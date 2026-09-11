enum DataTrust { official, fieldObservation, estimated }

extension DataTrustExtension on DataTrust {
  String toLabel() {
    switch (this) {
      case DataTrust.official:
        return 'OFFICIAL';
      case DataTrust.fieldObservation:
        return 'FIELD_OBSERVATION';
      case DataTrust.estimated:
        return 'ESTIMATED';
    }
  }

  static DataTrust fromString(String value) {
    switch (value) {
      case 'OFFICIAL':
        return DataTrust.official;
      case 'FIELD_OBSERVATION':
        return DataTrust.fieldObservation;
      default:
        return DataTrust.estimated;
    }
  }
}

class Operator {
  final String id;
  final String name;
  final String colorHex;

  Operator({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  factory Operator.fromJson(Map<String, dynamic> json) {
    return Operator(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['color'] as String,
    );
  }
}

class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DataTrust dataTrust;

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.dataTrust,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      dataTrust: DataTrustExtension.fromString(json['data_trust'] as String),
    );
  }
}

class TransportRoute {
  final String id;
  final String operatorId;
  final String shortName;
  final String longName;
  final String type;
  final DataTrust dataTrust;
  final List<String> stopIds;

  TransportRoute({
    required this.id,
    required this.operatorId,
    required this.shortName,
    required this.longName,
    required this.type,
    required this.dataTrust,
    required this.stopIds,
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
    );
  }
}
