import 'package:flutter/material.dart';

void main() {
  runApp(const DakarBusApp());
}

// ============================================================
// ETAT GLOBAL DE L'APPLICATION
// ============================================================
class GlobalState extends ChangeNotifier {
  bool _darkMode = false;
  bool get darkMode => _darkMode;

  void toggleDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }
}

final GlobalState globalState = GlobalState();

// ============================================================
// CONFIGURATION DES COULEURS ET THÈMES
// ============================================================
class AppColors {
  static const primary = Color(0xFF008037); // Vert drapeau / Transport
  static const secondary = Color(0xFFFCD116); // Jaune Sénégal
  static const ter = Color(0xFF8E44AD);
  static const brt = Color(0xFFE67E22);
  static const ddd = Color(0xFF2980B9);
  static const tata = Color(0xFFC0392B);
  static const aftu = Color(0xFF16A085);
  static const warning = Color(0xFFE74C3C);

  static Color background(bool dark) => dark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  static Color surface(bool dark) => dark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color textPrimary(bool dark) => dark ? Colors.white : const Color(0xFF2C3E50);
  static Color textSecondary(bool dark) => dark ? Colors.white70 : const Color(0xFF7F8C8D);
  static Color divider(bool dark) => dark ? Colors.white12 : const Color(0xFFE0E0E0);
}

// ============================================================
// MODELES DE DONNEES
// ============================================================
enum TransportSource { ter, brt, ddd, tata, aftu }

extension TransportSourceExt on TransportSource {
  String get label {
    switch (this) {
      case TransportSource.ter:
        return 'TER (Train Express Régional)';
      case TransportSource.brt:
        return 'SunuBRT (Bus Rapid Transit)';
      case TransportSource.ddd:
        return 'Dakar Dem Dikk';
      case TransportSource.tata:
        return 'Bus Tata';
      case TransportSource.aftu:
        return 'AFTU (Car Rapide / Minibus)';
    }
  }

  Color get color {
    switch (this) {
      case TransportSource.ter:
        return AppColors.ter;
      case TransportSource.brt:
        return AppColors.brt;
      case TransportSource.ddd:
        return AppColors.ddd;
      case TransportSource.tata:
        return AppColors.tata;
      case TransportSource.aftu:
        return AppColors.aftu;
    }
  }
}

class Stop {
  final String name;
  final String direction;
  final double distanceMeters;
  final List<int> departureMinutesFromMidnight;
  final IconData icon;
  final Color color;
  final String location;
  final String modeLabel;
  final TransportSource source;
  final bool isTerminal;

  const Stop({
    required this.name,
    required this.direction,
    required this.distanceMeters,
    required this.departureMinutesFromMidnight,
    required this.icon,
    required this.color,
    required this.location,
    required this.modeLabel,
    this.source = TransportSource.ddd,
    this.isTerminal = false,
  });

  String nextDepartureLabel() {
    if (departureMinutesFromMidnight.isEmpty) return 'Fréquence continue';
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    for (var m in departureMinutesFromMidnight) {
      if (m >= currentMinutes) {
        final diff = m - currentMinutes;
        return diff <= 0 ? 'À l\'approche' : 'Dans $diff min';
      }
    }
    return 'Terminé pour aujourd\'hui';
  }
}

class DetailedRoute {
  final String operator;
  final String lineNumber;
  final String origin;
  final String destination;
  final Color color;
  final String totalDistance;
  final List<StopDetailItem> stops;

  DetailedRoute({
    required this.operator,
    required this.lineNumber,
    required this.origin,
    required this.destination,
    required this.color,
    required this.totalDistance,
    required this.stops,
  });

