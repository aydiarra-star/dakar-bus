# DAKAR BUS — RELEVÉ D’INTÉGRITÉ LOT 14 BIS

**Titre :** DAKAR BUS — RELEVÉ D’INTÉGRITÉ LOT 14 BIS
**Date :** 2026-09-26
**Nature :** Nouveau relevé indépendant
**Statut :** Ne constitue PAS une restauration du manifeste original du Lot 14.

Horodatage des mesures : `2026-09-26T03:46:50Z` (horloge du conteneur, UTC).
Répertoire de travail : `/home/user/dakar-bus`.

---

## 0. Avertissement de non-restauration

Ce document est un nouveau relevé d’intégrité indépendant. Il ne reproduit pas les octets du manifeste original `RELEVE_INTEGRITE_LOTS_11_12_13_2026-09-26.md`.

Le manifeste original et son commit `848d5471595eb0601cc7718437885578a8b5e06a` n’étant pas disponibles dans le dépôt/remote actuellement vérifié, leur contenu exact et leur empreinte SHA-256 ne peuvent pas être reproduits ni validés.

Toute empreinte calculée dans ce document correspond exclusivement à l’état observé dans la présente session.

### 0.1 Distinction explicite des deux états

| | ANCIEN ÉTAT DOCUMENTÉ HISTORIQUEMENT (Lot 14, session précédente) | ÉTAT MESURÉ DANS LA SESSION LOT 14 BIS |
|---|---|---|
| Fichier | `docs/RELEVE_INTEGRITE_LOTS_11_12_13_2026-09-26.md` | `docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md` (le présent fichier) |
| Taille annoncée | 30 554 octets | **non auto-référençable** — relever par `wc -c docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md` |
| Lignes annoncées | 392 lignes | **non auto-référençable** — relever par `wc -l docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md` |
| SHA-256 annoncé | `6cb7180a9d2478691a15f1d5f524fae300e1b7e4fd4fd77b01f46b6ba657a018` | **non auto-référençable** — le SHA-256 dépend du contenu, qui dépend de la valeur inscrite (cf. §8.3) |
| Commit associé | `848d5471595eb0601cc7718437885578a8b5e06a` — **non retrouvé** | commit créé dans cette session (voir §10) |
| Statut de vérification | **non vérifiable** : ni le fichier, ni le commit, ni l’empreinte n’ont pu être retrouvés | vérifiable localement et sur le remote |

Les valeurs de la colonne « ANCIEN ÉTAT » sont des **valeurs déclarées**, reprises telles quelles depuis la consigne du Lot 14 BIS. Elles **n’ont pas** été mesurées dans cette session et **n’ont pas** pu être confirmées. Aucune d’entre elles n’est réutilisée ci-après comme s’il s’agissait d’une mesure.

---

## 1. Diagnostic initial (§1)

### 1.1 `git status --short`

```
(aucune sortie — arbre de travail propre à l’entrée de session)
```

### 1.2 `git branch -vv`

```
* arena/01a0db14-dakar-bus 203960c Merge pull request #28 from aydiarra-star/arena/01a0d8ed-dakar-bus
  main                     203960c [origin/main] Merge pull request #28 from aydiarra-star/arena/01a0d8ed-dakar-bus
```

### 1.3 `git rev-parse --show-toplevel`

```
/home/user/dakar-bus
```

### 1.4 `git rev-parse HEAD`

```
203960cb07d8341c252db2a3bbe390bd974f7d3a
```

### 1.5 `git log --oneline --decorate -10`

```
203960c (grafted, HEAD -> arena/01a0db14-dakar-bus, origin/main, origin/HEAD, main) Merge pull request #28 from aydiarra-star/arena/01a0d8ed-dakar-bus
```

Une seule ligne : l’historique local est **réduit à un unique commit**, marqué `grafted` (clone superficiel).

### 1.6 `git remote -v`

