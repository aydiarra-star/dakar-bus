# Audit AFTU / Tata — normalisation documentaire et des identités

**Date** : 2026-09-25 · **Branche** : `arena/01a0d6a5-dakar-bus` · **Périmètre** : `dakar_network.json` (identités AFTU/Tata) + libellés trompeurs PWA. **Aucune fréquence, aucun arrêt, aucun horaire, aucun moteur modifié.**

---

## 1. État initial (relevé avant toute modification)

| Élément | État au 2026-09-25 (avant normalisation) |
|---|---|
| Lignes AFTU | **80** : `aftu_1`…`aftu_72` (72, `counts_toward_official_total: true`) + `new_commune_03`…`10` (8, hors total) |
| Lignes Tata | **7** : `tata_218`, `tata_219`, `tata_50`, `tata_64`, `tata_78`, `new_commune_11`, `new_commune_12` |
| Arrêts | **117** (49 utilisés uniquement par AFTU/Tata, tous `UNVERIFIED`, `source: null`) |
| Provenance des routes AFTU/Tata | `data_status: UNVERIFIED` ×87 · `source_type: FIELD_OBSERVATION` ×77, `UNKNOWN` ×10 · **aucun** `source` ni `verified_at` |
| Fréquences | **0** pour AFTU et Tata ; 5 fréquences TER/BRT (`data/transit/departure-frequencies.json`) |
| Horaires | `schedule_status: UNKNOWN` partout (aucun horaire, aucune desserte) |
| GTFS dormant | `data/gtfs` : 76 routes dont **70 AFTU** (dont `TATA_01`, `TATA_02` avec `agency_id = AFTU`), **145 trips**, mais `stop_times` ne couvre que 6 trips BRT/TER → **aucune desserte AFTU/Tata**. Ce GTFS n'est lu ni par la PWA ni par Flutter |
| Opérateurs | `aftu.official_line_count = 72` (CETUD) ; `tata.official_line_count = null` (« minibus exploités par des GIE AFTU ») |
| Affichage | Flutter : 41 arrêts étiquetés AFTU, 8 Tata, source « non vérifiée » 🟡, départs « Horaire indisponible ». PWA : 6 pôles bus + panneau « Prochains passages » AFTU/Tata → « Horaire indisponible ». Libellés « **Flotte en direct** » et « **ETA live** » présents |

---

## 2. Sources consultées (2026-09-25)

| Source | Type | Ce qu'elle établit | Ce qu'elle n'établit pas |
|---|---|---|---|
| `https://aftu-senegal.org/infos-pratiques/` — AFTU, site de l'exploitant | **OFFICIAL_STATIC** (id `aftu_officiel`) | **Numéros et terminus des lignes urbaines** : n° 1–5, 24–89, 91 (= **72 lignes**), avec pour chaque ligne une page d'itinéraire | ni cadence, ni amplitude par ligne, ni liste d'arrêts exploitable, ni horaire |
| `https://cetud.sn/reseaux-de-transport/aftu/` — CETUD | OFFICIAL_STATIC | 72 lignes, 2300 bus, 14 GIE, amplitude réseau **6 h → 21 h**, plan des lignes (JPEG) | pas de cadence par ligne |
| `https://cetud.sn/wp-content/uploads/2026/03/10-CETUD-ESRBRT-TOME-2_VF.pdf` — Étude de référence BRT, Tome 2 | **INSTITUTIONAL** (id `cetud_esrbrt_tome2`) | **Tableaux 48/49** : « fréquence moyenne de passage en mn des lignes de l'AFTU sur quelques points autour du corridor » (LAV et samedi) — **mesures ponctuelles d'enquête** | **pas une fréquence par ligne** : points de mesure, jours étudiés, aucune amplitude, aucune correspondance ligne/numéro |
| `https://www.ssatp.org/sites/default/files/publication/Dakar_vf.pdf` — SSATP / Banque mondiale | **INSTITUTIONAL** (id `ssatp_dakar_minibus`) | Constat : « the AFTU network lacks formal frequencies/schedules » ; horaires et fréquences varient « excessively among GEIs and operators » ; fin de service ~21 h | — |
| `aftu-senegal.org` (accueil) | OFFICIAL_STATIC | 3000 bus, 23 départements, 1,3 M passagers/jour | aucun total de lignes « Tata » |
| Moovit (agrégateur) | **COMMUNITY** (tiers) | cadences indicatives par ligne (ex. « 3 » : 8 min lun-ven, 18 sam, 22 dim) | **écarté** : tiers non officiel, en contradiction avec le constat SSATP ; jamais converti en fréquence |

---

## 3. Contradictions constatées (mesurées, pas supposées)

Comparaison **numéro par numéro** entre la liste publiée par l'exploitant et notre référentiel (72 identifiants `aftu_1`…`aftu_72`) :

