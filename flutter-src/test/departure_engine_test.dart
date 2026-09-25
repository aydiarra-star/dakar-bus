import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/departure_estimate.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/departure_service.dart';

/// MOTEUR COMMUN DE DÉPARTS — règles non négociables (miroir Dart).
///
/// T1 horaire précis → scheduled · T2 fréquence → estimated (fenêtre) ·
/// T4 aucune donnée → unknown · T5 historique refusé · T6 communauté jamais
/// officielle · T7 GPS utilisateur ≠ véhicule · T8 aucune heure inventée ·
/// T9/T10 fréquence par ligne et par période · T11/T12 début/fin de service ·
/// T13 changement de fréquence · T14 assistant = même statut ·
/// T15–T18 KMF, Mbao, Yeumbeul, AIBD.
///
/// Aucun test ne dépend de l'heure réelle : tous les instants sont explicites.
void main() {
  final DepartureRegistry registry = DepartureEngineService.parseRegistry(
      File('assets/data/departure-frequencies.json').readAsStringSync());

  final DateTime lundi = DateTime(2026, 9, 28, 11, 43);
  const String lineTer = 'ter_dakar_diamniadio';
  const String lineB1 = 'brt_b1_guediawaye_petersen';
  const String lineB2 = 'brt_b2_express';

  DepartureEstimate ter(DateTime now) => DepartureEngineService.estimateNextDeparture(
        now: now,
        registry: registry,
        network: 'TER',
        lineId: lineTer,
        stopId: 'stop_dakar_ter',
      );

  test('T1 — horaire précis sourcé : scheduled, jamais converti en estimation', () {
    final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
      now: lundi,
      registry: registry,
      network: 'TER',
      lineId: lineTer,
      scheduledDepartures: <Map<String, dynamic>>[
        <String, dynamic>{
          'time': '12:10',
          'source': 'SETER — horaire publié',
          'sourceType': 'OFFICIAL',
        }
      ],
    );
    expect(e.status, ScheduleStatus.scheduled);
    expect(DepartureEngineService.clockOfIso(e.scheduledTime), '12:10');
    expect(e.estimatedFrom, isNull);
    expect(e.estimatedTo, isNull);
    expect(e.frequencyMinutes, isNull);
    expect(DepartureEngineService.validateEstimate(e), isEmpty);
    expect(DepartureEngineService.displayFor(e, now: lundi).badge,
        'Horaire théorique');
  });

  test('T1b — un horaire sans source utilisable ne devient pas scheduled', () {
    for (final String? type in <String?>[null, 'UNKNOWN', 'COMMUNITY']) {
      final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
        now: lundi,
        registry: registry,
        network: 'TER',
        lineId: lineTer,
        scheduledDepartures: <Map<String, dynamic>>[
          <String, dynamic>{'time': '12:10', 'sourceType': type}
        ],
      );
      expect(e.status, isNot(ScheduleStatus.scheduled), reason: '$type');
    }
  });

  test('T2 — fréquence TER documentée : estimated, fenêtre 0–10 min', () {
    final DepartureEstimate e = ter(lundi);
    expect(e.status, ScheduleStatus.estimated);
    expect(e.frequencyMinutes, 10);
    expect(DepartureEngineService.clockOfIso(e.estimatedFrom), '11:43');
    expect(DepartureEngineService.clockOfIso(e.estimatedTo), '11:53');
    expect(e.scheduledTime, isNull);
    expect(e.observedAt, isNull);
    expect(e.confidence, 'high');
    final DepartureDisplay d = DepartureEngineService.displayFor(e, now: lundi);
    expect(d.badge, 'Estimation');
    expect(d.isRealTime, isFalse);
    expect(d.isOfficial, isFalse);
    expect(d.headline, contains('0–10 min'));
    expect(RegExp(r'D[ée]part\s+\d{1,2}h\d{2}').hasMatch('${d.headline} ${d.body}'),
        isFalse);
  });

  test('T4 — aucune donnée : unknown, tous les champs temporels à null', () {
    final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
      now: lundi,
      registry: registry,
      network: 'DDD',
      lineId: 'ddd_1',
    );
    expect(e.status, ScheduleStatus.unknown);
    expect(e.scheduledTime, isNull);
    expect(e.estimatedFrom, isNull);
    expect(e.estimatedTo, isNull);
    expect(e.frequencyMinutes, isNull);
    expect(e.observedAt, isNull);
    expect(e.confidence, 'none');
    expect(DepartureEngineService.displayFor(e, now: lundi).body,
        'Horaire indisponible');
  });

  test('T5 — fréquence historique ou périmée : aucun service actuel', () {
    final DepartureRegistry fixture = DepartureEngineService.parseRegistry('''
    {"schema":"test","sources":[{"id":"passbi","source_type":"HISTORICAL","url":null}],
     "frequencies":[{"id":"ddd_1_passbi","network":"DDD","line_id":"ddd_1",
       "day_types":["MONDAY"],"service_start":"06:00","service_end":"21:00",
       "frequency_minutes":10,"status":"HISTORICAL","source_id":"passbi"}]}''');
    final DepartureEstimate e = DepartureEngineService.estimateNextDeparture(
      now: lundi,
      registry: fixture,
      network: 'DDD',
      lineId: 'ddd_1',
    );
    expect(e.status, ScheduleStatus.unknown);
    expect(e.frequencyMinutes, isNull);
  });

  test('T6 — OSM / communauté : jamais officielle, jamais utilisée sans opt-in', () {
    final DepartureRegistry fixture = DepartureEngineService.parseRegistry('''
    {"schema":"test","sources":[{"id":"osm","source_type":"COMMUNITY","url":null}],
     "frequencies":[{"id":"ddd_1_osm","network":"DDD","line_id":"ddd_1",
       "day_types":["MONDAY"],"service_start":"06:00","service_end":"21:00",
       "frequency_minutes":10,"status":"ACTIVE","source_id":"osm"}]}''');
    final DepartureEstimate refused = DepartureEngineService.estimateNextDeparture(
        now: lundi, registry: fixture, network: 'DDD', lineId: 'ddd_1');
    expect(refused.status, ScheduleStatus.unknown);
    expect(DepartureEngineService.displayFor(refused, now: lundi).isOfficial, isFalse);

    final DepartureSelection? selection = DepartureEngineService.selectFrequency(
      fixture,
      lineId: 'ddd_1',
      dayType: 'MONDAY',
      date: '2026-09-28',
      minutes: 703,
    );
    expect(selection, isNull, reason: 'COMMUNITY non utilisable par défaut');

    final DepartureSelection? optedIn = DepartureEngineService.selectFrequency(
      fixture,
      lineId: 'ddd_1',
      dayType: 'MONDAY',
      date: '2026-09-28',
      minutes: 703,
      allowCommunityFrequencies: true,
    );
    expect(optedIn, isNotNull);
    expect(optedIn!.policy.official, isFalse);
    expect(optedIn.policy.confidence, 'low');
    expect(DepartureSourcePolicy.of('HISTORICAL').usable, isFalse);
    expect(DepartureSourcePolicy.of('UNKNOWN').usable, isFalse);
    expect(DepartureSourcePolicy.of('OPEN_DATA').official, isFalse);
  });

  test('T7 — GPS utilisateur : jamais un véhicule', () {
    expect(DepartureEngineService.userPositionUses,
        <String>['LOCALISATION', 'STOP_PROXIMITY', 'DISTANCE', 'ROUTING']);
    expect(
        DepartureEngineService.vehicleFromUserPosition(<String, double>{
          'latitude': 14.7167,
          'longitude': -17.4677,
        }),
        isNull);
  });

  test('T8 — aucune heure précise inventée : balayage de la journée', () {
    final List<DateTime> instants = <DateTime>[
      DateTime(2026, 9, 28, 5, 0),
      DateTime(2026, 9, 28, 11, 43),
      DateTime(2026, 9, 28, 20, 57),
      DateTime(2026, 9, 28, 21, 30),
      DateTime(2026, 9, 28, 22, 30),
      DateTime(2026, 10, 4, 6, 0),
      DateTime(2026, 10, 4, 11, 43),
    ];
    for (final DateTime now in instants) {
      final DepartureEstimate e = ter(now);
      expect(DepartureEngineService.validateEstimate(e), isEmpty, reason: '$now');
      final DepartureDisplay d = DepartureEngineService.displayFor(e, now: now);
      if (e.status == ScheduleStatus.estimated) {
        expect(e.estimatedFrom, isNot(e.estimatedTo));
        expect(d.headline.startsWith('Départ'), isFalse);
      }
      if (e.status == ScheduleStatus.unknown) {
        expect(d.body, 'Horaire indisponible');
        expect(d.isRealTime, isFalse);
      }
    }
  });

  test('T9/T10 — fréquences par ligne et par période', () {
    final DateTime dimanche = DateTime(2026, 10, 4, 11, 0);
    final DepartureEstimate b1 = DepartureEngineService.estimateNextDeparture(
        now: dimanche, registry: registry, network: 'BRT', lineId: lineB1);
    final DepartureEstimate b2 = DepartureEngineService.estimateNextDeparture(
        now: dimanche, registry: registry, network: 'BRT', lineId: lineB2);
    expect(b1.status, ScheduleStatus.estimated);
    expect(b1.frequencyMinutes, 6);
    expect(b2.status, ScheduleStatus.unknown, reason: 'B2 ne circule pas le dimanche');

    expect(ter(DateTime(2026, 9, 28, 11, 43)).frequencyMinutes, 10);
    expect(ter(DateTime(2026, 9, 28, 21, 30)).frequencyMinutes, 20);
    expect(ter(DateTime(2026, 10, 4, 11, 43)).frequencyMinutes, 20);
  });

  test('T11/T12 — début et fin de service respectés', () {
    final DepartureEstimate tot = ter(DateTime(2026, 9, 28, 5, 0));
    expect(DepartureEngineService.clockOfIso(tot.estimatedFrom), '05:30');
    expect(DepartureEngineService.clockOfIso(tot.estimatedTo), '05:40');
    expect(tot.relative, 'BEFORE_SERVICE');

    final DepartureEstimate tard = ter(DateTime(2026, 9, 28, 22, 30));
    expect(tard.status, ScheduleStatus.unknown);
    expect(tard.reason, 'SERVICE_ENDED');
    final DepartureEstimate brtTard = DepartureEngineService.estimateNextDeparture(
        now: DateTime(2026, 9, 28, 21, 30), registry: registry, network: 'BRT', lineId: lineB1);
    expect(brtTard.status, ScheduleStatus.unknown, reason: 'le BRT s’arrête à 21h');
  });

  test('T13 — changement de fréquence pendant la journée (10 → 20 min à 21h)', () {
    final DepartureSelection? jour = DepartureEngineService.selectFrequency(
      registry,
      lineId: lineTer,
      network: 'TER',
      dayType: 'MONDAY',
      date: '2026-09-28',
      minutes: DepartureEngineService.clockToMinutes('11:43'),
    );
    final DepartureSelection? soir = DepartureEngineService.selectFrequency(
      registry,
      lineId: lineTer,
      network: 'TER',
      dayType: 'MONDAY',
      date: '2026-09-28',
      minutes: DepartureEngineService.clockToMinutes('21:30'),
    );
    expect(jour!.frequency.frequencyMinutes, 10);
    expect(soir!.frequency.frequencyMinutes, 20);
    expect(soir.frequency.serviceStart, '21:00');
    final DepartureEstimate finDePeriode = ter(DateTime(2026, 9, 28, 20, 57));
    expect(DepartureEngineService.clockOfIso(finDePeriode.estimatedTo), '21:00');
  });

  test('T14 — l’assistant utilise exactement le même statut que l’interface', () {
    final DateTime now = DateTime(2026, 9, 28, 11, 43);
    final DepartureEstimate e = ter(now);
    final DepartureDisplay d = DepartureEngineService.displayFor(e, now: now);
    final String answer =
        DepartureEngineService.assistantReply(e, mode: 'TER', now: now);
    expect(d.status, e.status);
    expect(answer, contains('fenêtre de 0 à 10 minutes'));
    expect(answer, contains("L'heure exacte du train n'est pas disponible"));
    expect(RegExp(r'\d{1,2}h\d{2}').hasMatch(answer), isFalse);

    final DepartureEstimate inconnu = DepartureEngineService.estimateNextDeparture(
        now: now, registry: registry, network: 'DDD', lineId: 'ddd_1');
    final String reponse = DepartureEngineService.assistantReply(inconnu, mode: 'DDD', now: now);
    expect(reponse, contains('pas actuellement de donnée suffisamment fiable'));
    expect(RegExp(r'\d+\s*min').hasMatch(reponse), isFalse);
  });

  test('Itinéraires — l’incertitude est conservée (jamais 12h17 tout court)', () {
    final DepartureLegPlan plan = DepartureEngineService.planItineraryLeg(
        ter(lundi), durationMinutes: 34);
    expect(plan.precision, 'WINDOW');
    expect(plan.departureTime, isNull);
    expect(plan.arrivalTime, isNull);
    expect(DepartureEngineService.clockOfIso(plan.arrivalWindowFrom), '12:17');
    expect(DepartureEngineService.clockOfIso(plan.arrivalWindowTo), '12:27');
    final DepartureLegPlan sansDonnee = DepartureEngineService.planItineraryLeg(
      const DepartureEstimate.unknown(),
      durationMinutes: 30,
    );
    expect(sansDonnee.precision, 'NONE');
    expect(sansDonnee.arrivalTime, isNull);
  });

  test('Référentiel : valide, sourcé, identique au fichier du dépôt', () {
    expect(DepartureEngineService.validateFrequencyRegistry(registry), isEmpty);
    for (final DepartureFrequency f in registry.frequencies) {
      final DepartureSource? source = registry.sourceById(f.sourceId);
      expect(source, isNotNull, reason: f.id);
      expect(<String>['OFFICIAL', 'INSTITUTIONAL', 'OPEN_DATA'],
          contains(source!.sourceType.code));
      expect(f.status, 'ACTIVE');
      expect(f.frequencyMinutes, greaterThan(0));
    }
    expect(
      File('assets/data/departure-frequencies.json').readAsStringSync(),
      File('../data/transit/departure-frequencies.json').readAsStringSync(),
      reason: 'le référentiel des deux applications a divergé',
    );
  });

  test('T15–T18 — KMF, Mbao, Yeumbeul, AIBD : rien n’est promu', () {
    final Map<String, dynamic> network =
        jsonDecode(File('assets/data/dakar_network.json').readAsStringSync())
            as Map<String, dynamic>;
    final List<Map<String, dynamic>> routes =
        (network['routes'] as List).cast<Map<String, dynamic>>();
    final Map<String, dynamic> terRoute =
        routes.firstWhere((Map<String, dynamic> r) => r['id'] == 'ter_dakar_diamniadio');
    final List<dynamic> terStops = terRoute['stops'] as List;
    expect(terStops.length, 13);

    // T15 — KMF reste UNKNOWN et n’est pas une gare TER.
    expect(terStops.any((dynamic id) => id.toString().contains('keur_massar')), isFalse);
    expect(registry.frequencies.any((DepartureFrequency f) => f.lineId.contains('keur_massar')), isFalse);

    // T16 — Mbao distinct de KMF.
    final List<Map<String, dynamic>> stops =
        (network['stops'] as List).cast<Map<String, dynamic>>();
    final Map<String, dynamic> mbao =
        stops.firstWhere((Map<String, dynamic> s) => s['id'] == 'stop_mbao');
    final Map<String, dynamic> kmf =
        stops.firstWhere((Map<String, dynamic> s) => s['id'] == 'stop_keur_massar');
    expect(mbao['place_id'], isNot(kmf['place_id']));
    expect(mbao['data_status'], 'UNVERIFIED');

    // T17 — Yeumbeul A/B n’est pas résolu.
    final List<Map<String, dynamic>> yeumbeul = stops
        .where((Map<String, dynamic> s) =>
            s['id'].toString().contains('yeumbeul') ||
            s['name'].toString().toLowerCase().contains('yeumbeul'))
        .toList();
    expect(yeumbeul.length, 1);

    // T18 — AIBD reste FUTURE, hors routes et hors fréquences.
    expect(stops.any((Map<String, dynamic> s) => s['id'].toString().contains('aibd')), isFalse);
    expect(registry.frequencies.any((DepartureFrequency f) => f.lineId.contains('aibd')), isFalse);
    final List<Map<String, dynamic>> notExposed =
        (network['services_not_exposed'] as List).cast<Map<String, dynamic>>();
    expect(
        notExposed.any((Map<String, dynamic> s) =>
            s['id'] == 'ter_diamniadio_aibd' && s['exposed'] == false),
        isTrue);
  });
}
