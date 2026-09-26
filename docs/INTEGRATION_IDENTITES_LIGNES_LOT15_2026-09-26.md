# DAKAR BUS — INTÉGRATION DES IDENTITÉS DE LIGNES — LOT 15

**Titre :** DAKAR BUS — INTÉGRATION DES IDENTITÉS PUBLIQUES DE LIGNES — LOT 15
**Date :** 2026-09-26
**Nature :** Intégration documentaire d'axe « identifiant », ajout seul
**Statut :** 80 lignes enrichies · **0 identité publique CONFIRMED** · 0 donnée préexistante modifiée

Horodatage des mesures : `2026-09-26` (horloge du conteneur, UTC). Répertoire : `/home/user/dakar-bus`.

---

## §1 État initial

| Élément | Valeur mesurée |
|---|---|
| Branche courante | `arena/01a0db14-dakar-bus` |
| HEAD **à l'entrée de la session** | `203960cb07d8341c252db2a3bbe390bd974f7d3a` |
| HEAD attendu par la consigne | `703611f06fcf686954aaab24f474140aff3403af` |
| Commit parent du lot 15 | `703611f06fcf686954aaab24f474140aff3403af` (`docs: record lot 14 bis integrity state`) |
| Remote | `origin` = `https://github.com/aydiarra-star/dakar-bus.git` |
| Branche `main` distante | `203960cb07d8341c252db2a3bbe390bd974f7d3a` (non touchée) |
| Branche distante `arena/01a0db14-dakar-bus` | `703611f06fcf686954aaab24f474140aff3403af` |

### 1.1 Fait notable — `.git` recréé une seconde fois pendant la session

À l'entrée, `HEAD` valait `203960c`, **pas** `703611f`. Vérifications réelles :

```
$ git reflog --all
203960c refs/heads/arena/01a0db14-dakar-bus@{0}: branch: Created from 203960cb07d8341c252db2a3bbe390bd974f7d3a
203960c HEAD@{0}: checkout: moving from main to arena/01a0db14-dakar-bus
203960c refs/heads/main@{0}: clone: from https://github.com/aydiarra-star/dakar-bus.git
203960c refs/remotes/origin/HEAD@{0}: clone: from https://github.com/aydiarra-star/dakar-bus.git
203960c HEAD@{1}: clone: from https://github.com/aydiarra-star/dakar-bus.git

$ stat -c '%w' .git        → Birth: 2026-09-26 04:00:17.098970068 +0000
$ stat -c '%w' .git/index  → Birth: 2026-09-26 04:00:18.390976594 +0000
```

Le reflog ne contient que des opérations de `clone`/`checkout`/`branch`, et `.git` a été **créé deux fois** durant l'heure écoulée (03:46 puis 04:00). **Le commit `703611f` n'existait donc pas dans l'instance locale.**

**Il existait sur le remote** (preuve §12) — c'est précisément l'objet du lot 14 BIS. Continuité rétablie **sans réécriture ni nouveau commit** : `git merge --ff-only` sur `origin/arena/01a0db14-dakar-bus`. Le fichier `docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md`, non suivi dans la nouvelle instance, a été vérifié **octet pour octet** avant et après l'opération :

| Mesure | Valeur |
|---|---|
| SHA-256 du blob `8648e7e2…` (contenu du commit poussé) | `195b96bc05f353b441516a00979325ebfa5b500e05bf64f4655e04f8a3cb713c` |
| SHA-256 du fichier de travail | `195b96bc05f353b441516a00979325ebfa5b500e05bf64f4655e04f8a3cb713c` |
| `cmp` après restauration | **octets identiques** |

Aucune donnée n'a été perdue. `main` n'a jamais été modifiée.

### 1.2 État des fichiers critiques à l'entrée

```
$ git status --short
?? docs/RELEVE_INTEGRITE_LOT_14_BIS_2026-09-26.md      (avant fast-forward, seul écart)

flutter-src/assets/data/dakar_network.json : 166 370 octets — suivi, non modifié
data/gtfs/*.txt                            : suivi, non modifié
```

---

## §2 Méthodologie

### 2.1 Principe de preuve minimale

Une identité publique n'est intégrée **que** si une source documentée permet d'établir directement l'information. Les quatre états du projet sont utilisés sans déformation :

| État | Signification retenue |
|---|---|
| `CONFIRMED` | la source établit **directement** la correspondance |
| `UNVERIFIED` | l'information existe en interne mais la correspondance publique n'est pas démontrée |
| `MISSING` | aucune information suffisamment exploitable |
| `CONFLICTING` | une information existe mais contredit une ou plusieurs sources |

