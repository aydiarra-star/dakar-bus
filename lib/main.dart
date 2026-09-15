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
// GEOFENCING STRICT TERRE FERME DAKAR (ANTI-OCEAN)
// ============================================================
class DakarBounds {
  static const double north = 14.7900;
  static const double south = 14.6600;
  static const double east = -17.1800;
  static const double west = -17.5300;

  static bool isValid(LatLng location) {
    // Exclusion spécifique de la Baie de Hann (zone maritime intérieure)
    if (location.latitude > 14.7000 && location.latitude < 14.7450 &&
        location.longitude > -17.4350 && location.longitude < -17.3750) {
      return false;
    }
    return location.latitude >= south &&
        location.latitude <= north &&
        location.longitude >= west &&
        location.longitude <= east &&
        location.latitude != 0.0 &&
        location.longitude != 0.0;
  }
}

// ============================================================
// SERVICE ROUTING REEL OSRM
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
        final points = coordinates
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .where((pt) => DakarBounds.isValid(pt))
            .toList();
        _cache[key] = points.isNotEmpty ? points : [start, end];
        return _cache[key]!;
      }
    } catch (_) {}
    
    final fallback = [start, end];
    _cache[key] = fallback;
    return fallback;
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
// GENERATEUR D HORAIRES DYNAMIQUES
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
// PALETTE OFFICIELLE DES TRANSPORTS
// ============================================================
class AppColors {
  static const primary = Color(0xFF00B140);
  static const primaryDark = Color(0xFF008A32);
  static const ter = Color(0xFF8B4513);    // Train Express Régional
  static const brt = Color(0xFF22C55E);    // Bus Rapid Transit
  static const aftu = Color(0xFFFF8C42);   // Autobus AFTU
  static const tata = Color(0xFF87CEEB);   // Minibus Tata
  static const ddd = Color(0xFF3B82F6);    // Dakar Dem Dikk
  static const background = Color(0xFFF1F8F5);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF555555);
  static const divider = Color(0xFFD4EDE2);
  static const success = Color(0xFF00B140);
  static const warning = Color(0xFFEF6C00);
}

// ============================================================
// SOURCE DE DONNEES & STATUT
// ============================================================
enum DataOrigin { official, verified, indicative, unavailable }
class DataSourceInfo {
  final DataOrigin origin; final String label; final String badgeEmoji;
  const DataSourceInfo({required this.origin, required this.label, required this.badgeEmoji});
  static const seter = DataSourceInfo(origin: DataOrigin.official, label: 'SETER (Officiel)', badgeEmoji: '🟢');
  static const sunubrt = DataSourceInfo(origin: DataOrigin.official, label: 'SunuBRT (Officiel)', badgeEmoji: '🟢');
  static const demdikk = DataSourceInfo(origin: DataOrigin.official, label: 'Dakar Dem Dikk', badgeEmoji: '🟢');
  static const aftuOfficial = DataSourceInfo(origin: DataOrigin.verified, label: 'AFTU (72 Lignes Officielles)', badgeEmoji: '🔵');
  static const demo = DataSourceInfo(origin: DataOrigin.indicative, label: 'Donnée Indicative (~)', badgeEmoji: '🟡');
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

  bool get isContinuousFlow => modeLabel == 'AFTU' || modeLabel == 'Tata';

  bool _isServiceOpen() {
    final now = DateTime.now();
    final hour = now.hour;
    int startHour = isContinuousFlow ? 6 : 5;
    if (hour >= startHour && hour < 22) return true;
    if (!isContinuousFlow && hour == 22 && now.minute <= 30) return true;
    return false;
  }

  int? nextDepartureMinutes() {
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return 5;
    
    final now = DateTime.now(); 
    final currentMin = now.hour * 60 + now.minute;
    for (final d in departureMinutesFromMidnight) { 
      if (d >= currentMin && (d - currentMin) <= 180) return d; 
    }
    return null;
  }

  int? remainingMinutes() { 
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return 5;
    final d = nextDepartureMinutes(); 
    if (d == null) return null; 
    return d - (DateTime.now().hour * 60 + DateTime.now().minute); 
  }

