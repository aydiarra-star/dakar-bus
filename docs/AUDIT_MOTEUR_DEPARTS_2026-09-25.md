# Audit read-only avant création du moteur commun de départs — 2026-09-25

Périmètre : TER, BRT, DDD, AFTU, TATA. Objet : « Quel transport puis-je prendre maintenant
et quand puis-je partir ? ».

**Statut de cette étape : lecture seule.** Aucun fichier n'a été modifié avant que cet audit
soit terminé. État du dépôt au moment de l'audit :

- branche `arena/01a0d6a5-dakar-bus`, arbre propre ;
- HEAD = `3fa5519` (merge de la PR #25, audit des données TER/BRT du 2026-09-24) ;
- aucun fichier suivi modifié, aucun fichier non suivi.

---

## 1. FICHIERS CONCERNÉS

| Fichier | Taille | Rôle réel aujourd'hui |
|---|---|---|
| `index.html` | 1 011 lignes | **Interface publiée** (PWA GitHub Pages). Carte Leaflet, 42 arrêts codés en dur, liste des arrêts, « Prochains passages », alertes, assistant IA. |
| `data/transit/reference-policy.json` | 1,4 ko | Référentiel de contrôle TER/BRT (13 gares, 23 stations, directions, seuil 100 m). Pas un jeu d'horaires. |
| `data/gtfs/*.txt` | 8 fichiers | GTFS **statique de contrôle** : 4 colonnes pour `stops.txt`, trajets `_003` orphelins, horaires synthétiques (06:00, 07:00, 12:00) déjà signalés comme non vérifiés. |
| `flutter-src/lib/main.dart` | 3 975 lignes | Application Flutter (projet « officiel » J9) : Explorer, Trajets, arrêts, GPS, assistant IA, cartes. |
| `flutter-src/lib/models/transport_network.dart` | 469 lignes | Modèle transport + provenance (`DataTrust`, `ProvenanceStatus`, `SourceType`, `ScheduleStatus`). |
| `flutter-src/lib/models/reliability.dart` | 87 lignes | Politique d'affichage : badges, « Horaire indisponible », garde-fou `guardRealtime`. |
| `flutter-src/lib/services/data_service.dart` | 161 lignes | Chargement de `dakar_network.json` + repli mémoire (fallback non sourcé). |
| `flutter-src/assets/data/dakar_network.json` | 159 ko | Référentiel unique : 5 opérateurs, 117 arrêts, 105 routes, `services_not_exposed` (B3, B4, TER AIBD). **Aucun horaire** (`schedule_status: UNKNOWN` partout). |
| `server/server.js` | 525 lignes | Proxy Express « GTFS-RT CETUD » + **générateur de données simulées** (`generateMockDakarGTFS`) actif par défaut. |
| `vercel.json` | — | Déploiement : `USE_MOCK: "true"` en production. |
| `api/index.js` | 3 lignes | Wrapper Vercel → `server/server.js`. |
| `scripts/lib/transit-validation.js` | 113 lignes | Validateur TER/BRT (gate « Real data release »), rouge par construction. |
| `tests/transit-validation.test.js` | 130 lignes | 24 tests du validateur (seule suite exécutable localement : `npm test`). |
| `.github/workflows/flutter-web-build.yml` | — | CI Flutter 3.24.5 : `pub get → analyze → test → build web`. Seul endroit où le Dart est vérifié. |
| `.github/workflows/transit-validation.yml` | — | Gate données TER/BRT (échec attendu, documenté). |
| `docs/AUDIT_DONNEES_2026-09-24.md` | 30 ko | Audit de provenance TER V2/V3 : 13 gares, KMF, Mbao, Yeumbeul, AIBD. Référence à ne pas contredire. |

## 2. ARCHITECTURE ACTUELLE

Deux applications cohabitent, avec **deux sources de vérité distinctes** :

```
                     ┌──────────────────────────────────────────────┐
   PWA publiée ──────│ index.html                                   │
   (GitHub Pages)    │  ALL_ARRETS (42 arrêts, JSON en dur)         │
                     │  + `next: ["2 min","7 min"]` ← FAUX DÉPARTS   │
                     │  + flotte animée `vehicles[]` ← FAUX VÉHICULES│
                     │  GTFSRTClient.generateMockGTFS()             │
                     └──────────────────────────────────────────────┘

   App Flutter ──────┐  flutter-src/assets/data/dakar_network.json
   (J9, build web)   │  5 opérateurs / 117 arrêts / 105 routes, 0 horaire
                     │  ScheduleStatus.UNKNOWN partout
                     └──────────────────────────────────────────────┘

   API Vercel ───────┐  server/server.js
                     │  generateMockDakarGTFS() : positions aléatoires,
                     │  retards aléatoires (-180 s … +420 s)  ← SIMULÉ
                     └──────────────────────────────────────────────┘
```

### 2.1 Modèles transport existants

- **JS (PWA)** : aucun modèle. `ALL_ARRETS` est un tableau d'objets littéraux avec
  `id`, `name`, `seq`, `dir`, `lines`, `distance`, `next`, `status`, `type`, `lat`, `lng`.
- **Dart (Flutter)** : `Operator`, `BusStop` (+ `Provenance`, `ProvenanceStatus`,
  `SourceType`, `placeId`, `coordinatesStatus`), `TransportRoute` (+ `scheduleStatus`,
  `countsTowardOfficialTotal`, `auditFlags`), `TransportNetwork`.
- **Déjà présent et réutilisable** : l'enum `ScheduleStatus { scheduled, realTime, estimated,
  unknown }` et `ScheduleStatusLabel` (`SCHEDULED`, `REAL_TIME`, `ESTIMATED`, `UNKNOWN`,
  libellé utilisateur « Horaire théorique / Temps réel / Estimation / Horaire indisponible »).
  **Les quatre statuts demandés existent donc déjà**, en Dart, avec les bons libellés.

### 2.2 DataProvider / DataService

- `flutter-src/lib/services/data_service.dart` : charge l'asset JSON, sinon repli mémoire
  (repli volontairement `UNVERIFIED`). Aucune notion de fréquence ni de période de service.
- PWA : pas de service. Les données sont dans `index.html`, et le « client GTFS-RT »
  (`GTFSRTClient`) ne fait **aucun appel réseau** : `fetchNow()` appelle `updateVehicles()`,
  qui déplace les marqueurs le long des polylignes.

### 2.3 Composant qui affiche les prochains départs

| Emplacement | État actuel |
|---|---|
| `index.html` ligne 290-291, `#next-arrivals` | Bloc « Prochains passages » avec badge **LIVE**… **jamais rempli** par le code. Le badge annonce du temps réel sans aucune donnée. |
| `index.html` `renderArrets()` | Affiche `a.next[0]`, c'est-à-dire une valeur **codée en dur par arrêt** (« 2 min », « 4 min », « 5 min ») identique pour tous les arrêts d'un même réseau. |
| `flutter-src/lib/main.dart` `Stop.  departureMinutesFromMidnight` (l. 699-786) | `scheduleStatusOf()` renvoie `UNKNOWN` si la liste est vide ; `nextDepartureLabel()` renvoie `null` → « Horaire indisponible ». Correct mais **sans fréquence** : aucune estimation possible. |
| `StopCard` (l. 2600-2650), `DualStopDetailPage` (l. 3900-3950) | Affichent « Horaire indisponible » / « Prochain départ programmé ». |
| `AssistantReplies.modeInfo` (l. 3449) | Termine par « Je ne dispose d'aucun horaire ni d'aucune fréquence vérifiés pour ce réseau. » |

