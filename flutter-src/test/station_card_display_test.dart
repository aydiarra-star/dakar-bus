// ignore_for_file: avoid_print, prefer_const_constructors, prefer_const_literals_to_create_immutables, use_key_in_widget_constructors, unintended_html_in_doc_comment
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(departureDisplayLabel(info), '🟡 Passage estimé toutes les 6 min');
      expect(departureDisplayLabel(info), isNot(contains('Départ dans')));
    });
    test('cas 4 — UNKNOWN → Horaire indisponible', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: _route, requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      expect(departureDisplayLabel(info), ReliabilityLabel.scheduleUnavailable);
    });
    test('cas 5 — intervalle 0–6 jamais présenté comme heure précise', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      final src = _freqSource(6);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      final label = departureDisplayLabel(info);
      expect(label, isNot(contains('Passage estimé dans')));
      expect(label, isNot(contains('0–')));
      expect(label, '🟡 Passage estimé toutes les 6 min');
    });
    test('cas 6 — pas de faux zéro', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      for (final m in [6, 10, 20]) {
        final src = _freqSource(m);
        final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
        final label = departureDisplayLabel(info);
        expect(label, isNot(contains('Départ dans 0 min')));
        expect(label, '🟡 Passage estimé toutes les $m min');
      }
    });
  });
}
