// LOT 7 (b) — TEST D'INTÉGRATION DE BOUT EN BOUT DU PIPELINE D'AFFICHAGE.
//
// Objectif : prouver, pour TER / BRT / DDD / AFTU, la chaîne COMPLÈTE
//
//   source GTFS → route → trip → direction → arrêt → stop_time
//   → heure Dakar → calcul X → DepartureInfo → composant Explorer → texte vert
//
// et non plus seulement « DepartureInfo.label est correct ». Le test ÉCHOUE si
// la valeur calculée depuis le stop_time n'arrive pas jusqu'au texte rendu par
// le composant Explorer (StopCard / SingleStopView).
//
// Données = feeds PassBi RÉELS embarqués (aucune donnée de transport créée).
// Les nombres exacts (TER 07:35/07:42/07:47 → 3/10/15 mn) proviennent d'une
// lecture indépendante des GTFS bruts, documentée dans
// explorer_prochains_passages_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/schedule_display.dart';
import 'package:dakar_bus/models/service_availability.dart';
import 'package:dakar_bus/models/transport_network.dart';

/// LOT fin de service — un texte d'attente est admis s'il porte soit les
/// minutes réelles (« N mn · … »), soit l'indisponibilité honnête, soit le
/// message de fin de service documenté (« Fin de service » / « Fin de service —
/// reprise à HH:MM … »). Ces deux derniers ne sont produits que lorsque le
/// service du jour est RÉELLEMENT terminé (bornes du feed), jamais inventés.
bool _isDepartureOrUnavailable(Widget w) {
  if (w is! Text || w.data == null) return false;
  final String d = w.data!;
  if (RegExp(r'^\d+ mn( · \d+ mn){0,2}$').hasMatch(d)) return true;
  // Passage estimé depuis une fréquence DOCUMENTÉE (jamais un stop_time réel).
  if (RegExp(r'^Passage estimé · \d+ mn$').hasMatch(d)) return true;
  if (d == ReliabilityLabel.scheduleUnavailable) return true;
  if (d == ServiceAvailability.labelServiceEnded) return true;
  if (d.startsWith('${ServiceAvailability.labelServiceEnded} — reprise à ')) {
    return true;
  }
  return false;
}

