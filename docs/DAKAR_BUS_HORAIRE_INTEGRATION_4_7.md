# Dakar Bus — Intégration Contrôlée du Moteur Horaire — Lot 4.7

**Lot : 4.7 — Intégration contrôlée du moteur horaire (DATA LAYER UNIQUEMENT)**
**Date : 2026-09-27**
**Nature : DATA LAYER / ENGINE → JONCTION → CONTRAT FLUTTER (sans UI/GPS/RoutePlanner)**
**Statut : COMPLETE**
**Base : commit 9f4f916 (main) + Lots 4.4 / 4.5 / 4.6 — Branche arena/01a0df09-dakar-bus**

---

## 1. Objectif et périmètre

Intégrer, sans modifier l'UI, le moteur horaire pur déterministe du Lot 4.6 comme source de vérité horaire du data layer, en respectant :

- **Point d'entrée unique** : `nextDeparture(routeId, stopId, serviceDate, now)` avec horloge injectable (jamais `Date.now()` / `DateTime.now()` dans la logique métier).
- **Lecture seule** des registres horaires : `data/transit/validated/schedule_registry.json` et `public_routes.json` ne sont jamais réécrits.
- **Interdits absolus** (vérifiés `git diff`) : `flutter-src/lib/main.dart` 0, `flutter-src/assets/data/dakar_network.json` 0, `data/gtfs/` 0, pas de GPS/UI/Navigation/RoutePlanner/routage/intermodalité/cartographie/MarkerLayer/PolylineLayer, pas de prix/tarif/FCFA/publicité, pas de temps réel fictif, pas d'horaires inventés, pas de recalcul TER intermédiaires, pas de conversion fréquence BRT en heures exactes, pas de promotion `UNCONFIRMED`→`SCHEDULED`, pas de trips-stop_times créés, pas de réécriture GTFS >24h.
- **Règle d'une donnée inconnue = `UNKNOWN`** — jamais approximée par une fréquence.

Le futur Flutter consommera le contrat via `ScheduleProvider → ScheduleEngine → DepartureInfo → DataProvider/DataService` sans duplication de logique horaire.

## 2. Principe — moteur pur, horloge injectable

```
schedule_registry.json / public_routes.json  (lecture seule, Lot 4.5)
        |
ScheduleProvider (EmptyScheduleProvider par défaut, InMemoryScheduleProvider en tests)
        |
ScheduleEngine (pur, déterministe, sans GPS/UI/Flutter — Lot 4.6)
        |  nextDeparture({routeId, stopId, directionId?, serviceDate, now})
RealtimeProvider (EmptyRealtimeProvider → 0 REAL_TIME)  →  FrequencyProvider (ESTIMATED seul repli)
        |
DepartureInfo / DepartureSearchResult  (contrat Flutter)
        |
DataProvider / DataService  (frequencyProvider + scheduleProvider + realtimeProvider + Clock)
        |
future UI (non modifiée en 4.7)
```

- `Clock` : `SystemClock` (UTC) en prod, `FixedClock('2026-09-27T08:17:00Z')` en tests.
- `nextDeparture` n'appelle aucune horloge interne ; l'instant `now` est UTC explicite. Un `now` non-UTC → `UNKNOWN`.
- `ScheduleEngine.fromRegistry(schedule_registry)` injecte le registre ; aucun fichier n'est lu pendant `nextDeparture`.

## 3. Fichiers analysés (audit préalable 2026-09-27)

