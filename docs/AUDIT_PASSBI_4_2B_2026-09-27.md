# AUDIT_PASSBI_4_2B — Recherche d'une source GTFS plus récente et mécanisme de mise à jour

- **Lot** : 4.2B
- **Date** : 2026-09-27
- **Dépôt audité** : `github.com/impactsolutionsas/passbi_core` (public) + écosystème PassBi (16 dépôts)
- **Statut final** : **C — `PASSBI_HISTORICAL_ONLY`**
- **Code applicatif modifié** : **aucun** (voir §14)
- **Prédécesseur** : `docs/AUDIT_PASSBI_2026-09-27.md` (inchangé)

---

## 1. Résumé exécutif

**Aucune donnée GTFS plus récente n'existe dans l'écosystème PassBi.** Les quatre ZIP présents dans `gtfs_folder/` ont été **déposés une seule fois, le 2026-02-10, dans le commit initial, et n'ont jamais été modifiés depuis** — sur aucune branche.

Trois résultats structurants, tous vérifiables :

1. **Un seul commit a jamais touché `gtfs_folder/`** : `7a2b99824699` (« Initial commit », 2026-02-10T11:44:46Z). Les blobs des 4 ZIP sont **identiques sur `main` et sur `dev`**.
2. **Aucun mécanisme automatique n'existe** : le seul workflow GitHub Actions du dépôt est `pages-build-deployment`. Aucun script du dépôt, ni de l'écosystème, ne télécharge un GTFS : tous lisent un **chemin local**.
3. **Le mot « CETUD » n'apparaît nulle part** : **0 occurrence dans les 1 251 fichiers** de `passbi_core` (vendor et binaires compris), et **0 occurrence** dans `passbi-gtfs-v1`. La provenance CETUD revendiquée sur la fiche Play Store **ne laisse aucune trace dans le code**.

**Deux corrections de prémisse** sont apportées au §8 : `InterpolateStopTimes` est du **code mort** (0 appel) — PassBi n'interpole donc pas à l'import ; en revanche le champ **`timepoint` est purement et simplement perdu**, car il n'existe ni dans le code ni dans le schéma SQL.

**Réponse à la question posée** : parmi les sept hypothèses, c'est la **7 — fichiers déposés manuellement dans le dépôt**. Le mécanisme conçu pour les mises à jour (upload admin, ajouté le 2026-06-22, soit *après* le dépôt des ZIP) n'a **jamais produit de version commitée**.

---

## 2. Historique PassBi (Phase 1)

### 2.1 Branches et volumétrie

| Branche | Commits | Dernier commit | SHA |
|---|---|---|---|
| `main` (défaut) | 47 | 2026-03-29T16:01:01Z | `4de3d96e0c60` |
| `dev` | 26 | **2026-06-22T07:21:06Z** | `d49bede23d72` |
| `features` | 1 | 2026-02-10T11:44:46Z | `7a2b99824699` |

Dépôt : créé le 2026-02-10T11:44:57Z, `pushed_at` = 2026-06-22T07:22:48Z, non archivé, non fork, aucun parent.

**Aucun commit après le 2026-06-22** — vérifié par requête filtrée :

```
GET /commits?since=2026-06-23T00:00:00Z   →   AUCUN COMMIT APRES LE 2026-06-22
```

### 2.2 Historique de `gtfs_folder/` — le résultat clé

Requête `GET /commits?sha={main|dev}&path=gtfs_folder` :

| Branche | Commits ayant touché `gtfs_folder/` |
|---|---|
| `main` | **1** — `7a2b99824699`, 2026-02-10T11:44:46Z, « Initial commit » |
| `dev` | **1** — `7a2b99824699`, 2026-02-10T11:44:46Z, « Initial commit » |

**Les quatre ZIP n'ont jamais été modifiés après leur dépôt initial.**

### 2.3 Le dernier commit (2026-06-22) ne touche pas aux données