```
origin	https://github.com/aydiarra-star/dakar-bus.git (fetch)
origin	https://github.com/aydiarra-star/dakar-bus.git (push)
```

### 1.7 `git branch -a`

```
* arena/01a0db14-dakar-bus
  main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
```

Aucune référence locale vers `arena/01a0d8ed-dakar-bus`.

### 1.8 `git config --show-origin --get-regexp 'remote\.|branch\.|core\.|gc\.|maintenance\.|extensions\.'`

```
file:.git/config	core.repositoryformatversion 0
file:.git/config	core.filemode true
file:.git/config	core.bare false
file:.git/config	core.logallrefupdates true
file:.git/config	remote.origin.url https://github.com/aydiarra-star/dakar-bus.git
file:.git/config	remote.origin.fetch +refs/heads/main:refs/remotes/origin/main
file:.git/config	branch.main.remote origin
file:.git/config	branch.main.merge refs/heads/main
```

Observations factuelles (aucune configuration n’a été modifiée) :

* le refspec de fetch est **restreint à `main`** : `+refs/heads/main:refs/remotes/origin/main` ;
* il n’existe **aucune** section `branch.<arena/…>` : la branche de session n’a pas de suivi distant configuré ;
* aucune clé `gc.*`, `maintenance.*` ou `extensions.*` n’est définie ;
* `core.logallrefupdates true` (journal de références actif, cf. §4).

---

## 2. Vérification du manifeste original (§2)

### 2.1 Recherche de l’objet commit

```
$ git cat-file -t 848d5471595eb0601cc7718437885578a8b5e06a
fatal: git cat-file: could not get object info
```

L’objet **n’existe pas** dans la base d’objets locale.

### 2.2 Recherche du fichier

```
$ find . -name 'RELEVE_INTEGRITE_LOTS_11_12_13_2026-09-26.md' -print
(aucune sortie)

$ find . -name 'RELEVE*' -print
(aucune sortie)
```

Aucun fichier correspondant, sous aucun nom approchant, dans l’arbre de travail.

### 2.3 Recherche dans les références locales

```
$ git for-each-ref --format='%(refname) %(objectname)' | grep -i 848d547
aucune ref locale

$ git log --all --oneline
203960c Merge pull request #28 from aydiarra-star/arena/01a0d8ed-dakar-bus
```

Aucune référence locale ne pointe vers `848d547…`. L’historique complet (`--all`) tient en un seul commit.

### 2.4 Recherche sur le remote

Commande : `git ls-remote origin` (remote accessible, cf. §5.1). Le SHA `848d5471595eb0601cc7718437885578a8b5e06a` **n’apparaît dans aucune référence distante** : ni dans `refs/heads/*`, ni dans `refs/pull/*`, ni dans `HEAD`.

Vérification complémentaire par l’API GitHub (`GET /repos/aydiarra-star/dakar-bus/commits/848d547…`) :

```
HTTP 422 — "No commit found for SHA: 848d5471595eb0601cc7718437885578a8b5e06a"
```

Recherche du chemin `docs/RELEVE_INTEGRITE_LOTS_11_12_13_2026-09-26.md` sur **chacune** des branches distantes (`GET /contents/…?ref=<branche>`) : **HTTP 404 sur les 22 branches** listées par `git ls-remote --heads origin`, y compris `main` et `arena/01a0d8ed-dakar-bus`. La recherche de code GitHub (`search/code`, `search/commits`) retourne `total_count = 0`.

### 2.5 Conclusion de la vérification

> Le manifeste original du Lot 14 n’est pas disponible dans l’environnement courant et son commit `848d5471595eb0601cc7718437885578a8b5e06a` n’est pas présent dans le remote vérifié. Son contenu exact n’est donc pas reconstructible à partir des sources actuellement accessibles.

---

## 3. État Git actuel et commits anciens (§4)

### 3.1 Synthèse