| Chemin | Taille | Contenu exploité en 4.7 |
|---|---|---|
| `data/transit/engine/clock.js` | 962 o | `SystemClock` / `FixedClock` — horloge injectable |
| `data/transit/engine/gtfs_time.js` | 4.0 K | `ServiceDate` / `ServiceTime` (>24h conservé `25:15` → `01:15` lendemain) |
| `data/transit/engine/schedule_engine.js` | 17 K (347 l.) | `ScheduleEngine.fromRegistry`, `nextDeparture`, `realtimeMaxAge=5min`, `MAX_DAYS_SCAN=7` |
| `data/transit/engine/integration.js` | **nouveau (Lot 4.7)** | `loadRegistry` (lecture seule) → `toContract` → `queryDeparture` (adaptateur contrat) |
| `data/transit/validated/schedule_registry.json` | 513 K (Lot 4.5) | **Lu uniquement** : 4 fréquences `ESTIMATED` + 624 `stop_times` (48 `PARTIALLY_CONFIRMED` / 576 `UNCONFIRMED`, 0 `SCHEDULED`, `times_rewritten=0`) |
| `data/transit/validated/public_routes.json` | 224 K | 115 routes (`TER 1` / `BRT 3` / `DDD 39` / `AFTU 72`) — identité horaire séparée |
| `data/transit/validated/route_status.json` | 41 K | Statuts par route |
| `data/transit/crosswalk/*.json` | 408 K + aftu 239K / brt 46K / ddd 126K / ter 32K | Corroboration des chaînes route→trip→stop |
| `flutter-src/lib/services/data_provider.dart` | 227 l. | `FrequencyProvider` (B1/B2 6min, TER 10/20min) + `DataProvider` alias |
| `flutter-src/lib/services/data_service.dart` | 298 l. | `DataService` (FrequencyProvider + ScheduleProvider Empty + RealtimeProvider Empty + Clock) — `nextDepartureFor` → `ScheduleEngine` |
| `flutter-src/lib/services/schedule_provider.dart` | 25 l. | `EmptyScheduleProvider` (prod, dataset null) / `InMemoryScheduleProvider` (tests) |
| `flutter-src/lib/services/schedule_service.dart` | 466 l. | `ScheduleEngine` Dart (`_maxCalendarDaysToScan=3660`, même discriminant) |
| `flutter-src/lib/services/clock.dart` | — | `Clock` / `SystemClock` / `FixedClock` — même sémantique que `clock.js` |
| `flutter-src/lib/services/realtime_provider.dart` | — | `EmptyRealtimeProvider` (0) |
| `flutter-src/lib/models/departure_info.dart` | 468 l. | `DepartureInfo` / `FrequencyWindow` / `FrequencySource` — contrat sortie cible |
| `flutter-src/lib/models/schedule_models.dart` | — | `ServiceDate`, `ServiceTime` (>24h), `ScheduleDataset` |
| `data/gtfs/` | feed `2.1-dakar-pwa-gtfs-rt` | **Non touché** — `git diff -- data/gtfs` = 0 |
| `flutter-src/lib/main.dart` | — | **Non touché** — `git diff` = 0 |
| `flutter-src/assets/data/dakar_network.json` | 105 routes | **Non touché** — `git diff` = 0 |

Tous les fichiers ont été listés (`ls -R`), lus et mesurés avant écriture — chiffres ci-dessus issus d'outils, non estimés.

## 4. Architecture d'intégration (Lot 4.7)

### 4.1 Couche JS (`data/transit/engine/integration.js`)

```js
const { queryDeparture, createEngineFromRegistry, toContract, loadRegistry } = require('./integration');

queryDeparture({
  routeId: 'ter_dakar_diamniadio',
  stopId: 'stop_dakar_ter',
  serviceDate: '2026-09-27',
  now: new Date('2026-09-27T08:17:00Z')
});
// → { status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', nextDepartureAt:'2026-09-27T08:25:00.000Z', ... }
```

Rôle : adaptateur fin entre `ScheduleEngine` (Lot 4.6) et le contrat Flutter, sans introduire de logique horaire parallèle.

### 4.2 Couche Dart (déjà câblée en Lot 4.6, vérifiée en 4.7)

