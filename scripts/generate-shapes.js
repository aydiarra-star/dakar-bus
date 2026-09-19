#!/usr/bin/env node
/**
 * Génère les tracés routiers réels (shapes) de toutes les lignes à partir de leurs
 * arrêts intermédiaires (stop_times.txt) via OSRM, puis écrit :
 *   - data/gtfs/shapes.txt                (GTFS : shape_pt_lat / shape_pt_lon)
 *   - data/routes/geometries.json         (GeoJSON FeatureCollection : [lng, lat])
 *
 * Sources de géométrie, par ordre de priorité pour chaque shape_id :
 *   1. data/routes/manual/<shape_id>.geojson   (ex. voie ferrée TER issue d'OSM)
 *   2. "reverse_of" dans data/routes/sources.json (voie dédiée bidirectionnelle)
 *   3. data/routes/osrm-cache/<shape_id>.json  (réponse OSRM enregistrée, hors ligne)
 *   4. Appel OSRM en direct (sauf --offline) — la réponse est mise en cache.
 *
 * ⚠️ AUCUN REPLI EN LIGNE DROITE : une ligne sans tracé routier valide est
 *    simplement absente des fichiers générés (et listée dans le rapport).
 *
 * Usage :
 *   node scripts/generate-shapes.js [--offline] [--refresh] [--only SHAPE_ID] [--print-urls] [--strict]
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  generateRouteGeometry, extractRouteLatLngs, shapeQualityReport, normalizeLatLngs,
  buildOsrmRouteUrl, chunkStops, getDistanceKm, RoadSnappingError, OSRM_BASE_URL
} from '../server/roadSnapping.js';
import { loadGTFS, buildTripWaypoints, routeMode, toCSV, latLngsToShapeRows } from '../server/gtfs.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const GTFS_DIR = path.join(ROOT, 'data', 'gtfs');
const ROUTES_DIR = path.join(ROOT, 'data', 'routes');
const CACHE_DIR = path.join(ROUTES_DIR, 'osrm-cache');
const MANUAL_DIR = path.join(ROUTES_DIR, 'manual');

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const OFFLINE = flag('--offline');
const REFRESH = flag('--refresh');
const STRICT = flag('--strict');
const PRINT_URLS = flag('--print-urls');
const ONLY = opt('--only');

const MODE_COLORS = { brt: '00B140', ddd: '3B82F6', ter: '10B981', aftu: 'EC4899', tata: 'F59E0B', bus: '6B7280' };

async function exists(p) { try { await fs.access(p); return true; } catch { return false; } }
async function readJson(p) { return JSON.parse(await fs.readFile(p, 'utf8')); }

function trimOsrmResponse(result) {
  return {
    fetched_at: result.timestamp,
    osrm: OSRM_BASE_URL,
    profile: result.profile,
    geometries: 'polyline',
    code: 'Ok',
    routes: [{ distance: result.distance, duration: result.duration, legs: result.legs, geometry: result.polyline }],
    waypoints: result.waypoints
  };
}

async function main() {
  const gtfs = await loadGTFS(GTFS_DIR);
  const waypointsByShape = buildTripWaypoints(gtfs);
  const sources = (await exists(path.join(ROUTES_DIR, 'sources.json'))) ? await readJson(path.join(ROUTES_DIR, 'sources.json')) : { shapes: {} };
  const routesById = new Map(gtfs.routes.map((r) => [r.route_id, r]));

  // Shapes demandés par trips.txt (ordre stable, sans doublon)
  const wanted = [];
  for (const t of gtfs.trips) {
    if (!t.shape_id || wanted.some((w) => w.shape_id === t.shape_id)) continue;
    if (ONLY && t.shape_id !== ONLY) continue;
    wanted.push({ shape_id: t.shape_id, trip: t, route: routesById.get(t.route_id) });
  }

  const results = new Map(); // shape_id → { latlngs, meta }
  const report = [];
  const missingUrls = [];

  const finish = (shape_id, status, detail, extra = {}) => report.push({ shape_id, status, detail, ...extra });

  // Passe 1 : manuel + cache + OSRM ; passe 2 : reverse_of
  for (const w of wanted) {
    const { shape_id, route } = w;
    const src = sources.shapes?.[shape_id] || {};
    const mode = route ? routeMode(route) : 'bus';
    const wp = waypointsByShape.get(shape_id);
    const stops = wp?.stops;
    if (src.reverse_of) continue;

    try {
      const manualPath = path.join(MANUAL_DIR, `${shape_id}.geojson`);
      if (await exists(manualPath)) {
        const feature = await readJson(manualPath);
        const coords = feature.geometry?.coordinates || feature.coordinates;
        const { latlngs } = normalizeLatLngs(coords, 'lnglat'); // GeoJSON = [lng, lat] (vérifié)
        const quality = shapeQualityReport(latlngs, stops, { maxSegmentKm: 3, minPointsPerKm: 3 });
        if (!quality.ok) throw new RoadSnappingError(`tracé manuel rejeté : ${quality.issues.join(' ; ')}`);
        results.set(shape_id, { latlngs, mode, route, stops, quality, source: feature.properties?.source || 'manual', distance_m: Math.round(quality.lengthKm * 1000) });
        finish(shape_id, 'OK', `manuel (${feature.properties?.source || 'manual'}) – ${quality.lengthKm} km, ${latlngs.length} pts`);
        continue;
      }

      if (!stops || stops.length < 2) {
        finish(shape_id, 'MANQUANT', 'aucun arrêt intermédiaire dans stop_times.txt → pas de waypoints, pas de tracé (jamais de ligne droite)');
        continue;
      }

      const cachePath = path.join(CACHE_DIR, `${shape_id}.json`);
      let osrm = null;
      if (!REFRESH && (await exists(cachePath))) {
        const cached = await readJson(cachePath);
        const route0 = cached.routes?.[0];
        if (cached.code !== 'Ok' || !route0) throw new RoadSnappingError('cache OSRM invalide');
        const expectedLegs = stops.length - 1;
        if (Array.isArray(route0.legs) && route0.legs.length !== expectedLegs) {
          throw new RoadSnappingError(`cache obsolète : ${route0.legs.length} tronçons pour ${stops.length} arrêts (relancer avec --refresh)`);
        }
        const latlngs = extractRouteLatLngs(route0, cached.geometries || 'polyline');
        const quality = shapeQualityReport(latlngs, stops);
        const maxSnap = Math.max(0, ...(cached.waypoints || []).map((x) => x.distance || 0), cached.waypoints_snap_max_m || 0);
        quality.maxSnapDistanceM = Math.round(maxSnap);
        if (maxSnap > 500) { quality.issues.push(`arrêt projeté à ${Math.round(maxSnap)} m de la route`); quality.ok = false; }
        if (!quality.ok) throw new RoadSnappingError(`cache rejeté : ${quality.issues.join(' ; ')}`);
        osrm = { latlngs, quality, distance: route0.distance, duration: route0.duration, source: 'osrm', cached: true };
      } else if (!OFFLINE) {
        const result = await generateRouteGeometry(stops, { quiet: true });
        await fs.mkdir(CACHE_DIR, { recursive: true });
        await fs.writeFile(cachePath, JSON.stringify({ shape_id, route_id: route?.route_id, ...trimOsrmResponse(result) }, null, 1));
        osrm = { latlngs: result.latlngs, quality: result.quality, distance: result.distance, duration: result.duration, source: 'osrm', cached: false };
      } else {
        for (const chunk of chunkStops(stops)) missingUrls.push({ shape_id, url: buildOsrmRouteUrl(chunk) });
        finish(shape_id, 'MANQUANT', 'pas de cache OSRM et mode --offline → à générer (voir --print-urls)');
        continue;
      }
      results.set(shape_id, { latlngs: osrm.latlngs, mode, route, stops, quality: osrm.quality, source: osrm.source, distance_m: Math.round(osrm.distance) });
      finish(shape_id, 'OK', `OSRM${osrm.cached ? ' (cache)' : ''} – ${(osrm.distance / 1000).toFixed(2)} km, ${osrm.latlngs.length} pts, détour ×${osrm.quality.detourRatio}, snap max ${osrm.quality.maxSnapDistanceM ?? '?'} m`);
    } catch (error) {
      const msg = error instanceof RoadSnappingError ? error.message : `${error.name}: ${error.message}`;
      finish(shape_id, 'ERREUR', msg);
      if (stops) for (const chunk of chunkStops(stops)) missingUrls.push({ shape_id, url: buildOsrmRouteUrl(chunk) });
    }
  }

  for (const w of wanted) {
    const src = sources.shapes?.[w.shape_id];
    if (!src?.reverse_of) continue;
    const base = results.get(src.reverse_of);
    if (!base) { finish(w.shape_id, 'MANQUANT', `dépend de ${src.reverse_of} (absent)`); continue; }
    const latlngs = base.latlngs.slice().reverse();
    const stops = waypointsByShape.get(w.shape_id)?.stops;
    const quality = shapeQualityReport(latlngs, stops, { maxSegmentKm: 3, minPointsPerKm: 3 });
    if (!quality.ok) { finish(w.shape_id, 'ERREUR', `inversion rejetée : ${quality.issues.join(' ; ')}`); continue; }
    results.set(w.shape_id, { ...base, latlngs, stops, quality, source: `${base.source} (reverse_of ${src.reverse_of})` });
    finish(w.shape_id, 'OK', `inverse de ${src.reverse_of}`);
  }

  // ---------- Écriture ----------
  const shapeRows = [];
  const features = [];
  for (const [shape_id, r] of results) {
    shapeRows.push(...latLngsToShapeRows(shape_id, r.latlngs, getDistanceKm));
    const trip = wanted.find((w) => w.shape_id === shape_id)?.trip;
    features.push({
      type: 'Feature',
      properties: {
        shape_id,
        route_id: r.route?.route_id || trip?.route_id || null,
        route_short_name: r.route?.route_short_name || null,
        route_long_name: r.route?.route_long_name || null,
        mode: r.mode,
        color: `#${(r.route?.route_color || MODE_COLORS[r.mode] || '6B7280').replace('#', '')}`,
        direction_id: trip ? Number(trip.direction_id) : null,
        headsign: trip?.trip_headsign || null,
        source: r.source,
        distance_m: r.distance_m,
        stops: r.stops ? r.stops.length : null,
        quality: { detour_ratio: r.quality.detourRatio ?? null, points_per_km: r.quality.pointsPerKm, max_segment_km: r.quality.maxSegmentKm, max_snap_m: r.quality.maxSnapDistanceM ?? null }
      },
      geometry: { type: 'LineString', coordinates: r.latlngs.map(([lat, lng]) => [lng, lat]) } // GeoJSON = [lng, lat]
    });
  }
  const collection = {
    type: 'FeatureCollection',
    generated_at: new Date().toISOString(),
    coordinate_order: 'GeoJSON [lng, lat] — convertir en [lat, lng] pour Leaflet',
    attribution: '© OpenStreetMap contributors (ODbL) – tracés routiers OSRM',
    features
  };
  if (!ONLY) {
    await fs.writeFile(path.join(GTFS_DIR, 'shapes.txt'), toCSV(['shape_id', 'shape_pt_lat', 'shape_pt_lon', 'shape_pt_sequence', 'shape_dist_traveled'], shapeRows));
    await fs.writeFile(path.join(ROUTES_DIR, 'geometries.json'), JSON.stringify(collection));
  }

  // ---------- Rapport ----------
  console.log('\n=== Génération des tracés routiers ===');
  for (const r of report) {
    const icon = r.status === 'OK' ? '✅' : r.status === 'MANQUANT' ? '⚪' : '❌';
    console.log(`${icon} ${r.shape_id.padEnd(20)} ${r.status.padEnd(9)} ${r.detail}`);
  }
  const ok = report.filter((r) => r.status === 'OK').length;
  const errors = report.filter((r) => r.status === 'ERREUR').length;
  const missing = report.filter((r) => r.status === 'MANQUANT').length;
  const noShapeRoutes = gtfs.routes.filter((r) => !gtfs.trips.some((t) => t.route_id === r.route_id && t.shape_id && results.has(t.shape_id)));
  console.log(`\n${ok} tracé(s) écrit(s), ${missing} manquant(s), ${errors} erreur(s). ${shapeRows.length} points → data/gtfs/shapes.txt, ${features.length} features → data/routes/geometries.json`);
  console.log(`Lignes sans tracé (non dessinées, aucun repli en ligne droite) : ${noShapeRoutes.length}/${gtfs.routes.length}` +
    (noShapeRoutes.length ? ` → ${noShapeRoutes.slice(0, 12).map((r) => r.route_id).join(', ')}${noShapeRoutes.length > 12 ? '…' : ''}` : ''));
  console.log('Pour les dessiner : ajouter leurs arrêts réels dans stops.txt + stop_times.txt puis relancer `npm run snap-routes`.');
  if (PRINT_URLS && missingUrls.length) {
    console.log('\nURLs OSRM à récupérer manuellement (enregistrer la réponse JSON dans data/routes/osrm-cache/<shape_id>.json) :');
    for (const m of missingUrls) console.log(`- ${m.shape_id}: ${m.url}`);
  }
  if (STRICT && (errors > 0 || missing > 0)) process.exit(1);
}

main().catch((error) => { console.error('❌', error); process.exit(1); });
