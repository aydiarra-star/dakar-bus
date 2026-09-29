/// Lot 4.18 — Couche de lecture GTFS réutilisable (format compact PassBi).
///
/// Lit le format produit par `scripts/build-passbi-processed.mjs` :
/// un JSON indexé par réseau (routes/stops/services/exceptions/trips/stop_times).
/// Un seul lecteur sert les quatre feeds PassBi — aucune duplication de code.
///
/// Sémantique calendrier : **ROLLING** (décision produit Lot 4.18) — le motif
/// hebdomadaire publié s'applique comme base de fonctionnement courante jusqu'à
/// remplacement par les données étude/CETUD. Les métadonnées `valid_from` /
/// `valid_to` d'origine sont conservées telles quelles dans [GtfsNetwork.meta]
/// et ne sont jamais falsifiées.
///
/// Sémantique temporelle : SCHEDULED uniquement. Aucun flux temps réel,
/// aucune conversion fréquence → prochain passage.
library;

import 'dart:convert';

class GtfsRoute {
  final String id;
  final String short;
  final String long;
  final int type;
  const GtfsRoute({required this.id, required this.short, required this.long, required this.type});
}

class GtfsStop {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final bool used;
  const GtfsStop({required this.id, required this.name, required this.lat, required this.lon, required this.used});
}

class GtfsService {
  final String id;
  final int mask; // bit0 = lundi … bit6 = dimanche
  final String start; // date d'origine YYYYMMDD (provenance, non bloquante)
  final String end;
  const GtfsService({required this.id, required this.mask, required this.start, required this.end});
}

/// Bornes horaires DOCUMENTÉES d'un `service_id` (Lot fin de service).
///
/// Calculées au chargement à partir des `stop_times` RÉELS de tous les trips
/// du service, en secondes depuis minuit du jour de service. Uniquement des
/// départs EMBARQUABLES (le trip continue après l'arrêt) — un terminus
/// n'est jamais une fin de service.
///
/// Aucune moyenne, aucune estimation : ce sont des extremums du feed.
class GtfsServiceBounds {
  /// Premier départ embarquable du service (secondes depuis minuit).
  final int firstSec;

  /// Dernier départ embarquable du service (secondes depuis minuit).
  final int lastSec;

  const GtfsServiceBounds({required this.firstSec, required this.lastSec});
}

/// Bornes du SERVICE JOURNALIER d'un réseau pour une date donnée : réunion des
/// services actifs ce jour-là, toutes routes, toutes directions et variantes
/// confondues.
///
/// [daySec] est le plus grand `departureSec` du feed entier : il borne la
/// fenêtre horaire réellement documentée. Un premier départ ≥ [daySec] n'est
/// pas une heure suffisamment étayée pour une reprise automatique et est
/// laissé `null`.
class NetworkServiceBounds {
  final int? firstSec;
  final int lastSec;
  final int daySec;
  final int dayOffset;

  const NetworkServiceBounds({
    required this.firstSec,
    required this.lastSec,
    required this.daySec,
    required this.dayOffset,
  });
}

class GtfsTrip {
  final String id;
  final int routeIndex;
  final int serviceIndex; // -1 si service inconnu
  final String direction; // '' si absent du feed (jamais inventé)
  final String headsign;
  const GtfsTrip({
    required this.id,
    required this.routeIndex,
    required this.serviceIndex,
    required this.direction,
    required this.headsign,
  });
}

class GtfsStopTime {
  final int tripIndex;
  final int stopIndex;
  final int sequence;
  final int arrivalSec;
  final int departureSec;
  const GtfsStopTime({
    required this.tripIndex,
    required this.stopIndex,
    required this.sequence,
    required this.arrivalSec,
    required this.departureSec,
  });
}

class GtfsNetwork {
  final String key; // TER | BRT | DDD | AFTU
  final Map<String, String> meta;
  final String agency;
  final List<GtfsRoute> routes;
  final List<GtfsStop> stops;
  final List<GtfsService> services;
  /// serviceId → (date YYYYMMDD → exception_type 1|2)
  final Map<String, Map<String, int>> exceptions;
  final List<GtfsTrip> trips;
  final List<GtfsStopTime> stopTimes;

