# DAKAR BUS TRANSIT DATA LAYER — Lot 4.4

- **Lot** : 4.4
- **Date** : 2026-09-27
- **Livrable** : couche de données de travail sous `data/transit/`
- **Nature** : **référentiel de travail interne — PAS une publication GTFS destinée à l'usager**
- **Code applicatif modifié** : **aucun** (§14)
- **Tests** : **52/52** (`npm test`) — 24 tests applicatifs existants inchangés + 28 tests de données ajoutés
- **Lots précédents** : 4.2B (`PASSBI_HISTORICAL_ONLY`), 4.3 (`PARTIALLY_CONFIRMED`) — inchangés

---

## 1. Architecture

### 1.1 Les trois niveaux

Le lot exige trois niveaux distincts, non mélangés. Ils sont matérialisés par **trois dossiers physiquement séparés**, pas par des champs dans un même fichier.

| Niveau | Dossier | Contenu | Alimente l'usager ? |
|---|---|---|---|
| **1 — RAW / HISTORICAL** | `data/transit/passbi/` | données PassBi telles quelles, identifiants d'origine | **non** |
| **2 — VALIDATED REFERENCE** | `data/transit/validated/` | éléments confirmés par des sources actuelles | **non, sauf liste du §12** |
| **3 — PRODUCTION READY** | `data/transit/production/` | ce qui est documenté pour l'expérience usager | **oui, 4 entités** |

Un élément ne monte de niveau que sur preuve. Aucun raccourci n'existe dans le générateur.

### 1.2 Les quatre dimensions indépendantes

```
IDENTITE    Qui est cette ligne ?
STRUCTURE   Quels sont ses arrets, son parcours, ses directions ?
HORAIRE     Quand passe-t-elle ?
TEMPS REEL  Ou est-elle maintenant ?
```

Chaque route porte les quatre statuts dans `validated/route_status.json` (130 lignes). **Aucune dimension n'est déduite d'une autre** — vérifié par test : aucune route dont la structure est `CONFIRMED` ou `PERSISTENT` n'a d'horaire `CONFIRMED`.

L'exemple du lot se retrouve tel quel :

```
TER   identity = CONFIRMED             structure = CONFIRMED
      schedule = PARTIALLY_CONFIRMED   realtime  = UNKNOWN
```

### 1.3 Ce qui n'a pas été touché

`data/gtfs/` (feed synthétique `2.1-dakar-pwa-gtfs-rt`, 76 routes, 42 arrêts) est **intact** — `git diff HEAD -- data/gtfs/` est vide. `data/transit/reference-policy.json` (2026-09-21) est **intact**. Les deux couches ne sont pas mélangées : le LEVEL 2 ne reprend aucune référence au `feed_version` synthétique.

---

## 2. Sources

| Réf. | Source | `source_type` | Datation | Usage |
|---|---|---|---|---|
| **S1** | `terdakar.sn/les_horaires_des_trains/` | `OFFICIAL_OPERATOR` | consulté 2026-09-27, actualités jusqu'au 30/03/2026 | fréquences et amplitudes TER |
| **S2** | `demdikk.sn/info-voyageurs/` | `OFFICIAL_OPERATOR` | complétée par actu `demdikk.sn` du 02/09/2026 | liste officielle des lignes DDD |
| **S3** | `sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/` | `OFFICIAL_OPERATOR` | offre de service « actuelle » | B1/B2, fréquence 6 min, renfort de pointe |
| **S4** | `sunubrt.sn/brt-3-semi-express/` | `OFFICIAL_OPERATOR` | via `dakar_network.json`, vérifié 2026-09-24 | identité de la B3 |
| **S5** | `senego.com/services/horaires-brt-ter` | `INSTITUTIONAL` | 2026-07-27 | 13 gares TER numérotées et kilométrées |
| **S6** | `ter-senegal.sn/gares/` | secondaire daté | 2026-05-14 | gares TER desservies |
| **S7** | PassBi — `impactsolutionsas/passbi_core` | **`PASSBI`** | dépôt 2026-02-10 ; feeds 2022→2025 | structure historique |
| **S8** | `dakar_network.json` | interne déjà audité | `audited_at: 2026-09-24` | identifiants publics, B3 |

