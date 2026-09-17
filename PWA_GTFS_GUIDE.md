# PWA + GTFS-RT - Guide d'implémentation Dakar Mobilité

## ✅ Ce qui a été ajouté (suite à ton "Oui")

### 1. PWA Offline-First
**Fichiers créés:**
- `manifest.json` : nom, icons, shortcuts (Explorer, Trajets, Alertes), theme #0f172a, display standalone, screenshots
- `service-worker.js` : cache static + dynamic + GTFS, stratégies
- `offline.html` : page fallback hors ligne

**Fonctionnalités PWA:**
- **Installable** : bannière d'installation automatique (beforeinstallprompt), bouton dans header + sidebar
- **Offline indicator** : bandeau jaune "Mode hors ligne" quand navigator.onLine = false
- **Cache stratégies:**
  - Static (index, manifest, offline.html, CDN) → Cache-first
  - Tuiles carto (basemaps.cartocdn.com) → Cache-first + revalidate background, gardées 7 jours
  - GTFS-RT /api/ → Network-first + fallback cache + mock JSON, TTL 30s
  - Navigation → fallback index.html ou offline.html
- **Background Sync** : quand on revient online, sync les alertes (`sync-alerts`)
- **Push Notifications** : bouton "Activer push" → demande permission, souscrit au pushManager, notif critique même app fermée
- **Cache size** : affiché dans Transports tab, récupéré via postMessage GET_CACHE_SIZE
- **GPS offline** : watchPosition fonctionne hors ligne, dernière position sauvée dans localStorage `last_gps`
- **Trajets sauvés offline** : bouton "⭐ Sauver offline" → localStorage `saved_trips` (20 max)
- **Alertes offline** : sauvées dans `gtfs_alerts` avec timestamp, restaurées si offline au load

**Test PWA:**
1. Ouvre le site, attends 3s → bannière "Installer Dakar Mobilité" apparaît
2. Sur Chrome: menu → Installer l'application
3. Sur iOS Safari: Partager → Sur l'écran d'accueil
4. Coupe le wifi → bandeau offline + carte reste visible (tiles en cache) + GPS actif + alertes cache 3h

### 2. GTFS-RT CETUD - Temps réel vrai + mock
**Client `GTFSRTClient` dans index.html:**
```js
const GTFS_CONFIG = {
  endpoint: '/api/gtfs-rt', // intercepté par SW
  realEndpoints: [
    'https://api.cetud.sn/gtfs-rt/vehiclePositions',
    'https://api.cetud.sn/gtfs-rt/tripUpdates',
    'https://api.cetud.sn/gtfs-rt/alerts'
  ],
  pollInterval: 3000, // 3s comme demandé
  useMock: true // passe à false quand tu as la clé CETUD
}
```

**Fonctionnement:**
- `fetchVehiclePositions()` : essaye vrai endpoint avec AbortController timeout 5s, sinon génère mock réaliste Dakar
- Mock génère 25 véhicules avec structure GTFS-RT officielle: header, entity[].vehicle { id, trip {tripId, routeId}, position {lat,lng,bearing,speed}, occupancyStatus, congestionLevel }
- `fetchNow()` : appelé toutes les 3s, met à jour les markers Leaflet directement (setLatLng), sauve dans localStorage pour offline
- Badge UI: `● GTFS-RT` vert passe en `GTFS-RT LIVE CETUD` quand vrai endpoint répond
- Bouton "Tester connexion GTFS" → force fetch + toast avec nb véhicules + source

**Comment brancher vraie API CETUD:**
1. Obtiens clé API CETUD (ou DDD, SENTER)
2. Dans `index.html`, change:
```js
GTFS_CONFIG.useMock = false;
GTFS_CONFIG.realEndpoints = ['https://TON_ENDPOINT/gtfs-rt'];
// Ajoute headers si besoin dans fetchWithFallback:
fetch(url, { headers: { 'Authorization': 'Bearer TA_CLE' } })
```
3. Si l'API renvoie du protobuf (GTFS-RT binaire), ajoute librairie `gtfs-realtime-bindings` ou utilise un proxy qui convertit en JSON
4. Le SW gère déjà le cache 30s + offline fallback, rien à changer

**Exemple proxy Node/Express pour convertir protobuf → JSON:**
```js
const GtfsRealtimeBindings = require('gtfs-realtime-bindings');
app.get('/api/gtfs-rt', async (req,res)=>{
  const resp = await fetch('https://api.cetud.sn/gtfs-rt', { headers: { 'x-api-key': process.env.CETUD_KEY }});
  const buffer = await resp.arrayBuffer();
  const feed = GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(new Uint8Array(buffer));
  res.json(feed);
});
```

### 3. Améliorations UX supplémentaires
- Offline badge sur carte "CACHE OFFLINE"
- GTFS-RT badge sur chaque ETA "• GTFS"
- Toasts plus longs (4s) avec max-width 90vw pour mobile
- Sauvegarde auto GPS + alertes + trips
- PWA status card dans sidebar avec SW, cache, offline, installable
- Config banner expliquant comment brancher vraie API

### 4. Fix refresh toujours actif
Le fix précédent (hash + localStorage + pushState) est conservé et compatible PWA. Le SW ne cache pas l'URL avec hash, donc refresh sur #trajets reste sur trajets même offline.

### 5. Déploiement PWA
Pour que PWA fonctionne en prod:
- HTTPS obligatoire (Vercel/Netlify OK)
- `manifest.json` et `service-worker.js` à la racine
- Vérifie avec Lighthouse → PWA score 100%
- Sur Vercel, ajoute dans `vercel.json`:
```json
{
  "headers": [
    { "source": "/service-worker.js", "headers": [{ "key": "Cache-Control", "value": "public, max-age=0, must-revalidate" }] }
  ],
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

**Fichiers finaux:**
- index.html (72KB, tout en un avec GTFS client + PWA logic)
- manifest.json
- service-worker.js (6.5KB)
- offline.html
- api/gtfs-rt (mock placeholder)
- PWA_GTFS_GUIDE.md (ce fichier)
- CORRECTIFS.md (ancien fix)

L'app est prête à être installée et à passer en vrai GTFS-RT dès que tu as l'endpoint CETUD.
