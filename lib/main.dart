import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
  static final Map<String, List<LatLng>> _cache = {};

  static String _cacheKey(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}|${b.latitude.toStringAsFixed(5)},${b.longitude.toStringAsFixed(5)}';

  static Future<List<LatLng>> getRealRoute(LatLng start, LatLng end) async {
    final key = _cacheKey(start, end);
    if (_cache.containsKey(key)) return _cache[key]!;

    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        final points = coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        _cache[key] = points;
        return points;
      }
    } catch (_) {}
    final fallback = _getFallbackTerrestrialRoute(start, end);
    _cache[key] = fallback;
    return fallback;
  }

  static List<LatLng> _getFallbackTerrestrialRoute(LatLng start, LatLng end) {
    if (start.latitude > 14.70 && end.latitude > 14.70 && (start.longitude - end.longitude).abs() > 0.05) {
      return [
        start, const LatLng(14.7410, -17.4120), const LatLng(14.7550, -17.3900),
        const LatLng(14.7588, -17.3803), const LatLng(14.7450, -17.3980), end,
      ];
    }
    return [start, end];
  }
}

// ============================================================
// SERVICE DE DETECTION DES DEUX SENS
// ============================================================
class OppositeStopService {
  static const double _maxOppositeDistanceMeters = 500.0;

  static Stop? findOppositeStop({required Stop currentStop, required List<Stop> allStops}) {
    Stop? bestCandidate;
    double minDistance = double.infinity;
    final currentName = currentStop.name.toLowerCase();

    for (final stop in allStops) {
      if (identical(stop, currentStop)) continue;
      if (stop.name == currentStop.name && stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= 50.0 && distance < minDistance) {
        final stopName = stop.name.toLowerCase();
        if (currentName.contains(stopName) || stopName.contains(currentName)) {
          minDistance = distance;
          bestCandidate = stop;
        }
      }
    }
    if (bestCandidate != null) return bestCandidate;

    for (final stop in allStops) {
      if (identical(stop, currentStop)) continue;
      if (stop.modeLabel != currentStop.modeLabel) continue;
      if (stop.direction == currentStop.direction) continue;

      final double distance = DistanceHelper.haversineMeters(currentStop.location, stop.location);
      if (distance <= _maxOppositeDistanceMeters && distance < minDistance) {
        minDistance = distance;
        bestCandidate = stop;
      }
    }
    return bestCandidate;
  }
}

// ============================================================
// GENERATEUR D HORAIRES
// ============================================================
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) { list.add(m); }
  return list;
}
List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);
final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
final List<int> _terBase = _buildTerBase();

// ============================================================
// COULEURS & THEME
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
// SOURCE DE DONNEES & STATUT
// ============================================================
enum DataOrigin { official, demo }
class DataSourceInfo {
  final DataOrigin origin; final String label;
  const DataSourceInfo({required this.origin, required this.label});
  static const seter = DataSourceInfo(origin: DataOrigin.official, label: 'SETER');
  static const sunubrt = DataSourceInfo(origin: DataOrigin.official, label: 'SunuBRT');
  static const demo = DataSourceInfo(origin: DataOrigin.demo, label: 'Demonstration');
}

enum DataStatus { scheduled, live, unknown }
class DataStatusBadge extends StatelessWidget {
  final DataStatus status; final bool compact;
  const DataStatusBadge({super.key, required this.status, this.compact = false});
  @override
  Widget build(BuildContext context) {
    Color color; String label; IconData? icon; bool dotOnly = false;
    switch (status) {
      case DataStatus.live: color = AppColors.success; label = 'LIVE'; dotOnly = true; break;
      case DataStatus.scheduled: color = AppColors.warning; label = 'Programme'; icon = Icons.schedule; break;
      case DataStatus.unknown: color = AppColors.neutral; label = 'Indisponible'; icon = Icons.help_outline; break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dotOnly) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
        else if (icon != null) Icon(icon, size: compact ? 10 : 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: compact ? 9 : 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3)),
      ]),
    );
  }
}

class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.success.withOpacity(0.35), width: 0.8)),
    child: const Text('OFFICIEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 0.5)),
  );
}

// ============================================================
// MODELES
// ============================================================
enum StopType { arrival, departure, boarding, terminus, correspondence }

class Stop {
  final String name; final String direction; final double distanceMeters;
  final List<int> departureMinutesFromMidnight; final IconData icon;
  final Color color; final LatLng location; final DataStatus status;
  final String modeLabel; final DataSourceInfo source;
  final StopType stopType;

  const Stop({
    required this.name, required this.direction, required this.distanceMeters,
    required this.departureMinutesFromMidnight, required this.icon, required this.color,
    required this.location, required this.modeLabel, this.status = DataStatus.scheduled,
    this.source = DataSourceInfo.demo, this.stopType = StopType.departure,
  });

  Stop copyWith({
    String? name, String? direction, double? distanceMeters,
    List<int>? departureMinutesFromMidnight, IconData? icon, Color? color,
    LatLng? location, DataStatus? status, String? modeLabel,
    DataSourceInfo? source, StopType? stopType,
  }) => Stop(
    name: name ?? this.name,
    direction: direction ?? this.direction,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    departureMinutesFromMidnight: departureMinutesFromMidnight ?? this.departureMinutesFromMidnight,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    location: location ?? this.location,
    status: status ?? this.status,
    modeLabel: modeLabel ?? this.modeLabel,
    source: source ?? this.source,
    stopType: stopType ?? this.stopType,
  );

