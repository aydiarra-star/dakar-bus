// GARDE-FOU — IDENTITÉ PUBLIQUE DES LIGNES D'UN PÔLE.
//
// Un `route_id` de feed (`DDD_05`, `AFTU_223`) n'est JAMAIS un numéro de ligne
// public. Une fiche de pôle n'affiche « DDD 5 » que si le référentiel public
// ([PublicBusLineCatalog]) documente le raccordement ; sinon elle n'affiche que
// le mode. Aucun numéro interne n'est présenté comme numéro public, aucune
// identité n'est inventée par troncature de l'identifiant.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/terminus_pole.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
    await app.appDataService.loadTerminusCatalog();
    await app.appDataService.loadPublicBusLineCatalog();
    app.integrateNetworkSearchCatalogForTest();
  });

  group('Identité publique — résolution d\'un route_id de pôle', () {
    test('un route_id documenté rend le libellé public officiel', () {
      // `DDD_05` est raccordé à la ligne publique « DDD 5 » (et non « DDD 05 »).
      expect(app.appDataService.documentedLabelForFeedRouteId('DDD_05'), 'DDD 5');
      expect(app.appDataService.documentedLabelForFeedRouteId('DDD_01'), 'DDD 1');
      expect(app.appDataService.documentedLabelForFeedRouteId('AFTU_2'), 'AFTU 2');
    });

    test('un route_id non documenté ne rend AUCUN numéro public', () {
      // `DDD_223` n'est pas raccordé : jamais « DDD 223 » (numéro inventé).
      expect(app.appDataService.documentedLabelForFeedRouteId('DDD_223'), isNull);
    });

    test('les libellés publics de pôle viennent du référentiel, jamais du route_id',
        () {
      final List<TerminusPole> poles = app.appDataService.terminusCatalog.poles;
      expect(poles, isNotEmpty);

      int undocumented = 0;
      int naiveWouldDiffer = 0;
      for (final TerminusPole pole in poles) {
        for (final String routeId in [...pole.dddRoutes, ...pole.aftuRoutes]) {
          final String mode = routeId.startsWith('DDD_') ? 'DDD' : 'AFTU';
          final String internalNumber =
              routeId.substring(routeId.indexOf('_') + 1);
          final String? label =
              app.appDataService.documentedLabelForFeedRouteId(routeId);
          if (label == null) {
            undocumented++;
            continue;
          }
          // Le libellé est bien un numéro public cohérent avec le mode…
          expect(label, startsWith('$mode '));
          expect(label, isNot(contains('_')),
              reason: '$routeId : identifiant interne exposé');
          // …et il peut différer du numéro interne (`DDD_05` → « DDD 5 »).
          if (label != '$mode $internalNumber') naiveWouldDiffer++;
        }
      }
      // Deux anomalies réelles existaient : des routes non raccordées
      // (numéro interne « DDD 223 ») et des numéros à zéro initial (« DDD 05 »).
      // Le référentiel les neutralise : preuve que le garde-fou est utile.
      expect(undocumented, greaterThan(0),
          reason: 'aucune route de pôle non raccordée : le repli n\'est pas testé');
      expect(naiveWouldDiffer, greaterThan(0),
          reason: 'aucun numéro à zéro initial : le garde-fou n\'est pas testé');
    });
  });

  group('Identité publique — rendu d\'une fiche de pôle', () {
    Future<void> pumpPole(WidgetTester tester, String poleId) async {
      final TerminusPole pole = app.appDataService.terminusCatalog.poles
          .firstWhere((p) => p.id == poleId);
      await tester.pumpWidget(MaterialApp(home: app.TerminusPolePage(pole: pole)));
      await tester.pumpAndSettle();
    }

    testWidgets('Gare de Petersen : « DDD 223 » n\'est jamais rendu',
        (WidgetTester tester) async {
      await pumpPole(tester, 'petersen');
      expect(find.textContaining('DDD 223'), findsNothing,
          reason: 'identifiant interne rendu comme numéro de ligne');
      // Les lignes AFTU documentées, elles, sont bien affichées.
      expect(find.textContaining('AFTU 2'), findsWidgets);
    });

    testWidgets('Parcelles Assainies : aucun numéro interne « DDD 0x » rendu',
        (WidgetTester tester) async {
      await pumpPole(tester, 'parcelles_assainies');
      expect(find.textContaining('DDD 01'), findsNothing);
      expect(find.textContaining('DDD 05'), findsNothing);
      // Identité publique documentée, en revanche, présente.
      expect(find.textContaining('DDD 1'), findsWidgets);
    });
  });
}
