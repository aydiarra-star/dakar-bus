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
      title: 'Dakar Bus',
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

class TransitStop {
  final String id;
  final String name;
  final String network; // TER, BRT, AFTU, DDD
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

  // Base de données complète des arrêts à Dakar
  final List<TransitStop> _allStops = [
    TransitStop(
      id: 'ter_colobane',
      name: 'Gare TER Colobane',
      network: 'TER',
      direction: 'Ligne Express • Dir. Diamniadio',
      point: const LatLng(14.6931, -17.4382),
      minutesRemaining: 5,
      color: const Color(0xFFE53935), // Rouge TER
      icon: Icons.directions_railway_filled,
    ),
    TransitStop(
      id: 'brt_colobane',
      name: 'Station BRT Colobane (B1)',
      network: 'BRT',
      direction: 'Ligne B1 • Dir. Guédiawaye',
      point: const LatLng(14.6960, -17.4395),
      minutesRemaining: 3,
      color: const Color(0xFF1E88E5), // Bleu BRT
      icon: Icons.directions_bus_filled,
    ),
    TransitStop(
      id: 'aftu_12',
      name: 'Arrêt AFTU Tata Ligne 12',
      network: 'AFTU',
      direction: 'Tata 12 • Dir. Palais de Justice / Sandaga',
      point: const LatLng(14.6850, -17.4420),
      minutesRemaining: 2,
      color: const Color(0xFFFB8C00), // Orange Tata
      icon: Icons.directions_bus,
    ),
    TransitStop(
      id: 'ddd_8',
      name: 'Arrêt Dakar Dem Dikk Ligne 8',
      network: 'DDD',
      direction: 'DDD Ligne 8 • Dir. Yoff / Sandaga',
      point: const LatLng(14.6780, -17.4350),
      minutesRemaining: 7,
      color: const Color(0xFF2E7D32), // Vert DDD
      icon: Icons.directions_bus_filled,
    ),
    TransitStop(
      id: 'brt_pikine',
      name: 'Station BRT Pikine',
      network: 'BRT',
      direction: 'Ligne B1 • Dir. Grand Médine',
      point: const LatLng(14.7528, -17.3917),
      minutesRemaining: 8,
      color: const Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
    ),
    TransitStop(
      id: 'ter_pikine',
      name: 'Gare TER Pikine',
      network: 'TER',
      direction: 'Ligne Express • Dir. Dakar Centre',
      point: const LatLng(14.7480, -17.3980),
      minutesRemaining: 12,
      color: const Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
    ),
    TransitStop(
      id: 'aftu_pikine',
      name: 'Arrêt AFTU Tata Pikine Rue 10',
      network: 'AFTU',
      direction: 'Tata 24 • Dir. Keur Massar',
      point: const LatLng(14.7580, -17.3850),
      minutesRemaining: 4,
      color: const Color(0xFFFB8C00),
      icon: Icons.directions_bus,
    ),
  ];

  // Tracés géographiques distincts par réseau (Polylines)
  final List<LatLng> _terRoute = const [
    LatLng(14.6700, -17.4330), // Dakar Gare
    LatLng(14.6931, -17.4382), // Colobane
    LatLng(14.7480, -17.3980), // Pikine
    LatLng(14.7890, -17.3120), // Rufisque
  ];

  final List<LatLng> _brtRoute = const [
    LatLng(14.6720, -17.4360), // Petersen
    LatLng(14.6960, -17.4395), // Colobane
    LatLng(14.7528, -17.3917), // Pikine
    LatLng(14.7710, -17.3970), // Guédiawaye
  ];

  final List<LatLng> _aftuRoute = const [
    LatLng(14.6650, -17.4380), // Sandaga
    LatLng(14.6850, -17.4420), // Colobane
    LatLng(14.7200, -17.4500), // Ouakam
    LatLng(14.7580, -17.3850), // Pikine Rue 10
  ];

  final List<LatLng> _dddRoute = const [
    LatLng(14.6680, -17.4320), // Palais
    LatLng(14.6780, -17.4350), // DDD Ligne 8
    LatLng(14.7300, -17.4600), // Ngor
    LatLng(14.7500, -17.4700), // Yoff
  ];

