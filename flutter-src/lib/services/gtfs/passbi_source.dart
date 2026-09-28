/// Lot 4.18 — Source opérationnelle PassBi (quatre feeds, un seul lecteur).
///
/// Charge `assets/data/passbi/{ter,brt,ddd,aftu}.json` + `crosswalk.json`.
/// Statut : ACTIVE — source = PassBi, source_type = PUBLIC_GTFS.
/// Le remplacement futur par les données étude/CETUD consiste à régénérer ces
/// assets (scripts/build-passbi-processed.mjs) : aucun changement de moteur.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/departure_info.dart';
import 'gtfs_source.dart';

/// Lot 4.21 §1 — Fiche d'audit d'une route PassBi, calculée à partir du feed
/// réellement intégré (aucune donnée téléchargée, aucune valeur recopiée).
///
/// Elle distingue explicitement ce que le lot impose de séparer :
///  * [scheduleAvailable] — la donnée permet-elle de calculer un prochain
///    départ (trips + stop_times + service actif + arrêt embarquable) ;
///  * [identityStatus] — l'identité publique de la ligne est-elle confirmée
///    (crosswalk) ; `unconfirmed` n'empêche PAS [scheduleAvailable].
class PassBiRouteSummary {
  final String network; // TER | BRT | DDD | AFTU
  final String routeId; // route_id PassBi exact
  final String shortName; // short_name PassBi exact
  final String longName; // long_name PassBi exact
  final int routeType; // route_type GTFS exact
  final int trips;
  final int servedStops;
  final int stopTimes;

  /// `stop_times` dont le trip continue après l'arrêt → montée possible.
  final int boardableStopTimes;
  final List<String> serviceIds;
  final List<String> directions; // direction_id réels du feed ('' = absent)
  final int? firstDepartureSec;
  final int? lastDepartureSec;

  /// Disponibilité horaire : un prochain départ est calculable.
  final bool scheduleAvailable;

  /// Identité publique (§3) — champ DISTINCT de [scheduleAvailable].
  final IdentityStatus identityStatus;

  /// Identités du référentiel dakar rattachées par le crosswalk (vides si
  /// identité non confirmée : aucun rattachement n'est alors deviné).
  final List<String> dakarRouteIds;

  /// Raison documentaire ([UnresolvedReason] ou `HORAIRES_CALCULABLES`).
  final String reason;

  const PassBiRouteSummary({
    required this.network,
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.routeType,
    required this.trips,
    required this.servedStops,
    required this.stopTimes,
    required this.boardableStopTimes,
    required this.serviceIds,
    required this.directions,
    required this.firstDepartureSec,
    required this.lastDepartureSec,
    required this.scheduleAvailable,
    required this.identityStatus,
    required this.dakarRouteIds,
    required this.reason,
  });

  /// Ligne du tableau d'audit (§1) :
  /// `network | route_id | short | long | trips | stop_times |
  ///  schedule_available | UI_mapping | reason`.
  String get auditRow => <String>[
        network,
        routeId,
        shortName,
        longName,
        '$trips',
        '$stopTimes',
        scheduleAvailable ? 'YES' : 'NO',
        identityStatus.code,
        reason,
      ].join(' | ');
}

/// Lot 4.21 §2 — Arrêt PassBi natif : identifiant, nom et coordonnées EXACTS
/// du feed, plus le nombre de lignes qui l'appellent réellement.
class PassBiStopRef {
  final String network;
  final String stopId;
  final String name;
  final double lat;
  final double lon;
  final int routeCount;

  const PassBiStopRef({
    required this.network,
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.routeCount,
  });

  /// Clé composite du moteur (`NET:id`), identique au crosswalk.
  String get compositeKey => '$network:$stopId';
}

/// Lot 4.21 §6 — Disponibilité d'un réseau comme feed GTFS PassBi autonome.
enum PassBiNetworkAvailability {
  /// Feed présent et exploitable (TER, BRT, DDD, AFTU).
  available,

