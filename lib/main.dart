import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const DakarBusApp());

// ============================================================
// GENERATEUR D HORAIRES OFFICIELS
// ============================================================
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) {
    list.add(m);
  }
  return list;
}

List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);

final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
final List<int> _terBase = _buildTerBase();

// ============================================================
// COULEURS (TER en Marron Vif exact)
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFF8D4004); // Marron vif pour le TER et ses rails
  static const aftu = Color(0xFFEF6C00);
  static const tata = Color(0xFF7B1FA2);
  static const ddd = Color(0xFF0288D1);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFEEEEEE);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const neutral = Color(0xFF9E9E9E);
}

// ============================================================
// SERVICE DE DETECTION DES DEUX SENS (ALLER / RETOUR)
// ============================================================
class OppositeStopService {
  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    for (final stop in allStops) {
      if (stop.name.toLowerCase() == currentStop.name.toLowerCase() &&
          stop.direction != currentStop.direction &&
          stop.modeLabel == currentStop.modeLabel) {
        return stop;
      }
    }
    return allStops.firstWhere(
      (s) => s.modeLabel == currentStop.modeLabel && s.direction != currentStop.direction,
      orElse: () => currentStop,
    );
  }
}

// ============================================================
// MODELES
// ============================================================
enum DataStatus { scheduled, live, unknown }

class Stop {
  final String name;
  final String direction;
  final double distanceMeters;
  final List<int> departureMinutesFromMidnight;
  final IconData icon;
  final Color color;
  final LatLng location;
  final DataStatus status;
  final String modeLabel;

  const Stop({
    required this.name,
    required this.direction,
    required this.distanceMeters,
    required this.departureMinutesFromMidnight,
    required this.icon,
    required this.color,
    required this.location,
    required this.modeLabel,
    this.status = DataStatus.scheduled,
  });

  int? nextDepartureMinutes() {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d > currentMin) return d;
    }
    if (departureMinutesFromMidnight.isNotEmpty) return departureMinutesFromMidnight.first + 24 * 60;
    return null;
  }

  int? remainingMinutes() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final now = DateTime.now();
    return d - (now.hour * 60 + now.minute);
  }
}

class TransitRoute {
  final String name;
  final String code;
  final String type;
  final Color color;
  final List<LatLng> points;

  const TransitRoute({required this.name, required this.code, required this.type, required this.color, required this.points});
}

class FavoriteRoute {
  final String label;
  final String from;
  final String to;
  final IconData icon;
  const FavoriteRoute({required this.label, required this.from, required this.to, required this.icon});
}

class TrafficAlert {
  final String title;
  final String description;
  final String time;
  final Color color;
  const TrafficAlert({required this.title, required this.description, required this.time, required this.color});
}

// ============================================================
// DONNEES DE TOUS LES ARRETTS ET TRACES
// ============================================================
final List<Stop> allStops = [
  // Gare TER Dakar
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER'),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER'),
  
  // Gare TER Colobane
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER'),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Dakar', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6935, -17.4443), modeLabel: 'TER'),

  // Gare TER Hann
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7222, -17.4321), modeLabel: 'TER'),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Dakar', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 7), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7220, -17.4323), modeLabel: 'TER'),

  // BRT
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT'),
  Stop(name: 'BRT Colobane', direction: 'Dir. Petersen', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 4), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6952, -17.4422), modeLabel: 'BRT'),

  // Bus AFTU, Tata, DDD
  const Stop(name: 'Arret AFTU 23', direction: 'Dir. Parcelles Assainies', distanceMeters: 280, departureMinutesFromMidnight: [630, 645, 700, 715], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460), modeLabel: 'AFTU'),
  const Stop(name: 'Arret Tata 12', direction: 'Dir. Guediawaye', distanceMeters: 600, departureMinutesFromMidnight: [640, 655, 710, 725], icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700), modeLabel: 'Tata'),
  const Stop(name: 'Arret DDD 12', direction: 'Dir. Ouakam', distanceMeters: 800, departureMinutesFromMidnight: [645, 700, 715, 730], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900), modeLabel: 'DDD'),
];

final List<Stop> mapPriorityStops = allStops;

// Tracés complets de toutes les lignes sur la carte
final List<TransitRoute> demoRoutes = [
  TransitRoute(
    name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter,
    points: [
      const LatLng(14.6792, -17.4407), const LatLng(14.6937, -17.4441),
      const LatLng(14.7222, -17.4321), const LatLng(14.7410, -17.4120),
      const LatLng(14.7550, -17.3900), const LatLng(14.7700, -17.3400),
      const LatLng(14.7750, -17.3100), const LatLng(14.7160, -17.1986),
    ],
  ),
  TransitRoute(
    name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt,
    points: [
      const LatLng(14.6720, -17.4400), const LatLng(14.6950, -17.4420),
      const LatLng(14.7050, -17.4400), const LatLng(14.7350, -17.4260),
      const LatLng(14.7735, -17.3977),
    ],
  ),
  TransitRoute(
    name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu,
    points: [const LatLng(14.7600, -17.4400), const LatLng(14.6900, -17.4460)],
  ),
  TransitRoute(
    name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata,
    points: [const LatLng(14.7735, -17.3977), const LatLng(14.6750, -17.4400)],
  ),
  TransitRoute(
    name: 'DDD', code: 'DDD', type: 'DDD', color: AppColors.ddd,
    points: [const LatLng(14.7350, -17.5100), const LatLng(14.6800, -17.4450)],
  ),
];

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }
}

