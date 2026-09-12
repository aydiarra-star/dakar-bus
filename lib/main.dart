import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const DakarBusApp());

// ============================================================
// COULEURS
// ============================================================
class AppColors {
  static const primary = Color(0xFF00695C);
  static const brt = Color(0xFF1976D2);
  static const ter = Color(0xFFE53935);
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
// STATUT
// ============================================================
enum DataStatus { scheduled, live, unknown }

class DataStatusBadge extends StatelessWidget {
  final DataStatus status;
  final bool compact;
  const DataStatusBadge({super.key, required this.status, this.compact = false});

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
        label = 'Programmé';
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
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotOnly)
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
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

// ============================================================
// MODÈLES
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
  final String modeLabel; // 'TER', 'BRT', 'AFTU', 'Tata', 'DDD'

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
    return '${h}h$m';
  }
}

class TransitRoute {
  final String name, code, type;
  final Color color;
  final List<LatLng> points;
  const TransitRoute({
    required this.name, required this.code, required this.type,
    required this.color, required this.points,
  });
}

class FavoriteRoute {
  final String label;
  final String from;
  final String to;
  final IconData icon;
  const FavoriteRoute({required this.label, required this.from, required this.to, required this.icon});
}

// Segment d'itinéraire
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
  });
}

class PlannedRoute {
  final String fromName;
  final String toName;
  final List<RouteSegment> segments;
  final int totalMinutes;
  final bool isBest;
  final DataStatus status;

  const PlannedRoute({
    required this.fromName,
    required this.toName,
    required this.segments,
    required this.totalMinutes,
    this.isBest = false,
    this.status = DataStatus.scheduled,
  });
}

// Résultat de recherche
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
// DONNÉES
// ============================================================
final List<Stop> terStations = [
  const Stop(name: 'Gare TER Dakar', direction: 'Terminus Dakar', distanceMeters: 350, departureMinutesFromMidnight: [640, 700, 720, 740, 800, 820, 900, 960, 1020, 1080, 1140, 1200], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6792, -17.4407), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Colobane', direction: 'Dir. Diamniadio', distanceMeters: 1200, departureMinutesFromMidnight: [645, 705, 725, 745, 805, 825, 905, 965, 1025, 1085, 1145, 1205], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6937, -17.4441), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Hann', direction: 'Dir. Diamniadio', distanceMeters: 3500, departureMinutesFromMidnight: [650, 710, 730, 750, 810, 830, 910, 970, 1030, 1090, 1150, 1210], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7222, -17.4321), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Dalifort', direction: 'Dir. Diamniadio', distanceMeters: 5100, departureMinutesFromMidnight: [655, 715, 735, 755, 815, 835, 915, 975, 1035, 1095, 1155, 1215], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7410, -17.4120), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Baux Maraîchers', direction: 'Dir. Diamniadio', distanceMeters: 6300, departureMinutesFromMidnight: [658, 718, 738, 758, 818, 838, 918, 978, 1038, 1098, 1158, 1218], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7470, -17.4010), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Pikine', direction: 'Dir. Diamniadio', distanceMeters: 7200, departureMinutesFromMidnight: [700, 720, 740, 800, 820, 840, 920, 980, 1040, 1100, 1160, 1220], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7550, -17.3900), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Thiaroye', direction: 'Dir. Diamniadio', distanceMeters: 8100, departureMinutesFromMidnight: [704, 724, 744, 804, 824, 844, 924, 984, 1044, 1104, 1164, 1224], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7588, -17.3803), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Yeumbeul', direction: 'Dir. Diamniadio', distanceMeters: 11500, departureMinutesFromMidnight: [710, 730, 750, 810, 830, 850, 930, 990, 1050, 1110, 1170, 1230], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7700, -17.3400), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Keur Mbaye Fall', direction: 'Dir. Dakar / Diamniadio', distanceMeters: 14200, departureMinutesFromMidnight: [714, 734, 754, 814, 834, 854, 934, 994, 1054, 1114, 1174, 1234], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7750, -17.3100), modeLabel: 'TER'),
  const Stop(name: 'Gare TER PNR', direction: 'Dir. Diamniadio', distanceMeters: 16800, departureMinutesFromMidnight: [718, 738, 758, 818, 838, 858, 938, 998, 1058, 1118, 1178, 1238], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7500, -17.2900), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Rufisque', direction: 'Dir. Diamniadio', distanceMeters: 22100, departureMinutesFromMidnight: [724, 744, 804, 824, 844, 904, 944, 1004, 1064, 1124, 1184, 1244], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7157, -17.2703), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Bargny', direction: 'Dir. Diamniadio', distanceMeters: 28500, departureMinutesFromMidnight: [730, 750, 810, 830, 850, 910, 950, 1010, 1070, 1130, 1190, 1250], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.6900, -17.2200), modeLabel: 'TER'),
  const Stop(name: 'Gare TER Diamniadio', direction: 'Terminus Diamniadio', distanceMeters: 35000, departureMinutesFromMidnight: [740, 800, 820, 840, 900, 920, 960, 1020, 1080, 1140, 1200, 1260], icon: Icons.train_rounded, color: AppColors.ter, location: LatLng(14.7160, -17.1986), modeLabel: 'TER'),
];

