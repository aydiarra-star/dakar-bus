import 'dart:convert';
import 'package:flutter/services.dart';

/// Niveau de fiabilité de la donnée — champ HISTORIQUE `data_trust`.
///
/// Conservé pour compatibilité. Depuis l'audit du 2026-09-24, la provenance
/// fait foi via [Provenance] (`data_status` + `source_type` + `source` +
/// `verified_at`). `unverified` a été ajouté : une donnée autrefois marquée
/// OFFICIAL sans aucune source traçable n'est plus présentée comme officielle.
enum DataTrust { official, fieldObservation, estimated, unverified }

extension DataTrustExtension on DataTrust {
  String toLabel() {
    switch (this) {
      case DataTrust.official:
        return 'OFFICIAL';
      case DataTrust.fieldObservation:
        return 'FIELD_OBSERVATION';
      case DataTrust.estimated:
        return 'ESTIMATED';
      case DataTrust.unverified:
        return 'UNVERIFIED';
    }
  }

  /// Valeur inconnue → [DataTrust.unverified] (auparavant `estimated`) :
  /// une valeur non reconnue ne doit jamais devenir une estimation implicite.
  static DataTrust fromString(String value) {
    switch (value) {
      case 'OFFICIAL':
        return DataTrust.official;
      case 'FIELD_OBSERVATION':
        return DataTrust.fieldObservation;
      case 'ESTIMATED':
        return DataTrust.estimated;
      case 'UNVERIFIED':
        return DataTrust.unverified;
      default:
        return DataTrust.unverified;
    }
  }
}

/// Statut de vérification d'une donnée (`data_status`).
///
/// Nommé `ProvenanceStatus` pour ne pas entrer en collision avec l'enum
/// `DataStatus` (live/scheduled/…) déclaré dans `main.dart`.
enum ProvenanceStatus { confirmed, unverified, conflicting, future }

extension ProvenanceStatusLabel on ProvenanceStatus {
  String toLabel() {
    switch (this) {
      case ProvenanceStatus.confirmed:
        return 'CONFIRMED';
      case ProvenanceStatus.unverified:
        return 'UNVERIFIED';
      case ProvenanceStatus.conflicting:
        return 'CONFLICTING';
      case ProvenanceStatus.future:
        return 'FUTURE';
    }
  }

  /// Absent ou inconnu → `unverified` (jamais `confirmed` par défaut).
  static ProvenanceStatus fromString(String? value) {
    switch (value) {
      case 'CONFIRMED':
        return ProvenanceStatus.confirmed;
      case 'CONFLICTING':
        return ProvenanceStatus.conflicting;
      case 'FUTURE':
        return ProvenanceStatus.future;
      default:
        return ProvenanceStatus.unverified;
    }
  }
}

/// Nature de la source (`source_type`).
enum SourceType {
  officialStatic,
  officialRealtime,
  operatorRealtime,
  estimated,
  community,
  fieldObservation,
  unknown,
}

extension SourceTypeLabel on SourceType {
  String toLabel() {
    switch (this) {
      case SourceType.officialStatic:
        return 'OFFICIAL_STATIC';
      case SourceType.officialRealtime:
        return 'OFFICIAL_REALTIME';
      case SourceType.operatorRealtime:
        return 'OPERATOR_REALTIME';
      case SourceType.estimated:
        return 'ESTIMATED';
      case SourceType.community:
        return 'COMMUNITY';
      case SourceType.fieldObservation:
        return 'FIELD_OBSERVATION';
      case SourceType.unknown:
        return 'UNKNOWN';
    }
  }

  /// Absent ou inconnu → `unknown`.
  static SourceType fromString(String? value) {
    switch (value) {
      case 'OFFICIAL_STATIC':
        return SourceType.officialStatic;
      case 'OFFICIAL_REALTIME':
        return SourceType.officialRealtime;
      case 'OPERATOR_REALTIME':
        return SourceType.operatorRealtime;
      case 'ESTIMATED':
        return SourceType.estimated;
      case 'COMMUNITY':
        return SourceType.community;
      case 'FIELD_OBSERVATION':
        return SourceType.fieldObservation;
      default:
        return SourceType.unknown;
    }
  }
}

/// Statut d'horaire (`schedule_status`) — préparé, non affiché par l'UI.
///
/// * `scheduled` : horaire théorique publié par une source officielle ;
/// * `realTime`  : UNIQUEMENT avec un flux officiel ou opérateur réel ;
/// * `estimated` : estimation — ne doit JAMAIS être présentée comme temps réel ;
/// * `unknown`   : aucune donnée → « Horaire indisponible ».
///
/// `dakar_network.json` ne contient aucun horaire : toutes les routes sont
/// `unknown`.
enum ScheduleStatus { scheduled, realTime, estimated, unknown }

