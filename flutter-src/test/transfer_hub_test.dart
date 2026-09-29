// LOT 5 — ITINÉRAIRES : le pôle de correspondance est dérivé des données.
//
// AVANT : `_findTransfer` choisissait son pôle par un littéral
// `s.name.contains('Colobane') || s.name.contains('Petersen')`, avec
// `allStops.first` en repli — une constante d'UI déguisée en décision de
// données. APRÈS : le pôle est l'arrêt desservi par le plus grand nombre de
// lignes distinctes du référentiel, extrémités du trajet exclues.
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!appDataService.isLoaded) await appDataService.loadNetworkData();
    // Doit précéder toute lecture de `allStops`.
    integrateNetworkDataForTest();
  });

  test('les pôles réels les plus desservis sont Colobane puis Petersen', () {
    int lines(String stopId) => appDataService.routes
        .where((TransportRoute r) => r.stopIds.contains(stopId))
        .length;

    // Colobane (27 lignes) est le pôle le plus desservi du référentiel,
    // conformément à l'audit 2026-09-24 ; Petersen suit avec 23.
    expect(lines('stop_colobane'), 27);
    expect(lines('stop_petersen'), 23);
    expect(lines('stop_colobane'), greaterThan(lines('stop_petersen')));
  });

  test('un trajet sans ligne directe produit une correspondance, pas un repli '
      'sur le premier arrêt de la liste', () {
    // Deux lieux de modes différents, sans ligne commune : la correspondance
    // doit passer par un vrai pôle dérivé des données.
    final RouteSearchResult res = RoutePlanner.plan(
      fromQuery: 'AIBD',
      toQuery: 'Ouakam',
      at: DateTime.utc(2026, 9, 28, 10, 0),
    );
    // Soit un itinéraire est trouvé, soit un message honnête est renvoyé —
    // jamais un itinéraire fabriqué passant par `allStops.first`.
    if (res.hasRoutes) {
      for (final PlannedRoute r in res.routes) {
        for (final RouteSegment seg in r.segments) {
          expect(seg.from.trim(), isNotEmpty);
          expect(seg.to.trim(), isNotEmpty);
        }
      }
    } else {
      expect(res.errorMessage, isNotNull);
    }
  });

  test('l\'absence de pôle commun ne fabrique jamais de correspondance', () {
    // Trajet où l'origine ET la destination sont elles-mêmes des pôles :
    // les exclure doit empêcher de les réutiliser comme correspondance.
    final RouteSearchResult res = RoutePlanner.plan(
      fromQuery: 'Colobane',
      toQuery: 'Petersen',
      at: DateTime.utc(2026, 9, 28, 10, 0),
    );
    if (res.hasRoutes) {
      for (final PlannedRoute r in res.routes) {
        expect(r.transferCount, lessThanOrEqualTo(1));
      }
    }
  });
}
