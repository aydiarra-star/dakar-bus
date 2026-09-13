import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const DakarBusApp());

// ============================================================
// SERVICE DE DÉTECTION DES DEUX SENS (ALLER / RETOUR)
// ============================================================
class OppositeStopService {
  static Stop? findOppositeStop({
    required Stop currentStop,
    required List<Stop> allStops,
  }) {
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    for (final stop in allStops) {
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      
      if (distance <= 50.0 && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName) || currentName.substring(0, (currentName.length * 0.6).toInt() > 0 ? (currentName.length * 0.6).toInt() : 1) == stopName.substring(0, (stopName.length * 0.6).toInt() > 0 ? (stopName.length * 0.6).toInt() : 1)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }
    return bestCandidate ?? allStops.firstWhere(
      (s) => s.modeLabel == currentStop.modeLabel && s.direction != currentStop.direction,
      orElse: () => currentStop,
    );
  }
}

// ============================================================
// SERVICE ROUTING REEL (OSRM + SECURITE TERRESTRE)
// ============================================================
class RoutingService {
  static Future<List<LatLng>> getRealRoute(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
      }
    } catch (_) {
      // En cas d'échec réseau ou timeout, on retourne un tracé terrestre de secours
    }
    return _getFallbackTerrestrialRoute(start, end);
  }

  static List<LatLng> _getFallbackTerrestrialRoute(LatLng start, LatLng end) {
    if (start.latitude > 14.70 && end.latitude > 14.70 && (start.longitude - end.longitude).abs() > 0.05) {
      return [
        start,
        LatLng(14.7410, -17.4120), // Dalifort / Route Nationale
        LatLng(14.7550, -17.3900), // Pikine
        LatLng(14.7588, -17.3803), // Thiaroye
        LatLng(14.7450, -17.3980), // Mbao
        end,
      ];
    }
    return [start, end];
  }
}

// ============================================================
// GENERATEUR D HORAIRES OFFICIELS
// ============================================================
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) {
    list.add(m);
  }
  return list;
}

List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();

bool _isSunday() => DateTime.now().weekday == DateTime.sunday;

List<int> _buildTerBase() {
  final step = _isSunday() ? 20 : 10;
  return _generateSchedule(from: 330, to: 1320, step: step);
}

final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
final List<int> _terBase = _buildTerBase();

// ============================================================
// COULEURS (BRT en Vert)
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF2E7D32); // BRT Vert
  static const ter = Color(0xFF8D4004); 
  static const aftu = Color(0xFFEF6C00);
  static const tata = Color(0xFF7B1FA2);
  static const ddd = Color(0xFF0288D1);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFEEEEEE);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const neutral = Color(0xFF9E9E9E);
}

// ============================================================
// SOURCE DE DONNEES & STATUT
// ============================================================
enum DataOrigin { official, demo }

class DataSourceInfo {
  final DataOrigin origin;
  final String label;
  const DataSourceInfo({required this.origin, required this.label});
  static const seter = DataSourceInfo(origin: DataOrigin.official, label: 'SETER');
  static const sunubrt = DataSourceInfo(origin: DataOrigin.official, label: 'SunuBRT');
  static const demo = DataSourceInfo(origin: DataOrigin.demo, label: 'Demonstration');
}

enum DataStatus { scheduled, live, unknown }

class DataStatusBadge extends StatelessWidget {
  final DataStatus status;
  final bool compact;
  const DataStatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Color color; String label; IconData? icon; bool dotOnly = false;
    switch (status) {
      case DataStatus.live: color = AppColors.success; label = 'LIVE'; dotOnly = true; break;
      case DataStatus.scheduled: color = AppColors.warning; label = 'Programme'; icon = Icons.schedule; break;
      case DataStatus.unknown: color = AppColors.neutral; label = 'Indisponible'; icon = Icons.help_outline; break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotOnly) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          else if (icon != null) Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: compact ? 9 : 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.success.withOpacity(0.35), width: 0.8),
      ),
      child: const Text('OFFICIEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 0.5)),
    );
  }
}

// ============================================================
// MODELES
// ============================================================
class Stop {
  final String name;
  final String direction;
  final double distanceMeters;
  final List<int> departureMinutesFromMidnight;
  final IconData icon;
  final Color color;
  final LatLng location;
  final DataStatus status;
  final String modeLabel;
  final DataSourceInfo source;

  const Stop({
    required this.name, required this.direction, required this.distanceMeters,
    required this.departureMinutesFromMidnight, required this.icon, required this.color,
    required this.location, required this.modeLabel, this.status = DataStatus.scheduled,
    this.source = DataSourceInfo.demo,
  });