**Hiérarchie** : opérateur > source secondaire datée > PassBi. Une source secondaire ne suffit jamais seule à établir une persistance.

**`PASSBI` n'est jamais promu `OFFICIAL_OPERATOR`.** PassBi revendique l'usage de données CETUD ; le lot 4.2 a réfuté cette revendication (`cetud.sn` ne publie ni GTFS ni API, et le mot « CETUD » apparaît **0 fois** dans les 1 251 fichiers du dépôt). Un test vérifie qu'aucun bloc de provenance ne promeut PassBi.

---

## 3. Provenance

### 3.1 Modèle

`data/transit/schema/provenance.schema.json` — JSON Schema draft-07. Il reste **extérieur** aux fichiers `.txt` GTFS, qui conservent une syntaxe strictement standard. Chaque entité importante porte :

```
source · source_type · source_url · date_source · date_verified
valid_from · valid_to · confidence · status · verification_note
```

`source_type` ∈ `OFFICIAL_OPERATOR` · `INSTITUTIONAL` · `PASSBI` · `OSM` · `HYBRID`

### 3.2 Provenance par champ

Quand plusieurs sources alimentent une entité, la provenance est portée **au niveau du champ**. Pour les gares TER (`ter_stop_mapping.json` → `provenance_by_field`) :

| Champ | Source | `source_type` |
|---|---|---|
| `stop_name` | PassBi (flux SETER) + senego.com + ter-senegal.sn | `HYBRID` |
| `coordinates` | PassBi (flux SETER), recoupées avec `dakar_network.json` | `PASSBI` |
| `sequence` | PassBi (flux SETER) + numérotation 1→13 de senego.com | `HYBRID` |

Jamais réduit à `source = PassBi`. Un test impose que `stop_name` ne soit **pas** typé `PASSBI`, précisément parce que trois sources actuelles le corroborent.

---

## 4. TER

### 4.1 Les 13 gares — `CONFIRMED`

`validated/structure/ter_stop_mapping.json`.

| # | Gare | `passbi_stop_id` (préfixe) | `dakar_bus_stop_id` | Écart |
|---|---|---|---|---|
| 1 | Dakar - Gare ferroviaire | `544a27a5` | `stop_dakar_ter` | 54 m |
| 2 | Colobane | `c70477e7` | `stop_colobane` | 221 m |
| 3 | Hann | `f405b86e` | `stop_hann` | 64 m |
| 4 | Dalifort | `61d82f6f` | `stop_dalifort_ter` | 69 m |
| 5 | Baux Maraîchers | `d802c3ec` | `stop_baux_maraichers` | 172 m |
| 6 | Pikine | `650b288f` | `stop_pikine` | 114 m |
| 7 | Thiaroye | `956bedfd` | `stop_thiaroye` | 74 m |
| 8 | Yeumbeul | `f8ec6c04` | `stop_yeumbeul` | 68 m |
| 9 | Keur Mbaye Fall | `41016cdb` | `stop_keur_mbaye_fall` | 9 m |
| 10 | PNR Rufisque | `90110d84` | `stop_pnr` | 64 m |
| 11 | Rufisque | `1d859f92` | `stop_rufisque` | 59 m |
| 12 | Bargny | `d30b03f2` | `stop_bargny` | 74 m |
| 13 | Diamniadio | `4445e51b` | `stop_diamniadio` | 68 m |

Les 13 UUID complets sont conservés intacts dans le fichier. **Contrôle de coordonnées** : 13/13 appariées, chacune à un arrêt **distinct**, au **même rang de séquence**. Écart moyen **85 m**, maximum 221 m, minimum 9 m. Aucun appariement croisé.

### 4.2 Décision de modélisation des identifiants

Le lot laissait le choix. **Décision prise** : l'identifiant public est celui déjà utilisé par `dakar_network.json`. L'UUID PassBi reste disponible comme identifiant historique dans `passbi_stop_id` et dans le crosswalk.

Justification : les UUID PassBi sont des identifiants de **tiers**, non stables d'un feed à l'autre ; les exposer créerait une dépendance à un dépôt dont la pérennité n'est pas établie. Un test interdit qu'un UUID PassBi apparaisse comme `stop_id` public.

