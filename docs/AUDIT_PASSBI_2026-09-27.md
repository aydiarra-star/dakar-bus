# AUDIT_PASSBI — Qualification des données PassBi

- **Date de l'audit** : 2026-09-27
- **Auditeur** : agent Arena (branche `arena/01a0df09-dakar-bus`)
- **Périmètre** : qualifier séparément les données PassBi (lignes, arrêts, itinéraires, horaires, fréquences, correspondances, temps réel, fraîcheur, provenance, couverture, opérateurs) et statuer sur leur intégrabilité.
- **Décision rendue** : **`NOT_READY_FOR_IMPORT`**
- **Impact sur le code** : **aucun**. Aucune donnée PassBi n'a été importée dans `ScheduleProvider`. Vérifié en fin de document (§10).
- **Impact sur le lot TER** : **aucune modification** de `docs/AUDIT_SOURCE_HORAIRE_TER_2026-09-27.md`. Les éléments nouveaux qui le concernent sont signalés au §9 sans le réécrire.

---

## 1. Identification de PassBi

| Élément | Valeur | Source | Consulté le |
|---|---|---|---|
| Nom | PassBi | Google Play | 2026-09-27 |
| Package Android | `com.senpassbi.app` | Google Play | 2026-09-27 |
| Éditeur (Play Store) | IMPACT SOLUTION SAS | Google Play | 2026-09-27 |
| Développeur déclaré | DJIBRIL SAGNA | Google Play | 2026-09-27 |
| Contact | contact@senpassbi.com / dev@senpassbi.com / +221 78 450 00 58 | Google Play | 2026-09-27 |
| Site vitrine | `https://senpassbi.com` | site | 2026-09-27 |
| Application web | `https://app.senpassbi.com` | site | 2026-09-27 |
| iOS | `apps.apple.com/sn/app/passbi/id6757200579` | site | 2026-09-27 |
| Documentation API | `impactsolutionsas.github.io/passbi_core/` | site | 2026-09-27 |
| Code source | `github.com/impactsolutionsas/passbi_core` — **public**, Go + PostgreSQL/PostGIS + Redis | GitHub API | 2026-09-27 |
| Dépôt créé le | 2026-02-10 | GitHub API | 2026-09-27 |
| Dernier commit `main` | `4de3d96e0c60`, 2026-03-29 | GitHub API | 2026-09-27 |
| Dernier push (toutes branches) | 2026-06-22 | GitHub API | 2026-09-27 |
| Dernière mise à jour Play Store | **30 janvier 2026** | Google Play | 2026-09-27 |
| Téléchargements Play Store | **50+** | Google Play | 2026-09-27 |

### 1.1 Statut officiel : non

PassBi se décrit lui-même, sur sa fiche Play Store, en ces termes :

> « PassBi est une application indépendante développée par Impact Solutions SAS. Elle ne représente aucune entité gouvernementale et n'est affiliée à aucun organisme public. »

**Conséquence** : `data_trust` ne peut pas être `OFFICIAL`. Par défaut, **`source_type = TERTIARY`**.

### 1.2 Contradiction relevée entre les deux supports de communication

| Support | Affirmation |
|---|---|
| Google Play (30/01/2026) | « n'est affiliée à aucun organisme public » |
| senpassbi.com | « **Official partner of CETUD** — Dakar Transport Authority » |

Les deux affirmations sont incompatibles. **Aucun document du CETUD consulté ne confirme un partenariat** (§3). Cette contradiction est à elle seule un motif de classement en `TERTIARY` : un partenaire officiel d'une autorité organisatrice n'a pas besoin de se déclarer non affilié, et l'inverse n'est pas démontré non plus.

---

## 2. Provenance revendiquée par PassBi

La fiche Play Store déclare :

> « PassBi utilise des données GTFS publiques centralisées par le CETUD (Conseil Exécutif des Transports Urbains Durables) et issues des opérateurs suivants : https://www.cetud.sn https://www.sunubrt.sn https://www.terdakar.sn https://www.demdikk.sn »

Le site vitrine ajoute : « computed on **official GTFS data** » et l'OpenAPI : « **GTFS-powered** — Built on standard GTFS data format ».

**Cette source primaire n'a pas pu être confirmée.** Voir §3.

---

## 3. Recherche de la source primaire : résultat négatif

### 3.1 Le CETUD ne publie aucun GTFS

Pages consultées le 2026-09-27 :

| Page | Contenu réel | GTFS ? |
|---|---|---|
| `cetud.sn/` | DG Gora SARR ; projets BRT, PMT, RTC, PMUD Dakar, PMUD Mbour ; « Observatoire de la mobilité » | **non** |
| `cetud.sn/observatoire/systeme-de-donnees/` | 4 familles de données (trafic, comportements, exploitation TC, externalités) ; capteurs radar/magnétiques, MIOVISION, drones ; enquêtes EMD (périodicité ~10 ans), EPD 2017, enquêtes O/D, données mobiles SONATEL (POC) | **non** |
| `cetud.sn/observatoire/indicateurs-de-trafic/` | Indicateurs agrégés datés 2020→2024 (ex. « Parc Dakar en Commun : 2780 bus (Février-2024) », « Lignes Dakar en Commun : 130 lignes (Février-2024) ») + publications PDF | **non** |

