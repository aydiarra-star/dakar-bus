// Synthetic provider boundary tests; no production real-time source is added.
import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/services/external_gtfs/frequency_source.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_feed.dart';
import 'package:dakar_bus/services/external_gtfs/gtfs_schedule_service.dart';
import 'package:dakar_bus/services/external_gtfs/schedule_assistant.dart';
import 'package:dakar_bus/services/external_gtfs/transit_data_provider.dart';
import 'external_gtfs_test.dart' show aftuTexts, cetudProvenance, passbiProvenance, saturday0730;

const question = 'Prochain bus AFTU 30 à Yeumbeul TEST ?';

TransitDataProvider provider({bool historical = false}) {
  final p = TransitDataProvider(now: saturday0730);
  p.registerSource(GtfsScheduleService(GtfsFeed.fromTexts(aftuTexts,
      historical ? passbiProvenance('AFTU') : cetudProvenance('AFTU'), network: 'AFTU')),
      role: historical ? ProviderRoles.historicalReference : ProviderRoles.currentOfficial);
  return p;
}

// Inject an already classified result at the assistant/provider boundary.
// This is NOT an observed vehicle and is never registered in production.
class RealtimeFixtureProvider extends TransitDataProvider {
  RealtimeFixtureProvider(this.current) : super(now: saturday0730) {
    registerSource(GtfsScheduleService(GtfsFeed.fromTexts(
        aftuTexts, cetudProvenance('AFTU'), network: 'AFTU')),
        role: ProviderRoles.currentOfficial);
  }
  final bool current;
  @override
  DepartureResult getDepartures(String routeId, String? stopId,
      {String? date, String? time, int? limit = 5}) {
    final r = super.getDepartures(routeId, stopId, date: date, time: time, limit: limit);
    return DepartureResult(routeId: r.routeId, stopId: r.stopId, date: r.date,
      currentTime: r.currentTime, status: 'REAL_TIME', reason: r.reason,
      source: r.source, sourceType: r.sourceType, feedVersion: r.feedVersion,
      validity: r.validity, provenanceLevel: r.provenanceLevel,
      departures: r.departures, isCurrent: current);
  }
}

void main() {
  test('SCHEDULED and GTFS-known frequency fallback ESTIMATED retain their meaning', () {
    final p = provider();
    p.registerSource(FrequencySource([
      FrequencyEntry(network: 'AFTU', lineNumber: '30', headwayMinutes: 12,
        routeIds: ['TEST_AFTU_R30'], from: '06:00', to: '21:00'),
    ], cetudProvenance('AFTU')), role: ProviderRoles.currentFrequency);
    final scheduled = answerScheduleQuestion(p, question);
    expect(scheduled.status, 'SCHEDULED');
    expect(scheduled.sentence, contains('départ programmé est à 07:42'));
    final estimated = answerScheduleQuestion(p, question, time: '12:00');
    expect(estimated.status, 'ESTIMATED');
    expect(estimated.provenanceLevel, 'ESTIMATED');
    expect(estimated.estimate!.headwayMinutes, 12);
    expect(estimated.departure, isNull);
    expect(estimated.departures, isEmpty);
    expect(estimated.sentence, contains('environ toutes les 12 minutes'));
    expect(estimated.sentence, isNot(contains('départ programmé')));
    expect(estimated.sentence, isNot(contains('temps réel')));
    expect(answerScheduleQuestion(p, question, time: '22:00').status, 'UNKNOWN');
    expect(answerScheduleQuestion(p, 'Prochain bus AFTU 30 à Inconnu TEST ?', time: '12:00').status, 'UNKNOWN');
  });
  test('REAL_TIME is only relayed from a current provider result', () {
    final a = answerScheduleQuestion(RealtimeFixtureProvider(true), question);
    expect(a.status, 'REAL_TIME');
    expect(a.sentence, contains('annoncé en temps réel est à 07:42'));
    expect(a.sentence, isNot(contains('programmé')));
    expect(answerScheduleQuestion(RealtimeFixtureProvider(false), question).status, 'UNKNOWN');
  });
  test('UNKNOWN stays unavailable; historical PassBi never becomes current', () {
    expect(answerScheduleQuestion(TransitDataProvider(now: saturday0730), question).status, 'UNKNOWN');
    final p = provider(historical: true);
    final a = answerScheduleQuestion(p, question);
    expect(a.status, 'UNKNOWN');
    expect(a.lineKnownHistorically, isTrue);
    expect(p.getDepartures('TEST_AFTU_R30', 'TEST_S_Y').isCurrent, isFalse);
  });
}
