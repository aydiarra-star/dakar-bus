import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

// ============================================================
// COULEURS (inchangées)
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFFE53935);
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
// STATUT DE FIABILITÉ
// ============================================================
enum DataStatus { scheduled, live, unknown }

class DataStatusBadge extends StatelessWidget {
  final DataStatus status;
  final bool compact;
  const DataStatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData? icon;
    bool dotOnly = false;

    switch (status) {
      case DataStatus.live:
        color = AppColors.success;
        label = 'LIVE';
        dotOnly = true;
        break;
      case DataStatus.scheduled:
        color = AppColors.warning;
        label = 'Programmé';
        icon = Icons.schedule;
        break;
      case DataStatus.unknown:
        color = AppColors.neutral;
        label = 'Indisponible';
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotOnly)
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          else if (icon != null)
            Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODÈLES
// ============================================================
class Stop {
  final String name;
  final String direction;
  final double distanceMeters;
  final List<int> departureMinutesFromMidnight; // [700, 723, 745, ...]
  final IconData icon;
  final Color color;
  final LatLng location;
  final DataStatus status;

  const Stop({
    required this.name,
    required this.direction,
    required this.distanceMeters,
    required this.departureMinutesFromMidnight,
    required this.icon,
    required this.color,
    required this.location,
    this.status = DataStatus.scheduled,
  });

  // Prochain départ futur selon l'heure actuelle
  int? nextDepartureMinutes() {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d > currentMin) return d;
    }
    // Si tous les départs sont passés, prendre le premier du lendemain (avec +24h)
    if (departureMinutesFromMidnight.isNotEmpty) {
      return departureMinutesFromMidnight.first + 24 * 60;
    }
    return null;
  }

  // Minutes restantes avant le prochain départ
  int? remainingMinutes() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    return d - currentMin;
  }

  // Heure formatée du prochain départ
  String? nextDepartureLabel() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final normalized = d % (24 * 60);
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '${h}h$m';
  }
}

class TransitRoute {
  final String name, code, type;
  final Color color;
  final List<LatLng> points;
  const TransitRoute({
    required this.name, required this.code, required this.type,
    required this.color, required this.points,
  });
}

class FavoriteRoute {
  final String label;
  final String from;
  final String to;
  final IconData icon;
  const FavoriteRoute({required this.label, required this.from, required this.to, required this.icon});
}

// ============================================================
// UTILITAIRES
// ============================================================
class TimeHelper {
  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'Départ imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  static bool isImminent(int minutes) => minutes <= 1;
}

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  // Distance Haversine entre deux points GPS
  static double haversineMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * 3.141592653589793 / 180;
    final lat2 = b.latitude * 3.141592653589793 / 180;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLon = (b.longitude - a.longitude) * 3.141592653589793 / 180;
    final h = (1 - _cos(dLat)) / 2 +
        _cos(lat1) * _cos(lat2) * (1 - _cos(dLon)) / 2;
    return 2 * earthRadius * _asin(_sqrt(h));
  }

  static double _cos(double x) {
    // Approximation suffisante via dart:math non importé ici → on utilise Math
    return _mathCos(x);
  }

  static double _asin(double x) => _mathAsin(x);
  static double _sqrt(double x) => _mathSqrt(x);
}

// Fallback simple sans dart:math
double _mathCos(double x) {
  // Taylor rapide (suffisant pour lat/lon)
  final x2 = x * x;
  return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
}

double _mathAsin(double x) {
  if (x < -1) return -1.5708;
  if (x > 1) return 1.5708;
  return x + (x * x * x) / 6 + (3 * x * x * x * x * x) / 40;
}

double _mathSqrt(double x) {
  if (x <= 0) return 0;
  double r = x;
  for (int i = 0; i < 20; i++) {
    r = (r + x / r) / 2;
  }
  return r;
}

