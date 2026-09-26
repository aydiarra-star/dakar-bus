import 'dart:collection';

import 'transport_network.dart';

/// Le fuseau métier du réseau Dakar. Les instants de service sont construits
/// en UTC, équivalent à Africa/Dakar (UTC+0 actuellement), jamais depuis le
/// fuseau local du téléphone.
const String kDakarTimeZone = 'Africa/Dakar';

/// Date civile d'un service, sans heure ni fuseau.
///
/// Elle reste la date GTFS d'origine même si [ServiceTime] dépasse minuit.
class ServiceDate implements Comparable<ServiceDate> {
  final int year;
  final int month;
  final int day;

  factory ServiceDate(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Doit être compris entre 1 et 9999');
    }
    // DateTime remappe les années 0–99 sur 1900–1999. Décaler de 400 ans
    // préserve le calendrier grégorien tout en validant correctement les
    // dates ISO anciennes sans dépendre de ce raccourci de l'API.
    final DateTime candidate = DateTime.utc(year + 400, month, day);
    if (candidate.year != year + 400 ||
        candidate.month != month ||
        candidate.day != day) {
      throw ArgumentError('Date de service invalide : $year-$month-$day');
    }
    return ServiceDate._(year, month, day);
  }

  const ServiceDate._(this.year, this.month, this.day);

  factory ServiceDate.parse(String value) {
    final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Date ISO invalide', value);
    return ServiceDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Africa/Dakar est UTC+0 actuellement : ce constructeur ne lit pas le TZ
  /// local du téléphone.
  factory ServiceDate.fromInstant(DateTime instant) {
    final DateTime utc = instant.toUtc();
    return ServiceDate(utc.year, utc.month, utc.day);
  }

  DateTime get utcMidnight => DateTime.utc(year, month, day);
  int get weekday => utcMidnight.weekday;

  ServiceDate addDays(int days) {
    final DateTime next = utcMidnight.add(Duration(days: days));
    return ServiceDate(next.year, next.month, next.day);
  }

  bool isBefore(ServiceDate other) => compareTo(other) < 0;
  bool isAfter(ServiceDate other) => compareTo(other) > 0;

  @override
  int compareTo(ServiceDate other) {
    final int yearResult = year.compareTo(other.year);
    if (yearResult != 0) return yearResult;
    final int monthResult = month.compareTo(other.month);
    return monthResult != 0 ? monthResult : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Heure relative au début de [ServiceDate]. Les heures supérieures ou égales
/// à 24 sont conservées, par exemple 24:02:00 = minuit + 2 minutes le lendemain.
class ServiceTime implements Comparable<ServiceTime> {
  final int hour;
  final int minute;
  final int second;

  factory ServiceTime(int hour, int minute, int second) {
    if (hour < 0) throw ArgumentError.value(hour, 'hour', 'Ne peut pas être négatif');
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Doit être compris entre 0 et 59');
    }
    if (second < 0 || second > 59) {
      throw ArgumentError.value(second, 'second', 'Doit être compris entre 0 et 59');
    }
    return ServiceTime._(hour, minute, second);
  }

  const ServiceTime._(this.hour, this.minute, this.second);

  factory ServiceTime.parse(String value) {
    final RegExpMatch? match =
        RegExp(r'^(\d{1,3}):([0-5]\d):([0-5]\d)$').firstMatch(value);
    if (match == null) throw FormatException('Heure GTFS invalide', value);
    return ServiceTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  int get secondsSinceServiceDayStart => hour * 3600 + minute * 60 + second;

  /// Retourne un instant UTC représentant l'heure locale Africa/Dakar.
  DateTime toInstant(ServiceDate serviceDate) => serviceDate.utcMidnight
      .add(Duration(seconds: secondsSinceServiceDayStart));

  /// Date civile de passage ; peut différer de [serviceDate].
  ServiceDate civilDate(ServiceDate serviceDate) =>
      serviceDate.addDays(secondsSinceServiceDayStart ~/ (24 * 60 * 60));

  @override
  int compareTo(ServiceTime other) =>
      secondsSinceServiceDayStart.compareTo(other.secondsSinceServiceDayStart);

  @override
  bool operator ==(Object other) =>
      other is ServiceTime &&
      hour == other.hour &&
      minute == other.minute &&
      second == other.second;

  @override
  int get hashCode => Object.hash(hour, minute, second);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}

/// Trip de transport public. Les identifiants sont des clés, jamais des noms
/// ou des indices géographiques.
class Trip {
  final String routeId;
  final String tripId;
  final String serviceId;
  final int? directionId;
  final String? headsign;

  Trip({
    required this.routeId,
    required this.tripId,
    required this.serviceId,
    this.directionId,
    this.headsign,
  }) {
    _requireId(routeId, 'routeId');
    _requireId(tripId, 'tripId');
    _requireId(serviceId, 'serviceId');
    if (directionId != null && directionId! < 0) {
      throw ArgumentError.value(directionId, 'directionId', 'Ne peut pas être négatif');
    }
  }
}

/// Passage d'un trip à un arrêt. Les deux heures sont indépendantes et
/// optionnelles ; une heure d'arrivée ne devient jamais un départ implicite.
class StopTime {
  final String tripId;
  final String stopId;
  final int stopSequence;
  final ServiceTime? arrivalTime;
  final ServiceTime? departureTime;

  StopTime({
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    this.arrivalTime,
    this.departureTime,
  }) {
    _requireId(tripId, 'tripId');
    _requireId(stopId, 'stopId');
    if (stopSequence <= 0) {
      throw ArgumentError.value(stopSequence, 'stopSequence', 'Doit être positif');
    }
    if (arrivalTime != null &&
        departureTime != null &&
        departureTime!.compareTo(arrivalTime!) < 0) {
      throw ArgumentError('departureTime précède arrivalTime au même stop');
    }
  }
}

/// Exception GTFS pour une date : ajout OU retrait du service, jamais les deux.
class ServiceException {
  final ServiceDate date;
  final bool serviceAdded;
  final bool serviceRemoved;

  factory ServiceException({
    required ServiceDate date,
    bool serviceAdded = false,
    bool serviceRemoved = false,
  }) {
    if (serviceAdded == serviceRemoved) {
      throw ArgumentError('Une exception doit être exactement un ajout ou un retrait');
    }
    return ServiceException._(date, serviceAdded, serviceRemoved);
  }

  const ServiceException._(this.date, this.serviceAdded, this.serviceRemoved);
}

/// Calendrier hebdomadaire et exceptions datées d'un service.
class Service {
  final String serviceId;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final ServiceDate startDate;
  final ServiceDate endDate;
  final List<ServiceException> exceptions;

  Service({
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
    List<ServiceException> exceptions = const <ServiceException>[],
  }) : exceptions = List<ServiceException>.unmodifiable(exceptions) {
    _requireId(serviceId, 'serviceId');
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('startDate doit précéder ou égaler endDate');
    }
    final Set<ServiceDate> exceptionDates = <ServiceDate>{};
    for (final ServiceException exception in this.exceptions) {
      if (!exceptionDates.add(exception.date)) {
        throw ArgumentError('Exception calendrier dupliquée pour ${exception.date}');
      }
    }
  }

  /// Les exceptions ont priorité sur la règle hebdomadaire. Un service ajouté
  /// par exception est actif à cette date même si le jour est normalement inactif.
  bool isActiveOn(ServiceDate date) {
    for (final ServiceException exception in exceptions) {
      if (exception.date == date) return exception.serviceAdded;
    }
    if (date.isBefore(startDate) || date.isAfter(endDate)) return false;
    switch (date.weekday) {
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
      case DateTime.sunday:
        return sunday;
      default:
        return false;
    }
  }
}

/// Périmètre exact couvert dans une direction. Route et stop forment une paire :
/// des ensembles séparés ne doivent pas créer artificiellement leur produit.
class ScheduleCoverageScope {
  final String routeId;
  final String stopId;
  final Set<int> directionIds;
  final bool allDirections;

  ScheduleCoverageScope({
    required this.routeId,
    required this.stopId,
    Set<int> directionIds = const <int>{},
    this.allDirections = false,
  }) : directionIds = Set<int>.unmodifiable(directionIds) {
    if (routeId.trim().isEmpty ||
        stopId.trim().isEmpty ||
        this.directionIds.any((int id) => id < 0)) {
      throw ArgumentError('La portée de couverture contient un identifiant invalide');
    }
  }

  bool includes({required String routeId, required String stopId, required int? directionId}) {
    if (this.routeId != routeId || this.stopId != stopId) return false;
    if (directionId == null) return allDirections;
    return allDirections || directionIds.contains(directionId);
  }
}

/// Couverture documentée d'une version horaire. Une couverture partielle peut
/// alimenter une observation, mais ne prouve jamais le prochain départ ni son
/// absence. Chaque portée désigne une paire route/stop exacte.
class ScheduleCoverage {
  final bool complete;
  final List<ScheduleCoverageScope> scopes;

  ScheduleCoverage({
    required this.complete,
    required List<ScheduleCoverageScope> scopes,
  }) : scopes = List<ScheduleCoverageScope>.unmodifiable(scopes);

  bool includes({
    required String routeId,
    required String stopId,
    required int? directionId,
  }) =>
      scopes.any((ScheduleCoverageScope scope) =>
          scope.includes(
            routeId: routeId,
            stopId: stopId,
            directionId: directionId,
          ));

  bool isCompleteFor({
    required String routeId,
    required String stopId,
    required int? directionId,
  }) =>
      complete &&
      includes(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
      );
}

/// Provenance d'une version horaire. La validité temporelle et le périmètre de
/// couverture sont vérifiés avant que le moteur puisse affirmer Found/NoDeparture.
class ScheduleProvenance {
  final String? source;
  final SourceType sourceType;
  final ServiceDate? dateSource;
  final ServiceDate? dateVerified;
  final ServiceDate? validFrom;
  final ServiceDate? validTo;
  final double? confidence;
  final ScheduleStatus scheduleStatus;
  final ScheduleCoverage? coverage;

  ScheduleProvenance({
    required this.source,
    required this.sourceType,
    required this.dateSource,
    required this.dateVerified,
    required this.validFrom,
    required this.validTo,
    required this.confidence,
    required this.scheduleStatus,
    required this.coverage,
  }) {
    if (confidence != null &&
        (!confidence!.isFinite || confidence! < 0 || confidence! > 1)) {
      throw ArgumentError.value(confidence, 'confidence', 'Doit être dans [0, 1]');
    }
    final ServiceDate? publishedDate = dateSource;
    final ServiceDate? verifiedDate = dateVerified;
    if (publishedDate != null &&
        verifiedDate != null &&
        publishedDate.isAfter(verifiedDate)) {
      throw ArgumentError('dateSource ne peut pas suivre dateVerified');
    }
    final ServiceDate? firstValidDate = validFrom;
    final ServiceDate? lastValidDate = validTo;
    if (firstValidDate != null &&
        lastValidDate != null &&
        firstValidDate.isAfter(lastValidDate)) {
      throw ArgumentError('validFrom doit précéder ou égaler validTo');
    }
  }

  bool isValidScheduleFor({
    required ServiceDate serviceDate,
    required String routeId,
    required String stopId,
    required int? directionId,
  }) {
    final ScheduleCoverage? scope = coverage;
    return scheduleStatus == ScheduleStatus.scheduled &&
        source != null &&
        source!.trim().isNotEmpty &&
        sourceType == SourceType.officialStatic &&
        dateSource != null &&
        dateVerified != null &&
        validFrom != null &&
        validTo != null &&
        !serviceDate.isBefore(validFrom!) &&
        !serviceDate.isAfter(validTo!) &&
        scope != null &&
        scope.includes(
          routeId: routeId,
          stopId: stopId,
          directionId: directionId,
        );
  }

  bool hasCompleteCoverageFor({
    required ServiceDate serviceDate,
    required String routeId,
    required String stopId,
    required int? directionId,
  }) =>
      isValidScheduleFor(
        serviceDate: serviceDate,
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
      ) &&
      coverage!.isCompleteFor(
        routeId: routeId,
        stopId: stopId,
        directionId: directionId,
      );

  bool get isValidRealtimeSource =>
      source != null &&
      source!.trim().isNotEmpty &&
      scheduleStatus == ScheduleStatus.realTime &&
      (sourceType == SourceType.officialRealtime ||
          sourceType == SourceType.operatorRealtime);
}

/// Un jeu de grille chargé par un ScheduleProvider. Aucune donnée de production
/// n'est créée par ce modèle.
class ScheduleDataset {
  final List<Trip> trips;
  final List<StopTime> stopTimes;
  final List<Service> services;
  final ScheduleProvenance? provenance;

  ScheduleDataset({
    required List<Trip> trips,
    required List<StopTime> stopTimes,
    required List<Service> services,
    required this.provenance,
  })  : trips = List<Trip>.unmodifiable(trips),
        stopTimes = List<StopTime>.unmodifiable(stopTimes),
        services = List<Service>.unmodifiable(services);

  late final Set<Trip> _tripIdentities = HashSet<Trip>.identity()..addAll(trips);
  late final Set<StopTime> _stopTimeIdentities =
      HashSet<StopTime>.identity()..addAll(stopTimes);
  late final Set<Service> _serviceIdentities = HashSet<Service>.identity()..addAll(services);
  late final List<String> _validationErrors = _computeValidationErrors();

  bool containsTripIdentity(Trip trip) => _tripIdentities.contains(trip);
  bool containsStopTimeIdentity(StopTime stopTime) =>
      _stopTimeIdentities.contains(stopTime);
  bool containsServiceIdentity(Service service) => _serviceIdentities.contains(service);

  /// Erreurs structurelles rendent la grille inexploitable : aucune référence
  /// n'est réparée par nom, proximité ou ordre implicite. Le résultat est mis
  /// en cache puisque les listes et leurs enregistrements sont immuables.
  List<String> get validationErrors => _validationErrors;

  List<String> _computeValidationErrors() {
    final List<String> errors = <String>[];
    final Set<String> tripIds = <String>{};
    for (final Trip trip in trips) {
      if (!tripIds.add(trip.tripId)) errors.add('trip_id dupliqué: ${trip.tripId}');
    }

    final Set<String> serviceIds = <String>{};
    for (final Service service in services) {
      if (!serviceIds.add(service.serviceId)) {
        errors.add('service_id dupliqué: ${service.serviceId}');
      }
    }

    final Map<String, List<StopTime>> byTrip = <String, List<StopTime>>{};
    for (final StopTime stopTime in stopTimes) {
      if (!tripIds.contains(stopTime.tripId)) {
        errors.add('stop_time sans trip correspondant: ${stopTime.tripId}');
      }
      byTrip.putIfAbsent(stopTime.tripId, () => <StopTime>[]).add(stopTime);
    }

    // L'ordre des lignes du fichier d'entrée n'est pas une identité : valider
    // l'unicité de stop_sequence plutôt que supposer que le provider a pré-trié
    // les enregistrements.
    for (final String tripId in tripIds) {
      final List<StopTime>? tripStopTimes = byTrip[tripId];
      if (tripStopTimes == null || tripStopTimes.isEmpty) {
        errors.add('trip sans stop_time: $tripId');
        continue;
      }
      final Set<int> sequences = <int>{};
      for (final StopTime stopTime in tripStopTimes) {
        if (!sequences.add(stopTime.stopSequence)) {
          errors.add('stop_sequence dupliquée dans $tripId');
          break;
        }
      }
    }
    return List<String>.unmodifiable(errors);
  }
}

/// Prédiction temps réel identifiée, uniquement consommée si elle correspond à
/// un trip/stop/direction et si son observation est fraîche.
class RealtimePrediction {
  final String routeId;
  final String tripId;
  final String stopId;
  final int stopSequence;
  final int directionId;
  final ServiceDate serviceDate;
  final DateTime predictedDepartureAt;
  final DateTime observedAt;
  final ScheduleProvenance provenance;

  RealtimePrediction({
    required this.routeId,
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    required this.directionId,
    required this.serviceDate,
    required DateTime predictedDepartureAt,
    required DateTime observedAt,
    required this.provenance,
  })  : predictedDepartureAt = predictedDepartureAt.toUtc(),
        observedAt = observedAt.toUtc() {
    _requireId(routeId, 'routeId');
    _requireId(tripId, 'tripId');
    _requireId(stopId, 'stopId');
    if (stopSequence <= 0) {
      throw ArgumentError.value(stopSequence, 'stopSequence', 'Doit être positif');
    }
    if (directionId < 0) {
      throw ArgumentError.value(directionId, 'directionId', 'Ne peut pas être négatif');
    }
    if (!provenance.isValidRealtimeSource) {
      throw ArgumentError('Une prédiction temps réel exige une provenance REAL_TIME traçable');
    }
  }

  bool isFreshAt(DateTime now, Duration maxAge) {
    final DateTime instant = now.toUtc();
    if (maxAge.isNegative || observedAt.isAfter(instant)) return false;
    if (instant.difference(observedAt) > maxAge) return false;
    return !predictedDepartureAt.isBefore(instant);
  }
}

void _requireId(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, name, 'Ne peut pas être vide');
}
