# Dakar Bus — Transit Data Layer 4.5 renforcé — Crosswalk, référentiel public et horaires

**Lot : 4.5 renforcé — Référentiel public AFTU / Dakar Dem Dikk + préparation des horaires exploitables**
**Date d'audit : 2026-09-27**
**Générateurs : `data/transit/tools/build_transit_layer.py` (4.4), `data/transit/tools/build_crosswalk_4_5.py`, `data/transit/tools/build_public_registry_4_5.py`**
**Sources : 9 auditées (6 N1, 3 N2), 0 N3 utilisée**

---

## 1. Sources

### 1.1 Principe

Recherche en priorité des sources actuelles N1 (opérateur/institutionnel), N2 public documenté (PassBi), N3 OSM seulement pour corroborer. Aucune identité n'est déduite du seul numéro, d'un numéro proche, d'une origine/destination supposée, d'un nom ressemblant, d'une proximité géographique, d'OSM seul ou d'une ancienne donnée PassBi non corroborée.

### 1.2 Registre audité

Table reproduite de `data/transit/crosswalk/source_audit.json` — 9 sources, toutes vérifiées le 2026-09-27.

| ID | URL | Niveau | `source_type` | Citée dans les preuves |
|---|---|---|---|---|
| `S_AFTU_OP` | `https://aftu-senegal.org/infos-pratiques/` | N1 | `OFFICIAL_OPERATOR` | **216** fois |
| `S_PASSBI` | `https://github.com/impactsolutionsas/passbi_core` | N2 | `PASSBI` | **141** fois |
| `S_DDD_OP` | `https://demdikk.sn/info-voyageurs/` | N1 | `OFFICIAL_OPERATOR` | **75** fois |
| `S_SENEGO` | `https://senego.com/services/horaires-brt-ter` | N2 | `INSTITUTIONAL` | **28** fois |
| `S_BRT_OP` | `https://www.sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/` | N1 | `OFFICIAL_OPERATOR` | **23** fois |
| `S_TERSEN` | `https://ter-senegal.sn/gares/` | N2 | `INSTITUTIONAL` | **13** fois |
| `S_BRT3_OP` | `https://www.sunubrt.sn/brt-3-semi-express/` | N1 | `OFFICIAL_OPERATOR` | **8** fois |
| `S_TER_PLAN` | `https://www.terdakar.sn/acceder-au-plan-de-la-ligne/` | N1 | `OFFICIAL_OPERATOR` | **2** fois |
| `S_TER_OP` | `https://www.terdakar.sn/les_horaires_des_trains/` | N1 | `OFFICIAL_OPERATOR` | 0 — consultée pour les fréquences |

Six sources sont N1, trois sont N2. **Aucune source N3 (OSM) n'est retenue** dans l'audit : OSM seul ne suffit pas à établir l'identité officielle d'une ligne et le lot n'en avait pas besoin. Un test vérifie la fermeture : chaque `source_url` apparaissant dans une `evidence[]` figure dans `source_audit.json`.

### 1.3 Dates de source

| Source | Date de source | Vérification |
|---|---|---|
| AFTU `aftu-senegal.org/infos-pratiques/` | 2026-07-14 | 2026-09-27 |
| DDD `demdikk.sn/info-voyageurs/` | — (page vivante, dernière actu 2026-09-02) | 2026-09-27 |
| BRT B3 `sunubrt.sn/brt-3-semi-express/` | 2026-09-24 | 2026-09-27 |
| TER `terdakar.sn/les_horaires_des_trains/` | 2026-03-30 | 2026-09-27 |
| TER `ter-senegal.sn/gares/` | 2026-05-14 | 2026-09-27 |
| Senego | 2026-07-27 | 2026-09-27 |
| PassBi | 2025-08-31 (feed period 20250818-20250831) | 2026-09-27 |

### 1.4 Sources consultées non retenues comme preuves

| Source | Motif |
|---|---|
| `fr.wikipedia.org/wiki/BRT_de_Dakar` (2026-03-26) | corrobore 23 stations et B3 depuis octobre 2025 — **non retenue comme preuve** |
| `seneplus.com` (2025-05-05) | corrobore B1 = 21 et B2 = 7 stations — **non retenue comme preuve** |
| `sentersa.sn/plan-de-transport/` (2013) | 13 gares dont Keur Massar et Mbao — non corroborée, la moins fiable, écartée |

---

## 2. Méthodologie

### 2.1 Trois niveaux conservés

Le lot 4.4 a séparé :

1. **RAW/HISTORICAL** (`data/transit/passbi/`) : 4 feeds PassBi, 21 fichiers, 337 554 o, MANIFEST avec SHA-256 et garde-fou `MAX_BYTES = 400_000`.
2. **VALIDATED REFERENCE** (`data/transit/validated/`) : GTFS minimal TER dimanche (48 trips, 624 stop_times) + registres `ter_stop_mapping`, `ter_schedule`, `brt_route_structure`, `ddd_routes`, `aftu_raw_registry`.
3. **PRODUCTION** (`data/transit/production/production_ready.json`) : 4 prêtes / 7 non prêtes, aucune licence PassBi (republication `BLOCKED`).

