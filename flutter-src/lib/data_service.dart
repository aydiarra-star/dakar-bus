/// Dakar Bus - Groupe 11
/// DataService : service de chargement réseau, ne génère aucun horaire fictif
/// Respecte règle : pas de donnée inventée, pas de _generateSchedule comme source officielle

import 'models/stop.dart';
import 'repositories/schedule_repository.dart';
import 'repositories/unavailable_schedule_repository.dart';

class DataService {
  final ScheduleRepository _scheduleRepository;

  DataService({ScheduleRepository? scheduleRepository})
      : _scheduleRepository = scheduleRepository ?? UnavailableScheduleRepository();

  ScheduleRepository get scheduleRepository => _scheduleRepository;

  /// Charge les arrêts depuis source réelle (GTFS, fichier officiel, etc.)
  /// Ne doit pas inventer d'horaires
  Future<List<Stop>> loadStops() async {
    // Dans Groupe 11, aucune source réelle branchée
    // Retourne liste vide ou charge depuis JSON existant sans horaires inventés
    // Le JSON dakar_network.json ne doit pas contenir de faux horaires (MD5 81c778f4644dcf5e1cf4ae25879218f0)
    // Pour l'instant, on retourne vide - l'intégration réelle viendra avec source officielle
    return [];
  }

  Future<List<Stop>> loadStopsWithSchedules() async {
    final stops = await loadStops();
    for (final stop in stops) {
      final departures = await _scheduleRepository.departuresForStop(stop.id);
      stop.setDepartures(departures);
    }
    return stops;
  }
}