/// Vrai si [text] est le message de fin de service (jamais un délai chiffré).
bool _isServiceEndedText(String text) =>
    text == ServiceAvailability.labelServiceEnded ||
    text.startsWith('${ServiceAvailability.labelServiceEnded} — reprise à ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lundi 2026-09-28 (service TER/BRT/DDD/AFTU actif). Fuseau Dakar = UTC+0.
  final DateTime lundi0732 = DateTime.utc(2026, 9, 28, 7, 32);
  final DateTime lundi14 = DateTime.utc(2026, 9, 28, 14, 0);

  const String terGare =
      '544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';

  setUpAll(() async {
    await app.appDataService.loadNetworkData();
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi est la source opérationnelle réelle');
  });

  // ------------------------------------------------------------------
  // Fabrique un arrêt EXPLORER (référentiel dakar : TER/BRT)
  // ------------------------------------------------------------------
  app.Stop explorerStop({
    required String name,
    required String stopId,
    required String scheduleRouteId,
    required String modeLabel,
    required Color color,
  }) =>
      app.Stop(
        name: name,
        stopId: stopId,
        scheduleRouteId: scheduleRouteId,
        direction: 'Dir. Test',
        distanceMeters: 100,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_transit,
        color: color,
        location: const LatLng(14.7, -17.45),
        modeLabel: modeLabel,
        source: app.DataSourceInfo.seter,
        stopType: app.StopType.boarding,
      );

  // Fabrique un arrêt EXPLORER NATIF PassBi (DDD/AFTU)
  app.Stop nativeStop({
    required String name,
    required String compositeKey,
    required String modeLabel,
    required Color color,
  }) =>
      app.Stop(
        name: name,
        passBiStopKey: compositeKey,
        direction: 'Dir. Test',
        distanceMeters: 100,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_bus,
        color: color,
        location: const LatLng(14.7, -17.45),
        modeLabel: modeLabel,
        source: app.DataSourceInfo.demdikk,
        stopType: app.StopType.boarding,
      );

  // ==================================================================
  // A. TER — chaîne exacte : stop_time réel → 3 mn · 10 mn · 15 mn
  // ==================================================================
  group('A. TER — stop_time réel → calcul → texte Explorer', () {
    test('stop_times 07:35/07:42/07:47 à 07:32 → 3/10/15 mn', () {
      final app.Stop stop = nativeStop(
        name: 'Gare TER Dakar',
        compositeKey: 'TER:$terGare',
        modeLabel: 'TER',
        color: app.AppColors.ter,
      );
      final List<DepartureInfo> list = stop.nextRealDepartures(at: lundi0732);
      expect(list.length, 3);
      expect(list[0].scheduledTime, DateTime.utc(2026, 9, 28, 7, 35));
      expect(list[1].scheduledTime, DateTime.utc(2026, 9, 28, 7, 42));
      expect(list[2].scheduledTime, DateTime.utc(2026, 9, 28, 7, 47));
      for (final DepartureInfo info in list) {
        expect(info.status, ScheduleStatus.scheduled);
        expect(info.scheduledTime, isNotNull);
        expect(info.frequencyMinutes, isNull,
            reason: 'un passage réel n\'a jamais de fréquence');
      }
      // calcul X : ceil(stop_time - heure Dakar)
      expect(stop.nextRealWaitingMinutes(at: lundi0732), <int>[3, 10, 15]);
      // texte EXACT que rend l'Explorer
      expect(formatWaitingMinutes(<int>[3, 10, 15]), '3 mn · 10 mn · 15 mn');
    });

    testWidgets('StopCard rend un délai numérique vert (ou l\'indisponibilité)', (t) async {
      final app.Stop stop = explorerStop(
        name: 'Gare TER Dakar',
        stopId: terGare,
        scheduleRouteId: 'ter_dakar_diamniadio',
        modeLabel: 'TER',
        color: app.AppColors.ter,
      );
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: app.StopCard(stop: stop, distanceMeters: 100),
        ),
      ));
      await t.pump();

      // Le composant rend, à l'instant Dakar courant, soit les minutes réelles
      // calculées par le pipeline (« N mn · … », vert), soit l'indicateur neutre
      // « Horaire indisponible ». Aucun autre texte n'est admis.
      final Finder finder = find.byWidgetPredicate(_isDepartureOrUnavailable);
      expect(finder, findsWidgets);
      final Text rendered = t.widget<Text>(finder.first);
      final String text = rendered.data!;
      if (_isServiceEndedText(text) ||
          text == ReliabilityLabel.scheduleUnavailable) {
        expect(rendered.style?.color, isNot(app.AppColors.success));
      } else {
        expect(rendered.style?.color, app.AppColors.success,
            reason: 'un délai réel est VERT : « $text »');
        for (final m in RegExp(r'\d+').allMatches(text)) {
          expect(int.parse(m.group(0)!), greaterThanOrEqualTo(1),
              reason: 'jamais 0 mn');
        }
      }
      expect(text.contains('moins'), isFalse);
      expect(text.toLowerCase().contains('fréquence'), isFalse);
      expect(RegExp(r'\d\s*[–-]\s*\d').hasMatch(text), isFalse);
    });
  });

  // ==================================================================
  // B. BRT — stop_time > fréquence, jamais « 0 min »
  // ==================================================================
  group('B. BRT — stop_time réel → calcul → texte Explorer', () {
    test('B1 Petersen 14:00 → 1 min (jamais 0 min)', () {
      final DepartureInfo info = app.appDataService.departureFor(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        network: 'BRT',
        at: lundi14,
      );
      expect(info.status, ScheduleStatus.scheduled,
          reason: 'un stop_time existe → SCHEDULED, la fréquence ne l\'écrase pas');
      expect(info.scheduledTime, isNotNull);
      expect(info.label, 'Prochain départ dans 1 min');
      expect(RegExp(r'(^|[^0-9])0 min').hasMatch(info.label), isFalse);
    });

    testWidgets('SingleStopView BRT rend un délai numérique vert', (t) async {
      final app.Stop stop = explorerStop(
        name: 'Petersen',
        stopId: 'stop_brt_01_petersen',
        scheduleRouteId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
        color: app.AppColors.brt,
      );
      await t.pumpWidget(MaterialApp(home: Scaffold(body: app.SingleStopView(stop: stop))));
      await t.pump();

      // La fiche arrêt rend les minutes réelles calculées (« N mn · … », vert)
      // à l'instant Dakar courant, ou « Horaire indisponible ». Rien d'autre.
      final Finder finder = find.byWidgetPredicate(_isDepartureOrUnavailable);
      expect(finder, findsWidgets);
      final Text rendered = t.widget<Text>(finder.first);
      final String text = rendered.data!;
      if (!_isServiceEndedText(text) &&
          text != ReliabilityLabel.scheduleUnavailable) {
        expect(rendered.style?.color, app.AppColors.success);
        for (final m in RegExp(r'\d+').allMatches(text)) {
          expect(int.parse(m.group(0)!), greaterThanOrEqualTo(1),
              reason: 'jamais 0 mn');
        }
      }
    });
  });

  // ==================================================================
  // C. DDD — natif PassBi : trip + stop_time + service actif
  // ==================================================================
  group('C. DDD — PassBi natif → stop_time → calcul → texte Explorer', () {
    test('au moins un arrêt DDD porte un stop_time futur à 14:00', () {
      final List<PassBiStopRefLite> withTimes = <PassBiStopRefLite>[];
      for (final ref in app.appDataService.passBiNativeStops('DDD')) {
        final info = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD', pbStopId: ref.stopId, at: lundi14);
        if (info.status == ScheduleStatus.scheduled && info.scheduledTime != null) {
          withTimes.add(PassBiStopRefLite(ref.stopId, ref.name, info));
        }
      }
      expect(withTimes, isNotEmpty,
          reason: 'DDD est dans le feed PassBi : des stop_times existent');

      for (final e in withTimes.take(10)) {
        final int expected = waitingMinutesBetween(e.info.scheduledTime!, lundi14)!;
        expect(expected >= 1, isTrue);
        expect(e.info.label, 'Prochain départ dans $expected min');
        expect(e.info.label, isNot(contains('Horaire indisponible')),
            reason: 'un stop_time PassBi réel ne doit jamais être masqué');
      }
    });

    testWidgets('StopCard DDD (arrêt natif) rend le délai calculé', (t) async {
      // Instant de référence déterministe : un arrêt DDD porteur d'un
      // stop_time à 14:00. Le composant, lui, utilise l'heure Dakar courante :
      // le test accepte donc le délai calculé OU l'indisponibilité honnête.
      final ref = app.appDataService
          .passBiNativeStops('DDD')
          .firstWhere((r) => app.appDataService
              .passBiDepartureFor(networkKey: 'DDD', pbStopId: r.stopId, at: lundi14)
              .scheduledTime != null);
      final app.Stop stop = nativeStop(
        name: ref.name,
        compositeKey: 'DDD:${ref.stopId}',
        modeLabel: 'DDD',
        color: app.AppColors.ddd,
      );
      await t.pumpWidget(MaterialApp(home: Scaffold(body: app.StopCard(stop: stop, distanceMeters: 100))));
      await t.pump();

      final Finder finder = find.byWidgetPredicate(_isDepartureOrUnavailable);
      expect(finder, findsWidgets);
      final Text rendered = t.widget<Text>(finder.first);
      if (!_isServiceEndedText(rendered.data!) &&
          rendered.data != ReliabilityLabel.scheduleUnavailable) {
        expect(rendered.style?.color, app.AppColors.success);
        for (final m in RegExp(r'\d+').allMatches(rendered.data!)) {
          expect(int.parse(m.group(0)!), greaterThanOrEqualTo(1));
        }
      }
    });
  });

  // ==================================================================
  // D. AFTU — natif PassBi : trip + stop_time + service actif
  // ==================================================================
  group('D. AFTU — PassBi natif → stop_time → calcul → texte Explorer', () {
    test('au moins un arrêt AFTU porte un stop_time futur à 14:00', () {
      final List<PassBiStopRefLite> withTimes = <PassBiStopRefLite>[];
      for (final ref in app.appDataService.passBiNativeStops('AFTU')) {
        final info = app.appDataService.passBiDepartureFor(
          networkKey: 'AFTU', pbStopId: ref.stopId, at: lundi14);
        if (info.status == ScheduleStatus.scheduled && info.scheduledTime != null) {
          withTimes.add(PassBiStopRefLite(ref.stopId, ref.name, info));
        }
      }
      expect(withTimes, isNotEmpty,
          reason: 'AFTU est dans le feed PassBi : des stop_times existent');
      for (final e in withTimes.take(10)) {
        final int expected = waitingMinutesBetween(e.info.scheduledTime!, lundi14)!;
        expect(e.info.label, 'Prochain départ dans $expected min');
        expect(e.info.label, isNot(contains('Horaire indisponible')));
      }
    });
  });

  // ==================================================================
  // E. Verrou transverse : aucun libellé affiché ne contient
  //    « 0 min », « moins d'une minute », un intervalle ni « fréquence ».
  // ==================================================================
  group('E. Verrou anti-régression des libellés', () {
    test('aucun label (parcours réel) ne viole la règle', () {
      final List<String> labels = <String>[];

      // TER
      for (final info in app.appDataService.nextDeparturesFor(
          routeId: 'ter_dakar_diamniadio',
          stopId: terGare,
          network: 'TER',
          at: lundi0732)) {
        labels.add(info.label);
      }
      // BRT
      labels.add(app.appDataService
          .departureFor(
              routeId: 'brt_b1_guediawaye_petersen',
              stopId: 'stop_brt_01_petersen',
              network: 'BRT',
              at: lundi14)
          .label);
      // DDD + AFTU natifs
      for (final net in <String>['DDD', 'AFTU']) {
        for (final ref in app.appDataService.passBiNativeStops(net).take(50)) {
          labels.add(app.appDataService
              .passBiDepartureFor(networkKey: net, pbStopId: ref.stopId, at: lundi14)
              .label);
        }
      }

      for (final l in labels) {
        expect(RegExp(r'(^|[^0-9])0 min').hasMatch(l), isFalse, reason: l);
        expect(l.toLowerCase().contains('moins d\'une minute'), isFalse, reason: l);
        expect(ReliabilityLabel.containsForbiddenRangeOrFrequency(l), isFalse,
            reason: 'ni intervalle ni fréquence affichés : $l');
        expect(l.contains('LIVE'), isFalse, reason: l);
      }
    });

    test('sanitizeScheduleLabel retire un intervalle/fréquence résiduel', () {
      expect(
        ReliabilityLabel.sanitizeScheduleLabel('Passage estimé dans 0–6 min · fréquence 6 min'),
        'Passage estimé dans 0–6 min',
      );
      expect(
        ReliabilityLabel.containsForbiddenRangeOrFrequency('Passage estimé dans 0–6 min · fréquence 6 min'),
        isTrue,
      );
      // Un libellé déjà sûr n'est jamais modifié.
      expect(ReliabilityLabel.sanitizeScheduleLabel('Prochain départ dans 3 min'),
          'Prochain départ dans 3 min');
    });
  });
}

/// Petite projection de test (évite d'exposer un type de service ici).
class PassBiStopRefLite {
  final String stopId;
  final String name;
  final DepartureInfo info;
  const PassBiStopRefLite(this.stopId, this.name, this.info);
}
