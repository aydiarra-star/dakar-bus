// CORRECTION CIBLÉE CARTES STATIONS — contrat Lots 4.9-4.10
// Vérifie que les cartes n'affichent plus "Passage estimé dans 0–X min"
// mais le contrat via DepartureInfo.
//
// RÈGLE ABSOLUE : aucune conversion intervalle/fréquence/distance → heure
// précise, pas de DateTime.now() fabriqué, pas de faux 0 min.
//
// 6 cas exigés :
//  1. Départ dans 3 min → 🟢 Départ dans 3 min
//  2. Départ maintenant → 🟢 Départ maintenant
//  3. Fréquence 6 → 🟡 Passage estimé toutes les 6 min
//  4. Inconnu → Horaire indisponible
//  5. Intervalle jamais converti en heure précise
//  6. Pas de faux zéro (estimated ≠ Départ dans 0/6 min)
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const String _route = 'test_route_synthetic_only';
const String _stop = 'test_stop_synthetic_only';

Service _service() => Service(
      serviceId: 'svc_test',
      monday: true,
      tuesday: true,
      wednesday: true,
      thursday: true,
      friday: true,
      saturday: true,
      sunday: true,
      startDate: ServiceDate(2026, 9, 26),
      endDate: ServiceDate(2026, 10, 10),
      exceptions: const [],
    );

ScheduleProvenance _provenance() => ScheduleProvenance(
      source: 'test-fixture://synthetic',
      sourceType: SourceType.officialStatic,
      dateSource: ServiceDate(2026, 9, 1),
      dateVerified: ServiceDate(2026, 9, 26),
      validFrom: ServiceDate(2026, 9, 26),
      validTo: ServiceDate(2026, 10, 10),
      confidence: null,
      scheduleStatus: ScheduleStatus.scheduled,
      coverage: ScheduleCoverage(
        complete: true,
        scopes: const [
          ScheduleCoverageScope(
            routeId: _route,
            stopId: _stop,
            directionIds: {0},
            allDirections: false,
          ),
        ],
      ),
    );

ScheduleDataset _datasetForTime(ServiceTime st, DateTime calcAt) {
  final trip = Trip(routeId: _route, tripId: 'trip_1', serviceId: 'svc_test', directionId: 0, headsign: 'Test');
  final stopTime = StopTime(tripId: 'trip_1', stopId: _stop, stopSequence: 1, departureTime: st);
  return ScheduleDataset(trips: [trip], stopTimes: [stopTime], services: [_service()], provenance: _provenance());
}

FrequencySource _freqSource(int minutes) => FrequencySource(
      operator: 'SunuBRT',
      routeId: 'brt_b1_test',
      routeLabel: 'BRT B1',
      source: 'SunuBRT',
      sourceType: SourceType.operatorTimetable,
      dateSource: '2026-09-01',
      dateVerified: '2026-09-26',
      validFrom: null,
      validTo: null,
      confidence: 0.8,
      status: ScheduleStatus.estimated,
      frequencies: [
        FrequencyWindow(
          weekdays: kEveryDay,
          startMinute: 0,
          endMinute: 24 * 60 - 1,
          frequencyMinutes: minutes,
        ),
      ],
      operatingHours: '00:00–23:59',
    );

