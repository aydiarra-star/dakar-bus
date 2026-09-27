/// Lot 4.18 — EtaCalculator : hiérarchie des sources d'ETA.
///
/// Ordre strict :
///  1. REAL_TIME — aucun flux temps réel n'existe dans le projet → JAMAIS ;
///  2. SCHEDULED — horaires programmés PassBi (source opérationnelle
///     actuelle, `ScheduleProvider`) → 🟢 X min quand calculable ;
///  3. ESTIMATED — fréquences officielles publiées (DataProvider legacy) ;
///  4. UNKNOWN — aucune donnée suffisante (pas de faux retard, pas de
///     fréquence présentée comme prochain passage).
///
/// Affichages interdits : « 0 min » comme pseudo-temps réel, « 0–20 min »,
/// « Passage non communiqué », une fréquence comme prochain passage.
library;

import '../models/departure_info.dart';
import 'data_provider.dart';
import 'schedule_provider.dart';

class EtaCalculator {
  final ScheduleProvider scheduleProvider;
  final DataProvider frequencyProvider;

  const EtaCalculator({
    required this.scheduleProvider,
    required this.frequencyProvider,
  });

  /// Calcule le meilleur [DepartureInfo] pour (route, arrêt, instant).
  ///
  /// Retourne toujours une réponse exploitable : SCHEDULED (PassBi) si
  /// disponible, sinon ESTIMATED (fréquences officielles), sinon UNKNOWN.
  DepartureInfo compute({
    required String? routeId,
    required String? stopId,
    required String network,
    required DateTime at,
    bool isPublicHoliday = false,
    String? operatorName,
  }) {
    // 2. SCHEDULED — PassBi (source opérationnelle actuelle).
    if (routeId != null) {
      final scheduled = scheduleProvider.departureAt(
        routeId: routeId,
        stopId: stopId,
        requestedAt: at,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );
      if (scheduled != null) return scheduled;
    }

    // 3. ESTIMATED — fréquences officielles legacy (routes sans mappage).
    if (routeId != null) {
      return frequencyProvider.departureInfoForRoute(
        routeId,
        at,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );
    }

    // 4. UNKNOWN.
    return DepartureInfo.unknown(
      operator: operatorName ?? 'Inconnu',
      routeId: 'unknown',
      requestedAt: at,
    );
  }

  /// Aucun chemin ne produit REAL_TIME : garde-fou explicite (les tests
  /// d'absence de faux temps réel s'appuient dessus).
  static const bool hasRealtimeFeed = false;
}