**Aucun portail open data, aucun jeu GTFS téléchargeable, aucune API de données sur `cetud.sn`.**

### 3.2 `api.cetud.sn` n'existe pas

Résolution DNS exécutée le 2026-09-27 (`python3 socket.gethostbyname`) :

```
api.cetud.sn          -> INEXISTANT
cetud.sn              -> 185.125.27.62
www.cetud.sn          -> 185.125.27.62
```

(Cohérent avec le lot TER : `api.ter.sn`, `api.sunubrt.sn`, `api.dakardemdikk.sn` sont également inexistants.)

### 3.3 Aucun GTFS public sénégalais trouvé

Recherches web du 2026-09-27 sur « GTFS Dakar Sénégal open data CETUD SunuBRT Dakar Dem Dikk » : les seuls jeux GTFS publiés trouvés sont **français, monégasques et luxembourgeois** (data.gouv.fr, data.public.lu). Côté Sénégal : `senegalouvert.github.io`, `senegal.opendataforafrica.org`, `senegal.africageoportal.com` (un shapefile « Réseaux de transport » daté de 2022, pas un GTFS).

### 3.4 Où les données se trouvent réellement

Les données sont **hébergées dans le dépôt public tiers** `impactsolutionsas/passbi_core`, sous `gtfs_folder/` :

```
gtfs_folder/gtfs_AFTU.zip        10 693 791 o   blob 2cb0fff8
gtfs_folder/gtfs_BRT.zip            520 189 o   blob 22e9f4cf
gtfs_folder/gtfs_Dem_Dikk.zip     2 635 299 o   blob 0d719ed5
gtfs_folder/gtfs_TER.zip            109 650 o   blob 0ea1bfb2
```

Les quatre archives ont été téléchargées via l'API GitHub et leurs tailles correspondent **octet pour octet** à celles de l'arbre du dépôt. Elles ont été analysées en local (§4).

**Conclusion sur la provenance** : la chaîne revendiquée « opérateurs → CETUD → PassBi » n'est **pas démontrée**. Ce qui est démontré, c'est « fichiers ZIP présents dans le dépôt d'un tiers, sans `feed_info.txt`, sans licence, sans publication opérateur identifiée ».

---

## 4. Analyse des flux GTFS réellement présents

### 4.1 Tableau de synthèse

| Flux | `agency_name` | `agency_url` | `agency_timezone` | Validité calendaire | routes | stops | trips | stop_times | `feed_info.txt` | `timepoint=1` |
|---|---|---|---|---|---|---|---|---|---|---|
| `gtfs_TER.zip` | SETER | seter.sn | **UTC** | **20250818 → 20250831** | 6 | 26 (13 gares ×2) | 572 | 7 332 | **absent** | 833 / 7 332 (11,4 %) |
| `gtfs_BRT.zip` | BRT | *(vide)* | Africa/Dakar | **20241024 → 20241231** | 2 (B1, B2) | 79 | 4 036 | 58 674 | **absent** | 58 674 / 58 674 (100 %) |
| `gtfs_Dem_Dikk.zip` | Dakar Dem Dikk | demdikk.sn | Africa/Dakar | **20220101 → 20231231** | 53 | 1 277 | 9 529 | 314 029 | **absent** | champ absent |
| `gtfs_AFTU.zip` | AFTU | aftu-senegal.org | Africa/Dakar | **20220101 → 20231231** | 73 | 2 401 | 11 077 | 677 918 | **absent** | champ absent |

`STATUS.md` du dépôt (daté 2026-02-10) confirme le total exploité :

> « 4 agences importées : Dakar Dem Dikk (53 routes), AFTU (73 routes), BRT (2 routes), TER (6 routes) — **Total : 134 routes, 1 795 stops** »

Ce total de **134** correspond exactement au champ `total: 134` des exemples de l'OpenAPI.

### 4.2 Les quatre flux sont expirés

Rapporté au 2026-09-27 :

| Flux | `valid_to` | Retard |
|---|---|---|
| TER | 2025-08-31 | **≈ 13 mois** |
| BRT | 2024-12-31 | **≈ 21 mois** |
| DDD | 2023-12-31 | **≈ 33 mois** |
| AFTU | 2023-12-31 | **≈ 33 mois** |

**Aucun des quatre flux ne décrit le service en vigueur aujourd'hui.**

### 4.3 Anomalies techniques constatées