| id | n° | notre libellé (observation terrain) | libellé publié par l'exploitant | verdict |
|---|---|---|---|---|
| `aftu_1` | 1 | Parcelles Assainies ↔ Sandaga | **LAT DIOR – HLM GRAND YOFF** | CONTREDIT |
| `aftu_2` | 2 | Guédiawaye ↔ Sandaga | **ROUTE PRINCIPALE PARCELLES – PETERSEN** | CONTREDIT |
| `aftu_3` | 3 | Marché Sandaga ↔ Hôpital Dalal Jamm | **YOFF – PETERSEN** | CONTREDIT |
| `aftu_5` | 5 | Keur Massar ↔ Petersen | PARCELLES ASSAINIES – PETERSEN | CONTREDIT (1 terminus commun) |
| `aftu_24` | 24 | Castor ↔ Hann | **UCAD – NOTAIRE GUEDIAWAYE** | CONTREDIT |
| `aftu_30` | 30 | Patte d'Oie ↔ Petersen | **GADAYE (GUEDIEWAYE) – GARE DE COLOBANE** | CONTREDIT |
| `aftu_40` | 40 | Bené Barak ↔ Sandaga | **GRAND MBAO – PETERSEN** | CONTREDIT |
| `aftu_50` | 50 | Yeumbeul ↔ Médina | **PETERSEN – MALIKA CIMETIERE** | CONTREDIT |
| `aftu_71` | 71 | Keur Mbaye Fall ↔ Colobane | KEUR MASSAR – CLAUDEL | CONTREDIT (1 terminus commun) |
| `tata_50` | 50 | Guédiawaye ↔ Sandaga (Tata) | *déjà attribué à AFTU 50* | **COLLISION DE NUMÉRO** |
| `tata_64` | 64 | Pikine ↔ Liberté 6 (Tata) | *déjà attribué à AFTU 64* | **COLLISION DE NUMÉRO** |
| `tata_78` | 78 | Yoff ↔ Petersen via Cambérène (Tata) | *déjà attribué à AFTU 78* | **COLLISION DE NUMÉRO** |

**Bilan mesuré** : **0 identité AFTU confirmée**, **54 contredites** (numéro publié, itinéraire différent), **18 numéros non publiés** (nos `aftu_6`…`aftu_23` : les numéros 6 à 23 **n'existent pas** dans la liste de l'exploitant) ; **18 numéros publiés absents de notre jeu** (73 → 89 et 91), non ajoutés. Seules 2 lignes partagent un terminus avec la publication (`aftu_5`, `aftu_71`) : insuffisant pour établir une identité.

Autres contradictions : `data/gtfs` attribue `TATA_01`/`TATA_02` à l'agence **AFTU** et invente 70 routes AFTU sans desserte ; la PWA affiche `lines: ["DDD 10","AFTU"]` sur ses 6 pôles bus ; `main.dart` conserve des arrêts de démonstration « TATA Ligne 50/64/78/218 » (retirés de l'affichage, mais présents dans le code).

---

## 4. Lignes confirmées

**Aucune.** L'exploitant publie le **numéro et les terminus**, mais **ni arrêts, ni horaires, ni cadence**. Un itinéraire (liste d'arrêts) ne peut donc pas être déclaré `CONFIRMED` : la seule chose confirmable serait le couple (numéro, terminus), et **aucun de nos itinéraires ne correspond** à la ligne portant ce numéro. Décision : **0 `CONFIRMED`**, conformément à la règle « CONFIRMED uniquement pour les informations réellement publiées par la source ».

## 5. Lignes conflictuelles — **57**

- **54 routes AFTU** (`aftu_1`…`aftu_5`, `aftu_24`…`aftu_72`) : `data_status: CONFLICTING`, `nomenclature_status: CONTRADICTED_BY_OPERATOR`, `official_line_number` + `official_long_name` renseignés, **ancien libellé conservé** dans `observed_long_name`, `source`/`source_url`/`verified_at` = publication opérateur. Aucun renommage silencieux, aucune fusion, listes d'arrêts inchangées.
- **3 routes Tata** (`tata_50`, `tata_64`, `tata_78`) : `CONFLICTING` + `collides_with_operator_line: "AFTU n"` — **non remappées** sur les lignes AFTU correspondantes (identité non résolue).

## 6. Lignes non confirmées — **30**

- **18 routes AFTU** (`aftu_6`…`aftu_23`) : `nomenclature_status: NUMBER_NOT_PUBLISHED_BY_OPERATOR`, `official_line_number: null`, `UNVERIFIED`. L'identifiant technique est conservé pour la stabilité (numérotation interne non publiée).
- **8 routes `new_commune_03`…`10`** (AFTU) : hors des 72 numéros publiés, `counts_toward_official_total: false`, `UNVERIFIED`, `schedule_status: UNKNOWN`.
- **4 routes Tata** (`tata_218`, `tata_219`, `new_commune_11`, `new_commune_12`) : `UNVERIFIED`, identité non résolue.

## 7. Décision sur les fréquences — **AUCUNE fréquence AFTU/Tata**