`DataService.nextDepartureFor({routeId, stopId, directionId?, serviceDate, now})` instancie `ScheduleEngine(dataset: _scheduleProvider.dataset, frequencyProvider: ..., realtimePredictions: ..., realtimeMaxAge: ...).nextDepartureFor(...)`. Le moteur Dart et le moteur JS partagent : même discriminant, même validation `now.isUtc`, même scan multi-jours (7 en JS / 3660 en Dart), même gestion `>24h`.

### 4.3 Flux de décision (priorité stricte)

```
Realtime frais (predictedDepartureAt + observedAt ≤ 5min) ? → REAL_TIME
  sinon départ exact PARTIALLY_CONFIRMED/SCHEDULED futur actif ce service ? → ce statut (jamais promu)
    sinon fréquence ESTIMATED documentée pour la route ? → ESTIMATED (scheduledTime/nextDepartureAt = null)
      sinon UNKNOWN (ou NO_DEPARTURE si couverture explicitement complète sans départ futur)
```

## 5. Contrat d'entrée

```ts
nextDeparture({
  routeId: string,          // ex. 'ter_dakar_diamniadio' | 'brt_b1' | 'ddd_1' | 'aftu_1'
  stopId: string,           // ex. 'stop_dakar_ter' | 'any_stop' (BRT repli)
  directionId?: number,     // null ou ≥0, invalide → UNKNOWN
  serviceDate: 'YYYY-MM-DD',// ServiceDate GTFS (ex. '2026-09-27')
  now: Date                 // instant UTC explicite — jamais DateTime local
})
```

Invariants vérifiés par les tests :
- `routeId`/`stopId` vides → `UNKNOWN`.
- `directionId < 0` → `UNKNOWN`.
- `now` non-UTC → `UNKNOWN` (Dart : `!now.isUtc`).

## 6. Contrat de sortie

Tout résultat — JS ou Dart — respecte le même contrat (sérialisable Flutter) :

| Champ | Type | Règle |
|---|---|---|
| `status` | `SCHEDULED` \| `REAL_TIME` \| `ESTIMATED` \| `PARTIALLY_CONFIRMED` \| `UNKNOWN` \| `NO_DEPARTURE` | Discriminant |
| `routeId` | string | Requête d'origine |
| `stopId` | string | Requête d'origine |
| `serviceDate` | `YYYY-MM-DD` | Requête d'origine |
| `scheduledTime` | `HH:MM:SS` \| null | Renseigné uniquement pour `SCHEDULED`/`PARTIALLY_CONFIRMED`/`REAL_TIME`; **jamais** pour `ESTIMATED`/`UNKNOWN` |
| `nextDepartureAt` | ISO-8601 UTC \| null | Instant du départ exact ; **null** pour `ESTIMATED` |
| `frequencyMinutes` | number \| null | Renseigné uniquement pour `ESTIMATED` (6 / 10 / 20) |
| `source` | string \| null | URL ou identifiant de source (ex. `terdakar.sn`) si exploitable |
| `sourceType` | `OFFICIAL_OPERATOR` \| `PASSBI` \| null | Traçabilité |
| `confidence` | `HIGH` \| `MEDIUM` \| `LOW` \| null | Niveau corroboré |
| `verificationNote` | string \| null | Raison / règle appliquée (ex. « ne peut être SCHEDULED ») |
| `minutesUntil` | number \| null | `Math.floor(diff/60000)` — 0 uniquement pour départ maintenant |
| `secondsUntil` | number \| null | Pour affichage fin |
| `displayLabel` | string | `Départ dans 3 min` / `Départ maintenant` / `Passage estimé toutes les 6 min` / `Horaire indisponible` (UI future, non rendue en 4.7) |
| `departures` | DepartureInfo[] \| null | Liste des trips coïncidents (cas SCHEDULED/PARTIALLY_CONFIRMED multi-trips) |

Garanties :
- `ESTIMATED` → `scheduledTime === null && nextDepartureAt === null && frequencyMinutes !== null`.
- `UNKNOWN` → `scheduledTime === null && nextDepartureAt === null && minutesUntil === null` (jamais `0` par défaut).
- Le registre source (`schedule_registry.json`) n'est **jamais** réécrit par `queryDeparture` (test non-régression).

