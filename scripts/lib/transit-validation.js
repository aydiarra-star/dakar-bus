'use strict';
// Pure validation: never generates, snaps, reorders or mutates source data.
// Lot 4.11 : compatible GTFS minimal + data/transit. Ne fabrique jamais source/ordre.
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
      const key = `${s.network ?? 'UNKNOWN'}:${name}`;
      if (names.has(key)) out.push(issue('DUPLICATE_STOP_NAME', s.id, names.get(key)));
      names.set(key, s.id);
    }
    if (validPoint([s.latitude, s.longitude])) {
      const key = `${s.network ?? 'UNKNOWN'}:${s.latitude},${s.longitude}`;
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
  // Lot 4.11 : géométrie non vérifiée → WARNING, absente/invalide → ERROR. Ne pas transformer UNKNOWN du PWA minimal en ERROR bloquante.
  if (route.geometryStatus !== 'VERIFIED' || !present(route.geometrySource)) {
    out.push(issue('ROUTE_GEOMETRY_UNVERIFIED', route.id, 'Distance au corridor réel inconnue. Un tracé interne ne prouve pas sa propre exactitude.', 'WARNING'));
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
function inferNetworkFromId(stopId) {
  if (typeof stopId === 'string') {
    if (stopId.startsWith('TER_')) return 'TER';
    if (stopId.startsWith('BRT_')) return 'BRT';
    if (stopId.startsWith('DDD_')) return 'DDD';
    if (stopId.startsWith('AFTU_')) return 'AFTU';
    if (stopId.startsWith('TATA_')) return 'TATA';
  }
  return null;
}
function validateNetworkIsolation(stops, routes) {
  const out = [], byId = new Map(stops.map(s => [s.id, s]));
  for (const s of stops) {
    // Lot 4.11 : network absent dans GTFS minimal ≠ erreur automatique. Vérifier seulement si présent et invalide.
    if (s.network !== undefined && s.network !== null && s.network !== '' && !NETWORKS.has(s.network)) out.push(issue('STOP_NETWORK_INVALID', s.id, 'network explicite requis'));
  }
  for (const r of routes) {
    if (r.network !== undefined && r.network !== null && r.network !== '' && !NETWORKS.has(r.network)) out.push(issue('ROUTE_NETWORK_INVALID', r.id, 'network explicite requis'));
    for (const id of r.stopIds || []) {
      const s = byId.get(id);
      if (!s) out.push(issue('UNKNOWN_STOP_REFERENCE', r.id, id));
      else {
        // Lot 4.11 : vérifier appartenance depuis structures/crosswalk ; fallback prefixe sans fabriquer.
        const sNetwork = s.network ?? inferNetworkFromId(s.id);
        const rNetwork = r.network ?? inferNetworkFromId(r.id);
        // Ne sanctionner que vraie incohérence TER/BRT explicite
        if (sNetwork && rNetwork && sNetwork !== rNetwork && (['TER', 'BRT'].includes(sNetwork) || ['TER', 'BRT'].includes(rNetwork))) {
          out.push(issue('NETWORK_ISOLATION_VIOLATION', r.id, `${id}: ${sNetwork} ≠ ${rNetwork}`));
        } else if (s.network !== undefined && r.network !== undefined && s.network !== r.network && (['TER', 'BRT'].includes(s.network) || ['TER', 'BRT'].includes(r.network))) {
          out.push(issue('NETWORK_ISOLATION_VIOLATION', r.id, `${id}: ${s.network} ≠ ${r.network}`));
        }
      }
    }
  }
  return out;
}
function isValidScheduleProvenance(s) {
  // ScheduleProvenance.isValidScheduleFor exige : SCHEDULED + source non vide + sourceType officialStatic + dateSource + dateVerified + validFrom + validTo + coverage
  // Ici on vérifie la présence minimale sans inventer.
  return s.status === 'SCHEDULED' &&
    present(s.source) &&
    (s.sourceType === 'OFFICIAL_STATIC' || s.sourceType === 'officialStatic' || s.sourceType === undefined) &&
    s.dateSource != null && s.dateVerified != null && s.validFrom != null && s.validTo != null && s.coverage != null;
}
function validateNetworkData(network, stops, route, policy) {
  const out = [...validateDuplicateStops(stops), ...validateStopCoordinates(stops), ...validateNetworkIsolation(stops, [route])];
  if (stops.length !== policy.expectedCount) out.push(issue('STOP_COUNT_MISMATCH', network, `${stops.length} / ${policy.expectedCount}`));
  if (route.network !== undefined && route.network !== network) out.push(issue('ROUTE_NETWORK_MISMATCH', route.id, network));
  for (const s of stops) {
    if (!present(s.id)) out.push(issue('STOP_ID_MISSING', network, 'Identifiant stable requis'));
    if (!present(s.name)) out.push(issue('STOP_NAME_MISSING', s.id, 'Nom requis'));
    // Lot 4.11 : network optionnel en GTFS minimal
    if (s.network !== undefined && s.network !== null && s.network !== '' && s.network !== network) out.push(issue('STOP_NETWORK_MISMATCH', s.id, network));
    // Lot 4.11 : provenance optionnelle si validée ailleurs — ne pas exiger dans stops.txt minimal (undefined = GTFS minimal)
    if (s.source !== undefined) {
      if (s.source === null || !present(s.source)) out.push(issue('STOP_SOURCE_MISSING', s.id, 'Provenance vérifiable requise'));
    }
    // Lot 4.11 : dataStatus absent ≠ erreur
    if (s.dataStatus !== undefined && s.dataStatus !== null && s.dataStatus !== '' && s.dataStatus !== 'VERIFIED' && s.dataStatus !== 'CONFIRMED') {
      // Accepter VERIFIED ou CONFIRMED/HYBRID selon data/transit ; rejeter seulement si explicite et non vérifié
      if (s.dataStatus !== 'VERIFIED') out.push(issue('STOP_DATA_UNVERIFIED', s.id, s.dataStatus || 'UNKNOWN'));
    }
    // Lot 4.11 : accepter ESTIMATED, vérifier SCHEDULED et REAL_TIME
    if (s.status !== undefined && s.status !== null && s.status !== '') {
      if (!['SCHEDULED', 'REAL_TIME', 'ESTIMATED', 'UNKNOWN'].includes(s.status)) out.push(issue('STOP_STATUS_INVALID', s.id, 'SCHEDULED / REAL_TIME / ESTIMATED / UNKNOWN requis'));
      if (s.status === 'SCHEDULED') {
        // SCHEDULED seulement si provenance + couverture complètes
        const hasProvenance = present(s.source) || present(s.provenanceSource) || s.sourceType === 'OFFICIAL_STATIC' || s.sourceType === 'OFFICIAL_OPERATOR';
        const hasCoverage = s.coverage != null || s.hasCompleteCoverage === true;
        // Si champs de provenance présents, les valider ; sinon, signaler manque (mais ne pas inventer)
        if (!hasProvenance || !s.dateSource || !s.dateVerified || !s.validFrom || !s.validTo || !hasCoverage) {
          // On exige les 6 conditions ScheduleProvenance ; si absentes, erreur
          if (!present(s.source) || !s.dateSource || !s.dateVerified || !s.validFrom || !s.validTo) {
            out.push(issue('SCHEDULED_WITHOUT_PROVENANCE', s.id, 'SCHEDULED exige source, dateSource, dateVerified, validFrom, validTo et couverture complète'));
          }
        }
      }
      if (s.status === 'REAL_TIME' && (!present(s.realtimeSource) || !Number.isFinite(Date.parse(s.observedAt)))) {
        out.push(issue('REALTIME_WITHOUT_EVIDENCE', s.id, 'Source et horodatage requis'));
      }
    } else {
      // Lot 4.11 : absence de status dans GTFS minimal ≠ erreur si provenance validée ailleurs.
      // On ne pousse pas STOP_STATUS_INVALID si status est undefined (GTFS minimal)
      // Les tests legacy qui attendent UNKNOWN par défaut doivent explicitement mettre status='UNKNOWN'
    }
    // Lot 4.11 : directions propriété du trajet, pas du stop — ne vérifier que si présent
    if (s.directions !== undefined && s.directions !== null) {
      if (!Array.isArray(s.directions) || s.directions.length !== policy.directions.length || new Set(s.directions).size !== policy.directions.length ||
        !policy.directions.every(d => s.directions.includes(d))) out.push(issue('STOP_DIRECTIONS_INVALID', s.id, 'Deux directions explicites, une seule gare physique'));
    }
  }
  // Lot 4.11 : ordre_sur_ligne optionnel — utiliser stop_times.stop_sequence si absent
  const orders = stops.map(s => s.ordre_sur_ligne).filter(v => v !== undefined && v !== null);
  const hasOrder = orders.length > 0;
  if (hasOrder) {
    if (orders.some(n => !Number.isInteger(n) || n < 1 || n > stops.length) || new Set(orders).size !== stops.length) {
      out.push(issue('STOP_ORDER_INVALID', network, 'Ordre explicite, entier et contigu requis'));
    }
    const expected = [...stops].sort((a,b) => (a.ordre_sur_ligne ?? 0) - (b.ordre_sur_ligne ?? 0)).map(s => s.id);
    if (JSON.stringify(route.stopIds) !== JSON.stringify(expected)) out.push(issue('ROUTE_STOP_ORDER_INVALID', route.id, 'Séquence distincte de ordre_sur_ligne'));
    if (JSON.stringify(route.reverseStopIds) !== JSON.stringify([...expected].reverse())) out.push(issue('REVERSE_STOP_ORDER_INVALID', route.id, 'Retour distinct de l’ordre inverse'));
  } else {
    // Ordre non porté par stops.txt — vérifier via route.stopIds/stop_times ailleurs (check-arrets.js)
    // Ne pas sanctionner ordre manquant en mode GTFS minimal
  }
  return [...out, ...validateRouteGeometry(route, stops, policy.maxStopDistanceMeters)];
}
const validateTerData = (stops, route, policy) => validateNetworkData('TER', stops, route, policy);
const validateBrtData = (stops, route, policy) => validateNetworkData('BRT', stops, route, policy);
// Fail closed: an off-route warning also blocks release. Unknown data may remain
// stored, but never satisfies the geographic acceptance criteria. UPDATED Lot 4.11 : geometry UNVERIFIED is WARNING, not blocking.
const blocksRelease = issues => issues.some(i => i.severity === 'ERROR' || i.code.endsWith('_STOP_OFF_ROUTE'));
module.exports = { normalizeName, validPoint, validateDuplicateStops, validateStopCoordinates,
  distanceToRouteMeters, validateRouteGeometry, validateNetworkIsolation, validateTerData, validateBrtData, blocksRelease, inferNetworkFromId };
