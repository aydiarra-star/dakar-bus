# AUDIT_PASSBI_PERSISTENCE — Validation de persistance 2026 des données PassBi

- **Lot** : 4.3
- **Date** : 2026-09-27
- **Règle appliquée** : `date ancienne + vérification de persistance + comparaison aux sources actuelles = niveau de confiance actuel`
- **Statut rendu** : **`PARTIALLY_CONFIRMED`**
- **Code applicatif modifié** : **aucun** (§17)
- **Rapports précédents** : `AUDIT_PASSBI_2026-09-27.md`, `AUDIT_PASSBI_4_2B_2026-09-27.md` — inchangés

---

## 1. Objectif

Déterminer, parmi les données PassBi disponibles, **ce qui est encore valable aujourd'hui et avec quel niveau de preuve**.

Le lot 4.2B avait établi que les feeds sont des snapshots historiques et qu'aucun GTFS 2026 n'existe. Ce lot renverse la question : **l'absence de fichier neuf n'invalide pas la structure ancienne**. Une donnée de 2022 confirmée par une source de 2026 est une donnée persistante.

Il ne s'agit donc plus de dater, mais de **confronter**.

---

## 2. Méthode

1. **Extraction** du référentiel PassBi depuis les 4 GTFS, sans modification des identifiants d'origine.
2. **Collecte de sources actuelles** (2026) : opérateurs d'abord, puis sources secondaires datées.
3. **Confrontation objet par objet** : stations, lignes, ordre des stations, coordonnées, fréquences, plages horaires.
4. **Séparation structure / horaire** : une station peut être `CONFIRMED_CURRENT` pendant que son horaire reste `UNKNOWN`.
5. **Interdiction de l'inférence numérique** : un numéro identique ne crée pas une identité (§10).

### 2.1 Sources actuelles utilisées

| Réf. | Source | Nature | Datation | Usage |
|---|---|---|---|---|
| **C1** | `terdakar.sn/les_horaires_des_trains/` | **opérateur TER** | consulté 2026-09-27 ; actualités jusqu'au 30/03/2026 | fréquences et amplitudes TER |
| **C2** | `demdikk.sn/info-voyageurs/` | **opérateur DDD** | page référencée ; complétée par `demdikk.sn` (actu 02/09/2026) | liste officielle des lignes DDD |
| **C3** | `sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/` | **opérateur BRT** | offre de service « actuelle » | B1/B2, fréquences, renfort de pointe |
| **C4** | `senego.com/services/horaires-brt-ter` | secondaire | 2026-07-27 | les 13 gares TER, numérotées et kilométrées |
| **C5** | `ter-senegal.sn/gares/` | secondaire | 2026-05-14 | gares TER desservies |
| **C6** | `voyage-senegal.info/le-ter-senegal-horaires-tarifs-infos-pratiques/` | secondaire | 2025-10-03 | grille horaire par gare, 13 gares |
| **C7** | `fr.wikipedia.org/wiki/BRT_de_Dakar` | secondaire | 2026-03-26 | 23 stations, ligne **B3 depuis octobre 2025** |
| **C8** | `seneplus.com` — phase 2 SunuBRT | secondaire | 2025-05-05 | B1 21 stations, B2 7 stations |
| **C9** | `dakar_network.json` du projet | **interne, déjà audité** | `audited_at: 2026-09-24` | référentiel courant du projet |
| **C10** | `sentersa.sn/plan-de-transport/` | opérateur SETER | **2023** | **variante contradictoire** (Keur Massar, Mbao) |

**Hiérarchie retenue** : opérateur (C1, C2, C3) > source secondaire datée (C4–C8) > source ancienne (C10). Une source secondaire ne suffit jamais seule à déclarer une persistance (§16, règle sur OSM).

### 2.2 Données PassBi utilisées

Empreintes vérifiées conformes au lot 4.2B (mêmes fichiers, bit pour bit) :

| Feed | SHA-256 | Période | Agence |
|---|---|---|---|
| `gtfs_TER.zip` | `09cb31f4291b28aae87c…7408` | 2025-08-18 → 2025-08-31 | SETER |
| `gtfs_BRT.zip` | `f5e27b7ee446d52a…46c4` | 2024-10-24 → 2024-12-31 | BRT |
| `gtfs_Dem_Dikk.zip` | `578323c9fa437531…7159` | 2022-01-01 → 2023-12-31 | Dakar Dem Dikk |
| `gtfs_AFTU.zip` | `7fae6b438de6177f…f428` | 2022-01-01 → 2023-12-31 | AFTU |

### 2.3 Inventaire extrait (Phase 1)

`source = PASSBI` · `source_date = 2026-02-10` (dépôt dans le commit initial) · identifiants d'origine **conservés tels quels**.

| Réseau | routes | stops | trips | stop_times | services | shapes | calendar_dates |
|---|---|---|---|---|---|---|---|
| TER | 6 | 13 gares (26 enreg.) | 572 | 7 332 | 12 | 0 | 0 |
| BRT | 2 | 28 stations (79 enreg.) | 4 036 | 58 674 | 7 | 6 785 | 69 |
| DDD | 53 | 1 277 | 9 529 | 314 029 | 3 | 3 500 | 40 |
| AFTU | 73 | 2 401 | 11 077 | 677 918 | 1 | 9 498 | 40 |
| **Total** | **134** | **3 783 bruts** | **25 214** | **1 057 953** | **23** | **19 783** | **149** |

---

## 3. TER — validation de persistance (Phase 2)

### 3.1 Les 13 gares

Ordre de la ligne, `stop_id` d'origine conservés, écart mesuré entre la coordonnée PassBi et la coordonnée du projet (distance orthodromique) :

| # | Gare PassBi | `stop_id` PassBi (inchangé) | Dakar Bus `stop_id` | Coordonnée PassBi | Écart | Statut |
|---|---|---|---|---|---|---|
| 1 | Dakar - Gare ferroviaire | `544a27a5-c6c6-4b70-b217-9c15d9b4278a` | `stop_dakar_ter` | 14.67570, -17.43311 | **54 m** | **CONFIRMED_CURRENT** |
| 2 | Colobane | `c70477e7-8391-4388-9a1f-8929a18dc14e` | `stop_colobane` | 14.69837, -17.44142 | **221 m** | **CONFIRMED_CURRENT** |
| 3 | Hann | `f405b86e-9eb3-4c36-ac95-be40a86d80af` | `stop_hann` | 14.72154, -17.43188 | **64 m** | **CONFIRMED_CURRENT** |
| 4 | Dalifort | `61d82f6f-1ba9-4d4e-8f39-d50329992647` | `stop_dalifort_ter` | 14.73410, -17.41962 | **69 m** | **CONFIRMED_CURRENT** |
| 5 | Baux Maraîchers | `d802c3ec-2be9-47b8-b7f4-f8f68af520c6` | `stop_baux_maraichers` | 14.74019, -17.40209 | **172 m** | **CONFIRMED_CURRENT** |
| 6 | Pikine | `650b288f-cce1-4671-a60b-ace229206958` | `stop_pikine` | 14.75050, -17.39086 | **114 m** | **CONFIRMED_CURRENT** |
| 7 | Thiaroye | `956bedfd-e112-472e-895a-48d69ece821d` | `stop_thiaroye` | 14.75907, -17.37968 | **74 m** | **CONFIRMED_CURRENT** |
| 8 | Yeumbeul | `f8ec6c04-478a-40e1-842c-5c9ca5030109` | `stop_yeumbeul` | 14.76501, -17.35587 | **68 m** | **CONFIRMED_CURRENT** |
| 9 | Keur Mbaye Fall | `41016cdb-2f7f-4453-a774-ad1b74a9b876` | `stop_keur_mbaye_fall` | 14.74416, -17.31392 | **9 m** | **CONFIRMED_CURRENT** |
| 10 | PNR Rufisque | `90110d84-209c-48ac-a866-df568477f21d` | `stop_pnr` | 14.72286, -17.28344 | **64 m** | **CONFIRMED_CURRENT** |
| 11 | Rufisque | `1d859f92-c798-4291-9631-262ed863698a` | `stop_rufisque` | 14.71629, -17.27043 | **59 m** | **CONFIRMED_CURRENT** |
| 12 | Bargny | `d30b03f2-46c1-4faf-b53e-dfc6310b916a` | `stop_bargny` | 14.69798, -17.22985 | **74 m** | **CONFIRMED_CURRENT** |
| 13 | Diamniadio | `4445e51b-971b-4f1a-a94a-1ca0c9bef411` | `stop_diamniadio` | 14.71653, -17.19886 | **68 m** | **CONFIRMED_CURRENT** |

