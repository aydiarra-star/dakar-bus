/**
 * Dakar Bus - Groupe 11
 * ScheduleRepository : abstraction pour récupérer les départs réellement sourcés
 *
 * Permettra ultérieurement de brancher :
 * - GTFS
 * - API officielle
 * - fichier officiel
 * - flux temps réel
 * - base distante
 *
 * Sans devoir réécrire StopCard ou SingleStopView
 */

export class ScheduleRepository {
  /**
   * @param {string} stopId
   * @returns {Promise<Array<import('../models/Departure.js').Departure>>}
   * Doit retourner une liste de Departure réellement sourcés, jamais inventés
   */
  async departuresForStop(stopId) {
    throw new Error('ScheduleRepository.departuresForStop() must be implemented by subclass');
  }

  /**
   * Optionnel : pour compatibilité future, récupérer pour une ligne spécifique
   * @param {string} stopId
   * @param {string} lineId
   * @returns {Promise<Array>}
   */
  async departuresForStopAndLine(stopId, lineId) {
    const all = await this.departuresForStop(stopId);
    return all.filter(d => d.lineId === lineId);
  }
}

export default ScheduleRepository;
