// Chantier « recherche + GPS + routage » — FICHE ARRÊT ALLER / RETOUR.
//
// Régression corrigée : l'onglet « Sens Retour » affichait soit un arrêt
// FABRIQUÉ (même arrêt affublé d'un sens inventé), soit « Arrêt en face non
// identifié » pour des arrêts TER/BRT qui desservent POURTANT les deux sens.
//
// Désormais, chaque onglet lit les VRAIS `trips` du feed et filtre sur le
// `headsign` réel (`DepartureInfo.direction`) :
//  * sens ALLER = sens DOMINANT (mode des prochains départs réels) ;
//  * sens RETOUR = tout AUTRE sens réellement desservi ;
//  * aucun horaire, aucun sens, aucun arrêt n'est fabriqué ; une direction non
//    desservie produit l'indisponibilité honnête, jamais un départ inventé.
//
// Données = feeds PassBi RÉELS (TER, BRT). TER/BRT ne sont pas modifiés : leurs
// arrêts, lignes et horaires restent ceux du feed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';

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
    expect(app.appDataService.passBiActive, isTrue);
  });

  app.Stop stopNamed(String name) =>
      app.allStops.firstWhere((app.Stop s) => s.name == name);

  /// Instant de référence FIXE (heure de Dakar) pour des rendus déterministes.
  ///
  /// Les horaires proviennent des `stop_times` RÉELS : à l'heure d'exécution, le
  /// dernier départ réel peut être passé (le feed BRT s'arrête à ~21 h 56) et
  /// l'écran affiche alors honnêtement l'indisponibilité. Fixer l'instant ne
  /// fabrique AUCUNE donnée : même feed, daté en heure pleine de service.
  final DateTime refAt = DateTime.utc(2026, 9, 30, 15, 0);

  test('filtre de sens : ne restreint QUE des départs réels, jamais ne crée',
      () {
    final app.Stop s = stopNamed('Gare TER Dakar');
    final List<DepartureInfo> all = s.nextRealDepartures(at: refAt, limit: 6);
    expect(all, isNotEmpty, reason: 'TER Gare Dakar doit avoir des départs réels');

    final String dominant = s.nextRealDepartures(at: refAt, limit: 12)
        .map((d) => d.direction ?? '')
        .where((d) => d.isNotEmpty)
        .fold<Map<String, int>>(<String, int>{}, (m, d) {
          m[d] = (m[d] ?? 0) + 1;
          return m;
        })
        .entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    expect(dominant, 'Diamniadio');

    // ALLER = dominant ; RETOUR = tout autre sens réel.
    final List<DepartureInfo> aller = s.realDeparturesWhere(
        (d) => d.direction == dominant,
        at: refAt,
        limit: 3);
    final List<DepartureInfo> retour = s.realDeparturesWhere(
        (d) => d.direction != null && d.direction != dominant,
        at: refAt,
        limit: 3);

    expect(aller, isNotEmpty);
    expect(retour, isNotEmpty, reason: 'Gare TER Dakar dessine les deux sens');
    // Chaque départ affiché appartient au bon sens — et provient d'un vrai trip.
    for (final d in aller) {
      expect(d.direction, dominant);
      expect(d.scheduledTime, isNotNull);
    }
    for (final d in retour) {
      expect(d.direction, isNot(dominant));
      expect(d.scheduledTime, isNotNull);
    }
    // Les horaires des deux sens diffèrent : ce n'est pas une inversion.
    expect(
      aller.map((d) => d.scheduledTime).toList(),
      isNot(equals(retour.map((d) => d.scheduledTime).toList())),
    );
  });

  test('minutes d\'attente filtrées par sens : cohérentes avec le sens', () {
    final app.Stop s = stopNamed('Gare TER Dakar');
    final List<int> aller =
        s.nextRealWaitingMinutesToward((d) => d == 'Diamniadio', at: refAt);
    final List<int> retour = s.nextRealWaitingMinutesToward(
        (d) => d != null && d != 'Diamniadio',
        at: refAt);
    expect(aller, isNotEmpty);
    expect(retour, isNotEmpty);
    for (final m in <int>[...aller, ...retour]) {
      expect(m, greaterThan(0), reason: 'jamais 0 mn (départ passé ignoré)');
    }
  });

  testWidgets('TER Gare Dakar : les DEUX onglets affichent des horaires réels',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MaterialApp(
            home: app.DualStopDetailPage(
                stop: stopNamed('Gare TER Dakar'), at: refAt)));
    await tester.pumpAndSettle();

    // Onglet ALLER : ni placeholder « non identifié », ni sens fabriqué, des
    // temps d'attente RÉELS.
    expect(find.textContaining('non identifié'), findsNothing);
    expect(find.textContaining('Embarquement)'), findsNothing);
    expect(find.textContaining('mn'), findsWidgets);

    // Onglet RETOUR : lui aussi des horaires RÉELS (le bug affichait
    // « Arrêt en face non identifié »).
    await tester.tap(find.widgetWithText(Tab, 'Sens Retour'));
    await tester.pumpAndSettle();
    expect(find.textContaining('non identifié'), findsNothing);
    expect(find.textContaining('Aucun départ réel'), findsNothing);
    expect(find.textContaining('mn'), findsWidgets);
  });

  testWidgets('BRT mono-sens : le sens non desservi reste honnête (aucun faux)',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        home: app.DualStopDetailPage(
            stop: stopNamed('Préfecture Guédiawaye - PEM BRT'), at: refAt)));
    await tester.pumpAndSettle();

    // L'aller (PETERSEN) est desservi : horaires réels présents.
    expect(find.textContaining('mn'), findsWidgets);

    // Le retour n'a aucun départ réel : indisponibilité explicite, pas de faux.
    await tester.tap(find.widgetWithText(Tab, 'Sens Retour'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Aucun départ réel programmé dans le sens retour'),
      findsOneWidget,
    );
  });
}
