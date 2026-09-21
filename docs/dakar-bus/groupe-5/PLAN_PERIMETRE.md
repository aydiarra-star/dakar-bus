# GROUPE 5 — Recherche / Explorer
## PLAN DE PÉRIMÈTRE (audit seul — aucun code modifié)

**Étape :** Step 4B — réintégration contrôlée du comportement récupéré
**Périmètre :** Groupe 5 uniquement (Search / Explorer). Aucun élargissement aux Groupes 6-10.
**Nature du document :** audit et cadrage. Conformément à la règle 6, **aucun code n'a été modifié**, aucun commit de code, aucun déploiement, aucun changement `gh-pages`, aucun changement du JSON actif.
**Statut :** en attente de validation du périmètre avant toute implémentation (règle 9).

---

## 0. Contexte : les Cartes 08 et 15 sont perdues

Les cartes d'analyse 08 et 15 (qui portaient sur Search/Explorer) **n'ont pas été retrouvées** : elles n'ont jamais été commitées et aucune copie n'existe sur le disque. Conformément à la règle 2, **aucune de leurs conclusions n'a été reprise de mémoire**. Conformément à la règle absolue, tout ce qui n'a pas pu être reconstruit de façon vérifiable est marqué **NON PROUVÉ**.

Tout le contenu de ce plan a été **ré-établi depuis zéro** à partir des seuls artefacts disponibles (règle 3) :

| Artefact | Emplacement | Rôle dans la preuve |
|---|---|---|
| Binaire de production | `/tmp/prod/dakar-bus-gh-pages/main.dart.js` (2,49 Mio, md5 `f5466709…`) | comportement réel déployé |
| Source de la branche | `flutter-src/lib/main.dart` (3 084 lignes, md5 `14caf350…`) | comportement actuel du code |
| JSON actif | `flutter-src/assets/data/dakar_network.json` (59 189 o, md5 `81c778f4…`) | source unique de vérité (§4-§5) |
| Outillage gh-pages | `/tmp/prod/dakar-bus-gh-pages/tools/` (`prefetch_osrm.py`, `apply_traces_v2..v6.py`, `track_shapes.py`) | origine des écarts d'infrastructure |

### 0.1 Méthode de décodage (à conserver — un piège a déjà coûté une fausse conclusion)

Une première analyse naïve du binaire avait conclu à tort que « les chaînes accentuées étaient absentes », donc que le binaire ne correspondait pas au source. **Cette conclusion était fausse.** dart2js échappe les caractères non-ASCII en `\xNN` / `\uNNNN` : un `grep` direct sur du texte accentué retourne systématiquement 0 occurrence, même quand la chaîne est présente.

Un décodeur a été écrit (`/tmp/g5/decode.py`, fonctions `load()`, `unesc()`, `find_all()`, `ctx()`) et **validé** : il reconstruit les chaînes littérales avant recherche. **Toute vérification binaire ultérieure doit passer par ce décodeur.** Après décodage, le binaire s'est révélé **pleinement cohérent** avec le source récupéré (mêmes chaînes, mêmes structures, mêmes commentaires Dart).

---

## 1. État initial vérifié (§3)

Vérification effectuée avant toute opération.

### 1.1 Git

| Référence | SHA attendu | SHA constaté | État |
|---|---|---|---|
| `main` | `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` | `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` | ✅ intact, non touché |
| `gh-pages` | `94a84b6070569bed708b8e779b9e70b7c9dafa45` | `94a84b6070569bed708b8e779b9e70b7c9dafa45` | ✅ intact, non touché |
| `arena/01a0c385-dakar-bus` | `16a1b30` | `16a1b30afa89bfca51ac4d92fad2a6727b8e4685` | ✅ branche de travail |

Arbre de travail : **propre**, contenu **byte-identique** au commit Groupe 4 `16a1b30` (vérifié par `git diff --stat` vide).

### 1.2 Anomalie rencontrée et corrigée (sans modification de fichier)

Au démarrage de cette phase, le clone local présentait `HEAD = ce8c94f` avec `flutter-src/` et `.github/workflows/flutter-verify.yml` **non suivis** — le clone avait été réinitialisé entre sessions (panne connue). Un `git diff` dans cet état était **trompeur** : il affichait 8 778 suppressions, car les fichiers non suivis sont invisibles à l'index.

Récupération appliquée, strictement locale et non destructive :

```
git fetch origin arena/01a0c385-dakar-bus
git reset --mixed FETCH_HEAD          # déplace le pointeur + l'index, NE TOUCHE PAS au contenu
```

Résultat : `HEAD = 16a1b30`, branche `arena/01a0c385-dakar-bus`, `git status --porcelain` vide, `git diff` vide. **Aucun force-push, aucun fichier modifié.** Le contenu de travail (commentaires Groupe 4, `GpsResolver`, D1-i, 4000 m, `take(30)`) était bien présent avant et après l'opération.

### 1.3 Application

| Élément | Valeur vérifiée |
|---|---|
| Version | `9.3.2+12` (pubspec.yaml:19) — ✅ conforme §28, aucune v9.4 créée |
| `pubspec.yaml` | md5 `a44209df…`, **inchangé** depuis Groupe 4 |
| Dépendances | `geolocator ^12.0.0` — aucune ajoutée |
| Tests | 7 fichiers, **162 tests** (`dakar_bounds` 17, `data_service` 10, `detailed_route` 37, `gps_position` 40, `network_data` 22, `opposite_stop` 34, `widget` 2) |
| CI | Run de référence `35636348996` — analyze + test **verts** |
| Workflow CI | `.github/workflows/flutter-verify.yml`, Flutter 3.24.5, inchangé |
| JSON actif | md5 `81c778f4…`, 59 189 o — **identique octet par octet au JSON de production** |

### 1.4 Contenu du JSON actif (rappel chiffré)

5 opérateurs, **105 lignes**, 117 arrêts. TER = 13 gares (`ter_dakar_diamniadio`). BRT B1 = 23 stations (`brt_b1_guediawaye_petersen`), B2 = 7 (`brt_b2_express`).

Vérifications complémentaires effectuées pour ce plan :
- **aucun `short_name` dupliqué** parmi les 105 lignes ;
- **0 ligne** avec moins de 2 arrêts valides au sens de `DakarBounds` ;
- une seule ligne entre en collision avec les 4 démos codées en dur : `short_name = 'TER'`.

---

## 2. Fonctionnalités concernées

Le périmètre Groupe 5 couvre la page Explorer et son chemin de données propre. `demoRoutes` n'est consommé **que** par Explorer et par la fonction d'intégration — c'est une frontière de périmètre nette, vérifiée :

