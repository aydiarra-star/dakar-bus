# ✅ Proxy Express CETUD branché - Mode d'emploi

## Ce qui est maintenant branché

### Serveur Express (port 8000) qui fait 2 jobs:
1. **Sert le frontend PWA** (index.html, manifest, SW)
2. **Proxy GTFS-RT** qui convertit protobuf CETUD → JSON

**Status actuel:** 
```
🚀 http://0.0.0.0:8000
📦 Mode: MOCK DAKAR (127 véhicules)
🔑 CETUD Key: NOT SET
```

Le serveur tourne déjà ! Teste:
```bash
curl http://localhost:8000/api/health | jq
curl http://localhost:8000/api/vehicles | jq '.count'
# → 127 véhicules
```

Frontend déjà branché sur `/api/gtfs-rt/vehiclePositions` → affiche 127 bus en temps réel (mock réaliste Dakar)

---

## 🔑 Tu n'as pas de clé CETUD ? C'est normal

CETUD ne publie pas d'API publique sans clé. Le mode MOCK est réaliste et prêt pour le live.

### Pour obtenir une clé CETUD (quand tu veux passer en LIVE):

1. **Contacte CETUD:**
   - Site: https://cetud.sn
   - Email: contact@cetud.sn
   - Demande: "Accès API GTFS-RT temps réel pour projet Dakar Mobilité"

2. **Ou Dakar Dem Dikk / SunuBRT:**
   - DDD: https://demdikk.sn
   - BRT: https://brt.sn / SunuBRT

3. **Alternative open data:**
   - Certains feeds GTFS statiques Dakar sont sur https://transport.data.gouv.fr ou Mobility Database
   - Mais GTFS-RT temps réel nécessite clé privée

---

## 🚀 Comment passer en LIVE quand tu as la clé (2 minutes)

### Étape 1: Teste ton endpoint
```bash
cd server
node test-cetud.js
```
Ce script teste tous les endpoints CETUD possibles avec et sans clé.

Si tu as une clé, mets-la dans `.env` puis re-teste.

### Étape 2: Configure .env
```bash
cd server
nano .env
```

Mets:
```env
USE_MOCK=false
CETUD_API_KEY=ta_clé_ici_123456
CETUD_API_KEY_HEADER=X-API-Key
# ou si CETUD te dit "Bearer":
# CETUD_API_KEY_HEADER=Authorization
# CETUD_API_KEY=Bearer ta_clé

CETUD_VEHICLE_POSITIONS_URL=https://api.cetud.sn/gtfs-rt/vehiclePositions
CETUD_TRIP_UPDATES_URL=https://api.cetud.sn/gtfs-rt/tripUpdates
CETUD_ALERTS_URL=https://api.cetud.sn/gtfs-rt/alerts
```

### Étape 3: Redémarre
```bash
npm start
# ou si tu utilises le process manager:
# le serveur redémarre auto
```

Vérifie:
```bash
curl http://localhost:8000/api/health | jq
# doit afficher "mode": "LIVE_CETUD" et "hasCetudKey": true
```

Frontend bascule auto en **"GTFS-RT LIVE CETUD"** (badge vert).

---

## 📡 Endpoints du proxy

| URL | Ce que ça fait | Format |
|-----|---------------|--------|
| `/api/gtfs-rt/vehiclePositions` | Positions bus (protobuf → JSON) | GTFS-RT |
| `/api/gtfs-rt/tripUpdates` | Retards / ETA | GTFS-RT |
| `/api/gtfs-rt/alerts` | Alertes trafic | GTFS-RT |
| `/api/gtfs-rt` | Tout combiné | JSON |
| `/api/vehicles` | Version simple pour Leaflet `{lat,lng,speed}` | JSON simple |
| `/api/alerts` | Version simple alertes | JSON simple |
| `/api/stream/vehicles` | SSE live push (au lieu de polling 3s) | text/event-stream |
| `/api/health` | Status MOCK/LIVE | JSON |

### Exemples:

**Frontend (déjà branché):**
```js
// Polling 3s
fetch('/api/gtfs-rt/vehiclePositions')
  .then(r=>r.json())
  .then(data=> {
    data.entity.forEach(e=> {
      // e.vehicle.position.latitude
      // e.vehicle.position.longitude
      // e.vehicle.position.speed
    })
  })

// Ou SSE live
const es = new EventSource('/api/stream/vehicles');
es.onmessage = e => {
  const data = JSON.parse(e.data);
  // update map
}
```

**cURL:**
```bash
curl http://localhost:8000/api/vehicles | jq
# {
#   "vehicles": [
#     { "id": "BRT_01_veh_0", "lat": 14.78, "lng": -17.43, "speed": 10.8, "speedKmh": "38.9" }
#   ],
#   "count": 127
# }
```

---

## 🔧 Détails techniques protobuf

Le proxy gère:

1. **Requête** → ajoute clé API dans header `X-API-Key` ou `Authorization: Bearer`
2. **Réponse** → si `application/x-protobuf`, décode avec `gtfs-realtime-bindings`
   ```js
   const feed = GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(buffer);
   const json = FeedMessage.toObject(feed, { longs: Number, enums: String });
   ```
3. **Cache** → 30s en mémoire (NodeCache) + SW cache côté client
4. **Fallback** → si fetch échoue, génère mock Dakar réaliste (127 véhicules)

**Si ton endpoint CETUD renvoie du JSON déjà (pas protobuf):**
Le proxy détecte `content-type: application/json` et parse direct, pas besoin de protobuf.

**Si CETUD te donne un .proto custom:**
Mets le fichier `.proto` dans `server/gtfs/` et adapte `server.js` ligne `GtfsRealtimeBindings`.

---

## 📱 PWA + GTFS-RT ensemble

- Service Worker cache les réponses `/api/gtfs-rt/*` 30s
- Si offline, SW renvoie dernier cache + mock
- GPS fonctionne offline (watchPosition)
- Tuiles carte en cache 7 jours

Donc même sans réseau, l'app affiche dernière position bus + ta position GPS.

---

## 🚀 Déploiement

### Local (déjà fait):
```bash
cd server && npm start
# http://localhost:8000
```

### Vercel:
```json
// vercel.json
{
  "builds": [
    { "src": "server/server.js", "use": "@vercel/node" },
    { "src": "index.html", "use": "@vercel/static" }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "server/server.js" },
    { "src": "/(.*)", "dest": "/index.html" }
  ]
}
```
Mets tes variables d'env CETUD dans Vercel Dashboard.

### Railway / Render:
- Root: `/`
- Build: `cd server && npm install`
- Start: `cd server && npm start`
- Env: `CETUD_API_KEY`, `USE_MOCK=false`

---

## 📊 Actuellement

- ✅ Proxy Express opérationnel port 8000
- ✅ 127 véhicules mock Dakar (BRT 23, DDD 45, Car Rapide 34, TER 3, AFTU 22)
- ✅ Endpoints /api/* fonctionnels
- ✅ Frontend branché et polling 3s
- ✅ PWA offline ready
- ✅ Fix refresh #trajets conservé
- ⏳ Attente clé CETUD pour passer LIVE (optionnel, mock déjà réaliste)

Tu veux que je contacte CETUD pour toi ou que je cherche un feed GTFS-RT public Dakar alternatif ?