final List<Stop> otherStations = [
  const Stop(name: 'PEM Petersen', direction: 'Terminus sud BRT', distanceMeters: 200, departureMinutesFromMidnight: [630, 636, 642, 648, 654, 700, 706, 712, 718, 724, 730, 736], icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6720, -17.4400), modeLabel: 'BRT'),
  const Stop(name: 'BRT Colobane', direction: 'Dir. Guédiawaye', distanceMeters: 150, departureMinutesFromMidnight: [635, 641, 647, 653, 659, 705, 711, 717, 723, 729, 735, 741], icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.6950, -17.4420), modeLabel: 'BRT'),
  const Stop(name: 'BRT Grand Dakar', direction: 'Dir. Guédiawaye', distanceMeters: 1500, departureMinutesFromMidnight: [640, 646, 652, 658, 704, 710, 716, 722, 728, 734, 740, 746], icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7050, -17.4400), modeLabel: 'BRT'),
  const Stop(name: 'BRT Parcelles', direction: 'Dir. Guédiawaye', distanceMeters: 5000, departureMinutesFromMidnight: [650, 656, 702, 708, 714, 720, 726, 732, 738, 744, 750, 756], icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7350, -17.4260), modeLabel: 'BRT'),
  const Stop(name: 'PEM Guédiawaye', direction: 'Terminus nord BRT', distanceMeters: 10500, departureMinutesFromMidnight: [700, 706, 712, 718, 724, 730, 736, 742, 748, 754, 800, 806], icon: Icons.directions_bus_rounded, color: AppColors.brt, location: LatLng(14.7735, -17.3977), modeLabel: 'BRT'),
  const Stop(name: 'Arrêt AFTU 23', direction: 'Dir. Parcelles Assainies', distanceMeters: 280, departureMinutesFromMidnight: [630, 645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.6900, -17.4460), modeLabel: 'AFTU'),
  const Stop(name: 'Arrêt AFTU 10', direction: 'Dir. Grand Yoff', distanceMeters: 450, departureMinutesFromMidnight: [635, 650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920], icon: Icons.directions_bus_outlined, color: AppColors.aftu, location: LatLng(14.7200, -17.4600), modeLabel: 'AFTU'),
  const Stop(name: 'Arrêt Tata 12', direction: 'Dir. Guédiawaye', distanceMeters: 600, departureMinutesFromMidnight: [640, 655, 710, 725, 740, 755, 810, 825, 840, 855, 910, 925], icon: Icons.directions_bus_filled, color: AppColors.tata, location: LatLng(14.7200, -17.4700), modeLabel: 'Tata'),
  const Stop(name: 'Arrêt DDD 12', direction: 'Dir. Ouakam', distanceMeters: 800, departureMinutesFromMidnight: [645, 700, 715, 730, 745, 800, 815, 830, 845, 900, 915, 930], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7250, -17.4900), modeLabel: 'DDD'),
  const Stop(name: 'Arrêt DDD 7', direction: 'Dir. Plateau', distanceMeters: 1200, departureMinutesFromMidnight: [650, 705, 720, 735, 750, 805, 820, 835, 850, 905, 920, 935], icon: Icons.directions_bus_filled_rounded, color: AppColors.ddd, location: LatLng(14.7350, -17.4500), modeLabel: 'DDD'),
];

final List<Stop> allStops = [...terStations, ...otherStations];

final List<Stop> mapPriorityStops = [
  terStations[0], terStations[1], terStations[5], terStations[8], terStations[12],
  otherStations[1], otherStations[4], otherStations[8],
];

final List<TransitRoute> demoRoutes = [
  const TransitRoute(name: 'TER', code: 'TER', type: 'TER', color: AppColors.ter, points: [
    LatLng(14.6792, -17.4407), LatLng(14.6937, -17.4441), LatLng(14.7222, -17.4321),
    LatLng(14.7410, -17.4120), LatLng(14.7550, -17.3900), LatLng(14.7700, -17.3400),
    LatLng(14.7750, -17.3100), LatLng(14.7500, -17.2900), LatLng(14.7157, -17.2703),
    LatLng(14.6900, -17.2200), LatLng(14.7160, -17.1986),
  ]),
  const TransitRoute(name: 'BRT', code: 'B1', type: 'BRT', color: AppColors.brt, points: [
    LatLng(14.6720, -17.4400), LatLng(14.6950, -17.4420), LatLng(14.7050, -17.4400),
    LatLng(14.7220, -17.4330), LatLng(14.7350, -17.4260), LatLng(14.7520, -17.4100),
    LatLng(14.7735, -17.3977),
  ]),
  const TransitRoute(name: 'AFTU', code: '23', type: 'AFTU', color: AppColors.aftu, points: [
    LatLng(14.7600, -17.4400), LatLng(14.7350, -17.4460), LatLng(14.7080, -17.4485),
    LatLng(14.6900, -17.4460), LatLng(14.6790, -17.4400),
  ]),
  const TransitRoute(name: 'Tata', code: '12', type: 'TATA', color: AppColors.tata, points: [
    LatLng(14.7735, -17.3977), LatLng(14.7480, -17.4280), LatLng(14.7240, -17.4560),
    LatLng(14.7080, -17.4700), LatLng(14.6880, -17.4620), LatLng(14.6750, -17.4400),
  ]),
  const TransitRoute(name: 'DDD', code: 'DDD-12', type: 'DDD', color: AppColors.ddd, points: [
    LatLng(14.7350, -17.5100), LatLng(14.7250, -17.4900), LatLng(14.7100, -17.4700),
    LatLng(14.6950, -17.4550), LatLng(14.6800, -17.4450),
  ]),
];

