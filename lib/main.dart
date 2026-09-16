import 'package:flutter/material.dart';

// ============================================================
// ETAT GLOBAL DE L'APPLICATION (Dark Mode, Favoris, etc.)
// ============================================================
class GlobalState extends ChangeNotifier {
  bool _darkMode = false;
  final List<String> _favorites = [];

  bool get darkMode => _darkMode;
  List<String> get favorites => _favorites;

  void toggleDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }

  void toggleFavorite(String stopName) {
    if (_favorites.contains(stopName)) {
      _favorites.remove(stopName);
    } else {
      _favorites.add(stopName);
    }
    notifyListeners();
  }

  bool isFavorite(String stopName) => _favorites.contains(stopName);
}

final GlobalState globalState = GlobalState();

// ============================================================
// PALETTE DE COULEURS ADAPTATIVE (Clair / Sombre)
// ============================================================
class AppColors {
  static const primary = Color(0xFF10B981); // Vert principal Dakar Bus
  static const ter = Color(0xFF8B4513);     // Marron TER
  static const brt = Color(0xFF3B82F6);     // Bleu BRT
  static const ddd = Color(0xFFEF4444);     // Rouge DDD
  static const tata = Color(0xFFF59E0B);    // Orange TATA / AFTU

  static Color background(bool dark) => dark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
  static Color surface(bool dark) => dark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color textPrimary(bool dark) => dark ? Colors.white : const Color(0xFF0F172A);
  static Color textSecondary(bool dark) => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color divider(bool dark) => dark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E8F0);
}

// ============================================================
// MODELES DE DONNEES
// ============================================================
enum TransportSource { ter, brt, ddd, tata, aftu }

extension TransportSourceExt on TransportSource {
  String get label {
    switch (this) {
      case TransportSource.ter: return 'TER Dakar';
      case TransportSource.brt: return 'SunuBRT';
      case TransportSource.ddd: return 'Dakar Dem Dikk';
      case TransportSource.tata: return 'AFTU / TATA';
      case TransportSource.aftu: return 'AFTU';
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
  final Offset location; // Coordonnées simulées pour la carte
  final String modeLabel;
  final TransportSource source;

  Stop({
    required this.name,
    required this.direction,
    required this.distanceMeters,
    required this.departureMinutesFromMidnight,
    required this.icon,
    required this.color,
    required this.location,
    required this.modeLabel,
    required this.source,
  });
}

class DetailedRoute {
  final String operator;
  final String lineNumber;
  final String origin;
  final String destination;
  final Color color;
  final String totalDistance;
  final List<RouteStop> stops;

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
    final orig = isReturnRoute ? stop.direction : 'Gare Colobane';
    final dest = isReturnRoute ? 'Gare Colobane' : stop.direction;
    return DetailedRoute(
      operator: stop.modeLabel,
      lineNumber: '14',
      origin: orig,
      destination: dest,
      color: stop.color,
      totalDistance: '12.5 km',
      stops: [
        RouteStop(name: orig, distanceFromStart: '0 km', estimatedTime: '0 min', type: 'Départ', isTerminal: true),
        RouteStop(name: 'Sandaga / Pompidou', distanceFromStart: '3.2 km', estimatedTime: '10 min', type: 'Correspondance', isTerminal: false),
        RouteStop(name: 'Gare Routière', distanceFromStart: '7.8 km', estimatedTime: '22 min', type: 'Passage', isTerminal: false),
        RouteStop(name: dest, distanceFromStart: '12.5 km', estimatedTime: '35 min', type: 'Terminus', isTerminal: true),
      ],
    );
  }
}

class RouteStop {
  final String name;
  final String distanceFromStart;
  final String estimatedTime;
  final String type;
  final bool isTerminal;

