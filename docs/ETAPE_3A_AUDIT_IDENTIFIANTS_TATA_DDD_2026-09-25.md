# Étape 3A — Audit des identifiants de lignes Tata et Dakar Dem Dikk

**Date** : 2026-09-25 · **Version** : 2 (corrections documentaires) · **Nature** : audit **en lecture seule** · **Statut** : *audit validé — décision A4 enregistrée, aucune donnée modifiée*

> **Version 2** — intègre la **décision A4** du commanditaire du 2026-09-25 : `new_commune_11` et `new_commune_12` sont classés **`MISSING`** (identifiants techniques, aucun numéro officiel établi) et non `CONFLICTING`. Les anomalies A1, A2, A3 sont converties en **cibles décidées**, prêtes à appliquer (§6.3, §9-2). Tableau final de l’axe identifiant : **§12**. **Aucune donnée n’est modifiée par cette version.** **Révision 2.1 (2026-09-25)** : l’erratum du référentiel Phase 3 a été **appliqué** (référentiel **révision 1.1**, §B.3/§E.1/§E.3/§K.4/§L/§M) et l’**extension A1** aux trois lignes DDD `new_commune_01/02/13` a été **autorisée et appliquée au référentiel**. **Toujours aucune donnée modifiée.**

> **Révision 2.1 — corrections documentaires appliquées.** Voir §6.3 A1/A4, §9-2, §11 et §12.2.

**Fichier audité** : `flutter-src/assets/data/dakar_network.json` — **268473 octets**, SHA-256 `2459dd18b5ad685b…`
(identique avant et après cet audit : voir §11).
**Documents de référence** : `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` (Phase 3, validé) et
`docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md` (Phase 2, validé).

---

## 0. Question posée et réponse courte

> *Certaines lignes Tata et DDD présentes dans `dakar_network.json` n'ont pas d'identifiant/numéro officiel clairement établi.*

**Confirmé, et chiffré.** Sur les 22 lignes Tata (7) et DDD (15) du fichier :

| Constat | Nombre | Détail |
|---|---|---|
| Lignes **sans aucun numéro officiel attribuable** | **7** | 2 Tata + 5 DDD (§4) |
| Lignes dont **le numéro porté appartient officiellement à un autre service** | **15** | 5 Tata + 10 DDD (§6.1, §6.2) |
| **Correspondances officielles confirmées** | **0** | aucune identité n'est établie (§5) |
| Lignes dont la **recherche d'identité est insuffisante** (axe correspondance) | **5** | 5 identités Tata : `tata_50`, `tata_64`, `tata_218`, `new_commune_11`, `new_commune_12` (§7) |

**Aucun numéro n'a été fabriqué à partir d'un identifiant interne** : c'est le point de méthode central de cet audit (§6.3).

**Axe « identifiant officiel » — résultat final (décision A4)** : **15 `CONFLICTING`** (5 Tata + 10 DDD) · **7 `MISSING`** (2 Tata + 5 DDD) · **0 `CONFIRMED`** · **0 `UNKNOWN`**. Tableau des 22 lignes : **§12**.

---

## 1. Périmètre et méthode

| Élément | Valeur |
|---|---|
| Lignes Tata analysées | **7** |
| Lignes DDD analysées | **15** |
| **Total analysé** | **22 lignes** (sur 105 routes du fichier) |
| Lignes AFTU (hors périmètre de cette étape) | 80 |
| TER / BRT (hors périmètre) | 3 |

**Étapes suivies** : (1) extraction exhaustive des champs des 22 lignes ; (2) confrontation à la liste officielle AFTU (`S-A1`, 72 libellés)
et aux deux pages DDD (`S-D1` titres/catégories, `S-D2` itinéraires arrêt par arrêt) ; (3) confrontation au référentiel canonique Phase 3
(48 identifiants DDD, 7 identités Tata) ; (4) verdict par ligne selon les quatre statuts imposés.

**Convention de statut retenue** (les quatre statuts demandés, et eux seuls) :

| Statut | Signification exacte employée ici |
|---|---|
| `CONFIRMED` | un numéro officiel **vérifié pour ce service précis** (numéro **et** itinéraire concordants) |
| `MISSING` | **aucun numéro officiel retrouvé** pour ce service |
| `CONFLICTING` | le numéro porté est publié officiellement **pour un autre service**, ou l'identité officielle du numéro est elle-même incompatible — aucun arbitrage |
| `UNKNOWN` | recherche insuffisante pour conclure |

> Ce statut qualifie **l'identifiant de la ligne interne**, pas la qualité de la ligne officielle du même numéro. Il est donc distinct
> de `canonical_status` (référentiel Phase 3) et de `data_status` (audit données 2026-09-24), qui restent inchangés.

---

## 2. Tableau exhaustif — lignes Tata (7)

