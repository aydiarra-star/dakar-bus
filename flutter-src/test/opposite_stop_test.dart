import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';

/// GROUPE 3 (Step 4B) — détection de l'arrêt situé en face (§10).
///
/// Algorithme PROUVÉ du binaire de production `A.adD(a, b)`, réintégré à
/// l'identique (rapport 4A, Carte 03) :
///   passe 1 — inclusion de nom dans les DEUX sens, à 120 m ou moins ;
///   passe 2 — même mode, direction différente, à 500 m ou moins ;
///   haversine, R = 6 371 008,8 m.
/// La Carte 03 interdit de réduire l'algorithme à une seule passe, de
/// remplacer l'inclusion de nom par une égalité stricte, et de changer R.
///
/// ---------------------------------------------------------------------------
/// ÉCART N°1 PORTÉ AU RAPPORT — les « noms croisés » de la Carte 03
/// ---------------------------------------------------------------------------
/// La Carte 03 décrit la passe 1 comme une « inclusion de nom dans les deux
/// sens », mais son jeu de fixtures (b) et la ligne 1457
/// (`opposite_pass1_within_120m`) prescrivent : « jumeau à 40 m / 90 m, noms
/// croisés (« X - BRT » / « BRT X ») => trouvé en passe 1 ».
/// Ces deux énoncés sont INCOMPATIBLES. Vérification :
///   'x - brt'  ne contient pas 'brt x', et réciproquement  -> REFUSÉ
///   'sacré-cœur - brt' / 'brt sacré-cœur'                  -> REFUSÉ
///   'obélisque' / 'place de l'obélisque - brt'             -> APPARIÉ
/// L'inclusion réciproque de sous-chaînes — celle de la source existante comme
/// celle que décrit la Carte 03 — n'apparie donc PAS des noms croisés.
/// Apparier de tels noms exigerait un découpage en mots, c'est-à-dire un
/// algorithme qui n'est prouvé ni dans la source historique ni dans le binaire
/// de production. Il n'a PAS été inventé (interdiction de tout repli inventé).
/// Deux tests ci-dessous figent le comportement RÉEL et montrent que la paire
/// reste appariée, mais par la passe 2.
///
/// ---------------------------------------------------------------------------
/// ÉCART N°2 PORTÉ AU RAPPORT — le seuil de 120 m est inopérant sur la donnée
/// ---------------------------------------------------------------------------
/// Sur les 117 arrêts de la donnée ACTIVE
/// (md5 81c778f4644dcf5e1cf4ae25879218f0), il n'existe AUCUNE paire d'arrêts
/// distincts dont les noms s'incluent et qui soient à 120 m ou moins. Le
/// passage du seuil de 50 m à 120 m est donc conforme à la production mais ne
/// change aucun appariement observable sur la donnée courante. Il n'est pas
/// présenté comme une amélioration.
///
/// ---------------------------------------------------------------------------
/// ÉCART N°3 PORTÉ AU RAPPORT — le risque de la Carte 03 est avéré
/// ---------------------------------------------------------------------------
/// La Carte 03 écartait le faux positif de la passe 2 en ces termes : « sur le
/// corridor BRT, deux stations consécutives réelles sont à ~700 m, donc pas de
/// faux positif ». Mesure sur la donnée ACTIVE : l'écart minimal entre deux
/// stations consécutives de B1 est de 311,9 m et 2 segments sur 22 sont à
/// 500 m ou moins. Le risque est donc RÉEL, et un test le met en évidence.
///
/// ---------------------------------------------------------------------------
/// MÉTHODE DE FIXATION DES DISTANCES — et pourquoi le seuil EXACT est évité
/// ---------------------------------------------------------------------------
/// Les fixtures sont placées sur un même méridien : la distance haversine d'un
/// arc méridien vaut R * deltaPhi, donc une cible en mètres se traduit en un
/// deltaPhi exact et la distance obtenue est reproductible.
///
/// En revanche, `DistanceHelper.haversineMeters` calcule `(1 - cos(dLat)) / 2`
/// et non `sin(dLat / 2)^2`. Les deux écritures sont mathématiquement égales
/// mais pas numériquement : pour de petits angles, `1 - cos` subit une
/// annulation catastrophique. Mesures relevées avec la formule du code :
///   cible 120,0 m -> mesuré 119,99999717 m (marge +2,8e-6 m sous le seuil)
///   cible 500,0 m -> mesuré 500,00000361 m (marge -3,6e-6 m sous le seuil)
/// Or une divergence d'un seul ULP sur `cos` entre bibliothèques mathématiques
/// se propage ici jusqu'à environ 7,5e-5 m, soit PLUS que ces marges de
/// quelques micromètres. Un test placé exactement sur le seuil serait donc
/// fragile d'une plateforme à l'autre.
///
/// Décision : les tests de limite utilisent 119,9 / 120,1 et 499,9 / 500,1
/// (marges de 0,1 m, sans ambiguïté), et un test dédié vérifie l'INCLUSIVITÉ de
/// la comparaison `<=` en liant l'attente à la distance réellement mesurée
/// plutôt qu'à la cible nominale.

