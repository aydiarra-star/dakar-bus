import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/departure_presentation.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

DateTime _at(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(year, month, day, hour, minute);

// Exclusivement des fixtures : aucun trip fictif n'entre dans les assets.
ScheduleDataset _syntheticSchedule(String routeId, String stopId) {
  return ScheduleDataset(
    trips: [Trip(routeId: routeId, tripId: 'synthetic_${routeId}_trip',
        serviceId: 'synthetic_service', directionId: 0)],
    stopTimes: [StopTime(tripId: 'synthetic_${routeId}_trip', stopId: stopId,
        stopSequence: 1, departureTime: ServiceTime(13, 40, 0))],
    services: [Service(serviceId: 'synthetic_service',
        monday: true, tuesday: true, wednesday: true, thursday: true,
        friday: true, saturday: true, sunday: true,
        startDate: ServiceDate(2026, 9, 21), endDate: ServiceDate(2026, 10, 10))],
    provenance: ScheduleProvenance(
      source: 'fixture://only-not-production',
      sourceType: SourceType.officialStatic,
      dateSource: ServiceDate(2026, 9, 21),
      dateVerified: ServiceDate(2026, 9, 21),
      validFrom: ServiceDate(2026, 9, 21),
      validTo: ServiceDate(2026, 10, 10),
      confidence: 0.99, scheduleStatus: ScheduleStatus.scheduled,
      coverage: ScheduleCoverage(complete: true, scopes: [
        ScheduleCoverageScope(routeId: routeId, stopId: stopId,
            allDirections: true),
      ]),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DataService service;
  setUpAll(() async {
    await app.appDataService.loadNetworkData();
  });
  setUp(() async {
    service = DataService();
    await service.loadNetworkData();
  });

  group('TER — deux terminus, cadence ancrée officiellement', () {
    test('Dakar lundi : 7, 6, 1 min puis Maintenant, sans trip fabriqué', () {
      for (final (minute, expected) in <(int, String)>[
        (28, '🟢 7 min'), (29, '🟢 6 min'),
        (34, '🟢 1 min'), (35, '🟢 Maintenant'),
      ]) {
        final at = _at(2026, 9, 28, 13, minute);
        final info = service.departureFor(
          routeId: 'ter_dakar_diamniadio', stopId: 'stop_dakar_ter',
          network: 'TER', at: at,
        );
        expect(DeparturePresentation.at(info, at).label, expected);
        expect(info.status, ScheduleStatus.estimated);
        expect(info.etaSource, EtaSource.combined);
        expect(info.tripId, isNull);
        expect(info.scheduledTime, isNull);
        expect(info.source, contains('terdakar.sn'));
        expect(info.calculationMethod, 'OPERATOR_TERMINAL_FIRST_DEPARTURE_AND_HEADWAY');
      }
    });

    test('Diamniadio lundi : 05:29→05:35 ; Dakar dimanche 06:18→06:25', () {
      final monday = _at(2026, 9, 28, 5, 29);
      final diamniadio = service.departureFor(
        routeId: 'ter_dakar_diamniadio', stopId: 'stop_diamniadio',
        network: 'TER', at: monday,
      );
      expect(DeparturePresentation.at(diamniadio, monday).label, '🟢 6 min');
      expect(diamniadio.etaAt, _at(2026, 9, 28, 5, 35));
      final sunday = _at(2026, 9, 27, 6, 18);
      final dakar = service.departureFor(
        routeId: 'ter_dakar_diamniadio', stopId: 'stop_dakar_ter',
        network: 'TER', at: sunday,
      );
      expect(DeparturePresentation.at(dakar, sunday).label, '🟢 7 min');
      expect(dakar.etaAt, _at(2026, 9, 27, 6, 25));
      final noReverseAnchor = service.departureFor(
        routeId: 'ter_dakar_diamniadio', stopId: 'stop_diamniadio',
        network: 'TER', at: sunday,
      );
      expect(noReverseAnchor.etaAt, isNull,
          reason: '06:25 dimanche : pas de départ Diamniadio prouvé');
    });

    test('transition soir, fin de plage et aucun passage aux gares intermédiaires', () {
      final evening = _at(2026, 9, 28, 20, 56);
      expect(service.departureFor(routeId: 'ter_dakar_diamniadio',
          stopId: 'stop_dakar_ter', network: 'TER', at: evening).etaAt,
          _at(2026, 9, 28, 21, 5));
      final last = _at(2026, 9, 28, 22, 5);
      expect(service.departureFor(routeId: 'ter_dakar_diamniadio',
          stopId: 'stop_dakar_ter', network: 'TER', at: last).etaAt, last);
      final tooLate = _at(2026, 9, 28, 22, 6);
      final info = service.departureFor(routeId: 'ter_dakar_diamniadio',
          stopId: 'stop_dakar_ter', network: 'TER', at: tooLate);
      expect(DeparturePresentation.at(info, tooLate).label,
          DeparturePresentation.noEta);
      final at = _at(2026, 9, 28, 13, 29);
      for (final stopId in ['stop_colobane', 'stop_hann',
          'stop_dalifort_ter', 'stop_rufisque']) {
        final info = service.departureFor(routeId: 'ter_dakar_diamniadio',
            stopId: stopId, network: 'TER', at: at);
        expect(info.etaAt, isNull, reason: stopId);
        expect(DeparturePresentation.at(info, at).label,
            DeparturePresentation.noEta, reason: stopId);
      }
    });

    test('pas d’ETA au mauvais arrêt, pour route seule ou sens GTFS inconnu', () {
      final now = _at(2026, 9, 28, 13, 29);
      for (final stopId in [null, 'stop_brt_01_petersen', 'nonexistent_stop']) {
        final info = service.departureInfoForRoute('ter_dakar_diamniadio',
            now, stopId: stopId);
        expect(info.etaAt, isNull, reason: '$stopId');
      }
      final wrongDirection = service.departureInfoForRoute('ter_dakar_diamniadio',
          now, stopId: 'stop_dakar_ter', directionId: 1);
      expect(wrongDirection.etaAt, isNull);
    });

    test('Stop → RoutePlanner → segment → Assistant : une seule ETA', () {
      final at = _at(2026, 9, 28, 13, 29);
      app.Stop fixtureStop(String name, String stopId, double lat) => app.Stop(
        name: name, stopId: stopId, scheduleRouteId: 'ter_dakar_diamniadio',
        modeLabel: 'TER', direction: 'Diamniadio', distanceMeters: 0,
        departureMinutesFromMidnight: const [], icon: Icons.train,
        color: app.AppColors.ter, location: LatLng(lat, -17.43),
      );
      final origin = fixtureStop('TER départ Dakar', 'stop_dakar_ter', 14.676);
      final destination = fixtureStop('TER arrivée Colobane', 'stop_colobane', 14.686);
      expect(app.departureDisplayLabel(origin.departureInfoAt(at: at)),
          '🟢 6 min');
      final saved = List<app.Stop>.of(app.allStops);
      try {
        app.allStops..clear()..addAll([origin, destination]);
        final result = app.RoutePlanner.plan(
          fromQuery: origin.name, toQuery: destination.name, at: at);
        expect(result.hasRoutes, isTrue);
        final info = result.routes.first.segments.first.departureInfo!;
        expect(info.etaAt, _at(2026, 9, 28, 13, 35));
        expect(result.routes.first.segments.first.departureTime, isNull);
        expect(app.AssistantReplies.itinerary(result.routes.first,
            origin.name, destination.name), contains('🟢 6 min'));
      } finally {
        app.allStops..clear()..addAll(saved);
      }
    });

    test('le calculateur exige phase, même date et fenêtre valide', () {
      expect(EtaCalculator.anchoredTerminalEta(
        firstDepartureAt: _at(2026, 9, 28, 5, 45),
        lastDepartureAt: _at(2026, 9, 28, 20, 55),
        headway: const Duration(minutes: 10),
        nowUtc: _at(2026, 9, 28, 13, 28),
      ), _at(2026, 9, 28, 13, 35));
      expect(EtaCalculator.anchoredTerminalEta(
        firstDepartureAt: _at(2026, 9, 28, 5, 45),
        lastDepartureAt: _at(2026, 9, 28, 20, 55),
        headway: Duration.zero,
        nowUtc: _at(2026, 9, 28, 13, 28),
      ), isNull);
      expect(EtaCalculator.anchoredTerminalEta(
        firstDepartureAt: _at(2026, 9, 28, 5, 45),
        lastDepartureAt: _at(2026, 9, 28, 20, 55),
        headway: const Duration(minutes: 10),
        nowUtc: _at(2026, 9, 29, 5, 45),
      ), isNull);
    });
  });

  group('couverture réelle par réseau et chemin générique pour sources futures', () {
    const candidates = <(String, String?, String)>[
      ('brt_b1_guediawaye_petersen', 'stop_brt_23_guediawaye', 'BRT B1'),
      ('brt_b2_express', 'stop_brt_23_guediawaye', 'BRT B2'),
      ('brt_b3', null, 'BRT B3 (non exposé)'),
      ('ddd_1', null, 'DDD'),
      ('aftu_1', null, 'AFTU'),
      ('new_mode', null, 'nouvelle mobilité'),
    ];
    for (final (routeId, stopId, network) in candidates) {
      test('$network : pas de faux départ issu de la fréquence/structure', () {
        final now = _at(2026, 9, 28, 13, 33);
        final info = service.departureFor(
          routeId: routeId, stopId: stopId, network: network, at: now);
        expect(info.etaAt, isNull, reason: network);
        expect(info.operationalStatus, isNull, reason: network);
        expect(DeparturePresentation.at(info, now).label,
            DeparturePresentation.noEta, reason: network);
      });

      test('$network : un horaire authentifié injecté passe par le même moteur', () {
        final stop = stopId ?? 'synthetic_${routeId}_stop';
        final injected = DataService(scheduleProvider: InMemoryScheduleProvider(
            _syntheticSchedule(routeId, stop)));
        final now = _at(2026, 9, 28, 13, 33);
        final info = injected.departureFor(routeId: routeId, stopId: stop,
            network: network, at: now);
        expect(info.etaAt, _at(2026, 9, 28, 13, 40));
        expect(info.etaSource, EtaSource.schedule);
        expect(DeparturePresentation.at(info, now).label, '🟢 7 min');
        final segment = app.RouteSegment(modeLabel: network,
            color: app.AppColors.ter, icon: Icons.train,
            from: 'A', to: 'B', durationMinutes: 10,
            departureInfo: info, departureTime: '09:00');
        final planned = app.PlannedRoute(fromName: 'A', toName: 'B',
            segments: [segment], totalMinutes: 10);
        final reply = app.AssistantReplies.itinerary(planned, 'A', 'B');
        expect(reply, contains('🟢 7 min'));
        expect(reply, isNot(contains('09:00')));
      });
    }
  });

  test('l’absence de donnée ne change jamais un état normal en incident', () {
    final info = service.departureFor(routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_23_guediawaye', network: 'BRT',
        at: _at(2026, 9, 28, 13, 33));
    expect(info.frequencyMinutes, 6);
    expect(info.etaAt, isNull);
    expect(info.operationalStatus, isNull);
    final label = DeparturePresentation.at(info, _at(2026, 9, 28, 13, 33)).label;
    for (final forbidden in ['🟢 6 min', '🟡', '🔴', 'Horaire indisponible',
        'Passage estimé', '0–20', 'UNKNOWN']) {
      expect(label, isNot(contains(forbidden)));
    }
  });
}
