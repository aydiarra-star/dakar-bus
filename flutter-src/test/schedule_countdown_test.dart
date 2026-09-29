// LOT 1 — HORAIRES : compte à rebours réel, fuseau Dakar, cas limites.
//
// Règle absolue : un « X min » n'est affiché en vert que lorsqu'une heure de
// départ EXACTE permet de le calculer. Une fréquence officielle n'est jamais
// convertie en faux prochain passage. L'heure de référence est celle de Dakar
// (Africa/Dakar, UTC+00), jamais l'heure locale du navigateur.
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/dakar_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 10:00 heure de Dakar (UTC), base déterministe pour les comptes à rebours.
final DateTime kBase = DateTime.utc(2026, 9, 28, 10, 0);

int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

Stop _stopWithDepartures(List<int> departures, {String mode = 'TER'}) => Stop(
      name: 'Arrêt test',
      direction: '',
      distanceMeters: 0,
      departureMinutesFromMidnight: departures,
      icon: Icons.circle,
      color: const Color(0xFF000000),
      location: const LatLng(14.7, -17.45),
      modeLabel: mode,
    );

String _codeSansCommentaires() => File('lib/main.dart')
    .readAsStringSync()
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==================================================================
  // Fuseau horaire de Dakar (Africa/Dakar, UTC+00, sans heure d'été)
  // ==================================================================
  group('fuseau Dakar', () {
    test('l\'horloge réseau est nommée Africa/Dakar et renvoie un instant UTC', () {
      expect(DakarClock.timeZone, 'Africa/Dakar');
      expect(DakarClock.now().isUtc, isTrue);
      expect(DakarClock.now().timeZoneOffset, Duration.zero);
    });

    test('une référence locale est ramenée à son instant réel (UTC)', () {
      final DateTime local = DateTime(2026, 9, 28, 10, 0);
      final DateTime dakar = DakarClock.toDakar(local);
      expect(dakar.isUtc, isTrue);
      // Conversion d'INSTANT : local et UTC décrivent le même moment.
      expect(dakar, equals(local.toUtc()));
    });

    test('une référence déjà UTC est conservée telle quelle', () {
      expect(DakarClock.toDakar(kBase), kBase);
    });

    test('le compte à rebours ne dépend pas du fuseau d\'expression de l\'instant', () {
      // Le même instant exprimé en heure locale puis en UTC doit donner le même
      // résultat : c'est ce qui empêche un utilisateur hors Dakar de voir un
      // décalage de plusieurs heures sur le prochain départ.
      final Stop stop = _stopWithDepartures(<int>[_minuteOfDay(kBase) + 3]);
      expect(stop.realRemainingMinutes(at: kBase), 3);
      expect(stop.realRemainingMinutes(at: kBase.toLocal()), 3);
    });

    test('source : le calcul d\'horaire de main.dart n\'utilise plus DateTime.now()', () {
      expect(_codeSansCommentaires().contains('DateTime.now()'), isFalse,
          reason: 'l\'heure locale du navigateur ne doit plus servir au calcul');
    });

    test('source : data_service.dart n\'utilise pas DateTime.now() (heure de Dakar via DakarClock)', () {
      final String code = File('lib/services/data_service.dart')
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('DateTime.now()'), isFalse,
          reason: 'la référence temporelle par défaut doit être DakarClock.now()');
      expect(code.contains('DakarClock.now()'), isTrue);
    });
  });

  // ==================================================================
  // Compte à rebours réel — 3 / 5 / 12 min
  // ==================================================================
  group('temps restant réel', () {
    test('départ dans 3 minutes → « 3 min »', () {
      final Stop stop = _stopWithDepartures(<int>[_minuteOfDay(kBase) + 3]);
      expect(stop.realRemainingMinutes(at: kBase), 3);
      expect(stop.realRemainingLabel(at: kBase), '3 min');
    });

    test('départ dans 5 minutes → « 5 min »', () {
      final Stop stop = _stopWithDepartures(<int>[_minuteOfDay(kBase) + 5]);
      expect(stop.realRemainingLabel(at: kBase), '5 min');
    });

    test('départ dans 12 minutes → « 12 min »', () {
      final Stop stop = _stopWithDepartures(<int>[_minuteOfDay(kBase) + 12]);
      expect(stop.realRemainingLabel(at: kBase), '12 min');
    });

    test('départ à l\'instant présent → « 1 min » (jamais « 0 min »)', () {
      final Stop stop = _stopWithDepartures(<int>[_minuteOfDay(kBase)]);
      expect(stop.realRemainingLabel(at: kBase), '1 min');
    });

    test('départ passé → aucun temps négatif, état explicite', () {
      final Stop stop =
          _stopWithDepartures(<int>[_minuteOfDay(kBase) - 10]); // il y a 10 min
      expect(stop.realRemainingMinutes(at: kBase), isNull);
      expect(stop.realRemainingLabel(at: kBase), isNull);
      expect(stop.nextDepartureMinutes(at: kBase), isNull);
      expect(stop.nextDepartureLabel(at: kBase), 'Horaire indisponible');
    });

    test('aucun horaire → « Horaire indisponible », pas de faux délai', () {
      final Stop stop = _stopWithDepartures(const <int>[]);
      expect(stop.scheduleStatus, ScheduleStatus.unknown);
      expect(stop.realRemainingMinutes(at: kBase), isNull);
      expect(stop.realRemainingLabel(at: kBase), isNull);
      expect(stop.nextDepartureLabel(at: kBase), 'Horaire indisponible');
    });
  });

  // ==================================================================
  // DepartureInfo : la fréquence n'est jamais un compte à rebours
  // ==================================================================
  group('DepartureInfo', () {
    test('un horaire programmé exact produit un compte à rebours', () {
      final DepartureInfo info = DepartureInfo.scheduled(
        operator: 'TER Dakar',
        routeId: 'ter_dakar_diamniadio',
        scheduledTime: kBase.add(const Duration(minutes: 12)),
      );
      expect(info.status, ScheduleStatus.scheduled);
      expect(info.minutesUntil(kBase), 12);
      expect(DepartureInfo.formatRemainingMinutes(info.minutesUntil(kBase)), '12 min');
    });

    test('un horaire programmé passé ne produit ni 0 min ni négatif', () {
      final DepartureInfo info = DepartureInfo.scheduled(
        operator: 'TER Dakar',
        routeId: 'ter_dakar_diamniadio',
        scheduledTime: kBase.subtract(const Duration(minutes: 1)),
      );
      expect(info.minutesUntil(kBase), isNull);
      expect(DepartureInfo.formatRemainingMinutes(info.minutesUntil(kBase)), isNull);
    });

    test('une fréquence officielle ne produit AUCUN compte à rebours', () {
      final DepartureInfo info = DepartureInfo.unknown(
        operator: 'SunuBRT',
        routeId: 'brt_b1_guediawaye_petersen',
        requestedAt: kBase,
      );
      expect(info.minutesUntil(kBase), isNull);
    });

    test('formatRemainingMinutes : null → null, sinon « N min » (jamais 0)',
        () {
      expect(DepartureInfo.formatRemainingMinutes(null), isNull);
      expect(DepartureInfo.formatRemainingMinutes(3), '3 min');
      expect(DepartureInfo.formatRemainingMinutes(12), '12 min');
      expect(DepartureInfo.formatRemainingMinutes(0), '1 min');
      expect(DepartureInfo.formatRemainingMinutes(-5), '1 min');
    });
  });

  // ==================================================================
  // Données réelles : les fréquences estimées ne deviennent pas un « X min »
  // ==================================================================
  group('données actives', () {
    setUpAll(() async {
      if (!appDataService.isLoaded) {
        await appDataService.loadNetworkData();
      }
      integrateNetworkDataForTest();
    });

    test('aucun arrêt à fréquence estimée ne calcule de temps restant', () {
      // À 10:00 heure de Dakar (lundi), les fréquences TER/BRT s'appliquent.
      final Iterable<Stop> estimes = allStops.where((Stop s) =>
          s.departureInfoAt(at: kBase).status == ScheduleStatus.estimated);
      expect(estimes, isNotEmpty,
          reason: 'les gares TER/BRT portent une fréquence officielle applicable à 10:00');
      for (final Stop s in estimes) {
        expect(s.realRemainingMinutes(at: kBase), isNull, reason: s.name);
        expect(s.realRemainingLabel(at: kBase), isNull, reason: s.name);
      }
    });

    test('aucun arrêt des données actives ne porte de compte à rebours fabriqué', () {
      for (final Stop s in allStops) {
        expect(s.realRemainingMinutes(at: kBase), isNull,
            reason: '${s.name} : aucun horaire exact n\'existe dans le JSON');
      }
    });
  });

  // ==================================================================
  // RENDU — le temps restant réel s'affiche en vert
  // ==================================================================
  group('rendu', () {
    Future<void> monte(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      await tester.pumpAndSettle();
    }

    testWidgets('un horaire exact s\'affiche « X min » en vert', (WidgetTester tester) async {
      // Départ ~5 min après l'instant courant pour rester stable au rendu.
      final int departure =
          _minuteOfDay(DakarClock.now()) + 5;
      final Stop stop = _stopWithDepartures(<int>[departure]);
      await monte(tester, StopCard(stop: stop, distanceMeters: 300));

      final Finder finder = find.byWidgetPredicate(
        (Widget w) => w is Text && w.data != null && RegExp(r'^\d+ min$').hasMatch(w.data!),
      );
      expect(finder, findsOneWidget);
      final Text text = tester.widget<Text>(finder);
      expect(text.style?.color, AppColors.success,
          reason: 'le temps restant réel doit être affiché en vert');
    });

    testWidgets('une fréquence estimée n\'affiche pas de faux « X min »',
        (WidgetTester tester) async {
      // À l'heure réelle du test, une gare TER peut être hors plage (UNKNOWN).
      // Le point vérifié est qu'aucun arrêt, quel que soit son état, ne produit
      // de faux compte à rebours à partir d'une fréquence.
      final Stop estime = allStops.firstWhere(
        (Stop s) => s.departureInfoAt(at: kBase).status == ScheduleStatus.estimated,
      );
      await monte(tester, StopCard(stop: estime, distanceMeters: 300));

      final List<String> textes = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .toList();
      expect(
        textes.where((String t) => RegExp(r'^\d+ min$').hasMatch(t)),
        isEmpty,
        reason: 'une fréquence n\'est pas un prochain départ : $textes',
      );
    });
  });
}
