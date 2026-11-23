import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_provider.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final expiredFeed = PassBiSource();

  setUpAll(() async {
    await expiredFeed.loadAll();
  });

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
        'line_ter_dakar_diamniadio',
        'line_brt_b1_guediawaye_petersen',
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
        routeId: 'other_route_1',
        stopId: 'stop_test',
        network: 'AUTRE_RESEAU',
        at: at,
      );

      // Vérifie que le verrou est limité à TER, BRT, DDD et AFTU.
      expect(info.status, ScheduleStatus.estimated);
    });
  });

  test('un calendrier GTFS reste appliqué après sa date de fin d’origine', () {
    final network = expiredFeed.network('TER')!;
    final entry = network.services.asMap().entries.firstWhere(
      (item) => item.value.mask != 0 &&
          item.value.end.compareTo('20350101') < 0,
    );
    final service = entry.value;

    DateTime? matchingDay;
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime.utc(2035, 1, 1 + offset);
      final weekdayBit = day.weekday - 1;
      if ((service.mask & (1 << weekdayBit)) != 0) {
        matchingDay = day;
        break;
      }
    }

    expect(matchingDay, isNotNull,
        reason: 'le service doit conserver au moins un jour hebdomadaire');
    expect(service.end.compareTo('20350101'), lessThan(0),
        reason: 'le test doit réellement utiliser une date de fin expirée');
    expect(network.serviceActiveOn(entry.key, matchingDay!), isTrue,
        reason: 'la date de fin historique ne doit pas désactiver le GTFS');
  });
}