### 2.4 Calculateur d'itinéraires

- PWA : `renderArrets()` / `focusStop()` seulement. **Aucun calculateur d'itinéraire** :
  les onglets existent (`#tab-trajets`, `#from-input`, `#to-input`, `#search-itinerary`),
  mais aucun code ne les câble à un moteur.
- Flutter : `RoutePlanner.plan()` (l. 1460-1555). Haversine + vitesse moyenne supposée
  (35 km/h TER-BRT, 20 km/h bus), `departureAfter(now)` → `null` sans horaire → statut
  `unknown` et « Horaire indisponible ». **Aucune heure inventée** (correctif du 2026-09-24).

### 2.5 Logique GPS actuelle

- Flutter : `GpsResolver` (l. 1698-1930) — décision pure et testable, `GpsState`
  (idle/loading/granted/denied/serviceDisabled/error/outOfCoverage), zone de service
  `DakarBounds`, message « Position GPS obtenue. », rayon 4 km / 30 arrêts. La position
  utilisateur sert à la carte, au tri « à proximité », aux distances et au routage.
  **`DataStatus.live` n'est jamais assigné** (l. 1711) : le GPS utilisateur ne crée
  aucun véhicule.
- PWA : bouton « Activer GPS » + `#gps-coords` (affichage de la position), utilisée pour
  « Ma position live ». **Mais** la même page anime une flotte fictive `vehicles[]`
  (6 BRT + 4 TER + 3 DDD) déplacée le long des tracés, avec « 127 véhicules actifs » et
  pastille « GTFS-RT LIVE ».

### 2.6 Fichiers de données existants

`data/gtfs/{agency,calendar,feed_info,routes,shapes,stop_times,stops,trips}.txt`,
`data/transit/reference-policy.json`,
`flutter-src/assets/data/dakar_network.json`,
et **aucun** fichier de fréquences / périodes de service / calendrier de jours fériés.

## 3. LOGIQUE ACTUELLE DES DÉPARTS

| Réseau | Ce qui est affiché aujourd'hui | Nature réelle |
|---|---|---|
| TER | « 4 min » (PWA, `next[0]`, les 13 gares ont la même valeur) | **Inventé** — valeur littérale en dur |
| BRT | « 2 min » (PWA, 23 stations) | **Inventé** — valeur littérale en dur |
| DDD / AFTU / TATA | « 5 min » (PWA, 6 pôles bus) | **Inventé** — valeur littérale en dur |
| TER/BRT/DDD/AFTU/TATA (Flutter) | « Horaire indisponible » | **Correct mais inexploitable** : plus aucune donnée de cadence |
| API `/api/gtfs-rt/*` | Positions + retards aléatoires, `USE_MOCK=true` en production | **Simulé** |

