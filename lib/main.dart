import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const DakarBusApp());

// ============================================================
// COULEURS OFFICIELLES DES LIGNES
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  // Couleurs officielles demandées
  static const ter = Color(0xFF8D6E63);       // Marron/gris-orange TER
  static const brt = Color(0xFF2E7D32);       // Vert BRT
  static const ddd = Color(0xFF1565C0);       // Bleu DDD
  static const aftu = Color(0xFF9E9E9E);      // Gris AFTU
  static const tata = Color(0xFFBDBDBD);      // Gris clair Tata
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8F9FA);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFEEEEEE);
  static const success = Color(0xFF2E7D32);
}

// ============================================================
// MODÈLES
// ============================================================
class Stop {
  final String name, direction, schedule, price, distance;
  final IconData icon;
  final Color color;
  final LatLng location;
  const Stop({
    required this.name, required this.direction, required this.schedule,
    required this.price, required this.distance, required this.icon,
    required this.color, required this.location,
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

// ============================================================
// 13 GARES DU TER (Dakar → Diamniadio)
// ============================================================
final List<Stop> terStations = [
  const Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar', schedule: '2 min', price: '500 FCFA', distance: '350 m', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407)),
  const Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', schedule: '4 min', price: '500 FCFA', distance: '1.2 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441)),
  const Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', schedule: '6 min', price: '500 FCFA', distance: '3.5 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7222, -17.4321)),
  const Stop(name: 'Gare TER Dalifort', direction: 'Dir. Diamniadio', schedule: '8 min', price: '500 FCFA', distance: '5.1 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7410, -17.4120)),
  const Stop(name: 'Gare TER Baux Maraîchers', direction: 'Dir. Diamniadio', schedule: '10 min', price: '500 FCFA', distance: '6.3 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7470, -17.4010)),
  const Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', schedule: '12 min', price: '500 FCFA', distance: '7.2 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7550, -17.3900)),
  const Stop(name: 'Gare TER Thiaroye', direction: 'Dir. Diamniadio', schedule: '14 min', price: '500 FCFA', distance: '8.1 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7588, -17.3803)),
  const Stop(name: 'Gare TER Yeumbeul', direction: 'Dir. Diamniadio', schedule: '16 min', price: '600 FCFA', distance: '11.5 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7700, -17.3400)),
  const Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Diamniadio', schedule: '18 min', price: '600 FCFA', distance: '14.2 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7750, -17.3100)),
  const Stop(name: 'Gare TER PNR', direction: 'Dir. Diamniadio', schedule: '20 min', price: '600 FCFA', distance: '16.8 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7500, -17.2900)),
  const Stop(name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio', schedule: '24 min', price: '700 FCFA', distance: '22.1 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7157, -17.2703)),
  const Stop(name: 'Gare TER Bargny', direction: 'Dir. Diamniadio', schedule: '28 min', price: '700 FCFA', distance: '28.5 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6900, -17.2200)),
  const Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', schedule: '32 min', price: '800 FCFA', distance: '35.0 km', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7160, -17.1986)),
];

