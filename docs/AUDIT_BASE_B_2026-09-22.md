# DAKAR BUS — AUDIT DE LA BASE B (Flutter dakarbus v9.3.2+12)

**Date** : 2026-09-22 · **Objet audité** : branche `arena/01a0c385-dakar-bus`, commit `ac03557` (22/09/2026), dossier `flutter-src/` · **Type** : audit en lecture seule

| Règle de la mission | Respect |
|---|---|
| Aucun fichier source modifié, aucun workflow créé, `flutter-src/` non copié dans la branche de travail | ✅ (le code de B a été lu via `git show` / une extraction temporaire hors dépôt, dans `/tmp`, non persistée) |
| Aucun commit, aucun push, aucun déploiement | ✅ (`git status` : seuls les rapports d'audit sont non suivis) |
| GPS et TER/BRT non modifiés | ✅ |
| Seul fichier créé : `docs/AUDIT_BASE_B_2026-09-22.md` | ✅ |

Conventions : « l.NNN » = ligne de `flutter-src/lib/main.dart` au commit `ac03557` sauf mention contraire. « A » = candidat A (`arena/01a0c30c-dakar-bus`, copie fidèle de `2c72e57`). « prod » = build déployé sur `gh-pages` (`94a84b6`). Les distances sont des haversines (R = 6 371 008,8 m) vers les référentiels déjà utilisés dans `docs/AUDIT_TER_BRT_DONNEES_2026-09-22.md` (§B.1 carte opérateur TER, §C.1 quais OSM SunuBRT).

---

## 0. Résumé exécutif

1. **B est le seul candidat qui porte la version cible `9.3.2+12` dans un `pubspec.yaml` commité**, avec un source vérifiable (analyze 0 issue, 232/232 tests verts en CI sous Flutter 3.24.5). Le point de départ de B (`904c35f`) est **identique octet pour octet** à `2c72e57` (arbre Git `5085bfb…`) : aucune modification cachée à l'import.
2. **TER/BRT** : B corrige réellement la couche « itinéraire » (fiche de ligne et polylignes dérivées du JSON : 13 gares / 23 stations, Keur Massar retiré du TER, `demoRoutes` littéraux supprimés, test l.672 neutralisé par la suppression de sa cause). Mais la correction est **partielle** : les 24 arrêts codés en dur (8 TER, 4 BRT, 12 autres) sont **conservés et verrouillés par des tests**, ce qui laisse sur la carte 8 faux points TER (jusqu'à 3 464 m de la vraie gare) et 4 faux points BRT (dont « BRT Colobane », inexistante) ; les 11 anciens arrêts « … - BRT » restent affichés sous couleur DDD/AFTU ; les marqueurs de carte restent limités à 30 arrêts « à proximité » (le symptôme audité hier n'est pas traité).
3. **GPS** : B **ne fabrique plus aucune position** (14.7167, −17.4677 n'est plus jamais assigné à `_userPosition` — prouvé par le code et par test). Mais B **rejette toujours la position réelle hors de `DakarBounds`** (`GpsResolver.fromMeasuredPosition` l.1441-1454 : position → `null`, état `error`). En France, l'utilisateur n'a ni sa position, ni de marqueur, ni de liste « à proximité » : **non conforme à la règle « position réelle conservée, statut hors couverture séparé »**.
4. **Build** : `flutter build web` n'a **jamais été exécuté sur B** (le workflow actif ne fait qu'analyze + test ; le `deploy.yml` hérité est inactif car placé sous `flutter-src/.github/`). Les éléments statiques sont favorables (mêmes imports que A, qui a produit le 1ᵉʳ build `2c96eef` en 3.24.5 ; aucun `dart:io` dans `lib/`), mais **aucun `pubspec.lock` n'est commité** : la reproductibilité exigée pour J9 n'est pas acquise en l'état.
5. **Risque de dérive** : B implémente les décisions d'un référentiel externe (« Phase 0 », « rapport 4A », « Cartes 03/04/14 », « §… ») **absent du dépôt**. Trois de ces décisions contredisent les règles fixées aujourd'hui : rejet des positions hors zone (D1-i), conservation des 24 points de démonstration (« §6 »), alignement sur la production binaire comme preuve (4 000 m / 30 / 20 s).

**Verdict** : B est une **bonne base technique** (source propre, testé, versionné, corrections TER/BRT structurelles saines) **à condition** de reprendre 3 points avant J9 (chaîne GPS hors zone, 24 arrêts codés en dur + tests qui les verrouillent, `pubspec.lock`) et de traiter 2 régressions de texte (« v9.4 (Web Fix) » l.2796, « 14 gares » l.2938). Détail des réponses aux 8 questions au §G.

---

## A. Source Flutter de B

### A.1 Structure (`flutter-src/`, 20 fichiers)

| Élément | Contenu | Remarque |
|---|---|---|
| `pubspec.yaml` | `name: dakar_bus`, **`version: 9.3.2+12`**, `sdk '>=3.3.0 <4.0.0'`, `flutter '>=3.19.0'` | Version portée par un commentaire de 14 lignes justifiant « identité production ». Commité en `f3f5145`. |
| Dépendances | `flutter_map ^6.1.0`, `latlong2 ^0.9.1`, `geolocator ^12.0.0`, `http ^1.2.2`, `cupertino_icons ^1.0.8` ; dev : `flutter_test`, `flutter_lints ^4.0.0` | **Identiques à A** (seuls `description` et `version` ont changé, diff `f3f5145`). Aucune dépendance ajoutée par les 14 commits. |
| `pubspec.lock` | **ABSENT** | `.gitignore` ignore `*.lock` puis ré-autorise `!pubspec.lock`, mais aucun lock n'a jamais été commité. Chaque `flutter pub get` résout à nouveau. |
| `lib/main.dart` | 3 310 lignes (A : 2 450) ; **777 lignes de commentaires** (A : 110) | Toute l'application est dans un seul fichier ; +667 lignes de commentaires de justification insérées dans le code. |
| `lib/models/transport_network.dart` | 192 l., `DataTrust {official, fieldObservation, estimated}`, `BusStop`, `TransportRoute`, `Operator` | **Inchangé** par rapport à A. |
| `lib/services/data_service.dart` | 155 l., `rootBundle.loadString('assets/data/dakar_network.json')` puis `_loadFallbackData()` en cas d'échec (l.34-40) | **Inchangé**. Le repli mémoire (réseau réduit codé en dur) subsiste. |
| `assets/data/dakar_network.json` | 117 arrêts, 105 lignes, 5 opérateurs ; **md5 `81c778f4644dcf5e1cf4ae25879218f0` = octet pour octet le JSON servi sur `gh-pages`** | Substitué en `f3f5145` (A : 92 arrêts, md5 `05685bf9…`). Clés `operator_id`, `short_name`, `long_name`, `stops`, `data_trust`. Aucune métadonnée de source/date. |
| `web/index.html` | `<base href="$FLUTTER_BASE_HREF">`, chargeur **hérité** `flutter.js` + `loadEntrypoint` ; titre/description « 40 lignes, 40 arrêts » | Fonctionne en 3.24.5 (le 1ᵉʳ build `2c96eef` a été produit avec ce même fichier) mais API de chargement dépréciée ; aucun `serviceWorker` configuré → pas d'enregistrement de SW par le chargeur. |
| `web/manifest.json` | `icons: []`, `start_url "."` | Aucune icône, pas de dossier `web/icons/`, pas de favicon. |
| `analysis_options.yaml` | `flutter_lints` + 4 règles désactivées | Analyze : `No issues found!` en CI. |
| `.github/workflows/deploy.yml` (sous `flutter-src/`) | Workflow complet hérité de A : Flutter 3.24.5, analyze, test, `flutter build web --release --base-href "/dakar-bus/"`, `upload-pages-artifact` + `deploy-pages` | **Inactif** (GitHub ne lit que `/.github/workflows` à la racine du dépôt). Modèle exploitable pour J9. |
| `README.md` | « 92 arrêts », badge « Version 9.3.0+4 » | Obsolète (hérité de A). |
| `test/` | 9 fichiers `*_test.dart`, 232 tests | Voir §E. |

### A.2 Ce que B contient en dehors de `flutter-src/`

B est branché sur `main` (`ce8c94f`) : il contient donc **toujours la PWA à la racine** (`index.html`, `data/gtfs/…`, `server/`, `api/`, `service-worker.js`…), **strictement inchangée** (`git diff ce8c94f ac03557 -- . ':!flutter-src' ':!docs/dakar-bus' ':!.github/workflows/flutter-verify.yml'` = vide). B ajoute : `.github/workflows/flutter-verify.yml` (actif, déclenché uniquement sur `push` de `arena/01a0c385-dakar-bus` et `workflow_dispatch`) et 7 documents sous `docs/dakar-bus/`.

### A.3 Historique de B au-dessus de `main` : 25 commits

| Nature | Commits | Fichiers |
|---|---|---|
| Import du source | `904c35f` | `flutter-src/**` = arbre `2c72e57` (identique), + `flutter-verify.yml` |
| CI (vérification seule) | `6ec77cb`, `f7afd93`, `ec52df6`, `84f0123` (partiel) | `.github/workflows/flutter-verify.yml` |
| **Code / données / tests (les « 14 commits »)** | `f3f5145`, `b1a645c`, `c9fcdca`, `84f0123`, `c6a9068`, `fb4da56`, `16a1b30`, `d5a82b8`, `ff0fe79`, `87f54d6`, `0e2a157`, `0d1696a`, `e506b72` (+ `904c35f`) | `flutter-src/**` |
| Documentation | `4e042bc`, `a696ccc`, `6270aa7`, `5fdf9bd`, `e2ebbd1`, `0c2ca4d`, `79a49fc`, `ac03557` | `docs/dakar-bus/**` |

Auteurs : `arena-ai-coding-agent[bot]`, `arena-agent`, `aydiarra-star`. Aucune PR ouverte depuis B.

---

## B. Audit des modifications présentes dans B (groupes 1 → 9)

Légende statut : **Correcte** = conforme et prouvée · **Douteuse** = fonctionne mais principe ou preuve contestable · **À corriger** = contraire aux règles fixées le 22/09 ou défaut avéré.

| Groupe · commit | Fichier(s) | Fonctionnalité | Modification exacte | Statut | Risque |
|---|---|---|---|---|---|
| **G1 · `f3f5145` (+`b1a645c`)** | `assets/data/dakar_network.json` | Données réseau | Remplacement intégral du JSON historique (92 arrêts, TER 12 avec Keur Massar, B1 12, B2 6) par le JSON de production `gh-pages` (117 arrêts, TER 13, B1 23, B2 7, 105 lignes). Substitution sans changement de schéma. | **Correcte sur la forme, douteuse sur le fond** : les coordonnées TER/BRT sont exactes (§D.2) mais le fichier reste **auto-déclaré `OFFICIAL`** sans source ni date (statut réel « vérifié, non officiel » — audit du 22/09). Il embarque aussi les 11 arrêts « … - BRT » obsolètes et 3 homonymes à coordonnées divergentes (§D.4). | Moyen : la donnée « prod » est reprise telle quelle, défauts compris. |
| G1 · `f3f5145` | `lib/main.dart` l.105-122 | `DakarBounds` | Rectangle d'exclusion « océan » (14.70-14.745 × −17.435/−17.375) **supprimé** ; bornes élargies 14.65→**14.55** S, 14.79→**14.90** N, −17.55→**−17.60** O, −17.15→**−16.85** E ; garde `(0,0)` conservé. Bornes recopiées du validateur `eI` du binaire de production. | **Correcte pour les arrêts** (le rectangle rejetait Hann, Dalifort, Baux Maraîchers), **à corriger pour le GPS** : `DakarBounds.isValid` reste l'unique juge de la position utilisateur (§C). | Élevé côté GPS (voir §C) ; nul côté données. |
| G1 · `f3f5145` | l.1206-1278 `DistanceHelper.haversineMeters` | Distance | `earthRadius` 6 371 000 → **6 371 008,8** m (valeur du binaire prod `ew`). | Correcte (écart 1,4 ppm, sans effet visible). | Nul. |
| G1 · `f3f5145` | `pubspec.yaml` | Version | `9.3.0+4` → **`9.3.2+12`** ; description « 117 arrêts, 105 lignes : 1 TER, 2 BRT, 80 AFTU, 15 DDD, 7 Tata ». | Correcte (décision validée aujourd'hui). | Faible : un build produira `version.json = 9.3.2 / 12`, **identique** à la prod actuelle → pas de discriminant de version entre l'ancien et le nouveau déploiement. |
| G1 · `f3f5145` | `test/dakar_bounds_test.dart`, `test/data_service_test.dart`, `test/network_data_test.dart` (nouveau, 22 tests) | Tests | Test « Ocean exclusion zone is invalid » **inversé** ; attentes `>= 90` remplacées par valeurs exactes (117/105/5) ; 22 tests de contenu JSON (13/23, ordre, Keur Massar absent du TER, B2 ⊂ B1…). | Correcte. Le test `les bornes sont celles de la production` (l.56) verrouille les 4 nombres de `DakarBounds`. | Faible : à réécrire si `DakarBounds` évolue. |
| **G2 · `c9fcdca` (+`84f0123`)** | l.322-347 `DetailedStop`, l.349-607 `DetailedRoute`, l.609-623 `openLineDetail`, l.628-717 `Stop.stopId` | Fiche de ligne | Suppression des 3 listes littérales de `fromStop` (TER 12 dont Keur Massar, BRT 11, générique avec « Station Intermédiaire » fabriquée) ; `DetailedRoute._build` (l.468-536) dérive les arrêts de `route.stopIds`, distance cumulée haversine, `totalDistance` calculé (TER 34,6 km, B1 17,5 km) ; résolution arrêt → JSON par `stopId`, puis nom exact, puis plus proche ≤ 250 m (l.538-575) ; `fromOperator` (l.458) ; ligne indérivable → `null` + bouton désactivé au lieu d'une fiche inventée ; `DetailedStop` ramené à 5 champs. | **Correcte** dans son principe (source unique). **Deux points douteux** : (1) `estimatedTime = '~${index×3} min'` (`kMinutesPerStop = 3`, l.388) est une **valeur fabriquée** affichée sous l'étiquette « Heure : » (l.3107) ; (2) le message de `openLineDetail` (l.614) dit « données réseau non chargées » alors que le cas fréquent est « arrêt non résoluble » (les 9 points TER/BRT codés en dur à > 250 m du JSON, §D.3). | Faible/moyen : UX trompeuse mais aucune donnée réseau inventée. |
| G2 | `test/detailed_route_test.dart` (37 tests) | Tests | Dérivation TER 13/BRT 23, ordre, inverse, distances, absence de littéraux. | Correcte. | — |
| **G3 · `c6a9068`** | l.181-252 `OppositeStopService`, l.3131-3210 `DualStopDetailPage` | Arrêt en face | Seuil passe 1 « nom inclus » 50 m → **120 m** (constante l.183) ; passe 2 (même mode, 500 m) inchangée ; **suppression du repli** `stop.copyWith(direction: 'Dir. Dakar / Centre')` : sans candidat, l'onglet « retour » affiche « Arrêt en face non identifié » (l.3193) au lieu d'un faux arrêt. | Correcte (supprime une donnée fabriquée). | Faible. |
| G3 | `test/opposite_stop_test.dart` (34 tests) | Tests | Seuils, priorité des passes, `null` sans substitution. | Correcte. | — |
| **G4 · `fb4da56` (+`16a1b30`)** | l.1325-1500 `GpsState`, `GpsResolution`, `GpsResolver` ; l.1503-1600 `_MainShellState` ; l.1738-1776 `_filteredStops` ; l.1795 `_distanceTo` ; l.1841-1900 bandeau GPS | GPS | Voir §C. Résumé : plus aucune substitution par 14.7167/−17.4677 ; flux continu `getPositionStream(high, distanceFilter 10, timeLimit 20 s)` au lieu de `getCurrentPosition` ; `denied`/`deniedForever` distingués ; rayon 5 000 → **4 000 m**, plafond 20 → **30** ; bandeau affichant `gpsMessage` ; souscription annulée dans `dispose` (l.1531). **Position hors `DakarBounds` → `position = null`, état `error`.** | **À corriger** (rejet de la position réelle hors zone, statut non séparé) ; le reste est correct. | **Élevé** au regard de la règle « GPS réel utilisable hors Dakar ». |
| G4 | `test/gps_position_test.dart` (40 tests) | Tests | Décisions `GpsResolver`, rayon/plafond, 7 « GARDE-FOU SOURCE » par lecture regex de `lib/main.dart`. | **Douteuse** : le test (e) l.176-190 **verrouille le rejet hors zone** (attend `position == null`, `state == error`) ; les gardes-fous « source » testent des chaînes de caractères, pas un comportement. | Moyen : ces tests devront être réécrits avec la correction GPS. |
| **Correction TER+BRT · `d5a82b8` (+`ff0fe79`)** | l.795-882 `networkPoints`, `officialRouteStops`, `networkOfRoute` ; l.884 `integrateNetworkDataForTest` ; l.1050-1095 `demoRoutes` | Carte / itinéraires | `demoRoutes` littéral (TER 6 pts, B1 10 pts, DDD 3, TATA 3) → **liste vide** alimentée par `_integrateNetworkData` : un tracé par ligne JSON (TER 13 pts, B1 23, B2 7). Formalisation « points Explorer ≠ arrêts d'itinéraire ». Le test `exists` l.1000 (`code == short_name`) n'est plus court-circuitant puisque la liste démarre vide. | **Correcte pour les polylignes** (cohérentes avec les 13/23 stations). **À corriger sur la doctrine** : les 24 arrêts codés en dur sont **volontairement conservés** (« aucun point d'Explorer n'est retiré ») et **verrouillés** par `ter_brt_route_data_test.dart` l.142-165 (`kTerExplorerPoints = 21`, `kBrtExplorerPoints = 27`). | **Élevé** pour la cohérence de la carte (§D.3). |
| **G5 · `87f54d6`** | l.2418-2422 `AlertsPage` | Textes | « 14 Gares » → « 13 Gares » (titre, message, badge) ; « Keur Massar » → « Keur Mbaye Fall » dans le message. | Correcte. | Nul. Reste « 14 gares officielles » dans l'assistant IA (l.2938) et « v9.4 (Web Fix) » dans Réglages (l.2796). |
| **G6 · `0e2a157` (+`0d1696a`)** | l.2440-2461 `AlertsPage` BRT ; l.2574-2575 et en-tête `CommunityAlertsPage` | Textes / statuts | Message BRT sans « Grand Yoff » (non station) ; badge « En direct » → « Données officielles » ; « Il y a 3 min / 6 min » → « Sans horodatage » ; « usagistes … temps réel » → « Signalements publiés par les usagers ». | Correcte sur « En direct » et les horodatages fictifs. **Douteuse** sur « Données officielles » : le libellé s'appuie sur `data_trust == OFFICIAL` **auto-déclaré** dans le JSON (aucune source officielle nominative n'existe pour les 23 stations — audit du 22/09 §C). | Faible. |
| G6 | `test/groupe6_alertes_test.dart` (12 tests) | Tests | Données + rendu (`testWidgets`) + garde-fous source. | Correcte. | — |
| **G7-P1 · `e506b72`** | l.1243-1248 `DistanceHelper.format` | Affichage distance | `< 1000 → m` ; `≥ 1000 → x.x km` remplacé par : `< 950 → m`, `< 10 km → x.x km`, sinon `N km` (formateur `A.azr` du binaire prod). | Correcte (cosmétique). | Nul. |
| G7-P1 | `test/dakar_bounds_test.dart` (+8 tests) | Tests | Trois branches du format. | Correcte. | — |
| **G7, G8, G9 · docs seuls** | `docs/dakar-bus/groupe-7/…`, `groupe-8/…`, `groupe-9/…` | Audits | Aucun code. Ils **reconnaissent** des défauts non corrigés : `_findNearestStop` sans distance ni `null` (l.1135-1142, repli silencieux sur « dakar »/`allStops.first`), `distanceMeters` statique affichée comme distance utilisateur (l.1795), `_isSunday()` évalué une seule fois, horaires 100 % synthétiques, `DataTrust` parsé mais jamais lu, badges 🟢 « Officiel » sur horaires générés, assistant IA obsolète. | Constats corrects, **corrections absentes**. | Voir §H. |

---

## C. GPS — audit strict de `fb4da56` (et de `f3f5145` pour `DakarBounds`)

### C.1 Chaîne réelle dans B (code lu, pas supposé)

```
_requestLocation() l.1550            → isLocationServiceEnabled → checkPermission/requestPermission
  → Geolocator.getPositionStream(LocationSettings(high, distanceFilter: 10, timeLimit: 20 s)) l.1577-1582
      onData  : _applyGps(GpsResolver.fromMeasuredPosition(LatLng(lat, lng)))        l.1584-1585
      onError : _applyGps(GpsResolver.fromStreamInterrupted(_userPosition))         l.1586-1587
      onDone  : idem                                                                  l.1588-1589
GpsResolver.fromMeasuredPosition(measured) l.1441-1454
      measured == null            → GpsResolution(error, 'Erreur GPS.')
      !DakarBounds.isValid(m)     → GpsResolution(state: error, position: NULL, message: 'Position hors zone, recentré sur Dakar.')
      sinon                       → GpsResolution(granted, position: measured, 'Position GPS obtenue.')
_applyGps(r) l.1541-1548            → _gpsState = r.state ; _userPosition = r.position ; _gpsMessage = r.message
```

Consommateurs de `_userPosition` : `ExplorerPage.userPosition` (tri/rayon l.1762-1765, `initialCenter` l.1910-1912, marqueur utilisateur l.1937-1938, `didUpdateWidget` l.1675-1689, `_distanceTo` l.1795), `AIChatPage` (l.1838 → l.2952-2957).

### C.2 Réponses aux 7 vérifications demandées

| Vérification | Réponse | Preuve |
|---|---|---|
| Les coordonnées GPS réelles sont-elles conservées hors Dakar ? | **NON.** Une mesure hors `DakarBounds` est **jetée** : `position: null`. | l.1443-1448 ; test `gps_position_test.dart` l.176-190 qui l'exige (`expect(r.position, isNull)`). |
| Une coordonnée est-elle remplacée par 14.7167, −17.4677 ? | **NON, plus jamais comme position utilisateur.** La seule affectation de `_userPosition` est `_userPosition = r.position` (l.1545) et aucun chemin de `GpsResolver` ne produit un littéral. La constante subsiste à l.1771 **uniquement pour trier** la liste quand aucune position n'existe (`const dakarCenter` local), et `_dakarCenter` (14.72, −17.43, l.1652) ne sert qu'à `initialCenter`. | grep `14.7167` : l.1346 (commentaire), l.1771 (tri) ; grep `_userPosition =` : l.1541 seul. Test l.192 et garde-fou l.544-555. |
| Le GPS réel peut-il fonctionner en France / hors Dakar ? | **NON.** À Paris : état `error`, bandeau « Position hors zone, recentré sur Dakar. », **aucun marqueur utilisateur** (l.1937 conditionné à `isValid`), **aucune liste à proximité** (`nearbyStops` reçoit `null` → tri depuis `dakarCenter`, 30 premiers), assistant « Active ton GPS » (l.2957), bouton GPS relance simplement `_requestLocation` (l.1948). | l.1443-1448, l.1762-1774, l.1937, l.1948, l.2952-2957. |
| `DakarBounds` sert-il encore à falsifier/rejeter la position réelle ? | **Falsifier : non. Rejeter : OUI**, à 6 endroits : l.1443 (`fromMeasuredPosition`), l.1471 (`fromStreamInterrupted`), l.1679 (`didUpdateWidget`), l.1910 (`initialCenter`), l.1937 (marqueur), l.1948 (bouton via `gpsState`). | grep `DakarBounds.isValid` (16 occurrences, dont ces 6 sur la position). |
| La carte peut-elle afficher la vraie position hors zone ? | **NON** (position `null` avant même d'atteindre la carte ; de plus la carte n'a pas de `cameraConstraint` mais `minZoom 9`, donc rien n'empêcherait techniquement l'affichage si la position était conservée). | l.1909-1915, l.1937. |
| Le statut « hors couverture » est-il séparé de la position ? | **NON.** `GpsResolution` porte `state + position + message` mais le cas hors zone **fusionne** « hors couverture » et « erreur GPS » (`GpsState.error`) et **efface** la position. Aucun état `outOfCoverage`, aucun drapeau distinct ; `GpsState` conserve volontairement 7 valeurs (test l.321 « aucun état ajouté »). | l.1361-1383, l.1443-1448, l.1325. |
| Le code ne fabrique-t-il aucune position ? | **OUI, confirmé** : aucune position inventée. `isSubstitutedPosition` reste `false` partout (l.1372-1377). Réserve : `_distanceTo` (l.1795) affiche, sans position, `s.distanceMeters` — une valeur **statique fabriquée** (350, 1 200, `300 + i×800`…) présentée comme distance à l'arrêt (constat F7 documenté dans B et laissé tel quel). | l.1795, l.974, l.751-788. |

### C.3 Autres constats GPS (non bloquants, à vérifier)

- **`timeLimit: 20 s` sur un flux continu** (l.1581) : la valeur est recopiée du binaire prod (`B.Lf`) sans que la politique d'interruption de la prod soit connue (le code l'admet, l.1458-1468). Sur les plateformes mobiles de `geolocator`, l'expiration **ferme** le flux ; sur le web, le comportement exact dépend de l'implémentation `watchPosition`. Conséquence possible pour un utilisateur immobile : après 20 s sans nouvelle position, `onError/onDone` → `fromStreamInterrupted` ; en zone la dernière position est conservée mais **plus aucune mise à jour** n'arrive sans appui sur le bouton ; hors zone (`_userPosition == null`) le message devient « Erreur GPS. ». **Non prouvé en navigateur — à tester avant J9.**
- Le message « Position hors zone, **recentré sur Dakar** » est exact (la carte reste sur `_dakarCenter`) mais décrit une décision produit contraire à la règle du 22/09.
- Tri sans position depuis 14.7167/−17.4677 (l.1771) : ce n'est pas une position exposée, mais **c'est** la même constante historique ; à remplacer par le centre du réseau calculé si l'on veut supprimer toute trace du repli.

