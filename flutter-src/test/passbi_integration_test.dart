// Lot 4.18 — Tests d'intégration PassBi (côté application Flutter).
//
// 20 exigences de tests obligatoires (docs/INTEGRATION_PASSBI_4_18_...) :
// TER/BRT/DDD/AFTU chargement, routes/stops/trips/stop_times/calendar/
// calendar_dates, prochain départ, 🟢 X min, changement de date, services
// actifs, correspondances, B1/B2 séparés, provenance, absence de données,
// pas de faux temps réel, remplacement futur.
//
// Les valeurs attendues (43885 s, 50430 s, 29400 s…) proviennent d'un
// calcul indépendant sur les GTFS bruts, pas de la relecture du code.
// Lot 4.19 : nuit → service J+1 ; départs embarquables seuls (quais de
// départ ou plateforme sœur documentée).
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/gtfs/routing_engine.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final PassBiSource src = PassBiSource();
  final ScheduleProvider provider = ScheduleProvider(src);
  final PassBiRoutingEngine engine = PassBiRoutingEngine(src);

  // Fixtures horaires (calcul brut indépendant, fuseau Dakar = UTC+0).
  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0); // 43885 s
  final DateTime lundi14 = DateTime.utc(2026, 9, 28, 14, 0);
  final DateTime lundi10 = DateTime.utc(2026, 9, 28, 10, 0);
  final DateTime dimanche12 = DateTime.utc(2026, 10, 4, 12, 0); // 43671 s
  const String colobanePb =
      'TER:c70477e7-8391-4388-9a1f-8929a18dc14e-00000000-0000-0000-0000-000000000000';
  const String diamniadioPb =
      'TER:4445e51b-971b-4f1a-a94a-1ca0c9bef411-00000000-0000-0000-0000-000000000000';

  setUpAll(() async {
    await src.loadAll();
  });

  group('1. chargement GTFS TER', () {
    test('feed TER présent et indexé', () {
      expect(src.isActive, isTrue);
      final ter = src.network('TER');
      expect(ter, isNotNull);
      expect(ter!.meta['network'], 'TER');
      expect(ter.routes.length, 6);
      expect(ter.trips.length, 572);
      expect(ter.stopTimes.length, 7332);
    });
  });

  group('2. chargement GTFS BRT', () {
    test('feed BRT présent : B1 et B2 seulement', () {
      final brt = src.network('BRT');
      expect(brt, isNotNull);
      expect(brt!.routes.map((r) => r.id).toList()..sort(), ['B1', 'B2']);
      expect(brt.trips.length, 4036);
      expect(brt.stopTimes.length, 58674);
    });
  });

  group('3. chargement GTFS DDD', () {
    test('feed DDD présent tel quel', () {
      final ddd = src.network('DDD');
      expect(ddd, isNotNull);
      expect(ddd!.routes.length, 53);
      expect(ddd.trips.length, 9529);
      expect(ddd.stopTimes.length, 314029);
    });
  });

  group('4. chargement GTFS AFTU', () {
    test('feed AFTU présent tel quel', () {
      final aftu = src.network('AFTU');
      expect(aftu, isNotNull);
      expect(aftu!.routes.length, 73);
      expect(aftu.trips.length, 11077);
      expect(aftu.stopTimes.length, 677918);
    });
  });

  group('5. routes', () {
    test('libellés intacts sur les quatre réseaux', () {
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final net = src.network(key)!;
        expect(net.routes, isNotEmpty);
        for (final r in net.routes) {
          expect(r.id, isNotEmpty);
          expect(r.short, isNotEmpty);
          expect(r.long, isNotEmpty);
        }
      }
      // Identifiants PassBi d'origine (UUID/short_name du feed) : aucune
      // route n'est une invention locale.
      final terRouteId = src.network('TER')!.routes.first.id;
      expect(terRouteId.length, greaterThan(20));
    });
  });

  group('6. stops', () {
    test('compteurs et arrêts utilisés', () {
      expect(src.network('TER')!.stops.length, 26);
      expect(src.network('TER')!.stops.where((s) => s.used).length, 13);
      expect(src.network('BRT')!.stops.length, 79);
      expect(src.network('BRT')!.stops.where((s) => s.used).length, 43);
      expect(src.network('DDD')!.stops.length, 1277);
      expect(src.network('AFTU')!.stops.length, 2401);
      final col = src.network('TER')!
          .stops.firstWhere((s) => s.id == colobanePb.substring(4));
      expect(col.name, 'Colobane');
      expect(col.used, isTrue);
    });
  });

  group('7. trips', () {
    test('indexation route/trip/service sans trou', () {
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final net = src.network(key)!;
        for (final t in net.trips) {
          expect(t.routeIndex, inInclusiveRange(0, net.routes.length - 1));
          expect(t.serviceIndex, inInclusiveRange(0, net.services.length - 1));
        }
      }
    });
  });

  group('8. stop_times', () {
    test('séquences et heures exploitables', () {
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final net = src.network(key)!;
        for (final st in net.stopTimes) {
          expect(st.tripIndex, inInclusiveRange(0, net.trips.length - 1));
          expect(st.stopIndex, inInclusiveRange(0, net.stops.length - 1));
          expect(st.sequence, greaterThan(0));
          expect(st.departureSec, greaterThanOrEqualTo(0));
        }
      }
      // L'arrêt Colobane est appelé par 572 trips (index par arrêt).
      final ter = src.network('TER')!;
      final colIdx = ter.stopIndexById[colobanePb.substring(4)]!;
      expect(ter.stopTimesByStop[colIdx]!.length, 572);
    });
  });

  group('9. calendar', () {
    test('motifs hebdomadaires et fenêtres d origine conservées', () {
      expect(src.network('TER')!.services.length, 12);
      expect(src.network('BRT')!.services.length, 7);
      expect(src.network('DDD')!.services.length, 4);
      expect(src.network('AFTU')!.services.length, 4);
      // Dates d'origine du feed, jamais falsifiées (mode ROLLING actif).
      expect(src.network('TER')!.meta['valid_from'], '20250818');
      expect(src.network('TER')!.meta['valid_to'], '20250831');
      expect(src.network('DDD')!.meta['valid_from'], '20220101');
      expect(src.network('AFTU')!.meta['valid_to'], '20231231');
      expect(src.network('TER')!.meta['calendar_mode'], 'ROLLING');
    });
  });

  group('10. calendar_dates', () {
    test('exceptions datées appliquées (ajout et retrait)', () {
      final brt = src.network('BRT')!;
      final ddd = src.network('DDD')!;
      expect(brt.exceptions.length, 69);
      expect(ddd.exceptions.length, 40);
      expect(src.network('AFTU')!.exceptions.length, 40);
      expect(src.network('TER')!.exceptions.length, 0);

      // Lundi de Pâques 2022-04-04 : LAV retiré par exception type 2.
      const lavIdx = 1; // ordre du feed : FULL, LAV, SAMEDI, DIMANCHE
      final lavId = ddd.services[lavIdx].id;
      expect(lavId, 'LAV');
      final jourFerie = DateTime.utc(2022, 4, 4); // lundi
      final lundiOrdinaire = DateTime.utc(2022, 4, 11);
      final types = ddd.exceptions[lavId]!;
      expect(types['20220404'], 2);
      expect(ddd.serviceActiveOn(lavIdx, jourFerie), isFalse);
      expect(ddd.serviceActiveOn(lavIdx, lundiOrdinaire), isTrue);
    });
  });

  group('11. prochain départ', () {
    test('TER Colobane lundi 12:00 → 43885 s (12:11:25)', () {
      final info = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      );
      expect(info, isNotNull);
      expect(info!.status, ScheduleStatus.scheduled);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 12, 11, 25));
      // Après minuit : le service J+1 est retrouvé avec son propre
      // service_id (Lot 4.19 B) — jamais « 0 min », jamais une fréquence.
      final nuit = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: DateTime.utc(2026, 10, 4, 23, 59),
      );
      expect(nuit, isNotNull);
      expect(nuit!.status, ScheduleStatus.scheduled);
      // dimanche 23:59 → lundi 06:00:30 via la plateforme sœur PGFA.
      expect(nuit.scheduledTime, DateTime.utc(2026, 10, 5, 6, 0, 30));
      expect(nuit.estimatedWaitFrom, 361);
      expect(nuit.label, 'Prochain départ dans 361 min');
    });

    test('API moteur directe : DDD_01 et AFTU_1 exploitables', () {
      final ddd = src.nextDepartureSec(
        networkKey: 'DDD',
        pbRouteId: 'DDD_01',
        pbStopId: 'D_805',
        at: DateTime.utc(2026, 9, 29, 8, 0), // mardi
      );
      expect(ddd, 29400); // 08:10:00
      final aftu = src.nextDepartureSec(
        networkKey: 'AFTU',
        pbRouteId: 'AFTU_1',
        pbStopId: 'A_916',
        at: lundi12.subtract(const Duration(hours: 4)), // 08:00
      );
      // 08:01:53 était l'ARRIVÉE du sens inverse terminant à A_916 :
      // le premier départ embarquable réel est 08:15:09 (Lot 4.19 A).
      expect(aftu, 29709); // 08:15:09
    });
  });

  group('12. calcul 🟢 X min', () {
    test('B1 Petersen lundi 14:00 → départ sœur 14:00:30 (< 1 min)', () {
      final info = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: lundi14,
      );
      expect(info, isNotNull);
      expect(info!.status, ScheduleStatus.scheduled);
      // PGFB est le quai d'arrivée : le départ embarquable se lit sur la
      // plateforme sœur PGFA (lien documenté 10 m — Lot 4.19 A).
      expect(info.estimatedWaitFrom, 0);
      expect(info.estimatedWaitTo, 0);
      expect(info.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(info.label, 'Prochain départ dans moins d’une minute');
      // Statut affiché = programmé (jamais « live »).
      expect(departureDataStatusOf(info.status), isNot('live'));
    });

    test('TER Colobane → « Prochain départ dans 11 min »', () {
      final info = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      );
      expect(info!.estimatedWaitFrom, 11);
      expect(info.label, 'Prochain départ dans 11 min');
      expect(info.sourceType, SourceType.publicGtfs);
      expect(info.sourceType.toLabel(), 'PUBLIC_GTFS');
    });
  });

  group('13. changement de date', () {
    test('départs différents lundi vs dimanche', () {
      final lundi = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      );
      final dimanche = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: dimanche12,
      );
      expect(lundi!.scheduledTime, DateTime.utc(2026, 9, 28, 12, 11, 25));
      expect(dimanche!.scheduledTime, DateTime.utc(2026, 10, 4, 12, 7, 51));
      expect(lundi.scheduledTime!.isAfter(dimanche.scheduledTime!), isTrue);
    });
  });

  group('14. services actifs', () {
    test('compteurs par jour (mode ROLLING)', () {
      final ter = src.network('TER')!;
      expect(ter.activeServiceCountOn(DateTime.utc(2026, 9, 28)), 2); // lundi
      expect(ter.activeServiceCountOn(DateTime.utc(2026, 10, 4)), 2); // dim.
      final brt = src.network('BRT')!;
      expect(brt.activeServiceCountOn(DateTime.utc(2026, 9, 28)), 1);
      final ddd = src.network('DDD')!;
      expect(ddd.activeServiceCountOn(DateTime.utc(2026, 9, 29)), 2); // FULL+LAV
    });
  });

  group('15. correspondances', () {
    test('TER direct : route → trip → stop_sequence → horaire', () {
      final journeys = engine.planJourneys(
        fromKeys: {colobanePb},
        toKeys: {diamniadioPb},
        at: lundi12,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, 0);
      expect(j.legs.first.network, 'TER');
      expect(j.legs.last.network, 'TER');
      // Premier départ après 12:00 = fixture 43885 s.
      expect(j.departureSec, 43885);
      expect(j.arrivalSec, greaterThan(j.departureSec));
    });

    test('BRT ↔ DDD : trajet composé avec correspondance réelle', () {
      final journeys = engine.planJourneys(
        fromKeys: {'BRT:0:GNOA'}, // B1 Golf Nord (aucun lien DDD direct)
        toKeys: {'DDD:D_449'},
        at: lundi10,
      );
      expect(journeys, isNotEmpty);
      final j = journeys.first;
      expect(j.transferCount, greaterThanOrEqualTo(1));
      expect(j.legs.first.network, 'BRT');
      expect(j.legs.last.network, 'DDD');
      // La correspondance passe par un lien documenté du crosswalk :
      // jamais par proximité seule.
      final lien = src.transferBetween(
          j.legs[0].toStopId, j.legs[1].fromStopId);
      expect(lien, isNotNull);
      expect(lien!.meters, lessThanOrEqualTo(500));
    });

    test('liens de transfert inter-réseaux présents et bornés', () {
      expect(src.transfers.length, greaterThanOrEqualTo(1000));
      final pairs = <String>{};
      for (final t in src.transfers) {
        final a = t.from.split(':').first;
        final b = t.to.split(':').first;
        pairs.add(([a, b]..sort()).join('-'));
        if (t.method == 'INCLUSION_NOM_PROXIMITE') {
          expect(t.meters, lessThanOrEqualTo(250));
          expect(a == b, isFalse, reason: 'inclusion = inter-réseaux');
        } else {
          expect(t.meters, lessThanOrEqualTo(500));
        }
      }
      // Corridors exigés par le lot (chaînage possible pour BRT↔TER via
      // DDD/AFTU — direct BRT↔TER absent, limite documentée au rapport).
      for (final p in ['DDD-TER', 'AFTU-TER', 'BRT-DDD', 'AFTU-BRT', 'AFTU-DDD']) {
        expect(pairs.contains(p), isTrue, reason: 'corridor $p absent');
      }
    });
  });

  group('16. B1 et B2 séparés', () {
    test('routes, arrêts et départs strictement distincts', () {
      final b1 = src.routeMapping('brt_b1_guediawaye_petersen')!;
      final b2 = src.routeMapping('brt_b2_express')!;
      expect(b1.isMapped, isTrue);
      expect(b2.isMapped, isTrue);
      expect(b1.pbRouteIds, ['B1']);
      expect(b2.pbRouteIds, ['B2']);
      // Même station dakar, plateformes PassBi distinctes.
      final p1 = src.stopMappingFor(
          'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen')!;
      final p2 =
          src.stopMappingFor('brt_b2_express', 'stop_brt_01_petersen')!;
      expect(p1.compositeStopId, 'BRT:0:PGFB');
      expect(p2.compositeStopId, 'BRT:0:PGFA');
      expect(p1.compositeStopId == p2.compositeStopId, isFalse);
      // Départs calculés indépendamment (jamais réutilisés entre lignes).
      final depB1 = provider.departureAt(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        requestedAt: lundi14,
      );
      final depB2 = provider.departureAt(
        routeId: 'brt_b2_express',
        stopId: 'stop_brt_23_guediawaye',
        requestedAt: lundi14,
      );
      // Quais de départ (sœurs PGFA/GDWB) : départs embarquables réels,
      // strictement distincts entre B1 et B2 (Lot 4.19 A).
      expect(depB1!.scheduledTime, DateTime.utc(2026, 9, 28, 14, 0, 30));
      expect(depB2!.scheduledTime, DateTime.utc(2026, 9, 28, 14, 3, 30));
      expect(
        depB1.scheduledTime == depB2.scheduledTime, isFalse);
      // Aucune route B3 fabriquée.
      expect(src.network('BRT')!.routes.any((r) => r.id == 'B3'), isFalse);
    });
  });

  group('17. provenance PassBi', () {
    test('ACTIVE, PUBLIC_GTFS, dates d origine intactes', () {
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final meta = src.network(key)!.meta;
        expect(meta['source'], startsWith('PassBi'));
        expect(meta['source_type'], 'PUBLIC_GTFS');
        expect(meta['status'], 'ACTIVE');
        expect(meta['date_source'], '2026-02-10');
        expect(meta['date_verified'], '2026-09-27');
        expect(meta['status'] == 'HISTORICAL', isFalse);
        expect(meta['valid_from'], isNotNull);
        expect(meta['valid_to'], isNotNull);
      }
      final cwMeta = src.crosswalkMeta!;
      expect(cwMeta['source'], startsWith('PassBi'));
      expect(cwMeta['source_type'], 'PUBLIC_GTFS');
      expect(cwMeta['status'], 'ACTIVE');
      // Chaîne complète : DepartureInfo porte la provenance.
      final info = provider.departureAt(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'stop_colobane',
        requestedAt: lundi12,
      )!;
      expect(info.sourceType, SourceType.publicGtfs);
      expect(info.source, contains('passbi'));
      expect(info.dateVerified, '2026-09-27');
    });
  });

  group('18. absence de données', () {
    test('mappage non confirmé → aucune donnée rattachée (jamais inventé)',
        () {
      // ddd_1 : identité non confirmée → pas d'horaire PassBi sur cette ligne.
      final ddd1 = src.routeMapping('ddd_1')!;
      expect(ddd1.status, 'UNMAPPED');
      expect(ddd1.method, 'IDENTITE_NON_CONFIRMEE');
      expect(ddd1.pbRouteIds, isEmpty);
      // Arrêt BRT jamais appelé dans le feed → mapping null, pas d'approximation.
      final gadaye = src.stopMappingFor('brt_b1_guediawaye_petersen',
          'stop_brt_22_gadaye');
      expect(gadaye, isNull);
      expect(
        provider.departureAt(
          routeId: 'brt_b1_guediawaye_petersen',
          stopId: 'stop_brt_22_gadaye',
          requestedAt: lundi14,
        ),
        isNull,
      );
      // ddd_1 (mappage non confirmé) : aucune donnée rattachée — le
      // provider retourne null, jamais un horaire inventé (Lot 4.19 §11).
      expect(
        provider.departureAt(
          routeId: 'ddd_1',
          stopId: 'stop_dakar_petersen',
          requestedAt: lundi14,
        ),
        isNull,
      );
      // Quai d'arrivée via l'API directe : AUCUN départ embarquable —
      // jamais « 0 min », jamais une fréquence, jamais un horaire fabriqué.
      final pgfbSeul = src.nextDepartureSec(
        networkKey: 'BRT',
        pbRouteId: 'B1',
        pbStopId: '0:PGFB',
        at: lundi14,
      );
      expect(pgfbSeul, isNull);
      // Un arrêt BRT jamais appelé dans le feed (GUEULE TAPEE/GTAB) :
      // aucune ligne, aucun départ.
      final neverCalled = src.nextDepartureSec(
        networkKey: 'BRT',
        pbRouteId: 'B1',
        pbStopId: '0:GTAB',
        at: lundi14,
      );
      expect(neverCalled, isNull);
    });
  });

  group('19. pas de faux temps réel', () {
    test('aucun chemin du produit ne produit REAL_TIME', () {
      expect(EtaCalculator.hasRealtimeFeed, isFalse);
      expect(ScheduleStatus.realTime.toLabel(), 'REAL_TIME'); // jamais produit
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        final meta = src.network(key)!.meta;
        expect(meta['source_type'], 'PUBLIC_GTFS');
        expect(meta['time_semantics'], contains('jamais REAL_TIME'));
        expect(meta['source_type'] == 'OFFICIAL_REALTIME', isFalse);
      }
      // Les réponses PassBi restent SCHEDULED ou UNKNOWN.
      final cases = <DepartureInfo?>[
        provider.departureAt(
          routeId: 'ter_dakar_diamniadio',
          stopId: 'stop_colobane',
          requestedAt: lundi12,
        ),
        provider.departureAt(
          routeId: 'brt_b1_guediawaye_petersen',
          stopId: 'stop_brt_01_petersen',
          requestedAt: DateTime.utc(2026, 10, 4, 23, 59),
        ),
      ];
      for (final info in cases) {
        expect(info!.status == ScheduleStatus.realTime, isFalse);
        expect(
          ['scheduled', 'unknown'].contains(info.status.name),
          isTrue,
        );
      }
      // SCHEDULED s'affiche comme horaire, jamais comme live.
      expect(departureDataStatusOf(ScheduleStatus.scheduled), 'scheduled');
      expect(departureDataStatusOf(ScheduleStatus.realTime), 'live');
    });
  });

  group('20. remplacement futur', () {
    test('une seule entrée de lecture pour les quatre feeds', () {
      // Lecture centralisée : substituer les assets + régénérer suffit,
      // aucun changement moteur.
      expect(PassBiSource.assetFiles.keys.toList()..sort(),
          ['AFTU', 'BRT', 'DDD', 'TER']);
      expect(PassBiSource.crosswalkAsset, 'assets/data/passbi/crosswalk.json');
      expect(src.networks.length, 4);
      // Le lecteur est bien le point unique : chaque réseau indexé.
      for (final key in ['TER', 'BRT', 'DDD', 'AFTU']) {
        expect(src.network(key), isNotNull);
      }
      // Aucune donnée hardcodée dans le lecteur : seuls les assets comptent.
      final mapping = src.routeMapping('ter_dakar_diamniadio')!;
      expect(mapping.isMapped, isTrue);
      expect(mapping.network, 'TER');
      expect(mapping.pbRouteIds.length, 6);
    });
  });

  group('7 (bis). DataService : chaîne complète', () {
    test('departureFor remonte un horaire PassBi programmé', () async {
      final ds = DataService();
      await ds.loadNetworkData();
      await ds.loadPassBiSchedules();
      expect(ds.passBiActive, isTrue);
      final info = ds.departureFor(
        routeId: 'brt_b1_guediawaye_petersen',
        stopId: 'stop_brt_01_petersen',
        network: 'BRT',
        at: lundi14,
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.estimatedWaitFrom, 2);
      expect(info.label, 'Prochain départ dans 2 min');
      expect(info.sourceType, SourceType.publicGtfs);
      // Route inconnue du référentiel → UNKNOWN, jamais planté.
      final ko = ds.departureFor(
        routeId: null,
        stopId: null,
        network: 'BRT',
        at: lundi14,
      );
      expect(ko.status, ScheduleStatus.unknown);
      // Chemin UI sans donnée : « Horaire indisponible » (jamais 0 min,
      // retard, interruption ni fréquence — Lot 4.19 §11).
      expect(ko.label, 'Horaire indisponible');
    });
  });
}

/// Classification présentée à l'UI (miroir strict de departureDataStatus de
/// main.dart) : seul ScheduleStatus.realTime devient « live ».
String departureDataStatusOf(ScheduleStatus status) {
  switch (status) {
    case ScheduleStatus.scheduled:
      return 'scheduled';
    case ScheduleStatus.realTime:
      return 'live';
    case ScheduleStatus.estimated:
      return 'estimated';
    case ScheduleStatus.unknown:
      return 'unknown';
  }
}
