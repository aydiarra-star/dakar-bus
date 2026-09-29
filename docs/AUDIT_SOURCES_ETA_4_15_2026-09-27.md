# Lot 4.15 — Audit des sources temporelles réelles pour l'ETA (27/09/2026)

**Objet** : déterminer, preuves à l'appui et **sans rien inventer**, s'il existe, réseau par
réseau (TER, BRT B1, B2, B3, DDD, AFTU), une vraie source de **prochain départ** —
horaire théorique exploitable ou temps réel — permettant un ETA défendable.

**Périmètre** : lecture seule. Aucun fichier produit modifié : `flutter-src/lib/*`,
`data/transit/`, `data/gtfs/`, `dakar_network.json`, GPS, cartographie, polylines sont
intacts. Aucun horaire, trip, stop_time, calendar ou fréquence créé. Aucun commit, aucune
fusion. Ce document est le seul ajout.

**État des révisions** :
- Branche de session `arena/01a0e370-dakar-bus`, HEAD `9f4f916` (merge PR #30, main),
  arbre propre avant/après ce rapport. À ce SHA, `data/transit/` ne contient que
  `reference-policy.json`.
- Le Lot 4.14E est poussé sur `arena/01a0df09-dakar-bus` au SHA **`0053a5e`** (PR #31
  ouverte, non mergée). Sa couche complète `data/transit/{passbi,validated,production,engine}`
  et son mécanisme ETA Flutter (`eta_calculator.dart`, `schedule_service.dart`,
  providers) ont été inspectés **en lecture seule** via `git show`/`git archive` — ces
  données **existent et sont auditables au SHA 4.14E, mais sont absentes de
  l'arbre de la branche de session**. Les deux faits sont indiqués ci-dessous.

---

## 1. Cadre sémantique opposable (à respecter dans toute la suite)

### 1.1 FRÉQUENCE ≠ HORAIRE THÉORIQUE ≠ PROCHAIN DÉPART ≠ PRÉDICTION ≠ TEMPS RÉEL

| Notion | Définition exacte | Exemple réel dans ce dépôt | Ce que ce N'EST PAS |
|---|---|---|---|
| **FRÉQUENCE** | Cadence publiée (« toutes les 10 min »). Elle donne un intervalle, **jamais une phase** : on ne sait pas à quel instant le dernier passage a eu lieu. | terdakar.sn : 10 min L–S, 20 min le soir ; sunubrt : 6 min ; `FrequencyProvider` (vérifié 2026-09-26) porte ces fenêtres en `ESTIMATED`. | Ce n'est pas un horaire : « fréquence 6 min → prochain bus dans 6 min » est un raisonnement **interdit**. |
| **HORAIRE THÉORIQUE** | Grille datée `route→trip→service→stop→time` (GTFS statique) avec jours de validité. Permet « prochain départ » par lecture à t0, **sans** connaissance du retard. | `data/transit/validated/gtfs` au SHA 4.14E : 48 trips / 624 stop_times **pour la seule date 2026-09-27** (dimanche), dont 48 `PARTIALLY_CONFIRMED` (départs Dakar) et 576 intermédiaires `UNCONFIRMED`. | Ce n'est pas du temps réel : il ne connaît ni retard ni position véhicule. |
| **PROCHAIN DÉPART** | Instant calculé **t0 + décalage validé** : soit lecture sur grille datée, soit *premier départ publié + fréquence* à un point **ancré** (terminus). Exemple validé 4.14E : Dakar lundi, dernier départ 13:29 → affichage 13:35 (6 min), statut `ESTIMATED`/`COMBINED`, sans `trip_id` reconstruit. | Mécanisme `anchoredTerminalEta` (SHA 4.14E) : terminus Dakar (L–S + dim/férié) et terminus Diamniadio (L–S) uniquement. | Ce n'est ni une prédiction de retard, ni un temps réel. |
| **PRÉDICTION** | Écart théorique↔observé appliqué à un trip précis : nécessite une observation fraîche (véhicule ou événement) **et** une grille de référence. | **Aucune prédiction n'existe dans le dépôt ni dans une source externe identifiée.** | Une fenêtre « 0–6 min » issue d'une seule fréquence n'est **pas** une prédiction. |
| **TEMPS RÉEL** | Flux horodaté et frais (`GTFS-RT VehiclePosition/TripUpdate/Alert`, SAE…) avec `timestamp`, `trip_id`, `stop_id`, `direction_id`, fraîcheur contrôlée. | **Aucun.** Recherche effectuée (§4) : rien. Seuls des **mocks** existent (`api/gtfs-rt` : `timestamp:0`, `entity:[]`, `source:"static-mock-file"` ; `server/server.js` : générateur `USE_MOCK=true`, 127 véhicules simulés ; `index.html` : tableaux `next` codés en dur, badge « GTFS-RT LIVE », `generateMockGTFS(){source:'simulated'}`). | Un mock, un badge « LIVE », une fréquence, une page d'horaire ou une application tierce **ne sont pas** du temps réel. |

### 1.2 ABSENCE DE DONNÉE ≠ RETARD ≠ INTERRUPTION

| État | Condition d'usage | Cas dans cet audit |
|---|---|---|
| 🟢 **Prochain départ défendable (X min)** | Une source réelle donne t0 + décalage validé (grille datée ou premier départ ancré + fréquence). | **TER, terminus seulement** (Dakar L–S + dim/férié ; Diamniadio L–S). |
| 🟡 **Retard établi (X min)** | Un écart mesuré théorique↔réel existe, horodaté et sourcé. | **Aucun réseau** — aucune source de retard n'existe. |
| 🔴 **Interruption documentée (Indisponible)** | Une interruption **documentée** (annonce opérateur, alerte datée) est établie. | **Aucun réseau** — aucune interruption documentée n'a été trouvée. |
| ⚪ **Aucune source (non applicable)** | Aucune des trois conditions ci-dessus : c'est l'**absence de donnée**. | B1, B2, B3, DDD, AFTU ; gares TER intermédiaires. |

⚠️ Règle dérivée : on n'affiche **jamais** 🟡 sans mesure et **jamais** 🔴 (« Indisponible »)
sans interruption documentée. Le silence d'une source n'est ni un retard ni une
interruption. Inversement, une page qui affiche des horaires ou une fréquence
**ne doit pas être étiquetée « temps réel »**.

---

## 2. Inventaire des datasets du dépôt

### 2.1 Présents sur la branche de session (HEAD `9f4f916`)

| Dataset | Routes | Trips | stop_times | Stops | Validité / dates | Source & statut | Historique ou actuel ? | Synthétique ou réel ? | Connecté à Flutter ? |
|---|---|---|---|---|---|---|---|---|---|
| `data/gtfs/` (GTFS PWA) | **76** (AFTU 68, DDD 4, TATA 2, TER 1, BRT 1) | **145** (AFTU 135, DDD 5, BRT 2, TER 2, TATA 1) | **108** lignes couvrant 6 `trip_id`, dont **36 orphelines** (`BRT_01_003`, `TER_01_003` absents de `trips.txt`) ; **141 trips sans aucun stop_time** (AFTU 135, DDD 5, TATA 1) | **42** (BRT 23, TER 13, 6 pôles) | `calendar` 5 services 20260101–20261231 ; `feed_info` version `2.1-dakar-pwa-gtfs-rt`, éditeur « CETUD Dakar Mobilité » | Jeu **démo PWA** ; historique git squashé (1 commit merge 2026-09-26), aucune provenance traçable | Calendrier « actuel » (2026) mais contenu **non sourcé opérateur** | **Synthétique** (heures rondes 06:00/06:02…, pas de temps d'arrêt réels) | **NON** — `pubspec.yaml` ne livre que `dakar_network.json`. Utilisé par la PWA (service-worker, `index.html`, `check-arrets`) uniquement. Au SHA 4.14E ces 36 orphelines ont été retirées (72 lignes / 4 trips) et `check-arrets` passe. |
| `flutter-src/assets/data/dakar_network.json` | **105** (ter 1, brt 2, ddd 15, aftu 80, tata 7) | — | — | **117** | Audité 2026-09-24 ; `schedule_status: UNKNOWN` sur les 105 routes ; aucun champ fréquence/horaire | Audit interne + provenance (`OFFICIAL`/`FIELD_OBSERVATION`) ; `services_not_exposed` : `brt_b3`, `brt_b4`, `ter_diamniadio_aibd` | Actuel (identité) ; **aucune donnée temporelle** | Réel pour l'identité/tracé (non temporel) | **OUI — seul asset Flutter** |
| `data/transit/reference-policy.json` | — | — | — | — | `reviewedAt` 2026-09-21 | Politique de référentiel | Actuel | — | NON |
| `api/gtfs-rt` (fichier) | — | — | — | — | `timestamp: 0` | Placeholder **statique** : `entity:[]`, note « static-mock-file… Replace with CETUD endpoint » | Non applicable | **Synthétique/mock** | NON (PWA seulement) |
| `server/server.js` + `server/.env` | — | — | — | — | `USE_MOCK=true` | Proxy GTFS-RT avec **générateur mock** (127 véhicules « réalistes ») ; endpoints `api.cetud.sn`, `api.ter.sn`, `api.sunubrt.sn`, `api.dakardemdikk.sn` **tous NXDOMAIN** (getent, 27/09/2026) ; fallback Suisse non pertinent ; `.env` committé (problème d'hygiène déjà signalé) | Mock actuel | **Synthétique** | NON (route `/api` Vercel → PWA) |
| `index.html` (PWA) | 42 arrêts | — | — | — | — | Valeurs `next` **codées en dur** : 23× `["2 min","7 min"]` (BRT), 13× `["4 min","14 min"]` (TER), 6× `["5 min","12 min"]` (pôles) ; badges « GTFS-RT LIVE », « 127 véhicules actifs », « LIVE » sur *Prochains passages* | — | **Fabriqué/simulé** — à signaler : n'est **aucune** source et n'est pas connecté à Flutter | NON |

### 2.2 Présents uniquement au SHA 4.14E (`0053a5e`, PR #31 — absents de la branche de session)

| Dataset | Contenu (comptages vérifiés) | Validité | Statut (registres) | Historique/actuel, synthétique/réel | Connecté à Flutter ? |
|---|---|---|---|---|---|
| `data/transit/passbi/ter/` | 6 routes, 26 stops, 572 trips, 7 332 stop_times (trips/stop_times hors git, blobs rétéléchargeables) | **20250818–20250831** | Niveau 1 brut, jamais exposé | **Historique** (PassBi/SETER, août 2025) ; `PassBi 12 min` jugé `CONTRADICTED` face à l'opérateur 10 min ; **licence absente → republication BLOQUÉÉE** | NON |
| `data/transit/passbi/brt/` | 2 routes, 79 stops, 4 036 trips, 58 674 stop_times, 69 calendar_dates | **20241024–20241231** | Niveau 1 brut | **Historique** (fin 2024) ; licence absente | NON |
| `data/transit/passbi/ddd/` | 53 routes, 1 277 stops, 9 529 trips, 314 029 stop_times | **20220101–20231231** | Niveau 1 brut ; 53→34 persistantes, 19 `NOT_FOUND` | **Strictement historique (2022–2023)** — jamais traitable comme horaires 2026 ; licence absente | NON |
| `data/transit/passbi/aftu/` | 73 routes, 2 401 stops, 11 077 trips, 677 918 stop_times, 1 196 602 fare_rules | **20220101–20231231** | Niveau 1 brut ; 73 lignes PassBi `UNCONFIRMED`, numérotation PassBi ≠ 72 lignes CETUD | **Strictement historique** ; licence absente | NON |
| `data/transit/validated/gtfs/` | 1 agency (SETER), 1 route TER, 13 stops, **48 trips, 624 stop_times**, calendar = **1 seule date 20260927** (`TER_SUNDAY_AUDIT`) | 2026-09-27 seul | 48 stop_times `PARTIALLY_CONFIRMED` (départs dimanche Dakar), **576 `UNCONFIRMED`** (gares intermédiaires) | Grille **théorique partielle et non courante** ; réelle mais non généralisable ; `realtime_status: NO_REAL_TIME_FEED` | NON (engine JS consommé par les tests node uniquement) |
| `data/transit/validated/schedule_registry.json` | 4 entrées fréquence : TER L–S 10 min (soir 20 min, 05:45/05:35→20:55, 21:05→22:05), TER dimanche 20 min (06:25→22:05), B1 6 min, B2 6 min | `date_source` 2026-03-30 (TER), `date_verified` 2026-09-27 | Toutes `ESTIMATED` ; statuts horaires : `SCHEDULED 0, ESTIMATED 4, PARTIALLY_CONFIRMED 48, UNCONFIRMED 576` ; **`realtime_entries: 0`, `NO_REAL_TIME_FEED`** ; note : « Une fréquence ne génère JAMAIS d'heures artificielles » | Fréquences actuelles sourcées opérateur ; aucune temps réel | NON |
| `data/transit/validated/route_status.json` | 130 routes × 4 dimensions | 2026-09-27 | `realtime: UNKNOWN` sur **130/130** ; schedule : 1 `PARTIALLY_CONFIRMED`, 2 `UNCONFIRMED`, 127 `UNKNOWN` | — | NON |
| `data/transit/validated/public_routes.json` | 115 routes publiées (TER 1, BRT 3, DDD 39, AFTU 72) | 2026-09-27 | schedule `ESTIMATED` 3 / `UNKNOWN` 112 ; **realtime `UNKNOWN` 115/115** | — | NON |
| `data/transit/production/production_ready.json` | 4 prêts / 7 non prêts | 2026-09-27 | « Temps réel, tous réseaux : **UNKNOWN** — *Aucun flux GTFS-RT ou SAE actif identifié* » | — | NON |
| `data/transit/engine/` (JS) | `schedule_engine.js`, `gtfs_time.js`, `integration.js`, `clock.js` | — | Lecture seule sur le registre, **tests node uniquement** | — | NON |
| Flutter 4.14E : `eta_calculator.dart`, `schedule_service.dart`, `realtime_provider.dart`, `schedule_provider.dart`, `departure_presentation.dart` | Hiérarchie `REAL_TIME > SCHEDULED > ESTIMATED > null` ; `anchoredTerminalEta` conditionné (route TER, `stop_dakar_ter`/`stop_diamniadio`, `directionId: null`, `dateVerified ≤ now`, même `ServiceDate`) | 2026-09-27 | Providers de production **vides** (`EmptyScheduleProvider`, `EmptyRealtimeProvider`) ; `FrequencyProvider` = fréquences officielles vérifiées 2026-09-26, ne produit jamais `REAL_TIME` | Mécanisme **référentiel à conserver tel quel** (Lot 4.14E validé) | OUI sur la PR #31 (absents du HEAD de session) |

**Signalement obligatoire (dataset présent mais non connecté à Flutter)** : tout le bloc
`data/transit/*` du SHA 4.14E, `data/gtfs/`, `api/gtfs-rt`, `server/*` (mocks) et les
tableaux `next` d'`index.html` **ne sont lus par aucun code Flutter**. Rien de tout cela
ne peut être présenté comme une source de l'application avant branchement explicite.

---

## 3. Sources web consultées (toutes consultées le 27/09/2026)

| # | URL | Organisme | Type | Réseau | Date de publication/mise à jour | Précision temporelle fournie | Fraîcheur | Utilisable pour un ETA ? |
|---|---|---|---|---|---|---|---|---|
| E1 | `terdakar.sn/les_horaires_des_trains/` | SETER (TER) | Opérateur | TER | Pas de date affichée ; actualité site au 30/03/2026 | **Fréquences** : 10 min L–S (05:35 départ Diamniadio / 05:45 départ Dakar → 20:55), 20 min 21:05→22:05 ; dim/fériés 20 min 06:25→22:05 + **premiers/derniers départs** | Page vivante, constantes depuis au moins mars 2026 | **OUI, sous conditions** : ancrage de prochain départ **aux terminus uniquement** (premier départ + fréquence). **NON** pour les gares intermédiaires, **NON** comme temps réel. |
| E2 | `sentersa.sn/plan-de-transport/` | SENTER | Opérateur | TER | Image datocms **20/01/2022** ; liste de gares antérieure à la phase 2 | Fréquences **divergentes** : 10 min 05:30→21h, dimanche 06:30 | **Périmée et contradictoire** (E1) | NON retenue |
| E3 | App **TER INFOS** (`play.google.com/store/apps/details?id=sn.seter.terdakar`, App Store `id6698889387`) ; lancement presse 29/07/2025 (osiris.sn, senego.com) | SETER | Opérateur | TER | Versions app 2025 ; buzz X 16/07/2026 | Revendique « horaires en temps réel », notifications trafic, « l'horaire du prochain train à proximité » | App maintained | **NON intégrable en l'état** : aucune API publique ni documentation identifiée. **Source candidate à solliciter** auprès de SETER. |
| E4 | `sunubrt.sn/brt-1-omnibus/` + `sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/` | Dakar Mobilité SA (SunuBRT) | Opérateur | B1 | Pages sans date de mise à jour | **Fréquence 6 min** (service 06:00–21:00, renforts pointe Petersen↔Grand Médine) ; afficheur **en station des 2 prochains BRT** ; promesse site/app « diffus**eront** l'information voyageur en temps réel » (futur) | Constant | **NON** : fréquence sans phase. L'afficheur station n'est **pas** un flux machine accessible. |
| E5 | `sunubrt.sn/brt-2-semi-express/` | SunuBRT | Opérateur | B2 | Idem | **Fréquence 6 min** L–S ; **7 stations** | Constant | NON (mêmes limites que B1) |
| E6 | `sunubrt.sn/brt-3-semi-express/` | SunuBRT | Opérateur | B3 | Service ouvert octobre 2025 (identité vérifiée 2026-09-24) | Fenêtres de pointe **L–V 07–11 et 16–20** ; **7 stations nommées** ; aucune fréquence ni grille | Actuel | **NON** : ni fréquence, ni grille, ni temps réel → aucune donnée temporelle exploitable. |
| E7 | App SunuBRT (Google Play `prod.maasify.dakar`, App Store `id6476969132`) | Dakar Mobilité SA | Opérateur | B1/B2/B3 | 2024–2025 | Revendique « prochains passages » de proximité, billettique, itinéraires | App maintained | **NON** : aucune API publique documentée. |
| E8 | `demdikk.sn/info-voyageurs/` | Dakar Dem Dikk | Opérateur | DDD | Page consultée 27/09/2026 | **Liste de lignes** (urbaines, banlieue, dessertes TER) + départs **1er/21h00** pour les seules lignes « TAF TAF » ; amplitude 06h–21h (CETUD) | Actuel pour l'identité | **NON** : aucune grille `route→trip→service→stop→time`, aucune fréquence. ⚠️ Le pied de page affiche des liens SEO/pillés (compromission probable du site) → fiabilité à confirmer côté opérateur. |
| E9 | `demdikk.sn/reseau-interurbain/` | Dakar Dem Dikk | Opérateur | DDD (interurbain) | Consultée 27/09/2026 | Heures de départ **fixes** interurbaines | Actuel | NON pour l'urbain ; hors périmètre urbain ETA. |
| E10 | `aftu-senegal.org/infos-pratiques/` | AFTU | Opérateur | AFTU | `source_date` 2026-07-14 (registre crosswalk) | **Liste de lignes + itinéraires** (« Voir itinéraire ») — **zéro donnée temporelle** | Actuel pour l'identité | NON |
| E11 | `cetud.sn/observatoire/systeme-de-donnees/` + `cetud.sn/reseaux-de-transport/ddd/` | CETUD | Institutionnelle | Tous | Pages 28–30/05/2025 | Mentionne la **création de fichiers GTFS** par CETUD « dans un objectif d'opendata » ; le bouton « Télécharger les lignes et horaires » de la page DDD pointe une **image JPEG** (`plan-lignes-ddd.jpeg`), pas un GTFS ; **aucun lien de téléchargement GTFS/GTFS-RT public trouvé** | Actuel | NON en l'état ; **point de contact prioritaire** pour obtenir les GTFS annoncés. |
| E12 | Centre de contrôle DDD / SAEIV (ndarinfo.com 06/07/2026 ; aps.sn 06/07/2026 ; dakaractu 31/03/2026) | Dakar Dem Dikk + ministère | Opérateur (presse) | DDD | 06/07/2026 | **Géolocalisation des bus en temps réel, assistance au respect des horaires** — système **interne** (SAEIV, CCO, billettique) | Récent | **NON publiquement exploitable** : aucune API/flux public identifié. Preuve qu'une source temps réel **existe en interne** → à solliciter. |
| E13 | `mobilitydatabase.org` + `transport.data.gouv.fr` (recherches 27/09/2026) | MobilityData / gouvernements | Tiers de référence | — | — | **Aucun flux Sénégal/Dakar référencé** (résultats : ONCF Maroc, DAKK États-Unis, feeds français) | — | Aucune source publique disponible |
| E14 | `moovitapp.com`, `dakartransitsenegal.online`, `bus-senegal.sn` | Tiers privés | Tierce | Tous | 2025–2026 | Revendiquent « temps réel » / horaires | Non vérifiable | **NON retenus** : pas de source-level API, méthodologie inconnue, non opposables à un opérateur. |
| E15 | DNS `api.ter.sn`, `api.cetud.sn`, `api.sunubrt.sn`, `api.dakardemdikk.sn` | — | — | Tous | Vérifié 27/09/2026 (`getent`) | **INEXISTANT (NXDOMAIN)** pour les 4 ; domaines opérateurs (`terdakar.sn`, `sunubrt.sn`, `demdikk.sn`, `aftu-senegal.org`, `cetud.sn`, `sentersa.sn`) résolvent | — | Les endpoints `server/.env` pointent vers **des hôtes qui n'existent pas** |

---

## 4. Recherche de sources de temps réel (GTFS-RT / SAE)

**Champs recherchés dans tout le dépôt** (js, json, dart, html, md — hors
`node_modules`) : `GTFS-RT`, `VehiclePosition`, `TripUpdate`, `StopTimeUpdate`,
`StopTimeEvent`, `schedule_relationship`, `delay`, `timestamp`, `gtfs-rt`, `Alert`,
`trip_id`, `route_id`, `stop_id`, `stop_sequence`, `direction_id`, `service_date`,
fichiers `.pb`/`.pbuf`/`.proto`.

**Résultat : aucun flux temps réel réel n'existe, ni dans le dépôt, ni en externe.**

1. **Dans le dépôt** — seuls des **mocks** : `api/gtfs-rt` = placeholder statique
   (`timestamp:0`, `entity:[]`) ; `server/server.js` = générateur mock (`USE_MOCK=true`
   aussi bien dans `.env` que dans `vercel.json`, 127 véhicules simulés, mock servi par
   défaut « pas de clé = mock ») ; `service-worker.js` précache `/api/gtfs-rt|vehicles|alerts`
   ; `index.html` = valeurs `next` codées en dur, badges « GTFS-RT LIVE » / « 127 véhicules
   actifs » / « LIVE », `generateMockGTFS()` → `source:'simulated'`. Aucun fichier
   protobuf, aucune entité `VehiclePosition/TripUpdate` réelle.
2. **Côté code Flutter** — `DataStatus.live` **n'est jamais assigné** dans `lib/` (contrat
   documenté en dur dans `main.dart`) ; à 4.14E les providers de production sont vides
   (`EmptyRealtimeProvider`) ; `schedule_registry` : `realtime_entries: 0`,
   `NO_REAL_TIME_FEED` ; `route_status` : `realtime UNKNOWN` ×130 ; `production_ready` :
   « Aucun flux GTFS-RT ou SAE actif identifié » ; règle README 4.14E :
   `REAL_TIME = NON` sur toute la couche. Le GPS utilisateur n'est **jamais** la position
   d'un véhicule (garde-fous 4.14D/4.14E).
3. **Endpoints** — les 4 hôtes `api.*.sn` du `.env` sont **NXDOMAIN** (§3-E15). Même en
   passant `USE_MOCK=false`, aucun fetch réel n'est possible aujourd'hui.
4. **Opérateurs** — TER INFOS (E3), app SunuBRT (E7) et SAEIV DDD (E12) **revendiquent**
   du temps réel dans leurs interfaces fermées ; **aucune API publique/documentée** n'a été
   trouvée. Les apps tierces (E14) ne sont pas des sources opposables.
5. **Registres** — aucun GTFS-RT, aucun SAE, aucune alerte datée : partout `UNKNOWN`.

**Sources de retard / d'interruption recherchées** : aucune source de retard (aucun
écart mesuré horodaté) ; aucune interruption documentée (la bannière « INFO TRAFIC » de
terdakar.sn affiche « Trafic normal », ce n'est **ni** un flux **ni** un retard mesuré).
→ **Aucun réseau ne peut porter 🟡 ni 🔴 (§1.2).**

---

## 5. Tableau principal — Réseau × Source

| Réseau | Source | Actuelle ? | Station | Direction | Donnée temporelle | Temps réel ? | ETA défendable ? | Blocage | Action suivante |
|---|---|---|---|---|---|---|---|---|---|
| TER | E1 `terdakar.sn/les_horaires_des_trains` (SETER) | **Oui** (consultée 27/09/2026) | 13 gares publiées ; ancrage aux **2 terminus** | Départ de Dakar / Départ de Diamniadio | Fréquences 10/20 min + **premiers/derniers départs** (05:45/05:35→20:55 ; 21:05→22:05 ; dim. 06:25→22:05) | Non | **Oui, sous conditions** (terminus, `ESTIMATED`) | Pas de grille par gare×sens ; pas de GTFS-RT ; mécanisme ancré = SHA 4.14E (PR #31 non mergée) ; gares intermédiaires sans temps de parcours validé | Solliciter SETER : grille datée gare×sens **ou** GTFS(-RT) ; **ne pas** étendre l'ancrage aux gares intermédiaires |
| TER | E2 `sentersa.sn` | **Non** (image 20/01/2022) | 13 gares (liste pré-phase-2) | — | Fréquences divergentes (05:30) | Non | Non | Source périmée + contradictoire | Écarter ; E1 fait référence |
| TER | E3 app TER INFOS | Oui (app) | — | — | Revendique horaires/trafic **temps réel** + prochain train à proximité | Revendiqué, **invérifiable** (aucune API) | Non (non intégrable) | App fermée, aucune API/documentation | Solliciter SETER : accès API/GTFS-RT documenté |
| TER | Registre 4.14E `validated/gtfs` (48 départs dim.) | Partiellement (date unique `20260927`) | **Dakar seulement** | Départ Dakar | Horaire théorique partiel : 48 `PARTIALLY_CONFIRMED`, 576 intermédiaires `UNCONFIRMED` | Non | Non (hors date, hors intermédiaires) | Calendrier à une seule date ; statut `SCHEDULED` interdit | Compléter l'audit horaire avant toute promotion `SCHEDULED` |
| BRT B1 | E4 `sunubrt.sn/brt-1-omnibus` | **Oui** (vérifié 26–27/09/2026) | 23 stations (structure ; PassBi 21 vs 23) | Petersen ↔ Guédiawaye | Fréquence **6 min** (06:00–21:00, renforts pointe ; 10→7 min dim.) | Non | **Non** | « 6 min » ≠ prochain bus : **phase inconnue**, aucun premier passage horodaté station×sens, aucun trip daté | Demander à SunuBRT/CETUD une grille `station×sens×jour` ou un GTFS-RT |
| BRT B2 | E5 `sunubrt.sn/brt-2-semi-express` | **Oui** (idem) | **7 stations** (physiquement partagées avec B1, `route_id` distinct obligatoire) | Petersen ↔ Guédiawaye | Fréquence **6 min** L–S | Non | **Non** | Idem B1 ; jamais réutiliser l'ETA B1 pour B2 | Idem B1, en conservant l'association B2 distincte |
| BRT B3 | E6 `sunubrt.sn/brt-3-semi-express` | Identité **Oui** (24/09/2026) ; temporel **aucune source** | **7 stations officielles** (mappées `candidate_stop_ids`, `in_passbi:false`, `excluded_from_gtfs:true`) | Semi-express (sens unique documenté) | Fenêtres de service L–V 07–11/16–20 **seulement** — ni fréquence, ni grille | Non | **Non** | **Aucune donnée temporelle démontrée** ; route **non exposée** dans l'app (`services_not_exposed`, correspondance « Gueule Tapée »↔`stop_brt_22_gadaye` non confirmée) | Obtenir grille/fréquence officielle B3 ; exposition produit = lot séparé autorisé ; **jamais** emprunter la cadence B1/B2 |
| DDD | E8/E9/E11 `demdikk.sn` + `cetud.sn` | Identité **Oui** (27/09/2026) | Liste de lignes (terminus déclarés), **pas de stations horaires** | Terminus↔terminus déclarés | Aucune (seuls 1er/dernier départ « TAF TAF » + amplitude 06h–21h) | Non | **Non** — source à obtenir | Aucun lien `route→trip→service→stop→time` **courant** ; PassBi 2022–2023 = historique sous licence bloquée ; GTFS « opendata » annoncé par CETUD **sans lien** ; SAEIV interne (E12) **sans API publique** ; `api.dakardemdikk.sn` NXDOMAIN | Demander à DDD/CETUD : **GTFS statique actuel** ou **flux SAEIV/GTFS-RT**, avec licence de redistribution |
| AFTU | E10 `aftu-senegal.org/infos-pratiques` | Identité **Oui** (`source_date` 14/07/2026) | 72 lignes (liste + itinéraires), **aucune heure** | Terminus déclarés | **Aucune** | Non | **Non** — source à obtenir | Aucun horaire ni fréquence publié ; PassBi 2022–2023 `UNCONFIRMED` (numérotation différente des 72 lignes CETUD) ; tiers (Moovit E14) non opposables | Demander à AFTU/CETUD : GTFS ou fréquences officielles ; **jamais** reconstruire depuis n° de ligne, destination, géométrie, OSM ou fréquence |

---

## 6. Sections par réseau

### 6.1 TER (Dakar ↔ Diamniadio)

**Ce qui existe.** Source opérateur E1 (consultée 27/09/2026) : fréquences **10 min L–S**
de **05:45** (départ Dakar) / **05:35** (départ Diamniadio) à **20:55**, puis **20 min**
de 21:05 à 22:05 ; **dimanches/fériés 20 min de 06:25 à 22:05** ; premiers/derniers
départs affichés. Source contradictoire E2 écartée (image 2022). Registre 4.14E :
`validated/gtfs` = 48 trips/624 stop_times **uniquement au 2026-09-27**, 48 départs
Dakar `PARTIALLY_CONFIRMED`, 576 intermédiaires `UNCONFIRMED` ; fréquences promues en
`ESTIMATED` avec la règle « une fréquence ne génère jamais d'heures artificielles ».

**Ce qui manque.** Aucune grille horaire datée par gare × sens × jour pour les **11 gares
intermédiaires** ni pour Diamniadio le dimanche ; aucun temps de parcours validé
inter-gares ; aucun flux GTFS-RT (`api.ter.sn` NXDOMAIN ; l'app TER INFOS E3 n'expose
aucune API ; bannière « INFO TRAFIC » = statut manuel, pas un retard mesuré).

**Mécanisme de référence (Lot 4.14E, SHA `0053a5e`, PR #31 non mergée).**
`anchoredTerminalEta` calcule le prochain départ **uniquement** sur les terminus
`stop_dakar_ter` (lun–sam + dim/férié) et `stop_diamniadio` (lun–sam seulement), sous
garde-fous stricts (route TER, `directionId: null`, `dateVerified ≤ now`, même
`ServiceDate`), statut `ESTIMATED`/`COMBINED`, sans `trip_id` reconstruit. Exemple
validé : lundi 13:29 → « 13:35 » (6 min). Les gares intermédiaires retournent
« Passage non communiqué ». Ce mécanisme est **conservé comme référence** : il n'est ni
étendu, ni modifié par le présent audit. À noter : ce mécanisme **n'existe pas** sur le
HEAD de la branche de session (fichiers `eta_calculator.dart`/`schedule_service.dart`
absents de `main`).

**Conclusion du TER : ETA DÉFENDABLE SOUS CONDITIONS**
*Conditions : terminus uniquement (Dakar L–S + dim/férié ; Diamniadio L–S) ; statut
`ESTIMATED` (jamais `SCHEDULED`, jamais `REAL_TIME`) ; source E1 actuelle ; jamais
d'extension aux gares intermédiaires sans temps de parcours validé ; jamais de
catégorisation « temps réel ».*

### 6.2 BRT B1 (Petersen ↔ Guédiawaye, omnibus)

**Ce qui existe.** E4 (opérateur, vérifié 26–27/09/2026) : fréquence **6 min**,
service 06:00–21:00, renforts de pointe Petersen↔Grand Médine ; dimanche 10 min puis
7 min (fenêtres `FrequencyProvider`, `ESTIMATED`). Structure : **23 stations**
(`brt_route_structure` : 21 PassBi vs 23 actuelles ; 21 déviations coordonnées 1–519 m
signalées). Afficheur **physique** en station (« 2 prochains BRT ») — non accessible en
machine. `data/gtfs` ne porte que 2 trips BRT **synthétiques non validés**.

**Ce qui manque.** Tout ce qui ferait un prochain départ : aucun premier passage
horodaté par station × sens, aucun trip daté, aucun calendrier, aucun flux temps réel
(`api.sunubrt.sn` NXDOMAIN, app E7 sans API). La promesse site/app de temps réel est au
**futur** (« diffuseront »).

**Interdits rappelés** : « fréquence 6 min → prochain bus dans 6 min » est un
raisononnement interdit (phase inconnue) ; les trips synthétiques `data/gtfs` ne deviennent
jamais des horaires d'opérateur.

**Conclusion du B1 : ETA NON DÉFENDABLE**

### 6.3 BRT B2 (semi-express, 7 stations)

**Ce qui existe.** E5 : fréquence **6 min** L–S, **7 stations** confirmées et **distinctes
de B1 au niveau des identifiants** (`brt_b2_express` ≠ `brt_b1_…`, règle
anti-doublon : les 7 stations physiques partagées portent le même `dakar_bus_stop_id`
mais **jamais** le même `route_id` ; l'ETA B1 n'est jamais réutilisée pour B2).
Registre 4.14E : `B2 7 CONFIRMED`, fréquence `ESTIMATED`.

**Ce qui manque.** Exactement ce qui manque à B1 : phase, grille, calendrier, temps réel ;
aucune donnée le dimanche (fenêtre `FrequencyProvider` B2 = lun–sam seulement →
`UNKNOWN` le dimanche, comportement voulu).

**Conclusion du B2 : ETA NON DÉFENDABLE**

### 6.4 BRT B3 (semi-express, service depuis octobre 2025)

**Ce qui existe.** Identité officielle E6 (vérifiée 24/09/2026) : **7 stations nommées**
(Préfecture de Guédiawaye, Gueule Tapée, Parcelles, Croisement 22, Khar Yalla, Place de
la Nation, Papa Gueye Fall), fenêtres de pointe L–V 07–11 / 16–20. Registre : identité
`NEW` (service réel), structure `UNCONFIRMED`, `in_passbi:false`,
`excluded_from_gtfs:true`, correspondances `NAME_ONLY` **non utilisées**.

**Ce qui manque.** **Les données temporelles ne sont pas démontrées** : ni fréquence, ni
grille, ni observation, ni flux ; **la route n'est même pas exposée** dans
`dakar_network.json` (`services_not_exposed.brt_b3`, 7 `candidate_stop_ids`, « Gueule
Tapée » non confirmée ; aucune station inventée).

**Conclusion du B3 : ETA NON DÉFENDABLE**

### 6.5 DDD (Dakar Dem Dikk)

**Ce qui existe.** Identité E8/E11 (consultées 27/09/2026) : liste de lignes officielles
(urbaines, banlieue, dessertes TER), amplitude 06h–21h, départs 1er/21h pour les seules
lignes TAF TAF. `ddd_routes` (4.14E) : 53 lignes PassBi → 34 persistantes, 19
`NOT_FOUND`, identité `PERSISTENT`, structure et horaires `UNKNOWN`. Le registre public
39 lignes DDD, toutes `schedule_status: UNKNOWN`.

**Recherche d'une source actuelle (obligatoire §8 du lot).** *Chaîne
`route→trip→service→stop→time`* : **absente** — PassBi DDD est **2022–2023**
(historique strict, licence absente, jamais assimilable à 2026), `data/gtfs` DDD = 5
trips synthétiques sans stop_times, CETUD annonce des GTFS « opendata » sans lien de
téléchargement (E11), `demdikk.sn/horaires/` est un 404. *Chaîne `route→stop→prédiction`*
: **absente** — `api.dakardemdikk.sn` NXDOMAIN, aucun GTFS-RT, app DDD sans API. Le
SAEIV/CCO de juillet 2026 (E12) prouve qu'une géolocalisation temps réel **existe en
interne**, mais **aucun flux public** n'est exposé.

**Conclusion du DDD : SOURCE À OBTENIR**
*Action : demander à DDD/CETUD un GTFS statique actuel complet ou un accès
SAEIV/GTFS-RT documenté, avec licence de redistribution. Aucune ETA affichée en attendant,
hors fenêtres d'amplitude déjà publiées (qui ne sont ni un horaire ni un prochain départ).*

### 6.6 AFTU (Association de Financement des Transports Urbains)

**Ce qui existe.** E10 (consultée 27/09/2026, `source_date` 14/07/2026) : **liste de
lignes + itinéraires**, zéro donnée temporelle. CETUD annonce 72 lignes. `aftu_raw_registry`
(4.14E) : 73 lignes PassBi toutes `UNCONFIRMED`, trou de numérotation (PassBi 1–5+24–91
vs dakar 1–72), « PassBi A30 ≠ ligne 30 ». Registre public : 72 lignes AFTU,
`schedule_status: UNKNOWN`, `realtime UNKNOWN`. PassBi AFTU = **2022–2023**, licence
absente. `data/gtfs` AFTU = 135 trips synthétiques **sans aucun stop_time** (6 stops de
pôles uniquement).

**Recherche d'une source actuelle.** Aucune : ni grille, ni fréquence, ni GTFS-RT, ni API.
Les tiers (E14 Moovit, dakartransitsenegal.online) revendiquent des horaires/du « temps
réel » mais ne sont **pas des sources officielles opposables** (aucune API de niveau
source, méthodologie inconnue).

**Conclusion de l'AFTU : SOURCE À OBTENIR**
*Action : demander à AFTU/CETUD un GTFS ou des fréquences officielles datées avec
licence. Interdictions explicites maintenues : jamais reconstruire des passages depuis le
numéro de ligne, la destination, la géométrie, l'OSM ou une fréquence ; les anciens
PassBi ne deviennent jamais des horaires 2026.*

---

## 7. Légende (application au présent audit)

- 🟢 **X min** — source de **prochain départ réelle et défendable** (t0 + décalage
  validé). **Concerné : TER aux terminus ancrés seulement** (Dakar L–S + dim/férié,
  Diamniadio L–S ; ex. « 13:35, 6 min », statut `ESTIMATED`). Aucune autre mobilité.
- 🟡 **X min** — **retard établi** (écart mesuré horodaté). **Aucun réseau concerné** :
  aucune source de retard n'existe.
- 🔴 **Indisponible** — **interruption documentée**. **Aucun réseau concerné** : aucune
  interruption documentée n'a été trouvée.
- ⚪ **Aucune source** — absence de donnée, **ni retard ni interruption** : B1, B2, B3,
  DDD, AFTU, et les gares TER intermédiaires. On n'affiche ni minute inventée, ni
  « Indisponible », ni libellé « temps réel ».

---

## 8. Matrice finale

| Réseau | ETA actuel | Source | Précision | Fraîcheur | Donnée manquante | Prochaine action |
|---|---|---|---|---|---|---|
| **TER** | 🟢 **Terminus seulement** (Dakar L–S + dim/férié ; Diamniadio L–S) ; ⚪ 11 gares intermédiaires + Diamniadio dimanche | E1 `terdakar.sn` (SETER) + mécanisme ancré SHA 4.14E | `ESTIMATED`/`COMBINED` ± cadence (ex. 13:29→13:35 = 6 min) ; **aucun retard connu**, donc pas de minute « temps réel » | Page consultée 27/09/2026, constantes depuis ≤30/03/2026 ; `date_verified` registre 27/09/2026 | Grille datée gare×sens×jour ; temps de parcours intermédiaires ; GTFS-RT | Solliciter SETER (grille ou GTFS-RT) ; **conserver le mécanisme 4.14E intact** ; rien étendre |
| **BRT B1** | ⚪ Aucun | E4 `sunubrt.sn` : fréquence 6 min | Fréquence seule = **aucun instant de passage** (phase inconnue) | Vérifié 26–27/09/2026, page sans date | Premier passage horodaté station×sens **ou** GTFS-RT ; grille datée | Demander à SunuBRT/CETUD la grille ou le flux |
| **BRT B2** | ⚪ Aucun | E5 : fréquence 6 min, 7 stations | Idem B1 ; route **distincte** de B1 obligatoire | Vérifié 26–27/09/2026 | Idem B1 (+ statut du dimanche : `UNKNOWN` assumé) | Idem B1, identifiants B2 conservés |
| **BRT B3** | ⚪ Aucun | E6 : identité + fenêtres de pointe seulement | **Aucune donnée temporelle** démontrée | Identité vérifiée 24/09/2026 | Grille **ou** fréquence officielle B3 ; décision d'exposition de la route | Obtenir la source B3 ; exposition = lot séparé autorisé ; jamais de cadence B1/B2 |
| **DDD** | ⚪ Aucun | E8/E11 : identité seulement ; SAEIV interne (E12) non exposée | **Aucune** (PassBi 2022–2023 = historique) | Identité consultée 27/09/2026 ; SAEIV annoncée 06/07/2026 | GTFS statique actuel `route→trip→service→stop→time` **ou** flux SAEIV/GTFS-RT + licence | Demander à DDD/CETUD (contact via cetud.sn E11) |
| **AFTU** | ⚪ Aucun | E10 : liste de lignes seulement | **Aucune** (PassBi 2022–2023 = historique, numérotation divergente) | `source_date` 14/07/2026, consulté 27/09/2026 | GTFS ou fréquences officielles datées + licence | Demander à AFTU/CETUD ; jamais reconstruire (n°/OSM/fréquence/proximité) |

**Bilan** : 1 mobilité sur 6 avec un prochain départ défendable (TER, sous conditions et
terminus seulement) ; 0 source de temps réel ; 0 retard établi ; 0 interruption
documentée ; 3 mobilités en attente d'acquisition de source (B3, DDD, AFTU) ;
2 mobilités avec une fréquence actuelle non convertible en ETA (B1, B2).

---

## 9. Garde-fous rappelés (aucun n'a été violé par cet audit)

1. Fréquence **jamais** convertie en « prochain passage ».
2. Aucun `trips`/`stop_times`/`calendar`/`frequencies` créé ; PassBi historique jamais
   promu horaire 2026 ; OSM/fréquence/proximité jamais utilisés pour inférer un passage.
3. GPS utilisateur **jamais** présenté comme position véhicule ; aucun faux GTFS-RT, aucun
   véhicule simulé présenté comme réel, aucune prédiction fabriquée.
4. B1 et B2 restent deux `route_id` distincts ; jamais d'ETA B1 réutilisée pour B2.
5. Le mécanisme TER validé en 4.14E n'est ni étendu aux gares intermédiaires, ni modifié.
6. Aucune page n'est étiquetée « temps réel » au seul prétexte qu'elle montre des horaires
   ou une fréquence ; les mocks/badges du dépôt sont explicitement signalés comme tels.
7. Aucun fichier produit modifié ; ce rapport est l'**unique** changement.
