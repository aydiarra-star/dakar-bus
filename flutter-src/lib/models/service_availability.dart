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

  /// Borne d'affichage : instant au-delà duquel un départ appartient à un
  /// service qui n'a PAS encore repris (jour de service suivant). Un départ
  /// dont l'horaire est ≥ à cette borne ne doit jamais être présenté comme une
  /// attente du service en cours — c'est l'origine des attentes aberrantes de
  /// plusieurs centaines de minutes (ex. 508 min).
  ///
  /// Calcul :
  ///  * si la reprise T-1h du prochain jour de service tombe APRÈS le dernier
  ///    départ du jour applicable (vraie interruption, ex. BRT/TER), la borne
  ///    est cette reprise ;
  ///  * sinon (réseau quasi continu, la reprise tombe pendant le service en
  ///    cours, ex. DDD), la borne est le PREMIER départ du jour de service
  ///    suivant (inclus), afin de ne pas supprimer un départ nocturne réel ;
  ///  * `null` si aucune donnée documentée ne permet de la fixer.
  final DateTime? displayHorizonAt;

  /// Code documentaire ([ServiceAvailabilityReason]).
  final String reason;

  const ServiceAvailability({
    required this.status,
    this.lastDeparture,
    this.resumptionAt,
    this.firstDeparture,
    this.resumptionLeadMinutes = kResumptionLeadMinutes,
    this.displayHorizonAt,
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
    DateTime? displayHorizonAt,
  }) =>
      ServiceAvailability(
        status: ServiceAvailabilityStatus.active,
        lastDeparture: lastDeparture,
        resumptionAt: resumptionAt,
        firstDeparture: firstDeparture,
        resumptionLeadMinutes: resumptionLeadMinutes,
        displayHorizonAt: displayHorizonAt,
        reason: ServiceAvailabilityReason.serviceActive,
      );

  factory ServiceAvailability.serviceEnded({
    DateTime? lastDeparture,
    DateTime? resumptionAt,
    DateTime? firstDeparture,
    int resumptionLeadMinutes = kResumptionLeadMinutes,
    DateTime? displayHorizonAt,
  }) =>
      ServiceAvailability(
        status: ServiceAvailabilityStatus.serviceEnded,
        lastDeparture: lastDeparture,
        resumptionAt: resumptionAt,
        firstDeparture: firstDeparture,
        resumptionLeadMinutes: resumptionLeadMinutes,
        displayHorizonAt: displayHorizonAt,
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
      other.displayHorizonAt == displayHorizonAt &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(status, lastDeparture, resumptionAt,
      firstDeparture, resumptionLeadMinutes, displayHorizonAt, reason);
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
  final int secondsOfDay = t.difference(day).inSeconds;

  // Bornes du service RÉELLEMENT applicable ce jour-là (aucun repli sur le
  // lendemain : c'est la distinction Fin de service vs service encore actif).
  final int lastToday = network.lastDepartureSecOn(day);
  final DateTime? lastDeparture =
      lastToday < 0 ? null : day.add(Duration(seconds: lastToday));

  if (lastToday >= 0 && secondsOfDay <= lastToday) {
    // Le service applicable roule encore (un départ embarquable reste possible
    // aujourd'hui, service de nuit type DDD inclus).
    final resumptionAt = _todayResumption(network, day);
    return ServiceAvailability.active(
      lastDeparture: lastDeparture,
      resumptionAt: resumptionAt,
      firstDeparture: _firstDepartureOf(network, day),
      displayHorizonAt: _activeHorizon(network, day, lastDeparture),
    );
  }

  // Fin de service : le dernier départ embarquable du jour est passé, ou aucun
  // service n'est actif aujourd'hui. On cherche le prochain jour de service
  // documenté (jusqu'à 7 jours) et sa fenêtre de reprise T-1h :
  //   * journée déjà terminée (now > dernier départ) → on passe à la suivante ;
  //   * fenêtre de reprise atteinte (now ≥ premier départ − 1 h) → service
  //     actif : le prochain départ documenté est affichable ;
  //   * sinon → fin de service, reprise à (premier départ − 1 h).
  for (int d = 0; d <= 7; d++) {
    final DateTime dd = DateTime.utc(day.year, day.month, day.day + d);
    final int? firstSec = network.firstDepartureSecOn(dd);
    if (firstSec == null) continue;
    final int lastSec = network.lastDepartureSecOn(dd);
    final DateTime first = _dayOf(dd).add(Duration(seconds: firstSec));
    final DateTime last = _dayOf(dd).add(Duration(seconds: lastSec));
    final DateTime resume =
        first.subtract(const Duration(minutes: kResumptionLeadMinutes));
    if (t.isAfter(last)) continue; // journée entièrement terminée
    if (!t.isBefore(resume)) {
      // Fenêtre de reprise T-1h atteinte : le prochain service est affichable
      // (aucun départ réel masqué — ex. service nocturne DDD à 00:09).
      return ServiceAvailability.active(
        lastDeparture: lastDeparture,
        resumptionAt: resume,
        firstDeparture: first,
        displayHorizonAt: _activeHorizon(network, dd, last),
      );
    }
    return ServiceAvailability.serviceEnded(
      lastDeparture: lastDeparture,
      resumptionAt: resume,
      firstDeparture: first,
      displayHorizonAt: resume,
    );
  }

  return ServiceAvailability.unknown(
      ServiceAvailabilityReason.noDocumentedService);
}

