import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';

// =============================================================================
// CORRECTION GPS HORS ZONE DE COUVERTURE + EXPLORATION CARTOGRAPHIQUE
// =============================================================================
//
// Couvre les exigences de tests du correctif :
//   GPS
//     • position réelle dans la zone de service ;
//     • position réelle en France ;
//     • permission accordée / refusée / refusée définitivement ;
//     • service de localisation désactivé ;
//     • position absente ou invalide ;
//     • aucune fausse position GPS injectée (garde-fou source).
//   Exploration cartographique
//     • ouverture sur Dakar depuis la France / sans GPS ;
//     • consultation des arrêts sans position à Dakar ;
//     • filtres Tous, Favoris, TER, BRT, DDD, TATA, AFTU ;
//     • absence de distances de plusieurs milliers de kilomètres ;
//     • pas de confusion centre de carte / position réelle.
//   Données et itinéraires
//     • dakar_network.json inchangé (taille verrouillée) ;
//     • aucun tracé fictif ajouté par le correctif ;
//     • données manquantes non présentées comme vérifiées (invariants existants
//       dans ter_brt_route_data_test / network_data_test — non régressés).
//
// Coutures pures uniquement : aucune dépendance au plugin geolocator.

/// Position réelle simulée en France (Paris) — plausible mais hors zone.
const LatLng _paris = LatLng(48.8566, 2.3522);

/// Position réelle simulée à Dakar (gare TER) — en zone de service.
const LatLng _dakarUser = LatLng(14.67599, -17.43352);

Stop _stop(String name, LatLng at, {Color? color, double distanceMeters = 500}) =>
    Stop(
      name: name,
      direction: 'Aller',
      distanceMeters: distanceMeters,
      departureMinutesFromMidnight: const [600],
      icon: Icons.directions_bus,
      color: color ?? AppColors.brt,
      location: at,
      modeLabel: 'BRT',
    );

