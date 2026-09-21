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
    // GROUPE 1 (Step 4B) — attentes portées de « >= 90 » à des valeurs EXACTES.
    //
    // AVANT : 'loadNetworkData loads réseau complet 92 routes',
    //         routes >= 90, stops >= 90, operators >= 4, avec le commentaire
    //         « 72 AFTU + 12 DDD + 5 Tata + 2 BRT + 1 TER = 92 ».
    // RAISON : ces valeurs décrivaient la DONNÉE HISTORIQUE. La donnée ACTIVE
    //         (gh-pages 94a84b60, md5 81c778f4644dcf5e1cf4ae25879218f0) compte
    //         117 arrêts et 105 lignes : 1 TER + 2 BRT + 80 AFTU + 15 DDD
    //         + 7 Tata. L'ancien libellé confondait arrêts et lignes.
    //         Des bornes inférieures masquaient aussi un basculement silencieux
    //         sur le repli en dur (5 lignes, 6 arrêts) : des valeurs exactes le
    //         rendent impossible.
    test('loadNetworkData charge la DONNÉE ACTIVE (117 arrêts, 105 lignes)',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ds = DataService();
      await ds.loadNetworkData();
      expect(ds.isLoaded, true);
      expect(ds.stops.length, 117);
      expect(ds.routes.length, 105);
      expect(ds.operators.length, 5);
    });

    test('le repli en dur n a PAS été utilisé', () async {
      // Le repli de DataService contient 6 arrêts et 5 lignes. Si l'asset
      // n'était pas lu, les comptes ci-dessus seraient 6 et 5.
      TestWidgetsFlutterBinding.ensureInitialized();
      final ds = DataService();
      await ds.loadNetworkData();
      expect(ds.stops.length, isNot(6));
      expect(ds.routes.length, isNot(5));
    });

    test('décomposition par opérateur de la donnée ACTIVE', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ds = DataService();
      await ds.loadNetworkData();
      int byOp(String id) =>
          ds.routes.where((r) => r.operatorId == id).length;
      expect(byOp('ter'), 1);
      expect(byOp('brt'), 2);
      expect(byOp('aftu'), 80);
      expect(byOp('ddd'), 15);
      expect(byOp('tata'), 7);
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
