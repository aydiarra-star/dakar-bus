import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_provider.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  group('exclusivité GTFS pour les quatre réseaux couverts', () {
    final at = DateTime.utc(2026, 9, 28, 10, 0);

    test('un flux non chargé ne déclenche jamais les fréquences TER/BRT', () {
      // PassBiSource volontairement non chargé : l'ancien calculateur
      // retombait ici sur les fréquences TER/BRT et retournait ESTIMATED.
      final calculator = EtaCalculator(
        scheduleProvider: ScheduleProvider(PassBiSource()),
        frequencyProvider: DataProvider(),
      );

      final cases = <({String network, String routeId})>[
        (network: 'TER', routeId: 'ter_dakar_diamniadio'),
        (network: 'BRT', routeId: 'brt_b1_guediawaye_petersen'),
        (network: 'DDD', routeId: 'ddd_1'),
        (network: 'AFTU', routeId: 'aftu_1'),
      ];

      for (final item in cases) {
        final info = calculator.compute(
          routeId: item.routeId,
          stopId: 'stop_test',
          network: item.network,
          at: at,
          operatorName: item.network,
        );
        expect(
          info.status,
          ScheduleStatus.unknown,
          reason: '${item.network} ne doit pas utiliser une fréquence de secours',
        );
        expect(info.scheduledTime, isNull);
        expect(info.frequencyMinutes, isNull);
        expect(info.unresolvedReason, UnresolvedReason.sourceInactive);
      }
    });

    test('API fréquence directe : route TER/BRT ne contourne pas le verrou', () {
      final service = DataService();

      for (final routeId in <String>[
        'ter_dakar_diamniadio',
        'brt_b1_guediawaye_petersen',
      ]) {
        final info = service.departureInfoForRoute(routeId, at);
        expect(info.status, ScheduleStatus.unknown);
        expect(info.frequencyMinutes, isNull);
        expect(info.unresolvedReason, UnresolvedReason.stopNotMatched);
      }
    });

    test('un réseau hors périmètre conserve le calcul historique', () {
      final calculator = EtaCalculator(
        scheduleProvider: ScheduleProvider(PassBiSource()),
        frequencyProvider: DataProvider(),
      );

      final info = calculator.compute(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_test',
        network: 'AUTRE_RESEAU',
        at: at,
      );

      // Vérifie que le verrou est limité à TER, BRT, DDD et AFTU.
      expect(info.status, ScheduleStatus.estimated);
    });
  });
}
