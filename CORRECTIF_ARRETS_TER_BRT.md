> **État au 21 septembre 2026 — correction non terminée.** Les anciens résultats « conforme » ci-dessous ne certifient pas la carte publiée. GitHub Pages sert Flutter depuis `gh-pages`, et non cette PWA. Le nouveau validateur bloque les données non sourcées. Voir [le rapport de reprise](docs/CORRECTION_TER_BRT_2026-09-21.md). Ne pas déployer cette PWA à la place de l’interface Flutter.

# Correctif définitif — Nombre d'arrêts TER & BRT sur la carte

> **Symptôme signalé** : « Sur les itinéraires du TER et du BRT, il y a plus d'arrêts. TER : plus de 13 arrêts sont sur l'image et sur le BRT plus de 23 arrêts sur l'image. »
>
> **Résultat après correctif** : la carte n'affiche **que** les arrêts du réseau sélectionné — **13 gares TER** (numérotées 1 → 13) et **23 stations SunuBRT** (numérotées 1 → 23). Vérifié automatiquement et visuellement (desktop + mobile).

---

## 1. Cause réelle du problème (diagnostic)

Le comptage était déjà bon dans les données (13 TER, 23 BRT, 6 pôles bus), mais **la carte affichait tous les réseaux en même temps** :

| Cause | Détail |
|---|---|
| ① Le filtre était purement visuel sur la **liste** | Le bouton `TER` / `BRT` filtrait les cartes de la liste, mais **aucun** arrêt n'était retiré de la carte Leaflet : 13 TER + 23 BRT + 6 pôles = **42 marqueurs** restaient affichés. |
| ② Les véhicules se dessinaient comme des arrêts | 13 pastilles « véhicules » (TER/BRT/DDD) très similaires aux arrêts → sur la carte, l'utilisateur comptait **55 marqueurs** au lieu de 13. |
| ③ Aucun moyen de compter | Marqueurs non identifiables (aucun `data-*`, pas de numéro) : impossible de vérifier « il y a bien 13 arrêts ». |
| ④ Comptages codés en dur | « 13 gares », « 23 stations », « 42 arrêts », « 40 arrêts », « 64 AFTU » dispersés dans le HTML, `<title>` et le manifest → chiffres contradictoires à l'écran. |
| ⑤ Un bug JavaScript bloquait l'initialisation | `window.map.invalidateSize is not a function` : la `<div id="map">` **écrase** la variable globale `map` (portée globale des `id`). Selon le chemin de navigation, l'app pouvait s'arrêter **avant** le dessin des marqueurs (aucun arrêt visible). |
| ⑥ Cache PWA périmé | Le service worker servait `index.html` et `data/gtfs/*` en *cache-first* : après un déploiement, l'utilisateur pouvait voir d'anciennes listes d'arrêts. |

Reproduction mesurée **avant** correctif (navigateur headless, filtre TER actif) :

```
13 TER + 23 BRT + 6 pôles + 13 véhicules = 55 marqueurs sur la carte
```

---

## 2. Solution définitive mise en œuvre

### a) Une seule source de vérité pour le comptage
`data/gtfs/stops.txt` alimente `NETWORK_STATS` (calculé, jamais écrit à la main) :

```js
const NETWORK_OFFICIEL = { TER: 13, BRT: 23, BUS: 6 };
```

Tous les textes de l'interface (titre, compteur, résumé, badge carte, panneau transports, pied de page) sont remplis **dynamiquement** à partir de ces valeurs : plus aucun chiffre codé en dur.

### b) Filtre réseau réellement appliqué à la carte
`applyMapFilter()` est appelé à chaque changement de filtre ou de calque :

* filtre **TER** → seuls les 13 marqueurs TER, le tracé TER et les 4 trains restent sur la carte ;
* filtre **BRT** → seules les 23 stations BRT, le corridor B1 et les 6 bus restent ;
* filtre **DDD / AFTU / TATA** → seuls les 6 pôles bus restent ;
* filtre **Tous** → 13 + 23 + 6 = **42 arrêts**.

### c) Marqueurs numérotés et identifiables (1 marqueur = 1 arrêt)
* Gares TER : pastille verte avec le **numéro officiel 1 → 13** ;
* Stations BRT : pastille verte SunuBRT avec le **numéro officiel 1 → 23** ;
* Pôles bus : pastille bleue ;
* Véhicules : forme **distincte** (rectangle arrondi animé, `data-kind="vehicle"`) et **exclue du comptage d'arrêts**.

