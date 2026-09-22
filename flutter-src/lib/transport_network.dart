/// Dakar Bus - Groupe 11
/// TransportNetwork : modèle réseau, ne génère aucun horaire fictif
/// Respecte architecture :
/// SOURCE RÉELLE -> Departure -> ScheduleRepository -> Stop -> departureAfter() -> UI

import 'models/stop.dart';
import 'models/departure.dart';
import 'models/data_status.dart';
import 'repositories/schedule_repository.dart';

class TransportNetwork {
  final List<Stop> stops;
  final ScheduleRepository scheduleRepository;

  TransportNetwork({
    required this.stops,
    required this.scheduleRepository,
  });

  /// Retourne le prochain départ réellement sourcé pour un arrêt
  Future<Departure?> nextDepartureForStop(String stopId, DateTime after) async {
    final departures = await scheduleRepository.departuresForStop(stopId);
    if (departures.isEmpty) return null;
    final future = departures.where((d) => d.departureTime.isAfter(after)).toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return future.isEmpty ? null : future.first;
  }

  bool hasSourcedSchedule(String stopId) {
    final stop = stops.where((s) => s.id == stopId).toList();
    if (stop.isEmpty) return false;
    return stop.first.hasSourcedSchedule;
  }

  DataStatus dataStatusForStop(String stopId, DateTime now) {
    final stop = stops.where((s) => s.id == stopId).toList();
    if (stop.isEmpty) return DataStatus.unknown;
    return stop.first.dataStatus;
  }
}
