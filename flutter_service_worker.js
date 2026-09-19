'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "c83c6add4003cca9f48287e3bd6f1c1c",
"index.html": "6e0b5cd811b5c301e699fe0ef2b40400",
"/": "6e0b5cd811b5c301e699fe0ef2b40400",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"canvaskit/skwasm.js.symbols": "262f4827a1317abb59d71d6c587a93e2",
"canvaskit/skwasm.wasm": "9f0c0c02b82a910d12ce0543ec130e60",
"canvaskit/chromium/canvaskit.wasm": "b1ac05b29c127d86df4bcfbf50dd902a",
"canvaskit/chromium/canvaskit.js": "671c6b4f8fcc199dcc551c7bb125f239",
"canvaskit/chromium/canvaskit.js.symbols": "a012ed99ccba193cf96bb2643003f6fc",
"canvaskit/canvaskit.wasm": "1f237a213d7370cf95f443d896176460",
"canvaskit/canvaskit.js": "66177750aff65a66cb07bb44b8c6422b",
"canvaskit/canvaskit.js.symbols": "48c83a2ce573d9692e8d970e288d75f7",
"canvaskit/skwasm.js": "694fda5704053957c2594de355805228",
"flutter.js": "f393d3c16b631f36852323de8e583132",
"main.dart.js": "30849dd4054bf6e71292f4eaa9cc0bd4",
"version.json": "e65464e45188b988e8c2513a0fdf6020",
"assets/assets/data/dakar_network.json": "0e3fad1b6af958f1dc77d608c9b33574",
"assets/assets/data/osrm_pairs.json": "3ddadaab1784b1d8d1601f81376cb3f5",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/fonts/MaterialIcons-Regular.otf": "d164c2e1de1f8d6c9305a88053d6c824",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.json": "b46737cf7adc121b830dcedb4b44a129",
"assets/AssetManifest.bin": "40e52590caf612e4557acbe41408f3e1",
"assets/AssetManifest.bin.json": "ad3d4ca430f5ec9950ba512db89136a0",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/NOTICES": "71e6398d95630ac1b40be1b31ae74461",
"manifest.json": "6f54d1c7161f2eaf864347a26b355b4f"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});

// ===== Traces routiers reels v3 (meme origine : aucun appel au routeur public) =====
// L'app demande ses geometries sur la MEME origine que le site :
//   /dakar-bus/osrm/route/v1/driving/<lng,lat;lng,lat>?overview=full&geometries=geojson
// Trois niveaux de service, dans l'ordre :
//   1. cache persistant osrm-geom-v3 (instantane, offline) ;
//   2. bundle precharge assets/assets/data/osrm_geometries.json (1 requete) ;
//   3. fichiers statiques osrm/route/v1/driving/* — servis par GitHub Pages,
//      donc operationnels MEME sans service worker (premiere visite).
// Le routeur public OSRM n'est plus jamais appele par la carte : plus de 429,
// plus de ligne droite entre deux arrets.
const OSRM_CACHE = 'osrm-geom-v3';
const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';
const OSRM_LOCAL_PATH = '/dakar-bus/osrm/route/v1/driving/';
const OSRM_SUFFIX = '?overview=full&geometries=geojson';
const OSRM_PAIRS_URL = 'assets/assets/data/osrm_pairs.json';
const OSRM_GEOMS_URL = 'assets/assets/data/osrm_geometries.json';
// Version des geometries prechargees. Le workflow « PrefetchOSRM geometries »
// la recalcule (hachage du bundle) a chaque regeneration de osrm_geometries.json.
const GEOM_VERSION = 'v2-06ce66cf0908';
// Marqueur de revision du correctif traces (audit, logs).
const TRACES_SW = 'v3';

let osrmBundle = null;
let osrmBundlePromise = null;
let osrmSeedAttempts = 0;
const OSRM_SEED_MAX_ATTEMPTS = 3;
const OSRM_SEED_RETRY_MS = 30000;

