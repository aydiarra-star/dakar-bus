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
// NOTIFIER GLOBAL POUR LE MODE SOMBRE & FAVORIS
// ============================================================
class AppStateNotifier extends ChangeNotifier {
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void toggleDarkMode(bool value) { _darkMode = value; notifyListeners(); }

  final Set<String> _favoriteStopNames = {};
  Set<String> get favoriteStopNames => _favoriteStopNames;

  bool isFavorite(String name) => _favoriteStopNames.contains(name);

  void toggleFavorite(String name) {
    if (_favoriteStopNames.contains(name)) {
      _favoriteStopNames.remove(name);
    } else {
      _favoriteStopNames.add(name);
    }
    notifyListeners();
  }
}

final AppStateNotifier globalState = AppStateNotifier();

// ============================================================
// GEOFENCING STRICT TERRE FERME DAKAR (ANTI-OCEAN)
// ============================================================
class DakarBounds {
  static const double north = 14.7900;
  static const double south = 14.6500;
  static const double east = -17.1500;
  static const double west = -17.5500;

  static bool isValid(LatLng location) {
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
// SERVICE DE DETECTION DES DEUX SENS & INVERSION PROPRE
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
// GENERATEUR D HORAIRES DYNAMIQUES & ROTATIONS CONTINUES
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
// PALETTE OFFICIELLE DES TRANSPORTS & THEME MANAGER
// ============================================================
class AppColors {
  static const primary = Color(0xFF00B140);
  static const primaryDark = Color(0xFF008A32);
  static const ter = Color(0xFF8B4513);
  static const brt = Color(0xFF22C55E);
  static const aftu = Color(0xFFFF8C42);
  static const tata = Color(0xFF87CEEB);
  static const ddd = Color(0xFF3B82F6);
  
  static Color background(bool dark) => dark ? const Color(0xFF121212) : const Color(0xFFF1F8F5);
  static Color surface(bool dark) => dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color textPrimary(bool dark) => dark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
  static Color textSecondary(bool dark) => dark ? const Color(0xFFAAAAAA) : const Color(0xFF555555);
  static Color divider(bool dark) => dark ? const Color(0xFF2C2C2C) : const Color(0xFFD4EDE2);
  
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
  static const demdikk = DataSourceInfo(origin: DataOrigin.official, label: 'Dakar Dem Dikk (Officiel)', badgeEmoji: '🟢');
  static const tataOfficial = DataSourceInfo(origin: DataOrigin.verified, label: 'Bus TATA (Officiel)', badgeEmoji: '🔵');
  static const aftuOfficial = DataSourceInfo(origin: DataOrigin.verified, label: 'AFTU (72 Lignes Officielles)', badgeEmoji: '🔵');
  static const demo = DataSourceInfo(origin: DataOrigin.indicative, label: 'Donnée Indicative (~)', badgeEmoji: '🟡');
}

// ============================================================
// MODELES DE DONNEES ET ROUTES DETAILLEES OFFICIELLES
// ============================================================
enum StopType { arrival, departure, boarding, terminus, correspondence, intermediate }

class DetailedStop {
  final String stopId;
  final String name;
  final int sequence;
  final LatLng location;
  final String distanceFromStart;
  final String estimatedTime;
  final bool isTerminal;
  final String type;

  const DetailedStop({
    required this.stopId,
    required this.name,
    required this.sequence,
    required this.location,
    required this.distanceFromStart,
    required this.estimatedTime,
    required this.isTerminal,
    required this.type,
  });
}

class DetailedRoute {
  final String routeId;
  final int lineNumber;
  final String operator;
  final Color color;
  String origin;
  String destination;
  final String totalDistance;
  final List<DetailedStop> stops;

  DetailedRoute({
    required this.routeId,
    required this.lineNumber,
    required this.operator,
    required this.color,
    required this.origin,
    required this.destination,
    required this.totalDistance,
    required this.stops,
  });

  static DetailedRoute fromStop(Stop stop, {bool isReturnRoute = false}) {
    if (stop.modeLabel == 'TER') {
      List<DetailedStop> terStops = [
        const DetailedStop(stopId: 'ter_1', name: 'Gare de Dakar', sequence: 1, location: LatLng(14.6792, -17.4407), distanceFromStart: '0 km', estimatedTime: '00:00', isTerminal: true, type: 'Embarquement'),
        const DetailedStop(stopId: 'ter_2', name: 'Colobane', sequence: 2, location: LatLng(14.6937, -17.4441), distanceFromStart: '1.2 km', estimatedTime: '03:00', isTerminal: false, type: 'Correspondance'),
        const DetailedStop(stopId: 'ter_3', name: 'Hann', sequence: 3, location: LatLng(14.7190, -17.4450), distanceFromStart: '3.5 km', estimatedTime: '06:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_4', name: 'Baux Maraîchers', sequence: 4, location: LatLng(14.7380, -17.4100), distanceFromStart: '5.5 km', estimatedTime: '09:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_5', name: 'Pikine', sequence: 5, location: LatLng(14.7550, -17.3900), distanceFromStart: '7.2 km', estimatedTime: '12:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_6', name: 'Thiaroye', sequence: 6, location: LatLng(14.7620, -17.3700), distanceFromStart: '9.0 km', estimatedTime: '15:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_7', name: 'Yeumbeul', sequence: 7, location: LatLng(14.7700, -17.3400), distanceFromStart: '11.5 km', estimatedTime: '18:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_8', name: 'Keur Massar', sequence: 8, location: LatLng(14.7900, -17.3250), distanceFromStart: '13.0 km', estimatedTime: '21:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_9', name: 'Keur Mbaye Fall', sequence: 9, location: LatLng(14.7750, -17.3100), distanceFromStart: '14.2 km', estimatedTime: '24:00', isTerminal: false, type: 'Correspondance'),
        const DetailedStop(stopId: 'ter_10', name: 'Rufisque', sequence: 10, location: LatLng(14.7150, -17.2700), distanceFromStart: '20.0 km', estimatedTime: '30:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_11', name: 'Bargny', sequence: 11, location: LatLng(14.7100, -17.2350), distanceFromStart: '26.0 km', estimatedTime: '36:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'ter_12', name: 'Diamniadio', sequence: 12, location: LatLng(14.7160, -17.1986), distanceFromStart: '35.0 km', estimatedTime: '45:00', isTerminal: true, type: 'Arrivée'),
      ];

      if (isReturnRoute) {
        terStops = terStops.reversed.toList();
        for (int i = 0; i < terStops.length; i++) {
          terStops[i] = DetailedStop(
            stopId: 'ter_ret_$i',
            name: terStops[i].name,
            sequence: i + 1,
            location: terStops[i].location,
            distanceFromStart: '${(35.0 - double.parse(terStops[i].distanceFromStart.replaceAll(' km', ''))).toStringAsFixed(1)} km',
            estimatedTime: '${i * 4}:00',
            isTerminal: i == 0 || i == terStops.length - 1,
            type: i == 0 ? 'Embarquement' : (i == terStops.length - 1 ? 'Arrivée' : 'Intermédiaire'),
          );
        }
      }

      return DetailedRoute(
        routeId: isReturnRoute ? 'TER_DIAM_DAK' : 'TER_DAK_DIAM',
        lineNumber: 1,
        operator: 'TER (Train Express Régional)',
        color: AppColors.ter,
        origin: isReturnRoute ? 'Gare de Diamniadio' : 'Gare de Dakar',
        destination: isReturnRoute ? 'Gare de Dakar' : 'Gare de Diamniadio',
        totalDistance: '35.0 km',
        stops: terStops,
      );
    } else if (stop.modeLabel == 'BRT') {
      List<DetailedStop> brtStops = [
        const DetailedStop(stopId: 'brt_1', name: 'Guédiawaye', sequence: 1, location: LatLng(14.7735, -17.3977), distanceFromStart: '0 km', estimatedTime: '00:00', isTerminal: true, type: 'Embarquement'),
        const DetailedStop(stopId: 'brt_2', name: 'Hôpital Dalal Jamm', sequence: 2, location: LatLng(14.7620, -17.4100), distanceFromStart: '1.5 km', estimatedTime: '04:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_3', name: 'Cambérène', sequence: 3, location: LatLng(14.7480, -17.4250), distanceFromStart: '3.0 km', estimatedTime: '08:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_4', name: 'Fadia', sequence: 4, location: LatLng(14.7350, -17.4350), distanceFromStart: '4.2 km', estimatedTime: '11:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_5', name: 'Parcelles Assainies', sequence: 5, location: LatLng(14.7220, -17.4420), distanceFromStart: '5.5 km', estimatedTime: '15:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_6', name: 'Grand Médine', sequence: 6, location: LatLng(14.7150, -17.4450), distanceFromStart: '6.5 km', estimatedTime: '18:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_7', name: 'Grand Yoff', sequence: 7, location: LatLng(14.7050, -17.4400), distanceFromStart: '7.8 km', estimatedTime: '22:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_8', name: 'Liberté 6', sequence: 8, location: LatLng(14.7150, -17.4580), distanceFromStart: '9.2 km', estimatedTime: '26:00', isTerminal: false, type: 'Correspondance'),
        const DetailedStop(stopId: 'brt_9', name: 'Sacré-Cœur', sequence: 9, location: LatLng(14.7100, -17.4650), distanceFromStart: '10.5 km', estimatedTime: '30:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_10', name: 'Place de l’Obélisque', sequence: 10, location: LatLng(14.6850, -17.4500), distanceFromStart: '12.5 km', estimatedTime: '36:00', isTerminal: false, type: 'Intermédiaire'),
        const DetailedStop(stopId: 'brt_11', name: 'Gare de Petersen', sequence: 11, location: LatLng(14.6720, -17.4400), distanceFromStart: '14.0 km', estimatedTime: '42:00', isTerminal: true, type: 'Arrivée'),
      ];

      if (isReturnRoute) {
        brtStops = brtStops.reversed.toList();
        for (int i = 0; i < brtStops.length; i++) {
          brtStops[i] = DetailedStop(
            stopId: 'brt_ret_$i',
            name: brtStops[i].name,
            sequence: i + 1,
            location: brtStops[i].location,
            distanceFromStart: '${(14.0 - double.parse(brtStops[i].distanceFromStart.replaceAll(' km', ''))).toStringAsFixed(1)} km',
            estimatedTime: '${i * 4}:00',
            isTerminal: i == 0 || i == brtStops.length - 1,
            type: i == 0 ? 'Embarquement' : (i == brtStops.length - 1 ? 'Arrivée' : 'Intermédiaire'),
          );
        }
      }

      return DetailedRoute(
        routeId: isReturnRoute ? 'BRT_PET_GUE' : 'BRT_GUE_PET',
        lineNumber: 1,
        operator: 'SunuBRT',
        color: AppColors.brt,
        origin: isReturnRoute ? 'Gare de Petersen' : 'Guédiawaye',
        destination: isReturnRoute ? 'Guédiawaye' : 'Gare de Petersen',
        totalDistance: '14.0 km',
        stops: brtStops,
      );
    } else {
      final originName = stop.name;
      final destName = DirectionHelper.extractDestination(stop.direction);
      
      List<DetailedStop> generalStops = [
        DetailedStop(stopId: 'gen_1', name: originName, sequence: 1, location: stop.location, distanceFromStart: '0 km', estimatedTime: '00:00', isTerminal: true, type: 'Embarquement'),
        DetailedStop(stopId: 'gen_2', name: 'Station Intermédiaire', sequence: 2, location: LatLng(stop.location.latitude + 0.01, stop.location.longitude + 0.01), distanceFromStart: '1.8 km', estimatedTime: '06:00', isTerminal: false, type: 'Intermédiaire'),
        DetailedStop(stopId: 'gen_3', name: destName, sequence: 3, location: LatLng(stop.location.latitude + 0.02, stop.location.longitude + 0.02), distanceFromStart: '3.5 km', estimatedTime: '12:00', isTerminal: true, type: 'Arrivée'),
      ];

      if (isReturnRoute) {
        generalStops = generalStops.reversed.toList();
        for (int i = 0; i < generalStops.length; i++) {
          generalStops[i] = DetailedStop(
            stopId: 'gen_ret_$i',
            name: generalStops[i].name,
            sequence: i + 1,
            location: generalStops[i].location,
            distanceFromStart: '${(3.5 - double.parse(generalStops[i].distanceFromStart.replaceAll(' km', ''))).toStringAsFixed(1)} km',
            estimatedTime: '${i * 6}:00',
            isTerminal: i == 0 || i == generalStops.length - 1,
            type: i == 0 ? 'Embarquement' : (i == generalStops.length - 1 ? 'Arrivée' : 'Intermédiaire'),
          );
        }
      }

      return DetailedRoute(
        routeId: 'GEN_${stop.modeLabel}',
        lineNumber: 1,
        operator: stop.modeLabel,
        color: stop.color,
        origin: isReturnRoute ? destName : originName,
        destination: isReturnRoute ? originName : destName,
        totalDistance: '3.5 km',
        stops: generalStops,
      );
    }
  }
}

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

  bool get isContinuousFlow => modeLabel == 'AFTU' || modeLabel == 'Tata' || modeLabel == 'DDD';

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
  bool get isDedicated => type == 'TER' || type == 'BRT';
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
// STATIONS ET ARRETS OFFICIELS (TER, BRT, DDD & TATA)
// ============================================================
final List<Stop> terStations = [
  Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar (Arrivée)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 0), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6792, -17.4407), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
  Stop(name: 'Gare TER Dakar', direction: 'Dir. Diamniadio (Embarquement)', distanceMeters: 350, departureMinutesFromMidnight: _shift(_terBase, 3), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6795, -17.4405), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: _shift(_terBase, 5), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.6937, -17.4441), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: _shift(_terBase, 9), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7190, -17.4450), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: _shift(_terBase, 17), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7550, -17.3900), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Dakar / Diamniadio', distanceMeters: 14200, departureMinutesFromMidnight: _shift(_terBase, 27), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7750, -17.3100), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.correspondence),
  Stop(name: 'Gare TER Diamniadio', direction: 'Dir. Dakar (Embarquement)', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 50), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7160, -17.1986), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.boarding),
  Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio (Arrivée)', distanceMeters: 35000, departureMinutesFromMidnight: _shift(_terBase, 48), icon: Icons.train_rounded, color: AppColors.ter, location: const LatLng(14.7163, -17.1980), modeLabel: 'TER', source: DataSourceInfo.seter, stopType: StopType.arrival),
];

