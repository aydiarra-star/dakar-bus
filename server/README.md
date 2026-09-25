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
| `GET /api/health` | Status + politique de données simulées + statuts du moteur | - |

Exemple :
```bash
curl http://localhost:8000/api/vehicles | jq
curl http://localhost:8000/api/gtfs-rt/vehiclePositions?nocache=1 | jq '.entity[0]'
```

## 🔄 Frontend

Depuis le 2026-09-25, **le frontend ne consomme plus ces endpoints pour afficher
des départs**. Il utilise le moteur commun :

```
engine/departure-engine.js  +  data/transit/departure-frequencies.json
        → SCHEDULED (horaire précis sourcé)
        → ESTIMATED (fenêtre issue d'une fréquence documentée)
        → REAL_TIME (uniquement une observation réelle horodatée)
        → UNKNOWN  (aucune donnée fiable)
```

Aucun flux GTFS-RT public (TER, BRT, DDD, AFTU, TATA) n'est disponible :
`/api/gtfs-rt/*` renvoie donc un refus explicite (`status: UNKNOWN`, 0 entité)
plutôt que des données inventées.

## 🧪 Mode simulé (développement local uniquement)

```bash
USE_MOCK=true ALLOW_SIMULATED_DATA=true NODE_ENV=development npm start
```

- Refusé **par défaut**, refusé **en production**, jamais présenté comme du
  temps réel (`_meta.simulated: true`, `_meta.status: 'SIMULATED'`).
- AVANT : l'absence de clé API suffisait à activer un flux « réaliste »
  (127 véhicules aléatoires, retards de -3 à +7 min, alertes inventées) servi
  comme un flux temps réel, y compris en production.
- Une fréquence, elle, n'est jamais transformée en temps réel : voir
  `engine/departure-engine.js` et `docs/AUDIT_MOTEUR_DEPARTS_2026-09-25.md`.

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

L'application reste utilisable : les départs TER et BRT sont **estimés** à partir
de fréquences documentées (fenêtre, jamais une heure précise), et les réseaux
sans fréquence publiée (DDD, AFTU, TATA) affichent « Information indisponible ».

Dès qu'un flux réel authentifié existe :

1. Renseigne l'URL et la clé ;
2. Vérifie que les observations portent `source`, `observedAt`, `lineId` et
   `vehicleId` (sinon elles sont refusées : `REAL_TIME` ne s'improvise pas) ;
3. Redéploie. Aucune donnée simulée ne sera servie à la place.

## 📄 Licence

MIT - Pour Dakar Mobilité