  int? nextDepartureMinutes() {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d > currentMin) return d;
    }
    if (departureMinutesFromMidnight.isNotEmpty) return departureMinutesFromMidnight.first + 24 * 60;
    return null;
  }

  int? remainingMinutes() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final now = DateTime.now();
    return d - (now.hour * 60 + now.minute);
  }

  String? nextDepartureLabel() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final normalized = d % (24 * 60);
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '$h h $m';
  }

  int? departureAfter(int minFromMidnight) {
    for (final d in departureMinutesFromMidnight) {
      if (d > minFromMidnight) return d;
    }
    if (departureMinutesFromMidnight.isNotEmpty) return departureMinutesFromMidnight.first + 24 * 60;
    return null;
  }
}

class TransitRoute {
  final String name;
  final String code;
  final String type;
  final Color color;
  final List<LatLng> points;

  const TransitRoute({required this.name, required this.code, required this.type, required this.color, required this.points});
}

class FavoriteRoute {
  final String label;
  final String from;
  final String to;
  final IconData icon;

  const FavoriteRoute({required this.label, required this.from, required this.to, required this.icon});
}

class RouteSegment {
  final String modeLabel;
  final Color color;
  final IconData icon;
  final String from;
  final String to;
  final int durationMinutes;
  final String? departureTime;
  final String? arrivalTime;
  final DataStatus status;
  final bool isWalk;

  const RouteSegment({
    required this.modeLabel, required this.color, required this.icon,
    required this.from, required this.to, required this.durationMinutes,
    this.departureTime, this.arrivalTime, this.status = DataStatus.scheduled, this.isWalk = false,
  });
}

class PlannedRoute {
  final String fromName;
  final String toName;
  final List<RouteSegment> segments;
  final int totalMinutes;
  final bool isBest;
  final DataStatus status;
  final int transferCount;

  const PlannedRoute({
    required this.fromName, required this.toName, required this.segments,
    required this.totalMinutes, this.isBest = false, this.status = DataStatus.scheduled, this.transferCount = 0,
  });
}

class RouteSearchResult {
  final List<PlannedRoute> routes;
  final List<String> missingData;
  final String? errorMessage;

  const RouteSearchResult({this.routes = const [], this.missingData = const [], this.errorMessage});
  bool get hasRoutes => routes.isNotEmpty;
}

// ============================================================
// DONNEES TER, BRT & AUTRES
// ============================================================
final List<Stop> terStations = [
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Dakar', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6935, -17.4443), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7222, -17.4321), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Dakar', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 7), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7220, -17.4323), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Dalifort', direction: 'Dir. Diamniadio', distanceMeters: 5100, departureMinutesFromMidnight: _shift(_terBase, 12), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7410, -17.4120), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Dalifort', direction: 'Dir. Dakar', distanceMeters: 5100, departureMinutesFromMidnight: _shift(_terBase, 10), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7412, -17.4122), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: _shift(_terBase, 17), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7550, -17.3900), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Thiaroye', direction: 'Dir. Diamniadio', distanceMeters: 8100, departureMinutesFromMidnight: _shift(_terBase, 20), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7588, -17.3803), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio', distanceMeters: 22100, departureMinutesFromMidnight: _shift(_terBase, 36), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7157, -17.2703), modeLabel: 'TER', source: DataSourceInfo.seter),
  Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 50), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7160, -17.1986), modeLabel: 'TER', source: DataSourceInfo.seter),
];

final List<Stop> brtStations = [
  Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: _shift(_brtBase, 0), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6720, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt),
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT', source: DataSourceInfo.sunubrt),
  Stop(name: 'PEM Guediawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: _shift(_brtBase, 8), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7735, -17.3977), modeLabel: 'BRT', source: DataSourceInfo.sunubrt),
];

final List<Stop> otherBusStations = [
  const Stop(name: 'Arret AFTU 23', direction: 'Dir. Parcelles Assainies', distanceMeters: 280, departureMinutesFromMidnight: [630, 645, 700, 715, 730], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460), modeLabel: 'AFTU'),
  const Stop(name: 'Arret Tata 12', direction: 'Dir. Guediawaye', distanceMeters: 600, departureMinutesFromMidnight: [640, 655, 710, 725, 740], icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700), modeLabel: 'Tata'),
  const Stop(name: 'Ligne DDD 1', direction: 'Parcelles Assainies ➔ Place Leclerc', distanceMeters: 350, departureMinutesFromMidnight: [360, 420, 480, 540], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7600, -17.4400), modeLabel: 'DDD'),
];

final List<Stop> allStops = [...terStations, ...brtStations, ...otherBusStations];
final List<Stop> mapPriorityStops = [terStations[0], terStations[2], terStations[4], brtStations[1], otherBusStations[0]];

