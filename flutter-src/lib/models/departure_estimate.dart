import 'transport_network.dart';

/// MOTEUR COMMUN DE DÉPARTS — modèle (2026-09-25).
///
/// Répond à « Quel transport puis-je prendre maintenant et quand puis-je
/// partir ? » avec exactement quatre statuts, déjà définis dans
/// [ScheduleStatus] : `scheduled`, `estimated`, `realTime`, `unknown`.
///
/// Règles portées par ce fichier :
///  * une valeur inconnue reste `null` — aucun champ n'est complété par une
///    valeur fictive pour « faire joli » ;
///  * une estimation porte une FENÊTRE (`estimatedFrom` → `estimatedTo`),
///    jamais une heure de départ précise ;
///  * une fréquence n'est jamais du temps réel ; un GPS utilisateur n'est
///    jamais un véhicule ;
///  * aucune donnée HISTORICAL / UNKNOWN / simulée ne produit de service.
///
/// Ce modèle est le miroir Dart de `engine/departure-engine.js` : les deux
/// applications partagent les mêmes règles et le même référentiel de
/// fréquences (`assets/data/departure-frequencies.json`).

/// Type de source admis (§16).
enum DepartureSourceType {
  official,
  institutional,
  openData,
  community,
  historical,
  unknown,
}

extension DepartureSourceTypeCode on DepartureSourceType {
  String get code {
    switch (this) {
      case DepartureSourceType.official:
        return 'OFFICIAL';
      case DepartureSourceType.institutional:
        return 'INSTITUTIONAL';
      case DepartureSourceType.openData:
        return 'OPEN_DATA';
      case DepartureSourceType.community:
        return 'COMMUNITY';
      case DepartureSourceType.historical:
        return 'HISTORICAL';
      case DepartureSourceType.unknown:
        return 'UNKNOWN';
    }
  }

  /// Une valeur absente ou non reconnue n'est jamais promue : UNKNOWN.
  static DepartureSourceType fromCode(Object? value) {
    switch (value) {
      case 'OFFICIAL':
        return DepartureSourceType.official;
      case 'INSTITUTIONAL':
        return DepartureSourceType.institutional;
      case 'OPEN_DATA':
        return DepartureSourceType.openData;
      case 'COMMUNITY':
        return DepartureSourceType.community;
      case 'HISTORICAL':
        return DepartureSourceType.historical;
      default:
        return DepartureSourceType.unknown;
    }
  }
}

/// Politique de source : utilisable, confiance, droit de se dire « officiel ».
class DepartureSourcePolicy {
  final DepartureSourceType sourceType;
  final bool usable;
  final String confidence;
  final bool official;
  final bool optIn;

  const DepartureSourcePolicy({
    required this.sourceType,
    required this.usable,
    required this.confidence,
    required this.official,
    this.optIn = false,
  });

  static const Map<DepartureSourceType, String> _confidence =
      <DepartureSourceType, String>{
    DepartureSourceType.official: 'high',
    DepartureSourceType.institutional: 'medium',
    DepartureSourceType.openData: 'medium',
    DepartureSourceType.community: 'low',
    DepartureSourceType.historical: 'none',
    DepartureSourceType.unknown: 'none',
  };

  /// COMMUNITY est utilisable seulement si l'appelant l'autorise, et n'est
  /// jamais officielle. HISTORICAL et UNKNOWN ne servent jamais le présent.
  static DepartureSourcePolicy of(Object? sourceType,
      {bool allowCommunity = false}) {
    final DepartureSourceType type = DepartureSourceTypeCode.fromCode(sourceType);
    switch (type) {
      case DepartureSourceType.official:
        return const DepartureSourcePolicy(
            sourceType: DepartureSourceType.official,
            usable: true,
            confidence: 'high',
            official: true);
      case DepartureSourceType.institutional:
        return const DepartureSourcePolicy(
            sourceType: DepartureSourceType.institutional,
            usable: true,
            confidence: 'medium',
            official: true);
      case DepartureSourceType.openData:
        return const DepartureSourcePolicy(
            sourceType: DepartureSourceType.openData,
            usable: true,
            confidence: 'medium',
            official: false);
      case DepartureSourceType.community:
        return DepartureSourcePolicy(
            sourceType: DepartureSourceType.community,
            usable: allowCommunity,
            confidence: 'low',
            official: false,
            optIn: true);
      case DepartureSourceType.historical:
        return const DepartureSourcePolicy(
            sourceType: DepartureSourceType.historical,
            usable: false,
            confidence: 'none',
            official: false);
      case DepartureSourceType.unknown:
        return const DepartureSourcePolicy(
            sourceType: DepartureSourceType.unknown,
            usable: false,
            confidence: 'none',
            official: false);
    }
  }

  static String confidenceOf(DepartureSourceType type) =>
      _confidence[type] ?? 'none';
}

/// Provenance enregistrée dans le référentiel de fréquences.
class DepartureSource {
  final String id;
  final String? label;
  final DepartureSourceType sourceType;
  final String? url;
  final String? retrievedAt;
  final String? publishedAt;
  final String? validFrom;
  final String? validTo;
  final String? note;