**Résultat de la comparaison de coordonnées** : **13 / 13 appariées**, chacune à un arrêt distinct du projet, **dans le même rang de séquence**. Écart moyen **85 m**, écart maximal **221 m** (Colobane), écart minimal **9 m** (Keur Mbaye Fall). Aucun appariement croisé, aucune gare sans vis-à-vis.

Séquence du projet (C9) : `dakar_ter → colobane → hann → dalifort_ter → baux_maraichers → pikine → thiaroye → yeumbeul → keur_mbaye_fall → pnr → rufisque → bargny → diamniadio` — **identique rang par rang** à la séquence PassBi.

**Confirmation par les sources actuelles** : trois sources 2026 indépendantes (C4 juillet 2026, C5 mai 2026, C6 octobre 2025) reproduisent **la même liste dans le même ordre**, avec **Keur Mbaye Fall** et **sans Keur Massar ni Mbao**. C4 les numérote 1 à 13 et les kilombre (Dakar 0 km → Diamniadio 36 km).

**Confiance : HIGH** — PassBi (flux SETER) + source actuelle indépendante concordent, sur le nom, l'ordre et la position.

### 3.2 Le conflit Keur Massar / Mbao est tranché

| Source | Datation | Position |
|---|---|---|
| PassBi (flux SETER) | 2025-08 | Keur Mbaye Fall, pas de Keur Massar ni Mbao |
| C4 senego | 2026-07 | **Keur Mbaye Fall** |
| C5 ter-senegal.sn | 2026-05 | **Keur Mbaye Fall** |
| C6 voyage-senegal.info | 2025-10 | **Keur Mbaye Fall** |
| **C10 sentersa.sn** | **2023** | Keur Massar + Mbao |
| Wikipedia EN | 2026-06 | « M'Bao Keur Massar » (reprise de la dénomination ancienne) |

**La variante Keur Massar / Mbao est la plus ancienne et la moins corroborée.** Elle est classée **CONTRADICTED** au sens du lot : une source existe, mais elle est contredite par des sources plus récentes et plus nombreuses. Rien n'est supprimé pour autant — la dénomination est simplement écartée comme référence.

> Ce point était documenté comme conflit ouvert dans `AUDIT_DONNEES_2026-09-24.md`. Il est ici **tranché par la preuve**, sans modification du JSON.

### 3.3 Lignes TER

| PassBi `route_short_name` | Relation | `route_id` PassBi (inchangé) | Courses | PassBi | État actuel | Statut |
|---|---|---|---|---|---|---|
| `10001` | Dakar → Diamniadio | `544a27a5-…-4445e51b-…` | **262** | 262 courses | C1 publie une exploitation Dakar↔Diamniadio | **PERSISTENT** |
| `20001` | Diamniadio → Dakar | `4445e51b-…-544a27a5-…` | **270** | 270 courses | idem | **PERSISTENT** |
| `14922` | Dakar → Yeumbeul | `544a27a5-…-f8ec6c04-…` | **4** | 4 courses partielles | aucune source actuelle | **UNKNOWN** |
| `20922` | Yeumbeul → Dakar | `f8ec6c04-…-544a27a5-…` | **4** | 4 courses partielles | aucune source actuelle | **UNKNOWN** |
| `13005` | Dakar → Rufisque | `544a27a5-…-1d859f92-…` | **16** | 16 courses partielles | aucune source actuelle | **UNKNOWN** |
| `23001` | Rufisque → Dakar | `1d859f92-…-544a27a5-…` | **16** | 16 courses partielles | aucune source actuelle | **UNKNOWN** |
| | | | **572** | | | |

Les identifiants de lignes PassBi sont des **UUID concaténant les `stop_id` des deux terminus** — par exemple `10001` = `544a27a5-…` (Dakar) + `4445e51b-…` (Diamniadio). Cette construction rend l'identité de la ligne **autoporteuse** : le parcours est encodé dans l'identifiant lui-même. Aucun identifiant n'a été modifié.

Les quatre relations partielles sont **plausibles** — la presse de septembre 2026 évoque des circulations partielles — mais **aucune source actuelle ne les confirme**. Elles restent `UNKNOWN` : ni confirmées, ni supprimées.

### 3.4 Structure calendaire PassBi

Le feed TER contient **12 `service_id`**, dont 6 desservent la relation principale :

| `service_id` (préfixe) | Jours | Courses | Amplitude |
|---|---|---|---|
| `38f23463-…` | **lun → sam** | 160 | 05:30 → 22:06 |
| `8a62eb4e-…` | mer → sam | 129 | 06:30 → 22:06 |
| `68f0b070-…` | lun → ven | 22 | 06:35 → 21:37 |
| `ac8d71e0-…` | mer → ven | 25 | 05:29 → 21:37 |
| `cec3ed22-…` | jeu → sam | 21 | 06:42 → 14:30 |
| `db5eb1cc-…` / `1ed51a8d-…` | **dimanche** | 101 + 101 | **06:25 → 22:05** |
| 5 autres | renforts ponctuels | 1 à 7 | variables |

**La structure calendaire est celle d'un service réel et différencié** (semaine / dimanche / renforts par jour), pas d'une grille uniforme. C'est un indice de provenance opérateur, cohérent avec l'attribution SETER.


---

## 4. Nouvelles stations TER (Phase 3)

| Station | Preuve | Date | Source | Statut |
|---|---|---|---|---|
| **AIBD** | Ouverture annoncée ; C4 décrit déjà « Gare de AIBD : terminus » ; MITTA/presse annoncent la mise en service | 2026-09-28 (annoncée) | presse sept. 2026, C4 (2026-07) | **PROVISIONAL** |
| **Sébikotane** | Aucune source actuelle trouvée ce jour ; « en construction » en juin 2026 | — | — | **UNKNOWN** |
| **Keur Moussa** | Cité dans l'EESS de la BAD (2016) comme **commune traversée** par la phase 2, jamais comme gare | 2016 | AfDB, EESS nov. 2016 | **UNKNOWN** |

