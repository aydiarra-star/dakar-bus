import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/clock.dart';
import 'package:dakar_bus/services/data_provider.dart';
import 'package:dakar_bus/services/data_service.dart';
import 'package:dakar_bus/services/eta_calculator.dart';
import 'package:dakar_bus/services/schedule_provider.dart';
import 'package:dakar_bus/services/schedule_service.dart';

// Toutes les heures et identités ci-dessous sont des fixtures synthétiques de
// tests. Elles ne représentent aucun horaire ni trip TER réel.
const String _route = 'test_route_synthetic_only';
const String _stop = 'test_stop_synthetic_only';
const String _otherStop = 'test_other_stop_synthetic_only';
const String _serviceId = 'test_service_synthetic_only';

Service _service({
  ServiceDate? start,
  ServiceDate? end,
  bool monday = true,
  bool tuesday = true,
  bool wednesday = true,
  bool thursday = true,
  bool friday = true,
  bool saturday = true,
  bool sunday = false,
  List<ServiceException> exceptions = const <ServiceException>[],
}) =>
    Service(
      serviceId: _serviceId,
      monday: monday,
      tuesday: tuesday,
      wednesday: wednesday,
      thursday: thursday,
      friday: friday,
      saturday: saturday,
      sunday: sunday,
      startDate: start ?? ServiceDate(2026, 9, 26),
      endDate: end ?? ServiceDate(2026, 10, 10),
      exceptions: exceptions,
    );

ScheduleProvenance _provenance({
  bool complete = true,
  ServiceDate? dateSource,
  ServiceDate? dateVerified,
  ServiceDate? validFrom,
  ServiceDate? validTo,
  bool omitDateSource = false,
  Set<String> routeIds = const <String>{_route},
  Set<String> stopIds = const <String>{_stop, _otherStop},
  Set<int> directionIds = const <int>{},
  bool allDirections = true,
}) =>
    ScheduleProvenance(
      source: 'test-fixture://synthetic-only-not-production-data',
      sourceType: SourceType.officialStatic,
      dateSource: omitDateSource ? null : dateSource ?? ServiceDate(2026, 9, 1),
      dateVerified: dateVerified ?? ServiceDate(2026, 9, 26),
      validFrom: validFrom ?? ServiceDate(2026, 9, 26),
      validTo: validTo ?? ServiceDate(2026, 10, 10),
      confidence: null,
      scheduleStatus: ScheduleStatus.scheduled,
      coverage: ScheduleCoverage(
        complete: complete,
        scopes: <ScheduleCoverageScope>[
          for (final String coveredRouteId in routeIds)
            for (final String coveredStopId in stopIds)
              ScheduleCoverageScope(
                routeId: coveredRouteId,
                stopId: coveredStopId,
                directionIds: directionIds,
                allDirections: allDirections,
              ),
        ],
      ),
    );

ScheduleProvenance _realtimeProvenance() => ScheduleProvenance(
      source: 'test-fixture://synthetic-realtime-not-a-feed',
      sourceType: SourceType.operatorRealtime,
      dateSource: null,
      dateVerified: null,
      validFrom: null,
      validTo: null,
      confidence: null,
      scheduleStatus: ScheduleStatus.realTime,
      coverage: null,
    );