final List<Stop> brtStations = [
  Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: _shift(_brtBase, 0), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6720, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
  Stop(name: 'BRT Colobane', direction: 'Dir. Guediawaye', distanceMeters: 150, departureMinutesFromMidnight: _shift(_brtBase, 2), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.6950, -17.4420), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guediawaye', distanceMeters: 1500, departureMinutesFromMidnight: _shift(_brtBase, 4), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7050, -17.4400), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.boarding),
  Stop(name: 'PEM Guediawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: _shift(_brtBase, 8), icon: Icons.directions_bus_rounded, color: AppColors.brt, location: const LatLng(14.7735, -17.3977), modeLabel: 'BRT', source: DataSourceInfo.sunubrt, stopType: StopType.terminus),
];

final List<Stop> dddStations = [
  Stop(name: 'DDD Ligne 1 (Colobane - Yoff)', direction: 'Dir. Yoff Pêcheurs', distanceMeters: 1200, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6950, -17.4440), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 3 (Sandaga - Ouakam)', direction: 'Dir. Cité Mamelles', distanceMeters: 900, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6730, -17.4420), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 10 (Liberté 6 - Patte d’Oie)', direction: 'Dir. Terminus Parcelles', distanceMeters: 2400, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.7150, -17.4580), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.correspondence),
  Stop(name: 'DDD Ligne 14 (Gare Maritime - UCAD)', direction: 'Dir. Université Cheikh Anta Diop', distanceMeters: 1800, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6900, -17.4600), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.boarding),
  Stop(name: 'DDD Ligne 20 (Petersen - Rufisque)', direction: 'Dir. Gare Rufisque', distanceMeters: 500, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: const LatLng(14.6720, -17.4390), modeLabel: 'DDD', source: DataSourceInfo.demdikk, stopType: StopType.terminus),
];

