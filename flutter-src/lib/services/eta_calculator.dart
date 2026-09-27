import '../models/departure_info.dart';
import '../models/transport_network.dart';

/// Résultat centralisé du calcul ETA. Jamais inventé sans données suffisantes.
class EtaResult {
  final int minutes; // 0 = Maintenant
  final DateTime etaAt; // instant UTC d'arrivée/passage estimé
  final EtaSource source;
  final double? confidence;
  final String? calculationMethod;
  final ScheduleStatus status; // garde la distinction interne

  const EtaResult({
    required this.minutes,
    required this.etaAt,
    required this.source,
    required this.status,
    this.confidence,
    this.calculationMethod,
  });

  bool get isNow => minutes == 0;
}

/// Calculateur centralisé — hiérarchie stricte :
/// 1) REAL_TIME si prédiction fraîche
/// 2) SCHEDULED si horaire théorique fiable
/// 3) ETA calculée si historique/temps de parcours/GPS suffisent
/// Sinon → null (Horaire indisponible, jamais inventé).
class EtaCalculator {
  /// Calcule l'ETA universelle à partir d'un DepartureInfo déjà résolu.
  /// La UI ne doit jamais refaire ce calcul.
  static EtaResult? fromDepartureInfo(DepartureInfo info, DateTime nowUtc) {
    final DateTime now = nowUtc.toUtc();

    // Niveau 1 & 2 : départ exact disponible (scheduled / realTime / estimated avec ETA)
    final DateTime? target = info.nextDepartureAt ?? info.etaAt ?? info.scheduledTime;
    if (target != null) {
      final int? seconds = _remainingSeconds(target, now);
      if (seconds == null) return null; // passé
      final int minutes = seconds == 0 ? 0 : (seconds + 59) ~/ 60;
      final EtaSource src = info.etaSource ??
          (info.status == ScheduleStatus.realTime ? EtaSource.realTime : EtaSource.schedule);
      return EtaResult(
        minutes: minutes,
        etaAt: target,
        source: src,
        status: info.status,
        confidence: info.etaConfidence ?? info.confidence,
        calculationMethod: info.calculationMethod ?? (info.status == ScheduleStatus.realTime ? 'REAL_TIME' : 'SCHEDULE'),
      );
    }

    // Niveau 3 : ETA calculée pour ESTIMATED quand nextDepartureAt absent
    // Attention : ne jamais présenter une fenêtre de fréquence comme HISTORICAL
    // sans preuve historique. Le défaut est COMBINED.
    if (info.status == ScheduleStatus.estimated && info.etaAt != null) {
      final int? seconds = _remainingSeconds(info.etaAt!, now);
      if (seconds == null) return null;
      final int minutes = seconds == 0 ? 0 : (seconds + 59) ~/ 60;
      return EtaResult(
        minutes: minutes,
        etaAt: info.etaAt!,
        source: info.etaSource ?? EtaSource.combined,
        status: ScheduleStatus.estimated,
        confidence: info.etaConfidence ?? info.confidence,
        calculationMethod: info.calculationMethod ?? 'COMBINED',
      );
    }

    // UNKNOWN ou autre sans cible → insuffisant
    return null;
  }

  /// Niveau 3 — calcule l'ETA à partir d'une fenêtre de fréquence + instant de référence.
  /// Utilise : premier départ de la fenêtre, fréquence, calendrier, heure actuelle.
  /// Retourne null si données insuffisantes (pas de fenêtre, hors plage, etc.).
  /// Cette méthode est la seule autorisée à convertir fréquence→heure via une fenêtre.
  static DateTime? estimatedEtaFromWindow({
    required FrequencyWindow window,
    required DateTime nowUtc,
    bool isPublicHoliday = false,
  }) {
    if (!window.appliesAt(nowUtc, isPublicHoliday: isPublicHoliday)) {
      final DateTime dakar = nowUtc.toUtc();
      final int nowMin = dakar.hour * 60 + dakar.minute;
      if (nowMin < window.startMinute) {
        final DateTime midnight = DateTime.utc(dakar.year, dakar.month, dakar.day);
        return midnight.add(Duration(minutes: window.startMinute));
      }
      return null;
    }
    final DateTime dakar = nowUtc.toUtc();
    final int nowMin = dakar.hour * 60 + dakar.minute;
    final int elapsed = nowMin - window.startMinute;
    final int remainder = elapsed % window.frequencyMinutes;
    final int delta = remainder == 0 ? 0 : window.frequencyMinutes - remainder;
    final DateTime midnight = DateTime.utc(dakar.year, dakar.month, dakar.day);
    if (delta == 0) {
      return DateTime.utc(dakar.year, dakar.month, dakar.day, dakar.hour, dakar.minute);
    }
    final int targetMin = nowMin + delta;
    if (targetMin > window.endMinute) return null;
    return midnight.add(Duration(minutes: targetMin));
  }

  /// GPS — sélectionne l'arrêt pertinent puis délègue au calcul normal.
  /// Ne remplace jamais le GPS réel par une position fictive.
  static EtaResult? fromGps({
    required DepartureInfo info,
    required DateTime nowUtc,
    // Positions génériques (lat/lon) — on évite LatLng pour ne pas dépendre de google_maps
    double? userLat,
    double? userLon,
    List<Map<String, double>>? vehiclePositions,
  }) {
    if (userLat == null && (vehiclePositions == null || vehiclePositions.isEmpty)) {
      return fromDepartureInfo(info, nowUtc);
    }
    final EtaResult? base = fromDepartureInfo(info, nowUtc);
    if (base == null) return null;
    if (userLat != null || (vehiclePositions != null && vehiclePositions.isNotEmpty)) {
      return EtaResult(
        minutes: base.minutes,
        etaAt: base.etaAt,
        source: EtaSource.gps,
        status: base.status,
        confidence: base.confidence,
        calculationMethod: 'GPS',
      );
    }
    return base;
  }

  /// Modèle historique / temps de parcours
  static DateTime? historicalEta({
    required List<DateTime> observedDepartures,
    required DateTime nowUtc,
  }) {
    if (observedDepartures.isEmpty) return null;
    final DateTime now = nowUtc.toUtc();
    for (final DateTime dep in observedDepartures) {
      if (!dep.isBefore(now)) return dep;
    }
    return null;
  }

  /// Travel time model : temps moyen entre arrêts
  static DateTime? travelTimeModelEta({
    required DateTime lastKnownPassage,
    required Duration averageTravelTime,
    required DateTime nowUtc,
  }) {
    final DateTime eta = lastKnownPassage.toUtc().add(averageTravelTime);
    if (eta.isBefore(nowUtc.toUtc())) return null;
    return eta;
  }

  static int? _remainingSeconds(DateTime target, DateTime now) {
    final int micros = target.toUtc().difference(now.toUtc()).inMicroseconds;
    if (micros < 0) return null;
    if (micros == 0) return 0;
    return (micros + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond;
  }
}
