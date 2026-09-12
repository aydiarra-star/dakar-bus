import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

// ============================================================
// COULEURS
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
  static const warning = Color(0xFFF57C00);
  static const neutral = Color(0xFF9E9E9E);
}

// ============================================================
// STATUT DE FIABILITÉ DES DONNÉES
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
    IconData icon;

    switch (status) {
      case DataStatus.live:
        color = AppColors.success;
        label = 'Live';
        icon = Icons.circle;
        break;
      case DataStatus.scheduled:
        color = AppColors.warning;
        label = 'Programmé';
        icon = Icons.schedule;
        break;
      case DataStatus.unknown:
        color = AppColors.neutral;
        label = 'Non disponible';
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon == Icons.circle
              ? Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
              : Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.bold,
              color: color,
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
  final String distance;
  final int minutesUntilArrival;
  final IconData icon;
  final Color color;
  final LatLng location;
  final DataStatus status;

  const Stop({
    required this.name,
    required this.direction,
    required this.distance,
    required this.minutesUntilArrival,
    required this.icon,
    required this.color,
    required this.location,
    this.status = DataStatus.scheduled,
  });
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
// DONNÉES (aucun prix)
// ============================================================
final List<Stop> terStations = [
  const Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar', distance: '350 m', minutesUntilArrival: 2, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407)),
  const Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distance: '1.2 km', minutesUntilArrival: 4, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441)),
  const Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distance: '3.5 km', minutesUntilArrival: 6, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7222, -17.4321)),
  const Stop(name: 'Gare TER Dalifort', direction: 'Dir. Diamniadio', distance: '5.1 km', minutesUntilArrival: 8, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7410, -17.4120)),
  const Stop(name: 'Gare TER Baux Maraîchers', direction: 'Dir. Diamniadio', distance: '6.3 km', minutesUntilArrival: 10, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7470, -17.4010)),
  const Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distance: '7.2 km', minutesUntilArrival: 12, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7550, -17.3900)),
  const Stop(name: 'Gare TER Thiaroye', direction: 'Dir. Diamniadio', distance: '8.1 km', minutesUntilArrival: 14, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7588, -17.3803)),
  const Stop(name: 'Gare TER Yeumbeul', direction: 'Dir. Diamniadio', distance: '11.5 km', minutesUntilArrival: 16, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7700, -17.3400)),
  const Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Diamniadio', distance: '14.2 km', minutesUntilArrival: 18, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7750, -17.3100)),
  const Stop(name: 'Gare TER PNR', direction: 'Dir. Diamniadio', distance: '16.8 km', minutesUntilArrival: 20, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7500, -17.2900)),
  const Stop(name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio', distance: '22.1 km', minutesUntilArrival: 24, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7157, -17.2703)),
  const Stop(name: 'Gare TER Bargny', direction: 'Dir. Diamniadio', distance: '28.5 km', minutesUntilArrival: 28, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6900, -17.2200)),
  const Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', distance: '35.0 km', minutesUntilArrival: 32, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7160, -17.1986)),
];