final List<Stop> tataStations = [
  Stop(name: 'TATA Ligne 50 (Guédiawaye - Sandaga)', direction: 'Dir. Sandaga Centre', distanceMeters: 800, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7700, -17.3950), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 64 (Pikine - Liberté 6)', direction: 'Dir. Liberté 6 Extension', distanceMeters: 1300, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7500, -17.3880), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 78 (Yoff - Petersen)', direction: 'Dir. PEM Petersen', distanceMeters: 2100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7500, -17.4680), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.boarding),
  Stop(name: 'TATA Ligne 218 (Mermoz - Keur Massar)', direction: 'Dir. Keur Massar', distanceMeters: 3100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_filled, color: AppColors.tata, location: const LatLng(14.7120, -17.4650), modeLabel: 'Tata', source: DataSourceInfo.tataOfficial, stopType: StopType.correspondence),
];

final List<Stop> aftuAndBusStations = [
  Stop(name: 'Parcelles Assainies (L1 à L10)', direction: 'Dir. Dakar Centre', distanceMeters: 300, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7645, -17.4420), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.boarding),
  Stop(name: 'Grand Yoff (L11 à L25)', direction: 'Dir. Petersen', distanceMeters: 1100, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.7420, -17.4480), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.correspondence),
  Stop(name: 'Terminus Petersen (AFTU L25)', direction: 'Terminus central AFTU', distanceMeters: 450, departureMinutesFromMidnight: [], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: const LatLng(14.6720, -17.4400), modeLabel: 'AFTU', source: DataSourceInfo.aftuOfficial, stopType: StopType.terminus),
];

