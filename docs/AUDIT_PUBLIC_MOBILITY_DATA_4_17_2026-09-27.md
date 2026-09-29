# Lot 4.17 — Audit des données publiques de mobilité pour Dakar Bus

**Date :** 2026-09-27
**Branche :** `arena/01a0e370-dakar-bus`
**Nature :** audit documentaire + intégration autorisée des données publiques réellement accessibles. **Aucun contact d'opérateur, aucun mail, aucun faux endpoint, aucune invention.**
**Rapports prérequis :** `docs/AUDIT_SOURCES_ETA_4_15_2026-09-27.md` (état des sources ETA), `docs/ETA_DATA_REQUESTS_4_16_2026-09-27.md` (demandes préparées, restées sans réponse → ce lot n'attend plus de réponse externe).

**État en entrée (Lot 4.15) :** TER ETA défendable sous conditions (terminus) ; B1/B2/B3 ETA non défendables ; DDD/AFTU source à obtenir ; 0 flux GTFS-RT réel ; 0 retard établi ; 0 interruption établie.

---

## 1. Sources examinées

| # | Source | Type | Nature de l'examen | Résultat principal |
|---|---|---|---|---|
| S1 | PassBi (senpassbi.com, Google Play, app web, docs API) | PUBLIC_APP | Site marketing, fiche Play Store, PWA `app.senpassbi.com`, documentation API publique | Déclare utiliser « des données GTFS publiques centralisées par le CETUD » (cetud, sunubrt, terdakar, demdikk) ; API de production **suspendue** ; **4 fichiers GTFS bruts accessibles** dans le dépôt public GitHub `impactsolutionsas/passbi_core` → récupérés |
| S2 | PassBi Core API (`passbi-api.onrender.com`) | PUBLIC_APP | Interrogation `/health` et `/v2/routes/list` | « This service has been suspended. » → **aucun prochain départ exploitable** |
| S3 | Dakar Transit (dakartransitsenegal.online) | PUBLIC_WEBSITE | Landing marketing + lien « Application Web » | Interface « LIVE » codée en dur (compteurs « 2 min », « 118 lignes », « 2 720 arrêts ») ; page app `dakar_transit_v2.html` = **404 Netlify** ; **aucune donnée structurée exposée** |
| S4 | SunuBRT (sunubrt.sn) | OFFICIAL_OPERATOR | Accueil + page « Horaires et arrêts » | Identités B1/B2/B3 (+ B4 « prochainement »), fréquence 6 min (06h–21h, 7j/7), 23 stations B1 ; page horaires rendue par formulaire/hCaptcha — **aucun fichier structuré** |
| S5 | Dakar Dem Dikk (demdikk.sn) | OFFICIAL_OPERATOR | Pages lignes/info-voyageurs (Lot 4.15, même date) | Listes de lignes + 1er/dernier départ seulement ; `horaires/` = 404 ; **aucun GTFS public** |
| S6 | AFTU (aftu-senegal.org) | OFFICIAL_OPERATOR | Infos pratiques (Lot 4.15) | Identité des lignes + liens carte ; **zéro donnée temporelle** |
| S7 | TER SETER (terdakar.sn, sentersa.sn, app TER INFOS) | OFFICIAL_OPERATOR | Horaires/fréquences (Lot 4.15) | Fréquences 10/20 min + 1ers départs ; app TER INFOS sans API publique ; **aucun GTFS/RT** |
| S8 | CETUD (cetud.sn : réseaux DDD, système de données) | OFFICIAL_INSTITUTION | Revérification 2026-09-27 | « GTFS destinés à l'open data et aux applications mobiles » **annoncés mais non téléchargeables** (lien = image JPEG ; page système de données = observatoire trafic, sans fichier GTFS) |
| S9 | busmaps.com (feedlist Sénégal) | COMMUNITY | Consultation du répertoire | 1 seul feed « Senegal » : `drk-nam` (provider « City-of-Windhoek », 2 routes/123 stops, **expiré déc. 2022**, mal étiqueté Dakar) ; téléchargements conditionnés à formulaire → **non récupérable** |
| S10 | Géoportail Sénégal (africageoportal) | PUBLIC_INSTITUTION | Dataset « Réseaux de transport » | Shapefile géométrie réseau (janv. 2022, « No License Provided », données 2020) → **géométrie seule, sans licence** |
| S11 | Mobility Database / transport.data.gouv | COMMUNITY | Recherche de feeds Sénégal | **Aucun flux GTFS sénégalais** (constat Lot 4.15, reconduit) |
| S12 | OpenStreetMap | COMMUNITY | Rôle complémentaire confirmé | Géométrie/coordonnées/contexte — **jamais source d'horaire ni d'exploitation** |
| S13 | Moovit, bus-senegal.sn | COMMUNITY | Revérification | Revendications « temps réel » sans API ni source vérifiable → **rejetées comme source** (Lot 4.15) |

## 2. URLs

- https://senpassbi.com/
- https://play.google.com/store/apps/details?id=com.senpassbi.app
- https://app.senpassbi.com/
- https://impactsolutionsas.github.io/passbi_core/ (+ `guides/`, `api/openapi.yaml`, `api/reference/data-models.md`)
- https://passbi-api.onrender.com/health et /v2/routes/list
- https://github.com/impactsolutionsas/passbi_core (dossier `gtfs_folder/`)
- https://raw.githubusercontent.com/impactsolutionsas/passbi_core/main/gtfs_folder/{gtfs_TER,gtfs_BRT,gtfs_Dem_Dikk,gtfs_AFTU}.zip
- https://dakartransitsenegal.online/ (+ `/dakar_transit_v2.html` → 404)
- https://www.sunubrt.sn/ et https://www.sunubrt.sn/mon-trajet-en-brt/horaires-et-arrets/
- https://demdikk.sn/ et https://demdikk.sn/info-voyageurs/
- https://aftu-senegal.org/infos-pratiques/
- https://www.terdakar.sn/les_horaires_des_trains/ ; https://sentersa.sn/plan-de-transport/
- https://cetud.sn/reseaux-de-transport/ddd/ ; https://cetud.sn/observatoire/systeme-de-donnees/
- https://busmaps.com/en/senegal/feedlist
- https://senegal.africageoportal.com/datasets/be2d26df9c4944b6ae07a628d9524308
- https://www.mobilitydatabase.org (recherche « Senegal »)

## 3. Date de consultation

**Toutes les sources ci-dessus : 2026-09-27.** Les éléments repris des Lots 4.15/4.16 (mêmes journées) sont indiqués comme tels ; revérifications effectuées ce jour : CETUD système-de-donnees, SunuBRT (accueil + horaires), PassBi (site, Play Store, PWA, docs API, API prod), Dakar Transit, busmaps, Géoportail.

## 4. Réseaux couverts

| Réseau | Couvert par les sources de ce lot ? | Quelle source ? |
|---|---|---|
| TER | Oui (structure + historique) | PassBi `gtfs_TER.zip` (SETER) ; fréquences officielles terdakar/sentersa (4.15) |
| BRT B1 | Oui (structure + historique 2024) | PassBi `gtfs_BRT.zip` ; identité officielle sunubrt.sn |
| BRT B2 | Oui (structure + historique 2024) | idem |
| BRT B3 | **Non** (absent du feed PassBi ; identité officielle seulement) | sunubrt.sn (7 stations, pointe lun–ven) |
| DDD | Oui (structure + historique 2022–2023) | PassBi `gtfs_Dem_Dikk.zip` |
| AFTU | Oui (structure + historique 2022–2023) | PassBi `gtfs_AFTU.zip` |
| TATA (minibus) | Non | — |
| GTFS-RT / SAE quels que soient les réseaux | **Non — aucune source** | — |

## 5. Données effectivement récupérées

**4 fichiers GTFS bruts publics** (dépôt `impactsolutionsas/passbi_core`, commit `7a2b998` du 2026-02-10), copiés bit-à-bit dans **`data/transit/passbi/`** avec empreintes SHA-256 et provenance complète (`MANIFEST.json`) :

| Fichier | Réseaux | routes | stops | trips | stop_times | Calendrier | Intégrité référentielle |
|---|---|---|---|---|---|---|---|
| `gtfs_TER.zip` (107 Ko) | TER | 6 | 26 (= 13 gares × 2) | 572 | 7 332 | 2025-08-18 → 2025-08-31 | 0 orphelin |
| `gtfs_BRT.zip` (508 Ko) | B1, B2 | 2 | 79 | 4 036 | 58 674 | 2024-10-24 → 2024-12-31 | 0 orphelin |
| `gtfs_Dem_Dikk.zip` (2,5 Mo) | DDD | 53 | 1 277 | 9 529 | 314 029 | 2022-01-01 → 2023-12-31 | 0 orphelin |
| `gtfs_AFTU.zip` (10,2 Mo) | AFTU | 73 | 2 401 | 11 077 | 677 918 | 2022-01-01 → 2023-12-31 | 0 orphelin |

Détails vérifiés le 2026-09-27 :

- **TER** : agency = SETER ; `direction_id` 0/1 ; 13 gares nommées (Dakar, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR Rufisque, Rufisque, Bargny, Diamniadio) — **conforme aux 13 gares du référentiel de contrôle** (`data/transit/reference-policy.json`) ; 13 des 26 entrées stop non référencées (doublons plateformes) ; pas de `shapes.txt`.
- **BRT** : routes `B1` et `B2` **distinctes** ; `direction_id` **vide sur tous les trips** ; `calendar.txt` vide, service = exceptions `calendar_dates` 2024-10-24→2024-12-31 ; 36 stops non référencés ; `transfers.txt` vide ; **aucune ligne B3/B4**.
- **DDD** : 53 routes `DDD_01…` ; `direction_id` 0/1 ; **anomalie** : `calendar_dates.txt` en délimiteur `;` (non conforme GTFS).
- **AFTU** : 73 routes `AFTU_1…` (numérotation non contiguë jusqu'à AFTU_84) ; `direction_id` 0/1 ; `shapes.txt` (9 498) et `fare_rules.txt` (1 196 602) présents.
- **Toutes lignes de compte identiques** à l'inventaire PassBi du Lot 4.14E (MANIFEST 4.14E) → les jeux sont bien les mêmes déjà audités, pas une version divergente.
- **Statuts d'exploitation** (champs obligatoires de provenance) : `source = PassBi (impactsolutionsas/passbi_core)`, `source_url` = URL raw exacte par fichier, `source_type = PUBLIC_GTFS`, `date_source = 2026-02-10`, `date_verified = 2026-09-27`, `valid_from/valid_to` par réseau, `confidence` = MEDIUM (structure) / LOW (horaires), `verification_note` détaillée par réseau, y compris la découverte (`discovery_source = PassBi`, `discovery_source_type = PUBLIC_APP`, note de provenance déclarée).

**Aucune donnée temps réel récupérée** (0 timestamp, 0 position, 0 prédiction) — conforme aux Lots 4.15/4.16.

## 6. Données non récupérables

| Donnée voulue | Source cible | Raison (constat 2026-09-27) |
|---|---|---|
| Prochains départs / ETAs live | PassBi API | **Service suspendu** (« This service has been suspended. » sur `/health` et `/v2/*`) |
| GTFS statique « actuel » 2026 | CETUD | Annoncé (open data/apps) mais **aucun lien de téléchargement** ; bouton = JPEG |
| GTFS / horaires par station | SunuBRT | Page horaires derrière formulaire/hCaptcha ; **aucun fichier** |
| GTFS / grille horaire | Dakar Dem Dikk | `horaires/` = 404 ; PDF/images seulement |
| Horaires AFTU | AFTU | Identité + carte uniquement |
| Grille gare×sens 2026 / GTFS-RT | SETER | Fréquences publiques seulement ; app TER INFOS sans API |
| Données structurées | Dakar Transit | Mocks côté client ; page applicative **404** |
| Feed GTFS « Senegal » | busmaps.com | 1 feed expiré 2022 mal étiqueté + téléchargement sous formulaire |
| Géométrie réseau | Géoportail SN | Shapefile 2020/2022 **sans licence** |
| Tout flux GTFS-RT / SAE / delay | Tous réseaux | **N'existe pas publiquement** (constat reconduit) |

## 7. Provenance

Pour chaque fichier intégré, `data/transit/passbi/MANIFEST.json` porte les 9 champs exigés :

| Champ | Valeur (tous fichiers, sauf mention) |
|---|---|
| `source` | PassBi (impactsolutionsas/passbi_core) |
| `source_url` | URL raw GitHub exacte du fichier (par réseau) |
| `source_type` | `PUBLIC_GTFS` (fichier GTFS brut public) — découverte : `PUBLIC_APP` via PassBi |
| `date_source` | 2026-02-10 (commit des fichiers) |
| `date_verified` | 2026-09-27 |
| `valid_from` / `valid_to` | par réseau (tableau §5) |
| `confidence` | MEDIUM structure / LOW horaires (cf. §8) |
| `verification_note` | par réseau : intégrité, directions, anomalies, conformité aux comptes 4.14E + note de provenance déclarée PassBi (« PassBi déclare utiliser des données GTFS publiques centralisées par le CETUD ») |

Distinction conservée : **source du fichier** (dépôt public passbi_core, URL exacte) ≠ **source de découverte** (PassBi site/Play Store/docs) ≠ **provenance déclarée des données** (CETUD + opérateurs, non revérifiable directement faute de fichier CETUD publié).

## 8. Niveau de confiance

| Couche | Confiance | Justification |
|---|---|---|
| Identité réseau (lignes, opérateurs) | **MEDIUM-HIGH** | Intégrité référentielle parfaite (0 orphelin), noms d'agences officielles (SETER, DDD, AFTU), 13 gares TER conformes au référentiel de contrôle |
| Structure (stops, directions, shapes) | **MEDIUM** | Complets et cohérents ; réserves : BRT sans `direction_id`, entrées stop dupliquées (plateformes), stops non référencés |
| Horaires (scheduled departures) | **LOW / EXPIRÉ** | Tous les calendriers sont expirés (2022→2025) ; aucun n'atteint 2026 ; conformité GTFS partielle (`;` dans calendar_dates DDD) |
| Prochains départs / temps réel | **ABSENT (aucun)** | Ni timestamp, ni prédiction ; API PassBi suspendue |
| Statut de la déclaration « GTFS CETUD » | **NON VÉRIFIÉ OFFICIELLEMENT** | PassBi le déclare ; le CETUD ne publie pas le fichier correspondant à comparer |

## 9. Comparaison PassBi / opérateurs / CETUD / autres applications

| Élément | PassBi (GTFS récupéré) | Opérateurs (sites officiels) | CETUD | Autres apps |
|---|---|---|---|---|
| TER | 6 routes / 13 gares, cal. août 2025 | terdakar : fréquences 10/20 min 2026 + 1ers départs | — | TER INFOS (pas d'API) ; Dakar Transit : « 13 gares » |
| BRT | **B1 + B2 seulement**, cal. oct–déc 2024 | sunubrt : B1 (23 stations), B2 (7), **B3 (7)**, B4 « prochainement », 6 min | — | Dakar Transit : « 4 lignes » (marketing) |
| DDD | 53 routes, cal. 2022–2023 | demdikk : listes de lignes + 1er/dernier départ | annonce **38 lignes** + téléchargement = JPEG | Dakar Transit : « 46 lignes » (marketing) |
| AFTU | 73 routes, cal. 2022–2023 | aftu-senegal : 83+ lignes (identité + carte) | annonce **72 lignes** | Dakar Transit : « 64 lignes » (marketing) |
| Temps réel | API **suspendue** ; zéro RT dans les GTFS | aucun flux public ; SAEIV DDD interne | aucun flux publié | revendications « LIVE » non prouvées (mocks) |
| Prochains départs | non exposés actuellement | fréquences affichées (pas des départs) | — | mocks d'interface (PassBi non vérifiable, Dakar Transit = codé en dur) |

## 10. Conflits détectés

1. **AFTU** : 73 routes (PassBi) vs 72 (CETUD) vs 83+ lignes (site AFTU) vs 64 (Dakar Transit) — quatre chiffres incompatibles, aucune correspondance publiée.
2. **DDD** : 53 routes (PassBi) vs 38 (CETUD) vs 46 (Dakar Transit) vs 42 (MobiliseYourCity 2024) — idem.
3. **BRT** : le feed PassBi ne contient ni **B3** ni **B4** alors que sunubrt.sn publie B3 (en service) et B4 (projet) — couverture incomplète du feed « BRT ».
4. **TER** : calendrier PassBi août 2025 (snapshot) vs fréquences officielles 2026 (terdakar 10 min dès 05:45 vs sentersa 05:30, page ≈2022) — conflit déjà établi au Lot 4.15 ; le GTFS PassBi ne résout pas l'écart, il l'antédate.
5. **Directions BRT** : `direction_id` vide dans le feed alors que les directions officielles existent (Papa Gueye Fall ↔ Préfecture Guédiawaye, `reference-policy.json`).
6. **Conformité GTFS** : `calendar_dates.txt` DDD/AFTU en délimiteur point-virgule (spec GTFS = virgule).
7. **Revendications temps réel** : PassBi (« Real-time Tracking », docs API departures), Dakar Transit (« LIVE », « 2 min »), Moovit — **aucune preuve technique accessible** (API suspendue ou mocks).

## 11. Données retenues

1. **`data/transit/passbi/gtfs_TER.zip`, `gtfs_BRT.zip`, `gtfs_Dem_Dikk.zip`, `gtfs_AFTU.zip`** — copies bit-à-bit (SHA-256 vérifiés) des 4 GTFS publics PassBi → usage : **structure de réseau documentée** (routes, stops, directions, trips, shapes) et référence comparée ; **pas** de départs 2026 (calendriers expirés).
2. **`data/transit/passbi/MANIFEST.json`** — provenance complète + règles d'usage + statuts d'expiration.
3. **`data/transit/passbi/README.md`** — règles d'usage obligatoires.
4. **Constats de provenance PassBi** (déclaration CETUD, suspension de l'API, endpoints documentés) — intégrés au présent rapport.

## 12. Données rejetées

| Donnée | Raison du rejet |
|---|---|
| Prochains départs / ETAs PassBi (API) | Service suspendu — **aucune donnée réelle n'est retournée** ; on ne rejette pas une donnée mais son absence (ABSENCE DE DONNÉE) |
| « Temps réel » PassBi / Dakar Transit / Moovit | Revendication marketing ou animation/mock **sans timestamp ni flux vérifiable** → interdit comme REAL_TIME |
| Dakar Transit (118 lignes, 2 720 arrêts, « 2 min ») | Valeurs codées en dur dans une landing, lien app 404 ; **source_secondaire purement déclarative** |
| busmaps.com feed `drk-nam` | Expiré déc. 2022, provider incohérent (City-of-Windhoek), non téléchargeable directement |
| Géoportail shapefile | Géométrie 2020/2022 **sans licence**, sans horaires — OSM couvre déjà ce rôle complémentaire |
| Calendriers PassBi comme « horaires 2026 » | **Expirés** (max 2025-08-31) — les présenter comme courants serait de l'invention |
| Fréquences (6 min B1/B2, 10/20 min TER) comme prochains passages | Interdit : fréquence ≠ prochain passage (phase absente) |
| Conversion d'une donnée PassBi en GTFS-RT ou en ETA live | **Interdite** — aucune preuve temps réel |

## 13. Conséquences sur ETA

| Réseau | Statut ETA après Lot 4.17 | Effet des données récupérées |
|---|---|---|
| **TER** | 🟢 **ETA défendable sous conditions** (terminus Dakar/Diamniadio, sources officielles 4.15 + mécanisme 4.14E) — **inchangé** | Le GTFS PassBi **ne l'étend pas** (calendrier août 2025 expiré) ni **ne l'affaiblit pas** (13 gares conformes au référentiel) |
| **BRT B1** | ⚪ **ETA non défendable** (aucune phase horaire valide) | Structure + historique 2024 récupérés ; **aucun départ 2026 déductible** — interdit de convertir la fréquence 6 min |
| **BRT B2** | ⚪ **ETA non défendable** — idem B1, `route_id` **distincte** conservée (jamais de réemploi de l'ETA B1) |
| **BRT B3** | ⚪ **SOURCE À OBTENIR** (toujours) | B3 **absent** de toutes les sources récupérées — non déductible de B1/B2 |
| **DDD** | ⚪ **SOURCE À OBTENIR** | GTFS 2022–2023 = structure uniquement ; SAEIV interne ≠ source accessible ; pas de grille 2026 |
| **AFTU** | ⚪ **SOURCE À OBTENIR** | GTFS 2022–2023 = structure uniquement ; numérotation divergente non résolue |
| **Tous** | Temps réel : **ABSENCE DE DONNÉE** (0 flux, 0 timestamp, 0 retard, 0 interruption) | Les statuts d'exploitation restent : `REAL_TIME` = aucun ; `ESTIMATED` = uniquement l'ancrage TER officiel ; `UNKNOWN` ailleurs |

Affichages interdits rappelés et non produits : aucun « 0 min », aucun « Passage non communiqué », aucun « Horaire indisponible » ajouté, aucun « 0–20 min », aucune fréquence affichée comme prochain passage.

## 14. Conséquences sur le routage

- **Aucun code de routage modifié** (le moteur d'itinéraires actuel n'est pas touché par ce lot ; aucune UI, carte, polyligne ou navigation modifiée).
- **Apport documentaire pour les contrôles de correspondance TER ↔ bus** (à échéance, dans la couche données) :
  - **Géométrie** : coordonnées stops DDD/AFTU/BRT PassBi → contrôle de cohérence géographique des paires d'arrêts (uniquement avec provenance et confiance MEDIUM) ;
  - **Sens** : `direction_id` 0/1 exploitable pour TER/DDD/AFTU ; **BRT inexploitable ici** (`direction_id` vide) ;
  - **Identités** : crosswalk futur possible route↔route PassBi vs réseau canonical, avec réserves des conflits §10 ;
  - **Horaires de correspondance** : **non démontrables** avec ces jeux (calendriers expirés) — seule l'ancrage TER par terminus (4.14E) fournit des temps aujourd'hui ;
  - **Temps de marche** : calculables à partir des coordonnées, mais **jamais une correspondance créée uniquement par proximité** (règle du lot conservée : géo cohérente + identités documentées + sens compatible + marche plausible + horaires réels le cas échéant).
- OSM reste complémentaire (géométrie, couverture) et **n'est jamais source d'horaire ni d'exploitation**.

## 15. Recommandations d'intégration

**Effectuées dans ce lot** (intégration dans la couche transit, jamais dans `main.dart`, zéro changement Dart) :

1. `data/transit/passbi/` = 4 GTFS publics bruts + `MANIFEST.json` (provenance 9 champs) + `README.md` (règles d'usage) — empreintes SHA-256 vérifiées, fichiers bit-à-bit identiques à la source.
2. Architecture respectée : **Data (→ `data/transit/`) → (DataService → moteur ETA/routage : inchangés) → Flutter UI (inchangée)**. Aucun mock transformé, aucune donnée fictive créée pour combler un trou.
3. `data/gtfs/` legacy **non modifié** ; `reference-policy.json` **non modifié** ; aucun horaire/trip/stop_time ajouté ; aucun GTFS-RT créé.

**Recommandations pour la suite (non réalisées ici, hors périmètre de ce lot) :**

- Utiliser ces jeux comme **référentiel de structure** pour un futur crosswalk PassBi ↔ réseau canonical (sous réserve des conflits §10 et d'une clarification de licence — dépôt passbi_core sans LICENSE) ;
- Ne brancher ces fichiers dans le calcul ETA **qu'après** obtention d'un calendrier 2026 actif (cf. demandes du Lot 4.16) ou d'un flux temps réel vérifiable ;
- Réexaminer périodiquement PassBi : réactivation possible de l'API (alors tester `timestamp`/`predicted_time` avant tout statut REAL_TIME) ;
- Conserver strictement la séparation `SCHEDULED / REAL_TIME / ESTIMATED / UNKNOWN / PARTIALLY_CONFIRMED` : ces données sont `SCHEDULED` **expiré**, jamais `REAL_TIME`.

---

## Validation du lot

Exécutée après création des livrables (détail des résultats dans le retour de travail) :

- `npm test` — suite Node du dépôt ;
- `node scripts/check-arrets.js` — état historique du checkout 4.15 conservé, non corrigé artificiellement ;
- `flutter analyze` / `flutter test` / `flutter build web` — SDK Flutter indisponible dans l'environnement d'audit (aucun exécutable `flutter`/`dart`, pas de réseau vers `storage.googleapis.com`) ; **`flutter-src/` est intact** (0 ligne modifiée), donc ces trois contrôles ne peuvent pas régresser par rapport à l'état validé du dépôt ;
- `git diff --check` — blancs/espace ;
- Contrôles de protection : aucun mock présenté comme réel, aucune donnée inventée, aucune modification GPS/cartographie/UI, `data/gtfs/` legacy intact, provenance présente pour les nouvelles données.
