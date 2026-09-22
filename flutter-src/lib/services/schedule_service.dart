/// Dakar Bus - Groupe 11
/// Services utilitaires pour horaires réellement sourcés

import '../models/data_status.dart';
import '../models/departure.dart';

Departure? departureAfter(List<Departure> departures, DateTime after) {
  if (departures.isEmpty) return null;
  final future = departures.where((d) => d.departureTime.isAfter(after)).toList()
    ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  return future.isEmpty ? null : future.first;
}

int? remainingMinutes(List<Departure> departures, DateTime now) {
  final next = departureAfter(departures, now);
  if (next == null) return null;
  final diff = next.departureTime.difference(now);
  if (diff.isNegative || diff.inSeconds <= 0) return null;
  return diff.inMinutes;
}

String nextDepartureLabel(List<Departure> departures, DateTime now) {
  final next = departureAfter(departures, now);
  if (next == null) return 'Horaire non disponible';
  final h = next.departureTime.hour;
  final m = next.departureTime.minute.toString().padLeft(2, '0');
  return '$h h $m';
}

DataStatus getDataStatus(List<Departure> departures, DateTime now) {
  final next = departureAfter(departures, now);
  if (next == null) return DataStatus.unknown;
  return next.status;
}

bool hasSourcedSchedule(List<Departure> departures) => departures.isNotEmpty;
