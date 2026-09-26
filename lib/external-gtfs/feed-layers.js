'use strict';
/**
 * Couches de feeds externes pilotées par manifeste :
 *  - data/external/gtfs/passbi/feed-manifest.json  → PassBi, HISTORICAL / REFERENCE_GTFS
 *    (les ZIP bruts restent dans audit/external-feeds/source/passbi_core/gtfs_folder/, lus tels quels) ;
 *  - data/external/gtfs/cetud/feed-manifest.json   → CETUD CURRENT (absent tant qu'aucun feed
 *    officiel n'a été récupéré et vérifié ; installé uniquement par scripts/gtfs/install-cetud-feed.js).
 * Chaque chargement re-vérifie le SHA-256 du ZIP : un ZIP modifié ou absent invalide l'entrée.
 */
const fs = require('fs');
const path = require('path');
const { openZip } = require('./zip-reader');
const { loadFeedFromZip } = require('./gtfs-feed-loader');
const { FeedProvenance, VALIDITY, SOURCE_TYPES } = require('./provenance');
const { GtfsScheduleService } = require('./gtfs-schedule-service');
const { TransitDataProvider, ROLES } = require('./transit-data-provider');
const { normalizeServiceDate, dakarClock } = require('./gtfs-time');

const MANIFEST_SCHEMA = 'dakar-bus/external-gtfs-feed-manifest/v1';
const MANIFEST_FILE = 'feed-manifest.json';
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_PASSBI_DIR = path.join(REPO_ROOT, 'data', 'external', 'gtfs', 'passbi');
const DEFAULT_CETUD_DIR = path.join(REPO_ROOT, 'data', 'external', 'gtfs', 'cetud');

const LAYER_STATUS = Object.freeze({
  ABSENT: 'ABSENT',
  CURRENT_INSTALLED: 'CURRENT_INSTALLED',
  INSTALLED_NOT_CURRENT: 'INSTALLED_NOT_CURRENT',
  INVALID: 'INVALID',
});

const ROLE_BY_MANIFEST = Object.freeze({
  CURRENT_OFFICIAL: ROLES.CURRENT_OFFICIAL,
  CURRENT_APPLICATION: ROLES.CURRENT_APPLICATION,
  CURRENT_OPEN_DATA: ROLES.CURRENT_OPEN_DATA,
  HISTORICAL_REFERENCE: ROLES.HISTORICAL_REFERENCE,
  REFERENCE_GTFS: ROLES.HISTORICAL_REFERENCE,
});

function cetudDir() { return process.env.DAKAR_BUS_CETUD_DIR ? path.resolve(process.env.DAKAR_BUS_CETUD_DIR) : DEFAULT_CETUD_DIR; }
function passbiDir() { return process.env.DAKAR_BUS_PASSBI_DIR ? path.resolve(process.env.DAKAR_BUS_PASSBI_DIR) : DEFAULT_PASSBI_DIR; }

