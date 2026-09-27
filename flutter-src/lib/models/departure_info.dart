import 'schedule_models.dart';
import 'transport_network.dart';

/// Source tracée d'une ETA — conservée même quand l'UI n'affiche que `🟢 X min`.
/// La distinction REAL_TIME / SCHEDULED / ESTIMATED reste dans [DepartureInfo.status],
/// mais [EtaSource] précise le calcul effectif (historique, GPS, etc.).
enum EtaSource {
  schedule,
  realTime,
  gps,
  historical,
  travelTimeModel,
  combined,
}

/// État du service, indépendant de la provenance et de la précision de l'ETA.
/// L'absence de preuve et l'absence d'ETA ne sont PAS une interruption.
enum OperationalStatus { normal, delayed, unavailable }

/// Preuve explicite d'un incident d'exploitation, limitée à une ligne et à une
/// période. Aucun flux d'incident n'est branché aujourd'hui : le simple statut
/// d'un horaire, une fréquence ou une confiance basse ne créent pas cette preuve.
class OperationalEvidence {
  final OperationalStatus status;
  final String routeId;
  final String source;
  final SourceType sourceType;
  final DateTime observedAt;
  final DateTime validUntil;

  OperationalEvidence({
    required this.status,
    required this.routeId,
    required this.source,
    required this.sourceType,
    required DateTime observedAt,
    required DateTime validUntil,
  }) : observedAt = observedAt.toUtc(), validUntil = validUntil.toUtc() {
    if (routeId.trim().isEmpty || source.trim().isEmpty ||
        !(Uri.tryParse(source)?.hasScheme ?? false) ||
        !{SourceType.officialStatic, SourceType.officialRealtime,
          SourceType.operatorRealtime}.contains(sourceType) ||
        !this.validUntil.isAfter(this.observedAt)) {
      throw ArgumentError('Un état opérationnel exige ligne, source et validité explicites');
    }
  }

  bool isValidAt(DateTime at) =>
      !at.toUtc().isBefore(observedAt) && !at.toUtc().isAfter(validUntil);
}

/// Période pendant laquelle une fréquence publiée est applicable.
///
/// Cette structure décrit uniquement une fréquence ; elle ne contient aucun
/// horaire de passage ou `stop_time` et ne peut pas produire un instant précis.
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
    // Africa/Dakar est UTC+0 actuellement. Normaliser un instant évite de lire
    // l'heure murale du téléphone ; une heure locale artificielle doit être
    // construite explicitement comme DateTime.utc dans les tests.
    final DateTime dakarInstant = requestedAt.toUtc();
    final int minute = dakarInstant.hour * 60 + dakarInstant.minute;
    if (minute < startMinute || minute > endMinute) return false;
    if (isPublicHoliday) return appliesOnPublicHoliday;
    return weekdays.contains(dakarInstant.weekday);
  }

  String get operatingHours => '${_clock(startMinute)}–${_clock(endMinute)}';

  static String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}

/// Source de fréquence d'exploitation. Une source de fréquence n'est jamais
/// un horaire statique par arrêt ni un flux temps réel.
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

/// Résultat immuable d'une recherche de départ.
///
/// Le constructeur générique est privé : le statut et les champs horaires sont
/// créés par des factories qui vérifient leurs invariants à l'exécution.
class DepartureInfo {
  final ScheduleStatus status;
  final DateTime? referenceTime;
  final int? estimatedWaitFrom;
  final int? estimatedWaitTo;
  final DateTime? scheduledTime;
  final DateTime? nextDepartureAt;
  final DateTime? calculatedAt;
  final DateTime? observedAt;
  final String operator;
  final String routeId;
  final String? stopId;
  final int? stopSequence;
  final String? tripId;
  final int? directionId;
  final ServiceDate? serviceDate;

  // Champs aplatis conservés pour les appels existants de l'application.
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
  final ScheduleProvenance? provenance;

  // --- Lot 4.14 : ETA universelle ---
  final EtaSource? etaSource;
  final DateTime? etaAt;
  final double? etaConfidence;
  final String? calculationMethod;
  final OperationalEvidence? operationalEvidence;
  final DateTime? realtimeValidUntil;