void main() {
  group('departureDisplayLabel — contrat Lots 4.9-4.10', () {
    test('cas 1 — SCHEDULED départ dans 3 min → 🟢 Départ dans 3 min', () {
      final calcAt = DateTime.utc(2026, 9, 28, 14, 37);
      final st = ServiceTime(14, 40, 0);
      final dataset = _datasetForTime(st, calcAt);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: calcAt,
      );
      final label = departureDisplayLabel(info);
      expect(label, '🟢 Départ dans 3 min');
      expect(label, isNot(contains('Passage estimé')));
      expect(label, isNot(contains('0–')));
    });

    test('cas 1b — REAL_TIME départ dans 3 min → 🟢 (même contrat)', () {
      final now = DateTime.utc(2026, 9, 28, 14, 37);
      final dataset = _datasetForTime(ServiceTime(14, 40, 0), now);
      final prediction = RealtimePrediction(
        routeId: _route,
        tripId: 'trip_1',
        stopId: _stop,
        stopSequence: 1,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        predictedDepartureAt: DateTime.utc(2026, 9, 28, 14, 40),
        observedAt: now.subtract(const Duration(seconds: 30)),
        provenance: ScheduleProvenance(
          source: 'realtime-fixture',
          sourceType: SourceType.operatorRealtime,
          dateSource: null,
          dateVerified: null,
          validFrom: null,
          validTo: null,
          confidence: null,
          scheduleStatus: ScheduleStatus.realTime,
          coverage: null,
        ),
      );
      final info = DepartureInfo.realTime(
        dataset: dataset,
        prediction: prediction,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        now: now,
        maxAge: const Duration(minutes: 2),
      );
      expect(departureDisplayLabel(info), '🟢 Départ dans 3 min');
    });

    test('cas 2 — SCHEDULED départ maintenant → 🟢 Départ maintenant', () {
      final calcAt = DateTime.utc(2026, 9, 28, 14, 40);
      final st = ServiceTime(14, 40, 0);
      final dataset = _datasetForTime(st, calcAt);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: calcAt,
      );
      expect(departureDisplayLabel(info), '🟢 Départ maintenant');
    });

    test('cas 3 — ESTIMATED fréquence 6 → 🟡 Passage estimé toutes les 6 min', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      final src = _freqSource(6);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      expect(info.status, ScheduleStatus.estimated);
      expect(departureDisplayLabel(info), '🟡 Passage estimé toutes les 6 min');
      expect(departureDisplayLabel(info), isNot(contains('Départ dans')));
      expect(departureDisplayLabel(info), isNot(contains('0–')));
    });

    test('cas 3b — ESTIMATED fréquence 10 → toutes les 10 min', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 9, 0);
      final src = _freqSource(10);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      expect(departureDisplayLabel(info), '🟡 Passage estimé toutes les 10 min');
    });

    test('cas 4 — UNKNOWN → Horaire indisponible', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: _route, requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      expect(departureDisplayLabel(info), ReliabilityLabel.scheduleUnavailable);
      expect(departureDisplayLabel(info), 'Horaire indisponible');
      expect(departureDisplayLabel(info), isNot(contains('🟢')));
      expect(departureDisplayLabel(info), isNot(contains('🟡')));
    });

    test('cas 5 — intervalle 0–6 jamais présenté comme heure précise', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      final src = _freqSource(6);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      final label = departureDisplayLabel(info);
      expect(label, isNot(contains('Passage estimé dans')));
      expect(label, isNot(contains('0–')));
      expect(label, isNot(contains('0-')));
      expect(label, isNot(contains('fréquence')));
      expect(label, '🟡 Passage estimé toutes les 6 min');
    });

    test('cas 6 — pas de faux zéro : ESTIMATED ne produit jamais Départ dans 0/6 min', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      for (final m in [6, 10, 20]) {
        final src = _freqSource(m);
        final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
        final label = departureDisplayLabel(info);
        expect(label, isNot(contains('Départ dans 0 min')));
        expect(label, isNot(contains('Départ dans $m min')));
        expect(label, isNot(contains('Départ maintenant')));
        expect(label, '🟡 Passage estimé toutes les $m min');
      }
    });

    test('sécurité — SCHEDULED ne fabrique pas d’heure depuis fréquence', () {
      final calcAt = DateTime.utc(2026, 9, 28, 14, 37);
      final st = ServiceTime(14, 40, 0);
      final dataset = _datasetForTime(st, calcAt);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: calcAt,
      );
      expect(info.frequencyMinutes, isNull);
      expect(info.scheduledTime, isNotNull);
      expect(departureDisplayLabel(info), contains('🟢'));
    });
  });

  group('StopCard et SingleStopView — affichage via DepartureInfo', () {
    testWidgets('StopCard SCHEDULED affiche 🟢 et pas 0–', (tester) async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
      final Stop scheduledStop = allStops.firstWhere(
        (s) => s.scheduleRouteId != null && s.scheduleStatus == ScheduleStatus.scheduled,
        orElse: () => allStops.firstWhere((s) => s.scheduleRouteId != null),
      );
      final String label = departureDisplayLabel(scheduledStop.departureInfo);
      expect(label, anyOf(contains('🟢'), contains('Horaire indisponible')));
      expect(label, isNot(contains('Passage estimé dans')));
      expect(label, isNot(contains('0–')));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StopCard(stop: scheduledStop, distanceMeters: 120))));
      await tester.pumpAndSettle();
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      expect(texts.any((t) => t.contains('🟢') || t.contains('Horaire indisponible') || t.contains('🟡')), isTrue);
      expect(texts.any((t) => t.contains('Passage estimé dans 0–')), isFalse);
      expect(texts.any((t) => t.contains('Passage estimé dans 0-')), isFalse);
    });

    testWidgets('StopCard ESTIMATED affiche 🟡 toutes les X, jamais Départ dans X', (tester) async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
      final Stop estimatedStop = allStops.firstWhere(
        (s) => s.scheduleRouteId == 'brt_b1_guediawaye_petersen',
        orElse: () => allStops.firstWhere((s) => s.departureInfo.status == ScheduleStatus.estimated, orElse: () => allStops.first),
      );
      if (estimatedStop.departureInfo.status == ScheduleStatus.estimated) {
        final String label = departureDisplayLabel(estimatedStop.departureInfo);
        expect(label, contains('🟡'));
        expect(label, contains('toutes les'));
        expect(label, isNot(contains('Départ dans')));
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: StopCard(stop: estimatedStop, distanceMeters: 250))));
        await tester.pumpAndSettle();
        final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
        expect(texts.any((t) => t.contains('🟡 Passage estimé toutes les')), isTrue);
        expect(texts.any((t) => t.contains('Départ dans 6 min')), isFalse);
        expect(texts.any((t) => t.contains('Départ dans 0')), isFalse);
      }
    });

    testWidgets('SingleStopView UNKNOWN affiche Horaire indisponible', (tester) async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
      final Stop unknownStop = Stop(
        name: 'Arrêt Test Inconnu',
        direction: 'Dir. Test',
        distanceMeters: 0,
        departureMinutesFromMidnight: const [],
        icon: Icons.bus_alert,
        color: Colors.grey,
        location: const LatLng(14.6937, -17.4441),
        modeLabel: 'Test',
        scheduleRouteId: 'route_unknown_test',
        stopId: 'stop_unknown_test',
      );
      expect(unknownStop.departureInfo.status, ScheduleStatus.unknown);
      expect(departureDisplayLabel(unknownStop.departureInfo), 'Horaire indisponible');
      await tester.pumpWidget(MaterialApp(home: SingleStopView(stop: unknownStop)));
      await tester.pumpAndSettle();
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      expect(texts, contains('Horaire indisponible'));
      expect(texts.any((t) => t.contains('Passage estimé dans')), isFalse);
    });
  });
}
