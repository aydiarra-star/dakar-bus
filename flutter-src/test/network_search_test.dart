// Chantier « Recherche + GPS + Routage » — tests de la recherche exhaustive.
//
// La barre de recherche interroge le MÊME référentiel que le GPS, construit à
// partir des données réellement chargées. Aucune entrée n'est inventée : une
// requête qui ne correspond à rien rend une liste vide.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/network_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
    await app.appDataService.loadPassBiSchedules();
    app.integratePassBiNativeStopsForTest();
    await app.appDataService.loadTerminusCatalog();
    app.integrateNetworkSearchCatalogForTest();
  });

  group('Recherche — référentiel exhaustif', () {
    test('le catalogue couvre toutes les natures du référentiel', () {
      final catalog = app.currentNetworkSearchCatalog;
      expect(catalog.total, greaterThan(0));
      expect(catalog.countOf(NetworkSearchKind.mobility), 4,
          reason: 'TER, BRT, DDD, AFTU sont les mobilités réellement chargées');
      expect(catalog.countOf(NetworkSearchKind.line), greaterThan(50));
      expect(catalog.stopLikeCount, greaterThan(1000),
          reason: 'les arrêts réels du feed doivent tous être indexés');
      expect(catalog.countOf(NetworkSearchKind.pole), greaterThan(0));
      expect(catalog.countOf(NetworkSearchKind.destination), greaterThan(0));
    });

    test('le catalogue est construit depuis les données réseau (pas une liste '
        'préchargée)', () {
      final catalog = app.currentNetworkSearchCatalog;
      // Nombre d'arrêts indexés == nombre d'arrêts natifs réellement desservis.
      int nativeCount = 0;
      for (final key in PassBiSource.assetFiles.keys) {
        nativeCount += app.appDataService.passBiSource.nativeStops(key).length;
      }
      expect(catalog.stopLikeCount, nativeCount,
          reason: 'chaque arrêt réel doit avoir une entrée de recherche');
    });
  });

  group('Recherche — mobilités, lignes, arrêts, gares, terminus, destinations',
      () {
    test('recherche d\'une mobilité', () {
      final hits = app.searchNetworkCatalog('AFTU');
      expect(hits.any((h) => h.kind == NetworkSearchKind.mobility &&
          h.label == 'AFTU'), isTrue);
    });

    test('recherche d\'une ligne (libellé réel du feed)', () {
      final hits = app.searchNetworkCatalog('AFTU_37');
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.kind == NetworkSearchKind.line), isTrue);
    });

    test('recherche d\'un arrêt', () {
      final hits = app.searchNetworkCatalog('Keur Mbaye Fall');
      expect(hits.any((h) => h.kind == NetworkSearchKind.stop), isTrue);
    });

    test('recherche d\'une gare / station', () {
      final hits = app.searchNetworkCatalog('Petersen');
      expect(
          hits.any((h) => h.kind == NetworkSearchKind.station), isTrue);
    });

    test('recherche d\'un terminus documenté', () {
      final hits = app.searchNetworkCatalog('Terminus Leclerc');
      expect(hits.any((h) => h.kind == NetworkSearchKind.terminus), isTrue);
    });

    test('recherche d\'une destination documentée', () {
      final hits = app.searchNetworkCatalog('Terminus Leclerc');
      expect(
          hits.any((h) => h.kind == NetworkSearchKind.destination), isTrue);
    });

    test('la recherche est exhaustive (au-delà des éléments préchargés)',
        () {
      // « Parcelles » remonte plusieurs arrêts réels distincts.
      final hits = app.searchNetworkCatalog('Parcelles', limit: 50);
      expect(hits.length, greaterThan(5));
    });

    test('une requête sans correspondance ne rend rien (aucune invention)',
        () {
      final hits = app.searchNetworkCatalog('zzzz-introuvable-zzzz');
      expect(hits, isEmpty);
    });

    test('une requête trop courte ne déclenche pas de recherche', () {
      expect(app.searchNetworkCatalog('a'), isEmpty);
    });
  });

  group('Recherche — GPS et barre de recherche = même référentiel', () {
    test('un arrêt trouvé par recherche textuelle est un arrêt réel du feed '
        'exploitable par le routage', () {
      final hits = app.searchNetworkCatalog('Parcelles');
      final stopHits = hits
          .where((h) =>
              (h.kind == NetworkSearchKind.stop ||
                  h.kind == NetworkSearchKind.station) &&
              h.compositeKey != null)
          .toList();
      expect(stopHits, isNotEmpty);
      final entry = stopHits.first;
      // L'arrêt existe bien dans le référentiel natif du réseau annoncé.
      final ids = app.appDataService.passBiSource
          .nativeStops(entry.network)
          .map((s) => s.stopId)
          .toSet();
      expect(ids, contains(entry.stopId));
    });

    test('la position d\'un lieu résolu par recherche est celle d\'un arrêt '
        'réel', () {
      final p = app.RoutePlanner.positionForQuery('Petersen');
      expect(p, isNotNull);
      // La position doit coïncider EXACTEMENT avec un arrêt réel nommé
      // « Petersen » (référentiel dakar ou arrêt natif du feed) — jamais une
      // coordonnée approximative inventée.
      final candidates = <double>[];
      for (final s in app.allStops) {
        if (s.name.toLowerCase().contains('petersen')) {
          candidates.add(s.location.latitude);
        }
      }
      for (final r in app.appDataService.passBiStopSearch('Petersen')) {
        candidates.add(r.lat);
      }
      expect(candidates, isNotEmpty);
      expect(
        candidates.any((lat) => (lat - p!.latitude).abs() < 1e-9),
        isTrue,
        reason: 'la position résolue doit être celle d\'un arrêt réel',
      );
    });

    test('une destination inconnue ne résout vers aucune position', () {
      expect(app.RoutePlanner.positionForQuery('zzz-inconnu-zzz'), isNull);
    });
  });
}
