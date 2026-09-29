// Lot 4.22 — EXPLORER : prochains passages RÉELS — verrous.
//
// Objectif : pour chaque arrêt disposant de vrais horaires, afficher
// « [Nom station] [MODE] vers [Destination] » puis immédiatement les 3
// prochains temps d'attente RÉELS (« 1 mn · 10 mn · 15 mn »).
//
// Règles absolues testées ici :
//  * les minutes proviennent UNIQUEMENT de vrais trips + stop_times
//    (aucune fréquence convertie en horaires, aucun départ estimé, aucun
//    départ fictif issu d'une heure d'ouverture) ;
//  * arrondi VERS LE HAUT : ceil(waitSeconds / 60) — jamais 0 mn (moins
//    d'une minute mais futur → 1 mn), un départ passé est ignoré ;
//  * 3 passages au maximum, avance « juste après » chaque passage réel
//    (jamais par fréquence), dayOffset respecté (secondes absolues) ;
//  * « Dir. Petersen » → « vers Petersen » ; direction inconnue → aucun
//    « vers » inventé ;
//  * TATA : zéro passage fabriqué (aucun feed).
//
// Données de test = feeds PassBi RÉELS (aucune donnée de transport créée) :
// le feed TER contient un motif réel 07:35 / 07:42 / 07:47 (Dakar - Gare
// ferroviaire) qui produit exactement « 3 mn · 10 mn · 15 mn » à 07:32.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_display.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/data_provider.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Arrêt réel du feed TER (Dakar - Gare ferroviaire), lundi 2026-09-28.
  const String terGare =
      '544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';
  final DateTime lundi0732 = DateTime.utc(2026, 9, 28, 7, 32);

  ScheduleProvider provider() => app.appDataService.scheduleProvider;

  setUpAll(() async {
    await app.appDataService.loadNetworkData();
    await app.appDataService.loadPassBiSchedules();
    expect(app.appDataService.passBiActive, isTrue,
        reason: 'PassBi est la source opérationnelle');
  });

  // ==================================================================
  // Test 1 — trois vrais passages : 3 mn · 10 mn · 15 mn
  // ==================================================================
  group('Test 1 — trois vrais stop_times → « 3 mn · 10 mn · 15 mn »', () {
    test('TER Dakar - Gare ferroviaire : 07:35 / 07:42 / 07:47 à 07:32', () {
      final List<DepartureInfo> list = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: lundi0732,
      );
      expect(list.length, 3);
      expect(list[0].scheduledTime, DateTime.utc(2026, 9, 28, 7, 35));
      expect(list[1].scheduledTime, DateTime.utc(2026, 9, 28, 7, 42));
      expect(list[2].scheduledTime, DateTime.utc(2026, 9, 28, 7, 47));
      for (final DepartureInfo info in list) {
        expect(info.status, ScheduleStatus.scheduled);
        expect(info.frequencyMinutes, isNull,
            reason: 'un passage réel n\'a jamais de fréquence');
        expect(info.scheduledTime, isNotNull);
      }
      final List<int> waits = <int>[];
      for (final DepartureInfo info in list) {
        waits.add(waitingMinutesBetween(info.scheduledTime!, lundi0732)!);
      }
      expect(waits, <int>[3, 10, 15]);
      expect(formatWaitingMinutes(waits), '3 mn · 10 mn · 15 mn');
    });
  });

  // ==================================================================
  // Test 2 — aucun zéro : moins d'une minute → 1 mn
  // ==================================================================
  group('Test 2 — jamais 0 mn (arrondi vers le haut)', () {
    test('18:02:30 pour un départ 18:03 → 1 mn', () {
      expect(
          waitingMinutesBetween(DateTime.utc(2026, 9, 28, 18, 3),
              DateTime.utc(2026, 9, 28, 18, 2, 30)),
          1);
      expect(formatWaitingMinutes(<int>[1]), '1 mn');
      // Arrondi vers le haut : 3 min 10 s → 4 ; 3 min 50 s → 4 ; 5 min 00 s → 5.
      expect(
          waitingMinutesBetween(DateTime.utc(2026, 9, 28, 18, 3, 10),
              DateTime.utc(2026, 9, 28, 18, 0)),
          4);
      expect(
          waitingMinutesBetween(DateTime.utc(2026, 9, 28, 18, 3, 50),
              DateTime.utc(2026, 9, 28, 18, 0)),
          4);
      expect(
          waitingMinutesBetween(
              DateTime.utc(2026, 9, 28, 18, 5), DateTime.utc(2026, 9, 28, 18, 0)),
          5);
      // Un départ à l'instant présent : 1 mn, jamais 0 mn.
      expect(
          waitingMinutesBetween(
              DateTime.utc(2026, 9, 28, 18, 0), DateTime.utc(2026, 9, 28, 18, 0)),
          1);
    });

    test('réel : à 07:34:30, le départ 07:35 affiche 1 mn (jamais 0 mn)', () {
      final DateTime at = DateTime.utc(2026, 9, 28, 7, 34, 30);
      final List<DepartureInfo> list = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: at,
      );
      expect(list.first.scheduledTime, DateTime.utc(2026, 9, 28, 7, 35));
      final int? w = waitingMinutesBetween(list.first.scheduledTime!, at);
      expect(w, 1);
      expect(formatWaitingMinutes(<int>[w!]), '1 mn');
    });
  });

  // ==================================================================
  // Test 3 — départ passé : jamais retourné
  // ==================================================================
  group('Test 3 — un stop_time passé n\'est jamais retourné', () {
    test('17:59 n\'apparaît jamais à 18:00 ; 07:35 jamais à 07:36', () {
      expect(
          waitingMinutesBetween(DateTime.utc(2026, 9, 28, 17, 59),
              DateTime.utc(2026, 9, 28, 18, 0)),
          isNull,
          reason: 'un départ déjà passé est ignoré');
      final DateTime at = DateTime.utc(2026, 9, 28, 7, 36);
      final List<DepartureInfo> list = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: at,
      );
      expect(list, isNotEmpty);
      expect(list.first.scheduledTime, DateTime.utc(2026, 9, 28, 7, 42),
          reason: 'le stop_time 07:35, déjà passé à 07:36, est ignoré');
      for (final DepartureInfo info in list) {
        expect(info.scheduledTime!.isBefore(at), isFalse);
      }
    });
  });

  // ==================================================================
  // Test 4 — fréquence seule : aucune série fabriquée
  // ==================================================================
  group('Test 4 — une fréquence ne devient jamais une série de départs', () {
    test('fréquence 6 min : ESTIMATED, aucun horaire, jamais « 6 · 12 · 18 »', () {
      FrequencySource? src;
      FrequencyWindow? w6;
      for (final FrequencySource s in DataProvider.officialFrequencySources) {
        for (final FrequencyWindow w in s.frequencies) {
          if (w.frequencyMinutes == 6) {
            src = s;
            w6 = w;
            break;
          }
        }
        if (w6 != null) break;
      }
      expect(w6, isNotNull,
          reason: 'le projet publie une fréquence officielle de 6 min');
      final DepartureInfo estimated =
          DepartureInfo.fromFrequency(src!, w6!, DateTime.utc(2026, 9, 28, 8, 0));
      expect(estimated.status, ScheduleStatus.estimated);
      expect(estimated.frequencyMinutes, 6);
      expect(estimated.scheduledTime, isNull,
          reason: 'une fréquence ne contient AUCUN départ fixe');

      // Route sans aucun stop_time exploitable (aftu_8, identité non
      // confirmée) : le pipeline Explorer retourne une liste VIDE — jamais
      // une série « 6 mn · 12 mn · 18 mn » fabriquée depuis la fréquence.
      final DateTime at8 = DateTime.utc(2026, 9, 28, 8, 0);
      expect(
          provider().nextDeparturesAt(
              routeId: 'aftu_8', stopId: 'stop_yoff', requestedAt: at8),
          isEmpty);
      expect(
          app.appDataService.nextDeparturesFor(
              routeId: 'aftu_8',
              stopId: 'stop_yoff',
              network: 'AFTU',
              at: at8),
          isEmpty);
      final app.Stop stopFrequence = app.Stop(
        name: 'Yoff',
        stopId: 'stop_yoff',
        scheduleRouteId: 'aftu_8',
        direction: 'Dir. test',
        distanceMeters: 0,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_bus,
        color: const Color(0xFF00A651),
        location: const LatLng(14.74, -17.47),
        modeLabel: 'AFTU',
      );
      expect(stopFrequence.nextRealDepartures(at: at8), isEmpty);
      expect(stopFrequence.nextRealWaitingMinutes(at: at8), isEmpty,
          reason: 'aucun « 6 mn · 12 mn · 18 mn » issu d\'une fréquence');
    });
  });

  // ==================================================================
  // Test 5 — maximum 3 passages
  // ==================================================================
  group('Test 5 — plafond de 3 passages', () {
    test('10 départs disponibles → 3 au plus', () {
      final List<DepartureInfo> trois = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: lundi0732,
      );
      expect(trois.length, 3,
          reason: '3 passages au maximum, même si la suite existe (07:54, 08:06…)');
      final List<DepartureInfo> cinq = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: lundi0732,
        limit: 5,
      );
      expect(cinq.length, 5,
          reason: 'la suite réelle existe bien : le plafond est le seul filtre');
      expect(
          cinq.take(3).map((DepartureInfo i) => i.scheduledTime).toList(),
          trois.map((DepartureInfo i) => i.scheduledTime).toList());
    });
  });

  // ==================================================================
  // Test 6 — direction : « Dir. Petersen » → « vers Petersen »
  // ==================================================================
  group('Test 6 — « Dir. Petersen » rendu « vers Petersen », sans duplication', () {
    test('normalisation', () {
      expect(normalizeDirectionLabel('Dir. Petersen'), 'vers Petersen');
      expect(normalizeDirectionLabel('vers Petersen'), 'vers Petersen');
      expect(normalizeDirectionLabel('Dir. vers Petersen'), 'vers Petersen');
      expect(normalizeDirectionLabel('Direction Petersen'), 'vers Petersen');
    });

    test('en-tête : « Sacré-Cœur BRT vers Petersen »', () {
      final String header =
          formatStopHeader('Sacré-Cœur', 'BRT', 'Dir. Petersen');
      expect(header, 'Sacré-Cœur BRT vers Petersen');
      expect(header.split('vers Petersen').length, 2,
          reason: 'une seule occurrence de la destination');
      expect(header.contains('Dir.'), isFalse,
          reason: 'le préfixe « Dir. » ne survit jamais à la normalisation');
      // Le MODE déjà présent dans le nom n\'est jamais dupliqué.
      expect(formatStopHeader('Sacré-Cœur - BRT', 'BRT', 'Dir. Petersen'),
          'Sacré-Cœur - BRT vers Petersen');
      // Headsign réel du feed BRT (« PETERSEN ») : lisible, donnée inchangée.
      expect(formatStopHeader('Sacré-Cœur', 'BRT', 'PETERSEN'),
          'Sacré-Cœur BRT vers Petersen');
    });
  });

  // ==================================================================
  // Test 7 — direction inconnue : aucune destination inventée
  // ==================================================================
  group('Test 7 — direction inconnue : jamais de « vers » inventé', () {
    test('null / vide / préfixe seul → null', () {
      expect(normalizeDirectionLabel(null), isNull);
      expect(normalizeDirectionLabel(''), isNull);
      expect(normalizeDirectionLabel('   '), isNull);
      expect(normalizeDirectionLabel('Dir.'), isNull);
    });

    test('libellé d\'arrêt non-directionnel → refusé', () {
      expect(
          normalizeDirectionLabel('3 lignes PassBi DDD',
              requireDirPrefix: true),
          isNull,
          reason: 'un nombre de lignes n\'est pas une destination');
      expect(
          normalizeDirectionLabel('Terminus central AFTU',
              requireDirPrefix: true),
          isNull);
      expect(normalizeDirectionLabel('Ligne PassBi DDD_217', requireDirPrefix: true),
          isNull);
    });

    test('en-tête : « Liberté 6 DDD » seul', () {
      expect(formatStopHeader('Liberté 6', 'DDD', null), 'Liberté 6 DDD');
      expect(
          formatStopHeader('Liberté 6', 'DDD', '3 lignes PassBi DDD',
              requireDirPrefix: true),
          'Liberté 6 DDD');
      expect(formatStopHeader('Liberté 6', 'DDD', null).contains('vers'),
          isFalse);
    });
  });

  // ==================================================================
  // Verrous complémentaires : TATA, dayOffset, réseaux
  // ==================================================================
  group('Verrous — TATA, dayOffset, DDD/AFTU natifs', () {
    test('TATA : zéro passage fabriqué (aucun feed)', () {
      expect(
          provider().nextDeparturesAtPassBiStop(
              networkKey: 'TATA', pbStopId: 'X', requestedAt: lundi0732),
          isEmpty);
      expect(app.appDataService.passBiNetworkAvailability('TATA'),
          PassBiNetworkAvailability.absentFromFeed);
    });

    test('dayOffset : passage de minuit → J+1 en secondes absolues', () {
      final List<DepartureInfo> list = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: DateTime.utc(2026, 9, 28, 23, 59),
      );
      expect(list, isNotEmpty);
      expect(list.first.scheduledTime, DateTime.utc(2026, 9, 29, 5, 30),
          reason: 'le service du lendemain, jamais comparé en minutes HH:mm');
      final List<({int sec, String routeId, String tripId, int dayOffset})>
          records = app.appDataService.passBiSource.nextNativeDepartures(
        networkKey: 'TER',
        pbStopId: terGare,
        at: DateTime.utc(2026, 9, 28, 23, 59),
      );
      expect(records.first.dayOffset, 1,
          reason: 'dayOffset du feed respecté (service J+1)');
    });

    test('DDD & AFTU : jusqu\'à 3 passages réels sur les arrêts natifs', () {
      for (final String netKey in <String>['DDD', 'AFTU']) {
        bool found = false;
        for (final ref in app.appDataService.passBiNativeStops(netKey).take(200)) {
          final List<String>? parts = PassBiSource.splitComposite(ref.compositeKey);
          if (parts == null) continue;
          final List<DepartureInfo> list =
              provider().nextDeparturesAtPassBiStop(
            networkKey: parts[0],
            pbStopId: parts[1],
            requestedAt: DateTime.utc(2026, 9, 28, 8, 0),
          );
          if (list.isEmpty) continue;
          found = true;
          expect(list.length, lessThanOrEqualTo(3));
          for (final DepartureInfo info in list) {
            expect(info.status, ScheduleStatus.scheduled);
            expect(info.frequencyMinutes, isNull);
          }
          break;
        }
        expect(found, isTrue,
            reason: '$netKey : au moins un arrêt natif expose un passage réel');
      }
    });

    test('aucun passage retourné ne porte de fréquence ni de REAL_TIME', () {
      final List<DepartureInfo> list = provider().nextDeparturesAtPassBiStop(
        networkKey: 'TER',
        pbStopId: terGare,
        requestedAt: lundi0732,
      );
      for (final DepartureInfo info in list) {
        expect(info.status, isNot(ScheduleStatus.realTime));
        expect(info.status, isNot(ScheduleStatus.estimated));
        expect(info.frequencyMinutes, isNull);
        expect(info.unresolvedReason, isNull);
      }
    });
  });
}
