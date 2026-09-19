// Simulation v5 : reprend la simulation v4 (VRAI flutter_service_worker.js dans
// un VM Node) et ajoute les contrôles spécifiques du correctif v5 :
//
//   * filtre A.eI : rectangle d'exclusion Hann/Dalifort retiré ;
//   * lignes de démo $.J0 : parsées depuis le VRAI main.dart.js (constantes
//     B.* + littéraux new A.aE), paires reconstruites EXACTEMENT comme le fait
//     A.aS2, puis résolues via le fetch handler (TER 13 gares, B1 direct 12,
//     DDD/TATA = JSON) ;
//   * séparation stricte par mode : paires TER/BRT = secours consécutif
//     (EXACTEMENT 2 points = gares consécutives exactes, provenance
//     *-secours), paires bus = osrm-driving ; formes source_kind vérifiées ;
//   * chemin legacy cross-origin : résolu depuis le fichier statique
//     same-origin même avec cache vide + bundle indisponible ;
//   * longueurs TER (~35 km) et BRT (modèle 12 stations).
//
// Par défaut le routeur public OSRM est simulé HORS SERVICE (429) : si un seul
// itinéraire en dépendait encore, le test échouerait.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');

const swSource = read('flutter_service_worker.js');
const mainJs = read('main.dart.js');
const indexHtml = read('index.html');
const bundle = JSON.parse(read('assets/assets/data/osrm_geometries.json'));
const pairs = JSON.parse(read('assets/assets/data/osrm_pairs.json'));
const network = JSON.parse(read('assets/assets/data/dakar_network.json'));

const ORIGIN = 'https://aydiarra-star.github.io';
const BASE = indexHtml.match(/<base href="([^"]+)"/)[1];
const LOCAL_PATH = `${BASE}osrm/route/v1/driving/`;
const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';
const OSRM_SUFFIX = '?overview=full&geometries=geojson';

let failures = 0;
const ok = (label, cond, extra = '') => {
  console.log(`  ${cond ? 'OK  ' : 'ECHEC'} ${label}${extra ? ' — ' + extra : ''}`);
  if (!cond) failures++;
};

// --- 1. Filtre A.eI (v4) ----------------------------------------------------
console.log('\n[1] main.dart.js : filtre A.eI (v4)');
ok('rectangle d\'exclusion Hann/Dalifort retire',
  !mainJs.includes('-17.435&&s<=-17.375') && !mainJs.includes('s>=-17.435&&s<=-17.375'));
ok('marqueur v4 present dans A.eI', mainJs.includes('rectangle d\'exclusion Hann/Dalifort retire'));
ok('garde-fou Dakar conserve (lat 14.55-14.9, lng -17.6--16.85)',
  mainJs.includes('if(r<14.55||r>14.9)return!1') && mainJs.includes('if(s<-17.6||s>-16.85)return!1'));
const eI = (lat, lng) => {
  if (lat < 14.55 || lat > 14.9) return false;
  if (lng < -17.6 || lng > -16.85) return false;
  return true;
};
const invalidStops = network.stops.filter((s) => !eI(s.latitude, s.longitude));
ok(`94/94 arrets valides par eI v4`, invalidStops.length === 0, invalidStops.map((s) => s.id).join(','));

// --- 2. Constantes recalées + démos parsées depuis le vrai bundle ------------
console.log('\n[2] main.dart.js : constantes et lignes de demo $.J0');
for (const [name, lit] of [
  ['Rufisque B.J1', 'B.J1=new A.aE(14.71596,-17.27)'],
  ['Diamniadio B.kb', 'B.kb=new A.aE(14.71606,-17.19845)'],
  ['Fadia B.oK', 'B.oK=new A.aE(14.735,-17.436)'],
  ['Liberte 6 B.kh', 'B.kh=new A.aE(14.718,-17.455)'],
]) ok(`${name} = JSON (${lit})`, mainJs.includes(lit));

