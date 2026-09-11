import '../models/transport_network.dart';

class DataService {
  List<TransportRoute> _routes = [];

  List<TransportRoute> get routes => _routes;

  Future<void> loadNetworkData() async {
    // Simulation d'un chargement rapide en mémoire
    await Future.delayed(const Duration(milliseconds: 300));

    _routes = [
      TransportRoute(
        id: 'brt_1',
        shortName: 'BRT Ligne 1',
        longName: 'Gare Petersen <-> Parcelles Assainies',
        operator: 'SunuBRT',
        dataTrust: DataTrust.official,
        stops: [
          RouteStop(id: 'petersen', name: 'Gare Petersen', trust: DataTrust.official),
          RouteStop(id: 'grand_yoff', name: 'Grand Yoff', trust: DataTrust.official),
          RouteStop(id: 'parcelles', name: 'Parcelles Assainies', trust: DataTrust.official),
        ],
      ),
      TransportRoute(
        id: 'aftu_12',
        shortName: 'AFTU Ligne 12',
        longName: 'Guédiawaye <-> Palais de Justice',
        operator: 'AFTU',
        dataTrust: DataTrust.fieldObservation,
        stops: [
          RouteStop(id: 'guediawaye', name: 'Guédiawaye', trust: DataTrust.fieldObservation),
          RouteStop(id: 'palais', name: 'Palais de Justice', trust: DataTrust.fieldObservation),
        ],
      ),
      TransportRoute(
        id: 'ddd_8',
        shortName: 'DDD Ligne 8',
        longName: 'Aéroport Yoff <-> Sandaga',
        operator: 'Dakar Dem Dikk',
        dataTrust: DataTrust.official,
        stops: [
          RouteStop(id: 'yoff', name: 'Aéroport Yoff', trust: DataTrust.official),
          RouteStop(id: 'sandaga', name: 'Sandaga', trust: DataTrust.official),
        ],
      ),
    ];
  }
}
