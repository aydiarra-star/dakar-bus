import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';

/// CORRECTION TER + BRT — structure des données et des itinéraires.
///
/// Ce fichier fige la séparation imposée entre les deux notions :
///
///   `<MODE>_NETWORK_POINTS`       les points du réseau visibles dans Explorer
///   `<MODE>_OFFICIAL_ROUTE_STOPS` les arrêts officiels d'un itinéraire
///
/// Explorer peut afficher davantage de points que l'itinéraire officiel ne
/// compte de stations ; l'inverse n'est jamais vrai, et un point d'Explorer
/// n'est jamais promu dans un itinéraire officiel au seul motif qu'il apparaît
/// sur la carte.
///
/// Données de référence : `assets/data/dakar_network.json`,
/// md5 81c778f4644dcf5e1cf4ae25879218f0, 59 189 octets — source unique (§4-§5),
/// identique octet par octet au JSON servi par gh-pages 94a84b6070569.
///
/// Référence du comportement combattu : la branche BRT codée en dur du binaire
/// de production (`a3j`, gh-pages) renvoyait **11** stations regroupées —
/// Guédiawaye, Hôpital Dalal Jamm, Parcelles Assainies, Cambérène, Grand Yoff,
/// Fadia, Liberté 6, Grand Médine, Sacré-Cœur, Place de l'Obélisque,
/// Gare de Petersen — avec l'en-tête littéral « 14.0 km ». Le §7 interdit ce
/// modèle ; les tests ci-dessous verrouillent les 23 stations officielles
/// distinctes à la place.

/// Les 13 gares de l'itinéraire TER, ordre Dakar -> Diamniadio (§6).
const List<String> kTer13 = <String>[
  'stop_dakar_ter',
  'stop_colobane',
  'stop_hann',
  'stop_dalifort_ter',
  'stop_baux_maraichers',
  'stop_pikine',
  'stop_thiaroye',
  'stop_yeumbeul',
  'stop_keur_mbaye_fall',
  'stop_pnr',
  'stop_rufisque',
  'stop_bargny',
  'stop_diamniadio',
];

/// Les 23 stations SunuBRT de B1, ordre Guédiawaye -> Petersen (§7).
const List<String> kBrtB123 = <String>[
  'stop_brt_23_guediawaye',
  'stop_brt_22_gadaye',
  'stop_brt_21_golf_nord',
  'stop_brt_20_fith_mith',
  'stop_brt_19_dalal_jamm',
  'stop_brt_18_golf_sud',
  'stop_brt_17_ndingala',
  'stop_brt_16_parcelles_assainies',
  'stop_brt_15_croisement_22',
  'stop_brt_14_police_parcelles',
  'stop_brt_13_grand_medine',
  'stop_brt_12_thiandoum',
  'stop_brt_11_scat_urbam',
  'stop_brt_10_khar_yallah',
  'stop_brt_09_liberte_6',
  'stop_brt_08_liberte_5',
  'stop_brt_07_sacre_coeur',
  'stop_brt_06_liberte_1',
  'stop_brt_05_grand_dakar',
  'stop_brt_04_dial_diop',
  'stop_brt_03_obelisque',
  'stop_brt_02_mosquee',
  'stop_brt_01_petersen',
];

/// Les 7 stations directes de B2 Express, toutes incluses dans B1.
///
/// AUDIT DONNÉES 2026-09-24 — séquence corrigée.
/// AVANT : 23, 19, 16 (Parcelles), 13, 09 (Liberté 6), 03, 01.
/// APRÈS : 23, 19, 13, 07 (Sacré-Cœur), 05 (Grand Dakar), 03, 01.
/// RAISON : l'ancienne liste figeait une hypothèse fausse. Le communiqué
///   SunuBRT du 30/09/2024 (lancement de B2 semi-express) nomme les 7 stations :
///   Papa Guèye Fall, Place de la Nation, Grand Dakar, Sacré-Cœur, Grand Médine,
///   Dalal Jam, Préfecture de Guédiawaye. Parcelles et Liberté 6 n'en font pas
///   partie. Les 7 stations restent une sous-séquence ordonnée de B1.
/// SOURCE : https://www.rts.sn/actualite/detail/a-la-une/sunubrt-lance-la-phase-2-avec-sept-nouvelles-stations-et-la-ligne-semi-express-b2
const List<String> kBrtB27 = <String>[
  'stop_brt_23_guediawaye',
  'stop_brt_19_dalal_jamm',
  'stop_brt_13_grand_medine',
  'stop_brt_07_sacre_coeur',
  'stop_brt_05_grand_dakar',
  'stop_brt_03_obelisque',
  'stop_brt_01_petersen',
];

/// Les 11 libellés regroupés de la branche BRT codée en dur de production.
/// Aucun ne doit constituer, à lui seul, une station de l'itinéraire officiel.
const List<String> kLegacyBrt11 = <String>[
  'Guédiawaye',
  'Hôpital Dalal Jamm',
  'Parcelles Assainies',
  'Cambérène',
  'Grand Yoff',
  'Fadia',
  'Liberté 6',
  'Grand Médine',
  'Sacré-Cœur',
  'Place de l’Obélisque',
  'Gare de Petersen',
];

const String kTerRouteId = 'ter_dakar_diamniadio';
const String kBrtB1Id = 'brt_b1_guediawaye_petersen';
const String kBrtB2Id = 'brt_b2_express';

