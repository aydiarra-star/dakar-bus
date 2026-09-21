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
class OppositeStopService {
  static const double _maxOppositeDistanceMeters = 500.0;

  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    for (final stop in allStops) {
      if (identical(stop, currentStop)) continue;
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= 50.0 && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }
    if (bestCandidate != null) return bestCandidate;

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
    return bestCandidate;
  }
}

// ============================================================
// GENERATEUR D HORAIRES DYNAMIQUES & ROTATIONS CONTINUES
// ============================================================
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) { list.add(m); }
  return list;
}
List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);
final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
final List<int> _terBase = _buildTerBase();

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
  static const demdikk = DataSourceInfo(origin: DataOrigin.official, label: 'Dakar Dem Dikk (Officiel)', badgeEmoji: '🟢');
  static const tataOfficial = DataSourceInfo(origin: DataOrigin.verified, label: 'Bus TATA (Officiel)', badgeEmoji: '🔵');
  static const aftuOfficial = DataSourceInfo(origin: DataOrigin.verified, label: 'AFTU (72 Lignes Officielles)', badgeEmoji: '🔵');
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

  DetailedRoute({
    required this.routeId,
    required this.lineNumber,
    required this.operator,
    required this.color,
    required this.origin,
    required this.destination,
    required this.totalDistance,
    required this.stops,
  });

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
  final Color color; final LatLng location; final DataStatus status;
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

  const Stop({
    required this.name, required this.direction, required this.distanceMeters,
    required this.departureMinutesFromMidnight, required this.icon, required this.color,
    required this.location, required this.modeLabel, this.status = DataStatus.scheduled,
    this.source = DataSourceInfo.demo, this.stopType = StopType.departure,
    this.stopId,
  });

  Stop copyWith({
    String? name, String? direction, double? distanceMeters,
    List<int>? departureMinutesFromMidnight, IconData? icon, Color? color,
    LatLng? location, DataStatus? status, String? modeLabel,
    DataSourceInfo? source, StopType? stopType, String? stopId,
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
  );

  bool get isContinuousFlow => modeLabel == 'AFTU' || modeLabel == 'Tata' || modeLabel == 'DDD';

  bool _isServiceOpen() {
    final now = DateTime.now();
    final hour = now.hour;
    int startHour = isContinuousFlow ? 6 : 5;
    if (hour >= startHour && hour < 22) return true;
    if (!isContinuousFlow && hour == 22 && now.minute <= 30) return true;
    return false;
  }

  int? nextDepartureMinutes() {
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return 5;
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d >= currentMin && (d - currentMin) <= 180) return d;
    }
    return null;
  }

  int? remainingMinutes() {
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return 5;
    final d = nextDepartureMinutes();
    if (d == null) return null;
    return d - (DateTime.now().hour * 60 + DateTime.now().minute);
  }

  String? nextDepartureLabel() {
    if (!_isServiceOpen()) return 'Service fermé';
    if (isContinuousFlow) return 'En rotation (~5 min)';
    final d = nextDepartureMinutes();
    if (d == null) return 'Prochainement';
    final normalized = d % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}';
  }

  int? departureAfter(int minFromMidnight) {
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return minFromMidnight + 5;
    for (final d in departureMinutesFromMidnight) { if (d > minFromMidnight) return d; }
    return null;
  }
}

enum DataStatus { scheduled, live, unknown }

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
  const RouteSegment({required this.modeLabel, required this.color, required this.icon, required this.from, required this.to, required this.durationMinutes, this.departureTime, this.arrivalTime, this.status = DataStatus.scheduled, this.isWalk = false});
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
// ============================================================
final List<Stop> terStations = [
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7190, -17.4450), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: _shift(_terBase, 17), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7550, -17.3900), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Dakar / Diamniadio', distanceMeters: 14200, departureMinutesFromMidnight: _shift(_terBase, 27), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7750, -17.3100), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.correspondence),
  Stop(name: 'Gare TER Diamniadio', direction: 'Dir. Dakar (Embarquement)', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 50), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7160, -17.1986), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio (Arrivée)', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 48), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7163, -17.1980), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
];

final List<Stop> brtStations = [
  Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: _shift(_brtBase, 0), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6720, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guediawaye', distanceMeters: 1500, departureMinutesFromMidnight: _shift(_brtBase, 4), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7050, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'PEM Guediawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: _shift(_brtBase, 8), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7735, -17.3977), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
];