| Ligne | Consommateur | Usage |
|---|---|---|
| `main.dart:912` | `_integrateNetworkData` | déduplication par `code` |
| `main.dart:914` | `_integrateNetworkData` | ajout des lignes JSON |
| `main.dart:953` | `_integrateNetworkData` | `debugPrint` de contrôle |
| `main.dart:959` | — | **définition** des 4 démos |
| `main.dart:1551` | `_loadDynamicRoutes` | `where(isDedicated)` — tracés au démarrage |
| `main.dart:1565` | `_lazyLoadRemainingRoutes` | `where(!isDedicated).take(20)` — OSRM différé |
| `main.dart:1703` | `build` | repli si `_dynamicPolylines` vide |

**Aucun autre écran** (RoutePlanner, DetailedRoutePage, AlertsPage, Assistant) ne lit `demoRoutes`. Une modification de `demoRoutes` ne peut donc pas déborder hors d'Explorer.

### Inventaire des fonctionnalités auditées

| # | Fonctionnalité | Localisation source | Localisation binaire |
|---|---|---|---|
| F1 | Champ de recherche + bouton effacer | 1875-1893 | `gRm()`, `A.apt` |
| F2 | Filtrage des résultats de recherche | 1682 | `gRm()` |
| F3 | Filtres par couleur (7 puces) | 1595, 1897 | `gNF()` |
| F4 | Liste « à proximité » (rayon, plafond, tris) | 1621-1630 | `gNF()` |
| F5 | Ligne de comptage des arrêts | 1899-1906 | `""+s+" arrêts"` / `"à proximité"` |
| F6 | Carte : centre, zoom, tuiles | 1703+, `MapOptions` | `B.IR`, `A.aFw` |
| F7 | Recentrage sur un arrêt | 1688 (`_centerOnStop`) | zoom 13.5 |
| F8 | Tracés de lignes au démarrage | 1548-1559 (`_loadDynamicRoutes`) | `A.F1.xw()` |
| F9 | Tracés différés via OSRM | 1561-1593 (`_lazyLoadRemainingRoutes`) | `A.F1.xv()` |
| F10 | Jeu de données de tracés (`demoRoutes`) | 959-988 | `$.J0()` |
| F11 | Intégration JSON → arrêts et tracés | 798-955 | `aW7()` |
| F12 | Service de routage OSRM | 124-157 | `A.aS2()` |
| F13 | `DetailedRoutePage` (frontière, non modifiable) | 2804-2860 | `A.a3g` |

---

## 3. Comportement actuel vs comportement cible

### 3.1 CONFORMES — aucun écart (preuve binaire établie)

Ces éléments sont **identiques** entre le source de la branche et le binaire de production. Ils ne doivent **pas** être touchés.

**F1 — Champ de recherche.** `hintText` identique (`'Où voulez-vous aller ? (ex: Colobane, Yoff...)'`, ligne 1880). Bouton d'effacement binaire `A.apt` : le source le possède déjà, ligne **1883** — `suffixIcon` = `IconButton(Icons.close)` présent uniquement quand `_searchFocused`, avec `_searchCtrl.clear()`. Résultats affichés quand `_searchFocused && _searchResults.isNotEmpty` (ligne 1889) — même condition que le binaire.

**F2 — Filtrage de recherche (`gRm()`).** `take(8)` et prédicat identiques : correspondance sur `name` **ou** `direction`, bornée par `DakarBounds.isValid`.

**F3 — Filtres par couleur (`gNF()`).** 7 puces dans le même ordre (`Tous`, `⭐ Favoris`, `TER`, `BRT`, `DDD`, `TATA`, `AFTU`). Filtrage par **couleur** (`p.color == AppColors.ter` etc.), favoris par **nom** — les deux logiques sont conformes. `_colorFor` / `MM` : même table de correspondance.

**F4 — Liste « à proximité » (`gNF()`).** Rayon **4000 m**, `take(30)` appliqué **trois fois**, double tri aux comparateurs **byte-identiques**, tri sans GPS depuis `B.hA = LatLng(14.7167, -17.4677)`.
> Ces valeurs avaient déjà été réintégrées au Groupe 4 (décisions D2-i et D5-i, constantes `GpsResolver.nearbyRadiusMeters = 4000.0` et `nearbyLimit = 30`). **La vérification Groupe 5 les confirme indépendamment.** Rien à refaire.

**F6 — Carte.** `MapOptions.initialCenter` : repli `B.IR = LatLng(14.72, -17.43)`, `initialZoom 11.2`, `minZoom 9`, `maxZoom 17`. `TileLayer` : `maxZoom 19`, `userAgentPackageName "dakar_bus"`, tuiles `tile.openstreetmap.org`. Tout est conforme.

> **Note sur les deux constantes de centre.** `B.hA = (14.7167, -17.4677)` (repli de position et de tri) et `B.IR = (14.72, -17.43)` (centre initial de la carte) sont **distinctes dans le binaire de production**. L'« incohérence de 4071 m » signalée au Groupe 4 est donc **fidèle à la production** : ce n'est pas un défaut du source. Aucune correction à apporter.

**F7 — Recentrage.** `_centerOnStop` : zoom **13.5**, déplacement de carte à **11.2**, chaînes de `debugPrint` identiques.

**F11 — Intégration JSON (`aW7()`).** Fonction **intégralement conforme**, vérifiée closure par closure :

| Closure binaire | Équivalent source | Verdict |
|---|---|---|
| `A.awP` : `a.a+"_"+a.r.a+"_"+a.r.b` | `'${s.name}_${s.location.latitude}_${s.location.longitude}'` | ✅ identique |
| `A.awZ` : `ter→B.az, brt→B.bl, ddd→B.bR, aftu→B.cx, tata→B.bS, défaut→B.z` | `colorForOperator` (807-816) | ✅ identique |
| `A.ax_` : icônes par opérateur, `aftu` + `TATA` | `iconForOperator` (817-826) | ✅ identique |
| `A.ax0` : `ter→"TER", brt→"BRT", ddd→"DDD", aftu→Tata/AFTU, tata→"Tata"` | `labelForOperator` (827-836) | ✅ identique |
| `A.ax1` : source par opérateur | `sourceForOperator` | ✅ identique |
| `A.ax2` : `total==1→ak, idx==0→ak, idx==total-1→fs, sinon→Sb` | `stopTypeForIndex` (847-852) | ✅ identique |
| `A.awR`/`A.awS` : `a.a === stopIds[i]` | `firstWhere((s) => s.id == stopIds[i])` (857-859) | ✅ identique |
| `A.awY` : `a.b === i.c` | `demoRoutes.any((r) => r.code == route.shortName)` (912) | ✅ identique |
| `A.axy` : `A.eI(a.r)` | `.where((p) => DakarBounds.isValid(p))` | ✅ identique |
| `300 + a2*800` | `distanceMeters: 300 + (i * 800).toDouble()` (886) | ✅ identique |
| `500` (arrêts orphelins) | `distanceMeters: 500` (939) | ✅ identique |
| `"Terminus X (Arrivée)"` / `"Dir. X"` | formules de direction (884-886) | ✅ identique |
| `debugPrint("✅ DataService intégré : …")` | ligne 953 | ✅ identique |