  /// Feed présent mais sans aucun horaire calculable.
  presentWithoutSchedules,

  /// Aucun feed PassBi : le réseau n'existe pas comme donnée GTFS PassBi
  /// autonome. Aucune route n'est alors fabriquée (TATA — §6).
  absentFromFeed;

  String get code => switch (this) {
        PassBiNetworkAvailability.available => 'AVAILABLE',
        PassBiNetworkAvailability.presentWithoutSchedules =>
          'PRESENT_WITHOUT_SCHEDULES',
        PassBiNetworkAvailability.absentFromFeed => 'ABSENT_FROM_FEED',
      };
}

class RouteMapping {
  /// Lot 4.21 (verrouillage) — Méthodes de PREUVE DOCUMENTAIRE seules
  /// susceptibles de confirmer une identité publique. Une identité n'est
  /// JAMAIS confirmée par un numéro, un route_id, un nom similaire, OSM,
  /// une proximité ou des terminus proches (`TERMINI_MATCH` reste une
  /// hypothèse non confirmée).
  static const Set<String> documentedIdentityMethods = <String>{
    'IDENTITY_OFFICIELLE',
  };

  final String dakarRouteId;
  final String? network; // TER | BRT | DDD | AFTU | null
  final List<String> pbRouteIds;
  final String status; // MAPPED | UNMAPPED
  final String method;
  final String note;

  /// Observation d'appariement NON confirmée (ex. `TERMINI_MATCH`) : gardée
  /// pour l'audit, elle ne produit AUCUN rattachement et ne confirme rien.
  final Map<String, dynamic>? hypothesis;

  const RouteMapping({
    required this.dakarRouteId,
    required this.network,
    required this.pbRouteIds,
    required this.status,
    required this.method,
    required this.note,
    this.hypothesis,
  });

  /// `true` uniquement si le crosswalk rattache la route avec une PREUVE
  /// DOCUMENTAIRE. Un `MAPPED` obtenu par termini/numéro/nom/proximité n'est
  /// pas une identité confirmée : [isMapped] reste `false`.
  bool get isMapped =>
      status == 'MAPPED' &&
      network != null &&
      pbRouteIds.isNotEmpty &&
      documentedIdentityMethods.contains(method);

  factory RouteMapping.fromJson(String dakarRouteId, Map<String, dynamic> json) =>
      RouteMapping(
        dakarRouteId: dakarRouteId,
        network: json['network'] as String?,
        pbRouteIds: ((json['pbRouteIds'] as List<dynamic>? ?? const [])).cast<String>(),
        status: (json['status'] ?? 'UNMAPPED') as String,
        method: (json['method'] ?? '') as String,
        note: (json['note'] ?? '') as String,
        hypothesis: (json['hypothesis'] as Map<String, dynamic>?),
      );
}

class StopMapping {
  final String dakarStopId;
  final String compositeStopId; // « TER:<stop_id> »
  final String method;
  final String confidence;
  final double? score;
  final int? meters;

  const StopMapping({
    required this.dakarStopId,
    required this.compositeStopId,
    required this.method,
    required this.confidence,
    this.score,
    this.meters,
  });

  factory StopMapping.fromJson(String dakarStopId, Map<String, dynamic> json) =>
      StopMapping(
        dakarStopId: dakarStopId,
        compositeStopId: json['pb'] as String,
        method: (json['method'] ?? '') as String,
        confidence: (json['confidence'] ?? '') as String,
        score: (json['score'] as num?)?.toDouble(),
        meters: (json['meters'] as num?)?.toInt(),
      );
}

class TransferLink {
  /// Lot 4.21 (verrouillage) — Méthodes de correspondance DOCUMENTÉES : le
  /// NOM est vérifié (égalité normalisée ou inclusion) et la distance reste
  /// bornée. AUCUNE correspondance par proximité seule : un lien sans méthode
  /// de nom vérifié, sans nom, ou impliquant un réseau hors feeds (TATA) est
  /// rejeté au chargement et n'entre jamais dans `source.transfers`.
  static const Set<String> documentedMethods = <String>{
    'NOM_IDENTIQUE_PROXIMITE', // même nom normalisé, ≤ 500 m
    'INCLUSION_NOM_PROXIMITE', // inclusion de nom inter-réseaux, ≤ 250 m
  };

