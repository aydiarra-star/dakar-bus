/// Dakar Bus - Groupe 11
/// Modèle Stop enrichi avec socle horaires réels
/// Architecture cible :
/// SOURCE RÉELLE -> Departure -> DataStatus.scheduled -> Stop -> departureAfter() -> remainingMinutes() -> UI

import 'data_status.dart';
import 'data_trust.dart';
import 'departure.dart';

class Stop {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final List<String> lines;
  final String? type;
  final DataTrust trust;
  final dynamic raw;

  List<Departure> _departures;

  Stop({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    List<String>? lines,
    this.type,
    List<Departure>? departures,
    this.trust = DataTrust.unknown,
    this.raw,
  })  : lines = lines ?? const [],
        _departures = departures ?? const [];

  List<Departure> get departures => List.unmodifiable(_departures);

  void setDepartures(List<Departure> departures) {
    _departures = List.from(departures);
  }

  bool get hasSourcedSchedule => _departures.isNotEmpty;

  DataStatus get dataStatus {
    if (!hasSourcedSchedule) return DataStatus.unknown;
    final next = departureAfter(DateTime.now());
    if (next == null) return DataStatus.unknown;
    return next.status;
  }

  /// Retourne le prochain Departure futur après [after]
  /// Principe :
  /// départs réellement sourcés -> filtrer futurs -> prendre prochain -> retourner heure
  /// NE PAS faire : heure actuelle + X, _generateSchedule, coefficient arbitraire
  Departure? departureAfter(DateTime after) {
    if (_departures.isEmpty) return null;
    final future = _departures
        .where((d) => d.departureTime.isAfter(after))
        .toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
    if (future.isEmpty) return null;
    return future.first;
  }

  int? remainingMinutes(DateTime now) {
    final next = departureAfter(now);
    if (next == null) return null;
    final diff = next.departureTime.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) return null;
    return diff.inMinutes;
  }

  String nextDepartureLabel(DateTime now) {
    final next = departureAfter(now);
    if (next == null) return 'Horaire non disponible';
    final h = next.departureTime.hour;
    final m = next.departureTime.minute.toString().padLeft(2, '0');
    return '$h h $m';
  }

  /// @deprecated _generateSchedule ne doit plus être utilisé comme source de départ réel
  /// Conservé uniquement pour documentation / compatibilité tests anciens non affichés
  List<Departure> generateSchedule() {
    // ignore: avoid_print
    print('_generateSchedule is deprecated and must not be used as real departure source. Use ScheduleRepository instead.');
    return [];
  }

  // Ancien nom pour compatibilité
  List<Departure> _generateSchedule() => generateSchedule();

  @override
  String toString() => 'Stop($id, $name, departures=${_departures.length})';
}