| # | Identifiant interne | Réseau | Catégorie de service | Numéro officiel publié | Nom/libellé officiel | Origine → destination (interne) | Statut de l'identifiant | Source officielle | Correspondance référentiel Phase 3 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `tata_50` | AFTU (`exploitation_ecosystem`) | `TATA` | **50** — détenu par AFTU (S-A1) | PETERSEN - MALIKA CIMETIERE | PEM Guédiawaye - Terminus BRT Nord ↔ Marché Sandaga - Centre Dakar | **`CONFLICTING`** | `S-A1` | `Tata` (7 identités) — §B.2/B.3 ; numéro détenu par **AFTU 50** |
| 2 | `tata_64` | AFTU (`exploitation_ecosystem`) | `TATA` | **64** — détenu par AFTU (S-A1) | GUEDIAWAYE - RUFISQUE | Pikine - Marché Zinc / TER ↔ Liberté 6 - BRT Correspondance | **`CONFLICTING`** | `S-A1` | `Tata` (7 identités) — §B.2/B.3 ; numéro détenu par **AFTU 64** |
| 3 | `tata_78` | AFTU (`exploitation_ecosystem`) | `TATA` | **78** — détenu par AFTU (S-A1) | DIAMAGUENE - LIBERTE 5 | Yoff - Aéroport & Plage ↔ PEM Petersen - Gare Routière | **`CONFLICTING`** | `S-A1` | `Tata` (7 identités) — §B.2/B.3 ; numéro détenu par **AFTU 78** ; `POSSIBLE_MATCH` → AFTU 3, AFTU 4 |
| 4 | `tata_218` | AFTU (`exploitation_ecosystem`) | `TATA` | **218** — détenu par DDD (S-D1/S-D2) | THIAROYE ↔ AÉROPORT LSS | Mermoz - Sacré-Cœur ↔ Keur Massar | **`CONFLICTING`** | `S-D1/S-D2` | `Tata` (7 identités) — §B.2/B.3 ; numéro détenu par **DDD 218** |
| 5 | `tata_219` | AFTU (`exploitation_ecosystem`) | `TATA` | **219** — détenu par DDD (S-D1/S-D2) | DAROUKHANE ↔ OUAKAM | Parcelles Assainies U26 - BRT ↔ PEM Petersen - Gare Routière | **`CONFLICTING`** | `S-D1/S-D2` | `Tata` (7 identités) — §B.2/B.3 ; numéro détenu par **DDD 219** ; `POSSIBLE_MATCH` → AFTU 2, AFTU 5, AFTU 25 |
| 6 | `new_commune_11` | AFTU (`exploitation_ecosystem`) | `TATA` | — aucun | — | Ouakam Cité Avion 2 ↔ Keur Massar Nord | **`MISSING`** | `—` | `Tata` (7 identités) — §B.2 ; **décision A4** : aucun numéro officiel établi, aucun conflit officiel ; ⚠️ ne pas confondre avec **DDD 11** (voir §6.3 A4) |
| 7 | `new_commune_12` | AFTU (`exploitation_ecosystem`) | `TATA` | — aucun | — | Jaxaay Nimzatt ↔ Diamniadio 2 - CICAD | **`MISSING`** | `—` | `Tata` (7 identités) — §B.2 ; **décision A4** : aucun numéro officiel établi, aucun conflit officiel ; ⚠️ ne pas confondre avec **DDD 12** (voir §6.3 A4) |

**Motifs ligne à ligne — Tata**

| Identifiant | Motif du statut |
|---|---|
| `tata_50` | Le numéro 50 est publié par AFTU pour un autre service ; l’itinéraire observé (Guédiawaye ↔ Sandaga) n’est pas celui de la ligne AFTU 50. |
| `tata_64` | Le numéro 64 est publié par AFTU pour un autre service ; l’itinéraire observé (Pikine ↔ Liberté 6) n’est pas celui de la ligne AFTU 64. |
| `tata_78` | Le numéro 78 est publié par AFTU pour un autre service ; corridor possible AFTU 3 / AFTU 4 mais aucune identité établie (POSSIBLE_MATCH). |
| `tata_218` | Le numéro 218 est publié par Dakar Dem Dikk pour un autre service ; l’itinéraire observé (Mermoz ↔ Keur Massar) n’a pas de correspondance publiée. |
| `tata_219` | Le numéro 219 est publié par Dakar Dem Dikk pour un autre service ; corridor possible AFTU 2 / 5 / 25 mais aucune identité établie (POSSIBLE_MATCH). |
| `new_commune_11` | Aucun numéro officiel établi : `new_commune_11` est un identifiant technique. Le « 11 » n’apparaît que dans cet identifiant et dans le libellé court **dérivé** « NEW 11 » ; le libellé d’origine (« Tata Ouakam - Ngor Village - Yoff Tonghor (Nord-Ouest) ») ne porte aucun numéro. Aucune publication ne numérote ce service. **Décision A4 : `MISSING`, jamais `CONFLICTING`.** ⚠️ Vigilance : ne pas confondre avec **DDD 11**. |
| `new_commune_12` | Aucun numéro officiel établi : `new_commune_12` est un identifiant technique. Le « 12 » n’apparaît que dans cet identifiant et dans le libellé court **dérivé** « NEW 12 » ; le libellé d’origine (« Tata Jaxaay - Rufisque - Diamniadio 2 (Est) ») ne porte aucun numéro. Aucune publication ne numérote ce service. **Décision A4 : `MISSING`, jamais `CONFLICTING`.** ⚠️ Vigilance : ne pas confondre avec **DDD 12**. |

---

## 3. Tableau exhaustif — lignes DDD (15)