  final Map<String, int> routeIndexById;
  final Map<String, int> stopIndexById;
  final Map<String, int> serviceIndexById;
  /// stopIndex → stop_times triés par heure de départ.
  final Map<int, List<GtfsStopTime>> stopTimesByStop;
  /// tripIndex → stop_times triés par stop_sequence.
  final Map<int, List<GtfsStopTime>> stopTimesByTrip;
  /// routeIndex → index des trips.
  final Map<int, List<int>> tripsByRoute;

  /// Lot 4.21 — stopIndex → ensemble des index de routes qui appellent
  /// RÉELLEMENT cet arrêt (dérivé des `stop_times`, jamais d'une proximité ni
  /// d'un numéro). Sert au chemin natif PassBi : le prochain départ d'un arrêt
  /// est cherché parmi les lignes qui le desservent effectivement.
  final Map<int, Set<int>> routeIndexesByStop;

  /// Lot fin de service — serviceIndex → bornes horaires documentées (premier
  /// et dernier départ EMBARQUABLE du `service_id`), calculées au chargement.
  final Map<int, GtfsServiceBounds> serviceBounds;

  /// Plus grand `departureSec` du feed : borne la fenêtre horaire documentée.
  final int daySec;

  const GtfsNetwork._({
    required this.key,
    required this.meta,
    required this.agency,
    required this.routes,
    required this.stops,
    required this.services,
    required this.exceptions,
    required this.trips,
    required this.stopTimes,
    required this.routeIndexById,
    required this.stopIndexById,
    required this.serviceIndexById,
    required this.stopTimesByStop,
    required this.stopTimesByTrip,
    required this.tripsByRoute,
    required this.routeIndexesByStop,
    required this.serviceBounds,
    required this.daySec,
  });

