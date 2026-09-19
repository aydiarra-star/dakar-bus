/**
 * Service de Road Snapping - Aligne les itinéraires aux routes réelles de Dakar.
 * Utilise OSRM (Open Source Routing Machine).
 *
 * RÈGLES FONDAMENTALES (voir CORRECTIFS.md §4) :
 *  1. Ordre des coordonnées :
 *     - OSRM / GeoJSON      → [lng, lat]   (longitude d'abord)
 *     - Leaflet / GTFS      → [lat, lng]   (latitude d'abord)
 *     Toute conversion passe par des helpers explicites (toLatLng / toLngLat),
 *     et chaque point est validé contre la boîte englobante de Dakar.
 *  2. Décodage : les polylines encodées (Google/OSRM) sont décodées par
 *     `decodePolyline()` qui renvoie des paires [lat, lng] (ordre natif du format).
 *  3. AUCUN repli en ligne droite : si OSRM échoue, une erreur `RoadSnappingError`
 *     est levée. On ne remplace JAMAIS un tracé routier par des vecteurs directs.
 *  4. Points de passage : tous les arrêts intermédiaires de la ligne sont transmis
 *     à OSRM (triés par `sequence`) pour que le tracé épouse la voirie réelle.
 */

export const OSRM_BASE_URL = process.env.OSRM_BASE_URL || 'https://router.project-osrm.org';
export const OSRM_PROFILE = process.env.OSRM_PROFILE || 'driving';

/** Boîte englobante (large) de la région de Dakar : Plateau → Diamniadio/AIBD. */
export const DAKAR_BBOX = Object.freeze({ minLat: 14.55, maxLat: 14.95, minLng: -17.60, maxLng: -16.95 });

/** Limites OSRM : nb max de coordonnées par requête (le serveur public en accepte ~100). */
export const OSRM_MAX_COORDS_PER_REQUEST = 90;

export class RoadSnappingError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'RoadSnappingError';
    this.details = details;
  }
}

export class CoordinateOrderError extends RoadSnappingError {
  constructor(message, details = {}) {
    super(message, details);
    this.name = 'CoordinateOrderError';
  }
}

// ---------------------------------------------------------------------------
// Géométrie de base
// ---------------------------------------------------------------------------

/** Distance Haversine en km. */
export function getDistanceKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function isFiniteNumber(n) {
  return typeof n === 'number' && Number.isFinite(n);
}

/** Vrai si (lat, lng) est dans la région de Dakar. */
export function isInDakar(lat, lng, bbox = DAKAR_BBOX) {
  return isFiniteNumber(lat) && isFiniteNumber(lng)
    && lat >= bbox.minLat && lat <= bbox.maxLat
    && lng >= bbox.minLng && lng <= bbox.maxLng;
}

/**
 * Détecte une inversion lat/lng : le couple n'est pas dans Dakar,
 * mais le couple inversé l'est (ex: [ -17.44, 14.69 ] lu comme [lat, lng]).
 */
export function looksSwapped(lat, lng, bbox = DAKAR_BBOX) {
  return !isInDakar(lat, lng, bbox) && isInDakar(lng, lat, bbox);
}

/**
 * Normalise un arrêt vers { id, name, lat, lng, sequence }.
 * Accepte {lat,lng} | {stop_lat,stop_lon} | {latitude,longitude} | {lat,lon}.
 * Lève CoordinateOrderError si les coordonnées semblent inversées
 * (sauf option autoFixSwapped:true → corrige et journalise).
 */