// Constantes B.* -> coordonnées.
const consts = new Map();
for (const m of mainJs.matchAll(/B\.([A-Za-z0-9_$]+)=new A\.aE\((-?[0-9.]+),(-?[0-9.]+)\)/g)) {
  consts.set(m[1], [parseFloat(m[2]), parseFloat(m[3])]); // [lat, lng]
}
// Lignes de démo : A.akW("NOM",...,A.b([STOPS],q),...).
const demos = [];
for (const m of mainJs.matchAll(/A\.akW\("([^"]+)",B\.[A-Za-z0-9_$]+,"[^"]*",A\.b\(\[([^\]]*)\],q\),"[^"]*"\)/g)) {
  const stops = [];
  for (const tok of m[2].split(/,(?![^(]*\))(?![^[]*\])/)) {
    const t = tok.trim();
    let mm = t.match(/^B\.([A-Za-z0-9_$]+)$/);
    if (mm) {
      if (!consts.has(mm[1])) { stops.push(null); continue; }
      stops.push(consts.get(mm[1]));
      continue;
    }
    mm = t.match(/^new A\.aE\((-?[0-9.]+),(-?[0-9.]+)\)$/);
    if (mm) { stops.push([parseFloat(mm[1]), parseFloat(mm[2])]); continue; }
    stops.push(null);
  }
  demos.push({ name: m[1], stops });
}
ok('4 lignes de demo parsees', demos.length === 4, demos.map((d) => d.name).join(','));
ok('aucun arret de demo inconnu', demos.every((d) => d.stops.every((s) => s !== null)));
const byName = new Map(demos.map((d) => [d.name, d.stops]));
const fmtPt = ([lat, lng]) => `${lng},${lat}`; // A.aS2 : lng,lat via String(double)
const demoPairs = [];
for (const [name, pts] of byName) {
  const valid = pts.filter(([lat, lng]) => eI(lat, lng));
  for (let i = 0; i + 1 < valid.length; i++) {
    demoPairs.push({ demo: name, coords: `${fmtPt(valid[i])};${fmtPt(valid[i + 1])}` });
  }
}
const stopsById = new Map(network.stops.map((s) => [s.id, s]));
const jsonCoords = (id) => { const s = stopsById.get(id); return [s.latitude, s.longitude]; };
const eq = (a, b) => a.length === b.length && a.every((p, i) => p[0] === b[i][0] && p[1] === b[i][1]);
const TER_IDS = ['stop_dakar_ter', 'stop_colobane', 'stop_hann', 'stop_dalifort_ter',
  'stop_baux_maraichers', 'stop_pikine', 'stop_thiaroye', 'stop_yeumbeul',
  'stop_keur_mbaye_fall', 'stop_pnr', 'stop_rufisque', 'stop_bargny', 'stop_diamniadio'];
const B1_IDS = network.routes.find((r) => r.id === 'brt_b1_guediawaye_petersen').stops;
ok('demo TER = 13 gares officielles dans l\'ordre',
  eq(byName.get('TER') ?? [], TER_IDS.map(jsonCoords)));
ok('demo B1 = JSON B1 direct (12 stations)',
  eq(byName.get('B1') ?? [], B1_IDS.map(jsonCoords)));
ok('demo DDD = ddd_12',
  eq(byName.get('DDD') ?? [], ['stop_guediawaye', 'stop_scatt_urbam', 'stop_parcelles_u26'].map(jsonCoords)));
ok('demo TATA = tata_219',
  eq(byName.get('TATA') ?? [], ['stop_parcelles_u26', 'stop_petersen'].map(jsonCoords)));

