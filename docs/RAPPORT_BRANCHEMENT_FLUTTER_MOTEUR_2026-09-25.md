# Branchement de l'application Flutter sur le moteur de départs validé

**Date** : 2026-09-25 · **Branche** : `arena/01a0d6a5-dakar-bus` · **PR** : #26
**Périmètre** : DONNÉES VALIDÉES → `DepartureEngineService` → INTERFACE FLUTTER.
Aucune donnée nouvelle, aucune donnée modifiée, aucune refonte d'interface.

---

## 1. Objet

L'application Flutter n'affichait **aucun** prochain passage : la carte d'arrêt et
la fiche d'arrêt disaient « Horaire indisponible » partout, y compris sur les
gares TER et les stations BRT dont la fréquence est publiée et sourcée. La PWA
JavaScript, elle, était déjà branchée sur le moteur commun depuis le lot
précédent (commit `1817e2f`, rapport `docs/MOTEUR_DEPARTS_MISE_EN_OEUVRE_2026-09-25.md`).

Ce lot branche Flutter sur **le même** moteur, sans second moteur, sans horaire
inventé et sans toucher aux données ni à l'interface existante.

---

## 2. Architecture du branchement

```
ARRÊT AFFICHÉ (Stop)
  stopId        (identifiant du référentiel d'arrêts)
  lineId        ← route.id, injecté par _integrateNetworkData() / integrateNetworkDataForTest()
  modeLabel     ('TER' | 'BRT' | 'DDD' | 'TATA' | 'AFTU' → réseau du référentiel)
        │
        ▼
DepartureEngineService            (lib/services/departure_service.dart)
  ensureLoaded()       : le référentiel embarqué est chargé UNE fois, au démarrage
  networkOfModeLabel() : libellé d'interface → réseau du référentiel
  estimateForLine()    : réseau + ligne + arrêt + instant → DepartureEstimate
        │                 (sélection de période, source utilisable, fenêtre)
        ▼
DepartureEstimate                 (lib/models/departure_estimate.dart)
  status ∈ { scheduled, estimated, realTime, unknown }
  scheduledTime | estimatedFrom/estimatedTo | frequencyMinutes | source | sourceType
  evaluatedAt   : instant de référence du calcul (parité avec le moteur JS)
        │
        ▼
DepartureDisplay  (DepartureEngineService.displayFor)
  badge : « Programmé » | « Estimation » | « Temps réel » | « Horaire indisponible »
  windowLabel, headline, detail (+ source), trafficNote
        │
        ▼
INTERFACE FLUTTER (inchangée dans sa structure)
  StopCard          → libellé court + badge (+ « Affluence indisponible » conservée)
  SingleStopView    → « Prochain passage » + phrase du moteur + source
  Assistant IA      → description réseau (inchangée) + phrase du moteur
```

