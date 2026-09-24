# Audit des données transport — 2026-09-24

Fichier audité : `flutter-src/assets/data/dakar_network.json`.
Principe : **aucune donnée inventée**. Ce qui n'est pas vérifié est marqué comme tel, sans être supprimé.

| | Avant | Après |
|---|---|---|
| Taille | 59 189 octets | 159 627 octets |
| SHA-256 | `e59f05b09f51890d…6bc9` | `9ba636183ac34768…ba6c` |
| Opérateurs / arrêts / routes | 5 / 117 / 105 | 5 / 117 / 105 (inchangé) |
| Coordonnées modifiées | — | **0** |
| Séquences modifiées | — | **1** (BRT B2) |

Périmètre : aucune modification de `lib/main.dart`, des écrans, de la carte, du GPS ou du design.

---

## 1. Rapport AVANT modification

Git : branche `arena/01a0d328-dakar-bus`, HEAD `b2a80ab`, arbre propre. L'historique ne contient qu'un seul commit : **aucune provenance traçable par git**. Les valeurs `OFFICIAL` d'origine ne s'appuient donc sur aucune source enregistrée.

**Opérateurs (5)** : `ter`, `brt`, `ddd`, `aftu`, `tata`.

**Arrêts (117)** : 55 `OFFICIAL`, 62 `FIELD_OBSERVATION`. Aucun arrêt orphelin, aucune référence cassée.

**Routes (105)**

| Réseau | Routes | Détail |
|---|---|---|
| TER | 1 | `ter_dakar_diamniadio` (13 gares) |
| BRT | 2 | `brt_b1_guediawaye_petersen` (23), `brt_b2_express` (7) |
| DDD | 15 | `ddd_1, 3, 7, 8, 9, 10, 11, 12, 14, 15, 20, 23` + `new_commune_01, 02, 13` |
| AFTU | 80 | `aftu_1..72` + `new_commune_03..10` |
| Tata | 7 | `tata_50, 64, 78, 218, 219` + `new_commune_11, 12` |

**Routes `OFFICIAL` (14)** : `ter_dakar_diamniadio`, `brt_b1_guediawaye_petersen`, `brt_b2_express`, `ddd_1, 3, 7, 8, 10, 14, 20, 23`, `new_commune_01, 02, 13`.
**Routes `FIELD_OBSERVATION` (91)** : `ddd_9, 11, 12, 15`, `aftu_1..72`, `tata_*` (5), `new_commune_03..12`.

**Absents** : BRT B3, BRT B4, prolongement TER AIBD.

**Doublons d'arrêts probables**
- **Homonymes exacts** : Sacré-Cœur (`stop_brt_07_sacre_coeur` / `stop_sacre_coeur`, 751 m), Liberté 6 (`stop_brt_09_liberte_6` / `stop_liberte6`, 1 028 m), Dalal Jamm (`stop_brt_19_dalal_jamm` / `stop_dalal_jamm`, 1 209 m).
- **Autres candidats** : Grand Médine, Guédiawaye, Petersen, Obélisque / Place de la Nation, Khar Yalla, Scat Urbam, Golf Sud, Parcelles U26, Grand Dakar, Dalifort, Diamniadio / Diamniadio 2.
- **Paires à moins de 80 m portant des noms différents** : `stop_fass` / `stop_sandaga` (77 m), `stop_dalifort` / `stop_khar_yalla` (77 m).
- **Suffixe « - BRT » hors lignes BRT** : 11 arrêts de bus portent ce suffixe sans être desservis par une ligne SunuBRT (`stop_camberene`, `dalal_jamm`, `fadia`, `grand_medine`, `grand_yoff`, `guediawaye`, `liberte6`, `obelisque`, `parcelles_u26`, `patte_doie`, `sacre_coeur`).

**Arrêts `OFFICIAL` sans aucune provenance (19, hors TER/BRT)** : `camberene`, `dalal_jamm`, `diamniadio_2`, `fadia`, `fann`, `grand_medine`, `grand_yoff`, `guediawaye`, `keur_massar`, `liberte6`, `obelisque`, `parcelles_u26`, `patte_doie`, `petersen`, `plateau`, `sacre_coeur`, `sandaga`, `ucad`, `yoff`.

