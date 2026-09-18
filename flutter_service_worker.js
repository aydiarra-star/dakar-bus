'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "f8621db206f6b8f7fe0dad8e136bff7c",
"index.html": "3d30264ad3755ac7731a33501f5f0a9d",
"/": "3d30264ad3755ac7731a33501f5f0a9d",
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
"main.dart.js": "0f1a5d111872aa16ec52e035a41479de",
"version.json": "35c7b98f6984ea4304b88334adc23ba7",
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

// ===== Traces routiers reels v2 (geometries prechargees au deploiement) =====
// Pre-charge en file regulée les geometries OSRM de toutes les paires d'arrets
// du reseau, les garde en cache persistant, et sert les requetes OSRM de l'app
// depuis ce cache : plus de rate-limit publique, plus de lignes droites, offline.
const OSRM_CACHE = 'osrm-geom-v2';
const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';
const OSRM_PAIRS_URL = 'assets/assets/data/osrm_pairs.json';
const OSRM_GEOMS_URL = 'assets/assets/data/osrm_geometries.json';
// v2 : version des geometries prechargees. Le workflow « PrefetchOSRM geometries »
// la recalcule (hachage du bundle) a chaque regeneration de osrm_geometries.json :
// le changement d'octets du service worker declenche la mise a jour chez les clients.
const GEOM_VERSION = 'v2-initial';
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

async function osrmRespond(request) {
  const cache = await caches.open(OSRM_CACHE);
  const hit = await cache.match(request);
  if (hit) return hit;
  try {
    return await osrmSchedule(request.url);
  } catch (e) {
    // Dernier recours : reseau direct non limite
    return fetch(request, { cache: 'no-store' });
  }
}

// v2 : installe en une seule requete les geometries prechargees par le workflow
// « PrefetchOSRM geometries » (bundle osrm_geometries.json commite sur gh-pages).
// La file runtime (osrmPrefetch) reste en repli pour les paires absentes du bundle.
async function osrmSeedFromBundle() {
  try {
    const res = await fetch(OSRM_GEOMS_URL + '?v=' + GEOM_VERSION, { cache: 'no-store' });
    if (!res.ok) throw new Error('bundle HTTP ' + res.status);
    const bundle = await res.json();
    const geoms = bundle && bundle.geometries;
    if (!geoms) throw new Error('bundle sans geometries');
    const cache = await caches.open(OSRM_CACHE);
    const existing = new Set((await cache.keys()).map((r) => r.url));
    let n = 0;
    for (const url in geoms) {
      if (existing.has(url)) continue;
      await cache.put(new Request(url), new Response(JSON.stringify(geoms[url]),
          { headers: { 'Content-Type': 'application/json' } }));
      n++;
    }
    console.debug('OSRM v2 : ' + n + ' geometries installees depuis le bundle precharge');
  } catch (e) {
    console.warn('OSRM v2 : bundle precharge indisponible (' + e + '), repli file runtime');
  }
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
    await osrmSeedFromBundle();
    await osrmPrefetch();
    await caches.delete('osrm-geom-v1'); // cache v1 obsolete
  })());
});

// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  // Requetes OSRM : servir depuis le cache de traces reels (ou file regulée).
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