## 7. Règles de promotion

### 7.1 SCHEDULED — les 6 conditions (toutes requises)

1. Heure exacte publiée (`arrival_time`/`departure_time` `HH:MM:SS`, y compris `>24:00`).
2. Source identifiable (ex. `terdakar.sn`, `sunubrt.sn`, GTFS opérateur avec URL).
3. Provenance exploitable (`source_type`, `source_url`, `date_verified`, `verification_note` / `provenance` Dart).
4. Validité temporelle (`valid_from`/`valid_to` ou `validFrom`/`validTo` couvrant `serviceDate`).
5. Calendrier actif (`calendar.txt` / `ScheduleServiceCalendar` : jour de semaine + fenêtre `start_date`→`end_date` + `calendar_dates.txt` exceptions `type 1`/`2`).
6. Chaîne `route → trip → stop_time → stop_sequence` cohérente pour la paire `(routeId, stopId)`.

Si **une** condition manque → `NOT SCHEDULED`. Le Lot 4.7 n'a **aucun** `SCHEDULED` : TER/BRT/DDD/AFTU ne réunissent pas les 6.

### 7.2 REAL_TIME

Uniquement si `routeId/tripId/stopId/stopSequence/directionId/serviceDate + predictedDepartureAt + observedAt` présents **et** `now - observedAt ≤ realtimeMaxAge` (défaut 5 min) **et** `source` traçable. Actuellement **0** en prod (`stats.realtime_entries=0`, `by_realtime_status.REAL_TIME=0`).

### 7.3 ESTIMATED

Uniquement pour une fréquence documentée (`headway_min`) :
- TER `TER_WEEKDAY` 10 min (semaine, 20 min après 21:05) — `terdakar.sn`.
- TER `TER_SUNDAY` 20 min (dimanche/jour férié 06:25→22:05).
- BRT `B1` 6 min (tous les jours) + renfort documenté — `sunubrt.sn`.
- BRT `B2` 6 min (lun-sam, 7 stations).

Jamais `08:00, 08:06…` généré — affichage : `Passage estimé toutes les 6 min`.

### 7.4 PARTIALLY_CONFIRMED

**48** départs `stop_dakar_ter` `stop_sequence=1` dimanche (`06:25, 06:45 … 22:05` toutes les 20 min) : corroborés par la fréquence officielle 20 min **et** conservés caractère pour caractère depuis PassBi, mais l'opérateur ne publie **pas** d'heure par station — ne peuvent donc pas être `SCHEDULED`. Le moteur conserve `PARTIALLY_CONFIRMED` avec `scheduledTime` + `nextDepartureAt` + `minutesUntil`, sans promotion.

### 7.5 UNKNOWN

576 intermédiaires `UNCONFIRMED` (`LOW` — heure PassBi non confirmée) → ignorés comme exacts ; repli `ESTIMATED` via fréquence (20) si la route en a. 111 routes `DDD 39 + AFTU 72` et `B3` (aucune fréquence exploitable) → `UNKNOWN` sec. `routeId`/`stopId` vides ou absents du réseau → `UNKNOWN`.

## 8. Résultats TER

### 8.1 Grille (source : `terdakar.sn/les_horaires_des_trains/`, `OFFICIAL_OPERATOR`, `date_verified 2026-09-27`)

- Semaine : 10 min `05:45/05:35 → 20:55`, 20 min `21:05 → 22:05` (dernier).
- Dimanche / férié : 20 min `06:25 → 22:05` (48 départs).
- Fenêtre d'audit actuelle : `20260927` seul jour validé (`TER_SUNDAY_AUDIT` `0,0,0,0,0,0,1`).

### 8.2 Vérifications `queryDeparture`

