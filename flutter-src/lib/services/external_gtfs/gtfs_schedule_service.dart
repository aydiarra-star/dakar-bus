// Moteur horaire — miroir Dart de lib/external-gtfs/gtfs-schedule-service.js.
// Les heures proviennent EXCLUSIVEMENT de stop_times ; une course n'est
// retenue que si son service est actif le jour interrogé. Jamais
// d'interpolation, jamais de fréquence convertie en heure.

import 'feed_provenance.dart';
import 'gtfs_feed.dart';
import 'gtfs_time.dart';

class ScheduleStatus {
  static const String scheduled = 'SCHEDULED';
  static const String estimated = 'ESTIMATED';
  static const String unknown = 'UNKNOWN';
}

class ScheduleReasons {
  static const String invalidTime = 'INVALID_TIME';
  static const String routeUnknown = 'ROUTE_UNKNOWN';
  static const String stopUnknown = 'STOP_UNKNOWN';
  static const String stopNotOnRoute = 'STOP_NOT_ON_ROUTE';
  static const String noServiceOnDate = 'NO_SERVICE_ON_DATE';
  static const String noMoreDepartures = 'NO_MORE_DEPARTURES';
  static const String noCurrentSource = 'NO_CURRENT_SOURCE';
}

/// Niveau de provenance intrinsèque d'un feed à une date (hors rôle).
String provenanceLevelForFeed(FeedProvenance p, String asOf) {
  if (p.validityStatusOn(asOf) != Validity.current) {
    return ProvenanceLevels.historicalReference;
  }
  if (p.sourceType == SourceTypes.institutional) {
    return ProvenanceLevels.officialStaticCurrent;
  }
  if (p.sourceType == SourceTypes.application) {
    return ProvenanceLevels.sourceApplicationCurrent;
  }
  if (p.sourceType == SourceTypes.openData) return ProvenanceLevels.openDataCurrent;
  return ProvenanceLevels.unknown;
}

class TripDirection {
  const TripDirection({
    this.directionId,
    this.tripHeadsign,
    this.originStopId,
    this.originStopName,
    this.terminusStopId,
    this.terminusStopName,
  });

  final String? directionId;
  final String? tripHeadsign;
  final String? originStopId;
  final String? originStopName;
  final String? terminusStopId;
  final String? terminusStopName;
}

class Departure {
  const Departure({
    required this.tripId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.stopId,
    required this.stopName,
    required this.stopSequence,
    required this.direction,
    required this.arrivalTime,
    required this.departureTime,
    required this.arrivalSeconds,
    required this.departureSeconds,
    required this.serviceId,
    required this.serviceDate,
    required this.source,
    required this.sourceType,
    required this.feedVersion,
    required this.validity,
    required this.provenanceLevel,
  });

  final String tripId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final String stopId;
  final String stopName;
  final int stopSequence;
  final TripDirection direction;
  final String? arrivalTime;
  final String? departureTime;
  final int? arrivalSeconds;
  final int departureSeconds;
  final String serviceId;

  /// 'YYYY-MM-DD' du jour de service (peut être la veille pour les heures ≥ 24:00).
  final String serviceDate;
  final String source;
  final String sourceType;
  final String feedVersion;
  final FeedValidity validity;
  final String provenanceLevel;
  final String status = ScheduleStatus.scheduled;

  Departure withLevel(String level) => Departure(
        tripId: tripId,
        routeId: routeId,
        routeShortName: routeShortName,
        routeLongName: routeLongName,
        stopId: stopId,
        stopName: stopName,
        stopSequence: stopSequence,
        direction: direction,
        arrivalTime: arrivalTime,
        departureTime: departureTime,
        arrivalSeconds: arrivalSeconds,
        departureSeconds: departureSeconds,
        serviceId: serviceId,
        serviceDate: serviceDate,
        source: source,
        sourceType: sourceType,
        feedVersion: feedVersion,
        validity: validity,
        provenanceLevel: level,
      );
}