final List<Stop> allStops = [...terStations, ...brtStations, ...dddStations, ...tataStations, ...aftuAndBusStations]
    .where((s) => DakarBounds.isValid(s.location))
    .toList();

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
      const LatLng(14.6720, -17.4400), const LatLng(14.6850, -17.4500),
      const LatLng(14.7100, -17.4650), const LatLng(14.7150, -17.4580),
      const LatLng(14.7050, -17.4400), const LatLng(14.7220, -17.4420),
      const LatLng(14.7350, -17.4350), const LatLng(14.7480, -17.4250),
      const LatLng(14.7620, -17.4100), const LatLng(14.7735, -17.3977),
    ],
  ),
  TransitRoute(
    name: 'DDD Lignes', code: 'DDD', type: 'DDD', color: AppColors.ddd,
    points: [
      const LatLng(14.6950, -17.4440), const LatLng(14.6730, -17.4420), const LatLng(14.6720, -17.4390),
    ],
  ),
  TransitRoute(
    name: 'TATA Bus', code: 'TATA', type: 'Tata', color: AppColors.tata,
    points: [
      const LatLng(14.7700, -17.3950), const LatLng(14.7500, -17.3880), const LatLng(14.7120, -17.4650),
    ],
  ),
];

class RoutePlanner {
  static RouteSearchResult plan({required String fromQuery, required String toQuery}) {
    final now = DateTime.now();
    final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);
    if (!isOpen) {
      return const RouteSearchResult(errorMessage: '🌙 Les réseaux TER, BRT, DDD et TATA sont actuellement fermés.');
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
      return '🔴 Bondé';
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

class DirectionHelper {
  static String extractDestination(String direction) {
    if (direction.contains('Dir.')) {
      return direction.replaceAll('Dir.', '').trim();
    }
    if (direction.contains('-')) {
      final parts = direction.split('-').map((s) => s.trim()).toList();
      return parts.last;
    }
    return 'Terminus / Centre';
  }
}

class DakarBusApp extends StatelessWidget {
  const DakarBusApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return MaterialApp(
          title: 'Dakar Bus',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background(dark),
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: dark ? Brightness.dark : Brightness.light),
            appBarTheme: AppBarTheme(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
          ),
          home: const MainShell(),
        );
      },
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
    _requestLocation();
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
        setState(() { _gpsState = GpsState.denied; _gpsMessage = 'Permission refusée.'; }); return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      if (DakarBounds.isValid(latLng)) {
        setState(() { _userPosition = latLng; _gpsState = GpsState.granted; _gpsMessage = null; });
      } else {
        setState(() { _userPosition = const LatLng(14.7100, -17.4200); _gpsState = GpsState.granted; _gpsMessage = 'Centré sur Dakar.'; });
      }
    } catch (_) { setState(() { _gpsState = GpsState.error; _gpsMessage = 'Erreur GPS.'; }); }
  }

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
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
        decoration: BoxDecoration(color: AppColors.surface(dark), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.surface(dark),
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
// EXPLORER (STYLE CITYMAPPER : ENCADRÉ COMPACT + POSITION USAGER CENTRÉE)
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition; final GpsState gpsState; final String? gpsMessage; final Future<void> Function() onRequestLocation;
  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.gpsMessage, required this.onRequestLocation});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final MapController _mapController = MapController();
  
  LatLng get _currentCenter => (widget.userPosition != null && DakarBounds.isValid(widget.userPosition!)) 
      ? widget.userPosition! 
      : const LatLng(14.7100, -17.4200);

  String _selectedFilter = 'Tous';
  bool _mapVisible = true;

  double _mapTargetHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return (h * 0.20).clamp(160.0, 200.0);
  }
  
  bool _searchFocused = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Polyline> _dynamicPolylines = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() { 
    super.initState(); 
    _loadDynamicRoutes(); 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_currentCenter, 14.0);
    });
  }

  @override
  void didUpdateWidget(covariant ExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userPosition != null && widget.userPosition != oldWidget.userPosition) {
      _mapController.move(widget.userPosition!, 14.0);
    }
  }

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
      loaded.add(Polyline(points: fullRoutePoints, color: route.color, strokeWidth: 5.0));
    }
    if (mounted) setState(() { _dynamicPolylines = loaded; _isLoadingRoutes = false; });
  }

  List<Stop> get _filteredStops {
    List<Stop> base;
    if (_selectedFilter == '⭐ Favoris') {
      base = allStops.where((s) => globalState.isFavorite(s.name)).toList();
    } else {
      switch (_selectedFilter) {
        case 'TER': base = allStops.where((s) => s.color == AppColors.ter).toList(); break;
        case 'BRT': base = allStops.where((s) => s.color == AppColors.brt).toList(); break;
        case 'DDD': base = allStops.where((s) => s.color == AppColors.ddd).toList(); break;
        case 'TATA': base = allStops.where((s) => s.color == AppColors.tata).toList(); break;
        case 'AFTU': base = allStops.where((s) => s.color == AppColors.aftu).toList(); break;
        default: base = List.from(allStops); break;
      }
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

  void _centerOnStop(Stop s) => _mapController.move(s.location, 15.0);
  void _openAI() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatPage()));

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    final stops = _filteredStops;
    final activePolylines = _dynamicPolylines.isNotEmpty ? _dynamicPolylines : demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 5.0)).toList();
    final mapStops = _selectedFilter == 'Tous' ? allStops : _filteredStops;

    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.surface(dark),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: SizedBox(
                    height: 26,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _mapVisible = !_mapVisible),
                      icon: Icon(_mapVisible ? Icons.keyboard_arrow_up : Icons.map, size: 13),
                      label: Text(
                        _mapVisible ? 'Réduire la carte' : 'Afficher la carte',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _mapVisible ? _mapTargetHeight(context) : 0,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.surface(dark)),
                  child: !_mapVisible
                      ? const SizedBox.shrink()
                      : ClipRect(
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _currentCenter,
                                  initialZoom: 14.0,
                                  minZoom: 9,
                                  maxZoom: 17,
                                  cameraConstraint: CameraConstraint.contain(
                                    bounds: LatLngBounds(
                                      const LatLng(DakarBounds.south, DakarBounds.west),
                                      const LatLng(DakarBounds.north, DakarBounds.east),
                                    ),
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'dakar_bus',
                                    maxZoom: 19,
                                  ),
                                  PolylineLayer(polylines: activePolylines),
                                  MarkerLayer(
                                    markers: mapStops
                                        .where((s) => DakarBounds.isValid(s.location))
                                        .map((s) => Marker(
                                              point: s.location,
                                              width: 16,
                                              height: 16,
                                              child: GestureDetector(
                                                onTap: () {
                                                  _centerOnStop(s);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => DualStopDetailPage(stop: s),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: s.color,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 1.5),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.3),
                                                        blurRadius: 3,
                                                      )
                                                    ],
                                                  ),
                                                  child: Icon(s.icon, color: Colors.white, size: 8),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                  if (widget.userPosition != null &&
                                      DakarBounds.isValid(widget.userPosition!))
                                    MarkerLayer(markers: [
                                      Marker(
                                        point: widget.userPosition!,
                                        width: 18,
                                        height: 18,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.4),
                                                blurRadius: 4,
                                              )
                                            ],
                                          ),
                                        ),
                                      )
                                    ]),
                                ],
                              ),
                              Positioned(
                                bottom: 8, left: 8,
                                child: Material(
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(16),
                                  color: AppColors.surface(dark),
                                  child: InkWell(
                                    onTap: () {
                                      if (widget.userPosition != null) {
                                        _mapController.move(widget.userPosition!, 14.5);
                                      } else {
                                        widget.onRequestLocation();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.my_location, color: AppColors.primary, size: 12),
                                          SizedBox(width: 4),
                                          Text('Ma position',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8, right: 8,
                                child: ElevatedButton.icon(
                                  onPressed: _openAI,
                                  icon: const Icon(Icons.auto_awesome, size: 11),
                                  label: const Text('Assistant IA',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    elevation: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    children: [
                      if (!_mapVisible) ...[
                        Row(children: [
                          Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 16)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Dakar Bus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                            Text('TER / BRT / DDD / TATA / AFTU', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark)))
                          ])),
                        ]),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider(dark)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: TextField(
                          controller: _searchCtrl, 
                          onChanged: (_) => setState(() => _searchFocused = true), 
                          style: TextStyle(color: AppColors.textPrimary(dark)),
                          decoration: InputDecoration(
                            hintText: 'On va où ? (ex: Colobane, Yoff...)', 
                            hintStyle: TextStyle(color: AppColors.textSecondary(dark)),
                            prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 18), 
                            suffixIcon: _searchFocused ? IconButton(icon: Icon(Icons.close, size: 14, color: AppColors.textSecondary(dark)), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null, 
                            border: InputBorder.none, 
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                          ),
                        ),
                      ),
                      if (_searchFocused && _searchResults.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider(dark))),
                          child: Column(children: _searchResults.map((s) => ListTile(dense: true, leading: Icon(s.icon, color: s.color, size: 16), title: Text(s.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary(dark))), subtitle: Text(s.direction, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark))), onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); })).toList()),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('Tous'), _chip('⭐ Favoris'), _chip('TER'), _chip('BRT'), _chip('DDD'), _chip('TATA'), _chip('AFTU')])),
                      const SizedBox(height: 12),
                      Row(children: [
                        Text('${stops.length} arrêts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))), 
                        const SizedBox(width: 6), 
                        Text('à proximité', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(dark)))
                      ]),
                      const SizedBox(height: 8),
                      ...stops.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: () => _centerOnStop(s), child: StopCard(stop: s, distanceMeters: _distanceTo(s))))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label) {
    final dark = globalState.darkMode;
    final color = _colorFor(label); 
    final sel = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6), 
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label), 
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : AppColors.surface(dark), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: sel ? color : AppColors.divider(dark), width: sel ? 1.5 : 1)
          ), 
          child: Text(label, style: TextStyle(color: sel ? color : AppColors.textSecondary(dark), fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 11))
        ),
      ),
    );
  }

  Color _colorFor(String label) { 
    switch (label) { 
      case '⭐ Favoris': return Colors.amber;
      case 'TER': return AppColors.ter; 
      case 'BRT': return AppColors.brt; 
      case 'DDD': return AppColors.ddd;
      case 'TATA': return AppColors.tata;
      case 'AFTU': return AppColors.aftu; 
      default: return AppColors.primary; 
    } 
  }
}

