import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/transport_network.dart';

/// INTÉGRATION CANONIQUE AFTU / TATA / DDD — LOT 1 (2026-09-25).
///
/// Source de référence : `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md`
/// (résolution) et `docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md` (audit).
/// Périmètre autorisé : `docs/AUDIT_IMPACT_INTEGRATION_REFERENTIEL_2026-09-25.md`.
///
/// Ce fichier transporte le STATUT DOCUMENTAIRE du référentiel canonique et
/// interdit toute promotion implicite. Règles figées ici :
///  * aucune route AFTU/Tata/DDD n'est CONFIRMED : elles restent CONFLICTING ou
///    UNVERIFIED (aucun arbitrage de conflit n'a été rendu) ;
///  * aucune fréquence n'est créée : `frequency_status = UNKNOWN` partout et le
///    registre de fréquences (TER/BRT) reste strictement inchangé ;
///  * une description d'itinéraire AFTU (`ROUTE_DOCUMENTED`) n'est JAMAIS une
///    liste d'arrêts : aucune séquence d'arrêts n'est ajoutée ;
///  * les lignes AFTU 84–89 et 91 n'ont AUCUN itinéraire publié
///    (`ROUTE_NOT_FOUND`) : aucun itinéraire n'est inventé ;
///  * les premiers/derniers départs connus (DDD 1, TAF TAF, Express AIBD) sont
///    documentés dans le bloc `canonical_referentiel` et ne sont rattachés à
///    AUCUNE route du jeu de données : ils ne peuvent alimenter ni l'UI ni le
///    moteur de départs.

