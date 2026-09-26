// All frequency entries and crosswalks below are synthetic TEST fixtures.
// Nothing in this test installs production frequencies or edits network data.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/transport_network.dart' as ui;
import 'package:dakar_bus/services/external_gtfs/cetud_feed_bootstrap.dart';
import 'package:dakar_bus/services/external_gtfs/departure_adapter.dart';
import 'package:dakar_bus/services/external_gtfs/feed_provenance.dart';
import 'package:dakar_bus/services/external_gtfs/frequency_source.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_feed.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_schedule_service.dart';
import 'package:dakar_bus/services/external_gtfs/schedule_assistant.dart';
import 'package:dakar_bus/services/external_gtfs/transit_data_provider.dart';
import 'external_gtfs_test.dart' show aftuTexts, cetudProvenance;
import 'schedule_assistant_status_test.dart' show RealtimeFixtureProvider;

FeedProvenance provenance(String network, {bool historical = false}) => FeedProvenance(
  source: 'TEST frequency', sourceType: 'SOURCE_INSTITUTIONAL',
  declaredStatus: historical ? 'HISTORICAL' : 'CURRENT',
  validFrom: '2026-01-01', validTo: '2026-12-31', network: network,
  url: 'https://example.invalid/TEST', publishedAt: '2026-01-01');

FrequencySource frequency(String network) => FrequencySource(network == 'TER' ? [
  FrequencyEntry(network: network, lineNumber: '1', routeIds: ['TEST_TER'],
    headwayMinutes: 10, days: ['monday','tuesday','wednesday','thursday','friday','saturday'],
    from: '05:30', to: '20:59:59'),
  FrequencyEntry(network: network, lineNumber: '1', routeIds: ['TEST_TER'],
    headwayMinutes: 20, days: ['monday','tuesday','wednesday','thursday','friday','saturday'],
    from: '21:00', to: '21:59:59'),
  FrequencyEntry(network: network, lineNumber: '1', routeIds: ['TEST_TER'],
    headwayMinutes: 20, days: ['sunday'], from: '06:30', to: '21:59:59'),
] : [FrequencyEntry(network: network, lineNumber: '1', routeIds: ['TEST_BRT'],
    headwayMinutes: 6, from: '06:00', to: '20:59:59')], provenance(network));

DepartureBinding binding(String network, {String stop = 'TEST_A',
    String? providerRoute, String? providerStop, bool applies = true}) => DepartureBinding(
  network: network, routeId: 'TEST_$network', stopId: stop,
  providerRouteId: providerRoute ?? 'TEST_$network',
  providerStopId: providerStop, frequencyAppliesAtStop: applies);

app.Stop stop(String network, {String id = 'TEST_A', String name = 'TEST origin'}) => app.Stop(
  name: name, stopId: id, scheduleRouteId: 'TEST_$network', direction: '',
  distanceMeters: 0, departureMinutesFromMidnight: const [],
  icon: Icons.train, color: Colors.blue, location: const LatLng(14.7, -17.4),
  modeLabel: network);