```js
queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' })
→ { status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', nextDepartureAt:'2026-09-27T08:25:00.000Z' } // 8 min après 08:17

queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T06:20:00Z' })
→ { status:'PARTIALLY_CONFIRMED', scheduledTime:'06:25:00' } // premier

queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T22:00:00Z' })
→ { status:'PARTIALLY_CONFIRMED', scheduledTime:'22:05:00' } // dernier

queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T22:10:00Z' })
→ { status:'ESTIMATED', frequencyMinutes:20, scheduledTime:null } // aucun départ exact futur ce jour — pas de 22:25 fictif

queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_colobane', serviceDate:'2026-09-27', now:'2026-09-27T06:20:00Z' })
→ { status:'ESTIMATED', frequencyMinutes:20 } // intermédiaires UNCONFIRMED → repli fréquence

queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-28', now:'2026-09-28T08:17:00Z' })
→ { status:'ESTIMATED', frequencyMinutes:10 } // lundi hors fenêtre 20260927 → fréquence semaine
```

### 8.3 Stations

13 gares : Dakar, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR Rufisque, Rufisque, Bargny, Diamniadio.

## 9. Résultats BRT

| Route | Fréquence documentée | queryDeparture | Note |
|---|---|---|---|
| **B1** `brt_b1` | 6 min tous les jours + renfort Petersen↔Grand Médine | `ESTIMATED`, `frequencyMinutes=6`, `scheduledTime=null` | Aucun `08:00, 08:06…` |
| **B2** `brt_b2` | 6 min lun-sam, 7 stations (`sunubrt.sn/brt-3-semi-express/`) | `ESTIMATED`, `frequencyMinutes=6` | Distincte de B1 (pas de fusion) |
| **B3** `brt_b3` | aucune fréquence exploitable — 7 stations officielles seules, depuis 10/2025 | `UNKNOWN` | `NEW`, jamais rapprochée de B1/B2 |

```js
queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' }) → ESTIMATED 6
queryDeparture({ routeId:'brt_b3', stopId:'any',        serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' }) → UNKNOWN
```

## 10. Résultats DDD / AFTU

```js
queryDeparture({ routeId:'ddd_1',  stopId:'any', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' }) → UNKNOWN
queryDeparture({ routeId:'aftu_1', stopId:'any', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z' }) → UNKNOWN
```

- DDD : 39 codes officiels — `IDENTITY=CONFIRMED`, `STRUCTURE=UNKNOWN`, `SCHEDULE=UNKNOWN`.
- AFTU : 72 lignes officielles (1-5, 24-89, 91) — `NOT_FOUND A90TD`, structure/horaire `UNKNOWN`.
- Règle respectée : `IDENTITY CONFIRMED` n'implique jamais `SCHEDULE CONFIRMED`.

## 11. Cas REAL_TIME

- **Prod : 0** — `stats.realtime_entries=0`, `by_realtime_status.REAL_TIME=0`, `NO_REAL_TIME_FEED`.
- **Test frais** : `predictedDepartureAt = now+3min`, `observedAt = now-1min` → `REAL_TIME`, `minutesUntil=3`, `displayLabel='Arrivée dans 3 min'`.
- **Test périmé** : `observedAt = now-10min` (>5min) → `ESTIMATED` (ou `UNKNOWN` si pas de fréquence), **sans** fausse donnée temps réel.
- `realtimeMaxAge` injectable (JS : 5min, Dart : `Duration`).

## 12. GTFS >24h et calendrier

- **Convention conservée** : `ServiceTime.parse('25:15:00').toString() === '25:15:00'` (jamais `01:15:00`), `times_rewritten=0`, `example_over_24h='25:15:00'`.
- `ServiceTime('25:15:00').toInstant(ServiceDate('2026-09-27')) → 2026-09-28T01:15:00Z`, 5 min après `01:10`.
- **Calendrier** : `TER_SUNDAY_AUDIT` dimanche seul ; `isServiceActiveOn` vérifie jour + `start_date`/`end_date` + `exceptions` (`type 1`=ajout, `type 2`=retrait). Exception `20260928 type 1` → lundi actif.
- **Scan** : JS `MAX_DAYS_SCAN=7` (suffisant pour fenêtre actuelle), Dart `3660` — trouve `lundi 00:10` depuis `dimanche 23:55` (15 min).

