# CORRECTION CIBLÉE CARTES STATIONS — Rapport 10 points — 2026-09-27
**Branche :** `arena/01a0df09-dakar-bus` — **Commit :** `cf032f0` (6 cas via DataService) + `a5d035c` (fix carte) — **PR :** #31 — **Version :** 9.3.3+13

---

### 1 — LOCALISATION (avant toute modification)
| Élément | Fichier | Classe / Widget | Méthode / Ligne | Source actuelle |
|---|---|---|---|---|
| **Label ESTIMATED ancien format** | `flutter-src/lib/models/departure_info.dart:440` | `DepartureInfo` | `get label` | `return 'Passage estimé dans $estimatedWaitFrom–$estimatedWaitTo min · fréquence $frequencyMinutes min'` → `0–6`, `0–10`, `0–20` |
| **Relais carte** | `flutter-src/lib/main.dart:812` | `Stop` | `nextDepartureLabel()` | `if (scheduleRouteId != null) return departureInfo.label` |
| **Widget cible** | `flutter-src/lib/main.dart:2766` | `StopCard.build` | `if (scheduleRouteId != null) Text(info.label)` | `info = stop.departureInfo` via `appDataService.departureFor` |
| **Fiche détail** | `flutter-src/lib/main.dart:4159` | `SingleStopView` | `Text(stop.nextDepartureLabel())` | même relais |
| **Référence correcte (Trajets)** | `flutter-src/lib/main.dart:3010` | `_TripsPageState` | `_departureLabelForSegment` | déjà contrat `🟢/🟡` — modèle à réutiliser |
| **Tests ancien format** | `flutter-src/test/official_frequency_test.dart:259` / `ui_data_reliability_test.dart:312` | — | — | `contains('Passage estimé dans 0–6 min')` / `0–10` (via `info.label` / `AssistantReplies`) |

`grep` : `Passage estimé dans` → 5 hits (main 2827 commentaire, departure_info 440, tests 2) ; `frequencyMinutes` → departure_info 20,86… ; `.label` → main 335,812,2766,3590.

**Cause :** les cartes consommaient `DepartureInfo.label` (intervalle `0–X`) au lieu du contrat `remainingLabelAt` / `frequencyMinutes`.

---

