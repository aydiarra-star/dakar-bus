import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/departure_info.dart';
import 'external_gtfs/departure_adapter.dart';
import '../models/transport_network.dart';

/// Service de chargement du réseau Dakar
/// CORRIGE : respecte le modèle TransportRoute (operatorId, type, stopIds)
/// + peut charger depuis assets/data/dakar_network.json OU fallback mémoire
class DataService {
  /// Same provider as the assistant. No source or crosswalk is invented here.
  DepartureAdapter? departureAdapter;

  DepartureInfo departureFor({required String network, required String? routeId,
      required String? stopId, String? directionId, DateTime? at}) {
    if (routeId == null || stopId == null) return const DepartureInfo.unknown();
    return departureAdapter?.resolve(network: network, routeId: routeId,
        stopId: stopId, directionId: directionId, at: at) ?? const DepartureInfo.unknown();
  }

  List<Operator> _operators = [];
  List<BusStop> _stops = [];
  List<TransportRoute> _routes = [];

  List<Operator> get operators => _operators;
  List<BusStop> get stops => _stops;
  List<TransportRoute> get routes => _routes;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Charge le réseau depuis assets/data/dakar_network.json
  /// Si le fichier n'existe pas ou erreur, charge les données de fallback
  Future<void> loadNetworkData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/dakar_network.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      // Utilise TransportNetwork pour parser
      final network = TransportNetwork.fromJson(data);
      _operators = network.operators;
      _stops = network.stops;
      _routes = network.routes;
      _loaded = true;
    } catch (e) {
      // Fallback : données en dur cohérentes avec le modèle
      await _loadFallbackData();
    }
  }

  /// Jeu de SECOURS minimal, utilisé seulement si l'asset JSON est illisible.
  ///
  /// Audit 2026-09-24 : ces entrées étaient marquées `DataTrust.official` sans
  /// aucune source (ex. « BRT Ligne 1 » à deux arrêts, qui n'existe pas sous
  /// cette forme). Elles sont désormais `DataTrust.unverified` et leur
  /// provenance vaut UNVERIFIED / UNKNOWN (valeur par défaut du modèle).
  Future<void> _loadFallbackData() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _operators = [
      Operator(id: 'brt', name: 'SunuBRT', colorHex: '#FFAB00'),
      Operator(id: 'ter', name: 'TER Dakar', colorHex: '#0052CC'),
      Operator(id: 'aftu', name: 'AFTU (Tata)', colorHex: '#00875A'),
      Operator(id: 'ddd', name: 'Dakar Dem Dikk', colorHex: '#DE350B'),
    ];

    _stops = [
      BusStop(
          id: 'stop_petersen',
          name: 'Gare Petersen',
          latitude: 14.6738,
          longitude: -17.4381,
          dataTrust: DataTrust.unverified),
      BusStop(
          id: 'stop_parcelles_u26',
          name: 'Parcelles Assainies U26',
          latitude: 14.7562,
          longitude: -17.4331,
          dataTrust: DataTrust.fieldObservation),
      BusStop(
          id: 'stop_guediawaye',
          name: 'Guédiawaye',
          latitude: 14.7735,
          longitude: -17.3977,
          dataTrust: DataTrust.unverified),
      BusStop(
          id: 'stop_palais',
          name: 'Palais de Justice',
          latitude: 14.6930,
          longitude: -17.4440,
          dataTrust: DataTrust.fieldObservation),
      BusStop(
          id: 'stop_yoff',
          name: 'Aéroport Yoff',
          latitude: 14.7645,
          longitude: -17.3660,
          dataTrust: DataTrust.unverified),
      BusStop(
          id: 'stop_sandaga',
          name: 'Sandaga',
          latitude: 14.6870,
          longitude: -17.4510,
          dataTrust: DataTrust.unverified),
    ];

    _routes = [
      TransportRoute(
        id: 'brt_1',
        operatorId: 'brt',
        shortName: 'BRT Ligne 1',
        longName: 'Gare Petersen <-> Parcelles Assainies',
        type: 'BRT',
        dataTrust: DataTrust.unverified,
        stopIds: ['stop_petersen', 'stop_parcelles_u26'],
      ),
      TransportRoute(
        id: 'aftu_12',
        operatorId: 'aftu',
        shortName: 'AFTU Ligne 12',
        longName: 'Guédiawaye <-> Palais de Justice',
        type: 'BUS',
        dataTrust: DataTrust.fieldObservation,
        stopIds: ['stop_guediawaye', 'stop_palais'],
      ),
      TransportRoute(
        id: 'ddd_8',
        operatorId: 'ddd',
        shortName: 'DDD Ligne 8',
        longName: 'Aéroport Yoff <-> Sandaga',
        type: 'BUS',
        dataTrust: DataTrust.unverified,
        stopIds: ['stop_yoff', 'stop_sandaga'],
      ),
      TransportRoute(
        id: 'line_tata_219',
        operatorId: 'aftu',
        shortName: 'Ligne 219',
        longName: 'Parcelles Assainies ⇄ Petersen',
        type: 'BUS',
        dataTrust: DataTrust.fieldObservation,
        stopIds: ['stop_parcelles_u26', 'stop_petersen'],
      ),
      TransportRoute(
        id: 'line_brt_b1',
        operatorId: 'brt',
        shortName: 'BRT B1',
        longName: 'Gare des Guéréos (Petersen) ⇄ Guédiawaye',
        type: 'BRT',
        dataTrust: DataTrust.unverified,
        stopIds: ['stop_petersen', 'stop_guediawaye'],
      ),
    ];
    _loaded = true;
  }

  /// Helpers pratiques
  List<BusStop> stopsForRoute(String routeId) {
    final route = _routes.firstWhere((r) => r.id == routeId,
        orElse: () => throw Exception('Route $routeId introuvable'));
    return route.stopIds
        .map((sid) => _stops.firstWhere((s) => s.id == sid))
        .toList();
  }

  Operator? operatorForRoute(TransportRoute route) {
    try {
      return _operators.firstWhere((o) => o.id == route.operatorId);
    } catch (_) {
      return null;
    }
  }
}
