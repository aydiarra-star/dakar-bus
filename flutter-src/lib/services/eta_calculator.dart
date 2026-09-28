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

    // Lot 4.21 §15 — un UNKNOWN restant porte sa raison précise. Le repli
    // legacy ci-dessous ne connaît pas le crosswalk : la raison est résolue
    // ici, une seule fois, depuis la source PassBi.
    final String? reason = routeId == null
        ? null
        : scheduleProvider.unresolvedReasonFor(
            routeId: routeId,
            stopId: stopId,
          );

    // 3. ESTIMATED — fréquences officielles legacy (routes sans mappage).
    if (routeId != null) {
      final estimated = frequencyProvider.departureInfoForRoute(
        routeId,
        at,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );
      if (reason != null &&
          estimated.status == ScheduleStatus.unknown &&
          estimated.unresolvedReason == null) {
        return estimated.withUnresolvedReason(reason);
      }
      return estimated;
    }

    // 4. UNKNOWN.
    return DepartureInfo.unknown(
      operator: operatorName ?? 'Inconnu',
      routeId: 'unknown',
      requestedAt: at,
      unresolvedReason: reason ?? UnresolvedReason.stopNotMatched,
    );
  }

  /// Lot 4.21 §4/§5 — chemin NATIF PassBi (DDD / AFTU).
  ///
  /// La donnée PassBi (route + trip + stop + stop_time + service actif) suffit
  /// à calculer un prochain départ SCHEDULED, indépendamment de la résolution
  /// documentaire de l'identité publique (§2). Aucun repli fréquence n'existe
  /// sur ce chemin : sans départ calculable → UNKNOWN et sa raison.
  DepartureInfo computePassBi({
    required String networkKey,
    required String pbStopId,
    required DateTime at,
    String? pbRouteId,
    bool isPublicHoliday = false,
  }) =>
      scheduleProvider.departureAtPassBiStop(
        networkKey: networkKey,
        pbStopId: pbStopId,
        requestedAt: at,
        pbRouteId: pbRouteId,
        isPublicHoliday: isPublicHoliday,
      );

  /// Aucun chemin ne produit REAL_TIME : garde-fou explicite (les tests
  /// d'absence de faux temps réel s'appuient dessus).
  static const bool hasRealtimeFeed = false;
}