final List<Stop> otherStations = [
  const Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distance: '200 m', minutesUntilArrival: 1, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6720, -17.4400)),
  const Stop(name: 'BRT Colobane', direction: 'Dir. Guédiawaye', distance: '150 m', minutesUntilArrival: 1, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420)),
  const Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guédiawaye', distance: '1.5 km', minutesUntilArrival: 3, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7050, -17.4400)),
  const Stop(name: 'BRT Liberté 6', direction: 'Dir. Guédiawaye', distance: '3.4 km', minutesUntilArrival: 7, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7220, -17.4330)),
  const Stop(name: 'BRT Sacré-Cœur', direction: 'Dir. Guédiawaye', distance: '4.0 km', minutesUntilArrival: 8, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7280, -17.4300)),
  const Stop(name: 'BRT Parcelles', direction: 'Dir. Guédiawaye', distance: '5.0 km', minutesUntilArrival: 10, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7350, -17.4260)),
  const Stop(name: 'BRT Grand Médine', direction: 'Dir. Guédiawaye', distance: '6.2 km', minutesUntilArrival: 12, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7450, -17.4180)),
  const Stop(name: 'BRT Scat Urbam', direction: 'Dir. Guédiawaye', distance: '7.5 km', minutesUntilArrival: 14, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7520, -17.4100)),
  const Stop(name: 'PEM Guédiawaye', direction: 'Terminus nord BRT', distance: '10.5 km', minutesUntilArrival: 20, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977)),
  const Stop(name: 'Arrêt AFTU 23', direction: 'Dir. Parcelles Assainies', distance: '280 m', minutesUntilArrival: 3, icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460)),
  const Stop(name: 'Arrêt AFTU 10', direction: 'Dir. Grand Yoff', distance: '450 m', minutesUntilArrival: 5, icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.7200, -17.4600)),
  const Stop(name: 'Arrêt Tata 12', direction: 'Dir. Guédiawaye', distance: '600 m', minutesUntilArrival: 4, icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700)),
  const Stop(name: 'Arrêt Tata 8', direction: 'Dir. Pikine', distance: '900 m', minutesUntilArrival: 6, icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7500, -17.4200)),
  const Stop(name: 'Arrêt DDD 12', direction: 'Dir. Ouakam', distance: '800 m', minutesUntilArrival: 6, icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900)),
  const Stop(name: 'Arrêt DDD 7', direction: 'Dir. Plateau', distance: '1.2 km', minutesUntilArrival: 8, icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7350, -17.4500)),
];

final List<Stop> allStops = [...terStations, ...otherStations];

