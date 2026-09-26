# AUDIT FEEDS CETUD ↔ PassBi ↔ Dakar Bus — LOT 16 BIS (2026-09-26)

**Nature : audit documentaire de récupération technique. Aucune modification de production.**
Aucune donnée inventée, aucune identité déduite. Ce qui n'a pas été trouvé est écrit « NON TROUVÉ » ; ce qui n'a pas pu être vérifié est écrit « UNKNOWN ».

| Élément | Valeur |
|---|---|
| Date d'audit (`retrieved_at`) | 2026-09-26 |
| Branche | `arena/01a0dc17-dakar-bus` |
| HEAD au début de l'audit | `203960cb07d8341c252db2a3bbe390bd974f7d3a` (arbre propre) |
| Fichiers de production **non touchés** | `flutter-src/assets/data/dakar_network.json`, `flutter-src/lib/**`, `data/gtfs/**`, `data/transit/**`, `server/**`, UI |
| Dossier de conservation créé | `audit/external-feeds/` (sources octet pour octet, `manifest.json`, `README.md`, `fetch_sources.sh`, `analyze_feeds.py`, `reports/`) |
| Classification des sources | **SOURCE_INSTITUTIONAL** = CETUD (`cetud.sn`), uniquement quand la donnée vient réellement du CETUD · **SOURCE_APPLICATION** = PassBi (`senpassbi.com`, `impactsolutionsas`) · **SOURCE_OPERATOR** = sites des exploitants (`aftu-senegal.org`, `demdikk.sn`) tels que transcrits dans `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` |

## Résumé exécutif

1. **CETUD ne publie aucun GTFS.** Le « FICHIER GTFS » n'existe sur `cetud.sn` qu'en prose (page Observatoire), sans lien, sans version. Les boutons « Télécharger » des pages DDD et AFTU livrent des **images JPEG cartographiques** (1282×905), pas des horaires ni des GTFS. Aucun temps réel.
2. **PassBi (application tierce) expose publiquement, dans un dépôt GitHub, quatre GTFS statiques** (AFTU, DDD, BRT, TER) — **récupérés, conservés, hachés, décompressés et analysés** (`audit/external-feeds/`). Leur **origine n'est pas documentée** ; l'origine CETUD n'est qu'une allégation marketing du site PassBi. Statut : **SOURCE_APPLICATION, origine CETUD alléguée non prouvée**.
3. **Les quatre flux sont HISTORICAL** : AFTU et DDD couvrent **2022-01-01 → 2023-12-31** (fichiers datés janvier–février 2023), BRT **2024-10-24 → 2024-12-31**, TER **2025-08-18 → 2025-08-31**. **Ils ne décrivent pas l'offre 2026** et ne doivent pas être présentés comme telle.
4. **L'API PassBi est documentée (OpenAPI 3.0.3, 8 GET sans authentification) mais son serveur de production est suspendu** (`passbi-api.onrender.com` → « This service has been suspended. »). Aucun chemin `/api*`, `/docs`, `/swagger*`, `/openapi*` n'existe sur `senpassbi.com`. Le backend de `app.senpassbi.com` et les endpoints des applications mobiles sont **UNKNOWN**.
5. **CAPTRANS** : site vitrine WordPress (0 document, 0 API, 0 flux). Plateforme d'exploitation AFTU **interne**.
6. **Temps réel = NON DISPONIBLE** pour AFTU, DDD, BRT, TER (aucun GTFS-RT, position, trip update ou alerte public ; PassBi liste GTFS-RT comme non implémenté et sa « position véhicule » est une interpolation d'horaire).
7. **Comparaison avec Dakar Bus** : sur la clé « numéro de ligne », **aucune ligne AFTU ni DDD de Dakar Bus n'obtient MATCH** (terminus non concordants pour les 54 AFTU et 10 DDD partageant un numéro ; 18 AFTU et 2 DDD de Dakar Bus n'existent dans aucune source ; 19 AFTU et 43 DDD du flux sont absentes de Dakar Bus). Les identités internes de Dakar Bus restent **non prouvées**.

---

## A. FEEDS TROUVÉS

| Source | URL | Format | Réseau | Version | Validité (au 2026-09-26) | Accès |
|---|---|---|---|---|---|---|
| PassBi — `impactsolutionsas/passbi_core` (SOURCE_APPLICATION) | `https://github.com/impactsolutionsas/passbi_core/blob/4de3d96e0c602ff2bdf718901d35c0f9d8098e96/gtfs_folder/gtfs_AFTU.zip` | GTFS statique (ZIP, 10 fichiers) | AFTU (73 routes) | pas de `feed_info.txt` ; fichiers datés 2023-01-23 → 2023-02-02 ; publié sur GitHub 2026-02-10T11:44:46Z | calendrier 2022-01-01 → 2023-12-31 → **HISTORICAL** | dépôt git public, sans authentification |
| PassBi — `impactsolutionsas/passbi_core` | `…/gtfs_folder/gtfs_Dem_Dikk.zip` (même commit) | GTFS statique (ZIP, 9 fichiers) | DDD (53 routes) | fichiers datés 2023-01-24 / 2023-02-02 ; publié 2026-02-10 | 2022-01-01 → 2023-12-31 → **HISTORICAL** | idem |
| PassBi — `impactsolutionsas/passbi_core` | `…/gtfs_folder/gtfs_BRT.zip` (même commit) | GTFS statique (ZIP, 9 fichiers) | BRT (B1, B2) | fichiers datés 2024-10-24 ; publié 2026-02-10 | `calendar.txt` vide ; `calendar_dates` 2024-10-24 → 2024-12-31 → **HISTORICAL** | idem |
| PassBi — `impactsolutionsas/passbi_core` | `…/gtfs_folder/gtfs_TER.zip` (même commit) | GTFS statique (ZIP CRLF, 6 fichiers) | TER / SETER (6 routes) | fichiers datés 2025-08-20 ; publié 2026-02-10 | 2025-08-18 → 2025-08-31 → **HISTORICAL** | idem |
| PassBi — `impactsolutionsas/passbi-gtfs-v1` (seconde copie) | `https://github.com/impactsolutionsas/passbi-gtfs-v1/tree/59438b4c69ea61e546f752ad880d8dee7e470d3e/fixtures` | GTFS décompressé (fixtures de test DDD, BRT, TER ; pas d'AFTU) | DDD, BRT, TER | fixtures ajoutées 2025-10-03 | **identiques** aux ZIP ci-dessus modulo CRLF, **sauf calendriers re-datés** (DDD 2022→2025, BRT 2024→2025) : re-datage développeur, **pas une mise à jour officielle** → non conservée | dépôt git public |
| CETUD — page DDD (SOURCE_INSTITUTIONAL) | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-ddd.jpeg` (bouton « Télécharger les lignes et horaires ») | **image JPEG 1282×905** (87 217 o) — cartographique, **pas GTFS, aucun horaire** | DDD | média WordPress n° 1668, téléversé 2024-12-03 ; copie identique (taille/dimensions) publiée par DDD le 2023-01-16 | **UNKNOWN** (image non datée ; le fichier a été téléversé par DDD le 2023-01-16 et re-téléversé par le CETUD le 2024-12-03 ; étiquettes au format `DDD_xxx`, voir §E) | public |
| CETUD — page AFTU | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-aftu.jpeg` (bouton « Télécharger le plan des lignes ») | **image JPEG 1282×905** (88 338 o) — cartographique, **pas GTFS** | AFTU | média n° 1667, téléversé 2024-12-03 | UNKNOWN | public — **non récupérable depuis le bac à sable** (voir §E) |
| CETUD — page BRT | `https://cetud.sn/wp-content/uploads/2024/11/sunubrt-guide-du-voyageur-vf.pdf` | PDF (guide voyageur) | BRT | 2024-11 | — | public, non récupéré (binaire) |
| CETUD — page TER | `https://cetud.sn/wp-content/uploads/2024/11/Plan-de-la-ligne-TER.pdf` | PDF (plan de ligne) | TER | 2024-11 | — | public, non récupéré (binaire) |
| CETUD — GTFS | **NON TROUVÉ** (aucune URL) | — | — | — | — | — |
| CAPTRANS — portail / API / GTFS | **NON TROUVÉ** | — | — | — | — | — |
| Temps réel (toutes sources) | **NON TROUVÉ** | — | — | — | — | — |

---

## B. CETUD (SOURCE_INSTITUTIONAL)

| Question | Réponse | Preuve |
|---|---|---|
| GTFS publié ? | **NON** | `robots.txt`, `sitemap.xml` (dernière modification 2025-05-08) : aucun `.zip`/`.csv`/`.json`/`gtfs` ; API REST WordPress médias (`/wp-json/wp/v2/media`, filtrages `application/*`, recherche `gtfs`) : aucun téléversement de données ; `posts?search=gtfs` → `[]` ; `search?search=gtfs` → `[]`. La page `/observatoire/systeme-de-donnees/` mentionne un « FICHIER GTFS … numérisation du réseau … opendata » **sans lien, sans URL, sans version** (contact : `observatoire@cetud.sn`). |
| Lignes AFTU ? | **OUI (prose + image)** | `/reseaux-de-transport/aftu/` : « 2 300 bus, 72 lignes, 14 GIE, 6 h – 21 h » ; bouton → `plan-lignes-aftu.jpeg` (**image cartographique**, non récupérée depuis le bac à sable). Aucun tableau de lignes, aucun arrêt. |
| Lignes DDD ? | **OUI (prose + image)** | `/reseaux-de-transport/ddd/` : « 400 bus, 38 lignes, 6 h – 21 h » ; bouton « Télécharger les lignes et horaires » → `plan-lignes-ddd.jpeg` (**image cartographique**, récupérée via copie DDD, voir §E). **Aucun horaire dans l'image.** |
| BRT ? | **OUI (prose + PDF)** | `/reseaux-de-transport/bus-regional-transit-brt/` : DSP du 2022-03-21 CETUD ↔ Dakar Mobilité ; 18 km, 23 stations, 121 bus électriques, 4 services, **« toutes les 6 minutes de 6 h à 21 h »** (fréquence **déclarée**) ; guide PDF ; application `prod.maasify.dakar`. **Pas de GTFS.** |
| TER ? | **OUI (prose + PDF)** | `/reseaux-de-transport/train-express-regional-ter/` : 14 gares ; plan PDF ; renvoi vers `terdakar.sn`. **Pas de GTFS.** |
| Horaires ? | **NON** | Aucun horaire par ligne (seulement des amplitudes « 6 h – 21 h »). |
| Temps réel ? | **NON** | Aucun flux GTFS-RT / positions / alertes. La page Observatoire indique que les données d'exploitation AFTU/DDD hors SAE proviennent de CAPTRANS (source interne). Les références `api.cetud.sn/gtfs-rt/*` du dépôt Dakar Bus (`server/`, `BRANCHEMENT_CETUD.md`) restent des **placeholders non vérifiés** (hôte non résolu/joignable). |
| Pages réseau (types WordPress) | 4 | `reseaux-de-transport` : TER (1055), BRT (1054), AFTU (1053), DDD (1018). |

**Confirmations externes de non-publication** : catalogue **Mobility Database** (`MobilityData/mobility-database-catalogs`, arbre complet, 3 555 fichiers) → **aucune entrée Sénégal/Dakar** ; recherche GitHub code/dépôts → aucun autre GTFS Dakar public ; **DT4A** (`git.digitaltransport4africa.org/data/africa`) → authentification requise, **non exploré** ; mémoire UASZ 2022 (Marone) : GTFS BRT « non disponible » ; article arXiv 2609.29998 (sept. 2026, GTFS4EV Dakar BRT) : GTFS BRT « fourni par l'autorité locale » (B1 omnibus, B2 semi-express, renfort B1, avec `frequencies.txt`) → **un GTFS BRT non public existe**, distinct du ZIP PassBi (qui n'a pas de `frequencies.txt`).

---

## C. PASSBI (SOURCE_APPLICATION)

| Question | Réponse | Preuve |
|---|---|---|
| API publique documentée ? | **OUI** | `https://impactsolutionsas.github.io/passbi_core/` (site public) et `docs/api/openapi.yaml` (OpenAPI 3.0.3, « PassBi Core API » v2.0.0, `security` non défini = sans authentification) : `GET /health`, `GET /v2/route-search`, `GET /v2/stops/nearby`, `GET /v2/stops/search`, `GET /v2/routes/list`, `GET /v2/stops/{id}/departures`, `GET /v2/routes/{id}/schedule`, `GET /v2/routes/{id}/trips` — JSON. Copie conservée : `audit/external-feeds/source/passbi_core/docs/api/openapi.yaml` (SHA-256 `b8cba8a1…3bd7`). |
| API publique **accessible** ? | **NON (2026-09-26)** | Serveur de production déclaré `https://passbi-api.onrender.com` → `/health` répond **« This service has been suspended. »** Second serveur déclaré : `http://localhost:8080` (dev). |
| `senpassbi.com` / `www.senpassbi.com` : `/api`, `/api/v1`, `/api/docs`, `/docs`, `/swagger`, `/swagger.json`, `/openapi.json`, `/openapi.yaml`, `/api-docs` ? | **NON** | Tous renvoient la page SPA « 404 » du site vitrine. `robots.txt` sans indication. `https://api.senpassbi.com/health` → 404 LiteSpeed (hôte **non documenté**, testé une fois, non exploré davantage). |
| GTFS ? | **OUI** | 4 ZIP dans `gtfs_folder/` du dépôt public `passbi_core` (ajoutés au commit initial `7a2b998`, 2026-02-10T11:44:46Z, auteur « IMPACT SOLUTION SAS ») — voir §A/§E. `STATUS.md` du dépôt (2026-02-10) : « Dakar Dem Dikk (53 routes), AFTU (73 routes), BRT (2 routes), TER (6 routes) — Total : 134 routes, 1 795 stops » (après « déduplication stops (30 m threshold) » ; les fichiers bruts totalisent 3 783 arrêts). |
| Origine des GTFS ? | **NON DOCUMENTÉE** | Aucun README/LICENSE/`feed_info.txt`/commentaire n'indique la provenance. `senpassbi.com` affirme « Official partner of CETUD » et « computed on official GTFS data » : **allégation**, non vérifiable. Indices (non probants) : `agency_phone` AFTU `00221 33 859 02 88` = téléphone publié par `aftu-senegal.org` ; dates de fichiers (janv.–févr. 2023) antérieures aux dépôts PassBi ; libellés de la carte CETUD/DDD au format `DDD_xxx` identiques aux `route_id` du flux. |
| Horaires ? | **OUI, HISTORIQUES** | `stop_times.txt` complets (AFTU 677 918 lignes, DDD 314 029, BRT 58 674, TER 7 332) — calendriers expirés (§H, §J). |
| Départs (endpoint `departures`) ? | **Documenté, non accessible** | `GET /v2/stops/{id}/departures` dans l'OpenAPI ; serveur suspendu. |
| Temps réel ? | **NON** | `STATUS.md` : « [ ] GTFS-RT support (real-time) » (non implémenté) ; `internal/routing/vehicle_position.go` = **interpolation à partir de l'horaire théorique**, pas de positions réelles. |
| Web app `https://app.senpassbi.com/` | **En ligne, backend UNKNOWN** | PWA Angular/Capacitor (build ≈ 2026-05-22, `ngsw.json`) ; le bundle inspecté partiellement n'a révélé aucune URL d'API ; **aucune tentative de contournement**. |
| Applications mobiles (`com.senpassbi.app`, App Store `id6757200579`) | **Endpoints UNKNOWN** | Fiches store non joignables depuis le bac à sable ; aucune analyse de binaire. Seuls les endpoints déclarés dans l'OpenAPI publique sont connus (tableau ci-dessous). |
| Autres dépôts publics `impactsolutionsas` (16) | Sans flux supplémentaire | `passbi-gtfs-v1` (fixtures re-datées), `passbi-web-app` (vide), `passbi-v2-backend` (NestJS billettique, Swagger `localhost:3000/docs` seulement), `travel-passbi-api` (starter). Seul hôte public trouvé dans le code : `passbi-api.onrender.com`. `PARTNER_API_README.md` décrit un système de clés API **optionnel** (non utilisé ici). |

**Endpoints PassBi publics connus (déclarés, non joignables le 2026-09-26)** — base `https://passbi-api.onrender.com`, méthode `GET`, format JSON, version API 2.0.0, réseaux DDD/AFTU/BRT/TER :

| Chemin | Objet |
|---|---|
| `/health` | état du service |
| `/v2/route-search` | itinéraires (paramètres origine/destination) |
| `/v2/stops/nearby` | arrêts à proximité |
| `/v2/stops/search` | recherche d'arrêts |
| `/v2/routes/list` | liste des lignes |
| `/v2/stops/{id}/departures` | prochains départs (théoriques) à un arrêt |
| `/v2/routes/{id}/schedule` | horaire d'une ligne |
| `/v2/routes/{id}/trips` | trips d'une ligne |

---

## D. CAPTRANS

| Question | Réponse | Preuve |
|---|---|---|
| Portail / API / fichiers / flux publics ? | **NON** | `https://captrans.sn/` = site WordPress institutionnel ; API REST publique : 7 pages (`actualites`, `aftu`, `captrans`, `Blog`, `Accueil` ×2, `Sample Page`), **0 média `application/*`** (`?rest_route=/wp/v2/media&media_type=application` → `[]`) ; `/wp-json/…` direct → 404. |
| GTFS ? | **NON** | Aucun. |
| Horaires ? | **NON** | Aucun. |
| Temps réel ? | **NON (interne)** | Le site évoque un suivi des rotations en interne ; aucun flux public. CETUD (post du 2019-08-19) : CAPTRANS = « Centre d'Appui aux métiers du Transport », plate-forme interne de données d'exploitation AFTU (équipements financés par le CETUD). |
| Contenu utile | Liste des 14 GIE AFTU | Alhamdoulillah, Avenue du Sénégal, Darou Salam, Diameguene, Diapalanté, Dimbalanté, Khéweul Aéroport, Nayobé, Ndiambour, Ressortissants du Walo, Sante Yalla, Sopelli Transports, Thiaroye Yeumbeul, Transports Mboup. Contact : Guédiawaye Mbode 3, +221 33 877 60 38, `captrans@captrans.sn`. |

---

## E. DONNÉES RÉCUPÉRÉES (fichiers exacts + SHA-256)

