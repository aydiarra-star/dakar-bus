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
  final String network; // BRT, TER, DDD, AFTU (Tata)
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

// --- ONGLET & STRUCTURE PRINCIPALE ---

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
  bool _hasSeenWelcome = false;

  List<LatLng> _highlightedItineraryPoints = [];
  String? _highlightedItineraryName;
  Color _highlightedItineraryColor = Colors.transparent;

  final GlobalKey<_MapHomeScreenState> _mapHomeKey = GlobalKey<_MapHomeScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSeenWelcome) {
        _showWelcomeOnboardingDialog();
      }
    });
  }

  void _showWelcomeOnboardingDialog() {
    setState(() => _hasSeenWelcome = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.directions_bus, color: Color(0xFF2E7D32), size: 30),
            SizedBox(width: 8),
            Text('Bienvenue sur Dakar Bus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Découvrez l’application de suivi temps réel pour tous vos déplacements à Dakar ! 🇸🇳',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• 🚄 Suivi complet : TER, BRT, Dakar Dem Dikk et bus Tata.\n• 🗺️ Carte interactive avec passages et distances estimées.\n• ⏱️ Calculateur de trajets intelligent.\n• 🤖 Assistant de voyage IA.'),
            SizedBox(height: 8),
            Text(
              'Prêt à voyager intelligemment ?',
              style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF2E7D32)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Commencer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRouteOnMap(List<LatLng> points, String name, Color color) {
    setState(() {
      _highlightedItineraryPoints = points;
      _highlightedItineraryName = name;
      _highlightedItineraryColor = color;
      _currentIndex = 0;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_mapHomeKey.currentState != null && points.isNotEmpty) {
        _mapHomeKey.currentState!._centerOnRoute(points.first, points);
      }
    });
  }

  void _clearHighlightedRoute() {
    setState(() {
      _highlightedItineraryPoints = [];
      _highlightedItineraryName = null;
      _highlightedItineraryColor = Colors.transparent;
    });
  }

  void _navigateToAndSearch(TransitStop stop) {
    setState(() {
      _currentIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_mapHomeKey.currentState != null) {
        _mapHomeKey.currentState!._focusOnStop(stop);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MapHomeScreen(
        key: _mapHomeKey,
        activeItineraryPoints: _highlightedItineraryPoints,
        activeItineraryName: _highlightedItineraryName,
        activeItineraryColor: _highlightedItineraryColor,
        onClearItinerary: _clearHighlightedRoute,
      ),
      RoutePlannerScreen(onShowOnMap: _showRouteOnMap),
      AllStopsScreen(onSelectStop: _navigateToAndSearch),
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
  // BRT
  TransitStop(
    id: 'brt_petersen',
    name: 'Station BRT Petersen',
    network: 'BRT',
    direction: 'Ligne B1 • Dir. Guédiawaye',
    point: const LatLng(14.6785, -17.4398),
    minutesRemaining: 2,
    color: const Color(0xFF1E88E5),
    icon: Icons.directions_bus,
  ),
  TransitStop(
    id: 'brt_grand_yoff',
    name: 'Station BRT Grand Yoff / Liberté 6',
    network: 'BRT',
    direction: 'Ligne B1 • Dir. Petersen',
    point: const LatLng(14.7212, -17.4618),
    minutesRemaining: 6,
    color: const Color(0xFF1E88E5),
    icon: Icons.directions_bus,
  ),
  // TER
  TransitStop(
    id: 'ter_dakar',
    name: 'Gare TER Dakar (Place des Tirailleurs)',
    network: 'TER',
    direction: 'Ligne Express • Dir. Diamniadio',
    point: const LatLng(14.6678, -17.4332),
    minutesRemaining: 4,
    color: const Color(0xFFE53935),
    icon: Icons.train,
  ),
  TransitStop(
    id: 'ter_pikine',
    name: 'Gare TER Pikine',
    network: 'TER',
    direction: 'Ligne Omnis • Dir. Dakar',
    point: const LatLng(14.7525, -17.4012),
    minutesRemaining: 8,
    color: const Color(0xFFE53935),
    icon: Icons.train,
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
    icon: Icons.directions_bus,
  ),
  TransitStop(
    id: 'ddd_parcelles',
    name: 'Terminus DDD Parcelles Assainies',
    network: 'DDD',
    direction: 'Ligne 6 • Dir. Palais de Justice',
    point: const LatLng(14.7560, -17.4420),
    minutesRemaining: 8,
    color: const Color(0xFF2E7D32),
    icon: Icons.directions_bus,
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
    icon: Icons.directions_transit,
  ),
  TransitStop(
    id: 'aftu_pikine_croisement',
    name: 'Arrêt AFTU Tata Pikine Croisement',
    network: 'AFTU',
    direction: 'Tata 38 • Dir. Marché HLM',
    point: const LatLng(14.7435, -17.3910),
    minutesRemaining: 5,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_transit,
  ),
  TransitStop(
    id: 'aftu_guediawaye',
    name: 'Arrêt AFTU Tata Guédiawaye',
    network: 'AFTU',
    direction: 'Tata 28 • Dir. Petersen',
    point: const LatLng(14.7738, -17.3975),
    minutesRemaining: 7,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_transit,
  ),
  TransitStop(
    id: 'aftu_mermoz',
    name: 'Arrêt AFTU Tata Mermoz / VDN',
    network: 'AFTU',
    direction: 'Tata 44 • Dir. Ouakam',
    point: const LatLng(14.7080, -17.4720),
    minutesRemaining: 9,
    color: const Color(0xFFFB8C00),
    icon: Icons.directions_transit,
  ),
];

// --- CALCULATEUR DE DISTANCE ---

String getStopEstimatedDistance(LatLng userPos, LatLng stopPos) {
  final double meters = Geolocator.distanceBetween(
    userPos.latitude,
    userPos.longitude,
    stopPos.latitude,
    stopPos.longitude,
  );
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  } else {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

// --- ONGLET 1 : CARTE DE L'ACCUEIL ---

class MapHomeScreen extends StatefulWidget {
  final List<LatLng> activeItineraryPoints;
  final String? activeItineraryName;
  final Color activeItineraryColor;
  final VoidCallback onClearItinerary;

  const MapHomeScreen({
    super.key,
    required this.activeItineraryPoints,
    this.activeItineraryName,
    required this.activeItineraryColor,
    required this.onClearItinerary,
  });

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(14.7100, -17.4100);
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

  void _centerOnRoute(LatLng start, List<LatLng> routePoints) {
    _mapController.move(start, 13.5);
  }

  void _focusOnStop(TransitStop stop) {
    _mapController.move(stop.point, 15.0);
    setState(() {
      _searchQuery = stop.name;
    });
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
        icon: Icons.directions_bus,
      ),
      LiveVehicle(
        id: 'ter_01',
        lineName: 'TER Express',
        currentPosition: LatLng(14.7000 + (now % 8) * 0.006, -17.4100 + (now % 8) * 0.004),
        heading: 90.0,
        color: const Color(0xFFE53935),
        icon: Icons.train,
      ),
      LiveVehicle(
        id: 'tata_24',
        lineName: 'AFTU Tata 24',
        currentPosition: LatLng(14.7500 + (now % 5) * 0.003, -17.3800 + (now % 5) * 0.003),
        heading: 120.0,
        color: const Color(0xFFFB8C00),
        icon: Icons.directions_transit,
      ),
      LiveVehicle(
        id: 'ddd_12',
        lineName: 'DDD Ligne 12',
        currentPosition: LatLng(14.7200 + (now % 6) * 0.004, -17.4600 + (now % 6) * 0.001),
        heading: 30.0,
        color: const Color(0xFF2E7D32),
        icon: Icons.directions_bus,
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
            options: MapOptions(
              initialCenter: _defaultCenter,
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
                  if (widget.activeItineraryPoints.isNotEmpty)
                    Polyline(
                      points: widget.activeItineraryPoints,
                      strokeWidth: 7,
                      color: widget.activeItineraryColor,
                      borderStrokeWidth: 3,
                      borderColor: Colors.white,
                    ),
                ],
              ),
              MarkerLayer(
                markers: filteredStops.map((stop) {
                  return Marker(
                    point: stop.point,
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(stop.point, 14.5);
                        _showStopDetailBottomSheet(stop);
                      },
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
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${vehicle.lineName} • En déplacement direct'),
                            backgroundColor: vehicle.color,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: vehicle.color, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Icon(vehicle.icon, color: vehicle.color, size: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          if (widget.activeItineraryPoints.isNotEmpty)
            Positioned(
              top: 70,
              left: 12,
              right: 12,
              child: Card(
                color: const Color(0xFFE8F5E9),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.navigation, color: Color(0xFF2E7D32)),
                  title: Text(widget.activeItineraryName ?? 'Itinéraire', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Tracé affiché à l\'écran', style: TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: widget.onClearItinerary,
                  ),
                ),
              ),
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
                    onPressed: () => _mapController.move(_defaultCenter, 11.8),
                    child: const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        heroTag: 'report_incident_btn',
                        onPressed: _showReportIncidentDialog,
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                        label: const Text('Signaler', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        heroTag: 'ai_assistant_btn',
                        onPressed: _openAIAssistant,
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                        label: const Text('Assistant IA', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                      ),
                    ],
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
    final distStr = getStopEstimatedDistance(_defaultCenter, stop.point);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        onTap: () {
          _mapController.move(stop.point, 15.0);
          _showStopDetailBottomSheet(stop);
        },
        leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white, size: 20)),
        title: Row(
          children: [
            Expanded(child: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: Text(stop.network, style: TextStyle(color: stop.color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Text('${stop.direction} • 🚶 $distStr', style: const TextStyle(fontSize: 11)),
        trailing: Text('${stop.minutesRemaining} min', style: TextStyle(color: stop.color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _showStopDetailBottomSheet(TransitStop stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: stop.color, radius: 24, child: Icon(stop.icon, color: Colors.white, size: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stop.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${stop.network} • ${stop.direction}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Statut de passage :', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: stop.color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                  child: Text('${stop.minutesRemaining} min estimé', style: TextStyle(color: stop.color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('💡 Correspondances disponibles ou lignes fréquentes pour cet arrêt.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    onPressed: () {
                      Navigator.pop(context);
                      _mapController.move(stop.point, 15.5);
                    },
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: const Text('Voir de plus près', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showReportIncidentDialog() {
    String selectType = 'Embouteillage 🚗';
    final List<String> types = ['Embouteillage 🚗', 'Bus en retard ⏱️', 'Panne de Transport 🔧', 'Perturbation de Route 🚧'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler un Incident'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aidez la communauté en signalant un problème en direct sur les lignes d\'aujourd\'hui.'),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectType,
                isExpanded: true,
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectType = val);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Merci ! Incident "$selectType" partagé avec les voyageurs.'),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Soumettre', style: TextStyle(color: Colors.white)),
          )
        ],
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
  final Function(List<LatLng>, String, Color) onShowOnMap;

  const RoutePlannerScreen({
    super.key,
    required this.onShowOnMap,
  });

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
                      points: const [
                        LatLng(14.6785, -17.4398),
                        LatLng(14.6995, -17.4520),
                        LatLng(14.7212, -17.4618),
                        LatLng(14.7780, -17.3110),
                      ],
                    ),
                    _buildRouteResultCard(
                      title: 'Option Express TER',
                      duration: '18 min',
                      price: '500 FCFA',
                      steps: 'Prendre le TER à la Gare de Dakar vers Diamniadio',
                      color: const Color(0xFFE53935),
                      points: const [
                        LatLng(14.6678, -17.4332),
                        LatLng(14.7170, -17.4310),
                        LatLng(14.7525, -17.4012),
                        LatLng(14.7132, -17.2718),
                      ],
                    ),
                    _buildRouteResultCard(
                      title: 'Ligne Directe Dakar Dem Dikk',
                      duration: '35 min',
                      price: '200 FCFA',
                      steps: 'Ligne DDD 12 direct jusqu\'au terminus',
                      color: const Color(0xFF2E7D32),
                      points: const [
                        LatLng(14.6680, -17.4320),
                        LatLng(14.7230, -17.4860),
                        LatLng(14.7560, -17.4680),
                      ],
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
    required List<LatLng> points,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.directions_transit, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$steps\nTarif estimé : $price'),
        trailing: Text(duration, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () {
                widget.onShowOnMap(points, title, color);
              },
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text('Voir l\'itinéraire sur la carte', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}

// --- ONGLET 3 : LISTE TOUS LES ARRÊTS ---

class AllStopsScreen extends StatefulWidget {
  final Function(TransitStop) onSelectStop;

  const AllStopsScreen({
    super.key,
    required this.onSelectStop,
  });

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
                  onTap: () {
                    widget.onSelectStop(stop);
                  },
                  leading: CircleAvatar(
                    backgroundColor: stop.color,
                    child: Icon(stop.icon, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Badge(
                        label: Text(stop.network),
                        backgroundColor: stop.color,
                      ),
                    ],
                  ),
                  subtitle: Text('${stop.direction}'),
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
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Signaler un bug / Retour utilisateur'),
            subtitle: const Text('Un problème sur l\'application ? Envoyez vos suggestions'),
            onTap: _showFeedbackDialog,
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

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer vos retours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Un avis, un arrêt non listé ou un bug ? Dites-le nous.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Votre message ici...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Merci pour votre retour précieux ! Notre équipe va l’examiner.'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