class StopCard extends StatelessWidget {
  final Stop stop; final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        final isFav = globalState.isFavorite(stop.name);
        final remaining = stop.remainingMinutes();
        final crowd = TimeHelper.getCrowdLevel(stop);
        Widget timeWidget;

        final now = DateTime.now();
        final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);

        if (!isOpen) {
          timeWidget = Text('Fermé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark)));
        } else if (remaining == null) { 
          timeWidget = Text('Bientôt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary(dark))); 
        } else if (remaining <= 0) { 
          timeWidget = Text('Imminent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stop.color)); 
        } else { 
          timeWidget = Text(TimeHelper.formatRemaining(remaining), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)); 
        }

        return GestureDetector(
          onLongPress: () {
            globalState.toggleFavorite(stop.name);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isFav ? '${stop.name} retiré des favoris' : '${stop.name} ajouté aux favoris ⭐'),
              duration: const Duration(seconds: 1),
            ));
          },
          child: Container(
            decoration: BoxDecoration(
              color: isFav ? AppColors.primary.withOpacity(dark ? 0.15 : 0.05) : AppColors.surface(dark), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: isFav ? AppColors.primary : AppColors.divider(dark), width: isFav ? 1.5 : 1), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DualStopDetailPage(stop: stop))),
              leading: CircleAvatar(backgroundColor: stop.color, radius: 20, child: Icon(stop.icon, color: Colors.white, size: 18)),
              title: Row(
                children: [
                  Expanded(child: Text(stop.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)))),
                  _buildStopTypeBadge(stop.stopType),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.direction, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary(dark))),
                    const SizedBox(height: 2),
                    Text('${DistanceHelper.format(distanceMeters)} • ${stop.modeLabel} (${stop.source.badgeEmoji}) • $crowd', style: TextStyle(fontSize: 9, color: AppColors.textSecondary(dark))),
                  ],
                ),
              ),
              trailing: timeWidget,
            ),
          ),
        );
      },
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
      case StopType.intermediate: color = Colors.grey; label = 'INTERM.'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.4), width: 0.8)),
      child: Text(label, style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class DualStopDetailPage extends StatelessWidget {
  final Stop stop;
  const DualStopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;
    final opposite = OppositeStopService.findOppositeStop(currentStop: stop, allStops: allStops);

    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStopSection(context, stop, 'Sens Actuel / Direction', dark),
          if (opposite != null) ...[
            const SizedBox(height: 20),
            Row(children: [const Icon(Icons.swap_horiz, color: AppColors.primary), const SizedBox(width: 8), Text('Sens Opposé Détecté', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark)))]),
            const SizedBox(height: 10),
            _buildStopSection(context, opposite, 'Sens Retour / Croisement', dark),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailedRoutePage(route: DetailedRoute.fromStop(stop)))),
            icon: const Icon(Icons.alt_route),
            label: const Text('Voir le parcours complet de la ligne'),
            style: ElevatedButton.styleFrom(backgroundColor: stop.color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildStopSection(BuildContext context, Stop s, String title, bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: s.color.withOpacity(0.4), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: s.color)),
          const SizedBox(height: 8),
          Text(s.direction, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
          const SizedBox(height: 6),
          Text('Opérateur : ${s.source.label}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(dark))),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text('Prochains départs :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: s.isContinuousFlow 
              ? [Chip(label: const Text('En rotation continue (~5 min)'), backgroundColor: s.color.withOpacity(0.1))]
              : s.departureMinutesFromMidnight.take(6).map((m) => Chip(
                  label: Text('${(m ~/ 60).toString().padLeft(2, '0')}h${(m % 60).toString().padLeft(2, '0')}'),
                  backgroundColor: AppColors.surface(dark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.divider(dark))),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

class DetailedRoutePage extends StatefulWidget {
  final DetailedRoute route;
  const DetailedRoutePage({super.key, required this.route});

  @override
  State<DetailedRoutePage> createState() => _DetailedRoutePageState();
}

class _DetailedRoutePageState extends State<DetailedRoutePage> {
  late DetailedRoute _currentRoute;
  bool _isReturn = false;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.route;
  }

  void _toggleDirection() {
    setState(() {
      _isReturn = !_isReturn;
      final dummyStop = Stop(name: _currentRoute.origin, direction: _currentRoute.destination, distanceMeters: 0, departureMinutesFromMidnight: [], icon: Icons.directions_bus, color: _currentRoute.color, location: _currentRoute.stops.first.location, modeLabel: _currentRoute.operator.contains('TER') ? 'TER' : (_currentRoute.operator.contains('BRT') ? 'BRT' : 'DDD'));
      _currentRoute = DetailedRoute.fromStop(dummyStop, isReturnRoute: _isReturn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = globalState.darkMode;

    return Scaffold(
      backgroundColor: AppColors.background(dark),
      appBar: AppBar(
        title: Text('${_currentRoute.operator} (Ligne ${_currentRoute.lineNumber})'),
        backgroundColor: _currentRoute.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Inverser sens',
            onPressed: _toggleDirection,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(16), border: Border.all(color: _currentRoute.color.withOpacity(0.5), width: 1.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.trip_origin, color: _currentRoute.color, size: 18), const SizedBox(width: 8), Text('Origine : ${_currentRoute.origin}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(dark)))]),
                const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(height: 16, child: VerticalDivider(color: Colors.grey))),
                Row(children: [Icon(Icons.location_on, color: _currentRoute.color, size: 18), const SizedBox(width: 8), Text('Destination : ${_currentRoute.destination}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(dark)))]),
                const SizedBox(height: 12),
                Text('Distance totale : ${_currentRoute.totalDistance} • ${_currentRoute.stops.length} stations', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Arrêts desservis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
          const SizedBox(height: 10),
          ..._currentRoute.stops.asMap().entries.map((entry) {
            final idx = entry.key;
            final stop = entry.value;
            final isLast = idx == _currentRoute.stops.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: stop.isTerminal ? _currentRoute.color : AppColors.surface(dark), shape: BoxShape.circle, border: Border.all(color: _currentRoute.color, width: 3))),
                      if (!isLast) Expanded(child: Container(width: 3, color: _currentRoute.color.withOpacity(0.4))),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider(dark))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stop.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(dark))),
                                  const SizedBox(height: 2),
                                  Text('Distance: ${stop.distanceFromStart} • Temps estimé: ${stop.estimatedTime}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(dark))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _currentRoute.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(stop.type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _currentRoute.color)),
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
    return AnimatedBuilder(
      animation: globalState,
      builder: (context, _) {
        final dark = globalState.darkMode;
        return Scaffold(
          backgroundColor: AppColors.background(dark),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Planifier un trajet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary(dark))),
                const SizedBox(height: 4),
                Text('Itinéraires multimodaux officiels (TER, BRT, DDD, TATA, AFTU).', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(dark))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface(dark), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      TextField(controller: _fromCtrl, decoration: const InputDecoration(labelText: 'Départ', prefixIcon: Icon(Icons.my_location))),
                      const SizedBox(height: 12),
                      TextField(controller: _toCtrl, decoration: const InputDecoration(labelText: 'Destination', prefixIcon: Icon(Icons.location_on))),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _search,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52)),
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Rechercher mon itinéraire', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  ..._result!.routes.map((r) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('${r.fromName} -> ${r.toName} (${r.totalMinutes} min)')))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes trafic')),
      body: const Center(child: Text('Réseaux officiels TER, BRT, DDD, TATA opérationnels.')),
    );
  }
}

class CommunityAlertsPage extends StatelessWidget {
  const CommunityAlertsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Direct rue')),
      body: const Center(child: Text('Signalements en temps réel.')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          SwitchListTile(title: const Text('Mode sombre'), value: globalState.darkMode, onChanged: (v) => globalState.toggleDarkMode(v)),
        ],
      ),
    );
  }
}

class AIChatPage extends StatelessWidget {
  const AIChatPage({super.key}); // Corrigé ici (AIChatPage au lieu de AIChatPoint)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA')),
      body: const Center(child: Text('Posez vos questions sur les lignes de transport à Dakar.')),
    );
  }
}