Conservés dans `audit/external-feeds/source/` (copies octet pour octet ; **rien n'est importé en production**). Provenance détaillée : `audit/external-feeds/manifest.json`.

| Fichier conservé | Source exacte | Récupéré le | Taille | Type | Date de publication / contenu | SHA-256 |
|---|---|---|---|---|---|---|
| `source/passbi_core/gtfs_folder/gtfs_AFTU.zip` | `github.com/impactsolutionsas/passbi_core` @ `4de3d96e0c602ff2bdf718901d35c0f9d8098e96` (blob `2cb0fff8`) | 2026-09-26 (`git clone`) | 10 693 791 o | ZIP GTFS | commit 2026-02-10T11:44:46Z ; fichiers internes 2023-01-23 → 2023-02-02 | `7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428` |
| `source/passbi_core/gtfs_folder/gtfs_Dem_Dikk.zip` | idem (blob `0d719ed5`) | 2026-09-26 | 2 635 299 o | ZIP GTFS | fichiers internes 2023-01-24 / 2023-02-02 | `578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159` |
| `source/passbi_core/gtfs_folder/gtfs_BRT.zip` | idem (blob `22e9f4cf`) | 2026-09-26 | 520 189 o | ZIP GTFS | fichiers internes 2024-10-24 | `f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4` |
| `source/passbi_core/gtfs_folder/gtfs_TER.zip` | idem (blob `0ea1bfb2`) | 2026-09-26 | 109 650 o | ZIP GTFS (CRLF) | fichiers internes 2025-08-20 | `09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408` |
| `source/passbi_core/docs/api/openapi.yaml` | idem (blob `59df0edf`, dernier commit 2026-02-13T17:52:03Z) | 2026-09-26 | 35 Ko | OpenAPI 3.0.3 YAML | v2.0.0 | `b8cba8a1cd3abb012266d240fcc1dfab99798afc03690f5ab55e21ac3b063bd7` |
| `source/cetud/plan-lignes-ddd.jpeg` | Bouton « Télécharger les lignes et horaires » de `https://cetud.sn/reseaux-de-transport/ddd/` → `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-ddd.jpeg` (média 1668 : 87 217 o, 1282×905, 2024-12-03). **Copie obtenue** depuis `https://demdikk.sn/wp-content/uploads/2023/01/plan-lignes-ddd.jpeg` (média 3938 : 87 217 o, 1282×905, téléversé 2023-01-16) | 2026-09-26 (résultat de recherche d'images, fichier complet) | 87 217 o | image/jpeg 1282×905 | fichier DDD 2023-01-16 ; re-téléversé par le CETUD 2024-12-03 | `6c40333cb4423e5bf4b33422eb70e20e08ab67c0c5d629ac06f901bbaf74f0f8` |

**Licence** : aucune déclarée pour les fichiers PassBi (ni `LICENSE`, ni `feed_info.txt`) ; non précisée pour l'image CETUD/DDD. **Type d'accès** : public, sans authentification.

**Inspection de `plan-lignes-ddd.jpeg` (source cartographique, pas GTFS)** : fond de plan type Google Maps de la presqu'île de Dakar avec tracés colorés étiquetés au format **`route_id`** (`DDD_1`, `DDD_2`, `DDD_4`, `DDD_5`, `DDD_7`, `DDD_8`, `DDD_11`, `DDD_12`, `DDD_13`, `DDD_15`, `DDD_16A`, `DDD_18`, `DDD_23`, `DDD_121`, `DDD_208`, `DDD_220`, `DDD_227`, `DDD_228`, `DDD_233`, `DDD_234`, `DDD_401`, `DDD_402`, `DDD_403`, `DDD_N305`, `DDD_N308`, `DDD_N311`, `DDD_N315`, `DDD_N319` — lecture visuelle non exhaustive, étiquettes superposées, aucune OCR). **Aucun horaire, aucun arrêt, aucune légende.** Le bouton « lignes et horaires » du CETUD ne livre donc **pas d'horaires**. Les libellés `DDD_Nxxx` sont retranscrits tels quels (sens du préfixe `N` : UNKNOWN). Identité octet pour octet avec la copie `cetud.sn` : **non prouvée** (SHA-256 `cetud.sn` non calculable depuis le bac à sable — même taille et mêmes dimensions ; `fetch_sources.sh` permet la vérification hors bac à sable).

**Non récupérés (hôtes injoignables depuis le bac à sable — seul `github.com` était accessible en HTTP direct)** : `plan-lignes-aftu.jpeg` (média 1667, 88 338 o, 1282×905 — **image cartographique, à conserver comme telle, non convertible en GTFS** ; SHA-256 UNKNOWN), `sunubrt-guide-du-voyageur-vf.pdf`, `Plan-de-la-ligne-TER.pdf`.

### E.1 Contenu des quatre GTFS (comptages exacts, `analyze_feeds.py`)

| Réseau | agency | routes | stops | trips | stop_times | calendar | calendar_dates | shapes (points / shape_id) | fare_attributes | fare_rules | frequencies | transfers | feed_info |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AFTU | 1 (`AFTU`, « Association de Financement des Professionnels du transport Urbain », `aftu-senegal.org`, `00221 33 859 02 88`, `Africa/Dakar`) | **73** | **2 401** | **11 077** | **677 918** | 4 (`FULL`, `LAV`, `SAMEDI`, `DIMANCHE` — 2022-01-01 → 2023-12-31) | 40 | 9 498 / 144 | 10 (`aftu_section_1…10` : 100 → 550 XOF) | **1 196 602** (67 routes couvertes) | absent | absent | absent |
| DDD | 1 (`DDD`, « Dakar Dem Dikk », `demdikk.sn/dakar-et-banlieue/`) | **53** | **1 277** | **9 529** | **314 029** | 4 (mêmes services, 2022-01-01 → 2023-12-31) | 40 (identique à AFTU) | 3 500 / 102 | 6 (`ddd_section_1…6` : 100, 150, 175, 200, 250, 350 XOF) | absent | absent | absent | absent |
| BRT | 1 (`BRT`, « BRT », URL vide) | **2** (B1, B2) | **79** (dont stations parentes) | **4 036** | **58 674** | 0 ligne (en-tête seul) | 69 (services `0_1…0_6`, `1_7` = listes de dates 2024-10-24 → 2024-12-31) | 6 785 / 35 | absent | absent | absent | 0 ligne | absent |
| TER | 1 (UUID, « SETER », `seter.sn`, **`UTC`**) | **6** | **26** (13 gares × 2 quais) | **572** | **7 332** | 12 (UUID, 2025-08-18 → 2025-08-31) | absent | absent | absent | absent | absent | absent | absent |

Observations de qualité (toutes consignées dans `reports/feed_summary.md`) :
- AFTU et DDD : `calendar_dates.txt` a un **en-tête séparé par `;`** (`service_id;date;exception_type`) alors que les données utilisent `,` — non conforme GTFS (lu en mode tolérant). Les 40 lignes = 20 dates (fériés 2022-2023) où `LAV` est retiré et `DIMANCHE` ajouté.
- AFTU : **tous les 11 077 trips utilisent le service `FULL` (7 j/7)** — aucune distinction semaine/samedi/dimanche. DDD : `LAV`/`SAMEDI`/`DIMANCHE` distincts, `FULL` inutilisé.
- AFTU : **738 trips sans aucune ligne `stop_times`** (`AFTU_31` dir 0, `AFTU_38` dir 1, `AFTU_41` dir 1, `AFTU_46` dir 1, **`AFTU_52` les deux sens → aucun horaire**, `AFTU_53` dir 0, `AFTU_57` dir 0, `AFTU_69` dir 1). DDD : **333 trips sans `stop_times`** (`DDD_217` dir 1 : 4, `DDD_311` dir 1 : 41, **`DDD_323` les deux sens → aucun horaire**).
- AFTU/DDD : `stops.txt` écrit `stop_lon` avant `stop_lat` (valeurs cohérentes : 100 % des arrêts dans l'emprise Dakar — AFTU lat 14,605–14,865 / lon −17,524…−17,133 ; DDD lat 14,617–14,833 / lon −17,519…−17,052). AFTU : 1 352 `zone_id` tarifaires (`SA_n`, plus des arrêts sans zone) exploités par `fare_rules` (1 196 602 lignes couvrant **67 des 73 routes**, réparties `aftu_section_1` 251 988 … `aftu_section_10` 120). DDD : aucun `zone_id`, pas de `fare_rules`.
- AFTU : `route_short_name` = code composite (`A1HL`, `A24NU`, `A59cD`, `A60bC`…, casse irrégulière) dont le préfixe numérique est **cohérent** avec `route_id` (`AFTU_n`) et `route_long_name` (`AFTU_n_…`) pour les 73 routes. DDD : idem (`D1LP`, `D102CC`, `D233 M` avec espace, `D9P0`/`D13T0` avec zéro) pour les 53 routes. Le **numéro de ligne** retenu (§F/§G) est ce préfixe numérique, **jamais** un identifiant interne Dakar Bus.
- BRT : `direction_id` vide (les deux sens sont distingués par le premier arrêt du trip) ; `trip_headsign` renseigné ; `parent_station` présent ; `agency_url` vide. TER : identifiants UUID, `agency_timezone = UTC` (Dakar est UTC+0, sans effet horaire).

---

## F. LIGNES AFTU (flux PassBi `gtfs_AFTU.zip` — HISTORICAL 2022-2023 — SOURCE_APPLICATION)

Numéro de ligne = préfixe numérique de `route_short_name`, vérifié identique à `route_id` et `route_long_name` (73/73 cohérents). Origine/destination = premier/dernier arrêt du motif d'arrêts dominant de chaque `direction_id` (le libellé porté par `trip_id`/`shape_id` désigne le terminus **de départ**). `schedule_status` : `SCHEDULE_PRESENT_HISTORICAL` = horaires théoriques présents mais **expirés** ; `NO_STOP_TIMES` = trips déclarés sans aucun horaire. **Numéros présents (73) : 1–5, 24–91** (le n° 90 n'est pas dans la liste officielle 2026 d'`aftu-senegal.org`, qui publie 1–5, 24–89, 91). Détail par sens : `audit/external-feeds/reports/routes_AFTU.md`.

| route_id | route_short_name | route_long_name | agency_id | direction_id : origine → destination (arrêts du motif dominant, trips) | arrêts distincts | trips | service_ids (trips) | schedule_status |
|---|---|---|---|---|---|---|---|---|
| `AFTU_1` | `A1HL` | AFTU_1_HLM-GR-YOFF_LAT-DIOR | AFTU | **0** : Lat Dior → Terminus 1 Face Keur Yoff (47 arr., 60 trips) ; **1** : Terminus 1 Face Keur Yoff → Lat Dior (45 arr., 54 trips) | 90 | 114 | FULL=114 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_2` | `A2PP` | AFTU_2_Parcelles-Assainies_Petersen | AFTU | **0** : Petersen 1 → Terminus Parcelles Assainies (47 arr., 75 trips) ; **1** : Terminus Parcelles Assainies → Petersen 1 (53 arr., 74 trips) | 98 | 149 | FULL=149 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_3` | `A3PY` | AFTU_3_Petersen_Yoff | AFTU | **0** : Yoff → Petersen 1 (62 arr., 89 trips) ; **1** : Petersen 1 → Yoff (59 arr., 86 trips) | 119 | 175 | FULL=175 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_4` | `A4PY` | AFTU_4_Petersen_Yoff | AFTU | **0** : Yoff → Petersen 1 (40 arr., 86 trips) ; **1** : Petersen 1 → Yoff (40 arr., 85 trips) | 78 | 171 | FULL=171 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_5` | `A5PP` | AFTU_5_Parcelles-Assainies_Petersen | AFTU | **0** : Petersen 1 → Terminus Parcelles Assainies (47 arr., 83 trips) ; **1** : Terminus Parcelles Assainies → Petersen 1 (46 arr., 86 trips) | 91 | 169 | FULL=169 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_24` | `A24NU` | AFTU_24_Notaire_UCAD | AFTU | **0** : Terminus 24 En Face Ucad → Terminus 24 64 (50 arr., 72 trips) ; **1** : Terminus 24 64 → Librairie Clairafrique (48 arr., 80 trips) | 96 | 152 | FULL=152 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_25` | `A25PP` | AFTU_25_Parcelle-Assainies_Petersen | AFTU | **0** : Petersen 1 → Terminus Parcelles Assainies (41 arr., 88 trips) ; **1** : Terminus Parcelles Assainies → Petersen 1 (41 arr., 95 trips) | 80 | 183 | FULL=183 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_26` | `A26PP` | AFTU_26_Parcelle-Assainies_Poste-Thiaroye | AFTU | **0** : Station Ciel Oil → Terminus Parcelles Assainies (40 arr., 88 trips) ; **1** : Face Brigade Nationale Des Sapeurs Pompiers Parcelle Assainies → Station Ciel Oil (41 arr., 94 trips) | 80 | 182 | FULL=182 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_27` | `A27GP` | AFTU_27_Guediawaye MB_Petersen | AFTU | **0** : Armurerie Coutellerie Amadou Niang → Terminus 27 (34 arr., 58 trips) ; **1** : Terminus 27 → Petersen 2 (41 arr., 68 trips) | 74 | 126 | FULL=126 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_28` | `A28HP` | AFTU_28_Hamo VI_Petersen | AFTU | **0** : Petersen 2 → Terminus 28 (31 arr., 62 trips) ; **1** : Terminus 28 → Petersen 2 (32 arr., 70 trips) | 60 | 132 | FULL=132 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_29` | `A29MP` | AFTU_29_Malibu_Petersen | AFTU | **0** : Petersen 1 → Terminus 29 (59 arr., 84 trips) ; **1** : Terminus 29 → Petersen 1 (56 arr., 98 trips) | 113 | 182 | FULL=182 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_30` | `A30CG` | AFTU_30_Colobane_Gadaye | AFTU | **0** : Terminus 30 49 → Colobane (67 arr., 71 trips) ; **1** : Colobane → Terminus 30 49 (68 arr., 64 trips) | 133 | 135 | FULL=135 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_31` | `A31ST` | AFTU_31_Sham_Thiaroye-kao | AFTU | **0** : ∅ (sans stop_times) → ∅ (0 arr., 85 trips) ; **1** : Sham Terminus 32  31 → Texaco (47 arr., 75 trips) | 47 | 160 | FULL=160 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 85 trips sans stop_times)` |
| `AFTU_32` | `A32DS` | AFTU_32_Daroukhane_Sham | AFTU | **0** : Sham Terminus 32  31 → Serigne Assane Terminus 32 33 (58 arr., 64 trips) ; **1** : Serigne Assane Terminus 32 33 → Sham Terminus 32  31 (62 arr., 74 trips) | 118 | 138 | FULL=138 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_33` | `A33CD` | AFTU_33_Colobane_Daroukane | AFTU | **0** : Serigne Assane Terminus 32 33 → Gare Routiére De Colobane (61 arr., 65 trips) ; **1** : Gare Routiére De Colobane → Serigne Assane Terminus 32 33 (63 arr., 62 trips) | 122 | 127 | FULL=127 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_34` | `A34LN` | AFTU_34_LAT-DIOR_Nord-Foire | AFTU | **0** : Ecole Japonaise Nord Foire → Lat Dior (49 arr., 76 trips) ; **1** : Lat Dior → Ecole Japonaise Nord Foire (48 arr., 94 trips) | 95 | 170 | FULL=170 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_35` | `A35NP` | AFTU_35_Ngor_Pikine-Texaco | AFTU | **0** : Texaco → Garage Ngor (51 arr., 94 trips) ; **1** : Garage Ngor → Texaco (47 arr., 83 trips) | 96 | 177 | FULL=177 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_36` | `A36DN` | AFTU_36_Daroukhane_Ngor | AFTU | **0** : Garage Ngor → Serigne Assane Terminus 36 46 70 (76 arr., 77 trips) ; **1** : Serigne Assane Terminus 36 46 70 → Garage Ngor (76 arr., 89 trips) | 150 | 166 | FULL=166 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_37` | `A37AU` | AFTU_37_APIX_UCAD | AFTU | **0** : Terminus 37 71 → Terminus 37 50 (98 arr., 54 trips) ; **1** : Terminus 37 50 → Terminus 37 71 (105 arr., 49 trips) | 201 | 103 | FULL=103 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_38` | `A38GS` | AFTU_38_Guediawaye_Sahm | AFTU | **0** : Sham Terminus 32  31 → Pai Terminus 38 (61 arr., 65 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 71 trips) | 61 | 136 | FULL=136 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 71 trips sans stop_times)` |
| `AFTU_39` | `A39DL` | AFTU_39_Diamalaye_Lat Dior | AFTU | **0** : Lat Dior → Terminus 59-39-69-80 Près De La Plage De Diamalaye (68 arr., 54 trips) ; **1** : Terminus 59-39-69-80 Près De La Plage De Diamalaye → Lat Dior (67 arr., 72 trips) | 133 | 126 | FULL=126 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_40` | `A40MP` | AFTU_40_Mbao_Petersen | AFTU | **0** : Petersen 2 → Terminus Grand Mbao (52 arr., 50 trips) ; **1** : Terminus Grand Mbao → Petersen 2 (51 arr., 63 trips) | 101 | 113 | FULL=113 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_41` | `A41GP` | AFTU_41_Guediawaye_Petersen | AFTU | **0** : Petersen 2 → Terminus 41 (60 arr., 53 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 70 trips) | 60 | 123 | FULL=123 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 70 trips sans stop_times)` |
| `AFTU_42` | `A42GO` | AFTU_42_Gadaye_Ouakam | AFTU | **0** : Devant Terminus 42 Et 44 Marché Jeudi → Terminus 30 49 (66 arr., 75 trips) ; **1** : Terminus 30 49 → Devant Terminus 42 Et 44 Marché Jeudi (67 arr., 86 trips) | 131 | 161 | FULL=161 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_43` | `A43CO` | AFTU_43_Comico_Ouakam | AFTU | **0** : Terminus 43 → Terminus 43 Yeumbeul Nord (82 arr., 64 trips) ; **1** : Terminus 43 Yeumbeul Nord → Terminus 43 (82 arr., 73 trips) | 162 | 137 | FULL=137 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_44` | `A44MO` | AFTU_44_Mbao_Ouakam | AFTU | **0** : Terminus 43 → Terminus Grand Mbao (55 arr., 93 trips) ; **1** : Terminus Grand Mbao → Terminus 43 (56 arr., 97 trips) | 109 | 190 | FULL=190 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_45` | `A45kP` | AFTU_45_kounoune_Parcelles Assainies | AFTU | **0** : Terminus Parcelles Assainies → Terminus 45 (101 arr., 75 trips) ; **1** : Terminus 45 → Terminus Parcelles Assainies (92 arr., 68 trips) | 191 | 143 | FULL=143 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_46` | `A46GL` | AFTU_46_Guediawaye_Lat Dior | AFTU | **0** : Lat Dior → Serigne Assane Terminus 36 46 70 (69 arr., 67 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 73 trips) | 69 | 140 | FULL=140 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 73 trips sans stop_times)` |
| `AFTU_47` | `A47LA` | AFTU_47_Lat Dior_Almadies | AFTU |  | 0 | 0 |  | `NO_SCHEDULE (aucun trip sans stop_times)` |
| `AFTU_48` | `A48LR` | AFTU_48_Lat Dior_Rufisque | AFTU | **0** : Terminus 48 → Garage Lat Dior (49 arr., 178 trips) ; **1** : Lat Dior → Terminus 48 (53 arr., 60 trips) | 101 | 238 | FULL=238 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_49` | `A49GN` | AFTU_49_Gadaye_Ngor | AFTU | **0** : Garage Ngor → Terminus 30 49 (87 arr., 64 trips) ; **1** : Terminus 30 49 → Garage Ngor (94 arr., 83 trips) | 179 | 147 | FULL=147 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_50` | `A50MP` | AFTU_50_Malicka_Petersen | AFTU | **0** : Petersen 2 → Terminus 37 50 (56 arr., 63 trips) ; **1** : Terminus 37 50 → Petersen 2 (54 arr., 72 trips) | 108 | 135 | FULL=135 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_51` | `A51BJ` | AFTU_51_Baux Maraichers_Jaxaay | AFTU | **0** : Terminus Pénitence → Gare Des Baux MaraîChers (71 arr., 80 trips) ; **1** : Gare Des Baux MaraîChers → Terminus Pénitence (73 arr., 77 trips) | 142 | 157 | FULL=157 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_52` | `A52BJ` | AFTU_52_Baux Maraichers_Jaxaay | AFTU | **0** : ∅ (sans stop_times) → ∅ (0 arr., 99 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 91 trips) | 0 | 190 | FULL=190 | `NO_STOP_TIMES (trips déclarés mais aucun horaire)` |
| `AFTU_53` | `A53KS` | AFTU_53_KEUR MASSAR_Sebikotane | AFTU | **0** : ∅ (sans stop_times) → ∅ (0 arr., 89 trips) ; **1** : Terminus 54 → Terminus 53 (87 arr., 87 trips) | 87 | 176 | FULL=176 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 89 trips sans stop_times)` |
| `AFTU_54` | `A54MU` | AFTU_54_M T O A_UCAD | AFTU | **0** : Terminus 37 71 → Terminus 54 Pres De La Pharmacie Pascal (64 arr., 96 trips) ; **1** : Terminus 54 Pres De La Pharmacie Pascal → Terminus 37 71 (60 arr., 103 trips) | 122 | 199 | FULL=199 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_55` | `A55PR` | AFTU_55_Petersen_Rufisque | AFTU | **0** : Terminus 55 → Petersen 2 (40 arr., 105 trips) ; **1** : Petersen 2 → Terminus 55 (44 arr., 83 trips) | 82 | 188 | FULL=188 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_56` | `A56JP` | AFTU_56_Jaxaaye_Petersen | AFTU | **0** : Petersen 2 → Arrêt Pa Thiaw (45 arr., 98 trips) ; **1** : Arrêt Pa Thiaw → Petersen 2 (42 arr., 72 trips) | 85 | 170 | FULL=170 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_57` | `A57LR` | AFTU_57_LIBERTE 5_Rufisque Gouye Mouride | AFTU | **0** : ∅ (sans stop_times) → ∅ (0 arr., 91 trips) ; **1** : Terminus 57 → Terminus 57 (54 arr., 81 trips) | 54 | 172 | FULL=172 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 91 trips sans stop_times)` |
| `AFTU_58` | `A58CS` | AFTU_58_Comico_Sahm | AFTU | **0** : Sham Terminus 38 45 58 → Terminus 43 Yeumbeul Nord (49 arr., 75 trips) ; **1** : Terminus 43 Yeumbeul Nord → Sham Terminus 38 45 58 (41 arr., 96 trips) | 88 | 171 | FULL=171 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_59` | `A59cD` | AFTU_59_cite gendarmerie_Diamalaye | AFTU | **0** : Terminus 59 Cité Assemblée 2 → Yoff (106 arr., 71 trips) ; **1** : Yoff → Terminus 59 Cité Assemblée 2 (115 arr., 91 trips) | 219 | 162 | FULL=162 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_60` | `A60bC` | AFTU_60_bargny_Colobane | AFTU | **0** : Colobane → En Face Angle Baye Laye (45 arr., 92 trips) ; **1** : Diouma Ndal Dalli → Colobane (46 arr., 91 trips) | 90 | 183 | FULL=183 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_61` | `A61Km` | AFTU_61_KEUR MASSAR_mamelles | AFTU | **0** : Terminus 61 → Keur Massar Terminus 61 (64 arr., 83 trips) ; **1** : Keur Massar Terminus 61 → Terminus 61 (63 arr., 97 trips) | 125 | 180 | FULL=180 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_62` | `A62gy` | AFTU_62_gueule tapee_youssou mbergane | AFTU | **0** : Terminus 62 (Rufisque Nord) → Gueule Tapée Rue Gt-49 (85 arr., 74 trips) ; **1** : Penc-Mi Boulevard Gueule Tapée → Arrêt Chérif (Rufisque Nord) (81 arr., 65 trips) | 164 | 139 | FULL=139 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_63` | `A63SR` | AFTU_63_Stade-Amitié_Rufisque | AFTU | **0** : Terminus 63 → Léopold Sédar Senghor (72 arr., 59 trips) ; **1** : Léopold Sédar Senghor → Terminus 63 (74 arr., 58 trips) | 144 | 117 | FULL=117 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_64` | `A64dg` | AFTU_64_diamniadio_guediawaye | AFTU | **0** : Terminus 24 64 → Terminus 64 (80 arr., 87 trips) ; **1** : Terminus 64 → Terminus 24 64 (81 arr., 79 trips) | 159 | 166 | FULL=166 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_65` | `A65Ck` | AFTU_65_Colobane_kounoune | AFTU | **0** : Kounoune École Mbaba → Colobane (62 arr., 79 trips) ; **1** : Colobane → Kounoune École Mbaba (66 arr., 62 trips) | 126 | 141 | FULL=141 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_66` | `A66gY` | AFTU_66_gorom_Yoff | AFTU | **0** : Yoff → Terminus 66 Et 79 (105 arr., 70 trips) ; **1** : Terminus 66 Et 79 → Yoff (104 arr., 66 trips) | 204 | 136 | FULL=136 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_67` | `A67Ot` | AFTU_67_Ouakam_thiawlene | AFTU | **0** : Terminus 67 → Ouakam Terminus 67 (75 arr., 62 trips) ; **1** : Ouakam Terminus 67 → Terminus 67 (77 arr., 53 trips) | 150 | 115 | FULL=115 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_68` | `A68st` | AFTU_68_sebikotane_tally diallo | AFTU | **0** : Yeumbeul → Terminus 53 (66 arr., 113 trips) ; **1** : Terminus 53 → Yeumbeul (66 arr., 76 trips) | 130 | 189 | FULL=189 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_69` | `A69Dn` | AFTU_69_Diamalaye_namora | AFTU | **0** : Terminus 69 → Terminus 59-39-69-80 Près De La Plage De Diamalaye (65 arr., 57 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 69 trips) | 65 | 126 | FULL=126 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 69 trips sans stop_times)` |
| `AFTU_70` | `A70dd` | AFTU_70_darouhane_diaxaye | AFTU | **0** : Jaxaay 2 En Face Cabinet Médical Matlaboul Chifa I → Serigne Assane Terminus 36 46 70 (52 arr., 79 trips) ; **1** : Serigne Assane Terminus 36 46 70 → Jaxaay 2 En Face Cabinet Médical Matlaboul Chifa I (61 arr., 83 trips) | 111 | 162 | FULL=162 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_71` | `A71cK` | AFTU_71_claudel_KEUR MASSAR | AFTU | **0** : Pharmacie Elimane Aly Drame Keur Massar → Terminus 37 71 (50 arr., 78 trips) ; **1** : Terminus 37 71 → Pharmacie Elimane Aly Drame Keur Massar (55 arr., 66 trips) | 103 | 144 | FULL=144 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_72` | `A72ks` | AFTU_72_kounoune_Guédiawaye | AFTU | **0** : Pai Terminus 38 → Kounoune École Mbaba (91 arr., 79 trips) ; **1** : Kounoune École Mbaba → Pai Terminus 38 (90 arr., 78 trips) | 179 | 157 | FULL=157 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_73` | `A73LP` | AFTU_73_Lac Rose_POSTE THIAROYE | AFTU | **0** : Station Ciel Oil → Terminus De La Ligne 73 (78 arr., 119 trips) ; **1** : Terminus De La Ligne 73 → Station Ciel Oil (79 arr., 111 trips) | 155 | 230 | FULL=230 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_74` | `A74bS` | AFTU_74_bargny_SOCABECK | AFTU | **0** : Terminus 74 81 → Bargny (87 arr., 72 trips) ; **1** : Bargny → Terminus 74 81 (87 arr., 80 trips) | 172 | 152 | FULL=152 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_75` | `A75CM` | AFTU_75_Colobane_MALIKA | AFTU | **0** : Terminus 75 Malika → Colobane (76 arr., 74 trips) ; **1** : Colobane → Terminus 75 Malika (78 arr., 60 trips) | 152 | 134 | FULL=134 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_76` | `A76AS` | AFTU_76_ASSURANCE_SIPRESS | AFTU | **0** : Onfp Terminus 76 → Terminus 76 (68 arr., 73 trips) ; **1** : Terminus 76 → Onfp Terminus 76 (67 arr., 77 trips) | 133 | 150 | FULL=150 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_77` | `A77CL` | AFTU_77_CITE TACCO_LIBERTE 5 | AFTU | **0** : Terminus Liberté 5 → Terminus 77 (57 arr., 71 trips) ; **1** : Terminus 77 → Terminus Liberté 5 (52 arr., 96 trips) | 107 | 167 | FULL=167 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_78` | `A78DL` | AFTU_78_DIAMAGUENE_LIBERTE 5 | AFTU | **0** : Terminus Liberté 5 → Marche Diamegeune (54 arr., 63 trips) ; **1** : Marche Diamegeune → Terminus Liberté 5 (52 arr., 77 trips) | 104 | 140 | FULL=140 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_79` | `A79Cg` | AFTU_79_CAMBERENE2_gorom | AFTU | **0** : Terminus 79 87 → Terminus 29 (97 arr., 62 trips) ; **1** : Terminus 29 → Terminus 79 87 (97 arr., 69 trips) | 192 | 131 | FULL=131 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_80` | `A80DD` | AFTU_80_DAROU THIOUB_Diamalaye | AFTU | **0** : Terminus 59-39-69-80 Près De La Plage De Diamalaye → Terminus 80 (105 arr., 63 trips) ; **1** : Terminus 80 → Terminus 59-39-69-80 Près De La Plage De Diamalaye (104 arr., 73 trips) | 207 | 136 | FULL=136 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_81` | `A81BT` | AFTU_81_BEAUX MARAICHER_TAWFEKH | AFTU | **0** : Terminus 74 81 → Gare Des Baux MaraîChers (94 arr., 69 trips) ; **1** : Gare Des Baux MaraîChers → Terminus 74 81 (73 arr., 63 trips) | 165 | 132 | FULL=132 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_82` | `A82CL` | AFTU_82_CITE COMICO_Lat Dior | AFTU | **0** : Service D'Hygiène → Terminus 43 Yeumbeul Nord (46 arr., 61 trips) ; **1** : Terminus 43 Yeumbeul Nord → Garage Lat Dior (51 arr., 75 trips) | 96 | 136 | FULL=136 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_83` | `A83AZ` | AFTU_83_ARAFAT_ZONE CAPTAGE | AFTU | **0** : Zone De Captage → Rufisque Ville Devant La Boutique Orange À  Coté De La Mairie (90 arr., 82 trips) ; **1** : Sonadis près du Jardin En Face Hôtel De Ville → Zone De Captage (93 arr., 143 trips) | 181 | 225 | FULL=225 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_84` | `A84JU` | AFTU_84_Jaxaay_UCAD | AFTU | **0** : Delafosse Commerce → Jaxaay 2 Pénitence (76 arr., 82 trips) ; **1** : Jaxaay 2 Pénitence → Terminus 84_54Derrière Ucad En Face Canal 4 (73 arr., 109 trips) | 148 | 191 | FULL=191 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_85` | `A85LL` | AFTU_85_Lac Rose_LIBERTE5 | AFTU | **0** : Terminus Liberté 5 → Terminus De La Ligne 73 (96 arr., 55 trips) ; **1** : Terminus De La Ligne 73 → Terminus Liberté 5 (89 arr., 133 trips) | 98 | 188 | FULL=188 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_86` | `A86TT` | AFTU_86_THIAROYE_TOUBAB DJALAW | AFTU | **0** : Terminus 86 → Route De Malika En Face Mairie Yeumbel Sud Et Sgbs (64 arr., 64 trips) ; **1** : Yeumbeul → Terminus 86 (68 arr., 67 trips) | 131 | 131 | FULL=131 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_87` | `A87BM` | AFTU_87_BAMBIBOR COMICO_MASSALIKOU | AFTU | **0** : Maristes Terminus 87 → Terminus 79 87 (71 arr., 48 trips) ; **1** : Terminus 79 87 → Maristes Terminus 87 (68 arr., 52 trips) | 137 | 100 | FULL=100 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_88` | `A88KL` | AFTU_88_KEUR MASSAR_LIBERTE5 | AFTU | **0** : Terminus Liberté 5 → Terminus 88 (81 arr., 47 trips) ; **1** : Terminus 88 → Terminus Liberté 5 (78 arr., 58 trips) | 157 | 105 | FULL=105 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_89` | `A89bT` | AFTU_89_bargny_TAWFEKH | AFTU | **0** : Terminus 89 → Poste Courant Bargny Près De La Gare Ter (55 arr., 68 trips) ; **1** : Poste Courant Bargny Près De La Gare Ter → Terminus 89 (53 arr., 63 trips) | 106 | 131 | FULL=131 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_90` | `A90TD` | AFTU_90_THOAROYE-AZUR_DENI BIRAME NDAO | AFTU | **0** : Terminus 90 → Deni Birame Ndao Nord (82 arr., 80 trips) ; **1** : Deni Birame Ndao Nord → Terminus 90 (82 arr., 75 trips) | 162 | 155 | FULL=155 | `SCHEDULE_PRESENT_HISTORICAL` |
| `AFTU_91` | `A91AD` | AFTU_91_APIX_DOUGAR | AFTU | **0** : Chez Lo électricien → Losso (70 arr., 48 trips) ; **1** : Losso → Terminus 91 (70 arr., 55 trips) | 139 | 103 | FULL=103 | `SCHEDULE_PRESENT_HISTORICAL` |

---

## G. LIGNES DDD (flux PassBi `gtfs_Dem_Dikk.zip` — HISTORICAL 2022-2023 — SOURCE_APPLICATION)

Mêmes conventions. **Numéros présents (53)** : 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 18, 20, 23, 102, 103, 105, 111, 121, 208, 210, 213, 217, 218, 219, 220, 221, 223, 227, 228, 231, 232, 233, 234, 301, 305, 308, 311, 315, 319, 323, 401, 402, 403, 404, 405, 501, 502, 503, 504. Détail par sens : `audit/external-feeds/reports/routes_DDD.md`.

| route_id | route_short_name | route_long_name | agency_id | direction_id : origine → destination (arrêts du motif dominant, trips) | arrêts distincts | trips | service_ids (trips) | schedule_status |
|---|---|---|---|---|---|---|---|---|
| `DDD_01` | `D1LP` | DDD_01_LECLERC_PARCELLES-ASSAINIES | DDD | **0** : Terminus Leclerc → Terminus Parcelles Assaines (43 arr., 89 trips) ; **1** : Terminus Parcelles Assaines → Terminus Leclerc (42 arr., 119 trips) | 83 | 208 | DIMANCHE=67, LAV=72, SAMEDI=69 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_02` | `D2DL` | DDD_02_DAROUKHANE_LECLERC | DDD | **0** : Terminus Leclerc → Terminus Daroukhane (55 arr., 79 trips) ; **1** : Terminus Daroukhane → Terminus Leclerc (49 arr., 93 trips) | 102 | 172 | DIMANCHE=51, LAV=65, SAMEDI=56 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_04` | `D4DL` | DDD_04_DIEUPPEUL_LECLERC | DDD | **0** : Terminus Leclerc → Terminus Liberté 5 (37 arr., 75 trips) ; **1** : Terminus Liberté 5 → Terminus Leclerc (36 arr., 81 trips) | 71 | 156 | DIMANCHE=53, LAV=54, SAMEDI=49 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_05` | `D5GP` | DDD_05_GUEDIAWAYE_PALAIS1 | DDD | **0** : Terminus Palais 1 → Terminus Guédiawayee (33 arr., 105 trips) ; **1** : Terminus Guédiawayee → Terminus Palais 1 (40 arr., 111 trips) | 71 | 216 | DIMANCHE=59, LAV=87, SAMEDI=70 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_06` | `D6CP` | DDD_06_CAMBERENE_PALAIS2 | DDD | **0** : Terminus Palais 2 → Terminus Canberene 2 (52 arr., 78 trips) ; **1** : Terminus Canberene 2 → Terminus Palais 2 (58 arr., 85 trips) | 108 | 163 | DIMANCHE=53, LAV=56, SAMEDI=54 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_07` | `D7OP` | DDD_07_OUAKAM_PALAIS-02 | DDD | **0** : Terminus Palais 2 → Terminus 7218 219 (36 arr., 138 trips) ; **1** : Terminus 7218 219 → Terminus Palais 2 (36 arr., 160 trips) | 70 | 298 | DIMANCHE=88, LAV=109, SAMEDI=101 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_08` | `D8PL` | DDD_08_AEROPORT-LSS_PALAIS-02 | DDD | **0** : Terminus Palais 2 → AéRoport LéOpold SéDar Senghor (47 arr., 99 trips) ; **1** : AéRoport LéOpold SéDar Senghor → Terminus Palais 2 (50 arr., 103 trips) | 95 | 202 | DIMANCHE=74, LAV=64, SAMEDI=64 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_09` | `D9P0` | DDD_09_LIBERTE-06_PALAIS-02 | DDD | **0** : Terminus Palais 2 → Terminus 9 Liberté 6 (32 arr., 120 trips) ; **1** : Terminus 9 Liberté 6 → Terminus Palais 2 (34 arr., 117 trips) | 64 | 237 | DIMANCHE=70, LAV=93, SAMEDI=74 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_10` | `D10LP` | DDD_10_LIBERTE 5_PALAIS-02 | DDD | **0** : Terminus Palais 2 → Terminus Liberté 5 (34 arr., 86 trips) ; **1** : Terminus Liberté 5 → Terminus Palais 2 (30 arr., 99 trips) | 62 | 185 | DIMANCHE=52, LAV=58, SAMEDI=75 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_11` | `D11KL` | DDD_11_KEUR MASSAR_LAT DIOR | DDD | **0** : Lat-Dior → Terminus Keur Massar (48 arr., 83 trips) ; **1** : Terminus Keur Massar → Lat-Dior (49 arr., 103 trips) | 95 | 186 | DIMANCHE=61, LAV=66, SAMEDI=59 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_12` | `D12GP` | DDD_12_Guediawaye_Palais-1 | DDD | **0** : Terminus Palais 1 → Terminus Guédiawayee (60 arr., 95 trips) ; **1** : Terminus Guédiawayee → Terminus Palais 1 (59 arr., 101 trips) | 117 | 196 | DIMANCHE=64, LAV=65, SAMEDI=67 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_13` | `D13T0` | DDD_13_PALAIS-02_TERMINUS-DIEUPPEUL | DDD | **0** : Terminus Palais 2 → Terminus Liberté 5 (24 arr., 98 trips) ; **1** : Terminus Liberté 5 → Terminus Palais 2 (25 arr., 108 trips) | 47 | 206 | DIMANCHE=71, LAV=64, SAMEDI=71 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_15` | `D15PR` | DDD_15_PALAIS1_RUFISQUE | DDD | **0** : Terminus Palais 1 → Terminus Rufisque P15 (43 arr., 95 trips) ; **1** : Terminus Rufisque P15 → Terminus Palais 1 (45 arr., 113 trips) | 86 | 208 | DIMANCHE=66, LAV=75, SAMEDI=67 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_16` | `D16MP` | DDD_16_MALIKA_PALAIS1 | DDD | **0** : Terminus Palais 2 → Terminus Malika (45 arr., 92 trips) ; **1** : Terminus Malika → Terminus Palais 2 (42 arr., 112 trips) | 85 | 204 | DIMANCHE=71, LAV=65, SAMEDI=68 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_18` | `D18D` | DDD_18_DIEUPEUL | DDD | **1** : Terminus Liberté 5 → Lonase Dieuppeul (43 arr., 39 trips) | 43 | 39 | LAV=39 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_20` | `D20D` | DDD_20_DIEUPEUL | DDD | **0** : Terminus Liberté 5 → Pharmacie La Miséricorde (45 arr., 39 trips) | 45 | 39 | LAV=39 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_23` | `D23P2` | DDD_23_PALAIS-2_PARCELLE-ASSAINIES | DDD | **0** : Terminus Palais 1 → Terminus Parcelles Assaines (56 arr., 90 trips) ; **1** : Terminus Parcelles Assaines → Terminus Palais 2 (57 arr., 106 trips) | 104 | 196 | DIMANCHE=64, LAV=66, SAMEDI=66 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_102` | `D102CC` | DDD_102_CAMBERENE_COLOBANE | DDD | **0** : Terrain Colobane → Terminus Canberene 2 (37 arr., 108 trips) ; **1** : Terminus Canberene 2 → Terrain Colobane (34 arr., 117 trips) | 69 | 225 | DIMANCHE=76, LAV=73, SAMEDI=76 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_103` | `D103AC` | DDD_103_AEROPORT_COLOBANE | DDD | **0** : Terrain Colobane → AéRoport LéOpold SéDar Senghor (32 arr., 108 trips) ; **1** : AéRoport LéOpold SéDar Senghor → Terrain Colobane (35 arr., 117 trips) | 65 | 225 | DIMANCHE=76, LAV=73, SAMEDI=76 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_105` | `D105CP` | DDD_105_CAMBERENE_PETERSEN | DDD | **0** : Ecole Papa Gueye Fall → Terminus Canberene 2 (25 arr., 108 trips) ; **1** : Terminus Canberene 2 → Grande Mosquée De Dakar (28 arr., 117 trips) | 52 | 225 | DIMANCHE=76, LAV=73, SAMEDI=76 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_111` | `D111LY` | DDD_111_LECLERC_YOFF | DDD | **0** : Terminus Leclerc → Terminus Diamalaye (29 arr., 108 trips) ; **1** : Terminus Diamalaye → Terminus Leclerc (31 arr., 117 trips) | 58 | 225 | DIMANCHE=76, LAV=73, SAMEDI=76 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_121` | `D121LS` | DDD_121_LECLERC_SCAT URBAM | DDD | **0** : Terminus Leclerc → Terminus 121 (32 arr., 108 trips) ; **1** : Terminus 121 → Terminus Leclerc (36 arr., 117 trips) | 66 | 225 | DIMANCHE=76, LAV=73, SAMEDI=76 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_208` | `D208BR` | DDD_208_BAYAKH_RUFISQUE | DDD | **0** : Terminus Rufisque P15 → Bayakh (33 arr., 85 trips) ; **1** : Bayakh → Terminus Rufisque P15 (32 arr., 85 trips) | 63 | 170 | DIMANCHE=62, LAV=54, SAMEDI=54 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_210` | `D210TM` | DDD_210_BAUX-MARAICHERS_TIVAOUNE-PEULH | DDD | **0** : Gare Des Baux MaraichéRs → Tivaouane Peulh (36 arr., 76 trips) ; **1** : Tivaouane Peulh → Gare Des Baux MaraichéRs (33 arr., 85 trips) | 67 | 161 | DIMANCHE=49, LAV=58, SAMEDI=54 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_213` | `D213DR` | DDD_213_DIEUPPEUL_RUFISQUE | DDD | **0** : Terminus Liberté 5 → Gare De Rufisque (48 arr., 76 trips) ; **1** : Gare De Rufisque → Terminus Liberté 5 (48 arr., 85 trips) | 94 | 161 | DIMANCHE=49, LAV=58, SAMEDI=54 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_217` | `D217OT` | DDD_217_OUAKAM_THIAROYE | DDD | **0** : Terminus 7218 219 → Terminus Poste Thiaroye (63 arr., 91 trips) ; **1** : Terminus Poste Thiaroye → Terminus 7218 219 (63 arr., 101 trips) | 124 | 192 | DIMANCHE=56, LAV=69, SAMEDI=67 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 4 trips sans stop_times)` |
| `DDD_218` | `D218AT` | DDD_218_AEROPORT-LSS_THIAROYE | DDD | **0** : Terminus 7218 219 → Terminus Poste Thiaroye (35 arr., 66 trips) ; **1** : Terminus Poste Thiaroye → Terminus 7218 219 (34 arr., 87 trips) | 67 | 153 | DIMANCHE=51, LAV=51, SAMEDI=51 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_219` | `D219DO` | DDD_219_DAROUKHANE_OUAKAM | DDD | **0** : Terminus 7218 219 → Terminus Daroukhane (60 arr., 91 trips) ; **1** : Terminus Daroukhane → Terminus 7218 219 (59 arr., 97 trips) | 117 | 188 | DIMANCHE=52, LAV=69, SAMEDI=67 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_220` | `D220DR` | DDD_220_DAROUKHANE_RUFISQUE | DDD | **0** : Superette → Devant La Mairie De Guédiawaye (36 arr., 80 trips) ; **1** : Devant La Mairie De Guédiawaye → Superette (38 arr., 76 trips) | 72 | 156 | DIMANCHE=52, LAV=52, SAMEDI=52 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_221` | `D221AG` | DDD_221_ALMADIES_GADAYE | DDD | **0** : Rond-Point Garage Ngor → Terminus Gadaye (55 arr., 76 trips) ; **1** : Terminus Gadaye → Rond-Point Garage Ngor (53 arr., 83 trips) | 106 | 159 | DIMANCHE=50, LAV=56, SAMEDI=53 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_223` | `D223DP` | DDD_223_DAROUKHANE_PETERSEN | DDD | **0** : Petersen → Terminus Daroukhane (24 arr., 59 trips) ; **1** : Terminus Daroukhane → Petersen (27 arr., 70 trips) | 49 | 129 | DIMANCHE=41, LAV=45, SAMEDI=43 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_227` | `D227TM` | DDD_227_KEUR-MASSAR_TERMINUS-PARCELLES | DDD | **0** : Terminus Parcelles Assaines → Terminus Keur Massar (43 arr., 87 trips) ; **1** : Terminus Keur Massar → Terminus Parcelles Assaines (41 arr., 94 trips) | 82 | 181 | DIMANCHE=66, LAV=60, SAMEDI=55 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_228` | `D228RY` | DDD_228_RUFISQUE_YENNE | DDD | **0** : Terminus → Espi (28 arr., 56 trips) ; **1** : Espi → Terminus (28 arr., 57 trips) | 54 | 113 | DIMANCHE=36, LAV=41, SAMEDI=36 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_231` | `D231BJ` | DDD_231_BAUX-MARAICHERS_JAXAAY | DDD | **0** : Gare Des Baux MaraichéRs → Terminus La LinguèRe (38 arr., 76 trips) ; **1** : Terminus La LinguèRe → Gare Des Baux MaraichéRs (35 arr., 85 trips) | 71 | 161 | DIMANCHE=49, LAV=58, SAMEDI=54 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_232` | `D232AB` | DDD_232_AEROPORT_BAUX-MARAICHERS | DDD | **0** : AéRoport LéOpold SéDar Senghor → Gare Des Baux MaraichéRs (36 arr., 63 trips) ; **1** : Gare Des Baux MaraichéRs → AéRoport LéOpold SéDar Senghor (36 arr., 73 trips) | 70 | 136 | DIMANCHE=43, LAV=50, SAMEDI=43 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_233` | `D233 M` | DDD_233_BAUX-MARAICHERS_ Palais-1 | DDD | **0** : Terminus Palais 1 → Gare Des Baux MaraichéRs (40 arr., 59 trips) ; **1** : Gare Des Baux MaraichéRs → Terminus Palais 1 (40 arr., 70 trips) | 78 | 129 | DIMANCHE=41, LAV=45, SAMEDI=43 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_234` | `D234JL` | DDD_234_JAXAAY_LECLERC | DDD | **0** : Terminus Leclerc → Terminus La LinguèRe (34 arr., 62 trips) ; **1** : Terminus La LinguèRe → Terminus Leclerc (35 arr., 76 trips) | 67 | 138 | DIMANCHE=44, LAV=49, SAMEDI=45 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_301` | `D301MP` | DDD_301_MEDINA_PARCELLES | DDD | **0** : Sham → Terminus Parcelles Assaines (27 arr., 144 trips) ; **1** : Terminus Parcelles Assaines → Sham (24 arr., 144 trips) | 49 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_305` | `D305PY` | DDD_305_PALAIS-2_YOFF | DDD | **0** : Aéroport Léopold Sédar Senghor → Terminus Palais 2 (24 arr., 144 trips) ; **1** : Terminus Palais 2 → Aéroport Léopold Sédar Senghor (21 arr., 144 trips) | 43 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_308` | `D308OP` | DDD_308_OUAKAM_PATTE-D'OIE | DDD | **0** : Terrain Basket Hôpital Nabil Choucair → Mamelles (21 arr., 144 trips) ; **1** : Mamelles → Jardin Patte D'Oie (23 arr., 144 trips) | 43 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_311` | `D311TT` | DDD_311_THIAROYE_TIV-PEULH | DDD | **0** : Croisement Keur Massar À Côté Station Senoil → Terminus De La Ligne 311 (17 arr., 41 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 41 trips) | 17 | 82 | LAV=82 | `SCHEDULE_PRESENT_HISTORICAL (partiel : 41 trips sans stop_times)` |
| `DDD_315` | `D315RY` | DDD_315_RUFISQUE_YENNE | DDD | **0** : Terminus SéBikhotane → Gare De Rufisque (23 arr., 144 trips) ; **1** : Gare De Rufisque → Terminus SéBikhotane (22 arr., 144 trips) | 43 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_319` | `D319SL` | DDD_319_OUAKAM_SICAP-LIBERTE-6 | DDD | **0** : Rond-Point Liberte 6 → Terminus 7218 219 (23 arr., 144 trips) ; **1** : Terminus 7218 219 → Rond-Point Liberte 6 (24 arr., 144 trips) | 45 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_323` | `D323PT` | DDD_323_GUEULE-TAPEE_PARCELLE-ASSAINIE | DDD | **0** : ∅ (sans stop_times) → ∅ (0 arr., 144 trips) ; **1** : ∅ (sans stop_times) → ∅ (0 arr., 144 trips) | 0 | 288 | DIMANCHE=96, LAV=96, SAMEDI=96 | `NO_STOP_TIMES (trips déclarés mais aucun horaire)` |
| `DDD_401` | `D401AO` | DDD_401_AIBD_OUAKAM | DDD | **0** : Terminus Diamniadio → Terminus 7218 219 (30 arr., 31 trips) ; **1** : Terminus 7218 219 → Terminus Diamniadio (24 arr., 27 trips) | 51 | 58 | DIMANCHE=20, LAV=18, SAMEDI=20 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_402` | `D402AT` | DDD_402_AIBD_THIAROYE | DDD | **0** : Terminus Diamniadio → Terminus Poste Thiaroye (26 arr., 84 trips) ; **1** : Terminus Poste Thiaroye → Terminus Diamniadio (28 arr., 63 trips) | 52 | 147 | DIMANCHE=42, LAV=65, SAMEDI=40 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_403` | `D403AP` | DDD_403_AIBD_PARCELLES-ASSAINIES | DDD | **0** : Terminus Diamniadio → Terminus Parcelles Assaines (29 arr., 33 trips) ; **1** : Terminus Parcelles Assaines → Terminus Diamniadio (30 arr., 36 trips) | 57 | 69 | DIMANCHE=27, LAV=20, SAMEDI=22 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_404` | `D404AL` | DDD_404_AIBD_LECLERC | DDD | **0** : Aibd → Terminus Leclerc (6 arr., 44 trips) ; **1** : Terminus Leclerc → Aibd (4 arr., 44 trips) | 8 | 88 | DIMANCHE=32, LAV=28, SAMEDI=28 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_405` | `D405AD` | DDD_405_AIBD_DIEUPPEUL | DDD | **0** : Terminus Diamniadio → Terminus Liberté 5 (19 arr., 47 trips) ; **1** : Terminus Liberté 5 → Terminus Diamniadio (16 arr., 43 trips) | 33 | 90 | DIMANCHE=36, LAV=30, SAMEDI=24 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_501` | `D501GP` | DDD_501_GARE-DE-DAKAR_PALAIS-2 | DDD | **0** : Port De Dakar → Terminus Palais 2 (9 arr., 150 trips) ; **1** : Terminus Palais 2 → Port De Dakar (9 arr., 150 trips) | 16 | 300 | DIMANCHE=100, LAV=100, SAMEDI=100 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_502` | `D502CU` | DDD_502_COLOBANE-UCAD-COLOBANE | DDD | **0** : Gare Ter Hlm → Terrain Colobane (15 arr., 52 trips) | 15 | 52 | LAV=52 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_503` | `D503CB` | DDD_503_COLOBANE-BELAIR-COLOBANE | DDD | **1** : Gare Ter Hlm → Scoa (8 arr., 52 trips) | 8 | 52 | LAV=52 | `SCHEDULE_PRESENT_HISTORICAL` |
| `DDD_504` | `D504DS` | DDD_504_GARE-DE-DIAMNIADIO_SPHERE MINISTERIELLE | DDD | **0** : Gare Ter De Diamniadio → Institut De Recherche En Santé (6 arr., 153 trips) ; **1** : Institut De Recherche En Santé → Gare Ter De Diamniadio (4 arr., 147 trips) | 8 | 300 | DIMANCHE=100, LAV=100, SAMEDI=100 | `SCHEDULE_PRESENT_HISTORICAL` |

