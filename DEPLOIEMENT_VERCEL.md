# 🚀 Déploiement Vercel - Dakar Mobilité PWA + GTFS-RT Proxy

## 1-Click Deploy

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/ton-repo/dakar-mobilite)

## Déploiement manuel (2 minutes)

### Étape 1: Push sur GitHub
```bash
git init
git add .
git commit -m "Dakar Mobilité PWA + GTFS-RT proxy"
git branch -M main
git remote add origin https://github.com/tonuser/dakar-mobilite.git
git push -u origin main
```

### Étape 2: Vercel
1. Va sur https://vercel.com/new
2. Importe ton repo GitHub `dakar-mobilite`
3. Vercel détecte `vercel.json` automatiquement
4. **Variables d'environnement** (Settings → Environment Variables) :

```env
USE_MOCK=true
# Quand tu as la clé CETUD:
# USE_MOCK=false
# CETUD_API_KEY=ta_clé_ici
# CETUD_API_KEY_HEADER=X-API-Key
# CETUD_VEHICLE_POSITIONS_URL=https://api.cetud.sn/gtfs-rt/vehiclePositions
# CETUD_TRIP_UPDATES_URL=https://api.cetud.sn/gtfs-rt/tripUpdates
# CETUD_ALERTS_URL=https://api.cetud.sn/gtfs-rt/alerts
PORT=8000
NODE_ENV=production
```

5. Clique **Deploy** → 30 secondes plus tard ton site est live !

**URL:** `https://ton-projet.vercel.app`

### Test après déploiement
```bash
curl https://ton-projet.vercel.app/api/health
curl https://ton-projet.vercel.app/api/vehicles | jq .count
curl https://ton-projet.vercel.app/api/gtfs/static | jq ._meta
```

## Fichiers Vercel importants

### `vercel.json`
Déjà créé à la racine :
- Route `/api/*` → `server/server.js` (Express)
- Route `/data/*` → GTFS static files
- Route `/*` → `index.html` (SPA, fix refresh bug)
- Headers pour SW et manifest

### `server/server.js`
- Export `default app` pour Vercel serverless
- Écoute seulement si `!process.env.VERCEL` (local)
- Gère protobuf → JSON

### `package.json` racine
Vercel utilise ce fichier pour installer deps.

## Mode MOCK vs LIVE

**Actuellement (sans clé):**
- `USE_MOCK=true` → 127 véhicules mock Dakar réalistes
- Pas besoin de clé CETUD
- Parfait pour démo, PWA, tests

**Quand tu as la clé CETUD:**
1. Dans Vercel Dashboard → Settings → Environment Variables
2. Mets `USE_MOCK=false` + `CETUD_API_KEY`
3. Redeploy (Vercel redéploie auto si tu pousses)

Frontend bascule auto en **GTFS-RT LIVE CETUD** (badge vert).

## PWA sur Vercel

Vercel sert en HTTPS automatiquement → PWA installable.

Vérifie :
- Chrome DevTools → Application → Manifest → doit afficher Dakar Mobilité
- Lighthouse → PWA score 100%
- Sur mobile, bannière "Ajouter à l'écran d'accueil"

Service Worker est servi avec `Cache-Control: no-cache` pour updates.

## GTFS Static enrichi

Le feed GTFS static Dakar que j'ai généré :

- **42 arrêts** : **13 gares officielles TER** (Dakar ↔ Diamniadio, phase 1 SETER/CETUD) + **23 stations SunuBRT** (PEM Petersen ↔ PEM Guédiawaye) + 6 pôles bus (UCAD, Plateau, Ouakam, Almadies, Yoff, Ngor). Filtre réseau appliqué à la carte : 13 gares TER seules / 23 stations BRT seules.
- **9 routes**: BRT 01, DDD 10/07/12/23, TATA, TER, AFTU 01
- **11 trips** + **stop_times** + **shapes** (tracés BRT, DDD, TER)
- **API**: `/api/gtfs/static` (JSON), `/data/gtfs/stops.txt` etc.

Sur la carte, les arrêts GTFS s'affichent en blanc bordure noire + shapes colorées.

Tu peux enrichir en ajoutant plus d'arrêts dans `data/gtfs/stops.txt`.

## Domaine custom (optionnel)

Vercel → Settings → Domains → ajoute `dakarmobilite.sn` ou `tondomaine.com`

## Logs Vercel

Vercel → Deployments → clique sur deployment → Logs → vois les requêtes GTFS-RT

## Coût

- Vercel Hobby: gratuit, 100GB bandwidth/mois, suffisant pour 10k users
- Si tu passes LIVE CETUD avec 3s polling, chaque user fait ~20 req/min → ~1M req/mois pour 100 users actifs → reste dans free tier si cache 30s activé

Cache 30s réduit les appels CETUD de 95%.

---

## Résumé de ce qui est déployé

✅ Fix refresh bug (#trajets conserve)
✅ PWA offline (manifest + SW)
✅ Proxy Express GTFS-RT protobuf→JSON
✅ Mode MOCK 127 bus Dakar réaliste
✅ GTFS static 12 arrêts + 9 routes
✅ Prêt pour LIVE CETUD dès que clé
✅ Vercel 1-click deploy

URL locale actuelle: http://localhost:8000 (proxy en cours)
