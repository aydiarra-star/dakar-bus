# CORRECTION TER + BRT — RAPPORT FINAL

**Commit :** `d5a82b8` (code + tests) puis `ff0fe79` (recentrage d'un test)
**Branche :** `arena/01a0c385-dakar-bus`
**CI :** run `106526942427` — `tests +219/-0 | analyze 0 issue(s) | exit a=0 t=0` (Flutter 3.24.5)
**Règle absolue respectée :** aucune interface modifiée.

---

## 1. Constat liminaire — ce que vous observiez n'était pas le code du dépôt

C'est le point le plus important de ce rapport.

**Votre observation « l'itinéraire BRT affiche seulement 11 éléments » est exacte — mais elle décrit l'application déployée, pas le code source actuel du dépôt.**

Preuve extraite du binaire de production (`gh-pages` `94a84b6070569`, `main.dart.js`, md5 `f5466709…`), fonction `a3j(a)` qui fabrique la fiche de ligne :

```js
a3j(a){ var j = a.x                                    // modeLabel de l'arrêt
  if (j === "TER") {
    s = [Fg,Fv,Fe,FDA,Fm,Fw,Fj,Fc,Fo,FPNR,Ff,Fq,Fd]    // 13 constantes codées en dur
    return tP("TER (Train Express Régional)", …, "Gare de Dakar", "Gare de Diamniadio", "35.0 km", s)
  } else if (j === "BRT") {
    r = [Ft,Fy,Fr,Fs,Fp,Fx,Fk,Fi,Fl,Fu,Fh]             // 11 constantes codées en dur
    return tP("SunuBRT", …, "Guédiawaye", "Gare de Petersen", "14.0 km", r)
  } else { q = aOu(a, !1) … }                           // les autres modes : dérivation JSON
```

Les 11 constantes BRT, décodées une à une, sont **exactement votre liste, dans votre ordre** :

| # | Production (`a3j`) | Votre observation |
|---|---|---|
| 1 | Guédiawaye | Guédiawaye |
| 2 | Hôpital Dalal **Jamm** | Hôpital Dalal Diam |
| 3 | Parcelles Assainies | Parcelles Assainies |
| 4 | Cambérène | Cambérène |
| 5 | Grand Yoff | Grand Yoff |
| 6 | Fadia | Fadia |
| 7 | Liberté 6 | Liberté 6 |
| 8 | Grand Médine | Grand Médine |
| 9 | Sacré-Cœur | Sacré-Cœur |
| 10 | Place de l'Obélisque | Place de l'Obélisque |
| 11 | Gare de Petersen | Gare Petersen |

**Or cette branche codée en dur n'existe plus dans le code du dépôt.** Elle a été remplacée au Groupe 3 (commit `c6a9068`) par la dérivation depuis `dakar_network.json`, conformément au §7 (« ne jamais réintroduire le modèle à 11 stations ») et au §8 (« les arrêts d'une fiche ligne proviennent du JSON courant, sans liste parallèle »).