### G.1 BRT et TER (pour mémoire — mêmes flux PassBi, HISTORICAL)

| route_id | route_short_name | route_long_name | agency_id | direction_id : origine → destination (arrêts du motif dominant, trips) | arrêts distincts | trips | service_ids (trips) | schedule_status |
|---|---|---|---|---|---|---|---|---|
| `B2` | `B2` | B2 | BRT | **orig=GUEDIAWAYE** : GUEDIAWAYE → PETERSEN (7 arr., 840 trips) ; **orig=PETERSEN** : PETERSEN → GUEDIAWAYE (7 arr., 894 trips) | 14 | 1734 | 0_1=289, 0_2=289, 0_3=289, 0_4=289, 0_5=289, 0_6=289 | `SCHEDULE_PRESENT_HISTORICAL` |
| `B1` | `B1` | B1 | BRT | **orig=GUEDIAWAYE** : GUEDIAWAYE → PETERSEN (21 arr., 1022 trips) ; **orig=PETERSEN** : PETERSEN → GUEDIAWAYE (21 arr., 1100 trips) ; **orig=POLE GRAND MEDINE** : POLE GRAND MEDINE → PETERSEN (14 arr., 180 trips) | 43 | 2302 | 0_1=345, 0_2=345, 0_3=345, 0_4=345, 0_5=345, 0_6=345, 1_7=232 | `SCHEDULE_PRESENT_HISTORICAL` |

