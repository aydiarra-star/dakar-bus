import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

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
}

class Stop {
  final String name, direction, price, distance;
  final int minutesUntilArrival;
  final IconData icon;
  final Color color;
  final LatLng location;
  const Stop({
    required this.name,
    required this.direction,
    required this.price,
    required this.distance,
    required this.minutesUntilArrival,
    required this.icon,
    required this.color,
    required this.location,
  });
}

class TransitRoute {
  final String name, code, type;
  final Color color;
  final List<LatLng> points;
  const TransitRoute({
    required this.name,
    required this.code,
    required this.type,
    required this.color,
    required this.points,
  });
}

final List<Stop> baseStops = [
  const Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar', price: '500 FCFA', distance: '350 m', minutesUntilArrival: 2, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407)),
  const Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', price: '500 FCFA', distance: '400 m', minutesUntilArrival: 5, icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441)),
  const Stop(name: 'Station BRT Colobane', direction: 'Dir. Guédiawaye Petersen', price: '400 FCFA', distance: '150 m', minutesUntilArrival: 1, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420)),
  const Stop(name: 'Station BRT Guédiawaye', direction: 'Dir. Petersen', price: '400 FCFA', distance: '2.1 km', minutesUntilArrival: 8, icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977)),
  const Stop(name: 'Arrêt AFTU Ligne 23', direction: 'Dir. Parcelles Assainies', price: '200 FCFA', distance: '280 m', minutesUntilArrival: 3, icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460)),
  const Stop(name: 'Arrêt Tata 12', direction: 'Dir. Guédiawaye', price: '250 FCFA', distance: '600 m', minutesUntilArrival: 4, icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700)),
  const Stop(name: 'Arrêt DDD Ligne 12', direction: 'Dir. Ouakam', price: '300 FCFA', distance: '800 m', minutesUntilArrival: 6, icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900)),
];

final List<TransitRoute> demoRoutes = [
  const TransitRoute(name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter, points: [
    LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7100, -17.4350),
    LatLng(14.7230, -17.4280), LatLng(14.7380, -17.4150), LatLng(14.7500, -17.3980),
    LatLng(14.7650, -17.3800),
  ]),
  const TransitRoute(name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt, points: [
    LatLng(14.7735, -17.3977), LatLng(14.7550, -17.4100), LatLng(14.7350, -17.4250),
    LatLng(14.7150, -17.4350), LatLng(14.6950, -17.4420), LatLng(14.6820, -17.4480),
    LatLng(14.6720, -17.4400),
  ]),
  const TransitRoute(name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu, points: [
    LatLng(14.7600, -17.4400), LatLng(14.7400, -17.4450), LatLng(14.7200, -17.4480),
    LatLng(14.7000, -17.4500), LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400),
  ]),
  const TransitRoute(name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata, points: [
    LatLng(14.7735, -17.3977), LatLng(14.7550, -17.4200), LatLng(14.7300, -17.4500),
    LatLng(14.7100, -17.4700), LatLng(14.6850, -17.4600), LatLng(14.6750, -17.4400),
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
    while (remaining <= 0) {
      remaining += 15;
    }
    final arrivalTime = now.add(Duration(minutes: remaining));
    return '${arrivalTime.hour.toString().padLeft(2, '0')}h${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  static int remainingMinutes(int minutesFromStart, int minuteOffset) {
    int remaining = minutesFromStart - minuteOffset;
    while (remaining <= 0) {
      remaining += 15;
    }
    return remaining;
  }

  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'À l\'arrêt';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }
}