  factory GtfsNetwork.fromJson(String key, String jsonString) {
    final dynamic raw = json.decode(jsonString);
    final Map<String, dynamic> root = raw as Map<String, dynamic>;

    final meta = <String, String>{};
    final metaRaw = (root['meta'] as Map<String, dynamic>? ?? const {});
    metaRaw.forEach((k, v) {
      if (v != null) meta[k] = v.toString();
    });

    final routes = <GtfsRoute>[];
    final routeIndexById = <String, int>{};
    for (final r in (root['routes'] as List<dynamic>)) {
      final m = r as Map<String, dynamic>;
      routeIndexById[m['id'] as String] = routes.length;
      routes.add(GtfsRoute(
        id: m['id'] as String,
        short: (m['short'] ?? m['id']) as String,
        long: (m['long'] ?? m['short'] ?? m['id']) as String,
        type: (m['type'] as num?)?.toInt() ?? 3,
      ));
    }

    final stops = <GtfsStop>[];
    final stopIndexById = <String, int>{};
    for (final s in (root['stops'] as List<dynamic>)) {
      final l = s as List<dynamic>;
      stopIndexById[l[0] as String] = stops.length;
      stops.add(GtfsStop(
        id: l[0] as String,
        name: l[1] as String,
        lat: (l[2] as num?)?.toDouble() ?? 0,
        lon: (l[3] as num?)?.toDouble() ?? 0,
        used: ((l[4] as num?)?.toInt() ?? 0) == 1,
      ));
    }

    final services = <GtfsService>[];
    final serviceIndexById = <String, int>{};
    for (final s in (root['services'] as List<dynamic>)) {
      final l = s as List<dynamic>;
      serviceIndexById[l[0] as String] = services.length;
      services.add(GtfsService(
        id: l[0] as String,
        mask: (l[1] as num).toInt(),
        start: (l[2] ?? '') as String,
        end: (l[3] ?? '') as String,
      ));
    }

    final exceptions = <String, Map<String, int>>{};
    for (final e in (root['exceptions'] as List<dynamic>? ?? const [])) {
      final l = e as List<dynamic>;
      final svc = l[0] as String;
      final date = l[1] as String;
      final type = (l[2] as num).toInt();
      (exceptions[svc] ??= <String, int>{})[date] = type;
    }

    final trips = <GtfsTrip>[];
    final tripsByRoute = <int, List<int>>{};
    for (final t in (root['trips'] as List<dynamic>)) {
      final l = t as List<dynamic>;
      final idx = trips.length;
      trips.add(GtfsTrip(
        id: l[0] as String,
        routeIndex: (l[1] as num).toInt(),
        serviceIndex: (l[2] as num).toInt(),
        direction: (l[3] ?? '') as String,
        headsign: (l[4] ?? '') as String,
      ));
      (tripsByRoute[trips[idx].routeIndex] ??= <int>[]).add(idx);
    }

    final stopTimes = <GtfsStopTime>[];
    final stopTimesByStop = <int, List<GtfsStopTime>>{};
    final stopTimesByTrip = <int, List<GtfsStopTime>>{};
    final routeIndexesByStop = <int, Set<int>>{};
    for (final st in (root['stop_times'] as List<dynamic>)) {
      final l = st as List<dynamic>;
      final item = GtfsStopTime(
        tripIndex: (l[0] as num).toInt(),
        stopIndex: (l[1] as num).toInt(),
        sequence: (l[2] as num).toInt(),
        arrivalSec: (l[3] as num?)?.toInt() ?? -1,
        departureSec: (l[4] as num?)?.toInt() ?? -1,
      );
      stopTimes.add(item);
      (stopTimesByStop[item.stopIndex] ??= <GtfsStopTime>[]).add(item);
      (stopTimesByTrip[item.tripIndex] ??= <GtfsStopTime>[]).add(item);
      // Lot 4.21 : desserte réelle de l'arrêt (une seule passe, aucun coût
      // supplémentaire au chargement).
      (routeIndexesByStop[item.stopIndex] ??= <int>{})
          .add(trips[item.tripIndex].routeIndex);
    }
    for (final list in stopTimesByStop.values) {
      list.sort((a, b) => a.departureSec.compareTo(b.departureSec));
    }
    for (final list in stopTimesByTrip.values) {
      list.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    // Lot fin de service — bornes horaires documentées par `service_id`,
    // calculées une seule fois au chargement. Seuls les départs EMBARQUABLES
    // comptent (`_tripContinuesPast`) : un trip terminé à l'arrêt n'est jamais
    // une fin de service. Aucune moyenne, aucune estimation — que des
    // extremums réels du feed.
    final serviceBounds = <int, GtfsServiceBounds>{};
    int daySec = 0;
    for (final st in stopTimes) {
      if (st.departureSec > daySec) daySec = st.departureSec;
      if (!_tripContinuesPastStatic(st, stopTimesByTrip)) continue;
      final trip = trips[st.tripIndex];
      if (trip.serviceIndex < 0) continue;
      final existing = serviceBounds[trip.serviceIndex];
      if (existing == null) {
        serviceBounds[trip.serviceIndex] = GtfsServiceBounds(
          firstSec: st.departureSec,
          lastSec: st.departureSec,
        );
      } else {
        serviceBounds[trip.serviceIndex] = GtfsServiceBounds(
          firstSec: st.departureSec < existing.firstSec ? st.departureSec : existing.firstSec,
          lastSec: st.departureSec > existing.lastSec ? st.departureSec : existing.lastSec,
        );
      }
    }

    return GtfsNetwork._(
      key: key,
      meta: meta,
      agency: (root['agency'] ?? key) as String,
      routes: routes,
      stops: stops,
      services: services,
      exceptions: exceptions,
      trips: trips,
      stopTimes: stopTimes,
      routeIndexById: routeIndexById,
      stopIndexById: stopIndexById,
      serviceIndexById: serviceIndexById,
      stopTimesByStop: stopTimesByStop,
      stopTimesByTrip: stopTimesByTrip,
      tripsByRoute: tripsByRoute,
      routeIndexesByStop: routeIndexesByStop,
      serviceBounds: serviceBounds,
      daySec: daySec,
    );
  }

  /// Un service est actif si une exception datée le concerne (1 = ajouté,
  /// 2 = retiré), sinon si son motif hebdomadaire couvre le jour demandé.
  /// La fenêtre d'origine (start/end) n'est PAS un blocage en mode ROLLING.
  bool serviceActiveOn(int serviceIndex, DateTime day) {
    if (serviceIndex < 0 || serviceIndex >= services.length) return false;
    final service = services[serviceIndex];
    final dateKey = '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
    final exc = exceptions[service.id];
    if (exc != null && exc.containsKey(dateKey)) {
      return exc[dateKey] == 1;
    }
    final weekdayBit = day.weekday - 1; // lundi = 0
    return (service.mask & (1 << weekdayBit)) != 0;
  }

  /// Nombre de services actifs ce jour-là (modes tests / diagnostics).
  int activeServiceCountOn(DateTime day) =>
      services.asMap().entries.where((e) => serviceActiveOn(e.key, day)).length;

  /// Lot fin de service — bornes du service journalier du réseau pour [day].
  ///
  /// Réunion de tous les `service_id` actifs ce jour-là (calendar +
  /// calendar_dates), toutes routes, directions et variantes confondues :
  ///   * [NetworkServiceBounds.lastSec] — dernier départ embarquable documenté ;
  ///   * [NetworkServiceBounds.firstSec] — premier départ documenté (brut, peut
  ///     valoir 0 pour un service de nuit type DDD) ;
  ///   * [NetworkServiceBounds.daySec] — borne du feed entier ;
  ///   * [NetworkServiceBounds.dayOffset] — décalage (1..7) vers le prochain
  ///     jour de service documenté lorsque [day] lui-même n'en a aucun
  ///     (reprise honnête, sans heure inventée).
  ///
  /// Aucune heure n'est inventée : une valeur absente reste `null`.
  NetworkServiceBounds networkServiceBounds(DateTime day) {
    final int? first = firstDepartureSecOn(day);
    final int last = lastDepartureSecOn(day);
    if (last >= 0) {
      return NetworkServiceBounds(
        firstSec: first,
        lastSec: last,
        daySec: daySec,
        dayOffset: 0,
      );
    }
    // Aucun service actif ce jour-là : on cherche le prochain jour de service
    // documenté (jusqu'à 7 jours) pour une reprise honnête — aucune heure n'est
    // inventée si rien n'est trouvé.
    final resumption = nextServiceResumption(day);
    return NetworkServiceBounds(
      firstSec: resumption?.firstSec,
      lastSec: resumption == null ? -1 : lastDepartureSecOn(resumption.day),
      daySec: daySec,
      dayOffset: resumption?.dayOffset ?? 0,
    );
  }

  /// Premier départ EMBARQUABLE documenté du service actif de [day], `null` si
  /// ce jour n'a aucun service actif. Peut valoir `0` — un service de nuit qui
  /// commence à 00:00 n'est jamais écarté.
  int? firstDepartureSecOn(DateTime day) {
    if (!_hasActiveServiceOn(day)) return null;
    return _firstSec((int si) => serviceActiveOn(si, day));
  }

  /// Dernier départ EMBARQUABLE documenté du service actif de [day], `-1` si
  /// ce jour n'a aucun service actif.
  int lastDepartureSecOn(DateTime day) {
    if (!_hasActiveServiceOn(day)) return -1;
    return _lastSec((int si) => serviceActiveOn(si, day));
  }

  bool _hasActiveServiceOn(DateTime day) {
    for (int i = 0; i < services.length; i++) {
      if (serviceActiveOn(i, day)) return true;
    }
    return false;
  }

  /// Prochain jour de service STRICTEMENT postérieur à [afterDay] (jusqu'à
  /// [maxDays] jours) avec son premier départ documenté : base de la reprise
  /// T-1h. `null` si aucun service documenté n'est trouvé — jamais inventé.
  ({DateTime day, int firstSec, int dayOffset})? nextServiceResumption(
    DateTime afterDay, {
    int maxDays = 7,
  }) {
    for (int d = 1; d <= maxDays; d++) {
      final day = DateTime.utc(afterDay.year, afterDay.month, afterDay.day + d);
      final int? first = firstDepartureSecOn(day);
      if (first != null) {
        return (day: day, firstSec: first, dayOffset: d);
      }
    }
    return null;
  }

  /// Plus petit premier départ documenté parmi les services sélectionnés par
  /// [active], `null` si aucun.
  int? _firstSec(bool Function(int) active) {
    int? best;
    for (final e in serviceBounds.entries) {
      if (!active(e.key)) continue;
      final f = e.value.firstSec;
      if (best == null || f < best) best = f;
    }
    return best;
  }

  /// Plus grand dernier départ documenté parmi les services sélectionnés par
  /// [active], `-1` si aucun.
  int _lastSec(bool Function(int) active) {
    int last = -1;
    for (final e in serviceBounds.entries) {
      if (!active(e.key)) continue;
      if (e.value.lastSec > last) last = e.value.lastSec;
    }
    return last;
  }

  static DateTime _dakarDay(DateTime at) {
    final t = at.isUtc ? at : at.toUtc();
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// Variante statique de [_tripContinuesPast], utilisée au chargement des
  /// bornes de service (avant que les maps ne soient des champs d'instance).
  static bool _tripContinuesPastStatic(
      GtfsStopTime st, Map<int, List<GtfsStopTime>> byTrip) {
    final rows = byTrip[st.tripIndex];
    if (rows == null || rows.isEmpty) return false;
    return st.sequence < rows.last.sequence;
  }

  /// Prochain départ (secondes depuis minuit du jour de service) pour une
  /// route et un arrêt donnés, à partir de [at] (convention Dakar UTC+0,
  /// identique à DataProvider). Retourne null si aucun départ calculable —
  /// jamais une fréquence, jamais un horaire inventé.
  ///
  /// Corrections Lot 4.19 (régression : tests/passbi-functional-419.test.js,
  /// passbi_functional_419_test.dart) :
  ///  A — seuls les départs EMBARQUABLES comptent : un trip terminé à l'arrêt
  ///      (arrêt = fin de trip) ne produit qu'une arrivée, jamais un
  ///      « prochain départ » (les lignes d'arrivée ne sont plus affichées) ;
  ///  B — scan sur 7 jours glissants : après le dernier départ du jour, le
  ///      service J+1..J+6 est retrouvé avec son propre service_id
  ///      (passage 23:59 → 00:00, jours sans service inclus).
  int? nextDepartureSec({
    required int routeIndex,
    required int stopIndex,
    required DateTime at,
  }) {
    final since = at.isUtc ? at : at.toUtc();
    final day0 = _dakarDay(since);
    final minOfDay0 = since.difference(day0).inSeconds;
    for (int d = 0; d < 7; d++) {
      final day = DateTime.utc(day0.year, day0.month, day0.day + d);
      final minOfDay = d == 0 ? minOfDay0 : 0;
      final list = stopTimesByStop[stopIndex];
      if (list == null) return null;
      int? best;
      for (final st in list) {
        if (st.departureSec < minOfDay) continue;
        final trip = trips[st.tripIndex];
        if (trip.routeIndex != routeIndex) continue;
        if (!serviceActiveOn(trip.serviceIndex, day)) continue;
        if (!_tripContinuesPast(st)) continue;
        if (best == null || st.departureSec < best) best = st.departureSec;
      }
      if (best != null) {
        // Absolu depuis minuit du jour demandé : la couche ScheduleProvider
        // calcule `scheduledTime = day0 + bestSec` — en J+1, le service se
        // place donc bien après minuit (passage 23:59 → 00:00).
        return best + d * 86400;
      }
    }
    return null;
  }

  /// Lot 4.19 A — True si le trip a encore des arrêts APRÈS cette row :
  /// montée possible (sinon : arrivée de terminus, jamais un départ affiché).
  bool _tripContinuesPast(GtfsStopTime st) {
    final rows = stopTimesByTrip[st.tripIndex];
    if (rows == null || rows.isEmpty) return false;
    return st.sequence < rows.last.sequence;
  }

  /// Lot 4.21 — Prochain départ EMBARQUABLE parmi un ENSEMBLE de routes, en
  /// une seule passe sur les `stop_times` de l'arrêt.
  ///
  /// [nextDepartureSec] (Lot 4.19) est conservé strictement inchangé pour ses
  /// appels existants ; cette variante ajoute ce dont le chemin natif
  /// DDD/AFTU a besoin : l'index de la route qui part EFFECTIVEMENT, afin que
  /// l'affichage utilise les métadonnées PassBi réelles de cette ligne (§2 du
  /// lot) et jamais une ligne déduite d'un numéro ou d'une proximité.
  ///
  /// Mêmes garde-fous que [nextDepartureSec] :
  ///  * départ embarquable uniquement (le trip continue après l'arrêt) ;
  ///  * service actif évalué par jour (calendar + calendar_dates) ;
  ///  * 7 jours glissants (passage 23:59 → 00:00, jours sans service) ;
  ///  * `null` si aucun départ n'est calculable — jamais une fréquence,
  ///    jamais un horaire inventé, jamais REAL_TIME.
  ///
  /// `sec` est absolu depuis minuit du jour demandé (> 86400 = J+1..J+6).
  ({int sec, int routeIndex, int tripIndex, int dayOffset})? nextDepartureAmong({
    required Set<int> routeIndexes,
    required int stopIndex,
    required DateTime at,
  }) {
    if (routeIndexes.isEmpty) return null;
    final list = stopTimesByStop[stopIndex];
    if (list == null) return null;
    final since = at.isUtc ? at : at.toUtc();
    final day0 = _dakarDay(since);
    final minOfDay0 = since.difference(day0).inSeconds;
    for (int d = 0; d < 7; d++) {
      final day = DateTime.utc(day0.year, day0.month, day0.day + d);
      final minOfDay = d == 0 ? minOfDay0 : 0;
      // `list` est triée par heure de départ croissante : la première ligne
      // qui passe tous les filtres EST le minimum du jour (aucun `best`
      // nécessaire, aucune passe supplémentaire).
      for (final st in list) {
        if (st.departureSec < minOfDay) continue;
        final trip = trips[st.tripIndex];
        if (!routeIndexes.contains(trip.routeIndex)) continue;
        if (!serviceActiveOn(trip.serviceIndex, day)) continue;
        if (!_tripContinuesPast(st)) continue;
        return (
          sec: st.departureSec + d * 86400,
          routeIndex: trip.routeIndex,
          tripIndex: st.tripIndex,
          dayOffset: d,
        );
      }
    }
    return null;
  }

  /// Lot fin de service — prochain départ EMBARQUABLE d'un ensemble de routes
  /// et d'un arrêt, **limité au SEUL jour de service de [at]** (aucun balayage
  /// multi-jours). C'est la primitive du pipeline d'affichage : un départ du
  /// service SUIVANT (lendemain, jour de service suivant) ne doit jamais être
  /// présenté comme une attente du service en cours (c'est l'origine des
  /// attentes aberrantes de plusieurs centaines de minutes, ex. 508 min).
  ///
  /// Le service applicable et le service suivant sont traités séparément par
  /// [ServiceAvailability] (fin de service + reprise T-1h).
  ({int sec, int routeIndex, int tripIndex, int dayOffset})?
      nextDepartureAmongWithin({
    required Set<int> routeIndexes,
    required int stopIndex,
    required DateTime at,
  }) {
    if (routeIndexes.isEmpty) return null;
    final list = stopTimesByStop[stopIndex];
    if (list == null) return null;
    final since = at.isUtc ? at : at.toUtc();
    final day0 = _dakarDay(since);
    final minOfDay0 = since.difference(day0).inSeconds;
    for (final st in list) {
      if (st.departureSec < minOfDay0) continue;
      final trip = trips[st.tripIndex];
      if (!routeIndexes.contains(trip.routeIndex)) continue;
      if (!serviceActiveOn(trip.serviceIndex, day0)) continue;
      if (!_tripContinuesPast(st)) continue;
      return (
        sec: st.departureSec,
        routeIndex: trip.routeIndex,
        tripIndex: st.tripIndex,
        dayOffset: 0,
      );
    }
    return null;
  }

  /// Lot 4.21 — Index des routes appelant réellement un arrêt (dérivé des
  /// `stop_times` au chargement). Ensemble vide si l'arrêt n'est pas appelé.
  Set<int> routeIndexesCalling(int stopIndex) =>
      routeIndexesByStop[stopIndex] ?? const <int>{};

  /// Tous les départs actifs d'une route à un arrêt pour une date donnée.
  List<int> departuresSecOn({
    required int routeIndex,
    required int stopIndex,
    required DateTime day,
  }) {
    final result = <int>[];
    final list = stopTimesByStop[stopIndex];
    if (list == null) return result;
    for (final st in list) {
      final trip = trips[st.tripIndex];
      if (trip.routeIndex != routeIndex) continue;
      if (!serviceActiveOn(trip.serviceIndex, day)) continue;
      if (!_tripContinuesPast(st)) continue; // (Lot 4.19 A) embarquable seul
      result.add(st.departureSec);
    }
    return result;
  }

  /// Routes (index) réellement appelées à un arrêt.
  List<int> routesCallingAt(int stopIndex) {
    final seen = <int>{};
    final list = stopTimesByStop[stopIndex];
    if (list == null) return const <int>[];
    for (final st in list) {
      seen.add(trips[st.tripIndex].routeIndex);
    }
    return seen.toList(growable: false);
  }
}
