import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/departure_presentation.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/main.dart' as app;

final _at = DateTime.utc(2026, 9, 28, 13, 33);
final _due = DateTime.utc(2026, 9, 28, 13, 40);
const _route = 'ter_fixture';
const _stop = 'ter_stop_fixture';

ScheduleDataset _schedule() {
  return ScheduleDataset(
    trips: [Trip(routeId: _route, tripId: 'trip_fixture', serviceId: 'service_fixture', directionId: 0)],
    stopTimes: [StopTime(tripId: 'trip_fixture', stopId: _stop, stopSequence: 1,
        departureTime: ServiceTime(13, 40, 0))],
    services: [Service(serviceId: 'service_fixture', monday: true, tuesday: true,
        wednesday: true, thursday: true, friday: true, saturday: true, sunday: true,
        startDate: ServiceDate(2026, 9, 21), endDate: ServiceDate(2026, 10, 10))],
    provenance: ScheduleProvenance(
      source: 'fixture://timetable', sourceType: SourceType.officialStatic,
      dateSource: ServiceDate(2026, 9, 21), dateVerified: ServiceDate(2026, 9, 21),
      validFrom: ServiceDate(2026, 9, 21), validTo: ServiceDate(2026, 10, 10),
      confidence: 0.99, scheduleStatus: ScheduleStatus.scheduled,
      coverage: ScheduleCoverage(complete: true, scopes: [
        ScheduleCoverageScope(routeId: _route, stopId: _stop, allDirections: true),
      ]),
    ),
  );
}

DepartureInfo _scheduled(DateTime at) {
  final dataset = _schedule();
  return DepartureInfo.scheduled(dataset: dataset, trip: dataset.trips.first,
      stopTime: dataset.stopTimes.first, service: dataset.services.first,
      serviceDate: ServiceDate(2026, 9, 28), provenance: dataset.provenance!,
      calculatedAt: at);
}

OperationalEvidence _alert({String routeId = _route, SourceType type = SourceType.operatorRealtime}) =>
    OperationalEvidence(status: OperationalStatus.unavailable,
        routeId: routeId, source: 'fixture://operator-confirmed-interruption',
        sourceType: type, observedAt: _at,
        validUntil: DateTime.utc(2026, 9, 28, 14, 0));