- `data/transit/departure-frequencies.json` et son miroir Dart **ne sont pas modifiés** (sha256 `e282a108…`, 5 fréquences : 3 TER + B1 + B2).
- L'exploitant ne publie **ni cadence ni amplitude par ligne** ; le constat institutionnel SSATP le confirme explicitement.
- Les **tableaux 48/49** du CETUD ESR-BRT (Tome 2) sont documentés dans `dataset_meta.sources` comme **mesures de passage en des points précis** (`usage: MEASUREMENT_REFERENCE_ONLY`, source `INSTITUTIONAL`) : ils ne sont **pas** convertis en fréquence de ligne. Aucun « 8 min », « 10 min », « 15 min » ni « 20 min » n'est créé.
- Conséquence conservée : `network_coverage` reste `NO_FREQUENCY` pour AFTU et Tata → **UNKNOWN** pour tous les départs.

## 8. Décision sur les arrêts

**Aucun arrêt ajouté, fusionné ou reclassé** (117 arrêts avant/après ; 33 `CONFIRMED`, 82 `UNVERIFIED`, 2 `CONFLICTING` — inchangé). Les 49 arrêts AFTU/Tata restent `UNVERIFIED` avec `source: null` (observation terrain). Aucune géométrie OSM n'est promue : OSM reste `COMMUNITY`, jamais une preuve d'exploitation.

## 9. Statut Tata

`operators.tata` porte désormais `is_independent_operator: false`, `parent_operator_id: "aftu"` et un `model_note` explicite : « Tata » désigne des **minibus/cars de l'écosystème AFTU (GIE)**, sans total de lignes officiel. Le filtre d'interface « Tata » est conservé (UX inchangée), mais **le modèle de données ne crée pas de second réseau** : chaque route Tata porte `service_category: "TATA"` et `exploitation_ecosystem: "AFTU"`, aucune n'est `CONFIRMED`, aucune n'est remappée arbitrairement.

## 10. Nettoyage des libellés trompeurs (§5)

| Fichier | Avant | Après | Raison |
|---|---|---|---|
| `index.html` (onglet Transports) | « Dakar Bus - **Flotte en direct** » | « Dakar Bus — **Réseau & capacités** » | aucune donnée de véhicule n'existe (couche véhicules désactivée) |
| `index.html` (carte GPS) | « Arrêts les plus proches avec **ETA live** » | « Arrêts les plus proches (**distance à vol d'oiseau**) » | aucune ETA n'existe : le GPS est celui de l'utilisateur, jamais un véhicule |
| `index.html` (meta) | « …carte **temps réel**… » | « …carte **interactive**… » | aucun flux temps réel public |
| `flutter-src/web/index.html` (meta) | « 40 lignes, 40 arrêts… carte **temps réel** » | « Planificateur d'itinéraires, carte **interactive**… » | chiffres périmés (105 lignes / 117 arrêts) et promesse de temps réel |

Aucune autre formulation de temps réel n'a été introduite ; `real_time.public_feeds` reste vide ; le moteur `REAL_TIME` n'est pas touché.

## 10 bis. Verrous de tests mis à jour (non-régression)

Trois garde-fous épinglaient la **taille en octets** de `dakar_network.json` pour empêcher qu'un correctif d'interface touche aux données ; ils ont été **portés au nouveau verrou** `213 248` octets / `sha256 3c2574e3…` (même procédure que lors de l'audit données du 2026-09-24 : verrou conservé à la nouvelle valeur, raison documentée en commentaire) :
`flutter-src/test/gps_position_test.dart` (règle 6), `flutter-src/test/cartographic_render_test.dart` (données intactes Phase 6/8), `flutter-src/test/out_of_coverage_test.dart` (garde-fous source). Ces tests vérifient **aussi** que les 117 arrêts, les 105 routes, les 5 opérateurs et les 13 gares TER dans l'ordre sont inchangés — c'est précisément ce que la normalisation respecte.

## 11. Limites actuelles

1. Les itinéraires AFTU/Tata restent des **observations terrain** non recoupées : aucune liste d'arrêts officielle n'existe.
2. `data/gtfs` (dormant) reste une seconde représentation contradictoire (70 routes AFTU, `TATA_01/02` sous agence AFTU) : **non traitée dans cette phase**, à normaliser dans un lot dédié.
3. Les 18 numéros publiés absents du jeu (73–89, 91) et les numéros 6–23 utilisés sans publication laissent le référentiel incomplet et partiellement mal numéroté — corrigeable seulement si l'exploitant publie des listes d'arrêts ou si le CETUD fournit un GTFS officiel.
4. Les tableaux 48/49 du CETUD restent inexploités (volontairement) : leur exploitation exigerait une méthode d'enquête et une correspondance ligne↔point de mesure.

## 12. Prochaine étape

1. Audit fonctionnel complet de l'application (read-only) : TER, BRT, DDD, AFTU/Tata, carte, StopCard, panneau, assistant, GPS, PWA ↔ Flutter.
2. Puis préparation du déploiement.
3. Lot ultérieur (hors périmètre) : normalisation ou retrait du GTFS dormant, et demande d'un GTFS officiel AFTU/CETUD (seule voie vers des fréquences légitimes).