  RouteStop({required this.name, required this.distanceFromStart, required this.estimatedTime, required this.type, required this.isTerminal});
}

// ============================================================
// DONNEES MOCKÉES (24 arrêts officiels Dakar)
// ============================================================
final List<Stop> allStops = [
  Stop(
    name: 'Gare TER Dakar',
    direction: 'Terminus Dakar (Arrivée)',
    distanceMeters: 350,
    departureMinutesFromMidnight: [360, 390, 420, 450, 480, 510, 540],
    icon: Icons.train,
    color: AppColors.ter,
    location: const Offset(120, 150),
    modeLabel: 'TER',
    source: TransportSource.ter,
  ),
  Stop(
    name: 'Colobane BRT',
    direction: 'Guédiawaye / Dalifort',
    distanceMeters: 650,
    departureMinutesFromMidnight: [365, 375, 385, 400],
    icon: Icons.directions_bus,
    color: AppColors.brt,
    location: const Offset(150, 200),
    modeLabel: 'BRT',
    source: TransportSource.brt,
  ),
  Stop(
    name: 'Sandaga AFTU',
    direction: 'Parcelles Assainies U22',
    distanceMeters: 900,
    departureMinutesFromMidnight: [370, 390, 410],
    icon: Icons.group,
    color: AppColors.tata,
    location: const Offset(100, 180),
    modeLabel: 'AFTU',
    source: TransportSource.tata,
  ),
  Stop(
    name: 'Grand Yoff TATA',
    direction: 'Terminus Liberté 5',
    distanceMeters: 1200,
    departureMinutesFromMidnight: [380, 410, 440],
    icon: Icons.directions_bus,
    color: AppColors.tata,
    location: const Offset(80, 100),
    modeLabel: 'TATA',
    source: TransportSource.tata,
  ),
  Stop(
    name: 'Hann Maristes DDD',
    direction: 'Pikine Icotaf',
    distanceMeters: 1500,
    departureMinutesFromMidnight: [360, 400, 450],
    icon: Icons.directions_bus,
    color: AppColors.ddd,
    location: const Offset(200, 160),
    modeLabel: 'DDD',
    source: TransportSource.ddd,
  ),
  // Génération complémentaire pour atteindre 24 arrêts
  ...List.generate(19, (index) {
    const modes = ['TER', 'BRT', 'DDD', 'TATA', 'AFTU'];
    const colors = [AppColors.ter, AppColors.brt, AppColors.ddd, AppColors.tata, AppColors.tata];
    const sources = [TransportSource.ter, TransportSource.brt, TransportSource.ddd, TransportSource.tata, TransportSource.aftu];
    final mIndex = index % 5;
    return Stop(
      name: 'Station Dakar ${index + 6}',
      direction: 'Direction Nord / Banlieue ${index + 1}',
      distanceMeters: 1800.0 + (index * 120),
      departureMinutesFromMidnight: [360 + (index * 15)],
      icon: mIndex == 0 ? Icons.train : Icons.directions_bus,
      color: colors[mIndex],
      location: Offset(50.0 + (index * 15) % 250, 50.0 + (index * 20) % 250),
      modeLabel: modes[mIndex],
      source: sources[mIndex],
    );
  }),
];

// ============================================================
// SERVICE GESTION SENS OPPOSE
// ============================================================
class OppositeStopService {
  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    for (var s in allStops) {
      if (s.name != currentStop.name && s.modeLabel == currentStop.modeLabel) {
        return s;
      }
    }
    return null;
  }
}

// ============================================================
// UTILITAIRES TEMPS & AFFLUENCE
// ============================================================
class TimeHelper {
  static String getWaitTimeFormatted(Stop stop) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    for (var dep in stop.departureMinutesFromMidnight) {
      if (dep >= currentMinutes) {
        final diff = dep - currentMinutes;
        if (diff == 0) return 'Immédiat';
        return '$diff min';
      }
    }
    return '5 min';
  }

  static String getCrowdLevel(Stop stop) {
    final now = DateTime.now();
    if ((now.hour >= 7 && now.hour <= 9) || (now.hour >= 17 && now.hour <= 20)) {
      return 'Forte affluence ⚠️';
    }
    return 'Fluide 🟢';
  }
}

// ============================================================
// POINT D'ENTREE DE L'APPLICATION
// ============================================================
void main() {
  runApp(const DakarBusApp());
}

class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Dakar Bus',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: globalState.darkMode ? Brightness.dark : Brightness.light,
            colorSchemeSeed: AppColors.primary,
          ),
          home: const MainNavigationShell(),
        );
      },
    );
  }
}

// ============================================================
// SHELL DE NAVIGATION PRINCIPAL (5 ONGLETS)
// ============================================================
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ExplorerPage(),
    AlertsPage(), // Remplacé ici par l'onglet Trafic
    CommunityAlertsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      body: _pages[_currentIndex < _pages.length ? _currentIndex : 0],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 3 ? 0 : _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface(dark),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary(dark),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Trajets'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Direct rue'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Réglages'),
        ],
      ),
    );
  }
}

