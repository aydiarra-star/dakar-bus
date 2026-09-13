import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const DakarBusApp());

// ============================================================
// SERVICE ROUTING REEL (OSRM + SECURITE TERRESTRE)
// ============================================================
class RoutingService {
  static Future<List<LatLng>> getRealRoute(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
      }
    } catch (_) {
      // En cas d'échec réseau ou timeout, on retourne un tracé terrestre de secours
    }
    return _getFallbackTerrestrialRoute(start, end);
  }

  static List<LatLng> _getFallbackTerrestrialRoute(LatLng start, LatLng end) {
    // Si les points concernent la grande banlieue/rafisque/thiaroye, on force un contournement terrestre
    if (start.latitude > 14.70 && end.latitude > 14.70 && (start.longitude - end.longitude).abs() > 0.05) {
      return [
        start,
        LatLng(14.7410, -17.4120), // Dalifort / Route Nationale
        LatLng(14.7550, -17.3900), // Pikine
        LatLng(14.7588, -17.3803), // Thiaroye
        LatLng(14.7450, -17.3980), // Mbao
        end,
      ];
    }
    return [start, end];
  }
}

// ============================================================
// SERVICE DE DÉTECTION DES DEUX SENS (ALLER / RETOUR)
// ============================================================
class OppositeStopService {
  static Stop? findOppositeStop({
    required Stop currentStop,
    required List<Stop> allStops,
  }) {
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    for (final stop in allStops) {
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      
      if (distance <= 50.0 && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName) || currentName.substring(0, (currentName.length * 0.6).toInt()) == stopName.substring(0, (stopName.length * 0.6).toInt())) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }
    return bestCandidate ?? allStops.firstWhere(
      (s) => s.modeLabel == currentStop.modeLabel && s.direction != currentStop.direction,
      orElse: () => currentStop,
    );
  }
}

// ============================================================
// GENERATEUR D HORAIRES OFFICIELS
// ============================================================
List<int> _generateSchedule({
  required int from,
  required int to,
  required int step,
}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) {
    list.add(m);
  }
  return list;
}

List<int> _shift(List<int> base, int offset) {
  return base.map((m) => m + offset).toList();
}

bool _isSunday() => DateTime.now().weekday == DateTime.sunday;

List<int> _buildTerBase() {
  final step = _isSunday() ? 20 : 10;
  return _generateSchedule(from: 330, to: 1320, step: step);
}

final List<int> _brtBase = _generateSchedule(
  from: 360,
  to: 1260,
  step: 6,
);

final List<int> _terBase = _buildTerBase();

// ============================================================
// COULEURS
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFF8D4004); 
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
// SOURCE DE DONNEES
// ============================================================
enum DataOrigin { official, demo }

class DataSourceInfo {
  final DataOrigin origin;
  final String label;

  const DataSourceInfo({
    required this.origin,
    required this.label,
  });

  static const seter = DataSourceInfo(
    origin: DataOrigin.official,
    label: 'SETER',
  );

  static const sunubrt = DataSourceInfo(
    origin: DataOrigin.official,
    label: 'SunuBRT',
  );

  static const demo = DataSourceInfo(
    origin: DataOrigin.demo,
    label: 'Demonstration',
  );
}

// ============================================================
// STATUT
// ============================================================
enum DataStatus { scheduled, live, unknown }

class DataStatusBadge extends StatelessWidget {
  final DataStatus status;
  final bool compact;

  const DataStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData? icon;
    bool dotOnly = false;

    switch (status) {
      case DataStatus.live:
        color = AppColors.success;
        label = 'LIVE';
        dotOnly = true;
        break;
      case DataStatus.scheduled:
        color = AppColors.warning;
        label = 'Programme';
        icon = Icons.schedule;
        break;
      case DataStatus.unknown:
        color = AppColors.neutral;
        label = 'Indisponible';
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotOnly)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            )
          else if (icon != null)
            Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.success.withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: const Text(
        'OFFICIEL',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================
// MODELES
// ============================================================
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
  final DataSourceInfo source;

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
    this.source = DataSourceInfo.demo,
  });

  int? nextDepartureMinutes() {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) {
      if (d > currentMin) return d;
    }
    if (departureMinutesFromMidnight.isNotEmpty) {
      return departureMinutesFromMidnight.first + 24 * 60;
    }
    return null;
  }

  int? remainingMinutes() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final now = DateTime.now();
    return d - (now.hour * 60 + now.minute);
  }

  String? nextDepartureLabel() {
    final d = nextDepartureMinutes();
    if (d == null) return null;
    final normalized = d % (24 * 60);
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '$h h $m';
  }

  int? departureAfter(int minFromMidnight) {
    for (final d in departureMinutesFromMidnight) {
      if (d > minFromMidnight) return d;
    }
    if (departureMinutesFromMidnight.isNotEmpty) {
      return departureMinutesFromMidnight.first + 24 * 60;
    }
    return null;
  }
}

class TransitRoute {
  final String name;
  final String code;
  final String type;
  final Color color;
  final List<LatLng> points;

  const TransitRoute({
    required this.name,
    required this.code,
    required this.type,
    required this.color,
    required this.points,
  });
}