**Ordre strict du moteur, jamais contourné** : `SCHEDULED` (horaire réellement
fourni) → `ESTIMATED` (fenêtre issue d'une fréquence sourcée) → `REAL_TIME`
(seulement sur observation réelle) → `UNKNOWN`. Flutter ne calcule aucun
horaire : `Stop.nextDeparture*` et `RoutePlanner` sont restés tels quels, et le
test `7 — aucune logique de départ parallèle` vérifie qu'aucune heure n'est
recalculée côté application.

---

## 3. Fichiers exacts du lot

`git diff --stat c0ef96a..HEAD` — **9 fichiers, 1629 insertions, 41 suppressions** :

| Fichier | Nature | Rôle |
|---|---|---|
| `docs/AUDIT_BRANCHEMENT_FLUTTER_MOTEUR_2026-09-25.md` | **créé** (151 l.) | Audit read-only §1 : constats A1–A5 et plan de branchement |
| `docs/RAPPORT_BRANCHEMENT_FLUTTER_MOTEUR_2026-09-25.md` | **créé** | Ce rapport (§19) |
| `flutter-src/lib/services/departure_service.dart` | modifié | `ensureLoaded()` (l. 35), `networkOfModeLabel()` (l. 43), `estimateForLine()` (l. 65), `hasDocumentedFrequency()` (l. 85), `selectFrequencyWithDiagnostics()` (l. 298), `referenceOf()` (l. 613), `displayFor()` (l. 623), `minuteWord()` (l. 731), `assistantReply()` (l. 734) |
| `flutter-src/lib/main.dart` | modifié (+193/−26) | `main()` → `ensureLoaded()` (l. 45) ; `Stop.lineId` (l. 728) ; `Stop.departureEstimate()` (l. 821) et `departureDisplay()` (l. 832) ; `_integrateNetworkData` `lineId: route.id` (l. 1382) ; `StopCard` (l. 2696) ; `SingleStopView` (l. 4002) ; `AssistantReplies.nextDeparture()` (l. 3546) ; `AIChatPage._reponseReseau()` (l. 3617) |
| `flutter-src/lib/models/departure_estimate.dart` | modifié | `evaluatedAt` : instant de référence de l'estimation (l. 304), sérialisé (l. 400) |
| `flutter-src/test/departure_wiring_test.dart` | **créé** (812 l., 37 tests) | Matrices horaires TER/BRT, erreurs §14, assistant, rendu, non-régression |
| `engine/departure-engine.js` | modifié (+10/−4) | Accord « minute » au singulier (`minuteWord`), version `1.0.1` |
| `tests/departure-engine.test.js` | modifié (+6) | Assertion de l'accord singulier (dernière minute de service) |
| `.github/workflows/flutter-web-build.yml` | modifié (+17) | Outillage CI : les tests en échec sont publiés en **annotation** (noms + `Expected/Actual`), pour ne pas dépendre du téléchargement de l'artefact de journal |

Aucun autre fichier n'est touché : ni `data/**`, ni `flutter-src/assets/**`, ni
`index.html`, ni `service-worker.js`, ni `server/**`.

### API Flutter ajoutée (la seule surface nouvelle)

```dart
// lib/services/departure_service.dart
static Future<bool> ensureLoaded();                                  // référentiel chargé une fois
static String? networkOfModeLabel(String? modeLabel);                 // 'TER' → 'TER', 'Tata' → 'TATA'
static DepartureEstimate estimateForLine({modeLabel, lineId, stopId, direction, now});
static DepartureDisplay displayFor(DepartureEstimate e, {DateTime? now});
static DateTime referenceOf(DepartureEstimate e, {DateTime? now});    // instant du calcul (evaluatedAt)
static bool hasDocumentedFrequency(String? modeLabel);

// lib/main.dart
class Stop { final String? lineId; DepartureEstimate departureEstimate({DateTime? now}); DepartureDisplay departureDisplay({DateTime? now}); }
```

---

## 4. Confirmation : l'interface n'a pas été reconstruite

- **Aucun écran, onglet, navigation, couleur, typographie, icône, filtre,
  recherche, GPS ou itinéraire n'a été modifié.** Les 13 hunks de `main.dart`
  touchent uniquement : le démarrage (chargement du référentiel), le champ
  `lineId` de `Stop`, les deux accesseurs d'affichage, l'injection
  `lineId: route.id`, la carte d'arrêt (`StopCard`), la fiche d'arrêt
  (`SingleStopView`) et la formulation de l'assistant.
- **Aucun arrêt, aucune ligne, aucun libellé d'interface n'a été ajouté.**
- Le panneau « Prochains passages » du §8 est servi par la carte d'arrêt et la
  fiche d'arrêt : (i) `line` = `stop.direction` (inchangé), (ii) badge de statut,
  (iii) fenêtre `estimatedFrom`–`estimatedTo`, (iv) source, (v) libellé
  « Prochain passage » / « Prochain passage estimé … ». Aucun nouveau panneau
  n'a été introduit (constat A4 de l'audit).
- La colonne **« Affluence »** reste « Affluence indisponible » (rendue dans la
  ligne combinée `« 300 m • TER (🟢) • Affluence indisponible »`), vérifiée par
  les tests de rendu et par `demo_data_cleanup_test.dart`.
