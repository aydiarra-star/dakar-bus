// BRANCHEMENT FLUTTER ↔ MOTEUR COMMUN DE DÉPARTS (2026-09-25).
//
// Vérifie que l'application Flutter consomme réellement le moteur validé :
//   Stop (stopId + lineId + modeLabel) → DepartureEngineService → DepartureEstimate → UI
//
// Non négociable :
//  * aucun horaire précis n'est inventé (une fréquence donne une FENÊTRE) ;
//  * aucun temps réel n'est simulé ;
//  * DDD / AFTU / TATA sans fréquence publiée restent UNKNOWN ;
//  * le référentiel audité (117 arrêts, 105 routes) n'est pas modifié.
//
// Aucun test ne dépend de l'heure réelle pour les valeurs : les instants sont
// explicites. Les deux tests de rendu comparent l'écran à la sortie du moteur
// calculée au même instant.
import 'dart:convert';
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_estimate.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/departure_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// « 11h40 », « 11:40 », « 11 h 40 » : une heure précise affichée.
final RegExp kHeurePrecise = RegExp(r'\b\d{1,2}\s?(:|h)\s?\d{2}\b');

/// « temps réel », « en direct », « live ».
final RegExp kTempsReel =
    RegExp(r'(temps\s+r[ée]el|en\s+direct|\blive\b)', caseSensitive: false);

DepartureRegistry _registreAudite() => DepartureEngineService.parseRegistry(
    File('assets/data/departure-frequencies.json').readAsStringSync());

/// Référentiel audité + un calendrier de jours fériés explicite (le vrai n'en
/// contient aucun : le moteur ne devine jamais un jour férié).
DepartureRegistry _registreAvecFerie(String date) {
  final Map<String, dynamic> json =
      jsonDecode(File('assets/data/departure-frequencies.json').readAsStringSync())
          as Map<String, dynamic>;
  (json['holidays'] as Map<String, dynamic>)['dates'] = <String>[date];
  return DepartureEngineService.parseRegistry(jsonEncode(json));
}

