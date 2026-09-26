// LOT 18 BIS — miroir Dart du moteur GTFS externe : provenance stricte,
// horaires depuis stop_times uniquement, priorité CETUD CURRENT, assistant.
// Fixture SYNTHÉTIQUE (identifiants TEST_*), aucune donnée réelle.

import 'package:dakar_bus/services/external_gtfs/cetud_feed_bootstrap.dart';
import 'package:dakar_bus/services/external_gtfs/feed_provenance.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_csv.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_feed.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_schedule_service.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_time.dart';
import 'package:dakar_bus/services/external_gtfs/schedule_assistant.dart';
import 'package:dakar_bus/services/external_gtfs/transit_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, String> aftuTexts = <String, String>{
  'agency':
      'agency_id,agency_name,agency_url,agency_timezone\nTEST_AFTU,AFTU TEST,https://example.invalid/aftu,Africa/Dakar\n',
  'routes':
      'route_id,agency_id,route_short_name,route_long_name,route_type\nTEST_AFTU_R30,TEST_AFTU,30,Fixture A - Fixture C,3\nTEST_AFTU_R31_NOSHORT,TEST_AFTU,,Sans numero public,3\n',
  'stops':
      'stop_id,stop_name,stop_lat,stop_lon\nTEST_S_Y,Yeumbeul TEST,14.77,-17.37\nTEST_S_YA,Yeumbeul A TEST,14.771,-17.371\nTEST_S_B,Fixture B,14.75,-17.40\nTEST_S_C,Fixture C,14.73,-17.44\n',
  'calendar':
      'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nTEST_WEEK,1,1,1,1,1,1,0,20260101,20261231\nTEST_SUNDAY,0,0,0,0,0,0,1,20260101,20261231\nTEST_EXPIRED,1,1,1,1,1,1,1,20250101,20251231\n',
  'calendar_dates':
      'service_id;date;exception_type\nTEST_WEEK,20260928,2\nTEST_SUNDAY,20260929,1\n',
  'trips':
      'route_id,service_id,trip_id,trip_headsign,direction_id\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W1,Fixture C,0\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W2,Fixture C,0\nTEST_AFTU_R30,TEST_WEEK,TEST_T_W3,Yeumbeul TEST,1\nTEST_AFTU_R30,TEST_SUNDAY,TEST_T_S1,Fixture C,0\nTEST_AFTU_R30,TEST_EXPIRED,TEST_T_X1,Fixture C,0\nTEST_AFTU_R31_NOSHORT,TEST_WEEK,TEST_T_N1,Fixture C,0\n',
  'stop_times': 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\n'
      'TEST_T_W1,07:42:00,07:42:00,TEST_S_Y,1\nTEST_T_W1,07:50:00,07:50:00,TEST_S_B,2\nTEST_T_W1,08:00:00,08:00:00,TEST_S_C,3\n'
      'TEST_T_W2,08:12:00,08:12:00,TEST_S_Y,1\nTEST_T_W2,08:20:00,08:20:00,TEST_S_B,2\nTEST_T_W2,08:30:00,08:30:00,TEST_S_C,3\n'
      'TEST_T_W3,09:00:00,09:00:00,TEST_S_C,1\nTEST_T_W3,09:10:00,09:10:00,TEST_S_B,2\nTEST_T_W3,09:20:00,09:20:00,TEST_S_Y,3\n'
      'TEST_T_S1,09:00:00,09:00:00,TEST_S_Y,1\nTEST_T_S1,09:10:00,09:10:00,TEST_S_B,2\nTEST_T_S1,09:20:00,09:20:00,TEST_S_C,3\n'
      'TEST_T_X1,07:30:00,07:30:00,TEST_S_Y,1\nTEST_T_X1,07:40:00,07:40:00,TEST_S_B,2\nTEST_T_X1,07:50:00,07:50:00,TEST_S_C,3\n'
      'TEST_T_N1,07:35:00,07:35:00,TEST_S_YA,1\nTEST_T_N1,07:45:00,07:45:00,TEST_S_B,2\nTEST_T_N1,07:55:00,07:55:00,TEST_S_C,3\n',
  'feed_info':
      'feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version\nCETUD TEST,https://example.invalid/cetud,fr,20260101,20261231,TEST-2026.1\n',
};