- Le chemin « horaire réellement fourni » de l'audit 2026-09-24 est conservé à
  l'identique : `horaireFourni = !depart.available && stop.scheduleStatus ==
  ScheduleStatus.scheduled` (StopCard l. 2701-2705, SingleStopView l. 4004-4009).
  Le moteur ne produisant jamais d'horaire sans source, les deux chemins
  restent distincts et honnêtes ; le test « horaire réellement fourni à un
  arrêt : “programmé”, jamais estimé » le verrouille.

---

## 5. Confirmation : le référentiel n'a pas été pollué

| Contrôle | Résultat |
|---|---|
| `data/transit/departure-frequencies.json` | **non modifié** par ce lot (dernier commit : `1817e2f`) ; 3 sources `OFFICIAL` avec `url`, TER ×3 (10 min 05:30-21:00 lun-sam, 20 min 21:00-22:00, dim/fériés 06:30-22:00), B1 6 min 06:00-21:00 7 j/7, B2 6 min lun-sam ; `holidays.dates = []` ; `real_time.public_feeds = []` |
| Miroir Dart `flutter-src/assets/data/departure-frequencies.json` | **byte-identique** (`cmp` OK ; 2 étapes `cmp` en CI J9) |
| Arrêts / lignes | **117 arrêts / 105 routes** (assertions `setUpAll` des tests Flutter, exécutées en CI) |
| KMF (`stop_keur_massar`) | reste `UNKNOWN` ; **Mbao distinct** de KMF |
| Yeumbeul A/B | non résolu (aucun choix arbitraire) |
| AIBD | non exposé |
| DDD / AFTU / TATA | **UNKNOWN partout** : aucune fréquence créée pour remplir l'interface |
| B1 / B2 | non élargies ; **pas de B3** (les tests vérifient `frequenciesForLine('brt_b3_semi_express')` vide) |
| Temps réel | aucun flux : `real_time.public_feeds = []`, `gtfs-rt-policy.js` inchangé, serveur en `NO_PUBLIC_FEED` / `simulatedDataServed: false` |
| GPS | usage utilisateur uniquement (position, arrêts proches, itinéraire) ; `vehicleFromUserPosition()` n'est jamais appelé côté Flutter |

---

## 6. Résultats de tests — commandes réellement exécutées

### 6.1 Avant (base) — rappel

| Commande | Où | Résultat |
|---|---|---|
| `npm test` | sandbox | **54 pass / 0 fail** |
| J9 (`flutter analyze` + `flutter test`) | CI, run `36092184693` (commit `c0ef96a`) | vert |

### 6.2 Local (sandbox), après toutes les modifications

| Commande exécutée | Résultat exact |
|---|---|
| `npm test` | `# pass 54`, `# fail 0` |
| `node --check engine/departure-engine.js` | aucune erreur de syntaxe |
| `node -e "…ENGINE_VERSION…"` | `ENGINE_VERSION = 1.0.1` |
| `cmp data/transit/departure-frequencies.json flutter-src/assets/data/departure-frequencies.json` | identique (aucune sortie) |

> `flutter analyze`, `flutter test` et `flutter build web` **ne sont pas
> exécutables dans la sandbox** (aucun SDK Flutter, dépôts `storage.googleapis.com`
> et `pub.dev` inaccessibles). Ces trois commandes sont celles du dépôt
> (`.github/workflows/flutter-web-build.yml`) et ont donc été exécutées par la CI J9.

### 6.3 CI J9 — run final **`36094735170`**, commit **`0deb9bf`**, conclusion `success`

| Étape du workflow (commande du dépôt) | Résultat exact publié par la CI |
|---|---|
| `flutter pub get` | OK (`Try flutter pub outdated for more information.`) |
| `flutter analyze` | `No issues found! (ran in 11.9s)` |
| `flutter test` | `00:12 +412: All tests passed!` |
| `flutter build web --release` | `✓ Built build/web` — `build/web` : 29 fichiers produits |

Chaque commit de la branche (code **et** documentation) déclenche la CI J9 : les
trois runs `36094735170` (commit `0deb9bf`), `36094920527` (commit `2677e0b`) et
`36095031627` (commit `b39a038`, tête de PR) sont tous `success`, avec le même
résultat — `flutter analyze` sans anomalie, `flutter test` **412 tests verts**
(00:08 / 00:11 / 00:11), `build/web` 29 fichiers.

