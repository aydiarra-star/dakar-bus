import '../models/departure_info.dart';
import '../models/transport_network.dart';
import '../models/schedule_models.dart';

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

    // Une prédiction temps réel périmée ne prouve plus un passage futur.
    if (info.realtimeValidUntil != null &&
        now.isAfter(info.realtimeValidUntil!)) return null;

    // Une heure vérifiable est requise. Une fréquence seule ne porte aucune ETA.
    if (info.status == ScheduleStatus.unknown) return null;
    if (info.status == ScheduleStatus.estimated && info.etaAt == null) {
      return null;
    }
    final DateTime? target = info.etaAt ??
        (info.status == ScheduleStatus.estimated ? null : info.nextDepartureAt ?? info.scheduledTime);
    if (target == null) return null;
    final int? seconds = _remainingSeconds(target, now);
    if (seconds == null) return null;
    final int minutes = seconds == 0 ? 0 : (seconds + 59) ~/ 60;
    final EtaSource? source = info.etaSource ??
        (info.status == ScheduleStatus.realTime
            ? EtaSource.realTime
            : info.status == ScheduleStatus.scheduled ? EtaSource.schedule : null);
    // ESTIMATED doit indiquer l'origine du calcul, sans source implicite.
    if (source == null) return null;
    return EtaResult(
      minutes: minutes,
      etaAt: target,
      source: source,
      status: info.status,
      confidence: info.etaConfidence ?? info.confidence,
      calculationMethod: info.calculationMethod ?? source.name,
    );
  }

  /// Cadence ancrée : SEULEMENT si un opérateur a publié l'heure du premier
  /// départ AU TERMINUS concerné et la cadence exacte jusqu'au dernier.
  /// Un simple intervalle à un arrêt intermédiaire ne passe jamais ici.
  /// La vérification source/terminus/service est la responsabilité du provider ;
  /// ce calculateur ne fait que l'arithmétique d'instants déjà documentés.
  static DateTime? anchoredTerminalEta({
    required DateTime firstDepartureAt,
    required DateTime lastDepartureAt,
    required Duration headway,
    required DateTime nowUtc,
  }) {
    final first = firstDepartureAt.toUtc();
    final last = lastDepartureAt.toUtc();
    final now = nowUtc.toUtc();
    if (headway <= Duration.zero || last.isBefore(first) ||
        ServiceDate.fromInstant(first) != ServiceDate.fromInstant(last) ||
        ServiceDate.fromInstant(first) != ServiceDate.fromInstant(now) ||
        now.isAfter(last)) return null;
    if (!now.isAfter(first)) return first;
    final elapsed = now.difference(first).inMicroseconds;
    final interval = headway.inMicroseconds;
    final hops = (elapsed + interval - 1) ~/ interval;
    final next = first.add(Duration(microseconds: hops * interval));
    return next.isAfter(last) ? null : next;
  }

  /// La position de l'utilisateur ne prédit pas le passage du véhicule.
  /// Sans modèle de trajet du véhicule vérifié, préserver l'ETA et sa source.
  static EtaResult? fromGps({
    required DepartureInfo info,
    required DateTime nowUtc,
    double? userLat,
    double? userLon,
    List<Map<String, double>>? vehiclePositions,
  }) {
    return fromDepartureInfo(info, nowUtc);
  }

  /// Prévision empirique seulement si trois passages réellement observés,
  /// antérieurs à now, montrent deux intervalles identiques et récents.
  /// Aucune fenêtre de fréquence publiée n'est interprétée comme historique.
  static DateTime? historicalEta({
    required List<DateTime> observedDepartures,
    required DateTime nowUtc,
  }) {
    if (observedDepartures.length < 3) return null;
    final now = nowUtc.toUtc();
    final sorted = observedDepartures.map((d) => d.toUtc()).toList()..sort();
    if (sorted.last.isAfter(now)) return null;
    final first = sorted[sorted.length - 3];
    final second = sorted[sorted.length - 2];
    final last = sorted.last;
    final headway = last.difference(second);
    if (headway <= Duration.zero || headway != second.difference(first) ||
        now.difference(last) > headway) return null;
    final eta = last.add(headway);
    return eta.isBefore(now) ? null : eta;
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
