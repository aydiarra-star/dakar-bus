/// Dakar Bus - Groupe 11
/// Tests du socle horaires réels
/// Test A à G selon spécification

import 'package:test/test.dart';
import '../lib/models/data_status.dart';
import '../lib/models/departure.dart';
import '../lib/models/stop.dart';
import '../lib/repositories/unavailable_schedule_repository.dart';
import '../lib/services/schedule_service.dart' as service;

void main() {
  group('Groupe 11 - Socle horaires réels', () {
    test('Test A - Aucun repository réel : aucune source -> aucun départ -> unknown / indisponible', () async {
      final repo = UnavailableScheduleRepository();
      final departures = await repo.departuresForStop('TER_01_Dakar');
      expect(departures, isEmpty);

      final stop = Stop(id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: departures);
      expect(stop.hasSourcedSchedule, isFalse);
      expect(stop.dataStatus, DataStatus.unknown);
      expect(stop.nextDepartureLabel(DateTime.utc(2026, 9, 22, 10, 0)), 'Horaire non disponible');
      expect(stop.remainingMinutes(DateTime.utc(2026, 9, 22, 10, 0)), isNull);
      expect(stop.departureAfter(DateTime.utc(2026, 9, 22, 10, 0)), isNull);
    });

    test('Test B - Départ scheduled réel injecté par le test', () {
      final fixedNow = DateTime.utc(2026, 9, 22, 13, 0);
      final departureTime = DateTime.utc(2026, 9, 22, 14, 20);

      final dep = Departure(
        stopId: 'TER_01_Dakar',
        lineId: 'TER',
        departureTime: departureTime,
        status: DataStatus.scheduled,
        direction: 'Diamniadio',
        sourceId: 'test-gtfs-2026',
      );

      expect(dep.status, DataStatus.scheduled);

      final stop = Stop(id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: [dep]);
      expect(stop.hasSourcedSchedule, isTrue);

      final next = stop.departureAfter(fixedNow);
      expect(next, isNotNull);
      expect(next!.departureTime, departureTime);
      expect(next.status, DataStatus.scheduled);
      expect(stop.nextDepartureLabel(fixedNow), isNot('Horaire non disponible'));
      expect(stop.remainingMinutes(fixedNow), 80);
    });

    test('Test C - Départ live réel injecté', () {
      final fixedNow = DateTime.utc(2026, 9, 22, 10, 0);
      final departureTime = DateTime.utc(2026, 9, 22, 10, 5);

      final dep = Departure(
        stopId: 'BRT_01_Petersen',
        lineId: 'BRT 01',
        departureTime: departureTime,
        status: DataStatus.live,
        direction: 'Guédiawaye',
        sourceId: 'test-realtime-cetud',
      );

      final stop = Stop(id: 'BRT_01_Petersen', name: 'Petersen', departures: [dep]);
      final next = stop.departureAfter(fixedNow);
      expect(next, isNotNull);
      expect(next!.status, DataStatus.live);
      expect(stop.remainingMinutes(fixedNow), 5);
      expect(stop.nextDepartureLabel(fixedNow), isNot('Horaire non disponible'));
    });

    test('Test D - Départ passé ne doit pas être retourné', () {
      final now = DateTime.utc(2026, 9, 22, 15, 0);
      final past = DateTime.utc(2026, 9, 22, 14, 0);

      final dep = Departure(
        stopId: 'TER_01_Dakar',
        lineId: 'TER',
        departureTime: past,
        status: DataStatus.scheduled,
        sourceId: 'test',
      );

      final stop = Stop(id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: [dep]);
      expect(stop.departureAfter(now), isNull);
      expect(stop.remainingMinutes(now), isNull);
      expect(stop.nextDepartureLabel(now), 'Horaire non disponible');
    });

    test('Test E - Plusieurs départs 13:00, 13:30, 14:00', () {
      final d1 = Departure(stopId: 'S1', lineId: 'TER', departureTime: DateTime.utc(2026, 9, 22, 13, 0), status: DataStatus.scheduled, sourceId: 'test');
      final d2 = Departure(stopId: 'S1', lineId: 'TER', departureTime: DateTime.utc(2026, 9, 22, 13, 30), status: DataStatus.scheduled, sourceId: 'test');
      final d3 = Departure(stopId: 'S1', lineId: 'TER', departureTime: DateTime.utc(2026, 9, 22, 14, 0), status: DataStatus.scheduled, sourceId: 'test');

      final stop = Stop(id: 'S1', name: 'Test', departures: [d1, d2, d3]);

      expect(stop.departureAfter(DateTime.utc(2026, 9, 22, 12, 50))!.departureTime, DateTime.utc(2026, 9, 22, 13, 0));
      expect(stop.departureAfter(DateTime.utc(2026, 9, 22, 13, 15))!.departureTime, DateTime.utc(2026, 9, 22, 13, 30));
      expect(stop.departureAfter(DateTime.utc(2026, 9, 22, 13, 45))!.departureTime, DateTime.utc(2026, 9, 22, 14, 0));
      expect(stop.departureAfter(DateTime.utc(2026, 9, 22, 14, 10)), isNull);
    });

    test('Test F - Aucun départ : null et Horaire non disponible', () {
      final stop = Stop(id: 'EMPTY', name: 'Vide', departures: []);
      final now = DateTime.utc(2026, 9, 22, 10, 0);
      expect(stop.departureAfter(now), isNull);
      expect(stop.remainingMinutes(now), isNull);
      expect(stop.nextDepartureLabel(now), 'Horaire non disponible');
      expect(stop.hasSourcedSchedule, isFalse);
      expect(stop.dataStatus, DataStatus.unknown);
    });

    test('Test G - Pas de génération automatique', () async {
      final repo = UnavailableScheduleRepository();
      for (final id in ['TER_01_Dakar', 'BRT_01_Petersen', 'UNKNOWN_STOP']) {
        final deps = await repo.departuresForStop(id);
        expect(deps, isEmpty);
        final stop = Stop(id: id, name: id, departures: deps);
        expect(stop.hasSourcedSchedule, isFalse);
        expect(stop.departures, isEmpty);
      }
      final emptyStop = Stop(id: 'TEST', name: 'Test');
      expect(emptyStop.departures, isEmpty);
      expect(emptyStop.generateSchedule(), isEmpty);
    });

    test('Test services avec temps contrôlable', () {
      final now = DateTime.utc(2026, 9, 22, 8, 0);
      final deps = [
        Departure(stopId: 'S1', lineId: 'L1', departureTime: DateTime.utc(2026, 9, 22, 9, 0), status: DataStatus.scheduled, sourceId: 'test'),
        Departure(stopId: 'S1', lineId: 'L1', departureTime: DateTime.utc(2026, 9, 22, 10, 0), status: DataStatus.live, sourceId: 'test'),
      ];

      final next = service.departureAfter(deps, now);
      expect(next!.departureTime, DateTime.utc(2026, 9, 22, 9, 0));
      expect(service.remainingMinutes(deps, now), 60);
      expect(service.nextDepartureLabel(deps, now), isNot('Horaire non disponible'));
      expect(service.getDataStatus(deps, now), DataStatus.scheduled);

      final afterFirst = DateTime.utc(2026, 9, 22, 9, 30);
      final next2 = service.departureAfter(deps, afterFirst);
      expect(next2!.status, DataStatus.live);
      expect(service.getDataStatus(deps, afterFirst), DataStatus.live);
    });
  });
}
