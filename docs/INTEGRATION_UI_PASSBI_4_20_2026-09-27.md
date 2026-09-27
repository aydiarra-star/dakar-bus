# Intégration UI du moteur PassBi — Lot 4.20

**Date :** 2026-09-27
**Branche :** `arena/01a0e370-dakar-bus`
**Objet :** connexion des résultats du moteur PassBi (Lot 4.19) aux écrans
Flutter existants — prochains départs et itinéraires affichés depuis
`GTFS → PassBiSource → ScheduleProvider → RoutingEngine → EtaCalculator →
modèle → UI`, au lieu des candidats/horaires/historique codés en dur.

Aucun changement de design, de navigation, de boutons, de couleurs, de
cartographie (MarkerLayer/PolylineLayer), de GPS, de filtres ou d'apparence.

---

## 1. Fichiers modifiés

| Fichier | Nature du changement |
|---|---|
| `flutter-src/lib/main.dart` | Seule modification de code (voir §2) |
| `flutter-src/test/passbi_ui_integration_420_test.dart` | **Nouveau** — tests d'intégration §12 (A–I) |
| `docs/INTEGRATION_UI_PASSBI_4_20_2026-09-27.md` | Ce document |

Aucun autre fichier touché : `data/gtfs/` (legacy), `data/transit/passbi/`,
les assets GTFS, les services (`data_service`, `eta_calculator`,
`schedule_provider`, `routing_engine`, `passbi_source`) et les modèles sont
inchangés par rapport au Lot 4.19 (commit `d201aed`).

## 2. Chaîne DATA → ROUTING → UI (points d'intégration audités)

Audit initial (§1) — données hardcodées / fréquences génériques / candidats
historiques / placeholder / fake ETA / résultat statique → traitement :

1. **`plan()` (RoutePlanner)** — les résultats du moteur PassBi sont
   calculés en priorité. Les candidats legacy (durée distance/vitesse,
   heures de fréquence) ne sont proposés **que si le moteur ne trouve
   aucun chemin**, et jamais en concurrence d'un résultat réel.
   `_findTransfer` inchangé.
2. **`_plannedFromPassBi`** — chaque tronçon d'un trajet moteur porte
   désormais un `DepartureInfo` complet :
   * statut **`ScheduleStatus.scheduled` strict** (jamais `realTime`) ;
   * `scheduledTime` = heure réelle du `stop_sequence` du trip (y compris
     passage J+1) ;
   * ETA (`estimatedWaitFrom`) = temps d'attente calculé à l'instant de la
     requête par le moteur, jamais `0` artificiel (→ libellé
     « moins d'une minute » si ≤ 0) ;
   * `source` = `PassBiSource.sourceUrl`, `sourceType = publicGtfs`,
     métadonnées du réseau (`date_source`, `date_verified`, `valid_from`,
     `valid_to`) ;
   * `frequencyMinutes` / `operatingHours` = `null` (une fréquence n'est
     jamais un départ) ;
   * `direction` = `tripDirectionOf(leg)` — direction_id/headsign **lu dans
     le feed**, `null` si absent (jamais déduit).
3. **Identité de ligne** — `passBiLineLabel()` : strictement les ids du
   feed. `BRT B1` / `BRT B2` (deux routes distinctes, pas de B3),
   `DDD_01`…, `AFTU_3`… ; le `route_id` TER (UUID) s'affiche sous son
   réseau seul — aucun numéro déduit d'un identifiant. Le sens du tronçon
   vient de `tripDirectionOf()` (ou `null`).
4. **`_buildRoute` (candidat direct legacy)** — `dep` utilise désormais le
   `scheduledTime` (SCHEDULED) quand PassBi connaît le départ ; les
   horaires réels s'affichent au lieu de l'historique codé en dur ;
   `ESTIMATED` reste **sans heure** (fréquence ≠ départ).
5. **Écran Explorer (`_RouteCard`)** — ligne « 🟢 » dynamique sous le
   nombre d'étapes, affichée **uniquement** si le premier tronçon est
   `scheduled`, libellé exact du moteur (`Prochain départ dans X min` /
   `moins d'une minute`), couleur `AppColors.success`. Jamais `0 min`
   non immédiat, jamais `0–20 min`, jamais « Live ».
6. **Fiche ligne (`DetailedRoutePage`, arrêts)** — le placeholder fixe
   `scheduleUnavailable` est remplacé par
   `appDataService.departureFor(routeId, stopId, network).label` :
   SCHEDULED → prochain départ réel (couleur de la ligne) ; sinon repli
   honnête `Horaire indisponible`.
7. **Assistant IA** — itinéraire : branche `scheduled && departureInfo != null`
   → « 🕒 <label> — horaire programmé » (avant la branche estimée).
8. **Réglages** — textes « Comment utiliser » et « Conditions » alignés :
   les horaires PassBi sont des programmations SCHEDULED issues de GTFS
   publics, jamais présentés en temps réel. `modeInfo` (verrouillé par
   les tests existants) inchangé.

Horloge (§11) : en production, l'heure courante (`DateTime.now()` /
`departureInfoForNow`) ; en tests, heures simulées 4.19 passées en `at:`.

