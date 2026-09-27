# Dakar Bus — Intégration Fonctionnelle Contrôlée — Lot 4.8

**Lot : 4.8 — Intégration fonctionnelle contrôlée du moteur horaire**
**Date : 2026-09-27**
**Nature : DATA LAYER fonctionnel — connexion `ScheduleEngine → DataService → DepartureInfo` sans UI/GPS/RoutePlanner**
**Statut : COMPLETE**
**Base : commit 9f4f916 (main) + Lots 4.4–4.7 — Branche `arena/01a0df09-dakar-bus`**

---

## 1. Audit initial

### 1.1 Fichiers inspectés avant toute modification (lecture seule)

| Chemin | Taille | Constat d'audit |
|---|---|---|
| `flutter-src/lib/services/data_service.dart` | 298 l. | `DataService(nextDepartureFor({routeId, stopId, directionId?, serviceDate, now}))` déjà câblé : instancie `ScheduleEngine(dataset:_scheduleProvider.dataset, frequencyProvider:uniqueRouteStop?FrequencyProvider:null, realtimePredictions, realtimeMaxAge)` et délègue à `ScheduleEngine.nextDepartureFor`. Horloge injectable (`Clock` → `SystemClock` prod / `FixedClock` tests), jamais `DateTime.now()` dans le moteur. `_hasUniqueRouteStop` n'autorise un repli `ESTIMATED` que si `route.id` + `stop.id` sont uniques dans `_routes`/`_stops` déjà chargés — aucune promotion `route.stopIds → stop_times`. |
| `flutter-src/lib/services/data_provider.dart` | 227 l. | `FrequencyProvider` : 3 `FrequencySource` `ESTIMATED` (`brt_b1_guediawaye_petersen` 6 min + 10/7 dim, `brt_b2_express` 6 min lun-sam, `ter_dakar_diamniadio` 10/20 min + 20 dim) — `departureInfoForRoute` renvoie `UNKNOWN` hors fenêtre, jamais `REAL_TIME` ni `stop_times`. `DataProvider` alias de compatibilité. Validations : `directionId!=null → UNKNOWN`, `serviceDate != ServiceDate.fromInstant(dakarTime) → UNKNOWN`. |
| `flutter-src/lib/models/departure_info.dart` | 468 l. | `DepartureInfo` immuable à factories vérifiées : `unknown`, `scheduled` (dataset+trip+stopTime+service+provenance complète, `departureTime` requis, `isValidScheduleFor && hasCompleteCoverageFor && dateVerified≤calculatedAt`), `realTime` (mêmes vérifs + `isFreshAt`), `fromFrequency` (`status==estimated`, `source`+`dateVerified` requis, `frequencyMinutes>0`, `window.appliesAt` vrai, `scheduledTime/nextDepartureAt==null`). Champs : `status`, `routeId`, `stopId`, `serviceDate`, `scheduledTime`, `nextDepartureAt`, `frequencyMinutes`, `source`, `sourceType`, `confidence`, `provenance` (porteur `verificationNote`), `remainingSecondsAt/minutesAt/labelAt`. |
| `flutter-src/lib/models/reliability.dart` | 93 l. | `ReliabilityLabel` : `OFFICIEL` seulement si `CONFIRMED`, `FUTURE` jamais actif, `UNVERIFIED/CONFLICTING` jamais promu, `scheduleStatusOf([]) → unknown`, `guardRealtime(..., hasRealtimeFeed:false) → unknown` si `realTime` sans flux. |
| `flutter-src/lib/services/schedule_service.dart` | 466 l. | `ScheduleEngine` : discriminant `FoundDeparture` (`SCHEDULED/REAL_TIME` + `nextDepartureAt`), `EstimatedDeparture` (`ESTIMATED` sans heure), `NoDeparture` (couverture complète sans départ futur), `UnknownDeparture`. Validation `routeId/stopId` non vides, `directionId≥0`, `now.isUtc`, `dataset==null → _estimatedOrUnknown`, `validationErrors`, `provenance.isValidScheduleFor/hasCompleteCoverageFor`, scan `serviceDate` jusqu'à `validTo` et `_maxCalendarDaysToScan=3660`, séquence `stop_sequence` cohérente, `toInstant` GTFS `>24h`. |
| `flutter-src/lib/services/clock.dart` | — | `Clock` / `SystemClock` (`DateTime.now().toUtc()`) / `FixedClock(instant.utc)` |
| `flutter-src/lib/services/realtime_provider.dart` | — | `EmptyRealtimeProvider` (prod) / `InMemoryRealtimeProvider(list)` |
| `flutter-src/lib/services/schedule_provider.dart` | 25 l. | `EmptyScheduleProvider(dataset==null)` prod (volontaire) / `InMemoryScheduleProvider(dataset)` tests/adapters |
| `flutter-src/lib/main.dart` | ~4000 l. | `RoutePlanner` (l.1517) : `RoutePlanner.plan(fromQuery,toQuery)` — logique de routage **non utilisée** pour les horaires. Flux réels : `ExplorerPage` (MarkerLayer/PolylineLayer carte), `Trajets` (`RoutePlanner.plan` + carte), fiches arrêt, `Assistant IA` — **aucun** n'appelle `DataService.nextDepartureFor`. Les horaires n'étaient jusqu'alors qu'un badge `ReliabilityLabel` + `DataProvider` fréquence, jamais un `nextDepartureFor` fonctionnel. |

