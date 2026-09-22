/**
 * Dakar Bus - Groupe 14
 * LocationService - encapsulation navigator.geolocation
 *
 * Responsabilités :
 * - Obtenir position réelle via navigateur
 * - Gérer SUCCESS, PERMISSION_DENIED, POSITION_UNAVAILABLE, TIMEOUT
 * - Confidentialité : GPS → navigateur → calcul local, jamais serveur
 * - Pas de stockage permanent historique
 * - Pas de compte utilisateur
 *
 * HTTPS requis : navigator.geolocation nécessite contexte sécurisé (HTTPS ou localhost)
 * GitHub Pages est en HTTPS, compatible.
 */

import { UserLocation } from '../models/UserLocation.js';

export const LocationErrorCode = Object.freeze({
  PERMISSION_DENIED: 'PERMISSION_DENIED', // utilisateur refuse GPS
  POSITION_UNAVAILABLE: 'POSITION_UNAVAILABLE', // position non déterminable
  TIMEOUT: 'TIMEOUT', // délai dépassé
  NOT_SUPPORTED: 'NOT_SUPPORTED', // GPS non supporté
  UNKNOWN: 'UNKNOWN',
});

export class LocationError extends Error {
  constructor(code, message, originalError = null) {
    super(message);
    this.name = 'LocationError';
    this.code = code;
    this.originalError = originalError;
  }
}

/**
 * Mappe GeolocationPositionError navigateur vers LocationErrorCode
 * @param {GeolocationPositionError} geoError
 * @returns {string} LocationErrorCode
 */
function mapGeolocationError(geoError) {
  if (!geoError || typeof geoError.code !== 'number') {
    return LocationErrorCode.UNKNOWN;
  }
  switch (geoError.code) {
    case 1: // PERMISSION_DENIED
      return LocationErrorCode.PERMISSION_DENIED;
    case 2: // POSITION_UNAVAILABLE
      return LocationErrorCode.POSITION_UNAVAILABLE;
    case 3: // TIMEOUT
      return LocationErrorCode.TIMEOUT;
    default:
      return LocationErrorCode.UNKNOWN;
  }
}

export class LocationService {
  /**
   * @param {Object} [options]
   * @param {number} [options.defaultTimeout=10000] - timeout ms par défaut
   * @param {boolean} [options.enableHighAccuracy=true]
   * @param {number} [options.maximumAge=0] - pas de cache par défaut
   */
  constructor({ defaultTimeout = 10000, enableHighAccuracy = true, maximumAge = 0 } = {}) {
    this.defaultTimeout = defaultTimeout;
    this.enableHighAccuracy = enableHighAccuracy;
    this.maximumAge = maximumAge;
  }

  /**
   * Vérifie si geolocation supportée
   * @returns {boolean}
   */
  isSupported() {
    return typeof navigator !== 'undefined' && !!navigator.geolocation;
  }

  /**
   * Obtient position actuelle une fois
   * Utilise navigator.geolocation.getCurrentPosition
   *
   * @param {Object} [options] - PositionOptions
   * @param {boolean} [options.enableHighAccuracy]
   * @param {number} [options.timeout]
   * @param {number} [options.maximumAge]
   * @returns {Promise<UserLocation>}
   */
  getCurrentPosition(options = {}) {
    return new Promise((resolve, reject) => {
      if (!this.isSupported()) {
        reject(new LocationError(LocationErrorCode.NOT_SUPPORTED, 'Geolocation non supportée par ce navigateur'));
        return;
      }

      const geoOptions = {
        enableHighAccuracy: options.enableHighAccuracy !== undefined ? options.enableHighAccuracy : this.enableHighAccuracy,
        timeout: options.timeout !== undefined ? options.timeout : this.defaultTimeout,
        maximumAge: options.maximumAge !== undefined ? options.maximumAge : this.maximumAge,
      };

      navigator.geolocation.getCurrentPosition(
        (pos) => {
          try {
            const userLocation = UserLocation.fromGeolocationPosition(pos);
            resolve(userLocation);
          } catch (e) {
            reject(new LocationError(LocationErrorCode.UNKNOWN, 'Position invalide reçue', e));
          }
        },
        (err) => {
          const code = mapGeolocationError(err);
          let message = err.message || 'Erreur géolocalisation';
          // Messages clairs pour UI
          if (code === LocationErrorCode.PERMISSION_DENIED) {
            message = 'Permission GPS refusée';
          } else if (code === LocationErrorCode.POSITION_UNAVAILABLE) {
            message = 'Position indisponible';
          } else if (code === LocationErrorCode.TIMEOUT) {
            message = 'Délai localisation dépassé';
          }
          reject(new LocationError(code, message, err));
        },
        geoOptions
      );
    });
  }

  /**
   * Suit position en continu
   * Utilise navigator.geolocation.watchPosition
   *
   * @param {function(UserLocation)} onSuccess
   * @param {function(LocationError)} onError
   * @param {Object} [options]
   * @returns {number} watchId (à passer à clearWatch)
   */
  watchPosition(onSuccess, onError, options = {}) {
    if (!this.isSupported()) {
      if (onError) {
        onError(new LocationError(LocationErrorCode.NOT_SUPPORTED, 'Geolocation non supportée'));
      }
      return null;
    }

    const geoOptions = {
      enableHighAccuracy: options.enableHighAccuracy !== undefined ? options.enableHighAccuracy : this.enableHighAccuracy,
      timeout: options.timeout !== undefined ? options.timeout : this.defaultTimeout,
      maximumAge: options.maximumAge !== undefined ? options.maximumAge : this.maximumAge,
    };

    const watchId = navigator.geolocation.watchPosition(
      (pos) => {
        try {
          const userLocation = UserLocation.fromGeolocationPosition(pos);
          if (onSuccess) onSuccess(userLocation);
        } catch (e) {
          if (onError) onError(new LocationError(LocationErrorCode.UNKNOWN, 'Position invalide', e));
        }
      },
      (err) => {
        const code = mapGeolocationError(err);
        let message = err.message || 'Erreur géolocalisation';
        if (code === LocationErrorCode.PERMISSION_DENIED) message = 'Permission GPS refusée';
        else if (code === LocationErrorCode.POSITION_UNAVAILABLE) message = 'Position indisponible';
        else if (code === LocationErrorCode.TIMEOUT) message = 'Délai localisation dépassé';
        if (onError) onError(new LocationError(code, message, err));
      },
      geoOptions
    );

    return watchId;
  }

  /**
   * Arrête suivi
   * @param {number} watchId
   */
  clearWatch(watchId) {
    if (watchId !== null && this.isSupported()) {
      navigator.geolocation.clearWatch(watchId);
    }
  }

  /**
   * Vérifie contexte sécurisé HTTPS (requis pour geolocation sur la plupart des navigateurs)
   * @returns {boolean} true si HTTPS ou localhost
   */
  static isSecureContext() {
    if (typeof window === 'undefined') return true; // Node test env
    return window.isSecureContext || location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
  }
}

export default LocationService;
