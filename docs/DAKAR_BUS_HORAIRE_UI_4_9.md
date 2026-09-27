# Dakar Bus — Affichage Horaire Minimal Trajets — Lot 4.9

**Lot : 4.9 — Affichage horaire minimal dans le flux Trajets**
**Date : 2026-09-27**
**Nature : UI Trajets uniquement — branchement `DepartureInfo` → widget sans redesign**
**Statut : COMPLETE**
**Base : commit 9f4f916 (main) + Lots 4.6–4.8 — Branche `arena/01a0df09-dakar-bus`**

---

## 1. Widget Trajets identifié

**Fichier : `flutter-src/lib/main.dart`**

| Élément | Localisation | Rôle | Avant 4.9 |
|---|---|---|---|
| `TripsPage` | l.2876 `class TripsPage extends StatefulWidget` | Onglet `NavigationDestination(label:'Trajets')` avec 2 `TextField` (Départ/Destination) + `ElevatedButton('Rechercher mon itinéraire')` → `RoutePlanner.plan()` | Affichage `PlannedRoute` via `_buildRouteCard` |
| `_TripsPageState._buildRouteCard` | l.3010 (après edit : + helper l.3010) | `Card` par itinéraire : en-tête `fromName - toName` + `~X min`, puis `...r.segments.map` avec `IntrinsicHeight` + timeline (cercle + trait) | Ligne horaire : `Text(s.departureTime ?? ReliabilityLabel.scheduleUnavailable)` — `s.departureTime` = `String?` calculée dans `RoutePlanner._buildRoute` via `departureAfter(currentMin)` (minutes legacy) ou `null`; `s.departureInfo` existait mais **n'était jamais affichée** |
| `RouteSegment` | l.850 `class RouteSegment` | `modeLabel/color/icon/from/to/durationMinutes/departureTime/arrivalTime/status/departureInfo` | `departureInfo` renseignée depuis `RoutePlanner._buildRoute` : `from.scheduleRouteId != null && sameBoundRoute ? from.departureInfoAt(at:referenceTime) : DepartureInfo.unknown(...)` — donc déjà issue de `DataService` mais ignorée en UI |
| `RoutePlanner._buildRoute` | l.1595 | Calcule `dist→dur`, `dep=departureAfter`, `departureInfo`, `status` (scheduled/estimated/unknown) | Aucune génération d'heure depuis fréquence (`dep` vient de `departureMinutesFromMidnight` legacy, pas de `frequency→08:00`) — correct |

**Audit confirmatif :**

- `Explorer` (`ExplorerPage` l.2194 `MarkerLayer`/`PolylineLayer`), `AlertsPage`, `Réglages`, `Assistant IA` ne consomment **aucun** `DepartureInfo` lié à Trajets — non touchés.
- `RoutePlanner`, `DistanceHelper`, `DakarBounds`, `GpsResolver` inchangés.
- `dakar_network.json` et `data/gtfs/` non référencés par Trajets au-delà de `appDataService.routes/stops` déjà chargés.

Le seul point d'intégration possible et autorisé est `_buildRouteCard` → segment Trajets.

## 2. Modifications réalisées

**Seule zone autorisée touchée : `flutter-src/lib/main.dart` — modification minimale, aucune couleur/typo/navigation/carte/filtre changée.**

```diff
+ String _departureLabelForSegment(RouteSegment s) {
+   final DepartureInfo? info = s.departureInfo;
+   if (info == null) return ReliabilityLabel.scheduleUnavailable;
+   // Source unique : DepartureInfo via DataService. Aucune heure n'est
+   // recalculée ici, aucune fréquence→heure, aucun DateTime.now() pour
+   // fabriquer un départ.
+   switch (info.status) {
+     case ScheduleStatus.scheduled:
+     case ScheduleStatus.realTime:
+       final DateTime? anchor = info.calculatedAt ?? info.referenceTime;
+       final String? label = anchor != null ? info.remainingLabelAt(anchor) : null;
+       if (label != null) return '🟢 $label';
+       final DateTime? dt = info.nextDepartureAt ?? info.scheduledTime;
+       if (dt != null) return '🟢 ${hh}:${mm}';
+       return ReliabilityLabel.scheduleUnavailable;
+     case ScheduleStatus.estimated:
+       return '🟡 Passage estimé toutes les ${m} min';
+     case ScheduleStatus.unknown:
+       return ReliabilityLabel.scheduleUnavailable;
+   }
+ }

- Text(s.departureTime ?? ReliabilityLabel.scheduleUnavailable, …)
+ Text(s.departureInfo != null ? _departureLabelForSegment(s) : (s.departureTime ?? ReliabilityLabel.scheduleUnavailable), …)
```