// --- 3. Paires demandées (JSON + démos) couvertes par le bundle --------------
console.log('\n[3] Couverture : paires JSON + paires demos dans le bundle');
const requested = [];
for (const route of network.routes) {
  const ids = route.stops ?? [];
  for (let i = 0; i + 1 < ids.length; i++) {
    const a = stopsById.get(ids[i]);
    const b = stopsById.get(ids[i + 1]);
    if (!a || !b) continue;
    if (!eI(a.latitude, a.longitude) || !eI(b.latitude, b.longitude)) continue;
    requested.push(`${a.longitude},${a.latitude};${b.longitude},${b.latitude}`);
  }
}
const uniqueCoords = [...new Set(requested)];
ok(`${uniqueCoords.length} paires JSON uniques, toutes dans osrm_pairs.json`,
  uniqueCoords.length === pairs.length && uniqueCoords.every((c) => pairs.includes(OSRM_PREFIX + c + OSRM_SUFFIX)));
const bundleKeys = new Set(Object.keys(bundle.geometries));
ok(`bundle schema=${bundle.schema} count=${bundle.count} : cles == paires`,
  bundle.schema === 2 && bundle.count === pairs.length
    && pairs.every((u) => bundleKeys.has(u)) && bundleKeys.size === pairs.length);
const demoMissing = demoPairs.filter((d) => !bundleKeys.has(OSRM_PREFIX + d.coords + OSRM_SUFFIX));
ok(`${demoPairs.length} paires de demo, toutes dans le bundle (0 appel 404)`,
  demoMissing.length === 0, demoMissing.slice(0, 2).map((d) => d.demo + ':' + d.coords).join(' | '));

// --- 4. Séparation par mode --------------------------------------------------
console.log('\n[4] Separation par mode (provenance)');
const trackOps = new Set(['ter', 'brt']);
const trackUrls = new Set();
for (const route of network.routes) {
  if (!trackOps.has(route.operator_id)) continue;
  const ids = route.stops ?? [];
  for (let i = 0; i + 1 < ids.length; i++) {
    const a = stopsById.get(ids[i]);
    const b = stopsById.get(ids[i + 1]);
    trackUrls.add(OSRM_PREFIX + `${a.longitude},${a.latitude};${b.longitude},${b.latitude}` + OSRM_SUFFIX);
  }
}
const prov = bundle.provenance ?? {};
const trackBad = [...trackUrls].filter((u) => !(prov[u] ?? '').endsWith('-secours'));
const trackNot2pts = [...trackUrls].filter((u) =>
  (bundle.geometries[u]?.routes?.[0]?.geometry?.coordinates ?? []).length !== 2);
const roadBad = pairs.filter((u) => !trackUrls.has(u) && prov[u] !== 'osrm-driving');
ok(`${trackUrls.size} paires TER/BRT = secours consecutif`, trackBad.length === 0, trackBad.slice(0, 2).join(' | '));
ok('payloads guides = EXACTEMENT 2 points (gares consecutives, 0 reutilisation)',
  trackNot2pts.length === 0, trackNot2pts.slice(0, 2).join(' | '));
const terShapes = JSON.parse(read('assets/assets/data/ter_rail_shapes.json'));
const brtShapes = JSON.parse(read('assets/assets/data/brt_dedicated_shapes.json'));
ok('formes en mode secours-consecutif (GTFS officiel indisponible documente)',
  terShapes.source_kind === 'secours-consecutif' && brtShapes.source_kind === 'secours-consecutif');