### 1.2 Chemins réels identifiés lors d'une requête utilisateur

```
Utilisateur tape "Gare TER Dakar" ou choisit "TER Diamniadio" + arrêt
  → ExplorerPage._activePolylines / MarkerLayer (carte) ou RoutePlanner.plan (Trajets)
  → stopsForRoute(routeId) / _hasUniqueRouteStop(routeId,stopId) (filtrage réseau chargé)
  → PAS d'appel à nextDepartureFor en production (EmptyScheduleProvider ⇒ dataset null)
  → Seule branche historique : departureInfoForRoute → FrequencyWindow.appliesAt → ESTIMATED/UNKNOWN
  → Jamais de DepartureInfo SCHEDULED/PARTIALLY_CONFIRMED avant Lot 4.8 en prod
```

Le Lot 4.8 ne crée pas un nouveau routage : il rend le chemin `route→stop→DataService.nextDepartureFor→DepartureInfo` fonctionnel en injectant, **en tests**, un `InMemoryScheduleProvider` portant le registre validé (JS : `createEngineFromRegistry`), sans toucher `main.dart`.

### 1.3 Registre horaire réel (lecture seule, Lot 4.5)

`data/transit/validated/schedule_registry.json` 513 K : 4 fréquences `ESTIMATED`, 624 `stop_times` (48 `PARTIALLY_CONFIRMED` `stop_dakar_ter` seq1 + 576 `UNCONFIRMED` intermédiaires, 0 `SCHEDULED`), `gtfs_time_convention.times_rewritten=0`, `example_over_24h=25:15:00`, `stats.by_realtime_status.REAL_TIME=0`, `realtime_entries=0`. `public_routes.json` 115 routes (TER1/BRT3/DDD39/AFTU72).

## 2. Architecture avant / après

### 2.1 Avant (Lots 4.6–4.7)

```
schedule_registry.json ──(lecture seule)──┐
                                          ├─→ ScheduleEngine (JS + Dart) — nextDeparture(route,stop,serviceDate,now)
public_routes.json ───────────────────────┘         ↕
                                              integration.js queryDeparture (Node tests, 21 tests)
                                              DepartureInfo (Dart tests synthétiques uniquement)
                                              DataService(nextDepartureFor) branché mais dataset==null ⇒ _estimatedOrUnknown
                                              ║
                                              ╚══ UI non branchée (volontaire)
```

### 2.2 Après (Lot 4.8 — sans UI)

```
schedule_registry.json ──(lecture seule)──┐
                                          ├─→ ScheduleEngine pur (JS + Dart, Clock injecté, now UTC)
public_routes.json ───────────────────────┘         ↓
                                              integration.js queryDeparture(route,stop,serviceDate,now)  ← Node : registre réel
                                              DataService.nextDepartureFor(…,InMemoryScheduleProvider(dataset)) ← Dart : même dataset synthétique/validé en tests
                                              ↓
                                              DepartureInfo / DepartureSearchResult
                                              (Found / Estimated / Unknown / NoDeparture)
                                              ↓
                                              (future Flutter — non modifié en 4.8)
```

