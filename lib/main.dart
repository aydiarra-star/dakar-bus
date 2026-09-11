import 'package:flutter/material.dart';

void main() {
  runApp(const DakarMobeliteApp());
}

class DakarMobeliteApp extends StatelessWidget {
  const DakarMobeliteApp({super.key});

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
      home: const MapExplorerScreen(),
    );
  }
}

class DepartureInfo {
  final String stationName;
  final String lineInfo;
  final String timeRemaining;
  final String fare;
  final Color iconBgColor;
  final IconData icon;

  const DepartureInfo({
    required this.stationName,
    required this.lineInfo,
    required this.timeRemaining,
    required this.fare,
    required this.iconBgColor,
    required this.icon,
  });
}

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  int _selectedBottomNav = 0;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  final List<DepartureInfo> _departures = const [
    DepartureInfo(
      stationName: 'Gare TER Colobane',
      lineInfo: 'TER Ligne Express • Dir. Diamniadio / Thiaroye',
      timeRemaining: '6 min',
      fare: '500 FCFA',
      iconBgColor: Color(0xFFE53935),
      icon: Icons.directions_railway_filled,
    ),
    DepartureInfo(
      stationName: 'Station BRT Colobane (B1)',
      lineInfo: 'BRT Ligne B1 • Dir. Guédiawaye',
      timeRemaining: '4 min',
      fare: '400 FCFA',
      iconBgColor: Color(0xFF1E88E5),
      icon: Icons.directions_bus_filled,
    ),
    DepartureInfo(
      stationName: 'Arrêt AFTU Tata Ligne 12',
      lineInfo: 'AFTU Tata • Dir. Palais de Justice / Sandaga',
      timeRemaining: '2 min',
      fare: '200 FCFA',
      iconBgColor: Color(0xFFFB8C00),
      icon: Icons.directions_bus,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredList = _departures.where((dep) {
      final matchesSearch = dep.stationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          dep.lineInfo.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_selectedFilter == 'TER_BRT') {
        return matchesSearch && (dep.lineInfo.contains('TER') || dep.lineInfo.contains('BRT'));
      } else if (_selectedFilter == 'AFTU') {
        return matchesSearch && dep.lineInfo.contains('AFTU');
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Stack(
        children: [
          // Background Vector Map Rendering
          Positioned.fill(
            child: CustomPaint(
              painter: MapBackgroundPainter(),
            ),
          ),

          // Top Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                      onPressed: () {},
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Assistant IA : Où désirez-vous aller ?')),
                      );
                    },
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

          // Bottom Sheet UI
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.25,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Où voulez-vous aller ? (ex: Thiaroye, Al...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                          _buildFilterChip('AFTU Tata', 'AFTU'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Prochains départs autour de vous',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...filteredList.map((dep) => _buildDepartureCard(dep)),
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
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explorer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alt_route_outlined),
            activeIcon: Icon(Icons.alt_route),
            label: 'Trajets',
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
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFC8E6C9),
        backgroundColor: const Color(0xFFF0F0F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFF81C784) : Colors.grey.shade300,
          ),
        ),
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }

  Widget _buildDepartureCard(DepartureInfo dep) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: dep.iconBgColor,
            child: Icon(dep.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dep.stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  dep.lineInfo,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dep.timeRemaining,
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dep.fare,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE8ECEF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final waterPaint = Paint()..color = const Color(0xFFB3E5FC);
    final waterPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.35, 0, size.height * 0.5)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    final redLinePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final redPath = Path()
      ..moveTo(size.width * 0.9, size.height * 0.1)
      ..lineTo(size.width * 0.4, size.height * 0.45);
    canvas.drawPath(redPath, redLinePaint);

    final blueLinePaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final bluePath = Path()
      ..moveTo(size.width * 0.85, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.4, size.width * 0.3, size.height * 0.42);
    canvas.drawPath(bluePath, blueLinePaint);

    final nodePaint = Paint()..color = Colors.white;
    final nodeBorderPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final Offset node1 = Offset(size.width * 0.84, size.height * 0.14);
    final Offset node2 = Offset(size.width * 0.75, size.height * 0.20);
    final Offset node3 = Offset(size.width * 0.51, size.height * 0.37);

    for (var node in [node1, node2, node3]) {
      canvas.drawCircle(node, 6, nodePaint);
      canvas.drawCircle(node, 6, nodeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