Vérification par l'historique git : `git grep` sur `b1a645c` (Groupe 1) trouve bien `brt_2 'Hôpital Dalal Jamm'`, `brt_3 'Cambérène'`, `brt_4 'Fadia'`, `brt_6 'Grand Médine'`, `brt_9 'Sacré-Cœur'`, `brt_10 'Place de l'Obélisque'` en littéraux dans `main.dart`. Ces mêmes noms ont **0 occurrence** dans le `main.dart` actuel.

> **Conséquence pratique :** le correctif BRT que vous demandez est **déjà dans le code** mais **invisible dans l'application en ligne**, parce que `gh-pages` sert toujours l'ancien binaire et que tout déploiement est interdit (§29-30, §33). Rien n'a été déployé par ce travail.

---

## 2. État réel mesuré avant intervention

Simulation fidèle de la chaîne complète (`allStops` → `_integrateNetworkData` → `_filteredStops` → `DetailedRoute`), exécutée sur le JSON actif :

| Mesure | Valeur | Votre observation |
|---|---|---|
| Points TER dans Explorer | **21** | « environ 18 » ✅ |
| Points BRT dans Explorer | **27** | « environ 28 » ✅ |
| Itinéraire TER ouvert depuis un point résoluble | **13 gares** | « 13 gares officielles » ✅ |
| Itinéraire BRT ouvert depuis un point résoluble | **23 stations** | « 11 éléments » ❌ (voir §1) |
| Points TER non ouvrables (bouton désactivé) | **4** | — |
| Points BRT non ouvrables (bouton désactivé) | **4** | — |

### 2.1 L'origine exacte du « point vers Keur Massar »

Vous signaliez « un point situé vers Keur Massar » parmi les points TER d'Explorer. Il est identifié et chiffré :

| Marqueur | Coordonnées | Distance à la gare officielle |
|---|---|---|
| `Gare TER Keur Mbaye Fall` (liste de démonstration) | 14.77500, -17.31000 | **3,46 km** de `stop_keur_mbaye_fall` (14.74408, -17.31389) |
| | | **2,32 km** de `stop_keur_massar` (14.79000, -17.32500) |

Ce marqueur hérité est donc **mal positionné** : il porte le nom d'une gare TER officielle mais se trouve à 3,46 km d'elle, et à 2,32 km de Keur Massar — d'où son apparition « vers Keur Massar » sur la carte.

**Keur Massar lui-même n'est pas un point TER.** `stop_keur_massar` est desservi par 6 lignes — `DDD 23`, `AFTU 5`, `AFTU 38`, `AFTU 46`, `AFTU 53`, `Tata 218` — et par **aucune** ligne TER. Il reçoit donc la couleur DDD/AFTU/Tata dans Explorer, jamais la couleur TER. Le §6 est respecté par la donnée, et un test le verrouille désormais.

### 2.2 Pourquoi les 11 éléments n'étaient pas de simples « regroupements »

Vérification faite sur la source unique : trois des onze noms de la liste historique correspondent à des arrêts du JSON qui **ne sont sur aucune ligne BRT** :

| Arrêt du JSON | Identifiant | Lignes le desservant | Dont BRT |
|---|---|---|---|
| `Grand Yoff - BRT & AFTU Hub` | `stop_grand_yoff` | 20 | **AUCUNE** |
| `Fadia - BRT` | `stop_fadia` | 7 | **AUCUNE** |
| `Cambérène - BRT` | `stop_camberene` | 7 | **AUCUNE** |

Et trois autres sont des **homonymes** des stations officielles de B1, à des positions différentes :

| Nom partagé | Station officielle B1 | Homonyme hors B1 | Écart |
|---|---|---|---|
| `Hôpital Dalal Jamm - BRT` | `stop_brt_19_dalal_jamm` 14.77287, -17.40979 | `stop_dalal_jamm` 14.76200, -17.41000 | ~1,2 km |
| `Liberté 6 - BRT Correspondance` | `stop_brt_09_liberte_6` 14.72631, -17.45919 | `stop_liberte6` 14.71800, -17.45500 | ~1,0 km |
| `Sacré-Cœur - BRT` | `stop_brt_07_sacre_coeur` 14.71660, -17.46350 | `stop_sacre_coeur` 14.71000, -17.46500 | ~0,7 km |

Les coordonnées des constantes binaires `brt_2`, `brt_8`, `brt_9` sont **celles des homonymes** (`14.762,-17.41` / `14.718,-17.455` / `14.71,-17.465`), pas celles des stations officielles du corridor. La liste à 11 éléments n'était donc pas seulement regroupée : elle s'appuyait sur des arrêts **hors du corridor B1**.

La résolution actuelle est immunisée contre ce piège : `_resolveJsonStop` restreint la correspondance par nom aux arrêts desservis par le **même exploitant** (`idsOfOperator`), si bien qu'un point BRT ne peut plus retomber sur un homonyme AFTU ou DDD.

---

## 3. Ce qui a été modifié

Trois changements, tous dans la couche données. **Aucun widget, aucun écran, aucune couleur, aucun filtre, aucun bouton, aucun texte, aucun calcul de proximité.**

### 3.1 §8 — Polyligne cohérente avec les stations (seul vrai défaut restant)

`demoRoutes` (les tracés dessinés sur la carte Explorer) démarre désormais **vide** et n'est alimentée que par `_integrateNetworkData`, depuis le JSON.

**AVANT — quatre tracés littéraux, aucun aligné sur les arrêts officiels :**

| Ligne | Littéral | Officiel | Défaut |
|---|---|---|---|
| TER | 6 points | 13 gares | tracé amputé de 7 gares |
| B1 | 10 points | 23 stations | tracé amputé de 13 stations |
| DDD | 3 points | `ddd_12` | coordonnées divergentes |
| TATA | 3 points | `tata_219` | coordonnées divergentes |

**Deux défauts démontrés :**

1. **TER amputé.** La déduplication de l'intégration compare le `code` de la démo au `short_name` du JSON. `'TER' == 'TER'` → la ligne officielle `ter_dakar_diamniadio` (13 gares) était **court-circuitée et jamais ajoutée**. La carte ne dessinait que les 6 points du littéral : **7 des 13 gares officielles absentes du tracé**, en contradiction de rendu avec le §6 alors que la donnée JSON est exacte.
2. **Doublons.** `'B1' ≠ 'BRT B1'`, `'DDD' ≠ 'DDD 12'`, `'TATA' ≠ 'Tata 219'` → ces trois lignes étaient **dessinées deux fois**, avec deux géométries divergentes superposées.

**APRÈS :** un tracé par ligne officielle — TER 13 points, BRT B1 23 points, BRT B2 7, DDD 12 3, Tata 219 2. Les doublons disparaissent **à la racine** au lieu d'être masqués.

**Équivalence de rendu vérifiée** (aucune régression visuelle) : `colorForOperator('ter'|'brt'|'ddd'|'tata')` rend exactement `AppColors.ter|brt|ddd|tata` et `labelForOperator` rend `'TER'|'BRT'|'DDD'|'Tata'` — soit les mêmes couleurs et types que les littéraux supprimés. `isDedicated` (`type == 'TER' || type == 'BRT'`) reste donc vrai pour TER et BRT : **3 tracés dédiés avant comme après**, le périmètre chargé au démarrage est conservé et **aucune requête OSRM supplémentaire** n'est provoquée. Le champ `TransitRoute.name` n'est lu par aucune vue (vérifié : sa déclaration est sa seule occurrence).

### 3.2 §1/§3/§5/§6 — Séparation explicite des deux notions

Trois accesseurs **additifs** à la couche données, qui nomment formellement les deux ensembles :

```dart
List<Stop>    networkPoints(Color modeColor)                       // <MODE>_NETWORK_POINTS
List<BusStop>? officialRouteStops(String routeId, {bool reverse})   // <MODE>_OFFICIAL_ROUTE_STOPS
String?       networkOfRoute(String routeId)                        // champ « réseau »
```

`networkPoints` reprend **à l'identique** le prédicat existant de `_filteredStops` (le mode y est porté par la couleur) : aucun filtre, aucune couleur, aucun calcul de proximité modifiés.

`officialRouteStops` restitue les champs demandés au §1 sans rien dupliquer : identifiant (`BusStop.id`), nom officiel (`BusStop.name`), coordonnées, réseau (`networkOfRoute`), **ordre dans l'itinéraire** (la position dans la liste — aucune copie redondante), statut de la donnée (`BusStop.dataTrust`). `reverse` produit le sens inverse **par inversion de l'ordre courant** (§7) : aucune seconde liste, aucune copie divergente.

Elle renvoie `null` — un « inconnu » honnête (§9) — là où `DataService.stopsForRoute` lève une exception, et saute un arrêt référencé mais absent **sans inventer de substitution**.

### 3.3 Couture de test

`@visibleForTesting void integrateNetworkDataForTest()` — couture **pure**, même schéma que la décision D3-i du Groupe 4 : aucune dépendance ajoutée, `pubspec.yaml` inchangé, `main()` reste le seul appelant en production.

### 3.4 Structure recommandée du §5 — déjà en place

Votre structure cible existe déjà, à un renommage près. Aucune réécriture n'était nécessaire :

| Votre `TransitStop` | Existant | Votre `TransitRoute` | Existant |
|---|---|---|---|
| `id` | `BusStop.id` | `id` | `TransportRoute.id` |
| `name` | `BusStop.name` | `network` | `TransportRoute.operatorId` |
| `network` | porté par la ligne | `name` | `shortName` / `longName` |
| `latitude` / `longitude` | `BusStop.latitude` / `.longitude` | `stopIds` | `TransportRoute.stopIds` |
| `routeOrder` | position dans `stopIds` | | |
| `direction` | niveau ligne (`reverse`) | | |
| `status` | `BusStop.dataTrust` (`official` / `fieldObservation` / `estimated`) | | |

---

## 4. Ce qui n'a PAS été modifié, et pourquoi

### 4.1 Les 8 points du réseau non résolubles — UNKNOWN conservé, rien d'inventé

Huit points issus des listes de démonstration sont trop éloignés de leur homonyme officiel pour être résolus (seuil de 250 m, valeur prouvée du binaire `aS1`) :

| Point | Écart à l'arrêt officiel |
|---|---|
| `Gare TER Keur Mbaye Fall` | 3,46 km |
| `BRT Grand Dakar` | 1,91 km |
| `Gare TER Hann` | 1,43 km |
| `PEM Guediawaye` | 1,18 km |
| `Gare TER Colobane` | 0,78 km |
| `Gare TER Pikine` | 0,60 km |
| `PEM Petersen` | 0,42 km |
| `BRT Colobane` | **aucune station B1 ne porte ce nom** |

Pour ces 8 points, `DetailedRoute.fromStop` renvoie `null` et le bouton « Voir la ligne complète & stations » reste **désactivé**.

**Aucune correspondance n'a été forcée.** Relier `Gare TER Hann` (14.7190, -17.4450) à `stop_hann` (14.72209, -17.43207) aurait exigé d'affirmer une identité que les coordonnées contredisent à 1,43 km — soit une donnée inventée au sens du §9. Conformément à votre condition de fin (« si une donnée officielle ne peut pas être vérifiée, arrête-toi sur cette donnée, signale-la et ne l'invente pas »), **ces 8 points sont signalés ici et laissés en état d'inconnu explicite**. Deux tests verrouillent ce comportement honnête.

`BRT Colobane` est un cas à part : **aucune** station de B1 ne porte ce nom. Il n'existe donc aucune cible officielle à laquelle le relier.

### 4.2 Le sens inverse n'est pas exposé dans l'interface

Le mécanisme est **implémenté et testé** (`officialRouteStops(routeId, reverse: true)`, `DetailedRoute.fromOperator('ter'|'brt', reverse: true)`), mais **aucun appel de l'interface ne passe `reverse: true`** :

| Appel | Ligne | `reverse` |
|---|---|---|
| `DetailedRoute.fromStop(stop)` | 2995 | absent → `false` |
| `DetailedRoute.fromOperator('ter')` | 2122 | absent → `false` |
| `DetailedRoute.fromOperator('brt')` | 2125 | absent → `false` |
| `DetailedRoute.fromOperator('ddd')` | 2128 | absent → `false` |

L'onglet « Sens Retour » de `DualStopDetailPage` (ligne 2949) affiche l'**arrêt en face** (Groupe 3, §10), pas la ligne inversée : il appelle `SingleStopView`, qui appelle `fromStop` sans `reverse`.

**Exposer le sens inverse exigerait d'ajouter un contrôle à un écran existant** — ce que votre règle absolue et le §10 interdisent (« ne pas modifier les écrans existants », « ne pas refaire l'UI »). **Aucune modification d'interface n'a donc été faite.** Les deux sens sont vérifiés par tests au niveau des données ; leur exposition relève d'une décision d'interface qui vous appartient.

### 4.3 Explorer n'a pas été réduit

Conformément au §6, le compteur Explorer n'a **pas** été aligné sur le nombre de stations d'un itinéraire. Les 21 points TER et 27 points BRT sont **intégralement conservés** — deux tests figent ces valeurs.

### 4.4 Le JSON actif n'a pas été touché

`assets/data/dakar_network.json` : md5 `81c778f4644dcf5e1cf4ae25879218f0`, 59 189 octets — **inchangé**, et identique octet par octet à celui servi par `gh-pages`. Aucune fusion des homonymes, aucune suppression, aucune coordonnée ajoutée.

---

## 5. Constat de donnée : deux couloirs partagés (pas un défaut)

Le test de garde anti-doublon a échoué au premier run (218 tests, `analyze` 0 issue, **1 seul échec**). L'assertion était trop forte, pas le code.

Sur les 105 lignes du JSON, **103 géométries sont distinctes**. Les deux paires qui partagent un tracé sont des lignes **distinctes** exploitant le même couloir :

| Paire | Couloir | Différences |
|---|---|---|
| `aftu_2` (AFTU 2) / `tata_50` (Tata 50) | Guédiawaye ↔ Sandaga | `id`, `short_name`, `long_name`, `operator_id` |
| `aftu_38` (AFTU 38) / `tata_218` (Tata 218) | Mermoz ↔ Keur Massar | `id`, `short_name`, `long_name`, `operator_id` |

Le JSON étant la source unique (§4-§5), **rien n'a été fusionné ni supprimé pour satisfaire un test**. La garde a été recentrée sur le défaut réellement corrigé (lignes dédiées TER/BRT), et un test fige explicitement ces deux seuls couloirs partagés légitimes afin qu'un doublon **nouveau** — lui, réel — soit immédiatement détecté.

---

## 6. Tests

**57 tests** ajoutés dans `flutter-src/test/ter_brt_route_data_test.dart`, couvrant les validations du §11 :

| Groupe | Couverture |
|---|---|
| §1/§6 Explorer ≠ itinéraire | conservation des 21 points TER et 27 points BRT ; Explorer > itinéraire ; les 13 gares et 23 stations visibles dans Explorer ; aucun point promu ; **Keur Massar hors itinéraire TER** |
| §6 itinéraire TER | 13 gares ; ordre Dakar → Diamniadio ; ordre inverse ; l'inverse est une inversion et non une seconde liste ; terminus ; réseau ; `dataTrust` connu ; coordonnées valides et non `(0,0)` ; fiche de ligne dans les deux sens |
| §7 itinéraire BRT B1 | 23 stations ; ordre Guédiawaye → Petersen ; ordre inverse ; inversion et non seconde liste ; **23 identifiants, 23 noms et 23 coordonnées uniques** ; rejet explicite des 11 libellés historiques ; non-fusion des stations distinctes (Liberté 6/5/1, Guédiawaye/Gadaye/Golf Nord/Fith Mith) ; terminus ; réseau ; coordonnées valides ; B2 ⊂ B1 ; fiche de ligne dans les deux sens |
| §9 aucune invention | chaque station provient des `stopIds` du JSON (ni recherche, ni approximation géographique) ; absence d'arrêt fabriqué `Station Intermédiaire` (branche générique de production) ; `totalDistance` **calculé**, jamais les littéraux `14.0 km` / `35.0 km` ; un point non résoluble ne fabrique **aucune** fiche ; un point officiel résout vers sa ligne |
| §8 polyligne | un seul tracé TER de 13 points **égaux aux 13 gares dans l'ordre** ; un seul tracé B1 de 23 points **égaux aux 23 stations dans l'ordre** ; pas de doublon sur les lignes dédiées ; les 2 seuls couloirs partagés sont AFTU/Tata ; **aucune coordonnée de tracé hors source unique** ; garde-fou Dakar sur tous les points ; 105 tracés pour 105 lignes ; couleurs et types conservés ; `isDedicated` conservé (3) ; idempotence de l'intégration |
| §5 structure | ligne = identifiant + réseau + nom + `stopIds` ; station = identifiant + nom + coordonnées + statut ; ordre porté par la liste ; ligne inconnue → `null` |

**Résultat CI :** `tests +219/-0 | analyze 0 issue(s)` — 219 tests verts (162 existants + 57 nouveaux), **0 diagnostic `flutter analyze`**.

---

## 7. Signalement hors périmètre — violation du §6 dans `AlertsPage`

Signalé, **non corrigé** (hors du périmètre TER/BRT données et itinéraires, et ce sont des textes d'écran que le §10 interdit de modifier sans nécessité fonctionnelle démontrée).

`main.dart` lignes 2249-2258, `AlertsPage.officialAlerts`, codé en dur :

- `'Réseau CETUD & SETER (14 Gares)'`
- `'Le TER dessert officiellement 14 gares de Dakar à Diamniadio en passant par Colobane, Hann, Pikine, Keur Massar et Rufisque.'`
- badge `'14 Gares Officielles'`

Ce texte contredit le §6 (TER = 13 gares) **et nomme Keur Massar comme gare TER**, alors que la donnée JSON ne fait desservir `stop_keur_massar` par aucune ligne TER.

Preuve binaire : `'14 Gares'` → **0 occurrence** ; `'14 gares'` → **0 occurrence** ; `'13 gares'` → **2 occurrences**. La production affiche « 13 gares desservies ». **Ce texte est une invention du source seul.**

Note annexe : la constante `ter_8 "Keur Massar"` (14.79, -17.325) existe bien dans le binaire de production, mais elle est **définie et jamais utilisée** — une seule occurrence, sa définition. Elle n'appartient pas à la liste des 13 gares de la branche TER. La production ne présente donc pas Keur Massar comme gare de l'itinéraire TER.

Les tests Groupe 1 existants (`network_data_test.dart:120` et `:167`) portent sur la **donnée**, pas sur ce texte d'UI — d'où la faille. Le nouveau test « Keur Massar reste hors de l'itinéraire TER (§6) » couvre la couche données ; le texte d'`AlertsPage` reste à traiter.

---

## 8. Invariants vérifiés en fin de travail

| Invariant | Valeur | État |
|---|---|---|
| `main` | `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` | ✅ inchangé |
| `gh-pages` | `94a84b6070569bed708b8e779b9e70b7c9dafa45` | ✅ inchangé, aucun déploiement |
| `arena/01a0c385-dakar-bus` | `ff0fe79ef118d15d1f86b40acf35a7ee41409f00` | seule branche poussée |
| `dakar_network.json` | md5 `81c778f4644dcf5e1cf4ae25879218f0`, 59 189 o | ✅ inchangé |
| `pubspec.yaml` | md5 `a44209df21aa059becf0ae95dcc8d058`, version `9.3.2+12` | ✅ inchangé, aucune dépendance ajoutée |
| Arbre de travail | — | ✅ propre |
| Déploiement / release / PR de déploiement | — | ✅ aucun |

---

## 9. Réponses au format imposé (§12)

```
TER
- nombre de gares officielles dans l'itinéraire : 13
- Explorer conservé : OUI (21 points, aucun retiré)
- direction Dakar → Diamniadio : OK
- direction Diamniadio → Dakar : OK (données + tests)
    réserve : le sens inverse n'est exposé par aucun contrôle d'interface ;
    l'ajouter modifierait un écran existant, ce que la règle absolue interdit.