/// Estimation par fréquence documentée (jamais une heure).
class FrequencyEstimate {
  const FrequencyEstimate({
    required this.network,
    required this.lineNumber,
    required this.headwayMinutes,
    required this.source,
    this.windowFrom,
    this.windowTo,
    this.url,
    this.publishedAt,
  });

  final String network;
  final String lineNumber;
  final int headwayMinutes;
  final String source;
  final String? windowFrom;
  final String? windowTo;
  final String? url;
  final String? publishedAt;
  final bool stopVerified = false;
}

class DepartureResult {
  const DepartureResult({
    required this.routeId,
    required this.stopId,
    required this.date,
    required this.currentTime,
    required this.status,
    required this.reason,
    required this.source,
    required this.sourceType,
    required this.feedVersion,
    required this.validity,
    required this.provenanceLevel,
    required this.departures,
    this.isCurrent = false,
    this.role,
    this.network,
    this.estimate,
    this.historicalReferenceAvailable = false,
  });

  final String routeId;
  final String? stopId;
  final String date;
  final String? currentTime;
  final String status;
  final String? reason;
  final String? source;
  final String? sourceType;
  final String? feedVersion;
  final FeedValidity? validity;
  final String provenanceLevel;
  final List<Departure> departures;
  final bool isCurrent;
  final String? role;
  final String? network;
  final FrequencyEstimate? estimate;
  final bool historicalReferenceAvailable;

  DepartureResult copyWith({
    String? provenanceLevel,
    List<Departure>? departures,
    bool? isCurrent,
    String? role,
    String? network,
    bool? historicalReferenceAvailable,
  }) =>
      DepartureResult(
        routeId: routeId,
        stopId: stopId,
        date: date,
        currentTime: currentTime,
        status: status,
        reason: reason,
        source: source,
        sourceType: sourceType,
        feedVersion: feedVersion,
        validity: validity,
        provenanceLevel: provenanceLevel ?? this.provenanceLevel,
        departures: departures ?? this.departures,
        isCurrent: isCurrent ?? this.isCurrent,
        role: role ?? this.role,
        network: network ?? this.network,
        estimate: estimate,
        historicalReferenceAvailable:
            historicalReferenceAvailable ?? this.historicalReferenceAvailable,
      );
}

class RouteDirectionStops {
  const RouteDirectionStops(this.directionId, this.tripId, this.stops);

  final String? directionId;
  final String tripId;
  final List<GtfsStop> stops;
}

/// Interface commune des sources horaires (GTFS statique, fréquence).
abstract class ScheduleSource {
  FeedProvenance get provenance;
  String? get network;

  /// 'gtfs' | 'frequency'.
  String get kind;

  bool knowsRoute(String routeId);
  List<GtfsRoute> routes();
  List<GtfsStop> stops();
  List<RouteDirectionStops> getStopsForRoute(String routeId);
  DepartureResult getDeparturesAtStop(
    String routeId,
    String? stopId,
    String date,
    String time, {
    int? limit = 5,
    String? asOf,
  });
}

class GtfsScheduleService implements ScheduleSource {
  GtfsScheduleService(this.feed);

  final GtfsFeed feed;

  @override
  FeedProvenance get provenance => feed.provenance;

  @override
  String? get network => feed.network;

  @override
  String get kind => 'gtfs';

  @override
  bool knowsRoute(String routeId) => feed.routes.containsKey(routeId);

  @override
  List<GtfsRoute> routes() => feed.routeList();

  @override
  List<GtfsStop> stops() => feed.stopList();

  GtfsRoute? getRoute(String routeId) => feed.routes[routeId];
  GtfsStop? getStop(String stopId) => feed.stops[stopId];

