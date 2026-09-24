import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';

/// AUDIT DONNÉES 2026-09-24 — provenance du réseau (docs/AUDIT_DONNEES_2026-09-24.md).
///
/// Ces tests figent les règles de l'audit :
///  * aucune donnée n'est CONFIRMED sans source ni date de vérification ;
///  * une observation terrain n'est jamais promue officielle ;
///  * aucun horaire n'est présenté : schedule_status = UNKNOWN partout ;
///  * TER = 13 gares confirmées, AIBD = FUTURE et non exposée ;
///  * B2 = liste officielle SunuBRT, B3 non exposée, B4 = FUTURE ;
///  * les 15 routes DDD ne prétendent pas représenter les 38 lignes CETUD ;
///  * les routes candidates new_commune_* ne comptent pas dans les totaux ;
///  * les doublons de lieux sont reliés par place_id sans suppression d'id.

const Set<String> kDataStatus = <String>{'CONFIRMED', 'UNVERIFIED', 'CONFLICTING', 'FUTURE'};
const Set<String> kSourceType = <String>{
  'OFFICIAL_STATIC',
  'OFFICIAL_REALTIME',
  'OPERATOR_REALTIME',
  'ESTIMATED',
  'COMMUNITY',
  'FIELD_OBSERVATION',
  'UNKNOWN',
};