**Keur Moussa n'est pas une station.** Le document de la BAD liste les **communes traversées** (Diamniadio, Sébikotane, Keur Moussa, Diass) — ce n'est pas une liste de gares. Conformément à la règle du lot, une commune traversée n'est pas convertie en station.

**Aucune des trois n'est ajoutée à Dakar Bus.** `dakar_network.json` conserve 13 gares ; `services_not_exposed` et les statuts existants sont inchangés.

---

## 5. Horaires TER (Phase 4)

Question posée : *« Existe-t-il une preuve actuelle que les horaires PassBi ont changé, ou qu'ils restent compatibles avec le service actuel ? »*

### 5.1 Grille semaine — **catégorie C : contredite**

| Élément | PassBi (août 2025) | C1 terdakar.sn (2026-09-27) | Verdict |
|---|---|---|---|
| Fréquence | **12 min** (77 intervalles sur 80) | **10 min** | **CONTRADICTED** |
| Premier départ de Dakar | **05:30** | **05:45** | **CONTRADICTED** |
| Dernier départ | 22:06 | **22:05** | écart de 1 min |
| Soirée | 24 min après 20:54 (3 intervalles) | 20 min de 21h05 à 22h05 | **CONTRADICTED** |
| Amplitude | 05:30 → 22:06 | 05:45 → 22:05 | partiellement compatible |

Mesure PassBi, service `38f23463-…` (lundi–samedi), ligne `10001` au départ de Dakar : **81 départs distincts, 05:30 → 22:06**, intervalles `{12 min : 77, 24 min : 3}`.

**Conclusion** : la grille semaine PassBi **ne décrit plus le service**. `schedule_status = UNKNOWN`. La source actuelle (C1) est prioritaire.

### 5.2 Grille dimanche et jours fériés — **catégorie A : confirmée**

| Élément | PassBi (août 2025) | C1 terdakar.sn (2026-09-27) | Verdict |
|---|---|---|---|
| Premier départ | **06:25** | **6h25** | **identique** |
| Fréquence | **20 min** — 45 intervalles sur 49 valent exactement 1200 s | **toutes les 20 minutes** | **identique** |
| Dernier départ | **22:05** | **22h05 dernier départ** | **identique** |

Mesure PassBi, service `db5eb1cc-…` (dimanche), ligne `10001` au départ de Dakar : **50 départs distincts, 06:25 → 22:05**, répartition des intervalles `{1200 s : 45, 1080 s : 1, 900 s : 1, 300 s : 1, 120 s : 1}`. Le service `1ed51a8d-…` (dimanche, sens retour) reproduit **exactement la même distribution**.