Le lot 4.5 ajoute sans casser la compatibilité 4.4 :

- le **crosswalk** (258 relations, schéma étendu : `source_route_id`, `public_route_id`, `direction`, `provenance_by_field`)
- le **référentiel public** `validated/public_routes.json` (115 lignes officielles, provenance par champ)
- le **registre horaire** `validated/schedule_registry.json` (fréquences ESTIMATED vs horaires, temps >24h)

Aucune fusion automatique sur ressemblance. `NAME_ONLY` ne promeut jamais. `COORDINATE_ONLY` n'établit jamais une identité officielle. OSM seul ne suffit pas. `EXACT`/`DOCUMENTED` exigent `evidence[]` + `verified_at`. `DELETED` interdit sans preuve de suppression.

### 2.2 Appariement AFTU (numéro + terminus)

Le site AFTU publie **72 lignes** : 1-5 puis 24-89 et 91 (pas de 90). Chaque entrée donne les deux terminus (ex. `GADAYE (GUEDIEWAYE) - GARE DE COLOBANE`). Le code PassBi `Axx__` encode lui-même `route_short_name` et les origines/destinations dans `route_long_name` (`AFTU_30_GADAYE_COLOBANE`).

Normalisation : suppression des mots vides (`TERMINUS`, `GARE`, `CITE`…), `squash()` pour `M T O A` → `MTOA` et `LIBERTE 5` → `LIBERTE5`, table `ALIAS_WORD` limitée aux variantes réellement observées (`MALICKA`/`MALIKA`, `SIPRESS`/`SIPRES`, `JAXAAYE`/`JAXAAY`, `DAROUHANE`/`DAROUKHANE`, `JAXAAY2`/`JAXAAY`…), jamais d'équivalence sémantique devinée (`MAMELLES` ≠ `ALMADIES`). Séparateurs ` - `, `- ` et ` ↔ ` gérés.

- `TERMINI_MATCH` : ≥2 tokens communs → `STRUCTURAL` / `PERSISTENT` / `HIGH`
- `PARTIAL_TERMINI` : 1 token → `STRUCTURAL` / `PARTIALLY_CONFIRMED` / `MEDIUM`
- `NUMBER_ONLY` : 0 token → `UNCONFIRMED` / `LOW`
- `NOT_FOUND` : numéro absent → `UNCONFIRMED` + note d'absence de preuve de suppression

Chaque ligne PassBi produit **deux** relations : `passbi → operator_current` (statut ci-dessus) et `passbi → dakar_bus` (**toujours `UNCONFIRMED`**, numérotation 1-72 continue du projet vs 1-5/24-91 opérateur).

### 2.3 Appariement DDD (numéro + terminus publiés)

Le site `demdikk.sn/info-voyageurs/` publie le **numéro et les deux terminus** de chaque ligne (39 codes : 7 Dessertes TER dont 502A/B, 503A/B, 504A/B, 11 Urbaines, 21 Banlieue). Pour les 34 persistantes, les deux terminus concordent (y compris variantes A/B ramenées au numéro de base : 15A/15B → 15). La relation est `STRUCTURAL` / `HIGH` / `PERSISTENT` avec deux preuves : l'opérateur publie `LIGNE n : origine ↔ destination` et le code PassBi encode le même numéro et les initiales des mêmes terminus.

### 2.4 BRT et TER

BRT : 22 entrées station PassBi = 21 stations physiques confirmées + 1 doublon `POLE GRAND MEDINE` (`COORDINATE_ONLY`, non fusionné). B1/B2/B3 distinctes, routes séparées, `stop_sequence` propre.

TER : 13 gares, même ordre, 85 m d'écart moyen, 221 m max (Colobane). PassBi crosswalk conservé comme historique, pas comme identifiants officiels actuels.

### 2.5 Horaires — préparation sans invention

Un départ est `SCHEDULED` uniquement si : heure exacte + source identifiable + période de validité + service actif + lien route→trip→stop→stop_time cohérent + provenance traçable. Sinon `UNKNOWN`. Une fréquence `toutes les 10 min` donne `ESTIMATED` (`Passage estimé toutes les 10 min`) et ne génère jamais `10:00, 10:10, 10:20` artificiels. `REAL_TIME` exige vehicle/trip/stop/direction/timestamp/fraîcheur/source — PassBi reste `NOT_REAL_TIME`. Les heures GTFS ≥24:00 sont conservées telles quelles.

---

## 3. AFTU

### 3.1 Référentiel officiel (public_routes.json)

