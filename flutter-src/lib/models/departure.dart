/// Dakar Bus - Groupe 11
/// Modèle Departure : représente un départ réellement sourcé
/// RÈGLE ABSOLUE : aucune donnée inventée
/// - departureTime doit provenir d'une source réelle
/// - Pas de DateTime.now() comme heure de départ
/// - Pas de distance -> durée, vitesse arbitraire, index -> horaire
/// - Pas de _generateSchedule comme source officielle

import 'data_status.dart';

class Departure {
  final String stopId;
  final String lineId;
  final DateTime departureTime;
  final DataStatus status;
  final String? direction;
  final String? sourceId;

  const Departure({
    required this.stopId,
    required this.lineId,
    required this.departureTime,
    required this.status,
    this.direction,
    this.sourceId,
  });

  bool isFuture(DateTime now) {
    return departureTime.isAfter(now);
  }

  int? remainingMinutes(DateTime now) {
    final diff = departureTime.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) return null;
    return diff.inMinutes;
  }

  @override
  String toString() => 'Departure($stopId, $lineId, $departureTime, $status)';
}