// ============================================================
// DONNÉES (horaires programmés — départs en minutes depuis minuit)
// ============================================================
final List<Stop> terStations = [
  const Stop(
    name: 'Gare TER Dakar', direction: 'Terminus Dakar',
    distanceMeters: 350,
    departureMinutesFromMidnight: [640, 700, 720, 740, 800, 820, 900, 960, 1020, 1080, 1140, 1200],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407),
  ),
  const Stop(
    name: 'Gare TER Colobane', direction: 'Dir. Diamniadio',
    distanceMeters: 1200,
    departureMinutesFromMidnight: [645, 705, 725, 745, 805, 825, 905, 965, 1025, 1085, 1145, 1205],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441),
  ),
  const Stop(
    name: 'Gare TER Hann', direction: 'Dir. Diamniadio',
    distanceMeters: 3500,
    departureMinutesFromMidnight: [650, 710, 730, 750, 810, 830, 910, 970, 1030, 1090, 1150, 1210],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7222, -17.4321),
  ),
  const Stop(
    name: 'Gare TER Pikine', direction: 'Dir. Diamniadio',
    distanceMeters: 7200,
    departureMinutesFromMidnight: [700, 720, 740, 800, 820, 840, 920, 980, 1040, 1100, 1160, 1220],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7550, -17.3900),
  ),
  const Stop(
    name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio',
    distanceMeters: 22100,
    departureMinutesFromMidnight: [720, 740, 800, 820, 840, 900, 940, 1000, 1060, 1120, 1180, 1240],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7157, -17.2703),
  ),
  const Stop(
    name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio',
    distanceMeters: 35000,
    departureMinutesFromMidnight: [740, 800, 820, 840, 900, 920, 960, 1020, 1080, 1140, 1200, 1260],
    icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7160, -17.1986),
  ),
];

final List<Stop> otherStations = [
  const Stop(
    name: 'PEM Petersen', direction: 'Terminus sud BRT',
    distanceMeters: 200,
    departureMinutesFromMidnight: [630, 636, 642, 648, 654, 700, 706, 712, 718, 724, 730, 736],
    icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6720, -17.4400),
  ),
  const Stop(
    name: 'BRT Colobane', direction: 'Dir. Guédiawaye',
    distanceMeters: 150,
    departureMinutesFromMidnight: [635, 641, 647, 653, 659, 705, 711, 717, 723, 729, 735, 741],
    icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420),
  ),
  const Stop(
    name: 'BRT Grand Dakar', direction: 'Dir. Guédiawaye',
    distanceMeters: 1500,
    departureMinutesFromMidnight: [640, 646, 652, 658, 704, 710, 716, 722, 728, 734, 740, 746],
    icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7050, -17.4400),
  ),
  const Stop(
    name: 'BRT Parcelles', direction: 'Dir. Guédiawaye',
    distanceMeters: 5000,
    departureMinutesFromMidnight: [650, 656, 702, 708, 714, 720, 726, 732, 738, 744, 750, 756],
    icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7350, -17.4260),
  ),
  const Stop(
    name: 'PEM Guédiawaye', direction: 'Terminus nord BRT',
    distanceMeters: 10500,
    departureMinutesFromMidnight: [700, 706, 712, 718, 724, 730, 736, 742, 748, 754, 800, 806],
    icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977),
  ),
  const Stop(
    name: 'Arrêt AFTU 23', direction: 'Dir. Parcelles Assainies',
    distanceMeters: 280,
    departureMinutesFromMidnight: [630, 645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915],
    icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460),
  ),
  const Stop(
    name: 'Arrêt AFTU 10', direction: 'Dir. Grand Yoff',
    distanceMeters: 450,
    departureMinutesFromMidnight: [635, 650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920],
    icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.7200, -17.4600),
  ),
  const Stop(
    name: 'Arrêt Tata 12', direction: 'Dir. Guédiawaye',
    distanceMeters: 600,
    departureMinutesFromMidnight: [640, 655, 710, 725, 740, 755, 810, 825, 840, 855, 910, 925],
    icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700),
  ),
  const Stop(
    name: 'Arrêt DDD 12', direction: 'Dir. Ouakam',
    distanceMeters: 800,
    departureMinutesFromMidnight: [645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915, 930],
    icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900),
  ),
  const Stop(
    name: 'Arrêt DDD 7', direction: 'Dir. Plateau',
    distanceMeters: 1200,
    departureMinutesFromMidnight: [650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920, 935],
    icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7350, -17.4500),
  ),
];