**72 lignes** publiées par `aftu-senegal.org/infos-pratiques/` (14/07/2026). Chacune avec numéro, origine, terminus, direction `null` (aucune direction publiée par l'opérateur), `identity_status = CONFIRMED`, `structure_status = UNKNOWN`, `schedule_status = UNKNOWN`, `realtime_status = UNKNOWN`, `confidence = HIGH`.

Exemple (`AFTU 30`) :

```
AFTU 30
Origine : GADAYE (GUEDIEWAYE)
Terminus : GARE DE COLOBANE
Source : https://aftu-senegal.org/infos-pratiques/ (OFFICIAL_OPERATOR, 2026-07-14)
Statut : CONFIRMED
```

Si une source ne donnait que `AFTU 30` sans terminus, le registre porterait `destination = UNKNOWN` — **aucune destination n'est déduite**. Ici toutes les 72 ont leurs deux terminus.

### 3.2 PassBi — 73 références conservées

`data/transit/crosswalk/aftu_crosswalk.json` : **146 entrées** (73 vers `operator_current`, 73 vers `dakar_bus`), 73 routes PassBi.

| Verdict | Nombre | Signification |
|---|---|---|
| `TERMINI_MATCH` | **52** | numéro + 2 terminus communs |
| `PARTIAL_TERMINI` | **18** | numéro + 1 terminus |
| `NUMBER_ONLY` | **2** | `A31ST` (31), `A52BJ` (52) |
| `NOT_FOUND` | **1** | `A90TD` (90) — pas de ligne 90 chez l'opérateur |

Chaque ligne garde ses deux identifiants :

- `source_route_id` : l'identifiant PassBi (ex. `gtfs_AFTU` `route_id`)
- `public_route_id` : `AFTU 30` **uniquement** lorsque `match_type ∈ {EXACT, DOCUMENTED, STRUCTURAL}` ; sinon `null`.

Vers `dakar_bus` : **les 73 restent `UNCONFIRMED`**, `public_route_id = null`, `target_id = null` — la seule identité du numéro ne constitue pas une preuve et les numérotations ne se superposent même pas.

### 3.3 Numérotation

- PassBi : `1-5` puis `24-91` (73 codes, pas de 6-23, pas de 90 manquant ? — 90 existe en PassBi mais pas chez l'opérateur)
- Opérateur : `1-5` puis `24-89` et `91` (72 lignes, pas de 90) — **conclusion : PassBi correspond à l'opérateur, c'est la numérotation 1-72 continue du projet (`flutter-src/assets/data/dakar_network.json`) qui est l'anomalie. Aucune renumérotation automatique n'est effectuée** (test vérifie 72 `aftu_*` 1..72 inchangés).

---

## 4. DDD (Dakar Dem Dikk)

### 4.1 Référentiel officiel (public_routes.json)

**39 codes** publiés par `demdikk.sn/info-voyageurs/` : 7 Dessertes TER, 11 Urbaines, 21 Banlieue (dont `15A/15B`, `16A/16B` à terminus identiques). Chacun `CONFIRMED` / `UNKNOWN` / `UNKNOWN` / `UNKNOWN`, `HIGH`.

Sections :

- Dessertes TER : 501 (`GARE DE DAKAR ↔ PALAIS 2`), 502A/B, 503A/B, 504A/B
- Urbaines : 1, 4, 7, 8, 9, 10, 13, 18, 20, 121, 23
- Banlieue : 2, 5, 6, 11, 12, 15A/B, 16A/B, 234, 233, 232, 228, 227, 221, 220, 219, 218, 217, 213, 208
- TAF TAF : itinéraire Ouakam → AIBD / Sphère Ministérielle (premier/dernier départs publiés, mais sans numéro de ligne ni liste d'arrêts) — **non promu en ligne numérotée**

Exemple déjà démontré conservé :

```
D501GP — DDD 501 : GARE DE DAKAR ↔ PALAIS 2
Source : https://demdikk.sn/info-voyageurs/ (OFFICIAL_OPERATOR)
Preuve : l'opérateur publie LIGNE 501 : GARE DE DAKAR ↔ PALAIS 2 ; le code PassBi D501GP encode G+P
```

### 4.2 Les 34 persistantes

`data/transit/validated/structure/ddd_routes.json` : **34/53** lignes PassBi persistent. Chacune `identity = PERSISTENT`, `structure = UNKNOWN`, `schedule = UNKNOWN`, `realtime = UNKNOWN`. Aucun `trips.txt`/`stop_times.txt`/`shapes.txt` créé.

Dans le crosswalk (`ddd_crosswalk.json`, 65 entrées) : les 34 vers `operator_current` sont `STRUCTURAL` / `HIGH` / `PERSISTENT` avec `public_route_id = DDD n` et deux preuves (opérateur + initiales PassBi). Les 10 vers `dakar_bus` (dont `ddd_1` = `PARTIALLY_CONFIRMED` / `LOW` — itinéraire interne `CONFLICTING`) sont `STRUCTURAL`.

### 4.3 Les 19 non retrouvées

**19** codes PassBi absents de la liste actuelle : 102, 103, 105, 111, 210, 223, 231, 301, 305, 308, 311, 315, 319, 323, 401, 402, 403, 404, 405. Toutes `UNCONFIRMED` / `LOW` / `UNCONFIRMED` avec la note imposée :

> « Non retrouvée dans les sources actuelles consultées ; absence de preuve de suppression établie. Aucun statut DELETED, DISCONTINUED ou INACTIVE. »

Jamais `deleted`/`discontinued`/`inactive`.

---

## 5. BRT

### 5.1 Référentiel public

| Route | Statut identité | Statut structure | Source | Horaires |
|---|---|---|---|---|
| **B1** | `CONFIRMED` | `PERSISTENT` | `sunubrt.sn` | `ESTIMATED` (6 min + renfort Petersen↔Grand Médine 6h-10h/16h-20h) |
| **B2** | `CONFIRMED` | `CONFIRMED` | `sunubrt.sn` | `ESTIMATED` (6 min, lun-sam) |
| **B3** | `NEW` | `UNCONFIRMED` | `sunubrt.sn/brt-3-semi-express/` (2026-09-24) | `UNKNOWN` |

B1/B2/B3 **séparées**. B3 n'est jamais rapprochée de B1/B2 (test vérifie `status = NEW` et note `Aucune correspondance avec B1 ou B2`).

### 5.2 Stations

- **21 stations physiques** confirmées (`L44.brt.physical_stations`), **22 entrées station PassBi** (21 `STRUCTURAL` + 1 `COORDINATE_ONLY`).
- **7 stations partagées** B1/B2 (même `stop_id` physique, `stop_sequence` propre au trip/route, **aucune duplication automatique**).
- **B1 : 21 stations PassBi, 23 stations actuelles documentées** — les deux niveaux sont conservés, **21 n'est pas porté à 23**.
- **B2 : 7 stations**, même ordre, `DOCUMENTED` / `CONFIRMED`.
- **B3 : 7 noms officiels** (`Préfecture Guédiawaye` → `Papa Gueye Fall`, dont `Gueule Tapée` non fusionnée avec le doublon).
- **Doublon conservé** : `POLE GRAND MEDINE` (`1:QPEM`, `COORDINATE_ONLY`, `LOW`, `UNCONFIRMED`, `NON fusionnée` — `COORDINATE_ONLY` ne suffit jamais).

Modèle : `physical_stop ├── route B1 ├── route B2 └── route B3`.

### 5.3 Fréquences

`brt_route_structure.json` : `frequency.value_min = 6` (`CONFIRMED`), `peak_reinforcement` `PERSISTENT`/`MEDIUM` (PassBi 258 courses 6h-9h/17h-20h, actuel 6h-10h/16h-20h). Fréquence ≠ horaire exact.

---

## 6. TER

### 6.1 Référentiel public

**1 route** `ter_dakar_diamniadio` (`Dakar ↔ Diamniadio`), `CONFIRMED` / `CONFIRMED` / `ESTIMATED` / `UNKNOWN`, `HIGH`.

**13 gares confirmées**, même ordre, mêmes coordonnées (écart moyen 85 m, max 221 m Colobane, min 9 m) :

1. Dakar - Gare ferroviaire (`544a27a5`)
2. Colobane (`c70477e7`)
3. Hann (`f405b86e`)
4. Dalifort (`61d82f6f`)
5. Baux Maraîchers (`d802c3ec`)
6. Pikine (`650b288f`)
7. Thiaroye (`956bedfd`)
8. Yeumbeul (`f8ec6c04`)
9. Keur Mbaye Fall (`41016cdb`)
10. PNR Rufisque (`90110d84`)
11. Rufisque (`1d859f92`)
12. Bargny (`d30b03f2`)
13. Diamniadio (`4445e51b`)

Crosswalk : 15 entrées — 13 gares `STRUCTURAL` / `HIGH` / `CONFIRMED` (4 preuves : nom, rang, position, source actuelle`) + 2 relations `DOCUMENTED` (Dakar↔Diamniadio `direction_id` 0/1 via `terdakar.sn/acceder-au-plan-de-la-ligne/`).

### 6.2 Horaire TER conservé

`ter_schedule.json` : grille actuelle 10 min semaine (5h45→22h05, 20 min après 21h05) et 20 min dimanche (6h25→22h05) — `ESTIMATED`, pas d'heure par station publiée. PassBi semaine 12 min (05:30→22:06, 81 départs) `CONTRADICTED`. Dimanche 48/48 retrouvés, 2 PassBi seuls (18:03, 19:50) exclus. GTFS validé : **48 trips** `TER_SUNDAY_AUDIT` (fenêtre `20260927-20260927`), **624 stop_times**, `calendar` 1, `calendar_dates` 0, `timepoint` détruit à l'import (lot 4.2B).

### 6.3 Gares non ajoutées

**3 noms écartés**, aucune entrée :

- `AIBD` : `PROVISIONAL` (mise en service annoncée 28/09/2026, non confirmée à la date d'audit)
- `Sébikotane` / `Keur Moussa` : communes traversées par la phase 2 (EESS BAD 2016), jamais documentées comme gares — une commune traversée n'est pas une gare.

Identifiants PassBi = crosswalk historique, pas identifiants officiels actuels.

---

## 7. Horaires

### 7.1 Registre commun

`data/transit/validated/schedule_registry.json` — 628 entrées :

| Élément | Nombre | `schedule_status` |
|---|---|---|
| **Fréquences** | **4** | `ESTIMATED` |
| `TER_WEEKDAY` 10 min (5h45→22h05, 20 min après 21h05) | 1 | `ESTIMATED` |
| `TER_SUNDAY` 20 min (6h25→22h05) | 1 | `ESTIMATED` |
| `BRT_ALL_DAYS` 6 min + renfort pointe | 1 | `ESTIMATED` |
| `BRT_WEEKDAYS` 6 min | 1 | `ESTIMATED` |
| **Stop_times TER Sunday** | **624** (48 trips × 13 gares) | — |
| départ Dakar (`stop_sequence = 1`) | 48 | `PARTIALLY_CONFIRMED` / `MEDIUM` |
| intermédiaires | 576 | `UNCONFIRMED` / `LOW` |
| `SCHEDULED` | **0** | — |
| `REAL_TIME` | **0** | `NO_REAL_TIME_FEED` |

Aucune fréquence n'a généré `10:00, 10:10` artificiels. `ESTIMATED` est affiché comme *Passage estimé toutes les 10 min*, jamais comme compte à rebours exact.

### 7.2 Règles vérifiées par les tests

1. Aucune relation `SCHEDULED` sans les 6 conditions (§12) — ici **0** `SCHEDULED`, donc vacuité respectée.
2. Aucune entrée `REAL_TIME` sans `vehicle/trip/stop/direction/timestamp/freshness/source` — **0** `REAL_TIME` (`PassBi = NOT_REAL_TIME`).
3. `ESTIMATED` ne contient pas de `trip_id`/`stop_id`/`arrival_time` précis et porte l'avertissement `ne devient jamais un horaire exact`.
4. Fréquence ≠ horaire exact (règle `ESTIMATED` vs `SCHEDULED` distincts).
5. Heures GTFS >24:00 conservées telles quelles, jamais converties (exemple `25:15:00` valide, `times_rewritten = 0`, 0/624 actuellement ≥24:00).

### 7.3 Objectif UX préparé

- Horaire exact : *Départ dans 6 min / 1 min / maintenant / dans 10 min* — uniquement si `SCHEDULED` et prochain départ réellement connu (ici **non disponible**, donc non affiché).
- Temps réel : *Arrivée dans 3 min* — uniquement avec source temps réel (ici **indisponible**).
- Fréquence : *Passage estimé toutes les 10 min* — disponible (TER/BRT).

Chaque `stop_time` porte `source`, `source_type`, `source_url`, `date_source`, `date_verified`, `valid_from`/`valid_to` = `20260927`, `confidence`, `verification_note`.

---

## 8. Provenance

### 8.1 Granularité par champ

`public_routes.json` et `crosswalk.json` n'ont pas de provenance globale trompeuse. Chaque entrée expose `provenance_by_field` :

```json
identity:  { source: "demdikk.sn", status: "CONFIRMED" }
origin_destination: { source: "demdikk.sn", status: "CONFIRMED" }
stops:     { source: "UNKNOWN", status: "UNKNOWN", note: "aucun arrêt actuel vérifié" }
schedule:  { source: "UNKNOWN", status: "UNKNOWN" }
```

Exemple (`DDD 501`) : `route_number` `CONFIRMED` (opérateur), `origin_destination` `CONFIRMED` (terminus publiés), `stops` `UNKNOWN` (aucun arrêt vérifié), `schedule` `UNKNOWN` (aucun horaire). Une identité confirmée ne signifie pas que les horaires sont disponibles — c'est volontaire.

### 8.2 Audit

`sources` : chaque relation est traçable jusqu'à `evidence[].source_url` + `date_verified`, toute URL citée figure dans `source_audit.json` (test). Niveaux respectés : aucune identité forte par PassBi seul ou OSM seul.

---

## 9. Statistiques

### 9.1 Crosswalk (registre central)

| Élément | Valeur |
|---|---|
| **Crosswalk total** | **258** |
| TER | 15 |
| BRT | 32 |
| DDD | 65 |
| AFTU | 146 |

| `match_type` | Nombre | Part |
|---|---|---|
| `STRUCTURAL` | **148** | 57,4 % |
| `UNCONFIRMED` | **105** | 40,7 % |
| `DOCUMENTED` | **4** | 1,6 % |
| `COORDINATE_ONLY` | **1** | 0,4 % |
| `EXACT` | **0** | 0 % |
| `NAME_ONLY` | **0** | 0 % |

| `confidence` | Nombre |
|---|---|
| `HIGH` | **124** |
| `MEDIUM` | **28** |
| `LOW` | **106** |

| `status` | Nombre |
|---|---|
| `PERSISTENT` | **117** |
| `UNCONFIRMED` | **96** |
| `PARTIALLY_CONFIRMED` | **19** |
| `CONFIRMED` | **16** |
| `NEW` | **8** |
| `UNKNOWN` | **2** |
| `DELETED` | **0** |

### 9.2 Référentiel public

| Réseau | Total officiel | `identity_status` | Détail |
|---|---|---|---|
| **AFTU** | **72** | `CONFIRMED` 72 | 1-5 puis 24-89 et 91 (pas de 90) |
| **DDD** | **39** | `CONFIRMED` 39 | 7 TER + 11 Urbaines + 21 Banlieue |
| **BRT** | **3** | B1 `CONFIRMED`, B2 `CONFIRMED`, B3 `NEW` | B1 `PERSISTENT`, B2 `CONFIRMED`, B3 `UNCONFIRMED` |
| **TER** | **1** route, **13** gares | `CONFIRMED` / `CONFIRMED` | Dakar→Diamniadio |
| **Public total** | **115** | — | `by_network {TER:1, BRT:3, DDD:39, AFTU:72}` |

Crosswalk DDD : 34 persistantes / 19 non retrouvées ; AFTU crosswalk : 52 `TERMINI_MATCH`, 18 `PARTIAL`, 2 `NUMBER_ONLY`, 1 `NOT_FOUND`, 73 vers Dakar Bus `UNCONFIRMED`.

### 9.3 Horaires

| Élément | Valeur |
|---|---|
| **Fréquences** `ESTIMATED` | **4** |
| **Stop_times** | **624** (48×13) |
| `PARTIALLY_CONFIRMED` (départs Dakar) | 48 |
| `UNCONFIRMED` (intermédiaires) | 576 |
| `SCHEDULED` | **0** |
| `ESTIMATED` (total) | **4** |
| `UNKNOWN` (stop_times) | 0 |
| `REAL_TIME` | **0** |
| GTFS >24h exemple | `25:15:00` valide, `times_rewritten = 0` |

---

## 10. Éléments non vérifiés

### 10.1 DDD — 19 lignes

Voir §4.3. Toutes `UNCONFIRMED` / `LOW`, note d'absence de preuve de suppression.

### 10.2 AFTU — 21 lignes non pleinement confirmées

| Catégorie | Nombre | Détail |
|---|---|---|
| `NUMBER_ONLY` | **2** | `A31ST` (31), `A52BJ` (52) |
| `NOT_FOUND` | **1** | `A90TD` (90) |
| `PARTIAL_TERMINI` | **18** | `A29MP`, `A32DS`, `A33CD`, `A36DN`, `A38GS`, `A41GP`, `A43CO`, `A57LR`, `A64dg`, `A65Ck`, `A68st`, `A69Dn`, `A74bS`, `A77CL`, `A79Cg`, `A85LL`, `A88KL`, `A89bT` |
| **Identité avec le projet** | **73** | les 73 lignes, sans exception `UNCONFIRMED` |

Les 18 partielles portent `PARTIALLY_CONFIRMED` / `MEDIUM` : un seul terminus concorde.

Contrôle : `52 + 18 + 2 + 1 = 73` PassBi, et `2 + 1 + 18 = 21` non pleinement confirmées.

### 10.3 BRT — 1 station

`POLE GRAND MEDINE` : `COORDINATE_ONLY`, `LOW`, `UNCONFIRMED`, non fusionnée.

### 10.4 TER — 3 noms écartés

`AIBD` (provisional), `Sébikotane` et `Keur Moussa` (communes traversées).

### 10.5 Horaires — non vérifiés

- AFTU 72 et DDD 39 : `schedule_status = UNKNOWN` (aucune grille horaire publiée par l'opérateur)
- BRT B3 : `UNKNOWN`
- TER intermédiaires : `UNCONFIRMED` (heure PassBi conservée mais non confirmée par l'opérateur)
- Temps réel : **0** entrée — aucun flux `REAL_TIME` disponible

### 10.6 Preuves manquantes

| Manque | Conséquence |
|---|---|
| Aucune déclaration d'équivalence PassBi ↔ opérateur | `EXACT` impossible partout |
| Aucune licence sur `passbi_core` | republication `BLOCKED` |
| Aucune API temps réel accessible | `REAL_TIME = 0` |
| Aucune grille horaire par station (TER/BRT) | `SCHEDULED = 0`, fréquences seules `ESTIMATED` |
| Numérotation du projet non publiée | 73 identités AFTU ↔ projet non établies |
| Structure actuelle de la B3 | `structure_status = UNCONFIRMED` |

---

## 11. Contradictions

| # | Contradiction | Traitement |
|---|---|---|
| 1 | **B1 : 21 stations PassBi vs 23 actuelles** | Les deux niveaux conservés. **21 n'est pas porté à 23.** |
| 2 | **Trois numérotations AFTU incompatibles** | Projet `1-72` continu est l'anomalie ; opérateur et PassBi `1-5` puis `24-91`. Aucune renumérotation. |
| 3 | **`A90TD` absente de l'opérateur** | `NOT_FOUND` + absence de preuve de suppression. Jamais `DELETED`. |
| 4 | **Nombre de lignes AFTU variable** | Opérateur 72, PassBi 73, Moovit 64. Chaque valeur attachée à sa source. |
| 5 | **Horaire TER semaine** | Grille PassBi 12 min contredite par 10 min opérateur. Consignée en `ter_schedule.json`, **non répercutée comme SCHEDULED** : identité ≠ horaire. |
| 6 | **`POLE GRAND MEDINE` vs `GRAND MEDINE`** | Doublon conservé, non fusionné. |
| 7 | **13 gares : deux listes divergentes** | `sentersa.sn/plan-de-transport/` (2013) ajoute Keur Massar et Mbao — source écartée, la moins corroborée. |
| 8 | **TER : fréquence vs horaire exact** | L'opérateur publie une fréquence, pas des heures par station. Le registre distingue `ESTIMATED` (fréquence) de `SCHEDULED` (heure exacte) — ici `SCHEDULED = 0`. |

Aucune contradiction n'est résolue par la proximité, la ressemblance ou la majorité des sources.

---

## 12. Tests

### 12.1 Résultat

```
$ npm test
# tests 83
# pass 83
# fail 0
```

| Fichier | Tests | Rôle |
|---|---|---|
| `tests/transit-crosswalk.test.js` | **21** | crosswalk, AFTU/DDD/BRT/TER, audit, cohérence |
| `tests/transit-data-layer.test.js` | 28 | lot 4.4 (LEVEL 1-3, GTFS, route_status) — 1 test précisé au 4.5 |
| `tests/transit-validation.test.js` | 24 | antérieur, non modifié |
| `tests/transit-schedule.test.js` | **10** | **référentiel public + horaires (renforcé)** |
| **Total** | **83** | |

### 12.2 Les 31 tests du lot 4.5

**Crosswalk (21)**

| # | Test |
|---|---|
| 1 | schéma complet et compatible 4.4 |
| 2 | `EXACT`/`DOCUMENTED`/`STRUCTURAL` exigent `evidence` + `verified_at` |
| 3 | `NAME_ONLY`/`COORDINATE_ONLY` ne portent jamais `HIGH` |
| 4 | DDD : 34 persistantes jamais `DELETED` |
| 5 | DDD : 19 non retrouvées `UNCONFIRMED` |
| 6 | DDD : aucune identité sans numéro + terminus |
| 7 | DDD : `D501GP` conserve sa preuve |
| 8 | AFTU : aucune correspondance numéro→numéro Dakar Bus |
| 9 | AFTU : non démontrées restent `UNCONFIRMED` |
| 10 | AFTU : numérotation projet non renumérotée |
| 11 | BRT : B1/B2/B3 distinctes |
| 12 | BRT : B2 = 7 stations, même ordre |
| 13 | BRT : B1 21 vs 23 conservés |
| 14 | BRT : station physique multi-routes sans duplication |
| 15 | TER : 13 gares, ordre conservé |
| 16 | TER : aucune nouvelle gare sans preuve |
| 17 | intermodal : registre de données, correspondances justifiées |
| 18 | audit : chaque source traçable |
| 19 | audit : niveaux respectés (pas d'identité par PassBi/OSM seul) |
| 20 | cohérence registres ↔ central |
| 21 | aucun horaire/tarif/temps réel inventé |

**Référentiel + horaires (10)**

| # | Test |
|---|---|
| 22 | public_routes : socle officiel complet (115, 72/39/3/1, provenance) |
| 23 | public_routes : AFTU 72, terminus documentés, pas de 90 |
| 24 | public_routes : DDD 39, provenance par champ |
| 25 | public_routes : BRT B1/B2/B3 et TER |
| 26 | horaires : aucun SCHEDULED sans les 6 conditions |
| 27 | horaires : aucun REAL_TIME sans flux frais |
| 28 | horaires : ESTIMATED sans faux scheduledTime |
| 29 | horaires : fréquence ≠ horaire exact |
| 30 | horaires : heures >24h acceptées |
| 31 | horaires : provenance et fenêtre de validité |

### 12.3 Défauts détectés et corrigés

Les tests ont trouvé **trois vrais défauts** avant 83/83 : `A90TD` sans entrée vers `dakar_bus`, comptage stations 21 vs 22 (doublon), et `AFTU_OFFICIAL` reconstruit de mémoire (52→18 `TERMINI_MATCH`). Corrigés par relecture de `aftu-senegal.org/infos-pratiques/` et ajout de `transit_sources.py` comme source unique.

Le test 4.4 « toutes les lignes AFTU sont `UNCONFIRMED` vers Dakar Bus » a été précisé (pas supprimé) : 73 entrées `UNCONFIRMED` / `null`.

---

## 13. Fichiers créés / modifiés

### 13.1 Créés — 13 fichiers

| Fichier | Taille | Rôle |
|---|---|---|
| `data/transit/crosswalk/crosswalk.json` | 416 795 o | registre central, **258 entrées** |
| `data/transit/crosswalk/aftu_crosswalk.json` | 244 101 o | AFTU, 146 entrées |
| `data/transit/crosswalk/ddd_crosswalk.json` | 128 340 o | DDD, 65 entrées (dont `provenance_by_field`) |
| `data/transit/crosswalk/brt_crosswalk.json` | 46 890 o | BRT, 32 entrées |
| `data/transit/crosswalk/ter_crosswalk.json` | 32 681 o | TER, 15 entrées |
| `data/transit/crosswalk/intermodal_transfers.json` | 8 994 o | 5 correspondances |
| `data/transit/crosswalk/source_audit.json` | 3 753 o | **9 sources** auditées |
| `data/transit/validated/public_routes.json` | 228 771 o | **115 routes** officielles, provenance par champ |
| `data/transit/validated/schedule_registry.json` | 513 219 o | 4 fréquences `ESTIMATED` + 624 `stop_times` |
| `data/transit/tools/build_crosswalk_4_5.py` | 41 558 o | constructeur crosswalk |
| `data/transit/tools/build_public_registry_4_5.py` | 21 644 o | constructeur référentiel + horaires |
| `data/transit/tools/transit_sources.py` | 13 536 o | source unique de vérité (listes + normaliseurs) |
| `tests/transit-schedule.test.js` | 11 162 o | 10 tests référentiel/horaires |

### 13.2 Générés au lot 4.4 et conservés

`data/transit/validated/gtfs/` (7 fichiers, 48 trips, 624 stop_times), `data/transit/validated/structure/` (5 registres), `data/transit/passbi/` (21 fichiers). `crosswalk.json` du 4.4 (186 entrées, 69 ko) a été **régénéré** en 258 entrées (schéma étendu, champs 4.4 conservés + `source_route_id`, `public_route_id`, `provenance_by_field`).

### 13.3 Modifiés — 1 fichier

| Fichier | Modification |
|---|---|
| `tests/transit-data-layer.test.js` | 1 test précisé (§12.3) — pas de suppression |

### 13.4 Traçabilité et reproduction

Chaque entrée renvoie à `evidence[].source_url` + `date_verified`, toute URL citée dans `source_audit.json`. Reproduction :

```bash
gh api repos/impactsolutionsas/passbi_core/git/blobs/{sha} --jq .content | base64 -d
python3 data/transit/tools/build_crosswalk_4_5.py /tmp/passbi_gtfs
python3 data/transit/tools/build_public_registry_4_5.py
npm test
```

Volume `data/transit/crosswalk/` : 766 666 o. Volume `data/transit/validated/` : 742 323 o + GTFS.

---

## 14. Vérification de non-modification de l'application

Contrôlé par commande, en fin de lot :

```
$ git diff -- flutter-src/lib/main.dart                              -> 0 lignes
$ git diff -- flutter-src/assets/data/dakar_network.json             -> 0 lignes
$ git diff -- data/gtfs/                                             -> 0 lignes
```

| Élément | État |
|---|---|
| `flutter-src/lib/main.dart` | **non modifié** |
| `flutter-src/assets/data/dakar_network.json` | **non modifié** — 105 routes, numérotation AFTU `1-72` intacte |
| `data/gtfs/` | **non modifié** |
| GPS, UI, `RoutePlanner`, moteur d'itinéraires, logique des correspondances | **non modifiés** |
| Moteur de correspondances intermodales | **non modifié** — `intermodal_transfers.json` registre de données uniquement |
| Prix, horaires inventés, temps réel fictif | **aucun** — `SCHEDULED = 0`, `REAL_TIME = 0`, tests l'interdisent |
| Commit, push, merge | **aucun** |

Les 5 fichiers Flutter modifiés et les 7 fichiers non suivis présents dans l'arbre proviennent de l'état préexistant du dépôt (mtime `2026-09-27 04:30:10`, antérieure aux fichiers du lot 4.5). **Aucun n'a été touché par ce lot.**

---

**LOT 4.5 RENFORCÉ — COMPLETE**

- Fichiers créés : **13** (7 crosswalk + 2 validés + 3 outils + 1 test horaire) + 1 rapport
- Fichiers modifiés : **1** (test 4.4 précisé) + 1 régénéré (`crosswalk.json` 186→258)
- AFTU : **72** officielles (`CONFIRMED`), **73** PassBi (52 `TERMINI_MATCH` / 18 `PARTIAL` / 2 `NUMBER_ONLY` / 1 `NOT_FOUND`), **73** vers Dakar Bus `UNCONFIRMED`
- DDD : **39** officielles, **34** persistantes (`PERSISTENT`), **19** non retrouvées (`UNCONFIRMED`), **0** `DELETED`
- BRT : **B1** 21/23, **B2** 7/7, **B3** `NEW` 7 stations
- TER : **13** gares, **1** route, ordre conservé, 3 noms écartés
- Crosswalk : **258** entrées (`STRUCTURAL` 148 / `UNCONFIRMED` 105 / `DOCUMENTED` 4 / `COORDINATE_ONLY` 1)
- Référentiel public : **115** routes (`TER 1` / `BRT 3` / `DDD 39` / `AFTU 72`)
- Horaires exploitables : **4** fréquences `ESTIMATED`, **48** départs `PARTIALLY_CONFIRMED`, **576** `UNCONFIRMED`, **0** `SCHEDULED`, **0** `REAL_TIME`, `>24h` supporté
- Tests : **83** (`21` crosswalk + **10** horaires + 28 4.4 + 24 validation) — **83/83 PASS**
- Application : **inchangée** (`main.dart` 0, `dakar_network.json` 0, `data/gtfs/` 0)