// ============================================================
// APPLICATION PRINCIPALE
// ============================================================
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ExplorerPage(),
      const TripsPage(),
      const AlertsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
          NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: 'Trajets'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Reglages'),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE EXPLORER (Avec tracés, filtres et temps d'attente)
// ============================================================
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';

  List<Stop> get _filteredStops {
    if (_selectedFilter == 'Tous') return allStops;
    return allStops.where((s) => s.modeLabel.toUpperCase() == _selectedFilter.toUpperCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text('Dakar Bus & Rail', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage())),
                  ),
                ],
              ),
            ),
            // CARTE INTERACTIVE AVEC TOUS LES TRACES ET MARQUEURS
            SizedBox(
              height: 230,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _dakarCenter, initialZoom: 11),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      PolylineLayer(
                        polylines: demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 4)).toList(),
                      ),
                      MarkerLayer(
                        markers: mapPriorityStops.map((s) => Marker(
                          point: s.location,
                          width: 24,
                          height: 24,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))),
                            child: Container(
                              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: Icon(s.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _legendItem(AppColors.ter, 'TER'),
                          _legendItem(AppColors.brt, 'BRT'),
                          _legendItem(AppColors.aftu, 'AFTU'),
                          _legendItem(AppColors.tata, 'Tata'),
                          _legendItem(AppColors.ddd, 'DDD'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // FILTRES HORIZONTAUX
            Container(
              height: 45,
              color: Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: ['Tous', 'TER', 'BRT', 'AFTU', 'Tata', 'DDD'].map((f) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontSize: 12, color: _selectedFilter == f ? Colors.white : AppColors.textPrimary)),
                    selected: _selectedFilter == f,
                    selectedColor: AppColors.primary,
                    onSelected: (val) => setState(() => _selectedFilter = f),
                  ),
                )).toList(),
              ),
            ),
            // LISTE DES ARRETS AVEC TEMPS D'ATTENTE EN DIRECT
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final stop = stops[index];
                  final remaining = stop.remainingMinutes() ?? 3;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                                child: Icon(stop.icon, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stop.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('${stop.modeLabel} . ${stop.direction}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$remaining min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                                  const Text('d attente', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ============================================================
// VUE DOUBLE SENS (ALLER / RETOUR) AVEC HEURES ET EMBARQUEMENT
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final Stop? oppositeStop = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(stop.name),
        backgroundColor: stop.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDirectionSection(
            title: "Embarquement / Départ (Sens Actuel)",
            currentStop: stop,
            badgeColor: Colors.green,
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 20),
          oppositeStop != null
              ? _buildDirectionSection(
                  title: "Arrivée / Terminus & Sens Opposé",
                  currentStop: oppositeStop,
                  badgeColor: Colors.orange,
                )
              : const Text("Aucun arrêt opposé enregistré.", textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDirectionSection({required String title, required Stop currentStop, required Color badgeColor}) {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final future = currentStop.departureMinutesFromMidnight.where((d) => d > currentMin).take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: badgeColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: badgeColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(currentStop.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Réseau : ${currentStop.modeLabel} | ${currentStop.direction}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          const Text('Heures de passage & Temps estimé :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (future.isEmpty)
            const Text('Plus de départ prévu aujourd hui.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            ...future.map((d) {
              final normalized = d % (24 * 60);
              final h = (normalized ~/ 60).toString().padLeft(2, '0');
              final m = (normalized % 60).toString().padLeft(2, '0');
              final remaining = d - currentMin;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$h:$m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    Text('$remaining min d attente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: remaining <= 3 ? AppColors.ter : AppColors.success)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE TRAJETS (PLANIFICATEUR INTERACTIF)
// ============================================================
class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final TextEditingController _fromCtrl = TextEditingController(text: 'Gare TER Dakar');
  final TextEditingController _toCtrl = TextEditingController(text: 'Gare TER Diamniadio');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planificateur de Trajets'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'Départ', prefixIcon: Icon(Icons.my_location))),
            const SizedBox(height: 12),
            TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'Destination', prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recherche d itinéraire en cours... TER Marron Vif opérationnel')),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Calculer l itinéraire'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PAGE ALERTES (INFORMATIONS TRAFIC)
// ============================================================
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const alerts = [
      TrafficAlert(title: 'TER Normal', description: 'Toutes les lignes TER circulent normalement (fréquence 10 min).', time: 'En direct', color: AppColors.success),
      TrafficAlert(title: 'BRT Fluide', description: 'Trafic régulier sur l ensemble du couloir BRT.', time: 'Il y a 5 min', color: AppColors.brt),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes et Trafic'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (ctx, i) {
          final a = alerts[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Icons.notifications_active, color: a.color),
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(a.description),
              trailing: Text(a.time, style: TextStyle(fontSize: 11, color: a.color, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// PAGE REGLAGES (PARAMETRES)
// ============================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres et Réglages'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.language), title: Text('Langue'), subtitle: Text('Français')),
          Divider(),
          ListTile(leading: Icon(Icons.notifications), title: Text('Notifications trafic'), subtitle: Text('Activées')),
          Divider(),
          ListTile(leading: Icon(Icons.info), title: Text('Version de l application'), subtitle: Text('Dakar Bus v2.4.0 (Officiel)')),
        ],
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': 'Bonjour ! Je suis votre assistant IA Dakar Bus. Posez vos questions sur les horaires TER (Marron Vif), BRT, AFTU, Tata ou DDD.'
    }
  ];

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _ctrl.clear();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add({'sender': 'ai', 'text': 'Je peux vous renseigner sur tous les réseaux de transport à Dakar !'});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA Dakar Bus'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final isUser = m['sender'] == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(m['text'] ?? '', style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Posez votre question...', border: InputBorder.none),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