### 4.3 Stations non ajoutées

| Station | Statut | Raison |
|---|---|---|
| **AIBD** | `PROVISIONAL` | mise en service annoncée au 28/09/2026, non confirmée par l'opérateur à la date d'audit |
| **Sébikotane** | `UNKNOWN` | aucune source actuelle trouvée |
| **Keur Moussa** | `UNKNOWN` | **commune traversée** (EESS BAD 2016), jamais documentée comme gare |

Aucune n'entre dans le référentiel. Un test vérifie leur absence.

---

## 5. BRT

### 5.1 Trois routes distinctes

| Route | Identité | Structure | Horaire | Stations PassBi | Stations actuelles |
|---|---|---|---|---|---|
| **B1** | `CONFIRMED` | `PERSISTENT` | `UNCONFIRMED` | 21 | 23 |
| **B2** | `CONFIRMED` | `CONFIRMED` | `UNCONFIRMED` | 7 | 7 |
| **B3** | `NEW` | `UNCONFIRMED` | `UNKNOWN` | absente | 7 nommées |

**B1 et B2 ne sont pas fusionnés.** Leurs 7 stations communes portent le même identifiant physique, mais les deux `route_id` restent distincts.

### 5.2 Anti-double-affichage

Le modèle porte `route_id` · `trip_id` · `direction_id` · `stop_sequence` · `shape_id`.

```
1 station physique  +  N routes  =  N stop_times
```

Les 7 stations partagées par B1 et B2 portent **le même** `dakar_bus_stop_id`. Aucune copie suffixée par ligne n'est créée. Deux tests le vérifient : unicité des stations physiques, et absence de doublon dans chaque séquence de ligne.

### 5.3 B3 — identité seule

Construite **uniquement** à partir de S4, relayé par `dakar_network.json` (`services_not_exposed.brt_b3`, vérifié 2026-09-24) : 7 stations nommées.

**Aucun `stop_id` ni coordonnée ne lui est attribué.** Elle est **exclue du GTFS**. Son parcours n'est **pas** reconstruit par proximité géographique.

Fait consigné sans être exploité : le `stops.txt` PassBi contient `GUEULE TAPEE` (`1:GTA`), non desservie par B1 ni B2, et « Gueule Tapée » figure parmi les stations officielles de la B3. Ce rapprochement est `NAME_ONLY`, confiance `LOW`, et **n'est pas utilisé** pour construire la ligne.

### 5.4 Doublons non fusionnés

22 stations PassBi sont desservies. 21 se résolvent sur des arrêts distincts du projet. La 22ᵉ (`POLE GRAND MEDINE`, desservie par la variante de pointe) se résout sur le même arrêt que `GRAND MEDINE`.

**Elle n'est pas fusionnée** : proximité 90 m, aucune preuve opérateur. Elle reste dans `unmerged_passbi_duplicates`, statut `UNCONFIRMED`, `merged: false`.