const Map<String, String> dddTexts = <String, String>{
  'agency': 'agency_id,agency_name,agency_url,agency_timezone\nTEST_DDD,Dem Dikk TEST,https://example.invalid/ddd,Africa/Dakar\n',
  'routes':
      'route_id,agency_id,route_short_name,route_long_name,route_type\nTEST_DDD_R16,TEST_DDD,16,Fixture L5 - Fixture X,3\nTEST_DDD_R16A,TEST_DDD,16A,Fixture L5 - Fixture X variante,3\n',
  'stops': 'stop_id,stop_name,stop_lat,stop_lon\nTEST_D_L5,Liberte 5 TEST,14.72,-17.46\nTEST_D_X,Fixture X,14.70,-17.47\n',
  'calendar':
      'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nTEST_DDD_ALL,1,1,1,1,1,1,1,20260101,20261231\n',
  'trips':
      'route_id,service_id,trip_id,trip_headsign,direction_id\nTEST_DDD_R16,TEST_DDD_ALL,TEST_D16_1,Fixture X,0\nTEST_DDD_R16A,TEST_DDD_ALL,TEST_D16A_1,Fixture X,0\n',
  'stop_times':
      'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nTEST_D16_1,10:05:00,10:05:00,TEST_D_L5,1\nTEST_D16_1,10:20:00,10:20:00,TEST_D_X,2\nTEST_D16A_1,10:01:00,10:01:00,TEST_D_L5,1\nTEST_D16A_1,10:15:00,10:15:00,TEST_D_X,2\n',
};

FeedProvenance cetudProvenance(String network) => FeedProvenance(
      source: 'CETUD',
      sourceType: 'OFFICIAL_STATIC_CURRENT',
      feedVersion: 'TEST-2026.1',
      validFrom: '2026-01-01',
      validTo: '2026-12-31',
      declaredStatus: 'CURRENT',
      authority: 'CETUD',
      sourceId: 'cetud/test_${network.toLowerCase()}',
      network: network,
    );

FeedProvenance passbiProvenance(String network) => FeedProvenance(
      source: 'PassBi',
      sourceType: 'SOURCE_APPLICATION',
      feedVersion: 'fixture',
      validFrom: '2022-01-01',
      validTo: '2023-12-31',
      declaredStatus: 'HISTORICAL',
      sourceId: 'passbi/test_${network.toLowerCase()}',
      network: network,
    );

DateTime saturday0730() => DateTime.utc(2026, 9, 26, 7, 30);

const String manifestJson = '''
{"schema":"dakar-bus/external-gtfs-feed-manifest/v1","feeds":[
 {"id":"cetud/test_aftu","source":"CETUD","source_type":"OFFICIAL_STATIC_CURRENT","status":"CURRENT","role":"CURRENT_OFFICIAL",
  "network":"AFTU","authority":"CETUD","version":"TEST-2026.1","valid_from":"2026-01-01","valid_to":"2026-12-31",
  "published_at":"2026-01-05","tables":["agency","routes","stops","trips","stop_times","calendar","calendar_dates","feed_info"]}
]}
''';