  int? nextDepartureMinutes() {
    final now = DateTime.now(); final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) { if (d > currentMin) return d; }
    if (departureMinutesFromMidnight.isNotEmpty) return departureMinutesFromMidnight.first + 24 * 60;
    return null;
  }
  int? remainingMinutes() { final d = nextDepartureMinutes(); if (d == null) return null; return d - (DateTime.now().hour * 60 + DateTime.now().minute); }
  String? nextDepartureLabel() { final d = nextDepartureMinutes(); if (d == null) return null; final normalized = d % (24 * 60); return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}'; }
  int? departureAfter(int minFromMidnight) { for (final d in departureMinutesFromMidnight) { if (d > minFromMidnight) return d; } if (departureMinutesFromMidnight.isNotEmpty) return departureMinutesFromMidnight.first + 24 * 60; return null; }
}

class TransitRoute {
  final String name; final String code; final String type; final Color color; final List<LatLng> points;
  const TransitRoute({required this.name, required this.code, required this.type, required this.color, required this.points});

  bool get isDedicated => type == 'TER' || type == 'BRT';
}

class FavoriteRoute {
  final String label; final String from; final String to; final IconData icon;
  const FavoriteRoute({required this.label, required this.from, required this.to, required this.icon});
}

class RouteSegment {
  final String modeLabel; final Color color; final IconData icon;
  final String from; final String to; final int durationMinutes;
  final String? departureTime; final String? arrivalTime;
  final DataStatus status; final bool isWalk;
  const RouteSegment({required this.modeLabel, required this.color, required this.icon, required this.from, required this.to, required this.durationMinutes, this.departureTime, this.arrivalTime, this.status = DataStatus.scheduled, this.isWalk = false});
}

class PlannedRoute {
  final String fromName; final String toName; final List<RouteSegment> segments;
  final int totalMinutes; final bool isBest; final DataStatus status; final int transferCount;
  const PlannedRoute({required this.fromName, required this.toName, required this.segments, required this.totalMinutes, this.isBest = false, this.status = DataStatus.scheduled, this.transferCount = 0});
}

class RouteSearchResult {
  final List<PlannedRoute> routes; final List<String> missingData; final String? errorMessage;
  const RouteSearchResult({this.routes = const [], this.missingData = const [], this.errorMessage});
  bool get hasRoutes => routes.isNotEmpty;
}

// ============================================================
// DONNEES (TER, BRT, AFTU, Tata, DDD)
// ============================================================
final List<Stop> terStations = [
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Dakar', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6935, -17.4443), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7222, -17.4321), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Dakar', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 7), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7220, -17.4323), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Dalifort', direction: 'Dir. Diamniadio', distanceMeters: 5100, departureMinutesFromMidnight: _shift(_terBase, 12), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7410, -17.4120), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Dalifort', direction: 'Dir. Dakar', distanceMeters: 5100, departureMinutesFromMidnight: _shift(_terBase, 10), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7412, -17.4122), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Baux Maraichers', direction: 'Dir. Diamniadio', distanceMeters: 6300, departureMinutesFromMidnight: _shift(_terBase, 14), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7470, -17.4010), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: _shift(_terBase, 17), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7550, -17.3900), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Thiaroye', direction: 'Dir. Diamniadio', distanceMeters: 8100, departureMinutesFromMidnight: _shift(_terBase, 20), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7588, -17.3803), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Yeumbeul', direction: 'Dir. Diamniadio', distanceMeters: 11500, departureMinutesFromMidnight: _shift(_terBase, 24), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7700, -17.3400), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Dakar / Diamniadio', distanceMeters: 14200, departureMinutesFromMidnight: _shift(_terBase, 27), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7750, -17.3100), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.correspondence),
  Stop(name: 'Gare TER PNR', direction: 'Dir. Diamniadio', distanceMeters: 16800, departureMinutesFromMidnight: _shift(_terBase, 30), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7500, -17.2900), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio', distanceMeters: 22100, departureMinutesFromMidnight: _shift(_terBase, 36), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7157, -17.2703), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Bargny', direction: 'Dir. Diamniadio', distanceMeters: 28500, departureMinutesFromMidnight: _shift(_terBase, 42), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6900, -17.2200), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 50), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7160, -17.1986), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.terminus),
];

final List<Stop> brtStations = [
  Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: _shift(_brtBase, 0), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6720, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guediawaye', distanceMeters: 1500, departureMinutesFromMidnight: _shift(_brtBase, 4), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7050, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'BRT Parcelles', direction: 'Dir. Guediawaye', distanceMeters: 5000, departureMinutesFromMidnight: _shift(_brtBase, 6), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7350, -17.4260), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'PEM Guediawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: _shift(_brtBase, 8), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7735, -17.3977), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
];

