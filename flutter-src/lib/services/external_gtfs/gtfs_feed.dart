// Modèle GTFS en mémoire — miroir Dart de lib/external-gtfs/models.js.
// Construit à partir des textes des tables (assets), sans modification des
// données : identifiants, noms, heures et dates sont conservés tels quels.

import 'feed_provenance.dart';
import 'gtfs_csv.dart';
import 'gtfs_time.dart';

/// Tables lues par le moteur (les tables tarifaires sont ignorées).
const List<String> engineTables = <String>[
  'agency',
  'routes',
  'stops',
  'trips',
  'stop_times',
  'calendar',
  'calendar_dates',
  'shapes',
  'feed_info',
  'frequencies',
];

const List<String> requiredFiles = <String>[
  'agency',
  'routes',
  'stops',
  'trips',
  'stop_times',
];

const Map<String, List<String>> requiredColumns = <String, List<String>>{
  'agency': <String>['agency_name'],
  'routes': <String>['route_id', 'route_short_name', 'route_long_name', 'route_type'],
  'stops': <String>['stop_id', 'stop_name', 'stop_lat', 'stop_lon'],
  'trips': <String>['route_id', 'service_id', 'trip_id'],
  'stop_times': <String>['trip_id', 'stop_id', 'stop_sequence'],
  'calendar': <String>[
    'service_id',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'start_date',
    'end_date',
  ],
  'calendar_dates': <String>['service_id', 'date', 'exception_type'],
};

class GtfsRoute {
  const GtfsRoute({
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
    required this.agencyId,
  });

  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String routeType;
  final String? agencyId;
}

class GtfsStop {
  const GtfsStop({
    required this.stopId,
    required this.stopName,
    required this.stopLat,
    required this.stopLon,
    required this.locationType,
    required this.parentStation,
  });

  final String stopId;
  final String stopName;
  final double? stopLat;
  final double? stopLon;
  final String? locationType;
  final String? parentStation;
}

class GtfsTrip {
  const GtfsTrip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.tripHeadsign,
    required this.directionId,
    required this.shapeId,
  });

  final String tripId;
  final String routeId;
  final String serviceId;
  final String? tripHeadsign;
  final String? directionId;
  final String? shapeId;
}

class GtfsService {
  GtfsService(this.serviceId);

  final String serviceId;
  final Map<String, bool> weekdays = <String, bool>{};
  String? startDate;
  String? endDate;
  bool hasCalendarRow = false;
  final Set<String> addedDates = <String>{};
  final Set<String> removedDates = <String>{};

  /// Actif à une date : calendar_dates (2 = retiré, 1 = ajouté) puis calendar.
  bool isActiveOn(String date) {
    final String day = normalizeServiceDate(date);
    if (removedDates.contains(day)) return false;
    if (addedDates.contains(day)) return true;
    if (!hasCalendarRow || startDate == null || endDate == null) return false;
    if (day.compareTo(startDate!) < 0 || day.compareTo(endDate!) > 0) return false;
    return weekdays[weekdayOf(day)] == true;
  }
}

class StopTimesColumns {
  final List<String> tripIds = <String>[];
  final List<String> stopIds = <String>[];
  final List<int> sequences = <int>[];

  /// -1 = absent.
  final List<int> arrivals = <int>[];
  final List<int> departures = <int>[];
  int missingTimes = 0;
  int invalidTimes = 0;

  int get count => tripIds.length;
}

class FeedValidation {
  const FeedValidation({
    required this.ok,
    required this.errors,
    required this.warnings,
    required this.counts,
  });

  final bool ok;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, int> counts;
}

class GtfsFeed {
  GtfsFeed(this.provenance, {String? network})
      : network = network ?? provenance.network;