// ============================================================
// BASE DE LIEUX (pour autocomplétion)
// ============================================================
class Place {
  final String name;
  final String type; // 'place', 'stop', 'station', 'line'
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

  // Villes et quartiers génériques
  final cities = [
    ('Dakar', LatLng(14.6928, -17.4467)),
    ('Plateau', LatLng(14.6720, -17.4400)),
    ('Guédiawaye', LatLng(14.7735, -17.3977)),
    ('Parcelles Assainies', LatLng(14.7600, -17.4400)),
    ('Pikine', LatLng(14.7550, -17.3900)),
    ('Rufisque', LatLng(14.7157, -17.2703)),
    ('Diamniadio', LatLng(14.7160, -17.1986)),
    ('Ouakam', LatLng(14.7250, -17.4900)),
    ('Almadies', LatLng(14.7350, -17.5100)),
    ('Hann', LatLng(14.7222, -17.4321)),
    ('Thiaroye', LatLng(14.7588, -17.3803)),
    ('Yeumbeul', LatLng(14.7700, -17.3400)),
    ('Keur Mbaye Fall', LatLng(14.7750, -17.3100)),
    ('Bargny', LatLng(14.6900, -17.2200)),
  ];

  for (final c in cities) {
    places.add(Place(
      name: c.$1,
      type: 'place',
      icon: Icons.location_city,
      color: AppColors.textSecondary,
      location: c.$2,
    ));
  }

  // Arrêts
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
// MOTEUR DE CALCUL D'ITINÉRAIRES
// ============================================================
class RoutePlanner {
  /// Calcule un itinéraire entre deux lieux.
  /// Utilise uniquement les données statiques disponibles.
  static RouteSearchResult plan({
    required String fromQuery,
    required String toQuery,
  }) {
    final missing = <String>[];
    final routes = <PlannedRoute>[];

    // 1. Résoudre les lieux
    final fromPlace = _resolvePlace(fromQuery);
    final toPlace = _resolvePlace(toQuery);

    if (fromPlace == null) {
      return RouteSearchResult(
        missingData: ['Lieu de départ introuvable dans la base'],
        errorMessage: 'Nous ne reconnaissons pas « $fromQuery ». Essayez un nom de quartier, de ville ou d\'arrêt.',
      );
    }
    if (toPlace == null) {
      return RouteSearchResult(
        missingData: ['Destination introuvable dans la base'],
        errorMessage: 'Nous ne reconnaissons pas « $toQuery ». Essayez un nom de quartier, de ville ou d\'arrêt.',
      );
    }

    // 2. Trouver les arrêts proches du départ et de la destination
    final fromStop = fromPlace.linkedStop ?? _nearestStop(fromPlace.location);
    final toStop = toPlace.linkedStop ?? _nearestStop(toPlace.location);

    if (fromStop == null) {
      return RouteSearchResult(
        missingData: ['Aucun arrêt connu proche du départ'],
        errorMessage: 'Aucun arrêt de transport n\'est répertorié proche de « ${fromPlace.name} ».',
      );
    }
    if (toStop == null) {
      return RouteSearchResult(
        missingData: ['Aucun arrêt connu proche de la destination'],
        errorMessage: 'Aucun arrêt de transport n\'est répertorié proche de « ${toPlace.name} ».',
      );
    }

    // 3. Cas direct : même mode, même famille de ligne
    if (fromStop.modeLabel == toStop.modeLabel &&
        fromStop.name != toStop.name) {
      // Calcul durée basée sur la distance
      final dist = DistanceHelper.haversineMeters(fromStop.location, toStop.location);
      // Vitesse moyenne approximative : 25 km/h pour TER/BRT, 15 km/h pour bus
      final speedKmh = (fromStop.modeLabel == 'TER' || fromStop.modeLabel == 'BRT') ? 30.0 : 15.0;
      final durationMin = ((dist / 1000.0) / speedKmh * 60).ceil();

      routes.add(PlannedRoute(
        fromName: fromPlace.name,
        toName: toPlace.name,
        totalMinutes: durationMin,
        isBest: true,
        status: DataStatus.scheduled,
        segments: [
          RouteSegment(
            modeLabel: fromStop.modeLabel,
            color: fromStop.color,
            icon: fromStop.icon,
            from: fromStop.name,
            to: toStop.name,
            durationMinutes: durationMin,
            departureTime: fromStop.nextDepartureLabel(),
            arrivalTime: _addMinutes(fromStop.nextDepartureLabel(), durationMin),
            status: DataStatus.scheduled,
          ),
        ],
      ));
    }

    // 4. Si pas direct : chercher correspondance via un stop commun
    if (routes.isEmpty) {
      // Chercher une paire (mode1 desservant fromStop, mode2 desservant toStop)
      // On peut passer par le hub Colobane ou un autre stop intermédiaire
      final hubs = allStops.where((s) =>
        s.name.contains('Colobane') || s.name.contains('Petersen') || s.name.contains('Pikine')
      ).toList();

      for (final hub in hubs) {
        final leg1 = _buildSegment(fromStop, hub);
        final leg2 = _buildSegment(hub, toStop);
        if (leg1 != null && leg2 != null) {
          routes.add(PlannedRoute(
            fromName: fromPlace.name,
            toName: toPlace.name,
            totalMinutes: leg1.durationMinutes + leg2.durationMinutes + 5,
            isBest: routes.isEmpty,
            status: DataStatus.scheduled,
            segments: [leg1, leg2],
          ));
          break;
        }
      }
    }

    // 5. Résultat
    if (routes.isEmpty) {
      missing.add('Correspondance connue entre « ${fromStop.name} » et « ${toStop.name} »');
      return RouteSearchResult(
        missingData: missing,
        errorMessage: 'Aucun itinéraire direct ou avec correspondance n\'est disponible dans notre base actuelle.',
      );
    }

    return RouteSearchResult(routes: routes);
  }