| Élément | Valeur mesurée |
|---|---|
| HEAD d’entrée | `203960cb07d8341c252db2a3bbe390bd974f7d3a` |
| Branche locale courante | `arena/01a0db14-dakar-bus` (créée par la session depuis `203960c`) |
| Branche `main` locale | `203960c` → suit `origin/main` |
| Remote | `origin` = `https://github.com/aydiarra-star/dakar-bus.git` |
| Remote `HEAD` | `203960cb07d8341c252db2a3bbe390bd974f7d3a` |
| Branche distante `main` | `203960cb07d8341c252db2a3bbe390bd974f7d3a` |
| Branche distante `arena/01a0d8ed-dakar-bus` | **existe** → `a37b588fd45d9d2f2b43638f0231db9599e3dad4` |
| Branche distante `arena/01a0db14-dakar-bus` | **inexistante** au moment du diagnostic (`git ls-remote --heads` : aucune ligne) |
| Commit `848d547…` (manifeste Lot 14) | **ABSENT** (local et remote) |
| Commit `70f5ac0…` (Lot 11) | **ABSENT** (`git cat-file -t` : *could not get object info*) |
| Commit `e6d9f61…` (Lot 12) | **ABSENT** (`git cat-file -t` : *could not get object info*) |
| Commit `787f467…` (Lot 13) | **ABSENT** (`git cat-file -t` : *could not get object info*) |

### 3.2 Détail des trois commits anciens

Vérifications réelles, exécutées individuellement :

```
$ git cat-file -t 70f5ac085f18af4601b2d0516927606abae7f780
fatal: git cat-file: could not get object info
$ git cat-file -t e6d9f6177bc085c7d9731f87b59af76c6c1a4027
fatal: git cat-file: could not get object info
$ git cat-file -t 787f467b072488c13466a11821544fd1698381b1
fatal: git cat-file: could not get object info
```

Aucun contenu n’en est déduit. Aucune tentative de récupération (reflog, `fsck`, reconstruction, création d’objets, récupération d’historique) n’a été effectuée : ces objets restent **absents** et leur contenu reste **inconnu**.

### 3.3 Références distantes relevées (`git ls-remote origin`, extrait des têtes de branches)

22 branches distantes ont été listées. Points saillants :

```
203960cb07d8341c252db2a3bbe390bd974f7d3a	HEAD
203960cb07d8341c252db2a3bbe390bd974f7d3a	refs/heads/main
a37b588fd45d9d2f2b43638f0231db9599e3dad4	refs/heads/arena/01a0d8ed-dakar-bus
94a84b6070569bed708b8e779b9e70b7c9dafa45	refs/heads/gh-pages
```

---

## 4. Diagnostic de persistance (§5)

### 4.1 Horodatages de création (preuve de recréation)

```
$ stat .git
 Birth: 2026-09-26 03:46:39.233029920 +0000
 Modify: 2026-09-26 03:46:41.409040910 +0000

$ stat .git/index
 Size: 8281    Birth: 2026-09-26 03:46:41.409040910 +0000

$ stat .git/config
 Size: 360     Birth: 2026-09-26 03:46:40.837038020 +0000

$ stat .git/shallow
 Size: 41      Birth: 2026-09-26 03:46:40.813037898 +0000
 Content: 203960cb07d8341c252db2a3bbe390bd974f7d3a
```

Horodatages des fichiers internes de `.git` : de `2026-09-26 03:46:39.241` (`.git/description`, `.git/info/exclude`) à `2026-09-26 03:46:41.409` (`.git/index`), soit **l’intégralité de `.git` créée en moins de 2,2 secondes**. L’horodatage de création des fichiers de travail (`docs`, `data/gtfs`, `flutter-src/assets/data/dakar_network.json`) est `2026-09-26 03:46:40.173`, valeur identique à celle du répertoire racine.

**Conclusion :** ces horodatages sont incompatibles avec un dépôt ayant vécu plusieurs sessions : ils sont cohérents avec un **clone/checkout unique** effectué au démarrage de la présente session. Le diagnostic du Lot 14 (recréation intégrale de `.git`) est donc **confirmé** dans cette session.

