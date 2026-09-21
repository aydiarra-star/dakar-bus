'use strict';
// Pure validation: never generates, snaps, reorders or mutates source data.
const NETWORKS = new Set(['TER', 'BRT', 'DDD', 'AFTU', 'TATA']);
const normalizeName = value => String(value || '').normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
const issue = (code, id, detail, severity = 'ERROR') => ({ severity, code, id, detail });
const present = value => typeof value === 'string' && value.trim().length > 0;
const validPoint = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite)
  && Math.abs(p[0]) <= 90 && Math.abs(p[1]) <= 180;

function validateDuplicateStops(stops) {
  const out = [], ids = new Set(), names = new Map(), coords = new Map();
  for (const s of stops) {
    if (ids.has(s.id)) out.push(issue('DUPLICATE_STOP_ID', s.id, 'Identifiant répété'));
    ids.add(s.id);
    const name = normalizeName(s.name);
    if (name) {
      const key = `${s.network}:${name}`;
      if (names.has(key)) out.push(issue('DUPLICATE_STOP_NAME', s.id, names.get(key)));
      names.set(key, s.id);
    }
    if (validPoint([s.latitude, s.longitude])) {
      const key = `${s.network}:${s.latitude},${s.longitude}`;
      if (coords.has(key)) out.push(issue('DUPLICATE_STOP_COORDINATES', s.id, coords.get(key)));
      coords.set(key, s.id);
    }
  }
  return out;
}
function validateStopCoordinates(stops) {
  return stops.flatMap(s => validPoint([s.latitude, s.longitude]) ? [] :
    [issue('STOP_COORDINATES_MISSING_OR_INVALID', s.id, 'Coordonnées numériques finies requises ; null ne signifie pas zéro')]);
}
function distanceToSegmentMeters(point, a, b) {
  const scale = Math.PI * 6371000 / 180, lonScale = scale * Math.cos(point[0] * Math.PI / 180);
  const xy = q => [(q[1] - point[1]) * lonScale, (q[0] - point[0]) * scale];
  const [ax, ay] = xy(a), [bx, by] = xy(b), dx = bx - ax, dy = by - ay;
  const t = dx * dx + dy * dy === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy)));
  return Math.hypot(ax + t * dx, ay + t * dy);
}
function distanceToRouteMeters(point, geometry) {
  if (!validPoint(point) || !Array.isArray(geometry) || geometry.length < 2 || !geometry.every(validPoint)) return null;
  return Math.min(...geometry.slice(1).map((p, i) => distanceToSegmentMeters(point, geometry[i], p)));
}
function validateRouteGeometry(route, stops, threshold = 100) {
  const out = [], geometry = route.geometry;
  if (!Number.isFinite(threshold) || threshold <= 0) return [issue('INVALID_DISTANCE_THRESHOLD', route.id, String(threshold))];
  if (route.geometryStatus !== 'VERIFIED' || !present(route.geometrySource)) {
    out.push(issue('ROUTE_GEOMETRY_UNVERIFIED', route.id, 'Distance au corridor réel inconnue. Un tracé interne ne prouve pas sa propre exactitude.'));
  }
  if (!Array.isArray(geometry) || geometry.length < 2 || !geometry.every(validPoint)) {
    return [...out, issue('ROUTE_GEOMETRY_MISSING_OR_INVALID', route.id, 'Aucun tracé exploitable')];
  }
  // Diagnostic only: vertices matching stops may be legitimate in a sourced GTFS,
  // but cannot establish geographic accuracy without independent provenance.
  if (stops.length && stops.every(s => geometry.some(p => p[0] === s.latitude && p[1] === s.longitude))) {
    out.push(issue('ALL_STOPS_ARE_GEOMETRY_VERTICES', route.id, 'Contrôle circulaire possible : tous les arrêts figurent dans le tracé.', 'WARNING'));
  }
  for (const s of stops) {
    const distance = distanceToRouteMeters([s.latitude, s.longitude], geometry);
    if (distance !== null && distance > threshold) out.push(issue(`${route.network}_STOP_OFF_ROUTE`, s.id,
      `${Math.round(distance)} m > ${threshold} m (géométrie ${route.geometryStatus || 'UNKNOWN'})`, 'WARNING'));
  }
  return out;
}
function validateNetworkIsolation(stops, routes) {
  const out = [], byId = new Map(stops.map(s => [s.id, s]));
  for (const s of stops) if (!NETWORKS.has(s.network)) out.push(issue('STOP_NETWORK_INVALID', s.id, 'network explicite requis'));
  for (const r of routes) {
    if (!NETWORKS.has(r.network)) out.push(issue('ROUTE_NETWORK_INVALID', r.id, 'network explicite requis'));
    for (const id of r.stopIds || []) {
      const s = byId.get(id);
      if (!s) out.push(issue('UNKNOWN_STOP_REFERENCE', r.id, id));
      else if (s.network !== r.network && (['TER', 'BRT'].includes(s.network) || ['TER', 'BRT'].includes(r.network))) {
        out.push(issue('NETWORK_ISOLATION_VIOLATION', r.id, `${id}: ${s.network} ≠ ${r.network}`));
      }
    }
  }
  return out;
}
function validateNetworkData(network, stops, route, policy) {
  const out = [...validateDuplicateStops(stops), ...validateStopCoordinates(stops), ...validateNetworkIsolation(stops, [route])];
  if (stops.length !== policy.expectedCount) out.push(issue('STOP_COUNT_MISMATCH', network, `${stops.length} / ${policy.expectedCount}`));
  if (route.network !== network) out.push(issue('ROUTE_NETWORK_MISMATCH', route.id, network));
  for (const s of stops) {
    if (!present(s.id)) out.push(issue('STOP_ID_MISSING', network, 'Identifiant stable requis'));
    if (!present(s.name)) out.push(issue('STOP_NAME_MISSING', s.id, 'Nom requis'));
    if (s.network !== network) out.push(issue('STOP_NETWORK_MISMATCH', s.id, network));
    if (!present(s.source)) out.push(issue('STOP_SOURCE_MISSING', s.id, 'Provenance vérifiable requise'));
    if (s.dataStatus !== 'VERIFIED') out.push(issue('STOP_DATA_UNVERIFIED', s.id, s.dataStatus || 'UNKNOWN'));
    if (!['SCHEDULED', 'REAL_TIME', 'UNKNOWN'].includes(s.status)) out.push(issue('STOP_STATUS_INVALID', s.id, 'SCHEDULED / REAL_TIME / UNKNOWN requis'));
    if (s.status === 'REAL_TIME' && (!present(s.realtimeSource) || !Number.isFinite(Date.parse(s.observedAt)))) {
      out.push(issue('REALTIME_WITHOUT_EVIDENCE', s.id, 'Source et horodatage requis'));
    }
    if (!Array.isArray(s.directions) || s.directions.length !== policy.directions.length || new Set(s.directions).size !== policy.directions.length ||
      !policy.directions.every(d => s.directions.includes(d))) out.push(issue('STOP_DIRECTIONS_INVALID', s.id, 'Deux directions explicites, une seule gare physique'));
  }
  const orders = stops.map(s => s.ordre_sur_ligne);
  if (orders.some(n => !Number.isInteger(n) || n < 1 || n > stops.length) || new Set(orders).size !== stops.length) {
    out.push(issue('STOP_ORDER_INVALID', network, 'Ordre explicite, entier et contigu requis'));
  }
  const expected = [...stops].sort((a,b) => a.ordre_sur_ligne - b.ordre_sur_ligne).map(s => s.id);
  if (JSON.stringify(route.stopIds) !== JSON.stringify(expected)) out.push(issue('ROUTE_STOP_ORDER_INVALID', route.id, 'Séquence distincte de ordre_sur_ligne'));
  if (JSON.stringify(route.reverseStopIds) !== JSON.stringify([...expected].reverse())) out.push(issue('REVERSE_STOP_ORDER_INVALID', route.id, 'Retour distinct de l’ordre inverse'));
  return [...out, ...validateRouteGeometry(route, stops, policy.maxStopDistanceMeters)];
}
const validateTerData = (stops, route, policy) => validateNetworkData('TER', stops, route, policy);
const validateBrtData = (stops, route, policy) => validateNetworkData('BRT', stops, route, policy);
// Fail closed: an off-route warning also blocks release. Unknown data may remain
// stored, but never satisfies the geographic acceptance criteria.
const blocksRelease = issues => issues.some(i => i.severity === 'ERROR' || i.code.endsWith('_STOP_OFF_ROUTE'));
module.exports = { normalizeName, validPoint, validateDuplicateStops, validateStopCoordinates,
  distanceToRouteMeters, validateRouteGeometry, validateNetworkIsolation, validateTerData, validateBrtData, blocksRelease };
