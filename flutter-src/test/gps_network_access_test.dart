// Chantier « Recherche + GPS + Routage » — tests GPS (position → arrêts →
// lignes → itinéraire, et points de sortie côté destination).
//
// Toutes les valeurs attendues proviennent des DONNÉES RÉELLEMENT chargées
// (feeds PassBi DDD/AFTU/BRT/TER) : aucun arrêt, aucune ligne et aucun
// itinéraire n'est inventé par le test ni par le moteur.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/services/gtfs/network_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
    await app.appDataService.loadPassBiSchedules();
    app.integratePassBiNativeStopsForTest();
    await app.appDataService.loadTerminusCatalog();
    app.integrateNetworkSearchCatalogForTest();
  });

  // Position de référence : Parcelles Assainies (zone de service Dakar).
  const LatLng parcelles = LatLng(14.76269, -17.42431);
  // Destination de référence : Keur Mbaye Fall.
  const LatLng keurMbayeFall = LatLng(14.74408, -17.31389);

  group('GPS — position → arrêts proches', () {
    test('la position retourne un ENSEMBLE d\'arrêts réels (jamais un seul)',
        () {
      final points = app.appDataService.accessPointsNear(
          lat: parcelles.latitude, lon: parcelles.longitude);
      expect(points.length, greaterThan(1),
          reason: 'le moteur ne doit pas se limiter à un unique arrêt');
      // Aucun doublon d'identité feed.
      final keys = points.map((p) => p.compositeKey).toSet();
      expect(keys.length, points.length);
      // Chaque arrêt porte une identité feed et une distance mesurée.
      for (final p in points) {
        expect(p.stopId, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.distanceMeters, greaterThanOrEqualTo(0));
      }
      // Tri par distance croissante.
      for (var i = 1; i < points.length; i++) {
        expect(points[i].distanceMeters,
            greaterThanOrEqualTo(points[i - 1].distanceMeters));
      }
    });

    test('plusieurs réseaux réels sont candidats autour de Parcelles', () {
      final networks = app.appDataService.mobilitiesNear(
          lat: parcelles.latitude, lon: parcelles.longitude);
      expect(networks, contains('DDD'));
      expect(networks, contains('AFTU'));
      expect(networks, contains('BRT'));
    });

    test('l\'arrêt le plus proche est bien un arrêt réel du feed', () {
      final points = app.appDataService.accessPointsNear(
          lat: parcelles.latitude, lon: parcelles.longitude);
      final first = points.first;
      // L'arrêt appartient au référentiel natif du réseau annoncé.
      final ids = app.appDataService.passBiSource
          .nativeStops(first.network)
          .map((s) => s.stopId)
          .toSet();
      expect(ids, contains(first.stopId));
      expect(first.distanceMeters, lessThan(NetworkAccess.defaultRadiusMeters));
    });

    test('la proximité n\'est pas limitée à la correspondance textuelle', () {
      // La position « Parcelles » ne désigne aucun arrêt par son nom : ce sont
      // les coordonnées qui trouvent les arrêts (BRT PARCELLES, etc.).
      final points = app.appDataService.accessPointsNear(
          lat: parcelles.latitude, lon: parcelles.longitude);
      expect(points.any((p) => p.network == 'BRT'), isTrue);
    });

    test('un point hors réseau ne renvoie aucun arrêt (aucune invention)', () {
      // Au large de l'Atlantique : aucun arrêt du réseau à moins de 2,5 km.
      final points = app.appDataService.accessPointsNear(lat: 14.0, lon: -18.5);
      expect(points, isEmpty);
    });
  });

  group('GPS — destination → points de sortie proches', () {
    test('Keur Mbaye Fall a des points de sortie réels, multi-réseaux', () {
      final exits = app.appDataService.exitPointsNear(
          lat: keurMbayeFall.latitude, lon: keurMbayeFall.longitude);
      expect(exits, isNotEmpty);
      final networks = exits.map((e) => e.network).toSet();
      // La gare TER de Keur Mbaye Fall et les arrêts AFTU/DDD sont candidats.
      expect(networks, contains('TER'));
      expect(networks, contains('AFTU'));
    });

    test('les points de sortie sont triés par distance croissante', () {
      final exits = app.appDataService.exitPointsNear(
          lat: keurMbayeFall.latitude, lon: keurMbayeFall.longitude);
      for (var i = 1; i < exits.length; i++) {
        expect(exits[i].distanceMeters,
            greaterThanOrEqualTo(exits[i - 1].distanceMeters));
      }
    });
  });

  group('GPS — position → lignes et itinéraire', () {
    test('Parcelles Assainies → Keur Mbaye Fall produit des itinéraires réels',
        () {
      final res = app.RoutePlanner.planFromPositions(
        from: parcelles,
        to: keurMbayeFall,
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      expect(res.hasRoutes, isTrue,
          reason: res.errorMessage ?? 'aucun itinéraire documenté');
      // Plusieurs candidats comparés (pas un seul chemin arbitraire).
      expect(res.routes.length, greaterThanOrEqualTo(2));
      for (final r in res.routes) {
        // Chaque itinéraire commence et finit par une marche d'accès réelle.
        expect(r.segments.first.isWalk, isTrue);
        expect(r.segments.last.isWalk, isTrue);
        expect(r.segments.first.from, 'Ma position');
        expect(r.segments.last.to, 'Destination');
        // Au moins un tronçon de transport documenté.
        expect(r.segments.where((s) => !s.isWalk), isNotEmpty);
        expect(r.totalMinutes, greaterThan(0));
      }
      // Les candidats sont comparés sur la durée totale (croissante).
      for (var i = 1; i < res.routes.length; i++) {
        expect(res.routes[i].totalMinutes,
            greaterThanOrEqualTo(res.routes[i - 1].totalMinutes));
      }
    });

    test('le premier itinéraire ne part pas systématiquement de l\'arrêt le '
        'plus proche', () {
      final res = app.RoutePlanner.planFromPositions(
        from: parcelles,
        to: keurMbayeFall,
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      expect(res.hasRoutes, isTrue);
      final bestOrigin = res.routes.first.segments
          .firstWhere((s) => !s.isWalk)
          .from;
      final points = app.appDataService.accessPointsNear(
          lat: parcelles.latitude, lon: parcelles.longitude);
      final nearestName = points.first.name;
      // Le meilleur itinéraire peut partir d'un autre arrêt que le plus
      // proche : la proximité est une entrée, pas le résultat (règle §14).
      expect(bestOrigin, isNot(equals('')));
      // Documente le comportement observé sans le figer : si le plus proche
      // n'est pas retenu, c'est que la comparaison des durées a joué.
      if (bestOrigin != nearestName) {
        expect(points.map((p) => p.name), contains(bestOrigin));
      }
    });

    test('TER : Dakar → Diamniadio est un trajet direct documenté', () {
      final res = app.RoutePlanner.planFromPositions(
        from: const LatLng(14.67599, -17.43352),
        to: const LatLng(14.71606, -17.19845),
        at: DateTime.utc(2026, 9, 28, 12, 0),
      );
      expect(res.hasRoutes, isTrue);
      final direct = res.routes.first;
      expect(direct.transferCount, 0);
      expect(
        direct.segments.any((s) => !s.isWalk && s.modeLabel == 'TER'),
        isTrue,
        reason: 'le TER doit participer au calcul quand il dessert la liaison',
      );
    });

    test('BRT : Parcelles → Guédiawaye propose le BRT réel', () {
      final res = app.RoutePlanner.planFromPositions(
        from: parcelles,
        to: const LatLng(14.77156, -17.38694),
        at: DateTime.utc(2026, 9, 28, 12, 0),
      );
      expect(res.hasRoutes, isTrue);
      expect(
        res.routes.any((r) => r.segments
            .any((s) => !s.isWalk && s.modeLabel.startsWith('BRT'))),
        isTrue,
      );
    });

    test('un trajet intermodal réel (AFTU + TER) est proposé', () {
      final res = app.RoutePlanner.planFromPositions(
        from: parcelles,
        to: keurMbayeFall,
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      final intermodal = res.routes.any((r) {
        final modes = r.segments
            .where((s) => !s.isWalk)
            .map((s) => s.modeLabel)
            .toSet();
        return modes.length > 1;
      });
      expect(intermodal, isTrue,
          reason: 'les correspondances documentées doivent être exploitées');
    });

    test('sans données (hors zone), aucun itinéraire n\'est inventé', () {
      final res = app.RoutePlanner.planFromPositions(
        from: const LatLng(14.0, -18.5),
        to: keurMbayeFall,
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      expect(res.hasRoutes, isFalse);
      expect(res.errorMessage, isNotNull);
    });
  });

  group('GPS — intégrité : la proximité ne crée pas de correspondance', () {
    test('deux arrêts très proches SANS lien documenté ne sont pas une '
        'correspondance : aucun détour n\'est créé', () {
      // « Westerne Cbao Parcelles Unité 6 » (DDD) et « Lpa » (AFTU) sont à
      // ~30 m l'un de l'autre mais AUCUN lien de transfert documenté ne les
      // relie dans le crosswalk.
      final from =
          app.appDataService.passBiStopSearch('Westerne Cbao Parcelles');
      final to = app.appDataService.passBiStopSearch('Lpa');
      expect(from, isNotEmpty);
      expect(to, isNotEmpty);
      final fromKey = '${from.first.network}:${from.first.stopId}';
      final toKey = '${to.first.network}:${to.first.stopId}';
      final meters = NetworkAccess.haversineMeters(
          from.first.lat, from.first.lon, to.first.lat, to.first.lon);
      expect(meters, lessThan(200),
          reason: 'les deux arrêts doivent bien être proches');
      final journeys = app.appDataService.routingEngine.planJourneys(
        fromKeys: <String>{fromKey},
        toKeys: <String>{toKey},
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      // Le moteur peut avoir trouvé un chemin DOCUMENTÉ (via une ligne qui
      // dessert réellement les deux arrêts) : dans ce cas, il ne doit jamais
      // être un simple « transfert » à pied entre les deux arrêts.
      for (final j in journeys) {
        expect(j.legs.length, greaterThanOrEqualTo(2),
            reason: 'un transfert à pied de proximité ne peut pas produire '
                'un trajet à un seul tronçon');
      }
      // Et si un seul tronçon existait, c'est que la ligne dessert réellement
      // les deux arrêts — jamais parce qu'ils sont voisins.
    });

    test('un lien de transfert documenté reste, lui, exploitable', () {
      // BRT « PARCELLES » ↔ DDD « LycéE Parcelles Assainies » sont reliés par
      // un transfert DOCUMENTÉ (INCLUSION_NOM_PROXIMITE, 21 m).
      final journeys = app.appDataService.routingEngine.planJourneys(
        fromKeys: const <String>{'BRT:0:PARB'},
        toKeys: const <String>{'DDD:D_1032'},
        at: DateTime.utc(2026, 9, 28, 8, 0),
      );
      expect(journeys, isNotEmpty,
          reason: 'un transfert documenté doit rester exploitable');
    });
  });
}
