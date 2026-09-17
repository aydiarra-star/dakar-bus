// Neutralise l'ancien service worker PWA (cache CARTO / API KEY REQUIRED) :
// se met à jour par-dessus, vide les caches, puis se désinstalle.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k)))).then(() => {
      return self.clients.claim();
    }).then(() => self.registration.unregister())
  );
});
