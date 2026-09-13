import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const DakarBusApp());
}

class DakarBusApp extends StatelessWidget {
  const DakarBusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Bus & Rail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

/// ===========================================================================
/// 1. COUCHE LOGIQUE : Service de détection des arrêts opposés (Sens A / Sens B)
/// ===========================================================================
class OppositeStopService {
  static Map<String, dynamic>? findOppositeStop({
    required Map<String, dynamic> currentStop,
    required List<Map<String, dynamic>> allStops,
  }) {
    if (currentStop.containsKey('parent_station') && currentStop['parent_station'] != null) {
      final parentId = currentStop['parent_station'];
      final match = allStops.firstWhere(
        (stop) => stop['parent_station'] == parentId && stop['id'] != currentStop['id'],
        orElse: () => {},
      );
      if (match.isNotEmpty) return match;
    }

    final double currentLat = currentStop['lat'];
    final double currentLon = currentStop['lon'];
    final String currentName = currentStop['name'].toString().toLowerCase();

    Map<String, dynamic>? bestCandidate;
    double minDistance = double.infinity;

    for (var stop in allStops) {
      if (stop['id'] == currentStop['id']) continue;

      final double lat = stop['lat'];
      final double lon = stop['lon'];
      final double distance = _calculateDistance(currentLat, currentLon, lat, lon);

      // Rayon de recherche de 50 mètres max (vis-à-vis rue / station BRT/TER)
      if (distance <= 0.05 && distance < minDistance) {
        final String stopName = stop['name'].toString().toLowerCase();
        if (_namesAreSimilar(currentName, stopName)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }

    return bestCandidate;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  static bool _namesAreSimilar(String name1, String name2) {
    if (name1.length < 3 || name2.length < 3) return name1 == name2;
    return name1.contains(name2) || name2.contains(name1);
  }
}

/// ===========================================================================
/// 2. ÉCRAN DE NAVIGATION PRINCIPAL
/// ===========================================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapPlaceholderScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Réglages'),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// 3. ÉCRAN ACCUEIL & RECHERCHE D'ARRÊTS (Intégration Double Sens)
/// ===========================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  // Exemple d'une base de données simulée d'arrêts (Bus, BRT, TER) à Dakar
  static final List<Map<String, dynamic>> mockStopsDatabase = [
    {
      "id": "stop_colobane_1",
      "name": "Colobane (Sens Aller - Centre-ville)",
      "lat": 14.6928,
      "lon": -17.4467,
      "parent_station": "station_colobane",
      "realtime_passages": [
        {"line": "BRT 1", "destination": "Pout", "time": "À quai"},
        {"line": "Bus 14", "destination": "Grand Yoff", "time": "3 min"},
        {"line": "TER", "destination": "Dakar", "time": "7 min"}
      ]
    },
    {
      "id": "stop_colobane_2",
      "name": "Colobane (Sens Retour - Banlieue)",
      "lat": 14.6930,
      "lon": -17.4465,
      "parent_station": "station_colobane",
      "realtime_passages": [
        {"line": "BRT 1", "destination": "Guédiawaye", "time": "2 min"},
        {"line": "Bus 21", "destination": "Pikine", "time": "5 min"}
      ]
    },
    {
      "id": "stop_mermoz_1",
      "name": "Mermoz (Avenue Bourguiba)",
      "lat": 14.7082,
      "lon": -17.4623,
      "realtime_passages": [
        {"line": "Bus 7", "destination": "Ouakam", "time": "4 min"}
      ]
    },
    {
      "id": "stop_mermoz_2",
      "name": "Mermoz (Opposé)",
      "lat": 14.7084,
      "lon": -17.4621,
      "realtime_passages": [
        {"line": "Bus 7", "destination": "Plateau", "time": "1 min"}
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus - Recherche d\'Arrêts'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: mockStopsDatabase.length,
        itemBuilder: (context, index) {
          final stop = mockStopsDatabase[index];
          return ListTile(
            leading: const Icon(Icons.directions_bus, color: Colors.blue),
            title: Text(stop['name']),
            subtitle: Text('ID: ${stop['id']}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Ouverture de la vue détaillée avec gestion des deux sens
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DualStopViewScreen(
                    initialStop: stop,
                    allStopsDatabase: mockStopsDatabase,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ===========================================================================
/// 4. VUE DÉTAILLÉE DE L'ARRÊT (Double Section : Aller & Retour)
/// ===========================================================================
class DualStopViewScreen extends StatefulWidget {
  final Map<String, dynamic> initialStop;
  final List<Map<String, dynamic>> allStopsDatabase;

  const DualStopViewScreen({
    Key? key,
    required this.initialStop,
    required this.allStopsDatabase,
  }) : super(key: key);

  @override
  State<DualStopViewScreen> createState() => _DualStopViewScreenState();
}

class _DualStopViewScreenState extends State<DualStopViewScreen> {
  late Map<String, dynamic> sensA;
  Map<String, dynamic>? sensB;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    sensA = widget.initialStop;
    // Recherche automatique du sens opposé (Sens B)
    sensB = OppositeStopService.findOppositeStop(
      currentStop: sensA,
      allStops: widget.allStopsDatabase,
    );
    
    // Simulation du chargement temps réel
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(sensA['name'] ?? 'Arrêt'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                // --- SECTION 1 : ARRÊT ACTUEL (SENS ALLER) ---
                _buildDirectionSection(
                  title: "Sens Aller (Arrêt Actuel)",
                  stopData: sensA,
                  badgeColor: Colors.green,
                ),
                
                const SizedBox(height: 16),
                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // --- SECTION 2 : ARRÊT OPPOSÉ (SENS RETOUR) ---
                sensB != null
                    ? _buildDirectionSection(
                        title: "Sens Retour (Arrêt Opposé)",
                        stopData: sensB!,
                        badgeColor: Colors.orange,
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          "Aucun arrêt opposé détecté à proximité immédiate pour ce point.",
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildDirectionSection({
    required String title,
    required Map<String, dynamic> stopData,
    required Color badgeColor,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: badgeColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stopData['name'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildRealtimePassagesList(stopData),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimePassagesList(Map<String, dynamic> stop) {
    final passages = stop['realtime_passages'] as List<dynamic>? ?? [];

    if (passages.isEmpty) {
      return const Text("Aucun passage en temps réel disponible pour cet arrêt.");
    }

    return Column(
      children: passages.map((passage) {
        final timeStr = passage['time'].toString();
        final isImminent = timeStr.contains('min') || timeStr.contains('quai');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(passage['line'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: Colors.blueGrey,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Text("Vers ${passage['destination']}", style: const TextStyle(fontSize: 14)),
                ],
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isImminent ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// ===========================================================================
/// 5. ÉCRANS ANNEXES (Carte & Réglages conservés)
/// ===========================================================================
class MapPlaceholderScreen extends StatelessWidget {
  const MapPlaceholderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte interactive (TER / BRT / Bus)')),
      body: const Center(
        child: Text('Module FlutterMap / Itinéraires Actif', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages & Configuration')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.info),
            title: Text('Version de l\'application'),
            subtitle: Text('4.3 - Double sens IDFM style intégré'),
          ),
        ],
      ),
    );
  }
}
