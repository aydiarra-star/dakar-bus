// TransitDataProvider — miroir Dart de lib/external-gtfs/transit-data-provider.js.
// Couche unique de résolution des horaires. Ordre de priorité :
//   1. CETUD CURRENT (currentOfficial, autorité CETUD)
//   2. autre source officielle actuelle
//   3. PassBi CURRENT si réellement prouvé (currentApplication)
//   4. open data actuelle
//   5. estimation par fréquence documentée (ESTIMATED)
//   6. UNKNOWN
// Les sources HISTORICAL ne participent JAMAIS à une réponse « maintenant ».

import 'feed_provenance.dart';
import 'gtfs_feed.dart';
import 'gtfs_schedule_service.dart';
import 'gtfs_time.dart';

class ProviderRoles {
  static const String currentOfficial = 'currentOfficial';
  static const String currentApplication = 'currentApplication';
  static const String currentOpenData = 'currentOpenData';
  static const String currentFrequency = 'currentFrequency';
  static const String historicalReference = 'historicalReference';
  static const List<String> all = <String>[
    currentOfficial,
    currentApplication,
    currentOpenData,
    currentFrequency,
    historicalReference,
  ];
  static const List<String> current = <String>[
    currentOfficial,
    currentApplication,
    currentOpenData,
    currentFrequency,
  ];
  static const Map<String, String> requiredSourceType = <String, String>{
    currentOfficial: SourceTypes.institutional,
    currentApplication: SourceTypes.application,
    currentOpenData: SourceTypes.openData,
  };
  static const Map<String, String> level = <String, String>{
    currentOfficial: ProvenanceLevels.officialStaticCurrent,
    currentApplication: ProvenanceLevels.sourceApplicationCurrent,
    currentOpenData: ProvenanceLevels.openDataCurrent,
    currentFrequency: ProvenanceLevels.estimated,
    historicalReference: ProvenanceLevels.historicalReference,
  };
}

/// Normalisation de comparaison (accents, casse, ponctuation).
String normalizeText(String? s) {
  if (s == null) return '';
  const String from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
  const String to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    final int k = from.indexOf(c);
    b.write(k >= 0 ? to[k] : c);
  }
  return b
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim();
}

class RegisteredSource {
  const RegisteredSource({
    required this.service,
    required this.role,
    required this.rank,
    required this.level,
    required this.network,
  });

  final ScheduleSource service;
  final String role;
  final int rank;
  final String level;
  final String? network;

  FeedProvenance get provenance => service.provenance;
}

class ResolvedSource {
  const ResolvedSource(this.source, this.validityStatus);

  final RegisteredSource source;
  final String validityStatus;

  bool get usable => validityStatus == Validity.current;
}

class ProviderReference {
  const ProviderReference(this.serviceDate, this.time);

  final String serviceDate;
  final String time;

  String get isoDate => toIsoDate(serviceDate);
}

class RouteMatch {
  const RouteMatch(this.route, this.source);

  final GtfsRoute route;
  final RegisteredSource source;
}

class StopMatches {
  const StopMatches(this.exact, this.partial);

  final List<GtfsStop> exact;
  final List<GtfsStop> partial;
}

class TransitDataProvider {
  TransitDataProvider({DateTime Function()? now})
      : now = now ?? DateTime.now;

  final DateTime Function() now;
  final List<RegisteredSource> sources = <RegisteredSource>[];

