import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/departure_info.dart';
import '../models/public_bus_line.dart';
import '../models/service_availability.dart';
import '../models/transport_network.dart';
import 'data_provider.dart';
import 'dakar_clock.dart';
import 'eta_calculator.dart';
import 'gtfs/network_access.dart';
import 'gtfs/passbi_source.dart';
import 'gtfs/routing_engine.dart';
import 'schedule_provider.dart';
import 'public_bus_line_catalog.dart';
import 'terminus_catalog.dart';

/// Service de chargement du réseau Dakar
/// CORRIGE : respecte le modèle TransportRoute (operatorId, type, stopIds)
/// + peut charger depuis assets/data/dakar_network.json OU fallback mémoire
///
/// Lot 4.18 : intègration des feeds GTFS PassBi (source opérationnelle
/// actuelle, `SourceType.publicGtfs`). La chaîne est
/// DataService → ScheduleProvider → EtaCalculator → moteur de routage → UI.
class DataService {
  final DataProvider _dataProvider;

  DataService({DataProvider? dataProvider})
      : _dataProvider = dataProvider ?? DataProvider();

  /// Source opérationnelle PassBi (quatre feeds GTFS, un seul lecteur).
  final PassBiSource passBiSource = PassBiSource();
  late final ScheduleProvider scheduleProvider =
      ScheduleProvider(passBiSource);
  late final EtaCalculator etaCalculator = EtaCalculator(
    scheduleProvider: scheduleProvider,
    frequencyProvider: _dataProvider,
  );
  late final PassBiRoutingEngine routingEngine =
      PassBiRoutingEngine(passBiSource);

  /// Chantier DDD/AFTU/TATA — référentiel pôles & terminus (lecture seule).
  final TerminusCatalog terminusCatalog = TerminusCatalog();

  /// MISSION — référentiel public des lignes AFTU / TATA / DDD (lecture seule).
  /// Numéros officiels, terminus publiés, raccordement horaire. Aucun horaire,
  /// aucun arrêt, aucune correspondance n'y est fabriqué.
  final PublicBusLineCatalog publicBusLineCatalog = PublicBusLineCatalog();

  /// Chantier « Recherche + GPS + Routage » — accès au réseau depuis une
  /// position : arrêts réels accessibles à pied, réseau par réseau.
  late final NetworkAccessIndex networkAccessIndex =
      NetworkAccessIndex(passBiSource);

  /// Chargement du référentiel pôles/terminus DDD/AFTU. Non bloquant :
  /// un échec laisse le catalogue vide sans impacter TER/BRT ni les horaires.
  Future<void> loadTerminusCatalog() => terminusCatalog.load();

  /// Chargement du référentiel public des lignes AFTU/DDD. Non bloquant.
  Future<void> loadPublicBusLineCatalog() => publicBusLineCatalog.load();

  /// Fiche ligne — séquence d'arrêts ORDONNÉE d'une ligne publique raccordée.
  ///
  /// Lit la route PassBi RÉELLE de la ligne (`feed_route_ids`) et ses
  /// `stop_times` réels, ordonnés par `stop_sequence`. Retourne `null` si la
  /// ligne n'est pas raccordée à une route réelle : aucune fiche n'est
  /// fabriquée pour une ligne BLOCKED / NOT_VERIFIED.
  PassBiRouteStopSequence? publicLineStopSequence(PublicBusLine line) {
    if (!line.hasRealSchedule) return null;
    final network = line.operator; // DDD | AFTU — clés de feed PassBi
    for (final routeId in line.feedRouteIds) {
      final seq = passBiSource.routeStopSequence(network, routeId);
      if (seq != null && !seq.isEmpty) return seq;
    }
    return null;
  }

  /// Chargement des horaires PassBi (distinct de loadNetworkData).
  /// En cas d'échec, l'app reste sur les données legacy — jamais de plantage.
  Future<void> loadPassBiSchedules() async {
    try {
      await passBiSource.loadAll();
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ PassBi GTFS indisponible (mode legacy) : $e');
    }
  }

  bool get passBiActive => passBiSource.isActive;

  /// Planification PassBi entre arrêts du référentiel dakar (via crosswalk).
  List<PassBiJourney> planPassBiJourneys({
    required Set<String> fromPassBiKeys,
    required Set<String> toPassBiKeys,
    required DateTime at,
    int maxResults = 4,
  }) =>
      routingEngine.planJourneys(
        fromKeys: fromPassBiKeys,
        toKeys: toPassBiKeys,
        at: at,
        maxResults: maxResults,
      );

  /// Clés PassBi (composite) correspondant à un arrêt dakar — tous réseaux.
  Set<String> passBiStopKeysForDakarStop(String dakarStopId) =>
      passBiSource.compositeStopsForDakarStop(dakarStopId);

  // ======================================================================
  // CHANTIER « RECHERCHE + GPS + ROUTAGE » — le GPS, entrée du routage
  // ======================================================================