/// Nombre de points TER affichés par Explorer.
///
/// AVANT PR #20 : 21 = 8 points de la liste de démonstration `terStations`
/// + les 13 gares officielles du JSON. Les 8 points de démo (coordonnées
/// héritées, hors tracé officiel) étaient le défaut combattu : 21 TER / 27 BRT
/// visibles sur le site live. Depuis PR #20, TER et BRT proviennent UNIQUEMENT
/// de `dakar_network.json` : Explorer affiche exactement les 13 gares
/// officielles. Ce nombre ne doit jamais être gonflé par une liste de
/// démonstration, ni réduit artificiellement (§6).
const int kTerExplorerPoints = 13;

/// Nombre de points BRT affichés par Explorer : les 23 stations officielles
/// (AVANT PR #20 : 4 de démo + 23).
const int kBrtExplorerPoints = 23;

/// Charge la DONNÉE ACTIVE sur la globale [appDataService] puis exécute
/// l'intégration, dans les mêmes conditions que `main()`.
Future<void> prepareNetwork() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!appDataService.isLoaded) {
    await appDataService.loadNetworkData();
  }
  expect(appDataService.isLoaded, true);
  // Garde : sans lecture de l'asset, le repli codé en dur donnerait 6 arrêts.
  expect(appDataService.stops.length, 117,
      reason: 'la DONNÉE ACTIVE doit être chargée, pas le repli en dur');
  expect(appDataService.routes.length, 105);
  integrateNetworkDataForTest();
}

/// Clé de coordonnées à la précision employée par le service de routage.
String coordKey(double lat, double lon) =>
    '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';

