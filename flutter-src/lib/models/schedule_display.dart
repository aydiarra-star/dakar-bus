/// Lot 4.22 — Explorer : formatage des prochains passages RÉELS.
///
/// Règles absolues (aucune donnée inventée) :
///  * les minutes d'attente proviennent de VRAIS départs (trips + stop_times +
///    services actifs) ; [waitingMinutesBetween] applique l'arrondi VERS LE
///    HAUT (`ceil(waitSeconds / 60)`) et ne retourne jamais 0 — un passage à
///    moins d'une minute mais encore futur affiche 1 mn ;
///  * [formatWaitingMinutes] ne retourne que « N mn » (liste « 1 mn · 10 mn ·
///    15 mn »), aucun texte supplémentaire (jamais « Prochain départ dans »,
///    jamais « Prévu HH h MM », jamais « Passage estimé dans ») ;
///  * [normalizeDirectionLabel] produit « vers X » à partir d'une direction
///    RÉELLE (headsign de trip ou libellé référentiel « Dir. X ») ; sans
///    direction réelle le résultat est `null` — AUCUNE destination n'est
///    inventée (ni par proximité, ni par numéro de ligne, ni par OSM) ;
///  * [formatStopHeader] compose « [Nom station] [MODE] vers [Destination] »
///    sans duplication (le MODE déjà présent dans le nom n'est pas répété).
library;

/// Minutes d'attente entières d'un départ : `ceil(waitSeconds / 60)`.
///
///  * `waitSeconds = departureTime - now` ;
///  * arrondi vers le haut : 3 min 10 s → 4 mn, 3 min 50 s → 4 mn,
///    5 min 00 s → 5 mn ;
///  * jamais 0 mn : un passage à moins d'une minute mais encore futur (et un
///    départ à l'instant présent) affiche 1 mn ;
///  * `null` si le départ est déjà passé (`waitSeconds < 0`) : un stop_time
///    passé n'est jamais retourné.
int? waitingMinutesBetween(DateTime departureTime, DateTime now) {
  final int waitSeconds = departureTime.difference(now).inSeconds;
  if (waitSeconds < 0) return null;
  final int ceilMinutes = (waitSeconds + 59) ~/ 60;
  return ceilMinutes < 1 ? 1 : ceilMinutes;
}

/// Un temps d'attente, uniquement « N mn » (jamais 0 mn, jamais d'autre texte).
String formatWaitingMinute(int minutes) => '${minutes < 1 ? 1 : minutes} mn';

/// Liste de temps d'attente : « 1 mn · 10 mn · 15 mn ».
///
/// Liste vide → chaîne vide : l'appelant affiche alors l'indicateur neutre
/// « Horaire indisponible » — jamais de faux temps.
String formatWaitingMinutes(List<int> waitingMinutes) =>
    waitingMinutes.map(formatWaitingMinute).join(' · ');

final RegExp _directionPrefix =
    RegExp(r'^(?:dir|direction)\s*[.:]?\s*', caseSensitive: false);

/// « PETERSEN » → « Petersen » (lisibilité). Une chaîne déjà mixte reste
/// inchangée (« Diamniadio » → « Diamniadio »). Présentation seule.
String _beautifyAllCaps(String value) {
  final bool hasLetter =
      value.contains(RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]'));
  if (!hasLetter || value != value.toUpperCase()) return value;
  return value
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word.substring(0, 1).toUpperCase()}'
              '${word.substring(1).toLowerCase()}')
      .join(' ');
}

/// Libellé de destination : « vers X » ou `null`.
///
///  * les préfixes « Dir. » / « Direction » sont retirés (« Dir. Petersen » →
///    « vers Petersen ») et « vers » n'est JAMAIS dupliqué (« Dir. vers
///    Petersen » → « vers Petersen ») ;
///  * un texte déjà normalisé (« vers Petersen ») reste tel quel ;
///  * [requireDirPrefix] : pour les libellés d'arrêt ambigus (« 3 lignes PassBi
///    DDD », « Terminus X (Arrivée) »), une destination n'est acceptée que si
///    la chaîne porte explicitement le préfixe « Dir. » — sinon `null`.
String? normalizeDirectionLabel(String? rawDirection,
    {bool requireDirPrefix = false}) {
  String s = (rawDirection ?? '').trim();
  if (s.isEmpty) return null;
  bool hadDirectionMark = false;
  for (int i = 0; i < 2; i++) {
    if (s.toLowerCase().startsWith('vers ')) {
      s = s.substring(5).trim();
      hadDirectionMark = true;
      continue;
    }
    final Match? m = _directionPrefix.firstMatch(s);
    if (m != null) {
      s = s.substring(m.end).trim();
      hadDirectionMark = true;
      continue;
    }
    break;
  }
  if (requireDirPrefix && !hadDirectionMark) return null;
  if (s.isEmpty) return null;
  return 'vers ${_beautifyAllCaps(s)}';
}

/// En-tête d'arrêt Explorer : « [Nom station] [MODE] vers [Destination] ».
///
///  * exemple : [formatStopHeader]('Sacré-Cœur', 'BRT', 'Dir. Petersen') ==
///    « Sacré-Cœur BRT vers Petersen » ;
///  * direction réelle inconnue → « [Nom station] [MODE] » seul (jamais de
///    « vers » inventé) ;
///  * sans duplication : le MODE déjà présent dans le nom n'est pas répété
///    (« Sacré-Cœur - BRT » + « BRT » → « Sacré-Cœur - BRT »).
String formatStopHeader(
  String stopName,
  String modeLabel,
  String? rawDirection, {
  bool requireDirPrefix = false,
}) {
  String base = stopName.trim();
  final String mode = modeLabel.trim();
  if (mode.isNotEmpty && !_endsWithWord(base, mode)) {
    base = base.isEmpty ? mode : '$base $mode';
  }
  final String? destination =
      normalizeDirectionLabel(rawDirection, requireDirPrefix: requireDirPrefix);
  return destination == null ? base : '$base $destination';
}

bool _endsWithWord(String text, String word) {
  final String t = text.toLowerCase();
  final String w = word.toLowerCase();
  if (!t.endsWith(w)) return false;
  if (t.length == w.length) return true;
  return !RegExp(r'[a-z0-9à-öø-ÿ]').hasMatch(t[t.length - w.length - 1]);
}
