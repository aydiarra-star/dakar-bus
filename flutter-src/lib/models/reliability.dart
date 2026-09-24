import 'transport_network.dart';

/// Décisions d'affichage liées à la fiabilité des données (audit 2026-09-24).
///
/// SEULE source des badges de fiabilité et des libellés d'horaire affichés par
/// l'interface. Règles :
///  * « OFFICIEL » uniquement pour une donnée CONFIRMED (provenance traçable) ;
///  * UNVERIFIED et CONFLICTING ne sont jamais présentés comme confirmés ;
///  * FUTURE n'est jamais présenté comme actif ;
///  * un statut inconnu n'est jamais promu : il vaut UNVERIFIED ;
///  * sans horaire vérifié : « Horaire indisponible », jamais d'heure calculée,
///    et jamais de temps réel (aucun flux n'existe dans le projet).
class ReliabilityLabel {

  static const String scheduleUnavailable = 'Horaire indisponible';
  /// Phrase imposée, mot pour mot, quand aucun horaire vérifié n'existe.
  static const String noVerifiedSchedule =
      "Je ne dispose pas d'un horaire vérifié pour ce trajet.";

  static const String badgeConfirmed = 'OFFICIEL';
  static const String badgeUnverified = 'NON VÉRIFIÉ';
  static const String badgeConflicting = 'CONTESTÉ';
  static const String badgeFuture = 'PROCHAINEMENT';

  /// Statut effectif d'un ensemble (ex. une route ET l'un de ses arrêts) : le
  /// MOINS sûr l'emporte. Ensemble vide → UNVERIFIED (rien n'est confirmé par
  /// défaut).
  static ProvenanceStatus combine(Iterable<ProvenanceStatus> statuses) {
    if (statuses.isEmpty) return ProvenanceStatus.unverified;
    if (statuses.contains(ProvenanceStatus.future)) return ProvenanceStatus.future;
    if (statuses.contains(ProvenanceStatus.conflicting)) {
      return ProvenanceStatus.conflicting;
    }
    if (statuses.contains(ProvenanceStatus.unverified)) {
      return ProvenanceStatus.unverified;
    }
    return ProvenanceStatus.confirmed;
  }

  /// Le badge « OFFICIEL » n'est autorisé que pour CONFIRMED.
  static bool canShowOfficial(ProvenanceStatus status) =>
      status == ProvenanceStatus.confirmed;

  /// Présenté comme actif (en service) : jamais pour FUTURE.
  static bool isPresentedAsActive(ProvenanceStatus status) =>
      status != ProvenanceStatus.future;

  /// Libellé du badge de fiabilité.
  static String badge(ProvenanceStatus status) {
    switch (status) {
      case ProvenanceStatus.confirmed:
        return badgeConfirmed;
      case ProvenanceStatus.unverified:
        return badgeUnverified;
      case ProvenanceStatus.conflicting:
        return badgeConflicting;
      case ProvenanceStatus.future:
        return badgeFuture;
    }
  }

  /// Statut d'horaire d'une liste de départs. Liste vide → UNKNOWN.
  /// Une liste fournie est au mieux SCHEDULED : ce module ne produit JAMAIS
  /// REAL_TIME (aucun flux officiel ni opérateur n'est disponible).
  static ScheduleStatus scheduleStatusOf(List<int> departures) =>
      departures.isEmpty ? ScheduleStatus.unknown : ScheduleStatus.scheduled;

  /// Garde-fou : un statut d'horaire ne peut pas « monter » vers REAL_TIME
  /// sans flux réel. [hasRealtimeFeed] est `false` dans tout le projet.
  static ScheduleStatus guardRealtime(ScheduleStatus status,
      {bool hasRealtimeFeed = false}) {
    if (status == ScheduleStatus.realTime && !hasRealtimeFeed) {
      return ScheduleStatus.unknown;
    }
    return status;
  }
}