  final FeedProvenance provenance;
  final String? network;
  final Set<String> tables = <String>{};
  final Map<String, List<String>> headers = <String, List<String>>{};
  final List<Map<String, String>> agencies = <Map<String, String>>[];
  final Map<String, GtfsRoute> routes = <String, GtfsRoute>{};
  final Map<String, GtfsStop> stops = <String, GtfsStop>{};
  final Map<String, GtfsTrip> trips = <String, GtfsTrip>{};
  final Map<String, List<String>> tripsByRoute = <String, List<String>>{};
  final Map<String, GtfsService> services = <String, GtfsService>{};
  final StopTimesColumns stopTimes = StopTimesColumns();
  final Map<String, List<int>> stopTimesByTrip = <String, List<int>>{};
  final Map<String, List<int>> stopTimesByStop = <String, List<int>>{};
  final Set<String> shapeIds = <String>{};
  int shapePoints = 0;
  Map<String, String>? feedInfo;
  final List<String> anomalies = <String>[];
  String? calendarStart;
  String? calendarEnd;

  Map<String, int> get counts => <String, int>{
        'agency': agencies.length,
        'routes': routes.length,
        'stops': stops.length,
        'trips': trips.length,
        'stop_times': stopTimes.count,
        'services': services.length,
        'shapes': shapeIds.length,
        'shape_points': shapePoints,
      };

  bool isServiceActive(String serviceId, String date) {
    final GtfsService? s = services[serviceId];
    return s != null && s.isActiveOn(date);
  }

  List<GtfsRoute> routeList() => routes.values.toList();
  List<GtfsStop> stopList() => stops.values.toList();

