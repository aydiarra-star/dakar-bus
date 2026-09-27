import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/schedule_service.dart';

const String _route = 'test_route_universal';
const String _stop = 'test_stop_universal';
const String _serviceId = 'test_service_universal';

Service _service() => Service(
      serviceId: _serviceId,
      monday: true,
      tuesday: true,
      wednesday: true,
      thursday: true,
      friday: true,
      saturday: true,
      sunday: true,
      startDate: ServiceDate(2026, 9, 21),
      endDate: ServiceDate(2026, 10, 10),
    );

ScheduleProvenance _provenance() => ScheduleProvenance(
      source: 'test-fixture://universal',
      sourceType: SourceType.officialStatic,
      dateSource: ServiceDate(2026, 9, 1),
      dateVerified: ServiceDate(2026, 9, 21),
      validFrom: ServiceDate(2026, 9, 21),
      validTo: ServiceDate(2026, 10, 10),
      confidence: 0.99,
      scheduleStatus: ScheduleStatus.scheduled,
      coverage: ScheduleCoverage(
        complete: true,
        scopes: [
          ScheduleCoverageScope(routeId: _route, stopId: _stop, allDirections: true),
        ],
      ),
    );

ScheduleDataset _datasetWithTimes(List<ServiceTime> times) {
  final trips = <Trip>[];
  final stopTimes = <StopTime>[];
  for (int i = 0; i < times.length; i++) {
    final tripId = 'trip_${i}_universal';
    trips.add(Trip(routeId: _route, tripId: tripId, serviceId: _serviceId, directionId: 0));
    stopTimes.add(StopTime(tripId: tripId, stopId: _stop, stopSequence: 1, departureTime: times[i]));
  }
  return ScheduleDataset(trips: trips, stopTimes: stopTimes, services: [_service()], provenance: _provenance());
}

String _display(DepartureInfo info) {
  final anchor = info.calculatedAt ?? info.referenceTime;
  if (anchor == null) return 'Horaire indisponible';
  final eta = EtaCalculator.fromDepartureInfo(info, anchor);
  if (eta == null) return 'Horaire indisponible';
  if (eta.isNow) return '🟢 Maintenant';
  return '🟢 ${eta.minutes} min';
}