  DepartureInfo._({
    required this.status,
    required this.operator,
    required this.routeId,
    required this.sourceType,
    this.referenceTime,
    this.estimatedWaitFrom,
    this.estimatedWaitTo,
    this.scheduledTime,
    this.nextDepartureAt,
    this.calculatedAt,
    this.observedAt,
    this.stopId,
    this.stopSequence,
    this.tripId,
    this.directionId,
    this.serviceDate,
    this.source,
    this.dateSource,
    this.dateVerified,
    this.validFrom,
    this.validTo,
    this.confidence,
    this.frequencyMinutes,
    this.operatingHours,
    this.direction,
    this.provenance,
    this.etaSource,
    this.etaAt,
    this.etaConfidence,
    this.calculationMethod,
    this.operationalEvidence,
    this.realtimeValidUntil,
  });

  /// Aucun départ exact n'est connu. Les éventuelles métadonnées de source ne
  /// donnent pas le droit d'afficher une heure.
  factory DepartureInfo.unknown({
    required String operator,
    required String routeId,
    FrequencySource? source,
    ScheduleProvenance? provenance,
    DateTime? requestedAt,
    String? stopId,
    int? stopSequence,
    String? tripId,
    int? directionId,
    ServiceDate? serviceDate,
  }) {
    final DateTime? instant = requestedAt?.toUtc();
    return DepartureInfo._(
      status: ScheduleStatus.unknown,
      operator: operator,
      routeId: routeId,
      stopId: stopId,
      stopSequence: stopSequence,
      tripId: tripId,
      directionId: directionId,
      serviceDate: serviceDate ?? (instant == null ? null : ServiceDate.fromInstant(instant)),
      referenceTime: instant,
      calculatedAt: instant,
      source: source?.source ?? provenance?.source,
      sourceType: source?.sourceType ?? provenance?.sourceType ?? SourceType.unknown,
      dateSource: source?.dateSource ?? provenance?.dateSource?.toString(),
      dateVerified: source?.dateVerified ?? provenance?.dateVerified?.toString(),
      validFrom: source?.validFrom ?? provenance?.validFrom?.toString(),
      validTo: source?.validTo ?? provenance?.validTo?.toString(),
      confidence: source?.confidence ?? provenance?.confidence,
      frequencyMinutes: null,
      operatingHours: null,
      direction: null,
      provenance: provenance,
    );
  }

  /// Construit un horaire publié seulement depuis un Trip, son StopTime actif
  /// et une provenance dont date, validité et couverture sont vérifiées.
  factory DepartureInfo.scheduled({
    required ScheduleDataset dataset,
    required Trip trip,
    required StopTime stopTime,
    required Service service,
    required ServiceDate serviceDate,
    required ScheduleProvenance provenance,
    required DateTime calculatedAt,
    String operator = 'Inconnu',
  }) {
    if (dataset.validationErrors.isNotEmpty ||
        !identical(dataset.provenance, provenance) ||
        !dataset.containsTripIdentity(trip) ||
        !dataset.containsStopTimeIdentity(stopTime) ||
        !dataset.containsServiceIdentity(service)) {
      throw ArgumentError(
        'Le trip, stop_time, service et provenance doivent provenir du même dataset',
      );
    }
    if (trip.serviceId != service.serviceId) {
      throw ArgumentError('Le service ne correspond pas au trip');
    }
    if (stopTime.tripId != trip.tripId || stopTime.stopSequence <= 0) {
      throw ArgumentError('Le stop_time ne correspond pas au trip ou à sa séquence');
    }
    if (!service.isActiveOn(serviceDate)) {
      throw ArgumentError('Le calendrier du trip est inactif à $serviceDate');
    }
    final ServiceTime? departureTime = stopTime.departureTime;
    if (departureTime == null) {
      throw ArgumentError('Un départ SCHEDULED exige departureTime');
    }
    final DateTime calculatedAtUtc = calculatedAt.toUtc();
    if (!provenance.isValidScheduleFor(
          serviceDate: serviceDate,
          routeId: trip.routeId,
          stopId: stopTime.stopId,
          directionId: trip.directionId,
        ) ||
        !provenance.hasCompleteCoverageFor(
          serviceDate: serviceDate,
          routeId: trip.routeId,
          stopId: stopTime.stopId,
          directionId: trip.directionId,
        ) ||
        provenance.dateVerified!.isAfter(ServiceDate.fromInstant(calculatedAtUtc))) {
      throw ArgumentError('La provenance horaire ne couvre pas complètement ce départ');
    }

    final DateTime departureAt = departureTime.toInstant(serviceDate);
    if (departureAt.isBefore(calculatedAtUtc)) {
      throw ArgumentError('Un départ SCHEDULED ne peut pas être déjà passé');
    }
    return DepartureInfo._(
      status: ScheduleStatus.scheduled,
      operator: operator,
      routeId: trip.routeId,
      stopId: stopTime.stopId,
      stopSequence: stopTime.stopSequence,
      tripId: trip.tripId,
      directionId: trip.directionId,
      serviceDate: serviceDate,
      referenceTime: calculatedAtUtc,
      calculatedAt: calculatedAtUtc,
      scheduledTime: departureAt,
      nextDepartureAt: departureAt,
      source: provenance.source,
      sourceType: provenance.sourceType,
      dateSource: provenance.dateSource?.toString(),
      dateVerified: provenance.dateVerified?.toString(),
      validFrom: provenance.validFrom?.toString(),
      validTo: provenance.validTo?.toString(),
      confidence: provenance.confidence,
      frequencyMinutes: null,
      operatingHours: null,
      direction: trip.headsign,
      provenance: provenance,
      etaSource: EtaSource.schedule,
      etaAt: departureAt,
      etaConfidence: provenance.confidence,
      calculationMethod: 'SCHEDULE',
    );
  }

