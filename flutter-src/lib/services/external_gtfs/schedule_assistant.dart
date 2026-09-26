// Assistant horaire — miroir Dart de lib/external-gtfs/schedule-assistant.js.
// Question (FR) → ScheduleQuestion → TransitDataProvider → source CURRENT →
// stop_times → phrase. L'assistant n'a AUCUNE donnée propre.

import 'feed_provenance.dart';
import 'frequency_source.dart';
import 'gtfs_feed.dart';
import 'gtfs_schedule_service.dart';
import 'gtfs_time.dart';
import 'transit_data_provider.dart';

class ScheduleSentences {
  /// LOT 18 BIS — aucune donnée fiable.
  static const String noReliableData =
      "Je n'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis.";

  /// LOT 18 — ligne connue (référence historique) mais aucune source actuelle.
  static const String knownLineNoSchedule =
      "Je connais la ligne, mais je n'ai pas actuellement d'horaire suffisamment fiable pour annoncer un départ précis.";
}

class ScheduleQuestion {
  const ScheduleQuestion({
    required this.raw,
    required this.isScheduleQuestion,
    this.network,
    this.lineNumber,
    this.stopName,
    this.directionHint,
    this.date,
    this.time,
  });

  final String raw;
  final bool isScheduleQuestion;
  final String? network;
  final String? lineNumber;
  final String? stopName;
  final String? directionHint;

  /// 'YYYY-MM-DD' si explicite dans la question.
  final String? date;

  /// 'HH:MM' si explicite dans la question.
  final String? time;
}

class ScheduleAnswer {
  const ScheduleAnswer({
    required this.handled,
    required this.status,
    required this.sentence,
    required this.question,
    this.reason,
    this.network,
    this.provenanceLevel,
    this.source,
    this.departure,
    this.departures = const <Departure>[],
    this.estimate,
    this.lineKnownHistorically = false,
  });

  final bool handled;
  final String status;
  final String? sentence;
  final ScheduleQuestion question;
  final String? reason;
  final String? network;
  final String? provenanceLevel;
  final String? source;
  final Departure? departure;
  final List<Departure> departures;
  final FrequencyEstimate? estimate;
  final bool lineKnownHistorically;
}

final List<MapEntry<RegExp, String>> _networkPatterns = <MapEntry<RegExp, String>>[
  MapEntry<RegExp, String>(RegExp(r'\bAFTU\b', caseSensitive: false), 'AFTU'),
  MapEntry<RegExp, String>(RegExp(r'\bDEM\s*DIKK\b', caseSensitive: false), 'DDD'),
  MapEntry<RegExp, String>(RegExp(r'\bDDD\b', caseSensitive: false), 'DDD'),
  MapEntry<RegExp, String>(RegExp(r'\bBRT\b', caseSensitive: false), 'BRT'),
  MapEntry<RegExp, String>(RegExp(r'\bTER\b', caseSensitive: false), 'TER'),
];

final RegExp _scheduleKeywords = RegExp(
  r'\b(prochain|prochaine|horaire|horaires|quand|heure|passe|passage|d[ée]part|bus|ligne|arr[êe]t)\b',
  caseSensitive: false,
);
final RegExp _isoDate = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b');
final RegExp _frDate = RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b');
final RegExp _tomorrow = RegExp(r'\bdemain\b', caseSensitive: false);
final RegExp _today = RegExp("\\baujourd['’]?hui\\b", caseSensitive: false);
final RegExp _timeRe = RegExp(r'\b(\d{1,2})\s*(?:h|:)\s*(\d{2})?\b', caseSensitive: false);
final RegExp _lineWithKeyword = RegExp(
  r'\b(?:ligne|bus|n[°o]\.?|num[ée]ro)\s*(\d{1,3}\s?[A-Za-z]?)(?=[\s?.,!]|$)',
  caseSensitive: false,
);
final RegExp _lineBare = RegExp(r'(\d{1,3}\s?[A-Za-z]?)(?=[\s?.,!]|$)');
final RegExp _stopWords = RegExp(
  "\\b(maintenant|svp|s['’]il vous pla[îi]t|merci|le|la|du|de la|prochain|prochaine|passe|quand|horaires?|heure)\\b",
  caseSensitive: false,
);
final RegExp _stopMarker = RegExp(
  "(?:[àa] l['’]arr[êe]t|arr[êe]t|depuis|station|[àa] partir de|from|[àa])\\s+(.+)\$",
  caseSensitive: false,
);
final RegExp _trailingPunct = RegExp(r'[?!.,;]+\s*$');
final RegExp _trailingWords = RegExp(
  r'(\s+(?:à|a|de|du|des|le|la|les|pour|vers|et))+\s*$',
  caseSensitive: false,
);
final RegExp _directionSplit = RegExp(r'^(.+?)\s+(?:direction|vers)\s+(.+)$', caseSensitive: false);

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Date invalide dans la question → ignorée (jamais corrigée).
String? _safeDate(String value) {
  try {
    return normalizeServiceDate(value);
  } on FormatException {
    return null;
  }
}