### 2.2 Interdiction absolue d'inférence

Ne sont **jamais** traités comme preuve : même numéro · nom similaire · même origine · même destination · direction · liste d'arrêts · proximité géographique · OSM · Moovit. En particulier, l'encodage « numéro interne = numéro public » a été **explicitement refusé** (voir §7.2).

### 2.3 Registre de preuves — volontairement vide

Le contrôle `scripts/check-line-identities.js` embarque un `CONFIRMED_EVIDENCE_REGISTRY` **vide**. Toute route se déclarant `CONFIRMED` sans y figurer nominativement provoque un **échec**. C'est la traduction mécanique de « preuve suffisante → intégration ; preuve insuffisante → statut de moindre prétention ».

### 2.4 Field-by-field

Une ligne peut être `CONFLICTING` sur le numéro et `UNVERIFIED`/`MISSING` sur l'origine, la destination ou les arrêts. Aucun statut de numéro ne promeut les autres champs.

---

## §3 Intégrations réellement effectuées

**80 routes enrichies, en AJOUT SEUL**, avec exactement les **4 champs** déjà définis par le lot §9-1 / PR #28 :

`official_identifier_status` · `official_identifier_note` · `official_number_observed` · `official_number_belongs_to`

### 3.1 Distribution

| Réseau | Routes | `CONFLICTING` | `MISSING` | `CONFIRMED` | `UNKNOWN` |
|---|---|---|---|---|---|
| AFTU (lot 15) | 80 | **54** | **26** | **0** | **0** |
| Tata/DDD (§9-1, inchangé) | 22 | 15 | 7 | 0 | 0 |
| **Total porteurs** | **102** | **69** | **33** | **0** | **0** |

Les **69 conflits** de la consigne (15 + 54) sont **tous conservés** : aucun n'a été transformé en identité confirmée.

### 3.2 Preuve des 54 `CONFLICTING`

Source : **référentiel canonique AFTU / Tata / Dakar Dem Dikk, révision 1.1** —
`docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md`, §A.1 (plage publiée **1–5, 24–89, 91** ; trous **6–23, 90**) et §E.3 (« 54 routes : numéro officiel porté mais itinéraire interne différent de la publication », `CONTRADICTED_BY_OPERATOR`).

La classification a été **reproduite par arithmétique indépendante** :

```
plage officielle AFTU = {1-5, 24-89, 91}
identifiants internes  = aftu_1 … aftu_72  (72) + new_commune_03 … new_commune_10  (8) = 80
  numéro ∈ plage officielle        → 54   (aftu_1-5, aftu_24-72)
  numéro ∈ trou documenté (6–23)   → 18   (aftu_6 … aftu_23)
  aucun numéro (identifiant technique) → 8
  sous-total « sans numéro publié » → 18 + 8 = 26
```

**Concordance exacte avec l'audit : 54 / 26.** Les 54 portent tous un numéro ≤ 72, donc **tous** disposent d'une page d'itinéraire publiée (§A.1 : 65 pages = n° 1–5, 24–83) : l'assertion « l'itinéraire interne contredit l'itinéraire publié » est vérifiable pour chacun.

Le tableau exhaustif des 80 lignes figure en **§3.5**.

### 3.3 Preuve des 26 `MISSING`

* **18 lignes `aftu_6` … `aftu_23`** — le numéro interne tombe dans le **trou de numérotation documenté** (6–23 non publiés, §A.1). Aucun numéro officiel AFTU n'est publié pour ces valeurs : `official_number_observed = false`, `official_number_belongs_to = null`.
* **8 lignes `new_commune_03` … `new_commune_10`** — identifiants **techniques** internes ; le suffixe n'est pas un numéro de ligne (règle de l'erratum 1.1, §E.3). Aucun numéro officiel établi.

### 3.4 Champs volontairement **non** créés

Aucun champ d'identité nouveau n'a été introduit. Le modèle existant représentait déjà l'information ; les champs `official_line_number`, `nomenclature_status`, `canonical_status`, `conflict_reason`, `match_class` etc. restent **absents** (branche historique 268473 non réintroduite), et `official_line_number` reste absent pour les 105 routes — y compris les 80 enrichies.

### 3.5 Tableau exhaustif des 80 intégrations

