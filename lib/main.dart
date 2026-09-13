import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

// ------------------- COULEURS OFFICIELLES -------------------
class AppColors {
  static const primary = Color(0xFF00695C);
  
  static const terLine = Color(0xFF8B4513);      // Marron / TER
  static const brtLine = Color(0xFF2E7D32);      // Vert / BRT
  static const dddLine = Color(0xFF1565C0);      // Bleu / DDD
  static const tataLine = Color(0xFF757575);     // Gris / AFTU Tata

  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFEEEEEE);
  static const success = Color(0xFF2E7D32);
}

// ------------------- MODÈLE DE DONNÉES DOUBLE SENS -------------------
class Stop {
  final String id, name, category, lines, distance, schedule, direction, price;
  final String? oppositeDirection; // Sens B (Retour)
  final String? oppositeSchedule;  // Temps de passage Sens B
  final String? oppositeStopId;    // ID de l'arrêt opposé si GTFS parent_station
  final bool isOfficial;
  final IconData icon;
  final Color color;
  final LatLng location;

  const Stop({
    required this.id,
    required this.name,
    required this.category,
    required this.lines,
    required this.distance,
    required this.schedule,
    required this.direction,
    required this.price,
    this.oppositeDirection,
    this.oppositeSchedule,
    this.oppositeStopId,
    required this.isOfficial,
    required this.icon,
    required this.color,
    required this.location,
  });
}

// Tracé GPS TER (Dakar -> Diamniadio)
final List<LatLng> terRoutePoints = [
  const LatLng(14.6678, -17.4331),
  const LatLng(14.6937, -17.4441),
  const LatLng(14.7100, -17.4350),
  const LatLng(14.7320, -17.4100),
  const LatLng(14.7522, -17.3912),
  const LatLng(14.7480, -17.3600),
  const LatLng(14.7550, -17.3400),
  const LatLng(14.7450, -17.3000),
  const LatLng(14.7150, -17.2720),
  const LatLng(14.6920, -17.2280),
  const LatLng(14.7200, -17.1800),
];

// Tracé GPS BRT (Petersen -> Guédiawaye)
final List<LatLng> brtRoutePoints = [
  const LatLng(14.6730, -17.4380),
  const LatLng(14.6950, -17.4420),
  const LatLng(14.7250, -17.4500),
  const LatLng(14.7580, -17.4300),
  const LatLng(14.7780, -17.3980),
];

final List<Stop> demoStops = [
  const Stop(
    id: '1',
    name: 'Gare TER Dakar',
    category: 'TER',
    lines: 'TER Express',
    distance: '100 m',
    schedule: '3 min (08h40)',
    direction: 'Aller : Dir. Diamniadio',
    oppositeDirection: 'Retour : Terminus Dakar (Quai d\'arrivée)',
    oppositeSchedule: 'À quai',
    price: '500 FCFA',
    isOfficial: true,
    icon: Icons.train,
    color: AppColors.terLine,
    location: LatLng(14.6678, -17.4331),
  ),
  const Stop(
    id: '2',
    name: 'Gare TER Colobane',
    category: 'TER',
    lines: 'TER Express',
    distance: '350 m',
    schedule: '5 min (08h45)',
    direction: 'Sens A : Dir. Diamniadio',
    oppositeDirection: 'Sens B : Dir. Dakar Plateau',
    oppositeSchedule: '8 min (08h48)',
    price: '500 FCFA',
    isOfficial: true,
    icon: Icons.train,
    color: AppColors.terLine,
    location: LatLng(14.6937, -17.4441),
  ),
  const Stop(
    id: '3',
    name: 'Station BRT Colobane',
    category: 'BRT',
    lines: 'BRT Ligne B1',
    distance: '150 m',
    schedule: '2 min',
    direction: 'Voie 1 : Dir. Guédiawaye',
    oppositeDirection: 'Voie 2 : Dir. Petersen',
    oppositeSchedule: '6 min',
    price: '400 FCFA',
    isOfficial: true,
    icon: Icons.directions_bus,
    color: AppColors.brtLine,
    location: LatLng(14.6950, -17.4420),
  ),
  const Stop(
    id: '4',
    name: 'Arrêt DDD Palais 1',
    category: 'DDD',
    lines: 'DDD Ligne 8',
    distance: '500 m',
    schedule: '14 min',
    direction: 'Sens Aller : Dir. Ouakam',
    oppositeDirection: 'Sens Retour : Dir. Palais de Justice',
    oppositeSchedule: '4 min',
    price: '175 FCFA',
    isOfficial: true,
    icon: Icons.directions_bus_filled,
    color: AppColors.dddLine,
    location: LatLng(14.6850, -17.4520),
  ),
  const Stop(
    id: '5',
    name: 'Arrêt AFTU Tata 23',
    category: 'AFTU',
    lines: 'Tata Ligne 23',
    distance: '280 m',
    schedule: '6 min',
    direction: 'Sens A : Dir. Parcelles Assainies',
    oppositeDirection: 'Sens B : Dir. Colobane Centre',
    oppositeSchedule: '11 min',
    price: '200 FCFA',
    isOfficial: false,
    icon: Icons.directions_bus_outlined,
    color: AppColors.tataLine,
    location: LatLng(14.7000, -17.4480),
  ),
];

