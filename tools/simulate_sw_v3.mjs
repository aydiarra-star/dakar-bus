// Simulation v3 : charge le VRAI flutter_service_worker.js dans un VM Node avec
// des caches et un fetch de test, puis verifie la chaine complete
//
//   dakar_network.json
//     -> URL construites exactement comme le fait main.dart.js (A.aS2)
//     -> fetch handler du service worker
//     -> geometrie routiere reelle (>= 2 points, donc pas de ligne droite)
//
// ainsi que le repli « sans service worker » : les fichiers statiques
// osrm/route/v1/driving/* servis tels quels par GitHub Pages.
//
// Par defaut le routeur public OSRM est simule HORS SERVICE (429) : si un seul
// itineraire en dependait encore, le test echouerait.
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

// --- 1. Ce que main.dart.js demande, reconstruit a l'identique -----------------
// A.aS2 : ".../route/v1/driving/" + lng + "," + lat + ";" + lng + "," + lat
//         + "?overview=full&geometries=geojson"   (concatenation de doubles bruts)
// String(double) en JS == toString() d'un double Dart (representation la plus
// courte qui round-trip) == repr(float) en Python.
const stopsById = new Map(network.stops.map((s) => [s.id, s]));
const requested = [];
for (const route of network.routes) {
  const ids = route.stops ?? [];
  for (let i = 0; i + 1 < ids.length; i++) {
    const a = stopsById.get(ids[i]);
    const b = stopsById.get(ids[i + 1]);
    if (!a || !b) continue;
    requested.push({
      route: route.id,
      coords: `${a.longitude},${a.latitude};${b.longitude},${b.latitude}`,
    });
  }
}
const uniqueCoords = [...new Set(requested.map((r) => r.coords))];

console.log(`\n[1] Donnees reseau : ${network.routes.length} lignes, ${network.stops.length} arrets`);
ok(`${requested.length} paires d'arrets consecutifs (${uniqueCoords.length} uniques)`,
  uniqueCoords.length > 0);
ok('les URL publiques deduites sont exactement celles d\'osrm_pairs.json',
  uniqueCoords.every((c) => pairs.includes(OSRM_PREFIX + c + OSRM_SUFFIX))
    && pairs.length === uniqueCoords.length);

// --- 2. main.dart.js : les polylignes de la carte -----------------------------
console.log('\n[2] main.dart.js : construction des polylignes de la carte');
const ap9 = mainJs.split('A.ap9.prototype=')[1].slice(0, 300);
const ap6 = mainJs.split('A.ap6.prototype=')[1].slice(0, 300);
ok('xw() (traces OSRM) traite TOUTES les lignes', ap9.includes('$1(a){return!0}'));
ok('xv() (lignes droites) ne traite plus aucune ligne', ap6.includes('$1(a){return!1}'));
ok(`prefixe demande = ${LOCAL_PATH} (meme origine)`, mainJs.includes(`"${LOCAL_PATH}"`));
ok('plus aucune reference au routeur public dans le bundle',
  !mainJs.includes('router.project-osrm.org'));