| # | Identifiant interne | Réseau | Catégorie de service | Numéro officiel publié | Nom/libellé officiel (`S-D1`) | Origine → destination (interne) | Statut de l'identifiant | Source officielle | Correspondance référentiel Phase 3 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `ddd_1` | DDD (`operator_id`) | Urbaine (`S-D1`) | **1** (détenu par DDD) | PARCELLES ASSAINIES ↔ PLACE LECLERC | Colobane - Marché & Gare TER ↔ Yoff - Aéroport & Plage | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 1` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Parcelles Assainies → Terminus Leclerc |
| 2 | `ddd_3` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | — | Marché Sandaga - Centre Dakar ↔ Ngor - Almadies | **`MISSING`** | `S-D1/S-D2` | absent des 48 identifiants (aucune fiche) |
| 3 | `ddd_7` | DDD (`operator_id`) | Urbaine (`S-D1`) | **7** (détenu par DDD) | OUAKAM ↔ PALAIS 2 | HLM Grand Yoff ↔ Almadies - Pointe | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 7` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Ouakam → Terminus Palais 2 |
| 4 | `ddd_8` | DDD (`operator_id`) | Urbaine (`S-D1`) | **8** (détenu par DDD) | AÉROPORT LSS ↔ PALAIS 2 | Yoff - Aéroport & Plage ↔ Marché Sandaga - Centre Dakar | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 8` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Aéroport LSS → Terminus Palais 2 |
| 5 | `ddd_9` | DDD (`operator_id`) | Urbaine (`S-D1`) | **9** (détenu par DDD) | LIBERTÉ 6 ↔ PALAIS 2 | Parcelles Assainies U26 - BRT ↔ Almadies - Pointe | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 9` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Liberté 6 → Terminus Palais 2 |
| 6 | `ddd_10` | DDD (`operator_id`) | Urbaine (`S-D1`) | **10** (détenu par DDD) | LIBERTÉ 5 ↔ PALAIS 2 | Liberté 6 - BRT Correspondance ↔ Parcelles Assainies U26 - BRT | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 10` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus liberté 5 (Dieuppeul) → Terminus Palais 2 |
| 7 | `ddd_11` | DDD (`operator_id`) | Banlieue (`S-D1`) | **11** (détenu par DDD) | KEUR MASSAR ↔ LAT DIOR | UCAD - Université Cheikh Anta Diop ↔ Parcelles Assainies U26 - BRT | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 11` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Keur Massar → Terminus Lat Dior |
| 8 | `ddd_12` | DDD (`operator_id`) | Banlieue (`S-D1`) | **12** (détenu par DDD) | GUÉDIAWAYE ↔ PALAIS 1 | PEM Guédiawaye - Terminus BRT Nord ↔ Parcelles Assainies U26 - BRT | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 12` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Guédiawaye → Palais 1 |
| 9 | `ddd_14` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | — | Gare Maritime - Plateau ↔ UCAD - Université Cheikh Anta Diop | **`MISSING`** | `S-D1/S-D2` | absent des 48 identifiants (aucune fiche) |
| 10 | `ddd_15` | DDD (`operator_id`) | Banlieue (`S-D1`) | **15** (détenu par DDD) | RUFISQUE <--> PALAIS 1 | Ouakam - Cité Avion ↔ Colobane - Marché & Gare TER | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 15` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Rufisque → Palais 1 |
| 11 | `ddd_20` | DDD (`operator_id`) | Urbaine (`S-D1`) | **20** (détenu par DDD) | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | PEM Petersen - Gare Routière ↔ Rufisque - Gare TER | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 20` — canonique **`CONFIRMED`** ; orig.→dest. officielle : Terminus Dieuppeul → Terminus Dieuppeul |
| 12 | `ddd_23` | DDD (`operator_id`) | Urbaine (`S-D1`) | **23** (détenu par DDD) | PARCELLES ASSAINIES ↔ PALAIS 1 | Marché Sandaga - Centre Dakar ↔ Keur Massar | **`CONFLICTING`** | `S-D1/S-D2` | `DDD 23` — canonique **`CONFLICTING`** ; orig.→dest. officielle : Terminus des Parcelles → Terminus Palais 2 |
| 13 | `new_commune_01` | DDD (`operator_id`) | — (aucune fiche officielle) — ligne candidate, hors total officiel | — aucun | — | Fass - Colobane ↔ Biscuiterie - HLM | **`MISSING`** | `S-D1` | absent des 48 identifiants (aucune fiche) |
| 14 | `new_commune_02` | DDD (`operator_id`) | — (aucune fiche officielle) — ligne candidate, hors total officiel | — aucun | — | Rebeuss - Plateau ↔ Amitié 2 - Dakar | **`MISSING`** | `S-D1` | absent des 48 identifiants (aucune fiche) |
| 15 | `new_commune_13` | DDD (`operator_id`) | — (aucune fiche officielle) — ligne candidate, hors total officiel | — aucun | — | Sébikotane Gare 2 ↔ Rebeuss - Plateau | **`MISSING`** | `S-D1` | absent des 48 identifiants (aucune fiche) |

**Motifs ligne à ligne — DDD**

| Identifiant | Motif du statut |
|---|---|
| `ddd_1` | Le numéro 1 est publié par DDD pour un autre service : l’itinéraire interne (Colobane ↔ Yoff Pêcheurs) contredit l’itinéraire officiel. |
| `ddd_3` | Aucune ligne 3 n’est publiée par DDD : l’identifiant 3 n’existe pas dans les 48 identifiants du référentiel. |
| `ddd_7` | Le numéro 7 est publié par DDD pour un autre service : l’itinéraire interne (HLM ↔ Yoff Almadies) contredit l’itinéraire officiel. |
| `ddd_8` | Le numéro 8 est publié par DDD pour un autre service : l’itinéraire interne (Aéroport Yoff ↔ Sandaga) contredit l’itinéraire officiel. |
| `ddd_9` | Le numéro 9 est publié par DDD pour un autre service : l’itinéraire interne (Parcelles ↔ Almadies) contredit l’itinéraire officiel. |
| `ddd_10` | Le numéro 10 est publié par DDD pour un autre service : l’itinéraire interne (Liberté 6 ↔ Parcelles) contredit l’itinéraire officiel. |
| `ddd_11` | Le numéro 11 est publié par DDD pour un autre service : l’itinéraire interne (UCAD ↔ Parcelles) contredit l’itinéraire officiel. |
| `ddd_12` | Le numéro 12 est publié par DDD pour un autre service : l’itinéraire interne (Guédiawaye ↔ Parcelles Express) diffère de l’officiel (destination Palais 1). |
| `ddd_14` | Aucune ligne 14 n’est publiée par DDD : l’identifiant 14 n’existe pas dans les 48 identifiants du référentiel. |
| `ddd_15` | Le numéro 15 est publié par DDD pour un autre service : l’itinéraire interne (Ouakam ↔ Colobane) contredit l’itinéraire officiel. |
| `ddd_20` | Le numéro 20 est publié par DDD pour un autre service : l’itinéraire interne (Petersen ↔ Rufisque) contredit l’itinéraire officiel (boucle Dieuppeul). |
| `ddd_23` | Le numéro 23 est publié par DDD mais l’identité officielle est elle-même contradictoire (en-tête « PALAIS 1 », dernier arrêt publié « Palais 2 ») ; itinéraire interne (Sandaga ↔ Keur Massar) différent. |
| `new_commune_01` | Aucun numéro observé : `new_commune_01` est un identifiant technique de ligne candidate, absente de la liste publiée par DDD. |
| `new_commune_02` | Aucun numéro observé : `new_commune_02` est un identifiant technique de ligne candidate, absente de la liste publiée par DDD. |
| `new_commune_13` | Aucun numéro observé : `new_commune_13` est un identifiant technique de ligne candidate, absente de la liste publiée par DDD. |

---

## 4. Liste exacte des lignes sans identifiant officiel (item 3)

**7 lignes** — aucune ne peut recevoir un numéro officiel en l'état :