Map<String, dynamic> _raw() => jsonDecode(
    File('assets/data/dakar_network.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _routes() =>
    (_raw()['routes'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _canonical() =>
    _raw()['canonical_referentiel'] as Map<String, dynamic>;

List<Map<String, dynamic>> _routesOf(String operator) =>
    _routes().where((Map<String, dynamic> r) => r['operator_id'] == operator).toList();

Iterable<Map<String, dynamic>> _afuTataDdd() sync* {
  for (final String op in <String>['aftu', 'tata', 'ddd']) {
    yield* _routesOf(op);
  }
}

void main() {
  group('Bloc canonique — périmètre officiel déclaré', () {
    test('le bloc `canonical_referentiel` décrit les 3 réseaux et ses règles', () {
      final Map<String, dynamic> c = _canonical();
      expect(c['version'], '2026-09-25');
      expect(c['source_document'], contains('REFERENTIEL_CANONIQUE_AFTU_TATA_DDD'));
      expect((c['rules'] as List), hasLength(7),
          reason: 'les 7 règles de non-invention sont déclarées dans la donnée');

      final Map<String, dynamic> aftu = c['aftu_official'] as Map<String, dynamic>;
      expect(aftu['published_line_count'], 72);
      expect(aftu['route_page_count'], 65);
      expect(aftu['lines_without_route_page'], <int>[84, 85, 86, 87, 88, 89, 91]);
      expect(aftu['stops_published'], 0, reason: 'AFTU ne publie aucun arrêt');
      expect(aftu['schedules_published'], 0);
      expect(aftu['frequencies_published'], 0);

      final Map<String, dynamic> ddd = c['ddd_official'] as Map<String, dynamic>;
      expect(ddd['published_identifier_count'], 48);
      expect(ddd['route_blocks_with_stops'], 39);
      expect(ddd['frequencies_published'], 0);
      expect(ddd['conflicting_identifiers'], <int>[6, 23, 208, 217, 218, 232, 233, 501]);

      final Map<String, dynamic> tata = c['tata'] as Map<String, dynamic>;
      expect(tata['published_network'], isFalse,
          reason: '« Tata » est une catégorie de service AFTU, pas un réseau');
      expect(tata['identities_in_dataset'], 7);
      expect(tata['model'], contains('service_category=TATA'));
    });

    test('la collision AFTU 5 / 25 est tranchée : deux lignes conservées', () {
      final Map<String, dynamic> collision = (_canonical()['aftu_official']
          as Map<String, dynamic>)['collision_5_25'] as Map<String, dynamic>;
      expect(collision['status'], 'NOT_A_DUPLICATE');
      expect(collision['decision'], contains('conservées'));
      expect((collision['sources'] as List), hasLength(3));
      final List<dynamic> descs = (_canonical()['aftu_official']
          as Map<String, dynamic>)['route_descriptions_verified'] as List<dynamic>;
      expect(descs, hasLength(2));
      for (final dynamic d in descs) {
        expect((d as Map<String, dynamic>)['nature'], 'ROUTE_DOCUMENTED',
            reason: 'une description de rues reste une description de rues');
      }
    });
  });

  group('Statuts préservés — aucune promotion', () {
    test('aucune route AFTU/Tata/DDD ne porte un statut confirmé ou partiel', () {
      for (final Map<String, dynamic> r in _afuTataDdd()) {
        expect(<String>['CONFLICTING', 'UNVERIFIED'], contains(r['canonical_status']),
            reason: '${r['id']} : le référentiel canonique ne confirme aucune '
                'identité AFTU/Tata/DDD — le statut doit rester transporté tel quel');
      }
    });

    test('répartition exacte des statuts (AFTU 54/26, Tata 7, DDD 13/2)', () {
      int count(String op, String status) => _routesOf(op)
          .where((Map<String, dynamic> r) => r['canonical_status'] == status)
          .length;
      expect(count('aftu', 'CONFLICTING'), 54);
      expect(count('aftu', 'UNVERIFIED'), 26);
      expect(count('tata', 'CONFLICTING'), 7);
      expect(count('ddd', 'CONFLICTING'), 13);
      expect(count('ddd', 'UNVERIFIED'), 2);
      expect(_routesOf('ter').length, 1);
      expect(_routesOf('brt').length, 2);
    });

    test('chaque route CONFLICTING porte un motif et ses sources', () {
      for (final Map<String, dynamic> r in _afuTataDdd()) {
        if (r['canonical_status'] != 'CONFLICTING') continue;
        expect(r['conflict_reason'], isA<String>(), reason: '${r['id']}');
        expect((r['conflict_reason'] as String).isNotEmpty, isTrue, reason: '${r['id']}');
        expect((r['conflict_sources'] as List), isNotEmpty, reason: '${r['id']}');
      }
    });

    test('les identités Tata possibles-match ne sont PAS rattachées à une ligne AFTU', () {
      final List<Map<String, dynamic>> tata = _routesOf('tata');
      final Map<String, dynamic> t78 =
          tata.firstWhere((Map<String, dynamic> r) => r['id'] == 'tata_78');
      expect(t78['match_class'], 'POSSIBLE_MATCH');
      expect(t78['possible_match_candidates'], contains('AFTU 3'));
      expect(t78.containsKey('remapped_to'), isFalse);
      expect(t78.containsKey('line_id'), isFalse);
      final Map<String, dynamic> t219 =
          tata.firstWhere((Map<String, dynamic> r) => r['id'] == 'tata_219');
      expect(t219['possible_match_candidates'], contains('AFTU 25'));
      expect(t219['service_category'], 'TATA');
      for (final Map<String, dynamic> r in tata) {
        expect(r['service_category'], 'TATA', reason: '${r['id']}');
      }
    });
  });

  group('Horaires et fréquences — aucune invention', () {
    test('aucune route ne porte d_horaire en propre', () {
      for (final Map<String, dynamic> r in _routes()) {
        expect(r.containsKey('first_departure'), isFalse, reason: '${r['id']}');
        expect(r.containsKey('last_departure'), isFalse, reason: '${r['id']}');
        expect(r.containsKey('departure_times'), isFalse, reason: '${r['id']}');
      }
    });

    test('frequency_status = UNKNOWN pour AFTU, Tata et DDD', () {
      for (final Map<String, dynamic> r in _afuTataDdd()) {
        expect(r['frequency_status'], 'UNKNOWN', reason: '${r['id']}');
      }
    });

    test('le registre de fréquences reste strictement inchangé (TER/BRT seulement)', () {
      final File file = File('assets/data/departure-frequencies.json');
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync().length, 12018,
          reason: 'aucune fréquence AFTU/Tata/DDD ajoutée au registre');
      final Map<String, dynamic> reg =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> freqs = reg['frequencies'] as List<dynamic>;
      expect(freqs, hasLength(5));
      final Set<String> networks = freqs
          .map((dynamic f) => (f as Map<String, dynamic>)['network'] as String)
          .toSet();
      expect(networks, <String>{'TER', 'BRT'},
          reason: 'le registre ne contient que TER et BRT');
    });

    test('les horaires connus sont documentés hors routes et non rattachables', () {
      final List<dynamic> schedules = _canonical()['schedules'] as List<dynamic>;
      expect(schedules, hasLength(7));

      for (final dynamic entry in schedules) {
        final Map<String, dynamic> s = entry as Map<String, dynamic>;
        expect(s.containsKey('route_id'), isFalse);
        expect(s.containsKey('line_id'), isFalse);
        expect(s.containsKey('id'), isFalse);
        expect(s['frequency_status'], 'UNKNOWN', reason: '${s['service']}');
        expect(s['attribution'], isA<String>());
        expect(s['source_url'], isA<String>());
        expect(s['verified_at'], '2026-09-25');
      }

      final List<Map<String, dynamic>> ddd1 = schedules
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> s) => s['service'] == 'Ligne 1 (urbaine)')
          .toList();
      expect(ddd1, hasLength(2), reason: 'deux terminus documentés pour DDD 1');
      expect(ddd1.map((Map<String, dynamic> s) => s['first_departure']),
          containsAll(<String>['05:30', '06:30']));

      final List<Map<String, dynamic>> taftaf = schedules
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> s) => s['service'] == 'TAF TAF')
          .toList();
      expect(taftaf, hasLength(4), reason: '4 paires de premiers/derniers départs');
      for (final Map<String, dynamic> s in taftaf) {
        expect(s['attribution'], contains('jamais reporté'),
            reason: 'TAF TAF reste dans sa propre catégorie de service');
      }

      final Map<String, dynamic> express = schedules
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> s) => s['service'] == 'Express AIBD');
      expect(express['amplitude'], contains('24 h/24'));
      expect(express['first_departure'], isNull,
          reason: 'une amplitude de service n_est pas une grille horaire');
    });
  });

  group('Itinéraires — la description de rues n_est jamais une liste d_arrêts', () {
    test('aucune route AFTU ne prétend porter une séquence d_arrêts publiée', () {
      for (final Map<String, dynamic> r in _routesOf('aftu')) {
        expect(<String>['ROUTE_DOCUMENTED', 'ROUTE_NOT_FOUND'],
            contains(r['official_route_documentation']),
            reason: '${r['id']} : STOP_SEQUENCE_CONFIRMED est interdit pour AFTU');
      }
    });

    test('aucun arrêt n_a été ajouté : paires (route, arrêt) gelées', () {
      int pairs(String op) => _routesOf(op)
          .fold<int>(0, (int acc, Map<String, dynamic> r) =>
              acc + (r['stops'] as List).length);
      expect(pairs('ter'), 13);
      expect(pairs('brt'), 30);
      expect(pairs('ddd'), 68);
      expect(pairs('aftu'), 325,
          reason: 'AFTU : 0 arrêt publié, donc 0 arrêt ajouté');
      expect(pairs('tata'), 28);
      expect(_raw()['stops'], hasLength(117));
      expect(_raw()['routes'], hasLength(105));
    });

    test('les lignes AFTU 84–89 et 91 restent sans itinéraire', () {
      final List<dynamic> noPage =
          (_canonical()['aftu_official'] as Map<String, dynamic>)['lines_without_route_page']
              as List<dynamic>;
      expect(noPage, <int>[84, 85, 86, 87, 88, 89, 91]);
      // Aucune route du jeu de données ne revendique ces numéros.
      for (final Map<String, dynamic> r in _routesOf('aftu')) {
        expect(noPage, isNot(contains(r['official_line_number'])),
            reason: '${r['id']} : aucun itinéraire ne peut être inventé');
      }
      // Les lignes 73–83 ont un itinéraire publié mais aucune route interne :
      // elles ne sont donc pas dans `lines_without_route_page`.
      for (final int n in <int>[73, 83]) {
        expect(noPage, isNot(contains(n)));
      }
    });

    test('les variantes DDD sans itinéraire ne sont pas rattachées à une route', () {
      final List<dynamic> variants =
          (_canonical()['ddd_official'] as Map<String, dynamic>)['identifiers_without_route']
              as List<dynamic>;
      expect(variants, <String>['15A', '15B', '502A', '502B', '503A', '503B', '504A', '504B', 'TAF TAF']);
      final List<String> dddIds =
          _routesOf('ddd').map((Map<String, dynamic> r) => r['id'] as String).toList();
      for (final dynamic v in variants) {
        expect(dddIds, isNot(contains(v)),
            reason: '$v : aucune route ne doit être créée sans itinéraire publié');
      }
    });
  });

  group('Fail-closed du modèle — une donnée ne se promeut pas toute seule', () {
    test('CONFIRMED sans source ni date est lu UNVERIFIED', () {
      final TransportRoute route = TransportRoute.fromJson(<String, dynamic>{
        'id': 'test_canonique_confirmed_sans_source',
        'operator_id': 'aftu',
        'short_name': 'TEST',
        'long_name': 'Test canonique',
        'type': 'BUS',
        'data_trust': 'OFFICIAL',
        'data_status': 'CONFIRMED',
        'source_type': 'OFFICIAL_STATIC',
        'source': null,
        'verified_at': null,
        'schedule_status': 'UNKNOWN',
        'stops': <String>[],
      });
      expect(route.provenance.status, ProvenanceStatus.unverified);
      expect(route.provenance.isConfirmed, isFalse);
    });

    test('les routes du référentiel canonique ne sont jamais CONFIRMED dans le modèle', () {
      final TransportNetwork network = TransportNetwork.fromJson(_raw());
      for (final TransportRoute r in network.routes) {
        if (!<String>['aftu', 'tata', 'ddd'].contains(r.operatorId)) continue;
        expect(r.provenance.status, isNot(ProvenanceStatus.confirmed),
            reason: '${r.id} : le référentiel canonique ne confirme aucune de ces lignes');
        expect(r.scheduleStatus, ScheduleStatus.unknown, reason: '${r.id}');
      }
    });
  });
}