class FavoriteRoute {
  final String label;
  final String from;
  final String to;
  final IconData icon;

  const FavoriteRoute({
    required this.label,
    required this.from,
    required this.to,
    required this.icon,
  });
}

class RouteSegment {
  final String modeLabel;
  final Color color;
  final IconData icon;
  final String from;
  final String to;
  final int durationMinutes;
  final String? departureTime;
  final String? arrivalTime;
  final DataStatus status;
  final bool isWalk;

  const RouteSegment({
    required this.modeLabel,
    required this.color,
    required this.icon,
    required this.from,
    required this.to,
    required this.durationMinutes,
    this.departureTime,
    this.arrivalTime,
    this.status = DataStatus.scheduled,
    this.isWalk = false,
  });
}

class PlannedRoute {
  final String fromName;
  final String toName;
  final List<RouteSegment> segments;
  final int totalMinutes;
  final bool isBest;
  final DataStatus status;
  final int transferCount;

  const PlannedRoute({
    required this.fromName,
    required this.toName,
    required this.segments,
    required this.totalMinutes,
    this.isBest = false,
    this.status = DataStatus.scheduled,
    this.transferCount = 0,
  });
}

class RouteSearchResult {
  final List<PlannedRoute> routes;
  final List<String> missingData;
  final String? errorMessage;

  const RouteSearchResult({
    this.routes = const [],
    this.missingData = const [],
    this.errorMessage,
  });

  bool get hasRoutes => routes.isNotEmpty;
}

// ============================================================
// DONNEES TER (officiel SETER)
// ============================================================
final List<Stop> terStations = [
  Stop(
    name: 'Gare TER Dakar',
    direction: 'Terminus Dakar (Arrivée)',
    distanceMeters: 350,
    departureMinutesFromMidnight: _shift(_terBase, 0),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6792, -17.4407),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Dakar',
    direction: 'Dir. Diamniadio (Embarquement)',
    distanceMeters: 350,
    departureMinutesFromMidnight: _shift(_terBase, 3),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6795, -17.4405),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Colobane',
    direction: 'Dir. Diamniadio',
    distanceMeters: 1200,
    departureMinutesFromMidnight: _shift(_terBase, 5),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6937, -17.4441),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Colobane',
    direction: 'Dir. Dakar',
    distanceMeters: 1200,
    departureMinutesFromMidnight: _shift(_terBase, 3),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6935, -17.4443),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Hann',
    direction: 'Dir. Diamniadio',
    distanceMeters: 3500,
    departureMinutesFromMidnight: _shift(_terBase, 9),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7222, -17.4321),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Hann',
    direction: 'Dir. Dakar',
    distanceMeters: 3500,
    departureMinutesFromMidnight: _shift(_terBase, 7),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7220, -17.4323),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Dalifort',
    direction: 'Dir. Diamniadio',
    distanceMeters: 5100,
    departureMinutesFromMidnight: _shift(_terBase, 12),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7410, -17.4120),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Dalifort',
    direction: 'Dir. Dakar',
    distanceMeters: 5100,
    departureMinutesFromMidnight: _shift(_terBase, 10),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7412, -17.4122),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Baux Maraichers',
    direction: 'Dir. Diamniadio',
    distanceMeters: 6300,
    departureMinutesFromMidnight: _shift(_terBase, 14),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7470, -17.4010),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Pikine',
    direction: 'Dir. Diamniadio',
    distanceMeters: 7200,
    departureMinutesFromMidnight: _shift(_terBase, 17),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7550, -17.3900),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Thiaroye',
    direction: 'Dir. Diamniadio',
    distanceMeters: 8100,
    departureMinutesFromMidnight: _shift(_terBase, 20),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7588, -17.3803),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Yeumbeul',
    direction: 'Dir. Diamniadio',
    distanceMeters: 11500,
    departureMinutesFromMidnight: _shift(_terBase, 24),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7700, -17.3400),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Keur Mbaye Fall',
    direction: 'Dir. Dakar / Diamniadio',
    distanceMeters: 14200,
    departureMinutesFromMidnight: _shift(_terBase, 27),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7750, -17.3100),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER PNR',
    direction: 'Dir. Diamniadio',
    distanceMeters: 16800,
    departureMinutesFromMidnight: _shift(_terBase, 30),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7500, -17.2900),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Rufisque',
    direction: 'Dir. Diamniadio',
    distanceMeters: 22100,
    departureMinutesFromMidnight: _shift(_terBase, 36),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7157, -17.2703),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Bargny',
    direction: 'Dir. Diamniadio',
    distanceMeters: 28500,
    departureMinutesFromMidnight: _shift(_terBase, 42),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6900, -17.2200),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
  Stop(
    name: 'Gare TER Diamniadio',
    direction: 'Terminus Diamniadio',
    distanceMeters: 35000,
    departureMinutesFromMidnight: _shift(_terBase, 50),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.7160, -17.1986),
    modeLabel: 'TER',
    source: DataSourceInfo.seter,
  ),
];