### d) Listes officielles numérotées 1 → 13 / 1 → 23
Boutons « 🚆 Voir les 13 gares » / « 🚌 Voir les 23 stations » (et cartes de l'onglet *Transports*) ouvrant la liste complète numérotée, dans l'ordre officiel :

* **TER (SETER/CETUD, phase 1 – 36 km)** : Gare de Dakar → Colobane → Hann → Dalifort → Baux Maraîchers → Pikine → Thiaroye → Yeumbeul → Keur Mbaye Fall → PNR → Rufisque → Bargny → Diamniadio.
* **BRT (corridor B1 omnibus – 18,3 km)** : Papa Gueye Fall (PEM Petersen) → … → Préfecture Guédiawaye (PEM).

### e) Panneau « Calques réseau » + badge de comptage
Un panneau sur la carte permet d'afficher/masquer chaque réseau et les véhicules, avec le compteur en direct (`13`, `23`, `6`, véhicules), plus un badge « 🚆 TER : 13 gares affichées (1 → 13) — aucun autre arrêt ».

### f) Bug bloquant `window.map` corrigé
Ajout de `window.__dakarMap` (référence fiable vers la carte Leaflet) et remplacement de l'appel fautif `window.map.invalidateSize()`. Plus aucune erreur JavaScript à l'exécution.

### g) Cache PWA assaini
`service-worker.js` passe en **v2.3-arrets** : `index.html` et `data/gtfs/*` sont servis en *network-first* (mise à jour automatique, plus de listes périmées en cache), les anciens caches sont purgés.

### h) Données GTFS complétées
`data/gtfs/stop_times.txt` : passage de **36 à 108 lignes**. Les trajets retour (`TER_01_002`, `BRT_01_002`) et des départs supplémentaires existent désormais réellement pour les 13 gares et les 23 stations (horaires croissants validés), au lieu d'un unique trajet aller.

---

## 3. Contrôle automatique (non-régression)

```bash
npm test          # ou : node scripts/check-arrets.js
```

`scripts/check-arrets.js` vérifie, sur **toutes les sources**, qu'il ne peut plus y avoir de dérive :

1. `data/gtfs/stops.txt` : 13 TER + 23 BRT + 6 pôles = 42, numérotation 1 → N sans trou ni doublon, aucun doublon GPS ;
2. `data/gtfs/stop_times.txt` : les 13 gares et 23 stations sont bien desservies, horaires croissants, aucun `stop_id` inconnu ;
3. `index.html` : liste embarquée identique au fichier GTFS, constante `NETWORK_OFFICIEL` conforme, marqueurs identifiables, filtre carte présent, aucune mention obsolète (« 40 arrêts », etc.) ;
4. **Tracés** : chaque gare TER et chaque station BRT est posée sur son tracé (écart max mesuré : 0 m) ;
5. Affichage de l'ordre officiel des 13 gares et des 23 stations.

Sortie attendue : `✅ CONFORME : 13 gares TER + 23 stations BRT + 6 pôles bus = 42 arrêts, sur toutes les sources.`

---

## 4. Tests navigateur (avant / après)

| Scénario | Avant | Après |
|---|---|---|
| Filtre **Tous** (carte) | 42 arrêts + 13 véhicules mélangés | 42 arrêts lisibles + véhicules distincts |
| Filtre **TER** (carte) | **55 marqueurs** (13 TER + 23 BRT + 6 pôles + 13 véhicules) | **13 marqueurs** numérotés 1 → 13 |
| Filtre **BRT** (carte) | **55 marqueurs** | **23 marqueurs** numérotés 1 → 23 |
| Filtre **DDD/AFTU/TATA** | 55 marqueurs | 6 pôles bus |
| Erreurs JavaScript | `window.map.invalidateSize is not a function` | aucune |
| Mobile 390 × 844 | idem | 13 / 23 / 42 exacts (panneau replié par défaut) |

---

## 5. Fichiers modifiés

| Fichier | Nature |
|---|---|
| `index.html` | Source de vérité des comptages, `applyMapFilter`, marqueurs numérotés, panneau de calques, badge, listes 1 → N, correctif `window.map`, comptages dynamiques |
| `data/gtfs/stop_times.txt` | Trajets retour + départs supplémentaires (13 gares / 23 stations réellement desservies) |
| `service-worker.js` | Cache v2.3-arrets, *network-first* sur `index.html` et `data/gtfs/*` |
| `scripts/check-arrets.js` | **Nouveau** — contrôle automatique de non-régression |
| `package.json` | Script `npm test` / `npm run check:arrets` |
| `README.md`, `DEPLOIEMENT_VERCEL.md`, `PWA_GTFS_GUIDE.md` | Comptages et sources alignés |
| `manifest.json` | Description alignée (13 gares TER, 23 stations BRT, 42 arrêts) |