ScheduleDataset _dataset({
  List<Service>? services,
  List<Trip>? trips,
  List<StopTime>? stopTimes,
  ScheduleProvenance? provenance,
  bool complete = true,
  List<ServiceTime> times = const <ServiceTime>[],
  bool monday = true,
  bool saturday = true,
  bool sunday = false,
  ServiceDate? serviceStart,
  ServiceDate? serviceEnd,
}) {
  final List<Trip> fixtureTrips = trips ?? <Trip>[
    for (int index = 0; index < times.length; index++)
      Trip(
        routeId: _route,
        tripId: 'test_trip_${index.toString().padLeft(2, '0')}_synthetic_only',
        serviceId: _serviceId,
        directionId: 0,
        headsign: 'Test direction',
      ),
  ];
  final List<StopTime> fixtureStopTimes = stopTimes ?? <StopTime>[
    for (int index = 0; index < times.length; index++)
      StopTime(
        tripId: 'test_trip_${index.toString().padLeft(2, '0')}_synthetic_only',
        stopId: _stop,
        stopSequence: 1,
        departureTime: times[index],
      ),
  ];
  return ScheduleDataset(
    trips: fixtureTrips,
    stopTimes: fixtureStopTimes,
    services: services ?? <Service>[
      _service(
        monday: monday,
        saturday: saturday,
        sunday: sunday,
        start: serviceStart,
        end: serviceEnd,
      ),
    ],
    provenance: provenance ?? _provenance(complete: complete),
  );
}

ScheduleEngine _engine(
  ScheduleDataset dataset, {
  List<RealtimePrediction> realtime = const <RealtimePrediction>[],
  Duration? realtimeMaxAge,
}) =>
    ScheduleEngine(
      dataset: dataset,
      realtimePredictions: realtime,
      realtimeMaxAge: realtimeMaxAge,
    );

FoundDeparture _found(DepartureSearchResult result) {
  expect(result, isA<FoundDeparture>());
  return result as FoundDeparture;
}

String _departureDisplayLabel(DepartureInfo info) {
  // Lot 4.14 : ETA universelle `🟢 X min` / `🟢 Maintenant`
  final anchor = info.calculatedAt ?? info.referenceTime;
  if (anchor == null) return 'Horaire indisponible';
  final EtaResult? eta = EtaCalculator.fromDepartureInfo(info, anchor);
  if (eta != null) {
    if (eta.isNow) return '🟢 Maintenant';
    return '🟢 ${eta.minutes} min';
  }
  return 'Horaire indisponible';
}

