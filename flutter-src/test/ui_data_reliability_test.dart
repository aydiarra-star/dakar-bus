// Mission 2 — contradictions UI ↔ données auditées (audit 2026-09-24).
//
// Règle absolue : l'interface ne présente jamais comme certaine une donnée
// déclarée non vérifiée. Mieux vaut « information indisponible » qu'une
// fausse information.
//
// Les 5 tests demandés sont regroupés en tête (groupes 1 à 5) ; les garde-fous
// complémentaires suivent. Aucun test ne fabrique de donnée : les cas
// synthétiques (route FUTURE, horaire programmé) sont construits en mémoire et
// ne touchent pas `dakar_network.json`.
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Heure « HH:MM », « HHhMM » ou « HH h MM » dans un texte.
final RegExp kHeure = RegExp(r'\b\d{1,2}\s?(:|h)\s?\d{2}\b');

/// Fréquence du type « toutes les 10 min » / « 10 à 20 min ».
final RegExp kFrequence =
    RegExp(r'(toutes\s+les\s+\d+|\d+\s*à\s*\d+\s*min|rotation)', caseSensitive: false);

/// Revendication de temps réel.
final RegExp kTempsReel =
    RegExp(r'(temps\s+r[ée]el|en\s+direct|\blive\b)', caseSensitive: false);

Stop _stop(String name, {List<int> departures = const <int>[], String mode = 'DDD'}) => Stop(
      name: name,
      direction: '',
      distanceMeters: 0,
      departureMinutesFromMidnight: departures,
      icon: Icons.circle,
      color: const Color(0xFF000000),
      location: const LatLng(14.7, -17.45),
      modeLabel: mode,
    );

TransportRoute _route(String id, ProvenanceStatus status, {String op = 'ddd'}) => TransportRoute(
      id: id,
      operatorId: op,
      shortName: id.toUpperCase(),
      longName: 'Ligne de test $id',
      type: 'bus',
      dataTrust: DataTrust.unverified,
      stopIds: const <String>['a', 'b'],
      provenance: Provenance(status: status, sourceType: SourceType.unknown),
    );

