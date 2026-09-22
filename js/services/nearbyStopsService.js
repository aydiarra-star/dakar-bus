/**
 * Dakar Bus - Groupe 14
 * NearbyStopsService - arrêts les plus proches
 *
 * Responsabilité :
 * UserLocation + liste réelle arrêts connus
 * → distance calculée (Haversine)
 * → tri par distance
 *
 * Règles :
 * - Ne pas inventer coordonnées arrêts, utiliser données existantes projet
 * - Si arrêt sans lat/lng → distance inconnue → ignoré
 * - Ne pas géocoder noms avec Google Maps ou autre API
 * - Ne pas créer arrêt artificiel si aucun dans rayon → message "Aucun arrêt connu à proximité"
 * - GPS ne change pas disponibilité horaires (UNKNOWN reste UNKNOWN)
 */

import { isValidCoordinate, distanceMeters, formatDistance, extractStopCoordinates } from './distanceService.js';

export class NearbyStopsService {
  /**
   * @param {Object} [options]
   * @param {number} [options.searchRadiusMeters=1000] - rayon défaut 1000 m
   * @param {number} [options.maxResults=5] - nombre résultats défaut 5
   */
  constructor({ searchRadiusMeters = 1000, maxResults = 5 } = {}) {
    if (typeof searchRadiusMeters !== 'number' || searchRadiusMeters <= 0) {
      throw new Error('searchRadiusMeters must be positive number');
    }
    if (typeof maxResults !== 'number' || maxResults <= 0) {
      throw new Error('maxResults must be positive number');
    }
    this.searchRadiusMeters = searchRadiusMeters;
    this.maxResults = maxResults;
  }

  /**
   * Trouve arrêts proches
   *
   * @param {import('../models/UserLocation.js').UserLocation|Object} userLocation - doit avoir latitude/longitude ou lat/lng
   * @param {Array<Object>} stops - liste arrêts réels du projet (avec lat/lng)
   * @param {Object} [overrideOptions]
   * @param {number} [overrideOptions.searchRadiusMeters] - rayon custom
   * @param {number} [overrideOptions.maxResults] - max custom
   * @returns {Array<{stop:Object, distanceMeters:number, distanceFormatted:string}>} trié proche→loin
   */
  findNearby(userLocation, stops, overrideOptions = {}) {
    // Validation position utilisateur - ne jamais inventer position
    if (!userLocation) {
      return [];
    }

    let userLat = null;
    let userLng = null;

    if (typeof userLocation.latitude === 'number' && typeof userLocation.longitude === 'number') {
      userLat = userLocation.latitude;
      userLng = userLocation.longitude;
    } else if (typeof userLocation.lat === 'number' && (typeof userLocation.lng === 'number' || typeof userLocation.lon === 'number')) {
      userLat = userLocation.lat;
      userLng = userLocation.lng !== undefined ? userLocation.lng : userLocation.lon;
    } else {
      // Position invalide → aucun résultat, pas de faux emplacement
      return [];
    }

    if (!isValidCoordinate(userLat, userLng)) {
      return [];
    }

    if (!Array.isArray(stops) || stops.length === 0) {
      return [];
    }

    const radius = overrideOptions.searchRadiusMeters !== undefined ? overrideOptions.searchRadiusMeters : this.searchRadiusMeters;
    const maxRes = overrideOptions.maxResults !== undefined ? overrideOptions.maxResults : this.maxResults;

    if (typeof radius !== 'number' || radius <= 0) {
      throw new Error('searchRadiusMeters must be positive');
    }
    if (typeof maxRes !== 'number' || maxRes <= 0) {
      throw new Error('maxResults must be positive');
    }

    const results = [];

    for (const stop of stops) {
      // Extraire coordonnées arrêt depuis données existantes uniquement
      const coords = extractStopCoordinates(stop);
      if (!coords) {
        // Arrêt sans coordonnées valides → ignoré (ne pas deviner via nom)
        continue;
      }

      const dist = distanceMeters(userLat, userLng, coords.lat, coords.lng);
      if (dist === null) {
        continue;
      }

      // Filtre rayon
      if (dist > radius) {
        continue;
      }

      results.push({
        stop,
        distanceMeters: dist,
        distanceFormatted: formatDistance(dist),
      });
    }

    // Tri proche → éloigné
    results.sort((a, b) => a.distanceMeters - b.distanceMeters);

    // Limiter nombre résultats
    return results.slice(0, maxRes);
  }

  /**
   * Version sans filtre rayon, retourne tous triés (pour cas "aucun dans rayon" → message approprié)
   * Utile pour UI qui veut afficher message si 0 dans rayon mais arrêts existent plus loin
   *
   * @param {Object} userLocation
   * @param {Array} stops
   * @param {number} maxResults
   * @returns {Array}
   */
  findClosest(userLocation, stops, maxResults = this.maxResults) {
    return this.findNearby(userLocation, stops, { searchRadiusMeters: Number.MAX_SAFE_INTEGER, maxResults });
  }

  /**
   * Helper pour vérifier si arrêt a coordonnées valides (pour tests / filtrage UI)
   * @param {Object} stop
   * @returns {boolean}
   */
  static hasValidCoordinates(stop) {
    const coords = extractStopCoordinates(stop);
    return coords !== null;
  }
}

export default NearbyStopsService;
