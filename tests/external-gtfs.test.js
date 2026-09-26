'use strict';
/**
 * LOT 18 BIS — moteur GTFS externe sur les VRAIS ZIP PassBi (HISTORICAL) et
 * règles du provider. Les valeurs attendues proviennent du manifeste d'audit
 * (audit/external-feeds/manifest.json) et des fichiers eux-mêmes.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const L = require('../lib/external-gtfs');
const { buildZip } = require('./helpers/zip-writer');
const { AFTU_TEXTS } = require('./helpers/cetud-synthetic-fixture');

const ROOT = path.resolve(__dirname, '..');
const ZIP_DIR = path.join(ROOT, 'audit', 'external-feeds', 'source', 'passbi_core', 'gtfs_folder');
const AUDIT_MANIFEST = JSON.parse(fs.readFileSync(path.join(ROOT, 'audit', 'external-feeds', 'manifest.json'), 'utf8'));
const EXPECTED = {
  AFTU: { file: 'gtfs_AFTU.zip', sha256: '7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428', size: 10693791, routes: 73, stops: 2401, trips: 11077, stop_times: 677918, services: 4, window: ['20220101', '20231231'] },
  DDD: { file: 'gtfs_Dem_Dikk.zip', sha256: '578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159', size: 2635299, routes: 53, stops: 1277, trips: 9529, stop_times: 314029, services: 4, window: ['20220101', '20231231'] },
  BRT: { file: 'gtfs_BRT.zip', sha256: 'f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4', size: 520189, routes: 2, stops: 79, trips: 4036, stop_times: 58674, services: 7, window: ['20241024', '20241231'] },
  TER: { file: 'gtfs_TER.zip', sha256: '09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408', size: 109650, routes: 6, stops: 26, trips: 572, stop_times: 7332, services: 12, window: ['20250818', '20250831'] },
};

const sha256File = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');

let passbiLayer = null;
function realLayer() {
  if (!passbiLayer) passbiLayer = L.loadLayer(L.DEFAULT_PASSBI_DIR, { asOf: '2026-09-26' });
  return passbiLayer;
}
const feedOf = (network) => realLayer().feeds.find((f) => f.entry.network === network);

test('1. ZIP bruts PassBi : présents, octet pour octet (SHA-256 / taille du manifeste d\'audit), tables requises lisibles', () => {
  for (const [network, exp] of Object.entries(EXPECTED)) {
    const p = path.join(ZIP_DIR, exp.file);
    assert.ok(fs.existsSync(p), `${exp.file} absent`);
    assert.equal(sha256File(p), exp.sha256, `${network} : SHA-256 modifié`);
    const audited = AUDIT_MANIFEST.feeds.find((f) => f.id.endsWith(exp.file));
    assert.equal(audited.sha256, exp.sha256);
    assert.equal(audited.file_size_bytes, exp.size);
    const zip = L.openZip(p);
    assert.equal(zip.size, exp.size);
    const entries = L.gtfsEntries(zip); // Map table → nom d'entrée
    for (const t of ['agency', 'routes', 'stops', 'trips', 'stop_times']) assert.ok(entries.has(t), `${network} : ${t}.txt manquant`);
    assert.ok(entries.has('calendar') || entries.has('calendar_dates'));
    // Lecture d'une entrée avec contrôle CRC (levée si corrompue).
    const agency = L.readTextEntry(zip, entries.get('agency'));
    assert.match(agency.split(/\r?\n/)[0], /agency_id|agency_name/);
  }
});

test('2. Lecture directe des ZIP : comptes exacts, validation OK, fenêtres calendaires réelles, aucune extraction sur disque', () => {
  const layer = realLayer();
  assert.equal(layer.status, L.LAYER_STATUS.INSTALLED_NOT_CURRENT);
  assert.deepEqual(layer.errors, []);
  for (const [network, exp] of Object.entries(EXPECTED)) {
    const f = feedOf(network);
    assert.ok(f && f.feed, `${network} non chargé`);
    assert.equal(f.validation.ok, true, `${network} : ${f.validation.errors.join(' ; ')}`);
    assert.equal(f.feed.counts.routes, exp.routes);
    assert.equal(f.feed.counts.stops, exp.stops);
    assert.equal(f.feed.counts.trips, exp.trips);
    assert.equal(f.feed.counts.stop_times, exp.stop_times);
    assert.equal(f.feed.counts.services, exp.services);
    assert.deepEqual([f.feed.calendarWindow.start, f.feed.calendarWindow.end], exp.window);
    assert.equal(f.validityStatus, 'HISTORICAL');
  }
  // Anomalies réelles connues, remontées en avertissement (jamais masquées).
  assert.ok(feedOf('AFTU').validation.warnings.includes('TRIPS_WITHOUT_STOP_TIMES: 738'));
  assert.ok(feedOf('DDD').validation.warnings.includes('TRIPS_WITHOUT_STOP_TIMES: 333'));
  const extracted = fs.readdirSync(ZIP_DIR).filter((n) => n.endsWith('.txt'));
  assert.deepEqual(extracted, [], 'aucun .txt extrait ne doit être versionné');
});

test('3. calendar_dates PassBi (en-tête « ; », lignes « , ») : exceptions réellement appliquées', () => {
  const feed = feedOf('AFTU').feed;
  assert.deepEqual([...feed.services.keys()].sort(), ['DIMANCHE', 'FULL', 'LAV', 'SAMEDI']);
  const lav = feed.services.get('LAV');
  const dim = feed.services.get('DIMANCHE');
  assert.equal(lav.removedDates.size, 20);
  assert.equal(dim.addedDates.size, 20);
  const removed = [...lav.removedDates][0];
  assert.equal(feed.isServiceActive('LAV', removed), false);
  assert.equal(feed.isServiceActive('FULL', '20230315'), true);
  assert.equal(feed.isServiceActive('FULL', '20260926'), false, 'hors fenêtre 2022-2023');
  assert.equal(feed.isServiceActive('SAMEDI', '20230318'), true); // samedi
  assert.equal(feed.isServiceActive('SAMEDI', '20230315'), false); // mercredi
});

test('4. Horaires depuis stop_times uniquement (AFTU_30 à Colobane A_1564, 2023-03-15 07:40) ; hors validité → aucun départ', () => {
  const service = feedOf('AFTU').service;
  assert.equal(service.getRoute('AFTU_30').routeShortName, 'A30CG');
  assert.equal(service.getStop('A_1564').stopName, 'Colobane');
  const r = service.getDeparturesAtStop('AFTU_30', 'A_1564', '2023-03-15', '07:40', { limit: 3 });
  assert.equal(r.status, 'SCHEDULED');
  assert.deepEqual(r.departures.map((d) => d.departureTime), ['07:47:45', '08:00:45', '08:13:45']);
  assert.deepEqual(r.departures.map((d) => d.tripId), ['AFTU_30_Colobane_10', 'AFTU_30_Colobane_11', 'AFTU_30_Colobane_12']);
  assert.ok(r.departures.every((d) => d.stopSequence === 1), 'Colobane est l\'origine des courses Colobane→Gadaye ; les arrivées au terminus (courses Gadaye→Colobane) ne sont pas des départs');
  assert.equal(r.departures[0].direction.terminusStopName, 'Terminus 30 49');
  assert.equal(r.provenanceLevel, 'HISTORICAL_REFERENCE');
  assert.equal(r.validity.status, 'HISTORICAL');
  assert.equal(service.getDeparturesAtStop('AFTU_30', 'A_1564', '2026-09-26', '07:40').reason, 'NO_SERVICE_ON_DATE');
  assert.equal(service.getDeparturesAtStop('AFTU_30', 'A_503', '2023-03-15', '07:40').departures[0].departureTime, '07:42:05', 'A_503 (En Face Stade Ndiarème) est sur la ligne');
  assert.equal(service.getDeparturesAtStop('AFTU_30', 'A_1', '2023-03-15', '07:40').reason, 'STOP_NOT_ON_ROUTE');
  assert.equal(service.getDeparturesAtStop('AFTU_999', 'A_1564', '2023-03-15', '07:40').reason, 'ROUTE_UNKNOWN');
  assert.equal(service.getDeparturesAtStop('AFTU_30', 'A_1564', '2023-03-15', 'bientôt').reason, 'INVALID_TIME');
});

test('5. Provider : PassBi = HISTORICAL uniquement ; rôle actuel refusé ; jamais un départ « actuel », même pour une date couverte', () => {
  const { provider, registered, skipped, layers } = L.buildProvider({ asOf: '2026-09-26', now: () => new Date('2026-09-26T07:40:00Z') });
  assert.equal(layers.cetud.status, L.LAYER_STATUS.ABSENT);
  assert.deepEqual(registered.map((r) => r.role), ['historicalReference', 'historicalReference', 'historicalReference', 'historicalReference']);
  assert.deepEqual(skipped, []);
  const aftu = feedOf('AFTU').service;
  for (const role of ['currentOfficial', 'currentApplication', 'currentOpenData']) {
    assert.throws(() => provider.registerSource(aftu, { role }), /HISTORICAL/);
  }
  assert.equal(provider.getDepartures('AFTU_30', 'A_1564', { date: '2023-03-15', time: '07:40' }).status, 'UNKNOWN');
  const now = provider.getDeparturesNow('AFTU_30', 'A_1564');
  assert.equal(now.status, 'UNKNOWN');
  assert.equal(now.isCurrent, false);
  assert.equal(now.historicalReferenceAvailable, true);
  const hist = provider.getHistoricalDepartures('AFTU_30', 'A_1564', { date: '2023-03-15', time: '07:40', limit: 1 });
  assert.equal(hist.departures[0].departureTime, '07:47:45');
  assert.equal(hist.isCurrent, false);
  assert.equal(hist.provenanceLevel, 'HISTORICAL_REFERENCE');
  assert.equal(provider.winningSource('AFTU', '2026-09-26'), null);
  assert.equal(provider.winningSource('DDD', '2026-09-26'), null);
});

test('6. Validation GTFS : références orphelines, heures non conformes, tables manquantes → feed refusé', () => {
  const prov = new L.FeedProvenance({ source: 'CETUD', sourceType: 'OFFICIAL_STATIC_CURRENT', declaredStatus: 'UNKNOWN' });
  const asTables = (files) => Object.fromEntries(Object.entries(files).map(([k, v]) => [k.replace('.txt', ''), v]));
  const broken = { ...AFTU_TEXTS, 'stop_times.txt': `${AFTU_TEXTS['stop_times.txt']}TEST_T_GHOST,25:99:00,7h42,TEST_S_NOPE,1\n` };
  const r1 = L.loadFeedFromTexts(asTables(broken), prov, { network: 'AFTU' });
  assert.equal(r1.validation.ok, false);
  assert.ok(r1.validation.errors.some((e) => e.startsWith('ORPHAN_REFERENCE') && e.includes('trip_id')));
  assert.ok(r1.validation.errors.some((e) => e.startsWith('ORPHAN_REFERENCE') && e.includes('stop_id')));
  assert.ok(r1.validation.errors.some((e) => e.startsWith('INVALID_TIME')));
  const noTrips = { ...AFTU_TEXTS };
  delete noTrips['trips.txt'];
  const r2 = L.loadFeedFromTexts(asTables(noTrips), prov, { network: 'AFTU' });
  assert.ok(r2.validation.errors.includes('FILE_MISSING: trips.txt'));
  const noCal = { ...AFTU_TEXTS };
  delete noCal['calendar.txt'];
  delete noCal['calendar_dates.txt'];
  const r3 = L.loadFeedFromTexts(asTables(noCal), prov, { network: 'AFTU' });
  assert.ok(r3.validation.errors.some((e) => e.startsWith('FILE_MISSING: calendar')));
  assert.equal(L.parseTime('7h42'), null);
  assert.equal(L.parseTime('25:10:00'), 25 * 3600 + 600, 'heures ≥ 24 autorisées en GTFS');
});

test('7. Fréquence documentée : ESTIMATED sans heure fabriquée ; jamais un rôle officiel', () => {
  const freq = new L.FrequencySource(
    [{ network: 'AFTU', lineNumber: '30', headwayMinutes: 12, days: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'], from: '06:00', to: '21:00', label: 'fixture' }],
    { source: 'Fixture publication', sourceType: 'SOURCE_INSTITUTIONAL', declaredStatus: 'CURRENT', validFrom: '2026-01-01', validTo: '2026-12-31', url: 'https://example.invalid/freq', publishedAt: '2026-02-01' },
  );
  const provider = new L.TransitDataProvider({ now: () => new Date('2026-09-26T07:30:00Z') });
  assert.throws(() => provider.registerSource(freq, { role: 'currentOfficial' }), /fréquence/);
  provider.registerSource(freq, { role: 'currentFrequency' });
  const r = provider.getDepartures('FREQ:AFTU:30', null, { date: '2026-09-26', time: '07:30' });
  assert.equal(r.status, 'ESTIMATED');
  assert.equal(r.provenanceLevel, 'ESTIMATED');
  assert.deepEqual(r.departures, []);
  assert.equal(r.estimate.headwayMinutes, 12);
  assert.equal(r.estimate.stopVerified, false);
  assert.equal(provider.getDepartures('FREQ:AFTU:30', null, { date: '2026-09-27', time: '07:30' }).status, 'UNKNOWN', 'dimanche hors jours documentés');
  const a = L.answerScheduleQuestion(provider, 'Prochain bus AFTU 30 à Yeumbeul ?');
  assert.equal(a.status, 'ESTIMATED');
  assert.ok(a.sentence.startsWith('La ligne AFTU 30 dessert cet itinéraire. D\'après Fixture publication, un passage est annoncé environ toutes les 12 minutes entre 06:00 et 21:00.'));
  assert.ok(a.sentence.endsWith(L.SENTENCES.NO_RELIABLE_DATA));
  assert.doesNotMatch(a.sentence, /départ programmé est à/);
});

test('8. Manifeste : ZIP altéré ou SHA-256 différent → source ignorée, jamais enregistrée', () => {
  const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'dakar-bus-manifest-'));
  try {
    const buffer = buildZip(AFTU_TEXTS);
    const zipPath = path.join(tmp, 'gtfs.zip');
    fs.writeFileSync(zipPath, buffer);
    const entry = {
      id: 'cetud/test', source: 'CETUD', source_type: 'OFFICIAL_STATIC_CURRENT', status: 'CURRENT', role: 'CURRENT_OFFICIAL', network: 'AFTU', authority: 'CETUD',
      zip: zipPath, sha256: L.sha256(buffer), size_bytes: buffer.length, version: 'T', valid_from: '2026-01-01', valid_to: '2026-12-31', published_at: '2026-01-05', retrieved_at: '2026-09-26', url: 'x', license: null,
    };
    const write = (feeds) => fs.writeFileSync(path.join(tmp, 'feed-manifest.json'), JSON.stringify({ schema: L.MANIFEST_SCHEMA, feeds }));
    write([entry]);
    assert.equal(L.loadLayer(tmp, { asOf: '2026-09-26' }).status, 'CURRENT_INSTALLED');
    write([{ ...entry, sha256: 'f'.repeat(64) }]);
    const tampered = L.loadLayer(tmp, { asOf: '2026-09-26' });
    assert.equal(tampered.status, 'INVALID');
    assert.match(tampered.errors[0], /SHA-256 différent/);
    assert.equal(L.buildProvider({ asOf: '2026-09-26', cetudDir: tmp, passbi: false }).provider.sources.length, 0);
    write([{ ...entry, status: 'HISTORICAL' }]);
    assert.match(L.loadLayer(tmp, { asOf: '2026-09-26' }).errors[0], /HISTORICAL/);
    write([{ ...entry, source_type: 'SOURCE_APPLICATION' }]);
    assert.match(L.loadLayer(tmp, { asOf: '2026-09-26' }).errors[0], /institutionnel/);
    write([{ ...entry, published_at: null }]);
    assert.match(L.loadLayer(tmp, { asOf: '2026-09-26' }).errors[0], /published_at/);
    fs.writeFileSync(zipPath, Buffer.concat([buffer.subarray(0, buffer.length - 10), Buffer.alloc(10)]));
    write([entry]);
    assert.notEqual(L.loadLayer(tmp, { asOf: '2026-09-26' }).status, 'CURRENT_INSTALLED');
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('9. Production non modifiée : dakar_network.json, data/gtfs, reference-policy — empreintes inchangées', () => {
  const expected = {
    'flutter-src/assets/data/dakar_network.json': 'c08389ac04265a786fba3794580ef7da19ce258009d8d76290a14d5349e7fbe3',
    'data/gtfs/agency.txt': 'd16d5b8026ab4b84851cb12e5b406718bbf05b4eac671e5c681bd8403c85dc5c',
    'data/gtfs/calendar.txt': 'db357382fc2512eb17b14f7fed6af0f0f0c2ec2dabb1c86813d43d4f3da0548d',
    'data/gtfs/feed_info.txt': '2b463e49025011767e5788c430503b3e35ec485389d6881e46af599b15632783',
    'data/gtfs/routes.txt': 'bbc838005a6fe36312c979fc0c1374eb9f7c917afb5ca772b8ba85ac909328c6',
    'data/gtfs/shapes.txt': '80a84ebad85ae58e1081e5308e709bd0262dcdd383c1532a80169396091f27eb',
    'data/gtfs/stop_times.txt': '3f90f8f00b247cc5fb79200e2e8ead9b8a8f9abe3e187b532056e62059e0c346',
    'data/gtfs/stops.txt': 'e9b8081069cf977150645101671037d17f3576d11044836322240e0cd0a8ac49',
    'data/gtfs/trips.txt': '568377c6e59c491b40405d88f555a9696a798650398f3a1f9ec43f6888a11824',
    'data/transit/reference-policy.json': '94d698469b766ee89743392ab8b17458ab6a3e6d183b32bd74d9b26ce19d3d1c',
  };
  for (const [rel, sha] of Object.entries(expected)) assert.equal(sha256File(path.join(ROOT, rel)), sha, `${rel} modifié`);
  const pubspec = fs.readFileSync(path.join(ROOT, 'flutter-src', 'pubspec.yaml'), 'utf8');
  assert.doesNotMatch(pubspec, /assets\/data\/external|passbi|gtfs/i, 'aucun feed externe ne doit être embarqué comme asset');
});
