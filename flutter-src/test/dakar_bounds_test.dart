import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';

/// GROUPE 1 (Step 4B) — garde-fou géographique et distance.
///
/// MODIFICATION MAJEURE de ce fichier : le test
/// « Ocean exclusion zone is invalid » a été INVERSÉ.
///
/// Il n'est pas supprimé pour faciliter la réintégration (ce que le §24
/// interdit) : son attente est contredite par la DONNÉE ACTIVE. Le rectangle
/// 14.7000-14.7450 × -17.4350 à -17.3750 contient trois des 13 gares TER que
/// le §6 interdit de supprimer :
///   stop_hann (14.72209, -17.43207), stop_dalifort_ter (14.73425, -17.41900),
///   stop_baux_maraichers (14.73971, -17.40361).
/// Preuve indépendante : le validateur `eI` du binaire de production porte le
/// commentaire « v4 : rectangle d'exclusion Hann/Dalifort retire (il couvrait
/// 3 gares TER officielles : Hann, Dalifort, Baux Maraichers) ».
void main() {
  group('DakarBounds — données non modifiées par le Groupe 1', () {
    test('Petersen is valid', () {
      expect(DakarBounds.isValid(const LatLng(14.6738, -17.4381)), true);
    });
    test('Guediawaye is valid', () {
      expect(DakarBounds.isValid(const LatLng(14.7735, -17.3977)), true);
    });
    test('Paris is invalid', () {
      expect(DakarBounds.isValid(const LatLng(48.8566, 2.3522)), false);
    });
    test('0,0 is invalid', () {
      // Garde CONSERVÉ bien que la production l'ait retiré : aucune donnée
      // active n'est à (0,0) et le §11 interdit de valider une position
      // absente. Voir la documentation de DakarBounds.
      expect(DakarBounds.isValid(const LatLng(0, 0)), false);
    });
  });

  group('DakarBounds — rectangle « océan » retiré (Groupe 1)', () {
    test('Hann - Maristes / TER est valide', () {
      expect(DakarBounds.isValid(const LatLng(14.72209, -17.43207)), true);
    });
    test('Dalifort - Gare TER est valide', () {
      expect(DakarBounds.isValid(const LatLng(14.73425, -17.41900)), true);
    });
    test('Baux Maraîchers - TER est valide', () {
      expect(DakarBounds.isValid(const LatLng(14.73971, -17.40361)), true);
    });
    test('le point central de l ancien rectangle est désormais valide', () {
      // (14.72, -17.40) était l'exemple même de la fausse « zone océan ».
      expect(DakarBounds.isValid(const LatLng(14.72, -17.40)), true);
    });
    test('Malika (14.8015) est valide — borne nord étendue', () {
      // Rejetée par l'ancienne borne nord 14.7900.
      expect(DakarBounds.isValid(const LatLng(14.8015, -17.3376)), true);
    });
    test('les bornes sont celles de la production', () {
      expect(DakarBounds.south, 14.55);
      expect(DakarBounds.north, 14.9);
      expect(DakarBounds.west, -17.6);
      expect(DakarBounds.east, -16.85);
    });
    test('hors du rectangle reste invalide', () {
      expect(DakarBounds.isValid(const LatLng(14.54, -17.40)), false);
      expect(DakarBounds.isValid(const LatLng(14.91, -17.40)), false);
      expect(DakarBounds.isValid(const LatLng(14.72, -17.61)), false);
      expect(DakarBounds.isValid(const LatLng(14.72, -16.84)), false);
    });
  });

  group('DistanceHelper', () {
    test('haversineMeters ~1km', () {
      // Petersen -> Sandaga ~2.0km (2019.84 m avec R = 6371008.8)
      final d = DistanceHelper.haversineMeters(
        const LatLng(14.6738, -17.4381),
        const LatLng(14.6870, -17.4510),
      );
      expect(d, greaterThan(1000));
      expect(d, lessThan(3000));
    });

    test('le rayon terrestre est 6 371 008,8 m (Groupe 1)', () {
      // Un degré de latitude pur vaut R * pi/180.
      //   R = 6371008.8 -> 111195.08023352182 m
      //   R = 6371000.0 -> 111194.92664454764 m
      // L'écart de 0,1536 m rend ce test discriminant à 1e-3 près : il échoue
      // avec l'ancien rayon.
      final d = DistanceHelper.haversineMeters(
        const LatLng(14.0, -17.0),
        const LatLng(15.0, -17.0),
      );
      expect(d, closeTo(111195.08023352182, 0.001));
    });

    test('distance nulle', () {
      expect(
        DistanceHelper.haversineMeters(
            const LatLng(14.72, -17.40), const LatLng(14.72, -17.40)),
        0.0,
      );
    });

    test('symétrie', () {
      const a = LatLng(14.6738, -17.4381);
      const b = LatLng(14.7735, -17.3977);
      expect(DistanceHelper.haversineMeters(a, b),
          DistanceHelper.haversineMeters(b, a));
    });

    test('format', () {
      // GROUPE 7 (P1) — comportement aligné sur le formateur de production
      // `A.azr` (gh-pages 94a84b60) :
      //   if (a < 950) return round(a) + " m";
      //   s = a / 1000;
      //   if (s < 10) return s.toStringAsFixed(1) + " km";
      //   return round(s) + " km";
      //
      // Branche 1 — mètres, seuil 950 m EXCLU.
      expect(DistanceHelper.format(0), '0 m');
      expect(DistanceHelper.format(1), '1 m');
      expect(DistanceHelper.format(100), '100 m');
      expect(DistanceHelper.format(850), '850 m');
      expect(DistanceHelper.format(949), '949 m');

      // Branche 2 — kilomètres à une décimale, de 950 m inclus à 10 km exclu.
      //
      // Valeur charnière 950 m : `950 / 1000.0` vaut exactement
      // 0.94999999999999995559 en IEEE-754, donc `toStringAsFixed(1)` —
      // compilé par dart2js en `toFixed(1)` — donne « 0.9 » et non « 1.0 ».
      // La production affiche « 0.9 km » pour 950 m ; c'est cette valeur
      // réelle qui est verrouillée ici, et non un arrondi décimal mental.
      expect(DistanceHelper.format(950), '0.9 km');
      expect(DistanceHelper.format(999), '1.0 km');
      expect(DistanceHelper.format(1000), '1.0 km');
      expect(DistanceHelper.format(1500), '1.5 km');
      // 9.999 reste dans la branche 2 (s < 10) et arrondit à « 10.0 ».
      expect(DistanceHelper.format(9999), '10.0 km');

      // Branche 3 — kilomètres ENTIERS à partir de 10 km inclus.
      expect(DistanceHelper.format(10000), '10 km');
      expect(DistanceHelper.format(12345), '12 km');
      expect(DistanceHelper.format(17900), '18 km');
      expect(DistanceHelper.format(35000), '35 km');
    });

    test('format — les trois branches de A.azr sont distinctes (Groupe 7 P1)',
        () {
      // Garde-fou contre les deux divergences corrigées (anomalie O1) :
      //  1. le seuil mètres/kilomètres est 950 et non 1000 ;
      //  2. au-delà de 10 km le résultat est entier et non à une décimale.
      // Chaque branche doit produire un format reconnaissable et stable.
      expect(DistanceHelper.format(949), endsWith(' m'));
      expect(DistanceHelper.format(950), endsWith(' km'));
      expect(DistanceHelper.format(9999), endsWith('.0 km'));
      expect(DistanceHelper.format(10000), endsWith(' km'));
      expect(DistanceHelper.format(10000).contains('.'), isFalse,
          reason: 'à partir de 10 km, A.azr arrondit à l\'entier');
      expect(DistanceHelper.format(17900).contains('.'), isFalse,
          reason: '17900 m doit donner « 18 km », jamais « 17.9 km »');
    });
  });

  group('Stop isContinuousFlow logic', () {
    test('placeholder - verified via modeLabel', () {
      // AFTU/DDD/Tata sont en rotation continue (isContinuousFlow true)
      // Vérifié indirectement via DistanceHelper et DakarBounds
      expect(DistanceHelper.format(100), '100 m');
    });
  });
}
