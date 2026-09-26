import '../models/schedule_models.dart';

/// Separate contract for verified static schedules. No production TER grid is
/// bundled: the default provider is deliberately empty until a sourced dataset
/// has been reviewed and supplied.
abstract interface class ScheduleProvider {
  ScheduleDataset? get dataset;
}

class EmptyScheduleProvider implements ScheduleProvider {
  const EmptyScheduleProvider();

  @override
  ScheduleDataset? get dataset => null;
}

/// In-memory provider useful for repository adapters and synthetic unit tests.
/// It is not wired to production assets by default.
class InMemoryScheduleProvider implements ScheduleProvider {
  @override
  final ScheduleDataset? dataset;

  const InMemoryScheduleProvider(this.dataset);
}