---

## 2. Nouveau modèle de provenance (additif)

Tous les champs existants sont conservés. `data_trust` reste une chaîne toujours présente (compatibilité), avec une valeur ajoutée : `UNVERIFIED`.

| Champ | Où | Valeurs |
|---|---|---|
| `data_status` | arrêts, routes | `CONFIRMED`, `UNVERIFIED`, `CONFLICTING`, `FUTURE` |
| `source_type` | arrêts, routes | `OFFICIAL_STATIC`, `OFFICIAL_REALTIME`, `OPERATOR_REALTIME`, `ESTIMATED`, `COMMUNITY`, `FIELD_OBSERVATION`, `UNKNOWN` |
| `source`, `verified_at` | arrêts, routes | `null` si la source est inconnue |
| `source_url`, `audit_note` | optionnels | lien réel consulté, explication de l'audit |
| `place_id` | arrêts | lieu physique (partagé entre arrêts de réseaux différents) |
| `coordinates_status` (+ `coordinates_note`) | arrêts | fiabilité de la position, distincte de celle de l'existence de l'arrêt |
| `schedule_status` | routes | `UNKNOWN` partout (le fichier ne contient aucun horaire) |
| `counts_toward_official_total` | routes AFTU / new_commune | `false` pour les lignes candidates |
| `audit_flags` | routes | `ITINERARY_GEOGRAPHICALLY_INCOHERENT`, `DUPLICATE_STOP_SEQUENCE` |
| `official_line_count` (+ note / source / url) | opérateurs | TER 1, BRT 3 (+ B4 future), DDD 38, AFTU 72, Tata `null` |
| `dataset_meta` | racine | schéma, valeurs admises, sources consultées |
| `services_not_exposed` | racine | B3, B4, TER AIBD — **non lus par l'application** |

Règles garanties par `test/data_provenance_test.dart` :
- `CONFIRMED` exige `source` + `verified_at` + `OFFICIAL_STATIC`. Le modèle Dart relit un `CONFIRMED` sans source comme `UNVERIFIED`.
- Source inconnue : `source_type` vaut `UNKNOWN` ou `FIELD_OBSERVATION`, et jamais `data_trust: OFFICIAL`.
- Une observation terrain n'est jamais `CONFIRMED` ni `OFFICIAL`.
- `ScheduleStatus.estimated` ne s'affiche jamais « temps réel » ; `unknown` s'affiche « Horaire indisponible ».

Modèle Dart : enums `ProvenanceStatus` (nom choisi pour éviter la collision avec `DataStatus` de `main.dart`), `SourceType`, `ScheduleStatus` et classe `Provenance`. Tous les nouveaux paramètres sont optionnels : les constructeurs existants restent valides. Une valeur `data_trust` inconnue donne désormais `unverified` (au lieu de `estimated`).

---

## 3. Résultat par réseau

### TER — CONFIRMED
- **Séquence** : les 13 gares Dakar → Diamniadio sont conformes au plan de ligne publié par SETER (carte uMap 556411, calque « Les gares », intégrée à terdakar.sn). Le plan ne contient **aucune gare Keur Massar ni Mbao**.
- **Coordonnées** : écart de 34 à 128 m avec les points SETER, donc `coordinates_status: CONFIRMED` (tolérance 150 m).
- **Nomenclature divergente** : le texte du schéma SENTER cite « Keur Massar » et « Mbao » à la place de « Dalifort » et « Keur Mbaye Fall ». C'est noté (`audit_note`) sur les deux gares ; le plan de l'exploitant fait foi.
- **AIBD** : `FUTURE`, dans `services_not_exposed` uniquement. Aucune gare ajoutée : au 2026-09-24, le prolongement est en essais, sans service commercial.

