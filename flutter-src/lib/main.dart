import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'models/transport_network.dart';
import 'models/reliability.dart';
import 'models/departure_info.dart';
import 'services/data_service.dart';

// ============================================================
// SERVICE GLOBAL RESEAU DAKAR — Connecté à assets/data/dakar_network.json
// ============================================================
final DataService appDataService = DataService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('🔴 FlutterError: ${details.exception}');
    debugPrint('${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Platform error: $error');
    debugPrint('$stack');
    return true;
  };
  try {
    await appDataService.loadNetworkData();
    _integrateNetworkData();
  } catch (e, st) {
    debugPrint('⚠️ DataService init failed: $e');
    debugPrint('$st');
  }
  runZonedGuarded(() {
    runApp(const DakarBusApp());
  }, (error, stack) {
    debugPrint('🔴 Uncaught zone error: $error');
    debugPrint('$stack');
  });
}

// ============================================================
// NOTIFIER GLOBAL POUR LE MODE SOMBRE & FAVORIS
// ============================================================
class AppStateNotifier extends ChangeNotifier {
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void toggleDarkMode(bool value) { _darkMode = value; notifyListeners(); }

  final Set<String> _favoriteStopNames = {};
  Set<String> get favoriteStopNames => _favoriteStopNames;

  bool isFavorite(String name) => _favoriteStopNames.contains(name);

  void toggleFavorite(String name) {
    if (_favoriteStopNames.contains(name)) {
      _favoriteStopNames.remove(name);
    } else {
      _favoriteStopNames.add(name);
    }
    notifyListeners();
  }
}

final AppStateNotifier globalState = AppStateNotifier();

// ============================================================
// GEOFENCING STRICT TERRE FERME DAKAR (ANTI-OCEAN)
// ============================================================
/// Garde-fou géographique de la région de Dakar.
///
/// GROUPE 1 (Step 4B) — aligné sur la DONNÉE ACTIVE.
///
/// AVANT : nord 14.7900, sud 14.6500, est -17.1500, ouest -17.5500, plus un
///         rectangle d'exclusion dit « zone océan »
///         (lat 14.7000-14.7450 × lon -17.4350 à -17.3750).
///
/// RAISON DU CHANGEMENT : ce rectangle rejetait 4 des 117 arrêts actifs, dont
///         TROIS DES 13 GARES TER que le §6 interdit de supprimer :
///           - stop_hann             « Hann - Maristes / TER »      14.72209, -17.43207
///           - stop_dalifort_ter     « Dalifort - Gare TER »        14.73425, -17.41900
///           - stop_baux_maraichers  « Baux Maraîchers - TER »      14.73971, -17.40361
///         et la borne nord 14.7900 rejetait stop_malika (14.80150, -17.33760).
///         La zone qualifiée d'« océan » couvre en réalité le corridor
///         ferroviaire Dakar-Diamniadio à l'est du centre-ville.
///
/// SOURCE DE PREUVE : le validateur `eI` du binaire de production
///         (gh-pages 94a84b60, main.dart.js) porte le commentaire de son
///         propre auteur :
///           « v4 : rectangle d'exclusion Hann/Dalifort retire (il couvrait
///             3 gares TER officielles : Hann, Dalifort, Baux Maraichers).
///             Garde-fou Dakar inchange. »
///         Les trois gares qu'il nomme sont exactement celles recalculées
///         indépendamment ici. Les bornes production lues dans ce même
///         validateur sont 14.55 / 14.9 / -17.6 / -16.85.
///
/// DIVERGENCE ASSUMÉE vis-à-vis de la production : le garde (0,0) est CONSERVÉ
///         alors que `eI` ne l'a pas. Aucune donnée active n'est concernée
///         (latitude minimale réelle 14.6738), et le §11 interdit de traiter
///         une position absente comme une position valable. Le conserver est
///         strictement plus sûr et ne contredit aucune donnée active.
///
/// PÉRIMÈTRE (correctif position utilisateur) : [DakarBounds] est le garde-fou
///         des **données réseau** (arrêts, tracés) uniquement. Il n'est plus
///         appliqué à la position mesurée de l'utilisateur, qui relève de
///         [PositionValidity] : un utilisateur à Thiès, Rufisque ou
///         Saint-Louis a une position réelle, elle est conservée telle quelle.
class DakarBounds {
  static const double north = 14.9;
  static const double south = 14.55;
  static const double east = -16.85;
  static const double west = -17.6;

  static bool isValid(LatLng location) {
    return location.latitude >= south &&
        location.latitude <= north &&
        location.longitude >= west &&
        location.longitude <= east &&
        location.latitude != 0.0 &&
        location.longitude != 0.0;
  }
}

/// Plausibilité géodésique d'une **position utilisateur mesurée**.
///
/// AVANT : la position GPS était soumise à [DakarBounds] ; toute mesure hors
///         du rectangle Dakar (Thiès, Rufisque-est, Saint-Louis, …) était
///         rejetée avec « Position hors zone, recentré sur Dakar. » alors
///         qu'elle était **réelle**. Un utilisateur réel hors de Dakar n'avait
///         donc jamais de position.
///
/// APRÈS : seule la plausibilité géodésique est vérifiée. Toute position
///         mesurée plausible est conservée **telle quelle, où qu'elle soit**.
///         Le principe §11 / D1-i est intact : aucune position absente ou
///         fabriquée n'est exposée — sont rejetées uniquement :
///           - l'« île nulle » (0, 0), valeur par défaut d'un géolocaliseur
///             muet, jamais une mesure réelle ;
///           - les latitudes hors [-90, 90] et longitudes hors [-180, 180] ;
///           - NaN / infini.
///         Ces cas sont des **échecs de mesure** et produisent « Erreur GPS. »
///
/// [DakarBounds] reste le garde-fou des données réseau (arrêts, tracés).
///
/// Note : `LatLng` (latlong2 0.9) vérifie déjà les bornes par `assert` en mode
/// debug ; les asserts étant absents en release, le contrôle est refait ici
/// sur les doubles bruts ([isPlausibleCoordinates]) — c'est aussi ce qui le
/// rend testable sans construire un `LatLng` invalide.
class PositionValidity {
  static bool isPlausibleCoordinates(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) {
      return false;
    }
    if (lat.abs() > 90.0 || lon.abs() > 180.0) return false;
    if (lat == 0.0 && lon == 0.0) return false;
    return true;
  }

  static bool isPlausible(LatLng location) =>
      isPlausibleCoordinates(location.latitude, location.longitude);
}

// ============================================================
// SERVICE ROUTING REEL OSRM
// ============================================================
class RoutingService {
  static final Map<String, List<LatLng>> _cache = {};

  static String _cacheKey(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}|${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';

  static Future<List<LatLng>> getRealRoute(LatLng start, LatLng end) async {
    final key = _cacheKey(start, end);
    if (_cache.containsKey(key)) return _cache[key]!;

    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        final points = coordinates
            .map<LatLng>((dynamic coord) => LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ))
            .where((pt) => DakarBounds.isValid(pt))
            .toList();
        _cache[key] = points.isNotEmpty ? points : [start, end];
        return _cache[key]!;
      }
    } catch (_) {}

    final fallback = [start, end];
    _cache[key] = fallback;
    return fallback;
  }
}

// ============================================================
// SERVICE DE DETECTION DES DEUX SENS & INVERSION PROPRE
// ============================================================
/// Détection de l'arrêt situé en face, de l'autre côté de la voie — les deux
/// sens d'un même point physique.
///
/// GROUPE 3 (§10) — algorithme PROUVÉ du binaire de production `A.adD(a, b)`,
/// réintégré à l'identique, sans simplification (rapport 4A, Carte 03 :
/// « NE PAS simplifier l'algorithme d'arrêt opposé : les 2 passes sont
/// conservées intégralement »).
///
/// Les deux passes sont strictement ordonnées et indépendantes :
///   passe 1 — inclusion de nom dans les DEUX sens, à 120 m ou moins ;
///   passe 2 — même mode, direction différente, à 500 m ou moins.
/// La passe 2 n'est consultée que si la passe 1 n'a rien donné. Elles ne sont
/// JAMAIS fusionnées (Carte 03, ligne 10).
///
/// Contrat : la fonction retourne `null` quand aucune correspondance fiable
/// n'existe. Elle ne force jamais de correspondance, n'élargit jamais un seuil
/// et ne crée jamais d'arrêt de substitution (§12).
class OppositeStopService {
  /// Passe 1 — seuil de correspondance de nom, en mètres.
  ///
  /// AVANT : 50.0, littéral anonyme écrit en ligne dans la boucle.
  /// APRÈS : 120.0, constante nommée.
  /// PREUVE : le binaire de production compare à 120 puis à 500 (rapport 4A,
  ///   Carte 03, ligne « 6. Preuve » : extrait `adD(a,b)` @ ~188500,
  ///   `k = A.ew(b.r, m.r)`, comparaison à 120 puis 500). La Carte 03 isole
  ///   précisément cet écart (« 4. Différence : seuil de la passe 1 :
  ///   50 m → 120 m ») et conclut (« 8. Décision ») : « À RÉINTÉGRER à 120 m —
  ///   sans simplifier l'algorithme ».
  /// RAISON : il ne s'agit donc pas d'un élargissement décidé ici, mais du
  ///   rétablissement de la valeur de production. Aucun seuil n'est porté
  ///   au-delà de 120 m / 500 m : une correspondance qui échoue reste un
  ///   échec, jamais un repli inventé (§12).
  static const double _maxNameMatchDistanceMeters = 120.0;

  /// Passe 2 — seuil « même mode, direction opposée », en mètres.
  /// Valeur PROUVÉE : 500 m dans `A.adD` (rapport 4A, Carte 03). Inchangée.
  static const double _maxOppositeDistanceMeters = 500.0;

  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    // ---- PASSE 1 : inclusion de nom dans les deux sens, à 120 m ou moins ----
    // L'inclusion réciproque (`a contient b` OU `b contient a`) est conservée
    // telle quelle : la Carte 03 interdit explicitement de la remplacer par une
    // égalité stricte (« 12. Ne pas modifier »). Elle apparie les libellés
    // croisés du type « X - BRT » / « BRT X ».
    for (final stop in allStops) {
      if (identical(stop, currentStop)) continue;
      // Même nom ET même direction : c'est la même entrée physique, pas son
      // vis-à-vis. Exclusion conservée de la source existante.
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= _maxNameMatchDistanceMeters && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }
    // La passe 1 a priorité absolue : si elle aboutit, la passe 2 n'est pas
    // consultée. Les deux passes ne sont jamais fusionnées (Carte 03).
    if (bestCandidate != null) return bestCandidate;

    // ---- PASSE 2 : même mode, direction différente, à 500 m ou moins --------
    for (final stop in allStops) {
      if (identical(stop, currentStop)) continue;
      if (stop.modeLabel != currentStop.modeLabel) continue;
      if (stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= _maxOppositeDistanceMeters && distance < minDistance) {
        minDistance = distance;
        bestCandidate = stop;
      }
    }
    // Aucune des deux passes n'a abouti : `null`. C'est un « inconnu » (§12),
    // jamais un arrêt de substitution. Il appartient à l'appelant de le traiter
    // comme tel — en aucun cas de fabriquer un vis-à-vis.
    return bestCandidate;
  }
}

// ============================================================
// HORAIRES — AUCUN GÉNÉRATEUR (audit données 2026-09-24)
// ============================================================
// AVANT : `_generateSchedule` / `_shift` fabriquaient des départs TER toutes
//         les 10 min (20 le dimanche) de 5 h 30 à 22 h, BRT toutes les 6 min
//         de 6 h à 21 h, décalés de 2 min par arrêt, et AFTU/DDD/Tata
//         affichaient « En rotation (~5 min) ».
// APRÈS : supprimé. `dakar_network.json` ne contient AUCUN horaire
//         (`schedule_status: UNKNOWN` sur les 105 routes) : l'interface
//         affiche « Horaire indisponible » (voir [ReliabilityLabel]).

// ============================================================
// PALETTE OFFICIELLE DES TRANSPORTS & THEME MANAGER
// ============================================================
class AppColors {
  static const primary = Color(0xFF00B140);
  static const primaryDark = Color(0xFF008A32);
  static const ter = Color(0xFF8B4513);
  static const brt = Color(0xFF22C55E);
  static const aftu = Color(0xFFFF8C42);
  static const tata = Color(0xFF87CEEB);
  static const ddd = Color(0xFF3B82F6);

  static Color background(bool dark) => dark ? const Color(0xFF121212) : const Color(0xFFF1F8F5);
  static Color surface(bool dark) => dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color textPrimary(bool dark) => dark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
  static Color textSecondary(bool dark) => dark ? const Color(0xFFAAAAAA) : const Color(0xFF555555);
  static Color divider(bool dark) => dark ? const Color(0xFF2C2C2C) : const Color(0xFFD4EDE2);

  static const success = Color(0xFF00B140);
  static const warning = Color(0xFFEF6C00);
}

// ============================================================
// SOURCE DE DONNEES & STATUT
// ============================================================
enum DataOrigin { official, verified, indicative, unavailable }
class DataSourceInfo {
  final DataOrigin origin; final String label; final String badgeEmoji;
  const DataSourceInfo({required this.origin, required this.label, required this.badgeEmoji});
  static const seter = DataSourceInfo(origin: DataOrigin.official, label: 'SETER (Officiel)', badgeEmoji: '🟢');
  static const sunubrt = DataSourceInfo(origin: DataOrigin.official, label: 'SunuBRT (Officiel)', badgeEmoji: '🟢');
  // Audit données 2026-09-24 : aucune route DDD, AFTU ou Tata n'est CONFIRMED
  // (DDD : contredites par demdikk.sn ou absentes ; AFTU/Tata : observations
  // terrain). Ces sources ne portent donc plus « (Officiel) » ni la pastille
  // 🟢/🔵 : elles sont indicatives (🟡). Identifiants conservés (API interne).
  static const demdikk = DataSourceInfo(origin: DataOrigin.indicative, label: 'Dakar Dem Dikk (non vérifié)', badgeEmoji: '🟡');
  static const tataOfficial = DataSourceInfo(origin: DataOrigin.indicative, label: 'Bus TATA (observation terrain, non vérifiée)', badgeEmoji: '🟡');
  static const aftuOfficial = DataSourceInfo(origin: DataOrigin.indicative, label: 'AFTU (itinéraires non vérifiés)', badgeEmoji: '🟡');
  /// Donnée dont la provenance n'est pas CONFIRMED (UNVERIFIED / CONFLICTING).
  static const unverified = DataSourceInfo(origin: DataOrigin.indicative, label: 'Donnée non vérifiée', badgeEmoji: '🟡');
  static const demo = DataSourceInfo(origin: DataOrigin.indicative, label: 'Donnée Indicative (~)', badgeEmoji: '🟡');
}

// ============================================================
// MODELES DE DONNEES ET ROUTES DETAILLEES OFFICIELLES
// ============================================================
enum StopType { arrival, departure, boarding, terminus, correspondence, intermediate }

/// Un arrêt tel qu'affiché dans la fiche détaillée d'une ligne.
///
/// GROUPE 2 (§8) — modèle aligné sur la production.
/// AVANT : 8 champs (stopId, name, sequence, location, distanceFromStart,
///         estimatedTime, isTerminal, type).
/// APRÈS : 5 champs (stopId, name, location, distanceFromStart, estimatedTime),
///         soit exactement le modèle du binaire de production (faisceau `aOu`,
///         rapport 4A §12.2).
/// RAISON : `sequence`, `isTerminal` et `type` n'étaient lus NULLE PART dans
///         l'application (vérifié : 0 occurrence de `.sequence` et `.isTerminal`
///         hors déclaration ; le `.type` restant appartient à `TransitRoute` et
///         `TransportRoute`). Le numéro d'ordre affiché est déjà dérivé de
///         l'index de la liste par `DetailedRoutePage` (`route.stops.asMap()`
///         puis `idx + 1`). Les supprimer ne modifie donc aucun rendu (§21
///         respecté) et retire trois valeurs que l'ancien `fromStop` fabriquait
///         à la main.
class DetailedStop {
  /// Identifiant métier dans `dakar_network.json` (ex. `stop_dakar_ter`).
  final String stopId;
  final String name;
  final LatLng location;

  /// Distance cumulée depuis le PREMIER arrêt de la ligne, au format « N.N km ».
  /// Calculée — jamais codée en dur (§9).
  final String distanceFromStart;

  /// Estimation du temps écoulé depuis le premier arrêt, au format « ~N min ».
  /// Le tilde marque explicitement l'approximation (§12 : aucune donnée
  /// présentée comme certaine). `dakar_network.json` ne contient aucun horaire
  /// d'arrêt intermédiaire : aucune heure n'est donc inventée. L'ancien code
  /// produisait des pseudo-heures `i * 4` / `i * 6` au format « HH:00 »,
  /// invalides dès que l'indice dépassait 23 (jusqu'à « 88:00 »).
  final String estimatedTime;

  const DetailedStop({
    required this.stopId,
    required this.name,
    required this.location,
    required this.distanceFromStart,
    required this.estimatedTime,
  });
}

class DetailedRoute {
  final String routeId;
  /// Numéro de ligne extrait du `short_name` JSON (ex. « BRT B1 » donne 1).
  /// `null` quand le code ne contient aucun chiffre (ex. « TER ») : aucun
  /// numéro n'est inventé (§12). Ce champ n'est lu par aucune vue.
  final int? lineNumber;
  final String operator;
  final Color color;
  String origin;
  String destination;
  final String totalDistance;
  final List<DetailedStop> stops;

  /// Provenance de la ligne dans le JSON (audit 2026-09-24). Absente →
  /// UNVERIFIED. Détermine, avec celle de chaque arrêt, le badge affiché.
  final ProvenanceStatus dataStatus;

  /// Provenance de chaque arrêt, par `stopId` (audit 2026-09-24). Gardée ici
  /// pour laisser `DetailedStop` à ses 5 champs de production. Arrêt absent
  /// → UNVERIFIED : un arrêt n'est jamais présumé confirmé.
  final Map<String, ProvenanceStatus> stopStatuses;

  DetailedRoute({
    required this.routeId,
    required this.lineNumber,
    required this.operator,
    required this.color,
    required this.origin,
    required this.destination,
    required this.totalDistance,
    required this.stops,
    this.dataStatus = ProvenanceStatus.unverified,
    this.stopStatuses = const <String, ProvenanceStatus>{},
  });

  /// Badge de fiabilité d'un arrêt DANS cette ligne : le moins sûr des deux
  /// statuts (ligne, arrêt). « OFFICIEL » seulement si les deux sont CONFIRMED.
  ProvenanceStatus statusOf(DetailedStop stop) =>
      ReliabilityLabel.combine(<ProvenanceStatus>[
        dataStatus,
        stopStatuses[stop.stopId] ?? ProvenanceStatus.unverified,
      ]);

  /// Seuil de résolution géographique d'un arrêt, en mètres.
  ///
  /// Valeur PROUVÉE : c'est celle du faisceau `aS1` du binaire de production
  /// (rapport 4A §12.1). Elle n'est pas élargie ici pour faire aboutir une
  /// résolution qui échoue : un échec reste un « inconnu » (§12) et non un
  /// arrêt de substitution.
  static const double kMaxResolveMeters = 250.0;

  /// Estimation du temps de parcours entre deux arrêts consécutifs, en minutes.
  ///
  /// Constante PROUVÉE du binaire de production (faisceau `aOu`, rapport 4A
  /// §12.2 : estimatedTime = "~" + (j * 3) + " min"). Elle est conservée telle
  /// quelle ; la seule correction appliquée est celle prescrite par 4A : le
  /// compteur démarre à 0 pour que le premier arrêt affiche « ~0 min » (la
  /// production affichait « ~3 min » au départ, ce qui est incohérent).
  static const int kMinutesPerStop = 3;