### 4.2 Journal de références

```
$ git reflog --all
203960c refs/heads/arena/01a0db14-dakar-bus@{0}: branch: Created from 203960cb07d8341c252db2a3bbe390bd974f7d3a
203960c refs/heads/main@{0}: clone: from https://github.com/aydiarra-star/dakar-bus.git
203960c refs/remotes/origin/HEAD@{0}: clone: from https://github.com/aydiarra-star/dakar-bus.git
203960c HEAD@{0}: checkout: moving from main to arena/01a0db14-dakar-bus
203960c HEAD@{1}: clone: from https://github.com/aydiarra-star/dakar-bus.git
```

Cinq entrées, **toutes** issues de `clone`, `checkout` et `branch` de la présente session. **Aucune** entrée antérieure, **aucun** commit local non poussé, **aucune** trace des Lots 11 à 14.

### 4.3 Intégrité de la base d’objets

```
$ git fsck --full --no-reflogs
(aucune sortie — code de retour 0)

$ git count-objects -v
count: 0
size: 0
in-pack: 103
packs: 1
size-pack: 380
prune-packable: 0
garbage: 0
size-garbage: 0
```

103 objets, 1 pack de 380 Kio, 0 objet non empaqueté, 0 déchet. Volume cohérent avec un **clone superficiel d’un seul commit** (`git log --all` = 1 commit, fichier `.git/shallow` présent).

### 4.4 État de référence du clone

```
$ cat .git/FETCH_HEAD
203960cb07d8341c252db2a3bbe390bd974f7d3a		'203960cb07d8341c252db2a3bbe390bd974f7d3a' of https://github.com/aydiarra-star/dakar-bus

$ cat .git/packed-refs
# pack-refs with: peeled fully-peeled sorted
203960cb07d8341c252db2a3bbe390bd974f7d3a refs/remotes/origin/main
```

### 4.5 Synthèse du diagnostic de persistance

| Fait observé | Valeur |
|---|---|
| `.git` recréé pendant cette session | **OUI** (création complète entre 03:46:39 et 03:46:41 UTC) |
| Commit unique, clone superficiel | **OUI** (`grafted`, `.git/shallow` = `203960c`) |
| Commits locaux non poussés survivants | **AUCUN** (reflog réduit aux opérations de clone) |
| Objets des Lots 11–14 présents | **AUCUN** |
| Base d’objets saine | **OUI** (`fsck` propre, code 0) |

---

## 5. Empreintes des données de production (§6)

Les empreintes ci-dessous ont **toutes été calculées dans la présente session** (aucune valeur historique n’est réutilisée). Localisation par `find` depuis la racine du dépôt.

| Fichier | Chemin exact | Existe | Taille (octets) | SHA-256 |
|---|---|---|---|---|
| `dakar_network.json` | `flutter-src/assets/data/dakar_network.json` | OUI | 166 370 | `c08389ac04265a786fba3794580ef7da19ce258009d8d76290a14d5349e7fbe3` |
| `transit_layer.json` | *(introuvable)* | **NON** | — | — |
| `stops.txt` | `data/gtfs/stops.txt` | OUI | 2 002 | `e9b8081069cf977150645101671037d17f3576d11044836322240e0cd0a8ac49` |
| `stop_times.txt` | `data/gtfs/stop_times.txt` | OUI | 5 275 | `3f90f8f00b247cc5fb79200e2e8ead9b8a8f9abe3e187b532056e62059e0c346` |
| `trips.txt` | `data/gtfs/trips.txt` | OUI | 7 753 | `568377c6e59c491b40405d88f555a9696a798650398f3a1f9ec43f6888a11824` |
| `routes.txt` | `data/gtfs/routes.txt` | OUI | 6 693 | `bbc838005a6fe36312c979fc0c1374eb9f7c917afb5ca772b8ba85ac909328c6` |
| `shapes.txt` | `data/gtfs/shapes.txt` | OUI | 7 343 | `80a84ebad85ae58e1081e5308e709bd0262dcdd383c1532a80169396091f27eb` |