async function osrmLoadBundle() {
  if (osrmBundle) return osrmBundle;
  if (!osrmBundlePromise) {
    osrmBundlePromise = (async () => {
      try {
        const res = await fetch(OSRM_GEOMS_URL + '?v=' + GEOM_VERSION, { cache: 'no-store' });
        if (!res.ok) throw new Error('bundle HTTP ' + res.status);
        const data = await res.json();
        const geoms = data && data.geometries;
        if (!geoms) throw new Error('bundle sans geometries');
        osrmBundle = geoms;
        return geoms;
      } finally {
        osrmBundlePromise = null;
      }
    })();
  }
  return osrmBundlePromise;
}

// v3 : toute reponse fabriquee ici porte les en-tetes CORS. Sans eux, une
// reponse synthetisee par le service worker pour une requete cross-origin est
// rejetee par le navigateur et l'app retombe sur une ligne droite.
function osrmJsonResponse(payload) {
  return new Response(JSON.stringify(payload), { headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Timing-Allow-Origin': '*'
  } });
}

// v3 : cle du bundle pour une URL, locale (/dakar-bus/osrm/route/v1/driving/...) ou publique.
function osrmBundleKey(url) {
  if (url.indexOf(OSRM_PREFIX) === 0) return url;
  let u;
  try {
    u = new URL(url, self.location.href);
  } catch (e) {
    return null;
  }
  if (u.pathname.indexOf(OSRM_LOCAL_PATH) !== 0) return null;
  const coords = u.pathname.substring(OSRM_LOCAL_PATH.length);
  if (!coords || coords.indexOf('/') !== -1) return null;
  return OSRM_PREFIX + coords + OSRM_SUFFIX;
}

// Cache -> bundle. Renvoie null si la paire n'est disponible nulle part.
async function osrmServe(url) {
  const key = osrmBundleKey(url);
  if (!key) return null;
  const cache = await caches.open(OSRM_CACHE);
  const hit = await cache.match(key);
  // Toujours reconstruite depuis un clone : la reponse stockee n'est jamais
  // consommee (une seconde lecture du cache doit marcher) et les en-tetes CORS
  // sont garantis quelle que soit la provenance de l'entree.
  if (hit) return osrmJsonResponse(await hit.clone().json());
  try {
    const geoms = await osrmLoadBundle();
    const payload = geoms && geoms[key];
    if (payload) {
      const response = osrmJsonResponse(payload);
      await cache.put(key, response.clone());
      return response;
    }
  } catch (e) {
    console.warn('OSRM ' + TRACES_SW + ' : bundle indisponible (' + e + ')');
  }
  return null;
}

// v3 : requete de l'app sur la meme origine.
// Dernier niveau : le fichier statique du depot (marche aussi sans SW).
async function osrmLocalRespond(request) {
  const served = await osrmServe(request.url);
  if (served) return served;
  return fetch(request, { cache: 'no-store' });
}

// Ancien prefixe cross-origin, pour les clients dont le main.dart.js n'est pas
// encore a jour : cache -> bundle -> routeur public en file regulée.
async function osrmRespond(request) {
  const served = await osrmServe(request.url);
  if (served) return served;
  try {
    return await osrmSchedule(request.url);
  } catch (e) {
    return fetch(request, { cache: 'no-store' });
  }
}

let osrmInflight = {};
let osrmQueue = [];
let osrmActive = 0;
let osrmPrefetchStarted = false;
const OSRM_MAX_CONC = 2;
const OSRM_SPACING_MS = 400;
const OSRM_TIMEOUT_MS = 10000;

function osrmNetwork(url, attempt) {
  return new Promise((resolve, reject) => {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), OSRM_TIMEOUT_MS);
    fetch(url, { signal: ctrl.signal }).then((res) => {
      clearTimeout(t);
      if (res.ok) {
        return caches.open(OSRM_CACHE).then((c) => c.put(url, res.clone())).then(() => resolve(res));
      }
      if ((res.status === 429 || res.status >= 500) && attempt < 4) {
        return setTimeout(() => resolve(osrmNetwork(url, attempt + 1)), 1500 * attempt);
      }
      reject(new Error('OSRM ' + res.status));
    }).catch((e) => {
      clearTimeout(t);
      if (attempt < 4) return setTimeout(() => resolve(osrmNetwork(url, attempt + 1)), 1500 * attempt);
      reject(e);
    });
  });
}

