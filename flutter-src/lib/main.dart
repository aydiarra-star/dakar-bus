/// Dakar Bus - Groupe 11
/// Main : point d'entrée, utilise socle horaires réels sans générer de faux horaires
/// Architecture :
/// SOURCE RÉELLE -> Departure -> ScheduleRepository -> Stop -> departureAfter() -> UI
/// Si aucune source réelle branchée : Aucune source -> aucun Departure -> unknown -> Horaire non disponible (comportement CORRECT)

import 'models/data_status.dart';
import 'models/stop.dart';
import 'repositories/unavailable_schedule_repository.dart';
import 'data_service.dart';

void main() {
  // Groupe 11 : aucune source réelle branchée à ce stade
  final repository = UnavailableScheduleRepository();
  final dataService = DataService(scheduleRepository: repository);

  // Exemple d'utilisation correcte :
  // - Aucune source -> liste vide -> Horaire non disponible
  // - Avec source réelle future : repository GTFS ou API officielle
  // Ne jamais faire : DateTime.now() comme heure de départ, _generateSchedule, distance -> durée

  // Pour l'instant, l'app affiche "Horaire non disponible" tant qu'aucune source réelle n'est branchée
  // C'est le comportement attendu et validé Groupe 11
  print('Dakar Bus Groupe 11 - Socle horaires réels prêt');
  print('Source réelle branchée : Aucune source réelle branchée à ce stade');
  print('DataStatus : ${DataStatus.unknown} -> Horaire non disponible');
}
