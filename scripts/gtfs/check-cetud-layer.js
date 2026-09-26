#!/usr/bin/env node
'use strict';
/**
 * Contrôle de la couche CETUD CURRENT (data/external/gtfs/cetud/ ou $DAKAR_BUS_CETUD_DIR).
 * Sortie : layer_status ∈ ABSENT | CURRENT_INSTALLED | INSTALLED_NOT_CURRENT | INVALID.
 * Code de sortie : 0 (ABSENT, CURRENT_INSTALLED, INSTALLED_NOT_CURRENT), 1 (INVALID).
 */
const { loadLayer, cetudDir, LAYER_STATUS } = require('../../lib/external-gtfs/feed-layers');

function main() {
  const asOf = process.argv[2] || undefined;
  const dir = cetudDir();
  const layer = loadLayer(dir, { asOf });
  const report = {
    layer: 'cetud',
    dir,
    as_of: layer.asOf,
    layer_status: layer.status,
    feeds: layer.feeds.map((f) => ({
      id: f.entry.id,
      network: f.entry.network,
      status: f.entry.status,
      role: f.entry.role,
      validity: f.provenance ? f.provenance.validityOn(layer.asOf) : null,
      sha256: f.entry.sha256,
      counts: f.feed ? f.feed.counts : null,
      validation: f.validation ? { ok: f.validation.ok, errors: f.validation.errors, warnings: f.validation.warnings } : null,
      errors: f.errors,
    })),
    errors: layer.errors,
  };
  console.log(JSON.stringify(report, null, 2));
  if (layer.status === LAYER_STATUS.ABSENT) console.error('CETUD CURRENT : ABSENT — aucune source officielle actuelle installée (voir data/external/gtfs/cetud/README.md).');
  if (layer.status === LAYER_STATUS.INSTALLED_NOT_CURRENT) console.error('CETUD : feed installé mais NON actuel — jamais utilisé comme source actuelle.');
  process.exit(layer.status === LAYER_STATUS.INVALID ? 1 : 0);
}

if (require.main === module) main();
module.exports = { main };
