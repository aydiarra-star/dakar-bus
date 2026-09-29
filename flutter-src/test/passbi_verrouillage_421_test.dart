// Lot 4.21 (suite) — VERROUILLAGE : identité publique ≠ horaire ≠ correspondance.
//
// Trois séparations scellées par des tests :
//   1. disponibilité réelle des horaires PassBi (trips + stop_times réels) ;
//   2. identité publique CONFIRMED uniquement avec preuve documentaire —
//      jamais par numéro, route_id, nom similaire, OSM, proximité ou terminus
//      proches (TERMINI_MATCH reste une hypothèse NON confirmée) ; plusieurs
//      lignes publiques pointant vers un même identifiant PassBi ne sont
//      JAMAIS fusionnées automatiquement ;
//   3. correspondances intermodales réellement documentées — même arrêt
//      physique desservi OU lien crosswalk à nom vérifié ; AUCUNE
//      correspondance par proximité seule ; TATA : zéro correspondance.
//
// Garde-fous : TER/BRT (IDENTITY_OFFICIELLE) inchangés ; aucun TATA fabriqué ;
// aucune fréquence convertie en horaire individuel ; countdown dynamique.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/gtfs/routing_engine.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime lundi10 = DateTime.utc(2026, 9, 28, 10, 0);
  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);

  // Gare Dakar TER (clé composite réelle du crosswalk).
  const String cDakar =
      'TER:544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi est la source opérationnelle');
  });

  /// Invariant de correspondance : toute transition de tronçon repose sur un
  /// arrêt PARTAGÉ ou un lien documenté du crosswalk — jamais une proximité,
  /// jamais une identité publique.
  void expectTransitionsDocumentees(List<PassBiJourney> js, String contexte) {
    for (final j in js) {
      for (int i = 1; i < j.legs.length; i++) {
        final prec = j.legs[i - 1];
        final suiv = j.legs[i];
        final partage = prec.toStopId == suiv.fromStopId;
        final lien = app.appDataService.passBiSource
            .transferBetween(prec.toStopId, suiv.fromStopId);
        expect(partage || lien != null, isTrue,
            reason: '$contexte : correspondance non documentée '
                '${prec.toStopId} → ${suiv.fromStopId}');
      }
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

  // ============================================================ 1. TATA
  group('1 — TATA : aucun feed, aucune route, aucune identité, aucune '
      'correspondance', () {
    test('1a. aucun feed TATA : AUCUNE route TATA fabriquée (anti-fabrication)',
        () {
      expect(PassBiSource.assetFiles.containsKey('TATA'), isFalse);
      expect(PassBiSource.assetFiles.keys.toList()..sort(),
          <String>['AFTU', 'BRT', 'DDD', 'TER']);
      expect(app.appDataService.passBiSource.network('TATA'), isNull);
      expect(app.appDataService.passBiNetworkAvailability('TATA'),
          PassBiNetworkAvailability.absentFromFeed);
      expect(app.appDataService.passBiTataMentions(), isEmpty,
          reason: 'aucune donnée PassBi ne mentionne « tata »');
      expect(app.appDataService.passBiRouteSummaries('TATA'), isEmpty);
      expect(app.appDataService.passBiNativeStops('TATA'), isEmpty);

      // Les identités TATA du référentiel dakar restent UNKNOWN : aucune
      // route, aucun rattachement, réseau absent du feed.
      final tata = app.appDataService.routes
          .where((r) => r.operatorId == 'tata')
          .toList();
      expect(tata, hasLength(7));
      for (final r in tata) {
        final m = app.appDataService.passBiSource.routeMapping(r.id);
        expect(m, isNotNull, reason: r.id);
        expect(m!.status, 'UNMAPPED', reason: r.id);
        expect(m.method, 'RESEAU_ABSENT_DU_FEED', reason: r.id);
        expect(m.network, isNull, reason: r.id);
        expect(m.pbRouteIds, isEmpty, reason: '${r.id} : route TATA fabriquée');
        expect(m.isMapped, isFalse, reason: r.id);
      }
    });

    test('1b. TATA → tout réseau : ZÉRO correspondance', () {
      // Aucun lien de transfert n'implique TATA (les clés hors feeds sont
      // rejetées par TransferLink.isDocumented).
      for (final t in app.appDataService.passBiSource.transfers) {
        final a = PassBiSource.splitComposite(t.from)!;
        final b = PassBiSource.splitComposite(t.to)!;
        expect(a[0], isNot('TATA'),
            reason: 'transfert impliquant TATA : ${t.from}');
        expect(b[0], isNot('TATA'),
            reason: 'transfert impliquant TATA : ${t.to}');
        expect(PassBiSource.assetFiles.containsKey(a[0]), isTrue);
        expect(PassBiSource.assetFiles.containsKey(b[0]), isTrue);
      }

      // Le moteur ne produit AUCUN trajet depuis/vers une clé TATA.
      for (final autre in <String>{
        'DDD:D_708',
        'AFTU:A_839',
        'BRT:0:GNOA',
        cDakar,
      }) {
        expect(
          app.appDataService.planPassBiJourneys(
            fromPassBiKeys: <String>{'TATA:tata_50'},
            toPassBiKeys: <String>{autre},
            at: lundi10,
          ),
          isEmpty,
          reason: 'TATA → $autre : aucun trajet',
        );
        expect(
          app.appDataService.planPassBiJourneys(
            fromPassBiKeys: <String>{autre},
            toPassBiKeys: <String>{'TATA:tata_50'},
            at: lundi10,
          ),
          isEmpty,
          reason: '$autre → TATA : aucun trajet',
        );
      }
    });

    test('1c. TATA : identité conservée UNKNOWN / IDENTITE_NON_CONFIRMEE', () {
      for (final r
          in app.appDataService.routes.where((r) => r.operatorId == 'tata')) {
        final m = app.appDataService.passBiSource.routeMapping(r.id)!;
        expect(m.note, contains('AUCUNE donnée'));
        expect(
            app.appDataService.scheduleProvider.unresolvedReasonFor(
                routeId: r.id, stopId: 'stop_mermoz'),
            UnresolvedReason.networkAbsentFromFeed);
      }
    });
  });

  // ================================================== 2. DDD identité/horaire
  group('2 — DDD : horaire disponible + identité UNKNOWN (DDD_217 / D217OT)',
      () {
    test('2a. DDD_217 : SCHEDULED calculable, identité publique non confirmée',
        () {
      final summary =
          app.appDataService.passBiSource.routeSummary('DDD', 'DDD_217');
      expect(summary, isNotNull);
      expect(summary!.shortName, 'D217OT');
      expect(summary.scheduleAvailable, isTrue,
          reason: 'trips + stop_times réels : horaire calculable');
      expect(summary.identityStatus, IdentityStatus.unconfirmed);
      expect(summary.dakarRouteIds, isEmpty,
          reason: 'aucune identité publique déduite du numéro');

      final stopId = firstStopOf('DDD', 'DDD_217');
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: stopId,
        pbRouteId: 'DDD_217',
        at: lundi12,
      );
      expect(info.status, ScheduleStatus.scheduled,
          reason: 'identité non confirmée ≠ horaire indisponible');
      expect(info.identityStatus, IdentityStatus.unconfirmed);
      expect(info.frequencyMinutes, isNull,
          reason: 'jamais une fréquence convertie en horaire');
      expect(info.label, isNot('Prochain départ dans 0 min'));
    });

    test('2b. l\'interface ne présente jamais DDD_217 comme numéro public DDD',
        () {
      final label = ScheduleProvider.identityLabelFor(
        'DDD',
        'DDD_217',
        IdentityStatus.unconfirmed,
        shortName: 'D217OT',
      );
      // Chantier UI : la source de données n'est plus nommée, et l'identifiant
      // interne n'est jamais présenté comme le numéro public DDD.
      expect(label, isNot(contains('PassBi')));
      expect(label, startsWith('DDD'));
      expect(label, contains('D217OT'));
      expect(label, isNot('D217OT'));
      expect(label.startsWith('D217OT'), isFalse);
      expect(label, isNot('DDD 217'));
      expect(label, isNot('D217'));
      // Confirmée serait possible UNIQUEMENT avec rattachement documenté —
      // ce qui n'existe pas pour DDD_217.
      expect(app.appDataService.passBiSource.dakarRouteIdsFor('DDD', 'DDD_217'),
          isEmpty);
      expect(app.appDataService.passBiSource.identityStatusOf('DDD', 'DDD_217'),
          IdentityStatus.unconfirmed);
    });
  });

  // ================================================= 3. AFTU identité/horaire
  group('3 — AFTU : horaire disponible + identité UNKNOWN, aucune fusion', () {
    test('3a. AFTU_3 : SCHEDULED + identité UNCONFIRMED', () {
      final summary =
          app.appDataService.passBiSource.routeSummary('AFTU', 'AFTU_3');
      expect(summary, isNotNull);
      expect(summary!.scheduleAvailable, isTrue);
      expect(summary.identityStatus, IdentityStatus.unconfirmed);
      expect(summary.dakarRouteIds, isEmpty);
      final stopId = firstStopOf('AFTU', 'AFTU_3');
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'AFTU',
        pbStopId: stopId,
        pbRouteId: 'AFTU_3',
        at: lundi10,
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.identityStatus, IdentityStatus.unconfirmed);
      final String label = ScheduleProvider.identityLabelFor(
          'AFTU', 'AFTU_3', IdentityStatus.unconfirmed,
          shortName: summary.shortName);
      expect(label, isNot(contains('PassBi')));
      expect(label, startsWith('AFTU'));
    });

    test('3b. aftu_8 / aftu_11 → AFTU_3 : hypothèses NON confirmées, jamais '
        'fusionnées', () {
      for (final id in <String>['aftu_8', 'aftu_11']) {
        final m = app.appDataService.passBiSource.routeMapping(id);
        expect(m, isNotNull, reason: id);
        expect(m!.status, 'UNMAPPED', reason: id);
        expect(m.method, 'IDENTITE_NON_CONFIRMEE', reason: id);
        expect(m.pbRouteIds, isEmpty,
            reason: '$id : aucun rattachement fabriqué');
        expect(m.isMapped, isFalse, reason: id);
        // L'observation de termini reste pour l'audit, sans confirmer.
        expect(m.hypothesis, isNotNull, reason: id);
        expect(m.hypothesis!['pbRouteId'], 'AFTU_3', reason: id);
        expect(m.hypothesis!['method'], 'TERMINI_MATCH', reason: id);
        expect(m.note, contains('Aucune fusion automatique'), reason: id);
      }
      // Deux lignes publiques distinctes pointant vers AFTU_3 : aucune n'est
      // rattachée, l'identité reste non confirmée.
      expect(
          app.appDataService.passBiSource.dakarRouteIdsFor('AFTU', 'AFTU_3'),
          isEmpty);
    });
  });

  // ================================= 4. identité jamais confirmée par numéro
  group('4 — identité JAMAIS confirmée par numéro/termini/nom seul', () {
    test('4a. seules les preuves documentaires (TER/BRT) confirment', () {
      for (final r in app.appDataService.routes) {
        final m = app.appDataService.passBiSource.routeMapping(r.id);
        expect(m, isNotNull, reason: r.id);
        if (m!.isMapped) {
          expect(
              RouteMapping.documentedIdentityMethods.contains(m.method),
              isTrue,
              reason: '${r.id} : confirmé sans preuve documentaire');
        }
        if (m.method == 'TERMINI_MATCH') {
          expect(m.isMapped, isFalse,
              reason: '${r.id} : TERMINI_MATCH ne confirme jamais');
          expect(m.status, 'UNMAPPED', reason: r.id);
        }
      }
      // Aucune route DDD/AFTU du feed n'est confirmée.
      for (final key in <String>['DDD', 'AFTU']) {
        for (final s in app.appDataService.passBiRouteSummaries(key)) {
          expect(s.identityStatus, IdentityStatus.unconfirmed,
              reason: s.routeId);
          expect(s.dakarRouteIds, isEmpty, reason: s.routeId);
        }
      }
    });

    test('4b. un MAPPED obtenu par termini est rejeté par le moteur', () {
      const craft = '''
{"meta":{},"routes":{"aftu_8":{"network":"AFTU","pbRouteIds":["AFTU_3"],
 "status":"MAPPED","method":"TERMINI_MATCH","score":0.92,
 "note":"hypo"}},"stops":{},"transfers":[]}''';
      final cw = PassBiSource.jsonDecodeCrosswalk(craft);
      final m = cw.routes['aftu_8']!;
      expect(m.status, 'MAPPED');
      expect(m.isMapped, isFalse,
          reason: 'sans preuve documentaire, MAPPED ne confirme rien');
    });

    test('4c. anti-fusion : aucun identifiant PassBi porté par 2 identités '
        'confirmées', () {
      final claims = <String, List<String>>{};
      for (final r in app.appDataService.routes) {
        final m = app.appDataService.passBiSource.routeMapping(r.id)!;
        if (!m.isMapped) continue;
        for (final pbId in m.pbRouteIds) {
          claims.putIfAbsent(pbId, () => <String>[]).add(r.id);
        }
      }
      for (final e in claims.entries) {
        expect(e.value.length, lessThanOrEqualTo(1),
            reason: 'fusion automatique : ${e.value} → ${e.key}');
      }
    });
  });

  // ============================================ 5. correspondances documentées
  group('5 — correspondances : documentées uniquement, jamais la proximité '
      'seule', () {
    test('5a. source.transfers : uniquement des liens documentés', () {
      final transfers = app.appDataService.passBiSource.transfers;
      expect(transfers.length, greaterThanOrEqualTo(1000));
      for (final t in transfers) {
        expect(t.isDocumented, isTrue,
            reason: 'lien non documenté : ${t.from} → ${t.to} (${t.method})');
        expect(t.meters, lessThanOrEqualTo(500));
        expect(t.name, isNotEmpty);
      }
    });

    test('5b. un lien de proximité seule est rejeté au chargement', () {
      const craft = '''
{"meta":{},"routes":{},"stops":{},"transfers":[
 {"from":"DDD:D_12","to":"AFTU:A_345","meters":0,"name":"","method":"PROXIMITE_SEULE","confidence":"high"},
 {"from":"DDD:D_12","to":"AFTU:A_345","meters":1,"name":"x","method":"","confidence":"high"},
 {"from":"TATA:tata_50","to":"DDD:D_708","meters":10,"name":"meme point","method":"NOM_IDENTIQUE_PROXIMITE","confidence":"high"},
 {"from":"DDD:D_708","to":"AFTU:A_839","meters":900,"name":"x","method":"NOM_IDENTIQUE_PROXIMITE","confidence":"high"}
]}''';
      final cw = PassBiSource.jsonDecodeCrosswalk(craft);
      expect(cw.transfers, isEmpty,
          reason: 'aucun lien de proximité seule / TATA / hors bornes accepté');
    });

    test('5c. deux arrêts proches de noms différents : aucune correspondance',
        () {
      // D_12 « Aéroport Léopold Sédar Senghor » (DDD) et A_345 « En Face École
      // Franco Islamique Al Qalam » (AFTU) sont à 9,8 m l\'un de l\'autre —
      // sans nom vérifié, la proximité ne crée aucun lien.
      expect(
          app.appDataService.passBiSource
              .transferBetween('DDD:D_12', 'AFTU:A_345'),
          isNull);
    });

    test('5d. matrice TER/BRT/DDD/AFTU : liens documentés par paire', () {
      final paires = <String, int>{};
      for (final t in app.appDataService.passBiSource.transfers) {
        final a = PassBiSource.splitComposite(t.from)![0];
        final b = PassBiSource.splitComposite(t.to)![0];
        final k = <String>[a, b]..sort();
        paires[k.join('-')] = (paires[k.join('-')] ?? 0) + 1;
      }
      for (final p in <String>[
        'DDD-TER', // TER → DDD
        'AFTU-TER', // TER → AFTU
        'BRT-DDD', // BRT → DDD
        'AFTU-BRT', // BRT → AFTU
        'AFTU-DDD', // DDD → AFTU / AFTU → DDD
      ]) {
        expect(paires[p], greaterThan(0),
            reason: 'paire $p sans lien documenté');
      }
      expect(paires.keys.where((k) => k.contains('TATA')), isEmpty);
    });

    test('5e. corridors réels : TER→DDD, TER→AFTU, BRT→DDD, BRT→AFTU, '
        'DDD→AFTU, AFTU→DDD', () {
      final corridors = <String, (Set<String>, Set<String>)>{
        'TER → DDD': (<String>{cDakar}, <String>{'DDD:D_325'}),
        'TER → AFTU': (<String>{cDakar}, <String>{'AFTU:A_548'}),
        'BRT → DDD': (<String>{'BRT:0:GNOA'}, <String>{'DDD:D_449'}),
        'BRT → AFTU': (<String>{'BRT:0:GNOA'}, <String>{'AFTU:A_608'}),
        'DDD → AFTU': (<String>{'DDD:D_708'}, <String>{'AFTU:A_839'}),
        'AFTU → DDD': (<String>{'AFTU:A_839'}, <String>{'DDD:D_708'}),
      };
      corridors.forEach((nom, c) {
        final js = app.appDataService.planPassBiJourneys(
          fromPassBiKeys: c.$1,
          toPassBiKeys: c.$2,
          at: lundi10,
        );
        expect(js, isNotEmpty, reason: '$nom : corridor exploitable');
        expectTransitionsDocumentees(js, nom);
      });
    });

    test('5f. une identité non confirmée n\'est jamais une preuve de '
        'correspondance', () {
      // Les rattachements d\'arrêts n\'existent QUE dans le périmètre des
      // identités documentées : aftu_8/aftu_11 ne rattachent aucun arrêt.
      expect(app.appDataService.passBiStopKeysForDakarStop('stop_yoff'), isEmpty,
          reason: 'aftu_8 non confirmé : aucun pont dakar → PassBi');
      // En revanche, une identité documentée continue de rattacher ses arrêts.
      expect(
          app.appDataService
              .passBiStopKeysForDakarStop('stop_brt_01_petersen'),
          isNotEmpty,
          reason: 'BRT B1 (documenté) : rattachement conservé');
      // Chaque lien de transfert relie des arrêts réellement desservis des
      // feeds — aucune identité de ligne n\'y intervient.
      for (final t in app.appDataService.passBiSource.transfers) {
        for (final key in <String>[t.from, t.to]) {
          final parts = PassBiSource.splitComposite(key)!;
          final net = app.appDataService.passBiSource.network(parts[0]);
          expect(net, isNotNull, reason: 'transfert hors feed : $key');
          if (net == null) continue;
          final si = net.stopIndexById[parts[1]];
          expect(si, isNotNull, reason: 'transfert vers arrêt inconnu : $key');
          if (si == null) continue;
          expect(net.routeIndexesCalling(si).isNotEmpty, isTrue,
              reason: 'transfert vers arrêt jamais desservi : $key');
        }
      }
    });
  });

  // ============================================== 6. TER/BRT non-régression
  group('6 — TER/BRT existants : aucune régression', () {
    test('6a. identités documentées inchangées', () {
      final ter = app.appDataService.passBiSource
          .routeMapping('ter_dakar_diamniadio')!;
      expect(ter.isMapped, isTrue);
      expect(ter.method, 'IDENTITY_OFFICIELLE');
      final b1 = app.appDataService.passBiSource
          .routeMapping('brt_b1_guediawaye_petersen')!;
      expect(b1.isMapped, isTrue);
      expect(b1.method, 'IDENTITY_OFFICIELLE');
      expect(b1.pbRouteIds, <String>['B1']);
      final b2 =
          app.appDataService.passBiSource.routeMapping('brt_b2_express')!;
      expect(b2.isMapped, isTrue);
      expect(b2.method, 'IDENTITY_OFFICIELLE');
      expect(b2.pbRouteIds, <String>['B2']);
      expect(app.appDataService.passBiSource.identityStatusOf('BRT', 'B1'),
          IdentityStatus.confirmed);
      expect(app.appDataService.passBiSource.identityStatusOf('BRT', 'B2'),
          IdentityStatus.confirmed);
      expect(app.appDataService.passBiSource.dakarRouteIdsFor('BRT', 'B1'),
          <String>['brt_b1_guediawaye_petersen']);
    });

    test('6b. le libellé d\'identité confirmée reste l\'identité documentée',
        () {
      expect(
          ScheduleProvider.identityLabelFor(
              'BRT', 'B1', IdentityStatus.confirmed),
          'BRT B1');
      expect(
          ScheduleProvider.identityLabelFor(
              'BRT', 'B2', IdentityStatus.confirmed),
          'BRT B2');
    });

    test('6c. le chemin crosswalk BRT B1 reste SCHEDULED + identité confirmée',
        () {
      final info = app.appDataService.departureFor(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        network: 'BRT',
        at: DateTime.utc(2026, 9, 28, 14, 0),
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(info.identityStatus, IdentityStatus.confirmed);
      expect(info.frequencyMinutes, isNull);
    });
  });

  // ================================= 7. identité ≠ horaire (séparation stricte)
  group('7 — identity_status ≠ schedule_status ; horaires réels uniquement', () {
    test('7a. un horaire SCHEDULED provient d\'un vrai stop_time du feed', () {
      final net = app.appDataService.passBiSource.network('DDD')!;
      final stopId = firstStopOf('DDD', 'DDD_01');
      final info = app.appDataService.passBiDepartureFor(
        networkKey: 'DDD',
        pbStopId: stopId,
        pbRouteId: 'DDD_01',
        at: lundi12,
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.frequencyMinutes, isNull,
          reason: 'une fréquence ne devient jamais un départ');
      expect(info.unresolvedReason, isNull);
      // Le départ annoncé existe comme stop_time réel (aucune estimation).
      final routeIndex = net.routeIndexById['DDD_01']!;
      final stopIndex = net.stopIndexById[stopId]!;
      final secOfDay =
          info.scheduledTime!.difference(DateTime.utc(2026, 9, 28)).inSeconds %
              86400;
      final reel = (net.stopTimesByStop[stopIndex] ?? const []).any((st) =>
          net.trips[st.tripIndex].routeIndex == routeIndex &&
          st.departureSec == secOfDay);
      expect(reel, isTrue,
          reason: 'départ $secOfDay s absent des stop_times réels');
    });

    test('7b. countdown dynamique par rapport à l\'heure de la demande', () {
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
      expect(a.scheduledTime, isNot(b.scheduledTime),
          reason: 'ETA calculée à l\'instant demandé, jamais figée');
      expect(a.referenceTime, DateTime.utc(2026, 9, 28, 8, 0));
      expect(b.referenceTime, DateTime.utc(2026, 9, 28, 8, 30));
      // Jamais de faux « 0 min » : le libellé reste honnête.
      expect(a.label, isNot('Prochain départ dans 0 min'));
      expect(b.label, isNot('Prochain départ dans 0 min'));
    });

    test('7c. aucun chemin ne produit REAL_TIME ni une fréquence déguisée', () {
      expect(EtaCalculator.hasRealtimeFeed, isFalse);
      final echantillons = <List<String>>[
        for (final ref in app.appDataService.passBiNativeStops('DDD').take(20))
          <String>['DDD', ref.stopId],
        for (final ref in app.appDataService.passBiNativeStops('AFTU').take(20))
          <String>['AFTU', ref.stopId],
      ];
      for (final e in echantillons) {
        final info = app.appDataService.passBiDepartureFor(
            networkKey: e[0], pbStopId: e[1], at: lundi12);
        expect(info.status, isNot(ScheduleStatus.realTime));
        if (info.status == ScheduleStatus.scheduled) {
          expect(info.frequencyMinutes, isNull);
          expect(info.scheduledTime, isNotNull);
          expect(info.label, isNot('Prochain départ dans 0 min'));
        } else {
          expect(info.unresolvedReason, isNotNull);
        }
      }
    });
  });
}
