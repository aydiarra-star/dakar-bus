import 'transport_network.dart';

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
  }) : assert(status != ScheduleStatus.realTime);

  factory DepartureInfo.unknown({
    required String operator,
    required String routeId,
    FrequencySource? source,
    DateTime? requestedAt,
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
      );

  bool get serviceActive => status == ScheduleStatus.scheduled ||
      status == ScheduleStatus.estimated;

  String get label {
    if (status == ScheduleStatus.estimated) {
      return 'Passage estimé dans $estimatedWaitFrom–$estimatedWaitTo min · fréquence $frequencyMinutes min';
    }
    if (status == ScheduleStatus.scheduled) return 'Départ programmé';
    return 'Horaire indisponible';
  }

  /// Minutes restantes avant l'heure de départ réellement programmée.
  ///
  /// `null` dès qu'aucune heure exacte n'est connue (`scheduledTime` absent —
  /// cas de toute fréquence), que la référence est inexploitable, ou que le
  /// départ est déjà passé. Un départ passé ne produit donc **jamais** de
  /// « 0 min » ni de temps négatif : l'appelant retombe sur un état explicite.
  /// Une fréquence ne produit jamais de compte à rebours : la fréquence et le
  /// prochain départ sont deux données distinctes.
  int? minutesUntil(DateTime now) {
    final DateTime? departure = scheduledTime;
    if (departure == null || status != ScheduleStatus.scheduled) return null;
    final int minutes = departure.difference(now).inMinutes;
    if (minutes < 0) return null;
    return minutes;
  }

  /// Fabrique une réponse PROGRAMMÉE à partir d'une heure réellement fournie.
  ///
  /// À n'utiliser que lorsqu'une source exploitable donne l'heure exacte du
  /// départ : ce constructeur transporte alors `scheduledTime`. Il ne génère
  /// aucune heure à partir d'une fréquence.
  factory DepartureInfo.scheduled({
    required String operator,
    required String routeId,
    required DateTime scheduledTime,
    String? source,
    SourceType sourceType = SourceType.unknown,
    String? dateSource,
    String? dateVerified,
    String? validFrom,
    String? validTo,
    double? confidence,
    String? direction,
    DateTime? referenceTime,
  }) =>
      DepartureInfo(
        status: ScheduleStatus.scheduled,
        operator: operator,
        routeId: routeId,
        referenceTime: referenceTime,
        estimatedWaitFrom: null,
        estimatedWaitTo: null,
        scheduledTime: scheduledTime,
        source: source,
        sourceType: sourceType,
        dateSource: dateSource,
        dateVerified: dateVerified,
        validFrom: validFrom,
        validTo: validTo,
        confidence: confidence,
        frequencyMinutes: null,
        operatingHours: null,
        direction: direction,
      );

  /// Libellé « X min » du temps restant réellement calculable.
  ///
  /// Renvoie `null` quand aucun horaire exact n'existe ou que le départ est
  /// passé : l'appelant affiche alors un état explicite plutôt qu'un faux délai.
  /// `0` n'est renvoyé que pour un départ à l'instant présent.
  static String? formatRemainingMinutes(int? minutes) {
    if (minutes == null) return null;
    if (minutes <= 0) return '0 min';
    return '$minutes min';
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