  final String from; // composite « NET:id »
  final String to;
  final int meters;
  final String name;
  final String method;
  final String confidence;

  const TransferLink({
    required this.from,
    required this.to,
    required this.meters,
    required this.name,
    required this.method,
    required this.confidence,
  });

  /// Lien de correspondance réellement documenté (voir [documentedMethods]).
  /// Une identité publique — confirmée ou non — n'intervient JAMAIS ici : la
  /// preuve d'un transfert est un arrêt physique réellement desservi avec nom
  /// vérifié, jamais une identité de ligne ni la seule géographie.
  bool get isDocumented {
    if (!documentedMethods.contains(method)) return false;
    if (name.trim().isEmpty) return false;
    if (meters < 0 || meters > 500) return false;
    if (from == to) return false;
    final String? netFrom = PassBiSource.splitComposite(from)?[0];
    final String? netTo = PassBiSource.splitComposite(to)?[0];
    if (netFrom == null || netTo == null) return false;
    // Réseaux couverts par les feeds PassBi uniquement (TATA : absent → zéro
    // correspondance possible, toute clé « TATA:… » est rejetée).
    return PassBiSource.assetFiles.containsKey(netFrom) &&
        PassBiSource.assetFiles.containsKey(netTo);
  }

  factory TransferLink.fromJson(Map<String, dynamic> json) => TransferLink(
        from: json['from'] as String,
        to: json['to'] as String,
        meters: (json['meters'] as num).toInt(),
        name: (json['name'] ?? '') as String,
        method: (json['method'] ?? '') as String,
        confidence: (json['confidence'] ?? '') as String,
      );
}

class PassBiSource {
  /// Les quatre feeds : un lecteur générique, zéro duplication.
  static const Map<String, String> assetFiles = <String, String>{
    'TER': 'assets/data/passbi/ter.json',
    'BRT': 'assets/data/passbi/brt.json',
    'DDD': 'assets/data/passbi/ddd.json',
    'AFTU': 'assets/data/passbi/aftu.json',
  };
  static const String crosswalkAsset = 'assets/data/passbi/crosswalk.json';

  /// Métadonnées de provenance communes (source_type PUBLIC_GTFS).
  static const String sourceName = 'PassBi (impactsolutionsas/passbi_core)';
  static const String sourceTypeLabel = 'PUBLIC_GTFS';
  static const String sourceUrl =
      'https://github.com/impactsolutionsas/passbi_core';
  static const String dateVerified = '2026-09-27';

  final Map<String, GtfsNetwork> networks = <String, GtfsNetwork>{};
  Map<String, RouteMapping>? _routeMappings;
  Map<String, Map<String, StopMapping>>? _stopMappings;
  List<TransferLink> _transfers = const <TransferLink>[];
  Map<String, dynamic>? _crosswalkMeta;

  bool get isActive => networks.length == assetFiles.length && _routeMappings != null;

  Map<String, dynamic>? get crosswalkMeta => _crosswalkMeta;
  List<TransferLink> get transfers => _transfers;

  GtfsNetwork? network(String key) => networks[key];

  /// Chargement complet des quatre feeds + crosswalk.
  /// Une seule entrée de lecture : le remplacement de source passe par là.
  Future<void> loadAll() async {
    for (final entry in assetFiles.entries) {
      final jsonString = await rootBundle.loadString(entry.value);
      networks[entry.key] = GtfsNetwork.fromJson(entry.key, jsonString);
    }
    final cw = jsonDecodeCrosswalk(
        await rootBundle.loadString(crosswalkAsset));
    _routeMappings = cw.routes;
    _stopMappings = cw.stops;
    _transfers = cw.transfers;
    _crosswalkMeta = cw.meta;
  }