/// Extraction déterministe : ce qui n'est pas écrit est null (aucune déduction).
ScheduleQuestion parseScheduleQuestion(String text, {DateTime? now}) {
  final String raw = text;
  final DakarClock clock = dakarClock(now ?? DateTime.now());
  String work = ' ${raw.replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  String? network;
  for (final MapEntry<RegExp, String> p in _networkPatterns) {
    if (p.key.hasMatch(work)) {
      network = p.value;
      work = work.replaceFirst(p.key, ' ');
      break;
    }
  }

  String? date;
  final RegExpMatch? iso = _isoDate.firstMatch(work);
  final RegExpMatch? fr = _frDate.firstMatch(work);
  if (iso != null) {
    date = _safeDate(iso.group(1)!);
    work = work.replaceFirst(iso.group(0)!, ' ');
  } else if (fr != null) {
    date = _safeDate('${fr.group(3)}-${fr.group(2)}-${fr.group(1)}');
    work = work.replaceFirst(fr.group(0)!, ' ');
  } else if (_tomorrow.hasMatch(work)) {
    date = addDays(clock.serviceDate, 1);
    work = work.replaceFirst(_tomorrow, ' ');
  } else if (_today.hasMatch(work)) {
    date = clock.serviceDate;
    work = work.replaceFirst(_today, ' ');
  }

  String? time;
  final RegExpMatch? t = _timeRe.firstMatch(work);
  if (t != null) {
    final int hh = int.parse(t.group(1)!);
    final int mm = t.group(2) == null ? 0 : int.parse(t.group(2)!);
    if (hh <= 47 && mm <= 59) {
      time = '${_pad2(hh)}:${_pad2(mm)}';
      work = work.replaceFirst(t.group(0)!, ' ');
    }
  }

  String? lineNumber;
  RegExpMatch? line = _lineWithKeyword.firstMatch(work);
  if (line == null && network != null) line = _lineBare.firstMatch(work);
  if (line != null) {
    lineNumber = line.group(1)!.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    work = work.replaceFirst(line.group(0)!, ' ');
  }

  work = work.replaceAll(_stopWords, ' ').replaceAll(RegExp(r'\s+'), ' ');
  String? stopName;
  String? directionHint;
  final RegExpMatch? stop = _stopMarker.firstMatch(work);
  if (stop != null) {
    String candidate =
        stop.group(1)!.replaceAll(_trailingPunct, '').replaceAll(_trailingWords, '').trim();
    final RegExpMatch? dir = _directionSplit.firstMatch(candidate);
    if (dir != null) {
      candidate = dir.group(1)!.trim();
      final String hint =
          dir.group(2)!.replaceAll(_trailingPunct, '').replaceAll(_trailingWords, '').trim();
      directionHint = hint.isEmpty ? null : hint;
    }
    stopName = candidate.isEmpty ? null : candidate;
  }

  // Question horaire : un numéro de ligne ET (un mot-clé horaire OU un réseau explicite avec un arrêt).
  final bool isScheduleQuestion = lineNumber != null &&
      (_scheduleKeywords.hasMatch(raw) || (network != null && stopName != null));
  return ScheduleQuestion(
    raw: raw,
    isScheduleQuestion: isScheduleQuestion,
    network: network,
    lineNumber: lineNumber,
    stopName: stopName,
    directionHint: directionHint,
    date: date == null ? null : toIsoDate(date),
    time: time,
  );
}

String scheduledSentence({
  required String network,
  required String lineNumber,
  required String stopName,
  required String timeHHMM,
  required String? terminus,
  required String source,
  required String sourceTypeLabel,
  required String? validFrom,
  required String? validTo,
}) {
  final StringBuffer b = StringBuffer(
      "La ligne $network $lineNumber dessert cet itinéraire. Depuis l'arrêt $stopName, le prochain départ programmé est à $timeHHMM.");
  if (terminus != null && terminus.isNotEmpty) b.write(' Direction $terminus.');
  b.write(' Source : $source ($sourceTypeLabel, validité $validFrom → $validTo).');
  return b.toString();
}