  /// Arrêts RÉELS accessibles à pied autour d'une position, tous réseaux
  /// (DDD, AFTU, BRT, TER). Retourne un ENSEMBLE de candidats — jamais un seul
  /// arrêt — avec leur distance mesurée. Aucun arrêt n'est fabriqué.
  List<NetworkAccessPoint> accessPointsNear({
    required double lat,
    required double lon,
    double? radiusMeters,
  }) {
    if (radiusMeters == null) {
      return networkAccessIndex.accessPointsNear(lat: lat, lon: lon);
    }
    return NetworkAccessIndex(passBiSource, radiusMeters: radiusMeters)
        .accessPointsNear(lat: lat, lon: lon);
  }

  /// Mobilités (TER, BRT, DDD, AFTU) réellement disponibles autour d'une
  /// position : « quelles mobilités puis-je prendre depuis ici ? ».
  Set<String> mobilitiesNear({required double lat, required double lon}) =>
      networkAccessIndex.networksNear(lat: lat, lon: lon);

  /// Points de sortie accessibles à pied autour d'une destination.
  List<NetworkAccessPoint> exitPointsNear({
    required double lat,
    required double lon,
    double? radiusMeters,
  }) =>
      accessPointsNear(lat: lat, lon: lon, radiusMeters: radiusMeters);

  /// Planning **porte-à-porte** entre une position de départ et une position
  /// d'arrivée : les points d'accès et de sortie sont dérivés des coordonnées
  /// réelles, puis le moteur PassBi explore `route → trip → service →
  /// stop_sequence` (correspondances documentées uniquement).
  ///
  /// Retourne plusieurs itinéraires candidats, comparés sur la durée totale
  /// (marche + transport). Liste vide si aucun chemin documenté n'existe —
  /// jamais d'itinéraire inventé.
  List<PassBiJourney> planJourneysFromPositions({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required DateTime at,
    int maxResults = 4,
    double? radiusMeters,
  }) {
    final origins = accessPointsNear(
        lat: fromLat, lon: fromLon, radiusMeters: radiusMeters);
    final exits = exitPointsNear(
        lat: toLat, lon: toLon, radiusMeters: radiusMeters);
    if (origins.isEmpty || exits.isEmpty) return const <PassBiJourney>[];
    final originWalk = <String, int>{
      for (final p in origins) p.compositeKey: p.walkSeconds,
    };
    final originMeters = <String, double>{
      for (final p in origins) p.compositeKey: p.distanceMeters,
    };
    final exitMeters = <String, double>{
      for (final p in exits) p.compositeKey: p.distanceMeters,
    };
    return routingEngine.planJourneysWithAccess(
      fromKeys: origins.map((p) => p.compositeKey).toSet(),
      toKeys: exits.map((p) => p.compositeKey).toSet(),
      at: at,
      originWalkSeconds: originWalk,
      originAccessMeters: originMeters,
      destinationAccessMeters: exitMeters,
      maxResults: maxResults,
    );
  }

  // ======================================================================
  // LOT 4.21 — PASSBI NATIF (DDD / AFTU) : identité ≠ exploitation horaire
  // ======================================================================

  /// §1 — Fiches d'audit du feed d'un réseau (routes, horaires calculables,
  /// identité publique). Sert aux tests, à la documentation et aux surfaces
  /// existantes ; aucune donnée n'est recopiée ni inventée.
  List<PassBiRouteSummary> passBiRouteSummaries(String networkKey) =>
      passBiSource.routeSummaries(networkKey);

  /// Liste plate de toutes les fiches d'audit, tous feeds confondus.
  List<PassBiRouteSummary> passBiAudit() => <PassBiRouteSummary>[
        for (final key in PassBiSource.assetFiles.keys)
          ...passBiSource.routeSummaries(key),
      ];

  /// §2/§7 — Arrêts PassBi natifs d'un réseau (réellement appelés).
  List<PassBiStopRef> passBiNativeStops(String networkKey) =>
      passBiSource.nativeStops(networkKey);

  /// §6 — Disponibilité d'un réseau comme feed GTFS PassBi autonome.
  /// TATA → `absentFromFeed` : aucune route n'est fabriquée.
  PassBiNetworkAvailability passBiNetworkAvailability(String networkKey) =>
      passBiSource.networkAvailability(networkKey);

  /// §6 — Preuve d'absence : occurrences de « tata » dans les métadonnées
  /// PassBi réellement chargées (vide attendu).
  List<String> passBiTataMentions() => passBiSource.tataMentions();

  /// §8 — Recherche d'arrêts PassBi natifs par nom réel (saisie utilisateur).
  List<PassBiStopRef> passBiStopSearch(String query, {Set<String>? networks}) =>
      passBiSource.searchNativeStops(query, networksFilter: networks);

  /// Lot fin de service — disponibilité du service journalier d'une mobilité
  /// PassBi (TER, BRT, DDD, AFTU) à [at] (heure de Dakar).
  ///
  /// S'appuie EXCLUSIVEMENT sur les bornes documentées du feed (premier et
  /// dernier départ embarquable du service actif). Ne fabrique aucune heure :
  /// un réseau sans feed (TATA) ou sans `stop_time` reste `unknown`. Le calcul
  /// est indépendant de l'arrêt consulté (un arrêt peut ne plus avoir de départ
  /// alors que le réseau roule encore).
  ServiceAvailability serviceAvailabilityFor(String networkKey, DateTime at) {
    return computeNetworkServiceAvailability(
      network: passBiSource.network(networkKey),
      at: at,
      isScheduleAvailable: (net) =>
          passBiSource.schedulableRouteCount(net.key) > 0,
    );
  }

