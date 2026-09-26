'use strict';
/**
 * Fixture SYNTHÉTIQUE (identifiants TEST_* uniquement) simulant un feed CETUD
 * CURRENT pour les tests. Aucune valeur ne provient d'un vrai réseau : les
 * lignes, arrêts, horaires sont fictifs et ne décrivent aucun service réel.
 */
const fs = require('fs');
const path = require('path');
const os = require('os');
const { buildZip } = require('./zip-writer');
const { sha256 } = require('../../lib/external-gtfs/zip-reader');
const { MANIFEST_SCHEMA } = require('../../lib/external-gtfs/feed-layers');

const AFTU_TEXTS = {
  'agency.txt': 'agency_id,agency_name,agency_url,agency_timezone,agency_lang\nTEST_AFTU,AFTU TEST,https://example.invalid/aftu,Africa/Dakar,fr\n',
  'routes.txt': 'route_id,agency_id,route_short_name,route_long_name,route_type\nTEST_AFTU_R30,TEST_AFTU,30,Fixture A - Fixture C,3\nTEST_AFTU_R31_NOSHORT,TEST_AFTU,,Sans numero public,3\n',
  'stops.txt': 'stop_id,stop_name,stop_lat,stop_lon,location_type\nTEST_S_Y,Yeumbeul TEST,14.7700,-17.3700,0\nTEST_S_YA,Yeumbeul A TEST,14.7710,-17.3710,0\nTEST_S_B,Fixture B,14.7500,-17.4000,0\nTEST_S_C,Fixture C,14.7300,-17.4400,0\n',
  'calendar.txt': 'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nTEST_WEEK,1,1,1,1,1,1,0,20260101,20261231\nTEST_SUNDAY,0,0,0,0,0,0,1,20260101,20261231\nTEST_EXPIRED,1,1,1,1,1,1,1,20250101,20251231\n',
  'calendar_dates.txt': 'service_id,date,exception_type\nTEST_WEEK,20260928,2\nTEST_SUNDAY,20260929,1\n',
  'trips.txt': 'route_id,service_id,trip_id,trip_headsign,direction_id,shape_id\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W1,Fixture C,0,TEST_SHAPE_1\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W2,Fixture C,0,TEST_SHAPE_1\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W3,Yeumbeul TEST,1,\nTEST_AFTU_R30,TEST_SUNDAY,TEST_T_S1,Fixture C,0,TEST_SHAPE_1\nTEST_AFTU_R30,TEST_EXPIRED,TEST_T_X1,Fixture C,0,TEST_SHAPE_1\nTEST_AFTU_R31_NOSHORT,TEST_WEEK,TEST_T_N1,Fixture C,0,\n',
  'stop_times.txt': [
    'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
    'TEST_T_W1,07:42:00,07:42:00,TEST_S_Y,1', 'TEST_T_W1,07:50:00,07:50:00,TEST_S_B,2', 'TEST_T_W1,08:00:00,08:00:00,TEST_S_C,3',
    'TEST_T_W2,08:12:00,08:12:00,TEST_S_Y,1', 'TEST_T_W2,08:20:00,08:20:00,TEST_S_B,2', 'TEST_T_W2,08:30:00,08:30:00,TEST_S_C,3',
    'TEST_T_W3,09:00:00,09:00:00,TEST_S_C,1', 'TEST_T_W3,09:10:00,09:10:00,TEST_S_B,2', 'TEST_T_W3,09:20:00,09:20:00,TEST_S_Y,3',
    'TEST_T_S1,09:00:00,09:00:00,TEST_S_Y,1', 'TEST_T_S1,09:10:00,09:10:00,TEST_S_B,2', 'TEST_T_S1,09:20:00,09:20:00,TEST_S_C,3',
    'TEST_T_X1,07:30:00,07:30:00,TEST_S_Y,1', 'TEST_T_X1,07:40:00,07:40:00,TEST_S_B,2', 'TEST_T_X1,07:50:00,07:50:00,TEST_S_C,3',
    'TEST_T_N1,07:35:00,07:35:00,TEST_S_YA,1', 'TEST_T_N1,07:45:00,07:45:00,TEST_S_B,2', 'TEST_T_N1,07:55:00,07:55:00,TEST_S_C,3',
    '',
  ].join('\n'),
  'shapes.txt': 'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nTEST_SHAPE_1,14.7700,-17.3700,1\nTEST_SHAPE_1,14.7500,-17.4000,2\nTEST_SHAPE_1,14.7300,-17.4400,3\n',
  'feed_info.txt': 'feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version\nCETUD TEST,https://example.invalid/cetud,fr,20260101,20261231,TEST-2026.1\n',
};