/// Retire les lignes entièrement commentées (les blocs AVANT/APRÈS citent
/// volontairement les anciens textes).
String _codeSansCommentaires(String src) => src
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!appDataService.isLoaded) {
      await appDataService.loadNetworkData();
    }
    expect(appDataService.stops.length, 117,
        reason: 'la donnée active doit être chargée, pas le repli en dur');
    expect(appDataService.routes.length, 105);
    integrateNetworkDataForTest();
  });

  // ==================================================================
  // 1. Une route UNVERIFIED ne peut pas afficher « Officiel ».
  // ==================================================================
  group('1 — UNVERIFIED n\'affiche jamais « Officiel »', () {
    test('règle : badge et autorisation', () {
      expect(ReliabilityLabel.canShowOfficial(ProvenanceStatus.unverified), isFalse);
      expect(ReliabilityLabel.badge(ProvenanceStatus.unverified), 'NON VÉRIFIÉ');
      expect(ReliabilityLabel.badge(ProvenanceStatus.unverified).toUpperCase(),
          isNot(contains('OFFICIEL')));
      // Route UNVERIFIED + arrêt CONFIRMED → le moins sûr l'emporte.
      expect(
          ReliabilityLabel.combine(
              <ProvenanceStatus>[ProvenanceStatus.unverified, ProvenanceStatus.confirmed]),
          ProvenanceStatus.unverified);
      // Statut inconnu (ensemble vide) : jamais promu en confirmé.
      expect(ReliabilityLabel.combine(const <ProvenanceStatus>[]), ProvenanceStatus.unverified);
    });

    test('données : aucun arrêt d\'une fiche de ligne non confirmée n\'est « OFFICIEL »', () {
      for (final String op in <String>['ddd', 'aftu', 'tata']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        expect(r, isNotNull, reason: 'fiche attendue pour $op');
        expect(r!.dataStatus, isNot(ProvenanceStatus.confirmed),
            reason: 'aucune route $op n\'est CONFIRMED dans le JSON audité');
        for (final DetailedStop s in r.stops) {
          expect(ReliabilityLabel.badge(r.statusOf(s)), isNot('OFFICIEL'),
              reason: '$op / ${s.name}');
        }
      }
    });

    test('données : la route confirmée (TER) garde son badge officiel', () {
      final DetailedRoute ter = DetailedRoute.fromOperator('ter')!;
      expect(ter.dataStatus, ProvenanceStatus.confirmed);
      expect(ter.stops.every((DetailedStop s) => ter.statusOf(s) == ProvenanceStatus.confirmed),
          isTrue,
          reason: 'les 13 gares TER sont CONFIRMED : le badge officiel y est justifié');
    });

    test('carte : pastille officielle 🟢 seulement pour un arrêt TER/BRT confirmé', () {
      final Map<String, BusStop> parId = <String, BusStop>{
        for (final BusStop b in appDataService.stops) b.id: b,
      };
      for (final Stop s in allStops.where((Stop s) => s.source.origin == DataOrigin.official)) {
        expect(<String>['TER', 'BRT'], contains(s.modeLabel), reason: s.name);
        expect(s.stopId, isNotNull, reason: s.name);
        expect(parId[s.stopId]!.provenance.status, ProvenanceStatus.confirmed, reason: s.name);
      }
      for (final DataSourceInfo src in <DataSourceInfo>[
        DataSourceInfo.demdikk,
        DataSourceInfo.tataOfficial,
        DataSourceInfo.aftuOfficial,
        DataSourceInfo.unverified,
      ]) {
        expect(src.origin, isNot(DataOrigin.official), reason: src.label);
        expect(src.label.toLowerCase(), isNot(contains('officiel')), reason: src.label);
        expect(src.badgeEmoji, isNot('🟢'), reason: src.label);
      }
    });

    test('source : plus aucun badge « [OFFICIEL] » codé en dur', () {
      final String code = _codeSansCommentaires(File('lib/main.dart').readAsStringSync());
      expect(code.contains("'[OFFICIEL]'"), isFalse);
    });
  });

  // ==================================================================
  // 2. Une route CONFLICTING n'est pas présentée comme confirmée.
  // ==================================================================
  group('2 — CONFLICTING n\'est jamais présenté comme confirmé', () {
    test('règle', () {
      expect(ReliabilityLabel.canShowOfficial(ProvenanceStatus.conflicting), isFalse);
      expect(ReliabilityLabel.badge(ProvenanceStatus.conflicting), 'CONTESTÉ');
      expect(
          ReliabilityLabel.combine(
              <ProvenanceStatus>[ProvenanceStatus.confirmed, ProvenanceStatus.conflicting]),
          ProvenanceStatus.conflicting);
    });

    test('données : arrêts CONFLICTING du B1 (brt_06, brt_22) non badgés « OFFICIEL »', () {
      final DetailedRoute b1 = DetailedRoute.fromOperator('brt')!;
      final List<DetailedStop> contestes = b1.stops.where((DetailedStop s) {
        final BusStop b = appDataService.stops.firstWhere((BusStop x) => x.id == s.stopId);
        return b.provenance.status == ProvenanceStatus.conflicting;
      }).toList();
      expect(contestes, isNotEmpty, reason: 'le JSON audité marque brt_06 et brt_22 CONFLICTING');
      for (final DetailedStop s in contestes) {
        expect(b1.statusOf(s), ProvenanceStatus.conflicting, reason: s.name);
        expect(ReliabilityLabel.badge(b1.statusOf(s)), 'CONTESTÉ', reason: s.name);
      }
    });

    test('données : chaque route CONFLICTING du JSON reste non confirmée à l\'affichage', () {
      final List<TransportRoute> conflictuelles = appDataService.routes
          .where((TransportRoute r) => r.provenance.status == ProvenanceStatus.conflicting)
          .toList();
      expect(conflictuelles, isNotEmpty);
      for (final TransportRoute r in conflictuelles) {
        final ProvenanceStatus affiche = ReliabilityLabel.combine(
            <ProvenanceStatus>[r.provenance.status, ProvenanceStatus.confirmed]);
        expect(ReliabilityLabel.canShowOfficial(affiche), isFalse, reason: r.id);
      }
    });
  });

  // ==================================================================
  // 3. Une route FUTURE n'est pas présentée comme active.
  // ==================================================================
  group('3 — FUTURE n\'est jamais présenté comme actif', () {
    test('règle', () {
      expect(ReliabilityLabel.isPresentedAsActive(ProvenanceStatus.future), isFalse);
      expect(ReliabilityLabel.canShowOfficial(ProvenanceStatus.future), isFalse);
      expect(ReliabilityLabel.badge(ProvenanceStatus.future), 'PROCHAINEMENT');
      // Même si tous les arrêts sont confirmés, une ligne future reste future.
      expect(
          ReliabilityLabel.combine(<ProvenanceStatus>[
            ProvenanceStatus.future,
            ProvenanceStatus.confirmed,
            ProvenanceStatus.confirmed,
          ]),
          ProvenanceStatus.future);
    });

    test('assistant : une ligne FUTURE est annoncée, pas listée comme en service', () {
      final String txt = AssistantReplies.modeInfo(
        'ter',
        <Operator>[Operator(id: 'ter', name: 'TER', colorHex: '#000000')],
        <TransportRoute>[_route('ter_aibd_test', ProvenanceStatus.future, op: 'ter')],
      );
      expect(txt, contains('pas encore en service'));
      expect(txt, isNot(contains('TER_AIBD_TEST (')),
          reason: 'une ligne FUTURE ne doit pas être décrite comme une ligne confirmée');
    });
  });

  // ==================================================================
  // 4. UNKNOWN ne devient jamais REAL_TIME.
  // ==================================================================
  group('4 — UNKNOWN ne devient jamais REAL_TIME', () {
    test('règle : aucune liste de départs ne produit REAL_TIME', () {
      expect(ReliabilityLabel.scheduleStatusOf(const <int>[]), ScheduleStatus.unknown);
      expect(ReliabilityLabel.scheduleStatusOf(const <int>[600]), ScheduleStatus.scheduled);
      expect(ReliabilityLabel.guardRealtime(ScheduleStatus.realTime), ScheduleStatus.unknown);
      expect(ReliabilityLabel.guardRealtime(ScheduleStatus.unknown), ScheduleStatus.unknown);
      expect(ScheduleStatus.unknown.displayLabel(), 'Horaire indisponible');
    });

    test('données : aucune route du JSON n\'est REAL_TIME', () {
      for (final TransportRoute r in appDataService.routes) {
        expect(r.scheduleStatus, isNot(ScheduleStatus.realTime), reason: r.id);
      }
    });

    test('arrêt sans horaire : « Horaire indisponible », aucune heure calculée', () {
      final Stop s = _stop('Arrêt sans horaire');
      expect(s.scheduleStatus, ScheduleStatus.unknown);
      expect(s.nextDepartureMinutes(), isNull);
      expect(s.remainingMinutes(), isNull);
      expect(s.departureAfter(0), isNull);
      expect(s.nextDepartureLabel(), 'Horaire indisponible');
    });

    test('aucun arrêt affiché ne porte d\'horaire fabriqué', () {
      for (final Stop s in allStops) {
        expect(s.departureMinutesFromMidnight, isEmpty, reason: s.name);
        expect(s.scheduleStatus, ScheduleStatus.unknown, reason: s.name);
      }
    });

    test('horaire fourni : présenté comme programmé, jamais comme temps réel', () {
      final Stop s = _stop('Arrêt programmé', departures: const <int>[23 * 60 + 59]);
      expect(s.scheduleStatus, ScheduleStatus.scheduled);
      expect(s.scheduleStatus, isNot(ScheduleStatus.realTime));
    });
  });

  // ==================================================================
  // 5. L'assistant ne génère aucun horaire absent des données vérifiées.
  // ==================================================================
  group('5 — l\'assistant n\'invente aucun horaire', () {
    test('itinéraire sans horaire : phrase imposée, aucune heure, aucune fréquence', () {
      // Deux gares TER du JSON (intégrées dans allStops par setUpAll).
      final RouteSearchResult res =
          RoutePlanner.plan(fromQuery: 'Gare TER Dakar', toQuery: 'Rufisque - Gare TER');
      expect(res.errorMessage, isNull);
      expect(res.hasRoutes, isTrue, reason: 'gares présentes dans allStops');
      final PlannedRoute r = res.routes.first;
      for (final RouteSegment seg in r.segments) {
        expect(seg.departureTime, isNull);
        expect(seg.arrivalTime, isNull);
        expect(seg.status, DataStatus.unknown);
      }
      final String txt = AssistantReplies.itinerary(r, 'Dakar', 'Rufisque');
      expect(txt, contains("Je ne dispose pas d'un horaire vérifié pour ce trajet."));
      expect(kHeure.hasMatch(txt), isFalse, reason: txt);
      expect(kFrequence.hasMatch(txt), isFalse, reason: txt);
      expect(kTempsReel.hasMatch(txt), isFalse, reason: txt);
      expect(txt, isNot(contains('Direct')));
    });

    test('réponses réseau : ni « 14 gares », ni fréquence, ni heure, ni temps réel', () {
      for (final String op in <String>['ter', 'brt', 'ddd', 'tata', 'aftu']) {
        final String txt =
            AssistantReplies.modeInfo(op, appDataService.operators, appDataService.routes);
        expect(txt, isNot(contains('14 gares')), reason: op);
        expect(kHeure.hasMatch(txt), isFalse, reason: '$op : $txt');
        expect(kFrequence.hasMatch(txt), isFalse, reason: '$op : $txt');
        expect(kTempsReel.hasMatch(txt), isFalse, reason: '$op : $txt');
        expect(txt, contains("Je ne dispose d'aucun horaire"), reason: op);
      }
    });

    test('réponses réseau : chiffres tirés des données', () {
      final TransportRoute ter =
          appDataService.routes.firstWhere((TransportRoute r) => r.operatorId == 'ter');
      final String txtTer =
          AssistantReplies.modeInfo('ter', appDataService.operators, appDataService.routes);
      expect(txtTer, contains('${ter.stopIds.length} arrêts'));

      final String txtDdd =
          AssistantReplies.modeInfo('ddd', appDataService.operators, appDataService.routes);
      final int nDdd =
          appDataService.routes.where((TransportRoute r) => r.operatorId == 'ddd').length;
      expect(txtDdd, contains('38 ligne(s)'), reason: 'total CETUD porté par le JSON');
      expect(txtDdd, contains('$nDdd ligne(s)'));
      expect(txtDdd, contains('ne sont pas vérifiées'));
      expect(txtDdd, isNot(contains('Sandaga-Ouakam')));
    });

    test('source : anciens textes inventés absents du code', () {
      final String code = _codeSansCommentaires(File('lib/main.dart').readAsStringSync());
      for (final String interdit in <String>[
        '14 gares officielles',
        'toutes les 10 à 20 min',
        'Rotation ~5 min',
        'fonctionnent normalement',
        'Alertes en temps réel',
        'aux horaires habituels',
        'Service de 5h00 à 22h30',
      ]) {
        expect(code.contains(interdit), isFalse, reason: interdit);
      }
    });
  });

  // ==================================================================
  // Garde-fou rendu — page Alertes : la carte DDD n'affirme plus rien de
  // non vérifié (3 cartes conservées, cf. groupe 6).
  // ==================================================================
  testWidgets('RENDU : la carte DDD ne revendique ni officiel ni horaires', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AlertsPage()));
    await tester.pumpAndSettle();

    final List<String> textes = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
    expect(textes, contains('Données non vérifiées'));
    for (final String t in textes) {
      expect(t, isNot(contains('horaires habituels')));
      expect(t, isNot(contains('Direction DDD')));
      expect(t, isNot(contains('Réseau actif')));
      expect(t, isNot(contains('certifiées')));
    }
  });
}
