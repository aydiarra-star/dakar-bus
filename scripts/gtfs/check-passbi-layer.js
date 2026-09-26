#!/usr/bin/env node
'use strict';
/**
 * Contrôle de la couche PassBi (HISTORICAL / REFERENCE_GTFS) :
 *  - 4 ZIP bruts présents, SHA-256 et tailles identiques au manifeste ;
 *  - lecture directe des ZIP et validation GTFS (tables, colonnes, références, heures) ;
 *  - tous les feeds déclarés HISTORICAL avec rôle REFERENCE_GTFS, aucun utilisable « maintenant ».
 */
const { loadLayer, passbiDir, buildProvider } = require('../../lib/external-gtfs/feed-layers');

const EXPECTED_NETWORKS = ['AFTU', 'DDD', 'BRT', 'TER'];

function main() {
  const asOf = process.argv[2] || undefined;
  const dir = passbiDir();
  const layer = loadLayer(dir, { asOf });
  const problems = [...layer.errors];
  const networks = layer.feeds.map((f) => f.entry.network);
  for (const n of EXPECTED_NETWORKS) if (!networks.includes(n)) problems.push(`feed PassBi ${n} absent du manifeste`);
  for (const f of layer.feeds) {
    if (f.entry.status !== 'HISTORICAL') problems.push(`${f.entry.id} : status ${f.entry.status} ≠ HISTORICAL`);
    if (f.entry.role !== 'REFERENCE_GTFS' && f.entry.role !== 'HISTORICAL_REFERENCE') problems.push(`${f.entry.id} : rôle ${f.entry.role} interdit pour PassBi`);
    if (f.entry.source_type !== 'SOURCE_APPLICATION') problems.push(`${f.entry.id} : source_type ${f.entry.source_type} ≠ SOURCE_APPLICATION`);
  }
  const { provider } = buildProvider({ asOf, cetud: false, passbiDir: dir });
  const usable = provider.describe(asOf).sources.filter((s) => s.usableNow);
  if (usable.length) problems.push(`sources PassBi utilisables comme actuelles : ${usable.map((s) => s.network).join(', ')}`);
  const report = {
    layer: 'passbi',
    dir,
    as_of: layer.asOf,
    layer_status: layer.status,
    feeds: layer.feeds.map((f) => ({
      id: f.entry.id,
      network: f.entry.network,
      status: f.entry.status,
      role: f.entry.role,
      zip: f.entry.zip,
      sha256: f.entry.sha256,
      size_bytes: f.entry.size_bytes,
      validity: f.provenance ? f.provenance.validityOn(layer.asOf) : null,
      counts: f.feed ? f.feed.counts : null,
      validation: f.validation ? { ok: f.validation.ok, errors: f.validation.errors, warnings: f.validation.warnings } : null,
      errors: f.errors,
    })),
    provider_usable_now: usable.length,
    problems,
    ok: problems.length === 0,
  };
  console.log(JSON.stringify(report, null, 2));
  console.error(problems.length ? `PassBi : ${problems.length} problème(s)` : 'PassBi : couche HISTORICAL conforme (4 ZIP, SHA-256 vérifiés, aucune source actuelle).');
  process.exit(problems.length ? 1 : 0);
}

if (require.main === module) main();
module.exports = { main };
