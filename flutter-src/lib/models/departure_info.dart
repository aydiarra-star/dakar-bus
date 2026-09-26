import 'transport_network.dart';
import '../services/external_gtfs/gtfs_schedule_service.dart' show DepartureResult;

/// Presentation contract. A frequency never populates [scheduledTime].
class DepartureInfo {
  const DepartureInfo.unknown()
      : status = ScheduleStatus.unknown,
        scheduledTime = null, estimatedWaitFrom = null, estimatedWaitTo = null,
        frequencyMinutes = null, referenceTime = null, evidence = null;

  const DepartureInfo({required this.status, required this.referenceTime,
    required this.evidence, this.scheduledTime, this.estimatedWaitFrom,
    this.estimatedWaitTo, this.frequencyMinutes});

  final ScheduleStatus status;
  final DateTime? scheduledTime;
  final int? estimatedWaitFrom;
  final int? estimatedWaitTo;
  final int? frequencyMinutes;
  final DateTime? referenceTime;
  /// Original result retains source, type, validity and provenance level.
  final DepartureResult? evidence;

  String get label {
    switch (status) {
      case ScheduleStatus.estimated:
        return 'Prochain passage\ndans $estimatedWaitFrom–$estimatedWaitTo min\nEstimation';
      case ScheduleStatus.scheduled:
        final time = scheduledTime;
        if (time == null) return 'Horaire indisponible';
        return 'Départ ${time.hour.toString().padLeft(2, '0')}h${time.minute.toString().padLeft(2, '0')}\nProgrammé';
      case ScheduleStatus.realTime:
        return 'Arrivée dans $estimatedWaitTo min\nTemps réel';
      case ScheduleStatus.unknown:
        return 'Horaire indisponible';
    }
  }
}