final List<Stop> allStops = [...terStations, ...otherStations];

final List<Stop> mapPriorityStops = [
  terStations[0], terStations[1], terStations[3], terStations[4], terStations[5],
  otherStations[1], otherStations[4], otherStations[8],
];

final List<TransitRoute> demoRoutes = [
  const TransitRoute(name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter, points: [
    LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7222, -17.4321),
    LatLng(14.7410, -17.4120), LatLng(14.7550, -17.3900), LatLng(14.7700, -17.3400),
    LatLng(14.7750, -17.3100), LatLng(14.7500, -17.2900), LatLng(14.7157, -17.2703),
    LatLng(14.6900, -17.2200), LatLng(14.7160, -17.1986),
  ]),
  const TransitRoute(name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt, points: [
    LatLng(14.6720, -17.4400), LatLng(14.6950, -17.4420), LatLng(14.7050, -17.4400),
    LatLng(14.7220, -17.4330), LatLng(14.7350, -17.4260), LatLng(14.7520, -17.4100),
    LatLng(14.7735, -17.3977),
  ]),
  const TransitRoute(name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu, points: [
    LatLng(14.7600, -17.4400), LatLng(14.7350, -17.4460), LatLng(14.7080, -17.4485),
    LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400),
  ]),
  const TransitRoute(name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata, points: [
    LatLng(14.7735, -17.3977), LatLng(14.7480, -17.4280), LatLng(14.7240, -17.4560),
    LatLng(14.7080, -17.4700), LatLng(14.6880, -17.4620), LatLng(14.6750, -17.4400),
  ]),
  const TransitRoute(name: 'DDD', code: 'DDD-12', type: 'DDD', color: AppColors.ddd, points: [
    LatLng(14.7350, -17.5100), LatLng(14.7250, -17.4900), LatLng(14.7100, -17.4700),
    LatLng(14.6950, -17.4550), LatLng(14.6800, -17.4450),
  ]),
];

// ============================================================
// APP
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
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
  Timer? _ticker;

  // État GPS
  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;

  List<FavoriteRoute> _favorites = [
    const FavoriteRoute(label: 'Maison', from: 'Ma position', to: 'Plateau', icon: Icons.home_rounded),
    const FavoriteRoute(label: 'Travail', from: 'Ma position', to: 'Parcelles Assainies', icon: Icons.work_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Rafraîchit l'UI toutes les 30 secondes pour recalculer les horaires
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    setState(() => _gpsState = GpsState.loading);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // Sur le web, GPS natif indisponible. On utilise une position de référence.
    // Sur natif, remplacer par Geolocator.
    setState(() {
      _userPosition = const LatLng(14.6937, -17.4441); // Colobane (référence)
      _gpsState = GpsState.granted;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position obtenue'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _addFavorite(FavoriteRoute fav) => setState(() => _favorites.add(fav));
  void _removeFavorite(int i) => setState(() => _favorites.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(
        userPosition: _userPosition,
        gpsState: _gpsState,
        onRequestLocation: _requestLocation,
      ),
      TripsPage(favorites: _favorites),
      const AlertsPage(),
      SettingsPage(
        favorites: _favorites,
        onAdd: _addFavorite,
        onRemove: _removeFavorite,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Réglages'),
            ],
          ),
        ),
      ),
    );
  }
}

enum GpsState { idle, loading, granted, denied }