Aucune réécriture d'architecture : une seule couche d'adaptation (`integration.js` + injection `InMemoryScheduleProvider` en tests) rend le flux fonctionnel démontrable. `main.dart` reste à `EmptyScheduleProvider` en prod jusqu'à fourniture `ScheduleDataset OFFICIAL_STATIC` sourcé.

## 3. Chemin fonctionnel

```dart
// Dart — flux fonctionnel réel (4.8)
final service = DataService(
  scheduleProvider: InMemoryScheduleProvider(datasetValidé), // tests ; prod = EmptyScheduleProvider()
  frequencyProvider: FrequencyProvider(),
  realtimeProvider: EmptyRealtimeProvider(), // ou InMemoryRealtimeProvider([predictionFraîche])
  clock: FixedClock(DateTime.utc(2026,9,27,8,17)),
);
final DepartureSearchResult res = service.nextDepartureFor(
  routeId: 'ter_dakar_diamniadio',
  stopId: 'stop_dakar_ter',
  serviceDate: ServiceDate(2026,9,27), // dimanche
  now: DateTime.utc(2026,9,27,8,17),
);
if (res is FoundDeparture) {
  final DepartureInfo info = res.departures.single; // status SCHEDULED/REAL_TIME (ou PARTIALLY via JS)
  info.remainingLabelAt(now); // "Départ dans 8 min" / "Départ maintenant"
}
```

```js
// Node — même chemin via integration.js (tests fonctionnels Lot 4.8)
const { queryDeparture } = require('./data/transit/engine/integration');
queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:new Date('2026-09-27T08:17:00Z') });
// → { status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', nextDepartureAt:'2026-09-27T08:25:00.000Z', … }
```

Garantie : l'appelant fournit `routeId/stopId/serviceDate/now` explicites ; aucune résolution par nom, proximité, `placeId`, `stop_sequence` implicite ou `route.stopIds → stop_times` n'est effectuée.

## 4. Fichiers modifiés

**Aucun fichier protégé modifié — vérifié `git diff` :**

| Zone protégée | `git diff`| État |
|---|---|---|
| `flutter-src/lib/main.dart` | `0` | **NON MODIFIÉ** |
| `flutter-src/assets/data/dakar_network.json` | `0` | **NON MODIFIÉ** |
| `data/gtfs/` | `0` | **NON MODIFIÉ** |
| GPS / `MarkerLayer` / `PolylineLayer` / `NavigationBar` / `Explorer` / `Alertes` / `Réglages` / `Assistant IA` / `RoutePlanner` / intermodalité | `grep -Rina 'MarkerLayer\|PolylineLayer\|RoutePlanner' flutter-src --diff` 0 | **NON MODIFIÉ** |

**Changements Lot 4.8 (data layer seuls, minimaux) :**

| Fichier | Nature | Description |
|---|---|---|
| `tests/horaire-fonctionnel.test.js` | **créé** | 23 tests fonctionnels Lot 4.8 (TER 3 + intermédiaire 1 + BRT 4 + DDD 1 + AFTU 1 + REAL_TIME 2 + priorité 5 + Clock 2 + timezone/>24h 2 + compat 2 + non-régression 1) — passent par `integration.queryDeparture` |
| `docs/DAKAR_BUS_HORAIRE_FONCTIONNEL_4_8.md` | **créé** | Ce rapport (17 sections + tableau) |
| `data/transit/engine/integration.js` | **conservé** Lot 4.7 | Aucune réécriture ; déjà `loadRegistry` lecture seule + `toContract` |

Héritage Lots 4.6–4.7 (inchangés en 4.8, listés pour `git diff --stat`) : `flutter-src/lib/models/departure_info.dart` / `reliability.dart` / `services/data_provider.dart` / `services/data_service.dart` / `test/ui_data_reliability_test.dart` (5 fichiers, 560+ insert — moteur déjà branché en 4.6).

Aucune modification visuelle d'Explorer/Trajets/fiches/cartes/IA.

