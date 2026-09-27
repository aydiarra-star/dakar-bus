/// Lot 4.18 — ScheduleProvider : horaires programmés PassBi (SCHEDULED).
///
/// Chaine d'intégration : DataService → ScheduleProvider → EtaCalculator →
/// moteur de routage → présentation UI (via les providers existants).
///
/// AUCUNE prétention temps réel : les feeds PassBi sont des horaires
/// programmés (`ScheduleStatus.scheduled`). L'absence de départ calculable
/// produit UNKNOWN — jamais un retard ni une fréquence affichée comme
/// prochain passage.
library;

import '../models/departure_info.dart';
import '../models/transport_network.dart';
import 'gtfs/passbi_source.dart';

class ScheduleProvider {
  final PassBiSource passBi;

  const ScheduleProvider(this.passBi);

  /// Le provider est opérationnel uniquement après le chargement des feeds.
  bool get isActive => passBi.isActive;

  /// Prochain départ pour un couple (route, arrêt) du référentiel dakar
  /// réseau via le crosswalk PassBi.
  ///
  /// Retourne :
  ///  * `null` → source inactive ou couple non mappé (le chemin legacy
  ///    fréquences/UNKNOWN reste applicable) ;
  ///  * [DepartureInfo] `unknown` → route mappée mais AUCUN départ
  ///    calculable à cette date/heure (provenance PassBi conservée) ;
  ///  * [DepartureInfo] `scheduled` → horaire PassBi réellement trouvé.
  DepartureInfo? departureAt({
    required String routeId,
    required String? stopId,
    required DateTime requestedAt,
    bool isPublicHoliday = false,
    String? operatorName,
  }) {
    if (!passBi.isActive || stopId == null) return null;
    final routeMapping = passBi.routeMapping(routeId);
    if (routeMapping == null || !routeMapping.isMapped) return null;
    final stopMapping = passBi.stopMappingFor(routeId, stopId);
    if (stopMapping == null) return null;

    final parts = PassBiSource.splitComposite(stopMapping.compositeStopId);
    if (parts == null) return null;
    final net = passBi.network(parts[0]);
    if (net == null) return null;

    final DateTime t = requestedAt.isUtc ? requestedAt : requestedAt.toUtc();
    final day = DateTime.utc(t.year, t.month, t.day);

    // Lot 4.19 A : les plateformes sœurs (quais de départ de la même
    // station, liaisons crosswalk ≤ 30 m) participent à la recherche — un
    // quai d'arrivée seul rendrait le départ « introuvable » alors qu'une
    // sœur de départ est documentée à quelques mètres.
    final candidates = <String>[parts[1], ...passBi.siblingStops(parts[0], parts[1])];
    int? bestSec;
    for (final pbRouteId in routeMapping.pbRouteIds) {
      for (final pbStopId in candidates) {
        final dep = passBi.nextDepartureSec(
          networkKey: parts[0],
          pbRouteId: pbRouteId,
          pbStopId: pbStopId,
          at: t,
        );
        if (dep != null && (bestSec == null || dep < bestSec)) bestSec = dep;
      }
    }

    final String operatorLabel = operatorName ?? _operatorFor(routeMapping.network);
    final String sourceUrl = net.meta['source_url'] ?? PassBiSource.sourceUrl;

    if (bestSec == null) {
      // Route mappée, aucun départ calculable → UNKNOWN documenté.
      return DepartureInfo(
        status: ScheduleStatus.unknown,
        operator: operatorLabel,
        routeId: routeId,
        referenceTime: t,
        source: sourceUrl,
        sourceType: SourceType.publicGtfs,
        dateSource: net.meta['date_source'],
        dateVerified: net.meta['date_verified'] ?? PassBiSource.dateVerified,
        validFrom: net.meta['valid_from'],
        validTo: net.meta['valid_to'],
        confidence: 0.8,
      );
    }

    final minOfDay = t.difference(day).inSeconds;
    final waitSec = bestSec - minOfDay;
    final waitMinutes = waitSec ~/ 60;
    final scheduledTime = day.add(Duration(seconds: bestSec));

    return DepartureInfo(
      status: ScheduleStatus.scheduled,
      operator: operatorLabel,
      routeId: routeId,
      referenceTime: t,
      scheduledTime: scheduledTime,
      estimatedWaitFrom: waitMinutes,
      estimatedWaitTo: waitMinutes,
      source: sourceUrl,
      sourceType: SourceType.publicGtfs,
      dateSource: net.meta['date_source'],
      dateVerified: net.meta['date_verified'] ?? PassBiSource.dateVerified,
      validFrom: net.meta['valid_from'],
      validTo: net.meta['valid_to'],
      confidence: 0.8,
    );
  }

  static String _operatorFor(String? network) {
    switch (network) {
      case 'TER':
        return 'TER Dakar';
      case 'BRT':
        return 'SunuBRT';
      case 'DDD':
        return 'Dakar Dem Dikk';
      case 'AFTU':
        return 'AFTU';
      default:
        return 'PassBi';
    }
  }
}
