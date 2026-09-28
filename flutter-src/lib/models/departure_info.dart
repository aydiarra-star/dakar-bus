import 'transport_network.dart';

/// Lot 4.21 §3 — IDENTITÉ PUBLIQUE D'UNE LIGNE, champ DISTINCT de la
/// disponibilité horaire.
///
/// AVANT : un seul et même état (`ScheduleStatus.unknown` + « Horaire
/// indisponible ») signifiait simultanément deux choses différentes :
///   * « l'identité publique de cette ligne n'est pas encore confirmée » ;
///   * « aucun horaire n'est calculable ».
/// Les lignes DDD/AFTU du feed PassBi — 52 routes DDD et 71 routes AFTU
/// pourvues de trips, stop_times et services actifs — étaient donc affichées
/// « Horaire indisponible » au seul motif que leur identité publique restait à
/// confirmer (crosswalk `IDENTITE_NON_CONFIRMEE`).
///
/// APRÈS : l'identité publique porte son propre statut. Une identité
/// [unconfirmed] n'empêche PAS un horaire `ScheduleStatus.scheduled`
/// techniquement calculable (§2 et §15 du lot) ; à l'inverse, une identité
/// [confirmed] ne garantit aucun départ.
enum IdentityStatus {
  /// Identité publique documentée : PREUVE DOCUMENTAIRE uniquement (identité
  /// officielle TER/BRT — `IDENTITY_OFFICIELLE`). Un numéro similaire, des
  /// terminus proches (`TERMINI_MATCH`), un route_id, un nom ou OSM ne
  /// confirment jamais une identité (verrouillage Lot 4.21).
  confirmed,

  /// Identité publique non résolue / à confirmer. N'implique AUCUNE absence de
  /// donnée horaire : les métadonnées PassBi réellement présentes (route_id,
  /// short_name, long_name) servent alors à l'affichage, sans nom commercial
  /// inventé ni origine/destination déduite du numéro.
  unconfirmed;

  /// Code documentaire stable (rapports, audits, tests).
  String get code => switch (this) {
        IdentityStatus.confirmed => 'CONFIRMED',
        IdentityStatus.unconfirmed => 'UNCONFIRMED',
      };
}

/// Lot 4.21 §15 — Raison précise d'un UNKNOWN restant.
///
/// Un UNKNOWN n'est jamais laissé sans explication : chaque valeur distingue
/// une cause réelle, et aucune ne correspond à « identité non confirmée alors
/// qu'un horaire est calculable » (ce cas produit désormais SCHEDULED).
class UnresolvedReason {
  /// Aucun feed PassBi ne couvre ce réseau (ex. TATA : aucune route, mode,
  /// vehicle_type, network ni agency PassBi ne l'établit — §6 du lot).
  static const String networkAbsentFromFeed = 'RESEAU_ABSENT_DU_FEED';

  /// Identité publique de la ligne non confirmée ET aucun couple
  /// (route, arrêt) PassBi rattachable à cette identité du référentiel dakar :
  /// aucun horaire n'est attribuable à CETTE identité (aucune identité n'est
  /// déduite d'un numéro seul).
  static const String identityUnconfirmed = 'IDENTITE_NON_CONFIRMEE';

  /// L'arrêt demandé ne correspond à aucune plateforme PassBi documentée.
  static const String stopNotMatched = 'ARRET_NON_CORRESPONDU';

  /// Route + arrêt + service résolus, mais aucun départ EMBARQUABLE dans le
  /// contexte temporel demandé (7 jours glissants) : fin de service, jour sans
  /// service, ou arrêt uniquement desservi en arrivée (terminus).
  static const String noComputableDeparture = 'AUCUN_DEPART_CALCULABLE';

  /// Le feed PassBi ne contient aucun `stop_time` pour cette route : aucun
  /// horaire n'existe dans la donnée (ex. DDD_323, AFTU_47, AFTU_52).
  static const String noStopTimesInFeed = 'AUCUN_STOP_TIME_DANS_LE_FEED';

  /// Source PassBi non chargée (échec de lecture des assets) : l'application
  /// reste sur le chemin legacy.
  static const String sourceInactive = 'SOURCE_PASSBI_INACTIVE';

  const UnresolvedReason._();
}

