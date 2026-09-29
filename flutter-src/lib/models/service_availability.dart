import '../services/gtfs/gtfs_source.dart';

/// Codes documentaires de disponibilité/service (stables pour tests et audits).
class ServiceAvailabilityReason {
  /// Un départ réel est encore calculable dans le contexte demandé.
  static const String serviceActive = 'SERVICE_ACTIF';

  /// Le dernier départ documenté du jour (ou du service de nuit en cours) est
  /// passé : l'exploitation du jour est terminée.
  static const String afterLastDeparture = 'SERVICE_TERMINE';

  /// Aucun `stop_time` documenté : la fin de service n'est pas déterminable —
  /// on ne l'invente pas.
  static const String noDocumentedService = 'AUCUN_SERVICE_DOCUMENTE';

  /// Aucun feed pour ce réseau (ex. TATA) : aucune fin de service déductible.
  static const String networkAbsentFromFeed = 'RESEAU_ABSENT_DU_FEED';

  const ServiceAvailabilityReason._();
}

/// Statut de DISPONIBILITÉ du service d'une mobilité, distinct de la
/// provenance d'un horaire ([ScheduleStatus]).
///
/// Ce n'est PAS un statut de provenance : il ne remplace jamais
/// SCHEDULED/ESTIMATED/UNKNOWN, il les complète. Un arrêt peut avoir un
/// `ScheduleStatus.unknown` (aucun départ calculable ici) tout en étant
/// [active] (le réseau roule encore) — et inversement [serviceEnded] alors que
/// la provenance reste connue.
enum ServiceAvailabilityStatus {
  /// Au moins un départ documenté est encore calculable : le service du jour
  /// est en cours. Le message « Fin de service » ne doit JAMAIS être affiché.
  active,

  /// Le service documenté du jour est RÉELLEMENT terminé (l'instant dépasse le
  /// dernier départ embarquable documenté). Le service du lendemain à venir est
  /// alors décrit par [ServiceAvailability.resumptionAt].
  serviceEnded,

  /// Impossible de décider : aucune donnée documentée ne permet d'établir une
  /// fin de service. On n'invente rien (affiche « Horaire indisponible »).
  unknown,
}

/// Nombre de minutes avant le premier service documenté où l'exploitation est
/// de nouveau considérée active (reprise automatique). Exigence produit : 1 h.
const int kResumptionLeadMinutes = 60;

/// Disponibilité du service journalier d'une mobilité, calculée à partir des
/// seules bornes DOCUMENTÉES du feed (premier et dernier départ embarquable).
///
/// Règles absolues :
///  * « Fin de service » n'est produit que si le dernier départ embarquable
///    documenté du jour est réellement dépassé — jamais sur une absence de
///    donnée ni sur une fréquence ;
///  * la reprise automatique se cale sur le PREMIER départ documenté du
///    lendemain moins [kResumptionLeadMinutes] ; si ce premier départ n'est pas
///    documenté, aucune heure n'est inventée ;
///  * le calcul est déterministe (données du feed + instant fourni).
class ServiceAvailability {
  /// Libellé imposé par la spécification produit.
  static const String labelServiceEnded = 'Fin de service';

  final ServiceAvailabilityStatus status;

  /// Dernier départ embarquable documenté du jour considéré (`null` si aucun).
  final DateTime? lastDeparture;

  /// Instant (heure de Dakar) de reprise automatique de l'affichage : premier
  /// départ documenté du lendemain moins [resumptionLeadMinutes]. `null` quand
  /// aucun premier départ suffisamment étayé ne permet de le fixer.
  final DateTime? resumptionAt;

  /// Premier départ documenté du service de reprise (`null` si inconnu).
  final DateTime? firstDeparture;

  /// Avance de reprise appliquée (minutes), exposée pour la traçabilité.
  final int resumptionLeadMinutes;

  /// Code documentaire ([ServiceAvailabilityReason]).
  final String reason;

  const ServiceAvailability({
    required this.status,
    this.lastDeparture,
    this.resumptionAt,
    this.firstDeparture,
    this.resumptionLeadMinutes = kResumptionLeadMinutes,
    required this.reason,
  });

  /// Vrai lorsque l'affichage doit porter « Fin de service ».
  bool get isServiceEnded => status == ServiceAvailabilityStatus.serviceEnded;

  /// Vrai lorsque le service du jour est terminé ET que le service du lendemain
  /// est documenté (affichage actif attendu à [resumptionAt]) — « à venir ».
  bool get isUpcomingService =>
      status == ServiceAvailabilityStatus.serviceEnded && resumptionAt != null;

  /// À [at], la reprise a-t-elle déjà eu lieu (affichage redevenu actif) ?
  bool isResumedAt(DateTime at) {
    final DateTime? r = resumptionAt;
    if (r == null) return false;
    final DateTime t = at.isUtc ? at : at.toUtc();
    return !t.isBefore(r);
  }

