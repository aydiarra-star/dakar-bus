import '../models/departure_info.dart';
import 'eta_calculator.dart';

/// Présentation unique : source ETA et état d'exploitation restent orthogonaux.
/// Sans ETA, ne pas prétendre que le service est interrompu ou en retard.
class DeparturePresentation {
  final String label;
  final OperationalStatus? operationalStatus;
  final EtaResult? eta;

  const DeparturePresentation._(this.label, this.operationalStatus, this.eta);

  /// Une absence d'ETA n'est pas un passage à afficher. Conservé comme valeur
  /// de compatibilité pour les appels qui attendent encore un String.
  static const String noEta = '';

  bool get hasDisplay => label.isNotEmpty;

  static DeparturePresentation at(DepartureInfo? info, DateTime at) {
    if (info == null) return const DeparturePresentation._(noEta, null, null);
    final status = info.operationalStatusAt(at);
    if (status == OperationalStatus.unavailable) {
      return const DeparturePresentation._('🔴 Indisponible',
          OperationalStatus.unavailable, null);
    }
    final eta = EtaCalculator.fromDepartureInfo(info, at);
    if (eta == null) return const DeparturePresentation._(noEta, null, null);
    final prefix = status == OperationalStatus.delayed ? '🟡' : '🟢';
    final text = eta.isNow ? 'Maintenant' : '${eta.minutes} min';
    return DeparturePresentation._('$prefix $text',
        status == OperationalStatus.delayed
            ? OperationalStatus.delayed : OperationalStatus.normal, eta);
  }
}