  /// Dérive la fiche d'une ligne depuis `dakar_network.json`, SOURCE UNIQUE (§8).
  ///
  /// AVANT : trois branches codées en dur. TER : 12 arrêts HISTORIQUES en
  ///         littéral. BRT : 11 arrêts HISTORIQUES en littéral, modèle
  ///         explicitement interdit par §7. Général : 3 arrêts dont un FABRIQUÉ
  ///         (« Station Intermédiaire » posé à `stop.location + 0.01`), donnée
  ///         inventée interdite par §12 et §30. Distances totales en littéraux
  ///         ('35.0 km', '14.0 km', '3.5 km'). Temps estimés `i * 4` / `i * 6`.
  /// APRÈS : algorithme du binaire de production (faisceau `aOu`, rapport 4A
  ///         §12.2) réimplémenté à l'identique, plus la correction 4A décrite
  ///         sur [kMinutesPerStop].
  /// RAISON : §8 impose que les arrêts d'une fiche ligne proviennent du JSON
  ///         courant, sans liste parallèle ; §9 impose de prouver la formule de
  ///         distance avant de l'afficher.
  ///
  /// FORMULE DE DISTANCE — PROUVÉE (§9) :
  ///   totalDistance = somme des haversine(arrêt_i, arrêt_i+1), R = 6371008.8 m
  ///   Vérifiée sur le JSON courant : TER = 34.6 km, BRT B1 = 17.5 km,
  ///   BRT B2 = 16.0 km — valeurs identiques à celles obtenues par simulation du
  ///   binaire de production (rapport 4A §9). Ce sont des sommes de cordes
  ///   géographiques, PAS des longueurs de voirie : la distance officielle du
  ///   corridor BRT annoncée par le CETUD est de 18.3 km. Les deux grandeurs
  ///   sont légitimes mais distinctes ; l'application affiche la grandeur
  ///   calculée à partir de la source unique.
  ///
  /// Retourne `null` lorsque la ligne ne peut pas être dérivée des données
  /// courantes : source non chargée, arrêt non résolu, ou ligne de moins de
  /// deux arrêts. Un `null` est un « inconnu » honnête (§12) ; il ne doit
  /// JAMAIS être remplacé par une fiche fabriquée.
  ///
  /// [reverse] produit la direction inverse par INVERSION de l'ordre courant du
  /// JSON (§6 pour le TER, §7 pour le BRT). Aucune seconde liste n'est créée.
  static DetailedRoute? fromStop(Stop stop, {bool reverse = false}) {
    final BusStop? json = _resolveJsonStop(stop);
    if (json == null) return null;

    // Lignes desservant cet arrêt, dans l'ordre du JSON (ordre canonique, §6).
    final List<TransportRoute> candidates = appDataService.routes
        .where((TransportRoute r) => r.stopIds.contains(json.id))
        .toList();
    if (candidates.isEmpty) return null;

    // Préférence d'exploitant. Un arrêt peut être desservi par plusieurs modes :
    // `stop_colobane` est desservi par 28 lignes (TER, DDD, AFTU et Tata). Sans
    // ce filtre, `aOu` ouvrirait la PREMIÈRE ligne trouvée — ici le TER — pour
    // un arrêt consulté en tant qu'arrêt DDD. Le repli sur `candidates.first`
    // conserve le comportement de production quand aucun exploitant ne
    // correspond.
    final String wanted = stop.modeLabel.toLowerCase();
    final List<TransportRoute> sameOperator =
        candidates.where((TransportRoute r) => r.operatorId == wanted).toList();
    return _build(
      sameOperator.isNotEmpty ? sameOperator.first : candidates.first,
      reverse: reverse,
    );
  }

  /// Dérive la fiche d'une ligne à partir de son exploitant, dans l'ordre du JSON.
  ///
  /// Utilisé par les suggestions de `TripsPage`. AVANT : ces suggestions
  /// passaient des `Stop` de démonstration codés en dur, dont les coordonnées
  /// sont héritées du JSON HISTORIQUE et ne correspondent plus aux arrêts
  /// ACTUELS. Cas prouvé : « PEM Guediawaye » (14.7735, -17.3977) est à 322 m
  /// du plus proche arrêt BRT actuel, au-delà du seuil de 250 m de `aS1` ; la
  /// résolution par proximité échouait donc, et la résolution par nom tombait à
  /// 0 m sur un arrêt homonyme « PEM Guédiawaye - Terminus BRT Nord » desservi
  /// uniquement par AFTU, DDD et Tata — jamais par le BRT. La dérivation par
  /// exploitant supprime toute résolution approximative.
  static DetailedRoute? fromOperator(String operatorId, {bool reverse = false}) {
    if (!appDataService.isLoaded) return null;
    final List<TransportRoute> candidates = appDataService.routes
        .where((TransportRoute r) => r.operatorId == operatorId)
        .toList();
    if (candidates.isEmpty) return null;
    return _build(candidates.first, reverse: reverse);
  }

  /// Cœur de la dérivation : séquence d'arrêts, distances cumulées, temps estimé.
  static DetailedRoute? _build(TransportRoute route, {bool reverse = false}) {
    // §6 / §7 : la direction inverse est l'inversion de l'ordre courant.
    final List<String> ids =
        reverse ? route.stopIds.reversed.toList() : route.stopIds;

    final List<DetailedStop> out = <DetailedStop>[];
    final Map<String, ProvenanceStatus> stopStatuses = <String, ProvenanceStatus>{};
    double cumulatedMeters = 0.0;
    LatLng? previous;

    for (final String sid in ids) {
      final List<BusStop> found =
          appDataService.stops.where((BusStop s) => s.id == sid).toList();
      // Arrêt référencé mais absent du JSON : on le saute sans interrompre la
      // ligne (comportement de `aOu`). Aucun arrêt de substitution n'est
      // inventé.
      if (found.isEmpty) continue;
      final BusStop s = found.first;
      final LatLng location = LatLng(s.latitude, s.longitude);
      if (previous != null) {
        cumulatedMeters += DistanceHelper.haversineMeters(previous, location);
      }
      final int elapsedMinutes = out.length * kMinutesPerStop;
      out.add(DetailedStop(
        stopId: s.id,
        name: s.name,
        location: location,
        distanceFromStart: '${(cumulatedMeters / 1000).toStringAsFixed(1)} km',
        estimatedTime: '~$elapsedMinutes min',
      ));
      stopStatuses[s.id] = s.provenance.status;
      previous = location;
    }

    // Moins de deux arrêts exploitables : aucune distance ne peut être calculée.
    if (out.length < 2) return null;

    final Operator? exploitant = appDataService.operatorForRoute(route);
    final String? digits =
        RegExp(r'(\d+)').firstMatch(route.shortName)?.group(1);

    return DetailedRoute(
      routeId: route.id,
      // `null` quand le code de ligne ne contient aucun chiffre (ex. « TER ») :
      // aucun numéro n'est inventé (§12). Ce champ n'est lu par aucune vue.
      lineNumber: digits == null ? null : int.tryParse(digits),
      operator: exploitant?.name ?? route.operatorId.toUpperCase(),
      color: _colorForOperatorId(route.operatorId),
      origin: out.first.name,
      destination: out.last.name,
      totalDistance: '${(cumulatedMeters / 1000).toStringAsFixed(1)} km',
      stops: out,
      dataStatus: route.provenance.status,
      stopStatuses: stopStatuses,
    );
  }

  /// Résout un `Stop` de l'application vers son arrêt dans `dakar_network.json`.
  ///
  /// Ordre de résolution, entièrement déterministe :
  ///  1. `stop.stopId`, quand l'arrêt provient déjà du JSON (cas nominal, c'est
  ///     la voie utilisée par `aOu` en production) ;
  ///  2. correspondance de NOM EXACT (le nom est déjà la clé de correspondance
  ///     retenue par §10 pour les arrêts opposés) ;
  ///  3. arrêt le plus proche à [kMaxResolveMeters] ou moins.
  ///
  /// Les étapes 2 et 3 sont restreintes aux arrêts desservis par le même
  /// exploitant que `stop.modeLabel`, quand ce mode correspond à un exploitant
  /// présent dans le JSON. Sans cette restriction, un arrêt de démonstration
  /// libellé BRT se résoudrait sur un homonyme desservi par d'autres modes et
  /// ouvrirait une ligne d'un autre mode.
  ///
  /// Retourne `null` si aucune résolution n'aboutit : c'est un « inconnu »
  /// (§12), jamais un arrêt inventé.
  static BusStop? _resolveJsonStop(Stop stop) {
    if (!appDataService.isLoaded) return null;
    final List<BusStop> all = appDataService.stops;
    if (all.isEmpty) return null;

    // 1. Identifiant métier : résolution exacte.
    final String? sid = stop.stopId;
    if (sid != null) {
      final List<BusStop> byId = all.where((BusStop s) => s.id == sid).toList();
      if (byId.isNotEmpty) return byId.first;
    }

    // Périmètre restreint au mode de l'arrêt consulté.
    final String wanted = stop.modeLabel.toLowerCase();
    final Set<String> idsOfOperator = <String>{
      for (final TransportRoute ligne in appDataService.routes
          .where((TransportRoute x) => x.operatorId == wanted)) ...ligne.stopIds,
    };
    final List<BusStop> scoped = idsOfOperator.isEmpty
        ? all
        : all.where((BusStop s) => idsOfOperator.contains(s.id)).toList();

    // 2. Correspondance de nom exacte.
    final List<BusStop> byName =
        scoped.where((BusStop s) => s.name == stop.name).toList();
    if (byName.isNotEmpty) return byName.first;

    // 3. Arrêt le plus proche, à kMaxResolveMeters ou moins.
    BusStop? nearest;
    double best = double.infinity;
    for (final BusStop s in scoped) {
      final double d = DistanceHelper.haversineMeters(
          stop.location, LatLng(s.latitude, s.longitude));
      if (d < best) {
        best = d;
        nearest = s;
      }
    }
    return (nearest != null && best <= kMaxResolveMeters) ? nearest : null;
  }

  /// Couleur de la ligne. Les couleurs de l'interface sont conservées à
  /// l'identique (§21) : ce sont les constantes `AppColors` déjà employées par
  /// `_integrateNetworkData`, et non les `colorHex` du JSON. Les deux
  /// coïncident d'ailleurs pour les deux modes structurants : TER #8B4513 =
  /// `AppColors.ter` (0xFF8B4513), BRT #22C55E = `AppColors.brt` (0xFF22C55E).
  static Color _colorForOperatorId(String operatorId) {
    switch (operatorId) {
      case 'ter':
        return AppColors.ter;
      case 'brt':
        return AppColors.brt;
      case 'ddd':
        return AppColors.ddd;
      case 'tata':
        return AppColors.tata;
      case 'aftu':
        return AppColors.aftu;
      default:
        return AppColors.primary;
    }
  }
}

/// Ouvre la fiche détaillée d'une ligne, ou signale honnêtement son
/// indisponibilité.
///
/// GROUPE 2 (§12) : quand la ligne ne peut pas être dérivée de la source
/// unique, `DetailedRoute` vaut `null`. Il ne faut alors ni fabriquer une fiche
/// ni naviguer vers une page vide : un message court explique l'indisponibilité.
/// Aucun composant visuel n'est ajouté ni retiré (§21).
void openLineDetail(BuildContext context, DetailedRoute? route) {
  if (route == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Détail de ligne indisponible : données réseau non chargées.'),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailedRoutePage(route: route)),
  );
}

// ============================================================
// CLASSE STOP — CORRIGÉE
// ============================================================
class Stop {
  final String name; final String direction; final double distanceMeters;
  final List<int> departureMinutesFromMidnight; final IconData icon;
  final Color color; final LatLng location; final DataStatus _legacyStatus;
  final String modeLabel; final DataSourceInfo source;
  final StopType stopType;

  /// Identifiant métier dans `dakar_network.json` (ex. `stop_dakar_ter`).
  ///
  /// GROUPE 2 (§8) : seul lien fiable entre un arrêt affiché et la source unique
  /// de vérité. `null` pour les arrêts de démonstration antérieurs à
  /// l'intégration JSON ; `DetailedRoute.fromStop` retombe alors sur le nom,
  /// puis sur la proximité géographique. Le paramètre est optionnel : aucun
  /// appel existant n'est cassé.
  final String? stopId;

  /// Ligne officiellement liée à cet arrêt. Une fréquence ne devient jamais
  /// un élément de [departureMinutesFromMidnight] : elle reste dans le provider.
  final String? scheduleRouteId;

  DepartureInfo get departureInfo => departureInfoAt();

  DepartureInfo departureInfoAt({
    DateTime? at,
    bool isPublicHoliday = false,
  }) =>
      appDataService.departureFor(
        network: modeLabel,
        routeId: scheduleRouteId,
        stopId: stopId,
        at: at,
        isPublicHoliday: isPublicHoliday,
      );

  const Stop({
    required this.name, required this.direction, required this.distanceMeters,
    required this.departureMinutesFromMidnight, required this.icon, required this.color,
    required this.location, required this.modeLabel,
    DataStatus status = DataStatus.scheduled,
    this.source = DataSourceInfo.demo, this.stopType = StopType.departure,
    this.stopId, this.scheduleRouteId,
  }) : _legacyStatus = status;

  Stop copyWith({
    String? name, String? direction, double? distanceMeters,
    List<int>? departureMinutesFromMidnight, IconData? icon, Color? color,
    LatLng? location, DataStatus? status, String? modeLabel,
    DataSourceInfo? source, StopType? stopType, String? stopId,
    String? scheduleRouteId,
  }) => Stop(
    name: name ?? this.name,
    direction: direction ?? this.direction,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    departureMinutesFromMidnight: departureMinutesFromMidnight ?? this.departureMinutesFromMidnight,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    location: location ?? this.location,
    status: status ?? this.status,
    modeLabel: modeLabel ?? this.modeLabel,
    source: source ?? this.source,
    stopType: stopType ?? this.stopType,
    stopId: stopId ?? this.stopId,
    scheduleRouteId: scheduleRouteId ?? this.scheduleRouteId,
  );

  // AUDIT DONNÉES 2026-09-24 — horaires.
  // AVANT : `isContinuousFlow` inventait une « rotation ~5 min » pour AFTU,
  //         DDD et Tata ; des heures d'ouverture (5 h–22 h 30) étaient
  //         supposées ; les départs TER/BRT venaient d'un générateur.
  // APRÈS : une heure réellement publiée reste SCHEDULED ; une fréquence
  //         officielle applicable passe ESTIMATED sans créer d'heure fixe.
  //         Sans source applicable : UNKNOWN. Aucun flux temps réel n'existe.

  /// Un départ lié à une ligne résout le statut à l'heure demandée : la
  /// fréquence reste ESTIMATED et ne remplit jamais une liste d'heures.
  ScheduleStatus get scheduleStatus => scheduleRouteId != null
      ? departureInfo.status
      : ReliabilityLabel.scheduleStatusOf(departureMinutesFromMidnight);

  /// Cross-layer status consumed by the planner; frequencies map to ESTIMATED.
  DataStatus get departureStatus => departureDataStatus(scheduleStatus);

  /// Public status surface consumed by app code. Route-bound stops derive it
  /// from their applicable source; legacy stops retain their stored value.
  DataStatus get status => scheduleRouteId != null
      ? departureStatus
      : _legacyStatus;

  DataStatus departureStatusAt(DateTime at, {bool isPublicHoliday = false}) =>
      departureDataStatus(
        departureInfoAt(at: at, isPublicHoliday: isPublicHoliday).status,
      );

  bool get _hasSchedule => scheduleStatus == ScheduleStatus.scheduled;

  int? nextDepartureMinutes() {
    if (!_hasSchedule) return null;
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d >= currentMin && (d - currentMin) <= 180) return d;
    }
    return null;
  }

  int? remainingMinutes() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    return d - (DateTime.now().hour * 60 + DateTime.now().minute);
  }

  String? nextDepartureLabel() {
    if (scheduleRouteId != null) return departureInfo.label;
    final d = nextDepartureMinutes();
    if (d == null) return ReliabilityLabel.scheduleUnavailable;
    final normalized = d % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}';
  }

  int? departureAfter(int minFromMidnight) {
    if (!_hasSchedule) return null;
    for (final d in departureMinutesFromMidnight) { if (d > minFromMidnight) return d; }
    return null;
  }
}

enum DataStatus { scheduled, live, unknown, estimated }

/// Keep the existing 4-value status contract. A realtime classification can
/// only be mapped here by a future live provider; current frequency sources
/// resolve exclusively to ESTIMATED or UNKNOWN.
DataStatus departureDataStatus(ScheduleStatus status) {
  switch (status) {
    case ScheduleStatus.scheduled:
      return DataStatus.scheduled;
    case ScheduleStatus.realTime:
      return DataStatus.live;
    case ScheduleStatus.estimated:
      return DataStatus.estimated;
    case ScheduleStatus.unknown:
      return DataStatus.unknown;
  }
}

class TransitRoute {
  final String name; final String code; final String type; final Color color; final List<LatLng> points;
  const TransitRoute({required this.name, required this.code, required this.type, required this.color, required this.points});
  bool get isDedicated => type == 'TER' || type == 'BRT';
}

class RouteSegment {
  final String modeLabel; final Color color; final IconData icon;
  final String from; final String to; final int durationMinutes;
  final String? departureTime; final String? arrivalTime;
  final DataStatus status; final bool isWalk;
  final DepartureInfo? departureInfo;
  const RouteSegment({required this.modeLabel, required this.color, required this.icon, required this.from, required this.to, required this.durationMinutes, this.departureTime, this.arrivalTime, this.status = DataStatus.scheduled, this.isWalk = false, this.departureInfo});
}

class PlannedRoute {
  final String fromName; final String toName; final List<RouteSegment> segments;
  final int totalMinutes; final bool isBest; final DataStatus status; final int transferCount;
  const PlannedRoute({required this.fromName, required this.toName, required this.segments, required this.totalMinutes, this.isBest = false, this.status = DataStatus.scheduled, this.transferCount = 0});
}

class RouteSearchResult {
  final List<PlannedRoute> routes; final List<String> missingData; final String? errorMessage;
  const RouteSearchResult({this.routes = const [], this.missingData = const [], this.errorMessage});
  bool get hasRoutes => routes.isNotEmpty;
}

// ============================================================
// STATIONS ET ARRETS OFFICIELS (TER, BRT, DDD & TATA)
// CORRIGE DEFINITIF 2026 : TER et BRT viennent UNIQUEMENT du JSON officiel
// dakar_network.json (13 gares TER + 23 stations BRT). Les listes de démo
// TER/BRT sont supprimées pour éviter 21 TER / 27 BRT sur la carte live.
// ============================================================
final List<Stop> terStations = <Stop>[];
final List<Stop> brtStations = <Stop>[];

// ============================================================
// POINTS DE DÉMONSTRATION — NON AFFICHÉS (audit données 2026-09-24, mission 3)
// ============================================================
// Ces 12 entrées (5 DDD, 4 TATA, 3 AFTU) ne sont PAS des arrêts physiques :
//  * leur nom est un libellé de ligne (« DDD Ligne 3 (Sandaga - Ouakam) »,
//    « Parcelles Assainies (L1 à L10) »…), pas un nom d'arrêt ;
//  * leurs coordonnées sont saisies à la main : 3 dupliquent exactement un
//    arrêt du JSON (DDD L14 ≡ stop_ucad, TATA 218 ≡ stop_mermoz, Grand Yoff ≡
//    stop_grand_yoff), les 9 autres sont à 222–1 320 m de tout arrêt réel ;
//  * les lignes DDD 3 et 14 ne figurent pas sur demdikk.sn/reseau-urbain-dakar/
//    et les itinéraires de L1, L10 et L20 y sont différents.
// Elles sont CONSERVÉES dans le code (structure du projet) mais RETIRÉES de
// `allStops` : ni carte, ni liste, ni planificateur, ni assistant. Les arrêts
// réels correspondants restent affichés via `dakar_network.json`, et les
// routes DDD/TATA/AFTU du JSON (dont ddd_3 et ddd_14) sont inchangées.
final List<Stop> dddStations = [
  Stop(name: 'DDD Ligne 1 (Colobane - Yoff)', direction: 'Dir. Yoff Pêcheurs', distanceMeters: 1200, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6950, -17.4440), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 3 (Sandaga - Ouakam)', direction: 'Dir. Cité Mamelles', distanceMeters: 900, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6730, -17.4420), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 10 (Liberté 6 - Patte d’Oie)', direction: 'Dir. Terminus Parcelles', distanceMeters: 2400, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.7150, -17.4580), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.correspondence),
  Stop(name: 'DDD Ligne 14 (Gare Maritime - UCAD)', direction: 'Dir. Université Cheikh Anta Diop', distanceMeters: 1800, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6900, -17.4600), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 20 (Petersen - Rufisque)', direction: 'Dir. Gare Rufisque', distanceMeters: 500, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6720, -17.4390), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.terminus),
];

// Démonstration TATA — non affichée (voir ci-dessus).
final List<Stop> tataStations = [
  Stop(name: 'TATA Ligne 50 (Guédiawaye - Sandaga)', direction: 'Dir. Sandaga Centre', distanceMeters: 800, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7700, -17.3950), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 64 (Pikine - Liberté 6)', direction: 'Dir. Liberté 6 Extension', distanceMeters: 1300, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7500, -17.3880), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 78 (Yoff - Petersen)', direction: 'Dir. PEM Petersen', distanceMeters: 2100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7500, -17.4680), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 218 (Mermoz - Keur Massar)', direction: 'Dir. Keur Massar', distanceMeters: 3100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7120, -17.4650), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.correspondence),
];