  // Helper JSON isolé (testable) : décodage du crosswalk.
  static PassBiCrosswalk jsonDecodeCrosswalk(String jsonString) =>
      CrosswalkParser.decode(jsonString);

  RouteMapping? routeMapping(String dakarRouteId) =>
      _routeMappings?[dakarRouteId];

  StopMapping? stopMappingFor(String dakarRouteId, String dakarStopId) =>
      _stopMappings?[dakarRouteId]?[dakarStopId];

  /// Toutes les clés PassBi (composite) correspondant à un arrêt dakar,
  /// tous réseaux confondus — utilisées par le moteur de routage.
  Set<String> compositeStopsForDakarStop(String dakarStopId) {
    final result = <String>{};
    final mappings = _stopMappings;
    if (mappings == null) return result;
    for (final entry in mappings.values) {
      final m = entry[dakarStopId];
      if (m != null) result.add(m.compositeStopId);
    }
    return result;
  }

  /// Lot 4.19 A — Plateformes « sœurs » d'un arrêt PassBi : même station,
  /// liaison documentée du crosswalk ≤ 30 m (liens construits avec vérification
  /// d'égalité de nom, jamais par proximité seule), strictement sur le même
  /// réseau. Un quai d'arrivée ne produit aucun départ embarquable : le
  /// prochain départ se lit sur la plateforme de départ sœur.
  Set<String> siblingStops(String networkKey, String pbStopId) {
    final out = <String>{};
    final composite = '$networkKey:$pbStopId';
    for (final t in _transfers) {
      if (t.meters > 30) continue;
      String? other;
      if (t.from == composite) {
        other = t.to;
      } else if (t.to == composite) {
        other = t.from;
      }
      if (other == null) continue;
      final op = splitComposite(other);
      if (op == null || op[0] != networkKey) continue; // même réseau uniquement
      out.add(op[1]);
    }
    return out;
  }

  /// Découpe « NET:id » → (réseau, stop_id brut).
  static List<String>? splitComposite(String composite) {
    final idx = composite.indexOf(':');
    if (idx <= 0 || idx >= composite.length - 1) return null;
    return <String>[composite.substring(0, idx), composite.substring(idx + 1)];
  }

  /// Prochain départ par identifiants PassBi (API moteur — indépendante du
  /// crosswalk dakar_network). Retourne null si non calculable.
  int? nextDepartureSec({
    required String networkKey,
    required String pbRouteId,
    required String pbStopId,
    required DateTime at,
  }) {
    final net = networks[networkKey];
    if (net == null) return null;
    final routeIndex = net.routeIndexById[pbRouteId];
    final stopIndex = net.stopIndexById[pbStopId];
    if (routeIndex == null || stopIndex == null) return null;
    return net.nextDepartureSec(routeIndex: routeIndex, stopIndex: stopIndex, at: at);
  }

  /// Transfert documenté entre deux arrêts composites (≤ 500 m, nom vérifié).
  TransferLink? transferBetween(String compositeA, String compositeB) {
    for (final t in _transfers) {
      if ((t.from == compositeA && t.to == compositeB) ||
          (t.from == compositeB && t.to == compositeA)) {
        return t;
      }
    }
    return null;
  }

  // ======================================================================
  // LOT 4.21 — CHEMIN NATIF PASSBI (identité publique ≠ exploitation horaire)
  // ======================================================================
  //
  // CONSTAT (audit §1) : les feeds DDD et AFTU contiennent des routes, trips,
  // stops, stop_times et services actifs — 52 routes DDD et 71 routes AFTU
  // permettent de calculer un prochain départ. Or le crosswalk n'a confirmé
  // l'identité publique d'AUCUNE route DDD et de 2 routes AFTU seulement
  // (`IDENTITE_NON_CONFIRMEE` partout ailleurs). Le chemin unique existant
  // (`ScheduleProvider.departureAt`) exigeait un mapping de route MAPPED :
  // l'identité non résolue bloquait donc l'exploitation d'horaires
  // techniquement valides — exactement la confusion que le §2 interdit.
  //
  // Le chemin natif ci-dessous lit les métadonnées PassBi RÉELLES (route_id,
  // short_name, long_name, direction_id, noms d'arrêts) sans rien inventer :
  // aucun nom commercial, aucune origine/destination, aucune identité déduite
  // d'un numéro.