  @override
  void initState() {
    super.initState();
    // Horaires dynamiques en temps réel (décompte automatique)
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
  }

  @override
  void dispose() {
    _timer?.cancel();
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
          // Carte OpenStreetMap dynamique et fluide
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(14.7100, -17.4300),
              initialZoom: 12.5,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dakarbus.app',
              ),
              // Tracés des 4 modes de transport avec leurs couleurs distinctes
              PolylineLayer(
                polylines: [
                  Polyline(points: _terRoute, strokeWidth: 5.0, color: const Color(0xFFE53935)), // Rouge
                  Polyline(points: _brtRoute, strokeWidth: 5.0, color: const Color(0xFF1E88E5)), // Bleu
                  Polyline(points: _aftuRoute, strokeWidth: 4.0, color: const Color(0xFFFB8C00)), // Orange
                  Polyline(points: _dddRoute, strokeWidth: 4.0, color: const Color(0xFF2E7D32)), // Vert
                ],
              ),
              // Arrêts cliquables sur la carte
              MarkerLayer(
                markers: filteredStops.map((stop) {
                  return Marker(
                    point: stop.point,
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(stop.point, 15.0);
                        _showStopDetails(stop);
                      },
                      child: Tooltip(
                        message: stop.name,
                        child: CircleAvatar(
                          backgroundColor: stop.color,
                          child: Icon(stop.icon, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // En-tête : Recentrage & Assistant IA
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
                      _mapController.move(const LatLng(14.7100, -17.4300), 12.5);
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

          // Feuille coulissante
          DraggableScrollableSheet(
            initialChildSize: 0.45,
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
                          'Dakar Bus',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Temps réel Live',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Champ de recherche instantané
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher arrêt (Pikine, Sandaga, Colobane)...',
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

                    // Filtres de réseaux
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tous les réseaux', 'ALL'),
                          _buildFilterChip('TER & BRT', 'TER_BRT'),
                          _buildFilterChip('AFTU Tata', 'AFTU'),
                          _buildFilterChip('Dakar Dem Dikk', 'DDD'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Prochains départs en temps réel',
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

  // Assistant IA fonctionnel
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
                const Text('Où souhaitez-vous aller ? Tapez votre destination (ex: Pikine, Sandaga, Guédiawaye).'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Entrez votre destination...',
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
                        if (input.contains('pikine')) {
                          aiAnswer = 'Pour aller à Pikine :\n• Option 1 : BRT Ligne B1 (Direct, ~15 min)\n• Option 2 : TER depuis Colobane (Direct, ~10 min)';
                        } else if (input.contains('sandaga') || input.contains('centre')) {
                          aiAnswer = 'Pour aller au Centre-Ville / Sandaga :\n• Prenez le Bus AFTU Tata Ligne 12 ou Dakar Dem Dikk Ligne 8.';
                        } else if (input.contains('guediawaye') || input.contains('guédiawaye')) {
                          aiAnswer = 'Pour Guédiawaye :\n• Empruntez la Ligne BRT B1 express.';
                        } else {
                          aiAnswer = 'Itinéraire recommandé : Prendre la ligne BRT B1 ou TER selon l\'arrêt le plus proche.';
                        }
                      });
                    },
                    child: const Text('Calculer le meilleur trajet', style: TextStyle(color: Colors.white)),
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

  // Modale sans tarifs
  void _showStopDetails(TransitStop stop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(stop.icon, color: stop.color),
            const SizedBox(width: 8),
            Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réseau : ${stop.network}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Ligne : ${stop.direction}'),
            const SizedBox(height: 6),
            Text('Prochain passage : ${stop.minutesRemaining} min',
                style: TextStyle(color: stop.color, fontWeight: FontWeight.bold, fontSize: 15)),
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
          _mapController.move(stop.point, 15.0);
          _showStopDetails(stop);
        },
        leading: CircleAvatar(
          backgroundColor: stop.color,
          child: Icon(stop.icon, color: Colors.white, size: 20),
        ),
        title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(stop.direction, style: const TextStyle(fontSize: 11)),
        trailing: Text(
          '${stop.minutesRemaining} min',
          style: TextStyle(color: stop.color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