## 13. Countdown et libellés

| Scénario | `minutesUntil` | `displayLabel` (concept, non rendu en 4.7) |
|---|---|---|
| TER exact `08:17 → 08:20` (fixture SCHEDULED) | `3` | `Départ dans 3 min` |
| TER exact `08:17 → 08:25` (PARTIALLY_CONFIRMED réel) | `8` | `Départ dans 8 min` |
| Départ maintenant `08:20` à `08:20` | `0` | `Départ maintenant` (ou `Arrivée imminente` pour REAL_TIME) |
| Après `22:10` (ESTIMATED) | `null` | `Passage estimé toutes les 20 min` |
| UNKNOWN (`unknown_route`) | `null` | `Horaire indisponible` — jamais `Départ dans 0 min` par approximation |

Garantie : `UNKNOWN` ≠ `0 min`. Le `0` n'est émis que pour un `nextDepartureAt` réel démontrable.

## 14. Non-régression, garde-fous et contrôles d'intégrité

### 14.1 Tests

```
$ npm test
# tests 121
# pass 121
# fail 0
```

| Suite | Tests | Couvre |
|---|---|---|
| `transit-data-layer.test.js` | 28 | Lot 4.4 (LEVEL 1-3, GTFS, route_status) |
| `transit-crosswalk.test.js` | 21 | Crosswalk 258, AFTU/DDD/BRT/TER |
| `transit-schedule.test.js` | 10 | Référentiel 115, fréquences vs horaires, >24h |
| `schedule-engine.test.js` | 17 | **Moteur pur (Lot 4.6)** |
| `horaire-integration.test.js` | **21** | **Lot 4.7 : contrat, TER 6 cas, BRT 4, DDD/AFTU 2, REAL_TIME 3, countdown/>24h/non-régression 4** |
| `transit-validation.test.js` | 24 | Transit-data-layer + production_ready |
| **Total** | **121** | 100 existants conservés + 21 ajoutés — **0 supprimé** |

Détail `horaire-integration` (21) :

| # | Test | Attendu |
|---|---|---|
| 1 | Contrat — structure minimale | 11 champs |
| 2 | ESTIMATED → null scheduledTime/nextDepartureAt | `frequencyMinutes=6` |
| 3 | TER 08:17→08:25 | `PARTIALLY_CONFIRMED` |
| 4 | TER 06:25 premier | `PARTIALLY_CONFIRMED` |
| 5 | TER 22:05 dernier | `PARTIALLY_CONFIRMED` |
| 6 | TER après 22:05 | `ESTIMATED 20` |
| 7 | TER dimanche actif / lundi → ESTIMATED semaine | `ESTIMATED 10` |
| 8 | TER intermédiaire | `ESTIMATED 20` |
| 9 | BRT B1 | `ESTIMATED 6` |
| 10 | BRT B2 | `ESTIMATED 6` |
| 11 | BRT B3 | `UNKNOWN` |
| 12 | BRT aucun faux départ exact | `ESTIMATED` (B1) |
| 13 | DDD ddd_1 | `UNKNOWN` |
| 14 | AFTU aftu_1 | `UNKNOWN` |
| 15 | REAL_TIME impossible (0) | `≠ REAL_TIME` |
| 16 | REAL_TIME frais 3 min / périmé → ESTIMATED | `REAL_TIME 3` / `ESTIMATED` |
| 17 | Countdown 08:17→08:20 = 3 min | `3` |
| 18 | Départ maintenant 08:20 | `0` + label |
| 19 | Jamais 0 par approximation | `≠ 'Départ dans 0 min'` |
| 20 | GTFS >24h conservé | `25:15` + `0` réécrit |
| 21 | Non-régression : registre non réécrit | `before === after` |

