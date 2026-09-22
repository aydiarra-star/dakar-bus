/// Dakar Bus - Groupe 11
/// UnavailableScheduleRepository : premier repository, aucune donnée fausse
/// Comportement :
/// aucune source réelle branchée -> liste vide -> Horaire non disponible
/// Il ne doit générer aucun horaire. Étape volontaire.

import '../models/departure.dart';
import 'schedule_repository.dart';

class UnavailableScheduleRepository implements ScheduleRepository {
  @override
  Future<List<Departure>> departuresForStop(String stopId) async {
    // Aucune source réelle branchée à ce stade
    return [];
  }

  @override
  Future<List<Departure>> departuresForStopAndLine(String stopId, String lineId) async {
    final all = await departuresForStop(stopId);
    return all.where((d) => d.lineId == lineId).toList();
  }
}