  /// Origine / terminus d'une course d'après ses stop_times (ordre stop_sequence).
  TripDirection tripDirection(String tripId) {
    final GtfsTrip? trip = feed.trips[tripId];
    final List<int> idx = feed.stopTimesByTrip[tripId] ?? <int>[];
    final String? first = idx.isEmpty ? null : feed.stopTimes.stopIds[idx.first];
    final String? last = idx.isEmpty ? null : feed.stopTimes.stopIds[idx.last];
    return TripDirection(
      directionId: trip?.directionId,
      tripHeadsign: trip?.tripHeadsign,
      originStopId: first,
      originStopName: first == null ? null : feed.stops[first]?.stopName,
      terminusStopId: last,
      terminusStopName: last == null ? null : feed.stops[last]?.stopName,
    );
  }

  /// Arrêts desservis par une ligne, par direction (course la plus longue).
  @override
  List<RouteDirectionStops> getStopsForRoute(String routeId) {
    final Map<String, List<int>> longest = <String, List<int>>{};
    final Map<String, String> longestTrip = <String, String>{};
    for (final String tripId in feed.tripsByRoute[routeId] ?? <String>[]) {
      final GtfsTrip? trip = feed.trips[tripId];
      final String key = trip?.directionId ?? '';
      final List<int> idx = feed.stopTimesByTrip[tripId] ?? <int>[];
      final List<int>? current = longest[key];
      if (current == null || idx.length > current.length) {
        longest[key] = idx;
        longestTrip[key] = tripId;
      }
    }
    final List<RouteDirectionStops> out = <RouteDirectionStops>[];
    for (final MapEntry<String, List<int>> e in longest.entries) {
      final List<GtfsStop> stops = <GtfsStop>[];
      for (final int i in e.value) {
        final GtfsStop? s = feed.stops[feed.stopTimes.stopIds[i]];
        if (s != null) stops.add(s);
      }
      out.add(RouteDirectionStops(
        e.key.isEmpty ? null : e.key,
        longestTrip[e.key]!,
        stops,
      ));
    }
    return out;
  }

  DepartureResult _empty(
    String routeId,
    String? stopId,
    String serviceDate,
    int? nowSeconds,
    FeedValidity validity,
    String level,
    String reason,
  ) =>
      DepartureResult(
        routeId: routeId,
        stopId: stopId,
        date: toIsoDate(serviceDate),
        currentTime: nowSeconds == null ? null : formatGtfsTime(nowSeconds),
        status: ScheduleStatus.unknown,
        reason: reason,
        source: provenance.source,
        sourceType: provenance.sourceTypeLabel,
        feedVersion: provenance.feedVersion,
        validity: validity,
        provenanceLevel: level,
        departures: const <Departure>[],
        network: network,
      );

