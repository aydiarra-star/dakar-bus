import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const DakarMobilityApp());
}

class DakarMobilityApp extends StatelessWidget {
  const DakarMobilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Mobilité',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class BusStop {
  final String id;
  final String name;
  final LatLng location;
  final List<String> lines;

  BusStop({
    required this.id,
    required this.name,
    required this.location,
    required this.lines,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng dakarCenter = const LatLng(14.6698, -17.4381);
  final LatLng userLocation = const LatLng(14.6650, -17.4350);

  final List<BusStop> busStops = [
    BusStop(
      id: '1',
      name: 'Place de l\'Indépendance',
      location: const LatLng(14.6698, -17.4381),
      lines: ['Ligne 1', 'Ligne 10', 'BRT'],
    ),
    BusStop(
      id: '2',
      name: 'Gare Routière Petersen',
      location: const LatLng(14.6780, -17.4410),
      lines: ['Ligne 2', 'Ligne 6', 'Dem Dikk'],
    ),
    BusStop(
      id: '3',
      name: 'UCAD - Université',
      location: const LatLng(14.6885, -17.4660),
      lines: ['Ligne 1', 'Ligne 7', 'Ligne 14'],
    ),
    BusStop(
      id: '4',
      name: 'Grand Yoff - Marché',
      location: const LatLng(14.7300, -17.4500),
      lines: ['Ligne 8', 'Ligne 12'],
    ),
  ];

  String getStopEstimatedDistance(LatLng userPos, LatLng stopPos) {
    const Distance distance = Distance();
    final double meters = distance.as(LengthUnit.Meter, userPos, stopPos);

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  void _showStopDetails(BusStop stop) {
    final String dist = getStopEstimatedDistance(userLocation, stop.location);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Color(0xFF1B5E20), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stop.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.navigation, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Distance estimée : $dist',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Lignes disponibles :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: stop.lines.map((line) {
                  return Chip(
                    label: Text(line),
                    backgroundColor: Colors.green.shade100,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Mobilité'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: dakarCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dakar.mobility',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              ...busStops.map((stop) {
                return Marker(
                  point: stop.location,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showStopDetails(stop),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
