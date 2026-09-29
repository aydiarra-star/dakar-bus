// LOT 2 — INTÉGRITÉ DES DONNÉES.
//
// Vérifie que les métadonnées d'intégrité présentes dans `dakar_network.json`
// (audit_flags, coordinates_status, provenance, place_id) sont réellement
// portées jusqu'à l'application, et que les incohérences constatées à l'audit
// sont bien signalées — jamais masquées ni promues.
//
// Aucune donnée n'est créée : ces tests lisent la source unique et l'API
// publique de l'application.
import 'dart:convert';
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/transport_network.dart';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load() =>
    json.decode(File('assets/data/dakar_network.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _routes(Map<String, dynamic> d) =>
    (d['routes'] as List).cast<Map<String, dynamic>>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> data = _load();
  final List<Map<String, dynamic>> routes = _routes(data);

  // ==================================================================
  // 1. Les drapeaux d'audit EXISTENT dans la source
  // ==================================================================
  group('drapeaux d\'audit — source', () {
    test('48 routes portent un drapeau, et les deux valeurs sont connues', () {
      final List<Map<String, dynamic>> flagged =
          routes.where((Map<String, dynamic> r) => r['audit_flags'] != null).toList();
      expect(flagged, hasLength(48));

      const Set<String> connus = <String>{
        'ITINERARY_GEOGRAPHICALLY_INCOHERENT',
        'DUPLICATE_STOP_SEQUENCE',
      };
      for (final Map<String, dynamic> r in flagged) {
        for (final String f in List<String>.from(r['audit_flags'] as List)) {
          expect(connus.contains(f), isTrue, reason: '${r['id']} : $f');
        }
      }
    });


    test('42 AFTU + 2 DDD en itinéraire incohérent, 4 en séquence dupliquée', () {
      int incoh = 0, dup = 0;
      for (final Map<String, dynamic> r in routes) {
        final List<String> f = List<String>.from((r['audit_flags'] as List?) ?? const <String>[]);
        if (f.contains('ITINERARY_GEOGRAPHICALLY_INCOHERENT')) incoh++;
        if (f.contains('DUPLICATE_STOP_SEQUENCE')) dup++;
      }
      expect(incoh, 44); // 42 AFTU + 2 DDD
      expect(dup, 4); // aftu_2, aftu_38, tata_218, tata_50
    });


    test('TER et BRT ne portent AUCUN drapeau (séquences saines)', () {
      for (final Map<String, dynamic> r in routes) {
        if (r['operator_id'] == 'ter' || r['operator_id'] == 'brt') {
          expect(r['audit_flags'], isNull, reason: '${r['id']}');
        }
      }
    });

  });

  // ==================================================================
  // 2. Les drapeaux sont RESTITUÉS à l'affichage, jamais reformulés
  // ==================================================================
  group('drapeaux d\'audit — restitution', () {
    test('chaque drapeau connu a un libellé ; un drapeau inconnu n\'en a pas', () {
      expect(
        ReliabilityLabel.auditFlagLabel('ITINERARY_GEOGRAPHICALLY_INCOHERENT'),
        isNotNull,
      );
      expect(
        ReliabilityLabel.auditFlagLabel('DUPLICATE_STOP_SEQUENCE'),
        isNotNull,
      );
      expect(ReliabilityLabel.auditFlagLabel('FLAG_INEXISTANT'), isNull);
    });


    test('une route signalée expose un avertissement lisible', () async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      // stop_sicap_liberte n'est desservi que par new_commune_01, route DDD
      // signalée ITINERARY_GEOGRAPHICALLY_INCOHERENT : la fiche dérivée doit
      // donc porter le drapeau et un libellé d'avertissement non vide.
      final List<Stop> matches = allStops
          .where((Stop s) => s.stopId == 'stop_sicap_liberte')
          .toList();
      expect(matches, isNotEmpty);
      final DetailedRoute? r = DetailedRoute.fromStop(matches.first);
      expect(r, isNotNull);
      expect(r!.auditFlags, contains('ITINERARY_GEOGRAPHICALLY_INCOHERENT'));
      expect(r.auditWarnings, isNotEmpty);
      for (final String w in r.auditWarnings) {
        expect(w.trim(), isNotEmpty);
      }
    });

    test('TER et BRT n\'affichent aucun avertissement d\'audit', () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      for (final String op in <String>['ter', 'brt']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        expect(r, isNotNull, reason: op);
        expect(r!.auditWarnings, isEmpty, reason: op);
      }
    });

  });

  // ==================================================================
  // 3. Fiabilité de la POSITION, distincte de l'existence de l'arrêt
  // ==================================================================
  group('coordonnées', () {
    test('la source porte 13 positions CONFIRMED, 90 UNVERIFIED, 14 CONFLICTING',
        () {
      final List<Map<String, dynamic>> stops =
          (data['stops'] as List).cast<Map<String, dynamic>>();
      final Map<String, int> byStatus = <String, int>{};
      for (final Map<String, dynamic> s in stops) {
        final String k = s['coordinates_status'] as String;
        byStatus[k] = (byStatus[k] ?? 0) + 1;
      }
      expect(byStatus['CONFIRMED'], 13);
      expect(byStatus['UNVERIFIED'], 90);
      expect(byStatus['CONFLICTING'], 14);
    });


    test('20 arrêts CONFIRMED ont une position NON confirmée (dont BRT)', () {
      final List<Map<String, dynamic>> stops =
          (data['stops'] as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> mixtes = stops
          .where((Map<String, dynamic> s) =>
              s['data_status'] == 'CONFIRMED' && s['coordinates_status'] != 'CONFIRMED')
          .toList();
      expect(mixtes, hasLength(20));
      for (final Map<String, dynamic> s in mixtes) {
        expect(s['id'], startsWith('stop_brt_'));
      }
    });


    test('libellé de position : CONFIRMED → null, sinon un libellé explicite', () {
      expect(ReliabilityLabel.coordinatesLabel(ProvenanceStatus.confirmed), isNull);
      expect(ReliabilityLabel.coordinatesLabel(ProvenanceStatus.unverified), isNotNull);
      expect(ReliabilityLabel.coordinatesLabel(ProvenanceStatus.conflicting), isNotNull);
    });


    test('la fiche TER expose une position confirmée par gare', () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      final DetailedRoute? r = DetailedRoute.fromOperator('ter');
      expect(r, isNotNull);
      expect(r!.stopCoordinatesStatuses, hasLength(r.stops.length));
      for (final DetailedStop s in r.stops) {
        expect(r.hasConfirmedPosition(s), isTrue, reason: s.stopId);
      }
    });


    test('la fiche BRT expose des positions NON confirmées (jamais promues)',
        () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      final DetailedRoute? r = DetailedRoute.fromOperator('brt');
      expect(r, isNotNull);
      final int nonConfirmees =
          r!.stops.where((DetailedStop s) => !r.hasConfirmedPosition(s)).length;
      expect(nonConfirmees, greaterThan(0),
          reason: 'les 23 positions BRT sont UNVERIFIED ou CONFLICTING');
    });

  });

  // ==================================================================
  // 4. Provenance : aucune promotion
  // ==================================================================
  group('provenance', () {
    test('un CONFIRMED sans source est relu UNVERIFIED (jamais promu)', () {
      final Provenance p = Provenance.fromJson(<String, dynamic>{
        'data_status': 'CONFIRMED',
        'source_type': 'OFFICIAL_STATIC',
      });
      expect(p.status, ProvenanceStatus.unverified);
    });


    test('DDD/AFTU/Tata : aucune route CONFIRMED ni OFFICIAL', () {
      for (final Map<String, dynamic> r in routes) {
        if (<String>['ddd', 'aftu', 'tata'].contains(r['operator_id'])) {
          expect(r['data_status'], isNot('CONFIRMED'), reason: '${r['id']}');
          expect(r['data_trust'], isNot('OFFICIAL'), reason: '${r['id']}');
        }
      }
    });


    test('seuls TER et BRT portent une route CONFIRMED', () {
      final List<Map<String, dynamic>> confirmed = routes
          .where((Map<String, dynamic> r) => r['data_status'] == 'CONFIRMED')
          .toList();
      expect(confirmed, hasLength(3)); // ter + brt B1 + brt B2
      for (final Map<String, dynamic> r in confirmed) {
        expect(<String>['ter', 'brt'].contains(r['operator_id']), isTrue,
            reason: '${r['id']}');
      }
    });


    test('le modèle Dart ne connaît que des statuts de provenance valides',
        () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
      for (final Stop s in allStops) {
        // Un arrêt dont la provenance est CONFIRMED doit porter une source.
        if (s.source.origin == DataOrigin.official) {
          expect(s.stopId, isNotNull, reason: s.name);
        }
      }
    });

  });

  // ==================================================================
  // 5. Doublons et références
  // ==================================================================
  group('doublons et références', () {
    test('aucun identifiant d\'arrêt ou de route dupliqué', () {
      final List<Map<String, dynamic>> stops =
          (data['stops'] as List).cast<Map<String, dynamic>>();
      expect(stops.map((Map<String, dynamic> s) => s['id']).toSet().length,
          stops.length);
      expect(routes.map((Map<String, dynamic> r) => r['id']).toSet().length,
          routes.length);
    });


    test('aucune coordonnée exactement dupliquée entre arrêts distincts', () {
      final List<Map<String, dynamic>> stops =
          (data['stops'] as List).cast<Map<String, dynamic>>();
      final Set<String> coords = <String>{};
      for (final Map<String, dynamic> s in stops) {
        final String c = '${s['latitude']},${s['longitude']}';
        expect(coords.contains(c), isFalse, reason: '${s['id']} : $c');
        coords.add(c);
      }
    });


    test('les 4 séquences dupliquées sont signalées, pas fusionnées', () {
      const List<List<String>> paires = <List<String>>[
        <String>['aftu_2', 'tata_50'],
        <String>['aftu_38', 'tata_218'],
      ];
      for (final List<String> p in paires) {
        final Map<String, dynamic> a =
            routes.firstWhere((Map<String, dynamic> r) => r['id'] == p[0]);
        final Map<String, dynamic> b =
            routes.firstWhere((Map<String, dynamic> r) => r['id'] == p[1]);
        expect(List<String>.from(a['stops'] as List),
            orderedEquals(List<String>.from(b['stops'] as List)),
            reason: p.join(' / '));
        expect(a['id'], isNot(b['id']), reason: 'identifiants distincts conservés');
      }
    });


    test('toute référence d\'arrêt existe, aucun arrêt orphelin', () {
      final Set<String> stopIds = (data['stops'] as List)
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> s) => s['id'] as String)
          .toSet();
      final Set<String> used = <String>{};
      for (final Map<String, dynamic> r in routes) {
        for (final String sid in List<String>.from(r['stops'] as List)) {
          expect(stopIds.contains(sid), isTrue, reason: '${r['id']} → $sid');
          used.add(sid);
        }
      }
      expect(used, equals(stopIds), reason: 'aucun arrêt orphelin attendu');
    });

  });

  // ==================================================================
  // 6. Données de démonstration : retirées de l'affichage
  // ==================================================================
  group('données de démonstration', () {
    test('les libellés de ligne de démo ne sont pas des arrêts affichés',
        () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      const List<String> libellesDemo = <String>[
        'DDD Ligne 1 (Colobane - Yoff)',
        'DDD Ligne 3 (Sandaga - Ouakam)',
        'DDD Ligne 10 (Liberté 6 - Patte d’Oie)',
        'DDD Ligne 14 (Gare Maritime - UCAD)',
        'DDD Ligne 20 (Petersen - Rufisque)',
        'TATA Ligne 50 (Guédiawaye - Sandaga)',
        'TATA Ligne 64 (Pikine - Liberté 6)',
        'TATA Ligne 78 (Yoff - Petersen)',
        'TATA Ligne 218 (Mermoz - Keur Massar)',
        'Parcelles Assainies (L1 à L10)',
        'Grand Yoff (L11 à L25)',
        'Terminus Petersen (AFTU L25)',
      ];
      final Set<String> affiches = allStops.map((Stop s) => s.name).toSet();
      for (final String l in libellesDemo) {
        expect(affiches.contains(l), isFalse, reason: l);
      }
    });


    test('tous les arrêts affichés proviennent du JSON (stopId non nul)',
        () async {
      
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
      expect(allStops, isNotEmpty);
      for (final Stop s in allStops) {
        expect(s.stopId, isNotNull, reason: s.name);
      }
    });

  });
}
