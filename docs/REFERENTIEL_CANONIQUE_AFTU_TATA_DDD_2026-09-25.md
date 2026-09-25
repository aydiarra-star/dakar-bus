# Référentiel canonique — AFTU / Tata / Dakar Dem Dikk

**Phase 3 — construction du référentiel canonique (résolution et préparation, aucune intégration).**

> **Révision 1.1 — erratum du 2026-09-25 (décision A4, validée).** Les interprétations antérieures de `new_commune_11` et `new_commune_12` sont rectifiées : ce sont des **identifiants techniques internes** ; **aucun numéro officiel Tata n’a été établi** pour ces deux fiches ; leur ressemblance avec **DDD 11** et **DDD 12** **ne constitue pas une collision officielle**. Par la même règle, le suffixe technique `01` / `02` / `13` des identifiants `new_commune_01`, `new_commune_02` et `new_commune_13` (DDD) **n’est pas un numéro officiel**. Passages rectifiés : §B.3 (tableau + bilan), §E.1, §E.3, §K.4, §L, §M (chiffre 3). **Aucune donnée, aucun identifiant interne, aucune ligne, aucun arrêt, aucun horaire et aucune fréquence ne sont modifiés.** Détail de la décision : `docs/ETAPE_3A_AUDIT_IDENTIFIANTS_TATA_DDD_2026-09-25.md` (§6.3 A4, §12).

**Date de vérification des sources : 2026-09-25** · **HEAD de référence : `09767c2b1633dead91b35821c74f74d4a5d97395`**

**Périmètre : documentaire uniquement.** Ce document ne modifie ni l'UI, ni le moteur de départs, ni `dakar_network.json`, ni `departure-frequencies.json`, ni aucun test. Il constitue la référence de résolution à valider **avant** toute intégration (Phase 4).

**Rapport d'entrée (validé) :** `docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md` — la Phase 3 en reprend les faits établis et **ajoute les résolutions** obtenues par lecture des sources officielles.

---

## 0. Méthode, conventions et statuts

### 0.1 Ce que cette phase résout

La Phase 2 a établi **ce qui est publié**. La Phase 3 tranche ce qui peut l'être **sur preuve officielle** :

| Question ouverte en Phase 2 | Résolution Phase 3 | Preuve |
|---|---|---|
| AFTU **5 vs 25** : doublon ? | **NON DOUBLON** — deux services distincts | descriptions d'itinéraire officielles divergentes (§A.3) |
| AFTU **84–89, 91** : itinéraires ? | **AUCUN itinéraire publié** (confirmé par 4 voies) | sitemap des cartes, sitemap des collections, recherche du site, API REST (§A.4) |
| DDD **16A vs 16B** | **DEUX SERVICES DISTINCTS** | listes d'arrêts officielles différentes (§C.2) |
| DDD **10 vs 13** | **DEUX SERVICES DISTINCTS** | itinéraires officiels différents (§F.1) |
| DDD **5 vs 6 vs 12** | **TROIS SERVICES DISTINCTS** | trois itinéraires officiels différents (§F.1) |
| DDD **18 vs 20** | **DEUX BOUCLES DISTINCTES** | listes d'arrêts différentes ; « conflit » de pages levé (§F.1) |
| DDD **227 vs 327** | **DEUX SERVICES DISTINCTS** | arrêts intermédiaires différents (§F.1) |
| DDD **502 vs 503** | **DEUX BOUCLES DISTINCTES** | listes d'arrêts différentes (§F.1) |
| Tata **78 / 219** vs AFTU | **POSSIBLE_MATCH** de corridor, **CONFLICTING** de numéro | terminus identiques à des lignes AFTU publiées (§B.3) |

### 0.2 Règles absolues appliquées (reconduites de la Phase 2)

1. **Ne jamais fabriquer** : horaire, fréquence, arrêt, itinéraire, correspondance, temps réel.
2. **Une description de rues AFTU reste `ROUTE_DOCUMENTED`** : elle ne devient jamais `STOP_SEQUENCE_CONFIRMED`.
3. **`stop_times.txt` dormant jamais utilisé** comme source officielle ; `data/gtfs/` reste hors référentiel.
4. **Aucune fréquence convertie en horaire** ; aucune amplitude convertie en grille.
5. **Aucune fusion ni suppression** : les doublons sont *résolus en qualification*, jamais supprimés.
6. **Aucun arbitrage manuel** d'une contradiction officielle : une contradiction n'est levée que si une **liste d'arrêts officielle** la lève ; sinon elle reste `CONFLICTING`.
7. **Le référentiel interne est une liste candidate** ; la source officielle prévaut toujours.

### 0.3 Statuts canoniques

| Statut | Définition |
|---|---|
| `CONFIRMED` | identité **et** contenu concordants entre les sources officielles disponibles (ou source unique officielle non contredite) |
| `PARTIAL` | identité publiée mais contenu incomplet (itinéraire ou arrêts ou horaires manquants), **sans contradiction** |
| `CONFLICTING` | deux passages officiels donnent des identités/contenus **incompatibles** : conservé tel quel |
| `UNVERIFIED` | présent dans le référentiel interne, **absent** des sources officielles |
| `UNKNOWN` | champ sans aucune donnée officielle |

Sous-qualificatifs de route (exigés par la Phase 3) :

| Qualificatif | Signification |
|---|---|
| `ROUTE_DOCUMENTED` | itinéraire décrit par l'exploitant sous forme de **rues / points de repère** (AFTU) |
| `STOP_SEQUENCE_CONFIRMED` | itinéraire publié sous forme de **liste d'arrêts ordonnée** (DDD, page `reseau-urbain-dakar`) |
| `ROUTE_NOT_FOUND` | aucune publication d'itinéraire (AFTU 84–89/91, DDD 15A/B, 502A/B, 503A/B, 504A/B) |

### 0.4 Codes sources utilisés dans les tableaux