  /// §4/§5/§9 — Prochain départ sur le référentiel natif PassBi.
  /// SCHEDULED (départ réel d'un trip/stop_time) ou UNKNOWN motivé.
  DepartureInfo passBiDepartureFor({
    required String networkKey,
    required String pbStopId,
    DateTime? at,
    String? pbRouteId,
    bool isPublicHoliday = false,
  }) =>
      etaCalculator.computePassBi(
        networkKey: networkKey,
        pbStopId: pbStopId,
        at: at ?? DakarClock.now(),
        pbRouteId: pbRouteId,
        isPublicHoliday: isPublicHoliday,
      );

  /// Variante par clé composite « NET:id » (utilisée par les arrêts natifs).
  DepartureInfo passBiDepartureForCompositeStop({
    required String compositeStopId,
    DateTime? at,
    bool isPublicHoliday = false,
  }) {
    final parts = PassBiSource.splitComposite(compositeStopId);
    if (parts == null) {
      return DepartureInfo.unknown(
        // Repli neutre : le nom de la source de données n'est jamais affiché.
        operator: 'Bus',
        routeId: compositeStopId,
        requestedAt: at,
        unresolvedReason: UnresolvedReason.stopNotMatched,
      );
    }
    return passBiDepartureFor(
      networkKey: parts[0],
      pbStopId: parts[1],
      at: at,
      isPublicHoliday: isPublicHoliday,
    );
  }

  /// Lot 4.22 (Explorer) — Jusqu'à [limit] prochains passages RÉELS d'un
  /// arrêt natif PassBi (clé composite « NET:id »). Vrais trips + stop_times
  /// uniquement ; une fréquence ne produit jamais de liste de départs.
  List<DepartureInfo> passBiNextDeparturesForCompositeStop({
    required String compositeStopId,
    DateTime? at,
    int limit = 3,
  }) {
    final parts = PassBiSource.splitComposite(compositeStopId);
    if (parts == null) return const <DepartureInfo>[];
    return scheduleProvider.nextDeparturesAtPassBiStop(
      networkKey: parts[0],
      pbStopId: parts[1],
      requestedAt: at ?? DakarClock.now(),
      limit: limit,
    );
  }

  /// Lot 4.22 (Explorer) — Jusqu'à [limit] prochains passages RÉELS d'un
  /// couple (route, arrêt) du référentiel dakar (crosswalk PassBi). Liste
  /// vide si aucun stop_time réel n'est calculable — jamais de faux temps.
  List<DepartureInfo> nextDeparturesFor({
    required String? routeId,
    required String? stopId,
    required String network,
    DateTime? at,
    bool isPublicHoliday = false,
    int limit = 3,
  }) {
    if (routeId == null || stopId == null) return const <DepartureInfo>[];
    return scheduleProvider.nextDeparturesAt(
      routeId: routeId,
      stopId: stopId,
      requestedAt: at ?? DakarClock.now(),
      isPublicHoliday: isPublicHoliday,
      limit: limit,
    );
  }

  /// Résout une fréquence officielle en ESTIMATED uniquement lorsqu'elle
  /// s'applique à la date/heure demandée. Aucun horaire station par station
  /// n'est construit ; les lignes sans source restent UNKNOWN.
  DepartureInfo departureInfoForRoute(
    String routeId,
    DateTime requestedAt, {
    bool isPublicHoliday = false,
    String? operatorName,
  }) =>
      _dataProvider.departureInfoForRoute(
        routeId,
        requestedAt,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );

  /// Entry point consumed by Stop. Unknown/incomplete identities remain UNKNOWN.
  DepartureInfo departureFor({
    required String? routeId,
    required String? stopId,
    required String network,
    DateTime? at,
    bool isPublicHoliday = false,
  }) {
    if (routeId == null || stopId == null) {
      return DepartureInfo.unknown(
        operator: network,
        routeId: routeId ?? 'unknown',
        requestedAt: at,
      );
    }
    final route = _routes.where((candidate) => candidate.id == routeId);
    if (route.length != 1 || !route.single.stopIds.contains(stopId)) {
      return DepartureInfo.unknown(
        operator: network,
        routeId: routeId,
        requestedAt: at,
      );
    }
    // Lot 4.18 : horaires PassBi (SCHEDULED) en priorité, puis fréquences
    // officielles legacy (ESTIMATED), sinon UNKNOWN. Jamais de REAL_TIME.
    // FUSION LOT 1 (#40) : la référence par défaut reste l'heure de Dakar
    // ([DakarClock.now]) et non l'heure locale du navigateur.
    return etaCalculator.compute(
      routeId: routeId,
      stopId: stopId,
      network: network,
      at: at ?? DakarClock.now(),
      isPublicHoliday: isPublicHoliday,
      operatorName: network,
    );
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