**Test de concordance exhaustive.** La série officielle actuelle (06:25, toutes les 20 min, jusqu'à 22:05) produit **48 départs**. Confrontation avec les 50 départs PassBi :

```
départs PassBi retrouvés dans la série officielle : 48/50
départs officiels absents de PassBi               : 0
départs PassBi hors série officielle              : 18:03, 19:50  (2 services supplémentaires)
```

Les quatre intervalles non standard correspondent précisément à ces deux renforts et à leur voisinage (2 min, 5 min, 15 min, 18 min).

**Aucun départ officiel actuel n'est absent de PassBi.** Les deux départs excédentaires sont des renforts, pas des contradictions.

**Conclusion** : la grille dominicale PassBi est **confirmée par la source opérateur actuelle**. C'est le résultat le plus fort de ce lot.

### 5.3 Corroboration par une source secondaire

C6 (voyage-senegal.info, 2025-10) publie une grille complète par gare, aux 13 gares, avec depuis Dakar : `21:05, 21:25, 21:45, 22:05` puis `11:25, 11:45, 12:05, 12:25, 12:45…` — **une série à 20 minutes identique à celle de PassBi**. Source secondaire, donc corroboration et non preuve autonome.

### 5.4 Statut horaire par objet

| Objet | `STRUCTURE_STATUS` | `SCHEDULE_STATUS` |
|---|---|---|
| Les 13 gares TER | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Grille dimanche/fériés | CONFIRMED_CURRENT | **PERSISTENCE_SUPPORTED** (non `SCHEDULED`) |
| Grille semaine | CONFIRMED_CURRENT | **UNKNOWN** (contredite) |
| Relations partielles | UNKNOWN | **UNKNOWN** |

Même confirmée, la grille dominicale **n'est pas promue en `SCHEDULED`** : il manque la publication opérateur d'une grille horaire datée et signée, avec date d'entrée en vigueur (§14).

---

## 6. Fréquences TER (Phase 5)

Conformément à la règle : une fréquence confirmée ne valide pas rétroactivement des heures exactes.

| Objet | Valeur PassBi | Source actuelle | Qualification |
|---|---|---|---|
| Fréquence dimanche/fériés | 20 min | C1 : « toutes les 20 minutes » | `frequency_current = CONFIRMED` |
| Fréquence semaine | 12 min | C1 : « toutes les 10 minutes » | `frequency_current = CONFIRMED` **(valeur actuelle = 10 min)** ; valeur PassBi **CONTRADICTED** |
| Amplitude dimanche | 06:25 → 22:05 | C1 : 6h25 → 22h05 | `CONFIRMED` |
| Amplitude semaine | 05:30 → 22:06 | C1 : 5H45 → 22H05 | `CONTRADICTED` sur le premier départ |
| Départs exacts PassBi (semaine) | 05:30, 05:42, 05:54… | aucune | `exact_passbi_departures = HISTORICAL / UNCONFIRMED` |
| Départs exacts PassBi (dimanche) | 06:25, 06:45, 07:05… | série officielle identique à 48/48 | `exact_passbi_departures = PERSISTENCE_SUPPORTED` |

**Écriture imposée par le lot, appliquée littéralement :**

```
fréquence dimanche      frequency_current = CONFIRMED
                        exact_passbi_departures = PERSISTENCE_SUPPORTED (48/48)

fréquence semaine       frequency_current = CONFIRMED (10 min, valeur ACTUELLE)
                        exact_passbi_departures = HISTORICAL / UNCONFIRMED (12 min ≠ 10 min)
```

**Note de prudence** : la presse de septembre 2026 évoque un passage à 8 minutes avec l'extension AIBD. L'opérateur (C1) indique 10 minutes. **La source opérateur prime** ; la valeur de presse n'est pas retenue.

---

## 7. BRT (Phase 6)

### 7.1 Ligne B2 — correspondance exacte

| Critère | PassBi (2024) | Source actuelle | Verdict |
|---|---|---|---|
| Identité | `B2`, `route_type=3` | B2 semi-express (C3, C7, C8) | **PERSISTENT** |
| Origine | PETERSEN (= Papa Gueye Fall) | Papa Gueye Fall | **identique** |
| Destination | GUEDIAWAYE (= Préfecture) | Préfecture de Guédiawaye | **identique** |
| Nombre de stations | **7** | **7** (C3, C7, C8) | **identique** |
| Ordre des stations | Petersen → Place de la Nation → Grand Dakar → Sacré-Cœur → Grand Médine → Dalal Jam → Guédiawaye | C8 : Papa Guèye Fall, Place de la Nation, Grand Dakar, Sacré-Cœur, Grand Médine, Dalal Jam, Préfecture de Guédiawaye | **identique, station par station** |
| Direction | 2 sens (894 + 840 courses) | 2 sens | **identique** |
| Fréquence | **6 min** (140 intervalles de 6 min) | C3/C7 : **6 min** | **identique** |
| Service | lundi–samedi | C3/C7 : lundi–samedi | **identique** |

**Confiance : HIGH.** Aucun écart. C'est la correspondance la plus complète du lot.

### 7.2 Ligne B1

| Critère | PassBi (2024) | Source actuelle | Verdict |
|---|---|---|---|
| Identité | `B1` omnibus | B1 omnibus | **PERSISTENT** |
| Origine / destination | Guédiawaye ↔ Petersen | idem | **identique** |
| Stations desservies | **21** | C8 (2025-05) : « B1 compte désormais **21 stations** » ; C7 (2026) : réseau de **23** stations | **PERSISTENT**, réseau étendu depuis |
| Ordre | Guédiawaye → Golf Nord → Dalal Jam → Golf Sud → Ndingala → Parcelles → Croisement 22 → Police des Parcelles → Grand Médine → Cardinal Hyacinthe → Scat Urbam → Khar Yalla → Liberté 6 → Liberté 5 → Sacré-Cœur → Liberté 1 → Grand Dakar → Dial Diop → Place de la Nation → Grande Mosquée → Petersen | C9 (Dakar Bus, 23 stations) contient **ces 21 dans le même ordre**, plus 2 | **les 21 sont toutes retrouvées** |
| Fréquence | 6 min | C3/C7 : 6 min | **identique** |
| Plage horaire | 6h → 21h | C3 : agences 06H–21H ; C7 : 6 A.M.–9 P.M. | **identique** |
| Service | tous les jours | C3 : « tous les jours » | **identique** |

**Les 2 stations manquantes chez PassBi** — `GADAYE` et `FITH MITH` — **sont présentes dans le `stops.txt` de PassBi** (identifiants `1:GAD`, `1:FMI`) mais **ne sont desservies par aucune course**. Elles figurent dans le référentiel actuel du projet (C9 : « Gadaye - Cambérène », « Fith Mith »).

**Lecture** : PassBi disposait déjà de ces deux stations dans son référentiel d'arrêts, sans les intégrer à l'itinéraire B1. Ce n'est donc **pas une donnée absente**, mais une **donnée non exploitée**. Statut : **PERSISTENT** pour la structure, **CHANGED** pour l'itinéraire B1 (21 → 23).

### 7.3 Renfort de pointe — persistance confirmée

PassBi contient une **variante B1 de 14 stations** (Pôle Grand Médine → Petersen), 258 courses, réparties ainsi :

```
heures de départ : {6h: 48, 7h: 42, 8h: 48, 9h: 42, 17h: 24, 18h: 24, 19h: 24, 20h: 6}
```

C3 (sunubrt.sn) documente : « Un renfort de ligne qui circule entre Petersen et Grand Médine aux heures de pointes. **Le matin dans le sens Petersen de 6h à 10h, le soir dans le sens Grand-Médine de 16h à 20h.** »

**Concordance** : tronçon identique (Petersen ↔ Grand Médine), fenêtre matinale 6h–9h observée dans une fenêtre annoncée 6h–10h, fenêtre du soir 17h–20h dans une fenêtre annoncée 16h–20h. Statut : **PERSISTENCE_SUPPORTED**, confiance **MEDIUM** (la fenêtre observée est incluse dans la fenêtre annoncée, sans la recouvrir exactement).

### 7.4 Différence documentée : la ligne B3

| Élément | Valeur |
|---|---|
| PassBi | **absente** (2 lignes seulement) |
| Source actuelle | C7 : « la ligne **B3** (depuis **Octobre 2025**) » ; C9 : `services_not_exposed.brt_b3`, `data_status: CONFIRMED`, source `sunubrt.sn/brt-3-semi-express/` |
| Classification | **NEW_CURRENT** |

**Fait notable** : le `stops.txt` de PassBi contient **`GUEULE TAPEE`** (`1:GTA`), non desservie par B1 ni B2 — et C9 liste **« Gueule Tapée » comme station officielle de la B3**. Le référentiel d'arrêts PassBi **anticipait donc une station de la B3**, sans l'exploiter.

**Règle appliquée** : « ne pas supposer qu'un changement de nom implique un changement de parcours ». Ici il ne s'agit ni d'un renommage ni d'un changement de parcours, mais d'une **ligne nouvelle** — traitée comme telle, sans fusion.

### 7.5 Stations PassBi non desservies

| Station PassBi | `stop_id` | Lecture |
|---|---|---|
| GADAYE | `1:GAD` | station réelle du réseau actuel (C9) — non exploitée par PassBi |
| FITH MITH | `1:FMI` | station réelle du réseau actuel (C9) — non exploitée |
| GUEULE TAPEE | `1:GTA` | station B3 actuelle (C9) — non exploitée |
| P.E DE PETERSEN | `1:PEP` | **doublon** de PETERSEN (même lieu, 130 m) |
| P.E DE GRAND-MEDINE | `1:PEM` | **doublon** de GRAND MEDINE |
| P.E. DE GUEDIAWAYE | `1:PEG` | **doublon** de GUEDIAWAYE |
| POLE GRAND MEDINE | `1:QPEM` | **triplé** avec GRAND MEDINE et P.E DE GRAND-MEDINE |

**Règle appliquée** : « ne jamais fusionner deux arrêts uniquement parce qu'ils sont proches géographiquement ». Les doublons sont **signalés**, pas fusionnés. Leur rapprochement exigerait une preuve opérateur.

---

## 8. DDD (Phase 7)

Source actuelle : **C2 `demdikk.sn/info-voyageurs/`** — liste officielle des lignes urbaines, banlieue et dessertes TER.

**Base d'appariement** : le numéro de ligne **et** les terminus. Le code PassBi est de la forme `D{numéro}{initiales des terminus}` — par exemple `D501GP` = ligne 501, **G**are de Dakar ↔ **P**alais 2, ce que C2 confirme littéralement (« LIGNE 501 : GARE DE DAKAR ↔ PALAIS 2 »). L'appariement ne repose donc **pas sur le seul numéro**.

### 8.1 Résultat

| Classification | Nombre | Détail |
|---|---|---|
| **PERSISTENT** | **34** | numéros retrouvés chez l'opérateur avec terminus compatibles |
| **NOT_FOUND** | **19** | aucune correspondance dans la liste actuelle |
| **NEW_CURRENT** | **0** | aucune ligne actuelle absente de PassBi |
| **CHANGED** | 0 au niveau de l'existence ; à vérifier au niveau des itinéraires |  |

### 8.2 Les 34 lignes persistantes

`D1LP` (Parcelles Assainies ↔ Place Leclerc) · `D2DL` (Daroukhane ↔ Place Leclerc) · `D4DL` (Liberté 5 ↔ Place Leclerc) · `D5GP` (Guédiawaye ↔ Palais 1) · `D6CP` (Cambérène 2 ↔ Palais 2) · `D7OP` (Ouakam ↔ Palais 2) · `D8PL` (Aéroport LSS ↔ Palais 2) · `D9P0` (Liberté 6 ↔ Palais 2) · `D10LP` (Liberté 5 ↔ Palais 2) · `D11KL` (Keur Massar ↔ Lat Dior) · `D12GP` (Guédiawaye ↔ Palais 1) · `D13T0` (Liberté 5 ↔ Palais 2) · `D15PR` (Rufisque ↔ Palais 1, 15A/15B) · `D16MP` (Malika ↔ Palais 1, 16A/16B) · `D18D` (Dieuppeul ↔ Centre-Ville) · `D20D` (Dieuppeul ↔ Centre-Ville) · `D23P2` (Parcelles Assainies ↔ Palais 1) · `D121LS` (Scat Urbam ↔ Leclerc) · `D208BR` (Bayakh ↔ Rufisque) · `D213DR` (Rufisque ↔ Dieuppeul) · `D217OT` (Thiaroye ↔ Ouakam) · `D218AT` (Thiaroye ↔ Aéroport LSS) · `D219DO` (Daroukhane ↔ Ouakam) · `D220DR` (Rufisque ↔ Guédiawaye) · `D221AG` (Gadaye ↔ Almadies) · `D227TM` (Keur Massar ↔ Parcelles) · `D228RY` (Rufisque ↔ Yenne) · `D232AB` (Baux Maraichers ↔ Aéroport LSS) · `D233 M` (Baux Maraichers ↔ Palais 1) · `D234JL` (Jaxaay ↔ Leclerc) · `D501GP` · `D502CU` · `D503CB` · `D504DS`

**Les 4 dessertes de gares TER (`D501`–`D504`) persistent toutes.** C2 les publie toujours comme « Dessertes Gares du TER ».

### 8.3 Les 19 lignes non retrouvées

`D102CC` · `D103AC` · `D105CP` · `D111LY` · `D210TM` · `D223DP` · `D231BJ` · `D301MP` · `D305PY` · `D308OP` · `D311TT` · `D315RY` · `D319SL` · `D323PT` · `D401AO` · `D402AT` · `D403AP` · `D404AL` · `D405AD`

**`NOT_FOUND` ≠ `SUPPRIMED`.** Ces 19 lignes forment des séries cohérentes (1xx, 2xx, 3xx, 4xx) qui pourraient correspondre à des services non publiés sur la page « info voyageurs », à des lignes interurbaines, ou à des lignes effectivement retirées. **Aucune preuve ne permet de trancher.** Elles restent au référentiel comme lignes historiques 2022-2023.

### 8.4 Confrontation avec les 12 lignes DDD du projet

| Projet | PassBi | `demdikk.sn` | Lecture |
|---|---|---|---|
| `ddd_1` | ✅ `D1LP` | ✅ ligne 1 | **PERSISTENT** — mais itinéraire interne `CONFLICTING` (déjà documenté dans C9) |
| `ddd_3` | ❌ | ❌ | **UNKNOWN** — dans aucune des deux sources |
| `ddd_7` | ✅ `D7OP` | ✅ ligne 7 | **PERSISTENT** |
| `ddd_8` | ✅ `D8PL` | ✅ ligne 8 | **PERSISTENT** |
| `ddd_9` | ✅ `D9P0` | ✅ ligne 9 | **PERSISTENT** |
| `ddd_10` | ✅ `D10LP` | ✅ ligne 10 | **PERSISTENT** |
| `ddd_11` | ✅ `D11KL` | ✅ ligne 11 | **PERSISTENT** |
| `ddd_12` | ✅ `D12GP` | ✅ ligne 12 | **PERSISTENT** |
| `ddd_14` | ❌ | ❌ | **UNKNOWN** — Moovit mentionne une ligne 14 (source tierce, non retenue seule) |
| `ddd_15` | ✅ `D15PR` | ✅ ligne 15A/15B | **PERSISTENT** |
| `ddd_20` | ✅ `D20D` | ✅ ligne 20 | **PERSISTENT** |
| `ddd_23` | ✅ `D23P2` | ✅ ligne 23 | **PERSISTENT** |

**10 sur 12 persistantes.**

### 8.5 L'écart de couverture DDD est chiffré

| Source | Nombre de lignes DDD |
|---|---|
| **PassBi** | **53** |
| `demdikk.sn` (C2) | 34 identifiants distincts (dont variantes A/B) |
| **Dakar Bus (C9)** | **12** |
| Dakar Transit (tiers) | 46 |
| CETUD, « Dakar en Commun » (févr. 2024) | 130 lignes tous opérateurs |

**PassBi est, de toutes les sources examinées, la plus complète pour DDD** — et la seule à fournir coordonnées, itinéraires et `shapes`. C'est sa principale valeur pour ce projet : le projet n'expose que 12 lignes DDD sur les 53 documentées par PassBi et les 34 publiées par l'opérateur.

---

## 9. AFTU (Phase 8)

### 9.1 Le piège de numérotation est réel et bloquant

| Source | Numéros |
|---|---|
| **PassBi** | 73 codes : **1, 2, 3, 4, 5, puis 24 → 91** |
| **Dakar Bus (C9)** | **1 → 72 en continu** |
| CETUD (via C9 `audit_note`) | 72 lignes — **le compte est officiel, la numérotation ne l'est pas** |
| Dakar Transit (tiers) | 64 |

**Chevauclement impossible** :

```
numéros PassBi absents de 1..72 : 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91
numéros 1..72 absents de PassBi : 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
```

PassBi **saute les numéros 6 à 23** et **pousse jusqu'à 91**. Le projet numérote 1 à 72 sans trou. **Les deux séries ne peuvent pas être superposées.**

### 9.2 Conséquence

| Objet | Statut |
|---|---|
| Les 73 lignes AFTU PassBi | **UNKNOWN** — `IDENTITY_UNCONFIRMED` |
| Les 72 lignes AFTU du projet | **UNKNOWN** — numérotation issue d'observations terrain, déjà signalée comme telle dans C9 |
| Le **compte** de lignes AFTU | **PERSISTENCE_SUPPORTED** — PassBi 73, CETUD 72 : mêmes ordres de grandeur, cohérents |

`dakar_network.json` le dit déjà explicitement pour `aftu_30` : *« Le nombre de lignes AFTU (72) est officiel (CETUD) ; la numérotation 1–72 et cet itinéraire proviennent d'observations terrain non vérifiées. »*

**PassBi apporte ici une information que le projet n'a pas** : les **codes officiels** (`A1HL`, `A24NU`, `A91AD`…), où le suffixe semble encoder les terminus. C'est une piste de réconciliation pour un lot ultérieur — **pas une correspondance établie**.

**Aucune ligne AFTU n'est déclarée supprimée.** Aucune correspondance n'est fabriquée.

---

## 10. Identités des lignes (Phase 10)

Règle appliquée : aucune identité déduite du seul numéro.

| Réseau | Base d'appariement utilisée | Résultat |
|---|---|---|
| **TER** | noms de gares + coordonnées + ordre | identité **établie** (13/13) |
| **BRT** | nom de ligne (B1/B2) + origine + destination + liste et ordre des stations | identité **établie** |
| **DDD** | numéro **et** initiales de terminus dans le code PassBi, confrontés à C2 | identité **établie** pour 34 lignes |
| **AFTU** | **aucune base disponible** | **`IDENTITY_UNCONFIRMED`** pour les 73 |

### 10.1 Cas explicitement non déduits

| Cas | Tentation | Décision |
|---|---|---|
| `aftu_30` (projet) vs `A30CG` (PassBi) | même numéro 30 | **IDENTITY_UNCONFIRMED** — les séries ne se superposent pas |
| `tata_218` / `tata_219` (projet) vs `D218AT` / `D219DO` (PassBi DDD) | mêmes numéros 218/219 | **IDENTITY_UNCONFIRMED** — opérateurs différents (Tata vs DDD), aucune preuve de reprise |
| `tata_50` vs `D501GP` | proximité numérique | **IDENTITY_UNCONFIRMED** |
| B2 « Express » (projet) vs B2 « semi-express » (opérateur) | même sigle B2 | identité **établie** (7 stations identiques) ; C9 note déjà que « l'express est B4 » |

---

## 11. Arrêts (Phase 9)

| Réseau | Arrêts PassBi | Correspondance actuelle | Statut |
|---|---|---|---|
| **TER** | 13 gares (26 enreg., station + quai) | 13/13 retrouvées, même ordre, C4 + C5 + C6 | **CURRENT_MATCH : nom ✅ coordonnées ✅ route ✅** |
| **BRT** | 22 stations desservies (+ 6 non desservies) | 21/21 de B1 dans C9 ; 7/7 de B2 dans C9 | **CURRENT_MATCH : nom ✅ coordonnées ✅ route ✅** |
| **DDD** | 1 277 | aucune liste d'arrêts opérateur publiée ; C9 n'expose que 3 à 5 arrêts par ligne | **UNCONFIRMED** |
| **AFTU** | 2 401 | idem | **UNCONFIRMED** |

### 11.1 Correspondances de noms documentées (pas de fusion automatique)

| PassBi | Actuel (C9) | Distance | Traitement |
|---|---|---|---|
| `PETERSEN` (`1:PGF`) | Papa Gueye Fall - PEM Petersen | même pôle | **NAME_MATCH documenté** — le pôle s'appelle « Petersen – Papa Gueye Fall » (C7) |
| `GUEDIAWAYE` (`1:GDW`) | Préfecture Guédiawaye - PEM | même pôle | **NAME_MATCH documenté** |
| `DALAL JAM` (`1:HDJ`) | Hôpital Dalal Jamm | même lieu | **NAME_MATCH documenté** |
| `CARDINAL HYACINT` (`1:CHT`) | Cardinal Hyacinthe Thiandoum | même lieu | **NAME_MATCH documenté** |
| `KHAR YALLA` (`1:KYA`) | Khar Yallah | variante orthographique | **NAME_MATCH documenté** |
| `PLACE DE LA NATION` (`1:PLN`) | Place de la Nation - Obélisque | même lieu | **NAME_MATCH documenté** |
| `PARCELLES` (`1:PAR`) | Parcelles Assainies | même lieu | **NAME_MATCH documenté** |

**Un changement mineur de nom ne crée pas un nouvel arrêt** : ces sept paires sont des variantes orthographiques ou des compléments de dénomination, relevées comme telles.

**À l'inverse, aucune fusion n'est opérée** entre `GRAND MEDINE` / `P.E DE GRAND-MEDINE` / `POLE GRAND MEDINE`, ni entre les trois paires PEM — malgré leur proximité (≤ 130 m). La proximité géographique seule ne suffit pas.

---

## 12. Nouvelles données 2026 (absentes de PassBi)

| Donnée | Source | Statut |
|---|---|---|
| **Ligne BRT B3** (depuis octobre 2025), 7 stations | C7, C9 (`sunubrt.sn/brt-3-semi-express/`) | **NEW_CURRENT** |
| **Stations Gadaye et Fith Mith** intégrées à l'itinéraire B1 | C9 (23 stations) | **NEW_CURRENT** (présentes dans le `stops.txt` PassBi mais non desservies) |
| **AIBD**, gare TER | presse sept. 2026, C4 | **PROVISIONAL** |
| **Fréquence TER semaine 10 min** (au lieu de 12) | C1 | **NEW_CURRENT** — remplace la valeur PassBi |
| **Premier départ TER semaine 05:45** (au lieu de 05:30) | C1 | **NEW_CURRENT** |
| **7 nouveaux arrêts interurbains DDD** (Mbirkilane, Malem Hodar, Nioro du Rip, Kanel, Bounkiling, Koumpentoum, Mbacké) | `demdikk.sn`, actu 02/09/2026 | **NEW_CURRENT** — hors périmètre urbain |
| Fréquence TER 8 min (extension AIBD) | presse sept. 2026 | **non retenue** — contredit l'opérateur (C1 : 10 min) |

**Aucune de ces données n'est intégrée.** Elles sont consignées pour le lot suivant.

---

## 13. Matrice de persistance (Phase 11)

| Réseau | Objet | PassBi | État actuel | Preuve actuelle | Statut | Confiance |
|---|---|---|---|---|---|---|
| TER | 13 gares | Oui | retrouvées à l'identique | C4 (2026-07), C5 (2026-05), C6 | **PERSISTENT** | **HIGH** |
| TER | Ordre des gares | Oui | identique | C4 numérote 1→13 dans le même ordre | **PERSISTENT** | **HIGH** |
| TER | Dakar ↔ Diamniadio | Oui | en service | C1 | **PERSISTENT** | **HIGH** |
| TER | Relations partielles (4) | Oui | non confirmé | aucune | **UNKNOWN** | LOW |
| TER | Grille dimanche | Oui | **confirmée** | C1 (6h25 / 20 min / 22h05) | **PERSISTENT** | **HIGH** |
| TER | Grille semaine | Oui | **contredite** | C1 (10 min / 5h45) | **CONTRADICTED** | **HIGH** |
| TER | AIBD | Non | annoncée | presse sept. 2026 | **PROVISIONAL** | MEDIUM |
| TER | Sébikotane | Non | inconnu | aucune | **UNKNOWN** | UNKNOWN |
| TER | Keur Moussa | Non | commune traversée | BAD 2016 | **UNKNOWN** | UNKNOWN |
| BRT | B2 identité + 7 stations + ordre | Oui | **identique** | C3, C7, C8 | **PERSISTENT** | **HIGH** |
| BRT | B1 identité + 21 stations + ordre | Oui | retrouvées dans un réseau à 23 | C7, C8, C9 | **PERSISTENT** | **HIGH** |
| BRT | Itinéraire B1 (21 → 23) | Oui | étendu | C9 | **CHANGED** | MEDIUM |
| BRT | Fréquence 6 min | Oui | identique | C3, C7 | **PERSISTENT** | **HIGH** |
| BRT | Renfort de pointe Petersen↔Grand Médine | Oui | documenté | C3 | **PERSISTENT** | MEDIUM |
| BRT | Plage 6h–21h | Oui | identique | C3, C7 | **PERSISTENT** | **HIGH** |
| BRT | Ligne B3 | Non | en service depuis 10/2025 | C7, C9 | **NEW_CURRENT** | **HIGH** |
| BRT | Doublons PEM (4 enreg.) | Oui | non tranché | aucune | **UNKNOWN** | LOW |
| DDD | 34 lignes | Oui | publiées par l'opérateur | C2 | **PERSISTENT** | **HIGH** |
| DDD | 19 lignes (1xx, 210, 223, 231, 3xx, 4xx) | Oui | non retrouvées | aucune | **UNKNOWN** | LOW |
| DDD | 1 277 arrêts | Oui | non vérifiable | aucune liste opérateur | **UNKNOWN** | UNKNOWN |
| AFTU | 73 lignes | Oui | identité non établie | aucune | **UNKNOWN** | UNKNOWN |
| AFTU | Compte de lignes (~72-73) | Oui | cohérent avec CETUD | C9 `audit_note` | **PERSISTENT** | MEDIUM |
| AFTU | 2 401 arrêts | Oui | non vérifiable | aucune | **UNKNOWN** | UNKNOWN |

**Aucun score numérique n'est utilisé**, conformément à la consigne.

---

## 14. Niveaux de confiance et statuts (Phases 12 et 13)

### 14.1 Répartition des niveaux de confiance

| Niveau | Définition appliquée | Objets |
|---|---|---|
| **HIGH** | PassBi + source actuelle indépendante concordent | 13 gares TER + ordre + relation Dakar↔Diamniadio + grille dimanche · B2 (7 stations, ordre, fréquence, service) · B1 (21 stations, ordre, fréquence, plage) · 34 lignes DDD · ligne B3 (côté actuel) |
| **MEDIUM** | PassBi + éléments actuels indirects concordent | renfort de pointe BRT · itinéraire B1 étendu · relations partielles TER (plausibles) · compte AFTU · AIBD |
| **LOW** | PassBi seul, éléments limités | 19 lignes DDD `NOT_FOUND` · 4 doublons PEM BRT |
| **UNKNOWN** | persistance indéterminable | 73 lignes AFTU · 3 678 arrêts DDD+AFTU · Sébikotane · Keur Moussa |

### 14.2 Séparation `STRUCTURE_STATUS` / `SCHEDULE_STATUS`

C'est la distinction centrale du lot. Exemples :

| Objet | `STRUCTURE_STATUS` | `SCHEDULE_STATUS` |
|---|---|---|
| Gare TER de Dakar | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Les 13 gares TER | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Grille TER dimanche | CONFIRMED_CURRENT | **PERSISTENCE_SUPPORTED** |
| Grille TER semaine | CONFIRMED_CURRENT | **UNKNOWN** (contredite) |
| Station BRT Sacré-Cœur | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Ligne BRT B2 | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Fréquence BRT 6 min | CONFIRMED_CURRENT | **ESTIMATED** (fréquence, jamais horaire exact) |
| Ligne DDD 218 | **CONFIRMED_CURRENT** | **UNKNOWN** |
| Ligne DDD 401 | **UNKNOWN** | **UNKNOWN** |
| Ligne AFTU (toutes) | **UNKNOWN** | **UNKNOWN** |

**Une station fiable est conservée même quand son horaire est inconnu.** Aucun `SCHEDULE_STATUS` n'est élevé du fait de la seule solidité structurelle.

### 14.3 Temps réel

# `REAL_TIME = NON`

Aucun flux GTFS-RT ou SAE n'existe chez PassBi. Rappel des preuves du lot 4.2B : `VehiclePositionEstimator` est du **code mort** (jamais instancié), `InterpolateStopTimes` n'est **jamais appelée**, la roadmap porte `- [ ] GTFS-RT support` et `- [ ] Real-time vehicle tracking` non cochées, et l'API est suspendue. **Aucune interpolation ne sera étiquetée `REAL_TIME`.**

---

## 15. Éléments confirmés, non confirmés, contredits (Phases 14, 15, 16)

### 15.1 Confirmés

1. **Les 13 gares TER, leurs noms, leur ordre** — trois sources 2026 indépendantes.
2. **Keur Mbaye Fall** appartient bien au réseau ; **Keur Massar et Mbao n'en font pas partie**.
3. **La grille TER du dimanche et des jours fériés** : 06:25, toutes les 20 minutes, dernier départ 22:05 — **48 départs officiels actuels sur 48 retrouvés dans PassBi**.
4. **La ligne BRT B2 intégralement** : identité, 7 stations, ordre, fréquence 6 min, service lundi–samedi.
5. **La ligne BRT B1** : identité, ses 21 stations et leur ordre, fréquence 6 min, amplitude 6h–21h, service quotidien.
6. **Le renfort de pointe BRT** Petersen ↔ Grand Médine.
7. **34 lignes DDD**, dont les 4 dessertes de gares TER (`D501`–`D504`).
8. **L'ordre de grandeur du parc AFTU** (72–73 lignes).

### 15.2 Non confirmés

1. **Les 73 lignes AFTU** — numérotation incompatible avec celle du projet, aucune base d'appariement.
2. **19 lignes DDD** — absentes de la liste opérateur actuelle, sans preuve de suppression.
3. **3 678 arrêts DDD et AFTU** — aucune liste d'arrêts opérateur publiée.
4. **Les 4 relations TER partielles** (Dakar↔Yeumbeul, Dakar↔Rufisque).
5. **Les 4 doublons PEM du BRT** et le statut exact des 6 stations PassBi non desservies.
6. **Les itinéraires détaillés** des 34 lignes DDD persistantes : l'existence est confirmée, le tracé ne l'est pas.
7. **`ddd_3` et `ddd_14`** du projet — dans aucune des deux sources.

### 15.3 Contredits

| Donnée PassBi | Contradiction | Source |
|---|---|---|
| Fréquence TER semaine **12 min** | **10 min** | C1 |
| Premier départ TER semaine **05:30** | **05:45** | C1 |
| Soirée TER **24 min** après 20:54 | **20 min** de 21h05 à 22h05 | C1 |
| Keur Massar et Mbao comme gares TER *(variante C10)* | Keur Mbaye Fall | C4, C5, C6 |
| BRT limité à 2 lignes | **3 lignes** depuis 10/2025 | C7, C9 |
| B1 à 21 stations | **23 stations** | C9 |

**Règle appliquée** : la source actuelle est prioritaire ; la donnée PassBi est conservée comme référence historique, pas effacée.

---

## 16. Règle d'intégration Dakar Bus (Phase 14)

```
STRUCTURE
  PassBi + validation actuelle        → structure persistante
  → 13 gares TER, B1/B2 et leurs stations, 34 lignes DDD

HORAIRE
  PassBi exact + preuve de validité   → SCHEDULED possible
  → AUCUN cas : aucune grille opérateur datée et signée n'a été obtenue

  PassBi exact + aucune validation    → historical / reference
  → toutes les heures TER semaine, BRT, DDD, AFTU

FRÉQUENCE
  fréquence confirmée                 → ESTIMATED, jamais SCHEDULED
  → TER dimanche (20 min), TER semaine (10 min, valeur ACTUELLE), BRT (6 min)

TEMPS RÉEL
  PassBi ne fournit aucune source REAL_TIME vérifiée
  → REAL_TIME = NON
```

### 16.1 Ce qui peut servir de référentiel structurel

| Donnée | Usage recommandé | Confiance |
|---|---|---|
| **13 gares TER** + coordonnées + ordre | crosswalk `stop_id` PassBi ↔ Dakar Bus | HIGH |
| **B2 : 7 stations + ordre** | validation du référentiel BRT existant | HIGH |
| **B1 : 21 stations + ordre** | validation partielle ; à compléter par Gadaye et Fith Mith | HIGH |
| **34 lignes DDD** (numéro + terminus) | **référentiel d'identité de lignes** — le plus complet disponible | HIGH |
| **Codes AFTU** (`A1HL`…`A91AD`) | piste de réconciliation de la numérotation, à instruire | MEDIUM |
| **`shapes.txt`** (19 783 points : BRT 6 785, DDD 3 500, AFTU 9 498) | géométrie de référence, sous réserve de licence | MEDIUM |

### 16.2 Ce qui ne peut pas encore servir d'horaires actuels

**Tout.** Aucun `stop_times` PassBi ne peut alimenter un horaire affiché :

| Réseau | Raison |
|---|---|
| TER | grille semaine contredite ; grille dimanche confirmée en fréquence mais sans grille opérateur signée |
| BRT | aucune source horaire ; uniquement une fréquence (6 min) |
| DDD | aucune source horaire actuelle |
| AFTU | aucune source horaire actuelle, identité des lignes non établie |

S'y ajoutent deux vices structurels indépendants de la fraîcheur, établis au lot 4.2B : **le flag `timepoint` est perdu à l'import PassBi** (impossible de distinguer heure exacte et heure approximative) et **aucune licence ne couvre les données**.

---

## 17. Recommandations pour le prochain lot

1. **Exploiter le crosswalk DDD en priorité.** 34 lignes avec numéro et terminus confirmés par l'opérateur, contre 12 exposées aujourd'hui. C'est le gain de couverture le mieux étayé du lot — mais il exige d'abord une **licence** sur les données.
2. **Instruire la numérotation AFTU.** PassBi fournit des codes officiels (`A1HL`, `A24NU`, `A91AD`) dont le suffixe semble encoder les terminus. Un lot dédié devrait tenter de les rattacher aux itinéraires, **sans jamais déduire du seul numéro**.
3. **Demander à SETER une grille horaire datée.** C'est l'unique voie vers un `SCHEDULED` TER. La grille dimanche est déjà corroborée à 48/48 : une publication officielle la ferait basculer.
4. **Traiter la B3.** Ligne confirmée, absente de PassBi, déjà présente dans `services_not_exposed`. Son exposition relève d'un lot de données, pas de cet audit.
5. **Documenter le conflit de la grille semaine.** 12 min (2025) → 10 min (2026) est un changement d'offre réel et daté. Il mérite d'être tracé, pas seulement écrasé.
6. **Lever le blocage licence avant toute intégration.** Aucune licence ne couvre les données PassBi. C'est un préalable absolu, indépendant de la qualité.
7. **Ne pas rouvrir Keur Massar / Mbao.** Le conflit est tranché par la preuve.

---

## 18. Fichiers modifiés · Commit

| Fichier | Action |
|---|---|
| `docs/AUDIT_PASSBI_PERSISTENCE_2026-09-27.md` | **créé** — le présent rapport |

**Aucun autre fichier.** Contrôle exécuté le 2026-09-27 :

```
$ git diff --stat HEAD -- flutter-src/assets/data/dakar_network.json     → vide (NON MODIFIÉ)
$ git diff --stat HEAD -- flutter-src/lib/main.dart                      → vide (NON MODIFIÉ)
$ find . -path ./.git -prune -o -type f -newermt '<heure du checkout>' -print
./docs/AUDIT_PASSBI_PERSISTENCE_2026-09-27.md                            → SEUL fichier écrit par ce lot
```

État du JSON de production après ce lot : clés racine `['dataset_meta', 'operators', 'stops', 'routes', 'services_not_exposed']` · **105 routes** · **117 stops** · **toutes les routes conservent `schedule_status = UNKNOWN`**. L'interface, le GPS, le routage, `ScheduleProvider` et les statuts existants sont inchangés. Les rapports `AUDIT_PASSBI_2026-09-27.md` et `AUDIT_PASSBI_4_2B_2026-09-27.md` sont inchangés.

**Note de transparence** : l'arbre de travail contient des modifications non commitées **antérieures à ce lot** (5 fichiers Flutter modifiés, 7 fichiers Flutter non suivis), héritées des lots précédents. Elles portent toutes la date du checkout et **n'ont pas été touchées ici**.

**Aucun commit créé.** Branche de travail : `arena/01a0df09-dakar-bus`.

---

## 19. Livrable final

# `PASSBI_PERSISTENCE_STATUS = PARTIALLY_CONFIRMED`

Ce statut décrit **l'état des données analysées**, pas la qualité globale de PassBi.

### 19.1 Dénombrement

**Objets structurels PassBi examinés : 169**

| Réseau | Objets | Décomposition |
|---|---|---|
| TER | 19 | 13 gares + 6 lignes |
| BRT | 24 | 22 stations desservies + 2 lignes |
| DDD | 53 | 53 lignes |
| AFTU | 73 | 73 lignes |

| Statut | Nombre | Part |
|---|---|---|
| **Persistants / confirmés** | **72** | 43 % |
| **Modifiés** | **1** | 1 % |
| **Non confirmés** | **96** | 56 % |
| **Contredits** | **0** au niveau structurel | 0 % |
| **Total** | **169** | 100 % |

*Détail des 72 persistants* : 13 gares TER + 2 relations TER Dakar↔Diamniadio + 22 stations BRT + **1 ligne BRT (B2)** + 34 lignes DDD = **72**.

*Détail du 1 modifié* : **ligne BRT B1** — identité, fréquence, amplitude et ses 21 stations confirmées, mais itinéraire étendu à 23 stations. Classée `CHANGED` et non `PERSISTENT` parce que l'objet « itinéraire » a changé, même si la ligne persiste.

*Détail des 96 non confirmés* : 4 relations TER partielles + 19 lignes DDD + 73 lignes AFTU = **96**.

Contrôle : 72 + 1 + 96 = **169**.

**Objets horaires examinés : 6**

| Statut | Nombre | Objets |
|---|---|---|
| Confirmés | **2** | grille TER dimanche · fréquence BRT 6 min |
| Contradicts | **1** | grille TER semaine |
| Non confirmés | **3** | horaires BRT · horaires DDD · horaires AFTU |

**Objets 2026 nouveaux, absents de PassBi : 7** (ligne B3 · stations Gadaye et Fith Mith · gare AIBD · fréquence TER 10 min · premier départ 05:45 · 7 arrêts interurbains DDD)

### 19.2 Principales différences

1. **TER semaine** : 12 min → **10 min** ; premier départ 05:30 → **05:45**. Changement d'offre réel et daté.
2. **TER dimanche** : **aucune différence**. Concordance 48/48.
3. **BRT** : 2 lignes → **3** ; B1 de 21 → **23** stations.
4. **DDD** : 53 lignes PassBi contre 34 publiées par l'opérateur et **12 exposées par le projet**.
5. **AFTU** : numérotations **incompatibles** (PassBi 1-5 puis 24-91 ; projet 1-72).
6. **Keur Massar / Mbao** : écartés au profit de **Keur Mbaye Fall**.

### 19.3 Synthèse

**Peut servir de référentiel structurel** : les 13 gares TER, les lignes et stations BRT B1/B2, les 34 lignes DDD avec leurs terminus, les géométries (`shapes.txt`), les codes AFTU comme piste.

**Ne peut pas encore servir d'horaires actuels** : **la totalité des `stop_times` PassBi**, tous réseaux confondus — pour absence de grille opérateur datée, perte du flag `timepoint`, et absence de licence.

**Une donnée ancienne mais confirmée a été traitée comme telle** : 43 % du référentiel structurel PassBi est confirmé par des sources 2026, alors même qu'aucun fichier PassBi n'a été produit depuis février 2026.
