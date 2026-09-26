import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/departure_info.dart';
import '../models/schedule_models.dart';
import '../models/transport_network.dart';
import 'clock.dart';
import 'data_provider.dart';
import 'realtime_provider.dart';
import 'schedule_provider.dart';
import 'schedule_service.dart';

/// Service de chargement du réseau Dakar
/// CORRIGE : respecte le modèle TransportRoute (operatorId, type, stopIds)
/// + peut charger depuis assets/data/dakar_network.json OU fallback mémoire
class DataService {
  final FrequencyProvider _frequencyProvider;
  final ScheduleProvider _scheduleProvider;
  final RealtimeProvider _realtimeProvider;
  final Clock _clock;
  final Duration? _realtimeMaxAge;

  DataService({
    DataProvider? dataProvider,
    FrequencyProvider? frequencyProvider,
    ScheduleProvider? scheduleProvider,
    RealtimeProvider? realtimeProvider,
    Clock? clock,
    Duration? realtimeMaxAge,
  })  : _frequencyProvider =
            frequencyProvider ?? dataProvider ?? FrequencyProvider(),
        _scheduleProvider = scheduleProvider ?? const EmptyScheduleProvider(),
        _realtimeProvider = realtimeProvider ?? const EmptyRealtimeProvider(),
        _clock = clock ?? const SystemClock(),
        _realtimeMaxAge = realtimeMaxAge;

  /// Résout une fréquence publiée en ESTIMATED uniquement lorsqu'elle
  /// s'applique à l'instant demandé. Aucun horaire par arrêt n'est construit.
  DepartureInfo departureInfoForRoute(
    String routeId,
    DateTime requestedAt, {
    bool isPublicHoliday = false,
    String? operatorName,
    String? stopId,
    int? directionId,
    ServiceDate? serviceDate,
  }) {
    if (stopId != null && !_hasUniqueRouteStop(routeId, stopId)) {
      return DepartureInfo.unknown(
        operator: operatorName ?? 'Inconnu',
        routeId: routeId,
        requestedAt: requestedAt,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
      );
    }
    return _frequencyProvider.departureInfoForRoute(
      routeId,
      requestedAt,
      isPublicHoliday: isPublicHoliday,
      operatorName: operatorName,
      stopId: stopId,
      directionId: directionId,
      serviceDate: serviceDate,
    );
  }

  /// Adaptateur historique consommé par Stop. L'horloge est injectable ; le
  /// nouveau moteur ci-dessous exige toujours now explicitement.
  DepartureInfo departureFor({
    required String? routeId,
    required String? stopId,
    required String network,
    DateTime? at,
    bool isPublicHoliday = false,
  }) {
    final DateTime instant = at?.toUtc() ?? _clock.now().toUtc();
    if (routeId == null || stopId == null) {
      return DepartureInfo.unknown(
        operator: network,
        routeId: routeId ?? 'unknown',
        requestedAt: instant,
      );
    }
    if (!_hasUniqueRouteStop(routeId, stopId)) {
      return DepartureInfo.unknown(
        operator: network,
        routeId: routeId,
        requestedAt: instant,
        stopId: stopId,
      );
    }
    // Cette branche conserve seulement une fréquence de ligne. La vérification
    // route.stopIds ne remplace jamais la relation trip -> stop_time du moteur.
    return departureInfoForRoute(
      routeId,
      instant,
      isPublicHoliday: isPublicHoliday,
      operatorName: network,
      stopId: stopId,
    );
  }

  /// API horaire explicite : aucune lecture d'horloge, aucune résolution de
  /// stop par nom/proximité et aucune interprétation de route.stopIds comme
  /// stop_times. Les départs exacts proviennent exclusivement de ScheduleEngine.
  DepartureSearchResult nextDepartureFor({
    required String routeId,
    required String stopId,
    int? directionId,
    required ServiceDate serviceDate,
    required DateTime now,
  }) {
    final bool routeStopKnownForFrequency = _hasUniqueRouteStop(routeId, stopId);

    return ScheduleEngine(
      dataset: _scheduleProvider.dataset,
      // route.stopIds est utilisé uniquement pour borner un repli ESTIMATED.
      // Une réponse SCHEDULED/REAL_TIME dépend exclusivement du dataset trips.
      frequencyProvider:
          routeStopKnownForFrequency ? _frequencyProvider : null,
      realtimePredictions: _realtimeProvider.predictions,
      realtimeMaxAge: _realtimeMaxAge,
    ).nextDepartureFor(
      routeId: routeId,
      stopId: stopId,
      directionId: directionId,
      serviceDate: serviceDate,
      now: now,
    );
  }

  /// Un repli de fréquence n'est permis que si les clés route/stop sont
  /// uniques dans le réseau déjà chargé. Cela ne valide jamais un StopTime.
  bool _hasUniqueRouteStop(String routeId, String stopId) {
    final List<TransportRoute> matchingRoutes =
        _routes.where((TransportRoute route) => route.id == routeId).toList();
    final List<BusStop> matchingStops =
        _stops.where((BusStop stop) => stop.id == stopId).toList();
    return matchingRoutes.length == 1 &&
        matchingRoutes.single.stopIds.contains(stopId) &&
        matchingStops.length == 1;
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
