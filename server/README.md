# Dakar Mobilité - Proxy GTFS-RT CETUD (Express + Protobuf)

Proxy qui convertit les flux GTFS-RT binaires (protobuf) de CETUD / DDD / BRT / TER en JSON pour le frontend PWA.

## 🚀 Installation rapide

```bash
cd server
npm install
cp .env.example .env
# Edite .env si tu as une clé CETUD
npm start
# → http://localhost:8000
```

Le serveur sert à la fois :
- Le frontend PWA (`/index.html`, `/manifest.json`, `/service-worker.js`)
- L'API GTFS-RT (`/api/gtfs-rt/*`)

## 🔑 Brancher CETUD (quand tu as la clé)

1. Obtiens ta clé sur https://cetud.sn ou contacte CETUD / Dakar Dem Dikk / SunuBRT
2. Dans `.env` :

```env
USE_MOCK=false
CETUD_API_KEY=ta_clé_ici
CETUD_API_KEY_HEADER=X-API-Key
# ou
# CETUD_API_KEY_HEADER=Authorization
# CETUD_API_KEY=Bearer ta_clé

CETUD_VEHICLE_POSITIONS_URL=https://api.cetud.sn/gtfs-rt/vehiclePositions
CETUD_TRIP_UPDATES_URL=https://api.cetud.sn/gtfs-rt/tripUpdates
CETUD_ALERTS_URL=https://api.cetud.sn/gtfs-rt/alerts
```

3. Redémarre : `npm start`
4. Teste : `curl http://localhost:8000/api/health` → doit afficher `mode: LIVE_CETUD`

### Formats supportés

Le proxy gère automatiquement :
- **Protobuf binaire** (`application/x-protobuf`) → décodé via `gtfs-realtime-bindings`
- **JSON** (`application/json` ou `?format=JSON`) → direct
- **Mock** si fetch échoue ou pas de clé → 127 véhicules Dakar réalistes

Headers gérés :
- `X-API-Key: xxx`
- `Authorization: Bearer xxx`
- `?key=xxx` (ajoute dans l'URL si besoin)

## 📡 Endpoints

| Endpoint | Description | Cache |
|----------|-------------|-------|
| `GET /api/gtfs-rt/vehiclePositions` | Positions véhicules GTFS-RT complet | 30s |
| `GET /api/gtfs-rt/tripUpdates` | Retards / ETA | 30s |
| `GET /api/gtfs-rt/alerts` | Alertes service | 30s |
| `GET /api/gtfs-rt` | Tout combiné | 30s |
| `GET /api/vehicles` | Format simple `{lat,lng,speed}` pour Leaflet | 30s |
| `GET /api/alerts` | Format simple alertes | 30s |
| `GET /api/stream/vehicles` | SSE live push (alternative polling) | live 3s |
| `GET /api/health` | Status + mode MOCK/LIVE | - |

Exemple :
```bash
curl http://localhost:8000/api/vehicles | jq
curl http://localhost:8000/api/gtfs-rt/vehiclePositions?nocache=1 | jq '.entity[0]'
```

## 🔄 Frontend déjà branché

Dans `index.html`, le client GTFS-RT fait :

```js
// Essaie d'abord vrai endpoint via proxy
fetch('/api/gtfs-rt/vehiclePositions')
  -> si 200 + protobuf -> décodé par proxy -> JSON
  -> si échec -> mock Dakar local

// Polling 3s
setInterval(fetchNow, 3000)

// SSE optionnel
new EventSource('/api/stream/vehicles')
```

Tu n'as rien à changer côté frontend.

## 🧪 Tester sans clé CETUD (mode MOCK)

Le mode mock génère :
- 127 véhicules (BRT 23, DDD 45, Car Rapide 34, TER 3, AFTU 22)
- Positions aléatoires autour de Dakar (14.69, -17.44)
- Vitesses 5-40 km/h, occupancy, congestion
- TripUpdates avec delays -3 à +7 min
- Alerts réalistes (panne Colobane, VDN, travaux Grand Yoff)

C'est ce qui tourne actuellement.

## 🐳 Docker (optionnel)

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --only=production
COPY server/ ./
COPY *.html *.json *.js ../
EXPOSE 8000
CMD ["node", "server.js"]
```

## 📦 Déploiement Vercel / Railway

Le proxy est compatible Vercel Serverless :

`vercel.json` :
```json
{
  "rewrites": [
    { "source": "/api/(.*)", "destination": "/server/server.js" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

Ou déploie sur Railway/Render avec `npm start`.

## ❓ Pas de clé CETUD ?

Pas grave, le mock est réaliste et le code est prêt pour le live. Dès que tu as la clé :

1. Mets `USE_MOCK=false`
2. Mets l'URL et la clé
3. Redéploie

Le frontend basculera automatiquement en LIVE (badge vert "GTFS-RT LIVE CETUD").

## 📄 Licence

MIT - Pour Dakar Mobilité