// ------------------- APPLICATION -------------------
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
  final List<String> _alerts = ['1', '2'];

  void _toggleAlert(String stopId) {
    setState(() {
      if (_alerts.contains(stopId)) {
        _alerts.remove(stopId);
      } else {
        _alerts.add(stopId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(alerts: _alerts, onToggleAlert: _toggleAlert),
      const TripsPage(),
      const MapPage(),
      AlertsPage(alerts: _alerts, onToggleAlert: _toggleAlert),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
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

// ------------------- PAGE DÉTAIL EN DOUBLE SENS -------------------
class StopDetailPage extends StatelessWidget {
  final Stop stop;
  const StopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stop.name),
        backgroundColor: stop.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Chip(
                label: Text(stop.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: stop.color,
              ),
              const SizedBox(width: 8),
              Text(stop.lines, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Tarif: ${stop.price}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),

          // SECTION 1 : SENS ALLER (SENS A)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: stop.color, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.north_east, color: stop.color),
                    const SizedBox(width: 8),
                    const Text('SECTION 1 — SENS ALLER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(stop.direction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text('Prochain passage : ${stop.schedule}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // SECTION 2 : SENS RETOUR (SENS B)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.south_west, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('SECTION 2 — SENS RETOUR (OPPOSÉ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(stop.oppositeDirection ?? 'Sens Retour', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Prochain passage : ${stop.oppositeSchedule ?? "Disponible dans 7 min"}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- COMPOSANTS ACCUEIL ET CARTE -------------------
class HomePage extends StatefulWidget {
  final List<String> alerts;
  final Function(String) onToggleAlert;

  const HomePage({super.key, required this.alerts, required this.onToggleAlert});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  @override
  Widget build(BuildContext context) {
    final filteredStops = demoStops.where((stop) {
      final matchesSearch = stop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.lines.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Tous' || stop.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

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
                  child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dakar Bus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('TER · BRT · DDD · AFTU (Double Sens)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un arrêt ou une ligne...',
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'TER', 'BRT', 'DDD', 'AFTU'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Arrêts & Départs en temps réel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...filteredStops.map((stop) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StopCard(
                    stop: stop,
                    isAlertActive: widget.alerts.contains(stop.id),
                    onToggleAlert: () => widget.onToggleAlert(stop.id),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class StopCard extends StatelessWidget {
  final Stop stop;
  final bool isAlertActive;
  final VoidCallback onToggleAlert;

  const StopCard({
    super.key,
    required this.stop,
    required this.isAlertActive,
    required this.onToggleAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                child: Icon(stop.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('↕ Double sens disponible', style: TextStyle(fontSize: 11, color: stop.color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(stop.schedule, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                  Text(stop.price, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                icon: Icon(
                  isAlertActive ? Icons.notifications_active : Icons.notifications_none,
                  color: isAlertActive ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: onToggleAlert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(14.7100, -17.3800),
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dakar_bus',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: terRoutePoints, strokeWidth: 5.0, color: AppColors.terLine),
                Polyline(points: brtRoutePoints, strokeWidth: 4.5, color: AppColors.brtLine),
              ],
            ),
            MarkerLayer(
              markers: demoStops.map((stop) {
                return Marker(
                  point: stop.location,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop)));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: stop.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(stop.icon, color: Colors.white, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  final List<String> alerts;
  final Function(String) onToggleAlert;

  const AlertsPage({super.key, required this.alerts, required this.onToggleAlert});

  @override
  Widget build(BuildContext context) {
    final alertStops = demoStops.where((s) => alerts.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (alertStops.isEmpty)
              const Center(child: Text('Aucune alerte enregistrée.'))
            else
              ...alertStops.map((s) => Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: s.color, child: Icon(s.icon, color: Colors.white)),
                      title: Text(s.name),
                      subtitle: Text(s.direction),
                      trailing: IconButton(
                        icon: const Icon(Icons.notifications_active, color: AppColors.primary),
                        onPressed: () => onToggleAlert(s.id),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Module Recherche de Trajets.')),
    );
  }
}
