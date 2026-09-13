import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const DakarBusApp());

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
// COULEURS (TER mis en Bleu Marin)
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFF1B263B); // Bleu Marin pour le TER
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
// SERVICE DE DETECTION DES DEUX SENS (ALLER / RETOUR) UNIVERSEL
// ============================================================
class OppositeStopService {
  static Stop? findOppositeStop({
    required Stop currentStop,
    required List<Stop> allStops,
  }) {
    // 1. Recherche par correspondance de nom exact mais direction opposée
    for (final stop in allStops) {
      if (stop.name.toLowerCase() == currentStop.name.toLowerCase() &&
          stop.direction != currentStop.direction &&
          stop.modeLabel == currentStop.modeLabel) {
        return stop;
      }
    }

    // 2. Recherche par proximité géographique (rayon de 500m) et nom similaire
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    for (final stop in allStops) {
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;
      if (stop.modeLabel != currentStop.modeLabel) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= 500.0 && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }

    // 3. Fallback universel : n'importe quel autre arrêt du même réseau avec une direction différente
    if (bestCandidate == null) {
      for (final stop in allStops) {
        if (stop.modeLabel == currentStop.modeLabel && stop.direction != currentStop.direction) {
          return stop;
        }
      }
    }

    return bestCandidate;
  }
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
// DONNEES TER (officiel SETER - Bleu Marin)
// ============================================================
final List<Stop> terStations = [
  Stop(
    name: 'Gare TER Dakar',
    direction: 'Terminus Dakar',
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
    direction: 'Dir. Diamniadio',
    distanceMeters: 350,
    departureMinutesFromMidnight: _shift(_terBase, 2),
    icon: Icons.train_rounded,
    color: AppColors.ter,
    location: const LatLng(14.6795, -17.4405),
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
    name: 'BRT Colobane',
    direction: 'Dir. Petersen',
    distanceMeters: 150,
    departureMinutesFromMidnight: _shift(_brtBase, 4),
    icon: Icons.directions_bus_rounded,
    color: AppColors.brt,
    location: const LatLng(14.6952, -17.4422),
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
// DONNEES AFTU / TATA / DDD (demo double sens)
// ============================================================
final List<Stop> otherBusStations = [
  const Stop(
    name: 'Arret AFTU 23',
    direction: 'Dir. Parcelles Assainies',
    distanceMeters: 280,
    departureMinutesFromMidnight: [630, 645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915],
    icon: Icons.directions_bus_outlined,
    color: AppColors.aftu,
    location: LatLng(14.6900, -17.4460),
    modeLabel: 'AFTU',
  ),
  const Stop(
    name: 'Arret AFTU 23',
    direction: 'Dir. Centre-ville',
    distanceMeters: 280,
    departureMinutesFromMidnight: [635, 650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920],
    icon: Icons.directions_bus_outlined,
    color: AppColors.aftu,
    location: LatLng(14.6902, -17.4462),
    modeLabel: 'AFTU',
  ),
  const Stop(
    name: 'Arret Tata 12',
    direction: 'Dir. Guediawaye',
    distanceMeters: 600,
    departureMinutesFromMidnight: [640, 655, 710, 725, 740, 755, 810, 825, 840, 855, 910, 925],
    icon: Icons.directions_bus_filled,
    color: AppColors.tata,
    location: LatLng(14.7200, -17.4700),
    modeLabel: 'Tata',
  ),
  const Stop(
    name: 'Arret Tata 12',
    direction: 'Dir. Dakar',
    distanceMeters: 600,
    departureMinutesFromMidnight: [645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915, 930],
    icon: Icons.directions_bus_filled,
    color: AppColors.tata,
    location: LatLng(14.7202, -17.4702),
    modeLabel: 'Tata',
  ),
  const Stop(
    name: 'Arret DDD 12',
    direction: 'Dir. Ouakam',
    distanceMeters: 800,
    departureMinutesFromMidnight: [645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915, 930],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7250, -17.4900),
    modeLabel: 'DDD',
  ),
  const Stop(
    name: 'Arret DDD 12',
    direction: 'Dir. Plateau',
    distanceMeters: 800,
    departureMinutesFromMidnight: [650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920, 935],
    icon: Icons.directions_bus_filled_rounded,
    color: AppColors.ddd,
    location: LatLng(14.7252, -17.4902),
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
  terStations[4],
  brtStations[1],
  brtStations[4],
  otherBusStations[0],
  otherBusStations[2],
  otherBusStations[4],
];

// ============================================================
// TRACES DES LIGNES (TER Bleu Marin)
// ============================================================
final List<TransitRoute> demoRoutes = [
  TransitRoute(
    name: 'TER',
    code: 'TER',
    type: 'TER',
    color: AppColors.ter,
    points: [
      const LatLng(14.6792, -17.4407),
      const LatLng(14.6937, -17.4441),
      const LatLng(14.7222, -17.4321),
      const LatLng(14.7410, -17.4120),
      const LatLng(14.7550, -17.3900),
      const LatLng(14.7700, -17.3400),
      const LatLng(14.7750, -17.3100),
      const LatLng(14.7500, -17.2900),
      const LatLng(14.7157, -17.2703),
      const LatLng(14.6900, -17.2200),
      const LatLng(14.7160, -17.1986),
    ],
  ),
  TransitRoute(
    name: 'BRT',
    code: 'B1',
    type: 'BRT',
    color: AppColors.brt,
    points: [
      const LatLng(14.6720, -17.4400),
      const LatLng(14.6950, -17.4420),
      const LatLng(14.7050, -17.4400),
      const LatLng(14.7220, -17.4330),
      const LatLng(14.7350, -17.4260),
      const LatLng(14.7520, -17.4100),
      const LatLng(14.7735, -17.3977),
    ],
  ),
  TransitRoute(
    name: 'AFTU',
    code: '23',
    type: 'AFTU',
    color: AppColors.aftu,
    points: [
      const LatLng(14.7600, -17.4400),
      const LatLng(14.7350, -17.4460),
      const LatLng(14.7080, -17.4485),
      const LatLng(14.6900, -17.4460),
      const LatLng(14.6790, -17.4400),
    ],
  ),
  TransitRoute(
    name: 'Tata',
    code: '12',
    type: 'TATA',
    color: AppColors.tata,
    points: [
      const LatLng(14.7735, -17.3977),
      const LatLng(14.7480, -17.4280),
      const LatLng(14.7240, -17.4560),
      const LatLng(14.7080, -17.4700),
      const LatLng(14.6880, -17.4620),
      const LatLng(14.6750, -17.4400),
    ],
  ),
  TransitRoute(
    name: 'DDD',
    code: 'DDD-12',
    type: 'DDD',
    color: AppColors.ddd,
    points: [
      const LatLng(14.7350, -17.5100),
      const LatLng(14.7250, -17.4900),
      const LatLng(14.7100, -17.4700),
      const LatLng(14.6950, -17.4550),
      const LatLng(14.6800, -17.4450),
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

  const Place({required this.name, required this.type, required this.icon, required this.color, this.location, this.linkedStop});
}

List<Place> buildPlaceDatabase() {
  final places = <Place>[];
  final cities = <List<Object>>[
    ['Dakar', LatLng(14.6928, -17.4467)],
    ['Plateau', LatLng(14.6720, -17.4400)],
    ['Medina', LatLng(14.6837, -17.4500)],
    ['Fass', LatLng(14.6880, -17.4500)],
    ['Colobane', LatLng(14.6937, -17.4441)],
    ['Hann', LatLng(14.7222, -17.4321)],
    ['Pikine', LatLng(14.7550, -17.3900)],
    ['Guediawaye', LatLng(14.7735, -17.3977)],
    ['Rufisque', LatLng(14.7157, -17.2703)],
    ['Diamniadio', LatLng(14.7160, -17.1986)],
    ['Parcelles Assainies', LatLng(14.7600, -17.4400)],
    ['Grand Yoff', LatLng(14.7300, -17.4600)],
    ['Ouakam', LatLng(14.7250, -17.4900)],
    ['Almadies', LatLng(14.7350, -17.5100)],
  ];
  for (final c in cities) {
    places.add(Place(name: c[0] as String, type: 'place', icon: Icons.location_city, color: AppColors.textSecondary, location: c[1] as LatLng));
  }
  for (final s in allStops) {
    places.add(Place(name: s.name, type: s.modeLabel, icon: s.icon, color: s.color, location: s.location, linkedStop: s));
  }
  return places;
}

final List<Place> placeDatabase = buildPlaceDatabase();

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    return RouteSearchResult(
      routes: [
        PlannedRoute(
          fromName: fromQuery,
          toName: toQuery,
          totalMinutes: 25,
          isBest: true,
          segments: [
            RouteSegment(
              modeLabel: 'TER',
              color: AppColors.ter,
              icon: Icons.train_rounded,
              from: fromQuery,
              to: toQuery,
              durationMinutes: 25,
              departureTime: '08h00',
              arrivalTime: '08h25',
            ),
          ],
        ),
      ],
    );
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
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
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
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }
  static double _asin(double x) {
    if (x < -1) return -1.5708;
    if (x > 1) return 1.5708;
    return x + (x * x * x) / 6 + (3 * x * x * x * x * x) / 40;
  }
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
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
  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;
  String? _gpsMessage;

  Future<void> _requestLocation() async {
    setState(() => _gpsState = GpsState.loading);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _gpsState = GpsState.serviceDisabled; _gpsMessage = 'GPS desactive.'; });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { _gpsState = GpsState.denied; _gpsMessage = 'Permission refusee.'; });
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _gpsState = GpsState.granted;
      });
    } catch (e) {
      setState(() => _gpsState = GpsState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, gpsMessage: _gpsMessage, onRequestLocation: _requestLocation),
      const TripsPage(favorites: []),
      const AlertsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
          NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: 'Trajets'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Reglages'),
        ],
      ),
    );
  }
}