### C.4 Conclusion GPS

**Conforme à « jamais de position fabriquée » ; non conforme à « position réelle conservée hors Dakar / hors couverture = statut, pas rejet ».** La correction future est circonscrite : `GpsResolver.fromMeasuredPosition` / `fromStreamInterrupted` (l.1441-1479), les 4 gardes `isValid` de la carte (l.1679, l.1910, l.1937, l.1948), et les tests l.176-190, l.355-361 qui verrouillent le rejet. `DakarBounds` peut rester tel quel pour valider **les arrêts**.

---

## D. TER / BRT — ce qui est réellement corrigé dans B

### D.1 Tableau de vérification

| Point demandé | État dans B | Preuve | Verdict |
|---|---|---|---|
| 13 gares TER | Route JSON `ter_dakar_diamniadio` = 13 arrêts ; `officialRouteStops('ter_…')` et `DetailedRoute.fromOperator('ter')` en dérivent. | JSON ; l.842-860 ; l.458-466 ; tests `network_data_test` l.98, `ter_brt_route_data_test` l.207. | ✅ pour l'itinéraire et la fiche. ❌ pour la carte Explorer : **21 points TER** (13 JSON + 8 codés en dur). |
| 23 stations BRT | Route `brt_b1_guediawaye_petersen` = 23 arrêts distincts (ids, noms, coordonnées) ; B2 = 7 ⊂ B1. | JSON ; tests l.285-335. | ✅ itinéraire/fiche. ❌ carte : **27 points BRT** (23 JSON + 4 codés en dur). |
| Suppression de Keur Massar TER | Aucune gare « Keur Massar » dans la route TER ni dans `terStations` (les 8 entrées Dart sont Dakar ×2, Colobane, Hann, Pikine, Keur Mbaye Fall, Diamniadio ×2). `stop_keur_massar` (14.79, −17.325) subsiste comme arrêt DDD 23 / AFTU / Tata 218 — légitime (quartier réel). | l.750-759 ; JSON ; test l.120-146. | ✅ |
| Suppression des anciennes stations obsolètes | **NON.** Les 11 arrêts « … - BRT » du JSON (`stop_camberene`, `stop_dalal_jamm`, `stop_fadia`, `stop_grand_medine`, `stop_grand_yoff`, `stop_guediawaye`, `stop_liberte6`, `stop_obelisque`, `stop_parcelles_u26`, `stop_patte_doie`, `stop_sacre_coeur`) sont conservés, desservis par DDD/AFTU/Tata, donc **affichés en couleur DDD/AFTU avec un nom « BRT »**. Trois portent **le même nom** qu'une station B1 à une autre position : « Sacré-Cœur - BRT » (14.71/−17.465 vs 14.7166/−17.4635), « Liberté 6 - BRT Correspondance » (14.718/−17.455 vs 14.72631/−17.45919, 926 m), « Hôpital Dalal Jamm - BRT » (14.762/−17.41 vs 14.77287/−17.40979). Et les **4 entrées BRT codées en dur** (l.762-765) restent : « PEM Petersen » (422 m du PEM réel), **« BRT Colobane » (station inexistante, 678 m de la plus proche)**, « BRT Grand Dakar » 14.705/−17.44 (**1 468 m** de Dial Diop, la plus proche), « PEM Guediawaye » (322 m). | Simulation de `allStops` (§D.3) ; JSON. | ❌ |
| Source unique JSON | **Partielle.** Fiche de ligne, polylignes, `officialRouteStops` : JSON seul. Carte/liste Explorer, recherche, planificateur : `allStops` = **24 entrées Dart + 117 JSON** (l.791-793 + l.886-1048). | l.750-793, l.886-1048. | ⚠️ |
| Ordre des stations | TER : ordre JSON = ordre opérateur Dakar → Diamniadio (13/13). B1 : ordre JSON Guédiawaye → Petersen conforme à OSM/presse sauf **Fith Mith (#4)** placée entre Golf Nord et Dalal Jamm mais géolocalisée 731 m à l'ouest, plus près de Golf Nord (2 m) que de son quai — son ordre est correct, sa position ne l'est pas. | Recalcul §D.2. | ✅ ordre ; ⚠️ Fith Mith. |
| Coordonnées | TER : 13 gares à **11–142 m** de la carte opérateur. BRT : 21 stations à **2–324 m** des quais OSM ; **Fith Mith 731 m**, **Grande Mosquée ~524 m** (195 m de Papa Gueye Fall) ; « Gadaye - Cambérène » nommée « Gueule Tapée » dans OSM (156 m). | §D.2. | ✅ TER ; ⚠️ 2 stations BRT. |
| Polylignes | Une par ligne JSON, points = arrêts dans l'ordre : TER 13, B1 23, B2 7 (l.988-1008). Segments **droits** entre stations (pas de géométrie de voie) : écart maximal à la voie ferrée ≈ 0,5 km (Rufisque → Bargny) — acceptable en attendant J5. Chargées au démarrage (`isDedicated`, l.1691-1698), filtrées par couleur (l.1847-1849). | l.988-1008, l.1691-1702, l.1841-1850. | ✅ (indicatif) |
| Cohérence données ↔ carte | **NON acquise.** (1) `mapStops = _filteredStops` (l.1850) : marqueurs limités à **30 arrêts dans 4 km** de l'utilisateur (ou 30 plus proches du centre sans position) alors que la polyligne est complète : depuis le Plateau, filtre TER → **5 marqueurs** dont 2 gares réelles ; filtre BRT → 7 dont 4 stations réelles (simulation §D.3). (2) Les 12 faux points TER/BRT codés en dur s'affichent **à côté** des vrais, hors de la polyligne (Hann à 1 432 m, Keur Mbaye Fall à **3 464 m**, Grand Dakar à 1 468 m). | l.1738-1776, l.1850, l.1921-1936 ; §D.3. | ❌ |
| Données encore contradictoires | Oui : (a) 8 TER + 4 BRT codés en dur vs JSON ; (b) 3 homonymes JSON à positions différentes ; (c) libellés « - BRT » sur des arrêts non BRT ; (d) `data_trust: OFFICIAL` auto-déclaré affiché 🟢 « SETER (Officiel) » / « SunuBRT (Officiel) » (l.293-294) sur des horaires **générés** (`_generateSchedule` l.253-262, `_shift(_terBase, i×2)` l.961-963) ; (e) `distanceMeters: 300 + i×800` (l.974) fabriquée ; (f) « 14 gares officielles » (l.2938) ; (g) `long_name` B1 « Corridor SunuBRT 23 stations » vs 18,3 km CETUD absent. | l.253-262, l.293-297, l.961-974, l.2938. | ❌ |

### D.2 Coordonnées JSON de B (= prod) vs référentiels

TER (ordre JSON, distance à la gare opérateur homonyme) : Dakar 57 m · Colobane 142 m · Hann 72 m · Dalifort 11 m · Baux Maraîchers 121 m · Pikine 71 m · Thiaroye 72 m · Yeumbeul 142 m · Keur Mbaye Fall 34 m · PNR 48 m · Rufisque 48 m · Bargny 79 m · Diamniadio 128 m. **Ordre identique à la carte opérateur (13/13).**

BRT B1 (ordre JSON Guédiawaye → Petersen, distance au quai OSM le plus proche) : Préfecture 77 m · Gadaye/Gueule Tapée 156 m · Golf Nord 2 m · **Fith Mith 731 m (plus proche de Golf Nord)** · Dalal Jamm 210 m · Golf Sud 38 m · Ndingala 46 m · Parcelles 46 m · Croisement 22 199 m · Police des Parcelles 46 m · Grand Médine 268 m · Thiandoum 48 m · Scat Urbam 22 m · Khar Yalla 148 m · Liberté 6 43 m · Liberté 5 40 m · Sacré-Cœur 324 m · Liberté 1 49 m · Grand Dakar 57 m · Dial Diop 100 m · Place de la Nation 280 m · **Grande Mosquée 195 m de Papa Gueye Fall (≈ 524 m de son quai)** · Papa Gueye Fall 186 m.

Statut de ces coordonnées : **VÉRIFIÉ MAIS NON OFFICIEL** (concordance avec carte opérateur / OSM ; aucune publication nominative géoréférencée de la SETER ni du CETUD). Le champ `data_trust: OFFICIAL` du JSON n'est pas une preuve.

### D.3 Simulation de `allStops` et de la carte (règles de B reproduites : bornes 14.55–14.9 / −17.6–−16.85, clé de dédoublonnage `nom_lat_lon`, rayon 4 000 m, plafond 30)

| Mesure | Résultat |
|---|---|
| `allStops` | **141** = 24 Dart + 117 JSON (aucun dédoublonnage croisé : aucun couple nom+coordonnées identique) ; 0 orphelin |
| Points par couleur | TER **21** · BRT **27** · DDD 37 · AFTU 44 · Tata 12 (les tests l.142-152 fixent 21 et 27) |
| Entrées TER codées en dur → distance à la gare JSON la plus proche | Dakar 851 m / 846 m · Colobane 785 m · **Hann 1 432 m** · Pikine 600 m · **Keur Mbaye Fall 3 464 m** · Diamniadio 17 m / 55 m |
| Entrées BRT codées en dur → station JSON la plus proche | Petersen 422 m · **BRT Colobane 678 m (inexistante)** · **BRT Grand Dakar 1 468 m** · PEM Guediawaye 322 m |
| Fiche de ligne depuis ces points (`fromStop`, seuil 250 m) | 9 des 12 points TER/BRT codés en dur ne résolvent **aucune** ligne → SnackBar « données réseau non chargées » (l.614) alors que les données sont chargées |
| Marqueurs affichés, filtre TER | sans position : 21 (tous) · Plateau : **5** (2 gares JSON) · Pikine : 5 (4 JSON) · Guédiawaye : 4 (3 JSON) |
| Marqueurs affichés, filtre BRT | sans position : 27 · Plateau : **7** (4 stations JSON) · Pikine : 9 (8) · Guédiawaye : 9 (8) |
| Arrêts nommés « … BRT » sous couleur DDD/AFTU | **11** |

### D.4 Verdict TER/BRT

**Réellement corrigé** : fiche de ligne, polylignes, ordre, effectifs 13/23, suppression de Keur Massar TER et des littéraux `fromStop`/`demoRoutes`, arrêt en face non fabriqué.
**Partiellement / non corrigé** : carte Explorer (24 points codés en dur, dont 12 TER/BRT faux, verrouillés par tests), 11 arrêts « - BRT » obsolètes, 3 homonymes, marqueurs limités à la proximité, horaires et distances fabriqués étiquetés « Officiel », 2 positions BRT approximatives, textes résiduels.

---

## E. Tests

### E.1 Inventaire (9 fichiers, 232 tests déclarés = 232 exécutés en CI)

| Fichier | Origine | Tests | Ce qu'il teste réellement | Ce qu'il ne teste pas / réserve |
|---|---|---|---|---|
| `network_data_test.dart` | nouveau G1 | 22 | Contenu du JSON chargé par `DataService` : TER 13, ordre, inverse, Keur Massar absent, Dalifort/PNR présents, B1 23, B2 7 ⊂ B1, intégrité référentielle 105 lignes, unicité ids, bornes, aucun (0,0). | Exactitude géographique (aucune référence externe) ; homonymes ; arrêts « - BRT » obsolètes. |
| `data_service_test.dart` | modifié G1 | 10 | Chargement réel de l'asset (117/105/5), repli **non** utilisé, décomposition par opérateur, `stopsForRoute`. | Le repli lui-même (contenu fabriqué) n'est ni testé ni désactivé. |
| `dakar_bounds_test.dart` | modifié G1, G7 | 18 | Bornes de prod, Paris/(0,0) invalides, Hann/Dalifort/Baux valides, haversine, R = 6 371 008,8, `format` 3 branches. | Verrouille les 4 bornes ; test « placeholder » l.163 sans assertion utile. |
| `detailed_route_test.dart` | nouveau G2 | 37 | Dérivation TER/BRT depuis le JSON, ordre, inverse, distances calculées, résolution par id/nom/250 m, `null` sans fiche inventée, préférence d'opérateur. | Affichage `~N min` (valeur fabriquée non questionnée). |
| `opposite_stop_test.dart` | nouveau G3 | 34 | Passes 120 m / 500 m, priorités, `null`. | — |
| `gps_position_test.dart` | nouveau G4 | 40 | `GpsResolver` : granted/denied/deniedForever/serviceDisabled/error, **hors zone → null + error (l.176)**, jamais 14.7167 (l.192), rayon 4 000/plafond 30, interruption de flux, 7 gardes-fous **par regex sur le source**. | Aucun test du widget/flux réel ; **verrouille la politique de rejet hors zone** ; gardes-fous textuels fragiles (cassent à tout renommage, ne prouvent pas un comportement). |
| `ter_brt_route_data_test.dart` | nouveau (d5a82b8) | 57 | Explorer ≠ itinéraire, **21/27 points Explorer conservés (l.142-152)**, 13/23, ordre, distinctes, polylignes = stations, aucun doublon de tracé, idempotence. | **Verrouille les 24 points codés en dur** (défaut érigé en invariant) ; ne teste pas le rendu carte (`_filteredStops`/`mapStops`). |
| `groupe6_alertes_test.dart` | nouveau G6 | 12 | Textes AlertsPage/Community rendus (`testWidgets`) + gardes-fous source. | — |
| `widget_test.dart` | hérité | 2 | Smoke. | — |

### E.2 Passent-ils ?

**Oui — prouvé par la CI, pas localement** (aucun SDK Flutter dans cet environnement ; `storage.googleapis.com` et `pub.dev` inaccessibles). Check run `106640360154` sur `ac03557` : `Analyzing flutter-src... No issues found!` ; `flutter test --reporter expanded` : `00:03 +232: All tests passed!` ; statut `flutter-4b/decompte = success`, « tests +232/-0 | 9 fichiers | analyze 0 issue(s) | exit a=0 t=0 | Flutter 3.24.5 • channel stable ». La somme des `test(` déclarés par fichier (18+10+37+40+12+22+34+57+2) vaut exactement 232 : aucun test ignoré. Historique : 5 pushes rouges (`f3f5145`, `c9fcdca`, `fb4da56`, `d5a82b8`, `0e2a157`) corrigés par le commit suivant à chaque fois (diagnostics analyze, YAML).

### E.3 Ce que la suite ne couvre pas

- Rendu de la carte Explorer (marqueurs = `_filteredStops`, polylignes) — aucun `testWidgets` sur `ExplorerPage`.
- Exactitude géographique vs référentiel externe (opérateur/OSM) — seulement la cohérence interne.
- Chaîne horaires → prochain départ → attente (0 test, reconnu par le doc groupe-7 §N.2).
- `RoutePlanner` / `_findNearestStop` (repli silencieux non testé).
- Le repli `_loadFallbackData` (contenu fabriqué), `RoutingService` (OSRM public).
- Compilation **web** (les tests tournent sur la VM Dart, pas via dart2js).

### E.4 Tests insuffisants ou trompeurs

1. `ter_brt_route_data_test.dart` l.142-165 : « Explorer conserve tous ses points existants » / « affiche PLUS de points que l'itinéraire » — **transforme un défaut (12 faux points TER/BRT) en garantie**.
2. `gps_position_test.dart` l.176-190 et l.355-361 : imposent `position == null` hors zone — **contraires à la règle du 22/09**.
3. Les 7 « GARDE-FOU SOURCE » (`File('lib/main.dart')` + regex) : testent l'absence de chaînes (`'< 5000'`, `DataStatus.live`, `_userPosition = const LatLng`) — utiles comme anti-régression textuelle, mais **ne prouvent aucun comportement** et échoueront sur toute refactorisation légitime.
4. `dakar_bounds_test.dart` l.56 « les bornes sont celles de la production » : la production n'est pas une source de vérité géographique.

---

## F. Build — B peut-il produire `flutter build web` avec Flutter 3.24.5 ?

| Critère | Constat | Preuve |
|---|---|---|
| Toolchain déjà exercée sur B | `flutter pub get`, `flutter analyze`, `flutter test` réussissent sous **Flutter 3.24.5 stable** (Java 17, `subosito/flutter-action@v2`, `working-directory: flutter-src`). | 23 runs « Flutter verify (Step 4B) », dernier `success` le 22/09 06:30 UTC. |
| `flutter build web` exécuté sur B ? | **Jamais.** Le workflow actif n'a pas d'étape build ; le `deploy.yml` hérité (qui construit avec `--base-href "/dakar-bus/"`) est **inactif** (sous `flutter-src/.github/`). | `flutter-verify.yml` l.70-85 ; `gh run list` : aucun run de build. |
| Compatibilité web statique | Imports de `lib/` **identiques à A** (`dart:async/convert/math/ui`, flutter, flutter_map, latlong2, geolocator, http) ; **aucun `dart:io`, `Platform`, `dart:html`**. A a produit le 1ᵉʳ build web `2c96eef` avec 3.24.5. Les tests importent `dart:io` (autorisé côté test). | grep imports ; `git ls-tree 2c96eef`. |
| Contraintes de version | `sdk >=3.3.0 <4.0.0` et `flutter >=3.19.0` compatibles avec 3.24.5 (Dart 3.5.4). | `pubspec.yaml`. |
| **Reproductibilité** | **Non garantie** : pas de `pubspec.lock` → `flutter_map ^6.1.0`, `geolocator ^12.0.0`, `http ^1.2.2`, `latlong2 ^0.9.1`, `flutter_lints ^4.0.0` sont résolus à chaque build à la dernière version compatible. Deux builds à des dates différentes peuvent embarquer des dépendances différentes. | `.gitignore`, arbre `flutter-src/`. |
| `web/index.html` | Chargeur `flutter.js` + `loadEntrypoint` (déprécié depuis 3.22 au profit de `flutter_bootstrap.js`), mais **toujours supporté en 3.24.5** (preuve : `2c96eef`). Aucun `serviceWorker` configuré → le SW généré ne sera pas enregistré par le chargeur ; l'ancien SW patché (« v6 », OSRM hors-ligne) présent chez les utilisateurs sera remplacé/neutralisé selon le navigateur. | `web/index.html` l.17-27 ; `flutter_service_worker.js` de prod. |
| Cible GitHub Pages | Pages est configuré en **`build_type: legacy`, source `gh-pages` / `/`**. Le `deploy.yml` hérité utilise `actions/deploy-pages` (nécessite `build_type: workflow`). Deux options pour J9 : (a) passer Pages en « GitHub Actions » ; (b) publier `build/web` sur `gh-pages` (ce qui **écrase** les patches manuels, le bundle OSRM et les assets « secours »). Branches `main`/`gh-pages` non protégées. | `gh api …/pages`. |
| Différences fonctionnelles attendues vs prod actuelle | `RoutingService` appelle **directement `https://router.project-osrm.org`** (l.134) pour les lignes non dédiées (prod : `/dakar-bus/osrm/…` servi par le SW + bundle de 299 géométries) ; en cas d'échec, segments droits (l.155-157). Version affichée dans Réglages : **« Dakar Bus v9.4 (Web Fix) »** (l.2796) alors que la prod affiche « v9.3.2 build 12 » (patch JS `a0ae515`). `version.json` généré = `9.3.2` / `12` = identique à la prod. | l.134, l.2796 ; audit du 22/09 §H. |

**Réponse** : techniquement, `flutter build web --release --base-href /dakar-bus/` sur B avec 3.24.5 a **toutes les chances d'aboutir** (même code de plateforme que le 1ᵉʳ build réussi, toolchain déjà validée jusqu'à `flutter test`), mais **ce n'est pas prouvé** et le build **ne serait pas reproductible** sans `pubspec.lock`.

