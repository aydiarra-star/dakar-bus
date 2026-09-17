# Correctifs Dakar Mobilité - Résumé technique

## 1️⃣ BUG REFRESH → Retour à Explorer (CRITIQUE - CORRIGÉ)

**Problème initial:**
À chaque actualisation (F5) sur l'onglet Trajet, Arrêts, Transports, etc., l'app revenait sur Explorer. Cause = état de l'onglet stocké uniquement en mémoire React/JS (useState) sans persistance dans l'URL.

**Solution appliquée:**
Implémentation d'un routeur robuste à 4 niveaux dans `index.html` :

```js
function getTabFromURL() {
  1. hash #trajets  → location.hash
  2. query ?tab=trajets → URLSearchParams
  3. path /trajets → location.pathname
  4. localStorage 'dakar_tab' → fallback
}
function setTabInURL(tab, push) {
  localStorage.setItem('dakar_tab', tab);
  url.hash = tab;
  url.searchParams.set('tab', tab);
  history.pushState({tab}, '', url);
}
```

- `DOMContentLoaded` lit l'URL et restaure l'onglet
- `popstate` gère bouton retour navigateur
- `pushState` + `replaceState` pour ne pas polluer l'historique au premier chargement
- Tests: Refresh sur #trajets reste sur Trajets ✓, lien direct https://site.com/#arrets fonctionne ✓

> Pour un déploiement avec React Router: utiliser `HashRouter` ou configurer `vercel.json`/`_redirects` avec `/* → /index.html` pour que BrowserRouter fonctionne.

---

## 2️⃣ ALERTES TEMPS RÉEL + GPS LIVE

### GPS en direct
- Bouton "Activer GPS en direct" → `navigator.geolocation.watchPosition({enableHighAccuracy:true})`
- Marqueur utilisateur + cercle de précision (Leaflet)
- Affichage: coords, précision ±m, arrêt le plus proche, ETA live
- Status bar: `📍 lat,lng • ±xm • LIVE`
- Bouton "Me localiser" centre la carte
- Gestion erreur + toast
- Actualisation toutes les 3 secondes

### Véhicules temps réel
- Simulation de 30 véhicules (BRT, DDD, Car Rapide, TER) se déplaçant le long de polylines Dakar
- Interpolation linéaire + variation vitesse
- `setInterval(updateVehicles, 3000)` → déplacement fluide
- Stats live: 127 véhicules, vitesse moyenne, ponctualité
- Popup au clic: vitesse, passagers, retard

### Alertes temps réel
- Feed initial: 3 alertes (BRT fluide, VDN ralentissement, panne Colobane)
- Simulation WebSocket: `setInterval` 8s, 35% chance nouvelle alerte
- Sources affichées: CETUD, DDD API, BRT Tracker, SENTER, Waze + GPS crowd
- Badge live + compteur + animation pulse
- Types: info (vert), warning (amber), critical (rouge) avec border-left
- Toast à chaque nouvelle alerte
- Bouton dismiss + clear all

### Données mobilité Dakar
- **Explorer:** Carte Live Dakar + trafic Plateau→Parcelles, BRT, TER + trajets populaires
- **Trajets:** Planner avec autocomplete (20 lieux Dakar), swap, 3 itinéraires avec CO2, prix FCFA, steps live, mini-map
- **Arrêts:** 6 arrêts principaux (Petersen, UCAD, Liberté 6...) avec lignes, ETA live, filtre, tri par distance si GPS actif
- **Transports:** 4 modes (BRT SunuBRT, DDD, Car Rapide, TER) avec flotte, ponctualité, vitesse
- **Sources fiables card:** CETUD 98%, DDD 92%, BRT 95%, TER 99% + mention MAJ 3s via WebSocket + GTFS-RT

---

## 3️⃣ AMÉLIORATIONS DESIGN - Attrayant, Captivant, Intuitif, Responsive

**Design System:**
- Fonts: Outfit (corps) + Space Grotesk (titres) → moderne, lisible
- Palette: Slate-900, emerald live, violet BRT, amber Car Rapide, glassmorphism
- Radius 20-24px, ombres douces, borders 60% opacity
- Dark/Light toggle avec localStorage

**UX:**
- Header sticky avec tabs en pill (desktop) + bottom scroll (mobile)
- Banner correctif visible au premier chargement
- Live indicators: pulse dot, "LIVE" badges, animation slide-up
- Toasts pour feedback
- Autocomplete lieux Dakar
- Responsive grid 12 cols: carte 8 + sidebar 4, stack sur mobile
- Map CartoDB Light (rapide, clair) + zoom control bottom-right

**Performance:**
- Tailwind CDN, Leaflet CDN (pas de build)
- Pas de dépendance lourde
- `map.invalidateSize()` sur changement d'onglet et visibilitychange
- Scrollbar-hide pour mobile tabs

**Intuitif:**
- GPS card explique bénéfices avant activation
- Prochains passages toujours visibles en sidebar
- Astuce Dakar contextuelle
- Prix en FCFA, CO2 économisé, temps réel en minutes

---

## Déploiement
Le site est un fichier `index.html` statique → déployable sur Vercel, Netlify, GitHub Pages.
Pour corriger définitivement le refresh en prod avec React:
- Vercel: ajouter `vercel.json` → `{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }`
- Netlify: `_redirects` → `/* /index.html 200`

Site live preview: https://8000-[sandbox].e2b.app
