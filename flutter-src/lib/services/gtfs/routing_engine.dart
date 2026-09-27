/// Lot 4.18 — Moteur de routage sur les données PassBi réelles.
///
/// Structure utilisée : route → trip → service → stop → stop_sequence →
/// horaire → correspondance.
///
/// Garde-fous (Lot 4.18) :
///  * un trajet n'emprunte que des `stop_sequence` réellement présents dans
///    les données (jamais de liaison par proximité seule) ;
///  * une correspondance n'existe qu'au même arrêt physique ou via un lien
///    documenté du crosswalk (nom vérifié + distance ≤ 500 m) ;
///  * les services doivent être actifs à la date demandée (mode ROLLING) ;
///  * aucune donnée n'est inventée : sans chemin possible → liste vide ;
///  * jamais de REAL_TIME (horaires programmés uniquement).
///
/// TER ↔ bus, BRT ↔ DDD, BRT ↔ AFTU, DDD ↔ AFTU : les paires de réseaux
/// sont traitées uniformément grâce aux liens de transfert du crosswalk.
library;

import 'passbi_source.dart';

class PassBiLeg {
  final String network; // TER | BRT | DDD | AFTU
  final String routeId;
  final String routeLabel;
  final String tripId; // trip GTFS exact — identité du véhicule (Lot 4.19)
  final String fromStopId;
  final String fromStopName;
  final String toStopId;
  final String toStopName;
  final int departureSec;
  final int arrivalSec;
  final String headsign;

  const PassBiLeg({
    required this.network,
    required this.routeId,
    required this.routeLabel,
    required this.tripId,
    required this.fromStopId,
    required this.fromStopName,
    required this.toStopId,
    required this.toStopName,
    required this.departureSec,
    required this.arrivalSec,
    required this.headsign,
  });

  int get durationMinutes => ((arrivalSec - departureSec) / 60).ceil();
}

class PassBiJourney {
  final String originKey;
  final String destinationKey;
  final List<PassBiLeg> legs;
  final int transferCount;
  final int departureSec;
  final int arrivalSec;

  const PassBiJourney({
    required this.originKey,
    required this.destinationKey,
    required this.legs,
    required this.transferCount,
    required this.departureSec,
    required this.arrivalSec,
  });

  int get totalMinutes => ((arrivalSec - departureSec) / 60).ceil();
}

class _SearchState {
  final String stopKey;
  final int timeSec;
  final List<PassBiLeg> legs;
  const _SearchState(this.stopKey, this.timeSec, this.legs);
}

class PassBiRoutingEngine {
  final PassBiSource source;

  /// Bornes de recherche (documentées) : horizon 6 h, 2 correspondances
  /// maximum, budget d'exploration borné — restent déterministes.
  final int horizonSec;
  final int maxTransfers;
  final int maxExplorations;

  PassBiRoutingEngine(
    this.source, {
    this.horizonSec = 6 * 3600,
    this.maxTransfers = 2,
    this.maxExplorations = 6000,
  });

  bool get isActive => source.isActive;

  /// Planning entre ensembles d'arrêts PassBi (clés composites).
  /// Retourne les trajets triés par heure d'arrivée (≤ [maxResults]).
  ///
  /// Corrections Lot 4.19 (régression passbi-functional-419.test.js et
  /// passbi_functional_419_test.dart) :
  ///  B — passage 23:59 → 00:00 : deux passes, jour J puis J+1 (services,
  ///      calendar, calendar_dates et jours sans service évalués sur le bon
  ///      jour), résultats fusionnés puis triés par arrivée ;
  ///  C — l'horizon (6 h) borne le DEBARQUEMENT : le premier véhicule doit
  ///      être pris dans l'horizon, mais une arrivée au-delà reste valide
  ///      (elle était auparavant supprimée, perdant un trajet J+1 réel).
  List<PassBiJourney> planJourneys({
    required Set<String> fromKeys,
    required Set<String> toKeys,
    required DateTime at,
    int maxResults = 4,
  }) {
    if (!source.isActive || fromKeys.isEmpty || toKeys.isEmpty) {
      return const <PassBiJourney>[];
    }
    final DateTime t = at.isUtc ? at : at.toUtc();
    final day = DateTime.utc(t.year, t.month, t.day);
    final int startSec = t.difference(day).inSeconds;

    final results = <PassBiJourney>[];
    // L'axe temporel reste ancré à minuit de J0 pour les DEUX passes : seul le
    // scan des horaires est décalé (offset jour) pour lire les services J+1.
    // L'horizon (embarquement) reste donc « maintenant + 6 h » — c'est ce qui
    // autorise un départ du lendemain matin trouvé à 23:59 (Lot 4.19 B).
    for (int shift = 0; shift <= 1; shift++) {
      results.addAll(_searchDay(
        fromKeys: fromKeys,
        toKeys: toKeys,
        day: DateTime.utc(day.year, day.month, day.day + shift),
        offset: shift * 86400,
        startSec: startSec,
        maxResults: maxResults,
      ));
    }

    results.sort((a, b) => a.arrivalSec.compareTo(b.arrivalSec));
    return results.take(maxResults).toList(growable: false);
  }