  factory DetailedRoute.fromStop(Stop stop, {bool isReturnRoute = false}) {
    final orig = isReturnRoute ? stop.direction : stop.name;
    final dest = isReturnRoute ? stop.name : stop.direction;
    return DetailedRoute(
      operator: stop.modeLabel,
      lineNumber: stop.source == TransportSource.ter ? 'T1' : (stop.source == TransportSource.brt ? 'B1' : 'L12'),
      origin: orig,
      destination: dest,
      color: stop.color,
      totalDistance: '${(stop.distanceMeters + 3500) / 1000} km',
      stops: [
        StopDetailItem(name: orig, sequence: 1, type: 'Origine / Terminus', estimatedTime: '00:00', distanceFromStart: '0 km', isTerminal: true),
        StopDetailItem(name: 'Station Intermédiaire Colobane', sequence: 2, type: 'Correspondance', estimatedTime: '+12 min', distanceFromStart: '2.5 km'),
        StopDetailItem(name: 'Station Lycée Limamou Laye', sequence: 3, type: 'Arrêt Standard', estimatedTime: '+22 min', distanceFromStart: '5.1 km'),
        StopDetailItem(name: dest, sequence: 4, type: 'Terminus', estimatedTime: '+35 min', distanceFromStart: '8.4 km', isTerminal: true),
      ],
    );
  }
}

class StopDetailItem {
  final String name;
  final int sequence;
  final String type;
  final String estimatedTime;
  final String distanceFromStart;
  final bool isTerminal;

  StopDetailItem({
    required this.name,
    required this.sequence,
    required this.type,
    required this.estimatedTime,
    required this.distanceFromStart,
    this.isTerminal = false,
  });
}

// ============================================================
// DONNEES DE TEST & SERVICES UTILITAIRES
// ============================================================
const List<Stop> allStops = [
  Stop(
    name: 'Gare de Dakar',
    direction: 'Diamniadio',
    distanceMeters: 250,
    departureMinutesFromMidnight: [360, 390, 420, 450, 480, 510, 540, 600, 660, 720, 780, 840, 900, 960, 1020, 1080],
    icon: Icons.train,
    color: AppColors.ter,
    location: 'Plateau, Dakar',
    modeLabel: 'TER Dakar',
    source: TransportSource.ter,
    isTerminal: true,
  ),
  Stop(
    name: 'Guédiawaye (Préfecture)',
    direction: 'Terminus BHC / Petersen',
    distanceMeters: 600,
    departureMinutesFromMidnight: [370, 375, 385, 400, 415, 430, 450, 480, 520, 560, 600, 650, 700, 750, 800, 850, 900],
    icon: Icons.directions_bus_filled,
    color: AppColors.brt,
    location: 'Guédiawaye',
    modeLabel: 'SunuBRT',
    source: TransportSource.brt,
    isTerminal: true,
  ),
  Stop(
    name: 'Université Cheikh Anta Diop (UCAD)',
    direction: 'Centre-Ville / Sandaga',
    distanceMeters: 900,
    departureMinutesFromMidnight: [380, 395, 410, 425, 440, 460, 490, 530, 570, 610, 660, 710, 760, 810, 860, 910],
    icon: Icons.directions_bus,
    color: AppColors.ddd,
    location: 'Avenue Cheikh Anta Diop',
    modeLabel: 'Dakar Dem Dikk',
    source: TransportSource.ddd,
  ),
  Stop(
    name: 'Parcelles Assainies (Unité 15)',
    direction: 'Colobane / Liberté 6',
    distanceMeters: 1200,
    departureMinutesFromMidnight: [],
    icon: Icons.airport_shuttle,
    color: AppColors.tata,
    location: 'Parcelles Assainies',
    modeLabel: 'Bus Tata - Ligne 21',
    source: TransportSource.tata,
  ),
  Stop(
    name: 'Grand Yoff (Lycée John F. Kennedy)',
    direction: 'Pikine / Thiaroye',
    distanceMeters: 1500,
    departureMinutesFromMidnight: [],
    icon: Icons.directions_bus,
    color: AppColors.aftu,
    location: 'Grand Yoff',
    modeLabel: 'AFTU Minibus',
    source: TransportSource.aftu,
  ),
];

class OppositeStopService {
  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    for (var stop in allStops) {
      if (stop.name != currentStop.name && stop.source == currentStop.source) {
        return stop;
      }
    }
    return allStops.isNotEmpty ? allStops.first : null;
  }
}

class TimeHelper {
  static String getCrowdLevel(Stop stop) {
    final hour = DateTime.now().hour;
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 20)) {
      return 'Forte affluence (Heure de pointe)';
    } else if (hour >= 11 && hour <= 15) {
      return 'Modérée';
    }
    return 'Fluide';
  }
}