Stop _arret(String mode, {String? lineId, String? stopId}) => Stop(
      name: 'Arrêt de test $mode',
      direction: 'Dir. Test',
      distanceMeters: 300,
      departureMinutesFromMidnight: const <int>[],
      icon: Icons.circle,
      color: const Color(0xFF00B140),
      location: const LatLng(14.7167, -17.4677),
      modeLabel: mode,
      stopId: stopId,
      lineId: lineId,
    );

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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!appDataService.isLoaded) {
      await appDataService.loadNetworkData();
    }
    expect(appDataService.stops.length, 117,
        reason: 'la donnée active doit rester celle du JSON audité');
    expect(appDataService.routes.length, 105);
    final bool pret = await DepartureEngineService.ensureLoaded();
    expect(pret, isTrue, reason: 'le référentiel embarqué doit se charger');
    integrateNetworkDataForTest();
  });

  // ==================================================================
  // 1. Le moteur est bien celui du référentiel validé
  // ==================================================================
  group('1 — moteur partagé', () {
    test('référentiel chargé, validé, non pollué', () {
      final DepartureRegistry? reg = DepartureEngineService.registry;
      expect(reg, isNotNull);
      expect(DepartureEngineService.isReady, isTrue);
      expect(DepartureEngineService.validateFrequencyRegistry(reg!), isEmpty);
      expect(reg.frequencies, hasLength(5), reason: 'TER ×3, BRT B1, BRT B2');
      expect(reg.frequencies.every((DepartureFrequency f) => f.status == 'ACTIVE'), isTrue);
      expect(reg.holidays, isEmpty,
          reason: 'aucun calendrier de jours fériés n’est deviné');
      expect(appDataService.stops.length, 117);
      expect(appDataService.routes.length, 105);
    });

    test('le moteur Dart et le référentiel PWA restent identiques', () {
      expect(
        File('assets/data/departure-frequencies.json').readAsStringSync(),
        File('../data/transit/departure-frequencies.json').readAsStringSync(),
        reason: 'le référentiel des deux applications a divergé',
      );
    });

    test('libellé d’interface → réseau du référentiel', () {
      expect(DepartureEngineService.networkOfModeLabel('TER'), 'TER');
      expect(DepartureEngineService.networkOfModeLabel('BRT'), 'BRT');
      expect(DepartureEngineService.networkOfModeLabel('DDD'), 'DDD');
      expect(DepartureEngineService.networkOfModeLabel('AFTU'), 'AFTU');
      expect(DepartureEngineService.networkOfModeLabel('Tata'), 'TATA');
      expect(DepartureEngineService.networkOfModeLabel('Inconnu'), isNull);
      expect(DepartureEngineService.hasDocumentedFrequency('TER'), isTrue);
      expect(DepartureEngineService.hasDocumentedFrequency('BRT'), isTrue);
      expect(DepartureEngineService.hasDocumentedFrequency('DDD'), isFalse);
      expect(DepartureEngineService.hasDocumentedFrequency('AFTU'), isFalse);
      expect(DepartureEngineService.hasDocumentedFrequency('Tata'), isFalse);
    });
  });

  // ==================================================================
  // 2. Stop → moteur : la ligne vient de la donnée, jamais d’une déduction
  // ==================================================================
  group('2 — Stop → DepartureEstimate', () {
    test('les arrêts affichés portent la ligne du référentiel', () {
      final Stop ter = allStops.firstWhere((Stop s) => s.modeLabel == 'TER');
      final Stop brt = allStops.firstWhere((Stop s) => s.modeLabel == 'BRT');
      expect(ter.lineId, 'ter_dakar_diamniadio');
      expect(brt.lineId, isNotNull);
      expect(brt.lineId!.startsWith('brt_'), isTrue);
      expect(ter.stopId, isNotNull);
      // Aucun horaire fabriqué : le champ local reste vide partout.
      expect(allStops.every((Stop s) => s.departureMinutesFromMidnight.isEmpty), isTrue);
      expect(allStops.every((Stop s) => s.scheduleStatus == ScheduleStatus.unknown), isTrue);
    });

    test('gare TER : estimation du moteur (jamais un horaire inventé)', () {
      final Stop ter = allStops.firstWhere((Stop s) => s.modeLabel == 'TER');
      final DepartureEstimate e =
          ter.departureEstimate(now: DateTime(2026, 9, 28, 11, 43));
      expect(e.lineId, 'ter_dakar_diamniadio');
      expect(e.status, ScheduleStatus.estimated);
      expect(e.scheduledTime, isNull, reason: 'aucun horaire précis en donnée');
      expect(e.observedAt, isNull, reason: 'aucun flux temps réel');
      expect(e.frequencyMinutes, 10);
      expect(DepartureEngineService.validateEstimate(e), isEmpty);
      final DepartureDisplay d = DepartureEngineService.displayFor(
          e, now: DateTime(2026, 9, 28, 11, 43));
      expect(d.badge, 'Estimation');
      expect(d.headline, contains('0–10 min'));
      expect(d.detail, contains('SETER'), reason: 'la source est affichée');
      expect(d.available, isTrue);
    });

    test('arrêt DDD / AFTU / Tata : UNKNOWN, sans fréquence inventée', () {
      for (final String mode in <String>['DDD', 'AFTU', 'Tata']) {
        final DepartureEstimate e =
            _arret(mode).departureEstimate(now: DateTime(2026, 9, 28, 11, 43));
        expect(e.status, ScheduleStatus.unknown, reason: mode);
        expect(e.reason, 'NO_FREQUENCY_FOR_LINE', reason: mode);
        expect(e.estimatedFrom, isNull);
        expect(e.estimatedTo, isNull);
        expect(e.frequencyMinutes, isNull);
        final DepartureDisplay d = DepartureEngineService.displayFor(e);
        expect(d.body, 'Horaire indisponible', reason: mode);
        expect(d.isEstimate, isFalse, reason: mode);
        expect(d.isRealTime, isFalse, reason: mode);
      }
    });

    test('arrêt hors référentiel : la fréquence de ligne ne remplace rien', () {
      final DepartureEstimate sansLigne = _arret('DDD', stopId: 'stop_inconnu')
          .departureEstimate(now: DateTime(2026, 9, 28, 11, 43));
      expect(sansLigne.status, ScheduleStatus.unknown);
      final DepartureEstimate terSansLigne = _arret('TER', stopId: 'stop_inconnu')
          .departureEstimate(now: DateTime(2026, 9, 28, 11, 43));
      expect(terSansLigne.status, ScheduleStatus.estimated,
          reason: 'la fréquence TER est documentée au niveau de la ligne');
      expect(terSansLigne.frequencyId, contains('ter_dakar_diamniadio'));
    });

    test('les arrêts orphelins (hors ligne) restent UNKNOWN', () {
      for (final Stop s in allStops) {
        if (s.lineId != null) continue;
        expect(s.departureEstimate(now: DateTime(2026, 9, 28, 11, 43)).status,
            ScheduleStatus.unknown,
            reason: s.name);
      }
    });
  });

  // ==================================================================
  // 3. Matrice horaire demandée (§16) — instants explicites
  // ==================================================================
  group('3 — TER : matrice horaire', () {
    DepartureEstimate ter(DateTime now) => DepartureEngineService.estimateForLine(
        modeLabel: 'TER', now: now);

    test('lundi 2026-09-28 : 10 min en journée, 20 min après 21h, arrêt à 22h', () {
      final Map<String, String> attendus = <String, String>{
        '05:30': '05:30→05:40', // ouverture documentée
        '10:00': '10:00→10:10',
        '20:59': '20:59→21:00', // la fenêtre ne dépasse pas la fin de période
        '21:00': '21:00→21:20', // bascule 10 min → 20 min
        '21:30': '21:30→21:50',
      };
      attendus.forEach((String heure, String fenetre) {
        final DateTime now = DateTime(2026, 9, 28, int.parse(heure.substring(0, 2)),
            int.parse(heure.substring(3)));
        final DepartureEstimate e = ter(now);
        expect(e.status, ScheduleStatus.estimated, reason: heure);
        expect(e.frequencyMinutes, heure.compareTo('21:00') < 0 ? 10 : 20, reason: heure);
        expect(
            '${DepartureEngineService.clockOfIso(e.estimatedFrom)}→'
            '${DepartureEngineService.clockOfIso(e.estimatedTo)}',
            fenetre,
            reason: heure);
      });
    });

    test('lundi 2026-09-28 : 05:29 (avant service) et 22:00 / 22:01 (terminé)', () {
      final DepartureEstimate tot = ter(DateTime(2026, 9, 28, 5, 29));
      expect(tot.status, ScheduleStatus.estimated);
      expect(tot.relative, 'BEFORE_SERVICE');
      expect(DepartureEngineService.clockOfIso(tot.estimatedFrom), '05:30');

      for (final DateTime fin in <DateTime>[
        DateTime(2026, 9, 28, 22, 0),
        DateTime(2026, 9, 28, 22, 1),
      ]) {
        final DepartureEstimate e = ter(fin);
        expect(e.status, ScheduleStatus.unknown, reason: '$fin');
        expect(e.reason, 'SERVICE_ENDED', reason: '$fin');
        expect(e.estimatedFrom, isNull);
        expect(e.frequencyMinutes, isNull);
      }
    });

    test('dimanche 2026-10-04 : 06:29 / 06:30 / 11:43 / 21:59 / 22:00 / 22:01', () {
      final DepartureEstimate avant = ter(DateTime(2026, 10, 4, 6, 29));
      expect(avant.relative, 'BEFORE_SERVICE');
      expect(DepartureEngineService.clockOfIso(avant.estimatedFrom), '06:30');
      expect(DepartureEngineService.clockOfIso(avant.estimatedTo), '06:50');
      expect(avant.frequencyMinutes, 20);

      final DepartureEstimate ouverture = ter(DateTime(2026, 10, 4, 6, 30));
      expect(ouverture.status, ScheduleStatus.estimated);
      expect(ouverture.relative, 'NOW');

      final DepartureEstimate jour = ter(DateTime(2026, 10, 4, 11, 43));
      expect(jour.frequencyMinutes, 20, reason: 'dimanche : 20 min, pas 10');

      final DepartureEstimate dernier = ter(DateTime(2026, 10, 4, 21, 59));
      expect(DepartureEngineService.clockOfIso(dernier.estimatedTo), '22:00');

      expect(ter(DateTime(2026, 10, 4, 22, 0)).reason, 'SERVICE_ENDED');
      expect(ter(DateTime(2026, 10, 4, 22, 1)).status, ScheduleStatus.unknown);
    });

    test('jour férié explicitement déclaré : la règle dimanche/fériés s’applique', () {
      final DepartureEstimate ferie = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 10, 5, 11, 43),
        registry: _registreAvecFerie('2026-10-05'),
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(ferie.status, ScheduleStatus.estimated);
      expect(ferie.dayType, 'HOLIDAY');
      expect(ferie.frequencyMinutes, 20, reason: '20 min le lundi férié');

      // Sans calendrier explicite, le même instant reste un lundi ordinaire :
      // le moteur ne devine jamais un jour férié.
      final DepartureEstimate lundi = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 10, 5, 11, 43),
        registry: _registreAudite(),
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(lundi.dayType, 'MONDAY');
      expect(lundi.frequencyMinutes, 10);
    });

    test('changement de période : 10 min → 20 min → service terminé', () {
      expect(ter(DateTime(2026, 9, 28, 20, 57)).frequencyMinutes, 10);
      expect(DepartureEngineService.clockOfIso(
          ter(DateTime(2026, 9, 28, 20, 57)).estimatedTo), '21:00');
      expect(ter(DateTime(2026, 9, 28, 21, 0)).frequencyMinutes, 20);
      expect(ter(DateTime(2026, 9, 28, 23, 59)).reason, 'SERVICE_ENDED');
    });
  });

  group('3bis — BRT, DDD, AFTU, Tata', () {
    DepartureEstimate b1(DateTime now) => DepartureEngineService.estimateForLine(
        modeLabel: 'BRT', lineId: 'brt_b1_guediawaye_petersen', now: now);
    DepartureEstimate b2(DateTime now) => DepartureEngineService.estimateForLine(
        modeLabel: 'BRT', lineId: 'brt_b2_express', now: now);
    DepartureEstimate ter(DateTime now) =>
        DepartureEngineService.estimateForLine(modeLabel: 'TER', now: now);

    test('B1 : 6 min tous les jours, y compris le dimanche', () {
      final DepartureEstimate dim = b1(DateTime(2026, 10, 4, 14, 0));
      expect(dim.status, ScheduleStatus.estimated);
      expect(dim.frequencyMinutes, 6);
      expect(DepartureEngineService.clockOfIso(dim.estimatedFrom), '14:00');
      expect(DepartureEngineService.clockOfIso(dim.estimatedTo), '14:06');

      final DepartureEstimate avant = b1(DateTime(2026, 10, 4, 5, 59));
      expect(avant.relative, 'BEFORE_SERVICE');
      expect(DepartureEngineService.clockOfIso(avant.estimatedFrom), '06:00');
      expect(b1(DateTime(2026, 10, 4, 21, 0)).reason, 'SERVICE_ENDED');
    });

    test('B2 : 6 min du lundi au samedi, aucune fréquence le dimanche', () {
      expect(b2(DateTime(2026, 9, 28, 11, 0)).frequencyMinutes, 6);
      expect(b2(DateTime(2026, 10, 4, 11, 0)).status, ScheduleStatus.unknown);
      expect(b2(DateTime(2026, 10, 4, 11, 0)).reason, 'NO_FREQUENCY_FOR_DAY');
    });

    test('aucune fréquence B1/B2 n’est étendue à d’autres lignes BRT', () {
      final DepartureRegistry reg = DepartureEngineService.registry!;
      expect(reg.frequenciesForLine('brt_b3_semi_express'), isEmpty);
      expect(reg.frequenciesForLine('brt_b4_express'), isEmpty);
      final DepartureEstimate b3 = DepartureEngineService.estimateForLine(
          modeLabel: 'BRT',
          lineId: 'brt_b3_semi_express',
          now: DateTime(2026, 9, 28, 11, 0));
      expect(b3.status, ScheduleStatus.unknown);
    });

    test('DDD / AFTU / Tata : UNKNOWN à toute heure', () {
      for (final DateTime now in <DateTime>[
        DateTime(2026, 9, 28, 6, 0),
        DateTime(2026, 9, 28, 11, 43),
        DateTime(2026, 9, 28, 18, 30),
      ]) {
        for (final MapEntry<String, String> cas in const <String, String>{
          'DDD': 'ddd_1',
          'AFTU': 'aftu_1',
          'Tata': 'tata_50',
        }.entries) {
          final DepartureEstimate e = DepartureEngineService.estimateForLine(
              modeLabel: cas.key, lineId: cas.value, now: now);
          expect(e.status, ScheduleStatus.unknown, reason: '${cas.key} $now');
          expect(e.frequencyMinutes, isNull, reason: '${cas.key} $now');
        }
      }
    });

    test('TER : la fréquence ne dépend pas du sens (documentée au niveau ligne)', () {
      final DepartureEstimate aller = DepartureEngineService.estimateForLine(
          modeLabel: 'TER', direction: 'Dakar ↔ Diamniadio', now: DateTime(2026, 9, 28, 10, 0));
      final DepartureEstimate retour = DepartureEngineService.estimateForLine(
          modeLabel: 'TER', direction: 'Diamniadio ↔ Dakar', now: DateTime(2026, 9, 28, 10, 0));
      expect(aller.frequencyMinutes, retour.frequencyMinutes);
      expect(ter(DateTime(2026, 9, 28, 10, 0)).status, ScheduleStatus.estimated);
    });
  });

  // ==================================================================
  // 4. Gestion des erreurs (§14) — jamais de donnée inventée
  // ==================================================================
  group('4 — référentiel absent, vide ou incohérent', () {
    test('sans référentiel chargé : TOUT est UNKNOWN', () async {
      final DepartureRegistry? sauvegarde = DepartureEngineService.registry;
      DepartureEngineService.registry = null;
      try {
        expect(DepartureEngineService.isReady, isFalse);
        final DepartureEstimate e = _arret('TER', lineId: 'ter_dakar_diamniadio')
            .departureEstimate(now: DateTime(2026, 9, 28, 11, 43));
        expect(e.status, ScheduleStatus.unknown);
        expect(e.reason, 'NO_DATA');
        expect(e.estimatedFrom, isNull);
        expect(DepartureEngineService.hasDocumentedFrequency('TER'), isFalse);
        expect(DepartureEngineService.displayFor(e).body, 'Horaire indisponible');
      } finally {
        DepartureEngineService.registry = sauvegarde;
      }
      expect(DepartureEngineService.isReady, isTrue);
    });

    test('référentiel vide : aucune estimation', () {
      final DepartureRegistry vide = DepartureEngineService.parseRegistry(
          '{"schema":"vide","sources":[],"frequencies":[],"holidays":{"dates":[]}}');
      expect(DepartureEngineService.validateFrequencyRegistry(vide), isEmpty);
      final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 9, 28, 11, 43),
        registry: vide,
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(e.status, ScheduleStatus.unknown);
      expect(e.reason, 'NO_FREQUENCY_FOR_LINE');
    });

    test('ligne inconnue et arrêt inconnu : UNKNOWN', () {
      expect(
          DepartureEngineService.estimateForLine(
                  modeLabel: 'TER', lineId: 'ligne_inexistante', now: DateTime(2026, 9, 28, 11, 43))
              .status,
          ScheduleStatus.unknown);
      expect(
          DepartureEngineService.estimateForLine(
                  modeLabel: 'Inconnu', stopId: 'stop_inconnu', now: DateTime(2026, 9, 28, 11, 43))
              .status,
          ScheduleStatus.unknown);
      expect(
          DepartureEngineService.estimateForLine(now: DateTime(2026, 9, 28, 11, 43)).status,
          ScheduleStatus.unknown,
          reason: 'aucun réseau fourni');
    });

    test('référentiel incohérent : détecté, jamais « réparé »', () {
      final DepartureRegistry casse = DepartureEngineService.parseRegistry('''
      {"schema":"casse","sources":[{"id":"s","source_type":"OFFICIAL","url":null}],
       "frequencies":[{"id":"f","network":"TER","line_id":"ter_dakar_diamniadio",
         "day_types":["MONDAY"],"service_start":"21:00","service_end":"05:00",
         "frequency_minutes":0,"status":"ACTIVE","source_id":"s"}]}''');
      final List<String> problemes =
          DepartureEngineService.validateFrequencyRegistry(casse);
      expect(problemes.any((String p) => p.contains('FREQUENCY_INVALID_MINUTES')), isTrue);
      expect(problemes.any((String p) => p.contains('FREQUENCY_INVALID_SERVICE_WINDOW')), isTrue);
      expect(problemes.any((String p) => p.contains('OFFICIAL_SOURCE_WITHOUT_URL')), isTrue);
      final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 9, 28, 11, 43),
        registry: casse,
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(e.status, ScheduleStatus.unknown);
      expect(e.frequencyMinutes, isNull);
    });

    test('jour férié : seul un calendrier explicite change la règle', () {
      final DepartureEstimate sansCalendrier = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 10, 5, 11, 43),
        registry: _registreAudite(),
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(sansCalendrier.dayType, 'MONDAY');
      expect(sansCalendrier.frequencyMinutes, 10);
      final DepartureEstimate avecCalendrier = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 10, 5, 11, 43),
        registry: _registreAvecFerie('2026-10-05'),
        network: 'TER',
        lineId: 'ter_dakar_diamniadio',
      );
      expect(avecCalendrier.dayType, 'HOLIDAY');
      expect(avecCalendrier.frequencyMinutes, 20);
    });
  });

  // ==================================================================
  // 5. Assistant IA : mêmes DepartureEstimate, aucune réponse inventée
  // ==================================================================
  group('5 — assistant', () {
    test('ESTIMATED : fenêtre annoncée, heure exacte refusée', () {
      final DepartureEstimate e = DepartureEngineService.estimateForLine(
          modeLabel: 'TER', now: DateTime(2026, 9, 28, 11, 43));
      final String reponse = AssistantReplies.nextDeparture(e, mode: 'TER');
      expect(reponse, contains('fenêtre de 0 à 10 minutes'));
      expect(reponse, contains("L'heure exacte du train n'est pas disponible"));
      expect(kHeurePrecise.hasMatch(reponse), isFalse, reason: reponse);
      expect(kTempsReel.hasMatch(reponse), isFalse, reason: reponse);
    });

    test('UNKNOWN : refus explicite, aucun chiffre', () {
      final DepartureEstimate e = DepartureEngineService.estimateForLine(
          modeLabel: 'DDD', lineId: 'ddd_1', now: DateTime(2026, 9, 28, 11, 43));
      final String reponse = AssistantReplies.nextDeparture(e, mode: 'DDD');
      expect(reponse, contains('pas actuellement de donnée suffisamment fiable'));
      expect(RegExp(r'\d+\s*min').hasMatch(reponse), isFalse, reason: reponse);
      expect(kHeurePrecise.hasMatch(reponse), isFalse, reason: reponse);
    });

    test('BEFORE_SERVICE : l’ouverture documentée est annoncée comme estimation', () {
      final DepartureEstimate e = DepartureEngineService.estimateForLine(
          modeLabel: 'BRT', lineId: 'brt_b1_guediawaye_petersen', now: DateTime(2026, 10, 4, 5, 0));
      final String reponse = AssistantReplies.nextDeparture(e, mode: 'BRT');
      expect(reponse, contains('Le service commence à 06:00'));
      expect(reponse, contains('estimé entre 6h00 et 6h06'));
      expect(reponse, contains("L'heure exacte du bus n'est pas disponible"));
    });

    test('description réseau : vraie pour TER/BRT, et toujours sans heure', () {
      for (final String op in <String>['ter', 'brt', 'ddd', 'tata', 'aftu']) {
        final String txt =
            AssistantReplies.modeInfo(op, appDataService.operators, appDataService.routes);
        expect(txt, contains("Je ne dispose d'aucun horaire"), reason: op);
        expect(kHeurePrecise.hasMatch(txt), isFalse, reason: '$op : $txt');
        expect(kTempsReel.hasMatch(txt), isFalse, reason: '$op : $txt');
      }
      final String ter =
          AssistantReplies.modeInfo('ter', appDataService.operators, appDataService.routes);
      expect(ter, contains('fréquence documentée'),
          reason: 'TER a une fréquence sourcée : la phrase doit le dire');
      final String ddd =
          AssistantReplies.modeInfo('ddd', appDataService.operators, appDataService.routes);
      expect(ddd, contains("aucune estimation n'est possible"),
          reason: 'DDD n’a aucune fréquence : la phrase doit le dire');
    });

    testWidgets('RENDU : la réponse de l’assistant vient du moteur', (WidgetTester tester) async {
      await _monte(tester, const AIChatPage());

      Future<void> question(String texte) async {
        await tester.enterText(find.byType(TextField), texte);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
      }

      // La phrase attendue est EXACTEMENT celle du moteur, calculée au même
      // instant (l'interface ne formule rien elle-même). Deux mesures
      // encadrent le rendu : une bascule de minute ne fait pas échouer le test.
      String phraseMoteur(String modeLabel) =>
          DepartureEngineService.assistantReply(
              DepartureEngineService.estimateForLine(modeLabel: modeLabel),
              mode: modeLabel);

      // La bulle de réponse est cherchée dans la conversation : le dernier
      // `Text` de l'écran est l'indication du champ de saisie, et la liste
      // paresseuse peut ne pas construire les bulles hors du viewport.
      List<String> bulles(String phrase) => _textes(tester)
          .where((String t) => t.contains(phrase))
          .toList();

      final String descriptionTer = AssistantReplies.modeInfo(
          'ter', appDataService.operators, appDataService.routes);
      final String avantTer = phraseMoteur('TER');
      await question('Je veux partir maintenant en TER');
      final String apresTer = phraseMoteur('TER');
      final List<String> bullesTer =
          bulles('Le TER est disponible dans cette direction');
      expect(bullesTer, isNotEmpty,
          reason: 'le moteur doit avoir répondu sur le TER : ${_textes(tester)}');
      for (final String reponseTer in bullesTer) {
        expect(reponseTer.startsWith(descriptionTer), isTrue,
            reason: 'la description réseau précède la phrase du moteur : '
                '$reponseTer');
        expect(reponseTer.endsWith(avantTer) || reponseTer.endsWith(apresTer),
            isTrue,
            reason: 'réponse = phrase du moteur — obtenu : $reponseTer');
        expect(kHeurePrecise.hasMatch(reponseTer), isFalse, reason: reponseTer);
        expect(kTempsReel.hasMatch(reponseTer), isFalse, reason: reponseTer);
      }

      final String avantDdd = phraseMoteur('DDD');
      await question('Et en DDD ?');
      final String apresDdd = phraseMoteur('DDD');
      final List<String> reponsesDdd = bulles('pas actuellement de donnée');
      expect(reponsesDdd, isNotEmpty,
          reason: 'le moteur doit avoir refusé d\'inventer un horaire DDD : '
              '${_textes(tester)}');
      for (final String reponseDdd in reponsesDdd) {
        expect(reponseDdd.endsWith(avantDdd) || reponseDdd.endsWith(apresDdd),
            isTrue,
            reason: reponseDdd);
        expect(RegExp(r'\d+\s*min').hasMatch(reponseDdd), isFalse,
            reason: reponseDdd);
      }
    });
  });

  // ==================================================================
  // 6. Rendu : l’écran affiche EXACTEMENT ce que le moteur produit
  // ==================================================================
  group('6 — rendu', () {
    testWidgets('StopCard : statut du moteur, jamais un horaire inventé',
        (WidgetTester tester) async {
      final Stop ter = allStops.firstWhere((Stop s) => s.modeLabel == 'TER');
      final DepartureDisplay avant = ter.departureDisplay();
      await _monte(tester, Scaffold(body: StopCard(stop: ter, distanceMeters: 300)));
      final DepartureDisplay apres = ter.departureDisplay();
      final List<String> textes = _textes(tester);

      if (avant.available) {
        expect(
            textes.any((String t) =>
                t == DepartureEngineService.shortLabel(avant) ||
                t == DepartureEngineService.shortLabel(apres)),
            isTrue,
            reason: '$textes');
        expect(textes, contains(avant.badge));
      } else {
        expect(textes, contains(ReliabilityLabel.scheduleUnavailable));
      }
      expect(textes.any((String t) => t.contains('Affluence indisponible')),
          isTrue,
          reason: 'la colonne Affluence reste inchangée : $textes');
      expect(textes.where(kHeurePrecise.hasMatch), isEmpty,
          reason: 'aucune heure précise ne doit apparaître : $textes');
    });

    testWidgets('StopCard : arrêt DDD → « Horaire indisponible »',
        (WidgetTester tester) async {
      final Stop ddd = allStops.firstWhere((Stop s) => s.modeLabel == 'DDD');
      await _monte(tester, Scaffold(body: StopCard(stop: ddd, distanceMeters: 500)));
      final List<String> textes = _textes(tester);
      expect(textes, contains(ReliabilityLabel.scheduleUnavailable));
      expect(textes.any((String t) => t.contains('Affluence indisponible')),
          isTrue,
          reason: 'la colonne Affluence reste inchangée : $textes');
      expect(textes.where((String t) => t.contains('Estimation')), isEmpty);
      expect(textes.where(kHeurePrecise.hasMatch), isEmpty);
    });

    testWidgets('Fiche d’arrêt : statut du moteur + source, affluence conservée',
        (WidgetTester tester) async {
      final Stop ter = allStops.firstWhere((Stop s) => s.modeLabel == 'TER');
      await _monte(tester, Scaffold(body: SingleStopView(stop: ter)));
      final List<String> textes = _textes(tester);
      final DepartureDisplay d = ter.departureDisplay();

      expect(textes, contains('Prochain passage'));
      expect(textes.any((String t) => t.contains('Affluence indisponible')),
          isTrue,
          reason: 'la colonne Affluence reste inchangée : $textes');
      if (d.available) {
        expect(textes, contains(d.badge));
        expect(textes.any((String t) => t.startsWith('Prochain passage estimé') || t.startsWith('Départ')),
            isTrue, reason: '$textes');
        expect(textes.any((String t) => t.contains('SETER')), isTrue,
            reason: 'la source doit être affichée : $textes');
      } else {
        expect(textes, contains(ReliabilityLabel.scheduleUnavailable));
      }
    });

    testWidgets('Fiche d’arrêt : TE jamais présenté pour une estimation',
        (WidgetTester tester) async {
      final Stop ter = allStops.firstWhere((Stop s) => s.modeLabel == 'TER');
      await _monte(tester, Scaffold(body: SingleStopView(stop: ter)));
      for (final String t in _textes(tester)) {
        expect(kTempsReel.hasMatch(t), isFalse, reason: t);
      }
    });
  });

  // ==================================================================
  // 7. Non-régression (§17)
  // ==================================================================
  group('7 — non-régression', () {
    test('aucune donnée n’a été ajoutée ni promue', () {
      final Set<String> ids = appDataService.stops.map((BusStop b) => b.id).toSet();
      expect(ids.contains('stop_keur_massar'), isTrue);
      expect(ids.contains('stop_mbao'), isTrue);
      expect(ids.contains('stop_yeumbeul'), isTrue);
      expect(ids.where((String id) => id.contains('aibd')), isEmpty);
      final Map<String, dynamic> json = jsonDecode(
              File('assets/data/dakar_network.json').readAsStringSync())
          as Map<String, dynamic>;
      final List<Map<String, dynamic>> notExposed =
          (json['services_not_exposed'] as List).cast<Map<String, dynamic>>();
      expect(notExposed.every((Map<String, dynamic> s) => s['exposed'] == false), isTrue);
      expect(notExposed.map((Map<String, dynamic> s) => s['id']),
          containsAll(<String>['brt_b3', 'brt_b4', 'ter_diamniadio_aibd']));
      final DepartureRegistry reg = DepartureEngineService.registry!;
      expect(reg.frequenciesForLine('brt_b3_semi_express'), isEmpty);
      expect(reg.frequenciesForLine('ter_diamniadio_aibd'), isEmpty);
      expect(appDataService.routes.map((TransportRoute r) => r.operatorId).toSet(),
          containsAll(<String>['ter', 'brt', 'ddd', 'aftu', 'tata']));
    });

    test('KMF reste UNKNOWN, Mbao reste distinct', () {
      final BusStop kmf =
          appDataService.stops.firstWhere((BusStop b) => b.id == 'stop_keur_massar');
      final BusStop mbao =
          appDataService.stops.firstWhere((BusStop b) => b.id == 'stop_mbao');
      expect(kmf.placeId, isNot(mbao.placeId));
      expect(mbao.provenance.status, ProvenanceStatus.unverified);
      expect(
          DepartureEngineService.estimateForLine(
                  modeLabel: 'TER',
                  lineId: 'keur_massar',
                  now: DateTime(2026, 9, 28, 11, 43))
              .status,
          ScheduleStatus.unknown);
    });

    testWidgets('horaire réellement fourni à un arrêt : « programmé », jamais estimé',
        (WidgetTester tester) async {
      // Cas synthétique (aucun arrêt du référentiel ne fournit d'horaire) :
      // il vérifie que le branchement n'a pas supprimé le chemin audité
      // « horaire fourni → programmé » et ne l'a pas transformé en estimation.
      final int dans5min = DateTime.now().minute + 5;
      final Stop programme = Stop(
        name: 'Arrêt programmé (test)',
        direction: 'Dir. Test',
        distanceMeters: 100,
        departureMinutesFromMidnight: <int>[
          (DateTime.now().hour * 60 + dans5min) % (24 * 60)
        ],
        icon: Icons.circle,
        color: const Color(0xFF00B140),
        location: const LatLng(14.7167, -17.4677),
        modeLabel: 'DDD',
      );
      expect(programme.scheduleStatus, ScheduleStatus.scheduled,
          reason: 'un horaire fourni reste un horaire fourni');
      final DepartureEstimate e = programme.departureEstimate();
      expect(e.status, ScheduleStatus.unknown,
          reason: 'sans source identifiée, le moteur ne promeut pas un horaire local');
      expect(e.frequencyMinutes, isNull);

      await _monte(tester, Scaffold(body: StopCard(stop: programme, distanceMeters: 100)));
      final List<String> textes = _textes(tester);
      expect(textes.where((String t) => t.contains('Estimation')), isEmpty, reason: '$textes');
      expect(textes.where(kTempsReel.hasMatch), isEmpty, reason: '$textes');
      final String attendu = programme.nextDepartureLabel()!;
      expect(
          textes.contains('Aucun départ programmé') ||
              textes.contains(attendu.startsWith('Prévu') ? attendu : 'Prévu $attendu'),
          isTrue,
          reason: '$textes');
    });

    test('aucune logique de départ parallèle : Stop ne calcule pas d’heure', () {
      final String code = File('lib/main.dart')
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('DepartureEngineService.estimateForLine'), isTrue,
          reason: 'l’interface passe par le moteur commun');
      for (final String interdit in <String>[
        "DateTime.now().add(",
        "dans 7 minutes",
        "retard de 5",
      ]) {
        expect(code.contains(interdit), isFalse, reason: interdit);
      }
      // L'accesseur d'interface ne connaît aucune donnée : il délègue.
      final Stop s = _arret('TER', lineId: 'ter_dakar_diamniadio');
      expect(s.departureMinutesFromMidnight, isEmpty);
      expect(s.nextDepartureLabel(), ReliabilityLabel.scheduleUnavailable);
      expect(s.departureEstimate(now: DateTime(2026, 9, 28, 11, 43)).status,
          ScheduleStatus.estimated);
    });
  });
}
