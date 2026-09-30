// Chantier DDD / AFTU / TATA — identification des pôles, gares routières et
// terminus.
//
// Vérifie le référentiel GÉNÉRÉ (`assets/data/reference/ddd_aftu_poles_terminus.json`,
// produit par `scripts/build-ddd-aftu-terminus.mjs` à partir des feeds PassBi)
// pour les 16 pôles du périmètre §3–§5 et pour les terminus découverts.
//
// Règle centrale (§10, §13) : une ligne n'est TERMINUS à un pôle que si elle
// figure dans `dddRoutes`/`aftuRoutes` — jamais parce qu'elle y passe. Une
// ligne en transit n'est jamais présentée comme terminant.
//
// Aucune donnée TER/BRT, aucun horaire, aucun routage n'est touché par ces tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/terminus_pole.dart';
import 'package:dakar_bus/services/terminus_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TerminusCatalog catalog = TerminusCatalog();
  late DddAftuTerminusReference ref;

  setUpAll(() async {
    await catalog.load();
    ref = catalog.reference!;
  });

  // ------------------------------------------------------------------ chargement
  group('Chargement du référentiel', () {
    test('le référentiel pôles/terminus DDD-AFTU est chargé', () {
      expect(catalog.isLoaded, isTrue);
      expect(ref.poles, isNotEmpty);
      expect(ref.generatedAt, isNotEmpty);
    });

    test('DDD : 53 routes analysées, 52 terminus A et 52 terminus B confirmés', () {
      expect(ref.raw['ddd']['totalRoutes'], 53);
      expect(ref.raw['ddd']['terminusAConfirmed'], 52);
      expect(ref.raw['ddd']['terminusBConfirmed'], 52);
    });

    test('AFTU : 73 routes analysées, 71 terminus A et 71 terminus B confirmés', () {
      expect(ref.raw['aftu']['totalRoutes'], 73);
      expect(ref.raw['aftu']['terminusAConfirmed'], 71);
      expect(ref.raw['aftu']['terminusBConfirmed'], 71);
    });
  });

  // ------------------------------------------------------- pôles obligatoires §3–§5
  group('Pôles obligatoires (§3–§5)', () {
    const requiredPoles = <String>[
      'petersen',
      'pem_guediawaye',
      'grand_medine',
      'colobane',
      'baux_maraichers',
      'diamniadio',
      'parcelles_assainies',
      'keur_massar',
      'pikine',
      'thiaroye',
      'rufisque',
      'sandaga',
      'yoff',
      'ouakam',
      'ngor',
      'mermoz',
    ];

    test('les 16 pôles du périmètre existent', () {
      for (final id in requiredPoles) {
        expect(ref.poleById(id), isNotNull, reason: 'pôle manquant : $id');
      }
    });

    test('chaque pôle a des coordonnées vérifiées, jamais océaniques', () {
      for (final id in requiredPoles) {
        final p = ref.poleById(id)!;
        expect(p.latitude, inInclusiveRange(14.55, 14.9), reason: id);
        expect(p.longitude, inInclusiveRange(-17.6, -16.85), reason: id);
        expect(p.latitude == 0 && p.longitude == 0, isFalse, reason: id);
        expect(p.coordinatesStatus, isNot(PoleCoordinatesStatus.rejected),
            reason: id);
      }
    });

    test('Petersen est un terminus DDD et AFTU documenté', () {
      final p = ref.poleById('petersen')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.roles, contains('TERMINUS'));
      expect(p.roles, contains('GARE_ROUTIERE'));
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
      expect(p.terminusStops, isNotEmpty);
      expect(p.coordinatesStatus, PoleCoordinatesStatus.confirmedVsFeed);
    });

    test('PEM Guédiawaye est terminus de lignes DDD, sans invention AFTU', () {
      final p = ref.poleById('pem_guediawaye')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      // Aucun terminus AFTU « Guédiawaye » dans le feed : la liste doit rester
      // vide, jamais complétée par supposition.
      expect(p.aftuRoutes, isEmpty);
    });

    test('Grand Médine : aucun terminus DDD/AFTU inventé, desserte en transit', () {
      final p = ref.poleById('grand_medine')!;
      expect(p.isTerminal, isFalse,
          reason: 'un rôle BRT ne prouve pas un terminus DDD/AFTU');
      expect(p.dddRoutes, isEmpty);
      expect(p.aftuRoutes, isEmpty);
      expect(p.status, PoleStatus.partial);
      expect(p.roles, contains('TRANSIT'));
      expect(p.dddTransitRoutes, isNotEmpty);
    });

    test('Colobane est terminus DDD et AFTU ET transit', () {
      final p = ref.poleById('colobane')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.roles, contains('TERMINUS'));
      expect(p.roles, contains('TRANSIT'));
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Baux Maraîchers est terminus DDD et AFTU documenté', () {
      final p = ref.poleById('baux_maraichers')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Diamniadio est terminus DDD ; coordonnée feed conservée', () {
      final p = ref.poleById('diamniadio')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      // La coordonnée déclarée (place_diamniadio, arrêt TER) diffère du
      // terminus DDD réel « Terminus Diamniadio » à ~3 km : la contradiction
      // est CONSERVÉE, jamais corrigée en déplaçant le point.
      expect(p.coordinatesStatus, PoleCoordinatesStatus.conflicting);
    });

    test('Parcelles Assainies est terminus DDD et AFTU documenté', () {
      final p = ref.poleById('parcelles_assainies')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Keur Massar est terminus DDD et AFTU documenté', () {
      final p = ref.poleById('keur_massar')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Pikine : aucun terminus DDD/AFTU, uniquement du transit', () {
      final p = ref.poleById('pikine')!;
      expect(p.isTerminal, isFalse);
      expect(p.status, PoleStatus.partial);
      expect(p.roles, contains('TRANSIT'));
      expect(p.dddTransitRoutes.length + p.aftuTransitRoutes.length,
          greaterThan(0));
    });

    test('Thiaroye est terminus DDD documenté', () {
      final p = ref.poleById('thiaroye')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
    });

    test('Rufisque est terminus DDD et AFTU documenté', () {
      final p = ref.poleById('rufisque')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Sandaga : aucune ligne ne doit y terminer sans preuve', () {
      final p = ref.poleById('sandaga')!;
      expect(p.isTerminal, isFalse,
          reason: 'aucun arrêt terminus nommé Sandaga dans le feed');
      expect(p.dddRoutes, isEmpty);
      expect(p.aftuRoutes, isEmpty);
    });

    test('le Plateau (Leclerc / Palais 1 / Palais 2) est terminus DDD', () {
      for (final id in ['plateau_leclerc', 'plateau_palais_1', 'plateau_palais_2']) {
        final p = ref.poleById(id)!;
        expect(p.isTerminal, isTrue, reason: id);
        expect(p.dddRoutes, isNotEmpty, reason: id);
      }
    });

    test('Yoff est terminus AFTU documenté', () {
      final p = ref.poleById('yoff')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Ouakam est terminus AFTU documenté', () {
      final p = ref.poleById('ouakam')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Ngor est terminus DDD et AFTU documenté', () {
      final p = ref.poleById('ngor')!;
      expect(p.status, PoleStatus.confirmed);
      expect(p.dddRoutes, isNotEmpty);
      expect(p.aftuRoutes, isNotEmpty);
    });

    test('Mermoz : statut objectivement déterminé (transit, pas terminus)', () {
      final p = ref.poleById('mermoz')!;
      expect(p.isTerminal, isFalse,
          reason: 'Mermoz est un pôle de transit/correspondance, pas un terminus');
      expect(p.status, PoleStatus.partial);
      expect(p.roles, contains('TRANSIT'));
      expect(p.dddTransitRoutes.isNotEmpty || p.aftuTransitRoutes.isNotEmpty,
          isTrue);
    });
  });

  // ------------------------------------------------------------- non-invention §13
  group('Non-invention des terminus', () {
    test('une ligne en transit n\'est jamais listée comme terminus', () {
      for (final p in ref.poles) {
        final Set<String> transit = <String>{
          ...p.dddTransitRoutes,
          ...p.aftuTransitRoutes,
        };
        for (final r in transit) {
          expect(p.terminatesHere(r), isFalse,
              reason: '${p.name} : $r ne fait que transiter');
        }
      }
    });

    test('un pôle non-terminal n\'expose aucune ligne terminus', () {
      for (final p in ref.poles.where((p) => !p.isTerminal)) {
        expect(p.dddRoutes, isEmpty, reason: p.name);
        expect(p.aftuRoutes, isEmpty, reason: p.name);
        expect(p.terminusStops, isEmpty, reason: p.name);
      }
    });

    test('chaque ligne terminus a un arrêt terminus réel rattaché', () {
      for (final p in ref.poles.where((p) => p.isTerminal)) {
        expect(p.terminusStops, isNotEmpty, reason: p.name);
        final Set<String> anchorRoutes = <String>{
          for (final s in p.terminusStops) ...s.routeIds,
        };
        for (final r in <String>[...p.dddRoutes, ...p.aftuRoutes]) {
          expect(anchorRoutes, contains(r), reason: '${p.name} / $r');
        }
      }
    });
  });

  // --------------------------------------------------------- TATA : prudence §9
  group('TATA — aucune association inventée', () {
    test('aucune association TATA confirmée par les feeds DDD/AFTU', () {
      final tata = ref.raw['tata'] as Map<String, dynamic>;
      expect(tata['vehicleType'], 'TATA');
      expect(tata['confirmedAssociations'], isEmpty);
      expect(tata['unconfirmedAssociations'], isEmpty);
    });
  });

  // ------------------------------------------------------------------- API modèle
  group('API du modèle', () {
    test('mappablePoles exclut les pôles rejetés et, par défaut, les non-terminaux',
        () {
      final mappable = catalog.mappablePoles();
      expect(mappable, isNotEmpty);
      expect(mappable.every((p) => p.isTerminal), isTrue);
      expect(
          mappable.any((p) => p.coordinatesStatus == PoleCoordinatesStatus.rejected),
          isFalse);
      expect(catalog.mappablePoles(terminalsOnly: false).length,
          greaterThanOrEqualTo(mappable.length));
    });

    test('chaque route du référentiel expose ses terminus et son statut', () {
      final routes = ref.raw['ddd']['routes'] as List<dynamic>;
      expect(routes, hasLength(53));
      for (final r in routes) {
        final m = r as Map<String, dynamic>;
        expect(m['routeId'], isA<String>());
        expect(m['status'], isA<String>());
        expect(m['directions'], isA<List<dynamic>>());
        expect(m['terminus'], isA<List<dynamic>>());
      }
      final aftuRoutes = ref.raw['aftu']['routes'] as List<dynamic>;
      expect(aftuRoutes, hasLength(73));
    });

    test('les pôles découverts hors périmètre sont inclus', () {
      final discovered = ref.poles.where((p) => p.discovered).toList();
      expect(discovered, isNotEmpty,
          reason: 'la liste §3–§5 n\'est pas limitative (§6)');
      expect(discovered.every((p) => p.isTerminal), isTrue);
    });
  });

  // ------------------------------------------------------------------ UI (§15)
  group('UI — affichage des pôles', () {
    testWidgets('la fiche d\'un pôle distingue terminus et transit',
        (WidgetTester tester) async {
      final colobane = ref.poleById('colobane')!;
      await tester.pumpWidget(MaterialApp(home: app.TerminusPolePage(pole: colobane)));
      await tester.pump();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.any((t) => t.contains('Terminus (départ / arrivée)')), isTrue,
          reason: 'section terminus attendue : $texts');
      expect(texts.any((t) => t.contains('Transit (ne terminent pas ici)')), isTrue,
          reason: 'section transit attendue : $texts');
    });

    testWidgets('la fiche d\'un pôle non-terminal n\'annonce aucun terminus',
        (WidgetTester tester) async {
      final mermoz = ref.poleById('mermoz')!;
      await tester.pumpWidget(MaterialApp(home: app.TerminusPolePage(pole: mermoz)));
      await tester.pump();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.any((t) => t.contains('Terminus (départ / arrivée)')), isFalse,
          reason: 'aucun terminus ne doit être annoncé : $texts');
      expect(texts.any((t) => t.contains('Transit (ne terminent pas ici)')), isTrue);
    });
  });
}