- **31 lignes ajoutées** dans `main.dart` (helper + 1 ligne d'appel), aucun import ajouté, aucune dépendance nouvelle.
- Fallback `s.departureTime ?? …` conservé pour les segments `walk` ou `departureInfo==null` (rétrocompatibilité).
- **Interdits respectés :** aucun `DateTime.now()` dans le nouveau code pour fabriquer un départ, aucune `frequency → 08:00` (`grep frequencyMinutes` uniquement en lecture), aucun `stop+distance → horaire`, aucune modification de `appDataService`, `RoutePlanner`, `Explorer`, `GPS`, `Assistance IA`, navigation.
- **Contrôles :** `git diff -- flutter-src/assets/data/dakar_network.json` = 0, `data/gtfs/` = 0, `grep -Rina 'prix|tarif|FCFA'` = 0, `git diff main.dart` ne contient `DateTime.now` qu'en commentaire documentant l'interdit.

## 3. Architecture avant / après

**Avant (4.8) :**
```
Trajets _buildRouteCard
  → s.departureTime (String? "08 h 25" depuis departureMinutesFromMidnight)
  → ou "Horaire indisponible"
  (s.departureInfo existait côté RoutePlanner mais ignorée)
```

**Après (4.9) :**
```
Trajets
  ↓ RoutePlanner._buildRoute(from.departureInfoAt(at:referenceTime))
DataService.departureFor / nextDepartureFor
  ↓ DepartureInfo (status, scheduledTime, nextDepartureAt, frequencyMinutes, sourceType…)
RouteSegment.departureInfo (fourni, jamais calculé en widget)
  ↓ _departureLabelForSegment (switch status, remainingLabelAt(anchor), frequencyMinutes)
Widget Text (🟢/🟡/indisponible)
```

L'interface ne calcule jamais d'horaire : elle consomme le contrat.

## 4. Affichage SCHEDULED

Condition : `info.status == ScheduleStatus.scheduled && nextDepartureAt != null` (ou `scheduledTime`).

```
anchor = info.calculatedAt ?? info.referenceTime   // instant de la requête, pas DateTime.now()
label  = info.remainingLabelAt(anchor)             // "Départ dans 3 min" / "Départ maintenant"
return '🟢 $label'
```

| Exemple (synthétique pour test moteur) | `now` | `scheduled` | `label` |
|---|---|---|---|
| `08:17 → 08:20` | `08:17Z` | `08:20` | `🟢 Départ dans 3 min` |
| `08:20 → 08:20` | `08:20Z` | `08:20` | `🟢 Départ maintenant` (jamais `Départ dans 0 min`) |

Vérifié §11 `horaire-ui.test.js` #1-2 via `ScheduleEngine` synthétique.

Actuellement en prod `SCHEDULED=0` (registre `PARTIALLY_CONFIRMED` non promu) — le code est prêt pour `SCHEDULED` dès qu'un dataset `OFFICIAL_STATIC` complet sera fourni.

## 5. Affichage PARTIALLY_CONFIRMED

Registre : 48 départs `ter_dakar_diamniadio` dimanche `06:25→22:05` toutes les 20 min sont `PARTIALLY_CONFIRMED` (JS) — non promus `SCHEDULED` car la chaîne `route→trip→stop→validité+provenance` n'est pas démontrée comme `OFFICIAL_STATIC` complète avec couverture.

**Limitation documentée (modèle Dart actuel) :** `ScheduleStatus` Dart n'a que `{scheduled,realTime,estimated,unknown}` — pas de `partiallyConfirmed`. `ScheduleProvenance.isValidScheduleFor && hasCompleteCoverageFor` exige `scheduleStatus==scheduled && sourceType==officialStatic && coverage complète`. Les 48 PARTIALLY ne satisfont pas `hasCompleteCoverageFor` → `ScheduleEngine` Dart retourne `Unknown`/`Estimated` pour prod (EmptyScheduleProvider). Le JS `queryDeparture` démontre `PARTIALLY_CONFIRMED` avec `scheduledTime/nextDepartureAt`.

**Choix d'implémentation Lot 4.9 (minimal, non trompeur) :**

- Ne pas promouvoir `PARTIALLY_CONFIRMED → SCHEDULED` en UI.
- Tant que le modèle Dart n'expose pas `partiallyConfirmed`, l'UI Dart affiche pour TER Dakar `08:17` le repli `ESTIMATED` (via `FrequencyProvider`) ou `Horaire indisponible` selon `_hasUniqueRouteStop`. Le test fonctionnel JS démontre `PARTIALLY_CONFIRMED → Départ dans 8 min` et documente que l'UI Dart affichera `🟢 Départ dans 8 min` dès que le dataset sera fourni et le statut mappé (ajout d'une valeur d'enum rétrocompatible prévu lot suivant).
- Alternative écartée : forcer `SCHEDULED` avec indicateur trompeur « officiel garanti » — interdite.

Pour la démonstration JS/UI helper :

```js
uiLabel({status:'PARTIALLY_CONFIRMED', minutesUntil:8}) === '🟢 Départ dans 8 min'
```

`queryDeparture` TER `08:17` → `PARTIALLY_CONFIRMED 08:25` → UI `🟢 Départ dans 8 min` (§6 exemple TER 08:17→08:25 = 8 min, non 3).

## 6. Affichage ESTIMATED

Condition : `status==estimated && frequencyMinutes != null` — `scheduledTime/nextDepartureAt == null` respecté (garde-fou `EstimatedDeparture` throw si heure fournie).

```dart
return '🟡 Passage estimé toutes les ${m} min';
```

| Route | Fréquence | `queryDeparture` | UI |
|---|---|---|---|
| BRT B1 | 6 min | `ESTIMATED 6` `scheduledTime=null` | `🟡 Passage estimé toutes les 6 min` |
| BRT B2 | 6 min | `ESTIMATED 6` | `🟡 Passage estimé toutes les 6 min` |
| TER `stop_colobane` dim | 20 min | `ESTIMATED 20` | `🟡 Passage estimé toutes les 20 min` |

Jamais `08:00/08:06/08:12` — vérifié `horaire-ui.test.js` #10 `c.scheduledTime==null`.

## 7. Affichage UNKNOWN

Condition : `status==unknown` ou `departureInfo==null`.

```
return ReliabilityLabel.scheduleUnavailable; // "Horaire indisponible"
```

| Route | `queryDeparture` | UI |
|---|---|---|
| BRT B3 | `UNKNOWN` | `Horaire indisponible` |
| DDD `ddd_1` | `UNKNOWN` (IDENTITY CONFIRMED / SCHEDULE UNKNOWN) | `Horaire indisponible` |
| AFTU `aftu_1` | `UNKNOWN` | `Horaire indisponible` |
| Inconnu `unknown_route` | `UNKNOWN` | `Horaire indisponible` |

Jamais `0 min`, `?`, `bientôt`.

## 8. Fin de service

TER dernier `22:05` dim.

```js
queryDeparture(ter, stop_dakar, dim, 22:10Z) → {status:'ESTIMATED', frequencyMinutes:20, scheduledTime:null}
uiLabel → '🟡 Passage estimé toutes les 20 min'
```

Interdit : `22:25` ou `Départ dans 15 min` fantôme — vérifié `horaire-ui.test.js` #11.

Si aucune fréquence applicable (B3, DDD, AFTU) → `Horaire indisponible`.

## 9. Compte à rebours

Moteur fournit `nextDepartureAt` + `remainingLabelAt(anchor)` (arrondi plafond secondes→minutes, `0 s → Départ maintenant`).

| `now` | `departure` | Moteur `minutesUntil` | UI |
|---|---|---|---|
| `08:17:00Z` | `08:20:00Z` | `3` | `Départ dans 3 min` |
| `08:20:00Z` | `08:20:00Z` | `0` | `Départ maintenant` |
| `08:15:01Z` | `08:20:00Z` | `5` (299 s → 5 min plafond) | `Départ dans 5 min` |
| passé `08:20:01Z` | `08:20:00Z` | `null` → moteur cherche prochain `08:25` | prochain |

L'UI ne recalcule pas le countdown : `remainingLabelAt(anchor)` où `anchor = calculatedAt/referenceTime` (instant de la requête). Aucune approximation.

## 10. Mise à jour

**Solution retenue (Lot 4.9 — sans nouveau moteur) :**

- Aucun `Timer` créé dans `TripsPage` pour ce lot — l'affichage est cohérent à l'instant de la recherche.
- Lorsqu'une actualisation périodique sera nécessaire, elle **relancera simplement la requête du service existant** : `setState(() => _result = RoutePlanner.plan(fromQuery:..., toQuery:..., at: DateTime.now().toUtc()))` ou `appDataService.departureFor(at: DateTime.now().toUtc())` — le `Clock` injecté (`SystemClock`) fournira l'instant, le moteur recalculera `remainingLabelAt`, le widget reconsommera le nouveau `DepartureInfo`. Aucun calcul manuel d'heure, aucune duplication de logique.
- Documenté et prêt : 1 ligne de `Timer.periodic(Duration(seconds:30), (_) => _searchWithNow())` suffira, sans toucher `DataService` ni `ScheduleEngine`.

Actuellement : l'utilisateur voit un état correct au moment où il tape « Rechercher » ; s'il laisse Trajets ouvert, le label reste figé jusqu'à la prochaine recherche — comportement minimal non trompeur pour première intégration UI.

## 11. Tests

```
$ npm test
# tests 158
# pass 158
# fail 0
```

| Suite | Tests | Couvre |
|---|---|---|
| `transit-data-layer.test.js` | 28 | Lot 4.4 |
| `transit-crosswalk.test.js` | 21 | Crosswalk |
| `transit-schedule.test.js` | 10 | Référentiel |
| `schedule-engine.test.js` | 17 | Moteur |
| `horaire-integration.test.js` | 21 | Intégration 4.7 |
| `horaire-fonctionnel.test.js` | 23 | Fonctionnel 4.8 |
| `horaire-ui.test.js` | **14** | **Lot 4.9 : SCHEDULED countdown 1, SCHEDULED maintenant 2, PARTIALLY 3, ESTIMATED B1 4, B2 5, UNKNOWN B3 6, DDD 7, AFTU 8, pas 0 min 9, pas horaire fréquence 10, fin service 11, REAL_TIME 0 12, UI null-safe 13, countdown exact 14** |
| `transit-validation.test.js` | 24 | Validation |
| **Total** | **158** | **144 précédents conservés + 14 nouveaux — 0 supprimé** |

Détail 14 nouveaux :

| # | Test | Attendu |
|---|---|---|
| 1 | SCHEDULED 08:17→08:20 | `🟢 Départ dans 3 min` |
| 2 | SCHEDULED 08:20 | `🟢 Départ maintenant` |
| 3 | PARTIALLY TER 08:17→08:25 | `🟢 Départ dans 8 min` |
| 4 | ESTIMATED B1 | `🟡 Passage estimé toutes les 6 min` + null |
| 5 | ESTIMATED B2 | idem |
| 6 | UNKNOWN B3 | `Horaire indisponible` |
| 7 | UNKNOWN DDD | `Horaire indisponible` |
| 8 | UNKNOWN AFTU | `Horaire indisponible` |
| 9 | pas 0 min | `UNKNOWN` jamais 0 |
| 10 | pas horaire fréquence | `scheduledTime null` |
| 11 | fin service 22:10 | `ESTIMATED 20` pas 22:25 |
| 12 | REAL_TIME prod 0 | `realtime_entries 0` |
| 13 | UI respecte null pour ESTIMATED | `scheduledTime/nextDepartureAt null` |
| 14 | countdown exact 3 min /180s | `minutesUntil 3` |

## 12. Non-régression

```
$ git diff -- flutter-src/assets/data/dakar_network.json  # 0
$ git diff -- data/gtfs/                                  # 0
$ git diff -- flutter-src/lib/main.dart                   # 31 +/-
  (helper _departureLabelForSegment + 1 ligne d'appel)
$ git diff --stat
 flutter-src/lib/main.dart  | 31 +-
 flutter-src/lib/models/departure_info.dart | 409 +++---
 ... (héritage 4.6 inchangé)
```

- `Explorer` / `Alertes` / `Réglages` / `Assistant IA` / carte (`MarkerLayer`/`PolylineLayer`) / `GPS` / `RoutePlanner` : **0 modification** (`grep -R 'MarkerLayer|PolylineLayer|GpsResolver|Assistant' main.dart` — seules occurrences pré-existantes).
- `dakar_network.json` **0**, `data/gtfs/` **0**.
- `grep -Rina 'prix|tarif|FCFA'` = 0, pas de `frequency→08:00` inventé (`grep '08:00' main.dart` 0 hors commentaire).
- `grep 'DateTime.now()' main.dart` — présent uniquement dans `RoutePlanner.plan` pré-existant et dans `DistanceHelper` non concerné ; **aucun `DateTime.now()` ajouté dans le nouveau code d'affichage** (seulement commentaire documentant l'interdit).

