# Dakar Mobilité - PWA Temps Réel + GTFS-RT CETUD

**Site live :** https://tonuser.github.io/dakar-mobilite/ (après déploiement)

Mobilité urbaine Dakar en temps réel : BRT SunuBRT (23 stations réelles), Dakar Dem Dikk, TER, Car Rapide avec GPS live, alertes GTFS-RT CETUD, PWA offline.

## ✅ Fonctionnalités

- **Fix refresh bug** : onglet conservé au refresh (#trajets + localStorage + History API)
- **PWA offline** : installable, carte en cache 7j, GPS offline, service worker
- **GTFS-RT Proxy Express** : convertit protobuf CETUD → JSON, cache 30s, mock 127 bus si pas de clé
- **GTFS Static Dakar** : 42 arrêts dont **23 stations BRT réelles** (Papa Gueye Fall → Préfecture Guédiawaye), 9 routes, shapes BRT/TER
- **GPS live** : watchPosition haute précision, ETA live, tri par distance
- **Alertes temps réel** : WebSocket mock + push notifications + cache offline

## 🛣️ Tracés routiers réels (road snapping OSRM)

Les lignes ne sont **plus** dessinées « à vol d'oiseau » : chaque tracé est calculé par
OSRM en passant par **tous les arrêts réels de la ligne** (waypoints issus de
`data/gtfs/stop_times.txt`), puis validé (densité de points, passage à ≤ 150 m de chaque
arrêt, terminus, ratio de détour). Le TER utilise la **voie ferrée OpenStreetMap**.

| Ligne | Tracé | Source | Longueur |
|-------|-------|--------|----------|
| BRT 01 Petersen → Préfecture de Guédiawaye (23 stations) | OSRM via 23 stations | OSM relation 19961993 | 18,45 km (officiel ≈ 18,3 km) |
| TER Dakar → Diamniadio (13 gares) | voie ferrée OSM | OSM relation 13645077 | 35,7 km |
| DDD 7 Palais → Ouakam (31 arrêts) | OSRM via 31 arrêts | OSM relation 6990669 | 15,8 km |
| DDD 10 Palais → Liberté 5 (30 arrêts) | OSRM via 30 arrêts | OSM relation 6990845 | 15,7 km |
| DDD 23 Palais 1 → Parcelles Assainies (51 arrêts) | OSRM via 51 arrêts | OSM relation 7495279 | 22,5 km |

Les autres lignes (AFTU, TATA, DDD 12…) n'ont pas encore d'arrêts intermédiaires connus :
elles ne sont **pas dessinées** (aucun repli en ligne droite). Pour en ajouter une :

1. ajouter ses arrêts réels dans `data/gtfs/stops.txt` et son trajet dans `stop_times.txt` ;
2. lancer `npm run snap-routes` (OSRM public) ou `npm run snap-routes -- --print-urls` pour
   récupérer les URLs à la main puis enregistrer la réponse dans `data/routes/osrm-cache/<shape_id>.json` ;
3. `npm run validate-shapes` vérifie l'ordre lat/lng, la densité et le passage par chaque arrêt.

Fichiers générés : `data/gtfs/shapes.txt` (GTFS) et `data/routes/geometries.json`
(GeoJSON `[lng, lat]`, converti en `[lat, lng]` par Leaflet côté client). Provenance : `data/routes/sources.json`.

Conventions de coordonnées (voir `server/roadSnapping.js`) :

| Format | Ordre |
|--------|-------|
| OSRM URL / GeoJSON | `lng,lat` / `[lng, lat]` |
| Polyline encodée OSRM (`decodePolyline`) | `[lat, lng]` |
| GTFS (`stop_lat`, `stop_lon`, `shape_pt_lat`, `shape_pt_lon`) | lat puis lon |
| Leaflet (`L.polyline`, `setLatLng`) | `[lat, lng]` |

## 🗺️ Arrêts réels (source OpenStreetMap, ODbL)

`data/gtfs/stops.txt` contient 128 arrêts géolocalisés depuis OSM : 23 stations BRT
(Petersen, Grande Mosquée, Place de la Nation, Dial Diop, Grand Dakar, Liberté 1, Sacré-Cœur,
Liberté 5, Liberté 6, Khar Yalla, Scat Urbam, Cardinal Hyacinthe Thiandoum, Grand Médine,
Police des Parcelles, Croisement 22, Parcelles Assainies, Ndingala, Golf Sud, Dalal Jamm,
Fith Mith, Golf Nord, Gueule Tapée, Préfecture de Guédiawaye), 13 gares TER (Dakar, Colobane,
Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Mbao, PNR, Rufisque, Bargny,
Diamniadio) et 92 arrêts Dakar Dem Dikk (lignes 7, 10, 23).

## 🚀 Déploiement GitHub Pages (1-click)

Ce repo est déjà configuré pour GitHub Pages avec GitHub Actions (`.github/workflows/deploy.yml`).

### Étapes :

1. **Crée repo GitHub** `dakar-mobilite` sur https://github.com/new
2. **Pousse le code** :
```bash
git init
git add .
git commit -m "Dakar Mobilité PWA + 23 BRT stations + GTFS-RT proxy"
git branch -M main
git remote add origin https://github.com/TONUSER/dakar-mobilite.git
git push -u origin main
```
3. **Active GitHub Pages** :
   - Va sur ton repo → Settings → Pages
   - Source : GitHub Actions
   - Le workflow se lance auto à chaque push sur main

4. **Site live** : `https://TONUSER.github.io/dakar-mobilite/`

### Test local
```bash
cd server && npm install && npm start
# http://localhost:8000
```

### Mode MOCK vs LIVE CETUD
- Sans clé : `USE_MOCK=true` → 127 bus mock réalistes (actuel)
- Avec clé CETUD : mets dans `server/.env` ou Vercel env vars :
```env
USE_MOCK=false
CETUD_API_KEY=ta_clé
CETUD_VEHICLE_POSITIONS_URL=https://api.cetud.sn/gtfs-rt/vehiclePositions
```
Frontend bascule auto en LIVE.

## 📁 Structure

```
.
├── index.html              # Frontend PWA (72KB, tout-en-un)
├── manifest.json           # PWA manifest
├── service-worker.js       # Offline cache
├── offline.html            # Fallback offline
├── data/gtfs/              # GTFS static Dakar
│   ├── stops.txt (128 arrêts réels OSM : 23 BRT, 13 TER, 92 DDD)
│   ├── routes.txt (76 routes)
│   ├── trips.txt, stop_times.txt (waypoints réels des lignes tracées)
│   ├── shapes.txt          # GÉNÉRÉ par scripts/generate-shapes.js (tracés routiers)
│   └── agency.txt, calendar.txt
├── data/routes/
│   ├── geometries.json     # GÉNÉRÉ : GeoJSON [lng,lat] des tracés (servi au frontend)
│   ├── osrm-cache/         # Réponses OSRM (polyline) par shape_id
│   ├── manual/             # Géométries manuelles (voie ferrée TER depuis OSM)
│   └── sources.json        # Provenance (relations/nœuds OSM, méthode)
├── scripts/
│   ├── generate-shapes.js  # npm run snap-routes  (OSRM via arrêts réels, sans repli)
│   └── validate-shapes.js  # npm run validate-shapes
├── server/
│   ├── server.js           # Proxy Express GTFS-RT protobuf→JSON + /api/routes/*
│   ├── roadSnapping.js     # Service OSRM : décodage polyline, conversions lat/lng, contrôles qualité
│   ├── roadSnapping.test.js# npm test
│   ├── gtfs.js             # Parsing CSV RFC 4180 + waypoints par trajet
│   ├── package.json
│   ├── .env.example
│   └── test-cetud.js
├── .github/workflows/deploy.yml  # GitHub Pages auto-deploy
├── vercel.json             # Pour Vercel aussi
└── README.md
```

## 📱 PWA

- Installable sur Android/iOS
- Offline : carte + GPS + trajets sauvés
- Push notifs alertes critiques
- Service Worker cache 30s GTFS-RT + 7j tuiles

## 🔌 API

| Endpoint | Description |
|----------|-------------|
| `/api/gtfs-rt/vehiclePositions` | Positions bus (via proxy Express, sinon mock) |
| `/api/gtfs/static` | GTFS static Dakar JSON (128 arrêts) |
| `/data/gtfs/stops.txt` | GTFS static brut |
| `/data/routes/geometries.json` | Tracés routiers réels (GeoJSON `[lng, lat]`) |
| `/api/routes/geometry?mode=ddd` | Tracés pré-générés filtrables (`route=`, `mode=`) |
| `/api/routes/:routeId/geometry` | Tracé d'une ligne (pré-généré, sinon OSRM à la volée via ses arrêts ; 404 si aucun arrêt connu — jamais de ligne droite) |
| `POST /api/routes/snap` | Road snapping à la demande `{ stops: [{lat, lng, sequence?}] }` → GeoJSON + polyline |
| `/api/vehicles` | Format simple Leaflet |
| `/api/health` | Status MOCK/LIVE |

Sur GitHub Pages, `/api/*` n'existe pas → frontend fallback mock local automatique (fonctionne quand même).

## 📄 Licence

MIT - Pour Dakar