extension ScheduleStatusLabel on ScheduleStatus {
  String toLabel() {
    switch (this) {
      case ScheduleStatus.scheduled:
        return 'SCHEDULED';
      case ScheduleStatus.realTime:
        return 'REAL_TIME';
      case ScheduleStatus.estimated:
        return 'ESTIMATED';
      case ScheduleStatus.unknown:
        return 'UNKNOWN';
    }
  }

  /// Libellé utilisateur. `estimated` n'emploie jamais « temps réel ».
  String displayLabel() {
    switch (this) {
      case ScheduleStatus.scheduled:
        return 'Horaire théorique';
      case ScheduleStatus.realTime:
        return 'Temps réel';
      case ScheduleStatus.estimated:
        return 'Estimation';
      case ScheduleStatus.unknown:
        return 'Horaire indisponible';
    }
  }

  /// Absent ou inconnu → `unknown`.
  static ScheduleStatus fromString(String? value) {
    switch (value) {
      case 'SCHEDULED':
        return ScheduleStatus.scheduled;
      case 'REAL_TIME':
        return ScheduleStatus.realTime;
      case 'ESTIMATED':
        return ScheduleStatus.estimated;
      default:
        return ScheduleStatus.unknown;
    }
  }
}

/// Provenance d'un arrêt ou d'une route.
///
/// Règle : `CONFIRMED` exige une source ET une date de vérification. Une
/// entrée `CONFIRMED` sans l'une ou l'autre est lue comme `UNVERIFIED` — une
/// donnée ne devient pas confirmée parce qu'un développeur l'a écrit.
class Provenance {
  final ProvenanceStatus status;
  final SourceType sourceType;
  final String? source;
  final String? sourceUrl;
  final String? verifiedAt;
  final String? auditNote;

  const Provenance({
    required this.status,
    required this.sourceType,
    this.source,
    this.sourceUrl,
    this.verifiedAt,
    this.auditNote,
  });

  /// Aucune information de provenance : UNVERIFIED / UNKNOWN.
  const Provenance.unknown()
      : status = ProvenanceStatus.unverified,
        sourceType = SourceType.unknown,
        source = null,
        sourceUrl = null,
        verifiedAt = null,
        auditNote = null;

  factory Provenance.fromJson(Map<String, dynamic> json) {
    final String? source = json['source'] as String?;
    final String? verifiedAt = json['verified_at'] as String?;
    ProvenanceStatus status =
        ProvenanceStatusLabel.fromString(json['data_status'] as String?);
    if (status == ProvenanceStatus.confirmed &&
        (source == null || verifiedAt == null)) {
      status = ProvenanceStatus.unverified;
    }
    return Provenance(
      status: status,
      sourceType: SourceTypeLabel.fromString(json['source_type'] as String?),
      source: source,
      sourceUrl: json['source_url'] as String?,
      verifiedAt: verifiedAt,
      auditNote: json['audit_note'] as String?,
    );
  }

  bool get isConfirmed => status == ProvenanceStatus.confirmed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'data_status': status.toLabel(),
        'source_type': sourceType.toLabel(),
        'source': source,
        'verified_at': verifiedAt,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (auditNote != null) 'audit_note': auditNote,
      };
}

class Operator {
  final String id;
  final String name;
  final String colorHex;

  /// Nombre de lignes annoncé par une source officielle (ex. CETUD : DDD 38,
  /// AFTU 72). `null` = aucun total officiel connu. Indépendant du nombre de
  /// routes présentes dans le jeu de données.
  final int? officialLineCount;
  final String? officialLineCountSource;

  Operator({
    required this.id,
    required this.name,
    required this.colorHex,
    this.officialLineCount,
    this.officialLineCountSource,
  });

