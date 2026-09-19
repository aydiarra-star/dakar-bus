import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  decodePolyline,
  encodePolyline,
  toLatLng,
  toLngLat,
  normalizeLatLngs,
  normalizeStop,
  validateAndSortStops,
  buildOsrmRouteUrl,
  chunkStops,
  shapeQualityReport,
  assertRoadLikeShape,
  generateRouteGeometry,
  RoadSnappingError,
  CoordinateOrderError
} from './roadSnapping.js';

// Quelques stations réelles du BRT (source OSM) en [lat, lng]
const BRT = [
  { id: 'petersen', name: 'Petersen', lat: 14.6758222, lng: -17.4412971, sequence: 1 },
  { id: 'mosquee', name: 'Grande Mosquée', lat: 14.6825044, lng: -17.4442152, sequence: 2 },
  { id: 'nation', name: 'Place de la Nation', lat: 14.6955698, lng: -17.4500055, sequence: 3 },
  { id: 'dialdiop', name: 'Dial Diop', lat: 14.6988058, lng: -17.4529316, sequence: 4 }
];

test('decodePolyline : exemple officiel Google → [lat, lng]', () => {
  const pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  assert.deepEqual(pts, [[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
});

test('decodePolyline/encodePolyline : aller-retour sans perte (précision 5)', () => {
  const latlngs = BRT.map((s) => [s.lat, s.lng]);
  const decoded = decodePolyline(encodePolyline(latlngs));
  decoded.forEach((p, i) => {
    assert.ok(Math.abs(p[0] - latlngs[i][0]) < 1e-5, 'lat');
    assert.ok(Math.abs(p[1] - latlngs[i][1]) < 1e-5, 'lng');
  });
});

test('decodePolyline : la latitude est bien en premier (pas d\'inversion)', () => {
  const [lat, lng] = decodePolyline(encodePolyline([[14.6758, -17.4413]]))[0];
  assert.ok(lat > 14 && lat < 15, `lat=${lat} devrait être ≈14.7`);
  assert.ok(lng < -17 && lng > -18, `lng=${lng} devrait être ≈-17.4`);
});

test('decodePolyline : chaîne tronquée → erreur explicite (pas de tracé partiel silencieux)', () => {
  const full = encodePolyline([[14.6758, -17.4413], [14.6825, -17.4442]]);
  assert.throws(() => decodePolyline(full.slice(0, -1)), RoadSnappingError);
  assert.throws(() => decodePolyline(42), RoadSnappingError);
});

test('toLatLng / toLngLat : conversions explicites GeoJSON ⇄ Leaflet', () => {
  assert.deepEqual(toLatLng([-17.4413, 14.6758]), [14.6758, -17.4413]);
  assert.deepEqual(toLngLat([14.6758, -17.4413]), [-17.4413, 14.6758]);
  // Un point GeoJSON déjà en [lat, lng] est détecté comme inversé
  assert.throws(() => toLatLng([14.6758, -17.4413]), CoordinateOrderError);
  assert.throws(() => toLngLat([-17.4413, 14.6758]), CoordinateOrderError);
});

test('normalizeLatLngs : détecte et corrige une inversion systématique', () => {
  const geojson = BRT.map((s) => [s.lng, s.lat]);
  const ok = normalizeLatLngs(geojson, 'lnglat');
  assert.equal(ok.swappedFixed, false);
  assert.deepEqual(ok.latlngs[0], [BRT[0].lat, BRT[0].lng]);
  // Déclaré latlng mais en réalité lnglat
  assert.throws(() => normalizeLatLngs(geojson, 'latlng'), CoordinateOrderError);
  const fixed = normalizeLatLngs(geojson, 'latlng', { autoFixSwapped: true });
  assert.equal(fixed.swappedFixed, true);
  assert.deepEqual(fixed.latlngs[0], [BRT[0].lat, BRT[0].lng]);
});

test('normalizeStop : accepte stop_lat/stop_lon et refuse les coordonnées inversées', () => {
  const s = normalizeStop({ stop_id: 'x', stop_name: 'X', stop_lat: '14.70', stop_lon: '-17.45', stop_sequence: '3' });
  assert.deepEqual(s, { id: 'x', name: 'X', lat: 14.7, lng: -17.45, sequence: 3 });
  assert.throws(() => normalizeStop({ name: 'inv', lat: -17.45, lng: 14.7 }), CoordinateOrderError);
  const fixed = normalizeStop({ name: 'inv', lat: -17.45, lng: 14.7 }, 0, { autoFixSwapped: true, logger: { warn() {} } });
  assert.equal(fixed.lat, 14.7);
  assert.equal(fixed.lng, -17.45);
  assert.throws(() => normalizeStop({ name: 'paris', lat: 48.85, lng: 2.35 }), RoadSnappingError);
});

test('validateAndSortStops : trie par séquence, dédoublonne et signale les écarts > 10 km', () => {
  const shuffled = [BRT[2], BRT[0], BRT[3], BRT[1], { ...BRT[1], id: 'dup' }];
  const { stops, anomalies } = validateAndSortStops(shuffled, { silent: true });
  assert.deepEqual(stops.map((s) => s.id), ['petersen', 'mosquee', 'nation', 'dialdiop']);
  assert.equal(anomalies.length, 0);
  const far = [BRT[0], { id: 'diam', name: 'Diamniadio', lat: 14.7238, lng: -17.1840, sequence: 2 }];
  const res = validateAndSortStops(far, { silent: true });
  assert.equal(res.anomalies.length, 1);
  assert.equal(res.anomalies[0].severity, 'CRITIQUE');
  assert.throws(() => validateAndSortStops([BRT[0]]), RoadSnappingError);
});

test('buildOsrmRouteUrl : coordonnées en lng,lat et overview=full', () => {
  const url = buildOsrmRouteUrl(BRT.slice(0, 2), { baseUrl: 'https://osrm.test/', profile: 'driving' });
  assert.ok(url.startsWith('https://osrm.test/route/v1/driving/-17.441297,14.675822;-17.444215,14.682504?'), url);
  assert.ok(url.includes('overview=full'));
  assert.ok(url.includes('geometries=polyline'));
});

test('chunkStops : tronçons chevauchants d\'un point', () => {
  const many = Array.from({ length: 10 }, (_, i) => ({ id: String(i) }));
  const chunks = chunkStops(many, 4);
  assert.deepEqual(chunks.map((c) => c.map((s) => s.id)), [['0', '1', '2', '3'], ['3', '4', '5', '6'], ['6', '7', '8', '9']]);
  assert.equal(chunkStops(many, 20).length, 1);
});

test('shapeQualityReport : des vecteurs directs entre terminus sont rejetés', () => {
  const straight = [[14.6937, -17.4441], [14.7722, -17.4103]]; // Petersen → Guédiawaye "à vol d\'oiseau"
  const report = shapeQualityReport(straight);
  assert.equal(report.ok, false);
  assert.throws(() => assertRoadLikeShape(straight), RoadSnappingError);
  // Un tracé dense (≈ 25 m entre points) est accepté
  const dense = [];
  for (let i = 0; i <= 400; i++) dense.push([14.6758 + i * 0.00025, -17.4413 - i * 0.0001]);
  assert.equal(shapeQualityReport(dense).ok, true);
});

function osrmResponse(latlngs, distanceM, snap = 5, legCount = 1) {
  const legs = Array.from({ length: legCount }, () => ({ distance: distanceM / legCount, duration: distanceM / legCount / 6 }));
  return {
    ok: true,
    status: 200,
    async json() {
      return {
        code: 'Ok',
        routes: [{ geometry: encodePolyline(latlngs), distance: distanceM, duration: distanceM / 6, legs }],
        waypoints: latlngs.slice(0, 2).map((p) => ({ name: 'rue', location: [p[1], p[0]], distance: snap }))
      };
    }
  };
}

test('generateRouteGeometry : renvoie GeoJSON [lng,lat] + latlngs [lat,lng] cohérents', async () => {
  const road = [];
  for (let i = 0; i <= 120; i++) road.push([14.6758 + (i / 120) * (14.6988 - 14.6758), -17.4413 + (i / 120) * (-17.4529 + 17.4413) + Math.sin(i / 5) * 0.0004]);
  const calls = [];
  const fetch = async (url) => { calls.push(url); return osrmResponse(road, 3200); };
  const result = await generateRouteGeometry(BRT, { fetch, quiet: true, retries: 1 });
  assert.equal(calls.length, 1);
  assert.ok(calls[0].includes('/route/v1/driving/-17.441297,14.675822;'), 'les waypoints intermédiaires sont transmis à OSRM');
  assert.equal(result.geometry.type, 'LineString');
  assert.equal(result.geometry.coordinates.length, result.latlngs.length);
  assert.deepEqual(result.geometry.coordinates[0], [result.latlngs[0][1], result.latlngs[0][0]]);
  assert.ok(result.latlngs[0][0] > 14 && result.latlngs[0][1] < -17);
  assert.equal(result.source, 'osrm');
  assert.equal(result.quality.ok, true);
  assert.equal(result.stops.length, 4);
});

test('generateRouteGeometry : échec OSRM → erreur, JAMAIS de ligne droite', async () => {
  const fetch = async () => ({ ok: false, status: 503, statusText: 'Service Unavailable', async json() { return {}; } });
  await assert.rejects(generateRouteGeometry(BRT, { fetch, quiet: true, retries: 2 }), RoadSnappingError);
  const noRoute = async () => ({ ok: true, status: 200, async json() { return { code: 'NoRoute', message: 'Impossible' }; } });
  await assert.rejects(generateRouteGeometry(BRT, { fetch: noRoute, quiet: true, retries: 1 }), /NoRoute/);
});

test('generateRouteGeometry : un tracé OSRM qui ne relie pas les arrêts est rejeté', async () => {
  const elsewhere = [];
  for (let i = 0; i <= 120; i++) elsewhere.push([14.75 + i * 0.0002, -17.40 - i * 0.0001]); // loin de Petersen
  const fetch = async () => osrmResponse(elsewhere, 3000);
  await assert.rejects(generateRouteGeometry(BRT, { fetch, quiet: true, retries: 1 }), /Tracé OSRM incohérent/);
});

test('generateRouteGeometry : découpe en tronçons et recolle sans point doublon', async () => {
  const stops = Array.from({ length: 7 }, (_, i) => ({ id: String(i), name: `S${i}`, lat: 14.68 + i * 0.004, lng: -17.44 - i * 0.002, sequence: i }));
  let n = 0;
  const fetch = async (url) => {
    n++;
    const coords = url.split('/route/v1/driving/')[1].split('?')[0].split(';').map((c) => c.split(',').map(Number));
    const pts = [];
    for (let k = 0; k < coords.length - 1; k++) {
      for (let j = 0; j < 40; j++) {
        const t = j / 40;
        pts.push([coords[k][1] + t * (coords[k + 1][1] - coords[k][1]) + Math.sin(j) * 0.0002, coords[k][0] + t * (coords[k + 1][0] - coords[k][0])]);
      }
    }
    pts.push([coords.at(-1)[1], coords.at(-1)[0]]);
    return osrmResponse(pts, 1000 * (coords.length - 1), 5, coords.length - 1);
  };
  const result = await generateRouteGeometry(stops, { fetch, quiet: true, retries: 1, maxCoordsPerRequest: 3 });
  assert.equal(n, 3);
  assert.equal(result.legs.length, 6);
  for (let i = 1; i < result.latlngs.length; i++) {
    assert.notDeepEqual(result.latlngs[i], result.latlngs[i - 1], 'pas de point doublon à la jonction');
  }
});