void main() {
  test('TER 13:33 → 13:40, puis Maintenant : ETA et provenance séparées', () {
    final info = _scheduled(_at);
    expect(info.etaMinutes, 7);
    expect(info.etaAt, _due);
    expect(info.etaSource, EtaSource.schedule);
    expect(info.calculationMethod, 'SCHEDULE');
    expect(info.operationalStatus, OperationalStatus.normal);
    expect(app.departureDisplayLabel(info), '🟢 7 min');
    expect(app.departureDisplayLabel(info, at: _due), '🟢 Maintenant');
    expect(DeparturePresentation.at(info, _due.add(const Duration(seconds: 1))).label,
        DeparturePresentation.noEta);
  });

  test('TER retard à 13:40 objectivement établi par prédiction fraîche appariée', () {
    final dataset = _schedule();
    final now = _due;
    final realtime = ScheduleProvenance(
        source: 'fixture://realtime', sourceType: SourceType.operatorRealtime,
        dateSource: null, dateVerified: null, validFrom: null, validTo: null,
        confidence: 0.95, scheduleStatus: ScheduleStatus.realTime, coverage: null);
    final prediction = RealtimePrediction(routeId: _route,
        tripId: dataset.trips.first.tripId, stopId: _stop, stopSequence: 1,
        directionId: 0, serviceDate: ServiceDate(2026, 9, 28),
        predictedDepartureAt: now.add(const Duration(minutes: 7)),
        observedAt: now.subtract(const Duration(seconds: 30)), provenance: realtime);
    final info = DepartureInfo.realTime(dataset: dataset, prediction: prediction,
        trip: dataset.trips.first, stopTime: dataset.stopTimes.first,
        service: dataset.services.first, now: now, maxAge: const Duration(minutes: 2));
    expect(info.operationalStatus, OperationalStatus.delayed);
    expect(info.etaSource, EtaSource.realTime);
    expect(info.scheduledTime, now);
    expect(app.departureDisplayLabel(info), '🟡 7 min');
    expect(app.departureDisplayColor(app.departurePresentation(info), false),
        isNot(app.departureDisplayColor(app.departurePresentation(_scheduled(_at)), false)));
  });

  test('interruption confirmée : rouge, ETA masquée même si horaire présent', () {
    final info = _scheduled(_at).withOperationalEvidence(_alert(), _at);
    expect(info.etaAt, _due);
    expect(info.operationalStatus, OperationalStatus.unavailable);
    expect(app.departureDisplayLabel(info), '🔴 Indisponible');
    expect(DeparturePresentation.at(info, _at).eta, isNull);
    expect(app.departureDisplayLabel(info, at: DateTime.utc(2026, 9, 28, 14, 1)),
        DeparturePresentation.noEta);
  });

  test('une interruption sourcée peut être signalée sans ETA, mais pas sans preuve', () {
    final unknown = DepartureInfo.unknown(operator: 'DDD', routeId: _route, requestedAt: _at);
    expect(unknown.operationalStatus, isNull);
    expect(app.departureDisplayLabel(unknown), DeparturePresentation.noEta);
    expect(unknown.withOperationalEvidence(_alert(), _at).operationalStatus,
        OperationalStatus.unavailable);
    expect(() => unknown.withOperationalEvidence(_alert(routeId: 'other'), _at), throwsArgumentError);
    expect(() => unknown.withOperationalEvidence(_alert(), DateTime.utc(2026, 9, 28, 15)), throwsArgumentError);
    expect(() => _alert(type: SourceType.community), throwsArgumentError);
  });

  test('TER, B1/B2/B3, DDD, AFTU et autres : aucune couleur ou ETA inventée', () {
    final data = DataService();
    for (final route in [
      'ter_dakar_diamniadio', 'brt_b1_guediawaye_petersen',
      'brt_b2_petersen', 'brt_b3_semi_express', 'ddd_1', 'aftu_1',
      'other_unverified',
    ]) {
      final info = data.departureInfoForRoute(route, DateTime.utc(2026, 9, 28, 14));
      final eta = EtaCalculator.fromDepartureInfo(info, DateTime.utc(2026, 9, 28, 14));
      final presentation = DeparturePresentation.at(info, DateTime.utc(2026, 9, 28, 14));
      if (eta == null) {
        expect(presentation.label, DeparturePresentation.noEta, reason: route);
        expect(presentation.operationalStatus, isNull, reason: route);
      }
      expect(presentation.label, isNot(contains('🟡')), reason: route);
      expect(presentation.label, isNot(contains('🔴')), reason: route);
      for (final forbidden in ['Horaire indisponible', 'Passage estimé', '0–20',
        'UNKNOWN', 'SCHEDULED', 'ESTIMATED']) {
        expect(presentation.label, isNot(contains(forbidden)), reason: route);
      }
    }
  });

  test('les anciens chemins : assistant et segment ignorent departureTime et fréquence', () {
    final unknown = DepartureInfo.unknown(operator: 'AFTU', routeId: 'test', requestedAt: _at);
    final segment = app.RouteSegment(modeLabel: 'AFTU', color: app.AppColors.tata,
        icon: Icons.directions_bus,
        from: 'A', to: 'B', durationMinutes: 10, departureTime: '13:40',
        status: app.DataStatus.estimated, departureInfo: unknown);
    final route = app.PlannedRoute(fromName: 'A', toName: 'B', segments: [segment],
        totalMinutes: 10, status: app.DataStatus.estimated);
    final reply = app.AssistantReplies.itinerary(route, 'A', 'B');
    expect(reply, isNot(contains('🕒')));
    expect(reply, isNot(contains('13:40')));
    expect(reply, isNot(contains('Passage estimé dans')));
  });
}
