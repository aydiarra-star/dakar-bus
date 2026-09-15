import 'package:flutter/material.dart';

void main() {
  runApp(const WaxtuBusApp());
}

class WaxtuBusApp extends StatelessWidget {
  const WaxtuBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waxtu-Bus Dakar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00853F), // Vert Sénégal / Transport urbain
          secondary: const Color(0xFFFDEF42), // Jaune vif
          tertiary: const Color(0xFFE31B23),  // Rouge
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const NetworksScreen(),
    const AssistantScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Trajets',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Réseaux',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Assistant IA',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. ÉCRAN PRINCIPAL / ITINÉRAIRES & RECHERCHE
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waxtu-Bus Dakar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module de recherche d'itinéraire
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _departureController,
                      decoration: const InputDecoration(
                        labelText: 'Point de départ (ex: Colobane, Pikine...)',
                        prefixIcon: Icon(Icons.my_location, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _arrivalController,
                      decoration: const InputDecoration(
                        labelText: 'Destination (ex: Plateau, Diamniadio...)',
                        prefixIcon: Icon(Icons.location_on, color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Calculer le meilleur itinéraire'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Réseaux intégrés à Dakar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Grille des réseaux multimodaux
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: const [
                NetworkBadge(name: 'TER', subtitle: 'Train Express Régional', color: Colors.blue),
                NetworkBadge(name: 'BRT', subtitle: 'Bus Rapid Transit', color: Colors.orange),
                NetworkBadge(name: 'AFTU', subtitle: '72 Lignes Urbaines', color: Colors.green),
                NetworkBadge(name: 'Tata & DDD', subtitle: 'Bus Dakar Dem Dikk', color: Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            if (_isSearching) ...[
              const Text(
                'Itinéraires suggérés (OSRM & Temps réel)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const ItineraryCard(
                transportType: 'BRT + AFTU',
                duration: '45 min',
                cost: '400 FCFA',
                details: 'Prendre le BRT de Liberté 6 jusqu\'à Grand Dakar, puis correspondance AFTU.',
              ),
              const ItineraryCard(
                transportType: 'TER Express',
                duration: '25 min',
                cost: '1000 FCFA',
                details: 'Gare de Dakar -> Gare de Diamniadio directe.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. ÉCRAN DES RÉSEAUX ET LIGNES
// ==========================================
class NetworksScreen extends StatelessWidget {
  const NetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réseaux et Lignes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'AFTU (72 Lignes)'),
              Tab(text: 'TER & BRT'),
              Tab(text: 'Horaires & Trafic'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: 15,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('AF', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Ligne AFTU ${index + 1}'),
                  subtitle: const Text('Parcours actif - Fréquence: 10 min'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ligne TER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Dakar - Diamniadio (Stations: Dakar, Colobane, Hann, Pikine, Thiaroye, Rufisque, Bargny, Diamniadio)'),
                  SizedBox(height: 20),
                  Text('Ligne BRT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Guédiawaye - Dakar Plateau (Corridor exclusif de 18.3 km)'),
                ],
              ),
            ),
            const Center(child: Text('État du trafic en temps réel et alertes géolocalisées.')),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. ASSISTANT INTELLIGENT IA
// ==========================================
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<Map<String, String>> _messages = [
    {'sender': 'bot', 'text': 'Nànga def ! Je suis ton assistant Waxtu-Bus. Comment puis-je t\'aider à te déplacer dans Dakar aujourd\'hui ?'}
  ];
  final TextEditingController _msgController = TextEditingController();

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': _msgController.text});
      _messages.add({'sender': 'bot', 'text': 'Recherche du trajet optimal pour "${_msgController.text}" avec prise en compte du trafic actuel...'});
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant Intelligent Waxtu-Bus')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Pose ta question (en français ou wolof)...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. PARAMÈTRES ET MODE HORS-LIGNE
// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres & Hors-Ligne')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Mode Hors-Ligne (Données en cache)'),
            subtitle: const Text('Sauvegarder les lignes AFTU et cartes pour usage sans internet'),
            value: true,
            onChanged: (val) {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue de l\'application'),
            subtitle: const Text('Français / Wolof'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos de Waxtu-Bus'),
            subtitle: const Text('Version 1.2.0 - Mobilité Urbaine Dakar'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ==========================================
// COMPOSANTS RÉUTILISABLES (WIDGETS)
// ==========================================
class NetworkBadge extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color color;

  const NetworkBadge({
    super.key,
    required this.name,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class ItineraryCard extends StatelessWidget {
  final String transportType;
  final String duration;
  final String cost;
  final String details;

  const ItineraryCard({
    super.key,
    required this.transportType,
    required this.duration,
    required this.cost,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.directions, color: Colors.white),
        ),
        title: Text('$transportType • $duration', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(details),
            const SizedBox(height: 4),
            Text('Coût estimé : $cost', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
