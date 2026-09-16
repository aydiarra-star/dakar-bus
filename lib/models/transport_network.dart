import 'dart:convert';
import 'package:flutter/services.dart';

/// Niveau de fiabilité de la donnée - Aligné avec CETUD/SETER
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
      // JSON utilise "color", modèle utilise "colorHex"
      colorHex: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorHex,
      };
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'data_trust': dataTrust.toLabel(),
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'operator_id': operatorId,
        'short_name': shortName,
        'long_name': longName,
        'type': type,
        'data_trust': dataTrust.toLabel(),
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
