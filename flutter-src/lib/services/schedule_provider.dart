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
import 'documented_route_identity.dart';
import 'gtfs/gtfs_source.dart';
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
    //
    // Lot 4.22 : la recherche conserve le `tripId` réel (même moteur
    // [PassBiSource.nextNativeDeparture] : embarquable + service actif + 7
    // jours glissants) afin d'afficher le sens RÉEL du trip (headsign du
    // feed) — jamais une destination déduite d'un nom, d'un numéro de ligne
    // ou d'une proximité.
    ({int sec, String routeId, String tripId, int dayOffset})? best;
    for (final pbRouteId in routeMapping.pbRouteIds) {
      final found = passBi.nextNativeDeparture(
        networkKey: parts[0],
        pbStopId: parts[1],
        at: t,
        onlyRouteId: pbRouteId,
      );
      if (found != null && (best == null || found.sec < best.sec)) best = found;
    }

    final String operatorLabel = operatorName ?? _operatorFor(routeMapping.network);
    final String sourceUrl = net.meta['source_url'] ?? PassBiSource.sourceUrl;

    if (best == null) {
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
        // Paramètres requis par DepartureInfo : aucune fréquence ni sens
        // n'est attaché à un départ programmé (null = non déterminé ici,
        // exactement comme DepartureInfo.unknown).
        frequencyMinutes: null,
        operatingHours: null,
        direction: null,
        // Lot 4.21 §3 : la route est mappée (identité publique confirmée) mais
        // aucun départ n'est calculable dans ce contexte temporel.
        identityStatus: IdentityStatus.confirmed,
        unresolvedReason: UnresolvedReason.noComputableDeparture,
      );
    }

    final minOfDay = t.difference(day).inSeconds;
    final waitSec = best.sec - minOfDay;
    final waitMinutes = waitSec ~/ 60;
    final scheduledTime = day.add(Duration(seconds: best.sec));

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
      // Sens réel du trip (headsign du feed) — jamais déduit. Aucune fréquence
      // n'est attachée à un départ programmé.
      frequencyMinutes: null,
      operatingHours: null,
      direction: _tripDirection(net, best.tripId),
      // Lot 4.21 §3 : le crosswalk a confirmé cette identité publique.
      identityStatus: IdentityStatus.confirmed,
      identityNote: 'Identité publique confirmée par le référentiel documenté.',
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
        // Repli neutre : le nom de la source de données (PassBi) n'est jamais
        // affiché par l'interface.
        return 'Bus';
    }
  }

  // ======================================================================
  // LOT 4.21 — CHEMIN NATIF : PassBi → ScheduleProvider → DepartureInfo → UI
  // ======================================================================

  /// §3 — Raison précise d'un UNKNOWN sur le chemin du référentiel dakar.
  ///
  /// Distinctions imposées par le lot (aucune confusion entre identité
  /// publique, disponibilité de la donnée PassBi et départ calculable) :
  ///  * `SOURCE_PASSBI_INACTIVE`   — feeds non chargés ;
  ///  * `RESEAU_ABSENT_DU_FEED`    — aucun feed PassBi pour ce réseau (TATA) ;
  ///  * `IDENTITE_NON_CONFIRMEE`   — crosswalk UNMAPPED : aucun couple
  ///    (route, arrêt) PassBi n'est rattachable à cette identité dakar, donc
  ///    AUCUN horaire ne peut lui être attribué sans inventer une identité ;
  ///  * `ARRET_NON_CORRESPONDU`    — route mappée, arrêt sans plateforme PassBi ;
  ///  * `AUCUN_DEPART_CALCULABLE`  — route + arrêt résolus, aucun départ
  ///    embarquable dans le contexte temporel (7 jours glissants).
  String unresolvedReasonFor({
    required String routeId,
    required String? stopId,
  }) {
    if (!passBi.isActive) return UnresolvedReason.sourceInactive;
    final mapping = passBi.routeMapping(routeId);
    if (mapping == null) return UnresolvedReason.networkAbsentFromFeed;
    if (!mapping.isMapped) {
      return mapping.network == null
          ? UnresolvedReason.networkAbsentFromFeed
          : UnresolvedReason.identityUnconfirmed;
    }
    if (stopId == null) return UnresolvedReason.stopNotMatched;
    final stopMapping = passBi.stopMappingFor(routeId, stopId);
    if (stopMapping == null) return UnresolvedReason.stopNotMatched;
    return UnresolvedReason.noComputableDeparture;
  }

  /// §2/§4/§5/§9 — Prochain départ sur le RÉFÉRENTIEL NATIF PassBi.
  ///
  /// Aucun mapping d'identité n'est requis : la route et l'arrêt sont ceux du
  /// feed. Le prochain départ provient d'un véritable `trip` + `stop_time`
  /// PassBi dont le service est actif — jamais d'une fréquence, jamais d'une
  /// estimation, jamais REAL_TIME.
  ///
  /// L'identité d'affichage est construite exclusivement à partir des
  /// métadonnées PassBi réellement présentes ([identityLabelFor]) :
  /// « Ligne PassBi DDD_217 » lorsque l'identité publique n'est pas confirmée.
  ///
  /// Retourne un [DepartureInfo] `scheduled` (🟢 X min) ou `unknown`
  /// (horaire indisponible + raison précise).
  ///
  /// [isPublicHoliday] est accepté pour la symétrie d'API avec le chemin du
  /// référentiel dakar ; le chemin natif ne l'utilise pas : l'activation d'un
  /// service est évaluée **par date** sur le feed (calendar + calendar_dates),
  /// jamais par une hypothèse de jour férié.
  DepartureInfo departureAtPassBiStop({
    required String networkKey,
    required String pbStopId,
    required DateTime requestedAt,
    String? pbRouteId,
    bool isPublicHoliday = false,
  }) {
    final net = passBi.network(networkKey);
    if (net == null) {
      return DepartureInfo.unknown(
        operator: _operatorFor(networkKey),
        routeId: pbRouteId ?? networkKey,
        requestedAt: requestedAt,
        unresolvedReason: UnresolvedReason.networkAbsentFromFeed,
      );
    }

    final DateTime t = requestedAt.isUtc ? requestedAt : requestedAt.toUtc();
    final day = DateTime.utc(t.year, t.month, t.day);
    final String sourceUrl = net.meta['source_url'] ?? PassBiSource.sourceUrl;
    final String operatorLabel =
        net.agency.isNotEmpty ? net.agency : _operatorFor(networkKey);

    final found = passBi.nextNativeDeparture(
      networkKey: networkKey,
      pbStopId: pbStopId,
      at: t,
      onlyRouteId: pbRouteId,
    );

    if (found == null) {
      final summary = pbRouteId == null
          ? null
          : passBi.routeSummary(networkKey, pbRouteId);
      final String reason = (summary != null && !summary.scheduleAvailable)
          ? UnresolvedReason.noStopTimesInFeed
          : UnresolvedReason.noComputableDeparture;
      return DepartureInfo(
        status: ScheduleStatus.unknown,
        operator: operatorLabel,
        routeId: pbRouteId ?? pbStopId,
        referenceTime: t,
        source: sourceUrl,
        sourceType: SourceType.publicGtfs,
        dateSource: net.meta['date_source'],
        dateVerified: net.meta['date_verified'] ?? PassBiSource.dateVerified,
        validFrom: net.meta['valid_from'],
        validTo: net.meta['valid_to'],
        confidence: 0.8,
        frequencyMinutes: null,
        operatingHours: null,
        direction: null,
        identityStatus: pbRouteId == null
            ? IdentityStatus.unconfirmed
            : passBi.identityStatusOf(networkKey, pbRouteId),
        identityNote: pbRouteId == null
            ? null
            : 'Identité publique non confirmée ; métadonnées du feed utilisées '
                'telles quelles (route_id, short_name, long_name).',
        unresolvedReason: reason,
      );
    }

    final String routeId = found.routeId;
    final minOfDay = t.difference(day).inSeconds;
    final waitMinutes = (found.sec - minOfDay) ~/ 60;
    final scheduledTime = day.add(Duration(seconds: found.sec));
    final IdentityStatus identity =
        passBi.identityStatusOf(networkKey, routeId);
    final summary = passBi.routeSummary(networkKey, routeId);

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
      // Aucune fréquence n'est attachée à un départ programmé.
      frequencyMinutes: null,
      operatingHours: null,
      // Sens réel du trip (direction_id du feed) — jamais déduit.
      direction: _tripDirection(net, found.tripId),
      identityStatus: identity,
      identityNote: identity == IdentityStatus.confirmed
          ? 'Identité publique confirmée par le référentiel documenté '
              '(${passBi.dakarRouteIdsFor(networkKey, routeId).join(', ')}).'
          : 'Identité publique UNCONFIRMED ; horaire techniquement calculable '
              '(route + trip + stop + stop_time + service actif). '
              'Affichage : métadonnées réelles du feed.',
      lineLabel: identityLabelFor(networkKey, routeId, identity,
          shortName: summary?.shortName),
      unresolvedReason: null,
    );
  }

  // ======================================================================
  // LOT 4.22 (EXPLORER) — JUSQU'À 3 PROCHAINS PASSAGES RÉELS
  // ======================================================================

  /// Jusqu'à [limit] prochains passages RÉELS sur un arrêt natif PassBi, dans
  /// l'ordre chronologique strict, à partir de [requestedAt].
  ///
  /// Logique (aucune donnée inventée) :
  ///  1. partir de l'heure actuelle ;
  ///  2. chercher le prochain `stop_time` réel (trip + stop_time + service
  ///      actif — [departureAtPassBiStop]) ;
  ///  3. son horaire absolu est `scheduledTime` (secondes absolues, `dayOffset`
  ///      du feed inclus : le passage de minuit place correctement le service
  ///      en J+1) ;
  ///  4. avancer d'UNE SECONDE juste après ce passage ;
  ///  5. rechercher le suivant ;
  ///  6. répéter jusqu'à [limit] passages (3 par défaut) ;
  ///  7. s'arrêter dès qu'il n'y a plus de passage réel.
  ///
  /// JAMAIS d'avancée par fréquence : un départ ESTIMATED/fréquence ne
  /// produit AUCUNE liste de passages (jamais « 6 mn · 12 mn · 18 mn » à
  /// partir d'une fréquence de 6 min). Un départ déjà passé est ignoré.
  List<DepartureInfo> nextDeparturesAtPassBiStop({
    required String networkKey,
    required String pbStopId,
    required DateTime requestedAt,
    String? pbRouteId,
    int limit = 3,
  }) {
    final out = <DepartureInfo>[];
    if (limit < 1) return out;
    final DateTime start =
        requestedAt.isUtc ? requestedAt : requestedAt.toUtc();
    DateTime cursor = start;
    while (out.length < limit) {
      final info = departureAtPassBiStop(
        networkKey: networkKey,
        pbStopId: pbStopId,
        requestedAt: cursor,
        pbRouteId: pbRouteId,
      );
      if (info.status != ScheduleStatus.scheduled) break;
      final DateTime? departureTime = info.scheduledTime;
      if (departureTime == null) break;
      if (departureTime.isBefore(start)) {
        // Bord de troncature à la seconde : le passage est déjà passé → ignoré.
        cursor = departureTime.add(const Duration(seconds: 1));
        continue;
      }
      out.add(info);
      // Juste après ce passage réel — jamais une fréquence.
      cursor = departureTime.add(const Duration(seconds: 1));
    }
    return out;
  }

  /// Jusqu'à [limit] prochains passages RÉELS pour un couple (route, arrêt)
  /// du référentiel dakar résolu par le crosswalk PassBi (TER, BRT…).
  ///
  /// Mêmes règles que [nextDeparturesAtPassBiStop] : uniquement de vrais
  /// trips + stop_times ; une route non mappée ou sans départ calculable
  /// retourne une liste vide — jamais de série issue d'une fréquence
  /// (« 6 mn · 12 mn · 18 mn » est interdit).
  List<DepartureInfo> nextDeparturesAt({
    required String routeId,
    required String? stopId,
    required DateTime requestedAt,
    bool isPublicHoliday = false,
    String? operatorName,
    int limit = 3,
  }) {
    final out = <DepartureInfo>[];
    if (limit < 1) return out;
    final DateTime start =
        requestedAt.isUtc ? requestedAt : requestedAt.toUtc();
    DateTime cursor = start;
    while (out.length < limit) {
      final info = departureAt(
        routeId: routeId,
        stopId: stopId,
        requestedAt: cursor,
        isPublicHoliday: isPublicHoliday,
        operatorName: operatorName,
      );
      if (info == null || info.status != ScheduleStatus.scheduled) break;
      final DateTime? departureTime = info.scheduledTime;
      if (departureTime == null) break;
      if (departureTime.isBefore(start)) {
        cursor = departureTime.add(const Duration(seconds: 1));
        continue;
      }
      out.add(info);
      cursor = departureTime.add(const Duration(seconds: 1));
    }
    return out;
  }

  /// Sens réel d'un trip (`direction_id` du feed). `null` si le feed n'en
  /// fournit pas : jamais inventé.
  static String? _tripDirection(GtfsNetwork net, String tripId) {
    for (final t in net.trips) {
      if (t.id == tripId) {
        if (t.headsign.isNotEmpty) return t.headsign;
        if (t.direction.isNotEmpty) return t.direction;
        return null;
      }
    }
    return null;
  }

  /// §2 — Identité d'affichage d'une ligne, construite UNIQUEMENT à partir
  /// d'une identité PUBLIQUE DOCUMENTÉE ([DocumentedRouteRegistry]). Le nom de
  /// la source de données (PassBi) n'apparaît jamais.
  ///
  ///  * identité publique confirmée par le référentiel documenté
  ///    ([RouteMapping.isMapped], ex. « BRT B1 ») → cette identité ;
  ///  * numéro public DOCUMENTÉ (DDD/AFTU, via [DocumentedRouteRegistry]) →
  ///    « DDD 217 », « AFTU 54 » ;
  ///  * sinon → le MODE du réseau seul (« DDD », « AFTU »), sans numéro.
  ///
  /// Un identifiant interne (`DDD_217`, `tata_218`) n'est JAMAIS présenté comme
  /// un numéro public : il est confronté au registre documenté, et sans preuve
  /// seul le mode est affiché. Aucun nom commercial inventé, aucune
  /// origine/destination déduite du numéro, aucune identité fabriquée.
  static String identityLabelFor(
    String networkKey,
    String pbRouteId,
    IdentityStatus identity, {
    String? shortName,
  }) {
    if (identity == IdentityStatus.confirmed) {
      return pbRouteId.startsWith(networkKey) ? pbRouteId : '$networkKey $pbRouteId';
    }
    // Identité publique documentée, adossée à une source vérifiable.
    final DocumentedRouteIdentity documented =
        DocumentedRouteRegistry.resolveRouteId(networkKey, pbRouteId);
    if (documented.documented && documented.publicRouteNumber != null) {
      // Identité TATA CONFIRMÉE par une source admissible → « Tata N ».
      // Aucune ligne n'étant confirmée en l'état, le repli « AFTU N » s'applique.
      final String? tata = DocumentedRouteRegistry.confirmedTataLabel(
          networkKey, documented.publicRouteNumber);
      if (tata != null) return tata;
      return '$networkKey ${documented.publicRouteNumber}';
    }
    // Aucune preuve documentaire : repli honnête sur le MODE du réseau.
    return networkKey;
  }
}