final List<Stop> otherBusStations = [
  const Stop(name: 'Arret AFTU 23', direction: 'Dir. Parcelles Assainies', distanceMeters: 280, departureMinutesFromMidnight: [630, 645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460), modeLabel: 'AFTU', stopType: StopType.boarding),
  const Stop(name: 'Arret AFTU 10', direction: 'Dir. Grand Yoff', distanceMeters: 450, departureMinutesFromMidnight: [635, 650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.7200, -17.4600), modeLabel: 'AFTU', stopType: StopType.boarding),
  const Stop(name: 'Arret Tata 12', direction: 'Dir. Guediawaye', distanceMeters: 600, departureMinutesFromMidnight: [640, 655, 710, 725, 740, 755, 810, 825, 840, 855, 910, 925], icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700), modeLabel: 'Tata', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 1', direction: 'Parcelles Assainies - Place Leclerc', distanceMeters: 350, departureMinutesFromMidnight: [360, 420, 480, 540, 600, 660, 720, 780, 840, 900, 960], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7600, -17.4400), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 4', direction: 'Liberté 5 - Place Leclerc', distanceMeters: 420, departureMinutesFromMidnight: [370, 430, 490, 550, 610, 670, 730, 790, 850, 910, 970], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7150, -17.4600), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 7', direction: 'Ouakam - Palais 2', distanceMeters: 500, departureMinutesFromMidnight: [380, 440, 500, 560, 620, 680, 740, 800, 860, 920, 980], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 8', direction: 'Aéroport LSS - Palais 2', distanceMeters: 600, departureMinutesFromMidnight: [390, 450, 510, 570, 630, 690, 750, 810, 870, 930], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7550, -17.4750), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 9', direction: 'Liberté 6 - Palais 2', distanceMeters: 650, departureMinutesFromMidnight: [400, 460, 520, 580, 640, 700, 760, 820, 880, 940], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4650), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 217', direction: 'Thiaroye - Ouakam', distanceMeters: 850, departureMinutesFromMidnight: [360, 440, 520, 600, 680, 760, 840, 920], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7588, -17.3803), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 218', direction: 'Thiaroye - Djiolof Chicken Almadie', distanceMeters: 900, departureMinutesFromMidnight: [370, 450, 530, 610, 690, 770, 850, 930], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7588, -17.3803), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 219', direction: 'Daroukhane - Ouakam', distanceMeters: 950, departureMinutesFromMidnight: [380, 460, 540, 620, 700, 780, 860, 940], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7200, -17.4900), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 220', direction: 'Rufisque - Guédiawaye', distanceMeters: 1100, departureMinutesFromMidnight: [390, 470, 550, 630, 710, 790, 870, 950], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7157, -17.2703), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 221', direction: 'Gadaye - Almadies', distanceMeters: 1200, departureMinutesFromMidnight: [400, 480, 560, 640, 720, 800, 880, 960], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7700, -17.4300), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 227', direction: 'Keur Massar - Parcelles Assainies', distanceMeters: 1300, departureMinutesFromMidnight: [410, 490, 570, 650, 730, 810, 890, 970], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7900, -17.3500), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 401', direction: 'Ouakam - Aéroport Diass (AIBD)', distanceMeters: 2500, departureMinutesFromMidnight: [420, 540, 660, 780, 900], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 402', direction: 'Thiaroye - Aéroport Diass (AIBD)', distanceMeters: 2600, departureMinutesFromMidnight: [430, 550, 670, 790, 910], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7588, -17.3803), modeLabel: 'DDD', stopType: StopType.boarding),
  const Stop(name: 'Ligne DDD 403', direction: 'Parcelles Assainies - Aéroport Diass (AIBD)', distanceMeters: 2700, departureMinutesFromMidnight: [440, 560, 680, 800, 920], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7600, -17.4400), modeLabel: 'DDD', stopType: StopType.boarding),
];

final List<Stop> allStops = [...terStations, ...brtStations, ...otherBusStations];

// ============================================================
// TRACES DES LIGNES
// ============================================================
final List<TransitRoute> demoRoutes = [
  const TransitRoute(
    name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter,
    points: [
      LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7222, -17.4321),
      LatLng(14.7410, -17.4120), LatLng(14.7550, -17.3900), LatLng(14.7700, -17.3400),
      LatLng(14.7750, -17.3100), LatLng(14.7500, -17.2900), LatLng(14.7157, -17.2703),
      LatLng(14.6900, -17.2200), LatLng(14.7160, -17.1986),
    ],
  ),
  const TransitRoute(
    name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt,
    points: [
      LatLng(14.6720, -17.4400), LatLng(14.6950, -17.4420), LatLng(14.7050, -17.4400),
      LatLng(14.7220, -17.4330), LatLng(14.7350, -17.4260), LatLng(14.7520, -17.4100),
      LatLng(14.7735, -17.3977),
    ],
  ),
  const TransitRoute(
    name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu,
    points: [
      LatLng(14.7600, -17.4400), LatLng(14.7450, -17.4430), LatLng(14.7200, -17.4460),
      LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400),
    ],
  ),
  const TransitRoute(
    name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata,
    points: [
      LatLng(14.7735, -17.3977), LatLng(14.7500, -17.4200), LatLng(14.7250, -17.4500),
      LatLng(14.7000, -17.4600), LatLng(14.6800, -17.4500), LatLng(14.6750, -17.4400),
    ],
  ),
  const TransitRoute(
    name: 'DDD Urbaine', code: 'DDD-1', type: 'DDD', color: AppColors.ddd,
    points: [
      LatLng(14.7600, -17.4400), LatLng(14.7450, -17.4440), LatLng(14.7250, -17.4520),
      LatLng(14.7050, -17.4560), LatLng(14.6900, -17.4480), LatLng(14.6790, -17.4420),
      LatLng(14.6720, -17.4400),
    ],
  ),
];

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    final fromStop = _findNearestStop(fromQuery);
    final toStop = _findNearestStop(toQuery);

    if (fromStop == null) return const RouteSearchResult(errorMessage: 'Lieu de depart introuvable.');
    if (toStop == null) return const RouteSearchResult(errorMessage: 'Destination introuvable.');

    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final candidates = <PlannedRoute>[];

    if (fromStop.modeLabel == toStop.modeLabel) {
      final direct = _buildRoute(fromStop, toStop, currentMin);
      if (direct != null) candidates.add(direct);
    }

    if (candidates.isEmpty || candidates.first.totalMinutes > 45) {
      final transfer = _findTransfer(fromStop, toStop, currentMin);
      if (transfer != null) candidates.add(transfer);
    }

    if (candidates.isEmpty) {
      return RouteSearchResult(errorMessage: 'Aucun itineraire trouve entre ${fromStop.name} et ${toStop.name}.');
    }

    candidates.sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));
    return RouteSearchResult(routes: candidates);
  }

  static Stop? _findNearestStop(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final s in allStops) {
      if (s.name.toLowerCase().contains(q)) return s;
    }
    return allStops.firstWhere((s) => s.name.toLowerCase().contains('dakar'), orElse: () => allStops.first);
  }

  static PlannedRoute? _buildRoute(Stop from, Stop to, int currentMin) {
    final safeCurrentMin = math.max(0, currentMin - 1);
    final dep = from.departureAfter(safeCurrentMin);
    if (dep == null) return null;
    final dist = DistanceHelper.haversineMeters(from.location, to.location);
    final speed = (from.modeLabel == 'TER' || from.modeLabel == 'BRT') ? 30.0 : 15.0;
    final dur = ((dist / 1000.0) / speed * 60).ceil();
    final arr = dep + dur;

    return PlannedRoute(
      fromName: from.name, toName: to.name, totalMinutes: arr - currentMin,
      transferCount: 0, status: DataStatus.scheduled,
      segments: [RouteSegment(modeLabel: from.modeLabel, color: from.color, icon: from.icon, from: from.name, to: to.name, durationMinutes: dur, departureTime: _formatMin(dep), arrivalTime: _formatMin(arr), status: DataStatus.scheduled)],
    );
  }

  static PlannedRoute? _findTransfer(Stop from, Stop to, int currentMin) {
    final hub = allStops.firstWhere((s) => s.name.contains('Colobane') || s.name.contains('Petersen'), orElse: () => allStops.first);
    if (hub.name == from.name || hub.name == to.name) return null;

    final leg1 = _buildRoute(from, hub, currentMin);
    if (leg1 == null) return null;
    final leg2 = _buildRoute(hub, to, (currentMin + leg1.totalMinutes));
    if (leg2 == null) return null;

    return PlannedRoute(
      fromName: from.name, toName: to.name,
      totalMinutes: leg1.totalMinutes + leg2.totalMinutes + 5,
      transferCount: 1, status: DataStatus.scheduled,
      segments: [...leg1.segments, ...leg2.segments],
    );
  }

  static String _formatMin(int minFromMidnight) {
    final normalized = minFromMidnight % (24 * 60);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}';
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
}

