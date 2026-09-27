import '../models/departure_info.dart';
import '../models/schedule_models.dart';
import '../models/transport_network.dart';

/// Provider de fréquences publiées, indépendant du ScheduleProvider.
///
/// Il renvoie UNKNOWN hors des jours/plages documentés et ne produit jamais
/// REAL_TIME, une heure exacte ou une liste de stop_times.
class FrequencyProvider {
  static const String _verifiedAt = '2026-09-26';
  static const String _brtB1Url = 'https://www.sunubrt.sn/brt-1-omnibus/';
  static const String _brtB2Url = 'https://www.sunubrt.sn/brt-2-semi-express/';
  static const String _terUrl = 'https://www.terdakar.sn/les_horaires_des_trains';

  static const List<FrequencySource> officialFrequencySources =
      <FrequencySource>[
    FrequencySource(
      operator: 'SunuBRT',
      routeId: 'brt_b1_guediawaye_petersen',
      routeLabel: 'B1',
      source: _brtB1Url,
      sourceType: SourceType.officialStatic,
      dateSource: null, // La page ne publie pas de date de mise à jour.
      dateVerified: _verifiedAt,
      validFrom: null,
      validTo: null,
      confidence: 0.98,
      status: ScheduleStatus.estimated,
      operatingHours: '06:00–21:00',
      frequencies: <FrequencyWindow>[
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 6 * 60,
          endMinute: 21 * 60,
          frequencyMinutes: 6,
        ),
        FrequencyWindow(
          weekdays: <int>{DateTime.sunday},
          startMinute: 6 * 60,
          endMinute: 11 * 60,
          frequencyMinutes: 10,
          appliesOnPublicHoliday: true,
        ),
        FrequencyWindow(
          weekdays: <int>{DateTime.sunday},
          startMinute: 11 * 60,
          endMinute: 21 * 60,
          frequencyMinutes: 7,
          appliesOnPublicHoliday: true,
        ),
      ],
    ),
    FrequencySource(
      operator: 'SunuBRT',
      routeId: 'brt_b2_express',
      routeLabel: 'B2',
      source: _brtB2Url,
      sourceType: SourceType.officialStatic,
      dateSource: null,
      dateVerified: _verifiedAt,
      validFrom: null,
      validTo: null,
      confidence: 0.98,
      status: ScheduleStatus.estimated,
      operatingHours: '06:00–21:00',
      frequencies: <FrequencyWindow>[
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 6 * 60,
          endMinute: 21 * 60,
          frequencyMinutes: 6,
        ),
      ],
    ),
    FrequencySource(
      operator: 'TER Dakar',
      routeId: 'ter_dakar_diamniadio',
      routeLabel: 'TER Dakar–Diamniadio',
      source: _terUrl,
      sourceType: SourceType.officialStatic,
      dateSource: null, // Pas de date de publication visible sur cette page.
      dateVerified: _verifiedAt,
      validFrom: null,
      validTo: null,
      confidence: 0.98,
      status: ScheduleStatus.estimated,
      operatingHours: 'Selon le jour et le sens (voir plage applicable)',
      frequencies: <FrequencyWindow>[
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 5 * 60 + 35,
          endMinute: 20 * 60 + 55,
          frequencyMinutes: 10,
          direction: 'Départ de Diamniadio',
        ),
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 5 * 60 + 45,
          endMinute: 20 * 60 + 55,
          frequencyMinutes: 10,
          direction: 'Départ de Dakar',
        ),
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 21 * 60 + 5,
          endMinute: 22 * 60 + 5,
          frequencyMinutes: 20,
          direction: 'Départ de Diamniadio (21:05–22:05)',
        ),
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 21 * 60 + 5,
          endMinute: 22 * 60 + 5,
          frequencyMinutes: 20,
          direction: 'Départ de Dakar (21:05–22:05)',
        ),
        FrequencyWindow(
          weekdays: <int>{DateTime.sunday},
          startMinute: 6 * 60 + 25,
          endMinute: 22 * 60 + 5,
          frequencyMinutes: 20,
          direction: 'Toute la ligne',
          appliesOnPublicHoliday: true,
        ),
      ],
    ),
  ];

  DepartureInfo departureInfoForRoute(
    String routeId,
    DateTime requestedAt, {
    bool isPublicHoliday = false,
    String? operatorName,
    String? stopId,
    int? directionId,
    ServiceDate? serviceDate,
  }) {
    // Les fréquences sont publiées en heure de Dakar (UTC+0), indépendamment
    // du fuseau local de l'appareil.
    final DateTime dakarTime = requestedAt.isUtc ? requestedAt : requestedAt.toUtc();
    FrequencySource? source;
    for (final candidate in officialFrequencySources) {
      if (candidate.routeId == routeId) {
        source = candidate;
        break;
      }
    }

    if (source == null) {
      return DepartureInfo.unknown(
        operator: operatorName ?? _operatorForUnknownRoute(routeId),
        routeId: routeId,
        requestedAt: dakarTime,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
      );
    }

    // Les fréquences actuelles ne possèdent pas de direction_id GTFS à
    // rapprocher. Ne pas convertir un libellé de direction en identifiant.
    if (directionId != null) {
      return DepartureInfo.unknown(
        operator: operatorName ?? source.operator,
        routeId: routeId,
        source: source,
        requestedAt: dakarTime,
        stopId: stopId,
        directionId: directionId,
        serviceDate: serviceDate,
      );
    }
    if (serviceDate != null && serviceDate != ServiceDate.fromInstant(dakarTime)) {
      return DepartureInfo.unknown(
        operator: operatorName ?? source.operator,
        routeId: routeId,
        source: source,
        requestedAt: dakarTime,
        stopId: stopId,
        serviceDate: serviceDate,
      );
    }

    for (final window in source.frequencies) {
      if (window.appliesAt(dakarTime, isPublicHoliday: isPublicHoliday)) {
        return DepartureInfo.fromFrequency(
          source,
          window,
          dakarTime,
          stopId: stopId,
          serviceDate: serviceDate,
          isPublicHoliday: isPublicHoliday,
        );
      }
    }

    return DepartureInfo.unknown(
      operator: source.operator,
      routeId: routeId,
      source: source,
      requestedAt: dakarTime,
      stopId: stopId,
      directionId: directionId,
      serviceDate: serviceDate,
    );
  }

  String _operatorForUnknownRoute(String routeId) {
    if (routeId.startsWith('ddd_')) return 'Dakar Dem Dikk';
    if (routeId.startsWith('aftu_') || routeId.startsWith('line_aftu_')) {
      return 'AFTU';
    }
    if (routeId.startsWith('line_tata_') || routeId.startsWith('tata_')) {
      return 'Tata';
    }
    return 'Inconnu';
  }
}

/// Alias de compatibilité pour les appels existants. Les nouvelles intégrations
/// doivent dépendre explicitement de [FrequencyProvider], jamais d'un provider
/// mélangeant horaires et fréquences.
class DataProvider extends FrequencyProvider {
  static const List<FrequencySource> officialFrequencySources =
      FrequencyProvider.officialFrequencySources;
}
