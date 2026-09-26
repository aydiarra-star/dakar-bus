import '../models/departure_info.dart';
import '../models/schedule_models.dart';
import '../models/transport_network.dart';
import 'data_provider.dart';

/// Issue discriminant séparée du statut d'une DepartureInfo.
sealed class DepartureSearchResult {
  const DepartureSearchResult();
}

/// Un ou plusieurs trips partent au même instant le plus proche.
final class FoundDeparture extends DepartureSearchResult {
  final List<DepartureInfo> departures;
  final DateTime nextDepartureAt;

  FoundDeparture(List<DepartureInfo> departures)
      : departures = List<DepartureInfo>.unmodifiable(departures),
        nextDepartureAt = _sharedInstant(departures) {
    if (departures.isEmpty ||
        departures.any((DepartureInfo info) =>
            (info.status != ScheduleStatus.scheduled &&
                info.status != ScheduleStatus.realTime) ||
            info.nextDepartureAt == null)) {
      throw ArgumentError('Found exige au moins un départ SCHEDULED/REAL_TIME exact');
    }
  }
}

/// Fréquence documentée, sans prétention d'heure exacte.
final class EstimatedDeparture extends DepartureSearchResult {
  final DepartureInfo info;

  EstimatedDeparture(this.info) {
    if (info.status != ScheduleStatus.estimated ||
        info.scheduledTime != null ||
        info.nextDepartureAt != null) {
      throw ArgumentError('Estimated exige ESTIMATED sans heure exacte');
    }
  }
}

/// Aucun départ dans la couverture explicitement complète jusqu'à cette date.
final class NoDeparture extends DepartureSearchResult {
  final ServiceDate coveredThrough;
  final String reason;

  const NoDeparture({required this.coveredThrough, required this.reason});
}

/// Les données ou la preuve sont insuffisantes pour répondre.
final class UnknownDeparture extends DepartureSearchResult {
  final String reason;

  const UnknownDeparture(this.reason);
}

/// Moteur déterministe de sélection de départs.
///
/// Il n'appelle jamais DateTime.now(), ne lit aucun fichier et ne complète pas
/// les relations par nom ou géographie. Les providers et l'instant sont injectés.
class ScheduleEngine {
  static const int _maxCalendarDaysToScan = 3660;

  final ScheduleDataset? dataset;
  final FrequencyProvider? frequencyProvider;
  final List<RealtimePrediction> realtimePredictions;
  final Duration? realtimeMaxAge;

  ScheduleEngine({
    required this.dataset,
    this.frequencyProvider,
    List<RealtimePrediction> realtimePredictions = const <RealtimePrediction>[],
    this.realtimeMaxAge,
  }) : realtimePredictions = List<RealtimePrediction>.unmodifiable(realtimePredictions);