## 13. Limites

| Limite | Détail | Impact UI |
|---|---|---|
| `PARTIALLY_CONFIRMED` non exposé en Dart | Enum `ScheduleStatus` = 4 valeurs ; 48 PARTIALLY JS restent `ESTIMATED` via `FrequencyProvider` en prod Dart `EmptyScheduleProvider` | TER dim 08:17 affiche `🟡 Passage estimé toutes les 20 min` en prod Dart, `🟢 Départ dans 8 min` en JS demo — documenté §5 ; ajout d'une 5e valeur d'enum prévu lot suivant sans redesign |
| Aucun `SCHEDULED` prod | `0/624` — pas de grille officielle complète | Pas de `Départ dans X min` garanti en prod avant dataset OFFICIAL_STATIC |
| Aucun `REAL_TIME` | `0` | Pas de prédiction temps réel |
| Fenêtre unique | `20260927` | Hors dim, repli fréquence |
| Mise à jour non live | Pas de Timer en 4.9 | Label figé jusqu'à nouvelle recherche — non trompeur, prévu §10 |
| Autres écrans non branchés | `Explorer`/`Alertes`/`IA` volontairement non touchés | Seul `Trajets` affiche l'horaire (§15 respecté) |

## 14. Prochaine étape

1. Étendre `ScheduleStatus` Dart avec `partiallyConfirmed` (ajout rétrocompatible) et mapper `PARTIALLY_CONFIRMED` JS → Dart avec indicateur discret `ⓘ partiellement confirmé` en UI (garde §6).
2. Fournir `ScheduleDataset` `OFFICIAL_STATIC` (TER complet + BRT grilles si publiées) et brancher `InMemoryScheduleProvider` derrière feature-flag — Trajets affichera alors `SCHEDULED` sans changement widget.
3. Brancher `RealtimeProvider` GTFS-RT frais → `🟢 Arrivée dans 3 min`.
4. Ajouter `Timer.periodic(30s)` dans `TripsPage` qui relance `RoutePlanner.plan(at: DateTime.now().toUtc())` — même architecture, affichage live minimal.
5. lot UI suivant : propager le même helper à `DetailedRoutePage` et fiche arrêt (toujours hors `Explorer` général).

---

### Exemples réels issus du moteur (Lot 4.9)

| Requête | `queryDeparture` | UI Trajets |
|---|---|---|
| TER `ter_dakar_diamniadio` `stop_dakar_ter` dim 08:17 | `PARTIALLY_CONFIRMED 08:25:00` `nextDepartureAt 2026-09-27T08:25:00Z` | `🟢 Départ dans 8 min` |
| BRT `brt_b1` any 08:17 | `ESTIMATED 6` | `🟡 Passage estimé toutes les 6 min` |
| BRT `brt_b2` any 08:17 | `ESTIMATED 6` | `🟡 Passage estimé toutes les 6 min` |
| BRT `brt_b3` any | `UNKNOWN` | `Horaire indisponible` |
| DDD `ddd_1` any | `UNKNOWN` | `Horaire indisponible` |
| AFTU `aftu_1` any | `UNKNOWN` | `Horaire indisponible` |

*UI Trajets branchée sur `DepartureInfo` sans recalcul, sans redesign, sans toucher Explorer/GPS/RoutePlanner/cartographie.*