Colonnes : `internal_id` · `public_number` (numéro publié par l'opérateur) · `network` · `operator` · `status` · `source` · `evidence`.

| internal_id | public_number | network | operator | status | source | evidence |
|---|---|---|---|---|---|---|
| `aftu_1` | 1 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour LAT DIOR ↔ HLM GRAND YOFF ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_2` | 2 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour ROUTE PRINCIPALE PARCELLES ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_3` | 3 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour YOFF ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_4` | 4 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour YOFF VILLAGE ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_5` | 5 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour PARCELLES ASSAINIES ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_6` | 6 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_7` | 7 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_8` | 8 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_9` | 9 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_10` | 10 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_11` | 11 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_12` | 12 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_13` | 13 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_14` | 14 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_15` | 15 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_16` | 16 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_17` | 17 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_18` | 18 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_19` | 19 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_20` | 20 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_21` | 21 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_22` | 22 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_23` | 23 | AFTU | AFTU | `MISSING` | — | numéro interne dans le trou de publication 6–23 (§A.1) — aucun numéro officiel |
| `aftu_24` | 24 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour UCAD ↔ NOTAIRE GUEDIAWAYE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_25` | 25 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour PARCELLES ASSAINIES ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_26` | 26 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour PARCELLES ASSAINIES ↔ POST THIAROYE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_27` | 27 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour MARCHE BOUBESS ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_28` | 28 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour HAMO V/VI ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_29` | 29 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour CITE NATION UNIES (CAMBERENE) ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_30` | 30 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GADAYE (GUEDIEWAYE) ↔ GARE DE COLOBANE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_31` | 31 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour TALLY ICOTAF X ROUTE DES NIAYES ↔ HOPITAL ABASS NDAO ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_32` | 32 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour SAHM ↔ SERIGNE ASSANE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_33` | 33 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour COLOBANE ↔ SERIGNE ASSANE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_34` | 34 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour NORD FOIRE ↔ LAT DIOR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_35` | 35 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour NGOR ↔ PIKINE TEXACO ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_36` | 36 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour MARCHE NDIAREME ↔ NGOR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_37` | 37 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour CITÉ APIX ↔ UCAD (CLAUDEL) ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_38` | 38 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour CITE DES ENSEIGNANTS ↔ SHAM ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_39` | 39 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour LAT-DIOR ↔ DIAMALAYE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_40` | 40 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GRAND MBAO ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_41` | 41 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour PETERSEN ↔ ETAGE MADIALE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_42` | 42 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GADAYE (GUEDIEWAYE) ↔ OUAKAM BAYE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_43` | 43 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour OUAKAM ↔ THIERNO NDIAYE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_44` | 44 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GRAND MBAO ↔ OUAKAM ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_45` | 45 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour KOUNOUNE NGALAM ↔ PARCELLES EGLISE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_46` | 46 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour SDE SERIGNE ASSANE ↔ LAT DIOR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_47` | 47 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour LAT DIOR ↔ ALMADIES ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_48` | 48 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour CITE SERIGNE MANSOUR ↔ LAT DIOR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_49` | 49 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GADAYE ↔ NGOR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_50` | 50 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour PETERSEN ↔ MALIKA CIMETIERE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_51` | 51 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour JAXAAY ↔ GARE DES BAUX MARAICHERS ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_52` | 52 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour BOUNTOU PIKINE ↔ KEUR MASSAR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_53` | 53 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour KEUR MASSAR ↔ SEBIKOTANE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_54` | 54 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour TERMINUS KEUR MASSAR (CITE MTOA) ↔ UCAD ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_55` | 55 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour TERMINUS RUFISQUE SONADIS ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_56` | 56 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour JAXAAY 2 ↔ PETERSEN ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_57` | 57 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour LIBERTE 6 ↔ RUFISQUE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_58` | 58 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour SAHM ↔ COMICO ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_59` | 59 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour DIAMALAYE ↔ CITÉ GENDARMERIE (Jaxaay) ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_60` | 60 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour COLOBANE ↔ BARGNY ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_61` | 61 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour ALMADIES ↔ KEUR MASSAR ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_62` | 62 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour ARRET CHERIF (RUFISQUE) ↔ PENC MI (GUEULE TAPEE) ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_63` | 63 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour TERMINUS CAMP MARCHAND RUFISQUE ↔ STADE LSS ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_64` | 64 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GUEDIAWAYE ↔ RUFISQUE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_65` | 65 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour COLOBANE ↔ JAXAAY ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_66` | 66 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour YOFF ↔ GOROM 1 ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_67` | 67 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour OUAKAM ↔ THIAWLENE RUFISQUE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_68` | 68 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour YEUMBEUL ↔ SEBIKOTANE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_69` | 69 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour DIAMALAYE ↔ TERMINUS TIVAOUANE PEUL ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_70` | 70 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour DAROUKHANE ↔ JAXXAY 2 ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_71` | 71 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour KEUR MASSAR ↔ CLAUDEL ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `aftu_72` | 72 | AFTU | AFTU | `CONFLICTING` | `S-A1` §A.2 | n° publié pour GUEDIAWAYE ↔ KOUNOUNE ; itinéraire interne ≠ itinéraire publié (§E.3) |
| `new_commune_03` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_04` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_05` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_06` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_07` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_08` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_09` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |
| `new_commune_10` | — | AFTU | AFTU | `MISSING` | — | identifiant technique : le suffixe n’est pas un numéro de ligne (erratum 1.1) |

**Total : 80 lignes enrichies** — 54 `CONFLICTING` + 26 `MISSING`.

---

## §4 Identités volontairement non intégrées

| Cas | Volume | Raison de non-intégration |
|---|---|---|
| `aftu_6` … `aftu_23` | 18 | numéro dans le **trou de publication** AFTU (6–23) : aucun numéro officiel n'existe. Le suffixe interne n'est **pas** une preuve. |
| `new_commune_03` … `new_commune_10` | 8 | identifiants **techniques** : le suffixe n'est pas un numéro de ligne. |
| toutes les lignes AFTU — origine / destination / direction / arrêts | 80 | le référentiel publie l'identité et l'itinéraire **de la ligne officielle**, pas la correspondance avec l'identité interne. Aucun remappage. |
| `tata_78`, `tata_219` | 2 | `POSSIBLE_MATCH` de corridor (AFTU 3/4 ; AFTU 2/5/25) : **un corridor identique n'est pas un service identique** (§B.4, §F.3). |
| `new_commune_11`, `new_commune_12` | 2 | aucun numéro officiel Tata établi ; existence et exploitant à confirmer. |
| DDD `6, 23, 208, 217, 218, 232, 233, 501` | 8 | contradictions **officielles** conservées, non arbitrées. |
| DDD `15A/15B, 502A/502B, 503A/503B, 504A/504B` | 8 | itinéraires et différenciation des variantes non publiés. |
| DDD `311, 319, 327` | 3 | source officielle unique : corroboration manquante. |
| horaires, fréquences, temps réel | — | **hors périmètre du lot 15** (voir §11). |

---

## §5 Conflits conservés

**69 conflits conservés, 0 résolu par conversion** :

| Foyer | Volume | Nature du conflit |
|---|---|---|
| AFTU internes | **54** | numéro officiel porté, **itinéraire interne différent** de la publication (§E.3, `CONTRADICTED_BY_OPERATOR`) |
| Tata | **5** | numéro déjà publié par un **autre** exploitant pour un autre service : AFTU 50/64/78 ; DDD 218/219 |
| DDD candidates | **10** | numéro officiel attribué à une **autre** identité (`ddd_1` … `ddd_23`) |
| **Total** | **69** | aucun arbitrage, aucune fusion, aucune suppression |

**Collisions inter-réseaux documentées** (§F.2) — **signalées dans la note**, jamais fusionnées : AFTU 1 / DDD 1 · AFTU 2 / DDD 2 · AFTU 4 / DDD 4 · AFTU 5 / DDD 5. Le contrôle refuse toute route AFTU concernée dont la note ne mentionne pas explicitement la collision (`UNDOCUMENTED_COLLISION`).

---

## §6 Tata — pourquoi aucune conversion automatique

« Tata » désigne, d'après le référentiel (§B.3, §B.4), une **catégorie de service** (`S-I1`) exploitée par des GIE de l'écosystème AFTU — **pas un réseau public numéroté autonome**. Preuves consignées :

* `CONFIRMED_MATCH` Tata → AFTU = **0** : « ni le numéro ni l'itinéraire ne concordent » ;
* `OPERATORS[].official_line_count = null` pour `tata` : aucun total officiel publié ;
* interdits de méthode (§B.4) : créer un réseau `TATA`, remapper `tata_50 → AFTU 50` / `tata_64 → AFTU 64` / `tata_78 → AFTU 78`, fusionner `tata_219` avec AFTU 5/25 ou `tata_78` avec AFTU 3/4.

Conséquences appliquées dans ce lot :

| Règle | Mise en œuvre |
|---|---|
| `tata_50 ≠ AFTU 50`, `tata_64 ≠ AFTU 64`, `tata_78 ≠ AFTU 78` | `official_number_belongs_to = "AFTU"` (le numéro appartient à AFTU, pas au Tata) ; aucune réécriture d'identité |
| `tata_218 ≠ DDD 218`, `tata_219 ≠ DDD 219` | `official_number_belongs_to = "DDD"` ; statut `CONFLICTING` conservé |
| aucun réseau `TATA` | contrôle `TATA_NETWORK_INVENTED` : `official_number_belongs_to === "TATA"` est **refusé** ; 0 occurrence dans la donnée |
| `new_commune_11` / `new_commune_12` | non transformés en « 11 » / « 12 » : `MISSING` conservé |

**Correspondances Tata confirmées par le lot 15 : 0.** Aucune preuve nouvelle n'a été apportée : le lot n'en a fabriqué aucune.

---

## §7 AFTU

### 7.1 Correspondances prouvées

Le lot 15 n'établit **aucune** correspondance identité interne ↔ ligne publique. Ce qu'il établit, sur preuve documentée, est plus étroit et strictement vérifiable :

* le **numéro officiel AFTU existe** pour 54 identités internes (plage 1–5, 24–89, 91) — et l'itinéraire interne **contredit** la publication ;
* le **numéro officiel n'existe pas** pour 26 identités internes (trou 6–23, ou identifiant technique).

`official_number_belongs_to = "AFTU"` signifie **« ce numéro est publié par l'AFTU »**, jamais « cette identité interne **est** la ligne AFTU n° N ». La distinction est portée par `official_identifier_status = CONFLICTING`.

### 7.2 Correspondances refusées

| Refus | Motif |
|---|---|
| `aftu_6` … `aftu_23` → « AFTU 6 » … « AFTU 23 » | **inférence par le numéro** : ces numéros ne sont **pas publiés** (trou documenté) |
| `new_commune_03` … `new_commune_10` → « AFTU 03 » … « AFTU 10 » | suffixe **technique**, pas un numéro |
| toute identité interne → ligne officielle AFTU de même numéro | un numéro partagé **ne fusionne rien** (§A.5) ; 54 conflits conservés |
| `AFTU 5` ↔ `AFTU 25` | **deux lignes distinctes**, corridors d'approche incompatibles (§D item 1) |
| `AFTU 84–89, 91` | aucun itinéraire publié : `ROUTE_NOT_FOUND` est un **fait**, non une lacune à combler (§D item 2). Ces numéros **n'ont pas de contrepartie interne** (l'identifiant interne s'arrête à `aftu_72`) |
| arrêts AFTU | **aucune source n'en publie** (§K.2) : 0 arrêt créé |

### 7.3 Contrôle anti-fausses-correspondances AFTU

La règle mécanique interdit une intégration fondée sur le seul numéro :

> pour toute route `aftu_N`, `official_number_observed` doit valoir **exactement** `N ∈ {1-5, 24-89, 91}`.

C'est-à-dire : « numéro observé » ⟺ « numéro réellement publié ». Un `aftu_9` marqué observé, ou un `aftu_40` marqué non observé, **fait échouer** le contrôle (`NUMBER_INFERENCE`).

---

## §8 DDD — variantes et ambiguïtés conservées

Le lot 15 **ne touche aucune ligne DDD** : leurs 15 verdicts (§9-1) sont inchangés et vérifiés par le contrôle (`FROZEN_TUPLE_CHANGED`).

Variantes traitées **séparément**, jamais fusionnées, sur preuve officielle (§D) :

| Variantes | Verdict conservé | Preuve de non-fusion |
|---|---|---|
| `16A` / `16B` | deux services distincts | listes d'arrêts officielles différentes (Hamo/Guédiawaye/Icotaf/Colobane vs Keur Massar/Thiaroye/Yarakh/Bel Air) |
| `502A`/`502B`, `503A`/`503B` | `PARTIAL` ; `502B` (Abass Ndao) et `503B` (Hydrocarbure) **non couverts** par un itinéraire publié | observation de corridor seulement, pas une identité |
| `15A`/`15B`, `504A`/`504B` | itinéraires **non publiés** → interdiction d'intégration (§K.2) | — |
| `TAF TAF` / `TAF` / `TO1` | **un service, trois désignations publiées** : non dupliqué | `S-D1` + `S-D2` ; variante « Sphère Ministérielle » sans arrêts publiés |

**DDD : 0 correspondance nouvelle, 0 variante fusionnée.**

---

## §9 TER / BRT — identités documentées intactes

Vérification (lecture seule) :

| Contrôle | TER | BRT |
|---|---|---|
| Nombre de services exposés | 1 (`ter_dakar_diamniadio`) | 2 (`brt_b1_guediawaye_petersen`, `brt_b2_express`) |
| identité publique | « TER » — Dakar Gare ↔ Diamniadio | « BRT B1 » (OMNIBUS) / « BRT B2 Express » (SEMI_EXPRESS) |
| `data_status` / `source_type` | `CONFIRMED` / `OFFICIAL_STATIC` | `CONFIRMED` / `OFFICIAL_STATIC` |
| Gares / stations | **13** | **23** (B1) et **7** (B2) |
| Champs d'identité du lot ajoutés | **aucun** | **aucun** |

Séparation maintenue entre identité de ligne, fréquence, géométrie, liste de stations et statut temps réel :

* **la fréquence officielle n'a pas été convertie en horaires** : `schedule_status = UNKNOWN` pour **105/105** routes (inchangé) ;
* **`shapes.txt` non modifié** (§11) ;
* `B3` reste **non exposée** (`services_not_exposed`, `exposed:false`) ; `B4` reste `FUTURE` ; le prolongement TER vers AIBD reste `FUTURE`. Aucune de ces entités n'a été promue.

---

## §10 Impact sur l'application

**Impact fonctionnel : nul.**

* Les quatre champs d'identité ne sont **lus par aucun code de l'application** : recherche exhaustive `official_identifier|official_number` dans `flutter-src/lib/` → **0 occurrence**. Ils n'existent que dans `flutter-src/assets/data/dakar_network.json` et dans les tests/contrôles.
* **Aucun libellé affiché ne change** : `short_name`, `long_name`, `operator_id`, `type`, `stops`, `schedule_status`, `data_status`, `audit_note` et `audit_flags` sont **strictement inchangés** pour les 105 routes.
* L'application ne peut donc **pas** afficher un numéro public nouveau, ni une correspondance nouvelle : aucune n'a été intégrée.
* Le delta de données est **exclusivement documentaire** : 320 lignes ajoutées, 0 supprimée, 0 modifiée (§11).

---

## §11 Données NON modifiées

| Objet | État | Preuve |
|---|---|---|
| `data/gtfs/shapes.txt` | **NON modifié** | SHA-256 `80a84ebad85ae58e1081e5308e709bd0262dcdd383c1532a80169396091f27eb` — identique à la mesure du lot 14 BIS |
| `data/gtfs/stops.txt` | **NON modifié** | SHA-256 `e9b8081069cf977150645101671037d17f3576d11044836322240e0cd0a8ac49` — identique |
| `data/gtfs/stop_times.txt` | **NON modifié** | SHA-256 `3f90f8f00b247cc5fb79200e2e8ead9b8a8f9abe3e187b532056e62059e0c346` — identique |
| `data/gtfs/trips.txt` | **NON modifié** | SHA-256 `568377c6e59c491b40405d88f555a9696a798650398f3a1f9ec43f6888a11824` — identique |
| `data/gtfs/routes.txt` | **NON modifié** | SHA-256 `bbc838005a6fe36312c979fc0c1374eb9f7c917afb5ca772b8ba85ac909328c6` — identique |
| `dakar_network.json` — **données préexistantes** | **NON modifiées** | empreinte **FNV-1a 32 = `0x0F206256`** (4 champs d'identité retirés, 105 routes) : **identique avant et après** l'ajout |
| `dakar_network.json` — arrêts | **NON modifiés** | 117 arrêts, inchangé ; aucun arrêt créé, renommé, déplacé |
| `dakar_network.json` — opérateurs / sources | **NON modifiés** | 5 opérateurs, 9 sources, 3 `services_not_exposed` — inchangés |
| horaires | **NON modifiés** | `schedule_status = UNKNOWN` sur **105/105** ; aucune ligne passée de `UNKNOWN` à `SCHEDULED` |
| fréquences | **NON modifiées** | aucune fréquence créée ; aucune fréquence convertie en horaire |
| géométrie | **NON modifiée** | aucune coordonnée, polyligne ou tracé touché |
| GPS | **NON modifié** | aucun code GPS touché |
| arrêts TER/BRT | **NON modifiés** | 13 gares TER / 23 stations BRT / 7 stations B2 — inchangés |
| temps réel | **NON modifié** | aucun flux, aucun code temps réel touché ; `UNKNOWN` partout |

### 11.1 Preuve du delta « ajout seul »

```
$ git diff --stat
 flutter-src/assets/data/dakar_network.json | 320 +++++++++++++++++++++++++++++
 1 file changed, 320 insertions(+)

$ git diff -U0 | grep -c '^+[^+]'   → 320
$ git diff -U0 | grep -c '^-[^-]'   → 0

$ git diff -U0 | grep '^+[^+]' | grep -oE '"official_[a-z_]+"' | sort | uniq -c
     80 "official_identifier_note"
     80 "official_identifier_status"
     80 "official_number_belongs_to"
     80 "official_number_observed"
```

**320 lignes ajoutées = 80 routes × 4 champs. Zéro ligne supprimée. Aucune ligne ajoutée hors de ces 4 clés** (le filtre de contrôle ci-dessus ne renvoie rien). Les 22 routes Tata/DDD du §9-1, TER, BRT, arrêts, opérateurs, `dataset_meta` et `services_not_exposed` n'apparaissent **nulle part** dans le diff.

---

## §12 Validation

Commandes réellement exécutées dans cet environnement :

| Commande | Résultat mesuré | Référence | Écart |
|---|---|---|---|
| `npm test` | **24/24 réussis**, 0 échec, exit 0 | 35/35 (historique déclaré) | **11 tests** — écart préexistant, documenté au lot 14 BIS, non corrigé |
| `npm run check:identites` | **CONFORME**, exit 0 | *nouveau (lot 15)* | — |
| `npm run transit:layer:check` | **script inexistant** (`Missing script`) | « à jour » (historique déclaré) | non exécutable — signalé, non contourné |
| `npm run validate:data` | **exit 1** — 11 lignes de constats, **294 occurrences pondérées** | 112 constats (historique déclaré) | **+182** — écart préexistant, documenté au lot 14 BIS, **strictement inchangé par le lot 15** |
| `flutter test` | **NON EXÉCUTÉ** — outil absent de l'environnement (`which flutter dart` → vide) | — | voir §12.2 |

**Aucun validateur n'a été modifié pour faire disparaître une erreur.** `scripts/check-arrets.js`, `scripts/lib/transit-validation.js` et `tests/transit-validation.test.js` sont **inchangés**.

### 12.1 Contrôle anti-fausses-correspondances — 10 tests négatifs

Un contrôle qui ne rejette rien ne prouve rien. Le contrôle a donc été éprouvé sur des **copies** (jamais sur la donnée de production), par mutation volontaire :

| Mutation tentée | Attendu | Résultat |
|---|---|---|
| `aftu_6` déclaré `CONFIRMED` | rejet | ✅ `UNPROVEN_CONFIRMED_IDENTITY` |
| `aftu_6` déclaré avec numéro observé (hors plage) | rejet | ✅ `NUMBER_INFERENCE` |
| `aftu_1` : champ préexistant modifié | rejet | ✅ `PREEXISTING_DATA_MODIFIED` |
| `aftu_1` : mention de collision DDD 1 retirée | rejet | ✅ `UNDOCUMENTED_COLLISION` |
| `official_line_number` ajouté | rejet | ✅ `FORBIDDEN_FIELD` |
| note contenant « semble / probablement » | rejet | ✅ `FORBIDDEN_JUSTIFICATION` |
| `tata_64` → `official_number_belongs_to = "TATA"` | rejet | ✅ `TATA_NETWORK_INVENTED` |
| champ d'identité ajouté à TER | rejet | ✅ `TER/BRT` → `OTHER_NETWORK_TOUCHED` |
| `official_identifier_note` supprimé | rejet | ✅ `PARTIAL_IDENTITY_FIELDS` |
| statut `UNKNOWN` sur une route AFTU | rejet | ✅ `UNDETERMINED_IDENTITY` |

**10/10 rejetés.** Contre-épreuve sur la donnée réelle : **exit 0, CONFORME**.

### 12.2 Tests Dart — mise à jour nécessaire et transparence

L'ajout des 4 champs aux 80 routes AFTU **invalide deux assertions** du test §9-1, qui encodaient l'ancien périmètre :

* `exactement 22 routes portent official_identifier_status` → devenu **102** ;
* `les 4 champs … sur les 22, et sur elles seules` → l'alternative « TER/BRT hors périmètre » doit distinguer les 80 AFTU.

Ces deux assertions ont été **mises à jour strictement** (`flutter-src/test/official_identifier_test.dart`), **sans toucher** aux verrous du §9-1 : tuples des 22 routes, distribution 15/7, `kEmpreinteNotes = 0x3E4A6A27`, `kEmpreinteDonneesExistantes = 0x0F206256` — tous conservés à l'identique. Un groupe `Lot 15 — identités documentaires des 80 lignes AFTU` a été ajouté (6 tests) verrouillant : distribution 54/26/0, « observé ⟺ plage officielle », « observé ⟺ propriétaire AFTU », notes non vides, TER/BRT hors axe, aucun numéro attribué à « TATA ».

**`flutter test` n'a pas pu être exécuté ici** : `flutter` et `dart` sont absents de l'environnement. Ce fait est signalé et **non masqué**. Compensations apportées :

1. l'implémentation FNV-1a 32 utilisée a été **validée contre les vecteurs officiels** (`""`→`0x811C9DC5`, `"a"`→`0xE40C292C`, `"foobar"`→`0xBF9CF968`, `"hello"`→`0x4F9F2CAB`) ;
2. les **deux** empreintes figées du test Dart ont été **reproduites exactement** sur la donnée réelle (`0x0F206256` et `0x3E4A6A27`), ce qui démontre que l'implémentation et la donnée sont conformes au verrou §9-1 ;
3. la **logique** des 6 nouveaux tests a été rejouée en miroir sur la donnée réelle (6/6 ✅) et par `npm run check:identites` ;
4. l'équilibre syntaxique du fichier Dart a été contrôlé (délimiteurs équilibrés, 21 tests, 2 groupes).

La CI `Flutter web build (J9)` (qui exécute `flutter analyze` + `flutter test`) est le vérificateur de référence ; elle a réussi sur `main` au commit `203960c`.

---

## §13 Fichiers touchés par le lot 15

| Fichier | Nature | Lignes |
|---|---|---|
| `flutter-src/assets/data/dakar_network.json` | 4 champs d'identité ajoutés aux 80 routes AFTU (ajout seul) | +320 / −0 |
| `scripts/check-line-identities.js` | **nouveau** — contrôle anti-fausses-correspondances | 280 lignes |
| `flutter-src/test/official_identifier_test.dart` | mise à jour du périmètre (2 assertions) + groupe AFTU (6 tests) | +125 / −8 |
| `package.json` | script `check:identites` | +1 |
| `.github/workflows/transit-validation.yml` | exécution du contrôle en CI | +2 |
| `docs/INTEGRATION_IDENTITES_LIGNES_LOT15_2026-09-26.md` | **nouveau** — le présent rapport | — |

Aucune autre modification. Aucun fichier de production, aucune géométrie, aucun horaire, aucune donnée GTFS.

---

## §14 Rapport final

```
DAKAR BUS — LOT 15 — ÉTAT FINAL
Branche                          : arena/01a0db14-dakar-bus
HEAD à l'entrée de session       : 203960cb07d8341c252db2a3bbe390bd974f7d3a
HEAD rétabli (fast-forward)      : 703611f06fcf686954aaab24f474140aff3403af
HEAD après commit                : voir §12 de la réponse (SHA du commit lot 15)
Commit parent                    : 703611f06fcf686954aaab24f474140aff3403af

Lignes ENRICHIES                 : 80
Identités CONFIRMED              : 0
Conflits CONSERVÉS                : 69   (54 AFTU + 15 Tata/DDD)
Restées MISSING                  : 33   (26 AFTU + 7 Tata/DDD)
Correspondances AFTU confirmed   : 0
Correspondances DDD confirmed    : 0
Correspondances Tata confirmed   : 0
TER / BRT                        : intacts (1 TER + 2 BRT, 13 gares / 23 + 7 stations ; 0 champ ajouté)

Données préexistantes modifiées  : 0     (FNV-1a 0x0F206256 inchangée)
Arrêts / opérateurs / sources     : 117 / 5 / 9 — inchangés
shapes.txt                       : NON modifié
Horaires / fréquences            : NON modifiés (schedule_status UNKNOWN 105/105)
Géométrie / GPS                  : NON modifiés
Arrêts TER/BRT                   : NON modifiés
Temps réel                       : NON modifié

npm test                         : 24/24, 0 échec (référence 35/35 — écart préexistant)
npm run check:identites          : CONFORME, exit 0 (10/10 tests négatifs rejetés)
npm run transit:layer:check      : script inexistant — non exécutable
npm run validate:data            : exit 1, 294 constats (inchangé par le lot 15)
flutter test                     : NON EXÉCUTÉ — flutter/dart absents de l'environnement

main                             : NON touchée
arena/01a0d8ed-dakar-bus         : NON touchée
Pull request                     : NON créée
```

Les 22 identités Tata/DDD du lot §9-1 sont **strictement inchangées** (tuples, notes, empreintes) : le lot 15 est un ajout d'axe, pas une réécriture.

---

*Fin du rapport d'intégration des identités de lignes — Lot 15. Le Lot 16 n'est pas engagé.*
