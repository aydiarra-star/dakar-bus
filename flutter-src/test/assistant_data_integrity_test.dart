// LOT 5 — ASSISTANT IA connecté aux seules données réellement disponibles.
//
// `AssistantReplies.modeInfo` présentait chaque réseau à partir des compteurs
// de provenance. Depuis LOT 2/3, la source porte aussi `audit_flags` et
// `official_identifier_status` : une ligne signalée « itinéraire incohérent »
// ou à numéro contesté était encore présentée comme ordinaire. Ces tests
// verrouillent la restitution de ces métadonnées — et l'absence d'invention
// pour un réseau sans anomalie.
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!appDataService.isLoaded) await appDataService.loadNetworkData();
    integrateNetworkDataForTest();
  });

  String info(String op) => AssistantReplies.modeInfo(
      op, appDataService.operators, appDataService.routes);

  test('DDD : l’IA signale les itinéraires géographiquement incohérents', () {
    final String reply = info('ddd');
    expect(reply, contains('géographiquement incohérentes'));
    expect(reply, contains('2 ligne(s)'));
  });

  test('DDD : l’IA signale les numéros contestés et absents', () {
    final String reply = info('ddd');
    expect(reply, contains('numéro contesté'));
    expect(reply, contains('8 ligne(s)')); // CONFLICTING DDD
    expect(reply, contains('aucun numéro officiel publié'));
  });

  test('TATA : séquences dupliquées et numéros contestés signalés', () {
    final String reply = info('tata');
    expect(reply, contains('séquence d’arrêts dupliquée'));
    expect(reply, contains('numéro contesté'));
  });

  test('TER : aucune anomalie inventée, mais l’absence d’horaire est dite', () {
    final String reply = info('ter');
    expect(reply, isNot(contains('géographiquement incohérentes')));
    expect(reply, isNot(contains('numéro contesté')));
    expect(reply, isNot(contains('séquence d’arrêts dupliquée')));
    expect(reply, contains('aucun horaire'));
  });

  test('les compteurs de l’IA correspondent aux données, pas à des littéraux', () {
    final List<TransportRoute> ddd = appDataService.routes
        .where((TransportRoute r) => r.operatorId == 'ddd')
        .toList();
    final int incoherent = ddd
        .where((TransportRoute r) =>
            r.auditFlags.contains('ITINERARY_GEOGRAPHICALLY_INCOHERENT'))
        .length;
    final int contested = ddd
        .where((TransportRoute r) =>
            r.officialIdentifierStatus == OfficialIdentifierStatus.conflicting)
        .length;
    expect(incoherent, 2);
    expect(contested, 10);
    final String reply = info('ddd');
    expect(reply, contains('$incoherent ligne(s) sont signalées'));
    expect(reply, contains('$contested ligne(s) portent un numéro contesté'));
  });
}