class AnimatedBusPosition {
  static LatLng interpolate(List<LatLng> points, double progress) {
    if (points.isEmpty) return const LatLng(14.7, -17.45);
    if (points.length == 1) return points[0];

    final totalSegments = points.length - 1;
    final scaled = progress * totalSegments;
    final index = scaled.floor().clamp(0, totalSegments - 1);
    final segProgress = scaled - index;

    final start = points[index];
    final end = points[index + 1];

    return LatLng(
      start.latitude + (end.latitude - start.latitude) * segProgress,
      start.longitude + (end.longitude - start.longitude) * segProgress,
    );
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
  double _busProgress = 0.0;
  Timer? _timer;
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update toutes les 2 secondes pour l'animation des bus
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _busProgress = (_busProgress + 0.008) % 1.0;
          // Toutes les 30 sec, incrémenter le compteur des minutes
          if (timer.tick % 15 == 0) {
            _minuteOffset++;
            _lastUpdate = DateTime.now();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(minuteOffset: _minuteOffset, lastUpdate: _lastUpdate, busProgress: _busProgress),
      TripsPage(minuteOffset: _minuteOffset),
      const SettingsPage(),
      AlertsPage(minuteOffset: _minuteOffset),
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
          minimum: const EdgeInsets.only(bottom: 8),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withOpacity(0.15),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Paramètres'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ÉCRAN EXPLORER
// ============================================================
class HomePage extends StatefulWidget {
  final int minuteOffset;
  final DateTime lastUpdate;
  final double busProgress;
  const HomePage({super.key, required this.minuteOffset, required this.lastUpdate, required this.busProgress});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7000, -17.4500);
  final LatLng _simulatedPosition = const LatLng(14.6937, -17.4441);
  String _selectedFilter = 'Tous';

  List<Stop> get _filteredStops {
    switch (_selectedFilter) {
      case 'TER':
        return baseStops.where((s) => s.color == AppColors.ter).toList();
      case 'BRT':
        return baseStops.where((s) => s.color == AppColors.brt).toList();
      case 'AFTU':
        return baseStops.where((s) => s.color == AppColors.aftu).toList();
      case 'Tata':
        return baseStops.where((s) => s.color == AppColors.tata).toList();
      case 'DDD':
        return baseStops.where((s) => s.color == AppColors.ddd).toList();
      default:
        return baseStops;
    }
  }

  void _locateUser() {
    _mapController.move(_simulatedPosition, 15.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 Position centrée sur Colobane'), backgroundColor: AppColors.primary, duration: Duration(seconds: 2)),
    );
  }

  void _openAI() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));
  }

  Widget _busMarker(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.busProgress;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _dakarCenter, initialZoom: 12.5),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus'),
                      PolylineLayer(
                        polylines: demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 4.0)).toList(),
                      ),
                      MarkerLayer(
                        markers: baseStops.map((stop) => Marker(
                          point: stop.location,
                          width: 36, height: 36,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StopDetailPage(stop: stop, minuteOffset: widget.minuteOffset),
                            )),
                            child: Container(
                              decoration: BoxDecoration(
                                color: stop.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
                              ),
                              child: Icon(stop.icon, color: Colors.white, size: 18),
                            ),
                          ),
                        )).toList(),
                      ),
                      // 🚌 BUS ANIMÉS
                      MarkerLayer(
                        markers: [
                          // TER : 1 train
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[0].points, p),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.ter, Icons.train_rounded),
                          ),
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[0].points, (p + 0.5) % 1.0),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.ter, Icons.train_rounded),
                          ),
                          // BRT : 3 bus
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[1].points, p),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.brt, Icons.directions_bus_rounded),
                          ),
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[1].points, (p + 0.33) % 1.0),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.brt, Icons.directions_bus_rounded),
                          ),
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[1].points, (p + 0.66) % 1.0),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.brt, Icons.directions_bus_rounded),
                          ),
                          // AFTU : 2 bus
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[2].points, p),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.aftu, Icons.directions_bus_outlined),
                          ),
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[2].points, (p + 0.5) % 1.0),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.aftu, Icons.directions_bus_outlined),
                          ),
                          // Tata : 2 bus
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[3].points, p),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.tata, Icons.directions_bus_filled),
                          ),
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[3].points, (p + 0.5) % 1.0),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.tata, Icons.directions_bus_filled),
                          ),
                          // DDD : 1 bus
                          Marker(
                            point: AnimatedBusPosition.interpolate(demoRoutes[4].points, p),
                            width: 24, height: 24,
                            child: _busMarker(AppColors.ddd, Icons.directions_bus_filled_rounded),
                          ),
                        ],
                      ),
                      // Position utilisateur
                      MarkerLayer(markers: [
                        Marker(
                          point: _simulatedPosition,
                          width: 22, height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, spreadRadius: 3)],
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                  Positioned(
                    top: 12, left: 12,
                    child: FloatingActionButton.small(
                      onPressed: _locateUser,
                      backgroundColor: AppColors.surface,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Assistant IA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _legend(AppColors.ter, 'TER'),
                          const SizedBox(width: 8),
                          _legend(AppColors.brt, 'BRT'),
                          const SizedBox(width: 8),
                          _legend(AppColors.aftu, 'AFTU'),
                          const SizedBox(width: 8),
                          _legend(AppColors.tata, 'Tata'),
                          const SizedBox(width: 8),
                          _legend(AppColors.ddd, 'DDD'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dakar Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('TER · BRT · AFTU · Tata · DDD', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('Live', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Où voulez-vous aller ?',
                        prefixIcon: Icon(Icons.search, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
                  const SizedBox(height: 20),
                  Text('${_filteredStops.length} arrêts · $_selectedFilter', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ..._filteredStops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StopCard(stop: s, minuteOffset: widget.minuteOffset),
                  )),
                  const SizedBox(height: 20),
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
        Container(width: 12, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
      case 'TER':
        return AppColors.ter;
      case 'BRT':
        return AppColors.brt;
      case 'AFTU':
        return AppColors.aftu;
      case 'Tata':
        return AppColors.tata;
      case 'DDD':
        return AppColors.ddd;
      default:
        return AppColors.primary;
    }
  }
}

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
                    Text('$time · ${stop.direction}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(TimeHelper.formatRemaining(remaining), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: remaining <= 3 ? AppColors.ter : AppColors.success)),
                  Text(stop.price, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
// ÉCRAN TRAJETS
// ============================================================
class TripsPage extends StatefulWidget {
  final int minuteOffset;
  const TripsPage({super.key, required this.minuteOffset});
  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  bool _searched = false;

  void _search() {
    setState(() => _searched = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔍 Recherche de trajets en cours...'), backgroundColor: AppColors.primary),
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
            const Text('Planifier un trajet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _tile(Icons.my_location, AppColors.primary, 'Départ', 'Gare TER Colobane'),
                  const Divider(height: 24),
                  _tile(Icons.location_on, AppColors.ter, 'Arrivée', 'Guédiawaye (BRT)'),
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
              const Text('Itinéraires suggérés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _tripOption('Option la plus rapide', 'BRT Direct (Ligne Express)', '25 min', '500 FCFA', AppColors.brt),
              const SizedBox(height: 10),
              _tripOption('Option économique', 'AFTU Ligne 23', '45 min', '250 FCFA', AppColors.aftu),
              const SizedBox(height: 10),
              _tripOption('Option confort', 'TER + BRT', '32 min', '800 FCFA', AppColors.ter),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, Color c, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _tripOption(String title, String sub, String dur, String price, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 4, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dur, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              Text(price, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ÉCRAN PARAMÈTRES
// ============================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _gps = true;

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
                  Text('Version 1.0.0', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  SizedBox(height: 8),
                  Text('Tous les horaires dans ta poche', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
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
// ÉCRAN ALERTES
// ============================================================
class AlertsPage extends StatelessWidget {
  final int minuteOffset;
  const AlertsPage({super.key, required this.minuteOffset});

  @override
  Widget build(BuildContext context) {
    final alerts = baseStops.take(4).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${alerts.length} alerte(s) active(s)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ...alerts.map((s) {
              final remaining = TimeHelper.remainingMinutes(s.minutesUntilArrival, minuteOffset);
              final time = TimeHelper.nextArrival(s.minutesUntilArrival, DateTime.now(), minuteOffset);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.color.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: s.color.withOpacity(0.12), shape: BoxShape.circle),
                        child: Icon(s.icon, color: s.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Prochain : $time · ${TimeHelper.formatRemaining(remaining)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ÉCRAN DÉTAIL ARRÊT
// ============================================================
class StopDetailPage extends StatefulWidget {
  final Stop stop;
  final int minuteOffset;
  const StopDetailPage({super.key, required this.stop, required this.minuteOffset});

  @override
  State<StopDetailPage> createState() => _StopDetailPageState();
}

class _StopDetailPageState extends State<StopDetailPage> {
  late int _localOffset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _localOffset = widget.minuteOffset;
    _timer = Timer.periodic(const Duration(seconds: 30), (t) {
      if (mounted) setState(() => _localOffset++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final now = DateTime.now();
    final r1 = TimeHelper.remainingMinutes(stop.minutesUntilArrival, _localOffset);
    final r2 = r1 + 15;
    final r3 = r1 + 30;
    final t1 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, _localOffset);
    final t2 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, _localOffset - 15);
    final t3 = TimeHelper.nextArrival(stop.minutesUntilArrival, now, _localOffset - 30);

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
              Text(stop.price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(width: 8),
              const Text('par passage', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prochains passages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync, size: 12, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(t1, TimeHelper.formatRemaining(r1), r1 <= 3),
          _row(t2, TimeHelper.formatRemaining(r2), false),
          _row(t3, TimeHelper.formatRemaining(r3), false),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAlertDialog(context, stop),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Me prévenir 10 min avant'),
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
        title: const Text('Activer l\'alerte ?'),
        content: Text('Vous serez prévenu 10 min avant le passage à ${stop.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🔔 Alerte activée pour ${stop.name}'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Activer'),
          ),
        ],
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
    {'role': 'ai', 'text': 'Bonjour ! Je suis votre assistant Dakar Bus. Posez-moi une question : destination, arrêt, ligne TER, BRT, AFTU, Tata ou DDD.'},
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
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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

    for (final stop in baseStops) {
      final stopName = _normalize(stop.name);
      if (q.contains(stopName) || stopName.contains(q)) {
        final r = TimeHelper.remainingMinutes(stop.minutesUntilArrival, 0);
        final t = TimeHelper.nextArrival(stop.minutesUntilArrival, now, 0);
        return '📍 ${stop.name}\nDirection : ${stop.direction}\nProchain passage : $t (dans ${TimeHelper.formatRemaining(r)})\nTarif : ${stop.price}\nDistance : ${stop.distance}';
      }
    }

    if (q.contains('diamniadio')) return '🚆 Pour Diamniadio : TER depuis la Gare de Dakar. 13 gares, terminus Diamniadio. ~40 min. Tarif jusqu\'à 800 FCFA.';
    if (q.contains('plateau')) return '🚌 Pour le Plateau : BRT depuis Colobane (~15 min, 400 FCFA) ou DDD Ligne 7 (~20 min, 300 FCFA).';
    if (q.contains('guediawaye')) return '🚌 Pour Guédiawaye : BRT depuis Colobane (PEM Guédiawaye). ~20 min. Tarif 400 FCFA.';
    if (q.contains('parcelles')) return '🚌 Pour Parcelles Assainies : AFTU Ligne 23 depuis Colobane. 3 min d\'attente. Tarif 200 FCFA.';
    if (q.contains('ouakam') || q.contains('almadies')) return '🚌 Pour Ouakam / Almadies : DDD Ligne 12. 6 min d\'attente. Tarif 300 FCFA.';
    if (q.contains('petersen')) return '🚌 Petersen est desservi par le BRT Ligne B1 (terminus sud). Tarif 400 FCFA.';
    if (q.contains('rufisque')) return '🚆 Pour Rufisque : TER depuis Dakar (11ème gare). Tarif ~700 FCFA.';
    if (q.contains('thiaroye')) return '🚆 Thiaroye est la 7ème gare du TER depuis Dakar. Tarif ~500 FCFA.';
    if (q.contains('keur mbaye') || q.contains('keurmbaye')) return '🚆 Keur Mbaye Fall est la 9ème gare du TER depuis Dakar, direction Diamniadio. Tarif ~600 FCFA.';
    if (q.contains('colobane')) return '📍 Colobane : hub central avec TER + BRT + bus AFTU. Connexion facile vers tous les quartiers.';
    if (q.contains('yeumbeul')) return '🚆 Yeumbeul est la 8ème gare du TER. Direction Diamniadio. Tarif ~600 FCFA.';
    if (q.contains('bargny')) return '🚆 Bargny est la 12ème gare du TER, avant Diamniadio. Tarif ~700 FCFA.';
    if (q.contains('hann')) return '🚆 Hann est la 3ème gare du TER depuis Dakar. Tarif 500 FCFA.';
    if (q.contains('pikine')) return '🚆 Pikine est la 6ème gare du TER depuis Dakar. Tarif 500 FCFA.';

    if (q.contains('ter') || q.contains('train')) return '🚆 Le TER relie Dakar à Diamniadio via 13 gares. Prochain départ de Dakar dans 2 min.';
    if (q.contains('brt')) return '🚍 Le BRT compte 23 stations de Petersen à Guédiawaye. Prochain BRT à Colobane dans 1 min. Tarif 400 FCFA.';
    if (q.contains('aftu')) return '🚌 AFTU couvre Dakar. Ligne 23 vers Parcelles Assainies dans 3 min. Tarif 200 FCFA.';
    if (q.contains('tata')) return '🚌 Les bus Tata desservent plusieurs quartiers. Tata 12 vers Guédiawaye dans 4 min. Tarif 250 FCFA.';
    if (q.contains('ddd') || q.contains('dakar dem dikk')) return '🚌 DDD : Ligne 12 vers Ouakam dans 6 min. Tarif 300 FCFA.';

    if (q.contains('bonjour') || q.contains('salut') || q.contains('bonsoir') || q.contains('hello')) {
      return 'Bonjour ! Je peux vous aider à trouver un trajet, une ligne ou un arrêt. Que cherchez-vous ?';
    }
    if (q.contains('merci')) return 'Avec plaisir ! Autre chose ?';
    if (q.contains('aide') || q.contains('help')) {
      return 'Je comprends : destinations, lignes (TER, BRT, AFTU, Tata, DDD), arrêts, tarifs et horaires. Exemples : « Je veux aller à Diamniadio », « Prochain BRT », « Où est Colobane ? »';
    }

    final words = q.split(' ').where((w) => w.length > 3).toList();
    for (final word in words) {
      for (final stop in baseStops) {
        if (_normalize(stop.name).contains(word)) {
          final r = TimeHelper.remainingMinutes(stop.minutesUntilArrival, 0);
          final t = TimeHelper.nextArrival(stop.minutesUntilArrival, now, 0);
          return '📍 ${stop.name}\n${stop.direction}\nProchain : $t (dans ${TimeHelper.formatRemaining(r)}) · ${stop.price}';
        }
      }
    }

    return 'Je n\'ai pas trouvé d\'information précise. Essayez : « Je veux aller à Diamniadio », « Prochain BRT », « Gare TER Colobane », « Plateau », « Guédiawaye ».';
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
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isUser ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(fontSize: 14)),
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