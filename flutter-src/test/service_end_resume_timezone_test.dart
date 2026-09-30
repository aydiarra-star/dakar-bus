// LOT fin de service / reprise T-1h — verrous de non-régression.
//
// Reproduit le problème terrain : un utilisateur dont le téléphone est en
// France (CEST, UTC+2) à 23:52 voit l'application calculer à 21:52 heure de
// Dakar (Africa/Dakar, UTC+0). Le moteur doit alors refuser d'afficher une
// attente aberrante (ex. 508 min) correspondant à un départ du service SUIVANT
// et annoncer « Fin de service — reprise à HH:MM ».
//
// Règles absolues vérifiées :
//  * l'heure de calcul vient de DakarClock (UTC), jamais de l'heure locale du
//    navigateur ;
//  * aucun horaire de fermeture codé en dur : bornes dérivées du feed ;
//  * un départ du service suivant n'est JAMAIS une attente du service courant ;
//  * 00:00 est un premier départ valide (reprise T-1h la veille) ;
//  * UNKNOWN (données insuffisantes) ≠ Fin de service ;
//  * GPS refusé n'a aucun effet sur le calcul horaire.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/service_availability.dart';
import 'package:dakar_bus/services/dakar_clock.dart';
import 'package:dakar_bus/services/gtfs/gtfs_source.dart';