**F12 — Service de routage (`A.aS2()`).** Conforme **à l'exception de l'hôte de l'URL** (voir écart E5) :

| Aspect | Production | Source | Verdict |
|---|---|---|---|
| Clé de cache | `lat.toFixed(5),lon.toFixed(5)\|lat.toFixed(5),lon.toFixed(5)` | `_cacheKey` identique (127-129) | ✅ |
| Ordre des coordonnées | `lon,lat;lon,lat` | identique | ✅ |
| Paramètres | `?overview=full&geometries=geojson` | identique | ✅ |
| Timeout HTTP | `B.jQ` = **4 s** | `Duration(seconds: 4)` | ✅ |
| Repli | `[start, end]` | identique | ✅ |
| Filtrage | `DakarBounds.isValid` | identique | ✅ |
| **Préfixe d'URL** | **`/dakar-bus/osrm/route/v1/driving/`** (relatif) | **`https://router.project-osrm.org/route/v1/driving/`** | ❌ **écart E5** |

**F13 — `DetailedRoutePage` (`A.a3g`, source 2804+).** **Identique** au binaire : centre de repli `B.hA`, `initialZoom 11.5`, `Polyline` de largeur **5** (source ligne 2845 : `strokeWidth: 5.0`). Conforme — **aucune modification**.

**Structure `TransitRoute`.** Le binaire expose `A.ma(a,b,c,d)` = 4 champs (`code`, `type`, `color`, `points`), alors que le source en déclare 5 (`name`, `code`, `type`, `color`, `points`, ligne 722). **Ce n'est pas un écart** : `name` est déclaré mais **jamais lu nulle part** dans `main.dart` (vérifié par grep — la seule occurrence est la déclaration elle-même). dart2js élimine les champs inutilisés. Le constructeur binaire `A.akW(a,b,c,d,e){return new A.ma(a,e,b,d)}` prend bien **5** arguments et abandonne le 3ᵉ (`name`) : le source de production passait donc déjà un `name` non stocké. La fabrique `ma(code, type, color, points)` correspond exactement à l'appel source `TransitRoute(name:, code:, type:, color:, points:)`.

---

### 3.2 ÉCARTS PROUVÉS

Six écarts sont établis par preuve binaire. Chacun reçoit un verdict GO / NO-GO motivé en §6.

---

#### E1 — `demoRoutes` non alignées sur le JSON ⚠️ **écart fonctionnel majeur**

**Preuve du comportement cible.** La liste `demoRoutes` de production (`$.J0()`) a été extraite **intégralement** du binaire. Les quatre tracés sont **exactement** les géométries du JSON actif :

| Démo | Production (binaire) | JSON actif | Verdict |
|---|---|---|---|
| TER | **13 points** | `ter_dakar_diamniadio`, 13 gares | ✅ 13/13 exacts |
| B1 | **23 points** | `brt_b1_guediawaye_petersen`, 23 stations | ✅ 23/23 exacts |
| DDD | **3 points** | `ddd_12`, 3 arrêts | ✅ 3/3 exacts |
| TATA | **2 points** | `tata_219`, 2 arrêts | ✅ 2/2 exacts |

Constructeur binaire : `A.akW(code, color, name, points, type)`. Les noms, codes et types sont **identiques** au source ; **seuls les points diffèrent**.

Cette extraction confirme un commentaire Dart v4 authentique retrouvé dans le binaire :
> *« demos recalées sur JSON (TER 13, B1 12 stations, DDD=ddd_12, TATA=tata_219 : doublons invisibles) »*

> **Contradiction tranchée :** le commentaire annonce « B1 12 stations » alors que le binaire contient **23** points pour B1. **Le binaire fait foi** ; le commentaire est inexact (vraisemblablement non mis à jour). La preuve retenue est l'extraction des coordonnées, pas le commentaire.

**Comportement actuel du source.** Les 4 démos codées en dur (lignes 959-988) ne correspondent à **aucune** géométrie du JSON :

| Démo | Source actuel | Cible prouvée | Écart |
|---|---|---|---|
| TER | **6 points** (14.6792/-17.4407 … 14.7160/-17.1986) | 13 points | ❌ 7 gares absentes |
| B1 | **10 points** (14.6720/-17.4400 … 14.7735/-17.3977) | 23 points | ❌ 13 stations absentes |
| DDD | **3 points** (coordonnées différentes) | 3 points `ddd_12` | ❌ coordonnées divergentes |
| TATA | **3 points** (coordonnées différentes) | 2 points `tata_219` | ❌ coordonnées divergentes + 1 point en trop |

**Conséquence utilisateur réelle, démontrée.** La déduplication de la ligne 912 compare `r.code == route.shortName`. Les codes des démos sont `'TER'`, `'B1'`, `'DDD'`, `'TATA'` ; les `short_name` du JSON sont `'TER'`, `'BRT B1'`, `'DDD 12'`, `'Tata 219'`. D'où :

1. **TER : la ligne JSON réelle est court-circuitée.** `'TER' == 'TER'` → `ter_dakar_diamniadio` (13 gares) n'est **jamais ajoutée** à `demoRoutes`. Seule la démo à **6 points** subsiste. **La carte affiche donc un tracé TER amputé de 7 gares sur 13.** C'est une contradiction de rendu avec le §6 (TER = 13 gares), alors même que la donnée JSON est correcte.
2. **BRT B1, DDD et TATA : doublons de tracé.** `'B1' ≠ 'BRT B1'`, `'DDD' ≠ 'DDD 12'`, `'TATA' ≠ 'Tata 219'` → les lignes JSON **sont** ajoutées. Ces trois lignes sont donc **dessinées deux fois**, avec deux géométries divergentes superposées.

État résultant aujourd'hui : `demoRoutes` = 4 démos + 104 lignes JSON = **108** entrées, dont 3 paires de doublons visibles et 1 TER incomplet.

**Effet du correctif v4 de production.** En alignant les points des démos sur le JSON, les doublons deviennent **géométriquement invisibles** (deux polylignes identiques superposées) et le TER affiche ses 13 gares. C'est exactement ce que décrit le commentaire « doublons invisibles ».