1. **`feed_info.txt` absent des quatre flux.** Aucune déclaration d'éditeur, de version, de période de validité ni de licence au niveau du flux. C'est le fichier qui, en GTFS, porte la provenance : il est systématiquement manquant.
2. **`calendar_dates.txt` malformé chez DDD et AFTU** : en-tête au point-virgule (`service_id;date;exception_type`) et lignes de données à la virgule (`LAV,20220404,2`). Un parseur GTFS strict échoue ou lit un fichier à une seule colonne.
3. **`calendar.txt` vide côté BRT** (en-tête seul) : tout le service repose sur `calendar_dates.txt`, 69 jours listés individuellement.
4. **`agency_timezone = UTC` pour le TER** au lieu d'`Africa/Dakar`. *Portée réelle à préciser* : le Sénégal est à UTC+0 sans heure d'été, donc l'écart numérique est nul — c'est une non-conformité, pas une erreur d'affichage.
5. **`transfers.txt` du BRT réduit à son en-tête** : aucune correspondance déclarée dans les données.
6. **`shapes.txt` absent du flux TER** : aucune géométrie de voie.
7. **Identifiants en UUID** (ex. `4445e51b-971b-4f1a-a94a-1ca0c9bef411-544a27a5-…`) : typique d'un flux généré par outil, non d'une exportation d'un système de planification opérateur.
8. **88,6 % des `stop_times` du TER portent `timepoint=0`**, c'est-à-dire *explicitement déclarés approximatifs* par la norme GTFS. Seuls 11,4 % sont des points horaires exacts.
9. **Secondes non nulles massives** : 93,2 % des `stop_times` TER, 99,7 % BRT, 95,4 % DDD, 98,3 % AFTU ont des secondes ≠ `00` (ex. TER `16:38:04`, `16:40:58`, `16:43:50`, `16:46:45`). Un horaire publié par un opérateur ferroviaire est exprimé en minutes rondes. Cette distribution est cohérente avec des **temps interpolés**, y compris là où `timepoint=1` (BRT) — contradiction interne.

### 4.4 Le mode de transport est attribué par PassBi, pas par les données

`STATUS.md` : « Normalisation mode BUS/BRT/TER ». Dans les flux, `route_type` vaut `2` (ferroviaire) pour le TER et `3` (bus) pour les trois autres. Le BRT est donc **reclassé `BRT` par l'importeur PassBi** alors que son `route_type` GTFS est `3`. À retenir : le champ `mode` renvoyé par l'API est une décision de PassBi, pas une donnée opérateur.

---

## 5. Qualification donnée par donnée

Légende — `source_type` : `PRIMARY` (opérateur/autorité) · `SECONDARY` (reprise documentée) · `TERTIARY` (tiers sans chaîne démontrée) · `UNKNOWN`.
`schedule_status` : `SCHEDULED` · `ESTIMATED` · `REAL_TIME` · `UNKNOWN`.

### 5.0 Tableau de synthèse — les 11 familles, les 9 champs

`date_verified` = **2026-09-27** pour l'ensemble (date du présent audit). Détail et justification famille par famille en §5.1 à §5.11.

| Donnée | `source` | `source_type` | `date_source` | `valid_from` | `valid_to` | `confidence` | `data_status` | `schedule_status` |
|---|---|---|---|---|---|---|---|---|
| **Lignes** (134) | `routes.txt` des 4 ZIP tiers | TERTIARY | 2022 → 2025-08-20 | 2022-01-01 | **échu** (2023→2025-08-31) | LOW | EXPIRED | UNKNOWN |
| **Arrêts** (1 795) | `stops.txt` des 4 ZIP | TERTIARY | idem | idem | **échu** | LOW-MED | EXPIRED | UNKNOWN |
| **Itinéraires** | moteur A* PassBi | TERTIARY | 2026-03-29 | s.o. | borné par les flux → **échu** | LOW | DERIVED | UNKNOWN |
| **Horaires** | `stop_times.txt` | TERTIARY | 2025-08-20 | 2025-08-18 | **2025-08-31 échu** | LOW | EXPIRED | **UNKNOWN** *(pas SCHEDULED)* |
| **Fréquences** | aucune publiée — dérivée de `trips.txt` | TERTIARY | 2025-08-20 | 2025-08-18 | **2025-08-31 échu** | LOW | DERIVED_FROM_EXPIRED | **ESTIMATED** |
| **Correspondances** | constante 180 s codée en dur | TERTIARY | 2026-03-29 | s.o. | s.o. | VERY LOW | HARDCODED_ASSUMPTION | UNKNOWN |
| **Temps réel** | revendication marketing | TERTIARY | 2026-09-27 | s.o. | s.o. | NONE | NOT_AVAILABLE | **UNKNOWN** *(pas REAL_TIME)* |
| **Date de mise à jour** | Play Store / dépôt / ZIP | TERTIARY | maj 2026-01-30 ; données 2025-08-31 | s.o. | s.o. | MEDIUM | STALE (≈ 13 mois) | UNKNOWN |
| **Provenance** | dépôt tiers `passbi_core`, sans `feed_info.txt` | **TERTIARY** | 2026-09-27 | s.o. | s.o. | NONE | **UNVERIFIED_PROVENANCE** | UNKNOWN |
| **Couverture** | `stops.txt` / `routes.txt` | TERTIARY | idem flux | idem | **échu** | MEDIUM | PARTIAL (pas d'AIBD, pas d'interurbain) | UNKNOWN |
| **Opérateurs** | `agency.txt` (SETER, BRT, DDD, AFTU) | TERTIARY | idem flux | idem | **échu** | LOW | NAMED_NOT_CONFIRMED | UNKNOWN |

**Aucune famille n'atteint `SCHEDULED`. Aucune n'atteint `REAL_TIME`.** Une seule atteint `ESTIMATED` (les fréquences, conformément à la règle), et elle porte un `valid_to` échu.