### 14.2 Zones protégées

```
$ git diff --stat HEAD -- flutter-src/lib/main.dart flutter-src/assets/data/dakar_network.json data/gtfs
  (vide — 0 modifié)
$ git diff --stat HEAD                      # seules couches engine/data layer
 flutter-src/lib/models/departure_info.dart     | 409 +++---
 flutter-src/lib/models/reliability.dart        |  13 +-
 flutter-src/lib/services/data_provider.dart    |  59 +-
 flutter-src/lib/services/data_service.dart     | 118 +-
 flutter-src/test/ui_data_reliability_test.dart |  82 +-
 5 files changed, 560 insertions(+), 121 deletions(-)
```

- `main.dart` : **0** modification.
- `dakar_network.json` : **0** modification.
- `data/gtfs/` : **0** modification.
- `schedule_registry.json` / `public_routes.json` : **lus** par `integration.js` (test `14.1#21` vérifie `before === after`).

### 14.3 Garde-fous textuels

```
$ grep -Rina "prix|tarif|FCFA" flutter-src data/transit --include="*.dart" --include="*.js" --include="*.json"
  (vide — 0)
$ grep -Rina "fake.*gps|gps.*simul|temps.*réel.*fictif" data/transit
  (vide — 0)
```

Aucun horaire `08:00, 08:06…` généré depuis une fréquence — `grep -R "scheduled_times\|departure_times"` absent des `frequencies`.

## 15. Livrables, limites et suite

### 15.1 Livrables Lot 4.7