final List<Stop> aftuAndBusStations = [
  Stop(name: 'Parcelles Assainies (L1 à L10)', direction: 'Dir. Dakar Centre', distanceMeters: 300, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7645, -17.4420), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Grand Yoff (L11 à L25)', direction: 'Dir. Petersen', distanceMeters: 1100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7420, -17.4480), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.correspondence),
  Stop(name: 'Terminus Petersen (AFTU L25)', direction: 'Terminus central AFTU', distanceMeters: 450, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.6720, -17.4400), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.terminus),
];

// Mission 3 : `dddStations`, `tataStations` et `aftuAndBusStations`
// (démonstration) ne sont plus concaténées. Les arrêts affichés proviennent
// uniquement de `dakar_network.json`, ajoutés par `_integrateNetworkData`.
final List<Stop> allStops = [...terStations, ...brtStations]
    .where((s) => DakarBounds.isValid(s.location))
    .toList();

// ============================================================
// §1 / §3 / §6 — SÉPARATION EXPLICITE DE DEUX NOTIONS DISTINCTES
//
//   <MODE>_NETWORK_POINTS        les points du réseau visibles dans Explorer
//   <MODE>_OFFICIAL_ROUTE_STOPS  les arrêts officiels d'un itinéraire
//
// Ces deux ensembles ne sont PAS interchangeables : un point affiché dans
// Explorer n'est pas une gare de l'itinéraire officiel. Leur confusion est la
// cause du défaut corrigé ici — un point d'Explorer ne doit jamais être promu
// dans un itinéraire officiel au seul motif qu'il apparaît sur la carte (§1).
// ============================================================

/// `<MODE>_NETWORK_POINTS` — points du réseau affichables dans Explorer.
///
/// Explorer peut afficher **davantage** de points que l'itinéraire officiel ne
/// compte de stations (§6). Cette liste n'est donc jamais réduite pour
/// correspondre à un itinéraire, et le compteur Explorer n'est jamais ajusté
/// artificiellement.
///
/// Le prédicat reproduit à l'identique celui, existant, de `_filteredStops` :
/// le mode y est porté par la couleur (`AppColors.ter`, `AppColors.brt`, …).
/// Aucun filtre, aucune couleur et aucun calcul de proximité n'est modifié
/// (§1, §10).
List<Stop> networkPoints(Color modeColor) =>
    allStops.where((Stop s) => s.color == modeColor).toList();

/// Arrêts à dessiner sur la **couche marqueurs** de la carte Explorer.
///
/// CORRECTIF ARRÊTS TER/BRT (carte principale) — cause du défaut : la couche
/// était alimentée uniquement par le flux « à proximité » (`_filteredStops` :
/// 30 arrêts max, rayon 4 km si position GPS). Sur 141 arrêts intégrés, le
/// plafond évinçait la quasi-totalité des gares TER et stations BRT
/// (Diamniadio, Bargny, Rufisque, Keur Mbaye Fall, Guédiawaye… situés de 9 à
/// 29 km du centre) alors que leurs tracés, eux, étaient dessinés en entier —
/// d'où des lignes sans leurs arrêts sur la carte.
///
/// Correctif, **sans aucune donnée nouvelle** : les arrêts officiels issus de
/// `assets/data/dakar_network.json` (déjà intégrés dans [allStops] par
/// `_integrateNetworkData`, identifiés par `stopId` non nul — donc aux
/// coordonnées exactes des sommets des polylignes TER/BRT) du réseau
/// actuellement affiché sont **garantis** sur la carte. [terDisplayed] /
/// [brtDisplayed] reproduisent le prédicat existant des `activePolylines`
/// (« Tous » → TER + BRT ; filtre TER/BRT → ce réseau ; autres filtres →
/// aucun : comportement antérieur inchangé).
///
/// Les arrêts de démonstration TER/BRT antérieurs au JSON (sans `stopId`) ne
/// sont plus redessinés sur la carte lorsqu'une gare/station officielle du
/// même réseau existe : leurs coordonnées héritées ne sont pas posées sur le
/// tracé officiel et créaient des doublons inutiles. Ils restent inchangés
/// dans les listes et cartes d'arrêts (aucune donnée retirée du projet). Sans
/// arrêt officiel disponible (repli en dur), rien n'est exclu : comportement
/// antérieur conservé. La déduplication avec [proximityStops] emploie la clé
/// `nom_latitude_longitude`, même convention que `_integrateNetworkData`.
///
/// Couture **pure** (même schéma que `integrateNetworkDataForTest` et
/// `GpsResolver.nearbyStops`) : testable sans carte ni plugin.
@visibleForTesting
List<Stop> explorerMapMarkerStops({
  required List<Stop> proximityStops,
  required bool terDisplayed,
  required bool brtDisplayed,
}) {
  final List<Stop> official = (terDisplayed || brtDisplayed)
      ? allStops
          .where((Stop s) =>
              s.stopId != null &&
              DakarBounds.isValid(s.location) &&
              ((terDisplayed && s.color == AppColors.ter) ||
                  (brtDisplayed && s.color == AppColors.brt)))
          .toList()
      : const <Stop>[];
  if (official.isEmpty) return List<Stop>.of(proximityStops);
  String keyOf(Stop s) =>
      '${s.name}_${s.location.latitude}_${s.location.longitude}';
  final Set<String> officialKeys = official.map(keyOf).toSet();
  final bool hasOfficialTer =
      official.any((Stop s) => s.color == AppColors.ter);
  final bool hasOfficialBrt =
      official.any((Stop s) => s.color == AppColors.brt);
  return <Stop>[
    ...official,
    ...proximityStops.where((Stop s) =>
        !officialKeys.contains(keyOf(s)) &&
        !(s.stopId == null &&
            ((s.color == AppColors.ter && hasOfficialTer) ||
                (s.color == AppColors.brt && hasOfficialBrt)))),
  ];
}

// ============================================================
// EXPLORATION HORS ZONE — COUTURES PURES (testables sans carte ni plugin)
// ============================================================

/// Base de la liste Explorer pour un filtre donné (chips « Tous », « ⭐
/// Favoris », TER, BRT, DDD, TATA, AFTU) — **indépendante de tout GPS**.
///
/// Même sélection que `_filteredStops` avant extraction : filtrage par couleur
/// réseau ou par favoris sur la liste source ([allStops] en production). Aucune
/// distance n'est calculée ici ; l'ordre/proximité est appliqué ensuite par
/// [explorerVisibleStops].
@visibleForTesting
List<Stop> explorerBaseStopsForFilter({
  required String selectedFilter,
  required Iterable<String> favoriteStopNames,
  required List<Stop> source,
}) {
  if (selectedFilter == '⭐ Favoris') {
    return source
        .where((Stop s) => favoriteStopNames.contains(s.name))
        .toList();
  }
  switch (selectedFilter) {
    case 'TER':
      return source.where((Stop s) => s.color == AppColors.ter).toList();
    case 'BRT':
      return source.where((Stop s) => s.color == AppColors.brt).toList();
    case 'DDD':
      return source.where((Stop s) => s.color == AppColors.ddd).toList();
    case 'TATA':
      return source.where((Stop s) => s.color == AppColors.tata).toList();
    case 'AFTU':
      return source.where((Stop s) => s.color == AppColors.aftu).toList();
    default:
      return List<Stop>.of(source);
  }
}

/// Liste visible dans l'Explorer (plafond + ordre) pour une position donnée —
/// **exploration Dakar indépendante du GPS**.
///
/// CORRECTION HORS ZONE — comportements :
///  * position **dans** la zone de service ([GpsResolver.isWithinServiceZone])
///    → identique à l'AVANT : tri par distance depuis la position mesurée,
///    rayon [GpsResolver.nearbyRadiusMeters] (4 km), plafond
///    [GpsResolver.nearbyLimit] (30) ;
///  * position **hors zone** (France, …) OU `null` (GPS refusé/indisponible)
///    → identique au chemin « sans position » préexistant : tri depuis le
///    centre géographique de Dakar (uniquement pour ORDONNER l'affichage,
///    jamais exposé comme position utilisateur), plafond 30, puis filtre
///    [DakarBounds]. Aucun « à proximité » n'est calculé depuis la France :
///    aucune distance de plusieurs milliers de kilomètres n'est produite.
///
/// Couture pure : testable sans carte ni plugin. Aucune donnée de transport
/// n'est modifiée ni fabriquée — seuls les objets d'entrée sont réordonnés.
@visibleForTesting
List<Stop> explorerVisibleStops({
  required List<Stop> base,
  required LatLng? userPosition,
}) {
  final List<Stop> working = List<Stop>.of(base);
  if (GpsResolver.isWithinServiceZone(userPosition)) {
    final LatLng position = userPosition!;
    working.sort((a, b) =>
        DistanceHelper.haversineMeters(position, a.location).compareTo(
            DistanceHelper.haversineMeters(position, b.location)));
    final nearby =
        GpsResolver.nearbyStops(working, position) ?? const <Stop>[];
    final List<Stop> limited = nearby.isNotEmpty
        ? nearby
        : working.take(GpsResolver.nearbyLimit).toList();
    return limited.where((s) => DakarBounds.isValid(s.location)).toList();
  }
  // Sans position exploitable (null ou hors zone) : ordonnancement depuis le
  // centre de Dakar — coordonnée d'ordre UNIQUEMENT, jamais une position
  // utilisateur (décision D1-i, inchangée).
  const LatLng dakarOrderCenter = LatLng(14.7167, -17.4677);
  working.sort((a, b) =>
      DistanceHelper.haversineMeters(dakarOrderCenter, a.location).compareTo(
          DistanceHelper.haversineMeters(dakarOrderCenter, b.location)));
  final List<Stop> limited = working.take(GpsResolver.nearbyLimit).toList();
  return limited.where((s) => DakarBounds.isValid(s.location)).toList();
}

/// Distance affichée sur une carte d'arrêt Explorer.
///
///  * position **dans** la zone de service → distance réelle
///    haversine(position mesurée, arrêt) — comportement inchangé ;
///  * position **hors zone** ou absente → repli identique au chemin « sans
///    position » préexistant (`Stop.distanceMeters`, constat F7 documenté) :
///    AUCUNE distance de plusieurs milliers de kilomètres (France → Dakar)
///    n'est présentée comme une distance de proximité utile.
@visibleForTesting
double explorerDistanceForDisplay(Stop s, LatLng? userPosition) {
  if (GpsResolver.isWithinServiceZone(userPosition)) {
    return DistanceHelper.haversineMeters(userPosition!, s.location);
  }
  return s.distanceMeters;
}

// ============================================================
// RENDU CARTOGRAPHIQUE — COUTURES PURES (lisibilité, sans donnée nouvelle)
// ============================================================

/// Géométrie **de rendu** d'un tracé pour la couche `PolylineLayer`
/// d'Explorer — correctif CAS A (doublonnage de rendu de la double ligne
/// BRT), appliqué au rendu uniquement, jamais aux données.
///
/// DIAGNOSTIC (démontré sur `assets/data/dakar_network.json`, inchangé) :
/// le JSON porte deux lignes BRT officielles — `BRT B1` (23 stations) et
/// `BRT B2 Express` (7 stations) — dont les 7 stations sont une
/// **sous-séquence exacte et ordonnée** des stations de B1 (indices 0, 4, 7,
/// 10, 14, 20, 22). `_loadDynamicRoutes` rend chaque ligne en vert
/// (`AppColors.brt`) :
///
///  * B1 relie ses 23 stations par segments successifs (son parcours) ;
///  * B2 relie ses 7 stations par des cordes directes qui **enjambent** les
///    16 stations intermédiaires de B1 — déviation latérale mesurée jusqu'à
///    ~910 m (segments intermédiaires à ~190-440 m) ;
///  * les deux polylignes coïncident exactement aux 7 stations partagées et
///    divergent entre elles → l'apparence « double ligne verte » /
///    « deux lignes parallèles » observée.
///
/// Ce n'est NI des points dupliqués dans une ligne (CAS B réfuté : aucun
/// point répété dans B1 ni dans B2, ni consécutif ni global), NI une
/// géométrie incohérente (CAS C réfuté : aucun retour arrière ni boucle dans
/// la séquence officielle de B1) : c'est un **doublonnage de rendu** de deux
/// lignes officielles distinctes partageant un coridoir.
///
/// Correctif de rendu : quand les points de [route] forment une sous-séquence
/// ordonnée exacte des points d'un autre tracé de **même couleur** (le
/// coridoir contenant, ex. B1 pour B2), le rendu suit le sous-tracé du
/// conteneur (y compris ses stations intermédiaires) au lieu de dessiner des
/// cordes parallèles. Les deux polylignes officielles sont toujours rendues
/// (aucune supprimée) et coïncident alors sommet pour sommet : une seule
/// ligne verte visible.
///
/// Aucune coordonnée n'est créée : chaque sommet du résultat est déjà un
/// sommet du tracé conteneur, lui-même construit uniquement depuis les arrêts
/// de `dakar_network.json`. Sans conteneur, [TransitRoute.points] est
/// retourné **inchangé** (même référence). `shapes.txt` (dépôt, hors
/// `flutter-src`) n'est pas chargé par l'application et n'intervient pas.
///
/// Couture **pure** : ni carte, ni plugin, ni I/O, aucune donnée mutée.
@visibleForTesting
List<LatLng> explorerRenderedRoutePoints(
    TransitRoute route, List<TransitRoute> universe) {
  TransitRoute? best;
  List<int>? bestIndices;
  for (final TransitRoute other in universe) {
    if (other.code == route.code) continue;
    if (other.color != route.color) continue;
    if (other.points.length <= route.points.length) continue;
    final List<int>? indices =
        _explorerSubsequenceIndices(route.points, other.points);
    if (indices != null &&
        (best == null || other.points.length > best.points.length)) {
      best = other;
      bestIndices = indices;
    }
  }
  if (best == null || bestIndices == null) return route.points;
  return best.points.sublist(bestIndices.first, bestIndices.last + 1);
}

/// Indices de la sous-séquence ordonnée **exacte** (égalité coordinate au
/// double près, sans approximation) de [needle] dans [haystack], ou `null`
/// si [needle] n'est pas contenu dans [haystack].
List<int>? _explorerSubsequenceIndices(
    List<LatLng> needle, List<LatLng> haystack) {
  final List<int> indices = <int>[];
  int h = 0;
  for (final LatLng n in needle) {
    while (h < haystack.length && !_explorerSamePoint(n, haystack[h])) {
      h++;
    }
    if (h >= haystack.length) return null;
    indices.add(h);
    h++;
  }
  return indices;
}

bool _explorerSamePoint(LatLng a, LatLng b) =>
    a.latitude == b.latitude && a.longitude == b.longitude;

/// Arrêt **structurant** pour la densité visuelle de la carte Explorer :
/// réseau TER ou BRT (tracés dédiés de la vue « Tous ») ou point
/// d'articulation (terminus / correspondance) quel que soit le réseau.
///
/// Dérivé uniquement des champs existants ([Stop.color], [Stop.stopType]) :
/// aucun champ ajouté, aucun inventaire de « principaux » codé en dur, aucun
/// arrêt retiré de la donnée.
@visibleForTesting
bool explorerStopIsStructuring(Stop s) =>
    s.color == AppColors.ter ||
    s.color == AppColors.brt ||
    s.stopType == StopType.terminus ||
    s.stopType == StopType.correspondence;

/// Empan visuel d'un marqueur arrêt pour un niveau de zoom donné — densité
/// **non destructive** (aucun arrêt supprimé, aucun réseau supprimé, aucun
/// filtre métier modifié ; le marqueur reste toujours transmis au
/// `MarkerLayer`) : il est seulement rendu plus ou moins visible.
///
/// Paliers cadrés sur les zooms déjà existants de l'Explorer (aperçu 11.2,
/// utilisateur 12.5, arrêt 13.5 ; bornes carte 9–17) :
///
///  * structurant (TER/BRT/terminus/correspondence) → plein écran à tout
///    zoom (priorité « vue éloignée ») ;
///  * secondaire, zoom < 12.0        → opacité 0.25, échelle 0.75 ;
///  * secondaire, 12.0 ≤ zoom < 13.5 → opacité 0.55, échelle 0.85 ;
///  * secondaire, zoom ≥ 13.5        → pleine visibilité.
///
/// Progression monotone : apparition progressive, jamais de disparition.
@visibleForTesting
({double opacity, double scale}) explorerMarkerVisual(double zoom, Stop stop) {
  if (explorerStopIsStructuring(stop)) {
    return (opacity: 1.0, scale: 1.0);
  }
  if (zoom < 12.0) return (opacity: 0.25, scale: 0.75);
  if (zoom < 13.5) return (opacity: 0.55, scale: 0.85);
  return (opacity: 1.0, scale: 1.0);
}

/// `<MODE>_OFFICIAL_ROUTE_STOPS` — arrêts officiels d'une ligne, dans l'ordre
/// canonique de `dakar_network.json` (source unique, §4-§5).
///
/// Chaque arrêt porte, sans duplication ni synthèse :
///   • identifiant de gare      — [BusStop.id]
///   • nom officiel             — [BusStop.name]
///   • coordonnées              — [BusStop.latitude] / [BusStop.longitude]
///   • réseau                   — [networkOfRoute]
///   • ordre dans l'itinéraire  — sa position dans la liste retournée
///   • statut de la donnée      — [BusStop.dataTrust]
///
/// La direction (§7) est portée par [reverse] : elle **inverse l'ordre
/// courant**, ce qui produit Diamniadio → Dakar et Petersen → Guédiawaye sans
/// créer de seconde liste ni de copie divergente des mêmes arrêts (§6, §7).
///
/// Retourne `null` quand le réseau n'est pas chargé, quand la ligne est
/// inconnue, ou quand aucun de ses arrêts n'est résoluble : un « inconnu »
/// honnête (§9), jamais une liste fabriquée. Contrairement à
/// `DataService.stopsForRoute` — qui lève une exception — un arrêt référencé
/// mais absent du JSON est sauté sans interrompre la ligne, et aucun arrêt de
/// substitution n'est inventé.
List<BusStop>? officialRouteStops(String routeId, {bool reverse = false}) {
  if (!appDataService.isLoaded) return null;
  final List<TransportRoute> found = appDataService.routes
      .where((TransportRoute r) => r.id == routeId)
      .toList();
  if (found.isEmpty) return null;
  final List<String> ids =
      reverse ? found.first.stopIds.reversed.toList() : found.first.stopIds;
  final List<BusStop> out = <BusStop>[];
  for (final String id in ids) {
    final List<BusStop> match =
        appDataService.stops.where((BusStop s) => s.id == id).toList();
    if (match.isNotEmpty) out.add(match.first);
  }
  return out.isEmpty ? null : out;
}

/// Réseau (`operatorId`) porteur d'une ligne officielle, ou `null` si la ligne
/// est inconnue ou le réseau non chargé. Complète [officialRouteStops] pour le
/// champ « réseau » de la structure demandée au §1.
String? networkOfRoute(String routeId) {
  if (!appDataService.isLoaded) return null;
  final List<TransportRoute> found = appDataService.routes
      .where((TransportRoute r) => r.id == routeId)
      .toList();
  return found.isEmpty ? null : found.first.operatorId;
}

// ============================================================
// INTEGRATION DataService → Stop / TransitRoute (Appelé depuis main())
// ============================================================

/// Couture de test pour [_integrateNetworkData], qui est privée et opère sur la
/// globale [appDataService].
///
/// Même schéma que la décision D3-i du Groupe 4 : couture **pure**, sans
/// nouvelle dépendance et sans modification de `pubspec.yaml`. Elle permet de
/// figer par test la cohérence entre les arrêts officiels d'un itinéraire et les
/// polylignes dessinées sur la carte Explorer (§8), sans rien changer au
/// comportement de l'application : `main()` reste le seul appelant en
/// production.
@visibleForTesting
void integrateNetworkDataForTest() => _integrateNetworkData();

