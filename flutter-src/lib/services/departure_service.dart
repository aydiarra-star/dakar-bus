import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/departure_estimate.dart';
import '../models/reliability.dart';
import '../models/transport_network.dart';

/// MOTEUR COMMUN DE DÉPARTS — miroir Dart de `engine/departure-engine.js`.
///
/// Hiérarchie appliquée sans exception :
///   1. horaire précis fiable ............ `ScheduleStatus.scheduled`
///   2. sinon fréquence fiable ........... `ScheduleStatus.estimated` (fenêtre)
///   3. sinon donnée véhicule réelle ..... `ScheduleStatus.realTime`
///   4. sinon ............................ `ScheduleStatus.unknown`
///
/// Le moteur ne contient AUCUNE donnée : sans référentiel chargé, tout est
/// `unknown` (échec fermé). Il n'invente jamais une heure, jamais un véhicule,
/// jamais un retard.
class DepartureEngineService {
  static const String engineVersion = '1.0.0';
  static const String registryAsset = 'assets/data/departure-frequencies.json';

  /// Référentiel chargé une seule fois par l'application (`main()`), comme la
  /// PWA charge `data/transit/departure-frequencies.json` au démarrage.
  ///
  /// `null` = moteur sans données : TOUT est `UNKNOWN` (échec fermé). Aucune
  /// fréquence de remplacement n'est créée pour « remplir » l'interface.
  static DepartureRegistry? registry;

  static bool get isReady => registry != null;

  /// Charge le référentiel embarqué si nécessaire.
  /// Retourne `true` si le moteur peut produire des estimations.
  static Future<bool> ensureLoaded() async {
    if (registry != null) return true;
    registry = await loadFromAssets();
    return registry != null;
  }

  /// Libellé d'interface (« TER », « BRT », « DDD », « AFTU », « Tata ») →
  /// réseau du référentiel. `null` pour tout libellé non documenté.
  static String? networkOfModeLabel(String? modeLabel) {
    if (modeLabel == null) return null;
    final String m = modeLabel.trim().toUpperCase();
    if (m == 'TATA') return 'TATA';
    if (m == 'TER' || m == 'BRT' || m == 'DDD' || m == 'AFTU') return m;
    return null;
  }

  /// Ligne documentée par défaut d'un réseau, utilisée seulement quand l'arrêt
  /// ne porte pas de `lineId` (arrêt hors référentiel). Volontairement limitée
  /// aux lignes réellement publiées : DDD, AFTU et TATA n'en ont aucune, donc
  /// aucune estimation ne leur est attribuée par défaut.
  static const Map<String, String> defaultLineIdByNetwork = <String, String>{
    'TER': 'ter_dakar_diamniadio',
    'BRT': 'brt_b1_guediawaye_petersen',
  };

  /// POINT D'ENTRÉE UNIQUE de l'interface (liste des arrêts, fiche d'arrêt,
  /// assistant) : un arrêt, son réseau, sa ligne → un [DepartureEstimate].
  ///
  /// Ne calcule rien : délègue à [estimateNextDeparture] et au référentiel
  /// chargé. Aucune heure n'est produite ici.
  static DepartureEstimate estimateForLine({
    String? modeLabel,
    String? lineId,
    String? stopId,
    String? direction,
    DateTime? now,
  }) {
    final String? network = networkOfModeLabel(modeLabel);
    return estimateNextDeparture(
      now: now ?? DateTime.now(),
      registry: registry,
      network: network,
      lineId: lineId ?? defaultLineIdByNetwork[network],
      stopId: stopId,
      direction: direction,
    );
  }

  /// Le réseau a-t-il des fréquences documentées dans le référentiel ?
  /// Sert à formuler l'assistant sans lui faire inventer de cadence.
  static bool hasDocumentedFrequency(String? modeLabel) {
    final String? network = networkOfModeLabel(modeLabel);
    final DepartureRegistry? reg = registry;
    if (network == null || reg == null) return false;
    return reg.frequencies.any((DepartureFrequency f) => f.network == network);
  }