final List<Stop> mapPriorityStops = [
  terStations[0], terStations[1], terStations[5], terStations[10], terStations[12],
  otherStations[1], otherStations[8], otherStations[13],
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
// UTILITAIRES
// ============================================================
class TimeHelper {
  static String nextArrival(int minutesFromStart, DateTime now, int minuteOffset) {
    int remaining = minutesFromStart - minuteOffset;
    while (remaining <= 0) { remaining += 15; }
    final arrivalTime = now.add(Duration(minutes: remaining));
    return '${arrivalTime.hour.toString().padLeft(2, '0')}h${arrivalTime.minute.toString().padLeft(2, '0')}';
  }
  static int remainingMinutes(int minutesFromStart, int minuteOffset) {
    int remaining = minutesFromStart - minuteOffset;
    while (remaining <= 0) { remaining += 15; }
    return remaining;
  }
  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'À l\'arrêt';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }
}

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
  int _minuteOffset = 0;
  Timer? _timer;
  List<FavoriteRoute> _favorites = [
    const FavoriteRoute(label: 'Maison', from: 'Ma position', to: 'Plateau', icon: Icons.home_rounded),
    const FavoriteRoute(label: 'Travail', from: 'Ma position', to: 'Parcelles Assainies', icon: Icons.work_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Simple incrémentation des minutes toutes les 30 sec pour les horaires programmés
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() => _minuteOffset++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _addFavorite(FavoriteRoute fav) {
    setState(() => _favorites.add(fav));
  }

  void _removeFavorite(int index) {
    setState(() => _favorites.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(minuteOffset: _minuteOffset),
      TripsPage(minuteOffset: _minuteOffset, favorites: _favorites),
      AlertsPage(minuteOffset: _minuteOffset),
      SettingsPage(favorites: _favorites, onAdd: _addFavorite, onRemove: _removeFavorite),
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

// ============================================================
// EXPLORER : CARTE + RECHERCHE + ARRÊTS
// ============================================================
class ExplorerPage extends StatefulWidget {
  final int minuteOffset;
  const ExplorerPage({super.key, required this.minuteOffset});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  final LatLng _simulatedPosition = const LatLng(14.6937, -17.4441);
  String _selectedFilter = 'Tous';
  int _mapHeight = 240;
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Stop> get _filteredStops {
    switch (_selectedFilter) {
      case 'TER': return allStops.where((s) => s.color == AppColors.ter).toList();
      case 'BRT': return allStops.where((s) => s.color == AppColors.brt).toList();
      case 'AFTU': return allStops.where((s) => s.color == AppColors.aftu).toList();
      case 'Tata': return allStops.where((s) => s.color == AppColors.tata).toList();
      case 'DDD': return allStops.where((s) => s.color == AppColors.ddd).toList();
      default: return allStops;
    }
  }

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.direction.toLowerCase().contains(q)
    ).take(6).toList();
  }

  void _centerOnStop(Stop stop) {
    _mapController.move(stop.location, 14.5);
  }

  void _locateUser() {
    _mapController.move(_simulatedPosition, 14.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Position centrée'), backgroundColor: AppColors.primary, duration: Duration(seconds: 2)),
    );
  }

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ====== CARTE RÉTRACTABLE ======
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
                                builder: (_) => StopDetailPage(stop: stop, minuteOffset: widget.minuteOffset),
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
                      MarkerLayer(markers: [
                        Marker(
                          point: _simulatedPosition,
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
                  // Bouton GPS
                  Positioned(
                    bottom: 12, left: 12,
                    child: FloatingActionButton.small(
                      onPressed: _locateUser,
                      backgroundColor: AppColors.surface,
                      child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                    ),
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
                  // Bouton rétracter
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
                          color: AppColors.primary,
                          size: 20,
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
                  // En-tête
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
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
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
                  // Suggestions
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: _searchResults.map((s) => ListTile(
                          dense: true,
                          leading: Icon(s.icon, color: s.color, size: 20),
                          title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(s.direction, style: const TextStyle(fontSize: 11)),
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
                  Row(
                    children: [
                      Text('${_filteredStops.length} arrêts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      Text('· $_selectedFilter', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const Spacer(),
                      const DataStatusBadge(status: DataStatus.scheduled, compact: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._filteredStops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _centerOnStop(s),
                      child: StopCard(stop: s, minuteOffset: widget.minuteOffset),
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
// CARTE D'ARRÊT (sans prix)
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop;
  final int minuteOffset;
  const StopCard({super.key, required this.stop, required this.minuteOffset});

  @override
  Widget build(BuildContext context) {
    final remaining = TimeHelper.remainingMinutes(stop.minutesUntilArrival, minuteOffset);
    final time = TimeHelper.nextArrival(stop.minutesUntilArrival, DateTime.now(), minuteOffset);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop, minuteOffset: minuteOffset))),
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
                    Text('${stop.direction} · ${stop.distance}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Départ $time', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(width: 6),
                        const DataStatusBadge(status: DataStatus.scheduled, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TimeHelper.formatRemaining(remaining),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: remaining <= 3 ? AppColors.ter : AppColors.success),
                  ),
                  const SizedBox(height: 2),
                  const Text('attente', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
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
  final int minuteOffset;
  final List<FavoriteRoute> favorites;
  const TripsPage({super.key, required this.minuteOffset, required this.favorites});
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
            // Favoris
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
            // Recherche
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
              Row(
                children: [
                  const Text('Itinéraires suggérés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const DataStatusBadge(status: DataStatus.scheduled, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              _tripOption('Meilleur choix', 'BRT Direct', '18 min', AppColors.brt, true),
              const SizedBox(height: 10),
              _tripOption('TER + marche', 'Train Express Régional', '24 min', AppColors.ter, false),
              const SizedBox(height: 10),
              _tripOption('AFTU Ligne 23', 'Bus direct', '31 min', AppColors.aftu, false),
              const SizedBox(height: 10),
              _tripOption('DDD Ligne 7', 'Dakar Dem Dikk', '35 min', AppColors.ddd, false),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Temps de trajet estimés à partir d\'horaires programmés. Non temps réel.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
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

  Widget _tripOption(String title, String sub, String duration, Color color, bool isBest) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isBest ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Row(
        children: [
          Container(width: 4, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isBest) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Meilleur', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(duration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ============================================================
// ALERTES
// ============================================================
class AlertsPage extends StatefulWidget {
  final int minuteOffset;
  const AlertsPage({super.key, required this.minuteOffset});
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
                final remaining = TimeHelper.remainingMinutes(10, widget.minuteOffset);
                final time = TimeHelper.nextArrival(10, DateTime.now(), widget.minuteOffset);
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
                              Text(
                                'Départ prévu : $time · ${TimeHelper.formatRemaining(remaining)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              const DataStatusBadge(status: DataStatus.scheduled, compact: true),
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
                  Text('Version 3.0', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
  final int minuteOffset;
  const StopDetailPage({super.key, required this.stop, required this.minuteOffset});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final r1 = TimeHelper.remainingMinutes(stop.minutesUntilArrival, minuteOffset);
    final r2 = r1 + 15;
    final r3 = r1 + 30;
    final t1 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, minuteOffset);
    final t2 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, minuteOffset - 15);
    final t3 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, minuteOffset - 30);

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
                Text('À ${stop.distance} de vous', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Prochains passages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              const DataStatusBadge(status: DataStatus.scheduled),
            ],
          ),
          const SizedBox(height: 12),
          _row(t1, TimeHelper.formatRemaining(r1), r1 <= 3),
          _row(t2, TimeHelper.formatRemaining(r2), false),
          _row(t3, TimeHelper.formatRemaining(r3), false),
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
                    'Horaires programmés. Les données temps réel seront affichées dès qu\'elles seront disponibles.',
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

  Widget _row(String time, String count, bool highlight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.ter.withOpacity(0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? AppColors.ter.withOpacity(0.4) : AppColors.divider, width: highlight ? 1.5 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: highlight ? AppColors.ter : AppColors.textPrimary)),
          Text(count, style: TextStyle(color: highlight ? AppColors.ter : AppColors.textSecondary, fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA (ne ment jamais)
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
      'text': 'Bonjour ! Je suis l\'assistant Dakar Bus.\n\nJe peux vous renseigner sur :\n• les lignes TER, BRT, AFTU, Tata, DDD\n• les arrêts et stations\n• les horaires programmés\n• la préparation d\'un trajet\n\nJe ne dispose pas encore de données temps réel.'
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
    final now = DateTime.now();

    // Recherche d'un arrêt
    for (final stop in allStops) {
      final sn = _normalize(stop.name);
      if (q.contains(sn) || sn.contains(q)) {
        final r = TimeHelper.remainingMinutes(stop.minutesUntilArrival, 0);
        final t = TimeHelper.nextArrival(stop.minutesUntilArrival, now, 0);
        return '📍 ${stop.name}\n\nDirection : ${stop.direction}\nDistance : ${stop.distance}\nProchain passage : $t (dans ${TimeHelper.formatRemaining(r)})\n\n⚠️ Horaire programmé, pas temps réel.';
      }
    }

    // Destinations connues
    if (q.contains('diamniadio')) return '🚆 Pour Diamniadio : prenez le TER depuis la Gare de Dakar. 13 gares desservies. Environ 40 min de trajet.\n\n⚠️ Horaire programmé.';
    if (q.contains('plateau')) return '🚌 Pour le Plateau : BRT depuis Colobane (environ 15 min) ou DDD Ligne 7.\n\n⚠️ Horaire programmé.';
    if (q.contains('guediawaye') || q.contains('guediawaye')) return '🚌 Pour Guédiawaye : BRT depuis Colobane vers PEM Guédiawaye. Environ 20 min.\n\n⚠️ Horaire programmé.';
    if (q.contains('parcelles')) return '🚌 Pour Parcelles Assainies : AFTU Ligne 23 depuis Colobane. Environ 20 min.\n\n⚠️ Horaire programmé.';
    if (q.contains('ouakam') || q.contains('almadies')) return '🚌 Pour Ouakam / Almadies : DDD Ligne 12.\n\n⚠️ Horaire programmé.';
    if (q.contains('rufisque')) return '🚆 Pour Rufisque : TER depuis Dakar, 11ème gare. Environ 30 min.\n\n⚠️ Horaire programmé.';
    if (q.contains('thiaroye')) return '🚆 Pour Thiaroye : TER depuis Dakar, 7ème gare.\n\n⚠️ Horaire programmé.';
    if (q.contains('keur mbaye')) return '🚆 Pour Keur Mbaye Fall : TER depuis Dakar, 9ème gare.\n\n⚠️ Horaire programmé.';
    if (q.contains('colobane')) return '📍 Colobane est un hub central :\n• Gare TER Colobane\n• Station BRT Colobane\n• Arrêt AFTU Ligne 23\n\nConnexions faciles vers tous les quartiers.';
    if (q.contains('yeumbeul')) return '🚆 Pour Yeumbeul : TER depuis Dakar, 8ème gare.\n\n⚠️ Horaire programmé.';
    if (q.contains('bargny')) return '🚆 Pour Bargny : TER depuis Dakar, 12ème gare.\n\n⚠️ Horaire programmé.';
    if (q.contains('hann')) return '🚆 Pour Hann : TER depuis Dakar, 3ème gare.\n\n⚠️ Horaire programmé.';
    if (q.contains('pikine')) return '🚆 Pour Pikine : TER depuis Dakar, 6ème gare.\n\n⚠️ Horaire programmé.';

    // Lignes
    if (q.contains('ter') || q.contains('train')) return '🚆 Le TER relie Dakar à Diamniadio via 13 gares.\n\nProchain départ depuis Gare de Dakar dans ${TimeHelper.formatRemaining(TimeHelper.remainingMinutes(2, 0))}.\n\n⚠️ Horaire programmé, pas temps réel.';
    if (q.contains('brt')) return '🚍 Le BRT compte 23 stations entre Petersen et Guédiawaye.\n\nProchain passage BRT Colobane dans ${TimeHelper.formatRemaining(TimeHelper.remainingMinutes(1, 0))}.\n\n⚠️ Horaire programmé.';
    if (q.contains('aftu')) return '🚌 AFTU dessert Dakar avec plusieurs lignes. Ligne 23 vers Parcelles Assainies.\n\n⚠️ Horaires estimés.';
    if (q.contains('tata')) return '🚌 Les bus Tata couvrent plusieurs quartiers. Tata 12 vers Guédiawaye.\n\n⚠️ Horaires estimés.';
    if (q.contains('ddd') || q.contains('dakar dem dikk')) return '🚌 Dakar Dem Dikk : Ligne 12 vers Ouakam.\n\n⚠️ Horaires estimés.';

    // Questions hors scope
    if (q.contains('prix') || q.contains('tarif') || q.contains('fcfa') || q.contains('coute') || q.contains('combien')) {
      return 'Je ne dispose pas d\'informations tarifaires fiables pour le moment. Les prix des transports ne sont pas affichés dans Dakar Bus.\n\nPour les tarifs, renseignez-vous directement auprès des opérateurs.';
    }
    if (q.contains('retard') || q.contains('temps reel') || q.contains('temps réel')) {
      return 'Les données temps réel ne sont pas encore connectées à Dakar Bus.\n\nLes horaires affichés sont des horaires programmés. Le statut réel sera bientôt disponible grâce à un partenariat avec les opérateurs.';
    }
    if (q.contains('perturbation') || q.contains('greve') || q.contains('accident')) {
      return 'Je n\'ai pas de source fiable pour vous informer sur les perturbations en cours.\n\nLes alertes de perturbation seront disponibles dès que les données officielles seront connectées.';
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