### 6.4 Chronologie honnête du lot (rouge → vert)

| Run (CI J9) | Commit | État | Détail |
|---|---|---|---|
| `36093406640` | `84796e4` | **échec** | `flutter analyze` OK ; `flutter test` : `00:12 +405 -6: Some tests failed.` |
| `36094058555` | `368cf3a` | échec (4 restants) | `+407 -4` — causes identifiées par les annotations |
| `36094197853` | `41b3bad` | échec (2 restants) | `+409 -2` — causes identifiées par les annotations |
| `36094338104` | `8eacc98` | **succès** | `00:08 +411: All tests passed!` + `build web` 29 fichiers |
| `36094559632` | `4053f1a` | **succès** | `00:12 +412: All tests passed!` |
| `36094735170` | `0deb9bf` | **succès** | ci-dessus (§6.3) |

Les journaux bruts et l'artefact `j9-logs-…` étaient indisponibles depuis la
sandbox (erreurs `EOF` de l'API GitHub). Le workflow publie désormais les échecs
en annotation (`::error title=flutter test — échec (…)::` + `Expected/Actual`),
ce qui a permis de nommer chaque test en échec sans télécharger d'artefact.

### 6.5 Défauts trouvés par ces tests et corrigés dans le lot

1. **Fenêtre recalculée sur un autre « maintenant »** : le moteur JS référence la
   fenêtre à `evaluatedAt` ; le miroir Dart la recalculait sur `DateTime.now()`,
   d'où « fenêtre de 446 à 456 minutes » pour une estimation produite à 11:43.
   → `DepartureEstimate.evaluatedAt` + `referenceOf()` (parité rétablie).
2. **`NO_FREQUENCY_FOR_DAY` confondu avec `NO_FREQUENCY_FOR_LINE`** : B2 le
   dimanche renvoyait le mauvais motif. → `selectFrequencyWithDiagnostics()`,
   comme le moteur JS.
3. **Source absente de la fiche d'arrêt avant l'ouverture du service** (§8 exige
   la source) : `displayFor`, branche `BEFORE_SERVICE`, affiche désormais
   « … — source : SETER (terdakar.sn) … ».
4. **Accord « 0 à 1 minutes »** dans la phrase de l'assistant (dernière minute de
   service, TER 20:59, BRT 20:54). → `minuteWord()` dans le moteur JS **et** dans
   le miroir Dart, version moteur `1.0.1`.
5. Deux assertions de test trop naïves (le dernier `Text` de l'écran est
   l'indication du champ de saisie, pas la bulle de réponse ; « Affluence
   indisponible » est rendue dans une ligne combinée) : corrigées dans le test,
   **sans toucher à l'interface**.

---

## 7. Exemples réels (sorties du moteur, instant explicite)