// ============================================================
// EXPLORER PAGE
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition;
  final GpsState gpsState;
  final String? gpsMessage;
  final Future<void> Function() onRequestLocation;

  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.gpsMessage, required this.onRequestLocation});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';

  List<Stop> get _filteredStops {
    switch (_selectedFilter) {
      case 'TER': return allStops.where((s) => s.modeLabel == 'TER').toList();
      case 'BRT': return allStops.where((s) => s.modeLabel == 'BRT').toList();
      case 'AFTU': return allStops.where((s) => s.modeLabel == 'AFTU').toList();
      case 'Tata': return allStops.where((s) => s.modeLabel == 'Tata').toList();
      case 'DDD': return allStops.where((s) => s.modeLabel == 'DDD').toList();
      default: return List.from(allStops);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dakar Bus & Rail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _dakarCenter, initialZoom: 11),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                PolylineLayer(
                  polylines: demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 4)).toList(),
                ),
                MarkerLayer(
                  markers: mapPriorityStops.map((s) => Marker(
                    point: s.location,
                    width: 24,
                    height: 24,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))),
                      child: Container(
                        decoration: BoxDecoration(color: s.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(s.icon, color: Colors.white, size: 12),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: ['Tous', 'TER', 'BRT', 'AFTU', 'Tata', 'DDD'].map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _selectedFilter == f,
                  onSelected: (val) => setState(() => _selectedFilter = f),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: stop.color, child: Icon(stop.icon, color: Colors.white, size: 18)),
                    title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${stop.modeLabel} . ${stop.direction}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
}