export function normalizeStop(stop, index = 0, options = {}) {
  if (!stop || typeof stop !== 'object') {
    throw new RoadSnappingError(`Arrêt #${index} invalide (objet attendu)`);
  }
  const lat = Number(stop.lat ?? stop.stop_lat ?? stop.latitude);
  const lng = Number(stop.lng ?? stop.lon ?? stop.stop_lon ?? stop.longitude);
  const name = stop.name ?? stop.stop_name ?? stop.id ?? stop.stop_id ?? `arrêt ${index + 1}`;
  const id = stop.id ?? stop.stop_id ?? `stop_${index + 1}`;
  const sequence = stop.sequence ?? stop.stop_sequence;

  if (!isFiniteNumber(lat) || !isFiniteNumber(lng)) {
    throw new RoadSnappingError(`Arrêt "${name}" (#${index}) : coordonnées non numériques`, { stop });
  }

  let fixedLat = lat;
  let fixedLng = lng;
  if (looksSwapped(lat, lng, options.bbox)) {
    if (options.autoFixSwapped) {
      (options.logger || console).warn(`⚠️ Arrêt "${name}" : lat/lng inversés (${lat}, ${lng}) → corrigés`);
      fixedLat = lng;
      fixedLng = lat;
    } else {
      throw new CoordinateOrderError(
        `Arrêt "${name}" (#${index}) : latitude/longitude inversées (${lat}, ${lng}). ` +
        `Attendu lat≈14.7, lng≈-17.4 pour Dakar.`,
        { stop }
      );
    }
  } else if (!isInDakar(fixedLat, fixedLng, options.bbox) && !options.allowOutsideDakar) {
    throw new RoadSnappingError(`Arrêt "${name}" (#${index}) hors de la région de Dakar (${lat}, ${lng})`, { stop });
  }

  return {
    id: String(id),
    name: String(name),
    lat: fixedLat,
    lng: fixedLng,
    sequence: sequence === undefined || sequence === null || sequence === '' ? undefined : Number(sequence)
  };
}

/**
 * Valide l'ordre des arrêts et détecte les anomalies (écarts > 10 km).
 * @returns {{ stops: Array, anomalies: Array }}
 */
export function validateAndSortStops(stops, options = {}) {
  if (!Array.isArray(stops) || stops.length === 0) {
    throw new RoadSnappingError('Aucun arrêt fourni');
  }
  const normalized = stops.map((s, i) => normalizeStop(s, i, options));

  // Tri par séquence si disponible (tri stable, conserve l'ordre pour séquences égales)
  const hasSequence = normalized.every((s) => isFiniteNumber(s.sequence));
  const sorted = hasSequence
    ? normalized.map((s, i) => ({ s, i })).sort((a, b) => (a.s.sequence - b.s.sequence) || (a.i - b.i)).map((x) => x.s)
    : normalized;

  // Suppression des doublons consécutifs (même position) : OSRM n'aime pas les legs de 0 m
  const deduped = sorted.filter((s, i) => {
    if (i === 0) return true;
    const p = sorted[i - 1];
    return getDistanceKm(p.lat, p.lng, s.lat, s.lng) > 0.005; // > 5 m
  });

  if (deduped.length < 2) {
    throw new RoadSnappingError('Au moins 2 arrêts distincts requis');
  }

  const anomalies = [];
  const maxGapKm = options.maxGapKm ?? 10;
  for (let i = 0; i < deduped.length - 1; i++) {
    const d = getDistanceKm(deduped[i].lat, deduped[i].lng, deduped[i + 1].lat, deduped[i + 1].lng);
    if (d > maxGapKm) {
      anomalies.push({
        from: deduped[i].name,
        to: deduped[i + 1].name,
        distanceKm: Number(d.toFixed(2)),
        severity: d > 2 * maxGapKm ? 'CRITIQUE' : 'ATTENTION'
      });
    }
  }
  if (anomalies.length && !options.silent) {
    (options.logger || console).warn('⚠️ Anomalies détectées entre arrêts consécutifs :', anomalies);
  }
  return { stops: deduped, anomalies };
}

// ---------------------------------------------------------------------------
// Conversions d'ordre de coordonnées (explicites !)
// ---------------------------------------------------------------------------

/** GeoJSON/OSRM [lng, lat] → Leaflet [lat, lng] (validé). */
export function toLatLng(lngLat, options = {}) {
  if (!Array.isArray(lngLat) || lngLat.length < 2) throw new CoordinateOrderError('Point GeoJSON invalide', { point: lngLat });
  const lng = Number(lngLat[0]);
  const lat = Number(lngLat[1]);
  if (looksSwapped(lat, lng, options.bbox)) {
    throw new CoordinateOrderError(`Point GeoJSON [${lngLat[0]}, ${lngLat[1]}] semble être [lat, lng] au lieu de [lng, lat]`, { point: lngLat });
  }
  return [lat, lng];
}

