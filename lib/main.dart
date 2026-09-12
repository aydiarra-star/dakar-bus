import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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

final demoStops = [
  const Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar', schedule: '2 min', price: '500 FCFA', distance: '350 m', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407)),
  const Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', schedule: '5 min', price: '500 FCFA', distance: '400 m', icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441)),
  const Stop(name: 'Station BRT Colobane', direction: 'Dir. Guédiawaye Petersen', schedule: '1 min', price: '400 FCFA', distance: '150 m', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420)),
  const Stop(name: 'Station BRT Guédiawaye', direction: 'Dir. Petersen', schedule: '8 min', price: '400 FCFA', distance: '2.1 km', icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977)),
  const Stop(name: 'Arrêt AFTU Ligne 23', direction: 'Dir. Parcelles Assainies', schedule: '3 min', price: '200 FCFA', distance: '280 m', icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460)),
  const Stop(name: 'Arrêt Tata 12', direction: 'Dir. Guédiawaye', schedule: '4 min', price: '250 FCFA', distance: '600 m', icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700)),
  const Stop(name: 'Arrêt DDD Ligne 12', direction: 'Dir. Ouakam / Almadies', schedule: '6 min', price: '300 FCFA', distance: '800 m', icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900)),
];

final demoRoutes = [
  const TransitRoute(name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter, points: [LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7100, -17.4350), LatLng(14.7230, -17.4280), LatLng(14.7380, -17.4150), LatLng(14.7500, -17.3980), LatLng(14.7650, -17.3800)]),
  const TransitRoute(name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt, points: [LatLng(14.7735, -17.3977), LatLng(14.7550, -17.4100), LatLng(14.7350, -17.4250), LatLng(14.7150, -17.4350), LatLng(14.6950, -17.4420), LatLng(14.6820, -17.4480), LatLng(14.6720, -17.4400)]),
  const TransitRoute(name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu, points: [LatLng(14.7600, -17.4400), LatLng(14.7400, -17.4450), LatLng(14.7200, -17.4480), LatLng(14.7000, -17.4500), LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400)]),
  const TransitRoute(name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata, points: [LatLng(14.7735, -17.3977), LatLng(14.7550, -17.4200), LatLng(14.7300, -17.4500), LatLng(14.7100, -17.4700), LatLng(14.6850, -17.4600), LatLng(14.6750, -17.4400)]),
  const TransitRoute(name: 'DDD', code: 'DDD-12', type: 'DDD', color: AppColors.ddd, points: [LatLng(14.7350, -17.5100), LatLng(14.7250, -17.4900), LatLng(14.7100, -17.4700), LatLng(14.6950, -17.4550), LatLng(14.6800, -17.4450)]),
];

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

// ============ ÉCRAN EXPLORER ============
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7000, -17.4500);
  LatLng? _userPosition;
  bool _loadingLocation = false;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Position indisponible')));
      }
    }
  }

  void _openAI() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));
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
                      initialZoom: 12.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dakar_bus',
                      ),
                      PolylineLayer(
                        polylines: demoRoutes.map((r) => Polyline(
                          points: r.points,
                          color: r.color,
                          strokeWidth: 4.0,
                        )).toList(),
                      ),
                      MarkerLayer(
                        markers: demoStops.map((stop) => Marker(
                          point: stop.location,
                          width: 36, height: 36,
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
                              child: Icon(stop.icon, color: Colors.white, size: 18),
                            ),
                          ),
                        )).toList(),
                      ),
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
                  // Légende
                  Positioned(
                    bottom: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                        _chip('Tous', true, AppColors.primary),
                        _chip('TER', false, AppColors.ter),
                        _chip('BRT', false, AppColors.brt),
                        _chip('AFTU', false, AppColors.aftu),
                        _chip('Tata', false, AppColors.tata),
                        _chip('DDD', false, AppColors.ddd),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Prochains départs autour de vous',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...demoStops.map((s) => Padding(
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
        Container(width: 12, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _chip(String label, bool sel, Color c) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? c : AppColors.divider),
        ),
        child: Text(label, style: TextStyle(color: sel ? c : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
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

// ============ TRAJETS ============
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

// ============ PARAMÈTRES ============
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _gps = true;
  bool _darkMode = false;

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
            _toggle('Mode sombre', 'Bientôt disponible', Icons.dark_mode_outlined, _darkMode, (v) => setState(() => _darkMode = v)),
            const SizedBox(height: 20),
            _section('Réseaux'),
            _tileSetting('TER', 'Train Express Régional', Icons.train_rounded, AppColors.ter),
            _tileSetting('BRT', 'Bus Rapid Transit', Icons.directions_bus_rounded, AppColors.brt),
            _tileSetting('AFTU', 'Association de financement', Icons.directions_bus_outlined, AppColors.aftu),
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

// ============ ALERTES ============
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...demoStops.take(3).map((s) => Padding(
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

// ============ DÉTAIL ARRÊT ============
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

// ============ ASSISTANT IA ============
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Bonjour ! Je suis votre assistant Dakar Bus. Posez-moi une question.'},
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
    if (q.contains('brt')) return 'Prochain BRT à Colobane dans 1 min, dir. Guédiawaye Petersen. 400 FCFA.';
    if (q.contains('ter')) return 'Prochain TER de Dakar dans 5 min, dir. Diamniadio. 500 FCFA.';
    if (q.contains('aftu') || q.contains('23')) return 'AFTU Ligne 23 dans 3 min, dir. Parcelles Assainies. 200 FCFA.';
    if (q.contains('tata') || q.contains('12')) return 'Tata 12 dans 4 min, dir. Guédiawaye. 250 FCFA.';
    if (q.contains('ddd')) return 'DDD Ligne 12 dans 6 min, dir. Ouakam. 300 FCFA.';
    if (q.contains('plateau')) return 'Pour le Plateau : BRT depuis Colobane, ~15 min.';
    if (q.contains('bonjour') || q.contains('salut')) return 'Bonjour ! Comment puis-je vous aider ?';
    return 'Je peux vous renseigner sur TER, BRT, AFTU, Tata, DDD. Précisez votre arrêt ou destination.';
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