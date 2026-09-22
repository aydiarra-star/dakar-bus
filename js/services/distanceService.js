/**
 * Dakar Bus - Groupe 14
 * DistanceService - calcul géographique pur, testable
 *
 * Règle absolue : pas de donnée inventée, formule correcte Haversine
 * Ne jamais faire latitude difference × constante arbitraire
 */

const EARTH_RADIUS_METERS = 6371000; // rayon moyen Terre en mètres

/**
 * Vérifie si coordonnées valides
 * @param {number} lat
 * @param {number} lon
 * @returns {boolean}
 */
export function isValidCoordinate(lat, lon) {
  return (
    typeof lat === 'number' &&
    typeof lon === 'number' &&
    !isNaN(lat) &&
    !isNaN(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180
  );
}

/**
 * Calcul distance Haversine pure
 * position utilisateur → arrêt
 *
 * @param {number} lat1 - latitude point 1
 * @param {number} lon1 - longitude point 1
 * @param {number} lat2 - latitude point 2
 * @param {number} lon2 - longitude point 2
 * @returns {number|null} distance en mètres, null si coordonnées invalides
 */
export function distanceMeters(lat1, lon1, lat2, lon2) {
  if (!isValidCoordinate(lat1, lon1) || !isValidCoordinate(lat2, lon2)) {
    return null;
  }

  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const radLat1 = toRad(lat1);
  const radLat2 = toRad(lat2);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(radLat1) * Math.cos(radLat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  const distance = EARTH_RADIUS_METERS * c;

  // Retourne distance brute (non arrondie) pour tri précis, formatage séparé
  return distance;
}

/**
 * Formate distance pour affichage lisible
 * Règle :
 * < 1000 m → mètres
 * ≥ 1000 m → kilomètres
 * Pas de précision excessive : 347,238 → 350 m
 *
 * @param {number|null} meters
 * @returns {string} ex: "120 m", "350 m", "0,8 km", "1,2 km", "Distance inconnue" si null
 */
export function formatDistance(meters) {
  if (meters === null || typeof meters !== 'number' || isNaN(meters) || meters < 0) {
    return 'Distance inconnue';
  }

  if (meters < 100) {
    // <100 m : mètre près
    return `${Math.round(meters)} m`;
  }

  if (meters < 1000) {
    // 100-999 m : arrondi à la dizaine la plus proche pour éviter 347,238
    const rounded = Math.round(meters / 10) * 10;
    return `${rounded} m`;
  }

  // ≥1000 m : kilomètres avec 1 décimale, virgule française
  const km = meters / 1000;
  // Arrondi à 1 décimale
  const kmRounded = Math.round(km * 10) / 10;
  // Format français avec virgule
  const formatted = kmRounded.toFixed(1).replace('.', ',');
  return `${formatted} km`;
}

/**
 * Extrait lat/lng d'un arrêt de manière tolérante
 * Supporte formats : {lat,lng}, {latitude,longitude}, {stop_lat,stop_lon}, {stopLat,stopLon}
 * @param {Object} stop
 * @returns {{lat:number, lng:number}|null}
 */
export function extractStopCoordinates(stop) {
  if (!stop || typeof stop !== 'object') return null;

  let lat = null;
  let lng = null;

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
    // GTFS txt parsing peut donner string
    const parsedLat = parseFloat(stop.stop_lat);
    const parsedLon = parseFloat(stop.stop_lon);
    if (!isNaN(parsedLat) && !isNaN(parsedLon)) {
      lat = parsedLat;
      lng = parsedLon;
    }
  } else if (typeof stop.lat === 'string' || typeof stop.lng === 'string') {
    const parsedLat = parseFloat(stop.lat);
    const parsedLon = parseFloat(stop.lng || stop.lon);
    if (!isNaN(parsedLat) && !isNaN(parsedLon)) {
      lat = parsedLat;
      lng = parsedLon;
    }
  }

  if (lat === null || lng === null) return null;
  if (!isValidCoordinate(lat, lng)) return null;

  return { lat, lng };
}

export default {
  distanceMeters,
  formatDistance,
  isValidCoordinate,
  extractStopCoordinates,
  EARTH_RADIUS_METERS,
};