### 5.1 Lignes / réseaux

| Champ | Valeur |
|---|---|
| `source` | `gtfs_folder/gtfs_*.zip` → `routes.txt` (dépôt tiers `impactsolutionsas/passbi_core`) |
| `source_type` | **TERTIARY** |
| `date_source` | 2022-01-01 → 2025-08-20 selon le flux (horodatage interne des fichiers) |
| `date_verified` | 2026-09-27 |
| `valid_from` | 2022-01-01 (DDD/AFTU) · 2024-10-24 (BRT) · 2025-08-18 (TER) |
| `valid_to` | 2023-12-31 (DDD/AFTU) · 2024-12-31 (BRT) · 2025-08-31 (TER) — **toutes échues** |
| `confidence` | **LOW** |
| `data_status` | **EXPIRED** · provenance non démontrée · pas de licence |
| `schedule_status` | **UNKNOWN** (non applicable — pas d'horaire) |

Contenu vérifié : **134 lignes** — DDD 53 (`D1LP`, `D2DL`, `D4DL`, `D5GP`, `D6CP`, `D7OP`, `D8PL`, `D9P0`, `D10LP`…), AFTU 73 (`A1HL`, `A2PP`, `A3PY`…), BRT 2 (`B1`, `B2`), TER 6.

Les 6 lignes TER portent des **relations partielles**, et non une seule ligne :

```
10001  Dakar (DAK) -> Diamniadio (DIA)
20001  Diamniadio (DIA) -> Dakar (DAK)
14922  Dakar (DAK) -> Yeumbeul (YEU)
20922  Yeumbeul (YEU) -> Dakar (DAK)
13005  Dakar (DAK) -> Rufisque (RUF)
23001  Rufisque (RUF) -> Dakar (DAK)
```

### 5.2 Arrêts

| Champ | Valeur |
|---|---|
| `source` | `stops.txt` des 4 flux |
| `source_type` | **TERTIARY** |
| `date_source` | idem §5.1 |
| `date_verified` | 2026-09-27 |
| `valid_from` / `valid_to` | idem §5.1 (échues) |
| `confidence` | **LOW-MEDIUM** (la géométrie des arrêts évolue peu ; la liste des arrêts desservis, si) |
| `data_status` | **EXPIRED** · déduplication à 30 m appliquée par PassBi |
| `schedule_status` | **UNKNOWN** (non applicable) |

Contenu vérifié : **3 783 arrêts bruts** (TER 26, BRT 79, DDD 1 277, AFTU 2 401), ramenés à **1 795** après la déduplication à 30 m décrite dans `STATUS.md`. Coordonnées présentes (`stop_lat`/`stop_lon`). Le flux TER utilise `location_type` 1 (station) et 0 (quai), 13 + 13.

> **Règle respectée** : aucune halte n'a été déduite d'une carte ou d'OSM. Les arrêts proviennent bien de `stops.txt`.

### 5.3 Itinéraires (routage)

| Champ | Valeur |
|---|---|
| `source` | moteur A* PassBi (`internal/routing`), 4 stratégies `no_transfer` / `direct` / `simple` / `fast` |
| `source_type` | **TERTIARY** (résultat de calcul, pas une donnée) |
| `date_source` | 2026-03-29 (dernier commit `main`) |
| `date_verified` | 2026-09-27 |
| `valid_from` | sans objet |
| `valid_to` | borné par la validité des flux sous-jacents → **échu** |
| `confidence` | **LOW** |
| `data_status` | **DERIVED** — sortie d'algorithme sur données expirées |
| `schedule_status` | **UNKNOWN** |

Un itinéraire PassBi n'est **pas une donnée d'opérateur** : c'est le résultat d'un calcul de plus court chemin. Il ne peut en aucun cas alimenter un champ horaire.

### 5.4 Horaires

| Champ | Valeur |
|---|---|
| `source` | `stop_times.txt` des 4 flux |
| `source_type` | **TERTIARY** |
| `date_source` | 2025-08-20 (TER) · 2024-10-24 (BRT) · 2022 (DDD/AFTU) |
| `date_verified` | 2026-09-27 |
| `valid_from` | 2025-08-18 (TER) — le plus récent |
| `valid_to` | 2025-08-31 (TER) — **échu depuis ≈ 13 mois** |
| `confidence` | **LOW** |
| `data_status` | **EXPIRED** · `feed_info.txt` absent · 88,6 % de `timepoint=0` (TER) · secondes interpolées |
| `schedule_status` | **UNKNOWN** — **pas `SCHEDULED`** |

**Justification du refus de `SCHEDULED`.** La règle imposée exige trois conditions cumulatives. État vérifié :

| Condition | État | Preuve |
|---|---|---|
| Rattachement ligne / course / arrêt | **✅ rempli** | `route_id`, `trip_id`, `stop_sequence`, `stop_id` présents ; courses de 13 arrêts |
| Provenance démontrée | **❌ non rempli** | pas de `feed_info.txt` ; dépôt tiers ; aucune publication opérateur trouvée ; `cetud.sn` ne publie aucun GTFS ; `api.cetud.sn` inexistant |
| Validité démontrée | **❌ non rempli** | `valid_to` 2025-08-31 ; échu de ≈ 13 mois ; réseau TER modifié le 2026-09-28 |

Deux conditions sur trois manquantes ⇒ **`SCHEDULED` exclu**. Le classement retenu est `UNKNOWN` et non `ESTIMATED`, car la donnée est échue : un `ESTIMATED` laisserait entendre qu'elle décrit le service courant, ce qui est faux.

### 5.5 Fréquences

| Champ | Valeur |
|---|---|
| `source` | **aucune fréquence publiée** — à dériver de `trips.txt` / `stop_times.txt` |
| `source_type` | **TERTIARY** |
| `date_source` | 2025-08-20 (TER) |
| `date_verified` | 2026-09-27 |
| `valid_from` / `valid_to` | 2025-08-18 / **2025-08-31 (échu)** |
| `confidence` | **LOW** |
| `data_status` | **DERIVED_FROM_EXPIRED** |
| `schedule_status` | **ESTIMATED** (conformément à la règle « une fréquence PassBi reste `ESTIMATED` ») |

Mesure effectuée sur le flux TER, ligne `10001` (Dakar → Diamniadio) : **262 courses** sur les 14 jours de validité, soit ≈ 18,7 courses/jour toutes relations confondues ; premier départ `05:30:00`, dernier `22:06:00`. Ces valeurs sont cohérentes avec l'ordre de grandeur publié par l'opérateur (10 min en heures pleines), **mais elles décrivent août 2025**.

> **Règle respectée** : aucune heure n'a été extrapolée à partir d'une fréquence. Le sens de la dérivation est ici inverse (fréquence observée à partir des courses), et elle reste cantonnée à `ESTIMATED`.

### 5.6 Correspondances

| Champ | Valeur |
|---|---|
| `source` | `data-models.md` : étape `TRANSFER`, « default: **180 seconds** / 3 minutes » ; `transfers.txt` BRT **vide** |
| `source_type` | **TERTIARY** |
| `date_source` | 2026-03-29 |
| `date_verified` | 2026-09-27 |
| `valid_from` / `valid_to` | sans objet |
| `confidence` | **VERY LOW** |
| `data_status` | **HARDCODED_ASSUMPTION** — constante de code, pas une donnée |
| `schedule_status` | **UNKNOWN** |

Le temps de correspondance de 180 s est une **valeur codée en dur**, identique quel que soit l'arrêt, le mode ou l'heure. Ce n'est pas une donnée de correspondance. De même, la durée de marche est « calculated from distance ÷ walking speed ».

### 5.7 Temps réel

| Champ | Valeur |
|---|---|
| `source` | revendications marketing (« Real-time schedules — DDD, BRT, AFTU, TER ») |
| `source_type` | **TERTIARY** |
| `date_source` | 2026-09-27 (consultation du site) |
| `date_verified` | 2026-09-27 |
| `valid_from` / `valid_to` | sans objet |
| `confidence` | **NONE** |
| `data_status` | **NOT_AVAILABLE** |
| `schedule_status` | **UNKNOWN** — **explicitement pas `REAL_TIME`** |

**Le temps réel PassBi est réfuté par trois preuves indépendantes.**

1. **Le code source.** `internal/routing/vehicle_position.go` définit un `VehiclePositionEstimator` dont la méthode `EstimatePosition` calcule une position « *based on elapsed time since the start of the journey* ». Il s'agit d'une **interpolation à partir de l'horaire théorique**, pas d'une position de véhicule reçue d'un flux.
2. **La roadmap du dépôt.** `README.md` :
   ```
   ## Roadmap
   - [ ] GTFS-RT support
   - [ ] Real-time vehicle tracking
   ```
   Les deux cases sont **non cochées** = non implémentées.
3. **L'absence de tout flux.** Aucun fichier `gtfs-rt`, `siri`, `vehicle_position` ou `trip_update` dans les 1 366 fichiers du dépôt. La seule occurrence est le fichier d'interpolation cité ci-dessus.

> **Point d'alerte.** PassBi affiche comme « real-time » une extrapolation d'horaires théoriques. C'est exactement le « faux temps réel » que les protections du lot 3.8 interdisent dans Dakar Bus. **Aucune donnée PassBi ne doit être étiquetée `REAL_TIME`.**

### 5.8 Disponibilité du service

| Champ | Valeur |
|---|---|
| `source` | `https://passbi-api.onrender.com` |
| `source_type` | **TERTIARY** |
| `date_verified` | 2026-09-27 |
| `data_status` | **SERVICE_SUSPENDED** |

Tests effectués le 2026-09-27 :

| URL | Réponse |
|---|---|
| `passbi-api.onrender.com/health` | « **Service Suspended** — This service has been suspended. » |
| `passbi-api.onrender.com/v2/routes/list?mode=BUS&limit=10` | « **Service Suspended** » |
| `api.senpassbi.com/health` | **404 Not Found** (LiteSpeed) — cet hôte n'est pas l'API |

Le seul hôte de production documenté est **suspendu**. L'API est donc **inaccessible** : ni vérifiable, ni consommable, ni contractuellement stable.

Résolution DNS du 2026-09-27, pour information :

```
senpassbi.com       -> 185.158.133.1      www.senpassbi.com -> 185.158.133.1
api.senpassbi.com   -> 192.64.117.101     app.senpassbi.com -> 64.29.17.1
passbi.sn           -> INEXISTANT
```

### 5.9 Date de mise à jour

| Repère | Date |
|---|---|
| Horodatage interne des fichiers du flux TER | 2025-08-20 |
| Horodatage interne des fichiers du flux BRT | 2024-10-24 |
| Validité calendaire DDD / AFTU | 2022 → 2023 |
| `STATUS.md` du dépôt | 2026-02-10 |
| Mise à jour Play Store | 2026-01-30 |
| Dernier commit `main` | 2026-03-29 |
| Dernier push du dépôt | 2026-06-22 |
| **Date de l'audit** | **2026-09-27** |

**Écart entre la dernière donnée (2025-08-31) et l'audit : ≈ 13 mois.** Le code a évolué en 2026 ; **les données, non**.

### 5.10 Couverture géographique

- **Dakar et banlieue** : DDD (1 277 arrêts), AFTU (2 401 arrêts), BRT (79 arrêts, corridor Guédiawaye ↔ Dakar).
- **TER** : 13 gares, de **Dakar à Diamniadio**.
- **Aucune gare AIBD, ni Sébikotane, ni Keur Moussa** dans le flux TER (recherche explicite : résultat « AUCUNE »).
- Le site vitrine annonce « bus interurbains, taxis et VTC » ; la fiche Play précise « intègre **progressivement** ». **Aucune donnée interurbaine, taxi ou VTC n'est présente** dans les 4 flux.

### 5.11 Opérateurs concernés

| Opérateur | `agency_id` | `agency_name` dans le flux | Réel ? |
|---|---|---|---|
| SETER / TER | `82abd4ab-…` | SETER — `seter.sn` | nommé, non vérifié auprès de l'opérateur |
| Sunu BRT | `BRT` | BRT — *URL vide* | nommé, non vérifié |
| Dakar Dem Dikk | `DDD` | Dakar Dem Dikk — `demdikk.sn` | nommé, non vérifié |
| AFTU | `AFTU` | Association de Financement des Professionnels du transport Urbain — `aftu-senegal.org` | nommé, non vérifié |

**Aucun accord, aucune autorisation, aucun contrat de diffusion n'est produit.** La mention d'un `agency_url` ne vaut pas consentement de l'opérateur.

---

## 6. Licence et droit de réutilisation

| Élément | Constat |
|---|---|
| `openapi.yaml` | déclare `license: name: MIT, url: https://opensource.org/licenses/MIT` |
| `README.md` | section « ## License — MIT License » |
| Fichier `LICENSE` / `COPYING` à la racine du dépôt | **ABSENT** (listing API : seuls `PARTNER_API_README.md` et `README.md`) |
| Licence portant sur les **données** de transport | **AUCUNE** |

Deux points bloquants :

1. La licence MIT annoncée n'est **matérialisée par aucun fichier `LICENSE`**.
2. Même matérialisée, **MIT porterait sur le code, pas sur les données de transport**. Or il n'existe **aucune licence sur les données**, donc **aucun droit de redistribution démontré**.

**Conséquence** : intégrer ces données dans Dakar Bus — a fortiori les embarquer dans un build public — exposerait le projet à un risque juridique, indépendamment de leur qualité.

---

## 7. Risques complémentaires

1. **Identités d'opérateurs écrasées.** Les `route_id` d'origine sont remplacés par des UUID concaténés. Toute réconciliation ultérieure avec un référentiel opérateur devient difficile.
2. **Identifiants d'arrêts non stables.** `D_771`, `A_938` sont des identifiants internes PassBi, sans `stop_code` opérateur garanti.
3. **Viabilité.** 50+ téléchargements, API suspendue, dépôt inactif depuis le 2026-06-22. Dépendre de cette source, c'est dépendre d'un service aujourd'hui à l'arrêt.
4. **Hygiène de sécurité du fournisseur.** `DEPLOYMENT_STATUS.md`, **commité dans un dépôt public**, contient des identifiants de base de données de production en clair (URL PostgreSQL Render complète, utilisateur et mot de passe). `.env.production` est également commité. Les valeurs ne sont pas reproduites ici. Cela n'invalide pas les données, mais renseigne sur la maturité du fournisseur.
5. **Affirmations marketing non étayées.** Le site affiche « 400K tickets issued » et « 95% uptime » en en-tête, tandis que la section « PassBi is already live » affiche des compteurs à **0** (« 0K Tickets issued », « 0 Operators integrated », « 0% Uptime SLA »). À rapprocher des 50+ téléchargements Play Store.
6. **Périmètre incohérent dans le temps.** iMedias (25/11/2025) décrit PassBi comme une **billetterie interopérable** avec « plus de 10 000 utilisateurs actifs et plusieurs dizaines d'opérateurs », lauréate du concours d'innovation du CETUD. La fiche Play de janvier 2026 décrit un **calculateur d'itinéraires** et précise que l'achat de titres n'est **pas encore** intégré. Les deux positionnements ne sont pas réconciliables en l'état.

---

## 8. Décision

### `NOT_READY_FOR_IMPORT`

| Critère | Exigence | État | Verdict |
|---|---|---|---|
| Provenance | Chaîne opérateur/autorité démontrée | Revendiquée via CETUD, **non confirmée** ; `cetud.sn` ne publie aucun GTFS | ❌ |
| Validité | `valid_to` postérieur à la date d'usage | **Échue de 13 à 33 mois** selon le flux | ❌ |
| Fraîcheur | Données à jour | Dernière donnée 2025-08-31 | ❌ |
| Accessibilité | Flux joignable et stable | **API suspendue** | ❌ |
| Licence | Droit de redistribution | **Aucune licence sur les données** | ❌ |
| Rattachement ligne/course/arrêt | `route_id`+`trip_id`+`stop_sequence` | **Présent** | ✅ |
| Temps réel | Flux accessible, frais, rattachable | **Inexistant** (interpolation d'horaires) | ❌ |
| Caractère officiel | Statut établi | Auto-déclaration « non affiliée » + revendication contradictoire | ❌ |

**1 critère sur 8 satisfait.**

### Chaîne imposée, respectée

```
PassBi → audit → provenance → validation → décision d'intégration
                     ↑                        ↑
              non démontrée          NOT_READY_FOR_IMPORT
```

L'étape suivante (`PassBi → modèle GTFS/structure interne → ScheduleProvider`) **n'est pas engagée**, faute de preuves suffisantes.

---

## 9. Éléments qui intéressent le lot TER (signalés, sans modification du rapport TER)

`docs/AUDIT_SOURCE_HORAIRE_TER_2026-09-27.md` **n'a pas été modifié**. Sa conclusion `NOT_READY_FOR_SCHEDULE_IMPORT` **reste valable et se trouve renforcée** : le seul ensemble d'heures exactes TER trouvé à ce jour est échu depuis août 2025 et s'arrête à Diamniadio.

Trois faits nouveaux, à verser au dossier le moment venu :

1. **Topologie confirmée.** Le flux TER contient **exactement 13 gares**, qui correspondent **une à une et dans le même ordre** aux 13 `stop_id` de notre application (vérifié dans `flutter-src/assets/data/dakar_network.json`) :

   | # | `stop_id` (app) | `stop_name` (flux SETER) |
   |---|---|---|
   | 1 | `stop_dakar_ter` | Dakar - Gare ferroviaire |
   | 2 | `stop_colobane` | Colobane |
   | 3 | `stop_hann` | Hann |
   | 4 | `stop_dalifort_ter` | Dalifort |
   | 5 | `stop_baux_maraichers` | Baux Maraîchers |
   | 6 | `stop_pikine` | Pikine |
   | 7 | `stop_thiaroye` | Thiaroye |
   | 8 | `stop_yeumbeul` | Yeumbeul |
   | 9 | `stop_keur_mbaye_fall` | Keur Mbaye Fall |
   | 10 | `stop_pnr` | PNR Rufisque |
   | 11 | `stop_rufisque` | Rufisque |
   | 12 | `stop_bargny` | Bargny |
   | 13 | `stop_diamniadio` | Diamniadio |

   Cela **tranche le conflit préexistant** documenté dans `AUDIT_DONNEES_2026-09-24.md` : ni Keur Massar ni Mbao. La variante de `sentersa.sn` (Keur Massar + Mbao) apparaît comme l'exception. *Le conflit n'a pas été rouvert dans le code ; il est seulement documenté ici.*

2. **Circulations partielles attestées.** Les 6 lignes TER du flux incluent des relations **Dakar ↔ Yeumbeul** et **Dakar ↔ Rufisque**, ce qui rejoint l'information de presse selon laquelle une partie des trains ne fait pas le parcours complet.

3. **Aucune desserte AIBD dans la seule source d'heures exactes disponible.** Le terminus du flux est Diamniadio. Combiné à l'ouverture de l'AIBD annoncée au 2026-09-28, cela confirme qu'**aucune donnée existante ne décrit le réseau qui entre en service**.

---

## 10. Preuve de non-modification du code

Exigence : **n'importer aucune donnée PassBi dans `ScheduleProvider` pendant cet audit.**

`git status --porcelain` à la clôture :

```
 M flutter-src/lib/models/departure_info.dart
 M flutter-src/lib/models/reliability.dart
 M flutter-src/lib/services/data_provider.dart
 M flutter-src/lib/services/data_service.dart
 M flutter-src/test/ui_data_reliability_test.dart
?? docs/AUDIT_SOURCE_HORAIRE_TER_2026-09-27.md
?? flutter-src/lib/models/schedule_models.dart
?? flutter-src/lib/services/clock.dart
?? flutter-src/lib/services/realtime_provider.dart
?? flutter-src/lib/services/schedule_provider.dart
?? flutter-src/lib/services/schedule_service.dart
?? flutter-src/test/schedule_models_test.dart
?? flutter-src/test/schedule_service_test.dart
```

Ces entrées sont **antérieures au présent audit** (lots 3.x et 4.1). Le seul fichier ajouté par cet audit est **`docs/AUDIT_PASSBI_2026-09-27.md`**.

Recherche de toute trace PassBi dans l'arbre de travail :

```
grep -rniI --exclude-dir=.git -e passbi -e senpassbi -e gtfs_folder .
→ (aucune occurrence hors du présent rapport)
```

De même, `git log --all -S "passbi"` ne renvoie rien : **PassBi n'a jamais été présent dans ce dépôt**.

**Preuve par l'arbre Git.** Comparaison du sous-arbre `flutter-src` de l'arbre de travail avec celui du commit `a2254a8` validé par le run CI #125 :

```
flutter-src (arbre de travail, fichiers non suivis inclus) : a8ebd75b6a5f8dfb309c8c8f107339f92f05c670
flutter-src (a2254a8, validé CI #125)                      : a8ebd75b6a5f8dfb309c8c8f107339f92f05c670
=> IDENTIQUES
```

Les deux empreintes étant égales, **aucune ligne de code Flutter n'a été ajoutée, modifiée ou supprimée** depuis le build validé. Le présent audit est strictement documentaire.

*(Méthode : `git add -A` puis `IDX=$(git write-tree)` et `git rev-parse "$IDX:flutter-src"`, l'index ayant été remis dans son état antérieur par `git reset` — aucun commit n'a été créé.)*

Également respecté : `main.dart`, l'interface, le GPS, le routage et les statuts existants sont **inchangés** ; le rapport TER est **inchangé** ; `EmptyScheduleProvider` reste le fournisseur actif.

---

## 11. Conditions de déblocage

Pour qu'une donnée PassBi devienne intégrable, il faudrait **cumulativement** :

1. **Une source primaire identifiée et accessible** — un GTFS publié par le CETUD ou par chaque opérateur, avec `feed_info.txt` renseignant éditeur, version et période de validité.
2. **Une licence explicite sur les données** autorisant la réutilisation et la redistribution.
3. **Une validité courante** : `valid_to` postérieur à la date de mise en production, et un calendrier de service couvrant les jours fériés.
4. **Un flux accessible et stable** : hôte documenté, disponible, versionné, idéalement avec engagement de service.
5. **Pour tout `SCHEDULED`** : provenance + validité + rattachement ligne/course/arrêt **tous trois démontrés**, et `timepoint=1` sur les passages concernés.
6. **Pour tout `REAL_TIME`** : un véritable flux GTFS-RT ou SIRI, frais, rattachable à une course, une ligne et un arrêt. Une position interpolée depuis l'horaire théorique **ne peut pas** être qualifiée `REAL_TIME`.
7. **Un accord écrit des opérateurs**, ou à défaut une publication opérateur directe rendant PassBi inutile comme intermédiaire.

**Recommandation** : contourner PassBi et **s'adresser directement aux opérateurs** (SETER/TER, Sunu BRT, Dakar Dem Dikk, AFTU) et au CETUD. PassBi est utile comme **indice** — il démontre qu'un jeu de 134 lignes et 1 795 arrêts a existé et circule — mais il n'est **pas une source** au sens où ce projet l'entend.

---

## 12. Sources consultées

| Réf. | Source | Consulté le | Usage |
|---|---|---|---|
| P1 | `play.google.com/store/apps/details?id=com.senpassbi.app&hl=fr` | 2026-09-27 | identité, éditeur, 50+, maj 30/01/2026, provenance revendiquée, avertissement |
| P2 | `senpassbi.com` | 2026-09-27 | revendications fonctionnelles, « official partner of CETUD », liens API/web/iOS |
| P3 | `impactsolutionsas.github.io/passbi_core/` | 2026-09-27 | endpoints, base URL de production |
| P4 | `impactsolutionsas.github.io/passbi_core/api/reference/data-models.md` | 2026-09-27 | modèles ; absence de champ de provenance ; TRANSFER 180 s |
| P5 | `impactsolutionsas.github.io/passbi_core/api/openapi.yaml` | 2026-09-27 | contrat des endpoints Schedule ; licence MIT annoncée |
| P6 | `passbi-api.onrender.com/health` et `/v2/routes/list` | 2026-09-27 | **Service Suspended** |
| P7 | `api.senpassbi.com/health` | 2026-09-27 | 404 LiteSpeed |
| P8 | `github.com/impactsolutionsas/passbi_core` (public) | 2026-09-27 | 1 366 fichiers ; `gtfs_folder/` ; `STATUS.md` ; `README.md` ; `vehicle_position.go` |
| P9 | 4 archives `gtfs_*.zip` téléchargées et analysées | 2026-09-27 | preuve primaire : validité, `feed_info`, `timepoint`, topologie |
| P10 | `cetud.sn/`, `/observatoire/systeme-de-donnees/`, `/observatoire/indicateurs-de-trafic/` | 2026-09-27 | absence de GTFS public CETUD |
| P11 | `imedias.net/un-senegalais-modernise-la-mobilite-avec-une-billetterie-digitale/` (25/11/2025) | 2026-09-27 | positionnement billetterie, concours CETUD |
| P12 | Résolutions DNS (`socket.gethostbyname`) | 2026-09-27 | existence des hôtes |

---

**Rapport clos le 2026-09-27.** Aucun commit, aucun push : validation utilisateur attendue.