  String? nextDepartureLabel() { 
    if (!_isServiceOpen()) return 'Service fermé';
    if (isContinuousFlow) return 'En rotation (~5 min)';
    final d = nextDepartureMinutes(); 
    if (d == null) return 'Prochainement'; 
    final normalized = d % (24 * 60); 
    return '${(normalized ~/ 60).toString().padLeft(2, '0')} h ${(normalized % 60).toString().padLeft(2, '0')}'; 
  }

  int? departureAfter(int minFromMidnight) { 
    if (!_isServiceOpen()) return null;
    if (isContinuousFlow) return minFromMidnight + 5;
    for (final d in departureMinutesFromMidnight) { if (d > minFromMidnight) return d; } 
    return null; 
  }
}

enum DataStatus { scheduled, live, unknown }

class TransitRoute {
  final String name; final String code; final String type; final Color color; final List<LatLng> points;
  const TransitRoute({required this.name, required this.code, required this.type, required this.color, required this.points});
  bool get isDedicated => type == 'TER';
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
// STATIONS ET ARRETS STRICTEMENT SUR TERRE FERME (DAKAR)
// ============================================================
final List<Stop> terStations = [
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7190, -17.4450), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: _shift(_terBase, 17), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7550, -17.3900), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Dakar / Diamniadio', distanceMeters: 14200, departureMinutesFromMidnight: _shift(_terBase, 27), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7750, -17.3100), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.correspondence),
  Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 50), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7160, -17.1986), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.terminus),
];

final List<Stop> brtStations = [
  Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: _shift(_brtBase, 0), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6720, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guediawaye', distanceMeters: 1500, departureMinutesFromMidnight: _shift(_brtBase, 4), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7050, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'PEM Guediawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: _shift(_brtBase, 8), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7735, -17.3977), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
];

final List<Stop> aftuAndBusStations = [
  Stop(name: 'Parcelles Assainies (L1 à L10)', direction: 'Dir. Dakar Centre', distanceMeters: 300, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7645, -17.4420), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Grand Yoff (L11 à L25)', direction: 'Dir. Petersen', distanceMeters: 1100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7420, -17.4480), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.correspondence),
  Stop(name: 'Terminus Petersen (AFTU L25)', direction: 'Terminus central AFTU', distanceMeters: 450, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.6720, -17.4400), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.terminus),
  Stop(name: 'Ouakam / Ngor (L26 à L40)', direction: 'Dir. Plateau', distanceMeters: 3100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7350, -17.4820), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Guédiawaye Notaire (L41 à L55)', direction: 'Dir. Kounoune', distanceMeters: 9200, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7750, -17.3950), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Bambilor / Rufisque (L56 à L72)', direction: 'Dir. Dakar Plateau', distanceMeters: 12000, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7450, -17.3650), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Mermoz (DDD)', direction: 'Dir. Sacré-Cœur', distanceMeters: 3500, departureMinutesFromMidnight: [360, 420, 480, 540, 600, 660, 720, 780, 840, 900], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.7120, -17.4650), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'Keur Massar (DDD)', direction: 'Dir. Keur Massar Centre', distanceMeters: 15000, departureMinutesFromMidnight: [360, 420, 480, 540, 600, 660, 720, 780, 840, 900, 960], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.7900, -17.3500), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'Arret Tata 12', direction: 'Dir. Guediawaye', distanceMeters: 600, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7200, -17.4700), modeLabel: 'Tata', source: DataSourceInfo.demo, stopType: StopType.boarding),
];

// Application stricte du géofencing sur l'ensemble des arrêts
final List<Stop> allStops = [...terStations, ...brtStations, ...aftuAndBusStations]
    .where((s) => DakarBounds.isValid(s.location))
    .toList();