/// Retire les commentaires d'un fichier source (chaînes conservées) — même
/// technique que gps_position_test.dart pour les garde-fous « source ».
String _stripComments(String src) {
  final out = StringBuffer();
  int i = 0;
  final n = src.length;
  String? quote;
  int interp = 0;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';
    if (quote == null) {
      if (c == '/' && next == '/') {
        while (i < n && src[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '*') {
        i += 2;
        while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
      if (c == "'" || c == '"') quote = c;
      out.write(c);
      i++;
      continue;
    }
    if (c == '\\' && i + 1 < n) {
      out.write(c);
      out.write(src[i + 1]);
      i += 2;
      continue;
    }
    if (c == '\n') {
      quote = null;
      interp = 0;
      out.write(c);
      i++;
      continue;
    }
    if (interp == 0 && c == r'$' && next == '{') {
      interp = 1;
      out.write(c);
      out.write(next);
      i += 2;
      continue;
    }
    if (interp > 0) {
      if (c == '{') {
        interp++;
      } else if (c == '}') {
        interp--;
      }
      out.write(c);
      i++;
      continue;
    }
    if (c == quote) quote = null;
    out.write(c);
    i++;
  }
  return out.toString();
}

void main() {
  group('GPS — détection hors zone distincte de la validité technique', () {
    test('position EN zone de service → « Position GPS obtenue. », hors zone = false', () {
      final r = GpsResolver.fromMeasuredPosition(_dakarUser);

      expect(r.state, GpsState.granted);
      expect(r.position, _dakarUser);
      expect(r.message, 'Position GPS obtenue.');
      expect(r.isOutOfCoverage, isFalse);
      expect(r.isSubstitutedPosition, isFalse);
    });

    test('position EN France → position réelle conservée + message de couverture exigé', () {
      final r = GpsResolver.fromMeasuredPosition(_paris);

      expect(PositionValidity.isPlausible(_paris), isTrue,
          reason: 'la position technique reste valide (PositionValidity inchangée)');
      expect(r.state, GpsState.granted,
          reason: 'la position réelle n\'est pas rejetée');
      expect(r.position, _paris,
          reason: '§2 : aucune position de Dakar injectée par-dessus la mesure');
      expect(r.message, 'Vous êtes hors de la zone de couverture Dakar Bus');
      expect(r.message, isNot('Position GPS obtenue.'),
          reason: '§2 : ne pas afficher « Position GPS obtenue » comme si '
              'l\'utilisateur était dans la zone de service');
      expect(r.isOutOfCoverage, isTrue);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.hasRealPosition, isTrue,
          reason: 'la position est réelle — seul le statut de couverture change');
    });

    test('isWithinServiceZone : logique distincte de PositionValidity', () {
      // Dans la zone.
      expect(GpsResolver.isWithinServiceZone(_dakarUser), isTrue);
      expect(PositionValidity.isPlausible(_dakarUser), isTrue);
      // Hors zone mais plausible (France).
      expect(GpsResolver.isWithinServiceZone(_paris), isFalse);
      expect(PositionValidity.isPlausible(_paris), isTrue);
      // Absente.
      expect(GpsResolver.isWithinServiceZone(null), isFalse);
      // Implausible ET hors zone : les deux prédicats refusent, pour des
      // raisons différentes (technique vs géographique).
      expect(GpsResolver.isWithinServiceZone(const LatLng(0, 0)), isFalse);
      expect(PositionValidity.isPlausible(const LatLng(0, 0)), isFalse);
      // Réutilise DakarBounds (limites existantes du projet, aucune zone
      // inventée).
      expect(GpsResolver.isWithinServiceZone(const LatLng(14.91, -17.4)), isFalse);
      expect(GpsResolver.isWithinServiceZone(const LatLng(14.72, -17.61)), isFalse);
    });

    test('les deux messages de granted sont distincts (état identique, étiquette différente)', () {
      final enZone = GpsResolver.fromMeasuredPosition(_dakarUser);
      final horsZone = GpsResolver.fromMeasuredPosition(_paris);

      expect(enZone.state, horsZone.state);
      expect(enZone.message, isNot(horsZone.message));
      expect(horsZone.message, GpsResolver.outOfCoverageMessage);
      expect(GpsResolver.outOfCoverageMessage,
          'Vous êtes hors de la zone de couverture Dakar Bus');
    });

    test('permission accordée → flux ; depuis la France le message reste celui de couverture', () {
      // `_requestLocation` délègue chaque mesure à fromMeasuredPosition :
      // permission accordée + mesure en France = granted + message hors zone.
      final r = GpsResolver.fromMeasuredPosition(_paris);
      expect(r.state, GpsState.granted);
      expect(r.message, GpsResolver.outOfCoverageMessage);
    });

    test('permission refusée → denied, position nulle, aucun message de zone', () {
      final r = GpsResolver.permissionDenied(forever: false);
      expect(r.state, GpsState.denied);
      expect(r.message, 'Permission GPS refusée.');
      expect(r.position, isNull);
      expect(r.isOutOfCoverage, isFalse);
    });

    test('permission refusée définitivement → deniedForever, position nulle', () {
      final r = GpsResolver.permissionDenied(forever: true);
      expect(r.state, GpsState.deniedForever);
      expect(r.message, GpsResolver.deniedForeverMessage);
      expect(r.position, isNull);
      expect(r.isOutOfCoverage, isFalse);
    });

    test('service de localisation désactivé → serviceDisabled, position nulle', () {
      const r = GpsResolver.serviceDisabled;
      expect(r.state, GpsState.serviceDisabled);
      expect(r.message, 'GPS désactivé.');
      expect(r.position, isNull);
      expect(r.isOutOfCoverage, isFalse);
    });

    test('position absente ou invalide → erreur, position nulle, jamais fabriquée', () {
      for (final r in <GpsResolution>[
        GpsResolver.fromMeasuredPosition(null),
        GpsResolver.fromMeasuredPosition(const LatLng(0, 0)),
        GpsResolver.fromStreamInterrupted(null),
        GpsResolver.fromStreamInterrupted(const LatLng(0, 0)),
        GpsResolver.error,
      ]) {
        expect(r.position, isNull);
        expect(r.isSubstitutedPosition, isFalse);
        expect(r.isOutOfCoverage, isFalse,
            reason: 'pas de position → pas de statut de couverture');
      }
      expect(GpsResolver.fromMeasuredPosition(null).state, GpsState.error);
    });

    test('interruption de flux EN France → position réelle conservée + message hors zone', () {
      final r = GpsResolver.fromStreamInterrupted(_paris);
      expect(r.state, GpsState.granted);
      expect(r.position, _paris);
      expect(r.message, GpsResolver.outOfCoverageMessage);
      expect(r.isOutOfCoverage, isTrue);
      expect(r.isSubstitutedPosition, isFalse);
    });

    test('GpsState conserve exactement ses 7 valeurs (aucun état ajouté)', () {
      expect(GpsState.values, hasLength(7));
      expect(GpsState.values.map((s) => s.name).toList(), <String>[
        'idle',
        'loading',
        'granted',
        'denied',
        'deniedForever',
        'serviceDisabled',
        'error',
      ]);
    });
  });

  group('Exploration — liste Explorer depuis la France ou sans GPS', () {
    // Fixtures : arrêts réels autour de Dakar + un hors de DakarBounds ignoré.
    final base = <Stop>[
      _stop('near_dakar_center', const LatLng(14.7170, -17.4640)),
      _stop('petersen', const LatLng(14.6738, -17.4381)),
      _stop('guediawaye', const LatLng(14.7735, -17.3977)),
      _stop('parcelles', const LatLng(14.7562, -17.4331)),
      _stop('yoff', const LatLng(14.7645, -17.3660)),
      _stop('diamniadio', const LatLng(14.7360, -17.1860)),
      _stop('rufisque', const LatLng(14.7167, -17.1660)),
      _stop('hors_rectangle', const LatLng(15.5, -17.0)),
    ];

    test('depuis la France : résultat IDENTIQUE à « sans GPS » (exploration indépendante)', () {
      final depuisFrance = explorerVisibleStops(base: base, userPosition: _paris);
      final sansGps = explorerVisibleStops(base: base, userPosition: null);

      expect(
        depuisFrance.map((s) => s.name).toList(),
        sansGps.map((s) => s.name).toList(),
        reason: 'la position en France ne doit ni trier « à proximité » depuis '
            'la France ni changer la liste affichée',
      );
    });

    test('depuis la France : uniquement des arrêts dans DakarBounds, plafond 30 respecté', () {
      final result = explorerVisibleStops(base: base, userPosition: _paris);

      expect(result, isNotEmpty);
      expect(result.length, lessThanOrEqualTo(GpsResolver.nearbyLimit));
      for (final s in result) {
        expect(DakarBounds.isValid(s.location), isTrue,
            reason: '${s.name} doit être dans la zone de données réseau');
      }
      expect(result.map((s) => s.name), isNot(contains('hors_rectangle')));
    });

    test('GPS refusé / indisponible (null) : la liste reste celle de Dakar', () {
      final result = explorerVisibleStops(base: base, userPosition: null);
      expect(result.map((s) => s.name), contains('near_dakar_center'),
          reason: 'les arrêts de Dakar restent consultables sans position GPS');
      for (final s in result) {
        expect(DakarBounds.isValid(s.location), isTrue);
      }
    });

    test('EN zone de service : le tri « à proximité » reste celui d\'avant (régression TER/BRT)', () {
      // Position à Dakar, arrêt à ~100 m au nord du centre : le chemin
      // rayon 4 km / plafond 30 / tri par distance mesurée reste actif.
      final near = _stop('a_100m', LatLng(_dakarUser.latitude + 100 / 111195.08, _dakarUser.longitude));
      final far = _stop('b_20km', LatLng(_dakarUser.latitude + 20000 / 111195.08, _dakarUser.longitude));

      final result = explorerVisibleStops(
          base: [far, near], userPosition: _dakarUser);

      expect(result.map((s) => s.name).toList(), <String>['a_100m'],
          reason: 'rayon 4 km inchangé en zone de service');
    });

    test('la liste d\'entrée n\'est jamais mutée (aucune donnée de transport modifiée)', () {
      final snapshot = base.map((s) => s.name).toList();
      explorerVisibleStops(base: base, userPosition: _paris);
      explorerVisibleStops(base: base, userPosition: _dakarUser);
      expect(base.map((s) => s.name).toList(), snapshot);
    });
  });

  group('Exploration — filtres Tous, Favoris, TER, BRT, DDD, TATA, AFTU', () {
    final source = <Stop>[
      _stop('ter_1', const LatLng(14.6800, -17.4400), color: AppColors.ter),
      _stop('ter_2', const LatLng(14.7000, -17.4300), color: AppColors.ter),
      _stop('brt_1', const LatLng(14.7100, -17.4500), color: AppColors.brt),
      _stop('brt_2', const LatLng(14.7200, -17.4400), color: AppColors.brt),
      _stop('ddd_1', const LatLng(14.7300, -17.4200), color: AppColors.ddd),
      _stop('tata_1', const LatLng(14.7400, -17.4100), color: AppColors.tata),
      _stop('aftu_1', const LatLng(14.7500, -17.4000), color: AppColors.aftu),
      _stop('fav_ddd', const LatLng(14.7600, -17.3900),
          color: AppColors.ddd),
    ];
    const favorites = {'fav_ddd', 'brt_1'};

    List<Stop> filter(String name) => explorerBaseStopsForFilter(
          selectedFilter: name,
          favoriteStopNames: favorites,
          source: source,
        );

    test('Tous → tous les arrêts, aucun filtre réseau appliqué', () {
      final r = filter('Tous');
      expect(r, hasLength(source.length));
    });

    test('Favoris → uniquement les noms favoris', () {
      final r = filter('⭐ Favoris');
      expect(r.map((s) => s.name).toSet(), <String>{'fav_ddd', 'brt_1'});
    });

    test('TER → uniquement la couleur TER', () {
      final r = filter('TER');
      expect(r, hasLength(2));
      expect(r.every((s) => s.color == AppColors.ter), isTrue);
    });

    test('BRT → uniquement la couleur BRT', () {
      final r = filter('BRT');
      expect(r, hasLength(2));
      expect(r.every((s) => s.color == AppColors.brt), isTrue);
    });

    test('DDD → uniquement la couleur DDD', () {
      final r = filter('DDD');
      expect(r, hasLength(2));
      expect(r.every((s) => s.color == AppColors.ddd), isTrue);
    });

    test('TATA → uniquement la couleur TATA', () {
      final r = filter('TATA');
      expect(r, hasLength(1));
      expect(r.every((s) => s.color == AppColors.tata), isTrue);
    });

    test('AFTU → uniquement la couleur AFTU', () {
      final r = filter('AFTU');
      expect(r, hasLength(1));
      expect(r.every((s) => s.color == AppColors.aftu), isTrue);
    });

    test('chaque filtre est consultable depuis la France comme sans GPS', () {
      for (final name in <String>[
        'Tous',
        '⭐ Favoris',
        'TER',
        'BRT',
        'DDD',
        'TATA',
        'AFTU',
      ]) {
        final base = filter(name);
        final depuisFrance =
            explorerVisibleStops(base: base, userPosition: _paris)
                .map((s) => s.name)
                .toList();
        final sansGps = explorerVisibleStops(base: base, userPosition: null)
            .map((s) => s.name)
            .toList();

        expect(depuisFrance, sansGps,
            reason: 'filtre « $name » : la France ne change pas la '
                'consultation des arrêts de Dakar');
        expect(depuisFrance, isNotEmpty,
            reason: 'filtre « $name » : au moins un arrêt affichable');
      }
    });
  });

  group('Distances affichées — aucune distance de plusieurs milliers de kilomètres', () {
    final stops = <Stop>[
      _stop('petersen', const LatLng(14.6738, -17.4381), distanceMeters: 350),
      _stop('guediawaye', const LatLng(14.7735, -17.3977), distanceMeters: 2400),
      _stop('yoff', const LatLng(14.7645, -17.3660), distanceMeters: 35000),
    ];

    test('TOUTES les distances réelles (dakar_network.json intégré) restent < 100 km', () async {
      // Donnée ACTIVE, jamais le repli en dur : même chemin que
      // explorer_marker_render_test.prepareNetwork.
      TestWidgetsFlutterBinding.ensureInitialized();
      if (!appDataService.isLoaded) {
        await appDataService.loadNetworkData();
      }
      expect(appDataService.isLoaded, isTrue);
      integrateNetworkDataForTest();
      expect(allStops, isNotEmpty);

      for (final s in allStops) {
        final double depuisFrance = explorerDistanceForDisplay(s, _paris);
        expect(depuisFrance, s.distanceMeters,
            reason: '${s.name} : hors zone, repli Stop.distanceMeters');
        expect(depuisFrance, lessThan(100000),
            reason: '${s.name} : jamais de « plusieurs milliers de km »');

        final double enZone = explorerDistanceForDisplay(s, _dakarUser);
        expect(enZone, lessThan(100000),
            reason: '${s.name} : en zone, la vraie distance Dakar→arrêt reste '
                'loin des milliers de km');
      }

      // Contrôle : depuis la France, l'haversine brute AURAIT été > 4 000 km
      // pour chaque arrêt — le repli est donc réellement actif.
      final sample = allStops.first;
      expect(DistanceHelper.haversineMeters(_paris, sample.location),
          greaterThan(4000000));
    });

    test('depuis la France → repli Stop.distanceMeters (jamais l\'haversine France→Dakar)', () {
      for (final s in stops) {
        final d = explorerDistanceForDisplay(s, _paris);
        expect(d, s.distanceMeters);
        expect(d, lessThan(100000),
            reason: '${s.name} : aucune distance « plusieurs milliers de km » '
                'présentée comme proximité utile');
        // Contrôle : l'haversine brute France→Dakar serait ~14 000 km.
        final brute = DistanceHelper.haversineMeters(_paris, s.location);
        expect(brute, greaterThan(4000000),
            reason: 'la fixture doit réellement être à des milliers de km');
        expect(d, isNot(brute));
      }
    });

    test('sans GPS → repli identique (comportement préexistant conservé)', () {
      for (final s in stops) {
        expect(explorerDistanceForDisplay(s, null), s.distanceMeters);
      }
    });

    test('EN zone de service → distance réelle mesurée inchangée', () {
      for (final s in stops) {
        final d = explorerDistanceForDisplay(s, _dakarUser);
        expect(d,
            DistanceHelper.haversineMeters(_dakarUser, s.location),
            reason: 'en zone, la vraie distance reste affichée');
      }
    });
  });

  group('Gardes-fous source — carte indépendante du GPS, aucune fausse position', () {
    late final String code;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue,
          reason: 'flutter test s\'exécute à la racine du paquet');
      code = _stripComments(file.readAsStringSync());
    });

    test('l\'ouverture de la carte sur Dakar est indépendante de la position GPS', () {
      expect(code.contains('initialCenter: GpsResolver.isWithinServiceZone'),
          isTrue,
          reason: 'initialCenter n\'accepte la position utilisateur QUE dans '
              'la zone de service ; sinon _dakarCenter');
      expect(
        RegExp(r'initialCenter:\s*\(?\s*widget\.userPosition').hasMatch(code),
        isFalse,
        reason: 'plus de centrage initial aveugle sur la position GPS '
            '(ancien chemin qui ouvrait la carte sur la France)');
    });

    test('les mises à jour GPS ne re-centrent pas la carte hors zone', () {
      expect(
        RegExp(r'didUpdateWidget[\s\S]{0,600}?isWithinServiceZone').hasMatch(code),
        isTrue,
        reason: 'didUpdateWidget est gardé par le prédicat de zone de service',
      );
    });

    test('le message de couverture exigé est présent et utilisé', () {
      expect(
        code.contains(
            "'Vous êtes hors de la zone de couverture Dakar Bus'"),
        isTrue,
        reason: '§3 : message exact dans le bandeau existant (via GpsResolver)',
      );
      expect(
        'GpsResolver.outOfCoverageMessage'.allMatches(code).length,
        greaterThanOrEqualTo(2),
        reason: 'le message est produit par le resolver ET consommé (assistant/UX)',
      );
      expect(code.contains('GpsResolver.isWithinServiceZone'), isTrue);
      expect('GpsResolver.isWithinServiceZone'.allMatches(code).length,
          greaterThanOrEqualTo(6),
          reason: 'la détection de zone couvre liste, distance, centrage, IA…');
    });

    test('aucune fausse position GPS injectée dans _userPosition', () {
      expect(RegExp(r'_userPosition\s*=\s*const\s+LatLng').hasMatch(code), isFalse);
      expect(RegExp(r'_userPosition\s*=\s*LatLng\s*\(').hasMatch(code), isFalse);
      expect(code.contains('_userPosition = r.position'), isTrue);
      expect(code.contains('isSubstitutedPosition'), isTrue);
      expect(RegExp(r'simulatedPosition|fakePosition|mockPosition').hasMatch(code),
          isFalse,
          reason: 'aucun mode simulation activable ni position simulée injectée');
    });

    test('PositionValidity n\'a pas été modifié pour rejeter la France', () {
      // Le corps de isPlausibleCoordinates ne doit contenir aucun contrôle de
      // zone : seuls (0,0), bornes globe et NaN/inf sont rejetés.
      final match = RegExp(r'isPlausibleCoordinates\(double lat, double lon\)\s*\{([\s\S]*?)\n  \}')
          .firstMatch(code);
      expect(match, isNotNull, reason: 'PositionValidity.isPlausibleCoordinates présent');
      final body = match!.group(1)!;
      expect(body.contains('DakarBounds'), isFalse,
          reason: 'aucun rejet géographique dans la validité technique');
      expect(body.contains('isNaN'), isTrue);
      expect(body.contains('90.0'), isTrue);
      expect(body.contains('180.0'), isTrue);
    });

    test('aucun tracé fictif ajouté par le correctif (source : pas de nouvelle polyligne)', () {
      // Les seules constructions de TransitRoute restent celles de
      // _integrateNetworkData (données JSON). Le correctif n'ajoute ni
      // coordonnée, ni point de tracé.
      expect(
        RegExp(r'TransitRoute\(').allMatches(code).length,
        lessThanOrEqualTo(3),
        reason: 'aucun constructeur de tracé supplémentaire introduit '
            '(appels existants : _integrateNetworkData + définitions)',
      );
      expect(code.contains('dakarOrderCenter'), isTrue,
          reason: 'le centre de Dakar ne sert qu\'à ORDONNER, jamais comme tracé');
    });

    test('dakar_network.json inchangé (taille verrouillée — source unique)', () {
      final file = File('assets/data/dakar_network.json');
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync().length, 59189,
          reason: 'données TER/BRT/DDD/TATA/AFTU non modifiées par le correctif');
    });
  });
}
