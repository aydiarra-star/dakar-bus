import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFFE53935);
  static const aftu = Color(0xFFEF6C00);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFEEEEEE);
  static const success = Color(0xFF2E7D32);
}

class Stop {
  final String name, lines, distance, schedule, direction, price;
  final bool isOfficial;
  final IconData icon;
  final Color color;
  final LatLng location;

  const Stop({
    required this.name,
    required this.lines,
    required this.distance,
    required this.schedule,
    required this.direction,
    required this.price,
    required this.isOfficial,
    required this.icon,
    required this.color,
    required this.location,
  });
}

final List<Stop> demoStops = [
  const Stop(
    name: 'Gare TER Colobane',
    lines: 'TER Ligne Express',
    distance: '350 m',
    schedule: '5 min',
    direction: 'Dir. Diamniadio / Thiaroye',
    price: '500 FCFA',
    isOfficial: true,
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: LatLng(14.6937, -17.4441),
  ),
  const Stop(
    name: 'Station BRT Colobane (B1)',
    lines: 'BRT Ligne B1',
    distance: '150 m',
    schedule: '1 min',
    direction: 'Dir. Guédiawaye Petersen',
    price: '400 FCFA',
    isOfficial: true,
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: LatLng(14.6950, -17.4420),
  ),
  const Stop(
    name: 'Arrêt AFTU Ligne 23',
    lines: 'Bus Tata 23',
    distance: '280 m',
    schedule: '3 min',
    direction: 'Dir. Parcelles Assainies',
    price: '200 FCFA',
    isOfficial: false,
    icon: Icons.directions_bus_outlined,
    color: AppColors.aftu,
    location: LatLng(14.6900, -17.4460),
  ),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
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
  final _pages = const [HomePage(), TripsPage(), MapPage(), AlertsPage()];

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
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Explorer'),
          NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route, color: AppColors.primary),
              label: 'Trajets'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppColors.primary),
              label: 'Carte'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications, color: AppColors.primary),
              label: 'Alertes'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_bus,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dakar Bus',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      Text('TER · BRT · AFTU',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Temps réel Live',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Où voulez-vous aller ? (ex: Thiaroye...)',
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Tous les réseaux', true),
                  _filterChip('TER & BRT', false),
                  _filterChip('AFTU Tata', false),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Prochains départs autour de vous',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...demoStops.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StopCard(stop: s),
                )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ],
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: stop.color, shape: BoxShape.circle),
                child: Icon(stop.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(stop.direction,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(stop.schedule,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success)),
                  Text(stop.price,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            const Text('Planifier un trajet',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _tile(Icons.my_location, AppColors.primary, 'Départ',
                      'Gare TER Colobane'),
                  const Divider(height: 24),
                  _tile(Icons.location_on, AppColors.ter, 'Arrivée',
                      'Guédiawaye (BRT)'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Rechercher',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text(title,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final LatLng _dakarCenter = const LatLng(14.6937, -17.4441);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _dakarCenter,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dakar_bus',
                ),
                MarkerLayer(
                  markers: demoStops.map((stop) {
                    return Marker(
                      point: stop.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      StopDetailPage(stop: stop)));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: stop.color,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(stop.icon,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Assistant IA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            const Text('Mes alertes',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            ...demoStops.take(2).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: s.color.withOpacity(0.3),
                            width: 1.5)),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: s.color.withOpacity(0.12),
                              shape: BoxShape.circle),
                          child: Icon(s.icon, color: s.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                              const Text('Prévenu 10 min avant',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.notifications_active,
                            color: AppColors.primary),
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

class StopDetailPage extends StatelessWidget {
  final Stop stop;
  const StopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
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
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      color: stop.color, shape: BoxShape.circle),
                  child: Icon(stop.icon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text(stop.direction,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('À ${stop.distance} de vous',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(stop.price,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(width: 8),
              const Text('par passage',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Prochains passages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  const SnackBar(
                      content: Text('🔔 Alerte programmée'),
                      backgroundColor: AppColors.primary),
                );
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Me prévenir 10 min avant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(count, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}