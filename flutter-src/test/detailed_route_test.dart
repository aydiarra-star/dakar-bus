import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';

/// GROUPE 2 (Step 4B) — fiche détaillée d'une ligne dérivée de la SOURCE UNIQUE.
///
/// Ces tests figent le §8, le §9, le §6, le §7 et le §12 :
///
///  * §8  les arrêts d'une fiche ligne proviennent de `dakar_network.json`,
///        jamais d'une liste parallèle codée en dur dans `main.dart` ;
///  * §9  `totalDistance` est CALCULÉE par une formule prouvée, jamais un
///        littéral. Formule : somme des haversine entre arrêts consécutifs,
///        R = 6371008.8 m. Valeurs de référence relevées sur la donnée ACTIVE
///        et confirmées par simulation du binaire de production (rapport 4A §9) :
///        TER = 34.6 km, BRT B1 = 17.5 km, BRT B2 = 16.0 km ;
///  * §6  TER = 13 gares, ordre Dakar -> Diamniadio, sens inverse = inversion ;
///  * §7  BRT = 23 stations, sens inverse = inversion de l'ordre courant ;
///  * §12 aucune donnée inventée : ce qui n'est pas dérivable vaut `null`.
///
/// Rappel sur les distances : 17.5 km est une somme de CORDES GÉOGRAPHIQUES
/// entre stations, ce n'est pas la longueur de voirie du corridor. La distance
/// officielle annoncée par le CETUD pour le corridor SunuBRT est de 18.3 km.
/// Les deux grandeurs sont légitimes mais distinctes ; l'application affiche la
/// grandeur calculée à partir de la source unique, et rien d'autre.

/// Les 13 gares TER dans l'ordre Dakar -> Diamniadio imposé par le §6.
/// (Même liste de référence que `network_data_test.dart` ; elle est répétée ici
/// pour que ce fichier reste autonome et lisible indépendamment.)
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

/// Les 23 stations SunuBRT de B1 dans l'ordre Guédiawaye -> Petersen (§7).
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

// ---------------------------------------------------------------------------
// Haversine INDÉPENDANT : réécrit ici avec `dart:math` pour ne pas réutiliser
// `DistanceHelper`. Si l'implémentation dérivait autre chose que la somme des
// haversine consécutifs, la comparaison du test 21 échouerait.
// ---------------------------------------------------------------------------
const double kRayonTerre = 6371008.8;

double _rad(double degres) => degres * math.pi / 180.0;

double haversineIndependante(LatLng a, LatLng b) {
  final double dLat = _rad(b.latitude - a.latitude);
  final double dLon = _rad(b.longitude - a.longitude);
  final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * kRayonTerre * math.asin(math.sqrt(h));
}

/// Somme des haversine entre arrêts consécutifs d'une liste d'identifiants.
double cumulDepuisIds(List<String> ids) {
  double total = 0.0;
  LatLng? precedent;
  for (final String id in ids) {
    final BusStop s = appDataService.stops.firstWhere((BusStop x) => x.id == id);
    final LatLng p = LatLng(s.latitude, s.longitude);
    if (precedent != null) total += haversineIndependante(precedent, p);
    precedent = p;
  }
  return total;
}

String km(double metres) => '${(metres / 1000).toStringAsFixed(1)} km';

/// Construit un `Stop` minimal pour exercer `DetailedRoute.fromStop`.
Stop arret({
  required String name,
  required LatLng location,
  String modeLabel = 'TER',
  String? stopId,
  String direction = '',
}) =>
    Stop(
      name: name,
      direction: direction,
      distanceMeters: 0,
      departureMinutesFromMidnight: const <int>[],
      icon: Icons.circle,
      color: const Color(0xFF000000),
      location: location,
      modeLabel: modeLabel,
      stopId: stopId,
    );

