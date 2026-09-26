#!/usr/bin/env node
'use strict';
/**
 * Installateur STRICT d'un feed GTFS officiel CETUD (AFTU ou DDD).
 *
 *   node scripts/gtfs/install-cetud-feed.js --zip <fichier.zip> --network AFTU|DDD \
 *        --published-at YYYY-MM-DD [--url <url>] [--origin <description de la remise>] \
 *        [--version <version>] [--license <licence>] [--retrieved-at YYYY-MM-DD] \
 *        [--as-of YYYY-MM-DD] [--dest <dossier>] [--dry-run]
 *
 * Règles :
 *  - le ZIP est copié INCHANGÉ (SHA-256 vérifié avant/après), jamais réécrit ;
 *  - refus si la validation GTFS échoue (tables/colonnes requises, références,
 *    heures, calendrier) ;
 *  - valid_from / valid_to lus dans le feed (feed_info.txt sinon calendar/calendar_dates) ;
 *  - status CURRENT + role CURRENT_OFFICIAL UNIQUEMENT si la validité couvre la
 *    date de référence ET qu'une publication est prouvée (--published-at) ;
 *    sinon status UNKNOWN + role REFERENCE_GTFS (jamais présenté comme actuel) ;
 *  - aucune valeur inventée : url / version / licence absentes restent null.
 */
const fs = require('fs');
const path = require('path');
const { openZip, sha256 } = require('../../lib/external-gtfs/zip-reader');
const { loadFeedFromZip } = require('../../lib/external-gtfs/gtfs-feed-loader');
const { FeedProvenance, classifyValidity, VALIDITY } = require('../../lib/external-gtfs/provenance');
const { normalizeServiceDate, toIsoDate, dakarClock } = require('../../lib/external-gtfs/gtfs-time');
const { MANIFEST_SCHEMA, MANIFEST_FILE, cetudDir, REPO_ROOT } = require('../../lib/external-gtfs/feed-layers');

const NETWORKS = ['AFTU', 'DDD'];

function parseArgs(argv) {
  const out = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') { out.dryRun = true; continue; }
    if (!a.startsWith('--')) throw new Error(`argument inattendu : ${a}`);
    const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--')) throw new Error(`valeur manquante pour ${a}`);
    out[key] = value;
    i++;
  }
  return out;
}

function isoOrNull(v, label) {
  if (v === undefined || v === null || v === '') return null;
  try { return toIsoDate(normalizeServiceDate(v)); } catch (e) { throw new Error(`${label} : date invalide « ${v} » (YYYY-MM-DD attendu)`); }
}

/**
 * Prépare une entrée de manifeste à partir d'un ZIP, sans rien écrire.
 * @returns {{entry: object, validation: object, feed: object, zip: object, decision: object}}
 */
function inspectFeed(options) {
  const network = String(options.network || '').toUpperCase();
  if (!NETWORKS.includes(network)) throw new Error(`--network doit valoir ${NETWORKS.join(' | ')}`);
  if (!options.zip) throw new Error('--zip requis');
  const zipPath = path.resolve(options.zip);
  if (!fs.existsSync(zipPath)) throw new Error(`ZIP introuvable : ${zipPath}`);
  const asOf = options.asOf ? normalizeServiceDate(options.asOf) : dakarClock(new Date()).serviceDate;
  const publishedAt = isoOrNull(options.publishedAt, '--published-at');
  const retrievedAt = isoOrNull(options.retrievedAt, '--retrieved-at') || toIsoDate(dakarClock(new Date()).serviceDate);
  const zip = openZip(zipPath);
  const provisional = new FeedProvenance({ source: 'CETUD', sourceType: 'OFFICIAL_STATIC_CURRENT', declaredStatus: 'UNKNOWN', authority: 'CETUD', network });
  const { feed, validation } = loadFeedFromZip(zip, provisional, { network });

  // Validité : feed_info.txt (feed_start_date / feed_end_date) sinon fenêtre calendrier.
  const info = feed.feedInfo || null;
  let validFrom = null; let validTo = null; let validitySource = null;
  if (info && info.feed_start_date && info.feed_end_date) {
    validFrom = isoOrNull(info.feed_start_date, 'feed_info.feed_start_date');
    validTo = isoOrNull(info.feed_end_date, 'feed_info.feed_end_date');
    validitySource = 'feed_info.txt feed_start_date/feed_end_date';
  } else if (feed.calendarWindow && feed.calendarWindow.start && feed.calendarWindow.end) {
    validFrom = toIsoDate(feed.calendarWindow.start);
    validTo = toIsoDate(feed.calendarWindow.end);
    validitySource = 'calendar.txt / calendar_dates.txt (fenêtre observée)';
  }
  const version = options.version || (info && info.feed_version) || null;
  const validityNow = classifyValidity(validFrom, validTo, asOf);
  const reasons = [];
  if (!validation.ok) reasons.push(`validation GTFS en échec : ${validation.errors.join(' ; ')}`);
  if (validityNow !== VALIDITY.CURRENT) reasons.push(`validité ${validFrom || '?'} → ${validTo || '?'} ne couvre pas ${toIsoDate(asOf)} (${validityNow})`);
  if (!publishedAt) reasons.push('publication non prouvée (--published-at absent)');
  if (!options.url && !options.origin) reasons.push('origine non documentée (--url ou --origin requis)');
  const current = reasons.length === 0;
  const entry = {
    id: `cetud/${network.toLowerCase()}/${path.basename(zipPath)}`,
    source: 'CETUD',
    source_type: 'OFFICIAL_STATIC_CURRENT',
    status: current ? VALIDITY.CURRENT : VALIDITY.UNKNOWN,
    role: current ? 'CURRENT_OFFICIAL' : 'REFERENCE_GTFS',
    network,
    authority: 'CETUD',
    zip: null, // renseigné à l'installation (chemin relatif au dépôt)
    sha256: zip.sha256,
    size_bytes: zip.size,
    version,
    valid_from: validFrom,
    valid_to: validTo,
    validity_source: validitySource,
    published_at: publishedAt,
    retrieved_at: retrievedAt,
    url: options.url || null,
    origin: options.origin || null,
    license: options.license || null,
    feed_info: info,
    counts: feed.counts,
    validation_warnings: validation.warnings,
    installed_at: toIsoDate(asOf),
    status_reasons: current ? [] : reasons,
  };
  return { entry, validation, feed, zip, decision: { current, reasons, validityNow, asOf: toIsoDate(asOf) } };
}