## 5. Contrat `DepartureInfo`

Champ Dart / JS (JS: `toContract`) — tous **null-safe** :

| Champ | Type | Règle Lot 4.8 |
|---|---|---|
| `status` | `SCHEDULED`/`PARTIALLY_CONFIRMED`/`ESTIMATED`/`UNKNOWN`/`REAL_TIME`/`NO_DEPARTURE` | Discriminant ; `ESTIMATED` jamais promu `SCHEDULED` |
| `routeId` | string | Requête d'origine |
| `stopId` | string | Requête d'origine |
| `serviceDate` | `ServiceDate` / `YYYY-MM-DD` | Requête d'origine |
| `scheduledTime` | `DateTime`/string `HH:MM:SS` \| null | Renseigné seulement pour `SCHEDULED/PARTIALLY_CONFIRMED/REAL_TIME` ; **null** pour `ESTIMATED/UNKNOWN` |
| `nextDepartureAt` | `DateTime` UTC ISO \| null | Instant du prochain départ exact ; **null** pour `ESTIMATED` |
| `frequencyMinutes` | `int` \| null | Renseigné seulement pour `ESTIMATED` (6/10/20) |
| `source` | string \| null | `terdakar.sn` / `sunubrt.sn` / PassBi — traçable |
| `sourceType` | `officialStatic`/`operatorRealtime`/`unknown` | Traçabilité |
| `confidence` | `HIGH`/`MEDIUM`/`LOW`/`null` \| double 0..1 | Provenance |
| `verificationNote` | via `provenance` (Dart) / `verificationNote` (JS) | Raison / règle appliquée (ex. « ne peut être SCHEDULED ») |

Invariants vérifiés (§15) : `ESTIMATED ⇒ scheduledTime==null && nextDepartureAt==null && frequencyMinutes!=null`, `UNKNOWN ⇒ scheduledTime==null && nextDepartureAt==null && minutesUntil==null` (jamais 0 par défaut).

## 6. TER

### 6.1 Grille (source `terdakar.sn/les_horaires_des_trains`, `OFFICIAL_OPERATOR`, `date_verified 2026-09-27`)

Semaine 10 min `05:45/05:35→20:55` + 20 min `21:05→22:05`, dimanche/ férié 20 min `06:25→22:05` — 48 départs corroborés (`passbi_found_in_official 48/48`), fenêtre d'audit `20260927` seule (`TER_SUNDAY_AUDIT` `0000001`).

### 6.2 Vérifications fonctionnelles (`queryDeparture` / `DataService.nextDepartureFor`)

```js
queryDeparture({routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z'})
→ {status:'PARTIALLY_CONFIRMED', scheduledTime:'08:25:00', nextDepartureAt:'2026-09-27T08:25:00.000Z', minutesUntil:8}
```

| Requête | `now` | Résultat | `nextDepartureAt` | Note |
|---|---|---|---|---|
| TER Dakar dim `08:17` | `08:17:00Z` | `PARTIALLY_CONFIRMED` | `08:25:00Z` | `scheduledTime=08:25:00`, 8 min |
| TER Dakar `08:25` (départ maintenant) | `08:25:00Z` | `PARTIALLY_CONFIRMED` | `08:25:00Z` | `minutesUntil=0`, `displayLabel='Départ maintenant'` — jamais `Départ dans 0 min` |
| TER Dakar `22:10` après dernier | `22:10:00Z` | `ESTIMATED 20` | `null` | aucun `22:25` fictif |
| TER Dakar `06:20` premier | `06:20:00Z` | `PARTIALLY_CONFIRMED` | `06:25:00Z` | premier départ |
| TER Dakar `22:00` dernier | `22:00:00Z` | `PARTIALLY_CONFIRMED` | `22:05:00Z` | dernier départ |

Le consommateur interprète `minutesUntil==0 && (SCHEDULED||PARTIALLY_CONFIRMED)` comme `Départ maintenant` (via `remainingLabelAt` / `displayLabel`).

## 7. TER — arrêt intermédiaire

```js
queryDeparture({routeId:'ter_dakar_diamniadio', stopId:'stop_colobane', serviceDate:'2026-09-27', now:'2026-09-27T06:20:00Z'})
→ {status:'ESTIMATED', frequencyMinutes:20, scheduledTime:null, nextDepartureAt:null}
```