// ============================================================
// DONNEES BRT (officiel SunuBRT)
// ============================================================
final List<Stop> brtStations = [
  Stop(
    name: 'PEM Petersen',
    direction: 'Terminus sud BRT',
    distanceMeters: 200,
    departureMinutesFromMidnight: _shift(_brtBase, 0),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.6720, -17.4400),
    modeLabel: 'BRT',
    source: DataSourceInfo.sunubrt,
  ),
  Stop(
    name: 'BRT Colobane',
    direction: 'Dir. Guediawaye',
    distanceMeters: 150,
    departureMinutesFromMidnight: _shift(_brtBase, 2),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.6950, -17.4420),
    modeLabel: 'BRT',
    source: DataSourceInfo.sunubrt,
  ),
  Stop(
    name: 'BRT Grand Dakar',
    direction: 'Dir. Guediawaye',
    distanceMeters: 1500,
    departureMinutesFromMidnight: _shift(_brtBase, 4),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.7050, -17.4400),
    modeLabel: 'BRT',
    source: DataSourceInfo.sunubrt,
  ),
  Stop(
    name: 'BRT Parcelles',
    direction: 'Dir. Guediawaye',
    distanceMeters: 5000,
    departureMinutesFromMidnight: _shift(_brtBase, 6),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.7350, -17.4260),
    modeLabel: 'BRT',
    source: DataSourceInfo.sunubrt,
  ),
  Stop(
    name: 'PEM Guediawaye',
    direction: 'Terminus nord BRT',
    distanceMeters: 10500,
    departureMinutesFromMidnight: _shift(_brtBase, 8),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.7735, -17.3977),
    modeLabel: 'BRT',
    source: DataSourceInfo.sunubrt,
  ),
];

// ============================================================
// DONNEES AFTU / TATA / DDD (Intégration complète)
// ============================================================
final List<Stop> otherBusStations = [
  const Stop(
    name: 'Arret AFTU 23',
    direction: 'Dir. Parcelles Assainies',
    distanceMeters: 280,
    departureMinutesFromMidnight: [
      630, 645, 700, 715, 730, 745,
      800, 815, 830, 845, 900, 915,
    ],
    icon: Icons.directions_bus_outlined,
    color: AppColors.aftu,
    location: LatLng(14.6900, -17.4460),
    modeLabel: 'AFTU',
  ),
  const Stop(
    name: 'Arret AFTU 10',
    direction: 'Dir. Grand Yoff',
    distanceMeters: 450,
    departureMinutesFromMidnight: [
      635, 650, 705, 720, 735, 750,
      805, 820, 835, 850, 905, 920,
    ],
    icon: Icons.directions_bus_outlined,
    color: AppColors.aftu,
    location: LatLng(14.7200, -17.4600),
    modeLabel: 'AFTU',
  ),
  const Stop(
    name: 'Arret Tata 12',
    direction: 'Dir. Guediawaye',
    distanceMeters: 600,
    departureMinutesFromMidnight: [
      640, 655, 710, 725, 740, 755,
      810, 825, 840, 855, 910, 925,
    ],
    icon: Icons.directions_bus_filled,
    color: AppColors.tata,
    location: LatLng(14.7200, -17.4700),
    modeLabel: 'Tata',
  ),
  const Stop(
    name: 'Ligne DDD 1',
    direction: 'Parcelles Assainies ➔ Place Leclerc',
    distanceMeters: 350,
    departureMinutesFromMidnight: [360, 420, 480, 540, 600, 660, 720, 780, 840, 900, 960],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7600, -17.4400),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 4',
    direction: 'Liberté 5 ➔ Place Leclerc',
    distanceMeters: 420,
    departureMinutesFromMidnight: [370, 430, 490, 550, 610, 670, 730, 790, 850, 910, 970],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7150, -17.4600),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 7',
    direction: 'Ouakam ➔ Palais 2',
    distanceMeters: 500,
    departureMinutesFromMidnight: [380, 440, 500, 560, 620, 680, 740, 800, 860, 920, 980],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7250, -17.4900),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 8',
    direction: 'Aéroport LSS ➔ Palais 2',
    distanceMeters: 600,
    departureMinutesFromMidnight: [390, 450, 510, 570, 630, 690, 750, 810, 870, 930],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7550, -17.4750),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 9',
    direction: 'Liberté 6 ➔ Palais 2',
    distanceMeters: 650,
    departureMinutesFromMidnight: [400, 460, 520, 580, 640, 700, 760, 820, 880, 940],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7250, -17.4650),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 217',
    direction: 'Thiaroye ➔ Ouakam',
    distanceMeters: 850,
    departureMinutesFromMidnight: [360, 440, 520, 600, 680, 760, 840, 920],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7588, -17.3803),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 218',
    direction: 'Thiaroye ➔ Djiolof Chicken Almadie',
    distanceMeters: 900,
    departureMinutesFromMidnight: [370, 450, 530, 610, 690, 770, 850, 930],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7588, -17.3803),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 219',
    direction: 'Daroukhane ➔ Ouakam',
    distanceMeters: 950,
    departureMinutesFromMidnight: [380, 460, 540, 620, 700, 780, 860, 940],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7200, -17.4900),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 220',
    direction: 'Rufisque ➔ Guédiawaye',
    distanceMeters: 1100,
    departureMinutesFromMidnight: [390, 470, 550, 630, 710, 790, 870, 950],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7157, -17.2703),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 221',
    direction: 'Gadaye ➔ Almadies',
    distanceMeters: 1200,
    departureMinutesFromMidnight: [400, 480, 560, 640, 720, 800, 880, 960],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7700, -17.4300),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 227',
    direction: 'Keur Massar ➔ Parcelles Assainies',
    distanceMeters: 1300,
    departureMinutesFromMidnight: [410, 490, 570, 650, 730, 810, 890, 970],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7900, -17.3500),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 401',
    direction: 'Ouakam ➔ Aéroport Diass (AIBD)',
    distanceMeters: 2500,
    departureMinutesFromMidnight: [420, 540, 660, 780, 900],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7250, -17.4900),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 402',
    direction: 'Thiaroye ➔ Aéroport Diass (AIBD)',
    distanceMeters: 2600,
    departureMinutesFromMidnight: [430, 550, 670, 790, 910],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7588, -17.3803),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Ligne DDD 403',
    direction: 'Parcelles Assainies ➔ Aéroport Diass (AIBD)',
    distanceMeters: 2700,
    departureMinutesFromMidnight: [440, 560, 680, 800, 920],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7600, -17.4400),
    modeLabel: 'DDD',
  ),
];