/** Leaflet/GTFS [lat, lng] → GeoJSON [lng, lat] (validé). */
export function toLngLat(latLng, options = {}) {
  if (!Array.isArray(latLng) || latLng.length < 2) throw new CoordinateOrderError('Point [lat, lng] invalide', { point: latLng });
  const lat = Number(latLng[0]);
  const lng = Number(latLng[1]);
  if (looksSwapped(lat, lng, options.bbox)) {
    throw new CoordinateOrderError(`Point [${latLng[0]}, ${latLng[1]}] semble être [lng, lat] au lieu de [lat, lng]`, { point: latLng });
  }
  return [lng, lat];
}

/**
 * Convertit une liste de points vers [lat, lng] en vérifiant l'ordre déclaré.
 * @param {Array} points
 * @param {'lnglat'|'latlng'} declaredOrder
 * @returns {{ latlngs: Array<[number,number]>, swappedFixed: boolean }}
 */
export function normalizeLatLngs(points, declaredOrder, options = {}) {
  if (!Array.isArray(points)) throw new CoordinateOrderError('Liste de points invalide');
  const asDeclared = points.map((p) => (declaredOrder === 'lnglat' ? [Number(p[1]), Number(p[0])] : [Number(p[0]), Number(p[1])]));
  const okDeclared = asDeclared.filter(([la, ln]) => isInDakar(la, ln, options.bbox)).length;
  const okSwapped = asDeclared.filter(([la, ln]) => isInDakar(ln, la, options.bbox)).length;
  let latlngs = asDeclared;
  let swappedFixed = false;
  if (okSwapped > okDeclared) {
    if (!options.autoFixSwapped) {
      throw new CoordinateOrderError(
        `Tracé déclaré "${declaredOrder}" mais ${okSwapped}/${points.length} points ne sont valides qu'inversés → inversion lat/lng probable`
      );
    }
    latlngs = asDeclared.map(([la, ln]) => [ln, la]);
    swappedFixed = true;
  }
  const invalid = latlngs.filter(([la, ln]) => !isInDakar(la, ln, options.bbox)).length;
  if (invalid > 0 && !options.allowOutsideDakar) {
    throw new RoadSnappingError(`${invalid}/${latlngs.length} points hors de la région de Dakar`);
  }
  return { latlngs, swappedFixed };
}

// ---------------------------------------------------------------------------
// Polyline (Google Encoded Polyline Algorithm Format) – utilisé par OSRM
// ---------------------------------------------------------------------------

/**
 * Décode une polyline encodée. Renvoie des paires [lat, lng] (ordre natif du format :
 * la latitude est encodée en premier). precision 5 = OSRM `polyline`, 6 = `polyline6`.
 */
export function decodePolyline(encoded, precision = 5) {
  if (typeof encoded !== 'string') throw new RoadSnappingError('Polyline : chaîne attendue');
  const factor = Math.pow(10, precision);
  const coordinates = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  const len = encoded.length;

  const readValue = () => {
    let result = 0;
    let shift = 0;
    let byte;
    do {
      if (index >= len) throw new RoadSnappingError('Polyline tronquée ou corrompue', { index, length: len });
      byte = encoded.charCodeAt(index++) - 63;
      if (byte < 0 || byte > 63) throw new RoadSnappingError(`Polyline : caractère invalide à l'index ${index - 1}`);
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) ? ~(result >> 1) : (result >> 1);
  };

  while (index < len) {
    lat += readValue();
    lng += readValue();
    coordinates.push([lat / factor, lng / factor]);
  }
  return coordinates;
}

