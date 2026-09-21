import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';

void main() {
  group('DataTrust', () {
    test('fromString OFFICIAL', () {
      expect(DataTrustExtension.fromString('OFFICIAL'), DataTrust.official);
    });
    test('fromString FIELD_OBSERVATION', () {
      expect(DataTrustExtension.fromString('FIELD_OBSERVATION'), DataTrust.fieldObservation);
    });
    test('toLabel', () {
      expect(DataTrust.official.toLabel(), 'OFFICIAL');
      expect(DataTrust.fieldObservation.toLabel(), 'FIELD_OBSERVATION');
      expect(DataTrust.estimated.toLabel(), 'ESTIMATED');
    });
  });

  group('TransportNetwork JSON', () {
    test('Operator fromJson', () {
      final op = Operator.fromJson({"id": "brt", "name": "SunuBRT", "color": "#22C55E"});
      expect(op.id, 'brt');
      expect(op.colorHex, '#22C55E');
    });
    test('BusStop fromJson', () {
      final stop = BusStop.fromJson({
        "id": "stop_petersen",
        "name": "Petersen",
        "latitude": 14.6738,
        "longitude": -17.4381,
        "data_trust": "OFFICIAL"
      });
      expect(stop.name, 'Petersen');
      expect(stop.dataTrust, DataTrust.official);
    });
    test('TransportRoute fromJson', () {
      final route = TransportRoute.fromJson({
        "id": "brt_1",
        "operator_id": "brt",
        "short_name": "BRT B1",
        "long_name": "Guediawaye <-> Petersen",
        "type": "BRT",
        "data_trust": "OFFICIAL",
        "stops": ["stop_a", "stop_b"]
      });
      expect(route.operatorId, 'brt');
      expect(route.stopIds.length, 2);
    });
  });

  group('DataService', () {
    test('loadNetworkData loads réseau complet 92 routes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ds = DataService();
      await ds.loadNetworkData();
      // Avec le JSON complet (40 routes) ou fallback (5 routes min), on attend >=5
      expect(ds.routes.length, greaterThanOrEqualTo(90)); // 72 AFTU + 12 DDD + 5 Tata + 2 BRT + 1 TER = 92
      expect(ds.stops.length, greaterThanOrEqualTo(90)); // 92 stops
      expect(ds.operators.length, greaterThanOrEqualTo(4));
      expect(ds.isLoaded, true);
    });

    test('stopsForRoute helper', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ds = DataService();
      await ds.loadNetworkData();
      if (ds.routes.isNotEmpty) {
        final first = ds.routes.first;
        final stops = ds.stopsForRoute(first.id);
        expect(stops.length, first.stopIds.length);
      }
    });
  });
}
