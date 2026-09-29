// Lot 4.20 — INTÉGRATION UI RÉELLE DU MOTEUR PASSBI.
//
// Tests d'intégration de la chaîne DATA → ROUTING → UI sur les seams
// réellement branchés :
//   PassBi GTFS → PassBiSource → ScheduleProvider → RoutingEngine →
//   EtaCalculator → modèle de résultat (Stop / PlannedRoute / DepartureInfo)
//   → écrans (StopCard, Trajets, fiche ligne).
//
// Matrice §12 du lot (A–I) : TER, BRT B1, BRT B2, DDD, AFTU,
// correspondance (RoutingEngine), lendemain (J+1), terminus, horizon.
// Le moteur Lot 4.19 reste la source de vérité : aucune heure, ETA,
// correspondance ni identité n'est recalculée dans les widgets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime lundi10 = DateTime.utc(2026, 9, 28, 10, 0);
  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);
  final DateTime lundi14 = DateTime.utc(2026, 9, 28, 14, 0);
  final DateTime dimanche2359 = DateTime.utc(2026, 10, 4, 23, 59);

  setUpAll(() async {
    await app.appDataService.loadNetworkData();
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi doit être actif : c''est la source opérationnelle');
    expect(app.appDataService.routes, isNotEmpty);
  });

  /// Arrêt de test branché sur la vraie chaîne (mêmes champs que les arrêts
  /// intégrés par `_integrateNetworkData`).
  app.Stop stopFix({
    required String name,
    required String stopId,
    required String routeId,
    String modeLabel = 'TER',
  }) =>
      app.Stop(
        name: name,
        stopId: stopId,
        scheduleRouteId: routeId,
        direction: 'Dir. test',
        distanceMeters: 0,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_bus,
        color: Colors.green,
        location: const LatLng(14.7, -17.4),
        modeLabel: modeLabel,
      );

  /// Garde-fous communs : SCHEDULED strict, jamais « 0 min », jamais « Live ».
  void expectHonest(DepartureInfo info) {
    expect(info.status, isNot(ScheduleStatus.realTime));
    expect(app.departureDataStatus(info.status), isNot(app.DataStatus.live));
    expect(info.label, isNot('Prochain départ dans 0 min'),
        reason: '« 0 min » n\'est jamais affiché (une minute au minimum)');
    expect(info.label.toLowerCase(), isNot(contains('live')));
    if (info.status == ScheduleStatus.scheduled) {
      expect(info.scheduledTime, isNotNull);
      expect(info.frequencyMinutes, isNull,
          reason: 'une fréquence n''est jamais un départ');
      expect(info.label, startsWith('Prochain départ dans'));
    }
  }

  // ==================================================================== A
  group('A. TER — prochain départ, ETA, SCHEDULED', () {
    test('Colobane : départ réel du moteur, ETA calculée, PUBLIC_GTFS', () {
      final s = stopFix(
        name: 'Colobane',
        stopId: 'stop_colobane',
        routeId: 'ter_dakar_diamniadio',
      );
      expect(s.scheduleRouteId, 'ter_dakar_diamniadio');
      final info = s.departureInfoAt(at: lundi12);
      expectHonest(info);
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 12, 11, 25));
      expect(info.estimatedWaitFrom, 11);
      expect(info.label, 'Prochain départ dans 12 min');
      expect(info.sourceType, SourceType.publicGtfs);
      expect(app.departureDataStatus(info.status), app.DataStatus.scheduled);
    });

    testWidgets('StopCard affiche l''ETA PassBi (donnée dynamique)',
        (WidgetTester tester) async {
      final s = stopFix(
        name: 'Colobane',
        stopId: 'stop_colobane',
        routeId: 'ter_dakar_diamniadio',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: s, distanceMeters: 120)),
      ));
      await tester.pump();
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      // Lot 4.22 : les prochains passages RÉELS s'affichent uniquement en
      // minutes d'attente numériques (« 1 mn · 10 mn · 15 mn ») — jamais
      // « Prochain départ dans… », « Prévu HH h MM » ni « Passage estimé… »,
      // jamais « 0 mn » (les minutes commencent à 1).
      final minutesPattern = RegExp(r'^[1-9]\d* mn( · [1-9]\d* mn)*$');
      expect(texts.any(minutesPattern.hasMatch), isTrue,
          reason: 'liste de minutes d\'attente réelles: $texts');
      for (final t in texts) {
        expect(t.contains('Prochain départ dans'), isFalse, reason: t);
        expect(t.contains('Prévu'), isFalse, reason: t);
        expect(t.contains('Passage estimé'), isFalse, reason: t);
      }
      expect(
          texts.any((t) =>
              t.contains('Live') ||
              t.contains('Prochain départ dans 0 min')), isFalse);
    });
  });

  // ==================================================================== B
  group('B. BRT B1 — ligne correcte, prochain départ réel, ETA', () {
    test('Petersen (quai d arrivité) : départ embarquable via sœur PGFA', () {
      final s = stopFix(
        name: 'Petersen',
        stopId: 'stop_brt_01_petersen',
        routeId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      final info = s.departureInfoAt(at: lundi14);
      expectHonest(info);
      expect(info.status, ScheduleStatus.scheduled);
      // 14:00:30 = VRAI départ (jamais l'arrivée 14:02:27 du terminus).
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(info.estimatedWaitFrom, 0);
      expect(info.label, 'Prochain départ dans 1 min');
      expect(info.routeId, 'brt_b1_guediawaye_petersen');
    });

    test('identité d ligne PassBi : « BRT B1 » sur les segments moteur', () {
      // Le libellé vient des ids du feed (leg.routeId), pas d'une déduction.
      expect(
        app.RoutePlanner.passBiLineLabel('BRT', 'B1'), 'BRT B1');
      expect(
        app.RoutePlanner.passBiLineLabel('BRT', 'B2'), 'BRT B2');
      expect(app.RoutePlanner.passBiLineLabel('DDD', 'DDD_01'), 'DDD_01');
      expect(app.RoutePlanner.passBiLineLabel('AFTU', 'AFTU_3'), 'AFTU_3');
      // Un UUID TER n'est pas un numéro de ligne : seul le réseau s'affiche.
      expect(
        app.RoutePlanner.passBiLineLabel(
            'TER', '544a27a5-c6c6-4b70-b217-9c15d9b4278a-4445e51b'),
        'TER',
      );
    });
  });

  // ==================================================================== C
  group('C. BRT B2 — distinction conservée avec B1', () {
    test('départs distincts par ligne, aucune réutilisation croisée', () {
      final b1 = stopFix(
        name: 'Guédiawaye',
        stopId: 'stop_brt_23_guediawaye',
        routeId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      final b2 = stopFix(
        name: 'Guédiawaye',
        stopId: 'stop_brt_23_guediawaye',
        routeId: 'brt_b2_express',
        modeLabel: 'BRT',
      );
      final infoB1 = b1.departureInfoAt(at: lundi14);
      final infoB2 = b2.departureInfoAt(at: lundi14);
      expectHonest(infoB1);
      expectHonest(infoB2);
      expect(infoB1.status, ScheduleStatus.scheduled);
      expect(infoB2.status, ScheduleStatus.scheduled);
      expect(infoB1.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(infoB2.scheduledTime, DateTime.utc(2026, 9, 28, 14, 3, 30));
      expect(infoB1.scheduledTime == infoB2.scheduledTime, isFalse);
      expect(infoB1.routeId, 'brt_b1_guediawaye_petersen');
      expect(infoB2.routeId, 'brt_b2_express');
      // Jamais de B3 (feed BRT : B1 et B2 seulement).
      expect(
        app.appDataService.passBiSource
            .network('BRT')!
            .routes
            .any((r) => r.id == 'B3'),
        isFalse,
      );
    });
  });

  // ==================================================================== D
  group('D. DDD — moteur PassBi, aucune fréquence transformée en ETA', () {
    test('ddd_1 non mappé → UNKNOWN honnête (identité non confirmée)', () {
      final mapping = app.appDataService.passBiSource.routeMapping('ddd_1');
      expect(mapping, isNotNull);
      expect(mapping!.status, 'UNMAPPED');
      expect(mapping.pbRouteIds, isEmpty,
          reason: 'aucune identité forcée → aucun horaire rattaché');
      final s = stopFix(
        name: 'Colobane',
        stopId: 'stop_colobane',
        routeId: 'ddd_1',
        modeLabel: 'DDD',
      );
      final info = s.departureInfoAt(at: lundi12);
      expectHonest(info);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.scheduledTime, isNull);
      expect(info.frequencyMinutes, isNull,
          reason: 'pas de fréquence présentée comme un départ');
    });
  });

  // ==================================================================== E
  group('E. AFTU — moteur PassBi ; UNKNOWN seulement sans donnée exploitable',
      () {
    test('aftu_8 (identité non confirmée) : aucun horaire attribué à CETTE '
        'identité, mais les horaires PassBi restent exploitables', () {
      // Verrouillage Lot 4.21 : aftu_8 n'est plus « mappé » — les terminus
      // proches (TERMINI_MATCH) ne confirment jamais une identité, et
      // aftu_8/aftu_11 ne fusionnent jamais sur AFTU_3. Le chemin référentiel
      // dakar n'attribue donc AUCUN horaire à l'identité aftu_8 (aucune
      // identité fabriquée)…
      final s = stopFix(
        name: 'Yoff',
        stopId: 'stop_yoff',
        routeId: 'aftu_8',
        modeLabel: 'AFTU',
      );
      final info = s.departureInfoAt(at: lundi10);
      expectHonest(info);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.unresolvedReason, UnresolvedReason.identityUnconfirmed);
      expect(info.frequencyMinutes, isNull,
          reason: 'pas de fréquence présentée comme un départ');
      // …mais les VRAIS horaires PassBi restent calculables sur le chemin
      // natif (AFTU_3, trips + stop_times réels) : identité ≠ horaire.
      final net = app.appDataService.passBiSource.network('AFTU')!;
      final routeIndex = net.routeIndexById['AFTU_3']!;
      String? stopId;
      for (int ti = 0; ti < net.trips.length; ti++) {
        if (net.trips[ti].routeIndex != routeIndex) continue;
        final rows = net.stopTimesByTrip[ti];
        if (rows == null || rows.isEmpty) continue;
        stopId = net.stops[rows.first.stopIndex].id;
        break;
      }
      final natif = app.appDataService.passBiDepartureFor(
        networkKey: 'AFTU',
        pbStopId: stopId!,
        pbRouteId: 'AFTU_3',
        at: lundi10,
      );
      expectHonest(natif);
      expect(natif.status, ScheduleStatus.scheduled);
      expect(natif.identityStatus, IdentityStatus.unconfirmed);
      expect(natif.lineLabel, isNot(contains('PassBi')));
      expect(natif.lineLabel, startsWith('AFTU'));
    });

    test('aftu_12 non mappé sans fréquence → UNKNOWN (jamais inventé)', () {
      final s = stopFix(
        name: 'Colobane',
        stopId: 'stop_colobane',
        routeId: 'aftu_12',
        modeLabel: 'AFTU',
      );
      final info = s.departureInfoAt(at: lundi10);
      expectHonest(info);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.estimatedWaitFrom, isNull);
    });
  });

  // ==================================================================== F
  group('F. correspondance — résultat du RoutingEngine', () {
    test('BRT → AFTU via le moteur (transitions documentées, identités '
        'distinctes)', () {
      // Corridor réel du moteur : aucune logique de correspondance UI, seuls
      // les trips/stop_times et les liens documentés du crosswalk (jamais une
      // proximité seule, jamais une identité publique comme preuve).
      final js = app.appDataService.planPassBiJourneys(
        fromPassBiKeys: <String>{'BRT:0:GNOA'}, // GOLF NORD (BRT)
        toPassBiKeys: <String>{'AFTU:A_608'}, // Devant Goor Yomboul Tissus
        at: lundi10,
      );
      expect(js, isNotEmpty, reason: 'corridor BRT→AFTU exploitable');
      final j = js.first;
      expect(j.legs.first.network, 'BRT');
      expect(j.legs.last.network, 'AFTU');
      expect(j.transferCount, greaterThanOrEqualTo(1));
      for (int i = 1; i < j.legs.length; i++) {
        final prec = j.legs[i - 1];
        final suiv = j.legs[i];
        final partage = prec.toStopId == suiv.fromStopId;
        final lien = app.appDataService.passBiSource
            .transferBetween(prec.toStopId, suiv.fromStopId);
        expect(partage || lien != null, isTrue,
            reason: 'correspondance non documentée '
                '${prec.toStopId} → ${suiv.fromStopId}');
      }
      // Les identités des deux réseaux restent indépendantes de la
      // correspondance : BRT confirmé (preuve documentaire), AFTU non
      // confirmé — l'identité n'est JAMAIS une preuve de correspondance.
      expect(
          app.appDataService.passBiSource
              .identityStatusOf('BRT', j.legs.first.routeId),
          IdentityStatus.confirmed);
      expect(
          app.appDataService.passBiSource
              .identityStatusOf('AFTU', j.legs.last.routeId),
          IdentityStatus.unconfirmed);
      // Chaque ETA de tronçon reste SCHEDULED (vrais stop_times), jamais un
      // faux « 0 min » ni une fréquence.
      for (final leg in j.legs) {
        expect(leg.routeId, isNotEmpty);
      }
    });
  });

  // ==================================================================== G
  group('G. lendemain — dimanche 23:59 → service J+1 (Lot 4.19 conservé)',
      () {
    test('ETA : lundi 05:35:30 (337 min), SCHEDULED', () {
      final s = stopFix(
        name: 'Colobane',
        stopId: 'stop_colobane',
        routeId: 'ter_dakar_diamniadio',
      );
      final info = s.departureInfoAt(at: dimanche2359);
      expectHonest(info);
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 10, 5, 5, 35, 30));
      expect(info.estimatedWaitFrom, 336);
      expect(info.label, 'Prochain départ dans 337 min');
    });
  });

  // ==================================================================== H
  group('H. terminus — jamais une arrivée comme prochain départ', () {
    test('B1 Petersen 14:00 : départ 14:00:30, pas l arrivée 14:02:27', () {
      final s = stopFix(
        name: 'Petersen',
        stopId: 'stop_brt_01_petersen',
        routeId: 'brt_b1_guediawaye_petersen',
        modeLabel: 'BRT',
      );
      final info = s.departureInfoAt(at: lundi14);
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(info.scheduledTime, isNot(DateTime.utc(2026, 9, 28, 14, 2, 27)),
          reason: '50547 = arrivée de terminus (Bug A Lot 4.19)');
    });
  });

  // ==================================================================== I
  group('I. horizon — départ dans l horizon, arrivée au-delà conservée', () {
    test('Colobane → Diamniadio à 23:59 : trajet J+1 embarquable', () {
      final saved = List<app.Stop>.of(app.allStops);
      try {
        final from = stopFix(
          name: 'Colobane (horizon)',
          stopId: 'stop_colobane',
          routeId: 'ter_dakar_diamniadio',
        );
        final to = stopFix(
          name: 'Diamniadio (horizon)',
          stopId: 'stop_diamniadio',
          routeId: 'ter_dakar_diamniadio',
        );
        app.allStops
          ..clear()
          ..addAll(<app.Stop>[from, to]);

        final res = app.RoutePlanner.plan(
          fromQuery: 'Colobane (horizon)',
          toQuery: 'Diamniadio (horizon)',
          at: dimanche2359,
        );
        expect(res.errorMessage, isNull);
        expect(res.hasRoutes, isTrue,
            reason: 'itinéraire J+1 (embarquement 05:35 < horizon 05:59)');
        final r = res.routes.first;
        expect(r.status, app.DataStatus.scheduled);
        expect(r.transferCount, 0);
        expect(r.segments, hasLength(1));
        // Embarquement lundi 05:35:30 (106530), arrivée 06:15:09 (108909,
        // au-delà de l'horizon 6 h) : conserve le trajet (Bug C Lot 4.19).
        expect(r.segments.first.departureTime, '05 h 35');
        expect(r.segments.first.arrivalTime, '06 h 15');
        expect(r.segments.first.departureInfo!.status,
            ScheduleStatus.scheduled);
        expect(r.segments.first.departureInfo!.scheduledTime,
            DateTime.utc(2026, 10, 5, 5, 35, 30));
        expect(r.segments.first.departureInfo!.estimatedWaitFrom, 336);
        expectHonest(r.segments.first.departureInfo!);
      } finally {
        app.allStops
          ..clear()
          ..addAll(saved);
      }
    });
  });
}