  final Map<String, List<PassBiRouteSummary>> _summaryCache =
      <String, List<PassBiRouteSummary>>{};
  final Map<String, List<PassBiStopRef>> _nativeStopCache =
      <String, List<PassBiStopRef>>{};

  /// Identités du référentiel dakar dont le crosswalk rattache cette route
  /// PassBi avec une PREUVE DOCUMENTAIRE ([RouteMapping.isMapped] : méthode
  /// [RouteMapping.documentedIdentityMethods] uniquement). Vide = identité
  /// publique non confirmée (et NON « absence d'horaire »).
  List<String> dakarRouteIdsFor(String networkKey, String pbRouteId) {
    final mappings = _routeMappings;
    if (mappings == null) return const <String>[];
    final out = <String>[];
    mappings.forEach((dakarRouteId, m) {
      if (m.isMapped &&
          m.network == networkKey &&
          m.pbRouteIds.contains(pbRouteId)) {
        out.add(dakarRouteId);
      }
    });
    return out;
  }

  /// §3 — Identité publique d'une route PassBi : CONFIRMED seulement si le
  /// crosswalk la rattache à une identité du référentiel dakar par PREUVE
  /// DOCUMENTAIRE ([RouteMapping.isMapped]). Un numéro similaire, des terminus
  /// proches ou un nom ressemblant ne confirment jamais : sinon UNCONFIRMED
  /// — sans jamais empêcher un horaire calculable.
  IdentityStatus identityStatusOf(String networkKey, String pbRouteId) =>
      dakarRouteIdsFor(networkKey, pbRouteId).isNotEmpty
          ? IdentityStatus.confirmed
          : IdentityStatus.unconfirmed;