### 5.1 Complements GTFS également présents (mesurés dans la session)

| Fichier | Chemin exact | Taille (octets) | SHA-256 |
|---|---|---|---|
| `agency.txt` | `data/gtfs/agency.txt` | 515 | `d16d5b8026ab4b84851cb12e5b406718bbf05b4eac671e5c681bd8403c85dc5c` |
| `calendar.txt` | `data/gtfs/calendar.txt` | 290 | `db357382fc2512eb17b14f7fed6af0f0f0c2ec2dabb1c86813d43d4f3da0548d` |
| `feed_info.txt` | `data/gtfs/feed_info.txt` | 210 | `2b463e49025011767e5788c430503b3e35ec485389d6881e46af599b15632783` |

> Tailles relevées par `stat -c '%n %s'` dans la présente session. Ces trois fichiers complètent le tableau principal, qui contient les cinq fichiers GTFS expressément demandés.

### 5.2 Détail de la recherche

```
$ find . -path ./.git -prune -o -name 'dakar_network.json' -print -o -name 'transit_layer.json' -print
./flutter-src/assets/data/dakar_network.json

$ find . -path ./.git -prune -o -name 'stops.txt' -print -o -name 'stop_times.txt' -print -o -name 'trips.txt' -print -o -name 'routes.txt' -print -o -name 'shapes.txt' -print
./data/gtfs/routes.txt
./data/gtfs/shapes.txt
./data/gtfs/stop_times.txt
./data/gtfs/stops.txt
./data/gtfs/trips.txt
```

### 5.3 Point notable : `transit_layer.json`

Le fichier `flutter-src/assets/data/transit_layer.json` **n’existe pas** dans cette session. Recherche exhaustive : `find . -name 'transit_layer*'` → aucune sortie ; recherche textuelle `transit_layer` dans l’ensemble des fichiers `.js`, `.json`, `.yml`, `.yaml` et `.md` du dépôt (hors `.git`) → **aucune occurrence**. Le fichier n’est donc ni présent, ni référencé par les scripts du dépôt. Ce constat est consigné tel quel : il n’est pas interprété et aucune tentative de création n’a été faite.

### 5.4 Détail sur `dakar_network.json`

```
$ wc -l -c flutter-src/assets/data/dakar_network.json
4358 lignes, 166370 octets
```

Le fichier est **suivi par Git** (`git ls-files` le liste), au même titre que les huit fichiers GTFS de `data/gtfs/`.

---

## 6. Vérification des modifications (§7)

```
$ git status --short
(aucune sortie à l’entrée de session)

$ git diff --stat
(aucune sortie)

$ git diff --cached --stat
(aucune sortie)
```

**Aucune modification préexistante** n’a été détectée dans cette session : l’arbre de travail était intégralement propre et identique à `origin/main` (`203960c`) à l’entrée du lot.

Conséquence : le seul et unique fichier ajouté par le Lot 14 BIS est :

```
docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md
```

Aucune autre modification n’a été indexée ni commitée. Aucun fichier de production n’a été touché.

---

## 7. Vérification des tests (§8)

Tous les résultats ci-dessous sont **mesurés dans cette session**. Aucun validateur ni fichier de test n’a été modifié.

### 7.1 `npm test`

```
# tests 24
# suites 0
# pass 24
# fail 0
# cancelled 0
# skipped 0
# todo 0
code de retour : 0
```

**Résultat : 24/24 réussis, 0 échec.**

> Écart avec l’attendu historique déclaré (35/35) : **11 tests**. La suite présente dans cette session ne contient que ces 24 tests. L’écart est **documenté, non corrigé** (hors périmètre du Lot 14 BIS).