6 autres stations PassBi ne sont desservies par aucune course (GADAYE, FITH MITH, GUEULE TAPEE et 3 doublons de pôles d'échange) — signalées, non fusionnées.

---

## 6. DDD

### 6.1 Les 34 lignes persistantes

`validated/structure/ddd_routes.json`. Base d'appariement : **numéro + terminus** — le code PassBi `D501GP` encode **G**are de Dakar ↔ **P**alais 2, que S2 publie littéralement.

Chaque ligne porte : `route_id` · `route_short_name` · `route_long_name` · `operator` · `origin` · `destination` · `source` · `source_type` · `date_verified` · `status` · `confidence`.

**Statuts imposés par le lot, appliqués littéralement :**

```
IDENTITY  = PERSISTENT      (numero + terminus retrouves chez l'operateur)
STRUCTURE = UNKNOWN         (le parcours complet n'est pas prouve)
SCHEDULE  = UNKNOWN         (aucune source horaire actuelle)
REALTIME  = UNKNOWN
```

`D1LP` `D2DL` `D4DL` `D5GP` `D6CP` `D7OP` `D8PL` `D9P0` `D10LP` `D11KL` `D12GP` `D13T0` `D15PR` `D16MP` `D18D` `D20D` `D23P2` `D121LS` `D208BR` `D213DR` `D217OT` `D218AT` `D219DO` `D220DR` `D221AG` `D227TM` `D228RY` `D232AB` `D233 M` `D234JL` `D501GP` `D502CU` `D503CB` `D504DS`

Les 4 dessertes de gares TER (`D501`–`D504`) persistent toutes.

### 6.2 Les 19 lignes non retrouvées

`D102CC` `D103AC` `D105CP` `D111LY` `D210TM` `D223DP` `D231BJ` `D301MP` `D305PY` `D308OP` `D311TT` `D315RY` `D319SL` `D323PT` `D401AO` `D402AT` `D403AP` `D404AL` `D405AD`

```
IDENTITY_STATUS = UNCONFIRMED
STATUS          = NOT_FOUND
note            = « Absente des sources verifiees, mais absence insuffisante
                   pour conclure a une suppression. »
```

**Aucune supprimée. Aucun statut `DISCONTINUED`.** Un test vérifie les **valeurs** des cinq champs de statut (pas le texte du fichier) contre une liste de statuts de suppression interdits, et vérifie que les 19 figurent toujours dans `route_status.json`.

### 6.3 Arrêts non inventés

| | Emplacement | Contenu |
|---|---|---|
| `historical_stops` | `passbi/ddd/stops.txt` (LEVEL 1) | **1 277** arrêts PassBi |
| `current_verified_stops` | `ddd_routes.json` | **`[]` — vide** |

Les arrêts PassBi ne sont **pas** importés comme arrêts actuels. Ils servent de crosswalk futur. Un test vérifie que le GTFS validé ne contient **que** les 13 gares TER.

---

## 7. AFTU

`validated/structure/aftu_raw_registry.json` — **référentiel brut uniquement**.

73 entrées portant `passbi_route_id` · `passbi_short_name` · `passbi_long_name` · `origin` · `destination` · `stops` · `source` · `source_date`, toutes en `identity_status = UNCONFIRMED`.

**Aucune identité importée.** Rappel de la preuve du lot 4.3 :

```
PassBi     : 1, 2, 3, 4, 5, puis 24 -> 91     (73 codes)
Dakar Bus  : 1 -> 72 en continu               (72 lignes)

numeros PassBi absents de 1..72 : 6 ... 23    (18 numeros)
numeros 1..72 absents de PassBi : 73 ... 91   (19 numeros)
```

`PASSBI A30 ≠ DAKAR BUS ligne 30`. Un test vérifie que les 73 lignes portent une entrée de crosswalk, toutes en `UNCONFIRMED` avec `target_id = null`.

Piste consignée pour un lot dédié : les codes PassBi (`A1HL`, `A24NU`, `A91AD`) semblent encoder les terminus en suffixe. **Ce n'est pas une correspondance établie.**

---

## 8. Crosswalk

`data/transit/crosswalk/crosswalk.json` — **186 entrées**.

```
crosswalk_id · source · source_id · target · target_id
match_type · evidence · confidence · verified_at · note
```

| `match_type` | Nombre | Sens |
|---|---|---|
| `DOCUMENTED` | **87** | preuve documentée (nom + terminus + coordonnées + source actuelle) |
| `NAME_ONLY` | **1** | Gueule Tapée ↔ B3, confiance LOW, non exploité |
| `UNCONFIRMED` | **98** | 73 AFTU + 19 DDD NOT_FOUND + 6 stations BRT non desservies |
| `EXACT` | 0 | aucun identifiant commun aux deux systèmes |
| `STRUCTURAL` | 0 | non nécessaire : le DOCUMENTED suffit |
| `COORDINATE_ONLY` | 0 | **refusé par politique** |

Par confiance : **HIGH 77** · MEDIUM 9 · **LOW 100**.

**Politique appliquée :**

```
COORDINATE_ONLY  ne suffit pas pour identifier une ligne
NAME_ONLY        ne suffit pas pour identifier une ligne
NUMBER_ONLY      ne suffit JAMAIS
```

Aucune entrée `COORDINATE_ONLY` n'existe. L'unique `NAME_ONLY` porte une confiance `LOW` (vérifié par test) et n'alimente aucune construction.

---

## 9. Statuts

### 9.1 Vocabulaire

`CONFIRMED` · `PERSISTENT` · `PARTIALLY_CONFIRMED` · `UNCONFIRMED` · `CONTRADICTED` · `NEW` · `UNKNOWN`, plus **`NOT_FOUND`** pour l'absence d'identité (section 9 du lot) — qui ne signifie jamais « supprimée ».

### 9.2 Répartition sur les 130 routes

| Dimension | CONFIRMED | PERSISTENT | PARTIALLY_CONFIRMED | UNCONFIRMED | NEW | UNKNOWN |
|---|---|---|---|---|---|---|
| **identité** | 3 | 34 | — | 92 | 1 | — |
| **structure** | 2 | 1 | — | 1 | — | 126 |
| **horaire** | — | — | 1 | 2 | — | 127 |
| **temps réel** | — | — | — | — | — | **130** |

Lecture : **l'identité est bien mieux établie que la structure, qui est bien mieux établie que l'horaire.** Cette gradation n'est pas déduite : chaque case provient d'une preuve distincte.

### 9.3 `CONTRADICTED`

Aucune route n'est `CONTRADICTED` au niveau structurel. La contradiction porte sur un **horaire** : la grille TER semaine (12 min PassBi vs 10 min opérateur). Elle est consignée dans `ter_schedule.json` et **exclue du LEVEL 2**.

---

## 10. Horaires

### 10.1 Deux niveaux séparés

`validated/structure/ter_schedule.json` distingue explicitement :

| | `historical_passbi_schedule` | `current_operator_schedule` |
|---|---|---|
| Emplacement | `passbi/ter/` (LEVEL 1) | S1 terdakar.sn |
| Semaine | 12 min, 05:30 → 22:06, 81 départs — **`CONTRADICTED`** | **10 min**, **05:45** → 22:05 — `CONFIRMED` |
| Dimanche | 20 min, 06:25 → 22:05, 50 départs | 20 min, 06:25 → 22:05 — `CONFIRMED` |
| Heures par station | présentes, non validées | **non publiées** |
| Statut résultant | — | **`ESTIMATED`** |

### 10.2 Semaine — non importée

La grille PassBi semaine **n'est pas** importée comme horaire actuel. Elle reste en LEVEL 1, marquée `CONTRADICTED`, avec la valeur opérateur actuelle consignée à côté.

### 10.3 Dimanche — `PARTIALLY_CONFIRMED`

Réconciliation exhaustive :

```
serie officielle actuelle (06:25 + 20 min -> 22:05)  : 48 departs
serie PassBi (service db5eb1cc, ligne 10001)         : 50 departs
PassBi retrouves dans l'officiel                     : 48/50
officiels absents de PassBi                          : 0
PassBi hors serie officielle                         : 18:03, 19:50
```

**Les 48 départs concordants sont promus en LEVEL 2** (48 trips, 624 `stop_times`) avec `schedule_status = PARTIALLY_CONFIRMED`. **Les 2 départs PassBi excédentaires sont exclus** du LEVEL 2 et restent en LEVEL 1.

**Statut par champ :**

```
origin_departure_time     = PARTIALLY_CONFIRMED
intermediate_stop_times   = UNCONFIRMED
```

### 10.4 Garde-fou de calendrier

Aucune période de validité opérateur n'est publiée. La fenêtre GTFS est donc **volontairement réduite à la seule date d'audit** (`start_date = end_date = 20260927`). C'est un garde-fou : le feed ne peut pas être confondu avec un calendrier annuel exploitable. Un test impose `start_date == end_date`.

### 10.5 Vice structurel consigné

Le flag `timepoint` **existe** dans le feed PassBi (colonne présente, vérifiée) mais est **détruit à l'import** par PassBi : aucune colonne `timepoint` dans son schéma ni dans ses 9 migrations (lot 4.2B). La distinction heure exacte / heure approximative **n'est donc pas fiable en aval**, indépendamment de la fraîcheur des données.

### 10.6 Heures supérieures ou égales à 24h

Convention GTFS conservée : les heures `25:xx`, `26:xx` sont écrites telles quelles et **jamais** converties en heure civile du jour suivant. `times_rewritten = 0`. Un test vérifie le format de chaque heure, l'absence de réécriture, et que les 48 départs du LEVEL 2 correspondent **caractère pour caractère** à la série confirmée.

---

## 11. GTFS structurel

`data/transit/validated/gtfs/` — 7 fichiers, syntaxe GTFS standard.

| Fichier | Lignes | Contenu |
|---|---|---|
| `agency.txt` | 1 | SETER |
| `routes.txt` | 1 | `ter_dakar_diamniadio` |
| `stops.txt` | 13 | les 13 gares confirmées |
| `trips.txt` | 48 | les 48 courses dominicales confirmées |
| `stop_times.txt` | 624 | 48 × 13, `timepoint` préservé |
| `calendar.txt` | 1 | `TER_SUNDAY_AUDIT`, fenêtre réduite à la date d'audit |
| `calendar_dates.txt` | 0 | en-tête seul — aucune exception validée |
| `shapes.txt` | **absent** | aucune géométrie validée actuellement |

**Ce qui est volontairement absent du GTFS** : les 3 routes BRT (structure documentée en JSON, aucun horaire), les 34 routes DDD (identité seule, structure `UNKNOWN`), les 73 routes AFTU (identité non établie), la grille TER semaine (`CONTRADICTED`).

**Rappel du lot, appliqué** : la validation syntaxique ne vaut pas validation métier. Ces 7 fichiers sont syntaxiquement valides **et** leur contenu est intégralement justifié — les deux sont vérifiés séparément, par des tests distincts.

---

## 12. Données prêtes pour production

`data/transit/production/production_ready.json` — **4 entités prêtes**.

| # | Entité | Statut | Utilisable pour | Jamais pour |
|---|---|---|---|---|
| 1 | **TER — 13 gares** (identité, ordre, coordonnées) | `CONFIRMED` | liste des gares, plan de ligne, distances, correspondances | horaires certifiés, temps réel |
| 2 | **BRT B2 — 7 stations et leur ordre** | `CONFIRMED` | liste des stations, ordre de desserte | horaires |
| 3 | **BRT B1 — identité et ses 21 stations** | `PERSISTENT` | structure de la ligne | horaires, liste exhaustive des 23 stations actuelles |
| 4 | **Fréquences opérateur** (TER 10 min semaine / 20 min dimanche ; BRT 6 min) | `CONFIRMED` | mention d'une fréquence, amplitude de service, information voyageur non horodatée | `SCHEDULED`, heure exacte par station, prochain départ calculé, `REAL_TIME` |

Aucune de ces quatre n'inclut d'heure exacte par station.

---

## 13. Données non prêtes

**7 catégories non prêtes.**

| # | Entité | Statut | Raison |
|---|---|---|---|
| 1 | Horaires TER **semaine** | `CONTRADICTED` | 12 min PassBi vs 10 min opérateur ; premier départ 05:30 vs 05:45 |
| 2 | Horaires TER dimanche (heures intermédiaires) | `PARTIALLY_CONFIRMED` | départs de Dakar confirmés 48/48 ; heures par station intermédiaire non validées |
| 3 | Horaires **BRT / DDD / AFTU** | `UNCONFIRMED` | aucune source horaire actuelle pour ces trois réseaux |
| 4 | Structure des **34 lignes DDD** | `UNKNOWN` | identité confirmée, parcours et arrêts non validés |
| 5 | Identités **AFTU** (73 lignes) | `UNCONFIRMED` | numérotation incompatible avec celle du projet |
| 6 | **Temps réel**, tous réseaux | `UNKNOWN` | aucun flux GTFS-RT ou SAE actif identifié |
| 7 | **Republication externe** des données PassBi | **`BLOCKED`** | aucune licence sur les données |

### 13.1 Limitations transverses

1. **Licence.** Le dépôt PassBi annonce MIT mais ne contient aucun fichier `LICENSE`, et aucune licence ne couvre les **données**. Blocage de republication, indépendant de la qualité.
2. **`timepoint` détruit à l'import.** Vice structurel de PassBi : la distinction exact/approximatif est perdue, quel que soit le feed.
3. **Aucune géométrie validée.** Les 19 783 points de `shapes` PassBi (BRT 6 785, DDD 3 500, AFTU 9 498) restent en LEVEL 1.
4. **Fenêtre de validité inconnue.** Aucun opérateur ne publie de période de validité ; la fenêtre GTFS est un garde-fou, pas une validation.
5. **Volume exclu de Git.** `stop_times`, `trips`, `shapes` et `fare_rules` (44 Mo en AFTU) ne sont pas versionnés. Ils restent re-téléchargeables via les `git_blob` du `MANIFEST.json`.

---

## 14. Aucun changement applicatif

Contrôles exécutés le 2026-09-27 :

```
$ git diff HEAD -- flutter-src/lib/main.dart                      -> vide  INCHANGE
$ git diff HEAD -- flutter-src/assets/data/dakar_network.json     -> vide  INCHANGE
$ git diff HEAD -- data/gtfs/                                     -> vide  INCHANGE
$ git diff HEAD -- data/transit/reference-policy.json             -> vide  INCHANGE
$ git diff HEAD -- tests/transit-validation.test.js               -> vide  INCHANGE

$ find . -path ./.git -prune -o -type f -newermt '<heure du checkout>' -print
  -> 43 fichiers : 42 sous data/transit/ + tests/transit-data-layer.test.js
```

| Élément | État |
|---|---|
| `main.dart` | **unchanged** |
| GPS | **unchanged** |
| routage | **unchanged** |
| UI, cartes, marqueurs, filtres, NavigationBar, Assistant IA | **unchanged** |
| `dakar_network.json` | **unchanged** |
| `data_service.dart` / `data_provider.dart` | **non touchés par ce lot** — portent des modifications antérieures (mtime = heure du checkout) |
| `data/gtfs/` | **unchanged** — non mélangé à PassBi |

Les 43 fichiers écrits sont tous postérieurs au checkout ; tous les fichiers Flutter portent l'heure du checkout.

**Commit : aucun.** Conforme à la consigne — en attente de validation avant intégration. Branche de travail : `arena/01a0df09-dakar-bus`.

---

## 15. Validation automatique

`tests/transit-data-layer.test.js` — **28 tests**, exécutés par `npm test` (runner existant `node --test tests/*.test.js`).

| Famille | Tests | Vérifie |
|---|---|---|
| Niveaux | 2 | trois dossiers séparés ; `data/gtfs/` et `reference-policy.json` intacts |
| Intégrité GTFS | 5 | IDs uniques ; `stop_sequence` cohérente ; trip→route, stop_time→stop, service_id valides ; aucune route ni stop_time orphelin ; convention GTFS des heures |
| Provenance | 3 | blocs complets et vocabulaire contrôlé ; PassBi jamais promu ; provenance par champ |
| TER | 5 | 13 gares appariées 1:1 ; aucun UUID public ; AIBD/Sébikotane/Keur Moussa absents ; semaine exclue / dimanche partielle ; dimensions indépendantes |
| BRT | 3 | B1/B2/B3 distincts ; 1 station physique + N routes sans duplication ; B3 hors GTFS |
| DDD | 2 | 34 + 19 = 53, aucun `DISCONTINUED` ; arrêts non inventés |
| AFTU | 1 | référentiel brut, aucune identité |
| Crosswalk | 2 | schéma complet et politique ; 73 AFTU en `UNCONFIRMED` |
| Statuts | 3 | quatre dimensions ; `REAL_TIME = NON` ; LEVEL 3 explicite |
| Manifeste + critère de fin | 2 | empreintes et re-téléchargement ; chaque entité a un statut et une raison |

**Résultat : `# tests 52 · # pass 52 · # fail 0`.** Les 24 tests applicatifs préexistants passent toujours, sans modification.

### 15.1 Défauts trouvés et corrigés par les tests

Les tests n'ont pas été écrits après coup pour valider un résultat : ils ont révélé **cinq défauts réels** du générateur, tous corrigés.

| Défaut | Détecté par | Correction |
|---|---|---|
| `stop_times.stop_id` référençait les **UUID PassBi** au lieu des identifiants publics | test d'intégrité stop_time→stop | mapping `passbi_stop_id → dakar_bus_stop_id` appliqué |
| Deux stations PassBi se résolvaient sur le **même arrêt**, créant une duplication | test anti-double-affichage | liste `unmerged_passbi_duplicates`, fusion refusée |
| `fare_rules.txt` AFTU (**44 Mo**) copié dans Git | contrôle de volume | garde-fou `MAX_BYTES = 400 000` |
| `verification_note` absente sur la provenance `sequence` | test de provenance | note ajoutée |
| Entrée LEVEL 3 « fréquences » sans `usable_for` | test LEVEL 3 | champs `usable_for` / `not_usable_for` renseignés |

---

## 16. Critère de fin

> « Pour chaque ligne, arrêt et horaire conservé de PassBi, savons-nous pourquoi nous le conservons et quel est son statut actuel ? »

**Oui.** Un test (`critère de fin`) impose que **chacune des 130 routes** de `route_status.json` porte une `note` non vide, et que **chacune des 186 entrées** du crosswalk porte une `evidence` non vide. Aucune entité n'est conservée sans raison tracée.

| Statut | Traitement appliqué |
|---|---|
| `CONFIRMED` | utilisable selon les règles de production — **13 gares TER, 7 stations B2** |
| `PERSISTENT` | structure actuelle confirmée — **B1 et ses 21 stations, 34 lignes DDD** |
| `PARTIALLY_CONFIRMED` | utilisable **uniquement** pour les éléments confirmés — **48 départs TER dimanche, départ de Dakar seulement** |
| `UNCONFIRMED` | référence interne uniquement — **73 AFTU, 19 DDD, horaires BRT/DDD/AFTU** |
| `CONTRADICTED` | ancienne donnée conservée pour traçabilité — **grille TER semaine** |
| `NEW` | donnée actuelle absente de PassBi — **BRT B3** |

---

## 17. Prochaines étapes

1. **Lever le blocage licence** avant toute intégration ou republication. Préalable absolu, indépendant de la qualité.
2. **Demander à SETER une grille horaire datée.** C'est l'unique voie vers un `SCHEDULED` TER. La grille dimanche est déjà corroborée à 48/48 : une publication officielle la ferait basculer de `PARTIALLY_CONFIRMED` à `CONFIRMED`.
3. **Exploiter le crosswalk DDD.** 34 lignes avec numéro et terminus confirmés par l'opérateur, contre 12 exposées aujourd'hui. Gain de couverture le mieux étayé — sous réserve de licence.
4. **Instruire la numérotation AFTU** dans un lot dédié, à partir des codes PassBi, **sans jamais déduire du seul numéro**.
5. **Documenter la B3** auprès de SunuBRT pour obtenir une liste de stations rattachable, seule condition de son entrée en structure.
6. **Trancher les doublons BRT** (Grand Médine / Pôle Grand Médine, et les 3 pôles d'échange) par une source opérateur, jamais par proximité.
7. **Ne pas rouvrir Keur Massar / Mbao.** Tranché par la preuve au lot 4.3.

---

## 18. Récapitulatif des fichiers

**43 fichiers créés, 0 modifié, 0 supprimé.**

```
data/transit/
├── README.md                                   (1)
├── MANIFEST.json
├── schema/provenance.schema.json
├── tools/build_transit_layer.py
├── passbi/                                     (21 — LEVEL 1)
│   ├── ter/    agency routes stops calendar
│   ├── brt/    agency routes stops calendar_dates transfers
│   ├── ddd/    agency routes stops calendar calendar_dates fare_attributes
│   └── aftu/   agency routes stops calendar calendar_dates fare_attributes
├── crosswalk/crosswalk.json
├── validated/                                  (13 — LEVEL 2)
│   ├── gtfs/   agency routes stops trips stop_times calendar calendar_dates
│   ├── structure/  ter_stop_mapping ter_schedule brt_route_structure
│   │               ddd_routes aftu_raw_registry
│   ├── route_status.json
│   └── BUILD_SUMMARY.json
└── production/production_ready.json            (1 — LEVEL 3)

tests/transit-data-layer.test.js                (1)
```

**Volume total : 42 fichiers, 691 ko.** Régénérable par `python3 data/transit/tools/build_transit_layer.py /tmp/passbi_gtfs`.
