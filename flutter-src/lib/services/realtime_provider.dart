import '../models/schedule_models.dart';

/// Separate optional source for realtime predictions. The production default
/// is empty; tests can inject explicitly synthetic predictions.
abstract interface class RealtimeProvider {
  List<RealtimePrediction> get predictions;
}

class EmptyRealtimeProvider implements RealtimeProvider {
  const EmptyRealtimeProvider();

  @override
  List<RealtimePrediction> get predictions => const <RealtimePrediction>[];
}

class InMemoryRealtimeProvider implements RealtimeProvider {
  @override
  final List<RealtimePrediction> predictions;

  InMemoryRealtimeProvider(List<RealtimePrediction> predictions)
      : predictions = List<RealtimePrediction>.unmodifiable(predictions);
}
