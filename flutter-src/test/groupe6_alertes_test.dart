// GROUPE 6 — garde-fous des trois corrections factuelles minimales.
//
// Rapport d'audit : `docs/dakar-bus/groupe-6/RAPPORT_AUDIT.md`.
// Incohérences couvertes : E.2 (« Grand Yoff » cité sur le corridor BRT),
// E.3 (badge « En direct » sans flux live), E.4 (signalements à ancienneté
// figée présentés comme temps réel), E.5 (« usagistes »).
//
// Trois niveaux de vérification, alignés sur le reste de la suite :
//
//   1. DONNÉE — la base factuelle, lue dans `assets/data/dakar_network.json`
//      via `appDataService` (source unique). Aucune valeur n'est imposée de
//      l'extérieur : chaque attente provient du fichier.
//   2. RENDU  — le comportement réel. Les pages sont montées avec
//      `testWidgets` et l'on asserte le texte **effectivement affiché**, pas
//      une constante recopiée.
//   3. SOURCE — garde-fou anti-régression sur les littéraux, selon le modèle
//      « GARDE-FOU SOURCE » déjà employé par `gps_position_test.dart`.
//
// Chaque groupe contient aussi un test « rien n'a été supprimé » : la
// correction retire une affirmation fausse, jamais une donnée réelle.

import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Identifiant du corridor BRT B1 dans la source unique.
const String kBrtB1Id = 'brt_b1_guediawaye_petersen';

/// Nombre de stations officielles du corridor B1 (§7 — invariant conservé).
const int kBrtB1Stations = 23;

/// Mots présents dans les noms d'arrêt du JSON mais qui ne désignent pas un
/// lieu : « Grand Yoff - BRT & AFTU Hub », « Gare TER Dakar », …
const Set<String> kMotsGeneriques = <String>{
  'brt',
  'ter',
  'pem',
  'ddd',
  'aftu',
  'tata',
  'gare',
  'station',
  'hub',
  'marche',
  'terminus',
  'correspondance',
  'intermediaire',
  'arret',
};

/// Ramène à une forme comparable : minuscules, sans accents, seuls les
/// caractères alphanumériques et l'espace conservés.
String normalise(String s) {
  final String sansAccent = s.toLowerCase().replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll(RegExp('[ç]'), 'c');
  return sansAccent.replaceAll(RegExp('[^a-z0-9 ]'), ' ');
}

/// Mots distinctifs d'un nom d'arrêt : 4 caractères ou plus, hors vocabulaire
/// générique. Dérivés du JSON, jamais saisis à la main.
Set<String> motsDistinctifs(String nomArret) => normalise(nomArret)
    .split(' ')
    .where((String w) => w.length >= 4 && !kMotsGeneriques.contains(w))
    .toSet();

/// Une chaîne affirme-t-elle un flux live / temps réel ?
///
/// Volontairement étroite : « Direct rue » (nom de l'onglet, conservé) ne doit
/// PAS être reconnu comme une revendication de direct.
final RegExp kRevendiqueDirect =
    RegExp(r'(en\s+direct|temps\s+reel|\blive\b|flux\s+direct|instantane)');

bool revendiqueDirect(String s) => kRevendiqueDirect.hasMatch(normalise(s));

/// Une chaîne affirme-t-elle une ancienneté relative à l'instant présent ?
final RegExp kRevendiqueAnciennete = RegExp(
    r'(il\s+y\s+a\b|\b\d+\s*min\b|\b\d+\s*sec\b|\b\d+\s*h\b|a\s+l\s*instant|maintenant|ce\s+jour)');

bool revendiqueAnciennete(String s) =>
    kRevendiqueAnciennete.hasMatch(normalise(s));

/// Noms des stations du corridor B1, lus dans la source unique.
List<String> stationsB1() =>
    appDataService.stopsForRoute(kBrtB1Id).map((BusStop s) => s.name).toList();

/// Tous les textes effectivement rendus par l'arbre de widgets.
List<String> textesRendus(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s.isNotEmpty)
    .toList();

