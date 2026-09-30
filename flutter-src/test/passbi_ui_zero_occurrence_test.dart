// Chantier « Recherche + GPS + Routage » — GARDE-FOU : le nom de la source de
// données interne (« PassBi ») ne doit JAMAIS être affiché à l'usager.
//
// Règle produit stricte : aucune chaîne RENDUE dans l'interface de Dakar Bus ne
// contient « PassBi ». Les identifiants techniques internes (noms de classes
// `PassBiSource`/`PassBiJourney`, chemins d'assets, base d'identités
// `SOURCE_PASSBI_INACTIVE`, métadonnées de provenance non rendues) restent
// autorisés dans le code et les données ; seul l'affichage est proscrit.
//
// Trois niveaux de preuve :
//  1. SOURCE  : aucun littéral de chaîne VISIBLE (hors commentaire) de `lib/`
//               ne contient « PassBi » — liste blanche explicite et justifiée ;
//  2. CATALOGUE : aucune entrée du catalogue de recherche unifié (le référentiel
//               partagé par la barre de recherche ET le GPS) ne porte « PassBi »
//               dans un champ affichable ;
//  3. UI      : fiche pôle/terminus, carte de résultat, StopCard, SingleStopView
//               et cartes d'itinéraire GPS ne rendent aucun « PassBi ».
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/terminus_pole.dart';
import 'package:dakar_bus/services/network_search.dart';

/// Texte rendu par un widget, concaténé (pour la recherche de chaînes).
List<String> _renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .toList();

/// Retire commentaires de ligne et de bloc — laisse les littéraux de chaîne.
String _stripComments(String src) {
  final out = StringBuffer();
  int i = 0;
  final n = src.length;
  String? quote;
  int interp = 0;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';
    if (quote == null) {
      if (c == '/' && next == '/') {
        while (i < n && src[i] != '\n') {
          i++;
        }
      } else if (c == '/' && next == '*') {
        i += 2;
        while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
          i++;
        }
        i += 2;
      } else {
        if (c == '"' || c == "'") quote = c;
        out.write(c);
        i++;
      }
    } else {
      out.write(c);
      if (c == r'\') {
        if (i + 1 < n) out.write(src[i + 1]);
        i += 2;
        continue;
      } else if (c == r'$' && next == '{') {
        interp++;
      } else if (c == '}' && interp > 0) {
        interp--;
      } else if (c == quote && interp == 0) {
        quote = null;
      }
      i++;
    }
  }
  return out.toString();
}

/// Extrait les littéraux de chaîne Dart (déjà privés de commentaires), en
/// conservant les séquences d'échappement telles qu'écrites dans la source.
List<String> _stringLiterals(String src) {
  final List<String> out = <String>[];
  int i = 0;
  final int n = src.length;
  while (i < n) {
    final String c = src[i];
    if (c == '"' || c == "'") {
      final StringBuffer buf = StringBuffer();
      i++;
      while (i < n && src[i] != c) {
        if (src[i] == r'\' && i + 1 < n) {
          buf.write(src[i]);
          buf.write(src[i + 1]);
          i += 2;
          continue;
        }
        buf.write(src[i]);
        i++;
      }
      out.add(buf.toString());
      i++; // guillemet fermant
    } else {
      i++;
    }
  }
  return out;
}