String estimatedSentence({
  required String network,
  required String lineNumber,
  required FrequencyEstimate estimate,
}) {
  final String window = estimate.windowFrom != null && estimate.windowTo != null
      ? ' entre ${estimate.windowFrom!.substring(0, 5)} et ${estimate.windowTo!.substring(0, 5)}'
      : '';
  return "La ligne $network $lineNumber dessert cet itinéraire. D'après ${estimate.source}, un passage est annoncé environ toutes les ${estimate.headwayMinutes} minutes$window. ${ScheduleSentences.noReliableData}";
}

class _Candidate {
  const _Candidate(this.departure, this.result, this.effective);

  final Departure departure;
  final DepartureResult result;
  final int effective;
}

DepartureResult? _frequencyEstimate(
  TransitDataProvider provider,
  String? network,
  String lineNumber,
  ProviderReference ref,
) {
  for (final ResolvedSource r in provider.resolveCurrentSources(ref.serviceDate)) {
    final ScheduleSource service = r.source.service;
    if (!r.usable || service is! FrequencySource) continue;
    final FrequencyEntry? entry = service.entryFor(network, lineNumber, ref.serviceDate, ref.time);
    if (entry == null) continue;
    final DepartureResult res = service.getDeparturesAtStop(
      entry.pseudoRouteId,
      null,
      ref.serviceDate,
      ref.time,
      asOf: ref.serviceDate,
    );
    if (res.status == ScheduleStatus.estimated) return res;
  }
  return null;
}