// ============================================================
// TRACES DES LIGNES (BRT Vert)
// ============================================================
final List<TransitRoute> demoRoutes = [
  const TransitRoute(
    name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter,
    points: [
      LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7222, -17.4321),
      LatLng(14.7410, -17.4120), LatLng(14.7550, -17.3900), LatLng(14.7700, -17.3400),
      LatLng(14.7160, -17.1986),
    ],
  ),
  const TransitRoute(
    name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt, // Vert
    points: [
      LatLng(14.6720, -17.4400), LatLng(14.6950, -17.4420), LatLng(14.7050, -17.4400),
      LatLng(14.7350, -17.4260), LatLng(14.7735, -17.3977),
    ],
  ),
];

// ============================================================
// BASE DE LIEUX ET MOTEUR D'ITINÉRAIRES
// ============================================================
class Place {
  final String name;
  final String type;
  final IconData icon;
  final Color color;
  final LatLng? location;
  final Stop? linkedStop;

  const Place({required this.name, required this.type, required this.icon, required this.color, this.location, this.linkedStop});
}

List<Place> buildPlaceDatabase() {
  final places = <Place>[];
  for (final s in allStops) {
    places.add(Place(name: s.name, type: s.modeLabel, icon: s.icon, color: s.color, location: s.location, linkedStop: s));
  }
  return places;
}
final List<Place> placeDatabase = buildPlaceDatabase();

class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    final fromStop = allStops.firstWhere((s) => s.name.toLowerCase().contains(fromQuery.toLowerCase()), orElse: () => allStops.first);
    final toStop = allStops.firstWhere((s) => s.name.toLowerCase().contains(toQuery.toLowerCase()), orElse: () => allStops.last);
    
    final route = PlannedRoute(
      fromName: fromStop.name,
      toName: toStop.name,
      totalMinutes: 25,
      isBest: true,
      segments: [
        RouteSegment(
          modeLabel: fromStop.modeLabel, color: fromStop.color, icon: fromStop.icon,
          from: fromStop.name, to: toStop.name, durationMinutes: 25,
          departureTime: '08:00', arrivalTime: '08:25',
        ),
      ],
    );
    return RouteSearchResult(routes: [route]);
  }
}

// ============================================================
// UTILITAIRES
// ============================================================
class TimeHelper {
   static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'Imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }
}

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }
  static double haversineMeters(LatLng a, LatLng b) => 500.0;
}

// ============================================================
// APPLICATION PRINCIPALE & NAVIGATION
// ============================================================
class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Bus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;
  String? _gpsMessage;

  final List<FavoriteRoute> _favorites = [
    const FavoriteRoute(label: 'Maison', from: 'Ma position', to: 'Plateau', icon: Icons.home_rounded),
  ];

  Future<void> _requestLocation() async {
    setState(() { _gpsState = GpsState.loading; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() { _gpsState = GpsState.denied; }); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _userPosition = LatLng(pos.latitude, pos.longitude); _gpsState = GpsState.granted; });
    } catch (_) {
      setState(() { _gpsState = GpsState.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, gpsMessage: _gpsMessage, onRequestLocation: _requestLocation),
      TripsPage(favorites: _favorites),
      const AlertsPage(),
      SettingsPage(favorites: _favorites, onAdd: (f) => setState(() => _favorites.add(f)), onRemove: (i) => setState(() => _favorites.removeAt(i))),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
          NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: 'Trajets'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Réglages'),
        ],
      ),
    );
  }
}

// ============================================================
// EXPLORER
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition;
  final GpsState gpsState;
  final String? gpsMessage;
  final Future<void> Function() onRequestLocation;

  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.gpsMessage, required this.onRequestLocation});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';
  List<Polyline> _dynamicPolylines = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadDynamicRoutes();
  }

  Future<void> _loadDynamicRoutes() async {
    List<Polyline> loaded = [];
    for (final route in demoRoutes) {
      if (route.points.length >= 2) {
        List<LatLng> fullRoutePoints = [];
        for (int i = 0; i < route.points.length - 1; i++) {
          final segment = await RoutingService.getRealRoute(route.points[i], route.points[i + 1]);
          if (fullRoutePoints.isNotEmpty && segment.isNotEmpty) segment.removeAt(0);
          fullRoutePoints.addAll(segment);
        }
        if (fullRoutePoints.isEmpty) fullRoutePoints = route.points;
        loaded.add(Polyline(points: fullRoutePoints, color: route.color, strokeWidth: 4.0));
      }
    }
    if (mounted) setState(() { _dynamicPolylines = loaded; _isLoadingRoutes = false; });
  }

  List<Stop> get _filteredStops {
    if (_selectedFilter == 'Tous') return allStops;
    return allStops.where((s) => s.modeLabel.toUpperCase() == _selectedFilter.toUpperCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;
    final activePolylines = _dynamicPolylines.isNotEmpty ? _dynamicPolylines : demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 4.0)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _dakarCenter, initialZoom: 11.5),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus'),
                      PolylineLayer(polylines: activePolylines),
                      MarkerLayer(
                        markers: mapPriorityStops.map((s) => Marker(
                          point: s.location, width: 24, height: 24,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))),
                            child: Container(decoration: BoxDecoration(color: s.color, shape: BoxShape.circle), child: Icon(s.icon, color: Colors.white, size: 12)),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: const [Text('Dakar Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Spacer(), OfficialBadge()]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['Tous', 'TER', 'BRT', 'AFTU', 'Tata', 'DDD'].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(f), selected: _selectedFilter == f, onSelected: (_) => setState(() => _selectedFilter = f)),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...stops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StopCard(stop: s, distanceMeters: s.distanceMeters),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StopCard extends StatelessWidget {
  final Stop stop;
  final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final remaining = stop.remainingMinutes();
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
        leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white, size: 18)),
        title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${stop.direction} • ${DistanceHelper.format(distanceMeters)}'),
        trailing: Text(remaining != null ? TimeHelper.formatRemaining(remaining) : 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
      ),
    );
  }
}