DetailedRoute attendre(DetailedRoute? r, String quoi) {
  expect(r, isNotNull, reason: 'dérivation attendue pour $quoi');
  return r!;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await appDataService.loadNetworkData();
    expect(appDataService.isLoaded, true);
    // Garde : si l'asset n'était pas lu, le repli codé en dur donnerait 6/5.
    expect(appDataService.stops.length, 117,
        reason: 'la DONNÉE ACTIVE doit être chargée');
    expect(appDataService.routes.length, 105,
        reason: 'la DONNÉE ACTIVE doit être chargée');
  });

  group('§8 — arrêts dérivés de la source unique, aucune liste parallèle', () {
    test('TER : la fiche dérivée compte exactement 13 gares', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.stops.length, 13);
    });

    test('TER : les 13 gares dérivées sont dans l\'ordre canonique du JSON', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kTer13));
    });

    test('BRT : la fiche dérivée compte exactement 23 stations (jamais 11)', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('brt'), 'BRT');
      expect(r.stops.length, 23);
      // §7 : le modèle historique à 11 stations est interdit.
      expect(r.stops.length, isNot(11));
      expect(r.stops.length, isNot(12));
    });

    test('BRT : les 23 stations dérivées sont dans l\'ordre canonique du JSON',
        () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('brt'), 'BRT');
      expect(r.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kBrtB123));
    });

    test('§6 — sens inverse TER = inversion exacte de l\'ordre courant', () {
      final DetailedRoute avant =
          attendre(DetailedRoute.fromOperator('ter'), 'TER aller');
      final DetailedRoute arriere = attendre(
          DetailedRoute.fromOperator('ter', reverse: true), 'TER retour');
      expect(arriere.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kTer13.reversed.toList()));
      expect(arriere.origin, avant.destination);
      expect(arriere.destination, avant.origin);
      // L'inversion est une bijection : mêmes gares, aucun ajout ni perte.
      expect(arriere.stops.length, avant.stops.length);
      expect(arriere.stops.map((DetailedStop s) => s.stopId).toSet(),
          avant.stops.map((DetailedStop s) => s.stopId).toSet());
    });

    test('§7 — sens inverse BRT = inversion exacte de l\'ordre courant', () {
      final DetailedRoute avant =
          attendre(DetailedRoute.fromOperator('brt'), 'BRT aller');
      final DetailedRoute arriere = attendre(
          DetailedRoute.fromOperator('brt', reverse: true), 'BRT retour');
      expect(arriere.stops.map((DetailedStop s) => s.stopId).toList(),
          orderedEquals(kBrtB123.reversed.toList()));
      expect(arriere.origin, avant.destination);
      expect(arriere.destination, avant.origin);
      expect(arriere.stops.length, 23);
    });

    test('aucun arrêt fabriqué : chaque stopId dérivé existe dans le JSON', () {
      for (final String op in <String>['ter', 'brt', 'ddd', 'aftu', 'tata']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        if (r == null) continue;
        for (final DetailedStop s in r.stops) {
          expect(appDataService.stops.any((BusStop x) => x.id == s.stopId), true,
              reason: 'arrêt inventé dans la fiche $op : ${s.stopId}');
          // L'ancien code fabriquait « Station Intermédiaire » à
          // `stop.location + 0.01` et l'identifiait `gen_1` / `gen_2` (§30).
          expect(s.stopId.startsWith('gen_'), false,
              reason: 'identifiant fabriqué interdit : ${s.stopId}');
          expect(s.name, isNot('Station Intermédiaire'));
        }
      }
    });

    test('aucun arrêt perdu : la fiche couvre tous les arrêts de la ligne JSON',
        () {
      final TransportRoute ter = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'ter_dakar_diamniadio');
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.stops.map((DetailedStop s) => s.stopId).toSet(),
          ter.stopIds.toSet());
    });

    test('origin et destination viennent du JSON, pas d\'un littéral', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.origin, 'Gare TER Dakar');
      expect(r.destination, 'Diamniadio - Gare TER Terminus');
      expect(r.origin, r.stops.first.name);
      expect(r.destination, r.stops.last.name);
    });

    test('§6 — Keur Massar est absent de la fiche TER dérivée', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.stops.any((DetailedStop s) => s.stopId == 'stop_keur_massar'),
          false);
      for (final DetailedStop s in r.stops) {
        expect(s.name.toLowerCase().contains('keur massar'), false,
            reason: 'gare TER interdite par le §6 : ${s.name}');
      }
    });

    test('operator vient du JSON (nom d\'exploitant), jamais d\'un littéral', () {
      expect(attendre(DetailedRoute.fromOperator('ter'), 'TER').operator,
          'TER Dakar - SETER');
      expect(attendre(DetailedRoute.fromOperator('brt'), 'BRT').operator,
          'SunuBRT');
      expect(attendre(DetailedRoute.fromOperator('ddd'), 'DDD').operator,
          'Dakar Dem Dikk');
    });

    test('routeId vient du JSON', () {
      expect(attendre(DetailedRoute.fromOperator('ter'), 'TER').routeId,
          'ter_dakar_diamniadio');
      expect(attendre(DetailedRoute.fromOperator('brt'), 'BRT').routeId,
          'brt_b1_guediawaye_petersen');
    });

    test('§12 — lineNumber : aucun numéro inventé quand le code n\'en a pas',
        () {
      // « TER » ne contient aucun chiffre : le numéro doit être `null`, pas 1.
      expect(attendre(DetailedRoute.fromOperator('ter'), 'TER').lineNumber,
          isNull);
      // « BRT B1 » contient 1.
      expect(attendre(DetailedRoute.fromOperator('brt'), 'BRT').lineNumber, 1);
    });

    test('les couleurs de l\'interface sont inchangées (§21)', () {
      expect(attendre(DetailedRoute.fromOperator('ter'), 'TER').color,
          AppColors.ter);
      expect(attendre(DetailedRoute.fromOperator('brt'), 'BRT').color,
          AppColors.brt);
      // Les constantes de l'interface coïncident avec les colorHex du JSON.
      expect(AppColors.ter, const Color(0xFF8B4513));
      expect(AppColors.brt, const Color(0xFF22C55E));
    });
  });

  group('§9 — distance CALCULÉE par la formule prouvée, jamais codée en dur', () {
    test('TER : totalDistance = 34.6 km (valeur prouvée)', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      expect(r.totalDistance, '34.6 km');
    });

    test('BRT B1 : totalDistance = 17.5 km (valeur prouvée)', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('brt'), 'BRT');
      expect(r.totalDistance, '17.5 km');
    });

    test('BRT B2 Express : la formule donne 16.0 km (3e point de preuve)', () {
      final TransportRoute b2 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'brt_b2_express');
      expect(b2.stopIds.length, 7);
      // B2 est un sous-ensemble de B1 dans le même ordre relatif (§7).
      final List<String> b1 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'brt_b1_guediawaye_petersen')
          .stopIds;
      final List<int> positions =
          b2.stopIds.map((String id) => b1.indexOf(id)).toList();
      expect(positions.every((int p) => p >= 0), true);
      expect(positions, orderedEquals(positions.toList()..sort()));
      expect(km(cumulDepuisIds(b2.stopIds)), '16.0 km');
    });

    test('totalDistance == distanceFromStart du DERNIER arrêt (cumul cohérent)',
        () {
      for (final String op in <String>['ter', 'brt', 'ddd']) {
        final DetailedRoute r = attendre(DetailedRoute.fromOperator(op), op);
        expect(r.totalDistance, r.stops.last.distanceFromStart,
            reason: 'cumul incohérent pour $op');
      }
    });

    test('le premier arrêt est à 0.0 km de lui-même', () {
      for (final String op in <String>['ter', 'brt', 'ddd']) {
        final DetailedRoute r = attendre(DetailedRoute.fromOperator(op), op);
        expect(r.stops.first.distanceFromStart, '0.0 km');
      }
    });

    test('les distances cumulées sont strictement croissantes', () {
      // Vérifié sur la donnée ACTIVE : aucun segment n'est de longueur nulle
      // (segment le plus court : 311.9 m sur BRT B1, 1575.3 m sur le TER,
      // 396.9 m sur DDD 1). La croissance est donc STRICTE, et non seulement
      // monotone — ce qui exclut tout arrêt dupliqué ou toute coordonnée
      // répétée dans la séquence dérivée.
      for (final String op in <String>['ter', 'brt', 'ddd']) {
        final DetailedRoute r = attendre(DetailedRoute.fromOperator(op), op);
        for (int i = 1; i < r.stops.length; i++) {
          final double avant =
              double.parse(r.stops[i - 1].distanceFromStart.split(' ').first);
          final double apres =
              double.parse(r.stops[i].distanceFromStart.split(' ').first);
          expect(apres, greaterThan(avant),
              reason: 'segment nul ou recul au rang $i de $op : '
                  '${r.stops[i].name}');
        }
        expect(double.parse(r.stops.last.distanceFromStart.split(' ').first),
            greaterThan(0.0));
      }
    });

    test('totalDistance == somme haversine INDÉPENDANTE des arrêts consécutifs',
        () {
      // C'est le test discriminant : il prouve que la valeur affichée est
      // CALCULÉE depuis les coordonnées du JSON, et non un littéral recopié.
      for (final String op in <String>['ter', 'brt', 'ddd', 'aftu', 'tata']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        if (r == null) continue;
        final double attendu = cumulDepuisIds(
            r.stops.map((DetailedStop s) => s.stopId).toList());
        expect(r.totalDistance, km(attendu), reason: 'formule ≠ preuve pour $op');
      }
    });

    test('chaque distanceFromStart == cumul haversine indépendant jusqu\'à elle',
        () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      for (int i = 0; i < r.stops.length; i++) {
        final double attendu = cumulDepuisIds(
            r.stops.take(i + 1).map((DetailedStop s) => s.stopId).toList());
        expect(r.stops[i].distanceFromStart, km(attendu),
            reason: 'cumul faux au rang $i (${r.stops[i].name})');
      }
    });

    test('les anciens littéraux codés en dur ne sont plus produits', () {
      const List<String> interdits = <String>['35.0 km', '14.0 km', '3.5 km'];
      for (final String op in <String>['ter', 'brt', 'ddd', 'aftu', 'tata']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        if (r == null) continue;
        expect(interdits.contains(r.totalDistance), false,
            reason: 'littéral historique réapparu pour $op : ${r.totalDistance}');
      }
    });

    test('format « N.N km » : une seule décimale, jamais davantage', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('ter'), 'TER');
      final RegExp format = RegExp(r'^\d+\.\d km$');
      expect(format.hasMatch(r.totalDistance), true,
          reason: 'format inattendu : ${r.totalDistance}');
      for (final DetailedStop s in r.stops) {
        expect(format.hasMatch(s.distanceFromStart), true,
            reason: 'format inattendu pour ${s.name} : ${s.distanceFromStart}');
      }
    });
  });

  group('§12 — temps estimé marqué approximatif, inconnu honnête', () {
    test('le premier arrêt affiche ~0 min (correction 4A du faisceau aOu)', () {
      // La production affichait « ~3 min » au départ, ce qui est incohérent :
      // le premier arrêt est à 0 minute de lui-même.
      for (final String op in <String>['ter', 'brt', 'ddd']) {
        final DetailedRoute r = attendre(DetailedRoute.fromOperator(op), op);
        expect(r.stops.first.estimatedTime, '~0 min');
      }
    });

    test('estimatedTime suit la règle prouvée ~(index * 3) min', () {
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('brt'), 'BRT');
      for (int i = 0; i < r.stops.length; i++) {
        expect(r.stops[i].estimatedTime, '~${i * 3} min',
            reason: 'temps estimé inattendu au rang $i (${r.stops[i].name})');
      }
    });

    test('aucune pseudo-heure « HH:00 » n\'est fabriquée', () {
      // L'ancien code produisait '${i * 4}:00' / '${i * 6}:00', soit jusqu'à
      // « 88:00 » pour 23 stations : des heures invalides présentées comme
      // réelles. Le format actuel est une durée explicitement approximative.
      final RegExp pseudoHeure = RegExp(r'^\d{1,2}:\d{2}$');
      for (final String op in <String>['ter', 'brt', 'ddd', 'aftu', 'tata']) {
        final DetailedRoute? r = DetailedRoute.fromOperator(op);
        if (r == null) continue;
        for (final DetailedStop s in r.stops) {
          expect(pseudoHeure.hasMatch(s.estimatedTime), false,
              reason: 'pseudo-heure fabriquée : ${s.estimatedTime}');
          expect(s.estimatedTime.startsWith('~'), true,
              reason: 'estimation non marquée comme approximation');
          expect(s.estimatedTime.endsWith(' min'), true);
        }
      }
    });

    test('exploitant inexistant : null, aucune fiche fabriquée', () {
      expect(DetailedRoute.fromOperator('inexistant'), isNull);
      expect(DetailedRoute.fromOperator(''), isNull);
    });

    test('arrêt non résoluble : null, aucune fiche fabriquée', () {
      final Stop inconnu = arret(
        name: 'Arrêt qui n\'existe pas',
        location: const LatLng(0.0, 0.0),
        modeLabel: 'TER',
      );
      expect(DetailedRoute.fromStop(inconnu), isNull);
    });

    test('arrêt hors du seuil de 250 m : null (seuil aS1 non élargi)', () {
      // « PEM Guediawaye » de la démonstration historique est à 322 m du plus
      // proche arrêt BRT ACTUEL. Le seuil éprouvé de production est 250 m : il
      // n'est pas élargi pour faire aboutir la résolution. Résultat = inconnu.
      final Stop demo = arret(
        name: 'PEM Guediawaye',
        location: const LatLng(14.7735, -17.3977),
        modeLabel: 'BRT',
      );
      expect(DetailedRoute.fromStop(demo), isNull);
    });
  });

  group('résolution de l\'arrêt vers la source unique', () {
    test('par stopId : résolution exacte, même ligne que fromOperator', () {
      final Stop s = arret(
        name: 'n\'importe quel libellé',
        location: const LatLng(0.0, 0.0),
        modeLabel: 'TER',
        stopId: 'stop_dakar_ter',
      );
      final DetailedRoute r = attendre(DetailedRoute.fromStop(s), 'par stopId');
      expect(r.routeId, 'ter_dakar_diamniadio');
      expect(r.stops.length, 13);
    });

    test('par nom exact : « Gare TER Dakar » résout stop_dakar_ter', () {
      // Les coordonnées du Stop de démonstration (14.6792, -17.4407) sont à
      // plus de 250 m de l'arrêt ACTUEL (14.67599, -17.43352) : c'est la
      // correspondance de nom, et non la proximité, qui résout cet arrêt.
      final Stop s = arret(
        name: 'Gare TER Dakar',
        location: const LatLng(14.6792, -17.4407),
        modeLabel: 'TER',
      );
      final DetailedRoute r = attendre(DetailedRoute.fromStop(s), 'par nom');
      expect(r.routeId, 'ter_dakar_diamniadio');
      expect(r.stops.first.stopId, 'stop_dakar_ter');
    });

    test('préférence d\'exploitant : un arrêt DDD à Colobane ouvre DDD 1, PAS le TER',
        () {
      // Preuve du besoin : `stop_colobane` est desservi par 28 lignes réparties
      // sur 4 exploitants (TER position 2/13, DDD 1 position 1/4, plus AFTU et
      // Tata). Sans préférence d'exploitant, `aOu` ouvrirait la PREMIÈRE ligne
      // trouvée — le TER — pour un arrêt consulté en tant qu'arrêt DDD.
      final Stop s = arret(
        name: 'Colobane',
        location: const LatLng(14.70035, -17.44165),
        modeLabel: 'DDD',
      );
      final DetailedRoute r =
          attendre(DetailedRoute.fromStop(s), 'arrêt DDD à Colobane');
      expect(r.routeId, 'ddd_1');
      expect(r.operator, 'Dakar Dem Dikk');
      expect(r.stops.first.stopId, 'stop_colobane');
      expect(r.origin, 'Colobane - Marché & Gare TER');
      expect(r.destination, 'Yoff - Aéroport & Plage');
      expect(r.stops.length, 4);
    });

    test('un arrêt TER à Colobane ouvre bien le TER (même position, autre mode)',
        () {
      final Stop s = arret(
        name: 'Colobane',
        location: const LatLng(14.70035, -17.44165),
        modeLabel: 'TER',
      );
      final DetailedRoute r =
          attendre(DetailedRoute.fromStop(s), 'arrêt TER à Colobane');
      expect(r.routeId, 'ter_dakar_diamniadio');
      expect(r.stops.length, 13);
    });

    test('périmètre de résolution restreint au mode consulté', () {
      // À (14.7735, -17.3977) se trouve l'arrêt « PEM Guédiawaye - Terminus BRT
      // Nord » (`stop_guediawaye`), desservi uniquement par AFTU, DDD et Tata.
      // Consulté en tant qu'arrêt AFTU, il doit résoudre cet homonyme ; consulté
      // en tant qu'arrêt BRT, il ne doit PAS tomber dessus.
      const LatLng ici = LatLng(14.7735, -17.3977);
      final DetailedRoute? enAftu =
          DetailedRoute.fromStop(arret(name: 'x', location: ici, modeLabel: 'AFTU'));
      expect(enAftu, isNotNull);
      expect(enAftu!.operator,
          'AFTU - Association de Financement des Transports Urbains');
      expect(
          DetailedRoute.fromStop(
              arret(name: 'x', location: ici, modeLabel: 'BRT')),
          isNull);
    });
  });

  group('§8 — modèle DetailedStop aligné sur la production', () {
    test('DetailedStop expose exactement les 5 champs du binaire de production',
        () {
      // Les champs morts `sequence`, `isTerminal` et `type` ont été supprimés :
      // ils n'étaient lus par aucune vue. Ce test compile uniquement si le
      // constructeur nommé expose bien les 5 champs attendus, et il échoue si
      // un champ supprimé est réintroduit comme obligatoire.
      const DetailedStop s = DetailedStop(
        stopId: 'stop_dakar_ter',
        name: 'Gare TER Dakar',
        location: LatLng(14.67599, -17.43352),
        distanceFromStart: '0.0 km',
        estimatedTime: '~0 min',
      );
      expect(s.stopId, 'stop_dakar_ter');
      expect(s.name, 'Gare TER Dakar');
      expect(s.location.latitude, 14.67599);
      expect(s.distanceFromStart, '0.0 km');
      expect(s.estimatedTime, '~0 min');
    });

    test('le numéro d\'ordre affiché vient de l\'index, pas d\'un champ dédié',
        () {
      // `DetailedRoutePage` numérote via `route.stops.asMap()` puis `idx + 1`.
      // La séquence dérivable est donc continue et sans trou.
      final DetailedRoute r = attendre(DetailedRoute.fromOperator('brt'), 'BRT');
      final List<int> numeros =
          r.stops.asMap().keys.map((int idx) => idx + 1).toList();
      expect(numeros, orderedEquals(List<int>.generate(23, (int i) => i + 1)));
      expect(r.stops.length, numeros.length);
    });
  });
}