---

## G. Réponses aux 8 questions

**1. B est-il techniquement une bonne base pour Dakar Bus ?** — **Oui, avec réserves.** Source propre et lisible, importé à l'identique de `2c72e57`, version `9.3.2+12` commitée, analyze 0 issue, 232 tests verts, données JSON de prod (coordonnées TER/BRT exactes), fiche de ligne et polylignes dérivées d'une source unique, suppression de plusieurs fabrications (Station Intermédiaire, faux arrêt en face, horodatages fictifs, badge « En direct »). Réserves : décisions produit contraires aux règles du 22/09 (GPS hors zone, 24 points de démonstration), absence de lock, dette reconnue mais non traitée (horaires synthétiques, badges, planificateur).

**2. Quelles corrections de B sont fiables ?** — G1 JSON (forme) et bornes pour les **arrêts** ; G1 rayon terrestre et version ; G2 `DetailedRoute` dérivée du JSON (hors `~N min`) ; G3 arrêt en face ; d5a82b8 polylignes depuis le JSON et suppression des `demoRoutes` littéraux ; G4 suppression de toute position fabriquée, flux continu, états `denied/deniedForever`, bandeau GPS, `dispose` ; G5/G6 textes ; G7-P1 format de distance. Les 232 tests associés passent.

**3. Quelles corrections doivent être vérifiées ou reprises ?** — (a) **GPS hors zone** (`fromMeasuredPosition`, `fromStreamInterrupted`, 4 gardes de carte, tests l.176/355) ; (b) **24 arrêts codés en dur** (l.750-788) et les tests qui les verrouillent (`kTerExplorerPoints`/`kBrtExplorerPoints`) ; (c) `mapStops = _filteredStops` (l.1850) ; (d) `timeLimit 20 s` à valider en navigateur ; (e) message de `openLineDetail` (l.614) ; (f) « Données officielles » et badges 🟢 fondés sur `data_trust` auto-déclaré ; (g) `~N min` (l.388, l.3107) ; (h) 11 arrêts « - BRT » obsolètes et 3 homonymes du JSON ; (i) Fith Mith / Grande Mosquée.

