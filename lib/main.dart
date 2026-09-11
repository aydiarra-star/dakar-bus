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
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> routes = [
      {'name': 'BRT Ligne 1', 'desc': 'Gare Petersen <-> Parcelles Assainies', 'type': 'SunuBRT'},
      {'name': 'AFTU Ligne 12', 'desc': 'Guédiawaye <-> Palais de Justice', 'type': 'AFTU'},
      {'name': 'DDD Ligne 8', 'desc': 'Aéroport Yoff <-> Sandaga', 'type': 'Dakar Dem Dikk'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final item = routes[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.directions_bus, color: Color(0xFF2E7D32), size: 36),
              title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['desc']!),
              trailing: Chip(
                label: Text(item['type']!, style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: const Color(0xFF2E7D32),
              ),
            ),
          );
        },
      ),
    );
  }
}