576 intermédiaires `UNCONFIRMED` (`LOW` PassBi non confirmée) → ignorés comme exacts ; repli `ESTIMATED 20` via fréquence dimanche (route connue). Interdit de promouvoir `UNCONFIRMED → SCHEDULED/PARTIALLY_CONFIRMED` — testé.

## 8. BRT

| Route | Fréquence | `queryDeparture` any_stop 08:17 | Note |
|---|---|---|---|
| **B1** `brt_b1` | 6 min tous les jours (+10/7 dim `sunubrt`) | `ESTIMATED 6` `scheduledTime=null` | `Passage estimé toutes les 6 min` — jamais `08:00,08:06…` |
| **B2** `brt_b2` | 6 min lun-sam 7 stations | `ESTIMATED 6` | distincte B1, pas de fusion |
| **B3** `brt_b3` | aucune grille (7 stations `NEW` depuis 10/2025) | `UNKNOWN` | jamais rapprochée B1/B2, jamais `ESTIMATED` inventé |

Vérifié : `ScheduleEngine` BRT ne produit **aucun** `scheduledTime` depuis fréquence.

## 9. DDD

```js
queryDeparture({routeId:'ddd_1', stopId:'any_stop', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z'})
→ {status:'UNKNOWN', scheduledTime:null, nextDepartureAt:null}
```

39 codes DDD officiels (`public_routes` `CONFIRMED`) — structure/horaire `UNKNOWN`. Règle conservée : `IDENTITY=CONFIRMED` n'implique jamais `SCHEDULE≠UNKNOWN` — distinction explicite et testée (`public_routes` contient `ddd_1` alors que statut horaire est `UNKNOWN`).

## 10. AFTU

```js
queryDeparture({routeId:'aftu_1', stopId:'any_stop', serviceDate:'2026-09-27', now:'2026-09-27T08:17:00Z'})
→ {status:'UNKNOWN'}
```

72 lignes officielles (1-5,24-89,91) — `NOT_FOUND A90TD` exclu, horaire `UNKNOWN`. Même distinction `IDENTITY CONFIRMED / SCHEDULE UNKNOWN` que DDD.

## 11. REAL_TIME

| Contexte | `realtime_entries` | Résultat |
|---|---|---|
| **Prod** (`schedule_registry.json`) | **0** `by_realtime_status.REAL_TIME=0` `NO_REAL_TIME_FEED` | Aucune donnée prod présentée comme `REAL_TIME` (test `≠REAL_TIME`) |
| **Frais** synthétique (`observedAt now-1min`, `predicted now+3min`, `maxAge 5min`) | 1 prédiction | `REAL_TIME` `minutesUntil=3` `Arrivée dans 3 min` |
| **Périmé** (`observedAt now-10min`) | 1 prédiction | `ESTIMATED` (fallback) `scheduledTime=null` pour BRT/TER sans exact — sans fausse donnée prod |

Respect Lot 4.2B : PassBi `NOT_REAL_TIME`.

## 12. Ordre de priorité

```
REAL_TIME frais
        ↓
SCHEDULED valide (6 conditions)
        ↓
PARTIALLY_CONFIRMED (48 départs Dakar corroborés, non SCHEDULED)
        ↓
ESTIMATED (fréquence documentée 6/10/20)
        ↓
UNKNOWN
```

Tests dédiés (§13) :

- `REAL_TIME frais` (08:42) écrase `SCHEDULED 08:40` → `REAL_TIME` retenu ; périmé → retombe `SCHEDULED`.
- `SCHEDULED 08:40` écrase `ESTIMATED 5 min` même route → `SCHEDULED`.
- `PARTIALLY_CONFIRMED` TER Dakar écrase `ESTIMATED 20` → `PARTIALLY_CONFIRMED` (8.1).
- `ESTIMATED` jamais promu `SCHEDULED` (B1).
- `UNKNOWN` jamais promu `ESTIMATED` si pas de fréquence (`unknown_route_sans_frequence`).

Une source moins fiable n'écrase jamais une plus fiable.