| route_id | route_short_name | route_long_name | agency_id | direction_id : origine → destination (arrêts du motif dominant, trips) | arrêts distincts | trips | service_ids (trips) | schedule_status |
|---|---|---|---|---|---|---|---|---|
| UUID (`route_short_name` 20001) | `20001` | Diamniadio (DIA) -> Dakar - Gare ferroviaire (DAK) | UUID → SETER | **0** : Diamniadio → Dakar - Gare ferroviaire (13 arr., 270 trips) | 13 | 270 | 12 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |
| UUID (`route_short_name` 10001) | `10001` | Dakar - Gare ferroviaire (DAK) -> Diamniadio (DIA) | UUID → SETER | **1** : Dakar - Gare ferroviaire → Diamniadio (13 arr., 262 trips) | 13 | 262 | 7 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |
| UUID (`route_short_name` 20922) | `20922` | Yeumbeul (YEU) -> Dakar - Gare ferroviaire (DAK) | UUID → SETER | **0** : Yeumbeul → Dakar - Gare ferroviaire (8 arr., 4 trips) | 8 | 4 | 2 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |
| UUID (`route_short_name` 23001) | `23001` | Rufisque (RUF) -> Dakar - Gare ferroviaire (DAK) | UUID → SETER | **0** : Rufisque → Dakar - Gare ferroviaire (11 arr., 16 trips) | 11 | 16 | 2 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |
| UUID (`route_short_name` 14922) | `14922` | Dakar - Gare ferroviaire (DAK) -> Yeumbeul (YEU) | UUID → SETER | **1** : Dakar - Gare ferroviaire → Yeumbeul (8 arr., 4 trips) | 8 | 4 | 3 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |
| UUID (`route_short_name` 13005) | `13005` | Dakar - Gare ferroviaire (DAK) -> Rufisque (RUF) | UUID → SETER | **1** : Dakar - Gare ferroviaire → Rufisque (11 arr., 16 trips) | 11 | 16 | 3 service_id (UUID) | `SCHEDULE_PRESENT_HISTORICAL` |

---

## H. HORAIRES (issus de `stop_times.txt` — HISTORIQUES — fréquence OBSERVÉE ≠ déclarée)

Méthode : pour chaque route × `service_id` × sens, départs au premier arrêt de chaque trip horodaté → `premier_depart`, `dernier_depart`, `nombre_de_trips`, `jours_de_service` (`calendar.txt`), **`fréquence_observée`** = médiane des écarts entre départs successifs (min). **Aucun flux ne contient `frequencies.txt` : il n'existe aucune fréquence déclarée dans les fichiers.** Seule fréquence déclarée connue : **BRT « toutes les 6 minutes »** (page CETUD, hors flux), qui coïncide avec l'observation (6,0 min par sens). Ces horaires décrivent **2022-2023 (AFTU/DDD), fin 2024 (BRT), août 2025 (TER)** et **ne sont pas l'offre 2026**. Détail par sens : `audit/external-feeds/reports/schedules_*.md|csv`.

