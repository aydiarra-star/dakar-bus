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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Coordonnées de Dakar (Centre)
  final LatLng _dakarCenter = const LatLng(14.6937, -17.4441);

  // Liste des arrêts de démonstration
  final List<Map<String, dynamic>> _busStops = [
    {'name': 'Place de l\'Indépendance', 'location': const LatLng(14.6685, -17.4338)},
    {'name': 'Gare Routière Beaux Maraîchers', 'location': const LatLng(14.7311, -17.3912)},
    {'name': 'UCAD - Université', 'location': const LatLng(14.6892, -17.4661)},
    {'name': 'Monument de la Renaissance', 'location': const LatLng(14.7225, -17.4948)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _dakarCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dakar_bus',
          ),
          MarkerLayer(
            markers: _busStops.map((stop) {
              return Marker(
                point: stop['location'] as LatLng,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Arrêt : ${stop['name']}')),
                    );
                  },
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
