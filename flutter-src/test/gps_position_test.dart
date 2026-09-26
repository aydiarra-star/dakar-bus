import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart' as network;
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/external_gtfs/cetud_feed_bootstrap.dart';
import 'package:dakar_bus/services/external_gtfs/departure_adapter.dart';
import 'package:dakar_bus/services/external_gtfs/frequency_source.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_feed.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_schedule_service.dart' as gtfs;
import 'package:dakar_bus/services/external_gtfs/transit_data_provider.dart';
import 'external_gtfs_test.dart' show aftuTexts, cetudProvenance, saturday0730;


// GROUPE 4 (Step 4B) — GPS §11 + §16.
//
// Comportements PROUVÉS réintégrés (rapport 4A, Carte 04, L159-173) :
//   • rayon « à proximité » = **4000 m** (`A.ap3`), au lieu de 5000 m ;
//   • plafond Explorer = **30 résultats** (`take(30)`), au lieu de 20 ;
//   • flux continu `getPositionStream` avec
//     `LocationSettings(accuracy: high, distanceFilter: 10, timeLimit: 20 s)`
//     (`B.Lf`), au lieu d'un `getCurrentPosition` ponctuel à 10 s ;
//   • les 3 états d'erreur conservés (`serviceDisabled`, `denied`, `error`).
//
// Défaut commun source + production CORRIGÉ (4A §16, L1310-1324) :
//   une position mesurée hors zone était remplacée par
//   `LatLng(14.7167, -17.4677)` avec l'état `granted`. §11 interdit toute
//   position fabriquée : décision D1-i → `position == null` + état d'erreur
//   explicite, le recadrage Dakar restant assuré par `_dakarCenter`.
//
// CORRECTIF POSITION UTILISATEUR (PositionValidity) :
//   la position mesurée n'est plus soumise à `DakarBounds` (garde-fou des
//   données réseau uniquement). Toute position mesurée géodésiquement
//   plausible est conservée telle quelle, où qu'elle soit (Thiès, Rufisque,
//   Saint-Louis…). Seuls les échecs de mesure — île nulle (0,0), |lat| > 90,
//   |lon| > 180 — produisent « Erreur GPS. ». §11 / D1-i restent intacts :
//   aucune position absente ou fabriquée n'est exposée.
//
// CORRECTION HORS ZONE DE COUVERTURE (distincte du rejet historique) :
//   une position plausible HORS de la zone de service (France…) reste
//   `granted` avec sa coordonnée réelle, mais le message du bandeau devient
//   « Vous êtes hors de la zone de couverture Dakar Bus » et
//   `isOutOfCoverage` vaut `true` — « Position GPS obtenue. » n'est plus
//   affiché comme si l'utilisateur était dans la zone de service. Les attentes
//   des tests hors zone (Paris, etc.) sont adaptées en conséquence ; les
//   attentes EN zone (message « Position GPS obtenue. ») sont inchangées.
//
// ---------------------------------------------------------------------------
// MÉTHODE — décision D3-i (couture pure, aucune dépendance ajoutée)
// ---------------------------------------------------------------------------
// `Geolocator` passe par des platform channels : en `flutter test`, tout appel
// réel lève `MissingPluginException`. Toute la décision GPS a donc été placée
// dans [GpsResolver], qui ne manipule que des types Dart simples (`LatLng?`,
// `bool`, `Iterable<Stop>`) et ne référence jamais le plugin. Ces tests
// vérifient les décisions et les calculs **sans dépendre du plugin de
// géolocalisation** et sans modifier `pubspec.yaml`.
//
// Ce qui n'est PAS testable ici et ne l'est pas : la signature réelle de
// `LocationSettings` / `getPositionStream` en geolocator ^12.0.0 (vérifiée par
// `flutter analyze` en CI) et le comportement runtime web (Groupe 10).
//
// ---------------------------------------------------------------------------
// PRÉCISION FLOTTANTE — leçon du Groupe 3
// ---------------------------------------------------------------------------
// Haversine dérive aux seuils exacts (120.0 → 119.99999717 ; 500.0 →
// 500.00000361, variation libm ~75 µm). Les fixtures de seuil utilisent donc
// des marges de ±0,1 m et la distance réellement mesurée est assertée.

/// Mètres par degré de latitude, cohérent avec le rayon de [DistanceHelper]
/// (R = 6 371 008,8 m, §10). Pour un déplacement purement en latitude, la
/// distance orthodromique vaut exactement R × Δlat(en radians).
const double _metersPerDegreeLat = 6371008.8 * math.pi / 180.0;

/// Position de référence des fixtures : gare TER de Dakar, réelle et plausible
/// au sens de [PositionValidity]. Volontairement différente de la coordonnée
/// de recadrage historique `LatLng(14.7167, -17.4677)`.
const LatLng _user = LatLng(14.67599, -17.43352);

LatLng _northOf(LatLng from, double meters) =>
    LatLng(from.latitude + meters / _metersPerDegreeLat, from.longitude);

Stop _stop(String name, LatLng at) => Stop(
      name: name,
      direction: 'Aller',
      distanceMeters: 0,
      departureMinutesFromMidnight: const [600],
      icon: Icons.directions_bus,
      color: AppColors.brt,
      location: at,
      modeLabel: 'BRT',
    );

