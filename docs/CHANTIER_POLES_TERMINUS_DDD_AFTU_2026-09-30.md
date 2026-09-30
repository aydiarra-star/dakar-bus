# Chantier — Identification des pôles, gares routières et terminus DDD / AFTU / TATA

**Date de vérification : 2026-09-30** · **Périmètre : DDD / AFTU / TATA uniquement.**

> **Règle absolue (§1) — TER/BRT hors périmètre.** Ce chantier est strictement
> **additif**. Aucune gare TER, aucune station BRT, aucun horaire, aucune
> fréquence, aucun GPS, aucun routage TER/BRT n'est modifié. `data/gtfs/`,
> `flutter-src/assets/data/passbi/{ter,brt}.json`, `dakar_network.json`,
> `servedInOrder()`, le calcul des minutes, la fin de service et la reprise
> T-1h sont **inchangés** (voir §Régression en fin de document).

---

## 1. Méthode et sources

Le référentiel est **dérivé des mêmes feeds PassBi déjà intégrés** (aucune
nouvelle source, aucune donnée saisie à la main) :

```
flutter-src/assets/data/passbi/ddd.json   (53 routes)
flutter-src/assets/data/passbi/aftu.json  (73 routes)
        │
        ▼  scripts/lib/ddd-aftu-terminus.mjs
   route → trip → direction → stop → stop_times
        │
        ▼  premier / dernier arrêt réellement desservi par chaque trip
   terminus A (départ) · terminus B (arrivée)
        │
        ▼  rattachement des terminus aux pôles + classification
   assets/data/reference/ddd_aftu_poles_terminus.json
```

Une ligne n'est déclarée **TERMINUS** à un pôle que si un arrêt terminus réel du
feed lui est rattaché. Une ligne qui ne fait que passer est enregistrée en
**TRANSIT** — jamais en terminus (§10, §13). Aucune association par proximité.

