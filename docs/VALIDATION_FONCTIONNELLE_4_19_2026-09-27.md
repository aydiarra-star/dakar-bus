# Validation fonctionnelle réelle — Lot 4.19

**Date :** 2026-09-27 · **Branche :** `arena/01a0e370-dakar-bus` · **Base :** Lot 4.18 (`4038c91`)
**Objet :** validation fonctionnelle des itinéraires et ETA sur les feeds PassBi réels (TER, BRT B1/B2, DDD, AFTU), correction ciblée des bugs démontrés, rapport §18.

---

## 1. Contexte et périmètre

- PassBi feeds = base opérationnelle (TER, BRT B1/B2, DDD, AFTU actifs). Aucune ré-audit de sources, aucune nouvelle donnée, aucun contact opérateur, aucune modification des GTFS bruts (`data/gtfs/`, `data/transit/passbi/` intacts), aucun changement GPS/UI (données affichées uniquement).
- Lot de validation-et-correction : seuls les bugs **démontrés** par un test sont corrigés, selon le protocole §17 : fichier → cause → périmètre 4.19 → **test de régression d'abord** → correctif → re-test. Les erreurs historiques `check:arrets` ne sont pas touchées ; aucune donnée éditée pour faire passer un test.
- Exigences : §1–§13 matrice fonctionnelle, §14 validations, §15 UI (documentée), §16 critères de succès, §18 ce rapport, §19 commit uniquement si corrections, **pas de push, pas de merge, PR #31 inchangée**.

## 2. Méthode

- **Miroir Node** `tests/helpers/passbi-engine419.mjs` : port fidèle de `gtfs_source` / `schedule_provider` / `routing_engine` sur les assets réels, permettant d'exécuter la matrice §1–§13 sans SDK Flutter (absent de l'environnement ; `flutter analyze/test/build` → **CI**).
- **Fixtures recalculées indépendamment** sur les GTFS bruts (arrêts, séquences, horaires) — jamais reprises du code testé.
- **Ordre stricte** : les tests de régression (Node `tests/passbi-functional-419.test.js`) ont été écrits et exécutés **avant** les correctifs Dart ; les correctifs ont ensuite été appliqués à la couche de production et aux contrepars Dart (`passbi_functional_419_test.dart`).
- Trois bugs démontrés (détail §8) : **A** départs non embarquables, **B** passage de minuit, **C** horizon sur l'arrivée.

## 3. Résultats §1 — TER direct

| Réseau | Route | Origine | Destination | Trip | Heure simulée | Prochain départ | ETA | Résultat |
|---|---|---|---|---|---|---|---|---|
| TER | 544a27a5…→4445e51b… (Dakar–Diamniadio, dir 1, headsign « Diamniadio ») | Dakar - Gare ferroviaire | Diamniadio | `2025-35-12:06:00 PM-28818422-0555-187a-d6a…` | lun. 12:00 | 12:06:00 | 12:51:29 (dép. 12:06, arr. 12:51) | ✅ route/trip/direction/stop_sequence (Dakar<Colobane<Diamniadio) et horaires cohérents ; 0 correspondance |
| TER | même (sens PETERSEN→…) | Dakar - Gare ferroviaire | Colobane | idem | lun. 12:00 | 12:06:00 | arr. 12:11:25 | ✅ |
| TER | même | Colobane | Diamniadio | idem | lun. 12:00 | **12:11:25** (wait 11 min) | arr. 12:51:29 | ✅ prochain départ + ETA calculés |
| TER | 4445e51b…→544a27a5… (dir 0, « Dakar - Gare ferroviaire ») | Rufisque | Dakar - Gare ferroviaire | `2025-35-11:54:00 AM-483c9987-70c9-4376-a4b…` | lun. 12:00 | 12:02:59 | arr. 12:39:58 | ✅ « si les données permettent » : données présentes, sens retour validé |

## 4. Résultats §2–§5 — Lignes (B1, B2, DDD, AFTU)

