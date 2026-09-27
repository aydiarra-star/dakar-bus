import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper local identique à celui de main.dart (contrat Lots 4.9-4.10)
// pour tester sans importer main.dart (évite 19 issues liées à l'import).
String _departureDisplayLabel(DepartureInfo info) {
  switch (info.status) {
    case ScheduleStatus.scheduled:
    case ScheduleStatus.realTime:
      final anchor = info.calculatedAt ?? info.referenceTime;
      final label = anchor != null ? info.remainingLabelAt(anchor) : null;
      if (label != null) return '🟢 $label';
      final dt = info.nextDepartureAt ?? info.scheduledTime;
      if (dt != null) {
        final hh = dt.toUtc().hour.toString().padLeft(2, '0');
        final mm = dt.toUtc().minute.toString().padLeft(2, '0');
        return '🟢 $hh:$mm';
      }
      return ReliabilityLabel.scheduleUnavailable;
    case ScheduleStatus.estimated:
      final m = info.frequencyMinutes;
      if (m == null) return ReliabilityLabel.scheduleUnavailable;
      return '🟡 Passage estimé toutes les $m min';
    case ScheduleStatus.unknown:
      return ReliabilityLabel.scheduleUnavailable;
  }
}

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
      final label = _departureDisplayLabel(info);
      expect(label, '🟢 Départ dans 3 min');
      expect(label, isNot(contains('Passage estimé')));
      expect(label, isNot(contains('0–')));
    });
    test('cas 2 — SCHEDULED départ maintenant', () {
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
      expect(_departureDisplayLabel(info), '🟢 Départ maintenant');
    });
    test('cas 3 — ESTIMATED fréquence 6', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      final src = _freqSource(6);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      expect(_departureDisplayLabel(info), '🟡 Passage estimé toutes les 6 min');
      expect(_departureDisplayLabel(info), isNot(contains('Départ dans')));
    });
    test('cas 4 — UNKNOWN', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: _route, requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      expect(_departureDisplayLabel(info), ReliabilityLabel.scheduleUnavailable);
      expect(_departureDisplayLabel(info), 'Horaire indisponible');
    });
    test('cas 5 — intervalle jamais présenté comme heure', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      final src = _freqSource(6);
      final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
      final label = _departureDisplayLabel(info);
      expect(label, isNot(contains('Passage estimé dans')));
      expect(label, isNot(contains('0–')));
      expect(label, '🟡 Passage estimé toutes les 6 min');
    });
    test('cas 6 — pas de faux zéro', () {
      final requestedAt = DateTime.utc(2026, 9, 28, 14, 0);
      for (final m in [6, 10, 20]) {
        final src = _freqSource(m);
        final info = DepartureInfo.fromFrequency(src, src.frequencies.first, requestedAt);
        final label = _departureDisplayLabel(info);
        expect(label, isNot(contains('Départ dans 0 min')));
        expect(label, '🟡 Passage estimé toutes les $m min');
      }
    });
  });
}