`d49bede23d72`, message littéral **« 22/07/2026 »** (incohérent avec sa date de commit du 22/06 — coquille de l'auteur), **61 fichiers touchés** :

| Fichier | Rôle |
|---|---|
| `internal/handlers/admin/gtfs.go` (+555) | **Panneau admin GTFS** : upload, versionnement, import |
| `internal/handlers/admin/{billing,partners,users,auth,audit_log,tiers,api_keys,co2,dashboard,system,profile,analytics}.go` | Back-office complet |
| `internal/handlers/partner_portal/*.go` (7 fichiers) | Portail partenaires |
| `internal/middleware/{admin_auth,partner_portal_auth,security}.go` | Authentification |
| `migrations/005..009_*.sql` | admin_user, partner_auth, audit_log, billing, **gtfs_agencies** |
| `cmd/seed/main.go` (+180) | Données de test |

**`gtfs_folder/` : absent de la liste des 61 fichiers.** Ce commit est fonctionnel (monétisation, admin), pas data.

---

## 3. Branches, tags, releases (Phase 2)

| Élément | Résultat |
|---|---|
| Branches | 3 (`main`, `dev`, `features`) |
| **Tags** | **AUCUN** |
| **Releases** | **AUCUNE** |
| Archives | aucune publication |
| Branches expérimentales | `features` = 1 commit (l'initial), abandonnée |
| Fichiers GTFS absents de `main` | **aucun** — `dev` et `main` portent exactement les 4 mêmes ZIP |

### 3.1 Comparaison binaire des blobs `main` vs `dev`

| Fichier | Blob `main` | Blob `dev` | Identique |
|---|---|---|---|
| `gtfs_AFTU.zip` | `2cb0fff80857d8b0a3591c58956cffc75d77071a` | `2cb0fff80857d8b0a3591c58956cffc75d77071a` | **OUI** |
| `gtfs_BRT.zip` | `22e9f4cff94f213040dfa6e61250e1a04c0802e5` | `22e9f4cff94f213040dfa6e61250e1a04c0802e5` | **OUI** |
| `gtfs_Dem_Dikk.zip` | `0d719ed5704a99cca60bac8e0ed038681c5fc5b3` | `0d719ed5704a99cca60bac8e0ed038681c5fc5b3` | **OUI** |
| `gtfs_TER.zip` | `0ea1bfb2929b8498e0c07830541a0ebd685a9427` | `0ea1bfb2929b8498e0c07830541a0ebd685a9427` | **OUI** |

### 3.2 Conclusion Phase 2

# `NO_NEWER_GTFS_FOUND`

Éléments vérifiés : 3 branches intégralement listées, 0 tag, 0 release, 0 commit après le 2026-06-22, 1 seul commit historique sur `gtfs_folder/`, blobs identiques entre `main` et `dev`.

---

## 4. Mécanismes d'update GTFS (Phase 3)

### 4.1 Workflows GitHub Actions

```
GET /actions/workflows   →   total_count = 1
```

```yaml
workflow:                pages-build-deployment
path:                    dynamic/pages/pages-build-deployment
trigger:                 push sur la branche servant GitHub Pages (automatique GitHub)
schedule:                AUCUN (pas de cron)
source:                  le dépôt lui-même (fichiers statiques docs/)
download:                AUCUN
generation:              AUCUNE
destination:             GitHub Pages
last relevant commit:    run du 2026-03-29T16:01:03Z
```

Les **4 seuls runs** enregistrés sont des builds Pages : 2026-02-13, 2026-03-04, 2026-03-28, 2026-03-29. Tous `success`. Aucun ne concerne des données.

Le dossier `.github/` du dépôt ne contient **que** `copilot-instructions.md` — **il n'y a pas de sous-dossier `workflows/`**.

### 4.2 Le seul mécanisme de mise à jour conçu : l'upload admin manuel

`internal/handlers/admin/gtfs.go` (branche `dev`, ajouté le 2026-06-22) implémente :

```go
// UploadGTFS POST /api/admin/gtfs/agencies/:agencyId/upload
fh, err := c.FormFile("file")                          // upload multipart
if !strings.HasSuffix(strings.ToLower(fh.Filename), ".zip") { ... }
// Storage path: {GTFS_FOLDER}/{agencyId}/v{N}_{timestamp}.zip
storageName := fmt.Sprintf("v%d_%s.zip", nextVersion, ts)
// INSERT ... (agency_id, version_number, filename, storage_path,
//              file_size_bytes, sha256, uploaded_by, notes)
```

avec `getGTFSFolder()` qui renvoie `os.Getenv("GTFS_FOLDER")` ou, par défaut, `./gtfs_folder`, et `runImporterAsync` qui exécute `--gtfs=<zipPath>`.

**Lecture** : le GTFS entre chez PassBi par **téléversement humain** d'un ZIP par un administrateur identifié (`uploaded_by` = e-mail de l'admin), avec SHA-256 et numéro de version. **Il n'existe aucune ingestion automatique, aucune planification, aucune synchronisation avec un opérateur.**

**Vérification décisive** : le dépôt ne contient **aucun sous-dossier** `gtfs_folder/{agencyId}/v{N}_*.zip`. Les seuls contenus de `gtfs_folder/` sont les 4 ZIP d'origine. ⇒ **Aucun upload admin n'a jamais été reversé au dépôt.**

> **Limite honnête** : ce mécanisme écrit aussi dans la base de données de PassBi. Il est donc *possible* qu'une version plus récente ait été téléversée directement en base sans passer par Git. Cela ne peut pas être vérifié : l'API est suspendue et l'endpoint exige une authentification admin. Cette hypothèse n'est **ni confirmée ni infirmée** — elle n'est en tout cas **pas vérifiable**, ce qui suffit à écarter toute intégration.

### 4.3 Conclusion Phase 3

# `NO_AUTOMATED_GTFS_UPDATE_FOUND`

---

## 5. Sources amont (Phases 4 et 6)

### 5.1 Inventaire exhaustif des URLs du code

Recherche sur les 1 251 fichiers de `passbi_core` (`dev`), hors `vendor/`, extensions `.go .sh .sql .yml .yaml .env* Makefile` :

| Occurrences | URL | Nature |
|---|---|---|
| 11 | `http://localhost` | développement |
| 1 | `https://passbi-api.onrender.com` | API PassBi elle-même |
| 1 | `https://opensource.org/licenses/MIT` | lien de licence |
| 1 | `https://github.com/passbi/passbi_core` | **lien mort — le dépôt n'existe pas (404)** |
| 1 | `https://github.com/impactsolutionsas/passbi_core` | auto-référence |
| 2 | `https://docs.passbi.com` / `/authentication` | documentation |
| 1 | `https://developers.google.com/transit/gtfs/reference` | **spécification** GTFS |
| 2 | `https://app.supabase.com/project/xlvuggzprjjkzolonbuh/...` | console de la base PassBi |

**Aucune de ces URLs n'est une source de données de transport.**

### 5.2 Absence totale de référence au CETUD

```
grep -rnia 'cetud' .   →   occurrences : 0
```

Portée : **les 1 251 fichiers de `passbi_core`, `vendor/` et fichiers binaires compris**. Même résultat dans `passbi-gtfs-v1`.

La fiche Play Store affirme pourtant : « PassBi utilise des données GTFS publiques centralisées par le CETUD ». **Cette affirmation ne correspond à rien dans le code.**

Rappel des vérifications indépendantes du lot 4.1/4.2 (2026-09-27) : `cetud.sn/observatoire/systeme-de-donnees/` décrit capteurs, enquêtes EMD et données mobiles — **aucun GTFS** ; `api.cetud.sn` **n'existe pas en DNS**.

> Distinction imposée par le lot : « PassBi affirme utiliser CETUD » est **vérifié** (l'affirmation existe). « CETUD publie effectivement ce feed » est **non démontré, et contredit** par l'absence de toute publication GTFS du CETUD.

### 5.3 Les scripts ne téléchargent rien

| Fichier | Comportement vérifié |
|---|---|
| `import_gtfs.sh` | `./bin/passbi-import --gtfs=gtfs_folder/gtfs_TER.zip` (×4) — **chemins locaux uniquement** |
| `Makefile`, cible `import` | `go run cmd/importer/main.go --agency-id=$(AGENCY) --gtfs=$(GTFS)` — variable locale, usage documenté `make import GTFS=./gtfs.zip` |
| `.env.example` | 20 variables : base, Redis, API, cache, `MAX_WALK_DISTANCE`, `WALKING_SPEED`, `TRANSFER_TIME`, `MAX_EXPLORED_NODES`, `ROUTE_TIMEOUT`. **Aucune URL de source, aucun `GTFS_FOLDER`.** |

### 5.4 Exploration de l'écosystème PassBi (16 dépôts)

`impactsolutionsas` est un **compte utilisateur** (l'endpoint `/orgs/` renvoie 404). Dépôts triés par date de push :

| Dépôt | Push | Exploré | Données GTFS ? |
|---|---|---|---|
| `aemud-app` | 2026-08-23 | — | hors périmètre (autre produit) |
| `impactsolution.tech` | 2026-07-12 | — | site vitrine |
| `ofood_backend` | 2026-07-05 | — | hors périmètre |
| `impactsolutions` | 2026-07-05 | — | hors périmètre |
| **`passbi_core`** | 2026-06-22 | ✅ intégral | **4 ZIP, figés au 2026-02-10** |
| `passbi-web-app` | 2026-03-29 | ✅ (3 fichiers) | non |
| `deggbi-poc` | 2026-03-25 | ✅ (128 fichiers) | non |
| **`passbi-gtfs-v1`** | 2026-02-16 | ✅ intégral | **fixtures décompressées — mêmes données** |
| **`passbi-v2-backend`** | 2026-01-28 | ✅ intégral | non (3 scripts d'import local) |
| **`travel-passbi-api`** | 2025-08-29 | ✅ (95 fichiers) | **aucune** |
| `passbi-app-v1` | 2025-07-21 | ✅ (190 fichiers) | non |
| `passbi-v2-backoffice` | 2025-07-04 | ✅ (2 fichiers) | non |
| `passbi-backoffice` | 2025-05-09 | ✅ (147 fichiers) | non |
| `selling-api.senpassbi.com` | 2025-04-09 | — | billetterie |

**`passbi-gtfs-v1`** (NestJS, créé 2025-10-03) contient `fixtures/gtfs_brt/`, `fixtures/gtfs_ddd/`, `fixtures/gtfs_ter/` — **pas de `gtfs_aftu/`**. Ses GTFS sont **décompressés**. Comparaison décisive : les `service_id` du TER y sont **les mêmes UUID** que dans le ZIP de `passbi_core` :

```
38f23463-d512-5c3f-6ed7-33132080f1e8,1,1,1,1,1,1,0,20250825,20250831
fa54f07d-702e-e4cc-6400-6efff8c64d25,0,0,0,0,1,1,0,20250825,20250831
4cd85026-70ce-fee8-af22-6008c0215228,0,0,0,0,0,1,0,20250825,20250831
```

Mêmes UUID, mêmes dates, mêmes 13 gares ⇒ **c'est la même donnée**, antérieure et non plus récente. Son import se fait par `POST /gtfs/import` avec `{"dirPath":"./fixtures/gtfs_ddd","agencyId":"DDD"}` — **chemin local**.

**`passbi-v2-backend`** contient trois scripts :

| Script | Ligne vérifiée | Accès réseau |
|---|---|---|
| `gtfs-import.js` | `readGTFSFile(path.join(gtfsFolder,'stops.txt'))` — usage `node gtfs-import.js <folder> <OPERATOR_CODE>` | **aucun** |
| `gtfs-loader.js` | `const folderPath = path.join('./gtfs', folder)` | **aucun** |
| `gtfs-sync.js` | `syncGTFS(args[0], args[1])`, lit `stops.txt` d'un dossier local — **ne synchronise que les arrêts** | **aucun** |

**Aucun `fetch`, aucun `axios`, aucun `http.get` dans les trois.**

### 5.5 URLs de `passbi-v2-backend` — toutes internes ou inexistantes

URLs trouvées, et résolution DNS testée le 2026-09-27 :

| URL dans le code | DNS |
|---|---|
| `https://api-docs.passbi.sn/docs` | **INEXISTANT** |
| `https://api-sandbox.passbi.sn/v1/` | **INEXISTANT** |
| `https://otel-staging.passbi.sn` | **INEXISTANT** |
| `https://api-prod.senpassbi.sn/v1` | **INEXISTANT** |
| `passbi.sn` | **INEXISTANT** |
| `http://minio-01-stg:9000` (`S3_ENDPOINT`, README) | hostname Docker interne, **non résolvable** |
| `app.senpassbi.com` | 64.29.17.65 (vitrine) |
| `passbi-api.onrender.com` | 216.24.57.16 — mais **« Service Suspended »** |

Les URLs `passbi.sn` / `senpassbi.sn` sont des **configurations de staging non publiées**. Conformément à la règle du lot, une URL présente dans une configuration ou un exemple **n'est pas une source active** : ici, elles ne résolvent même pas.

### 5.6 Conclusion Phase 6

# AUCUNE SOURCE AMONT IDENTIFIABLE

| Question | Réponse vérifiée |
|---|---|
| Propriétaire de la donnée | **inconnu** — aucun `feed_info.txt`, aucun éditeur déclaré |
| URL de récupération | **aucune** — inventaire exhaustif des 1 251 fichiers |
| Date de récupération | **inconnue** ; seul repère = horodatage interne des fichiers (TER : 2025-08-20) |
| Méthode de récupération | **dépôt manuel** dans le commit initial ; puis upload admin (jamais utilisé dans Git) |
| Fréquence de mise à jour | **aucune** — 1 seul commit data en 7 mois d'existence |
| Dernière mise à jour connue | **2026-02-10** (dépôt des ZIP) ; données elles-mêmes : 2025-08-31 au mieux |
| Conditions de réutilisation | **aucune licence** |

---

## 6. Analyse des 4 feeds (Phase 5)

### 6.1 Empreintes — version exactement analysée

Les quatre fichiers ont été retéléchargés depuis l'API GitHub puis **vérifiés contre le dépôt** via `git hash-object` :

| Fichier | SHA-256 | Taille | Blob Git | Contrôle |
|---|---|---|---|---|
| `gtfs_TER.zip` | `09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408` | 109 650 o | `0ea1bfb2929b` | **CONFORME** |
| `gtfs_BRT.zip` | `f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4` | 520 189 o | `22e9f4cff94f` | **CONFORME** |
| `gtfs_Dem_Dikk.zip` | `578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159` | 2 635 299 o | `0d719ed5704a` | **CONFORME** |
| `gtfs_AFTU.zip` | `7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428` | 10 693 791 o | `2cb0fff80857` | **CONFORME** |

*(Note de méthode : comparer le SHA-1 du fichier brut au blob Git est une erreur — un blob est le SHA-1 de `blob <taille>\0` + contenu. Le contrôle correct utilise `git hash-object`.)*

### 6.2 Fiches de traçabilité

Les quatre feeds partagent : `commit_introducing_file = 7a2b99824699`, `last_modified_commit = 7a2b99824699`, `last_modified_date = 2026-02-10T11:44:46Z`, `feed_info_present = NON`, `source_declared = AUCUNE`, `provenance_declared = AUCUNE`, `license_declared = AUCUNE`.

#### `gtfs_TER.zip`

| Champ | Valeur |
|---|---|
| `GTFS_period_start` / `_end` | **20250818 / 20250831** (12 services, 2 semaines) |
| `agency.txt` | `SETER` — `https://www.seter.sn/` — timezone **UTC** |
| `routes.txt` | 6 lignes, `route_type=2` (ferroviaire) |
| `trips.txt` | 572 courses |
| `stop_times.txt` | 7 332 passages ; `timepoint=1` : 833 (11,4 %) · `timepoint=0` : 6 499 (88,6 %) |
| `calendar.txt` | 12 services, 20250818→20250831 |
| `calendar_dates.txt` | **absent** — aucune exception, aucun jour férié |
| `shapes.txt` | **absent** — aucune géométrie |
| `stops.txt` | 26 enregistrements = **13 gares** × (station + quai) |

#### `gtfs_BRT.zip`

| Champ | Valeur |
|---|---|
| `GTFS_period_start` / `_end` | **20241024 / 20241231** (69 jours en `calendar_dates`) |
| `agency.txt` | `BRT` — **URL vide** — timezone `Africa/Dakar` |
| `routes.txt` | 2 lignes (`B1`, `B2`), `route_type=3` |
| `trips.txt` / `stop_times.txt` | 4 036 courses / 58 674 passages — `timepoint=1` à 100 % |
| `calendar.txt` | **vide** (en-tête seul) |
| `calendar_dates.txt` | 69 exceptions, `exception_type=1` |
| `shapes.txt` | présent (267 600 o) |
| `transfers.txt` | **en-tête seul — vide** |
| `stops.txt` | 79 arrêts |

#### `gtfs_Dem_Dikk.zip`

| Champ | Valeur |
|---|---|
| `GTFS_period_start` / `_end` | **20220101 / 20231231** |
| `agency.txt` | `Dakar Dem Dikk` — `https://demdikk.sn/dakar-et-banlieue/` — `Africa/Dakar` |
| `routes.txt` | 53 lignes (`D1LP`, `D2DL`, `D4DL`, `D5GP`, `D6CP`, `D7OP`…), `route_type=3` |
| `trips.txt` / `stop_times.txt` | 9 529 courses / 314 029 passages — **champ `timepoint` absent** |
| `calendar.txt` | 4 services, 2022→2023 |
| `calendar_dates.txt` | **malformé** : en-tête `service_id;date;exception_type` (`;`) mais données à la virgule |
| `shapes.txt` | présent · `fare_attributes.txt` présent |
| `stops.txt` | 1 277 arrêts |

#### `gtfs_AFTU.zip`

| Champ | Valeur |
|---|---|
| `GTFS_period_start` / `_end` | **20220101 / 20231231** |
| `agency.txt` | `Association de Financement des Professionnels du transport Urbain` — `https://aftu-senegal.org/` — `+221 33 859 02 88` |
| `routes.txt` | 73 lignes (`A1HL`, `A2PP`, `A3PY`…), `route_type=3` |
| `trips.txt` / `stop_times.txt` | 11 077 courses / 677 918 passages — **champ `timepoint` absent** |
| `calendar.txt` | 4 services, 2022→2023 |
| `calendar_dates.txt` | **malformé** (même défaut que DDD) |
| `shapes.txt` | présent · `fare_attributes.txt` + `fare_rules.txt` présents |
| `stops.txt` | 2 401 arrêts |

**Totaux** : 134 lignes · 3 783 arrêts bruts · 25 214 courses · 1 057 953 passages. Le total de 134 correspond au `total: 134` des exemples OpenAPI et aux « 134 routes, 1 795 stops » de `STATUS.md` (après déduplication à 30 m).

---

## 7. TER (Phase 7)

| Question | Réponse vérifiée |
|---|---|
| Les 13 stations historiques | **OUI** — Dakar Gare ferroviaire, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR Rufisque, Rufisque, Bargny, Diamniadio |
| Sébikotane | **NON** — recherche explicite, aucune occurrence |
| AIBD | **NON** — aucune occurrence |
| Keur Moussa | **NON** — aucune occurrence |
| Nouveaux trajets | **NON** — 6 relations, toutes à terminus Diamniadio ou intermédiaires |
| Nouveaux `service_id` | **NON** — 12 UUID, tous présents dans `passbi-gtfs-v1` |
| Nouveaux trips | **NON** — 572 courses, aucune version plus récente |
| Calendrier 2026 | **NON** — 20250818→20250831 exclusivement |
| Horaires 2026 | **NON** |

Les 6 relations incluent des **circulations partielles** — `14922`/`20922` Dakar↔Yeumbeul, `13005`/`23001` Dakar↔Rufisque — qui corroborent les informations de presse sur des trains ne faisant pas le parcours complet.

### 7.1 Avertissement sur la phase 2 du TER

La mise en service de l'AIBD est annoncée au **2026-09-28**. Le feed PassBi s'arrête à Diamniadio et a expiré le 2025-08-31 : **il ne décrit ni le réseau actuel, ni le réseau de demain.**

Conformément à la consigne, **AIBD et Sébikotane ne sont pas ajoutés à Dakar Bus**. Le référentiel de statuts à conserver est :

| Gare | `station_status` | Preuve à fournir |
|---|---|---|
| Les 13 gares actuelles | `confirmed` | flux SETER + `dakar_network.json`, concordance 1:1 |
| AIBD | `provisional` | ouverture annoncée au 2026-09-28 par la presse et le MITTA, **non confirmée par l'opérateur** dans une donnée structurée |
| Sébikotane | `unknown` | « en construction » (APS/Le Soleil 20/06), desserte au 28/09 non établie |

---

## 8. Données exactes vs calculées (Phase 8)

### 8.1 Ce qui est réellement dans les fichiers

Les `arrival_time` et `departure_time` sont **présents dans les ZIP**, avec `stop_sequence`, `trip_id`, `stop_id`. Ce sont des valeurs GTFS réelles, **non reconstruites par PassBi**. Exemple relevé dans `gtfs_TER.zip` :

```
seq=1  16:29:59 -> 16:30:00
seq=2  16:34:00 -> 16:35:25
seq=3  16:38:04 -> 16:38:54
```

### 8.2 ⚠️ Correction de prémisse : `InterpolateStopTimes` est du code mort

`internal/gtfs/normalize.go:139-213` définit bien :

```go
// InterpolateStopTimes fills in missing arrival/departure times
// For trips with missing times, interpolate based on distance/speed
func InterpolateStopTimes(stopTimes []models.GTFSStopTime) []models.GTFSStopTime {
```

**Mais elle n'est jamais appelée.** Dénombrement des appels réels dans `cmd/importer/main.go` :

| Fonction | Appels |
|---|---|
| `gtfs.ParseGTFSZip` | 1 |
| `gtfs.ValidateAndCleanStops` | 1 |
| `gtfs.DeduplicateStops` | 1 |
| `gtfs.InferMode` | 2 |
| `gtfs.ParseTimeToSeconds` | 4 |
| **`gtfs.InterpolateStopTimes`** | **0** |

**Conséquence** : l'affirmation « PassBi interpole les horaires manquants à l'import » — reprise du lot précédent — est **fausse pour le chemin d'import**. Les secondes irrégulières observées (93,2 % des passages TER) sont **déjà dans le ZIP** : elles ont été produites **en amont**, par l'outil inconnu qui a généré le feed.

**Cela n'améliore en rien la qualification** : une donnée interpolée en amont reste interpolée, et le feed le déclare lui-même via `timepoint=0`.

### 8.3 ⚠️ Découverte critique : le flag `timepoint` est perdu à l'import

```
grep -rniE 'timepoint' migrations/          →   AUCUN résultat (9 migrations)
grep -rniE 'timepoint' --include='*.go'     →   AUCUN résultat
```

Schéma réel de la table (`migrations/003_schedule_tables.up.sql`) :

```sql
CREATE TABLE stop_time (
    id BIGSERIAL PRIMARY KEY, trip_id TEXT NOT NULL, agency_id TEXT NOT NULL,
    stop_id TEXT NOT NULL, stop_sequence INT NOT NULL,
    arrival_time TEXT, departure_time TEXT,
    arrival_seconds INT, departure_seconds INT, created_at TIMESTAMPTZ
);
```

**Aucune colonne `timepoint`.** Donc la distinction « horaire exact » / « horaire approximatif », pourtant présente dans le feed TER (11,4 % / 88,6 %), **est définitivement détruite à l'import**.

**Conséquence décisive** : en sortie d'API PassBi, **il est impossible de savoir si une heure donnée était un point horaire exact ou une valeur approximative**. Un consommateur — Dakar Bus — ne peut donc **jamais** garantir qu'une heure issue de PassBi mérite le statut `SCHEDULED`, même si le feed était à jour. C'est un vice structurel, indépendant de la fraîcheur.

### 8.4 Aucun temps réel, même simulé

`internal/routing/vehicle_position.go` définit `VehiclePositionEstimator`, `EstimatePosition`, `interpolatePosition`, `EstimateArrivalTime`, `DistanceAlongPath`.

**Toutes les occurrences de ces symboles sont dans ce seul fichier** (plus une ligne `[x] Fonction EstimatePosition` dans `STATUS.md`). Le type n'est **jamais instancié**, aucune méthode n'est **jamais appelée**.

**C'est du code mort.** La roadmap confirme : `- [ ] GTFS-RT support`, `- [ ] Real-time vehicle tracking` — non cochés.

# `NOT_REAL_TIME`

Aucun flux GTFS-RT ou SAE n'existe, n'est consommé, ni même implémenté. Toute position « véhicule » chez PassBi serait une extrapolation d'horaire théorique — et en l'état, elle n'est même pas produite.

### 8.5 Valeurs de configuration, non des données

| Paramètre | Valeur | Fichiers |
|---|---|---|
| `TRANSFER_TIME` | **180** | `.env.example:27`, `.env.production:29`, `docker-compose.yml:55`, `render.yaml:60`, `README.md:351`, 3 guides de déploiement |
| `WALKING_SPEED`, `MAX_WALK_DISTANCE` | configurables | `.env.example` |

Le temps de correspondance est une **constante globale**, identique quel que soit l'arrêt, le mode ou l'heure. À qualifier `HARDCODED_ASSUMPTION`, jamais comme une donnée.

### 8.6 Point positif à signaler

`calendar` et `calendar_date` **sont** importés (`cmd/importer/main.go:427-453`) **et réellement interrogés** par les endpoints horaires (`internal/api/schedule_handlers.go:198-219`, logique par paliers avec « Tier 3: calendar_date additions for today »). La table `trip` porte bien `service_id`. Le moteur respecte donc le calendrier de service — mais comme tous les calendriers sont expirés, `service_active` serait faux aujourd'hui.

---

## 9. Licence et provenance (Phase 9)

| # | Question | Réponse vérifiée |
|---|---|---|
| 1 | **Licence du code PassBi** | MIT **annoncée** — `README.md` §License et `openapi.yaml` `license: MIT` — **mais aucun fichier `LICENSE` ni `COPYING` à la racine** (listing API : seuls `README.md` et `PARTNER_API_README.md`). La licence est donc **déclarée, pas matérialisée**. |
| 2 | **Licence des fichiers GTFS** | **AUCUNE.** Aucun `feed_info.txt` dans les 4 flux ⇒ pas de `feed_license`. Aucun fichier de licence accompagnant `gtfs_folder/`. |
| 3 | **Droit de réutilisation des données** | **Non démontré.** Aucune licence, aucun accord, aucune publication opérateur identifiée. |
| 4 | **Droit de redistribution dans Dakar Bus** | **Non démontré** — et donc à écarter. Embarquer ces données dans un build public exposerait le projet. |

**Règle appliquée** : MIT ≠ GTFS librement réutilisable. D'une part la licence n'est pas matérialisée ; d'autre part, même matérialisée, **MIT porterait sur le code Go, pas sur les données de transport**, qui relèvent d'un régime distinct et ici totalement absent.

Provenance : `source_type = TERTIARY` maintenu. La revendication CETUD est sans trace dans le code et sans publication CETUD correspondante.

---

## 10. Statut final (Phase 10)

# C — `PASSBI_HISTORICAL_ONLY`

| Statut | Retenu ? | Motif |
|---|---|---|
| A — `PASSBI_CURRENT_FEED_FOUND` | **non** | aucune version plus récente sur aucune des 3 branches ; 0 tag ; 0 release ; 1 seul commit data |
| B — `PASSBI_REGENERABLE_FROM_IDENTIFIED_SOURCE` | **non** | aucune source amont : 0 URL de données sur 1 251 fichiers, 0 occurrence de « CETUD », tous les scripts en lecture locale |
| **C — `PASSBI_HISTORICAL_ONLY`** | **OUI** | feeds figés au 2026-02-10, périodes 2022→2025-08, aucun mécanisme de mise à jour |
| D — `PASSBI_SOURCE_FOUND_BUT_NOT_CURRENT` | **non** | aucune source n'a été trouvée du tout — ni active, ni inactive |

---

## 11. Pourquoi les 4 feeds restent utiles

Historiques ne veut pas dire inutiles. Valeur réelle, par feed :

| Feed | Usage légitime | Usage interdit |
|---|---|---|
| **TER** | **Crosswalk de topologie** : 13 gares avec coordonnées, concordance 1:1 avec Dakar Bus. **Référence pour les relations partielles** (Dakar↔Yeumbeul, Dakar↔Rufisque). | Horaires 2026 · AIBD · Sébikotane |
| **BRT** | **Crosswalk de topologie** : 79 arrêts, corridor B1/B2, `shapes.txt` exploitable pour la géométrie. | Horaires · fréquences |
| **DDD** | **Référence historique** : 53 lignes nommées (`D1LP`, `D7OP`…), 1 277 arrêts, `shapes.txt`, `fare_attributes.txt`. Utile pour reconstituer le réseau 2022-2023. | Horaires · toute donnée 2026 |
| **AFTU** | **Référence historique** : 73 lignes, 2 401 arrêts, `fare_rules.txt` (seul feed avec règles tarifaires). | Horaires · toute donnée 2026 |

**Le meilleur usage est le crosswalk** : les identifiants, noms et coordonnées d'arrêts évoluent lentement, alors que les horaires changent à chaque grille. Un crosswalk `stop_id PassBi ↔ stop_id Dakar Bus` est défendable ; un horaire de 2022 ne l'est pas.

**Pourquoi ils ne doivent pas alimenter les horaires 2026** — quatre raisons indépendantes, chacune suffisante :

1. **Péremption** : `valid_to` échus de 13 mois (TER), 21 mois (BRT), 33 mois (DDD/AFTU).
2. **Rupture de réseau** : le TER change de phase le 2026-09-28 ; le feed s'arrête à Diamniadio.
3. **Perte du flag d'exactitude** : `timepoint` absent du schéma PassBi (§8.3) — impossible de distinguer heure exacte et heure approximative.
4. **Absence de licence** : redistribution non démontrable (§9).

### Ce qui manque pour atteindre `SCHEDULED`

| # | Manque | Preuve attendue |
|---|---|---|
| 1 | Provenance | GTFS publié **par l'opérateur** (SETER, Sunu BRT, DDD, AFTU) ou par le CETUD, à une URL stable |
| 2 | Métadonnées de flux | `feed_info.txt` avec `feed_publisher_name`, `feed_version`, `feed_start_date`, `feed_end_date`, `feed_license` |
| 3 | Validité courante | `valid_to` postérieur à la mise en production |
| 4 | Calendrier complet | `calendar.txt` **et** `calendar_dates.txt` couvrant les jours fériés — et des fichiers non malformés |
| 5 | Exactitude exploitable | `timepoint=1` sur les passages utilisés, **et** conservation de ce flag jusqu'à l'affichage |
| 6 | Fuseau conforme | `agency_timezone = Africa/Dakar` (le TER indique `UTC`) |
| 7 | Licence | autorisation explicite de réutilisation et de redistribution |
| 8 | Accord opérateur | pour AIBD/Sébikotane : confirmation de desserte datée |

Les points 1 à 4 et 7 manquent **totalement**. Les points 5, 6 et 8 sont en outre inatteignables **via PassBi**, qui détruit le flag `timepoint`.

---

## 12. Recommandation précise pour Dakar Bus

1. **Ne rien importer.** Les 4 feeds restent hors de `ScheduleProvider`. `EmptyScheduleProvider` demeure le fournisseur actif.
2. **Ne pas modifier `dakar_network.json`.** Aucun ajout d'AIBD ni de Sébikotane. Conserver `ter_dakar_diamniadio.schedule_status = UNKNOWN`.
3. **Clore la piste PassBi comme source de données, la conserver comme indice.** PassBi démontre qu'un jeu de 134 lignes / 1 795 arrêts a circulé ; il ne fournit ni donnée fraîche, ni chaîne de provenance, ni licence.
4. **S'adresser directement aux quatre opérateurs et au CETUD** — c'est la seule voie vers un `SCHEDULED`. Demande minimale : un GTFS avec `feed_info.txt`, une licence, et une périodicité de publication.
5. **Si un contact PassBi est établi**, demander précisément : (a) l'origine des 4 ZIP, (b) la date et la méthode d'obtention, (c) l'outil qui a produit les secondes irrégulières et les `timepoint=0`, (d) une licence écrite. Sans ces quatre réponses, la piste reste fermée.
6. **Ne jamais qualifier de `REAL_TIME` une donnée PassBi.** Aucun flux n'existe ; le code d'estimation est mort ; la roadmap le confirme.
7. **Conserver le présent rapport comme référence de traçabilité** : les SHA-256 du §6.1 permettent de reconnaître sans ambiguïté la version analysée si de nouveaux ZIP apparaissent.

---

## 13. Réponses aux 7 hypothèses du lot

| # | Hypothèse | Verdict | Preuve |
|---|---|---|---|
| 1 | Snapshots statiques historiques | **✅ OUI — c'est la réalité** | 1 seul commit data (2026-02-10), périodes 2022→2025-08, blobs identiques `main`/`dev` |
| 2 | Générés périodiquement depuis une source externe | ❌ NON | 0 workflow data, 0 cron, 0 script de téléchargement |
| 3 | Récupérables depuis une autre branche/tag/commit | ❌ NON | 3 branches vérifiées, 0 tag, 0 release, blobs identiques |
| 4 | Régénérables avec un script | ❌ NON | `import_gtfs.sh` et `Makefile` consomment un ZIP **local** ; ils ne le produisent pas |
| 5 | Alimentées par une API ou un endpoint externe | ❌ NON | inventaire exhaustif : 10 URLs, aucune source de données ; domaines `passbi.sn`/`senpassbi.sn` inexistants |
| 6 | Issues d'un GTFS CETUD identifiable | ❌ NON | **0 occurrence de « CETUD »** sur 1 251 fichiers ; aucun GTFS publié par le CETUD |
| 7 | **Fichiers déposés manuellement dans le dépôt** | **✅ OUI — mécanisme confirmé** | dépôt unique au commit initial ; mécanisme d'upload admin ajouté le 2026-06-22, jamais utilisé dans Git |

---

## 14. Fichiers modifiés

| Fichier | Action |
|---|---|
| `docs/AUDIT_PASSBI_4_2B_2026-09-27.md` | **créé** — le présent rapport |

**Aucun autre fichier.** Vérifications exécutées :

```
git status --porcelain                     → seuls ajouts : les 2 rapports d'audit
grep -rniI --exclude-dir=.git -e passbi .  → aucune occurrence hors docs/AUDIT_PASSBI*
git write-tree → rev-parse :flutter-src    → a8ebd75b6a5f8dfb309c8c8f107339f92f05c670
git rev-parse a2254a8:flutter-src            → a8ebd75b6a5f8dfb309c8c8f107339f92f05c670   IDENTIQUES
```

Le sous-arbre `flutter-src` est **inchangé** depuis le build validé par la CI (run #125). `main.dart`, l'interface, le GPS, le routage, les statuts et les données de production sont **intacts**. `docs/AUDIT_SOURCE_HORAIRE_TER_2026-09-27.md` et `docs/AUDIT_PASSBI_2026-09-27.md` sont **inchangés**.

`flutter analyze` / `flutter test` restent **non exécutables** dans cet environnement (aucun toolchain Dart/Flutter) — sans conséquence, aucune ligne de code n'ayant changé.

---

## 15. Commit SHA

**Aucun commit créé.** Conformément à la règle du lot (« ❌ Pas de commit de code applicatif », « ✅ Audit uniquement »), le rapport est laissé non commité, en attente de validation.

Branche de travail : `arena/01a0df09-dakar-bus`.

---

## Annexe — méthodes de vérification

| Vérification | Commande |
|---|---|
| Branches, tags, releases | `gh api repos/{R}/branches`, `/tags`, `/releases` |
| Commits après une date | `gh api "repos/{R}/commits?since=2026-06-23T00:00:00Z"` |
| Historique d'un chemin | `gh api "repos/{R}/commits?sha={B}&path=gtfs_folder"` |
| Comparaison de blobs | `gh api "repos/{R}/git/trees/{ref}?recursive=1"` |
| Téléchargement vérifié | `gh api "repos/{R}/git/blobs/{sha}"` + `git hash-object` |
| Empreintes | `sha256sum` |
| Analyse des feeds | `python3` + `zipfile` + `csv` |
| Recherche plein texte | `gh api repos/{R}/tarball/{ref}` puis `grep -rnia` en local |
| Existence des domaines | `python3 socket.gethostbyname` |

**Limite déclarée** : l'API de code search de GitHub était en quota (`403 API rate limit exceeded`). La recherche plein texte a donc été faite **localement** sur les archives complètes des dépôts, ce qui est plus exhaustif (vendor et binaires inclus).

---

**Rapport clos le 2026-09-27.**