void _integrateNetworkData() {
  if (!appDataService.isLoaded) return;
  if (appDataService.stops.isEmpty || appDataService.routes.isEmpty) return;

  // Evite les doublons par nom+location
  final existingKeys = allStops.map((s) => '${s.name}_${s.location.latitude}_${s.location.longitude}').toSet();
  int addedStops = 0;

  // Helper : map operatorId → couleur / icône / label / source
  Color colorForOperator(String opId) {
    switch (opId) {
      case 'ter': return AppColors.ter;
      case 'brt': return AppColors.brt;
      case 'ddd': return AppColors.ddd;
      case 'aftu': return AppColors.aftu;
      case 'tata': return AppColors.tata;
      default: return AppColors.primary;
    }
  }
  IconData iconForOperator(String opId, String type) {
    switch (opId) {
      case 'ter': return Icons.train_rounded;
      case 'brt': return Icons.directions_bus_rounded;
      case 'ddd': return Icons.directions_bus_filled_rounded;
      case 'aftu': return type == 'TATA' ? Icons.directions_bus_filled : Icons.directions_bus_outlined;
      case 'tata': return Icons.directions_bus_filled;
      default: return Icons.directions_bus;
    }
  }
  String labelForOperator(String opId, String type) {
    switch (opId) {
      case 'ter': return 'TER';
      case 'brt': return 'BRT';
      case 'ddd': return 'DDD';
      case 'aftu': return type.toUpperCase().contains('TATA') ? 'Tata' : 'AFTU';
      case 'tata': return 'Tata';
      default: return type.toUpperCase();
    }
  }
  DataSourceInfo sourceForOperator(String opId) {
    switch (opId) {
      case 'ter': return DataSourceInfo.seter;
      case 'brt': return DataSourceInfo.sunubrt;
      case 'ddd': return DataSourceInfo.demdikk;
      case 'aftu': return DataSourceInfo.aftuOfficial;
      case 'tata': return DataSourceInfo.tataOfficial;
      default: return DataSourceInfo.demo;
    }
  }
  StopType stopTypeForIndex(int idx, int total) {
    if (total == 1) return StopType.boarding;
    if (idx == 0) return StopType.boarding;
    if (idx == total - 1) return StopType.terminus;
    return StopType.intermediate;
  }

  for (final route in appDataService.routes) {
    final stopIds = route.stopIds;
    for (int i = 0; i < stopIds.length; i++) {
      final busStop = appDataService.stops.where((s) => s.id == stopIds[i]).isEmpty
          ? null
          : appDataService.stops.firstWhere((s) => s.id == stopIds[i]);
      if (busStop == null) continue;
      if (!DakarBounds.isValid(LatLng(busStop.latitude, busStop.longitude))) continue;

      final color = colorForOperator(route.operatorId);
      final icon = iconForOperator(route.operatorId, route.type);
      final label = labelForOperator(route.operatorId, route.type);
      // Audit données 2026-09-24 : la source officielle (pastille 🟢) n'est
      // attribuée que si la route ET l'arrêt sont CONFIRMED. Sinon, source
      // non vérifiée — un statut inconnu n'est jamais promu.
      final bool confirmed = ReliabilityLabel.canShowOfficial(ReliabilityLabel
          .combine(<ProvenanceStatus>[route.provenance.status, busStop.provenance.status]));
      final source = confirmed ? sourceForOperator(route.operatorId) : DataSourceInfo.unverified;
      final key = '${busStop.name}_${busStop.latitude}_${busStop.longitude}';
      if (existingKeys.contains(key)) continue;

      // Horaires : AUCUN. Le JSON n'en fournit pas (schedule_status UNKNOWN) ;
      // l'ancien générateur TER/BRT a été supprimé (audit 2026-09-24).
      const List<int> schedule = <int>[];

      final stop = Stop(
        name: busStop.name,
        stopId: busStop.id,
        scheduleRouteId: route.id,
        direction: i == stopIds.length - 1
            ? 'Terminus ${busStop.name} (Arrivée)'
            : 'Dir. ${appDataService.stops.lastWhere((s) => s.id == stopIds.last, orElse: () => busStop).name}',
        distanceMeters: 300 + (i * 800).toDouble(),
        departureMinutesFromMidnight: schedule,
        icon: icon,
        color: color,
        location: LatLng(busStop.latitude, busStop.longitude),
        modeLabel: label,
        source: source,
        stopType: stopTypeForIndex(i, stopIds.length),
      );
      allStops.add(stop);
      existingKeys.add(key);
      addedStops++;
    }

    // Ajoute aussi un TransitRoute pour la carte si >=2 points
    final points = stopIds
        .map((id) {
          try { return appDataService.stops.firstWhere((s) => s.id == id); } catch (_) { return null; }
        })
        .whereType<BusStop>()
        .map((s) => LatLng(s.latitude, s.longitude))
        .where((p) => DakarBounds.isValid(p))
        .toList();
    if (points.length >= 2) {
      final color = colorForOperator(route.operatorId);
      // Evite les doublons de TransitRoute (même code)
      final exists = demoRoutes.any((r) => r.code == route.shortName);
      if (!exists) {
        demoRoutes.add(TransitRoute(
          name: route.shortName,
          code: route.shortName,
          type: labelForOperator(route.operatorId, route.type),
          color: color,
          points: points,
        ));
      }
    }
  }

  // --- Ajoute les arrêts orphelins (présents dans stops mais jamais dans routes) ---
  for (final bs in appDataService.stops) {
    final key = '${bs.name}_${bs.latitude}_${bs.longitude}';
    if (existingKeys.contains(key)) continue;
    if (!DakarBounds.isValid(LatLng(bs.latitude, bs.longitude))) continue;
    // Détermine le label/ couleur par défaut : AFTU si non trouvé
    const label = 'AFTU';
    const color = AppColors.aftu;
    const icon = Icons.directions_bus_outlined;
    const source = DataSourceInfo.aftuOfficial;
    final stop = Stop(
      name: bs.name,
      stopId: bs.id,
      direction: 'Dir. Centre Dakar',
      distanceMeters: 500,
      departureMinutesFromMidnight: [],
      icon: icon,
      color: color,
      location: LatLng(bs.latitude, bs.longitude),
      modeLabel: label,
      source: source,
      stopType: StopType.boarding,
    );
    allStops.add(stop);
    existingKeys.add(key);
    addedStops++;
  }

  debugPrint('✅ DataService intégré : $addedStops arrêts JSON ajoutés → total allStops=${allStops.length}, demoRoutes=${demoRoutes.length}');
}

// ============================================================
// TRACES DES ROUTES — POLYLIGNES DE LA CARTE EXPLORER
// ============================================================
/// Tracés de lignes dessinés sur la carte Explorer.
///
/// CORRECTION TER/BRT (§8 : « la polyligne doit rester cohérente avec les
/// stations »). Cette liste démarre **vide** et n'est alimentée que par
/// `_integrateNetworkData`, depuis `assets/data/dakar_network.json` — la source
/// unique (§4-§5). Aucune coordonnée de ligne n'est plus codée en dur ici.
///
/// AVANT : quatre tracés littéraux hérités d'un JSON historique, dont AUCUN ne
///         correspondait aux arrêts officiels actuels :
///           TER  →  6 points   (13 gares officielles)
///           B1   → 10 points   (23 stations officielles)
///           DDD  →  3 points   (coordonnées divergentes de `ddd_12`)
///           TATA →  3 points   (coordonnées divergentes de `tata_219`)
///
/// DEUX DÉFAUTS DÉMONTRÉS de ces littéraux :
///  1. TER AMPUTÉ. La déduplication de `_integrateNetworkData` compare le
///     `code` de la démo au `short_name` du JSON. `'TER' == 'TER'` → la ligne
///     officielle `ter_dakar_diamniadio` (13 gares) était **court-circuitée**
///     et jamais ajoutée. La carte ne dessinait que 6 points : 7 des 13 gares
///     officielles étaient absentes du tracé, en contradiction de rendu avec le
///     §6 alors même que la donnée JSON est exacte.
///  2. DOUBLONS. `'B1' ≠ 'BRT B1'`, `'DDD' ≠ 'DDD 12'`, `'TATA' ≠ 'Tata 219'`
///     → ces trois lignes étaient **dessinées deux fois**, avec deux géométries
///     divergentes superposées sur la même carte.
///
/// APRÈS : un seul tracé par ligne officielle, construit depuis les arrêts du
/// JSON — TER 13 points, BRT B1 23 points, BRT B2 7, DDD 12 3, Tata 219 2. Les
/// doublons disparaissent **à la racine** au lieu d'être masqués par un recalage
/// des littéraux sur le JSON.
///
/// ÉQUIVALENCE VÉRIFIÉE (aucun rendu perdu). Pour chacune des quatre lignes, la
/// couleur et le type dérivés du JSON sont identiques à ceux des anciens
/// littéraux : `colorForOperator('ter'|'brt'|'ddd'|'tata')` rend
/// `AppColors.ter|brt|ddd|tata`, et `labelForOperator` rend
/// `'TER'|'BRT'|'DDD'|'Tata'`. `TransitRoute.isDedicated` (`type == 'TER' ||
/// type == 'BRT'`) reste donc vrai pour le TER et le BRT : le périmètre chargé
/// au démarrage par `_loadDynamicRoutes` est conservé, et aucune requête OSRM
/// supplémentaire n'est provoquée.
///
/// Le champ `name` de `TransitRoute` n'est lu par **aucune** vue (seule sa
/// déclaration le mentionne) : la disparition de `'DDD Lignes'` et
/// `'TATA Bus'` n'a aucun effet observable.
///
/// AUCUN POINT D'EXPLORER N'EST RETIRÉ par ce changement. Les marqueurs
/// proviennent de `allStops`, liste **distincte** de celle-ci : Explorer peut
/// afficher plus de points que l'itinéraire officiel ne compte de stations (§6),
/// et le compteur Explorer n'est jamais ajusté artificiellement pour
/// correspondre à un itinéraire.
final List<TransitRoute> demoRoutes = <TransitRoute>[];

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static RouteSearchResult plan({
    required String fromQuery,
    required String toQuery,
    DateTime? at,
    bool isPublicHoliday = false,
  }) {
    final now = at ?? DateTime.now();
    // Audit données 2026-09-24 — AVANT : hors 5 h 00–22 h 30, réponse « Les
    // réseaux … sont actuellement fermés (Service de 5h00 à 22h30) ». Ces
    // heures de service ne figurent dans AUCUNE donnée (schedule_status
    // UNKNOWN partout) : affirmation supprimée. L'itinéraire reste calculé ;
    // ses heures sont « Horaire indisponible » faute d'horaire fourni.

    final fromStop = _findNearestStop(fromQuery);
    final toStop = _findNearestStop(toQuery);

    if (fromStop == null) return const RouteSearchResult(errorMessage: 'Lieu de départ introuvable.');
    if (toStop == null) return const RouteSearchResult(errorMessage: 'Destination introuvable.');

    final currentMin = now.hour * 60 + now.minute;
    final candidates = <PlannedRoute>[];

    if (fromStop.modeLabel == toStop.modeLabel) {
      final direct = _buildRoute(
        fromStop,
        toStop,
        currentMin,
        now,
        isPublicHoliday: isPublicHoliday,
      );
      if (direct != null) candidates.add(direct);
    }

    if (candidates.isEmpty || candidates.first.totalMinutes > 45) {
      final transfer = _findTransfer(
        fromStop,
        toStop,
        currentMin,
        now,
        isPublicHoliday: isPublicHoliday,
      );
      if (transfer != null) candidates.add(transfer);
    }

    if (candidates.isEmpty) {
      return RouteSearchResult(errorMessage: 'Aucun itinéraire trouvé entre ${fromStop.name} et ${toStop.name}.');
    }

    candidates.sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
    return RouteSearchResult(routes: candidates);
  }

  static Stop? _findNearestStop(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || allStops.isEmpty) return null;
    for (final s in allStops) {
      if (s.name.toLowerCase().contains(q)) return s;
    }
    return allStops.firstWhere((s) => s.name.toLowerCase().contains('dakar'), orElse: () => allStops.first);
  }

  static PlannedRoute? _buildRoute(
    Stop from,
    Stop to,
    int currentMin,
    DateTime referenceTime, {
    required bool isPublicHoliday,
  }) {
    final dist = DistanceHelper.haversineMeters(from.location, to.location);
    final speed = (from.modeLabel == 'TER' || from.modeLabel == 'BRT') ? 35.0 : 20.0;
    int dur = ((dist / 1000.0) / speed * 60).ceil();
    if (dur < 5) dur = 5;

    // AUDIT DONNÉES 2026-09-24.
    // AVANT : `dep = departureAfter(now) ?? now` — sans horaire, l'heure
    //         courante devenait une « heure de départ » et `dep + dur` une
    //         heure d'arrivée, toutes deux affichées avec `DataStatus.scheduled`.
    // APRÈS : heures de départ/arrivée seulement si un horaire est fourni ;
    //         sinon une fréquence applicable fournit seulement ESTIMATED :
    //         aucune heure exacte n'est calculée. Sans fréquence : UNKNOWN.
    //         `dur` reste l'estimation historique (distance / vitesse moyenne) ;
    //         ses calculs ne sont pas modifiés ici.
    final safeCurrentMin = math.max(0, currentMin);
    final bool sameBoundRoute = from.scheduleRouteId == null ||
        from.scheduleRouteId == to.scheduleRouteId;
    final int? dep = from.departureAfter(safeCurrentMin);
    final int? arr = dep == null ? null : dep + dur;
    final DepartureInfo departureInfo = from.scheduleRouteId != null && sameBoundRoute
        ? from.departureInfoAt(
            at: referenceTime, isPublicHoliday: isPublicHoliday)
        : DepartureInfo.unknown(
            operator: from.modeLabel,
            routeId: from.scheduleRouteId ?? 'unknown',
            requestedAt: referenceTime,
          );
    final DataStatus status = from.scheduleRouteId != null
        ? sameBoundRoute
            ? from.departureStatusAt(referenceTime,
                isPublicHoliday: isPublicHoliday)
            : DataStatus.unknown
        : dep == null ? DataStatus.unknown : DataStatus.scheduled;

    return PlannedRoute(
      fromName: from.name, toName: to.name, totalMinutes: dur,
      transferCount: 0, status: status,
      segments: [RouteSegment(modeLabel: from.modeLabel, color: from.color,
        icon: from.icon, from: from.name, to: to.name, durationMinutes: dur,
        departureTime: dep == null ? null : _formatMin(dep),
        arrivalTime: arr == null ? null : _formatMin(arr), status: status,
        departureInfo: from.scheduleRouteId == null ? null : departureInfo)],
    );
  }

  static PlannedRoute? _findTransfer(
    Stop from,
    Stop to,
    int currentMin,
    DateTime referenceTime, {
    required bool isPublicHoliday,
  }) {
    if (allStops.isEmpty) return null;
    final hub = allStops.firstWhere((s) => s.name.contains('Colobane') || s.name.contains('Petersen'), orElse: () => allStops.first);
    if (hub.name == from.name || hub.name == to.name) return null;

    final leg1 = _buildRoute(
      from,
      hub,
      currentMin,
      referenceTime,
      isPublicHoliday: isPublicHoliday,
    );
    if (leg1 == null) return null;
    final leg2 = _buildRoute(
      hub,
      to,
      currentMin + leg1.totalMinutes,
      referenceTime.add(Duration(minutes: leg1.totalMinutes)),
      isPublicHoliday: isPublicHoliday,
    );
    if (leg2 == null) return null;

    return PlannedRoute(
      fromName: from.name, toName: to.name,
      totalMinutes: leg1.totalMinutes + leg2.totalMinutes + 5,
      transferCount: 1,
      // La fréquence ne fournit jamais d'heure précise. L'itinéraire composé
      // reste estimé si ses deux tronçons ont une source applicable.
      status: leg1.status == DataStatus.unknown || leg2.status == DataStatus.unknown
          ? DataStatus.unknown
          : leg1.status == DataStatus.estimated || leg2.status == DataStatus.estimated
              ? DataStatus.estimated
              : leg1.status == DataStatus.scheduled && leg2.status == DataStatus.scheduled
                  ? DataStatus.scheduled
                  : DataStatus.unknown,
      segments: [...leg1.segments, ...leg2.segments],
    );
  }

  static String _formatMin(int minFromMidnight) {
    final normalized = minFromMidnight % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}';
  }
}

// ============================================================
// UTILITAIRES & GESTION DES DIRECTIONS
// ============================================================
class TimeHelper {
  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'Imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  // Audit données 2026-09-24 (mission 3) — AVANT : `getCrowdLevel` déduisait
  // « 🔴 Bondé (Heure de pointe) », « 🟠 Dense » ou « 🟢 Fluide » de la seule
  // heure du téléphone, pour tous les arrêts, et l'affichait comme un état
  // observé. APRÈS : supprimé. Aucune donnée de fréquentation n'existe :
  // l'interface affiche [ReliabilityLabel.crowdUnavailable].
}

class DistanceHelper {
  /// Formate une distance en mètres pour l'affichage.
  ///
  /// GROUPE 7 (P1) — aligné sur le formateur réellement observé dans le
  /// binaire de production (gh-pages `94a84b60`, `main.dart.js`), fonction
  /// `A.azr` :
  ///
  ///     azr(a){ var s;
  ///       if (a < 950) return "" + a.round() + " m";
  ///       s = a / 1000;
  ///       if (s < 10) return s.toStringAsFixed(1) + " km";
  ///       return "" + s.round() + " km"; }
  ///
  /// `A.azr` est appelée aux deux seuls endroits où ce formateur est utilisé
  /// ici : le sous-titre de `StopCard` et la réponse « Tu es près de » de
  /// l'assistant — les mêmes points d'appel que `format` (L2123, L2916).
  ///
  /// AVANT : seuil de bascule à 1000 m et une décimale conservée au-delà de
  ///         10 km. Deux divergences avec la production (audit Groupe 7,
  ///         anomalie O1) : 17 900 m s'affichait « 17.9 km » au lieu de
  ///         « 18 km », et 999 m « 999 m » au lieu de « 1.0 km ».
  /// APRÈS : seuil à 950 m ; kilomètres entiers à partir de 10 km.
  ///
  /// Preuves des deux opérateurs du binaire :
  ///  * `B.c.a4` = `Math.round` (round, et non `ceil` : la définition du
  ///    binaire porte le message d'erreur `".round()"`) ;
  ///  * `B.c.aa(a, b)` = `a.toFixed(b)`, c'est-à-dire `toStringAsFixed`.
  ///
  /// Note sur la valeur charnière 950 m : `950 / 1000.0` vaut exactement
  /// 0.94999999999999995559 en IEEE-754, donc `toStringAsFixed(1)` donne
  /// « 0.9 » et non « 1.0 ». La production affiche bien **« 0.9 km »** pour
  /// 950 m. C'est une conséquence directe de l'arrondi binaire, vérifiée sur
  /// `toFixed` : le test ci-dessous verrouille cette valeur réelle.
  ///
  /// `haversineMeters`, `_distanceTo`, `distanceMeters` et les distances de
  /// `DetailedRoute` (L494, L516, formatées en ligne et non via `format`) ne
  /// sont pas concernés.
  static String format(double meters) {
    if (meters < 950) return '${meters.round()} m';
    final double km = meters / 1000.0;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Distance orthodromique en mètres.
  ///
  /// GROUPE 1 (Step 4B) — rayon terrestre aligné sur la valeur prouvée.
  ///
  /// AVANT : earthRadius = 6371000.0
  /// APRÈS : earthRadius = 6371008.8
  ///
  /// RAISON : le §10 impose « Haversine, Earth radius = 6 371 008,8 m ».
  ///         L'écart relatif est de 1,4 ppm, mais les seuils de l'algorithme
  ///         d'arrêt opposé (120 m puis 500 m) sont comparés à cette distance :
  ///         deux implémentations doivent produire le même nombre pour que les
  ///         tests et la production concordent.
  ///
  /// SOURCE DE PREUVE : la fonction `ew` du binaire de production
  ///         (gh-pages 94a84b60, main.dart.js) calcule
  ///         `12742017.6 * asin(sqrt(...))`, soit 2 × 6 371 008,8 — la forme
  ///         « diamètre » de la même formule écrite ici avec `2 * earthRadius`.
  static double haversineMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371008.8;
    final double lat1 = a.latitude * math.pi / 180.0;
    final double lat2 = b.latitude * math.pi / 180.0;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final double h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }
}

class DirectionHelper {
  static String extractDestination(String direction) {
    if (direction.contains('Dir.')) {
      return direction.replaceAll('Dir.', '').trim();
    }
    if (direction.contains('-')) {
      final parts = direction.split('-').map((s) => s.trim()).toList();
      return parts.last;
    }
    return 'Terminus / Centre';
  }
}

