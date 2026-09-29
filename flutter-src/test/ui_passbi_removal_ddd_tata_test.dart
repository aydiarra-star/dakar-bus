// CHANTIER UI — SUPPRESSION DE « PassBi » DE L'INTERFACE + IDENTIFICATION
// DDD / TATA + VERT HARICOT CLAIR.
//
// Ces tests portent sur la PRÉSENTATION uniquement. Le pipeline horaire
// (PassBi → route → trip → direction → arrêt → stop_times → DakarClock →
// calcul X min → DepartureInfo → Explorer) est STRICTEMENT inchangé : ces
// tests vérifient justement qu'il ne l'est pas (mêmes minutes, aucun « 0 min »,
// aucun « moins d'une minute », aucun horaire inventé, vrais stop_times
// prioritaires sur toute fréquence).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_display.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

/// Texte rendu par un widget, concaténé (pour la recherche de chaînes).
List<String> _renderedTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .toList();

/// Premier élément satisfaisant [test], ou `null`.
T? _firstOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final T item in items) {
    if (test(item)) return item;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue);
    app.integratePassBiNativeStopsForTest();
  });

  app.Stop dakarStop({
    required String name,
    required String stopId,
    required String routeId,
    required String modeLabel,
    required Color color,
  }) =>
      app.Stop(
        name: name,
        stopId: stopId,
        scheduleRouteId: routeId,
        direction: 'Dir. test',
        distanceMeters: 100,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_bus,
        color: color,
        location: const LatLng(14.7, -17.4),
        modeLabel: modeLabel,
      );

  // ==================================================================
  // 1. Aucune chaîne « PassBi » visible dans les composants utilisateur
  // ==================================================================
  group('1 — « PassBi » n\'est plus visible dans l\'interface', () {
    test('stripPassBiFromLabel retire toutes les formulations connues', () {
      expect(app.stripPassBiFromLabel('Ligne PassBi AFTU_49'), 'AFTU_49');
      expect(app.stripPassBiFromLabel('Ligne PassBi DDD_217 · D217OT'),
          'DDD_217 · D217OT');
      expect(app.stripPassBiFromLabel('PassBi DDD_217'), 'DDD_217');
      expect(app.stripPassBiFromLabel('3 lignes PassBi DDD'), 'DDD');
      expect(app.stripPassBiFromLabel('1 ligne PassBi AFTU'), 'AFTU');
      // Un libellé sans « PassBi » est renvoyé à l'identique.
      expect(app.stripPassBiFromLabel('DDD 1'), 'DDD 1');
      expect(app.stripPassBiFromLabel('BRT B1'), 'BRT B1');
      for (final String s in <String>[
        'Ligne PassBi AFTU_49',
        'Ligne PassBi DDD_217 · D217OT',
        '3 lignes PassBi DDD',
      ]) {
        expect(app.stripPassBiFromLabel(s).contains('PassBi'), isFalse,
            reason: s);
      }
    });

    test('le libellé de source affiché ne nomme plus la source de données', () {
      expect(app.DataSourceInfo.passbiGtfs.label.contains('PassBi'), isFalse);
    });

    test('un arrêt natif DDD ne porte plus « PassBi » dans son libellé', () {
      final app.Stop? natif = _firstOrNull(
          app.passBiNativeStops, (app.Stop s) => s.modeLabel == 'DDD');
      expect(natif, isNotNull);
      expect(natif!.direction.contains('PassBi'), isFalse);
      expect(natif.direction, contains('DDD'));
    });

    testWidgets('StopCard d\'un arrêt natif DDD n\'affiche aucun « PassBi »',
        (WidgetTester tester) async {
      final app.Stop? cible = _firstOrNull(
          app.passBiNativeStops, (app.Stop s) => s.modeLabel == 'DDD');
      expect(cible, isNotNull);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: cible!, distanceMeters: 250)),
      ));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('PassBi')), isFalse,
          reason: 'aucune chaîne PassBi visible : $texts');
    });

    testWidgets('SingleStopView d\'un arrêt natif ne montre aucun « PassBi »',
        (WidgetTester tester) async {
      final app.Stop? cible = _firstOrNull(
          app.passBiNativeStops, (app.Stop s) => s.modeLabel == 'DDD');
      expect(cible, isNotNull);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: app.SingleStopView(stop: cible!))));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('PassBi')), isFalse,
          reason: 'aucune chaîne PassBi visible : $texts');
    });

    test('le libellé de tronçon rendu par Trajets ne montre aucun « PassBi »',
        () {
      // La carte de trajet rend `stripPassBiFromLabel(segment.modeLabel)`.
      const app.RouteSegment segment = app.RouteSegment(
        modeLabel: 'PassBi DDD_217',
        color: Color(0xFF3B82F6),
        icon: Icons.directions_bus,
        from: 'Colobane',
        to: 'Diamniadio',
        durationMinutes: 12,
      );
      final String rendered = app.stripPassBiFromLabel(segment.modeLabel);
      expect(rendered.contains('PassBi'), isFalse);
      expect(rendered, 'DDD_217');
    });
  });

  // ==================================================================
  // 2. Identification DDD claire
  // ==================================================================
  group('2 — DDD : identification claire dans Explorer', () {
    testWidgets('StopCard DDD natif : mode DDD + minutes, sans PassBi',
        (WidgetTester tester) async {
      // Un arrêt natif DDD dont le prochain passage est calculable.
      final app.Stop? cible = _firstOrNull(
          app.passBiNativeStops,
          (app.Stop s) =>
              s.modeLabel == 'DDD' &&
              s.departureInfoAt(at: lundi12).status == ScheduleStatus.scheduled);
      expect(cible, isNotNull, reason: 'un arrêt DDD calcule un départ');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: cible!, distanceMeters: 250)),
      ));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      // Le MODE DDD est identifiable (modeLabel de l'arrêt / badge).
      expect(texts.any((String t) => t.contains('DDD')), isTrue,
          reason: 'identité DDD attendue : $texts');
      expect(texts.any((String t) => t.contains('PassBi')), isFalse);
    });

    test('une ligne DDD documentée expose « DDD <numéro> » (jamais inventé)',
        () async {
      if (!app.appDataService.isLoaded) {
        await app.appDataService.loadNetworkData();
      }
      app.integrateNetworkDataForTest();
      final app.DetailedRoute? r = app.DetailedRoute.fromOperator('ddd');
      expect(r, isNotNull);
      expect(r!.lineNumberLabel, isNotNull);
      expect(r.routeLabel, startsWith('DDD '));
      expect(r.routeLabel, isNot(contains('PassBi')));
      // Le numéro affiché est celui de la source, jamais deviné.
      expect(r.routeLabel, 'DDD ${r.lineNumber}');
    });

    testWidgets('la fiche de ligne DDD affiche numéro, direction et arrêts',
        (WidgetTester tester) async {
      if (!app.appDataService.isLoaded) {
        await app.appDataService.loadNetworkData();
      }
      app.integrateNetworkDataForTest();
      final app.DetailedRoute r = app.DetailedRoute.fromOperator('ddd')!;
      await tester.pumpWidget(
          MaterialApp(home: app.DetailedRoutePage(route: r)));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      // Numéro de ligne visible.
      expect(texts.any((String t) => t.contains(r.routeLabel)), isTrue,
          reason: 'numéro de ligne DDD visible : $texts');
      // Direction/origine-destination visible.
      expect(texts.any((String t) => t.contains('➔')), isTrue,
          reason: 'direction visible : $texts');
      expect(texts.any((String t) => t.contains('PassBi')), isFalse);
    });
  });

  // ==================================================================
  // 3. Identification TATA claire
  // ==================================================================
  group('3 — TATA : identification claire dans Explorer', () {
    test('une ligne Tata documentée expose « Tata <numéro> »', () async {
      if (!app.appDataService.isLoaded) {
        await app.appDataService.loadNetworkData();
      }
      app.integrateNetworkDataForTest();
      final app.DetailedRoute? r = app.DetailedRoute.fromOperator('tata');
      expect(r, isNotNull);
      expect(r!.lineNumberLabel, isNotNull);
      expect(r.routeLabel, startsWith('Tata '));
      expect(r.routeLabel, 'Tata ${r.lineNumber}');
    });

    testWidgets('la fiche de ligne Tata affiche son numéro et sa direction',
        (WidgetTester tester) async {
      if (!app.appDataService.isLoaded) {
        await app.appDataService.loadNetworkData();
      }
      app.integrateNetworkDataForTest();
      final app.DetailedRoute r = app.DetailedRoute.fromOperator('tata')!;
      await tester.pumpWidget(
          MaterialApp(home: app.DetailedRoutePage(route: r)));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('Tata')), isTrue,
          reason: 'identité Tata visible : $texts');
      expect(texts.any((String t) => t.contains('➔')), isTrue);
    });

    testWidgets('un arrêt Tata affiché est identifiable comme Tata',
        (WidgetTester tester) async {
      final app.Stop? tata =
          _firstOrNull(app.allStops, (app.Stop s) => s.modeLabel == 'Tata');
      expect(tata, isNotNull, reason: 'le référentiel expose des arrêts Tata');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: tata!, distanceMeters: 300)),
      ));
      await tester.pump();
      final List<String> texts = _renderedTexts(tester);
      expect(texts.any((String t) => t.contains('Tata')), isTrue,
          reason: 'arrêt Tata identifiable : $texts');
      expect(texts.any((String t) => t.contains('PassBi')), isFalse);
    });

    test('aucune ligne TATA inventée : TATA reste absent des feeds', () {
      // TATA n\'est pas transformé en réseau fictif indépendant : aucun arrêt
      // natif TATA n\'existe, et aucune route de feed ne porte le réseau TATA.
      final Iterable<app.Stop> natifsTata = app.passBiNativeStops
          .where((app.Stop s) => s.modeLabel == 'TATA');
      expect(natifsTata, isEmpty,
          reason: 'aucun arrêt TATA natif : aucune ligne TATA inventée');
      // Les routes Tata affichées proviennent du référentiel dakar documenté.
      expect(app.appDataService.routes.any((r) => r.operatorId == 'tata'), isTrue);
    });
  });

  // ==================================================================
  // 4. Vert haricot clair homogène
  // ==================================================================
  group('4 — vert haricot clair', () {
    test('la teinte haricot clair est définie et distincte du vert de statut',
        () {
      expect(app.AppColors.beanGreen, isA<Color>());
      expect(app.AppColors.beanGreenLight, isA<Color>());
      // Le vert des départs (success) reste inchangé : aucune règle horaire
      // n'est touchée.
      expect(app.AppColors.success, const Color(0xFF00B140));
    });

    test('les boutons principaux et la navigation utilisent le vert haricot',
        () {
      final String code = File('lib/main.dart')
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      // Navigation principale : icônes sélectionnées en vert haricot.
      expect(code.contains('selectedIcon: Icon(Icons.explore, color: AppColors.beanGreen)'),
          isTrue);
      expect(code.contains('indicatorColor: AppColors.beanGreen'), isTrue);
      // Au moins un bouton principal (Assistant IA / Trajets / Signaler).
      expect(code.contains('backgroundColor: AppColors.beanGreen'), isTrue);
      // Le vert de statut des départs reste porté par success.
      expect(code.contains('AppColors.success'), isTrue);
    });
  });

  // ==================================================================
  // 5. Horaires : aucune régression (pipeline inchangé)
  // ==================================================================
  group('5 — horaires inchangés (aucune régression)', () {
    test('un vrai stop_time reste prioritaire et produit « X min » (jamais 0)',
        () {
      final app.Stop stop = dakarStop(
          name: 'Petersen',
          stopId: 'stop_brt_01_petersen',
          routeId: 'brt_b1_guediawaye_petersen',
          modeLabel: 'BRT',
          color: app.AppColors.brt);
      final DepartureInfo info = stop.departureInfoAt(
          at: DateTime.utc(2026, 9, 28, 14, 0));
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, isNotNull);
      expect(info.frequencyMinutes, isNull,
          reason: 'un vrai stop_time n\'est jamais une fréquence');
      expect(info.label, 'Prochain départ dans 1 min');
      expect(info.label.contains('moins'), isFalse);
      expect(RegExp(r'(^|[^0-9])0 min').hasMatch(info.label), isFalse);
    });

    test('les minutes calculées restent affichées (ceil, jamais 0)', () {
      expect(waitingMinutesBetween(
              DateTime.utc(2026, 9, 28, 14, 0, 30), DateTime.utc(2026, 9, 28, 14, 0)),
          1);
      expect(formatWaitingMinute(0), '1 mn');
      expect(formatWaitingMinute(-3), '1 mn');
      expect(formatWaitingMinutes(<int>[3, 10, 15]), '3 mn · 10 mn · 15 mn');
    });

    test('une estimation documentée reste « Passage estimé dans X min »', () {
      final DepartureInfo info = DepartureInfo.fromFrequency(
        const FrequencySource(
          operator: 'SunuBRT',
          routeId: 'brt_b1_guediawaye_petersen',
          routeLabel: 'B1',
          source: 'https://www.sunubrt.sn/',
          sourceType: SourceType.officialStatic,
          dateSource: null,
          dateVerified: '2026-09-26',
          validFrom: null,
          validTo: null,
          confidence: 0.98,
          status: ScheduleStatus.estimated,
          operatingHours: '06:00–21:00',
          frequencies: <FrequencyWindow>[
            FrequencyWindow(
              weekdays: kMondayToSaturday,
              startMinute: 6 * 60,
              endMinute: 21 * 60,
              frequencyMinutes: 6,
            ),
          ],
        ),
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 6 * 60,
          endMinute: 21 * 60,
          frequencyMinutes: 6,
        ),
        DateTime.utc(2026, 9, 28, 10, 0),
      );
      expect(info.label, 'Passage estimé dans 6 min');
      expect(info.label, isNot(contains('Prochain départ')));
    });

    test('sans donnée réelle : « Horaire indisponible », aucun horaire inventé',
        () {
      final app.Stop stop = dakarStop(
          name: 'Colobane',
          stopId: 'stop_colobane',
          routeId: 'ddd_1',
          modeLabel: 'DDD',
          color: app.AppColors.ddd);
      final DepartureInfo info = stop.departureInfoAt(at: lundi12);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.scheduledTime, isNull);
      expect(info.frequencyMinutes, isNull);
    });

    test('le libellé d\'identité interne ne fuit jamais un horaire', () {
      // La présentation ne touche pas aux statuts : un libellé nettoyé reste un
      // libellé, jamais un horaire.
      final String label = ScheduleProvider.identityLabelFor(
          'DDD', 'DDD_217', IdentityStatus.unconfirmed,
          shortName: 'D217OT');
      expect(label, isNot(contains('min')));
      expect(label, isNot(contains('PassBi')));
    });
  });
}
