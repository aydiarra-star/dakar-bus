/**
 * Dakar Bus - Groupe 11
 * Modèle Departure : représente un départ réellement sourcé
 *
 * RÈGLE ABSOLUE : aucune donnée inventée.
 * - departureTime doit provenir d'une source réelle
 * - Pas de DateTime.now() comme heure de départ
 * - Pas de distance -> durée
 * - Pas de vitesse arbitraire
 * - Pas de _generateSchedule
 *
 * Immutable, typé, minimal.
 */

import { DataStatus, isValidDataStatus } from './DataStatus.js';

export class Departure {
  /**
   * @param {Object} param0
   * @param {string} param0.stopId - identifiant arrêt réel (ex: TER_01_Dakar)
   * @param {string} param0.lineId - identifiant ligne réelle (ex: TER, BRT 01)
   * @param {Date} param0.departureTime - Date réelle du départ, sourcée
   * @param {string} param0.status - DataStatus.scheduled | live | unknown
   * @param {string|null} [param0.direction] - direction optionnelle (ex: Diamniadio)
   * @param {string|null} [param0.sourceId] - id source réelle (ex: gtfs-cetud-2026)
   */
  constructor({ stopId, lineId, departureTime, status, direction = null, sourceId = null }) {
    if (!stopId || typeof stopId !== 'string') {
      throw new Error('Departure requires stopId string');
    }
    if (!lineId || typeof lineId !== 'string') {
      throw new Error('Departure requires lineId string');
    }
    if (!(departureTime instanceof Date) || isNaN(departureTime.getTime())) {
      throw new Error('Departure requires valid Date departureTime from real source');
    }
    if (!isValidDataStatus(status)) {
      throw new Error(`Departure status must be one of ${Object.values(DataStatus).join(', ')}`);
    }
    // Interdiction: status unknown ne devrait pas avoir de departureTime exploitable
    // Mais on autorise si réellement nécessaire (ex: source indique unknown)
    // On ne génère jamais de temps arbitraire.

    this.stopId = stopId;
    this.lineId = lineId;
    this.departureTime = new Date(departureTime.getTime()); // clone, immutable
    this.status = status;
    this.direction = direction;
    this.sourceId = sourceId;

    Object.freeze(this);
  }

  /**
   * @param {Date} now - heure de référence injectable pour tests
   * @returns {boolean} true si départ dans le futur
   */
  isFuture(now = new Date()) {
    return this.departureTime.getTime() > now.getTime();
  }

  /**
   * @param {Date} now
   * @returns {number|null} minutes restantes, null si passé
   * Ne retourne jamais 5/10/15 par défaut.
   */
  remainingMinutes(now = new Date()) {
    const diffMs = this.departureTime.getTime() - now.getTime();
    if (diffMs <= 0) return null;
    return Math.floor(diffMs / 60000);
  }

  toString() {
    return `Departure(${this.stopId}, ${this.lineId}, ${this.departureTime.toISOString()}, ${this.status})`;
  }
}

export default Departure;
