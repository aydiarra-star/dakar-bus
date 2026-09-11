import 'package:flutter/material.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
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
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Lignes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}

// --- ONGLET 1 : CARTE & ARRÊTS ---

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _allStops = [
    {
      'id': 'brt_1',
      'name': 'Station BRT Petersen',
      'type': 'BRT',
      'dir': 'Dir. Guédiawaye',
      'time': '2 min',
      'color': const Color(0xFF1E88E5),
      'icon': Icons.directions_bus,
    },
    {
      'id': 'ter_1',
      'name': 'Gare TER Dakar',
      'type': 'TER',
      'dir': 'Dir. Diamniadio',
      'time': '4 min',
      'color': const Color(0xFFE53935),
      'icon': Icons.train,
    },
    {
      'id': 'ddd_1',
      'name': 'Terminus DDD Parcelles',
      'type': 'DDD',
      'dir': 'Ligne 6',
      'time': '8 min',
      'color': const Color(0xFF2E7D32),
      'icon': Icons.directions_bus,
    },
    {
      'id': 'aftu_1',
      'name': 'Arrêt AFTU Tata 24',
      'type': 'AFTU',
      'dir': 'Dir. Colobane',
      'time': '3 min',
      'color': const Color(0xFFFB8C00),
      'icon': Icons.directions_transit,
    },
    {
      'id': 'brt_2',
      'name': 'Station BRT Grand Yoff',
      'type': 'BRT',
      'dir': 'Dir. Petersen',
      'time': '6 min',
      'color': const Color(0xFF1E88E5),
      'icon': Icons.directions_bus,
    },
    {
      'id': 'aftu_2',
      'name': 'Arrêt AFTU Tata 38',
      'type': 'AFTU',
      'dir': 'Dir. Marché HLM',
      'time': '5 min',
      'color': const Color(0xFFFB8C00),
      'icon': Icons.directions_transit,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredStops = _allStops.where((stop) {
      final matchesSearch = stop['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop['type'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop['dir'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedFilter == 'TER_BRT') {
        return matchesSearch && (stop['type'] == 'TER' || stop['type'] == 'BRT');
      }
      if (_selectedFilter == 'DDD') return matchesSearch && stop['type'] == 'DDD';
      if (_selectedFilter == 'AFTU') return matchesSearch && stop['type'] == 'AFTU';
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            onPressed: _showAIAssistant,
            tooltip: 'Assistant IA',
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulation Visuelle Carte Dakar
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 40, color: Color(0xFF2E7D32)),
                      const SizedBox(height: 4),
                      Text(
                        'Réseau actif : BRT • TER • DDD • Tata',
                        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Text(
                        '📍 Presqu\'île de Dakar (Temps Réel)',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'map_btn',
                    backgroundColor: const Color(0xFF2E7D32),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Position actualisée sur Dakar')),
                      );
                    },
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Barres de Recherche & Filtres
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un arrêt ou une ligne (BRT, TER...)...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', 'ALL'),
                      _buildFilterChip('TER & BRT', 'TER_BRT'),
                      _buildFilterChip('Dakar Dem Dikk', 'DDD'),
                      _buildFilterChip('AFTU Tata', 'AFTU'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des Arrêts
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filteredStops.length,
              itemBuilder: (context, index) {
                final stop = filteredStops[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: stop['color'],
                      child: Icon(stop['icon'], color: Colors.white, size: 20),
                    ),
                    title: Text(stop['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${stop['type']} • ${stop['dir']}', style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      stop['time'],
                      style: TextStyle(color: stop['color'], fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String id) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
        selected: isSelected,
        selectedColor: const Color(0xFF2E7D32),
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }

  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text('Assistant Smart Dakar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('💡 Recommandation du moment : Le BRT B1 est plus fluide que la VDN à cette heure-ci.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris', style: TextStyle(color: Colors.white)),
              ),
            ),
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
  final TextEditingController _startController = TextEditingController(text: 'Ma position');
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
                labelText: 'Destination (ex: Petersen, Guédiawaye)',
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
                onPressed: () => setState(() => _hasSearched = true),
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text('Trouver un trajet', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            if (_hasSearched)
              Expanded(
                child: ListView(
                  children: const [
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Color(0xFF1E88E5), child: Icon(Icons.directions_bus, color: Colors.white)),
                        title: Text('BRT B1 + Tata 24', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Petersen ➔ Guédiawaye • Tarif : 300 FCFA'),
                        trailing: Text('25 min', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Color(0xFFE53935), child: Icon(Icons.train, color: Colors.white)),
                        title: Text('TER Express', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Gare Dakar ➔ Diamniadio • Tarif : 500 FCFA'),
                        trailing: Text('18 min', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
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
}

// --- ONGLET 3 : PARAMÈTRES ---

class SettingsScreen extends StatelessWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

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
            subtitle: const Text('Activer le thème sombre'),
            value: isDarkMode,
            onChanged: onThemeChanged,
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos de Dakar Bus'),
            subtitle: const Text('Version 1.0.0 • Suivi en temps réel'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Dakar Bus',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Dakar Bus',
              );
            },
          ),
        ],
      ),
    );
  }
}
