// LOT 6 — Garde-fous de qualité transverses.
//
// Ces tests protègent des invariants de projet qui, s'ils régressaient,
// réintroduiraient des données inventées, un faux temps réel, un prix, une
// heure locale de navigateur ou un GPS fabriqué. Ils sont volontairement
// fondés sur les sources et les assets réellement livrés (pas de mock).
import 'dart:convert';
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/services/dakar_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Contenu Dart exécutable : commentaires (`//`, `///`) retirés pour ne pas
/// confondre une mention documentaire avec un appel réel.
List<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

String _executable(File file) => file
    .readAsLinesSync()
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n');

List<File> _jsonAssets() => Directory('assets/data')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.json'))
    .toList();

Map<String, dynamic> _network() => jsonDecode(
    File('assets/data/dakar_network.json').readAsStringSync())
    as Map<String, dynamic>;

Map<String, dynamic> _route(String id) =>
    (_network()['routes'] as List).cast<Map<String, dynamic>>().firstWhere(
        (Map<String, dynamic> r) => r['id'] == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LOT 6 — horloge', () {
    test('DateTime.now() n\'est appelé que depuis DakarClock (source unique)', () {
      final List<String> offenders = <String>[];
      for (final File f in _dartFiles()) {
        if (f.path.endsWith('services/dakar_clock.dart')) continue;
        if (_executable(f).contains('DateTime.now()')) offenders.add(f.path);
      }
      expect(offenders, isEmpty,
          reason: 'une heure locale de navigateur réintroduirait un décalage '
              'de fuseau : tout doit passer par DakarClock.now()');
    });

    test('DakarClock est Africa/Dakar et n\'altère pas un instant UTC', () {
      expect(DakarClock.timeZone, 'Africa/Dakar');
      final DateTime instant = DateTime.utc(2026, 1, 2, 3, 4, 5);
      expect(DakarClock.toDakar(instant), instant);
      expect(DakarClock.isPlausible(instant), isTrue);
    });
  });

  group('LOT 6 — aucune donnée interdite (prix, temps réel simulé)', () {
    test('aucun jeton tarifaire dans le code Dart livré', () {
      final RegExp price = RegExp(r'\b(fcfa|tarif|prix|co[ûu]t|price|fare)\b',
          caseSensitive: false);
      final List<String> offenders = <String>[];
      for (final File f in _dartFiles()) {
        if (price.hasMatch(_executable(f))) offenders.add(f.path);
      }
      expect(offenders, isEmpty,
          reason: 'la règle prix est absolue : aucun tarif dans l\'interface');
    });

    test('aucune clé tarifaire dans les assets JSON', () {
      final RegExp fare = RegExp(r'"(fare|price|tarif|fcfa)[a-z_]*"\s*:',
          caseSensitive: false);
      final List<String> offenders = <String>[];
      for (final File f in _jsonAssets()) {
        if (fare.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });

    test('aucun schedule_status / data_status REAL_TIME ou LIVE dans les assets',
        () {
      // Aucun flux GTFS-RT / SAE n'est branché : une valeur temps réel serait
      // une donnée inventée.
      final RegExp statuses = RegExp(
          r'"(schedule_status|data_status)"\s*:\s*"([^"]+)"',
          caseSensitive: false);
      final List<String> offenders = <String>[];
      for (final File f in _jsonAssets()) {
        for (final RegExpMatch m in statuses.allMatches(f.readAsStringSync())) {
          final String value = m.group(2)!;
          if (value == 'REAL_TIME' || value == 'LIVE') {
            offenders.add('${f.path}: ${m.group(1)}=$value');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('l\'étiquette honnête « Horaire indisponible » est préservée', () {
      expect(ReliabilityLabel.scheduleUnavailable, 'Horaire indisponible');
      expect(ReliabilityLabel.noVerifiedSchedule, isNotEmpty);
    });
  });

  group('LOT 6 — GPS réel, jamais fabriqué', () {
    test('coordonnées techniquement impossibles rejetées (NaN, Inf, 0,0, plage)',
        () {
      expect(PositionValidity.isPlausibleCoordinates(double.nan, 10), isFalse);
      expect(
          PositionValidity.isPlausibleCoordinates(10, double.infinity), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(91, 10), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(10, -181), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(0, 0), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(14.67, -17.43), isTrue);
    });

    test(
        'position valide hors zone : conservée, hors couverture '
        '(pas de repli Dakar)', () {
      const LatLng france = LatLng(48.85, 2.35);
      expect(PositionValidity.isPlausible(france), isTrue);
      expect(GpsResolver.isWithinServiceZone(france), isFalse);
      expect(
          GpsResolver.isWithinServiceZone(const LatLng(14.67, -17.43)), isTrue);
      expect(GpsResolver.isWithinServiceZone(null), isFalse);
    });

    test('la constante de couverture nomme explicitement Dakar Bus', () {
      expect(GpsResolver.outOfCoverageMessage, contains('hors'));
      expect(GpsResolver.outOfCoverageMessage.toLowerCase(), contains('dakar'));
    });
  });

  group('LOT 6 — intégrité des données TER / BRT', () {
    test('TER : exactement 13 gares sur la route documentée', () {
      expect(List<String>.from(_route('ter_dakar_diamniadio')['stops'] as List),
          hasLength(13));
    });

    test('BRT B1 = 23 stations ; B2 = 7 stations', () {
      expect(
          List<String>.from(_route('brt_b1_guediawaye_petersen')['stops'] as List),
          hasLength(23));
      expect(List<String>.from(_route('brt_b2_express')['stops'] as List),
          hasLength(7));
    });

    test('B2 est une sous-séquence ordonnée de B1 (pas de ligne artificielle)',
        () {
      final List<String> b1 = List<String>.from(
          _route('brt_b1_guediawaye_petersen')['stops'] as List);
      final List<String> b2 =
          List<String>.from(_route('brt_b2_express')['stops'] as List);
      int cursor = -1;
      for (final String id in b2) {
        final int at = b1.indexOf(id);
        expect(at, greaterThan(cursor), reason: '$id hors séquence B1');
        cursor = at;
      }
    });

    test('B3 non exposée comme route ; stations non inventées', () {
      final List<Map<String, dynamic>> routes =
          (_network()['routes'] as List).cast<Map<String, dynamic>>();
      expect(routes.any((Map<String, dynamic> r) => r['id'] == 'brt_b3'), isFalse);
      final List<Map<String, dynamic>> hidden =
          (_network()['services_not_exposed'] as List)
              .cast<Map<String, dynamic>>();
      expect(
          hidden.firstWhere(
              (Map<String, dynamic> s) => s['id'] == 'brt_b3')['exposed'],
          isFalse);
    });
  });

  group('LOT 6 — assistant IA sans invention', () {
    setUpAll(() async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();
    });

    test('un réseau sans horaire vérifié est dit tel quel, sans chiffre inventé',
        () {
      final String reply = AssistantReplies.modeInfo(
          'ter', appDataService.operators, appDataService.routes);
      expect(reply, contains('aucun horaire'));
      expect(reply, isNot(contains('temps réel')));
      expect(reply, isNot(contains('min')));
    });
  });
}