  /// Construit une prédiction fraîche et reliée au même trip et stop. La
  /// vérification des clés demandées est également effectuée par le moteur.
  factory DepartureInfo.realTime({
    required ScheduleDataset dataset,
    required RealtimePrediction prediction,
    required Trip trip,
    required StopTime stopTime,
    required Service service,
    required DateTime now,
    required Duration maxAge,
    String operator = 'Inconnu',
  }) {
    if (dataset.validationErrors.isNotEmpty ||
        !dataset.containsTripIdentity(trip) ||
        !dataset.containsStopTimeIdentity(stopTime) ||
        !dataset.containsServiceIdentity(service)) {
      throw ArgumentError('Le trip, stop_time et service doivent provenir du même dataset');
    }
    if (prediction.routeId != trip.routeId || prediction.tripId != trip.tripId) {
      throw ArgumentError('La prédiction temps réel ne correspond pas au trip');
    }
    final ScheduleProvenance? staticProvenance = dataset.provenance;
    if (staticProvenance == null ||
        !staticProvenance.isValidScheduleFor(
          serviceDate: prediction.serviceDate,
          routeId: trip.routeId,
          stopId: stopTime.stopId,
          directionId: prediction.directionId,
        ) ||
        !staticProvenance.hasCompleteCoverageFor(
          serviceDate: prediction.serviceDate,
          routeId: trip.routeId,
          stopId: stopTime.stopId,
          directionId: prediction.directionId,
        ) ||
        staticProvenance.dateVerified!.isAfter(ServiceDate.fromInstant(now))) {
      throw ArgumentError('La grille ne prouve pas une couverture complète et valide du trip');
    }
    if (stopTime.tripId != trip.tripId ||
        stopTime.stopId != prediction.stopId ||
        stopTime.stopSequence != prediction.stopSequence) {
      throw ArgumentError('La prédiction temps réel ne correspond pas au stop_time exact');
    }
    if (trip.directionId != null && trip.directionId != prediction.directionId) {
      throw ArgumentError('Le sens de la prédiction temps réel ne correspond pas au trip');
    }
    if (service.serviceId != trip.serviceId || !service.isActiveOn(prediction.serviceDate)) {
      throw ArgumentError('Le service du trip est inactif ou ne correspond pas');
    }
    if (!prediction.isFreshAt(now, maxAge)) {
      throw ArgumentError('La prédiction temps réel est périmée ou déjà passée');
    }

    final DateTime nowUtc = now.toUtc();
    final DateTime? scheduledAt = stopTime.departureTime?.toInstant(prediction.serviceDate);
    return DepartureInfo._(
      status: ScheduleStatus.realTime,
      operator: operator,
      routeId: prediction.routeId,
      stopId: prediction.stopId,
      stopSequence: prediction.stopSequence,
      tripId: prediction.tripId,
      directionId: prediction.directionId,
      serviceDate: prediction.serviceDate,
      referenceTime: nowUtc,
      calculatedAt: nowUtc,
      observedAt: prediction.observedAt,
      scheduledTime: scheduledAt,
      nextDepartureAt: prediction.predictedDepartureAt,
      source: prediction.provenance.source,
      sourceType: prediction.provenance.sourceType,
      dateSource: prediction.provenance.dateSource?.toString(),
      dateVerified: prediction.provenance.dateVerified?.toString(),
      validFrom: prediction.provenance.validFrom?.toString(),
      validTo: prediction.provenance.validTo?.toString(),
      confidence: prediction.provenance.confidence,
      frequencyMinutes: null,
      operatingHours: null,
      direction: trip.headsign,
      provenance: prediction.provenance,
      etaSource: EtaSource.realTime,
      etaAt: prediction.predictedDepartureAt,
      etaConfidence: prediction.provenance.confidence,
      calculationMethod: 'REAL_TIME',
      realtimeValidUntil: prediction.observedAt.add(maxAge),
    );
  }