// ============================================================
// TRACES DES ROUTES AUX COULEURS RESPECTIVES
// ============================================================
final List<TransitRoute> demoRoutes = [
  TransitRoute(
    name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter,
    points: [
      const LatLng(14.6792, -17.4407), const LatLng(14.6937, -17.4441),
      const LatLng(14.7190, -17.4450), const LatLng(14.7550, -17.3900),
      const LatLng(14.7750, -17.3100), const LatLng(14.7160, -17.1986),
    ],
  ),
  TransitRoute(
    name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt,
    points: [
      const LatLng(14.6720, -17.4400), const LatLng(14.6950, -17.4420),
      const LatLng(14.7350, -17.4260), const LatLng(14.7735, -17.3977),
    ],
  ),
  TransitRoute(
    name: 'AFTU 72 Lignes', code: 'A25', type: 'AFTU', color: AppColors.aftu,
    points: [
      const LatLng(14.7645, -17.4420), const LatLng(14.7420, -17.4480), const LatLng(14.6720, -17.4400),
    ],
  ),
  TransitRoute(
    name: 'Tata / DDD', code: 'T12', type: 'Tata', color: AppColors.tata,
    points: [
      const LatLng(14.6792, -17.4407), const LatLng(14.7120, -17.4650), const LatLng(14.7900, -17.3500),
    ],
  ),
];