Map<String, dynamic> _raw() => jsonDecode(
    File('assets/data/dakar_network.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _list(String key) =>
    (_raw()[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _route(String id) =>
    _list('routes').firstWhere((Map<String, dynamic> r) => r['id'] == id);

Map<String, dynamic> _stop(String id) =>
    _list('stops').firstWhere((Map<String, dynamic> s) => s['id'] == id);

void main() {
  group('Schéma de provenance (JSON brut)', () {
    test('volumes inchangés : 5 opérateurs, 117 arrêts, 105 routes', () {
      expect(_list('operators'), hasLength(5));
      expect(_list('stops'), hasLength(117));
      expect(_list('routes'), hasLength(105));
    });

    test('chaque arrêt et chaque route porte data_status, source_type, source, verified_at', () {
      for (final Map<String, dynamic> e in <Map<String, dynamic>>[
        ..._list('stops'),
        ..._list('routes'),
      ]) {
        expect(kDataStatus, contains(e['data_status']), reason: '${e['id']}');
        expect(kSourceType, contains(e['source_type']), reason: '${e['id']}');
        expect(e.containsKey('source'), isTrue, reason: '${e['id']}');
        expect(e.containsKey('verified_at'), isTrue, reason: '${e['id']}');
        expect(e['data_trust'], isA<String>(), reason: 'champ historique conservé : ${e['id']}');
      }
    });

    test('CONFIRMED exige une source nommée et une date de vérification', () {
      for (final Map<String, dynamic> e in <Map<String, dynamic>>[
        ..._list('stops'),
        ..._list('routes'),
      ]) {
        if (e['data_status'] == 'CONFIRMED') {
          expect(e['source'], isNotNull, reason: '${e['id']}');
          expect(e['verified_at'], isNotNull, reason: '${e['id']}');
          expect(e['source_type'], 'OFFICIAL_STATIC', reason: '${e['id']}');
        }
      }
    });

    test('source inconnue → source_type UNKNOWN ou FIELD_OBSERVATION, jamais officielle', () {
      for (final Map<String, dynamic> e in <Map<String, dynamic>>[
        ..._list('stops'),
        ..._list('routes'),
      ]) {
        if (e['source'] == null) {
          expect(<String>['UNKNOWN', 'FIELD_OBSERVATION'], contains(e['source_type']),
              reason: '${e['id']}');
          expect(e['verified_at'], isNull, reason: '${e['id']}');
          expect(e['data_trust'], isNot('OFFICIAL'), reason: '${e['id']}');
        }
      }
    });

    test('une observation terrain n\'est jamais promue CONFIRMED ni OFFICIAL', () {
      for (final Map<String, dynamic> e in <Map<String, dynamic>>[
        ..._list('stops'),
        ..._list('routes'),
      ]) {
        if (e['data_trust'] == 'FIELD_OBSERVATION' || e['source_type'] == 'FIELD_OBSERVATION') {
          expect(e['data_status'], isNot('CONFIRMED'), reason: '${e['id']}');
          expect(e['data_trust'], 'FIELD_OBSERVATION', reason: '${e['id']}');
        }
      }
    });

    test('data_trust OFFICIAL uniquement pour une donnée sourcée', () {
      for (final Map<String, dynamic> e in <Map<String, dynamic>>[
        ..._list('stops'),
        ..._list('routes'),
      ]) {
        if (e['data_trust'] == 'OFFICIAL') {
          expect(e['source_type'], 'OFFICIAL_STATIC', reason: '${e['id']}');
          expect(e['source'], isNotNull, reason: '${e['id']}');
        }
      }
    });

    test('aucun horaire : toutes les routes sont en schedule_status UNKNOWN', () {
      for (final Map<String, dynamic> r in _list('routes')) {
        expect(r['schedule_status'], 'UNKNOWN', reason: '${r['id']}');
      }
    });
  });

  group('TER', () {
    test('13 gares CONFIRMED, coordonnées à ≤ 150 m du plan SETER', () {
      final Map<String, dynamic> ter = _route('ter_dakar_diamniadio');
      expect(ter['data_status'], 'CONFIRMED');
      final List<String> gares = List<String>.from(ter['stops'] as List);
      expect(gares, hasLength(13));
      for (final String id in gares) {
        expect(_stop(id)['data_status'], 'CONFIRMED', reason: id);
        expect(_stop(id)['coordinates_status'], 'CONFIRMED', reason: id);
      }
    });

    test('Keur Massar et Mbao ne sont pas des gares TER', () {
      final List<String> gares = List<String>.from(_route('ter_dakar_diamniadio')['stops'] as List);
      expect(gares.any((String id) => id.contains('keur_massar') || id.contains('mbao')), isFalse);
    });

    test('AIBD : FUTURE, non exposée, absente des arrêts et des routes', () {
      final Map<String, dynamic> aibd = _list('services_not_exposed')
          .firstWhere((Map<String, dynamic> s) => s['id'] == 'ter_diamniadio_aibd');
      expect(aibd['data_status'], 'FUTURE');
      expect(aibd['exposed'], isFalse);
      expect(_list('stops').any((Map<String, dynamic> s) => (s['id'] as String).contains('aibd')), isFalse);
      expect(_list('routes').any((Map<String, dynamic> r) => (r['id'] as String).contains('aibd')), isFalse);
    });
  });

  group('BRT', () {
    test('B1 : 23 stations, CONFIRMED', () {
      final Map<String, dynamic> b1 = _route('brt_b1_guediawaye_petersen');
      expect(b1['data_status'], 'CONFIRMED');
      expect(b1['stops'] as List, hasLength(23));
    });

    test('B2 : les 7 stations du communiqué SunuBRT du 30/09/2024', () {
      final Map<String, dynamic> b2 = _route('brt_b2_express');
      expect(b2['data_status'], 'CONFIRMED');
      expect(b2['service_pattern'], 'SEMI_EXPRESS');
      expect(
          List<String>.from(b2['stops'] as List),
          orderedEquals(<String>[
            'stop_brt_23_guediawaye', // Préfecture de Guédiawaye
            'stop_brt_19_dalal_jamm', // Dalal Jam
            'stop_brt_13_grand_medine', // Grand Médine
            'stop_brt_07_sacre_coeur', // Sacré-Cœur
            'stop_brt_05_grand_dakar', // Grand Dakar
            'stop_brt_03_obelisque', // Place de la Nation
            'stop_brt_01_petersen', // Papa Gueye Fall
          ]));
    });

    test('B3 non exposée comme route (stations non inventées), B4 FUTURE', () {
      expect(_list('routes').any((Map<String, dynamic> r) => r['id'] == 'brt_b3'), isFalse);
      final List<Map<String, dynamic>> hidden = _list('services_not_exposed');
      final Map<String, dynamic> b3 =
          hidden.firstWhere((Map<String, dynamic> s) => s['id'] == 'brt_b3');
      final Map<String, dynamic> b4 =
          hidden.firstWhere((Map<String, dynamic> s) => s['id'] == 'brt_b4');
      expect(b3['exposed'], isFalse);
      expect(b3['official_station_names'] as List, hasLength(7));
      expect(b4['data_status'], 'FUTURE');
      expect(b4['official_station_names'], isNull, reason: 'stations B4 non publiées');
    });

    test('noms de stations non tranchés signalés, pas maquillés', () {
      expect(_stop('stop_brt_06_liberte_1')['data_status'], 'CONFLICTING');
      expect(_stop('stop_brt_22_gadaye')['data_status'], 'CONFLICTING');
      expect(_stop('stop_brt_20_fith_mith')['data_status'], 'UNVERIFIED');
    });
  });

  group('DDD / AFTU / Tata', () {
    test('DDD : 38 lignes officielles, 15 routes dans le jeu, aucune CONFIRMED', () {
      final Map<String, dynamic> ddd =
          _list('operators').firstWhere((Map<String, dynamic> o) => o['id'] == 'ddd');
      expect(ddd['official_line_count'], 38);
      final List<Map<String, dynamic>> routes =
          _list('routes').where((Map<String, dynamic> r) => r['operator_id'] == 'ddd').toList();
      expect(routes, hasLength(15));
      expect(routes.length, isNot(ddd['official_line_count']));
      expect(routes.any((Map<String, dynamic> r) => r['data_status'] == 'CONFIRMED'), isFalse);
      expect(routes.any((Map<String, dynamic> r) => r['data_trust'] == 'OFFICIAL'), isFalse);
    });

    test('AFTU : 72 lignes officielles ; aftu_1..72 non vérifiées ; candidates hors total', () {
      final Map<String, dynamic> aftu =
          _list('operators').firstWhere((Map<String, dynamic> o) => o['id'] == 'aftu');
      expect(aftu['official_line_count'], 72);
      final List<Map<String, dynamic>> numbered = _list('routes')
          .where((Map<String, dynamic> r) => RegExp(r'^aftu_\d+$').hasMatch(r['id'] as String))
          .toList();
      expect(numbered, hasLength(72));
      for (final Map<String, dynamic> r in numbered) {
        expect(r['data_status'], 'UNVERIFIED', reason: '${r['id']}');
        expect(r['source_type'], 'FIELD_OBSERVATION', reason: '${r['id']}');
      }
      for (int n = 1; n <= 13; n++) {
        final String id = 'new_commune_${n.toString().padLeft(2, '0')}';
        final Map<String, dynamic> r = _route(id);
        expect(r['counts_toward_official_total'], isFalse, reason: id);
        expect(r['data_status'], 'UNVERIFIED', reason: id);
        expect(r['source_type'], 'UNKNOWN', reason: id);
      }
    });

    test('Tata : observations terrain, jamais officielles', () {
      for (final Map<String, dynamic> r
          in _list('routes').where((Map<String, dynamic> r) => r['operator_id'] == 'tata')) {
        expect(r['data_status'], isNot('CONFIRMED'), reason: '${r['id']}');
        expect(r['data_trust'], isNot('OFFICIAL'), reason: '${r['id']}');
      }
    });
  });

  group('Lieux physiques (place_id)', () {
    test('chaque arrêt a un place_id', () {
      for (final Map<String, dynamic> s in _list('stops')) {
        expect(s['place_id'], isA<String>(), reason: '${s['id']}');
      }
    });

    test('station BRT et arrêt de bus homonymes : même lieu, deux identifiants conservés', () {
      const List<List<String>> pairs = <List<String>>[
        <String>['stop_brt_19_dalal_jamm', 'stop_dalal_jamm'],
        <String>['stop_brt_07_sacre_coeur', 'stop_sacre_coeur'],
        <String>['stop_brt_09_liberte_6', 'stop_liberte6'],
      ];
      for (final List<String> p in pairs) {
        expect(_stop(p[0])['place_id'], _stop(p[1])['place_id'], reason: p.join(' / '));
        expect(p[0], isNot(p[1]));
      }
    });
  });

  group('Modèle Dart', () {
    test('Provenance absente → UNVERIFIED / UNKNOWN', () {
      final Provenance p = Provenance.fromJson(<String, dynamic>{});
      expect(p.status, ProvenanceStatus.unverified);
      expect(p.sourceType, SourceType.unknown);
      expect(p.source, isNull);
    });

    test('CONFIRMED sans source ni date est lu comme UNVERIFIED', () {
      final Provenance p = Provenance.fromJson(<String, dynamic>{
        'data_status': 'CONFIRMED',
        'source_type': 'OFFICIAL_STATIC',
      });
      expect(p.status, ProvenanceStatus.unverified);
    });

    test('DataTrust : UNVERIFIED reconnu, valeur inconnue → unverified', () {
      expect(DataTrustExtension.fromString('UNVERIFIED'), DataTrust.unverified);
      expect(DataTrustExtension.fromString('ESTIMATED'), DataTrust.estimated);
      expect(DataTrustExtension.fromString('???'), DataTrust.unverified);
      expect(DataTrust.unverified.toLabel(), 'UNVERIFIED');
    });

    test('ScheduleStatus : ESTIMATED jamais « temps réel », UNKNOWN → « Horaire indisponible »', () {
      expect(ScheduleStatus.estimated.displayLabel().toLowerCase(), isNot(contains('temps réel')));
      expect(ScheduleStatus.unknown.displayLabel(), 'Horaire indisponible');
      expect(ScheduleStatusLabel.fromString(null), ScheduleStatus.unknown);
    });

    test('le DataService charge le JSON actif (pas le repli) avec sa provenance', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final DataService ds = DataService();
      await ds.loadNetworkData();
      expect(ds.stops, hasLength(117), reason: 'le repli en dur en compte 6');
      expect(ds.routes, hasLength(105));
      final BusStop hann = ds.stops.firstWhere((BusStop s) => s.id == 'stop_hann');
      expect(hann.provenance.status, ProvenanceStatus.confirmed);
      expect(hann.coordinatesStatus, ProvenanceStatus.confirmed);
      final TransportRoute ddd1 = ds.routes.firstWhere((TransportRoute r) => r.id == 'ddd_1');
      expect(ddd1.provenance.status, ProvenanceStatus.conflicting);
      expect(ddd1.dataTrust, DataTrust.unverified);
      expect(ddd1.scheduleStatus, ScheduleStatus.unknown);
      final Operator ddd = ds.operators.firstWhere((Operator o) => o.id == 'ddd');
      expect(ddd.officialLineCount, 38);
      final TransportRoute nc = ds.routes.firstWhere((TransportRoute r) => r.id == 'new_commune_05');
      expect(nc.countsTowardOfficialTotal, isFalse);
    });
  });
}