  factory ServiceAvailability.active({
    DateTime? lastDeparture,
    DateTime? resumptionAt,
    DateTime? firstDeparture,
    int resumptionLeadMinutes = kResumptionLeadMinutes,
  }) =>
      ServiceAvailability(
        status: ServiceAvailabilityStatus.active,
        lastDeparture: lastDeparture,
        resumptionAt: resumptionAt,
        firstDeparture: firstDeparture,
        resumptionLeadMinutes: resumptionLeadMinutes,
        reason: ServiceAvailabilityReason.serviceActive,
      );

  factory ServiceAvailability.serviceEnded({
    DateTime? lastDeparture,
    DateTime? resumptionAt,
    DateTime? firstDeparture,
    int resumptionLeadMinutes = kResumptionLeadMinutes,
  }) =>
      ServiceAvailability(
        status: ServiceAvailabilityStatus.serviceEnded,
        lastDeparture: lastDeparture,
        resumptionAt: resumptionAt,
        firstDeparture: firstDeparture,
        resumptionLeadMinutes: resumptionLeadMinutes,
        reason: ServiceAvailabilityReason.afterLastDeparture,
      );

  factory ServiceAvailability.unknown(String reason) => ServiceAvailability(
        status: ServiceAvailabilityStatus.unknown,
        reason: reason,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceAvailability &&
      other.status == status &&
      other.lastDeparture == lastDeparture &&
      other.resumptionAt == resumptionAt &&
      other.firstDeparture == firstDeparture &&
      other.resumptionLeadMinutes == resumptionLeadMinutes &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(
      status, lastDeparture, resumptionAt, firstDeparture, resumptionLeadMinutes, reason);
}

/// Calcule la disponibilité du service journalier d'un réseau à [at].
///
/// [isScheduleAvailable] indique si le feed permet réellement de calculer un
/// prochain départ (au moins un `stop_time` + service exploitable). Sans lui,
/// le résultat est [ServiceAvailabilityStatus.unknown] : aucune fin de service
/// n'est déduite d'une absence de donnée.
ServiceAvailability computeNetworkServiceAvailability({
  required GtfsNetwork? network,
  required DateTime at,
  required bool Function(GtfsNetwork net) isScheduleAvailable,
}) {
  if (network == null) {
    return ServiceAvailability.unknown(
        ServiceAvailabilityReason.networkAbsentFromFeed);
  }
  if (!isScheduleAvailable(network)) {
    return ServiceAvailability.unknown(
        ServiceAvailabilityReason.noDocumentedService);
  }

  final DateTime t = at.isUtc ? at : at.toUtc();
  final DateTime day = DateTime.utc(t.year, t.month, t.day);
  final NetworkServiceBounds bounds = network.networkServiceBounds(day);
  if (bounds.lastSec < 0) {
    return ServiceAvailability.unknown(
        ServiceAvailabilityReason.noDocumentedService);
  }

  final int secondsOfDay = t.difference(day).inSeconds;
  final DateTime lastDeparture = day.add(Duration(seconds: bounds.lastSec));

  if (secondsOfDay > bounds.lastSec) {
    // Fin de service : le dernier départ documenté du jour (ou le dernier
    // départ d'un service de nuit ayant commencé la veille) est passé.
    final DateTime tomorrow = DateTime.utc(day.year, day.month, day.day + 1);
    return ServiceAvailability.serviceEnded(
      lastDeparture: lastDeparture,
      resumptionAt: _resumptionAt(network, tomorrow),
      firstDeparture: _firstDepartureOf(network, tomorrow),
    );
  }

  return ServiceAvailability.active(
    lastDeparture: lastDeparture,
    resumptionAt: _resumptionAt(network, day),
    firstDeparture: _firstDepartureOf(network, day),
  );
}

/// Premier départ documenté du service actif à cette date, `null` si non étayé.
DateTime? _firstDepartureOf(GtfsNetwork network, DateTime day) {
  final NetworkServiceBounds b = network.networkServiceBounds(day);
  final int? first = b.firstSec;
  if (first == null || first <= 0 || first >= b.daySec) return null;
  final DateTime base =
      DateTime.utc(day.year, day.month, day.day + b.dayOffset);
  return base.add(Duration(seconds: first));
}

/// Reprise automatique : premier départ documenté moins [kResumptionLeadMinutes].
/// `null` si le premier départ n'est pas suffisamment étayé (jamais inventé).
DateTime? _resumptionAt(GtfsNetwork network, DateTime day) {
  final DateTime? first = _firstDepartureOf(network, day);
  if (first == null) return null;
  return first.subtract(const Duration(minutes: kResumptionLeadMinutes));
}