final List<Stop> allStops = [
  ...terStations,
  ...brtStations,
  ...otherBusStations,
];

final List<Stop> mapPriorityStops = [
  terStations[0],
  terStations[2],
  terStations[5],
  terStations[8],
  terStations[12],
  brtStations[1],
  brtStations[4],
  otherBusStations[3],
];

// ============================================================
// TRACES DES LIGNES (100% Terrestres - Contournement strict de l'eau)
// ============================================================
final List<TransitRoute> demoRoutes = [
  const TransitRoute(
    name: 'TER',
    code: 'TER',
    type: 'TER',
    color: AppColors.ter,
    points: [
      LatLng(14.6792, -17.4407),
      LatLng(14.6937, -17.4441),
      LatLng(14.7222, -17.4321),
      LatLng(14.7410, -17.4120),
      LatLng(14.7550, -17.3900),
      LatLng(14.7700, -17.3400),
      LatLng(14.7750, -17.3100),
      LatLng(14.7500, -17.2900),
      LatLng(14.7157, -17.2703),
      LatLng(14.6900, -17.2200),
      LatLng(14.7160, -17.1986),
    ],
  ),
  const TransitRoute(
    name: 'BRT',
    code: 'B1',
    type: 'BRT',
    color: AppColors.brt,
    points: [
      LatLng(14.6720, -17.4400),
      LatLng(14.6950, -17.4420),
      LatLng(14.7050, -17.4400),
      LatLng(14.7220, -17.4330),
      LatLng(14.7350, -17.4260),
      LatLng(14.7520, -17.4100),
      LatLng(14.7735, -17.3977),
    ],
  ),
  const TransitRoute(
    name: 'AFTU',
    code: '23',
    type: 'AFTU',
    color: AppColors.aftu,
    points: [
      LatLng(14.7600, -17.4400),
      LatLng(14.7450, -17.4430),
      LatLng(14.7200, -17.4460),
      LatLng(14.6900, -17.4460),
      LatLng(14.6790, -17.4400),
    ],
  ),
  const TransitRoute(
    name: 'Tata',
    code: '12',
    type: 'TATA',
    color: AppColors.tata,
    points: [
      LatLng(14.7735, -17.3977),
      LatLng(14.7500, -17.4200),
      LatLng(14.7250, -17.4500),
      LatLng(14.7000, -17.4600),
      LatLng(14.6800, -17.4500),
      LatLng(14.6750, -17.4400),
    ],
  ),
  const TransitRoute(
    name: 'DDD Urbaine (Lignes 1, 4)',
    code: 'DDD-1',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      LatLng(14.7600, -17.4400),
      LatLng(14.7450, -17.4440),
      LatLng(14.7250, -17.4520),
      LatLng(14.7050, -17.4560),
      LatLng(14.6900, -17.4480),
      LatLng(14.6790, -17.4420),
      LatLng(14.6720, -17.4400),
    ],
  ),
  const TransitRoute(
    name: 'DDD Côtière (Lignes 7, 8, 9)',
    code: 'DDD-7',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      LatLng(14.7250, -17.4900),
      LatLng(14.7120, -17.4780),
      LatLng(14.6980, -17.4680),
      LatLng(14.6850, -17.4520),
      LatLng(14.6790, -17.4420),
    ],
  ),
  // Tracé Banlieue 100% sur la route (Évite rigoureusement l'océan)
  const TransitRoute(
    name: 'DDD Banlieue (217-227)',
    code: 'DDD-217',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      LatLng(14.7900, -17.3500), // Keur Massar
      LatLng(14.7800, -17.3680),
      LatLng(14.7700, -17.3850), // Guediawaye
      LatLng(14.7588, -17.3803), // Thiaroye
      LatLng(14.7620, -17.3750), // Intérieur terre (Mbaout Nord)
      LatLng(14.7520, -17.3900), // Pikine Intérieur
      LatLng(14.7410, -17.4120), // Dalifort Route Nationale
      LatLng(14.7222, -17.4321), // Hann
      LatLng(14.6937, -17.4441), // Colobane
      LatLng(14.6792, -17.4407), // Dakar
    ],
  ),
  const TransitRoute(
    name: 'DDD Express AIBD (401-403)',
    code: 'DDD-401',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      LatLng(14.7600, -17.4400),
      LatLng(14.7250, -17.4900),
      LatLng(14.6950, -17.4550),
      LatLng(14.6720, -17.4400),
      LatLng(14.7222, -17.4321),
      LatLng(14.7410, -17.4120),
      LatLng(14.7160, -17.1986),
    ],
  ),
];