| Code | Source |
|---|---|
| `S-A1` | `https://aftu-senegal.org/infos-pratiques/` (liste officielle des lignes AFTU) |
| `S-A2` | page d'itinéraire AFTU correspondante `https://aftu-senegal.org/map/dakar-urbain-ligne-{N}/` |
| `S-A3` | `https://aftu-senegal.org/waymark_map-sitemap.xml` (inventaire des pages d'itinéraire) |
| `S-D1` | `https://demdikk.sn/info-voyageurs/` |
| `S-D2` | `https://demdikk.sn/reseau-urbain-dakar/` |
| `S-D3` | `https://demdikk.sn/` (alerte officielle ligne 01) |
| `S-D4` | `https://demdikk.sn/offres-de-transport/` (Express AIBD) |
| `S-I1` | ITF/ILO 2020 (contexte « Tata ») |

---

## A. AFTU — référentiel canonique des 72 lignes

**Source principale : `S-A1`.** Pour chaque ligne : identité officielle (numéro + origine + destination) **CONFIRMÉE**, itinéraire **`ROUTE_DOCUMENTED`** (rues) pour 65 lignes, **`ROUTE_NOT_FOUND`** pour 7 lignes, **aucun arrêt**, **aucun horaire**, **aucune fréquence**.

### A.1 Rappel du périmètre officiel

| Élément | Valeur |
|---|---|
| Lignes publiées | **72** (n° 1–5, 24–89, 91) |
| Trous de numérotation | 6–23, 90 (non publiés) |
| Pages d'itinéraire | **65** (n° 1–5, 24–83) — `S-A2` + `S-A3` |
| Sans page d'itinéraire | **7** (n° 84, 85, 86, 87, 88, 89, 91) — lien « Voir itinéraire » renvoyant vers `S-A1` |
| Arrêts explicites publiés | **0** |
| Horaires publiés | **0** |
| Fréquences publiées | **0** |

### A.2 Fiches canoniques (72 lignes)

`ROUTE_DESCRIPTION` = nature de l'itinéraire **publié** ; `EXPLICIT_STOPS` = arrêts nommés. `STATUS` : `PARTIAL` = identité confirmée + itinéraire documenté sans arrêts ni horaires ; `UNVERIFIED` = identité confirmée mais itinéraire absent.

| LINE_ID | OFFICIAL_NAME | ORIGIN | DESTINATION | ROUTE_DESCRIPTION | EXPLICIT_STOPS | SOURCE | VERIFIED_AT | STATUS |
|---|---|---|---|---|---|---|---|---|
| `AFTU 1` | LAT DIOR- HLM GRAND YOFF | LAT DIOR | HLM GRAND YOFF | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 2` | ROUTE PRINCIPALE PARCELLES - PETERSEN | ROUTE PRINCIPALE PARCELLES | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 3` | YOFF - PETERSEN | YOFF | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 4` | YOFF VILLAGE - PETERSEN | YOFF VILLAGE | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 5` | PARCELLES ASSAINIES- PETERSEN | PARCELLES ASSAINIES | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 24` | UCAD - NOTAIRE GUEDIAWAYE | UCAD | NOTAIRE GUEDIAWAYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 25` | PARCELLES ASSAINIES - PETERSEN | PARCELLES ASSAINIES | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 26` | PARCELLES ASSAINIES - POST THIAROYE | PARCELLES ASSAINIES | POST THIAROYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 27` | MARCHE BOUBESS - PETERSEN | MARCHE BOUBESS | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 28` | HAMO V/VI - PETERSEN | HAMO V/VI | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 29` | CITE NATION UNIES (CAMBERENE) - PETERSEN | CITE NATION UNIES (CAMBERENE) | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 30` | GADAYE (GUEDIEWAYE) - GARE DE COLOBANE | GADAYE (GUEDIEWAYE) | GARE DE COLOBANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 31` | TALLY ICOTAF X ROUTE DES NIAYES - HOPITAL ABASS NDAO | TALLY ICOTAF X ROUTE DES NIAYES | HOPITAL ABASS NDAO | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 32` | SAHM - SERIGNE ASSANE | SAHM | SERIGNE ASSANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 33` | COLOBANE - SERIGNE ASSANE | COLOBANE | SERIGNE ASSANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 34` | NORD FOIRE - LAT DIOR | NORD FOIRE | LAT DIOR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 35` | NGOR - PIKINE TEXACO | NGOR | PIKINE TEXACO | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 36` | MARCHE NDIAREME - NGOR | MARCHE NDIAREME | NGOR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 37` | CITÉ APIX - UCAD (CLAUDEL) | CITÉ APIX | UCAD (CLAUDEL) | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 38` | CITE DES ENSEIGNANTS - SHAM | CITE DES ENSEIGNANTS | SHAM | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 39` | LAT-DIOR - DIAMALAYE | LAT-DIOR | DIAMALAYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 40` | GRAND MBAO - PETERSEN | GRAND MBAO | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 41` | PETERSEN - ETAGE MADIALE | PETERSEN | ETAGE MADIALE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 42` | GADAYE (GUEDIEWAYE) - OUAKAM BAYE | GADAYE (GUEDIEWAYE) | OUAKAM BAYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 43` | OUAKAM - THIERNO NDIAYE | OUAKAM | THIERNO NDIAYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 44` | GRAND MBAO - OUAKAM | GRAND MBAO | OUAKAM | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 45` | KOUNOUNE NGALAM - PARCELLES EGLISE | KOUNOUNE NGALAM | PARCELLES EGLISE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 46` | SDE SERIGNE ASSANE - LAT DIOR | SDE SERIGNE ASSANE | LAT DIOR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 47` | LAT DIOR - ALMADIES | LAT DIOR | ALMADIES | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 48` | CITE SERIGNE MANSOUR - LAT DIOR | CITE SERIGNE MANSOUR | LAT DIOR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 49` | GADAYE - NGOR | GADAYE | NGOR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 50` | PETERSEN - MALIKA CIMETIERE | PETERSEN | MALIKA CIMETIERE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 51` | JAXAAY - GARE DES BAUX MARAICHERS | JAXAAY | GARE DES BAUX MARAICHERS | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 52` | BOUNTOU PIKINE - KEUR MASSAR | BOUNTOU PIKINE | KEUR MASSAR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 53` | KEUR MASSAR - SEBIKOTANE | KEUR MASSAR | SEBIKOTANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 54` | TERMINUS KEUR MASSAR (CITE MTOA) - UCAD | TERMINUS KEUR MASSAR (CITE MTOA) | UCAD | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 55` | TERMINUS RUFISQUE SONADIS - PETERSEN | TERMINUS RUFISQUE SONADIS | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 56` | JAXAAY 2 - PETERSEN | JAXAAY 2 | PETERSEN | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 57` | LIBERTE 6 - RUFISQUE | LIBERTE 6 | RUFISQUE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 58` | SAHM - COMICO | SAHM | COMICO | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 59` | DIAMALAYE - CITÉ GENDARMERIE (Jaxaay) | DIAMALAYE | CITÉ GENDARMERIE (Jaxaay) | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 60` | COLOBANE - BARGNY | COLOBANE | BARGNY | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 61` | ALMADIES - KEUR MASSAR | ALMADIES | KEUR MASSAR | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 62` | ARRET CHERIF (RUFISQUE) - PENC MI (GUEULE TAPEE) | ARRET CHERIF (RUFISQUE) | PENC MI (GUEULE TAPEE) | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 63` | TERMINUS CAMP MARCHAND RUFISQUE - STADE LSS | TERMINUS CAMP MARCHAND RUFISQUE | STADE LSS | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 64` | GUEDIAWAYE - RUFISQUE | GUEDIAWAYE | RUFISQUE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 65` | COLOBANE - JAXAAY | COLOBANE | JAXAAY | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 66` | YOFF - GOROM 1 | YOFF | GOROM 1 | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 67` | OUAKAM - THIAWLENE RUFISQUE | OUAKAM | THIAWLENE RUFISQUE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 68` | YEUMBEUL - SEBIKOTANE | YEUMBEUL | SEBIKOTANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 69` | DIAMALAYE - TERMINUS TIVAOUANE PEUL | DIAMALAYE | TERMINUS TIVAOUANE PEUL | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 70` | DAROUKHANE - JAXXAY 2 | DAROUKHANE | JAXXAY 2 | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 71` | KEUR MASSAR - CLAUDEL | KEUR MASSAR | CLAUDEL | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 72` | GUEDIAWAYE - KOUNOUNE | GUEDIAWAYE | KOUNOUNE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 73` | LAC ROSE - POSTE THIAROYE | LAC ROSE | POSTE THIAROYE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 74` | TERMINUS BARGNY (GARE FERROVIAIRE) - TIVAOUNE PEUL | TERMINUS BARGNY (GARE FERROVIAIRE) | TIVAOUNE PEUL | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 75` | TERMINUS MALIKA (CITE SONATEL) - TERMINUS GARE ROUTIERE COLOBANE | TERMINUS MALIKA (CITE SONATEL) | TERMINUS GARE ROUTIERE COLOBANE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 76` | SIPRES - CITE ASSURANCE | SIPRES | CITE ASSURANCE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 77` | RUFISQUE - LIBERTE 5 | RUFISQUE | LIBERTE 5 | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 78` | DIAMAGUENE - LIBERTE 5 | DIAMAGUENE | LIBERTE 5 | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 79` | SANGALKAM - CAMBERENE | SANGALKAM | CAMBERENE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 80` | DIAMALAYE - DAROU THIOUB | DIAMALAYE | DAROU THIOUB | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 81` | BEAUX MARRAICHERS - TIVAOUNE PEUL | BEAUX MARRAICHERS | TIVAOUNE PEUL | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 82` | LAT DIOR - COMICO YEUMBEUL | LAT DIOR | COMICO YEUMBEUL | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 83` | RUFISQUE ARAFAT- ZONE DE CAPTAGE | RUFISQUE ARAFAT | ZONE DE CAPTAGE | `ROUTE_DOCUMENTED` (rues / points de repère) | `UNKNOWN` — non publiés | `S-A1` + `S-A2` | 2026-09-25 | `PARTIAL` |
| `AFTU 84` | UCAD - JAXAAY | UCAD | JAXAAY | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 85` | BANOBA - LIBERTE 5 | BANOBA | LIBERTE 5 | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 86` | TOURNALOU BOUNE - TOUBAB DIALAW | TOURNALOU BOUNE | TOUBAB DIALAW | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 87` | BAMBILOR - MOSQUEE MASSALIKOU DJINANE | BAMBILOR | MOSQUEE MASSALIKOU DJINANE | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 88` | MTOA - LIBERTE 5 | MTOA | LIBERTE 5 | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 89` | BARGNY - CROISEMENT NIAGUE (CITE SICAP) | BARGNY | CROISEMENT NIAGUE (CITE SICAP) | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |
| `AFTU 91` | APIX - DOUGAR | APIX | DOUGAR | `ROUTE_NOT_FOUND` | `UNKNOWN` — non publiés | `S-A1` | 2026-09-25 | `UNVERIFIED` |

### A.3 Collision AFTU 5 / AFTU 25 — **RÉSOLUE : deux lignes distinctes**

| Critère | AFTU 5 | AFTU 25 |
|---|---|---|
| Numéro officiel | 5 | 25 |
| Libellé officiel | PARCELLES ASSAINIES- PETERSEN | PARCELLES ASSAINIES - PETERSEN |
| Origine | Terminus Gare des Parcelles Assainies | Terminus Gare des Parcelles Assainies |
| Destination | Terminus Petersen | Terminus Gare Petersen |
| Source officielle | `S-A1` + `S-A2` (ligne 5) | `S-A1` + `S-A2` (ligne 25) |
| Itinéraire publié | **via Route de l'Église – Route des Niayes – Pont Stade LSS – Autoroute Seydina L – Route principale de Grand Yoff – HOGGY – Route du front de terre – Av. Bourguiba – Av. Cheikh Amadou Bamba Mbacké (rue 13) – rues 39/17/22/25/37 – Av. Blaise Diagne – Av. Émile Badiane – Rue Mangin** | **via Route principale des Parcelles Assainies – École Dior – Carrefour HLM Grand Médine/Diamalayé – VDN prolongée – Échangeur de la Foire – VDN – Carrefour Seydou N Tall – Av. Cheikh Anta Diop – Av. Blaise Diagne – Av. Émile Badiane – Rue Mangin** |
| Segment terminal commun | Av. Blaise Diagne – Av. Émile Badiane – Rue Mangin – Petersen | idem |
| **Verdict** | **DOUBLON ÉCARTÉ** — deux services distincts | corridors d'approche **incompatibles** : côte nord par les Niayes / Grand Yoff pour la 5 ; axe VDN – Cheikh Anta Diop pour la 25. **Les deux lignes sont conservées, aucune fusion, aucune suppression.** |

> Le libellé strictement identique de `S-A1` est donc un **effet d'homonymie de terminus**, pas un doublon. Seule la lecture des pages d'itinéraire (`S-A2`) permet de le démontrer — la Phase 3 ne s'appuie donc sur aucune supposition.

### A.4 Lignes AFTU 84, 85, 86, 87, 88, 89, 91 — **itinéraire non publié (vérifié par 4 voies)**

| Vérification | Résultat |
|---|---|
| Page `S-A1` : lien « Voir itinéraire » | renvoie vers `S-A1` (elle-même), sans contenu d'itinéraire |
| Sitemap des cartes `S-A3` | **65 entrées** — les n° 84–89 et 91 sont **absentes** |
| Sitemap des collections `waymark_collection-sitemap.xml` | collections pour 1–5, 24–83 + une collection globale : **aucune collection 84–91** |
| Recherche interne du site (`?s=ligne+84`, API REST `wp/v2/search`) | **aucun résultat** hors la page `S-A1` |
| Ancienne URL `/map/dakar-urbain-ligne-84/` | **404** |

**Conclusion : `ROUTE_NOT_FOUND` est un fait documentaire, pas une lacune d'exploration.** Les 7 lignes restent `PARTIAL` au niveau identité (numéro + origine + destination publiés par l'exploitant) et `UNKNOWN` au niveau itinéraire/arrêts/horaires.

| Ligne | Libellé officiel | Origine | Destination | Itinéraire | STATUT |
|---|---|---|---|---|---|
| `AFTU 84` | UCAD - JAXAAY | UCAD | JAXAAY | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 85` | BANOBA - LIBERTE 5 | BANOBA | LIBERTE 5 | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 86` | TOURNALOU BOUNE - TOUBAB DIALAW | TOURNALOU BOUNE | TOUBAB DIALAW | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 87` | BAMBILOR - MOSQUEE MASSALIKOU DJINANE | BAMBILOR | MOSQUEE MASSALIKOU DJINANE | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 88` | MTOA - LIBERTE 5 | MTOA | LIBERTE 5 | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 89` | BARGNY - CROISEMENT NIAGUE (CITE SICAP) | BARGNY | CROISEMENT NIAGUE (CITE SICAP) | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |
| `AFTU 91` | APIX - DOUGAR | APIX | DOUGAR | `ROUTE_NOT_FOUND` | `UNVERIFIED` (itinéraire) |

### A.5 Enseignement sur la nomenclature AFTU

- Les 12 lignes internes du référentiel portant un numéro officiel **sans page d'itinéraire** (`AFTU 73–83`) n'ont **pas** d'itinéraire à opposer ; en revanche la ligne **27** et la ligne **36** n'étaient joignables que par une URL de prévisualisation (`?post_type=waymark_map&p=…&preview=true`) ; elles **redirigent** vers leurs pages propres (`/map/dakar-urbain-ligne-27/`, `/map/dakar-urbain-ligne-36/`). Aucune n'est manquante.
- Le référentiel interne porte 54 identités AFTU avec un numéro publié mais un **itinéraire différent** (`CONTRADICTED_BY_OPERATOR` dans `dakar_network.json`) et 26 identifiants sans numéro publié (`NUMBER_NOT_PUBLISHED_BY_OPERATOR`). **Ces conflits internes ne sont pas traités dans cette phase** : ils relèveront d'une phase de correction après validation (voir §K).

---

## B. TATA — les 7 identités existantes du référentiel

**Aucun réseau « Tata » n'est publié** (`S-A1`, `S-D1`). Les sources établissent que « Tata » est une **catégorie de véhicule/service** exploitée dans l'écosystème AFTU (`S-I1`). Le référentiel interne contient **7 identités** classées `operator_id = tata` — elles sont **conservées telles quelles** (aucune suppression, aucun remappage).

### B.1 Rappel du modèle cible retenu (aucune écriture dans cette phase)

```
network        = AFTU          # jamais un second réseau « TATA »
service_category = TATA        # catégorie de service / de véhicule
line_id        = <identifiant interne conservé>
```

La Phase 3 **ne crée aucun réseau TATA** : c'est exactement le sens de la consigne « ne pas créer un deuxième réseau TATA si les données correspondent à des services AFTU ». Les 7 identités restent décrites par `service_category = TATA` et `exploitation_ecosystem = AFTU` (champs déjà présents dans `dakar_network.json`).

### B.2 Fiches des 7 identités (lecture seule du référentiel)

| Identifiant | Libellé observé (interne) | Arrêts internes | Catégorie | Écosystème | Statut interne |
|---|---|---|---|---|---|
| `new_commune_11` | Tata Ouakam - Ngor Village - Yoff Tonghor (Nord-Ouest) | Ouakam Cité Avion 2, Ngor Village - Yoff, Yoff Tonghor - Aéroport, Keur Massar Nord | `TATA` | `AFTU` | `UNVERIFIED` |
| `new_commune_12` | Tata Jaxaay - Rufisque - Diamniadio 2 (Est) | Jaxaay Nimzatt, Rufisque Ouest - Dangou, Rufisque Nord - Castor, Diamniadio 2 - CICAD | `TATA` | `AFTU` | `UNVERIFIED` |
| `tata_218` | Mermoz ↔ Keur Massar (Tata 218) | Mermoz - Sacré-Cœur, Sacré-Cœur - BRT, Grand Yoff - BRT & AFTU Hub, Pikine - Marché Zinc / TER, Keur Massar | `TATA` | `AFTU` | `UNVERIFIED` |
| `tata_219` | Parcelles Assainies ↔ Petersen (Tata 219) | Parcelles Assainies U26 - BRT, PEM Petersen - Gare Routière | `TATA` | `AFTU` | `UNVERIFIED` |
| `tata_50` | Guédiawaye ↔ Sandaga (Tata Ligne 50) | PEM Guédiawaye - Terminus BRT Nord, Pikine - Marché Zinc / TER, Colobane - Marché & Gare TER, PEM Petersen - Gare Routière, Marché Sandaga - Centre Dakar | `TATA` | `AFTU` | `CONFLICTING` |
| `tata_64` | Pikine ↔ Liberté 6 (Tata Ligne 64) | Pikine - Marché Zinc / TER, Scat Urbam - Parcelles, Patte d'Oie - BRT, Liberté 6 - BRT Correspondance | `TATA` | `AFTU` | `CONFLICTING` |
| `tata_78` | Yoff ↔ Petersen via Cambérène (Tata 78) | Yoff - Aéroport & Plage, Cambérène - BRT, Parcelles Assainies U26 - BRT, PEM Petersen - Gare Routière | `TATA` | `AFTU` | `CONFLICTING` |

> **Erratum 1.1** : `new_commune_11` et `new_commune_12` sont des identifiants **techniques** internes ; leur fiche reste `UNVERIFIED` (aucun numéro officiel établi). La collision de numéro qui leur était attribuée en §B.3 est **supprimée** : voir la note de bas de tableau B.3.

### B.3 Recherche de correspondance AFTU — méthode et résultat

Méthode : pour chaque identité, (1) collision de numéro avec les listes **officielles** AFTU et DDD, (2) correspondance de **terminus** avec les 72 libellés officiels AFTU.

| Identifiant | N° | Correspondance AFTU par terminus | Identités AFTU candidates | Collision de numéro | MATCH_CLASS | STATUT canonique |
|---|---|---|---|---|---|---|
| `new_commune_11` | identifiant technique — **aucun n° établi** | 11 ligne(s) AFTU à terminus commun | correspondance partielle (un seul terminus commun) : AFTU 1, AFTU 3, AFTU 4, AFTU 35, AFTU 36… | **aucune** — le « 11 » est un suffixe technique, non un numéro publié (⚠️ ne pas confondre avec **DDD 11**) | `UNKNOWN` | `UNVERIFIED` |
| `new_commune_12` | identifiant technique — **aucun n° établi** | 13 ligne(s) AFTU à terminus commun | correspondance partielle (un seul terminus commun) : AFTU 51, AFTU 55, AFTU 56, AFTU 57, AFTU 59… | **aucune** — le « 12 » est un suffixe technique, non un numéro publié (⚠️ ne pas confondre avec **DDD 12**) | `UNKNOWN` | `UNVERIFIED` |
| `tata_218` | 218 | 5 ligne(s) AFTU à terminus commun | correspondance partielle (un seul terminus commun) : AFTU 52, AFTU 53, AFTU 54, AFTU 61, AFTU 71 | **DDD 218** = « THIAROYE ↔ AÉROPORT LSS » | `UNKNOWN` | `CONFLICTING` |
| `tata_219` | 219 | 15 ligne(s) AFTU à terminus commun | terminus **identiques** à AFTU 2, AFTU 5 et AFTU 25 (« PARCELLES ASSAINIES – PETERSEN ») | **DDD 219** = « DAROUKHANE ↔ OUAKAM » | `POSSIBLE_MATCH` | `CONFLICTING` |
| `tata_50` | 50 | 3 ligne(s) AFTU à terminus commun | correspondance partielle (un seul terminus commun) : AFTU 24, AFTU 64, AFTU 72 | **AFTU 50** = « PETERSEN - MALIKA CIMETIERE » | `UNKNOWN` | `CONFLICTING` |
| `tata_64` | 64 | 3 ligne(s) AFTU à terminus commun | correspondance partielle (un seul terminus commun) : AFTU 35, AFTU 52, AFTU 57 | **AFTU 64** = « GUEDIAWAYE - RUFISQUE » | `UNKNOWN` | `CONFLICTING` |
| `tata_78` | 78 | 16 ligne(s) AFTU à terminus commun | terminus **identiques** à AFTU 3 (« YOFF – PETERSEN ») et AFTU 4 (« YOFF VILLAGE – PETERSEN ») | **AFTU 78** = « DIAMAGUENE - LIBERTE 5 » | `POSSIBLE_MATCH` | `CONFLICTING` |

**Bilan de la classification demandée (les deux dimensions sont distinctes) :**

| Classe | Nombre | Identités |
|---|---|---|
| `CONFIRMED_MATCH` | **0** | — (aucune identité Tata n'est prouvée identique à une ligne AFTU publiée : ni le numéro ni l'itinéraire ne concordent) |
| `POSSIBLE_MATCH` | **2** | `tata_78` (corridor AFTU 3/4), `tata_219` (corridor AFTU 2/5/25) |
| `CONFLICTING` | **5** | `tata_50`, `tata_64`, `tata_78`, `tata_218`, `tata_219` : le numéro qu’elles portent est déjà publié par un exploitant pour un **autre** service (AFTU 50/64/78 ; DDD 218/219). *Erratum 1.1 : `new_commune_11` et `new_commune_12` sortent de cette classe — elles ne portent aucun numéro officiel.* |
| `NO_MATCH` | **0** | — |
| `UNKNOWN` | **5** | `new_commune_11`, `new_commune_12`, `tata_218`, `tata_50`, `tata_64` (correspondance de terminus insuffisante pour conclure) |

> **Note de bas de tableau (erratum 1.1 — décision A4)** : `new_commune_11` et `new_commune_12` sont des **identifiants techniques internes**. **Aucun numéro officiel Tata n’a été établi** pour ces deux fiches ; leur ressemblance avec **DDD 11** (« KEUR MASSAR ↔ LAT DIOR ») et **DDD 12** (« GUÉDIAWAYE ↔ PALAIS 1 »), qui sont deux lignes réelles, **ne constitue pas une collision officielle**. Elles sont `UNVERIFIED` et leur identifiant est `MISSING` (aucun numéro officiel retrouvé), jamais `CONFLICTING`. ⚠️ **Vigilance** : les libellés courts dérivés « NEW 11 » / « NEW 12 » entretiennent une confusion visuelle avec DDD 11 / DDD 12 — ne jamais les lire comme des numéros de ligne.

*(Cette note remplace la collision de numéro « DDD 11 / DDD 12 » précédemment enregistrée.)*

> Les colonnes `MATCH_CLASS` (service) et `STATUT` (numérotation) ne se contredisent pas : un service peut avoir un **corridor plausible** chez AFTU tout en portant un **numéro déjà attribué à un autre service**. Les deux informations sont conservées séparément, sans arbitrage.

### B.4 Ce qu'il ne faut surtout pas faire (consigné pour la Phase 4)

| Interdit | Raison |
|---|---|
| Créer un réseau `TATA` avec `line_id = X` | aucun réseau Tata n'est publié ; « Tata » est une catégorie de service (`S-I1`) |
| Remapper `tata_50` → `AFTU 50`, `tata_64` → `AFTU 64`, `tata_78` → `AFTU 78` | identités officielles **incompatibles** (`S-A1`) : ce serait fabriquer une correspondance |
| Fusionner `tata_219` avec `AFTU 5`/`25` ou `tata_78` avec `AFTU 3`/`4` | corridor identique ≠ service identique : `POSSIBLE_MATCH` n'autorise aucune fusion |
| Supprimer une identité Tata | aucune donnée ne doit disparaître d'un référentiel |

---

## C. DDD — référentiel canonique des lignes actuelles

**Sources principales : `S-D1` (titres, catégories, horaires TAF TAF) et `S-D2` (itinéraires arrêt par arrêt).**

### C.1 Périmètre publié

| Élément | Valeur |
|---|---|
| Identifiants distincts publiés (union des deux pages) | **48** |
| Blocs d'itinéraire publiés sur `S-D2` | **40 blocs** (la ligne **18** y est publiée **deux fois**) → **39 identifiants** avec itinéraire |
| Identifiants sans aucun itinéraire publié | **9** : 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B, TAF TAF |
| Horaires publiés | **2 services** : ligne **1** (`S-D3`) et **TAF TAF** (`S-D1`) |
| Fréquences publiées | **0** |
| Temps réel public | **aucun** (CCO interne seulement) |

### C.2 Fiches canoniques des 48 identifiants

`ITIN.` : `STOP_SEQUENCE_CONFIRMED` = liste d'arrêts officielle ordonnée publiée ; `ROUTE_NOT_FOUND` = aucun itinéraire. `ARRÊTS` : `OUI` = liste ordonnée publiée (premier/dernier arrêt relevés) ; `NON` = non publiés. Statuts : voir §0.3.

| LINE_ID | CATÉGORIE | LIBELLÉ OFFICIEL (S-D1) | ORIGINE → DESTINATION (S-D2) | ITIN. | ARRÊTS | HORAIRE | FRÉQ. | STATUS | SOURCE |
|---|---|---|---|---|---|---|---|---|---|
| `DDD 501` | Desserte gare TER | GARE DE DAKAR ↔ PALAIS 2 | Terminus Palais 2 → Terminus Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 502A` | Desserte gare TER | COLOBANE ↔ UCAD | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 502B` | Desserte gare TER | COLOBANE ↔ ABASS NDAO | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 503A` | Desserte gare TER | COLOBANE ↔ MOLE 8 | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 503B` | Desserte gare TER | COLOBANE ↔ HYDROCARBURE | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 504A` | Desserte gare TER | GARE DIAMNIADIO ↔ SPHERE MINISTERIEL | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 504B` | Desserte gare TER | SEBIKOTANE ↔ GARE DIAMNIADIO | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 1` | Urbaine | PARCELLES ASSAINIES ↔ PLACE LECLERC | Terminus Parcelles Assainies → Terminus Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `SCHEDULE_CONFIRMED` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` + `S-D3` |
| `DDD 4` | Urbaine | LIBERTÉ 5 ↔ PLACE LECLERC | Terminus Liberté 5 (Dieuppeul) → Terminus Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 7` | Urbaine | OUAKAM ↔ PALAIS 2 | Terminus Ouakam → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 8` | Urbaine | AÉROPORT LSS ↔ PALAIS 2 | Terminus Aéroport LSS → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 9` | Urbaine | LIBERTÉ 6 ↔ PALAIS 2 | Terminus Liberté 6 → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 10` | Urbaine | LIBERTÉ 5 ↔ PALAIS 2 | Terminus liberté 5 (Dieuppeul) → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 13` | Urbaine | LIBERTÉ 5 ↔ PALAIS 2 | Terminus liberté 5 (Dieuppeul) → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 18` | Urbaine | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | Terminus Liberté 5 (Dieuppeul) → Terminus Liberté 5 (Dieuppeul) | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 20` | Urbaine | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | Terminus Dieuppeul → Terminus Dieuppeul | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 23` | Urbaine | PARCELLES ASSAINIES ↔ PALAIS 1 | Terminus des Parcelles → Terminus Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 121` | Urbaine | SCAT URBAM ↔ LECLERC | Terminus Scat Urban → Terminus Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 319` | Urbaine | LIBERTÉ 6 <--> OUAKAM | Terminus liberté 6 → Terminus Ouakam | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD 502` | Urbaine | GARE DE GARE <--> GARE DE GARE | Gare colobane → Gare Colobane | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD 503` | Urbaine | GARE DE GARE <--> GARE DE GARE | Gare de Colobane → Gare de Colobane | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD TO1` | TAF TAF (catégorie propre) | TAF TAF OUAKAM (TO1) : OUAKAM <--> PALAIS 2 | Terminus Ouakam → Palais 2 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD TAF` | TAF TAF (catégorie propre) | TAF TAF : OUAKAM ↔ AIBD | Terminus Ouakam → AIBD | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD TAF TAF` | TAF TAF (catégorie propre) | OUAKAM ↔ AIBD / SPHÈRE MINISTÉRIELLE (Diamniadio) | — | `ROUTE_NOT_FOUND` | NON | `SCHEDULE_CONFIRMED` (premiers/derniers départs) | `UNKNOWN` | `CONFIRMED` | `S-D1` |
| `DDD 2` | Banlieue | DAROUKHANE ↔ PLACE LECLERC | Terminus Daroukhane → Terminus Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 5` | Banlieue | GUÉDIAWAYE ↔ PALAIS 1 | Terminus Guédiawaye → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 6` | Banlieue | CAMBÉRÈNE 2 ↔ PALAIS 2 | Terminus Guédiawaye → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 11` | Banlieue | KEUR MASSAR ↔ LAT DIOR | Terminus Keur Massar → Terminus Lat Dior | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 12` | Banlieue | GUÉDIAWAYE ↔ PALAIS 1 | Terminus Guédiawaye → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 15` | Banlieue | RUFISQUE <--> PALAIS 1 | Terminus Rufisque → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D2` |
| `DDD 15A` | Banlieue | RUFISQUE ↔ PALAIS 1 | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 15B` | Banlieue | RUFISQUE ↔ PALAIS 1 | — | `ROUTE_NOT_FOUND` | NON | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| `DDD 16A` | Banlieue | MALIKA ↔ PALAIS 1 | Terminus Malika → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 16B` | Banlieue | MALIKA ↔ PALAIS 1 | Terminus Malika → Palais 1 | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 208` | Banlieue | BAYAKH ↔ RUFISQUE | Gorom 01 → Rufisque | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 213` | Banlieue | RUFISQUE ↔ DIEUPPEUL | Gare de Rufisque → Terminus Dieuppeul | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 217` | Banlieue | THIAROYE ↔ OUAKAM | Dépôt Thiaroye → Terminus aéroport LSS | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 218` | Banlieue | THIAROYE ↔ AÉROPORT LSS | Dépôt Thiaroye → Terminus aéroport LSS | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 219` | Banlieue | DAROUKHANE ↔ OUAKAM | Daroukhane → Terminus Ouakam | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 220` | Banlieue | RUFISQUE ↔ GUÉDIAWAYE | Terminus Rufisque → Terminus Guediawaye | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 221` | Banlieue | GADAYE ↔ ALMADIES | Terminus Gadaye (Filaos) → Terminus Almadies | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 227` | Banlieue | TERMINUS KEUR MASSAR ↔ TERMINUS PARCELLES | Terminus Keur Massar → Terminus Parcelles | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 228` | Banlieue | TERMINUS RUFISQUE ↔ YENNE | Terminus Rufisque → Diamniadio Yenne | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 232` | Banlieue | BAUX MARAICHERS ↔ AÉROPORT LSS | Baux Maraichers → Terminus Aéroport LSS | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 233` | Banlieue | BAUX MARAICHERS ↔ PALAIS 1 | Baux Maraichers → Terminus Aéroport LSS | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1` + `S-D2` |
| `DDD 234` | Banlieue | JAXAAY ↔ LECLERC | TERMINUS JAXAAY (Mosquée Niakoul Rab) → Leclerc | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1` + `S-D2` |
| `DDD 311` | Banlieue | LAC ROSE <--> CROISSEMENT KEUR MASSAR | Lac rose croissement Niague → Retour vers Lac Rose | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| `DDD 327` | Banlieue | KEUR MASSAR <--> TERMINUS PARCELLES | Terminus Keur Massar → Terminus Parcelles | `STOP_SEQUENCE_CONFIRMED` | **OUI** | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |

### C.3 Détail des statuts et des motifs

| LINE_ID | STATUT | Motif documentaire |
|---|---|---|
| `DDD 501` | `CONFLICTING` | terminus divergents entre les deux pages (GARE DE DAKAR ↔ PALAIS 2 / PALAIS 2 ↔ LECLERCL) |
| `DDD 502A` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; corridor « Colobane → UCAD » partiellement couvert par la boucle 502 |
| `DDD 502B` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; corridor « Abass Ndao » non couvert par la boucle 502 |
| `DDD 503A` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; corridor « Mole 8 » partiellement couvert par la boucle 503 |
| `DDD 503B` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; corridor « Hydrocarbure » non couvert par la boucle 503 |
| `DDD 504A` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; absente de la page « reseau-urbain-dakar » |
| `DDD 504B` | `PARTIAL` | desserte gare du TER : titre seul, aucun itinéraire publié ; absente de la page « reseau-urbain-dakar » |
| `DDD 1` | `CONFIRMED` | identité concordante sur les deux pages ; itinéraire arrêt par arrêt ; horaires 1er/dernier départ (alerte officielle) |
| `DDD 4` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 7` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 8` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 9` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 10` | `CONFIRMED` | identité concordante ; itinéraire propre (distinct de la 13) |
| `DDD 13` | `CONFIRMED` | identité concordante ; itinéraire propre (distinct de la 10) |
| `DDD 18` | `CONFIRMED` | boucle Dieuppeul → Centre-ville → Dieuppeul confirmée par les arrêts ; l'intitulé de la page « reseau-urbain » omet le retour (bloc publié deux fois) |
| `DDD 20` | `CONFIRMED` | boucle confirmée par les arrêts ; itinéraire propre (distinct de la 18) |
| `DDD 23` | `CONFLICTING` | en-tête « PALAIS 1 » mais le dernier arrêt publié est « Terminus Palais 2 » |
| `DDD 121` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 319` | `PARTIAL` | itinéraire arrêt par arrêt publié, mais identité absente de la page « info-voyageurs » (source unique) |
| `DDD 502` | `PARTIAL` | boucle « GARE DE GARE » publiée avec arrêts (Gare Colobane → UCAD → Gare Colobane) ; scission 502A/502B non couverte |
| `DDD 503` | `PARTIAL` | boucle « GARE DE GARE » publiée avec arrêts (Gare de Colobane → Mole 8 → Gare de Colobane) ; scission 503A/503B non couverte |
| `DDD TO1` | `PARTIAL` | arrêts publiés (Ouakam ↔ Palais 2) ; variante absente de « info-voyageurs » (source unique) |
| `DDD TAF` | `PARTIAL` | arrêts publiés (Ouakam → AIBD) ; désignation propre à la page « reseau-urbain » |
| `DDD TAF TAF` | `CONFIRMED` | service TAF TAF : horaires officiels (premiers/derniers départs) ; arrêts non publiés sur cette page |
| `DDD 2` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 5` | `CONFIRMED` | identité concordante ; itinéraire propre (distinct de 6 et 12) |
| `DDD 6` | `CONFLICTING` | identités incompatibles entre les deux pages (CAMBÉRÈNE 2 ↔ PALAIS 2 / GUÉDIAWAYE ↔ PALAIS 1) |
| `DDD 11` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 12` | `CONFIRMED` | identité concordante ; itinéraire propre (distinct de 5 et 6) |
| `DDD 15` | `CONFIRMED` | itinéraire arrêt par arrêt publié (identité de base « 15 ») |
| `DDD 15A` | `PARTIAL` | variante non documentée : même intitulé que 15B, aucun itinéraire propre |
| `DDD 15B` | `PARTIAL` | variante non documentée : même intitulé que 15A, aucun itinéraire propre |
| `DDD 16A` | `CONFIRMED` | variante A : itinéraire propre publié (Malika → Hamo/Guédiawaye/Icotaf → Colobane → Palais 1) |
| `DDD 16B` | `CONFIRMED` | variante B : itinéraire propre publié (Malika → Keur Massar/Thiaroye/Yarakh/Bel Air → Palais 1) |
| `DDD 208` | `CONFLICTING` | en-tête « BAYAKH » absent de la liste publiée (premier arrêt : Gorom 01) |
| `DDD 213` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 217` | `CONFLICTING` | en-tête « OUAKAM » mais dernier arrêt publié « Terminus aéroport LSS » |
| `DDD 218` | `CONFLICTING` | liste d'arrêts strictement identique à celle de la ligne 217 |
| `DDD 219` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 220` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 221` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 227` | `CONFIRMED` | itinéraire propre publié (distinct de la 327), arrêts intermédiaires différents |
| `DDD 228` | `CONFIRMED` | itinéraire publié (bloc privé de son préfixe « LIGNE 228 : » — défaut de publication) |
| `DDD 232` | `CONFLICTING` | liste d'arrêts strictement identique à celle de la ligne 233 |
| `DDD 233` | `CONFLICTING` | liste d'arrêts strictement identique à celle de la 232 (dernier arrêt « Terminus Aéroport LSS » ≠ en-tête « PALAIS 1 ») |
| `DDD 234` | `CONFIRMED` | identité concordante ; itinéraire arrêt par arrêt |
| `DDD 311` | `PARTIAL` | itinéraire arrêt par arrêt publié, identité absente de « info-voyageurs » (source unique) |
| `DDD 327` | `PARTIAL` | itinéraire propre publié (distinct de la 227), identité absente de « info-voyageurs » (source unique) |

### C.4 Répartition

| Statut | Identifiants | Nombre |
|---|---|---|
| `CONFIRMED` | `1`, `4`, `7`, `8`, `9`, `10`, `13`, `18`, `20`, `121`, `TAF TAF`, `2`, `5`, `11`, `12`, `15`, `16A`, `16B`, `213`, `219`, `220`, `221`, `227`, `228`, `234` | **25** |
| `PARTIAL` | `502A`, `502B`, `503A`, `503B`, `504A`, `504B`, `319`, `502`, `503`, `TO1`, `TAF`, `15A`, `15B`, `311`, `327` | **15** |
| `CONFLICTING` | `501`, `23`, `6`, `208`, `217`, `218`, `232`, `233` | **8** |
| **TOTAL** | — | **48** |

---

## D. Lignes résolues

Résolutions obtenues **sur preuve officielle** (aucune déduction, aucun arbitrage d'opinion).

| # | Objet | Question posée en Phase 2 | Résolution | Preuve |
|---|---|---|---|---|
| 1 | **AFTU 5 / AFTU 25** | doublon ? | **Deux lignes distinctes** — conservées toutes les deux | `S-A2` lignes 5 et 25 : corridors d'approche incompatibles (Niayes/Grand Yoff vs VDN/Cheikh Anta Diop), même segment terminal |
| 2 | **AFTU 84–89, 91** | itinéraires manquants à trouver ? | **Aucun itinéraire publié** : `ROUTE_NOT_FOUND` est un fait | `S-A1` (liens renvoyant à elle-même) + `S-A3` (65 entrées) + sitemap des collections + recherche interne + API REST + 404 sur `/map/dakar-urbain-ligne-84/` |
| 3 | **AFTU 27, AFTU 36** | pages difficiles d'accès | **Pages valides** : les URL de prévisualisation redirigent vers `/map/dakar-urbain-ligne-27/` et `/map/dakar-urbain-ligne-36/` | `S-A1` (liens `preview=true`) + `S-A2` |
| 4 | **DDD 16A / 16B** | doublon (mêmes terminus MALIKA ↔ PALAIS 1) | **Deux services distincts** : 16A par Hamo/Guédiawaye/Icotaf/Colobane ; 16B par Keur Massar/Thiaroye/Yarakh/Bel Air | `S-D2` : listes d'arrêts officielles **différentes** |
| 5 | **DDD 10 / 13** | doublon (mêmes terminus LIBERTÉ 5 ↔ PALAIS 2) | **Deux services distincts** : 10 par Fann/Corniche/Rebeuss ; 13 par Castors/HLM/Ouagou Niayes/Petersen | `S-D2` : itinéraires officiels différents |
| 6 | **DDD 5 / 6 / 12** | doublon triple (GUÉDIAWAYE ↔ PALAIS 1) | **Trois services distincts** (5 : Patte d'Oie/Autoroute ; 6 : Camberène/Grand Médine/Liberté 5 ; 12 : Canada/Sandika/Bountou Pikine/Fann) | `S-D2` : trois itinéraires officiels différents |
| 7 | **DDD 18 / 20** | conflit de libellés entre les deux pages + doublon | **Deux boucles distinctes**, toutes deux **Dieuppeul → Centre-ville → Dieuppeul** : l'« aller simple » de `S-D2` est un **intitulé incomplet**, la boucle est confirmée par les arrêts. Conflit **levé par la preuve**, non par arbitrage | `S-D1` (boucle explicite) + `S-D2` (arrêts revenant au terminus de départ) |
| 8 | **DDD 227 / 327** | doublon (KEUR MASSAR ↔ TERMINUS PARCELLES) | **Deux services distincts** : 227 par Police Wakhinane/Hamo 6/Guédiawaye/Stade Amadou Barry/CES Canada ; 327 par Malibu | `S-D2` : arrêts intermédiaires différents |
| 9 | **DDD 502 / 503** | doublon (deux fois « GARE DE GARE ») | **Deux boucles distinctes** : 502 Gare Colobane → UCAD → Gare Colobane ; 503 Gare de Colobane → Mole 8 → Gare de Colobane. Libellé « GARE DE GARE » = **défaut de publication**, pas un doublon | `S-D2` : listes d'arrêts différentes |
| 10 | **DDD 502 ↔ 502A / 503 ↔ 503A** | correspondances à établir | **Observation de corridor** (non une identité) : la boucle 502 contient « UCAD » (corridor de 502A) ; la boucle 503 contient « Mole 8 » (corridor de 503A). **502B (Abass Ndao) et 503B (Hydrocarbure) ne sont couverts par aucun itinéraire publié** | `S-D2` (arrêts) + `S-D1` (titres) |
| 11 | **DDD 319, 311, 327** | identités à corroborer | **Itinéraires officiels publiés** (`STOP_SEQUENCE_CONFIRMED`) ; l'identité reste `PARTIAL` faute de seconde page | `S-D2` |
| 12 | **DDD 228** | bloc sans préfixe | **Identité confirmée** : le bloc « TERMINUS RUFISQUE ↔ YENNE » publié sans son préfixe « LIGNE 228 : » est bien la ligne 228 de `S-D1` (défaut de publication) | `S-D1` + `S-D2` |
| 13 | **Tata `tata_78`, `tata_219`** | correspondance AFTU possible ? | **`POSSIBLE_MATCH`** de corridor : `tata_78` ↔ AFTU 3/4 (Yoff – Petersen) ; `tata_219` ↔ AFTU 2/5/25 (Parcelles Assainies – Petersen). **Aucune fusion** (voir §B.4) | `S-A1` (libellés officiels) |
| 14 | **TAF TAF / TO1 / TAF** | une ou plusieurs lignes ? | **Un service, trois désignations publiées** : `TAF TAF` (`S-D1`, horaires + corridor), `TAF` (`S-D2`, arrêts Ouakam → AIBD), `TO1` (`S-D2`, arrêts Ouakam → Palais 2). La variante « Sphère Ministérielle » a des **horaires** mais **aucun arrêt publié** | `S-D1` + `S-D2` |

**14 résolutions**, dont **9 lèvent une suspicion de doublon** (items 1, 4, 5, 6, 7, 8, 9, 10, 13) — **toujours par conservation des deux entités**, jamais par suppression.

---

## E. Lignes conflictuelles

### E.1 Conflits officiels conservés (aucun arbitrage)

| Réseau | Ligne | Conflit | Statut |
|---|---|---|---|
| DDD | **6** | `S-D1` : CAMBÉRÈNE 2 ↔ PALAIS 2 — `S-D2` : GUÉDIAWAYE ↔ PALAIS 1 (itinéraire complet distinct) | `CONFLICTING` |
| DDD | **23** | en-tête « PARCELLES ASSAINIES ↔ PALAIS 1 » mais dernier arrêt publié « Terminus Palais 2 » | `CONFLICTING` |
| DDD | **208** | en-tête « BAYAKH ↔ RUFISQUE » mais aucun arrêt « Bayakh » (liste de Gorom 01 à Rufisque) | `CONFLICTING` |
| DDD | **217** | en-tête « THIAROYE ↔ OUAKAM » mais dernier arrêt publié « Terminus aéroport LSS » | `CONFLICTING` |
| DDD | **218** | liste d'arrêts **strictement identique** à celle de la 217 | `CONFLICTING` |
| DDD | **232** | liste d'arrêts **strictement identique** à celle de la 233 | `CONFLICTING` |
| DDD | **233** | liste identique à la 232 ; dernier arrêt « Terminus Aéroport LSS » ≠ en-tête « PALAIS 1 » | `CONFLICTING` |
| DDD | **501** | `S-D1` : GARE DE DAKAR ↔ PALAIS 2 — `S-D2` : PALAIS 2 ↔ LECLERCL | `CONFLICTING` |
| Tata | **les 5 identités** | numéro déjà publié par un exploitant pour un **autre** service : AFTU 50/64/78 ; DDD 218/219. *Erratum 1.1 : `new_commune_11` / `new_commune_12` sont des identifiants techniques sans numéro officiel — elles ne figurent plus ici.* | `CONFLICTING` |

**Total : 13 entités officielles en `CONFLICTING`** (8 DDD + 5 Tata) — *volume rectifié par l’erratum 1.1 (décision A4) : les deux identités Tata `new_commune_11` / `new_commune_12`, sans numéro officiel établi, n’entrent pas dans ce décompte.* Aucune entité n’est corrigée, fusionnée ou supprimée.

### E.2 Anomalies de publication (sans effet sur l'identité)

| Objet | Anomalie | Traitement |
|---|---|---|
| DDD 18 | bloc d'itinéraire **publié deux fois** dans `S-D2` | identité et itinéraire `CONFIRMED` ; doublon de **publication** signalé |
| DDD 228 | bloc publié **sans préfixe** « LIGNE 228 : » | identité `CONFIRMED` via `S-D1` |
| DDD 502, 503 | libellé « GARE DE GARE ↔ GARE DE GARE » | boucles réelles ; libellé de publication défaillant |
| DDD 501 | « LECLERCL » (faute de frappe) | conservée telle quelle dans la citation source |
| DDD `info-voyageurs` | page polluée par un spam SEO (liens casino injectés) | contenu métier intact ; source signalée comme bruitée |
| AFTU | sitemap : collection `lignne-28` (typo), `ligne-51-2` (doublon d'URL) | 65 pages valides confirmées |
| AFTU | page d'accueil : module de réservation de **démonstration** (villes européennes, horaires 05:00–19:00, tarifs fictifs) | **exclu** du référentiel (contredit la FAQ officielle « jusqu'à 21 H ») |
| DDD | pages `infos-trafic` et `faqs/service-urbain-dakar-et-peripherie` en « Erreur critique WordPress » | sources inaccessibles, aucune donnée extraite |

### E.3 Conflits internes au référentiel (hors périmètre de résolution Phase 3)

| Foyer | Volume | Nature | Traitement |
|---|---|---|---|
| AFTU internes | **54** routes | numéro officiel porté mais itinéraire interne **différent** de la publication | `CONTRADICTED_BY_OPERATOR` — **non résolu ici** (relève d'une phase de correction, §K) |
| AFTU internes | **26** routes | identifiants `aftu_*` **sans numéro publié** | `NUMBER_NOT_PUBLISHED_BY_OPERATOR` — non résolu ici |
| DDD candidates | **10** | numéro officiel attribué à une **autre** identité (`ddd_1 .. ddd_23`) | `CONFLICTING` conservé |
| DDD candidates | **5** | `ddd_3` (n° 3) et `ddd_14` (n° 14) : numéros **non publiés** par DDD ; `new_commune_01`, `new_commune_02`, `new_commune_13` : identifiants **techniques** — le suffixe `01` / `02` / `13` **n’est pas** un numéro officiel et ne crée aucune correspondance avec DDD 1, 2 ou 13 | `UNVERIFIED` conservé ; identifiant `MISSING` (erratum 1.1) |
| Tata | **7** | voir §B | `CONFLICTING` conservé |

> Ces conflits **internes** n'invalident pas le référentiel canonique officiel : ils caractérisent l'écart entre le jeu de données embarqué et la publication des exploitants. Ils sont délibérément **laissés en l'état** dans cette phase.

> **Règle appliquée (erratum 1.1)** : le suffixe d’un identifiant **technique** (`new_commune_01`, `new_commune_02`, `new_commune_13`, `new_commune_11`, `new_commune_12`) n’est **jamais** un numéro officiel. Aucun `official_line_number` n’est renseigné pour ces fiches et aucune correspondance avec DDD 1, 2, 11, 12 ou 13 n’est créée sans source officielle explicite.

---

## F. Doublons potentiels — verdicts

### F.1 Suspicions de la Phase 2 : verdict après lecture des itinéraires officiels

| Suspicion | Verdict Phase 3 | Preuve | Suite |
|---|---|---|---|
| AFTU **5 / 25** | **DOUBLON ÉCARTÉ** | `S-A2` : corridors incompatibles | aucune action |
| AFTU **57 / 77** | **DOUBLON ÉCARTÉ** (terminus différents : Liberté 6 ≠ Liberté 5) | `S-A1` | aucune action |
| DDD **10 / 13** | **DOUBLON ÉCARTÉ** | `S-D2` : itinéraires différents | aucune action |
| DDD **5 / 6 / 12** | **DOUBLON ÉCARTÉ** (3 services) | `S-D2` : 3 itinéraires différents | aucune action |
| DDD **18 / 20** | **DOUBLON ÉCARTÉ** (2 boucles distinctes) | `S-D2` : listes différentes | aucune action |
| DDD **16A / 16B** | **DOUBLON ÉCARTÉ** | `S-D2` : listes différentes | aucune action |
| DDD **227 / 327** | **DOUBLON ÉCARTÉ** | `S-D2` : arrêts intermédiaires différents | aucune action |
| DDD **502 / 503** | **DOUBLON ÉCARTÉ** (2 boucles distinctes) | `S-D2` : listes différentes | aucune action |
| DDD **15A / 15B** | **NON RÉSOLU** | aucune source ne publie d'itinéraire pour A ou B (intitulés identiques) | confirmation opérateur (§G) |
| DDD **502A / 502B** | **NON RÉSOLU** | titres seuls ; seul le corridor 502A (UCAD) est approché par la boucle 502 | confirmation opérateur (§G) |
| DDD **503A / 503B** | **NON RÉSOLU** | titres seuls ; seul le corridor 503A (Mole 8) est approché par la boucle 503 | confirmation opérateur (§G) |

### F.2 Collisions de numéros entre réseaux — jamais des doublons

| Numéro | AFTU (`S-A1`) | DDD (`S-D1`/`S-D2`) | Décision |
|---|---|---|---|
| 1 | LAT DIOR – HLM GRAND YOFF | PARCELLES ASSAINIES ↔ PLACE LECLERC | **deux lignes distinctes** (réseaux et exploitants différents) |
| 2 | ROUTE PRINCIPALE PARCELLES – PETERSEN | DAROUKHANE ↔ PLACE LECLERC | idem |
| 4 | YOFF VILLAGE – PETERSEN | LIBERTÉ 5 ↔ PLACE LECLERC | idem |
| 5 | PARCELLES ASSAINIES – PETERSEN | GUÉDIAWAYE ↔ PALAIS 1 | idem |

### F.3 Règle de dédoublonnage retenue (pour la Phase 4)

Aucune fusion ne peut être décidée sans **cinq** éléments : `network` + `operator` + numéro officiel + origine/destination **et** identité d'itinéraire. En Phase 3, **aucune fusion n'est prononcée** : 9 suspicions sont écartées (les entités restent distinctes), **3 restent non résolues** et aucune entité n'est supprimée.

---

## G. Lignes nécessitant encore une confirmation

| Réseau | Entités | Nombre | Question à poser à l'exploitant |
|---|---|---|---|
| AFTU | 84, 85, 86, 87, 88, 89, 91 | **7** | itinéraires officiels (aucune page publiée) |
| AFTU | (72 lignes) | *(global)* | horaires, fréquences, arrêts : aucune publication |
| Tata | `new_commune_11`, `new_commune_12`, `tata_218`, `tata_219`, `tata_50`, `tata_64`, `tata_78` | **7** | existence, exploitant, numéro officiel, correspondance AFTU éventuelle |
| DDD | 6, 23, 208, 217, 218, 232, 233, 501 | **8** | arbitrage des contradictions officielles (§E.1) |
| DDD | 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B | **8** | itinéraires et différenciation des variantes A/B |
| DDD | 311, 319, 327 | **3** | corroboration par une seconde source officielle (source unique actuellement) |
| DDD | (46 identifiants) | *(global)* | horaires et fréquences des lignes urbaines/banlieue hors ligne 1 |
| DDD / CETUD | — | *(global)* | existence d'un flux **temps réel** public après la mise en service du CCO |

**Total d'entités nominatives nécessitant une confirmation : 33** (7 AFTU + 7 Tata + 8 DDD conflictuelles + 8 DDD sans itinéraire + 3 DDD à corroborer).

---

## H. Horaires exploitables — inventaire

**Le moteur de départs n'est pas touché.** Aucune donnée ci-dessous n'est convertie en départ, en fréquence ou en grille horaire : c'est un **inventaire documentaire**.

### H.1 `SCHEDULE_CONFIRMED` — horaires officiels exploitables

| # | Service | Donnée officielle | Catégorie | Source | Usage autorisé en Phase 4 |
|---|---|---|---|---|---|
| 1 | **DDD ligne 1** | Centre social des Parcelles : 1er départ **05 h 30**, dernier **20 h 30** — Terminus Leclerc : 1er départ **06 h 30**, dernier **21 h 00** | **Ligne urbaine** | `S-D3` | `first_departure` / `last_departure` de la ligne 1 uniquement |
| 2 | **TAF TAF** Ouakam → AIBD | 06 h 00 → 21 h 00 | service TAF TAF (catégorie propre) | `S-D1` | 1er/dernier départ du **service TAF TAF**, jamais d'une ligne urbaine |
| 3 | **TAF TAF** Ouakam → Sphère Ministérielle | 05 h 45 → 21 h 00 | idem | `S-D1` | idem |
| 4 | **TAF TAF** AIBD → Ouakam | 06 h 00 → 21 h 00 | idem | `S-D1` | idem |
| 5 | **TAF TAF** Sphère Ministérielle → Ouakam | 06 h 00 → 20 h 30 | idem | `S-D1` | idem |
| 6 | **Express AIBD** | service **24 h/24 et 7 j/7** (sur réservation, 6 000 FCFA) | service **express** (hors lignes urbaines) | `S-D4` | amplitude de service express uniquement |

> **Cloisonnement exigé et respecté** : les horaires TAF TAF et Express AIBD appartiennent à **leur propre catégorie de service**. Ils **ne sont attribués à aucune ligne urbaine DDD** (ni à la 1, ni à la 23, ni à la 227, ni à la 234, qui desservent pourtant des corridors proches).

### H.2 `FREQUENCY_CONFIRMED` — fréquences officielles

**Aucune (0).** Ni AFTU, ni Tata, ni DDD (urbain, banlieue, dessertes gares) ne publient de fréquence. Le schéma `frequency_status = CONFIRMED` + `schedule_status = UNKNOWN` **ne s'applique à aucune entité de ce référentiel**.

### H.3 `NO_SCHEDULE` — entités sans horaire exploitable

| Réseau | Entités sans horaire | Nombre |
|---|---|---|
| AFTU | **les 72 lignes** | **72** |
| Tata | **les 7 identités** | **7** |
| DDD | **46 identifiants** (48 − ligne 1 − TAF TAF) | **46** |
| **TOTAL** | — | **125** |

Rappel AFTU : la FAQ officielle (« les bus circulent généralement tôt le matin jusqu'au soir à 21 H, horaires variables selon les lignes et les zones ») est une **information générale d'exploitation**, non un horaire : elle reste classée **hors horaire** et **ne produit aucune valeur** par ligne.

### H.4 `CONFLICTING_SCHEDULE` — contradictions d'horaires

**0 contradiction parmi les sources exploitables.** Une seule contradiction a été observée, sur une source **écartée** :

| Source | Contradiction | Décision |
|---|---|---|
| Module de réservation de la page d'accueil AFTU (démonstration : Prague, Vilnius, Lisbonne) — horaires 05:00 … 19:00 | incompatible avec la FAQ officielle AFTU (« jusqu'à 21 H ») | **source exclue du référentiel** : aucune valeur horaire n'en est retenue |

---

## I. Données sans horaire (détail par entité)

| Réseau | Entités | Horaire | Fréquence | Motif |
|---|---|---|---|---|
| AFTU | 1–5, 24–89, 91 (**72**) | `UNKNOWN` | `UNKNOWN` | aucune publication d'horaire ni de fréquence par ligne |
| Tata | 7 identités | `UNKNOWN` | `UNKNOWN` | aucune source officielle ; identités elles-mêmes `CONFLICTING` |
| DDD | 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 15A, 15B, 16A, 16B, 18, 20, 23, 121, 208, 213, 217, 218, 219, 220, 221, 227, 228, 232, 233, 234, 311, 319, 327, 501, 502, 503, 502A, 502B, 503A, 503B, 504A, 504B, TO1, TAF (**46**) | `UNKNOWN` | `UNKNOWN` | seuls la ligne 1 et le service TAF TAF publient des heures |

Ces `UNKNOWN` sont **conservés tels quels** : ils ne doivent être « remplis » par aucune estimation, aucune moyenne, aucun report depuis un autre réseau ou un autre service.

---

## J. Sources

### J.1 Sources officielles exploitantes (primaires)

| Code | URL | Réseau | Contenu exploité | Contenu absent |
|---|---|---|---|---|
| `S-A1` | `https://aftu-senegal.org/infos-pratiques/` | AFTU | **72** lignes : numéro, libellé, lien d'itinéraire | arrêts, horaires, fréquences |
| `S-A2` | `https://aftu-senegal.org/map/dakar-urbain-ligne-{N}/` (**65 pages**) | AFTU | `ROUTE_DOCUMENTED` (rues / points de repère), dates 2026-05 → 2026-07 | arrêts séquentiels, horaires |
| `S-A3` | `https://aftu-senegal.org/waymark_map-sitemap.xml` | AFTU | preuve des **65** pages ; absence des 84–91 | — |
| `S-A4` | `https://aftu-senegal.org/waymark_collection-sitemap.xml` | AFTU | absence de collection pour 84–91 ; anomalies de publication | — |
| `S-A5` | `https://aftu-senegal.org/faq/` | AFTU | amplitude générale (« tôt le matin … 21 H ») | tout horaire par ligne |
| `S-D1` | `https://demdikk.sn/info-voyageurs/` | DDD | **40 entrées** (dessertes TER, urbaines, banlieue, TAF TAF) + horaires TAF TAF | itinéraires pour 15A/B, 502A/B, 503A/B, 504A/B |
| `S-D2` | `https://demdikk.sn/reseau-urbain-dakar/` | DDD | **40 blocs** d'arrêts ordonnés (39 identifiants, ligne 18 dupliquée) | 504A/504B ; horaires |
| `S-D3` | `https://demdikk.sn/` (alerte info) | DDD | horaires 1er/dernier départ **ligne 1** | — |
| `S-D4` | `https://demdikk.sn/offres-de-transport/` | DDD | Express AIBD 24 h/24 7 j/7 ; Dakar–Banjul 07 h 00 / 07 h 30 | horaires urbains |
| `S-D5` | `https://demdikk.sn/dakar-dem-dikk-inaugure-son-centre-de-controle-operationnel/` | DDD | CCO temps réel **interne** | **aucun flux public** |

### J.2 Sources de contexte (non décisionnelles)

| Code | Source | Apport |
|---|---|---|
| `S-I1` | ITF/ILO, *Dakar BRT — Labour Impact Assessment* (2020) | « AFTU … (**Tata minibus operator**) » ; 505 Tata ; « **still known locally as Tatas** » → Tata = marque/catégorie, pas réseau |
| `S-I2` | Presse sénégalaise (2013) | remises de minibus Tata aux membres AFTU (contexte) |
| `S-I3` | Guide tiers `cyriljarnias.com` | DDD « ~45 lignes », tarifs 150–275 FCFA, AFTU surnommé « Tata » — **non officiel**, corroboration seulement |

### J.3 Sources écartées ou inaccessibles

| Source | Statut |
|---|---|
| Page d'accueil AFTU — module de réservation | **démonstration** (villes européennes, horaires 05:00–19:00, tarifs fictifs) → exclue |
| `https://demdikk.sn/infos-trafic/` | « Erreur critique WordPress » |
| `https://demdikk.sn/faqs/service-urbain-dakar-et-peripherie/` | « Erreur critique WordPress » |
| `https://aftu-senegal.org/map/dakar-urbain-ligne-84/` (et 85–89, 91) | **404** / lien renvoyant vers `S-A1` |
| `https://aftu-senegal.org/collection/ligne-N/` | archives sans arrêts supplémentaires (ne pas parcourir) |
| `data/gtfs/stop_times.txt` (dépôt) | **dormant et non sourcé** → jamais utilisé comme source officielle |
| Pages de démonstration WordPress de `demdikk.sn` | hors sujet, écartées |

### J.4 Vérifications d'absence (traçabilité)

| Vérification | Résultat |
|---|---|
| `S-A3` (sitemap des cartes) | 65 entrées, n° 1–5 et 24–83 |
| `S-A4` (sitemap des collections) | 1–5, 24–83 + collection globale |
| Recherche interne `?s=ligne+84` | aucun résultat hors `S-A1` |
| API REST `wp-json/wp/v2/search?search=JAXAAY` | aucun résultat hors `S-A1` |
| API REST `wp-json/wp/v2/waymark_map` | type non exposé (`rest_no_route`) |
| `/map/dakar-urbain-ligne-84/` | 404 |

---

## K. Recommandations d'intégration (Phase 4 — après validation)

### K.1 Ce qui peut être intégré, dans cet ordre

| Ordre | Donnée | Provenance | Condition |
|---|---|---|---|
| 1 | **Nomenclature officielle AFTU** : 72 numéros + origine/destination | `S-A1` | remplacer/compléter les libellés non sourcés ; ne résout **pas** les 54 contradictions internes (§E.3) sans décision explicite |
| 2 | **`ROUTE_DOCUMENTED` AFTU** (65 descriptions de rues) | `S-A2` | stockage en **description**, jamais en `stop_sequence` |
| 3 | **Identités DDD officielles (48)** avec statut canonique (§C.2) | `S-D1` + `S-D2` | les 8 `CONFLICTING` sont intégrables **en tant que tels** (statut explicite), jamais « corrigés » |
| 4 | **Listes d'arrêts DDD (39)** | `S-D2` | **extraction outillée obligatoire** avec conservation de la page source et horodatage ; pas de recopie manuelle |
| 5 | **Horaires ligne DDD 1** (`first/last_departure`) | `S-D3` | uniquement après décision d'activer ou non la ligne 1 dans l'UI |
| 6 | **Horaires TAF TAF** | `S-D1` | dans la **catégorie de service TAF TAF**, jamais reportés sur une ligne urbaine |
| 7 | **Express AIBD 24/7** | `S-D4` | catégorie express, séparée |
| 8 | **Modélisation Tata** : `network = AFTU`, `service_category = TATA`, entités conservées `CONFLICTING` | `S-I1` + §B | **aucun** second réseau, **aucun** remappage |

### K.2 Ce qui doit rester `UNKNOWN` (interdiction d'intégration)

- horaires et fréquences de **toutes** les lignes AFTU (**72**) ;
- horaires et fréquences de **46** identifiants DDD ;
- **arrêts AFTU** : aucune source n'en publie ;
- itinéraires **15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B** ;
- arrêts du TAF TAF variante « Sphère Ministérielle » ;
- **temps réel** : aucune API publique (`S-D5`) → `realtime_status = UNKNOWN` pour tout le référentiel ;
- identités Tata : aucune résolution de numéro ;
- doublons non résolus : **15A/15B, 502A/502B, 503A/503B**.

### K.3 Interdits de méthode à reconduire en Phase 4

1. Ne pas transformer une `ROUTE_DOCUMENTED` AFTU en arrêts (règle 2 de la Phase 2).
2. Ne pas convertir une fréquence en horaire, ni une amplitude en grille.
3. Ne pas réutiliser `data/gtfs/stop_times.txt` (dormant, non sourcé).
4. Ne pas fusionner sur simple identité de terminus (§F.3).
5. Ne pas reporter un horaire TAF TAF ou Express sur une ligne urbaine.
6. Ne pas créer de réseau TATA (§B.4).
7. Ne pas supprimer les 7 entités Tata, ni les 15 candidats DDD, ni les 8 lignes AFTU sans itinéraire.
8. **Ne pas toucher** : TER, BRT, `DepartureEngineService`, `data/transit/departure-frequencies.json` + miroir Dart, `main.dart` (GPS, RoutePlanner, Assistant), `index.html`, UI publiable.

### K.4 Points de vigilance remontés à l'exploitant

Les 33 entités listées au §G, et en particulier :

- **AFTU 84–89 / 91** : itinéraires à publier (aucune page d'itinéraire — fait vérifié par 4 voies) ;
- **DDD 502B (Abass Ndao)** et **503B (Hydrocarbure)** : corridors **non couverts** par les boucles 502/503 publiées ;
- **DDD 218 / 232 / 233 / 217** : listes d'arrêts dupliquées côté publication (probable copier-coller) ;
- **DDD 6 / 501** : identités incompatibles entre les deux pages officielles ;
- **DDD 23 / 208** : en-tête et liste d'arrêts divergents ;
- **Tata** : **5** identités (`tata_50`, `tata_64`, `tata_78`, `tata_218`, `tata_219`) portent des numéros déjà attribués à d’autres services — la question « quelle ligne officielle ces services desservent-ils réellement ? » reste ouverte. Les 2 autres (`new_commune_11`, `new_commune_12`) n’ont **aucun numéro officiel établi** (erratum 1.1) : leur existence et leur exploitant restent à confirmer.

---

## L. Tableau final du référentiel canonique

Légende : `Itinéraire` = **nature de la publication** ; `Arrêts` = arrêts **nommés** publiés (premier → dernier arrêt lorsque la liste est ordonnée) ; `Statut` = statut canonique du §0.3. Aucune cellule `UNKNOWN`/`non publié` n'est un oubli : c'est un **constat de non-publication**.

| Réseau | Ligne | Origine | Destination | Itinéraire | Arrêts | Horaire | Fréquence | Statut | Source |
|---|---|---|---|---|---|---|---|---|---|
| AFTU | **1** | LAT DIOR | HLM GRAND YOFF | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **2** | ROUTE PRINCIPALE PARCELLES | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **3** | YOFF | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **4** | YOFF VILLAGE | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **5** | PARCELLES ASSAINIES | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **24** | UCAD | NOTAIRE GUEDIAWAYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **25** | PARCELLES ASSAINIES | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **26** | PARCELLES ASSAINIES | POST THIAROYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **27** | MARCHE BOUBESS | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **28** | HAMO V/VI | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **29** | CITE NATION UNIES (CAMBERENE) | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **30** | GADAYE (GUEDIEWAYE) | GARE DE COLOBANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **31** | TALLY ICOTAF X ROUTE DES NIAYES | HOPITAL ABASS NDAO | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **32** | SAHM | SERIGNE ASSANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **33** | COLOBANE | SERIGNE ASSANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **34** | NORD FOIRE | LAT DIOR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **35** | NGOR | PIKINE TEXACO | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **36** | MARCHE NDIAREME | NGOR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **37** | CITÉ APIX | UCAD (CLAUDEL) | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **38** | CITE DES ENSEIGNANTS | SHAM | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **39** | LAT-DIOR | DIAMALAYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **40** | GRAND MBAO | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **41** | PETERSEN | ETAGE MADIALE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **42** | GADAYE (GUEDIEWAYE) | OUAKAM BAYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **43** | OUAKAM | THIERNO NDIAYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **44** | GRAND MBAO | OUAKAM | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **45** | KOUNOUNE NGALAM | PARCELLES EGLISE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **46** | SDE SERIGNE ASSANE | LAT DIOR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **47** | LAT DIOR | ALMADIES | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **48** | CITE SERIGNE MANSOUR | LAT DIOR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **49** | GADAYE | NGOR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **50** | PETERSEN | MALIKA CIMETIERE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **51** | JAXAAY | GARE DES BAUX MARAICHERS | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **52** | BOUNTOU PIKINE | KEUR MASSAR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **53** | KEUR MASSAR | SEBIKOTANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **54** | TERMINUS KEUR MASSAR (CITE MTOA) | UCAD | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **55** | TERMINUS RUFISQUE SONADIS | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **56** | JAXAAY 2 | PETERSEN | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **57** | LIBERTE 6 | RUFISQUE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **58** | SAHM | COMICO | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **59** | DIAMALAYE | CITÉ GENDARMERIE (Jaxaay) | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **60** | COLOBANE | BARGNY | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **61** | ALMADIES | KEUR MASSAR | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **62** | ARRET CHERIF (RUFISQUE) | PENC MI (GUEULE TAPEE) | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **63** | TERMINUS CAMP MARCHAND RUFISQUE | STADE LSS | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **64** | GUEDIAWAYE | RUFISQUE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **65** | COLOBANE | JAXAAY | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **66** | YOFF | GOROM 1 | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **67** | OUAKAM | THIAWLENE RUFISQUE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **68** | YEUMBEUL | SEBIKOTANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **69** | DIAMALAYE | TERMINUS TIVAOUANE PEUL | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **70** | DAROUKHANE | JAXXAY 2 | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **71** | KEUR MASSAR | CLAUDEL | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **72** | GUEDIAWAYE | KOUNOUNE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **73** | LAC ROSE | POSTE THIAROYE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **74** | TERMINUS BARGNY (GARE FERROVIAIRE) | TIVAOUNE PEUL | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **75** | TERMINUS MALIKA (CITE SONATEL) | TERMINUS GARE ROUTIERE COLOBANE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **76** | SIPRES | CITE ASSURANCE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **77** | RUFISQUE | LIBERTE 5 | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **78** | DIAMAGUENE | LIBERTE 5 | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **79** | SANGALKAM | CAMBERENE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **80** | DIAMALAYE | DAROU THIOUB | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **81** | BEAUX MARRAICHERS | TIVAOUNE PEUL | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **82** | LAT DIOR | COMICO YEUMBEUL | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **83** | RUFISQUE ARAFAT | ZONE DE CAPTAGE | `ROUTE_DOCUMENTED` (rues) | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-A1`+`S-A2` |
| AFTU | **84** | UCAD | JAXAAY | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **85** | BANOBA | LIBERTE 5 | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **86** | TOURNALOU BOUNE | TOUBAB DIALAW | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **87** | BAMBILOR | MOSQUEE MASSALIKOU DJINANE | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **88** | MTOA | LIBERTE 5 | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **89** | BARGNY | CROISEMENT NIAGUE (CITE SICAP) | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| AFTU | **91** | APIX | DOUGAR | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` | `S-A1` |
| Tata (catégorie AFTU) | `new_commune_11` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` (identifiant technique : aucun numéro officiel établi — erratum 1.1 ; ⚠️ ne pas confondre avec DDD 11) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `new_commune_12` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `UNVERIFIED` (identifiant technique : aucun numéro officiel établi — erratum 1.1 ; ⚠️ ne pas confondre avec DDD 12) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `tata_218` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` (numéro déjà pris : DDD 218) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `tata_219` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` (numéro déjà pris : DDD 219) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `tata_50` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` (numéro déjà pris : AFTU 50) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `tata_64` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` (numéro déjà pris : AFTU 64) | `S-A1` (absence) + `S-I1` |
| Tata (catégorie AFTU) | `tata_78` | non publiée par une source officielle | non publiée par une source officielle | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` (numéro déjà pris : AFTU 78) | `S-A1` (absence) + `S-I1` |
| DDD | **501** | GARE DE DAKAR | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Palais 2 → Terminus Leclerc | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **502A** | COLOBANE | UCAD | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **502B** | COLOBANE | ABASS NDAO | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **503A** | COLOBANE | MOLE 8 | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **503B** | COLOBANE | HYDROCARBURE | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **504A** | GARE DIAMNIADIO | SPHERE MINISTERIEL | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **504B** | SEBIKOTANE | GARE DIAMNIADIO | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **1** | PARCELLES ASSAINIES | PLACE LECLERC | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Parcelles Assainies → Terminus Leclerc | `SCHEDULE_CONFIRMED` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2`+`S-D3` |
| DDD | **4** | LIBERTÉ 5 | PLACE LECLERC | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Liberté 5 (Dieuppeul) → Terminus Leclerc | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **7** | OUAKAM | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Ouakam → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **8** | AÉROPORT LSS | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Aéroport LSS → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **9** | LIBERTÉ 6 | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Liberté 6 → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **10** | LIBERTÉ 5 | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus liberté 5 (Dieuppeul) → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **13** | LIBERTÉ 5 | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus liberté 5 (Dieuppeul) → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **18** | DIEUPPEUL | DIEUPPEUL | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Liberté 5 (Dieuppeul) → Terminus Liberté 5 (Dieuppeul) | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **20** | DIEUPPEUL | DIEUPPEUL | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Dieuppeul → Terminus Dieuppeul | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **23** | PARCELLES ASSAINIES | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus des Parcelles → Terminus Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **121** | SCAT URBAM | LECLERC | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Scat Urban → Terminus Leclerc | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **319** | LIBERTÉ 6 | OUAKAM | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus liberté 6 → Terminus Ouakam | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **502** | GARE DE GARE | GARE DE GARE | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Gare colobane → Gare Colobane | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **503** | GARE DE GARE | GARE DE GARE | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Gare de Colobane → Gare de Colobane | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **TO1** | TAF TAF OUAKAM (TO1) : OUAKAM | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Ouakam → Palais 2 | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **TAF** | TAF TAF : OUAKAM | AIBD | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Ouakam → AIBD | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **TAF TAF** | OUAKAM | AIBD / SPHÈRE MINISTÉRIELLE (Diamniadio) | non publié | non publiés | `SCHEDULE_CONFIRMED` | `UNKNOWN` | `CONFIRMED` | `S-D1` |
| DDD | **2** | DAROUKHANE | PLACE LECLERC | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Daroukhane → Terminus Leclerc | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **5** | GUÉDIAWAYE | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Guédiawaye → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **6** | CAMBÉRÈNE 2 | PALAIS 2 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Guédiawaye → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **11** | KEUR MASSAR | LAT DIOR | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Keur Massar → Terminus Lat Dior | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **12** | GUÉDIAWAYE | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Guédiawaye → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **15** | RUFISQUE | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Rufisque → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D2` |
| DDD | **15A** | RUFISQUE | PALAIS 1 | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **15B** | RUFISQUE | PALAIS 1 | non publié | non publiés | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D1` |
| DDD | **16A** | MALIKA | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Malika → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **16B** | MALIKA | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Malika → Palais 1 | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **208** | BAYAKH | RUFISQUE | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Gorom 01 → Rufisque | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **213** | RUFISQUE | DIEUPPEUL | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Gare de Rufisque → Terminus Dieuppeul | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **217** | THIAROYE | OUAKAM | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Dépôt Thiaroye → Terminus aéroport LSS | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **218** | THIAROYE | AÉROPORT LSS | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Dépôt Thiaroye → Terminus aéroport LSS | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **219** | DAROUKHANE | OUAKAM | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Daroukhane → Terminus Ouakam | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **220** | RUFISQUE | GUÉDIAWAYE | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Rufisque → Terminus Guediawaye | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **221** | GADAYE | ALMADIES | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Gadaye (Filaos) → Terminus Almadies | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **227** | TERMINUS KEUR MASSAR | TERMINUS PARCELLES | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Keur Massar → Terminus Parcelles | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **228** | TERMINUS RUFISQUE | YENNE | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Rufisque → Diamniadio Yenne | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **232** | BAUX MARAICHERS | AÉROPORT LSS | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Baux Maraichers → Terminus Aéroport LSS | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **233** | BAUX MARAICHERS | PALAIS 1 | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Baux Maraichers → Terminus Aéroport LSS | `NO_SCHEDULE` | `UNKNOWN` | `CONFLICTING` | `S-D1`+`S-D2` |
| DDD | **234** | JAXAAY | LECLERC | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | TERMINUS JAXAAY (Mosquée Niakoul Rab) → Leclerc | `NO_SCHEDULE` | `UNKNOWN` | `CONFIRMED` | `S-D1`+`S-D2` |
| DDD | **311** | LAC ROSE | CROISSEMENT KEUR MASSAR | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Lac rose croissement Niague → Retour vers Lac Rose | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |
| DDD | **327** | KEUR MASSAR | TERMINUS PARCELLES | arrêts ordonnés (`STOP_SEQUENCE_CONFIRMED`) | Terminus Keur Massar → Terminus Parcelles | `NO_SCHEDULE` | `UNKNOWN` | `PARTIAL` | `S-D2` |

### L.1 Volumétrie du référentiel

| Réseau | Entités canoniques | Avec itinéraire publié | Sans itinéraire | Statuts |
|---|---|---|---|---|
| AFTU | **72** | 65 (`ROUTE_DOCUMENTED`, rues) | 7 (84–89, 91) | 65 `PARTIAL` · 7 `UNVERIFIED` |
| Tata (7 identités du référentiel, catégorie AFTU) | **7** | 0 | 7 | 7 `CONFLICTING` (dont 2 `POSSIBLE_MATCH` de corridor) |
| DDD | **48** | 39 (`STOP_SEQUENCE_CONFIRMED`) | 9 (15A/B, 502A/B, 503A/B, 504A/B, TAF TAF) | 25 `CONFIRMED` · 15 `PARTIAL` · 8 `CONFLICTING` |
| **TOTAL** | **127** | **104** | **23** | — |

---

## M. Contrôle final

**Commandes exécutées (lecture seule) :**

```
$ git status --porcelain
?? docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md
?? docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md
$ git rev-parse HEAD
09767c2b1633dead91b35821c74f74d4a5d97395
```

Les **deux** entrées `??` sont des fichiers **non suivis** : le rapport d'audit de la Phase 2 (déjà non suivi à l'ouverture de cette phase — contrôle `hash-object` effectué **avant** toute opération) et le présent référentiel canonique. **Aucune entrée `M`** : aucun fichier suivi n'est modifié.

**Confirmations exigées :**

| Exigence | État |
|---|---|
| HEAD toujours `09767c2` | **CONFIRMÉ** |
| Aucun fichier existant modifié | **CONFIRMÉ** (aucune entrée `M` dans `git status`) |
| Aucun moteur modifié | **CONFIRMÉ** (`engine/`, `departure-frequencies.json`, miroir Dart intacts) |
| Aucun horaire ajouté | **CONFIRMÉ** (inventaire documentaire seulement, §H) |
| Aucun arrêt ajouté | **CONFIRMÉ** (aucun arrêt créé, aucune `stop_sequence` produite) |
| Aucun doublon supprimé | **CONFIRMÉ** (9 suspicions écartées **par conservation**, 3 non résolues, 0 suppression) |
| Seule modification autorisée | **le présent référentiel** — nouveau fichier documentaire, non suivi ; aucun autre fichier créé ni modifié |

**Les 7 chiffres demandés :**

| # | Demande | Résultat |
|---|---|---|
| 1 | Nombre de lignes AFTU résolues | **72 / 72** résolues au niveau identité (numéro + origine + destination). Itinéraire documenté : **65** ; `ROUTE_NOT_FOUND` : **7** (84–89, 91). Arrêts : 0. Horaires : 0. |
| 2 | Nombre de lignes DDD résolues | **48 / 48** identifiants documentés et classés ; **25 `CONFIRMED`**, **39** avec itinéraire arrêt par arrêt, dont **9 doublons potentiels écartés** par preuve (§F.1). |
| 3 | Nombre de lignes conflictuelles | **13 officielles** : **8 DDD** (6, 23, 208, 217, 218, 232, 233, 501) + **5 Tata** (numéro déjà attribué : 50, 64, 78, 218, 219). *Volume rectifié par l’erratum 1.1 : `new_commune_11` / `new_commune_12` sont des identifiants techniques sans numéro officiel (auparavant comptées à tort comme conflictuelles).* *Hors périmètre : **54 + 26** routes AFTU internes et **10 + 5** candidats DDD internes (§E.3), non résolus dans cette phase.* |
| 4 | Nombre de lignes sans itinéraire | **23** dans le tableau final : **7 AFTU** + **7 Tata** + **9 DDD** (15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B, TAF TAF). *Dont 22 sans aucun itinéraire et 1 (TAF TAF) avec corridor documenté mais sans arrêt publié.* |
| 5 | Nombre de lignes avec horaires | **2** : **DDD ligne 1** (seule **ligne urbaine** avec horaires officiels) et **TAF TAF** (catégorie de service propre). *Hors lignes urbaines : **Express AIBD** (24 h/24, 7 j/7).* |
| 6 | Nombre de lignes avec fréquence | **0** (aucune fréquence publiée, tout réseau confondu). |
| 7 | Nombre de lignes nécessitant encore une confirmation | **33** : 7 AFTU (itinéraires) + 7 Tata (existence/numéro) + 8 DDD conflictuelles + 8 DDD sans itinéraire + 3 DDD à corroborer (§G). |

**Aucune intégration n'a été effectuée.** L'UI, le moteur de départs, les données embarquées, les tests et la navigation restent strictement identiques à `09767c2`.

**STOP — référentiel canonique soumis à validation avant toute Phase 4 (intégration).**