Les valeurs ci-dessous sont **produites par le moteur** (même référentiel que
l'application), la fenêtre étant calculée par rapport à l'instant de
l'estimation — convention de l'interface Flutter (`referenceOf`). Le miroir Dart
produit les mêmes statuts, fenêtres et libellés ; c'est ce que vérifient les
tests `flutter test` exécutés en CI (§6.3).

| Réseau / ligne | Instant | Statut | Fenêtre | Badge | Phrase de l'assistant |
|---|---|---|---|---|---|
| TER Dakar ↔ Diamniadio | lun 2026-09-28 05:29 | ESTIMATED (`BEFORE_SERVICE`) | 05:30 → 05:40 | Estimation | « … Le service commence à 05:30 : le premier passage est estimé entre 5h30 et 5h40. L'heure exacte du train n'est pas disponible. » |
| TER | lun 2026-09-28 10:00 | ESTIMATED | 10:00 → 10:10 | Estimation | « … estimé dans une fenêtre de 0 à 10 minutes … » |
| TER | lun 2026-09-28 11:43 | ESTIMATED | 11:43 → 11:53 | Estimation | « … fenêtre de 0 à 10 minutes … » |
| TER | lun 2026-09-28 20:59 | ESTIMATED | 20:59 → 21:00 | Estimation | « … fenêtre de 0 à 1 minute … » |
| TER | lun 2026-09-28 21:00 | ESTIMATED | 21:00 → 21:20 | Estimation | « … fenêtre de 0 à 20 minutes … » |
| TER | lun 2026-09-28 21:30 | ESTIMATED | 21:30 → 21:50 | Estimation | « … fenêtre de 0 à 20 minutes … » |
| TER | lun 2026-09-28 22:00 / 22:01 | UNKNOWN (`SERVICE_ENDED`) | — | Horaire indisponible | « Je connais cette ligne, mais je n'ai pas actuellement de donnée suffisamment fiable pour estimer le prochain passage. » |
| TER | dim 2026-10-04 06:29 | ESTIMATED (`BEFORE_SERVICE`) | 06:30 → 06:50 | Estimation | « … Le service commence à 06:30 … entre 6h30 et 6h50 … » |
| TER | dim 2026-10-04 11:43 | ESTIMATED | 11:43 → 12:03 | Estimation | « … fenêtre de 0 à 20 minutes … » |
| TER | dim 2026-10-04 21:59 | ESTIMATED | 21:59 → 22:00 | Estimation | « … fenêtre de 0 à 1 minute … » |
| TER | **férié 2026-10-05** (calendrier `holidays.dates = []`) | ESTIMATED | 06:29 → 06:39 (règle lundi, 10 min) | Estimation | Aucun jour férié n'est **deviné** : sans calendrier publié, la règle du lundi s'applique. Avec un calendrier explicitement déclaré (test), la règle dimanche/fériés (20 min) s'applique. |
| BRT B1 | dim 2026-10-04 05:59 | ESTIMATED (`BEFORE_SERVICE`) | 06:00 → 06:06 | Estimation | « … Le service commence à 06:00 … entre 6h00 et 6h06 … » (bus) |
| BRT B1 | dim 2026-10-04 14:00 | ESTIMATED | 14:00 → 14:06 | Estimation | « … fenêtre de 0 à 6 minutes … » |
| BRT B1 | dim 2026-10-04 21:00 | UNKNOWN (`SERVICE_ENDED`) | — | Horaire indisponible | refus explicite |
| BRT B2 | lun 2026-09-28 11:43 | ESTIMATED | 11:43 → 11:49 | Estimation | « … fenêtre de 0 à 6 minutes … » |
| BRT B2 | **dim 2026-10-04 11:00** | UNKNOWN (`NO_FREQUENCY_FOR_DAY`) | — | Horaire indisponible | refus explicite (aucune fréquence B2 le dimanche) |
| **DDD** `ddd_1` | lun 2026-09-28 11:43 | UNKNOWN (`NO_FREQUENCY_FOR_LINE`) | — | Horaire indisponible | refus explicite |
| **AFTU** `aftu_1` | lun 2026-09-28 11:43 | UNKNOWN (`NO_FREQUENCY_FOR_LINE`) | — | Horaire indisponible | refus explicite |
| **TATA** `tata_50` | lun 2026-09-28 11:43 | UNKNOWN (`NO_FREQUENCY_FOR_LINE`) | — | Horaire indisponible | refus explicite |

Exemple de carte d'arrêt (gare TER Dakar, relevé d'un test de rendu en CI) :

```
Gare TER Dakar
EMBARQ.
Dir. Diamniadio - Gare TER Terminus
300 m • TER (🟢) • Affluence indisponible        ≈ 69–79 min
                                                 Estimation
```

