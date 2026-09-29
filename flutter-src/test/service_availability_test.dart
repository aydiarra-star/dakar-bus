// LOT fin de service — disponibilité du service journalier des mobilités
// documentées (TER/BRT/DDD/AFTU) et reprise automatique.
//
// Deux niveaux :
//  * DÉTERMINISTE — un réseau GTFS synthétique (aucune donnée de transport
//    inventée côté produit : ce n'est qu'une fixture de test) prouve le calcul
//    des bornes documentées, l'exclusion du terminus, la fin de service et la
//    reprise (premier départ du lendemain moins 1 h) ;
//  * RÉEL — les feeds PassBi embarqués : à une heure fixée, chaque mobilité
//    documentée expose un statut ACTIF ou TERMINÉ (jamais inconnu), et TATA
//    (sans feed) reste inconnu — aucune fin de service n'est inventée.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/service_availability.dart';
import 'package:dakar_bus/services/gtfs/gtfs_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Fixture GTFS minimale (format compact réel de `GtfsNetwork.fromJson`).
  //
  //  * S1 départ 06:00 (T1) et 09:10 (T2, terminus ici — non embarquable) ;
  //  * S2 départ 06:10 (T1, terminus ici — non embarquable) et 09:00 (T2).
  //  → bornes documentées du service : premier 06:00, dernier 09:00 ; le
  //    terminus (06:10 à S2 / 09:10 à S1) ne compte JAMAIS.
  // ------------------------------------------------------------------
  GtfsNetwork fixture() => GtfsNetwork.fromJson(
        'TEST',
        jsonEncode(<String, dynamic>{
          'meta': {'source_url': 'test://fixture', 'date_source': '20260101'},
          'agency': 'Test',
          'routes': [
            {'id': 'R1', 'short': '1', 'long': 'Ligne 1', 'type': 3},
          ],
          'stops': [
            ['S1', 'Arrêt A', 14.70, -17.40, 1],
            ['S2', 'Arrêt B', 14.71, -17.41, 1],
          ],
          'services': [
            ['SVC', 127, '20260101', '20261231'], // tous les jours
          ],
          'exceptions': <List<dynamic>>[],
          'trips': [
            // T1 depuis S1 ; T2 depuis S2.
            ['T1', 0, 0, '0', 'B'],
            ['T2', 0, 0, '1', 'A'],
          ],
          'stop_times': [
            [0, 0, 1, 21600, 21600], // T1 @ S1 06:00 (embarquable)
            [0, 1, 2, 22200, 22200], // T1 @ S2 06:10 (terminus)
            [1, 1, 1, 32400, 32400], // T2 @ S2 09:00 (embarquable)
            [1, 0, 2, 33000, 33000], // T2 @ S1 09:10 (terminus)
          ],
        }),
      );

  final DateTime lundi = DateTime.utc(2026, 9, 28); // lundi (fixture: tous les jours)

  group('bornes documentées (fixture déterministe)', () {
    test('premier/dernier départ embarquable, terminus exclu', () {
      final GtfsNetwork net = fixture();
      final NetworkServiceBounds b = net.networkServiceBounds(lundi);
      expect(b.firstSec, 21600, reason: 'premier départ embarquable à 06:00');
      expect(b.lastSec, 32400, reason: 'dernier départ embarquable à 09:00');
      expect(b.dayOffset, 0);
    });

    test('service terminé après le dernier départ documenté', () {
      final GtfsNetwork net = fixture();
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 10, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      expect(a.lastDeparture, DateTime.utc(2026, 9, 28, 9, 0));
      // Reprise : premier départ du lendemain (06:00) moins 1 h → 05:00.
      expect(a.resumptionAt, DateTime.utc(2026, 9, 29, 5, 0));
      expect(a.firstDeparture, DateTime.utc(2026, 9, 29, 6, 0));
      expect(a.isServiceEnded, isTrue);
      expect(a.isUpcomingService, isTrue);
    });

    test('service actif avant le dernier départ', () {
      final GtfsNetwork net = fixture();
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 7, 0),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.active);
      expect(a.resumptionAt, DateTime.utc(2026, 9, 28, 5, 0));
    });

    test('networkServiceBounds sans services actifs → reprise J+1', () {
      // Un service actif le lundi uniquement ; le mardi n'a plus rien, mais le
      // mercredi reprend.
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'TEST2',
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
          // lundi (bit1) et mercredi (bit3) → mask 1 + 4 = 5.
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
      // mardi 2026-09-29 : aucun service actif → reprise mercredi.
      final NetworkServiceBounds b = net.networkServiceBounds(DateTime.utc(2026, 9, 29));
      expect(b.lastSec, 18000, reason: 'dernier départ mercredi 05:00');
      expect(b.dayOffset, 1);
    });

    test('premier départ à minuit (service de nuit) → reprise non inventée', () {
      final GtfsNetwork net = GtfsNetwork.fromJson(
        'NIGHT',
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
            [0, 0, 1, 0, 0], // 00:00 (embarquable)
            [0, 1, 2, 600, 600], // 00:10
          ],
        }),
      );
      final ServiceAvailability a = computeNetworkServiceAvailability(
        network: net,
        at: DateTime.utc(2026, 9, 28, 0, 30),
        isScheduleAvailable: (_) => true,
      );
      expect(a.status, ServiceAvailabilityStatus.serviceEnded);
      // Premier départ à minuit : trop proche de la borne basse du feed pour
      // étayer une heure de reprise — aucune heure n'est inventée.
      expect(a.resumptionAt, isNull);
      expect(a.isUpcomingService, isFalse);
    });

    test('réseau absent / horaires non documentés → inconnu', () {
      expect(
        computeNetworkServiceAvailability(
            network: null, at: lundi, isScheduleAvailable: (_) => true).status,
        ServiceAvailabilityStatus.unknown,
      );
      expect(
        computeNetworkServiceAvailability(
                network: fixture(), at: lundi, isScheduleAvailable: (_) => false)
            .status,
        ServiceAvailabilityStatus.unknown,
      );
    });
  });

  group('réseaux réels (feeds embarqués)', () {
    setUpAll(() async {
      await app.appDataService.loadNetworkData();
      await app.appDataService.loadPassBiSchedules();
      expect(app.appDataService.passBiActive, isTrue);
    });

    test('TER : actif le mardi 12:00, terminé à 23:30', () {
      final ServiceAvailability mid = app.appDataService
          .serviceAvailabilityFor('TER', DateTime.utc(2026, 9, 29, 12, 0));
      expect(mid.status, ServiceAvailabilityStatus.active);

      final ServiceAvailability soir = app.appDataService
          .serviceAvailabilityFor('TER', DateTime.utc(2026, 9, 29, 23, 30));
      expect(soir.status, ServiceAvailabilityStatus.serviceEnded);
      expect(soir.lastDeparture, DateTime.utc(2026, 9, 29, 22, 47, 37));
      // Mercredi premier départ 05:29:59 → reprise 04:29:59.
      expect(soir.resumptionAt, DateTime.utc(2026, 9, 30, 4, 29, 59));
    });

    test('BRT : actif le mardi 12:00, terminé à 23:00', () {
      expect(
        app.appDataService
            .serviceAvailabilityFor('BRT', DateTime.utc(2026, 9, 29, 12, 0))
            .status,
        ServiceAvailabilityStatus.active,
      );
      final ServiceAvailability soir = app.appDataService
          .serviceAvailabilityFor('BRT', DateTime.utc(2026, 9, 29, 23, 0));
      expect(soir.status, ServiceAvailabilityStatus.serviceEnded);
      expect(soir.lastDeparture, DateTime.utc(2026, 9, 29, 21, 55, 1));
      // Mercredi premier départ 06:00:30 → reprise 05:00:30.
      expect(soir.resumptionAt, DateTime.utc(2026, 9, 30, 5, 0, 30));
    });

    test('AFTU : actif le mardi 06:00, terminé à 23:00', () {
      expect(
        app.appDataService
            .serviceAvailabilityFor('AFTU', DateTime.utc(2026, 9, 29, 6, 0))
            .status,
        ServiceAvailabilityStatus.active,
      );
      final ServiceAvailability soir = app.appDataService
          .serviceAvailabilityFor('AFTU', DateTime.utc(2026, 9, 29, 23, 0));
      expect(soir.status, ServiceAvailabilityStatus.serviceEnded);
    });

    test('DDD : borne du réseau à l\'arrêt (service de nuit → pas de reprise inventée)',
        () {
      // DDD roule quasiment 24 h/24 ; à 12:00 le service est actif.
      expect(
        app.appDataService
            .serviceAvailabilityFor('DDD', DateTime.utc(2026, 9, 29, 12, 0))
            .status,
        ServiceAvailabilityStatus.active,
      );
    });

    test('TATA : aucune fin de service inventée (réseau absent du feed)', () {
      final ServiceAvailability a = app.appDataService
          .serviceAvailabilityFor('TATA', DateTime.utc(2026, 9, 29, 23, 0));
      expect(a.status, ServiceAvailabilityStatus.unknown);
      expect(a.reason, ServiceAvailabilityReason.networkAbsentFromFeed);
    });
  });

  group('message « Fin de service » (présentation)', () {
    test('service actif → aucun message', () {
      final ServiceAvailability a = ServiceAvailability.active(
        lastDeparture: DateTime.utc(2026, 9, 29, 22, 47),
      );
      expect(
        app.serviceNoticeFor(a, DateTime.utc(2026, 9, 29, 12, 0)),
        isNull,
      );
    });

    test('service terminé → message avec reprise documentée', () {
      final ServiceAvailability a = ServiceAvailability.serviceEnded(
        lastDeparture: DateTime.utc(2026, 9, 29, 22, 47),
        resumptionAt: DateTime.utc(2026, 9, 30, 4, 29),
        firstDeparture: DateTime.utc(2026, 9, 30, 5, 29),
      );
      final String? notice =
          app.serviceNoticeFor(a, DateTime.utc(2026, 9, 29, 23, 30));
      expect(notice, isNotNull);
      expect(notice!, contains('Fin de service'));
      expect(notice, contains('reprise à 04:29'));
      expect(notice.toLowerCase().contains('0 min'), isFalse);
    });

    test('reprise atteinte → l\'affichage redevient actif (aucun message)', () {
      final ServiceAvailability a = ServiceAvailability.serviceEnded(
        lastDeparture: DateTime.utc(2026, 9, 29, 22, 47),
        resumptionAt: DateTime.utc(2026, 9, 30, 4, 29),
      );
      expect(app.serviceNoticeFor(a, DateTime.utc(2026, 9, 30, 4, 30)), isNull);
    });

    test('service terminé sans reprise documentée → message sans heure inventée',
        () {
      final ServiceAvailability a = ServiceAvailability.serviceEnded(
        lastDeparture: DateTime.utc(2026, 9, 29, 22, 47),
      );
      expect(
        app.serviceNoticeFor(a, DateTime.utc(2026, 9, 29, 23, 30)),
        ServiceAvailability.labelServiceEnded,
      );
    });
  });
}
