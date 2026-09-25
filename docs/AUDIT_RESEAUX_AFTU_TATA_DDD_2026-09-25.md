# Audit documentaire — Réseaux AFTU / Tata / Dakar Dem Dikk (DDD)

**Date de vérification des sources : 2026-09-25** · **Périmètre : documentation uniquement** (aucun code, aucune donnée, aucun fichier du dépôt modifié)

**HEAD de référence : `09767c2b1633dead91b35821c74f74d4a5d97395`**

**Sources officielles exploitées :** `https://aftu-senegal.org/` (AFTU) · `https://demdikk.sn/` (DDD) · sources institutionnelles externes pour le contexte « Tata » (ITF/ILO).

---

## 0. Méthode, périmètre et limites

### 0.1 Objet

Constituer un inventaire documentaire **vérifiable** des lignes AFTU, Tata et DDD (numéro, origine, destination, itinéraire, arrêts, horaires, fréquence, source) **avant toute intégration dans le code**. Ce rapport ne propose aucune donnée nouvelle : il ne fait que **constater** ce que les sources officielles publient, et **signaler ce qui manque**.

### 0.2 Règles appliquées (auto-contraintes d'audit)

1. **Aucune donnée inventée, aucune donnée interpolée.** Tout champ non publié par une source est écrit `UNKNOWN` ou `non publié`.
2. **Une description d'itinéraire n'est pas une liste d'arrêts.** Une succession de rues ou de lieux dans une phrase reste un `ROUTE_DESCRIPTION` ; elle n'est **jamais** convertie en `stop_sequence` GTFS ni en arrêts séquentiels.
3. **Aucune fréquence n'est convertie en horaire.** « toutes les 10 min » ne produit jamais 08:10 / 08:20 / 08:30.
4. **Aucune fusion, aucune suppression.** Les données existantes (`dakar_network.json`) sont laissées intactes ; les doublons sont *signalés*, jamais corrigés.
5. **Le référentiel interne est une liste CANDIDATE**, jamais supérieure au site officiel de l'opérateur. En cas d'écart, c'est l'écart qui est rapporté, sans arbitrage.
6. **Aucune donnée GTFS dormante n'est réutilisée** (`data/gtfs/stop_times.txt` non sourcé) ; chaque horaire cité possède une provenance URL vérifiable.
7. **Aucune modification du dépôt** pendant l'audit (lecture seule).

### 0.3 Vocabulaire de statut (utilisé dans tout le rapport)