/** Lit et contrôle la structure d'un manifeste ; null si absent. */
function readManifest(dir) {
  const manifestPath = path.join(dir, MANIFEST_FILE);
  if (!fs.existsSync(manifestPath)) return null;
  let manifest;
  try { manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')); } catch (e) { throw new Error(`Manifeste illisible ${manifestPath} : ${e.message}`); }
  if (manifest.schema !== MANIFEST_SCHEMA) throw new Error(`Manifeste ${manifestPath} : schema « ${manifest.schema} » ≠ ${MANIFEST_SCHEMA}`);
  if (!Array.isArray(manifest.feeds)) throw new Error(`Manifeste ${manifestPath} : « feeds » doit être un tableau`);
  return { manifestPath, dir, manifest };
}

/** Contrôle statique d'une entrée : champs, rôle cohérent avec le statut, ZIP présent et SHA-256 identique. */
function checkManifestEntry(entry, dir) {
  const errors = [];
  const required = ['id', 'source', 'source_type', 'status', 'role', 'network', 'zip', 'sha256'];
  for (const k of required) if (entry[k] === undefined || entry[k] === null || entry[k] === '') errors.push(`champ manquant : ${k}`);
  if (entry.status && !VALIDITY[entry.status]) errors.push(`status inconnu : ${entry.status}`);
  const role = ROLE_BY_MANIFEST[entry.role];
  if (entry.role && !role) errors.push(`role inconnu : ${entry.role}`);
  if (entry.status === VALIDITY.HISTORICAL && role && role !== ROLES.HISTORICAL_REFERENCE) errors.push('un feed HISTORICAL ne peut avoir qu\'un rôle HISTORICAL_REFERENCE / REFERENCE_GTFS');
  if (role && role !== ROLES.HISTORICAL_REFERENCE && entry.status !== VALIDITY.CURRENT) errors.push(`rôle ${entry.role} exige status CURRENT (statut : ${entry.status})`);
  if (entry.status === VALIDITY.CURRENT && (!entry.valid_from || !entry.valid_to)) errors.push('status CURRENT exige valid_from et valid_to');
  if (entry.status === VALIDITY.CURRENT && !entry.published_at) errors.push('status CURRENT exige published_at (publication prouvée)');
  if (entry.role === 'CURRENT_OFFICIAL' && (FeedProvenance.fromManifestEntry({ ...entry, source: entry.source || '?' }).sourceType !== SOURCE_TYPES.SOURCE_INSTITUTIONAL)) {
    errors.push('CURRENT_OFFICIAL exige un source_type institutionnel (OFFICIAL_STATIC_CURRENT / OFFICIAL_CURRENT)');
  }
  const zipPath = entry.zip ? (path.isAbsolute(entry.zip) ? entry.zip : path.resolve(REPO_ROOT, entry.zip)) : null;
  let zip = null;
  if (zipPath) {
    if (!fs.existsSync(zipPath)) errors.push(`ZIP absent : ${entry.zip}`);
    else {
      try {
        zip = openZip(zipPath);
        if (entry.sha256 && zip.sha256 !== String(entry.sha256).toLowerCase()) errors.push(`SHA-256 différent : manifeste ${entry.sha256} ≠ fichier ${zip.sha256}`);
        if (entry.size_bytes !== undefined && Number(entry.size_bytes) !== zip.size) errors.push(`taille différente : manifeste ${entry.size_bytes} ≠ fichier ${zip.size}`);
      } catch (e) { errors.push(`ZIP illisible : ${e.message}`); }
    }
  }
  return { errors, role, zipPath, zip, dir };
}

/**
 * Charge une couche complète : manifeste, contrôles, feeds, validation GTFS, services.
 * @param {string} dir
 * @param {{asOf?: string, networks?: string[], load?: boolean}} [options]
 */
function loadLayer(dir, options = {}) {
  const asOf = options.asOf ? normalizeServiceDate(options.asOf) : dakarClock(new Date()).serviceDate;
  const read = readManifest(dir);
  if (!read) return { dir, manifestPath: path.join(dir, MANIFEST_FILE), status: LAYER_STATUS.ABSENT, asOf, feeds: [], errors: [] };
  const feeds = [];
  const errors = [];
  for (const entry of read.manifest.feeds) {
    if (options.networks && !options.networks.includes(entry.network)) continue;
    const check = checkManifestEntry(entry, dir);
    const item = { entry, role: check.role, zipPath: check.zipPath, errors: check.errors.slice(), provenance: null, feed: null, validation: null, service: null, validityStatus: null };
    if (!check.errors.length) {
      item.provenance = FeedProvenance.fromManifestEntry({ ...entry, original_file: entry.zip });
      item.validityStatus = item.provenance.validityStatusOn(asOf);
      if (options.load !== false) {
        try {
          const loaded = loadFeedFromZip(check.zip, item.provenance, { network: entry.network });
          item.feed = loaded.feed;
          item.validation = loaded.validation;
          if (!loaded.validation.ok) item.errors.push(...loaded.validation.errors.map((e) => `GTFS : ${e}`));
          else item.service = new GtfsScheduleService(loaded.feed);
        } catch (e) { item.errors.push(`chargement : ${e.message}`); }
      }
    }
    if (item.errors.length) errors.push(`${entry.id || entry.zip} : ${item.errors.join(' ; ')}`);
    feeds.push(item);
  }
  let status;
  if (!feeds.length) status = LAYER_STATUS.ABSENT;
  else if (feeds.every((f) => f.errors.length)) status = LAYER_STATUS.INVALID;
  else if (feeds.some((f) => !f.errors.length && f.entry.status === VALIDITY.CURRENT && f.validityStatus === VALIDITY.CURRENT)) status = LAYER_STATUS.CURRENT_INSTALLED;
  else status = LAYER_STATUS.INSTALLED_NOT_CURRENT;
  return { dir, manifestPath: read.manifestPath, manifest: read.manifest, status, asOf, feeds, errors };
}

/**
 * Construit le provider commun : CETUD CURRENT (si installé et valide) puis PassBi HISTORICAL.
 * Un feed dont le manifeste ou le SHA est invalide n'est JAMAIS enregistré.
 */
function buildProvider(options = {}) {
  const now = options.now || (() => new Date());
  const asOf = options.asOf ? normalizeServiceDate(options.asOf) : dakarClock(now()).serviceDate;
  const provider = new TransitDataProvider({ now });
  const layers = {};
  const registered = [];
  const skipped = [];
  const register = (layerName, layer) => {
    layers[layerName] = layer;
    for (const f of layer.feeds) {
      if (f.errors.length || !f.service) { skipped.push({ layer: layerName, id: f.entry.id, reason: f.errors.join(' ; ') || 'non chargé' }); continue; }
      try {
        provider.registerSource(f.service, { role: f.role });
        registered.push({ layer: layerName, id: f.entry.id, role: f.role, network: f.entry.network, validityStatus: f.validityStatus });
      } catch (e) { skipped.push({ layer: layerName, id: f.entry.id, reason: e.message }); }
    }
  };
  if (options.cetud !== false) register('cetud', loadLayer(options.cetudDir || cetudDir(), { asOf, networks: options.networks }));
  if (options.passbi !== false) register('passbi', loadLayer(options.passbiDir || passbiDir(), { asOf, networks: options.networks }));
  if (Array.isArray(options.extraSources)) {
    for (const { service, role } of options.extraSources) { provider.registerSource(service, { role }); registered.push({ layer: 'extra', id: service.provenance.sourceId, role, network: service.network }); }
  }
  return { provider, layers, registered, skipped, asOf };
}

module.exports = {
  MANIFEST_SCHEMA, MANIFEST_FILE, LAYER_STATUS, ROLE_BY_MANIFEST, REPO_ROOT, DEFAULT_PASSBI_DIR, DEFAULT_CETUD_DIR,
  cetudDir, passbiDir, readManifest, checkManifestEntry, loadLayer, buildProvider,
};