void main() {
  test('CSV : délimiteur d\'en-tête « ; » et corps « , » (quirk PassBi) ; heures GTFS', () {
    final CsvTable t = parseCsv(aftuTexts['calendar_dates']!);
    expect(t.header, <String>['service_id', 'date', 'exception_type']);
    expect(t.rows.length, 2);
    expect(t.rows.first, <String>['TEST_WEEK', '20260928', '2']);
    expect(parseGtfsTime('07:42:00'), 7 * 3600 + 42 * 60);
    expect(parseGtfsTime('25:10:00'), 25 * 3600 + 600);
    expect(parseGtfsTime('7h42'), isNull);
    expect(normalizeServiceDate('2026-09-26'), '20260926');
    expect(weekdayOf('20260926'), 'saturday');
    expect(dakarClock(saturday0730()).time, '07:30:00');
  });

  test('Feed synthétique : construction, validation, calendrier (calendar_dates appliqués)', () {
    final GtfsFeed feed = GtfsFeed.fromTexts(aftuTexts, cetudProvenance('AFTU'), network: 'AFTU');
    final FeedValidation v = validateFeed(feed);
    expect(v.ok, isTrue, reason: v.errors.join(' ; '));
    expect(feed.counts['routes'], 2);
    expect(feed.counts['stop_times'], 18);
    expect(feed.services['TEST_WEEK']!.removedDates, contains('20260928'));
    expect(feed.isServiceActive('TEST_WEEK', '20260928'), isFalse);
    expect(feed.isServiceActive('TEST_SUNDAY', '20260929'), isTrue);
    expect(feed.isServiceActive('TEST_EXPIRED', '20260926'), isFalse);
    expect(v.warnings, contains('ROUTE_SHORT_NAME_MISSING: 1 route(s)'));
    final Map<String, String> broken = Map<String, String>.of(aftuTexts);
    broken['stop_times'] = '${aftuTexts['stop_times']}TEST_T_GHOST,25:99:00,7h42,TEST_S_NOPE,1\n';
    final FeedValidation bv = validateFeed(GtfsFeed.fromTexts(broken, cetudProvenance('AFTU')));
    expect(bv.ok, isFalse);
    expect(bv.errors.any((String e) => e.startsWith('INVALID_TIME')), isTrue);
    expect(bv.errors.any((String e) => e.contains('trip_id inconnu')), isTrue);
  });

  test('Provider : HISTORICAL jamais actuel, currentOfficial exige une source institutionnelle', () {
    final TransitDataProvider provider = TransitDataProvider(now: saturday0730);
    final GtfsScheduleService passbi = GtfsScheduleService(
        GtfsFeed.fromTexts(aftuTexts, passbiProvenance('AFTU'), network: 'AFTU'));
    expect(() => provider.registerSource(passbi, role: ProviderRoles.currentOfficial), throwsStateError);
    expect(() => provider.registerSource(passbi, role: ProviderRoles.currentApplication), throwsStateError);
    provider.registerSource(passbi, role: ProviderRoles.historicalReference);
    final DepartureResult now = provider.getDeparturesNow('TEST_AFTU_R30', 'TEST_S_Y');
    expect(now.status, ScheduleStatus.unknown);
    expect(now.isCurrent, isFalse);
    expect(now.historicalReferenceAvailable, isTrue);
    final DepartureResult hist =
        provider.getHistoricalDepartures('TEST_AFTU_R30', 'TEST_S_Y', date: '2023-03-15', time: '07:40');
    expect(hist.provenanceLevel, ProvenanceLevels.historicalReference);
    expect(hist.isCurrent, isFalse);
    // Un feed CETUD ne peut pas être enregistré comme application, ni l'inverse.
    final GtfsScheduleService cetud =
        GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts, cetudProvenance('AFTU'), network: 'AFTU'));
    expect(() => provider.registerSource(cetud, role: ProviderRoles.currentApplication), throwsStateError);
    expect(TransitDataProvider().sources, isEmpty);
  });

  test('CETUD CURRENT prioritaire : SCHEDULED depuis stop_times, phrase exacte, DDD 16 ≠ 16A', () {
    final TransitDataProvider provider = TransitDataProvider(now: saturday0730);
    provider.registerSource(
        GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts, passbiProvenance('AFTU'), network: 'AFTU')),
        role: ProviderRoles.historicalReference);
    provider.registerSource(
        GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts, cetudProvenance('AFTU'), network: 'AFTU')),
        role: ProviderRoles.currentOfficial);
    provider.registerSource(
        GtfsScheduleService(GtfsFeed.fromTexts(dddTexts, cetudProvenance('DDD'), network: 'DDD')),
        role: ProviderRoles.currentOfficial);
    expect(provider.winningSource('AFTU', '2026-09-26')!.provenance.source, 'CETUD');
    expect(provider.winningSource('AFTU', '2026-09-26')!.rank, 0);

    final DepartureResult now = provider.getDeparturesNow('TEST_AFTU_R30', 'TEST_S_Y', limit: 2);
    expect(now.status, ScheduleStatus.scheduled);
    expect(now.isCurrent, isTrue);
    expect(now.provenanceLevel, ProvenanceLevels.officialStaticCurrent);
    expect(now.departures.map((Departure d) => d.departureTime).toList(), <String>['07:42:00', '08:12:00']);
    expect(now.departures.first.direction.terminusStopName, 'Fixture C');
    expect(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', date: '2026-09-28', time: '07:00').reason,
        ScheduleReasons.noServiceOnDate);
    expect(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', date: '2026-09-29', time: '08:30').departures.first.tripId,
        'TEST_T_S1');
    expect(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y', date: '2026-09-26', time: '23:00').reason,
        ScheduleReasons.noMoreDepartures);

    final ScheduleQuestion q = parseScheduleQuestion("Prochain bus AFTU 30 à l'arrêt Yeumbeul TEST ?", now: saturday0730());
    expect(q.isScheduleQuestion, isTrue);
    expect(<String?>[q.network, q.lineNumber, q.stopName, q.date, q.time], <String?>['AFTU', '30', 'Yeumbeul TEST', null, null]);
    final ScheduleAnswer a = answerScheduleQuestion(provider, "Prochain bus AFTU 30 à l'arrêt Yeumbeul TEST ?");
    expect(a.status, ScheduleStatus.scheduled);
    expect(
        a.sentence,
        "La ligne AFTU 30 dessert cet itinéraire. Depuis l'arrêt Yeumbeul TEST, le prochain départ programmé est à 07:42. "
        'Direction Fixture C. Source : CETUD (OFFICIAL_STATIC_CURRENT, validité 2026-01-01 → 2026-12-31).');
    expect(a.departure!.tripId, 'TEST_T_W1');
    expect(answerScheduleQuestion(provider, 'AFTU 30 à Yeumbeul le 2026-09-29 à 8h30').departure!.tripId, 'TEST_T_S1');
    expect(answerScheduleQuestion(provider, 'bus AFTU 30 depuis Fixture B direction Yeumbeul').departure!.tripId, 'TEST_T_W3');
    expect(answerScheduleQuestion(provider, 'Quand passe la ligne 16 DDD depuis Liberte 5 TEST ?').sentence,
        startsWith("La ligne DDD 16 dessert cet itinéraire. Depuis l'arrêt Liberte 5 TEST, le prochain départ programmé est à 10:05."));
    expect(answerScheduleQuestion(provider, 'ligne 16A DDD à Liberte 5 TEST').sentence,
        startsWith("La ligne DDD 16A dessert cet itinéraire. Depuis l'arrêt Liberte 5 TEST, le prochain départ programmé est à 10:01."));
    expect(answerScheduleQuestion(provider, 'ligne 31 AFTU à Yeumbeul A TEST').sentence, ScheduleSentences.noReliableData);
    expect(answerScheduleQuestion(provider, 'prochain bus AFTU 30 à Fixture').status, 'AMBIGUOUS_STOP');
    expect(answerScheduleQuestion(provider, 'prochain bus AFTU 30 à Yeumbeul TEST', time: '23:00').sentence,
        ScheduleSentences.noReliableData);
    expect(answerScheduleQuestion(provider, 'Où est le bus ?').handled, isFalse);
  });

  test('Repli exact sans source actuelle ; ligne connue seulement en historique ; feed expiré → UNKNOWN', () {
    final TransitDataProvider empty = TransitDataProvider(now: saturday0730);
    final ScheduleAnswer none = answerScheduleQuestion(empty, "Prochain bus AFTU 30 à l'arrêt Colobane ?");
    expect(none.handled, isTrue);
    expect(none.status, ScheduleStatus.unknown);
    expect(none.sentence, "Je n'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis.");

    final TransitDataProvider onlyHist = TransitDataProvider(now: saturday0730);
    onlyHist.registerSource(
        GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts, passbiProvenance('AFTU'), network: 'AFTU')),
        role: ProviderRoles.historicalReference);
    final ScheduleAnswer known = answerScheduleQuestion(onlyHist, "Prochain bus AFTU 30 à l'arrêt Yeumbeul TEST ?");
    expect(known.reason, 'LINE_KNOWN_NO_CURRENT_SOURCE');
    expect(known.sentence, "Je connais la ligne, mais je n'ai pas actuellement d'horaire suffisamment fiable pour annoncer un départ précis.");

    // Même feed CETUD, horloge en 2027 : validité dépassée → jamais d'heure.
    final TransitDataProvider later = TransitDataProvider(now: () => DateTime.utc(2027, 2, 1, 7, 30));
    later.registerSource(
        GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts, cetudProvenance('AFTU'), network: 'AFTU')),
        role: ProviderRoles.currentOfficial);
    expect(later.getDeparturesNow('TEST_AFTU_R30', 'TEST_S_Y').status, ScheduleStatus.unknown);
    expect(answerScheduleQuestion(later, "Prochain bus AFTU 30 à l'arrêt Yeumbeul TEST ?").sentence,
        ScheduleSentences.knownLineNoSchedule);
  });

  test('Bootstrap : sans manifeste → ABSENT et repli ; avec manifeste + tables → CURRENT_INSTALLED', () async {
    final CetudBootstrapResult absent = await bootstrapCetudFeedLayer(
      loadText: (String key) async => throw StateError('asset absent : $key'),
      now: saturday0730,
    );
    expect(absent.layerStatus, CetudLayerStatus.absent);
    expect(absent.provider.sources, isEmpty);
    expect(answerScheduleQuestion(absent.provider, 'Prochain bus AFTU 30 à Colobane ?').sentence,
        ScheduleSentences.noReliableData);

    final Map<String, String> assets = <String, String>{cetudManifestAsset: manifestJson};
    for (final MapEntry<String, String> e in aftuTexts.entries) {
      assets['$cetudAssetRoot/aftu/${e.key}.txt'] = e.value;
    }
    final CetudBootstrapResult installed = await bootstrapCetudFeedLayer(
      loadText: (String key) async {
        final String? v = assets[key];
        if (v == null) throw StateError('asset absent : $key');
        return v;
      },
      now: saturday0730,
    );
    expect(installed.layerStatus, CetudLayerStatus.currentInstalled, reason: installed.notes.join('\n'));
    expect(installed.provider.sources.single.role, ProviderRoles.currentOfficial);
    expect(answerScheduleQuestion(installed.provider, "Prochain bus AFTU 30 à l'arrêt Yeumbeul TEST ?").sentence,
        startsWith("La ligne AFTU 30 dessert cet itinéraire. Depuis l'arrêt Yeumbeul TEST, le prochain départ programmé est à 07:42."));

    // Manifeste déclarant HISTORICAL avec rôle CURRENT_OFFICIAL : refusé par le provider.
    final Map<String, String> tampered = Map<String, String>.of(assets);
    tampered[cetudManifestAsset] = manifestJson.replaceFirst('"status":"CURRENT"', '"status":"HISTORICAL"');
    final CetudBootstrapResult refused = await bootstrapCetudFeedLayer(
      loadText: (String key) async => tampered[key] ?? (throw StateError('asset absent : $key')),
      now: saturday0730,
    );
    expect(refused.layerStatus, CetudLayerStatus.invalid);
    expect(refused.provider.sources, isEmpty);
  });
}