  /// Enregistre une source avec un rôle. Règles strictes :
  ///  - un feed déclaré HISTORICAL ne peut recevoir qu'un rôle historicalReference ;
  ///  - un rôle « current » exige un statut déclaré CURRENT ;
  ///  - currentOfficial exige une source institutionnelle (CETUD / autorité).
  RegisteredSource registerSource(ScheduleSource service, {required String role}) {
    if (!ProviderRoles.all.contains(role)) {
      throw ArgumentError('TransitDataProvider : rôle inconnu « $role »');
    }
    final FeedProvenance prov = service.provenance;
    final String label =
        '${prov.source}${prov.network == null ? '' : ' (${prov.network})'}';
    if (role != ProviderRoles.historicalReference) {
      if (prov.declaredStatus == Validity.historical) {
        throw StateError(
            'TransitDataProvider : $label est déclarée HISTORICAL et ne peut pas être enregistrée comme $role');
      }
      if (prov.declaredStatus != Validity.current) {
        throw StateError(
            'TransitDataProvider : $label n\'a pas de statut CURRENT prouvé (statut ${prov.declaredStatus}) — rôle $role refusé');
      }
      final String? requiredType = ProviderRoles.requiredSourceType[role];
      if (requiredType != null && prov.sourceType != requiredType) {
        throw StateError(
            'TransitDataProvider : $label (${prov.sourceTypeLabel}) ne peut pas tenir le rôle $role ($requiredType requis)');
      }
      if (role == ProviderRoles.currentFrequency && service.kind != 'frequency') {
        throw StateError(
            'TransitDataProvider : le rôle currentFrequency est réservé aux sources de fréquence');
      }
      if (role != ProviderRoles.currentFrequency && service.kind == 'frequency') {
        throw StateError(
            'TransitDataProvider : une source de fréquence ne peut pas tenir le rôle $role');
      }
    }
    final RegisteredSource entry = RegisteredSource(
      service: service,
      role: role,
      rank: _rankFor(role, prov),
      level: ProviderRoles.level[role]!,
      network: service.network ?? prov.network,
    );
    sources.add(entry);
    sources.sort((RegisteredSource a, RegisteredSource b) => a.rank.compareTo(b.rank));
    return entry;
  }

  int _rankFor(String role, FeedProvenance prov) {
    switch (role) {
      case ProviderRoles.currentOfficial:
        return normalizeText(prov.authority ?? prov.source) == 'CETUD' ? 0 : 1;
      case ProviderRoles.currentApplication:
        return 2;
      case ProviderRoles.currentOpenData:
        return 3;
      case ProviderRoles.currentFrequency:
        return 4;
      default:
        return 9;
    }
  }

  /// Date/heure de référence (horloge Dakar, UTC+0).
  ProviderReference reference({String? date, String? time}) {
    final DakarClock clock = dakarClock(now());
    final String serviceDate =
        date == null ? clock.serviceDate : normalizeServiceDate(date);
    final String t = time ?? clock.time;
    final int? seconds = parseGtfsTime(t);
    if (seconds == null) {
      throw FormatException('TransitDataProvider : heure invalide « $t »');
    }
    return ProviderReference(serviceDate, formatGtfsTime(seconds));
  }

  /// Sources « current » avec leur validité à une date.
  List<ResolvedSource> resolveCurrentSources(String asOf) {
    final String day = normalizeServiceDate(asOf);
    return sources
        .where((RegisteredSource s) => ProviderRoles.current.contains(s.role))
        .map((RegisteredSource s) =>
            ResolvedSource(s, s.provenance.validityStatusOn(day)))
        .toList();
  }

  List<RegisteredSource> historicalSources() => sources
      .where((RegisteredSource s) => s.role == ProviderRoles.historicalReference)
      .toList();

  /// Source gagnante pour un réseau à une date (null → UNKNOWN).
  RegisteredSource? winningSource(String? network, String asOf) {
    final String? net = network?.toUpperCase();
    for (final ResolvedSource r in resolveCurrentSources(asOf)) {
      if (!r.usable || r.source.service.kind == 'frequency') continue;
      final String? sn = r.source.network?.toUpperCase();
      if (net == null || sn == null || sn == net) return r.source;
    }
    return null;
  }

  DepartureResult _unknown(
    String routeId,
    String? stopId,
    ProviderReference ref,
    String reason,
  ) =>
      DepartureResult(
        routeId: routeId,
        stopId: stopId,
        date: ref.isoDate,
        currentTime: ref.time,
        status: ScheduleStatus.unknown,
        reason: reason,
        source: null,
        sourceType: null,
        feedVersion: null,
        validity: null,
        provenanceLevel: ProvenanceLevels.unknown,
        departures: const <Departure>[],
        historicalReferenceAvailable:
            historicalSources().any((RegisteredSource s) => s.service.knowsRoute(routeId)),
      );