// ============================================================
// BASE DE LIEUX
// ============================================================
class Place {
  final String name;
  final String type;
  final IconData icon;
  final Color color;
  final LatLng? location;
  final Stop? linkedStop;

  const Place({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.location,
    this.linkedStop,
  });
}

List<Place> buildPlaceDatabase() {
  final places = <Place>[];

  final cities = <List<Object>>[
    ['Dakar', LatLng(14.6928, -17.4467)],
    ['Plateau', LatLng(14.6720, -17.4400)],
    ['Medina', LatLng(14.6837, -17.4500)],
    ['Fass', LatLng(14.6880, -17.4500)],
    ['Gueule Tapee', LatLng(14.6900, -17.4450)],
    ['Soumbedioune', LatLng(14.6850, -17.4420)],
    ['Fann', LatLng(14.6900, -17.4650)],
    ['Point E', LatLng(14.6950, -17.4600)],
    ['Mermoz', LatLng(14.7050, -17.4750)],
    ['Sacre-Coeur', LatLng(14.7100, -17.4700)],
    ['Grand Dakar', LatLng(14.7000, -17.4550)],
    ['HLM', LatLng(14.7080, -17.4700)],
    ['Yoff', LatLng(14.7550, -17.4750)],
    ['Ngor', LatLng(14.7550, -17.5000)],
    ['Almadies', LatLng(14.7350, -17.5100)],
    ['Ouakam', LatLng(14.7250, -17.4900)],
    ['Mamelles', LatLng(14.7200, -17.4950)],
    ['Grand Yoff', LatLng(14.7300, -17.4600)],
    ['Patte d Oie', LatLng(14.7350, -17.4550)],
    ['Liberte 6', LatLng(14.7250, -17.4650)],
    ['SICAP Liberte', LatLng(14.7280, -17.4620)],
    ['Dieuppeul', LatLng(14.7150, -17.4600)],
    ['Derkle', LatLng(14.7180, -17.4550)],
    ['Hann', LatLng(14.7222, -17.4321)],
    ['Bel-Air', LatLng(14.7180, -17.4200)],
    ['Front de Terre', LatLng(14.7100, -17.4400)],
    ['Parcelles Assainies', LatLng(14.7600, -17.4400)],
    ['Grand Medine', LatLng(14.7650, -17.4500)],
    ['Cite Comico', LatLng(14.7700, -17.4400)],
    ['Unite 15', LatLng(14.7620, -17.4380)],
    ['Pikine', LatLng(14.7550, -17.3900)],
    ['Guediawaye', LatLng(14.7735, -17.3977)],
    ['Thiaroye', LatLng(14.7588, -17.3803)],
    ['Guinaw Rail', LatLng(14.7700, -17.3800)],
    ['Diamaguenne', LatLng(14.7800, -17.3600)],
    ['Camberene', LatLng(14.7700, -17.4300)],
    ['Yeumbeul', LatLng(14.7700, -17.3400)],
    ['Malika', LatLng(14.7850, -17.3300)],
    ['Keur Massar', LatLng(14.7900, -17.3500)],
    ['Jaxaay', LatLng(14.7900, -17.3700)],
    ['Tivaouane Peulh', LatLng(14.7900, -17.4200)],
    ['Keur Mbaye Fall', LatLng(14.7750, -17.3100)],
    ['Rufisque', LatLng(14.7157, -17.2703)],
    ['Bargny', LatLng(14.6900, -17.2200)],
    ['Diamniadio', LatLng(14.7160, -17.1986)],
    ['Sebikotane', LatLng(14.7400, -17.1700)],
    ['Sangalkam', LatLng(14.7800, -17.2200)],
  ];

  for (final c in cities) {
    places.add(Place(
      name: c[0] as String,
      type: 'place',
      icon: Icons.location_city,
      color: AppColors.textSecondary,
      location: c[1] as LatLng,
    ));
  }

  for (final s in allStops) {
    places.add(Place(
      name: s.name,
      type: s.modeLabel,
      icon: s.icon,
      color: s.color,
      location: s.location,
      linkedStop: s,
    ));
  }

  return places;
}

