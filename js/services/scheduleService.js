/**
 * Dakar Bus - Groupe 11
 * Services utilitaires pour horaires réellement sourcés
 * Ces fonctions opèrent sur des Departure réels, jamais inventés
 */

import { DataStatus } from '../models/DataStatus.js';

/**
 * Recherche le prochain départ réellement sourcé
 * @param {Array<import('../models/Departure.js').Departure>} departures - départs sourcés
 * @param {Date} after - heure de référence
 * @returns {import('../models/Departure.js').Departure|null}
 */
export function departureAfter(departures, after = new Date()) {
  if (!Array.isArray(departures) || departures.length === 0) return null;
  if (!(after instanceof Date) || isNaN(after.getTime())) {
    throw new Error('departureAfter requires valid Date');
  }

  const future = departures
    .filter(d => d.departureTime.getTime() > after.getTime())
    .sort((a, b) => a.departureTime.getTime() - b.departureTime.getTime());

  return future.length > 0 ? future[0] : null;
}

/**
 * Calcule les minutes restantes jusqu'au prochain départ réel
 * @param {Array} departures
 * @param {Date} now
 * @returns {number|null}
 */
export function remainingMinutes(departures, now = new Date()) {
  const next = departureAfter(departures, now);
  if (!next) return null;
  const diff = next.departureTime.getTime() - now.getTime();
  if (diff <= 0) return null;
  return Math.floor(diff / 60000);
}

/**
 * Label affichable pour le prochain départ
 * @param {Array} departures
 * @param {Date} now
 * @returns {string} "14 h 20" ou "Horaire non disponible"
 */
export function nextDepartureLabel(departures, now = new Date()) {
  const next = departureAfter(departures, now);
  if (!next) return 'Horaire non disponible';
  const h = next.departureTime.getHours();
  const m = next.departureTime.getMinutes().toString().padStart(2, '0');
  return `${h} h ${m}`;
}

/**
 * Détermine le DataStatus à partir d'une liste de départs
 * @param {Array} departures
 * @param {Date} now
 * @returns {string} DataStatus
 */
export function getDataStatus(departures, now = new Date()) {
  const next = departureAfter(departures, now);
  if (!next) return DataStatus.unknown;
  return next.status;
}

/**
 * Vérifie hasSourcedSchedule
 * @param {Array} departures
 * @returns {boolean}
 */
export function hasSourcedSchedule(departures) {
  return Array.isArray(departures) && departures.length > 0;
}

export default {
  departureAfter,
  remainingMinutes,
  nextDepartureLabel,
  getDataStatus,
  hasSourcedSchedule,
};
