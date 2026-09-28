/// Horloge de référence du réseau : heure de Dakar (Africa/Dakar).
///
/// Dakar n'applique **aucun changement d'heure** : le fuseau est un UTC+00
/// constant. Un horaire publié « 06:00 » par un opérateur sénégalais est donc
/// une heure de Dakar, quelle que soit la position ou le fuseau du navigateur.
///
/// AVANT : `Stop.remainingMinutes`, `Stop.nextDepartureMinutes` et
///         `RoutePlanner.plan` dérivaient l'heure courante de `DateTime.now()`
///         (heure **locale** du navigateur). Un utilisateur à Paris (UTC+2 en
///         été) voyait le prochain départ décalé de deux heures.
/// APRÈS : une source unique convertit toute référence en heure de Dakar, et
///         le calcul d'un « X min » restant se fait entre deux instants du même
///         fuseau.
class DakarClock {
  const DakarClock._();

  /// Fuseau officiel du réseau Dakar. Nommé pour la traçabilité : c'est
  /// `Africa/Dakar` (UTC+00, sans heure d'été) et non un décalage supposé.
  static const String timeZone = 'Africa/Dakar';

  /// Instant courant du réseau, exprimé en heure de Dakar (UTC).
  ///
  /// L'API Dart n'expose pas la base de données des fuseaux IANA : l'instant
  /// est donc obtenu en UTC, ce qui **est** l'heure de Dakar pour un UTC+00
  /// constant. Aucune heure locale de navigateur n'intervient.
  static DateTime now() => DateTime.now().toUtc();

  /// Convertit une référence quelconque (locale ou UTC) en heure de Dakar.
  ///
  /// Une valeur locale est ramenée à son instant réel puis exprimée en UTC.
  /// Une valeur déjà UTC est renvoyée telle quelle. Aucune hypothèse sur le
  /// fuseau du navigateur n'est faite au-delà de la conversion d'instant.
  static DateTime toDakar(DateTime instant) =>
      instant.isUtc ? instant : instant.toUtc();

  /// Vrai si la référence porte une date/heure exploitable (pas de NaN ni de
  /// valeur aberrante héritée d'un parseur).
  static bool isPlausible(DateTime instant) =>
      instant.millisecondsSinceEpoch.isFinite;
}