| Statut | Signification exacte |
|---|---|
| `CONFIRMED` | Donnée publiée par une source **officielle** de l'exploitant, concordante avec la seconde source officielle quand elle existe. |
| `PARTIAL` | Donnée officielle publiée, mais incomplète ou non corroborée par la seconde source officielle. |
| `CONFLICTING` | Deux sources officielles (ou deux passages d'une même page officielle) donnent des informations **incompatibles**. Aucun arbitrage n'est fait ici. |
| `UNVERIFIED` | Présent dans le référentiel interne mais **absent des sources officielles consultées** : ni confirmé, ni contredit. |
| `UNKNOWN` | Champ pour lequel **aucune donnée officielle** n'a été trouvée. |

### 0.4 Limites assumées de cet audit

- **Connectivité du bac à sable** : l'accès HTTPS direct (`curl`, `urllib`) échoue (TLS interrompu). La consultation a été faite page par page ; aucune extraction automatisée en masse n'a pu être conservée hors de ce rapport.
- **Aucune liste d'arrêts n'a été recopiée à la main** dans ce rapport. Les 39 listes d'arrêts publiées par DDD sont **localisées et référencées** (§7) mais restent à extraire de façon outillée (avec provenance) lors d'une phase ultérieure **après validation** : recopier à la main une liste officielle créerait une source de vérité non vérifiable, contraire à la règle 2.
- **AFTU ne publie aucune liste d'arrêts ni aucun horaire par ligne** : la seule information horaire AFTU existante est une **généralité** (FAQ), classée en catégorie D (§9).
- **DDD** publie des arrêts (page « reseau-urbain-dakar ») mais **aucune fréquence** ; seules **deux lignes** (01 et TAF TAF) ont des horaires, et uniquement sous forme de **premier/dernier départ**.
- Les données du référentiel `flutter-src/assets/data/dakar_network.json` sont citées **comme liste candidate**, jamais comme preuve.
- Le module de réservation présent sur `aftu-senegal.org/` est une **démonstration** (villes européennes, tarifs fictifs) : exclu comme source.

---

## 1. Nombre de lignes AFTU actuelles

**72 lignes publiées** sur `https://aftu-senegal.org/infos-pratiques/` (source officielle AFTU).

| Élément constaté | Valeur |
|---|---|
| Numéros publiés | 1–5, 24–89, 91 |
| Trous de numérotation | 6–23 et 90 (non publiés) |
| Lignes avec page d'itinéraire `/map/dakar-urbain-ligne-N/` | **65** (n° 1–5 et 24–83) |
| Lignes sans page d'itinéraire | **7** (n° 84, 85, 86, 87, 88, 89, 91) — leur lien « Voir itinéraire » renvoie vers `/infos-pratiques/` |
| Lignes avec arrêts nommés séquentiels | **0** |
| Lignes avec horaire publié | **0** |
| Lignes avec fréquence publiée | **0** |

Contrôle de cohérence : le sitemap `waymark_map-sitemap.xml` (relevé 2026-07-14) contient **65 pages** `/map/dakar-urbain-ligne-N/` et `waymark_collection-sitemap.xml` **66 collections** — dont une faute de frappe (`lignne-28`) et une entrée dupliquée (`ligne-51-2`). Les deux comptages concordent avec les 65 pages d'itinéraire ci-dessus.

> Le nombre **72** est le seul nombre de lignes AFTU opposable : il provient de la liste publiée par l'exploitant. Toute autre valeur (ex. « environ 60 lignes » citée par des sources tierces) est une approximation à ne pas utiliser.

---

## 2. Nombre de lignes TATA

**0 ligne n'est publiée par un opérateur nommé « TATA ».** Aucune source officielle consultée (AFTU, DDD) ne publie de liste de lignes « Tata ».

Ce que les sources établissent :

| Constat | Source |
|---|---|
| « AFTU — Association de Financement des professionnels du Transport Urbain (Tata minibus operator) » | ITF/ILO, *Dakar Bus Rapid Transit — Labour Impact Assessment* (2020) |
| 505 minibus de marque Tata remis à l'AFTU (2005-2008), constructeur ensuite remplacé (King Long), véhicules « **still known locally as Tatas** » | même source + presse sénégalaise (2013) |

**Conclusion :** « Tata » désigne une **marque de véhicule / une catégorie de service** exploitée par les opérateurs AFTU, et **non un réseau distinct**. Il ne peut donc pas exister, en l'état des sources, une « ligne Tata N » parallèle à une « ligne AFTU N ».

### 2.1 Les 7 identités « Tata » présentes dans le référentiel interne (liste candidate)

| Identifiant interne | Libellé interne | Numéro implicite |
|---|---|---|
| `new_commune_11` | Tata Ouakam - Ngor Village - Yoff Tong | 11 |
| `new_commune_12` | Tata Jaxaay - Rufisque - Diamniadio 2 | 12 |
| `tata_218` | Mermoz ↔ Keur Massar (Tata 218) | 218 |
| `tata_219` | Parcelles Assainies ↔ Petersen (Tata 219) | 219 |
| `tata_50` | Guédiawaye ↔ Sandaga (Tata Ligne 50) | 50 |
| `tata_64` | Pikine ↔ Liberté 6 (Tata Ligne 64) | 64 |
| `tata_78` | Yoff ↔ Petersen via Cambérène (Tata 78) | 78 |

Ces 7 entrées ne correspondent à **aucune ligne publiée** par AFTU ni par DDD : voir §4 pour leur classification et §5 pour les collisions de numéros.

---

## 3. Nombre de lignes DDD actuelles

DDD publie ses lignes sur **deux pages officielles distinctes**, qui ne donnent pas le même périmètre :

| Page officielle | Entrées publiées | Contenu |
|---|---|---|
| `https://demdikk.sn/info-voyageurs/` | **40** | dessertes gares TER (7) + urbaines (11) + banlieue (21) + TAF TAF (1) — **titres uniquement** (origine ↔ destination), aucune liste d'arrêts |
| `https://demdikk.sn/reseau-urbain-dakar/` | **39** | 39 blocs d'itinéraire **arrêt par arrêt** (séparateur « – ») |
| **Union des identifiants publiés** | **48** | voir ci-dessous |

### 3.1 Les 48 identifiants publiés (union des deux pages)

```
1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 15A, 15B, 16A, 16B, 18, 20, 23, 121, 208, 213, 217, 218, 219, 220, 221, 227, 228, 232, 233, 234, 311, 319, 327, 501, 502, 502A, 502B, 503, 503A, 503B, 504A, 504B, TAF TAF (sans numéro), TAF, TO1
```

Un même service peut y apparaître sous plusieurs désignations : la desserte **TAF TAF** figure sous `TAF TAF` (info-voyageurs), `TAF` et `TO1` (reseau-urbain, la variante `TO1` ayant pour destination affirmée « PALAIS 2 ») ; les lignes **15**, **502** et **503** de la page « reseau-urbain » sont **scindées** en `15A/15B`, `502A/502B`, `503A/503B` sur « info-voyageurs ».

### 3.2 Répartition telle que publiée

| Catégorie | Identifiants |
|---|---|
| Dessertes gares du TER | 501, 502A, 502B, 503A, 503B, 504A, 504B |
| Urbaines (page reseau-urbain) | 1, 4, 7, 8, 9, 10, 13, 18, 20, 23, 121, 319 |
| Banlieue (page reseau-urbain) | 2, 5, 6, 11, 12, 15, 16A, 16B, 208, 213, 217, 218, 219, 220, 221, 227, 228, 232, 233, 234, 311, 327 |
| TAF TAF / TO1 | TAF TAF (info-voyageurs), TAF, TO1 (reseau-urbain) |
| Uniquement sur « reseau-urbain » | 15, 311, 319, 327, 502, 503, TAF, TO1 |
| Uniquement sur « info-voyageurs » | 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B |

> **`504A` et `504B` ne sont publiées que sur une seule page**, sans aucun itinéraire détaillé ; `319`, `311`, `327` n'apparaissent **que** sur la page « reseau-urbain ».

---

### 3.3 Comparaison de la liste CANDIDATE interne avec les listes officielles

Le référentiel interne contient **15 routes DDD**. Règle appliquée : la liste candidate **ne peut jamais prévaloir** sur le site officiel ; l'écart est constaté, jamais arbitré.

| Identifiant interne | Libellé interne (candidat) | N° | Identité officielle publiée | Présence officielle | Qualification |
|---|---|---|---|---|---|
| `ddd_1` | Colobane ↔ Yoff Pêcheurs (DDD Ligne 1) | 1 | PARCELLES ASSAINIES ↔ PLACE LECLERC | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_7` | HLM ↔ Yoff Almadies (DDD Ligne 7) | 7 | OUAKAM ↔ PALAIS 2 | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_8` | Aéroport Yoff ↔ Sandaga Centre (DDD Ligne 8) | 8 | AÉROPORT LSS ↔ PALAIS 2 | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_9` | Parcelles ↔ Almadies via Ngor (DDD Ligne 9) | 9 | LIBERTÉ 6 ↔ PALAIS 2 | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_10` | Liberté 6 ↔ Patte d'Oie ↔ Parcelles (DDD Ligne 10) | 10 | LIBERTÉ 5 ↔ PALAIS 2 | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_11` | UCAD ↔ Parcelles Assainies (DDD Ligne 11) | 11 | KEUR MASSAR ↔ LAT DIOR | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_12` | Guédiawaye ↔ Parcelles Express (DDD Ligne 12) | 12 | GUÉDIAWAYE ↔ PALAIS 1 | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_15` | Ouakam ↔ Colobane via Mermoz (DDD Ligne 15) | 15 | RUFISQUE ↔ PALAIS 1 | une seule page (reseau-urbain) | `CONFLICTING` — identité officielle différente |
| `ddd_20` | Petersen ↔ Rufisque (DDD Ligne 20 Interurbaine) | 20 | DIEUPPEUL ↔ CENTRE-VILLE | les deux pages | `CONFLICTING` — identité officielle différente |
| `ddd_23` | Sandaga ↔ Keur Massar (DDD Ligne 23) | 23 | PARCELLES ASSAINIES ↔ PALAIS 1 | les deux pages | `CONFLICTING` — identité officielle différente |
| `new_commune_01` | DDD Fass - SICAP - Grand Dakar | 01 | PARCELLES ASSAINIES ↔ PLACE LECLERC (= ligne 1) | les deux pages | `CONFLICTING` — collision avec la ligne officielle 1 |
| `new_commune_02` | DDD Plateau - Fann - Amitié | 02 | DAROUKHANE ↔ PLACE LECLERC (= ligne 2) | les deux pages | `CONFLICTING` — collision avec la ligne officielle 2 |
| `new_commune_13` | DDD Sébikotane - Bargny - Fass | 13 | LIBERTÉ 5 ↔ PALAIS 2 (= ligne 13) | les deux pages | `CONFLICTING` — collision avec la ligne officielle 13 (identité différente) |
| `ddd_3` | Sandaga ↔ Ouakam / Ngor (DDD Ligne 3) | 3 | **aucune ligne 3 publiée par DDD** | — | `UNVERIFIED` — numéro non publié par DDD |
| `ddd_14` | Gare Maritime ↔ UCAD (DDD Ligne 14 Plate) | 14 | **aucune ligne 14 publiée par DDD** | — | `UNVERIFIED` — numéro non publié par DDD |

**Résultat : 0 identité candidate sur 15 est confirmée par les sources officielles.** 13 sont en conflit (§12), 2 ne correspondent à aucune ligne publiée (`ddd_3`, `ddd_14`). Aucune donnée interne n'est supprimée : la correction éventuelle relève d'une phase ultérieure **après validation**.

---

## 4. Correspondances TATA ↔ AFTU

Méthode : pour chaque identité « Tata » du référentiel, recherche d'un numéro équivalent dans **les deux listes officielles** (AFTU 72 lignes ; DDD 48 identifiants), puis comparaison de l'identité de service (origine/destination). Aucune donnée n'est supprimée ni fusionnée.

| Identité Tata (interne) | Numéro | Correspondance AFTU | Correspondance DDD | Classification | Motif |
|---|---|---|---|---|---|
| `new_commune_11` (« Tata Ouakam - Ngor Village - Yoff Tong ») | 11 | — | DDD 11 = KEUR MASSAR ↔ LAT DIOR (2 pages) | **CONFLICTING** | le n° 11 est publié par DDD ; aucune identité Tata n'est établie pour ce numéro |
| `new_commune_12` (« Tata Jaxaay - Rufisque - Diamniadio 2 ») | 12 | — | DDD 12 = GUÉDIAWAYE ↔ PALAIS 1 (2 pages) | **CONFLICTING** | le n° 12 est publié par DDD ; aucune identité Tata n'est établie pour ce numéro |
| `tata_218` (« Mermoz ↔ Keur Massar (Tata 218) ») | 218 | — | DDD 218 = THIAROYE ↔ AÉROPORT LSS (2 pages) | **CONFLICTING** | le n° 218 est publié par DDD ; identité Tata non établie |
| `tata_219` (« Parcelles Assainies ↔ Petersen (Tata 219) ») | 219 | — | DDD 219 = DAROUKHANE ↔ OUAKAM (2 pages) | **CONFLICTING** | le n° 219 est publié par DDD ; identité Tata non établie |
| `tata_50` (« Guédiawaye ↔ Sandaga (Tata Ligne 50) ») | 50 | AFTU 50 = PETERSEN – MALIKA CIMETIERE | — | **CONFLICTING** | le n° 50 est attribué par AFTU à une liaison sans rapport avec « Guédiawaye ↔ Sandaga » |
| `tata_64` (« Pikine ↔ Liberté 6 (Tata Ligne 64) ») | 64 | AFTU 64 = GUEDIAWAYE – RUFISQUE | — | **CONFLICTING** | le n° 64 est attribué par AFTU à une liaison sans rapport avec « Pikine ↔ Liberté 6 » |
| `tata_78` (« Yoff ↔ Petersen via Cambérène (Tata 78) ») | 78 | AFTU 78 = DIAMAGUENE – LIBERTE 5 | — | **CONFLICTING** | le n° 78 est attribué par AFTU à une liaison sans rapport avec « Yoff ↔ Petersen via Cambérène » |

**Bilan TATA : CONFIRMED_MATCH = 0 · POSSIBLE_MATCH = 0 · CONFLICTING = 7 · NO_MATCH = 0 · UNKNOWN = 0.**

Interprétation prudente : les 7 entrées Tata du référentiel **ne peuvent pas être rattachées** à une ligne AFTU officielle telle que publiée. Trois hypothèses restent ouvertes, **aucune n'étant retenue ici** : (a) itinéraires réellement exploités mais non publiés par AFTU ; (b) numéros de travail internes aux GIE ; (c) doublons d'un même service désigné autrement. La seule façon de trancher est une **confirmation opérateur** (§16).

---

## 5. Doublons potentiels

Règle : **jamais de dédoublonnage sur le seul numéro**. La comparaison porte sur le réseau, l'exploitant, le numéro, l'origine, la destination et l'identité d'itinéraire. Aucune donnée n'est supprimée.

### 5.1 Collisions de numéros entre réseaux — **jamais des doublons**

| Numéro | AFTU (officiel) | DDD (officiel) | Décision |
|---|---|---|---|
| 1 | LAT DIOR – HLM GRAND YOFF | PARCELLES ASSAINIES ↔ PLACE LECLERC | **Deux lignes distinctes** (réseaux et exploitants différents) |
| 2 | ROUTE PRINCIPALE PARCELLES – PETERSEN | DAROUKHANE ↔ PLACE LECLERC | idem |
| 4 | YOFF VILLAGE – PETERSEN | LIBERTÉ 5 ↔ PLACE LECLERC | idem |
| 5 | PARCELLES ASSAINIES – PETERSEN | GUÉDIAWAYE ↔ PALAIS 1 | idem |

`AFTU 1 ≠ DDD 1` : la coïncidence de numéro **ne crée ni ne justifie aucune fusion**.

### 5.2 Doublons potentiels internes à l'AFTU

| Lignes | Constat | Qualification |
|---|---|---|
| **5 et 25** | Libellés strictement identiques : « PARCELLES ASSAINIES - PETERSEN » | `POSSIBLE_DUPLICATE` — à confirmer par l'opérateur (deux services peuvent coexister avec des tracés différents) |
| 57 et 77 | « LIBERTE 6 – RUFISQUE » / « RUFISQUE – LIBERTE 5 » | Similitude de mots seulement : **terminus différents** (Liberté 6 ≠ Liberté 5) → **non doublon** |

### 5.3 Doublons potentiels internes à DDD

| Lignes | Constat | Qualification |
|---|---|---|
| **10 et 13** | Libellés identiques sur les deux pages : « LIBERTÉ 5 ↔ PALAIS 2 » | `POSSIBLE_DUPLICATE` (2 numéros, une seule identité publiée) |
| **5, 12 et 6** | « GUÉDIAWAYE ↔ PALAIS 1 » publié pour 5 et 12 ; pour 6 sur la page « reseau-urbain » | `POSSIBLE_DUPLICATE` + conflit (§12) |
| **18 et 20** | Libellés identiques : « DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL » | `POSSIBLE_DUPLICATE` |
| **15A et 15B** | Libellés identiques (RUFISQUE ↔ PALAIS 1), variantes A/B non départagées | `POSSIBLE_DUPLICATE` (variantes à clarifier) |
| **16A et 16B** | Libellés identiques (MALIKA ↔ PALAIS 1), variantes A/B non départagées | `POSSIBLE_DUPLICATE` (variantes à clarifier) |
| **227 et 327** | Mêmes extrémités publiées : KEUR MASSAR ↔ TERMINUS PARCELLES (327 uniquement sur « reseau-urbain ») | `POSSIBLE_DUPLICATE` |
| **502 et 503** | Les deux publiées « GARE DE GARE ↔ GARE DE GARE » (libellé de boucle non renseigné) | `POSSIBLE_DUPLICATE` par défaut de libellé |

### 5.4 Doublons potentiels « AFTU ↔ Tata » (le seul cas théoriquement dédoublonnable)

Aucun **CONFIRMED_MATCH** n'existe (§4). Les seules collisions sont des conflits d'usage de numéro (`TATA 50/64/78` face à `AFTU 50/64/78`, identités incompatibles) → **aucun dédoublonnage justifié** ; les deux jeux doivent rester distincts et `CONFLICTING`.

---

## 6. Lignes AFTU avec itinéraire détaillé

**65 lignes sur 72** disposent d'une page d'itinéraire publiée : `https://aftu-senegal.org/map/dakar-urbain-ligne-N/` (n° 1–5, 24–83).

**Nature exacte de ce que ces pages contiennent** (vérifié par échantillonnage sur les lignes 1, 27 et 30) : un bloc « ITINÉRAIRE » qui est une **suite de rues, de carrefours et de points de repère**, du type :

> **Ligne 1** : « TERMINUS GARE LAT DIOR - RUE SANDINIERY - RUE DE LA SOMME … TERMINUS ESPACE HLM GD MEDINE (FACE AUTOROUTE) »
> **Ligne 30** : « … WAKHINANENIMZATT RUE 212, MARCHÉ NDIARÈME, STADE AMADOU BARRY, LYCÉE CANADA … TERMINUS GARE DE COLOBANE »
> **Ligne 27** : « MARCHE BOUBESS → GARE PETERSEN »

**Conséquence de méthode (règle 2) :** ces pages documentent un **`ROUTE_DESCRIPTION`**, pas une liste d'arrêts. Elles ne contiennent :

- **aucun arrêt nommé séquentiel** (aucune séquence d'arrêts avec ordre, ni identifiant d'arrêt) ;
- **aucun horaire** ;
- **aucune fréquence**.

Le lien « Voir itinéraire » des 7 lignes **84, 85, 86, 87, 88, 89, 91** renvoie d'ailleurs vers la page `/infos-pratiques/` elle-même (donc sans contenu d'itinéraire).

