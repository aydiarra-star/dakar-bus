# Dakar Bus — Moteur Horaire Exploitable — Lot 4.6

**Lot : 4.6 — Construction du moteur horaire exploitable**
**Date : 2026-09-27**
**Nature : DATA LAYER / ENGINE uniquement — aucune modification UI/GPS/RoutePlanner**
**Statut : COMPLETE**

---

## 1. Objectif

Construire, à partir de l'état réel du dépôt et des artefacts des Lots 4.4 et 4.5, une couche horaire capable de répondre de façon déterministe à :

```
nextDeparture(route, stop, serviceDate, currentTime)
```

en distinguant explicitement `SCHEDULED`, `PARTIALLY_CONFIRMED`, `ESTIMATED`, `UNKNOWN` et `REAL_TIME`, sans jamais inventer une heure de départ, d'arrivée, un passage à un arrêt, une correspondance ou une donnée temps réel. Une donnée inconnue reste `UNKNOWN`.

Le moteur doit pouvoir produire, lorsqu'il est démontrable :

- `🟢 Départ dans 3 min` (SCHEDULED/REAL_TIME)
- `🟡 Passage estimé toutes les 10 min` (ESTIMATED)
- `UNKNOWN` sinon

## 2. Fichiers analysés

### 2.1 Dépôt réel (recherche préalable)

| Chemin | Contenu | Rôle pour 4.6 |
|---|---|---|
| `data/transit/validated/public_routes.json` | 115 routes officielles (`TER 1`/`BRT 3`/`DDD 39`/`AFTU 72`), provenance par champ | Socle d'identité — vérifie que `IDENTITY=CONFIRMED` n'implique pas `SCHEDULE=CONFIRMED` |
| `data/transit/validated/schedule_registry.json` | 4 fréquences `ESTIMATED` + 624 `stop_times` (48 `PARTIALLY_CONFIRMED` / 576 `UNCONFIRMED`, 0 `SCHEDULED`) | Registre horaire source — le moteur ne lit que ce registre, jamais les `passbi/` bruts |
| `data/transit/validated/gtfs/` | `calendar.txt` 1 service (`TER_SUNDAY_AUDIT` 20260927), `trips.txt` 48, `stop_times.txt` 624 | Calendrier et trips validés — vérifiés caractère pour caractère vs PassBi |
| `data/transit/validated/structure/ter_schedule.json` | 48 départs dimanche corroborés, fréquences 10/20 min, `origin_departure_time=PARTIALLY_CONFIRMED` | Preuve que 48 départs ne sont pas promus en SCHEDULED |
| `data/transit/crosswalk/*.json` | `crosswalk.json` 258, `source_audit.json` 9 sources | Audit des sources et de la chaîne route→trip→stop |
| `data/transit/tools/transit_sources.py` | 72 AFTU + 39 DDD publiés | Source unique de vérité — pas de déduction par numéro |
| `flutter-src/lib/models/schedule_models.dart` | `ServiceDate`, `ServiceTime` (>24h conservé), `ScheduleEngine`, `Clock` | Modèle Dart existant — le moteur JS s'aligne sur sa sémantique (UTC, >24h, calendrier) |
| `flutter-src/lib/services/schedule_service.dart` (466 l.) | `nextDepartureFor` déterministe, `Clock` injecté, `realtimeMaxAge` | Référence d'architecture — le moteur JS en est le miroir data-layer |
| `docs/DAKAR_BUS_TRANSIT_DATA_LAYER_4_4.md` | 52/52 tests, 3 niveaux séparés | Rappel : `data/gtfs/` intact, `MAX_BYTES` garde-fou |
| `docs/DAKAR_BUS_TRANSIT_CROSSWALK_4_5.md` | 83/83 tests, 115 routes, 258 crosswalks | Base 4.5 renforcé — chiffres vérifiés, pas supposés |
| `data/gtfs/` | feed synthétique `2.1-dakar-pwa-gtfs-rt` (76 routes, 42 arrêts) | **Non touché** — `git diff` vide |
| `flutter-src/lib/main.dart` | — | **Non touché** — `git diff` vide |
| `flutter-src/assets/data/dakar_network.json` | 105 routes (72 AFTU 1-72) | **Non touché** — `git diff` vide |