// ============================================================
// EXPLORER
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition;
  final GpsState gpsState;
  final Future<void> Function() onRequestLocation;

  const ExplorerPage({
    super.key,
    required this.userPosition,
    required this.gpsState,
    required this.onRequestLocation,
  });

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';
  int _mapHeight = 240;
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void didUpdateWidget(covariant ExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userPosition != null && oldWidget.userPosition == null) {
      _mapController.move(widget.userPosition!, 14.5);
    }
  }

  List<Stop> get _filteredStops {
    List<Stop> base;
    switch (_selectedFilter) {
      case 'TER': base = allStops.where((s) => s.color == AppColors.ter).toList(); break;
      case 'BRT': base = allStops.where((s) => s.color == AppColors.brt).toList(); break;
      case 'AFTU': base = allStops.where((s) => s.color == AppColors.aftu).toList(); break;
      case 'Tata': base = allStops.where((s) => s.color == AppColors.tata).toList(); break;
      case 'DDD': base = allStops.where((s) => s.color == AppColors.ddd).toList(); break;
      default: base = List.from(allStops); break;
    }
    // Tri par distance si position connue
    if (widget.userPosition != null) {
      base.sort((a, b) {
        final da = DistanceHelper.haversineMeters(widget.userPosition!, a.location);
        final db = DistanceHelper.haversineMeters(widget.userPosition!, b.location);
        return da.compareTo(db);
      });
    }
    return base;
  }

  double _distanceTo(Stop s) {
    if (widget.userPosition == null) return s.distanceMeters;
    return DistanceHelper.haversineMeters(widget.userPosition!, s.location);
  }

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.direction.toLowerCase().contains(q)
    ).take(8).toList();
  }

  void _centerOnStop(Stop stop) => _mapController.move(stop.location, 14.5);

  void _openAI() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));
  }

  void _cycleMapHeight() {
    setState(() {
      if (_mapHeight == 240) _mapHeight = 320;
      else if (_mapHeight == 320) _mapHeight = 140;
      else _mapHeight = 240;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ====== CARTE ======
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _mapHeight.toDouble(),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _dakarCenter,
                      initialZoom: 11.5,
                      minZoom: 10,
                      maxZoom: 17,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dakar_bus',
                        maxZoom: 19,
                      ),
                      PolylineLayer(
                        polylines: demoRoutes.map((r) => Polyline(
                          points: r.points, color: r.color, strokeWidth: 3.5,
                        )).toList(),
                      ),
                      MarkerLayer(
                        markers: mapPriorityStops.map((stop) => Marker(
                          point: stop.location,
                          width: 24, height: 24,
                          child: GestureDetector(
                            onTap: () {
                              _centerOnStop(stop);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => StopDetailPage(stop: stop),
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: stop.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
                              ),
                              child: Icon(stop.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        )).toList(),
                      ),
                      // Position utilisateur (uniquement si connue)
                      if (widget.userPosition != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: widget.userPosition!,
                            width: 18, height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)],
                              ),
                            ),
                          ),
                        ]),
                    ],
                  ),

                  // Bouton GPS 3 états
                  Positioned(
                    bottom: 12, left: 12,
                    child: _gpsButton(),
                  ),

                  // Bouton IA
                  Positioned(
                    bottom: 12, right: 12,
                    child: ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Assistant IA', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),

                  // Bouton rétracter carte
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: _cycleMapHeight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _mapHeight == 140 ? Icons.expand_more : Icons.expand_less,
                          color: AppColors.primary, size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Légende
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _legend(AppColors.ter, 'TER'),
                          const SizedBox(width: 6),
                          _legend(AppColors.brt, 'BRT'),
                          const SizedBox(width: 6),
                          _legend(AppColors.aftu, 'AFTU'),
                          const SizedBox(width: 6),
                          _legend(AppColors.tata, 'Tata'),
                          const SizedBox(width: 6),
                          _legend(AppColors.ddd, 'DDD'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ====== CONTENU ======
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dakar Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('TER · BRT · AFTU · Tata · DDD', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recherche
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() => _searchFocused = true),
                      onTap: () => setState(() => _searchFocused = true),
                      decoration: InputDecoration(
                        hintText: 'Où voulez-vous aller ?',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchFocused
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchFocused = false);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  // Suggestions typées
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: _searchResults.map((s) => ListTile(
                          dense: true,
                          leading: Icon(s.icon, color: s.color, size: 20),
                          title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Row(
                            children: [
                              Text(s.direction, style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 6),
                              _categoryChip(s),
                            ],
                          ),
                          onTap: () {
                            _searchCtrl.text = s.name;
                            setState(() => _searchFocused = false);
                            _centerOnStop(s);
                          },
                        )).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Filtres
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip('Tous'),
                        _chip('TER'),
                        _chip('BRT'),
                        _chip('AFTU'),
                        _chip('Tata'),
                        _chip('DDD'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // En-tête "X arrêts"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stops.length} arrêts',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 1),
                        child: Text(
                          'À proximité',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Liste
                  if (stops.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Aucun arrêt à proximité', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    )
                  else
                    ...stops.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _centerOnStop(s),
                        child: StopCard(stop: s, distanceMeters: _distanceTo(s)),
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsButton() {
    switch (widget.gpsState) {
      case GpsState.loading:
        return FloatingActionButton.small(
          onPressed: null,
          backgroundColor: AppColors.surface,
          child: const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        );
      case GpsState.granted:
        return FloatingActionButton.small(
          onPressed: () {
            if (widget.userPosition != null) {
              _mapController.move(widget.userPosition!, 14.5);
            }
          },
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
        );
      default:
        return FloatingActionButton.small(
          onPressed: () => widget.onRequestLocation(),
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.location_searching, color: AppColors.primary, size: 20),
        );
    }
  }

  Widget _categoryChip(Stop s) {
    String label;
    if (s.color == AppColors.ter) label = 'TER';
    else if (s.color == AppColors.brt) label = 'BRT';
    else if (s.color == AppColors.aftu) label = 'AFTU';
    else if (s.color == AppColors.tata) label = 'Tata';
    else if (s.color == AppColors.ddd) label = 'DDD';
    else label = 'Arrêt';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: s.color)),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _chip(String label) {
    final color = _colorFor(label);
    final sel = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color : AppColors.divider, width: sel ? 2 : 1),
          ),
          child: Text(label, style: TextStyle(color: sel ? color : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }

  Color _colorFor(String label) {
    switch (label) {
      case 'TER': return AppColors.ter;
      case 'BRT': return AppColors.brt;
      case 'AFTU': return AppColors.aftu;
      case 'Tata': return AppColors.tata;
      case 'DDD': return AppColors.ddd;
      default: return AppColors.primary;
    }
  }
}

// ============================================================
// CARTE D'ARRÊT
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop;
  final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final next = stop.nextDepartureMinutes();
    final remaining = stop.remainingMinutes();
    final timeLabel = stop.nextDepartureLabel();

    Widget timeWidget;
    if (next == null || remaining == null) {
      timeWidget = const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Horaire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          Text('non disponible', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ],
      );
    } else if (remaining <= 0) {
      timeWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Départ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: stop.color)),
          Text('imminent', style: TextStyle(fontSize: 11, color: stop.color, fontWeight: FontWeight.w600)),
        ],
      );
    } else {
      final isUrgent = remaining <= 3;
      timeWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            TimeHelper.formatRemaining(remaining),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isUrgent ? AppColors.ter : AppColors.success,
            ),
          ),
          Text(
            'd\'attente',
            style: TextStyle(
              fontSize: 9,
              color: isUrgent ? AppColors.ter : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop))),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                child: Icon(stop.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${stop.direction} · ${DistanceHelper.format(distanceMeters)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (next != null && timeLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Départ $timeLabel', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(width: 6),
                          DataStatusBadge(status: stop.status, compact: true),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const DataStatusBadge(status: DataStatus.unknown, compact: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              timeWidget,
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TRAJETS
// ============================================================
class TripsPage extends StatefulWidget {
  final List<FavoriteRoute> favorites;
  const TripsPage({super.key, required this.favorites});
  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final _fromCtrl = TextEditingController(text: 'Ma position');
  final _toCtrl = TextEditingController();
  bool _searched = false;

  void _search() {
    if (_toCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir une destination'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _searched = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Planifier un trajet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.favorites.isNotEmpty) ...[
              const Text('Favoris', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.favorites.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        _toCtrl.text = f.to;
                        _search();
                      },
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(f.icon, color: AppColors.primary, size: 20),
                            const Spacer(),
                            Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(f.to, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _field(Icons.my_location, AppColors.primary, 'Départ', _fromCtrl),
                  const Divider(height: 24),
                  _field(Icons.location_on, AppColors.ter, 'Destination', _toCtrl),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Rechercher', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            if (_searched) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Icon(Icons.construction, size: 40, color: AppColors.warning),
                    const SizedBox(height: 12),
                    const Text(
                      'Moteur d\'itinéraire en préparation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le calcul d\'itinéraires sera disponible dès que les données officielles des opérateurs seront connectées.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const DataStatusBadge(status: DataStatus.unknown),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(IconData icon, Color c, String label, TextEditingController ctrl) {
    return Row(
      children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Saisir...',
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ALERTES
// ============================================================
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final List<Map<String, dynamic>> _alerts = [
    {'stop': 'BRT Colobane', 'icon': Icons.directions_bus_rounded, 'color': AppColors.brt, 'minutes': 5, 'active': true},
    {'stop': 'Gare TER Dakar', 'icon': Icons.train_rounded, 'color': AppColors.ter, 'minutes': 10, 'active': true},
  ];

  void _showAddAlert() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouvelle alerte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...allStops.take(6).map((s) => ListTile(
              leading: Icon(s.icon, color: s.color),
              title: Text(s.name),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _alerts.add({'stop': s.name, 'icon': s.icon, 'color': s.color, 'minutes': 10, 'active': true});
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _showAddAlert,
                  icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${_alerts.where((a) => a['active'] == true).length} alerte(s) active(s)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (_alerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('Aucune alerte', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Ajoutez une alerte pour être prévenu avant le passage.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ..._alerts.asMap().entries.map((entry) {
                final idx = entry.key;
                final a = entry.value;
                final stop = allStops.firstWhere(
                  (s) => s.name == a['stop'],
                  orElse: () => allStops.first,
                );
                final remaining = stop.remainingMinutes();
                final timeLabel = stop.nextDepartureLabel();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (a['color'] as Color).withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), shape: BoxShape.circle),
                          child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['stop'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (remaining != null && timeLabel != null)
                                Text(
                                  'Départ prévu $timeLabel · dans ${TimeHelper.formatRemaining(remaining)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                )
                              else
                                const Text('Horaire non disponible', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              DataStatusBadge(status: stop.status, compact: true),
                            ],
                          ),
                        ),
                        Switch(
                          value: a['active'] as bool,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _alerts[idx]['active'] = v),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Les alertes reposent sur les horaires programmés. Le temps réel sera activé avec les données officielles.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RÉGLAGES
// ============================================================
class SettingsPage extends StatefulWidget {
  final List<FavoriteRoute> favorites;
  final Function(FavoriteRoute) onAdd;
  final Function(int) onRemove;
  const SettingsPage({super.key, required this.favorites, required this.onAdd, required this.onRemove});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _gps = true;

  void _addFavorite() {
    final labelCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau favori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Maison)')),
            TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Destination')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && toCtrl.text.isNotEmpty) {
                widget.onAdd(FavoriteRoute(label: labelCtrl.text, from: 'Ma position', to: toCtrl.text, icon: Icons.star_rounded));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Paramètres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _section('Général'),
            _toggle('Notifications', 'Alertes de passage', Icons.notifications_outlined, _notifications, (v) => setState(() => _notifications = v)),
            _toggle('Localisation', 'Position sur la carte', Icons.location_on_outlined, _gps, (v) => setState(() => _gps = v)),
            const SizedBox(height: 20),
            Row(
              children: [
                _section('Mes favoris'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addFavorite,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (widget.favorites.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Text('Aucun favori. Ajoutez vos trajets fréquents.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              )
            else
              ...widget.favorites.asMap().entries.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(entry.value.icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${entry.value.from} → ${entry.value.to}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => widget.onRemove(entry.key),
                      icon: const Icon(Icons.delete_outline, color: AppColors.ter, size: 20),
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 20),
            _section('Réseaux'),
            _tileSetting('TER', 'Train Express Régional', Icons.train_rounded, AppColors.ter),
            _tileSetting('BRT', 'Bus Rapid Transit', Icons.directions_bus_rounded, AppColors.brt),
            _tileSetting('AFTU', 'Lignes de bus', Icons.directions_bus_outlined, AppColors.aftu),
            _tileSetting('Tata', 'Bus Tata', Icons.directions_bus_filled, AppColors.tata),
            _tileSetting('DDD', 'Dakar Dem Dikk', Icons.directions_bus_filled_rounded, AppColors.ddd),
            const SizedBox(height: 20),
            _section('À propos'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dakar Bus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Version 3.1', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  SizedBox(height: 8),
                  Text('Application d\'information voyageurs pour Dakar.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('Horaires programmés — temps réel en préparation.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
    );
  }

  Widget _toggle(String title, String sub, IconData icon, bool value, Function(bool) onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChange),
        ],
      ),
    );
  }

  Widget _tileSetting(String title, String sub, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}

// ============================================================
// DÉTAIL ARRÊT
// ============================================================
class StopDetailPage extends StatelessWidget {
  final Stop stop;
  const StopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;

    // Filtrer les départs futurs
    final futureDepartures = stop.departureMinutesFromMidnight
        .where((d) => d > currentMin)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(width: 72, height: 72, decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle), child: Icon(stop.icon, color: Colors.white, size: 36)),
                const SizedBox(height: 12),
                Text(stop.direction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('À ${DistanceHelper.format(stop.distanceMeters)} de vous', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Prochains passages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              DataStatusBadge(status: stop.status),
            ],
          ),
          const SizedBox(height: 12),
          if (futureDepartures.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Text('Horaire non disponible pour le moment', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...futureDepartures.map((d) {
              final h = (d ~/ 60).toString().padLeft(2, '0');
              final m = (d % 60).toString().padLeft(2, '0');
              final remaining = d - currentMin;
              final isNext = d == futureDepartures.first;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isNext ? stop.color.withOpacity(0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isNext ? stop.color.withOpacity(0.4) : AppColors.divider,
                    width: isNext ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${h}h$m',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isNext ? stop.color : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      TimeHelper.formatRemaining(remaining),
                      style: TextStyle(
                        color: isNext ? stop.color : AppColors.textSecondary,
                        fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Horaires programmés. Le temps réel sera affiché dès qu\'il sera disponible.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAlertDialog(context, stop),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Me prévenir avant le passage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(BuildContext context, Stop stop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Me prévenir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Délai avant passage :', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [5, 10, 15].map((m) => ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Alerte activée : $m min avant ${stop.name}'), backgroundColor: AppColors.success),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text('$m min'),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Bonjour ! Je suis l\'assistant Dakar Bus.\n\nJe peux vous renseigner sur :\n• les lignes TER, BRT, AFTU, Tata, DDD\n• les arrêts et stations\n• les horaires programmés\n\nJe ne dispose pas encore de données temps réel.'
    },
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _messages.add({'role': 'ai', 'text': _generateResponse(text)});
    });
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  String _normalize(String s) {
    s = s.toLowerCase();
    s = s.replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e');
    s = s.replaceAll('à', 'a').replaceAll('â', 'a');
    s = s.replaceAll('î', 'i').replaceAll('ï', 'i');
    s = s.replaceAll('ô', 'o').replaceAll('ö', 'o');
    s = s.replaceAll('ù', 'u').replaceAll('û', 'u');
    s = s.replaceAll('ç', 'c');
    return s;
  }

  String _generateResponse(String query) {
    final q = _normalize(query);

    for (final stop in allStops) {
      final sn = _normalize(stop.name);
      if (q.contains(sn) || sn.contains(q)) {
        final remaining = stop.remainingMinutes();
        final timeLabel = stop.nextDepartureLabel();
        if (remaining != null && timeLabel != null) {
          return '📍 ${stop.name}\n\nDirection : ${stop.direction}\nDistance : ${DistanceHelper.format(stop.distanceMeters)}\nProchain départ : $timeLabel (${TimeHelper.formatRemaining(remaining)})\n\n🟠 Horaire programmé, pas temps réel.';
        }
        return '📍 ${stop.name}\n\nDirection : ${stop.direction}\n\nHoraire non disponible pour le moment.';
      }
    }

    if (q.contains('diamniadio')) return '🚆 Pour Diamniadio : TER depuis la Gare de Dakar. 13 gares desservies. Environ 40 min.\n\n🟠 Horaire programmé.';
    if (q.contains('plateau')) return '🚌 Pour le Plateau : BRT depuis Colobane (environ 15 min) ou DDD Ligne 7.\n\n🟠 Horaire programmé.';
    if (q.contains('guediawaye')) return '🚌 Pour Guédiawaye : BRT depuis Colobane vers PEM Guédiawaye.\n\n🟠 Horaire programmé.';
    if (q.contains('parcelles')) return '🚌 Pour Parcelles Assainies : AFTU Ligne 23 depuis Colobane.\n\n🟠 Horaire programmé.';
    if (q.contains('ouakam') || q.contains('almadies')) return '🚌 Pour Ouakam / Almadies : DDD Ligne 12.\n\n🟠 Horaire programmé.';
    if (q.contains('rufisque')) return '🚆 Pour Rufisque : TER depuis Dakar, 11ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('thiaroye')) return '🚆 Pour Thiaroye : TER depuis Dakar, 7ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('keur mbaye')) return '🚆 Pour Keur Mbaye Fall : TER depuis Dakar, 9ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('colobane')) return '📍 Colobane est un hub central :\n• Gare TER Colobane\n• Station BRT Colobane\n• Arrêt AFTU Ligne 23';
    if (q.contains('yeumbeul')) return '🚆 Pour Yeumbeul : TER depuis Dakar, 8ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('bargny')) return '🚆 Pour Bargny : TER depuis Dakar, 12ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('hann')) return '🚆 Pour Hann : TER depuis Dakar, 3ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('pikine')) return '🚆 Pour Pikine : TER depuis Dakar, 6ème gare.\n\n🟠 Horaire programmé.';

    if (q.contains('ter') || q.contains('train')) return '🚆 Le TER relie Dakar à Diamniadio via 13 gares.\n\n🟠 Horaire programmé.';
    if (q.contains('brt')) return '🚍 Le BRT compte 23 stations entre Petersen et Guédiawaye.\n\n🟠 Horaire programmé.';
    if (q.contains('aftu')) return '🚌 AFTU dessert Dakar avec plusieurs lignes.\n\n🟠 Horaires estimés.';
    if (q.contains('tata')) return '🚌 Les bus Tata couvrent plusieurs quartiers.\n\n🟠 Horaires estimés.';
    if (q.contains('ddd') || q.contains('dakar dem dikk')) return '🚌 Dakar Dem Dikk : plusieurs lignes à Dakar.\n\n🟠 Horaires estimés.';

    if (q.contains('prix') || q.contains('tarif') || q.contains('fcfa') || q.contains('coute') || q.contains('combien')) {
      return 'Je ne dispose pas d\'informations tarifaires fiables pour le moment.\n\nLes prix ne sont pas affichés dans Dakar Bus.';
    }
    if (q.contains('retard') || q.contains('temps reel') || q.contains('temps réel') || q.contains('live')) {
      return 'Les données temps réel ne sont pas encore connectées à Dakar Bus.\n\nLes horaires affichés sont des horaires programmés. Le statut réel sera bientôt disponible.';
    }
    if (q.contains('perturbation') || q.contains('greve') || q.contains('accident')) {
      return 'Je n\'ai pas de source fiable pour vous informer sur les perturbations en cours.\n\nLes alertes seront disponibles dès que les données officielles seront connectées.';
    }

    if (q.contains('bonjour') || q.contains('salut') || q.contains('bonsoir') || q.contains('hello')) {
      return 'Bonjour ! Comment puis-je vous aider ?';
    }
    if (q.contains('merci')) return 'Avec plaisir !';

    return 'Je n\'ai pas d\'information fiable pour répondre à cette question.\n\nEssayez :\n• « Prochain TER »\n• « Où est Colobane ? »\n• « Comment aller à Diamniadio ? »';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Assistant IA'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isUser ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Posez votre question...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}