  /// Une estimation de fréquence ne contient aucune heure exacte.
  factory DepartureInfo.fromFrequency(
    FrequencySource source,
    FrequencyWindow window,
    DateTime requestedAt, {
    String? stopId,
    int? directionId,
    ServiceDate? serviceDate,
    bool isPublicHoliday = false,
  }) {
    if (source.status != ScheduleStatus.estimated) {
      throw ArgumentError('Une fréquence ne peut produire que ESTIMATED');
    }
    if (source.source.trim().isEmpty || source.dateVerified.trim().isEmpty) {
      throw ArgumentError('Une fréquence ESTIMATED exige une source et une date de vérification');
    }
    if (directionId != null) {
      throw ArgumentError('Une fréquence sans direction_id ne peut pas affirmer un sens GTFS');
    }
    if (window.frequencyMinutes <= 0) {
      throw ArgumentError.value(window.frequencyMinutes, 'frequencyMinutes');
    }
    if (!source.frequencies.contains(window) ||
        !window.appliesAt(requestedAt, isPublicHoliday: isPublicHoliday)) {
      throw ArgumentError('La fréquence ne s’applique pas à cette source et à cet instant');
    }
    final DateTime dakarInstant = requestedAt.toUtc();
    if (serviceDate != null && serviceDate != ServiceDate.fromInstant(dakarInstant)) {
      throw ArgumentError('Une fréquence ne valide que la date civile demandée');
    }
    return DepartureInfo._(
      status: ScheduleStatus.estimated,
      operator: source.operator,
      routeId: source.routeId,
      stopId: stopId,
      directionId: directionId,
      serviceDate: serviceDate ?? ServiceDate.fromInstant(dakarInstant),
      referenceTime: dakarInstant,
      calculatedAt: dakarInstant,
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
      scheduledTime: null,
      nextDepartureAt: null,
      observedAt: null,
      provenance: null,
      etaSource: null,
      etaAt: null,
      etaConfidence: null,
      calculationMethod: null,
    );
  }