Tous les fichiers ont été lus avant toute écriture. Les chiffres ci-dessus sont issus de `wc -l`, `sha256sum` et `python3 -c` sur les fichiers réels, pas des estimations.

## 3. Architecture

### 3.1 Couche pure

```
data/transit/engine/
  clock.js            — SystemClock / FixedClock (instant injecté, jamais Date.now() dans la logique métier)
  gtfs_time.js        — ServiceDate / ServiceTime (GTFS >24h conservé, 25:15:00 = lendemain 01:15)
  schedule_engine.js  — ScheduleEngine pur (route, stop, serviceDate, now) → discriminant
```

Le moteur :

- n'appelle jamais `GPS`, `UI`, `Flutter`, `RoutePlanner`, `data_provider.dart` ;
- ne lit aucun fichier à l'intérieur de `nextDeparture` — le registre est injecté au constructeur ;
- est déterministe pour un même `now` UTC ;
- refuse un `now` non-UTC (Dart) ou invalide → `UNKNOWN` ;
- gère `directionId` optionnel et invalide → `UNKNOWN`.

### 3.2 Injection

```js
const engine = ScheduleEngine.fromRegistry(scheduleRegistry, calendar);
engine.nextDeparture({ routeId, stopId, serviceDate: '2026-09-27', now: new Date('2026-09-27T08:17:00Z') });
```

`now` est un `Date` UTC explicite. Pour les tests : `new FixedClock('2026-09-27T08:17:00Z').now()`.

### 3.3 Flux

```
Realtime frais ? → REAL_TIME
  sinon départ exact PARTIALLY_CONFIRMED/SCHEDULED futur ? → ce statut (jamais promu)
    sinon fréquence ESTIMATED pour la route ? → ESTIMATED
      sinon UNKNOWN
```

Priorité : `REAL_TIME` (frais) > `SCHEDULED` > `PARTIALLY_CONFIRMED` > `ESTIMATED` > `UNKNOWN`. L'âge seul n'invalide pas PassBi ; c'est la corroboration et la structure qui décident.

## 4. Règles de classification

| Statut | Conditions (toutes requises) | `scheduledTime` | `frequencyMinutes` |
|---|---|---|---|
| `SCHEDULED` | heure exacte + source identifiable + provenance enregistrée + période de validité + calendrier actif + chaîne `route→trip→stop→stop_time→stop_sequence` cohérente | `HH:MM:SS` | `null` |
| `PARTIALLY_CONFIRMED` | corroborée (ex. grille Dakar 48 départs) mais chaîne incomplète pour chaque station | `HH:MM:SS` | `null` |
| `ESTIMATED` | fréquence documentée (`headway_min`) sans heure exacte démontrable | `null` | `10` / `20` / `6` |
| `UNKNOWN` | aucune des précédentes | `null` | `null` |
| `REAL_TIME` | `predictedDepartureAt` + `observedAt` frais (`≤ realtimeMaxAge`, défaut 5 min) + `route/trip/stop/direction/serviceDate` identifiés | `null` | `null` |
| `NO_DEPARTURE` | couverture explicitement complète mais aucun départ futur ce jour | — | — |

Interdits :