| Identifiant interne | Réseau | Pourquoi aucun numéro officiel |
|---|---|---|
| `ddd_3` | DDD | Le numéro 3 **n'existe pas** dans les 48 identifiants publiés par DDD (constat du 2026-09-24, confirmé par le référentiel §C.4). |
| `ddd_14` | DDD | Le numéro 14 **n'existe pas** dans les 48 identifiants publiés par DDD (constat du 2026-09-24, confirmé par §C.4). |
| `new_commune_01` | DDD | Ligne candidate sans source : absente de la liste publiée ; aucun numéro observé (le « 01 » est un identifiant technique). |
| `new_commune_02` | DDD | Idem `new_commune_01`. |
| `new_commune_13` | DDD | Idem `new_commune_01`. |
| `new_commune_11` | Tata | Aucun numéro dans le libellé observé (« Tata Ouakam - Ngor Village - Yoff Tonghor ») ; le « 11 » vient de l'identifiant technique. |
| `new_commune_12` | Tata | Aucun numéro dans le libellé observé (« Tata Jaxaay - Rufisque - Diamniadio 2 ») ; le « 12 » vient de l'identifiant technique. |

> **Règle appliquée** : `new_commune_11` ne signifie **pas** « ligne 11 ». Aucun de ces sept identifiants ne reçoit de numéro.

---

## 5. Correspondances confirmées (item 4)

**Aucune : 0 correspondance confirmée**, ni pour Tata ni pour DDD.

| Réseau | Résultat | Preuve |
|---|---|---|
| Tata | `CONFIRMED_MATCH` = **0** | Référentiel §B.3 : « aucune identité Tata n'est prouvée identique à une ligne AFTU publiée : ni le numéro ni l'itinéraire ne concordent ». Seuls `tata_219` (corridor AFTU 2/5/25) et `tata_78` (corridor AFTU 3/4) atteignent `POSSIBLE_MATCH`, ce qui **n'autorise ni fusion ni remappage** (§B.4). |
| DDD | **0** | Les 10 lignes internes dont le numéro est publié par DDD (1, 7, 8, 9, 10, 11, 12, 15, 20, 23) ont un itinéraire interne **contredit** par l'itinéraire officiel du même numéro ; les 5 autres n'ont aucun numéro (§4). |

**Conséquence directe** : `official_line_number` **ne peut être renseigné pour aucune des 22 lignes** — cela signifierait une identité que les sources contredisent.

---

## 6. Conflits (item 5)

### 6.1 Tata — le numéro porté est déjà publié pour un autre service (5 lignes)

| Identifiant | Numéro porté | Publié officiellement comme | Conséquence |
|---|---|---|---|
| `tata_50` | 50 | **AFTU 50** — « PETERSEN - MALIKA CIMETIERE » | Itinéraire observé (Guédiawaye ↔ Sandaga) ≠ ligne AFTU 50 → pas de remappage. |
| `tata_64` | 64 | **AFTU 64** — « GUEDIAWAYE - RUFISQUE » | Itinéraire observé (Pikine ↔ Liberté 6) ≠ ligne AFTU 64 → pas de remappage. |
| `tata_78` | 78 | **AFTU 78** — « DIAMAGUENE - LIBERTE 5 » | Corridor possible AFTU 3/4 (`POSSIBLE_MATCH`) ; numéro déjà pris → aucune fusion. |
| `tata_218` | 218 | **DDD 218** — « THIAROYE ↔ AÉROPORT LSS » | Aucune correspondance publiée pour Mermoz ↔ Keur Massar. |
| `tata_219` | 219 | **DDD 219** — « DAROUKHANE ↔ OUAKAM » | Corridor possible AFTU 2/5/25 (`POSSIBLE_MATCH`) ; aucune fusion. |

### 6.2 DDD — le numéro est publié mais désigne un autre service (10 lignes)

| Identifiant | Numéro | Ligne officielle du même numéro | Itinéraire interne (contredit) |
|---|---|---|---|
| `ddd_1` | 1 | PARCELLES ASSAINIES ↔ PLACE LECLERC | Colobane ↔ Yoff Pêcheurs |
| `ddd_7` | 7 | OUAKAM ↔ PALAIS 2 | HLM ↔ Yoff Almadies |
| `ddd_8` | 8 | AÉROPORT LSS ↔ PALAIS 2 | Aéroport Yoff ↔ Sandaga Centre |
| `ddd_9` | 9 | LIBERTÉ 6 ↔ PALAIS 2 | Parcelles ↔ Almadies via Ngor |
| `ddd_10` | 10 | LIBERTÉ 5 ↔ PALAIS 2 | Liberté 6 ↔ Patte d'Oie ↔ Parcelles |
| `ddd_11` | 11 | KEUR MASSAR ↔ LAT DIOR | UCAD ↔ Parcelles Assainies |
| `ddd_12` | 12 | GUÉDIAWAYE ↔ PALAIS 1 | Guédiawaye ↔ Parcelles Express |
| `ddd_15` | 15 | RUFISQUE <--> PALAIS 1 | Ouakam ↔ Colobane via Mermoz |
| `ddd_20` | 20 | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | Petersen ↔ Rufisque |
| `ddd_23` | 23 | PARCELLES ASSAINIES ↔ PALAIS 1 *(dernier arrêt publié : Palais 2)* | Marché Sandaga ↔ Keur Massar |

> `ddd_23` cumule **deux** conflits : interne (itinéraire observé ≠ itinéraire officiel) et **officiel** (en-tête « PALAIS 1 » vs dernier arrêt « Terminus Palais 2 ») — conflit officiel **conservé**, non arbitré (référentiel §E.1).

### 6.3 Anomalies de méthode constatées, et corrections décidées (item 8)

> **Statut de cette section (v2)** : les anomalies sont **constatées dans la donnée actuelle** et **ne sont pas corrigées ici**
> (cette version est documentaire). Les **cibles** ci-dessous sont décidées et prêtes à être appliquées dans un lot de données
> ultérieur, après votre validation explicite.

