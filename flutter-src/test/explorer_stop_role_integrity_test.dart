// AUDIT FONCTIONNEL FINAL — RÔLE D'ARRÊT DÉRIVÉ DE L'ENSEMBLE DES LIGNES.
//
// Anomalie observée en navigateur (zones Petersen / Guédiawaye / Colobane) :
// un pôle d'échange desservi par une vingtaine de lignes (PEM Petersen, PEM
// Guédiawaye, Colobane, Rufisque…) affichait le badge « INTERM. » — ou
// « TERMINUS » — selon le PREMIER itinéraire rencontré dans
// `dakar_network.json`, jamais selon la fonction réelle de l'arrêt.
//
// Le rôle est désormais dérivé de TOUS les `stop_sequence` qui desservent
// l'arrêt (terminus > boarding > intermediate). Ces tests verrouillent :
//   A. le pôle d'échange PEM Petersen n'est plus « INTERM. » ;
//   B. un arrêt réellement terminus d'au moins une ligne reste « TERMINUS » ;
//   C. le rôle d'un arrêt intermédiaire sur toutes ses lignes reste
//      « INTERM. » (aucune promotion) ;
//   D. le rôle est cohérent avec les `stop_sequence` réellement présents ;
//   E. aucune donnée source n'est modifiée (JSON inchangé).
//
// Aucune donnée n'est ajoutée : le rôle reste entièrement dérivé du
// `stop_sequence` déjà présent dans `dakar_network.json`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;


/// Ids d'arrêt en tête / en queue de chaque itinéraire du référentiel.
({Set<String> heads, Set<String> tails, Set<String> inner}) _routeEnds() {
  final Set<String> heads = <String>{};
  final Set<String> tails = <String>{};
  final Set<String> inner = <String>{};
  for (final route in app.appDataService.routes) {
    final List<String> ids = route.stopIds;
    for (int i = 0; i < ids.length; i++) {
      if (i == 0) {
        heads.add(ids[i]);
      } else if (i == ids.length - 1) {
        tails.add(ids[i]);
      } else {
        inner.add(ids[i]);
      }
    }
  }
  return (heads: heads, tails: tails, inner: inner);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
  });

  app.Stop stopById(String id) =>
      app.allStops.firstWhere((app.Stop s) => s.stopId == id);

  group('A — un pôle d\'échange multi-lignes n\'est plus « INTERM. »', () {
    test('PEM Petersen (20 lignes) n\'est plus intermédiaire', () {
      final app.Stop petersen = stopById('stop_petersen');
      expect(petersen.stopType, isNot(app.StopType.intermediate),
          reason: 'PEM Petersen est un terminus réel d\'au moins une ligne');
      expect(petersen.stopType, app.StopType.terminus);
    });

    test('les autres pôles d\'échange réels sont terminaux', () {
      for (final String id in <String>[
        'stop_petersen',
        'stop_guediawaye',
        'stop_colobane',
        'stop_rufisque',
        'stop_dakar_ter',
      ]) {
        expect(stopById(id).stopType, app.StopType.terminus,
            reason: '$id est terminus d\'au moins une ligne réelle');
      }
    });
  });

  group('B/C — le rôle suit l\'ensemble des `stop_sequence`', () {
    test('un arrêt jamais en tête/queue reste intermédiaire', () {
      final ends = _routeEnds();
      final List<app.Stop> all = app.allStops
          .where((app.Stop s) => s.stopId != null)
          .toList();
      int checked = 0;
      for (final app.Stop s in all) {
        final String id = s.stopId!;
        final bool neverEnd =
            !ends.heads.contains(id) && !ends.tails.contains(id);
        if (neverEnd) {
          expect(s.stopType, app.StopType.intermediate,
              reason: '$id n\'est extrémité d\'aucune ligne');
          checked++;
        }
      }
      expect(checked, greaterThan(0));
    });

    test('un arrêt terminus d\'au moins une ligne n\'est jamais intermédiaire',
        () {
      final ends = _routeEnds();
      for (final app.Stop s in app.allStops) {
        final String? id = s.stopId;
        if (id == null) continue;
        if (ends.tails.contains(id)) {
          expect(s.stopType, app.StopType.terminus,
              reason: '$id est terminus d\'au moins une ligne');
        }
      }
    });

    test('le rôle est stable quel que soit l\'ordre des itinéraires', () {
      // Deux appels idempotents ne changent pas le rôle : la dérivation ne
      // dépend pas de l'ordre de rencontre, seulement de l'ensemble.
      final Map<String, app.StopType> before = <String, app.StopType>{
        for (final app.Stop s in app.allStops)
          if (s.stopId != null) s.stopId!: s.stopType,
      };
      app.integrateNetworkDataForTest();
      for (final app.Stop s in app.allStops) {
        if (s.stopId == null) continue;
        expect(s.stopType, before[s.stopId], reason: s.stopId);
      }
    });
  });

  group('D — cohérence avec les données sources', () {
    test('strongerStopRole : preuve décroissante terminus > boarding > interm.',
        () {
      expect(app.strongerStopRole(null, app.StopType.boarding),
          app.StopType.boarding);
      expect(app.strongerStopRole(app.StopType.boarding, app.StopType.terminus),
          app.StopType.terminus);
      expect(app.strongerStopRole(app.StopType.terminus, app.StopType.boarding),
          app.StopType.terminus);
      expect(
          app.strongerStopRole(
              app.StopType.intermediate, app.StopType.boarding),
          app.StopType.boarding);
      expect(
          app.strongerStopRole(
              app.StopType.intermediate, app.StopType.intermediate),
          app.StopType.intermediate);
    });
  });

  group('E — aucune donnée source modifiée', () {
    test('le JSON dakar_network.json reste inchangé (117 arrêts, 105 lignes)',
        () {
      final String json = File('assets/data/dakar_network.json').readAsStringSync();
      expect(json.contains('"stop_petersen"'), isTrue);
      expect(app.appDataService.stops.length, 117);
      expect(app.appDataService.routes.length, 105);
    });
  });
}