// Lignes DDD Intégrées Officiellement
final List<Stop> dddStations = [
  Stop(name: 'DDD Ligne 1 (Colobane - Yoff)', direction: 'Dir. Yoff Pêcheurs', distanceMeters: 1200, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6950, -17.4440), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 3 (Sandaga - Ouakam)', direction: 'Dir. Cité Mamelles', distanceMeters: 900, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6730, -17.4420), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 10 (Liberté 6 - Patte d’Oie)', direction: 'Dir. Terminus Parcelles', distanceMeters: 2400, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.7150, -17.4580), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.correspondence),
  Stop(name: 'DDD Ligne 14 (Gare Maritime - UCAD)', direction: 'Dir. Université Cheikh Anta Diop', distanceMeters: 1800, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6900, -17.4600), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 20 (Petersen - Rufisque)', direction: 'Dir. Gare Rufisque', distanceMeters: 500, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6720, -17.4390), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.terminus),
];

// Bus TATA Intégrés Officiellement
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

final List<Stop> allStops = [...terStations, ...brtStations, ...dddStations, ...tataStations, ...aftuAndBusStations]
    .where((s) => DakarBounds.isValid(s.location))
    .toList();

// ============================================================
// INTEGRATION DataService → Stop / TransitRoute (Appelé depuis main())
// ============================================================
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
      final source = sourceForOperator(route.operatorId);
      final key = '${busStop.name}_${busStop.latitude}_${busStop.longitude}';
      if (existingKeys.contains(key)) continue;

      // Horaires : TER/BRT avec base, AFTU/DDD en rotation continue (liste vide)
      List<int> schedule = [];
      if (label == 'TER') {
        schedule = _shift(_terBase, i * 2);
      } else if (label == 'BRT') {
        schedule = _shift(_brtBase, i * 2);
      } else {
        schedule = []; // AFTU/DDD/Tata → isContinuousFlow = true
      }

      final stop = Stop(
        name: busStop.name,
        stopId: busStop.id,
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
// TRACES DES ROUTES
// ============================================================
final List<TransitRoute> demoRoutes = [
  TransitRoute(
    name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter,
    points: [
      const LatLng(14.6792, -17.4407), const LatLng(14.6937, -17.4441),
      const LatLng(14.7190, -17.4450), const LatLng(14.7550, -17.3900),
      const LatLng(14.7750, -17.3100), const LatLng(14.7160, -17.1986),
    ],
  ),
  TransitRoute(
    name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt,
    points: [
      const LatLng(14.6720, -17.4400), const LatLng(14.6850, -17.4500),
      const LatLng(14.7100, -17.4650), const LatLng(14.7150, -17.4580),
      const LatLng(14.7050, -17.4400), const LatLng(14.7220, -17.4420),
      const LatLng(14.7350, -17.4350), const LatLng(14.7480, -17.4250),
      const LatLng(14.7620, -17.4100), const LatLng(14.7735, -17.3977),
    ],
  ),
  TransitRoute(
    name: 'DDD Lignes', code: 'DDD', type: 'DDD', color: AppColors.ddd,
    points: [
      const LatLng(14.6950, -17.4440), const LatLng(14.6730, -17.4420), const LatLng(14.6720, -17.4390),
    ],
  ),
  TransitRoute(
    name: 'TATA Bus', code: 'TATA', type: 'Tata', color: AppColors.tata,
    points: [
      const LatLng(14.7700, -17.3950), const LatLng(14.7500, -17.3880), const LatLng(14.7120, -17.4650),
    ],
  ),
];

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    final now = DateTime.now();
    final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);
    if (!isOpen) {
      return const RouteSearchResult(errorMessage: '🌙 Les réseaux TER, BRT, DDD et TATA sont actuellement fermés (Service de 5h00 à 22h30).');
    }

    final fromStop = _findNearestStop(fromQuery);
    final toStop = _findNearestStop(toQuery);

    if (fromStop == null) return const RouteSearchResult(errorMessage: 'Lieu de départ introuvable.');
    if (toStop == null) return const RouteSearchResult(errorMessage: 'Destination introuvable.');

    final currentMin = now.hour * 60 + now.minute;
    final candidates = <PlannedRoute>[];

    if (fromStop.modeLabel == toStop.modeLabel) {
      final direct = _buildRoute(fromStop, toStop, currentMin);
      if (direct != null) candidates.add(direct);
    }

    if (candidates.isEmpty || candidates.first.totalMinutes > 45) {
      final transfer = _findTransfer(fromStop, toStop, currentMin);
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
    if (q.isEmpty) return null;
    for (final s in allStops) {
      if (s.name.toLowerCase().contains(q)) return s;
    }
    return allStops.firstWhere((s) => s.name.toLowerCase().contains('dakar'), orElse: () => allStops.first);
  }

  static PlannedRoute? _buildRoute(Stop from, Stop to, int currentMin) {
    final dist = DistanceHelper.haversineMeters(from.location, to.location);
    final speed = (from.modeLabel == 'TER' || from.modeLabel == 'BRT') ? 35.0 : 20.0;
    int dur = ((dist / 1000.0) / speed * 60).ceil();
    if (dur < 5) dur = 5;

    final safeCurrentMin = math.max(0, currentMin);
    final dep = from.departureAfter(safeCurrentMin) ?? safeCurrentMin;
    final arr = dep + dur;

    return PlannedRoute(
      fromName: from.name, toName: to.name, totalMinutes: dur,
      transferCount: 0, status: DataStatus.scheduled,
      segments: [RouteSegment(modeLabel: from.modeLabel, color: from.color, icon: from.icon, from: from.name, to: to.name, durationMinutes: dur, departureTime: _formatMin(dep), arrivalTime: _formatMin(arr), status: DataStatus.scheduled)],
    );
  }

  static PlannedRoute? _findTransfer(Stop from, Stop to, int currentMin) {
    final hub = allStops.firstWhere((s) => s.name.contains('Colobane') || s.name.contains('Petersen'), orElse: () => allStops.first);
    if (hub.name == from.name || hub.name == to.name) return null;

    final leg1 = _buildRoute(from, hub, currentMin);
    if (leg1 == null) return null;
    final leg2 = _buildRoute(hub, to, (currentMin + leg1.totalMinutes));
    if (leg2 == null) return null;

    return PlannedRoute(
      fromName: from.name, toName: to.name,
      totalMinutes: leg1.totalMinutes + leg2.totalMinutes + 5,
      transferCount: 1, status: DataStatus.scheduled,
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

  static String getCrowdLevel(Stop stop) {
    final now = DateTime.now();
    final h = now.hour;
    if ((h >= 7 && h <= 9) || (h >= 17 && h <= 19)) {
      return '🔴 Bondé (Heure de pointe)';
    } else if ((h >= 10 && h <= 16)) {
      return '🟠 Dense';
    }
    return '🟢 Fluide';
  }
}

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Timer? _ticker;
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
  void dispose() { _ticker?.cancel(); super.dispose(); }

  Future<void> _requestLocation() async {
    setState(() { _gpsState = GpsState.loading; _gpsMessage = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() { _gpsState = GpsState.serviceDisabled; _gpsMessage = 'GPS désactivé.'; }); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _gpsState = GpsState.denied; _gpsMessage = 'Permission GPS refusée.'; }); return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      if (DakarBounds.isValid(latLng)) {
        setState(() { _userPosition = latLng; _gpsState = GpsState.granted; _gpsMessage = null; });
      } else {
        setState(() { _userPosition = const LatLng(14.7167, -17.4677); _gpsState = GpsState.granted; _gpsMessage = 'Position hors zone, recentré sur Dakar.'; });
      }
    } catch (_) { setState(() { _gpsState = GpsState.error; _gpsMessage = 'Erreur GPS.'; }); }
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
    if (widget.userPosition != null &&
        widget.userPosition != oldWidget.userPosition &&
        DakarBounds.isValid(widget.userPosition!)) {
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
      final points = route.points.where((pt) => DakarBounds.isValid(pt)).toList();
      if (points.length >= 2) loaded.add(Polyline(points: points, color: route.color, strokeWidth: 5.5));
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
      if (fullRoutePoints.length >= 2) extra.add(Polyline(points: fullRoutePoints, color: route.color, strokeWidth: 4.5));
      // Petite pause pour ne pas saturer
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (mounted && extra.isNotEmpty) {
      setState(() => _dynamicPolylines = [..._dynamicPolylines, ...extra]);
    }
  }

  List<Stop> get _filteredStops {
    List<Stop> base;
    if (_selectedFilter == '⭐ Favoris') {
      base = allStops.where((s) => globalState.isFavorite(s.name)).toList();
    } else {
      switch (_selectedFilter) {
        case 'TER': base = allStops.where((s) => s.color == AppColors.ter).toList(); break;
        case 'BRT': base = allStops.where((s) => s.color == AppColors.brt).toList(); break;
        case 'DDD': base = allStops.where((s) => s.color == AppColors.ddd).toList(); break;
        case 'TATA': base = allStops.where((s) => s.color == AppColors.tata).toList(); break;
        case 'AFTU': base = allStops.where((s) => s.color == AppColors.aftu).toList(); break;
        default: base = List.from(allStops); break;
      }
    }
    if (widget.userPosition != null) {
      base.sort((a, b) => DistanceHelper.haversineMeters(widget.userPosition!, a.location).compareTo(DistanceHelper.haversineMeters(widget.userPosition!, b.location)));
    }
    // ✅ Fluidité : n'affiche que les arrêts proches (5km, 20 max) pour éviter la surcharge carte/liste
    if (widget.userPosition != null) {
      base.sort((a, b) => DistanceHelper.haversineMeters(widget.userPosition!, a.location).compareTo(DistanceHelper.haversineMeters(widget.userPosition!, b.location)));
      final nearby = base.where((s) => DistanceHelper.haversineMeters(widget.userPosition!, s.location) < 5000).take(20).toList();
      base = nearby.isNotEmpty ? nearby : base.take(20).toList();
    } else {
      const dakarCenter = LatLng(14.7167, -17.4677);
      base.sort((a, b) => DistanceHelper.haversineMeters(dakarCenter, a.location).compareTo(DistanceHelper.haversineMeters(dakarCenter, b.location)));
      base = base.take(20).toList();
    }
    return base.where((s) => DakarBounds.isValid(s.location)).toList();
  }

  double _distanceTo(Stop s) => widget.userPosition == null ? s.distanceMeters : DistanceHelper.haversineMeters(widget.userPosition!, s.location);

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
    final basePolylines = _dynamicPolylines.isNotEmpty ? _dynamicPolylines : demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 5.0)).toList();
    final activePolylines = filterColor == null
        ? basePolylines.where((p) => p.color == AppColors.ter || p.color == AppColors.brt).toList() // Tous : seulement TER/BRT (tracés dédiés, pas le spaghetti)
        : basePolylines.where((p) => p.color == filterColor).toList();
    final mapStops = _filteredStops; // ✅ Toujours filtré à proximité (20 max), pas allStops

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
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
                            initialCenter: (widget.userPosition != null && DakarBounds.isValid(widget.userPosition!))
                                ? widget.userPosition!
                                : _dakarCenter,
                            initialZoom: _zoomOverview,
                            minZoom: 9,
                            maxZoom: 17,
                            // ✅ PAS de cameraConstraint → carte fluide sur web
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus', maxZoom: 19),
                            PolylineLayer(polylines: activePolylines),
                            MarkerLayer(
                              markers: mapStops.where((s) => DakarBounds.isValid(s.location)).map((s) => Marker(
                                point: s.location, width: 24, height: 24,
                                child: GestureDetector(
                                  onTap: () { _centerOnStop(s); Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))); },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: s.color, shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3)],
                                    ),
                                    child: Icon(s.icon, color: Colors.white, size: 12),
                                  ),
                                ),
                              )).toList(),
                            ),
                            if (widget.userPosition != null && DakarBounds.isValid(widget.userPosition!))
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
        final remaining = stop.remainingMinutes();
        final crowd = TimeHelper.getCrowdLevel(stop);
        Widget timeWidget;

        final now = DateTime.now();
        final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);

        if (!isOpen) {
          timeWidget = Text('Fermé', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark)));
        } else if (remaining == null) {
          timeWidget = Text('Bientôt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark)));
        } else if (remaining <= 0) {
          timeWidget = Text('Imminent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stop.color));
        } else {
          timeWidget = Text(TimeHelper.formatRemaining(remaining), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success));
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
              trailing: timeWidget,
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
                Text('Itinéraires multimodaux officiels (TER, BRT, DDD, TATA, AFTU).', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
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
                  Text('Suggestions populaires (TER, BRT, DDD, TATA)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
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
                      _suggestionChip('Colobane - Yoff (DDD Ligne 1)', () {
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
                  Text('${r.totalMinutes} min', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
                  Text('Durée totale', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark)))
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
                          Row(children: [Icon(s.icon, size: 14, color: s.color), const SizedBox(width: 6), Text(s.modeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: s.color)), const Spacer(), Text(s.departureTime ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)))]),
                          const SizedBox(height: 4),
                          Text('${s.from} - ${s.to}', style: TextStyle(fontSize: 12, color: AppColors.textPrimary(dark))),
                          const SizedBox(height: 2),
                          Text('Durée: ${s.durationMinutes} min', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
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
        'type': 'TER',
        'title': 'Réseau CETUD & SETER (14 Gares)',
        'source': 'Source officielle : CETUD / SETER',
        'message': 'Le TER dessert officiellement 14 gares de Dakar à Diamniadio en passant par Colobane, Hann, Pikine, Keur Massar et Rufisque.',
        'severity': 'success',
        'badge': '14 Gares Officielles',
        'icon': Icons.train_rounded,
        'color': AppColors.ter,
      },
      {
        'type': 'BRT',
        'title': 'Corridor officiel SunuBRT',
        'source': 'Source officielle : Dakar Mobilité / CETUD',
        'message': 'Le corridor relie Guédiawaye à Petersen en passant par Dalal Jamm, Parcelles Assainies, Grand Yoff et la Place de l’Obélisque.',
        'severity': 'success',
        'badge': 'En direct',
        'icon': Icons.directions_bus_rounded,
        'color': AppColors.brt,
      },
      {
        'type': 'DDD',
        'title': 'Dakar Dem Dikk - Lignes Urbaines',
        'source': 'Source officielle : Direction DDD',
        'message': 'Les flottes DDD assurent les liaisons interurbaines et les lignes régulières 1, 3, 10, 14 et 20 aux horaires habituels.',
        'severity': 'success',
        'badge': 'Réseau actif',
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
                Text('Informations certifiées CETUD, SETER, SunuBRT & Dakar Dem Dikk.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
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
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(alertBadge, style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)))
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
  final List<Map<String, String>> _communityReports = [
    {'user': 'Mamadou S.', 'location': 'Parcelles Assainies (BRT)', 'type': 'Trafic fluide', 'time': 'Il y a 3 min', 'status': '🟢 Fluide'},
    {'user': 'Aïssatou N.', 'location': 'Gare de Dakar (TER)', 'type': 'Embarquement régulier', 'time': 'Il y a 6 min', 'status': '🟢 Fluide'},
  ];

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
                        'time': 'À l’instant',
                        'status': selectedType.substring(0, 2),
                      });
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement publié avec succès !')));
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
                      Text('Signalements en temps réel par les usagistes à Dakar.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
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
                        onTap: () => _showInfoModal(context, 'Comment utiliser l’application', '1. Utilisez l’onglet Explorer pour visualiser votre position GPS en temps réel et les arrêts à proximité.\n2. Maintenez un arrêt enfoncé pour l’ajouter à vos favoris ⭐.\n3. Utilisez l’onglet Trajets pour planifier vos déplacements multimodaux officiels (TER, BRT, DDD, TATA).\n4. Interrogez l’Assistant IA pour toute question sur les horaires et les lignes.'),
                      ),
                      Divider(height: 1, color: AppColors.divider(dark)),
                      ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                        title: Text('Conditions d’utilisation', style: TextStyle(color: AppColors.textPrimary(dark))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showInfoModal(context, 'Conditions d’utilisation', 'Dakar Bus fournit des informations de transport indicatives et officielles basées sur les données des opérateurs de la région de Dakar (CETUD, SETER, SunuBRT, DDD, AFTU). L’application s’engage à assurer un affichage fidèle et mis à jour en continu.'),
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
    final buf = StringBuffer();
    buf.writeln('🧭 Itinéraire trouvé : $from → $to');
    buf.writeln('⏱️ Durée totale : ${r.totalMinutes} min • ${r.transferCount} correspondance(s)');
    buf.writeln('');
    for (int i = 0; i < r.segments.length; i++) {
      final s = r.segments[i];
      buf.writeln('${i+1}. ${s.modeLabel} : ${s.from} → ${s.to}');
      buf.writeln('   🕒 ${s.departureTime} → ${s.arrivalTime} • ${s.durationMinutes} min • ${s.modeLabel == 'TER' || s.modeLabel == 'BRT' ? 'Direct' : 'Rotation ~5 min'}');
    }
    buf.writeln('');
    buf.writeln('💡 Astuce : ouvre l\'onglet "Trajets" pour voir le détail sur la carte.');
    if (widget.userPosition != null) {
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
      // Si from manquant mais GPS dispo, utilise l'arrêt le plus proche
      if ((from == null || from.isEmpty) && widget.userPosition != null) {
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
      aiReply = '🚆 [Mémorisé : TER] Le Train Express Régional relie Dakar à Diamniadio en traversant 14 gares officielles (Colobane, Pikine, Rufisque...) avec un départ toutes les 10 à 20 min. Dis-moi ton départ et arrivée pour un itinéraire TER.';
    } else if (lower.contains('brt') || lower.contains('guédiawaye') || lower.contains('petersen') || lower.contains('sunu')) {
      _dernierModeInterroge = 'BRT';
      aiReply = '🚌 [Mémorisé : SunuBRT] Le couloir BRT relie le PEM Guédiawaye au PEM Petersen en passant par Dalal Jamm, Parcelles Assainies et l’Obélisque. Donne-moi un trajet pour te guider.';
    } else if (lower.contains('ddd') || lower.contains('dakar dem dikk') || lower.contains('ligne 1') || lower.contains('ligne 3')) {
      _dernierModeInterroge = 'DDD';
      aiReply = '🚍 [Mémorisé : Dakar Dem Dikk] Les bus DDD couvrent les lignes urbaines et interurbaines (L1 Colobane-Yoff, L3 Sandaga-Ouakam, etc.). Précise ton trajet DDD et je te le planifie.';
    } else if (lower.contains('tata') || lower.contains('minibus') || lower.contains('ligne 50')) {
      _dernierModeInterroge = 'TATA';
      aiReply = '🚐 [Mémorisé : Bus TATA] Les bus TATA desservent Guédiawaye, Pikine, Yoff, Mermoz, Keur Massar... Dis-moi où tu veux aller.';
    } else if (lower.contains('aftu') || lower.contains('parcelles') || lower.contains('grand yoff')) {
      _dernierModeInterroge = 'AFTU';
      aiReply = '🚐 [Mémorisé : AFTU] 72 lignes AFTU couvrent tout Dakar (Parcelles, Grand Yoff, Petersen...). Donne-moi départ/arrivée pour un itinéraire AFTU.';
    } else if (lower.contains('où suis-je') || lower.contains('ou suis je') || lower.contains('autour de moi') || lower.contains('proche')) {
      if (widget.userPosition != null) {
        final nearby = allStops.map((s) => MapEntry(s, DistanceHelper.haversineMeters(widget.userPosition!, s.location))).toList()..sort((a,b)=>a.value.compareTo(b.value));
        final top = nearby.take(3).map((e)=> '- ${e.key.name} (${DistanceHelper.format(e.value)} • ${e.key.modeLabel})').join('\n');
        aiReply = '📍 Tu es près de :\n$top\n\nJe peux te guider vers une destination. Où veux-tu aller ?';
      } else {
        aiReply = '📍 Active ton GPS via "Activer GPS" sur la carte, puis je pourrai te montrer les arrêts autour de toi et planifier un trajet.';
      }
    } else if (lower.contains('alerte') || lower.contains('bouchon') || lower.contains('trafic') || lower.contains('direct rue')) {
      aiReply = '🚨 Alertes en temps réel : consulte l\'onglet "Alertes" (CETUD/SETER) et "Direct rue" (signalements usagers). Tu peux aussi publier un signalement. Veux-tu que je vérifie le trafic autour de toi ? Active ton GPS et dis-moi ta position.';
    } else {
      aiReply = '🚍 Les réseaux TER, BRT, DDD, TATA, AFTU fonctionnent normalement. Pour un itinéraire précis, dis-moi : "Je suis à X, je veux aller à Y" ou "De X à Y". Exemple testé : "Je suis à Dakar, je veux aller à Keur Mbaye Fall" → je te donne le trajet TER direct.';
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
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text('[OFFICIEL]', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.success))),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.access_time, size: 12, color: route.color),
                                  const SizedBox(width: 4),
                                  Text('Heure : ${stop.estimatedTime}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary(dark))),
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

    final retourStop = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops) ?? stop.copyWith(
      direction: 'Dir. Dakar / Centre',
      stopType: StopType.departure,
    );

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
            SingleStopView(stop: retourStop),
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
    final crowd = TimeHelper.getCrowdLevel(stop);
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prochain départ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                          const SizedBox(height: 2),
                          Text(stop.nextDepartureLabel() ?? 'Fermé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stop.color)),
                        ],
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