  /// Lot 4.14 — ETA calculée pour une fréquence lorsque des données suffisantes
  /// existent (fenêtre, calendrier, historique, temps de parcours, GPS).
  /// Le statut reste ESTIMATED pour conserver la traçabilité, mais l'ETA est
  /// fournie via [etaAt]/[etaSource] et permet l'affichage `🟢 X min`.
  factory DepartureInfo.estimatedWithEta({
    required FrequencySource source,
    required FrequencyWindow window,
    required DateTime requestedAt,
    required DateTime etaAt,
    required EtaSource etaSource,
    String? calculationMethod,
    double? etaConfidence,
    String? stopId,
    int? directionId,
    ServiceDate? serviceDate,
    bool isPublicHoliday = false,
  }) {
    if (source.status != ScheduleStatus.estimated ||
        !source.frequencies.contains(window) ||
        !window.appliesAt(requestedAt, isPublicHoliday: isPublicHoliday) ||
        source.source.trim().isEmpty || source.dateVerified.trim().isEmpty ||
        etaSource == EtaSource.schedule || etaSource == EtaSource.realTime ||
        (calculationMethod?.trim().isEmpty ?? true)) {
      throw ArgumentError('Une ETA estimée exige fréquence applicable, source et méthode de calcul explicites');
    }
    final DateTime dakarInstant = requestedAt.toUtc();
    final DateTime etaUtc = etaAt.toUtc();
    if (etaUtc.isBefore(dakarInstant)) {
      throw ArgumentError('L’ETA calculée ne peut pas être dans le passé');
    }
    return DepartureInfo._(
      status: ScheduleStatus.estimated,
      operator: source.operator,
      routeId: source.routeId,
      stopId: stopId,
      directionId: directionId,
      serviceDate: serviceDate ?? ServiceDate.fromInstant(dakarInstant),
      referenceTime: dakarInstant,
      calculatedAt: dakarInstant,
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
      scheduledTime: null,
      nextDepartureAt: etaUtc, // permet remainingLabelAt uniforme
      observedAt: null,
      provenance: null,
      etaSource: etaSource,
      etaAt: etaUtc,
      etaConfidence: etaConfidence ?? source.confidence,
      calculationMethod: calculationMethod ?? etaSource.name,
    );
  }

  /// Copie avec ETA calculée — utilisée par EtaCalculator sans dupliquer le moteur.
  DepartureInfo withCalculatedEta({
    required DateTime etaAt,
    required EtaSource etaSource,
    String? calculationMethod,
    double? etaConfidence,
  }) {
    final DateTime etaUtc = etaAt.toUtc();
    if (status != ScheduleStatus.estimated ||
        etaSource == EtaSource.schedule || etaSource == EtaSource.realTime ||
        (calculationMethod?.trim().isEmpty ?? true) ||
        etaUtc.isBefore((calculatedAt ?? referenceTime)?.toUtc() ?? etaUtc)) {
      throw ArgumentError('ETA calculée : ancrage estimé et méthode explicite requis');
    }
    return DepartureInfo._(
      status: status,
      operator: operator,
      routeId: routeId,
      stopId: stopId,
      stopSequence: stopSequence,
      tripId: tripId,
      directionId: directionId,
      serviceDate: serviceDate,
      referenceTime: referenceTime,
      calculatedAt: calculatedAt,
      estimatedWaitFrom: estimatedWaitFrom,
      estimatedWaitTo: estimatedWaitTo,
      scheduledTime: scheduledTime,
      nextDepartureAt: etaUtc,
      observedAt: observedAt,
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
      provenance: provenance,
      etaSource: etaSource,
      etaAt: etaUtc,
      etaConfidence: etaConfidence ?? confidence,
      calculationMethod: calculationMethod ?? etaSource.name,
      operationalEvidence: operationalEvidence,
      realtimeValidUntil: realtimeValidUntil,
    );
  }

  /// État à l'instant consulté : la prédiction temps réel fraîche appariée au
  /// passage théorique prouve un retard si elle est strictement postérieure.
  /// Sans ETA ni preuve d'incident, l'état reste inconnu (null), jamais rouge.
  OperationalStatus? operationalStatusAt(DateTime at) {
    if (operationalEvidence != null && operationalEvidence!.isValidAt(at)) {
      return operationalEvidence!.status;
    }
    if (realtimeValidUntil != null && at.toUtc().isAfter(realtimeValidUntil!)) {
      return null;
    }
    final target = etaAt ?? nextDepartureAt;
    if (target == null || target.isBefore(at.toUtc()) ||
        status == ScheduleStatus.unknown) return null;
    if (status == ScheduleStatus.realTime && scheduledTime != null &&
        target.isAfter(scheduledTime!)) return OperationalStatus.delayed;
    return OperationalStatus.normal;
  }

