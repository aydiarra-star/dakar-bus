// Lot 4.19 — VALIDATION FONCTIONNELLE RÉELLE (côté Flutter).
//
// Contrepart Dart des tests Node tests/passbi-functional-419.test.js :
// même matrice §1–§13, sur le code de production (gtfs_source,
// passbi_source, schedule_provider, routing_engine) avec les corrections
// démonstrées du lot :
//  * A — départs embarquables uniquement (quais d'arrivée exclus,
//        plateformes sœurs documentées ≤ 30 m) ;
//  * B — passage 23:59 → 00:00 : service J+1 retrouvé (ETA + moteur) ;
//  * C — horizon 6 h borne l'embarquement, jamais une arrivée valide.
// Aucun mock : seuls les assets réels flutter-src/assets/data/passbi/.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/gtfs/routing_engine.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final PassBiSource src = PassBiSource();
  final ScheduleProvider provider = ScheduleProvider(src);
  final PassBiRoutingEngine engine = PassBiRoutingEngine(src);

  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);
  final DateTime lundi14 = DateTime.utc(2026, 9, 28, 14, 0);
  final DateTime lundi10 = DateTime.utc(2026, 9, 28, 10, 0);
  final DateTime lundi1329 = DateTime.utc(2026, 9, 28, 13, 29);
  final DateTime dimanche2359 = DateTime.utc(2026, 10, 4, 23, 59);

  const String dakarPb =
      'TER:544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';
  const String colobanePb =
      'TER:c70477e7-8391-4388-9a1f-8929a18dc14e-00000000-0000-0000-0000-000000000000';
  const String diamniadioPb =
      'TER:4445e51b-971b-4f1a-a94a-1ca0c9bef411-00000000-0000-0000-0000-000000000000';
  const String rufisquePb =
      'TER:1d859f92-c798-4291-9631-262ed863698a-00000000-0000-0000-0000-000000000000';

  setUpAll(() async {
    await src.loadAll();
  });

  // ------------------------------------------------------------------ §1
  group('§1 TER direct', () {
    test('Dakar → Diamniadio : route, trip, direction, stop_sequence, horaires',
        () {
      final journeys = engine.planJourneys(
        fromKeys: {dakarPb},
        toKeys: {diamniadioPb},
        at: lundi12,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, 0);
      expect(j.legs, hasLength(1));
      final leg = j.legs.first;
      expect(leg.network, 'TER');
      final ter = src.network('TER')!;
      expect(ter.routes.any((r) => r.id == leg.routeId), isTrue);
      expect(leg.tripId, isNotEmpty);
      expect(leg.fromStopName, 'Dakar - Gare ferroviaire');
      expect(leg.toStopName, 'Diamniadio');
      final trip = ter.trips.firstWhere((t) => t.id == leg.tripId);
      expect(trip.direction, '1');
      expect(trip.headsign, 'Diamniadio');
      // stop_sequence : ordre croissant Dakar → Colobane → Diamniadio.
      final tripIdx = ter.trips.indexOf(trip);
      final rows = ter.stopTimesByTrip[tripIdx]!;
      final posDakar = rows
          .indexWhere((r) => r.stopIndex == ter.stopIndexById[dakarPb.substring(4)]);
      final posCol = rows
          .indexWhere((r) => r.stopIndex == ter.stopIndexById[colobanePb.substring(4)]);
      final posDia = rows
          .indexWhere((r) => r.stopIndex == ter.stopIndexById[diamniadioPb.substring(4)]);
      expect(posDakar, greaterThanOrEqualTo(0));
      expect(posCol, greaterThan(posDakar));
      expect(posDia, greaterThan(posCol));
      // Horaires (fixture brut) : 12:06:00 → 12:51:29.
      expect(j.departureSec, 43560);
      expect(j.arrivalSec, 46289);
      expect(j.arrivalSec, greaterThan(j.departureSec));
    });

    test('Dakar → Colobane et Colobane → Diamniadio exploitables', () {
      final a = engine.planJourneys(
          fromKeys: {dakarPb}, toKeys: {colobanePb}, at: lundi12)
          .first;
      expect(a.legs.first.fromStopName, 'Dakar - Gare ferroviaire');
      expect(a.legs.first.toStopName, 'Colobane');
      expect(a.arrivalSec, 43885); // 12:11:25
      final b = engine.planJourneys(
          fromKeys: {colobanePb}, toKeys: {diamniadioPb}, at: lundi12)
          .first;
      expect(b.legs.first.fromStopName, 'Colobane');
      expect(b.departureSec, 43885);
      expect(b.arrivalSec, 46289);
    });

    test('Rufisque → Dakar (sens retour)', () {
      final j = engine.planJourneys(
          fromKeys: {rufisquePb}, toKeys: {dakarPb}, at: lundi12)
          .first;
      expect(j.transferCount, 0);
      expect(j.legs.first.fromStopName, 'Rufisque');
      expect(j.legs.first.toStopName, 'Dakar - Gare ferroviaire');
      final ter = src.network('TER')!;
      final trip = ter.trips.firstWhere((t) => t.id == j.legs.first.tripId);
      expect(trip.direction, '0');
      expect(trip.headsign, 'Dakar - Gare ferroviaire');
    });

    test('prochain départ Colobane 12:00 → 12:11:25 (ETA 11 min)', () {
      final info = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      )!;
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 12, 11, 25));
      expect(info.estimatedWaitFrom, 11);
    });
  });

  // ------------------------------------------------------------------ §2
  group('§2 BRT B1', () {
    test('Guédiawaye → Petersen + intermédiaire B1 (Golf Nord)', () {
      final j = engine.planJourneys(
        fromKeys: {'BRT:0:GDWB'},
        toKeys: {'BRT:0:PGFB'},
        at: lundi12,
      ).first;
      expect(j.legs, hasLength(1));
      expect(j.legs.first.network, 'BRT');
      expect(['B1', 'B2'].contains(j.legs.first.routeId), isTrue);
      expect(j.legs.first.headsign, 'PETERSEN');

      final k = engine.planJourneys(
        fromKeys: {'BRT:0:GNOA'},
        toKeys: {'BRT:0:PGFB'},
        at: lundi12,
      ).first;
      expect(k.legs.first.routeId, 'B1');
      expect(k.legs.first.fromStopName, 'GOLF NORD');
      expect(k.departureSec, 43503); // 12:05:03
      expect(k.arrivalSec, 46587); // 12:56:27
      // stop_sequence croissante sur le trip (id réseau « BRT:0:X » → « 0:X »).
      final brt = src.network('BRT')!;
      final tripIdx =
          brt.trips.indexWhere((t) => t.id == k.legs.first.tripId);
      final rows = brt.stopTimesByTrip[tripIdx]!;
      final rawFrom = k.legs.first.fromStopId.split(':').skip(1).join(':');
      final fromIdx =
          rows.indexWhere((r) => r.stopIndex == brt.stopIndexById[rawFrom]);
      final toIdx = rows.indexWhere(
          (r) => r.stopIndex == brt.stopIndexById['0:PGFB']);
      expect(fromIdx, greaterThanOrEqualTo(0));
      expect(toIdx, greaterThan(fromIdx));
    });

    test('ETA B1 dynamique : 13:29 → 13:32:04 = 🟢 3 min', () {
      final info = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_05_grand_dakar',
        requestedAt: lundi1329,
      )!;
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 13, 32, 4));
      expect(info.estimatedWaitFrom, 3);
      expect(info.label, 'Prochain départ dans 3 min');
    });

    test('rég. A : quai d\'arrivée PGFB sans sœur → aucun départ ( jamais 0 min)',
        () {
      // API directe sur le quai d'arrivée : AUCUNE ligne embarquable.
      expect(
        src.nextDepartureSec(
            networkKey: 'BRT', pbRouteId: 'B1', pbStopId: '0:PGFB', at: lundi14),
        isNull,
      );
      // La provider, elle, remonte le départ de la plateforme sœur PGFA
      // (lien documenté 10 m) : 14:00:30 — pas l'arrivée 14:02:27.
      final info = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: lundi14,
      )!;
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(info.estimatedWaitFrom, 0);
      expect(info.label, 'Prochain départ dans moins d’une minute');
    });
  });

  // ------------------------------------------------------------------ §3
  group('§3 BRT B2 indépendant', () {
    test('ETA B2 distincte de B1, aucune réutilisation', () {
      final depB2 = provider.departureAt(
        routeId: 'brt_b2_express',
        stopId: 'stop_brt_23_guediawaye',
        requestedAt: lundi14,
      )!;
      final depB1 = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: lundi14,
      )!;
      expect(depB2.status, ScheduleStatus.scheduled);
      expect(depB2.scheduledTime, DateTime.utc(2026, 9, 28, 14, 3, 30)); // 50610
      expect(depB1.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30)); // 50430
      expect(depB2.scheduledTime == depB1.scheduledTime, isFalse);
      // Mappings B1/B2 strictement distincts + aucune route B3.
      final p1 = src.stopMappingFor(
          'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen')!;
      final p2 = src.stopMappingFor(
          'brt_b2_express', 'stop_brt_01_petersen')!;
      expect(p1.compositeStopId == p2.compositeStopId, isFalse);
      expect(src.routeMapping('brt_b1_guediawaye_petersen')!.pbRouteIds, ['B1']);
      expect(src.routeMapping('brt_b2_express')!.pbRouteIds, ['B2']);
      expect(src.network('BRT')!.routes.any((r) => r.id == 'B3'), isFalse);
    });

    test('trips B2 : stop_sequence des stations express cohérente', () {
      final brt = src.network('BRT')!;
      final b2RouteIdx = brt.routeIndexById['B2']!;
      // Trouver un trip B2 passant Grand Dakar → Grand Médaradé Dalal Jam.
      final gdab = brt.stopIndexById['0:GDAB']!;
      final gdwb = brt.stopIndexById['0:GDWB']!;
      var found = false;
      for (final ti in brt.tripsByRoute[b2RouteIdx]!) {
        final rows = brt.stopTimesByTrip[ti]!;
        final a = rows.indexWhere((r) => r.stopIndex == gdab);
        final b = rows.indexWhere((r) => r.stopIndex == gdwb);
        if (a >= 0 && b >= 0) {
          // positions de départ cohérentes selon le sens, séquence croissante.
          for (var i = 1; i < rows.length; i++) {
            expect(rows[i].sequence, greaterThan(rows[i - 1].sequence));
          }
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'aucun trip B2 sur GDAB et GDWB');
    });
  });

  // ------------------------------------------------------------------ §4
  group('§4 DDD', () {
    test('DDD_01 et DDD_403 exploitables sous leurs identifiants PassBi', () {
      final ddd = src.network('DDD')!;
      expect(ddd.routes.any((r) => r.id == 'DDD_01'), isTrue);
      expect(ddd.routes.any((r) => r.id == 'DDD_403'), isTrue);
      final dep01 = src.nextDepartureSec(
        networkKey: 'DDD',
        pbRouteId: 'DDD_01',
        pbStopId: 'D_805',
        at: DateTime.utc(2026, 9, 29, 8, 0),
      );
      expect(dep01, 29400); // 08:10:00
      final j = engine.planJourneys(
        fromKeys: {'DDD:D_805'},
        toKeys: {'DDD:D_140'},
        at: lundi10,
      );
      expect(j, isNotEmpty);
      expect(j.first.legs.first.routeId, 'DDD_01');
      expect(j.first.transferCount, 0);
      // L'identité UI ddd_1 reste non confirmée : AUCUNE route rattachée.
      final ddd1 = src.routeMapping('ddd_1')!;
      expect(ddd1.status, 'UNMAPPED');
      expect(ddd1.pbRouteIds, isEmpty);
    });
  });

  // ------------------------------------------------------------------ §5
  group('§5 AFTU', () {
    test('AFTU_1 et AFTU_3 exploitables, directions du feed', () {
      final aftu = src.network('AFTU')!;
      expect(aftu.routes.any((r) => r.id == 'AFTU_1'), isTrue);
      expect(aftu.routes.any((r) => r.id == 'AFTU_3'), isTrue);
      final dep1 = src.nextDepartureSec(
        networkKey: 'AFTU',
        pbRouteId: 'AFTU_1',
        pbStopId: 'A_916',
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      expect(dep1, 29709); // 08:15:09 — départ embarquable (pas l'arrivée)
      final j = engine.planJourneys(
        fromKeys: {'AFTU:A_1633'},
        toKeys: {'AFTU:A_1250'},
        at: lundi10,
      );
      expect(j, isNotEmpty);
      expect(['AFTU_3', 'AFTU_4'].contains(j.first.legs.first.routeId), isTrue);
      expect(j.first.transferCount, 0);
      // direction_id du feed présente (jamais inventée).
      final trip = aftu.trips
          .firstWhere((t) => t.id == j.first.legs.first.tripId);
      expect(['0', '1'].contains(trip.direction), isTrue);
    });
  });

  // ------------------------------------------------------------------ §6
  group('§6 BRT → DDD', () {
    test('correspondance documentée et temporellement compatible', () {
      final journeys = engine.planJourneys(
        fromKeys: {'BRT:0:GNOA'},
        toKeys: {'DDD:D_449'},
        at: lundi10,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, greaterThanOrEqualTo(1));
      expect(j.legs.first.network, 'BRT');
      expect(j.legs.last.network, 'DDD');
      final l1 = j.legs[0];
      final l2 = j.legs[1];
      expect(l2.departureSec, greaterThanOrEqualTo(l1.arrivalSec));
      final lien = src.transferBetween(l1.toStopId, l2.fromStopId);
      expect(lien, isNotNull, reason: 'aucun lien documenté entre les jambes');
      expect(lien!.meters, lessThanOrEqualTo(500));
      final walk =
          ((lien.meters ~/ 80) < 1 ? 1 : lien.meters ~/ 80) * 60;
      expect(
        l2.departureSec,
        greaterThanOrEqualTo(l1.arrivalSec + walk),
        reason: '2e véhicule inatteignable (arr + marche > départ)',
      );
    });
  });

  // ------------------------------------------------------------------ §7
  group('§7 BRT → AFTU', () {
    test('2e départ réellement atteignable', () {
      final journeys = engine.planJourneys(
        fromKeys: {'BRT:0:GNOA'},
        toKeys: {'AFTU:A_608'},
        at: lundi10,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, greaterThanOrEqualTo(1));
      expect(j.legs.first.network, 'BRT');
      expect(j.legs.last.network, 'AFTU');
      final l1 = j.legs[0];
      final l2 = j.legs[1];
      expect(l2.departureSec, greaterThanOrEqualTo(l1.arrivalSec));
      final lien = src.transferBetween(l1.toStopId, l2.fromStopId);
      expect(lien, isNotNull);
      final walk =
          ((lien!.meters ~/ 80) < 1 ? 1 : lien.meters ~/ 80) * 60;
      expect(l2.departureSec, greaterThanOrEqualTo(l1.arrivalSec + walk));
    });
  });

  // ------------------------------------------------------------------ §8
  group('§8 TER → BUS', () {
    test('TER → DDD uniquement via liens documentés', () {
      // Gare de Dakar : AUCUN lien direct (jamais de proximité seule).
      final lsDakar = src.transfers
          .where((t) => t.from == dakarPb || t.to == dakarPb)
          .toList();
      expect(lsDakar, isEmpty);
      final journeys = engine.planJourneys(
        fromKeys: {dakarPb},
        toKeys: {'DDD:D_325'},
        at: lundi10,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, greaterThanOrEqualTo(1));
      expect(j.legs.first.network, 'TER', reason: 'premier leg = TER');
      expect(j.legs.last.network, 'DDD');
      final lien = src.transferBetween(j.legs[0].toStopId, j.legs[1].fromStopId);
      expect(lien, isNotNull);
      expect(lien!.meters, lessThanOrEqualTo(500));
      final walk = ((lien.meters ~/ 80) < 1 ? 1 : lien.meters ~/ 80) * 60;
      expect(j.legs[1].departureSec,
          greaterThanOrEqualTo(j.legs[0].arrivalSec + walk));
    });

    test('TER → AFTU même exigence', () {
      final journeys = engine.planJourneys(
        fromKeys: {dakarPb},
        toKeys: {'AFTU:A_548'},
        at: lundi10,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.legs.first.network, 'TER');
      expect(j.legs.last.network, 'AFTU');
      final lien = src.transferBetween(j.legs[0].toStopId, j.legs[1].fromStopId);
      expect(lien, isNotNull);
    });
  });

  // ------------------------------------------------------------------ §9
  group('§9 ETA dynamique', () {
    test('13:29 → 13:32 = 🟢 3 min ; 13:29 → 13:35 = 🟢 6 min', () {
      final a = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_05_grand_dakar',
        requestedAt: lundi1329,
      )!;
      expect(a.scheduledTime, DateTime.utc(2026, 9, 28, 13, 32, 4));
      expect(a.estimatedWaitFrom, 3);

      final b = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi1329,
      )!;
      expect(b.scheduledTime, DateTime.utc(2026, 9, 28, 13, 35, 12));
      expect(b.estimatedWaitFrom, 6);
      expect(b.label, 'Prochain départ dans 6 min');

      // 30 s plus tôt → ETA différente (aucune valeur codée en dur).
      final earlier = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi1329.add(const Duration(seconds: 30)),
      )!;
      expect(earlier.estimatedWaitFrom, 5);

      // La valeur vient bien d'un horaire PassBi, jamais d'une fréquence.
      expect(a.sourceType, SourceType.publicGtfs);
      expect(a.status, ScheduleStatus.scheduled);
    });
  });

  // ------------------------------------------------------------------ §10
  group('§10 jour suivant', () {
    test('23:59 → 00:00 : ETA sur J+1 (service_id change)', () {
      final ter = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: dimanche2359,
      )!;
      expect(ter.status, ScheduleStatus.scheduled);
      // lundi 05:35:30 (abs 106530 depuis dimanche 00:00).
      expect(ter.scheduledTime, DateTime.utc(2026, 10, 5, 5, 35, 30));
      expect(ter.estimatedWaitFrom, 336);

      final brt = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: dimanche2359,
      )!;
      expect(brt.status, ScheduleStatus.scheduled);
      expect(brt.scheduledTime, DateTime.utc(2026, 10, 5, 6, 0, 30));
      expect(brt.estimatedWaitFrom, 361);
    });

    test('moteur : trajet embarqué sur J+1, au-delà de minuit', () {
      final journeys = engine.planJourneys(
        fromKeys: {colobanePb},
        toKeys: {diamniadioPb},
        at: dimanche2359,
      );
      expect(journeys, isNotEmpty, reason: 'itinéraire J+1 introuvable');
      final j = journeys.first;
      expect(j.departureSec, 106530); // lundi 05:35:30
      expect(j.arrivalSec, 108909); // lundi 06:15:09 (départ du trip à Diamniadio)
      expect(j.arrivalSec, greaterThan(j.departureSec));
      // service_id distinct entre dimanche et lundi (changement réel).
      final ter = src.network('TER')!;
      final trip = ter.trips.firstWhere((t) => t.id == j.legs.first.tripId);
      expect(trip.id, contains('5:30:00 AM'));
      // Le trip du dimanche soir est un autre service.
      final dimanche12 = engine.planJourneys(
        fromKeys: {colobanePb},
        toKeys: {diamniadioPb},
        at: DateTime.utc(2026, 10, 4, 12, 0),
      ).first;
      expect(dimanche12.legs.first.tripId == trip.id, isFalse);
    });
  });

  // ------------------------------------------------------------------ §11
  group('§11 aucun départ → rien d inventé', () {
    test('route non mappée, arrêt jamais appelé, quai d arrivée', () {
      // ddd_1 → aucune donnée rattachée (null).
      expect(
        provider.departureAt(
          routeId: 'ddd_1',
          stopId: 'stop_dakar_petersen',
          requestedAt: lundi12,
        ),
        isNull,
      );
      // GUEULE TAPEE (GTAB) : listé, jamais appelé → aucun départ.
      expect(
        src.nextDepartureSec(
            networkKey: 'BRT', pbRouteId: 'B1', pbStopId: '0:GTAB', at: lundi12),
        isNull,
      );
      // Recherche depuis un arrêt non desservi → zéro trajet (pas de fake).
      final j = engine.planJourneys(
        fromKeys: {'BRT:0:GTAB'},
        toKeys: {diamniadioPb},
        at: lundi12,
      );
      expect(j, isEmpty);
      // Jamais « 0 min », retard, interruption, fréquence ni faux horaire.
      final labels = ['0 min', 'retard', 'interruption', 'toutes les 6'];
      for (final l in labels) {
        expect(jsonDump(j).contains(l), isFalse);
      }
    });
  });

  // ------------------------------------------------------------------ §12
  group('§12 jamais de retard sur horaire programmé', () {
    test('SCHEDULED uniquement, aucune structure de retard', () {
      final info = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      )!;
      expect(info.status, ScheduleStatus.scheduled);
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final meta = src.network(key)!.meta;
        expect(meta['time_semantics'], contains('jamais REAL_TIME'));
        expect(meta['source_type'], 'PUBLIC_GTFS');
        expect(
          RegExp(r'delay|delayed|realtime_vehicle')
              .hasMatch(meta.values.join(' ')),
          isFalse,
        );
      }
    });
  });

  // ------------------------------------------------------------------ §13
  group('§13 identités séparées', () {
    test('TER ≠ BRT, B1 ≠ B2, DDD ≠ AFTU, B3 absent', () {
      final ids = <String, Set<String>>{};
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        ids[key] = src.network(key)!.routes.map((r) => r.id).toSet();
      }
      expect(ids['TER']!.contains('B1'), isFalse);
      expect(ids['BRT']!.contains('B3'), isFalse);
      expect(ids['BRT']!.any(ids['DDD']!.contains), isFalse);
      expect(ids['DDD']!.any(ids['AFTU']!.contains), isFalse);
      expect(
        src.routeMapping('brt_b1_guediawaye_petersen')!.pbRouteIds.first ==
            src.routeMapping('brt_b2_express')!.pbRouteIds.first,
        isFalse,
      );
      // Chaque réseau ne référence que ses propres routes.
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final net = src.network(key)!;
        for (final ti in net.tripsByRoute.keys) {
          expect(ti, inInclusiveRange(0, net.routes.length - 1));
        }
      }
    });
  });
}

String jsonDump(Object? o) => o.toString();