for (const [nm, sh] of [['TER', terShapes], ['BRT', brtShapes]]) {
  const seqs = sh.points.map((p) => p.shape_pt_sequence);
  ok(`forme ${nm} : sequences strictes 1..${seqs.length}`,
    seqs.every((s, i) => s === i + 1) && sh.points.every((p) => p.stop_id));
}
ok(`${pairs.length - trackUrls.size} paires bus = osrm-driving`, roadBad.length === 0);
const shapeSrcBad = [...trackUrls].filter((u) => !bundle.geometries[u]?.shape_source);
ok('payloads guides portent shape_source', shapeSrcBad.length === 0);
const roadHasShape = pairs.filter((u) => !trackUrls.has(u) && bundle.geometries[u]?.shape_source);
ok('payloads routiers sans shape_source', roadHasShape.length === 0);
// Longueurs : TER ~35 km ; BRT fidèle au modèle 12 stations.
const dist = (u) => bundle.geometries[u]?.routes?.[0]?.distance ?? 0;
let terLen = 0;
for (let i = 0; i + 1 < TER_IDS.length; i++) {
  const a = stopsById.get(TER_IDS[i]);
  const b = stopsById.get(TER_IDS[i + 1]);
  terLen += dist(OSRM_PREFIX + `${a.longitude},${a.latitude};${b.longitude},${b.latitude}` + OSRM_SUFFIX);
}
let brtLen = 0;
for (let i = 0; i + 1 < B1_IDS.length; i++) {
  const a = stopsById.get(B1_IDS[i]);
  const b = stopsById.get(B1_IDS[i + 1]);
  brtLen += dist(OSRM_PREFIX + `${a.longitude},${a.latitude};${b.longitude},${b.latitude}` + OSRM_SUFFIX);
}
ok(`TER ferroviaire : ${(terLen / 1000).toFixed(1)} km (plage 30-40)`, terLen >= 30000 && terLen <= 40000);
ok(`BRT site propre : ${(brtLen / 1000).toFixed(1)} km (plage 20-26)`, brtLen >= 20000 && brtLen <= 26000);

// --- 5. main.dart.js : non-régression v3 --------------------------------------
console.log('\n[5] main.dart.js : non-regression v3');
const ap9 = mainJs.split('A.ap9.prototype=')[1].slice(0, 300);
const ap6 = mainJs.split('A.ap6.prototype=')[1].slice(0, 300);
ok('xw() traite TOUTES les lignes', ap9.includes('$1(a){return!0}'));
ok('xv() ne traite plus aucune ligne', ap6.includes('$1(a){return!1}'));
ok(`prefixe demande = ${LOCAL_PATH} (meme origine)`, mainJs.includes(`"${LOCAL_PATH}"`));
ok('plus aucune reference au routeur public dans le bundle', !mainJs.includes('router.project-osrm.org'));

// --- 6. Environnement de test : caches + fetch -------------------------------
class FakeCache {
  constructor() { this.map = new Map(); }
  key(req) { return typeof req === 'string' ? req : req.url; }
  async match(req) { return this.map.get(this.key(req)); }
  async put(req, res) { this.map.set(this.key(req), res); }
  async keys() { return [...this.map.keys()].map((u) => new Request(u)); }
  async delete(req) { return this.map.delete(this.key(req)); }
}
const stores = new Map();
const caches = {
  async open(name) { if (!stores.has(name)) stores.set(name, new FakeCache()); return stores.get(name); },
  async delete(name) { return stores.delete(name); },
  async keys() { return [...stores.keys()]; },
};

let osrmPublicCalls = 0;
let staticFileServed = 0;
const OSRM_PUBLIC_DOWN = !process.argv.includes('--osrm-public-up');