  /// Construit le feed depuis les textes des tables ({'routes': '...', ...}).
  factory GtfsFeed.fromTexts(
    Map<String, String> texts,
    FeedProvenance provenance, {
    String? network,
  }) {
    final GtfsFeed feed = GtfsFeed(provenance, network: network);
    final Map<String, CsvTable> parsed = <String, CsvTable>{};
    for (final MapEntry<String, String> e in texts.entries) {
      final String table = e.key.replaceAll(RegExp(r'\.txt$'), '');
      if (!engineTables.contains(table)) continue;
      final CsvTable t = parseCsv(e.value);
      parsed[table] = t;
      feed.tables.add(table);
      feed.headers[table] = t.header;
    }

    String? cell(List<String> row, int i) {
      if (i < 0 || i >= row.length) return null;
      final String v = row[i].trim();
      return v.isEmpty ? null : v;
    }

    final CsvTable? agency = parsed['agency'];
    if (agency != null) feed.agencies.addAll(rowsToObjects(agency));

    final CsvTable? routes = parsed['routes'];
    if (routes != null) {
      final int iId = routes.columnIndex('route_id');
      final int iShort = routes.columnIndex('route_short_name');
      final int iLong = routes.columnIndex('route_long_name');
      final int iType = routes.columnIndex('route_type');
      final int iAgency = routes.columnIndex('agency_id');
      for (final List<String> r in routes.rows) {
        final String? id = cell(r, iId);
        if (id == null) {
          feed.anomalies.add('ROUTE_WITHOUT_ID');
          continue;
        }
        if (feed.routes.containsKey(id)) feed.anomalies.add('DUPLICATE_ROUTE_ID: $id');
        feed.routes[id] = GtfsRoute(
          routeId: id,
          routeShortName: cell(r, iShort) ?? '',
          routeLongName: cell(r, iLong) ?? '',
          routeType: cell(r, iType) ?? '',
          agencyId: cell(r, iAgency),
        );
      }
    }

    final CsvTable? stops = parsed['stops'];
    if (stops != null) {
      final int iId = stops.columnIndex('stop_id');
      final int iName = stops.columnIndex('stop_name');
      final int iLat = stops.columnIndex('stop_lat');
      final int iLon = stops.columnIndex('stop_lon');
      final int iLoc = stops.columnIndex('location_type');
      final int iParent = stops.columnIndex('parent_station');
      for (final List<String> r in stops.rows) {
        final String? id = cell(r, iId);
        if (id == null) {
          feed.anomalies.add('STOP_WITHOUT_ID');
          continue;
        }
        feed.stops[id] = GtfsStop(
          stopId: id,
          stopName: cell(r, iName) ?? '',
          stopLat: double.tryParse(cell(r, iLat) ?? ''),
          stopLon: double.tryParse(cell(r, iLon) ?? ''),
          locationType: cell(r, iLoc),
          parentStation: cell(r, iParent),
        );
      }
    }

    final CsvTable? calendar = parsed['calendar'];
    if (calendar != null) {
      final int iId = calendar.columnIndex('service_id');
      final int iStart = calendar.columnIndex('start_date');
      final int iEnd = calendar.columnIndex('end_date');
      final Map<String, int> dayIdx = <String, int>{
        for (final String d in gtfsWeekdays) d: calendar.columnIndex(d),
      };
      for (final List<String> r in calendar.rows) {
        final String? id = cell(r, iId);
        if (id == null) continue;
        final GtfsService s = feed.services.putIfAbsent(id, () => GtfsService(id));
        s.hasCalendarRow = true;
        for (final String d in gtfsWeekdays) {
          s.weekdays[d] = cell(r, dayIdx[d]!) == '1';
        }
        try {
          s.startDate = normalizeServiceDate(cell(r, iStart) ?? '');
          s.endDate = normalizeServiceDate(cell(r, iEnd) ?? '');
          feed._widen(s.startDate!);
          feed._widen(s.endDate!);
        } on FormatException {
          feed.anomalies.add('CALENDAR_DATE_INVALID: $id');
        }
      }
    }

    final CsvTable? calendarDates = parsed['calendar_dates'];
    if (calendarDates != null) {
      final int iId = calendarDates.columnIndex('service_id');
      final int iDate = calendarDates.columnIndex('date');
      final int iType = calendarDates.columnIndex('exception_type');
      for (final List<String> r in calendarDates.rows) {
        final String? id = cell(r, iId);
        if (id == null) continue;
        final GtfsService s = feed.services.putIfAbsent(id, () => GtfsService(id));
        try {
          final String day = normalizeServiceDate(cell(r, iDate) ?? '');
          final String type = cell(r, iType) ?? '';
          if (type == '1') {
            s.addedDates.add(day);
            feed._widen(day);
          } else if (type == '2') {
            s.removedDates.add(day);
          } else {
            feed.anomalies.add('CALENDAR_DATES_EXCEPTION_TYPE_INVALID: $id');
          }
        } on FormatException {
          feed.anomalies.add('CALENDAR_DATES_DATE_INVALID: $id');
        }
      }
    }

    final CsvTable? trips = parsed['trips'];
    if (trips != null) {
      final int iTrip = trips.columnIndex('trip_id');
      final int iRoute = trips.columnIndex('route_id');
      final int iService = trips.columnIndex('service_id');
      final int iHead = trips.columnIndex('trip_headsign');
      final int iDir = trips.columnIndex('direction_id');
      final int iShape = trips.columnIndex('shape_id');
      for (final List<String> r in trips.rows) {
        final String? id = cell(r, iTrip);
        final String? routeId = cell(r, iRoute);
        final String? serviceId = cell(r, iService);
        if (id == null || routeId == null || serviceId == null) {
          feed.anomalies.add('TRIP_REFERENCE_MISSING');
          continue;
        }
        feed.trips[id] = GtfsTrip(
          tripId: id,
          routeId: routeId,
          serviceId: serviceId,
          tripHeadsign: cell(r, iHead),
          directionId: cell(r, iDir),
          shapeId: cell(r, iShape),
        );
        feed.tripsByRoute.putIfAbsent(routeId, () => <String>[]).add(id);
      }
    }

    final CsvTable? stopTimes = parsed['stop_times'];
    if (stopTimes != null) {
      final int iTrip = stopTimes.columnIndex('trip_id');
      final int iStop = stopTimes.columnIndex('stop_id');
      final int iSeq = stopTimes.columnIndex('stop_sequence');
      final int iArr = stopTimes.columnIndex('arrival_time');
      final int iDep = stopTimes.columnIndex('departure_time');
      final StopTimesColumns st = feed.stopTimes;
      for (final List<String> r in stopTimes.rows) {
        final String? tripId = cell(r, iTrip);
        final String? stopId = cell(r, iStop);
        if (tripId == null || stopId == null) {
          feed.anomalies.add('STOP_TIME_REFERENCE_MISSING');
          continue;
        }
        final String? rawArr = cell(r, iArr);
        final String? rawDep = cell(r, iDep);
        final int? arr = parseGtfsTime(rawArr);
        final int? dep = parseGtfsTime(rawDep);
        if ((arr == null && rawArr != null) || (dep == null && rawDep != null)) {
          st.invalidTimes++;
        }
        if (arr == null && dep == null) st.missingTimes++;
        final int i = st.count;
        st.tripIds.add(tripId);
        st.stopIds.add(stopId);
        st.sequences.add(int.tryParse(cell(r, iSeq) ?? '') ?? -1);
        st.arrivals.add(arr ?? -1);
        st.departures.add(dep ?? -1);
        feed.stopTimesByTrip.putIfAbsent(tripId, () => <int>[]).add(i);
        feed.stopTimesByStop.putIfAbsent(stopId, () => <int>[]).add(i);
      }
      for (final List<int> list in feed.stopTimesByTrip.values) {
        list.sort((int a, int b) => st.sequences[a].compareTo(st.sequences[b]));
      }
    }

    final CsvTable? shapes = parsed['shapes'];
    if (shapes != null) {
      final int iId = shapes.columnIndex('shape_id');
      for (final List<String> r in shapes.rows) {
        final String? id = cell(r, iId);
        if (id == null) continue;
        feed.shapeIds.add(id);
        feed.shapePoints++;
      }
    }

    final CsvTable? info = parsed['feed_info'];
    if (info != null) {
      final List<Map<String, String>> rows = rowsToObjects(info);
      feed.feedInfo = rows.isEmpty ? null : rows.first;
    }
    return feed;
  }