const double kRayonTerre = 6371008.8;

/// Point de référence des fixtures : coordonnées réelles de la gare TER de
/// Dakar dans `dakar_network.json` (`stop_dakar_ter`).
const LatLng kBase = LatLng(14.67599, -17.43352);

/// Paire de noms à inclusion réciproque RÉELLE, relevée dans la donnée ACTIVE
/// (`stop_obelisque` et la station BRT homonyme). Sert de fixture nominale de
/// la passe 1 : l'inclusion y est vérifiée, contrairement aux noms croisés.
const String kNomCourt = 'Obélisque';
const String kNomLong = 'Place de l\'Obélisque - BRT';

/// Place un point à [metres] au nord de [base], sur le même méridien.
LatLng nord(LatLng base, double metres) {
  final double delta = (metres / kRayonTerre) * (180.0 / math.pi);
  return LatLng(base.latitude + delta, base.longitude);
}

/// Construit un `Stop` de fixture. `direction` distingue les sens : la passe 2
/// exige deux libellés différents, l'exclusion de la passe 1 exige au contraire
/// même nom ET même direction.
Stop arret({
  required String name,
  required LatLng location,
  String direction = 'Dir. A',
  String modeLabel = 'BRT',
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
    );

/// Charge la donnée ACTIVE dans le service global partagé par l'application.
Future<void> chargerSourceUnique() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await appDataService.loadNetworkData();
  expect(appDataService.isLoaded, true);
  // Garde : le repli codé en dur donnerait 6 arrêts et 5 lignes.
  expect(appDataService.stops.length, 117,
      reason: 'la DONNÉE ACTIVE doit être chargée');
  expect(appDataService.routes.length, 105);
}