**Quatre concepts distingués** dans le modèle : `TERMINUS`, `GARE_ROUTIERE`,
`POLE_ECHANGE`, `ARRÊT DE TRANSIT`. Un même lieu peut cumuler plusieurs rôles
(ex. Petersen : pôle d'échange **et** gare routière **et** terminus de certaines
lignes **et** transit pour d'autres).

### Chaîne de validation (§16 finale)

```
source officielle → ligne → arrêt → ordre de desserte → terminus
   → coordonnées → direction → affichage
```

Si la preuve manque : **UNKNOWN**. Aucune information manquante n'est complétée
par supposition.

---

## 2. Livrables

| Fichier | Rôle |
|---|---|
| `scripts/lib/ddd-aftu-terminus.mjs` | moteur de dérivation (routes, terminus, pôles, intégrité) |
| `scripts/build-ddd-aftu-terminus.mjs` | point d'entrée de génération |
| `scripts/report-ddd-aftu-terminus.mjs` | rapport de complétude §17 (`--md`) |
| `data/reference/ddd_aftu_poles_terminus.json` | référentiel généré (copie app) |
| `flutter-src/assets/data/reference/ddd_aftu_poles_terminus.json` | asset embarqué |
| `flutter-src/lib/models/terminus_pole.dart` | modèle Dart |
| `flutter-src/lib/services/terminus_catalog.dart` | chargement + filtrage (coordonnées rejetées) |
| `flutter-src/lib/main.dart` | filtre « Pôles », carte, fiche pôle |
| `tests/ddd-aftu-terminus.test.js` | tests Node |
| `flutter-src/test/ddd_aftu_terminus_test.dart` | tests Dart (référentiel + UI) |

Commandes :

```bash
npm run build:terminus     # régénère le référentiel
npm run report:terminus    # rapport texte (--md pour Markdown)
```

---

## 3. Cas UNKNOWN / CONFLICTING résolus

| Cas | Statut | Motif documentaire |
|---|---|---|
| `DDD_323` | **UNKNOWN** | `AUCUN_STOP_TIME_DANS_LE_FEED` — aucune desserte horaire : terminus non établi |
| `AFTU_47` | **UNKNOWN** | `AUCUN_STOP_TIME_DANS_LE_FEED` |
| `AFTU_52` | **UNKNOWN** | `AUCUN_STOP_TIME_DANS_LE_FEED` |
| `DDD_16` | **CONFLICTING** | libellé officiel « MALIKA ↔ PALAIS 1 », mais le feed ne dessert **jamais** Palais 1 (retour = Palais 2) : contradiction **conservée**, non arbitrée |

Aucun de ces cas n'est « complété » artificiellement.

---

## 4. Rapport final (§20)

<!-- REPORT:START -->
# Rapport de complétude DDD / AFTU / TATA


### DDD — synthèse

- lignes analysées : 53
- terminus A confirmés : 52
- terminus B confirmés : 52
- lignes UNKNOWN : 1 DDD_323
- lignes CONFLICTING : 1 DDD_16
- terminus distincts : 51

### DDD — lignes sans terminus confirmé (UNKNOWN)

- DDD_323 : AUCUN_STOP_TIME_DANS_LE_FEED

### DDD — terminus à confirmer (CONFLICTING / CANDIDATE)

- DDD_16 : TERMINUS_FEED_CONTREDIT_LIBELLE_OFFICIEL_PALAIS_1_VS_PALAIS_2

### DDD — terminus uniques alors que deux sont documentés

- (aucune)

### AFTU — synthèse

- lignes analysées : 73
- terminus A confirmés : 71
- terminus B confirmés : 71
- lignes UNKNOWN : 2 AFTU_47, AFTU_52
- lignes CONFLICTING : 0 
- terminus distincts : 94

### AFTU — lignes sans terminus confirmé (UNKNOWN)

- AFTU_47 : AUCUN_STOP_TIME_DANS_LE_FEED
- AFTU_52 : AUCUN_STOP_TIME_DANS_LE_FEED

### AFTU — terminus à confirmer (CONFLICTING / CANDIDATE)

- (aucune)

### AFTU — terminus uniques alors que deux sont documentés

- (aucune)

### TATA — associations

- associations confirmées : 0
- associations non confirmées : 0
- Aucune source officielle n'établit qu'une ligne AFTU/DDD utilise des véhicules TATA. Aucune association n'est enregistrée (voir docs/AUDIT_IDENTIFICATION_TATA_PR48_2026-09-29.md).

### Intégrité (§13) — aucun terminus par proximité

- associations pôle→ligne par proximité seule : 0
- terminus sans source : 0
- lignes à terminus unique : 0 

### Pôles (périmètre §3–§5 + découverts)

| pôle | statut | rôles | DDD terminus | AFTU terminus | coord |
|---|---|---|---|---|---|
| Gare de Petersen | CONFIRMED | TERMINUS, GARE_ROUTIERE, POLE_ECHANGE | 1 | 13 | CONFIRMED_VS_FEED |
| PEM Guédiawaye | CONFIRMED | TERMINUS, TRANSIT, GARE_ROUTIERE, POLE_ECHANGE | 3 | 0 | CONFIRMED_VS_FEED |
| Grand Médine | PARTIAL | TRANSIT, POLE_ECHANGE | 0 | 0 | UNVERIFIED |
| Gare de Colobane | CONFIRMED | TERMINUS, TRANSIT, GARE_ROUTIERE, POLE_ECHANGE | 3 | 5 | CONFIRMED_VS_FEED |
| Gare des Baux Maraîchers | CONFIRMED | TERMINUS, TRANSIT, GARE_ROUTIERE, POLE_ECHANGE | 4 | 2 | CONFIRMED_VS_FEED |
| Gare de Diamniadio | CONFIRMED | TERMINUS, TRANSIT, GARE_ROUTIERE, POLE_ECHANGE | 5 | 0 | CONFLICTING |
| Parcelles Assainies | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 5 | 5 | CONFIRMED_VS_FEED |
| Keur Massar | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 3 | 2 | CONFLICTING |
| Pikine | PARTIAL | TRANSIT, POLE_ECHANGE | 0 | 0 | UNVERIFIED |
| Thiaroye | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 3 | 0 | CONFIRMED_VS_FEED |
| Rufisque | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 4 | 2 | CONFIRMED_VS_FEED |
| Sandaga | PARTIAL | TRANSIT, POLE_ECHANGE | 0 | 0 | UNVERIFIED |
| Plateau — Terminus Leclerc | CONFIRMED | TERMINUS, POLE_ECHANGE | 7 | 0 | CONFIRMED_VS_FEED |
| Plateau — Terminus Palais 1 | CONFIRMED | TERMINUS, POLE_ECHANGE | 5 | 0 | CONFIRMED_VS_FEED |
| Plateau — Terminus Palais 2 | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 10 | 0 | CONFIRMED_VS_FEED |
| Plateau — Port de Dakar | CONFIRMED | TERMINUS, POLE_ECHANGE | 1 | 0 | CONFIRMED_VS_FEED |
| Yoff | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 0 | 5 | CONFIRMED_VS_FEED |
| Ouakam | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 0 | 1 | CONFIRMED_VS_FEED |
| Ngor | CONFIRMED | TERMINUS, TRANSIT, POLE_ECHANGE | 1 | 3 | CONFIRMED_VS_FEED |
| Mermoz | PARTIAL | TRANSIT, POLE_ECHANGE | 0 | 0 | UNVERIFIED |
| Terminus Liberté 5 | CONFIRMED | TERMINUS | 7 | 4 | CONFIRMED_VS_FEED |
| Terminus 7218 219 | CONFIRMED | TERMINUS | 6 | 0 | CONFIRMED_VS_FEED |
| Lat-Dior | CONFIRMED | TERMINUS | 1 | 5 | CONFIRMED_VS_FEED |
| AéRoport LéOpold SéDar Senghor | CONFIRMED | TERMINUS | 4 | 0 | CONFIRMED_VS_FEED |
| Terminus Daroukhane | CONFIRMED | TERMINUS | 3 | 0 | CONFIRMED_VS_FEED |
| Terminus Canberene 2 | CONFIRMED | TERMINUS | 3 | 0 | CONFIRMED_VS_FEED |
| Terminus 30 49 | CONFIRMED | TERMINUS | 0 | 3 | CONFIRMED_VS_FEED |
| Sham Terminus 32  31 | CONFIRMED | TERMINUS, TRANSIT | 0 | 3 | CONFIRMED_VS_FEED |
| Serigne Assane Terminus 36 46 70 | CONFIRMED | TERMINUS | 0 | 3 | CONFIRMED_VS_FEED |
| Terminus 37 71 | CONFIRMED | TERMINUS | 0 | 3 | CONFIRMED_VS_FEED |
| Terminus 59-39-69-80 Près De La Plage De Diamalaye | CONFIRMED | TERMINUS | 0 | 3 | CONFIRMED_VS_FEED |
| Terminus 43 Yeumbeul Nord | CONFIRMED | TERMINUS | 0 | 3 | CONFIRMED_VS_FEED |
| Terminus La LinguèRe | CONFIRMED | TERMINUS | 2 | 0 | CONFIRMED_VS_FEED |
| Gare Ter Hlm | CONFIRMED | TERMINUS | 2 | 0 | CONFIRMED_VS_FEED |
| Terminus 24 64 | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Station Ciel Oil | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 29 | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Texaco | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Serigne Assane Terminus 32 33 | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 37 50 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Pai Terminus 38 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus Grand Mbao | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 43 | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Garage Lat Dior | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 53 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Kounoune École Mbaba | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Yeumbeul | CONFIRMED | TERMINUS, TRANSIT | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus De La Ligne 73 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 74 81 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |
| Terminus 79 87 | CONFIRMED | TERMINUS | 0 | 2 | CONFIRMED_VS_FEED |

### Liste complète des terminus


**DDD** (51) : 
Aibd · AéRoport LéOpold SéDar Senghor · Aéroport Léopold Sédar Senghor · Bayakh · Croisement Keur Massar À Côté Station Senoil · Devant La Mairie De Guédiawaye · Ecole Papa Gueye Fall · Espi · Gare De Rufisque · Gare Des Baux MaraichéRs · Gare Ter De Diamniadio · Gare Ter Hlm · Grande Mosquée De Dakar · Institut De Recherche En Santé · Jardin Patte D'Oie · Lat-Dior · Lonase Dieuppeul · Mamelles · Petersen · Pharmacie La Miséricorde · Port De Dakar · Rond-Point Garage Ngor · Rond-Point Liberte 6 · Scoa · Sham · Superette · Terminus · Terminus 121 · Terminus 7218 219 · Terminus 9 Liberté 6 · Terminus Canberene 2 · Terminus Daroukhane · Terminus De La Ligne 311 · Terminus Diamalaye · Terminus Diamniadio · Terminus Gadaye · Terminus Guédiawayee · Terminus Keur Massar · Terminus La LinguèRe · Terminus Leclerc · Terminus Liberté 5 · Terminus Malika · Terminus Palais 1 · Terminus Palais 2 · Terminus Parcelles Assaines · Terminus Poste Thiaroye · Terminus Rufisque P15 · Terminus SéBikhotane · Terrain Basket Hôpital Nabil Choucair · Terrain Colobane · Tivaouane Peulh

**AFTU** (94) : 
Armurerie Coutellerie Amadou Niang · Arrêt Chérif (Rufisque Nord) · Arrêt Pa Thiaw · Bargny · Chez Lo électricien · Colobane · Delafosse Commerce · Deni Birame Ndao Nord · Devant Terminus 42 Et 44 Marché Jeudi · Diouma Ndal Dalli · Ecole Japonaise Nord Foire · En Face Angle Baye Laye · Face Brigade Nationale Des Sapeurs Pompiers Parcelle Assainies · Garage Lat Dior · Garage Ngor · Gare Des Baux MaraîChers · Gare Routiére De Colobane · Gueule Tapée Rue Gt-49 · Jaxaay 2 En Face Cabinet Médical Matlaboul Chifa I · Jaxaay 2 Pénitence · Keur Massar Terminus 61 · Kounoune École Mbaba · Lat Dior · Librairie Clairafrique · Losso · Léopold Sédar Senghor · Marche Diamegeune · Maristes Terminus 87 · Onfp Terminus 76 · Ouakam Terminus 67 · Pai Terminus 38 · Penc-Mi Boulevard Gueule Tapée · Petersen 1 · Petersen 2 · Pharmacie Elimane Aly Drame Keur Massar · Poste Courant Bargny Près De La Gare Ter · Route De Malika En Face Mairie Yeumbel Sud Et Sgbs · Rufisque Ville Devant La Boutique Orange À  Coté De La Mairie · Serigne Assane Terminus 32 33 · Serigne Assane Terminus 36 46 70 · Service D'Hygiène · Sham Terminus 32  31 · Sham Terminus 38 45 58 · Sonadis près du Jardin En Face Hôtel De Ville · Station Ciel Oil · Terminus 1 Face Keur Yoff · Terminus 24 64 · Terminus 24 En Face Ucad · Terminus 27 · Terminus 28 · Terminus 29 · Terminus 30 49 · Terminus 37 50 · Terminus 37 71 · Terminus 41 · Terminus 43 · Terminus 43 Yeumbeul Nord · Terminus 45 · Terminus 48 · Terminus 53 · Terminus 54 · Terminus 54 Pres De La Pharmacie Pascal · Terminus 55 · Terminus 57 · Terminus 59 Cité Assemblée 2 · Terminus 59-39-69-80 Près De La Plage De Diamalaye · Terminus 61 · Terminus 62 (Rufisque Nord) · Terminus 63 · Terminus 64 · Terminus 66 Et 79 · Terminus 67 · Terminus 69 · Terminus 74 81 · Terminus 75 Malika · Terminus 76 · Terminus 77 · Terminus 79 87 · Terminus 80 · Terminus 84_54Derrière Ucad En Face Canal 4 · Terminus 86 · Terminus 88 · Terminus 89 · Terminus 90 · Terminus 91 · Terminus De La Ligne 73 · Terminus Grand Mbao · Terminus Liberté 5 · Terminus Parcelles Assainies · Terminus Pénitence · Texaco · Yeumbeul · Yoff · Zone De Captage
<!-- REPORT:END -->

---

## 5. Tests et non-régression (§16, §18)

* `flutter analyze` — **No issues found**.
* `flutter test` — **709 tests OK** (dont 31 nouveaux pour ce chantier).
* `npm test` (Node) — **107 tests OK** (dont 10 nouveaux).
* `flutter build web --release --base-href /dakar-bus/` — **✓ Built build/web**.

Vérifié comme **inchangé** : TER, BRT, gares TER, stations BRT, horaires et
fréquences TER/BRT, GPS, `servedInOrder()`, calcul des minutes, fin de service,
reprise T-1h, LOT 3. Aucun fichier `ter.json` / `brt.json` / `data/gtfs/` /
`dakar_network.json` n'est modifié (`git diff` vide sur ces chemins).

---

## 6. Carte et fiches d'arrêt (§15)

Le filtre **« Pôles »** de l'écran Explorer affiche les pôles et terminus
documentés. Chaque fiche sépare explicitement :

* **Terminus (départ / arrivée)** — lignes DDD / AFTU qui commencent ou
  finissent réellement au pôle ;
* **Transit (ne terminent pas ici)** — lignes qui ne font qu'y passer ;
* **Arrêts terminus réels (feed)** — ancrage de chaque terminus ;
* **Statut** pôle et **coordonnées** (dont les contradictions conservées).

Une ligne n'est jamais présentée comme terminant à un pôle si elle ne fait
qu'y passer.
