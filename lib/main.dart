import 'package:flutter/material.dart';

enum DataTrust { verified, crowdsourced, estimated }

class Operator {
  final String id;
  final String name;
  final Color color;

  const Operator({
    required this.id,
    required this.name,
    required this.color,
  });
}

class BusStop {
  final String id;
  final String name;
  final String locality;

  const BusStop({
    required this.id,
    required this.name,
    required this.locality,
  });
}

class TransportRoute {
  final String id;
  final String lineNumber;
  final Operator operator;
  final String origin;
  final String destination;
  final List<BusStop> stops;
  final DataTrust trustLevel;

  const TransportRoute({
    required this.id,
    required this.lineNumber,
    required this.operator,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.trustLevel,
  });
}

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
        ),
        useMaterial3: true,
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
  String _searchQuery = '';
  String _selectedOperatorId = 'ALL';

  static const opDDD = Operator(id: 'DDD', name: 'Dakar Dem Dikk', color: Color(0xFF1B5E20));
  static const opAFTU = Operator(id: 'AFTU', name: 'AFTU (Tata)', color: Color(0xFFE65100));
  static const opBRT = Operator(id: 'BRT', name: 'SunuBRT', color: Color(0xFF0D47A1));

  final List<TransportRoute> _routes = const [
    TransportRoute(
      id: 'r1',
      lineNumber: 'Ligne 1',
      operator: opBRT,
      origin: 'Gare Petersen',
      destination: 'Parcelles Assainies',
      trustLevel: DataTrust.verified,
      stops: [
        BusStop(id: 's1', name: 'Gare Petersen', locality: 'Dakar Plateau'),
        BusStop(id: 's2', name: 'Grand Médina', locality: 'Médina'),
        BusStop(id: 's3', name: 'Parcelles Assainies Unit 10', locality: 'Parcelles Assainies'),
      ],
    ),
    TransportRoute(
      id: 'r2',
      lineNumber: 'Ligne 12',
      operator: opAFTU,
      origin: 'Guédiawaye',
      destination: 'Palais de Justice',
      trustLevel: DataTrust.crowdsourced,
      stops: [
        BusStop(id: 's4', name: 'Terminus Guédiawaye', locality: 'Guédiawaye'),
        BusStop(id: 's5', name: ' HLM 5', locality: 'HLM'),
        BusStop(id: 's6', name: 'Palais de Justice', locality: 'Rebeuss'),
      ],
    ),
    TransportRoute(
      id: 'r3',
      lineNumber: 'Ligne 8',
      operator: opDDD,
      origin: 'Aéroport Yoff',
      destination: 'Sandaga',
      trustLevel: DataTrust.verified,
      stops: [
        BusStop(id: 's7', name: 'Aéroport Yoff', locality: 'Yoff'),
        BusStop(id: 's8', name: 'UCAD', locality: 'Fann'),
        BusStop(id: 's9', name: 'Marché Sandaga', locality: 'Dakar Plateau'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRoutes = _routes.where((route) {
      final matchesSearch = route.lineNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          route.origin.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          route.destination.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesOp = _selectedOperatorId == 'ALL' || route.operator.id == _selectedOperatorId;
      return matchesSearch && matchesOp;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher une ligne, un arrêt...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('Tous', 'ALL'),
                _buildFilterChip('SunuBRT', 'BRT'),
                _buildFilterChip('AFTU', 'AFTU'),
                _buildFilterChip('Dakar Dem Dikk', 'DDD'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredRoutes.length,
              itemBuilder: (context, index) {
                final route = filteredRoutes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: route.operator.color,
                      child: const Icon(Icons.directions_bus, color: Colors.white),
                    ),
                    title: Row(
                      children: [
                        Text(route.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        _buildTrustBadge(route.trustLevel),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('${route.origin} ➔ ${route.destination}'),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)),
                      );
                    },
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
    final isSelected = _selectedOperatorId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedOperatorId = id),
      ),
    );
  }

  Widget _buildTrustBadge(DataTrust trust) {
    String text;
    Color color;
    switch (trust) {
      case DataTrust.verified:
        text = 'Vérifié';
        color = Colors.green;
        break;
      case DataTrust.crowdsourced:
        text = 'Communautaire';
        color = Colors.orange;
        break;
      case DataTrust.estimated:
        text = 'Estimé';
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class RouteDetailScreen extends StatelessWidget {
  final TransportRoute route;
  const RouteDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${route.lineNumber} - ${route.operator.name}'),
        backgroundColor: route.operator.color,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: route.stops.length,
        itemBuilder: (context, index) {
          final stop = route.stops[index];
          return ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: route.operator.color),
                if (index < route.stops.length - 1)
                  Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
              ],
            ),
            title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(stop.locality),
          );
        },
      ),
    );
  }
}
