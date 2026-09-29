// LOT 3 — ROUTAGE : aucune correspondance créée par simple proximité.
//
// Une correspondance TER ↔ bus (ou bus ↔ bus) n'est autorisée que si un arrêt
// physique/documenté commun la fonde : au moins une LIGNE RÉELLE du référentiel
// dessert les deux arrêts. Un pôle « le plus desservi », une distance courte ou
// une orientation de sens ne suffisent jamais.
//
// Deux fabrications sont verrouillées ici :
//   1. `_findTransfer` construisait deux tronçons `from → hub` et `hub → to`
//      sans vérifier qu'une ligne les desservait réellement (correspondance par
//      proximité géographique vers le pôle le plus desservi) ;
//   2. `_findNearestStop` résolvait un lieu inconnu vers `allStops.first`
//      (origine fabriquée), au lieu de répondre « lieu introuvable ».
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!appDataService.isLoaded) await appDataService.loadNetworkData();
    integrateNetworkDataForTest();
  });

  /// Vrai si au moins une ligne RÉELLE dessert les deux arrêts nommés.
  bool servedByCommonRoute(String aName, String bName) {
    final List<BusStop> stops = appDataService.stops;
    String? idOf(String name) {
      for (final BusStop s in stops) {
        if (s.name == name) return s.id;
      }
      return null;
    }

    final String? a = idOf(aName);
    final String? b = idOf(bName);
    if (a == null || b == null) return false;
    for (final TransportRoute r in appDataService.routes) {
      if (r.stopIds.contains(a) && r.stopIds.contains(b)) return true;
    }
    return false;
  }

  test('source : aucune origine fabriquée par repli sur le premier arrêt', () {
    final String code = File('lib/main.dart').readAsStringSync();
    // On ignore les commentaires (qui documentent justement le retrait).
    final String executable = code
        .split('\n')
        .where((String l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(executable.contains('orElse: () => allStops.first'), isFalse,
        reason: 'un lieu inconnu ne doit pas se résoudre sur un arrêt de repli');
  });

  test('source : _findTransfer exige une ligne réelle pour chaque tronçon', () {
    final String code = File('lib/main.dart').readAsStringSync();
    expect(code.contains('_servedByCommonRoute'), isTrue,
        reason: 'la correspondance doit être justifiée par une ligne réelle');
  });

  test('lieu de départ inconnu : « introuvable », jamais un arrêt de repli', () {
    final RouteSearchResult res =
        RoutePlanner.plan(fromQuery: 'AIBD', toQuery: 'Rufisque - Gare TER');
    expect(res.hasRoutes, isFalse);
    expect(res.errorMessage, isNotNull);
    expect(res.errorMessage, contains('introuvable'));
  });

  test('destination inconnue : « introuvable »', () {
    final RouteSearchResult res =
        RoutePlanner.plan(fromQuery: 'Gare TER Dakar', toQuery: 'Paris');
    expect(res.hasRoutes, isFalse);
    expect(res.errorMessage, contains('introuvable'));
  });

  test('toute correspondance produite est justifiée par une ligne réelle', () {
    // Balayage de couples intermodaux : chaque transition d'un itinéraire
    // produit doit reposer sur un arrêt commun réellement desservi.
    const List<List<String>> couples = <List<String>>[
      <String>['Almadies - Pointe', 'Gare TER Dakar'],
      <String>['Papa Gueye Fall - PEM Petersen BRT', 'Gare TER Dakar'],
      <String>['Papa Gueye Fall - PEM Petersen BRT', 'Bargny - Gare TER'],
      <String>['Biscuiterie - HLM', 'Rufisque - Gare TER'],
      <String>['Colobane - Marché & Gare TER', 'Papa Gueye Fall - PEM Petersen BRT'],
      <String>['PEM Petersen - Gare Routière', 'Palais de Justice - Dakar'],
    ];
    for (final List<String> c in couples) {
      final RouteSearchResult res = RoutePlanner.plan(
        fromQuery: c[0],
        toQuery: c[1],
        at: DateTime.utc(2026, 9, 28, 10, 0),
      );
      if (!res.hasRoutes) continue;
      for (final PlannedRoute r in res.routes) {
        final List<RouteSegment> segs = r.segments;
        for (int i = 1; i < segs.length; i++) {
          final String arrivee = segs[i - 1].to;
          final String depart = segs[i].from;
          // Même arrêt (le nom se répète) ou une ligne réelle relie les deux.
          expect(
            arrivee == depart || servedByCommonRoute(arrivee, depart),
            isTrue,
            reason: 'correspondance non documentée : $arrivee → $depart '
                '(couple ${c[0]} → ${c[1]})',
          );
        }
      }
    }
  });

  test('une correspondance sans ligne commune n\'est jamais produite', () {
    // Deux gares TER : `_findTransfer` peut être sollicité sur ce couple, mais
    // une gare TER n'est reliée à aucune autre que par la ligne TER elle-même.
    // Toute correspondance éventuelle doit rester fondée sur une ligne réelle.
    final RouteSearchResult res = RoutePlanner.plan(
      fromQuery: 'Bargny - Gare TER',
      toQuery: 'Keur Mbaye Fall - Gare TER',
      at: DateTime.utc(2026, 9, 28, 10, 0),
    );
    if (res.hasRoutes) {
      for (final PlannedRoute r in res.routes) {
        final List<RouteSegment> segs = r.segments;
        for (int i = 1; i < segs.length; i++) {
          expect(
            segs[i - 1].to == segs[i].from ||
                servedByCommonRoute(segs[i - 1].to, segs[i].from),
            isTrue,
            reason: 'transition non documentée ${segs[i - 1].to} → ${segs[i].from}',
          );
        }
      }
    }
  });
}