  static RouteSegment? _buildSegment(Stop from, Stop to) {
    if (from.name == to.name) return null;
    final dist = DistanceHelper.haversineMeters(from.location, to.location);
    if (dist > 30000) return null; // trop loin
    final speed = (from.modeLabel == 'TER' || from.modeLabel == 'BRT') ? 30.0 : 15.0;
    final durationMin = ((dist / 1000.0) / speed * 60).ceil();
    if (durationMin <= 0) return null;
    return RouteSegment(
      modeLabel: from.modeLabel,
      color: from.color,
      icon: from.icon,
      from: from.name,
      to: to.name,
      durationMinutes: durationMin,
      departureTime: from.nextDepartureLabel(),
      arrivalTime: _addMinutes(from.nextDepartureLabel(), durationMin),
      status: DataStatus.scheduled,
    );
  }

  static Place? _resolvePlace(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    // Correspondance exacte
    for (final p in placeDatabase) {
      if (p.name.toLowerCase() == q) return p;
    }
    // Contient
    for (final p in placeDatabase) {
      if (p.name.toLowerCase().contains(q) || q.contains(p.name.toLowerCase())) {
        return p;
      }
    }
    // Mots clés
    for (final word in q.split(' ')) {
      if (word.length < 3) continue;
      for (final p in placeDatabase) {
        if (p.name.toLowerCase().contains(word)) return p;
      }
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

  static String? _addMinutes(String? time, int minutes) {
    if (time == null) return null;
    final parts = time.split('h');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final total = h * 60 + m + minutes;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}h${nm.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// UTILITAIRES
// ============================================================
class TimeHelper {
  static String formatRemaining(int minutes) {
    if (minutes <= 0) return 'Départ imminent';
    if (minutes == 1) return '1 min';
    return '$minutes min';
  }

  /// Vrai si l'attente dépasse 3h (le prochain bus est probablement
  /// le lendemain — évite l'affichage absurde de type "1199 min").
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

  static double _cos(double x) { final x2 = x * x; return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720; }
  static double _asin(double x) { if (x < -1) return -1.5708; if (x > 1) return 1.5708; return x + (x*x*x)/6 + (3*x*x*x*x*x)/40; }
  static double _sqrt(double x) { if (x <= 0) return 0; double r = x; for (int i = 0; i < 20; i++) { r = (r + x / r) / 2; } return r; }
}

// ============================================================
// APP
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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Timer? _ticker;
  LatLng? _userPosition;
  GpsState _gpsState = GpsState.idle;

  List<FavoriteRoute> _favorites = [
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
    setState(() => _gpsState = GpsState.loading);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _userPosition = const LatLng(14.6937, -17.4441);
      _gpsState = GpsState.granted;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position obtenue'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)),
      );
    }
  }

  void _addFavorite(FavoriteRoute f) => setState(() => _favorites.add(f));
  void _removeFavorite(int i) => setState(() => _favorites.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorerPage(userPosition: _userPosition, gpsState: _gpsState, onRequestLocation: _requestLocation),
      TripsPage(favorites: _favorites),
      const AlertsPage(),
      SettingsPage(favorites: _favorites, onAdd: _addFavorite, onRemove: _removeFavorite),
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
            height: 64,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: AppColors.primary), label: 'Explorer'),
              NavigationDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route, color: AppColors.primary), label: 'Trajets'),
              NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: AppColors.primary), label: 'Alertes'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.primary), label: 'Réglages'),
            ],
          ),
        ),
      ),
    );
  }
}

enum GpsState { idle, loading, granted, denied }

// ============================================================
// EXPLORER
// ============================================================
class ExplorerPage extends StatefulWidget {
  final LatLng? userPosition;
  final GpsState gpsState;
  final Future<void> Function() onRequestLocation;
  const ExplorerPage({super.key, required this.userPosition, required this.gpsState, required this.onRequestLocation});
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
      base.sort((a, b) => DistanceHelper.haversineMeters(widget.userPosition!, a.location).compareTo(DistanceHelper.haversineMeters(widget.userPosition!, b.location)));
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
  void _cycleMapHeight() => setState(() {
    if (_mapHeight == 240) _mapHeight = 320;
    else if (_mapHeight == 320) _mapHeight = 140;
    else _mapHeight = 240;
  });

