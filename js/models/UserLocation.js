/**
 * Dakar Bus - Groupe 14
 * Modèle UserLocation - position utilisateur réelle uniquement
 *
 * Règles :
 * - Donnée locale navigateur uniquement, jamais envoyée serveur
 * - Pas d'historique déplacements
 * - Contient latitude, longitude, accuracy, timestamp
 * - Ne jamais mélanger avec horaires / ETA / positions bus
 */

export class UserLocation {
  /**
   * @param {Object} param0
   * @param {number} param0.latitude
   * @param {number} param0.longitude
   * @param {number|null} [param0.accuracy] - précision en mètres (si fournie par navigateur)
   * @param {Date|number} [param0.timestamp] - Date ou epoch ms
   */
  constructor({ latitude, longitude, accuracy = null, timestamp = null }) {
    if (typeof latitude !== 'number' || isNaN(latitude) || latitude < -90 || latitude > 90) {
      throw new Error('UserLocation requires valid latitude -90..90');
    }
    if (typeof longitude !== 'number' || isNaN(longitude) || longitude < -180 || longitude > 180) {
      throw new Error('UserLocation requires valid longitude -180..180');
    }
    if (accuracy !== null && (typeof accuracy !== 'number' || isNaN(accuracy) || accuracy < 0)) {
      throw new Error('UserLocation accuracy must be null or >=0 number');
    }

    this.latitude = latitude;
    this.longitude = longitude;
    this.accuracy = accuracy; // mètres, peut être null

    if (timestamp instanceof Date) {
      if (isNaN(timestamp.getTime())) throw new Error('Invalid timestamp Date');
      this.timestamp = new Date(timestamp.getTime());
    } else if (typeof timestamp === 'number') {
      const d = new Date(timestamp);
      if (isNaN(d.getTime())) throw new Error('Invalid timestamp number');
      this.timestamp = d;
    } else if (timestamp === null) {
      this.timestamp = new Date();
    } else {
      throw new Error('UserLocation timestamp must be Date, number or null');
    }

    // Freeze pour éviter mutation accidentelle (pas d'historique, pas d'envoi serveur)
    Object.freeze(this);
  }

  /**
   * Vérifie si position est récente
   * @param {number} maxAgeMs - âge max en ms (défaut 5 minutes = 300000 ms)
   * @param {Date} now - heure référence injectable pour tests
   * @returns {boolean}
   */
  isRecent(maxAgeMs = 5 * 60 * 1000, now = new Date()) {
    if (!(now instanceof Date) || isNaN(now.getTime())) throw new Error('isRecent requires valid Date now');
    const age = now.getTime() - this.timestamp.getTime();
    return age >= 0 && age <= maxAgeMs;
  }

  /**
   * @returns {boolean} true si position obsolète
   */
  isStale(maxAgeMs = 5 * 60 * 1000, now = new Date()) {
    return !this.isRecent(maxAgeMs, now);
  }

  /**
   * Retourne lat/lng pour compatibilité avec code existant qui utilise lat/lng
   */
  get lat() {
    return this.latitude;
  }

  get lng() {
    return this.longitude;
  }

  toString() {
    return `UserLocation(${this.latitude.toFixed(5)}, ${this.longitude.toFixed(5)}, ±${this.accuracy !== null ? Math.round(this.accuracy) + 'm' : '?'}, ${this.timestamp.toISOString()})`;
  }

  /**
   * Factory depuis GeolocationPosition navigateur
   * @param {GeolocationPosition} position
   * @returns {UserLocation}
   */
  static fromGeolocationPosition(position) {
    if (!position || !position.coords) {
      throw new Error('Invalid GeolocationPosition');
    }
    return new UserLocation({
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: typeof position.coords.accuracy === 'number' ? position.coords.accuracy : null,
      timestamp: position.timestamp ? new Date(position.timestamp) : new Date(),
    });
  }
}

export default UserLocation;