**A1 — 5 lignes portent un `conflict_reason` qui présuppose un numéro jamais observé.** *(constat inchangé)*
`new_commune_01`, `new_commune_02`, `new_commune_13` (DDD) et `new_commune_11`, `new_commune_12` (Tata) affichent un motif
de type « identité interne ≠ identité publiée … pour ce numéro » ou « le numéro porté est déjà publié par DDD … », alors
qu'**aucun numéro n'est porté** par ces lignes : le numéro n'a été déduit que de l'identifiant technique.
C'est exactement la fabrication que la règle « ne jamais fabriquer un numéro à partir de l'identifiant interne » interdit.

* **Correction décidée** (`new_commune_11`, `new_commune_12`) : `official_identifier_status = MISSING` ; `conflict_reason` et
  `conflict_sources` **retirés** (aucun conflit officiel démontré) et remplacés par `official_identifier_note` (motif du §2 + note de vigilance A4) ;
  `canonical_status` revient à `UNVERIFIED` — ce que la fiche §B.2 du référentiel indique déjà.
* **Correction proposée** (`new_commune_01`, `new_commune_02`, `new_commune_13` — DDD) : même traitement, par cohérence documentaire
  (le numéro invoqué 01/02/13 n’existe pas davantage). **Extension autorisée et appliquée** par le commanditaire le 2026-09-25 : identifiants techniques sans numéro officiel → statut d’identifiant **`MISSING`** ; aucune correspondance créée avec DDD 1, 2 ou 13 ; `official_line_number` **non renseigné** ; `canonical_status` inchangé (`UNVERIFIED`). Rectifié dans le référentiel §E.3.

**A2 — Contradiction interne sur `tata_218` et `tata_219`.** *(constat inchangé)*
Ces deux lignes portent simultanément :
`nomenclature_status = "NUMBER_NOT_PUBLISHED_BY_OPERATOR"` **et**
`conflict_reason = "Le numéro porté par cette identité est déjà publié par Dakar Dem Dikk pour un autre service…"`.
Les deux affirmations sont incompatibles : le numéro **est** publié (par DDD, cf. §6.1). La première vient du constat du
2026-09-24 (« publié par aucun opérateur »), établi **avant** la découverte des identifiants DDD 218/219 en Phase 3.

* **Correction décidée** : `nomenclature_status` passe à `"NUMBER_ALREADY_ASSIGNED_TO_DDD_LINE"` — forme calquée sur la valeur
  existante `"NUMBER_ALREADY_ASSIGNED_TO_AFTU_LINE"` déjà portée par `tata_50`/`64`/`78` — en cohérence avec le `conflict_reason`,
  qui est exact. Aucune autre valeur n'est touchée.

**A3 — Vocabulaire d'identifiant non homogène entre opérateurs.** *(constat inchangé)*
Les 3 Tata numérotés portent `official_line_number` (50, 64, 78) tandis que **les 15 lignes DDD n'ont pas ce champ du tout**,
y compris celles dont le numéro est publié (1, 7, 8…). Aucune des deux situations ne permet de distinguer
« numéro porté » de « numéro établi pour ce service ».

* **Correction décidée** : `official_line_number` **n'est pas modifié** (interdiction explicite) ; les 4 champs de §9-1 sont ajoutés
  sur les 22 lignes, dont `official_number_observed` qui **distingue désormais explicitement** « numéro porté observé » de
  « numéro établi pour ce service ». La distinction se lit dans les nouveaux champs, sans réécrire l'existant.

**A4 — DÉCISION RENDUE : `new_commune_11` et `new_commune_12` sont classés `MISSING`.**
Le §B.3 et le §E.1 du référentiel Phase 3 enregistraient pour ces deux identités une **collision de numéro avec DDD 11 / DDD 12**,
reposant sur le suffixe de l'identifiant technique (« 11 », « 12 »), **pas** sur un numéro observé.

**Décision du commanditaire (2026-09-25), enregistrée telle quelle :**

* `new_commune_11` et `new_commune_12` sont des **identifiants techniques internes** ;
* **aucun numéro officiel Tata correspondant n'a été établi** ;
* le « 11 » et le « 12 » **ne doivent donc pas** être interprétés comme des numéros de lignes ;
* la **simple ressemblance** avec les lignes DDD 11 et DDD 12 **ne constitue pas une collision officielle**.

**Conséquences** : les deux identités sont **`MISSING`** sur l'axe identifiant ; aucun conflit officiel n'étant démontré,
`canonical_status` ne peut pas rester `CONFLICTING` et doit revenir à **`UNVERIFIED`** (statut déjà porté par leur fiche §B.2) ;
`conflict_reason` et `conflict_sources` sont retirés. `internal_id` **non renommés**, `official_line_number` **non modifié**,
**aucun remappage, aucune fusion, aucune suppression**.

**⚠️ Note documentaire de vigilance (à conserver dans la donnée)** — les identifiants techniques `new_commune_11` et
`new_commune_12` peuvent être **confondus visuellement** avec les identifiants DDD **11** et **12**, qui sont deux lignes
réelles du référentiel (« KEUR MASSAR ↔ LAT DIOR » et « GUÉDIAWAYE ↔ PALAIS 1 »). Le libellé court dérivé « NEW 11 » / « NEW 12 »
renforce cette confusion. La note doit rester attachée à ces deux lignes (`official_identifier_note`) : **aucune collision
officielle n'existe ; les entités restent distinctes**.

**Erratum APPLIQUÉ au référentiel Phase 3 le 2026-09-25** (autorisation expresse du commanditaire) — le livrable porte désormais la mention **« Révision 1.1 — erratum du 2026-09-25 (décision A4, validée) »** et les passages suivants ont été rectifiés :

| Section rectifiée | Avant | Après |
|---|---|---|
| §B.2 (fiches) | `UNVERIFIED` | inchangé + renvoi à l’erratum (déjà cohérent) |
| §B.3 (tableau) | collision « DDD 11 / DDD 12 », statut `CONFLICTING` | collision **supprimée** (aucune) ; `N°` = « identifiant technique — aucun n° établi » ; statut `UNVERIFIED` + note de vigilance |
| §B.3 (bilan) | `CONFLICTING` = **7** | **5** (`tata_50/64/78/218/219`) |
| §E.1 | « 15 entités … 8 DDD + 7 Tata » | **13 = 8 DDD + 5 Tata** |
| §E.3 | « DDD candidates 13 » incluant `new_commune_01/02/13` ; « 2 » sans numéro | **10** (`ddd_1 .. ddd_23`) ; **5** (`ddd_3`, `ddd_14`, `new_commune_01/02/13`) + règle : un suffixe technique n’est jamais un numéro |
| §K.4 | « les 7 identités portent des numéros déjà attribués » | **5** identités + les 2 sans numéro établi |
| §L | STATUS : `CONFLICTING (numéro déjà pris : DDD 11/12)` | `UNVERIFIED` (identifiant technique : aucun numéro officiel établi) |
| §M (chiffre 3) | « 15 officielles : 8 DDD + 7 Tata » | **13 : 8 DDD + 5 Tata** ; renvoi « 13 + 2 » → **10 + 5** |