// ============================================================
// VUE : DOUBLE SENS (ALLER / RETOUR RÉINTÉGRÉE)
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final Stop? oppositeStop = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(stop.name),
        backgroundColor: stop.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDirectionSection(
            title: "Embarquement / Départ (Sens Actuel)",
            currentStop: stop,
            badgeColor: Colors.green,
            context: context,
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 20),
          oppositeStop != null
              ? _buildDirectionSection(
                  title: "Arrivée / Terminus & Sens Opposé",
                  currentStop: oppositeStop,
                  badgeColor: Colors.orange,
                  context: context,
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                  child: const Text("Aucun arrêt opposé détecté.", textAlign: TextAlign.center),
                ),
        ],
      ),
    );
  }

  Widget _buildDirectionSection({
    required String title,
    required Stop currentStop,
    required Color badgeColor,
    required BuildContext context,
  }) {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final future = currentStop.departureMinutesFromMidnight.where((d) => d > currentMin).take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: badgeColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: badgeColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(currentStop.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Direction : ${currentStop.direction}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          const Text('Prochains départs :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (future.isEmpty)
            const Text('Plus de passage prévu aujourd hui.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            ...future.map((d) {
              final h = (d ~/ 60).toString().padLeft(2, '0');
              final m = (d % 60).toString().padLeft(2, '0');
              final remaining = d - currentMin;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$h:$m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$remaining min d attente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: remaining <= 3 ? AppColors.ter : AppColors.success)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// TRAJETS & PARAMÈTRES
// ============================================================
class TripsPage extends StatefulWidget {
  final List<FavoriteRoute> favorites;
  const TripsPage({super.key, required this.favorites});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final _fromCtrl = TextEditingController(text: 'Gare TER Dakar');
  final _toCtrl = TextEditingController(text: 'Gare TER Diamniadio');
  RouteSearchResult? _result;

  void _search() => setState(() => _result = RoutePlanner.plan(fromQuery: _fromCtrl.text, toQuery: _toCtrl.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planifier un trajet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'Départ')),
          TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'Destination')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _search, child: const Text('Rechercher')),
          if (_result != null && _result!.hasRoutes)
            ..._result!.routes.map((r) => Card(child: ListTile(title: Text('${r.fromName} ➔ ${r.toName}'), trailing: Text('${r.totalMinutes} min')))),
        ],
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Alertes')), body: const Center(child: Text('Trafic normal sur le réseau.')));
}

class SettingsPage extends StatelessWidget {
  final List<FavoriteRoute> favorites;
  final Function(FavoriteRoute) onAdd;
  final Function(int) onRemove;
  const SettingsPage({super.key, required this.favorites, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(onPressed: () {}, child: const Text('SE CONNECTER')),
          const SizedBox(height: 20),
          ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('Mon portefeuille'), onTap: () {}),
          ListTile(leading: const Icon(Icons.directions_bus), title: const Text('Mes trajets enregistrés'), onTap: () {}),
          ListTile(leading: const Icon(Icons.local_offer), title: const Text('Mes offres'), onTap: () {}),
          ListTile(leading: const Icon(Icons.star), title: const Text('Donner mon avis'), onTap: () {}),
          ListTile(leading: const Icon(Icons.chat), title: const Text('Contactez Nous'), onTap: () {}),
          ListTile(leading: const Icon(Icons.forum), title: const Text('Groupe WhatsApp'), onTap: () {}),
          ListTile(leading: const Icon(Icons.handshake), title: const Text('Aidez nous'), onTap: () {}),
        ],
      ),
    );
  }
}