  @override
  Widget build(BuildContext context) {
    final stops = _filteredStops;

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
                      PolylineLayer(polylines: demoRoutes.map((r) => Polyline(points: r.points, color: r.color, strokeWidth: 3.5)).toList()),
                      MarkerLayer(
                        markers: mapPriorityStops.map((s) => Marker(
                          point: s.location, width: 24, height: 24,
                          child: GestureDetector(
                            onTap: () { _centerOnStop(s); Navigator.push(context, MaterialPageRoute(builder: (_) => StopDetailPage(stop: s))); },
                            child: Container(
                              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)]),
                              child: Icon(s.icon, color: Colors.white, size: 12),
                            ),
                          ),
                        )).toList(),
                      ),
                      if (widget.userPosition != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: widget.userPosition!, width: 18, height: 18,
                            child: Container(decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)])),
                          ),
                        ]),
                    ],
                  ),
                  Positioned(bottom: 12, left: 12, child: _gpsButton()),
                  Positioned(
                    bottom: 12, right: 12,
                    child: ElevatedButton.icon(
                      onPressed: _openAI,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Assistant IA', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
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
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _legend(AppColors.ter, 'TER'), const SizedBox(width: 6),
                        _legend(AppColors.brt, 'BRT'), const SizedBox(width: 6),
                        _legend(AppColors.aftu, 'AFTU'), const SizedBox(width: 6),
                        _legend(AppColors.tata, 'Tata'), const SizedBox(width: 6),
                        _legend(AppColors.ddd, 'DDD'),
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
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 20)),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Dakar Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('TER · BRT · AFTU · Tata · DDD', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() => _searchFocused = true),
                      onTap: () => setState(() => _searchFocused = true),
                      decoration: InputDecoration(
                        hintText: 'Où voulez-vous aller ?',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: _searchFocused ? IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary), onPressed: () { _searchCtrl.clear(); setState(() => _searchFocused = false); }) : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchFocused && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: _searchResults.map((s) => ListTile(
                        dense: true,
                        leading: Icon(s.icon, color: s.color, size: 20),
                        title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Row(children: [Text(s.direction, style: const TextStyle(fontSize: 11)), const SizedBox(width: 6), _categoryChip(s)]),
                        onTap: () { _searchCtrl.text = s.name; setState(() => _searchFocused = false); _centerOnStop(s); },
                      )).toList()),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('Tous'), _chip('TER'), _chip('BRT'), _chip('AFTU'), _chip('Tata'), _chip('DDD')])),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${stops.length} arrêts', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Padding(padding: EdgeInsets.only(bottom: 1), child: Text('À proximité', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  ]),
                  const SizedBox(height: 8),
                  if (stops.isEmpty)
                    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: const Text('Aucun arrêt à proximité', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
                  else
                    ...stops.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(onTap: () => _centerOnStop(s), child: StopCard(stop: s, distanceMeters: _distanceTo(s))),
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
        return FloatingActionButton.small(onPressed: null, backgroundColor: AppColors.surface,
          child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
      case GpsState.granted:
        return FloatingActionButton.small(
          onPressed: () { if (widget.userPosition != null) _mapController.move(widget.userPosition!, 14.5); },
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.my_location, color: AppColors.primary, size: 20));
      default:
        return FloatingActionButton.small(onPressed: () => widget.onRequestLocation(), backgroundColor: AppColors.surface,
          child: const Icon(Icons.location_searching, color: AppColors.primary, size: 20));
    }
  }

  Widget _categoryChip(Stop s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: s.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(s.modeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: s.color)),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
  ]);

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
// CARTE D'ARRÊT
// ============================================================
class StopCard extends StatelessWidget {
  final Stop stop;
  final double distanceMeters;
  const StopCard({super.key, required this.stop, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final next = stop.nextDepartureMinutes();
    final remaining = stop.remainingMinutes();
    final timeLabel = stop.nextDepartureLabel();

    Widget timeWidget;
    if (next == null || remaining == null) {
      timeWidget = const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Horaire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        Text('non disponible', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      ]);
    } else if (remaining <= 0) {
      timeWidget = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Départ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: stop.color)),
        Text('imminent', style: TextStyle(fontSize: 11, color: stop.color, fontWeight: FontWeight.w600)),
      ]);
    } else if (TimeHelper.isProbablyNextDay(remaining)) {
      // CORRECTION : au-delà de 3h d'attente, on affiche "Demain"
      // plutôt qu'un nombre de minutes absurde (ex: 1199 min).
      timeWidget = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('Demain', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        Text(timeLabel ?? '--:--', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]);
    } else {
      final isUrgent = remaining <= 3;
      timeWidget = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(TimeHelper.formatRemaining(remaining), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isUrgent ? AppColors.ter : AppColors.success)),
        Text('d\'attente', style: TextStyle(fontSize: 9, color: isUrgent ? AppColors.ter : AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]);
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop))),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle), child: Icon(stop.icon, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('${stop.direction} · ${DistanceHelper.format(distanceMeters)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              if (next != null && timeLabel != null) ...[
                const SizedBox(height: 4),
                Row(children: [Text('Départ $timeLabel', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(width: 6), DataStatusBadge(status: stop.status, compact: true)]),
              ] else ...[
                const SizedBox(height: 4),
                const DataStatusBadge(status: DataStatus.unknown, compact: true),
              ],
            ])),
            const SizedBox(width: 8),
            timeWidget,
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// TRAJETS — AVEC MOTEUR RÉEL
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
  bool _fromFocus = false;
  bool _toFocus = false;

  List<Place> _suggestions(String query) {
    if (query.trim().length < 2) return [];
    final q = query.toLowerCase();
    return placeDatabase.where((p) => p.name.toLowerCase().contains(q)).take(6).toList();
  }

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
            const SizedBox(height: 8),
            const Text('Planifier un trajet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.favorites.isNotEmpty) ...[
              const Text('Favoris', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.favorites.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () { _toCtrl.text = f.to; _search(); },
                      child: Container(
                        width: 140, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(f.icon, color: AppColors.primary, size: 20),
                          const Spacer(),
                          Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(f.to, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Champs départ / arrivée
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                _autocompleteField(
                  icon: Icons.my_location, color: AppColors.primary, label: 'Départ',
                  ctrl: _fromCtrl, focused: _fromFocus,
                  onFocus: (v) => setState(() => _fromFocus = v),
                  onSelect: (p) { _fromCtrl.text = p.name; setState(() => _fromFocus = false); },
                ),
                const Divider(height: 24),
                _autocompleteField(
                  icon: Icons.location_on, color: AppColors.ter, label: 'Destination',
                  ctrl: _toCtrl, focused: _toFocus,
                  onFocus: (v) => setState(() => _toFocus = v),
                  onSelect: (p) { _toCtrl.text = p.name; setState(() => _toFocus = false); },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text('Recherche de votre trajet...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ])
                      : const Text('Rechercher', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
            // Résultats
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResult(_result!),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(RouteSearchResult res) {
    if (res.hasRoutes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Itinéraires proposés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            const DataStatusBadge(status: DataStatus.scheduled),
          ]),
          const SizedBox(height: 12),
          ...res.routes.asMap().entries.map((entry) {
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _routeCard(r),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'Horaires programmés. Les conditions réelles de circulation peuvent modifier le temps de trajet.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              )),
            ]),
          ),
        ],
      );
    }

    // Pas de routes
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(Icons.route_outlined, size: 40, color: AppColors.warning),
          const SizedBox(height: 12),
          const Text('Itinéraire indisponible', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            res.errorMessage ?? 'Nous ne disposons pas encore de suffisamment de données pour calculer précisément ce trajet.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (res.missingData.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft, child: Text('Données manquantes :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            ...res.missingData.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(m, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            )),
          ],
          const SizedBox(height: 12),
          const DataStatusBadge(status: DataStatus.unknown),
        ],
      ),
    );
  }

  Widget _routeCard(PlannedRoute r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: r.isBest ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (r.isBest) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                child: const Text('Meilleur', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text('${r.fromName} → ${r.toName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Text('${r.totalMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
          ]),
          const SizedBox(height: 12),
          ...r.segments.asMap().entries.map((entry) {
            final seg = entry.value;
            final isLast = entry.key == r.segments.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: seg.color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(seg.icon, color: seg.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(seg.modeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: seg.color)),
                    Text('${seg.from} → ${seg.to}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${seg.durationMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    if (seg.departureTime != null) Text('Départ ${seg.departureTime}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ]),
                ]),
                if (!isLast) Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                  child: Container(width: 2, height: 14, color: AppColors.divider),
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          Row(children: [
            const DataStatusBadge(status: DataStatus.scheduled, compact: true),
            const Spacer(),
            if (r.segments.first.departureTime != null && r.segments.last.arrivalTime != null)
              Text(
                '${r.segments.first.departureTime} → ${r.segments.last.arrivalTime}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _autocompleteField({
    required IconData icon, required Color color, required String label,
    required TextEditingController ctrl, required bool focused,
    required Function(bool) onFocus, required Function(Place) onSelect,
  }) {
    final suggestions = focused ? _suggestions(ctrl.text) : <Place>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            TextField(
              controller: ctrl,
              onTap: () => onFocus(true),
              onChanged: (_) => onFocus(true),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero, hintText: 'Saisir un lieu, une gare, un arrêt...'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ])),
        ]),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: Column(children: suggestions.map((p) => ListTile(
              dense: true,
              leading: Icon(p.icon, color: p.color, size: 18),
              title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(_typeLabel(p.type), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              onTap: () => onSelect(p),
            )).toList()),
          ),
      ],
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'place': return '📍 Lieu';
      case 'TER': return '🚆 Gare TER';
      case 'BRT': return '🚌 Station BRT';
      case 'AFTU': return '🚌 Arrêt AFTU';
      case 'Tata': return '🚌 Arrêt Tata';
      case 'DDD': return '🚌 Arrêt DDD';
      default: return t;
    }
  }
}