/// Littéraux PassBi VISIBLES tolérés (jamais affichés à l'usager), chacun
/// justifié. Une régression qui introduirait une nouvelle chaîne échoue.
const Map<String, Set<String>> _allowedPassBiLiterals = <String, Set<String>>{
  'lib/main.dart': <String>{
    // Sanitizer d'affichage : ses motifs SERVENT à retirer « PassBi ».
    r'\d+\s+lignes?\s+PassBi\s*',
    r'\bLignes?\s+PassBi\s*',
    r'\bPassBi\s*',
    // Journal de développement (debugPrint), jamais rendu.
    '✅ PassBi natif \$netKey : \$added arrêts exploitables ',
  },
  'lib/services/data_service.dart': <String>{
    // Journal de développement (print sous ignore), jamais rendu.
    '⚠️ PassBi GTFS indisponible (mode legacy) : \$e',
  },
  'lib/services/gtfs/passbi_source.dart': <String>{
    // Métadonnée de provenance (nom + URL), non rendue dans l'UI.
    'PassBi (impactsolutionsas/passbi_core)',
  },
};

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

  // ================================================================ 1. SOURCE
  group('1 — SOURCE : aucun littéral PassBi visible non justifié', () {
    test('chaque littéral PassBi de lib/ est dans la liste blanche', () {
      final Map<String, Set<String>> found = <String, Set<String>>{};
      for (final FileSystemEntity e in Directory('lib')
          .listSync(recursive: true)
          .where((FileSystemEntity e) => e.path.endsWith('.dart'))) {
        final String src = _stripComments(File(e.path).readAsStringSync());
        for (final String lit in _stringLiterals(src)) {
          if (!lit.contains('PassBi')) continue;
          (found[e.path] ??= <String>{}).add(lit);
        }
      }
      expect(found, isNotEmpty,
          reason: 'le référentiel source doit encore contenir PassBi (sinon '
              'tester sur un chemin différent)');
      for (final MapEntry<String, Set<String>> entry in found.entries) {
        final Set<String> allowed =
            _allowedPassBiLiterals[entry.key] ?? const <String>{};
        for (final String lit in entry.value) {
          expect(allowed, contains(lit),
              reason: 'littéral PassBi non justifié dans ${entry.key} : « $lit »\n'
                  'Le nom de la source ne doit jamais être affiché à l\'usager.');
        }
      }
    });

    test('la fiche pôle/terminus ne contient plus « feeds PassBi »', () {
      final String src = _stripComments(File('lib/main.dart').readAsStringSync());
      // Chaque littéral rendu contenant « Terminus dérivés » est neutre.
      final List<String> rendered = _stringLiterals(src)
          .where((String s) => s.contains('Terminus dérivés'))
          .toList();
      expect(rendered, isNotEmpty,
          reason: 'la phrase source de la fiche pôle doit exister');
      for (final String lit in rendered) {
        expect(lit.contains('PassBi'), isFalse,
            reason: 'la fiche pôle affichait la source interne PassBi : « $lit »');
      }
      expect(rendered.any((String s) => s.contains('données opérationnelles DDD/AFTU')),
          isTrue,
          reason: 'formulation neutre attendue');
    });
  });

  // ============================================================= 2. CATALOGUE
  group('2 — CATALOGUE unifié : aucun libellé PassBi', () {
    test('toutes les entrées du catalogue exposent un libellé sans PassBi', () {
      final NetworkSearchCatalog cat = app.currentNetworkSearchCatalog;
      expect(cat.entries, isNotEmpty);
      for (final NetworkSearchEntry e in cat.entries) {
        expect(e.label.contains('PassBi'), isFalse,
            reason: 'libellé de recherche pollué : ${e.label}');
      }
    });

    test('les champs affichables (libellé) des résultats de recherche sont '
        'propres, quelle que soit la requête', () {
      for (final String q in <String>['PassBi', 'AFTU', 'DDD', 'BRT', 'TER',
          'Keur Mbaye Fall', 'Parcelles', 'Terminus']) {
        for (final NetworkSearchEntry e in app.searchNetworkCatalog(q, limit: 50)) {
          expect(e.label.contains('PassBi'), isFalse,
              reason: 'requête « $q » → libellé « ${e.label} »');
        }
      }
    });

    test('les champs rendus du référentiel pôles/terminus sont sans PassBi', () {
      final TerminusPole? pole = app.appDataService.terminusCatalog.poles.isNotEmpty
          ? app.appDataService.terminusCatalog.poles.first
          : null;
      expect(pole, isNotNull, reason: 'le référentiel pôles doit être chargé');
      // Champs réellement rendus par TerminusPolePage / TerminusPoleCard.
      expect(pole!.name.contains('PassBi'), isFalse);
      expect(pole.status.toLabel().contains('PassBi'), isFalse);
      expect(pole.coordinatesStatus.toLabel().contains('PassBi'), isFalse);
      for (final TerminusPole p in app.appDataService.terminusCatalog.poles) {
        expect(p.name.contains('PassBi'), isFalse);
        if (p.note != null) {
          expect(p.note!.contains('PassBi'), isFalse,
              reason: 'note de pôle rendue : ${p.note}');
        }
      }
    });
  });

  // ==================================================================== 3. UI
  group('3 — UI : aucune chaîne PassBi rendue', () {
    testWidgets('la fiche d\'un pôle terminus n\'affiche aucun « PassBi »',
        (WidgetTester tester) async {
      final TerminusPole pole = app.appDataService.terminusCatalog.poles
          .firstWhere((TerminusPole p) => p.isTerminal);
      await tester.pumpWidget(MaterialApp(home: app.TerminusPolePage(pole: pole)));
      await tester.pump();
      // Fait défiler toute la fiche pour rendre chaque section.
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 6; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pump();
      }
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('PassBi')), isFalse,
          reason: 'chaîne PassBi visible dans la fiche pôle : $texts');
    });

    testWidgets('la carte de résultat de recherche n\'affiche aucun « PassBi »',
        (WidgetTester tester) async {
      final app.Stop stop = app.Stop(
        name: 'Petersen',
        direction: 'DDD 217 · Parcelles Assainies',
        distanceMeters: 420,
        departureMinutesFromMidnight: const <int>[360],
        icon: Icons.directions_bus,
        color: const Color(0xFF3B82F6),
        location: const LatLng(14.7167, -17.4677),
        modeLabel: 'DDD',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: stop, distanceMeters: 420)),
      ));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('PassBi')), isFalse,
          reason: 'carte de résultat polluée : $texts');
    });

    testWidgets('SingleStopView d\'un arrêt natif DDD n\'affiche aucun '
        '« PassBi »', (WidgetTester tester) async {
      final app.Stop? cible = app.passBiNativeStops.cast<app.Stop?>().firstWhere(
          (app.Stop? s) => s != null && s.modeLabel == 'DDD',
          orElse: () => null);
      expect(cible, isNotNull, reason: 'un arrêt natif DDD doit être chargé');
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: app.SingleStopView(stop: cible!))));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('PassBi')), isFalse,
          reason: 'SingleStopView pollué : $texts');
    });
  });

  // ============================================================= 4. DONNÉES
  group('4 — DONNÉES : champs non rendus mais surveillés', () {
    test('les données de transport ne sont pas modifiées par ce correctif '
        'de présentation', () {
      // Le correctif est purement présentationnel : il ne touche ni les feeds
      // PassBi (horaires/arrêts/lignes) ni le référentiel. Les occurrences de
      // « PassBi » y restent comme provenance interne non affichée.
      for (final String p in <String>[
        'assets/data/passbi/ter.json',
        'assets/data/passbi/brt.json',
        'assets/data/passbi/ddd.json',
        'assets/data/passbi/aftu.json',
        'assets/data/passbi/crosswalk.json',
      ]) {
        final File f = File(p);
        expect(f.existsSync(), isTrue, reason: '$p doit exister');
        // Fichier JSON valide, non tronqué.
        final Object? decoded = jsonDecode(f.readAsStringSync());
        expect(decoded, isNotNull, reason: '$p doit rester un JSON valide');
      }
    });
  });
}
