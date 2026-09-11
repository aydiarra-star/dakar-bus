import 'package:flutter/material.dart';

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

// Modèle de données enrichi
class TransitStop {
  final String id;
  final String name;
  final String network; // TER, BRT, AFTU, DDD
  final String direction;
  final String fare;
  final String timeRemaining;
  final Color color;
  final IconData icon;

  const TransitStop({
    required this.id,
    required this.name,
    required this.network,
    required this.direction,
    required this.fare,
    required this.timeRemaining,
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
  int _selectedBottomNav = 0;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  TransitStop? _selectedStopOnMap;

  // Base de données complète des réseaux : TER, BRT, AFTU, Dakar Dem Dikk
  final List<TransitStop> _allStops = const [
    TransitStop(
      id: 'ter_1',
      name: 'Gare TER Colobane',
      network: 'TER',
      direction: 'Ligne Express • Dir. Diamniadio',
      fare: '500 FCFA',
      timeRemaining: '6 min',
      color: Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
    ),
    TransitStop(
      id: 'brt_1',
      name: 'Station BRT Colobane (B1)',
      network: 'BRT',
      direction: 'Ligne B1 • Dir. Guédiawaye',
      fare: '400 FCFA',
      timeRemaining: '4 min',
      color: Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
    ),
    TransitStop(
      id: 'aftu_12',
      name: 'Arrêt AFTU Tata Ligne 12',
      network: 'AFTU',
      direction: 'Tata Ligne 12 • Dir. Palais de Justice',
      fare: '200 FCFA',
      timeRemaining: '2 min',
      color: Color(0xFFFB8C00),
      icon: Icons.directions_bus,
    ),
    TransitStop(
      id: 'ddd_8',
      name: 'Arrêt Dakar Dem Dikk Ligne 8',
      network: 'DDD',
      direction: 'DDD Ligne 8 • Dir. Aéroport Yoff / Sandaga',
      fare: '175 FCFA',
      timeRemaining: '8 min',
      color: Color(0xFF2E7D32),
      icon: Icons.directions_bus_filled,
    ),
  ];

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
          // Carte interactive avec sélection directe des arrêts
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.0,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFE8ECEF)),
                  // Tracés interactifs sur la carte
                  CustomPaint(
                    size: Size.infinite,
                    painter: InteractiveMapPainter(),
                  ),
                  // Marqueurs d'arrêts cliquables sur la carte
                  ...filteredStops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    final topPos = 120.0 + (index * 80.0);
                    final leftPos = 80.0 + (index * 60.0);

                    return Positioned(
                      top: topPos,
                      left: leftPos,
                      child: GestureDetector(
                        onTap: () => _showStopDetails(stop),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: stop.color,
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(stop.icon, color: Colors.white, size: 20),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                              ),
                              child: Text(
                                stop.name,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Boutons du haut (Géolocalisation & Assistant IA)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'location_btn',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Géolocalisation en cours...')),
                      );
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
                      backgroundColor: const Color(0xFF4CAF50),
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panneau coulissant interactif
          DraggableScrollableSheet(
            initialChildSize: 0.50,
            minChildSize: 0.20,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
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

                    // Champ de recherche dynamique
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher arrêt, lieu, TER, BRT, Tata...',
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

                    // Filtres par réseau
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
                      'Prochains départs autour de vous',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Liste interactive
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
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explorer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alt_route),
            label: 'Trajets',
          ),
        ],
      ),
    );
  }

  // Modale Assistant IA interactive
  void _openAIAssistant() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
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
                const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                const Text('Assistant IA Transport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Où souhaitez-vous aller ? Posez votre question en langage naturel (ex: "Comment aller de Pikine à Sandaga ?")'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Posez votre question...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                onPressed: () {
                  final text = controller.text;
                  Navigator.pop(ctx);
                  if (text.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('IA : Calcul de l\'itinéraire pour "$text"...')),
                    );
                  }
                },
                child: const Text('Calculer l\'itinéraire', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modale de détails lorsqu'on clique sur un arrêt
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
            const SizedBox(height: 4),
            Text('Ligne : ${stop.direction}'),
            const SizedBox(height: 4),
            Text('Tarif : ${stop.fare}'),
            const SizedBox(height: 4),
            Text('Arrivée estimée : ${stop.timeRemaining}', style: TextStyle(color: stop.color, fontWeight: FontWeight.bold)),
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
        onTap: () => _showStopDetails(stop),
        leading: CircleAvatar(
          backgroundColor: stop.color,
          child: Icon(stop.icon, color: Colors.white, size: 20),
        ),
        title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(stop.direction, style: const TextStyle(fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(stop.timeRemaining, style: TextStyle(color: stop.color, fontWeight: FontWeight.bold)),
            Text(stop.fare, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// Dessin interactif de la carte
class InteractiveMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final redLine = Paint()..color = const Color(0xFFE53935)..strokeWidth = 6..style = PaintingStyle.stroke;
    final blueLine = Paint()..color = const Color(0xFF1E88E5)..strokeWidth = 6..style = PaintingStyle.stroke;
    final greenLine = Paint()..color = const Color(0xFF2E7D32)..strokeWidth = 6..style = PaintingStyle.stroke;

    final path1 = Path()..moveTo(50, 100)..lineTo(300, 400);
    final path2 = Path()..moveTo(80, 200)..quadraticBezierTo(200, 250, 350, 300);

    canvas.drawPath(path1, redLine);
    canvas.drawPath(path2, blueLine);
    canvas.drawPath(path1, greenLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
