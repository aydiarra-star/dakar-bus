// Simulation du service worker v2.1 dans Node : prouve le semis du bundle et le
// repli « bundle à la demande » quand le routeur public OSRM est indisponible.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const swSource = fs.readFileSync(`${ROOT}/flutter_service_worker.js`, 'utf8');
const bundle = JSON.parse(fs.readFileSync(`${ROOT}/assets/assets/data/osrm_geometries.json`, 'utf8'));
const pairs = JSON.parse(fs.readFileSync(`${ROOT}/assets/assets/data/osrm_pairs.json`, 'utf8'));

// --- CacheStorage minimal -------------------------------------------------
class FakeCache {
  constructor() { this.map = new Map(); }
  async match(req) { const k = typeof req === 'string' ? req : req.url; return this.map.get(k) ?? undefined; }
  async put(req, res) { this.map.set(typeof req === 'string' ? req : req.url, res); }
  async keys() { return [...this.map.keys()].map((u) => ({ url: u })); }
  async delete(req) { return this.map.delete(typeof req === 'string' ? req : req.url); }
  async addAll(reqs) { for (const r of reqs) await this.put(r, new Response('stub')); }
}
const stores = new Map();
const caches = {
  async open(name) { if (!stores.has(name)) stores.set(name, new FakeCache()); return stores.get(name); },
  async delete(name) { return stores.delete(name); },
  async keys() { return [...stores.keys()]; },
};

// --- fetch simulé ---------------------------------------------------------
let osrmCalls = 0;
let bundleCalls = 0;
const OSRM_DOWN = process.argv.includes('--osrm-down');
async function fakeFetch(url, opts) {
  const u = typeof url === 'string' ? url : url.url;
  if (u.startsWith('assets/assets/data/osrm_geometries.json')) {
    bundleCalls++;
    return new Response(JSON.stringify(bundle), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  if (u.startsWith('assets/assets/data/osrm_pairs.json')) {
    return new Response(JSON.stringify(pairs), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  if (u.startsWith('https://router.project-osrm.org/')) {
    osrmCalls++;
    if (OSRM_DOWN) return new Response('rate limited', { status: 429 });
    return new Response(JSON.stringify({ code: 'Ok', routes: [{ geometry: { coordinates: [[-17.45, 14.72], [-17.44, 14.73]] } }] }),
      { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  return new Response('not found', { status: 404 });
}

// --- chargement du SW -----------------------------------------------------
const listeners = {};
const swLogs = { debug: 0, warn: [] };
const quietConsole = {
  debug: () => { swLogs.debug++; },
  warn: (...a) => { swLogs.warn.push(a.join(' ')); },
  log: console.log, error: console.error,
};
const sandbox = {
  caches, fetch: fakeFetch, Response, Request, console: quietConsole, setTimeout, clearTimeout, URL,
  AbortController, TextEncoder, TextDecoder,
  self: { addEventListener: (t, fn) => { (listeners[t] ??= []).push(fn); }, location: { origin: 'https://aydiarra-star.github.io' }, skipWaiting() {} },
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(swSource, sandbox, { filename: 'flutter_service_worker.js' });

const api = vm.runInContext('({ osrmSeedFromBundle, osrmRespond, osrmLoadBundle, TRACES_SW, GEOM_VERSION, OSRM_CACHE })', sandbox);
console.log(`SW chargé : TRACES_SW=${api.TRACES_SW} GEOM_VERSION=${api.GEOM_VERSION} cache=${api.OSRM_CACHE}`);
const logsSince = () => { const n = swLogs.debug; swLogs.debug = 0; return n; };

// --- Test 1 : semis du bundle à l'activation ------------------------------
await api.osrmSeedFromBundle();
const cache = await caches.open(api.OSRM_CACHE);
const seeded = (await cache.keys()).length;
logsSince();
console.log(`\n[TEST 1] semis : ${seeded}/${pairs.length} géométries en cache, appels bundle=${bundleCalls}, appels OSRM public=${osrmCalls}`);
if (seeded !== pairs.length) { console.error('  ECHEC : couverture incomplète'); process.exit(1); }
if (osrmCalls !== 0) { console.error('  ECHEC : le semis a tapé le routeur public'); process.exit(1); }
console.log('  OK : 1 seule requête bundle, 0 requête vers le routeur public');

// --- Test 2 : cache vide + routeur public HS -> repli bundle --------------
stores.delete(api.OSRM_CACHE);                       // simule un semis perdu/interruptu
vm.runInContext('osrmBundle = null;', sandbox);       // et un SW redémarré (mémoire vide)
const sample = pairs[137];
logsSince();
const res = await api.osrmRespond(new Request(sample));
const body = await res.json();
const coords = body?.routes?.[0]?.geometry?.coordinates ?? [];
console.log(`\n[TEST 2] cache vide + OSRM ${OSRM_DOWN ? 'en 429' : 'OK'} : paire #137`);
console.log(`  statut=${res.status} content-type=${res.headers.get('content-type')} coordonnées=${coords.length}`);
console.log(`  appels OSRM public=${osrmCalls} (le repli bundle doit répondre sans eux)`);
if (res.status !== 200 || coords.length < 2) { console.error('  ECHEC : pas de géométrie réelle servie'); process.exit(1); }
const back = await cache.match(sample);
console.log(`  remise en cache pour les prochains appels : ${back ? 'oui' : 'NON'}`);
if (!back) { console.error('  ECHEC : la réponse bundle n’a pas été remise en cache'); process.exit(1); }
if (OSRM_DOWN && osrmCalls > 4) { console.error('  ECHEC : repli vers le routeur public alors que le bundle avait la paire'); process.exit(1); }
console.log('  OK : itinéraire réel servi depuis le bundle, sans dépendre du routeur public');

// --- Test 3 : toutes les paires du réseau sont résolvables ----------------
let resolved = 0;
logsSince();
for (const url of pairs) {
  const r = await api.osrmRespond(new Request(url));
  const j = await r.json();
  if (r.status === 200 && (j?.routes?.[0]?.geometry?.coordinates?.length ?? 0) >= 2) resolved++;
}
console.log(`\n[TEST 3] ${resolved}/${pairs.length} paires résolues avec une géométrie routière réelle (${logsSince()} servis depuis le bundle)`);
if (resolved !== pairs.length) { console.error('  ECHEC : des mobilités resteraient en ligne droite'); process.exit(1); }
console.log('  OK : aucune mobilité ne retombe sur une ligne droite');

// --- Test 4 : libellé Réglages dans le bundle compilé ---------------------
const mainJs = fs.readFileSync(`${ROOT}/main.dart.js`, 'utf8');
const label = mainJs.match(/Dakar Bus v[\d.]+ build \d+/)?.[0];
const version = JSON.parse(fs.readFileSync(`${ROOT}/version.json`, 'utf8'));
const idx = fs.readFileSync(`${ROOT}/index.html`, 'utf8').match(/serviceWorkerVersion: "(\d+)"/)?.[1];
console.log(`\n[TEST 4] Réglages : « ${label} » | version.json build_number=${version.build_number} | serviceWorkerVersion=${idx}`);
if (label !== 'Dakar Bus v9.3.2 build 8' || version.build_number !== '8' || idx !== '477962404') {
  console.error('  ECHEC : incohérence de version'); process.exit(1);
}
console.log('  OK : build 8 affiché, cohérent avec version.json et le SW');
console.log('\nTOUS LES TESTS PASSENT');
