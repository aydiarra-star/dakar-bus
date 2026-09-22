/// Dakar Bus - Groupe 11
/// ScheduleRepository : abstraction pour récupérer les départs réellement sourcés
/// Permettra ultérieurement de brancher GTFS, API officielle, fichier officiel, flux temps réel, base distante
/// Sans devoir réécrire StopCard ou SingleStopView

import '../models/departure.dart';

abstract class ScheduleRepository {
  Future<List<Departure>> departuresForStop(String stopId);

  Future<List<Departure>> departuresForStopAndLine(String stopId, String lineId) async {
    final all = await departuresForStop(stopId);
    return all.where((d) => d.lineId == lineId).toList();
  }
}