  const DepartureSource({
    required this.id,
    required this.sourceType,
    this.label,
    this.url,
    this.retrievedAt,
    this.publishedAt,
    this.validFrom,
    this.validTo,
    this.note,
  });

  factory DepartureSource.fromJson(Map<String, dynamic> json) => DepartureSource(
        id: json['id'] as String,
        label: json['label'] as String?,
        sourceType: DepartureSourceTypeCode.fromCode(json['source_type']),
        url: json['url'] as String?,
        retrievedAt: json['retrieved_at'] as String?,
        publishedAt: json['published_at'] as String?,
        validFrom: json['valid_from'] as String?,
        validTo: json['valid_to'] as String?,
        note: json['note'] as String?,
      );
}

/// Fréquence documentée d'une ligne, pour des jours et des périodes précis.
class DepartureFrequency {
  final String id;
  final String network;
  final String lineId;
  final String? stopId;
  final String? direction;
  final List<String> dayTypes;
  final String serviceStart;
  final String serviceEnd;
  final int frequencyMinutes;
  final String status; // ACTIVE | HISTORICAL | PENDING_VERIFICATION
  final String? sourceId;

  const DepartureFrequency({
    required this.id,
    required this.network,
    required this.lineId,
    required this.dayTypes,
    required this.serviceStart,
    required this.serviceEnd,
    required this.frequencyMinutes,
    required this.status,
    this.stopId,
    this.direction,
    this.sourceId,
  });