/** Encode des paires [lat, lng] en polyline (utile pour les tests et le cache). */
export function encodePolyline(latlngs, precision = 5) {
  const factor = Math.pow(10, precision);
  let output = '';
  let prevLat = 0;
  let prevLng = 0;
  const encodeValue = (value) => {
    let v = value < 0 ? ~(value << 1) : (value << 1);
    let s = '';
    while (v >= 0x20) {
      s += String.fromCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    s += String.fromCharCode(v + 63);
    return s;
  };
  for (const [lat, lng] of latlngs) {
    const iLat = Math.round(lat * factor);
    const iLng = Math.round(lng * factor);
    output += encodeValue(iLat - prevLat) + encodeValue(iLng - prevLng);
    prevLat = iLat;
    prevLng = iLng;
  }
  return output;
}

// ---------------------------------------------------------------------------
// Qualité du tracé (garde-fou anti "lignes droites")
// ---------------------------------------------------------------------------

/** Longueur d'une liste [lat,lng] en km. */
export function pathLengthKm(latlngs) {
  let km = 0;
  for (let i = 1; i < latlngs.length; i++) {
    km += getDistanceKm(latlngs[i - 1][0], latlngs[i - 1][1], latlngs[i][0], latlngs[i][1]);
  }
  return km;
}

/**
 * Rapport de qualité : densité de points, plus long segment, ratio de détour.
 * Un tracé routier réel a une densité élevée (> 4 pts/km) et pas de segment > 3 km.
 * Des "vecteurs directs" entre terminus ont 1 à 2 pts/km et des segments de plusieurs km.
 */
export function shapeQualityReport(latlngs, stops = null, options = {}) {
  const maxSegmentKm = options.maxSegmentKm ?? 3;
  const minPointsPerKm = options.minPointsPerKm ?? 4;
  let km = 0;
  let maxSeg = 0;
  for (let i = 1; i < latlngs.length; i++) {
    const d = getDistanceKm(latlngs[i - 1][0], latlngs[i - 1][1], latlngs[i][0], latlngs[i][1]);
    km += d;
    if (d > maxSeg) maxSeg = d;
  }
  const pointsPerKm = km > 0 ? latlngs.length / km : Infinity;
  const report = {
    points: latlngs.length,
    lengthKm: Number(km.toFixed(3)),
    maxSegmentKm: Number(maxSeg.toFixed(3)),
    pointsPerKm: Number(pointsPerKm.toFixed(1)),
    issues: []
  };
  if (latlngs.length < 2) report.issues.push('moins de 2 points');
  if (maxSeg > maxSegmentKm) report.issues.push(`segment de ${maxSeg.toFixed(2)} km > ${maxSegmentKm} km (vecteur direct ?)`);
  if (km > 2 && pointsPerKm < minPointsPerKm) report.issues.push(`densité ${pointsPerKm.toFixed(1)} pts/km < ${minPointsPerKm} (tracé non routier ?)`);

  if (Array.isArray(stops) && stops.length >= 2 && latlngs.length >= 2) {
    const first = stops[0];
    const last = stops[stops.length - 1];
    const dStart = getDistanceKm(first.lat, first.lng, latlngs[0][0], latlngs[0][1]) * 1000;
    const dEnd = getDistanceKm(last.lat, last.lng, latlngs[latlngs.length - 1][0], latlngs[latlngs.length - 1][1]) * 1000;
    let straight = 0;
    for (let i = 1; i < stops.length; i++) straight += getDistanceKm(stops[i - 1].lat, stops[i - 1].lng, stops[i].lat, stops[i].lng);
    report.terminusStartOffsetM = Math.round(dStart);
    report.terminusEndOffsetM = Math.round(dEnd);
    report.detourRatio = straight > 0 ? Number((km / straight).toFixed(3)) : null;
    const maxTerminusOffsetM = options.maxTerminusOffsetM ?? 300;
    if (dStart > maxTerminusOffsetM) report.issues.push(`départ du tracé à ${Math.round(dStart)} m du premier arrêt`);
    if (dEnd > maxTerminusOffsetM) report.issues.push(`fin du tracé à ${Math.round(dEnd)} m du dernier arrêt`);
    const maxDetour = options.maxDetourRatio ?? 2.5;
    if (report.detourRatio && report.detourRatio > maxDetour) report.issues.push(`ratio de détour ${report.detourRatio} > ${maxDetour} (boucles / demi-tours ?)`);
  }
  report.ok = report.issues.length === 0;
  return report;
}

/** Lève une erreur si le tracé ressemble à des lignes droites. */
export function assertRoadLikeShape(latlngs, stops = null, options = {}) {
  const report = shapeQualityReport(latlngs, stops, options);
  if (!report.ok) {
    throw new RoadSnappingError(`Tracé rejeté : ${report.issues.join(' ; ')}`, { report });
  }
  return report;
}

// ---------------------------------------------------------------------------
// OSRM
// ---------------------------------------------------------------------------

/** Construit l'URL OSRM : coordonnées en `lng,lat` séparées par `;`. */
export function buildOsrmRouteUrl(stops, options = {}) {
  const base = (options.baseUrl || OSRM_BASE_URL).replace(/\/+$/, '');
  const profile = options.profile || OSRM_PROFILE;
  const geometries = options.geometries || 'polyline'; // polyline (1e-5) : compact et précis à ~1 m
  const coords = stops.map((s) => `${s.lng.toFixed(6)},${s.lat.toFixed(6)}`).join(';');
  const params = new URLSearchParams({
    overview: 'full',
    geometries,
    steps: 'false',
    annotations: 'false'
  });
  if (options.continueStraight !== undefined) params.set('continue_straight', String(options.continueStraight));
  if (options.radiuses) params.set('radiuses', options.radiuses);
  return `${base}/route/v1/${profile}/${coords}?${params.toString()}`;
}

/** Découpe une liste d'arrêts en tronçons (chevauchement d'un point) pour respecter la limite OSRM. */
export function chunkStops(stops, maxPerRequest = OSRM_MAX_COORDS_PER_REQUEST) {
  if (stops.length <= maxPerRequest) return [stops];
  const chunks = [];
  let start = 0;
  while (start < stops.length - 1) {
    const end = Math.min(start + maxPerRequest, stops.length);
    chunks.push(stops.slice(start, end));
    if (end === stops.length) break;
    start = end - 1; // le dernier point devient le premier du tronçon suivant
  }
  return chunks;
}

/** Extrait les coordonnées [lat, lng] d'une réponse OSRM (polyline, polyline6 ou geojson). */
export function extractRouteLatLngs(route, geometries = 'polyline') {
  if (!route || route.geometry === undefined || route.geometry === null) {
    throw new RoadSnappingError('Réponse OSRM sans géométrie');
  }
  if (geometries === 'geojson') {
    const coords = route.geometry?.coordinates;
    if (!Array.isArray(coords)) throw new RoadSnappingError('Géométrie GeoJSON OSRM invalide');
    return coords.map((c) => toLatLng(c)); // GeoJSON = [lng, lat] → [lat, lng]
  }
  if (typeof route.geometry !== 'string') throw new RoadSnappingError('Géométrie OSRM : polyline (chaîne) attendue');
  return decodePolyline(route.geometry, geometries === 'polyline6' ? 6 : 5);
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Appelle OSRM pour une liste d'arrêts (≤ limite) avec retries.
 * @returns {{ latlngs, distance, duration, legs, waypoints, url }}
 */
export async function fetchOsrmRoute(stops, options = {}) {
  const fetchImpl = options.fetch || globalThis.fetch;
  if (typeof fetchImpl !== 'function') throw new RoadSnappingError('fetch indisponible (Node ≥ 18 requis)');
  const geometries = options.geometries || 'polyline';
  const url = buildOsrmRouteUrl(stops, { ...options, geometries });
  const retries = options.retries ?? 3;
  const timeoutMs = options.timeoutMs ?? 15000;
  const logger = options.logger || console;
  let lastError;

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      if (!options.quiet) logger.log(`📡 Requête OSRM (${stops.length} arrêts, essai ${attempt}/${retries}) : ${url.slice(0, 140)}…`);
      const signal = typeof AbortSignal !== 'undefined' && AbortSignal.timeout ? AbortSignal.timeout(timeoutMs) : undefined;
      const response = await fetchImpl(url, { headers: { 'User-Agent': 'DakarBus/2.2 road-snapping' }, signal });
      if (!response.ok) {
        const retryable = response.status === 429 || response.status >= 500;
        const err = new RoadSnappingError(`OSRM HTTP ${response.status} ${response.statusText || ''}`.trim(), { status: response.status, url });
        if (retryable && attempt < retries) { lastError = err; await sleep(500 * 2 ** (attempt - 1)); continue; }
        throw err;
      }
      const data = await response.json();
      if (data.code !== 'Ok') {
        throw new RoadSnappingError(`OSRM: ${data.code} – ${data.message || 'aucune route trouvée'}`, { code: data.code, url });
      }
      if (!Array.isArray(data.routes) || data.routes.length === 0) {
        throw new RoadSnappingError('Aucune route trouvée par OSRM', { url });
      }
      const route = data.routes[0];
      const latlngs = extractRouteLatLngs(route, geometries);
      if (latlngs.length < 2) throw new RoadSnappingError('Géométrie OSRM vide', { url });
      return {
        latlngs,
        distance: route.distance,
        duration: route.duration,
        legs: (route.legs || []).map((l) => ({ distance: l.distance, duration: l.duration })),
        waypoints: (data.waypoints || []).map((w) => ({ name: w.name || '', location: w.location, snapDistanceM: w.distance })),
        url,
        raw: options.keepRaw ? data : undefined
      };
    } catch (error) {
      if (error instanceof RoadSnappingError && !(error.details?.status >= 500 || error.details?.status === 429)) {
        if (error.details?.code) throw error; // NoRoute, InvalidQuery… → inutile de réessayer
        if (!error.details?.status) { lastError = error; }
        else throw error;
      } else {
        lastError = error;
      }
      if (attempt < retries) { await sleep(500 * 2 ** (attempt - 1)); continue; }
    }
  }
  throw new RoadSnappingError(`OSRM injoignable après ${retries} essais : ${lastError?.message || 'erreur inconnue'}`, { cause: lastError, url });
}