/// Réponse de l'assistant à partir du provider commun (jamais d'autre source).
ScheduleAnswer answerScheduleQuestion(
  TransitDataProvider provider,
  String text, {
  String? date,
  String? time,
  int limit = 3,
}) {
  final ScheduleQuestion q = parseScheduleQuestion(text, now: provider.now());
  if (!q.isScheduleQuestion || q.lineNumber == null) {
    return ScheduleAnswer(
      handled: false,
      status: 'NOT_A_SCHEDULE_QUESTION',
      sentence: null,
      question: q,
    );
  }
  final String lineNumber = q.lineNumber!;
  final ProviderReference ref = provider.reference(date: date ?? q.date, time: time ?? q.time);

  // 1. Ligne : uniquement par route_short_name, uniquement dans les sources actuelles utilisables.
  final List<RouteMatch> matches = provider.routesForLine(q.network, lineNumber, asOf: ref.serviceDate);
  final List<String> networks = <String>[];
  for (final RouteMatch m in matches) {
    final String? n = m.source.network;
    if (n != null && !networks.contains(n)) networks.add(n);
  }
  if (q.network == null && networks.length > 1) {
    return ScheduleAnswer(
      handled: true,
      status: 'AMBIGUOUS_NETWORK',
      reason: 'AMBIGUOUS_NETWORK',
      sentence:
          'Précisez le réseau (${networks.join(' ou ')}) : la ligne $lineNumber existe dans plusieurs réseaux.',
      question: q,
    );
  }
  if (matches.isEmpty) {
    final DepartureResult? est = _frequencyEstimate(provider, q.network, lineNumber, ref);
    if (est != null && est.estimate != null) {
      return ScheduleAnswer(
        handled: true,
        status: ScheduleStatus.estimated,
        sentence: estimatedSentence(
          network: est.estimate!.network,
          lineNumber: lineNumber,
          estimate: est.estimate!,
        ),
        question: q,
        network: est.estimate!.network,
        provenanceLevel: ProvenanceLevels.estimated,
        source: est.source,
        estimate: est.estimate,
      );
    }
    final bool known =
        provider.routesForLine(q.network, lineNumber, includeHistorical: true).isNotEmpty;
    return ScheduleAnswer(
      handled: true,
      status: ScheduleStatus.unknown,
      reason: known ? 'LINE_KNOWN_NO_CURRENT_SOURCE' : 'LINE_UNKNOWN',
      sentence: known ? ScheduleSentences.knownLineNoSchedule : ScheduleSentences.noReliableData,
      question: q,
      provenanceLevel: ProvenanceLevels.unknown,
      lineKnownHistorically: known,
    );
  }
  final String? network = q.network ?? (networks.isEmpty ? null : networks.first);
  if (q.stopName == null) {
    return ScheduleAnswer(
      handled: true,
      status: 'MISSING_STOP',
      reason: 'MISSING_STOP',
      sentence: "Précisez l'arrêt de départ pour la ligne ${network ?? ''} $lineNumber.".replaceAll('  ', ' '),
      question: q,
      network: network,
    );
  }

  // 2. Arrêt : parmi les arrêts réellement desservis par ces lignes, source par source (ordre de priorité).
  final Map<String, List<RouteMatch>> bySource = <String, List<RouteMatch>>{};
  for (final RouteMatch m in matches) {
    bySource.putIfAbsent(m.source.provenance.sourceId, () => <RouteMatch>[]).add(m);
  }
  List<String>? stopAmbiguity;
  String? unknownReason;
  for (final List<RouteMatch> group in bySource.values) {
    final RegisteredSource source = group.first.source;
    final ScheduleSource service = source.service;
    final Map<String, GtfsStop> served = <String, GtfsStop>{};
    for (final RouteMatch m in group) {
      for (final RouteDirectionStops dir in service.getStopsForRoute(m.route.routeId)) {
        for (final GtfsStop s in dir.stops) {
          served.putIfAbsent(s.stopId, () => s);
        }
      }
    }
    final StopMatches sm = TransitDataProvider.matchStops(served.values.toList(), q.stopName!);
    List<GtfsStop> stops = sm.exact;
    if (stops.isEmpty) {
      final List<String> names = <String>[];
      for (final GtfsStop s in sm.partial) {
        if (!names.contains(s.stopName)) names.add(s.stopName);
      }
      if (sm.partial.length == 1 || (sm.partial.length > 1 && names.length == 1)) {
        stops = sm.partial;
      } else if (sm.partial.length > 1) {
        stopAmbiguity = names;
        continue;
      } else {
        continue;
      }
    }
    // 3. Départs via le provider (mêmes règles de priorité et de validité).
    final List<_Candidate> candidates = <_Candidate>[];
    for (final RouteMatch m in group) {
      for (final GtfsStop stop in stops) {
        final DepartureResult res = provider.getDepartures(
          m.route.routeId,
          stop.stopId,
          date: ref.isoDate,
          time: ref.time,
          limit: limit,
        );
        if (res.status == ScheduleStatus.scheduled) {
          for (final Departure d in res.departures) {
            final int offset =
                normalizeServiceDate(d.serviceDate).compareTo(ref.serviceDate) < 0 ? 86400 : 0;
            candidates.add(_Candidate(d, res, d.departureSeconds - offset));
          }
        } else if (res.status == ScheduleStatus.unknown) {
          unknownReason ??= res.reason;
        }
      }
    }
    List<_Candidate> filtered = candidates;
    if (q.directionHint != null) {
      final String hint = normalizeText(q.directionHint);
      filtered = candidates
          .where((_Candidate c) =>
              normalizeText(c.departure.direction.terminusStopName).contains(hint) ||
              normalizeText(c.departure.direction.tripHeadsign).contains(hint))
          .toList();
      if (filtered.isEmpty && candidates.isNotEmpty) {
        unknownReason ??= 'NO_DEPARTURE_FOR_DIRECTION';
      }
    }
    filtered.sort((_Candidate a, _Candidate b) {
      final int c = a.effective.compareTo(b.effective);
      return c != 0 ? c : a.departure.tripId.compareTo(b.departure.tripId);
    });
    if (filtered.isNotEmpty) {
      final _Candidate best = filtered.first;
      final Departure d = best.departure;
      return ScheduleAnswer(
        handled: true,
        status: ScheduleStatus.scheduled,
        sentence: scheduledSentence(
          network: network ?? '',
          lineNumber: lineNumber,
          stopName: d.stopName,
          timeHHMM: formatHHMM(d.departureSeconds),
          terminus: d.direction.terminusStopName,
          source: d.source,
          sourceTypeLabel: d.sourceType,
          validFrom: d.validity.validFrom,
          validTo: d.validity.validTo,
        ),
        question: q,
        network: network,
        provenanceLevel: best.result.provenanceLevel,
        source: d.source,
        departure: d,
        departures: filtered.take(limit).map((_Candidate c) => c.departure).toList(),
      );
    }
  }
  if (stopAmbiguity != null) {
    return ScheduleAnswer(
      handled: true,
      status: 'AMBIGUOUS_STOP',
      reason: 'AMBIGUOUS_STOP',
      sentence:
          "Plusieurs arrêts correspondent à « ${q.stopName} » : ${stopAmbiguity.join(', ')}. Précisez l'arrêt.",
      question: q,
      network: network,
    );
  }
  return ScheduleAnswer(
    handled: true,
    status: ScheduleStatus.unknown,
    reason: unknownReason ?? 'STOP_NOT_FOUND_ON_LINE',
    sentence: ScheduleSentences.noReliableData,
    question: q,
    network: network,
    provenanceLevel: ProvenanceLevels.unknown,
  );
}
