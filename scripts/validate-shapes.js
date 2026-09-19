#!/usr/bin/env node
/**
 * Valide les tracés générés (data/routes/geometries.json + data/gtfs/shapes.txt) :
 *  - ordre des coordonnées (GeoJSON [lng, lat] / GTFS lat,lon) et points dans Dakar ;
 *  - aucun tracé "en ligne droite" (densité de points, longueur max de segment) ;
 *  - le tracé démarre/termine aux terminus et passe à ≤ 150 m de CHAQUE arrêt intermédiaire ;
 *  - cohérence GTFS : les trajets avec horaires ont un tracé, shapes.txt ⇔ geometries.json.
 * Code de sortie 1 en cas d'anomalie.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeLatLngs, shapeQualityReport, getDistanceKm, isInDakar } from '../server/roadSnapping.js';
import { loadGTFS, buildTripWaypoints, shapesFromGtfs } from '../server/gtfs.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MAX_STOP_DISTANCE_M = Number(process.env.MAX_STOP_DISTANCE_M || 150);

/** Distance (m) d'un point à une polyligne [lat,lng] (projection équirectangulaire locale). */
function distanceToPolylineM(lat, lng, latlngs) {
  const kx = Math.cos((lat * Math.PI) / 180) * 111320;
  const ky = 110540;
  const px = lng * kx, py = lat * ky;
  let best = Infinity;
  for (let i = 1; i < latlngs.length; i++) {
    const ax = latlngs[i - 1][1] * kx, ay = latlngs[i - 1][0] * ky;
    const bx = latlngs[i][1] * kx, by = latlngs[i][0] * ky;
    const dx = bx - ax, dy = by - ay;
    const len2 = dx * dx + dy * dy;
    let t = len2 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0;
    t = Math.max(0, Math.min(1, t));
    const cx = ax + t * dx, cy = ay + t * dy;
    const d = Math.hypot(px - cx, py - cy);
    if (d < best) best = d;
  }
  return best;
}

async function main() {
  const problems = [];
  const warn = (s) => problems.push(s);
  const gtfs = await loadGTFS(path.join(ROOT, 'data', 'gtfs'));
  const waypoints = buildTripWaypoints(gtfs);
  const collection = JSON.parse(await fs.readFile(path.join(ROOT, 'data', 'routes', 'geometries.json'), 'utf8'));
  const gtfsShapes = shapesFromGtfs(gtfs.shapes);
  const featuresById = new Map();

  for (const f of collection.features) {
    const id = f.properties.shape_id;
    featuresById.set(id, f);
    if (f.geometry?.type !== 'LineString') { warn(`${id}: géométrie ${f.geometry?.type} (LineString attendu)`); continue; }
    let latlngs;
    try {
      ({ latlngs } = normalizeLatLngs(f.geometry.coordinates, 'lnglat')); // lève si [lat,lng]
    } catch (e) { warn(`${id}: ${e.message}`); continue; }
    const stops = waypoints.get(id)?.stops;
    const q = shapeQualityReport(latlngs, stops, { maxSegmentKm: 3, minPointsPerKm: 3 });
    if (!q.ok) warn(`${id}: ${q.issues.join(' ; ')}`);
    if (stops) {
      const far = [];
      for (const s of stops) {
        const d = distanceToPolylineM(s.lat, s.lng, latlngs);
        if (d > MAX_STOP_DISTANCE_M) far.push(`${s.name} (${Math.round(d)} m)`);
      }
      if (far.length) warn(`${id}: ${far.length} arrêt(s) à plus de ${MAX_STOP_DISTANCE_M} m du tracé → ${far.slice(0, 5).join(', ')}`);
    }
    const g = gtfsShapes.get(id);
    if (!g) warn(`${id}: absent de shapes.txt`);
    else {
      if (g.length !== latlngs.length) warn(`${id}: ${g.length} pts dans shapes.txt vs ${latlngs.length} dans geometries.json`);
      const bad = g.filter(([la, ln]) => !isInDakar(la, ln)).length;
      if (bad) warn(`${id}: ${bad} points de shapes.txt hors Dakar (lat/lon inversés ?)`);
      const dStart = getDistanceKm(g[0][0], g[0][1], latlngs[0][0], latlngs[0][1]) * 1000;
      if (dStart > 5) warn(`${id}: shapes.txt et geometries.json ne commencent pas au même point (${Math.round(dStart)} m)`);
    }
    console.log(`✅ ${id.padEnd(20)} ${String(latlngs.length).padStart(4)} pts  ${q.lengthKm.toFixed(2).padStart(6)} km  ${q.pointsPerKm} pts/km  seg max ${q.maxSegmentKm} km` +
      (stops ? `  ${stops.length} arrêts, détour ×${q.detourRatio}, terminus ${q.terminusStartOffsetM}/${q.terminusEndOffsetM} m` : ''));
  }
  for (const id of gtfsShapes.keys()) if (!featuresById.has(id)) warn(`${id}: présent dans shapes.txt mais pas dans geometries.json`);
  for (const [id, wp] of waypoints) if (!featuresById.has(id)) warn(`${id}: le trajet ${wp.trip.trip_id} a des horaires (${wp.stops.length} arrêts) mais aucun tracé généré`);

  const noShape = gtfs.routes.filter((r) => !gtfs.trips.some((t) => t.route_id === r.route_id && featuresById.has(t.shape_id)));
  console.log(`\n${featuresById.size} tracés validés. ${noShape.length} ligne(s) sans tracé (non dessinées) : ${noShape.map((r) => r.route_id).join(', ')}`);
  if (problems.length) {
    console.error(`\n❌ ${problems.length} anomalie(s) :`);
    for (const p of problems) console.error(' - ' + p);
    process.exit(1);
  }
  console.log('✅ Aucune anomalie : tous les tracés suivent la voirie et passent par leurs arrêts.');
}

main().catch((e) => { console.error('❌', e); process.exit(1); });