Aucune heure précise n'est affichée pour une estimation : le seul horaire
affichable est l'ouverture documentée du service (05:30 / 06:00), et le libellé
de statut reste « Estimation ». « Temps réel » n'apparaît que si une observation
réelle existe (aucun flux aujourd'hui : `real_time.public_feeds = []`).

---

## 8. Cas d'erreur couverts (§14) — aucune donnée inventée

Groupe `4 — référentiel absent, vide ou incohérent` de
`flutter-src/test/departure_wiring_test.dart` (exécuté en CI) :

| Cas | Vérification |
|---|---|
| Référentiel absent (non chargé) | **tout est UNKNOWN** ; aucune estimation |
| Référentiel vide | aucune estimation, aucun horaire |
| Ligne inconnue / arrêt inconnu | UNKNOWN ; une fréquence de ligne ne remplace jamais l'arrêt inconnu |
| Référentiel incohérent (source absente, période inversée) | détecté (`validateRegistry`), jamais « réparé » ni estimé |
| Service terminé | `SERVICE_ENDED` → UNKNOWN (TER 22:00/22:01, B1 21:00) |
| Service pas commencé | fenêtre ancrée sur l'ouverture documentée (`BEFORE_SERVICE`) |
| Jour férié | seul un calendrier **explicite** change la règle ; sinon aucune supposition |
| Changement de période | 10 min → 20 min → service terminé (TER 20:59 / 21:00 / 21:30 / 22:00) |

---

## 9. Bloc de confirmation finale

```
LOT  : BRANCHER FLUTTER SUR LE MOTEUR DE DÉPARTS VALIDÉ (2026-09-25)
BRANCHE : arena/01a0d6a5-dakar-bus · PR #26 · commit 0deb9bf

[OK] UN SEUL MOTEUR : l'application Flutter appelle DepartureEngineService
     (ensureLoaded → estimateForLine → DepartureEstimate → displayFor).
     Aucun nextDeparture()/calculateNextBus() parallèle : test 7 de
     departure_wiring_test.dart.
[OK] FLUX : Stop (stopId + lineId + modeLabel) → Line/Direction →
     DepartureEngineService → DepartureEstimate → StopCard / SingleStopView /
     Assistant IA.
[OK] STATUTS : SCHEDULED (horaire fourni, « Programmé ») · ESTIMATED (fenêtre,
     « Estimation ») · REAL_TIME (observation réelle uniquement) · UNKNOWN
     (« Horaire indisponible »). Vocabulaire identique à la PWA.
[OK] AUCUN HORAIRE INVENTÉ : une fréquence documentée donne une FENÊTRE ;
     0 heure exacte dans les réponses de l'assistant (tests group 5) ;
     toute heure affichée doit être documentée (ouverture ou fenêtre du moteur).
[OK] AVANT/APRÈS SERVICE : avant 05:30, la fenêtre est ancrée sur l'ouverture
     documentée ; après le dernier départ documenté, UNKNOWN (SERVICE_ENDED).
[OK] DDD / AFTU / TATA : UNKNOWN à toute heure ; KMF reste UNKNOWN et distinct
     de Mbao ; Yeumbeul A/B non résolu ; AIBD non exposé ; pas de B3.
[OK] UI NON RECONSTRUITE : navigation, couleurs, carte, filtres, recherche, GPS,
     itinéraires, favoris, StopCard, panneau, boutons, typographie, icônes
     inchangés ; « Affluence indisponible » conservée ; aucun arrêt ajouté.
[OK] RÉFÉRENTIEL INTACT : 117 arrêts / 105 routes ; référentiel et miroir
     byte-identiques (cmp) ; aucune donnée TER modifiée ; aucune fréquence
     créée ; real_time.public_feeds = [].
[OK] GPS : usage utilisateur uniquement, jamais donnée véhicule.
[OK] TESTS : npm test → 54 pass / 0 fail (sandbox) ;
     CI J9 run 36094735170 (commit 0deb9bf) → flutter pub get OK,
     flutter analyze « No issues found! (ran in 11.9s) »,
     flutter test « 00:12 +412: All tests passed! »,
     flutter build web « ✓ Built build/web » (29 fichiers).
[OK] ZÉRO RÉGRESSION : suites existantes incluses dans les 412 tests verts.

RESTE HORS PÉRIMÈTRE (inchangé, préexistant) : le check « TER BRT data
validation » est rouge (12 s) sur les exécutions antérieures de la branche
arena/01a0d328-dakar-bus (2026-09-24) comme sur celles de ce lot ; ce lot ne
touche ni data/gtfs/**, ni scripts/**, ni tests/transit-validation.test.js.
```