  /// §1 — Audit complet d'un feed : une fiche par route, calculée depuis les
  /// données réellement intégrées.
  List<PassBiRouteSummary> routeSummaries(String networkKey) {
    final cached = _summaryCache[networkKey];
    if (cached != null) return cached;
    final net = networks[networkKey];
    if (net == null) return const <PassBiRouteSummary>[];

    // Accumulateurs indexés par route (aucune fermeture à zéro argument :
    // la liste est construite typée, sans cast inutile).
    final int routeCount = net.routes.length;
    final List<int> trips = List<int>.filled(routeCount, 0);
    final List<int> stopTimes = List<int>.filled(routeCount, 0);
    final List<int> boardable = List<int>.filled(routeCount, 0);
    final List<Set<int>> served =
        List<Set<int>>.generate(routeCount, (_) => <int>{});
    final List<Set<String>> services =
        List<Set<String>>.generate(routeCount, (_) => <String>{});
    final List<Set<String>> directions =
        List<Set<String>>.generate(routeCount, (_) => <String>{});
    final List<int?> first = List<int?>.filled(routeCount, null);
    final List<int?> last = List<int?>.filled(routeCount, null);

    for (int ti = 0; ti < net.trips.length; ti++) {
      final trip = net.trips[ti];
      if (trip.routeIndex < 0 || trip.routeIndex >= trips.length) continue;
      trips[trip.routeIndex]++;
      if (trip.serviceIndex >= 0 && trip.serviceIndex < net.services.length) {
        services[trip.routeIndex].add(net.services[trip.serviceIndex].id);
      }
      if (trip.direction.isNotEmpty) {
        directions[trip.routeIndex].add(trip.direction);
      }
      for (final st in (net.stopTimesByTrip[ti] ?? const <GtfsStopTime>[])) {
        stopTimes[trip.routeIndex]++;
        served[trip.routeIndex].add(st.stopIndex);
        final dep = st.departureSec;
        if (first[trip.routeIndex] == null || dep < first[trip.routeIndex]!) {
          first[trip.routeIndex] = dep;
        }
        if (last[trip.routeIndex] == null || dep > last[trip.routeIndex]!) {
          last[trip.routeIndex] = dep;
        }
        // Embarquable : le trip continue après cet arrêt (Lot 4.19 A).
        final rows = net.stopTimesByTrip[ti];
        if (rows != null && rows.isNotEmpty && st.sequence < rows.last.sequence) {
          boardable[trip.routeIndex]++;
        }
      }
    }

    final out = <PassBiRouteSummary>[];
    for (int ri = 0; ri < net.routes.length; ri++) {
      final r = net.routes[ri];
      final bool available = boardable[ri] > 0;
      final String reason;
      if (available) {
        reason = 'HORAIRES_CALCULABLES';
      } else if (trips[ri] == 0) {
        reason = UnresolvedReason.noComputableDeparture; // aucun trip
      } else if (stopTimes[ri] == 0) {
        reason = UnresolvedReason.noStopTimesInFeed;
      } else {
        reason = UnresolvedReason.noComputableDeparture;
      }
      out.add(PassBiRouteSummary(
        network: networkKey,
        routeId: r.id,
        shortName: r.short,
        longName: r.long,
        routeType: r.type,
        trips: trips[ri],
        servedStops: served[ri].length,
        stopTimes: stopTimes[ri],
        boardableStopTimes: boardable[ri],
        serviceIds: services[ri].toList()..sort(),
        directions: directions[ri].toList()..sort(),
        firstDepartureSec: first[ri],
        lastDepartureSec: last[ri],
        scheduleAvailable: available,
        identityStatus: identityStatusOf(networkKey, r.id),
        dakarRouteIds: dakarRouteIdsFor(networkKey, r.id),
        reason: reason,
      ));
    }
    _summaryCache[networkKey] = List<PassBiRouteSummary>.unmodifiable(out);
    return _summaryCache[networkKey]!;
  }

  PassBiRouteSummary? routeSummary(String networkKey, String pbRouteId) {
    for (final s in routeSummaries(networkKey)) {
      if (s.routeId == pbRouteId) return s;
    }
    return null;
  }

  /// Nombre de routes du feed dont un prochain départ est calculable.
  int schedulableRouteCount(String networkKey) =>
      routeSummaries(networkKey).where((s) => s.scheduleAvailable).length;

  /// §6 — Disponibilité d'un réseau comme feed GTFS PassBi autonome.
  ///
  /// TATA : `assetFiles` ne contient AUCUN feed TATA et aucune donnée PassBi
  /// (route, mode, vehicle_type, network, agency) ne permet d'établir une
  /// mobilité TATA indépendante → [PassBiNetworkAvailability.absentFromFeed].
  /// Aucune route TATA n'est fabriquée.
  PassBiNetworkAvailability networkAvailability(String networkKey) {
    final net = networks[networkKey];
    if (net == null) return PassBiNetworkAvailability.absentFromFeed;
    final summaries = routeSummaries(networkKey);
    if (summaries.isEmpty) {
      return PassBiNetworkAvailability.presentWithoutSchedules;
    }
    return summaries.any((s) => s.scheduleAvailable)
        ? PassBiNetworkAvailability.available
        : PassBiNetworkAvailability.presentWithoutSchedules;
  }