// ============================================================
// MOTEUR D ITINERAIRES INTELLIGENT
// ============================================================
class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    final now = DateTime.now();
    final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);
    if (!isOpen) {
      return const RouteSearchResult(errorMessage: '🌙 Les réseaux TER, BRT et bus sont actuellement fermés (Service de 5h00 à 22h30).');
    }

    final fromStop = _findNearestStop(fromQuery);
    final toStop = _findNearestStop(toQuery);

    if (fromStop == null) return const RouteSearchResult(errorMessage: 'Lieu de départ introuvable.');
    if (toStop == null) return const RouteSearchResult(errorMessage: 'Destination introuvable.');

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
      return RouteSearchResult(errorMessage: 'Aucun itinéraire trouvé entre ${fromStop.name} et ${toStop.name}.');
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
    final dist = DistanceHelper.haversineMeters(from.location, to.location);
    final speed = (from.modeLabel == 'TER' || from.modeLabel == 'BRT') ? 35.0 : 20.0;
    int dur = ((dist / 1000.0) / speed * 60).ceil();
    if (dur < 5) dur = 5;

    final safeCurrentMin = math.max(0, currentMin);
    final dep = from.departureAfter(safeCurrentMin) ?? safeCurrentMin;
    final arr = dep + dur;

    return PlannedRoute(
      fromName: from.name, toName: to.name, totalMinutes: dur,
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
    if (minutes <= 0) return 'Imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  static String getCrowdLevel(Stop stop) {
    final now = DateTime.now();
    final h = now.hour;
    if ((h >= 7 && h <= 9) || (h >= 17 && h <= 19)) {
      return '🔴 Bondé (Heure de pointe)';
    } else if ((h >= 10 && h <= 16)) {
      return '🟠 Dense';
    }
    return '🟢 Fluide';
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
    if (direction.contains('Dir. Dakar')) {
      return direction.replaceAll('Dir. Dakar', 'Dir. retour');
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

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  Future<void> _requestLocation() async {
    setState(() { _gpsState = GpsState.loading; _gpsMessage = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() { _gpsState = GpsState.serviceDisabled; _gpsMessage = 'GPS désactivé.'; }); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _gpsState = GpsState.denied; _gpsMessage = 'Permission GPS refusée.'; }); return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      if (DakarBounds.isValid(latLng)) {
        setState(() { _userPosition = latLng; _gpsState = GpsState.granted; _gpsMessage = null; });
      } else {
        setState(() { _userPosition = const LatLng(14.7167, -17.4677); _gpsState = GpsState.granted; _gpsMessage = 'Position hors zone, recentré sur Dakar.'; });
      }
    } catch (_) { setState(() { _gpsState = GpsState.error; _gpsMessage = 'Erreur GPS.'; }); }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, gpsMessage: _gpsMessage, onRequestLocation: _requestLocation),
      const TripsPage(),
      const AlertsPage(),
      const CommunityAlertsPage(),
      const SettingsPage(),
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
            indicatorColor: AppColors.primary.withOpacity(0.18),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 68,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: AppColors.primary), label: 'Direct rue'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Réglages'),
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
        fullRoutePoints = route.points.where((pt) => DakarBounds.isValid(pt)).toList();
      } else {
        final List<Future<List<LatLng>>> futures = [];
        for (int i = 0; i < route.points.length - 1; i++) {
          futures.add(RoutingService.getRealRoute(route.points[i], route.points[i + 1]));
        }
        final List<List<LatLng>> segments = await Future.wait(futures);
        for (final segment in segments) {
          final validSeg = segment.where((pt) => DakarBounds.isValid(pt)).toList();
          if (fullRoutePoints.isNotEmpty && validSeg.isNotEmpty) {
            fullRoutePoints.addAll(validSeg.skip(1));
          } else {
            fullRoutePoints.addAll(validSeg);
          }
        }
        if (fullRoutePoints.isEmpty) fullRoutePoints = route.points.where((pt) => DakarBounds.isValid(pt)).toList();
      }
      loaded.add(Polyline(points: fullRoutePoints, color: route.color, strokeWidth: 5.5));
    }
    if (mounted) setState(() { _dynamicPolylines = loaded; _isLoadingRoutes = false; });
  }

  List<Stop> get _filteredStops {
    List<Stop> base;
    switch (_selectedFilter) {
      case 'TER': base = allStops.where((s) => s.color == AppColors.ter).toList(); break;
      case 'BRT': base = allStops.where((s) => s.color == AppColors.brt).toList(); break;
      case 'DDD': base = allStops.where((s) => s.color == AppColors.ddd).toList(); break;
      case 'AFTU': base = allStops.where((s) => s.color == AppColors.aftu).toList(); break;
      case 'Tata': base = allStops.where((s) => s.color == AppColors.tata).toList(); break;
      default: base = List.from(allStops); break;
    }
    if (widget.userPosition != null) {
      base.sort((a, b) => DistanceHelper.haversineMeters(widget.userPosition!, a.location).compareTo(DistanceHelper.haversineMeters(widget.userPosition!, b.location)));
    }
    return base.where((s) => DakarBounds.isValid(s.location)).toList();
  }

  double _distanceTo(Stop s) => widget.userPosition == null ? s.distanceMeters : DistanceHelper.haversineMeters(widget.userPosition!, s.location);

  List<Stop> get _searchResults {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allStops.where((s) => (s.name.toLowerCase().contains(q) || s.direction.toLowerCase().contains(q)) && DakarBounds.isValid(s.location)).take(8).toList();
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
                        markers: mapStops.where((s) => DakarBounds.isValid(s.location)).map((s) => Marker(
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
                      if (widget.userPosition != null && DakarBounds.isValid(widget.userPosition!))
                        MarkerLayer(markers: [Marker(point: widget.userPosition!, width: 20, height: 20, child: Container(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)])))]),
                    ],
                  ),

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
                              Text(_mapHeight == 160 ? 'Agrandir' : 'Réduire', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _legend(AppColors.ter, 'TER'), const SizedBox(width: 6),
                        _legend(AppColors.brt, 'BRT'), const SizedBox(width: 6),
                        _legend(AppColors.ddd, 'DDD'), const SizedBox(width: 6),
                        _legend(AppColors.aftu, 'AFTU'), const SizedBox(width: 6),
                        _legend(AppColors.tata, 'Tata'),
                      ]),
                    ),
                  ),
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
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dakar Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('TER / BRT / DDD / 72 Lignes AFTU & Tata', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
                  ]),
                  const SizedBox(height: 14),
                  Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]), child: TextField(controller: _searchCtrl, onChanged: (_) => setState(() => _searchFocused = true), decoration: InputDecoration(hintText: 'Où voulez-vous aller ? (ex: Parcelles, UCAD...)', prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22), suffixIcon: _searchFocused ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Column(children: _searchResults.map((s) => ListTile(dense: true, leading: Icon(s.icon, color: s.color, size: 22), title: Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), subtitle: Text(s.direction, style: const TextStyle(fontSize: 12)), onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); })).toList())),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('Tous'), _chip('TER'), _chip('BRT'), _chip('DDD'), _chip('AFTU'), _chip('Tata')])),
                  const SizedBox(height: 16),
                  Row(children: [Text('${stops.length} arrêts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Text('à proximité', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
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

  Color _colorFor(String label) { switch (label) { case 'TER': return AppColors.ter; case 'BRT': return AppColors.brt; case 'DDD': return AppColors.ddd; case 'AFTU': return AppColors.aftu; case 'Tata': return AppColors.tata; default: return AppColors.primary; } }
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
    final crowd = TimeHelper.getCrowdLevel(stop);
    Widget timeWidget;

    final now = DateTime.now();
    final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);

    if (!isOpen) {
      timeWidget = const Text('Service fermé', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary));
    } else if (remaining == null) { 
      timeWidget = const Text('Prochainement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)); 
    } else if (remaining <= 0) { 
      timeWidget = Text('Imminent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stop.color)); 
    } else { 
      timeWidget = Text(TimeHelper.formatRemaining(remaining), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)); 
    }

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
              Text('${DistanceHelper.format(distanceMeters)} . ${stop.modeLabel} (${stop.source.badgeEmoji}) . $crowd', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
      case StopType.arrival: color = AppColors.warning; label = 'ARRIVÉE'; break;
      case StopType.departure: color = AppColors.primary; label = 'DÉPART'; break;
      case StopType.boarding: color = AppColors.brt; label = 'EMBARQ.'; break;
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
// ONGLET TRAJETS
// ============================================================
class TripsPage extends StatefulWidget {
  const TripsPage({super.key});
  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final _fromCtrl = TextEditingController(text: 'Parcelles Assainies');
  final _toCtrl = TextEditingController(text: 'Petersen');
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
            const Text('Planifier un trajet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Itinéraires multimodaux officiels (TER, BRT, 72 Lignes AFTU, Tata).', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]),
              child: Column(
                children: [
                  _buildInputField(controller: _fromCtrl, label: 'Départ', icon: Icons.my_location, color: AppColors.primary),
                  const SizedBox(height: 12),
                  _buildInputField(controller: _toCtrl, label: 'Destination', icon: Icons.location_on, color: AppColors.ter),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
                    child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Rechercher mon itinéraire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            if (_result == null && !_loading) ...[
              const SizedBox(height: 24),
              const Text('Suggestions populaires (72 Lignes AFTU)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _suggestionChip('Parcelles - Petersen (L25)', () { _fromCtrl.text = 'Parcelles'; _toCtrl.text = 'Petersen'; _search(); }),
                  _suggestionChip('Guediawaye - Kounoune (L72)', () { _fromCtrl.text = 'Guediawaye'; _toCtrl.text = 'Kounoune'; _search(); }),
                  _suggestionChip('Dakar - Diamniadio (TER)', () { _fromCtrl.text = 'Dakar'; _toCtrl.text = 'Diamniadio'; _search(); }),
                  _suggestionChip('Mermoz - Keur Massar (DDD)', () { _fromCtrl.text = 'Mermoz'; _toCtrl.text = 'Keur Massar'; _search(); }),
                ],
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              Row(children: [const Text('Itinéraires proposés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), Text('${_result!.routes.length} résultat(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
              const SizedBox(height: 12),
              if (_result!.hasRoutes)
                ..._result!.routes.map((r) => _buildRouteCard(r))
              else
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)), child: Column(children: [const Icon(Icons.error_outline, color: AppColors.warning, size: 40), const SizedBox(height: 10), Text(_result!.errorMessage ?? 'Aucun trajet trouvé', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))])),
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r.fromName} - ${r.toName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 2), Text('${r.transferCount} correspondance(s) . ${r.segments.length} étape(s)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${r.totalMinutes} min', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)), const Text('Durée totale', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))]),
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
                          Text('Durée: ${s.durationMinutes} min', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
// ONGLET ALERTES OFFICIELLES & EN TEMPS REEL
// ============================================================
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> officialAlerts = [
      {
        'type': 'AFTU',
        'title': 'Catalogue officiel des 72 lignes AFTU',
        'source': 'Source officielle : aftu-senegal.org',
        'message': 'Le réseau AFTU intègre officiellement 72 lignes opérationnelles connectées en temps réel.',
        'severity': 'success',
        'badge': 'Base 72 Lignes',
        'icon': Icons.directions_bus_outlined,
        'color': AppColors.aftu,
      },
      {
        'type': 'TER',
        'title': 'Régulation et trafic - Ligne Dakar / Diamniadio',
        'source': 'Source officielle : SETER',
        'message': 'Régulation en cours sur l\'axe Dakar - Diamniadio suite à un afflux aux heures de pointe.',
        'severity': 'warning',
        'badge': 'Mise à jour en direct',
        'icon': Icons.train_rounded,
        'color': AppColors.ter,
      },
      {
        'type': 'BRT',
        'title': 'État du réseau SunuBRT',
        'source': 'Source officielle : Dakar Mobilité',
        'message': 'Trafic 100% fluide et opérationnel sur l\'ensemble du couloir exclusif.',
        'severity': 'success',
        'badge': 'En temps réel',
        'icon': Icons.directions_bus_rounded,
        'color': AppColors.brt,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Alertes trafic & Réseau', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Informations certifiées SETER, SunuBRT, DDD & AFTU.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ...officialAlerts.map((alert) => _buildAlertCard(context, alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final isWarning = alert['severity'] == 'warning';
    final color = isWarning ? AppColors.warning : AppColors.success;
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              Icon(alert['icon'], color: alert['color']),
              const SizedBox(width: 10),
              Expanded(child: Text('${alert['type']} - ${alert['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(alert['source'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  const SizedBox(height: 12),
                  Text(alert['message'], style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      child: Container(
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
                  Row(children: [Text(alert['type'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: alert['color'])), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(alert['badge'], style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 4),
                  Text(alert['source'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Text(alert['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Appuyer pour consulter le rapport officiel →', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CROWDSOURCING & SIGNALEMENT DIRECT RUE
// ============================================================
class CommunityAlertsPage extends StatefulWidget {
  const CommunityAlertsPage({super.key});

  @override
  State<CommunityAlertsPage> createState() => CommunityAlertsPageState();
}

class CommunityAlertsPageState extends State<CommunityAlertsPage> {
  final List<Map<String, String>> _communityReports = [
    {'user': 'Mamadou S.', 'location': 'Parcelles Assainies (L25)', 'type': 'Rotation fluide AFTU', 'time': 'Il y a 3 min', 'status': '🟢 Fluide'},
    {'user': 'Aïssatou N.', 'location': 'Mermoz (DDD)', 'type': 'Bus DDD climatisé', 'time': 'Il y a 6 min', 'status': '🟢 Fluide'},
    {'user': 'Ousmane D.', 'location': 'Colobane', 'type': 'Embouteillage routier', 'time': 'Il y a 12 min', 'status': '🔴 Bloqué'},
  ];

  void _showReportDialog(BuildContext ctxParent) {
    String location = 'Dakar';
    String type = 'Embouteillage';
    showDialog(
      context: ctxParent,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler un incident sur le terrain'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Lieu / Ligne AFTU / Arrêt'),
              onChanged: (v) => location = v,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Description (ex: Embouteillage, Attente bus...)'),
              onChanged: (v) => type = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _communityReports.insert(0, {'user': 'Vous', 'location': location, 'type': type, 'time': 'À l\'instant', 'status': '🟠 Signalé'});
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctxParent).showSnackBar(const SnackBar(content: Text('Merci ! Votre signalement aide toute la communauté.')));
            },
            child: const Text('Publier'),
          ),
        ],
      ),
    );
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
            Row(
              children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Direct rue & Communauté', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Signalements en temps réel par les usagers à Dakar.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ])),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Signaler'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._communityReports.map((report) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(report['user']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text(report['time']!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 4),
                        Text('📍 ${report['location']} — ${report['type']}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(report['status']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// REGLAGES
// ============================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  void _showPresentationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('À propos de Dakar Bus'),
        content: const SingleChildScrollView(
          child: Text(
            'Un jeune Sénégalais, profondément soucieux du développement de son pays et des défis quotidiens du transport urbain, a conçu et lancé cette application pour faciliter aux usagers la mobilité à Dakar.\n\n'
            'Intégrant désormais les 72 lignes officielles du réseau AFTU, le TER, le BRT, les bus DDD et Tata, Dakar Bus ambitionne de rendre les déplacements plus fluides et prévisibles.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showUserGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comment utiliser Dakar Bus'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Explorer : Visualisez le réseau et les tracés de toutes les mobilités sans dépassement maritime.\n'
            '2. Trajets : Entrez votre point de départ et votre destination.\n'
            '3. Lignes : Cliquez sur les flèches d\'un arrêt pour voir le détail séquentiel des arrêts.\n'
            '4. Assistant IA : Interrogez l\'assistant vocal ou textuel.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
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
            const Text('Réglages & Préférences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                    title: const Text('Notifications trafic'),
                    value: _notificationsEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                    title: const Text('Mode sombre'),
                    value: _darkMode,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _darkMode = v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.primary),
                    title: const Text('Présentation du projet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showPresentationDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: AppColors.primary),
                    title: const Text('Comment utiliser l\'application'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showUserGuideDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primary),
                    title: const Text('Version de l\'application'),
                    subtitle: const Text('Dakar Bus v6.5 (Timeline Stops & Safe Geofence)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ASSISTANT IA INTELLIGENT & VOCAL ACTIF
// ============================================================
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isListening = false;
  
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': 'Nanga def ! 👋 Je suis l\'assistant intelligent de Dakar Bus. Interrogez-moi sur les 72 lignes AFTU, le TER, le BRT ou vos trajets.',
    },
  ];

  void _simulateVoiceInput() {
    setState(() => _isListening = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          if (_msgCtrl.text.isEmpty) {
            _msgCtrl.text = 'Ligne 25 Parcelles Petersen';
          }
        });
        _sendMessage();
      }
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _msgCtrl.clear();
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      final response = _processAIIntelligence(text);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': response});
        });
        _scrollToBottom();
      }
    });
  }

  String _processAIIntelligence(String query) {
    final q = query.toLowerCase().trim();

    if (q.contains('bonjour') || q.contains('salut') || q.contains('salam') || q.contains('nanga def')) {
      return 'Nanga def ! 😊 Le réseau AFTU référence 72 lignes officielles. Où souhaitez-vous vous rendre à Dakar ?';
    }

    if (q.contains('ligne 25') || q.contains('l25')) {
      return '🚌 **AFTU Ligne 25** (Source officielle AFTU) :\n'
          '• **Parcours** : Terminus Parcelles Assainies ➔ École Dior ➔ Petersen\n'
          '• **Fréquence** : ~12 minutes en heures de pointe\n'
          '• **Statut** : En rotation continue (6h00 - 22h00)';
    }

    if (q.contains('retard') || q.contains('perturbation') || q.contains('trafic')) {
      return '📡 [État du réseau officiel]\n\n'
          '🟤 TER : Trafic régulier.\n'
          '🟢 BRT : Trafic fluide.\n'
          '🟠 AFTU : 72 lignes en rotation normale.';
    }

    String destination = 'Gare TER Dakar';
    if (q.contains('mermoz')) destination = 'Mermoz';
    if (q.contains('pikine')) destination = 'Gare TER Pikine';

    final result = RoutePlanner.plan(fromQuery: 'Parcelles Assainies', toQuery: destination);
    if (result.hasRoutes) {
      final r = result.routes.first;
      final seg = r.segments.first;
      return '🧭 Itinéraire optimal calculé (${r.totalMinutes} min) :\n\n'
          '🚶 Départ de ${r.fromName}\n'
          '${seg.icon == Icons.train_rounded ? '🚆' : '🚌'} ${seg.modeLabel} (${seg.from} ➔ ${seg.to})\n'
          '📊 Confort estimé : ${TimeHelper.getCrowdLevel(allStops.first)}\n'
          '🚶 Arrivée à ${r.toName}';
    }

    return result.errorMessage ?? '🤔 J\'ai bien analysé votre demande ("$query"). Le système de transport est opérationnel.';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant IA - Dakar Bus'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.amberAccent : Colors.white),
            onPressed: _simulateVoiceInput,
            tooltip: 'Dictée vocale',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isListening)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.warning.withOpacity(0.2),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Écoute en cours... Parlez maintenant.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
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
                IconButton(
                  icon: const Icon(Icons.mic, color: AppColors.primary),
                  onPressed: _simulateVoiceInput,
                ),
                Expanded(child: TextField(controller: _msgCtrl, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: 'Posez votre question (Ligne 25, Mermoz...)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)))),
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
// PAGE CHRONOLOGIQUE DES ARRETS DU TRAJET (ARRÊTS ALIGNÉS)
// ============================================================
class RouteStopsTimelinePage extends StatelessWidget {
  final Stop stop;
  const RouteStopsTimelinePage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    // Filtrer les arrêts appartenant au même mode de transport ou ligne
    final lineStops = allStops.where((s) => s.modeLabel == stop.modeLabel).toList();
    if (lineStops.isEmpty) lineStops.add(stop);

    return Scaffold(
      appBar: AppBar(
        title: Text('Trajet — ${stop.modeLabel} (${stop.name})'),
        backgroundColor: stop.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: stop.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stop.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(stop.icon, color: stop.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sens : ${stop.direction}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: stop.color)),
                      const SizedBox(height: 2),
                      Text('${lineStops.length} arrêts desservis sur cet axe.', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Arrêts alignés sur le parcours :', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...lineStops.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isLast = idx == lineStops.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle),
                        child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                      ),
                      if (!isLast) Expanded(child: Container(width: 3, color: stop.color.withOpacity(0.4))),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(s.direction, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: stop.color),
                                const SizedBox(width: 4),
                                Text(DistanceHelper.format(s.distanceMeters), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text(TimeHelper.getCrowdLevel(s), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
    final currentBadge = isArrival ? 'Arrivée' : 'Départ';
    final oppositeBadge = isArrival ? 'Départ' : 'Arrivée';

    return Scaffold(
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteStopsTimelinePage(stop: stop))),
            child: _buildStopCard(context, stop, stop.direction, stop.distanceMeters, currentBadge, showArrow: true),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteStopsTimelinePage(stop: opposite))),
            child: _buildStopCard(context, opposite, opposite.direction, opposite.distanceMeters, oppositeBadge, showArrow: true),
          ),
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
                  'Sens inverse affiché par déduction.',
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
                const Row(children: [Icon(Icons.info_outline, color: AppColors.primary), SizedBox(width: 10), Text('Informations sur l\'arrêt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 12),
                _buildInfoRow('Mode', stop.modeLabel),
                _buildInfoRow('Type', _getStopTypeLabel(stop.stopType)),
                _buildInfoRow('Distance', DistanceHelper.format(stop.distanceMeters)),
                _buildInfoRow('Affluence', TimeHelper.getCrowdLevel(stop)),
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

  Widget _buildStopCard(BuildContext context, Stop s, String direction, double distance, String badgeText, {bool showArrow = false}) {
    final nextTimeStr = s.nextDepartureLabel() ?? 'Prochainement';

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
          Row(
            children: [
              Icon(Icons.arrow_forward_ios, size: 12, color: s.color),
              const SizedBox(width: 6),
              Expanded(child: Text(direction, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.color))),
              if (showArrow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: s.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Voir le trajet →', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prochain départ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(nextTimeStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: s.color)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Distance', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(DistanceHelper.format(distance), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
      case StopType.arrival: return 'Arrivée';
      case StopType.departure: return 'Départ';
      case StopType.boarding: return 'Embarquement';
      case StopType.terminus: return 'Terminus';
      case StopType.correspondence: return 'Correspondance';
    }
  }
}
