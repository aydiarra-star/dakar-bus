// Source « fréquence documentée » — miroir Dart de lib/external-gtfs/frequency-source.js.
// Produit un statut ESTIMATED (intervalle publié par une source identifiée),
// JAMAIS une heure de passage. Aucune fréquence n'est embarquée par défaut.

import 'feed_provenance.dart';
import 'gtfs_feed.dart';
import 'gtfs_schedule_service.dart';
import 'gtfs_time.dart';

class FrequencyEntry {
  FrequencyEntry({
    required String network,
    required String lineNumber,
    required this.headwayMinutes,
    List<String>? routeIds,
    List<String>? days,
    String? from,
    String? to,
    this.label,
  })  : network = network.toUpperCase(),
        lineNumber = lineNumber.trim().toUpperCase(),
        routeIds = routeIds ?? <String>[],
        days = days == null || days.isEmpty
            ? null
            : days.map((String d) => d.toLowerCase()).toList(),
        fromSeconds = from == null ? null : parseGtfsTime(from),
        toSeconds = to == null ? null : parseGtfsTime(to) {
    if (headwayMinutes <= 0) {
      throw ArgumentError('FrequencyEntry : headwayMinutes invalide ($lineNumber)');
    }
  }

  final String network;
  final String lineNumber;
  final int headwayMinutes;
  final List<String> routeIds;
  final List<String>? days;
  final int? fromSeconds;
  final int? toSeconds;
  final String? label;

  String get pseudoRouteId => 'FREQ:$network:$lineNumber';
}

class FrequencySource implements ScheduleSource {
  FrequencySource(this.entries, this.provenance);

  final List<FrequencyEntry> entries;

  @override
  final FeedProvenance provenance;

  @override
  String? get network => entries.isEmpty ? provenance.network : entries.first.network;

  @override
  String get kind => 'frequency';

  @override
  List<GtfsRoute> routes() => entries
      .map((FrequencyEntry e) => GtfsRoute(
            routeId: e.pseudoRouteId,
            routeShortName: e.lineNumber,
            routeLongName: e.label ?? '',
            routeType: '',
            agencyId: null,
          ))
      .toList();

  @override
  List<GtfsStop> stops() => <GtfsStop>[];

  @override
  List<RouteDirectionStops> getStopsForRoute(String routeId) => <RouteDirectionStops>[];

  @override
  bool knowsRoute(String routeId) => _entryByRoute(routeId) != null;

  FrequencyEntry? _entryByRoute(String routeId) {
    for (final FrequencyEntry e in entries) {
      if (e.routeIds.contains(routeId) || e.pseudoRouteId == routeId) return e;
    }
    return null;
  }

  /// Entrée applicable à une ligne, une date et une heure.
  FrequencyEntry? entryFor(String? network, String lineNumber, String date, String time) {
    final String? net = network?.toUpperCase();
    final String line = lineNumber.trim().toUpperCase();
    final String day = normalizeServiceDate(date);
    final String weekday = weekdayOf(day);
    final int? seconds = parseGtfsTime(time);
    for (final FrequencyEntry e in entries) {
      if (net != null && e.network != net) continue;
      if (e.lineNumber != line) continue;
      if (e.days != null && !e.days!.contains(weekday)) continue;
      if (seconds != null && e.fromSeconds != null && seconds < e.fromSeconds!) continue;
      if (seconds != null && e.toSeconds != null && seconds > e.toSeconds!) continue;
      return e;
    }
    return null;
  }

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
    final FrequencyEntry? entry = _entryByRoute(routeId);
    final FrequencyEntry? applicable =
        entry == null ? null : entryFor(entry.network, entry.lineNumber, serviceDate, time);
    final String level = provenance.isCurrentOn(ref)
        ? ProvenanceLevels.estimated
        : ProvenanceLevels.historicalReference;
    String status = ScheduleStatus.unknown;
    String? reason;
    if (nowSeconds == null) {
      reason = ScheduleReasons.invalidTime;
    } else if (entry == null) {
      reason = ScheduleReasons.routeUnknown;
    } else if (applicable == null) {
      reason = ScheduleReasons.noServiceOnDate;
    } else {
      status = ScheduleStatus.estimated;
    }
    return DepartureResult(
      routeId: routeId,
      stopId: stopId,
      date: toIsoDate(serviceDate),
      currentTime: nowSeconds == null ? null : formatGtfsTime(nowSeconds),
      status: status,
      reason: reason,
      source: provenance.source,
      sourceType: provenance.sourceTypeLabel,
      feedVersion: provenance.feedVersion,
      validity: provenance.validityOn(ref, serviceDate),
      provenanceLevel: level,
      departures: const <Departure>[],
      network: network,
      estimate: status == ScheduleStatus.estimated && applicable != null
          ? FrequencyEstimate(
              network: applicable.network,
              lineNumber: applicable.lineNumber,
              headwayMinutes: applicable.headwayMinutes,
              source: provenance.source,
              windowFrom: applicable.fromSeconds == null
                  ? null
                  : formatGtfsTime(applicable.fromSeconds!),
              windowTo: applicable.toSeconds == null
                  ? null
                  : formatGtfsTime(applicable.toSeconds!),
              url: provenance.url,
              publishedAt: provenance.publishedAt,
            )
          : null,
    );
  }
}
