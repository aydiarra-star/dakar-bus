import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const DakarBusApp());
}

class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Mobilité',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
      ),
      home: const MainMapScreen(),
    );
  }
}

// --- MODÈLES DE DONNÉES ---

enum RealtimeStatus { realtime, scheduled, estimated, disrupted }

class TransitStop {
  final String id;
  final String name;
  final String network; // TER, BRT, AFTU, DDD
  final String direction;
  final LatLng point;
  int minutesRemaining;
  final Color color;
  final IconData icon;
  final RealtimeStatus status;

  TransitStop({
    required this.id,
    required this.name,
    required this.network,
    required this.direction,
    required this.point,
    required this.minutesRemaining,
    required this.color,
    required this.icon,
    this.status = RealtimeStatus.realtime,
  });
}

// Modèle pour un véhicule en mouvement live
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

// --- ÉCRAN PRINCIPAL ---

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final MapController _mapController = MapController();
  int _selectedBottomNav = 0;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  Timer? _timer;

  // Véhicules en temps réel sur la carte
  List<LiveVehicle> _liveVehicles = [];
  StreamSubscription<List<LiveVehicle>>? _vehicleSubscription;

  // Tracés exacts des réseaux (Polylines)
  final List<LatLng> _terRoute = const [
    LatLng(14.6678, -17.4332), // Dakar
    LatLng(14.7170, -17.4310), // Hann
    LatLng(14.7525, -17.4012), // Pikine
    LatLng(14.7644, -17.3751), // Thiaroye
    LatLng(14.7132, -17.2718), // Rufisque
    LatLng(14.6974, -17.2023), // Diamniadio
  ];

  final List<LatLng> _brtRoute = const [
    LatLng(14.6785, -17.4398), // Petersen
    LatLng(14.6865, -17.4435), // De Gaulle
    LatLng(14.6925, -17.4475), // Colobane Obélisque
    LatLng(14.6995, -17.4520), // Dial Diop
    LatLng(14.7212, -17.4618), // Liberté 6
    LatLng(14.7350, -17.4550), // Grand Yoff
    LatLng(14.7455, -17.4462), // Patte d'Oie
    LatLng(14.7738, -17.3975), // Guédiawaye
  ];

  final List<LatLng> _dddRoute = const [
    LatLng(14.6680, -17.4320),
    LatLng(14.7230, -17.4860),
    LatLng(14.7560, -17.4680),
    LatLng(14.7455, -17.4462),
    LatLng(14.6974, -17.2023),
    LatLng(14.7833, -16.9333),
  ];

  final List<LatLng> _aftuRoute = const [
    LatLng(14.6785, -17.4398),
    LatLng(14.7580, -17.3850),
    LatLng(14.7780, -17.3110),
    LatLng(14.7880, -16.9250),
  ];

  // Base de données des arrêts
  final List<TransitStop> _allStops = [
    // TER
    TransitStop(
      id: 'ter_dakar',
      name: 'Gare TER Dakar (Place des Tirailleurs)',
      network: 'TER',
      direction: 'Ligne Express • Dir. Diamniadio',
      point: const LatLng(14.6678, -17.4332),
      minutesRemaining: 4,
      color: const Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
      status: RealtimeStatus.realtime,
    ),
    TransitStop(
      id: 'ter_pikine',
      name: 'Gare TER Pikine',
      network: 'TER',
      direction: 'Ligne Express • Dir. Diamniadio',
      point: const LatLng(14.7525, -17.4012),
      minutesRemaining: 12,
      color: const Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
      status: RealtimeStatus.realtime,
    ),
    TransitStop(
      id: 'ter_diamniadio',
      name: 'Gare TER Diamniadio',
      network: 'TER',
      direction: 'Ligne Express • Terminus',
      point: const LatLng(14.6974, -17.2023),
      minutesRemaining: 30,
      color: const Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
      status: RealtimeStatus.scheduled,
    ),

    // BRT
    TransitStop(
      id: 'brt_petersen',
      name: 'Station BRT Petersen',
      network: 'BRT',
      direction: 'Ligne B1 • Dir. Guédiawaye',
      point: const LatLng(14.6785, -17.4398),
      minutesRemaining: 2,
      color: const Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
      status: RealtimeStatus.realtime,
    ),
    TransitStop(
      id: 'brt_colobane',
      name: 'Station BRT Obélisque (Colobane)',
      network: 'BRT',
      direction: 'Ligne B1 • Dir. Guédiawaye',
      point: const LatLng(14.6925, -17.4475),
      minutesRemaining: 8,
      color: const Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
      status: RealtimeStatus.realtime,
    ),
    TransitStop(
      id: 'brt_guediawaye',
      name: 'Station BRT Préfecture de Guédiawaye',
      network: 'BRT',
      direction: 'Ligne B1 • Terminus',
      point: const LatLng(14.7738, -17.3975),
      minutesRemaining: 28,
      color: const Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
      status: RealtimeStatus.realtime,
    ),

    // DDD & AFTU
    TransitStop(
      id: 'ddd_interurbain_thies',
      name: 'Gare Interurbaine DDD Thiès',
      network: 'DDD',
      direction: 'Ligne Express • Dir. Dakar Centre',
      point: const LatLng(14.7833, -16.9333),
      minutesRemaining: 15,
      color: const Color(0xFF2E7D32),
      icon: Icons.directions_bus_filled,
      status: RealtimeStatus.estimated,
    ),
    TransitStop(
      id: 'aftu_keur_massar',
      name: 'Arrêt AFTU Tata Keur Massar',
      network: 'AFTU',
      direction: 'Tata 24 • Dir. Colobane',
      point: const LatLng(14.7780, -17.3110),
      minutesRemaining: 5,
      color: const Color(0xFFFB8C00),
      icon: Icons.directions_bus,
      status: RealtimeStatus.realtime,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Défaire le décompte automatique
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() {
        for (var stop in _allStops) {
          if (stop.minutesRemaining > 1) {
            stop.minutesRemaining--;
          } else {
            stop.minutesRemaining = 10;
          }
        }
      });
    });

    // Lancement de la réception GPS Live des véhicules
    _vehicleSubscription = _getLiveVehiclesStream().listen((vehicles) {
      setState(() {
        _liveVehicles = vehicles;
      });
    });
  }

  // Générateur dynamique de positions GPS des bus et trains
  Stream<List<LiveVehicle>> _getLiveVehiclesStream() async* {
    int step = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      step++;

      // Calcul des mouvements fluides le long des tracés
      final brtPos = _brtRoute[step % _brtRoute.length];
      final terPos = _terRoute[step % _terRoute.length];
      final aftuPos = _aftuRoute[step % _aftuRoute.length];

      yield [
        LiveVehicle(
          id: 'brt_bus_101',
          lineName: 'BRT B1 Express',
          currentPosition: brtPos,
          heading: 45.0,
          color: const Color(0xFF1E88E5),
          icon: Icons.directions_bus_filled,
        ),
        LiveVehicle(
          id: 'ter_train_01',
          lineName: 'TER Express Diamniadio',
          currentPosition: terPos,
          heading: 90.0,
          color: const Color(0xFFE53935),
          icon: Icons.directions_railway_filled,
        ),
        LiveVehicle(
          id: 'aftu_tata_24',
          lineName: 'Tata 24 Keur Massar',
          currentPosition: aftuPos,
          heading: 120.0,
          color: const Color(0xFFFB8C00),
          icon: Icons.directions_bus,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStops = _allStops.where((stop) {
      final matchesSearch = stop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.direction.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.network.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedFilter == 'TER_BRT') {
        return matchesSearch && (stop.network == 'TER' || stop.network == 'BRT');
      } else if (_selectedFilter == 'AFTU') {
        return matchesSearch && stop.network == 'AFTU';
      } else if (_selectedFilter == 'DDD') {
        return matchesSearch && stop.network == 'DDD';
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Carte interactive
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(14.7100, -17.4100),
              initialZoom: 11.8,
              minZoom: 8,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dakarmobilite.app',
              ),
              // Lines
              PolylineLayer(
                polylines: [
                  Polyline(points: _terRoute, strokeWidth: 5.5, color: const Color(0xFFE53935)),
                  Polyline(points: _brtRoute, strokeWidth: 5.5, color: const Color(0xFF1E88E5)),
                  Polyline(points: _dddRoute, strokeWidth: 3.5, color: const Color(0xFF2E7D32)),
                  Polyline(points: _aftuRoute, strokeWidth: 3.5, color: const Color(0xFFFB8C00)),
                ],
              ),
              // Arrêts fixés
              MarkerLayer(
                markers: filteredStops.map((stop) {
                  return Marker(
                    point: stop.point,
                    width: 38,
                    height: 38,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(stop.point, 14.5);
                        _showStopDetails(stop);
                      },
                      child: CircleAvatar(
                        backgroundColor: stop.color,
                        child: Icon(stop.icon, color: Colors.white, size: 18),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // VÉHICULES EN TEMPS RÉEL (Live GPS Markers)
              MarkerLayer(
                markers: _liveVehicles.map((vehicle) {
                  return Marker(
                    point: vehicle.currentPosition,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${vehicle.lineName} • Suivi GPS Live Actif'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: vehicle.color, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                        ),
                        child: Icon(vehicle.icon, color: vehicle.color, size: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // En-tête
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'recenter_btn',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.move(const LatLng(14.7100, -17.4100), 11.8);
                    },
                    child: const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openAIAssistant,
                    icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                    label: const Text(
                      'Assistant IA',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panneau bas
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.18,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, color: Color(0xFF2E7D32), size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          'Dakar Mobilité',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.sensors, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'GPS LIVE',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un arrêt (Pikine, Petersen, Thiès)...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
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
                    const Text(
                      'Prochains passages à proximité',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (filteredStops.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('Aucun arrêt trouvé.')),
                      )
                    else
                      ...filteredStops.map((stop) => _buildStopTile(stop)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomNav,
        onTap: (index) => setState(() => _selectedBottomNav = index),
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Trajets'),
        ],
      ),
    );
  }

  void _openAIAssistant() {
    final controller = TextEditingController();
    String? aiAnswer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    const Text('Assistant IA Transport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Où souhaitez-vous vous rendre ?'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Destination (ex: Guédiawaye, Thiès)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    onPressed: () {
                      final input = controller.text.trim().toLowerCase();
                      setModalState(() {
                        if (input.contains('thies') || input.contains('thiès')) {
                          aiAnswer = 'Pour Thiès :\n• Prenez le bus interurbain Dakar Dem Dikk ou une ligne AFTU.';
                        } else if (input.contains('guediawaye') || input.contains('guédiawaye')) {
                          aiAnswer = 'Pour Guédiawaye :\n• Empruntez le BRT B1 depuis Petersen (suivi GPS en direct).';
                        } else {
                          aiAnswer = 'Itinéraire conseillé : Combinez le TER pour la banlieue et le BRT en centre-ville.';
                        }
                      });
                    },
                    child: const Text('Calculer le trajet', style: TextStyle(color: Colors.white)),
                  ),
                ),
                if (aiAnswer != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Text(aiAnswer!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStopDetails(TransitStop stop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(stop.icon, color: stop.color),
            const SizedBox(width: 8),
            Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 15))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réseau : ${stop.network}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Direction : ${stop.direction}'),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Arrivée estimée : ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${stop.minutesRemaining} min', style: TextStyle(color: stop.color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
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
        label: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF1B5E20) : Colors.black87)),
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
      color: const Color(0xFFFAFAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          _mapController.move(stop.point, 14.5);
          _showStopDetails(stop);
        },
        leading: CircleAvatar(
          backgroundColor: stop.color,
          child: Icon(stop.icon, color: Colors.white, size: 20),
        ),
        title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        subtitle: Text(stop.direction, style: const TextStyle(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: stop.color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${stop.minutesRemaining} min',
            style: TextStyle(color: stop.color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