| Réseau | Route | Origine | Destination | Trip | Heure simulée | Prochain départ | ETA | Résultat |
|---|---|---|---|---|---|---|---|---|
| BRT | B1 (headsign PETERSEN) | Guédiawaye (GDWB) | Petersen (PGFB) | — | lun. 12:00 | 12:00:30 | arr. 12:56:27 | ✅ legs mono-route, jamais d'ETA B2 |
| BRT | **B1 uniquement** (OD exclusif) | Golf Nord (GNOA) | Petersen (PGFB) | `0_11461601` | lun. 12:00 | 12:05:03 | arr. 12:56:27 | ✅ §2 : station intermédiaire, route = B1, seq croissante, ETA dynamique |
| BRT | B1 | Grand Dakar (GDAB) | — | — | **13:29** | 13:32:04 | **🟢 3 min** | ✅ « Prochain départ dans 3 min » (calculé, non codé en dur) |
| BRT | B2 (7 stations express, seq PGFA→…→GDWA croissante, headsign GUEDIAWAYE) | Guédiawaye (GDWA) | — | trips B2 (800+) | lun. **14:00** | **14:03:30** (50610, quai sœur GDWB) | 3 min | ✅ §3 : B1 14:00:30 (50430) ≠ B2 14:03:30 — aucune réutilisation croisée ; **B3 absent** du feed |
| DDD | DDD_01 (Terminus Parcelles Assaines→Terminus Leclerc, dir 1) | D_805 | D_140 | `DDD_01_PARCELLES-ASSAINIES_LAV_14` | lun. 10:00 | 10:20:00 | arr. 11:43:06 | ✅ §4 : identité UI `ddd_1` reste UNMAPPED (aucune identité forcée), ligne exploitable sous son id PassBi |
| DDD | DDD_403 (→ Terminus Diamniadio) | D_805 | D_1216 | `DDD_403_…` | mar. 08:00 | 08:10:00 (29400) | — | ✅ 2ᵉ ligne DDD validée |
| AFTU | AFTU_1 (Terminus 1 Face Keur Yoff→Lat Dior, dir 1) | A_916 | A_1601 | — | lun. 08:00 | **08:15:09** (29709, embarquable) | — | ✅ §5 (l'ancien 08:01:53 était une ARRIVÉE — voir Bug A) |
| AFTU | AFTU_3 / AFTU_4 (services parallèles, Petersen 1→Yoff) | A_1633 | A_1250 | `AFTU_4_Petersen_27` | lun. 10:00 | 10:11:29 | arr. 11:02:01 | ✅ 2ᵉ route AFTU + direction_id du feed vérifiés ; direction : AFTU/DDD = direction_id (headsigns vides — limite feed, rien inventé) |

## 5. Résultats §6–§8 — Correspondances (jamais par proximité seule)

| Réseau | Route | Origine | Destination | Trip | Heure simulée | Prochain départ | ETA | Résultat |
|---|---|---|---|---|---|---|---|---|
| BRT→DDD | B1 + DDD_219 | Golf Nord (GNOA, aucun lien DDD direct) | D_449 | `0_11461581` + DDD_219 | lun. 10:00 | 10:05:03 | arr. 10:28:22 (tc=1) | ✅ §6 : lien crosswalk documenté entre jambes ; **2e départ ≥ arrivée 1er véhicule + marche** (arr. 10:16:55 → 2e dép. 10:23:05 ≥ +60 s) — aucun transfert temporellement impossible |
| BRT→AFTU | B1 + AFTU_2 | Golf Nord (GNOA, sans lien AFTU au départ) | A_608 | `0_11461581` + AFTU_2 | lun. 10:00 | 10:05:03 | arr. 10:48:59 (tc=1) | ✅ §7 : même contrôle d'atteignabilité ; liaison documentée (KYAB↔A_1792, 67 m) |
| TER→DDD | TER + DDD_402 | Dakar gare (**aucun lien direct** — contrôlé) | D_325 | `2025-35-10:06:00 AM-b1e8c148…` + DDD_402 | lun. 10:00 | 10:06:00 | arr. 10:39:46 (tc=1) | ✅ §8 : 1er leg = TER obligatoire ; correspondance via liens Keur Mbaye Fall gare (≤ 500 m, nom vérifié) ; temporalité tenue |
| TER→AFTU | TER + AFTU_65 | Dakar gare | A_548 | `2025-35-10:06:00 AM-b1e8c148…` + AFTU_65 | lun. 10:00 | 10:06:00 | arr. 11:12:47 (tc=1) | ✅ idem : aucune correspondance TER↔bus inventée par proximité |

## 6. Résultats §9–§12 — ETA, jour suivant, absence de données, statut

| Réseau | Route | Origine | Destination | Trip | Heure simulée | Prochain départ | ETA | Résultat |
|---|---|---|---|---|---|---|---|---|
| BRT | B1 | Grand Dakar | — | — | **13:29** | 13:32:04 | **🟢 3 min** (label « Prochain départ dans 3 min ») | ✅ §9 cas nominal |
| TER | 6 routes TER | Colobane | — | — | **13:29** | 13:35:12 | **🟢 6 min** (label « Prochain départ dans 6 min ») | ✅ §9 cas 6 min exact |
| TER | idem | Colobane | — | — | 13:29:**30** | 13:35:12 | **5 min** | ✅ §9 dynamique : 30 s d'écart → ETA différente ; 0 s → 6 min. Aucune valeur codée en dur, aucune fréquence convertie (valeur = ligne `stop_times` réelle 48912/48724) |
| BRT | B1 | Petersen | — | — | lun. 14:00 | **14:00:30** | « Prochain départ dans moins d'une minute » (wait 0) | ✅ jamais « 0 min » pseudo temps réel |
| TER | 6 routes TER | Colobane | — | change de `service_id` (`…8:05:00 PM…` dim. → `…5:30:00 AM…` lun.) | **dim. 23:59** | **05:35:30 J+1** (abs 106530) | **336 min** | ✅ §10 ETA : prochain service retrouvé après minuit via calendar + calendar_dates |
| BRT | B1 | Petersen | — | via quai sœur PGFA | dim. 23:59 | **06:00:30 J+1** (abs 108030) | 361 min | ✅ §10 |
| TER | — | Colobane | Diamniadio | `2025-35-5:30:00 AM-a25f062d…` (**autre trip que le jour**) | dim. 23:59 | embarq. **05:35:30 J+1** | arr. **06:15:09 J+1** | ✅ §10 moteur : itinéraire J+1 complet (au-delà de l'horizon d'arrivée — Bug C) |
| — | `ddd_1` (UNMAPPED) | Petersen | — | — | lun. 12:00 | aucune donnée | — | ✅ §11 : `provider → null`, zéro route rattachée, rien d'inventé |
| BRT | B1/B2 | GUEULE TAPEE (`0:GTAB`, 0 rows) | Diamniadio | — | lun. 12:00 | aucun | — | ✅ §11 : départ null + **0 trajet** au moteur (jamais « 0 min », retard, interruption, fréquence ni faux horaire) |
| TER | 6 routes TER | Colobane | — | — | lun. 12:00 | 12:11:25 | 11 min, `SCHEDULED` | ✅ §12 : horaire PassBi programmé → jamais 🟡 retard ; métadonnées « jamais REAL_TIME », `PUBLIC_GTFS`, aucun champ de prédiction dans les 4 feeds |

## 7. Résultat §13 — Identités séparées

| Contrôle | Résultat |
|---|---|
| TER ∩ BRT = ∅ ; B1 ∉ TER ; B3 absent du feed BRT ; BRT ∩ DDD = ∅ ; DDD ∩ AFTU = ∅ | ✅ |
| `brt_b1… → ['B1']` ≠ `brt_b2_express → ['B2']` (ids PassBi distincts) | ✅ |
| Chaque réseau ne référence que ses propres routes (trips ↔ routes cohérents sur les 4 feeds) ; crosswalk mapped = réseau propre | ✅ |

## 8. Bugs démontrés et correctifs (protocole §17)

### Bug A — départs non embarquables affichés comme « prochain départ »
- **Fichier :** `flutter-src/lib/services/gtfs/gtfs_source.dart` (`nextDepartureSec`, `departuresSecOn`).
- **Cause :** aucune vérification que le trip **continue après l'arrêt** : sur un quai d'arrivée (PGFB, GDWA, A_916 en sens inverse), la première ligne > t est une ARRIVÉE de terminus (ex. B1@PGFB **50547** = 14:02:27 = arrivée, alors que le vrai départ PGFA est **50430** = 14:00:30 ; B2@GDWA **50730** vs départ réel GDWB **50610** ; AFTU_1@A_916 08:01:53 = arrivée du sens inverse).
- **Périmètre :** ETA/next-departure PassBi (4 feeds), fournies par le provider.
- **Test de régression AVANT correctif :** `tests/passbi-functional-419.test.js` §2 (« départ EMBARQUABLE » : brut 50547 préservé en exposition du bug, rideable = 0 ligne sur PGFA corrigé… et sœur PGFA → 50430), §3, §5, §9, + Dart `passbi_functional_419_test.dart` §2.
- **Correctif :** garde `_tripContinuesPast` (stop_sequence < dernière séquence du trip) sur `nextDepartureSec` et `departuresSecOn` ; `PassBiSource.siblingStops` (plateformes sœurs : liens crosswalk ≤ 30 m, **même réseau**, construits avec vérification d'égalité de nom) + boucle candidates dans `ScheduleProvider` — le départ se lit sur le quai de départ sœur documenté.
- **Re-test :** 18/18 Node + Dart §2/§3/§5/§9 verts ; attentes 4.18 mises à jour (voir §9).

### Bug B — passage 23:59 → 00:00 sans prochain service
- **Fichier :** `gtfs_source.dart` (`nextDepartureSec` : scan J only) et `routing_engine.dart` (`planJourneys` : BFS sur un seul jour).
- **Cause :** le scan ne couvrait que le jour de la requête ; au-delà du dernier départ du jour → `null` (ETA) et `[]` (moteur), même si le service J+1 existe (service_id, calendar, calendar_dates, jours sans service évalués sur le mauvais jour).
- **Périmètre :** ETA + moteur d'itinéraires (4 feeds).
- **Test de régression AVANT correctif :** Node §10 (dim. 23:59 → 106530 / 108030 ; moteur → 05:35:30 J+1) ; Dart §10.
- **Correctif :** `nextDepartureSec` : scan **7 jours glissants**, retour absolu depuis minuit J0 (`best + d*86400` — `scheduledTime = day0 + bestSec` place donc le service le bon jour) ; moteur : **deux passes J puis J+1** (`_searchDay`, axe ancré à minuit J0, offset jour sur les horaires), résultats fusionnés triés par arrivée.
- **Re-test :** §10 vert (ETA 336/361 min, trip J+1 `…5:30:00 AM…` ≠ trip dimanche `…8:05:00 PM…` = changement de service_id réel, jours sans service via `calendar_dates` : lundi de Pâques LAV retiré → FULL assure le service).

### Bug C — horizon 6 h tranchant sur l'ARRIVÉE (moteur)
- **Fichier :** `routing_engine.dart` (`planJourneys`).
- **Cause :** `if (rst.departureSec > deadline) break;` dans la boucle des arrêts du trip : un trajet **embarqué** dans l'horizon (05:35 < 05:59) mais **arrivant** au-delà (06:15) était supprimé → itinéraire J+1 réel perdu (`[]`).
- **Périmètre :** moteur d'itinéraires PassBi.
- **Test de régression AVANT correctif :** Node §10 moteur (Colobane 23:59 → Diamniadio : `[]` avant, trajet après) ; Dart §10.
- **Correctif :** l'horizon borne le **débarquement/embarquement uniquement** (`absDep > deadline → break`) ; plus de coupe sur l'arrivée (`absArr` libre, l'état n'est pas ré-émbarqué au-delà du deadline).
- **Re-test :** §10 moteur vert (05:35:30 → 06:15:09) ; §6/§7/§8 intacts (atteignabilité vérifiée).

Aucun autre bug fonctionnel démontré : les corrections se limitent à A/B/C sur 4 fichiers de production (`gtfs_source`, `passbi_source`, `schedule_provider`, `routing_engine`).

## 9. Tests 4.18 supersédés mis à jour (valeurs remplacées par A/B)

| Test | Ancienne attente (sémantique buguée) | Nouvelle attente (vérité rideable/J+1) |
|---|---|---|
| Node 11 (TER nuit) | après 23:59:59 → `null` | **106530** (J+1 05:35:30) + dim. 23:59 → 106530 |
| Node 12 (B1 14:00) | PGFB **50547** (arrivée), « 🟢 2 min » | PGFA **50430** (départ, wait 0) + PGFB → `null` |
| Node 16 (B1/B2) | 50547 / 50730 (arrivées) | **50430 / 50610** (départs sœurs) + PGFB/GDWA → `null` |
| Node 18 (nuit) | B1 nuit → `null` via PGFB | conservé (PGFB reste `null` sur 2 jours) + `0:GTAB` jamais appelé → `null` |
| Node 21 (AFTU) | A_916 08:00 → **28913** (08:01:53, arrivée) | **29709** (08:15:09, départ) |
| Dart g.11 | nuit → `unknown` « Horaire indisponible » | nuit → `scheduled` **lun. 06:00:30**, 361 min (Bug B) ; AFTU 29709 |
| Dart g.12 | B1 14:02:27, 2 min | B1 **14:00:30**, 0 → « moins d'une minute » |
| Dart g.16 | B1 14:02:27 / B2 14:05:30 | **14:00:30 / 14:03:30**, distincts |
| Dart g.18 | nuit → unknown | `ddd_1 → null`, quai arrivée → `null`, `0:GTAB → null` (§11) ; label « Horaire indisponible » ré-attaché au chemin UNKNOWN réel (DataService route inconnue, g. 7 bis) |

## 10. Validation (§14, §15, §16)

- **`npm test` : 63/63 verts** (24 legacy + 21 PassBi données + 18 fonctionnels §1–§13).
- **`npm run check:arrets` :** EXIT=1 **strictement identique** au baseline (`/tmp/checkarrets_before.txt`) — erreurs historiques non touchées, aucune donnée éditée.
- **`git diff --check` :** OK (0).
- **`flutter analyze` / `flutter test` / `flutter build` :** SDK absent de l'environnement → **exécutés par la CI** (`flutter-web-build.yml`, Flutter 3.24.5) ; les fichiers de tests Dart (`passbi_integration_test.dart` mis à jour, `passbi_functional_419_test.dart` ajouté) y sont exécutés.
- **§15 UI :** pas d'environnement d'exécution visuel ici → **documenté pour CI/revue** : aucun écran ni style modifié ; seules les données affichées changent (14:00:30 au lieu d'arrivées, nuit → horaire du lendemain, « moins d'une minute » au lieu de « 2 min » sur arrivée, trajets J+1 au moteur).
- **§16 critères :** cohérence route/trip/direction/sequence/horaires ✅, ETA dynamiques (3/6/5/11/336/361 min, zéro valeur dure) ✅, aucun faux temps réel ni « 0 min » ✅, aucun transfert inventé (liens crosswalk ≤ 500 m, temporalité arr+marche≤départ sur §6/§7/§8) ✅, UNKNOWN sans invention (§11) ✅, SCHEDULED jamais 🟡 (§12) ✅, identités séparées (§13) ✅.

## 11. Décisions, limites, engagements (§19)

- **Commit unique** des seules corrections + tests + ce rapport sur `arena/01a0e370-dakar-bus`, **après** validation complète. **Aucun push, aucun merge, PR #31 inchangée.**
- Aucune donnée (`data/transit/passbi`, `data/gtfs`, `dakar_network.json`, crosswalk) modifiée ; aucun GTFS brut touché ; main.dart inchangé.
- Limites connues (non-bugs, rien d'inventé pour les masquer) : headsigns vides sur DDD/AFTU (direction = `direction_id`), B2 ⊂ stations B1 (tests §2/§3 sur séparations route/provider/trip), pas de BRT↔TER direct (chaînable via DDD/AFTU), branche `DepartureInfo.unknown` du provider actuellement non déclenchable sur les données actuelles (couple route/arrêt mappé ⇒ départ trouvé sur 7 jours) — label « Horaire indisponible » couvert par le chemin UI route inconnue ; PassBi API suspendue (aucune donnée live obtainable), **aucun** passage en REAL_TIME.