/**
 * Récupère la géométrie routière réelle passant par TOUS les arrêts (waypoints).
 * ⚠️ Pas de repli : en cas d'échec, l'erreur est propagée (jamais de ligne droite).
 *
 * @param {Array} stops - Arrêts {id, name, lat, lng, sequence}
 * @param {Object} options - { profile, baseUrl, fetch, geometries, strict, logger, quiet }
 * @returns {Promise<Object>} { geometry (GeoJSON LineString [lng,lat]), latlngs ([lat,lng]), polyline, distance, duration, legs, stops, quality, timestamp }
 */
export async function generateRouteGeometry(stops, options = {}) {
  const logger = options.logger || console;
  const { stops: sortedStops, anomalies } = validateAndSortStops(stops, { ...options, logger });
  const chunks = chunkStops(sortedStops, options.maxCoordsPerRequest || OSRM_MAX_COORDS_PER_REQUEST);

  let latlngs = [];
  let distance = 0;
  let duration = 0;
  const legs = [];
  const waypoints = [];
  const urls = [];
  for (let i = 0; i < chunks.length; i++) {
    const part = await fetchOsrmRoute(chunks[i], { ...options, logger });
    const partLatLngs = i === 0 ? part.latlngs : part.latlngs.slice(1); // évite le point doublon de jonction
    latlngs = latlngs.concat(partLatLngs);
    distance += part.distance;
    duration += part.duration;
    legs.push(...part.legs);
    waypoints.push(...(i === 0 ? part.waypoints : part.waypoints.slice(1)));
    urls.push(part.url);
  }

  // Contrôles qualité : le tracé doit être routier et cohérent avec les arrêts.
  const quality = shapeQualityReport(latlngs, sortedStops, options);
  const maxSnap = Math.max(0, ...waypoints.map((w) => w.snapDistanceM || 0));
  quality.maxSnapDistanceM = Math.round(maxSnap);
  if (maxSnap > (options.maxSnapDistanceM ?? 500)) {
    quality.issues.push(`un arrêt a été projeté à ${Math.round(maxSnap)} m de la route la plus proche`);
    quality.ok = false;
  }
  if (!quality.ok) {
    const msg = `Tracé OSRM incohérent : ${quality.issues.join(' ; ')}`;
    if (options.strict !== false) throw new RoadSnappingError(msg, { quality, urls });
    logger.warn('⚠️ ' + msg);
  }

  return {
    geometry: { type: 'LineString', coordinates: latlngs.map(([lat, lng]) => [lng, lat]) }, // GeoJSON = [lng, lat]
    latlngs,                                                                                     // Leaflet = [lat, lng]
    polyline: encodePolyline(latlngs, 5),
    distance,
    duration,
    legs,
    waypoints,
    stops: sortedStops,
    anomalies,
    quality,
    source: 'osrm',
    profile: options.profile || OSRM_PROFILE,
    urls,
    timestamp: new Date().toISOString()
  };
}

export default {
  generateRouteGeometry,
  validateAndSortStops,
  normalizeStop,
  getDistanceKm,
  decodePolyline,
  encodePolyline,
  toLatLng,
  toLngLat,
  normalizeLatLngs,
  shapeQualityReport,
  assertRoadLikeShape,
  buildOsrmRouteUrl,
  chunkStops,
  fetchOsrmRoute,
  isInDakar,
  looksSwapped,
  DAKAR_BBOX,
  RoadSnappingError,
  CoordinateOrderError
};