/// Période pendant laquelle une fréquence publiée est applicable.
///
/// Cette structure ne décrit que des intervalles de fréquence : elle ne
/// contient volontairement aucun horaire de passage ou `stop_time`.
class FrequencyWindow {
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;
  final int frequencyMinutes;
  final bool appliesOnPublicHoliday;
  final String? direction;

  const FrequencyWindow({
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    required this.frequencyMinutes,
    this.appliesOnPublicHoliday = false,
    this.direction,
  })  : assert(startMinute >= 0 && startMinute < 24 * 60),
        assert(endMinute >= 0 && endMinute < 24 * 60),
        assert(frequencyMinutes > 0);

  bool appliesAt(DateTime requestedAt, {bool isPublicHoliday = false}) {
    final minute = requestedAt.hour * 60 + requestedAt.minute;
    if (minute < startMinute || minute > endMinute) return false;
    if (isPublicHoliday) return appliesOnPublicHoliday;
    return weekdays.contains(requestedAt.weekday);
  }

  String get operatingHours => '${_clock(startMinute)}–${_clock(endMinute)}';

  static String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}

/// Source officielle de fréquence d'exploitation d'une ligne.
///
/// `status` caractérise ce que la source permet d'estimer. Ce n'est jamais un
/// statut temps réel. Une fréquence ne contient et ne génère aucun départ fixe.
class FrequencySource {
  final String operator;
  final String routeId;
  final String routeLabel;
  final String source;
  final SourceType sourceType;
  final String? dateSource;
  final String dateVerified;
  final String? validFrom;
  final String? validTo;
  final double confidence;
  final ScheduleStatus status;
  final List<FrequencyWindow> frequencies;
  final String operatingHours;

  const FrequencySource({
    required this.operator,
    required this.routeId,
    required this.routeLabel,
    required this.source,
    required this.sourceType,
    required this.dateSource,
    required this.dateVerified,
    required this.validFrom,
    required this.validTo,
    required this.confidence,
    required this.status,
    required this.frequencies,
    required this.operatingHours,
  })  : assert(confidence >= 0 && confidence <= 1),
        assert(status != ScheduleStatus.realTime);
}

/// Réponse calculée pour une demande à une date/heure donnée.
///
/// Pour `estimated`, `frequencyMinutes` et `operatingHours` sont des
/// métadonnées/provenance, pas une heure de départ. Les champs ne comportent
/// volontairement aucun `departureTime`.
class DepartureInfo {
  final ScheduleStatus status;
  final DateTime? referenceTime;
  final int? estimatedWaitFrom;
  final int? estimatedWaitTo;
  final DateTime? scheduledTime;
  final String operator;
  final String routeId;
  final String? source;
  final SourceType sourceType;
  final String? dateSource;
  final String? dateVerified;
  final String? validFrom;
  final String? validTo;
  final double? confidence;
  final int? frequencyMinutes;
  final String? operatingHours;
  final String? direction;

  /// Lot 4.21 §3 — identité publique de la ligne, DISTINCTE de [status].
  /// `unconfirmed` n'empêche pas un horaire `scheduled` calculable.
  final IdentityStatus identityStatus;

  /// Note documentaire d'identité (provenance : crosswalk ou métadonnées
  /// PassBi). Jamais un nom commercial inventé.
  final String? identityNote;

  /// Lot 4.21 §2 — identité d'affichage issue des métadonnées PassBi RÉELLES
  /// (ex. « Ligne PassBi DDD_217 »). `null` lorsque la ligne affichée reste
  /// celle du référentiel dakar (TER/BRT/AFTU mappés) : aucun rendu existant
  /// n'est modifié.
  final String? lineLabel;

  /// Lot 4.21 §15 — raison précise d'un UNKNOWN ([UnresolvedReason]).
  /// `null` lorsque le départ est calculable.
  final String? unresolvedReason;

  const DepartureInfo({
    required this.status,
    required this.operator,
    this.referenceTime,
    this.estimatedWaitFrom,
    this.estimatedWaitTo,
    this.scheduledTime,
    required this.routeId,
    required this.source,
    required this.sourceType,
    required this.dateSource,
    required this.dateVerified,
    required this.validFrom,
    required this.validTo,
    required this.confidence,
    required this.frequencyMinutes,
    required this.operatingHours,
    required this.direction,
    this.identityStatus = IdentityStatus.unconfirmed,
    this.identityNote,
    this.lineLabel,
    this.unresolvedReason,
  }) : assert(status != ScheduleStatus.realTime);