## 3. Réseaux couverts

| Réseau | Statut dans l'UI intégrée |
|---|---|
| **TER** (`ter_dakar_diamniadio`) | MAPPÉ → SCHEDULED, heures réelles, sens UUID TER affiché « TER » |
| **BRT B1** (`brt_b1_guediawaye_petersen`) | MAPPÉ → SCHEDULED, label « BRT B1 », sens = headsign |
| **BRT B2** (`brt_b2_express`) | MAPPÉ → SCHEDULED, label « BRT B2 », départs **distincts** de B1 |
| **DDD** (`ddd_*`) | UNMAPPED (aucune identité confirmée) → **UNKNOWN honnête** « Horaire indisponible » — jamais de fréquence transformée en ETA (aucune fréquence n'est publiée pour DDD) |
| **AFTU** (`aftu_8`, `aftu_11`) | MAPPÉ → SCHEDULED (ex. aftu_8 stop_yoff → AFTU_3) ; autres lignes AFTU → UNKNOWN honnête (pas de fréquence) |

B3 n'existe pas dans le feed intégré et n'est jamais déduit.

## 4. Statut et hiérarchie ETA (§4)

* **REAL_TIME** : impossible — `EtaCalculator.hasRealtimeFeed = false`,
  aucune source temps réel réelle n'est accessible ; `DepartureInfo`
  interdit `realTime` par assertion.
* **SCHEDULED (PassBi)** : prochain départ issu de
  route → trip → service → date/jour → stop → stop_sequence ; présentation
  « Prochain départ dans X min » (0 → « moins d'une minute »).
* **ESTIMATED (fréquences officielles legacy)** : uniquement sur les
  lignes sans mappage PassBi et seulement là où une fréquence publiée
  existe (B1/B2/TER legacy) ; sans heure fixe.
* **🔴 interruption** : statut dédié inchangé (aucune donnée d'intégration
  ne l'alimente — rien n'est simulé).
* **UNKNOWN** : « Horaire indisponible », réservé aux identités que PassBi
  ne permet pas encore de calculer (mappage UNMAPPED sans fréquence) —
  les UNKNOWN **artificiels** que PassBi permet désormais de résoudre
  (TER, B1, B2, aftu_8, itinéraires J+1…) ont été supprimés de l'UI.

## 5. Correspondances (§7)

Les correspondances affichées proviennent **exclusivement** de
`PassBiRoutingEngine` (liens géographiques/directions/délais/horaires du
crosswalk PassBi). Aucune logique de proximité n'est ajoutée dans les
widgets ; aucun lien impossible (TER→bus sans relation, BRT→TER arrêt
artificiel, AFTU→DDD inventé, B1/B2 fusionnés) n'est produit. Le repli
legacy `_findTransfer` n'est utilisé que si le moteur ne trouve rien.

## 6. Tests (§12)

**Nouveau : `flutter-src/test/passbi_ui_integration_420_test.dart`** —
matrice A–I, PassBi chargé en `setUpAll` isolé (les tests verrous
existants ne chargent jamais PassBi et restent verts tels quels) :

| # | Scoupe | Assertion clé |
|---|---|---|
| A | TER Colobane lundi 12:00 | SCHEDULED `12:11:25`, ETA 11 min, `publicGtfs` + widget `StopCard` affiche « Prochain départ dans » |
| B | BRT B1 Petersen lundi 14:00 | départ `14:00:30` (jamais l'arrivée), ETA 0 → « moins d'une minute » + libellés `passBiLineLabel` (`BRT B1`, `BRT B2`, `DDD_01`, `AFTU_3`, TER UUID → « TER ») |
| C | B1 vs B2 même arrêt | `14:00:30` ≠ `14:03:30`, routeIds distincts, **aucun B3** dans le feed |
| D | DDD `ddd_1` | mapping `UNMAPPED`, `pbRouteIds` vides → UNKNOWN « Horaire indisponible », `frequencyMinutes == null` |
| E | AFTU `aftu_8` mappé | SCHEDULED `10:09:39` ETA 9 min ; `aftu_12` non mappé → UNKNOWN honnête |
| F | Correspondance BRT B1 → AFTU | `plan()` retourne un trajet `transferCount ≥ 1` du **moteur**, segments `BRT B1` / `AFTU*`, tous `SCHEDULED` avec ETA |
| G | Dimanche 23:59 → J+1 | SCHEDULED lundi `05:35:30`, ETA 336 min (Lot 4.19 conservé) |
| H | Terminus | départ `14:00:30` ≠ arrivée `14:02:27` (Bug A) |
| I | Horizon | Colobane → Diamniadio 23:59 : segments `05 h 35` → `06 h 15`, embarquement dans l'horizon, arrivée au-delà conservée (Bug C) |

Garde-fous communs : aucun statut `realTime`, aucun libellé
« Prochain départ dans 0 min », aucun « Live », aucune fréquence sur un
statut SCHEDULED.

**Correction démontrée (test 4.19)** : `passbi_functional_419_test.dart`
attendait `j.arrivalSec == 108309` alors que le commentaire, le GTFS brut
(Diamniadio `departure_time 06:15:09` de trip `…5:35:00 AM-a25f062d…`) et
le code moteur (`absArr = rst.departureSec + offset`,
`routing_engine.dart`) donnent **108909**. Faute de frappe isolée corrigée
en `108909` — aucun code produit modifié (règle 4.19 : bug démontré
d'abord).

**Régression** (inchangés et verts) :
* `npm test` → **63/63** (21 passbi-gtfs + 18 passbi-functional-419 + 24 legacy)
* `npm run check:arrets` → sortie strictement identique au baseline
  (EXIT=1 conservé — le script historique n'est **pas** modifié pour
  atteindre EXIT=0)

## 7. Limites assumées

* **DDD et lignes AFTU non mappées** : `Horaire indisponible` (UNKNOWN
  honnête) — aucun horaire n'est inventé tant qu'aucune identité/ressource
  source n'est fournie.
* **TER** : sens d'affichage = réseau « TER » (les `route_id` sont des UUID
  sans numéro exploitable ; aucun sens n'est déduit).
* **Pas de temps réel** : aucun flux GTFS-RT ni API PassBi accessible
  (service PassBi suspendu, constaté le 2026-09-27) ; les données GTFS
  PassBi sont la base opérationnelle, dates d'origine conservées en
  métadonnées (`date_source`, `valid_from`, `valid_to`) sans falsification.
* La vérification Flutter (`analyze` / `test` / `build`) repose sur la CI
  du dépôt : **aucun exécutable Flutter/Dart n'est disponible dans
  l'environnement local** ; aucune vérification CI n'est revendiquée ici
  (la branche n'a encore exécuté aucune workflow à ce jour).

## 8. CI attendue

* Analyse, tests et build web Flutter via `flutter-web-build.yml`
  (Flutter 3.24.5) lors du prochain push de la branche.
* Résultat **non encore exécuté** à date de rédaction : aucun run CI n'est
  revendiqué (§14 — ne pas inventer de résultat CI).
* Aucun push ni merge effectué ; **PR #31 inchangée**.

## 9. Engagement d'honnêteté (§15)

Aucune modification de `data/gtfs/` legacy, de GPS, `PositionValidity`,
`DakarBounds`, cartographie ou `dakar_network.json` ; aucun horaire,
correspondance, direction, ligne ni prix inventés ; aucune parallélisation
de la logique d'itinéraire hors `ScheduleProvider`/`RoutingEngine` ;
PassBi n'est jamais présenté comme temps réel ; B1/B2 restent distincts ;
B3 jamais déduit ; les dates originales des feeds sont conservées en
métadonnées.
