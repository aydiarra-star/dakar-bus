import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DakarBusApp());
}

class DakarBusApp extends StatefulWidget {
  const DakarBusApp({super.key});

  @override
  State<DakarBusApp> createState() => _DakarBusAppState();
}

class _DakarBusAppState extends State<DakarBusApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Bus',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
      ),
      home: MainNavigationScreen(
        onThemeChanged: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

// --- MODÈLES DE DONNÉES ---

enum RealtimeStatus { realtime, scheduled, estimated }
enum DataSource { crowdsourcing, scrapedApi, hybrid }

class TransitStop {
  final String id;
  final String name;
  final String network;
  final String direction;
  final LatLng point;
  int minutesRemaining;
  final Color color;
  final IconData icon;

  TransitStop({
    required this.id,
    required this.name,
    required this.network,
    required this.direction,
    required this.point,
    required this.minutesRemaining,
    required this.color,
    required this.icon,
  });
}

class LiveVehicle {
  final String id;
  final String lineName;
  LatLng currentPosition;
  final double heading;
  final Color color;
  final IconData icon;

  LiveVehicle({
    required this.id,
    required this.lineName,
    required this.currentPosition,
    required this.heading,
    required this.color,
    required this.icon,
  });
}

// --- ÉCRAN PRINCIPAL AVEC NAVIGATION ---

class MainNavigationScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const MainNavigationScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MapHomeScreen(),
      const RoutePlannerScreen(),
      const AllStopsScreen(),
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Trajets'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Arrêts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}

// --- DONNÉES GLOBALES ET RÉSEAU ---

final List<TransitStop> globalStopsList = [
  // BRT & TER
  TransitStop(
    id: 'brt_petersen',
    name: 'Station BRT Petersen',
    network: 'BRT',
    direction: 'Ligne B1 • Dir. Guédiawaye',
    point: const LatLng(14.6785, -17.4398),
    minutesRemaining: 2,
    color: const Color(0xFF1E88E5),
    icon: Icons.directions_bus_filled,
  ),
  TransitStop(
    id: 'ter_dakar',
    name: 'Gare TER Dakar (Place des Tirailleurs)',
    network: 'TER',
    direction: 'Ligne Express • Dir. Diamniadio',
    point: const LatLng(14.6678, -17.4332),
    minutesRemaining: 4,
    color: const Color(0xFFE53935),
    icon: Icons.directions_railway_filled,
  ),
  TransitStop(
    id: 'brt_grand_yoff',
    name: 'Station BRT Grand Yoff / Liberté 6',
    network: 'BRT',
    direction: 'Ligne B1 • Dir. Petersen',
    point: const LatLng(14.7212, -17.4618),
    minutesRemaining: 6,
    color: const Color(0xFF1E88E5),
    icon: Icons.directions_bus_filled,
  ),
  // DAKAR DEM DIKK
  TransitStop(
    id: 'ddd_thies',
    name: 'Gare Interurbaine DDD Thiès',
    network: 'DDD',
    direction: 'Ligne Express • Dir. Dakar Centre',
    point: const LatLng(14.7833, -16.9333),
    minutesRemaining: 14,
    color: const Color(0xFF2E7D32),
    icon: Icons.directions_bus_filled,
  ),
  TransitStop(
    id: 'ddd_parcelles',
    name: 'Terminus DDD Parcelles Assainies',
    network: 'DDD',
    direction: 'Ligne 6 • Dir. Palais de Justice',
    point: const LatLng(14.7560, -17.4420),
    minutesRemaining: 8,
    color: const Color(0xFF2E7D32),
    icon: Icons.directions_bus_filled,
  ),
  // BUS TATA AFTU
  TransitStop(
    id: 'aftu_keur_massar',
    name: 'Arrêt AFTU Tata Keur Massar',
    network: 'AFTU',
    direction: 'Tata 24 • Dir. Colobane',
    point: const LatLng(14.7780, -17.3110),
    minutesRemaining: 3,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_bus,
  ),
  TransitStop(
    id: 'aftu_pikine',
    name: 'Arrêt AFTU Tata Pikine Croisement',
    network: 'AFTU',
    direction: 'Tata 38 • Dir. Marché HLM',
    point: const LatLng(14.7525, -17.3980),
    minutesRemaining: 5,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_bus,
  ),
  TransitStop(
    id: 'aftu_guediawaye',
    name: 'Arrêt AFTU Tata Guédiawaye',
    network: 'AFTU',
    direction: 'Tata 28 • Dir. Petersen',
    point: const LatLng(14.7738, -17.3975),
    minutesRemaining: 7,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_bus,
  ),
];

// --- ONGLET 1 : CARTE DE L'ACCUEIL ---

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final MapController _mapController = MapController();
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  Timer? _timer;

  List<LiveVehicle> _liveVehicles = [];

  final List<LatLng> _terRoute = const [
    LatLng(14.6678, -17.4332), LatLng(14.7170, -17.4310),
    LatLng(14.7525, -17.4012), LatLng(14.7132, -17.2718),
  ];

  final List<LatLng> _brtRoute = const [
    LatLng(14.6785, -17.4398), LatLng(14.6995, -17.4520),
    LatLng(14.7212, -17.4618), LatLng(14.7738, -17.3975),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      setState(() {
        _updateLivePositions();
      });
    });
    _updateLivePositions();
  }

  void _updateLivePositions() {
    final now = DateTime.now().second;
    _liveVehicles = [
      LiveVehicle(
        id: 'brt_101',
        lineName: 'BRT B1',
        currentPosition: LatLng(14.6850 + (now % 10) * 0.005, -17.4450 + (now % 10) * 0.002),
        heading: 45.0,
        color: const Color(0xFF1E88E5),
        icon: Icons.directions_bus_filled,
      ),
      LiveVehicle(
        id: 'ter_01',
        lineName: 'TER Express',
        currentPosition: LatLng(14.7000 + (now % 8) * 0.006, -17.4100 + (now % 8) * 0.004),
        heading: 90.0,
        color: const Color(0xFFE53935),
        icon: Icons.directions_railway_filled,
      ),
      LiveVehicle(
        id: 'tata_24',
        lineName: 'AFTU Tata 24',
        currentPosition: LatLng(14.7500 + (now % 5) * 0.003, -17.3800 + (now % 5) * 0.003),
        heading: 120.0,
        color: const Color(0xFFFB8C00),
        icon: Icons.directions_bus,
      ),
      LiveVehicle(
        id: 'ddd_12',
        lineName: 'DDD Ligne 12',
        currentPosition: LatLng(14.7200 + (now % 6) * 0.004, -17.4600 + (now % 6) * 0.001),
        heading: 30.0,
        color: const Color(0xFF2E7D32),
        icon: Icons.directions_bus_filled,
      ),
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStops = globalStopsList.where((stop) {
      final matchesSearch = stop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.direction.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.network.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedFilter == 'TER_BRT') return matchesSearch && (stop.network == 'TER' || stop.network == 'BRT');
      if (_selectedFilter == 'AFTU') return matchesSearch && stop.network == 'AFTU';
      if (_selectedFilter == 'DDD') return matchesSearch && stop.network == 'DDD';
      return matchesSearch;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(14.7100, -17.4100),
              initialZoom: 11.8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dakarbus.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: _terRoute, strokeWidth: 5, color: const Color(0xFFE53935)),
                  Polyline(points: _brtRoute, strokeWidth: 5, color: const Color(0xFF1E88E5)),
                ],
              ),
              MarkerLayer(
                markers: filteredStops.map((stop) {
                  return Marker(
                    point: stop.point,
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _mapController.move(stop.point, 14.5),
                      child: CircleAvatar(
                        backgroundColor: stop.color,
                        child: Icon(stop.icon, color: Colors.white, size: 18),
                      ),
                    ),
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: _liveVehicles.map((vehicle) {
                  return Marker(
                    point: vehicle.currentPosition,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: vehicle.color, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Icon(vehicle.icon, color: vehicle.color, size: 22),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: () => _mapController.move(const LatLng(14.7100, -17.4100), 11.8),
                    child: const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openAIAssistant,
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    label: const Text('Assistant IA', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.18,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, color: Color(0xFF2E7D32), size: 28),
                        const SizedBox(width: 8),
                        const Text('Dakar Bus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(12)),
                          child: const Text('LIVE 100%', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un arrêt (Pikine, Petersen, Tata)...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tous les réseaux', 'ALL'),
                          _buildFilterChip('TER & BRT', 'TER_BRT'),
                          _buildFilterChip('Dakar Dem Dikk', 'DDD'),
                          _buildFilterChip('AFTU Tata', 'AFTU'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Prochains passages à proximité', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...filteredStops.map((stop) => _buildStopTile(stop)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String id) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFC8E6C9),
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }

  Widget _buildStopTile(TransitStop stop) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white, size: 20)),
        title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        subtitle: Text(stop.direction, style: const TextStyle(fontSize: 11)),
        trailing: Text('${stop.minutesRemaining} min', style: TextStyle(color: stop.color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _openAIAssistant() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assistant IA Dakar Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Posez une question sur le réseau de transport de Dakar.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('Fermer', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}

// --- ONGLET 2 : CALCULATEUR DE TRAJETS ---

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final TextEditingController _startController = TextEditingController(text: 'Ma position actuelle');
  final TextEditingController _destController = TextEditingController();
  bool _hasSearched = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculateur d\'itinéraires'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _startController,
              decoration: const InputDecoration(
                labelText: 'Départ',
                prefixIcon: Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destController,
              decoration: const InputDecoration(
                labelText: 'Destination (ex: Guédiawaye, Thiès, Petersen)',
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  setState(() {
                    _hasSearched = true;
                  });
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text('Rechercher des trajets', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            if (_hasSearched)
              Expanded(
                child: ListView(
                  children: [
                    _buildRouteResultCard(
                      title: 'Option la plus rapide (BRT + Bus Tata)',
                      duration: '25 min',
                      price: '300 FCFA',
                      steps: 'Prendre le BRT B1 à Petersen, puis Tata 24',
                      color: const Color(0xFF1E88E5),
                    ),
                    _buildRouteResultCard(
                      title: 'Option Express TER',
                      duration: '18 min',
                      price: '500 FCFA',
                      steps: 'Prendre le TER à la Gare de Dakar vers Diamniadio',
                      color: const Color(0xFFE53935),
                    ),
                    _buildRouteResultCard(
                      title: 'Ligne Directe Dakar Dem Dikk',
                      duration: '35 min',
                      price: '200 FCFA',
                      steps: 'Ligne DDD 12 direct jusqu\'au terminus',
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteResultCard({
    required String title,
    required String duration,
    required String price,
    required String steps,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.directions_transit, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$steps\nTarif estimé : $price'),
        trailing: Text(duration, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

// --- ONGLET 3 : LISTE TOUS LES ARRÊTS ---

class AllStopsScreen extends StatefulWidget {
  const AllStopsScreen({super.key});

  @override
  State<AllStopsScreen> createState() => _AllStopsScreenState();
}

class _AllStopsScreenState extends State<AllStopsScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = globalStopsList.where((stop) {
      return stop.name.toLowerCase().contains(_filter.toLowerCase()) ||
          stop.network.toLowerCase().contains(_filter.toLowerCase()) ||
          stop.direction.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tous les arrêts de transport'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => _filter = val),
              decoration: const InputDecoration(
                hintText: 'Rechercher un arrêt (Pikine, TER, Tata 24)...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final stop = filtered[index];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white)),
                  title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${stop.network} • ${stop.direction}'),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- ONGLET 4 : PARAMÈTRES ---

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _gpsEnabled = true;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Mode Sombre'),
            subtitle: const Text('Activer le thème sombre pour l\'application'),
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Géolocalisation GPS'),
            subtitle: const Text('Autoriser la détection des bus proches'),
            value: _gpsEnabled,
            onChanged: (val) => setState(() => _gpsEnabled = val),
            secondary: const Icon(Icons.gps_fixed),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Notifications en direct'),
            subtitle: const Text('Recevoir les alertes de perturbation des lignes'),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('À propos de Dakar Bus'),
            subtitle: const Text('Version 1.0.0 • Réseaux BRT, TER, DDD, AFTU Tata'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Dakar Bus',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Dakar Bus - Suivi en temps réel.',
              );
            },
          ),
        ],
      ),
    );
  }
}