**Conflit de règles à trancher.** Reproduire la production **à la lettre** (recopier 13 + 23 + 3 + 2 coordonnées en dur dans `main.dart`) violerait :
- le **§7** : *« aucune seconde liste de 23 stations dans main.dart »* ;
- le **§4-§5** : *« dakar_network.json = source unique de vérité, pas de seconde source »*.

Deux implémentations produisent le **même comportement observable** :

| Option | Description | §4/§7 | Risque |
|---|---|---|---|
| **O-A** (production littérale) | Recopier les coordonnées du JSON en dur dans les 4 démos | ❌ **viole §7 et §4** | Faible techniquement, interdit par les règles |
| **O-B1** (équivalent comportemental) ⭐ | **Supprimer les 4 démos codées en dur** ; `demoRoutes` démarre vide et n'est alimentée que par le JSON | ✅ conforme | Faible — voir vérification ci-dessous |
| O-B2 | Conserver les démos mais inverser la déduplication pour que le JSON l'emporte | ✅ conforme | Plus élevé : plus de code, logique de remplacement à tester |

**Vérification d'équivalence de O-B1** (chaque maillon contrôlé) :

Les 4 démos ont **toutes** un équivalent JSON complet : `ter_dakar_diamniadio` (13), `brt_b1_guediawaye_petersen` (23), `ddd_12` (3), `tata_219` (2). Une ligne dérivée du JSON produit :

| Attribut | Démo codée en dur | Ligne dérivée du JSON | Identique ? |
|---|---|---|---|
| TER — couleur | `AppColors.ter` | `colorForOperator('ter')` = `AppColors.ter` | ✅ |
| TER — type | `'TER'` | `labelForOperator('ter','TER')` = `'TER'` | ✅ |
| TER — `isDedicated` | `true` | `true` | ✅ |
| B1 — couleur | `AppColors.brt` | `colorForOperator('brt')` = `AppColors.brt` | ✅ |
| B1 — type | `'BRT'` | `labelForOperator('brt','BRT')` = `'BRT'` | ✅ |
| B1 — `isDedicated` | `true` | `true` | ✅ |
| DDD — couleur | `AppColors.ddd` | `colorForOperator('ddd')` = `AppColors.ddd` | ✅ |
| DDD — type | `'DDD'` | `labelForOperator('ddd','BUS')` = `'DDD'` | ✅ |
| TATA — couleur | `AppColors.tata` | `colorForOperator('tata')` = `AppColors.tata` | ✅ |
| TATA — type | `'Tata'` | `labelForOperator('tata','BUS')` = `'Tata'` | ✅ |

Les quatre attributs observables (`code` utilisé uniquement en déduplication interne, `type`, `color`, `points`) sont **strictement identiques**. Le champ `name` différerait (`'TER'` vs `'TER'`, `'BRT'` vs `'BRT B1'`, `'DDD Lignes'` vs `'DDD 12'`, `'TATA Bus'` vs `'Tata 219'`) mais `name` est **prouvé inutilisé** (§3.1) → aucune conséquence observable.

Aucun `short_name` n'étant dupliqué dans le JSON et aucune ligne n'ayant moins de 2 arrêts valides, **O-B1 donne `demoRoutes` = 105 entrées, toutes dérivées du JSON, aucune perdue.**

> **Recommandation : O-B1.** Elle reproduit le comportement cible prouvé (mêmes géométries, mêmes couleurs, mêmes types, TER complet, doublons supprimés à la racine plutôt que masqués) tout en respectant §4 et §7. **Cette option n'est pas la reproduction littérale du binaire** : elle requiert une décision explicite de l'utilisateur (voir §8, décision D-G5-1).

---

#### E2 — Stratégie de chargement des tracés : architecture **inversée**

C'est l'écart le plus profond, et le plus dangereux à porter tel quel.

**Production (`A.F1` = `_ExplorerPageState`), décodée intégralement :**

| Méthode | Rôle | Filtre | Largeur | OSRM |
|---|---|---|---|---|
| `an()` | `initState` → appelle `xw()` | — | — | — |
| `aE()` | `didUpdateWidget` : recentre si position valide | — | — | — |
| **`xw()`** | **chargeur principal** | `where(ap9)` avec **`ap9 = TRUE`** → **toutes** les lignes | **3.5** | **oui**, segments pair-à-pair, `Future.wait(...).timeout(B.jQ = 4 s, onTimeout: () => [])`, repli en points droits si < 2 points |
| **`xv()`** | chargeur différé | `where(ap6)` avec **`ap6 = FALSE`** → **aucune** ligne | 3 | **code mort** (v3), délai `B.bv`, `setState` seulement si résultat non vide |

`xw()` appelle `xv()` à la fin. Deux commentaires Dart v3 authentiques retrouvés dans le binaire le confirment :
> *« TOUTES lignes passent par OSRM »* — *« plus aucune ligne droite, xw() couvre tout »*

**Source actuel (1548-1590) :** architecture **inverse**.

| Méthode | Filtre | Largeur | OSRM |
|---|---|---|---|
| `_loadDynamicRoutes` | `where((r) => r.isDedicated)` → TER/BRT seulement | **5.5** | **non** — lignes droites, commentaire *« instantané, pas d'OSRM »* |
| `_lazyLoadRemainingRoutes` | `where((r) => !r.isDedicated).take(20)` | **4.5** | **oui**, `Future.wait(...).timeout(3 s)`, délai initial 800 ms |

`isDedicated` est défini ligne 724 : `type == 'TER' || type == 'BRT'`.

**Ampleur chiffrée du passage à v3** (calculée depuis le JSON actif) :

```
lignes JSON totales                : 105
demoRoutes après intégration       : 108 (état actuel)  /  105 (après O-B1)
SEGMENTS OSRM à requêter en v3     : 347
État actuel (where isDedicated)    : 4 lignes + ~14 segments
```

**Pourquoi la production peut se le permettre — et le source non.** Production ne contacte **jamais** Internet : l'URL est **relative** (`/dakar-bus/osrm/…`, voir E5) et sert des réponses OSRM **pré-extraites localement** sur gh-pages :

```
/tmp/prod/dakar-bus-gh-pages/osrm/route/v1/driving/
  299 fichiers, 1 636 Kio
  ex. : -17.2292,14.69818;-17.19845,14.71606
```

générés par `tools/prefetch_osrm.py` (workflow `.github/workflows/prefetch-osrm.yml`).

**Preuve décisive — les 4 assets de géométrie ne sont PAS des assets runtime :**

