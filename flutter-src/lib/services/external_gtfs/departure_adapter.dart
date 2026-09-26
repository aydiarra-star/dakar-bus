import '../../models/departure_info.dart';
import '../../models/transport_network.dart' as ui;
import 'gtfs_schedule_service.dart';
import 'gtfs_time.dart';
import 'transit_data_provider.dart';

/// Explicit crosswalk, never inferred from names, coordinates or colors.
/// Register only when the source covers this route/stop/direction. A frequency
/// binding additionally requires documented applicability at that stop.
class DepartureBinding {
  const DepartureBinding({required this.network, required this.routeId,
    required this.stopId, required this.providerRouteId,
    required this.providerStopId, this.directionId,
    this.frequencyAppliesAtStop = false});
  final String network;
  final String routeId;
  final String stopId;
  final String providerRouteId;
  final String? providerStopId;
  final String? directionId;
  final bool frequencyAppliesAtStop;
}

class DepartureAdapter {
  DepartureAdapter(this.provider, {Iterable<DepartureBinding> bindings = const []})
      : bindings = List.unmodifiable(bindings);
  final TransitDataProvider provider;
  final List<DepartureBinding> bindings;

  DepartureInfo resolve({required String network, required String routeId,
    required String stopId, String? directionId, DateTime? at}) {
    final matches = bindings.where((b) => b.network.toUpperCase() == network.toUpperCase()
        && b.routeId == routeId && b.stopId == stopId
        && (directionId == null || b.directionId == directionId)).toList();
    // Ambiguity is not resolved by picking the first route or direction.
    if (matches.length != 1) return const DepartureInfo.unknown();
    final binding = matches.single;
    final instant = (at ?? provider.now()).toUtc(); // Africa/Dakar = UTC+0
    final clock = dakarClock(instant);
    final result = provider.getDepartures(binding.providerRouteId,
        binding.providerStopId, date: clock.serviceDate, time: clock.time);
    if (!result.isCurrent || (result.network != null &&
        result.network!.toUpperCase() != network.toUpperCase())) {
      return const DepartureInfo.unknown();
    }
    if (result.status == ScheduleStatus.estimated) {
      final estimate = result.estimate;
      if (!binding.frequencyAppliesAtStop || estimate == null ||
          estimate.network.toUpperCase() != network.toUpperCase() ||
          estimate.headwayMinutes <= 0) return const DepartureInfo.unknown();
      return DepartureInfo(status: ui.ScheduleStatus.estimated,
        referenceTime: instant, evidence: result, estimatedWaitFrom: 0,
        estimatedWaitTo: estimate.headwayMinutes,
        frequencyMinutes: estimate.headwayMinutes);
    }
    if (result.status != ScheduleStatus.scheduled && result.status != 'REAL_TIME') {
      return const DepartureInfo.unknown();
    }
    final candidates = result.departures.where((d) =>
        d.routeId == binding.providerRouteId && d.stopId == binding.providerStopId &&
        (binding.directionId == null || d.direction.directionId == binding.directionId))
        .map((d) => DateTime.parse('${toIsoDate(d.serviceDate)}T00:00:00Z')
            .add(Duration(seconds: d.departureSeconds)))
        .where((time) => !time.isBefore(instant)).toList()..sort();
    if (candidates.isEmpty) return const DepartureInfo.unknown();
    final time = candidates.first;
    if (result.status == 'REAL_TIME') {
      // Only relay a provider classification; never infer it from static data.
      return DepartureInfo(status: ui.ScheduleStatus.realTime,
        referenceTime: instant, evidence: result,
        estimatedWaitTo: (time.difference(instant).inSeconds / 60).ceil());
    }
    return DepartureInfo(status: ui.ScheduleStatus.scheduled,
      referenceTime: instant, evidence: result, scheduledTime: time);
  }
}