void main() {
  group('Lot 4.14 — ETA universelle TER (exemple 13:40)', () {
    final dataset = _datasetWithTimes([ServiceTime(13, 40, 0)]);
    final serviceDate = ServiceDate(2026, 9, 28); // Monday

    test('13:33 → 7 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 33),
      );
      expect(_display(info), '🟢 7 min');
      expect(info.etaSource, EtaSource.schedule);
      expect(info.status, ScheduleStatus.scheduled);
    });

    test('13:34 → 6 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 34),
      );
      expect(_display(info), '🟢 6 min');
    });

    test('13:35 → 5 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 35),
      );
      expect(_display(info), '🟢 5 min');
    });

    test('13:36 → 4 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 36),
      );
      expect(_display(info), '🟢 4 min');
    });

    test('13:37 → 3 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 37),
      );
      expect(_display(info), '🟢 3 min');
    });

    test('13:38 → 2 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 38),
      );
      expect(_display(info), '🟢 2 min');
    });

    test('13:39 → 1 min', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 39),
      );
      expect(_display(info), '🟢 1 min');
    });

    test('13:40 → Maintenant', () {
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: serviceDate,
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 40),
      );
      expect(_display(info), '🟢 Maintenant');
      expect(info.etaMinutesAt(DateTime.utc(2026, 9, 28, 13, 40)), 0);
    });
  });

  group('Lot 4.14 — REAL_TIME', () {
    test('ETA 13:43 reference 13:40 → 3 min', () {
      final dataset = _datasetWithTimes([ServiceTime(13, 40, 0)]);
      final now = DateTime.utc(2026, 9, 28, 13, 40);
      final prediction = RealtimePrediction(
        routeId: _route,
        tripId: dataset.trips.first.tripId,
        stopId: _stop,
        stopSequence: 1,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        predictedDepartureAt: DateTime.utc(2026, 9, 28, 13, 43),
        observedAt: DateTime.utc(2026, 9, 28, 13, 39, 30),
        provenance: ScheduleProvenance(
          source: 'test-realtime',
          sourceType: SourceType.operatorRealtime,
          dateSource: null,
          dateVerified: null,
          validFrom: null,
          validTo: null,
          confidence: 0.95,
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
      expect(_display(info), '🟢 3 min');
      expect(info.etaSource, EtaSource.realTime);
      expect(info.status, ScheduleStatus.realTime);
    });
  });

  group('Lot 4.14 — GPS', () {
    test('GPS utilisateur → arrêt pertinent → ETA', () {
      // Simulation : utilisateur près de _stop, véhicule à proximité
      final dataset = _datasetWithTimes([ServiceTime(14, 0, 0)]);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 55),
      );
      // ETA de base = 5 min
      expect(_display(info), '🟢 5 min');
      // Via GPS, la source devient gps mais minutes identiques
      final gpsEta = EtaCalculator.fromGps(info: info, nowUtc: DateTime.utc(2026, 9, 28, 13, 55), userLat: 14.68, userLon: -17.44);
      expect(gpsEta, isNotNull);
      expect(gpsEta!.minutes, 5);
      expect(gpsEta.source, EtaSource.gps);
      // Display reste 🟢 5 min
      expect('🟢 ${gpsEta.minutes} min', '🟢 5 min');
    });

    test('GPS sans position ne remplace pas par fiction', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: 'unknown', requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      final eta = EtaCalculator.fromGps(info: info, nowUtc: DateTime.utc(2026, 9, 28, 12, 0));
      expect(eta, isNull);
      expect(_display(info), 'Horaire indisponible');
    });
  });

  group('Lot 4.14 — HISTORICAL', () {
    test('ETA calculée à partir de fenêtre fréquence → 🟢 X min (COMBINED, pas HISTORICAL)', () {
      final window = FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 13 * 60, endMinute: 15 * 60, frequencyMinutes: 10);
      // Fréquence 10, fenêtre 13:00-15:00, now 13:34 → prochain 13:40 → 6 min
      // Une fenêtre de fréquence N'EST PAS une donnée historique — elle doit être tracée COMBINED
      final etaAt = EtaCalculator.estimatedEtaFromWindow(window: window, nowUtc: DateTime.utc(2026, 9, 28, 13, 34));
      expect(etaAt, DateTime.utc(2026, 9, 28, 13, 40));
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_hist',
        routeLabel: 'Test',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '13:00–15:00',
        frequencies: [window],
      );
      final info = DepartureInfo.estimatedWithEta(
        source: source,
        window: window,
        requestedAt: DateTime.utc(2026, 9, 28, 13, 34),
        etaAt: etaAt!,
        etaSource: EtaSource.combined,
        calculationMethod: 'FREQUENCY_WINDOW',
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.etaSource, EtaSource.combined);
      expect(info.etaSource, isNot(EtaSource.historical));
      expect(_display(info), '🟢 6 min');
    });

    test('ETA historique vraie à partir d’observations → HISTORICAL', () {
      // Vraie historique : liste d’observations passées
      final observed = [
        DateTime.utc(2026, 9, 28, 13, 20),
        DateTime.utc(2026, 9, 28, 13, 40),
        DateTime.utc(2026, 9, 28, 14, 0),
      ];
      final etaAt = EtaCalculator.historicalEta(observedDepartures: observed, nowUtc: DateTime.utc(2026, 9, 28, 13, 34));
      expect(etaAt, DateTime.utc(2026, 9, 28, 13, 40));
      final window = FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 13 * 60, endMinute: 15 * 60, frequencyMinutes: 10);
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_hist_true',
        routeLabel: 'TestTrue',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '13:00–15:00',
        frequencies: [window],
      );
      final info = DepartureInfo.estimatedWithEta(
        source: source,
        window: window,
        requestedAt: DateTime.utc(2026, 9, 28, 13, 34),
        etaAt: etaAt!,
        etaSource: EtaSource.historical,
        calculationMethod: 'HISTORICAL',
      );
      expect(info.etaSource, EtaSource.historical);
      expect(_display(info), '🟢 6 min');
    });

    test('historical avec travelTimeModel', () {
      final lastPassage = DateTime.utc(2026, 9, 28, 13, 30);
      final eta = EtaCalculator.travelTimeModelEta(
        lastKnownPassage: lastPassage,
        averageTravelTime: const Duration(minutes: 10),
        nowUtc: DateTime.utc(2026, 9, 28, 13, 34),
      );
      expect(eta, DateTime.utc(2026, 9, 28, 13, 40));
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_hist2',
        routeLabel: 'Test2',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '13:00–15:00',
        frequencies: [FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 13 * 60, endMinute: 15 * 60, frequencyMinutes: 10)],
      );
      final window = source.frequencies.first;
      final info = DepartureInfo.estimatedWithEta(
        source: source,
        window: window,
        requestedAt: DateTime.utc(2026, 9, 28, 13, 34),
        etaAt: eta!,
        etaSource: EtaSource.travelTimeModel,
        calculationMethod: 'TRAVEL_TIME_MODEL',
      );
      expect(_display(info), '🟢 6 min');
      expect(info.etaSource, EtaSource.travelTimeModel);
    });
  });

  group('Lot 4.14 — DONNÉES INSUFFISANTES', () {
    test('fréquence seule sans fenêtre exploitable → Horaire indisponible', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: 'ddd_1', requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      expect(_display(info), 'Horaire indisponible');
      expect(info.etaAt, isNull);
    });

    test('ESTIMATED sans ETA calculée → Horaire indisponible, jamais 6 min inventé', () {
      final window = FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 6 * 60, endMinute: 21 * 60, frequencyMinutes: 6);
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_insufficient',
        routeLabel: 'Test',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '06:00–21:00',
        frequencies: [window],
      );
      // Créer un ESTIMATED sans ETA (fréquence pure)
      final info = DepartureInfo.fromFrequency(source, window, DateTime.utc(2026, 9, 28, 14, 1));
      // Sans ETA, l'affichage doit être Horaire indisponible, pas 🟢 6 min
      // Mais notre DataService calcule l'ETA, donc fromFrequency pur est insuffisant
      // On vérifie que _display retourne Horaire indisponible si on n'a pas d'ETA
      // (c'est le cas pour un DepartureInfo.fromFrequency sans etaAt)
      expect(info.nextDepartureAt, isNull);
      expect(info.etaAt, isNull);
      expect(_display(info), 'Horaire indisponible');
    });

    test('BRT toutes les 6 min seule ne devient pas 🟢 6 min automatiquement', () {
      final service = DataService();
      // À 14:00, BRT B1 a une ETA calculée (Maintenant), pas 6 min brut
      // On vérifie qu'à 14:01, ce n'est pas 6 min mais 5 min (calcul via fenêtre)
      final info = service.departureInfoForRoute('brt_b1_guediawaye_petersen', DateTime.utc(2026, 9, 28, 14, 1));
      final label = _display(info);
      expect(label, isNot('🟢 6 min')); // ne doit pas être la fréquence brute
      expect(label, '🟢 5 min');
    });
  });

  group('Lot 4.14 — NON-RÉGRESSION', () {
    test('absence de Passage estimé toutes les X min', () {
      final service = DataService();
      final routes = ['brt_b1_guediawaye_petersen', 'ter_dakar_diamniadio', 'ddd_1', 'aftu_1'];
      for (final r in routes) {
        final info = service.departureInfoForRoute(r, DateTime.utc(2026, 9, 28, 14, 0));
        final label = _display(info);
        expect(label, isNot(contains('Passage estimé toutes les')));
        expect(label, isNot(contains('Passage estimé dans')));
        expect(label, isNot(contains('🟡')));
      }
      // Vérifier aussi les labels directs
      final window = FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 6 * 60, endMinute: 21 * 60, frequencyMinutes: 6);
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_no_passage',
        routeLabel: 'Test',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '06:00–21:00',
        frequencies: [window],
      );
      final est = DepartureInfo.fromFrequency(source, window, DateTime.utc(2026, 9, 28, 14, 1));
      expect(_display(est), isNot(contains('Passage estimé')));
    });

    test('pas de 🟢 0 min', () {
      final dataset = _datasetWithTimes([ServiceTime(13, 40, 0)]);
      final infoPast = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 40),
      );
      expect(_display(infoPast), '🟢 Maintenant');
      expect(_display(infoPast), isNot(contains('0 min')));

      final infoFuture = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 39),
      );
      expect(_display(infoFuture), '🟢 1 min');
      expect(_display(infoFuture), isNot(contains('0 min')));
    });

    test('après minuit et >24:00', () {
      // 24:02 du 26/09 → 00:02 le 27/09
      final serviceDate = ServiceDate(2026, 9, 26);
      final dataset = _datasetWithTimes([ServiceTime.parse('24:02:00')]);
      // Recherche à 23:59 le 26/09
      final engine = ScheduleEngine(dataset: dataset);
      final result = engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: serviceDate,
        now: DateTime.utc(2026, 9, 26, 23, 59, 59),
      );
      expect(result, isA<FoundDeparture>());
      final found = result as FoundDeparture;
      expect(found.nextDepartureAt, DateTime.utc(2026, 9, 27, 0, 2));
      final info = found.departures.first;
      // À 23:59:59 → 00:02 = 121 secondes → 3 min (ceil)
      // Mais notre etaMinutes calcule via _remainingSeconds → 121s → 3 min
      // Vérifier que 00:02 est bien géré
      expect(info.nextDepartureAt, DateTime.utc(2026, 9, 27, 0, 2));
      // Test >24:00 via 25:30 → 01:30 le lendemain
      final dataset2 = _datasetWithTimes([ServiceTime.parse('25:30:00')]);
      final engine2 = ScheduleEngine(dataset: dataset2);
      final result2 = engine2.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: serviceDate,
        now: DateTime.utc(2026, 9, 26, 23, 0),
      );
      expect(result2, isA<FoundDeparture>());
      expect((result2 as FoundDeparture).nextDepartureAt, DateTime.utc(2026, 9, 27, 1, 30));
    });

    test('toutes les mobilités utilisent même rendu 🟢 X min', () {
      final terInfo = DepartureInfo.scheduled(
        dataset: _datasetWithTimes([ServiceTime(14, 10, 0)]),
        trip: _datasetWithTimes([ServiceTime(14, 10, 0)]).trips.first,
        stopTime: _datasetWithTimes([ServiceTime(14, 10, 0)]).stopTimes.first,
        service: _datasetWithTimes([ServiceTime(14, 10, 0)]).services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: _datasetWithTimes([ServiceTime(14, 10, 0)]).provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 14, 0),
      );
      expect(_display(terInfo), '🟢 10 min');

      final brtInfo = DataService().departureInfoForRoute('brt_b1_guediawaye_petersen', DateTime.utc(2026, 9, 28, 14, 0));
      // 14:00 → Maintenant
      expect(_display(brtInfo), anyOf('🟢 Maintenant', contains('🟢')));

      final dddInfo = DataService().departureInfoForRoute('ddd_1', DateTime.utc(2026, 9, 28, 14, 0));
      expect(_display(dddInfo), 'Horaire indisponible');
      expect(_display(dddInfo), isNot(contains('🟢 0 min')));
    });
  });

  group('Lot 4.14 — PROVENANCE conservée', () {
    test('display 🟢 6 min mais status ESTIMATED + HISTORICAL tracé', () {
      final window = FrequencyWindow(weekdays: {DateTime.monday}, startMinute: 13 * 60, endMinute: 15 * 60, frequencyMinutes: 10);
      final source = FrequencySource(
        operator: 'Test',
        routeId: 'test_prov',
        routeLabel: 'Test',
        source: 'https://example.com',
        sourceType: SourceType.officialStatic,
        dateSource: null,
        dateVerified: '2026-09-21',
        validFrom: null,
        validTo: null,
        confidence: 0.8,
        status: ScheduleStatus.estimated,
        operatingHours: '13:00–15:00',
        frequencies: [window],
      );
      final etaAt = DateTime.utc(2026, 9, 28, 13, 40);
      final info = DepartureInfo.estimatedWithEta(
        source: source,
        window: window,
        requestedAt: DateTime.utc(2026, 9, 28, 13, 34),
        etaAt: etaAt,
        etaSource: EtaSource.combined,
        calculationMethod: 'FREQUENCY_WINDOW',
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.etaSource, EtaSource.combined);
      expect(info.etaSource, isNot(EtaSource.historical));
      expect(info.calculationMethod, 'FREQUENCY_WINDOW');
      expect(_display(info), '🟢 6 min');
    });

    test('SCHEDULE reste SCHEDULE avec source SCHEDULE', () {
      final dataset = _datasetWithTimes([ServiceTime(13, 40, 0)]);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: DateTime.utc(2026, 9, 28, 13, 34),
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.etaSource, EtaSource.schedule);
      expect(_display(info), '🟢 6 min');
    });
  });

  group('Lot 4.14 — BRT / DDD / AFTU généralisés', () {
    test('BRT B1 fréquence 6 → ETA 5 min à 14:01 (COMBINED, pas HISTORICAL)', () {
      final info = DataService().departureInfoForRoute('brt_b1_guediawaye_petersen', DateTime.utc(2026, 9, 28, 14, 1));
      expect(info.status, ScheduleStatus.estimated);
      expect(info.etaSource, EtaSource.combined);
      expect(info.etaSource, isNot(EtaSource.historical));
      expect(_display(info), '🟢 5 min');
    });

    test('BRT B2 fréquence 6 → ETA', () {
      final info = DataService().departureInfoForRoute('brt_b2_express', DateTime.utc(2026, 9, 28, 14, 1));
      expect(info.status, ScheduleStatus.estimated);
      expect(_display(info), '🟢 5 min');
    });

    test('TER fréquence 10 → ETA 5 min à 14:00', () {
      final info = DataService().departureInfoForRoute('ter_dakar_diamniadio', DateTime.utc(2026, 9, 28, 14, 0));
      expect(info.status, ScheduleStatus.estimated);
      expect(_display(info), '🟢 5 min');
    });

    test('DDD sans horaire → Horaire indisponible (jamais inventé)', () {
      final info = DataService().departureInfoForRoute('ddd_1', DateTime.utc(2026, 9, 28, 14, 0));
      expect(info.status, ScheduleStatus.unknown);
      expect(_display(info), 'Horaire indisponible');
      expect(_display(info), isNot(contains('🟢')));
    });

    test('AFTU sans horaire → Horaire indisponible', () {
      final info = DataService().departureInfoForRoute('aftu_1', DateTime.utc(2026, 9, 28, 14, 0));
      expect(info.status, ScheduleStatus.unknown);
      expect(_display(info), 'Horaire indisponible');
    });
  });
}
