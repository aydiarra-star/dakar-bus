import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/transport_network.dart';

class DataService {
  List<Operator> operators = [];
  List<BusStop> stops = [];
  List<TransportRoute> routes = [];

  Future<void> loadNetworkData() async {
    final String response = await rootBundle.loadString('assets/data/dakar_network.json');
    final data = json.decode(response);

    operators = (data['operators'] as List).map((i) => Operator.fromJson(i)).toList();
    stops = (data['stops'] as List).map((i) => BusStop.fromJson(i)).toList();
    routes = (data['routes'] as List).map((i) => TransportRoute.fromJson(i)).toList();
  }
}