Aucune de ces trois branches ne correspond à trois sources distinctes : il n'existe
aujourd'hui **aucun** endroit où l'on distingue `SCHEDULED`, `ESTIMATED`, `REAL_TIME`
et `UNKNOWN` à l'affichage des départs.

## 4. SOURCES DE DONNÉES ACTUELLES

| Donnée | Source enregistrée | Statut |
|---|---|---|
| 13 gares TER (séquence, coordonnées) | SETER uMap 556411 / terdakar.sn, 2026-09-24 | CONFIRMED |
| 23 stations BRT B1, B2 corrigée | SunuBRT + communiqué 30/09/2024 | CONFIRMED (3 noms litigieux) |
| 15 routes DDD | 10 CONFLICTING (demdikk.sn), 2 UNVERIFIED | non exploitable comme horaire |
| 80 routes AFTU / 7 Tata | FIELD_OBSERVATION | UNVERIFIED |
| GTFS statique `data/gtfs/` | non tracé (séquences et horaires synthétiques) | NON VÉRIFIÉ |
| Prochains passages (PWA) | **aucune** | FAUX |
| GTFS-RT (API) | **aucune** | SIMULÉ |
| PassBI 08/2025 | tiers | HISTORICAL — interdit en production |
| KMF | — | UNKNOWN |
| Mbao | — | UNVERIFIED, distinct de KMF |
| Yeumbeul A/B | — | non départagé |
| AIBD | — | FUTURE, ne doit pas entrer dans le référentiel TER |

## 5. POINTS À MODIFIER (périmètre de cette étape)

1. **Créer le moteur commun** (nouveau fichier, partagé PWA + assistant + itinéraires).
2. **Créer le référentiel de fréquences documentées** (nouveau fichier de données, avec
   `source`, `sourceType`, `validFrom/validTo`, `dayTypes`, `serviceStart/End`) :
   - TER Dakar ↔ Diamniadio : documenté par l'exploitant SETER ;
   - BRT B1 et B2 : documentés par l'exploitant SunuBRT ;
   - DDD, AFTU, TATA : **aucune fréquence documentée → UNKNOWN** (ne rien inventer).
3. **PWA `index.html`** : supprimer les valeurs de départs codées en dur (`next: [...]`),
   rendre `#next-arrivals` et la liste des arrêts depuis le moteur, supprimer la flotte
   simulée (`vehicles[]`, `updateVehicles`, `setInterval`), remplacer les badges
   « LIVE / GTFS-RT LIVE / 127 véhicules actifs » par l'état réel (aucun flux public),
   faire répondre l'assistant IA via le même moteur. **Aucune restructuration visuelle.**
4. **API `server/server.js`** : ne plus servir de positions/retards simulés par défaut
   (`USE_MOCK` ne suffit plus ; drapeau explicite + refus en production).
5. **Tests** : les 18 tests demandés, plus les règles de non-régression.
6. **Miroir Dart** du moteur (modèle + service + tests) pour que les deux applications
   partagent les mêmes règles. `main.dart` **n'est pas modifié** (voir §6).

## 6. POINTS À NE PAS TOUCHER

- `flutter-src/assets/data/dakar_network.json` : 13 gares TER, KMF, Mbao, Yeumbeul,
  AIBD (`services_not_exposed`) — **aucune écriture**.
- `data/gtfs/*`, `data/transit/reference-policy.json`, `scripts/lib/transit-validation.js`,
  `tests/transit-validation.test.js`, workflow du gate TER/BRT : inchangés.
- `flutter-src/lib/main.dart` : **aucune modification**. Le fichier est la référence de
  l'interface ET de la non-régression ; il ne peut être ni compilé ni testé dans ce
  bac à sable (Flutter non installable), et son état actuel (« Horaire indisponible »,
  jamais d'heure inventée) reste honnête. Le branchement de l'UI Dart sur le moteur est
  un lot séparé, à faire avec `flutter analyze` + `flutter test` disponibles.
- `index.html` : structure HTML, styles, onglets, carte, polylignes, marqueurs d'arrêts,
  popups, thème, service worker. Seuls les **contenus de statut** changent.
- Aucun import de PassBI 2025, GeoJSON tiers, OSM comme officiel, horaire historique,
  donnée AIBD non confirmée. Aucun `stop_times` fabriqué à partir des fréquences.

## 7. Constat de synthèse (ce qui manque exactement)

1. Il n'existe **aucun objet commun** décrivant un départ attendu (le besoin
   `DepartureEstimate`).
2. Il n'existe **aucune donnée de cadence** : ni dans `dakar_network.json`, ni dans
   `data/gtfs/`, ni ailleurs. Le seul chiffre de fréquence du dépôt était celui du
   générateur supprimé le 2026-09-24 (fabriqué) — il ne peut pas servir de source.
3. L'ordre de confiance n'est appliqué nulle part : la PWA affiche du faux temps réel,
   l'app Flutter affiche un UNKNOWN honnête mais muet.
4. Le seul flux « temps réel » du dépôt est simulé et actif en production.
