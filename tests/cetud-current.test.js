'use strict';
/**
 * LOT 18 BIS — couche CETUD CURRENT : installateur strict, priorité du
 * provider, assistant IA. Feed CETUD réel NON disponible publiquement au
 * 2026-09-26 : ces tests utilisent une fixture SYNTHÉTIQUE (identifiants
 * TEST_*) qui simule un feed officiel valide, sans aucune donnée réelle.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const L = require('../lib/external-gtfs');
const { installFeed } = require('../scripts/gtfs/install-cetud-feed');
const { buildFixtureZip, writeFixtureLayer, AFTU_TEXTS } = require('./helpers/cetud-synthetic-fixture');

const NOW_SAT = () => new Date('2026-09-26T07:30:00Z'); // samedi, 07:30 heure de Dakar (UTC+0)
const ROOT = path.resolve(__dirname, '..');

test('10. Installateur CETUD strict : ZIP inchangé + SHA-256, CURRENT seulement si validité couverte ET publication prouvée, refus si invalide', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dakar-bus-install-'));
  try {
    const src = path.join(tmp, 'src');
    fs.mkdirSync(src);
    const zipA = path.join(src, 'gtfs_aftu_test.zip');
    const zipD = path.join(src, 'gtfs_ddd_test.zip');
    const zipB = path.join(src, 'gtfs_broken_test.zip');
    fs.writeFileSync(zipA, buildFixtureZip('AFTU'));
    fs.writeFileSync(zipD, buildFixtureZip('DDD'));
    fs.writeFileSync(zipB, buildFixtureZip('BROKEN'));
    const dest = path.join(tmp, 'cetud');

    const dry = installFeed({ zip: zipA, network: 'AFTU', publishedAt: '2026-01-05', url: 'https://example.invalid/aftu', asOf: '2026-09-26', dest, dryRun: true });
    assert.equal(dry.dryRun, true);
    assert.equal(fs.existsSync(dest), false, 'dry-run n\'écrit rien');

    const a = installFeed({ zip: zipA, network: 'AFTU', publishedAt: '2026-01-05', url: 'https://example.invalid/aftu', asOf: '2026-09-26', dest });
    assert.equal(a.entry.status, 'CURRENT');
    assert.equal(a.entry.role, 'CURRENT_OFFICIAL');
    assert.equal(a.entry.source_type, 'OFFICIAL_STATIC_CURRENT');
    assert.equal(a.entry.version, 'TEST-2026.1', 'version lue dans feed_info.txt, pas inventée');
    assert.deepEqual([a.entry.valid_from, a.entry.valid_to], ['2026-01-01', '2026-12-31']);
    assert.equal(a.entry.license, null, 'licence absente → null');
    assert.equal(L.sha256(fs.readFileSync(a.target)), L.sha256(fs.readFileSync(zipA)), 'copie octet pour octet');
    assert.equal(path.dirname(a.target), path.join(dest, 'aftu'));

    const d = installFeed({ zip: zipD, network: 'DDD', origin: 'remise test sans date de publication', asOf: '2026-09-26', dest });
    assert.equal(d.entry.status, 'UNKNOWN');
    assert.equal(d.entry.role, 'REFERENCE_GTFS');
    assert.match(d.decision.reasons.join(' '), /publication non prouvée/);

    const expired = installFeed({ zip: zipD, network: 'DDD', publishedAt: '2026-01-05', url: 'u', asOf: '2027-03-01', dest, dryRun: true });
    assert.equal(expired.entry.status, 'UNKNOWN', 'validité dépassée → jamais CURRENT');

    assert.throws(() => installFeed({ zip: zipB, network: 'AFTU', publishedAt: '2026-01-05', url: 'u', asOf: '2026-09-26', dest }), /ZIP refusé/);
    assert.throws(() => installFeed({ zip: zipA, network: 'TER', publishedAt: '2026-01-05', url: 'u', dest }), /--network/);

    const manifest = JSON.parse(fs.readFileSync(path.join(dest, 'feed-manifest.json'), 'utf8'));
    assert.equal(manifest.schema, L.MANIFEST_SCHEMA);
    assert.deepEqual(manifest.feeds.map((f) => [f.network, f.status, f.role]), [['AFTU', 'CURRENT', 'CURRENT_OFFICIAL'], ['DDD', 'UNKNOWN', 'REFERENCE_GTFS']]);
    const layer = L.loadLayer(dest, { asOf: '2026-09-26' });
    assert.equal(layer.status, 'CURRENT_INSTALLED');
    assert.deepEqual(layer.errors, []);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('11. Provider : CETUD CURRENT prioritaire sur PassBi HISTORICAL ; calendar_dates respectées ; feed expiré → UNKNOWN ; aucune donnée par défaut', () => {
  const fx = writeFixtureLayer();
  try {
    const { provider, registered, layers } = L.buildProvider({ asOf: '2026-09-26', cetudDir: fx.dir, now: NOW_SAT });
    assert.equal(layers.cetud.status, 'CURRENT_INSTALLED');
    assert.deepEqual(registered.slice(0, 2).map((r) => [r.id, r.role]), [['cetud/test_aftu', 'currentOfficial'], ['cetud/test_ddd', 'currentOfficial']]);
    assert.equal(registered.filter((r) => r.layer === 'passbi').length, 4);
    const win = provider.winningSource('AFTU', '2026-09-26');
    assert.equal(win.provenance.source, 'CETUD');
    assert.equal(win.rank, 0);
    assert.equal(win.level, 'OFFICIAL_STATIC_CURRENT');

    const now = provider.getDeparturesNow('TEST_AFTU_R30', 'TEST_S_Y', { limit: 2 });
    assert.equal(now.status, 'SCHEDULED');
    assert.equal(now.isCurrent, true);
    assert.equal(now.source, 'CETUD');
    assert.equal(now.provenanceLevel, 'OFFICIAL_STATIC_CURRENT');
    assert.deepEqual(now.departures.map((d) => [d.departureTime, d.tripId, d.serviceId]), [['07:42:00', 'TEST_T_W1', 'TEST_WEEK'], ['08:12:00', 'TEST_T_W2', 'TEST_WEEK']]);
    assert.equal(now.departures[0].status, 'SCHEDULED');
    assert.equal(now.departures[0].direction.terminusStopName, 'Fixture C');
    // Service EXPIRED (2025) jamais actif en 2026, même si ses stop_times existent.
    assert.ok(!now.departures.some((d) => d.tripId === 'TEST_T_X1'));
    // calendar_dates : TEST_WEEK retiré le 2026-09-28 (lundi) → aucun service ; TEST_SUNDAY ajouté le 2026-09-29 (mardi).
    assert.equal(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', { date: '2026-09-28', time: '07:00' }).reason, 'NO_SERVICE_ON_DATE');
    assert.equal(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', { date: '2026-09-29', time: '08:30' }).departures[0].tripId, 'TEST_T_S1');
    assert.equal(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', { date: '2026-09-27', time: '07:30' }).departures[0].departureTime, '09:00:00', 'dimanche');
    assert.equal(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', { date: '2026-09-26', time: '09:00' }).reason, 'NO_MORE_DEPARTURES');
    // PassBi reste consultable uniquement en référence historique, et n'est jamais « actuel ».
    assert.equal(provider.getDepartures('AFTU_30', 'A_1564', { date: '2023-03-15', time: '07:40' }).status, 'UNKNOWN');
    assert.equal(provider.getHistoricalDepartures('AFTU_30', 'A_1564', { date: '2023-03-15', time: '07:40', limit: 1 }).departures[0].departureTime, '07:47:45');

    // Même couche, horloge en 2027 : le feed CETUD est expiré → UNKNOWN (jamais d'heure d'un feed périmé).
    const later = L.buildProvider({ asOf: '2027-02-01', cetudDir: fx.dir, passbi: false, now: () => new Date('2027-02-01T07:30:00Z') });
    assert.equal(later.layers.cetud.status, 'INSTALLED_NOT_CURRENT');
    const stale = later.provider.getDeparturesNow('TEST_AFTU_R30', 'TEST_S_Y');
    assert.equal(stale.status, 'UNKNOWN');
    assert.equal(stale.isCurrent, false);

    assert.equal(new L.TransitDataProvider().sources.length, 0, 'aucune source embarquée par défaut');
    const cetudFeed = layers.cetud.feeds[0].service;
    assert.throws(() => new L.TransitDataProvider().registerSource(cetudFeed, { role: 'currentApplication' }), /SOURCE_APPLICATION requis/);
    const passbiAftu = layers.passbi.feeds.find((f) => f.entry.network === 'AFTU').service;
    assert.throws(() => new L.TransitDataProvider().registerSource(passbiAftu, { role: 'currentOfficial' }), /HISTORICAL/);
  } finally {
    fx.cleanup();
  }
});

test('12. Assistant IA : même provider, phrases exactes (trouvé / fallback LOT 18 BIS / ligne connue), DDD 16 ≠ 16A, arrêt ambigu', () => {
  const fx = writeFixtureLayer();
  try {
    const { provider } = L.buildProvider({ asOf: '2026-09-26', cetudDir: fx.dir, now: NOW_SAT });
    const q = L.parseScheduleQuestion('Prochain bus AFTU 30 à l\'arrêt Yeumbeul TEST ?', { now: NOW_SAT() });
    assert.deepEqual([q.isScheduleQuestion, q.network, q.lineNumber, q.stopName, q.date, q.time], [true, 'AFTU', '30', 'Yeumbeul TEST', null, null]);
    const found = L.answerScheduleQuestion(provider, 'Prochain bus AFTU 30 à l\'arrêt Yeumbeul TEST ?');
    assert.equal(found.status, 'SCHEDULED');
    assert.equal(found.sentence, 'La ligne AFTU 30 dessert cet itinéraire. Depuis l\'arrêt Yeumbeul TEST, le prochain départ programmé est à 07:42. Direction Fixture C. Source : CETUD (OFFICIAL_STATIC_CURRENT, validité 2026-01-01 → 2026-12-31).');
    assert.equal(found.provenanceLevel, 'OFFICIAL_STATIC_CURRENT');
    assert.equal(found.departure.tripId, 'TEST_T_W1');
    // Date/heure explicites, direction demandée, arrêt en correspondance partielle unique.
    const tue = L.answerScheduleQuestion(provider, 'AFTU 30 à Yeumbeul le 2026-09-29 à 8h30');
    assert.equal(tue.departure.tripId, 'TEST_T_S1');
    assert.match(tue.sentence, /départ programmé est à 09:00\./);
    const back = L.answerScheduleQuestion(provider, 'bus AFTU 30 depuis Fixture B direction Yeumbeul');
    assert.equal(back.departure.tripId, 'TEST_T_W3');
    assert.match(back.sentence, /Depuis l'arrêt Fixture B, le prochain départ programmé est à 09:10\. Direction Yeumbeul TEST\./);
    // DDD : variantes jamais fusionnées, numéro lu tel quel dans route_short_name.
    assert.match(L.answerScheduleQuestion(provider, 'Quand passe la ligne 16 DDD depuis Liberte 5 TEST ?').sentence, /^La ligne DDD 16 dessert cet itinéraire\. Depuis l'arrêt Liberte 5 TEST, le prochain départ programmé est à 10:05\./);
    assert.match(L.answerScheduleQuestion(provider, 'ligne 16A DDD à Liberte 5 TEST').sentence, /^La ligne DDD 16A dessert cet itinéraire\. Depuis l'arrêt Liberte 5 TEST, le prochain départ programmé est à 10:01\./);
    // Ligne sans route_short_name : jamais déduite → fallback exact.
    const noShort = L.answerScheduleQuestion(provider, 'ligne 31 AFTU à Yeumbeul A TEST');
    assert.equal(noShort.status, 'UNKNOWN');
    assert.equal(noShort.sentence, L.SENTENCES.NO_RELIABLE_DATA);
    // Arrêt ambigu / arrêt hors ligne / plus de départ.
    const amb = L.answerScheduleQuestion(provider, 'prochain bus AFTU 30 à Fixture');
    assert.equal(amb.status, 'AMBIGUOUS_STOP');
    assert.equal(amb.sentence, 'Plusieurs arrêts correspondent à « Fixture » : Fixture B, Fixture C. Précisez l\'arrêt.');
    assert.equal(L.answerScheduleQuestion(provider, 'prochain bus AFTU 30 à Liberte 5 TEST').sentence, L.SENTENCES.NO_RELIABLE_DATA);
    assert.equal(L.answerScheduleQuestion(provider, 'prochain bus AFTU 30 à Yeumbeul TEST', { time: '23:00' }).sentence, L.SENTENCES.NO_RELIABLE_DATA);
    assert.equal(L.answerScheduleQuestion(provider, 'Où est le bus ?').handled, false);

    // Sans couche CETUD (état réel du dépôt) : fallback LOT 18 BIS exact, jamais un horaire PassBi.
    const real = L.buildProvider({ asOf: '2026-09-26', now: NOW_SAT });
    assert.equal(real.layers.cetud.status, 'ABSENT');
    const absent = real.provider;
    assert.equal(L.answerScheduleQuestion(absent, 'Prochain bus AFTU 30 à l\'arrêt Colobane ?').sentence, 'Je n\'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis.');
    assert.equal(L.answerScheduleQuestion(absent, 'Prochain bus DDD 16 à Liberté 5 ?').sentence, L.SENTENCES.NO_RELIABLE_DATA);
    assert.equal(L.answerScheduleQuestion(absent, 'ligne A30CG AFTU à Colobane').handled, false, 'code interne PassBi non reconnu comme numéro de ligne');
    // Ligne connue uniquement par une référence historique déclarée → phrase LOT 18.
    const histProv = new L.FeedProvenance({ source: 'Fixture historique', sourceType: 'SOURCE_APPLICATION', declaredStatus: 'HISTORICAL', validFrom: '2024-01-01', validTo: '2024-12-31', network: 'AFTU' });
    const hist = L.loadFeedFromTexts(Object.fromEntries(Object.entries(AFTU_TEXTS).map(([k, v]) => [k.replace('.txt', ''), v])), histProv, { network: 'AFTU' });
    const onlyHist = new L.TransitDataProvider({ now: NOW_SAT });
    onlyHist.registerSource(new L.GtfsScheduleService(hist.feed), { role: 'historicalReference' });
    const known = L.answerScheduleQuestion(onlyHist, 'Prochain bus AFTU 30 à l\'arrêt Yeumbeul TEST ?');
    assert.equal(known.status, 'UNKNOWN');
    assert.equal(known.reason, 'LINE_KNOWN_NO_CURRENT_SOURCE');
    assert.equal(known.sentence, 'Je connais la ligne, mais je n\'ai pas actuellement d\'horaire suffisamment fiable pour annoncer un départ précis.');
    // Le miroir Dart doit porter les mêmes phrases.
    const dart = fs.readFileSync(path.join(ROOT, 'flutter-src', 'lib', 'services', 'external_gtfs', 'schedule_assistant.dart'), 'utf8');
    assert.ok(dart.includes(L.SENTENCES.NO_RELIABLE_DATA));
    assert.ok(dart.includes(L.SENTENCES.KNOWN_LINE_NO_SCHEDULE));
  } finally {
    fx.cleanup();
  }
});
