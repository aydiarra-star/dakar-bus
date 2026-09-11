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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _stops = [
    {'name': 'Station BRT Petersen', 'type': 'BRT', 'dir': 'Dir. Guédiawaye', 'time': '2 min', 'color': Colors.blue},
    {'name': 'Gare TER Dakar', 'type': 'TER', 'dir': 'Dir. Diamniadio', 'time': '4 min', 'color': Colors.red},
    {'name': 'Terminus DDD Parcelles', 'type': 'DDD', 'dir': 'Ligne 6', 'time': '8 min', 'color': Colors.green},
    {'name': 'Arrêt AFTU Tata 24', 'type': 'AFTU', 'dir': 'Dir. Colobane', 'time': '3 min', 'color': Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredStops = _stops.where((stop) {
      final query = _searchQuery.toLowerCase();
      return stop['name'].toLowerCase().contains(query) ||
             stop['type'].toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher un arrêt ou une ligne (BRT, TER, Tata)...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredStops.length,
                itemBuilder: (context, index) {
                  final stop = filteredStops[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: stop['color'],
                        child: const Icon(Icons.directions_bus, color: Colors.white),
                      ),
                      title: Text(stop['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${stop['type']} • ${stop['dir']}'),
                      trailing: Text(stop['time'], style: TextStyle(color: stop['color'], fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF2E7D32),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Lignes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}