  /// Une passe de recherche sur [day] ; toutes les heures sont exprimées en
  /// secondes absolues depuis minuit de J0 (offset = [shift] jour(s)).
  List<PassBiJourney> _searchDay({
    required Set<String> fromKeys,
    required Set<String> toKeys,
    required DateTime day,
    required int offset,
    required int startSec,
    required int maxResults,
  }) {
    final int deadline = startSec + horizonSec;

    final results = <PassBiJourney>[];
    final seenGoal = <String>{};
    var explorations = 0;

    // File d'expansion triée par heure (BFS temporel borné).
    var frontier = <_SearchState>[];
    for (final key in fromKeys) {
      frontier.add(_SearchState(key, startSec, const <PassBiLeg>[]));
    }

    // Meilleur temps vu par arrêt — évite les boucles et les doublons.
    final bestAt = <String, int>{};

    while (frontier.isNotEmpty && explorations < maxExplorations) {
      frontier.sort((a, b) => a.timeSec.compareTo(b.timeSec));
      final nextFrontier = <_SearchState>[];
      for (final state in frontier) {
        explorations++;
        if (explorations > maxExplorations) break;
        if (state.timeSec > deadline) continue;

        // Objectif atteint à cet arrêt (arrivée à l'état courant).
        if (state.legs.isNotEmpty &&
            toKeys.contains(state.stopKey) &&
            seenGoal.add(state.stopKey)) {
          results.add(PassBiJourney(
            originKey: fromKeys.contains(state.stopKey)
                ? state.stopKey
                : state.legs.first.fromStopId,
            destinationKey: state.stopKey,
            legs: List<PassBiLeg>.unmodifiable(state.legs),
            transferCount: state.legs.length - 1,
            departureSec: state.legs.first.departureSec,
            arrivalSec: state.timeSec,
          ));
          continue; // on n'explore pas au-delà de l'arrivée
        }

        // Embarquement possible depuis cet arrêt (+ liens documentés).
        final boardingPoints = <String, int>{state.stopKey: 0};
        for (final link in _linksFrom(state.stopKey)) {
          boardingPoints[link.$1] = link.$2; // clé alias, marche en secondes
        }
        for (final entry in boardingPoints.entries) {
          final departAt = state.timeSec + entry.value;
          if (departAt > deadline) continue; // (C) horizon sur l'embarquement
          final parts = PassBiSource.splitComposite(entry.key);
          if (parts == null) continue;
          final net = source.network(parts[0]);
          if (net == null) continue;
          final stopIndex = net.stopIndexById[parts[1]];
          if (stopIndex == null) continue;
          final list = net.stopTimesByStop[stopIndex];
          if (list == null) continue;
          for (final st in list) {
            final absDep = st.departureSec + offset;
            if (absDep < departAt) continue;
            if (absDep > deadline) break; // (C) embarquement borné à l'horizon
            final trip = net.trips[st.tripIndex];
            if (!net.serviceActiveOn(trip.serviceIndex, day)) continue;
            if (trip.routeIndex < 0) continue;
            final route = net.routes[trip.routeIndex];
            // Tous les arrêts suivants du trip (séquence réelle).
            final tripStops = net.stopTimesByTrip[st.tripIndex];
            if (tripStops == null) continue;
            var seenCurrent = false;
            for (final rst in tripStops) {
              if (!seenCurrent) {
                if (rst.sequence == st.sequence &&
                    rst.stopIndex == st.stopIndex) {
                  seenCurrent = true;
                }
                continue;
              }
              // (C) PAS de coupure sur l'arrivée : au-delà de l'horizon, le
              // trajet reste valide ; l'état ne sera pas ré-émbarqué (deadline).
              final absArr = rst.departureSec + offset;
              final destKey = '${parts[0]}:${net.stops[rst.stopIndex].id}';
              final leg = PassBiLeg(
                network: parts[0],
                routeId: route.id,
                routeLabel: route.short,
                tripId: trip.id,
                fromStopId: entry.key,
                fromStopName: net.stops[stopIndex].name,
                toStopId: destKey,
                toStopName: net.stops[rst.stopIndex].name,
                departureSec: absDep,
                arrivalSec: absArr,
                headsign: trip.headsign,
              );
              final newLegs = <PassBiLeg>[...state.legs, leg];

              if (toKeys.contains(destKey) && seenGoal.add(destKey)) {
                results.add(PassBiJourney(
                  originKey: state.legs.isEmpty
                      ? state.stopKey
                      : state.legs.first.fromStopId,
                  destinationKey: destKey,
                  legs: List<PassBiLeg>.unmodifiable(newLegs),
                  transferCount: newLegs.length - 1,
                  departureSec: newLegs.first.departureSec,
                  arrivalSec: absArr,
                ));
                continue;
              }

              if (newLegs.length - 1 <= maxTransfers) {
                final sig = destKey;
                final prev = bestAt[sig];
                if (prev == null || absArr < prev) {
                  bestAt[sig] = absArr;
                  nextFrontier.add(_SearchState(destKey, absArr, newLegs));
                }
              }
            }
          }
        }
      }
      frontier = nextFrontier;
      if (results.length >= maxResults * 3) break;
    }
    return results;
  }

  /// Alias de correspondance documentés : (clé, marche en secondes).
  Iterable<(String, int)> _linksFrom(String key) sync* {
    // marche standard : 80 m/min, minimum 1 minute.
    for (final link in source.transfers) {
      if (link.from == key) {
        final minutes = link.meters ~/ 80 < 1 ? 1 : link.meters ~/ 80;
        yield (link.to, minutes * 60);
      } else if (link.to == key) {
        final minutes = link.meters ~/ 80 < 1 ? 1 : link.meters ~/ 80;
        yield (link.from, minutes * 60);
      }
    }
  }
}
