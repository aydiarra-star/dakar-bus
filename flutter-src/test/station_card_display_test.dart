import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cas 4 — UNKNOWN → Horaire indisponible', () {
    final info = DepartureInfo.unknown(operator: 'Test', routeId: 'test_route_synthetic_only', requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
    expect(departureDisplayLabel(info), 'Horaire indisponible');
  });
}