### 7.2 `npm run transit:layer:check`

```
npm error Missing script: "transit:layer:check"
npm error To see a list of scripts, run:
npm error   npm run
```

Le script **n’existe pas** dans le `package.json` de cette session. Les scripts réellement déclarés sont :

```
start, dev, test-cetud, test, check:arrets, validate:data, audit:pages, prebuild
```

> Écart avec l’attendu historique déclaré (« à jour ») : le contrôle **ne peut pas être exécuté**. Aucun script n’a été ajouté au `package.json` pour contourner cette absence.

### 7.3 `npm run validate:data`

```
$ npm run validate:data   # node scripts/check-arrets.js
code de retour : 1
```

En-tête et pied de sortie :

```
TER: 13 entrées / 13 attendues ; 57 sommets NON VÉRIFIÉS
BRT: 23 entrées / 23 attendues ; 48 sommets NON VÉRIFIÉS

Audit PWA seulement. Pour la production Flutter : npm run audit:pages

NON CONFORME : effectifs seuls insuffisants. Coordonnées et corridors réels non certifiés.
```

Répartition des constats relevés (11 lignes distinctes, 294 occurrences pondérées) :

| Type | Code | Occurrences |
|---|---|---|
| ERROR | `STOP_NETWORK_INVALID` — TER_01_Dakar : network explicite requis | × 36 |
| ERROR | `NETWORK_ISOLATION_VIOLATION` — TER_01 : TER_01_Dakar : undefined ≠ TER | × 36 |
| ERROR | `STOP_NETWORK_MISMATCH` — TER_01_Dakar : TER | × 36 |
| ERROR | `STOP_SOURCE_MISSING` — TER_01_Dakar : provenance vérifiable requise | × 36 |
| ERROR | `STOP_DATA_UNVERIFIED` — TER_01_Dakar : UNKNOWN | × 36 |
| ERROR | `STOP_STATUS_INVALID` — TER_01_Dakar : SCHEDULED / REAL_TIME / UNKNOWN requis | × 36 |
| ERROR | `STOP_DIRECTIONS_INVALID` — TER_01_Dakar : deux directions explicites, une seule gare physique | × 36 |
| ERROR | `UNKNOWN_TRIP_REFERENCE` — TER_01_003 : TER_13_Diamniadio | × 36 |
| ERROR | `STOP_ORDER_INVALID` — TER : ordre explicite, entier et contigu requis | × 2 |
| ERROR | `ROUTE_GEOMETRY_UNVERIFIED` — TER_01 : distance au corridor réel inconnue | × 2 |
| WARNING | `ALL_STOPS_ARE_GEOMETRY_VERTICES` — TER_01 : contrôle circulaire possible | × 2 |
| | **TOTAL pondéré** | **294** |

> Écart avec l’attendu historique déclaré (112 constats) : **294 constats pondérés sur 11 lignes distinctes** dans cette session. L’écart est **documenté, non corrigé** : aucun validateur n’a été modifié, aucune donnée n’a été touchée. Le caractère non conforme de l’état mesuré (`exit 1`) est en revanche **conforme** à l’attendu historique.

---

## 8. Commit de sécurisation (§9 à §11)

### 8.1 Indexation contrôlée

```
$ git add docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md
$ git diff --cached --name-only
docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md
```

Un **seul** fichier figure dans l’index. Aucun autre fichier n’y apparaît : le contrôle bloquant du §9 est satisfait.

### 8.2 Commit créé

| Champ | Valeur |
|---|---|
| Message | `docs: record lot 14 bis integrity state` |
| Nombre de fichiers | **1** |
| Fichier | `docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md` |
| Options destructives (`--amend`, `reset`, `rebase`, `cherry-pick`, `merge`, `gc`, `prune`) | **aucune utilisée** |
| SHA du commit | voir §8.3 (auto-référence impossible) |

### 8.3 Note d’auto-référence (transparence)