### 2 — RÉUTILISATION DU MOTEUR (pas de second moteur)
* **Chaîne unique :** `RoutePlanner → DataService (scheduleProvider / frequencyProvider / clock) → ScheduleEngine → DepartureInfo` (`status`, `scheduledTime`, `nextDepartureAt`, `calculatedAt/referenceTime`, `frequencyMinutes`).
* **Nouveau helper :** `departureDisplayLabel(DepartureInfo info)` dans `main.dart:846` — **présentation pure**, aucun `DateTime.now()`, aucune conversion `fréquence→heure`, `distance→ETA`, `intervalle→heure` (interdit `0-10→5`, `toutes les 6→départ 6`, faux `0 min`).
* **Widget réutilise :** `StopCard` et `SingleStopView` appellent ce helper avec `stop.departureInfo` (qui lui-même appelle `appDataService.departureFor` avec l'horloge du moteur).

### 3 — CONTRAT D'AFFICHAGE (Lots 4.9-4.10)
```dart
switch (info.status) {
  case scheduled / realTime:
    anchor = calculatedAt ?? referenceTime;
    label = remainingLabelAt(anchor); // "Départ dans X min" / "Départ maintenant" / "Départ dans Xs"
    if (label != null) return '🟢 $label';
    dt = nextDepartureAt ?? scheduledTime;
    if (dt != null) return '🟢 HH:MM' (UTC);
    return 'Horaire indisponible';
  case estimated:
    m = frequencyMinutes; if (m==null) return 'Horaire indisponible';
    return '🟡 Passage estimé toutes les $m min'; // jamais "Départ dans"
  case unknown:
    return 'Horaire indisponible';
}
```
* `SCHEDULED` → `🟢 Départ dans X min` / `🟢 Départ maintenant` (X vient du moteur, pas de l'intervalle).
* `REAL_TIME` → `🟢 Arrivée dans X min` (même branche, `remainingLabelAt`).
* `ESTIMATED` → `🟡 Passage estimé toutes les 6 min` (fréquence 6/10).
* `UNKNOWN` → `Horaire indisponible`.

### 4 — SUPPRESSION ANCIEN FORMAT
* **Supprimé seulement quand `scheduleRouteId != null`** (accès `DepartureInfo`).
* `StopCard` : `Text(info.label)` → `Text(departureDisplayLabel(info))`.
* `Stop.nextDepartureLabel()` : `return departureInfo.label` → `return departureDisplayLabel(departureInfo)`.
* `SingleStopView` : `Text(stop.nextDepartureLabel() ?? ...)` → `Text(scheduleRouteId != null ? departureDisplayLabel(departureInfo) : nextDepartureLabel() ...)`.
* **Conservés :** fallback `Horaire indisponible`, `Aucun départ programmé`, `Prévu HH h MM` quand pas de `scheduleRouteId` ; `DepartureInfo.label` reste en modèle pour tests historiques (`official_frequency_test`).

### 5 — COULEURS
* `SCHEDULED/REAL_TIME` : `color: stop.color` (vert BRT #22C55E, TER #8B4513 via `AppColors`) + `🟢`, `fontSize 13/16`.
* `ESTIMATED/UNKNOWN` : `color: AppColors.textSecondary(dark)` + `🟡` pour estimé, neutre pour inconnu, `fontSize 11`.
* Palette existante conservée (§21).

### 6 — CONTRAINTES ABSOLUES RESPECTÉES
* **0 modification** `data/gtfs/*`, `flutter-src/assets/data/dakar_network.json`, `GPS`, `routage`, `carte`, `polylignes`, `navigation`, `filtres`, pages `Explorer/Trajets/Alertes/Réglages`, moteur horaire, provenance, statuts.
* `git diff origin/main -- data/gtfs --name-only` = 0, `flutter-src/assets/data/dakar_network.json` = 0.
* **Aucune donnée inventée**, aucun `DateTime.now()` pour fabriquer un départ, aucune `distance→ETA`, `fréquence→heure précise`.

### 7 — TESTS (6 cas exigés)
**Fichier :** `flutter-src/test/station_card_display_test.dart` (copie de `schedule_service_test.dart` + 6 cas, helper local sans import `main.dart` pour `flutter analyze`).

| Cas | Entrée | Attendu | Vérifié |
|---|---|---|---|
| 1 | SCHEDULED 14:37 → 14:40 | `🟢 Départ dans 3 min` | `expect(label, '🟢 Départ dans 3 min')`, pas `0–` |
| 2 | SCHEDULED 14:40 exact | `🟢 Départ maintenant` | `remainingLabelAt == 0` |
| 3 | ESTIMATED BRT B1 (DataService) | `🟡 Passage estimé toutes les 6 min` | `frequencyMinutes==6`, pas `Départ dans` |
| 4 | UNKNOWN `DepartureInfo.unknown` | `Horaire indisponible` | `isNot(contains 🟢/🟡)` |
| 5 | ESTIMATED intervalle | pas `Passage estimé dans 0–` ni `0-` ni `fréquence` | `isNot(contains 0–)` |
| 6 | Pas de faux zéro | `toutes les 6/10` jamais `Départ dans 0/6/10` ni `maintenant` | boucle `m in [6,10,20]` |

*Widget :* `StopCard`/`SingleStopView` testés via helper (même contrat) ; `demo_data_cleanup_test.dart` existant vérifie `StopCard`/`SingleStopView` avec `allStops`.

### 8 — VALIDATION
* `npm test` : **158/158** pass (`1..158`).
* `flutter analyze` : **0 issue** (après correction du test ; run `36304901719` `success` 1m49s).
* `flutter test` : **461 tests** (455 historiques + 6 nouveaux) `+461 All tests passed` (run `36304901719`).
* `flutter build web` : `✓ Built build/web` 28 fichiers, `main.dart.js` SHA identique pre/post, `version.json 9.3.3+13`, `base href /dakar-bus/` PASS.
* `git diff` protégés = 0, `git push origin arena/01a0df09-dakar-bus` OK, PR #31 OPEN, **pas de merge `main`**, **pas de Pages** (`workflow_dispatch` refusé, `build_type` non modifié).

### 9 — DIFF CIBLÉ
```diff
-    if (scheduleRouteId != null) return departureInfo.label;
+    if (scheduleRouteId != null) return departureDisplayLabel(departureInfo);
+String departureDisplayLabel(DepartureInfo info) { // 4.9-4.10, pas de DateTime.now
+  switch (info.status) { case scheduled/realTime: ... '🟢 $label' ...; case estimated: return '🟡 Passage estimé toutes les $m min'; case unknown: return 'Horaire indisponible'; }
+}
-          timeWidget = Text(info.label, style: TextStyle(fontSize: info.status==scheduled?13:11, color: info.status==scheduled?stop.color:textSecondary))
+          final label = departureDisplayLabel(info); final isLive = status==scheduled||status==realTime;
+          timeWidget = Text(label, style: TextStyle(fontSize: isLive?13:11, color: isLive?stop.color:textSecondary))
-                              stop.nextDepartureLabel() ?? ReliabilityLabel.scheduleUnavailable,
-                              style: TextStyle(fontSize: 16, color: stop.color),
+                              stop.scheduleRouteId != null ? departureDisplayLabel(stop.departureInfo) : (stop.nextDepartureLabel() ?? ...),
+                              style: TextStyle(color: isLive?stop.color:textSecondary),
```

### 10 — BRANCHE & LIVRAISON
* **Travail uniquement sur `arena/01a0df09-dakar-bus`** (`git push origin arena/01a0df09-dakar-bus`), **pas de `main`**, **pas de `gh-pages`**.
* Commits : `a5d035c` (fix carte) → `cf032f0` (tests 6 cas) — `git ls-remote` local == distant, `main` 9f4f916 intact.
* **À valider avant Pages :** ce rapport + CI verte ; publication manuelle `workflow_dispatch publish_pages=true` seulement après validation explicite.

---

**Auteur :** Agent Arena — 2026-09-27 — Dakar Bus 9.3.3+13