  void _widen(String day) {
    if (calendarStart == null || day.compareTo(calendarStart!) < 0) calendarStart = day;
    if (calendarEnd == null || day.compareTo(calendarEnd!) > 0) calendarEnd = day;
  }
}

/// Validation structurelle : tables et colonnes requises, références,
/// heures, calendrier. Les anomalies non bloquantes sont des avertissements.
FeedValidation validateFeed(GtfsFeed feed) {
  final List<String> errors = <String>[];
  final List<String> warnings = <String>[];
  for (final String f in requiredFiles) {
    if (!feed.tables.contains(f)) errors.add('FILE_MISSING: $f.txt');
  }
  if (!feed.tables.contains('calendar') && !feed.tables.contains('calendar_dates')) {
    errors.add('FILE_MISSING: calendar.txt ou calendar_dates.txt');
  }
  for (final MapEntry<String, List<String>> e in requiredColumns.entries) {
    final List<String>? header = feed.headers[e.key];
    if (header == null) continue;
    for (final String c in e.value) {
      if (!header.contains(c)) errors.add('COLUMN_MISSING: ${e.key}.$c');
    }
  }
  final List<String>? stHeader = feed.headers['stop_times'];
  if (stHeader != null &&
      !stHeader.contains('arrival_time') &&
      !stHeader.contains('departure_time')) {
    errors.add('COLUMN_MISSING: stop_times.arrival_time/departure_time');
  }
  int tripsUnknownRoute = 0;
  int tripsUnknownService = 0;
  for (final GtfsTrip t in feed.trips.values) {
    if (!feed.routes.containsKey(t.routeId)) tripsUnknownRoute++;
    if (!feed.services.containsKey(t.serviceId)) tripsUnknownService++;
  }
  final StopTimesColumns st = feed.stopTimes;
  int stUnknownTrip = 0;
  int stUnknownStop = 0;
  for (int i = 0; i < st.count; i++) {
    if (!feed.trips.containsKey(st.tripIds[i])) stUnknownTrip++;
    if (!feed.stops.containsKey(st.stopIds[i])) stUnknownStop++;
  }
  int tripsWithoutStopTimes = 0;
  int duplicateSequences = 0;
  int orderErrors = 0;
  for (final String tripId in feed.trips.keys) {
    final List<int>? idx = feed.stopTimesByTrip[tripId];
    if (idx == null || idx.isEmpty) {
      tripsWithoutStopTimes++;
      continue;
    }
    for (int k = 1; k < idx.length; k++) {
      if (st.sequences[idx[k]] == st.sequences[idx[k - 1]]) {
        duplicateSequences++;
        break;
      }
    }
    int last = -1;
    for (final int i in idx) {
      final int t = st.departures[i] >= 0 ? st.departures[i] : st.arrivals[i];
      if (t < 0) continue;
      if (t < last) {
        orderErrors++;
        break;
      }
      last = t;
    }
  }
  if (tripsUnknownRoute > 0) errors.add('ORPHAN_REFERENCE: $tripsUnknownRoute trip(s) → route_id inconnu');
  if (tripsUnknownService > 0) errors.add('ORPHAN_REFERENCE: $tripsUnknownService trip(s) → service_id inconnu');
  if (stUnknownTrip > 0) errors.add('ORPHAN_REFERENCE: $stUnknownTrip stop_time(s) → trip_id inconnu');
  if (stUnknownStop > 0) errors.add('ORPHAN_REFERENCE: $stUnknownStop stop_time(s) → stop_id inconnu');
  if (tripsWithoutStopTimes > 0) warnings.add('TRIPS_WITHOUT_STOP_TIMES: $tripsWithoutStopTimes');
  if (duplicateSequences > 0) warnings.add('DUPLICATE_STOP_SEQUENCE: $duplicateSequences trip(s)');
  if (orderErrors > 0) warnings.add('TIME_ORDER: $orderErrors trip(s) avec des heures non croissantes le long de la course');
  final int timesPresent = st.count - st.missingTimes;
  if (st.count > 0 && timesPresent == 0) errors.add('NO_TIMES: aucune heure dans stop_times.txt');
  if (st.invalidTimes > 0) {
    errors.add('INVALID_TIME: ${st.invalidTimes} stop_time(s) avec une heure non conforme (HH:MM:SS attendu)');
  }
  if (feed.routes.isEmpty) errors.add('EMPTY: routes.txt vide');
  if (feed.stops.isEmpty) errors.add('EMPTY: stops.txt vide');
  if (feed.trips.isEmpty) errors.add('EMPTY: trips.txt vide');
  if (st.count == 0) errors.add('EMPTY: stop_times.txt vide');
  if (feed.services.isEmpty) errors.add('EMPTY: aucun service (calendar / calendar_dates)');
  final int routesWithoutShortName =
      feed.routes.values.where((GtfsRoute r) => r.routeShortName.isEmpty).length;
  if (routesWithoutShortName > 0) {
    warnings.add('ROUTE_SHORT_NAME_MISSING: $routesWithoutShortName route(s)');
  }
  final Set<String> directions = <String>{};
  for (final GtfsTrip t in feed.trips.values) {
    directions.add(t.directionId ?? '');
  }
  for (final String d in directions) {
    if (d != '' && d != '0' && d != '1') warnings.add('DIRECTION_ID_INVALID: $d');
  }
  warnings.addAll(feed.anomalies);
  return FeedValidation(
    ok: errors.isEmpty,
    errors: errors,
    warnings: warnings,
    counts: feed.counts,
  );
}