void main() {
  setUpAll(() async {
    await prepareNetwork();
  });

  // ==================================================================
  group('§1 / §6 — Explorer ≠ itinéraire : les deux ensembles restent distincts',
      () {
    test('TER : Explorer conserve tous ses points existants', () {
      final List<Stop> points = networkPoints(AppColors.ter);
      expect(points.length, kTerExplorerPoints,
          reason: 'aucun point d\'Explorer ne doit disparaître (§6, Test TER 1)');
    });

    test('BRT : Explorer conserve tous ses points existants', () {
      final List<Stop> points = networkPoints(AppColors.brt);
      expect(points.length, kBrtExplorerPoints,
          reason: 'aucun point d\'Explorer ne doit disparaître (§6, Test BRT 1)');
    });

    test('Explorer affiche EXACTEMENT les gares TER officielles : mêmes points que l\'itinéraire',
        () {
      // Post-PR #20 : sans liste de démonstration, l'ensemble des points TER
      // d'Explorer et l'ensemble des gares de l'itinéraire officiel sont
      // égaux (mêmes identifiants), tout en restant deux notions distinctes
      // (§1 / §6) : Explorer n'est pas construit à partir de l'itinéraire.
      final Set<String> explorer = networkPoints(AppColors.ter)
          .map((Stop s) => s.stopId)
          .whereType<String>()
          .toSet();
      final Set<String> itineraire =
          officialRouteStops(kTerRouteId)!.map((BusStop s) => s.id).toSet();
      expect(explorer, itineraire,
          reason: 'aucun point TER de démonstration, aucune gare manquante');
      expect(networkPoints(AppColors.ter).every((Stop s) => s.stopId != null),
          true,
          reason: 'chaque point TER d\'Explorer est un arrêt de la source unique');
    });

    test('Explorer affiche EXACTEMENT les stations BRT officielles : mêmes points que B1',
        () {
      final Set<String> explorer = networkPoints(AppColors.brt)
          .map((Stop s) => s.stopId)
          .whereType<String>()
          .toSet();
      final Set<String> itineraire =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toSet();
      expect(explorer, itineraire,
          reason: 'aucune station BRT de démonstration, aucune station manquante');
      expect(networkPoints(AppColors.brt).every((Stop s) => s.stopId != null),
          true);
    });

    test('les 13 gares officielles TER sont bien présentes dans Explorer', () {
      final Set<String> idsAffiches = networkPoints(AppColors.ter)
          .map((Stop s) => s.stopId)
          .whereType<String>()
          .toSet();
      for (final String id in kTer13) {
        expect(idsAffiches.contains(id), true,
            reason: 'la gare officielle $id doit rester visible dans Explorer');
      }
    });

    test('les 23 stations officielles B1 sont bien présentes dans Explorer', () {
      final Set<String> idsAffiches = networkPoints(AppColors.brt)
          .map((Stop s) => s.stopId)
          .whereType<String>()
          .toSet();
      for (final String id in kBrtB123) {
        expect(idsAffiches.contains(id), true,
            reason: 'la station officielle $id doit rester visible dans Explorer');
      }
    });

    test('aucun point d\'Explorer n\'est promu dans l\'itinéraire TER', () {
      // L'itinéraire reste à 13 : la promotion d'un point quelconque du réseau
      // (ex. Keur Massar, présent dans allStops) ferait croître la liste.
      expect(officialRouteStops(kTerRouteId)!.length, 13);
    });

    test('Keur Massar reste hors de l\'itinéraire TER (§6)', () {
      final List<String> ids =
          officialRouteStops(kTerRouteId)!.map((BusStop s) => s.id).toList();
      expect(ids.contains('stop_keur_massar'), false,
          reason: 'Keur Massar est desservi par DDD/AFTU/Tata, jamais par le TER');
      // Il subsiste comme point du réseau, desservi hors TER.
      expect(appDataService.stops.any((BusStop s) => s.id == 'stop_keur_massar'),
          true);
    });
  });

  // ==================================================================
  group('§6 — itinéraire TER : 13 gares officielles, ordre et sens inverse', () {
    test('l\'itinéraire TER compte exactement 13 gares', () {
      expect(officialRouteStops(kTerRouteId)!.length, 13);
    });

    test('ordre exact Dakar -> Diamniadio (§6, Test TER 3)', () {
      expect(officialRouteStops(kTerRouteId)!.map((BusStop s) => s.id).toList(),
          orderedEquals(kTer13));
    });

    test('ordre inverse exact Diamniadio -> Dakar (§7, Test TER 4)', () {
      expect(
          officialRouteStops(kTerRouteId, reverse: true)!
              .map((BusStop s) => s.id)
              .toList(),
          orderedEquals(kTer13.reversed.toList()));
    });

    test('le sens inverse est une INVERSION, pas une seconde liste (§7)', () {
      final List<String> aller =
          officialRouteStops(kTerRouteId)!.map((BusStop s) => s.id).toList();
      final List<String> retour = officialRouteStops(kTerRouteId, reverse: true)!
          .map((BusStop s) => s.id)
          .toList();
      expect(retour, orderedEquals(aller.reversed.toList()));
      expect(retour.toSet(), aller.toSet(),
          reason: 'les deux sens décrivent exactement les mêmes gares');
      expect(retour.length, aller.length);
    });

    test('terminus : Gare TER Dakar en tête, Diamniadio en queue', () {
      final List<BusStop> gares = officialRouteStops(kTerRouteId)!;
      expect(gares.first.name, 'Gare TER Dakar');
      expect(gares.last.name, 'Diamniadio - Gare TER Terminus');
    });

    test('réseau de l\'itinéraire TER = ter', () {
      expect(networkOfRoute(kTerRouteId), 'ter');
    });

    test('chaque gare porte un statut de donnée connu (§9)', () {
      for (final BusStop s in officialRouteStops(kTerRouteId)!) {
        expect(DataTrust.values.contains(s.dataTrust), true,
            reason: '${s.id} : statut de donnée inconnu du modèle');
      }
    });

    test('chaque gare a des coordonnées valides, aucune n\'est à (0,0)', () {
      for (final BusStop s in officialRouteStops(kTerRouteId)!) {
        expect(DakarBounds.isValid(LatLng(s.latitude, s.longitude)), true,
            reason: '${s.id} hors du garde-fou Dakar');
        expect(s.latitude == 0.0 && s.longitude == 0.0, false);
      }
    });

    test('la fiche de ligne TER expose les 13 gares dans l\'ordre', () {
      final DetailedRoute? fiche = DetailedRoute.fromOperator('ter');
      expect(fiche, isNotNull);
      expect(fiche!.stops.length, 13);
      expect(fiche.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kTer13));
      expect(fiche.origin, 'Gare TER Dakar');
      expect(fiche.destination, 'Diamniadio - Gare TER Terminus');
    });

    test('la fiche de ligne TER en sens inverse expose l\'ordre retourné', () {
      final DetailedRoute? fiche =
          DetailedRoute.fromOperator('ter', reverse: true);
      expect(fiche, isNotNull);
      expect(fiche!.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kTer13.reversed.toList()));
      expect(fiche.origin, 'Diamniadio - Gare TER Terminus');
      expect(fiche.destination, 'Gare TER Dakar');
    });
  });

  // ==================================================================
  group('§7 — itinéraire BRT B1 : 23 stations distinctes, ordre et sens inverse',
      () {
    test('B1 compte exactement 23 stations officielles', () {
      expect(officialRouteStops(kBrtB1Id)!.length, 23);
    });

    test('ordre exact Guédiawaye -> Petersen (§7, Test BRT 3)', () {
      expect(officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toList(),
          orderedEquals(kBrtB123));
    });

    test('ordre inverse exact Petersen -> Guédiawaye (§7, Test BRT 4)', () {
      expect(
          officialRouteStops(kBrtB1Id, reverse: true)!
              .map((BusStop s) => s.id)
              .toList(),
          orderedEquals(kBrtB123.reversed.toList()));
    });

    test('le sens inverse est une INVERSION, pas une seconde liste (§7)', () {
      final List<String> aller =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toList();
      final List<String> retour = officialRouteStops(kBrtB1Id, reverse: true)!
          .map((BusStop s) => s.id)
          .toList();
      expect(retour, orderedEquals(aller.reversed.toList()));
      expect(retour.toSet(), aller.toSet());
      expect(retour.length, 23);
    });

    test('les 23 stations sont des entités DISTINCTES — identifiants', () {
      final List<String> ids =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toList();
      expect(ids.toSet().length, 23,
          reason: 'une station ne doit pas apparaître deux fois');
    });

    test('les 23 stations sont des entités DISTINCTES — noms officiels', () {
      final List<String> noms =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.name).toList();
      expect(noms.toSet().length, 23,
          reason: 'deux stations officielles ne partagent pas un nom');
    });

    test('les 23 stations sont des entités DISTINCTES — coordonnées', () {
      final Set<String> coords = officialRouteStops(kBrtB1Id)!
          .map((BusStop s) => coordKey(s.latitude, s.longitude))
          .toSet();
      expect(coords.length, 23,
          reason: 'deux stations officielles ne partagent pas une position');
    });

    test('B1 n\'est PAS les 11 regroupements historiques (§7, Test BRT 2)', () {
      final List<String> noms =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.name).toList();
      expect(noms.length, isNot(11),
          reason: 'le modèle à 11 stations est interdit par le §7');
      for (final String legacy in kLegacyBrt11) {
        expect(noms.contains(legacy), false,
            reason: '« $legacy » est un regroupement historique de plusieurs '
                'stations ou zones ; ce n\'est pas une station officielle '
                'distincte de B1');
      }
    });

    test('les stations officiellement distinctes ne sont pas fusionnées (§7)',
        () {
      // Cas précis du regroupement historique « Liberté 6 » : le corridor
      // officiel distingue Liberté 6, Liberté 5 et Liberté 1.
      final List<String> noms =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.name).toList();
      expect(noms.where((String n) => n.startsWith('Liberté')).length, 3,
          reason: 'Liberté 6, Liberté 5 et Liberté 1 sont trois stations');
      // Cas du regroupement historique « Guédiawaye » : le corridor distingue
      // Préfecture Guédiawaye, Gadaye - Cambérène, Golf Nord, Fith Mith.
      expect(
          noms
              .where((String n) =>
                  n.contains('Guédiawaye') ||
                  n.contains('Gadaye') ||
                  n.contains('Golf Nord') ||
                  n.contains('Fith Mith'))
              .length,
          4);
    });

    test('terminus : Préfecture Guédiawaye en tête, Petersen en queue', () {
      final List<BusStop> st = officialRouteStops(kBrtB1Id)!;
      expect(st.first.name, 'Préfecture Guédiawaye - PEM BRT');
      expect(st.last.name, 'Papa Gueye Fall - PEM Petersen BRT');
    });

    test('réseau de l\'itinéraire B1 = brt', () {
      expect(networkOfRoute(kBrtB1Id), 'brt');
    });

    test('chaque station a des coordonnées valides, aucune n\'est à (0,0)', () {
      for (final BusStop s in officialRouteStops(kBrtB1Id)!) {
        expect(DakarBounds.isValid(LatLng(s.latitude, s.longitude)), true,
            reason: '${s.id} hors du garde-fou Dakar');
        expect(s.latitude == 0.0 && s.longitude == 0.0, false);
      }
    });

    test('B2 Express compte 7 stations, toutes incluses dans B1', () {
      final List<BusStop> b2 = officialRouteStops(kBrtB2Id)!;
      expect(b2.length, 7);
      expect(b2.map((BusStop s) => s.id).toList(), orderedEquals(kBrtB27));
      final Set<String> b1 =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toSet();
      for (final BusStop s in b2) {
        expect(b1.contains(s.id), true,
            reason: '${s.id} dessert B2 mais pas B1');
      }
    });

    test('la fiche de ligne BRT expose les 23 stations dans l\'ordre', () {
      final DetailedRoute? fiche = DetailedRoute.fromOperator('brt');
      expect(fiche, isNotNull);
      expect(fiche!.stops.length, 23);
      expect(fiche.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kBrtB123));
      expect(fiche.origin, 'Préfecture Guédiawaye - PEM BRT');
      expect(fiche.destination, 'Papa Gueye Fall - PEM Petersen BRT');
    });

    test('la fiche de ligne BRT en sens inverse expose l\'ordre retourné', () {
      final DetailedRoute? fiche =
          DetailedRoute.fromOperator('brt', reverse: true);
      expect(fiche, isNotNull);
      expect(fiche!.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kBrtB123.reversed.toList()));
      expect(fiche.origin, 'Papa Gueye Fall - PEM Petersen BRT');
      expect(fiche.destination, 'Préfecture Guédiawaye - PEM BRT');
    });
  });

  // ==================================================================
  group('§9 — aucune station inventée, aucune donnée fabriquée', () {
    test('chaque station officielle provient des stopIds du JSON (§9, Test BRT 5)',
        () {
      final TransportRoute route = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == kBrtB1Id);
      final List<String> ids =
          officialRouteStops(kBrtB1Id)!.map((BusStop s) => s.id).toList();
      // Aucune station n'est issue d'une résolution par approximation
      // géographique ou d'une recherche : toutes viennent de la liste de la
      // ligne dans la source unique.
      expect(ids.toSet().difference(route.stopIds.toSet()), isEmpty);
      expect(ids.length, route.stopIds.length);
    });

    test('même garantie pour le TER', () {
      final TransportRoute route = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == kTerRouteId);
      final List<String> ids =
          officialRouteStops(kTerRouteId)!.map((BusStop s) => s.id).toList();
      expect(ids.toSet().difference(route.stopIds.toSet()), isEmpty);
      expect(ids.length, route.stopIds.length);
    });

    test('aucun arrêt fabriqué « Station Intermédiaire » (branche production)',
        () {
      // La branche générique de `a3j` en production fabriquait un arrêt
      // « Station Intermédiaire » posé à `location + 0.01`. Données inventées,
      // interdites (§9).
      expect(
          allStops.any((Stop s) => s.name == 'Station Intermédiaire'), false);
      expect(
          appDataService.stops
              .any((BusStop s) => s.name == 'Station Intermédiaire'),
          false);
    });

    test('totalDistance est CALCULÉ, jamais les littéraux historiques', () {
      final DetailedRoute brt = DetailedRoute.fromOperator('brt')!;
      final DetailedRoute ter = DetailedRoute.fromOperator('ter')!;
      expect(brt.totalDistance, isNot('14.0 km'),
          reason: '« 14.0 km » est le littéral de la branche BRT codée en dur');
      expect(ter.totalDistance, isNot('35.0 km'),
          reason: '« 35.0 km » est le littéral de la branche TER codée en dur');
      expect(RegExp(r'^\d+\.\d km$').hasMatch(brt.totalDistance), true);
      expect(RegExp(r'^\d+\.\d km$').hasMatch(ter.totalDistance), true);
    });

    test('un point du réseau non résoluble ne fabrique AUCUNE fiche (§9)', () {
      // « Gare TER Keur Mbaye Fall » (14.7750, -17.3100) est le point
      // historique de l'ancienne liste de démonstration `terStations`,
      // supprimée par PR #20 : il n'existe plus dans Explorer et n'y est PAS
      // restauré (c'était le défaut combattu). La fixture reproduit ce même
      // point — mêmes nom et coordonnées — pour garder la garantie §9 : il est
      // à 3,46 km de la gare officielle `stop_keur_mbaye_fall`, au-delà du
      // seuil de résolution de 250 m, et sans homonyme TER. Aucune
      // correspondance fiable : la fiche est `null`, jamais inventée.
      expect(
          networkPoints(AppColors.ter)
              .any((Stop s) => s.name == 'Gare TER Keur Mbaye Fall'),
          false,
          reason: 'la liste de démonstration TER ne doit pas être restaurée');
      const Stop legacy = Stop(
        name: 'Gare TER Keur Mbaye Fall',
        direction: 'Dir. Dakar / Diamniadio',
        distanceMeters: 14200,
        departureMinutesFromMidnight: <int>[],
        icon: Icons.train_rounded,
        color: AppColors.ter,
        location: LatLng(14.7750, -17.3100),
        modeLabel: 'TER',
        source: DataSourceInfo.seter,
        stopType: StopType.correspondence,
      );
      final Iterable<BusStop> garesTer = officialRouteStops(kTerRouteId)!;
      final double plusProche = garesTer
          .map((BusStop s) => DistanceHelper.haversineMeters(
              legacy.location, LatLng(s.latitude, s.longitude)))
          .reduce((double a, double b) => a < b ? a : b);
      expect(plusProche, greaterThan(250),
          reason: 'fixture hors du seuil de résolution de 250 m');
      expect(garesTer.any((BusStop s) => s.name == legacy.name), false,
          reason: 'aucun homonyme parmi les gares officielles');
      expect(DetailedRoute.fromStop(legacy), isNull,
          reason: 'aucune donnée inventée : un inconnu reste un inconnu');
    });

    test('un point BRT non résoluble ne fabrique AUCUNE fiche (§9)', () {
      // Même principe : « PEM Guediawaye » (14.7735, -17.3977), point
      // historique de `brtStations` (supprimée par PR #20), à 322 m de la
      // station B1 la plus proche (`stop_brt_21_golf_nord`) et sans homonyme
      // parmi les stations BRT.
      expect(
          networkPoints(AppColors.brt).any((Stop s) => s.name == 'PEM Guediawaye'),
          false,
          reason: 'la liste de démonstration BRT ne doit pas être restaurée');
      const Stop legacy = Stop(
        name: 'PEM Guediawaye',
        direction: 'Terminus nord BRT',
        distanceMeters: 10500,
        departureMinutesFromMidnight: <int>[],
        icon: Icons.directions_bus_rounded,
        color: AppColors.brt,
        location: LatLng(14.7735, -17.3977),
        modeLabel: 'BRT',
        source: DataSourceInfo.sunubrt,
        stopType: StopType.terminus,
      );
      final Iterable<BusStop> stationsB1 = officialRouteStops(kBrtB1Id)!;
      final double plusProche = stationsB1
          .map((BusStop s) => DistanceHelper.haversineMeters(
              legacy.location, LatLng(s.latitude, s.longitude)))
          .reduce((double a, double b) => a < b ? a : b);
      expect(plusProche, greaterThan(250));
      expect(stationsB1.any((BusStop s) => s.name == legacy.name), false);
      expect(DetailedRoute.fromStop(legacy), isNull);
    });

    test('une gare officielle résout bien vers sa ligne TER', () {
      final List<Stop> candidats = networkPoints(AppColors.ter)
          .where((Stop s) => s.stopId == 'stop_thiaroye')
          .toList();
      expect(candidats.length, 1);
      final DetailedRoute? fiche = DetailedRoute.fromStop(candidats.first);
      expect(fiche, isNotNull);
      expect(fiche!.routeId, kTerRouteId);
      expect(fiche.stops.length, 13);
    });

    test('une station officielle résout bien vers B1 et ses 23 stations', () {
      final List<Stop> candidates = networkPoints(AppColors.brt)
          .where((Stop s) => s.stopId == 'stop_brt_11_scat_urbam')
          .toList();
      expect(candidates.length, 1);
      final DetailedRoute? fiche = DetailedRoute.fromStop(candidates.first);
      expect(fiche, isNotNull);
      expect(fiche!.routeId, kBrtB1Id);
      expect(fiche.stops.length, 23);
    });
  });

  // ==================================================================
  group('§8 — la polyligne reste cohérente avec les stations officielles', () {
    test('un seul tracé TER sur la carte, de 13 points', () {
      final List<TransitRoute> ter =
          demoRoutes.where((TransitRoute r) => r.code == 'TER').toList();
      expect(ter.length, 1, reason: 'le TER ne doit plus être dessiné en double');
      expect(ter.first.points.length, 13,
          reason: 'la polyligne TER doit passer par les 13 gares officielles');
    });

    test('les 13 points du tracé TER SONT les 13 gares officielles, dans l\'ordre',
        () {
      final TransitRoute ter =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'TER');
      final List<BusStop> gares = officialRouteStops(kTerRouteId)!;
      expect(ter.points.length, gares.length);
      for (int i = 0; i < gares.length; i++) {
        expect(ter.points[i].latitude, closeTo(gares[i].latitude, 1e-9),
            reason: 'gare ${i + 1} (${gares[i].name}) : latitude divergente');
        expect(ter.points[i].longitude, closeTo(gares[i].longitude, 1e-9),
            reason: 'gare ${i + 1} (${gares[i].name}) : longitude divergente');
      }
    });

    test('un seul tracé BRT B1 sur la carte, de 23 points', () {
      final List<TransitRoute> b1 =
          demoRoutes.where((TransitRoute r) => r.code == 'BRT B1').toList();
      expect(b1.length, 1,
          reason: 'B1 était dessiné deux fois (démo 10 points + JSON 23 points)');
      expect(b1.first.points.length, 23);
    });

    test('les 23 points du tracé B1 SONT les 23 stations officielles, dans l\'ordre',
        () {
      final TransitRoute b1 =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'BRT B1');
      final List<BusStop> stations = officialRouteStops(kBrtB1Id)!;
      expect(b1.points.length, stations.length);
      for (int i = 0; i < stations.length; i++) {
        expect(b1.points[i].latitude, closeTo(stations[i].latitude, 1e-9),
            reason: 'station ${i + 1} (${stations[i].name})');
        expect(b1.points[i].longitude, closeTo(stations[i].longitude, 1e-9),
            reason: 'station ${i + 1} (${stations[i].name})');
      }
    });

    test('aucun doublon de tracé pour le TER et le BRT (défaut corrigé)', () {
      // Le défaut corrigé : la démo TER (6 points) et la ligne officielle TER
      // (13 gares) coexistaient, de même que la démo B1 (10 points) et
      // `BRT B1` (23 stations). Chaque ligne dédiée n'a plus qu'un tracé.
      final Set<String> geometries = <String>{};
      for (final TransitRoute r
          in demoRoutes.where((TransitRoute r) => r.isDedicated)) {
        final String cle = r.points
            .map((LatLng p) => coordKey(p.latitude, p.longitude))
            .join(';');
        expect(geometries.add(cle), true,
            reason: 'le tracé de « ${r.code} » est dessiné en double');
      }
      expect(geometries.length, 3, reason: 'TER + BRT B1 + BRT B2');
    });

    test('les seules géométries partagées sont deux couloirs AFTU/Tata distincts',
        () {
      // CONSTAT DE DONNÉE, pas un défaut. Sur les 105 lignes du JSON, 103
      // géométries sont distinctes ; les deux paires qui partagent un tracé
      // sont des lignes **distinctes** exploitant le même couloir :
      //   `aftu_2`  (AFTU 2)  / `tata_50`  (Tata 50)  — Guédiawaye ↔ Sandaga
      //   `aftu_38` (AFTU 38) / `tata_218` (Tata 218) — Mermoz ↔ Keur Massar
      // Elles diffèrent par `id`, `short_name`, `long_name` et `operator_id`.
      // Le JSON est la source unique (§4-§5) : rien n'est fusionné, rien n'est
      // supprimé, aucune donnée n'est inventée. Ce test fige ce fait afin
      // qu'un doublon NOUVEAU — lui, réel — soit immédiatement détecté.
      final Map<String, List<String>> parGeometrie = <String, List<String>>{};
      for (final TransitRoute r in demoRoutes) {
        final String cle = r.points
            .map((LatLng p) => coordKey(p.latitude, p.longitude))
            .join(';');
        parGeometrie.putIfAbsent(cle, () => <String>[]).add(r.code);
      }
      final List<List<String>> partagees = parGeometrie.values
          .where((List<String> v) => v.length > 1)
          .toList();
      expect(partagees.length, 2,
          reason: 'toute géométrie partagée supplémentaire est un doublon réel');
      expect(parGeometrie.length, 103,
          reason: '105 lignes officielles, 103 géométries distinctes');
      expect(partagees.expand((List<String> v) => v).toSet(),
          <String>{'AFTU 2', 'Tata 50', 'AFTU 38', 'Tata 218'});
    });

    test('AUCUNE coordonnée de tracé ne subsiste hors de la source unique (§4)',
        () {
      final Set<String> coordsJson = appDataService.stops
          .map((BusStop s) => coordKey(s.latitude, s.longitude))
          .toSet();
      for (final TransitRoute r in demoRoutes) {
        for (final LatLng p in r.points) {
          expect(coordsJson.contains(coordKey(p.latitude, p.longitude)), true,
              reason: 'le tracé « ${r.code} » contient un point qui n\'est '
                  'aucun arrêt du JSON : coordonnée inventée ou héritée d\'un '
                  'JSON historique ($p)');
        }
      }
    });

    test('tous les points de tous les tracés valident le garde-fou Dakar', () {
      for (final TransitRoute r in demoRoutes) {
        expect(r.points.length, greaterThanOrEqualTo(2));
        for (final LatLng p in r.points) {
          expect(DakarBounds.isValid(p), true,
              reason: 'tracé « ${r.code} » : point $p hors bornes');
        }
      }
    });

    test('toutes les lignes du JSON ont un tracé, aucune démo résiduelle', () {
      expect(demoRoutes.length, appDataService.routes.length,
          reason: 'chaque ligne officielle a exactement un tracé, et il n\'en '
              'existe aucun hors JSON');
    });

    test('couleurs et types dérivés : le rendu TER/BRT est conservé (§10)', () {
      final TransitRoute ter =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'TER');
      final TransitRoute brt =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'BRT B1');
      expect(ter.color, AppColors.ter, reason: 'la couleur TER ne change pas');
      expect(brt.color, AppColors.brt, reason: 'la couleur BRT ne change pas');
      expect(ter.type, 'TER');
      expect(brt.type, 'BRT');
    });

    test('isDedicated conservé : TER et BRT restent chargés au démarrage', () {
      final TransitRoute ter =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'TER');
      final TransitRoute brt =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'BRT B1');
      expect(ter.isDedicated, true);
      expect(brt.isDedicated, true);
      // Le périmètre du chargement initial n'est pas élargi : aucune requête
      // OSRM supplémentaire n'est provoquée par cette correction.
      expect(demoRoutes.where((TransitRoute r) => r.isDedicated).length, 3,
          reason: 'TER + BRT B1 + BRT B2, comme avant la correction');
    });

    test('l\'intégration est idempotente : rien ne se duplique au rechargement',
        () {
      final int tracesAvant = demoRoutes.length;
      final int arretsAvant = allStops.length;
      integrateNetworkDataForTest();
      expect(demoRoutes.length, tracesAvant);
      expect(allStops.length, arretsAvant);
    });
  });

  // ==================================================================
  group('§5 — structure : réseau, ligne, station, itinéraire', () {
    test('une ligne officielle porte identifiant, réseau, nom et stopIds', () {
      final TransportRoute b1 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == kBrtB1Id);
      expect(b1.id, kBrtB1Id);
      expect(b1.operatorId, 'brt');
      expect(b1.shortName, 'BRT B1');
      expect(b1.stopIds.length, 23);
      expect(b1.stopIds, orderedEquals(kBrtB123));
    });

    test('une station officielle porte identifiant, nom, coordonnées et statut',
        () {
      final BusStop s = appDataService.stops
          .firstWhere((BusStop x) => x.id == 'stop_brt_09_liberte_6');
      expect(s.name, 'Liberté 6 - BRT Correspondance');
      expect(s.latitude, closeTo(14.72631, 1e-9));
      expect(s.longitude, closeTo(-17.45919, 1e-9));
      expect(s.dataTrust, DataTrust.official);
    });

    test('l\'ordre dans l\'itinéraire est la position dans stopIds, sans champ dupliqué',
        () {
      final List<BusStop> stations = officialRouteStops(kBrtB1Id)!;
      for (int i = 0; i < stations.length; i++) {
        expect(stations[i].id, kBrtB123[i],
            reason: 'l\'ordre de l\'itinéraire est porté par la liste elle-même');
      }
    });

    test('une ligne inconnue renvoie null, jamais une liste fabriquée (§9)', () {
      expect(officialRouteStops('ligne_inexistante'), isNull);
      expect(networkOfRoute('ligne_inexistante'), isNull);
    });
  });

  // ==================================================================
  // CORRECTIF AFFICHAGE CARTOGRAPHIQUE DES ARRÊTS TER/BRT.
  //
  // Cause verrouillée ici : la couche marqueurs d'Explorer était alimentée
  // par le seul flux « à proximité » (`_filteredStops` : 30 arrêts max,
  // rayon 4 km si GPS). En vue « Tous », ce plafond ne laissait visibles
  // qu'1 gare TER et 8 stations BRT pendant que les tracés complets
  // (13 + 23) étaient dessinés. `explorerMapMarkerStops` garantit
  // désormais les arrêts officiels des réseaux affichés, sans donnée
  // nouvelle (mêmes objets `Stop` intégrés du JSON, `stopId` non nul).
  // ==================================================================
  group('§10 — marqueurs de la carte : gares/stations officielles garanties',
      () {
    /// Réplique du comportement réel d'Explorer : `proximityStops` =
    /// `_filteredStops` (arrêts de la couleur du filtre, plafonnés à 30 par
    /// la proximité — les réseaux ci-dessous comptent moins de 30 arrêts) et
    /// `terDisplayed`/`brtDisplayed` = prédicat des `activePolylines`
    /// (« Tous » → TER + BRT, sinon la couleur sélectionnée).
    List<Stop> markersFor(String filtre) {
      final List<Stop> prox;
      switch (filtre) {
        case 'TER':
          prox = networkPoints(AppColors.ter);
          break;
        case 'BRT':
          prox = networkPoints(AppColors.brt);
          break;
        case 'DDD':
          prox = networkPoints(AppColors.ddd);
          break;
        default: // « Tous »
          prox = [
            ...networkPoints(AppColors.ter),
            ...networkPoints(AppColors.brt),
          ];
          break;
      }
      return explorerMapMarkerStops(
        proximityStops: prox,
        terDisplayed: filtre == 'Tous' || filtre == 'TER',
        brtDisplayed: filtre == 'Tous' || filtre == 'BRT',
      );
    }

    test('« Tous » : chaque gare TER officielle (13) a son marqueur', () {
      final List<Stop> tous = markersFor('Tous');
      final Set<String> ids =
          tous.map((Stop s) => s.stopId).whereType<String>().toSet();
      for (final String id in kTer13) {
        expect(ids.contains(id), true, reason: 'gare $id absente de la carte');
      }
      expect(
          tous.where((Stop s) =>
                  s.stopId != null && s.color == AppColors.ter).length,
          13,
          reason: '13 marqueurs TER, un par gare officielle, sans doublon');
    });

    test('« Tous » : chaque station BRT officielle (23) a son marqueur', () {
      final List<Stop> tous = markersFor('Tous');
      final Set<String> ids =
          tous.map((Stop s) => s.stopId).whereType<String>().toSet();
      for (final String id in kBrtB123) {
        expect(ids.contains(id), true,
            reason: 'station $id absente de la carte');
      }
      expect(
          tous.where((Stop s) =>
                  s.stopId != null && s.color == AppColors.brt).length,
          23,
          reason: '23 marqueurs BRT, un par station officielle, sans doublon');
    });

    test('« Tous » : plus aucun doublon démo héritée / officielle sur la carte',
        () {
      // Depuis PR #20, Explorer ne contient plus que les 13 + 23 officiels ;
      // la couche marqueurs, elle, garantit de surcroît qu'aucun arrêt de
      // démonstration hérité (sans `stopId`, coordonnées hors tracé) ne
      // serait redessiné même s'il réapparaissait dans `proximityStops`.
      final List<Stop> tous = markersFor('Tous');
      expect(
          tous.where((Stop s) =>
              s.color == AppColors.ter && s.stopId == null).length,
          0,
          reason: 'aucun arrêt TER de démonstration redessiné sur la carte');
      expect(
          tous.where((Stop s) =>
              s.color == AppColors.brt && s.stopId == null).length,
          0,
          reason: 'aucune station BRT de démonstration redessinée sur la carte');
      expect(tous.length, 36,
          reason: '13 gares TER + 23 stations BRT, rien d\'autre');
    });

    test('filtre TER : exactement les 13 gares officielles, aucune station BRT',
        () {
      final List<Stop> ter = markersFor('TER');
      expect(ter.length, 13, reason: 'un marqueur par gare officielle');
      expect(
          ter.where((Stop s) =>
                  s.stopId != null && s.color == AppColors.ter).length,
          13);
      expect(ter.where((Stop s) => s.color == AppColors.brt).length, 0);
    });

    test('filtre BRT : exactement les 23 stations officielles, aucune gare TER',
        () {
      final List<Stop> brt = markersFor('BRT');
      expect(brt.length, 23, reason: 'un marqueur par station officielle');
      expect(
          brt.where((Stop s) =>
                  s.stopId != null && s.color == AppColors.brt).length,
          23);
      expect(brt.where((Stop s) => s.color == AppColors.ter).length, 0);
    });

    test('chaque marqueur TER officiel est posé sur un sommet du tracé TER',
        () {
      final TransitRoute ter =
          demoRoutes.firstWhere((TransitRoute r) => r.code == 'TER');
      final Set<String> sommets = ter.points
          .map((LatLng p) => coordKey(p.latitude, p.longitude))
          .toSet();
      for (final Stop s in markersFor('TER')
          .where((Stop s) => s.stopId != null && s.color == AppColors.ter)) {
        expect(
            sommets.contains(
                coordKey(s.location.latitude, s.location.longitude)),
            true,
            reason: '${s.name} (${s.stopId}) n\'est pas sur le tracé TER');
      }
    });

    test('chaque marqueur BRT officiel est posé sur un sommet du tracé B1',
        () {
      final TransitRoute b1 = demoRoutes
          .firstWhere((TransitRoute r) => r.code == 'BRT B1');
      final Set<String> sommets = b1.points
          .map((LatLng p) => coordKey(p.latitude, p.longitude))
          .toSet();
      for (final Stop s in markersFor('BRT')
          .where((Stop s) => s.stopId != null && s.color == AppColors.brt)) {
        expect(
            sommets.contains(
                coordKey(s.location.latitude, s.location.longitude)),
            true,
            reason: '${s.name} (${s.stopId}) n\'est pas sur le tracé B1');
      }
    });

    test('hors TER/BRT (DDD, TATA, AFTU, Favoris) : comportement inchangé', () {
      final List<Stop> prox = networkPoints(AppColors.ddd);
      final List<Stop> out = explorerMapMarkerStops(
          proximityStops: prox, terDisplayed: false, brtDisplayed: false);
      expect(out.length, prox.length,
          reason: 'sans réseau dédié affiché, la couche est inchangée');
    });

    test('tous les marqueurs produits restent dans les bornes Dakar', () {
      for (final String f in const <String>['Tous', 'TER', 'BRT']) {
        for (final Stop s in markersFor(f)) {
          expect(DakarBounds.isValid(s.location), true,
              reason: '${s.name} ($f) hors bornes');
        }
      }
    });
  });
}