  /// Prochains départs d'une ligne à un arrêt, à une date ('YYYY-MM-DD' ou
  /// 'YYYYMMDD') et une heure ('HH:MM[:SS]').
  @override
  DepartureResult getDeparturesAtStop(
    String routeId,
    String? stopId,
    String date,
    String time, {
    int? limit = 5,
    String? asOf,
  }) {
    final String serviceDate = normalizeServiceDate(date);
    final String ref = asOf == null ? serviceDate : normalizeServiceDate(asOf);
    final int? nowSeconds = parseGtfsTime(time);
    final FeedValidity validity = provenance.validityOn(ref, serviceDate);
    final String level = provenanceLevelForFeed(provenance, ref);
    if (nowSeconds == null) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.invalidTime);
    }
    final GtfsRoute? route = feed.routes[routeId];
    if (route == null) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.routeUnknown);
    }
    final GtfsStop? stop = stopId == null ? null : feed.stops[stopId];
    if (stop == null) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.stopUnknown);
    }
    final StopTimesColumns st = feed.stopTimes;
    final String previousDate = addDays(serviceDate, -1);
    final Map<String, bool> activeCache = <String, bool>{};
    bool active(String serviceId, String day) => activeCache.putIfAbsent(
        '$serviceId|$day', () => feed.isServiceActive(serviceId, day));

    final List<_Candidate> candidates = <_Candidate>[];
    bool onRoute = false;
    bool anyServiceActive = false;
    for (final int i in feed.stopTimesByStop[stopId] ?? <int>[]) {
      final GtfsTrip? trip = feed.trips[st.tripIds[i]];
      if (trip == null || trip.routeId != routeId) continue;
      onRoute = true;
      // Terminus d'une course : arrivée, pas un départ (aucune montée possible).
      final List<int>? tripIdx = feed.stopTimesByTrip[trip.tripId];
      if (tripIdx != null && tripIdx.length > 1 && tripIdx.last == i) continue;
      final int dep = st.departures[i] >= 0
          ? st.departures[i]
          : (st.arrivals[i] >= 0 ? st.arrivals[i] : -1);
      if (dep < 0) continue;
      if (active(trip.serviceId, serviceDate)) {
        anyServiceActive = true;
        if (dep >= nowSeconds) candidates.add(_Candidate(i, trip, dep, serviceDate));
      }
      // Courses de la veille dépassant minuit (heures GTFS ≥ 24:00:00).
      if (dep >= 86400 && active(trip.serviceId, previousDate)) {
        anyServiceActive = true;
        if (dep - 86400 >= nowSeconds) {
          candidates.add(_Candidate(i, trip, dep - 86400, previousDate));
        }
      }
    }
    if (!onRoute) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.stopNotOnRoute);
    }
    if (!anyServiceActive) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.noServiceOnDate);
    }
    if (candidates.isEmpty) {
      return _empty(routeId, stopId, serviceDate, nowSeconds, validity, level,
          ScheduleReasons.noMoreDepartures);
    }
    candidates.sort((_Candidate a, _Candidate b) {
      final int c = a.effective.compareTo(b.effective);
      return c != 0 ? c : a.trip.tripId.compareTo(b.trip.tripId);
    });
    final List<_Candidate> kept = limit == null
        ? candidates
        : candidates.take(limit < 0 ? 0 : limit).toList();
    final List<Departure> departures = kept.map((_Candidate c) {
      final int i = c.index;
      return Departure(
        tripId: c.trip.tripId,
        routeId: routeId,
        routeShortName: route.routeShortName,
        routeLongName: route.routeLongName,
        stopId: stop.stopId,
        stopName: stop.stopName,
        stopSequence: st.sequences[i],
        direction: tripDirection(c.trip.tripId),
        arrivalTime: st.arrivals[i] >= 0 ? formatGtfsTime(st.arrivals[i]) : null,
        departureTime: st.departures[i] >= 0 ? formatGtfsTime(st.departures[i]) : null,
        arrivalSeconds: st.arrivals[i] >= 0 ? st.arrivals[i] : null,
        departureSeconds: st.departures[i] >= 0 ? st.departures[i] : st.arrivals[i],
        serviceId: c.trip.serviceId,
        serviceDate: toIsoDate(c.serviceDate),
        source: provenance.source,
        sourceType: provenance.sourceTypeLabel,
        feedVersion: provenance.feedVersion,
        validity: validity,
        provenanceLevel: level,
      );
    }).toList();
    return DepartureResult(
      routeId: routeId,
      stopId: stopId,
      date: toIsoDate(serviceDate),
      currentTime: formatGtfsTime(nowSeconds),
      status: ScheduleStatus.scheduled,
      reason: null,
      source: provenance.source,
      sourceType: provenance.sourceTypeLabel,
      feedVersion: provenance.feedVersion,
      validity: validity,
      provenanceLevel: level,
      departures: departures,
      network: network,
    );
  }
}

class _Candidate {
  const _Candidate(this.index, this.trip, this.effective, this.serviceDate);

  final int index;
  final GtfsTrip trip;
  final int effective;
  final String serviceDate;
}
