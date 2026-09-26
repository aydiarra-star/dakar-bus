/// Injectable source of instants. Scheduling services receive an explicit
/// instant; only legacy UI adapters need the system clock fallback.
abstract interface class Clock {
  DateTime now();
}

/// System clock normalized to an absolute UTC instant. Africa/Dakar is UTC+0
/// currently, so callers never interpret the phone's wall-clock zone as Dakar.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Deterministic clock for unit tests and replay tools.
class FixedClock implements Clock {
  final DateTime instant;

  FixedClock(DateTime instant) : instant = instant.toUtc();

  @override
  DateTime now() => instant;
}