## 13. Clock

`ScheduleEngine` n'appelle **jamais** `DateTime.now()` / `Date.now()` ; `now` est **injectable**.

| Usage | Horloge | Test |
|---|---|---|
| Tests | `FixedClock(DateTime.utc(2026,9,27,8,17))` | `clock.now().toISOString()` déterministe, deux `queryDeparture(clock.now())` identiques |
| Prod | `SystemClock` (`DateTime.now().toUtc()`) | `SystemClock.now()` non lu par le moteur — seul `now` explicite compte |
| Garde-fou | `now` non-UTC | `UnknownDeparture` (Dart) |

## 14. ServiceDate / Timezone

- `kDakarTimeZone = Africa/Dakar` — instants construits en **UTC** (Dakar UTC+0 actuellement), jamais fuseau local téléphone.
- `ServiceDate.fromInstant(DateTime.utc)` + `FrequencyWindow.appliesAt(requestedAt.toUtc())` → `Sunday 06:25` s'applique correctement.
- Testé : `08:17Z` Dakar = `08:17Z` UTC → `PARTIALLY_CONFIRMED`.

## 15. GTFS >24h

Convention GTFS conservée (jamais réécrite) — `schedule_registry.json` `times_rewritten=0`, `example_over_24h=25:15:00`.

```js
ServiceTime.parse('25:15:00').toString() === '25:15:00' // pas 01:15:00
ServiceTime.parse('25:15:00').toInstant(ServiceDate.parse('2026-09-27')) === '2026-09-28T01:15:00.000Z'
```

Recherche : service `2026-09-27` `25:15` trouvé 5 min après `2026-09-28T01:10Z` → `SCHEDULED 25:15:00` `minutesUntil=5` — chaîne source inchangée.

## 16. Tests

```
$ npm test
# tests 144
# pass 144
# fail 0
```

| Suite | Tests | Couvre |
|---|---|---|
| `transit-data-layer.test.js` | 28 | Lot 4.4 |
| `transit-crosswalk.test.js` | 21 | Crosswalk 258 |
| `transit-schedule.test.js` | 10 | Référentiel 115, >24h |
| `schedule-engine.test.js` | 17 | Moteur pur 4.6 |
| `horaire-integration.test.js` | 21 | Intégration 4.7 |
| `horaire-fonctionnel.test.js` | **23** | **Lot 4.8 : TER 3 + intermédiaire 1 + BRT 4 + DDD 1 + AFTU 1 + REAL_TIME 2 + priorité 5 + Clock 2 + timezone/>24h 2 + compat 2 + non-régression 1** |
| `transit-validation.test.js` | 24 | Validation + production_ready |
| **Total** | **144** | **121 existants conservés + 23 nouveaux — 0 supprimé** |

Détail 23 nouveaux :

| # | Test | Attendu |
|---|---|---|
| 1–3 | TER 08:17→08:25 / 08:25→0 Départ maintenant / 22:10→ESTIMATED 20 | `PARTIALLY` 08:25 / `0` label / `ESTIMATED` |
| 4 | TER intermédiaire `stop_colobane` | `ESTIMATED 20` |
| 5–8 | BRT B1 6 / B2 6 / B3 UNKNOWN / jamais 08:00→08:06 | `ESTIMATED`/`UNKNOWN` |
| 9 | DDD `ddd_1` | `UNKNOWN` |
| 10 | AFTU `aftu_1` | `UNKNOWN` |
| 11–12 | REAL_TIME prod 0 / frais 3 min vs périmé ESTIMATED | `≠REAL_TIME` / `REAL_TIME 3` |
| 13–17 | Priorité REAL_TIME> SCHEDULED / SCHEDULED>ESTIMATED / PARTIALLY>ESTIMATED / UNKNOWN↛ESTIMATED / ESTIMATED↛SCHEDULED | priorité stricte |
| 18–19 | Clock FixedClock déterministe / SystemClock non appelé | `FixedClock` idempotent |
| 20–21 | Timezone Africa/Dakar UTC+0 / GTFS 25:15→01:15 | `PARTIALLY` / `25:15` 5min |
| 22–23 | Compat Flutter `DepartureInfo` null-safe + registre non réécrit | 11 champs + `before===after` |

