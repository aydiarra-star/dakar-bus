// Lot 4.21 — EXPLOITATION PASSBI DDD / AFTU / TATA (matrice §11 A–L).
//
// Ces tests portent sur la chaîne RÉELLE :
//   feeds PassBi (assets) → PassBiSource → ScheduleProvider →
//   PassBiRoutingEngine → EtaCalculator → DepartureInfo → Stop / Explorer /
//   RoutePlanner.
//
// Ils vérifient la règle centrale du lot : une identité publique
// `UNCONFIRMED` n'empêche JAMAIS un horaire PassBi techniquement calculable
// (§2, §15), et aucun départ, nom commercial ou réseau TATA n'est inventé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lundi 2026-09-28 (jour ouvré) — convention Dakar = UTC.
  final DateTime lundi10 = DateTime.utc(2026, 9, 28, 10, 0);
  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);
  final DateTime lundi2359 = DateTime.utc(2026, 9, 28, 23, 59);
  final DateTime dimanche10 = DateTime.utc(2026, 10, 4, 10, 0);
  final DateTime dimanche2359 = DateTime.utc(2026, 10, 4, 23, 59);

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi est la source opérationnelle');
    app.integratePassBiNativeStopsForTest();
  });

  /// Garde-fous communs : jamais REAL_TIME, jamais 0 min, jamais une fréquence
  /// présentée comme un départ.
  void expectHonest(DepartureInfo info) {
    expect(info.status, isNot(ScheduleStatus.realTime));
    expect(app.departureDataStatus(info.status), isNot(app.DataStatus.live));
    expect(info.label, isNot('Prochain départ dans 0 min'));
    expect(info.label.toLowerCase(), isNot(contains('live')));
    if (info.status == ScheduleStatus.scheduled) {
      expect(info.scheduledTime, isNotNull);
      expect(info.frequencyMinutes, isNull,
          reason: 'une fréquence n\'est jamais un départ');
      expect(info.label, startsWith('Prochain départ dans'));
    } else {
      expect(info.scheduledTime, isNull);
      expect(info.unresolvedReason, isNotNull,
          reason: 'tout UNKNOWN porte sa raison précise (§15)');
    }
  }

  /// Premier arrêt réellement desservi par une route du feed.
  String firstStopOf(String networkKey, String routeId) {
    final net = app.appDataService.passBiSource.network(networkKey)!;
    final routeIndex = net.routeIndexById[routeId]!;
    for (int ti = 0; ti < net.trips.length; ti++) {
      if (net.trips[ti].routeIndex != routeIndex) continue;
      final rows = net.stopTimesByTrip[ti];
      if (rows == null || rows.isEmpty) continue;
      return net.stops[rows.first.stopIndex].id;
    }
    throw StateError('route $networkKey/$routeId sans arrêt');
  }

  // ==================================================================== A
  group('A — DDD : prochain départ PassBi calculable', () {
    test('route DDD_01 à son premier arrêt : SCHEDULED + PUBLIC_GTFS', () {
      final stopId = firstStopOf('DDD', 'DDD_01');
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: stopId,
        pbRouteId: 'DDD_01',
        at: lundi12,
      );
      expectHonest(info);
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.routeId, 'DDD_01');
      expect(info.sourceType, SourceType.publicGtfs);
      expect(info.operator, contains('Dakar Dem Dikk'));
      expect(info.scheduledTime!.isBefore(lundi12.add(const Duration(hours: 3))),
          isTrue);
      expect(info.estimatedWaitFrom, greaterThanOrEqualTo(0));
      // Identité publique NON confirmée (§3) : champ DISTINCT du statut horaire.
      expect(info.identityStatus, IdentityStatus.unconfirmed);
      expect(info.identityNote, contains('UNCONFIRMED'));
      // §2 : l'affichage vient des métadonnées PassBi réelles.
      expect(info.lineLabel, startsWith('Ligne PassBi DDD_01'));
    });

    test('audit §1 : 53 routes DDD, 52 avec horaires calculables', () {
      final summaries = app.appDataService.passBiRouteSummaries('DDD');
      expect(summaries, hasLength(53));
      expect(summaries.where((s) => s.scheduleAvailable), hasLength(52));
      final sans = summaries.where((s) => !s.scheduleAvailable).toList();
      expect(sans.map((s) => s.routeId), <String>['DDD_323']);
      expect(sans.single.trips, 288, reason: 'DDD_323 a des trips');
      expect(sans.single.stopTimes, 0, reason: '… mais aucun stop_time');
      expect(sans.single.reason, UnresolvedReason.noStopTimesInFeed);
      for (final s in summaries) {
        expect(s.network, 'DDD');
        expect(s.shortName, isNotEmpty);
        expect(s.longName, isNotEmpty);
        expect(s.identityStatus, IdentityStatus.unconfirmed,
            reason: '${s.routeId} : aucune identité DDD n\'est confirmée');
        expect(s.dakarRouteIds, isEmpty,
            reason: '${s.routeId} : aucune identité n\'est déduite');
        expect(s.scheduleAvailable, s.boardableStopTimes > 0);
      }
    });

    test('§7 : le filtre DDD de l\'Explorer renvoie des arrêts PassBi exploitables',
        () {
      final source = app.explorerStopSource(
        selectedFilter: 'DDD',
        dakarStops: app.allStops,
        passBiStops: app.passBiNativeStops,
      );
      final ddd = app.explorerBaseStopsForFilter(
        selectedFilter: 'DDD',
        favoriteStopNames: const <String>{},
        source: source,
      );
      final natifs = ddd.where((s) => s.passBiStopKey != null).toList();
      expect(natifs, isNotEmpty,
          reason: 'le filtre DDD doit exposer les arrêts PassBi DDD réels');
      expect(ddd.every((s) => s.color == app.AppColors.ddd), isTrue);
      // Un de ces arrêts calcule un vrai prochain départ.
      final avecDepart = natifs
          .map((s) => s.departureInfoAt(at: lundi12))
          .where((i) => i.status == ScheduleStatus.scheduled)
          .toList();
      expect(avecDepart, isNotEmpty,
          reason: 'les arrêts DDD PassBi exposés doivent produire des départs');
      for (final info in avecDepart) {
        expectHonest(info);
        expect(info.lineLabel, startsWith('Ligne PassBi DDD_'));
      }
    });

    test('§7 : les autres filtres restent strictement sur le référentiel dakar',
        () {
      for (final filtre in <String>['Tous', 'TER', 'BRT', 'TATA', '⭐ Favoris']) {
        expect(
          app.explorerStopSource(
            selectedFilter: filtre,
            dakarStops: app.allStops,
            passBiStops: app.passBiNativeStops,
          ),
          same(app.allStops),
          reason: 'filtre « $filtre » : aucun arrêt natif ajouté',
        );
      }
      expect(
        app.passBiNativeStops.any((s) => app.allStops.contains(s)),
        isFalse,
        reason: 'allStops reste le référentiel dakar (aucune pollution)',
      );
    });
  });

  // ==================================================================== B
  group('B — AFTU : prochain départ PassBi calculable', () {
    test('route AFTU_3 : SCHEDULED, identité CONFIRMED (crosswalk)', () {
      final stopId = firstStopOf('AFTU', 'AFTU_3');
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'AFTU',
        pbStopId: stopId,
        pbRouteId: 'AFTU_3',
        at: lundi10,
      );
      expectHonest(info);
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.routeId, 'AFTU_3');
      expect(info.sourceType, SourceType.publicGtfs);
      // AFTU_3 est rattachée par le crosswalk (aftu_8, aftu_11).
      expect(info.identityStatus, IdentityStatus.confirmed);
      expect(info.lineLabel, 'AFTU_3');
    });

    test('audit §1 : 73 routes AFTU, 71 avec horaires calculables', () {
      final summaries = app.appDataService.passBiRouteSummaries('AFTU');
      expect(summaries, hasLength(73));
      expect(summaries.where((s) => s.scheduleAvailable), hasLength(71));
      final sans = summaries.where((s) => !s.scheduleAvailable).toList();
      expect(sans.map((s) => s.routeId).toList()..sort(),
          <String>['AFTU_47', 'AFTU_52']);
      final confirmes =
          summaries.where((s) => s.identityStatus == IdentityStatus.confirmed).toList();
      expect(confirmes.map((s) => s.routeId), <String>['AFTU_3']);
      expect(confirmes.single.dakarRouteIds.toSet(), <String>{'aftu_8', 'aftu_11'});
    });

    test('§7 : le filtre AFTU expose les arrêts PassBi AFTU réels', () {
      final source = app.explorerStopSource(
        selectedFilter: 'AFTU',
        dakarStops: app.allStops,
        passBiStops: app.passBiNativeStops,
      );
      final aftu = app.explorerBaseStopsForFilter(
        selectedFilter: 'AFTU',
        favoriteStopNames: const <String>{},
        source: source,
      );
      final natifs = aftu.where((s) => s.passBiStopKey != null).toList();
      expect(natifs, isNotEmpty);
      expect(aftu.every((s) => s.color == app.AppColors.aftu), isTrue);
    });

    test('arrêt natif : nom et coordonnées viennent du feed (§2)', () {
      final refs = app.appDataService.passBiNativeStops('AFTU');
      expect(refs, hasLength(2237));
      final ref = refs.first;
      final stop = app.passBiNativeStops
          .firstWhere((s) => s.passBiStopKey == ref.compositeKey);
      expect(stop.name, ref.name);
      expect(stop.location.latitude, ref.lat);
      expect(stop.location.longitude, ref.lon);
      expect(stop.modeLabel, 'AFTU');
      expect(stop.source, app.DataSourceInfo.passbiGtfs);
      expect(stop.stopId, isNull,
          reason: 'un arrêt PassBi n\'est pas un arrêt dakar_network');
      expect(stop.direction, contains('PassBi AFTU'));
      // Aucune identité de ligne dakar ne lui est attribuée.
      expect(app.DetailedRoute.fromStop(stop), isNull);
    });
  });

  // ==================================================================== C
  group('C — DDD sans départ calculable → UNKNOWN motivé', () {
    test('arrêt inconnu du feed', () {
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: 'D_INEXISTANT',
        at: lundi12,
      );
      expectHonest(info);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.unresolvedReason, UnresolvedReason.noComputableDeparture);
    });

    test('route sans stop_time (DDD_323) → AUCUN_STOP_TIME_DANS_LE_FEED', () {
      final stopId = app.appDataService.passBiNativeStops('DDD').first.stopId;
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: stopId,
        pbRouteId: 'DDD_323',
        at: lundi12,
      );
      expectHonest(info);
      expect(info.status, ScheduleStatus.unknown);
      expect(info.unresolvedReason, UnresolvedReason.noStopTimesInFeed);
    });

    test('l\'UNKNOWN dakar reste motivé par l\'identité, pas par la donnée', () {
      // `ddd_1` : identité dakar non confirmée → aucun horaire ne lui est
      // attribué (aucune identité n'est déduite d'un numéro). La donnée PassBi
      // DDD est pourtant disponible et exploitée par le chemin natif.
      final info = app.appDataService.departureFor(
        routeId: 'ddd_1',
        stopId: 'stop_colobane',
        network: 'DDD',
        at: lundi12,
      );
      expect(info.status, ScheduleStatus.unknown);
      expect(info.label, 'Horaire indisponible');
      expect(info.unresolvedReason, UnresolvedReason.identityUnconfirmed);
      expect(info.frequencyMinutes, isNull);
    });
  });

  // ==================================================================== D
  group('D — AFTU sans départ calculable → UNKNOWN motivé', () {
    test('arrêt inconnu / route sans données', () {
      final inconnu = app.appDataService.passBiDepartureFor(
        networkKey: 'AFTU',
        pbStopId: 'A_INEXISTANT',
        at: lundi12,
      );
      expect(inconnu.status, ScheduleStatus.unknown);
      expect(inconnu.unresolvedReason, UnresolvedReason.noComputableDeparture);

      final stopId = app.appDataService.passBiNativeStops('AFTU').first.stopId;
      final sansHoraire = app.appDataService.passBiDepartureFor(
        networkKey: 'AFTU',
        pbStopId: stopId,
        pbRouteId: 'AFTU_47',
        at: lundi12,
      );
      expect(sansHoraire.status, ScheduleStatus.unknown);
      expect(sansHoraire.unresolvedReason, UnresolvedReason.noStopTimesInFeed);
    });

    test('le feed AFTU est bien AVAILABLE (UNKNOWN ≠ absence de données)', () {
      expect(app.appDataService.passBiNetworkAvailability('AFTU'),
          PassBiNetworkAvailability.available);
      expect(app.appDataService.passBiNetworkAvailability('DDD'),
          PassBiNetworkAvailability.available);
    });
  });

  // ==================================================================== E
  group('E — SCHEDULED ≠ REAL_TIME', () {
    test('aucun chemin DDD/AFTU ne produit REAL_TIME ni DataStatus.live', () {
      final echantillons = <List<String>>[
        for (final ref in app.appDataService.passBiNativeStops('DDD').take(40))
          <String>['DDD', ref.stopId],
        for (final ref in app.appDataService.passBiNativeStops('AFTU').take(40))
          <String>['AFTU', ref.stopId],
      ];
      for (final echantillon in echantillons) {
        final info = app.appDataService.passBiDepartureFor(
          networkKey: echantillon[0],
          pbStopId: echantillon[1],
          at: lundi12,
        );
        expectHonest(info);
        expect(info.status, isNot(ScheduleStatus.realTime));
        expect(app.departureDataStatus(info.status), isNot(app.DataStatus.live));
        if (info.status == ScheduleStatus.scheduled) {
          expect(info.sourceType, SourceType.publicGtfs);
        }
      }
      expect(EtaCalculator.hasRealtimeFeed, isFalse);
    });

    test('les feeds DDD/AFTU déclarent une sémantique SCHEDULED', () {
      for (final key in <String>['DDD', 'AFTU']) {
        final meta = app.appDataService.passBiSource.network(key)!.meta;
        expect(meta['time_semantics'], contains('SCHEDULED'));
        expect(meta['source_type'], 'PUBLIC_GTFS');
      }
    });
  });

  // ==================================================================== F
  group('F — ETA dynamique', () {
    test('le libellé suit l\'heure de la demande (aucune ETA figée)', () {
      final stopId = app.appDataService.passBiNativeStops('DDD')[2].stopId;
      final a = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD',
          pbStopId: stopId,
          at: DateTime.utc(2026, 9, 28, 8, 0));
      final b = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD',
          pbStopId: stopId,
          at: DateTime.utc(2026, 9, 28, 8, 30));
      expect(a.status, ScheduleStatus.scheduled);
      expect(b.status, ScheduleStatus.scheduled);
      expect(a.scheduledTime, isNot(b.scheduledTime));
      expect(a.estimatedWaitFrom, lessThan(180));
      expect(b.estimatedWaitFrom, lessThan(180));
      expect(a.label, a.estimatedWaitFrom == 0
          ? 'Prochain départ dans moins d’une minute'
          : 'Prochain départ dans ${a.estimatedWaitFrom} min');
    });
  });

  // ==================================================================== G
  group('G — changement de jour', () {
    test('23:59 → le service J+1 est retrouvé et daté du lendemain', () {
      DepartureInfo? trouve;
      for (final ref in app.appDataService.passBiNativeStops('DDD').take(400)) {
        final info = app.appDataService.passBiDepartureFor(
            networkKey: 'DDD', pbStopId: ref.stopId, at: lundi2359);
        if (info.status == ScheduleStatus.scheduled &&
            info.scheduledTime!.day == 29) {
          trouve = info;
          break;
        }
      }
      expect(trouve, isNotNull,
          reason: 'un départ J+1 doit être trouvé après le dernier service');
      expect(trouve!.scheduledTime!.day, 29);
      expect(trouve.scheduledTime!.month, 9);
      expect(trouve.scheduledTime!.isAfter(lundi2359), isTrue);
    });

    test('DDD_18 (service LAV) : dimanche → report, lundi → même jour', () {
      final stopId = firstStopOf('DDD', 'DDD_18');
      final dim = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD',
          pbStopId: stopId,
          pbRouteId: 'DDD_18',
          at: dimanche10);
      final lun = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD',
          pbStopId: stopId,
          pbRouteId: 'DDD_18',
          at: lundi10);
      expect(dim.status, ScheduleStatus.scheduled);
      expect(lun.status, ScheduleStatus.scheduled);
      expect(dim.scheduledTime!.day, isNot(4),
          reason: 'aucun service LAV le dimanche 4 octobre');
      expect(lun.scheduledTime!.day, 28,
          reason: 'le lundi, DDD_18 part le jour même');
    });
  });

  // ==================================================================== H
  group('H — terminus : une arrivée n\'est jamais un prochain départ', () {
    test('le départ rendu à un terminus est un stop_time EMBARQUABLE', () {
      final net = app.appDataService.passBiSource.network('DDD')!;
      final routeIndex = net.routeIndexById['DDD_01']!;
      String? terminusStopId;
      int? terminusSequence;
      for (int ti = 0; ti < net.trips.length; ti++) {
        if (net.trips[ti].routeIndex != routeIndex) continue;
        final rows = net.stopTimesByTrip[ti];
        if (rows == null || rows.isEmpty) continue;
        terminusStopId = net.stops[rows.last.stopIndex].id;
        terminusSequence = rows.last.sequence;
        break;
      }
      expect(terminusStopId, isNotNull);
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: terminusStopId!,
        pbRouteId: 'DDD_01',
        at: lundi12,
      );
      expectHonest(info);
      if (info.status == ScheduleStatus.scheduled) {
        final stopIndex = net.stopIndexById[terminusStopId]!;
        final secOfDay =
            info.scheduledTime!.difference(DateTime.utc(2026, 9, 28)).inSeconds %
                86400;
        final rows = (net.stopTimesByStop[stopIndex] ?? const [])
            .where((st) =>
                st.departureSec == secOfDay &&
                net.trips[st.tripIndex].routeIndex == routeIndex)
            .toList();
        expect(rows, isNotEmpty);
        // Au moins une des lignes d'arrêt correspondantes est EMBARQUABLE :
        // l'arrivée du terminus (dernière séquence du trip) n'est jamais
        // retenue comme « prochain départ ».
        final embarqables = rows.where((st) {
          final tripRows = net.stopTimesByTrip[st.tripIndex]!;
          return st.sequence < tripRows.last.sequence;
        }).toList();
        expect(embarqables, isNotEmpty,
            reason: 'l\'arrivée du terminus n\'est pas un départ embarquable');
        expect(embarqables.first.sequence, isNot(terminusSequence));
      }
    });
  });

  // ==================================================================== I
  group('I — horizon d\'embarquement', () {
    test('l\'horizon borne l\'embarquement, pas l\'arrivée', () {
      const int horizonSec = 6 * 3600;
      final departSec = 23 * 3600 + 59 * 60;
      final borne = departSec + horizonSec;

      // Extrémités réelles d\'une même ligne DDD : le premier véhicule du
      // lendemain (05:50) est dans l\'horizon de 6 h (05:59) — l\'embarquement
      // est donc valide, et l\'arrivée (06:39) DÉPASSE l\'horizon sans être
      // tronquée (correction Lot 4.19 C).
      final net = app.appDataService.passBiSource.network('DDD')!;
      final routeIndex = net.routeIndexById['DDD_01']!;
      final rows =
          net.stopTimesByTrip.entries.firstWhere((e) =>
              net.trips[e.key].routeIndex == routeIndex &&
              (e.value.isNotEmpty)).value;
      final origine = net.stops[rows.first.stopIndex].id;
      final destination = net.stops[rows.last.stopIndex].id;
      final js = app.appDataService.planPassBiJourneys(
        fromPassBiKeys: <String>{'DDD:$origine'},
        toPassBiKeys: <String>{'DDD:$destination'},
        at: lundi2359,
        maxResults: 2,
      );
      expect(js, isNotEmpty,
          reason: 'l\'horizon laisse passer le premier véhicule du lendemain');
      final j = js.first;
      expect(j.departureSec, greaterThan(departSec));
      expect(j.departureSec, lessThanOrEqualTo(borne),
          reason: 'l\'embarquement reste dans l\'horizon de 6 h');
      expect(j.arrivalSec, greaterThan(borne),
          reason: 'l\'arrivée au-delà de l\'horizon est conservée (Lot 4.19 C)');
      expect(j.legs.single.network, 'DDD');
      expect(j.legs.single.routeId, 'DDD_01');
    });

    test('cas prouvé Lot 4.19 C : arrivée au-delà de l\'horizon conservée', () {
      final from = app.appDataService.passBiSource
          .stopMappingFor('ter_dakar_diamniadio', 'stop_colobane')!;
      final to = app.appDataService.passBiSource
          .stopMappingFor('ter_dakar_diamniadio', 'stop_diamniadio')!;
      final js = app.appDataService.planPassBiJourneys(
        fromPassBiKeys: <String>{from.compositeStopId},
        toPassBiKeys: <String>{to.compositeStopId},
        at: dimanche2359,
        maxResults: 2,
      );
      expect(js, isNotEmpty,
          reason: 'trajet J+1 embarquable après le dernier service');
      final j = js.first;
      const int departSec = 23 * 3600 + 59 * 60;
      expect(j.departureSec, lessThanOrEqualTo(departSec + 6 * 3600));
      expect(j.arrivalSec, greaterThan(departSec + 6 * 3600),
          reason: 'l\'arrivée n\'est jamais tronquée par l\'horizon (Lot 4.19 C)');
    });
  });

  // ==================================================================== J
  group('J — aucune identité inventée', () {
    test('aucun mapping DDD n\'est fabriqué, aucune identité n\'est déduite', () {
      for (final id in <String>['ddd_1', 'ddd_10', 'ddd_14', 'ddd_3']) {
        final mapping = app.appDataService.passBiSource.routeMapping(id);
        expect(mapping, isNotNull, reason: id);
        expect(mapping!.status, 'UNMAPPED', reason: id);
        expect(mapping.pbRouteIds, isEmpty, reason: id);
      }
      for (final s in app.appDataService.passBiRouteSummaries('DDD')) {
        expect(s.dakarRouteIds, isEmpty,
            reason: '${s.routeId} : aucune identité dakar n\'est devinée');
      }
    });

    test('le libellé d\'identité ne contient aucun nom commercial inventé', () {
      final summaries = app.appDataService.passBiRouteSummaries('DDD');
      for (final s in summaries.take(10)) {
        final label = ScheduleProvider.identityLabelFor(
            'DDD', s.routeId, s.identityStatus,
            shortName: s.shortName);
        expect(label, startsWith('Ligne PassBi ${s.routeId}'));
        expect(label, isNot(contains('DDD Ligne')));
        expect(label, contains(s.shortName));
      }
      // Une identité confirmée garde l'identifiant du feed tel quel.
      expect(
          ScheduleProvider.identityLabelFor(
              'BRT', 'B1', IdentityStatus.confirmed),
          'BRT B1');
    });

    test('§8 : la recherche native est stricte (jamais approchée)', () {
      expect(
          app.appDataService.passBiStopSearch('Terminus Palais 2'), isNotEmpty);
      expect(app.appDataService.passBiStopSearch('Pa'), isEmpty);
      expect(app.appDataService.passBiStopSearch('zzzz introuvable'), isEmpty);
    });
  });

  // ==================================================================== K
  group('K — aucun TATA inventé', () {
    test('aucune donnée PassBi n\'établit un réseau TATA autonome', () {
      expect(app.appDataService.passBiNetworkAvailability('TATA'),
          PassBiNetworkAvailability.absentFromFeed);
      expect(app.appDataService.passBiTataMentions(), isEmpty,
          reason: 'aucune route/mode/vehicle_type/agency « tata » dans les feeds');
      expect(app.appDataService.passBiSource.network('TATA'), isNull);
      expect(PassBiSource.assetFiles.containsKey('TATA'), isFalse);
    });

    test('les identités TATA du référentiel dakar restent UNMAPPED', () {
      final tata =
          app.appDataService.routes.where((r) => r.operatorId == 'tata').toList();
      expect(tata, hasLength(7));
      for (final r in tata) {
        final mapping = app.appDataService.passBiSource.routeMapping(r.id);
        expect(mapping, isNotNull, reason: r.id);
        expect(mapping!.status, 'UNMAPPED', reason: r.id);
        expect(mapping.method, 'RESEAU_ABSENT_DU_FEED', reason: r.id);
        expect(mapping.pbRouteIds, isEmpty, reason: r.id);
      }
    });

    test('aucune route TATA n\'est ajoutée par le référentiel natif', () {
      expect(app.passBiNativeNetworkKeys(), <String>['DDD', 'AFTU']);
      expect(app.passBiNativeStops.any((s) => s.modeLabel == 'TATA'), isFalse);
      expect(
        app.passBiNativeStops.any((s) => s.color == app.AppColors.tata),
        isFalse,
      );
    });

    test('le filtre TATA reste strictement sur le référentiel dakar', () {
      expect(
        app.explorerStopSource(
          selectedFilter: 'TATA',
          dakarStops: app.allStops,
          passBiStops: app.passBiNativeStops,
        ),
        same(app.allStops),
      );
      final tataStops =
          app.allStops.where((s) => s.color == app.AppColors.tata).take(5).toList();
      expect(tataStops, isNotEmpty);
      for (final s in tataStops) {
        final info = s.departureInfoAt(at: lundi12);
        expect(info.status, ScheduleStatus.unknown, reason: s.name);
        expect(info.label, 'Horaire indisponible');
      }
    });
  });

  // ==================================================================== L
  group('L — correspondance DDD/AFTU réellement supportée', () {
    test('le corridor DDD → AFTU produit un trajet moteur', () {
      final js = app.appDataService.planPassBiJourneys(
        fromPassBiKeys: <String>{'DDD:D_708'}, // Terminus Palais 2
        toPassBiKeys: <String>{'AFTU:A_839'}, // Gare TER Keur Mbaye Fall
        at: DateTime.utc(2026, 9, 28, 7, 30),
        maxResults: 4,
      );
      expect(js, isNotEmpty, reason: 'corridor DDD → AFTU exploitable (§10)');
      final j = js.first;
      expect(j.legs.last.network, 'AFTU');
      expect(j.legs.any((l) => l.network == 'DDD'), isTrue);
      // Chaque transition repose sur un arrêt partagé ou un lien documenté.
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
    });

    test('chaque lien DDD↔AFTU est borné et documenté', () {
      final liens = app.appDataService.passBiSource.transfers.where((t) {
        final a = t.from.split(':').first;
        final b = t.to.split(':').first;
        return (a == 'DDD' && b == 'AFTU') || (a == 'AFTU' && b == 'DDD');
      }).toList();
      expect(liens.length, greaterThanOrEqualTo(700));
      for (final t in liens) {
        expect(t.meters, lessThanOrEqualTo(500));
        expect(t.method, isNotEmpty);
        expect(t.confidence, isNotEmpty);
      }
    });
  });

  // ============================================================ §1 / §15
  group('§1 — audit reproductible et raisons d\'UNKNOWN', () {
    test('le tableau d\'audit couvre les quatre feeds', () {
      final audit = app.appDataService.passBiAudit();
      expect(audit.where((s) => s.network == 'TER'), hasLength(6));
      expect(audit.where((s) => s.network == 'BRT'), hasLength(2));
      expect(audit.where((s) => s.network == 'DDD'), hasLength(53));
      expect(audit.where((s) => s.network == 'AFTU'), hasLength(73));
      for (final s in audit) {
        expect(s.scheduleAvailable, s.boardableStopTimes > 0, reason: s.routeId);
        expect(s.reason, isNotEmpty);
      }
    });

    test('§15 : chaque UNKNOWN restant porte une raison distincte', () {
      final raisons = <String>{
        UnresolvedReason.networkAbsentFromFeed,
        UnresolvedReason.identityUnconfirmed,
        UnresolvedReason.stopNotMatched,
        UnresolvedReason.noComputableDeparture,
        UnresolvedReason.noStopTimesInFeed,
        UnresolvedReason.sourceInactive,
      };
      expect(raisons, hasLength(6));
      // « identité non confirmée » et « aucun départ » sont deux champs
      // distincts (§3) : une identité UNCONFIRMED peut porter SCHEDULED.
      final stopId = firstStopOf('DDD', 'DDD_01');
      final info = app.appDataService.passBiDepartureFor(
          networkKey: 'DDD', pbStopId: stopId, pbRouteId: 'DDD_01', at: lundi12);
      expect(info.identityStatus, IdentityStatus.unconfirmed);
      expect(info.status, ScheduleStatus.scheduled);
    });

    test('les arrêts natifs couvrent les arrêts réellement desservis', () {
      expect(app.appDataService.passBiNativeStops('DDD'), hasLength(1186));
      expect(app.appDataService.passBiNativeStops('AFTU'), hasLength(2237));
      for (final ref in app.appDataService.passBiNativeStops('DDD').take(50)) {
        expect(ref.routeCount, greaterThan(0));
        expect(ref.name.isNotEmpty, isTrue);
      }
    });
  });

  // ============================================================ §8 Trajets
  group('§8 — RoutePlanner : DDD/AFTU utilisables comme moyens de transport', () {
    test('le second essai natif produit un itinéraire DDD → AFTU réel', () {
      final saved = List<app.Stop>.of(app.allStops);
      try {
        final from = app.Stop(
          name: 'Terminus Palais 2',
          direction: 'Dir. test',
          distanceMeters: 0,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus,
          color: app.AppColors.ddd,
          location: const LatLng(14.67, -17.44),
          modeLabel: 'DDD',
        );
        final to = app.Stop(
          name: 'Gare Ter Keur Mbaye Fall',
          direction: 'Dir. test',
          distanceMeters: 0,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus,
          color: app.AppColors.aftu,
          location: const LatLng(14.77, -17.39),
          modeLabel: 'AFTU',
        );
        app.allStops
          ..clear()
          ..addAll(<app.Stop>[from, to]);

        final res = app.RoutePlanner.plan(
          fromQuery: 'Terminus Palais 2',
          toQuery: 'Gare Ter Keur Mbaye Fall',
          at: DateTime.utc(2026, 9, 28, 7, 30),
        );
        expect(res.hasRoutes, isTrue,
            reason: 'le référentiel natif PassBi doit fournir un itinéraire');

        // Le tronçon moteur (SCHEDULED par tronçon) est celui du référentiel
        // natif : le repli legacy ne produit ni identifiant de ligne PassBi
        // ni horaire programmé.
        final moteur = res.routes.where((r) =>
            r.segments.isNotEmpty &&
            r.segments.every((seg) =>
                seg.departureInfo != null &&
                seg.departureInfo!.status == ScheduleStatus.scheduled));
        expect(moteur, isNotEmpty,
            reason: 'chaque tronçon porte son ETA SCHEDULED du moteur');
        final r = moteur.first;
        for (final seg in r.segments) {
          expect(app.departureDataStatus(seg.departureInfo!.status),
              isNot(app.DataStatus.live));
          expect(seg.departureTime, isNotNull);
          expect(seg.arrivalTime, isNotNull);
          // L'identité de ligne reste un identifiant PassBi réel.
          expect(seg.modeLabel, matches(RegExp(r'^(DDD|AFTU|TER|BRT)(_|$)')));
        }
        expect(r.segments.first.modeLabel, startsWith('DDD'));
        expect(r.segments.last.modeLabel, startsWith('AFTU'));
      } finally {
        app.allStops
          ..clear()
          ..addAll(saved);
      }
    });
  });

  // ============================================================ UI (widget)
  group('UI — un arrêt natif PassBi affiche un départ réel', () {
    testWidgets('StopCard : identité PassBi + ETA SCHEDULED, jamais « 0 min »',
        (WidgetTester tester) async {
      // Un arrêt natif dont le prochain départ est calculable — vérifié aussi
      // à l'instant réel du rendu (StopCard interroge l'horloge).
      app.Stop? cible;
      for (final s in app.passBiNativeStops.take(200)) {
        if (s.departureInfoAt(at: lundi12).status == ScheduleStatus.scheduled &&
            s.departureInfo.status == ScheduleStatus.scheduled) {
          cible = s;
          break;
        }
      }
      expect(cible, isNotNull,
          reason: 'au moins un arrêt natif expose un départ');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: app.StopCard(stop: cible!, distanceMeters: 250)),
      ));
      await tester.pump();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
      expect(texts.any((t) => t.startsWith('Ligne PassBi DDD_')), isTrue,
          reason: 'identité d\'affichage PassBi (§2) : $texts');
      expect(texts.any((t) => t.contains('Prochain départ dans')), isTrue,
          reason: 'labels: $texts');
      expect(texts.any((t) => t.contains('Prochain départ dans 0 min')), isFalse);
      expect(texts.any((t) => t.toLowerCase().contains('live')), isFalse);
      expect(texts.any((t) => t == 'Horaire indisponible'), isFalse);
    });
  });
}