### 6.1 Les 65 lignes AFTU disposant d'une description d'itinéraire

```
  1, 2, 3, 4, 5, 24, 25, 26, 27, 28, 29, 30
  31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42
  43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54
  55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66
  67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78
  79, 80, 81, 82, 83
```

Pour chacune, le couple origine/destination publié figure dans le tableau final (§18) ; la description d'itinéraire reste **à extraire de la page `/map/dakar-urbain-ligne-N/` correspondante** lors d'une phase ultérieure (aucune recopie manuelle ici).

---

## 7. Lignes DDD avec itinéraire détaillé

**39 identifiants** disposent d'un itinéraire **arrêt par arrêt** : ce sont **les 39 blocs** de la page officielle `https://demdikk.sn/reseau-urbain-dakar/`, où les arrêts sont énumérés dans l'ordre et séparés par « – ». **C'est la seule source officielle, tous réseaux confondus, qui publie des arrêts explicites.**

Détail des 39 blocs (avec les réserves constatées) :

| Identifiant | Titre publié (en-tête) | Réserve constatée |
|---|---|---|
| `1` | PARCELLES ASSAINIES <--> PLACE LECLERC | — |
| `4` | LIBERTÉ 5 <--> PLACE LECLERC | — |
| `7` | OUAKAM <--> PALAIS 2 | — |
| `8` | AEROPORT LSS <--> PALAIS 2 | — |
| `9` | LIBERTÉ 6 <--> PALAIS 2 | — |
| `10` | LIBERTÉ 5 <--> PALAIS 2 | — |
| `13` | LIBERTÉ 5 <--> PALAIS 2 | — |
| `18` | DIEUPPEUL <--> CENTRE-VILLE | ⚠ **bloc publié deux fois** à l'identique dans la même page ; titres différents selon la page |
| `20` | DIEUPPEUL <--> CENTRE-VILLE | ⚠ **en-tête en conflit** avec la page info-voyageurs |
| `23` | PARCELLES ASSAINIES <--> PALAIS 1 | ⚠ en-tête « PALAIS 1 » mais la liste d'arrêts se termine « Terminus Palais 2 » |
| `121` | SCAT URBAM <--> LECLERC | — |
| `319` | LIBERTÉ 6 <--> OUAKAM | publiée **uniquement** par cette page (absente d'info-voyageurs) |
| `501` | PALAIS 2 <--> LECLERCL | ⚠ en-tête « PALAIS 2 ↔ LECLERCL » (faute de frappe) **incompatible** avec info-voyageurs (« GARE DE DAKAR ↔ PALAIS 2 ») |
| `502` | GARE DE GARE <--> GARE DE GARE | ⚠ en-tête « GARE DE GARE ↔ GARE DE GARE » : **boucle publiée sans terminus** |
| `503` | GARE DE GARE <--> GARE DE GARE | ⚠ en-tête « GARE DE GARE ↔ GARE DE GARE » : **boucle publiée sans terminus** |
| `TO1` | TAF TAF OUAKAM (TO1) : OUAKAM <--> PALAIS 2 | variante TAF TAF, mentionnée uniquement ici |
| `TAF` | TAF TAF : OUAKAM ↔ AIBD | desserte TAF TAF mentionnée uniquement ici |
| `2` | DAROUKHANE <--> PLACE LECLERC | — |
| `5` | GUÉDIAWAYE <--> PALAIS 1 | — |
| `6` | GUÉDIAWAYE <--> PALAIS 1 | ⚠ **en-tête en conflit** avec la page info-voyageurs (« CAMBÉRÈNE 2 ↔ PALAIS 2 ») |
| `11` | KEUR MASSAR <--> LAT DIOR | — |
| `12` | GUÉDIAWAYE <--> PALAIS 1 | — |
| `15` | RUFISQUE <--> PALAIS 1 | — |
| `16A` | MALIKA <--> PALAIS 1 | — |
| `16B` | MALIKA <--> PALAIS 1 | — |
| `208` | BAYAKH <--> RUFISQUE | ⚠ en-tête « BAYAKH » mais la liste commence à Gorom 01 / Bambilor (aucun arrêt « Bayakh ») |
| `213` | RUFISQUE <--> DIEUPPEUL | — |
| `217` | THIAROYE <--> OUAKAM | ⚠ en-tête « THIAROYE ↔ OUAKAM » mais la liste se termine « Terminus aéroport LSS » |
| `218` | THIAROYE <--> AÉROPORT LSS | ⚠ **liste d'arrêts identique à celle du 217** alors que les en-têtes diffèrent (copie probable) |
| `219` | DAROUKHANE <--> OUAKAM | — |
| `220` | RUFISQUE <--> GUÉDIAWAYE | — |
| `221` | GADAYE <--> ALMADIES | — |
| `227` | KEUR MASSAR <--> TERMINUS PARCELLES | — |
| `228` | TERMINUS RUFISQUE <--> YENNE | — |
| `232` | BAUX MARAICHERS <--> AEROPORT LSS | — |
| `233` | BAUX MARAICHERS <--> PALAIS 1 | ⚠ **liste d'arrêts identique à celle du 232** (« Terminus Aéroport LSS ») alors que l'en-tête annonce « PALAIS 1 » |
| `234` | JAXAAY <--> LECLERC | — |
| `311` | LAC ROSE <--> CROISSEMENT KEUR MASSAR | publiée **uniquement** par cette page (absente d'info-voyageurs) |
| `327` | KEUR MASSAR <--> TERMINUS PARCELLES | publiée **uniquement** par cette page ; mêmes extrémités que la 227 |

En complément, la page `info-voyageurs` publie pour **TAF TAF** un **corridor** (Ouakam – Mamelles – Almadies – Ngor – Yoff – Foire – VDN – JVC – Liberté 6 – Patte d'Oie – Autoroute – Diamniadio – AIBD) : c'est un **itinéraire documenté**, **pas** une liste d'arrêts.

---

## 8. Lignes sans itinéraire trouvé

| Réseau | Identifiants | Nombre | Motif |
|---|---|---|---|
| AFTU | 84, 85, 86, 87, 88, 89, 91 | 7 | aucune page d'itinéraire publiée (lien renvoyant à `/infos-pratiques/`) |
| DDD | 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B | 8 | publiées **seulement en tant que titres** par info-voyageurs ; aucune liste d'arrêts |
| DDD | TAF TAF / TO1 | (1 service) | corridor décrit, **aucun arrêt nommé** |
| Tata | les 7 identités du référentiel | 7 | aucune source officielle ne publie de lignes Tata |
| DDD (candidats non publiés) | `ddd_3` (n° 3), `ddd_14` (n° 14) | 2 | ces numéros **n'existent pas** dans les deux pages officielles DDD |

Total : **7 lignes AFTU + 8 identifiants DDD + 1 service TAF TAF + 7 entités Tata + 2 candidats** sans itinéraire officiel exploitable.

---

## 9. Lignes avec horaires officiels

Recherche menée séparément dans les cinq catégories exigées.

### A. Horaires précis (par ligne, avec heures) — **trouvés : 1**

| Réseau | Ligne | Horaire officiel publié | Source |
|---|---|---|---|
| DDD | **01** (Parcelles Assainies ↔ Leclerc) | *Centre social des Parcelles* : 1er départ **05 h 30**, dernier **20 h 30** · *Terminus Leclerc* : 1er départ **06 h 30**, dernier **21 h 00** | `https://demdikk.sn/` (alerte info officielle) |

### B. Premiers / derniers départs (sans grille horaire) — **trouvés : 1 service (4 paires)**

| Réseau | Service | Premier / dernier départ publiés | Source |
|---|---|---|---|
| DDD | **TAF TAF** Ouakam → AIBD | 06 h 00 → 21 h 00 | `https://demdikk.sn/info-voyageurs/` |
| DDD | TAF TAF Ouakam → Sphère Ministérielle | 05 h 45 → 21 h 00 | idem |
| DDD | TAF TAF AIBD → Ouakam | 06 h 00 → 21 h 00 | idem |
| DDD | TAF TAF Sphère Ministérielle → Ouakam | 06 h 00 → 20 h 30 | idem |

Hors périmètre « lignes urbaines » mais officiel : **Express AIBD** (DDD) = service **24 h/24 et 7 j/7**, forfait 6 000 FCFA, départ du terminus HLM Grand-Yoff 1 h avant la convocation et retour 1 h après l'atterrissage (`https://demdikk.sn/offres-de-transport/`). **Dakar–Banjul** : départs quotidiens 07 h 00 et 07 h 30 (ligne interurbaine).

### C. Fréquence documentée — **trouvée : 0**

Aucune fréquence chiffrée n'est publiée pour une ligne AFTU, Tata ou DDD (voir §10).

### D. Informations générales sans horaire — **1 (AFTU)**

> FAQ officielle AFTU : « Les bus circulent généralement tôt le matin jusqu'au soir à **21 H**, avec des horaires variables selon les lignes et les zones desservies ». C'est une **généralité d'exploitation**, non un horaire de ligne : elle ne produit **aucune** valeur horaire exploitable par ligne.

### E. Temps réel — **aucune donnée temps réel publique**

DDD a inauguré le 06 juillet 2026 un **Centre de contrôle opérationnel (CCO)** qui suit la position des bus et le trafic **en interne** (vidéosurveillance incluse). Aucune **API ni flux temps réel public** n'est annoncé. Il n'existe donc **aucune** source permettant d'affirmer `realtime_status = CONFIRMED` pour une quelconque ligne.

**Bilan §9 : 1 ligne avec horaire précis (DDD 01), 1 service avec premiers/derniers départs (DDD TAF TAF), 0 fréquence, 1 généralité AFTU, 0 temps réel.**

---

## 10. Lignes avec fréquence seulement

**Aucune.** Aucune page officielle AFTU ou DDD, pour aucune ligne AFTU, Tata ou DDD, ne publie de fréquence (intervalle, passages/heure, « toutes les N minutes »).

Conséquence directe : le modèle `frequency_status = CONFIRMED` + `schedule_status = UNKNOWN` **ne s'applique à aucune ligne AFTU/Tata/DDD** en l'état des sources.

> Pour mémoire, hors périmètre : les fréquences **TER** (10/20 min) et **BRT B1/B2** (6 min) déjà présentes dans `data/transit/departure-frequencies.json` restent **inchangées** et ne concernent pas cet audit.

---

## 11. Lignes sans horaire

| Réseau | Lignes sans aucun horaire publié | Nombre |
|---|---|---|
| AFTU | **toutes** (1–5, 24–89, 91) | **72 / 72** |
| DDD | **toutes sauf 01 et TAF TAF** | **46 / 48 identifiants** (39 d'entre elles ont pourtant un itinéraire détaillé → `schedule_status = UNKNOWN` malgré un itinéraire connu) |
| Tata | les 7 identités du référentiel | **7 / 7** |

**Total : 125 entités sans horaire exploitable** (72 AFTU + 46 DDD + 7 Tata). Aucun horaire ne peut en être déduit, estimé ou interpolé.

---

## 12. Contradictions officielles

Aucun arbitrage n'est effectué : toutes sont conservées telles quelles, avec `status = CONFLICTING`.

### 12.1 Entre les deux pages officielles DDD (identités incompatibles)

| Ligne | Page `info-voyageurs` | Page `reseau-urbain-dakar` |
|---|---|---|
| **6** | CAMBÉRÈNE 2 ↔ PALAIS 2 | GUÉDIAWAYE ↔ PALAIS 1 |
| **18** | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | DIEUPPEUL ↔ CENTRE-VILLE |
| **20** | DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL | DIEUPPEUL ↔ CENTRE-VILLE |
| **501** | GARE DE DAKAR ↔ PALAIS 2 | PALAIS 2 ↔ LECLERCL (faute de frappe incluse) |

### 12.2 Contradictions internes à la page « reseau-urbain-dakar »

| Ligne | Contradiction constatée |
|---|---|
| 18 | bloc **dupliqué à l'identique** dans la même page |
| 23 | en-tête « PARCELLES ASSAINIES ↔ PALAIS 1 » / liste d'arrêts se terminant « Terminus Palais 2 » |
| 217 | en-tête « THIAROYE ↔ OUAKAM » / liste se terminant « Terminus aéroport LSS » |
| 218 | liste d'arrêts **identique à celle du 217**, alors que les en-têtes diffèrent |
| 233 | liste d'arrêts **identique à celle du 232** alors que les en-têtes diffèrent |
| 208 | en-tête « BAYAKH ↔ RUFISQUE » / liste commençant à Gorom 01 – Bambilor |
| 502, 503 | en-tête « GARE DE GARE ↔ GARE DE GARE » (terminus non renseignés) |

### 12.3 Divergences de numérotation entre les deux pages DDD

| Base | Page « reseau-urbain » | Page « info-voyageurs » |
|---|---|---|
| 15 | publiée comme `15` (itinéraire arrêt par arrêt) | **scindée** en `15A` et `15B` (titres seuls) |
| 502 | publiée comme `502` (boucle) | **scindée** en `502A` et `502B` (dessertes gares : Colobane ↔ UCAD / Abass Ndao) |
| 503 | publiée comme `503` (boucle) | **scindée** en `503A` et `503B` (Colobane ↔ Mole 8 / Hydrocarbure) |
| 504 | **absente** de la page « reseau-urbain » | `504A` et `504B` publiées (dessertes gares Diamniadio / Sébikotane) |

**Aucune fusion 502 ↔ 502A/B ni 503 ↔ 503A/B n'est proposée** : les deux périmètres publiés sont conservés et signalés comme divergents.

### 12.4 Contradictions et anomalies AFTU / Tata

| Objet | Constat |
|---|---|
| Lignes **5** et **25** | libellés strictement identiques (« PARCELLES ASSAINIES - PETERSEN ») pour deux numéros distincts |
| Sitemap AFTU | 65 pages d'itinéraire / 66 collections ; faute de frappe `lignne-28` ; entrée dupliquée `ligne-51-2` |
| Lignes 84–89, 91 | « Voir itinéraire » renvoie vers `/infos-pratiques/` au lieu d'une page d'itinéraire |
| Page d'accueil AFTU | module de réservation de **démonstration** (villes européennes, tarifs fictifs, horaires 05:00–19:00) **incompatible** avec la FAQ officielle (« jusqu'à 21 H ») → **non exploitable**, à ignorer en tant que donnée |
| DDD | bandeau d'alerte de la page d'accueil nomme la ligne **« 01 »** là où `info-voyageurs` écrit **« 1 »** (même ligne ; simple divergence de forme) |
| DDD | pages `infos-trafic` et `faqs/service-urbain-dakar-et-peripherie` en **« Erreur critique WordPress »** (contenu inaccessible) |
| Pages DDD | balisage HTML pollué par un **spam SEO** (centaines de liens de casino injectés) : contenu métier intact, mais lecture partiellement bruitée |

---

## 13. Sources utilisées

### 13.1 Sources officielles exploitantes (primaires)

| URL | Réseau | Type de contenu | Exploité pour | Limites constatées |
|---|---|---|---|---|
| `https://aftu-senegal.org/infos-pratiques/` | AFTU | liste officielle des lignes | les **72 numéros** + origine/destination + liens d'itinéraire | ni arrêts, ni horaires, ni fréquences |
| `https://aftu-senegal.org/map/dakar-urbain-ligne-N/` (65 pages) | AFTU | fiche d'itinéraire | `ROUTE_DESCRIPTION` (rues / points de repère) | pas d'arrêts séquentiels, pas d'horaires |
| `https://aftu-senegal.org/waymark_map-sitemap.xml` | AFTU | sitemap | preuve des **65 pages** d'itinéraire (maj 2026-06/07) | 66 collections (typo `lignne-28`, doublon `ligne-51-2`) |
| `https://aftu-senegal.org/faq/` | AFTU | FAQ | fenêtre d'exploitation générale (« tôt le matin … 21 H ») | **aucun horaire par ligne** |
| `https://aftu-senegal.org/a-propos-de-nous/`, `/mot-du-president/` | AFTU | présentation | contexte institutionnel (2001, 14 GIE, 2 750 bus, projet « Yonu Jam ») | aucune donnée de ligne |
| `https://demdikk.sn/info-voyageurs/` | DDD | liste officielle des lignes | **40 entrées** (dessertes TER, urbaines, banlieue, TAF TAF) + premiers/derniers départs TAF TAF | titres seuls (pas d'arrêts) ; page polluée par du spam SEO |
| `https://demdikk.sn/reseau-urbain-dakar/` | DDD | itinéraires officiels | **39 blocs** d'itinéraires **arrêt par arrêt** | contradictions internes ; 502/503 en boucle ; 504A/B absentes |
| `https://demdikk.sn/` (bandeau d'alerte) | DDD | info trafic officielle | horaires **ligne 01** (05 h 30/20 h 30 – 06 h 30/21 h 00) | alerte ponctuelle, seul horaire urbain publié |
| `https://demdikk.sn/offres-de-transport/` | DDD | offres | Express AIBD **24 h/24 7 j/7** ; Dakar–Banjul 07 h 00 / 07 h 30 ; 80 lignes interurbaines | ne concerne pas les lignes urbaines |
| `https://demdikk.sn/dakar-dem-dikk-inaugure-son-centre-de-controle-operationnel/` | DDD | actualité (06/07/2026) | existence d'un CCO temps réel **interne** | **aucun flux/API public** → temps réel non exploitable |
| `https://demdikk.sn/page-sitemap.xml` | DDD | sitemap | inventaire des pages exploitables | la plupart des entrées sont des pages de démo de thème WordPress |

### 13.2 Sources de contexte (non décisionnelles)

| Source | Apport | Usage |
|---|---|---|
| ITF/ILO, *Dakar Bus Rapid Transit — Labour Impact Assessment* (2020) | « AFTU … (**Tata minibus operator**) » ; 505 Tata (2005-2008) ; « still known locally as Tatas » | établit que **Tata = marque de véhicule / catégorie de service**, pas un réseau |
| Presse sénégalaise (2013) | remises de 310 minibus Tata aux membres AFTU | corroboration historique |
| `cyriljarnias.com` (guide pratique) | DDD « environ 45 lignes », tarifs 150-275 FCFA, AFTU surnommé « Tata » | **non officiel** : corroboration uniquement |

### 13.3 Sources inaccessibles ou à exclure

| Source | Statut |
|---|---|
| `https://demdikk.sn/infos-trafic/` | **« Erreur critique WordPress »** — aucune donnée |
| `https://demdikk.sn/faqs/service-urbain-dakar-et-peripherie/` | **« Erreur critique WordPress »** — aucune donnée |
| `https://aftu-senegal.org/map/dakar-urbain-ligne-84/` | **404** (idem 85–89 et 91 : liens renvoyant à `/infos-pratiques/`) |
| `https://aftu-senegal.org/collection/ligne-N/` (66 collections) | archives sans arrêts supplémentaires → **ne pas parcourir** |
| Page d'accueil `aftu-senegal.org` (module de réservation) | **démonstration** (Prague/Vilnius/Lisbonne, tarifs fictifs) → **jamais** une source d'horaire |
| `data/gtfs/stop_times.txt` (dépôt) | **dormant, non sourcé** → jamais réutilisé comme horaire (§15) |

---

## 14. Données intégrables (après validation seulement)

Liste **strictement documentaire** : rien n'est intégré à ce stade. Chaque élément ci-dessous a une provenance URL vérifiable et un statut de données explicite.

| # | Donnée | Portée | Statut à retenir | Source |
|---|---|---|---|---|
| 1 | **Nomenclature officielle AFTU : 72 numéros + origine/destination** | identités de lignes AFTU (remplace/complète tout libellé non sourcé) | `CONFIRMED` (numéro + O/D publiés par l'exploitant) | aftu-senegal.org/infos-pratiques |
| 2 | **`ROUTE_DESCRIPTION` AFTU** pour 65 lignes | description textuelle (rues/repères) | `CONFIRMED` **comme description**, jamais comme arrêts | `/map/dakar-urbain-ligne-N/` |
| 3 | **Identifiants DDD officiels (48) + origine/destination** | identités de lignes DDD | `CONFIRMED` hors lignes listées au §12 (celles-ci : `CONFLICTING`) | info-voyageurs + reseau-urbain |
| 4 | **Listes d'arrêts DDD (39 blocs, arrêts explicites ordonnés)** | arrêts DDD nommés, avec provenance | `CONFIRMED` pour 15 lignes ; `PARTIAL`/`CONFLICTING` selon §12 — **extraction outillée à faire**, aucune recopie manuelle | reseau-urbain-dakar |
| 5 | **Horaires ligne DDD 01** (05 h 30/20 h 30 ; 06 h 30/21 h 00) | `first_departure` / `last_departure` uniquement | `CONFIRMED` (pas une grille horaire) | demdikk.sn (alerte) |
| 6 | **Premiers/derniers départs TAF TAF** (4 paires) | `first_departure` / `last_departure` | `CONFIRMED` | info-voyageurs |
| 7 | **Express AIBD 24 h/24 7 j/7** | amplitude de service (ligne express) | `CONFIRMED` | offres-de-transport |
| 8 | **Signalement des 7 identités Tata** comme `CONFLICTING` (jamais fusionnées) | métadonnée de conflit | `CONFLICTING` | §4 de ce rapport |

Interdits maintenus pour toute intégration future : transformer une `ROUTE_DESCRIPTION` en `stop_sequence` ; convertir une fréquence en horaire ; réutiliser `data/gtfs/stop_times.txt` ; publier un `realtime_status = CONFIRMED`.

---

## 15. Données devant rester UNKNOWN

| Donnée | Portée | Motif |
|---|---|---|
| **Tous les horaires AFTU (72 lignes)** | `schedule_status = UNKNOWN` | aucune publication par ligne (la FAQ n'est pas un horaire) |
| **Toutes les fréquences AFTU / Tata / DDD** | `frequency_status = UNKNOWN` | aucune fréquence publiée (§10) |
| **Horaires de 46 identifiants DDD** | `schedule_status = UNKNOWN` | seule la ligne 01 et TAF TAF publient des heures |
| **Arrêts AFTU (séquences)** | `stops = UNKNOWN` | aucune source ne publie d'arrêts AFTU ordonnés |
| **Itinéraires 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B** | `route = UNKNOWN` | titres seuls, aucune liste d'arrêts |
| **Arrêts TAF TAF / TO1** | `stops = UNKNOWN` | corridor décrit sans arrêts nommés |
| **Identités des 7 « Tata »** | `line_identity = UNKNOWN`/`CONFLICTING` | aucune source officielle Tata |
| **Temps réel (tous réseaux)** | `realtime_status = UNKNOWN` | CCO interne uniquement, aucune API publique |
| **319, 311, 327** (source unique) | `corroboration = UNVERIFIED` | publiées par une seule page DDD (routes publiées mais identité non recoupée) |
| **Doublons potentiels** (5/25, 10/13, 5/12/6, 18/20, 15A/15B, 16A/16B, 227/327, 502/503) | `dedup = UNKNOWN` | aucun arbitrage possible sans l'opérateur |
| **`ddd_3` (n° 3) et `ddd_14` (n° 14)** | `line_identity = UNVERIFIED` | ces numéros ne sont pas publiés par DDD |

---

## 16. Données nécessitant une confirmation opérateur

| # | Question à poser | Destinataire | Impact si non confirmé |
|---|---|---|---|
| 1 | Les lignes **5** et **25** AFTU sont-elles un même service (tracés identiques) ou deux services distincts ? | AFTU | doublon non tranchable |
| 2 | Itinéraires officiels des lignes AFTU **84, 85, 86, 87, 88, 89, 91** ? | AFTU | 7 lignes sans itinéraire |
| 3 | Horaires (ou au minimum premiers/derniers départs) et fréquences des **72 lignes AFTU** ? | AFTU | `schedule_status`/`frequency_status` restent `UNKNOWN` |
| 4 | Liste officielle des **lignes exploitées par les véhicules « Tata »** et leur éventuelle correspondance avec les 72 numéros AFTU ? | AFTU / GIE | 7 identités `CONFLICTING` non résolues |
| 5 | Ligne **6** : Cambérène 2 ↔ Palais 2 **ou** Guédiawaye ↔ Palais 1 ? | DDD | conflit conservé (`CONFLICTING`) |
| 6 | Lignes **18** et **20** : boucle (Dieuppeul ↔ Centre-ville ↔ Dieuppeul) ou aller simple ? S'agit-il d'une seule et même ligne ? | DDD | 2 conflits + 1 doublon potentiel |
| 7 | Ligne **501** : « Gare de Dakar ↔ Palais 2 » ou « Palais 2 ↔ Leclerc » ? | DDD | conflit conservé |
| 8 | Lignes **10 et 13** : deux lignes distinctes ou une seule ligne à deux indices ? | DDD | doublon potentiel |
| 9 | Lignes **5, 6, 12** : périmètres respectifs (Guédiawaye ↔ Palais 1) ? | DDD | doublon potentiel + conflit |
| 10 | Lignes **15A/15B** et **16A/16B** : quel tracé distingue A de B ? | DDD | variantes non documentées |
| 11 | **227** et **327** : deux lignes distinctes aux mêmes extrémités ? | DDD | doublon potentiel |
| 12 | **502/503** (boucles) vs **502A/502B** et **503A/503B** (dessertes gares) : périmètres exacts, et **504A/504B** absentes de la page « reseau-urbain » ? | DDD | asymétrie documentaire conservée |
| 13 | Erreurs internes à corriger côté source : **23** (Palais 1 vs Palais 2), **217/218** (listes identiques), **232/233** (listes identiques), **208** (Bayakh absent de la liste) ? | DDD | contradictions conservées telles quelles |
| 14 | Statut de **319, 311, 327** (absentes d'`info-voyageurs`) : lignes actives ? | DDD | source unique → `UNVERIFIED` |
| 15 | Horaires / fréquences des lignes DDD urbaines et banlieue (hors 01 et TAF TAF) ? | DDD | `UNKNOWN` conservé |
| 16 | Existence d'un **flux temps réel** public (API/GTFS-RT) après la mise en service du CCO ? | DDD / CETUD | `realtime_status = UNKNOWN` conservé |

---



## 17. Fiches documentaires DDD (champs imposés)

Une fiche par **identifiant officiellement publié** (48 identifiants, union des deux pages). Rappel : `UNKNOWN` = aucune donnée officielle ; `PARTIAL` = publié mais incomplet/non corroboré ; `CONFLICTING` = sources officielles incompatibles.

### 17.1 Dessertes gares du TER (7 identifiants) + les 2 boucles publiées 502 / 503

- **LINE_ID** `502A` · **NETWORK** `DDD` · **OFFICIAL_NAME** `502A` · **ORIGIN** `COLOBANE` · **DESTINATION** `UCAD` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : COLOBANE ↔ UCAD (aucun itinéraire publié)
- **LINE_ID** `502B` · **NETWORK** `DDD` · **OFFICIAL_NAME** `502B` · **ORIGIN** `COLOBANE` · **DESTINATION** `ABASS NDAO` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : COLOBANE ↔ ABASS NDAO (aucun itinéraire publié)
- **LINE_ID** `503A` · **NETWORK** `DDD` · **OFFICIAL_NAME** `503A` · **ORIGIN** `COLOBANE` · **DESTINATION** `MOLE 8` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : COLOBANE ↔ MOLE 8 (aucun itinéraire publié)
- **LINE_ID** `503B` · **NETWORK** `DDD` · **OFFICIAL_NAME** `503B` · **ORIGIN** `COLOBANE` · **DESTINATION** `HYDROCARBURE` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : COLOBANE ↔ HYDROCARBURE (aucun itinéraire publié)
- **LINE_ID** `504A` · **NETWORK** `DDD` · **OFFICIAL_NAME** `504A` · **ORIGIN** `GARE DIAMNIADIO` · **DESTINATION** `SPHERE MINISTERIEL` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : GARE DIAMNIADIO ↔ SPHERE MINISTERIEL — absente de la page reseau-urbain
- **LINE_ID** `504B` · **NETWORK** `DDD` · **OFFICIAL_NAME** `504B` · **ORIGIN** `SEBIKOTANE` · **DESTINATION** `GARE DIAMNIADIO` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte gare TER : SEBIKOTANE ↔ GARE DIAMNIADIO — absente de la page reseau-urbain
- **LINE_ID** `501` · **NETWORK** `DDD` · **OFFICIAL_NAME** `501` · **ORIGIN** `GARE DE DAKAR` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** classée « desserte gare du TER » par info-voyageurs ; terminus divergents entre les deux pages
- **LINE_ID** `502` · **NETWORK** `DDD` · **OFFICIAL_NAME** `502` · **ORIGIN** `GARE DE GARE` · **DESTINATION** `GARE DE GARE` · **DIRECTION** `boucle — terminus non renseignés` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publiée en boucle « GARE DE GARE » ; info-voyageurs la scinde en 502A/502B
- **LINE_ID** `503` · **NETWORK** `DDD` · **OFFICIAL_NAME** `503` · **ORIGIN** `GARE DE GARE` · **DESTINATION** `GARE DE GARE` · **DIRECTION** `boucle — terminus non renseignés` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publiée en boucle « GARE DE GARE » ; info-voyageurs la scinde en 503A/503B

### 17.2 Lignes urbaines (12)

- **LINE_ID** `1` · **NETWORK** `DDD` · **OFFICIAL_NAME** `1` · **ORIGIN** `PARCELLES ASSAINIES` · **DESTINATION** `PLACE LECLERC` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `CONFIRMED — 05 h 30 / 20 h 30 (Parcelles) ; 06 h 30 / 21 h 00 (Leclerc)` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `4` · **NETWORK** `DDD` · **OFFICIAL_NAME** `4` · **ORIGIN** `LIBERTÉ 5` · **DESTINATION** `PLACE LECLERC` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `7` · **NETWORK** `DDD` · **OFFICIAL_NAME** `7` · **ORIGIN** `OUAKAM` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `8` · **NETWORK** `DDD` · **OFFICIAL_NAME** `8` · **ORIGIN** `AÉROPORT LSS` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `9` · **NETWORK** `DDD` · **OFFICIAL_NAME** `9` · **ORIGIN** `LIBERTÉ 6` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `10` · **NETWORK** `DDD` · **OFFICIAL_NAME** `10` · **ORIGIN** `LIBERTÉ 5` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** libellé identique à la ligne 13 (doublon potentiel)
- **LINE_ID** `13` · **NETWORK** `DDD` · **OFFICIAL_NAME** `13` · **ORIGIN** `LIBERTÉ 5` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** libellé identique à la ligne 10 (doublon potentiel)
- **LINE_ID** `18` · **NETWORK** `DDD` · **OFFICIAL_NAME** `18` · **ORIGIN** `DIEUPPEUL` · **DESTINATION** `DIEUPPEUL` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** bloc dupliqué dans la page reseau-urbain ; périmètre boucle/aller simple non tranché
- **LINE_ID** `20` · **NETWORK** `DDD` · **OFFICIAL_NAME** `20` · **ORIGIN** `DIEUPPEUL` · **DESTINATION** `DIEUPPEUL` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** périmètre boucle/aller simple non tranché ; libellé identique à la ligne 18
- **LINE_ID** `23` · **NETWORK** `DDD` · **OFFICIAL_NAME** `23` · **ORIGIN** `PARCELLES ASSAINIES` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** en-tête « Palais 1 » vs arrêts terminant « Palais 2 »
- **LINE_ID** `121` · **NETWORK** `DDD` · **OFFICIAL_NAME** `121` · **ORIGIN** `SCAT URBAM` · **DESTINATION** `LECLERC` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `319` · **NETWORK** `DDD` · **OFFICIAL_NAME** `319` · **ORIGIN** `LIBERTÉ 6` · **DESTINATION** `OUAKAM` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publiée uniquement par la page reseau-urbain

### 17.3 Lignes de banlieue (22)

- **LINE_ID** `2` · **NETWORK** `DDD` · **OFFICIAL_NAME** `2` · **ORIGIN** `DAROUKHANE` · **DESTINATION** `PLACE LECLERC` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `5` · **NETWORK** `DDD` · **OFFICIAL_NAME** `5` · **ORIGIN** `GUÉDIAWAYE` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** libellé identique aux lignes 6 (page réseau) et 12 (doublon potentiel)
- **LINE_ID** `6` · **NETWORK** `DDD` · **OFFICIAL_NAME** `6` · **ORIGIN** `CAMBÉRÈNE 2` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** conflit d'identité entre les deux pages DDD — arbitrage interdit
- **LINE_ID** `11` · **NETWORK** `DDD` · **OFFICIAL_NAME** `11` · **ORIGIN** `KEUR MASSAR` · **DESTINATION** `LAT DIOR` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `12` · **NETWORK** `DDD` · **OFFICIAL_NAME** `12` · **ORIGIN** `GUÉDIAWAYE` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** libellé identique aux lignes 5 et 6 (page réseau) (doublon potentiel)
- **LINE_ID** `15` · **NETWORK** `DDD` · **OFFICIAL_NAME** `15` · **ORIGIN** `RUFISQUE` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** la page reseau-urbain publie « 15 » (arrêts détaillés) ; info-voyageurs publie 15A/15B
- **LINE_ID** `15A` · **NETWORK** `DDD` · **OFFICIAL_NAME** `15A` · **ORIGIN** `RUFISQUE` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publie le même intitulé que 15B ; aucun itinéraire publié
- **LINE_ID** `15B` · **NETWORK** `DDD` · **OFFICIAL_NAME** `15B` · **ORIGIN** `RUFISQUE` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publie le même intitulé que 15A ; aucun itinéraire publié
- **LINE_ID** `16A` · **NETWORK** `DDD` · **OFFICIAL_NAME** `16A` · **ORIGIN** `MALIKA` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** variante A : tracé distinct de 16B non documenté par l'intitulé
- **LINE_ID** `16B` · **NETWORK** `DDD` · **OFFICIAL_NAME** `16B` · **ORIGIN** `MALIKA` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** variante B : tracé distinct de 16A non documenté par l'intitulé
- **LINE_ID** `208` · **NETWORK** `DDD` · **OFFICIAL_NAME** `208` · **ORIGIN** `BAYAKH` · **DESTINATION** `RUFISQUE` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** arrêt « Bayakh » absent de la liste d'arrêts publiée
- **LINE_ID** `213` · **NETWORK** `DDD` · **OFFICIAL_NAME** `213` · **ORIGIN** `RUFISQUE` · **DESTINATION** `DIEUPPEUL` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `217` · **NETWORK** `DDD` · **OFFICIAL_NAME** `217` · **ORIGIN** `THIAROYE` · **DESTINATION** `OUAKAM` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** liste d'arrêts terminant « aéroport LSS » alors que l'en-tête annonce Ouakam
- **LINE_ID** `218` · **NETWORK** `DDD` · **OFFICIAL_NAME** `218` · **ORIGIN** `THIAROYE` · **DESTINATION** `AÉROPORT LSS` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** liste d'arrêts identique à celle de la ligne 217
- **LINE_ID** `219` · **NETWORK** `DDD` · **OFFICIAL_NAME** `219` · **ORIGIN** `DAROUKHANE` · **DESTINATION** `OUAKAM` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `220` · **NETWORK** `DDD` · **OFFICIAL_NAME** `220` · **ORIGIN** `RUFISQUE` · **DESTINATION** `GUÉDIAWAYE` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `221` · **NETWORK** `DDD` · **OFFICIAL_NAME** `221` · **ORIGIN** `GADAYE` · **DESTINATION** `ALMADIES` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `227` · **NETWORK** `DDD` · **OFFICIAL_NAME** `227` · **ORIGIN** `TERMINUS KEUR MASSAR` · **DESTINATION** `TERMINUS PARCELLES` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** mêmes extrémités que la ligne 327 (doublon potentiel)
- **LINE_ID** `228` · **NETWORK** `DDD` · **OFFICIAL_NAME** `228` · **ORIGIN** `TERMINUS RUFISQUE` · **DESTINATION** `YENNE` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `232` · **NETWORK** `DDD` · **OFFICIAL_NAME** `232` · **ORIGIN** `BAUX MARAICHERS` · **DESTINATION** `AÉROPORT LSS` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `233` · **NETWORK** `DDD` · **OFFICIAL_NAME** `233` · **ORIGIN** `BAUX MARAICHERS` · **DESTINATION** `PALAIS 1` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** liste d'arrêts identique à celle de la ligne 232
- **LINE_ID** `234` · **NETWORK** `DDD` · **OFFICIAL_NAME** `234` · **ORIGIN** `JAXAAY` · **DESTINATION** `LECLERC` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFIRMED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** —
- **LINE_ID** `311` · **NETWORK** `DDD` · **OFFICIAL_NAME** `311` · **ORIGIN** `LAC ROSE` · **DESTINATION** `CROISSEMENT KEUR MASSAR` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** publiée uniquement par la page reseau-urbain
- **LINE_ID** `327` · **NETWORK** `DDD` · **OFFICIAL_NAME** `327` · **ORIGIN** `KEUR MASSAR` · **DESTINATION** `TERMINUS PARCELLES` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt)` · **EXPLICIT_STOPS** `publiés (liste explicite ordonnée)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** mêmes extrémités que la ligne 227 ; publiée par une seule page

### 17.4 TAF TAF (3 désignations publiées)

- **LINE_ID** `TAF TAF` · **NETWORK** `DDD` · **OFFICIAL_NAME** `TAF TAF` · **ORIGIN** `OUAKAM` · **DESTINATION** `AIBD / SPHÈRE MINISTÉRIELLE (Diamniadio)` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `CONFIRMED (premiers/derniers départs)` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte TAF TAF avec premiers/derniers départs officiels ; arrêts non nommés
- **LINE_ID** `TAF` · **NETWORK** `DDD` · **OFFICIAL_NAME** `TAF` · **ORIGIN** `OUAKAM` · **DESTINATION** `AIBD` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `corridor publié (points de repère)` · **EXPLICIT_STOPS** `non publiés (aucun arrêt nommé)` · **SCHEDULE** `CONFIRMED (premiers/derniers départs)` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** desserte TAF TAF (corridor Ouakam → AIBD) ; arrêts non nommés
- **LINE_ID** `TO1` · **NETWORK** `DDD` · **OFFICIAL_NAME** `TO1` · **ORIGIN** `OUAKAM` · **DESTINATION** `PALAIS 2` · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `corridor publié (points de repère)` · **EXPLICIT_STOPS** `non publiés (aucun arrêt nommé)` · **SCHEDULE** `CONFIRMED (premiers/derniers départs)` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `PARTIAL` · **SOURCE_URL** `https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** variante TAF TAF : OUAKAM ↔ PALAIS 2 (mentionnée uniquement par la page reseau-urbain)

### 17.5 Fiches des 15 entrées candidates du référentiel (comparaison avec l'officiel)

Les 15 entrées DDD du référentiel interne sont documentées ci-dessous (les 5 dont l'identité officielle est absente, puis les 10 en collision de numéro). Objectif : **éviter toute perte d'information**. **Aucune suppression, aucune fusion.**

- **LINE_ID** `ddd_1` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `1` · **ORIGIN/DESTINATION** `PARCELLES ASSAINIES ↔ PLACE LECLERC` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_7` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `7` · **ORIGIN/DESTINATION** `OUAKAM ↔ PALAIS 2` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_8` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `8` · **ORIGIN/DESTINATION** `AÉROPORT LSS ↔ PALAIS 2` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_9` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `9` · **ORIGIN/DESTINATION** `LIBERTÉ 6 ↔ PALAIS 2` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_10` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `10` · **ORIGIN/DESTINATION** `LIBERTÉ 5 ↔ PALAIS 2` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_11` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `11` · **ORIGIN/DESTINATION** `KEUR MASSAR ↔ LAT DIOR` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_12` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `12` · **ORIGIN/DESTINATION** `GUÉDIAWAYE ↔ PALAIS 1` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_15` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `15` · **ORIGIN/DESTINATION** `RUFISQUE ↔ PALAIS 1` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_20` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `20` · **ORIGIN/DESTINATION** `DIEUPPEUL ↔ CENTRE-VILLE` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_23` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `23` · **ORIGIN/DESTINATION** `PARCELLES ASSAINIES ↔ PALAIS 1` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `new_commune_01` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `01` · **ORIGIN/DESTINATION** `PARCELLES ASSAINIES ↔ PLACE LECLERC (= ligne 1)` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `new_commune_02` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `02` · **ORIGIN/DESTINATION** `DAROUKHANE ↔ PLACE LECLERC (= ligne 2)` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `new_commune_13` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** `13` · **ORIGIN/DESTINATION** `LIBERTÉ 5 ↔ PALAIS 2 (= ligne 13)` (officiel) · **DIRECTION** `bidirectionnelle (non documentée)` · **ROUTE_DESCRIPTION** `publiée (arrêt par arrêt) pour l'identité officielle` · **EXPLICIT_STOPS** `publiés (page reseau-urbain)` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `CONFLICTING` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/` · **VERIFIED_AT** `2026-09-25` · **NOTES** l'entrée interne porte un numéro déjà attribué par DDD à une **autre** identité : collision conservée, aucun arbitrage (§3.3, §12)
- **LINE_ID** `ddd_3` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** *(aucun — non publié par DDD)* · **ORIGIN** `SANDAGA` (candidat) · **DESTINATION** `OUAKAM / NGOR` (candidat) · **DIRECTION** `non documentée` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `UNVERIFIED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/ (absence constatée)` · **VERIFIED_AT** `2026-09-25` · **NOTES** numéro non publié par l'exploitant : identité non prouvée, à confirmer opérateur (§16)
- **LINE_ID** `ddd_14` (candidat) · **NETWORK** `DDD` · **OFFICIAL_NAME** *(aucun — non publié par DDD)* · **ORIGIN** `GARE MARITIME` (candidat) · **DESTINATION** `UCAD` (candidat) · **DIRECTION** `non documentée` · **ROUTE_DESCRIPTION** `non publiée` · **EXPLICIT_STOPS** `non publiés` · **SCHEDULE** `UNKNOWN` · **FREQUENCY** `UNKNOWN` · **DATA_STATUS** `UNVERIFIED` · **SOURCE_URL** `https://demdikk.sn/info-voyageurs/ + https://demdikk.sn/reseau-urbain-dakar/ (absence constatée)` · **VERIFIED_AT** `2026-09-25` · **NOTES** numéro non publié par l'exploitant : identité non prouvée, à confirmer opérateur (§16)

---

## 18. Tableau final

Tableau récapitulatif demandé. `Itinéraire` = nature de l'itinéraire **publié** ; `Arrêts` = existence d'arrêts **nommés** ; les champs `UNKNOWN` correspondent à une **absence de publication officielle**, jamais à une donnée manquante à deviner.

| Réseau | Ligne | Origine | Destination | Itinéraire | Arrêts | Horaires | Fréquence | Statut | Source |
|---|---|---|---|---|---|---|---|---|---|
| AFTU | **1** | LAT DIOR | HLM GRAND YOFF | description de rues (page `/map/dakar-urbain-ligne-1/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-1/` |
| AFTU | **2** | ROUTE PRINCIPALE PARCELLES | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-2/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-2/` |
| AFTU | **3** | YOFF | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-3/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-3/` |
| AFTU | **4** | YOFF VILLAGE | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-4/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-4/` |
| AFTU | **5** | PARCELLES ASSAINIES | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-5/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-5/` |
| AFTU | **24** | UCAD | NOTAIRE GUEDIAWAYE | description de rues (page `/map/dakar-urbain-ligne-24/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-24/` |
| AFTU | **25** | PARCELLES ASSAINIES | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-25/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-25/` |
| AFTU | **26** | PARCELLES ASSAINIES | POST THIAROYE | description de rues (page `/map/dakar-urbain-ligne-26/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-26/` |
| AFTU | **27** | MARCHE BOUBESS | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-27/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-27/` |
| AFTU | **28** | HAMO V/VI | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-28/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-28/` |
| AFTU | **29** | CITE NATION UNIES (CAMBERENE) | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-29/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-29/` |
| AFTU | **30** | GADAYE (GUEDIEWAYE) | GARE DE COLOBANE | description de rues (page `/map/dakar-urbain-ligne-30/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-30/` |
| AFTU | **31** | TALLY ICOTAF X ROUTE DES NIAYES | HOPITAL ABASS NDAO | description de rues (page `/map/dakar-urbain-ligne-31/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-31/` |
| AFTU | **32** | SAHM | SERIGNE ASSANE | description de rues (page `/map/dakar-urbain-ligne-32/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-32/` |
| AFTU | **33** | COLOBANE | SERIGNE ASSANE | description de rues (page `/map/dakar-urbain-ligne-33/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-33/` |
| AFTU | **34** | NORD FOIRE | LAT DIOR | description de rues (page `/map/dakar-urbain-ligne-34/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-34/` |
| AFTU | **35** | NGOR | PIKINE TEXACO | description de rues (page `/map/dakar-urbain-ligne-35/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-35/` |
| AFTU | **36** | MARCHE NDIAREME | NGOR | description de rues (page `/map/dakar-urbain-ligne-36/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-36/` |
| AFTU | **37** | CITÉ APIX | UCAD (CLAUDEL) | description de rues (page `/map/dakar-urbain-ligne-37/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-37/` |
| AFTU | **38** | CITE DES ENSEIGNANTS | SHAM | description de rues (page `/map/dakar-urbain-ligne-38/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-38/` |
| AFTU | **39** | LAT-DIOR | DIAMALAYE | description de rues (page `/map/dakar-urbain-ligne-39/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-39/` |
| AFTU | **40** | GRAND MBAO | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-40/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-40/` |
| AFTU | **41** | PETERSEN | ETAGE MADIALE | description de rues (page `/map/dakar-urbain-ligne-41/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-41/` |
| AFTU | **42** | GADAYE (GUEDIEWAYE) | OUAKAM BAYE | description de rues (page `/map/dakar-urbain-ligne-42/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-42/` |
| AFTU | **43** | OUAKAM | THIERNO NDIAYE | description de rues (page `/map/dakar-urbain-ligne-43/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-43/` |
| AFTU | **44** | GRAND MBAO | OUAKAM | description de rues (page `/map/dakar-urbain-ligne-44/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-44/` |
| AFTU | **45** | KOUNOUNE NGALAM | PARCELLES EGLISE | description de rues (page `/map/dakar-urbain-ligne-45/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-45/` |
| AFTU | **46** | SDE SERIGNE ASSANE | LAT DIOR | description de rues (page `/map/dakar-urbain-ligne-46/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-46/` |
| AFTU | **47** | LAT DIOR | ALMADIES | description de rues (page `/map/dakar-urbain-ligne-47/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-47/` |
| AFTU | **48** | CITE SERIGNE MANSOUR | LAT DIOR | description de rues (page `/map/dakar-urbain-ligne-48/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-48/` |
| AFTU | **49** | GADAYE | NGOR | description de rues (page `/map/dakar-urbain-ligne-49/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-49/` |
| AFTU | **50** | PETERSEN | MALIKA CIMETIERE | description de rues (page `/map/dakar-urbain-ligne-50/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-50/` |
| AFTU | **51** | JAXAAY | GARE DES BAUX MARAICHERS | description de rues (page `/map/dakar-urbain-ligne-51/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-51/` |
| AFTU | **52** | BOUNTOU PIKINE | KEUR MASSAR | description de rues (page `/map/dakar-urbain-ligne-52/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-52/` |
| AFTU | **53** | KEUR MASSAR | SEBIKOTANE | description de rues (page `/map/dakar-urbain-ligne-53/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-53/` |
| AFTU | **54** | TERMINUS KEUR MASSAR (CITE MTOA) | UCAD | description de rues (page `/map/dakar-urbain-ligne-54/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-54/` |
| AFTU | **55** | TERMINUS RUFISQUE SONADIS | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-55/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-55/` |
| AFTU | **56** | JAXAAY 2 | PETERSEN | description de rues (page `/map/dakar-urbain-ligne-56/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-56/` |
| AFTU | **57** | LIBERTE 6 | RUFISQUE | description de rues (page `/map/dakar-urbain-ligne-57/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-57/` |
| AFTU | **58** | SAHM | COMICO | description de rues (page `/map/dakar-urbain-ligne-58/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-58/` |
| AFTU | **59** | DIAMALAYE | CITÉ GENDARMERIE (Jaxaay) | description de rues (page `/map/dakar-urbain-ligne-59/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-59/` |
| AFTU | **60** | COLOBANE | BARGNY | description de rues (page `/map/dakar-urbain-ligne-60/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-60/` |
| AFTU | **61** | ALMADIES | KEUR MASSAR | description de rues (page `/map/dakar-urbain-ligne-61/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-61/` |
| AFTU | **62** | ARRET CHERIF (RUFISQUE) | PENC MI (GUEULE TAPEE) | description de rues (page `/map/dakar-urbain-ligne-62/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-62/` |
| AFTU | **63** | TERMINUS CAMP MARCHAND RUFISQUE | STADE LSS | description de rues (page `/map/dakar-urbain-ligne-63/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-63/` |
| AFTU | **64** | GUEDIAWAYE | RUFISQUE | description de rues (page `/map/dakar-urbain-ligne-64/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-64/` |
| AFTU | **65** | COLOBANE | JAXAAY | description de rues (page `/map/dakar-urbain-ligne-65/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-65/` |
| AFTU | **66** | YOFF | GOROM 1 | description de rues (page `/map/dakar-urbain-ligne-66/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-66/` |
| AFTU | **67** | OUAKAM | THIAWLENE RUFISQUE | description de rues (page `/map/dakar-urbain-ligne-67/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-67/` |
| AFTU | **68** | YEUMBEUL | SEBIKOTANE | description de rues (page `/map/dakar-urbain-ligne-68/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-68/` |
| AFTU | **69** | DIAMALAYE | TERMINUS TIVAOUANE PEUL | description de rues (page `/map/dakar-urbain-ligne-69/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-69/` |
| AFTU | **70** | DAROUKHANE | JAXXAY 2 | description de rues (page `/map/dakar-urbain-ligne-70/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-70/` |
| AFTU | **71** | KEUR MASSAR | CLAUDEL | description de rues (page `/map/dakar-urbain-ligne-71/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-71/` |
| AFTU | **72** | GUEDIAWAYE | KOUNOUNE | description de rues (page `/map/dakar-urbain-ligne-72/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-72/` |
| AFTU | **73** | LAC ROSE | POSTE THIAROYE | description de rues (page `/map/dakar-urbain-ligne-73/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-73/` |
| AFTU | **74** | TERMINUS BARGNY (GARE FERROVIAIRE) | TIVAOUNE PEUL | description de rues (page `/map/dakar-urbain-ligne-74/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-74/` |
| AFTU | **75** | TERMINUS MALIKA (CITE SONATEL) | TERMINUS GARE ROUTIERE COLOBANE | description de rues (page `/map/dakar-urbain-ligne-75/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-75/` |
| AFTU | **76** | SIPRES | CITE ASSURANCE | description de rues (page `/map/dakar-urbain-ligne-76/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-76/` |
| AFTU | **77** | RUFISQUE | LIBERTE 5 | description de rues (page `/map/dakar-urbain-ligne-77/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-77/` |
| AFTU | **78** | DIAMAGUENE | LIBERTE 5 | description de rues (page `/map/dakar-urbain-ligne-78/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-78/` |
| AFTU | **79** | SANGALKAM | CAMBERENE | description de rues (page `/map/dakar-urbain-ligne-79/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-79/` |
| AFTU | **80** | DIAMALAYE | DAROU THIOUB | description de rues (page `/map/dakar-urbain-ligne-80/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-80/` |
| AFTU | **81** | BEAUX MARRAICHERS | TIVAOUNE PEUL | description de rues (page `/map/dakar-urbain-ligne-81/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-81/` |
| AFTU | **82** | LAT DIOR | COMICO YEUMBEUL | description de rues (page `/map/dakar-urbain-ligne-82/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-82/` |
| AFTU | **83** | RUFISQUE ARAFAT | ZONE DE CAPTAGE | description de rues (page `/map/dakar-urbain-ligne-83/`) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `aftu-senegal.org/infos-pratiques` + `/map/dakar-urbain-ligne-83/` |
| AFTU | **84** | UCAD | JAXAAY | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **85** | BANOBA | LIBERTE 5 | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **86** | TOURNALOU BOUNE | TOUBAB DIALAW | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **87** | BAMBILOR | MOSQUEE MASSALIKOU DJINANE | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **88** | MTOA | LIBERTE 5 | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **89** | BARGNY | CROISEMENT NIAGUE (CITE SICAP) | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| AFTU | **91** | APIX | DOUGAR | **non trouvé** (aucune page publiée) | non publiés | UNKNOWN | UNKNOWN | `UNVERIFIED` | `aftu-senegal.org/infos-pratiques` |
| Tata (référentiel) | `new_commune_11` — Tata Ouakam - Ngor Village - Yoff Tong | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `new_commune_12` — Tata Jaxaay - Rufisque - Diamniadio 2 | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `tata_218` — Mermoz ↔ Keur Massar (Tata 218) | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `tata_219` — Parcelles Assainies ↔ Petersen (Tata 219) | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `tata_50` — Guédiawaye ↔ Sandaga (Tata Ligne 50) | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `tata_64` — Pikine ↔ Liberté 6 (Tata Ligne 64) | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| Tata (référentiel) | `tata_78` — Yoff ↔ Petersen via Cambérène (Tata 78) | non publiée par une source officielle | non publiée par une source officielle | **non trouvé** (aucune source officielle Tata) | non publiés | UNKNOWN | UNKNOWN | `CONFLICTING` | `aftu-senegal.org` (absence constatée) + sources de contexte §13.2 |
| DDD | **1** | PARCELLES ASSAINIES | PLACE LECLERC | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | **CONFIRMED** — 05 h 30 / 20 h 30 ; 06 h 30 / 21 h 00 | UNKNOWN | `CONFIRMED` | `demdikk.sn` (alerte) + `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **2** | DAROUKHANE | PLACE LECLERC | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **4** | LIBERTÉ 5 | PLACE LECLERC | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **5** | GUÉDIAWAYE | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **6** | CAMBÉRÈNE 2 | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **7** | OUAKAM | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **8** | AÉROPORT LSS | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **9** | LIBERTÉ 6 | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **10** | LIBERTÉ 5 | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **11** | KEUR MASSAR | LAT DIOR | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **12** | GUÉDIAWAYE | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **13** | LIBERTÉ 5 | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **15** | RUFISQUE | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **15A** | RUFISQUE | PALAIS 1 | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **15B** | RUFISQUE | PALAIS 1 | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **16A** | MALIKA | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **16B** | MALIKA | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **18** | DIEUPPEUL | DIEUPPEUL | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **20** | DIEUPPEUL | DIEUPPEUL | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **23** | PARCELLES ASSAINIES | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **121** | SCAT URBAM | LECLERC | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **208** | BAYAKH | RUFISQUE | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **213** | RUFISQUE | DIEUPPEUL | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **217** | THIAROYE | OUAKAM | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **218** | THIAROYE | AÉROPORT LSS | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **219** | DAROUKHANE | OUAKAM | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **220** | RUFISQUE | GUÉDIAWAYE | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **221** | GADAYE | ALMADIES | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **227** | TERMINUS KEUR MASSAR | TERMINUS PARCELLES | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **228** | TERMINUS RUFISQUE | YENNE | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **232** | BAUX MARAICHERS | AÉROPORT LSS | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **233** | BAUX MARAICHERS | PALAIS 1 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **234** | JAXAAY | LECLERC | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFIRMED` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **311** | LAC ROSE | CROISSEMENT KEUR MASSAR | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **319** | LIBERTÉ 6 | OUAKAM | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **327** | KEUR MASSAR | TERMINUS PARCELLES | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **501** | GARE DE DAKAR | PALAIS 2 | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/info-voyageurs` + `/reseau-urbain-dakar` |
| DDD | **502** | GARE DE GARE | GARE DE GARE | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **502A** | COLOBANE | UCAD | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **502B** | COLOBANE | ABASS NDAO | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **503** | GARE DE GARE | GARE DE GARE | arrêt par arrêt (page `reseau-urbain-dakar`) | publiés (liste explicite) | UNKNOWN | UNKNOWN | `CONFLICTING` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **503A** | COLOBANE | MOLE 8 | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **503B** | COLOBANE | HYDROCARBURE | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **504A** | GARE DIAMNIADIO | SPHERE MINISTERIEL | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **504B** | SEBIKOTANE | GARE DIAMNIADIO | **non publié** (titre seul) | non publiés | UNKNOWN | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **TAF TAF** | OUAKAM | AIBD / SPHÈRE MINISTÉRIELLE (Diamniadio) | corridor publié (points de repère) | non publiés (aucun arrêt nommé) | **CONFIRMED** — premiers/derniers départs | UNKNOWN | `PARTIAL` | `demdikk.sn/info-voyageurs` |
| DDD | **TAF** | OUAKAM | AIBD | corridor publié (points de repère) | non publiés (aucun arrêt nommé) | **CONFIRMED** — premiers/derniers départs | UNKNOWN | `PARTIAL` | `demdikk.sn/reseau-urbain-dakar` |
| DDD | **TO1** | OUAKAM | PALAIS 2 | corridor publié (points de repère) | non publiés (aucun arrêt nommé) | **CONFIRMED** — premiers/derniers départs | UNKNOWN | `PARTIAL` | `demdikk.sn/reseau-urbain-dakar` |

### 18.1 Récapitulatif des statuts

| Réseau | Entités analysées | Statuts |
|---|---|---|
| AFTU | **72** | `PARTIAL` = 65 (itinéraire documenté, sans arrêts ni horaires) · `UNVERIFIED` = 7 (aucun itinéraire) |
| Tata (référentiel) | **7** | `CONFLICTING` = 7 (collision de numéros, identité non établie) |
| DDD (officiel) | **48** | `CONFIRMED` = 15 · `PARTIAL` = 16 · `CONFLICTING` = 17 |
| DDD (candidats internes) | **15** | `CONFLICTING` = 13 (collision de numéro / identité différente) · `UNVERIFIED` = 2 (n° 3 et 14 non publiés) |
| **Total** | **142** | — |

---

## 19. Synthèse des 16 points demandés et clôture

### 19.1 Réponses aux 16 points

| # | Point | Réponse |
|---|---|---|
| 1 | Nombre de lignes AFTU actuelles | **72** (n° 1–5, 24–89, 91 ; trous 6–23 et 90) — aucune avec arrêts, horaire ou fréquence |
| 2 | Nombre de lignes TATA | **0 ligne publiée par un opérateur « Tata »** ; 7 identités « Tata » dans le référentiel interne, toutes `CONFLICTING` |
| 3 | Nombre de lignes DDD actuelles | **48 identifiants publiés** (40 sur `info-voyageurs`, 39 blocs sur `reseau-urbain`, unions/inclusions détaillées §3) |
| 4 | Correspondances TATA ↔ AFTU | CONFIRMED_MATCH 0 · POSSIBLE_MATCH 0 · **CONFLICTING 7** · NO_MATCH 0 · UNKNOWN 0 (§4) |
| 5 | Doublons potentiels | AFTU 5/25 ; DDD 10/13, 5/6/12, 18/20, 15A/15B, 16A/16B, 227/327, 502/503 ; collisions inter-réseaux 1, 2, 4, 5 **non dédoublonnées** (§5) |
| 6 | Lignes AFTU avec itinéraire détaillé | **65** — mais il s'agit de **descriptions de rues**, jamais d'arrêts séquentiels (§6) |
| 7 | Lignes DDD avec itinéraire détaillé | **39 blocs arrêt par arrêt** (`reseau-urbain-dakar`), dont 15 conformes et 24 avec réserve (§7, §12) |
| 8 | Lignes sans itinéraire trouvé | AFTU 84–89, 91 · DDD 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B · TAF TAF (sans arrêts) · Tata 7 · candidats `ddd_3`, `ddd_14` (§8) |
| 9 | Lignes avec horaires officiels | **DDD 01** (05 h 30/20 h 30 – 06 h 30/21 h 00) et **TAF TAF** (4 paires de premiers/derniers départs) ; Express AIBD 24 h/24 7 j/7 (express) ; **0 côté AFTU** (§9) |
| 10 | Lignes avec fréquence seulement | **0** — aucune fréquence publiée pour AFTU, Tata ou DDD (§10) |
| 11 | Lignes sans horaire | **125** : 72 AFTU + 46 identifiants DDD + 7 Tata (§11) |
| 12 | Contradictions officielles | 4 entre pages DDD (6, 18, 20, 501) ; 8 anomalies internes à `reseau-urbain` (18 doublon de bloc, 23, 208, 217, 218, 233, 502, 503) ; 4 divergences de numérotation (15, 502, 503, 504) ; 1 doublon AFTU (5/25) ; 1 module de démo AFTU contradictoire (§12) |
| 13 | Sources utilisées | 11 sources officielles + 3 sources de contexte + 6 sources inaccessibles à exclure (§13) |
| 14 | Données intégrables | 8 blocs documentaires, **uniquement après validation** : nomenclature AFTU 72, descriptions d'itinéraire AFTU, identités DDD 48, listes d'arrêts DDD 39, horaires 01 et TAF TAF, Express AIBD, signalement Tata (§14) |
| 15 | Données devant rester UNKNOWN | horaires AFTU/DDD non publiés, toutes les fréquences, arrêts AFTU, itinéraires 15A/B et 502A/B/503A/B/504A/B, arrêts TAF TAF, identités Tata, temps réel, corroboration 311/319/327, doublons, candidats 3/14 (§15) |
| 16 | Données nécessitant confirmation opérateur | 16 questions listées (§16) — AFTU (4), DDD (11), temps réel (1) |

### 19.2 Clôture

**Conformité du dépôt** (contrôle final, read-only) :

```
$ git status --porcelain
?? docs/AUDIT_RESEAUX_AFTU_TATA_DDD_2026-09-25.md
$ git rev-parse HEAD
09767c2b1633dead91b35821c74f74d4a5d97395
```

Aucun fichier suivi par Git n'a été modifié : le seul élément nouveau est ce rapport. Aucune donnée du référentiel n'a été corrigée, fusionnée ou supprimée.

**Nombre exact de lignes analysées :**

| Périmètre | Entités |
|---|---|
| Lignes AFTU officielles | **72** |
| Identifiants DDD officiels (union des deux pages) | **48** |
| Dont blocs d'itinéraire arrêt par arrêt (DDD) | 39 |
| Entités « Tata » du référentiel interne | **7** |
| Entrées DDD candidates du référentiel interne (comparées) | **15** |
| **Total d'objets documentaires analysés** | **142** |

**Lignes nécessitant encore une recherche documentaire :**

| Réseau | Lignes / objets | Recherche à mener |
|---|---|---|
| AFTU | **84, 85, 86, 87, 88, 89, 91** | itinéraires officiels (aucune page publiée) |
| AFTU | **5 et 25** | dédoublonnage (libellés identiques) |
| AFTU | les **72** lignes | arrêts, horaires, fréquences (aucune publication) |
| DDD | **15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B** | itinéraires (titres seuls publiés) |
| DDD | **311, 319, 327** | corroboration par une 2ᵉ source officielle (source unique) |
| DDD | **6, 18, 20, 501** | arbitrage des terminus entre les deux pages |
| DDD | **23, 208, 217, 218, 232, 233, 502, 503** | corrections d'incohérences internes (côté DDD) |
| DDD | **10/13, 5/12/6, 18/20, 15A/15B, 16A/16B, 227/327** | dédoublonnage / distinction des variantes |
| DDD | **46 identifiants** | horaires et fréquences (hors 01 et TAF TAF) |
| Tata | **7 identités** | existence, exploitant et numéros officiels |

**Horaires réellement exploitables (tous réseaux AFTU/Tata/DDD) :**

| # | Donnée horaire | Nature | Statut |
|---|---|---|---|
| 1 | DDD ligne 01 : Parcelles 05 h 30 / 20 h 30 ; Leclerc 06 h 30 / 21 h 00 | premier/dernier départ | `CONFIRMED` |
| 2 | DDD TAF TAF Ouakam → AIBD : 06 h 00 / 21 h 00 | premier/dernier départ | `CONFIRMED` |
| 3 | DDD TAF TAF Ouakam → Sphère : 05 h 45 / 21 h 00 | premier/dernier départ | `CONFIRMED` |
| 4 | DDD TAF TAF AIBD → Ouakam : 06 h 00 / 21 h 00 | premier/dernier départ | `CONFIRMED` |
| 5 | DDD TAF TAF Sphère → Ouakam : 06 h 00 / 20 h 30 | premier/dernier départ | `CONFIRMED` |
| 6 | DDD Express AIBD : 24 h/24 et 7 j/7 (ligne express, forfait 6 000 FCFA) | amplitude de service | `CONFIRMED` |
| — | Aucune grille horaire par ligne (créneaux), aucune fréquence, aucun horaire AFTU | — | `UNKNOWN` conservé |

**Rien n'a été implémenté.** Aucune ligne de code, aucun fichier de données, aucun test n'a été touché : les horaires ci-dessus ne sont **pas** convertis en départs, aucune fréquence n'a été créée, aucun arrêt AFTU n'a été déduit d'une description de rues, aucune identité Tata n'a été fusionnée avec une ligne AFTU, et les contradictions DDD restent `CONFLICTING` sans arbitrage.

**STOP — en attente de validation de ce rapport avant toute intégration.**