  DepartureResult _decorate(DepartureResult r, RegisteredSource s) {
    final bool current =
        r.status == ScheduleStatus.scheduled || r.status == ScheduleStatus.estimated;
    return r.copyWith(
      isCurrent: current,
      provenanceLevel: r.status == ScheduleStatus.unknown ? ProvenanceLevels.unknown : s.level,
      role: s.role,
      network: s.network,
      departures: r.departures.map((Departure d) => d.withLevel(s.level)).toList(),
    );
  }

  /// Prochains départs « actuels » : uniquement sources current utilisables.
  DepartureResult getDepartures(
    String routeId,
    String? stopId, {
    String? date,
    String? time,
    int? limit = 5,
  }) {
    final ProviderReference ref = reference(date: date, time: time);
    DepartureResult? fallback;
    for (final ResolvedSource r in resolveCurrentSources(ref.serviceDate)) {
      if (!r.usable || !r.source.service.knowsRoute(routeId)) continue;
      final DepartureResult res = r.source.service.getDeparturesAtStop(
        routeId,
        stopId,
        ref.serviceDate,
        ref.time,
        limit: limit,
        asOf: ref.serviceDate,
      );
      if (res.status == ScheduleStatus.scheduled || res.status == ScheduleStatus.estimated) {
        return _decorate(res, r.source);
      }
      fallback ??= _decorate(res, r.source);
    }
    return fallback ?? _unknown(routeId, stopId, ref, ScheduleReasons.noCurrentSource);
  }

  DepartureResult getDeparturesNow(String routeId, String? stopId, {int? limit = 5}) =>
      getDepartures(routeId, stopId, limit: limit);

  /// Consultation explicite de la référence historique (jamais « actuel »).
  DepartureResult getHistoricalDepartures(
    String routeId,
    String? stopId, {
    String? date,
    String? time,
    int? limit = 5,
  }) {
    final ProviderReference ref = reference(date: date, time: time);
    for (final RegisteredSource s in historicalSources()) {
      if (!s.service.knowsRoute(routeId)) continue;
      final DepartureResult res = s.service.getDeparturesAtStop(
        routeId,
        stopId,
        ref.serviceDate,
        ref.time,
        limit: limit,
        asOf: ref.serviceDate,
      );
      return res.copyWith(
        isCurrent: false,
        provenanceLevel: ProvenanceLevels.historicalReference,
        role: ProviderRoles.historicalReference,
      );
    }
    return _unknown(routeId, stopId, ref, ScheduleReasons.routeUnknown);
  }

  /// Lignes dont route_short_name (champ officiel) vaut exactement le numéro.
  List<RouteMatch> routesForLine(
    String? network,
    String lineNumber, {
    String? asOf,
    bool includeHistorical = false,
  }) {
    final String wanted = normalizeText(lineNumber);
    if (wanted.isEmpty) return <RouteMatch>[];
    final String? net = network?.toUpperCase();
    final String day = asOf == null
        ? dakarClock(now()).serviceDate
        : normalizeServiceDate(asOf);
    final List<RegisteredSource> pool = includeHistorical
        ? historicalSources()
        : resolveCurrentSources(day)
            .where((ResolvedSource r) => r.usable)
            .map((ResolvedSource r) => r.source)
            .toList();
    final List<RouteMatch> out = <RouteMatch>[];
    for (final RegisteredSource s in pool) {
      if (s.service.kind == 'frequency') continue;
      final String? sn = s.network?.toUpperCase();
      if (net != null && sn != null && sn != net) continue;
      for (final GtfsRoute r in s.service.routes()) {
        if (normalizeText(r.routeShortName) == wanted) out.add(RouteMatch(r, s));
      }
    }
    return out;
  }

  /// Arrêts dont le nom correspond (exact normalisé, sinon inclusion).
  static StopMatches matchStops(List<GtfsStop> stops, String name) {
    final String wanted = normalizeText(name);
    if (wanted.isEmpty) return const StopMatches(<GtfsStop>[], <GtfsStop>[]);
    final List<GtfsStop> exact =
        stops.where((GtfsStop s) => normalizeText(s.stopName) == wanted).toList();
    if (exact.isNotEmpty) return StopMatches(exact, <GtfsStop>[]);
    final List<GtfsStop> partial =
        stops.where((GtfsStop s) => normalizeText(s.stopName).contains(wanted)).toList();
    return StopMatches(<GtfsStop>[], partial);
  }
}
