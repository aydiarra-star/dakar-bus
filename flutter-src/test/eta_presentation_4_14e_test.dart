import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/departure_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Instants injectés uniquement dans les tests ; aucun horaire n'est ajouté
// aux données ni fabriqué dans les widgets.
final DateTime monday = DateTime.utc(2026, 9, 28, 13, 29);
const String ter = 'ter_dakar_diamniadio';
const String b1 = 'brt_b1_guediawaye_petersen';
const String b2 = 'brt_b2_express';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await app.appDataService.loadNetworkData();
    app.integrateNetworkDataForTest();
  });

  test('TER terminus : 6 min, 1 min, Maintenant, sans nouveau trip', () {
    for (final (minute, expected) in <(int, String)>[
      (29, '🟢 6 min'), (34, '🟢 1 min'), (35, '🟢 Maintenant'),
    ]) {
      final at = DateTime.utc(2026, 9, 28, 13, minute);
      final display = app.departurePresentationForRouteStop(
        routeId: ter, stopId: 'stop_dakar_ter', network: 'TER', at: at,
      );
      expect(display.label, expected);
      expect(display.hasDisplay, isTrue);
      expect(display.operationalStatus, OperationalStatus.normal);
    }
  });

  test('TER intermédiaire et hors plage : aucun texte ni faux ETA', () {
    for (final (stopId, at) in <(String, DateTime)>[
      ('stop_colobane', monday),
      ('stop_dakar_ter', DateTime.utc(2026, 9, 28, 22, 6)),
    ]) {
      final display = app.departurePresentationForRouteStop(
        routeId: ter, stopId: stopId, network: 'TER', at: at,
      );
      expect(display.hasDisplay, isFalse);
      expect(display.label, isEmpty);
      expect(display.operationalStatus, isNull);
    }
  });

  test('BRT B1 et B2 : la fréquence documentée ne crée aucun ETA', () {
    for (final routeId in <String>[b1, b2]) {
      final info = app.appDataService.departureFor(
        routeId: routeId, stopId: 'stop_brt_23_guediawaye',
        network: 'BRT', at: monday,
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
      expect(info.etaAt, isNull);
      expect(DeparturePresentation.at(info, monday).hasDisplay, isFalse);
    }
  });

  test('DDD et AFTU : trips sans stop_times exploitables, pas de passage', () {
    for (final routeId in <String>['ddd_1', 'aftu_1']) {
      final route = app.appDataService.routes.singleWhere((r) => r.id == routeId);
      final info = app.appDataService.departureFor(
        routeId: routeId, stopId: route.stopIds.first,
        network: route.operatorId, at: monday,
      );
      final display = DeparturePresentation.at(info, monday);
      expect(info.etaAt, isNull);
      expect(display.hasDisplay, isFalse);
      expect(display.operationalStatus, isNull);
    }
  });

  test('B1/B2 : sept stations physiques, deux routes sans confusion', () {
    final b2Route = app.appDataService.routes.singleWhere((r) => r.id == b2);
    expect(b2Route.stopIds, hasLength(7));
    for (final stopId in b2Route.stopIds) {
      final shared = app.allStops.where((s) => s.stopId == stopId).toList();
      expect(shared, hasLength(1), reason: stopId);
      final station = shared.single;
      expect(station.scheduleRouteId, b1, reason: stopId);
      expect(station.servedRouteIds, containsAll(<String>[b1, b2]));
      expect(station.servesRoute('ddd_1'), isFalse);
      expect(station.copyWith().servedRouteIds, containsAll(<String>[b1, b2]));
      final b1Info = station.departureInfoForRouteAt(b1, at: monday);
      final b2Info = station.departureInfoForRouteAt(b2, at: monday);
      expect(b1Info.routeId, b1);
      expect(b2Info.routeId, b2);
      expect(b1Info.etaAt, isNull);
      expect(b2Info.etaAt, isNull);
      expect(station.departureInfoForRouteAt('ddd_1', at: monday).status,
          ScheduleStatus.unknown);
      expect(app.DetailedRoute.fromStop(station)!.routeId, b1,
          reason: 'le routage primaire de $stopId reste intact');
    }
  });

  test('UNKNOWN sans preuve ne devient jamais jaune ni rouge', () {
    final info = DepartureInfo.unknown(
      operator: 'DDD', routeId: 'ddd_1', requestedAt: monday,
    );
    final display = DeparturePresentation.at(info, monday);
    expect(display.hasDisplay, isFalse);
    expect(display.operationalStatus, isNull);
    expect(display.label, isNot(contains('🟡')));
    expect(display.label, isNot(contains('🔴')));
  });

  testWidgets('DetailedRoutePage affiche le TER calculable, pas les replis',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final route = app.DetailedRoute.fromOperator('ter')!;
    await tester.pumpWidget(MaterialApp(
      home: app.DetailedRoutePage(route: route, at: monday),
    ));
    expect(find.text('🟢 6 min'), findsOneWidget);
    expect(find.text('Passage non communiqué'), findsNothing);
    expect(find.text('Horaire indisponible'), findsNothing);
  });

  testWidgets('StopCard BRT et SingleStopView sans ETA masquent le passage',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final station = app.allStops.firstWhere(
        (s) => s.stopId == 'stop_brt_23_guediawaye');
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: app.StopCard(stop: station, distanceMeters: 300),
    )));
    expect(find.text('Passage non communiqué'), findsNothing);
    expect(find.textContaining('Passage estimé'), findsNothing);
    expect(find.text('🟢 6 min'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: app.SingleStopView(stop: station),
    )));
    expect(find.text('Prochain passage'), findsNothing);
    expect(find.text('Passage non communiqué'), findsNothing);
  });
}