// ============================================================
// APP SHELL
// ============================================================
class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return MaterialApp(
          title: 'Dakar Bus',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background(dark),
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: dark ? Brightness.dark : Brightness.light),
            appBarTheme: const AppBarTheme(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

enum GpsState { idle, loading, granted, denied, deniedForever, serviceDisabled, error }

// ============================================================
// GPS §11 — COUTURE PURE ET TESTABLE (Groupe 4, décision D3-i)
// ------------------------------------------------------------
// Toute la décision GPS (état, position, message) est calculée ici à partir
// de types Dart simples, SANS aucune référence au plugin `geolocator`. Les
// tests vérifient donc les décisions et les calculs sans dépendre du plugin
// de géolocalisation, et sans ajouter de dépendance au `pubspec.yaml`.
//
// Règles appliquées :
//   §11        position RÉELLE ou erreur/UNKNOWN — jamais de position
//              fabriquée ; rayon 4000 m ; 30 résultats au maximum.
//   §16        aucune position de substitution n'est produite ;
//              `isSubstitutedPosition` reste `false` sur tous les chemins et
//              aucune position substituée ne peut produire REAL_TIME
//              (`DataStatus.live` n'est jamais assigné — 4A Carte 14).
//   4A Carte 04 `A.ap3 = 4000`, `take(30)`,
//              `LocationSettings(accuracy: high, distanceFilter: 10, 20 s)`.
//
// AVANT (défaut commun source + production, 4A §16) : une position mesurée
// hors zone était remplacée par `LatLng(14.7167, -17.4677)` et l'état passait
// à `granted` — une coordonnée inventée était exposée à tous les consommateurs
// (carte, liste « à proximité », assistant, distances affichées).
// APRÈS (décision D1-i) : aucune mesure exploitable → `position == null` et
// état d'erreur explicite. Le recadrage sur Dakar reste assuré par
// `_dakarCenter` dans `MapOptions.initialCenter`, donc la carte n'est jamais
// vide et aucune coordonnée fabriquée n'est présentée comme la position de
// l'utilisateur.
// CORRECTIF POSITION UTILISATEUR : « exploitable » signifie désormais
// **géodésiquement plausible** (`PositionValidity`), et non plus « dans le
// rectangle Dakar » (`DakarBounds`, réservé aux données réseau). Une position
// réelle mesurée à Thiès, Rufisque ou Saint-Louis est conservée telle quelle.
// ============================================================

/// Décision GPS pure : état + position + message.
///
/// [position] est `null` sauf si une position a été **mesurée** ET jugée
/// plausible par [PositionValidity]. Aucun chemin de [GpsResolver] ne produit
/// une coordonnée non mesurée, et aucune position mesurée plausible n'est
/// rejetée pour cause d'éloignement de Dakar.
class GpsResolution {
  final GpsState state;
  final LatLng? position;
  final String? message;

  /// §16 — drapeau « position substituée ».
  ///
  /// Toujours `false` dans cette application : il est conservé comme
  /// **invariant vérifiable par les tests**. Si un chemin venait à exposer une
  /// coordonnée non mesurée, ce drapeau devrait passer à `true` et le statut
  /// REAL_TIME resterait interdit.
  final bool isSubstitutedPosition;

  /// Détection HORS ZONE DE COUVERTURE — **distincte** de la validité
  /// technique de la mesure ([PositionValidity]) : une position à Paris est
  /// parfaitement plausible (`position != null`, état `granted`, aucune
  /// substitution) tout en étant hors de la zone de service dakaroise.
  ///
  /// `true` uniquement quand une position **mesurée et plausible** est située
  /// hors des limites [DakarBounds]. Jamais `true` sans `position` réelle.
  final bool isOutOfCoverage;

  const GpsResolution({
    required this.state,
    this.position,
    this.message,
    this.isSubstitutedPosition = false,
    this.isOutOfCoverage = false,
  });

  /// `true` uniquement pour une position réellement mesurée et exploitable.
  bool get hasRealPosition => state == GpsState.granted && position != null;
}

/// Décisions GPS déterministes, sans plugin. Voir l'en-tête ci-dessus.
class GpsResolver {
  GpsResolver._();

  /// Rayon « à proximité » prouvé — 4A Carte 04 : `A.ap3 = 4000`.
  /// AVANT : 5000 m codés en dur dans `_filteredStops`.
  static const double nearbyRadiusMeters = 4000.0;

  /// Plafond de résultats Explorer prouvé — 4A Carte 04 : `take(30)`.
  /// AVANT : `take(20)` (trois occurrences dans `_filteredStops`).
  static const int nearbyLimit = 30;

  /// `distanceFilter` du flux continu — 4A Carte 04 : `B.Lf`.
  static const int streamDistanceFilterMeters = 10;

  /// `timeLimit` du flux continu — 4A Carte 04 : `B.Lf` (20 s).
  /// AVANT : `getCurrentPosition(timeLimit: 10 s)`, appel ponctuel.
  static const Duration streamTimeLimit = Duration(seconds: 20);

  static const GpsResolution idle = GpsResolution(state: GpsState.idle);
  static const GpsResolution loading = GpsResolution(state: GpsState.loading);

  /// Service de localisation désactivé (1ᵉʳ des 3 états d'erreur conservés).
  static const GpsResolution serviceDisabled =
      GpsResolution(state: GpsState.serviceDisabled, message: 'GPS désactivé.');

  /// Échec technique du géolocaliseur (3ᵉ état d'erreur conservé).
  static const GpsResolution error =
      GpsResolution(state: GpsState.error, message: 'Erreur GPS.');

  /// Permission refusée — simple ou définitive.
  ///
  /// 4A Carte 04 impose de conserver les 3 états d'erreur ; la décision D4
  /// impose en plus que « refusée » et « refusée définitivement » soient
  /// **distinguables** par l'utilisateur. `GpsState.deniedForever` était
  /// déclaré dans l'enum sans jamais être assigné (les deux cas étaient
  /// collapse en `denied`) : il est désormais utilisé. Aucun état nouveau n'est
  /// créé — seule une valeur déjà déclarée reçoit son affectation.
  ///
  /// Refus définitif : sur un navigateur, le bouton « Activer GPS » ne peut
  /// pas lever ce blocage (l'invite n'est plus jamais présentée). Le message
  /// indique donc le **seul levier** réellement disponible : les réglages du
  /// navigateur. Aucune information inventée, uniquement l'action à mener.
  static const String deniedForeverMessage =
      'Permission GPS refusée définitivement : réactivez la localisation dans '
      'les réglages de votre navigateur.';

  static GpsResolution permissionDenied({required bool forever}) => forever
      ? const GpsResolution(
          state: GpsState.deniedForever,
          message: deniedForeverMessage,
        )
      : const GpsResolution(
          state: GpsState.denied,
          message: 'Permission GPS refusée.',
        );

  /// Position **mesurée** → décision (§11).
  ///
  /// - mesurée et plausible ([PositionValidity]) → `granted`, coordonnée
  ///   conservée telle quelle **où qu'elle soit** (Dakar, Thiès, Rufisque,
  ///   Saint-Louis…), aucune substitution ;
  /// - mesurée mais géodésiquement implausible ((0,0), |lat| > 90,
  ///   |lon| > 180, NaN) → c'est un échec de mesure : état d'erreur explicite
  ///   et `position == null` (décision D1-i) ;
  /// - aucune mesure (`null`) → état d'erreur explicite et `position == null`.
  ///
  /// AVANT : [DakarBounds] était appliqué ici et rejetait toute position
  /// réelle hors du rectangle Dakar (« Position hors zone, recentré sur
  /// Dakar. »). Ce rejet est supprimé : une position réelle n'est jamais
  /// rejetée — elle est **conservée telle quelle**.
  ///
  /// CORRECTION HORS ZONE (distincte du rejet historique) : une position
  /// mesurée plausible située hors de la zone de service reste `granted` avec
  /// sa coordonnée réelle intacte, mais le message du bandeau devient
  /// [outOfCoverageMessage] et [GpsResolution.isOutOfCoverage] vaut `true` :
  /// « Position GPS obtenue. » n'est plus affiché comme si l'utilisateur
  /// était dans la zone de service. Aucune substitution, aucun rejet.
  static GpsResolution fromMeasuredPosition(LatLng? measured) {
    if (measured == null) return error;
    if (!PositionValidity.isPlausible(measured)) return error;
    return _granted(measured);
  }

  /// Message exigé pour une position réelle hors zone de service.
  static const String outOfCoverageMessage =
      'Vous êtes hors de la zone de couverture Dakar Bus';

  /// Détection hors zone de couverture — **logique distincte** de
  /// [PositionValidity] (validité technique de la mesure).
  ///
  /// Réutilise [DakarBounds], les limites géographiques déjà présentes dans
  /// le projet (garde-fou du réseau de données). Aucune nouvelle zone n'est
  /// inventée. RÉSERVE : [DakarBounds] est le rectangle des **données
  /// réseau** du projet — il n'est pas documenté comme périmètre de
  /// couverture officiel des opérateurs ; il sert ici uniquement d'indicateur
  /// de « zone de service » existante la plus pertinente.
  ///
  /// Retourne `true` uniquement pour une position non nulle située dans ce
  /// rectangle. Jamais de position fabriquée n'est produite par ce prédicat.
  static bool isWithinServiceZone(LatLng? measured) =>
      measured != null && DakarBounds.isValid(measured);

  /// Décision `granted` d'une position mesurée plausible : coordonnée
  /// conservée telle quelle, message selon la zone de service.
  static GpsResolution _granted(LatLng measured) {
    final bool inZone = DakarBounds.isValid(measured);
    return GpsResolution(
      state: GpsState.granted,
      position: measured,
      message: inZone ? 'Position GPS obtenue.' : outOfCoverageMessage,
      isOutOfCoverage: !inZone,
    );
  }

  /// Interruption du flux continu (erreur, ou `timeLimit` de 20 s atteint).
  ///
  /// Le `timeLimit` prouvé interrompt le flux dès qu'aucune nouvelle position
  /// n'arrive dans ce délai — cas normal pour un utilisateur immobile, et le
  /// `distanceFilter` de 10 m fait qu'un utilisateur statique n'émet justement
  /// aucun nouvel événement. Détruire alors une position **réelle déjà
  /// mesurée** ferait perdre une donnée valide, ce que le §11 interdit dans
  /// son principe (« position réelle ou erreur » : ici la position réelle
  /// existe). Elle est donc conservée. Sans aucune mesure préalable,
  /// l'interruption est un échec GPS explicite.
  ///
  /// PORTÉ AU RAPPORT : la 4A ne décrit pas la politique d'erreur d'un flux
  /// continu (le binaire prouve les réglages `B.Lf`, pas la gestion de son
  /// interruption). Aucun redémarrage automatique n'est ajouté.
  static GpsResolution fromStreamInterrupted(LatLng? lastMeasured) {
    if (lastMeasured != null && PositionValidity.isPlausible(lastMeasured)) {
      // Même politique que [fromMeasuredPosition] : la position réelle est
      // conservée ; seule l'étiquette de zone (« hors couverture ») diffère
      // quand la mesure est hors de [DakarBounds].
      return _granted(lastMeasured);
    }
    return error;
  }

  /// Liste « à proximité » prouvée — 4A Carte 04.
  ///
  /// Filtre à [nearbyRadiusMeters], tri par distance croissante depuis la
  /// position **mesurée**, puis plafond [nearbyLimit].
  ///
  /// Sans position réelle, **aucune** liste n'est produite : `null` est
  /// renvoyé et l'appelant conserve son ordre d'affichage existant. Aucune
  /// distance n'est jamais calculée depuis une coordonnée fabriquée.
  static List<Stop>? nearbyStops(Iterable<Stop> stops, LatLng? userPosition) {
    if (userPosition == null) return null;
    final within = stops
        .where((s) =>
            DistanceHelper.haversineMeters(userPosition, s.location) <
            nearbyRadiusMeters)
        .toList()
      ..sort((a, b) => DistanceHelper
          .haversineMeters(userPosition, a.location)
          .compareTo(DistanceHelper.haversineMeters(userPosition, b.location)));
    return within.take(nearbyLimit).toList();
  }
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Timer? _ticker;

  /// GROUPE 4 (F4) — souscription au flux continu `getPositionStream`.
  ///
  /// DOIT être annulée dans [dispose] (règle générale n°9 : aucune fuite de
  /// subscription). AVANT : aucun flux — un seul appel ponctuel
  /// `getCurrentPosition` depuis `initState` puis à chaque appui sur le bouton.
  StreamSubscription<Position>? _positionSub;

  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;
  String? _gpsMessage;

  @override
  void initState() {
    super.initState();
    _requestLocation();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    // ✅ GROUPE 4 : annulation de la souscription GPS AVANT `super.dispose()`.
    //    Sans cet appel, un State démonté continuerait de recevoir des
    //    positions et de déclencher `setState` (fuite + exception).
    //    AVANT : `void dispose() { _ticker?.cancel(); super.dispose(); }`
    _positionSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  /// Reporte une décision pure de [GpsResolver] dans l'état du widget.
  ///
  /// Toute la logique de décision vit dans [GpsResolver], testable sans plugin
  /// (décision D3-i). §11 : `_userPosition` ne reçoit qu'une position
  /// réellement mesurée — jamais une coordonnée fabriquée.
  void _applyGps(GpsResolution r) {
    if (!mounted) return;
    setState(() {
      _gpsState = r.state;
      _userPosition = r.position;
      _gpsMessage = r.message;
    });
  }

  Future<void> _requestLocation() async {
    setState(() { _gpsState = GpsState.loading; _gpsMessage = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _applyGps(GpsResolver.serviceDisabled);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // ✅ GROUPE 4 (D4) : refus simple et refus définitif désormais
        //    distinguables. `GpsState.deniedForever` était déclaré dans l'enum
        //    sans jamais être assigné (les deux cas étaient collapse en
        //    `denied`) ; aucune valeur nouvelle n'est créée.
        _applyGps(GpsResolver.permissionDenied(
            forever: permission == LocationPermission.deniedForever));
        return;
      }
      // ✅ GROUPE 4 (F4) — flux continu prouvé, 4A Carte 04 :
      //    `B.Lf = LocationSettings(accuracy: high, distanceFilter: 10,
      //    timeLimit: 20 s)`, puis `getPositionStream(locationSettings: B.Lf)`.
      //    AVANT : `getCurrentPosition(desiredAccuracy: high,
      //    timeLimit: 10 s)`, ponctuel, sans `distanceFilter`.
      //    Une souscription existante est annulée avant d'en ouvrir une
      //    nouvelle : `_requestLocation` est appelé par `initState` ET par le
      //    bouton GPS — deux flux simultanés seraient sinon possibles.
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: GpsResolver.streamDistanceFilterMeters,
          timeLimit: GpsResolver.streamTimeLimit,
        ),
      ).listen(
        (position) => _applyGps(GpsResolver.fromMeasuredPosition(
            LatLng(position.latitude, position.longitude))),
        onError: (_) =>
            _applyGps(GpsResolver.fromStreamInterrupted(_userPosition)),
        onDone: () =>
            _applyGps(GpsResolver.fromStreamInterrupted(_userPosition)),
        cancelOnError: false,
      );
    } catch (_) {
      // AVANT : état `error` systématique. Désormais : une position réelle déjà
      // mesurée est conservée (voir `GpsResolver.fromStreamInterrupted`). Au
      // premier appel `_userPosition` est `null` → comportement identique à
      // l'AVANT (`error` + 'Erreur GPS.').
      _applyGps(GpsResolver.fromStreamInterrupted(_userPosition));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, gpsMessage: _gpsMessage, onRequestLocation: _requestLocation),
      const TripsPage(),
      const AlertsPage(),
      const CommunityAlertsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppColors.surface(dark), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface(dark),
            indicatorColor: AppColors.primary.withOpacity(0.18),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 68,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: AppColors.primary), label: 'Direct rue'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Réglages'),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EXPLORER — ZOOM DÉZOOMÉ, SANS CameraConstraint (WEB SAFE)
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition; final GpsState gpsState; final String? gpsMessage; final Future<void> Function() onRequestLocation;
  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.gpsMessage, required this.onRequestLocation});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';
  int _mapHeight = 260;
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Polyline> _dynamicPolylines = [];
  bool _isLoadingRoutes = true;

  /// Zoom courant de la carte, suivi via `MapOptions.onPositionChanged`
  /// (gestes ET déplacements programmatiques). Pilote la densité visuelle des
  /// marqueurs ([explorerMarkerVisual]) — aucun arrêt n'est jamais retiré de
  /// la couche ni des données, seul le rendu change avec le zoom.
  double _mapZoom = _zoomOverview;

  // ✅ ZOOMS ADAPTÉS
  static const double _zoomOverview = 11.2;
  static const double _zoomOnStop = 13.5;
  static const double _zoomOnUser = 12.5;

  @override
  void initState() {
    super.initState();
    _loadDynamicRoutes();
    // ✅ Fix: ne pas appeler _mapController.move() avant que la map soit prête
    // initialCenter gère déjà le centrage initial. Le move est reporté à onMapReady si besoin.
  }

  @override
  void didUpdateWidget(covariant ExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ CORRECTION HORS ZONE : recentrage automatique UNIQUEMENT depuis une
    //    position dans la zone de service. Depuis la France, les mises à jour
    //    GPS ne déplacent plus la carte hors de Dakar : l'exploration reste
    //    indépendante de la position GPS réelle. La position réelle reste
    //    conservée (marqueur utilisateur) et le bouton « Position GPS » reste
    //    utilisable pour aller s'y rendre volontairement.
    if (GpsResolver.isWithinServiceZone(widget.userPosition) &&
        widget.userPosition != oldWidget.userPosition) {
      // ✅ Fix: guard move avec try + postFrame pour éviter LateInitializationError
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted) _mapController.move(widget.userPosition!, _zoomOverview);
        } catch (e) {
          debugPrint('Map move skipped (not ready): $e');
        }
      });
    }
  }

  Future<void> _loadDynamicRoutes() async {
    // ✅ Fluidité : charge uniquement TER/BRT (dédié) au démarrage — instantané, pas d'OSRM
    final List<Polyline> loaded = [];
    final initialRoutes = demoRoutes.where((r) => r.isDedicated).toList();
    for (final route in initialRoutes) {
      // ✅ RENDU ANTI-DOUBLE-LIGNE (CAS A) — géométrie éventuellement calée
      //    sur le coridoir conteneur de même couleur (ex. : les cordes de
      //    BRT B2 Express suivent alors le sous-tracé de BRT B1 au lieu de
      //    dessiner une seconde ligne verte parallèle). Couture pure, voir
      //    [explorerRenderedRoutePoints] : aucune donnée mutée.
      // ✅ Lisibilité des superpositions — liserre blanche (dessous du trait,
      //    largeur additive `borderStrokeWidth`) sépare visuellement les
      //    réseaux qui se croisent, sans changer leurs couleurs ni épaisseurs.
      final points = explorerRenderedRoutePoints(route, demoRoutes)
          .where((pt) => DakarBounds.isValid(pt))
          .toList();
      if (points.length >= 2) {
        loaded.add(Polyline(
          points: points,
          color: route.color,
          strokeWidth: 5.5,
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ));
      }
    }
    if (mounted) setState(() { _dynamicPolylines = loaded; _isLoadingRoutes = false; });
    // Charge le reste en arrière-plan, paresseusement et par petits lots (cache OSRM)
    _lazyLoadRemainingRoutes();
  }

  Future<void> _lazyLoadRemainingRoutes() async {
    // Ne charge les autres tracés que si besoin et de manière non bloquante
    await Future.delayed(const Duration(milliseconds: 800));
    final List<Polyline> extra = [];
    final remaining = demoRoutes.where((r) => !r.isDedicated).take(20).toList(); // limite à 20 pour ne pas surcharger
    for (final route in remaining) {
      if (route.points.length < 2) continue;
      // Utilise le cache OSRM, mais sans bloquer l'UI
      List<LatLng> fullRoutePoints = [];
      try {
        final futures = <Future<List<LatLng>>>[];
        for (int i = 0; i < route.points.length - 1; i++) {
          futures.add(RoutingService.getRealRoute(route.points[i], route.points[i + 1]));
        }
        final segments = await Future.wait(futures).timeout(const Duration(seconds: 3), onTimeout: () => []);
        for (final seg in segments) {
          final validSeg = seg.where((pt) => DakarBounds.isValid(pt)).toList();
          if (fullRoutePoints.isNotEmpty && validSeg.isNotEmpty) {
            fullRoutePoints.addAll(validSeg.skip(1));
          } else {
            fullRoutePoints.addAll(validSeg);
          }
        }
      } catch (_) {}
      if (fullRoutePoints.isEmpty) fullRoutePoints = route.points.where((pt) => DakarBounds.isValid(pt)).toList();
      if (fullRoutePoints.length >= 2) {
        extra.add(Polyline(
          points: fullRoutePoints,
          color: route.color,
          strokeWidth: 4.5,
          // ✅ Même liserre blanche que les tracés dédiés — séparation
          //    visuelle des réseaux superposés (rendu seul).
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ));
      }
      // Petite pause pour ne pas saturer
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (mounted && extra.isNotEmpty) {
      setState(() => _dynamicPolylines = [..._dynamicPolylines, ...extra]);
    }
  }

    // ✅ GROUPE 4 (F2 + F3) — 4A Carte 04 : rayon **4000 m** (`A.ap3`) et
    //    plafond de **30 résultats** (`take(30)`).
    //    AVANT : `< 5000` et `.take(20)` (trois occurrences).
    //    Le calcul est délégué à `GpsResolver.nearbyStops`, couture pure
    //    testable sans plugin de géolocalisation (décision D3-i).
    //
    // ✅ CORRECTION HORS ZONE : la sélection du filtre
    //    ([explorerBaseStopsForFilter]) puis l'ordre/le plafond
    //    ([explorerVisibleStops]) sont des coutures pures. Depuis une
    //    position hors zone (France) ou sans GPS, le tri « à proximité »
    //    n'est PAS calculé depuis la position mesurée : la liste est ordonnée
    //    depuis le centre de Dakar (chemin « sans position » préexistant), ce
    //    qui supprime les distances de plusieurs milliers de kilomètres et
    //    garantit l'exploration du réseau dakarois à distance.
    List<Stop> get _filteredStops => explorerVisibleStops(
          base: explorerBaseStopsForFilter(
            selectedFilter: _selectedFilter,
            favoriteStopNames: globalState.favoriteStopNames,
            source: allStops,
          ),
          userPosition: widget.userPosition,
        );

  /// GROUPE 4 (décision D6-i) — **COMPORTEMENT INCHANGÉ EN ZONE DE SERVICE**.
  ///
  /// CONSTAT F7 PORTÉ AU RAPPORT, NON PROUVÉ / HORS PÉRIMÈTRE :
  /// quand aucune position réelle n'est disponible, cette méthode retombe sur
  /// `s.distanceMeters`, c'est-à-dire une valeur portée par le modèle `Stop`
  /// (500, 350, `35000`, valeurs dérivées d'un index pour les arrêts de
  /// démonstration), et `StopCard` l'affiche comme s'il s'agissait de la
  /// distance de utilisateur à l'arrêt — repli préexistant, non modifié ici.
  ///
  /// CORRECTION HORS ZONE : le même repli s'applique désormais à une position
  /// réelle mais **hors zone de service** (France) : l'haversine
  /// France → Dakar (~14 000 km) n'est plus présentée comme une distance de
  /// proximité utile. En zone de service, la distance réelle mesurée reste
  /// affichée à l'identique. Délégation pure à [explorerDistanceForDisplay].
  double _distanceTo(Stop s) => explorerDistanceForDisplay(s, widget.userPosition);

  /// GROUPE 4 (D4-i) — icône du bandeau GPS.
  ///
  /// Reflète uniquement l'état réel produit par [GpsResolver]. Les quatre cas
  /// exigés par D4 sont visuellement séparés : position obtenue, permission
  /// refusée (simple ou définitive), service désactivé, erreur.
  IconData get _gpsBannerIcon => switch (widget.gpsState) {
        GpsState.granted => Icons.my_location,
        GpsState.denied || GpsState.deniedForever => Icons.location_off,
        GpsState.serviceDisabled => Icons.location_disabled,
        GpsState.idle || GpsState.loading || GpsState.error => Icons.gps_not_fixed,
      };

  /// GROUPE 4 (D4-i) — couleur du bandeau GPS.
  ///
  /// Palette existante uniquement : `AppColors.success` (vert officiel, déjà
  /// utilisé pour une position obtenue sur le bouton GPS), `AppColors.warning`
  /// (déjà utilisé pour « Bientôt » dans `StopCard`) et `AppColors.textSecondary`.
  ///
  /// CORRECTION HORS ZONE : une position réelle hors zone de service est un
  /// avertissement (`AppColors.warning`), pas un succès vert — le message
  /// « Vous êtes hors de la zone de couverture Dakar Bus » ne doit pas être
  /// présenté comme une réussite de localisation en zone de service.
  bool get _outOfCoverage => widget.gpsMessage == GpsResolver.outOfCoverageMessage;

  Color _gpsBannerColor(bool dark) => switch (widget.gpsState) {
        GpsState.granted =>
          _outOfCoverage ? AppColors.warning : AppColors.success,
        GpsState.denied ||
        GpsState.deniedForever ||
        GpsState.serviceDisabled =>
          AppColors.warning,
        GpsState.idle || GpsState.loading || GpsState.error => AppColors.textSecondary(dark),
      };

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) => (s.name.toLowerCase().contains(q) || s.direction.toLowerCase().contains(q)) && DakarBounds.isValid(s.location)).take(8).toList();
  }

  void _centerOnStop(Stop s) {
    try {
      _mapController.move(s.location, _zoomOnStop);
    } catch (e) {
      debugPrint('centerOnStop skipped (map not ready): $e');
    }
  }
  void _openAI() => Navigator.push(context, MaterialPageRoute(builder: (_) => AIChatPage(userPosition: widget.userPosition)));

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    final stops = _filteredStops;
    // ✅ Filtre les tracés par mobilité pour éviter le spaghetti orange : n'affiche que la couleur sélectionnée
    final Color? filterColor = _selectedFilter == 'Tous' ? null : _colorFor(_selectedFilter);
    final basePolylines = _dynamicPolylines.isNotEmpty
        ? _dynamicPolylines
        : demoRoutes
            .map((r) => Polyline(
                  // Même géométrie de rendu que `_loadDynamicRoutes` (CAS A)
                  // pour un état de chargement cohérent.
                  points: explorerRenderedRoutePoints(r, demoRoutes)
                      .where((pt) => DakarBounds.isValid(pt))
                      .toList(),
                  color: r.color,
                  strokeWidth: 5.0,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ))
            .toList();
    final activePolylines = filterColor == null
        ? basePolylines.where((p) => p.color == AppColors.ter || p.color == AppColors.brt).toList() // Tous : seulement TER/BRT (tracés dédiés, pas le spaghetti)
        : basePolylines.where((p) => p.color == filterColor).toList();
    final mapStops = _filteredStops; // ✅ Toujours filtré à proximité (30 max — Groupe 4), pas allStops
    // ✅ CORRECTIF ARRÊTS TER/BRT — garantit sur la carte les gares/stations
    //    officielles des réseaux affichés (même prédicat que `activePolylines`
    //    ci-dessus), que le plafond de proximité évinçait. Cause, périmètre et
    //    déduplication documentés sur [explorerMapMarkerStops].
    final mapMarkerStops = explorerMapMarkerStops(
      proximityStops: mapStops,
      terDisplayed: filterColor == null || filterColor == AppColors.ter,
      brtDisplayed: filterColor == null || filterColor == AppColors.brt,
    );
    // ✅ DIAGNOSTIC RUNTIME (correctif TER/BRT) — une ligne par reconstruction :
    //    compte réel de ce qui est transmis au MarkerLayer de CETTE carte,
    //    après le seul filtrage résiduel (DakarBounds) ci-dessous.
    final markerStops = mapMarkerStops.where((s) => DakarBounds.isValid(s.location)).toList();
    debugPrint('[EXPLORER][MARKERS] transmis au MarkerLayer: total=${markerStops.length} TER=${markerStops.where((s) => s.color == AppColors.ter).length} BRT=${markerStops.where((s) => s.color == AppColors.brt).length} | allStops=${allStops.length} proximité=${mapStops.length} | filtre=$_selectedFilter gps=${widget.gpsState} rayon=${GpsResolver.nearbyRadiusMeters}m limite=${GpsResolver.nearbyLimit}');

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ✅ GROUPE 4 (F5, décision D4-i) — BANDEAU GPS PERSISTANT.
                //
                // `gpsMessage` était déjà transmis à `ExplorerPage` par
                // `MainShell.build` et déclaré comme champ de ce widget, mais
                // n'était lu dans AUCUN `build` : les messages produits par le
                // code étaient **invisibles** pour l'utilisateur (constat absent
                // du rapport 4A, qui les supposait « transitoires »).
                // 4A Carte 04 — tests (b), (c), (d), (e) — et la décision D4
                // exigent qu'ils le deviennent et soient distinguables :
                // position obtenue / refusée / refusée définitivement / erreur.
                //
                // Intervention UI minimale : aucun composant nouveau, aucune
                // refonte d'Explorer. Mêmes couleurs (`AppColors.surface`,
                // `divider`, `success`, `warning`, `textSecondary`), même rayon
                // 16, mêmes marges et même corps de texte 11 gras que le reste
                // de l'écran. Le bandeau reste affiché tant qu'un message
                // existe (§16 : persistance) et ne contient AUCUNE information
                // inventée — uniquement l'état réel du géolocaliseur.
                if (widget.gpsMessage != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface(dark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider(dark)),
                    ),
                    child: Row(
                      children: [
                        Icon(_gpsBannerIcon, size: 14, color: _gpsBannerColor(dark)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.gpsMessage!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gpsBannerColor(dark))),
                        ),
                      ],
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _mapHeight.toDouble(),
                  decoration: const BoxDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      ClipRect(
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            // ✅ CORRECTION HORS ZONE : l'ouverture sur Dakar
                            //    est indépendante de la position GPS réelle —
                            //    centrage sur l'utilisateur UNIQUEMENT s'il se
                            //    trouve dans la zone de service (sinon
                            //    _dakarCenter). Depuis la France, la carte
                            //    s'ouvre donc sur Dakar sans GPS simulé ; le
                            //    centrage sur Dakar ne prétend pas que le
                            //    téléphone est à Dakar (la position réelle
                            //    reste affichée comme marqueur hors vue).
                            initialCenter: GpsResolver.isWithinServiceZone(widget.userPosition)
                                ? widget.userPosition!
                                : _dakarCenter,
                            initialZoom: _zoomOverview,
                            minZoom: 9,
                            maxZoom: 17,
                            // ✅ PAS de cameraConstraint → carte fluide sur web
                            // ✅ DENSITÉ AU ZOOM (rendu seul) : suit le zoom
                            //    réel de la caméra (gestes et déplacements
                            //    programmatiques) pour appliquer
                            //    [explorerMarkerVisual]. Seuil 0.1 : pas de
                            //    reconstruction à chaque micro-mouvement.
                            onPositionChanged: (position, _) {
                              final double? z = position.zoom;
                              if (z == null || (z - _mapZoom).abs() < 0.1) {
                                return;
                              }
                              if (mounted) setState(() => _mapZoom = z);
                            },
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus', maxZoom: 19),
                            PolylineLayer(polylines: activePolylines),
                            MarkerLayer(
                              // ✅ DENSITÉ AU ZOOM (Phases 3-4) : empan
                              //    20 px (cible 18-20), opacité/échelle
                              //    pilotées par [_mapZoom] via
                              //    [explorerMarkerVisual]. NON destructif :
                              //    la liste `markerStops` est inchangée (aucun
                              //    arrêt retiré — même transmission qu'avant) ;
                              //    couleurs, icônes, interactions et page de
                              //    détail au clic identiques.
                              markers: markerStops.map((s) {
                                final ({double opacity, double scale}) visual =
                                    explorerMarkerVisual(_mapZoom, s);
                                return Marker(
                                  point: s.location, width: 20, height: 20,
                                  child: Opacity(
                                    opacity: visual.opacity,
                                    child: Transform.scale(
                                      scale: visual.scale,
                                      child: GestureDetector(
                                        onTap: () { _centerOnStop(s); Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))); },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: s.color, shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3)],
                                          ),
                                          child: Icon(s.icon, color: Colors.white, size: 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (widget.userPosition != null && PositionValidity.isPlausible(widget.userPosition!))
                              MarkerLayer(markers: [Marker(point: widget.userPosition!, width: 22, height: 22, child: Container(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)])))]),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: 16, left: 16,
                        child: Material(
                          elevation: 4, borderRadius: BorderRadius.circular(24), color: AppColors.surface(dark),
                          child: InkWell(
                            onTap: widget.gpsState == GpsState.granted
                                ? () { if (widget.userPosition != null) { try { _mapController.move(widget.userPosition!, _zoomOnUser); } catch (e) { debugPrint('GPS move skipped: $e'); } } }
                                : () => widget.onRequestLocation(),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  widget.gpsState == GpsState.loading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(widget.gpsState == GpsState.granted ? Icons.my_location : Icons.location_searching, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 6),
                                  Text(widget.gpsState == GpsState.granted ? 'Position GPS' : 'Activer GPS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 16, right: 16,
                        child: ElevatedButton.icon(
                          onPressed: _openAI,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Assistant IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 4),
                        ),
                      ),

                      Positioned(
                        top: 12, right: 12,
                        child: Material(
                          elevation: 4, borderRadius: BorderRadius.circular(24), color: AppColors.surface(dark),
                          child: InkWell(
                            onTap: () => setState(() => _mapHeight = _mapHeight == 260 ? 340 : (_mapHeight == 340 ? 160 : 260)),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_mapHeight == 160 ? Icons.expand_more : Icons.expand_less, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 4),
                                  Text(_mapHeight == 160 ? 'Agrandir' : 'Réduire', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Dakar Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                          Text('TER / BRT / DDD / TATA / AFTU', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark)))
                        ])),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider(dark)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() => _searchFocused = true),
                          style: TextStyle(color: AppColors.textPrimary(dark)),
                          decoration: InputDecoration(
                            hintText: 'Où voulez-vous aller ? (ex: Colobane, Yoff...)',
                            hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
                            prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
                            suffixIcon: _searchFocused ? IconButton(icon: Icon(Icons.close, size: 20, color: AppColors.textSecondary(dark)), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                          ),
                        ),
                      ),
                      if (_searchFocused && _searchResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider(dark))),
                          child: Column(children: _searchResults.map((s) => ListTile(dense: true, leading: Icon(s.icon, color: s.color, size: 22), title: Text(s.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(dark))), subtitle: Text(s.direction, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))), onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); })).toList()),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('Tous'), _chip('⭐ Favoris'), _chip('TER'), _chip('BRT'), _chip('DDD'), _chip('TATA'), _chip('AFTU')])),
                      const SizedBox(height: 16),
                      Row(children: [
                        Text('${stops.length} arrêts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                        const SizedBox(width: 8),
                        if (_isLoadingRoutes)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        else
                          Text('à proximité (Maintenez un arrêt pour l\'ajouter aux favoris)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark)))
                      ]),
                      const SizedBox(height: 10),
                      ...stops.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(onTap: () => _centerOnStop(s), child: StopCard(stop: s, distanceMeters: _distanceTo(s))))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label) {
    final dark = globalState.darkMode;
    final color = _colorFor(label);
    final sel = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : AppColors.surface(dark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: sel ? color : AppColors.divider(dark), width: sel ? 2 : 1)
          ),
          child: Text(label, style: TextStyle(color: sel ? color : AppColors.textSecondary(dark), fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13))
        ),
      ),
    );
  }

  Color _colorFor(String label) {
    switch (label) {
      case '⭐ Favoris': return Colors.amber;
      case 'TER': return AppColors.ter;
      case 'BRT': return AppColors.brt;
      case 'DDD': return AppColors.ddd;
      case 'TATA': return AppColors.tata;
      case 'AFTU': return AppColors.aftu;
      default: return AppColors.primary;
    }
  }
}