const DDD_TEXTS = {
  'agency.txt': 'agency_id,agency_name,agency_url,agency_timezone\nTEST_DDD,Dem Dikk TEST,https://example.invalid/ddd,Africa/Dakar\n',
  'routes.txt': 'route_id,agency_id,route_short_name,route_long_name,route_type\nTEST_DDD_R16,TEST_DDD,16,Fixture L5 - Fixture X,3\nTEST_DDD_R16A,TEST_DDD,16A,Fixture L5 - Fixture X variante,3\n',
  'stops.txt': 'stop_id,stop_name,stop_lat,stop_lon\nTEST_D_L5,Liberte 5 TEST,14.7200,-17.4600\nTEST_D_X,Fixture X,14.7000,-17.4700\n',
  'calendar.txt': 'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nTEST_DDD_ALL,1,1,1,1,1,1,1,20260101,20261231\n',
  'trips.txt': 'route_id,service_id,trip_id,trip_headsign,direction_id\nTEST_DDD_R16,TEST_DDD_ALL,TEST_D16_1,Fixture X,0\nTEST_DDD_R16A,TEST_DDD_ALL,TEST_D16A_1,Fixture X,0\n',
  'stop_times.txt': 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nTEST_D16_1,10:05:00,10:05:00,TEST_D_L5,1\nTEST_D16_1,10:20:00,10:20:00,TEST_D_X,2\nTEST_D16A_1,10:01:00,10:01:00,TEST_D_L5,1\nTEST_D16A_1,10:15:00,10:15:00,TEST_D_X,2\n',
  'feed_info.txt': 'feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version\nCETUD TEST,https://example.invalid/cetud,fr,20260101,20261231,TEST-2026.1\n',
};

/** Feed volontairement invalide : stop_time vers une course inconnue + arrêt orphelin + heure fausse. */
const BROKEN_TEXTS = {
  ...AFTU_TEXTS,
  'stop_times.txt': `${AFTU_TEXTS['stop_times.txt']}TEST_T_GHOST,25:99:00,25:99:00,TEST_S_NOPE,1\n`,
};

const FIXTURE_TEXTS = { AFTU: AFTU_TEXTS, DDD: DDD_TEXTS, BROKEN: BROKEN_TEXTS };

function buildFixtureZip(network) {
  const texts = FIXTURE_TEXTS[network];
  if (!texts) throw new Error(`fixture inconnue : ${network}`);
  return buildZip(texts);
}

function manifestEntry(network, zipRelPath, buffer, overrides = {}) {
  return {
    id: `cetud/test_${network.toLowerCase()}`,
    source: 'CETUD',
    source_type: 'OFFICIAL_STATIC_CURRENT',
    status: 'CURRENT',
    role: 'CURRENT_OFFICIAL',
    network,
    authority: 'CETUD',
    zip: zipRelPath,
    sha256: sha256(buffer),
    size_bytes: buffer.length,
    version: 'TEST-2026.1',
    valid_from: '2026-01-01',
    valid_to: '2026-12-31',
    published_at: '2026-01-05',
    retrieved_at: '2026-09-26',
    url: 'https://example.invalid/cetud/gtfs (fixture synthétique)',
    license: 'fixture',
    ...overrides,
  };
}

/**
 * Écrit une couche CETUD synthétique complète dans un dossier temporaire.
 * @param {{networks?: string[], overrides?: object, dir?: string}} [options]
 * @returns {{dir: string, manifestPath: string, zips: Record<string,string>, cleanup: () => void}}
 */
function writeFixtureLayer(options = {}) {
  const dir = options.dir || fs.mkdtempSync(path.join(os.tmpdir(), 'dakar-bus-cetud-fixture-'));
  const networks = options.networks || ['AFTU', 'DDD'];
  const feeds = [];
  const zips = {};
  for (const network of networks) {
    const buffer = buildFixtureZip(network);
    const sub = path.join(dir, network.toLowerCase());
    fs.mkdirSync(sub, { recursive: true });
    const zipPath = path.join(sub, `gtfs_${network.toLowerCase()}_test.zip`);
    fs.writeFileSync(zipPath, buffer);
    zips[network] = zipPath;
    feeds.push(manifestEntry(network, zipPath, buffer, (options.overrides && options.overrides[network]) || {}));
  }
  const manifest = { schema: MANIFEST_SCHEMA, layer: 'cetud', generated_at: '2026-09-26', fixture: true, feeds };
  const manifestPath = path.join(dir, 'feed-manifest.json');
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  return { dir, manifestPath, manifest, zips, cleanup: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

module.exports = { FIXTURE_TEXTS, AFTU_TEXTS, DDD_TEXTS, BROKEN_TEXTS, buildFixtureZip, manifestEntry, writeFixtureLayer };
