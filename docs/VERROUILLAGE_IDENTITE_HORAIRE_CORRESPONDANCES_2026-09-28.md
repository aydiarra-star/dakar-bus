# Lot 4.21 (suite) — Verrouillage : identité publique ≠ horaire ≠ correspondances

**Date :** 2026-09-28  
**Branche :** `arena/01a0e820-dakar-bus` (session Arena — poursuite du Lot 4.21 de `arena/01a0e53c-dakar-bus`, PR #38) · **PR vers `main` :** #39 · **SHA validé :** `9699f62`  
**Périmètre :** TATA, DDD, AFTU, routing engine, identité vs horaire, horaires, tests.  
**Interdits respectés :** TER, BRT B1/B2, GPS, cartographie, UI validée et PR #31 non modifiés ; aucune donnée de transport créée ; aucune hypothèse transformée en identité confirmée.

---

## 1. Règle unique (verrouillée en données, moteur et tests)

Trois notions restent **strictement séparées** :

| Notion | Champ(s) | Règle |
|---|---|---|
| **Disponibilité horaire** | `schedule_status` / `scheduleAvailable` | Calculable uniquement depuis de **vrais trips + stop_times** PassBi (+ service actif). Jamais depuis une fréquence, jamais estimé, jamais REAL_TIME. |
| **Identité publique** | `identity_status` (`IdentityStatus`) | `CONFIRMED` **uniquement avec preuve documentaire** (`IDENTITY_OFFICIELLE` : TER corridor, BRT B1, BRT B2). Un numéro, un `route_id`, un nom similaire, OSM, une proximité ou des terminus proches (`TERMINI_MATCH`) **ne confirment jamais**. |
| **Correspondance intermodale** | `crosswalk.transfers` → `source.transfers` → moteur | Uniquement **un même arrêt physique réellement desservi** ou **un lien documenté du crosswalk à nom vérifié** (≤ 500 m, méthodes `NOM_IDENTIQUE_PROXIMITE` / `INCLUSION_NOM_PROXIMITE`). **Jamais la seule proximité. Jamais une identité publique (confirmée ou non) comme preuve.** |

Une route PassBi DDD/AFTU peut donc avoir **horaire disponible + identité UNKNOWN** — l'ancien bug « identité non confirmée = horaire indisponible » n'est pas réintroduit (chemin natif conservé).

## 2. TATA — audit et garde-fous

**Constat d'audit :** aucun feed PassBi TATA (`data/transit/passbi/` : TER, BRT, Dem_Dikk, AFTU uniquement ; `PassBiSource.assetFiles` sans TATA), aucune route/mode/agency TATA dans les feeds (`tataMentions()` vide). Le référentiel dakar documente lui-même que « Tata » désigne les minibus des GIE AFTU et que CETUD ne publie pas de réseau Tata distinct.

**État conservé :** les 7 identités `tata_*` restent `UNMAPPED` / `RESEAU_ABSENT_DU_FEED` / `UNKNOWN` (mention comme réseau non documenté uniquement) ; zéro route TATA fabriquée ; zéro identité TATA confirmée ; zéro correspondance TATA (0 lien dans le crosswalk, moteur muet sur toute clé `TATA:…`).

**Tests anti-fabrication explicites :** `passbi_verrouillage_421_test.dart` (1a–1c) et `tests/passbi-verrouillage-421.test.js` (2a–2b) — tout ajout futur de route TATA, de feed TATA, de rattachement ou de correspondance fait échouer la suite.

## 3. AFTU — réévaluation des mappings `AFTU_8 → AFTU_3` et `AFTU_11 → AFTU_3`

Ces deux mappings reposaient **uniquement** sur `TERMINI_MATCH` (score 0,92 de termini proches) et pointaient **tous les deux vers la même route PassBi `AFTU_3`** (auto-fusion de deux lignes publiques distinctes). Réévaluation appliquée :

* les terminus proches **ne confirment plus** une identité : les deux mappings sont déclassés en `UNMAPPED` / `IDENTITE_NON_CONFIRMEE` ;
* l'observation reste archivée dans un champ `hypothesis` (`pbRouteId: AFTU_3`, `method: TERMINI_MATCH`, `score: 0.92`) + note « Aucune fusion automatique : 2 identités publiques distinctes (aftu_8, aftu_11) pointent vers la même route PassBi AFTU_3 » ;
* **aucune fusion automatique** : ni l'une ni l'autre n'est rattachée ; `dakarRouteIdsFor('AFTU','AFTU_3')` reste vide ;
* les horaires PassBi d'`AFTU_3` restent **calculables** sous son identifiant PassBi (« Ligne PassBi AFTU_3 · A3PY »), statut horaire distinct du statut identité.

Généralisation (générateur `scripts/build-passbi-processed.mjs`) : aucun mapping DDD/AFTU ne devient `MAPPED` sans preuve documentaire ; toute méthode d'appariement approximatif ne produit qu'une hypothèse ; un garde-fou anti-fusion déclasse tout mapping réel conflictuel. `RouteMapping.isMapped` (Dart) exige `documentedIdentityMethods` : un `MAPPED` codé à la main avec `TERMINI_MATCH` est **rejeté par le moteur** (test 4b).

## 4. DDD — identité ≠ horaire (ex. `DDD_217` / `D217OT`)

* `DDD_217` reste exploitable pour calculer un horaire PassBi réel (52/53 routes DDD ont des horaires calculables) ;
* son identité publique reste **UNKNOWN / UNCONFIRMED** : présentation « Ligne PassBi DDD_217 · D217OT » — l'identifiant PassBi n'est **jamais** présenté comme le numéro public DDD ;
* les tronçons d'itinéraire dont l'identité n'est pas confirmée sont explicitement marqués « PassBi … » (`PassBi DDD_217`, `PassBi AFTU_3`) — contenu de libellé uniquement, aucun changement d'apparence (styles, couleurs, mise en page inchangés) ;
* `identity_status` et `schedule_status` portent des valeurs indépendantes partout (`PassBiRouteSummary`, `DepartureInfo`, `ScheduleProvider`).

## 5. Routing engine — `source.transfers`

Audit de `flutter-src/lib/services/gtfs/routing_engine.dart` : les correspondances proviennent **exclusivement** de `source.transfers` (liens du crosswalk) ou d'un arrêt partagé ; le moteur ne crée aucun lien géographique.

Verrous ajoutés :

* `TransferLink.isDocumented` : méthode de nom vérifié + nom non vide + distance ≤ 500 m + clés dans les réseaux des feeds (TATA rejeté) ;
* `CrosswalkParser.decode` : tout lien non documenté est **rejeté au chargement** (un crosswalk bricolé ne peut pas injecter une correspondance par proximité) ;
* `PassBiRoutingEngine._linksFrom` : revérification `isDocumented` (défense en profondeur) ;
* les rattachements d'arrêts n'existent que dans le périmètre des identités **documentées** : une identité non confirmée (aftu_8/aftu_11) ne sert jamais de pont ni de preuve ;
* miroir Node (`tests/helpers/passbi-engine419.mjs`, `passbi-native421.mjs`) aligné sur les mêmes filtres.

**Matrice testée (transitions = arrêt partagé OU lien documenté) :** TER→DDD, TER→AFTU, BRT→DDD, BRT→AFTU, DDD→AFTU, AFTU→DDD ; TATA→tout réseau = **zéro**. Proximité seule (D_12 ↔ A_345 à 9,8 m, noms différents) = **zéro** correspondance.

## 6. Horaires

* uniquement de vrais `trip` + `stop_time` du feed (test : tout départ SCHEDULED existe comme `stop_time` réel) ;
* aucune fréquence convertie en horaire individuel (`frequencyMinutes` nul sur le chemin PassBi ; les fréquences officielles TER/BRT legacy restent ESTIMATED) ;
* aucun faux « 0 min » (libellé « moins d'une minute » sous la minute) ; jamais REAL_TIME ;
* countdown dynamique : recalculé à chaque instant de demande (heure de Dakar = UTC+0).

## 7. Fichiers modifiés

| Fichier | Changement |
|---|---|
| `scripts/build-passbi-processed.mjs` | Règles d'identité (preuve documentaire seule), hypothèses archivées, garde-fou anti-fusion, règles meta |
| `flutter-src/assets/data/passbi/crosswalk.json` | Régénéré : 3 MAPPED documentés (TER, B1, B2) ; aftu_8/aftu_11 déclassés + `hypothesis` ; transferts inchangés (1505) |
| `data/transit/passbi/processed_manifest.json` | Stats crosswalk régénérées (sorties d'identiques) |
| `flutter-src/lib/services/gtfs/passbi_source.dart` | `RouteMapping.isMapped` documentaire, `TransferLink.isDocumented`, filtre parseur, `identityStatusOf` |
| `flutter-src/lib/services/gtfs/routing_engine.dart` | Garde-fou `isDocumented` + doc |
| `flutter-src/lib/services/schedule_provider.dart` | Doc `identityLabelFor` (PassBi ≠ numéro public) |
| `flutter-src/lib/models/departure_info.dart` | Doc `IdentityStatus.confirmed` (preuve documentaire) |
| `flutter-src/lib/main.dart` | Libellé de tronçon « PassBi … » si identité non confirmée (contenu uniquement) |
| `tests/helpers/passbi-engine419.mjs` / `passbi-native421.mjs` | Miroirs alignés (filtres transferts, identité documentaire) |
| `tests/passbi-gtfs.test.js` / `tests/passbi-ddd-aftu-421.test.js` | Compteurs et assertions alignés sur la règle |
| `flutter-src/test/passbi_ddd_aftu_421_test.dart` / `passbi_ui_integration_420_test.dart` | Anciennes assertions TERMINI_MATCH mises à jour |
| `flutter-src/test/passbi_verrouillage_421_test.dart` | **NOUVEAU** — matrice de verrouillage Dart |
| `tests/passbi-verrouillage-421.test.js` | **NOUVEAU** — matrice de verrouillage Node |
| `scripts/audit-passbi-ddd-aftu.mjs` | Section identité : preuves, hypothèses, anti-fusion, TATA |
| `.github/workflows/flutter-verify.yml` / `flutter-web-build.yml` | Branche de session ajoutée aux déclencheurs |

## 8. Résultats

* **Node / npm test :** 95/95 (82 préexistants + 13 nouveaux) — `node --test tests/*.test.js`.
* **Audit PassBi :** `node scripts/audit-passbi-ddd-aftu.mjs` — 3 identités confirmées (preuve documentaire), 2 hypothèses non confirmées (aftu_8/aftu_11≈AFTU_3), 0 fusion, 0 transfert TATA.
* **Flutter (CI — `flutter-verify` + `flutter-web-build`, Flutter 3.24.5), SHA `9699f62` :** ✅ `flutter analyze` **0 issue** · ✅ `flutter test` **503/503** (481 préexistants + 22 verrouillage) · ✅ `flutter build web` · ✅ `TER BRT data validation`. Premier run (`e99dc81`) : +481/-1, 8 erreurs — import manquant `models/transport_network.dart` (`ScheduleStatus`) dans le test de verrouillage, corrigé dans `9699f62` (uniquement le test, aucun code métier touché).

## 9. Non-régressions

* TER corridor, BRT B1 / BRT B2 : identités `IDENTITY_OFFICIELLE`, chemins crosswalk SCHEDULED inchangés (tests 6a–6c + suites 419/420 existantes) ;
* aucun fichier TER/BRT/GPS/cartographie/UI de style modifié ; PR #31 intacte ;
* feeds source (zip) et sorties `ter/brt/ddd/aftu.json` **bit-à-bit identiques** (génération déterministe).