void main() {
  group('Passe 1 — inclusion de nom à 120 m ou moins', () {
    test('jumeau exact à 40 m, même nom, sens différent : trouvé', () {
      // 4A Carte 03, jeu de fixtures (a).
      final Stop courant =
          arret(name: 'Gare TER Dakar', location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: 'Gare TER Dakar',
          location: nord(kBase, 40.0),
          direction: 'Dir. B');
      final Stop? trouve = OppositeStopService.findOppositeStop(
          currentStop: courant, allStops: <Stop>[courant, jumeau]);
      expect(identical(trouve, jumeau), true);
    });

    test('noms à inclusion réciproque à 40 m : trouvé', () {
      final Stop courant = arret(name: kNomCourt, location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: kNomLong, location: nord(kBase, 40.0), direction: 'Dir. B');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('noms à inclusion réciproque à 90 m : trouvé', () {
      // 4A Carte 03, jeu de fixtures (b) — à ceci près que la fixture prescrite
      // (« X - BRT » / « BRT X ») n'est pas appariable par inclusion ; voir
      // l'ÉCART N°1 en tête de fichier. La distance de 90 m est conservée.
      final Stop courant = arret(name: kNomCourt, location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: kNomLong, location: nord(kBase, 90.0), direction: 'Dir. B');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('inclusion court contenu dans long : trouvé', () {
      final Stop courant =
          arret(name: 'Colobane', location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: 'Colobane - Marché & Gare TER',
          location: nord(kBase, 100.0),
          direction: 'Dir. B');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('inclusion long contenant court : trouvé (réciprocité exigée)', () {
      // La Carte 03 impose l'inclusion « dans les deux sens ». Ce test échoue
      // si la comparaison est réduite à un seul sens.
      final Stop courant = arret(
          name: 'Colobane - Marché & Gare TER', location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: 'Colobane', location: nord(kBase, 100.0), direction: 'Dir. B');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('l\'inclusion n\'est PAS une égalité stricte', () {
      // Carte 03, « 12. Ne pas modifier » : ne pas remplacer l'inclusion de nom
      // par une égalité stricte. Deux noms différents mais inclus doivent être
      // appariés.
      final Stop courant = arret(name: 'Petersen', location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: 'Papa Gueye Fall - PEM Petersen BRT',
          location: nord(kBase, 50.0),
          direction: 'Dir. B');
      expect(courant.name, isNot(jumeau.name));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('ÉCART N°1 — noms croisés « X - BRT » / « BRT X » : la passe 1 ne les apparie pas',
        () {
      // Voir l'ÉCART N°1 en tête de fichier. Ni « x - brt » ne contient
      // « brt x », ni l'inverse : l'inclusion réciproque de sous-chaînes
      // refuse cette paire, contrairement à ce qu'annoncent la fixture (b) de
      // la Carte 03 et la ligne 1457 du rapport 4A.
      // Pour isoler la passe 1, les deux arrêts portent le MÊME libellé de
      // sens : la passe 2, qui exige deux sens différents, est alors inerte.
      // Aucun découpage en mots n'a été ajouté pour forcer cet appariement.
      final Stop courant = arret(
          name: 'Sacré-Cœur - BRT', location: kBase, direction: 'Dir. A');
      final Stop croise = arret(
          name: 'BRT Sacré-Cœur', location: nord(kBase, 40.0), direction: 'Dir. A');
      expect('sacré-cœur - brt'.contains('brt sacré-cœur'), false);
      expect('brt sacré-cœur'.contains('sacré-cœur - brt'), false);
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, croise]),
          isNull,
          reason: 'la passe 1 ne doit pas apparier des noms croisés');
    });

    test('ÉCART N°1 — ces mêmes noms croisés sont appariés par la PASSE 2', () {
      // Complément du test précédent : la paire n'est pas perdue pour
      // l'application, mais elle est appariée par la passe 2 (même mode, sens
      // différents, 40 m <= 500 m), et non par la passe 1. C'est précisément
      // pourquoi la Carte 03 interdit de fusionner les deux passes.
      final Stop courant = arret(
          name: 'Sacré-Cœur - BRT', location: kBase, direction: 'Dir. Nord');
      final Stop croise = arret(
          name: 'BRT Sacré-Cœur', location: nord(kBase, 40.0), direction: 'Dir. Sud');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, croise]),
          isNotNull,
          reason: 'la passe 2 doit prendre le relais à 40 m, même mode, sens opposés');
    });

    test('119,9 m : trouvé (limite intérieure du seuil)', () {
      final Stop courant = arret(name: kNomCourt, location: kBase, direction: 'Dir. A');
      final Stop jumeau = arret(
          name: kNomLong, location: nord(kBase, 119.9), direction: 'Dir. B');
      final double mesure =
          DistanceHelper.haversineMeters(courant.location, jumeau.location);
      expect(mesure, closeTo(119.9, 1e-3));
      expect(mesure, lessThanOrEqualTo(120.0));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('120,1 m : refusé (limite extérieure du seuil)', () {
      // Mode différent afin que la passe 2 ne puisse pas rattraper le refus :
      // le `null` provient bien du seuil de 120 m.
      final Stop courant = arret(
          name: kNomCourt, location: kBase, direction: 'Dir. A', modeLabel: 'TER');
      final Stop jumeau = arret(
          name: kNomLong, location: nord(kBase, 120.1), direction: 'Dir. B', modeLabel: 'BRT');
      final double mesure =
          DistanceHelper.haversineMeters(courant.location, jumeau.location);
      expect(mesure, greaterThan(120.0));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNull);
    });

    test('homonyme à 130 m : la passe 1 échoue (opposite_pass1_rejects_beyond_120m)',
        () {
      // 4A ligne 1458 : « 130 m => passe 1 échoue ».
      // Isolation rigoureuse du seuil : les deux AUTRES voies de rejet sont
      // neutralisées pour que le `null` provienne bien des 120 m.
      //   - sens DIFFÉRENTS, sinon l'exclusion « même nom et même direction »
      //     écarterait le candidat avant toute mesure de distance ;
      //   - modes DIFFÉRENTS, sinon la passe 2 (500 m) rattraperait le candidat
      //     et le test ne mesurerait plus la passe 1.
      final Stop courant = arret(
          name: kNomCourt, location: kBase, direction: 'Dir. A', modeLabel: 'TER');
      final Stop jumeau = arret(
          name: kNomLong, location: nord(kBase, 130.0), direction: 'Dir. B', modeLabel: 'BRT');
      expect(
          DistanceHelper.haversineMeters(courant.location, jumeau.location),
          greaterThan(120.0),
          reason: 'la fixture doit bien dépasser le seuil de la passe 1');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNull);
    });

    test('noms sans inclusion à 40 m : refusé malgré la proximité', () {
      // Cas RÉEL de la donnée ACTIVE : « Dalifort - Foirail » et
      // « Khar Yalla - Grand Yoff » sont à 77,34 m l'un de l'autre, mais leurs
      // noms n'ont aucun lien d'inclusion. La proximité seule ne suffit pas.
      final Stop courant =
          arret(name: 'Dalifort - Foirail', location: kBase, direction: 'Dir. A');
      final Stop voisin = arret(
          name: 'Khar Yalla - Grand Yoff',
          location: nord(kBase, 77.34),
          direction: 'Dir. A');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('l\'arrêt lui-même n\'est jamais retenu comme vis-à-vis', () {
      final Stop courant =
          arret(name: 'Gare TER Dakar', location: kBase, direction: 'Dir. A');
      final Stop clone =
          arret(name: 'Gare TER Dakar', location: kBase, direction: 'Dir. A');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, clone]),
          isNull);
    });

    test('parmi plusieurs candidats de passe 1, le plus proche est retenu', () {
      final Stop courant =
          arret(name: kNomCourt, location: kBase, direction: 'Dir. A');
      final Stop loin = arret(
          name: kNomCourt, location: nord(kBase, 110.0), direction: 'Dir. B');
      final Stop pres = arret(
          name: kNomCourt, location: nord(kBase, 20.0), direction: 'Dir. C');
      // Ordre de la liste inversé : le résultat ne doit pas en dépendre.
      final Stop? trouve = OppositeStopService.findOppositeStop(
          currentStop: courant, allStops: <Stop>[courant, loin, pres]);
      expect(identical(trouve, pres), true);
    });
  });

  group('Passe 2 — même mode, sens opposé, 500 m ou moins', () {
    test('300 m, même mode, sens opposé : trouvé (opposite_pass2_500m_same_mode_opposite)',
        () {
      // 4A ligne 1459. Noms sans inclusion, pour que la passe 1 ne puisse pas
      // aboutir et que la passe 2 soit réellement exercée.
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop jumeau = arret(
          name: 'Bêta', location: nord(kBase, 300.0), direction: 'Dir. Sud');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('300 m, même sens : null (opposite_rejects_same_direction)', () {
      // 4A ligne 1460.
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop voisin = arret(
          name: 'Bêta', location: nord(kBase, 300.0), direction: 'Dir. Nord');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('300 m, mode différent, sens opposé : null (opposite_rejects_other_mode)',
        () {
      // 4A ligne 1461 et fixture (f).
      final Stop courant = arret(
          name: 'Alpha', location: kBase, direction: 'Dir. Nord', modeLabel: 'BRT');
      final Stop voisin = arret(
          name: 'Bêta',
          location: nord(kBase, 300.0),
          direction: 'Dir. Sud',
          modeLabel: 'TER');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('800 m : null (opposite_rejects_beyond_500m)', () {
      // 4A ligne 1462 et fixture (d).
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop voisin = arret(
          name: 'Bêta', location: nord(kBase, 800.0), direction: 'Dir. Sud');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('499,9 m : trouvé (limite intérieure du seuil)', () {
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop jumeau = arret(
          name: 'Bêta', location: nord(kBase, 499.9), direction: 'Dir. Sud');
      final double mesure =
          DistanceHelper.haversineMeters(courant.location, jumeau.location);
      expect(mesure, closeTo(499.9, 1e-3));
      expect(mesure, lessThanOrEqualTo(500.0));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, jumeau]),
          isNotNull);
    });

    test('500,1 m : refusé (limite extérieure du seuil)', () {
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop voisin = arret(
          name: 'Bêta', location: nord(kBase, 500.1), direction: 'Dir. Sud');
      final double mesure =
          DistanceHelper.haversineMeters(courant.location, voisin.location);
      expect(mesure, greaterThan(500.0));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('parmi plusieurs candidats de passe 2, le plus proche est retenu', () {
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop loin = arret(
          name: 'Gamma', location: nord(kBase, 480.0), direction: 'Dir. Sud');
      final Stop pres = arret(
          name: 'Bêta', location: nord(kBase, 150.0), direction: 'Dir. Ouest');
      final Stop? trouve = OppositeStopService.findOppositeStop(
          currentStop: courant, allStops: <Stop>[courant, loin, pres]);
      expect(identical(trouve, pres), true);
    });

    test('la passe 1 a priorité sur la passe 2', () {
      // Un candidat de passe 1 à 40 m doit l'emporter sur un candidat de passe 2
      // à 300 m, même si ce dernier est du même mode et de sens opposé. Les
      // deux passes ne sont pas fusionnées (Carte 03).
      // Le candidat de passe 1 porte un sens DIFFÉRENT et un mode DIFFÉRENT :
      // sans cela l'exclusion « même nom et même direction » l'écarterait, ou la
      // passe 2 le rattraperait, et le test ne prouverait plus la priorité.
      final Stop courant = arret(
          name: kNomCourt, location: kBase, direction: 'Dir. Nord', modeLabel: 'TER');
      final Stop passe1 = arret(
          name: kNomCourt,
          location: nord(kBase, 40.0),
          direction: 'Dir. Est',
          modeLabel: 'BRT');
      final Stop passe2 = arret(
          name: 'Bêta', location: nord(kBase, 300.0), direction: 'Dir. Sud', modeLabel: 'TER');
      final Stop? trouve = OppositeStopService.findOppositeStop(
          currentStop: courant, allStops: <Stop>[courant, passe2, passe1]);
      expect(identical(trouve, passe1), true,
          reason: 'la passe 1 (40 m, nom inclus) doit primer sur la passe 2 (300 m)');
    });
  });

  group('Seuils — aucune augmentation, comparaison inclusive', () {
    test('inclusivité de <= vérifiée sur la distance MESURÉE, pas sur la cible',
        () {
      // À 120,0 m nominal, la formule du code ((1 - cos(dLat)) / 2) mesure
      // 119,99999717 m : le seuil est atteint par défaut et la comparaison
      // inclusive l'accepte. À 500,0 m nominal elle mesure 500,00000361 m et le
      // refuse. L'attente est donc liée à la distance RÉELLEMENT mesurée : à
      // l'échelle du micromètre c'est l'arrondi de la formule qui décide, et un
      // test qui prétendrait trancher le seuil exact serait fragile.
      final Stop courant1 =
          arret(name: kNomCourt, location: kBase, direction: 'Dir. A', modeLabel: 'TER');
      final Stop jumeau1 = arret(
          name: kNomLong, location: nord(kBase, 120.0), direction: 'Dir. B', modeLabel: 'BRT');
      final double d1 =
          DistanceHelper.haversineMeters(courant1.location, jumeau1.location);
      expect(d1, closeTo(120.0, 1e-3), reason: 'la fixture vise le seuil');
      final Stop? r1 = OppositeStopService.findOppositeStop(
          currentStop: courant1, allStops: <Stop>[courant1, jumeau1]);
      expect(r1 != null, d1 <= 120.0,
          reason: 'la passe 1 doit appliquer <= à la distance mesurée ($d1 m)');

      final Stop courant2 =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop jumeau2 = arret(
          name: 'Bêta', location: nord(kBase, 500.0), direction: 'Dir. Sud');
      final double d2 =
          DistanceHelper.haversineMeters(courant2.location, jumeau2.location);
      expect(d2, closeTo(500.0, 1e-3), reason: 'la fixture vise le seuil');
      final Stop? r2 = OppositeStopService.findOppositeStop(
          currentStop: courant2, allStops: <Stop>[courant2, jumeau2]);
      expect(r2 != null, d2 <= 500.0,
          reason: 'la passe 2 doit appliquer <= à la distance mesurée ($d2 m)');
    });

    test('aucun seuil n\'est élargi : 600 m est refusé par les deux passes', () {
      // Un candidat qui satisfait TOUTES les conditions de fond (nom inclus,
      // même mode, sens opposé) mais dépasse les deux seuils doit rester sans
      // correspondance. Ce test échoue si un repli est ajouté.
      final Stop courant =
          arret(name: kNomCourt, location: kBase, direction: 'Dir. Nord');
      final Stop voisin = arret(
          name: kNomLong, location: nord(kBase, 600.0), direction: 'Dir. Sud');
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, voisin]),
          isNull);
    });

    test('les fixtures méridiennes sont mesurées par haversine à 1e-3 m près', () {
      // Ce test valide la MÉTHODE de fixation des distances employée par tout le
      // fichier : sans elle, aucun test de seuil ne serait probant.
      // Le rayon R = 6 371 008,8 m est figé par `dakar_bounds_test.dart`
      // (Groupe 1), qui dispose d'un test discriminant entre 6371008.8 et
      // l'ancienne valeur 6371000.0. Il n'est pas doublé ici, où un arc de
      // 300 m ne sépare les deux rayons que de 4e-4 m.
      for (final double cible in <double>[40.0, 90.0, 120.0, 300.0, 500.0, 800.0]) {
        final double mesure =
            DistanceHelper.haversineMeters(kBase, nord(kBase, cible));
        expect(mesure, closeTo(cible, 1e-3),
            reason: 'fixture faussée pour la cible $cible m (mesuré $mesure)');
      }
    });
  });

  group('Contrat — aucune correspondance forcée (§12)', () {
    test('arrêt seul : null (fixture 4A (c))', () {
      final Stop seul = arret(name: 'Alpha', location: kBase);
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: seul, allStops: <Stop>[seul]),
          isNull);
    });

    test('liste vide : null', () {
      final Stop seul = arret(name: 'Alpha', location: kBase);
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: seul, allStops: <Stop>[]),
          isNull);
    });

    test('aucun candidat admissible : null, jamais un arrêt de substitution', () {
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final List<Stop> bruit = <Stop>[
        // Trop loin pour les deux passes.
        arret(name: 'Bêta', location: nord(kBase, 900.0), direction: 'Dir. Sud'),
        // Proche mais même sens : la passe 2 l'écarte, et les noms ne s'incluent
        // pas : la passe 1 aussi.
        arret(name: 'Gamma', location: nord(kBase, 50.0), direction: 'Dir. Nord'),
        // Proche et sens opposé, mais mode différent.
        arret(
            name: 'Delta',
            location: nord(kBase, 60.0),
            direction: 'Dir. Sud',
            modeLabel: 'TER'),
      ];
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: courant, allStops: <Stop>[courant, ...bruit]),
          isNull);
    });

    test('le service retourne l\'objet reçu, il n\'en crée jamais', () {
      final Stop courant =
          arret(name: 'Alpha', location: kBase, direction: 'Dir. Nord');
      final Stop jumeau = arret(
          name: 'Bêta', location: nord(kBase, 300.0), direction: 'Dir. Sud');
      final Stop? trouve = OppositeStopService.findOppositeStop(
          currentStop: courant, allStops: <Stop>[courant, jumeau]);
      expect(identical(trouve, jumeau), true,
          reason: 'le service ne doit ni copier ni fabriquer un arrêt');
      expect(trouve!.location.latitude, jumeau.location.latitude);
      expect(trouve.location.longitude, jumeau.location.longitude);
      expect(trouve.name, jumeau.name);
    });
  });

  group('Donnée ACTIVE — caractérisation (§10 appliqué aux données réelles)', () {
    setUpAll(chargerSourceUnique);

    test('ÉCART N°2 — aucune paire de la donnée ACTIVE ne satisfait la passe 1', () {
      // Sur les 117 arrêts ACTIVE, il n'existe AUCUNE paire d'arrêts distincts
      // dont les noms s'incluent et qui soient à 120 m ou moins. Les deux
      // seules paires à 120 m ou moins sont « Dalifort - Foirail » /
      // « Khar Yalla - Grand Yoff » (77,34 m) et « Fass - Colobane » /
      // « Marché Sandaga - Centre Dakar » (77,35 m) : aucune des deux n'a de
      // lien d'inclusion de nom.
      // Conséquence honnête : le passage du seuil de 50 m à 120 m, bien que
      // conforme à la production, ne change AUCUN appariement sur la donnée
      // courante.
      final List<BusStop> arrets = appDataService.stops;
      final List<String> paires = <String>[];
      for (int i = 0; i < arrets.length; i++) {
        for (int j = i + 1; j < arrets.length; j++) {
          final BusStop a = arrets[i];
          final BusStop b = arrets[j];
          final String na = a.name.toLowerCase();
          final String nb = b.name.toLowerCase();
          final bool inclusion = na == nb || na.contains(nb) || nb.contains(na);
          if (!inclusion) continue;
          final double d = DistanceHelper.haversineMeters(
              LatLng(a.latitude, a.longitude), LatLng(b.latitude, b.longitude));
          if (d <= 120.0) {
            paires.add('${a.name} <-> ${b.name} (${d.toStringAsFixed(2)} m)');
          }
        }
      }
      expect(paires, isEmpty, reason: 'paires de passe 1 inattendues : $paires');
    });

    test('les paires à 120 m ou moins de la donnée ACTIVE sont correctement refusées',
        () {
      // Complément du test précédent : ces paires existent, et la passe 1 les
      // refuse à bon droit faute d'inclusion de nom.
      final List<BusStop> arrets = appDataService.stops;
      final List<List<BusStop>> proches = <List<BusStop>>[];
      for (int i = 0; i < arrets.length; i++) {
        for (int j = i + 1; j < arrets.length; j++) {
          final double d = DistanceHelper.haversineMeters(
              LatLng(arrets[i].latitude, arrets[i].longitude),
              LatLng(arrets[j].latitude, arrets[j].longitude));
          if (d <= 120.0) proches.add(<BusStop>[arrets[i], arrets[j]]);
        }
      }
      expect(proches.length, 2, reason: 'paires à <=120 m attendues : 2');
      for (final List<BusStop> paire in proches) {
        // Même sens : la passe 2 est inerte, on observe donc la passe 1 seule.
        final Stop a = arret(
            name: paire[0].name,
            location: LatLng(paire[0].latitude, paire[0].longitude),
            direction: 'Dir. A');
        final Stop b = arret(
            name: paire[1].name,
            location: LatLng(paire[1].latitude, paire[1].longitude),
            direction: 'Dir. A');
        expect(
            OppositeStopService.findOppositeStop(
                currentStop: a, allStops: <Stop>[a, b]),
            isNull,
            reason: 'appariement indu : ${paire[0].name} / ${paire[1].name}');
      }
    });

    test('ÉCART N°3 — l\'hypothèse de la Carte 03 (~700 m entre stations BRT) est réfutée',
        () {
      // La Carte 03 écartait le risque de faux positif de la passe 2 en ces
      // termes : « sur le corridor BRT, deux stations consécutives réelles sont
      // à ~700 m, donc pas de faux positif ». Mesure sur la donnée ACTIVE :
      // l'écart minimal entre deux stations consécutives de B1 est de 311,9 m
      // et 2 segments sur 22 sont à 500 m ou moins. Le risque signalé est donc
      // RÉEL sur la donnée courante.
      // L'algorithme est néanmoins réintégré à l'identique, car la Carte 03
      // interdit de le simplifier ; l'écart est documenté, pas corrigé.
      final TransportRoute b1 = appDataService.routes
          .firstWhere((TransportRoute r) => r.id == 'brt_b1_guediawaye_petersen');
      final List<double> segments = <double>[];
      for (int i = 1; i < b1.stopIds.length; i++) {
        final BusStop p = appDataService.stops
            .firstWhere((BusStop s) => s.id == b1.stopIds[i - 1]);
        final BusStop q =
            appDataService.stops.firstWhere((BusStop s) => s.id == b1.stopIds[i]);
        segments.add(DistanceHelper.haversineMeters(
            LatLng(p.latitude, p.longitude), LatLng(q.latitude, q.longitude)));
      }
      expect(segments.length, 22);
      segments.sort();
      expect(segments.first, closeTo(311.9, 0.5));
      expect(segments.where((double s) => s <= 500.0).length, 2);
      expect(segments.first, lessThan(700.0),
          reason: 'la Carte 03 supposait ~700 m minimum entre stations');
    });

    test('ÉCART N°3 — la passe 2 apparie deux stations BRT consécutives réelles',
        () {
      // Mise en évidence concrète du constat précédent, sur des arrêts et des
      // coordonnées réels : « Papa Gueye Fall - PEM Petersen BRT » et
      // « Grande Mosquée - BRT » sont deux stations CONSÉCUTIVES de B1, à
      // 311,9 m, toutes deux SunuBRT. Dès que leurs libellés de sens diffèrent,
      // la passe 2 les apparie comme « arrêt en face ».
      // Ce comportement est celui de la production ; il est figé ici pour que
      // toute évolution ultérieure de la donnée ou de l'algorithme soit
      // consciente de cet effet.
      final BusStop petersen = appDataService.stops
          .firstWhere((BusStop s) => s.id == 'stop_brt_01_petersen');
      final BusStop mosquee = appDataService.stops
          .firstWhere((BusStop s) => s.id == 'stop_brt_02_mosquee');
      expect(petersen.name, 'Papa Gueye Fall - PEM Petersen BRT');
      expect(mosquee.name, 'Grande Mosquée - BRT');
      final Stop a = arret(
          name: petersen.name,
          location: LatLng(petersen.latitude, petersen.longitude),
          direction: 'Terminus Petersen (Arrivée)',
          modeLabel: 'BRT');
      final Stop b = arret(
          name: mosquee.name,
          location: LatLng(mosquee.latitude, mosquee.longitude),
          direction: 'Dir. Petersen',
          modeLabel: 'BRT');
      final double d = DistanceHelper.haversineMeters(a.location, b.location);
      expect(d, closeTo(311.9, 0.5));
      expect(
          OppositeStopService.findOppositeStop(
              currentStop: a, allStops: <Stop>[a, b]),
          isNotNull,
          reason: 'faux positif documenté de la passe 2 sur la donnée ACTIVE');
    });

    test('donnée ACTIVE : aucune correspondance n\'est forcée, pour aucun arrêt', () {
      // Les 117 arrêts réels sont versés dans une même liste, tous avec le même
      // libellé de sens : la passe 2, qui exige deux sens différents, est donc
      // inerte. Reste la passe 1 — or le test d'ÉCART N°2 établit qu'elle ne
      // trouve aucune paire dans la donnée ACTIVE. Le service doit alors
      // renvoyer `null` pour CHAQUE arrêt, sans jamais forcer de correspondance
      // ni créer d'arrêt de substitution (§12).
      // Chaque arrêt est testé en tant que `currentStop` DEPUIS la liste, afin
      // que l'exclusion par `identical()` s'applique exactement comme dans
      // l'application : un arrêt n'est jamais son propre vis-à-vis.
      final List<Stop> reels = appDataService.stops
          .map((BusStop s) => arret(
              name: s.name,
              location: LatLng(s.latitude, s.longitude),
              direction: 'Dir. Centre',
              modeLabel: 'TER'))
          .toList();
      expect(reels.length, 117);

      final List<String> forces = <String>[];
      for (final Stop courant in reels) {
        final Stop? trouve = OppositeStopService.findOppositeStop(
            currentStop: courant, allStops: reels);
        if (trouve != null) forces.add('${courant.name} -> ${trouve.name}');
      }
      expect(forces, isEmpty,
          reason: 'correspondances forcées sur la donnée ACTIVE : $forces');
    });
  });
}
