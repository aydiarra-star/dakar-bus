# LOT 4.1 — Audit de la source horaire TER (27/09/2026)

**Objet** : déterminer, preuves à l'appui, quelles données TER peuvent devenir
`SCHEDULED`, lesquelles doivent rester `ESTIMATED` ou `UNKNOWN`.

**Périmètre** : lecture seule. Aucun horaire intégré, aucun modèle ajouté,
`main.dart` / interface / GPS / routage non touchés, `ScheduleProvider` inchangé.

**Décision rendue en fin de document : `NOT_READY_FOR_SCHEDULE_IMPORT`.**

---

## 1. Contexte vérifié

| Fait | Valeur vérifiée | Source |
|---|---|---|
| Mise en service commerciale Diamniadio–AIBD | **lundi 28/09/2026** | communiqué MITTA repris par Pressafrik, Senegal7, laviesenegalaise, Xibaaru, senego, seneplus, SENTV (24–26/09/2026) |
| Longueur de la section nouvelle | ~19 km | idem |
| Tronçon existant | Dakar–Diamniadio, 36 km, service commercial depuis le 27/12/2021 | SENTV 26/09/2026 |
| Durée Dakar–AIBD annoncée | **55 minutes** (presse 2026) — **45 minutes** (page projet APIX) | senego 24/09/2026 ; investinsenegal.sn |
| Communes traversées par la phase 2 | Diamniadio, Sébikotane, Keur Moussa | PAR APIX ; SENTV |

> **Conflit n°1 — durée** : 55 min (presse, sept. 2026) contre 45 min (page
> projet APIX, non datée). Aucune des deux valeurs n'est un horaire exploitable.

---

## 2. Sources consultées

Toutes consultées le **27/09/2026**.

### Sources opérateur / institutionnelles