**Règle appliquée** : `new_commune_11` / `new_commune_12` (Tata) et `new_commune_01` / `new_commune_02` / `new_commune_13` (DDD) sont des **identifiants techniques internes** ; le suffixe n’est **pas** un numéro officiel ; **aucune collision officielle** n’en découle. Les `internal_id` ne sont **pas** renommés, `official_line_number` **n’est pas** renseigné.

---

## 7. Lignes réellement inconnues (item 6)

Sur l'**axe identifiant**, aucune ligne ne reste `UNKNOWN` : chaque ligne reçoit un verdict documenté (`CONFLICTING` ou `MISSING`).
Sur l'**axe correspondance** (recherche d'une ligne officielle équivalente), **5 identités Tata** restent `UNKNOWN` — recherche
insuffisante pour conclure, conformément au référentiel §B.3 :

| Identifiant | `match_class` (Phase 3) | Raison |
|---|---|---|
| `tata_218` | `UNKNOWN` | 5 lignes AFTU à terminus commun, un seul terminus partagé → insuffisant. |
| `tata_50` | `UNKNOWN` | 3 lignes AFTU à terminus commun → insuffisant. |
| `tata_64` | `UNKNOWN` | 3 lignes AFTU à terminus commun → insuffisant. |
| `new_commune_11` | `UNKNOWN` | 11 lignes AFTU à terminus commun, un seul partagé → insuffisant. |
| `new_commune_12` | `UNKNOWN` | 13 lignes AFTU à terminus commun, un seul partagé → insuffisant. |

*(Pour rappel : `tata_219` et `tata_78` sont `POSSIBLE_MATCH` — corridor plausible, identité non établie.)*

---

## 8. Sources utilisées (item 7)

| Code | Source | Usage dans cet audit |
|---|---|---|
| `S-A1` | `https://aftu-senegal.org/infos-pratiques/` — liste officielle des 72 lignes urbaines AFTU | Numéros et libellés officiels AFTU (50, 64, 78) ; absence de numéro pour les identités Tata. |
| `S-D1` | `https://demdikk.sn/info-voyageurs/` — titres et catégories DDD (40 entrées) | Numéros et libellés officiels DDD ; présence de 1, 7, 8, 9, 10, 11, 12, 15, 20, 23 ; absence de 3 et 14. |
| `S-D2` | `https://demdikk.sn/reseau-urbain-dakar/` — itinéraires arrêt par arrêt (40 blocs) | Origine → destination officielles, servant à établir la contradiction d'itinéraire. |
| `S-D3` | `https://demdikk.sn/` — alerte officielle ligne 01 | Renforce la publication officielle de la ligne 1. |
| `S-I1` | ITF/ILO 2020 — contexte « Tata » | « Tata » = catégorie de véhicule/service de l'écosystème AFTU (aucun réseau Tata publié). |
| — | `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` (validé) | Statuts canoniques des 48 identifiants DDD, verdicts Tata §B.3, conflits §E.1, collisions §F.2. |
| — | `docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md` (validé) | Périmètre publié, preuves d'absence. |
| — | `NOTES` du fichier (`audit_note`, `checked_against`, 2026-09-24) | Constats internes déjà documentés (lignes 3 et 14 absentes, contradictions d'itinéraires). |

**Non utilisés comme preuve** (écartés) : sources tierces (Moovit, transitrun…), OSM/`COMMUNITY`, GTFS dormant `data/gtfs/` (`stop_times.txt`), modules de réservation.

---

## 9. Modifications proposées (item 8) — **aucune n'est appliquée**

### P1 — Statut d'identifiant explicite sur les 22 lignes (recommandé)

Ajouter, **en ajout seul**, sur chacune des 22 lignes Tata/DDD :

| Champ proposé | Contenu | Notes |
|---|---|---|
| `official_identifier_status` | `CONFIRMED` / `MISSING` / `CONFLICTING` / `UNKNOWN` | Verdict de cet audit. Ici : **15 `CONFLICTING` + 7 `MISSING`**, 0 `CONFIRMED`, 0 `UNKNOWN` |
| `official_identifier_note` | motif court (§2 et §3) | Reprend le motif documenté, sans jugement |
| `official_number_observed` | numéro porté observé (`50`, `218`…) ou `null` | `null` pour les 7 lignes du §4 |
| `official_number_belongs_to` | libellé officiel du service qui détient ce numéro | `null` si aucun |

**Application ligne à ligne des 22 lignes — verdict figé par la décision A4 :**

| Statut | Nombre | Lignes |
|---|---|---|
| `CONFLICTING` | **15** | `tata_50`, `tata_64`, `tata_78`, `tata_218`, `tata_219` · `ddd_1`, `ddd_7`, `ddd_8`, `ddd_9`, `ddd_10`, `ddd_11`, `ddd_12`, `ddd_15`, `ddd_20`, `ddd_23` |
| `MISSING` | **7** | `new_commune_11`, `new_commune_12` · `ddd_3`, `ddd_14`, `new_commune_01`, `new_commune_02`, `new_commune_13` |
| `CONFIRMED` | **0** | — (aucune identité établie) |
| `UNKNOWN` | **0** | — (aucun cas restant sur l’axe identifiant) |

`official_number_observed` : renseigné pour les 15 lignes `CONFLICTING` (numéro porté par le libellé) ; **`null`** pour les 7 lignes `MISSING` — le « 11 » / « 12 » de `new_commune_11` / `new_commune_12` **n’est pas un numéro de ligne**.

**Aucune valeur existante n'est modifiée** ; `official_line_number` **reste inchangé** (aucune identité n'étant établie, il reste `null` ou absent) ;
aucune route, aucun arrêt, aucune fréquence, aucun horaire n'est ajouté ou supprimé. **Aucun nouveau réseau Tata n'est créé.**