  OperationalStatus? get operationalStatus =>
      operationalStatusAt(calculatedAt ?? referenceTime ?? operationalEvidence?.observedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

  /// Seule une preuve explicite, fraîche et rattachée à la même ligne peut
  /// signaler une suspension. Aucune source d'alerte n'est simulée par l'app.
  DepartureInfo withOperationalEvidence(OperationalEvidence evidence, DateTime at) {
    if (evidence.routeId != routeId || !evidence.isValidAt(at) ||
        (evidence.status == OperationalStatus.delayed && etaAt == null)) {
      throw ArgumentError('Preuve opérationnelle non applicable au départ');
    }
    return DepartureInfo._(
      status: status, operator: operator, routeId: routeId,
      stopId: stopId, stopSequence: stopSequence, tripId: tripId,
      directionId: directionId, serviceDate: serviceDate,
      referenceTime: referenceTime, estimatedWaitFrom: estimatedWaitFrom,
      estimatedWaitTo: estimatedWaitTo, scheduledTime: scheduledTime,
      nextDepartureAt: nextDepartureAt, calculatedAt: calculatedAt,
      observedAt: observedAt, source: source, sourceType: sourceType,
      dateSource: dateSource, dateVerified: dateVerified,
      validFrom: validFrom, validTo: validTo, confidence: confidence,
      frequencyMinutes: frequencyMinutes, operatingHours: operatingHours,
      direction: direction, provenance: provenance, etaSource: etaSource,
      etaAt: etaAt, etaConfidence: etaConfidence,
      calculationMethod: calculationMethod, operationalEvidence: evidence,
      realtimeValidUntil: realtimeValidUntil,
    );
  }

  bool get serviceActive =>
      status == ScheduleStatus.scheduled ||
      status == ScheduleStatus.realTime ||
      status == ScheduleStatus.estimated;

  /// Nombre de secondes restant, recalculé au moment de l'affichage.
  /// Une heure passée n'est jamais rendue comme compte à rebours négatif.
  int? remainingSecondsAt(DateTime now) {
    final DateTime? target = nextDepartureAt;
    if (target == null) return null;
    final int microseconds = target.toUtc().difference(now.toUtc()).inMicroseconds;
    if (microseconds < 0) return null;
    if (microseconds == 0) return 0;
    return (microseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// Minutes d'affichage arrondies vers le haut ; ce n'est pas un champ stocké.
  int? remainingMinutesAt(DateTime now) {
    final int? seconds = remainingSecondsAt(now);
    if (seconds == null) return null;
    if (seconds == 0) return 0;
    return (seconds + Duration.secondsPerMinute - 1) ~/ Duration.secondsPerMinute;
  }

  String? remainingLabelAt(DateTime now) {
    final int? seconds = remainingSecondsAt(now);
    if (seconds == null) return null;
    if (seconds == 0) return 'Départ maintenant';
    if (seconds < Duration.secondsPerMinute) return 'Départ dans $seconds s';
    return 'Départ dans ${remainingMinutesAt(now)} min';
  }

  // --- Lot 4.14 : ETA universelle ---
  /// ETA cible : prioritairement etaAt/nextDepartureAt, sinon scheduledTime.
  DateTime? get _etaTarget => etaAt ?? nextDepartureAt ?? scheduledTime;

  int? etaRemainingSecondsAt(DateTime now) {
    final DateTime? target = _etaTarget;
    if (target == null) return null;
    final int micros = target.toUtc().difference(now.toUtc()).inMicroseconds;
    if (micros < 0) return null;
    if (micros == 0) return 0;
    return (micros + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond;
  }

  /// Valeur instantanée dérivée (jamais une durée issue de la fréquence).
  int? get etaMinutes {
    final instant = calculatedAt ?? referenceTime;
    return instant == null ? null : etaMinutesAt(instant);
  }

  int? etaMinutesAt(DateTime now) {
    final int? seconds = etaRemainingSecondsAt(now);
    if (seconds == null) return null;
    if (seconds == 0) return 0;
    return (seconds + 59) ~/ 60;
  }

  /// Libellé universel `X min` / `Maintenant` — utilisé par l'UI Lot 4.14.
  /// Retourne null si aucune ETA défendable.
  String? etaLabelAt(DateTime now) {
    final int? minutes = etaMinutesAt(now);
    if (minutes == null) return null;
    if (minutes == 0) return 'Maintenant';
    return '$minutes min';
  }

  /// Vrai si une ETA chiffrée est disponible et non passée.
  bool get hasEta => _etaTarget != null;

  /// Compatibilité : jamais de fenêtre transformée en compte à rebours.
  /// Le libellé destiné à l'interface est DeparturePresentation, avec l'instant
  /// de consultation explicite et le calcul unique dans EtaCalculator.
  String get label => 'Passage non communiqué';
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