**4. Le GPS de B est-il conforme à « jamais de position fabriquée » ?** — **Oui pour la fabrication** (aucun littéral n'est jamais exposé comme position utilisateur — prouvé). **Non pour l'usage hors Dakar** : la position réelle est rejetée, le statut « hors couverture » n'existe pas séparément, la carte ne peut pas l'afficher, `DakarBounds` reste le juge de la position (§C.2).

**5. TER/BRT réellement corrigés ou partiellement ?** — **Partiellement.** Corrigé : itinéraires, fiches, polylignes, effectifs, ordre, Keur Massar. Non corrigé : carte Explorer (faux points, arrêts obsolètes, limitation à 30/4 km), horaires/distances fabriqués étiquetés « Officiel », 2 positions BRT approximatives, textes résiduels (§D).

**6. Quels problèmes restent avant J9 ?** — Voir §H (bloquants : lock, GPS hors zone, points codés en dur + tests ; non bloquants : textes, OSRM, icônes/manifest, SW).

**7. J9 peut-il être exécuté proprement après cet audit ?** — **Oui, sous conditions** : (1) décider la cible Pages (workflow vs `gh-pages`) ; (2) commiter un `pubspec.lock` ; (3) placer un workflow **à la racine** (le `deploy.yml` hérité est un bon modèle : 3.24.5, analyze, test, build `--base-href /dakar-bus/`), avec `working-directory: flutter-src` et **sans aucune étape de patch** de `main.dart.js` ; (4) accepter que le premier déploiement depuis B **remplace** les patches manuels et le bundle OSRM de la prod, **et** qu'il expose les défauts restants (faux points, « v9.4 (Web Fix) », « 14 gares » dans l'IA) si J1/J2/J3 ne sont pas faits avant. Recommandation : corriger d'abord les deux textes (l.2796, l.2938) et le GPS hors zone — petits, isolés — puis J9, puis le reste.