  factory Operator.fromJson(Map<String, dynamic> json) {
    return Operator(
      id: json['id'] as String,
      name: json['name'] as String,
      // JSON utilise "color", modèle utilise "colorHex"
      colorHex: json['color'] as String,
      officialLineCount: (json['official_line_count'] as num?)?.toInt(),
      officialLineCountSource: json['official_line_count_source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorHex,
        'official_line_count': officialLineCount,
        'official_line_count_source': officialLineCountSource,
      };
}

class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DataTrust dataTrust;

  /// Provenance de l'arrêt (absente → UNVERIFIED / UNKNOWN).
  final Provenance provenance;

  /// Lieu physique. Plusieurs arrêts réseau (ex. station BRT et arrêt de bus
  /// homonyme) peuvent partager le même `placeId` tout en gardant leur `id`.
  final String? placeId;

  /// Fiabilité des coordonnées, distincte de celle de l'existence de l'arrêt.
  final ProvenanceStatus coordinatesStatus;

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.dataTrust,
    this.provenance = const Provenance.unknown(),
    this.placeId,
    this.coordinatesStatus = ProvenanceStatus.unverified,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      dataTrust: DataTrustExtension.fromString(json['data_trust'] as String),
      provenance: Provenance.fromJson(json),
      placeId: json['place_id'] as String?,
      coordinatesStatus: ProvenanceStatusLabel.fromString(
          json['coordinates_status'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'data_trust': dataTrust.toLabel(),
        ...provenance.toJson(),
        'coordinates_status': coordinatesStatus.toLabel(),
        if (placeId != null) 'place_id': placeId,
      };
}

class TransportRoute {
  final String id;
  final String operatorId;
  final String shortName;
  final String longName;
  final String type;
  final DataTrust dataTrust;
  final List<String> stopIds;

  /// Provenance de l'itinéraire (absente → UNVERIFIED / UNKNOWN).
  final Provenance provenance;

  /// Aucun horaire n'est fourni par le jeu de données → `unknown`.
  final ScheduleStatus scheduleStatus;

  /// `false` : la route ne fait pas partie du total officiel de l'opérateur
  /// (ex. lignes candidates new_commune_*). `null` : non renseigné.
  final bool? countsTowardOfficialTotal;

  /// Anomalies détectées par l'audit (ex. ITINERARY_GEOGRAPHICALLY_INCOHERENT).
  final List<String> auditFlags;

  TransportRoute({
    required this.id,
    required this.operatorId,
    required this.shortName,
    required this.longName,
    required this.type,
    required this.dataTrust,
    required this.stopIds,
    this.provenance = const Provenance.unknown(),
    this.scheduleStatus = ScheduleStatus.unknown,
    this.countsTowardOfficialTotal,
    this.auditFlags = const <String>[],
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    return TransportRoute(
      id: json['id'] as String,
      operatorId: json['operator_id'] as String,
      shortName: json['short_name'] as String,
      longName: json['long_name'] as String,
      type: json['type'] as String,
      dataTrust: DataTrustExtension.fromString(json['data_trust'] as String),
      stopIds: List<String>.from(json['stops'] as List),
      provenance: Provenance.fromJson(json),
      scheduleStatus:
          ScheduleStatusLabel.fromString(json['schedule_status'] as String?),
      countsTowardOfficialTotal: json['counts_toward_official_total'] as bool?,
      auditFlags: json['audit_flags'] == null
          ? const <String>[]
          : List<String>.from(json['audit_flags'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'operator_id': operatorId,
        'short_name': shortName,
        'long_name': longName,
        'type': type,
        'data_trust': dataTrust.toLabel(),
        ...provenance.toJson(),
        'schedule_status': scheduleStatus.toLabel(),
        if (countsTowardOfficialTotal != null)
          'counts_toward_official_total': countsTowardOfficialTotal,
        if (auditFlags.isNotEmpty) 'audit_flags': auditFlags,
        'stops': stopIds,
      };
}

/// Wrapper complet du réseau - utile pour charger dakar_network.json d'un coup
class TransportNetwork {
  final List<Operator> operators;
  final List<BusStop> stops;
  final List<TransportRoute> routes;

  TransportNetwork({
    required this.operators,
    required this.stops,
    required this.routes,
  });

  factory TransportNetwork.fromJson(Map<String, dynamic> json) {
    return TransportNetwork(
      operators: (json['operators'] as List)
          .map((e) => Operator.fromJson(e as Map<String, dynamic>))
          .toList(),
      stops: (json['stops'] as List)
          .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
          .toList(),
      routes: (json['routes'] as List)
          .map((e) => TransportRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Charge depuis assets/data/dakar_network.json
  static Future<TransportNetwork> loadFromAssets() async {
    final jsonString =
        await rootBundle.loadString('assets/data/dakar_network.json');
    final Map<String, dynamic> decoded =
        json.decode(jsonString) as Map<String, dynamic>;
    return TransportNetwork.fromJson(decoded);
  }

  // Helpers
  Operator? operatorById(String id) {
    try {
      return operators.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  BusStop? stopById(String id) {
    try {
      return stops.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BusStop> stopsForRoute(TransportRoute route) {
    return route.stopIds
        .map((id) => stopById(id))
        .whereType<BusStop>()
        .toList();
  }
}