function installFeed(options) {
  const inspected = inspectFeed(options);
  const { entry, validation, zip, decision } = inspected;
  if (!validation.ok) {
    const err = new Error(`ZIP refusé (validation GTFS) : ${validation.errors.join(' ; ')}`);
    err.validation = validation;
    throw err;
  }
  const dest = options.dest ? path.resolve(options.dest) : cetudDir();
  const subdir = path.join(dest, entry.network.toLowerCase());
  const target = path.join(subdir, path.basename(zip.path));
  const relTarget = path.relative(REPO_ROOT, target).split(path.sep).join('/');
  entry.zip = relTarget.startsWith('..') ? target : relTarget;
  if (options.dryRun) return { ...inspected, dryRun: true, target, manifestPath: path.join(dest, MANIFEST_FILE) };

  fs.mkdirSync(subdir, { recursive: true });
  fs.copyFileSync(zip.path, target);
  const copied = sha256(fs.readFileSync(target));
  if (copied !== zip.sha256) {
    fs.rmSync(target, { force: true });
    throw new Error(`copie corrompue : SHA-256 ${copied} ≠ ${zip.sha256}`);
  }
  const manifestPath = path.join(dest, MANIFEST_FILE);
  let manifest = { schema: MANIFEST_SCHEMA, layer: 'cetud', generated_at: entry.installed_at, feeds: [] };
  if (fs.existsSync(manifestPath)) {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    if (manifest.schema !== MANIFEST_SCHEMA) throw new Error(`manifeste existant incompatible (${manifest.schema})`);
    manifest.feeds = (manifest.feeds || []).filter((f) => f.network !== entry.network);
  }
  manifest.generated_at = entry.installed_at;
  manifest.feeds.push(entry);
  manifest.feeds.sort((a, b) => String(a.network).localeCompare(String(b.network)));
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  return { ...inspected, dryRun: false, target, manifestPath, decision };
}

function main() {
  let options;
  try { options = parseArgs(process.argv.slice(2)); } catch (e) { console.error(`Erreur : ${e.message}`); process.exit(2); }
  try {
    const result = installFeed(options);
    const { entry, validation, decision } = result;
    console.log(JSON.stringify({
      installed: !result.dryRun,
      dry_run: result.dryRun,
      target: result.target,
      manifest: result.manifestPath,
      network: entry.network,
      sha256: entry.sha256,
      size_bytes: entry.size_bytes,
      version: entry.version,
      valid_from: entry.valid_from,
      valid_to: entry.valid_to,
      published_at: entry.published_at,
      status: entry.status,
      role: entry.role,
      status_reasons: decision.reasons,
      counts: entry.counts,
      warnings: validation.warnings,
    }, null, 2));
    if (!decision.current) console.error('ATTENTION : feed installé comme référence (status UNKNOWN), PAS comme source actuelle.');
    process.exit(0);
  } catch (e) {
    console.error(`REFUS : ${e.message}`);
    process.exit(1);
  }
}

if (require.main === module) main();

module.exports = { inspectFeed, installFeed, parseArgs, NETWORKS };