// ============================================================
// APPLICATION PRINCIPALE & NAVIGATION
// ============================================================
class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Dakar Bus Official',
          debugShowCheckedModeBanner: false,
          themeMode: globalState.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark),
          ),
          home: const MainNavigationShell(),
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    AlertsPage(),
    CommunityAlertsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppColors.surface(dark),
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_bus), label: 'Trajets'),
          NavigationDestination(icon: Icon(Icons.notifications_active), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.forum), label: 'Direct Rue'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Réglages'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.black,
        tooltip: 'Assistant IA',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage())),
        child: const Icon(Icons.smart_toy),
      ),
    );
  }
}

// ============================================================
// PAGE D'ACCUEIL & RECHERCHE INTERACTIVE
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = '';
  TransportSource? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    final filteredStops = allStops.where((stop) {
      final matchesQuery = stop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stop.modeLabel.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == null || stop.source == _selectedFilter;
      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.directions_transit, color: AppColors.secondary),
            SizedBox(width: 10),
            Text('Dakar Bus & Multimodal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une station, un quartier (Ex: Colobane)...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Tous', null),
                      _filterChip('TER', TransportSource.ter),
                      _filterChip('SunuBRT', TransportSource.brt),
                      _filterChip('DDD', TransportSource.ddd),
                      _filterChip('Tata', TransportSource.tata),
                      _filterChip('AFTU', TransportSource.aftu),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredStops.isEmpty
                ? Center(
                    child: Text('Aucune station trouvée', style: TextStyle(color: AppColors.textSecondary(dark))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredStops.length,
                    itemBuilder: (context, index) {
                      final stop = filteredStops[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface(dark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider(dark)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: stop.color,
                            child: Icon(stop.icon, color: Colors.white, size: 20),
                          ),
                          title: Text(stop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary(dark))),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Direction : ${stop.direction}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                              const SizedBox(height: 2),
                              Text('Prochain : ${stop.nextDepartureLabel()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stop.color)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop)),
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

  Widget _filterChip(String label, TransportSource? source) {
    final isSelected = _selectedFilter == source;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedFilter = selected ? source : null),
        selectedColor: AppColors.secondary,
        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
        backgroundColor: Colors.white.withOpacity(0.2),
      ),
    );
  }
}

// ============================================================
// PAGE DETAIL D'UNE ROUTE OFFICIELLE
// ============================================================
class DetailedRoutePage extends StatelessWidget {
  final DetailedRoute route;
  const DetailedRoutePage({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          appBar: AppBar(
            title: Text('${route.operator} (L${route.lineNumber})'),
            backgroundColor: route.color,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Inverser le sens',
                onPressed: () {
                  final inverted = DetailedRoute.fromStop(
                    Stop(
                      name: route.origin,
                      direction: route.destination,
                      distanceMeters: 0,
                      departureMinutesFromMidnight: [],
                      icon: Icons.directions_bus,
                      color: route.color,
                      location: route.stops.first.name,
                      modeLabel: route.operator,
                    ),
                    isReturnRoute: true,
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => DetailedRoutePage(route: inverted)),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface(dark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider(dark)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.route, color: route.color, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${route.origin} ➔ ${route.destination}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.divider(dark)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Distance totale : ${route.totalDistance}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                        Text('${route.stops.length} arrêts desservis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: route.color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Liste des stations et arrêts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 12),
              ...route.stops.asMap().entries.map((entry) {
                final idx = entry.key;
                final stop = entry.value;
                final isLast = idx == route.stops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: stop.isTerminal ? route.color : AppColors.surface(dark),
                              shape: BoxShape.circle,
                              border: Border.all(color: route.color, width: 3),
                            ),
                          ),
                          if (!isLast) Expanded(child: Container(width: 3, color: route.color.withOpacity(0.5))),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface(dark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider(dark)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(stop.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                                      const SizedBox(height: 2),
                                      Text('Séquence ${stop.sequence} • ${stop.type}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(stop.estimatedTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: route.color)),
                                    Text(stop.distanceFromStart, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// PAGES SECONDAIRES (DETAIL ARRET, ALERTES, REGLAGES, IA)
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final opposite = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);
    final dark = globalState.darkMode;

    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface(dark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(dark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: stop.color, radius: 20, child: Icon(stop.icon, color: Colors.white, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                          Text(stop.direction, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.divider(dark)),
                const SizedBox(height: 8),
                Text('Prochain passage : ${stop.nextDepartureLabel()}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: stop.color)),
                const SizedBox(height: 4),
                Text('Affluence estimée : ${TimeHelper.getCrowdLevel(stop)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 4),
                Text('Source officielle : ${stop.source.label}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
              ],
            ),
          ),
          if (opposite != null) ...[
            const SizedBox(height: 20),
            Text('Arrêt opposé (Sens retour)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(dark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider(dark)),
              ),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: opposite.color, child: Icon(opposite.icon, color: Colors.white, size: 18)),
                title: Text(opposite.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                subtitle: Text(opposite.direction, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                trailing: Text(opposite.nextDepartureLabel(), style: TextStyle(fontWeight: FontWeight.bold, color: opposite.color)),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: opposite))),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: stop.color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailedRoutePage(route: DetailedRoute.fromStop(stop)))),
            icon: const Icon(Icons.map),
            label: const Text('Voir l\'itinéraire complet et les correspondances'),
          ),
        ],
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: const Text('Alertes Trafic Officielles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _alertCard('TER', 'Trafic normal sur l\'ensemble de la ligne Dakar - Diamniadio.', 'Il y a 10 min', AppColors.ter, dark),
          _alertCard('SunuBRT', 'Fluidité parfaite entre Guédiawaye et Petersen.', 'Il y a 30 min', AppColors.brt, dark),
          _alertCard('Dakar Dem Dikk', 'Renforcement des dessertes universitaires (UCAD).', 'Il y a 1 heure', AppColors.ddd, dark),
        ],
      ),
    );
  }

  Widget _alertCard(String title, String desc, String time, Color color, bool dark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider(dark))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
            const Spacer(),
            Text(time, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
          ]),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(fontSize: 14, color: AppColors.textPrimary(dark))),
        ],
      ),
    );
  }
}

