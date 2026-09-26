// Heures et dates GTFS — miroir Dart de lib/external-gtfs/gtfs-time.js.
// Aucun arrondi, aucune heure fabriquée : une heure est soit lue telle quelle
// dans stop_times.txt, soit absente. Fuseau de service Africa/Dakar = UTC+0.

final RegExp _timeRe = RegExp(r'^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$');
final RegExp _isoDateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _compactDateRe = RegExp(r'^(\d{4})(\d{2})(\d{2})$');

const List<String> gtfsWeekdays = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// 'HH:MM[:SS]' (HH peut dépasser 24 en GTFS) → secondes depuis minuit, ou null.
int? parseGtfsTime(String? value) {
  if (value == null) return null;
  final RegExpMatch? m = _timeRe.firstMatch(value);
  if (m == null) return null;
  final int h = int.parse(m.group(1)!);
  final int min = int.parse(m.group(2)!);
  final int s = m.group(3) == null ? 0 : int.parse(m.group(3)!);
  if (min > 59 || s > 59) return null;
  return h * 3600 + min * 60 + s;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// secondes → 'HH:MM:SS' (HH non réduit modulo 24, conforme GTFS).
String formatGtfsTime(int seconds) {
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final int s = seconds % 60;
  return '${_pad2(h)}:${_pad2(m)}:${_pad2(s)}';
}

/// secondes → 'HH:MM' (affichage).
String formatHHMM(int seconds) =>
    '${_pad2(seconds ~/ 3600)}:${_pad2((seconds % 3600) ~/ 60)}';

/// 'YYYY-MM-DD' | 'YYYYMMDD' → 'YYYYMMDD' ; lève [FormatException] si invalide.
String normalizeServiceDate(String value) {
  final String s = value.trim();
  RegExpMatch? m = _isoDateRe.firstMatch(s);
  m ??= _compactDateRe.firstMatch(s);
  if (m == null) throw FormatException('Date de service invalide : « $value »');
  final int y = int.parse(m.group(1)!);
  final int mo = int.parse(m.group(2)!);
  final int d = int.parse(m.group(3)!);
  final DateTime dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) {
    throw FormatException('Date de service inexistante : « $value »');
  }
  return '${y.toString().padLeft(4, '0')}${_pad2(mo)}${_pad2(d)}';
}

/// 'YYYYMMDD' → 'YYYY-MM-DD'.
String toIsoDate(String value) {
  final String d = normalizeServiceDate(value);
  return '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)}';
}

DateTime _utcOf(String yyyymmdd) {
  final String d = normalizeServiceDate(yyyymmdd);
  return DateTime.utc(
    int.parse(d.substring(0, 4)),
    int.parse(d.substring(4, 6)),
    int.parse(d.substring(6, 8)),
  );
}

/// Jour de semaine GTFS ('monday' … 'sunday') d'une date de service.
String weekdayOf(String yyyymmdd) => gtfsWeekdays[_utcOf(yyyymmdd).weekday - 1];

/// Date de service décalée de [n] jours.
String addDays(String yyyymmdd, int n) {
  final DateTime dt = _utcOf(yyyymmdd).add(Duration(days: n));
  return '${dt.year.toString().padLeft(4, '0')}${_pad2(dt.month)}${_pad2(dt.day)}';
}

/// Horloge de service (Dakar = UTC+0 toute l'année).
class DakarClock {
  const DakarClock(this.serviceDate, this.seconds);

  final String serviceDate;
  final int seconds;

  String get isoDate => toIsoDate(serviceDate);
  String get time => formatGtfsTime(seconds);
}

DakarClock dakarClock(DateTime instant) {
  final DateTime u = instant.toUtc();
  final String day =
      '${u.year.toString().padLeft(4, '0')}${_pad2(u.month)}${_pad2(u.day)}';
  return DakarClock(day, u.hour * 3600 + u.minute * 60 + u.second);
}
