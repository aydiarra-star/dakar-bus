/// Lot 4.18 — EtaCalculator : hiérarchie des sources d'ETA.
///
/// Ordre strict :
///  1. REAL_TIME — aucun flux temps réel n'existe dans le projet → JAMAIS ;
///  2. SCHEDULED — horaires programmés PassBi (source opérationnelle
///     actuelle, `ScheduleProvider`) → 🟢 X min quand calculable ;
///  3. ESTIMATED — fréquences officielles publiées (DataProvider legacy),
///     uniquement hors des quatre réseaux couverts par le GTFS ;
///  4. UNKNOWN — aucune donnée suffisante.
///
/// Pour TER, BRT, DDD et AFTU, le GTFS est exclusif : absence de mapping,
/// de départ ou de chargement = UNKNOWN, sans repli sur les fréquences.
///
/// Affichages interdits : « 0 min » comme pseudo-temps réel, « 0–20 min »,
/// une fréquence comme prochain passage.
library;

import '../models/departure_info.dart';
import '../models/transport_network.dart';
import 'data_provider.dart';
import 'schedule_provider.dart';

class EtaCalculator {
  final ScheduleProvider scheduleProvider;
  final DataProvider frequencyProvider;

  const EtaCalculator({
    required this.scheduleProvider,
    required this.frequencyProvider,
  });

  static const Set<String> _passBiOnlyNetworks = <String>{
    'TER',
    'BRT',
    'DDD',
    'AFTU',
  };

  bool _usesPassBiExclusively(String network) =>
      _passBiOnlyNetworks.contains(network.trim().toUpperCase());

  /// Calcule le meilleur [DepartureInfo] pour (route, arrêt, instant).
  ///
  /// TER/BRT/DDD/AFTU : PassBi uniquement, sinon UNKNOWN.
  /// Les autres réseaux conservent le comportement historique.
  DepartureInfo compute({
    required String? routeId,
    required String? stopId,
    required String network,
    required DateTime at,
    bool isPublicHoliday = false,
    String? operatorName,
  }) {
    // SCHEDULED — PassBi (source opérationnelle actuelle).
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

    // Résolution de la raison d'absence depuis la source GTFS.
    final String? reason = routeId == null
        ? null
        : scheduleProvider.unresolvedReasonFor(
            routeId: routeId,
            stopId: stopId,
          );

    // Verrou d'exclusivité : aucun repli fréquence sur TER/BRT/DDD/AFTU,
    // même si le feed n'est pas chargé ou si l'identité n'est pas raccordée.
    if (_usesPassBiExclusively(network)) {
      return DepartureInfo.unknown(
        operator: operatorName ?? network,
        routeId: routeId ?? 'unknown',
        requestedAt: at,
        unresolvedReason: reason ??
            (routeId == null
                ? UnresolvedReason.stopNotMatched
                : UnresolvedReason.sourceInactive),
      );
    }

    // ESTIMATED — fréquences legacy uniquement hors des quatre réseaux GTFS.
    if (routeId != null) {
      return frequencyProvider.departureInfoForRoute(
        routeId,
        at,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );
    }

    return DepartureInfo.unknown(
      operator: operatorName ?? 'Inconnu',
      routeId: 'unknown',
      requestedAt: at,
      unresolvedReason: UnresolvedReason.stopNotMatched,
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