- **Engine** : `data/transit/engine/{clock.js, gtfs_time.js, schedule_engine.js}` (Lot 4.6) + **nouveau** `integration.js` (Lot 4.7 — adaptateur contrat, lecture seule).
- **Tests** : `tests/horaire-integration.test.js` (21 tests d'intégration TER/BRT/DDD/AFTU/REAL_TIME/countdown/>24h).
- **Doc** : `docs/DAKAR_BUS_HORAIRE_INTEGRATION_4_7.md` (ce fichier — 15 sections + tableau final).
- **Dart** : câblage déjà présent via `DataService.nextDepartureFor` / `ScheduleEngine` Dart (vérifié, 0 duplication de règle horaire).

### 15.2 Limites restantes

| Limite | Détail | Impact |
|---|---|---|
| Aucun `SCHEDULED` réel | 0/624 — opérateur = fréquences, pas heures par station | Aucun `Départ dans X min` SCHEDULED affichable en prod (seulement PARTIALLY_CONFIRMED) |
| Aucun `REAL_TIME` | 0 prédiction — PassBi `NOT_REAL_TIME` | Pas d'`Arrivée dans 3 min` temps réel |
| Fenêtre TER unique | `20260927` seul jour validé | Grille non généralisable au-delà du dimanche audité |
| BRT sans grille | 6 min seules | Pas de départ par arrêt |
| DDD/AFTU sans horaire | 111 routes UNKNOWN | Identité confirmée, pas d'horaire |
| GTFS >24h non observé | 0/624 actuellement | Support codé, non exercé en prod |
| Republication BLOCKED | Pas de licence PassBi | Données non redistribuables hors dépôt |
| `EmptyScheduleProvider` prod | `dataset=null` tant qu'aucun dataset sourcé n'est fourni | Dart retombe en `ESTIMATED`/`UNKNOWN` (comportement attendu) |

### 15.3 Tableau final — comptes horaires vérifiés (Lot 4.7)

> Chiffres issus du registre réel `schedule_registry.json` (`jq '.stats'`) et de `public_routes.json` — mesurés, non arrondis. Un même trajet le dimanche est compté une fois en `PARTIALLY_CONFIRMED` (départ Dakar) et 12 fois en `UNCONFIRMED` (intermédiaires non promus).

| # | Statut / Catégorie | Registre (schedule_registry) | Moteur — `queryDeparture` 08:17 Dakar 27/09/2026 | Source |
|---|---|---|---|---|
| 1 | **SCHEDULED** | **0** / 624 `stop_times` | Aucun — aucune route ne réunit les 6 conditions | `schedule_registry.json` `by_schedule_status.SCHEDULED=0` |
| 2 | **PARTIALLY_CONFIRMED** | **48** / 624 (`stop_dakar_ter` `seq=1`, `06:25→22:05` toutes les 20 min) | TER Dakar `08:17→08:25` → `PARTIALLY_CONFIRMED` (`scheduledTime=08:25:00`) — non promu `SCHEDULED` | `terdakar.sn` + PassBi `48/48` |
| 3 | **ESTIMATED (fréquences)** | **4** fréquences `ESTIMATED` (`TER_WEEKDAY 10/20` + `TER_SUNDAY 20` + `B1 6` + `B2 6`) ; **576** intermédiaires `UNCONFIRMED` repliés via fréquence | TER intermédiaire `stop_colobane 06:20` → `ESTIMATED 20`; BRT `B1`/`B2` any_stop → `ESTIMATED 6` | `terdakar.sn` · `sunubrt.sn` |
| 4 | **UNKNOWN (routes sans horaire)** | **111** routes `DDD 39 + AFTU 72` sans horaire ; `B3` (7 stations, `NEW`) sans fréquence | `ddd_1` → `UNKNOWN` ; `aftu_1` → `UNKNOWN` ; `brt_b3` → `UNKNOWN` | `public_routes.json` 115 |
| 5 | **REAL_TIME** | **0** prédiction ; `realtime_entries=0` | `0` en prod ; test frais `now-1min→now+3min` → `REAL_TIME 3 min` ; périmé `now-10min` → `ESTIMATED` | `schedule_registry.json` `NO_REAL_TIME_FEED` |
| 6 | **NO_DEPARTURE / fin de service** | Couverture complète dimanche jusqu'à `22:05` | TER Dakar `22:10` → plus de départ exact ce jour → `ESTIMATED 20` (pas de 22:25 fictif) | Moteur `nextDeparture` |

### 15.4 Suite recommandée

1. Fournir un `ScheduleDataset` sourcé `OFFICIAL_STATIC` avec les 6 preuves pour promouvoir `PARTIALLY_CONFIRMED → SCHEDULED` (sans changer le moteur).
2. Brancher un `RealtimeProvider` (GTFS-RT frais) → `REAL_TIME` frais, sans modifier l'UI.
3. Étendre la fenêtre `ScheduleRegistry` au-delà du `20260927` (tournées semaine) — actuellement seul le dimanche est audité.
4. Câbler `DataService(scheduleProvider: InMemoryScheduleProvider(dataset))` dans l'arbre Flutter prod (feature flag) — UI Inchangée, data layer seul concerné.
5. Conserver `ScheduleProvider Empty` par défaut en prod tant que la source n'est pas publiée — principe `UNKNOWN` > approximation.

---

## Annexe — commandes de vérification (Lot 4.7)

```bash
npm test                          # 121 PASS / 0 FAIL (100 existants + 21 Lot 4.7)
git diff --stat HEAD -- flutter-src/lib/main.dart flutter-src/assets/data/dakar_network.json data/gtfs
                                  # (vide) — 3 zones protégées 0
grep -Rina "prix|tarif|FCFA" flutter-src data/transit --include="*.dart" --include="*.js" --include="*.json"
                                  # (vide) — 0
node -e "const {queryDeparture}=require('./data/transit/engine/integration');
  console.log(queryDeparture({routeId:'ter_dakar_diamniadio',stopId:'stop_dakar_ter',serviceDate:'2026-09-27',now:new Date('2026-09-27T08:17:00Z')}))"
                                  # { status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', ... }
```

*Fin du Lot 4.7 — aucune UI/GPS modifiée, aucune heure inventée, aucune réécriture de `schedule_registry.json` ou des 3 zones protégées.*