  /// §6 — Preuve vérifiable : occurrence du mot « tata » (insensible à la
  /// casse) dans les métadonnées PassBi réellement chargées — agency, meta,
  /// route_id/short_name/long_name, noms d'arrêts, trip_id, direction_id,
  /// headsign. Aucun autre champ n'existe dans le format compact.
  List<String> tataMentions() {
    final out = <String>[];
    networks.forEach((key, net) {
      bool hit(String? value) =>
          value != null && value.toLowerCase().contains('tata');
      if (hit(net.agency)) out.add('$key:agency=${net.agency}');
      net.meta.forEach((k, v) {
        if (hit(v)) out.add('$key:meta.$k=$v');
      });
      for (final r in net.routes) {
        if (hit(r.id) || hit(r.short) || hit(r.long)) {
          out.add('$key:route=${r.id}');
        }
      }
      for (final s in net.stops) {
        if (hit(s.name)) out.add('$key:stop=${s.id}');
      }
      for (final t in net.trips) {
        if (hit(t.id) || hit(t.direction) || hit(t.headsign)) {
          out.add('$key:trip=${t.id}');
        }
      }
    });
    return out;
  }

  /// §2/§7 — Arrêts PassBi natifs d'un réseau : réellement appelés par au
  /// moins une ligne (dérivé des `stop_times`), nom et coordonnées du feed.
  List<PassBiStopRef> nativeStops(String networkKey) {
    final cached = _nativeStopCache[networkKey];
    if (cached != null) return cached;
    final net = networks[networkKey];
    if (net == null) return const <PassBiStopRef>[];
    final out = <PassBiStopRef>[];
    for (int si = 0; si < net.stops.length; si++) {
      final routes = net.routeIndexesCalling(si);
      if (routes.isEmpty) continue; // arrêt jamais appelé : non exposé
      final s = net.stops[si];
      out.add(PassBiStopRef(
        network: networkKey,
        stopId: s.id,
        name: s.name,
        lat: s.lat,
        lon: s.lon,
        routeCount: routes.length,
      ));
    }
    final result = List<PassBiStopRef>.unmodifiable(out);
    _nativeStopCache[networkKey] = result;
    return result;
  }