// ============================================================
// ALERTES
// ============================================================
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final List<Map<String, dynamic>> _alerts = [
    {'stop': 'BRT Colobane', 'icon': Icons.directions_bus_rounded, 'color': AppColors.brt, 'minutes': 5, 'active': true},
    {'stop': 'Gare TER Dakar', 'icon': Icons.train_rounded, 'color': AppColors.ter, 'minutes': 10, 'active': true},
  ];

  void _showAddAlert() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nouvelle alerte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...allStops.take(6).map((s) => ListTile(
            leading: Icon(s.icon, color: s.color),
            title: Text(s.name),
            onTap: () { Navigator.pop(ctx); setState(() { _alerts.add({'stop': s.name, 'icon': s.icon, 'color': s.color, 'minutes': 10, 'active': true}); }); },
          )),
        ]),
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
            const SizedBox(height: 8),
            Row(children: [
              const Text('Mes alertes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: _showAddAlert, icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28)),
            ]),
            const SizedBox(height: 4),
            Text('${_alerts.where((a) => a['active'] == true).length} alerte(s) active(s)', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ..._alerts.asMap().entries.map((entry) {
              final idx = entry.key;
              final a = entry.value;
              final stop = allStops.firstWhere((s) => s.name == a['stop'], orElse: () => allStops.first);
              final remaining = stop.remainingMinutes();
              final timeLabel = stop.nextDepartureLabel();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (a['color'] as Color).withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: (a['color'] as Color).withOpacity(0.12), shape: BoxShape.circle), child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['stop'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (remaining != null && timeLabel != null)
                        if (TimeHelper.isProbablyNextDay(remaining))
                          Text('Départ prévu demain à $timeLabel', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                        else
                          Text('Départ prévu $timeLabel · dans ${TimeHelper.formatRemaining(remaining)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                      else
                        const Text('Horaire non disponible', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      DataStatusBadge(status: stop.status, compact: true),
                    ])),
                    Switch(value: a['active'] as bool, activeColor: AppColors.primary, onChanged: (v) => setState(() => _alerts[idx]['active'] = v)),
                  ]),
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
// RÉGLAGES
// ============================================================
class SettingsPage extends StatefulWidget {
  final List<FavoriteRoute> favorites;
  final Function(FavoriteRoute) onAdd;
  final Function(int) onRemove;
  const SettingsPage({super.key, required this.favorites, required this.onAdd, required this.onRemove});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _gps = true;

  void _addFavorite() {
    final labelCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau favori'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Maison)')),
          TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'Destination')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && toCtrl.text.isNotEmpty) {
                widget.onAdd(FavoriteRoute(label: labelCtrl.text, from: 'Ma position', to: toCtrl.text, icon: Icons.star_rounded));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Ajouter'),
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
            const SizedBox(height: 8),
            const Text('Paramètres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _section('Général'),
            _toggle('Notifications', 'Alertes de passage', Icons.notifications_outlined, _notifications, (v) => setState(() => _notifications = v)),
            _toggle('Localisation', 'Position sur la carte', Icons.location_on_outlined, _gps, (v) => setState(() => _gps = v)),
            const SizedBox(height: 20),
            Row(children: [
              _section('Mes favoris'),
              const Spacer(),
              TextButton.icon(onPressed: _addFavorite, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
            ]),
            if (widget.favorites.isEmpty)
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: const Text('Aucun favori. Ajoutez vos trajets fréquents.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)))
            else
              ...widget.favorites.asMap().entries.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(entry.value.icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.value.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${entry.value.from} → ${entry.value.to}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  IconButton(onPressed: () => widget.onRemove(entry.key), icon: const Icon(Icons.delete_outline, color: AppColors.ter, size: 20)),
                ]),
              )),
            const SizedBox(height: 20),
            _section('Réseaux'),
            _tileSetting('TER', 'Train Express Régional', Icons.train_rounded, AppColors.ter),
            _tileSetting('BRT', 'Bus Rapid Transit', Icons.directions_bus_rounded, AppColors.brt),
            _tileSetting('AFTU', 'Lignes de bus', Icons.directions_bus_outlined, AppColors.aftu),
            _tileSetting('Tata', 'Bus Tata', Icons.directions_bus_filled, AppColors.tata),
            _tileSetting('DDD', 'Dakar Dem Dikk', Icons.directions_bus_filled_rounded, AppColors.ddd),
            const SizedBox(height: 20),
            _section('À propos'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dakar Bus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Version 3.2', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('Application d\'information voyageurs pour Dakar.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text('Moteur d\'itinéraire basé sur données programmées.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)));

  Widget _toggle(String title, String sub, IconData icon, bool value, Function(bool) onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 22), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Switch(value: value, activeColor: AppColors.primary, onChanged: onChange),
      ]),
    );
  }

  Widget _tileSetting(String title, String sub, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
      ]),
    );
  }
}

