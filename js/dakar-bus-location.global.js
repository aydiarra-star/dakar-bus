/**
 * Dakar Bus - Groupe 14
 * Bundle global pour navigateur (sans ESM) - Location / Distance / Nearby
 * Expose window.DakarBusLocation
 *
 * Respecte :
 * - Pas de donnée inventée
 * - GPS → navigateur → calcul local, jamais serveur
 * - HTTPS requis (GitHub Pages OK)
 */

(function (global) {
  const EARTH_RADIUS_METERS = 6371000;

  // --- UserLocation ---
  class UserLocation {
    constructor({ latitude, longitude, accuracy = null, timestamp = null }) {
      if (typeof latitude !== 'number' || isNaN(latitude) || latitude < -90 || latitude > 90) {
        throw new Error('UserLocation requires valid latitude -90..90');
      }
      if (typeof longitude !== 'number' || isNaN(longitude) || longitude < -180 || longitude > 180) {
        throw new Error('UserLocation requires valid longitude -180..180');
      }
      if (accuracy !== null && (typeof accuracy !== 'number' || isNaN(accuracy) || accuracy < 0)) {
        throw new Error('UserLocation accuracy must be null or >=0');
      }
      this.latitude = latitude;
      this.longitude = longitude;
      this.accuracy = accuracy;
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
      Object.freeze(this);
    }

    isRecent(maxAgeMs = 5 * 60 * 1000, now = new Date()) {
      if (!(now instanceof Date) || isNaN(now.getTime())) throw new Error('isRecent requires valid Date now');
      const age = now.getTime() - this.timestamp.getTime();
      return age >= 0 && age <= maxAgeMs;
    }

    isStale(maxAgeMs, now) {
      return !this.isRecent(maxAgeMs, now);
    }

    get lat() { return this.latitude; }
    get lng() { return this.longitude; }

    static fromGeolocationPosition(position) {
      if (!position || !position.coords) throw new Error('Invalid GeolocationPosition');
      return new UserLocation({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: typeof position.coords.accuracy === 'number' ? position.coords.accuracy : null,
        timestamp: position.timestamp ? new Date(position.timestamp) : new Date(),
      });
    }
  }

  // --- DistanceService ---
  function isValidCoordinate(lat, lon) {
    return (
      typeof lat === 'number' &&
      typeof lon === 'number' &&
      !isNaN(lat) &&
      !isNaN(lon) &&
      lat >= -90 && lat <= 90 &&
      lon >= -180 && lon <= 180
    );
  }

  function distanceMeters(lat1, lon1, lat2, lon2) {
    if (!isValidCoordinate(lat1, lon1) || !isValidCoordinate(lat2, lon2)) return null;
    const toRad = (deg) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const radLat1 = toRad(lat1);
    const radLat2 = toRad(lat2);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(radLat1) * Math.cos(radLat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return EARTH_RADIUS_METERS * c;
  }

  function formatDistance(meters) {
    if (meters === null || typeof meters !== 'number' || isNaN(meters) || meters < 0) {
      return 'Distance inconnue';
    }
    if (meters < 100) return `${Math.round(meters)} m`;
    if (meters < 1000) {
      const rounded = Math.round(meters / 10) * 10;
      return `${rounded} m`;
    }
    const km = meters / 1000;
    const kmRounded = Math.round(km * 10) / 10;
    const formatted = kmRounded.toFixed(1).replace('.', ',');
    return `${formatted} km`;
  }

  function extractStopCoordinates(stop) {
    if (!stop || typeof stop !== 'object') return null;
    let lat = null, lng = null;
    if (typeof stop.lat === 'number') {
      lat = stop.lat;
      lng = typeof stop.lng === 'number' ? stop.lng : stop.lon;
    } else if (typeof stop.latitude === 'number') {
      lat = stop.latitude;
      lng = stop.longitude;
    } else if (typeof stop.stop_lat === 'number') {
      lat = stop.stop_lat;
      lng = stop.stop_lon;
    } else if (typeof stop.stopLat === 'number') {
      lat = stop.stopLat;
      lng = stop.stopLon;
    } else if (typeof stop.stop_lat === 'string' || typeof stop.stop_lon === 'string') {
      const parsedLat = parseFloat(stop.stop_lat);
      const parsedLon = parseFloat(stop.stop_lon);
      if (!isNaN(parsedLat) && !isNaN(parsedLon)) { lat = parsedLat; lng = parsedLon; }
    } else if (typeof stop.lat === 'string' || typeof stop.lng === 'string') {
      const parsedLat = parseFloat(stop.lat);
      const parsedLon = parseFloat(stop.lng || stop.lon);
      if (!isNaN(parsedLat) && !isNaN(parsedLon)) { lat = parsedLat; lng = parsedLon; }
    }
    if (lat === null || lng === null) return null;
    if (!isValidCoordinate(lat, lng)) return null;
    return { lat, lng };
  }

  // --- LocationService ---
  const LocationErrorCode = Object.freeze({
    PERMISSION_DENIED: 'PERMISSION_DENIED',
    POSITION_UNAVAILABLE: 'POSITION_UNAVAILABLE',
    TIMEOUT: 'TIMEOUT',
    NOT_SUPPORTED: 'NOT_SUPPORTED',
    UNKNOWN: 'UNKNOWN',
  });

  class LocationError extends Error {
    constructor(code, message, originalError = null) {
      super(message);
      this.name = 'LocationError';
      this.code = code;
      this.originalError = originalError;
    }
  }

  function mapGeolocationError(geoError) {
    if (!geoError || typeof geoError.code !== 'number') return LocationErrorCode.UNKNOWN;
    switch (geoError.code) {
      case 1: return LocationErrorCode.PERMISSION_DENIED;
      case 2: return LocationErrorCode.POSITION_UNAVAILABLE;
      case 3: return LocationErrorCode.TIMEOUT;
      default: return LocationErrorCode.UNKNOWN;
    }
  }

  class LocationService {
    constructor({ defaultTimeout = 20000, enableHighAccuracy = true, maximumAge = 0 } = {}) {
      this.defaultTimeout = defaultTimeout;
      this.enableHighAccuracy = enableHighAccuracy;
      this.maximumAge = maximumAge;
    }
    isSupported() {
      return typeof navigator !== 'undefined' && !!navigator.geolocation;
    }
    getCurrentPosition(options = {}) {
      return new Promise((resolve, reject) => {
        if (!this.isSupported()) {
          reject(new LocationError(LocationErrorCode.NOT_SUPPORTED, 'Geolocation non supportée'));
          return;
        }
        const geoOptions = {
          enableHighAccuracy: options.enableHighAccuracy !== undefined ? options.enableHighAccuracy : this.enableHighAccuracy,
          timeout: options.timeout !== undefined ? options.timeout : this.defaultTimeout,
          maximumAge: options.maximumAge !== undefined ? options.maximumAge : this.maximumAge,
        };
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            try { resolve(UserLocation.fromGeolocationPosition(pos)); }
            catch (e) { reject(new LocationError(LocationErrorCode.UNKNOWN, 'Position invalide', e)); }
          },
          (err) => {
            const code = mapGeolocationError(err);
            let message = err.message || 'Erreur géolocalisation';
            if (code === LocationErrorCode.PERMISSION_DENIED) message = 'Permission GPS refusée';
            else if (code === LocationErrorCode.POSITION_UNAVAILABLE) message = 'Position indisponible';
            else if (code === LocationErrorCode.TIMEOUT) message = 'Délai localisation dépassé';
            reject(new LocationError(code, message, err));
          },
          geoOptions
        );
      });
    }
    watchPosition(onSuccess, onError, options = {}) {
      if (!this.isSupported()) {
        if (onError) onError(new LocationError(LocationErrorCode.NOT_SUPPORTED, 'Geolocation non supportée'));
        return null;
      }
      const geoOptions = {
        enableHighAccuracy: options.enableHighAccuracy !== undefined ? options.enableHighAccuracy : this.enableHighAccuracy,
        timeout: options.timeout !== undefined ? options.timeout : this.defaultTimeout,
        maximumAge: options.maximumAge !== undefined ? options.maximumAge : this.maximumAge,
      };
      return navigator.geolocation.watchPosition(
        (pos) => {
          try { if (onSuccess) onSuccess(UserLocation.fromGeolocationPosition(pos)); }
          catch (e) { if (onError) onError(new LocationError(LocationErrorCode.UNKNOWN, 'Position invalide', e)); }
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
    }
    clearWatch(watchId) {
      if (watchId !== null && this.isSupported()) navigator.geolocation.clearWatch(watchId);
    }
    static isSecureContext() {
      if (typeof window === 'undefined') return true;
      return window.isSecureContext || location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
    }
  }

  // --- NearbyStopsService ---
  class NearbyStopsService {
    constructor({ searchRadiusMeters = 1000, maxResults = 5 } = {}) {
      if (typeof searchRadiusMeters !== 'number' || searchRadiusMeters <= 0) throw new Error('searchRadiusMeters must be positive');
      if (typeof maxResults !== 'number' || maxResults <= 0) throw new Error('maxResults must be positive');
      this.searchRadiusMeters = searchRadiusMeters;
      this.maxResults = maxResults;
    }
    findNearby(userLocation, stops, overrideOptions = {}) {
      if (!userLocation) return [];
      let userLat = null, userLng = null;
      if (typeof userLocation.latitude === 'number' && typeof userLocation.longitude === 'number') {
        userLat = userLocation.latitude; userLng = userLocation.longitude;
      } else if (typeof userLocation.lat === 'number' && (typeof userLocation.lng === 'number' || typeof userLocation.lon === 'number')) {
        userLat = userLocation.lat; userLng = userLocation.lng !== undefined ? userLocation.lng : userLocation.lon;
      } else return [];
      if (!isValidCoordinate(userLat, userLng)) return [];
      if (!Array.isArray(stops) || stops.length === 0) return [];
      const radius = overrideOptions.searchRadiusMeters !== undefined ? overrideOptions.searchRadiusMeters : this.searchRadiusMeters;
      const maxRes = overrideOptions.maxResults !== undefined ? overrideOptions.maxResults : this.maxResults;
      const results = [];
      for (const stop of stops) {
        const coords = extractStopCoordinates(stop);
        if (!coords) continue;
        const dist = distanceMeters(userLat, userLng, coords.lat, coords.lng);
        if (dist === null) continue;
        if (dist > radius) continue;
        results.push({ stop, distanceMeters: dist, distanceFormatted: formatDistance(dist) });
      }
      results.sort((a, b) => a.distanceMeters - b.distanceMeters);
      return results.slice(0, maxRes);
    }
    findClosest(userLocation, stops, maxResults = this.maxResults) {
      return this.findNearby(userLocation, stops, { searchRadiusMeters: Number.MAX_SAFE_INTEGER, maxResults });
    }
    static hasValidCoordinates(stop) {
      return extractStopCoordinates(stop) !== null;
    }
  }

  // Expose
  const DakarBusLocation = {
    UserLocation,
    LocationService,
    LocationError,
    LocationErrorCode,
    DistanceService: { distanceMeters, formatDistance, isValidCoordinate, extractStopCoordinates, EARTH_RADIUS_METERS },
    NearbyStopsService,
  };

  global.DakarBusLocation = DakarBusLocation;
  if (typeof module !== 'undefined' && module.exports) module.exports = DakarBusLocation;

})(typeof window !== 'undefined' ? window : globalThis);