// ============================================================
// 23 STATIONS DU BRT (Petersen ↔ Guédiawaye)
// ============================================================
final List<Stop> brtStations = [
  const Stop(name: 'PEM Petersen', direction: 'Terminus Petersen', schedule: '1 min', price: '400 FCFA', distance: '200 m', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6720, -17.4400)),
  const Stop(name: 'Place de la Nation', direction: 'Dir. Guédiawaye', schedule: '2 min', price: '400 FCFA', distance: '400 m', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6800, -17.4380)),
  const Stop(name: 'Gueule Tapée', direction: 'Dir. Guédiawaye', schedule: '3 min', price: '400 FCFA', distance: '700 m', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6850, -17.4400)),
  const Stop(name: 'Grande Mosquée', direction: 'Dir. Guédiawaye', schedule: '4 min', price: '400 FCFA', distance: '1.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6880, -17.4420)),
  const Stop(name: 'BRT Colobane', direction: 'Dir. Guédiawaye', schedule: '1 min', price: '400 FCFA', distance: '150 m', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420)),
  const Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guédiawaye', schedule: '3 min', price: '400 FCFA', distance: '1.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7050, -17.4400)),
  const Stop(name: 'BRT Liberté 1', direction: 'Dir. Guédiawaye', schedule: '5 min', price: '400 FCFA', distance: '2.3 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7120, -17.4380)),
  const Stop(name: 'BRT Liberté 5', direction: 'Dir. Guédiawaye', schedule: '6 min', price: '400 FCFA', distance: '2.9 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7180, -17.4350)),
  const Stop(name: 'BRT Liberté 6', direction: 'Dir. Guédiawaye', schedule: '7 min', price: '400 FCFA', distance: '3.4 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7220, -17.4330)),
  const Stop(name: 'BRT Sacré-Cœur', direction: 'Dir. Guédiawaye', schedule: '8 min', price: '400 FCFA', distance: '4.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7280, -17.4300)),
  const Stop(name: 'Police des Parcelles', direction: 'Dir. Guédiawaye', schedule: '9 min', price: '400 FCFA', distance: '4.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7320, -17.4280)),
  const Stop(name: 'BRT Parcelles', direction: 'Dir. Guédiawaye', schedule: '10 min', price: '400 FCFA', distance: '5.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7350, -17.4260)),
  const Stop(name: 'BRT Grand Médine', direction: 'Dir. Guédiawaye', schedule: '12 min', price: '400 FCFA', distance: '6.2 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7450, -17.4180)),
  const Stop(name: 'PEM Grand Médine', direction: 'Dir. Guédiawaye', schedule: '13 min', price: '400 FCFA', distance: '6.8 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7480, -17.4150)),
  const Stop(name: 'Scat Urbam', direction: 'Dir. Guédiawaye', schedule: '14 min', price: '400 FCFA', distance: '7.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7520, -17.4100)),
  const Stop(name: 'Card. Hy. Thiandoum', direction: 'Dir. Guédiawaye', schedule: '15 min', price: '400 FCFA', distance: '8.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7550, -17.4080)),
  const Stop(name: 'BRT Golf Sud', direction: 'Dir. Guédiawaye', schedule: '16 min', price: '400 FCFA', distance: '8.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7580, -17.4050)),
  const Stop(name: 'BRT Golf Nord', direction: 'Dir. Guédiawaye', schedule: '17 min', price: '400 FCFA', distance: '9.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7620, -17.4020)),
  const Stop(name: 'BRT Ndingala', direction: 'Dir. Guédiawaye', schedule: '18 min', price: '400 FCFA', distance: '9.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7660, -17.4000)),
  const Stop(name: 'Préf. Guédiawaye', direction: 'Dir. Guédiawaye', schedule: '19 min', price: '400 FCFA', distance: '10.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7700, -17.3980)),
  const Stop(name: 'PEM Guédiawaye', direction: 'Terminus Guédiawaye', schedule: '20 min', price: '400 FCFA', distance: '10.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977)),
  const Stop(name: 'BRT Khar Yallah', direction: 'Dir. Guédiawaye', schedule: '21 min', price: '400 FCFA', distance: '11.0 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7750, -17.3960)),
  const Stop(name: 'BRT Gadaye', direction: 'Terminus Gadaye', schedule: '22 min', price: '400 FCFA', distance: '11.5 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7780, -17.3940)),
];

// ============================================================
// ARRÊTS AFTU / TATA / DDD
// ============================================================
final List<Stop> otherStops = [
  const Stop(name: 'AFTU Ligne 23', direction: 'Dir. Parcelles Assainies', schedule: '3 min', price: '200 FCFA', distance: '280 m', icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460)),
  const Stop(name: 'AFTU Ligne 10', direction: 'Dir. Grand Yoff', schedule: '5 min', price: '200 FCFA', distance: '450 m', icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.7200, -17.4600)),
  const Stop(name: 'Tata 12', direction: 'Dir. Guédiawaye', schedule: '4 min', price: '250 FCFA', distance: '600 m', icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700)),
  const Stop(name: 'Tata 8', direction: 'Dir. Pikine', schedule: '6 min', price: '250 FCFA', distance: '900 m', icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7500, -17.4200)),
  const Stop(name: 'DDD Ligne 12', direction: 'Dir. Ouakam / Almadies', schedule: '6 min', price: '300 FCFA', distance: '800 m', icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900)),
  const Stop(name: 'DDD Ligne 7', direction: 'Dir. Plateau', schedule: '8 min', price: '300 FCFA', distance: '1.2 km', icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7350, -17.4500)),
];

// Tous les arrêts combinés
final List<Stop> allStops = [...terStations, ...brtStations, ...otherStops];

// ============================================================
// TRACÉS DES LIGNES (Polylines)
// ============================================================
final List<TransitRoute> demoRoutes = [
  // TER : Dakar → Diamniadio (tracé des gares)
  TransitRoute(
    name: 'TER Ligne Express',
    code: 'TER',
    type: 'TER',
    color: AppColors.ter,
    points: terStations.map((s) => s.location).toList(),
  ),
  // BRT : Petersen → Guédiawaye
  TransitRoute(
    name: 'BRT Ligne B1',
    code: 'B1',
    type: 'BRT',
    color: AppColors.brt,
    points: brtStations.map((s) => s.location).toList(),
  ),
  // AFTU : Ligne 23 (Nord → Sud)
  const TransitRoute(
    name: 'AFTU Ligne 23',
    code: '23',
    type: 'AFTU',
    color: AppColors.aftu,
    points: [
      LatLng(14.7600, -17.4400), LatLng(14.7400, -17.4450),
      LatLng(14.7200, -17.4480), LatLng(14.7000, -17.4500),
      LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400),
    ],
  ),
  // Tata 12
  const TransitRoute(
    name: 'Tata Ligne 12',
    code: '12',
    type: 'TATA',
    color: AppColors.tata,
    points: [
      LatLng(14.7735, -17.3977), LatLng(14.7550, -17.4200),
      LatLng(14.7300, -17.4500), LatLng(14.7100, -17.4700),
      LatLng(14.6850, -17.4600), LatLng(14.6750, -17.4400),
    ],
  ),
  // DDD 12
  const TransitRoute(
    name: 'DDD Ligne 12',
    code: 'DDD-12',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      LatLng(14.7350, -17.5100), LatLng(14.7250, -17.4900),
      LatLng(14.7100, -17.4700), LatLng(14.6950, -17.4550),
      LatLng(14.6800, -17.4450),
    ],
  ),
];

// ============================================================
// APPLICATION
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
  final _pages = const [HomePage(), TripsPage(), SettingsPage(), AlertsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}

// ============================================================
// ÉCRAN EXPLORER
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4000);
  LatLng? _userPosition;
  bool _loadingLocation = false;
  String _selectedFilter = 'Tous';

  Future<void> _locateUser() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Permission refusée');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = LatLng(pos.latitude, pos.longitude);
        _loadingLocation = false;
      });
      _mapController.move(_userPosition!, 14.0);
    } catch (e) {
      setState(() => _loadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position indisponible')),
        );
      }
    }
  }

  void _openAI() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));
  }

  List<Stop> get _filteredStops {
    if (_selectedFilter == 'Tous') return allStops.take(15).toList();
    if (_selectedFilter == 'TER') return terStations.take(8).toList();
    if (_selectedFilter == 'BRT') return brtStations.take(8).toList();
    if (_selectedFilter == 'AFTU') return otherStops.where((s) => s.color == AppColors.aftu).toList();
    if (_selectedFilter == 'Tata') return otherStops.where((s) => s.color == AppColors.tata).toList();
    if (_selectedFilter == 'DDD') return otherStops.where((s) => s.color == AppColors.ddd).toList();
    return allStops;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ============ CARTE EN HAUT ============
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _dakarCenter,
                      initialZoom: 11.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dakar_bus',
                      ),
                      // Tracés des lignes
                      PolylineLayer(
                        polylines: demoRoutes.map((r) => Polyline(
                          points: r.points,
                          color: r.color,
                          strokeWidth: 4.0,
                        )).toList(),
                      ),
                      // Marqueurs d'arrêts
                      MarkerLayer(
                        markers: allStops.map((stop) => Marker(
                          point: stop.location,
                          width: 32, height: 32,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop))),
                            child: Container(
                              decoration: BoxDecoration(
                                color: stop.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
                              ),
                              child: Icon(stop.icon, color: Colors.white, size: 16),
                            ),
                          ),
                        )).toList(),
                      ),
                      // Position utilisateur
                      if (_userPosition != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _userPosition!,
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
                  // Bouton GPS
                  Positioned(
                    top: 12, left: 12,
                    child: FloatingActionButton.small(
                      onPressed: _loadingLocation ? null : _locateUser,
                      backgroundColor: AppColors.surface,
                      child: _loadingLocation
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                  // Assistant IA
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
                  // Légende couleurs officielles
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                      ),
                      child: Wrap(
                        spacing: 10, runSpacing: 4,
                        children: [
                          _legend(AppColors.ter, 'TER'),
                          _legend(AppColors.brt, 'BRT'),
                          _legend(AppColors.ddd, 'DDD'),
                          _legend(AppColors.aftu, 'AFTU'),
                          _legend(AppColors.tata, 'Tata'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ============ CONTENU DÉFILABLE ============
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
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
                        _chip('Tous', AppColors.primary),
                        _chip('TER', AppColors.ter),
                        _chip('BRT', AppColors.brt),
                        _chip('AFTU', AppColors.aftu),
                        _chip('Tata', AppColors.tata),
                        _chip('DDD', AppColors.ddd),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('${_filteredStops.length} arrêts · $_selectedFilter',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ..._filteredStops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StopCard(stop: s),
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
        Container(width: 14, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _chip(String label, Color c) {
    final sel = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? c.withOpacity(0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? c : AppColors.divider, width: sel ? 2 : 1),
          ),
          child: Text(label, style: TextStyle(color: sel ? c : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }
}

class StopCard extends StatelessWidget {
  final Stop stop;
  const StopCard({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop))),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                child: Icon(stop.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(stop.direction, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(stop.schedule, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
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
class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      onPressed: () {},
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Paramètres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _section('Général'),
            _toggle('Notifications', 'Alertes de passage', Icons.notifications_outlined, _notifications, (v) => setState(() => _notifications = v)),
            _toggle('Localisation GPS', 'Position en temps réel', Icons.location_on_outlined, _gps, (v) => setState(() => _gps = v)),
            const SizedBox(height: 20),
            _section('Réseaux couverts'),
            _tileSetting('TER', '13 gares · Dakar ↔ Diamniadio', Icons.train_rounded, AppColors.ter),
            _tileSetting('BRT', '23 stations · Petersen ↔ Guédiawaye', Icons.directions_bus_rounded, AppColors.brt),
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
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20)),
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
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = [terStations[0], brtStations[4], otherStops[0]];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...alerts.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: s.color.withOpacity(0.3), width: 1.5)),
                child: Row(
                  children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: s.color.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(s.icon, color: s.color, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const Text('Prévenu 10 min avant', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ÉCRAN DÉTAIL ARRÊT
// ============================================================
class StopDetailPage extends StatelessWidget {
  final Stop stop;
  const StopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Container(width: 72, height: 72, decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                  child: Icon(stop.icon, color: Colors.white, size: 36)),
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
          const Text('Prochains passages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row('16h25', 'dans 7 min'),
          _row('16h31', 'dans 13 min'),
          _row('16h37', 'dans 19 min'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔔 Alerte programmée'), backgroundColor: AppColors.primary),
                );
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Me prévenir 10 min avant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String time, String count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(count, style: const TextStyle(color: AppColors.textSecondary)),
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
    {'role': 'ai', 'text': 'Bonjour ! Je suis votre assistant Dakar Bus. Posez-moi une question sur les lignes TER, BRT, AFTU, Tata ou DDD.'},
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

  String _generateResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('ter')) return 'Le TER relie Dakar à Diamniadio en 13 gares. Prochain départ dans 2 min depuis la Gare de Dakar. 500-800 FCFA selon la destination.';
    if (q.contains('brt')) return 'Le BRT compte 23 stations entre Petersen et Guédiawaye. Prochain bus à Colobane dans 1 min. 400 FCFA.';
    if (q.contains('ddd') || q.contains('dakar dem dikk')) return 'Dakar Dem Dikk (DDD) couvre plusieurs lignes. Ligne 12 vers Ouakam dans 6 min. 300 FCFA.';
    if (q.contains('tata')) return 'Les bus Tata desservent plusieurs quartiers. Tata 12 vers Guédiawaye dans 4 min. 250 FCFA.';
    if (q.contains('aftu') || q.contains('23')) return 'AFTU Ligne 23 vers Parcelles Assainies dans 3 min. 200 FCFA.';
    if (q.contains('diamniadio')) return 'Diamniadio est le terminus du TER. 13 gares desservies. ~35 km depuis Dakar.';
    if (q.contains('guédiawaye')) return 'Guédiawaye est desservie par le BRT (PEM Guédiawaye) et plusieurs lignes Tata.';
    if (q.contains('plateau')) return 'Pour le Plateau : BRT depuis Colobane (~15 min) ou DDD Ligne 7.';
    if (q.contains('bonjour') || q.contains('salut')) return 'Bonjour ! Comment puis-je vous aider ?';
    return 'Je peux vous renseigner sur les lignes TER (13 gares), BRT (23 stations), AFTU, Tata et DDD. Précisez votre arrêt ou destination.';
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Posez votre question...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}