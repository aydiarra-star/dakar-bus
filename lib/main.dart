import 'dart:async';
import 'dart:math';
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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B050),
          brightness: Brightness.light,
        ),
      ),
      home: const MainCityScreen(),
    );
  }
}

class TransportOption {
  final String id;
  final String title;
  final String type;
  final String lineName;
  final String destination;
  int minutesLeft;
  final Color color;
  final int price;
  final bool isCrowded;

  TransportOption({
    required this.id,
    required this.title,
    required this.type,
    required this.lineName,
    required this.destination,
    required this.minutesLeft,
    required this.color,
    required this.price,
    this.isCrowded = false,
  });
}

class VehiclePosition {
  final String id;
  final String type;
  final Color color;
  double progress;
  final String lineName;

  VehiclePosition({
    required this.id,
    required this.type,
    required this.color,
    required this.progress,
    required this.lineName,
  });
}

class RouteResult {
  final String destination;
  final String totalDuration;
  final int totalPrice;
  final String arrivalTime;
  final List<RouteStep> steps;

  RouteResult({
    required this.destination,
    required this.totalDuration,
    required this.totalPrice,
    required this.arrivalTime,
    required this.steps,
  });
}

class RouteStep {
  final IconData icon;
  final String instruction;
  final String detail;
  final Color color;

  RouteStep({
    required this.icon,
    required this.instruction,
    required this.detail,
    required this.color,
  });
}

class MainCityScreen extends StatefulWidget {
  const MainCityScreen({super.key});

  @override
  State<MainCityScreen> createState() => _MainCityScreenState();
}

class _MainCityScreenState extends State<MainCityScreen> {
  int _selectedNavIndex = 0;
  bool _isChatOpen = false;
  String _selectedFilter = 'TOUT';
  String _destinationQuery = '';
  
  late RouteResult _activeRoute;

  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  late Timer _realtimeTimer;

