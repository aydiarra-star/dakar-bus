import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_provider.dart';
import 'package:dakar_bus/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DataService service;

  setUpAll(() async {
    await app.appDataService.loadNetworkData();
  });

  DateTime at(int year, int month, int day, int hour, [int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute);

  setUp(() {
    service = DataService();
  });

  group('fréquences officielles SunuBRT', () {
    test('B1 : aucune fréquence historique ne contourne le GTFS exclusif', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 14), // lundi
      );

      expect(info.status, ScheduleStatus.unknown);
      expect(info.serviceActive, isFalse);
      expect(info.frequencyMinutes, isNull);
      expect(info.operatingHours, isNull);
      expect(info.operator, 'Transport');
      expect(info.routeId, 'brt_b1_guediawaye_petersen');
      expect(info.source, isNull);
      expect(info.sourceType, SourceType.unknown);
      expect(info.dateSource, isNull, reason: 'la date de publication est absente');
      expect(info.dateVerified, isNull);
      expect(info.validFrom, isNull);
      expect(info.validTo, isNull);
      expect(info.confidence, isNull);
    });

    test('B1 dimanche : aucun repli sur la fréquence historique', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 27, 8), // dimanche
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
      expect(info.operatingHours, isNull);
    });

    test('B1 dimanche après-midi : aucun repli sur la fréquence historique', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 27, 14),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
      expect(info.operatingHours, isNull);
    });

    test('B1 hors de la plage 06h–21h reste UNKNOWN', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 22),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.serviceActive, isFalse);
      expect(info.frequencyMinutes, isNull);
      expect(info.source, isNull);
    });

    test('B1 jour férié : aucun repli sur la fréquence historique', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 8), // lundi férié déclaré explicitement
        isPublicHoliday: true,
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
    });

    test('B2 : aucun repli sur la fréquence historique', () {
      final info = service.departureInfoForRoute(
        'brt_b2_express',
        at(2026, 9, 28, 14),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
      expect(info.operatingHours, isNull);
      expect(info.source, isNull);
    });

    test('B2 dimanche reste UNKNOWN sans extrapoler B1', () {
      final info = service.departureInfoForRoute(
        'brt_b2_express',
        at(2026, 9, 27, 14),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.serviceActive, isFalse);
      expect(info.frequencyMinutes, isNull);
    });
  });

  group('garde-fous et TER', () {
    test('les fréquences ne peuvent pas produire LIVE', () {
      for (final source in DataProvider.officialFrequencySources) {
        expect(source.status, isNot(ScheduleStatus.realTime));
        for (final window in source.frequencies) {
          expect(window.frequencyMinutes, greaterThan(0));
        }
      }
      for (final routeId in <String>[
        'brt_b1_guediawaye_petersen',
        'brt_b2_express',
        'ter_dakar_diamniadio',
      ]) {
        final result = service.departureInfoForRoute(
          routeId,
          at(2026, 9, 28, 14),
        );
        expect(result.status, isNot(ScheduleStatus.realTime));
        expect(
          app.departureDataStatus(result.status),
          isNot(app.DataStatus.live),
        );
      }
      final unsupported = service.departureInfoForRoute(
        'route_without_a_current_source',
        at(2026, 9, 28, 14),
      );
      expect(unsupported.status, ScheduleStatus.unknown);
      expect(app.departureDataStatus(unsupported.status), app.DataStatus.unknown);
    });

    test('aucune fréquence historique ne fabrique un horaire station par station', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 14),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
      // DepartureInfo ne transporte qu'une fréquence/plage et aucune heure de
      // départ ni collection de stop_times.
      expect(info.operatingHours, isNull);
    });

    test('DDD et AFTU restent UNKNOWN', () {
      for (final routeId in <String>['ddd_1', 'aftu_1', 'line_tata_219']) {
        final result = service.departureInfoForRoute(
          routeId,
          at(2026, 9, 28, 14),
        );
        expect(result.status, ScheduleStatus.unknown, reason: routeId);
        expect(result.frequencyMinutes, isNull, reason: routeId);
      }
    });

    test('TER : aucune fréquence historique ne contourne le GTFS exclusif', () {
      final weekday = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 28, 14),
      );
      expect(weekday.status, ScheduleStatus.unknown);
      expect(weekday.frequencyMinutes, isNull);
      expect(weekday.source, isNull);
      expect(weekday.dateVerified, isNull);

      final late = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 28, 21, 30),
      );
      expect(late.status, ScheduleStatus.unknown);
      expect(late.frequencyMinutes, isNull);

      final sunday = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 27, 14),
      );
      expect(sunday.status, ScheduleStatus.unknown);
      expect(sunday.frequencyMinutes, isNull);

      final beforeService = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 28, 5),
      );
      expect(beforeService.status, ScheduleStatus.unknown);

      final terSource = DataProvider.officialFrequencySources
          .singleWhere((source) => source.routeId == 'ter_dakar_diamniadio');
      expect(
        terSource.frequencies.singleWhere(
            (window) => window.direction == 'Départ de Diamniadio').startMinute,
        5 * 60 + 35,
      );
      expect(
        terSource.frequencies.singleWhere(
            (window) => window.direction == 'Départ de Dakar').startMinute,
        5 * 60 + 45,
      );
    });

    test('DataStatus suit le contrat à quatre valeurs', () {
      expect(app.DataStatus.values.map((status) => status.name),
          <String>['scheduled', 'live', 'unknown', 'estimated']);
    });

    test('le chemin DataService → Stop → moteur ne contourne pas le GTFS exclusif', () {
      final savedStops = List<app.Stop>.of(app.allStops);
      app.Stop fixtureStop(String name, String stopId) => app.Stop(
            name: name,
            stopId: stopId,
            scheduleRouteId: 'brt_b1_guediawaye_petersen',
            direction: 'B1',
            distanceMeters: 0,
            departureMinutesFromMidnight: const <int>[],
            icon: Icons.directions_bus,
            color: Colors.green,
            location: const LatLng(14.7, -17.4),
            modeLabel: 'BRT',
          );

      try {
        final from = fixtureStop('Origin B1', 'stop_brt_23_guediawaye');
        final to = fixtureStop('Destination B1', 'stop_brt_22_gadaye');
        final requestedAt = at(2026, 9, 28, 14);
        app.allStops
          ..clear()
          ..addAll(<app.Stop>[from, to]);

        // Sans stop_time GTFS calculable, le Stop reste UNKNOWN.
        final throughStop = from.departureInfoAt(at: requestedAt);
        expect(throughStop.status, ScheduleStatus.unknown);
        expect(from.departureStatusAt(requestedAt), app.DataStatus.unknown);
        expect(throughStop.serviceActive, isFalse);
        expect(throughStop.frequencyMinutes, isNull);
        expect(throughStop.scheduledTime, isNull);
        expect(from.departureMinutesFromMidnight, isEmpty);

        final result = app.RoutePlanner.plan(
          fromQuery: 'Origin B1',
          toQuery: 'Destination B1',
          at: requestedAt,
        );
        expect(result.hasRoutes, isTrue);
        final route = result.routes.single;
        expect(route.status, app.DataStatus.unknown);
        expect(route.status, isNot(app.DataStatus.live));
        expect(route.segments.single.status, app.DataStatus.unknown);
        expect(route.segments.single.departureInfo?.frequencyMinutes, isNull);
        expect(route.segments.single.departureTime, isNull);
        expect(route.segments.single.arrivalTime, isNull);
        expect(
          app.AssistantReplies.itinerary(route, route.fromName, route.toName),
          contains('Je ne dispose pas d\'un horaire vérifié pour ce trajet.'),
        );
        expect(
          app.AssistantReplies.itinerary(route, route.fromName, route.toName),
          isNot(contains('0–6 min')),
          reason: 'aucun intervalle affiché (règle anti-régression)',
        );
      } finally {
        app.allStops
          ..clear()
          ..addAll(savedStops);
      }
    });
  });
}