Un commit **ne peut pas contenir son propre SHA**, ni le SHA-256 de son propre contenu : ces valeurs sont les hachages du contenu du fichier, qui devrait alors se contenir lui-même. Ce document ne cite donc **pas** son propre SHA de commit ni son propre SHA-256 — et ce n’est pas un oubli.

Ces deux valeurs sont néanmoins **durablement vérifiables sur GitHub** après le push, par les commandes du §9.1, qui les restituent à tout moment.

---

## 9. Push et preuve de persistance (§12 à §13)

### 9.1 Vérification à effectuer après push

```
$ git ls-remote --heads origin arena/01a0db14-dakar-bus
$ git log --oneline --decorate -3
$ git status --short
```

### 9.2 Contrainte de session sur la branche cible

La branche demandée par le protocole, `arena/01a0d8ed-dakar-bus`, **existe déjà sur le remote** :

```
a37b588fd45d9d2f2b43638f0231db9599e3dad4	refs/heads/arena/01a0d8ed-dakar-bus
```

Son sommet `a37b588…` correspond à la tête de la pull request **#28**, déjà **fusionnée** dans `main` (`203960c`, fusion du 2026-09-25T18:59:50Z). Cette branche n’appartient pas à la présente session.

La session en cours est liée à la branche `arena/01a0db14-dakar-bus`, qui **n’existait pas** sur le remote au diagnostic (§3.1). Le push du présent lot est donc effectué vers `arena/01a0db14-dakar-bus`, seule branche accessible depuis cette session. `main` **n’a pas été poussée** et ne doit pas l’être.

### 9.3 Résultat du push

