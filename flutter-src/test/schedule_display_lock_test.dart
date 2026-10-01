// Verrouillage de l'affichage des horaires (audit 2026-09-30).
//
// Règle produit : Dakar Bus ne doit JAMAIS inventer une donnée, mais ne doit
// pas non plus afficher « Horaire indisponible » lorsqu'une ESTIMATION
// réellement calculable à partir d'une source DOCUMENTÉE existe.
//
// Anomalie corrigée : un arrêt du référentiel desservi par une ligne à
// fréquence publiée (ex. BRT B1, `brt_b1_guediawaye_petersen`, source
// https://www.sunubrt.sn/brt-1-omnibus/, 6 min lundi–samedi 06:00–21:00) mais
// sans `stop_time` propre à l'instant demandé affichait « Horaire
// indisponible » alors qu'une fréquence documentée est applicable.
//
// Données = feeds/référentiel RÉELS. Aucune donnée GTFS/PassBi n'est créée ou
// modifiée ; aucune correspondance n'est déduite d'une proximité.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/schedule_display.dart';
import 'package:dakar_bus/models/transport_network.dart';

// Lundi 2026-09-28, 14:38 heure de Dakar (UTC+0) : service actif, dans la
// fenêtre de fréquence B1 (06:00–21:00).
final DateTime lundi1438 = DateTime.utc(2026, 9, 28, 14, 38);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await app.appDataService.loadNetworkData();
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi est la source opérationnelle réelle');
  });

  app.Stop explorerStop({
    required String name,
    required String stopId,
    required String scheduleRouteId,
    required String modeLabel,
  }) =>
      app.Stop(
        name: name,
        direction: '',
        stopId: stopId,
        scheduleRouteId: scheduleRouteId,
        modeLabel: modeLabel,
        color: app.AppColors.brt,
        distanceMeters: 100,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_transit,
        location: const LatLng(14.7, -17.45),
        source: app.DataSourceInfo.seter,
        stopType: app.StopType.boarding,
      );

  // ------------------------------------------------------------------
  // 1. Modèle : format court d'estimation, jamais un faux temps.
  // ------------------------------------------------------------------
  group('1 — formatEstimatedWaitLabel', () {
    test('fréquence documentée → « Passage estimé · N mn »', () {
      expect(formatEstimatedWaitLabel(6), 'Passage estimé · 6 mn');
      expect(formatEstimatedWaitLabel(10), 'Passage estimé · 10 mn');
    });

    test('sans fréquence → null (l\'appelant garde « Horaire indisponible »)', () {
      expect(formatEstimatedWaitLabel(null), isNull);
      expect(formatEstimatedWaitLabel(0), isNull);
      expect(formatEstimatedWaitLabel(-3), isNull);
    });
  });

  // ------------------------------------------------------------------
  // 2. Données réelles : BRT Gadaye / Fith Mith (B1 mappée, sans stop_time).
  // ------------------------------------------------------------------
  group('2 — arrêt BRT B1 mappé sans stop_time → ESTIMATED documenté', () {
    test('Gadaye : aucun stop_time mais fréquence B1 applicable', () {
      final app.Stop s = explorerStop(
        name: 'Gadaye - Cambérène - BRT',
        stopId: 'stop_brt_22_gadaye',
        scheduleRouteId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      // Aucun passage réel calculable à cet instant.
      expect(s.nextRealWaitingMinutes(at: lundi1438, limit: 3), isEmpty);
      // Mais une fréquence DOCUMENTÉE est applicable.
      final DepartureInfo info = s.departureInfoAt(at: lundi1438);
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
      expect(info.scheduledTime, isNull,
          reason: 'une fréquence ne fabrique aucune heure de passage');
      expect(info.label, 'Passage estimé dans 6 min');
    });

    test('Fith Mith : idem (fréquence documentée, pas de départ fabriqué)', () {
      final app.Stop s = explorerStop(
        name: 'Fith Mith - BRT',
        stopId: 'stop_brt_20_fith_mith',
        scheduleRouteId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      expect(s.nextRealWaitingMinutes(at: lundi1438, limit: 3), isEmpty);
      final DepartureInfo info = s.departureInfoAt(at: lundi1438);
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
    });
  });

  // ------------------------------------------------------------------
  // 3. Rendu Explorer : l'estimation documentée remplace l'indisponibilité.
  // ------------------------------------------------------------------
  group('3 — rendu StopCard / SingleStopView', () {
    testWidgets('StopCard Gadaye affiche « Passage estimé · 6 mn »',
        (WidgetTester t) async {
      final app.Stop s = explorerStop(
        name: 'Gadaye - Cambérène - BRT',
        stopId: 'stop_brt_22_gadaye',
        scheduleRouteId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: s, distanceMeters: 100, at: lundi1438)),
      ));
      await t.pump();
      final List<String> texts =
          t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
      expect(texts, contains('Passage estimé · 6 mn'));
      expect(texts.contains(ReliabilityLabel.scheduleUnavailable), isFalse,
          reason: 'une estimation documentée ne doit pas être masquée');
    });

    testWidgets('SingleStopView Gadaye affiche « Passage estimé · 6 mn »',
        (WidgetTester t) async {
      final app.Stop s = explorerStop(
        name: 'Gadaye - Cambérène - BRT',
        stopId: 'stop_brt_22_gadaye',
        scheduleRouteId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: app.SingleStopView(stop: s, at: lundi1438)),
      ));
      await t.pump();
      final List<String> texts =
          t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
      expect(texts, contains('Passage estimé · 6 mn'));
    });
  });

  // ------------------------------------------------------------------
  // 4. Anti-invention : sans fréquence documentée, « Horaire indisponible ».
  //    DDD/AFTU non mappés (IDENTITE_NON_CONFIRMEE) et TATA (absent du feed)
  //    ne doivent JAMAIS produire d'estimation.
  // ------------------------------------------------------------------
  group('4 — aucune estimation inventée pour les réseaux non documentés', () {
    test('DDD non mappé (ddd_1) : pas de fréquence → UNKNOWN', () {
      final app.Stop s = explorerStop(
        name: 'HLM Grand Yoff',
        stopId: 'stop_hlm',
        scheduleRouteId: 'ddd_1',
        modeLabel: 'DDD',
      );
      final DepartureInfo info = s.departureInfoAt(at: lundi1438);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
      expect(formatEstimatedWaitLabel(info.frequencyMinutes), isNull);
      expect(s.nextRealWaitingMinutes(at: lundi1438, limit: 3), isEmpty);
    });

    test('AFTU non mappé (aftu_3) : pas de fréquence → UNKNOWN', () {
      final app.Stop s = explorerStop(
        name: 'Grand Médine - BRT',
        stopId: 'stop_grand_medine',
        scheduleRouteId: 'aftu_3',
        modeLabel: 'AFTU',
      );
      final DepartureInfo info = s.departureInfoAt(at: lundi1438);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.frequencyMinutes, isNull);
    });

    testWidgets('StopCard DDD non mappé garde « Horaire indisponible »',
        (WidgetTester t) async {
      final app.Stop s = explorerStop(
        name: 'HLM Grand Yoff',
        stopId: 'stop_hlm',
        scheduleRouteId: 'ddd_1',
        modeLabel: 'DDD',
      );
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: s, distanceMeters: 100, at: lundi1438)),
      ));
      await t.pump();
      final List<String> texts =
          t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
      expect(texts, contains(ReliabilityLabel.scheduleUnavailable));
      expect(texts.any((x) => x.startsWith('Passage estimé')), isFalse);
    });
  });
}
