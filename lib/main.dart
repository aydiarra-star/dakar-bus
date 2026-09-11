import 'package:flutter/material.dart';
import 'models/transport_network.dart';
import 'services/data_service.dart';

void main() {
  runApp(const DakarBusApp());
}

class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakar Bus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00875A)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DataService _dataService = DataService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _dataService.loadNetworkData();
    setState(() {
      _isLoading = false;
    });
  }

  Color _getTrustColor(DataTrust trust) {
    switch (trust) {
      case DataTrust.official:
        return Colors.green;
      case DataTrust.fieldObservation:
        return Colors.blue;
      case DataTrust.estimated:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus'),
        backgroundColor: const Color(0xFF00875A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Réseau de Transport',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._dataService.routes.map((route) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF00875A),
                        child: Text(
                          route.shortName.split(' ').last,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(route.shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(route.longName),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTrustColor(route.dataTrust).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          route.dataTrust.toLabel(),
                          style: TextStyle(
                            color: _getTrustColor(route.dataTrust),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