class DistanceHelper {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }

  static double haversineMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371000.0;
    final double lat1 = a.latitude * math.pi / 180.0;
    final double lat2 = b.latitude * math.pi / 180.0;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final double h = (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }
}

// ============================================================
// INVERSEUR DE DIRECTION
// ============================================================
class DirectionHelper {
  static String reverse(String direction) {
    if (direction.contains('-')) {
      final parts = direction.split('-').map((s) => s.trim()).toList();
      if (parts.length == 2) return '${parts[1]} - ${parts[0]}';
    }
    if (direction.contains('Dir. Dakar / Diamniadio')) {
      return direction.replaceAll('Dir. Dakar / Diamniadio', 'Dir. Diamniadio / Dakar');
    }
    if (direction.contains('Arrivée')) {
      return direction.replaceAll('Arrivée', 'Embarquement');
    }
    if (direction.contains('Embarquement')) {
      return direction.replaceAll('Embarquement', 'Arrivée');
    }
    if (direction.startsWith('Dir. ')) {
      return direction.replaceFirst('Dir. ', 'Dir. retour vers ');
    }
    if (direction.startsWith('Terminus ')) {
      return 'Dir. retour depuis ${direction.substring(9)}';
    }
    return 'Sens inverse - $direction';
  }

  static StopType oppositeType(StopType type) {
    switch (type) {
      case StopType.arrival: return StopType.boarding;
      case StopType.boarding: return StopType.arrival;
      case StopType.terminus: return StopType.terminus;
      case StopType.correspondence: return StopType.correspondence;
      case StopType.departure: return StopType.departure;
    }
  }
}