  /// Copie identique portant une raison d'UNKNOWN ([unresolvedReason]).
  /// Aucun autre champ n'est modifié — le libellé affiché reste inchangé.
  DepartureInfo withUnresolvedReason(String reason) => DepartureInfo(
        status: status,
        operator: operator,
        referenceTime: referenceTime,
        estimatedWaitFrom: estimatedWaitFrom,
        estimatedWaitTo: estimatedWaitTo,
        scheduledTime: scheduledTime,
        routeId: routeId,
        source: source,
        sourceType: sourceType,
        dateSource: dateSource,
        dateVerified: dateVerified,
        validFrom: validFrom,
        validTo: validTo,
        confidence: confidence,
        frequencyMinutes: frequencyMinutes,
        operatingHours: operatingHours,
        direction: direction,
        identityStatus: identityStatus,
        identityNote: identityNote,
        lineLabel: lineLabel,
        unresolvedReason: reason,
      );

  factory DepartureInfo.unknown({
    required String operator,
    required String routeId,
    FrequencySource? source,
    DateTime? requestedAt,
    IdentityStatus identityStatus = IdentityStatus.unconfirmed,
    String? identityNote,
    String? unresolvedReason,
  }) =>
      DepartureInfo(
        status: ScheduleStatus.unknown,
        operator: operator,
        routeId: routeId,
        referenceTime: requestedAt,
        estimatedWaitFrom: null,
        estimatedWaitTo: null,
        source: source?.source,
        sourceType: source?.sourceType ?? SourceType.unknown,
        dateSource: source?.dateSource,
        dateVerified: source?.dateVerified,
        validFrom: source?.validFrom,
        validTo: source?.validTo,
        confidence: source?.confidence,
        frequencyMinutes: null,
        // Une fenêtre générique ne doit pas laisser croire qu'elle est
        // applicable au jour/à l'heure demandés (ex. B2 le dimanche).
        operatingHours: null,
        direction: null,
        identityStatus: identityStatus,
        identityNote: identityNote,
        unresolvedReason: unresolvedReason,
      );

  bool get serviceActive => status == ScheduleStatus.scheduled ||
      status == ScheduleStatus.estimated;

  String get label {
    if (status == ScheduleStatus.estimated) {
      return 'Passage estimé dans $estimatedWaitFrom–$estimatedWaitTo min · fréquence $frequencyMinutes min';
    }
    if (status == ScheduleStatus.scheduled) {
      // Lot 4.18 : horaire PassBi réellement trouvé (SCHEDULED).
      final from = estimatedWaitFrom;
      if (from != null && from <= 0) {
        return 'Prochain départ dans moins d’une minute';
      }
      if (from != null) {
        return 'Prochain départ dans $from min';
      }
      return 'Départ programmé';
    }
    return 'Horaire indisponible';
  }

  factory DepartureInfo.fromFrequency(
    FrequencySource source,
    FrequencyWindow window,
    DateTime requestedAt,
  ) =>
      DepartureInfo(
        status: ScheduleStatus.estimated,
        operator: source.operator,
        routeId: source.routeId,
        referenceTime: requestedAt,
        estimatedWaitFrom: 0,
        estimatedWaitTo: window.frequencyMinutes,
        source: source.source,
        sourceType: source.sourceType,
        dateSource: source.dateSource,
        dateVerified: source.dateVerified,
        validFrom: source.validFrom,
        validTo: source.validTo,
        confidence: source.confidence,
        frequencyMinutes: window.frequencyMinutes,
        operatingHours: window.operatingHours,
        direction: window.direction,
        // Les sources de fréquence publiées du projet (SETER, SunuBRT) portent
        // une identité publique officielle : CONFIRMED (Lot 4.21 §3).
        identityStatus: IdentityStatus.confirmed,
        identityNote: 'Identité officielle publiée (${source.operator}).',
      );
}

/// Valeurs nulles-safe partagées pour les périodes documentées.
const Set<int> kMondayToSaturday = <int>{
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
};
const Set<int> kEveryDay = <int>{
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
};