DateTime _dayOf(DateTime day) => DateTime.utc(day.year, day.month, day.day);

/// Premier départ documenté du service actif à cette date, `null` si non étayé.
///
/// Un service de nuit qui commence à 00:00 est conservé tel quel : `firstSec`
/// peut valoir `0`. Il n'est écarté que s'il atteint la borne haute du feed
/// (≥ [NetworkServiceBounds.daySec]), c'est-à-dire qu'il n'y a pas de fenêtre
/// documentée cohérente.
DateTime? _firstDepartureOf(GtfsNetwork network, DateTime day) {
  final NetworkServiceBounds b = network.networkServiceBounds(day);
  final int? first = b.firstSec;
  if (first == null || first >= b.daySec) return null;
  return _dayOf(day).add(Duration(days: b.dayOffset, seconds: first));
}

/// Reprise « du jour » (service ACTIF) : premier départ documenté de [day]
/// moins [kResumptionLeadMinutes], `null` si le jour n'a pas de premier départ
/// étayé. Exposée pour la traçabilité du service en cours.
DateTime? _todayResumption(GtfsNetwork network, DateTime day) {
  final DateTime? first = _firstDepartureOf(network, day);
  if (first == null) return null;
  return first.subtract(const Duration(minutes: kResumptionLeadMinutes));
}

/// Borne d'affichage lorsque le service est ACTIF : un départ du jour de
/// service suivant n'est affichable que si la reprise T-1h de ce jour tombe
/// APRÈS le dernier départ du jour applicable (vraie interruption, ex.
/// BRT/TER). Sinon (réseau quasi continu, la reprise tombe pendant le service
/// en cours, ex. DDD) la borne est le PREMIER départ du jour suivant, inclus :
/// aucun départ nocturne réel n'est supprimé, et aucune attente aberrante du
/// lendemain (ex. 508 min) n'est présentée comme le service en cours.
DateTime? _activeHorizon(
  GtfsNetwork network,
  DateTime day,
  DateTime? lastDeparture,
) {
  final resumption = network.nextServiceResumption(day);
  if (resumption == null) return null;
  final DateTime nextFirst = _dayOf(resumption.day)
      .add(Duration(seconds: resumption.firstSec));
  final DateTime nextResumption =
      nextFirst.subtract(const Duration(minutes: kResumptionLeadMinutes));
  // Vraie interruption (ex. BRT/TER) : la reprise T-1h du lendemain tombe
  // APRÈS le dernier départ du jour → borne = cette reprise.
  if (lastDeparture != null && nextResumption.isAfter(lastDeparture)) {
    return nextResumption;
  }
  // Réseau quasi continu (ex. DDD) : la reprise tombe pendant le service en
  // cours → borne = premier départ du jour suivant (inclus), aucun départ
  // nocturne réel supprimé.
  return nextFirst;
}