// ============================================================
// CARTE D ARRET (SANS CŒUR ENCOMBRANT - APPUIS LONGS POUR FAVORIS)
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop; final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        final isFav = globalState.isFavorite(stop.name);
        const String crowd = ReliabilityLabel.crowdUnavailable;
        Widget timeWidget;

        // AUDIT DONNÉES 2026-09-24.
        // AVANT : « Fermé » déduit de l'heure (5 h–22 h 30 supposés),
        //         « Bientôt », « Imminent » et un compte à rebours vert calculé
        //         sur des départs générés — lu comme du temps réel.
        // APRÈS : sans horaire fourni → « Horaire indisponible » ; avec un
        //         horaire fourni → « Prévu HH h MM » (programmé, pas de
        //         compte à rebours). Aucun flux temps réel n'existe.
        if (stop.scheduleRouteId != null) {
          final info = stop.departureInfo;
          timeWidget = Text(info.label, style: TextStyle(
            fontSize: info.status == ScheduleStatus.scheduled ? 13 : 11,
            fontWeight: FontWeight.bold,
            color: info.status == ScheduleStatus.scheduled
                ? stop.color
                : AppColors.textSecondary(dark),
          ));
        } else if (stop.scheduleStatus == ScheduleStatus.unknown) {
          timeWidget = Text(ReliabilityLabel.scheduleUnavailable, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark)));
        } else if (stop.nextDepartureMinutes() == null) {
          timeWidget = Text('Aucun départ programmé', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark)));
        } else {
          timeWidget = Text('Prévu ${stop.nextDepartureLabel()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stop.color));
        }

        return GestureDetector(
          onLongPress: () {
            globalState.toggleFavorite(stop.name);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isFav ? '${stop.name} retiré des favoris' : '${stop.name} ajouté aux favoris ⭐'),
              duration: const Duration(seconds: 1),
            ));
          },
          child: Container(
            decoration: BoxDecoration(
              color: isFav ? AppColors.primary.withOpacity(dark ? 0.15 : 0.05) : AppColors.surface(dark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isFav ? AppColors.primary : AppColors.divider(dark), width: isFav ? 1.5 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
              leading: CircleAvatar(backgroundColor: stop.color, radius: 24, child: Icon(stop.icon, color: Colors.white, size: 22)),
              title: Row(
                children: [
                  Expanded(child: Text(stop.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)))),
                  if (isFav) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.star, size: 16, color: Colors.amber)),
                  _buildStopTypeBadge(stop.stopType),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.direction, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary(dark))),
                    const SizedBox(height: 2),
                    Text('${DistanceHelper.format(distanceMeters)} • ${stop.modeLabel} (${stop.source.badgeEmoji}) • $crowd', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                  ],
                ),
              ),
              // BUG UI — LIBELLÉ DE DIRECTION REPLIÉ CARACTÈRE PAR CARACTÈRE.
              //
              // CAUSE : `ListTile` n'est pas un `Row` contrôlé ici ; il calcule
              //   lui-même la largeur du titre et du sous-titre :
              //     largeurTitre = largeurTuile − contentPadding
              //                    − (leading + horizontalTitleGap)
              //                    − (trailing + horizontalTitleGap)
              //   `leading` vaut 48 px (+ 16 px de gap) et `trailing` reçoit
              //   une largeur NON bornée : le libellé de fréquence
              //   (« Passage estimé dans 0–6 min · fréquence 6 min », ~285 px
              //   en 11 px gras) consommait donc presque toute la tuile. La
              //   colonne de texte (dont `Text(stop.direction,
              //   « Dir. Papa Gueye Fall - PEM Petersen BRT ») ne recevait plus
              //   que quelques pixels — d'où un repli caractère par caractère
              //   et un empilement vertical qui déformait la carte.
              //
              // CORRECTIF MINIMAL : borner la largeur du seul élément de droite
              //   à une fraction de la largeur réellement disponible (contrainte
              //   responsive issue du parent : aucune largeur fixe arbitraire),
              //   de sorte que la colonne de texte conserve toujours la majorité
              //   de l'espace et se replie uniquement entre les mots. Quand le
              //   libellé tient déjà sur une ligne (écrans larges), sa largeur
              //   naturelle est conservée : aucun changement d'affichage.
              //   Aucun texte, couleur, icône, espacement ni style modifié.
              trailing: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.34),
                  child: timeWidget,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStopTypeBadge(StopType type) {
    Color color; String label;
    switch (type) {
      case StopType.arrival: color = AppColors.warning; label = 'ARRIVÉE'; break;
      case StopType.departure: color = AppColors.primary; label = 'DÉPART'; break;
      case StopType.boarding: color = AppColors.brt; label = 'EMBARQ.'; break;
      case StopType.terminus: color = AppColors.ter; label = 'TERMINUS'; break;
      case StopType.correspondence: color = AppColors.tata; label = 'CORRESP.'; break;
      case StopType.intermediate: color = Colors.grey; label = 'INTERM.'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.4), width: 0.8)),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ============================================================