/// Retire les commentaires (`//` et `/* */`) d'un fichier Dart.
///
/// Utilisé par les garde-fous « source » ci-dessous : un commentaire qui cite
/// `DataStatus.live`, `getCurrentPosition` ou `< 5000` ne doit pas être pris
/// pour du code.
///
/// Les chaînes sont **conservées** (seuls les commentaires sont retirés). Une
/// première version retirait aussi les chaînes : elle se désynchronisait sur
/// les interpolations Dart qui contiennent elles-mêmes des guillemets, par
/// exemple `${(normalized ~/ 60).toString().padLeft(2, '0')}` dans
/// `TimeHelper`. La présente version suit les interpolations `${...}` en
/// comptant les accolades, donc un guillemet interne ne peut plus fermer la
/// chaîne prématurément.
///
/// Vérifié à l'écriture de ces tests : aucun des motifs interdits par les
/// garde-fous n'apparaît dans un littéral de chaîne de `lib/main.dart`, donc
/// conserver les chaînes ne les affaiblit pas.
String _stripComments(String src) {
  final out = StringBuffer();
  int i = 0;
  final n = src.length;
  String? quote; // guillemet ouvrant de la chaîne en cours, null hors chaîne
  int interp = 0; // profondeur d'accolades dans une interpolation `${...}`
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';

    if (quote == null) {
      // Hors chaîne : les commentaires sont retirés, le reste recopié.
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

    // Dans une chaîne : tout est recopié tel quel.
    if (c == '\\' && i + 1 < n) {
      out.write(c);
      out.write(src[i + 1]);
      i += 2;
      continue;
    }
    if (c == '\n') {
      // Une chaîne simple ne peut pas contenir de saut de ligne brut.
      quote = null;
      interp = 0;
      out.write(c);
      i++;
      continue;
    }
    if (interp == 0 && c == '\$' && next == '{') {
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

// Adversarial TEST source: a static departure falsely labelled REAL_TIME.
// The real provider (not a mocked provider) must refuse to mark it current.
class _UnobservedRealtimeSource extends gtfs.GtfsScheduleService {
  _UnobservedRealtimeSource(super.feed);

  @override
  gtfs.DepartureResult getDeparturesAtStop(String routeId, String? stopId,
      String date, String time, {int? limit = 5, String? asOf}) {
    final r = super.getDeparturesAtStop(routeId, stopId, date, time,
        limit: limit, asOf: asOf);
    return gtfs.DepartureResult(routeId: r.routeId, stopId: r.stopId,
      date: r.date, currentTime: r.currentTime, status: 'REAL_TIME',
      reason: r.reason, source: r.source, sourceType: r.sourceType,
      feedVersion: r.feedVersion, validity: r.validity,
      provenanceLevel: r.provenanceLevel, departures: r.departures,
      isCurrent: true); // Deliberately forged claim; must not survive provider.
  }
}

void main() {
  group('Groupe 4 — §11 position réelle ou erreur, jamais fabriquée', () {
    test('(a) position mesurée et valide → granted, coordonnée conservée telle quelle', () {
      final measured = _northOf(_user, 250);
      expect(PositionValidity.isPlausible(measured), isTrue, reason: 'fixture doit être plausible');

      final r = GpsResolver.fromMeasuredPosition(measured);

      expect(r.state, GpsState.granted);
      expect(r.position, measured, reason: '§11 : la position affichée est celle mesurée');
      expect(r.position!.latitude, measured.latitude);
      expect(r.position!.longitude, measured.longitude);
      expect(r.hasRealPosition, isTrue);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.message, 'Position GPS obtenue.',
          reason: 'fixture en zone de service → message standard inchangé');
      expect(r.isOutOfCoverage, isFalse,
          reason: 'Dakar est dans la zone de service');
    });

    test('(e) position mesurée HORS du rectangle Dakar → conservée telle quelle (PositionValidity) + message hors zone', () {
      // AVANT : rejetée (« Position hors zone, recentré sur Dakar. ») alors
      // qu'elle était réelle. APRÈS : DakarBounds ne s'applique qu'aux données
      // réseau ; une position mesurée plausible est réelle, où qu'elle soit.
      // CORRECTION HORS ZONE : elle reste réelle ET affichable, mais le
      // bandeau signal « Vous êtes hors de la zone de couverture Dakar Bus »
      // au lieu de « Position GPS obtenue. ».
      const horsDakar = <String, LatLng>{
        'Mbour': LatLng(14.4167, -16.9667),
        'Saint-Louis': LatLng(16.0179, -16.4896),
        'nord du rectangle': LatLng(15.5, -17.0),
        'Paris': LatLng(48.8566, 2.3522),
      };
      for (final entry in horsDakar.entries) {
        expect(DakarBounds.isValid(entry.value), isFalse,
            reason: '${entry.key} : fixture hors du rectangle réseau');
        expect(PositionValidity.isPlausible(entry.value), isTrue,
            reason: '${entry.key} : position plausible');

        final r = GpsResolver.fromMeasuredPosition(entry.value);

        expect(r.state, GpsState.granted, reason: '${entry.key} : position réelle');
        expect(r.position, entry.value,
            reason: '${entry.key} : §11 — conservée telle quelle, aucune substitution');
        expect(r.hasRealPosition, isTrue);
        expect(r.isSubstitutedPosition, isFalse);
        expect(r.isOutOfCoverage, isTrue,
            reason: '${entry.key} : détection hors zone distincte de PositionValidity');
        expect(r.message, GpsResolver.outOfCoverageMessage,
            reason: '${entry.key} : le bandeau ne doit pas afficher « Position '
                'GPS obtenue » comme si l\'utilisateur était en zone de service');
        expect(r.message, isNot('Position GPS obtenue.'));
      }
    });

    test('(e bis) position géodésiquement implausible → position null + « Erreur GPS. » (D1-i)', () {
      // Île nulle (0,0) — valeur par défaut d'un géolocaliseur muet : un
      // échec de mesure, jamais une position réelle. (Les coordonnées hors du
      // globe, |lat| > 90 / |lon| > 180, sont couvertes sur doubles bruts dans
      // dakar_bounds_test.dart : `LatLng` les refuse déjà par assert.)
      const implausible = LatLng(0.0, 0.0);
      expect(PositionValidity.isPlausible(implausible), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(91.0, -17.0), isFalse);
      expect(PositionValidity.isPlausibleCoordinates(14.7, -181.0), isFalse);

      final r = GpsResolver.fromMeasuredPosition(implausible);

      expect(r.position, isNull,
          reason: 'D1-i : aucune position exposée si elle n\'est pas exploitable');
      expect(r.state, GpsState.error);
      expect(r.hasRealPosition, isFalse);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.message, 'Erreur GPS.');
    });

    test('D1-i : la coordonnée de repli historique n\'est JAMAIS produite comme position utilisateur', () {
      // 4A §16 : `B.hA = LatLng(14.7167, -17.4677)` était injectée comme
      // position de l'utilisateur. Elle ne doit plus l'être : ni pour une
      // mesure implausible (→ null), ni pour une mesure hors Dakar (→ la
      // mesure elle-même).
      const fabrication = LatLng(14.7167, -17.4677);

      for (final implausible in <LatLng>[
        const LatLng(0.0, 0.0),
      ]) {
        final r = GpsResolver.fromMeasuredPosition(implausible);
        expect(r.position, isNull, reason: 'implausible $implausible');
        expect(r.position, isNot(fabrication));
        expect(r.isSubstitutedPosition, isFalse,
            reason: '§16 : aucune substitution — la valeur est absente, pas remplacée');
        expect(r.state, GpsState.error);
      }
      for (final horsDakar in <LatLng>[
        const LatLng(15.5, -17.0), // nord
        const LatLng(14.0, -17.0), // sud
        const LatLng(14.7, -16.0), // est
        const LatLng(14.7, -18.0), // ouest
        const LatLng(48.8566, 2.3522), // Paris
      ]) {
        final r = GpsResolver.fromMeasuredPosition(horsDakar);
        expect(r.position, horsDakar, reason: 'hors Dakar $horsDakar : mesure conservée');
        expect(r.position, isNot(fabrication));
        expect(r.isSubstitutedPosition, isFalse);
      }
    });

    test('aucune mesure (null) → état d\'erreur explicite, position null', () {
      final r = GpsResolver.fromMeasuredPosition(null);

      expect(r.state, GpsState.error);
      expect(r.position, isNull);
      expect(r.hasRealPosition, isFalse);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.message, 'Erreur GPS.');
    });

    test('§16 : isSubstitutedPosition est false sur TOUS les chemins du resolver', () {
      final valid = _northOf(_user, 100);
      final resolutions = <GpsResolution>[
        GpsResolver.idle,
        GpsResolver.loading,
        GpsResolver.serviceDisabled,
        GpsResolver.error,
        GpsResolver.permissionDenied(forever: false),
        GpsResolver.permissionDenied(forever: true),
        GpsResolver.fromMeasuredPosition(valid),
        GpsResolver.fromMeasuredPosition(null),
        GpsResolver.fromMeasuredPosition(const LatLng(15.5, -17.0)),
        GpsResolver.fromMeasuredPosition(const LatLng(0.0, 0.0)),
        GpsResolver.fromStreamInterrupted(valid),
        GpsResolver.fromStreamInterrupted(null),
        GpsResolver.fromStreamInterrupted(const LatLng(15.5, -17.0)),
        GpsResolver.fromStreamInterrupted(const LatLng(0.0, 0.0)),
      ];

      expect(resolutions, hasLength(14));
      for (final r in resolutions) {
        expect(r.isSubstitutedPosition, isFalse,
            reason: 'état ${r.state} : aucune position substituée n\'est produite');
      }
    });

    test('hasRealPosition n\'est vrai que pour une position mesurée exploitable', () {
      expect(GpsResolver.fromMeasuredPosition(_northOf(_user, 10)).hasRealPosition, isTrue);
      expect(GpsResolver.fromMeasuredPosition(null).hasRealPosition, isFalse);
      expect(GpsResolver.fromMeasuredPosition(const LatLng(15.5, -17.0)).hasRealPosition, isTrue,
          reason: 'hors du rectangle Dakar mais réelle et plausible');
      expect(GpsResolver.fromMeasuredPosition(const LatLng(0.0, 0.0)).hasRealPosition, isFalse);
      expect(GpsResolver.serviceDisabled.hasRealPosition, isFalse);
      expect(GpsResolver.permissionDenied(forever: false).hasRealPosition, isFalse);
      expect(GpsResolver.permissionDenied(forever: true).hasRealPosition, isFalse);
      expect(GpsResolver.error.hasRealPosition, isFalse);
      expect(GpsResolver.idle.hasRealPosition, isFalse);
      expect(GpsResolver.loading.hasRealPosition, isFalse);
    });
  });

  group('Groupe 4 — les 3 états d\'erreur conservés + D4 distinguables', () {
    test('(b) service de localisation désactivé → serviceDisabled', () {
      const r = GpsResolver.serviceDisabled;

      expect(r.state, GpsState.serviceDisabled);
      expect(r.message, 'GPS désactivé.');
      expect(r.position, isNull);
    });

    test('(c) permission refusée → denied', () {
      final r = GpsResolver.permissionDenied(forever: false);

      expect(r.state, GpsState.denied);
      expect(r.message, 'Permission GPS refusée.');
      expect(r.position, isNull);
    });

    test('(c bis) permission refusée DÉFINITIVEMENT → deniedForever (D4)', () {
      final r = GpsResolver.permissionDenied(forever: true);

      expect(r.state, GpsState.deniedForever,
          reason: 'AVANT le Groupe 4 : `deniedForever` était déclaré sans jamais être assigné');
      expect(r.message, GpsResolver.deniedForeverMessage);
      // Le message indique l'action à mener : sur un navigateur, le bouton
      // « Activer GPS » ne peut pas lever un refus définitif.
      expect(r.message, startsWith('Permission GPS refusée définitivement'));
      expect(r.message, contains('réglages de votre navigateur'));
      expect(r.position, isNull);
    });

    test('(d) erreur du géolocaliseur → error', () {
      const r = GpsResolver.error;

      expect(r.state, GpsState.error);
      expect(r.message, 'Erreur GPS.');
      expect(r.position, isNull);
    });

    test('D4 : les cas exigés sont distinguables deux à deux (état ET message)', () {
      final cas = <GpsResolution>[
        GpsResolver.fromMeasuredPosition(_northOf(_user, 10)), // position obtenue (en zone)
        GpsResolver.permissionDenied(forever: false), // refusée
        GpsResolver.permissionDenied(forever: true), // refusée définitivement
        GpsResolver.error, // erreur GPS
      ];
      final messages = cas.map((r) => r.message).toSet();

      expect(messages, hasLength(4), reason: '4 messages distincts pour 4 cas distincts');
      expect(messages, containsAll(<String>[
        'Position GPS obtenue.',
        'Permission GPS refusée.',
        GpsResolver.deniedForeverMessage,
        'Erreur GPS.',
      ]));
      // `denied` et `deniedForever` ne doivent plus être confondus.
      expect(cas[1].state, isNot(cas[2].state));
    });

    test('les 3 états d\'erreur de la Carte 04 sont tous présents (aucun supprimé)', () {
      expect(GpsResolver.serviceDisabled.state, GpsState.serviceDisabled);
      expect(GpsResolver.permissionDenied(forever: false).state, GpsState.denied);
      expect(GpsResolver.error.state, GpsState.error);
    });

    test('règle 8 : GpsState conserve exactement ses 7 valeurs, aucun état ajouté', () {
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

  group('Groupe 4 — interruption du flux continu (F4)', () {
    test('position réelle déjà mesurée → conservée, pas détruite', () {
      final measured = _northOf(_user, 300);

      final r = GpsResolver.fromStreamInterrupted(measured);

      expect(r.state, GpsState.granted);
      expect(r.position, measured);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.message, 'Position GPS obtenue.');
      expect(r.isOutOfCoverage, isFalse, reason: 'mesure en zone de service');
    });

    test('aucune position mesurée → échec GPS explicite', () {
      final r = GpsResolver.fromStreamInterrupted(null);

      expect(r.state, GpsState.error);
      expect(r.position, isNull);
      expect(r.message, 'Erreur GPS.');
    });

    test('position hors du rectangle Dakar au moment de l\'interruption → conservée + message hors zone', () {
      const horsDakar = LatLng(15.5, -17.0);
      final r = GpsResolver.fromStreamInterrupted(horsDakar);

      expect(r.state, GpsState.granted);
      expect(r.position, horsDakar);
      expect(r.isSubstitutedPosition, isFalse);
      expect(r.isOutOfCoverage, isTrue);
      expect(r.message, GpsResolver.outOfCoverageMessage,
          reason: 'hors zone : message de couverture, pas « Position GPS obtenue. »');
    });

    test('position implausible au moment de l\'interruption → échec, jamais substituée', () {
      final r = GpsResolver.fromStreamInterrupted(const LatLng(0.0, 0.0));

      expect(r.state, GpsState.error);
      expect(r.position, isNull);
      expect(r.isSubstitutedPosition, isFalse);
    });

    test('réglages du flux prouvés (4A Carte 04 : B.Lf)', () {
      expect(GpsResolver.streamDistanceFilterMeters, 10, reason: 'distanceFilter: 10');
      expect(GpsResolver.streamTimeLimit, const Duration(seconds: 20),
          reason: 'timeLimit: 20 s (AVANT : 10 s sur getCurrentPosition)');
    });
  });

  group('Groupe 4 — F2 rayon 4000 m (écart #3)', () {
    test('la constante vaut 4000 m et plus 5000 m', () {
      expect(GpsResolver.nearbyRadiusMeters, 4000.0);
      expect(GpsResolver.nearbyRadiusMeters, isNot(5000.0));
    });

    test('arrêt à 3999,9 m → INCLUS dans le rayon', () {
      final proche = _stop('proche', _northOf(_user, 3999.9));
      final d = DistanceHelper.haversineMeters(_user, proche.location);
      expect(d, closeTo(3999.9, 0.01), reason: 'la fixture doit réellement être à 3999,9 m');
      expect(d, lessThan(GpsResolver.nearbyRadiusMeters));

      final result = GpsResolver.nearbyStops([proche], _user)!;

      expect(result, hasLength(1));
      expect(result.single.name, 'proche');
    });

    test('arrêt à 4000,1 m → EXCLU du rayon', () {
      final lointain = _stop('lointain', _northOf(_user, 4000.1));
      final d = DistanceHelper.haversineMeters(_user, lointain.location);
      expect(d, closeTo(4000.1, 0.01), reason: 'la fixture doit réellement être à 4000,1 m');
      expect(d, greaterThan(GpsResolver.nearbyRadiusMeters));

      final result = GpsResolver.nearbyStops([lointain], _user)!;

      expect(result, isEmpty);
    });

    test('le rayon sépare bien les deux arrêts encadrant le seuil', () {
      final dedans = _stop('dedans', _northOf(_user, 3999.9));
      final dehors = _stop('dehors', _northOf(_user, 4000.1));

      final result = GpsResolver.nearbyStops([dehors, dedans], _user)!;

      expect(result.map((s) => s.name).toList(), <String>['dedans']);
    });

    test('sans position réelle → aucune liste « à proximité » (null), rien de fabriqué', () {
      final s = _stop('x', _northOf(_user, 10));

      expect(GpsResolver.nearbyStops([s], null), isNull,
          reason: '§11 : pas de position réelle → pas de proximité calculée');
    });

    test('résultats triés par distance croissante depuis la position mesurée', () {
      final stops = <Stop>[
        _stop('a_2500', _northOf(_user, 2500)),
        _stop('b_100', _northOf(_user, 100)),
        _stop('c_1800', _northOf(_user, 1800)),
        _stop('d_50', _northOf(_user, 50)),
      ];

      final result = GpsResolver.nearbyStops(stops, _user)!;

      expect(result.map((s) => s.name).toList(), <String>['d_50', 'b_100', 'c_1800', 'a_2500']);
      final distances = result
          .map((s) => DistanceHelper.haversineMeters(_user, s.location))
          .toList();
      for (int i = 1; i < distances.length; i++) {
        expect(distances[i], greaterThanOrEqualTo(distances[i - 1]));
      }
    });

    test('la liste d\'entrée n\'est pas mutée par nearbyStops', () {
      final stops = <Stop>[
        _stop('a_2500', _northOf(_user, 2500)),
        _stop('b_100', _northOf(_user, 100)),
      ];

      GpsResolver.nearbyStops(stops, _user);

      expect(stops.map((s) => s.name).toList(), <String>['a_2500', 'b_100'],
          reason: 'nearbyStops trie une copie, pas la liste de l\'appelant');
    });
  });

  group('Groupe 4 — F3 plafond 30 résultats (écart #5)', () {
    test('la constante vaut 30 et plus 20', () {
      expect(GpsResolver.nearbyLimit, 30);
      expect(GpsResolver.nearbyLimit, isNot(20));
    });

    test('35 arrêts dans le rayon → exactement 30 renvoyés', () {
      final stops = <Stop>[
        for (int i = 1; i <= 35; i++) _stop('s$i', _northOf(_user, 100.0 * i)),
      ];
      // Toutes les fixtures sont bien à l'intérieur du rayon de 4000 m.
      for (final s in stops) {
        expect(DistanceHelper.haversineMeters(_user, s.location),
            lessThan(GpsResolver.nearbyRadiusMeters));
      }

      final result = GpsResolver.nearbyStops(stops, _user)!;

      expect(result, hasLength(30), reason: 'AVANT le Groupe 4 : 20');
      expect(stops, hasLength(35), reason: 'la fixture contient bien plus que le plafond');
    });

    test('les 30 renvoyés sont les 30 PLUS PROCHES (les 5 plus lointains exclus)', () {
      final stops = <Stop>[
        for (int i = 1; i <= 35; i++) _stop('s$i', _northOf(_user, 100.0 * i)),
      ];

      final result = GpsResolver.nearbyStops(stops, _user)!;
      final names = result.map((s) => s.name).toSet();

      for (int i = 1; i <= 30; i++) {
        expect(names, contains('s$i'), reason: 's$i (à ${100 * i} m) doit être retenu');
      }
      for (int i = 31; i <= 35; i++) {
        expect(names, isNot(contains('s$i')), reason: 's$i (à ${100 * i} m) doit être exclu');
      }
      expect(result.first.name, 's1');
      expect(result.last.name, 's30');
    });

    test('moins de 30 arrêts dans le rayon → tous renvoyés, aucun remplissage', () {
      final stops = <Stop>[
        for (int i = 1; i <= 5; i++) _stop('s$i', _northOf(_user, 100.0 * i)),
      ];

      final result = GpsResolver.nearbyStops(stops, _user)!;

      expect(result, hasLength(5), reason: 'règle 8 : aucun arrêt artificiel ajouté');
    });

    test('aucun arrêt dans le rayon → liste vide, jamais de substitution', () {
      final loin = _stop('loin', _northOf(_user, 9000));
      expect(DistanceHelper.haversineMeters(_user, loin.location),
          greaterThan(GpsResolver.nearbyRadiusMeters));

      final result = GpsResolver.nearbyStops([loin], _user)!;

      expect(result, isEmpty);
    });
  });

  group('Groupe 4 — F6 garde-fou REAL_TIME (test g, Carte 14)', () {
    test('DataStatus conserve exactement les 4 valeurs du contrat du bridge', () {
      expect(DataStatus.values, hasLength(4));
      expect(DataStatus.values.map((s) => s.name).toList(),
          <String>['scheduled', 'live', 'unknown', 'estimated']);
      expect(departureDataStatus(network.ScheduleStatus.scheduled), DataStatus.scheduled);
      expect(departureDataStatus(network.ScheduleStatus.estimated), DataStatus.estimated);
      expect(departureDataStatus(network.ScheduleStatus.unknown), DataStatus.unknown);
      expect(departureDataStatus(network.ScheduleStatus.realTime), DataStatus.live);
    });

    test('le resolver GPS n\'expose AUCUN DataStatus (aucun statut produit par le GPS)', () {
      // §16 : « jamais REAL_TIME » à partir d'une position. La couture GPS ne
      // manipule aucun statut de donnée : elle ne renvoie qu'un état GPS, une
      // position et un message.
      final r = GpsResolver.fromMeasuredPosition(_northOf(_user, 10));
      expect(r, isA<GpsResolution>());
      expect(r.hasRealPosition, isTrue);
      // Aucun accesseur de GpsResolution ne peut renvoyer un DataStatus :
      // ses seuls champs publics sont state, position, message,
      // isSubstitutedPosition, et son seul getter est hasRealPosition (bool).
      expect(r.isSubstitutedPosition, isA<bool>());
      expect(r.hasRealPosition, isA<bool>());
      expect(r.state, isA<GpsState>());
      expect(r.message, isA<String>());
    });

    test('GARDE-FOU SOURCE : live reste limité au mapping de type explicite', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());
      final mapping = RegExp(
          r'DataStatus departureDataStatus\(ScheduleStatus status\)\s*\{[\s\S]*?\n\}')
          .allMatches(code).toList();
      expect(mapping, hasLength(1));
      // Whitelist the COMPLETE pure function, not any arbitrary block containing
      // DataStatus.live. Any extra assignment/branch requires review.
      const expected = '''
DataStatus departureDataStatus(ScheduleStatus status) {
  switch (status) {
    case ScheduleStatus.scheduled: return DataStatus.scheduled;
    case ScheduleStatus.estimated: return DataStatus.estimated;
    case ScheduleStatus.realTime: return DataStatus.live;
    case ScheduleStatus.unknown: return DataStatus.unknown;
  }
}
''';
      String compact(String value) => value.replaceAll(RegExp(r'\s+'), '');
      expect(compact(mapping.single.group(0)!), compact(expected));
      final outsideMapping = code.replaceRange(mapping.single.start, mapping.single.end, '');
      expect(outsideMapping.contains('DataStatus.live'), isFalse,
          reason: 'aucune production directe de live hors du mapping contrôlé');
    });

    test('GARDE-FOU PRODUCTION : bootstrap et réseau embarqué sans live', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final boot = await bootstrapCetudFeedLayer(now: saturday0730);
      expect(boot.layerStatus, CetudLayerStatus.absent);
      expect(boot.provider.sources, isEmpty,
          reason: 'aucune source véhicule réelle branchée actuellement');
      final data = DataService();
      await data.loadNetworkData();
      expect(data.routes, hasLength(105), reason: 'asset réel, pas le fallback');
      data.departureAdapter = DepartureAdapter(boot.provider);
      for (final route in data.routes) {
        expect(route.scheduleStatus, isNot(network.ScheduleStatus.realTime));
        for (final stopId in route.stopIds) {
          final info = data.departureFor(network: route.operatorId,
              routeId: route.id, stopId: stopId);
          expect(departureDataStatus(info.status), DataStatus.unknown);
          expect(info.scheduledTime, isNull);
          expect(info.estimatedWaitTo, isNull, reason: 'aucun ETA inventé');
        }
      }
    });

    test('GARDE-FOU MOTEUR : statique, fréquence et faux REAL_TIME ne produisent pas live', () {
      final feed = GtfsFeed.fromTexts(aftuTexts, cetudProvenance('AFTU'), network: 'AFTU');
      final sources = <gtfs.ScheduleSource>[
        gtfs.GtfsScheduleService(feed),
        FrequencySource([FrequencyEntry(network: 'AFTU', lineNumber: '30',
          routeIds: ['TEST_AFTU_R30'], headwayMinutes: 10,
          from: '06:00', to: '21:00')], cetudProvenance('AFTU')),
        _UnobservedRealtimeSource(feed),
      ];
      final expected = [DataStatus.scheduled, DataStatus.estimated, DataStatus.unknown];
      for (var i = 0; i < sources.length; i++) {
        final provider = TransitDataProvider(now: saturday0730);
        provider.registerSource(sources[i], role: sources[i].kind == 'frequency'
            ? ProviderRoles.currentFrequency : ProviderRoles.currentOfficial);
        final data = DataService()..departureAdapter = DepartureAdapter(provider, bindings: [
          const DepartureBinding(network: 'AFTU', routeId: 'TEST_LINE',
            stopId: 'TEST_STOP', providerRouteId: 'TEST_AFTU_R30',
            providerStopId: 'TEST_S_Y', frequencyAppliesAtStop: true),
        ]);
        final info = data.departureFor(network: 'AFTU', routeId: 'TEST_LINE', stopId: 'TEST_STOP');
        expect(departureDataStatus(info.status), expected[i]);
        expect(departureDataStatus(info.status), isNot(DataStatus.live));
        expect(info.label, isNot(contains('Temps réel')));
        if (i == 1) {
          expect(info.scheduledTime, isNull);
          expect(info.estimatedWaitFrom, 0);
          expect(info.estimatedWaitTo, 10);
        }
        if (i == 2) {
          expect(provider.getDepartures('TEST_AFTU_R30', 'TEST_S_Y').isCurrent, isFalse);
          expect(info.estimatedWaitTo, isNull, reason: 'ETA fictif refusé');
        }
      }
    });

    test('GARDE-FOU SOURCE : aucune position GPS fabriquée n\'est assignée à _userPosition', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());

      // 4A §16 : `_userPosition = const LatLng(14.7167, -17.4677)` avec état
      // `granted`. Toute affectation d'un littéral LatLng est interdite.
      expect(RegExp(r'_userPosition\s*=\s*const\s+LatLng').hasMatch(code), isFalse,
          reason: 'D1-i : ne pas conserver LatLng(14.7167,-17.4677) comme position GPS');
      expect(RegExp(r'_userPosition\s*=\s*LatLng\s*\(').hasMatch(code), isFalse,
          reason: 'D1-i : aucune coordonnée littérale comme position utilisateur');
      expect(code.contains('_userPosition = r.position'), isTrue,
          reason: 'la seule affectation admise provient de la décision pure du resolver');
    });

    test('GARDE-FOU SOURCE : le rayon 5000 m et le plafond take(20) ont disparu du chemin GPS', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());

      expect(code.contains('< 5000'), isFalse, reason: 'écart #3 corrigé : rayon 4000 m');
      expect(RegExp(r'nearbyStops').hasMatch(code), isTrue,
          reason: 'le calcul de proximité passe par la couture pure testée');
      expect(RegExp(r'GpsResolver\.nearbyLimit').hasMatch(code), isTrue,
          reason: 'écart #5 corrigé : plafond 30 via la constante prouvée');
    });

    test('GARDE-FOU SOURCE : la souscription au flux continu est annulée (aucune fuite)', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());

      expect(code.contains('StreamSubscription<Position>? _positionSub'), isTrue,
          reason: 'règle générale n°9 : le flux continu est introduit');
      expect(code.contains('_positionSub?.cancel()'), isTrue,
          reason: 'règle générale n°9 : vérification d\'absence de fuite de subscription');

      // Le cancel doit figurer dans dispose(), avant super.dispose().
      final disposeIdx = code.indexOf('void dispose() {');
      expect(disposeIdx, greaterThan(-1), reason: '_MainShellState.dispose existe');
      final body = code.substring(disposeIdx, code.indexOf('}', code.indexOf('super.dispose()', disposeIdx)));
      expect(body.contains('_positionSub?.cancel()'), isTrue,
          reason: 'l\'annulation doit être dans dispose(), pas seulement avant re-souscription');
      expect(body.contains('_ticker?.cancel()'), isTrue,
          reason: 'le ticker préexistant reste annulé (Groupes 1-3 non régressés)');
      expect(body.indexOf('_positionSub?.cancel()'), lessThan(body.indexOf('super.dispose()')),
          reason: 'annulation AVANT super.dispose()');
    });

    test('GARDE-FOU SOURCE : le flux continu remplace l\'appel ponctuel', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());

      expect(code.contains('Geolocator.getPositionStream'), isTrue,
          reason: '4A Carte 04 : flux continu');
      expect(code.contains('Geolocator.getCurrentPosition'), isFalse,
          reason: 'l\'appel ponctuel est remplacé, pas conservé en doublon');
      expect(RegExp(r'locationSettings:\s*const\s+LocationSettings').hasMatch(code), isTrue,
          reason: '4A Carte 04 : `getPositionStream(locationSettings: B.Lf)`');
      expect(RegExp(r'distanceFilter:\s*GpsResolver\.streamDistanceFilterMeters').hasMatch(code),
          isTrue);
      expect(RegExp(r'timeLimit:\s*GpsResolver\.streamTimeLimit').hasMatch(code), isTrue);
    });

    test('GARDE-FOU SOURCE : les 4 messages GPS sont rendus visibles (F5, D4-i)', () {
      final code = _stripComments(File('lib/main.dart').readAsStringSync());

      // Le champ était transmis à ExplorerPage mais jamais lu dans aucun build.
      expect(code.contains('widget.gpsMessage'), isTrue,
          reason: 'D4-i : le message déjà produit est rendu visible');
      expect(RegExp(r'if\s*\(\s*widget\.gpsMessage\s*!=\s*null\s*\)').hasMatch(code), isTrue,
          reason: 'bandeau persistant affiché tant qu\'un message existe (§16)');
      expect(code.contains('Text(widget.gpsMessage!'), isTrue,
          reason: 'le texte du message est affiché');
    });
  });

  group('Groupe 4 — invariants de périmètre (règles 4, 6, 8)', () {
    test('règle 6 : le JSON actif est strictement inchangé et TER = 13 gares', () {
      final file = File('assets/data/dakar_network.json');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      // AUDIT DONNÉES 2026-09-24 — AVANT : 59189 octets (sha256 e59f05b0…).
      // APRÈS (audit données) : 159627 octets (sha256 9ba63618…). RAISON : ce verrou garantit
      // qu'un correctif d'INTERFACE ne touche pas aux données. Le commit
      // « fix(data): audit and provenance » modifie volontairement le JSON
      // (champs de provenance ajoutés, séquence B2 corrigée ; 117 arrêts,
      // 105 lignes, 5 opérateurs et coordonnées inchangés). Le verrou est
      // conservé à la nouvelle valeur. Voir docs/AUDIT_DONNEES_2026-09-24.md.
      //
      // §9-1 — APRÈS : 166370 octets (sha256 c08389ac…). RAISON : le lot §9-1
      // ajoute quatre champs d'identifiant officiel, en AJOUT SEUL, sur
      // exactement 22 routes Tata/DDD (7 Tata + 15 DDD) : +88 lignes, aucune
      // ligne supprimée. Aucune donnée préexistante n'est modifiée (105 lignes,
      // 117 arrêts, 5 opérateurs, coordonnées, géométrie et arrêts inchangés).
      // Voir docs/ETAPE_3A_AUDIT_IDENTIFIANTS_TATA_DDD_2026-09-25.md §9-1/§12.
      expect(bytes.length, 166370,
          reason: 'taille du JSON actif verrouillée après l’audit données 2026-09-24, '
              'révisée par le lot §9-1 (sha256 c08389ac…)');

      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final stops = (data['stops'] as List).cast<Map<String, dynamic>>();
      final routes = (data['routes'] as List).cast<Map<String, dynamic>>();
      expect(stops, hasLength(117), reason: '117 arrêts dans la source unique de vérité');
      expect(routes, hasLength(105), reason: '105 lignes dans la source unique de vérité');

      // §6 : les 13 gares TER, dans l'ordre exact, de `stop_dakar_ter` à
      // `stop_diamniadio`.
      //
      // PRÉCISION IMPORTANTE — l'assertion « Keur Massar absent du JSON » serait
      // FAUSSE : Keur Massar existe légitimement dans la source unique de
      // vérité comme ARRÊT DE BUS (`stop_keur_massar`, `stop_jaxaay`,
      // `stop_keur_massar_nord`, `stop_malika`). §6 interdit uniquement qu'il
      // réapparaisse comme **gare TER**. Le garde-fou porte donc sur la route
      // TER, pas sur le fichier entier.
      final ter = routes.where((r) => r['operator_id'] == 'ter').toList();
      expect(ter, hasLength(1), reason: 'une seule ligne TER dans le JSON');

      final terStops = (ter.single['stops'] as List).cast<String>();
      expect(terStops, hasLength(13), reason: '§6 : TER = 13 gares, jamais supprimées');
      expect(terStops.first, 'stop_dakar_ter', reason: '§6 : 1re gare');
      expect(terStops.last, 'stop_diamniadio', reason: '§6 : dernière gare');
      expect(terStops.where((id) => id.contains('keur_massar')), isEmpty,
          reason: '§6 : Keur Massar ne doit jamais réapparaître comme gare TER');

      final nameOf = <String, String>{
        for (final s in stops) s['id'] as String: s['name'] as String,
      };
      final terNames = terStops.map((id) => nameOf[id] ?? id).toList();
      expect(terNames.where((n) => n.contains('Keur Massar')), isEmpty,
          reason: '§6 : aucune gare TER nommée Keur Massar');
      expect(terNames.first, 'Gare TER Dakar');
      expect(terNames.last, 'Diamniadio - Gare TER Terminus');
    });

    test('règle 8 : aucune donnée inventée — le resolver ne crée ni arrêt ni coordonnée', () {
      // `nearbyStops` ne peut renvoyer que des objets présents dans l'entrée.
      final entree = <Stop>[
        _stop('a', _northOf(_user, 100)),
        _stop('b', _northOf(_user, 200)),
        _stop('hors', _northOf(_user, 9000)),
      ];

      final result = GpsResolver.nearbyStops(entree, _user)!;

      for (final s in result) {
        expect(entree.map((e) => e.name), contains(s.name),
            reason: 'chaque résultat provient de la liste fournie');
      }
      expect(result.map((s) => s.name).toSet().difference(entree.map((e) => e.name).toSet()),
          isEmpty);
    });

    test('les valeurs GPS prouvées sont les seules exposées par GpsResolver', () {
      // Garde contre l'introduction silencieuse d'un nouveau seuil (§20 : pas
      // d'alerte 5/10/15 min inventée ; D2 : « ne change aucun autre seuil »).
      expect(GpsResolver.nearbyRadiusMeters, 4000.0);
      expect(GpsResolver.nearbyLimit, 30);
      expect(GpsResolver.streamDistanceFilterMeters, 10);
      expect(GpsResolver.streamTimeLimit, const Duration(seconds: 20));
    });
  });
}