// --- 3. Environnement de test : caches + fetch -------------------------------
class FakeCache {
  constructor() { this.map = new Map(); }
  key(req) { return typeof req === 'string' ? req : req.url; }
  // Volontairement STRICT : un vrai navigateur rend une copie a chaque match.
  // Ici on rend l'objet stocke, pour prouver que le service worker ne consomme
  // jamais une reponse en cache (sinon le 2e appel echouerait).
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
  // Comme un navigateur : une URL relative est resolue contre la base du SW.
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
    // GitHub Pages sert le fichier statique du depot (repli sans cache/bundle).
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

// --- 4. Chargement du service worker reel ------------------------------------
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
console.log(`\n[3] Service worker charge : TRACES_SW=${api.TRACES_SW} cache=${api.OSRM_CACHE} GEOM_VERSION=${api.GEOM_VERSION}`);
ok(`prefixe local du SW = ${LOCAL_PATH}`, api.OSRM_LOCAL_PATH === LOCAL_PATH);
ok('cle bundle retrouvee depuis une URL locale',
  api.osrmBundleKey(`${ORIGIN}${LOCAL_PATH}${uniqueCoords[0]}${OSRM_SUFFIX}`)
    === OSRM_PREFIX + uniqueCoords[0] + OSRM_SUFFIX);

// FetchEvent minimal : on declenche le VRAI listener "fetch" du service worker.
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

// --- 5. Activation : semis du bundle ----------------------------------------
console.log('\n[4] Activation du service worker');
for (const fn of listeners.activate ?? []) {
  let wait;
  fn({ waitUntil: (p) => { wait = p; } });
  await wait;
}
const cache = await caches.open(api.OSRM_CACHE);
const seeded = (await cache.keys()).length;
ok(`semis : ${seeded}/${pairs.length} geometries en cache`, seeded === pairs.length);
ok('le semis n\'a pas appele le routeur public', osrmPublicCalls === 0);

// --- 6. Toutes les mobilites de la carte, via le fetch handler ---------------
console.log('\n[5] Chaque paire consecutive du reseau, via le fetch handler du SW');
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
ok(`${resolved}/${uniqueCoords.length} paires servies avec une geometrie routiere reelle`,
  resolved === uniqueCoords.length, straight.length ? `en ligne droite : ${straight.slice(0, 3)}` : '');
ok('toutes les reponses portent Access-Control-Allow-Origin: *', corsOk === uniqueCoords.length);
ok('aucune ne vient du fichier statique : tout est servi du cache/bundle',
  staticFileServed === 0, `${staticFileServed} appel(s) aux fichiers`);
ok(`routeur public OSRM ${OSRM_PUBLIC_DOWN ? 'simule HORS SERVICE et ' : ''}jamais appele`,
  osrmPublicCalls === 0, `${osrmPublicCalls} appel(s)`);

// --- 7. Assemblage des polylignes comme le fait A.F1.xw() --------------------
console.log('\n[6] Polylignes de la carte (logique de A.F1.xw() reproduite)');
const geomCache = new Map();
for (const c of uniqueCoords) {
  const res = await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${c}${OSRM_SUFFIX}`);
  geomCache.set(c, await coordsOf(res));
}
let snappedLines = 0;
const straightLines = [];
for (const route of network.routes) {
  const ids = route.stops ?? [];
  if (ids.length < 2) continue;
  const flat = [];
  for (let i = 0; i + 1 < ids.length; i++) {
    const a = stopsById.get(ids[i]);
    const b = stopsById.get(ids[i + 1]);
    const c = `${a.longitude},${a.latitude};${b.longitude},${b.latitude}`;
    const seg = geomCache.get(c);
    // A.aS2 retombe sur [depart, arrivee] si la geometrie est vide.
    const pts = seg && seg.length >= 2 ? seg : [[a.longitude, a.latitude], [b.longitude, b.latitude]];
    const mapped = pts.map(([lng, lat]) => [lat, lng]);
    if (flat.length && mapped.length) flat.push(...mapped.slice(1));
    else flat.push(...mapped);
  }
  // A.F1.xw() : if (m.length < 2) m = n  -> ligne droite entre arrets
  if (flat.length >= 2 && flat.length > ids.length) snappedLines++;
  else straightLines.push(route.id);
}
ok(`${snappedLines}/${network.routes.length} lignes tracees sur la voirie reelle`,
  snappedLines === network.routes.length,
  straightLines.length ? `encore droites : ${straightLines.slice(0, 5)}` : '');

// --- 8. Repli sans service worker (fichiers statiques du depot) --------------
console.log('\n[7] Repli sans service worker : fichiers statiques du depot');
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

// Cache vide + bundle indisponible -> le SW doit retomber sur le fichier statique.
console.log('\n[8] SW degrade : cache vide + bundle indisponible -> fichier statique');
stores.delete(api.OSRM_CACHE);
vm.runInContext('osrmBundle = null;', sandbox);
const savedFetch = sandbox.fetch;
sandbox.fetch = async (input, opts) => {
  const url = typeof input === 'string' ? input : input.url;
  if (url.includes('osrm_geometries.json')) return new Response('boom', { status: 503 });
  return savedFetch(input, opts);
};
const degraded = await coordsOf(await dispatchFetch(`${ORIGIN}${LOCAL_PATH}${uniqueCoords[42]}${OSRM_SUFFIX}`));
ok('geometrie reelle servie depuis le fichier statique', degraded.length >= 2,
  `${degraded.length} points, ${staticFileServed} fichier(s) statique(s) servi(s)`);
sandbox.fetch = savedFetch;

// --- 9. Coherence des versions ----------------------------------------------
console.log('\n[9] Versions');
const label = mainJs.match(/Dakar Bus v[\d.]+ build \d+/)?.[0];
const version = JSON.parse(read('version.json'));
const idx = indexHtml.match(/serviceWorkerVersion: "(\d+)"/)?.[1];
const boot = read('flutter_bootstrap.js').match(/serviceWorkerVersion: "(\d+)"/)?.[1];
ok(`Reglages « ${label} » / version.json=${version.build_number} / SW=${idx} / bootstrap=${boot}`,
  label === `Dakar Bus v${version.version} build ${version.build_number}`
    && idx === '477962405' && boot === idx);

console.log(failures === 0
  ? `\nTOUS LES TESTS PASSENT (routeur public OSRM ${OSRM_PUBLIC_DOWN ? 'simule HORS SERVICE' : 'disponible'})`
  : `\n${failures} TEST(S) EN ECHEC`);
process.exit(failures === 0 ? 0 : 1);