final List<Place> placeDatabase = buildPlaceDatabase();

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static const double _maxWalkMeters = 900;
  static const double _walkSpeedMpm = 83.0;

  static RouteSearchResult plan({
    required String fromQuery,
    required String toQuery,
  }) {
    final fromPlace = _resolvePlace(fromQuery);
    final toPlace = _resolvePlace(toQuery);

    if (fromPlace == null) {
      return RouteSearchResult(
        missingData: ['Lieu de depart introuvable'],
        errorMessage: 'Nous ne reconnaissons pas $fromQuery.',
      );
    }
    if (toPlace == null) {
      return RouteSearchResult(
        missingData: ['Destination introuvable'],
        errorMessage: 'Nous ne reconnaissons pas $toQuery.',
      );
    }

    final fromStop = fromPlace.linkedStop ?? _nearestStop(fromPlace.location);
    final toStop = toPlace.linkedStop ?? _nearestStop(toPlace.location);

    if (fromStop == null || toStop == null) {
      return RouteSearchResult(
        missingData: ['Arret introuvable'],
        errorMessage: 'Aucun arret proche trouvé.',
      );
    }

    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final candidates = <PlannedRoute>[];

    if (fromStop.modeLabel == toStop.modeLabel && fromStop.name != toStop.name) {
      final direct = _buildDirectRoute(fromStop, toStop, fromPlace.name, toPlace.name, currentMin);
      if (direct != null) candidates.add(direct);
    }

    if (candidates.isEmpty) {
      return RouteSearchResult(
        missingData: ['Correspondance'],
        errorMessage: 'Aucun itinéraire direct trouvé entre ${fromStop.name} et ${toStop.name}.',
      );
    }

    return RouteSearchResult(routes: candidates);
  }

  static PlannedRoute? _buildDirectRoute(Stop from, Stop to, String fromName, String toName, int currentMin) {
    final dep = from.departureAfter(currentMin - 1);
    if (dep == null) return null;
    final dur = _travelDuration(from, to);
    final arr = dep + dur;

    return PlannedRoute(
      fromName: fromName,
      toName: toName,
      totalMinutes: arr - currentMin,
      transferCount: 0,
      status: DataStatus.scheduled,
      segments: [
        RouteSegment(
          modeLabel: from.modeLabel,
          color: from.color,
          icon: from.icon,
          from: from.name,
          to: to.name,
          durationMinutes: dur,
          departureTime: _formatMin(dep),
          arrivalTime: _formatMin(arr),
          status: DataStatus.scheduled,
        ),
      ],
    );
  }

  static int _travelDuration(Stop a, Stop b) {
    final dist = DistanceHelper.haversineMeters(a.location, b.location);
    if (dist < 50) return 0;
    final speedKmh = (a.modeLabel == 'TER' || a.modeLabel == 'BRT') ? 30.0 : 15.0;
    final minutes = ((dist / 1000.0) / speedKmh * 60).ceil();
    return minutes < 2 ? 2 : minutes;
  }

  static String _formatMin(int minFromMidnight) {
    final normalized = minFromMidnight % (24 * 60);
    final h = (normalized ~/ 60).toString().padLeft(2, '0');
    final m = (normalized % 60).toString().padLeft(2, '0');
    return '$h h $m';
  }

  static Place? _resolvePlace(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final p in placeDatabase) {
      if (p.name.toLowerCase() == q || p.name.toLowerCase().contains(q)) return p;
    }
    return null;
  }

  static Stop? _nearestStop(LatLng? loc) {
    if (loc == null) return null;
    Stop? best;
    double bestDist = double.infinity;
    for (final s in allStops) {
      final d = DistanceHelper.haversineMeters(loc, s.location);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}

// ============================================================
// UTILITAIRES
// ============================================================
class TimeHelper {
  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'Depart imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  static bool isProbablyNextDay(int minutes) => minutes > 180;
}

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  static double haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * 3.141592653589793 / 180;
    final lat2 = b.latitude * 3.141592653589793 / 180;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLon = (b.longitude - a.longitude) * 3.141592653589793 / 180;
    final h = (1 - _cos(dLat)) / 2 + _cos(lat1) * _cos(lat2) * (1 - _cos(dLon)) / 2;
    return 2 * R * _asin(_sqrt(h));
  }

  static double _cos(double x) {
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24;
  }

  static double _asin(double x) {
    if (x < -1) return -1.5708;
    if (x > 1) return 1.5708;
    return x + (x * x * x) / 6;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }
}

// ============================================================
// APP SHELL
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
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