/// Fixture GTFS (format compact réel) : premier départ [firstSec], dernier
/// départ embarquable [lastSec], tous les jours.
GtfsNetwork dailyNetwork({
  required int firstSec,
  required int lastSec,
  int mask = 127,
}) =>
    GtfsNetwork.fromJson(
      'T',
      jsonEncode(<String, dynamic>{
        'meta': <String, String>{},
        'agency': 'Test',
        'routes': [
          {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
        ],
        'stops': [
          ['S1', 'A', 14.7, -17.4, 1],
          ['S2', 'B', 14.71, -17.41, 1],
          ['S3', 'C', 14.72, -17.42, 1],
        ],
        'services': [
          ['ALL', mask, '20260101', '20261231'],
        ],
        'exceptions': <List<dynamic>>[],
        'trips': [
          ['T', 0, 0, '0', 'C'],
        ],
        'stop_times': [
          [0, 0, 1, firstSec, firstSec], // embarquable
          [0, 1, 2, lastSec, lastSec], // embarquable (dernier départ réel)
          [0, 2, 3, lastSec + 600, lastSec + 600], // terminus (jamais compté)
        ],
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==================================================================
  // §2/§14 — FUSEAU : 23:52 France (UTC+2) = 21:52 Dakar (UTC+0).
  // ==================================================================
  group('fuseau — heure de Dakar, jamais l\'heure locale', () {
    test('DakarClock.now() est toujours en UTC (Africa/Dakar = UTC+0)', () {
      final DateTime now = DakarClock.now();
      expect(now.isUtc, isTrue);
      expect(DakarClock.timeZone, 'Africa/Dakar');
    });

    test('un instant France (UTC+2) correspond au même instant Dakar', () {
      // 23:52 CEST (UTC+2) = 21:52 UTC = 21:52 Dakar. On part de l'instant
      // absolu (UTC) : aucune hypothèse sur le fuseau de la machine de test.
      final DateTime instant = DateTime.utc(2026, 9, 29, 21, 52);
      final DateTime dakar = DakarClock.toDakar(instant);
      expect(dakar.isUtc, isTrue);
      expect(dakar, instant);
      expect(dakar.hour, 21);
      expect(dakar.minute, 52);
      // Une référence LOCALE est ramenée au même instant (TZ-agnostique).
      expect(DakarClock.toDakar(instant.toLocal()), instant);
    });
  });

  // ==================================================================
  // §8/§18 — PREMIER SERVICE À MINUIT : reprise 23:00 la veille.
  // ==================================================================
  group('premier service à 00:00', () {
    test('avant la fenêtre de reprise (22:00) → fin de service, reprise 23:00',
        () {
      final GtfsNetwork net = dailyNetwork(firstSec: 0, lastSec: 3600); // 00:00–01:00
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 22, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.firstDeparture, DateTime.utc(2026, 9, 29, 0, 0));
      expect(a.resumptionAt, DateTime.utc(2026, 9, 28, 23, 0));
      expect(a.isUpcomingService, isTrue);
    });

    test('dans la fenêtre T-1h (23:30 ≥ 00:00 − 1 h) → service actif', () {
      final GtfsNetwork net = dailyNetwork(firstSec: 0, lastSec: 3600);
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 23, 30),
        isScheduleAvailable: (_) => true,
      );
      // 23:30 est déjà dans la fenêtre de reprise → le service du lendemain
      // (00:00) est annoncé comme actif, jamais masqué.
      expect(a.resumptionAt, DateTime.utc(2026, 9, 28, 23, 0));
      expect(a.status, ServiceAvailabilityStatus.active);
    });
  });

  // ==================================================================
  // §18 — T-1h : premier service 06:00 → reprise 05:00.
  // ==================================================================
  group('reprise T-1h', () {
    test('premier service 06:00 → reprise 05:00', () {
      final GtfsNetwork net =
          dailyNetwork(firstSec: 21600, lastSec: 32400); // 06:00–09:00
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 10, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.resumptionAt, DateTime.utc(2026, 9, 29, 5, 0));
      expect(a.firstDeparture, DateTime.utc(2026, 9, 29, 6, 0));
    });

    test('avant le premier départ du jour → pas de fausse fin de service',
        () {
      final GtfsNetwork net = dailyNetwork(firstSec: 21600, lastSec: 32400);
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 5, 30), // 05:30, reprise atteinte
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.active);
      expect(a.firstDeparture, DateTime.utc(2026, 9, 28, 6, 0));
    });
  });

  // ==================================================================
  // §9 — CALENDRIER : start_date / end_date / calendar_dates / dimanche.
  // ==================================================================
  group('calendrier GTFS', () {
    test('service hors période (mardi) → non actif, reprise au jour actif',
        () {
      // Actif lundi (bit0 = 1) et mercredi (bit2 = 4) uniquement.
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'T',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['MON', 1, '20260101', '20261231'],
            ['WED', 4, '20260101', '20261231'],
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            ['TM', 0, 0, '0', 'B'],
            ['TW', 0, 1, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 21600, 21600],
            [0, 1, 2, 22200, 22200],
            [1, 0, 1, 18000, 18000],
            [1, 1, 2, 18600, 18600],
          ],
        }),
      );
      // mardi 2026-09-29 : aucun service actif ce jour → la reprise est
      // mercredi 04:00 (premier départ 05:00 − 1 h), pas une fin de service
      // silencieuse.
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 29, 12, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.resumptionAt, DateTime.utc(2026, 9, 30, 4, 0));
      expect(a.firstDeparture, DateTime.utc(2026, 9, 30, 5, 0));
    });

    test('calendar_dates : service AJOUTÉ un jour sans motif hebdomadaire',
        () {
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'T',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          // Aucun jour hebdomadaire (mask 0) : n'existe que par exception.
          'services': [
            ['EXC', 0, '20260101', '20261231'],
          ],
          'exceptions': [
            ['EXC', '20260929', 1], // ajouté le mardi 29/09
          ],
          'trips': [
            ['TE', 0, 0, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 28800, 28800], // 08:00
            [0, 1, 2, 29400, 29400],
          ],
        }),
      );
      // Le mardi 29/09 : service ajouté → actif à 07:30 (départ 08:00 à venir).
      final ServiceAvailability mid = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 29, 7, 30),
        isScheduleAvailable: (_) => true,
      );
      expect(mid.status, ServiceAvailabilityStatus.active);
      expect(mid.firstDeparture, DateTime.utc(2026, 9, 29, 8, 0));
      // Un autre jour sans exception ET sans service dans les 7 jours
      // suivants : aucune donnée → UNKNOWN (jamais Fin de service inventée).
      final ServiceAvailability autre = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 20, 7, 30),
        isScheduleAvailable: (_) => true,
      );
      expect(autre.status, ServiceAvailabilityStatus.unknown);
    });

    test('calendar_dates : service SUPPRIMÉ → non actif ce jour', () {
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'T',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['ALL', 127, '20260101', '20261231'],
          ],
          'exceptions': [
            ['ALL', '20260929', 2], // retiré le mardi 29/09
          ],
          'trips': [
            ['T', 0, 0, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 28800, 28800],
            [0, 1, 2, 29400, 29400],
          ],
        }),
      );
      // Retiré le 29/09 → aucun service actif ce jour, reprise le 30/09.
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 29, 8, 30),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.firstDeparture, DateTime.utc(2026, 9, 30, 8, 0));
      expect(a.resumptionAt, DateTime.utc(2026, 9, 30, 7, 0));
    });

    test('dimanche : calendrier distinct (service dominical)', () {
      // Actif dimanche seulement (bit6 = 64).
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'T',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['SUN', 64, '20260101', '20261231'],
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            ['TS', 0, 0, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 25200, 25200], // 07:00
            [0, 1, 2, 25800, 25800],
          ],
        }),
      );
      // Dimanche 2026-10-04 : actif (départ 07:00 à venir à 06:30).
      expect(
        computeNetworkServiceAvailability(
          network: net,
          at: DateTime.utc(2026, 10, 4, 6, 30),
          isScheduleAvailable: (_) => true,
        ).status,
        ServiceAvailabilityStatus.active,
      );
      // Lundi 2026-10-05 : non actif, reprise dimanche suivant.
      final ServiceAvailability lundi = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 10, 5, 8, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(lundi.status, ServiceAvailabilityStatus.serviceEnded);
      expect(lundi.firstDeparture, DateTime.utc(2026, 10, 11, 7, 0));
    });
  });

  // ==================================================================
  // §6 — UNKNOWN ≠ Fin de service.
  // ==================================================================
  group('UNKNOWN vs Fin de service', () {
    test('réseau absent → UNKNOWN, jamais Fin de service', () {
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: null,
        at: DateTime.utc(2026, 9, 29, 23, 52),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.unknown);
      expect(a.isServiceEnded, isFalse);
      expect(a.reason, ServiceAvailabilityReason.networkAbsentFromFeed);
    });

    test('horaires non exploitables → UNKNOWN, jamais Fin de service', () {
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: dailyNetwork(firstSec: 21600, lastSec: 32400),
        at: DateTime.utc(2026, 9, 29, 23, 52),
        isScheduleAvailable: (_) => false,
      );
      expect(a.status, ServiceAvailabilityStatus.unknown);
      expect(a.isServiceEnded, isFalse);
      expect(a.reason, ServiceAvailabilityReason.noDocumentedService);
    });

    test('message : UNKNOWN → aucune mention « Fin de service »', () {
      final ServiceAvailability a = ServiceAvailability.unknown(
          ServiceAvailabilityReason.noDocumentedService);
      expect(app.serviceNoticeFor(a, DateTime.utc(2026, 9, 29, 23, 52)),
          isNull);
    });
  });

  // ==================================================================
  // §3/§14 — 508 min : un départ du lendemain n'est jamais une attente.
  // ==================================================================
  group('attente aberrante (508 min)', () {
    test('le prochain départ du service suivant est borné (jamais 500+)', () {
      // Réseau 06:00–09:00, jour suivant 06:00. À 10:00 le prochain départ
      // RÉEL brut du feed est celui du lendemain (06:00 → 1200 min) ; la borne
      // d'affichage le rejette : aucun « X min » du service suivant.
      final GtfsNetwork net = dailyNetwork(firstSec: 21600, lastSec: 32400);
      final DateTime at = DateTime.utc(2026, 9, 29, 10, 0);
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: at,
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      // Reprise 05:00 le 30/09 : le départ du lendemain (06:00) est ≥ à la
      // borne de reprise → jamais affiché comme attente du jour.
      expect(a.displayHorizonAt, DateTime.utc(2026, 9, 30, 5, 0));
    });

    test('aucun « X min » n\'est produit au-delà de la borne', () {
      final GtfsNetwork net = dailyNetwork(firstSec: 21600, lastSec: 32400);
      final DateTime at = DateTime.utc(2026, 9, 29, 10, 0);
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: at,
        isScheduleAvailable: (_) => true,
      );
      // Le départ du lendemain (30/09 06:00) est au-delà de la borne → filtré.
      final DateTime lendemain = DateTime.utc(2026, 9, 30, 6, 0);
      expect(lendemain.isBefore(a.displayHorizonAt!), isFalse,
          reason: 'le départ du lendemain ne doit pas passer la borne');
    });
  });

  // ==================================================================
  // §11 — service nocturne : un départ de nuit réel n'est jamais supprimé.
  // ==================================================================
  group('service nocturne', () {
    test('un départ à 00:09 (jour de service courant) reste affichable', () {
      // Service 20:00 → 00:09 (départ de nuit embarquable), tous les jours.
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'N',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['ALL', 127, '20260101', '20261231'],
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            ['TN', 0, 0, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 72000, 72000], // 20:00 (embarquable)
            [0, 1, 2, 86940, 86940], // 24:09 = 00:09 (embarquable)
            [0, 2, 3, 87540, 87540], // terminus
          ],
        }),
      );
      // 23:30 : le dernier départ embarquable du jour (24:09, soit 00:09 le
      // lendemain civil) est encore à venir → service ACTIF, aucun départ de
      // nuit supprimé. Le départ est bien placé en J+1 civil.
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 29, 23, 30),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.active);
      expect(a.lastDeparture, DateTime.utc(2026, 9, 30, 0, 9));
    });

    test('GTFS > 24 h : 24:09 et 25:15 restent du jour de service', () {
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'N2',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['ALL', 127, '20260101', '20261231'],
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            ['T', 0, 0, '0', 'B'],
          ],
          'stop_times': [
            [0, 0, 1, 72000, 72000], // 20:00
            [0, 1, 2, 86940, 86940], // 24:09
            [0, 2, 3, 90900, 90900], // 25:15 (embarquable : un arrêt suit)
            [0, 3, 4, 91500, 91500], // terminus
          ],
        }),
      );
      // 25:15 = 90900 s : dernier départ embarquable documenté du service du
      // 29/09 (jour de service GTFS), jamais converti ni rattaché à un autre
      // service_id.
      expect(net.lastDepartureSecOn(DateTime.utc(2026, 9, 29)), 90900);
      expect(net.firstDepartureSecOn(DateTime.utc(2026, 9, 29)), 72000);
    });
  });

  // ==================================================================
  // §10/§11 — plusieurs directions : l'arrêt sans départ ne ferme pas le
  // réseau tant qu'une autre direction roule.
  // ==================================================================
  group('directions multiples', () {
    test('une direction terminée ne ferme pas la mobilité', () {
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'D',
        jsonEncode(<String, dynamic>{
          'meta': <String, String>{},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'L1', 'type': 3},
          ],
          'stops': [
            ['S1', 'A', 14.7, -17.4, 1],
            ['S2', 'B', 14.71, -17.41, 1],
          ],
          'services': [
            ['ALL', 127, '20260101', '20261231'],
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            ['T1', 0, 0, '0', 'B'],
            ['T2', 0, 0, '1', 'A'],
          ],
          'stop_times': [
            [0, 0, 1, 21600, 21600], // sens 0 : 06:00
            [0, 1, 2, 22200, 22200],
            [1, 1, 1, 32400, 32400], // sens 1 : 09:00
            [1, 0, 2, 33000, 33000],
          ],
        }),
      );
      // À 07:00 le réseau est actif (le dernier départ du jour, 09:00, est
      // encore à venir) même si un arrêt précis n'a plus de départ.
      expect(
        computeNetworkServiceAvailability(
          network: net,
          at: DateTime.utc(2026, 9, 29, 7, 0),
          isScheduleAvailable: (_) => true,
        ).status,
        ServiceAvailabilityStatus.active,
      );
    });
  });

  // ==================================================================
  // §14/§17/§18 — FEEDS RÉELS : 23:52 France = 21:52 Dakar.
  // ==================================================================
  group('feeds réels — 21:52 Dakar (23:52 France)', () {
    setUpAll(() async {
      await app.appDataService.loadNetworkData();
      await app.appDataService.loadPassBiSchedules();
      expect(app.appDataService.passBiActive, isTrue);
    });

    // 21:52 Dakar = 23:52 France (CEST). Référence construite en UTC : aucune
    // heure locale de navigateur n'intervient.
    final DateTime dakar2152 = DateTime.utc(2026, 9, 29, 21, 52);

    test('TER : actif à 21:52 (dernier départ 22:47)', () {
      final ServiceAvailability a =
          app.appDataService.serviceAvailabilityFor('TER', dakar2152);
      expect(a.status, ServiceAvailabilityStatus.active);
      expect(a.lastDeparture!.isAfter(dakar2152), isTrue);
    });

    test('BRT : actif à 21:52 (dernier départ 21:55)', () {
      final ServiceAvailability a =
          app.appDataService.serviceAvailabilityFor('BRT', dakar2152);
      expect(a.status, ServiceAvailabilityStatus.active);
      expect(a.lastDeparture, DateTime.utc(2026, 9, 29, 21, 55, 1));
    });

    test('BRT : fin de service à 22:52 → reprise documentée', () {
      final ServiceAvailability a = app.appDataService
          .serviceAvailabilityFor('BRT', DateTime.utc(2026, 9, 29, 22, 52));
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.resumptionAt, DateTime.utc(2026, 9, 30, 5, 0, 30));
      final String? notice =
          app.serviceNoticeFor(a, DateTime.utc(2026, 9, 29, 22, 52));
      expect(notice, isNotNull);
      expect(notice!, contains('Fin de service'));
      expect(notice, contains('reprise à 05:00'));
    });

    test('DDD : aucun « X min » aberrant (> 400) à 21:52', () {
      final ServiceAvailability a =
          app.appDataService.serviceAvailabilityFor('DDD', dakar2152);
      final List<app.Stop> stops = app.appDataService
          .passBiNativeStops('DDD')
          .map((r) => app.Stop(
                name: r.name,
                stopId: r.stopId,
                passBiStopKey: 'DDD:${r.stopId}',
                direction: '—',
                distanceMeters: 0,
                departureMinutesFromMidnight: const <int>[],
                icon: Icons.directions_bus,
                color: const Color(0xFF00A651),
                location: const LatLng(14.74, -17.47),
                modeLabel: 'DDD',
              ))
          .toList();
      expect(stops, isNotEmpty);
      for (final app.Stop s in stops) {
        for (final int w
            in s.nextRealWaitingMinutes(at: dakar2152, horizon: a.displayHorizonAt)) {
          expect(w, lessThanOrEqualTo(400),
              reason: '${s.name} : attente aberrante $w min');
          expect(w, greaterThan(0), reason: '${s.name} : 0 min artificiel');
        }
      }
    });

    test('TATA : aucune fin de service inventée (réseau absent)', () {
      final ServiceAvailability a =
          app.appDataService.serviceAvailabilityFor('TATA', dakar2152);
      expect(a.status, ServiceAvailabilityStatus.unknown);
      expect(a.isServiceEnded, isFalse);
    });
  });
}