void main() {
  group('nextDepartureFor — instants et secondes', () {
    final ServiceDate monday = ServiceDate(2026, 9, 28);
    final ScheduleEngine engine = _engine(
      _dataset(times: <ServiceTime>[
        ServiceTime(14, 40, 0),
        ServiceTime(14, 50, 0),
      ]),
    );

    test('choisit le départ exact le plus proche parmi plusieurs trips', () {
      final FoundDeparture result = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 38),
      ));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 40));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('14:38:00 vers 14:40:00 donne 120 secondes', () {
      final DepartureInfo info = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 38),
      )).departures.single;
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 28, 14, 38)), 120);
      expect(info.remainingMinutesAt(DateTime.utc(2026, 9, 28, 14, 38)), 2);
    });

    test('14:39:00 vers 14:40:00 donne 60 secondes et une minute', () {
      final DepartureInfo info = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 39),
      )).departures.single;
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 28, 14, 39)), 60);
      expect(info.remainingMinutesAt(DateTime.utc(2026, 9, 28, 14, 39)), 1);
    });

    test('14:39:01 donne 59 secondes', () {
      final DepartureInfo info = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 39, 1),
      )).departures.single;
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 28, 14, 39, 1)), 59);
      expect(info.remainingLabelAt(DateTime.utc(2026, 9, 28, 14, 39, 1)), 'Départ dans 59 s');
    });

    test('14:39:59 donne une seconde', () {
      final DepartureInfo info = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 39, 59),
      )).departures.single;
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 28, 14, 39, 59)), 1);
    });

    test('égalité exacte retourne maintenant', () {
      final DepartureInfo info = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 40),
      )).departures.single;
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 28, 14, 40)), 0);
      expect(info.remainingLabelAt(DateTime.utc(2026, 9, 28, 14, 40)), 'Départ maintenant');
    });

    test('14:40:01 écarte le départ passé et sélectionne le suivant', () {
      final FoundDeparture result = _found(engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 40, 1),
      ));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 50));
    });

    test('trips ex æquo à la même seconde restent tous visibles', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'test_a_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
          Trip(
            routeId: _route,
            tripId: 'test_b_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_a_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_b_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      final FoundDeparture result = _found(_engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 38),
      ));
      expect(result.departures, hasLength(2));
      expect(result.departures.map((DepartureInfo info) => info.tripId),
          containsAll(<String>['test_a_synthetic_only', 'test_b_synthetic_only']));
    });

    test('deux passages du même trip au même stop gardent leurs sequences', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'loop_trip_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'loop_trip_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'loop_trip_synthetic_only',
            stopId: _stop,
            stopSequence: 3,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      final FoundDeparture result = _found(_engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: DateTime.utc(2026, 9, 28, 14, 38),
      ));
      expect(result.departures, hasLength(2));
      expect(
        result.departures.map((DepartureInfo info) => info.stopSequence),
        containsAll(<int>[1, 3]),
      );
    });

    test('now local est refusé ; le moteur exige un instant explicite UTC', () {
      final DepartureSearchResult result = engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        serviceDate: monday,
        now: DateTime(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });
  });

  group('nextDepartureFor — date de service et calendrier', () {
    test('24:02 du 26/09 devient 00:02 le 27/09 sans changer serviceDate', () {
      final ServiceDate saturday = ServiceDate(2026, 9, 26);
      final FoundDeparture result = _found(_engine(_dataset(
        times: <ServiceTime>[ServiceTime.parse('24:02:00')],
      )).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: saturday,
        now: DateTime.utc(2026, 9, 26, 23, 59, 59),
      ));
      final DepartureInfo info = result.departures.single;
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 27, 0, 2));
      expect(info.serviceDate, saturday);
      expect(info.remainingSecondsAt(DateTime.utc(2026, 9, 26, 23, 59, 59)), 121);
    });

    test('service inactif dimanche cherche le prochain service démontré lundi', () {
      final ScheduleDataset dataset = _dataset(
        times: <ServiceTime>[ServiceTime(6, 0, 0)],
        monday: true,
        saturday: false,
        sunday: false,
      );
      final FoundDeparture result = _found(_engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 27),
        now: DateTime.utc(2026, 9, 27, 23),
      ));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 6));
      expect(result.departures.single.serviceDate, ServiceDate(2026, 9, 28));
    });

    test('calendrier absent produit Unknown, jamais un service quotidien supposé', () {
      final ScheduleDataset dataset = _dataset(services: const <Service>[], times: <ServiceTime>[
        ServiceTime(14, 40, 0),
      ]);
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('serviceId sans calendrier correspondant produit Unknown', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(routeId: _route, tripId: 'test_trip_synthetic_only', serviceId: 'missing_service'),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
        services: <Service>[
          _service(
            start: ServiceDate(2026, 9, 26),
            end: ServiceDate(2026, 10, 10),
          ),
        ],
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('aucun trip au stop dans une couverture complète donne NoDeparture', () {
      final ScheduleDataset dataset = _dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _otherStop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<NoDeparture>());
    });
  });

  group('nextDepartureFor — IDs, couverture et sources', () {
    test('route incorrecte retourne Unknown sans fallback par nom', () {
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
      )).nextDepartureFor(
        routeId: 'another_route',
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('stop incorrect non couvert retourne Unknown sans proximité/placeId', () {
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
      )).nextDepartureFor(
        routeId: _route,
        stopId: 'stop_nearby_but_not_linked',
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('direction sans trip correspondant donne NoDeparture si couverture exhaustive', () {
      final ScheduleDataset dataset = _dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
        provenance: _provenance(
          directionIds: const <int>{0, 1},
          allDirections: false,
        ),
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 1,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<NoDeparture>());
    });

    test('trip actif sans direction ne devient pas NoDeparture pour un sens', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'trip_without_direction_synthetic_only',
            serviceId: _serviceId,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'trip_without_direction_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('grille partielle ne prouve ni Found comme prochain ni NoDeparture', () {
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
        complete: false,
      )).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('stop_sequence incohérent invalide le jeu et produit Unknown', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'test_trip_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('source expirée ou historique est rejetée pour 2026', () {
      final ScheduleProvenance oldSource = _provenance(
        dateSource: ServiceDate(2022, 10, 1),
        dateVerified: ServiceDate(2026, 9, 26),
        validFrom: ServiceDate(2022, 10, 1),
        validTo: ServiceDate(2022, 10, 31),
      );
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
        provenance: oldSource,
      )).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('source sans date publiée ne permet pas SCHEDULED', () {
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
        provenance: _provenance(omitDateSource: true),
      )).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('date de vérification future ne valide pas une grille actuelle', () {
      final DepartureSearchResult result = _engine(_dataset(
        times: <ServiceTime>[ServiceTime(14, 40, 0)],
        provenance: _provenance(dateVerified: ServiceDate(2026, 10, 1)),
      )).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    test('stop_time sans departure_time ne devient pas une heure de départ', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'test_trip_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            arrivalTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      final DepartureSearchResult result = _engine(dataset).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });
  });

  // ==================================================================
  // Intégrité de stop_sequence : un passage ne peut pas desservir la
  // séquence N après la séquence N+1. Un trip contradictoire est écarté,
  // jamais réordonné ; il n'invalide ni les autres trips, ni le dataset.
  // ==================================================================
  group('nextDepartureFor — intégrité de stop_sequence', () {
    final ServiceDate monday = ServiceDate(2026, 9, 28);
    final DateTime now = DateTime.utc(2026, 9, 28, 14, 38);

    Trip tripOf(String tripId) => Trip(
          routeId: _route,
          tripId: tripId,
          serviceId: _serviceId,
          directionId: 0,
        );

    DepartureSearchResult search(ScheduleEngine engine) {
      return engine.nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: monday,
        now: now,
      );
    }

    test('séquences cohérentes avec l’ordre temporel : trip accepté', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_coherent_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_coherent_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 30, 0),
          ),
          StopTime(
            tripId: 'test_trip_coherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      final FoundDeparture result = _found(search(_engine(dataset)));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 40));
      expect(result.departures.single.stopSequence, 2);
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('séquence décroissante dans le temps : trip rejeté, UNKNOWN', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_reversed_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_reversed_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_reversed_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
      );
      expect(search(_engine(dataset)), isA<UnknownDeparture>());
    });

    test('l’ordre temporel est aussi vérifié sur arrival_time seul', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_arrival_only_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_arrival_only_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            arrivalTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_arrival_only_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            arrivalTime: ServiceTime(14, 45, 0),
          ),
        ],
      );
      expect(search(_engine(dataset)), isA<UnknownDeparture>());
    });

    test('deux arrêts au même instant : séquences croissantes acceptées', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_same_instant_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_same_instant_synthetic_only',
            stopId: _stop,
            stopSequence: 4,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_same_instant_synthetic_only',
            stopId: _otherStop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
        ],
      );
      // À heure égale aucune contradiction temporelle n'est démontrable : le
      // départ du stop interrogé (séquence 4) reste sélectionnable.
      final FoundDeparture result = _found(search(_engine(dataset)));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 40));
      expect(result.departures.single.stopSequence, 4);
    });

    test('trip incohérent écarté, trip valide utilisé', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[
          tripOf('test_trip_incoherent_synthetic_only'),
          tripOf('test_trip_valid_synthetic_only'),
        ],
        stopTimes: <StopTime>[
          // Trip incohérent : la séquence 2 est desservie avant la séquence 1.
          // Son 14:39, plus tôt que le candidat valide, ne doit JAMAIS sortir.
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 39, 0),
          ),
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
          StopTime(
            tripId: 'test_trip_valid_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 50, 0),
          ),
        ],
      );
      final FoundDeparture result = _found(search(_engine(dataset)));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 50));
      expect(result.departures.single.tripId, 'test_trip_valid_synthetic_only');
    });

    test('tous les trips incohérents et couverture partielle : UNKNOWN', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_incoherent_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
        provenance: _provenance(complete: false),
      );
      expect(search(_engine(dataset)), isA<UnknownDeparture>());
    });

    test('tous les trips incohérents malgré une couverture complète : UNKNOWN, jamais NoDeparture', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_incoherent_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_incoherent_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
        provenance: _provenance(complete: true),
      );
      final DepartureSearchResult result = search(_engine(dataset));
      expect(result, isA<UnknownDeparture>());
      expect(result, isNot(isA<NoDeparture>()));
    });

    test('stop_sequence dupliquée dans un trip : refusée par le dataset, UNKNOWN', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_duplicated_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_duplicated_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_duplicated_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
      );
      // Séquences identiques : déjà une erreur structurelle en amont, le moteur
      // n'a donc pas à départager deux passages homonymes.
      expect(dataset.validationErrors, isNotEmpty);
      expect(search(_engine(dataset)), isA<UnknownDeparture>());
    });

    test('prédiction temps réel sur un trip à séquence incohérente : rejetée', () {
      final ScheduleDataset dataset = _dataset(
        trips: <Trip>[tripOf('test_trip_rt_incoherent_synthetic_only')],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_rt_incoherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            departureTime: ServiceTime(14, 40, 0),
          ),
          StopTime(
            tripId: 'test_trip_rt_incoherent_synthetic_only',
            stopId: _otherStop,
            stopSequence: 1,
            departureTime: ServiceTime(14, 45, 0),
          ),
        ],
      );
      final DepartureSearchResult result = search(_engine(
        dataset,
        realtime: <RealtimePrediction>[
          RealtimePrediction(
            routeId: _route,
            tripId: 'test_trip_rt_incoherent_synthetic_only',
            stopId: _stop,
            stopSequence: 2,
            directionId: 0,
            serviceDate: monday,
            predictedDepartureAt: DateTime.utc(2026, 9, 28, 14, 42),
            observedAt: DateTime.utc(2026, 9, 28, 14, 37, 50),
            provenance: _realtimeProvenance(),
          ),
        ],
        realtimeMaxAge: const Duration(seconds: 60),
      ));
      expect(result, isA<UnknownDeparture>());
      expect(result, isNot(isA<FoundDeparture>()));
    });
  });

  group('FrequencyProvider et temps réel', () {
    test('fréquence TER seule reste ESTIMATED sans heure exacte', () {
      final DateTime now = DateTime.utc(2026, 9, 28, 14, 38);
      final DepartureSearchResult result = ScheduleEngine(
        dataset: null,
        frequencyProvider: FrequencyProvider(),
      ).nextDepartureFor(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'test_stop_ter_synthetic_only',
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      );
      expect(result, isA<EstimatedDeparture>());
      final DepartureInfo info = (result as EstimatedDeparture).info;
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 10);
      expect(info.scheduledTime, isNull);
      expect(info.nextDepartureAt, isNull);
      expect(info.etaAt, isNull);
      expect(info.serviceDate, ServiceDate(2026, 9, 28));
    });

    test('une fréquence ne donne pas un faux sens directionnel', () {
      final DepartureSearchResult result = ScheduleEngine(
        dataset: null,
        frequencyProvider: FrequencyProvider(),
      ).nextDepartureFor(
        routeId: 'ter_dakar_diamniadio',
        stopId: 'test_stop_ter_synthetic_only',
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: DateTime.utc(2026, 9, 28, 14, 38),
      );
      expect(result, isA<UnknownDeparture>());
    });

    final DateTime now = DateTime.utc(2026, 9, 28, 14, 38);
    final ScheduleDataset dataset = _dataset(times: <ServiceTime>[ServiceTime(14, 40, 0)]);

    RealtimePrediction prediction({
      String routeId = _route,
      String tripId = 'test_trip_00_synthetic_only',
      String stopId = _stop,
      int stopSequence = 1,
      int directionId = 0,
      DateTime? observedAt,
      DateTime? predictedAt,
    }) =>
        RealtimePrediction(
          routeId: routeId,
          tripId: tripId,
          stopId: stopId,
          stopSequence: stopSequence,
          directionId: directionId,
          serviceDate: ServiceDate(2026, 9, 28),
          predictedDepartureAt: predictedAt ?? DateTime.utc(2026, 9, 28, 14, 42),
          observedAt: observedAt ?? DateTime.utc(2026, 9, 28, 14, 37, 50),
          provenance: _realtimeProvenance(),
        );

    test('REAL_TIME frais du même trip/stop/sens est utilisé', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction()],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 42));
      expect(result.departures.single.status, ScheduleStatus.realTime);
      expect(result.departures.single.observedAt, DateTime.utc(2026, 9, 28, 14, 37, 50));
    });

    test('REAL_TIME exact peut fournir un départ sans departure_time statique', () {
      final ScheduleDataset withoutPublishedDeparture = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'test_trip_00_synthetic_only',
            serviceId: _serviceId,
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_00_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
          ),
        ],
      );
      final FoundDeparture result = _found(_engine(
        withoutPublishedDeparture,
        realtime: <RealtimePrediction>[prediction()],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.realTime);
      expect(result.departures.single.scheduledTime, isNull);
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 42));
    });

    test('REAL_TIME exact peut compléter un direction_id absent du trip statique', () {
      final ScheduleDataset withoutDirection = _dataset(
        trips: <Trip>[
          Trip(
            routeId: _route,
            tripId: 'test_trip_00_synthetic_only',
            serviceId: _serviceId,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_00_synthetic_only',
            stopId: _stop,
            stopSequence: 1,
          ),
        ],
      );
      final FoundDeparture result = _found(_engine(
        withoutDirection,
        realtime: <RealtimePrediction>[prediction()],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.realTime);
      expect(result.departures.single.directionId, 0);
    });

    test('REAL_TIME expiré est rejeté et retombe sur SCHEDULED', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[
          prediction(observedAt: DateTime.utc(2026, 9, 28, 14, 35)),
        ],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 40));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('REAL_TIME d’un autre trip est rejeté', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction(tripId: 'other_trip')],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('REAL_TIME d’un autre stop est rejeté', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction(stopId: _otherStop)],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('REAL_TIME d’une autre stop_sequence est rejeté', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction(stopSequence: 2)],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
      expect(result.departures.single.stopSequence, 1);
    });

    test('REAL_TIME d’une autre direction est rejeté', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction(directionId: 1)],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });

    test('REAL_TIME d’une autre route est rejeté', () {
      final FoundDeparture result = _found(_engine(
        dataset,
        realtime: <RealtimePrediction>[prediction(routeId: 'other_route')],
        realtimeMaxAge: const Duration(seconds: 60),
      ).nextDepartureFor(
        routeId: _route,
        stopId: _stop,
        directionId: 0,
        serviceDate: ServiceDate(2026, 9, 28),
        now: now,
      ));
      expect(result.departures.single.status, ScheduleStatus.scheduled);
    });
  });

  test('DataService ne donne pas une fréquence à un stop sans lien réseau exact', () {
    final DataService service = DataService();
    final DepartureInfo info = service.departureInfoForRoute(
      'ter_dakar_diamniadio',
      DateTime.utc(2026, 9, 28, 14, 38),
      stopId: 'unlinked_stop_synthetic_test',
    );
    expect(info.status, ScheduleStatus.unknown);
    expect(info.nextDepartureAt, isNull);
  });

  test('DataService permet d’injecter l’horloge du chemin legacy', () {
    final DateTime instant = DateTime.utc(2026, 9, 28, 14, 38);
    final DataService service = DataService(clock: FixedClock(instant));
    final DepartureInfo info = service.departureFor(
      routeId: null,
      stopId: null,
      network: 'fixture',
    );
    expect(info.calculatedAt, instant);
    expect(info.status, ScheduleStatus.unknown);
  });

  test('DataService reçoit route, stop, date et now explicitement', () {
    final DataService service = DataService(
      scheduleProvider: InMemoryScheduleProvider(
        _dataset(times: <ServiceTime>[ServiceTime(14, 40, 0)]),
      ),
    );
    final DepartureSearchResult result = service.nextDepartureFor(
      routeId: _route,
      stopId: _stop,
      directionId: 0,
      serviceDate: ServiceDate(2026, 9, 28),
      now: DateTime.utc(2026, 9, 28, 14, 38),
    );
    expect(_found(result).nextDepartureAt, DateTime.utc(2026, 9, 28, 14, 40));
  });

  group('station_card_display — contrat Lot 4.14 ETA universelle (6 cas)', () {
    test('cas 1 — SCHEDULED départ dans 3 min → 🟢 3 min', () {
      final calcAt = DateTime.utc(2026, 9, 28, 14, 37);
      final st = ServiceTime(14, 40, 0);
      final dataset = _dataset(times: <ServiceTime>[st]);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: calcAt,
      );
      final label = _departureDisplayLabel(info);
      expect(label, '🟢 3 min');
    });
    test('cas 2 — SCHEDULED départ maintenant → 🟢 Maintenant', () {
      final calcAt = DateTime.utc(2026, 9, 28, 14, 40);
      final st = ServiceTime(14, 40, 0);
      final dataset = _dataset(times: <ServiceTime>[st]);
      final info = DepartureInfo.scheduled(
        dataset: dataset,
        trip: dataset.trips.first,
        stopTime: dataset.stopTimes.first,
        service: dataset.services.first,
        serviceDate: ServiceDate(2026, 9, 28),
        provenance: dataset.provenance!,
        calculatedAt: calcAt,
      );
      expect(_departureDisplayLabel(info), '🟢 Maintenant');
    });
    test('cas 3 — ESTIMATED fréquence 6 ne produit pas d’ETA', () {
      final service = DataService();
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        DateTime.utc(2026, 9, 28, 14, 1),
      );
      expect(info.status, ScheduleStatus.estimated);
      expect(info.frequencyMinutes, 6);
      final label = _departureDisplayLabel(info);
      expect(label, isNot(contains('Passage estimé')));
      expect(label, isNot(contains('🟡')));
      expect(label, 'Horaire indisponible');
      expect(info.etaSource, isNull);
    });
    test('cas 4 — UNKNOWN → Horaire indisponible', () {
      final info = DepartureInfo.unknown(operator: 'Test', routeId: _route, requestedAt: DateTime.utc(2026, 9, 28, 12, 0));
      expect(_departureDisplayLabel(info), 'Horaire indisponible');
    });
    test('cas 5 — intervalle jamais présenté comme heure', () {
      final service = DataService();
      final info = service.departureInfoForRoute(
        'brt_b1_guediawaye_petersen',
        DateTime.utc(2026, 9, 28, 14, 1),
      );
      final label = _departureDisplayLabel(info);
      expect(label, isNot(contains('Passage estimé dans')));
      expect(label, isNot(contains('Passage estimé toutes les')));
      expect(label, isNot(contains('0–')));
      expect(label, isNot(contains('🟡')));
      expect(label, 'Horaire indisponible');
    });
    test('cas 6 — pas de faux zéro, pas de conversion fréquence→heure brute', () {
      final service = DataService();
      final infoNow = service.departureInfoForRoute('brt_b1_guediawaye_petersen', DateTime.utc(2026, 9, 28, 14, 0));
      expect(_departureDisplayLabel(infoNow), 'Horaire indisponible');
      expect(_departureDisplayLabel(infoNow), isNot(contains('0 min')));
      final infoTer = service.departureInfoForRoute('ter_dakar_diamniadio', DateTime.utc(2026, 9, 28, 14, 0));
      final labelTer = _departureDisplayLabel(infoTer);
      expect(labelTer, isNot(contains('Passage estimé')));
      expect(labelTer, isNot(contains('🟡')));
      expect(labelTer, isNot(contains('0 min')));
      expect(labelTer, 'Horaire indisponible');
    });
  });
}