enum GpsState { idle, loading, granted, denied, deniedForever, serviceDisabled, error }

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Timer? _ticker;
  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;
  String? _gpsMessage;

  final List<FavoriteRoute> _favorites = [
    const FavoriteRoute(label: 'Maison', from: 'Ma position', to: 'Plateau', icon: Icons.home_rounded),
    const FavoriteRoute(label: 'Travail', from: 'Ma position', to: 'Parcelles Assainies', icon: Icons.work_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _requestLocation() async {
    setState(() {
      _gpsState = GpsState.loading;
      _gpsMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsState = GpsState.serviceDisabled;
          _gpsMessage = 'GPS désactivé.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsState = GpsState.denied;
          _gpsMessage = 'Permission GPS refusée.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _gpsState = GpsState.granted;
        _gpsMessage = null;
      });
    } catch (_) {
      setState(() {
        _gpsState = GpsState.error;
        _gpsMessage = 'Erreur GPS.';
      });
    }
  }

  void _addFavorite(FavoriteRoute f) => setState(() => _favorites.add(f));
  void _removeFavorite(int i) => setState(() => _favorites.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(
        userPosition: _userPosition,
        gpsState: _gpsState,
        gpsMessage: _gpsMessage,
        onRequestLocation: _requestLocation,
      ),
      TripsPage(favorites: _favorites),
      const AlertsPage(),
      SettingsPage(
        favorites: _favorites,
        onAdd: _addFavorite,
        onRemove: _removeFavorite,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Reglages'),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EXPLORER AVEC CHARGEMENT ASYNCHRONE DES TRACÉS ROUTIERS
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition;
  final GpsState gpsState;
  final String? gpsMessage;
  final Future<void> Function() onRequestLocation;

  const ExplorerPage({
    super.key,
    required this.userPosition,
    required this.gpsState,
    required this.gpsMessage,
    required this.onRequestLocation,
  });

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';
  int _mapHeight = 240;
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Polyline> _dynamicPolylines = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadDynamicRoutes();
  }

  Future<void> _loadDynamicRoutes() async {
    List<Polyline> loaded = [];
    for (final route in demoRoutes) {
      if (route.points.length >= 2) {
        // Calcul des sous-segments via OSRM pour un alignement parfait sur la route
        List<LatLng> fullRoutePoints = [];
        for (int i = 0; i < route.points.length - 1; i++) {
          final segment = await RoutingService.getRealRoute(route.points[i], route.points[i+1]);
          if (fullRoutePoints.isNotEmpty && segment.isNotEmpty) {
            segment.removeAt(0);
          }
          fullRoutePoints.addAll(segment);
        }
        if (fullRoutePoints.isEmpty) fullRoutePoints = route.points;

        loaded.add(Polyline(
          points: fullRoutePoints,
          color: route.color,
          strokeWidth: 4.0,
        ));
      }
    }
    if (mounted) {
      setState(() {
        _dynamicPolylines = loaded;
        _isLoadingRoutes = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExplorerPage old) {
    super.didUpdateWidget(old);
    if (widget.userPosition != null && old.userPosition == null) {
      _mapController.move(widget.userPosition!, 14.5);
    }
  }

  List<Stop> get _filteredStops {
    List<Stop> base;
    switch (_selectedFilter) {
      case 'TER': base = allStops.where((s) => s.color == AppColors.ter).toList(); break;
      case 'BRT': base = allStops.where((s) => s.color == AppColors.brt).toList(); break;
      case 'AFTU': base = allStops.where((s) => s.color == AppColors.aftu).toList(); break;
      case 'Tata': base = allStops.where((s) => s.color == AppColors.tata).toList(); break;
      case 'DDD': base = allStops.where((s) => s.color == AppColors.ddd).toList(); break;
      default: base = List.from(allStops); break;
    }
    if (widget.userPosition != null) {
      base.sort((a, b) {
        final da = DistanceHelper.haversineMeters(widget.userPosition!, a.location);
        final db = DistanceHelper.haversineMeters(widget.userPosition!, b.location);
        return da.compareTo(db);
      });
    }
    return base;
  }

  double _distanceTo(Stop s) {
    if (widget.userPosition == null) return s.distanceMeters;
    return DistanceHelper.haversineMeters(widget.userPosition!, s.location);
  }

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) => s.name.toLowerCase().contains(q) || s.direction.toLowerCase().contains(q)).take(8).toList();
  }

  void _centerOnStop(Stop s) => _mapController.move(s.location, 14.5);
  void _openAI() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));

  void _cycleMapHeight() {
    setState(() {
      if (_mapHeight == 240) _mapHeight = 320;
      else if (_mapHeight == 320) _mapHeight = 140;
      else _mapHeight = 240;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;

    // Si les routes dynamiques ne sont pas encore chargées, on utilise les démos statiques terrestres
    final activePolylines = _dynamicPolylines.isNotEmpty
        ? _dynamicPolylines
        : demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 4.0)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _mapHeight.toDouble(),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _dakarCenter,
                      initialZoom: 11.5,
                      minZoom: 10,
                      maxZoom: 17,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dakar_bus',
                        maxZoom: 19,
                      ),
                      PolylineLayer(polylines: activePolylines),
                      MarkerLayer(
                        markers: mapPriorityStops
                            .map(
                              (s) => Marker(
                                point: s.location,
                                width: 24,
                                height: 24,
                                child: GestureDetector(
                                  onTap: () {
                                    _centerOnStop(s);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s)));
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: s.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
                                    ),
                                    child: Icon(s.icon, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (widget.userPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.userPosition!,
                              width: 18,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_isLoadingRoutes)
                    Positioned(
                      top: 10,
                      left: 140,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Ajustement route GPS...', style: TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                  Positioned(bottom: 12, left: 12, child: _gpsButton()),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Assistant IA', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _cycleMapHeight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
                        child: Icon(_mapHeight == 140 ? Icons.expand_more : Icons.expand_less, color: AppColors.primary, size: 20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _legend(AppColors.ter, 'TER'), const SizedBox(width: 6),
                          _legend(AppColors.brt, 'BRT'), const SizedBox(width: 6),
                          _legend(AppColors.aftu, 'AFTU'), const SizedBox(width: 6),
                          _legend(AppColors.tata, 'Tata'), const SizedBox(width: 6),
                          _legend(AppColors.ddd, 'DDD'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dakar Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('TER / BRT / AFTU / Tata / DDD (Tracés GPS réels)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const OfficialBadge(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() => _searchFocused = true),
                      onTap: () => setState(() => _searchFocused = true),
                      decoration: InputDecoration(
                        hintText: 'Ou voulez-vous aller ?',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchFocused ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: _searchResults.map((s) => ListTile(
                          dense: true,
                          leading: Icon(s.icon, color: s.color, size: 20),
                          title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(s.direction, style: const TextStyle(fontSize: 11)),
                          onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); },
                        )).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [_chip('Tous'), _chip('TER'), _chip('BRT'), _chip('AFTU'), _chip('Tata'), _chip('DDD')],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('${stops.length} arrêts', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...stops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _centerOnStop(s),
                      child: StopCard(stop: s, distanceMeters: _distanceTo(s)),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsButton() {
    switch (widget.gpsState) {
      case GpsState.loading:
        return FloatingActionButton.small(onPressed: null, backgroundColor: AppColors.surface, child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
      case GpsState.granted:
        return FloatingActionButton.small(onPressed: () { if (widget.userPosition != null) _mapController.move(widget.userPosition!, 14.5); }, backgroundColor: AppColors.surface, child: const Icon(Icons.my_location, color: AppColors.primary, size: 20));
      default:
        return FloatingActionButton.small(onPressed: () => widget.onRequestLocation(), backgroundColor: AppColors.surface, child: const Icon(Icons.location_searching, color: AppColors.primary, size: 20));
    }
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _chip(String label) {
    final color = _colorFor(label);
    final sel = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color : AppColors.divider, width: sel ? 2 : 1),
          ),
          child: Text(label, style: TextStyle(color: sel ? color : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
        ),
      ),
    );
  }

  Color _colorFor(String label) {
    switch (label) {
      case 'TER': return AppColors.ter;
      case 'BRT': return AppColors.brt;
      case 'AFTU': return AppColors.aftu;
      case 'Tata': return AppColors.tata;
      case 'DDD': return AppColors.ddd;
      default: return AppColors.primary;
    }
  }
}

// ============================================================
// CARTE D ARRET
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop;
  final double distanceMeters;

  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final next = stop.nextDepartureMinutes();
    final remaining = stop.remainingMinutes();

    Widget timeWidget;
    if (next == null || remaining == null) {
      timeWidget = const Text('Non dispo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    } else if (remaining <= 0) {
      timeWidget = Text('Imminent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stop.color));
    } else {
      timeWidget = Text(TimeHelper.formatRemaining(remaining), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success));
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
        leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white, size: 18)),
        title: Text(stop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('${stop.direction} . ${DistanceHelper.format(distanceMeters)}', style: const TextStyle(fontSize: 11)),
        trailing: timeWidget,
      ),
    );
  }
}

// ============================================================
// TRAJETS
// ============================================================
class TripsPage extends StatefulWidget {
  final List<FavoriteRoute> favorites;
  const TripsPage({super.key, required this.favorites});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final _fromCtrl = TextEditingController(text: 'Keur Mbaye Fall');
  final _toCtrl = TextEditingController(text: 'Dakar');
  bool _loading = false;
  RouteSearchResult? _result;

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _result = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    final res = RoutePlanner.plan(fromQuery: _fromCtrl.text, toQuery: _toCtrl.text);
    if (!mounted) return;
    setState(() { _loading = false; _result = res; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Planifier un trajet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'Départ', icon: Icon(Icons.my_location))),
                  const Divider(),
                  TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'Destination', icon: Icon(Icons.location_on))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                    child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Rechercher'),
                  ),
                ],
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              if (_result!.hasRoutes)
                ..._result!.routes.map((r) => Card(child: ListTile(title: Text('${r.fromName} ➔ ${r.toName}'), trailing: Text('${r.totalMinutes} min'))))
              else
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_result!.errorMessage ?? 'Aucun trajet'))),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ALERTES & REGLAGES
// ============================================================
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Alertes')), body: const Center(child: Text('Trafic normal sur le réseau.')));
}

class SettingsPage extends StatelessWidget {
  final List<FavoriteRoute> favorites;
  final Function(FavoriteRoute) onAdd;
  final Function(int) onRemove;
  const SettingsPage({super.key, required this.favorites, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Réglages')), body: ListView(padding: const EdgeInsets.all(16), children: const [ListTile(title: Text('Version Dakar Bus v2.6.0 (GPS Validé)'))]));
}

// ============================================================
// DETAIL DOUBLE SENS
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final opposite = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);
    return Scaffold(
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sens : ${stop.direction}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          if (opposite != null) Text('Arrêt opposé détecté : ${opposite.name}'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: const Center(child: Text('Comment puis-je vous aider sur vos trajets à Dakar ?')),
    );
  }
}
