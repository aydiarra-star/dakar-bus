// Mission 3 — nettoyage des données fictives ou trompeuses encore visibles
// (audit données 2026-09-24).
//
// Objectif : aucune donnée de démonstration ne doit être confondue avec une
// information réelle par un voyageur. Ces tests empêchent la réapparition :
//  1. d'une affluence déduite de l'heure ;
//  2. de faux signalements d'usagers dans « Direct rue » ;
//  3. d'une source d'alerte non justifiée par la donnée ;
//  4. des points de démonstration DDD/TATA/AFTU dans l'affichage ;
//  5. d'une durée calculée présentée comme officielle ou garantie.
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Retire les lignes entièrement commentées (les blocs AVANT/APRÈS citent
/// volontairement les anciens textes).
String _code() => File('lib/main.dart')
    .readAsStringSync()
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n');

List<String> _textes(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

Future<void> _monte(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

/// Noms des 12 points de démonstration (conservés dans le code, non affichés).
List<String> _nomsDemo() => <Stop>[...dddStations, ...tataStations, ...aftuAndBusStations]
    .map((Stop s) => s.name)
    .toList();

Stop _unArretReel() => allStops.firstWhere((Stop s) => s.stopId != null);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!appDataService.isLoaded) {
      await appDataService.loadNetworkData();
    }
    expect(appDataService.stops.length, 117,
        reason: 'la donnée active doit être chargée, pas le repli en dur');
    expect(appDataService.routes.length, 105);
    integrateNetworkDataForTest();
  });

  // ==================================================================
  // 1. Affluence
  // ==================================================================
  group('1 — aucune affluence déduite de l\'heure', () {
    test('source : plus d\'estimation horaire de fréquentation', () {
      final String code = _code();
      for (final String interdit in <String>[
        'getCrowdLevel',
        'Bondé',
        'Heure de pointe',
        '🟠 Dense',
        '🟢 Fluide\'',
      ]) {
        expect(code.contains(interdit), isFalse, reason: interdit);
      }
      expect(ReliabilityLabel.crowdUnavailable, 'Affluence indisponible');
    });

    testWidgets('RENDU : la carte d\'arrêt affiche « Affluence indisponible »',
        (WidgetTester tester) async {
      await _monte(tester, Scaffold(body: StopCard(stop: _unArretReel(), distanceMeters: 300)));
      final List<String> textes = _textes(tester);
      expect(textes.any((String t) => t.contains('Affluence indisponible')), isTrue,
          reason: '$textes');
      for (final String t in textes) {
        expect(t, isNot(contains('Bondé')));
        expect(t, isNot(contains('Fluide')));
        expect(t, isNot(contains('Dense')));
      }
    });

    testWidgets('RENDU : la fiche d\'arrêt affiche « Affluence indisponible »',
        (WidgetTester tester) async {
      await _monte(tester, Scaffold(body: SingleStopView(stop: _unArretReel())));
      final List<String> textes = _textes(tester);
      expect(textes, contains('Affluence indisponible'));
      expect(textes.where((String t) => t.contains('Bondé') || t.contains('Fluide')), isEmpty);
    });
  });

  // ==================================================================
  // 2. Onglet « Direct rue »
  // ==================================================================
  group('2 — aucun faux signalement d\'usager', () {
    test('source : noms et signalements fictifs absents du code', () {
      final String code = _code();
      for (final String interdit in <String>[
        'Mamadou S.',
        'Aïssatou N.',
        'Embarquement régulier',
        'Signalement publié avec succès',
      ]) {
        expect(code.contains(interdit), isFalse, reason: interdit);
      }
    });

    testWidgets('RENDU : état vide explicite au démarrage, écran conservé',
        (WidgetTester tester) async {
      await _monte(tester, const CommunityAlertsPage());
      final List<String> textes = _textes(tester);
      expect(textes, contains('Direct rue & Communauté'));
      expect(textes, contains('Aucun signalement vérifié disponible pour le moment.'));
      expect(textes.where((String t) => t.startsWith('📍')), isEmpty);
      expect(find.byIcon(Icons.person), findsNothing,
          reason: 'aucune carte d\'usager n\'est rendue');
    });

    testWidgets('INTERACTION : le signalement saisi reste local et non vérifié',
        (WidgetTester tester) async {
      await _monte(tester, const CommunityAlertsPage());
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Colobane');
      await tester.tap(find.text('Publier mon signalement'));
      await tester.pumpAndSettle();

      final List<String> textes = _textes(tester);
      expect(textes, contains('Moi (Usager)'));
      expect(textes, contains('Non vérifié'));
      expect(textes, isNot(contains('Aucun signalement vérifié disponible pour le moment.')));
      expect(textes.where((String t) => t.startsWith('📍')), hasLength(1),
          reason: 'seul le signalement réellement saisi apparaît');
      expect(textes.any((String t) => t.contains('non partagé')), isTrue,
          reason: 'le message de confirmation ne prétend pas à une publication');
    });
  });

  // ==================================================================
  // 3. Sources des cartes d'alerte
  // ==================================================================
  group('3 — chaque source d\'alerte correspond à la donnée', () {
    testWidgets('RENDU : sources TER / BRT / DDD issues de la provenance', (WidgetTester tester) async {
      await _monte(tester, const AlertsPage());
      final List<String> sources =
          _textes(tester).where((String t) => t.startsWith('Source') || t.startsWith('Total')).toList();
      expect(sources, hasLength(3), reason: '$sources');

      final TransportRoute ter = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'ter_dakar_diamniadio');
      final TransportRoute b1 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'brt_b1_guediawaye_petersen');
      final Operator ddd = appDataService.operators.firstWhere((Operator o) => o.id == 'ddd');

      expect(ter.provenance.status, ProvenanceStatus.confirmed);
      expect(ter.provenance.source, contains('SETER'));
      expect(sources, contains('Source officielle : SETER (terdakar.sn)'));

      expect(b1.provenance.status, ProvenanceStatus.confirmed);
      expect(b1.provenance.source, contains('SunuBRT'));
      expect(sources, contains('Source officielle : SunuBRT (sunubrt.sn)'));

      expect(ddd.officialLineCountSource, 'CETUD');
      expect(sources.any((String s) => s.contains('CETUD') && s.contains('non vérifiés')), isTrue);

      for (final String s in sources) {
        expect(s, isNot(contains('Dakar Mobilité')), reason: 'attribution sans justification');
      }
    });
  });

  // ==================================================================
  // 4. Points de démonstration DDD / TATA / AFTU
  // ==================================================================
  group('4 — aucun point de démonstration dans l\'affichage', () {
    test('structure conservée : les 12 points restent définis dans le code', () {
      expect(_nomsDemo(), hasLength(12));
      expect(_nomsDemo(), contains('DDD Ligne 3 (Sandaga - Ouakam)'));
      expect(_nomsDemo(), contains('DDD Ligne 14 (Gare Maritime - UCAD)'));
    });

    test('affichage : aucun point de démo dans allStops (carte, listes, planificateur)', () {
      final Set<String> demo = _nomsDemo().toSet();
      expect(allStops, isNotEmpty);
      for (final Stop s in allStops) {
        expect(demo.contains(s.name), isFalse, reason: s.name);
        expect(s.stopId, isNotNull, reason: '${s.name} : tout arrêt affiché vient du JSON');
      }
      final Set<String> idsJson = appDataService.stops.map((BusStop b) => b.id).toSet();
      expect(allStops.every((Stop s) => idsJson.contains(s.stopId)), isTrue);
    });

    test('données réelles intactes : routes ddd_3 / ddd_14 et arrêts dupliqués conservés', () {
      final Set<String> routes = appDataService.routes.map((TransportRoute r) => r.id).toSet();
      expect(routes, containsAll(<String>['ddd_3', 'ddd_14']),
          reason: 'aucune route du JSON n\'est supprimée');
      final Set<String> affiches =
          allStops.map((Stop s) => s.stopId).whereType<String>().toSet();
      expect(affiches, containsAll(<String>['stop_ucad', 'stop_mermoz', 'stop_grand_yoff']),
          reason: 'les arrêts réels que la démo dupliquait restent affichés');
    });

    test('planificateur : un libellé de démo ne résout plus vers un faux arrêt', () {
      final RouteSearchResult res =
          RoutePlanner.plan(fromQuery: 'DDD Ligne 3', toQuery: 'Gare TER Dakar');
      for (final PlannedRoute r in res.routes) {
        for (final RouteSegment seg in r.segments) {
          expect(seg.from, isNot(contains('DDD Ligne')));
          expect(seg.to, isNot(contains('DDD Ligne')));
        }
      }
    });
  });

  // ==================================================================
  // 5. Estimation de durée
  // ==================================================================
  group('5 — la durée calculée est toujours marquée estimée', () {
    test('libellé : estimée et non garantie', () {
      expect(ReliabilityLabel.estimatedDuration, contains('estimée'));
      expect(ReliabilityLabel.estimatedDuration, contains('non garantie'));
      final String code = _code();
      expect(code.contains("'Durée totale'"), isFalse);
      expect(code.contains("'Durée: "), isFalse);
    });

    test('assistant : chaque durée affichée est qualifiée d\'estimation', () {
      final RouteSearchResult res =
          RoutePlanner.plan(fromQuery: 'Gare TER Dakar', toQuery: 'Rufisque - Gare TER');
      expect(res.hasRoutes, isTrue);
      final String txt = AssistantReplies.itinerary(res.routes.first, 'Dakar', 'Rufisque');
      final List<String> lignesDuree =
          txt.split('\n').where((String l) => RegExp(r'\d+ min').hasMatch(l)).toList();
      expect(lignesDuree, isNotEmpty);
      for (final String l in lignesDuree) {
        expect(l.toLowerCase(), contains('estim'), reason: l);
        expect(l.toLowerCase(), isNot(contains('officiel')), reason: l);
      }
    });
  });

  // Garde-fou : la suggestion DDD ne présente plus un itinéraire contesté
  // comme une ligne établie ; plus de « populaires » sans donnée.
  test('source : suggestions sans popularité supposée ni itinéraire présenté comme établi', () {
    final String code = _code();
    expect(code.contains('Suggestions populaires'), isFalse);
    expect(code.contains("'Colobane - Yoff (DDD Ligne 1)'"), isFalse);
    final TransportRoute ddd1 =
        appDataService.routes.firstWhere((TransportRoute r) => r.id == 'ddd_1');
    expect(ddd1.provenance.status, ProvenanceStatus.conflicting,
        reason: 'la puce « itinéraire contesté » reflète le statut réel de ddd_1');
  });

  test('contrôle : la position utilisée par les tests est dans Dakar', () {
    expect(DakarBounds.isValid(const LatLng(14.7167, -17.4677)), isTrue);
  });
}