### BRT
- **B1 — CONFIRMED** : omnibus, 23 stations (sunubrt.sn). La page B1 du site affiche encore « 21 stations » (texte de 2024).
  - 20 stations `CONFIRMED` avec leur nom officiel en `audit_note`.
  - `stop_brt_06_liberte_1` : **CONFLICTING** (« Liberté 1 » dans le communiqué de 2024, « Liberté 4 » sur sunubrt.sn en 2025).
  - `stop_brt_22_gadaye` : **CONFLICTING** (nom introuvable ; la page B3 nomme cette position « Gueule Tapée »).
  - `stop_brt_20_fith_mith` : **UNVERIFIED** (nom présent seulement dans une grille non officielle ; coordonnée à ~731 m de la station OSM).
- **B2 — CONFIRMED après correction de séquence** (voir §4).
- **B3** : service réel (sunubrt.sn), mais **non exposé** comme route. La correspondance « Gueule Tapée » ↔ `stop_brt_22_gadaye` n'est pas confirmée ; les 7 noms officiels sont conservés dans `services_not_exposed`.
- **B4 : FUTURE** (« Prochainement »). Stations non publiées : `null`.

### DDD
- CETUD annonce **38 lignes** ; le jeu en contient 15. `official_line_count: 38` est accompagné d'une note explicite : les 15 routes ne représentent pas le réseau.
- **10 routes CONFLICTING** (itinéraire du JSON contredit par demdikk.sn, conservé sans réécriture) : `ddd_1, 7, 8, 9, 10, 11, 12, 15, 20, 23`.
- **`ddd_3`, `ddd_14` : UNVERIFIED / UNKNOWN** (aucune ligne 3 ni 14 publiée par DDD).
- **`new_commune_01, 02, 13` : UNVERIFIED / UNKNOWN**, `counts_toward_official_total: false`.
- Les 8 routes auparavant `OFFICIAL` passent en `data_trust: UNVERIFIED`.

### AFTU
- CETUD annonce **72 lignes**. `aftu_1..72` restent `FIELD_OBSERVATION` / `UNVERIFIED` : seul le nombre est officiel, pas la numérotation ni les itinéraires.
- `new_commune_03..10` : `UNVERIFIED` / `UNKNOWN`, `counts_toward_official_total: false`.

### Tata
- **Statut** : les 7 routes restent `FIELD_OBSERVATION` / `UNVERIFIED` (`new_commune_11, 12` passent en `UNKNOWN`).
- **Pas de réseau distinct** : « Tata » désigne les minibus des GIE AFTU, et CETUD ne publie pas de total Tata.
- **Risques de confusion** : `tata_218` / `tata_219` portent les numéros de deux lignes DDD officielles (218 Thiaroye ↔ Aéroport LSS, 219 Daroukhane ↔ Ouakam). `tata_218` a la même séquence que `aftu_38`, et `tata_50` la même que `aftu_2`.

---

## 4. Changements importants (AVANT / APRÈS / RAISON / SOURCE)

| Élément | Avant | Après | Raison | Source |
|---|---|---|---|---|
| `brt_b2_express.stops` | 23, 19, **16**, 13, **09**, 03, 01 | 23, 19, 13, **07**, **05**, 03, 01 | Parcelles et Liberté 6 ne font pas partie de B2 ; il manquait Sacré-Cœur et Grand Dakar | Communiqué SunuBRT 30/09/2024 (RTS) |
| `brt_b2_express.long_name` | « Guédiawaye ↔ Petersen Express (7 stations directes) » | « Préfecture de Guédiawaye ↔ Papa Gueye Fall (semi-express, 7 stations) » | B2 est semi-express ; l'express est B4 | idem |
| `ddd_1, 7, 8, 10, 20, 23` | OFFICIAL | UNVERIFIED / CONFLICTING | OFFICIAL sans source, contredit par l'opérateur | demdikk.sn |
| `ddd_9, 11, 12, 15` | FIELD_OBSERVATION | FIELD_OBSERVATION / CONFLICTING | contredit par l'opérateur | demdikk.sn |
| `ddd_3, ddd_14` | OFFICIAL | UNVERIFIED / UNKNOWN | ligne absente de la liste de l'opérateur | demdikk.sn |
| `new_commune_01, 02, 13` | OFFICIAL | UNVERIFIED / UNKNOWN | aucune source | — |
| `new_commune_03..12` | FIELD_OBSERVATION | UNVERIFIED / UNKNOWN | aucune source, hors totaux officiels | — |
| 19 arrêts hors TER/BRT | OFFICIAL | UNVERIFIED / UNKNOWN | OFFICIAL sans provenance | — |
| `stop_brt_20_fith_mith` | OFFICIAL | UNVERIFIED / UNKNOWN | nom non officiel | — |
| `stop_brt_06`, `stop_brt_22` | OFFICIAL | OFFICIAL / CONFLICTING | station réelle, nom contesté | SunuBRT |
| Repli en dur (`data_service.dart`) | `DataTrust.official` ×7 | `DataTrust.unverified` | données de secours sans source | — |

