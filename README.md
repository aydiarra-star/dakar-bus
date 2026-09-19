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

## 🗺️ 23 Stations BRT Réelles Ajoutées

Source : CETUD brochure + Senego + Wikipedia BRT Dakar

1. Papa Gueye Fall - PEM Petersen
2. Grande Mosquée
3. Place de la Nation - Obélisque
4. Dial Diop 1
5. Dial Diop 2
6. Grand Dakar
7. Liberté 1
8. Sacré-Cœur
9. Liberté 5
10. Liberté 6
11. Khar Yallah
12. Scat Urbam
13. Cardinal Hyacinthe Thiandoum
14. Grand Médine - PEM
15. Police des Parcelles
16. Croisement 22
17. Parcelles Assainies
18. Fith Mith
19. Ndingala - Golf Sud
20. Dalal Jam - Hôpital
21. Golf Nord
22. Gadaye - Cambérène
23. Préfecture Guédiawaye - PEM

+ 13 gares TER Dakar → Diamniadio + arrêts DDD/AFTU

Tout est dans `data/gtfs/stops.txt` et affiché sur carte avec icônes violettes BRT.

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
│   ├── stops.txt (42 arrêts dont 23 BRT)
│   ├── routes.txt (9 routes)
│   ├── trips.txt, stop_times.txt, shapes.txt
│   └── agency.txt, calendar.txt
├── server/
│   ├── server.js           # Proxy Express GTFS-RT protobuf→JSON
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
| `/api/gtfs/static` | GTFS static Dakar JSON (42 arrêts) |
| `/data/gtfs/stops.txt` | GTFS static brut |
| `/api/vehicles` | Format simple Leaflet |
| `/api/health` | Status MOCK/LIVE |

Sur GitHub Pages, `/api/*` n'existe pas → frontend fallback mock local automatique (fonctionne quand même).

## 📄 Licence

MIT - Pour Dakar
