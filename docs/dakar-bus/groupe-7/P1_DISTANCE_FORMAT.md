# GROUPE 7 — P1 : alignement de `DistanceHelper.format` sur `A.azr`

**Anomalie traitée : O1** de l'audit Groupe 7
(`docs/dakar-bus/groupe-7/AUDIT_GPS_DISTANCE_DEPARTS.md`).

Périmètre : **une seule fonction** + ses tests. Aucun autre comportement modifié.

- **Commit de la correction** : `e506b72`
- **Commit du présent rapport** : voir §7
- **Référence avant correction** : `e2ebbd1` (231 tests, analyze 0 issue)
- **CI après correction** : check-run `106616675690` → `success`, **232 tests, 0 échec, analyze 0 issue**

---

## 1. Problème constaté

L'audit Groupe 7 a établi que le formateur de distance du source divergeait de celui de la
production déployée, en **deux points** :

| | Source avant correction | Production (`A.azr`) |
|---|---|---|
| Seuil de bascule mètres → kilomètres | **1000 m** | **950 m** |
| Au-delà de 10 km | **une décimale conservée** | **kilomètres entiers** |

```dart
// AVANT — lib/main.dart:1207-1210
static String format(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000.0).toStringAsFixed(1)} km';
}
```

Conséquences visibles pour l'utilisateur, aux deux seuls points d'affichage de `format`
(le sous-titre de `StopCard` L2123 et la réponse « Tu es près de » de l'assistant L2916) :

| Distance | Avant | Production | Écart |
|---|---|---|---|
| 999 m | `999 m` | `1.0 km` | ❌ |
| 10 000 m | `10.0 km` | `10 km` | ❌ |
| 12 345 m | `12.3 km` | `12 km` | ❌ |
| 17 900 m | `17.9 km` | `18 km` | ❌ |
| 35 000 m | `35.0 km` | `35 km` | ❌ |

Portée réelle : la bande ≥ 10 km concerne **14 des 141 arrêts** quand le GPS est absent
(10 stations B1 d'index ≥ 13, 3 arrêts TER de démonstration dont 2 à 35 km, 1 arrêt BRT à
10,5 km), ainsi que **toute distance GPS réelle ≥ 10 km**. La bande 950-999 m n'est atteinte
que par des distances GPS réelles (les valeurs statiques `300 + i×800` et les littéraux de
démonstration n'y tombent jamais).

Les trois assertions de test préexistantes (`format(850)`, `format(1500)`, `format(100)`)
se situaient toutes dans la zone où source et production **concordent** : elles verrouillaient
donc le comportement divergent sans jamais le détecter.

---

## 2. Comportement production observé

Source de preuve : binaire de production gh-pages `94a84b60` → `main.dart.js`,
2 497 533 octets, blob `4260bdf5a569c753e3470af2cb35b8055c56b43d`.

### 2.1 Le formateur

```js
azr(a){ var s;
  if (a < 950) return "" + B.c.a4(a) + " m";
  s = a / 1000;
  if (s < 10) return B.c.aa(s, 1) + " km";
  return "" + B.c.a4(s) + " km"; }
```

### 2.2 Les deux opérateurs, vérifiés individuellement

Ni `a4` ni `aa` n'ont été présumés : leurs **définitions** ont été lues dans le binaire.

```js
// B.c.a4 = round()  — et non ceil() : le message d'erreur le prouve
a4(a){ if(a>0){ if(a!==1/0) return Math.round(a) }
       else if(a>-1/0) return 0-Math.round(0-a)
       throw A.d(A.a6(""+a+".round()")) }

// B.c.aa(a,b) = toStringAsFixed(b) — compilé en toFixed natif
aa(a,b){ var s;
  if(b>20) throw A.d(A.cr(b,0,20,"fractionDigits",null));
  s = a.toFixed(b);
  if(a===0 && this.gkk(a)) return "-"+s;
  return s }
```

`ceil` et `floor` existent séparément dans le même binaire (`Math.ceil` avec message `".ceil()"`,
`Math.floor`), ce qui exclut toute confusion avec `a4`.

### 2.3 `azr` est bien l'équivalent de `DistanceHelper.format`

Les trois points d'appel de `A.azr` dans le binaire correspondent exactement aux points d'appel
de `format` dans le source :

| Binaire | Source | Contexte |
|---|---|---|
| `j = A.azr(f.d)` dans `A.aiK.$2` | L2123 | sous-titre de `StopCard` |
| `"📍 à " + A.azr(A.ew(r.r, q.r))` | L2916 | assistant, arrêt opposé |
| `"• "+s.a+" — "+s.got()+" • "+s.b+" ("+A.azr(a.b)+")"` | — | liste d'arrêts proches |

### 2.4 Les distances de `DetailedRoute` ne passent **pas** par `azr`

La production formate ses distances de ligne en ligne : `g = B.c.aa(k/1000, 1)` puis `g + " km"`,
soit `toStringAsFixed(1)` **sans seuil ni branche entière**. Le source fait exactement la même
chose aux L494 et L516. Ces deux implémentations concordent déjà et sont **hors périmètre** de P1 —
d'où l'absence d'effet sur les tests `TER : totalDistance = 34.6 km`, `BRT B1 : 17.5 km`,
`BRT B2 Express : 16.0 km` et `format « N.N km » : une seule décimale`.

### 2.5 ⚠️ Valeur charnière 950 m : la production affiche « 0.9 km », pas « 1.0 km »

Point établi pendant l'implémentation et **vérifié empiriquement par la CI** (voir §5).

`950 / 1000.0` n'est pas `0.95` en IEEE-754 : c'est exactement
**`0.9499999999999999555910790149937383830547332763671875`**, strictement **inférieur** à 0,95.
Or `toStringAsFixed` est compilé en `toFixed` natif (§2.2), qui arrondit la valeur binaire exacte :

```
(950/1000.0).toPrecision(20) = 0.94999999999999995559
(0.9499999999999999556).toFixed(1) = "0.9"
```

**La production affiche donc « 0.9 km » pour 950 m.** L'attente « 950 m → 1.0 km » figurant dans
l'énoncé de la tâche provenait d'un arrondi décimal mental (0,95 → 1,0) et non du comportement
réel du binaire. Comme l'objectif assigné était l'alignement sur `A.azr` **réellement observé**,
c'est la valeur réelle — « 0.9 km » — qui a été implémentée et verrouillée par le test.

Les sept autres valeurs attendues de l'énoncé sont en revanche **exactes** et ont été reprises
telles quelles (850 → `850 m`, 949 → `949 m`, 999 → `1.0 km`, 1500 → `1.5 km`,
9999 → `10.0 km`, 10000 → `10 km`, 17900 → `18 km`).

> Note : la section §4 de l'énoncé initial décrivait le comportement du **source** en
> l'étiquetant « production observé », et inversement. Elle a été explicitement écartée ;
> c'est le binaire qui fait foi.

---

## 3. Correction effectuée

**Fichier** : `flutter-src/lib/main.dart`, fonction `DistanceHelper.format` (anciennement L1207-1210).

```dart
// APRÈS
static String format(double meters) {
  if (meters < 950) return '${meters.round()} m';
  final double km = meters / 1000.0;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
```

Portée exacte du changement dans `lib/` :

| | |
|---|---|
| Lignes de code modifiées | **2 supprimées, 4 ajoutées** (le corps de `format`) |
| Lignes de commentaire ajoutées | 38 (documentation de la preuve, dans la même fonction) |
| Classes ajoutées / supprimées | **0** |
| Méthodes renommées | **0** |
| Signatures modifiées | **0** — `static String format(double meters)` inchangée |
| Points d'appel modifiés | **0** — L2123 et L2916 inchangés |
| Constantes / seuils touchés ailleurs | **0** |
| Total `lib/main.dart` | 3272 → 3310 lignes (+38, uniquement le commentaire) |

Le diff `lib/` vérifié ligne à ligne ne contient **que** le bloc `class DistanceHelper { … format … }`.
Aucune ligne de signature (`class`, `static`, `void`, `Widget`, `_distanceTo`, `nearbyStops`,
`GpsResolver`, `_generateSchedule`, `_terBase`, `_brtBase`, `DataStatus`, `remainingMinutes`,
`nextDeparture…`) n'apparaît dans le diff.

Contrôle d'intégrité structurelle : compte des délimiteurs après suppression des commentaires et
des littéraux de chaîne — accolades 317/317 (écart 0), crochets 150/150 (écart 0), parenthèses
1985/1983 (écart +2, **identique à celui de la version HEAD non modifiée** : artefact du lexer sur
les interpolations `${…}` et les littéraux regex, aucun déséquilibre introduit).

### Effet d'affichage résultant

Conformément à l'énoncé, les changements d'affichage sont une conséquence directe de l'alignement
sur `A.azr` et non une modification de la logique des arrêts :

| Distance | Avant | Après | |
|---|---|---|---|
| 0 / 1 / 100 / 850 / 949 m | identique | identique | ✅ inchangé |
| **950 m** | `950 m` | `0.9 km` | ✅ aligné (§2.5) |
| **999 m** | `999 m` | `1.0 km` | ✅ aligné |
| 1000 / 1500 / 9999 m | identique | identique | ✅ inchangé |
| **10 000 m** | `10.0 km` | `10 km` | ✅ aligné |
| **12 345 m** | `12.3 km` | `12 km` | ✅ aligné |
| **17 900 m** | `17.9 km` | `18 km` | ✅ aligné |
| **35 000 m** | `35.0 km` | `35 km` | ✅ aligné |

Aucune **valeur** de distance n'est modifiée : seule sa **mise en forme** change, et uniquement dans
les deux bandes où le source divergeait de la production.

---

## 4. Tests ajoutés / modifiés

**Fichier** : `flutter-src/test/dakar_bounds_test.dart`, groupe `DistanceHelper` uniquement.

### 4.1 Test existant étendu (aucun test ajouté à ce stade)

`test('format', …)` : **2 assertions → 14 assertions**, couvrant les trois branches et les deux
seuils. Les 2 assertions d'origine (850, 1500) sont conservées à l'identique.

| Branche | Valeurs verrouillées | Attendu |
|---|---|---|
| 1 — mètres (`< 950`) | 0, 1, 100, 850, 949 | `0 m`, `1 m`, `100 m`, `850 m`, `949 m` |
| 2 — km à 1 décimale (`≥ 950` et `< 10 km`) | 950, 999, 1000, 1500, 9999 | `0.9 km`, `1.0 km`, `1.0 km`, `1.5 km`, `10.0 km` |
| 3 — km entiers (`≥ 10 km`) | 10000, 12345, 17900, 35000 | `10 km`, `12 km`, `18 km`, `35 km` |

Toutes les valeurs exigées par l'énoncé sont présentes (0, 1, 999, 1000, 1500, 17900, 10000),
complétées par 100, 850, 949, 950, 9999, 12345, 35000.

La valeur charnière 950 m est verrouillée à **`0.9 km`** avec un commentaire expliquant l'arrondi
IEEE-754 (§2.5), pour qu'une relecture ultérieure ne la « corrige » pas en `1.0 km` par intuition.

### 4.2 Test ajouté

`test('format — les trois branches de A.azr sont distinctes (Groupe 7 P1)', …)` — **6 assertions**,
garde-fou contre le retour des deux divergences d'O1 :

- `format(949)` se termine par ` m` et `format(950)` par ` km` → **verrouille le seuil à 950**,
  donc interdit le retour au seuil 1000 ;
- `format(9999)` se termine par `.0 km` → la branche 2 conserve bien sa décimale ;
- `format(10000)` et `format(17900)` **ne contiennent aucun point** → **verrouille l'arrondi
  entier ≥ 10 km**, avec `reason:` explicite (« 17900 m doit donner « 18 km », jamais « 17.9 km » »).

### 4.3 Bilan

| | Avant | Après |
|---|---|---|
| Tests dans `dakar_bounds_test.dart` | 17 | **18** |
| Tests au total | 231 | **232** |
| Tests placeholder créés | — | **0** |
| Assertions sur `format` | 3 | **20** |

Aucun test placeholder n'a été créé. Le test placeholder **préexistant**
(`'placeholder - verified via modeLabel'`, anomalie O21) a été **laissé intact** : le corriger
relèverait de O5/O21, explicitement hors périmètre de P1. Son assertion
`format(100) == '100 m'` reste vraie après la correction (100 < 950), donc il ne casse pas.

---

## 5. Résultats CI / analyze

Run : check-run `106616675690`, commit `e506b72`,
https://github.com/aydiarra-star/dakar-bus/actions/runs/35687273061/job/106616675690

### 5.1 Résumé autoritaire (`.output.summary`)

```
tests +232/-0 | 9 fichiers | analyze 0 issue(s) | exit a=0 t=0 | Flutter 3.24.5 • channel stable
```

### 5.2 `flutter analyze` — intégral

```
Analyzing flutter-src...
No issues found! (ran in 12.0s)
```

**0 issue.** Aucun avertissement introduit (en particulier `prefer_const_declarations` n'est pas
déclenché : `final double km = meters / 1000.0;` n'est pas une expression constante).

### 5.3 `flutter test` — intégral

```
00:03 +232: All tests passed!
```

- **232 tests passés, 0 échec** (`grep -cE "\-[0-9]+:"` sur le log → **0**)
- Les 8 fichiers de test sont exécutés, dont `dakar_bounds_test.dart`
- Le compte passe de 231 à **232** : exactement **+1**, le test ajouté en §4.2. Le test étendu
  en §4.1 ne change pas le compte, comme attendu.
- Le log `.output.text` est tronqué à 47 994 octets par la limite GitHub des check-runs : toutes
  les lignes individuelles ne sont pas visibles, mais le décompte final `+232` et
  `All tests passed!` sont exhaustifs.

### 5.4 Confirmation empirique de la valeur charnière

Le passage de `expect(DistanceHelper.format(950), '0.9 km')` **confirme sur la VM Dart réelle**
l'analyse IEEE-754 du §2.5 : la VM et dart2js (`toFixed`) s'accordent. Cette assertion n'était
pas vérifiable localement (aucun SDK Flutter dans le sandbox) ; elle l'est désormais par la CI.

### 5.5 Aucune régression

Les 231 tests antérieurement verts **restent verts** (232 = 231 + 1). En particulier :
- les 3 assertions préexistantes sur `format` (850, 1500, 100) ;
- `TER : totalDistance = 34.6 km`, `BRT B1 : 17.5 km`, `BRT B2 Express : 16.0 km`,
  `totalDistance == somme haversine INDÉPENDANTE`, `format « N.N km » : une seule décimale`
  → inchangés, car `DetailedRoute` formate en ligne (§2.4) ;
- les 40 tests GPS, les 34 tests d'arrêt opposé, les 57 tests TER/BRT, les 22 tests réseau,
  les 12 tests alertes Groupe 6, les 10 tests DataService.

---

## 6. Fichiers touchés

| Fichier | Nature | Lignes |
|---|---|---|
| `flutter-src/lib/main.dart` | modifié | +40 / −2 (corps de `format` + documentation) |
| `flutter-src/test/dakar_bounds_test.dart` | modifié | +47 / −0 |
| `docs/dakar-bus/groupe-7/P1_DISTANCE_FORMAT.md` | créé | ce rapport |

`git diff --stat` sur le commit `e506b72` : **2 fichiers, 87 insertions, 2 suppressions.**

Aucun autre fichier n'apparaît dans `git status` ni dans le diff.

---

## 7. Éléments explicitement NON modifiés

### 7.1 Vérifié par diff et par somme de contrôle

| Élément | Preuve |
|---|---|
| `assets/data/dakar_network.json` | md5 **`81c778f4644dcf5e1cf4ae25879218f0`** — identique à la référence ; `git diff --stat -- flutter-src/assets` **vide** |
| `pubspec.yaml` / `pubspec.lock` | `git diff --stat` **vide** → **aucune dépendance ajoutée, modifiée ou retirée** |
| 13 gares TER | données et tests inchangés ; les 57 tests `ter_brt_route_data_test` verts |
| 23 stations BRT B1 (+ 7 B2) | idem |
| gh-pages | toujours à **`94a84b6070569bed708b8e779b9e70b7c9dafa45`** — `git ls-remote origin gh-pages` inchangé |
| Déploiement | **aucun** : aucun build de production, aucune publication, aucun `flutter build web` |

### 7.2 Vérifié par lecture du diff `lib/` (aucune de ces lignes n'y apparaît)

| Non modifié | Repère |
|---|---|
| GPS : `_requestLocation`, `getPositionStream`, `_applyGps`, `_userPosition` | L1476-1560 |
| `GpsResolver`, `GpsState`, `GpsResolution`, `DakarBounds` | L1287, 1323, 1348-1463 |
| `nearbyStops`, `nearbyRadiusMeters` (4000 m), `nearbyLimit` (30) | L1451-1461, 1353, 1357 |
| `_findNearestStop` (**anomalie O2 laissée ouverte**) | L1135-1142 |
| `_distanceTo` et la valeur `distanceMeters` (**O3 laissée ouverte**) | L1759, L974 |
| `300 + (i * 800)` et la déduplication `existingKeys` (**O4 laissée ouverte**) | L974, L890, L1016 |
| `_resolveJsonStop`, `kMaxResolveMeters` (250 m) | L538-577, L379 |
| Horaires : `_generateSchedule`, `_shift`, `_isSunday`, `_buildTerBase`, `_terBase`, `_brtBase` | L253-262 |
| Départs : `isContinuousFlow`, `_isServiceOpen`, `nextDepartureMinutes`, `remainingMinutes`, `nextDepartureLabel`, `departureAfter` | L672-716 |
| Flux continu AFTU / Tata / DDD (« 5 min ») | L672, 685, 696 |
| Fenêtre de service inline de `StopCard` (**O7 laissée ouverte**) | L2078 |
| `DataStatus` (**O6 laissée ouverte**) | L719 |
| `StopCard`, `ExplorerPage`, toute l'UI, textes, couleurs, styles, navigation | — |
| `AIChatPage` (**O10 laissée ouverte**, réservée au Groupe 9) | L2774+, dont L2922 |
| Alertes : `AlertsPage`, `CommunityAlertsPage` (Groupe 6) | — |
| Itinéraires : `RoutePlanner`, vitesses 35/20 km/h, `DetailedRoute` | L1145-1175, L480-520 |
| `OppositeStopService` (120 m / 500 m) | L218, L237 |
| Polylignes (Groupe 5), OSRM | L1041+, L128 |
| `TimeHelper.getCrowdLevel`, `formatRemaining` | L1188-1203 |
| `haversineMeters` (R = 6 371 008,8 m) | L1229 |

### 7.3 Anomalies Groupe 7 volontairement **non** traitées

Conformément à l'interdiction absolue de l'énoncé, **seule O1 a été corrigée**. Restent ouvertes,
dans leur périmètre respectif :

**O2** (arrêt de repli de `_findNearestStop`), **O3** (distances statiques sans GPS),
**O4** (doublons d'arrêts homonymes), **O5** (couverture horaires/départs),
**O6** (`DataStatus.unknown`), **O7** (double fenêtre de service), **O8** (`_isSunday` évalué une
fois), **O9** (aucun report au lendemain), **O10** (« Alertes en temps réel » → Groupe 9),
**O11** (segment « lignes » absent du `StopCard`), **O12** (chemin GPS ponctuel supprimé),
**O13** (deux centres « Dakar » à 4,07 km), et **O14** à **O23**.

Les horaires synthétiques, les départs AFTU/Tata/DDD, les données TER/BRT, les itinéraires, les
arrêts, l'UI, l'IA et les alertes n'ont fait l'objet d'**aucune** modification.

---

## 8. Contrôle Git

```
Commit de la correction : e506b72  fix(groupe-7-P1): aligner DistanceHelper.format
                                     sur le formateur production A.azr
Commit parent (référence): e2ebbd1  docs(groupe-7): audit strict GPS → … → départs
Branche                  : arena/01a0c385-dakar-bus (poussée sur elle seule)
git status --porcelain   : vide après chaque commit
Fichiers du commit       : flutter-src/lib/main.dart
                           flutter-src/test/dakar_bounds_test.dart
Tests                    : 232 (+232 / -0)
flutter analyze          : No issues found! (0 issue)
JSON                     : md5 81c778f4644dcf5e1cf4ae25879218f0 — inchangé
Dépendances              : pubspec.yaml / pubspec.lock inchangés
gh-pages                 : 94a84b60 — inchangée
Déploiement              : aucun
```

---

## 9. Condition de succès

| Critère | Statut |
|---|---|
| `DistanceHelper.format` aligné sur le comportement production identifié | ✅ les 3 branches de `A.azr` reproduites, opérateurs `round`/`toStringAsFixed` prouvés |
| Les tests couvrent les seuils | ✅ 950 / 949 (seuil mètres), 10000 / 9999 (seuil 10 km), 20 assertions |
| Tous les tests passent | ✅ 232/232, `All tests passed!` |
| `flutter analyze` = 0 issue | ✅ `No issues found!` |
| Aucun autre comportement fonctionnel modifié | ✅ diff `lib/` confiné au corps de `format` (§7.2) |
| JSON inchangé | ✅ md5 identique |
| Aucun déploiement | ✅ gh-pages `94a84b60` inchangée |

---

**GROUPE 7 — P1 TERMINÉ — DISTANCEHELPER ALIGNÉ — AUCUN AUTRE COMPORTEMENT MODIFIÉ**
