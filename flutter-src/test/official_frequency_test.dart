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
    test('B1 lundi à 14h est ESTIMATED, avec la source et les métadonnées', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 14), // lundi
      );

      expect(info.status, ScheduleStatus.estimated);
      expect(info.serviceActive, isTrue);
      expect(info.frequencyMinutes, 6);
      expect(info.operatingHours, '06:00–21:00');
      expect(info.operator, 'SunuBRT');
      expect(info.routeId, 'brt_b1_guediawaye_petersen');
      expect(info.source, 'https://www.sunubrt.sn/brt-1-omnibus/');
      expect(info.sourceType, SourceType.officialStatic);
      expect(info.dateSource, isNull, reason: 'la date de publication est absente');
      expect(info.dateVerified, '2026-09-26');
      expect(info.validFrom, isNull);
      expect(info.validTo, isNull);
      expect(info.confidence, greaterThan(0));
    });

    test('B1 dimanche 08h utilise 10 minutes', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 27, 8), // dimanche
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 10);
      expect(info.operatingHours, '06:00–11:00');
    });

    test('B1 dimanche 14h utilise 7 minutes', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 27, 14),
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 7);
      expect(info.operatingHours, '11:00–21:00');
    });

    test('B1 hors de la plage 06h–21h reste UNKNOWN', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 22),
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.serviceActive, isFalse);
      expect(info.frequencyMinutes, isNull);
      expect(info.source, 'https://www.sunubrt.sn/brt-1-omnibus/');
    });

    test('B1 applique les plages dimanche/jour férié à un jour férié', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 8), // lundi férié déclaré explicitement
        isPublicHoliday: true,
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 10);
    });

    test('B2 lundi à 14h est ESTIMATED', () {
      final info = service.departureInfoForRoute(
        'brt_b2_express',
        at(2026, 9, 28, 14),
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
      expect(info.operatingHours, '06:00–21:00');
      expect(info.source, 'https://www.sunubrt.sn/brt-2-semi-express/');
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

    test('la fréquence ne fabrique aucun horaire station par station', () {
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        at(2026, 9, 28, 14),
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
      // DepartureInfo ne transporte qu'une fréquence/plage et aucune heure de
      // départ ni collection de stop_times.
      expect(info.operatingHours, '06:00–21:00');
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

    test('TER utilise seulement les fréquences publiées et vérifiées', () {
      final weekday = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 28, 14),
      );
      expect(weekday.status, ScheduleStatus.estimated);
      expect(weekday.frequencyMinutes, 10);
      expect(weekday.source, 'https://www.terdakar.sn/les_horaires_des_trains');
      expect(weekday.dateVerified, '2026-09-26');

      final late = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 28, 21, 30),
      );
      expect(late.status, ScheduleStatus.estimated);
      expect(late.frequencyMinutes, 20);

      final sunday = service.departureInfoForRoute(
        'ter_dakar_diamniadio',
        at(2026, 9, 27, 14),
      );
      expect(sunday.status, ScheduleStatus.estimated);
      expect(sunday.frequencyMinutes, 20);

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

    test('chemin complet DataProvider → DataService → Stop → moteur', () {
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

        // La réponse obtenue sur le Stop est déjà de type ScheduleStatus.estimated.
        final throughStop = from.departureInfoAt(at: requestedAt);
        expect(throughStop.status, ScheduleStatus.estimated);
        expect(from.departureStatusAt(requestedAt), app.DataStatus.estimated);
        expect(throughStop.serviceActive, isTrue);
        expect(throughStop.frequencyMinutes, 6);
        expect(throughStop.scheduledTime, isNull);
        expect(from.departureMinutesFromMidnight, isEmpty);

        final result = app.RoutePlanner.plan(
          fromQuery: 'Origin B1',
          toQuery: 'Destination B1',
          at: requestedAt,
        );
        expect(result.hasRoutes, isTrue);
        final route = result.routes.single;
        expect(route.status, app.DataStatus.estimated);
        expect(route.status, isNot(app.DataStatus.live));
        expect(route.segments.single.status, app.DataStatus.estimated);
        expect(route.segments.single.departureInfo?.frequencyMinutes, 6);
        expect(route.segments.single.departureTime, isNull);
        expect(route.segments.single.arrivalTime, isNull);
        expect(
          app.AssistantReplies.itinerary(route, route.fromName, route.toName),
          contains('Passage estimé dans 0–6 min'),
        );
      } finally {
        app.allStops
          ..clear()
          ..addAll(savedStops);
      }
    });
  });
}