**8. Risque de modifications non désirées par rapport au projet officiel ?** — **Oui, identifié et borné.** B applique un cahier des charges externe (« Phase 0 », « 4A », « Cartes », « §… ») **non présent dans le dépôt** (seul `docs/dakar-bus/groupe-5/PLAN_PERIMETRE.md` le mentionne). Trois de ses décisions contredisent les règles d'aujourd'hui (rejet hors zone D1-i ; conservation des points de démonstration ; « la production binaire fait preuve »). Autres éléments discutables mais explicites : `distanceMeters` statique affichée comme distance (F7, laissé volontairement), `~N min` fabriqué, `version.json` identique à la prod. Aucune modification cachée : l'import est identique à `2c72e57`, chaque changement est tracé par commit, et aucun fichier hors `flutter-src/`, `docs/dakar-bus/`, `flutter-verify.yml` n'est touché.

---

## H. Problèmes restants avant J9 (état de B, sans correction)

| # | Problème | Où | Bloquant pour J9 ? | Lien avec le plan J1–J10 |
|---|---|---|---|---|
| H1 | Pas de `pubspec.lock` → build non reproductible | `flutter-src/` | **Oui** (objectif « build reproductible ») | J9 |
| H2 | Position réelle hors `DakarBounds` rejetée, statut non séparé | l.1441-1479, l.1679, l.1910, l.1937, l.1948 ; tests l.176, l.355 | **Oui** au regard de la règle GPS (à traiter avant ou avec J9, correction isolée) | J6-A (variante GPS) |
| H3 | 24 arrêts codés en dur (12 TER/BRT faux) + tests qui les verrouillent | l.750-793 ; `ter_brt_route_data_test.dart` l.110-165 | Fortement recommandé avant mise en prod (sinon régression visible vs l'objectif 13/23 sur la carte) | J2 / J3 |
| H4 | Marqueurs limités à 30 / 4 km (ligne incomplète sur la carte) | l.1738-1776, l.1850 | Non bloquant, mais symptôme initial non traité | J1 |
| H5 | « Dakar Bus v9.4 (Web Fix) » dans Réglages ; « 14 gares officielles » dans l'IA | l.2796, l.2938 | Régression visible dès le 1ᵉʳ build → à corriger avant J9 (2 lignes) | J8 |
| H6 | 11 arrêts « - BRT » obsolètes, 3 homonymes JSON, Fith Mith/Grande Mosquée | `assets/data/dakar_network.json` | Non bloquant | J3 |
| H7 | Horaires/`distanceMeters`/`~N min` fabriqués sous badge 🟢 « Officiel » ; `data_trust` jamais lu | l.253-262, l.293-297, l.388, l.961-974, l.1795 | Non bloquant (déjà en prod) | J7 |
| H8 | `_findNearestStop` sans distance ni `null` (planificateur) | l.1135-1142 | Non bloquant | hors plan (à ajouter) |
| H9 | Repli mémoire `_loadFallbackData` (réseau fabriqué si l'asset échoue) | `data_service.dart` l.34-40 | Non bloquant | J7 |
| H10 | `RoutingService` → OSRM public direct ; perte du bundle hors-ligne de la prod | l.124-158 | Non bloquant ; à décider (bundle commité côté source ou lignes droites assumées) | J5 / J10 |
| H11 | `web/` sans icônes, manifest vide, méta « 40 lignes » ; README « 9.3.0+4 / 92 arrêts » | `web/`, `README.md` | Non bloquant | J8 |
| H12 | `timeLimit 20 s` du flux GPS : comportement navigateur non vérifié | l.1581 | Non bloquant ; test manuel à prévoir | J4 |
| H13 | Workflow de vérification déclenché uniquement sur `arena/01a0c385-dakar-bus` | `.github/workflows/flutter-verify.yml` l.32-35 | À adapter au nouveau workflow J9 | J9 |

---

## I. Conclusion sur B

- **Adopter B comme base officielle : recommandé.** Il n'existe aucune alternative commitée équivalente (A = état brut avec tous les défauts ; la prod = binaire non reconstructible).
- **Ne pas déployer B tel quel** : trois corrections courtes doivent précéder ou accompagner J9 (H1 lock, H2 GPS hors zone, H5 textes) et la question des 24 points codés en dur (H3) doit être tranchée, car les tests actuels **empêchent** de les retirer sans réécriture des tests.
- **Ordre proposé après validation** : H5 + H2 (petits, isolés, testables) → H1 + J9 (workflow racine, lock, build, cible Pages) → H3/H4 (J2/J3/J1) → H6/H7 (J3/J7) → reste.

### Critère de fin

| Élément | État |
|---|---|
| Code modifié | **Aucun** |
| Workflow créé ou modifié | **Aucun** |
| `flutter-src/` copié dans la branche de travail | **Non** (lecture via Git et extraction temporaire hors dépôt) |
| Commit / push / déploiement / fusion | **Aucun** |
| Branche | `arena/01a0ca19-dakar-bus`, inchangée |
| Fichier créé | `docs/AUDIT_BASE_B_2026-09-22.md` uniquement |

**En attente de votre décision** : (1) adoption de B comme base ; (2) importation de `flutter-src/` de `ac03557` dans cette branche ; (3) ordre des corrections préalables à J9.