Synthèse : AFTU — 135 couples route×sens horodatés, 10 339 trips horodatés, premiers départs entre 04:48 et 07:15, derniers départs entre 19:30 et 19:45, fréquence observée médiane **6,8 min** (1,3 → 16,1) ; **DDD** — 287 couples route×service×sens, 3 303 trips `LAV` / 2 975 `SAMEDI` / 2 918 `DIMANCHE`, premiers départs 05:30–08:00, derniers 19:07–23:00, fréquence observée médiane **25 min** (12 → 120).

### H.1 AFTU (service `FULL`, 7 j/7 dans le flux)

| route_id | n° (champ flux) | service_id | jours de service | premier départ | dernier départ | trips horodatés (tous sens) | fréq. observée médiane (min, par sens) | fréq. déclarée |
|---|---|---|---|---|---|---|---|---|
| `AFTU_1` | 1 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:33:33 | 19:33:43 | 114 | 5.7–6.8 | AUCUNE dans le flux |
| `AFTU_2` | 2 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:22:03 | 19:33:49 | 149 | 5.9–6.0 | AUCUNE dans le flux |
| `AFTU_3` | 3 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 04:55:11 | 19:33:32 | 175 | 11.6–11.7 | AUCUNE dans le flux |
| `AFTU_4` | 4 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:38:40 | 19:32:53 | 171 | 7.7–10.2 | AUCUNE dans le flux |
| `AFTU_5` | 5 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:13:42 | 19:32:48 | 169 | 5.2–5.5 | AUCUNE dans le flux |
| `AFTU_24` | 24 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:07:21 | 19:32:46 | 152 | 5.2–12.2 | AUCUNE dans le flux |
| `AFTU_25` | 25 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:56:46 | 19:33:02 | 183 | 4.5–4.8 | AUCUNE dans le flux |
| `AFTU_26` | 26 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:00:22 | 19:30:21 | 182 | 4.4–8.9 | AUCUNE dans le flux |
| `AFTU_27` | 27 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:12:39 | 19:44:34 | 126 | 6.5–9.1 | AUCUNE dans le flux |
| `AFTU_28` | 28 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:31:00 | 19:34:55 | 132 | 6.1–7.4 | AUCUNE dans le flux |
| `AFTU_29` | 29 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:10:50 | 19:35:01 | 182 | 4.5–5.2 | AUCUNE dans le flux |
| `AFTU_30` | 30 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:29:19 | 19:32:56 | 135 | 6.0–13.0 | AUCUNE dans le flux |
| `AFTU_31` | 31 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:07:30 | 19:33:49 | 75 | 6.2 | AUCUNE dans le flux |
| `AFTU_32` | 32 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:32:42 | 19:35:47 | 138 | 5.9–11.1 | AUCUNE dans le flux |
| `AFTU_33` | 33 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:38:51 | 19:30:27 | 127 | 6.8–13.1 | AUCUNE dans le flux |
| `AFTU_34` | 34 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:08:39 | 19:32:38 | 170 | 3.8–5.9 | AUCUNE dans le flux |
| `AFTU_35` | 35 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:12:52 | 19:35:52 | 177 | 9.1–10.1 | AUCUNE dans le flux |
| `AFTU_36` | 36 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:27:12 | 19:35:38 | 166 | 5.2–8.8 | AUCUNE dans le flux |
| `AFTU_37` | 37 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:59:47 | 19:32:20 | 103 | 7.9–10.9 | AUCUNE dans le flux |
| `AFTU_38` | 38 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:15:48 | 19:31:48 | 65 | 9.6 | AUCUNE dans le flux |
| `AFTU_39` | 39 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:49:55 | 19:34:32 | 126 | 4.5–7.0 | AUCUNE dans le flux |
| `AFTU_40` | 40 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:23:34 | 19:36:32 | 113 | 6.5–13.6 | AUCUNE dans le flux |
| `AFTU_41` | 41 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:24:10 | 19:37:33 | 53 | 13.4 | AUCUNE dans le flux |
| `AFTU_42` | 42 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:26:17 | 19:34:11 | 161 | 5.0–6.9 | AUCUNE dans le flux |
| `AFTU_43` | 43 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:04:14 | 19:34:02 | 137 | 5.8–13.8 | AUCUNE dans le flux |
| `AFTU_44` | 44 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 04:48:28 | 19:34:35 | 190 | 4.6–4.7 | AUCUNE dans le flux |
| `AFTU_45` | 45 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:35:58 | 19:35:15 | 143 | 6.3–11.7 | AUCUNE dans le flux |
| `AFTU_46` | 46 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:28:54 | 19:32:48 | 67 | 6.1 | AUCUNE dans le flux |
| `AFTU_48` | 48 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:13:00 | 19:34:51 | 238 | 1.3–7.2 | AUCUNE dans le flux |
| `AFTU_49` | 49 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:24:56 | 19:32:07 | 147 | 4.4–12.4 | AUCUNE dans le flux |
| `AFTU_50` | 50 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:25:02 | 19:34:53 | 135 | 6.1–6.2 | AUCUNE dans le flux |
| `AFTU_51` | 51 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:37:20 | 19:35:22 | 157 | 5.9–10.4 | AUCUNE dans le flux |
| `AFTU_53` | 53 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:39:38 | 19:35:10 | 87 | 9.7 | AUCUNE dans le flux |
| `AFTU_54` | 54 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:31:00 | 19:33:28 | 199 | 3.7–4.4 | AUCUNE dans le flux |
| `AFTU_55` | 55 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:37:15 | 19:33:02 | 188 | 4.4–7.0 | AUCUNE dans le flux |
| `AFTU_56` | 56 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:24:37 | 19:31:21 | 170 | 3.3–5.8 | AUCUNE dans le flux |
| `AFTU_57` | 57 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:02:49 | 19:35:34 | 81 | 12.6 | AUCUNE dans le flux |
| `AFTU_58` | 58 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:18:31 | 19:34:09 | 171 | 4.5–8.1 | AUCUNE dans le flux |
| `AFTU_59` | 59 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:41:38 | 19:45:18 | 162 | 6.1–11.6 | AUCUNE dans le flux |
| `AFTU_60` | 60 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:09:37 | 19:30:22 | 183 | 4.7–4.8 | AUCUNE dans le flux |
| `AFTU_61` | 61 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:21:06 | 19:45:10 | 180 | 9.1–9.7 | AUCUNE dans le flux |
| `AFTU_62` | 62 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:08:40 | 19:35:37 | 139 | 5.9–10.6 | AUCUNE dans le flux |
| `AFTU_63` | 63 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:30:00 | 19:32:44 | 117 | 7.8–10.0 | AUCUNE dans le flux |
| `AFTU_64` | 64 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:41:48 | 19:33:28 | 166 | 4.8–5.5 | AUCUNE dans le flux |
| `AFTU_65` | 65 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:53:37 | 19:30:45 | 141 | 4.9–12.2 | AUCUNE dans le flux |
| `AFTU_66` | 66 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:34:27 | 19:36:30 | 136 | 6.9–12.8 | AUCUNE dans le flux |
| `AFTU_67` | 67 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:34:30 | 19:30:42 | 115 | 6.0–16.1 | AUCUNE dans le flux |
| `AFTU_68` | 68 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:05:02 | 19:32:44 | 189 | 2.8–5.5 | AUCUNE dans le flux |
| `AFTU_69` | 69 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 07:15:00 | 19:37:16 | 57 | 8.6 | AUCUNE dans le flux |
| `AFTU_70` | 70 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:51:40 | 19:32:45 | 162 | 5.7 | AUCUNE dans le flux |
| `AFTU_71` | 71 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:40:07 | 19:34:24 | 144 | 6.2–6.7 | AUCUNE dans le flux |
| `AFTU_72` | 72 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:51:55 | 19:36:04 | 157 | 8.5–10.8 | AUCUNE dans le flux |
| `AFTU_73` | 73 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:33:47 | 19:31:08 | 230 | 6.8–7.0 | AUCUNE dans le flux |
| `AFTU_74` | 74 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:59:00 | 19:34:56 | 152 | 6.4–10.1 | AUCUNE dans le flux |
| `AFTU_75` | 75 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:24:23 | 19:37:47 | 134 | 5.8–12.4 | AUCUNE dans le flux |
| `AFTU_76` | 76 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:12:17 | 19:35:24 | 150 | 5.5–9.9 | AUCUNE dans le flux |
| `AFTU_77` | 77 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:11:04 | 19:33:46 | 167 | 3.9–11.0 | AUCUNE dans le flux |
| `AFTU_78` | 78 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:31:05 | 19:34:01 | 140 | 7.3–9.1 | AUCUNE dans le flux |
| `AFTU_79` | 79 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:32:55 | 19:33:26 | 131 | 6.8–12.8 | AUCUNE dans le flux |
| `AFTU_80` | 80 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:14:00 | 19:36:28 | 136 | 5.0–7.1 | AUCUNE dans le flux |
| `AFTU_81` | 81 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:15:00 | 19:35:05 | 132 | 6.7–12.3 | AUCUNE dans le flux |
| `AFTU_82` | 82 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:36:38 | 19:31:13 | 136 | 5.7–7.1 | AUCUNE dans le flux |
| `AFTU_83` | 83 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:26:09 | 19:34:52 | 225 | 1.9–10.2 | AUCUNE dans le flux |
| `AFTU_84` | 84 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:51:26 | 19:33:04 | 191 | 3.2–5.6 | AUCUNE dans le flux |
| `AFTU_85` | 85 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:30:21 | 19:35:54 | 188 | 2.2–11.0 | AUCUNE dans le flux |
| `AFTU_86` | 86 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:35:56 | 19:37:10 | 131 | 11.8–13.2 | AUCUNE dans le flux |
| `AFTU_87` | 87 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:33:24 | 19:34:59 | 100 | 8.1–9.3 | AUCUNE dans le flux |
| `AFTU_88` | 88 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:37:45 | 19:35:46 | 105 | 7.7–11.4 | AUCUNE dans le flux |
| `AFTU_89` | 89 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 05:45:12 | 19:36:51 | 131 | 6.3–13.5 | AUCUNE dans le flux |
| `AFTU_90` | 90 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:05:26 | 19:32:29 | 155 | 5.4–6.2 | AUCUNE dans le flux |
| `AFTU_91` | 91 | `FULL` | lun/mar/mer/jeu/ven/sam/dim | 06:10:48 | 19:32:49 | 103 | 7.3–13.0 | AUCUNE dans le flux |

### H.2 DDD (services `LAV` / `SAMEDI` / `DIMANCHE`)