| Asset présent sur gh-pages | Taille | Occurrences dans le binaire |
|---|---|---|
| `osrm_geometries.json` | 1 749 972 o | **0** |
| `osrm_pairs.json` | 35 706 o | **0** |
| `brt_dedicated_shapes.json` | 3 309 o | **0** |
| `ter_rail_shapes.json` | 1 874 o | **0** |
| `assets/data/dakar_network.json` | — | **1** (`apY("assets/data/dakar_network.json")`) |

**Aucun code applicatif ne lit ces fichiers.** Ce sont des artefacts d'outillage servant à *produire* le cache de 299 réponses. Le mécanisme hors-ligne de production repose donc **exclusivement sur l'infrastructure de déploiement**, pas sur le code Dart.

**Verdict : NO-GO pour le Groupe 5.** Porter `where(true)` sans l'infrastructure correspondante aurait l'un de ces deux effets, tous deux régressifs :
- URL live conservée → **347 requêtes HTTP vers `router.project-osrm.org` au démarrage d'Explorer** : abusif, quasi certainement limité ou bloqué, écran figé jusqu'au timeout ;
- URL relative adoptée (E5) → **404 sur les 347 segments** en build local (le dépôt ne contient pas `osrm/`), donc repli systématique en lignes droites : le tracé réel disparaît.

De plus, **299 fichiers en cache < 347 segments** : même la production ne couvre pas tous les segments et retombe partiellement en lignes droites. La couverture exacte par ligne est **NON PROUÉE** (voir §5).

Le v3 de production n'est donc **pas un comportement portable isolément** : c'est un couple (code + infrastructure de cache) dont la seconde moitié relève des Groupes 10-11. À traiter comme **décision D-G5-2**.

---

#### E3 — Largeurs de tracé (`strokeWidth`)

| Emplacement | Production | Source | Écart |
|---|---|---|---|
| chargeur principal (`xw` / `_loadDynamicRoutes`) | **3.5** | **5.5** | ❌ |
| chargeur différé (`xv` / `_lazyLoadRemainingRoutes`) | **3** | **4.5** | ❌ |
| repli dans `build` (ligne 1703) | **3.5** | **5.0** | ❌ |
| `DetailedRoutePage` | **5** | **5.0** | ✅ conforme |

**Nuance importante à ne pas commettre.** En production, la largeur **3** appartient à `xv()`, qui est du **code mort** (filtre `false`) : elle n'est donc **jamais observable** en production. Dans le source, `_lazyLoadRemainingRoutes` est **vivant** et dessine réellement les lignes non dédiées. Adopter la valeur 3 modifierait donc un rendu **effectif**, ce qui n'est pas la simple copie d'une constante morte.

Écart **purement cosmétique**, sans conséquence fonctionnelle. À rapprocher du §21 (*« aucune refonte d'UI, modifications minimales uniquement si fonctionnellement nécessaires »*).

---

#### E4 — Timeout du `Future.wait`

| | Production | Source |
|---|---|---|
| `Future.wait(segments).timeout(...)` | `B.jQ` = **4 s** | **3 s** (ligne **1575**) |
| Timeout HTTP interne à `getRealRoute` | `B.jQ` = 4 s | 4 s ✅ |

`B.jQ` a été extrait explicitement : `new A.aR(4e6)` = **4 000 000 µs = 4 s**. La production utilise **la même constante** pour le timeout HTTP et pour le `Future.wait` ; le source est désaligné (3 s vs 4 s).

Écart **prouvé, trivial, sans risque**. Un `Future.wait` borné à 3 s alors que chaque requête interne dispose de 4 s est par ailleurs incohérent : le repli global se déclenche avant l'épuisement des requêtes individuelles.

---

#### E5 — URL OSRM : relative en production, absolue dans le source

| | Production | Source |
|---|---|---|
| Préfixe | `/dakar-bus/osrm/route/v1/driving/` | `https://router.project-osrm.org/route/v1/driving/` |
| Occurrences de `router.project-osrm.org` dans le binaire | **0** | — |

**Conséquence d'un portage direct :** un build Flutter local (`flutter run`, `flutter build web`) servirait depuis la racine du dépôt, où `osrm/` n'existe pas → **404 sur chaque segment** → repli silencieux en lignes droites `[start, end]`. Cela **casserait l'objectif du Groupe 11** (build local fonctionnel).

Rendre l'URL relative fonctionnerait **uniquement** si l'on ajoutait au dépôt ~1,79 Mio d'assets de cache **et** si l'on câblait leur publication — c'est-à-dire une modification du build et du déploiement, donc des **Groupes 10-11**, explicitement hors périmètre (règle 4).

**Verdict : NO-GO pour le Groupe 5.** À traiter comme **décision D-G5-3**.

---

#### E6 — Texte de la ligne de comptage

Structure binaire décodée :
```js
Text("" + s + " arrêts",  fontSize 16, bold)   // s = stops.length
SizedBox(width 8)
if (isLoadingRoutes) CircularProgressIndicator   // B.RS
else Text("à proximité", fontSize 11)
```

Source (1899-1906) : `Text('${stops.length} arrêts', fontSize 16, bold)` ✅, `SizedBox(width: 8)` ✅, spinner `CircularProgressIndicator(strokeWidth: 2)` ✅, puis :

| | Texte |
|---|---|
| Production | `'à proximité'` |
| Source | `'à proximité (Maintenez un arrêt pour l\'ajouter aux favoris)'` |

**Seul le second `Text` diffère.** Le premier, le séparateur et le spinner sont déjà conformes.

**Aucune perte d'information en cas d'alignement** : l'indication « maintenez un arrêt pour l'ajouter aux favoris » reste présente dans la modale d'aide (ligne 2553 : *« 2. Maintenez un arrêt enfoncé pour l'ajouter à vos favoris ⭐ »*).

Écart **purement cosmétique**, même tension avec le §21 que E3.

---

## 4. Synthèse des écarts

| # | Écart | Nature | Cible prouvée ? | Verdict Groupe 5 |
|---|---|---|---|---|
| **E1** | `demoRoutes` non alignées sur le JSON (TER 6/13, B1 10/23, DDD et TATA divergents) → TER amputé à la carte, 3 doublons de tracé | **Fonctionnelle** | ✅ oui, coordonnées exactes | **GO** (implémentation à décider : O-B1 recommandé) |
| **E2** | Architecture de chargement inversée (`where(true)` + OSRM généralisé vs `where(isDedicated)` sans OSRM) | **Architecturale / infrastructure** | ✅ oui, mais **non portable isolément** | **NO-GO** (347 requêtes ou 404 systématiques) |
| **E3** | `strokeWidth` 5.5/4.5/5.0 vs 3.5/3/3.5 | Cosmétique | ✅ oui | **OPTIONNEL** (décision utilisateur) |
| **E4** | Timeout `Future.wait` 3 s vs 4 s | Paramètre | ✅ oui | **GO** |
| **E5** | URL OSRM absolue vs relative | **Infrastructure / déploiement** | ✅ oui, mais dépend d'assets gh-pages absents du dépôt | **NO-GO** (casserait le build local, Groupe 11) |
| **E6** | Texte `'à proximité (Maintenez…)'` vs `'à proximité'` | Cosmétique | ✅ oui | **OPTIONNEL** (décision utilisateur) |