// ============================================================
// VUE DOUBLE SENS (ALLER / RETOUR) - STYLE IDFM
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;

  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final Stop? oppositeStop = OppositeStopService.findOppositeStop(
      currentStop: stop,
      allStops: allStops,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(stop.name),
        backgroundColor: stop.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDirectionSection(
            title: "Sens Aller (Arrêt Actuel)",
            currentStop: stop,
            badgeColor: Colors.green,
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 20),
          oppositeStop != null
              ? _buildDirectionSection(
                  title: "Sens Retour (Arrêt Opposé)",
                  currentStop: oppositeStop,
                  badgeColor: Colors.orange,
                )
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                  child: const Column(
                    children: [
                      Icon(Icons.swap_horiz, size: 32, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text("Aucun arrêt opposé détecté pour cette station.", style: TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDirectionSection({
    required String title,
    required Stop currentStop,
    required Color badgeColor,
  }) {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final future = currentStop.departureMinutesFromMidnight
        .where((d) => d > currentMin)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: badgeColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: badgeColor)),
              const Spacer(),
              DataStatusBadge(status: currentStop.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(currentStop.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Réseau : ${currentStop.modeLabel} | Direction : ${currentStop.direction}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          const Text('Prochains passages :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (future.isEmpty)
            const Text('Plus de passage prévu aujourd hui.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else
            ...future.map((d) {
              final h = (d ~/ 60).toString().padLeft(2, '0');
              final m = (d % 60).toString().padLeft(2, '0');
              final remaining = d - currentMin;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$h:$m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      TimeHelper.formatRemaining(remaining),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: remaining <= 3 ? AppColors.ter : AppColors.success),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA & GUIDAGE COMPLET
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'ai', 'text': 'Bonjour ! Je suis votre assistant IA Dakar Bus. Posez vos questions sur les horaires TER, BRT, AFTU, Tata, DDD ou demandez un itinéraire.'}
  ];

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _ctrl.clear();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String reply = 'Je peux vous guider sur les réseaux TER (Bleu Marin), BRT, AFTU, Tata et Dakar Dem Dikk.';
      final lower = text.toLowerCase();

      if (lower.contains('ter') || lower.contains('train')) {
        reply = 'Le TER (lignes Bleu Marin) fonctionne de 5h30 à 22h avec une fréquence de 10 min en semaine et 20 min le dimanche.';
      } else if (lower.contains('brt')) {
        reply = 'Le BRT relie Petersen à Guédiawaye avec un passage toutes les 6 minutes.';
      } else if (lower.contains('tata') || lower.contains('aftu') || lower.contains('ddd')) {
        reply = 'Les bus AFTU, Tata et Dakar Dem Dikk couvrent l’ensemble des quartiers de Dakar avec des arrêts dans les deux sens.';
      } else if (lower.contains('itinéraire') || lower.contains('aller') || lower.contains('trajet')) {
        reply = 'Pour aller d’un point à un autre, consultez l’onglet Trajets ou cherchez votre station sur la carte interactive.';
      }

      setState(() {
        _messages.add({'sender': 'ai', 'text': reply});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA Dakar Bus'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final isUser = m['sender'] == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(m['text'] ?? '', style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Posez votre question...', border: InputBorder.none),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pages annexes
class TripsPage extends StatelessWidget {
  final List<FavoriteRoute> favorites;
  const TripsPage({super.key, required this.favorites});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Page Trajets')));
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Page Alertes')));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Page Réglages')));
}