  /// Usages autorisés de la position de l'utilisateur. Le GPS utilisateur
  /// n'est jamais un véhicule : voir [vehicleFromUserPosition].
  static const List<String> userPositionUses = <String>[
    'LOCALISATION',
    'STOP_PROXIMITY',
    'DISTANCE',
    'ROUTING',
  ];

  /// Une position d'utilisateur ne produit jamais de position de véhicule.
  static Map<String, double>? vehicleFromUserPosition(Object? userPosition) =>
      null;

  static const Map<int, String> _dayNames = <int, String>{
    DateTime.monday: 'MONDAY',
    DateTime.tuesday: 'TUESDAY',
    DateTime.wednesday: 'WEDNESDAY',
    DateTime.thursday: 'THURSDAY',
    DateTime.friday: 'FRIDAY',
    DateTime.saturday: 'SATURDAY',
    DateTime.sunday: 'SUNDAY',
  };

  // ------------------------------------------------------------------
  // Référentiel
  // ------------------------------------------------------------------

  /// Charge le référentiel embarqué. Toute erreur → `null` (donc `unknown`),
  /// jamais un jeu de fréquences de remplacement.
  static Future<DepartureRegistry?> loadFromAssets() async {
    try {
      final String raw = await rootBundle.loadString(registryAsset);
      return DepartureRegistry.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Parse un référentiel déjà lu (tests, cache hors ligne).
  static DepartureRegistry parseRegistry(String raw) =>
      DepartureRegistry.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Erreurs bloquantes : une fréquence sans source, sans jour ou sans période
  /// n'est pas une donnée exploitable.
  static List<String> validateFrequencyRegistry(DepartureRegistry registry) {
    final List<String> issues = <String>[];
    final Set<String> sourceIds =
        registry.sources.map((s) => s.id).toSet();
    for (final DepartureFrequency f in registry.frequencies) {
      if (f.lineId.isEmpty) issues.add('FREQUENCY_WITHOUT_LINE:${f.id}');
      if (f.frequencyMinutes <= 0) {
        issues.add('FREQUENCY_INVALID_MINUTES:${f.id}');
      }
      final int? start = clockToMinutes(f.serviceStart);
      final int? end = clockToMinutes(f.serviceEnd);
      if (start == null || end == null || end <= start) {
        issues.add('FREQUENCY_INVALID_SERVICE_WINDOW:${f.id}');
      }
      if (f.dayTypes.isEmpty) issues.add('FREQUENCY_WITHOUT_DAY_TYPE:${f.id}');
      if (f.sourceId == null || !sourceIds.contains(f.sourceId)) {
        issues.add('FREQUENCY_WITHOUT_VALID_SOURCE:${f.id}');
      }
      if (f.status.toUpperCase() == 'HISTORICAL') {
        issues.add('FREQUENCY_MARKED_HISTORICAL:${f.id}');
      }
    }
    for (final DepartureSource s in registry.sources) {
      if (s.sourceType == DepartureSourceType.official && s.url == null) {
        issues.add('OFFICIAL_SOURCE_WITHOUT_URL:${s.id}');
      }
    }
    return issues;
  }

  // ------------------------------------------------------------------
  // Temps — Dakar = UTC+00:00 toute l'année
  // ------------------------------------------------------------------

  static String dateOf(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  static int minutesOfDay(DateTime now) => now.hour * 60 + now.minute;

  /// Type de jour effectif. Un jour férié n'est appliqué que s'il est
  /// explicitement déclaré : le moteur ne devine aucun jour férié.
  static String dayTypeOf(DateTime now, {Set<String> holidays = const <String>{}}) {
    if (holidays.contains(dateOf(now))) return 'HOLIDAY';
    return _dayNames[now.weekday] ?? 'UNKNOWN';
  }

  static int? clockToMinutes(String? clock) {
    if (clock == null || clock.length != 5 || clock[2] != ':') return null;
    final int? hours = int.tryParse(clock.substring(0, 2));
    final int? minutes = int.tryParse(clock.substring(3, 5));
    if (hours == null || minutes == null) return null;
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return hours * 60 + minutes;
  }

  static String minutesToClock(int minutes) {
    final int m = ((minutes % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  /// Affichage FR : « 05:30 » → « 5h30 ».
  static String? clockToDisplay(String? clock) {
    final int? minutes = clockToMinutes(clock);
    if (minutes == null) return null;
    return '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
  }

  static String isoLocal(String date, int minutes) =>
      '${date}T${minutesToClock(minutes)}:00+00:00';

  /// `num.clamp` renvoie `num` : on borne explicitement en `int`.
  static int clampInt(int value, int low, int high) {
    if (value < low) return low;
    if (value > high) return high;
    return value;
  }

  static String? clockOfIso(String? iso) {
    if (iso == null || iso.length < 16) return null;
    return iso.substring(11, 16);
  }

  static String? minutesBetweenIso(String? fromIso, String? toIso) {
    final int? a = clockToMinutes(clockOfIso(fromIso));
    final int? b = clockToMinutes(clockOfIso(toIso));
    if (a == null || b == null) return null;
    return (b - a).toString();
  }

  // ------------------------------------------------------------------
  // §11 — Fenêtre d'estimation
  // ------------------------------------------------------------------

  static DepartureWindow estimateNextDepartureFromFrequency({
    required DateTime currentTime,
    required int frequency,
    required String serviceStart,
    required String serviceEnd,
  }) {
    final int? start = clockToMinutes(serviceStart);
    final int? end = clockToMinutes(serviceEnd);
    DepartureWindow unknown(String reason, String? note) => DepartureWindow(
          status: ScheduleStatus.unknown,
          reason: reason,
          note: note,
        );

    if (start == null || end == null || end <= start) {
      return unknown('NO_DATA', 'Période de service inconnue ou incohérente.');
    }
    if (frequency <= 0) {
      return unknown('NO_DATA', 'Fréquence inconnue.');
    }
    final String date = dateOf(currentTime);
    final int now = minutesOfDay(currentTime);

    if (now >= end) {
      return unknown('SERVICE_ENDED',
          'Service terminé (dernier départ documenté $serviceEnd).');
    }
    if (now < start) {
      final int to = start + frequency > end ? end : start + frequency;
      return DepartureWindow(
        status: ScheduleStatus.estimated,
        estimatedFrom: isoLocal(date, start),
        estimatedTo: isoLocal(date, to),
        frequencyMinutes: frequency,
        relative: 'BEFORE_SERVICE',
        reason: 'FREQUENCY_BEFORE_SERVICE',
        note: 'Service non commencé : premier passage estimé à partir de '
            '${clockToDisplay(serviceStart)}.',
      );
    }
    final int to = now + frequency > end ? end : now + frequency;
    return DepartureWindow(
      status: ScheduleStatus.estimated,
      estimatedFrom: isoLocal(date, now),
      estimatedTo: isoLocal(date, to),
      frequencyMinutes: frequency,
      relative: 'NOW',
      reason: 'FREQUENCY_ACTIVE',
      note: now + frequency > end
          ? 'Fin de période à $serviceEnd : la cadence suivante s’applique '
              'ensuite (aucune extrapolation).'
          : null,
    );
  }

  // ------------------------------------------------------------------
  // Sélection de fréquence
  // ------------------------------------------------------------------

  /// La période qui contient l'instant courant prime, sinon la prochaine
  /// ouverture, sinon la période terminée la plus tardive.
  ///
  /// Retourne la sélection ET le diagnostic « fréquence existante mais pas pour
  /// ce type de jour » — parité avec `selection.dayMismatch` du moteur JS, qui
  /// distingue `NO_FREQUENCY_FOR_DAY` de `NO_FREQUENCY_FOR_LINE`.
  static (DepartureSelection?, bool) selectFrequencyWithDiagnostics(
    DepartureRegistry registry, {
    required String lineId,
    String? network,
    String? dayType,
    String? date,
    int? minutes,
    bool allowCommunityFrequencies = false,
  }) {
    final List<DepartureFrequency> candidates =
        registry.frequenciesForLine(lineId);
    DepartureSelection? best;
    int bestRank = 99;
    int bestTieBreak = 0;
    bool dayMismatch = false;

    for (final DepartureFrequency f in candidates) {
      if (network != null && f.network != network) continue;
      if (f.stopId != null) continue; // fréquence d'arrêt : non utilisée ici
      if (dayType != null && f.dayTypes.isNotEmpty &&
          !f.dayTypes.contains(dayType)) {
        // Fréquence documentée, mais pas pour ce type de jour : B2 le dimanche.
        dayMismatch = true;
        continue;
      }
      if (f.status.toUpperCase() == 'HISTORICAL') continue;
      if (f.sourceId == null) continue;
      final DepartureSource? source = registry.sourceById(f.sourceId);
      if (source == null) continue;
      final DepartureSourcePolicy policy = DepartureSourcePolicy.of(
          source.sourceType.code,
          allowCommunity: allowCommunityFrequencies);
      if (!policy.usable) continue;
      if (date != null) {
        if (source.validFrom != null && source.validFrom!.compareTo(date) > 0) {
          continue;
        }
        if (source.validTo != null && source.validTo!.compareTo(date) < 0) {
          continue;
        }
      }
      final int? start = clockToMinutes(f.serviceStart);
      final int? end = clockToMinutes(f.serviceEnd);
      int rank = 2;
      int tieBreak = 0;
      if (minutes != null && start != null && end != null) {
        if (minutes >= start && minutes < end) {
          rank = 0;
          tieBreak = -end;
        } else if (minutes < start) {
          rank = 1;
          tieBreak = start;
        } else {
          rank = 3;
          tieBreak = -end;
        }
      }
      if (rank < bestRank || (rank == bestRank && tieBreak < bestTieBreak)) {
        bestRank = rank;
        bestTieBreak = tieBreak;
        best = DepartureSelection(frequency: f, policy: policy);
      }
    }
    return (best, dayMismatch);
  }

  /// Sélection publique : la fréquence retenue, ou `null`.
  static DepartureSelection? selectFrequency(
    DepartureRegistry registry, {
    required String lineId,
    String? network,
    String? dayType,
    String? date,
    int? minutes,
    bool allowCommunityFrequencies = false,
  }) =>
      selectFrequencyWithDiagnostics(
        registry,
        lineId: lineId,
        network: network,
        dayType: dayType,
        date: date,
        minutes: minutes,
        allowCommunityFrequencies: allowCommunityFrequencies,
      ).$1;

  // ------------------------------------------------------------------
  // Cœur
  // ------------------------------------------------------------------

  /// Estimation pour un arrêt / une ligne à un instant donné.
  ///
  /// [scheduledDepartures] : horaires précis sourcés (heure locale "HH:MM").
  /// Aucun horaire précis fourni ⇒ jamais de statut `scheduled`.
  static DepartureEstimate estimateNextDeparture({
    required DateTime now,
    required DepartureRegistry? registry,
    String? network,
    String? lineId,
    String? stopId,
    String? direction,
    List<Map<String, dynamic>> scheduledDepartures =
        const <Map<String, dynamic>>[],
  }) {
    final String dayType = registry == null
        ? dayTypeOf(now)
        : dayTypeOf(now, holidays: registry.holidays);

    // 1. Horaire précis fiable → scheduled
    final Map<String, dynamic>? scheduled =
        _pickScheduled(scheduledDepartures, now, lineId);
    if (scheduled != null) {
      final DepartureSourcePolicy policy = DepartureSourcePolicy.of(
          scheduled['sourceType'],
          allowCommunity: false);
      final int? scheduledMinutes =
          clockToMinutes(scheduled['time'] as String?);
      if (scheduledMinutes == null) {
        return DepartureEstimate.unknown(
          network: network,
          lineId: lineId,
          stopId: stopId,
          direction: direction,
          evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
          reason: 'SCHEDULE_UNREADABLE',
          note: 'Horaire illisible : aucune heure n’est proposée.',
        );
      }
      return DepartureEstimate(
        status: ScheduleStatus.scheduled,
        evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
        network: network,
        lineId: lineId,
        stopId: stopId,
        direction: direction,
        scheduledTime: isoLocal(dateOf(now), scheduledMinutes),
        source: scheduled['source'] as String?,
        sourceType: policy.sourceType,
        confidence: policy.confidence,
        dayType: dayType,
        relative: 'SCHEDULED',
        reason: 'SCHEDULED_TIMETABLE',
        usedSourceIsOfficial: policy.official,
      );
    }

    if (registry == null) {
      return DepartureEstimate.unknown(
        network: network,
        lineId: lineId,
        stopId: stopId,
        direction: direction,
        evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
        reason: 'NO_DATA',
        note: 'Référentiel de fréquences indisponible : aucune estimation, '
            'aucune heure inventée.',
      );
    }

    // 2. Fréquence fiable → estimated (fenêtre)
    bool dayMismatch = false;
    if (lineId != null) {
      final (DepartureSelection? retenue, bool jourNonCouvert) =
          selectFrequencyWithDiagnostics(
        registry,
        lineId: lineId,
        network: network,
        dayType: dayType,
        date: dateOf(now),
        minutes: minutesOfDay(now),
      );
      final DepartureSelection? selection = retenue;
      dayMismatch = jourNonCouvert;
      if (selection != null) {
        final DepartureWindow window = estimateNextDepartureFromFrequency(
          currentTime: now,
          frequency: selection.frequency.frequencyMinutes,
          serviceStart: selection.frequency.serviceStart,
          serviceEnd: selection.frequency.serviceEnd,
        );
        final DepartureSource? source =
            registry.sourceById(selection.frequency.sourceId);
        if (window.status == ScheduleStatus.estimated) {
          return DepartureEstimate(
            status: ScheduleStatus.estimated,
            evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
            network: network,
            lineId: lineId,
            stopId: stopId,
            direction: direction,
            estimatedFrom: window.estimatedFrom,
            estimatedTo: window.estimatedTo,
            frequencyMinutes: window.frequencyMinutes,
            source: source?.label,
            sourceType: selection.policy.sourceType,
            validFrom: source?.validFrom,
            validTo: source?.validTo,
            confidence: selection.policy.confidence,
            frequencyId: selection.frequency.id,
            retrievedAt: source?.retrievedAt,
            dayType: dayType,
            serviceStart: selection.frequency.serviceStart,
            serviceEnd: selection.frequency.serviceEnd,
            relative: window.relative,
            reason: window.reason,
            note: window.note,
            usedSourceIsOfficial: selection.policy.official,
          );
        }
        return DepartureEstimate.unknown(
          network: network,
          lineId: lineId,
          stopId: stopId,
          direction: direction,
          evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
          reason: window.reason,
          note: window.note,
        );
      }
    }

    // 4. Rien de fiable → unknown
    return DepartureEstimate.unknown(
      network: network,
      lineId: lineId,
      stopId: stopId,
      direction: direction,
      evaluatedAt: isoLocal(dateOf(now), minutesOfDay(now)),
      reason: dayMismatch ? 'NO_FREQUENCY_FOR_DAY' : 'NO_FREQUENCY_FOR_LINE',
      note: dayMismatch
          ? 'Fréquence documentée pour d’autres jours seulement : aucune '
              'estimation pour ce jour.'
          : 'Aucune fréquence documentée pour cette ligne : information '
              'indisponible, aucune estimation.',
    );
  }

  static Map<String, dynamic>? _pickScheduled(
    List<Map<String, dynamic>> departures,
    DateTime now,
    String? lineId,
  ) {
    Map<String, dynamic>? best;
    int? bestMinutes;
    final int nowMinutes = minutesOfDay(now);
    for (final Map<String, dynamic> d in departures) {
      final DepartureSourcePolicy policy =
          DepartureSourcePolicy.of(d['sourceType']);
      if (!policy.usable) continue;
      if (lineId != null && d['lineId'] != null && d['lineId'] != lineId) {
        continue;
      }
      final int? minutes = clockToMinutes(d['time'] as String?);
      if (minutes == null || minutes <= nowMinutes) continue;
      if (bestMinutes == null || minutes < bestMinutes) {
        bestMinutes = minutes;
        best = d;
      }
    }
    return best;
  }

  /// Contrôles internes : toute violation est un défaut du moteur.
  static List<String> validateEstimate(DepartureEstimate e) {
    final List<String> issues = <String>[];
    switch (e.status) {
      case ScheduleStatus.estimated:
        if (e.scheduledTime != null) issues.add('ESTIMATE_AS_SCHEDULED');
        if (e.observedAt != null) issues.add('ESTIMATE_AS_REALTIME');
        if (e.frequencyMinutes == null) issues.add('ESTIMATE_WITHOUT_FREQUENCY');
        if (e.estimatedFrom == null || e.estimatedTo == null) {
          issues.add('ESTIMATE_WITHOUT_WINDOW');
        } else if (e.estimatedTo!.compareTo(e.estimatedFrom!) <= 0) {
          issues.add('ESTIMATE_WINDOW_IS_NOT_A_WINDOW');
        }
        break;
      case ScheduleStatus.scheduled:
        if (e.scheduledTime == null) issues.add('SCHEDULED_WITHOUT_TIME');
        if (e.estimatedFrom != null || e.estimatedTo != null) {
          issues.add('SCHEDULED_DEGRADED_TO_ESTIMATE');
        }
        break;
      case ScheduleStatus.realTime:
        if (e.observedAt == null) issues.add('REALTIME_WITHOUT_OBSERVATION');
        if (e.vehicleId == null && e.eventId == null) {
          issues.add('REALTIME_WITHOUT_VEHICLE');
        }
        if (e.source == null) issues.add('REALTIME_WITHOUT_SOURCE');
        break;
      case ScheduleStatus.unknown:
        if (e.scheduledTime != null ||
            e.estimatedFrom != null ||
            e.estimatedTo != null ||
            e.frequencyMinutes != null ||
            e.observedAt != null) {
          issues.add('UNKNOWN_WITH_TIME');
        }
        break;
    }
    if (e.sourceType == DepartureSourceType.historical ||
        e.sourceType == DepartureSourceType.unknown) {
      if (e.status != ScheduleStatus.unknown) {
        issues.add('SERVICE_FROM_UNUSABLE_SOURCE');
      }
    }
    return issues;
  }

  // ------------------------------------------------------------------
  // §17 / §18 / §19 — présentation, assistant, itinéraires
  // ------------------------------------------------------------------

  /// Instant de référence d'une estimation : celui du calcul (`evaluatedAt`),
  /// jamais un « maintenant » différent. Un appelant peut toujours imposer un
  /// autre instant (tests, rejeu), mais l'interface n'a rien à recalculer.
  static DateTime referenceOf(DepartureEstimate e, {DateTime? now}) {
    if (now != null) return now;
    final String? iso = e.evaluatedAt;
    if (iso != null) {
      final DateTime? parsed = DateTime.tryParse(iso);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static DepartureDisplay displayFor(DepartureEstimate e, {DateTime? now}) {
    final DateTime ref = referenceOf(e, now: now);
    final bool official = e.usedSourceIsOfficial &&
        (e.sourceType == DepartureSourceType.official ||
            e.sourceType == DepartureSourceType.institutional);
    switch (e.status) {
      case ScheduleStatus.scheduled:
        final String clock = clockToDisplay(clockOfIso(e.scheduledTime)) ?? '—';
        return DepartureDisplay(
          status: e.status,
          badge: e.status.displayLabel(),
          title: 'Départ $clock',
          headline: 'Départ $clock',
          body: 'Horaire programmé',
          detail: e.source == null ? null : 'Source : ${e.source}',
          isOfficial: official,
          available: true,
        );
      case ScheduleStatus.estimated:
        final int? from = clockToMinutes(clockOfIso(e.estimatedFrom));
        final int? to = clockToMinutes(clockOfIso(e.estimatedTo));
        final int w1 =
            from == null ? 0 : clampInt(from - minutesOfDay(ref), 0, 1440);
        final int w2 = to == null
            ? (e.frequencyMinutes ?? 0)
            : clampInt(to - minutesOfDay(ref), w1, 1440);
        final String window = '$w1–$w2 min';
        if (e.relative == 'BEFORE_SERVICE') {
          return DepartureDisplay(
            status: e.status,
            badge: e.status.displayLabel(),
            title: 'Premier passage estimé',
            headline: 'Premier passage estimé entre '
                '${clockToDisplay(clockOfIso(e.estimatedFrom)) ?? '—'} et '
                '${clockToDisplay(clockOfIso(e.estimatedTo)) ?? '—'}',
            body: 'Service non commencé (ouverture documentée à '
                '${e.serviceStart ?? '—'})',
            detail: 'Estimation à partir d’une fréquence documentée '
                '(${e.frequencyMinutes} min)'
                '${e.source == null ? '' : ' — source : ${e.source}'}',
            windowLabel: window,
            trafficNote: 'Le passage réel peut varier selon l’exploitation et '
                'la circulation.',
            isEstimate: true,
            available: true,
          );
        }
        return DepartureDisplay(
          status: e.status,
          badge: e.status.displayLabel(),
          title: 'Prochain passage estimé',
          headline: 'Prochain passage estimé dans $window',
          body: 'Passage estimé '
              '${clockToDisplay(clockOfIso(e.estimatedFrom)) ?? '—'} – '
              '${clockToDisplay(clockOfIso(e.estimatedTo)) ?? '—'}',
          detail: 'Estimation à partir d’une fréquence documentée '
              '(${e.frequencyMinutes} min)'
              '${e.source == null ? '' : ' — source : ${e.source}'}',
          windowLabel: window,
          trafficNote: 'Le passage réel peut varier selon l’exploitation et la '
              'circulation.',
          isEstimate: true,
          available: true,
        );
      case ScheduleStatus.realTime:
        final int? eta = clockToMinutes(clockOfIso(e.estimatedFrom));
        final int? delta =
            eta == null ? null : clampInt(eta - minutesOfDay(ref), 0, 1440);
        final String title =
            delta == null ? 'Passage observé' : 'Arrivée dans $delta min';
        return DepartureDisplay(
          status: e.status,
          badge: e.status.displayLabel(),
          title: title,
          headline: title,
          body: 'Véhicule ${e.vehicleId ?? e.eventId ?? 'observé'} — observé à '
              '${clockToDisplay(clockOfIso(e.observedAt)) ?? '—'}',
          detail: e.source == null ? null : 'Source : ${e.source}',
          isOfficial: official,
          isRealTime: true,
          available: true,
        );
      case ScheduleStatus.unknown:
        return DepartureDisplay(
          status: ScheduleStatus.unknown,
          badge: ScheduleStatus.unknown.displayLabel(),
          title: 'Prochain passage',
          headline: 'Prochain passage',
          body: ReliabilityLabel.scheduleUnavailable,
        );
    }
  }

  /// Libellé court : jamais une heure précise pour une estimation.
  static String shortLabel(DepartureDisplay d) {
    switch (d.status) {
      case ScheduleStatus.scheduled:
        return d.headline;
      case ScheduleStatus.estimated:
        return '≈ ${d.windowLabel ?? '—'}';
      case ScheduleStatus.realTime:
        return d.headline;
      case ScheduleStatus.unknown:
        return ReliabilityLabel.scheduleUnavailable;
    }
  }

  /// L'assistant ne calcule rien : il formule le même [DepartureEstimate].
  static String assistantReply(
    DepartureEstimate e, {
    String? mode,
    DateTime? now,
  }) {
    final String network = mode ?? e.network ?? 'réseau';
    final String vehicleWord = network.toUpperCase() == 'TER' ? 'du train' : 'du bus';
    final DateTime ref = referenceOf(e, now: now);
    switch (e.status) {
      case ScheduleStatus.scheduled:
        return 'Le $network est disponible dans cette direction. Départ '
            'programmé à ${clockToDisplay(clockOfIso(e.scheduledTime)) ?? '—'}'
            '${e.source == null ? '' : ' (source : ${e.source})'}.';
      case ScheduleStatus.estimated:
        if (e.relative == 'BEFORE_SERVICE') {
          return 'Le $network est disponible dans cette direction. Le service '
              'commence à ${e.serviceStart ?? '—'} : le premier passage est '
              'estimé entre ${clockToDisplay(clockOfIso(e.estimatedFrom)) ?? '—'} et '
              '${clockToDisplay(clockOfIso(e.estimatedTo)) ?? '—'}. L\'heure exacte '
              '$vehicleWord n\'est pas disponible.';
        }
        final int? from = clockToMinutes(clockOfIso(e.estimatedFrom));
        final int? to = clockToMinutes(clockOfIso(e.estimatedTo));
        final int w1 =
            from == null ? 0 : clampInt(from - minutesOfDay(ref), 0, 1440);
        final int w2 = to == null
            ? (e.frequencyMinutes ?? 0)
            : clampInt(to - minutesOfDay(ref), w1, 1440);
        return 'Le $network est disponible dans cette direction. Le prochain '
            'passage est estimé dans une fenêtre de $w1 à $w2 minutes. '
            'L\'heure exacte $vehicleWord n\'est pas disponible.';
      case ScheduleStatus.realTime:
        final int? eta = clockToMinutes(clockOfIso(e.estimatedFrom));
        final int? delta =
            eta == null ? null : clampInt(eta - minutesOfDay(ref), 0, 1440);
        return 'Véhicule ${e.vehicleId ?? e.eventId ?? 'observé'} observé à '
            '${clockToDisplay(clockOfIso(e.observedAt)) ?? '—'}'
            '${delta == null ? '' : ' ; arrivée estimée dans $delta minutes'} '
            '(temps réel, source : ${e.source ?? 'opérateur'}).';
      case ScheduleStatus.unknown:
        return 'Je connais cette ligne, mais je n’ai pas actuellement de donnée '
            'suffisamment fiable pour estimer le prochain passage.';
    }
  }

  /// Une fenêtre de départ produit une fenêtre d'arrivée : jamais
  /// « vous arriverez exactement à 12h17 ».
  static DepartureLegPlan planItineraryLeg(
    DepartureEstimate e, {
    int? durationMinutes,
  }) {
    String? add(String? iso) {
      if (iso == null || durationMinutes == null) return null;
      final int? clock = clockToMinutes(clockOfIso(iso));
      if (clock == null) return null;
      return isoLocal(iso.substring(0, 10), clock + durationMinutes);
    }

    switch (e.status) {
      case ScheduleStatus.scheduled:
        return DepartureLegPlan(
          status: e.status,
          precision: 'EXACT',
          departureTime: e.scheduledTime,
          arrivalTime: add(e.scheduledTime),
          note: 'Horaire programmé — durée de parcours estimée.',
        );
      case ScheduleStatus.estimated:
        return DepartureLegPlan(
          status: e.status,
          precision: 'WINDOW',
          departureWindowFrom: e.estimatedFrom,
          departureWindowTo: e.estimatedTo,
          arrivalWindowFrom: add(e.estimatedFrom),
          arrivalWindowTo: add(e.estimatedTo),
          note: 'Départ estimé : l’arrivée reste une fenêtre, l’incertitude '
              'est conservée.',
        );
      case ScheduleStatus.realTime:
        return DepartureLegPlan(
          status: e.status,
          precision: 'REALTIME_DEPARTURE_PLUS_ESTIMATED_TRAVEL',
          departureTime: e.estimatedFrom,
          arrivalTime: add(e.estimatedFrom),
          note: 'Départ observé ; durée de parcours estimée.',
        );
      case ScheduleStatus.unknown:
        return const DepartureLegPlan(
          status: ScheduleStatus.unknown,
          precision: 'NONE',
          note: '${ReliabilityLabel.scheduleUnavailable} : aucune heure de '
              'départ ou d’arrivée n’est annoncée.',
        );
    }
  }
}
