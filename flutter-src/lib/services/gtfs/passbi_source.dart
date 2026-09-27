/// Lot 4.18 — Source opérationnelle PassBi (quatre feeds, un seul lecteur).
///
/// Charge `assets/data/passbi/{ter,brt,ddd,aftu}.json` + `crosswalk.json`.
/// Statut : ACTIVE — source = PassBi, source_type = PUBLIC_GTFS.
/// Le remplacement futur par les données étude/CETUD consiste à régénérer ces
/// assets (scripts/build-passbi-processed.mjs) : aucun changement de moteur.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'gtfs_source.dart';

class RouteMapping {
  final String dakarRouteId;
  final String? network; // TER | BRT | DDD | AFTU | null
  final List<String> pbRouteIds;
  final String status; // MAPPED | UNMAPPED
  final String method;
  final String note;

  const RouteMapping({
    required this.dakarRouteId,
    required this.network,
    required this.pbRouteIds,
    required this.status,
    required this.method,
    required this.note,
  });

  bool get isMapped => status == 'MAPPED' && network != null && pbRouteIds.isNotEmpty;

  factory RouteMapping.fromJson(String dakarRouteId, Map<String, dynamic> json) =>
      RouteMapping(
        dakarRouteId: dakarRouteId,
        network: json['network'] as String?,
        pbRouteIds: ((json['pbRouteIds'] as List<dynamic>? ?? const [])).cast<String>(),
        status: (json['status'] ?? 'UNMAPPED') as String,
        method: (json['method'] ?? '') as String,
        note: (json['note'] ?? '') as String,
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
      transfers.add(TransferLink.fromJson(t as Map<String, dynamic>));
    }
    return PassBiCrosswalk(
      routes: routes,
      stops: stops,
      transfers: transfers,
      meta: root['meta'] as Map<String, dynamic>? ?? const {},
    );
  }
}