- Transformer `toutes les 10 min` en `10:00, 10:10…` ;
- Utiliser `0` comme valeur de secours (`minutesUntil` n'est `0` que pour un départ réellement maintenant) ;
- Considérer une interpolation GTFS comme du temps réel ;
- Réécrire `25:15:00 → 01:15:00`.

## 5. Résultats TER

### 5.1 Grille

- **Fréquences officielles** (`terdakar.sn/les_horaires_des_trains/`, 2026-03-30, `OFFICIAL_OPERATOR`) :
  - Semaine : 10 min (05:45→22:05, 20 min après 21:05) — `ESTIMATED`
  - Dimanche : 20 min (06:25→22:05) — `ESTIMATED`
- **48 départs dimanche corroborés** : `06:25, 06:45, 07:05, …, 22:05` (tous les 20 min). `passbi_found_in_official = 48/48`, `official_missing_from_passbi = []`, `passbi_only = 18:03, 19:50` exclus. Provenance : `ter_schedule.json` `sunday_reconciliation`.
- **624 `stop_times`** (48 trips × 13 gares) : 48 `PARTIALLY_CONFIRMED` (départ Dakar `stop_sequence=1`, `MEDIUM`, note « correspond à la fréquence officielle mais l'opérateur ne publie pas d'heure par station — ne peut être SCHEDULED ») et 576 `UNCONFIRMED` (`LOW`, « heure intermédiaire PassBi, non confirmée »).

### 5.2 Moteur — vérification

```js
engine = ScheduleEngine.fromRegistry(registry) // registry = schedule_registry.json
engine.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T06:20:00Z' })
→ { status:'PARTIALLY_CONFIRMED', scheduledTime:'06:25:00', minutesUntil:5 }

engine.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' })
→ { status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', minutesUntil:8 }

engine.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T22:10:00Z' })
→ { status:'ESTIMATED', frequencyMinutes:20 } // aucun départ exact futur ce jour
```

Les 48 ne sont **pas** promus en `SCHEDULED` : la chaîne `route→trip→stop→stop_time` est bien présente, mais la provenance n'est pas `OFFICIAL_OPERATOR` avec `schedule_status=scheduled` et `isValidScheduleFor` complet pour chaque station (l'opérateur ne publie pas d'heure par arrêt). Le moteur conserve donc `PARTIALLY_CONFIRMED` sans perdre l'information.

### 5.3 Stations

- 13 gares : Dakar, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR Rufisque, Rufisque, Bargny, Diamniadio.
- Intermédiaires (`stop_colobane` etc.) → `ESTIMATED` via fréquence (20) car `UNCONFIRMED` non exploitable en `nextDeparture` exact.

## 6. Résultats BRT

| Route | Fréquence documentée | Moteur | Note |
|---|---|---|---|
| **B1** (`brt_b1`) | 6 min (tous les jours) + renfort `Petersen↔Grand Médine` | `ESTIMATED`, `frequencyMinutes=6`, `scheduledTime=null` | Aucun `08:00, 08:06…` généré |
| **B2** (`brt_b2`) | 6 min (lun-sam) | `ESTIMATED`, `frequencyMinutes=6` | 7 stations, même ordre, distincte de B1 |
| **B3** (`brt_b3`) | aucune fréquence exploitable (7 stations officielles seules) | `UNKNOWN` | `NEW`, jamais rapprochée de B1/B2 |

Vérification :

```js
engine.nextDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' })
→ { status:'ESTIMATED', frequencyMinutes:6 }
```

Une station physique commune (7 partagées B1/B2) ne provoque **aucune fusion** des identités de lignes — le moteur filtre par `routeId` exact.

## 7. Résultats DDD

- **39 codes officiels** (`DDD 501, 1, 4… 213, 208` etc., `CONFIRMED`), structure `UNKNOWN`, horaire `UNKNOWN`, `HIGH`.
- **Aucun horaire exact** : `engine.nextDeparture({ routeId:'ddd_1', stopId:'stop_parcelles', … }) → UNKNOWN` avec raison `Aucune donnée horaire vérifiée pour la route ddd_1 (IDENTITY peut être CONFIRMED mais SCHEDULE = UNKNOWN)`.
- Règle respectée : `IDENTITY = CONFIRMED` + `SCHEDULE = UNKNOWN` est valide et testée.

## 8. Résultats AFTU

- **72 lignes officielles** (`AFTU 1-5 puis 24-89 et 91`, `CONFIRMED`), structure/horaire `UNKNOWN`.
- **73 PassBi** vs 72 officielles : `A90TD` (`NOT_FOUND`) reste `UNCONFIRMED`.
- **Aucun horaire exact** : `engine.nextDeparture({ routeId:'aftu_1', stopId:'stop_lat_dior', … }) → UNKNOWN`.

Ni le numéro, ni le terminus, ni la distance, ni `OSM`, ni une autre ligne n'ont servi à déduire une heure.

## 9. Traitement GTFS >24h

Convention conservée : `25:15:00` et `26:05:00` sont valides et **jamais** réécrites.

```js
ServiceTime.parse('25:15:00').toString() === '25:15:00' // pas '01:15:00'
ServiceTime.parse('25:15:00').toInstant(ServiceDate.parse('2026-09-27'))
→ 2026-09-28T01:15:00Z
ServiceTime.parse('25:15:00').secondsSinceServiceDayStart === 90900
ServiceTime.parse('25:15:00').civilDate(ServiceDate.parse('2026-09-27')) → 2026-09-28
```

`schedule_registry.json` : `gtfs_time_convention.times_rewritten = 0`, `example_over_24h = "25:15:00", example_valid = true`. Actuellement 0/624 `stop_times` ≥24:00, mais le moteur les comparerait correctement (test : `25:15` du service `2026-09-27` trouvé 5 min après `2026-09-28T01:10:00Z`).

## 10. Calendrier / exceptions

- **Service TER** : `TER_SUNDAY_AUDIT` `0,0,0,0,0,0,1` du `20260927` au `20260927` (dimanche uniquement). `isServiceActiveOn` vérifie jour de semaine, fenêtre `start_date`/`end_date` et exceptions `exception_type 1` (ajout) / `2` (retrait).
- **Exceptions** : `isServiceActiveOn({ monday:0,…, exceptions:[{date:'20260928',type:1}] }, 2026-09-28) → true`.
- **Scan multi-jours** : `ScheduleEngine` scanne `serviceDate` puis `+1…+MAX_DAYS_SCAN` (7 en JS, 3660 en Dart) pour trouver le prochain départ après minuit ou après un jour sans service. Exemple : 27/09 23:55 → 28/09 00:10 trouvé à `+15 min`.
- **Test** : service actif lundi trouvé, dimanche inactif scanne vers lundi (comportement Dart identique).

## 11. Cas SCHEDULED

**0** entrée dans le registre actuel.

Conditions non réunies pour TER/BRT/DDD/AFTU : l'opérateur publie des fréquences, pas d'heures par station avec les 6 preuves (source, provenance, validité, calendrier, chaîne cohérente). Le moteur ne promeut donc rien en `SCHEDULED`.

Démonstration synthétique (fixture, pas une donnée TER réelle) :

```js
engine = new ScheduleEngine(makeDataset(['08:20:00'])) // dataset synthétique avec provenance complète
engine.nextDeparture({ routeId:'test_route', stopId:'test_stop', serviceDate:'2026-09-28', now:'2026-09-28T08:17:00Z' })
→ { status:'SCHEDULED', scheduledTime:'08:20:00', minutesUntil:3 } // 🟢 Départ dans 3 min
engine.nextDeparture({ routeId:'test_route', stopId:'test_stop', serviceDate:'2026-09-28', now:'2026-09-28T08:17:00Z' }) // départ à 08:17
→ { status:'SCHEDULED', minutesUntil:0 } // Départ maintenant (0 uniquement si réel)
engine.nextDeparture({ serviceDate:'2026-09-28', now:'2026-09-28T08:15:00Z' }) // 08:10 passé
→ { status:'SCHEDULED', scheduledTime:'08:20:00' } // prochain après le passé
```

## 12. Cas PARTIALLY_CONFIRMED

**48** entrées : les départs Dakar `stop_dakar_ter` `stop_sequence=1` du registre.

- Source : PassBi historique corroborée par la fréquence officielle 20 min.
- Validité : `20260927-20260927` (`TER_SUNDAY_AUDIT`).
- Calendrier : actif ce dimanche.
- Chaîne : `ter_dakar_diamniadio → TER_SUN_xxx → stop_dakar_ter → stop_time 06:25…22:05` présente, mais `schedule_status = PARTIALLY_CONFIRMED` (pas `OFFICIAL_STATIC` complet pour chaque station).

Le moteur retourne `PARTIALLY_CONFIRMED` avec `scheduledTime` et `minutesUntil`, **sans la promouvoir** en `SCHEDULED`. Exemple §5.2.

## 13. Cas ESTIMATED

**4** fréquences :

| Route | `headway_min` | Source |
|---|---|---|
| `ter_dakar_diamniadio` `TER_WEEKDAY` | 10 (20 après 21:05) | `terdakar.sn` |
| `ter_dakar_diamniadio` `TER_SUNDAY` | 20 | `terdakar.sn` |
| `brt_b1` | 6 + renfort | `sunubrt.sn` |
| `brt_b2` | 6 | `sunubrt.sn` |

Le moteur retourne :

```js
{ status:'ESTIMATED', frequencyMinutes:10, scheduledTime:null, minutesUntil:null }
// 🟡 Passage estimé toutes les 10 min — jamais « Départ dans 7 min »
```

Vérifié : `f.scheduled_times` et `f.departure_times` absents, `verification_note` contient « ne … JAMAIS ».

## 14. Cas UNKNOWN

- **Défaut** : `routeId`/`stopId` vides → `UNKNOWN`.
- **Aucune donnée** : `unknown_route` → `UNKNOWN` (`Aucune donnée horaire vérifiée…`).
- **576 intermédiaires TER** `UNCONFIRMED` → le moteur les ignore en tant qu'exacts et retombe en `ESTIMATED` (fréquence) ou `UNKNOWN` si la route n'a pas de fréquence (B3).
- **DDD/AFTU** 111 routes sans horaire → `UNKNOWN`.
- `minutesUntil` reste `null` (jamais `0` par défaut).

## 15. Résultats des tests

```
$ npm test
# tests 100
# pass 100
# fail 0
```

| Suite | Tests | Couvre |
|---|---|---|
| `transit-data-layer.test.js` | 28 | Lot 4.4 (LEVEL 1-3, GTFS, route_status) |
| `transit-crosswalk.test.js` | 21 | Crosswalk 258, AFTU/DDD/BRT/TER, audit, cohérence |
| `transit-schedule.test.js` | 10 | Référentiel public 115, fréquences vs horaires, >24h |
| `schedule-engine.test.js` | **17** | **Exact, immédiat, passé, ESTIMATED, UNKNOWN, >24h, changement de jour, calendrier, TER 48, BRT 6 min, DDD/AFTU UNKNOWN, REAL_TIME frais/périmé** |
| `transit-validation.test.js` | 24 | Transit-data-layer + production_ready (existants) |
| **Total** | **100** | |

Détail moteur (17) :

| # | Test | Résultat |
|---|---|---|
| 1 | Exact 08:17 → 08:20 = 3 min | `SCHEDULED` 3 min |
| 2 | Départ immédiat 08:17 → 0 min | `SCHEDULED` 0 |
| 3 | Départ passé 08:10 → 08:20 | `SCHEDULED` 5 min |
| 4 | Aucun exact + fréquence 10 min → `ESTIMATED` | `ESTIMATED` 10 |
| 5 | Aucune donnée → `UNKNOWN` | `UNKNOWN` |
| 6 | Jamais 0 par défaut | `null` |
| 7 | GTFS 25:15 → lendemain 01:15 (5 min) | `SCHEDULED` 5 |
| 8 | >24h conservé `25:15` ≠ `01:15` | `25:15` |
| 9 | Changement de jour 23:55 → 00:10 (15 min) | `SCHEDULED` 15 |
| 10 | Calendrier lundi actif, dimanche scanné vers lundi | `SCHEDULED` |
| 11 | Exception ajout/retrait | `true`/`false` |
| 12 | TER 48 `PARTIALLY_CONFIRMED` (06:25, 08:25, après 22:05 → ESTIMATED 20) | `PARTIALLY_CONFIRMED` |
| 13 | TER 576 `UNCONFIRMED` → `ESTIMATED` 20 | `ESTIMATED` |
| 14 | BRT 6 min → `ESTIMATED`, B3 `UNKNOWN` | `ESTIMATED`/`UNKNOWN` |
| 15 | DDD `UNKNOWN` | `UNKNOWN` |
| 16 | AFTU `UNKNOWN` | `UNKNOWN` |
| 17 | `REAL_TIME` frais 3 min, périmé → `ESTIMATED` | `REAL_TIME`/`ESTIMATED` |

## 16. Limites restantes

| Limite | Détail | Impact |
|---|---|---|
| **Aucun `SCHEDULED` réel** | 0/624, l'opérateur ne publie pas d'heure par station | Aucun `Départ dans X min` exact n'est affichable en production |
| **Aucun `REAL_TIME`** | 0 prédiction, `realtimeMaxAge` 5 min, PassBi `NOT_REAL_TIME` | Aucune `Arrivée dans 3 min` temps réel |
| **Fenêtre TER unique** | `20260927` seul jour validé | Grille non généralisable au-delà du dimanche audité |
| **BRT sans grille** | 6 min seulement | Pas de départ par arrêt |
| **DDD/AFTU sans horaire** | 111 routes `UNKNOWN` | Identité confirmée mais pas d'horaire |
| **GTFS >24h non observé** | 0/624 actuellement | Support codé, non exercé en prod |
| **Republication `BLOCKED`** | Aucune licence PassBi | Données non redistribuables hors dépôt |
| **Provenance non `OFFICIAL_STATIC` complète** | `schedule_status` TER = `PARTIALLY_CONFIRMED` | Le Dart `ScheduleProvenance.isValidScheduleFor` retournerait `false` pour `SCHEDULED` |

Le moteur est prêt à passer à `SCHEDULED` dès qu'une source `OFFICIAL_STATIC` avec les 6 conditions sera fournie — sans changement de code.

## 17. Prochaines étapes

1. **Obtenir une source `OFFICIAL_STATIC` avec heures par station** (TER/BRT) et l'ingérer en `validated/gtfs` avec `valid_from`/`valid_to` et `ScheduleProvenance` `scheduled`.
2. **Brancher un flux `REAL_TIME`** (`vehicle_id`, `trip_id`, `stop_id`, `predictedDepartureAt`, `observedAt`) et alimenter `realtimePredictions` avec `realtimeMaxAge` contrôlé.
3. **Étendre le calendrier** au-delà du 20260927 et publier `calendar_dates.txt` avec exceptions.
4. **Publier `public_routes.json` + `schedule_registry.json`** vers `ScheduleProvider` Dart (actuellement `EmptyScheduleProvider`) après revue.
5. **Ajouter des tests d'intégration** avec un `FixedClock` sur la grille réelle une fois `SCHEDULED` disponible.

---

### Contrôles finaux obligatoires (annexe)

```bash
$ npm test
# tests 100
# pass 100
# fail 0

$ git diff -- flutter-src/lib/main.dart
0 lignes

$ git diff -- flutter-src/assets/data/dakar_network.json
0 lignes

$ git diff -- data/gtfs/
0 lignes
```

| Vérification | Résultat |
|---|---|
| Prix/tarif/FCFA introduit | **non** — `grep -r` 0 occurrence dans `data/transit/engine/` et `schedule_registry.json` |
| Temps réel fictif créé | **non** — `REAL_TIME` 0, `realtimePredictions` vide en prod |
| Horaire exact généré depuis fréquence | **non** — `ESTIMATED` n'a ni `trip_id` ni `scheduledTime` |
| `main.dart` modifié | **NON** |
| `dakar_network.json` modifié | **NON** |
| `data/gtfs/` modifié | **NON** |
| `UI` modifiée | **NON** |
| `GPS` modifié | **NON** |
| `routage` modifié | **NON** |

**LOT 4.6 — COMPLETE**

- Fichiers créés : 3 (`data/transit/engine/clock.js`, `gtfs_time.js`, `schedule_engine.js`) + 1 test (`tests/schedule-engine.test.js` 17 tests) + 1 rapport (`docs/DAKAR_BUS_HORAIRE_ENGINE_4_6.md`)
- Fichiers modifiés : 0 (hors rapports et registres 4.5)
- Fichiers supprimés : 0
- Tests : 100 (83 existants + 17 moteur) — 100/100 PASS
- `SCHEDULED` : **0** (0/624, aucune grille exacte officielle complète)
- `PARTIALLY_CONFIRMED` : **48** (départs Dakar dimanche)
- `ESTIMATED` : **4** fréquences (TER 10/20, BRT 6/6)
- `UNCONFIRMED` : **576** (intermédiaires TER)
- `UNKNOWN` : 111 routes AFTU/DDD sans horaire + B3
- `REAL_TIME` : **0**
- TER : 48 `PARTIALLY_CONFIRMED` / 576 `UNCONFIRMED` / 2 seules fréquences `ESTIMATED`
- BRT : 6 min `ESTIMATED`, 0 faux départ
- DDD : `IDENTITY CONFIRMED` (39) / `SCHEDULE UNKNOWN` (39)
- AFTU : `IDENTITY CONFIRMED` (72) / `SCHEDULE UNKNOWN` (72)
- `main.dart` modifié : **NON**
- `dakar_network.json` modifié : **NON**
- `data/gtfs` modifié : **NON**
- `UI` modifiée : **NON**
- `GPS` modifié : **NON**
- `routage` modifié : **NON**

> Aucun commit, push ou merge n'a été effectué — en attente de validation explicite.