// ============================================================
// ONGLET EXPLORER (CARTE REDUITE + LISTE DES 24 ARRETS)
// ============================================================
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  String _selectedFilter = 'Tous';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;

        // Filtrage des arrêts
        final filteredStops = allStops.where((stop) {
          final matchesSearch = stop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              stop.direction.toLowerCase().contains(_searchQuery.toLowerCase());
          if (_selectedFilter == 'Tous') return matchesSearch;
          if (_selectedFilter == 'Favoris') return matchesSearch && globalState.isFavorite(stop.name);
          return matchesSearch && stop.modeLabel.toUpperCase() == _selectedFilter.toUpperCase();
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ============================================================
                // CARTE INTERACTIVE - HAUTEUR REDUITE ET PROPRE (env. 200px)
                // ============================================================
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      // Fond carte simulé avec style web/map
                      Container(
                        color: dark ? const Color(0xFF1A202C) : const Color(0xFFE2E8F0),
                        child: Stack(
                          children: [
                            // Lignes de transport fictives sur la carte
                            Center(
                              child: CustomPaint(
                                size: const Size(double.infinity, 200),
                                painter: MapLinesPainter(),
                              ),
                            ),
                            // Marqueurs sur la carte
                            ...allStops.take(6).map((stop) {
                              return Positioned(
                                left: stop.location.dx * 1.2,
                                top: stop.location.dy * 0.6,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop)));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: stop.color,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                                    ),
                                    child: Icon(stop.icon, color: Colors.white, size: 14),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      // Bouton Assistant IA Flottant sur la carte
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                          label: const Text('Assistant IA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // CONTENU PRINCIPAL SOUS LA CARTE
                // ============================================================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête titre application
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dakar Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                              Text('TER / BRT / DDD / TATA / AFTU', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Barre de recherche
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface(dark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider(dark)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(color: AppColors.textPrimary(dark), fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Où voulez-vous aller ? (ex: Colobane...)',
                            hintStyle: TextStyle(color: AppColors.textSecondary(dark), fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filtres horizontaux (Tous, Favoris, TER, BRT, DDD, TATA, AFTU)
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ['Tous', 'Favoris', 'TER', 'BRT', 'DDD', 'TATA', 'AFTU'].map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary(dark))),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface(dark),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.primary : AppColors.divider(dark))),
                                onSelected: (_) => setState(() => _selectedFilter = filter),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Compteur d'arrêts
                      Text(
                        '${filteredStops.length} arrêts à proximité',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)),
                      ),
                      const SizedBox(height: 10),

                      // Liste des arrêts
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredStops.length,
                        itemBuilder: (context, index) {
                          final stop = filteredStops[index];
                          final waitTime = TimeHelper.getWaitTimeFormatted(stop);
                          final isFav = globalState.isFavorite(stop.name);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface(dark),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider(dark)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop)));
                                },
                                onLongPress: () {
                                  globalState.toggleFavorite(stop.name);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(isFav ? '${stop.name} retiré des favoris' : '${stop.name} ajouté aux favoris ⭐'),
                                    duration: const Duration(seconds: 1),
                                  ));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: stop.color,
                                        radius: 20,
                                        child: Icon(stop.icon, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    stop.name,
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark)),
                                                  ),
                                                ),
                                                if (isFav) const Icon(Icons.star, size: 14, color: Colors.amber),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(stop.direction, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text('${stop.distanceMeters.toInt()} m', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
                                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                                Text(stop.modeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stop.color)),
                                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                                Text(TimeHelper.getCrowdLevel(stop), style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            waitTime,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('En direct', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                          ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Peintre personnalisé pour dessiner des lignes de transport fictives sur la mini-carte
class MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintTer = Paint()..color = AppColors.ter..strokeWidth = 3..style = PaintingStyle.stroke;
    final paintBrt = Paint()..color = AppColors.brt..strokeWidth = 3..style = PaintingStyle.stroke;

    final pathTer = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.8, size.width, size.height * 0.4);

    final pathBrt = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.8, size.height);

    canvas.drawPath(pathTer, paintTer);
    canvas.drawPath(pathBrt, paintBrt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// DETAIL D'UN ARRET & SENS OPPOSE (TER, BRT, TATA, AFTU, DDD)
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        final opposite = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);
        final isFav = globalState.isFavorite(stop.name);
        final detailedRoute = DetailedRoute.fromStop(stop);

        return Scaffold(
          backgroundColor: AppColors.background(dark),
          appBar: AppBar(
            backgroundColor: stop.color,
            foregroundColor: Colors.white,
            title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [
              IconButton(
                icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.white),
                onPressed: () {
                  globalState.toggleFavorite(stop.name);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isFav ? '${stop.name} retiré des favoris' : '${stop.name} ajouté aux favoris ⭐'),
                    duration: const Duration(seconds: 1),
                  ));
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: stop.color, radius: 22, child: Icon(stop.icon, color: Colors.white, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stop.modeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stop.color)),
                              const SizedBox(height: 2),
                              Text(stop.direction, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(dark))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Source officielle :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                        Text(stop.source.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Affluence estimée :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                        Text(TimeHelper.getCrowdLevel(stop), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailedRoutePage(route: detailedRoute)));
                },
                icon: const Icon(Icons.alt_route, size: 18),
                label: const Text('Voir le parcours complet et arrêts', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stop.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Text('Sens opposé / Retour suggéré', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 10),
              if (opposite != null)
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: opposite)));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface(dark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider(dark)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: stop.color, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opposite.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                              Text(opposite.direction, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider(dark)),
                  ),
                  child: Text('Aucun arrêt retour direct détecté à proximité.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// PAGE DETAIL DU PARCOURS COMPLET & INVERSION DE SENS
// ============================================================
class DetailedRoutePage extends StatefulWidget {
  final DetailedRoute route;
  const DetailedRoutePage({super.key, required this.route});

  @override
  State<DetailedRoutePage> createState() => _DetailedRoutePageState();
}

class _DetailedRoutePageState extends State<DetailedRoutePage> {
  late DetailedRoute _currentRoute;
  bool _isReturn = false;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route;
  }

  void _toggleDirection() {
    setState(() {
      _isReturn = !_isReturn;
      final dummyStop = Stop(
        name: _currentRoute.origin,
        direction: _currentRoute.destination,
        distanceMeters: 0,
        departureMinutesFromMidnight: [],
        icon: Icons.directions_bus,
        color: _currentRoute.color,
        location: _currentRoute.stops.first.location,
        modeLabel: _currentRoute.operator.contains('TER') ? 'TER' : (_currentRoute.operator.contains('BRT') ? 'BRT' : 'DDD'),
        source: TransportSource.ter,
      );
      _currentRoute = DetailedRoute.fromStop(dummyStop, isReturnRoute: _isReturn);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          appBar: AppBar(
            backgroundColor: _currentRoute.color,
            foregroundColor: Colors.white,
            title: Text('${_currentRoute.operator} (L${_currentRoute.lineNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Inverser le sens',
                onPressed: _toggleDirection,
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trip_origin, color: _currentRoute.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Départ : ${_currentRoute.origin}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(dark)))),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(height: 16, child: VerticalDivider(thickness: 2, color: Colors.grey)),
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: _currentRoute.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Arrivée : ${_currentRoute.destination}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(dark)))),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Distance totale :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                        Text(_currentRoute.totalDistance, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sens du parcours :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                        Text(_isReturn ? 'Retour / Inversé' : 'Aller / Direct', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _currentRoute.color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Liste des arrêts desservis (${_currentRoute.stops.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
              const SizedBox(height: 12),
              ..._currentRoute.stops.asMap().entries.map((entry) {
                final index = entry.key;
                final stop = entry.value;
                final isLast = index == _currentRoute.stops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: stop.isTerminal ? _currentRoute.color : AppColors.surface(dark),
                              shape: BoxShape.circle,
                              border: Border.all(color: _currentRoute.color, width: 3),
                            ),
                          ),
                          if (!isLast) Expanded(child: Container(width: 2, color: _currentRoute.color.withOpacity(0.4))),
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
                                      Text(stop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))),
                                      const SizedBox(height: 2),
                                      Text('Distance : ${stop.distanceFromStart} • Estimé : ${stop.estimatedTime}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _currentRoute.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(stop.type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _currentRoute.color)),
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
// ONGLET ALERTES TRAFIC EN TEMPS REEL
// ============================================================
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Alertes Trafic', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Informations en direct des réseaux de transport à Dakar.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),
                _alertCard(
                  title: 'TER - Trafic Fluide',
                  description: 'Les navettes entre Dakar et Diamniadio circulent normalement selon les horaires établis.',
                  time: 'Il y a 10 min',
                  color: AppColors.ter,
                  icon: Icons.train,
                  dark: dark,
                ),
                _alertCard(
                  title: 'SunuBRT - Travaux mineurs',
                  description: 'Léger ralentissement signalé aux abords de Colobane. Circulation régulée.',
                  time: 'Il y a 35 min',
                  color: AppColors.brt,
                  icon: Icons.directions_bus,
                  dark: dark,
                ),
                _alertCard(
                  title: 'AFTU / TATA - Heure de pointe',
                  description: 'Forte affluence sur les axes menant vers Petersen et Sandaga. Prévoyez un léger décalage.',
                  time: 'Il y a 1 h',
                  color: AppColors.aftu,
                  icon: Icons.group,
                  dark: dark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _alertCard({required String title, required String description, required String time, required Color color, required IconData icon, required bool dark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(dark)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary(dark)))),
                    Text(time, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ONGLET DIRECT RUE / COMMUNAUTE
// ============================================================
class CommunityAlertsPage extends StatelessWidget {
  const CommunityAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Direct Rue & Communauté', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Partagez ou consultez les signalements en temps réel des usagers.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(dark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider(dark)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.campaign_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text('Signaler un incident', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                      const SizedBox(height: 6),
                      Text('Embouteillage, bus plein, panne ou contrôle sur votre ligne ?', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé à la communauté !')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Faire un signalement rapide'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Derniers signalements usagers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 12),
                _communityPost('Mamadou S.', 'Route de l’Ouakam', 'Ralentissement important niveau rond-point suite à un accrochage.', 'Il y a 12 min', dark),
                _communityPost('Aminata D.', 'Gare Colobane', 'BRT direction Guédiawaye à l’heure, fluide.', 'Il y a 25 min', dark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _communityPost(String author, String location, String text, String time, bool dark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(dark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.2), radius: 14, child: Text(author[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
              const SizedBox(width: 8),
              Text(author, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(dark))),
              const Spacer(),
              Text(time, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))),
            ],
          ),
          const SizedBox(height: 8),
          Text('📍 $location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark), height: 1.3)),
        ],
      ),
    );
  }
}

