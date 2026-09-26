import 'package:flutter_test/flutter_test.dart';
import 'package:dakar_bus/models/schedule_models.dart';
import 'package:dakar_bus/models/transport_network.dart';

const String _routeId = 'test_route_synthetic_only';
const String _stopId = 'test_stop_synthetic_only';

Service _service({
  required ServiceDate start,
  required ServiceDate end,
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
      serviceId: 'test_service_synthetic_only',
      monday: monday,
      tuesday: tuesday,
      wednesday: wednesday,
      thursday: thursday,
      friday: friday,
      saturday: saturday,
      sunday: sunday,
      startDate: start,
      endDate: end,
      exceptions: exceptions,
    );

ScheduleProvenance _provenance({
  ServiceDate? dateSource,
  ServiceDate? dateVerified,
  ServiceDate? validFrom,
  ServiceDate? validTo,
  bool omitDateSource = false,
  bool complete = true,
  ScheduleStatus scheduleStatus = ScheduleStatus.scheduled,
  SourceType sourceType = SourceType.officialStatic,
}) =>
    ScheduleProvenance(
      source: 'test-fixture://synthetic-only-not-production-data',
      sourceType: sourceType,
      dateSource: omitDateSource ? null : dateSource ?? ServiceDate(2026, 9, 1),
      dateVerified: dateVerified ?? ServiceDate(2026, 9, 26),
      validFrom: validFrom ?? ServiceDate(2026, 9, 26),
      validTo: validTo ?? ServiceDate(2026, 10, 10),
      confidence: null,
      scheduleStatus: scheduleStatus,
      coverage: ScheduleCoverage(
        complete: complete,
        scopes: <ScheduleCoverageScope>[
          ScheduleCoverageScope(
            routeId: _routeId,
            stopId: _stopId,
            allDirections: true,
          ),
          ScheduleCoverageScope(
            routeId: _routeId,
            stopId: 'test_other_stop_synthetic_only',
            allDirections: true,
          ),
        ],
      ),
    );

void main() {
  group('ServiceDate / ServiceTime', () {
    test('ServiceDate valide, parse ISO, weekday et arithmétique UTC', () {
      final ServiceDate saturday = ServiceDate.parse('2026-09-26');
      expect(saturday, ServiceDate(2026, 9, 26));
      expect(saturday.weekday, DateTime.saturday);
      expect(saturday.addDays(1), ServiceDate(2026, 9, 27));
      expect(saturday.toString(), '2026-09-26');
    });

    test('refuse une date invalide ou un format non ISO', () {
      expect(() => ServiceDate(2026, 2, 30), throwsArgumentError);
      expect(() => ServiceDate.parse('26/09/2026'), throwsFormatException);
    });

    test('ServiceTime 24:02:00 passe au lendemain et garde la serviceDate', () {
      final ServiceDate serviceDate = ServiceDate(2026, 9, 26);
      final ServiceTime serviceTime = ServiceTime.parse('24:02:00');
      expect(serviceTime.toString(), '24:02:00');
      expect(serviceTime.civilDate(serviceDate), ServiceDate(2026, 9, 27));
      expect(
        serviceTime.toInstant(serviceDate),
        DateTime.utc(2026, 9, 27, 0, 2),
      );
      // La date stockée sur le trip n'est pas remplacée par la date civile.
      expect(serviceDate, ServiceDate(2026, 9, 26));
    });

    test('ServiceTime valide les minutes/secondes et accepte une heure >= 24', () {
      expect(ServiceTime(48, 0, 0).hour, 48);
      expect(() => ServiceTime.parse('24:60:00'), throwsFormatException);
      expect(() => ServiceTime(1, 0, 60), throwsArgumentError);
      expect(() => ServiceTime(-1, 0, 0), throwsArgumentError);
    });
  });

  group('Service et exceptions', () {
    final ServiceDate saturday = ServiceDate(2026, 9, 26);
    final ServiceDate sunday = ServiceDate(2026, 9, 27);
    final ServiceDate monday = ServiceDate(2026, 9, 28);

    test('lundi et samedi actifs, dimanche inactif selon la règle hebdomadaire', () {
      final Service service = _service(start: saturday, end: monday);
      expect(service.isActiveOn(monday), isTrue);
      expect(service.isActiveOn(saturday), isTrue);
      expect(service.isActiveOn(sunday), isFalse);
    });

    test('date hors startDate/endDate inactive sans exception', () {
      final Service service = _service(start: monday, end: monday);
      expect(service.isActiveOn(saturday), isFalse);
    });

    test('exception ajoutée active un dimanche normalement inactif', () {
      final Service service = _service(
        start: saturday,
        end: monday,
        exceptions: <ServiceException>[
          ServiceException(date: sunday, serviceAdded: true),
        ],
      );
      expect(service.isActiveOn(sunday), isTrue);
    });

    test('exception supprimée désactive un lundi normalement actif', () {
      final Service service = _service(
        start: saturday,
        end: monday,
        exceptions: <ServiceException>[
          ServiceException(date: monday, serviceRemoved: true),
        ],
      );
      expect(service.isActiveOn(monday), isFalse);
    });

    test('une exception doit être exactement un ajout OU un retrait', () {
      expect(
        () => ServiceException(date: sunday),
        throwsArgumentError,
      );
      expect(
        () => ServiceException(
          date: sunday,
          serviceAdded: true,
          serviceRemoved: true,
        ),
        throwsArgumentError,
      );
    });

    test('les exceptions dupliquées pour une date sont rejetées', () {
      expect(
        () => _service(
          start: saturday,
          end: monday,
          exceptions: <ServiceException>[
            ServiceException(date: sunday, serviceAdded: true),
            ServiceException(date: sunday, serviceRemoved: true),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('Provenance et couverture', () {
    final ServiceDate date2026 = ServiceDate(2026, 9, 26);

    test('source actuelle, datée et complète couvre la requête', () {
      final ScheduleProvenance source = _provenance();
      expect(
        source.isValidScheduleFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isTrue,
      );
      expect(
        source.hasCompleteCoverageFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isTrue,
      );
    });

    test('une source sans date de publication ne valide pas SCHEDULED', () {
      final ScheduleProvenance source = _provenance(omitDateSource: true);
      expect(
        source.isValidScheduleFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isFalse,
      );
    });

    test('une source expirée ou 10/2022 ne couvre pas une requête 2026', () {
      final ScheduleProvenance historical = _provenance(
        dateSource: ServiceDate(2022, 10, 1),
        dateVerified: ServiceDate(2026, 9, 26),
        validFrom: ServiceDate(2022, 10, 1),
        validTo: ServiceDate(2022, 10, 31),
      );
      expect(
        historical.isValidScheduleFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isFalse,
      );
    });

    test('une grille partielle est sourcée mais ne prouve pas l’exhaustivité', () {
      final ScheduleProvenance partial = _provenance(complete: false);
      expect(
        partial.isValidScheduleFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isTrue,
      );
      expect(
        partial.hasCompleteCoverageFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: null,
        ),
        isFalse,
      );
    });

    test('des paires route/stop distinctes ne sont pas croisées artificiellement', () {
      final ScheduleProvenance source = ScheduleProvenance(
        source: 'test-fixture://synthetic-only-not-production-data',
        sourceType: SourceType.officialStatic,
        dateSource: ServiceDate(2026, 9, 1),
        dateVerified: ServiceDate(2026, 9, 26),
        validFrom: ServiceDate(2026, 9, 26),
        validTo: ServiceDate(2026, 10, 10),
        confidence: null,
        scheduleStatus: ScheduleStatus.scheduled,
        coverage: ScheduleCoverage(
          complete: true,
          scopes: <ScheduleCoverageScope>[
            ScheduleCoverageScope(
              routeId: 'test_route_a_synthetic_only',
              stopId: 'test_stop_a_synthetic_only',
              allDirections: true,
            ),
            ScheduleCoverageScope(
              routeId: 'test_route_b_synthetic_only',
              stopId: 'test_stop_b_synthetic_only',
              allDirections: true,
            ),
          ],
        ),
      );
      expect(
        source.isValidScheduleFor(
          serviceDate: date2026,
          routeId: 'test_route_a_synthetic_only',
          stopId: 'test_stop_b_synthetic_only',
          directionId: null,
        ),
        isFalse,
      );
    });

    test('une direction hors périmètre n’est pas couverte', () {
      final ScheduleProvenance source = ScheduleProvenance(
        source: 'test-fixture://synthetic-only-not-production-data',
        sourceType: SourceType.officialStatic,
        dateSource: ServiceDate(2026, 9, 1),
        dateVerified: ServiceDate(2026, 9, 26),
        validFrom: ServiceDate(2026, 9, 26),
        validTo: ServiceDate(2026, 10, 10),
        confidence: null,
        scheduleStatus: ScheduleStatus.scheduled,
        coverage: ScheduleCoverage(
          complete: true,
          scopes: <ScheduleCoverageScope>[
            ScheduleCoverageScope(
              routeId: _routeId,
              stopId: _stopId,
              directionIds: const <int>{0},
            ),
          ],
        ),
      );
      expect(
        source.isValidScheduleFor(
          serviceDate: date2026,
          routeId: _routeId,
          stopId: _stopId,
          directionId: 1,
        ),
        isFalse,
      );
    });
  });

  group('validation du jeu de données', () {
    test('trip/stop_time valide conserve les clés et stop_sequence', () {
      final ScheduleDataset dataset = ScheduleDataset(
        trips: <Trip>[
          Trip(
            routeId: _routeId,
            tripId: 'test_trip_synthetic_only',
            serviceId: 'test_service_synthetic_only',
            directionId: 0,
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: _stopId,
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
        provenance: _provenance(),
      );
      expect(dataset.validationErrors, isEmpty);
    });

    test('stop_time orphelin ou séquence dupliquée rend la grille invalide', () {
      final ScheduleDataset orphan = ScheduleDataset(
        trips: const <Trip>[],
        stopTimes: <StopTime>[
          StopTime(tripId: 'missing_trip', stopId: _stopId, stopSequence: 1),
        ],
        services: const <Service>[],
        provenance: _provenance(),
      );
      expect(orphan.validationErrors, isNotEmpty);

      final ScheduleDataset badSequence = ScheduleDataset(
        trips: <Trip>[
          Trip(
            routeId: _routeId,
            tripId: 'test_trip_synthetic_only',
            serviceId: 'test_service_synthetic_only',
          ),
        ],
        stopTimes: <StopTime>[
          StopTime(tripId: 'test_trip_synthetic_only', stopId: _stopId, stopSequence: 1),
          StopTime(
            tripId: 'test_trip_synthetic_only',
            stopId: 'test_other_stop_synthetic_only',
            stopSequence: 1,
          ),
        ],
        services: const <Service>[],
        provenance: _provenance(),
      );
      expect(
        badSequence.validationErrors.any((String error) => error.contains('stop_sequence')),
        isTrue,
      );
    });
  });
}