  DepartureSearchResult nextDepartureFor({
    required String routeId,
    required String stopId,
    int? directionId,
    required ServiceDate serviceDate,
    required DateTime now,
  }) {
    if (routeId.trim().isEmpty || stopId.trim().isEmpty) {
      return const UnknownDeparture('routeId et stopId sont obligatoires.');
    }
    if (directionId != null && directionId < 0) {
      return const UnknownDeparture('directionId invalide.');
    }
    // Le contrat reçoit un instant UTC. Refuser un DateTime local empêche une
    // heure murale du téléphone d'être prise pour l'heure Africa/Dakar.
    if (!now.isUtc) {
      return const UnknownDeparture('now doit être un instant UTC explicite.');
    }

    final ScheduleDataset? currentDataset = dataset;
    if (currentDataset == null) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: 'Aucune grille horaire vérifiée n’est chargée.',
      );
    }

    final List<String> validationErrors = currentDataset.validationErrors;
    if (validationErrors.isNotEmpty) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: validationErrors.join('; '),
      );
    }

    final ScheduleProvenance? provenance = currentDataset.provenance;
    final ServiceDate todayInDakar = ServiceDate.fromInstant(now);
    if (provenance == null ||
        !provenance.isValidScheduleFor(
          serviceDate: serviceDate,
          routeId: routeId,
          stopId: stopId,
          directionId: directionId,
        ) ||
        provenance.dateVerified!.isAfter(todayInDakar)) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: 'La provenance ou la validité de la grille ne couvre pas cette requête.',
      );
    }

    if (!provenance.hasCompleteCoverageFor(
      serviceDate: serviceDate,
      routeId: routeId,
      stopId: stopId,
      directionId: directionId,
    )) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: 'La grille est partielle pour cette route, ce stop ou ce sens.',
      );
    }

    if (currentDataset.services.isEmpty) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: 'Aucun calendrier de service n’est fourni.',
      );
    }

    final Map<String, Service> servicesById = <String, Service>{
      for (final Service service in currentDataset.services) service.serviceId: service,
    };
    final List<Trip> routeTrips = currentDataset.trips
        .where((Trip trip) => trip.routeId == routeId)
        .toList(growable: false);
    final Map<String, List<StopTime>> stopTimesByTrip = <String, List<StopTime>>{};
    for (final StopTime stopTime in currentDataset.stopTimes) {
      stopTimesByTrip.putIfAbsent(stopTime.tripId, () => <StopTime>[]).add(stopTime);
    }

    // Intégrité de séquence par trip : un passage ne peut pas desservir la
    // séquence N après la séquence N+1. Un trip contradictoire est écarté —
    // jamais réordonné, jamais réparé — sans invalider les autres trips ni le
    // dataset. Le calcul est fait une fois par trip, hors de la boucle de dates.
    final Set<String> incoherentTripIds = <String>{
      for (final Trip trip in routeTrips)
        if (!_hasCoherentSequence(
          stopTimesByTrip[trip.tripId] ?? const <StopTime>[],
        ))
          trip.tripId,
    };

    DateTime? earliestInstant;
    final Map<String, DepartureInfo> earliestDepartures = <String, DepartureInfo>{};
    bool indeterminateCalendar = false;
    bool indeterminateDirection = false;
    bool missingDepartureTime = false;
    bool incoherentSequence = false;
    ServiceDate date = serviceDate;
    int scannedDays = 0;

    while (!date.isAfter(provenance.validTo!) && scannedDays < _maxCalendarDaysToScan) {
      // Une ServiceTime est non négative : dès que le minuit d'une date non
      // traitée est après le meilleur instant, aucune date suivante ne peut le
      // précéder, même si un trip précédent traverse plusieurs minuits.
      if (earliestInstant != null && date.utcMidnight.isAfter(earliestInstant)) break;

      if (!provenance.isValidScheduleFor(
        serviceDate: date,
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
      )) {
        break;
      }

      for (final Trip trip in routeTrips) {
        final List<StopTime> tripStopTimes = stopTimesByTrip[trip.tripId] ?? const <StopTime>[];
        final List<StopTime> matchingStops = tripStopTimes
            .where((StopTime stopTime) => stopTime.stopId == stopId)
            .toList(growable: false);
        if (matchingStops.isEmpty) continue;
        if (directionId != null &&
            trip.directionId != null &&
            trip.directionId != directionId) {
          continue;
        }

        // Un trip dont l'ordre temporel contredit ses stop_sequence ne décrit
        // aucun passage exploitable : il ne fournit ni horaire statique, ni
        // appariement temps réel. Il est ignoré ici, avant toute sélection.
        if (incoherentTripIds.contains(trip.tripId)) {
          incoherentSequence = true;
          continue;
        }

        final Service? service = servicesById[trip.serviceId];
        if (service == null) {
          indeterminateCalendar = true;
          continue;
        }
        if (!service.isActiveOn(date)) continue;

        for (final StopTime stopTime in matchingStops) {
          final ServiceTime? departureTime = stopTime.departureTime;
          final RealtimePrediction? realtime = _matchingRealtime(
            trip: trip,
            stopTime: stopTime,
            serviceDate: date,
            directionId: directionId,
            now: now,
          );
          if (directionId != null && trip.directionId == null && realtime == null) {
            if (departureTime == null) {
              missingDepartureTime = true;
            } else if (!departureTime.toInstant(date).isBefore(now)) {
              indeterminateDirection = true;
            }
            continue;
          }
          final DateTime? candidateAt =
              realtime?.predictedDepartureAt ?? departureTime?.toInstant(date);
          if (candidateAt == null) {
            missingDepartureTime = true;
            continue;
          }
          if (candidateAt.isBefore(now)) continue;

          final DepartureInfo info;
          try {
            info = realtime == null
                ? DepartureInfo.scheduled(
                    dataset: currentDataset,
                    trip: trip,
                    stopTime: stopTime,
                    service: service,
                    serviceDate: date,
                    provenance: provenance,
                    calculatedAt: now,
                  )
                : DepartureInfo.realTime(
                    dataset: currentDataset,
                    prediction: realtime,
                    trip: trip,
                    stopTime: stopTime,
                    service: service,
                    now: now,
                    maxAge: realtimeMaxAge!,
                  );
          } on ArgumentError catch (error) {
            return UnknownDeparture('Départ rejeté : $error');
          }

          final String candidateKey =
              '${trip.tripId}:${stopTime.stopSequence}@$date';
          if (earliestInstant == null || candidateAt.isBefore(earliestInstant)) {
            earliestInstant = candidateAt;
            earliestDepartures
              ..clear()
              ..[candidateKey] = info;
          } else if (candidateAt == earliestInstant) {
            earliestDepartures[candidateKey] = info;
          }
        }
      }

      date = date.addDays(1);
      scannedDays++;
    }

    // Un trip sans calendrier ou un stop_time sans heure de départ peut précéder
    // le candidat visible : la grille ne permet alors pas d'affirmer « prochain ».
    if (indeterminateCalendar || indeterminateDirection || missingDepartureTime) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: indeterminateCalendar
            ? 'Au moins un trip n’a pas de calendrier service vérifiable.'
            : indeterminateDirection
                ? 'Au moins un trip actif n’a pas de direction vérifiable.'
                : 'Au moins un stop_time n’a pas de departure_time.',
      );
    }

    if (scannedDays >= _maxCalendarDaysToScan &&
        !date.isAfter(provenance.validTo!)) {
      return const UnknownDeparture(
        'La recherche dépasse la fenêtre de sécurité du calendrier.',
      );
    }

    if (earliestDepartures.isNotEmpty) {
      final List<DepartureInfo> ordered = earliestDepartures.values.toList()
        ..sort((DepartureInfo a, DepartureInfo b) {
          final int tripOrder = a.tripId!.compareTo(b.tripId!);
          if (tripOrder != 0) return tripOrder;
          return a.stopSequence!.compareTo(b.stopSequence!);
        });
      return FoundDeparture(ordered);
    }

    // Aucun départ exploitable alors qu'au moins un trip desservant ce stop a
    // été écarté pour séquence contradictoire : ce trip aurait pu fournir un
    // départ, l'absence n'est donc pas démontrable. Un trip valide trouvé plus
    // haut l'emporte toujours : l'incohérence d'un trip ne disqualifie pas les
    // autres.
    if (incoherentSequence) {
      return _estimatedOrUnknown(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
        now: now,
        reason: 'Au moins un trip a des stop_sequence en contradiction avec '
            'l’ordre temporel de son passage.',
      );
    }

    return NoDeparture(
      coveredThrough: provenance.validTo!,
      reason: 'Aucun trip actif ne dessert ce stop dans la couverture complète.',
    );
  }

  /// `true` si les stop_sequence du trip ne contredisent pas l'ordre temporel
  /// de son passage.
  ///
  /// La position temporelle d'un stop_time est son `departureTime`, à défaut
  /// son `arrivalTime` ; un stop_time sans aucune heure ne porte pas
  /// d'information temporelle et n'est pas pris en compte. À heure égale les
  /// séquences sont comparées dans l'ordre croissant : un même arrêt servi deux
  /// fois au même instant (boucle) reste donc accepté. Seule une séquence
  /// strictement décroissante dans le temps invalide le trip. Les stop_sequence
  /// dupliquées au sein d'un trip sont déjà refusées en amont par
  /// `ScheduleDataset.validationErrors`.
  static bool _hasCoherentSequence(List<StopTime> tripStopTimes) {
    final List<StopTime> timed = tripStopTimes
        .where((StopTime stopTime) =>
            stopTime.departureTime != null || stopTime.arrivalTime != null)
        .toList(growable: false)
      ..sort((StopTime a, StopTime b) {
        final int timeOrder = (a.departureTime ?? a.arrivalTime)!
            .compareTo(b.departureTime ?? b.arrivalTime!);
        if (timeOrder != 0) return timeOrder;
        return a.stopSequence.compareTo(b.stopSequence);
      });
    for (int index = 1; index < timed.length; index++) {
      if (timed[index].stopSequence < timed[index - 1].stopSequence) {
        return false;
      }
    }
    return true;
  }

  RealtimePrediction? _matchingRealtime({
    required Trip trip,
    required StopTime stopTime,
    required ServiceDate serviceDate,
    required int? directionId,
    required DateTime now,
  }) {
    final Duration? maxAge = realtimeMaxAge;
    if (maxAge == null) return null;
    final List<RealtimePrediction> matches = realtimePredictions.where((RealtimePrediction item) {
      return item.routeId == trip.routeId &&
          item.tripId == trip.tripId &&
          item.stopId == stopTime.stopId &&
          item.stopSequence == stopTime.stopSequence &&
          (trip.directionId == null || item.directionId == trip.directionId) &&
          (directionId == null || item.directionId == directionId) &&
          item.serviceDate == serviceDate &&
          item.isFreshAt(now, maxAge);
    }).toList(growable: false);
    if (matches.isEmpty) return null;

    matches.sort((RealtimePrediction a, RealtimePrediction b) =>
        b.observedAt.compareTo(a.observedAt));
    final DateTime newestObservation = matches.first.observedAt;
    final List<RealtimePrediction> newest = matches
        .where((RealtimePrediction prediction) => prediction.observedAt == newestObservation)
        .toList(growable: false);
    final Set<DateTime> predictions = newest
        .map((RealtimePrediction prediction) => prediction.predictedDepartureAt)
        .toSet();
    // Deux valeurs incompatibles au même instant d'observation ne sont pas
    // départagées arbitrairement : le moteur retombe sur l'horaire statique.
    if (predictions.length != 1) return null;
    return newest.first;
  }

  DepartureSearchResult _estimatedOrUnknown({
    required String routeId,
    required String stopId,
    required int? directionId,
    required ServiceDate serviceDate,
    required DateTime now,
    required String reason,
  }) {
    final FrequencyProvider? provider = frequencyProvider;
    if (provider == null || directionId != null) return UnknownDeparture(reason);

    // Une fréquence ne porte pas de serviceDate arbitraire ni de directionId
    // GTFS. Elle n'est utilisée qu'à la date civile courante, avec le sens omis.
    if (ServiceDate.fromInstant(now) != serviceDate) return UnknownDeparture(reason);

    final DepartureInfo estimate = provider.departureInfoForRoute(
      routeId,
      now,
      stopId: stopId,
      serviceDate: serviceDate,
    );
    if (estimate.status == ScheduleStatus.estimated) {
      return EstimatedDeparture(estimate);
    }
    return UnknownDeparture(reason);
  }
}

DateTime _sharedInstant(List<DepartureInfo> departures) {
  if (departures.isEmpty) throw ArgumentError('Found exige au moins un départ');
  final DateTime? instant = departures.first.nextDepartureAt;
  if (instant == null ||
      departures.any((DepartureInfo item) => item.nextDepartureAt != instant)) {
    throw ArgumentError('Les départs regroupés doivent partager le même instant');
  }
  return instant;
}