// ============================================================
// ONGLET REGLAGES & PREFERENCES
// ============================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Réglages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Personnalisez votre application Dakar Bus.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(dark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider(dark)),
                  ),
                  child: SwitchListTile(
                    title: Text('Mode Sombre (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))),
                    subtitle: Text('Optimise l’affichage de nuit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                    secondary: const Icon(Icons.dark_mode_rounded, color: AppColors.primary),
                    value: dark,
                    activeColor: AppColors.primary,
                    onChanged: (val) => globalState.toggleDarkMode(val),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(dark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider(dark)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: AppColors.primary),
                        title: Text('À propos de Dakar Bus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))),
                        subtitle: Text('TER, BRT, DDD, TATA, AFTU (Version officielle 2026)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                        title: Text('Confidentialité & Données GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))),
                        subtitle: Text('Vos données de géolocalisation restent strictement locales', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// ASSISTANT IA (INTEGRE)
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'ai', 'text': 'Nànga def ! Je suis votre assistant intelligent pour les transports à Dakar. Comment puis-je vous aider à planifier votre trajet aujourd’hui ?'}
  ];

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _msgCtrl.clear();
      _messages.add({
        'sender': 'ai',
        'text': 'J’analyse votre demande concernant "$text". Les lignes TER, BRT et Tata fonctionnent normalement sur cet axe en ce moment.'
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Assistant IA Transport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface(dark),
                      borderRadius: BorderRadius.circular(14),
                      border: isUser ? null : Border.all(color: AppColors.divider(dark)),
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUser ? Colors.white : AppColors.textPrimary(dark),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: AppColors.surface(dark),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: TextStyle(color: AppColors.textPrimary(dark)),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question sur les bus...',
                      hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