// ============================================================
// BASE DE CONNAISSANCE IA
// ============================================================
const Map<String, String> kDakarLocationAliases = {
  'mermoz': 'Liberté 5',
  'plateau': 'Place Leclerc',
  'medina': 'Place Leclerc',
  'médina': 'Place Leclerc',
  'sacre coeur': 'Liberté 5',
  'sacré coeur': 'Liberté 5',
  'point e': 'Liberté 5',
  'parcelles': 'Parcelles Assainies',
  'parcelles assainies': 'Parcelles Assainies',
  'ouakam': 'Ouakam',
  'pikine': 'Pikine',
  'guediawaye': 'Guediawaye',
  'guédiawaye': 'Guediawaye',
  'keur massar': 'Keur Massar',
  'thiaroye': 'Thiaroye',
  'rufisque': 'Rufisque',
  'diamniadio': 'Diamniadio',
  'aibd': 'Aéroport Diass',
  'petersen': 'PEM Petersen',
  'colobane': 'Colobane',
  'hann': 'Hann',
  'dalifort': 'Dalifort',
  'baux maraichers': 'Baux Maraichers',
  'yeumbeul': 'Yeumbeul',
  'keur mbaye fall': 'Keur Mbaye Fall',
  'pnr': 'PNR',
  'bargny': 'Bargny',
  'liberte 5': 'Liberté 5',
  'liberté 5': 'Liberté 5',
  'liberte 6': 'Liberté 6',
  'liberté 6': 'Liberté 6',
  'daroukhane': 'Daroukhane',
  'gadaye': 'Gadaye',
};

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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
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
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  Future<void> _requestLocation() async {
    setState(() { _gpsState = GpsState.loading; _gpsMessage = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() { _gpsState = GpsState.serviceDisabled; _gpsMessage = 'GPS desactive.'; }); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _gpsState = GpsState.denied; _gpsMessage = 'Permission GPS refusee.'; }); return;
      }
      // CORRECTION WEB GEOLOCATOR (compatible dart2js / webassembly)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() { _userPosition = LatLng(position.latitude, position.longitude); _gpsState = GpsState.granted; _gpsMessage = null; });
    } catch (_) { setState(() { _gpsState = GpsState.error; _gpsMessage = 'Erreur GPS.'; }); }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, gpsMessage: _gpsMessage, onRequestLocation: _requestLocation),
      TripsPage(favorites: _favorites),
      const AlertsPage(),
      SettingsPage(favorites: _favorites, onAdd: (f) => setState(() => _favorites.add(f)), onRemove: (i) => setState(() => _favorites.removeAt(i))),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 68,
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
// EXPLORER
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition; final GpsState gpsState; final String? gpsMessage; final Future<void> Function() onRequestLocation;
  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.gpsMessage, required this.onRequestLocation});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  final LatLng _dakarCenter = const LatLng(14.7200, -17.4300);
  String _selectedFilter = 'Tous';
  int _mapHeight = 260;
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Polyline> _dynamicPolylines = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() { super.initState(); _loadDynamicRoutes(); }

  Future<void> _loadDynamicRoutes() async {
    final List<Polyline> loaded = [];

    for (final route in demoRoutes) {
      if (route.points.length < 2) continue;

      List<LatLng> fullRoutePoints = [];

      if (route.isDedicated) {
        fullRoutePoints = List<LatLng>.from(route.points);
      } else {
        final List<Future<List<LatLng>>> futures = [];
        for (int i = 0; i < route.points.length - 1; i++) {
          futures.add(RoutingService.getRealRoute(route.points[i], route.points[i + 1]));
        }
        final List<List<LatLng>> segments = await Future.wait(futures);
        for (final segment in segments) {
          if (fullRoutePoints.isNotEmpty && segment.isNotEmpty) {
            fullRoutePoints.addAll(segment.skip(1));
          } else {
            fullRoutePoints.addAll(segment);
          }
        }
        if (fullRoutePoints.isEmpty) fullRoutePoints = List<LatLng>.from(route.points);
      }

      loaded.add(Polyline(
        points: fullRoutePoints,
        color: route.color,
        strokeWidth: route.isDedicated ? 6.0 : 4.5,
      ));
    }

    if (mounted) setState(() { _dynamicPolylines = loaded; _isLoadingRoutes = false; });
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
      base.sort((a, b) => DistanceHelper.haversineMeters(widget.userPosition!, a.location).compareTo(DistanceHelper.haversineMeters(widget.userPosition!, b.location)));
    }
    return base;
  }

  double _distanceTo(Stop s) => widget.userPosition == null ? s.distanceMeters : DistanceHelper.haversineMeters(widget.userPosition!, s.location);

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) => s.name.toLowerCase().contains(q) || s.direction.toLowerCase().contains(q)).take(8).toList();
  }

  void _centerOnStop(Stop s) => _mapController.move(s.location, 14.5);
  void _openAI() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;
    final activePolylines = _dynamicPolylines.isNotEmpty ? _dynamicPolylines : demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 5.0)).toList();
    final mapStops = _selectedFilter == 'Tous' ? allStops : _filteredStops;

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
                    options: MapOptions(initialCenter: _dakarCenter, initialZoom: 11.5, minZoom: 10, maxZoom: 17),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dakar_bus', maxZoom: 19),
                      PolylineLayer(polylines: activePolylines),
                      MarkerLayer(
                        markers: mapStops.map((s) => Marker(
                          point: s.location, width: 24, height: 24,
                          child: GestureDetector(
                            onTap: () { _centerOnStop(s); Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: s))); },
                            child: Container(
                              decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3)],
                              ),
                              child: Icon(s.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        )).toList(),
                      ),
                      if (widget.userPosition != null)
                        MarkerLayer(markers: [Marker(point: widget.userPosition!, width: 20, height: 20, child: Container(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)])))]),
                    ],
                  ),
                  if (_isLoadingRoutes) Positioned(top: 10, left: 140, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)), child: const Text('Calcul des routes GPS...', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),

                  Positioned(
                    bottom: 16, left: 16,
                    child: Material(
                      elevation: 4, borderRadius: BorderRadius.circular(24), color: AppColors.surface,
                      child: InkWell(
                        onTap: widget.gpsState == GpsState.granted ? () { if (widget.userPosition != null) _mapController.move(widget.userPosition!, 14.5); } : () => widget.onRequestLocation(),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              widget.gpsState == GpsState.loading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(widget.gpsState == GpsState.granted ? Icons.my_location : Icons.location_searching, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                              Text(widget.gpsState == GpsState.granted ? 'Ma position' : 'Activer GPS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 16, right: 16,
                    child: ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Assistant IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 4),
                    ),
                  ),

                  Positioned(
                    top: 12, right: 12,
                    child: Material(
                      elevation: 4, borderRadius: BorderRadius.circular(24), color: AppColors.surface,
                      child: InkWell(
                        onTap: () => setState(() => _mapHeight = _mapHeight == 260 ? 340 : (_mapHeight == 340 ? 160 : 260)),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_mapHeight == 160 ? Icons.expand_more : Icons.expand_less, color: AppColors.primary, size: 18),
                              const SizedBox(width: 4),
                              Text(_mapHeight == 160 ? 'Agrandir' : 'Reduire', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(top: 12, left: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [_legend(AppColors.ter, 'TER'), const SizedBox(width: 6), _legend(AppColors.brt, 'BRT'), const SizedBox(width: 6), _legend(AppColors.aftu, 'AFTU'), const SizedBox(width: 6), _legend(AppColors.tata, 'Tata'), const SizedBox(width: 6), _legend(AppColors.ddd, 'DDD')]))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 22)),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dakar Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('TER / BRT / AFTU / Tata / DDD', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
                    const OfficialBadge(),
                  ]),
                  const SizedBox(height: 14),
                  Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]), child: TextField(controller: _searchCtrl, onChanged: (_) => setState(() => _searchFocused = true), decoration: InputDecoration(hintText: 'Ou voulez-vous aller ?', prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22), suffixIcon: _searchFocused ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Column(children: _searchResults.map((s) => ListTile(dense: true, leading: Icon(s.icon, color: s.color, size: 22), title: Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), subtitle: Text(s.direction, style: const TextStyle(fontSize: 12)), onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); })).toList())),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('Tous'), _chip('TER'), _chip('BRT'), _chip('AFTU'), _chip('Tata'), _chip('DDD')])),
                  const SizedBox(height: 16),
                  Row(children: [Text('${stops.length} arrets', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Text('a proximite', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
                  const SizedBox(height: 10),
                  ...stops.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(onTap: () => _centerOnStop(s), child: StopCard(stop: s, distanceMeters: _distanceTo(s))))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]);

  Widget _chip(String label) {
    final color = _colorFor(label); final sel = _selectedFilter == label;
    return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => setState(() => _selectedFilter = label), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: sel ? color.withOpacity(0.15) : AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: sel ? color : AppColors.divider, width: sel ? 2 : 1)), child: Text(label, style: TextStyle(color: sel ? color : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)))));
  }

  Color _colorFor(String label) { switch (label) { case 'TER': return AppColors.ter; case 'BRT': return AppColors.brt; case 'AFTU': return AppColors.aftu; case 'Tata': return AppColors.tata; case 'DDD': return AppColors.ddd; default: return AppColors.primary; } }
}