class CommunityAlertsPage extends StatelessWidget {
  const CommunityAlertsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: const Text('Direct Rue (Communauté)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider(dark))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text('Ralentissement à Colobane', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 6),
                const Text('Embouteillage important au niveau du rond-point suite à un camion en panne. Prévoyez 10 min de plus.'),
                const SizedBox(height: 8),
                Text('Signalé par un utilisateur • Il y a 5 min', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: const Text('Réglages & Préférences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text('Mode Sombre (Dark Mode)', style: TextStyle(color: AppColors.textPrimary(dark), fontWeight: FontWeight.bold)),
            subtitle: Text('Basculer entre le thème clair et sombre', style: TextStyle(color: AppColors.textSecondary(dark), fontSize: 12)),
            value: dark,
            activeColor: AppColors.primary,
            onChanged: (val) => globalState.toggleDarkMode(val),
          ),
          Divider(color: AppColors.divider(dark)),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primary),
            title: Text('À propos de Dakar Bus', style: TextStyle(color: AppColors.textPrimary(dark), fontWeight: FontWeight.bold)),
            subtitle: Text('Version 2.5.0 - Multimodal officiel Dakar', style: TextStyle(color: AppColors.textSecondary(dark), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'content': 'Bonjour ! Je suis votre assistant IA spécialisé dans les transports à Dakar (TER, BRT, DDD, TATA, AFTU). Comment puis-je vous aider ?'}
  ];

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _ctrl.clear();
      _messages.add({
        'role': 'ai',
        'content': 'Je traite votre demande concernant "$text". Pour aller plus vite, utilisez l\'onglet "Trajets" ou consultez directement les stations sur la carte interactive !'
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: const Text('Assistant IA Dakar Bus')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface(dark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isUser ? AppColors.primary : AppColors.divider(dark)),
                    ),
                    child: Text(
                      m['content']!,
                      style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary(dark), fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface(dark),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: AppColors.textPrimary(dark)),
                    decoration: const InputDecoration(hintText: 'Posez votre question sur les transports...', border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