| # | Source | Ce qu'elle fournit réellement |
|---|---|---|
| S1 | `terdakar.sn/les_horaires_des_trains/` | **Fréquences uniquement** : « toutes les 10 minutes du lundi au samedi de 5H35 (départ de Diamniadio) et 5H45 (départ de Dakar) à 20H55, et toutes les 20 min de 21h05 à 22h05 dernier départ » ; « toutes les 20 minutes, le dimanche et les jours fériés de 6h25 à 22h05 ». Plus un module dynamique « Par ligne / Par commune / Rechercher » sans grille publiée. **Aucune mention de l'AIBD.** |
| S2 | `terdakar.sn/` (accueil) | Module horaire identique ; « INFO TRAFIC : Trafic normal sur le réseau ». **Aucune annonce AIBD.** |
| S3 | `terdakar.sn/l-actualite-du-reseau/` | Dernière actualité : **30/03/2026**. Le seul article mentionnant l'AIBD date du **18/05/2022** (« En attendant l'extension du TER vers AIBD… », navettes bus DDD). |
| S4 | `sentersa.sn/plan-de-transport/` | **Fréquences différentes de S1** : « toutes les 10 minutes du lundi au samedi de 5H30 à 21H, et toutes les 20 min de 21h à 22h » ; « toutes les 20 minutes, le dimanche et les jours fériés de 6h30 à 22h ». Liste de gares **antérieure à la phase 2** (« Une quatorzième gare est prévue à l'aéroport Blaise Diagne »). Image datocms d'horodatage 20/01/2022. |
| S5 | `sentersa.sn/le-ter-phase-2/` | **Page vide** : seul le fil d'Ariane est restitué, aucun contenu exploitable. |
| S6 | `investinsenegal.sn/grand_travaux/train-express-regional/` (APIX) | 55 km, 45 min, 13 gares + 14ᵉ à l'AIBD en fin de phase 2, 6 trains/heure. |
| S7 | **PAR APIX** — `investinsenegal.sn/wp-content/uploads/2023/08/Projet-TER-DAKAR-Diamniadio-AIBD-–-Phase-2.pdf` | **Source la plus précise sur la topologie** : « **Deux gares sont prévues dans le projet** au niveau de l'AIBD, gare terminus et de Sébikotane ». Keur Moussa est une **commune traversée sur 10,6 km**, pas une gare. |
| S8 | APS, 20/06/2026 | Lancement des travaux de la gare de Sébikotane ; le chef de l'État « a instruit les services concernés, notamment la Senter, … de mettre en place une **halte provisoire** avant l'achèvement de l'ouvrage de la gare ». |
| S9 | Le Soleil / allAfrica, 22/06/2026 | DG SENTER (Cheikh Ibrahima Ndiaye) : « le Ter desservira, à terme, **14 gares**, auxquelles viendra s'ajouter celle de Sébikotane actuellement en construction ». Tarif Dakar–AIBD 4 000 FCFA. |
| S10 | SENTV, 22/06/2026 | DG SENTER : parc porté à 22 rames ; fréquence Dakar–Diamniadio de 10 min → **8 min** ; « **une partie des trains poursuivra ensuite son trajet jusqu'à l'AIBD** ». Tarif Dakar–Sébikotane maintenu à 1 500 FCFA. |

### Sources tierces (non retenues comme preuve)

| # | Source | Note |
|---|---|---|
| T1 | `au-senegal.com`, 22/09/2026 | **« Les tarifs et horaires restent à confirmer officiellement. »** Confirme l'absence de grille publiée. |
| T2 | `ilove-senegal.com`, 24/09/2026 et 05/07/2026 | Tarifs détaillés (4 000 / 7 500 FCFA ; abonnement 85 000 / 125 000). Écrit « samedi 28 septembre » alors que le 28/09/2026 est un **lundi** → fiabilité insuffisante. |
| T3 | `senego.com`, 24–25/09/2026 | 55 min ; précise : « **Les horaires et tarifs de la nouvelle desserte sont consultables dans les gares et sur les canaux officiels.** » |
| T4 | Wikipedia | 13 gares, phase 2 « annoncée pour mi 2026 » → non à jour. |
| T5 | `ter-senegal.sn`, `safarisenegal.com`, `senego.com/services/horaires-brt-ter` | Listes d'arrêts **contradictoires** (12 arrêts, ou 8 arrêts) et fréquences fantaisistes (« 15 à 20 min en pointe, 30 à 45 min en creuse »). **À écarter.** |

---

## 3. Tableau obligatoire

| Élément | Résultat | Source | Date | Statut |
|---|---|---|---|---|
| **Dakar → AIBD** | Aucune grille horaire publiée. Seule la durée (~55 min) et l'existence du service sont annoncées. Horaires « consultables dans les gares et sur les canaux officiels » | MITTA via presse (T3) ; aucun horaire sur S1–S5 | 24–26/09/2026 | **UNKNOWN** |
| **AIBD → Dakar** | Idem — aucune heure de départ publiée | idem | 24–26/09/2026 | **UNKNOWN** |
| **Dakar → Diamniadio** | Fréquence seule : 10 min (L–S, 5H45→20H55) puis 20 min (21H05→22H05) selon S1 ; 10 min (5H30→21H) puis 20 min selon S4. **Aucune heure de passage par gare** | S1 (terdakar.sn) / S4 (sentersa.sn) — **valeurs divergentes** | 27/09/2026 | **ESTIMATED** (fréquence sourcée opérateur) — **jamais SCHEDULED** |
| **Diamniadio → Dakar** | Fréquence seule, premier départ 5H35 de Diamniadio (S1) | S1 | 27/09/2026 | **ESTIMATED** |
| **Dimanche** | Fréquence seule : 20 min de 6h25 à 22h05 (S1) / de 6h30 à 22h (S4). Aucune heure exacte | S1 / S4 — **divergent** | 27/09/2026 | **ESTIMATED** |
| **Jours fériés** | Assimilés au dimanche par S1 et S4 (« le dimanche et les jours fériés »), mais **aucun calendrier de service, aucune liste de dates** publiée | S1 / S4 | 27/09/2026 | **UNKNOWN** pour toute date donnée |
| **Gares intermédiaires phase 2** | **Deux gares prévues : AIBD (terminus) et Sébikotane.** Keur Moussa = commune traversée (10,6 km), **pas une gare**. Sébikotane : gare en travaux au 20/06/2026, « halte provisoire » instruite sans document d'exploitation publié | S7 (PAR APIX) ; S8 (APS) ; S9 (DG SENTER) | 2023 / 20–22/06/2026 | **AIBD : CONFIRMED** · **Sébikotane : indéterminé à l'ouverture** · **Keur Moussa : non** |
| **Temps réel** | **Aucun flux.** `api.ter.sn` (porté par `server/.env`) **ne résout pas en DNS**, alors que `terdakar.sn` résout. Aucun GTFS-RT, aucune API, aucun SAE documenté | Test DNS 27/09/2026 ; `server/.env:19` | 27/09/2026 | **UNKNOWN — aucun flux à connecter** |

---

## 4. Topologie : ce qui est établi, ce qui ne l'est pas

### Établi par source institutionnelle

- **13 gares** en service sur Dakar–Diamniadio (S4, S6, S9).
- **AIBD** = 14ᵉ gare, terminus de la phase 2 (S6, S7, S9). **C'est la seule gare nouvelle dont l'existence soit documentée par l'opérateur/le maître d'ouvrage.**
- **Sébikotane** : gare prévue par le PAR (S7), travaux lancés le 20/06/2026 (S8), « à terme » selon le DG SENTER (S9), avec une **halte provisoire** instruite pour l'ouverture. **Aucun document d'exploitation ne dit si elle est desservie le 28/09/2026.**
- **Keur Moussa** : commune traversée, **aucune gare** dans le PAR (S7).

### Non établi — refus de déduction

- **Aucun ordre exact des arrêts phase 2** n'est publié (Diamniadio → ? → AIBD).
- **Aucune identification des circulations partielles** : S10 indique seulement qu'« une partie des trains » poursuivra jusqu'à l'AIBD. Sans cette information, aucun `trip_id` ni `direction_id` ne peut être construit.
- **Aucune nouvelle halte intermédiaire** ne peut être ajoutée : ni carte, ni OSM, ni le fait que Sébikotane et Keur Moussa soient des communes traversées ne constituent une preuve de desserte.

### Conflit préexistant sur les 13 gares (non résolu par ce lot)

| Variante | Liste |
|---|---|
| **Application** (`dakar_network.json`, route `ter_dakar_diamniadio`) | Dakar, Colobane, Hann, **Dalifort**, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, **Keur Mbaye Fall**, PNR, Rufisque, Bargny, Diamniadio |
| **S4 (sentersa.sn, texte)** | Dakar, Colobane, Hann, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, **Keur Massar**, **Mbao**, PNR, Rufisque, Bargny, Diamniadio |
| **au-senegal (2024)** | … Yeumbeul, **Keur Mbaye Fall**, **Mbao**, PNR … |

> Trois variantes incompatibles (Dalifort / Keur Massar / Mbao / Keur Mbaye Fall).
> L'audit du 24/09 (`docs/AUDIT_DONNEES_2026-09-24.md`, l. 83) tranche en faveur de
> la carte uMap 556411 publiée par SETER : **ni Keur Massar ni Mbao**. Ce conflit
> est signalé, **non rouvert** ici.

---

## 5. Temps réel — vérification explicite

Le dépôt contient `server/.env` **et** `server/.env.example` (tous deux **committés**),
ligne 19 :

```
TER_API_URL=https://api.ter.sn/gtfs-rt
```

Vérification DNS du 27/09/2026 :

| Hôte | Résolution |
|---|---|
| `api.ter.sn` | **INEXISTANT** — `Name or service not known` |
| `api.cetud.sn` | **INEXISTANT** |
| `api.sunubrt.sn` | **INEXISTANT** |
| `api.dakardemdikk.sn` | **INEXISTANT** |
| `terdakar.sn` | 48.222.250.113 ✅ |
| `www.terdakar.sn` | 172.67.203.148 ✅ |

**Conclusion** : les quatre endpoints GTFS-RT du fichier `.env` pointent vers des
domaines qui n'existent pas. Ce sont des URL aspirées d'un mock, **pas des flux
d'opérateur**. Conformément à la consigne, cette seule présence ne vaut pas preuve
— elle est ici **réfutée**. Aucun endpoint n'est connecté, aucun `REAL_TIME` créé.

*Note d'hygiène annexe (hors périmètre, signalée) : `server/.env` est suivi par
git. Il ne contient aucun secret, seulement des URL, mais un `.env` committé est
une mauvaise pratique à corriger dans un lot dédié.*

---

## 6. Données explicitement écartées

| Donnée | Statut | Vérification dans le dépôt |
|---|---|---|
| `data/gtfs/` (GTFS local) | **Écarté** — feed synthétique | `feed_info.txt` : `feed_version = 2.1-dakar-pwa-gtfs-rt` ; `calendar.txt` : `TER_DAILY` 20260101–20261231 ; `routes.txt` : `TER_01 … "TER 13 gares officielles"` ; `stops.txt` : `TER_01_Dakar` … `TER_13_Diamniadio`, **aucune gare AIBD**. Horaires ronds synthétiques. |
| Horaires PDF SETER d'octobre 2022 | **Écarté** — référence historique uniquement | Non présents dans le dépôt ; non importés. |
| Anciennes listes de minutes | **Écarté** | `schedule_status = UNKNOWN` sur `ter_dakar_diamniadio` dans `dakar_network.json` (vérifié). |
| Fréquences seules | **Non convertibles en `SCHEDULED`** | Voir §3 — c'est pourtant la seule donnée opérateur disponible. |
| Sites tiers sans provenance opérateur | **Écarté** | T5 : listes d'arrêts contradictoires. |
| Extrapolation fréquence → heures de gare | **Interdite et non réalisée** | Aucun `scheduledTime` fabriqué. |

---

## 7. Pourquoi `SCHEDULED` est impossible aujourd'hui

Pour émettre un `StopTime` `SCHEDULED`, le moteur du Lot 3 exige
(`flutter-src/lib/models/schedule_models.dart`, `ScheduleProvenance`) :
`source`, `source_type`, `date_source`, `date_verified`, `valid_from`, `valid_to`,
une `ScheduleCoverage` explicite, puis par `StopTime` : `trip_id`, `stop_id`,
`stop_sequence`, `arrival_time`, `departure_time`.

État réel au 27/09/2026 :

| Champ requis | Disponible ? |
|---|---|
| `source` / `source_type` | Non — aucun document horaire officiel daté |
| `date_source` / `date_verified` | Non — S1 et S4 ne portent **aucune date d'entrée en vigueur** |
| `valid_from` / `valid_to` | Non — aucune période de validité publiée |
| `ScheduleCoverage` | Non — dessertes partielles non publiées (S10) |
| `trip_id` | Non — aucun identifiant de circulation publié |
| `stop_sequence` phase 2 | Non — ordre Diamniadio→AIBD non publié |
| `arrival_time` / `departure_time` | **Non — aucune heure par gare publiée** |

**Zéro des sept familles de champs n'est satisfait.**

---

## 8. Décision

# `NOT_READY_FOR_SCHEDULE_IMPORT`

**Motif** : aucune grille horaire actuelle, complète et sourcée opérateur n'existe
au 27/09/2026. Les deux sites officiels ne publient que des **fréquences**,
mutuellement divergentes, sans date d'entrée en vigueur. Le site de l'opérateur
n'annonce même pas encore l'ouverture du 28/09. Une source tierce (T1) confirme
explicitement que « les tarifs et horaires restent à confirmer officiellement ».

### `source_status = insufficient`

### Conséquences techniques appliquées

- **Aucune injection dans `ScheduleProvider`** : `EmptyScheduleProvider` reste le
  provider par défaut (`dataset => null`), inchangé.
- **`TER exact next departure` reste `UNKNOWN`** : `schedule_status = UNKNOWN` sur
  `ter_dakar_diamniadio` dans `dakar_network.json`, inchangé.
- **Aucun fichier de code modifié par ce lot.** Aucun modèle de provenance ajouté :
  `ScheduleProvenance` / `ScheduleCoverage` / `ScheduleDataset` du Lot 3 couvrent
  déjà le besoin ; en ajouter sans source réelle serait de la spéculation.
- **Aucun test de parsing ajouté** : la consigne ne l'autorise que « si une source
  réelle est effectivement obtenue ». Ce n'est pas le cas.
- Protections du Lot 3 intactes (`scheduleStatusOf` → `UNKNOWN`, validation de
  cohérence `stop_sequence`, refus `REAL_TIME` sans flux).

### Ce que la fréquence autorise — et n'autorise pas

La fréquence **est** publiée par l'opérateur (S1, S4). Elle autorise donc un statut
`ESTIMATED` **si et seulement si** un lot dédié le décide, avec :

- la source exacte et sa date de consultation ;
- le traitement explicite du **conflit S1 ≠ S4** (5H35/5H45→20H55 vs 5H30→21H) ;
- l'absence de `scheduledTime` (interdit) ;
- une `valid_to` courte, la grille devant être revalidée après le 28/09/2026.

**Ce lot ne l'implémente pas** : la consigne interdit de « changer les statuts
UNKNOWN actuels sans nouvelle preuve ».

---

## 9. Conditions de déblocage

Pour passer à `READY_FOR_SCHEDULE_IMPORT`, il faut obtenir **au moins** :

1. Une **grille horaire officielle datée** (PDF ou page) indiquant les heures de
   passage **par gare**, dans les deux sens, avec date d'entrée en vigueur —
   publiée par SETER/TER Dakar, SENTER, le MITTA ou APIX.
2. Le **statut de desserte de Sébikotane** au 28/09/2026 (gare définitive, halte
   provisoire, ou non desservie).
3. L'**ordre exact des arrêts** Diamniadio → AIBD et le schéma des
   **circulations partielles** (quels trains vont jusqu'à l'AIBD).
4. Le **calendrier de service** : jours de circulation, dimanche, jours fériés,
   période transitoire éventuelle autour du 28/09/2026.

À défaut, la seule évolution défendable est une **fréquence `ESTIMATED`**
soigneusement sourcée — jamais `SCHEDULED`.

---

## 10. Séparation données nouvelles / données historiques

| Catégorie | Contenu | Usage autorisé |
|---|---|---|
| **Nouveau (2026)** | Ouverture Diamniadio–AIBD le 28/09/2026 ; 19 km ; gare AIBD ; gare de Sébikotane (travaux) ; 22 rames ; fréquence cible 8 min ; tarifs annoncés 4 000 / 7 500 FCFA | Information de contexte uniquement. **Aucune heure exploitable.** |
| **Historique** | PDF SETER octobre 2022 ; page `sentersa.sn/plan-de-transport/` (contenu et image de janvier 2022, liste de gares pré-phase 2) ; article `terdakar.sn` du 18/05/2022 sur les navettes DDD ; GTFS synthétique `data/gtfs/` (feed_version `2.1-dakar-pwa-gtfs-rt`) | **Référence historique seulement. Interdits comme `SCHEDULED`.** |
| **Ni l'un ni l'autre** | Sites tiers (T5) aux listes d'arrêts contradictoires | **Écartés.** |