### P2 — Correction des anomalies de méthode (§6.3)

| # | Correction **décidée** | Cible exacte |
|---|---|---|
| A1 — `new_commune_11`, `new_commune_12` | Retirer un conflit déduit d’un identifiant technique | `official_identifier_status = MISSING` ; `conflict_reason` / `conflict_sources` retirés ; `canonical_status` → `UNVERIFIED` ; `official_identifier_note` = motif + note de vigilance A4 |
| A1 — extension `new_commune_01`, `02`, `13` (DDD) | **Autorisée et appliquée au référentiel** | Identifiants techniques sans numéro officiel → `MISSING` ; aucune correspondance avec DDD 1, 2, 13 ; `official_line_number` non renseigné → **§E.3** |
| A2 — `tata_218`, `tata_219` | Supprimer la contradiction interne | `nomenclature_status` → `NUMBER_ALREADY_ASSIGNED_TO_DDD_LINE` |
| A3 — les 22 lignes | Distinguer « porté » de « établi » | Ajout des 4 champs de §9-1 ; `official_line_number` **inchangé** |
| A4 — `new_commune_11`, `new_commune_12` | **Décision rendue (v2), erratum appliqué (révision 1.1)** | `MISSING` + note de vigilance ; **erratum du référentiel Phase 3 rectifié** : §B.3, §E.1, §E.3, §K.4, §L, §M |

### P3 — Ce qui n'est **pas** proposé

Aucun remappage (`tata_50` ≠ `AFTU 50`, `tata_219` ≠ `AFTU 5`, `ddd_1` ≠ ligne 1 DDD), aucune fusion, aucun renommage, aucune suppression,
aucun numéro attribué d'office, aucune fréquence, aucun horaire, aucun arrêt, aucun itinéraire, aucune ligne nouvelle.

---

## 10. Contrôle final

| Contrôle | Attendu | Constaté |
|---|---|---|
| Lignes Tata analysées | 7 | **7** |
| Lignes DDD analysées | 15 | **15** |
| Identifiant interne fabriqué en numéro officiel | 0 | **0** |
| Modifications de fichiers de production | 0 | **0** (audit en lecture seule) |
| Routes avant / après | 105 / 105 | **105 / 105** |
| Arrêts avant / après | 117 / 117 | **117 / 117** |
| Horaires / fréquences ajoutés | 0 | **0** |
| Axe identifiant — `CONFLICTING` | 15 | **15** |
| Axe identifiant — `MISSING` | 7 | **7** |
| Axe identifiant — `CONFIRMED` | 0 | **0** |
| Axe identifiant — `UNKNOWN` | 0 | **0** |
| Identifiants techniques interprétés comme numéros (après décision A4) | 0 | **0** |
| Passages du référentiel Phase 3 rectifiés | 7 sections | **7** (§B.2, §B.3 tableau, §B.3 bilan, §E.1, §E.3, §K.4, §L, §M) |
| Identifiants internes renommés | 0 | **0** |
| `official_line_number` renseigné par cet erratum | 0 | **0** |
| SHA-256 du fichier audité | `2459dd18b5ad685b…` inchangé | **`2459dd18b5ad685b…`** |

---

## 11. Portée et suite

* Cet audit est **en lecture seule** : `dakar_network.json` n’a pas été modifié — ni par l’audit initial, ni par cette **version 2**
  (même SHA-256, mêmes 105 routes, mêmes 117 arrêts).
* **Décision A4 enregistrée et erratum appliqué** : `new_commune_11` / `new_commune_12` = **`MISSING`** (identifiants techniques), avec note de vigilance — voir §6.3 A4 et le tableau final §12.
* Les anomalies A1 / A2 / A3 sont converties en **cibles décidées** (§9-2) : elles sont **prêtes à appliquer**, mais **non appliquées**.
* **Erratum du référentiel Phase 3 : APPLIQUÉ** le 2026-09-25 → référentiel **révision 1.1** (§B.3, §E.1, §E.3, §K.4, §L, §M). L’**extension A1** aux trois lignes DDD `new_commune_01/02/13` est également appliquée au référentiel (§E.3). Voir §6.3 A4 et §12.2. **Les données, elles, restent intactes** : aucun lot de données n’est appliqué.
* **Le Lot 3 (typage du modèle Dart) reste suspendu** : le travail commencé n’a **pas** été appliqué et **aucun commit** n’a été créé pour lui.
* **Aucun commit / push n’a été effectué pour cet audit** — j’attends votre validation.
* Après validation, ordre proposé : **(1)** appliquer le lot de données (§9-1 + §9-2) — l’erratum du référentiel, lui, est **déjà appliqué** (révision 1.1) ; **(2)** puis reprendre le Lot 3
  avec un vocabulaire figé (« numéro porté observé » / « numéro établi pour ce service »).
---

## 12. Décision A4 enregistrée et tableau final de l’axe identifiant (22 lignes)

**Décision du commanditaire (2026-09-25)** : `new_commune_11` et `new_commune_12` sont classés **`MISSING`**, pas `CONFLICTING` —
identifiants techniques internes, aucun numéro officiel Tata établi, « 11 » / « 12 » qui ne sont pas des numéros de ligne,
et une simple ressemblance avec les lignes DDD 11 / DDD 12 qui ne constitue pas une collision officielle.

**Effet de la décision : `official_line_number` n’est pas modifié · les `internal_id` ne sont pas renommés ·**

**Extension A1 (autorisée le 2026-09-25)** : les trois lignes DDD `new_commune_01`, `new_commune_02` et `new_commune_13` suivent la même règle — le suffixe technique `01` / `02` / `13` **n’est pas** un numéro officiel ; **aucune correspondance** avec DDD 1, 2 ou 13 n’est créée ; `official_line_number` **non renseigné** ; statut d’identifiant **`MISSING`** conservé. Rectifié dans le référentiel §E.3.
**`new_commune_11` n’est pas transformé en « 11 », `new_commune_12` n’est pas transformé en « 12 » ·**
**aucun remappage, aucune fusion, aucune suppression, aucun arrêt, aucun horaire, aucune fréquence.**