function osrmSchedule(url) {
  if (osrmInflight[url]) return osrmInflight[url];
  const p = new Promise((resolve, reject) => { osrmQueue.push({ url, resolve, reject }); osrmPump(); });
  osrmInflight[url] = p;
  p.finally(() => { delete osrmInflight[url]; });
  return p;
}

function osrmPump() {
  while (osrmActive < OSRM_MAX_CONC && osrmQueue.length > 0) {
    const job = osrmQueue.shift();
    osrmActive++;
    osrmNetwork(job.url, 1)
      .then(job.resolve)
      .catch((e) => { console.warn('OSRM serve fail', job.url, e); job.reject(e); })
      .finally(() => { osrmActive--; setTimeout(osrmPump, OSRM_SPACING_MS); });
  }
}

// Installe en une seule requete les geometries prechargees par le workflow
// « PrefetchOSRM geometries » (bundle osrm_geometries.json commite sur gh-pages).
async function osrmSeedFromBundle() {
  let geoms;
  try {
    geoms = await osrmLoadBundle();
  } catch (e) {
    console.warn('OSRM ' + TRACES_SW + ' : bundle precharge indisponible (' + e
        + '), repli fichiers statiques + nouvelle tentative programmee');
    osrmScheduleSeedRetry();
    return;
  }
  const cache = await caches.open(OSRM_CACHE);
  const before = new Set((await cache.keys()).map((r) => r.url));
  const urls = Object.keys(geoms);
  let n = 0;
  for (const url of urls) {
    if (before.has(url)) continue;
    await cache.put(new Request(url), osrmJsonResponse(geoms[url]));
    n++;
  }
  console.debug('OSRM ' + TRACES_SW + ' : ' + n + ' geometries installees depuis le bundle ('
      + urls.length + ' au total)');
  const after = new Set((await cache.keys()).map((r) => r.url));
  const missing = urls.filter((u) => !after.has(u));
  if (missing.length === 0) {
    console.debug('OSRM ' + TRACES_SW + ' : couverture complete ' + after.size + '/' + urls.length);
    return;
  }
  console.warn('OSRM ' + TRACES_SW + ' : ' + missing.length + ' geometries manquantes apres semis');
  osrmScheduleSeedRetry();
}

function osrmScheduleSeedRetry() {
  if (osrmSeedAttempts >= OSRM_SEED_MAX_ATTEMPTS) {
    console.warn('OSRM ' + TRACES_SW + ' : semis abandonne, le repli bundle/fichiers prend le relais');
    return;
  }
  osrmSeedAttempts++;
  setTimeout(() => {
    osrmSeedFromBundle().catch((e) => console.warn('OSRM ' + TRACES_SW + ' : retry KO', e));
  }, OSRM_SEED_RETRY_MS);
}

async function osrmPrefetch() {
  if (osrmPrefetchStarted) return;
  osrmPrefetchStarted = true;
  try {
    const cache = await caches.open(OSRM_CACHE);
    const res = await fetch(OSRM_PAIRS_URL, { cache: 'no-store' });
    const pairs = await res.json();
    const existing = new Set((await cache.keys()).map((r) => r.url));
    for (const url of pairs) {
      if (!existing.has(url)) osrmSchedule(url).catch(() => {});
    }
    console.debug('OSRM prefetch :', pairs.length - existing.size, 'geometries en file');
  } catch (e) { console.warn('OSRM prefetch fail', e); }
}

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      await osrmSeedFromBundle();
      await osrmPrefetch();
    } catch (e) {
      // Un semis incomplet ne doit jamais bloquer l'activation.
      console.warn('OSRM ' + TRACES_SW + ' : semis incomplet (' + e
          + '), repli bundle/fichiers statiques actif');
    }
    await caches.delete('osrm-geom-v1'); // caches obsoletes
    await caches.delete('osrm-geom-v2');
  })());
});

// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  // v3 : tracés reels — meme origine d'abord (l'app), ancien prefixe ensuite.
  if (new URL(event.request.url).pathname.indexOf(OSRM_LOCAL_PATH) === 0) {
    event.respondWith(osrmLocalRespond(event.request));
    return;
  }
  if (event.request.url.startsWith(OSRM_PREFIX)) {
    event.respondWith(osrmRespond(event.request));
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