// ============================================================
// CARTE D ARRET
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop; final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final remaining = stop.remainingMinutes();
    Widget timeWidget;
    if (remaining == null) { timeWidget = const Text('Non dispo', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)); }
    else if (remaining <= 0) { timeWidget = Text('Imminent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stop.color)); }
    else { timeWidget = Text(TimeHelper.formatRemaining(remaining), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)); }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
        leading: CircleAvatar(backgroundColor: stop.color, radius: 24, child: Icon(stop.icon, color: Colors.white, size: 22)),
        title: Row(
          children: [
            Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            _buildStopTypeBadge(stop.stopType),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stop.direction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('${DistanceHelper.format(distanceMeters)} . ${stop.modeLabel}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        trailing: timeWidget,
      ),
    );
  }

  Widget _buildStopTypeBadge(StopType type) {
    Color color; String label;
    switch (type) {
      case StopType.arrival: color = AppColors.warning; label = 'ARRIVEE'; break;
      case StopType.departure: color = AppColors.primary; label = 'DEPART'; break;
      case StopType.boarding: color = AppColors.brt; label = 'EMBARQUEMENT'; break;
      case StopType.terminus: color = AppColors.ter; label = 'TERMINUS'; break;
      case StopType.correspondence: color = AppColors.tata; label = 'CORRESP.'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.4), width: 0.8)),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
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
    await Future.delayed(const Duration(milliseconds: 600));
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
            const Text('Planifier un trajet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Trouvez le meilleur itineraire multimodal.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]),
              child: Column(
                children: [
                  _buildInputField(controller: _fromCtrl, label: 'Depart', icon: Icons.my_location, color: AppColors.primary),
                  const SizedBox(height: 12),
                  _buildInputField(controller: _toCtrl, label: 'Destination', icon: Icons.location_on, color: AppColors.ter),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
                    child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Rechercher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            if (_result == null && !_loading) ...[
              const SizedBox(height: 24),
              const Text('Suggestions populaires', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _suggestionChip('Dakar - Diamniadio', () { _fromCtrl.text = 'Dakar'; _toCtrl.text = 'Diamniadio'; _search(); }),
                  _suggestionChip('Petersen - Guediawaye', () { _fromCtrl.text = 'Petersen'; _toCtrl.text = 'Guediawaye'; _search(); }),
                  _suggestionChip('Keur Massar - Plateau', () { _fromCtrl.text = 'Keur Massar'; _toCtrl.text = 'Plateau'; _search(); }),
                  _suggestionChip('Thiaroye - Ouakam', () { _fromCtrl.text = 'Thiaroye'; _toCtrl.text = 'Ouakam'; _search(); }),
                ],
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              Row(children: [const Text('Itineraires proposes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), Text('${_result!.routes.length} resultat(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
              const SizedBox(height: 12),
              if (_result!.hasRoutes)
                ..._result!.routes.map((r) => _buildRouteCard(r))
              else
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)), child: Column(children: [const Icon(Icons.error_outline, color: AppColors.warning, size: 40), const SizedBox(height: 10), Text(_result!.errorMessage ?? 'Aucun trajet trouve', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, required Color color}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: color, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2)),
        filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    );
  }

  Widget _buildRouteCard(PlannedRoute r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: r.segments.first.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(r.segments.first.icon, color: r.segments.first.color, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r.fromName} - ${r.toName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text('${r.transferCount} correspondance(s) . ${r.segments.length} etape(s)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${r.totalMinutes} min', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)), const Text('Duree totale', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))]),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...r.segments.asMap().entries.map((entry) {
              final s = entry.value;
              final isLast = entry.key == r.segments.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)), if (!isLast) Expanded(child: Container(width: 2, color: AppColors.divider))]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Icon(s.icon, size: 14, color: s.color), const SizedBox(width: 6), Text(s.modeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: s.color)), const Spacer(), Text(s.departureTime ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 4),
                          Text('${s.from} - ${s.to}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('Duree: ${s.durationMinutes} min', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ALERTES & ASSISTANT IA
// ============================================================
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final List<Map<String, dynamic>> _alerts = [
    {'type': 'TER', 'message': 'Retard de 10 min sur la ligne Dakar-Diamniadio suite a un incident technique.', 'severity': 'warning', 'time': 'Il y a 5 min', 'icon': Icons.train_rounded, 'color': AppColors.ter},
    {'type': 'BRT', 'message': 'Trafic fluide sur l\'ensemble du reseau BRT.', 'severity': 'success', 'time': 'Il y a 12 min', 'icon': Icons.directions_bus_rounded, 'color': AppColors.brt},
    {'type': 'DDD', 'message': 'Deviation de la ligne 217 a Thiaroye en raison de travaux.', 'severity': 'warning', 'time': 'Il y a 30 min', 'icon': Icons.directions_bus_filled_rounded, 'color': AppColors.ddd},
    {'type': 'AFTU', 'message': 'Reprise normale du trafic sur la ligne 23.', 'severity': 'success', 'time': 'Il y a 1 h', 'icon': Icons.directions_bus_outlined, 'color': AppColors.aftu},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Alertes trafic', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Informations en temps reel sur l\'etat du reseau.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ..._alerts.map((alert) => _buildAlertCard(alert)),
            const SizedBox(height: 24),
            _buildAIAssistantSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isWarning = alert['severity'] == 'warning';
    final color = isWarning ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: alert['color'].withOpacity(0.1), shape: BoxShape.circle), child: Icon(alert['icon'], color: alert['color'], size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Text(alert['type'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: alert['color'])), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(alert['time'], style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)))]),
                const SizedBox(height: 6),
                Text(alert['message'], style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Column(
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 24)), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Assistant IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)), Text('Posez vos questions en direct', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]))]),
          const SizedBox(height: 16),
          const Text('L\'IA analyse le reseau en temps reel pour vous informer sur les horaires, les perturbations et vous guider dans vos correspondances.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage())), icon: const Icon(Icons.chat_bubble_outline, size: 20), label: const Text('Discuter avec l\'IA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ],
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA (Chat)
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Bonjour ! 👋 Je suis votre assistant IA Dakar Bus. Je connais l\'ensemble du réseau (TER, BRT, AFTU, Tata, DDD) et ses ${allStops.length} arrêts.\n\n'
          'Dites-moi simplement où vous voulez aller, par exemple :\n'
          '• "Je veux aller à Keur Massar"\n'
          '• "Comment rejoindre Mermoz ?"\n'
          '• "Bus pour Diamniadio"\n'
          '• "Y a-t-il des retards ?"',
    },
  ];

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _messages.add({'role': 'user', 'text': text}); _msgCtrl.clear(); });
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 600), () {
      final response = _getAIResponse(text);
      if (mounted) { setState(() { _messages.add({'role': 'ai', 'text': response}); }); _scrollToBottom(); }
    });
  }

  String _getAIResponse(String query) {
    final q = query.toLowerCase().trim();

    if (RegExp(r'\b(bonjour|salut|bonsoir|hello|coucou|salam|nanga def)\b').hasMatch(q) && q.length < 25) {
      return 'Bonjour ! 😊 Où souhaitez-vous vous rendre aujourd\'hui ? Je peux vous guider vers n\'importe quel arrêt du réseau (TER, BRT, AFTU, Tata, DDD).';
    }

    final intentPatterns = [
      RegExp(r'(?:je veux|j\'aimerais|j aimerais|je souhaiterais|je voudrais|je cherche à|peux[- ]tu me dire comment)\s+(?:aller|me rendre|rejoindre|atteindre)\s+(?:à|au|aux|en|vers|jusqu\'?à)?\s*(.+)'),
      RegExp(r'(?:comment|comment faire pour)\s+(?:aller|me rendre|rejoindre|atteindre)\s+(?:à|au|aux|en|vers|jusqu\'?à)?\s*(.+)'),
      RegExp(r'(?:bus|car|ter|brt|transport|trajet|itinéraire|route|chemin|ligne)\s+(?:pour|vers|jusqu\'?à|à)\s+(.+)'),
      RegExp(r'(?:aller|direction|vers)\s+(?:à|au|aux|en|vers)?\s*(.+)'),
      RegExp(r'(?:je suis à|je pars de|je viens de|départ de)\s+(.+)'),
    ];

    for (final pattern in intentPatterns) {
      final match = pattern.firstMatch(q);
      if (match != null) {
        final rawDest = match.group(1)?.trim() ?? '';
        final dest = _cleanLocationQuery(rawDest);
        if (dest.isNotEmpty) {
          return _respondToRouteQuery(dest);
        }
      }
    }

    if (RegExp(r'\b(retard|perturbation|probleme|problème|panne|travaux|perturbé|perturbe)\b').hasMatch(q)) {
      return '📡 État du réseau en temps réel :\n\n'
          '🟤 TER : léger retard de 10 min sur Dakar - Diamniadio\n'
          '🔵 BRT : trafic fluide (fréquence 6 min)\n'
          '🟠 DDD 217 : déviation à Thiaroye (travaux en cours)\n'
          '🟢 AFTU 23 : trafic normal\n\n'
          'Consultez l\'onglet "Alertes" pour plus de détails.';
    }

    if (RegExp(r'\b(ter|train)\b').hasMatch(q)) {
      final terStops = allStops.where((s) => s.modeLabel == 'TER').toList();
      return '🚆 Le TER dessert ${terStops.length} gares, de Dakar à Diamniadio.\n\n'
          'Fréquence : toutes les 10 min en semaine, 20 min le dimanche.';
    }

    if (RegExp(r'\bbrt\b').hasMatch(q)) {
      return '🚌 Le BRT relie PEM Petersen à PEM Guédiawaye via Colobane, Grand Dakar et Parcelles (fréquence : toutes les 6 min).';
    }

    final ligneMatch = RegExp(r'ligne\s+(\d+)').firstMatch(q);
    if (ligneMatch != null) {
      return _respondLigneInfo(ligneMatch.group(1)!);
    }

    final stop = _findStopFuzzy(q);
    if (stop != null) {
      return _respondStopInfo(stop);
    }

    return '🤔 Je n\'ai pas bien saisi votre demande. Essayez par exemple : "Comment rejoindre Mermoz ?"';
  }

  String _cleanLocationQuery(String s) {
    return s.replaceAll(RegExp(r'[?!.,;:]+$'), '').trim();
  }

  String _respondToRouteQuery(String destination) {
    final stop = _findStopFuzzy(destination);

    if (stop == null) {
      final suggestions = _suggestClosestStops(destination);
      return '📍 Je n\'ai pas trouvé "$destination".\n\n'
          'Suggestions :\n${suggestions.map((s) => '• ${s.name} (${s.modeLabel})').join('\n')}';
    }

    final fromStop = allStops.firstWhere((s) => s.name.toLowerCase().contains('gare ter dakar'));
    final result = RoutePlanner.plan(fromQuery: fromStop.name, toQuery: stop.name);

    if (result.hasRoutes) {
      final route = result.routes.first;
      final steps = route.segments.map((seg) {
        return '  • ${seg.modeLabel} : ${seg.from} - ${seg.to} (${seg.durationMinutes} min)';
      }).join('\n');

      return '🎯 Destination : **${stop.name}** (${stop.modeLabel})\n\n'
          '🚏 Itinéraire conseillé depuis ${fromStop.name} :\n$steps\n\n'
          '⏱️ Durée totale : ${route.totalMinutes} min';
    }

    return _respondStopInfo(stop);
  }

  String _respondStopInfo(Stop stop) {
    final remaining = stop.remainingMinutes();
    final nextLabel = remaining != null ? (remaining <= 0 ? 'imminent' : 'dans $remaining min') : 'non disponible';
    return '🚏 Arrêt : **${stop.name}**\n📌 Direction : ${stop.direction}\n⏱️ Prochain départ : $nextLabel';
  }

  String _respondLigneInfo(String numero) {
    final matching = allStops.where((s) => s.modeLabel == 'DDD' && s.name.toLowerCase().contains('ddd $numero')).toList();
    if (matching.isEmpty) return 'Ligne DDD $numero introuvable.';
    final stop = matching.first;
    return '🚌 **${stop.name}**\n📍 Parcours : ${stop.direction}';
  }

  Stop? _findStopFuzzy(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    for (final s in allStops) {
      if (s.name.toLowerCase() == q || s.name.toLowerCase().contains(q) || q.contains(s.name.toLowerCase())) return s;
    }

    for (final entry in kDakarLocationAliases.entries) {
      if (q.contains(entry.key) || entry.key.contains(q)) {
        final target = entry.value.toLowerCase();
        for (final s in allStops) {
          if (s.name.toLowerCase().contains(target)) return s;
        }
      }
    }
    return null;
  }

  List<Stop> _suggestClosestStops(String query) {
    return allStops.take(3).toList();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) { _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA - Dakar Bus'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                    ),
                    child: Text(msg['text']!, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgCtrl, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: 'Posez votre question...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)))),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: AppColors.primary, radius: 22, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REGLAGES
// ============================================================
class SettingsPage extends StatelessWidget {
  final List<FavoriteRoute> favorites;
  final Function(FavoriteRoute) onAdd;
  final Function(int) onRemove;
  const SettingsPage({super.key, required this.favorites, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Parametres et Reglages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.info_outline, color: AppColors.primary), title: const Text('Version de l\'application'), subtitle: const Text('Dakar Bus v3.1.0'), trailing: const Icon(Icons.chevron_right)),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.language, color: AppColors.primary), title: const Text('Langue'), subtitle: const Text('Francais'), trailing: const Icon(Icons.chevron_right)),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.notifications_outlined, color: AppColors.primary), title: const Text('Notifications'), subtitle: const Text('Activees'), trailing: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// DETAIL ARRET — ALLER / RETOUR