BRT
- nombre de stations officielles dans B1 : 23
- anciennes stations regroupées : 11
    (dans le binaire déployé uniquement — déjà retirées du source au Groupe 3 ;
     3 d'entre elles ne sont sur aucune ligne BRT, 3 autres sont des homonymes
     hors corridor)
- nouvelles stations distinctes : 23
    (aucune créée : toutes issues de dakar_network.json ; 23 identifiants,
     23 noms et 23 coordonnées uniques)
- direction Guédiawaye → Petersen : OK
- direction Petersen → Guédiawaye : OK (données + tests, même réserve UI)

INTERFACE
- UI modifiée : NON
- navigation modifiée : NON
- carte modifiée : NON
    (aucun widget, tuile, zoom, marqueur, couleur, filtre ou bouton touché ;
     seule la géométrie des polylignes est corrigée, comme l'exige le §8)

DONNÉES
- données inventées : NON
- données inconnues explicitement conservées : OUI
    (8 points du réseau non résolubles, 0,42 à 3,46 km de leur homonyme
     officiel : fiche = null, bouton désactivé, aucune correspondance forcée)
```

### Condition de fin

| Condition | État |
|---|---|
| TER = 13 gares officielles correctement ordonnées dans son itinéraire | ✅ atteint, verrouillé par tests |
| BRT B1 = stations officielles distinctes correctement ordonnées dans les deux directions | ✅ atteint (23), verrouillé par tests |
| Explorer conservé | ✅ 21 TER / 27 BRT, figé par tests |
| Interface actuelle conservée | ✅ aucun widget modifié |

**Réserve à lever par vous, et non par moi :** le correctif n'est visible dans l'application en ligne qu'après un déploiement, qui reste interdit par le §29-30 et le §33. `gh-pages` sert toujours le binaire à 11 stations.