/// Monte la page dans une surface assez haute pour que `ListView` construise
/// toutes ses cartes (le montage par défaut de 800×600 pourrait en laisser
/// hors écran, et `ListView` est paresseux).
Future<void> montePage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!appDataService.isLoaded) {
      await appDataService.loadNetworkData();
    }
    expect(appDataService.isLoaded, isTrue);
    // Garde : sans lecture de l'asset, le repli codé en dur de `DataService`
    // donnerait un réseau réduit et fausserait tous les tests de ce fichier.
    expect(appDataService.stops.length, 117,
        reason: 'la DONNÉE ACTIVE doit être chargée, pas le repli en dur');
    expect(appDataService.routes.length, 105);
  });

  // ==================================================================
  // CORRECTION 1 (E.2) — l'alerte BRT ne présente pas « Grand Yoff »
  // comme une station officielle du corridor B1.
  // ==================================================================
  group('Groupe 6 — Correction 1 : « Grand Yoff » hors du corridor B1', () {
    test('DONNÉE : la source unique ne place aucune station « Grand Yoff » sur le B1', () {
      final List<String> noms = stationsB1();

      expect(noms, hasLength(kBrtB1Stations),
          reason: '§7 — le corridor B1 compte 23 stations, invariant conservé');
      expect(
          noms.where((String n) => normalise(n).contains('grand yoff')),
          isEmpty,
          reason:
              'aucune des 23 stations officielles du B1 ne porte le nom « Grand Yoff »');
    });

    test('DONNÉE : « Grand Yoff » reste un arrêt réel du JSON, desservi hors BRT', () {
      // La correction retire une AFFIRMATION FAUSSE, pas une donnée : l'arrêt
      // doit continuer d'exister dans la source unique et d'être desservi.
      final List<BusStop> arrets = appDataService.stops
          .where((BusStop s) => normalise(s.name).contains('grand yoff'))
          .toList();

      expect(arrets, isNotEmpty,
          reason: '« Grand Yoff » existe bien comme arrêt dans le JSON');

      for (final BusStop arret in arrets) {
        final List<TransportRoute> lignes = appDataService.routes
            .where((TransportRoute r) => r.stopIds.contains(arret.id))
            .toList();

        expect(lignes, isNotEmpty,
            reason: '${arret.id} doit rester desservi par au moins une ligne');
        expect(
            lignes.where((TransportRoute r) => r.operatorId == 'brt'),
            isEmpty,
            reason:
                '${arret.id} (${arret.name}) n\'est sur AUCUNE ligne BRT : le citer '
                'sur le corridor B1 contredit la source unique');
      }
    });

    testWidgets('RENDU : l\'alerte BRT affichée ne cite pas « Grand Yoff »', (WidgetTester tester) async {
      await montePage(tester, const AlertsPage());

      final Finder message = find.textContaining('Le corridor relie');
      expect(message, findsOneWidget,
          reason: 'la carte d\'alerte BRT doit être rendue');

      final String texte = tester.widget<Text>(message).data!;
      expect(normalise(texte).contains('grand yoff'), isFalse,
          reason: 'E.2 — « Grand Yoff » n\'est pas une station du corridor B1');
    });

    testWidgets('RENDU : chaque lieu cité par l\'alerte BRT est une station du corridor B1',
        (WidgetTester tester) async {
      await montePage(tester, const AlertsPage());

      final String texte =
          tester.widget<Text>(find.textContaining('Le corridor relie')).data!;
      final Set<String> cites = normalise(texte).split(' ').toSet();

      // Vocabulaire de liaison de la phrase, et non des lieux.
      const Set<String> liaison = <String>{
        'corridor', 'relie', 'passant',
      };

      // Ensemble des mots distinctifs portés par les stations officielles du
      // B1 : tout lieu cité doit s'y retrouver. Construit par compréhension,
      // sans collection mutable locale.
      final Set<String> motsB1 = <String>{
        for (final String nom in stationsB1()) ...motsDistinctifs(nom)
      };

      // On parcourt les mots distinctifs de TOUS les arrêts du JSON : si l'un
      // d'eux apparaît dans le message, il faut qu'une station du B1 le porte
      // aussi. Les mots sont dérivés du fichier, aucun n'est saisi à la main.
      final List<String> nonCorrobores = <String>[
        for (final BusStop arret in appDataService.stops)
          for (final String mot in motsDistinctifs(arret.name))
            if (!liaison.contains(mot) &&
                cites.contains(mot) &&
                !motsB1.contains(mot))
              '$mot (cité dans l\'alerte, présent sur ${arret.id} '
                  '« ${arret.name} », absent des 23 stations du B1)'
      ];

      expect(nonCorrobores, isEmpty,
          reason: 'E.2 — l\'alerte BRT ne doit nommer que des stations '
              'réellement situées sur le corridor officiel B1');

      // Contre-partie : la correction ne vide pas la carte. Les lieux
      // confirmés par la source unique restent cités.
      for (final String attendu in <String>[
        'guediawaye',
        'petersen',
        'dalal',
        'jamm',
        'parcelles',
        'assainies',
        'obelisque'
      ]) {
        expect(cites, contains(attendu),
            reason: '$attendu est une station du B1 : elle doit rester citée');
      }
    });

    test('SOURCE : le littéral « Grand Yoff » a disparu de la page Alertes', () {
      final String code = _stripComments(File('lib/main.dart').readAsStringSync());

      final int debut = code.indexOf('class AlertsPage');
      final int fin = code.indexOf('class CommunityAlertsPage');
      expect(debut, greaterThanOrEqualTo(0));
      expect(fin, greaterThan(debut),
          reason: 'la page Alertes doit rester bornée par ces deux classes');

      final String blocAlertes = code.substring(debut, fin);
      expect(blocAlertes.contains('Grand Yoff'), isFalse,
          reason: 'E.2 — aucune carte d\'alerte ne doit citer « Grand Yoff » '
              'comme station du corridor BRT');

      // Hors périmètre vérifié : « Grand Yoff » reste présent AILLEURS dans
      // l'application (point de démonstration Explorer, assistant). Rien n'y
      // a été retiré.
      expect(code.contains('Grand Yoff'), isTrue,
          reason: 'l\'arrêt « Grand Yoff » reste référencé hors AlertsPage : '
              'aucune donnée n\'a été supprimée');
    });
  });

  // ==================================================================
  // CORRECTION 2 (E.3) — aucun statut LIVE / REAL_TIME sans donnée.
  // ==================================================================
  group('Groupe 6 — Correction 2 : aucun statut live sans donnée', () {
    testWidgets('RENDU : aucune carte d\'alerte n\'affirme un direct ou un temps réel',
        (WidgetTester tester) async {
      await montePage(tester, const AlertsPage());

      final List<String> textes = textesRendus(tester);
      expect(textes, isNotEmpty);

      final List<String> live =
          textes.where((String t) => revendiqueDirect(t)).toList();
      expect(live, isEmpty,
          reason: 'E.3 / §18 — `DataStatus.live` n\'est jamais assigné dans '
              'lib/ et aucun flux temps réel n\'existe : aucune carte ne peut '
              'affirmer un direct. Textes fautifs : $live');
    });

    testWidgets('RENDU + DONNÉE : le badge BRT s\'appuie sur le data_trust réel de la ligne',
        (WidgetTester tester) async {
      // 1. La donnée : le corridor B1 porte bien un statut OFFICIAL dans la
      //    source unique. C'est le seul statut réel disponible pour cette
      //    alerte — d'où le libellé retenu.
      final TransportRoute b1 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == kBrtB1Id);
      expect(b1.dataTrust, DataTrust.official,
          reason: 'le badge doit refléter un attribut présent dans le JSON');
      expect(b1.dataTrust.toLabel(), 'OFFICIAL');

      // 2. Le rendu : le badge affiché reprend ce qualificatif et n'affirme
      //    aucun direct.
      await montePage(tester, const AlertsPage());

      final List<String> textes = textesRendus(tester);
      final List<String> officiels = textes
          .where((String t) => normalise(t).contains('officiell'))
          .toList();
      expect(officiels, isNotEmpty,
          reason: 'le statut officiel, lui, est justifié par la donnée');
      for (final String t in officiels) {
        expect(revendiqueDirect(t), isFalse, reason: 'texte fautif : $t');
      }

      // 3. Le badge fautif a bien disparu du rendu.
      expect(textes.where((String t) => normalise(t) == 'en direct'), isEmpty,
          reason: 'E.3 — le badge « En direct » ne doit plus être rendu');
    });

    test('SOURCE : aucun des trois badges de la page Alertes ne revendique un direct', () {
      final String code = _stripComments(File('lib/main.dart').readAsStringSync());

      final int debut = code.indexOf('class AlertsPage');
      final int fin = code.indexOf('class CommunityAlertsPage');
      final String blocAlertes = code.substring(debut, fin);

      final List<String> badges = RegExp(r"'badge':\s*'([^']*)'")
          .allMatches(blocAlertes)
          .map((Match m) => m.group(1)!)
          .toList();

      expect(badges, hasLength(3),
          reason: 'les trois cartes d\'alerte officielles sont conservées');
      for (final String badge in badges) {
        expect(revendiqueDirect(badge), isFalse,
            reason: 'E.3 / §18 — badge fautif : « $badge »');
        expect(revendiqueAnciennete(badge), isFalse,
            reason: 'E.3 — aucun horodatage fictif dans un badge : « $badge »');
      }
    });
  });

  // ==================================================================
  // CORRECTION 3 (E.4 / E.5) — les signalements ne sont pas présentés
  // comme des événements live.
  // ==================================================================
  group('Groupe 6 — Correction 3 : signalements non présentés comme live', () {
    // PÉRIMÈTRE — un cas voisin est volontairement LAISSÉ TEL QUEL :
    // `_showAddReportModal` insère un signalement avec `'time': 'À l'instant'`.
    // Contrairement aux deux chaînes figées corrigées ici, celle-ci est produite
    // par une action RÉELLE de l'utilisateur, au moment où elle a lieu : à
    // l'instant de l'insertion, elle est exacte. La rendre non temporelle
    // exigerait de générer un horodatage (`DateTime.now()`), ce que la consigne
    // du Groupe 6 interdit explicitement (« Ne génère pas de nouvelles
    // dates/heures »). Elle est donc documentée ici et portée au rapport final,
    // et non modifiée. Les tests de ce groupe assertent le rendu INITIAL de la
    // page, qui ne contient plus aucune ancienneté figée.
    testWidgets('RENDU : aucun signalement n\'affiche une ancienneté figée', (WidgetTester tester) async {
      await montePage(tester, const CommunityAlertsPage());

      final List<String> textes = textesRendus(tester);
      expect(textes, isNotEmpty);

      final List<String> fautifs =
          textes.where((String t) => revendiqueAnciennete(t)).toList();
      expect(fautifs, isEmpty,
          reason: 'E.4 / §20 — « Il y a 3 min » était une chaîne figée : elle '
              'affirmait une ancienneté relative à l\'instant présent alors '
              'qu\'aucun horodatage n\'existe. Textes fautifs : $fautifs');
    });

    testWidgets('RENDU : l\'en-tête n\'affirme plus de temps réel', (WidgetTester tester) async {
      await montePage(tester, const CommunityAlertsPage());

      final List<String> textes = textesRendus(tester);
      final List<String> live =
          textes.where((String t) => revendiqueDirect(t)).toList();
      expect(live, isEmpty,
          reason: 'E.4 — « Signalements en temps réel… » affirmait un flux '
              'live inexistant. Textes fautifs : $live');

      // Le nom de l'onglet, lui, est conservé : « Direct rue & Communauté »
      // est une appellation de fonctionnalité, pas une revendication de flux.
      expect(textes, contains('Direct rue & Communauté'),
          reason: 'la fonctionnalité et son intitulé sont conservés');
    });

    testWidgets('RENDU : la fonctionnalité est conservée, sans horodatage inventé',
        (WidgetTester tester) async {
      await montePage(tester, const CommunityAlertsPage());

      final List<String> textes = textesRendus(tester);

      // Les deux signalements existants sont toujours là : rien n'a été
      // supprimé, aucun nouveau signalement n'a été créé.
      for (final String attendu in <String>[
        'Mamadou S.',
        'Aïssatou N.',
        '📍 Parcelles Assainies (BRT) — Trafic fluide',
        '📍 Gare de Dakar (TER) — Embarquement régulier',
      ]) {
        expect(textes, contains(attendu),
            reason: 'le signalement « $attendu » doit rester affiché');
      }
      expect(textes.where((String t) => t.startsWith('📍')), hasLength(2),
          reason: 'ni plus ni moins que les deux signalements existants');

      // Le bouton de signalement reste actif : la fonctionnalité de publication
      // n'est pas retirée par la correction.
      final Finder bouton = find.widgetWithText(ElevatedButton, 'Signaler');
      expect(bouton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(bouton).onPressed, isNotNull,
          reason: 'la publication d\'un signalement doit rester possible');

      // Chaque signalement porte un horodatage explicitement non temporel, et
      // aucune date ni heure n'a été générée à la place.
      final List<String> horodatages = textes
          .where((String t) => normalise(t).contains('horodatage'))
          .toList();
      expect(horodatages, hasLength(2),
          reason: 'les deux signalements affichent un horodatage non temporel');
      for (final String h in horodatages) {
        expect(RegExp(r'\d').hasMatch(h), isFalse,
            reason: 'E.4 — aucune date ni heure ne doit être inventée : « $h »');
      }
    });

    test('SOURCE : plus aucune ancienneté figée ni « usagistes » dans main.dart', () {
      final String code = _stripComments(File('lib/main.dart').readAsStringSync());

      expect(RegExp(r"'time':\s*'Il y a").hasMatch(code), isFalse,
          reason: 'E.4 — aucune chaîne figée « Il y a … » comme horodatage');
      expect(code.contains('usagistes'), isFalse,
          reason: 'E.5 — seule « usagers » est attesté (binaire de production)');
      expect(code.contains('Signalements en temps réel'), isFalse,
          reason: 'E.4 — l\'en-tête ne doit plus affirmer de temps réel');

      // La page et sa liste de signalements existent toujours : la
      // fonctionnalité n'a pas été retirée pour faire passer le test.
      expect(code.contains('class CommunityAlertsPage extends StatefulWidget'),
          isTrue);
      expect(code.contains('_communityReports'), isTrue);
      expect(code.contains('_showAddReportModal'), isTrue);
    });
  });
}