// ============================================================
class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final realOpposite = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);
    final opposite = realOpposite ?? _buildVirtualOpposite(stop);
    final bool isVirtual = realOpposite == null;

    final isArrival = stop.stopType == StopType.arrival;
    final currentBadge = isArrival ? 'Arrivee' : 'Depart';
    final oppositeBadge = isArrival ? 'Depart' : 'Arrivee';

    return Scaffold(
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStopCard(stop, stop.direction, stop.distanceMeters, currentBadge),
          const SizedBox(height: 16),
          _buildStopCard(opposite, opposite.direction, opposite.distanceMeters, oppositeBadge),
          if (isVirtual) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Sens inverse affiche par deduction.',
                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontStyle: FontStyle.italic),
                )),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
            child: Column(
              children: [
                const Row(children: [Icon(Icons.info_outline, color: AppColors.primary), SizedBox(width: 10), Text('Informations sur l\'arret', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 12),
                _buildInfoRow('Mode', stop.modeLabel),
                _buildInfoRow('Type', _getStopTypeLabel(stop.stopType)),
                _buildInfoRow('Distance', DistanceHelper.format(stop.distanceMeters)),
                _buildInfoRow('Source', stop.source.label),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Stop _buildVirtualOpposite(Stop original) {
    return original.copyWith(
      direction: DirectionHelper.reverse(original.direction),
      stopType: DirectionHelper.oppositeType(original.stopType),
      departureMinutesFromMidnight: original.departureMinutesFromMidnight.map((m) => m + 5).toList(),
    );
  }

  Widget _buildStopCard(Stop s, String direction, double distance, String badgeText) {
    final nextMin = s.nextDepartureMinutes();
    final normalized = nextMin != null ? nextMin % (24 * 60) : null;
    final nextTimeStr = normalized != null
        ? '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}'
        : 'Indisponible';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: s.color, radius: 18, child: Icon(s.icon, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: s.color)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary), const SizedBox(width: 6), Expanded(child: Text(direction, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prochain depart', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(nextTimeStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: s.color)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Distance', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(DistanceHelper.format(distance), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _getStopTypeLabel(StopType type) {
    switch (type) {
      case StopType.arrival: return 'Arrivee';
      case StopType.departure: return 'Depart';
      case StopType.boarding: return 'Embarquement';
      case StopType.terminus: return 'Terminus';
      case StopType.correspondence: return 'Correspondance';
    }
  }
}
