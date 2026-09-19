// Dakar Mobilité - Service Worker PWA + Offline + GTFS-RT cache
const CACHE_VERSION = 'dakar-mobilite-v2.2';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;
const GTFS_CACHE = `${CACHE_VERSION}-gtfs`;

const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/offline.html',
  '/data/gtfs/stops.txt',
  '/data/gtfs/shapes.txt',
  '/data/gtfs/routes.txt',
  '/data/gtfs/trips.txt',
  '/data/gtfs/stop_times.txt',
  'https://cdn.tailwindcss.com',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
  'https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=Space+Grotesk:wght@500;700&display=swap'
];

// GTFS-RT endpoints - will be cached with network-first strategy
const GTFS_ENDPOINTS = [
  '/api/gtfs-rt',
  '/api/vehicles',
  '/api/alerts',
  'https://api.cetud.sn',
  'https://api.dakardemdikk.sn'
];

self.addEventListener('install', (event) => {
  console.log('[SW] Install', CACHE_VERSION);
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(STATIC_ASSETS.map(url => new Request(url, { cache: 'no-cache' }))).catch(err => {
        console.warn('[SW] Some assets failed to cache', err);
        // Cache at least the core
        return cache.addAll(['/','/index.html','/manifest.json']);
      });
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activate');
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(k => !k.startsWith(CACHE_VERSION)).map(k => {
          console.log('[SW] Deleting old cache', k);
          return caches.delete(k);
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Network-first for GTFS-RT / live data, Cache-first for static
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET
  if (request.method !== 'GET') return;

  // Handle GTFS-RT live data - Network first, fallback to cache + mock
  if (GTFS_ENDPOINTS.some(ep => url.href.includes(ep)) || url.pathname.includes('/api/')) {
    event.respondWith(
      fetch(request)
        .then(response => {
          // Cache successful GTFS responses for 30s
          if (response.ok) {
            const clone = response.clone();
            caches.open(GTFS_CACHE).then(cache => {
              cache.put(request, clone);
              // Auto-expire after 30s via timestamp header check in client
            });
          }
          return response;
        })
        .catch(() => {
          // Offline: return cached GTFS or mock data
          return caches.match(request).then(cached => {
            if (cached) return cached;
            // Return mock GTFS-RT JSON
            return new Response(JSON.stringify({
              source: 'cache-offline-mock',
              timestamp: Date.now(),
              vehicles: [],
              alerts: [],
              offline: true
            }), {
              headers: { 'Content-Type': 'application/json' }
            });
          });
        })
    );
    return;
  }

  // Leaflet tiles - Cache first with network fallback (important for offline map)
  if (url.hostname.includes('basemaps.cartocdn.com') || url.hostname.includes('tile.openstreetmap.org')) {
    event.respondWith(
      caches.open(DYNAMIC_CACHE).then(cache => {
        return cache.match(request).then(cached => {
          if (cached) {
            // Revalidate in background
            fetch(request).then(res => {
              if (res.ok) cache.put(request, res);
            }).catch(()=>{});
            return cached;
          }
          return fetch(request).then(res => {
            if (res.ok) cache.put(request, res.clone());
            return res;
          }).catch(() => cached);
        });
      })
    );
    return;
  }

  // Static assets - Cache first
  event.respondWith(
    caches.match(request).then(cached => {
      if (cached) return cached;
      return fetch(request).then(response => {
        // Cache new static assets
        if (response.ok && (request.url.startsWith(self.location.origin) || STATIC_ASSETS.includes(request.url))) {
          const clone = response.clone();
          caches.open(DYNAMIC_CACHE).then(cache => cache.put(request, clone));
        }
        return response;
      }).catch(() => {
        // Offline fallback for navigation
        if (request.mode === 'navigate') {
          return caches.match('/index.html').then(c => c || caches.match('/offline.html'));
        }
      });
    })
  );
});

// Background Sync for alerts when back online
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-alerts') {
    event.waitUntil(
      // Try to fetch latest alerts when back online
      fetch('/api/alerts').then(res => {
        if (res.ok) {
          return res.json().then(data => {
            // Notify clients
            self.clients.matchAll().then(clients => {
              clients.forEach(client => client.postMessage({ type: 'ALERTS_SYNCED', data }));
            });
          });
        }
      }).catch(()=>{})
    );
  }
});

// Push notifications for critical alerts (CETUD)
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : { title: 'Dakar Mobilité', body: 'Nouvelle alerte trafic à Dakar' };
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/manifest.json', // fallback
      badge: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" rx="24" fill="%230f172a"/><text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-weight="800" font-size="48" fill="white">D</text></svg>',
      vibrate: [200, 100, 200],
      data: { url: '/#alertes' }
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data.url || '/#alertes')
  );
});

// Message handler for client
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  if (event.data && event.data.type === 'GET_CACHE_SIZE') {
    caches.keys().then(keys => {
      Promise.all(keys.map(k => caches.open(k).then(c => c.keys().then(ks => ({ name:k, count:ks.length }))))).then(sizes => {
        event.ports[0].postMessage({ sizes });
      });
    });
  }
});