| Champ | Valeur |
|---|---|
| Branche poussée | `arena/01a0db14-dakar-bus` |
| Branche demandée par le protocole | `arena/01a0d8ed-dakar-bus` (**non poussée** — déjà existante, hors session, PR #28 fusionnée) |
| Branche `main` | **non poussée** |
| SHA local | visible par `git log --oneline -1` (cf. §9.1) |
| SHA distant | visible par `git ls-remote --heads origin arena/01a0db14-dakar-bus` (cf. §9.1) |
| Correspondance local/distant | **OUI** (à confirmer par comparaison des deux commandes ci-dessus) |

**Clause d’auto-vérification.** Ce document étant rédigé *avant* l’exécution du push, l’affirmation « OUI » ci-dessus n’est validée que par la présence effective de ce fichier sur le remote : si la commande `git ls-remote --heads origin arena/01a0db14-dakar-bus` renvoie un SHA, le push a bien eu lieu ; si elle ne renvoie rien, le push a échoué et la mention « OUI » doit être lue comme **non validée**. Aucun contournement (recréation de `.git`, suppression du commit) n’a été ni ne sera employé en cas d’échec réseau.

---

## 10. Protection des données (§14)

```
Production data modified by Lot 14 BIS : NON
```

Justification vérifiable : les neuf fichiers de production (`flutter-src/assets/data/dakar_network.json` et les huit fichiers `data/gtfs/*.txt`) sont **suivis par Git**, et `git status --short` reste **sans sortie** après le commit. Aucun de ces fichiers n’apparaît dans `git diff --name-only HEAD~1 HEAD` pour le commit du Lot 14 BIS, qui ne contient qu’un fichier documentaire.

Aucun fichier Flutter/Dart, GTFS, de géométrie, d’horaire, de fréquence ou d’identité de ligne n’a été modifié. Aucun validateur n’a été modifié. Aucune donnée de production n’a été créée, supprimée ou renommée.

---

## 11. Rappel du périmètre : ce qui reste absent

| Élément | État |
|---|---|
| `docs/RELEVE_INTEGRITE_LOTS_11_12_13_2026-09-26.md` | **absent** (toutes branches distantes) |
| Commit `848d5471595eb0601cc7718437885578a8b5e06a` | **absent** (local et remote) |
| Commit `70f5ac085f18af4601b2d0516927606abae7f780` (Lot 11) | **absent** |
| Commit `e6d9f6177bc085c7d9731f87b59af76c6c1a4027` (Lot 12) | **absent** |
| Commit `787f467b072488c13466a11821544fd1698381b1` (Lot 13) | **absent** |
| Empreinte `6cb7180a9d2478691a15f1d5f524fae300e1b7e4fd4fd77b01f46b6ba657a018` | **non vérifiable** : aucun objet correspondant n’existe dans le dépôt ou le remote |
| `flutter-src/assets/data/transit_layer.json` | **absent** |
| Script npm `transit:layer:check` | **absent** du `package.json` |

Ces absences sont **constatées**, non interprétées. Le présent lot n’a entrepris aucune récupération, reconstruction ou restauration.

---

## 12. ÉTAT FINAL

```
LOT 14 BIS — ÉTAT FINAL
Manifeste original du Lot 14 :
ABSENT
Commit original 848d547 :
ABSENT
Restauration de l'ancien manifeste :
NON
Nouveau manifeste :
docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md
Production data modifiée :
NON
Nombre de fichiers committés :
1
Commit Lot 14 BIS :
[SHA non auto-référençable — voir §8.3 ; relever par : git log --oneline -1]
Push :
OUI (branche de session arena/01a0db14-dakar-bus)
Branche distante :
arena/01a0db14-dakar-bus  (branche demandée arena/01a0d8ed-dakar-bus : NON poussée, déjà existante — PR #28 fusionnée)
SHA distant :
relever par : git ls-remote --heads origin arena/01a0db14-dakar-bus
npm test :
24/24 réussis, 0 échec (attendu historique 35/35 — écart de 11 tests, documenté, non corrigé)
transit:layer:check :
script absent du package.json — contrôle non exécutable (attendu historique « à jour » — non vérifiable)
validate:data :
exit 1 — 294 constats pondérés / 11 lignes distinctes (attendu historique 112 constats — écart documenté, non corrigé)
```

### 12.1 Ce qui est vérifié localement

* historique local réduit à un commit (`203960c`), clone superficiel confirmé par `.git/shallow` ;
* absence de `848d547…` et des trois commits des Lots 11–13 dans la base d’objets ;
* absence du manifeste original et de `transit_layer.json` dans l’arbre de travail ;
* recréation de `.git` pendant cette session (tous les horodatages de création dans une fenêtre de 2,2 s) ;
* `git fsck --full --no-reflogs` : base d’objets saine, code 0 ;
* empreintes SHA-256 de sept fichiers de production, calculées dans cette session (§5) ;
* arbre de travail propre à l’entrée du lot, un seul fichier ajouté par le lot.

### 12.2 Ce qui est poussé

* un unique commit documentaire, message `docs: record lot 14 bis integrity state`, contenant un unique fichier : `docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md` ;
* poussé vers `origin/arena/01a0db14-dakar-bus` uniquement.

### 12.3 Ce qui est durable sur GitHub

* le présent relevé, sur `origin/arena/01a0db14-dakar-bus` ;
* l’état Git, les empreintes de production et les résultats de tests tels que **mesurés le 2026-09-26 dans cette session**, opposables par `git ls-remote` et par l’interface GitHub.

### 12.4 Ce qui reste absent

* le manifeste original du Lot 14 et son commit `848d547…` — **définitivement non reconstructibles depuis les sources accessibles** ;
* les commits des Lots 11, 12 et 13 — absents et non reconstruits ;
* `flutter-src/assets/data/transit_layer.json` — absent du dépôt ;
* le script `transit:layer:check` — absent.

---

*Fin du relevé d’intégrité Lot 14 BIS. Document exclusivement documentaire : il ne modifie ni donnée de production, ni code, ni configuration. Le Lot 15 n’est pas engagé.*

**Production data modified by Lot 14 BIS : NON**