---

## 5. Éléments NON PROUVÉS

Conformément à la règle absolue, ces points **ne doivent pas** être implémentés ni supposés.

| # | Élément | Pourquoi NON PROUVÉ |
|---|---|---|
| NP1 | **Valeur de `B.bv`** (délai du chargeur différé `xv`) | Constante repérée dans le binaire mais **valeur non extraite**. Sans conséquence : en production `xv()` est du code mort (`where(false)`), son délai est donc **inobservable**. Le source utilise 800 ms. |
| NP2 | **Couverture exacte du cache OSRM par ligne** | 299 fichiers en cache pour 347 segments : la production retombe donc **partiellement** en lignes droites. Le mapping fichier → ligne n'a pas été établi ; on ne peut pas dire quelles lignes bénéficient d'un vrai tracé en production. |
| NP3 | **Ordre et nombre exacts de `_dynamicPolylines` au runtime** | Dépendent de l'ordonnancement asynchrone et du timeout. Le chemin de code est prouvé, pas l'état final observable. |
| NP4 | **Présence réelle d'un champ `name` dans le source de production** | Indistinguable d'une élimination par dart2js d'un champ inutilisé. **Sans conséquence observable** : `name` est prouvé inutilisé dans le source actuel. |
| NP5 | **Commentaire v4 « B1 12 stations »** | **Contredit par le binaire** (23 points, 23/23 exacts). Le commentaire est inexact et **ne doit pas** être suivi. Le binaire fait foi. |
| NP6 | **Cartes 08 et 15** | Définitivement perdues. Aucune de leurs conclusions n'a été reprise. Tout ce qui précède a été ré-établi indépendamment. |
| NP7 | **Pertinence fonctionnelle de E3 et E6** | Les valeurs cibles sont prouvées ; rien ne prouve qu'elles aient une motivation autre qu'esthétique. Aucun comportement utilisateur ne dépend d'elles. |
| NP8 | **Total `totalDistance` 14.0 vs 18.3 km (§9)** | Non réexaminé ici : hors périmètre Groupe 5 (aucun consommateur de `demoRoutes`). Reste **NON PROUVÉ** tant que la formule n'est pas établie. |

---

## 6. Critères GO / NO-GO

### 6.1 GO — peut être implémenté après validation du périmètre

| Écart | Condition |
|---|---|
| **E1** | Choix d'implémentation **validé par l'utilisateur** (D-G5-1). Recommandation : **O-B1**. |
| **E4** | Aucun prérequis. Alignement du timeout sur 4 s. |

### 6.2 OPTIONNEL — cosmétique, soumis au §21

| Écart | Arbitrage |
|---|---|
| **E3** | Valeurs prouvées mais purement esthétiques. Le §21 impose des modifications minimales **uniquement si fonctionnellement nécessaires**. À confirmer ou écarter (D-G5-4). |
| **E6** | Idem. Aucune perte d'information (l'aide reste dans la modale ligne 2553). À confirmer ou écarter (D-G5-4). |

### 6.3 NO-GO — refusé pour le Groupe 5, motivé

| Écart | Motif du refus |
|---|---|
| **E2** | Nécessite le cache OSRM gh-pages (299 fichiers / 1,6 Mio) **et** l'URL relative. Porté seul : 347 requêtes live au démarrage, ou 404 systématiques. Relève des Groupes 10-11. |
| **E5** | Casserait le build local (objectif Groupe 11). Exigerait ~1,79 Mio d'assets + câblage de publication. Relève des Groupes 10-11. |

### 6.4 Critères de réussite de l'implémentation (si validée)