// ============================================================
// DÉTAIL ARRÊT
// ============================================================
class StopDetailPage extends StatelessWidget {
  final Stop stop;
  const StopDetailPage({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMin = now.hour * 60 + now.minute;
    final future = stop.departureMinutesFromMidnight.where((d) => d > currentMin).take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(stop.name), backgroundColor: stop.color, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Column(children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: stop.color, shape: BoxShape.circle), child: Icon(stop.icon, color: Colors.white, size: 36)),
            const SizedBox(height: 12),
            Text(stop.direction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('À ${DistanceHelper.format(stop.distanceMeters)} de vous', style: const TextStyle(color: AppColors.textSecondary)),
          ])),
          const SizedBox(height: 24),
          Row(children: [
            const Text('Prochains passages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            DataStatusBadge(status: stop.status),
          ]),
          const SizedBox(height: 12),
          if (future.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Plus de passage aujourd\'hui', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                if (stop.departureMinutesFromMidnight.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Prochain départ demain à ${stop.nextDepartureLabel() ?? "--:--"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ]),
            )
          else
            ...future.map((d) {
              final h = (d ~/ 60).toString().padLeft(2, '0');
              final m = (d % 60).toString().padLeft(2, '0');
              final remaining = d - currentMin;
              final isNext = d == future.first;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isNext ? stop.color.withOpacity(0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isNext ? stop.color.withOpacity(0.4) : AppColors.divider, width: isNext ? 1.5 : 1),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${h}h$m', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isNext ? stop.color : AppColors.textPrimary)),
                  Text(TimeHelper.formatRemaining(remaining), style: TextStyle(color: isNext ? stop.color : AppColors.textSecondary, fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
                ]),
              );
            }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 16), const SizedBox(width: 8),
              const Expanded(child: Text('Horaires programmés. Le temps réel sera affiché dès qu\'il sera disponible.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            ]),
          ),
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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Bonjour ! Je suis l\'assistant Dakar Bus.\n\nJe peux vous renseigner sur :\n• les lignes TER, BRT, AFTU, Tata, DDD\n• les arrêts et stations\n• les horaires programmés\n• les itinéraires (en utilisant les données disponibles)\n\nJe ne dispose pas encore de données temps réel.'},
  ];

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': t});
      _messages.add({'role': 'ai', 'text': _generateResponse(t)});
    });
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  String _normalize(String s) {
    s = s.toLowerCase();
    s = s.replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e');
    s = s.replaceAll('à', 'a').replaceAll('â', 'a');
    s = s.replaceAll('î', 'i').replaceAll('ï', 'i');
    s = s.replaceAll('ô', 'o').replaceAll('ö', 'o');
    s = s.replaceAll('ù', 'u').replaceAll('û', 'u');
    s = s.replaceAll('ç', 'c');
    return s;
  }

  String _generateResponse(String query) {
    final q = _normalize(query);

    for (final stop in allStops) {
      final sn = _normalize(stop.name);
      if (q.contains(sn) || sn.contains(q)) {
        final r = stop.remainingMinutes();
        final t = stop.nextDepartureLabel();
        if (r != null && t != null) {
          if (TimeHelper.isProbablyNextDay(r)) {
            return '📍 ${stop.name}\n\nDirection : ${stop.direction}\nDistance : ${DistanceHelper.format(stop.distanceMeters)}\nPlus de passage aujourd\'hui. Prochain départ demain à $t.\n\n🟠 Horaire programmé, pas temps réel.';
          }
          return '📍 ${stop.name}\n\nDirection : ${stop.direction}\nDistance : ${DistanceHelper.format(stop.distanceMeters)}\nProchain départ : $t (${TimeHelper.formatRemaining(r)})\n\n🟠 Horaire programmé, pas temps réel.';
        }
        return '📍 ${stop.name}\n\nDirection : ${stop.direction}\n\nHoraire non disponible pour le moment.';
      }
    }

    if (q.contains('diamniadio')) return '🚆 Pour Diamniadio : TER depuis la Gare de Dakar. 13 gares desservies. Environ 40 min.\n\n🟠 Horaire programmé.';
    if (q.contains('plateau')) return '🚌 Pour le Plateau : BRT depuis Colobane ou DDD Ligne 7.\n\n🟠 Horaire programmé.';
    if (q.contains('guediawaye')) return '🚌 Pour Guédiawaye : BRT depuis Colobane vers PEM Guédiawaye.\n\n🟠 Horaire programmé.';
    if (q.contains('parcelles')) return '🚌 Pour Parcelles Assainies : AFTU Ligne 23 depuis Colobane.\n\n🟠 Horaire programmé.';
    if (q.contains('ouakam') || q.contains('almadies')) return '🚌 Pour Ouakam / Almadies : DDD Ligne 12.\n\n🟠 Horaire programmé.';
    if (q.contains('rufisque')) return '🚆 Pour Rufisque : TER depuis Dakar, 11ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('thiaroye')) return '🚆 Pour Thiaroye : TER depuis Dakar, 7ème gare.\n\n🟠 Horaire programmé.';
    if (q.contains('keur mbaye')) return '🚆 Keur Mbaye Fall est la 9ème gare du TER (entre Yeumbeul et PNR).\n\n🟠 Horaire programmé.';
    if (q.contains('colobane')) return '📍 Colobane est un hub central : Gare TER Colobane, Station BRT Colobane, Arrêt AFTU 23.';
    if (q.contains('yeumbeul')) return '🚆 Yeumbeul : 8ème gare du TER.\n\n🟠 Horaire programmé.';
    if (q.contains('bargny')) return '🚆 Bargny : 12ème gare du TER.\n\n🟠 Horaire programmé.';
    if (q.contains('hann')) return '🚆 Hann : 3ème gare du TER.\n\n🟠 Horaire programmé.';
    if (q.contains('pikine')) return '🚆 Pikine : 6ème gare du TER.\n\n🟠 Horaire programmé.';

    if (q.contains('ter') || q.contains('train')) return '🚆 Le TER relie Dakar à Diamniadio via 13 gares.\n\n🟠 Horaire programmé.';
    if (q.contains('brt')) return '🚍 Le BRT compte 23 stations entre Petersen et Guédiawaye.\n\n🟠 Horaire programmé.';
    if (q.contains('aftu')) return '🚌 AFTU dessert Dakar avec plusieurs lignes.\n\n🟠 Horaires estimés.';
    if (q.contains('tata')) return '🚌 Les bus Tata couvrent plusieurs quartiers.\n\n🟠 Horaires estimés.';
    if (q.contains('ddd')) return '🚌 Dakar Dem Dikk : plusieurs lignes à Dakar.\n\n🟠 Horaires estimés.';

    if (q.contains('prix') || q.contains('tarif') || q.contains('fcfa')) {
      return 'Je ne dispose pas d\'informations tarifaires fiables pour le moment.';
    }
    if (q.contains('retard') || q.contains('temps reel') || q.contains('live')) {
      return 'Les données temps réel ne sont pas encore connectées. Les horaires affichés sont programmés.';
    }

    if (q.contains('bonjour') || q.contains('salut')) return 'Bonjour ! Comment puis-je vous aider ?';
    if (q.contains('merci')) return 'Avec plaisir !';

    return 'Je n\'ai pas d\'information fiable pour répondre.\n\nEssayez :\n• « Prochain TER »\n• « Où est Colobane ? »\n• « Comment aller à Diamniadio ? »';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Assistant IA'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            final isUser = msg['role'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isUser ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
                ),
                child: Text(msg['text']!, style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ),
            );
          },
        )),
        Container(
          padding: const EdgeInsets.all(8),
          color: AppColors.surface,
          child: SafeArea(top: false, child: Row(children: [
            Expanded(child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Posez votre question...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
            )),
            IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.primary)),
          ])),
        ),
      ]),
    );
  }
}