# GROUPE 9 — AUDIT DATA TRUST / STATUT DES HORAIRES / FIABILITÉ AFFICHÉE

**Phase : AUDIT UNIQUEMENT.** Aucun fichier `lib/`, `test/`, JSON, interface, texte utilisateur,
horaire, logique, statut, badge, workflow n'a été modifié. Aucun déploiement.
Le seul artefact produit est ce document.

Référence : HEAD `79a49fc` (rapport Groupe 8). Complémentaire — pas redondant — de
`docs/dakar-bus/groupe-8/AUDIT_HORAIRES_DEPARTS.md`, qui auditait la **chaîne de calcul** ;
celui-ci audite la **chaîne de fiabilité**.

> **Méthode.** Aucune déduction : chaque affirmation renvoie à un fichier, une ligne, une valeur
> de donnée ou un objet Git vérifié. Trois sources de preuve sont utilisées et **strictement
> séparées** en section K : le code (`lib/`, `test/`), les données (`dakar_network.json`), et Git
> (20 commits locaux **plus** le commit récupéré `2c72e576`, source pré-force-push accessible via
> l'API GitHub). Le binaire de production gh-pages `94a84b60` est utilisé en contre-épreuve.

---

## A — Résumé exécutif

Dakar Bus possède **deux** vocabulaires de fiabilité, et **aucun des deux** n'atteint l'horaire affiché.

1. **`DataTrust`** (`lib/models/transport_network.dart:5`) — `official` / `fieldObservation` /
   `estimated`. Il est **réellement porté par la source unique** : 117 arrêts et 105 lignes du JSON
   ont un `data_trust`. Il est correctement **parsé** dans `BusStop` et `TransportRoute`. Puis il
   **disparaît** : `lib/main.dart` ne le lit **jamais** (0 lecture ; 3 mentions, toutes en
   commentaire), et le modèle d'affichage `Stop` ne possède **aucun champ** pour le recevoir.
2. **`DataSourceInfo`** (`lib/main.dart:290-299`) — 6 constantes avec `origin`, `label`,
   `badgeEmoji`. Attribuées **exclusivement** d'après `operatorId` (L925-933), jamais d'après
   `data_trust`. `origin` n'est **jamais lu** (0 comparaison), `label` n'est **jamais affiché** ;
   seul `badgeEmoji` l'est, à **un unique endroit** (L2161).
3. **`DataStatus`** (`lib/main.dart:719`) — `scheduled` / `live` / `unknown`. **Jamais lu** dans
   tout `lib/`. Seule `scheduled` est assignée (6 fois). `live` et `unknown` sont mortes, et
   `realTime` n'existe pas. Git prouve qu'il en était **déjà ainsi** dans la source pré-force-push.

Conséquence mesurable : **18 arrêts `FIELD_OBSERVATION`** (tous DDD) s'affichent avec le badge 🟢
« officiel », et **44 autres** (37 AFTU, 7 Tata) avec 🔵. Pendant ce temps l'assistant énonce des
heures absolues — « 🕒 15 h 10 → 15 h 55 » — issues d'une suite arithmétique, sans qualificatif.

**Aucun timestamp n'existe dans le modèle** : la fraîcheur d'une donnée ne peut pas être
représentée, encore moins affichée. **Aucune API horaire** n'est appelée : les deux seuls endpoints
sont OSRM (géométrie d'itinéraire) et les tuiles OpenStreetMap.

Le mot **« inconnu »** compte **8 occurrences** dans `lib/`, **toutes en commentaires** : il n'est
jamais montré à l'utilisateur. Quand un horaire n'est pas connu, l'application affiche
**« Bientôt »** ou **« Prochainement »** — formulations positives.

**30 anomalies** `G9-H01`…`G9-H30` : 6 🔴, 11 🟠, 9 🟡, 4 🟢.

---

## B — Architecture réelle : source → modèle → horaire → départ → affichage

### B.1 La chaîne telle qu'elle est implémentée

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 1. SOURCE                                                                     │
│    assets/data/dakar_network.json   md5 81c778f4644dcf5e1cf4ae25879218f0     │
│    3 clés : operators(5) · stops(117) · routes(105)                           │
│    ✅ data_trust PRÉSENT sur stops et routes   ❌ AUCUN champ horaire         │
└──────────────────────────────────────────────────────────────────────────────┘
                                   ↓  rootBundle.loadString + json.decode
┌──────────────────────────────────────────────────────────────────────────────┐
│ 2. PARSER   lib/models/transport_network.dart                                 │
│    DataTrustExtension.fromString(json['data_trust'])        L19-28            │
│    BusStop.fromJson          L73-81   → .dataTrust  ✅ CONSERVÉ               │
│    TransportRoute.fromJson   L112-121 → .dataTrust  ✅ CONSERVÉ               │
└──────────────────────────────────────────────────────────────────────────────┘
                                   ↓  DataService.loadNetworkData()  (data_service.dart L22-38)
┌──────────────────────────────────────────────────────────────────────────────┐
│ 3. SERVICE   lib/services/data_service.dart                                   │
│    appDataService = DataService()                     main.dart L16           │
│    .stops : List<BusStop>       ✅ dataTrust accessible                       │
│    .routes: List<TransportRoute>✅ dataTrust accessible                       │
│    ⚠️ fallback _loadFallbackData() L40-142 : 6 arrêts + 5 lignes codés en dur │
└──────────────────────────────────────────────────────────────────────────────┘
                                   ↓  _integrateNetworkData()   main.dart L886-1010
┌──────────────────────────────────────────────────────────────────────────────┐
│ 4. 🔴 POINT DE RUPTURE   main.dart L968-982                                   │
│    Stop( name: busStop.name,              ← LU                                │
│          stopId: busStop.id,              ← LU                                │
│          location: LatLng(busStop.lat, busStop.lon),  ← LU                    │
│          color / icon / modeLabel / source: ← dérivés de route.operatorId     │
│          direction:                       ← SYNTHÉTISÉE depuis stopIds.last   │
│          departureMinutesFromMidnight:    ← SYNTHÉTISÉE (_shift)              │
│          distanceMeters: 300 + i*800      ← SYNTHÉTISÉE                       │
│          status: (défaut) DataStatus.scheduled                                │
│        )                                                                      │
│    ❌ busStop.dataTrust   JAMAIS LU                                           │
│    ❌ route.dataTrust     JAMAIS LU                                           │
│    ❌ la classe Stop n'a AUCUN champ dataTrust (12 champs, L628-643)          │
└──────────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│ 5. MODÈLE UI   class Stop   main.dart L628-716                                │
│    12 champs : name, direction, distanceMeters,                               │
│      departureMinutesFromMidnight, icon, color, location, status,             │
│      modeLabel, source, stopType, stopId                                      │
│    → source : DataSourceInfo (6 constantes, choisie par operatorId)           │
│    → status : DataStatus.scheduled (jamais lu)                                │
│    → dataTrust : ❌ N'EXISTE PAS                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│ 6. AFFICHAGE                                                                  │
│    StopCard L2161        → badgeEmoji 🟢/🔵/🟡   ✅ SEUL marqueur visible     │
│    StopCard L2116-2125   → badge d'attente (Fermé/Bientôt/Imminent/N min)     │
│    SingleStopView L3272  → « Prochain départ » + nextDepartureLabel()         │
│    SingleStopView L3278  → « Affluence » + getCrowdLevel()                    │
│    AIChatPage L2884      → « 🕒 15 h 10 → 15 h 55 »                           │
│    DetailedRoutePage L3107 → « Heure : ~N min »                               │
│    AlertsPage L2422/2461/2471 → badges texte statiques                        │
│    ❌ source.label  JAMAIS AFFICHÉ   ❌ source.origin JAMAIS LU               │
│    ❌ dataTrust     JAMAIS AFFICHÉ   ❌ status        JAMAIS AFFICHÉ          │
└──────────────────────────────────────────────────────────────────────────────┘
```

### B.2 Réponse à la question centrale : **où la fiabilité disparaît-elle ?**

> **À l'étape 4, `lib/main.dart:968-982`, dans `_integrateNetworkData()`.**

Ce n'est pas un oubli ponctuel mais une **impossibilité structurelle** : la classe `Stop`
(L628-643) ne déclare **aucun** champ de confiance. Même si L968-982 voulait transmettre
`busStop.dataTrust`, il n'existerait **nulle part où le stocker**. La rupture est donc double :

| Niveau | État | Preuve |
|---|---|---|
| JSON | ✅ présent | 117 `data_trust` sur stops, 105 sur routes |
| Parser | ✅ conservé | `transport_network.dart:79`, `:118` |
| Service | ✅ accessible | `appDataService.stops[i].dataTrust` |
| **Conversion `BusStop` → `Stop`** | 🔴 **PERDU** | `main.dart:968-982` ne le lit pas |
| **Modèle UI `Stop`** | 🔴 **INEXISTANT** | 12 champs, aucun `dataTrust` |
| Horaire / départ / attente | ❌ jamais qualifié | §D, §F |
| UI | ⚠️ substitut indirect | 1 émoji dérivé d'`operatorId`, L2161 |

**La donnée de confiance n'est pas « dégradée » : elle est intégralement présente jusqu'au service,
puis intégralement absente du modèle d'affichage.** Il n'existe aucun état intermédiaire.

### B.3 Le substitut : d'où vient réellement le badge affiché

```
route.operatorId  ──→  sourceForOperator(opId)   main.dart L925-933
   'ter'   → DataSourceInfo.seter          🟢  origin: official
   'brt'   → DataSourceInfo.sunubrt        🟢  origin: official
   'ddd'   → DataSourceInfo.demdikk        🟢  origin: official
   'aftu'  → DataSourceInfo.aftuOfficial   🔵  origin: verified
   'tata'  → DataSourceInfo.tataOfficial   🔵  origin: verified
   autre   → DataSourceInfo.demo           🟡  origin: indicative
                                    ↓
                        stop.source.badgeEmoji   →   affiché L2161
```

Le badge ne dépend que d'**une seule entrée : l'identifiant texte de l'opérateur**. Ni la confiance
de l'arrêt, ni celle de la ligne, ni l'existence d'un horaire, ni sa fraîcheur n'interviennent.

---

## C — `DataTrust` : inventaire complet

### C.1 Déclaration et extension

| Élément | Fichier:ligne | Contenu |
|---|---|---|
| Enum | `lib/models/transport_network.dart:5` | `enum DataTrust { official, fieldObservation, estimated }` |
| Extension | `:7` | `extension DataTrustExtension on DataTrust` |
| `toLabel()` | `:8-17` | `official`→`'OFFICIAL'`, `fieldObservation`→`'FIELD_OBSERVATION'`, `estimated`→`'ESTIMATED'` |
| `fromString()` | `:19-28` | `'OFFICIAL'`→`official`, `'FIELD_OBSERVATION'`→`fieldObservation`, **`default:`→`estimated`** |
| Doc | `:4` | `/// Niveau de fiabilité de la donnée - Aligné avec CETUD/SETER` |

> ⚠️ `fromString` a une branche **`default:`** : toute valeur absente ou non reconnue devient
> silencieusement `estimated`. Aucun journal, aucune exception. Le JSON actuel ne contient que
> `OFFICIAL` et `FIELD_OBSERVATION`, donc cette branche n'est **jamais empruntée** aujourd'hui.

### C.2 Porteurs du champ

| Classe | Champ | Constructeur | `fromJson` | `toJson` |
|---|---|---|---|---|
| `BusStop` | `:63` | `:70` (`required`) | `:79` | `:88` |
| `TransportRoute` | `:98` | `:107` (`required`) | `:118` | `:129` |
| `Operator` | ❌ **aucun** | — | `:40-48` (pas de `data_trust`) | `:51` |

### C.3 Tous les constructeurs / affectations de `DataTrust`

| # | Fichier:ligne | Valeur | Contexte |
|---|---|---|---|
| 1 | `transport_network.dart:79` | `fromString(json['data_trust'])` | `BusStop.fromJson` — **seul chemin réel** |
| 2 | `transport_network.dart:118` | `fromString(json['data_trust'])` | `TransportRoute.fromJson` — **seul chemin réel** |
| 3 | `data_service.dart:56` | `DataTrust.official` | fallback, arrêt `stop_petersen` |
| 4 | `data_service.dart:62` | `DataTrust.fieldObservation` | fallback, `stop_parcelles_u26` |
| 5 | `data_service.dart:68` | `DataTrust.official` | fallback, `stop_guediawaye` |
| 6 | `data_service.dart:74` | `DataTrust.fieldObservation` | fallback, `stop_palais` |
| 7 | `data_service.dart:80` | `DataTrust.official` | fallback, `stop_yoff` |
| 8 | `data_service.dart:86` | `DataTrust.official` | fallback, `stop_sandaga` |
| 9 | `data_service.dart:96` | `DataTrust.official` | fallback, ligne `brt_1` |
| 10 | `data_service.dart:105` | `DataTrust.fieldObservation` | fallback, ligne `aftu_12` |
| 11 | `data_service.dart:114` | `DataTrust.official` | fallback, ligne `ddd_8` |
| 12 | `data_service.dart:123` | `DataTrust.fieldObservation` | fallback, ligne `line_tata_219` |
| 13 | `data_service.dart:132` | `DataTrust.official` | fallback, ligne `line_brt_b1` |
| 14-16 | `transport_network.dart:22, 24, 26` | `official` / `fieldObservation` / `estimated` | `fromString` |

**Affectations dans `lib/main.dart` : 0.** `DataTrust` n'y apparaît **que** dans l'`import` (L10)
et dans 3 commentaires (L830, L2453-2454, L3152).

### C.4 Toutes les lectures de `DataTrust`

| Fichier | Lectures réelles (`x.dataTrust` hors déclaration) |
|---|---|
| `lib/main.dart` | **0** |
| `lib/services/data_service.dart` | **0** |
| `lib/models/transport_network.dart` | **2** : `:88` et `:129`, dans `toJson()` |

Et **`toJson()` n'est appelé nulle part dans `lib/`** : les 3 méthodes `toJson`
(`transport_network.dart:51, 83, 123`) ont **0 site d'appel**. Les 2 seules lectures de
`.dataTrust` sont donc **inatteignables à l'exécution** — seule la suite de tests les exerce.

> **`DataTrust` est intégralement write-only dans l'application en fonctionnement.**

### C.5 Table exigée : valeur × existe × produite × utilisée × affichée × testée

| Valeur | Existe | Produite | Utilisée | Affichée | Testée |
|---|---|---|---|---|---|
| **`official`** | ✅ `:5` | ✅ `fromString('OFFICIAL')` `:22` · 4 arrêts + 3 lignes du fallback · **55 arrêts + 14 lignes du JSON** | ❌ **jamais lue** dans `lib/main.dart` | ❌ **jamais** | ✅ 5 tests (voir §I) |
| **`fieldObservation`** | ✅ `:5` | ✅ `fromString('FIELD_OBSERVATION')` `:24` · 2 arrêts + 2 lignes du fallback · **62 arrêts + 91 lignes du JSON** | ❌ **jamais lue** | ❌ **jamais** | ✅ 2 tests |
| **`estimated`** | ✅ `:5` | ⚠️ **uniquement** par `fromString` `default:` `:26` — **0 occurrence de `ESTIMATED` dans le JSON** → **jamais produite par les données** | ❌ **jamais lue** | ❌ **jamais** | ⚠️ partiel : `toLabel` `:16` + 1 disjonction (`network_data_test:303`) |

### C.6 Tous les endroits où l'information est perdue ou ignorée

| # | Emplacement | Nature de la perte |
|---|---|---|
| P1 | `main.dart:968-982` | 🔴 `BusStop.dataTrust` non transmis à `Stop` |
| P2 | `main.dart:628-643` | 🔴 `class Stop` n'a **aucun** champ de confiance |
| P3 | `main.dart:942-954` | 🔴 `TransportRoute.dataTrust` non lu ; `source` vient d'`operatorId` |
| P4 | `main.dart:925-933` | 🔴 `sourceForOperator` ignore toute confiance |
| P5 | `main.dart:2161` | 🟠 seul `badgeEmoji` rendu ; `label` (texte explicite) jamais |
| P6 | `main.dart:289` | 🟠 `DataOrigin` jamais comparé (0 `origin ==`) |
| P7 | `transport_network.dart:88, 129` | 🟡 lectures dans `toJson`, **0 appel** |
| P8 | `Operator` `:30-54` | 🟡 aucun `data_trust` sur les opérateurs (ni dans le JSON) |
| P9 | `main.dart:631, 719` | 🔴 `DataStatus` présent mais jamais lu (§D) |

---

## D — `DataStatus` : inventaire complet

### D.1 Déclaration

```dart
// lib/main.dart:719
enum DataStatus { scheduled, live, unknown }
```

> **`realTime` n'existe pas.** Le triplet produit « SCHEDULED / REAL_TIME / UNKNOWN » se traduit
> ici par `scheduled` / `live` / `unknown`. La chaîne `REAL_TIME` apparaît **3 fois** dans `lib/`,
> **uniquement en commentaires d'interdiction** (L1340, L1371, L2455).

### D.2 Porteurs

| Classe | Champ | Défaut | `copyWith` |
|---|---|---|---|
| `Stop` | `:631` | `:647` `= DataStatus.scheduled` | `:655` |
| `RouteSegment` | `:731` | `:732` `= DataStatus.scheduled` | — |
| `PlannedRoute` | `:737` | `:738` `= DataStatus.scheduled` | — |

### D.3 Toutes les affectations — **6, toutes `scheduled`**

| Ligne | Objet |
|---|---|
| `647` | `Stop` (défaut) |
| `732` | `RouteSegment` (défaut) |
| `738` | `PlannedRoute` (défaut) |
| `1156` | `PlannedRoute` dans `_buildRoute` |
| `1157` | `RouteSegment` dans `_buildRoute` |
| `1173` | `PlannedRoute` dans `_findTransfer` |

`DataStatus.live` : **0 affectation**. `DataStatus.unknown` : **0 affectation, 0 référence** dans
`lib/` comme dans `test/` en tant que valeur.

### D.4 Toutes les lectures — **aucune**

Recherche exhaustive de `.status`, `status ==`, `status !=`, `switch (…status`, `case DataStatus` :

| Ligne | Nature |
|---|---|
| `140` | `response.statusCode == 200` — HTTP, sans rapport |
| `631, 731, 737` | **déclarations** |
| `655, 665` | plumbing `copyWith` |
| `647, 732, 738, 1156, 1157, 1173` | **écritures** |
| `1341, 2447, 2562, 2669` | **commentaires** |
| `367, 3043, 3054` | ⚠️ **homonyme** : `DetailedRoute.origin` / `.destination` sont des **noms de lieux**, sans rapport avec `DataOrigin` |

**Il n'existe aucune condition, aucun `switch`, aucun badge, aucun texte, aucune couleur dépendant
de `DataStatus`.**

### D.5 Table exigée : valeur × état réel

| Valeur | Définition | Instanciation | Assignation | Lecture | Affichage | Tests | Chemin d'exécution réel | Verdict |
|---|---|---|---|---|---|---|---|---|
| **`scheduled`** | `:719` | ✅ `B.a2 = new A.a2U(0,"scheduled")` en production | ✅ **6 fois** | ❌ **0** | ❌ **0** | ⚠️ forme seulement | valeur posée, jamais consultée | 🟠 **réellement assignée, fonctionnellement morte** |
| **`live`** | `:719` | ❌ **éliminée par tree-shaking** : `"live"` = **0 occurrence** dans les 2 497 533 octets du binaire | ❌ **0** | ❌ **0** | ❌ **0** | ✅ mais **pour vérifier son absence** (`gps_position_test:537`) | aucun | 🔴 **morte — seulement déclarée et gardée** |
| **`unknown`** | `:719` | ❌ éliminée (6 occurrences de `"unknown"` dans le binaire, **toutes sans rapport**) | ❌ **0** | ❌ **0** | ❌ **0** | ⚠️ **1 seule**, dans la liste des noms attendus (`:512`) | aucun | 🔴 **morte — seulement déclarée** |

**Tree-shaking comme preuve indépendante.** dart2js n'émet une constante d'enum que si elle est
référencée. Le binaire ne contient **qu'une** constante `DataStatus`. En comparaison, `DataTrust`
voit **ses trois valeurs matérialisées** (`A.zc(0,"official")`, `(1,"fieldObservation")`,
`(2,"estimated")`) parce que `fromString` les construit toutes. Le compilateur confirme donc,
indépendamment de l'analyse de source, que `live` et `unknown` sont du code mort — et que
`estimated`, bien que construit, ne sert à rien.

### D.6 Verrouillage par les tests

| Test | Fichier:ligne | Effet |
|---|---|---|
| `DataStatus conserve exactement 3 valeurs` | `gps_position_test.dart:509-513` | `hasLength(3)` + noms exacts `['scheduled','live','unknown']` |
| `GARDE-FOU SOURCE : DataStatus.live n'est assigné nulle part` | `:531-541` | scan textuel : `contains('DataStatus.live') == false` **et** `contains('enum DataStatus { scheduled, live, unknown }') == true` |
| `le resolver GPS n'expose AUCUN DataStatus` | `:515` | couture GPS |

**Toute évolution de l'enum casse 2 tests.** Aucun test ne vérifie en revanche que `unknown`
n'est jamais assigné — seul `live` est gardé.

---

## E — Horaires : provenance réelle par réseau

### E.1 Vérifications préalables

| Question | Réponse | Preuve |
|---|---|---|
| Horaires présents dans le JSON ? | ❌ **NON** | 3 clés racines, aucun champ `time`/`hour`/`minute`/`freq`/`headway`/`schedule`/`calendar`/`departure`/`interval`/`service`. Les 10 `time` et 3 `day` sont des sous-chaînes de noms (« Gare Mari**time** ») |
| Horaires présents dans une API ? | ❌ **NON — aucune API horaire** | **2 endpoints seulement** : `https://router.project-osrm.org/route/v1/driving/` (L134, **géométrie d'itinéraire**) et `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (L1919, L3070, **tuiles de carte**). Aucun autre `Uri.parse`, aucun autre `http.` |
| Timestamp / horodatage ? | ❌ **AUCUN** | `grep timestamp\|updatedAt\|lastUpdate\|horodat` sur `lib/` : 3 commentaires + le littéral `'Sans horodatage'` (L2574-2575, données de démonstration « Direct rue »). **Aucun champ d'horodatage dans aucun modèle** |
| Calcul dynamique ? | ❌ **NON** | `_terBase`/`_brtBase` sont des `final` top-level (L261-262), calculés **une fois** par session. Le seul paramètre variable est l'**index** `i` de l'arrêt dans sa ligne |
| Temps réel ? | ❌ **NON** | Aucun flux, aucune socket, aucun polling horaire. Le seul `Timer.periodic` (L1522, 15 s) ne fait que `setState` pour rafraîchir l'affichage |
| ETA réelle ? | ❌ **NON** | `dur = ceil(dist/1000/speed*60)` avec `speed` = **35** (TER/BRT) ou **20** km/h codé en dur (L1146). OSRM n'est utilisé que pour la **géométrie** des polylignes, jamais pour un temps |

### E.2 Tableau par réseau

| | **TER** | **BRT** | **AFTU** | **Tata** | **DDD** |
|---|---|---|---|---|---|
| Lignes dans le JSON | **1** | **2** (B1 23, B2 7) | **80** | **7** | **15** |
| Arrêts créés | 13 | 23 | 41 | 8 | 32 |
| **Source officielle identifiée ?** | ❌ non | ❌ non | ❌ non | ❌ non | ❌ non |
| **Horaires dans le JSON ?** | ❌ non | ❌ non | ❌ non | ❌ non | ❌ non |
| **Horaires dans une API ?** | ❌ non | ❌ non | ❌ non | ❌ non | ❌ non |
| **Horaires codés en dur ?** | ✅ `330`, `1320`, `10`, `20` (L260) | ✅ `360`, `1260`, `6` (L261) | ✅ `5` (L685, 696) | ✅ `5` | ✅ `5` |
| **Horaires synthétiques ?** | ✅ 100 % — 100 départs (50 le dimanche) | ✅ 100 % — 151 départs | ✅ 100 % — constante | ✅ 100 % | ✅ 100 % |
| **Calcul dynamique ?** | ❌ statique par index | ❌ statique par index | ❌ constante | ❌ constante | ❌ constante |
| **Temps réel ?** | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Timestamp ?** | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Direction** | ⚠️ **synthétisée** `'Dir. ${dernier arrêt}'` (L972-973) ; aucun champ de sens dans le JSON ; **aucune direction « Dakar »** pour les 13 gares | ⚠️ idem ; **aucune direction retour** | ⚠️ idem | ⚠️ idem | ⚠️ idem |
| **Prochain arrêt** | ✅ dérivé du JSON (`stopIds`) | ✅ idem | ✅ idem | ✅ idem | ✅ idem |
| **ETA réelle** | ❌ 35 km/h codé en dur | ❌ 35 km/h | ❌ 20 km/h | ❌ 20 km/h | ❌ 20 km/h |
| Décalage appliqué | `_shift(_terBase, i*2)` → +0…+24 min | `_shift(_brtBase, i*2)` → +0…+44 min | `schedule = []` | `[]` | `[]` |
| Valeur affichée | `HH h MM` précis | `HH h MM` précis | « 5 min » / « En rotation (~5 min) » | idem | idem |
| `data_trust` JSON des arrêts | 13/13 `OFFICIAL` | 23/23 et 7/7 `OFFICIAL` | 4 `OFFICIAL`, **37 `FIELD_OBSERVATION`** | 1 `OFFICIAL`, **7 `FIELD_OBSERVATION`** | 14 `OFFICIAL`, **18 `FIELD_OBSERVATION`** |
| Badge affiché | 🟢 | 🟢 | 🔵 | 🔵 | 🟢 |
| **Le `data_trust` influence-t-il l'horaire ou le badge ?** | ❌ **non** | ❌ **non** | ❌ **non** | ❌ **non** | ❌ **non** |

### E.3 Les constantes de `_generateSchedule` — localisation exhaustive

```dart
// L253-257
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) { list.add(m); }
  return list;
}
// L258  List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
// L259  bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
// L260  List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);
// L261  final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
// L262  final List<int> _terBase = _buildTerBase();
```

| Constante | Emplacement | Valeur | Réseau | Lignes concernées | Signification | **Origine identifiable ?** | Risque de présentation trompeuse |
|---|---|---|---|---|---|---|---|
| `from` TER | L260 | **330** = 05 h 30 | TER | les 13 gares | premier départ | ❌ **NON** — aucun commentaire, aucune source, aucun ticket, aucun test | 🔴 élevé : présenté comme une heure officielle |
| `to` TER | L260 | **1320** = 22 h 00 | TER | les 13 gares | dernier départ | ❌ **NON** | 🔴 élevé |
| `step` TER semaine | L260 | **10** min | TER | les 13 gares | fréquence | ❌ **NON** | 🔴 élevé : « toutes les 10 min » est affirmé à l'utilisateur (L2938) |
| `step` TER dimanche | L260 | **20** min | TER | les 13 gares | fréquence dominicale | ❌ **NON** | 🔴 élevé |
| `from` BRT | L261 | **360** = 06 h 00 | BRT | 23 stations B1 | premier départ | ❌ **NON** | 🔴 élevé |
| `to` BRT | L261 | **1260** = 21 h 00 | BRT | 23 stations B1 | dernier départ | ❌ **NON** | 🔴 élevé : la fenêtre annoncée dit 22 h 30 (L1105) |
| `step` BRT | L261 | **6** min | BRT | 23 stations B1 | fréquence | ❌ **NON** | 🔴 élevé |
| offset TER | L961 | **`i * 2`** | TER | selon l'index | décalage le long de la ligne | ❌ **NON** | 🟠 moyen |
| offset BRT | L963 | **`i * 2`** | BRT | selon l'index | idem | ❌ **NON** | 🟠 moyen |
| `_isSunday` | L259 | `weekday == 7` | TER | toutes | détection du dimanche | ⚠️ convention ISO, mais **heure locale appareil** | 🟠 moyen |
| rotation continue | L685, L696 | **5** | AFTU + Tata + DDD | **81 arrêts** | attente permanente | ❌ **NON** | 🔴 élevé : valeur constante présentée comme un temps d'attente |
| libellé rotation | L704 | `'En rotation (~5 min)'` | AFTU + Tata + DDD | 81 arrêts | texte | ❌ **NON** | 🔴 élevé |
| ouverture continue | L677 | **6** h | AFTU + Tata + DDD | 81 arrêts | début de service | ❌ **NON** | 🟠 |
| ouverture TER/BRT | L677 | **5** h | TER + BRT | 36 arrêts | début de service | ❌ **NON** | 🟠 |
| fermeture | L678-679 | **22** h, **+30** min | TER + BRT | 36 arrêts | fin de service | ❌ **NON** | 🟠 |
| horizon | L689 | **180** min | TER + BRT | 36 arrêts | fenêtre de recherche | ❌ **NON — NON PROUVÉ** | 🟠 |
| vitesse TER/BRT | L1146 | **35.0** km/h | TER + BRT | itinéraires | calcul de durée | ❌ **NON** | 🟠 |
| vitesse autres | L1146 | **20.0** km/h | AFTU/Tata/DDD | itinéraires | idem | ❌ **NON** | 🟠 |
| plancher de durée | L1148 | **5** min | tous | itinéraires | durée minimale | ❌ **NON** | 🟡 |
| minutes par arrêt | L388 | **3** | TER/BRT | fiche ligne | `estimatedTime` | ⚠️ **partiellement** : le commentaire L384-387 cite le faisceau `aOu` du binaire de production | 🟠 |
| distance de repli | L974 | **`300 + i*800`** | tous | 117 arrêts | `distanceMeters` | ❌ **NON** | 🟠 (déjà G7 O1) |

**Sur 21 constantes, 19 n'ont aucune origine identifiable**, 1 est partiellement documentée
(`kMinutesPerStop`, alignée sur la production), 1 est une convention (`weekday == 7`).

> **Règle appliquée ici, conformément à la consigne :** aucune de ces valeurs n'est qualifiée
> d'officielle au motif qu'elle figure dans le code. Le code ne fait pas la provenance.

---

## F — Badges : toutes les occurrences et leur provenance

### F.1 Inventaire lexical exhaustif dans `lib/`

| Mot | Occurrences | Dont commentaires | Dont code | Dont face utilisateur |
|---|---|---|---|---|
| `Officiel` (capitale) | 10 | 2 | 8 | **7** |
| `officiel` | 32 | 27 | 5 | **2** |
| `OFFICIAL` | 3 | 3 | 0 | 0 |
| `Données officielles` | 2 | 1 | 1 | **1** |
| `En direct` | 1 | **1** | 0 | **0** |
| `LIVE` / `Live` | **0** | — | — | 0 |
| `live` | 7 | 2 | 5 | **0** (déclarations d'enum) |
| `Programmé` / `programm` | **0** | — | — | **0** |
| `Temps réel` (capitale) | **0** | — | — | 0 |
| `temps réel` | 7 | 5 | 2 | **2** |
| `realTime` / `REAL_TIME` | 3 | **3** | 0 | **0** |
| `Estimé` | **0** | — | — | 0 |
| `estim` | 9 | 5 | 4 | **1** (« Heure : ~N min ») |
| `Indicatif` | 1 | 0 | 1 | **0** (`label` jamais affiché) |
| `indicat` | 5 | 0 | 5 | **1** (L2786) |
| `Inconnu` (capitale) | **0** | — | — | **0** |
| `inconnu` | 9 | **9** | 0 | **0** |
| `unknown` | 1 | 0 | 1 | **0** |
| `Vérifié` | 4 | **4** | 0 | 0 |
| `verified` | 4 | 0 | 4 | **0** |
| `Synthétique` | **0** | — | — | 0 |
| `Fiable` / `fiabilité` | **0** | — | — | 0 |
| `Approxim` | **0** | — | — | 0 |

**Constat lexical** : les mots qui qualifieraient honnêtement la donnée — « Programmé »,
« Estimé », « Inconnu », « Synthétique », « Approximatif », « Fiabilité » — ont
**0 occurrence face utilisateur**. Les mots qui la sur-qualifient — « Officiel », « officielles »,
« Données officielles » — ont **9 occurrences face utilisateur**.

### F.2 Toutes les occurrences face utilisateur

| # | Fichier:ligne | Écran | Texte exact | Donnée associée | **Source réelle de cette donnée** |
|---|---|---|---|---|---|
| B1 | `main.dart:2161` | **Explorer → `StopCard`** (sous-titre des 141 arrêts) | `${format(dist)} • ${modeLabel} (${badgeEmoji}) • ${crowd}` → ex. « 1.5 km • TER (🟢) • 🟠 Dense » | l'arrêt entier, dont son attente | 🟢/🔵 = `sourceForOperator(operatorId)` L925-933. **`data_trust` ignoré.** Distance parfois `300+i*800` synthétique. Affluence = horloge seule |
| B2 | `main.dart:293-295` | (définition) | `'SETER (Officiel)'`, `'SunuBRT (Officiel)'`, `'Dakar Dem Dikk (Officiel)'` | `label` | ❌ **jamais affiché** — seul `badgeEmoji` l'est |
| B3 | `main.dart:296-297` | (définition) | `'Bus TATA (Officiel)'`, `'AFTU (72 Lignes Officielles)'` | `label` | ❌ **jamais affiché** |
| B4 | `main.dart:298` | (définition) | `'Donnée Indicative (~)'` | `label` de `demo` | ❌ **jamais affiché** — et `demo` n'est attribué à **aucun** des 117 arrêts JSON |
| B5 | `main.dart:2422` | **Alertes → carte TER** | `'badge': '13 Gares Officielles'` | le nombre de gares TER | ✅ **fondé** : le JSON contient bien 13 gares `OFFICIAL`. Littéral statique, non dérivé |
| B6 | `main.dart:2419` | Alertes → carte TER | `'source': 'Source officielle : CETUD / SETER'` | la carte d'alerte | ✅ fondé quant à l'exploitant. Littéral statique |
| B7 | `main.dart:2420` | Alertes → carte TER | `'Le TER dessert officiellement 13 gares…'` | idem | ✅ fondé |
| B8 | `main.dart:2461` | **Alertes → carte BRT** | `'badge': 'Données officielles'` | la carte d'alerte | ⚠️ **fondé sur `brt_b1.data_trust == 'OFFICIAL'`** (justifié en commentaire L2446-2455), mais c'est un **littéral statique** : il ne varie pas avec la donnée |
| B9 | `main.dart:2457-2458` | Alertes → carte BRT | `'Corridor officiel SunuBRT'`, `'Source officielle : Dakar Mobilité / CETUD'` | idem | ⚠️ idem |
| B10 | `main.dart:2468` | Alertes → carte DDD | `'source': 'Source officielle : Direction DDD'` | la carte d'alerte | 🔴 **contredit la donnée** : **18 des 32 arrêts DDD sont `FIELD_OBSERVATION`** |
| B11 | `main.dart:2471` | Alertes → carte DDD | `'badge': 'Réseau actif'` | la carte d'alerte | ⚠️ aucun mécanisme ne vérifie que le réseau est actif |
| B12 | `main.dart:2469` | Alertes → carte DDD | `'…aux horaires habituels.'` | horaires DDD | 🔴 **aucun horaire DDD n'existe** : `schedule = []`, attente constante 5 min |
| B13 | `main.dart:2230` | **Trajets → `TripsPage`** | `'Itinéraires multimodaux officiels (TER, BRT, DDD, TATA, AFTU).'` | les itinéraires calculés | 🔴 **les itinéraires sont calculés** : vitesses 35/20 km/h codées en dur, durée `ceil(dist/speed)`, heures de départ synthétiques |
| B14 | `main.dart:2786` | **Réglages → modale « Conditions d'utilisation »** | `'Dakar Bus fournit des informations de transport indicatives et officielles basées sur les données des opérateurs… L'application s'engage à assurer un affichage fidèle et mis à jour en continu.'` | toute l'application | 🔴 **« mis à jour en continu » : aucun mécanisme de mise à jour n'existe.** Le JSON est un asset compilé, immuable entre deux builds. Aucune API de données |
| B15 | `main.dart:2779` | Réglages → modale d'aide | `'…votre position GPS en temps réel…'` | la position | 🟡 **partiellement fondé** : `getPositionStream` + ticker 15 s existent ; mais la position peut être **synthétique** (repli sur distances `300+i*800` et tri sur centre fabriqué) |
| B16 | `main.dart:2960` | **Assistant IA** | `'🚨 Alertes en temps réel : consulte l'onglet "Alertes" (CETUD/SETER) et "Direct rue"…'` | les alertes | 🔴 **aucun flux temps réel** : les cartes d'Alertes sont des littéraux statiques (L2392-2475), « Direct rue » affiche `'Sans horodatage'` (L2574-2575) |
| B17 | `main.dart:2938` | **Assistant IA** | `'…en traversant 14 gares officielles… avec un départ toutes les 10 à 20 min.'` | le TER | 🔴 **double erreur** : « 14 » alors que le JSON en porte **13** ; « toutes les 10 à 20 min » reprend des constantes non sourcées (L260) |
| B18 | `main.dart:2796` | Réglages | `Icons.verified` à côté de « Version de l'application » | la version | 🟢 icône décorative, sans portée sur les données |

### F.3 La question posée : « badge Officiel + attente synthétique »

**Comportement observable, décrit sans jugement produit.**

À l'écran **Explorer**, chaque arrêt est rendu par `StopCard` (L2100-2193). La carte contient, dans
le même encart visuel :

```
L2111  final int? remaining = stop.remainingMinutes();      ← calcul synthétique
L2116  final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);
L2117-2125  badge trailing : « Fermé » | « Bientôt » | « Imminent » | « N min »
L2161  sous-titre : « 1.5 km • TER (🟢) • 🟠 Dense »
```

Le badge 🟢 et le badge d'attente sont **rendus par le même widget, dans la même carte, à 44 lignes
d'écart**, sans séparateur sémantique ni qualificatif intermédiaire.

**Chaîne de provenance des deux valeurs, vérifiée ligne à ligne :**

| Élément affiché | Provenance exacte | Contient une donnée d'opérateur ? |
|---|---|---|
| 🟢 | `sourceForOperator('ter')` → `DataSourceInfo.seter` → `badgeEmoji` (L925-933, L293) | **oui**, l'identité de l'exploitant — mais **ni son horaire, ni sa confiance** |
| « 9 min » | `remainingMinutes()` L694-700 → `nextDepartureMinutes()` L683-692 → `departureMinutesFromMidnight` L631 → `_shift(_terBase, i*2)` L961 → `_generateSchedule(from: 330, to: 1320, step: 10)` L260 | **non** — suite arithmétique pure |

**Ce qui est techniquement vrai :**

1. Le 🟢 qualifie **l'exploitant**, pas l'horaire. `DataSourceInfo.origin` vaut `official`, mais ce
   champ n'est **jamais lu** (§C.6 P6) et `label` **jamais affiché** (§F.2 B2) : l'utilisateur ne
   voit que l'émoji, sans le texte qui préciserait « SETER (Officiel) ».
2. Rien dans le rendu ne rattache l'émoji à l'exploitant plutôt qu'à la carte entière. La chaîne
   affichée est `distance • mode (émoji) • affluence`, suivie du badge d'attente : **quatre
   informations hétérogènes sur une même ligne visuelle**.
3. **Aucun qualificatif horaire n'existe** : « Programmé », « Estimé », « Indicatif », « Inconnu »,
   « Approximatif » ont **0 occurrence face utilisateur** (§F.1).
4. Le seul endroit où un texte explicite apparaît (« Données officielles », B8) qualifie une
   **carte d'alerte statique**, pas un horaire.
5. L'attente affichée est **100 % synthétique** pour les cinq réseaux (§E.2).

**Réponse factuelle à la question :** rien, dans le code rendu, ne permet à l'interface de
différencier « l'opérateur est officiel » de « le prochain départ est officiellement fourni par
l'opérateur ». Les deux lectures sont techniquement compatibles avec ce qui est affiché, et
**aucun élément du rendu ne les départage** — ni texte, ni couleur, ni icône, ni tooltip, ni
hiérarchie visuelle. La seconde lecture est en outre **renforcée** par trois facteurs vérifiés :
l'absence totale de qualificatif horaire (§F.1), la proximité visuelle dans un même widget (L2111 /
L2161), et le fait que l'assistant énonce des heures absolues sans aucune réserve (§H).

---

## G — Les 18 arrêts `FIELD_OBSERVATION`

### G.1 Identification exhaustive

**Les 18 arrêts sont tous `Dakar Dem Dikk` (opérateur `ddd`).** Aucun TER, aucun BRT.

| # | Nom | `id` | `data_trust` |
|---|---|---|---|
| 1 | HLM Grand Yoff | `stop_hlm` | FIELD_OBSERVATION |
| 2 | Point E - Fann | `stop_point_e` | FIELD_OBSERVATION |
| 3 | Castor - HLM | `stop_castor` | FIELD_OBSERVATION |
| 4 | Scat Urbam - Parcelles | `stop_scatt_urbam` | FIELD_OBSERVATION |
| 5 | Gare Maritime - Plateau | `stop_gare_maritime` | FIELD_OBSERVATION |
| 6 | Ouakam - Cité Avion | `stop_ouakam` | FIELD_OBSERVATION |
| 7 | Mermoz - Sacré-Cœur | `stop_mermoz` | FIELD_OBSERVATION |
| 8 | Ngor - Almadies | `stop_ngor` | FIELD_OBSERVATION |
| 9 | Almadies - Pointe | `stop_almadies` | FIELD_OBSERVATION |
| 10 | Fass - Colobane | `stop_fass` | FIELD_OBSERVATION |
| 11 | SICAP Liberté - Dakar | `stop_sicap_liberte` | FIELD_OBSERVATION |
| 12 | Dieuppeul - Derklé | `stop_dieuppeul` | FIELD_OBSERVATION |
| 13 | Grand Dakar - Biscuiterie | `stop_grand_dakar` | FIELD_OBSERVATION |
| 14 | Biscuiterie - HLM | `stop_biscuiterie` | FIELD_OBSERVATION |
| 15 | Rebeuss - Plateau | `stop_rebeuss` | FIELD_OBSERVATION |
| 16 | Amitié 2 - Dakar | `stop_amitie` | FIELD_OBSERVATION |
| 17 | Sébikotane Gare 2 | `stop_sebikotane_gare2` | FIELD_OBSERVATION |
| 18 | Bargny Guedj - Bord de Mer | `stop_bargny_guedj` | FIELD_OBSERVATION |

### G.2 Répartition complète des 62 `FIELD_OBSERVATION`

| Opérateur | `FIELD_OBSERVATION` | `OFFICIAL` | Badge affiché | `DataSourceInfo` | `origin` |
|---|---|---|---|---|---|
| **DDD** | **18** | 14 | 🟢 | `demdikk` | `official` |
| AFTU | 37 | 4 | 🔵 | `aftuOfficial` | `verified` |
| Tata | 7 | 1 | 🔵 | `tataOfficial` | `verified` |
| TER | 0 | 13 | 🟢 | `seter` | `official` |
| BRT | 0 | 23 | 🟢 | `sunubrt` | `official` |
| **Total** | **62** | **55** | | | |

### G.3 Comportement réel de ces 18 arrêts

| Question | Réponse vérifiée | Preuve |
|---|---|---|
| Quelle source est affichée ? | 🟢, sans texte | L2161 rend `badgeEmoji` seul ; `label` « Dakar Dem Dikk (Officiel) » n'est **jamais** affiché |
| Quel badge est affiché ? | **🟢 — le même que TER et BRT** | `sourceForOperator('ddd')` → `DataSourceInfo.demdikk` (L929), `badgeEmoji: '🟢'` (L295) |
| Quels horaires sont affichés ? | **Aucun horaire** : `schedule = []` (L965) → `nextDepartureLabel()` renvoie `'En rotation (~5 min)'` (L704) | L964-965, L672, L704 |
| Quels temps d'attente sont affichés ? | **« 5 min » en permanence**, de 6 h à 22 h ; « Fermé » hors fenêtre | L696 (`return 5`), L677 (`startHour = 6`), L2117-2125 |
| Ces horaires viennent-ils du même `_generateSchedule` ? | ❌ **NON — ils n'en viennent pas du tout.** DDD est en **flux continu** : court-circuit **avant** toute lecture de liste | L672 `isContinuousFlow`, L685, L696 |
| Existe-t-il une différence de comportement avec les autres arrêts ? | ❌ **AUCUNE.** Le code ne contient **aucune** branche sur `dataTrust` | §C.4 : 0 lecture dans `main.dart` |

### G.4 Comparaison directe : arrêt `OFFICIAL` vs arrêt `FIELD_OBSERVATION`, même opérateur

Les 32 arrêts DDD se répartissent 14 `OFFICIAL` / 18 `FIELD_OBSERVATION`. Comparaison de deux
arrêts du **même opérateur**, au **même instant**, dans le **même écran** :

| | `stop_dakar_plateau` (DDD, `OFFICIAL`) | `stop_hlm` (DDD, `FIELD_OBSERVATION`) |
|---|---|---|
| `source` | `demdikk` | `demdikk` |
| `badgeEmoji` affiché | 🟢 | 🟢 |
| `origin` | `official` | `official` |
| `modeLabel` | `DDD` | `DDD` |
| `departureMinutesFromMidnight` | `[]` | `[]` |
| attente affichée | « 5 min » | « 5 min » |
| étiquette | « En rotation (~5 min) » | « En rotation (~5 min) » |
| affluence | identique (horloge seule) | identique |
| **Différence visible** | — | **AUCUNE** |

> **Les 18 arrêts `FIELD_OBSERVATION` sont strictement indiscernables des 14 arrêts `OFFICIAL` du
> même opérateur, et indiscernables des 36 arrêts TER/BRT officiellement confirmés.** Le seul
> signal de confiance porté par la source unique est intégralement neutralisé à l'étape 4 (§B.2).

### G.5 Les 44 autres `FIELD_OBSERVATION` (AFTU + Tata)

Même mécanisme, badge 🔵 (`origin: verified`). L'écart est **moins marquant** visuellement — 🔵
diffère de 🟢 — mais le 🔵 est **identique** pour les 5 arrêts `OFFICIAL` et les 44
`FIELD_OBSERVATION` de ces deux opérateurs. Aucune distinction n'est possible non plus.

---

## H — Assistant IA : chemin réel des données

### H.1 Ce que l'assistant sait — inventaire

| Concept | L'assistant y a-t-il accès ? | Chemin exact |
|---|---|---|
| **Horaires** | ✅ **oui, indirectement** | `_formatRouteResult` L2884 lit `RouteSegment.departureTime` / `.arrivalTime`, produits par `_formatMin(dep)` L1157 |
| **Prochains départs** | ⚠️ **uniquement dans un itinéraire** | `departureAfter(safeCurrentMin)` L1151. **Aucun intent « horaire / prochain / depart / quelle heure / passe a » n'existe** : grep sur ces motifs dans `AIChatPage` → **0 résultat** |
| **Temps d'attente** | ❌ **non** | `remainingMinutes()` n'est **jamais appelé** par `AIChatPage`. `nextDepartureLabel()` non plus |
| **Statut de donnée** | ❌ **non** | `PlannedRoute.status` et `RouteSegment.status` sont posés à `scheduled` (L1156-1157) mais **jamais lus** — y compris par l'assistant |
| **Sources** | ❌ **non** | `Stop.source` n'est jamais mentionné dans les 12 réponses `aiReply` (L2927-2964) |
| **Données officielles** | ⚠️ **par affirmation textuelle** | L2938 : « 14 gares officielles ». L2962 : « Les réseaux TER, BRT, DDD, TATA, AFTU fonctionnent normalement » |
| **Données inconnues** | ❌ **non** | le mot « inconnu » a **0 occurrence** dans `AIChatPage` ; aucun état d'ignorance n'est exprimé |

### H.2 Le chemin complet d'une heure énoncée par l'assistant

```
texte utilisateur  « je suis à Dakar je veux aller à Diamniadio »
  ↓  AIChatPage._sendMessage()                      L2894
  ↓  _extractTrip(text) — regex                L2828, L2860-2870
  ↓  RoutePlanner.plan(fromQuery, toQuery)          L2929  → L1101
  ↓  _findNearestStop('dakar')                      L1108  → L1135-1142
  ↓      retourne le PREMIER arrêt contenant « dakar »
  ↓  _buildRoute(from, to, currentMin)              L1118  → L1144
  ↓      dist = haversineMeters(from.location, to.location)          L1145
  ↓      speed = 35.0 (TER/BRT) ou 20.0                    L1146  ← CONSTANTE
  ↓      dur = ceil(dist/1000/speed*60), plancher 5               L1147-1148
  ↓      dep = from.departureAfter(safeCurrentMin) ?? safeCurrentMin   L1151
  ↓              ↓
  ↓         departureAfter  L711-716 : premier d de la liste avec d > currentMin
  ↓              ↓
  ↓         departureMinutesFromMidnight  L631
  ↓              ↓
  ↓         _shift(_terBase, i*2)   L961        ← DÉCALAGE SYNTHÉTIQUE
  ↓              ↓
  ↓         _terBase = _generateSchedule(from:330, to:1320, step:10)   L260, L253
  ↓              ↓
  ↓         🔴 SUITE ARITHMÉTIQUE 330, 340, 350 … 1320
  ↓      arr = dep + dur                                            L1152
  ↓      status: DataStatus.scheduled   ← posé, JAMAIS LU            L1156
  ↓      departureTime: _formatMin(dep)  → « 15 h 10 »               L1157, L1178
  ↓  _formatRouteResult(res, from, to)                    L2930  → L2873
  ↓  buf.writeln('   🕒 ${s.departureTime} → ${s.arrivalTime} • …')   L2884
  ↓
🔴 AFFICHÉ : « 🕒 15 h 10 → 15 h 55 • 45 min • Direct »
```

### H.3 Vérification de la question posée

> **« L'IA pourrait-elle actuellement répondre "Le prochain départ est à 15h10" alors que cette
> information provient uniquement d'un horaire synthétique ? »**

**OUI — démontré, avec reproduction numérique exacte.**

Port fidèle de L253-262, L711-716, L1144-1157, L1178-1181 et L2884, avec les coordonnées réelles
du JSON (`stop_dakar_ter` 14.6760/−17.4335, `stop_diamniadio`) :

| Heure système | `departureAfter(907)` | Réplique exacte de L2884 |
|---|---|---|
| 15:07 | `910` | **« 🕒 15 h 10 → 15 h 55 • 45 min • Direct »** |
| 15:00 | `910` | « 🕒 15 h 10 → 15 h 55 • 45 min • Direct » |
| 14:41 | `890` | « 🕒 14 h 50 → 15 h 35 • 45 min • Direct » |

**Provenance de « 15 h 10 » :** `910 = 330 + 10 × 58`, soit l'**index 58** de la suite
arithmétique `_terBase`, avec un décalage `i*2 = 0` (la gare de Dakar est l'arrêt d'index 0).
`910 ∈ _terBase` : **vrai**.

Aucune donnée d'opérateur, aucun timestamp, aucune API, aucun horaire du JSON n'intervient à
aucune étape. La distance (25 673 m haversine) et la vitesse (35 km/h codée en dur) produisent
les « 45 min ». **L'intégralité de la phrase est synthétique, et elle est énoncée sans aucune
réserve** — le seul qualificatif présent est « Direct ».

### H.4 Les 12 réponses de l'assistant (L2927-2964)

| Ligne | Déclencheur | Contenu | Qualifie-t-il la donnée ? |
|---|---|---|---|
| 2930 | itinéraire demandé | `_formatRouteResult` → heures absolues | ❌ **non** |
| 2938 | « ter » mémorisé | « 14 gares officielles … toutes les 10 à 20 min » | 🔴 affirme « officielles » + **14** au lieu de 13 |
| 2955 | position GPS disponible | « 📍 Tu es près de : … » | ❌ non |
| 2960 | « alerte » | « 🚨 Alertes en temps réel … » | 🔴 affirme un temps réel inexistant |
| 2962 | « ça va » / état du réseau | « Les réseaux TER, BRT, DDD, TATA, AFTU fonctionnent normalement » | 🔴 affirme un état non vérifié |
| autres | 7 réponses | guidage, destinations, GPS | ❌ non |

**Aucune des 12 réponses n'exprime une incertitude, une absence de donnée, ou un statut.**

### H.5 Divergence avec la production déployée

Le binaire gh-pages `94a84b60` contient un **intent horaire dédié** que le source actuel n'a plus :

```js
// production
…||B.d.n(a7,"quelle heure")||B.d.n(a7,"passe a")){ r=a4.rY(a8) …
  return "🕒 "+r.a+" ("+r.b+") — lignes "+r.got()+"\nProchain départ : "+r.IM()
         +"\nAffluence actuelle : "+A.akL(r) …
```

`r.IM()` est `nextDepartureLabel()`. **La production répondait donc directement à une question
d'horaire**, en énonçant `nextDepartureLabel()` — déjà synthétique, mais au moins sur demande
explicite. Le source actuel n'a **aucune** branche équivalente (grep `horaire|prochain|depart|
quelle heure|passe a` dans `AIChatPage` → **0 résultat**), et « Fréquence : » → **0 occurrence**.

Deux conséquences opposées, toutes deux documentées :
- **perte fonctionnelle** : l'assistant ne répond plus à « à quelle heure passe le prochain bus ? » ;
- **moindre exposition** : il n'énonce plus d'horaire **hors** d'un calcul d'itinéraire.

En revanche, `AIChatPage` affiche toujours des heures absolues via `_formatRouteResult` (L2884),
chemin **identique** à la production (`"N. mode : de → à • 🕒 dep → arr (dur min)"`).

---

## I — Tests : couverture réelle

### I.1 Volume

**232 tests**, 9 fichiers : `dakar_bounds_test` 18 · `data_service_test` 10 ·
`detailed_route_test` 37 · `gps_position_test` 40 · `groupe6_alertes_test` 12 ·
`network_data_test` 22 · `opposite_stop_test` 34 · `ter_brt_route_data_test` 57 ·
`widget_test` 2.

### I.2 Références par symbole dans `test/`

| Symbole | Occ. | Fichiers | Symbole | Occ. | Fichiers |
|---|---|---|---|---|---|
| `DataTrust` | **15** | 4 | `DataSourceInfo` | **0** | 0 |
| `dataTrust` | **8** | 4 | `sourceForOperator` | **0** | 0 |
| `data_trust` | **5** | 3 | `badgeEmoji` | **0** | 0 |
| `DataStatus` | **10** | 2 | `DataOrigin` | **0** | 0 |
| `OFFICIAL` | 9 | 4 | `Officiel` | **0** | 0 |
| `official` | 38 | 4 | `_generateSchedule` | **0** | 0 |
| `FIELD_OBSERVATION` | 4 | 2 | `remainingMinutes` | **0** | 0 |
| `fieldObservation` | 3 | 2 | `nextDeparture` | **0** | 0 |
| `ESTIMATED` | 2 | 2 | `departure` | 3 | 3 |
| `estimated` | 11 | 3 | `schedule` | 2 | 1 |
| `live` | 20 | 2 | `badge` | 18 | 1 |
| `unknown` | **2** | 1 | `source` | 25 | 6 |

### I.3 Les tests `DataTrust` — ce qu'ils vérifient réellement (7 tests)

| Fichier:ligne | Test | Ce qui est vérifié | Ce qui **ne** l'est **pas** |
|---|---|---|---|
| `data_service_test.dart:8` | `fromString OFFICIAL` | `'OFFICIAL'` → `DataTrust.official` | — |
| `:11` | `fromString FIELD_OBSERVATION` | `'FIELD_OBSERVATION'` → `fieldObservation` | la branche `default:` → `estimated` **n'est pas testée** |
| `:14-16` | `toLabel` | les 3 valeurs → `'OFFICIAL'`/`'FIELD_OBSERVATION'`/`'ESTIMATED'` | `toLabel` est **inatteignable dans l'app** (`toJson` jamais appelé) |
| `:32-35` | `BusStop fromJson` | un JSON minimal → `stop.dataTrust == official` | — |
| `:44` | `TransportRoute fromJson` | idem pour une ligne | — |
| `network_data_test.dart:296-305` | `data_trust des arrêts actifs connu du modèle` | chaque arrêt du JSON a une valeur **parmi les 3** | ❌ **ne vérifie pas la valeur**, seulement qu'elle est reconnue |
| `ter_brt_route_data_test.dart:248` | `chaque gare porte un statut de donnée connu (§9)` | `DataTrust.values.contains(s.dataTrust)` | ❌ idem |
| `:688` | `une station officielle porte identifiant, nom, coordonnées et statut` | `s.dataTrust == DataTrust.official` | — |
| `groupe6_alertes_test.dart:276-285` | `le badge BRT s'appuie sur le data_trust réel de la ligne` | `b1.dataTrust == official` **et** `toLabel() == 'OFFICIAL'` | ⚠️ vérifie la **justification textuelle** d'un badge d'alerte statique — **pas** un rendu |

### I.4 Les tests `DataStatus` — 4 tests, tous sur la **forme**

| Fichier:ligne | Test | Portée |
|---|---|---|
| `gps_position_test.dart:509-513` | `DataStatus conserve exactement 3 valeurs` | `hasLength(3)` + noms exacts |
| `:515` | `le resolver GPS n'expose AUCUN DataStatus` | couture GPS |
| `:531-541` | `GARDE-FOU SOURCE : DataStatus.live n'est assigné nulle part` | scan **textuel** de `lib/main.dart` |
| `groupe6_alertes_test.dart:271` | `reason:` rappelant que `live` n'est jamais assigné | message, pas assertion |

**Aucun test ne vérifie le comportement d'une valeur de `DataStatus`** — puisqu'aucune n'est lue.
Les 2 occurrences de `unknown` dans `test/` sont la **liste des noms attendus** (L512) et le
**scan textuel de la déclaration** (L540). `unknown` n'est jamais manipulé comme valeur.

### I.5 Branches non testées et cas inexistants

| Branche / cas | Emplacement | Testée ? |
|---|---|---|
| `fromString` branche `default:` → `estimated` | `transport_network.dart:26` | ❌ **non** |
| `_loadFallbackData()` de `DataService` | `data_service.dart:40-142` | ❌ **non** — 0 test ne déclenche l'échec de chargement |
| `sourceForOperator` (6 branches) | `main.dart:925-933` | ❌ **non** — 0 référence |
| `labelForOperator` (6 branches) | `main.dart:915-923` | ❌ **non** |
| `colorForOperator` / `iconForOperator` | `main.dart:895-913` | ❌ **non** |
| rendu de `badgeEmoji` | `main.dart:2161` | ❌ **non** — 0 test widget sur `StopCard` |
| propagation `dataTrust` → `Stop` | `main.dart:968-982` | ❌ **impossible** — le champ n'existe pas |
| lecture de `DataStatus` | — | ❌ **impossible** — aucune lecture n'existe |
| `DataOrigin` (4 valeurs) | `main.dart:289` | ❌ **non** — 0 référence |
| les 3 fenêtres de service | `674-681`, `1103`, `2116` | ❌ **non** |
| l'horizon 180 | `main.dart:689` | ❌ **non** (les 7 « 180 » des tests sont `pi/180` ou des fixtures de distance) |
| les 4 libellés de `nextDepartureLabel` | `main.dart:702-709` | ❌ **non** |
| les 4 états du badge d'attente | `main.dart:2117-2125` | ❌ **non** |
| le texte « 14 gares officielles » de l'IA | `main.dart:2938` | ❌ **non** |

### I.6 Conclusion de couverture

**Les 232 tests certifient la chaîne JSON → parser → modèle de données. Aucun ne certifie la
chaîne modèle → UI.** Les 18 occurrences de `badge` dans `test/` concernent toutes les **cartes
d'alerte statiques** (`groupe6_alertes_test.dart`), pas le badge de fiabilité des arrêts.

Le test placeholder du Groupe 7 (anomalie O21) est toujours présent, inchangé :

```dart
// test/dakar_bounds_test.dart:162-167
group('Stop isContinuousFlow logic', () {
  test('placeholder - verified via modeLabel', () {
    // AFTU/DDD/Tata sont en rotation continue (isContinuousFlow true)
    // Vérifié indirectement via DistanceHelper et DakarBounds
    expect(DistanceHelper.format(100), '100 m');
  });
});
```

`isContinuousFlow` n'y est jamais appelé.

---

## J — Anomalies

Numérotation `G9-H01`…`G9-H30`. Sévérité classée par **impact sur la représentation de la
fiabilité**, conformément au principe produit. Les anomalies déjà identifiées par le Groupe 8 sont
**référencées**, pas re-dérivées.

### 🔴 CRITIQUE — la fiabilité réelle n'est pas représentable

---

**G9-H01** · 🔴 · `lib/main.dart:628-643` et `:968-982`

- **Preuve** : `class Stop` déclare **12 champs** — `name`, `direction`, `distanceMeters`,
  `departureMinutesFromMidnight`, `icon`, `color`, `location`, `status`, `modeLabel`, `source`,
  `stopType`, `stopId`. **Aucun** ne porte une confiance de donnée. `grep dataTrust` sur la plage
  L600-760 → **0 résultat**. À L968-982, `busStop.name` (L969), `busStop.id` (L970),
  `busStop.latitude`/`.longitude` (L978) sont lus ; `busStop.dataTrust` ne l'est **pas**.
- **Comportement actuel** : la confiance de l'arrêt est disponible jusqu'au service
  (`appDataService.stops[i].dataTrust`) puis **disparaît définitivement** à la conversion. Aucun
  widget ne peut y accéder, même s'il le voulait.
- **Impact** : il est **structurellement impossible** d'afficher la confiance réelle d'un arrêt
  sans modifier le modèle `Stop`. C'est la cause racine de G9-H02, G9-H05 et G9-H13.

---

**G9-H02** · 🔴 · `lib/main.dart` (3 occurrences de `dataTrust`, toutes en commentaire : L830, L2453-2454, L3152)

- **Preuve** : **0 lecture** de `.dataTrust` dans `lib/main.dart`. Les 2 seules lectures de tout
  `lib/` sont `transport_network.dart:88` et `:129`, dans `toJson()` — et **`toJson()` a 0 site
  d'appel** dans `lib/` (3 déclarations L51, L83, L123).
- **Comportement actuel** : `DataTrust` est **intégralement write-only à l'exécution**. La valeur
  est parsée, stockée en mémoire, et jamais consultée par aucun code atteignable.
- **Impact** : le seul signal de fiabilité **réellement porté par la source unique** est
  intégralement neutralisé. 117 arrêts et 105 lignes ont une confiance ; l'application n'en tient
  aucun compte.

---

**G9-H03** · 🔴 · `lib/main.dart:925-933` (`sourceForOperator`)

- **Preuve** : le badge affiché est une fonction **exclusive** de `route.operatorId` — 6 branches
  sur chaîne. `busStop.dataTrust` et `route.dataTrust` n'y apparaissent pas. Croisement mesuré sur
  les 117 arrêts JSON :

| Badge | `OFFICIAL` | `FIELD_OBSERVATION` |
|---|---|---|
| 🟢 `seter` | 13 | 0 |
| 🟢 `sunubrt` | 23 | 0 |
| 🟢 `demdikk` | 14 | **18** |
| 🔵 `aftuOfficial` | 4 | **37** |
| 🔵 `tataOfficial` | 1 | **7** |

- **Comportement actuel** : **68 arrêts affichent 🟢, dont 18 sont `FIELD_OBSERVATION`** ;
  **49 affichent 🔵, dont 44 sont `FIELD_OBSERVATION`**. Soit **62 arrêts sur 117 (53 %)** dont la
  confiance réelle est contredite ou ignorée par le badge.
- **Impact** : un arrêt relevé sur le terrain est présenté avec le même marqueur visuel qu'un arrêt
  officiellement confirmé. Cf. §G.4 : deux arrêts DDD de confiance différente sont **strictement
  indiscernables** à l'écran.

---

**G9-H04** · 🔴 · aucun modèle de `lib/` — vérifié par `grep -rn "timestamp\|updatedAt\|lastUpdate\|horodat" lib/`

- **Preuve** : **0 champ d'horodatage** dans `BusStop`, `TransportRoute`, `Operator`, `Stop`,
  `RouteSegment`, `PlannedRoute`, `TransitRoute`, `DetailedRoute`, `DetailedStopInfo`. Les seules
  occurrences sont 3 commentaires et le littéral `'Sans horodatage'` (L2574-2575, démonstration).
  Le JSON ne porte **aucun** champ de date non plus (§B.1).
- **Comportement actuel** : la **fraîcheur** d'une donnée ne peut pas être représentée. Il est
  impossible de savoir si un horaire date d'aujourd'hui, d'il y a un an, ou n'a jamais existé.
- **Impact** : le concept « TEMPS RÉEL » du contrat produit est **irreprésentable** en l'état :
  non seulement aucune valeur ne l'incarne (§D.5), mais **aucun champ ne pourrait la justifier**.
  Corollaire : la promesse « mis à jour en continu » (L2786, G9-H15) est invérifiable par
  construction.

---

**G9-H05** · 🔴 · `lib/main.dart:2161` + `:2111-2125`

- **Preuve** : `StopCard` rend, dans le même widget, `stop.source.badgeEmoji` (L2161) et le badge
  d'attente issu de `remainingMinutes()` (L2111, L2117-2125). `label` — le texte qui préciserait
  « SETER (Officiel) » — n'est **jamais rendu** (§F.2 B2-B4). Recherche : « Programmé » **0**,
  « Estimé » **0**, « Indicatif » **0 affiché**, « Inconnu » **0**, « Approximatif » **0** (§F.1).
- **Comportement actuel** : un émoji qualifiant **l'exploitant** jouxte une attente **100 %
  synthétique**, sans séparateur sémantique ni qualificatif horaire. Analyse détaillée en §F.3.
- **Impact** : rien dans le rendu ne départage « l'opérateur est officiel » de « le prochain départ
  est officiellement fourni par l'opérateur ». Conjonction directe avec le principe produit
  « pas de donnée inventée ». Recoupe l'anomalie Groupe 8 **H-01**.

---

**G9-H06** · 🔴 · `lib/main.dart:2873-2891`, `:1144-1157`, `:260`

- **Preuve** : §H.2-H.3. Reproduction numérique : à 15:07, `departureAfter(907)` renvoie `910`,
  `_formatMin(910)` renvoie `'15 h 10'`, L2884 écrit **« 🕒 15 h 10 → 15 h 55 • 45 min • Direct »**.
  `910 = 330 + 10 × 58` — index 58 d'une suite arithmétique.
- **Comportement actuel** : l'assistant énonce une **heure absolue** au format horloge, sans
  aucune réserve. Le seul qualificatif de la ligne est « Direct ». `PlannedRoute.status` est posé
  à `scheduled` (L1156) puis **jamais lu**.
- **Impact** : la formulation la plus assertive de toute l'application — une heure précise, donnée
  par un assistant conversationnel — repose intégralement sur une constante non sourcée.

### 🟠 IMPORTANT

---

**G9-H07** · 🟠 · `lib/main.dart:289` (`enum DataOrigin`), `:291` (`final DataOrigin origin`)

- **Preuve** : `grep "origin ==\|origin !=\|switch (.*origin\|case DataOrigin"` sur `lib/` →
  **0 résultat**. Les 6 occurrences de `DataOrigin.` sont les **affectations** des constantes
  L293-298. `unavailable` n'est **jamais assigné**. ⚠️ Ne pas confondre avec `DetailedRoute.origin`
  (L367, L3043, L3054), un **nom de lieu**.
- **Comportement actuel** : la graduation en 4 niveaux (`official` / `verified` / `indicative` /
  `unavailable`) existe mais **n'est jamais consultée** : elle ne produit ni couleur, ni texte, ni
  condition. Seul l'émoji — choisi indépendamment — est rendu.
- **Impact** : un second vocabulaire de fiabilité mort, après `DataStatus`. Deux enums de
  fiabilité, **zéro lecture**.

---

**G9-H08** · 🟠 · `lib/main.dart:291`, `:293-298`

- **Preuve** : `label` est déclaré `final String`, renseigné par les 6 constantes. Recherche de
  `source.label` / `.label` sur une instance de `DataSourceInfo` → **0 occurrence**. Le seul rendu
  est `stop.source.badgeEmoji` (L2161).
- **Comportement actuel** : les textes « SETER (Officiel) », « Donnée Indicative (~) »,
  « AFTU (72 Lignes Officielles) » **n'apparaissent nulle part à l'écran**.
- **Impact** : l'unique information explicite sur la provenance existe en code et n'est jamais
  montrée. L'utilisateur ne voit qu'un point coloré, sans légende. Noter que
  `'Donnée Indicative (~)'` — le seul libellé **honnête** du système — est celui qui est le moins
  susceptible d'être affiché : `DataSourceInfo.demo` n'est attribué à **aucun** des 117 arrêts JSON.

---

**G9-H09** · 🟠 · `lib/main.dart:2786`

- **Preuve** : texte exact — « Dakar Bus fournit des informations de transport indicatives et
  officielles basées sur les données des opérateurs de la région de Dakar (CETUD, SETER, SunuBRT,
  DDD, AFTU). **L'application s'engage à assurer un affichage fidèle et mis à jour en continu.** »
- **Comportement actuel** : aucun mécanisme de mise à jour n'existe. Le JSON est un **asset
  compilé** (`rootBundle.loadString`, `data_service.dart:26`) : immuable entre deux builds. Les 2
  seuls endpoints réseau sont OSRM (géométrie) et les tuiles OSM (§E.1). Aucun timestamp (G9-H04).
- **Impact** : engagement contractuel affiché à l'utilisateur, **sans aucun moyen technique de le
  tenir**. Le mot « indicatives » est par ailleurs le seul qualificatif honnête de toute
  l'interface — mais il est noyé dans une phrase qui affirme aussi « officielles ».

---

**G9-H10** · 🟠 · `lib/main.dart:2938`, `:2950`, `:297`

- **Preuve — deux contradictions numériques avec la source unique, toutes deux affichées :**

| Texte | Ligne | Affirmation | Valeur réelle du JSON | Écart | Affiché ? |
|---|---|---|---|---|---|
| « …en traversant **14 gares officielles** (Colobane, Pikine, Rufisque...) » | `2938` | 14 gares TER | **13** (`ter_dakar_diamniadio`) | **+1** | ✅ **oui**, assistant |
| « **72 lignes AFTU** couvrent tout Dakar (Parcelles, Grand Yoff, Petersen...) » | `2950` | 72 lignes AFTU | **80** (`operator_id: aftu`) | **−8** | ✅ **oui**, assistant |
| `label: 'AFTU (72 Lignes Officielles)'` | `297` | 72 lignes | **80** | −8 | ❌ **non** (`label` jamais rendu, G9-H08) |

  Comptage vérifié sur le JSON : `aftu` **80** lignes · `ddd` **15** · `tata` **7** · `brt` **2** ·
  `ter` **1** = **105**. **0 test** ne porte sur « 72 » (grep `72 lignes|72 Lignes` sur `test/` → 0).
  Git : la chaîne « 14 gares officielles » existe **à l'identique** dans la source pré-force-push
  `2c72e576` (L2120) ; le Groupe 5 (`87f54d6`) n'a corrigé que le badge d'Alertes
  (`'14 Gares Officielles'` → `'13 Gares Officielles'`, L2422). **Aucune régression** : les deux
  erreurs sont d'origine.
  À l'inverse, les textes d'Alertes sont **exacts** : « 13 Gares » (L2418, L2420, L2422) et
  « 23 stations » (commentaire L2432) correspondent bien au JSON.
- **Comportement actuel** : l'assistant contredit la source unique **et** les textes d'Alertes de la
  même application — qui, eux, sont exacts. Les qualificatifs « officielles » et « Officielles »
  renforcent des affirmations erronées. « toutes les 10 à 20 min » (L2938) reprend en outre les
  constantes non sourcées de L260 (§E.3).
- **Impact** : deux erreurs factuelles chiffrées, visibles, dans une zone **verrouillée**
  (`AIChatPage`) — à traiter dans le lot IA, pas ici.

---

**G9-H11** · 🟠 · `lib/main.dart:2468-2471`

- **Preuve** : carte d'alerte DDD — `'source': 'Source officielle : Direction DDD'`,
  `'badge': 'Réseau actif'`, `'message': '…aux horaires habituels.'` Or **18 des 32 arrêts DDD
  sont `FIELD_OBSERVATION`** (§G.1) et **aucun horaire DDD n'existe** (`schedule = []`, L965).
- **Comportement actuel** : trois affirmations statiques — source officielle, réseau actif,
  horaires habituels — dont aucune n'est dérivée de la donnée ni vérifiée par un mécanisme.
- **Impact** : l'écran Alertes est le **seul** endroit où un texte explicite de fiabilité est
  affiché ; c'est aussi celui qui contredit le plus directement le `data_trust` réel.

---

**G9-H12** · 🟠 · `lib/main.dart:2960`

- **Preuve** : « 🚨 **Alertes en temps réel** : consulte l'onglet "Alertes" (CETUD/SETER) et
  "Direct rue" (signalements usagers)… ». Les cartes d'Alertes sont des **littéraux statiques**
  (L2392-2475) ; « Direct rue » affiche `'Sans horodatage'` (L2574-2575). Git : la chaîne est
  **absente** du binaire de production (`« Alertes en temps réel » → 0 occurrence`), donc
  **postérieure** au build déployé. Le Groupe 6 a retiré la formulation équivalente de
  `CommunityAlertsPage` (commentaire L2667-2672) mais **pas** celle-ci.
- **Impact** : revendication de temps réel sans aucun flux. Incohérente avec la correction E.4/E.5
  du Groupe 6 appliquée au même concept, à 300 lignes de distance. Recoupe Groupe 8 **H-09**.

---

**G9-H13** · 🟠 · `test/` — 0 référence à `DataSourceInfo`, `badgeEmoji`, `sourceForOperator`, `DataOrigin`

- **Preuve** : §I.2. Les 18 occurrences de `badge` dans `test/` concernent toutes les cartes
  d'alerte statiques. Les 15 occurrences de `DataTrust` s'arrêtent au **parser** et au **JSON**
  (§I.3). Aucun test ne vérifie la propagation vers l'UI — et G9-H01 la rend impossible.
- **Impact** : le **seul marqueur de fiabilité réellement visible** (l'émoji de L2161) n'est couvert
  par **aucun** test. Toute modification de `sourceForOperator` passerait inaperçue. Les 7 tests
  `DataTrust` donnent l'apparence d'une couverture de la fiabilité alors qu'ils ne testent que la
  lecture du JSON.

---

**G9-H14** · 🟠 · `lib/services/data_service.dart:40-142` (`_loadFallbackData`)

- **Preuve** : si `rootBundle.loadString` ou `json.decode` lève (L34-37), l'application bascule sur
  **4 opérateurs, 6 arrêts et 5 lignes codés en dur**, dont :
  - `line_brt_b1` — `shortName: 'BRT B1'`, **`stopIds: ['stop_petersen','stop_guediawaye']`** :
    **2 stations**, alors que la règle établie est **23** ;
  - `line_tata_219` — `operatorId: 'aftu'` pour une ligne **Tata** ;
  - `brt_1` — `shortName: 'BRT Ligne 1'`, identifiant absent du JSON réel.
  **0 test** ne déclenche ce chemin (§I.5).
- **Comportement actuel** : chemin atteignable en production (asset manquant, JSON corrompu,
  erreur de décodage). Il produirait un réseau à 6 arrêts, un BRT B1 à 2 stations, et des badges
  🟢/🔵 attribués par `sourceForOperator` sur ces identifiants.
- **Impact** : latence élevée mais portée totale — **contredit frontalement le modèle 23 stations**
  verrouillé par §7, et par 57 tests qui, eux, ne s'exécutent que sur le chemin nominal.

---

**G9-H15** · 🟠 · `lib/main.dart:2230`

- **Preuve** : `TripsPage` affiche en en-tête « **Itinéraires multimodaux officiels** (TER, BRT,
  DDD, TATA, AFTU). » Les itinéraires sont produits par `_buildRoute` (L1144-1157) : distance
  haversine, vitesse **35/20 km/h codée en dur** (L1146), durée `ceil(dist/speed*60)` avec plancher
  5 min (L1147-1148), heure de départ issue de la suite synthétique (L1151).
- **Impact** : le mot « officiels » qualifie un **calcul** dont aucun paramètre ne provient d'un
  opérateur. OSRM n'est pas utilisé ici (uniquement pour les polylignes, L1716).

---

**G9-H16** · 🟠 · `lib/main.dart:2422`, `:2461`

- **Preuve** : `'13 Gares Officielles'` et `'Données officielles'` sont des **littéraux** dans une
  liste statique (L2392-2475). Le commentaire L2446-2455 justifie le second par
  `brt_b1_guediawaye_petersen.data_trust == 'OFFICIAL'`, et le test
  `groupe6_alertes_test.dart:276-285` vérifie cette **justification** — mais le badge lui-même
  n'est **pas dérivé** de la donnée.
- **Comportement actuel** : si le `data_trust` du JSON passait à `FIELD_OBSERVATION`, le badge
  afficherait toujours « Données officielles ». Le test échouerait, l'interface non.
- **Impact** : couplage **documenté mais non implémenté**. Le seul badge textuel de fiabilité de
  l'application repose sur une convention de commentaire, pas sur un lien de code.

---

**G9-H17** · 🟠 · `lib/main.dart:719`, `:631`, `:731`, `:737` — **origine non démontrable**

- **Preuve de l'état, pas de l'intention** : `DataStatus` n'est **jamais lu** (§D.4). Git prouve
  qu'il en était **déjà ainsi** dans `2c72e576` : 11 occurrences, toutes structurelles
  (L403, 410, 417, 480, 492, 493, 498, 499, 810, 811, 827) — déclaration, défauts, `copyWith`,
  assignations `scheduled`. **0 lecture**, **0 assignation de `live` ou `unknown`**, déclaration
  `enum DataStatus { scheduled, live, unknown }` **identique** à L480.
- **Comportement actuel** : le triplet SCHEDULED / REAL_TIME / UNKNOWN du cahier des charges est
  **inopérant** depuis l'origine accessible du projet.
- **Impact** : dette pure — 3 classes portent un champ inutile, et 2 tests verrouillent une
  déclaration sans effet. **La raison d'être de cet enum n'est écrite nulle part** : ni
  commentaire, ni documentation, ni commit. Cf. §K.

### 🟡 À DOCUMENTER

---

**G9-H18** · 🟡 · `lib/models/transport_network.dart:26` — la branche `default:` de `fromString`
produit `estimated` pour **toute** valeur absente ou non reconnue, silencieusement. Le JSON actuel
ne contient **aucune** valeur `ESTIMATED` (§E.2), donc `DataTrust.estimated` n'est **jamais produit
par les données** — seulement par le fallback de parsing. Non testé (§I.5). Un `data_trust`
mal orthographié deviendrait `estimated` sans aucun signal — et comme rien ne lit la valeur,
l'effet serait de toute façon invisible.

**G9-H19** · 🟡 · `lib/models/transport_network.dart:51, 83, 123` — les trois `toJson()` ont
**0 site d'appel** dans `lib/`. La sérialisation inverse (`dataTrust.toLabel()`, L88 et L129) est
donc **inatteignable à l'exécution**. Ce sont les **2 seules lectures** de `.dataTrust` de tout
`lib/` : la valeur n'est lue que par du code mort et par des tests.

**G9-H20** · 🟡 · `lib/models/transport_network.dart:30-54` (`class Operator`) et
`assets/data/dakar_network.json` — les **5 opérateurs n'ont aucun `data_trust`** : le JSON ne
porte cette clé que sur `stops` et `routes`. Vérifié : `{'<absent>': 5}`. La confiance d'un
exploitant n'est donc jamais exprimée par la source, alors que c'est précisément ce que le badge
🟢/🔵 prétend conveyer.

**G9-H21** · 🟡 · `lib/main.dart:289` + `:719` + `transport_network.dart:5` — **quatre valeurs
déclarées et jamais atteignables** réparties sur trois enums : `DataOrigin.unavailable` (jamais
assigné), `DataStatus.live` (jamais assigné), `DataStatus.unknown` (jamais assigné),
`DataTrust.estimated` (jamais produit par les données). Le vocabulaire de fiabilité déclaré compte
**10 valeurs** ; **6** sont effectivement produites ; **0** est lue.

**G9-H22** · 🟡 · `lib/main.dart:1014-1040` — le chemin « orphelins » attribue d'office
`label = 'AFTU'` (L1019), `direction: 'Dir. Centre Dakar'`, `distanceMeters: 500`,
`departureMinutesFromMidnight: []` → donc badge 🔵 et « 5 min » **sans aucune source**.
**Dormant** : 117 arrêts créés par les lignes = 117 arrêts du JSON, **0 orphelin**. Deviendrait
actif si le JSON ajoutait un arrêt non rattaché à une ligne. Recoupe Groupe 8 **H-18**.

**G9-H23** · 🟡 · `lib/main.dart:2796` — `Icons.verified` est utilisé comme icône décorative de la
ligne « Version de l'application ». Aucun lien avec `DataOrigin.verified`. Risque de confusion
limité au lecteur de code, pas à l'utilisateur.

**G9-H24** · 🟡 · `lib/main.dart:367`, `:3043`, `:3054` — homonymie : `DetailedRoute.origin` est un
**nom de lieu** (`String origin` / `String destination`), sans rapport avec `DataSourceInfo.origin`
(`DataOrigin`). Le rendu `'${route.origin} ➔ ${route.destination}'` (L3054) affiche un trajet, pas
une provenance. Aucune anomalie fonctionnelle ; risque de confusion en maintenance.

**G9-H25** · 🟡 · `lib/main.dart:3107` — la fiche de ligne affiche `'Heure : ${stop.estimatedTime}'`
précédé de `Icons.access_time`, où `estimatedTime = '~' + (arrêts précédents × 3) + ' min'`
(L388, L489, L495). Une **durée cumulée** est présentée sous le mot **« Heure »**, sans qualificatif
d'estimation alors que le préfixe `~` est le seul indice. Recoupe Groupe 8 **H-30**.

**G9-H26** · 🟡 · `lib/main.dart:1194-1203`, `:3278` — `getCrowdLevel(Stop stop)` **n'utilise pas
son paramètre** : étiquette purement horlogère, **identique pour les 141 arrêts**, affichée en gras
sous l'intitulé **« Affluence »**. Aucune donnée d'affluence n'existe. Production-fidèle.

### 🟢 CONFORME / POSITIF

---

**G9-H27** · 🟢 · `lib/models/transport_network.dart` — **intègre et inchangé**. Git : le fichier
est **octet pour octet identique** entre `2c72e576` (source pré-force-push récupérée) et HEAD
`79a49fc` — md5 `04c1c59463c258818ba8dd078c9b9c6a` dans les deux cas, 4 877 octets, 192 lignes.
`DataTrust` n'a **jamais** été modifié, appauvri ni contourné dans le modèle. La perte se situe
**en aval**, dans `main.dart`.

**G9-H28** · 🟢 · **Aucun badge mensonger de type « LIVE »**. `LIVE` **0 occurrence**, `Live`
**0 occurrence**, « En direct » **1 occurrence en commentaire uniquement** (L2446). Git prouve le
retrait : `'badge': 'En direct'` existait à `2c72e576` (L1674) et a été remplacé par
`'badge': 'Données officielles'` par le Groupe 6 (`0e2a157`), avec justification documentée
(L2446-2455) et test (`groupe6_alertes_test.dart:276-285`). `DataStatus.live` n'est assigné nulle
part, et **deux tests** le garantissent.

**G9-H29** · 🟢 · **Aucune donnée de confiance n'est inventée.** `sourceForOperator` ne fabrique
aucune valeur : elle projette un `operatorId` réel du JSON sur une constante existante.
`DataTrust.estimated` n'est jamais produite artificiellement. `DataOrigin.unavailable` jamais
assignée. Aucun statut `REAL_TIME` n'est introduit — les 3 occurrences de `REAL_TIME` sont des
commentaires d'**interdiction** (L1340, L1371, L2455).

**G9-H30** · 🟢 · **Le JSON porte une confiance réelle et exploitable.** 117 arrêts et 105 lignes
ont un `data_trust` valide, reconnu par le parser (`network_data_test.dart:296-305` le vérifie).
Git : les `routes` sont **inchangées** entre `2c72e576` et HEAD (105 lignes, 14 `OFFICIAL`,
91 `FIELD_OBSERVATION`). Les `stops` ont été **enrichis** par le Groupe 1 (`f3f5145`) :
92 → 117 arrêts, `OFFICIAL` 28 → 55, `FIELD_OBSERVATION` 64 → 62. La base de donnée de confiance
s'est donc **améliorée** — c'est son exploitation qui fait défaut.

---

## K — Éléments prouvés / non prouvables

### K.1 PROUVÉ PAR LE CODE

| # | Fait | Preuve |
|---|---|---|
| C1 | `DataTrust` a 3 valeurs : `official`, `fieldObservation`, `estimated` | `transport_network.dart:5` |
| C2 | `fromString` a une branche `default:` → `estimated` | `transport_network.dart:26` |
| C3 | `BusStop` et `TransportRoute` portent `dataTrust` ; `Operator` **non** | `:63`, `:98`, `:30-54` |
| C4 | **0 lecture** de `.dataTrust` dans `lib/main.dart` | grep exhaustif ; 3 mentions, toutes commentaires |
| C5 | Les **2 seules** lectures de `.dataTrust` sont dans `toJson()`, qui a **0 site d'appel** | `:88`, `:129` ; grep `toJson()` → 3 déclarations, 0 appel |
| C6 | `class Stop` a 12 champs, **aucun** de confiance | `main.dart:628-643` |
| C7 | La conversion `BusStop → Stop` ne lit que `name`, `id`, `latitude`, `longitude` | `main.dart:968-982` |
| C8 | Le badge vient **exclusivement** de `operatorId` | `main.dart:925-933` |
| C9 | `DataOrigin` n'est **jamais comparé ni branché** | grep `origin ==`, `case DataOrigin` → 0 |
| C10 | `DataSourceInfo.label` n'est **jamais affiché** ; `badgeEmoji` l'est à **1 seul** endroit | grep `.label` → 0 rendu ; `main.dart:2161` |
| C11 | `DataStatus` n'est **jamais lu** dans `lib/` | §D.4, inventaire exhaustif des `.status` |
| C12 | `DataStatus` a **6** affectations, toutes `scheduled` ; `live` et `unknown` **0** | `647, 732, 738, 1156, 1157, 1173` |
| C13 | `DataStatus.realTime` **n'existe pas** | `main.dart:719` ; `REAL_TIME` = 3 commentaires |
| C14 | **Aucun** timestamp dans aucun modèle de `lib/` | grep `timestamp\|updatedAt\|lastUpdate\|horodat` |
| C15 | **Aucune** API horaire : 2 endpoints seulement (OSRM routing, tuiles OSM) | `main.dart:134, 1919, 3070` |
| C16 | Aucun horaire codé en dur n'a d'origine documentée : 19 constantes sur 21 sans source | §E.3 |
| C17 | L'assistant énonce des heures absolues via `_formatRouteResult` | `main.dart:2884`, `1157`, `1151`, `1178` |
| C18 | L'assistant n'a **aucun** intent horaire | grep `horaire\|prochain\|depart\|quelle heure\|passe a` dans `AIChatPage` → 0 |
| C19 | « inconnu » a **8 occurrences, toutes en commentaires** | §F.1 |
| C20 | « Programmé », « Estimé », « Inconnu », « Synthétique », « Approximatif » : **0 face utilisateur** | §F.1 |
| C21 | 3 fenêtres de service indépendantes et contradictoires | `674-681`, `1103`, `2116` |
| C22 | `getCrowdLevel` n'utilise pas son paramètre `stop` | `main.dart:1194-1203` |
| C23 | `_loadFallbackData` code en dur 6 arrêts, 5 lignes, dont un « BRT B1 » à **2 stations** | `data_service.dart:40-142`, `:132-136` |
| C24 | 2 tests verrouillent textuellement la déclaration de `DataStatus` | `gps_position_test.dart:509-513`, `:531-541` |
| C25 | **0 test** sur `DataSourceInfo`, `badgeEmoji`, `sourceForOperator`, `DataOrigin` | §I.2 |
| C26 | Les 7 tests `DataTrust` s'arrêtent au parser et au JSON | §I.3 |
| C27 | 5 écrans de navigation + 4 écrans secondaires | `main.dart:1604-1610`, `1627-1631`, `2812`, `3030`, `3131`, `3212` |
| C28 | Le test placeholder O21 est inchangé | `dakar_bounds_test.dart:162-167` |

### K.2 PROUVÉ PAR LES DONNÉES (`dakar_network.json`, md5 `81c778f4…18f0`)

| # | Fait | Valeur mesurée |
|---|---|---|
| D1 | 3 clés racines, aucun champ horaire | `operators` 5 · `stops` 117 · `routes` 105 |
| D2 | Clés de `stops` | `id`, `name`, `latitude`, `longitude`, `data_trust` — **5 seulement** |
| D3 | Clés de `routes` | `id`, `operator_id`, `short_name`, `long_name`, `type`, `data_trust`, `stops` — **7 seulement** |
| D4 | Clés d'`operators` | `id`, `name`, `color` — **aucun `data_trust`** |
| D5 | `data_trust` des arrêts | **55 `OFFICIAL`** / **62 `FIELD_OBSERVATION`** / **0 `ESTIMATED`** / 0 absent |
| D6 | `data_trust` des lignes | **14 `OFFICIAL`** / **91 `FIELD_OBSERVATION`** |
| D7 | Les 62 `FIELD_OBSERVATION` par opérateur | AFTU **37** · DDD **18** · Tata **7** · TER **0** · BRT **0** |
| D8 | Les 18 arrêts DDD `FIELD_OBSERVATION` | **identifiés nominativement**, §G.1 |
| D9 | TER | 1 ligne `ter_dakar_diamniadio`, `data_trust: OFFICIAL`, **13 gares**, 13/13 arrêts `OFFICIAL` |
| D10 | BRT | 2 lignes, `OFFICIAL` ; B1 **23 stations** (23/23 `OFFICIAL`), B2 Express **7** (7/7 `OFFICIAL`), B2 ⊆ B1 |
| D11 | Types de lignes | `TER` 1 · `BRT` 2 · `BUS` 102 — **aucun `TATA`** |
| D12 | Aucun champ de sens / direction | 0 `direction`, 0 `headsign`, 0 `toward` |
| D13 | `ESTIMATED` absent du JSON | **0 occurrence** → `DataTrust.estimated` jamais produit par les données |

### K.3 PROUVÉ PAR GIT

Historique disponible : **20 commits** (`f3f5145` … `79a49fc`), **plus** le commit récupéré
`2c72e576` (source pré-force-push, 260 commits d'origine, accessible via l'API GitHub).

| # | Fait | Preuve Git |
|---|---|---|
| G1 | `transport_network.dart` est **octet pour octet identique** entre `2c72e576` et HEAD | md5 `04c1c59463c258818ba8dd078c9b9c6a` dans les deux cas ; 4 877 octets ; 192 lignes |
| G2 | Le bloc `DataSourceInfo` (6 constantes, libellés, émojis, origins) est **identique caractère pour caractère** | `2c72e576:213-223` vs `HEAD:289-299` |
| G3 | Comptes **identiques** hist/actuel : `DataOrigin` 8=8, `DataSourceInfo` 43=43, `badgeEmoji` 9=9, `_generateSchedule` 3=3, `_terBase` 10=10, `_brtBase` 6=6, `nextDepartureLabel` 2=2, `remainingMinutes` 2=2, `nextDepartureMinutes` 3=3, `departureAfter` 2=2, `_isServiceOpen` 5=5, `isContinuousFlow` 8=8, `getCrowdLevel` 3=3 | grep comparatif sur les deux blobs |
| G4 | **`data_trust` n'a jamais été lu par `main.dart`**, à aucune date accessible | `2c72e576` : `DataTrust` **0**, `dataTrust` **0**, `data_trust` **0**. HEAD : 3 mentions, toutes commentaires |
| G5 | `DataStatus` était **déjà write-only** dans la source pré-force-push | `2c72e576` : 11 occurrences, toutes structurelles (L403, 410, 417, 480, 492-493, 498-499, 810-811, 827) ; déclaration L480 **identique** ; 0 lecture |
| G6 | **Badge d'Alertes BRT changé** : `'En direct'` → `'Données officielles'` | `2c72e576:1674` vs `HEAD:2461` ; commit `0e2a157` (Groupe 6), diff explicite, justification L2446-2455 |
| G7 | **Badge d'Alertes TER changé** : `'14 Gares Officielles'` → `'13 Gares Officielles'` | `2c72e576:1664` vs `HEAD:2422` ; commit `87f54d6` (Groupe 5) |
| G8 | Badge `'Réseau actif'` **inchangé** | `2c72e576:1684` = `HEAD:2471` |
| G9 | « 14 gares officielles » dans l'assistant est **d'origine**, pas une régression | `2c72e576:2120` = `HEAD:2938`, chaîne identique |
| G10 | Le JSON a été **remplacé** par le Groupe 1 | md5 hist `05685bf95af3ba9969b69da92a31eee3` ≠ actuel `81c778f4…` ; commit `f3f5145` |
| G11 | `data_trust` des **routes inchangé** ; celui des **stops enrichi** | hist 105 lignes 14/91 = actuel ; hist 92 arrêts 28 `OFFICIAL`/64 `FIELD_OBSERVATION` → actuel 117 arrêts 55/62 |
| G12 | Groupe 6 a retiré « Signalements en temps réel par les usagers à Dakar. » | présent dans le binaire gh-pages, absent du source ; commit `0e2a157` |
| G13 | « Alertes en temps réel » (L2960) est **postérieur** au build déployé | **0 occurrence** dans le binaire `94a84b60` |
| G14 | L'intent horaire de l'assistant existait en production et a disparu du source | binaire : `…"quelle heure"‖…"passe a" → "Prochain départ : "+IM()` ; source : 0 branche équivalente |
| G15 | Le badge système n'a **jamais** été modifié depuis l'origine accessible | G2 + G3 |

### K.4 NON DÉMONTRABLE avec l'état actuel du projet

| # | Question | Pourquoi |
|---|---|---|
| N1 | **Pourquoi `DataStatus` a-t-il été créé ?** | Aucune intention écrite : 0 commentaire sur l'enum (L719 est une ligne nue), 0 documentation dans `docs/`, 0 message de commit l'évoquant. Git prouve qu'il était **déjà** inutilisé en `2c72e576`, mais les 260 commits antérieurs sont **inaccessibles** (force-push `d179fe16`). **L'intention d'origine est INCONNUE / NON DÉMONTRABLE.** |
| N2 | **`DataStatus` a-t-il déjà été utilisé avant `2c72e576` ?** | INCONNU / NON DÉMONTRABLE — historique antérieur détruit |
| N3 | **Le système de badge 🟢/🔵 existait-il avant le Groupe 1 ?** | **Oui, prouvé** : il est présent en `2c72e576` (G2). En revanche **qui l'a introduit et pourquoi** : INCONNU / NON DÉMONTRABLE |
| N4 | **D'où viennent les constantes horaires** (330, 1320, 10, 20, 360, 1260, 6, 5, 180, 35, 20 km/h) ? | Aucun commentaire, aucune source citée, aucun ticket, aucun test. Elles existent déjà en `2c72e576` (comptes identiques, G3). **Origine INCONNUE / NON DÉMONTRABLE** |
| N5 | **Pourquoi l'horizon vaut-il 180 minutes ?** | INCONNU / NON DÉMONTRABLE (déjà établi en Groupe 8 §F) |
| N6 | **Les horaires synthétiques correspondent-ils à une grille réelle SETER/SunuBRT ?** | **INCONNU / NON DÉMONTRABLE.** Aucune source externe dans le dépôt, aucune référence, aucun document. Rien ne permet d'affirmer ni d'infirmer une correspondance |
| N7 | **Cause du bug historique 1199/1189 à 14 h 41** | INCONNU / NON DÉMONTRABLE (Groupe 8 §6). L'impossibilité **actuelle** est en revanche prouvée |
| N8 | **Le `data_trust` du JSON reflète-t-il une évaluation réelle du CETUD ?** | Le commentaire `transport_network.dart:4` affirme « Aligné avec CETUD/SETER », mais **aucun document, aucune source, aucune date** ne l'étaye. **NON DÉMONTRABLE** |
| N9 | **Les 37 AFTU et 7 Tata `FIELD_OBSERVATION` ont-ils été relevés sur le terrain, et quand ?** | Aucun champ de date, aucun auteur, aucune note dans le JSON. **NON DÉMONTRABLE** |
| N10 | **`data_trust` a-t-il déjà atteint l'interface dans une version antérieure ?** | **Non**, pour tout l'historique accessible (G4). Au-delà de `2c72e576` : NON DÉMONTRABLE |

---

## K.5 — Erratum portant sur le rapport Groupe 8

Le rapport Groupe 8 (`docs/dakar-bus/groupe-8/AUDIT_HORAIRES_DEPARTS.md`, commit `79a49fc`)
indique, dans ses sections J, K, L et E.2, des **comptes de lignes** qui sont **faux**. Recomptage
vérifié sur `dakar_network.json` (md5 `81c778f4644dcf5e1cf4ae25879218f0`) :

| Réseau | Groupe 8 (erroné) | **Valeur réelle** | Arrêts créés (corrects dans G8) |
|---|---|---|---|
| TER | 1 | **1** ✅ | 13 ✅ |
| BRT | 2 | **2** ✅ | 23 ✅ |
| AFTU | 78 | **80** ❌ | 41 ✅ |
| Tata | 4 | **7** ❌ | 8 ✅ |
| DDD | 23 | **15** ❌ | 32 ✅ |
| **Total** | 108 ❌ | **105** ✅ | **117** ✅ (+ 24 littéraux = 141) |

**Portée de l'erreur : limitée aux comptes de lignes.** Toutes les autres valeurs du Groupe 8 sont
re-vérifiées et **confirmées** : 117 arrêts JSON, 24 littéraux, 141 au total, **81 arrêts en flux
continu** (41 + 8 + 32), 13 gares TER, 23 stations B1, 7 B2, 55 `OFFICIAL` / 62
`FIELD_OBSERVATION`, 14 / 91 pour les lignes, les 18 arrêts DDD, les constantes horaires, le
plafond 180, le maximum 104 min, les 232 tests et les 27 points de comparaison avec la production.
Le total erroné (108) aurait dû alerter : le JSON en porte 105.

**Le rapport Groupe 8 n'a PAS été modifié** : la consigne du Groupe 9 autorise uniquement la
création de `docs/dakar-bus/groupe-9/AUDIT_DATA_TRUST_STATUT.md`. Cet erratum est donc porté ici,
et la correction du document Groupe 8 est laissée à la décision du produit.

---

## L — Décisions produit encore nécessaires

Aucune décision n'est prise ici. Ces choix **doivent** être tranchés avant toute implémentation,
car chacun change ce que l'utilisateur voit.

### L.1 Décisions bloquantes — aucune correction possible sans elles

| # | Décision | Options observables dans le code actuel | Contrainte technique |
|---|---|---|---|
| **P1** | **Que doit qualifier le badge visible ?** | (a) l'exploitant — comportement actuel ; (b) la confiance de l'arrêt (`data_trust`) ; (c) la fiabilité de l'horaire ; (d) les trois, séparément | (b) et (c) exigent un **nouveau champ** sur `Stop` (G9-H01) ; (d) exige plusieurs marqueurs visuels |
| **P2** | **Un horaire synthétique doit-il être nommé comme tel ?** | (a) oui, texte explicite ; (b) oui, mais discrètement (`~`, « estimation ») ; (c) non, l'heure reste nue — état actuel | Le mot « Estimé » a **0 occurrence** aujourd'hui ; toute option ajoute du texte utilisateur |
| **P3** | **`data_trust` doit-il piloter le badge ?** | (a) oui → **62 arrêts sur 117 changent de badge** ; (b) non, il reste informatif | (a) rétrograde 18 arrêts DDD de 🟢, et 44 arrêts AFTU/Tata de 🔵 |
| **P4** | **Que faire des 4 valeurs mortes ?** (`DataStatus.live`, `.unknown`, `DataOrigin.unavailable`, `DataTrust.estimated`) | (a) les utiliser ; (b) les supprimer ; (c) les conserver en garde-fou déclaré | **(b) casse 2 tests** (`gps_position_test:509-513` et `:531-541`) qui verrouillent la déclaration textuelle |
| **P5** | **L'assistant peut-il énoncer une heure absolue ?** | (a) oui sans réserve — actuel ; (b) oui avec réserve ; (c) non, seulement des intervalles ; (d) non, seulement « je ne connais pas les horaires réels » | `AIChatPage` est une **zone verrouillée** ; décision à coupler avec le lot IA |

### L.2 Décisions de second niveau

| # | Décision | Enjeu |
|---|---|---|
| **P6** | Faut-il un **timestamp** sur les données ? | Sans lui, « TEMPS RÉEL » et « mis à jour en continu » restent irreprésentables (G9-H04, G9-H09). En ajouter suppose une source de mise à jour, qui n'existe pas |
| **P7** | Le texte « mis à jour en continu » (L2786) doit-il être **retiré** ou **tenu** ? | Engagement contractuel affiché, aucun mécanisme (G9-H09) |
| **P8** | « Itinéraires multimodaux **officiels** » (L2230) : qualificatif à conserver ? | Les itinéraires sont calculés avec des vitesses codées en dur (G9-H15) |
| **P9** | La carte DDD « Source officielle » + « aux horaires habituels » (L2468-2469) : à corriger ? | 18 arrêts `FIELD_OBSERVATION`, 0 horaire (G9-H11) |
| **P10** | Les badges d'Alertes doivent-ils être **dérivés** de la donnée plutôt que littéraux ? | Actuellement justifiés par commentaire et par test, mais non couplés au code (G9-H16) |
| **P11** | `source.label` doit-il être affiché quelque part ? | C'est le seul texte explicite de provenance ; il existe et n'est jamais montré (G9-H08) |
| **P12** | Le fallback `DataService` (6 arrêts, BRT B1 à 2 stations) doit-il être **conservé, aligné ou supprimé** ? | Contredit le modèle 23 stations verrouillé par §7 (G9-H14) |
| **P13** | Faut-il un état **« horaire inconnu »** visible ? | Le mot « inconnu » a 0 occurrence face utilisateur ; « Bientôt » et « Prochainement » masquent l'absence (Groupe 8 H-05) |
| **P14** | L'affluence horlogère (L1194-1203) doit-elle rester présentée comme « Affluence » ? | Aucune donnée d'affluence n'existe (G9-H26) |

### L.3 Ce qui n'est **pas** une décision produit

Points purement techniques, ne changeant rien de visible — à traiter après L.1/L.2 :
`toJson()` mort (G9-H19), homonymie `origin` (G9-H24), `Icons.verified` décoratif (G9-H23),
branche `default:` silencieuse (G9-H18), chemin orphelin dormant (G9-H22),
libellé « Heure : » pour une durée (G9-H25).

---

## M — Conclusion

**Question : quelle est aujourd'hui la représentation réelle de la fiabilité des horaires dans
Dakar Bus ?**

**Il n'en existe aucune.**

La fiabilité des **horaires** n'est représentée **à aucun niveau** du système :

- **dans la source** : `dakar_network.json` ne contient **aucun horaire** — 0 champ sur 117 arrêts
  et 105 lignes. Il n'y a donc aucune fiabilité horaire à déclarer, puisque aucune donnée horaire
  n'existe ;
- **dans le modèle** : la classe `Stop` porte 12 champs, dont `status` (`DataStatus`) et `source`
  (`DataSourceInfo`) — **ni l'un ni l'autre ne qualifie un horaire**. `status` n'est **jamais lu** ;
  `source` qualifie un **exploitant**. Aucun champ ne porte de timestamp, donc la fraîcheur est
  irreprésentable ;
- **dans le calcul** : les horaires proviennent de **21 constantes codées en dur**, dont **19 sans
  aucune origine identifiable** ;
- **dans l'affichage** : les mots « Programmé », « Estimé », « Inconnu », « Synthétique »,
  « Approximatif » ont **0 occurrence face utilisateur**. Le seul marqueur visible est un **émoji**
  (🟢/🔵/🟡) rendu à **un unique endroit** (L2161), dérivé du seul `operatorId`, et dont le texte
  explicite (`label`) n'est **jamais montré**.

Il existe bien **deux** vocabulaires de fiabilité dans le code — `DataTrust` (3 valeurs) et
`DataOrigin` (4 valeurs) — et un troisième, `DataStatus` (3 valeurs). **Sur les 10 valeurs
déclarées, 6 sont effectivement produites, et 0 est lue.** `DataTrust` est la seule à être
réellement alimentée par la source (117 arrêts, 105 lignes) ; elle est **intégralement perdue** à
la conversion `BusStop → Stop` (`main.dart:968-982`), et cette perte est **structurelle** : `Stop`
n'a aucun champ pour la recevoir.

Ce que l'utilisateur voit effectivement, et qui constitue **toute** la représentation actuelle de
la fiabilité :

| Ce qui est montré | Où | Ce que cela qualifie réellement |
|---|---|---|
| 🟢 / 🔵 / 🟡 | `StopCard` L2161, 141 arrêts | **l'identité de l'exploitant**, pas la donnée |
| « 13 Gares Officielles » | Alertes L2422 | un **littéral statique**, non dérivé |
| « Données officielles » | Alertes L2461 | un **littéral statique**, justifié par commentaire |
| « Source officielle : … » | Alertes L2419, 2458, 2468 | un **littéral statique** |
| « Itinéraires multimodaux officiels » | Trajets L2230 | un **calcul** à vitesses codées en dur |
| « …officielles … mis à jour en continu » | Réglages L2786 | un **engagement** sans mécanisme |
| « 14 gares officielles » | Assistant L2938 | une affirmation **erronée** (le JSON en porte 13) |
| « Alertes en temps réel » | Assistant L2960 | un **flux inexistant** |
| « 15 h 10 → 15 h 55 » | Assistant L2884 | l'index 58 d'une **suite arithmétique** |

Aucun de ces neuf éléments ne qualifie un **horaire**. Tous qualifient autre chose — un
exploitant, un compteur de gares, une intention, un engagement — ou rien du tout.

Et quand un horaire n'est pas connu, l'utilisateur ne voit **jamais** « inconnu » : il voit
**« Bientôt »**, **« Prochainement »** ou **« En rotation (~5 min) »** — trois formulations
positives. Le mot « inconnu » existe **8 fois** dans `lib/`, **toutes en commentaires**.

Git établit que cet état n'est **pas** une régression : le modèle `transport_network.dart` est
**octet pour octet identique** à la source pré-force-push `2c72e576`, le bloc `DataSourceInfo` est
**identique caractère pour caractère**, les 13 symboles de la chaîne horaire ont des **comptes
identiques**, et `data_trust` n'a **jamais** été lu par `main.dart` à aucune date accessible. Les
seuls changements de badge démontrables sont deux **améliorations** (Groupe 5 : « 14 » → « 13 » ;
Groupe 6 : « En direct » → « Données officielles »). La lacune est **originelle**, pas introduite.

---

## Annexe 1 — §17 du cahier des charges : les 7 questions du critère de réussite

| # | Question | Réponse | Statut |
|---|---|---|---|
| **1** | **D'où viennent exactement les horaires actuels ?** | De **21 constantes codées en dur** dans `lib/main.dart`, dont deux suites arithmétiques : `_generateSchedule(from:330, to:1320, step:10\|20)` (L260) pour le TER, `(from:360, to:1260, step:6)` (L261) pour le BRT, décalées de `_shift(base, i*2)` selon l'index de l'arrêt (L961, L963) ; et la constante **5** pour les 81 arrêts AFTU/Tata/DDD (L685, L696). **Aucun** ne provient du JSON (0 champ horaire), d'une API (2 endpoints : OSRM routing + tuiles OSM), ni d'un timestamp (0 dans le modèle). | ✅ **PROUVÉ PAR LE CODE ET LES DONNÉES** |
| **2** | **Les horaires sont-ils réellement officiels ou synthétiques ?** | **100 % synthétiques**, pour les **cinq** réseaux. Ni officiels, ni dérivés de données officielles : aucune donnée horaire officielle n'entre dans le calcul. Ce qui **est** officiel dans le JSON, c'est l'**existence et les coordonnées** des arrêts (13 gares TER, 23 stations B1, 7 B2 en `data_trust: OFFICIAL`) — pas leurs horaires. | ✅ **PROUVÉ PAR LE CODE ET LES DONNÉES** |
| **3** | **Où est stockée la fiabilité de chaque donnée ?** | Dans **deux endroits disjoints, aucun des deux ne qualifiant un horaire**. (1) `DataTrust` — réellement alimenté par la source : `BusStop.dataTrust` (`transport_network.dart:63,79`) et `TransportRoute.dataTrust` (`:98,118`), 117 arrêts + 105 lignes du JSON. (2) `DataSourceInfo.origin` — 4 niveaux (`main.dart:289`), attribués par `sourceForOperator(operatorId)` (L925-933). (3) `DataStatus` — 3 valeurs (L719) sur `Stop`, `RouteSegment`, `PlannedRoute`. **La classe `Stop` n'a aucun champ `dataTrust`.** | ✅ **PROUVÉ PAR LE CODE** |
| **4** | **Cette fiabilité atteint-elle l'utilisateur ?** | **Partiellement, et jamais pour un horaire.** `DataTrust` : **NON** — 0 lecture dans `main.dart`, perdu à L968-982. `DataOrigin` : **NON** — 0 comparaison. `DataSourceInfo.label` : **NON** — 0 rendu. `DataSourceInfo.badgeEmoji` : **OUI**, à **un seul endroit** (L2161), sur les 141 arrêts. `DataStatus` : **NON** — 0 lecture. S'y ajoutent 8 littéraux textuels statiques (§M). Mesure : **62 arrêts sur 117 (53 %)** portent un badge en contradiction avec leur `data_trust` réel. | ✅ **PROUVÉ PAR LE CODE** |
| **5** | **Pourquoi `DataStatus` existe-t-il alors qu'il est pratiquement inutilisé ?** | ⚠️ **Réponse en deux parties.** *Ce qui est prouvé* : il est **né inutilisé** — Git établit qu'en `2c72e576` (source pré-force-push) ses 11 occurrences étaient déjà toutes structurelles, avec 0 lecture et 0 assignation de `live`/`unknown`, et une déclaration identique. Il n'a donc **jamais** fonctionné dans tout l'historique accessible ; ce n'est pas une régression. *Ce qui n'est pas prouvé* : **l'intention de son auteur** → **INCONNU / NON DÉMONTRABLE AVEC L'ÉTAT ACTUEL DU PROJET**. Aucun commentaire sur l'enum, aucune documentation dans `docs/`, aucun message de commit ne l'évoque, et les 260 commits antérieurs à `2c72e576` sont détruits (force-push `d179fe16`). | ⚠️ **PARTIELLEMENT — l'intention est NON DÉMONTRABLE** |
| **6** | **Que voit réellement l'utilisateur lorsqu'un horaire n'est pas connu ?** | **« Bientôt »** (badge `StopCard` L2121), **« Prochainement »** (`nextDepartureLabel` L706) ou **« En rotation (~5 min) »** (L704) — **trois formulations positives**. Jamais « inconnu », jamais « horaire indisponible », jamais « aucune donnée ». Le mot « inconnu » compte **8 occurrences** dans `lib/`, **toutes en commentaires**. Et l'absence totale de départ est annoncée par « Bientôt » jusqu'à **45 minutes** (Groupe 8 H-05). | ✅ **PROUVÉ PAR LE CODE** |
| **7** | **Que faudrait-il décider avant toute correction future ?** | **14 décisions produit**, listées en §L. **5 bloquantes** : P1 ce que le badge doit qualifier · P2 nommer ou non un horaire synthétique · P3 faire piloter le badge par `data_trust` (changerait **62 arrêts sur 117**) · P4 le sort des **4 valeurs mortes** (en supprimer casse **2 tests** qui verrouillent la déclaration) · P5 les heures absolues de l'assistant. **9 de second niveau** : P6 timestamp · P7 « mis à jour en continu » · P8 « officiels » · P9 carte DDD · P10 badges dérivés · P11 afficher `label` · P12 fallback `DataService` · P13 état « inconnu » visible · P14 « Affluence ». | ✅ **PROUVÉ PAR LE CODE** |

**Aucune des 7 réponses n'a été complétée par une supposition.** La seule part non démontrable —
l'intention d'origine de `DataStatus` — est signalée comme telle en question 5 et en §K.4 (N1, N2).

---

## Annexe 2 — §12 du cahier des charges : impact écran par écran

Les 9 écrans de l'application (`main.dart:1604-1610` : 5 onglets ; `2812`, `3030`, `3131`, `3212` :
4 écrans secondaires), avec ce qu'ils affichent aujourd'hui.

| Écran | Fichier:ligne | Donnée affichée | Source | Statut actuel | Badge actuel | Risque de confusion |
|---|---|---|---|---|---|---|
| **Explorer** (carte + liste) | `1643`, `1503` | 141 arrêts, distances, marqueurs | JSON (117) + littéraux (24) ; distances parfois `300+i*800` (L974) | `scheduled` (jamais lu) | 🟢/🔵/🟡 via `StopCard` | 🔴 **élevé** — le badge jouxte une attente synthétique sans qualificatif |
| **`StopCard`** (composant) | `2100-2193` | nom, direction, `distance • mode (🟢) • affluence`, badge d'attente | L2111 `remainingMinutes()`, L2161 `source.badgeEmoji` | `scheduled` | **🟢/🔵/🟡 — seul marqueur de fiabilité de l'app** | 🔴 **élevé** — 4 informations hétérogènes sur une ligne ; 62 arrêts sur 117 en contradiction avec `data_trust` |
| **Détail arrêt** (`DualStopDetailPage` / `SingleStopView`) | `3131`, `3212` | « Prochain départ » + heure ou libellé, « Affluence », aller/retour | L3272 `nextDepartureLabel()`, L3278 `getCrowdLevel()` | `scheduled` | ❌ **aucun badge de fiabilité** | 🔴 **élevé** — heure nue au format `HH h MM`, sans réserve ; affluence horlogère identique pour les 141 arrêts |
| **Trajets** (`TripsPage`) | `2194` | en-tête « Itinéraires multimodaux **officiels** », durée totale, durée par segment | L2230 littéral ; L2344/L2369 `totalMinutes`/`durationMinutes` | `scheduled` | ❌ aucun | 🟠 **moyen** — le mot « officiels » qualifie un calcul à vitesses codées en dur ; champs de saisie pré-remplis (L2201-2202) |
| **Alertes** (`AlertsPage`) | `2387` | 3 cartes statiques avec badges texte | L2392-2475 **littéraux** | — | « 13 Gares Officielles », « Données officielles », « Réseau actif » | 🟠 **moyen** — seul endroit avec un texte explicite, mais non dérivé de la donnée ; la carte DDD contredit `data_trust` (18 `FIELD_OBSERVATION`) |
| **Direct rue** (`CommunityAlertsPage`) | `2543` | signalements de démonstration | L2574-2575 littéraux, `'time': 'Sans horodatage'` | — | ❌ aucun | 🟢 **faible** — le Groupe 6 a retiré « en temps réel » ; « Sans horodatage » est **honnête** |
| **Réglages** (`SettingsPage`) | `2720` | modale d'aide « position GPS **en temps réel** », modale « Conditions d'utilisation » « …**mis à jour en continu** », `Icons.verified` | L2779, L2786, L2796 | — | ❌ aucun | 🟠 **moyen** — deux engagements sans mécanisme ; icône `verified` décorative |
| **Assistant IA** (`AIChatPage`) | `2812` | itinéraires avec **heures absolues**, 12 réponses dont « 14 gares officielles », « Alertes en temps réel », « fonctionnent normalement » | L2884 `_formatRouteResult` ; L2927-2964 | `scheduled` (jamais lu) | ❌ aucun | 🔴 **élevé** — formulation la plus assertive de l'app (« 🕒 15 h 10 ») sur donnée 100 % synthétique ; 3 affirmations non fondées |
| **Fiche ligne** (`DetailedRoutePage`) | `3030` | « **Heure :** ~N min », distance depuis l'origine, 13 gares / 23 stations | L3107 `estimatedTime` = `arrêts × 3` (L388, L489, L495) | — | ❌ aucun | 🟠 **moyen** — une **durée** libellée « Heure » avec `Icons.access_time` ; le `~` est le seul indice d'estimation |

**Synthèse** : **1 seul** des 9 écrans porte un marqueur de fiabilité par arrêt (Explorer, via
`StopCard`) ; **1 seul** porte un texte explicite (Alertes, 3 littéraux statiques) ; **0** n'affiche
`data_trust`, `DataOrigin`, `DataSourceInfo.label` ou `DataStatus`. Les **4** écrans à risque
🔴 sont Explorer/`StopCard`, Détail arrêt, Assistant IA — soit exactement ceux où une heure ou une
attente est montrée.

---

## Annexe 3 — §14 du cahier des charges : vérifications techniques obligatoires

| Vérification | Résultat |
|---|---|
| `git status --porcelain` (avant audit) | ⚠️ clone **réinitialisé** : HEAD retombé sur `ce8c94f`, 3 entrées untracked. **Réparé** par `git fetch --depth 20 origin arena/…` + `git reset --mixed FETCH_HEAD` — **aucun fichier touché**, md5 JSON et tailles vérifiés identiques avant/après |
| `git status --porcelain` (après réparation) | **vide** — arbre propre |
| `git branch --show-current` | `arena/01a0c385-dakar-bus` |
| `git log -1 --oneline` (avant audit) | `79a49fc docs(groupe-8): audit strict de la chaîne horaires → prochains départs → attente → statut` |
| `flutter test` | **impossible localement** — aucun SDK Flutter dans le sandbox (`storage.googleapis.com` et `pub.dev` bloqués, pas de `clang`/`cmake`/`ninja`). **Exécuté par la CI GitHub Actions**, seule voie disponible. Résultat : **232/232** |
| `flutter analyze` | idem — **exécuté par la CI**. Résultat : **0 issue** |
| MD5 `dakar_network.json` | **`81c778f4644dcf5e1cf4ae25879218f0`** — **identique** à la référence |
| HEAD gh-pages | **`94a84b6070569bed708b8e779b9e70b7c9dafa45`** — **identique** à la référence |
| Déploiement | **aucun** |

---

**AUCUNE MODIFICATION FONCTIONNELLE N'A ÉTÉ EFFECTUÉE.**
`lib/` intact · `test/` intact · JSON intact · interface intacte · textes utilisateur intacts ·
horaires intacts · logique intacte · statuts intacts · badges intacts · workflow intact ·
aucun déploiement. Le seul fichier créé est ce rapport.