1. `flutter analyze` **sans erreur** (porte de publication CI = code de sortie d'analyze ; toujours lire `.output.summary`).
2. `flutter test` : **162 tests existants verts + nouveaux tests verts**, avec garde anti-« 0 test ».
3. `demoRoutes` ne contient **plus aucune coordonnée codée en dur** ; toutes proviennent du JSON.
4. Le tracé TER affiché comporte **13 points**, dans l'ordre du §6 (`kTer13`).
5. Le tracé BRT B1 comporte **23 points**, dans l'ordre du §7 (`kBrtB123`), **une seule fois**.
6. `pubspec.yaml` **inchangé** (md5 `a44209df…`), version toujours `9.3.2+12`.
7. `assets/data/dakar_network.json` **inchangé** (md5 `81c778f4…`).
8. `main` et `gh-pages` **non touchés** (SHAs §1.1 inchangés).
9. Aucun prix, tarif, coût ou FCFA ajouté (§22).
10. Aucun `REAL_TIME` introduit depuis une donnée substituée (§18, D5-i).
11. CI verte sur `arena/01a0c385-dakar-bus` ; en cas d'échec → **STOP** (règle 9 du Groupe 3).
12. Push **uniquement** vers `arena/01a0c385-dakar-bus`. Aucun déploiement Pages.

---

## 7. Fichiers à modifier / à NE PAS modifier

### 7.1 À modifier (si le périmètre est validé)

| Fichier | Zone | Modification |
|---|---|---|
| `flutter-src/lib/main.dart` | **959-988** (`demoRoutes`) | E1 — suppression des 4 démos codées en dur (option O-B1). Liste initialisée vide. |
| `flutter-src/lib/main.dart` | **1575** (`_lazyLoadRemainingRoutes`) | E4 — timeout `3 s` → `4 s`. |
| `flutter-src/lib/main.dart` | *(à créer, près de 912-918)* | Couture de test publique pour `_integrateNetworkData` (voir §9.1). |
| `flutter-src/lib/main.dart` | **1554, 1586, 1703** (largeurs) et **1905** (texte) | **Seulement si D-G5-4 = oui** — E3 et E6. |
| `flutter-src/test/explorer_routes_test.dart` | *(nouveau)* | Tests E1/E4 (§9). |

### 7.2 À NE PAS modifier

| Fichier / zone | Raison |
|---|---|
| `flutter-src/assets/data/dakar_network.json` | Source unique de vérité (§4-§5), déjà **identique à la production**. Règle 6 : aucun changement sans nécessité démontrée — **aucune nécessité n'est démontrée ici**. |
| `flutter-src/pubspec.yaml` | Version validée Phase 0 (§28). Aucune dépendance nouvelle (D3-i, règle 7). |
| `main.dart` **124-157** (`RoutingService`) | Conforme à la production hormis l'URL ; l'URL est **NO-GO** (E5). |
| `main.dart` **721-725** (`TransitRoute`) | Structure conforme (champ `name` inutilisé, sans conséquence). |
| `main.dart` **798-955** (`_integrateNetworkData`) | **Intégralement conforme** au binaire, closure par closure. Seule la couture de test s'y ajoute, sans changer la logique. |
| `main.dart` **807-852** (`colorForOperator`, `iconForOperator`, `labelForOperator`, `sourceForOperator`, `stopTypeForIndex`) | Byte-identiques à la production. |
| `main.dart` **1243-1358** (`GpsResolver`) | Résultat du Groupe 4 (D1-i à D6-i), confirmé conforme par cet audit. |
| `main.dart` **1595** (`_filteredStops`) et **1682** (`_searchResults`) | Conformes : `take(8)`, `take(30)`×3, rayon 4000, tris identiques. |
| `main.dart` **1875-1893** (champ de recherche, bouton effacer, résultats) et **1897** (7 puces) | Conformes. |
| `main.dart` **70-105** (documentation + validateur `DakarBounds`) | **Déjà résolu au Groupe 1** : la preuve v4 du rectangle d'exclusion y est documentée (bornes 14.55 / 14.9 / -17.6 / -16.85, divergence assumée de la garde `(0,0)`). Rien à refaire. |
| `main.dart` **2804-2860** (`DetailedRoutePage`) | Conforme (repli `B.hA`, `initialZoom 11.5`, largeur 5 en ligne 2845). |
| Groupes 1-4 : `test/dakar_bounds_test.dart`, `test/opposite_stop_test.dart`, `test/gps_position_test.dart`, `test/detailed_route_test.dart` | Règle 4 : ne pas toucher sauf nécessité démontrée. **Aucune nécessité démontrée.** |
| `.github/workflows/flutter-verify.yml` | CI en place, inchangée. |
| `gh-pages` (branche et contenus) | Interdiction absolue (§29-30, §33, règle 6). |
| `main` | Interdiction absolue. |

---

## 8. Points de décision soumis à l'utilisateur

Aucune implémentation ne démarre avant réponse (règle 9).

| # | Décision | Options | Recommandation |
|---|---|---|---|
| **D-G5-1** | Implémentation de E1 | **(a) O-B1** : supprimer les démos, `demoRoutes` dérivée du seul JSON — conforme §4/§7, même comportement observable prouvé. **(b) O-A** : reproduction littérale du binaire (coordonnées recopiées en dur) — **viole §7**. **(c) O-B2** : inverser la déduplication pour que le JSON l'emporte. **(d)** ne rien faire. | **(a) O-B1** |
| **D-G5-2** | E2 (OSRM généralisé, v3) | **(a)** NO-GO Groupe 5, reporté aux Groupes 10-11 avec l'infrastructure de cache. **(b)** tenter maintenant → 347 requêtes live au démarrage. | **(a) NO-GO / report** |
| **D-G5-3** | E5 (URL OSRM relative) | **(a)** conserver l'URL live `router.project-osrm.org`. **(b)** URL relative + ajout de ~1,79 Mio d'assets de cache au dépôt + câblage de publication (touche au build, Groupes 10-11). | **(a)** pour le Groupe 5 ; (b) à instruire en Groupe 10-11 |
| **D-G5-4** | E3 + E6 (cosmétique) | **(a)** appliquer pour une fidélité stricte à la production. **(b)** écarter au nom du §21 (modifications minimales, uniquement si fonctionnellement nécessaires). | **(b) écarter** — ou (a) si la fidélité pixel prime |
| **D-G5-5** | Signalement hors périmètre (§10) | Corriger la violation « 14 Gares / Keur Massar » d'`AlertsPage` dans un groupe dédié, ou la traiter dès maintenant malgré la règle 4. | **Reporter** au groupe traitant Alerts/Info |

---

## 9. Tests à ajouter

### 9.1 Contrainte technique préalable — couture de test

`_integrateNetworkData()` est **privée** (ligne 798) et opère sur la globale `appDataService` (ligne 16), chargée uniquement dans `main()`. Les tests existants construisent un `DataService()` **local** (`loadActive()` dans `network_data_test.dart:86-94`) et ne peuvent donc **pas** déclencher l'intégration.

Il faut une **couture publique**, sur le modèle retenu au Groupe 4 (décision D3-i : couture pure, **aucune nouvelle dépendance**, **aucune modification de `pubspec.yaml`**) :

```dart
@visibleForTesting
void integrateNetworkDataForTest() => _integrateNetworkData();
```

`demoRoutes` et `allStops` sont déjà publiques → lisibles depuis les tests. L'intégration est **ré-exécutable sans effet cumulatif** (le jeu `existingKeys` est reconstruit depuis `allStops` à chaque appel, et la déduplication `demoRoutes.any(...)` empêche les doublons) — propriété à figer par un test.

### 9.2 Tests proposés (fichier `flutter-src/test/explorer_routes_test.dart`)

| # | Test | Garde |
|---|---|---|
| T1 | Après intégration, `demoRoutes` contient **exactement une** ligne TER, à **13 points** | §6 |
| T2 | Ces 13 points correspondent, **dans l'ordre**, aux 13 gares de `kTer13` (coordonnées du JSON) | §6 |
| T3 | **Aucune** gare du TER n'est `stop_keur_massar` | §6 |
| T4 | `demoRoutes` contient **exactement une** ligne BRT B1 à **23 points**, dans l'ordre `kBrtB123` | §7 |
| T5 | **Aucun doublon géométrique** : pas deux entrées partageant la même liste de points | E1 |
| T6 | `demoRoutes.length == 105` et **toutes** les entrées proviennent du JSON (aucune démo résiduelle) | E1 / O-B1 |
| T7 | `ddd_12` → 3 points, `tata_219` → 2 points, identiques au JSON | E1 |
| T8 | **Tous** les points de **toutes** les lignes de `demoRoutes` valident `DakarBounds` | invariant, aucun arrêt artificiel |
| T9 | Couleurs dérivées : ligne TER → `AppColors.ter`, BRT → `AppColors.brt`, DDD → `AppColors.ddd`, Tata → `AppColors.tata` | équivalence O-B1 |
| T10 | `isDedicated` : la ligne TER et les lignes BRT sont `true`, DDD et Tata sont `false` | F8/F9 non régressés |
| T11 | **Idempotence** : deux intégrations successives ne changent ni `demoRoutes.length` ni `allStops.length` | §9.1 |
| T12 | Timeout du `Future.wait` = **4 s**, via une constante nommée et testable | E4 |

**Garde statique** (hors test unitaire, à intégrer à la CI ou à une vérification manuelle) : après O-B1, `main.dart` ne doit plus contenir **aucun littéral `LatLng(` codé en dur** dans la plage de `demoRoutes`. Cela verrouille §4 (pas de seconde source) et §7 (pas de seconde liste).

> Les tests devront utiliser `const` et non `final` pour les constantes de seuil : le lint `prefer_const_declarations` fait échouer `flutter analyze` sinon (piège déjà rencontré).

---

## 10. Risques

| # | Risque | Gravité | Mitigation |
|---|---|---|---|
| R1 | **O-B1 supprime le repli en dur si l'asset JSON échoue à charger.** Aujourd'hui, les 4 démos offrent un tracé minimal même sans JSON. | **Élevée** | `main()` enveloppe déjà le chargement dans un `try/catch` (lignes 30-36) avec `debugPrint`. Le repli carte (ligne 1703) utilise `demoRoutes`, qui serait vide → carte sans tracé mais **fonctionnelle** (les arrêts et la recherche viennent d'`allStops`, également vide sans JSON). **C'est un changement de comportement en mode dégradé** : à valider explicitement dans D-G5-1. Un test de garde-fou (JSON absent → pas d'exception, pas de donnée fabriquée) est à ajouter. |
| R2 | Porter E2 ou E5 malgré le NO-GO | **Élevée** | Verdict motivé en §6.3. Toute tentative exige l'infrastructure des Groupes 10-11. |
| R3 | Régression des 162 tests existants | Moyenne | CI après chaque modification (règle 7 du Groupe 3, §24). Arrêt immédiat en cas d'échec. |
| R4 | Toucher par effet de bord aux Groupes 1-4 | Moyenne | §7.2 liste explicitement les zones intouchables. `demoRoutes` n'a aucun consommateur hors Explorer (§2). |
| R5 | Confondre commentaire binaire et comportement réel (NP5 : « B1 12 stations ») | Moyenne | Le binaire extrait fait toujours foi sur les commentaires. |
| R6 | Grep naïf sur le binaire concluant à tort « absent » | Moyenne | Toujours passer par `/tmp/g5/decode.py` (§0.1). |
| R7 | Perte du token GitHub en cours de phase (déjà survenu en fin de Groupe 4) | Moyenne | Effectuer les lectures critiques immédiatement après le run CI ; demander une reconnexion si nécessaire. |
| R8 | Appliquer E3/E6 et contrevenir au §21 | Faible | Subordonné à D-G5-4. |
| R9 | `xv()` devenant code mort si E2 était partiellement appliqué | Faible | E2 est NO-GO en bloc ; pas d'application partielle. |

---

## 11. Signalements hors périmètre Groupe 5

Conformément à la règle 4 (pas d'élargissement), ces éléments sont **signalés mais non traités**.

### 11.1 ⚠️ Violation du §6 dans `AlertsPage` — « 14 Gares » et Keur Massar

`main.dart:2249-2258`, `AlertsPage.officialAlerts`, **codé en dur** :

- *« Réseau CETUD & SETER (14 Gares) »*
- *« Le TER dessert officiellement 14 gares … Keur Massar »*
- badge *« 14 Gares Officielles »*

**Preuve binaire :**

| Chaîne | Occurrences dans le binaire |
|---|---|
| `'14 Gares'` | **0** |
| `'14 gares'` | **0** |
| `'13 gares'` | **2** |

La production affiche **« 13 gares desservies »**. Le contenu d'`AlertsPage` est donc une **invention du source seul**, en contradiction directe avec :
- le **§6** : *« TER = 13 gares, ordre exact. Ne jamais réintroduire Keur Massar comme TER »* ;
- les tests Groupe 1 déjà en place : `network_data_test.dart:120` (*« Gare TER Keur Massar est ABSENTE du TER »*) et `:167` (*« le libellé long annonce 13 gares, pas 14 »*) — ces tests portent sur la **donnée**, pas sur ce texte d'UI codé en dur, d'où la faille.

**Localisation :** `AlertsPage`, **pas** Explorer/Search → **hors périmètre Groupe 5**. À traiter dans le groupe couvrant Alerts/Info (décision **D-G5-5**).

> Note : `RECOVERY.md` affirmait que « Gare TER Keur Massar » avait été introduite par les patches. Cette affirmation **n'est pas corroborée** ; la provenance est désormais documentée par la preuve binaire ci-dessus (0 occurrence en production).

### 11.2 Correction d'un constat du Groupe 4 (F7) — `distanceMeters`

Le Groupe 4 avait marqué **NON PROUVÉ / hors périmètre** l'origine des valeurs `s.distanceMeters` utilisées par l'assistant et les affichages de distance (décision D6-i : aucune modification).

**Cet audit établit la preuve manquante.** Le binaire contient littéralement :

```js
new A.cg(b1, a3, 300 + a2*800, …)     // arrêts issus d'une ligne, a2 = index de l'arrêt
new A.cg(h, "Dir. Centre Dakar", 500, …)   // arrêts orphelins AFTU
```

soit exactement le source :

```dart
distanceMeters: 300 + (i * 800).toDouble(),   // ligne 886
distanceMeters: 500,                          // ligne 939
```

**Conclusion : F7 est CONFORME À LA PRODUCTION.** Ce ne sont pas des valeurs inventées par le source récupéré mais bien le comportement déployé. La décision **D6-i** (aucune modification des distances) est **confirmée correcte**, et son motif passe de « non prouvé » à « prouvé conforme ». Aucune action requise.

---

## 12. État final de cette étape

| Élément | État |
|---|---|
| Code modifié | **AUCUN** (règle 6) |
| Commit de code | **AUCUN** |
| JSON actif modifié | **NON** (md5 `81c778f4…` inchangé) |
| `pubspec.yaml` modifié | **NON** (md5 `a44209df…`, version `9.3.2+12`) |
| Déploiement / gh-pages | **AUCUN** (`gh-pages = 94a84b6070569…` inchangé) |
| `main` | **inchangé** (`ce8c94f14f37…`) |
| Branche de travail | `arena/01a0c385-dakar-bus` uniquement |
| Tests exécutés | aucun nouveau (aucune modification à valider) ; 162 tests existants verts au dernier run `35636348996` |
| Livrable | ce document, `docs/dakar-bus/groupe-5/PLAN_PERIMETRE.md` |

**➡️ ARRÊT ici, conformément à la règle 9. Aucune implémentation ne sera lancée tant que le périmètre et les décisions D-G5-1 à D-G5-5 n'auront pas été validés.**