  final List<VehiclePosition> _liveVehicles = [
    VehiclePosition(id: "V_TER_1", type: "TER", color: Colors.redAccent, progress: 0.1, lineName: "TER Dakar-Diamniadio"),
    VehiclePosition(id: "V_BRT_1", type: "BRT", color: Colors.blue, progress: 0.4, lineName: "BRT B1 Petersen-Guédiawaye"),
    VehiclePosition(id: "V_TATA_23", type: "AFTU", color: Colors.orange, progress: 0.7, lineName: "Tata 23"),
    VehiclePosition(id: "V_DDD_12", type: "DDD", color: Colors.teal, progress: 0.25, lineName: "DDD Line 12"),
  ];

  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': 'Bonjour ! Je suis l\'assistant IA Dakar Bus. Je peux vous guider vers n\'importe quel quartier (Thiaroye, Almadies, Guédiawaye, Pikine, Mermoz...), vous donner les tarifs ou les horaires du TER/BRT.'
    }
  ];

  final List<TransportOption> _allTransports = [
    TransportOption(
      id: "ter_1",
      title: "Gare TER Colobane",
      type: "TER",
      lineName: "TER Ligne Express",
      destination: "Diamniadio / Thiaroye",
      minutesLeft: 2,
      color: Colors.redAccent,
      price: 500,
    ),
    TransportOption(
      id: "brt_1",
      title: "Station BRT Colobane (B1)",
      type: "BRT",
      lineName: "BRT Ligne B1",
      destination: "Guédiawaye Petersen",
      minutesLeft: 4,
      color: Colors.blue,
      price: 400,
    ),
    TransportOption(
      id: "aftu_23",
      title: "Arrêt AFTU Ligne 23",
      type: "AFTU",
      lineName: "Bus Tata 23",
      destination: "Parcelles Assainies",
      minutesLeft: 5,
      color: Colors.orange,
      price: 200,
      isCrowded: true,
    ),
    TransportOption(
      id: "ddd_12",
      title: "Dakar Dem Dikk Ligne 12",
      type: "DDD",
      lineName: "DDD Bus 12",
      destination: "Palais de Justice ⇆ Almadies",
      minutesLeft: 8,
      color: Colors.teal,
      price: 250,
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _activeRoute = RouteResult(
      destination: "Gare de Thiaroye",
      totalDuration: "16 min",
      totalPrice: 500,
      arrivalTime: "14:42",
      steps: [
        RouteStep(icon: Icons.directions_walk, instruction: "Marcher jusqu'à la Gare TER Colobane", detail: "2 min (150 m)", color: Colors.grey),
        RouteStep(icon: Icons.train, instruction: "TER Direction Diamniadio", detail: "Départ dans 2 min • Voie 2", color: Colors.redAccent),
        RouteStep(icon: Icons.location_on, instruction: "Arrivée à la Gare de Thiaroye", detail: "Correspondances bus AFTU locales à la sortie", color: Colors.green),
      ],
    );

    _realtimeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          for (var t in _allTransports) {
            if (t.minutesLeft > 1) {
              t.minutesLeft--;
            } else {
              t.minutesLeft = Random().nextInt(7) + 2;
            }
          }

          for (var v in _liveVehicles) {
            v.progress += 0.03;
            if (v.progress > 1.0) v.progress = 0.0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _realtimeTimer.cancel();
    _chatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _calculateAndSetRoute(String destination) {
    final query = destination.toLowerCase().trim();
    if (query.isEmpty) return;

    RouteResult result;

    if (query.contains('thiaroye') || query.contains('rufisque') || query.contains('diamniadio')) {
      result = RouteResult(
        destination: "Gare de Thiaroye",
        totalDuration: "16 min",
        totalPrice: 500,
        arrivalTime: "14:42",
        steps: [
          RouteStep(icon: Icons.directions_walk, instruction: "Marcher jusqu'à la Gare TER Colobane", detail: "2 min (150 m)", color: Colors.grey),
          RouteStep(icon: Icons.train, instruction: "TER Direction Diamniadio", detail: "Départ dans ${_allTransports[0].minutesLeft} min • Voie 2", color: Colors.redAccent),
          RouteStep(icon: Icons.location_on, instruction: "Arrivée à la Gare de Thiaroye", detail: "Correspondances bus AFTU locales à la sortie", color: Colors.green),
        ],
      );
    } else if (query.contains('guediawaye') || query.contains('guédiawaye') || query.contains('parcelles')) {
      result = RouteResult(
        destination: "Guédiawaye Bus Station",
        totalDuration: "22 min",
        totalPrice: 400,
        arrivalTime: "14:48",
        steps: [
          RouteStep(icon: Icons.directions_walk, instruction: "Rejoindre la station BRT Colobane", detail: "3 min de marche", color: Colors.grey),
          RouteStep(icon: Icons.directions_bus, instruction: "BRT Ligne B1 (Voie Dédiée)", detail: "Départ dans ${_allTransports[1].minutesLeft} min • Climatisé", color: Colors.blue),
          RouteStep(icon: Icons.location_on, instruction: "Terminus Guédiawaye", detail: "Arrêt connecté au réseau AFTU", color: Colors.green),
        ],
      );
    } else if (query.contains('almadies') || query.contains('ngor') || query.contains('ouakam')) {
      result = RouteResult(
        destination: "Almadies / Ngor",
        totalDuration: "35 min",
        totalPrice: 250,
        arrivalTime: "15:01",
        steps: [
          RouteStep(icon: Icons.directions_walk, instruction: "Rejoindre l'arrêt Dakar Dem Dikk", detail: "4 min de marche", color: Colors.grey),
          RouteStep(icon: Icons.directions_bus, instruction: "DDD Ligne 12 vers Almadies", detail: "Départ dans ${_allTransports[3].minutesLeft} min", color: Colors.teal),
          RouteStep(icon: Icons.location_on, instruction: "Arrivée aux Almadies", detail: "Zone restaurants & plages", color: Colors.green),
        ],
      );
    } else {
      result = RouteResult(
        destination: destination,
        totalDuration: "28 min",
        totalPrice: 200,
        arrivalTime: "14:54",
        steps: [
          RouteStep(icon: Icons.directions_walk, instruction: "Rejoindre l'arrêt AFTU Colobane", detail: "2 min de marche", color: Colors.grey),
          RouteStep(icon: Icons.directions_bus, instruction: "Bus AFTU Tata Ligne 23", detail: "Départ dans ${_allTransports[2].minutesLeft} min", color: Colors.orange),
          RouteStep(icon: Icons.location_on, instruction: "Arrivée à $destination", detail: "Trajet direct", color: Colors.green),
        ],
      );
    }

    setState(() {
      _activeRoute = result;
      _selectedNavIndex = 1;
    });
  }

  void _sendAiMessage(String text) {
    if (text.trim().isEmpty) return;
    final userQuery = text.toLowerCase().trim();

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _chatController.clear();
    });

    String response;

    if (userQuery.contains('tarif') || userQuery.contains('prix') || userQuery.contains('combien')) {
      response = "Tarifs des transports à Dakar :\n• TER : 500 à 1500 FCFA.\n• BRT : 400 à 500 FCFA.\n• Bus AFTU (Tata) : 150 à 250 FCFA.\n• Dakar Dem Dikk : 175 à 300 FCFA.";
    } else if (userQuery.contains('horaire') || userQuery.contains('premier') || userQuery.contains('dernier')) {
      response = "Le TER circule de 05h30 à 22h00. Le BRT fonctionne de 06h00 à 23h00. Les bus AFTU et DDD circulent de 06h00 à 21h30.";
    } else {
      _calculateAndSetRoute(text);
      response = "J'ai calculé le meilleur itinéraire vers '${_activeRoute.destination}'. Durée estimée : ${_activeRoute.totalDuration}, Tarif : ${_activeRoute.totalPrice} FCFA.";
    }

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'ai', 'text': response});
        });
      }
    });
  }

  List<TransportOption> get _filteredTransports {
    return _allTransports.where((t) {
      if (_selectedFilter == 'BUS' && (t.type != 'AFTU' && t.type != 'DDD')) return false;
      if (_selectedFilter == 'RAIL' && (t.type != 'TER' && t.type != 'BRT')) return false;
      if (_destinationQuery.isNotEmpty &&
          !t.title.toLowerCase().contains(_destinationQuery.toLowerCase()) &&
          !t.destination.toLowerCase().contains(_destinationQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DakarCityMapPainter(vehicles: _liveVehicles),
            ),
          ),
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.small(
                  heroTag: "btn_loc",
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00B050),
                  elevation: 4,
                  child: const Icon(Icons.my_location),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Position : Place Colobane, Dakar")),
                    );
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B050),
                    foregroundColor: Colors.white,
                    elevation: 5,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text("Assistant IA", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (_selectedNavIndex == 0)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.20,
              maxChildSize: 0.88,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.directions_bus_filled, color: Color(0xFF00B050), size: 26),
                          SizedBox(width: 8),
                          Text("Dakar Bus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Spacer(),
                          Chip(
                            label: Text("Temps réel Live", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: Color(0xFF00B050),
                            visualDensity: VisualDensity.compact,
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onSubmitted: (val) => _calculateAndSetRoute(val),
                        onChanged: (val) => setState(() => _destinationQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Où voulez-vous aller ? (ex: Thiaroye, Almadies)',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00B050)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _destinationQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip("TOUT", "Tous les réseaux"),
                            const SizedBox(width: 8),
                            _buildFilterChip("RAIL", "TER & BRT"),
                            const SizedBox(width: 8),
                            _buildFilterChip("BUS", "AFTU Tata & DDD"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text("Prochains départs autour de vous", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 8),
                      ..._filteredTransports.map((item) => Card(
                            elevation: 0,
                            color: Colors.grey[50],
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: item.color,
                                child: Icon(item.type == 'TER' ? Icons.train : Icons.directions_bus, color: Colors.white, size: 18),
                              ),
                              title: Row(
                                children: [
                                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (item.isCrowded) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.people, size: 14, color: Colors.orange),
                                  ]
                                ],
                              ),
                              subtitle: Text("${item.lineName} • Dir. ${item.destination}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("${item.minutesLeft} min", style: const TextStyle(color: Color(0xFF00B050), fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text("${item.price} FCFA", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                ],
                              ),
                              onTap: () => _calculateAndSetRoute(item.destination),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          if (_selectedNavIndex == 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_activeRoute.destination, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Arrivée estimée à ${_activeRoute.arrivalTime}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF00B050).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text("${_activeRoute.totalDuration} • ${_activeRoute.totalPrice} FCFA", style: const TextStyle(color: Color(0xFF00B050), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _activeRoute.steps.length,
                        itemBuilder: (context, index) {
                          final step = _activeRoute.steps[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: step.color.withOpacity(0.15),
                                  child: Icon(step.icon, color: step.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(step.instruction, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(step.detail, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isChatOpen)
            Positioned(
              bottom: 75,
              left: 12,
              right: 12,
              height: 420,
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00B050),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text("Assistant IA Dakar Bus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => setState(() => _isChatOpen = false),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isAi = msg['sender'] == 'ai';
                          return Align(
                            alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAi ? Colors.grey[100] : const Color(0xFF00B050),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                msg['text']!,
                                style: TextStyle(color: isAi ? Colors.black87 : Colors.white, fontSize: 13),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: const InputDecoration(
                                hintText: "Posez votre question...",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onSubmitted: _sendAiMessage,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: Color(0xFF00B050)),
                            onPressed: () => _sendAiMessage(_chatController.text),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) => setState(() => _selectedNavIndex = index),
        selectedItemColor: const Color(0xFF00B050),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Trajets'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF00B050).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF00B050) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }
}

class DakarCityMapPainter extends CustomPainter {
  final List<VehiclePosition> vehicles;

  DakarCityMapPainter({required this.vehicles});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE8ECEB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final seaPaint = Paint()..color = const Color(0xFFB0E0E6);
    final seaPath = Path()
      ..moveTo(0, size.height * 0.15)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width * 0.38, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.9, 0, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(seaPath, seaPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.4), Offset(size.width * 0.8, size.height * 0.8), roadPaint);

    final terPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final terPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.95, size.height * 0.12);
    canvas.drawPath(terPath, terPaint);

    final brtPaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final brtPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.54)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.35, size.width * 0.85, size.height * 0.28);
    canvas.drawPath(brtPath, brtPaint);

    for (var vehicle in vehicles) {
      double x = size.width * (0.28 + (0.60 * vehicle.progress));
      double y = size.height * (0.52 - (0.35 * vehicle.progress));

      canvas.drawCircle(Offset(x, y), 8, Paint()..color = vehicle.color);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant DakarCityMapPainter oldDelegate) => true;
}
