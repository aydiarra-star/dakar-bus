/**
 * Utilitaires GTFS : parsing CSV (RFC 4180), chargement des fichiers statiques,
 * et construction des listes d'arrêts (waypoints) par trajet.
 *
 * Convention : GTFS stocke stop_lat / stop_lon séparément ; les points de tracé
 * (shapes.txt) sont en shape_pt_lat / shape_pt_lon → ordre "latitude d'abord".
 */
import fs from 'node:fs/promises';
import path from 'node:path';

/** Parse un CSV (gère guillemets, virgules et retours ligne dans les champs, BOM, CRLF). */
export function parseCSV(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  const src = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') { field += '"'; i++; } else { inQuotes = false; }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field); field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && src[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some((v) => v !== '')) rows.push(row);
      row = [];
    } else {
      field += c;
    }
  }
  if (field !== '' || row.length) { row.push(field); if (row.some((v) => v !== '')) rows.push(row); }
  if (rows.length === 0) return [];
  const headers = rows[0].map((h) => h.trim());
  return rows.slice(1).map((r) => {
    const obj = {};
    headers.forEach((h, idx) => { obj[h] = (r[idx] ?? '').trim(); });
    return obj;
  });
}

/** Sérialise des objets en CSV (RFC 4180, CRLF, guillemets si nécessaire). */
export function toCSV(headers, records) {
  const esc = (v) => {
    const s = v === undefined || v === null ? '' : String(v);
    return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [headers.join(',')];
  for (const rec of records) lines.push(headers.map((h) => esc(Array.isArray(rec) ? rec[headers.indexOf(h)] : rec[h])).join(','));
  return lines.join('\r\n') + '\r\n';
}

/** Charge les fichiers GTFS présents dans un dossier. */
export async function loadGTFS(dir, files = ['agency', 'routes', 'trips', 'stops', 'stop_times', 'shapes', 'calendar']) {
  const gtfs = {};
  for (const name of files) {
    try {
      const text = await fs.readFile(path.join(dir, `${name}.txt`), 'utf8');
      gtfs[name] = parseCSV(text);
    } catch (error) {
      if (error.code === 'ENOENT') gtfs[name] = []; else throw error;
    }
  }
  return gtfs;
}

/** Déduit le mode (brt, ter, ddd, aftu, tata) d'une ligne à partir de son id / agence. */
export function routeMode(route) {
  const id = String(route.route_id || '').toUpperCase();
  const agency = String(route.agency_id || '').toUpperCase();
  if (id.startsWith('BRT') || agency === 'BRT') return 'brt';
  if (id.startsWith('TER') || agency === 'TER') return 'ter';
  if (id.startsWith('DDD') || agency === 'DDD') return 'ddd';
  if (id.startsWith('TATA')) return 'tata';
  if (id.startsWith('AFTU') || agency === 'AFTU') return 'aftu';
  return 'bus';
}

/**
 * Construit, pour chaque trajet ayant des horaires, la liste ordonnée de ses arrêts
 * (waypoints réels pour OSRM). Retourne une Map shape_id → { trip, route, stops }.
 * Un trajet sans stop_times n'a PAS de waypoints → aucune géométrie ne sera générée
 * (et surtout pas une ligne droite terminus → terminus).
 */
export function buildTripWaypoints(gtfs) {
  const stopsById = new Map(gtfs.stops.map((s) => [s.stop_id, s]));
  const routesById = new Map(gtfs.routes.map((r) => [r.route_id, r]));
  const byTrip = new Map();
  for (const st of gtfs.stop_times) {
    if (!byTrip.has(st.trip_id)) byTrip.set(st.trip_id, []);
    byTrip.get(st.trip_id).push(st);
  }
  const result = new Map();
  for (const trip of gtfs.trips) {
    const shapeId = trip.shape_id;
    if (!shapeId || result.has(shapeId)) continue;
    const times = byTrip.get(trip.trip_id);
    if (!times || times.length < 2) continue;
    const stops = times
      .slice()
      .sort((a, b) => Number(a.stop_sequence) - Number(b.stop_sequence))
      .map((st) => {
        const s = stopsById.get(st.stop_id);
        if (!s) throw new Error(`stop_times: arrêt inconnu "${st.stop_id}" (trajet ${trip.trip_id})`);
        return { id: s.stop_id, name: s.stop_name, lat: Number(s.stop_lat), lng: Number(s.stop_lon), sequence: Number(st.stop_sequence) };
      });
    result.set(shapeId, { trip, route: routesById.get(trip.route_id), stops });
  }
  return result;
}

/** Regroupe shapes.txt par shape_id → tableau de [lat, lng] trié par séquence. */
export function shapesFromGtfs(shapeRows) {
  const byId = new Map();
  for (const row of shapeRows) {
    if (!byId.has(row.shape_id)) byId.set(row.shape_id, []);
    byId.get(row.shape_id).push({ seq: Number(row.shape_pt_sequence), lat: Number(row.shape_pt_lat), lng: Number(row.shape_pt_lon) });
  }
  const out = new Map();
  for (const [id, pts] of byId) {
    pts.sort((a, b) => a.seq - b.seq);
    out.set(id, pts.map((p) => [p.lat, p.lng]));
  }
  return out;
}

/** Convertit une liste [lat,lng] en lignes shapes.txt (avec distance cumulée en km). */
export function latLngsToShapeRows(shapeId, latlngs, getDistanceKm) {
  const rows = [];
  let dist = 0;
  for (let i = 0; i < latlngs.length; i++) {
    if (i > 0) dist += getDistanceKm(latlngs[i - 1][0], latlngs[i - 1][1], latlngs[i][0], latlngs[i][1]);
    rows.push({
      shape_id: shapeId,
      shape_pt_lat: latlngs[i][0].toFixed(6),
      shape_pt_lon: latlngs[i][1].toFixed(6),
      shape_pt_sequence: i + 1,
      shape_dist_traveled: dist.toFixed(3)
    });
  }
  return rows;
}