// ONGLET TRAJETS
// ============================================================
class TripsPage extends StatefulWidget {
  const TripsPage({super.key});
  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final _fromCtrl = TextEditingController(text: 'Parcelles Assainies');
  final _toCtrl = TextEditingController(text: 'Petersen');
  bool _loading = false;
  RouteSearchResult? _result;

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _result = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    final res = RoutePlanner.plan(fromQuery: _fromCtrl.text, toQuery: _toCtrl.text);
    if (!mounted) return;
    setState(() { _loading = false; _result = res; });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Planifier un trajet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Itinéraires multimodaux indicatifs (TER, BRT, DDD, TATA, AFTU).', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      _buildInputField(controller: _fromCtrl, label: 'Départ', icon: Icons.my_location, color: AppColors.primary, dark: dark),
                      const SizedBox(height: 12),
                      _buildInputField(controller: _toCtrl, label: 'Destination', icon: Icons.location_on, color: AppColors.ter, dark: dark),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _search,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
                        child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Rechercher mon itinéraire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                if (_result == null && !_loading) ...[
                  const SizedBox(height: 24),
                  // Mission 3 : « populaires » supposait une donnée de fréquentation
                  // inexistante — remplacé par un libellé neutre.
                  Text('Exemples de lignes (TER, BRT, DDD)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: [
                      // GROUPE 2 (§8) : les cibles sont dérivées du JSON par
                      // exploitant. Les `Stop` de démonstration codés en dur ne
                      // sont plus passés à `DetailedRoute` : leurs coordonnées
                      // HISTORIQUES ne permettent plus de résoudre un arrêt
                      // ACTUEL (voir `DetailedRoute.fromOperator`). Les trois
                      // libellés ci-dessous sont conservés à l'identique (§21).
                      _suggestionChip('Dakar - Diamniadio (TER)', () {
                        openLineDetail(context, DetailedRoute.fromOperator('ter'));
                      }, dark),
                      _suggestionChip('Guédiawaye - Petersen (BRT)', () {
                        openLineDetail(context, DetailedRoute.fromOperator('brt'));
                      }, dark),
                      // Mission 3 : `ddd_1` est CONFLICTING (itinéraire contredit
                      // par demdikk.sn) — la puce le signale au lieu de le
                      // présenter comme une ligne établie.
                      _suggestionChip('Colobane - Yoff (DDD 1, itinéraire contesté)', () {
                        openLineDetail(context, DetailedRoute.fromOperator('ddd'));
                      }, dark),
                    ],
                  ),
                ],

                if (_result != null) ...[
                  const SizedBox(height: 24),
                  Row(children: [
                    Text('Itinéraires proposés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                    const Spacer(),
                    Text('${_result!.routes.length} résultat(s)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark)))
                  ]),
                  const SizedBox(height: 12),
                  if (_result!.hasRoutes)
                    ..._result!.routes.map((r) => _buildRouteCard(r, dark))
                  else
                    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16)), child: Column(children: [const Icon(Icons.error_outline, color: AppColors.warning, size: 40), const SizedBox(height: 10), Text(_result!.errorMessage ?? 'Aucun trajet trouvé', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary(dark)))]))
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, required Color color, required bool dark}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.textPrimary(dark)),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: AppColors.textSecondary(dark)),
        prefixIcon: Icon(icon, color: color, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider(dark))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
        filled: true, fillColor: AppColors.background(dark), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap, bool dark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider(dark)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary(dark)))
      ),
    );
  }

  Widget _buildRouteCard(PlannedRoute r, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.surface(dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: r.segments.first.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(r.segments.first.icon, color: r.segments.first.color, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.fromName} - ${r.toName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary(dark))),
                  const SizedBox(height: 2),
                  Text('${r.transferCount} correspondance(s) • ${r.segments.length} étape(s)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark)))
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('~${r.totalMinutes} min', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
                  Text(ReliabilityLabel.estimatedDuration, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark)))
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.divider(dark)),
            const SizedBox(height: 12),
            ...r.segments.asMap().entries.map((entry) {
              final s = entry.value;
              final isLast = entry.key == r.segments.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)), if (!isLast) Expanded(child: Container(width: 2, color: AppColors.divider(dark)))]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Icon(s.icon, size: 14, color: s.color), const SizedBox(width: 6), Text(s.modeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: s.color)), const Spacer(), Text(s.departureTime ?? ReliabilityLabel.scheduleUnavailable, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)))]),
                          const SizedBox(height: 4),
                          Text('${s.from} - ${s.to}', style: TextStyle(fontSize: 12, color: AppColors.textPrimary(dark))),
                          const SizedBox(height: 2),
                          Text('Durée estimée : ~${s.durationMinutes} min', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ONGLET ALERTES OFFICIELLES (SOURCE FIABLE CETUD / SETER / DAKAR MOBILITE)
// ============================================================
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> officialAlerts = [
      {
        // GROUPE 5 — micro-correction (§6 : TER = 13 gares, ordre exact).
        //
        // AVANT : « (14 Gares) », « dessert officiellement 14 gares … Keur
        //         Massar … », badge « 14 Gares Officielles ».
        // PREUVE : ces trois textes sont une invention du source récupéré. Le
        //         binaire de production (gh-pages 94a84b6070569, main.dart.js)
        //         ne contient AUCUNE occurrence de « 14 Gares », « 14 gares »
        //         ni « Gares Officielles », et n'a aucune carte « Réseau CETUD
        //         & SETER ». Son alerte TER réelle annonce « 13 gares
        //         desservies ».
        // CONTRADICTION : `stop_keur_massar` est desservi par 6 lignes — DDD 23,
        //         AFTU 5, AFTU 38, AFTU 46, AFTU 53 et Tata 218 — et par
        //         AUCUNE ligne TER. Le présenter comme une gare du TER
        //         contredit le §6 et la source unique.
        // APRÈS : 13 gares, et les cinq gares citées en exemple sont toutes des
        //         gares TER officielles de `ter_dakar_diamniadio` — Colobane
        //         (#2), Hann (#3), Pikine (#6), Keur Mbaye Fall (#9,
        //         `stop_keur_mbaye_fall`) et Rufisque (#11). Keur Massar est
        //         remplacé par Keur Mbaye Fall, gare officielle dont le nom
        //         proche est la source vraisemblable de la confusion.
        // PÉRIMÈTRE : textes uniquement. Aucun widget, badge, icône, couleur,
        //         sévérité ni structure modifié ; JSON inchangé ; Keur Massar
        //         n'est ajouté à aucune donnée TER.
        'type': 'TER',
        'title': 'Réseau CETUD & SETER (13 Gares)',
        // Mission 3 : source alignée sur la provenance CONFIRMED de
        // `ter_dakar_diamniadio` (SETER — plan publié sur terdakar.sn). Le
        // CETUD n'est pas la source de la liste des 13 gares : retiré.
        'source': 'Source officielle : SETER (terdakar.sn)',
        'message': 'Le TER dessert officiellement 13 gares de Dakar à Diamniadio en passant par Colobane, Hann, Pikine, Keur Mbaye Fall et Rufisque.',
        'severity': 'success',
        'badge': '13 Gares Officielles',
        'icon': Icons.train_rounded,
        'color': AppColors.ter,
      },
      {
        // GROUPE 6 — corrections factuelles minimales. Rapport d'audit :
        // `docs/dakar-bus/groupe-6/RAPPORT_AUDIT.md`, incohérences E.2 et E.3.
        //
        // E.2 — « Grand Yoff » RETIRÉ de l'énumération du corridor.
        //   PREUVE : dans `dakar_network.json` (source unique), la ligne
        //   `brt_b1_guediawaye_petersen` compte 23 stations et AUCUNE ne porte
        //   ce nom. L'arrêt `stop_grand_yoff` (« Grand Yoff - BRT & AFTU Hub »)
        //   existe bien dans le JSON, mais il est desservi par des lignes DDD
        //   et AFTU — pas par le B1. Le citer comme station du corridor BRT
        //   contredisait donc la source unique. Les lieux conservés sont tous
        //   confirmés : Guédiawaye (#1), Dalal Jamm (#5), Parcelles Assainies
        //   (#8), Obélisque (#21), Petersen (#23).
        //   PÉRIMÈTRE : aucune station créée, la liste des 23 stations n'est
        //   pas modifiée, la carte et les polylignes ne sont pas touchées. La
        //   formulation retenue est celle que l'audit a classée « CONFIRMÉ PAR
        //   LES DONNÉES » (E.16) pour le descriptif BRT de l'assistant — les
        //   deux textes décrivent désormais le même corridor, sans qu'aucun
        //   des deux n'ait été inventé.
        //
        // E.3 — badge « En direct » remplacé par « Données officielles ».
        //   PREUVE : `DataStatus.live` n'est JAMAIS assigné dans `lib/` (enum
        //   déclaré L719, seule valeur effectivement utilisée : `scheduled`).
        //   Aucun flux temps réel n'existe : les trois cartes ci-dessus sont
        //   des littéraux statiques. Le badge affirmait donc un direct sans
        //   aucune donnée pour l'étayer, ce que le §18 interdit.
        //   Le libellé retenu s'appuie sur un statut RÉEL de la source unique :
        //   `brt_b1_guediawaye_petersen.data_trust == 'OFFICIAL'`
        //   (`DataTrust.official`). Aucun horodatage n'est créé, aucun statut
        //   REAL_TIME n'est introduit, aucune donnée nouvelle n'est inventée.
        'type': 'BRT',
        'title': 'Corridor officiel SunuBRT',
        // Mission 3 — AVANT : « Dakar Mobilité / CETUD », attribution sans
        // justification. APRÈS : source de la provenance CONFIRMED de
        // `brt_b1_guediawaye_petersen` (SunuBRT — sunubrt.sn).
        'source': 'Source officielle : SunuBRT (sunubrt.sn)',
        'message': 'Le corridor relie Guédiawaye à Petersen en passant par Dalal Jamm, Parcelles Assainies et la Place de l’Obélisque.',
        'severity': 'success',
        'badge': 'Données officielles',
        'icon': Icons.directions_bus_rounded,
        'color': AppColors.brt,
      },
      {
        // AUDIT DONNÉES 2026-09-24 — carte conservée (3 cartes, cf. groupe 6),
        // textes corrigés.
        // AVANT : « Source officielle : Direction DDD », « lignes régulières 1,
        //         3, 10, 14 et 20 aux horaires habituels », badge « Réseau
        //         actif », sévérité `success`.
        // PREUVE : aucune route DDD n'est CONFIRMED dans dakar_network.json ;
        //         demdikk.sn/reseau-urbain-dakar/ ne publie ni ligne 3 ni
        //         ligne 14 ; aucun horaire DDD n'existe dans les données.
        // APRÈS : seul le total officiel sourcé (38 lignes, CETUD) est
        //         affirmé ; les lignes de l'application sont déclarées non
        //         vérifiées ; aucun horaire ni état d'exploitation.
        'type': 'DDD',
        'title': 'Dakar Dem Dikk - Lignes Urbaines',
        'source': 'Total officiel : CETUD • itinéraires non vérifiés',
        'message': 'Le CETUD recense 38 lignes Dakar Dem Dikk. Les lignes DDD affichées dans l’application ne sont pas vérifiées : leurs itinéraires sont indicatifs et aucun horaire vérifié n’est disponible.',
        'severity': 'warning',
        'badge': 'Données non vérifiées',
        'icon': Icons.directions_bus_filled_rounded,
        'color': AppColors.ddd,
      },
    ];

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Alertes trafic & Réseau', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Niveau de vérification indiqué sur chaque carte (sources : SETER, SunuBRT, CETUD).', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),
                ...officialAlerts.map((alert) => _buildAlertCard(context, alert, dark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert, bool dark) {
    final Color alertColor = alert['color'] as Color;
    final IconData alertIcon = alert['icon'] as IconData;
    final String alertType = alert['type'] as String;
    final String alertBadge = alert['badge'] as String;
    final String alertSource = alert['source'] as String;
    final String alertMessage = alert['message'] as String;
    // Audit 2026-09-24 : le badge n'est vert que pour une donnée vérifiée.
    final Color badgeColor = alert['severity'] == 'success' ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: alertColor.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: alertColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(alertIcon, color: alertColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(alertType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: alertColor)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(alertBadge, style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold)))
                ]),
                const SizedBox(height: 4),
                Text(alertSource, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 6),
                Text(alertMessage, style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary(dark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DIRECT RUE & COMMUNAUTÉ
// ============================================================
class CommunityAlertsPage extends StatefulWidget {
  const CommunityAlertsPage({super.key});

  @override
  State<CommunityAlertsPage> createState() => CommunityAlertsPageState();
}

class CommunityAlertsPageState extends State<CommunityAlertsPage> {
  // GROUPE 6 — correction factuelle minimale. Rapport d'audit :
  // `docs/dakar-bus/groupe-6/RAPPORT_AUDIT.md`, incohérence E.4.
  //
  // AVANT : `time: 'Il y a 3 min'` et `'Il y a 6 min'` — chaînes FIGÉES,
  //         rendues telles quelles par le build (`Text(report['time']!)`).
  //         Elles affirmaient une ancienneté relative à l'instant présent
  //         alors qu'aucun horodatage n'existe : un signalement affiché
  //         « il y a 3 min » le restait indéfiniment, y compris après
  //         plusieurs jours. C'est présenter une donnée statique comme un
  //         événement temps réel actuellement observé (§18, §20).
  // PREUVE : `dakar_network.json` (source unique) ne contient aucune donnée de
  //         signalement ; il n'y a ni backend ni persistance ; `DataStatus.live`
  //         n'est jamais assigné dans `lib/`.
  // APRÈS : `'Sans horodatage'` — formulation explicitement NON temps réel,
  //         choisie parmi les deux options autorisées par la consigne (statut
  //         déjà présent, ou libellé explicitement non live). Aucune date ni
  //         heure n'est générée, aucun signalement n'est créé, la
  //         fonctionnalité est intégralement conservée.
  // PÉRIMÈTRE : mêmes clés, mêmes valeurs pour `user`/`location`/`type`, même
  //         structure de carte, même widget de rendu. Seule la chaîne `time`
  //         change. La clé `status` n'est lue par AUCUN widget (vérifié) :
  //         elle est laissée inchangée, hors périmètre.
  //
  // AUDIT DONNÉES 2026-09-24 (mission 3) — faux signalements RETIRÉS.
  // AVANT : deux signalements codés en dur, attribués à « Mamadou S. » et
  //         « Aïssatou N. » (« Trafic fluide » à Parcelles Assainies,
  //         « Embarquement régulier » à la gare de Dakar), rendus comme ceux
  //         d'usagers réels.
  // PREUVE : aucune source (ni JSON, ni backend, ni persistance) ; ces noms et
  //         ces états n'ont jamais été observés.
  // APRÈS : liste initiale VIDE → état vide explicite
  //         [ReliabilityLabel.noVerifiedReport]. La saisie par l'utilisateur
  //         (`_showAddReportModal`) est conservée ; son signalement reste local
  //         à la session et marqué non vérifié.
  final List<Map<String, String>> _communityReports = <Map<String, String>>[];

  void _showAddReportModal() {
    final locCtrl = TextEditingController();
    String selectedType = '🟢 Trafic fluide';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dark = globalState.darkMode;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouveau signalement rue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 14),
              TextField(
                controller: locCtrl,
                style: TextStyle(color: AppColors.textPrimary(dark)),
                decoration: InputDecoration(
                  labelText: 'Lieu / Station (ex: Colobane, UCAD...)',
                  labelStyle: TextStyle(color: AppColors.textSecondary(dark)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: AppColors.background(dark),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: AppColors.surface(dark),
                style: TextStyle(color: AppColors.textPrimary(dark)),
                items: ['🟢 Trafic fluide', '🟠 Ralentissement / Dense', '🔴 Gros bouchon / Bloqué', '🚌 Bus plein / Attente longue']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                onChanged: (val) => selectedType = val!,
                decoration: InputDecoration(
                  labelText: 'État constaté',
                  labelStyle: TextStyle(color: AppColors.textSecondary(dark)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: AppColors.background(dark),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (locCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _communityReports.insert(0, {
                        'user': 'Moi (Usager)',
                        'location': locCtrl.text.trim(),
                        'type': selectedType,
                        // Mission 3 : plus d'« À l'instant » figé (resté
                        // affiché indéfiniment) — statut explicite à la place.
                        'time': 'Non vérifié',
                        'status': selectedType.substring(0, 2),
                      });
                    });
                    Navigator.pop(context);
                    // Mission 3 : aucun backend — le signalement n'est ni publié ni
                    // partagé ; il reste affiché sur cet appareil, pour la session.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement ajouté sur cet appareil (non partagé, non vérifié).')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Publier mon signalement', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Direct rue & Communauté', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                      const SizedBox(height: 4),
                      // GROUPE 6 (E.4 / E.5) : « en temps réel » RETIRÉ —
                      // aucun flux live n'existe (aucune donnée de signalement
                      // dans la source unique, `DataStatus.live` jamais
                      // assigné). « usagistes » → « usagers » : c'est la seule
                      // formulation attestée, le binaire de production
                      // contenant exactement « Signalements en temps réel par
                      // les usagers à Dakar. » (`usagistes` : 0 occurrence).
                      // La structure du widget, son style et sa place dans la
                      // mise en page sont inchangés.
                      Text('Signalements publiés par les usagers à Dakar.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                    ])),
                    ElevatedButton.icon(
                      onPressed: _showAddReportModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Signaler'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Mission 3 : état vide explicite — aucune activité simulée.
                if (_communityReports.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider(dark))),
                    child: Text(ReliabilityLabel.noVerifiedReport, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                  ),
                ..._communityReports.map((report) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider(dark))),
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Text(report['user']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))), const Spacer(), Text(report['time']!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark)))]),
                            const SizedBox(height: 4),
                            Text('📍 ${report['location']} — ${report['type']}', style: TextStyle(fontSize: 13, color: AppColors.textPrimary(dark))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// REGLAGES (AVEC INFORMATIONS UTILES COMPLÈTES)
// ============================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showInfoModal(BuildContext context, String title, String content) {
    final dark = globalState.darkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 12),
              Text(content, style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary(dark))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Réglages & Préférences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                  child: Column(
                    children: [
                      SwitchListTile(secondary: const Icon(Icons.notifications_outlined, color: AppColors.primary), title: Text('Notifications trafic', style: TextStyle(color: AppColors.textPrimary(dark))), value: true, activeColor: AppColors.primary, onChanged: (_) {}),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      SwitchListTile(secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary), title: Text('Mode sombre', style: TextStyle(color: AppColors.textPrimary(dark))), value: dark, activeColor: AppColors.primary, onChanged: (v) => globalState.toggleDarkMode(v)),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: AppColors.primary),
                        title: Text('Comment utiliser l’application', style: TextStyle(color: AppColors.textPrimary(dark))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showInfoModal(context, 'Comment utiliser l’application', '1. Utilisez l’onglet Explorer pour visualiser votre position GPS en temps réel et les arrêts à proximité.\n2. Maintenez un arrêt enfoncé pour l’ajouter à vos favoris ⭐.\n3. Utilisez l’onglet Trajets pour planifier vos déplacements multimodaux (TER, BRT, DDD, TATA) ; les itinéraires non vérifiés sont signalés comme tels.\n4. Interrogez l’Assistant IA pour toute question sur les lignes. Aucun horaire vérifié n’est disponible pour l’instant.'),
                      ),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                        title: Text('Conditions d’utilisation', style: TextStyle(color: AppColors.textPrimary(dark))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showInfoModal(context, 'Conditions d’utilisation', 'Dakar Bus fournit des informations de transport indicatives. Seules les données dont la source officielle a été vérifiée (SETER, SunuBRT) sont présentées comme officielles ; les autres itinéraires (DDD, AFTU, TATA) sont signalés comme non vérifiés. Aucun horaire ni aucune position de véhicule en temps réel ne sont fournis.'),
                      ),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: AppColors.primary),
                        title: Text('Qui sommes-nous ?', style: TextStyle(color: AppColors.textPrimary(dark))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showInfoModal(context, 'Qui sommes-nous ?', 'Dakar Bus est la plateforme de référence multimodale conçue pour faciliter la mobilité urbaine à Dakar. Notre mission est d’offrir à chaque usager une visibilité totale sur les réseaux de transport et de fluidifier les déplacements quotidiens.'),
                      ),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      ListTile(leading: const Icon(Icons.verified, color: AppColors.primary), title: Text('Version de l’application', style: TextStyle(color: AppColors.textPrimary(dark))), subtitle: Text('Dakar Bus v9.4 (Web Fix)', style: TextStyle(color: AppColors.textSecondary(dark)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// RÉPONSES DE L'ASSISTANT — CONSTRUITES À PARTIR DES DONNÉES (audit 2026-09-24)
// ============================================================
// AVANT : textes figés affirmant « 14 gares officielles », « un départ toutes
//         les 10 à 20 min », « L1 Colobane-Yoff, L3 Sandaga-Ouakam », « 72
//         lignes AFTU couvrent tout Dakar », « Les réseaux … fonctionnent
//         normalement », et pour un trajet « 🕒 hh:mm → hh:mm … Direct /
//         Rotation ~5 min » calculés sans horaire.
// APRÈS : chaque réponse est dérivée des opérateurs et routes chargés, avec
//         leur statut de provenance. Une fréquence officielle applicable est
//         qualifiée ESTIMATED ; aucune heure fixe ou donnée LIVE n'est inventée.
class AssistantReplies {

  /// Texte d'un itinéraire calculé. Sans horaire programmé fourni, la phrase
  /// imposée [ReliabilityLabel.noVerifiedSchedule] remplace toute heure.
  static String itinerary(PlannedRoute r, String from, String to) {
    final buf = StringBuffer();
    buf.writeln('🧭 Itinéraire trouvé : $from → $to');
    buf.writeln('⏱️ Durée estimée : ~${r.totalMinutes} min (estimation non vérifiée) • ${r.transferCount} correspondance(s)');
    buf.writeln('');
    for (int i = 0; i < r.segments.length; i++) {
      final s = r.segments[i];
      buf.writeln('${i + 1}. ${s.modeLabel} : ${s.from} → ${s.to}');
      if (s.status == DataStatus.scheduled && s.departureTime != null && s.arrivalTime != null) {
        buf.writeln('   🕒 Horaire programmé : ${s.departureTime} → ${s.arrivalTime}');
      } else if (s.status == DataStatus.estimated && s.departureInfo != null) {
        buf.writeln('   🕒 ${s.departureInfo!.label} — estimation non garantie');
      } else {
        buf.writeln('   🕒 ${ReliabilityLabel.noVerifiedSchedule}');
      }
      buf.writeln('   Durée estimée : ~${s.durationMinutes} min (estimation non vérifiée)');
    }
    return buf.toString();
  }

  static const Map<String, String> _prefix = <String, String>{
    'ter': '🚆 [Mémorisé : TER]',
    'brt': '🚌 [Mémorisé : SunuBRT]',
    'ddd': '🚍 [Mémorisé : Dakar Dem Dikk]',
    'tata': '🚐 [Mémorisé : Bus TATA]',
    'aftu': '🚐 [Mémorisé : AFTU]',
  };

  /// Présentation d'un réseau, dérivée des données : lignes CONFIRMED listées
  /// avec leur nombre d'arrêts et leur source ; lignes non vérifiées,
  /// contestées ou futures seulement comptées, et qualifiées comme telles.
  static String modeInfo(String operatorId, List<Operator> operators, List<TransportRoute> routes) {
    Operator? op;
    for (final o in operators) {
      if (o.id == operatorId) op = o;
    }
    final mine = routes.where((r) => r.operatorId == operatorId).toList();
    final confirmed = mine.where((r) => r.provenance.status == ProvenanceStatus.confirmed).toList();
    final int unverified = mine.where((r) => r.provenance.status == ProvenanceStatus.unverified).length;
    final int conflicting = mine.where((r) => r.provenance.status == ProvenanceStatus.conflicting).length;
    final int future = mine.where((r) => r.provenance.status == ProvenanceStatus.future).length;

    final buf = StringBuffer(_prefix[operatorId] ?? '🚍');
    final Operator? found = op;
    if (found != null && found.officialLineCount != null && found.officialLineCountSource != null) {
      buf.write(' Selon ${found.officialLineCountSource}, le réseau ${found.name} compte ${found.officialLineCount} ligne(s).');
    }
    if (mine.isEmpty) {
      buf.write(" L'application ne contient aucune ligne de ce réseau.");
    } else {
      for (final r in confirmed) {
        final src = r.provenance.source;
        buf.write(' ${r.shortName} (${r.longName}) : ${r.stopIds.length} arrêts${src == null ? '' : ' (source : $src)'}.');
      }
      final int notConfirmed = unverified + conflicting;
      if (notConfirmed > 0) {
        buf.write(' $notConfirmed ligne(s) de l’application ne sont pas vérifiées');
        if (conflicting > 0) buf.write(', dont $conflicting signalée(s) comme contradictoire(s) par l’audit');
        buf.write(' : leurs itinéraires sont indicatifs.');
      }
      if (future > 0) buf.write(' $future ligne(s) annoncée(s), pas encore en service.');
    }
    buf.write(" Je ne dispose d'aucun horaire ni d'aucune fréquence vérifiés pour ce réseau.");
    buf.write(' Dis-moi ton départ et ton arrivée pour un itinéraire.');
    return buf.toString();
  }
}

// ============================================================
// ASSISTANT IA INTELLIGENT, CONTEXTUEL ET MEMORISATEUR DE MOBILITE
// ============================================================
class AIChatPage extends StatefulWidget {
  final LatLng? userPosition;
  const AIChatPage({super.key, this.userPosition});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Nanga def ! 👋 Je suis votre assistant IA expert des mobilités à Dakar. Posez-moi vos questions sur les lignes TER, BRT, DDD, TATA et AFTU ou demandez-moi un itinéraire. Ex: « Je suis à Petersen, je veux aller à Keur Mbaye Fall »'}
  ];

  String? _dernierModeInterroge;

  // Extrait départ/destination d’un message naturel
  Map<String, String?> _extractTrip(String text) {
    String? from;
    String? to;
    final lower = text.toLowerCase();
    // Patterns fréquents
    // 1) "je suis à X je veux aller à Y" / "je suis a X je veux aller a Y"
    final m1 = RegExp(r"je\s+suis\s+(?:à|a)\s+(.+?)\s+je\s+veux\s+aller\s+(?:à|a)\s+(.+)", caseSensitive: false).firstMatch(text);
    if (m1 != null) {
      from = m1.group(1)?.trim();
      to = m1.group(2)?.trim();
      return {'from': from, 'to': to};
    }
    // 2) "de X à Y" / "de X a Y"
    final m2 = RegExp(r"de\s+(.+?)\s+(?:à|a)\s+(.+)", caseSensitive: false).firstMatch(text);
    if (m2 != null) {
      // évite de capter "depuis" tout seul
      final candFrom = m2.group(1)?.trim() ?? "";
      final candTo = m2.group(2)?.trim() ?? "";
      if (candFrom.length > 2 && candTo.length > 2 && !candFrom.toLowerCase().contains("puis")) {
        from = candFrom;
        to = candTo;
        // Nettoie "je veux aller" ou "comment aller" devant
        from = from.replaceAll(RegExp(r"^(je\s+veux\s+aller|comment\s+aller|aller)\s+", caseSensitive: false), "").trim();
        to = to.replaceAll(RegExp(r"[\?\.!]+$"), "").trim();
        return {'from': from, 'to': to};
      }
    }
    // 3) "je veux aller à Y" (sans from explicite) -> from = position GPS ou "Ma position"
    final m3 = RegExp(r"je\s+veux\s+aller\s+(?:à|a)\s+(.+)", caseSensitive: false).firstMatch(text);
    if (m3 != null) {
      to = m3.group(1)?.trim().replaceAll(RegExp(r"[\?\.!]+$"), "");
      // cherche un "je suis à X" avant
      final mFrom = RegExp(r"je\s+suis\s+(?:à|a)\s+(.+?)(?:\s+je\s+veux|$)", caseSensitive: false).firstMatch(text);
      if (mFrom != null) {
        from = mFrom.group(1)?.trim();
      } else if (lower.contains("dakar") && !lower.contains("keur") && !lower.contains("petersen")) {
        from = "Dakar";
      } else {
        from = null; // sera remplacé par GPS si dispo
      }
      return {'from': from, 'to': to};
    }
    return {'from': null, 'to': null};
  }

  String _formatRouteResult(RouteSearchResult res, String from, String to) {
    if (res.errorMessage != null) return '⚠️ ${res.errorMessage}';
    if (!res.hasRoutes) return 'Aucun itinéraire trouvé entre $from et $to.';
    final r = res.routes.first;
    final buf = StringBuffer(AssistantReplies.itinerary(r, from, to));
    buf.writeln('');
    buf.writeln('💡 Astuce : ouvre l\'onglet "Trajets" pour voir le détail sur la carte.');
    // ✅ CORRECTION HORS ZONE : le tri « des arrêts proches » n'est réellement
    //    pris en compte que depuis la zone de service — hors zone, cette
    //    mention mensongère n'est pas affichée.
    if (GpsResolver.isWithinServiceZone(widget.userPosition)) {
      buf.writeln('📍 Position GPS prise en compte pour le tri des arrêts proches.');
    }
    return buf.toString();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _msgCtrl.clear();
    });

    final lower = text.toLowerCase();
    String aiReply;
    bool isTripRequest = lower.contains('aller') || lower.contains('trajet') || lower.contains('veux aller') || lower.contains('comment aller') || RegExp(r"de\s+.+\s+(?:à|a)\s+.+").hasMatch(lower);

    if (isTripRequest) {
      final trip = _extractTrip(text);
      String? from = trip['from'];
      String? to = trip['to'];
      // Si from manquant mais GPS dispo DANS LA ZONE DE SERVICE, utilise l'arrêt le plus proche.
      // ✅ CORRECTION HORS ZONE : depuis la France, l'arrêt « le plus proche »
      //    serait un arrêt de Dakar à ~14 000 km présenté comme origine —
      //    repli sur « Dakar » (ci-dessous) au lieu d'une origine trompeuse.
      if ((from == null || from.isEmpty) &&
          GpsResolver.isWithinServiceZone(widget.userPosition)) {
        // trouve l'arrêt le plus proche de la position
        Stop? nearest;
        double best = double.infinity;
        for (final s in allStops) {
          final d = DistanceHelper.haversineMeters(widget.userPosition!, s.location);
          if (d < best) { best = d; nearest = s; }
        }
        if (nearest != null) {
          from = nearest.name;
        }
      }
      if (from == null || from.isEmpty) {
        from = "Dakar";
      }
      if (to == null || to.isEmpty) {
        aiReply = '🧭 Pour calculer ton itinéraire, précise ta destination. Exemple : "Je suis à Petersen, je veux aller à Keur Mbaye Fall" ou "De Colobane à Yoff"';
      } else {
        final res = RoutePlanner.plan(fromQuery: from, toQuery: to);
        aiReply = _formatRouteResult(res, from, to);
        // Mémorise le mode du premier segment
        if (res.hasRoutes && res.routes.first.segments.isNotEmpty) {
          _dernierModeInterroge = res.routes.first.segments.first.modeLabel;
        }
      }
    } else if (lower.contains('ter') || lower.contains('train') || lower.contains('diamniadio')) {
      _dernierModeInterroge = 'TER';
      aiReply = AssistantReplies.modeInfo('ter', appDataService.operators, appDataService.routes);
    } else if (lower.contains('brt') || lower.contains('guédiawaye') || lower.contains('petersen') || lower.contains('sunu')) {
      _dernierModeInterroge = 'BRT';
      aiReply = AssistantReplies.modeInfo('brt', appDataService.operators, appDataService.routes);
    } else if (lower.contains('ddd') || lower.contains('dakar dem dikk') || lower.contains('ligne 1') || lower.contains('ligne 3')) {
      _dernierModeInterroge = 'DDD';
      aiReply = AssistantReplies.modeInfo('ddd', appDataService.operators, appDataService.routes);
    } else if (lower.contains('tata') || lower.contains('minibus') || lower.contains('ligne 50')) {
      _dernierModeInterroge = 'TATA';
      aiReply = AssistantReplies.modeInfo('tata', appDataService.operators, appDataService.routes);
    } else if (lower.contains('aftu') || lower.contains('parcelles') || lower.contains('grand yoff')) {
      _dernierModeInterroge = 'AFTU';
      aiReply = AssistantReplies.modeInfo('aftu', appDataService.operators, appDataService.routes);
    } else if (lower.contains('où suis-je') || lower.contains('ou suis je') || lower.contains('autour de moi') || lower.contains('proche')) {
      if (GpsResolver.isWithinServiceZone(widget.userPosition)) {
        final nearby = allStops.map((s) => MapEntry(s, DistanceHelper.haversineMeters(widget.userPosition!, s.location))).toList()..sort((a,b)=>a.value.compareTo(b.value));
        final top = nearby.take(3).map((e)=> '- ${e.key.name} (${DistanceHelper.format(e.value)} • ${e.key.modeLabel})').join('\n');
        aiReply = '📍 Tu es près de :\n$top\n\nJe peux te guider vers une destination. Où veux-tu aller ?';
      } else if (widget.userPosition != null) {
        // ✅ CORRECTION HORS ZONE : position réelle mais hors de la zone de
        //    service — aucune distance de proximité n'est calculée (elle
        //    serait de plusieurs milliers de kilomètres) ; le message de zone
        //    existant est rappelé, l'exploration reste possible.
        aiReply = '${GpsResolver.outOfCoverageMessage}.\n\n'
            'Tu peux explorer la carte de Dakar et ses arrêts, ou me demander '
            'un itinéraire entre deux arrêts.';
      } else {
        aiReply = '📍 Active ton GPS via "Activer GPS" sur la carte, puis je pourrai te montrer les arrêts autour de toi et planifier un trajet.';
      }
    } else if (lower.contains('alerte') || lower.contains('bouchon') || lower.contains('trafic') || lower.contains('direct rue')) {
      // Audit 2026-09-24 : aucun flux temps réel ni état du trafic n'existe ;
      // l'assistant ne propose plus de « vérifier le trafic ».
      aiReply = '🚨 Je ne dispose d\'aucune information vérifiée sur l\'état du trafic. Consulte l\'onglet "Alertes" (informations réseau, avec leur niveau de vérification) et "Direct rue" (signalements d\'usagers, non vérifiés). Tu peux aussi publier un signalement.';
    } else {
      aiReply = '🚍 Je ne dispose d\'aucune information vérifiée sur l\'état du trafic des réseaux TER, BRT, DDD, TATA et AFTU. Pour un itinéraire, dis-moi : "Je suis à X, je veux aller à Y" ou "De X à Y". Exemple : "Je suis à Dakar, je veux aller à Keur Mbaye Fall" → je te propose un itinéraire en TER.';
      if (_dernierModeInterroge != null) {
        aiReply += '\n💡 (Mémorisé : $_dernierModeInterroge)';
      }
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() { _messages.add({'role': 'ai', 'text': aiReply}); });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          appBar: AppBar(title: const Text('Assistant IA - Dakar Bus'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          body: Container(
            color: AppColors.background(dark),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (c, i) {
                      final msg = _messages[i];
                      final isAi = msg['role'] == 'ai';
                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAi ? AppColors.surface(dark) : AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider(dark)),
                          ),
                          child: Text(msg['text']!, style: TextStyle(color: isAi ? AppColors.textPrimary(dark) : Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.surface(dark),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _msgCtrl, style: TextStyle(color: AppColors.textPrimary(dark)), decoration: InputDecoration(hintText: 'Posez votre question sur un trajet ou une mobilité...', hintStyle: TextStyle(color: AppColors.textSecondary(dark)), border: InputBorder.none))),
                    IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _sendMessage),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PAGE DE ROUTE DETAILLEE
// ============================================================
class DetailedRoutePage extends StatelessWidget {
  final DetailedRoute route;
  const DetailedRoutePage({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final validPoints = route.stops.map((s) => s.location).where((pt) => DakarBounds.isValid(pt)).toList();

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          appBar: AppBar(title: Text('${route.operator} — ${route.origin}'), backgroundColor: route.color, foregroundColor: Colors.white),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: route.color.withOpacity(0.3), width: 1.5)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${route.origin} ➔ ${route.destination}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary(dark))),
                      const SizedBox(height: 4),
                      Text('${route.totalDistance} • ${route.stops.length} stations/arrêts', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: route.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(route.operator, style: TextStyle(fontWeight: FontWeight.bold, color: route.color, fontSize: 11))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider(dark))),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(initialCenter: validPoints.isNotEmpty ? validPoints.first : const LatLng(14.7167, -17.4677), initialZoom: 11.5),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus', maxZoom: 19),
                    if (validPoints.length > 1) PolylineLayer(polylines: [Polyline(points: validPoints, color: route.color, strokeWidth: 5.0)]),
                    MarkerLayer(markers: route.stops.where((s) => DakarBounds.isValid(s.location)).map((s) => Marker(point: s.location, width: 24, height: 24, child: Container(decoration: BoxDecoration(color: route.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.location_on, color: Colors.white, size: 12)))).toList()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Arrêts & Gares alignés — ${route.operator}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 12),
              ...route.stops.asMap().entries.map((entry) {
                final idx = entry.key; final stop = entry.value; final isLast = idx == route.stops.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(children: [
                        Container(width: 26, height: 26, decoration: BoxDecoration(color: route.color, shape: BoxShape.circle), child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                        if (!isLast) Expanded(child: Container(width: 3, color: route.color.withOpacity(0.4))),
                      ]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider(dark))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(stop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark)))),
                                  // Audit 2026-09-24 — AVANT : « [OFFICIEL] » sur TOUS les arrêts,
                                  // quel que soit le statut. APRÈS : badge dérivé du statut le moins
                                  // sûr (ligne, arrêt) ; vert seulement si CONFIRMED.
                                  Builder(builder: (context) {
                                    final ProvenanceStatus st = route.statusOf(stop);
                                    final Color c = ReliabilityLabel.canShowOfficial(st) ? AppColors.success : AppColors.warning;
                                    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('[${ReliabilityLabel.badge(st)}]', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c)));
                                  }),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.access_time, size: 12, color: route.color),
                                  const SizedBox(width: 4),
                                  // Audit 2026-09-24 — AVANT : « Heure : ~N min » (N = rang × 3,
                                  // hypothèse non sourcée) lu comme une heure. Aucun horaire n'existe
                                  // dans les données : `estimatedTime` reste dans le modèle, non affiché.
                                  Text(ReliabilityLabel.scheduleUnavailable, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary(dark))),
                                  const Spacer(),
                                  Text('📍 ${stop.distanceFromStart}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// DETAIL ARRET — ALLER / RETOUR SYNCHRONISE
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final allerStop = stop.copyWith(
      direction: stop.direction.contains('Dir.') ? stop.direction : 'Dir. Diamniadio (Embarquement)',
      stopType: StopType.boarding,
    );

    // GROUPE 3 (§10, §12) — AVANT : l'absence de correspondance fiable était
    // masquée par un arrêt FABRIQUÉ, `stop.copyWith(direction: 'Dir. Dakar /
    // Centre')` : le MÊME arrêt, affublé d'un libellé de sens inventé, présenté
    // dans l'onglet « Sens Retour » comme un vis-à-vis réel. C'est forcer une
    // correspondance, ce que le §12 interdit.
    // APRÈS : le `null` renvoyé par le service est conservé tel quel et l'onglet
    // affiche un état « non identifié » explicite.
    //
    // Limite structurelle portée au rapport : `dakar_network.json` ne contient
    // AUCUN champ de sens — un arrêt n'y porte que id, name, latitude,
    // longitude et data_trust. La « direction » que compare la passe 2 est donc
    // un libellé synthétisé par `_integrateNetworkData` d'après la position de
    // l'arrêt dans sa ligne, et non un sens réel issu de la source unique.
    // L'algorithme de production `adD` fonctionnait déjà sur ce même champ ; il
    // est réintégré à l'identique, et cette limite est documentée plutôt que
    // corrigée ici (la correction exigerait de créer un sens que la donnée ne
    // fournit pas, ce qui serait une invention).
    final Stop? retourStop =
        OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(stop.name),
          backgroundColor: stop.color,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Sens Aller / Départ', icon: Icon(Icons.arrow_forward, size: 16)),
              Tab(text: 'Sens Retour', icon: Icon(Icons.arrow_back, size: 16)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleStopView(stop: allerStop),
            // §12 : aucune correspondance fiable -> état explicite, jamais un
            // arrêt inventé. L'architecture à deux onglets, leurs libellés et
            // les styles sont conservés à l'identique (§21) : seul le contenu
            // de l'onglet « Sens Retour » cesse d'être fabriqué.
            if (retourStop != null)
              SingleStopView(stop: retourStop)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Arrêt en face non identifié\n\n'
                    'Aucune correspondance fiable dans les données réseau '
                    'pour « ${stop.name} ».',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary(globalState.darkMode)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// VUE UNIQUE POUR UN SENS DONNE
// ============================================================
class SingleStopView extends StatelessWidget {
  final Stop stop;
  const SingleStopView({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    const String crowd = ReliabilityLabel.crowdUnavailable;
    // GROUPE 2 (§8) : `null` quand la ligne est indérivable des données
    // courantes — un « inconnu » honnête (§12), jamais une fiche inventée.
    final DetailedRoute? routeDetails = DetailedRoute.fromStop(stop);

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        final isFav = globalState.isFavorite(stop.name);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(dark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: stop.color.withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: stop.color, radius: 20, child: Icon(stop.icon, color: Colors.white, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary(dark))),
                            const SizedBox(height: 2),
                            Text(stop.direction, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary(dark))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.grey),
                        onPressed: () => globalState.toggleFavorite(stop.name),
                        tooltip: 'Favori',
                      ),
                    ],
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.divider(dark))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prochain départ programmé', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                            const SizedBox(height: 2),
                            Text(
                              stop.nextDepartureLabel() ?? ReliabilityLabel.scheduleUnavailable,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stop.color),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Affluence', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                          const SizedBox(height: 2),
                          Text(crowd, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              // GROUPE 2 (§12) : bouton désactivé quand la ligne ne peut pas
              // être dérivée de la source unique. Aucune fiche fabriquée n'est
              // proposée en remplacement ; le composant et son style restent
              // inchangés (§21).
              onPressed: routeDetails == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailedRoutePage(route: routeDetails))),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Voir la ligne complète & stations', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: stop.color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }
}