**Données retirées : aucune.** Aucun arrêt, aucune route, aucune coordonnée supprimés.

## 5. Détail généré depuis le JSON

### Routes signalées `ITINERARY_GEOGRAPHICALLY_INCOHERENT` (itinéraire ≥ 2× la distance entre terminus)

| Route | Statut | Note |
|---|---|---|
| `ddd_14` | UNVERIFIED | Itinéraire de 6.9 km pour 3.3 km entre terminus (×2.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_6` | UNVERIFIED | Itinéraire de 20.2 km pour 6.9 km entre terminus (×2.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_7` | UNVERIFIED | Itinéraire de 38.7 km pour 10.5 km entre terminus (×3.7) : succession d’arrêts géographiquement incohérente. |
| `aftu_9` | UNVERIFIED | Itinéraire de 41.2 km pour 4.0 km entre terminus (×10.2) : succession d’arrêts géographiquement incohérente. |
| `aftu_10` | UNVERIFIED | Itinéraire de 14.8 km pour 6.6 km entre terminus (×2.2) : succession d’arrêts géographiquement incohérente. |
| `aftu_13` | UNVERIFIED | Itinéraire de 26.1 km pour 4.2 km entre terminus (×6.3) : succession d’arrêts géographiquement incohérente. |
| `aftu_14` | UNVERIFIED | Itinéraire de 56.8 km pour 9.1 km entre terminus (×6.2) : succession d’arrêts géographiquement incohérente. |
| `aftu_17` | UNVERIFIED | Itinéraire de 14.2 km pour 2.7 km entre terminus (×5.2) : succession d’arrêts géographiquement incohérente. |
| `aftu_20` | UNVERIFIED | Itinéraire de 36.6 km pour 7.8 km entre terminus (×4.7) : succession d’arrêts géographiquement incohérente. |
| `aftu_23` | UNVERIFIED | Itinéraire de 21.2 km pour 3.1 km entre terminus (×6.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_26` | UNVERIFIED | Itinéraire de 14.0 km pour 5.9 km entre terminus (×2.4) : succession d’arrêts géographiquement incohérente. |
| `aftu_28` | UNVERIFIED | Itinéraire de 17.0 km pour 5.5 km entre terminus (×3.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_29` | UNVERIFIED | Itinéraire de 10.6 km pour 2.6 km entre terminus (×4.0) : succession d’arrêts géographiquement incohérente. |
| `aftu_31` | UNVERIFIED | Itinéraire de 16.8 km pour 2.8 km entre terminus (×5.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_34` | UNVERIFIED | Itinéraire de 49.0 km pour 6.6 km entre terminus (×7.5) : succession d’arrêts géographiquement incohérente. |
| `aftu_39` | UNVERIFIED | Itinéraire de 16.1 km pour 3.9 km entre terminus (×4.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_42` | UNVERIFIED | Itinéraire de 20.6 km pour 6.5 km entre terminus (×3.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_43` | UNVERIFIED | Itinéraire de 27.7 km pour 2.6 km entre terminus (×10.5) : succession d’arrêts géographiquement incohérente. |
| `aftu_44` | UNVERIFIED | Itinéraire de 42.5 km pour 5.1 km entre terminus (×8.3) : succession d’arrêts géographiquement incohérente. |
| `aftu_46` | UNVERIFIED | Itinéraire de 33.3 km pour 10.3 km entre terminus (×3.2) : succession d’arrêts géographiquement incohérente. |
| `aftu_47` | UNVERIFIED | Itinéraire de 57.7 km pour 9.9 km entre terminus (×5.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_48` | UNVERIFIED | Itinéraire de 25.0 km pour 4.1 km entre terminus (×6.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_49` | UNVERIFIED | Itinéraire de 12.8 km pour 2.0 km entre terminus (×6.5) : succession d’arrêts géographiquement incohérente. |
| `aftu_51` | UNVERIFIED | Itinéraire de 20.0 km pour 2.5 km entre terminus (×7.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_53` | UNVERIFIED | Itinéraire de 56.8 km pour 17.0 km entre terminus (×3.3) : succession d’arrêts géographiquement incohérente. |
| `aftu_55` | UNVERIFIED | Itinéraire de 17.5 km pour 8.2 km entre terminus (×2.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_56` | UNVERIFIED | Itinéraire de 40.2 km pour 8.9 km entre terminus (×4.5) : succession d’arrêts géographiquement incohérente. |
| `aftu_57` | UNVERIFIED | Itinéraire de 15.3 km pour 6.4 km entre terminus (×2.4) : succession d’arrêts géographiquement incohérente. |
| `aftu_58` | UNVERIFIED | Itinéraire de 21.5 km pour 5.2 km entre terminus (×4.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_59` | UNVERIFIED | Itinéraire de 30.5 km pour 1.1 km entre terminus (×28.5) : succession d’arrêts géographiquement incohérente. |
| `aftu_61` | UNVERIFIED | Itinéraire de 29.9 km pour 7.7 km entre terminus (×3.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_62` | UNVERIFIED | Itinéraire de 26.5 km pour 6.8 km entre terminus (×3.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_64` | UNVERIFIED | Itinéraire de 24.9 km pour 2.1 km entre terminus (×11.7) : succession d’arrêts géographiquement incohérente. |
| `aftu_66` | UNVERIFIED | Itinéraire de 43.0 km pour 10.5 km entre terminus (×4.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_67` | UNVERIFIED | Itinéraire de 19.4 km pour 1.8 km entre terminus (×10.9) : succession d’arrêts géographiquement incohérente. |
| `aftu_68` | UNVERIFIED | Itinéraire de 53.2 km pour 23.3 km entre terminus (×2.3) : succession d’arrêts géographiquement incohérente. |
| `aftu_69` | UNVERIFIED | Itinéraire de 35.6 km pour 13.9 km entre terminus (×2.6) : succession d’arrêts géographiquement incohérente. |
| `aftu_70` | UNVERIFIED | Itinéraire de 46.6 km pour 7.7 km entre terminus (×6.1) : succession d’arrêts géographiquement incohérente. |
| `aftu_71` | UNVERIFIED | Itinéraire de 38.2 km pour 14.6 km entre terminus (×2.6) : succession d’arrêts géographiquement incohérente. |
| `aftu_72` | UNVERIFIED | Itinéraire de 22.6 km pour 9.2 km entre terminus (×2.5) : succession d’arrêts géographiquement incohérente. |
| `new_commune_01` | UNVERIFIED | Itinéraire de 7.1 km pour 1.0 km entre terminus (×7.1) : succession d’arrêts géographiquement incohérente. |
| `new_commune_03` | UNVERIFIED | Itinéraire de 19.2 km pour 4.5 km entre terminus (×4.3) : succession d’arrêts géographiquement incohérente. |
| `new_commune_05` | UNVERIFIED | Itinéraire de 9.9 km pour 4.2 km entre terminus (×2.4) : succession d’arrêts géographiquement incohérente. |
| `new_commune_07` | UNVERIFIED | Itinéraire de 22.2 km pour 5.3 km entre terminus (×4.2) : succession d’arrêts géographiquement incohérente. |

### Routes à séquence identique (`DUPLICATE_STOP_SEQUENCE`)

- `aftu_2` (Guédiawaye ↔ Sandaga (AFTU Ligne 2 Express))
- `aftu_38` (Mermoz ↔ Keur Massar (AFTU Ligne 38))
- `tata_218` (Mermoz ↔ Keur Massar (Tata 218))
- `tata_50` (Guédiawaye ↔ Sandaga (Tata Ligne 50))

### Lieux physiques partagés (`place_id`)

| place_id | Arrêts (ids conservés) | Coordonnées de l'arrêt bus |
|---|---|---|
| `place_petersen` | `stop_brt_01_petersen` (Papa Gueye Fall - PEM Petersen BRT) ; `stop_petersen` (PEM Petersen - Gare Routière) | — |
| `place_place_de_la_nation` | `stop_brt_03_obelisque` (Place de la Nation - Obélisque - BRT) ; `stop_obelisque` (Place de l'Obélisque - BRT) | À 1051 m de stop_brt_03_obelisque, alors qu’ils désignent le même lieu. |
| `place_sacre_coeur` | `stop_brt_07_sacre_coeur` (Sacré-Cœur - BRT) ; `stop_sacre_coeur` (Sacré-Cœur - BRT) | À 751 m de stop_brt_07_sacre_coeur, alors qu’ils désignent le même lieu. |
| `place_liberte_6` | `stop_brt_09_liberte_6` (Liberté 6 - BRT Correspondance) ; `stop_liberte6` (Liberté 6 - BRT Correspondance) | À 1028 m de stop_brt_09_liberte_6, alors qu’ils désignent le même lieu. |
| `place_khar_yalla` | `stop_brt_10_khar_yallah` (Khar Yallah - BRT) ; `stop_khar_yalla` (Khar Yalla - Grand Yoff) | À 1002 m de stop_brt_10_khar_yallah, alors qu’ils désignent le même lieu. |
| `place_scat_urbam` | `stop_brt_11_scat_urbam` (Scat Urbam - BRT) ; `stop_scatt_urbam` (Scat Urbam - Parcelles) | À 4934 m de stop_brt_11_scat_urbam, alors qu’ils désignent le même lieu. |
| `place_grand_medine` | `stop_brt_13_grand_medine` (Grand Médine - PEM BRT) ; `stop_grand_medine` (Grand Médine - BRT) | À 3671 m de stop_brt_13_grand_medine, alors qu’ils désignent le même lieu. |
| `place_golf_sud` | `stop_brt_18_golf_sud` (Golf Sud - BRT) ; `stop_golf_sud` (Golf Sud - Guédiawaye) | À 1996 m de stop_brt_18_golf_sud, alors qu’ils désignent le même lieu. |
| `place_dalal_jamm` | `stop_brt_19_dalal_jamm` (Hôpital Dalal Jamm - BRT) ; `stop_dalal_jamm` (Hôpital Dalal Jamm - BRT) | À 1209 m de stop_brt_19_dalal_jamm, alors qu’ils désignent le même lieu. |
| `place_prefecture_guediawaye` | `stop_brt_23_guediawaye` (Préfecture Guédiawaye - PEM BRT) ; `stop_guediawaye` (PEM Guédiawaye - Terminus BRT Nord) | À 1177 m de stop_brt_23_guediawaye, alors qu’ils désignent le même lieu. |

### Coordonnées CONFLICTING

- `stop_brt_02_mosquee` — Point à ~195 m du quai OSM « Papa Gueye Fall » et à ~524 m de celui de « Grande Mosquée » (docs/AUDIT_BASE_B_2026-09-22.md §D.2).
- `stop_brt_20_fith_mith` — Écart d’environ 731 m avec la station OSM la plus proche (docs/AUDIT_BASE_B_2026-09-22.md §D.2).
- `stop_dalal_jamm` — À 1209 m de stop_brt_19_dalal_jamm, alors qu’ils désignent le même lieu.
- `stop_dalifort` — « Dalifort - Foirail » est placé à 3924 m de la gare TER de Dalifort (plan SETER) et à 77 m de stop_khar_yalla : position incohérente avec le nom.
- `stop_fass` — À 77 m de stop_sandaga alors que Fass et Sandaga sont deux quartiers distincts : au moins une des deux positions est fausse.
- `stop_golf_sud` — À 1996 m de stop_brt_18_golf_sud, alors qu’ils désignent le même lieu.
- `stop_grand_medine` — À 3671 m de stop_brt_13_grand_medine, alors qu’ils désignent le même lieu.
- `stop_guediawaye` — À 1177 m de stop_brt_23_guediawaye, alors qu’ils désignent le même lieu.
- `stop_khar_yalla` — À 1002 m de stop_brt_10_khar_yallah, alors qu’ils désignent le même lieu.
- `stop_liberte6` — À 1028 m de stop_brt_09_liberte_6, alors qu’ils désignent le même lieu.
- `stop_obelisque` — À 1051 m de stop_brt_03_obelisque, alors qu’ils désignent le même lieu.
- `stop_sacre_coeur` — À 751 m de stop_brt_07_sacre_coeur, alors qu’ils désignent le même lieu.
- `stop_sandaga` — À 77 m de stop_fass alors que Fass et Sandaga sont deux quartiers distincts : au moins une des deux positions est fausse.
- `stop_scatt_urbam` — À 4934 m de stop_brt_11_scat_urbam, alors qu’ils désignent le même lieu.

### Écarts TER JSON ↔ plan SETER

| Gare | Écart |
|---|---|
| `stop_dakar_ter` Gare TER Dakar | 57 m |
| `stop_colobane` Colobane - Marché & Gare TER | 84 m |
| `stop_hann` Hann - Maristes / TER | 72 m |
| `stop_dalifort_ter` Dalifort - Gare TER | 75 m |
| `stop_baux_maraichers` Baux Maraîchers - TER | 88 m |
| `stop_pikine` Pikine - Marché Zinc / TER | 54 m |
| `stop_thiaroye` Thiaroye - Gare TER | 72 m |
| `stop_yeumbeul` Yeumbeul - Station TER | 102 m |
| `stop_keur_mbaye_fall` Keur Mbaye Fall - Correspondance TER | 34 m |
| `stop_pnr` PNR - Station TER | 48 m |
| `stop_rufisque` Rufisque - Gare TER | 48 m |
| `stop_bargny` Bargny - TER | 79 m |
| `stop_diamniadio` Diamniadio - Gare TER Terminus | 128 m |

---

## 6. Tests

Aucun test n'a été supprimé ni contourné. Les tests modifiés figeaient une hypothèse désormais **fausse** ; chaque modification porte un commentaire AVANT / APRÈS / RAISON dans le code.

| Test | Avant | Après | Raison |
|---|---|---|---|
| `network_data_test.dart` `kBrtB27` | ancienne séquence B2 | séquence officielle | la liste figeait une séquence contredite par SunuBRT |
| `ter_brt_route_data_test.dart` `kBrtB27` | idem | idem | idem |
| `detailed_route_test.dart` distance B2 | `16.0 km` | `16.5 km` | même formule (haversine, R = 6 371 008,8 m), nouvelle séquence (16 454,6 m) |
| `network_data_test.dart` « data_trust connu du modèle » | 3 valeurs | 4 valeurs (+ `UNVERIFIED`) | l'enum a été étendue ; l'intention du test (aucune valeur ignorée) est conservée |
| `cartographic_render_test`, `gps_position_test`, `out_of_coverage_test` | taille 59 189 | taille 159 627 | verrou « un correctif UI ne touche pas aux données » ; ce commit modifie volontairement les données. Le verrou est conservé |

**Nouveau test** : `test/data_provenance_test.dart` (règles du §2, TER, BRT, DDD, AFTU, Tata, `place_id`, modèle Dart, chargement effectif du JSON par `DataService`).

**Validation locale** : Flutter n'est pas installable dans ce bac à sable (accès bloqué à storage.googleapis.com et pub.dev). Les étapes `flutter analyze`, `flutter test` et `flutter build web` sont exécutées par le workflow GitHub « Flutter web build (J9) ». Les assertions JSON du nouveau test ont été rejouées en Python sur le fichier réel : 0 échec. `npm test` : 24/24.

---

## 7. Sources utilisées (consultées le 2026-09-24)

| Source | URL | Usage |
|---|---|---|
| SETER — plan de la ligne | https://www.terdakar.sn/acceder-au-plan-de-la-ligne/ | séquence et positions des 13 gares |
| SETER — carte uMap intégrée | https://umap.openstreetmap.fr/fr/map/556411 | coordonnées des gares (calque « Les gares ») |
| SENTER — plan de transport | https://sentersa.sn/plan-de-transport/ | 13 gares, AIBD en phase 2 ; nomenclature divergente |
| SunuBRT — site officiel | https://www.sunubrt.sn/ | B1 (23 stations), B4 « Prochainement » |
| SunuBRT — ligne B3 | https://www.sunubrt.sn/brt-3-semi-express/ | 7 stations B3 |
| Communiqué SunuBRT du 30/09/2024 (relayé par RTS) | https://www.rts.sn/actualite/detail/a-la-une/sunubrt-lance-la-phase-2-avec-sept-nouvelles-stations-et-la-ligne-semi-express-b2 | 7 stations B2 |
| Dakar Dem Dikk — réseau | https://demdikk.sn/reseau-urbain-dakar/ | itinéraires DDD officiels |
| CETUD — DDD | https://cetud.sn/reseaux-de-transport/ddd/ | 38 lignes |
| CETUD — AFTU | https://cetud.sn/reseaux-de-transport/aftu/ | 72 lignes |
| `docs/AUDIT_BASE_B_2026-09-22.md` §D.2 (comparaison OSM, source communautaire) | — | écarts de coordonnées BRT |

Aucune API, aucun flux GTFS-RT et aucun endpoint n'a été ajouté ni supposé.

---

## 8. Limites connues, signalées mais non corrigées (hors périmètre)

1. **Libellés d'interface** : `lib/main.dart` (fichier interdit de modification) contient des mentions « officiel » **codées en dur**, sans lecture de `data_status`. Elles peuvent désormais contredire la donnée :
   - l. 337-341 : « SETER / SunuBRT / Dakar Dem Dikk / Bus TATA (Officiel) », « AFTU (72 Lignes Officielles) » ;
   - l. 3415 : l'assistant annonce « 14 gares officielles » (le TER en compte 13) et « un départ toutes les 10 à 20 min », une fréquence non fournie par les données ;
   - l. 2938-2939 : la carte DDD annonce « Source officielle : Direction DDD » et « lignes régulières 1, 3, 10, 14 et 20 aux horaires habituels », alors que les lignes 3 et 14 n'existent pas sur demdikk.sn et que 1, 10 et 20 sont CONFLICTING ;
   - l. 3586 : badge `[OFFICIEL]`.
2. **Commentaires obsolètes** dans `lib/main.dart` : « BRT B2 = 16.0 km » (l. 452) et séquence B2 (l. 1026-1047). Ils sont documentaires uniquement.
3. **Suffixe « - BRT »** : les 11 arrêts de bus concernés n'ont **pas été renommés** (texte affiché). Une `audit_note` le signale.
4. **Coordonnées `CONFLICTING`** : non corrigées. Aucune source officielle de coordonnées n'est disponible pour ces arrêts de bus.
5. **Libellé court B2** : `short_name` « BRT B2 Express » est conservé, car l'application en extrait le numéro de ligne.
6. **Données communautaires** : `data/gtfs/shapes.txt` et les polylignes ne sont pas des preuves d'exploitation (voir `dataset_meta.geometry_note`).
7. **Audit des pages publiées** : `scripts/lib/pages-audit.js` signalera toujours `STOP_PROVENANCE_MISSING` (82 arrêts ont `source: null`, ce qui est honnête) et `EXPLICIT_NETWORK_MISSING`.
8. **B1 incomplète** : 3 noms de stations restent à trancher (Liberté 1/4, Gadaye/Gueule Tapée, Fith Mith). Il faudrait une liste officielle datée de SunuBRT ou du CETUD.