## 17. Non-régression

- **Zones protégées** (exigé §18) :

```
$ git diff -- flutter-src/lib/main.dart         # 0
$ git diff -- flutter-src/assets/data/dakar_network.json # 0
$ git diff -- data/gtfs/                        # 0
$ grep -Rina "prix|tarif|FCFA" flutter-src data/transit --include="*.dart" --include="*.js" # 0
$ git diff --stat                               # 5 fichiers moteur (héritage 4.6) : departure_info.dart / reliability.dart / data_provider.dart / data_service.dart / ui_data_reliability_test.dart — aucune ligne UI/GPS/Explorer/RoutePlanner
```

- **Aucune modification visuelle** : `Explorer` (MarkerLayer/PolylineLayer), `Trajets` (`RoutePlanner.plan`), fiches arrêt, cartes, `Assistant IA` — **NON MODIFIÉS**.
- **Compatibilité Flutter** : `DepartureInfo`/`Reliability`/`DataProvider`/`DataService` — aucun champ public supprimé ; `provenance` conserve `verificationNote`.

## 18. Limites

| Limite | Détail | Impact |
|---|---|---|
| Aucun `SCHEDULED` réel | 0/624 — opérateur = fréquences, pas heures par station | Prod n'affiche pas `Départ dans X min` `SCHEDULED` (seulement `PARTIALLY_CONFIRMED` démontrable) |
| Aucun `REAL_TIME` prod | `realtime_entries=0` | Pas d'`Arrivée dans 3 min` temps réel |
| Fenêtre TER unique | `20260927` seul jour validé | Grille non généralisable au-delà du dimanche audité |
| BRT sans grille | 6 min seules | Pas de départ par arrêt |
| DDD/AFTU sans horaire | 111 routes `UNKNOWN` | Identité confirmée, pas d'horaire |
| `EmptyScheduleProvider` prod | `dataset==null` tant qu'aucun dataset `OFFICIAL_STATIC` n'est fourni | `DataService.nextDepartureFor` retombe `ESTIMATED/UNKNOWN` — comportement attendu, ET tests `InMemory` prouvent le flux avec dataset |
| Republication `BLOCKED` | Pas de licence PassBi | Données non redistribuables hors dépôt |
| UI non branchée | Volontaire (§16) | Données arrivent correctement, affichage décalé au lot UI |

## 19. Prochaine étape

1. Fournir un `ScheduleDataset` `OFFICIAL_STATIC` sourcé avec les 6 preuves (source+provenance+validité+calendrier+chaîne `route→trip→stop_sequence`) pour promouvoir `PARTIALLY_CONFIRMED → SCHEDULED` sans changer le moteur.
2. Brancher `InMemoryScheduleProvider(datasetValidé)` en prod derrière feature-flag (toujours sans toucher `main.dart` UI).
3. Connecter un `RealtimeProvider` GTFS-RT frais → `REAL_TIME`.
4. Lot UI : brancher `DepartureInfo.remainingLabelAt(now)` / `displayLabel` dans fiches arrêt / `Explorer` / `Trajets` (seul lot visuel).

---

## Annexe — tableau demandé (§19)

| Réseau | Identité | Horaire | Résultat fonctionnel |
|---|---|---|---|
| TER | Confirmée | 48 départs dimanche | PARTIALLY_CONFIRMED |
| TER intermédiaire | Confirmée | fréquence | ESTIMATED |
| BRT B1 | Confirmée | 6 min | ESTIMATED |
| BRT B2 | Confirmée | 6 min | ESTIMATED |
| BRT B3 | Nouvelle | aucune grille | UNKNOWN |
| DDD | Confirmée | aucune grille | UNKNOWN |
| AFTU | Confirmée | aucune grille | UNKNOWN |

*Vérifié fonctionnellement : `queryDeparture` / `DataService.nextDepartureFor` → `DepartureInfo` cohérent (status, routeId, stopId, serviceDate, scheduledTime, nextDepartureAt, frequencyMinutes, source, sourceType, confidence, verificationNote/provenance) sans heure inventée, sans réécriture `schedule_registry.json` ni des 3 zones protégées.*
