/**
 * Dakar Bus - Groupe 11
 * UnavailableScheduleRepository : premier repository, aucune donnée fausse
 *
 * Comportement :
 * aucune source réelle branchée
 *   ↓
 * liste vide
 *   ↓
 * Horaire non disponible
 *
 * Il ne doit générer aucun horaire.
 * Cette étape est volontaire : architecture fonctionnelle avant première source réelle.
 */

import { ScheduleRepository } from './ScheduleRepository.js';

export class UnavailableScheduleRepository extends ScheduleRepository {
  /**
   * @param {string} stopId
   * @returns {Promise<Array>} toujours vide
   */
  async departuresForStop(stopId) {
    // Aucune source réelle branchée à ce stade
    // Retourne volontairement une liste vide, pas de génération
    return [];
  }
}

export default UnavailableScheduleRepository;
