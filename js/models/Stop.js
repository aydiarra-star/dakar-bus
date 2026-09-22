/**
 * Dakar Bus - Groupe 11
 * Modèle Stop enrichi avec socle horaires réels
 *
 * Architecture cible :
 * SOURCE RÉELLE
 *   ↓
 * Schedule / Departure
 *   ↓
 * DataStatus.scheduled
 *   ↓
 * Stop
 *   ↓
 * departureAfter()
 *   ↓
 * remainingMinutes()
 *   ↓
 * StopCard / SingleStopView
 *
 * Règles :
 * - Aucun horaire inventé
 * - Si aucun Departure réel, hasSourcedSchedule = false, DataStatus = unknown, label = "Horaire non disponible"
 * - departureAfter() filtre les départs futurs, prend le prochain, retourne son heure
 * - Ne jamais faire heure actuelle + X, ni _generateSchedule, ni coefficient arbitraire
 */

import { DataStatus } from './DataStatus.js';
import { DataTrust } from './DataTrust.js';

export class Stop {
  /**
   * @param {Object} param0
   * @param {string} param0.id - identifiant arrêt réel
   * @param {string} param0.name
   * @param {number} [param0.lat]
   * @param {number} [param0.lng]
   * @param {Array<string>} [param0.lines]
   * @param {string} [param0.type] - TER, BRT, DDD, etc.
   * @param {Array<import('./Departure.js').Departure>} [param0.departures] - départs réellement sourcés
   * @param {string} [param0.trust] - DataTrust
   * @param {Object} [param0.raw] - données brutes originales (pour compatibilité)
   */
  constructor({ id, name, lat = null, lng = null, lines = [], type = null, departures = [], trust = DataTrust.unknown, raw = null }) {
    if (!id || typeof id !== 'string') {
      throw new Error('Stop requires id string');
    }
    if (!name || typeof name !== 'string') {
      throw new Error('Stop requires name string');
    }

    this.id = id;
    this.name = name;
    this.lat = lat;
    this.lng = lng;
    this.lines = Array.isArray(lines) ? [...lines] : [];
    this.type = type;
    this.trust = trust;
    this.raw = raw;

    // departures : uniquement des Departure réellement sourcés, jamais générés
    // On clone le tableau pour immutabilité partielle
    this._departures = Array.isArray(departures) ? [...departures] : [];

    // Ne pas freeze totalement pour permettre injection repository ultérieure,
    // mais protéger les départs
    // Object.freeze(this) serait trop restrictif pour l'intégration progressive
  }

  /**
   * @returns {Array} liste des départs réellement sourcés (copie)
   */
  get departures() {
    return [...this._departures];
  }

  /**
   * Injecte des départs réellement sourcés (remplace)
   * @param {Array<import('./Departure.js').Departure>} departures
   */
  setDepartures(departures) {
    if (!Array.isArray(departures)) {
      throw new Error('setDepartures requires array');
    }
    this._departures = [...departures];
  }

  /**
   * @returns {boolean} true si au moins un départ sourcé existe
   */
  get hasSourcedSchedule() {
    return this._departures.length > 0;
  }

  /**
   * @returns {string} DataStatus actuel
   * - scheduled si au moins un départ scheduled futur
   * - live si au moins un départ live futur (prioritaire sur scheduled si présent ? on prend le plus proche)
   * - unknown si aucun départ
   */
  get dataStatus() {
    if (!this.hasSourcedSchedule) return DataStatus.unknown;

    // Chercher le prochain départ futur (avec now réel)
    const next = this.departureAfter(new Date());
    if (!next) return DataStatus.unknown;

    return next.status;
  }

  /**
   * Retourne le prochain Departure futur après `after`
   * Principe :
   * départs réellement sourcés
   *   ↓
   * filtrer les départs futurs
   *   ↓
   * prendre le prochain
   *   ↓
   * retourner son heure
   *
   * @param {Date} after - heure de référence (injectable pour tests)
   * @returns {import('./Departure.js').Departure|null}
   */
  departureAfter(after = new Date()) {
    if (!(after instanceof Date) || isNaN(after.getTime())) {
      throw new Error('departureAfter requires valid Date');
    }

    if (this._departures.length === 0) return null;

    // Filtrer futurs, trier par heure
    const future = this._departures
      .filter(d => d.departureTime.getTime() > after.getTime())
      .sort((a, b) => a.departureTime.getTime() - b.departureTime.getTime());

    if (future.length === 0) return null;

    return future[0];
  }

  /**
   * @param {Date} now - heure injectable
   * @returns {number|null} minutes restantes jusqu'au prochain départ réel, null si aucun
   * Ne retourne jamais 5/10/15 par défaut
   */
  remainingMinutes(now = new Date()) {
    const next = this.departureAfter(now);
    if (!next) return null;
    const diffMs = next.departureTime.getTime() - now.getTime();
    if (diffMs <= 0) return null;
    return Math.floor(diffMs / 60000);
  }

  /**
   * @param {Date} now
   * @returns {string} label affichable
   * - Si vrai départ : "14 h 20" (format local)
   * - Sinon : "Horaire non disponible"
   */
  nextDepartureLabel(now = new Date()) {
    const next = this.departureAfter(now);
    if (!next) {
      return 'Horaire non disponible';
    }

    // Format 14 h 20
    const hours = next.departureTime.getHours();
    const minutes = next.departureTime.getMinutes().toString().padStart(2, '0');
    return `${hours} h ${minutes}`;
  }

  /**
   * @deprecated _generateSchedule ne doit plus être utilisé comme source de départ réel
   * Conservé uniquement pour documentation / compatibilité tests anciens non affichés
   * NE PAS UTILISER
   */
  _generateSchedule() {
    console.warn('_generateSchedule is deprecated and must not be used as real departure source. Use ScheduleRepository instead.');
    return [];
  }

  toString() {
    return `Stop(${this.id}, ${this.name}, departures=${this._departures.length})`;
  }
}

export default Stop;