void connect(TransitDataProvider p, List<DepartureBinding> bindings) {
  app.transitDataProvider = p;
  app.appDataService.departureAdapter = DepartureAdapter(p, bindings: bindings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late TransitDataProvider provider;
  late TransitDataProvider previousProvider;
  late DepartureAdapter? previousAdapter;
  late List<app.Stop> previousStops;
  setUp(() {
    previousProvider = app.transitDataProvider;
    previousAdapter = app.appDataService.departureAdapter;
    previousStops = List.of(app.allStops);
    now = DateTime.utc(2026, 9, 26, 10);
    provider = TransitDataProvider(now: () => now);
    provider.registerSource(frequency('TER'), role: ProviderRoles.currentFrequency);
    provider.registerSource(frequency('BRT'), role: ProviderRoles.currentFrequency);
    connect(provider, [binding('TER'), binding('TER', stop: 'TEST_B'), binding('BRT')]);
  });
  tearDown(() {
    app.transitDataProvider = previousProvider;
    app.appDataService.departureAdapter = previousAdapter;
    app.allStops..clear()..addAll(previousStops);
  });

  test('1, 9: provider → DataService → Stop is ESTIMATED, never exact', () {
    final s = stop('TER');
    expect(s.scheduleStatus, ui.ScheduleStatus.estimated);
    expect(s.departureInfo.estimatedWaitFrom, 0);
    expect(s.departureInfo.estimatedWaitTo, 10);
    expect(s.departureInfo.scheduledTime, isNull);
    expect(s.departureMinutesFromMidnight, isEmpty);
    expect(s.nextDepartureMinutes(), isNull);
    expect(s.departureAfter(600), isNull);
    expect(s.departureInfo.evidence!.source, 'TEST frequency');
    expect(s.copyWith(name: 'TEST copy').scheduleStatus, ui.ScheduleStatus.estimated);
  });
  test('2, 3: inactive and 21:00 boundary without overlap', () {
    final s = stop('TER');
    now = DateTime.utc(2026, 9, 26, 5, 29, 59);
    expect(s.scheduleStatus, ui.ScheduleStatus.unknown);
    now = DateTime.utc(2026, 9, 26, 20, 59, 59);
    expect(s.departureInfo.frequencyMinutes, 10);
    now = DateTime.utc(2026, 9, 26, 21);
    expect(s.departureInfo.frequencyMinutes, 20);
    now = DateTime.utc(2026, 9, 26, 22);
    expect(s.scheduleStatus, ui.ScheduleStatus.unknown);
    now = DateTime.utc(2026, 9, 27, 6, 30);
    expect(s.departureInfo.frequencyMinutes, 20);
  });
  test('4, 5, 6: BRT scoped fixture estimated; DDD/AFTU/TATA unknown', () {
    expect(stop('BRT').scheduleStatus, ui.ScheduleStatus.estimated);
    for (final network in ['DDD', 'AFTU', 'TATA']) {
      expect(stop(network).scheduleStatus, ui.ScheduleStatus.unknown);
    }
  });
  test('7: SCHEDULED retains provider time', () {
    final p = TransitDataProvider(now: () => DateTime.utc(2026, 9, 26, 7, 30));
    p.registerSource(GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts,
        cetudProvenance('AFTU'), network: 'AFTU')), role: ProviderRoles.currentOfficial);
    connect(p, [binding('AFTU', providerRoute: 'TEST_AFTU_R30', providerStop: 'TEST_S_Y')]);
    final s = stop('AFTU');
    expect(s.scheduleStatus, ui.ScheduleStatus.scheduled);
    expect(s.nextDepartureMinutes(), 462);
    expect(s.departureAfter(450), 462);
    expect(s.departureInfo.label, 'Départ 07h42\nProgrammé');
  });
  test('8: REAL_TIME only relayed from current provider fixture', () {
    for (final current in [true, false]) {
      connect(RealtimeFixtureProvider(current),
          [binding('AFTU', providerRoute: 'TEST_AFTU_R30', providerStop: 'TEST_S_Y')]);
      final s = stop('AFTU');
      expect(s.scheduleStatus, current ? ui.ScheduleStatus.realTime : ui.ScheduleStatus.unknown);
      expect(s.nextDepartureMinutes(), isNull);
      if (current) expect(s.departureInfo.label, 'Arrivée dans 12 min\nTemps réel');
    }
  });
  test('10: Paris offset and Dakar represent the same service instant', () {
    now = DateTime.parse('2026-09-26T22:59:59+02:00');
    final paris = stop('TER').departureInfo;
    now = DateTime.parse('2026-09-26T20:59:59Z');
    expect(stop('TER').departureInfo.frequencyMinutes, paris.frequencyMinutes);
    expect(paris.frequencyMinutes, 10);
    now = DateTime.parse('2026-09-26T23:00:00+02:00');
    expect(stop('TER').departureInfo.frequencyMinutes, 20);
  });
  testWidgets('11: Explorer StopCard consumes ESTIMATED', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        app.StopCard(stop: stop('TER'), distanceMeters: 0))));
    expect(find.text('Prochain passage\ndans 0–10 min\nEstimation'), findsOneWidget);
    expect(find.text('Horaire indisponible'), findsNothing);
  });
  testWidgets('12: DetailedRoutePage uses the same estimate mapping', (tester) async {
    final route = app.DetailedRoute(routeId: 'TEST_TER', lineNumber: 1,
      operator: 'TEST operator label', scheduleNetwork: 'TER', color: Colors.blue,
      origin: 'TEST origin', destination: 'TEST destination', totalDistance: '0 km', stops: [
        const app.DetailedStop(stopId: 'TEST_A', name: 'TEST origin',
          location: LatLng(14.7, -17.4), distanceFromStart: '0 km', estimatedTime: ''),
      ]);
    await tester.pumpWidget(MaterialApp(home: app.DetailedRoutePage(route: route)));
    await tester.ensureVisible(find.text('Prochain passage\ndans 0–10 min\nEstimation'));
    await tester.pump();
    expect(find.text('Prochain passage\ndans 0–10 min\nEstimation'), findsOneWidget);
  });
  test('13: planner keeps uncertainty and no fabricated exact departure', () {
    app.allStops..clear()..addAll([stop('TER'), stop('TER', id: 'TEST_B', name: 'TEST destination')]);
    final r = app.RoutePlanner.plan(fromQuery: 'TEST origin', toQuery: 'TEST destination').routes.first;
    expect(r.status, app.DataStatus.estimated);
    expect(r.segments.first.departureTime, isNull);
    expect(r.segments.first.arrivalTime, isNull);
    expect(r.segments.first.departureInfo!.estimatedWaitTo, 10);
    expect(app.AssistantReplies.itinerary(r, r.fromName, r.toName), contains('Estimation'));
  });
  test('14: assistant uses the exact same provider and remains estimated', () {
    expect(identical(app.appDataService.departureAdapter!.provider, app.transitDataProvider), isTrue);
    expect(answerScheduleQuestion(app.transitDataProvider,
        'Prochain TER 1 à TEST origin ?').status, 'ESTIMATED');
  });
  test('CETUD absent does not erase independent CURRENT frequencies', () async {
    final boot = await bootstrapCetudFeedLayer(now: () => now,
      loadText: (_) async => throw StateError('absent TEST'),
      frequencySources: [frequency('TER')]);
    expect(boot.layerStatus, CetudLayerStatus.absent);
    connect(boot.provider, [binding('TER')]);
    expect(stop('TER').scheduleStatus, ui.ScheduleStatus.estimated);
  });
  test('no crosswalk, ambiguous crosswalk, unverified stop or expired source → UNKNOWN', () {
    for (final bindings in <List<DepartureBinding>>[
      [], [binding('TER'), binding('TER')], [binding('TER', applies: false)],
    ]) {
      connect(provider, bindings);
      expect(stop('TER').scheduleStatus, ui.ScheduleStatus.unknown);
    }
    connect(provider, [binding('TER')]);
    now = DateTime.utc(2027, 1, 1, 10);
    expect(stop('TER').scheduleStatus, ui.ScheduleStatus.unknown);
  });
  test('historical frequency cannot be registered as CURRENT', () {
    final historical = FrequencySource(frequency('TER').entries,
        provenance('TER', historical: true));
    expect(() => provider.registerSource(historical, role: ProviderRoles.currentFrequency),
        throwsStateError);
  });
}