async function fakeFetch(input, opts) {
  const raw = typeof input === 'string' ? input : input.url;
  const url = new URL(raw, `${ORIGIN}${BASE}`).toString();
  if (url.startsWith(`${ORIGIN}${BASE}assets/assets/data/osrm_geometries.json`)) {
    return new Response(JSON.stringify(bundle), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  if (url.startsWith(`${ORIGIN}${BASE}assets/assets/data/osrm_pairs.json`)) {
    return new Response(JSON.stringify(pairs), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  if (url.startsWith(`${ORIGIN}${BASE}assets/assets/data/`)) {
    const rel = decodeURIComponent(new URL(url).pathname.slice(BASE.length));
    const file = path.join(ROOT, rel);
    if (fs.existsSync(file)) return new Response(fs.readFileSync(file), { status: 200, headers: { 'Content-Type': 'application/octet-stream' } });
    return new Response('not found', { status: 404 });
  }
  if (url.startsWith(`${ORIGIN}${LOCAL_PATH}`)) {
    const coords = decodeURIComponent(new URL(url).pathname.slice(LOCAL_PATH.length));
    const file = path.join(ROOT, 'osrm/route/v1/driving', coords);
    if (fs.existsSync(file)) {
      staticFileServed++;
      return new Response(fs.readFileSync(file), { status: 200, headers: { 'Content-Type': 'application/octet-stream' } });
    }
    return new Response('not found', { status: 404 });
  }
  if (url.startsWith(OSRM_PREFIX)) {
    osrmPublicCalls++;
    if (OSRM_PUBLIC_DOWN) return new Response('rate limited', { status: 429 });
    const coords = new URL(url).pathname.slice('/route/v1/driving/'.length);
    const payload = bundle.geometries[OSRM_PREFIX + coords + OSRM_SUFFIX];
    return payload
      ? new Response(JSON.stringify(payload), { status: 200, headers: { 'Content-Type': 'application/json' } })
      : new Response('not found', { status: 404 });
  }
  return new Response('not found', { status: 404 });
}

// --- 7. Chargement du service worker réel ------------------------------------
const listeners = {};
const swConsole = { debug: () => {}, warn: (...a) => swConsole.warnings.push(a.join(' ')), log: () => {}, error: () => {}, warnings: [] };
const sandbox = {
  caches, fetch: fakeFetch, Response, Request, Headers, URL, AbortController,
  setTimeout, clearTimeout, TextEncoder, TextDecoder, console: swConsole,
  self: {
    addEventListener: (t, fn) => { (listeners[t] ??= []).push(fn); },
    location: new URL(BASE, ORIGIN),
    skipWaiting() {},
  },
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(swSource, sandbox, { filename: 'flutter_service_worker.js' });

const api = vm.runInContext(
  '({ TRACES_SW, GEOM_VERSION, OSRM_CACHE, OSRM_LOCAL_PATH, osrmBundleKey, osrmSeedFromBundle })', sandbox);
console.log(`\n[6] Service worker charge : TRACES_SW=${api.TRACES_SW} cache=${api.OSRM_CACHE} GEOM_VERSION=${api.GEOM_VERSION}`);
ok('TRACES_SW=v5', api.TRACES_SW === 'v5');
ok('cache=osrm-geom-v5 (renouvellement force)', api.OSRM_CACHE === 'osrm-geom-v5');
ok(`prefixe local du SW = ${LOCAL_PATH}`, api.OSRM_LOCAL_PATH === LOCAL_PATH);
ok('cle bundle retrouvee depuis une URL locale',
  api.osrmBundleKey(`${ORIGIN}${LOCAL_PATH}${uniqueCoords[0]}${OSRM_SUFFIX}`)
    === OSRM_PREFIX + uniqueCoords[0] + OSRM_SUFFIX);

async function dispatchFetch(url) {
  const event = {
    request: new Request(url),
    method: 'GET',
    _response: null,
    respondWith(p) { this._response = p; },
  };
  for (const fn of listeners.fetch ?? []) fn(event);
  if (!event._response) return null;
  return event._response;
}

const coordsOf = async (res) => {
  if (!res || res.status !== 200) return [];
  const body = JSON.parse(await res.text());
  return body?.routes?.[0]?.geometry?.coordinates ?? [];
};

// --- 8. Activation : semis du bundle -----------------------------------------
console.log('\n[7] Activation du service worker');
for (const fn of listeners.activate ?? []) {
  let wait;
  fn({ waitUntil: (p) => { wait = p; } });
  await wait;
}
const cache = await caches.open(api.OSRM_CACHE);
const seeded = (await cache.keys()).length;
ok(`semis : ${seeded}/${pairs.length} geometries en cache`, seeded === pairs.length);
ok('le semis n\'a pas appele le routeur public', osrmPublicCalls === 0);

// --- 9. Paires JSON + démos via le fetch handler ------------------------------
console.log('\n[8] Paires JSON + demos, via le fetch handler du SW');
let resolved = 0;
let straight = [];
let corsOk = 0;
for (const c of uniqueCoords) {
  const res = await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${c}${OSRM_SUFFIX}`);
  const coords = await coordsOf(res);
  if (coords.length >= 2) resolved++;
  else straight.push(c);
  if (res && res.headers.get('access-control-allow-origin') === '*') corsOk++;
}
ok(`${resolved}/${uniqueCoords.length} paires JSON servies avec une geometrie reelle`,
  resolved === uniqueCoords.length, straight.length ? `en echec : ${straight.slice(0, 3)}` : '');
let demoResolved = 0;
const demoStraight = [];
for (const d of demoPairs) {
  const res = await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${d.coords}${OSRM_SUFFIX}`);
  const coords = await coordsOf(res);
  if (coords.length >= 2) demoResolved++;
  else demoStraight.push(`${d.demo}:${d.coords}`);
}
ok(`${demoResolved}/${demoPairs.length} paires de demo servies avec une geometrie reelle`,
  demoResolved === demoPairs.length, demoStraight.slice(0, 2).join(' | '));
ok('toutes les reponses portent Access-Control-Allow-Origin: *', corsOk === uniqueCoords.length);
ok('aucune ne vient du fichier statique : tout est servi du cache/bundle',
  staticFileServed === 0, `${staticFileServed} appel(s) aux fichiers`);
ok(`routeur public OSRM ${OSRM_PUBLIC_DOWN ? 'simule HORS SERVICE et ' : ''}jamais appele`,
  osrmPublicCalls === 0, `${osrmPublicCalls} appel(s)`);

// --- 10. Assemblage des polylignes comme A.F1.xw() -----------------------------
console.log('\n[9] Polylignes de la carte (logique de A.F1.xw() reproduite)');
const geomCache = new Map();
for (const c of uniqueCoords) {
  const res = await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${c}${OSRM_SUFFIX}`);
  geomCache.set(c, await coordsOf(res));
}
let snappedLines = 0;
const straightLines = [];
let secoursLines = 0;
const secoursBad = [];
for (const route of network.routes) {
  const ids = route.stops ?? [];
  if (ids.length < 2) continue;
  const flat = [];
  for (let i = 0; i + 1 < ids.length; i++) {
    const a = stopsById.get(ids[i]);
    const b = stopsById.get(ids[i + 1]);
    const c = `${a.longitude},${a.latitude};${b.longitude},${b.latitude}`;
    const seg = geomCache.get(c);
    const pts = seg && seg.length >= 2 ? seg : [[a.longitude, a.latitude], [b.longitude, b.latitude]];
    const mapped = pts.map(([lng, lat]) => [lat, lng]);
    if (flat.length && mapped.length) flat.push(...mapped.slice(1));
    else flat.push(...mapped);
  }
  if (route.operator_id === 'ter' || route.operator_id === 'brt') {
    // v5 : secours = EXACTEMENT les gares/arrets consecutifs, dans l'ordre.
    const expected = ids.map((id) => { const s = stopsById.get(id); return [s.latitude, s.longitude]; });
    if (flat.length === expected.length && flat.every((p, i) => p[0] === expected[i][0] && p[1] === expected[i][1])) secoursLines++;
    else secoursBad.push(route.id);
  } else if (flat.length >= 2 && flat.length > ids.length) snappedLines++;
  else straightLines.push(route.id);
}
const nRoad = network.routes.filter((r) => r.operator_id !== 'ter' && r.operator_id !== 'brt').length;
ok(`${snappedLines}/${nRoad} lignes bus tracees sur voirie reelle`,
  snappedLines === nRoad,
  straightLines.length ? `encore droites : ${straightLines.slice(0, 5)}` : '');
ok(`${secoursLines}/3 lignes TER/BRT = gares consecutives exactes (secours spec)`,
  secoursLines === 3, secoursBad.join(', '));
// La démo TER (seule ligne TER affichee : la JSON est dedupee par awY) suit le rail.
const terDemoPts = [];
for (const d of demoPairs.filter((x) => x.demo === 'TER')) {
  terDemoPts.push(...(geomCache.get(d.coords) ?? []));
}
ok(`demo TER : ${terDemoPts.length} points = 12 segments x 2 gares consecutives`, terDemoPts.length === 24);

// --- 11. Repli sans service worker ----------------------------------------------
console.log('\n[10] Repli sans service worker : fichiers statiques du depot');
let onDisk = 0;
let diskStraight = [];
for (const c of uniqueCoords) {
  const file = path.join(ROOT, 'osrm/route/v1/driving', c);
  if (!fs.existsSync(file)) { diskStraight.push(c); continue; }
  const body = JSON.parse(fs.readFileSync(file, 'utf8'));
  if ((body?.routes?.[0]?.geometry?.coordinates ?? []).length >= 2) onDisk++;
  else diskStraight.push(c);
}
ok(`${onDisk}/${uniqueCoords.length} fichiers osrm/route/v1/driving/* valides`,
  onDisk === uniqueCoords.length, diskStraight.length ? `manquants : ${diskStraight.slice(0, 3)}` : '');
ok('aucun caractere non ASCII (decodage latin1 sur octet-stream sans risque)',
  (() => {
    const dir = path.join(ROOT, 'osrm/route/v1/driving');
    return fs.readdirSync(dir).every((f) => Buffer.from(fs.readFileSync(path.join(dir, f))).every((b) => b < 128));
  })());

// --- 12. SW dégradé + chemin legacy cross-origin (nouveauté v4) -----------------
console.log('\n[11] SW degrade : cache vide + bundle indisponible');
stores.delete(api.OSRM_CACHE);
vm.runInContext('osrmBundle = null;', sandbox);
const savedFetch = sandbox.fetch;
sandbox.fetch = async (input, opts) => {
  const url = typeof input === 'string' ? input : input.url;
  if (url.includes('osrm_geometries.json')) return new Response('boom', { status: 503 });
  return savedFetch(input, opts);
};
const degraded = await coordsOf(await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${uniqueCoords[42]}${OSRM_SUFFIX}`));
ok('geometrie reelle servie depuis le fichier statique (requete locale)', degraded.length >= 2,
  `${degraded.length} points, ${staticFileServed} fichier(s) statique(s) servi(s)`);
const terPublicUrl = OSRM_PREFIX + demoPairs.find((d) => d.demo === 'TER').coords + OSRM_SUFFIX;
const legacy = await dispatchFetch(terPublicUrl);
const legacyCoords = await coordsOf(legacy);
ok('paire TER demandee sur l\'ancien prefixe cross-origin : servie depuis le statique (jamais le routeur)',
  legacyCoords.length >= 2 && osrmPublicCalls === 0,
  `${legacyCoords.length} points, ${osrmPublicCalls} appel(s) au routeur public`);
ok('reponse legacy avec Access-Control-Allow-Origin: *',
  legacy && legacy.headers.get('access-control-allow-origin') === '*');
sandbox.fetch = savedFetch;

// --- 13. Cohérence des versions --------------------------------------------------
console.log('\n[12] Versions');
const label = mainJs.match(/Dakar Bus v[\d.]+ build \d+/)?.[0];
const version = JSON.parse(read('version.json'));
const idx = indexHtml.match(/serviceWorkerVersion: "(\d+)"/)?.[1];
const boot = read('flutter_bootstrap.js').match(/serviceWorkerVersion: "(\d+)"/)?.[1];
ok(`Reglages « ${label} » / version.json=${version.build_number} / SW=${idx} / bootstrap=${boot}`,
  label === `Dakar Bus v${version.version} build ${version.build_number}`
    && idx === '477962407' && boot === idx);

console.log(failures === 0
  ? `\nTOUS LES TESTS PASSENT (routeur public OSRM ${OSRM_PUBLIC_DOWN ? 'simule HORS SERVICE' : 'disponible'})`
  : `\n${failures} TEST(S) EN ECHEC`);
process.exit(failures === 0 ? 0 : 1);