  /// Repliement d'accents (le SDK Dart n'expose pas de normalisation Unicode) :
  /// couvre les caractères réellement présents dans les noms d'arrêts PassBi
  /// et du référentiel dakar. Aucun autre caractère n'est transformé.
  static const Map<String, String> _accentFolds = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ÿ': 'y', 'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
    'À': 'a', 'Á': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a', 'Å': 'a',
    'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e',
    'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i',
    'Ò': 'o', 'Ó': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
    'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u',
    'Ç': 'c', 'Ñ': 'n',
  };

  /// Normalisation de nom (accentuation, casse, ponctuation) — même intention
  /// que celle du générateur de crosswalk, pour une recherche reproductible.
  static String normalizeName(String value) {
    final buf = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      final String raw = value[i];
      final String c = _accentFolds[raw] ?? raw;
      final int code = c.codeUnitAt(0);
      final bool alnum = (code >= 0x30 && code <= 0x39) ||
          (code >= 0x61 && code <= 0x7a) ||
          (code >= 0x41 && code <= 0x5a);
      buf.write(alnum ? c.toLowerCase() : ' ');
    }
    return buf.toString().replaceAll(RegExp(r' +'), ' ').trim();
  }

  /// §8 — Recherche d'arrêts PassBi natifs par nom réel (saisie utilisateur).
  ///
  /// Règle STRICTE (aucune correspondance devinée) : le nom PassBi normalisé
  /// doit CONTENIR la requête normalisée entière. L'inverse (la requête
  /// contient un fragment de nom) n'est pas accepté : « Rufisque - Gare TER »
  /// ne doit pas résoudre vers un arrêt PassBi nommé « Rufisque ».
  List<PassBiStopRef> searchNativeStops(String query,
      {Set<String>? networksFilter, int limit = 8}) {
    final q = normalizeName(query);
    if (q.length < 3) return const <PassBiStopRef>[];
    final out = <PassBiStopRef>[];
    for (final key in (networksFilter ?? assetFiles.keys)) {
      if (!assetFiles.containsKey(key)) continue; // TATA : aucun feed
      for (final s in nativeStops(key)) {
        if (normalizeName(s.name).contains(q)) {
          out.add(s);
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  /// §4/§5 — Prochain départ natif : le plus tôt parmi les lignes PassBi qui
  /// appellent RÉELLEMENT l'arrêt (plateformes sœurs du crosswalk incluses,
  /// même réseau, Lot 4.19 A). Retourne la route gagnante afin que l'affichage
  /// utilise ses métadonnées PassBi réelles.
  ({int sec, String routeId, String tripId, int dayOffset})? nextNativeDeparture({
    required String networkKey,
    required String pbStopId,
    required DateTime at,
    String? onlyRouteId,
  }) {
    final net = networks[networkKey];
    if (net == null) return null;
    final stopIndex = net.stopIndexById[pbStopId];
    if (stopIndex == null) return null;

    final routeIndexes = <int>{};
    final candidates = <String>[pbStopId, ...siblingStops(networkKey, pbStopId)];
    for (final candidate in candidates) {
      final ci = net.stopIndexById[candidate];
      if (ci == null) continue;
      routeIndexes.addAll(net.routeIndexesCalling(ci));
    }
    if (onlyRouteId != null) {
      final wanted = net.routeIndexById[onlyRouteId];
      if (wanted == null) return null;
      routeIndexes.retainAll(<int>{wanted});
    }
    if (routeIndexes.isEmpty) return null;

    ({int sec, int routeIndex, int tripIndex, int dayOffset})? best;
    for (final candidate in candidates) {
      final ci = net.stopIndexById[candidate];
      if (ci == null) continue;
      final found = net.nextDepartureAmong(
        routeIndexes: routeIndexes,
        stopIndex: ci,
        at: at,
      );
      if (found == null) continue;
      if (best == null || found.sec < best.sec) best = found;
    }
    if (best == null) return null;
    return (
      sec: best.sec,
      routeId: net.routes[best.routeIndex].id,
      tripId: net.trips[best.tripIndex].id,
      dayOffset: best.dayOffset,
    );
  }
}

class PassBiCrosswalk {
  final Map<String, RouteMapping> routes;
  final Map<String, Map<String, StopMapping>> stops;
  final List<TransferLink> transfers;
  final Map<String, dynamic> meta;
  const PassBiCrosswalk({
    required this.routes,
    required this.stops,
    required this.transfers,
    required this.meta,
  });
}

class CrosswalkParser {
  static PassBiCrosswalk decode(String jsonString) {
    final root = json.decode(jsonString) as Map<String, dynamic>;
    final routes = <String, RouteMapping>{};
    final routesRaw = root['routes'] as Map<String, dynamic>? ?? const {};
    routesRaw.forEach((k, v) {
      routes[k] = RouteMapping.fromJson(k, v as Map<String, dynamic>);
    });
    final stops = <String, Map<String, StopMapping>>{};
    final stopsRaw = root['stops'] as Map<String, dynamic>? ?? const {};
    stopsRaw.forEach((routeId, perRoute) {
      final inner = <String, StopMapping>{};
      (perRoute as Map<String, dynamic>).forEach((stopId, value) {
        if (value != null) {
          inner[stopId] =
              StopMapping.fromJson(stopId, value as Map<String, dynamic>);
        }
      });
      stops[routeId] = inner;
    });
    final transfers = <TransferLink>[];
    for (final t in (root['transfers'] as List<dynamic>? ?? const [])) {
      final link = TransferLink.fromJson(t as Map<String, dynamic>);
      // Verrouillage (Lot 4.21) : seuls les liens DOCUMENTÉS (nom vérifié +
      // distance bornée, réseaux des feeds) entrent dans `source.transfers`.
      // Un lien de pure proximité — ou impliquant un réseau hors feeds comme
      // TATA — est rejeté ici : le moteur de routage ne pourra jamais
      // l'utiliser comme correspondance.
      if (link.isDocumented) transfers.add(link);
    }
    return PassBiCrosswalk(
      routes: routes,
      stops: stops,
      transfers: transfers,
      meta: root['meta'] as Map<String, dynamic>? ?? const {},
    );
  }
}