// ====================================================================
// GARDE-FOU SOURCE — utilitaire partagé
// ====================================================================
// Reproduction à l'identique de `_stripComments` (test/gps_position_test.dart,
// L88-157) : retire les commentaires `//` et `/* */` tout en préservant le
// contenu des chaînes littérales et des interpolations `${…}`, afin que les
// garde-fous portent sur le code et non sur la documentation.
String _stripComments(String src) {
  final out = StringBuffer();
  int i = 0;
  final n = src.length;
  String? quote; // guillemet ouvrant de la chaîne en cours, null hors chaîne
  int interp = 0; // profondeur d'accolades dans une interpolation `${...}`
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';

    if (quote == null) {
      // Hors chaîne : les commentaires sont retirés, le reste recopié.
      if (c == '/' && next == '/') {
        while (i < n && src[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '*') {
        i += 2;
        while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') quote = c;
      out.write(c);
      i++;
      continue;
    }

    // Dans une chaîne : tout est recopié tel quel.
    if (c == '\\' && i + 1 < n) {
      out.write(c);
      out.write(src[i + 1]);
      i += 2;
      continue;
    }
    if (c == '\n') {
      // Une chaîne simple ne peut pas contenir de saut de ligne brut.
      quote = null;
      interp = 0;
      out.write(c);
      i++;
      continue;
    }
    if (interp == 0 && c == '\$' && next == '{') {
      interp = 1;
      out.write(c);
      out.write(next);
      i += 2;
      continue;
    }
    if (interp > 0) {
      if (c == '{') {
        interp++;
      } else if (c == '}') {
        interp--;
      }
      out.write(c);
      i++;
      continue;
    }
    if (c == quote) quote = null;
    out.write(c);
    i++;
  }
  return out.toString();
}