  factory DepartureFrequency.fromJson(Map<String, dynamic> json) =>
      DepartureFrequency(
        id: json['id'] as String,
        network: json['network'] as String,
        lineId: json['line_id'] as String,
        stopId: json['stop_id'] as String?,
        direction: json['direction'] as String?,
        dayTypes:
            (json['day_types'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[],
        serviceStart: json['service_start'] as String,
        serviceEnd: json['service_end'] as String,
        frequencyMinutes: (json['frequency_minutes'] as num).toInt(),
        status: (json['status'] as String?) ?? 'ACTIVE',
        sourceId: json['source_id'] as String?,
      );
}

/// Référentiel complet (`assets/data/departure-frequencies.json`).
class DepartureRegistry {
  final String schema;
  final String? auditedAt;
  final List<DepartureSource> sources;
  final List<DepartureFrequency> frequencies;
  final Set<String> holidays;

  DepartureRegistry({
    required this.schema,
    required this.sources,
    required this.frequencies,
    this.auditedAt,
    this.holidays = const <String>{},
  });

  factory DepartureRegistry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> holidays =
        (json['holidays'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> dates =
        (holidays['dates'] as List?) ?? const <dynamic>[];
    return DepartureRegistry(
      schema: (json['schema'] as String?) ?? 'inconnu',
      auditedAt: json['audited_at'] as String?,
      sources: ((json['sources'] as List?) ?? const <dynamic>[])
          .map((e) => DepartureSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      frequencies: ((json['frequencies'] as List?) ?? const <dynamic>[])
          .map((e) => DepartureFrequency.fromJson(e as Map<String, dynamic>))
          .toList(),
      holidays: dates.map((e) => e.toString()).toSet(),
    );
  }

  DepartureSource? sourceById(String? id) {
    if (id == null) return null;
    for (final DepartureSource source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  List<DepartureFrequency> frequenciesForLine(String? lineId) {
    if (lineId == null) return const <DepartureFrequency>[];
    return frequencies.where((f) => f.lineId == lineId).toList();
  }
}

/// Objet commun de départ, strictement celui du moteur partagé.
///
/// Toutes les valeurs inconnues sont `null` : un objet d'apparence complète
/// serait un objet faux.
class DepartureEstimate {
  final String? network;
  final String? lineId;
  final String? stopId;
  final String? direction;
  final ScheduleStatus status;
  final String? scheduledTime;
  final String? estimatedFrom;
  final String? estimatedTo;
  final int? frequencyMinutes;
  final String? source;
  final DepartureSourceType? sourceType;
  final String? validFrom;
  final String? validTo;
  final String? observedAt;
  final String? confidence;
  final String? frequencyId;

  /// Instant de référence de l'estimation (« maintenant » au moment du calcul).
  ///
  /// Parité avec `evaluatedAt` du moteur JS : l'affichage et l'assistant
  /// calculent la fenêtre relative par rapport à CET instant, jamais par
  /// rapport à un « maintenant » différent. Sans cela, une estimation produite
  /// à 11:43 réaffichée à 18:00 annoncerait la fenêtre de 18:00.
  final String? evaluatedAt;
  final String? retrievedAt;
  final String? dayType;
  final String? serviceStart;
  final String? serviceEnd;
  final String? vehicleId;
  final String? eventId;
  final String? relative;
  final String? reason;
  final String? note;
  final bool usedSourceIsOfficial;
  final List<String> warnings;

  const DepartureEstimate({
    required this.status,
    this.network,
    this.lineId,
    this.stopId,
    this.direction,
    this.scheduledTime,
    this.estimatedFrom,
    this.estimatedTo,
    this.frequencyMinutes,
    this.source,
    this.sourceType,
    this.validFrom,
    this.validTo,
    this.observedAt,
    this.confidence,
    this.frequencyId,
    this.evaluatedAt,
    this.retrievedAt,
    this.dayType,
    this.serviceStart,
    this.serviceEnd,
    this.vehicleId,
    this.eventId,
    this.relative,
    this.reason,
    this.note,
    this.usedSourceIsOfficial = false,
    this.warnings = const <String>[],
  });

  /// Aucune donnée fiable : c'est la valeur par défaut, jamais une invention.
  const DepartureEstimate.unknown({
    this.network,
    this.lineId,
    this.stopId,
    this.direction,
    this.reason,
    this.note,
    this.evaluatedAt,
  })  : status = ScheduleStatus.unknown,
        scheduledTime = null,
        estimatedFrom = null,
        estimatedTo = null,
        frequencyMinutes = null,
        source = null,
        sourceType = null,
        validFrom = null,
        validTo = null,
        observedAt = null,
        confidence = 'none',
        frequencyId = null,
        retrievedAt = null,
        dayType = null,
        serviceStart = null,
        serviceEnd = null,
        vehicleId = null,
        eventId = null,
        relative = null,
        usedSourceIsOfficial = false,
        warnings = const <String>[];

  bool get isEstimate => status == ScheduleStatus.estimated;
  bool get isRealTime => status == ScheduleStatus.realTime;
  bool get isAvailable => status != ScheduleStatus.unknown;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'network': network,
        'lineId': lineId,
        'stopId': stopId,
        'direction': direction,
        'status': status.toLabel(),
        'scheduledTime': scheduledTime,
        'estimatedFrom': estimatedFrom,
        'estimatedTo': estimatedTo,
        'frequencyMinutes': frequencyMinutes,
        'source': source,
        'sourceType': sourceType?.code,
        'validFrom': validFrom,
        'validTo': validTo,
        'observedAt': observedAt,
        'confidence': confidence,
        'frequencyId': frequencyId,
        'evaluatedAt': evaluatedAt,
        'retrievedAt': retrievedAt,
        'dayType': dayType,
        'serviceStart': serviceStart,
        'serviceEnd': serviceEnd,
        'vehicleId': vehicleId,
        'eventId': eventId,
        'relative': relative,
        'reason': reason,
        'note': note,
        'usedSourceIsOfficial': usedSourceIsOfficial,
        'warnings': warnings,
      };
}

/// Fenêtre d'estimation produite par `estimateNextDepartureFromFrequency`.
class DepartureWindow {
  final ScheduleStatus status;
  final String? estimatedFrom;
  final String? estimatedTo;
  final int? frequencyMinutes;
  final String? relative;
  final String? reason;
  final String? note;

  const DepartureWindow({
    required this.status,
    this.estimatedFrom,
    this.estimatedTo,
    this.frequencyMinutes,
    this.relative,
    this.reason,
    this.note,
  });
}

/// Objet sélectionné par le moteur pour un arrêt, une ligne et un instant.
class DepartureSelection {
  final DepartureFrequency frequency;
  final DepartureSourcePolicy policy;
  final List<String> warnings;

  const DepartureSelection({
    required this.frequency,
    required this.policy,
    this.warnings = const <String>[],
  });
}

/// Libellés d'interface : le composant existant choisit, il ne recalcule rien.
///
/// Aucune heure précise n'est produite pour une estimation.
class DepartureDisplay {
  final ScheduleStatus status;
  final String badge;
  final String title;
  final String headline;
  final String body;
  final String? detail;
  final String? windowLabel;
  final String? trafficNote;
  final bool isOfficial;
  final bool isEstimate;
  final bool isRealTime;
  final bool available;

  const DepartureDisplay({
    required this.status,
    required this.badge,
    required this.title,
    required this.headline,
    required this.body,
    this.detail,
    this.windowLabel,
    this.trafficNote,
    this.isOfficial = false,
    this.isEstimate = false,
    this.isRealTime = false,
    this.available = false,
  });
}

/// Jambe d'itinéraire : la précision ne dépasse jamais celle de la source.
class DepartureLegPlan {
  final ScheduleStatus status;
  final String precision; // EXACT | WINDOW | REALTIME_DEPARTURE_PLUS_ESTIMATED_TRAVEL | NONE
  final String? departureTime;
  final String? arrivalTime;
  final String? departureWindowFrom;
  final String? departureWindowTo;
  final String? arrivalWindowFrom;
  final String? arrivalWindowTo;
  final String? note;

  const DepartureLegPlan({
    required this.status,
    required this.precision,
    this.departureTime,
    this.arrivalTime,
    this.departureWindowFrom,
    this.departureWindowTo,
    this.arrivalWindowFrom,
    this.arrivalWindowTo,
    this.note,
  });
}