| route_id | n° (champ flux) | service_id | jours de service | premier départ | dernier départ | trips horodatés (tous sens) | fréq. observée médiane (min, par sens) | fréq. déclarée |
|---|---|---|---|---|---|---|---|---|
| `DDD_01` | 1 | `DIMANCHE` | dim | 06:30:00 | 21:30:00 | 67 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_01` | 1 | `LAV` | lun/mar/mer/jeu/ven | 05:50:00 | 22:05:00 | 72 | 20.0–32.5 | AUCUNE dans le flux |
| `DDD_01` | 1 | `SAMEDI` | sam | 06:00:00 | 21:10:00 | 69 | 20.0–35.0 | AUCUNE dans le flux |
| `DDD_02` | 2 | `DIMANCHE` | dim | 06:30:00 | 21:30:00 | 51 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_02` | 2 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:50:00 | 65 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_02` | 2 | `SAMEDI` | sam | 06:00:00 | 21:05:00 | 56 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_04` | 4 | `DIMANCHE` | dim | 07:00:00 | 21:40:00 | 53 | 30.0–40.0 | AUCUNE dans le flux |
| `DDD_04` | 4 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:25:00 | 54 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_04` | 4 | `SAMEDI` | sam | 06:30:00 | 21:30:00 | 49 | 25.0–45.0 | AUCUNE dans le flux |
| `DDD_05` | 5 | `DIMANCHE` | dim | 06:30:00 | 21:30:00 | 59 | 30.0 | AUCUNE dans le flux |
| `DDD_05` | 5 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:40:00 | 87 | 20.0 | AUCUNE dans le flux |
| `DDD_05` | 5 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 70 | 25.0 | AUCUNE dans le flux |
| `DDD_06` | 6 | `DIMANCHE` | dim | 06:30:00 | 21:25:00 | 53 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_06` | 6 | `LAV` | lun/mar/mer/jeu/ven | 05:45:00 | 21:50:00 | 56 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_06` | 6 | `SAMEDI` | sam | 06:00:00 | 21:30:00 | 54 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_07` | 7 | `DIMANCHE` | dim | 07:00:00 | 21:20:00 | 88 | 20.0 | AUCUNE dans le flux |
| `DDD_07` | 7 | `LAV` | lun/mar/mer/jeu/ven | 05:45:00 | 21:05:00 | 109 | 12.0–20.0 | AUCUNE dans le flux |
| `DDD_07` | 7 | `SAMEDI` | sam | 06:00:00 | 21:20:00 | 101 | 15.0–20.0 | AUCUNE dans le flux |
| `DDD_08` | 8 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 74 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_08` | 8 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:20:00 | 64 | 20.0–30.0 | AUCUNE dans le flux |
| `DDD_08` | 8 | `SAMEDI` | sam | 06:00:00 | 21:05:00 | 64 | 25.0 | AUCUNE dans le flux |
| `DDD_09` | 9 | `DIMANCHE` | dim | 07:00:00 | 21:10:00 | 70 | 25.0 | AUCUNE dans le flux |
| `DDD_09` | 9 | `LAV` | lun/mar/mer/jeu/ven | 05:50:00 | 21:20:00 | 93 | 15.0–20.0 | AUCUNE dans le flux |
| `DDD_09` | 9 | `SAMEDI` | sam | 06:00:00 | 21:10:00 | 74 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_10` | 10 | `DIMANCHE` | dim | 07:00:00 | 21:20:00 | 52 | 30.0 | AUCUNE dans le flux |
| `DDD_10` | 10 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:30:00 | 58 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_10` | 10 | `SAMEDI` | sam | 06:30:00 | 21:05:00 | 75 | 15.0–25.0 | AUCUNE dans le flux |
| `DDD_11` | 11 | `DIMANCHE` | dim | 06:30:00 | 21:05:00 | 61 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_11` | 11 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:45:00 | 66 | 20.0–35.0 | AUCUNE dans le flux |
| `DDD_11` | 11 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 59 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_12` | 12 | `DIMANCHE` | dim | 06:30:00 | 21:30:00 | 64 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_12` | 12 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:50:00 | 65 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_12` | 12 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 67 | 25.0 | AUCUNE dans le flux |
| `DDD_13` | 13 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 71 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_13` | 13 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:05:00 | 64 | 25.0 | AUCUNE dans le flux |
| `DDD_13` | 13 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 71 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_15` | 15 | `DIMANCHE` | dim | 06:30:00 | 21:05:00 | 66 | 25.0 | AUCUNE dans le flux |
| `DDD_15` | 15 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:50:00 | 75 | 20.0–30.0 | AUCUNE dans le flux |
| `DDD_15` | 15 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 67 | 25.0 | AUCUNE dans le flux |
| `DDD_16` | 16 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 71 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_16` | 16 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:50:00 | 65 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_16` | 16 | `SAMEDI` | sam | 06:00:00 | 21:10:00 | 68 | 20.0–30.0 | AUCUNE dans le flux |
| `DDD_18` | 18 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:10:00 | 39 | 20.0 | AUCUNE dans le flux |
| `DDD_20` | 20 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:10:00 | 39 | 20.0 | AUCUNE dans le flux |
| `DDD_23` | 23 | `DIMANCHE` | dim | 06:30:00 | 21:30:00 | 64 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_23` | 23 | `LAV` | lun/mar/mer/jeu/ven | 05:50:00 | 21:25:00 | 66 | 20.0–30.0 | AUCUNE dans le flux |
| `DDD_23` | 23 | `SAMEDI` | sam | 06:00:00 | 21:15:00 | 66 | 20.0–30.0 | AUCUNE dans le flux |
| `DDD_102` | 102 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_102` | 102 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:14:00 | 73 | 17.0–25.0 | AUCUNE dans le flux |
| `DDD_102` | 102 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_103` | 103 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_103` | 103 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:14:00 | 73 | 17.0–25.0 | AUCUNE dans le flux |
| `DDD_103` | 103 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_105` | 105 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_105` | 105 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:14:00 | 73 | 17.0–25.0 | AUCUNE dans le flux |
| `DDD_105` | 105 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_111` | 111 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_111` | 111 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:14:00 | 73 | 17.0–25.0 | AUCUNE dans le flux |
| `DDD_111` | 111 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_121` | 121 | `DIMANCHE` | dim | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_121` | 121 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:14:00 | 73 | 17.0–25.0 | AUCUNE dans le flux |
| `DDD_121` | 121 | `SAMEDI` | sam | 06:30:00 | 21:20:00 | 76 | 20.0 | AUCUNE dans le flux |
| `DDD_208` | 208 | `DIMANCHE` | dim | 07:00:00 | 22:00:00 | 62 | 30.0 | AUCUNE dans le flux |
| `DDD_208` | 208 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 20:05:00 | 54 | 32.5 | AUCUNE dans le flux |
| `DDD_208` | 208 | `SAMEDI` | sam | 06:00:00 | 20:05:00 | 54 | 32.5 | AUCUNE dans le flux |
| `DDD_210` | 210 | `DIMANCHE` | dim | 07:00:00 | 20:45:00 | 49 | 35.0–37.5 | AUCUNE dans le flux |
| `DDD_210` | 210 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:20:00 | 58 | 30.0 | AUCUNE dans le flux |
| `DDD_210` | 210 | `SAMEDI` | sam | 06:00:00 | 20:20:00 | 54 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_213` | 213 | `DIMANCHE` | dim | 07:00:00 | 20:45:00 | 49 | 35.0–37.5 | AUCUNE dans le flux |
| `DDD_213` | 213 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:20:00 | 58 | 30.0 | AUCUNE dans le flux |
| `DDD_213` | 213 | `SAMEDI` | sam | 06:00:00 | 20:20:00 | 54 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_217` | 217 | `DIMANCHE` | dim | 06:30:00 | 20:50:00 | 52 | 30.0 | AUCUNE dans le flux |
| `DDD_217` | 217 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:00:00 | 69 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_217` | 217 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 67 | 25.0 | AUCUNE dans le flux |
| `DDD_218` | 218 | `DIMANCHE` | dim | 06:00:00 | 20:30:00 | 51 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_218` | 218 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 20:20:00 | 51 | 25.0–40.0 | AUCUNE dans le flux |
| `DDD_218` | 218 | `SAMEDI` | sam | 06:00:00 | 20:30:00 | 51 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_219` | 219 | `DIMANCHE` | dim | 06:30:00 | 20:50:00 | 52 | 30.0 | AUCUNE dans le flux |
| `DDD_219` | 219 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:00:00 | 69 | 20.0–25.0 | AUCUNE dans le flux |
| `DDD_219` | 219 | `SAMEDI` | sam | 06:00:00 | 21:25:00 | 67 | 25.0 | AUCUNE dans le flux |
| `DDD_220` | 220 | `DIMANCHE` | dim | 06:30:00 | 20:50:00 | 52 | 30.0 | AUCUNE dans le flux |
| `DDD_220` | 220 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 20:55:00 | 52 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_220` | 220 | `SAMEDI` | sam | 06:00:00 | 20:55:00 | 52 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_221` | 221 | `DIMANCHE` | dim | 06:30:00 | 20:50:00 | 50 | 30.0–35.0 | AUCUNE dans le flux |
| `DDD_221` | 221 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:05:00 | 56 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_221` | 221 | `SAMEDI` | sam | 06:30:00 | 20:55:00 | 53 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_223` | 223 | `DIMANCHE` | dim | 06:30:00 | 20:45:00 | 41 | 35.0–47.5 | AUCUNE dans le flux |
| `DDD_223` | 223 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:00:00 | 45 | 30.0–45.0 | AUCUNE dans le flux |
| `DDD_223` | 223 | `SAMEDI` | sam | 06:30:00 | 20:45:00 | 43 | 37.5–45.0 | AUCUNE dans le flux |
| `DDD_227` | 227 | `DIMANCHE` | dim | 06:30:00 | 21:05:00 | 66 | 25.0 | AUCUNE dans le flux |
| `DDD_227` | 227 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 20:50:00 | 60 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_227` | 227 | `SAMEDI` | sam | 06:30:00 | 20:55:00 | 55 | 25.0–30.0 | AUCUNE dans le flux |
| `DDD_228` | 228 | `DIMANCHE` | dim | 06:30:00 | 20:40:00 | 36 | 50.0 | AUCUNE dans le flux |
| `DDD_228` | 228 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:20:00 | 41 | 40.0–50.0 | AUCUNE dans le flux |
| `DDD_228` | 228 | `SAMEDI` | sam | 06:30:00 | 20:40:00 | 36 | 50.0 | AUCUNE dans le flux |
| `DDD_231` | 231 | `DIMANCHE` | dim | 07:00:00 | 20:45:00 | 49 | 35.0–37.5 | AUCUNE dans le flux |
| `DDD_231` | 231 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:20:00 | 58 | 30.0 | AUCUNE dans le flux |
| `DDD_231` | 231 | `SAMEDI` | sam | 06:00:00 | 20:20:00 | 54 | 25.0–35.0 | AUCUNE dans le flux |
| `DDD_232` | 232 | `DIMANCHE` | dim | 06:30:00 | 20:40:00 | 43 | 37.5–40.0 | AUCUNE dans le flux |
| `DDD_232` | 232 | `LAV` | lun/mar/mer/jeu/ven | 06:20:00 | 20:10:00 | 50 | 25.0–37.5 | AUCUNE dans le flux |
| `DDD_232` | 232 | `SAMEDI` | sam | 06:30:00 | 20:40:00 | 43 | 37.5–40.0 | AUCUNE dans le flux |
| `DDD_233` | 233 | `DIMANCHE` | dim | 06:30:00 | 20:45:00 | 41 | 35.0–47.5 | AUCUNE dans le flux |
| `DDD_233` | 233 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 21:00:00 | 45 | 30.0–45.0 | AUCUNE dans le flux |
| `DDD_233` | 233 | `SAMEDI` | sam | 06:30:00 | 20:45:00 | 43 | 37.5–45.0 | AUCUNE dans le flux |
| `DDD_234` | 234 | `DIMANCHE` | dim | 06:30:00 | 21:35:00 | 44 | 35.0–45.0 | AUCUNE dans le flux |
| `DDD_234` | 234 | `LAV` | lun/mar/mer/jeu/ven | 05:30:00 | 21:30:00 | 49 | 30.0–45.0 | AUCUNE dans le flux |
| `DDD_234` | 234 | `SAMEDI` | sam | 06:00:00 | 21:45:00 | 45 | 35.0–45.0 | AUCUNE dans le flux |
| `DDD_301` | 301 | `DIMANCHE` | dim | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_301` | 301 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_301` | 301 | `SAMEDI` | sam | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_305` | 305 | `DIMANCHE` | dim | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_305` | 305 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_305` | 305 | `SAMEDI` | sam | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_308` | 308 | `DIMANCHE` | dim | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_308` | 308 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_308` | 308 | `SAMEDI` | sam | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_311` | 311 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 20:50:00 | 41 | 20.0 | AUCUNE dans le flux |
| `DDD_315` | 315 | `DIMANCHE` | dim | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_315` | 315 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_315` | 315 | `SAMEDI` | sam | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_319` | 319 | `DIMANCHE` | dim | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_319` | 319 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_319` | 319 | `SAMEDI` | sam | 06:30:00 | 19:07:00 | 96 | 17.0 | AUCUNE dans le flux |
| `DDD_401` | 401 | `DIMANCHE` | dim | 08:00:00 | 21:30:00 | 20 | 60.0–120.0 | AUCUNE dans le flux |
| `DDD_401` | 401 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 20:30:00 | 18 | 105.0 | AUCUNE dans le flux |
| `DDD_401` | 401 | `SAMEDI` | sam | 06:00:00 | 21:30:00 | 20 | 90.0 | AUCUNE dans le flux |
| `DDD_402` | 402 | `DIMANCHE` | dim | 07:00:00 | 21:10:00 | 42 | 42.5 | AUCUNE dans le flux |
| `DDD_402` | 402 | `LAV` | lun/mar/mer/jeu/ven | 05:45:00 | 20:35:00 | 65 | 15.0–35.0 | AUCUNE dans le flux |
| `DDD_402` | 402 | `SAMEDI` | sam | 06:30:00 | 20:40:00 | 40 | 40.0 | AUCUNE dans le flux |
| `DDD_403` | 403 | `DIMANCHE` | dim | 07:00:00 | 22:00:00 | 27 | 60.0–90.0 | AUCUNE dans le flux |
| `DDD_403` | 403 | `LAV` | lun/mar/mer/jeu/ven | 06:50:00 | 21:50:00 | 20 | 90.0–105.0 | AUCUNE dans le flux |
| `DDD_403` | 403 | `SAMEDI` | sam | 06:50:00 | 21:50:00 | 22 | 90.0 | AUCUNE dans le flux |
| `DDD_404` | 404 | `DIMANCHE` | dim | 07:00:00 | 21:25:00 | 32 | 60.0 | AUCUNE dans le flux |
| `DDD_404` | 404 | `LAV` | lun/mar/mer/jeu/ven | 06:30:00 | 21:10:00 | 28 | 60.0 | AUCUNE dans le flux |
| `DDD_404` | 404 | `SAMEDI` | sam | 06:40:00 | 21:40:00 | 28 | 60.0 | AUCUNE dans le flux |
| `DDD_405` | 405 | `DIMANCHE` | dim | 07:00:00 | 21:45:00 | 36 | 45.0 | AUCUNE dans le flux |
| `DDD_405` | 405 | `LAV` | lun/mar/mer/jeu/ven | 05:45:00 | 20:45:00 | 30 | 45.0–75.0 | AUCUNE dans le flux |
| `DDD_405` | 405 | `SAMEDI` | sam | 06:00:00 | 20:30:00 | 24 | 70.0 | AUCUNE dans le flux |
| `DDD_501` | 501 | `DIMANCHE` | dim | 06:40:00 | 23:00:00 | 100 | 20.0 | AUCUNE dans le flux |
| `DDD_501` | 501 | `LAV` | lun/mar/mer/jeu/ven | 06:40:00 | 23:00:00 | 100 | 20.0 | AUCUNE dans le flux |
| `DDD_501` | 501 | `SAMEDI` | sam | 06:40:00 | 23:00:00 | 100 | 20.0 | AUCUNE dans le flux |
| `DDD_502` | 502 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 23:00:00 | 52 | 20.0 | AUCUNE dans le flux |
| `DDD_503` | 503 | `LAV` | lun/mar/mer/jeu/ven | 06:00:00 | 23:00:00 | 52 | 20.0 | AUCUNE dans le flux |
| `DDD_504` | 504 | `DIMANCHE` | dim | 05:45:00 | 22:55:00 | 100 | 20.0 | AUCUNE dans le flux |
| `DDD_504` | 504 | `LAV` | lun/mar/mer/jeu/ven | 05:45:00 | 22:55:00 | 100 | 20.0 | AUCUNE dans le flux |
| `DDD_504` | 504 | `SAMEDI` | sam | 05:45:00 | 22:55:00 | 100 | 20.0 | AUCUNE dans le flux |

### H.3 BRT (services = listes de dates 2024-10-24 → 2024-12-31 ; `1_7` = 12 dates supplémentaires B1)

| route_id | n° (champ flux) | service_id | jours de service | premier départ | dernier départ | trips horodatés (tous sens) | fréq. observée médiane (min, par sens) | fréq. déclarée |
|---|---|---|---|---|---|---|---|---|
| `B2` | B2 | `0_1` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B2` | B2 | `0_2` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B2` | B2 | `0_3` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B2` | B2 | `0_4` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B2` | B2 | `0_5` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B2` | B2 | `0_6` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:03:30 | 20:57:30 | 289 | 6.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_1` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_2` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_3` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_4` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_5` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `0_6` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 21:00:30 | 345 | 6.0–8.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |
| `B1` | B1 | `1_7` | dates énumérées dans calendar_dates (2024-10-24 → 2024-12-31) | 06:00:30 | 20:55:30 | 232 | 7.0 | 6 min (déclaré par la page CETUD BRT, hors flux) |

### H.4 TER (12 services UUID, 2025-08-18 → 2025-08-31)

| route_id | n° (champ flux) | service_id | jours de service | premier départ | dernier départ | trips horodatés (tous sens) | fréq. observée médiane (min, par sens) | fréq. déclarée |
|---|---|---|---|---|---|---|---|---|
| `20001` | 20001 | `1ed51a8d…` | dim | 06:25:00 | 22:05:00 | 51 | 20.0 | AUCUNE dans le flux |
| `20001` | 20001 | `38f23463…` | lun/mar/mer/jeu/ven/sam | 05:30:00 | 22:06:00 | 79 | 12.0 | AUCUNE dans le flux |
| `20001` | 20001 | `4cd85026…` | sam | 11:00:00 | 11:00:00 | 1 | — | AUCUNE dans le flux |
| `20001` | 20001 | `4db2746d…` | jeu/ven | 06:18:00 | 06:47:06 | 2 | 29.1 | AUCUNE dans le flux |
| `20001` | 20001 | `68f0b070…` | lun/mar/mer/jeu/ven | 06:35:00 | 06:47:06 | 2 | 12.1 | AUCUNE dans le flux |
| `20001` | 20001 | `75be6f61…` | ven/sam | 20:06:00 | 20:30:00 | 2 | 24.0 | AUCUNE dans le flux |
| `20001` | 20001 | `8a62eb4e…` | mer/jeu/ven/sam | 06:30:14 | 22:06:00 | 69 | 12.0 | AUCUNE dans le flux |
| `20001` | 20001 | `ac8d71e0…` | mer/jeu/ven | 05:29:59 | 06:35:18 | 5 | 12.3 | AUCUNE dans le flux |
| `20001` | 20001 | `cec3ed22…` | jeu/ven/sam | 06:54:00 | 11:30:00 | 5 | 72.0 | AUCUNE dans le flux |
| `20001` | 20001 | `d8799802…` | sam | 11:00:00 | 11:00:00 | 1 | — | AUCUNE dans le flux |
| `20001` | 20001 | `db5eb1cc…` | dim | 06:25:00 | 22:05:00 | 51 | 20.0 | AUCUNE dans le flux |
| `20001` | 20001 | `fa54f07d…` | ven/sam | 20:06:00 | 20:30:00 | 2 | 24.0 | AUCUNE dans le flux |
| `10001` | 10001 | `1ed51a8d…` | dim | 06:25:00 | 22:05:00 | 50 | 20.0 | AUCUNE dans le flux |
| `10001` | 10001 | `38f23463…` | lun/mar/mer/jeu/ven/sam | 05:30:00 | 22:06:00 | 81 | 12.0 | AUCUNE dans le flux |
| `10001` | 10001 | `4db2746d…` | jeu/ven | 05:54:00 | 06:18:00 | 3 | 12.0 | AUCUNE dans le flux |
| `10001` | 10001 | `8a62eb4e…` | mer/jeu/ven/sam | 06:30:35 | 22:06:00 | 60 | 12.0 | AUCUNE dans le flux |
| `10001` | 10001 | `ac8d71e0…` | mer/jeu/ven | 05:30:40 | 05:42:30 | 2 | 11.8 | AUCUNE dans le flux |
| `10001` | 10001 | `cec3ed22…` | jeu/ven/sam | 06:42:00 | 14:30:00 | 16 | 24.0 | AUCUNE dans le flux |
| `10001` | 10001 | `db5eb1cc…` | dim | 06:25:00 | 22:05:00 | 50 | 20.0 | AUCUNE dans le flux |
| `20922` | 20922 | `68f0b070…` | lun/mar/mer/jeu/ven | 08:08:48 | 09:20:00 | 2 | 71.2 | AUCUNE dans le flux |
| `20922` | 20922 | `ac8d71e0…` | mer/jeu/ven | 08:08:31 | 09:20:00 | 2 | 71.5 | AUCUNE dans le flux |
| `23001` | 23001 | `68f0b070…` | lun/mar/mer/jeu/ven | 08:44:27 | 21:37:11 | 8 | 97.5 | AUCUNE dans le flux |
| `23001` | 23001 | `ac8d71e0…` | mer/jeu/ven | 08:44:27 | 21:37:11 | 8 | 97.5 | AUCUNE dans le flux |
| `14922` | 14922 | `4db2746d…` | jeu/ven | 07:35:00 | 07:35:00 | 1 | — | AUCUNE dans le flux |
| `14922` | 14922 | `68f0b070…` | lun/mar/mer/jeu/ven | 07:35:00 | 08:47:02 | 2 | 72.0 | AUCUNE dans le flux |
| `14922` | 14922 | `ac8d71e0…` | mer/jeu/ven | 08:47:02 | 08:47:02 | 1 | — | AUCUNE dans le flux |
| `13005` | 13005 | `4db2746d…` | jeu/ven | 07:47:00 | 07:47:00 | 1 | — | AUCUNE dans le flux |
| `13005` | 13005 | `68f0b070…` | lun/mar/mer/jeu/ven | 07:47:00 | 20:45:00 | 8 | 105.0 | AUCUNE dans le flux |
| `13005` | 13005 | `ac8d71e0…` | mer/jeu/ven | 09:35:00 | 20:45:00 | 7 | 89.0 | AUCUNE dans le flux |

---

## I. COMPARAISON CETUD ↔ PassBi ↔ Dakar Bus

### I.1 Méthode et limites

- **Clé de comparaison : le numéro de ligne porté par le champ source** (`route_short_name`/`route_id`/`route_long_name` du flux ; libellé officiel `aftu-senegal.org` / `demdikk.sn` du 2026-09-25 ; `short_name` « AFTU n » / « DDD n » de Dakar Bus). Aucune identité n'a été résolue par OSM, Moovit, un identifiant interne ou un rapprochement géométrique.
- Pour un **même numéro**, les terminus sont comparés par **jetons de libellés** (normalisation, préfixe ≥ 4, similarité ≥ 0,8, mots génériques exclus). Cette comparaison est **indicative** : elle signale une cohérence ou une contradiction, elle ne crée pas d'identité. Statuts (vocabulaire imposé) : **MATCH** (numéro identique et tous les terminus concordants) · **MISMATCH** (numéro identique, terminus non ou partiellement concordants) · **MISSING_IN_DAKAR_BUS** · **MISSING_IN_SOURCE** · **UNKNOWN**.
- **Aucun GTFS CETUD n'existe** : la colonne « CETUD » de la comparaison se réduit aux chiffres publiés (« 72 lignes » AFTU, « 38 lignes » DDD) et aux étiquettes de la carte DDD. La comparaison « source » utilise donc le flux **PassBi (SOURCE_APPLICATION, 2022-2023)** et, en contrôle, la **liste officielle des exploitants (2026-09-25)**.
- **Arrêts et ordre des arrêts : UNKNOWN pour toutes les lignes.** Dakar Bus décrit 3 à 5 arrêts (coordonnées `UNVERIFIED`/`CONFLICTING`) là où le flux en horodate 30 à 90 par sens ; aucun rapprochement géométrique n'a été effectué (interdit pour l'identité, et sans valeur sur des coordonnées non vérifiées).
- **Horaires : MISSING_IN_DAKAR_BUS pour toutes les lignes** (`schedule_status = UNKNOWN` partout dans Dakar Bus), mais les horaires source sont **HISTORICAL** — ils ne peuvent pas être présentés comme « prochain départ » 2026.

### I.2 Résultat global

| Comparaison | MATCH | MISMATCH | MISSING_IN_DAKAR_BUS | MISSING_IN_SOURCE | UNKNOWN | Total clés |
|---|---|---|---|---|---|---|
| **AFTU** — PassBi GTFS → Dakar Bus (80 lignes internes « AFTU 1…72 » + « NEW »/« Tata » hors clé) | **0** | **54** (n° 1–5, 24–72 : numéro commun, terminus différents) | **19** (n° 73–91 absents de Dakar Bus) | **18** (n° 6–23 : n'existent ni dans le flux ni dans la liste officielle) | 0 | 91 |
| **AFTU** — PassBi GTFS ↔ liste officielle `aftu-senegal.org` 2026 | 49 | 23 (23 cas « 1/2 terminus » ou 0/2 : n° 27, 29, 31, 32, 36, 38, 41, 43, 48, 52, 54, 61, 64, 65, 69, 74, 77, 79, 81, 85, 86, 88, 89) | — | 0 | 18 (n° 6–23 : dans aucune des deux) + 1 `MISSING_IN_OFFICIAL_LIST` (n° 90) | 91 |
| **DDD** — PassBi GTFS → Dakar Bus (15 lignes internes « DDD n ») | **0** | **10** (n° 1, 7, 8, 9, 10, 11, 12, 15, 20, 23) | **43** | **2** (n° 3, 14 : dans aucune source) | 14 (identifiants officiels à suffixe/TAF TAF absents du flux et de Dakar Bus) | 69 |
| **DDD** — PassBi GTFS ↔ liste officielle `demdikk.sn` 2026 | 33 | 1 (n° 311) | 19 `MISSING_IN_OFFICIAL_LIST` (16, 102, 103, 105, 111, 210, 223, 231, 301, 305, 308, 315, 323, 401–405, 504) | 14 (15A, 15B, 16A, 16B, 327, 502A/B, 503A/B, 504A/B, TAF, TAF TAF, TO1) | 2 | 69 |
| **CETUD (chiffres publiés) ↔ PassBi** | AFTU : CETUD « 72 lignes » vs flux **73** (n° 90 en plus) · DDD : CETUD « 38 lignes » vs flux **53** · carte CETUD/DDD : 28 étiquettes lues, toutes de la forme `DDD_xxx`/`DDD_Nxxx`, dont `DDD_16A` (le flux a `DDD_16`) et `DDD_N305/N308/N311/N315/N319` (le flux a `DDD_305/308/311/315/319`) — correspondance **UNKNOWN** | | | | | |

Lecture : le flux PassBi AFTU est **cohérent avec la numérotation officielle 2026** (mêmes trous 6–23, mêmes numéros 24–89/91 ; 49 lignes avec terminus concordants) — ce qui corrobore sa nature de réseau AFTU réel de 2022-2023 — tandis que la numérotation interne de Dakar Bus « AFTU 1…72 » **ne correspond à aucune source** (les n° 6–23 n'existent pas, et les n° 24–72 de Dakar Bus désignent d'autres terminus que ceux du flux et de la liste officielle). Pour DDD, le flux 2022-2023 diffère de la liste 2026 (19 numéros disparus, 14 apparus) : **évolution du réseau non documentée** → le flux ne peut pas servir de référentiel 2026.

### I.3 AFTU — détail par numéro

| n° | PassBi GTFS 2022-2023 (route_id — route_long_name) | liste officielle exploitant 2026-09-25 | Dakar Bus (`id` — `long_name`) | **PassBi → Dakar Bus** | détail | PassBi ↔ officiel | officiel ↔ Dakar Bus |
|---|---|---|---|---|---|---|---|
| 1 | `AFTU_1` — AFTU_1_HLM-GR-YOFF_LAT-DIOR | LAT DIOR- HLM GRAND YOFF | `aftu_1` — Parcelles Assainies ↔ Sandaga (AFTU Ligne 1) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 2 | `AFTU_2` — AFTU_2_Parcelles-Assainies_Petersen | ROUTE PRINCIPALE PARCELLES - PETERSEN | `aftu_2` — Guédiawaye ↔ Sandaga (AFTU Ligne 2 Express) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 3 | `AFTU_3` — AFTU_3_Petersen_Yoff | YOFF - PETERSEN | `aftu_3` — Marché Sandaga ↔ Hôpital Dalal Jamm (AFTU Ligne 3) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 4 | `AFTU_4` — AFTU_4_Petersen_Yoff | YOFF VILLAGE - PETERSEN | `aftu_4` — Gare TER Dakar ↔ Cambérène (AFTU Ligne 4) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 5 | `AFTU_5` — AFTU_5_Parcelles-Assainies_Petersen | PARCELLES ASSAINIES- PETERSEN | `aftu_5` — Keur Massar ↔ Petersen (AFTU Ligne 5) | **MISMATCH** | numéro identique mais 1/2 terminus concordant(s) seulement | MATCH | MISMATCH |
| 6 | — | — | `aftu_6` — Hôpital Dalal Jamm ↔ Liberté 6 (AFTU Ligne 6) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 7 | — | — | `aftu_7` — Keur Mbaye Fall ↔ Hôpital Dalal Jamm (AFTU Ligne 7) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 8 | — | — | `aftu_8` — Yoff ↔ Petersen via Patte d'Oie (AFTU Ligne 8) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 9 | — | — | `aftu_9` — Fadia ↔ Mermoz (AFTU Ligne 9) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 10 | — | — | `aftu_10` — Gare Maritime ↔ Grand Yoff (AFTU Ligne 10) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 11 | — | — | `aftu_11` — Grand Yoff ↔ Petersen Centre (AFTU Ligne 11) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 12 | — | — | `aftu_12` — Guédiawaye ↔ Palais de Justice (AFTU Ligne 12) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 13 | — | — | `aftu_13` — Fadia ↔ Sacré-Cœur (AFTU Ligne 13) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 14 | — | — | `aftu_14` — Ngor ↔ UCAD (AFTU Ligne 14) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 15 | — | — | `aftu_15` — Parcelles ↔ Rufisque (AFTU Ligne 15) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 16 | — | — | `aftu_16` — Palais de Justice ↔ Pikine (AFTU Ligne 16) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 17 | — | — | `aftu_17` — HLM Grand Yoff ↔ Cambérène (AFTU Ligne 17) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 18 | — | — | `aftu_18` — Pikine ↔ UCAD (AFTU Ligne 18 Universitaire) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 19 | — | — | `aftu_19` — Keur Mbaye Fall ↔ Mermoz (AFTU Ligne 19) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 20 | — | — | `aftu_20` — Baux Maraîchers ↔ Gare TER Dakar (AFTU Ligne 20) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 21 | — | — | `aftu_21` — Thiaroye ↔ Petersen (AFTU Ligne 21) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 22 | — | — | `aftu_22` — Médina ↔ Yeumbeul (AFTU Ligne 22) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 23 | — | — | `aftu_23` — Point E ↔ PEM Petersen (AFTU Ligne 23) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 24 | `AFTU_24` — AFTU_24_Notaire_UCAD | UCAD - NOTAIRE GUEDIAWAYE | `aftu_24` — Castor ↔ Yoff via Hann (AFTU Ligne 24) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 25 | `AFTU_25` — AFTU_25_Parcelle-Assainies_Petersen | PARCELLES ASSAINIES - PETERSEN | `aftu_25` — Hôpital Dalal Jamm ↔ Place de l'Obélisque (AFTU Ligne 25) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 26 | `AFTU_26` — AFTU_26_Parcelle-Assainies_Poste-Thiaroye | PARCELLES ASSAINIES - POST THIAROYE | `aftu_26` — Scat Urbam ↔ Yoff Pêcheurs (AFTU Ligne 26) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 27 | `AFTU_27` — AFTU_27_Guediawaye | MARCHE BOUBESS - PETERSEN | `aftu_27` — Médina ↔ Yoff (AFTU Ligne 27) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 28 | `AFTU_28` — AFTU_28_Hamo | HAMO V/VI - PETERSEN | `aftu_28` — Patte d'Oie ↔ Hôpital Dalal Jamm (AFTU Ligne 28) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 29 | `AFTU_29` — AFTU_29_Malibu_Petersen | CITE NATION UNIES (CAMBERENE) - PETERSEN | `aftu_29` — Thiaroye ↔ Yeumbeul (AFTU Ligne 29) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 30 | `AFTU_30` — AFTU_30_Colobane_Gadaye | GADAYE (GUEDIEWAYE) - GARE DE COLOBANE | `aftu_30` — Patte d'Oie ↔ Petersen (AFTU Ligne 30) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 31 | `AFTU_31` — AFTU_31_Sham_Thiaroye-kao | TALLY ICOTAF X ROUTE DES NIAYES - HOPITAL ABASS NDAO | `aftu_31` — Gare TER Dakar ↔ Colobane (AFTU Ligne 31) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 32 | `AFTU_32` — AFTU_32_Daroukhane_Sham | SAHM - SERIGNE ASSANE | `aftu_32` — Hann ↔ Keur Mbaye Fall (AFTU Ligne 32) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 33 | `AFTU_33` — AFTU_33_Colobane_Daroukane | COLOBANE - SERIGNE ASSANE | `aftu_33` — Ouakam ↔ Parcelles (AFTU Ligne 33) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 34 | `AFTU_34` — AFTU_34_LAT-DIOR_Nord-Foire | NORD FOIRE - LAT DIOR | `aftu_34` — Fadia ↔ Gare TER Dakar (AFTU Ligne 34) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 35 | `AFTU_35` — AFTU_35_Ngor_Pikine-Texaco | NGOR - PIKINE TEXACO | `aftu_35` — HLM ↔ Petersen via Castor (AFTU Ligne 35) | **MISMATCH** | numéro identique mais aucun terminus concordant (1 comparés) | MATCH | MISMATCH |
| 36 | `AFTU_36` — AFTU_36_Daroukhane_Ngor | MARCHE NDIAREME - NGOR | `aftu_36` — HLM Grand Yoff ↔ Yeumbeul (AFTU Ligne 36) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 37 | `AFTU_37` — AFTU_37_APIX_UCAD | CITÉ APIX - UCAD (CLAUDEL) | `aftu_37` — Keur Mbaye Fall ↔ Yoff (AFTU Ligne 37) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 38 | `AFTU_38` — AFTU_38_Guediawaye_Sahm | CITE DES ENSEIGNANTS - SHAM | `aftu_38` — Mermoz ↔ Keur Massar (AFTU Ligne 38) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 39 | `AFTU_39` — AFTU_39_Diamalaye_Lat | LAT-DIOR - DIAMALAYE | `aftu_39` — Colobane ↔ Fadia (AFTU Ligne 39) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 40 | `AFTU_40` — AFTU_40_Mbao_Petersen | GRAND MBAO - PETERSEN | `aftu_40` — Bené Barak ↔ Sandaga (AFTU Ligne 40) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 41 | `AFTU_41` — AFTU_41_Guediawaye_Petersen | PETERSEN - ETAGE MADIALE | `aftu_41` — Hann ↔ Diamniadio (AFTU Ligne 41) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 42 | `AFTU_42` — AFTU_42_Gadaye_Ouakam | GADAYE (GUEDIEWAYE) - OUAKAM BAYE | `aftu_42` — Fadia ↔ Thiaroye (AFTU Ligne 42) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 43 | `AFTU_43` — AFTU_43_Comico_Ouakam | OUAKAM - THIERNO NDIAYE | `aftu_43` — Yeumbeul ↔ Thiaroye (AFTU Ligne 43) | **MISMATCH** | numéro identique mais 1/2 terminus concordant(s) seulement | MISMATCH | MISMATCH |
| 44 | `AFTU_44` — AFTU_44_Mbao_Ouakam | GRAND MBAO - OUAKAM | `aftu_44` — Yeumbeul ↔ Keur Mbaye Fall (AFTU Ligne 44) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 45 | `AFTU_45` — AFTU_45_kounoune_Parcelles | KOUNOUNE NGALAM - PARCELLES EGLISE | `aftu_45` — Scat Urbam ↔ Colobane (AFTU Ligne 45) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 46 | `AFTU_46` — AFTU_46_Guediawaye_Lat | SDE SERIGNE ASSANE - LAT DIOR | `aftu_46` — Cambérène ↔ Ngor (AFTU Ligne 46) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 47 | `AFTU_47` — AFTU_47_Lat | LAT DIOR - ALMADIES | `aftu_47` — Hôpital Dalal Jamm ↔ Médina (AFTU Ligne 47) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 48 | `AFTU_48` — AFTU_48_Lat | CITE SERIGNE MANSOUR - LAT DIOR | `aftu_48` — Ouakam ↔ Ngor (AFTU Ligne 48) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 49 | `AFTU_49` — AFTU_49_Gadaye_Ngor | GADAYE - NGOR | `aftu_49` — Médina ↔ UCAD (AFTU Ligne 49) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 50 | `AFTU_50` — AFTU_50_Malicka_Petersen | PETERSEN - MALIKA CIMETIERE | `aftu_50` — Yeumbeul ↔ Médina (AFTU Ligne 50) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 51 | `AFTU_51` — AFTU_51_Baux | JAXAAY - GARE DES BAUX MARAICHERS | `aftu_51` — Scat Urbam ↔ PEM Guédiawaye (AFTU Ligne 51) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 52 | `AFTU_52` — AFTU_52_Baux | BOUNTOU PIKINE - KEUR MASSAR | `aftu_52` — Ngor ↔ Sandaga via Ouakam (AFTU Ligne 52) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 53 | `AFTU_53` — AFTU_53_KEUR | KEUR MASSAR - SEBIKOTANE | `aftu_53` — Almadies ↔ Bené Barak (AFTU Ligne 53) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 54 | `AFTU_54` — AFTU_54_M | TERMINUS KEUR MASSAR (CITE MTOA) - UCAD | `aftu_54` — Thiaroye ↔ Hann (AFTU Ligne 54) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 55 | `AFTU_55` — AFTU_55_Petersen_Rufisque | TERMINUS RUFISQUE SONADIS - PETERSEN | `aftu_55` — Pikine ↔ Castor (AFTU Ligne 55) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 56 | `AFTU_56` — AFTU_56_Jaxaaye_Petersen | JAXAAY 2 - PETERSEN | `aftu_56` — Scat Urbam ↔ Place de l'Obélisque (AFTU Ligne 56) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 57 | `AFTU_57` — AFTU_57_LIBERTE | LIBERTE 6 - RUFISQUE | `aftu_57` — Grand Médine ↔ Hôpital Dalal Jamm (AFTU Ligne 57) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 58 | `AFTU_58` — AFTU_58_Comico_Sahm | SAHM - COMICO | `aftu_58` — Mermoz ↔ Gare TER Dakar (AFTU Ligne 58) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 59 | `AFTU_59` — AFTU_59_cite | DIAMALAYE - CITÉ GENDARMERIE (Jaxaay) | `aftu_59` — Gare TER Dakar ↔ Gare Maritime (AFTU Ligne 59) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 60 | `AFTU_60` — AFTU_60_bargny_Colobane | COLOBANE - BARGNY | `aftu_60` — Almadies ↔ Petersen (AFTU Ligne 60) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 61 | `AFTU_61` — AFTU_61_KEUR | ALMADIES - KEUR MASSAR | `aftu_61` — PEM Guédiawaye ↔ Yoff (AFTU Ligne 61) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 62 | `AFTU_62` — AFTU_62_gueule | ARRET CHERIF (RUFISQUE) - PENC MI (GUEULE TAPEE) | `aftu_62` — Hann ↔ PEM Guédiawaye (AFTU Ligne 62) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 63 | `AFTU_63` — AFTU_63_Stade-Amitié_Rufisque | TERMINUS CAMP MARCHAND RUFISQUE - STADE LSS | `aftu_63` — Scat Urbam ↔ Point E (AFTU Ligne 63) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 64 | `AFTU_64` — AFTU_64_diamniadio_guediawaye | GUEDIAWAYE - RUFISQUE | `aftu_64` — Castor ↔ Sacré-Cœur (AFTU Ligne 64) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 65 | `AFTU_65` — AFTU_65_Colobane_kounoune | COLOBANE - JAXAAY | `aftu_65` — Sacré-Cœur ↔ Guédiawaye (AFTU Ligne 65) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 66 | `AFTU_66` — AFTU_66_gorom_Yoff | YOFF - GOROM 1 | `aftu_66` — Mermoz ↔ Thiaroye (AFTU Ligne 66) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 67 | `AFTU_67` — AFTU_67_Ouakam_thiawlene | OUAKAM - THIAWLENE RUFISQUE | `aftu_67` — PEM Petersen ↔ Place de l'Obélisque (AFTU Ligne 67) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 68 | `AFTU_68` — AFTU_68_sebikotane_tally | YEUMBEUL - SEBIKOTANE | `aftu_68` — Grand Médine ↔ Bargny (AFTU Ligne 68) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 69 | `AFTU_69` — AFTU_69_Diamalaye_namora | DIAMALAYE - TERMINUS TIVAOUANE PEUL | `aftu_69` — Yeumbeul ↔ UCAD (AFTU Ligne 69) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MISMATCH | MISMATCH |
| 70 | `AFTU_70` — AFTU_70_darouhane_diaxaye | DAROUKHANE - JAXXAY 2 | `aftu_70` — Pikine ↔ Colobane (AFTU Ligne 70) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 71 | `AFTU_71` — AFTU_71_claudel_KEUR | KEUR MASSAR - CLAUDEL | `aftu_71` — Keur Mbaye Fall ↔ Colobane (AFTU Ligne 71) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 72 | `AFTU_72` — AFTU_72_kounoune_Guédiawaye | GUEDIAWAYE - KOUNOUNE | `aftu_72` — Yeumbeul ↔ Fadia (AFTU Ligne 72) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 73 | `AFTU_73` — AFTU_73_Lac | LAC ROSE - POSTE THIAROYE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 74 | `AFTU_74` — AFTU_74_bargny_SOCABECK | TERMINUS BARGNY (GARE FERROVIAIRE) - TIVAOUNE PEUL | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 75 | `AFTU_75` — AFTU_75_Colobane_MALIKA | TERMINUS MALIKA (CITE SONATEL) - TERMINUS GARE ROUTIERE COLOBANE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 76 | `AFTU_76` — AFTU_76_ASSURANCE_SIPRESS | SIPRES - CITE ASSURANCE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 77 | `AFTU_77` — AFTU_77_CITE | RUFISQUE - LIBERTE 5 | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 78 | `AFTU_78` — AFTU_78_DIAMAGUENE_LIBERTE | DIAMAGUENE - LIBERTE 5 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 79 | `AFTU_79` — AFTU_79_CAMBERENE2_gorom | SANGALKAM - CAMBERENE | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 80 | `AFTU_80` — AFTU_80_DAROU | DIAMALAYE - DAROU THIOUB | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 81 | `AFTU_81` — AFTU_81_BEAUX | BEAUX MARRAICHERS - TIVAOUNE PEUL | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 82 | `AFTU_82` — AFTU_82_CITE | LAT DIOR - COMICO YEUMBEUL | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 83 | `AFTU_83` — AFTU_83_ARAFAT_ZONE | RUFISQUE ARAFAT- ZONE DE CAPTAGE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 84 | `AFTU_84` — AFTU_84_Jaxaay_UCAD | UCAD - JAXAAY | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 85 | `AFTU_85` — AFTU_85_Lac | BANOBA - LIBERTE 5 | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 86 | `AFTU_86` — AFTU_86_THIAROYE_TOUBAB | TOURNALOU BOUNE - TOUBAB DIALAW | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 87 | `AFTU_87` — AFTU_87_BAMBIBOR | BAMBILOR - MOSQUEE MASSALIKOU DJINANE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 88 | `AFTU_88` — AFTU_88_KEUR | MTOA - LIBERTE 5 | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 89 | `AFTU_89` — AFTU_89_bargny_TAWFEKH | BARGNY - CROISEMENT NIAGUE (CITE SICAP) | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 90 | `AFTU_90` — AFTU_90_THOAROYE-AZUR_DENI | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 91 | `AFTU_91` — AFTU_91_APIX_DOUGAR | APIX - DOUGAR | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |

### I.4 DDD — détail par identifiant

| n° | PassBi GTFS 2022-2023 (route_id — route_long_name) | liste officielle exploitant 2026-09-25 | Dakar Bus (`id` — `long_name`) | **PassBi → Dakar Bus** | détail | PassBi ↔ officiel | officiel ↔ Dakar Bus |
|---|---|---|---|---|---|---|---|
| 1 | `DDD_01` — DDD_01_LECLERC_PARCELLES-ASSAINIES | PARCELLES ASSAINIES ↔ PLACE LECLERC | `ddd_1` — Colobane ↔ Yoff Pêcheurs (DDD Ligne 1) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 2 | `DDD_02` — DDD_02_DAROUKHANE_LECLERC | DAROUKHANE ↔ PLACE LECLERC | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 3 | — | — | `ddd_3` — Sandaga ↔ Ouakam / Ngor (DDD Ligne 3) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 4 | `DDD_04` — DDD_04_DIEUPPEUL_LECLERC | LIBERTÉ 5 ↔ PLACE LECLERC | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 5 | `DDD_05` — DDD_05_GUEDIAWAYE_PALAIS1 | GUÉDIAWAYE ↔ PALAIS 1 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 6 | `DDD_06` — DDD_06_CAMBERENE_PALAIS2 | CAMBÉRÈNE 2 ↔ PALAIS 2 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 7 | `DDD_07` — DDD_07_OUAKAM_PALAIS-02 | OUAKAM ↔ PALAIS 2 | `ddd_7` — HLM ↔ Yoff Almadies (DDD Ligne 7) | **MISMATCH** | numéro identique mais aucun terminus concordant (1 comparés) | MATCH | MISMATCH |
| 8 | `DDD_08` — DDD_08_AEROPORT-LSS_PALAIS-02 | AÉROPORT LSS ↔ PALAIS 2 | `ddd_8` — Aéroport Yoff ↔ Sandaga Centre (DDD Ligne 8) | **MISMATCH** | numéro identique mais 1/2 terminus concordant(s) seulement | MATCH | MISMATCH |
| 9 | `DDD_09` — DDD_09_LIBERTE-06_PALAIS-02 | LIBERTÉ 6 ↔ PALAIS 2 | `ddd_9` — Parcelles ↔ Almadies via Ngor (DDD Ligne 9) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 10 | `DDD_10` — DDD_10_LIBERTE | LIBERTÉ 5 ↔ PALAIS 2 | `ddd_10` — Liberté 6 ↔ Patte d'Oie ↔ Parcelles (DDD Ligne 10) | **MISMATCH** | numéro identique mais 1/3 terminus concordant(s) seulement | MATCH | MISMATCH |
| 11 | `DDD_11` — DDD_11_KEUR | KEUR MASSAR ↔ LAT DIOR | `ddd_11` — UCAD ↔ Parcelles Assainies (DDD Ligne 11) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 12 | `DDD_12` — DDD_12_Guediawaye_Palais-1 | GUÉDIAWAYE ↔ PALAIS 1 | `ddd_12` — Guédiawaye ↔ Parcelles Express (DDD Ligne 12) | **MISMATCH** | numéro identique mais 1/2 terminus concordant(s) seulement | MATCH | MISMATCH |
| 13 | `DDD_13` — DDD_13_PALAIS-02_TERMINUS-DIEUPPEUL | LIBERTÉ 5 ↔ PALAIS 2 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 14 | — | — | `ddd_14` — Gare Maritime ↔ UCAD (DDD Ligne 14 Plateau) | **MISSING_IN_SOURCE** |  | UNKNOWN | MISSING_IN_SOURCE |
| 15 | `DDD_15` — DDD_15_PALAIS1_RUFISQUE | RUFISQUE <--> PALAIS 1 | `ddd_15` — Ouakam ↔ Colobane via Mermoz (DDD Ligne 15) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 15A | — | RUFISQUE ↔ PALAIS 1 | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 15 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 15B | — | RUFISQUE ↔ PALAIS 1 | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 15 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 16 | `DDD_16` — DDD_16_MALIKA_PALAIS1 | — | — | **MISSING_IN_DAKAR_BUS** | numéro présent dans le flux PassBi (2022-2023) mais absent de la liste officielle 2026-09-25 ; la liste officielle publie les variantes 16A, 16B — correspondance UNKNOWN | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 16A | — | MALIKA ↔ PALAIS 1 | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 16 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 16B | — | MALIKA ↔ PALAIS 1 | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 16 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 18 | `DDD_18` — DDD_18_DIEUPEUL | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 20 | `DDD_20` — DDD_20_DIEUPEUL | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | `ddd_20` — Petersen ↔ Rufisque (DDD Ligne 20 Interurbain) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 23 | `DDD_23` — DDD_23_PALAIS-2_PARCELLE-ASSAINIES | PARCELLES ASSAINIES ↔ PALAIS 1 | `ddd_23` — Sandaga ↔ Keur Massar (DDD Ligne 23) | **MISMATCH** | numéro identique mais aucun terminus concordant (2 comparés) | MATCH | MISMATCH |
| 102 | `DDD_102` — DDD_102_CAMBERENE_COLOBANE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 103 | `DDD_103` — DDD_103_AEROPORT_COLOBANE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 105 | `DDD_105` — DDD_105_CAMBERENE_PETERSEN | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 111 | `DDD_111` — DDD_111_LECLERC_YOFF | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 121 | `DDD_121` — DDD_121_LECLERC_SCAT | SCAT URBAM ↔ LECLERC | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 208 | `DDD_208` — DDD_208_BAYAKH_RUFISQUE | BAYAKH ↔ RUFISQUE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 210 | `DDD_210` — DDD_210_BAUX-MARAICHERS_TIVAOUNE-PEULH | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 213 | `DDD_213` — DDD_213_DIEUPPEUL_RUFISQUE | RUFISQUE ↔ DIEUPPEUL | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 217 | `DDD_217` — DDD_217_OUAKAM_THIAROYE | THIAROYE ↔ OUAKAM | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 218 | `DDD_218` — DDD_218_AEROPORT-LSS_THIAROYE | THIAROYE ↔ AÉROPORT LSS | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 219 | `DDD_219` — DDD_219_DAROUKHANE_OUAKAM | DAROUKHANE ↔ OUAKAM | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 220 | `DDD_220` — DDD_220_DAROUKHANE_RUFISQUE | RUFISQUE ↔ GUÉDIAWAYE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 221 | `DDD_221` — DDD_221_ALMADIES_GADAYE | GADAYE ↔ ALMADIES | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 223 | `DDD_223` — DDD_223_DAROUKHANE_PETERSEN | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 227 | `DDD_227` — DDD_227_KEUR-MASSAR_TERMINUS-PARCELLES | TERMINUS KEUR MASSAR ↔ TERMINUS PARCELLES | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 228 | `DDD_228` — DDD_228_RUFISQUE_YENNE | TERMINUS RUFISQUE ↔ YENNE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 231 | `DDD_231` — DDD_231_BAUX-MARAICHERS_JAXAAY | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 232 | `DDD_232` — DDD_232_AEROPORT_BAUX-MARAICHERS | BAUX MARAICHERS ↔ AÉROPORT LSS | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 233 | DDD_233 [D233 M] DDD_233_BAUX-MARAICHERS_ Palais-1 — dir0: T | BAUX MARAICHERS ↔ PALAIS 1 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 234 | `DDD_234` — DDD_234_JAXAAY_LECLERC | JAXAAY ↔ LECLERC | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 301 | `DDD_301` — DDD_301_MEDINA_PARCELLES | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 305 | `DDD_305` — DDD_305_PALAIS-2_YOFF | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 308 | `DDD_308` — DDD_308_OUAKAM_PATTE-D'OIE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 311 | `DDD_311` — DDD_311_THIAROYE_TIV-PEULH | LAC ROSE <--> CROISSEMENT KEUR MASSAR | — | **MISSING_IN_DAKAR_BUS** |  | MISMATCH | MISSING_IN_DAKAR_BUS |
| 315 | `DDD_315` — DDD_315_RUFISQUE_YENNE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 319 | `DDD_319` — DDD_319_OUAKAM_SICAP-LIBERTE-6 | LIBERTÉ 6 <--> OUAKAM | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 323 | `DDD_323` — DDD_323_GUEULE-TAPEE_PARCELLE-ASSAINIE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 327 | — | KEUR MASSAR <--> TERMINUS PARCELLES | — | **UNKNOWN** |  | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 401 | `DDD_401` — DDD_401_AIBD_OUAKAM | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 402 | `DDD_402` — DDD_402_AIBD_THIAROYE | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 403 | `DDD_403` — DDD_403_AIBD_PARCELLES-ASSAINIES | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 404 | `DDD_404` — DDD_404_AIBD_LECLERC | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 405 | `DDD_405` — DDD_405_AIBD_DIEUPPEUL | — | — | **MISSING_IN_DAKAR_BUS** |  | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 501 | `DDD_501` — DDD_501_GARE-DE-DAKAR_PALAIS-2 | GARE DE DAKAR ↔ PALAIS 2 | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 502 | `DDD_502` — DDD_502_COLOBANE-UCAD-COLOBANE | GARE DE GARE <--> GARE DE GARE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 502A | — | COLOBANE ↔ UCAD | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 502 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 502B | — | COLOBANE ↔ ABASS NDAO | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 502 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 503 | `DDD_503` — DDD_503_COLOBANE-BELAIR-COLOBANE | GARE DE GARE <--> GARE DE GARE | — | **MISSING_IN_DAKAR_BUS** |  | MATCH | MISSING_IN_DAKAR_BUS |
| 503A | — | COLOBANE ↔ MOLE 8 | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 503 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 503B | — | COLOBANE ↔ HYDROCARBURE | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 503 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 504 | `DDD_504` — DDD_504_GARE-DE-DIAMNIADIO_SPHERE | — | — | **MISSING_IN_DAKAR_BUS** | numéro présent dans le flux PassBi (2022-2023) mais absent de la liste officielle 2026-09-25 ; la liste officielle publie les variantes 504A, 504B — correspondance UNKNOWN | MISSING_IN_OFFICIAL_LIST | UNKNOWN |
| 504A | — | GARE DIAMNIADIO ↔ SPHERE MINISTERIEL | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 504 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| 504B | — | SEBIKOTANE ↔ GARE DIAMNIADIO | — | **UNKNOWN** | numéro officiel 2026 absent du flux PassBi (2022-2023) ; le flux contient le numéro de base 504 sans suffixe — correspondance UNKNOWN | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| TAF | — | TAF TAF : OUAKAM ↔ AIBD | — | **UNKNOWN** |  | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| TAF TAF | — | OUAKAM ↔ AIBD / SPHÈRE MINISTÉRIELLE (Diamniadio) | — | **UNKNOWN** |  | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |
| TO1 | — | TAF TAF OUAKAM (TO1) : OUAKAM <--> PALAIS 2 | — | **UNKNOWN** |  | MISSING_IN_SOURCE | MISSING_IN_DAKAR_BUS |

### I.5 Identités Dakar Bus hors clé numérique (non comparables)

`brt_b1_guediawaye_petersen`, `brt_b2_express` (BRT : le flux PassBi a B1/B2 avec 21 et 7 arrêts par sens — cohérent en nombre avec Dakar Bus 23/7 stations, ordre non comparé), `ter_dakar_diamniadio` (TER : 13 gares dans les deux — Dakar, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR Rufisque, Rufisque, Bargny, Diamniadio dans le flux), `tata_218`, `tata_219`, `tata_50`, `tata_64`, `tata_78` (aucun flux « Tata » : le flux AFTU ne contient pas de n° 218/219 ; les n° 50, 64, 78 du flux AFTU sont d'autres lignes — **UNKNOWN**), `new_commune_01…13` (« NEW nn » : aucune contrepartie dans aucune source → **MISSING_IN_SOURCE**).

### I.6 Illustration de l'objectif final (« Yeumbeul → Colobane ») — données HISTORIQUES uniquement

Dans le flux AFTU 2022-2023, quatre lignes horodatent à la fois un arrêt dont le nom contient « Yeumbeul » et un arrêt dont le nom contient « Colobane » : **`AFTU_50`** (« Route De Yeumbeul Devant Ecobank » … « Station Ola Colobane »), **`AFTU_54`**, **`AFTU_75`** (« … Mairie Yeumbel Sud … » … « Colobane »), **`AFTU_82`** (« Terminus 43 Yeumbeul Nord » … « Bank Of Africa Colobane »). Aucune ligne DDD du flux ne relie les deux. Ceci montre ce qu'un GTFS **à jour et officiel** permettrait (ligne + direction + arrêt + prochain départ théorique) ; **avec les flux actuels (expirés), aucune réponse « maintenant » ne peut être produite sans inventer**.

---

## J. INCONNUES

| # | Inconnue | Ce qui la lèverait |
|---|---|---|
| J1 | **Origine réelle des 4 GTFS PassBi** (CETUD ? exploitants ? production PassBi ?) — le dépôt ne le dit pas ; « partenaire officiel du CETUD » est une allégation. | Demande écrite à `observatoire@cetud.sn` et à Impact Solutions SAS ; publication CETUD avec `feed_info.txt`. |
| J2 | **Version 2026 des GTFS** : le CETUD annonce un « fichier GTFS » en prose sans le publier ; l'article arXiv 2609.29998 prouve qu'un GTFS BRT (avec `frequencies.txt`) circule en privé. | Publication open data CETUD ou accès DT4A (authentifié, non tenté). |
| J3 | **Identité octet pour octet** de `plan-lignes-ddd.jpeg` (copie `demdikk.sn` 2023 vs `cetud.sn` 2024) et **SHA-256 de `plan-lignes-aftu.jpeg`** (non récupéré). | Exécuter `audit/external-feeds/fetch_sources.sh` hors bac à sable. |
| J4 | **Sens du préfixe `N`** des étiquettes `DDD_N305/N308/N311/N315/N319` de la carte CETUD, et lien `DDD_16A` (carte, liste officielle 16A/16B) ↔ `DDD_16` (flux). | Légende officielle DDD/CETUD. |
| J5 | **Backend de `app.senpassbi.com`** et **endpoints des applications mobiles** PassBi ; **statut futur** de `passbi-api.onrender.com` (suspendu) ; rôle de `api.senpassbi.com` (404). | Documentation éditeur ; ré-interrogation ultérieure de `/health`. |
| J6 | **Licence de réutilisation** des GTFS PassBi (aucune déclarée) et de l'image CETUD. | Clarification éditeur / CETUD avant tout import. |
| J7 | **Évolution du réseau DDD 2023 → 2026** (19 numéros du flux absents de la liste 2026, 14 identifiants 2026 absents du flux ; « 38 lignes » CETUD vs 53 routes flux vs 48 identifiants demdikk.sn) et **AFTU n° 90** (flux) absent de la liste officielle. | Référentiel exploitant daté. |
| J8 | **Lignes sans horaire dans le flux** : `AFTU_52`, `DDD_323` (aucun `stop_times`) ; sens manquants pour `AFTU_31/38/41/46/53/57/69`, `DDD_217/311`. | Version corrigée du flux. |
| J9 | **Fréquences déclarées** AFTU/DDD (aucune source), **horaires 2026** AFTU/DDD (aucune source publique : ni CETUD, ni CAPTRANS, ni exploitants au-delà de la ligne DDD 1 et de TAF TAF). | Publication exploitant/CETUD. |
| J10 | **Temps réel** : aucun flux public ; les placeholders `api.cetud.sn/gtfs-rt/*` du dépôt restent non vérifiés. **REAL_TIME = NON DISPONIBLE.** | Convention d'accès CETUD/Dakar Mobilité/SETER. |
| J11 | Correspondance des **identités internes Dakar Bus** (`aftu_1…72`, `ddd_*`, `tata_*`, `new_commune_*`) avec le réseau réel : **aucune** n'est confirmée par les sources de ce lot. | Ré-identification à partir d'une source officielle datée (hors de ce lot ; interdiction d'import automatique). |

---

## Annexe 1 — Méthode de récupération (sans contournement)

- **Bac à sable** : seul `github.com`/`api.github.com` (et `pypi.org`, `registry.npmjs.org`) répondaient en HTTP direct ; tous les autres hôtes (`cetud.sn`, `senpassbi.com`, `app.senpassbi.com`, `captrans.sn`, `demdikk.sn`, `aftu-senegal.org`, `impactsolutionsas.github.io`, `passbi-api.onrender.com`, stores) ont été consultés **en lecture seule via l'outil de récupération de pages** (texte uniquement, pas de binaires, codes HTTP non exposés). Aucune authentification, aucun secret, aucun contournement.
- **Chemins testés sur `senpassbi.com` et `www.senpassbi.com`** : `/robots.txt`, `/api`, `/api/v1`, `/api/docs`, `/docs`, `/swagger`, `/swagger.json`, `/openapi.json`, `/openapi.yaml`, `/api-docs` → page SPA « 404 » ; `https://api.senpassbi.com/health` → 404 LiteSpeed ; `https://passbi-api.onrender.com/health` → « This service has been suspended. » ; `https://impactsolutionsas.github.io/passbi_core/` → documentation publique (OK).
- **CETUD** : `robots.txt`, `sitemap.xml`, `/observatoire/systeme-de-donnees/`, `/reseaux-de-transport/{ddd,aftu,bus-regional-transit-brt,train-express-regional-ter}/`, API REST WordPress (`media`, `posts?search=captrans|gtfs`, `search`, `reseaux-de-transport`) ; `posts?search=captrans` → 3 billets (dont 2019-08-19).
- **PassBi GitHub** : `gh api users/impactsolutionsas/repos` (16 dépôts publics) ; clones complets de `passbi_core` et `passbi-gtfs-v1`, clones superficiels de `passbi-web-app`, `passbi-v2-backend`, `travel-passbi-api` ; grep provenance/GTFS-RT/hôtes.
- **Autres** : arbre complet du catalogue Mobility Database (aucun `sn-`), recherches GitHub code/dépôts, recherches web (DT4A, arXiv 2609.29998, UASZ 2022, SSATP), recherche d'images (seule voie ayant livré le JPEG DDD complet ; les autres résultats — miniatures, articles de presse — ont été écartés et supprimés du dépôt).

## Annexe 2 — Reproductibilité

```bash
# 1. Régénérer les rapports (lecture seule ; écrit uniquement audit/external-feeds/reports/)
python3 audit/external-feeds/analyze_feeds.py --as-of 2026-09-26
# 2. Re-télécharger et vérifier les sources (clone épinglé + SHA-256 ; curl cetud.sn hors bac à sable)
bash audit/external-feeds/fetch_sources.sh /tmp/fetch
# 3. Empreintes
sha256sum audit/external-feeds/source/passbi_core/gtfs_folder/*.zip audit/external-feeds/source/cetud/plan-lignes-ddd.jpeg
```

## Annexe 3 — Ce que ce lot n'autorise PAS

- Présenter les horaires 2022-2023 (AFTU/DDD), fin 2024 (BRT) ou août 2025 (TER) comme l'offre 2026 ou comme « prochain départ ».
- Importer les flux dans `dakar_network.json`/`data/gtfs/` ou renommer des lignes Dakar Bus d'après eux (origine non prouvée, licence absente, validité expirée).
- Résoudre une identité Dakar Bus par ressemblance de numéro, de nom d'arrêt ou de géométrie.
- Simuler un temps réel.
