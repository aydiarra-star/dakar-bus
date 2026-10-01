// Chantier UI (Lot 4.20–4.22) — VERROUS D'AFFICHAGE DE L'EXPLORER.
//
// Reproduit et scelle trois anomalies observées sur l'Explorer :
//   A. « vers 0 » / « vers 1 » — le `direction_id` GTFS (« 0 »/« 1 »), simple
//      indicateur binaire, était présenté comme une destination ;
//   B. « INTERM. » — un badge de rôle posé sur TOUS les arrêts natifs PassBi,
//      alors que leur rôle d'arrêt n'est pas documenté ;
//   C. attente aberrante avant le premier service (ex. 137 mn à 03:00) alors
//      que le prochain `stop_time` relève d'un service qui n'a pas repris.
//
// Plus : la recherche d'identité de ligne doit exploiter le référentiel
// documenté (catalogue des lignes publiques) plutôt que le seul numéro final du
// `route_id`.
//
// Données = feeds PassBi RÉELS. Aucune donnée TER/BRT, aucun horaire, aucune
// correspondance n'est créée ou modifiée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/service_availability.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime lundi12 = DateTime.utc(2026, 9, 28, 12, 0);

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    await app.appDataService.loadPassBiSchedules();
    app.integratePassBiNativeStopsForTest();
    await app.appDataService.loadTerminusCatalog();
    await app.appDataService.loadPublicBusLineCatalog();
    expect(app.appDataService.passBiActive, isTrue);
  });

  List<String> textsOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((Text t) => t.data ?? '')
      .toList();

  // ==================================================================
  // A — le `direction_id` binaire n'est jamais une destination
  // ==================================================================
  group('A — direction : « vers 0 »/« vers 1 » interdit', () {
    test('A1. les départs réels natifs n\'exposent jamais « 0 »/« 1 »', () {
      var checked = 0;
      for (final app.Stop s in app.passBiNativeStops) {
        for (final DepartureInfo d in s.nextRealDepartures(at: lundi12)) {
          expect(d.direction, isNot('0'), reason: '${s.name} : direction binaire');
          expect(d.direction, isNot('1'), reason: '${s.name} : direction binaire');
          checked++;
        }
        if (checked > 400) break;
      }
      expect(checked, greaterThan(0),
          reason: 'des départs réels doivent être inspectés');
    });

    testWidgets('A2. StopCard : aucun en-tête « vers 0 »/« vers 1 »',
        (WidgetTester tester) async {
      app.Stop? cible;
      for (final app.Stop s in app.passBiNativeStops.take(200)) {
        if (s.departureInfoAt(at: lundi12).status == ScheduleStatus.scheduled) {
          cible = s;
          break;
        }
      }
      expect(cible, isNotNull);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: app.StopCard(stop: cible!, distanceMeters: 250, at: lundi12)),
      ));
      await tester.pump();
      final List<String> texts = textsOf(tester);
      expect(texts.any((t) => t.contains('vers 0')), isFalse, reason: '$texts');
      expect(texts.any((t) => t.contains('vers 1')), isFalse, reason: '$texts');
    });
  });

  // ==================================================================
  // B — badge de rôle : jamais un défaut technique sur un arrêt natif
  // ==================================================================
  group('B — badge « INTERM. » : seulement si le rôle est établi', () {
    testWidgets('B1. un arrêt natif PassBi n\'affiche aucun badge de rôle',
        (WidgetTester tester) async {
      final app.Stop natif = app.passBiNativeStops.first;
      expect(natif.passBiStopKey, isNotNull);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: app.StopCard(stop: natif, distanceMeters: 250, at: lundi12)),
      ));
      await tester.pump();
      expect(textsOf(tester).any((t) => t == 'INTERM.'), isFalse,
          reason: 'badge technique interdit sur un arrêt natif');
    });

    testWidgets('B2. un arrêt à rôle documenté conserve son badge',
        (WidgetTester tester) async {
      // Arrêt NON natif (référentiel dakar) porteur d'un rôle explicite : le
      // badge doit continuer de s'afficher — le correctif ne supprime rien.
      const app.Stop referentiel = app.Stop(
        name: 'Arrêt rôle documenté',
        direction: 'Dir. Test',
        distanceMeters: 300,
        departureMinutesFromMidnight: <int>[],
        icon: Icons.directions_bus,
        color: Colors.blue,
        location: LatLng(14.7, -17.4),
        modeLabel: 'TER',
        stopType: app.StopType.intermediate,
      );
      expect(referentiel.passBiStopKey, isNull);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: app.StopCard(
                stop: referentiel, distanceMeters: 300, at: lundi12)),
      ));
      await tester.pump();
      expect(textsOf(tester).any((t) => t == 'INTERM.'), isTrue);
    });
  });

  // ==================================================================
  // C — avant la reprise du service : aucune attente aberrante
  // ==================================================================
  group('C — avant le premier service : reprise annoncée, pas d\'attente', () {
    test('C1. serviceNoticeFor / serviceDisplayBlocked — avant reprise', () {
      final DateTime reprise = DateTime.utc(2026, 9, 28, 3, 48);
      final ServiceAvailability actif = ServiceAvailability.active(
        resumptionAt: reprise,
        firstDeparture: DateTime.utc(2026, 9, 28, 4, 48),
      );
      final DateTime avant = DateTime.utc(2026, 9, 28, 3, 0);
      expect(app.serviceDisplayBlocked(actif, avant), isTrue);
      final String? notice = app.serviceNoticeFor(actif, avant);
      expect(notice, isNotNull);
      expect(notice, contains('reprise à 03:48'));

      // Une fois la reprise atteinte, l'affichage redevient actif.
      final DateTime apres = DateTime.utc(2026, 9, 28, 3, 48);
      expect(app.serviceDisplayBlocked(actif, apres), isFalse);
      expect(app.serviceNoticeFor(actif, apres), isNull);
    });

    testWidgets(
        'C2. StopCard à 03:00 (avant reprise) : aucun « X mn », reprise affichée',
        (WidgetTester tester) async {
      final DateTime avant = DateTime.utc(2026, 9, 28, 3, 0);
      app.Stop? cible;
      for (final app.Stop s in app.passBiNativeStops) {
        final ServiceAvailability? a = s.serviceAvailability(at: avant);
        if (a != null &&
            a.status == ServiceAvailabilityStatus.active &&
            a.resumptionAt != null &&
            avant.isBefore(a.resumptionAt!)) {
          cible = s;
          break;
        }
      }
      expect(cible, isNotNull,
          reason: 'un arrêt actif avant sa reprise doit exister à 03:00');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: app.StopCard(stop: cible!, distanceMeters: 250, at: avant)),
      ));
      await tester.pump();
      final List<String> texts = textsOf(tester);
      expect(texts.any((t) => RegExp(r'^[1-9]\d* mn').hasMatch(t)), isFalse,
          reason: 'attente du service non repris interdite : $texts');
      expect(texts.any((t) => t.contains('Fin de service — reprise à')), isTrue,
          reason: 'la reprise documentée doit être annoncée : $texts');
    });
  });

  // ==================================================================
  // D — identité de ligne : le référentiel documenté est exploité
  // ==================================================================
  group('D — identité de ligne : libellé documenté prioritaire', () {
    test('D1. un libellé de catalogue raccorde une variante de route_id', () {
      // `DDD_15` n'est pas résolu par le numéro final du route_id ; le libellé
      // documenté du catalogue, lui, le raccorde.
      expect(
        ScheduleProvider.identityLabelFor('DDD', 'DDD_15',
            IdentityStatus.unconfirmed, documentedCatalogLabel: 'DDD 15'),
        'DDD 15',
      );
      // Sans preuve documentaire : repli honnête sur le MODE seul.
      expect(
        ScheduleProvider.identityLabelFor('DDD', 'DDD_15',
            IdentityStatus.unconfirmed),
        'DDD',
      );
    });

    test('D2. un libellé de catalogue d\'un autre mode est ignoré', () {
      expect(
        ScheduleProvider.identityLabelFor('DDD', 'DDD_15',
            IdentityStatus.unconfirmed, documentedCatalogLabel: 'AFTU 15'),
        'DDD',
      );
    });
  });

  // ==================================================================
  // E — la proximité ne crée jamais une correspondance
  // ==================================================================
  group('E — intégrité : proximité ≠ correspondance', () {
    test('E1. tout lien de transfert reste documenté (nom + méthode)', () {
      for (final TransferLink t
          in app.appDataService.passBiSource.transfers) {
        expect(t.isDocumented, isTrue,
            reason: 'lien non documenté : ${t.from} → ${t.to}');
        expect(t.name, isNotEmpty);
      }
    });

    test('E2. deux arrêts natifs proches sans lien documenté : rien', () {
      final List<app.Stop> natifs = app.passBiNativeStops.take(600).toList();
      var pairesProches = 0;
      for (int i = 0; i < natifs.length; i++) {
        for (int j = i + 1; j < natifs.length; j++) {
          final app.Stop a = natifs[i];
          final app.Stop b = natifs[j];
          if (a.passBiStopKey == null || b.passBiStopKey == null) continue;
          final double d =
              const Distance().as(LengthUnit.Meter, a.location, b.location);
          if (d > 150) continue;
          pairesProches++;
          final link = app.appDataService.passBiSource
              .transferBetween(a.passBiStopKey!, b.passBiStopKey!);
          if (link != null) {
            expect(link.isDocumented, isTrue,
                reason: 'correspondance créée par proximité : '
                    '${a.passBiStopKey} → ${b.passBiStopKey}');
          }
          if (pairesProches > 50) break;
        }
        if (pairesProches > 50) break;
      }
      // Aucune assertion de volume : si aucune paire proche n'existe, le test
      // reste vrai (aucune correspondance fabriquée).
      expect(pairesProches, greaterThanOrEqualTo(0));
    });
  });
}