| # | Identifiant interne | Réseau | Catégorie de service | Numéro officiel publié | Statut de l’identifiant | Service qui détient ce numéro | `match_class` |
|---|---|---|---|---|---|---|---|
| 1 | `tata_50` | AFTU (`exploitation_ecosystem`) | `TATA` | **50** | **`CONFLICTING`** | AFTU 50 | `UNKNOWN` |
| 2 | `tata_64` | AFTU (`exploitation_ecosystem`) | `TATA` | **64** | **`CONFLICTING`** | AFTU 64 | `UNKNOWN` |
| 3 | `tata_78` | AFTU (`exploitation_ecosystem`) | `TATA` | **78** | **`CONFLICTING`** | AFTU 78 | `POSSIBLE_MATCH` (AFTU 3, AFTU 4) |
| 4 | `tata_218` | AFTU (`exploitation_ecosystem`) | `TATA` | **218** | **`CONFLICTING`** | DDD 218 | `UNKNOWN` |
| 5 | `tata_219` | AFTU (`exploitation_ecosystem`) | `TATA` | **219** | **`CONFLICTING`** | DDD 219 | `POSSIBLE_MATCH` (AFTU 2, AFTU 5, AFTU 25) |
| 6 | `new_commune_11` | AFTU (`exploitation_ecosystem`) | `TATA` | — aucun | **`MISSING`** | — | `UNKNOWN` · ⚠️ vigilance : ne pas confondre avec **DDD 11** |
| 7 | `new_commune_12` | AFTU (`exploitation_ecosystem`) | `TATA` | — aucun | **`MISSING`** | — | `UNKNOWN` · ⚠️ vigilance : ne pas confondre avec **DDD 12** |
| 8 | `ddd_1` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **1** | **`CONFLICTING`** | DDD 1 | — |
| 9 | `ddd_3` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | **`MISSING`** | — | — |
| 10 | `ddd_7` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **7** | **`CONFLICTING`** | DDD 7 | — |
| 11 | `ddd_8` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **8** | **`CONFLICTING`** | DDD 8 | — |
| 12 | `ddd_9` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **9** | **`CONFLICTING`** | DDD 9 | — |
| 13 | `ddd_10` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **10** | **`CONFLICTING`** | DDD 10 | — |
| 14 | `ddd_11` | DDD (`operator_id`) | `Banlieue` (`S-D1`) | **11** | **`CONFLICTING`** | DDD 11 | — |
| 15 | `ddd_12` | DDD (`operator_id`) | `Banlieue` (`S-D1`) | **12** | **`CONFLICTING`** | DDD 12 | — |
| 16 | `ddd_14` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | **`MISSING`** | — | — |
| 17 | `ddd_15` | DDD (`operator_id`) | `Banlieue` (`S-D1`) | **15** | **`CONFLICTING`** | DDD 15 | — |
| 18 | `ddd_20` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **20** | **`CONFLICTING`** | DDD 20 | — |
| 19 | `ddd_23` | DDD (`operator_id`) | `Urbaine` (`S-D1`) | **23** | **`CONFLICTING`** | DDD 23 | — |
| 20 | `new_commune_01` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | **`MISSING`** | — | — |
| 21 | `new_commune_02` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | **`MISSING`** | — | — |
| 22 | `new_commune_13` | DDD (`operator_id`) | — (aucune fiche officielle) | — aucun | **`MISSING`** | — | — |
| **22** | **Total** | — | — | — | **15 `CONFLICTING` · 7 `MISSING` · 0 `CONFIRMED` · 0 `UNKNOWN`** | — | — |

### 12.1 Note documentaire de vigilance (à conserver)

⚠️ **Ne pas confondre `new_commune_11` / `new_commune_12` avec les lignes DDD 11 / DDD 12.**

| Identifiant technique (Tata) | Libellé court dérivé | Voie de confusion | Entité DDD réellement concernée |
|---|---|---|---|
| `new_commune_11` | « NEW 11 » | suffixe « 11 » | **DDD 11** — KEUR MASSAR ↔ LAT DIOR |
| `new_commune_12` | « NEW 12 » | suffixe « 12 » | **DDD 12** — GUÉDIAWAYE ↔ PALAIS 1 |

Ces libellés courts sont **dérivés de l’identifiant technique** (`new_commune_11` → « NEW 11 ») et **non observés** sur le terrain :
les libellés d’origine ne portent aucun numéro. La confusion est **purement visuelle** ; elle doit être signalée dans la donnée
(`official_identifier_note`) et **ne doit jamais** produire de collision, de fusion ou de remappage.

### 12.2 Erratum **appliqué** — référentiel Phase 3 révision 1.1

La décision A4 rendait caducs les passages suivants du livrable Phase 3 (validé). **Tous ont été rectifiés le 2026-09-25** (référentiel **révision 1.1**) :

| Section du référentiel | Passage | Correction **appliquée** |
|---|---|---|
| §B.2 (fiches) | `new_commune_11` / `new_commune_12` décrits `UNVERIFIED` | **déjà cohérent — aucun changement** |
| §B.3 (tableau) | collision « DDD 11 / DDD 12 » et statut `CONFLICTING` | retirer la collision ; statut → `UNVERIFIED`, statut d’identifiant → `MISSING` |
| §B.3 (bilan) | `CONFLICTING` = **7** identités | → **5** identités |
| §E.1 | « 15 entités … 8 DDD + 7 Tata » | → **13 = 8 DDD + 5 Tata** |
| §L (tableau final) | STATUS des 2 lignes : `CONFLICTING (numéro déjà pris : DDD 11/12)` | → `UNVERIFIED` |
| §M (chiffre 3) | « 15 officielles : 8 DDD + 7 Tata » | → **13 = 8 DDD + 5 Tata** |

**Contrôle d’intégrité** : `dakar_network.json` — **268473 octets**, SHA-256 `2459dd18b5ad685b…`, **105 routes**, **117 arrêts** :
strictement identiques avant et après cette version 2 (aucune écriture de donnée).
