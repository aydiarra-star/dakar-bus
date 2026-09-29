# Lot 4.16 — Préparation et audit des sources à obtenir

**Date :** 2026-09-27
**Statut du lot :** DOCUMENTAIRE UNIQUEMENT — ce document prépare les demandes ; aucun envoi n'est effectué.
**Rapport de prérequis :** `docs/AUDIT_SOURCES_ETA_4_15_2026-09-27.md` (Lot 4.15, même date)

**Rappel de l'état issu du Lot 4.15 :**

| Réseau | État |
|---|---|
| TER | ETA défendable sous conditions — terminus uniquement |
| BRT B1 | ETA non défendable actuellement |
| BRT B2 | ETA non défendable actuellement |
| BRT B3 | ETA non défendable actuellement |
| DDD | Source actuelle à obtenir |
| AFTU | Source actuelle à obtenir |

Flux GTFS-RT réel identifiés : **0**. Retards établis : **0**. Interruptions établies : **0**.

---

## 1. Objectif

L'objectif de ces demandes est d'obtenir, pour chaque réseau, les données qui permettent de relier **un passage réel à une station, à un sens et à un jour/daté**, afin de calculer ensuite une attente du type 🟢 X min — et uniquement lorsqu'une preuve réelle existe : 🟡 X min (retard établi) ou 🔴 Indisponible (interruption documentée).

Deux chaînes de données sont visées :

**Chaîne statique (horaire daté) :**

```
route → trip → service → stop → direction → heure
```

**Chaîne temps réel (prédiction) :**

```
route → stop → timestamp → predicted_time
```

Sans au moins l'une de ces deux chaînes, il n'existe pas de source d'ETA défendable :

- une **fréquence** (« toutes les 6 min ») n'est **pas** un prochain passage : elle ne donne ni la phase du premier passage dans la journée, ni le sens, ni la station ;
- un **horaire théorique non daté** (sans date de validité ni service) ne permet pas de savoir s'il est encore en vigueur ;
- un **contenu web ou PDF** (plan de lignes, images, listes d'arrêts) ne contient pas de temps exploitable.

Chaque demande ci-dessous vise donc un objet précis : soit une grille `gare/station × sens × jour × heure` avec date de validité, soit un GTFS statique complet, soit un flux temps réel documenté (endpoint, protocole, auth, champs, fraîcheur).

**Périmètre strict de ce lot :**

- NE PAS modifier l'application.
- NE PAS modifier les données transit (`data/transit/`, `data/gtfs/`).
- NE PAS créer d'horaires, de GTFS, de GTFS-RT, de trips ni de stop_times.
- NE PAS simuler de temps réel.
- NE PAS committer, pousser ni merger.
- NE PAS contacter réellement les opérateurs (voir §10).

---

## 2. TER / SETER

**Source cible :** SETER (Société d'Exploitation des Transports du TER — opérateur), via les canaux officiels `terdakar.sn` / `sentersa.sn` / application TER INFOS.
**État au 4.15 :** ancrages terminus défendables sous conditions (Dakar lun–sam + dim/férié, Diamniadio lun–sam ; sources E1 `terdakar.sn` et application TER INFOS lancée le 29/07/2025) ; grille intermédiaire non défendable ; fréquences en conflit entre sources (terdakar 10 min dès 05:45 vs sentersa 10 min 05:30–21h, page image ≈ 01/2022) ; aucun flux public identifié ; domaine `api.ter.sn` non résolu (NXDOMAIN).

### A. GTFS statique actuel

Demander si SETER peut fournir un GTFS statique complet :

| Fichier GTFS | Contenu demandé |
|---|---|
| `agency.txt` | Identité opérateur, nom officiel, URL, fuseau |
| `routes.txt` | route_id stables, nom officiel, route_short/long_name |
| `trips.txt` | trip_id, route_id, direction_id, service_id |
| `stops.txt` | stop_id stables (toutes les gares), nom, coordonnées |
| `stop_times.txt` | trip_id, stop_id, stop_sequence, arrival_time, departure_time |
| `calendar.txt` | service_id, jours de la semaine actifs |
| `calendar_dates.txt` | exceptions datées (fériés, suppressions) |
| `frequencies.txt` | si — et seulement si — des fréquences sont publiées avec un trip de référence |
| `shapes.txt` | tracé des itinéraires |

Avec, obligatoirement :

- **date de validité** du jeu de données (validity period) ;
- **date de dernière mise à jour** ;
- **version du réseau** (versioning / release) ;
- **sens** : chaque trip doit être relié à `direction_id` explicite (sens voyageur, pas seulement aller/retour déduit des coordonnées) ;
- **identifiants stables** : `route_id`, `trip_id`, `stop_id`, `service_id` réutilisables d'une version à l'autre (sinon toute mise à jour casserait les références).

### B. Temps réel

Demander si un flux temps réel existe :

- **GTFS-RT** (VehiclePosition, TripUpdate/StopTimeUpdate, ServiceAlert) ;
- **API** propriétaire (JSON/REST) ;
- **SAE** (système d'aide à l'exploitation) avec accès externe documenté.

Si oui, demander :

| Catégorie | Champs demandés |
|---|---|
| Accès | URL / end-point, protocole (HTTP, protobuf, WebSocket…), authentification (clé, OAuth…), fréquence de mise à jour, conditions d'usage |
| Identification | `trip_id`, `route_id`, `stop_id`, `stop_sequence` |
| Temps | `timestamp` (horodatage serveur), `predicted_time` (heure prédite), `delay` (retard, si exposé) |

Si non : demander de le confirmer explicitement (« aucun flux actuellement ») — cette réponse documente elle-même l'ABSENCE DE DONNÉE (distincte d'un retard et d'une interruption).

### C. Grille horaire (minimum acceptable)

Si aucun GTFS n'est disponible, demander au minimum une grille :

```
gare × sens × jour (lun, mar, … , dim/férié) × heure de passage
```

avec **date de validité** de la grille.

**IMPORTANT :** ne pas demander uniquement « les horaires du TER ». La donnée doit permettre de relier un passage à **une gare précise** et **à un sens précis**. Une grille globale « Dakar–Diamniadio toutes les 10 min » sans phase (heure de départ réelle du premier passage, par gare et par sens) ne permet aucun calcul d'ETA.

**Question à poser telle quelle :**

> « Existe-t-il, pour chaque gare et chaque sens, une heure de passage de référence (premier passage daté) permettant de calculer les passages successifs, avec la date de validité de cette grille ? »

---

## 3. BRT B1 / B2 — SunuBRT / opérateur BRT / CETUD

**Source cible :** opérateur BRT (SunuBRT) et/ou CETUD.
**État au 4.15 :** fréquence B1 6 min (06:00–21:00, renforts de pointe Petersen↔Grand Médine) et B2 6 min (lun–sam) publiées sur `sunubrt.sn` ; aucune heure de départ/référence par station ni par sens ; aucun flux temps réel ; domaine `api.sunubrt.sn` NXDOMAIN ; app SunuBRT sans API publique documentée.

**Demander séparément B1 et B2.** Une station physique partagée ne fusionne pas deux lignes : chaque requête garde son propre `route_id`.

### Option 1 — Structure horaire (statique)

Pour **chacune** de B1 et de B2 :

| Champ | Détail |
|---|---|
| `route_id` | identifiant officiel stable de la ligne |
| `nom officiel` | intitulé public exact (BRT 1 / BRT 2) |
| `direction_id` | sens 0/1 ou équivalent explicite |
| stations | liste officielle des stations |
| `stop_id` | identifiant stable par station |
| ordre des stations | `stop_sequence` par direction |
| horaires par station | heure d'arrivée/départ à chaque station, **par sens** |
| jours de service | service_id / jours actifs + fériés |
| date de validité | période de validité + date de dernière mise à jour |

### Option 2 — Flux temps réel

Un flux temps réel avec : `route_id`, `trip_id`, `stop_id`, `stop_sequence`, `timestamp`, `predicted_time`, `delay`.

**IMPORTANT : la fréquence « 6 minutes » ne suffit pas.** Demander explicitement :

> « Existe-t-il une heure de départ ou un passage de référence permettant de calculer les passages successifs à une station et dans un sens précis ? »

- **Si oui** : demander la source exacte (fichier, page, API, tableau, PDF daté), son auteur, sa date de publication et sa date de validité.
- **Si non** : **ne pas convertir la fréquence en ETA**. La réponse documente l'ABSENCE DE DONNÉE ; aucun « prochain bus dans 6 min » ne peut en être déduit.

---

## 4. BRT B3

**Source cible :** opérateur BRT (SunuBRT)/CETUD.
**État au 4.15 :** B3 = ligne `NEW` (lancée oct. 2025), statut `UNCONFIRMED` ; stations officielles publiées (site : service pointe lun–ven 07–11h / 16–20h, 7 stations) ; **non exposée** dans `dakar_network.json` (avec `candidate_stop_ids` à confirmer) ; aucune horaire par station ; `route_status` = schedule UNKNOWN.

**Demander une source distincte de B1/B2**, couvrant :

| Champ | Détail |
|---|---|
| identité officielle | nom public exact de la ligne BRT 3 |
| `route_id` | identifiant officiel stable |
| origine / destination | terminus officiels |
| stations | liste officielle complète |
| `stop_id` | identifiant stable par station |
| direction | sens explicite, applicable à chaque station |
| ordre des stations | `stop_sequence` par direction |
| horaires | grille station × sens × jour (si disponible) |
| date de validité | période de validité + date de mise à jour |
| fréquence éventuelle | avec la **question de la phase** (voir ci-dessous) |
| temps réel éventuel | GTFS-RT / API / afficheur, avec les mêmes champs que §3 option 2 |

**Question de phase obligatoire** (même formulation que §3) : heure de départ/passage de référence par station et par sens, ou confirmation d'absence.

**IMPORTANT :** ne **jamais** déduire B3 depuis B1/B2 — ni identité, ni stations, ni fréquence, ni horaires. Si l'opérateur confirme une source B3, elle est traitée comme un jeu de données indépendant (`route_id` propre, validation propre).

---

## 5. DDD — Dakar Dem Dikk

**Source cible :** Dakar Dem Dikk (opérateur) et/ou CETUD.
**État au 4.15 :** site `demdikk.sn/info-voyageurs` = listes de lignes + premiers/derniers départs seulement (pas de grille) ; `demdikk.sn/horaires/` = 404 ; bouton CETUD « Télécharger les lignes et horaires » = image JPEG ; PassBi DDD (53 routes/1 277 stops/9 529 trips) = historique 2022–2023 avec licence absente (republication bloquée) ; SAEIV/CCO (inauguré, presse 07/2026) = géolocalisation **interne** ; `api.dakardemdikk.sn` / `api.cetud.sn` NXDOMAIN.

### A. GTFS actuel

Au minimum :

| Fichier | Contenu |
|---|---|
| `routes.txt` | toutes les lignes DDD, route_id stables |
| `trips.txt` | trip_id, direction_id, service_id |
| `stops.txt` | arrêts avec stop_id stables |
| `stop_times.txt` | heures par trip × arrêt × stop_sequence |
| `calendar.txt` | jours de service |
| `calendar_dates.txt` | exceptions datées |

avec **date de validité** et date de dernière mise à jour.

### B. Temps réel (SAEIV / CCO)

Demander si le SAEIV/CCO dispose d'une **API ou d'un flux externe** accessible aux tiers.

Si oui :

- endpoint ; protocole ; authentification ;
- fréquence de rafraîchissement ;
- véhicule / trip / ligne / direction ;
- prochain arrêt ; `timestamp` ; ETA ; retard.

**IMPORTANT :** le SAEIV interne **ne doit pas être présenté comme une source accessible** tant qu'un accès externe n'est pas confirmé par écrit. Tant que cet accès n'est pas confirmé, la case « temps réel » de ce rapport reste ABSENCE DE DONNÉE (pas un retard, pas une interruption), exactement comme au 4.15.

**Question à poser telle quelle :**

> « Le centre de contrôle SAEIV expose-t-il une API publique ou un flux GTFS-RT/GTFS-Flex documenté pour les horaires et positions des véhicules ? Si oui, quelles sont l'URL, l'authentification et les conditions d'accès ? »

---

## 6. AFTU — Alliance des Fédérations de Transport Urbain du Sénégal

**Source cible :** AFTU et/ou CETUD.
**État au 4.15 :** site AFTU = identité des lignes + « Voir itinéraire » (carte) ; **aucun horaire, aucune fréquence, aucun temps réel** ; PassBi AFTU = 73 routes / 2 401 stops / 11 077 trips mais historique 2022-01-01→2023-12-31 (non réutilisable comme horaires 2026) + licence absente ; numérotation divergente (83+ sur le site vs 72 lignes CETUD/PassBi) ; `api.*` NXDOMAIN ; aucun GTFS AFTU public (mobilitydatabase : aucun flux Sénégal).

Demander :

| Objet | Détail |
|---|---|
| GTFS actuel | `routes.txt`, `trips.txt`, `stops.txt`, `stop_times.txt`, `calendar.txt`, `calendar_dates.txt` |
| liste officielle des lignes | numérotation courante, libellés officiels, correspondance public ↔ interne |
| directions | `direction_id` explicite par trip |
| dates de validité | valid_from / valid_to + date de dernière mise à jour |
| fréquence officielle datée (éventuel) | uniquement avec heure de référence (phase) par station/sens et date de validité |
| temps réel (éventuel) | API / SAE, avec les mêmes champs que §5 B |
| licence | conditions de réutilisation / licence du jeu de données |

**IMPORTANT :** ne **jamais** reconstruire les horaires à partir des numéros de lignes, de la destination, de la géométrie, d'OSM ou d'une fréquence seule. Si l'AFTU/CETUD ne fournit aucune donnée horaire datée, la réponse est documentée en ABSENCE DE DONNÉE et l'ETA reste non défendable (état inchangé : SOURCE À OBTENIR).

---

## 7. Schéma minimal commun

Toute donnée reçue — statique ou temps réel — doit être rattachable au modèle commun suivant avant toute intégration :

| # | Champ | Rôle | Statique | Temps réel |
|---|---|---|---|---|
| 1 | `route_id` | identifie la ligne | requis | requis |
| 2 | `trip_id` | identifie le passage (voyage) | requis | requis (ou déduit du GTFS statique lié) |
| 3 | `service_id` | identifie les jours de service | requis | — (dérivé de service_date) |
| 4 | `stop_id` | identifie la station/gare | requis | requis (ou position exploitable) |
| 5 | `stop_sequence` | ordre de la station dans le trip | requis | requis si présent dans le flux |
| 6 | `direction_id` | sens du voyage | requis | requis (ou déduit du trip) |
| 7 | `service_date` | jour de circulation considéré | requis | requis (date à laquelle s'applique la prédiction) |
| 8 | `scheduled_time` | heure théorique prévue | requis | requis si le flux ou le GTFS statique la fournit |
| 9 | `predicted_time` | heure prédite/réelle | — | requis |
| 10 | `timestamp` | horodatage de l'événement/prédiction | — | requis (obligatoire) |
| 11 | `delay` | écart prévu (si exposé par la source) | — | si disponible |
| 12 | `source` | identifiant de la source (URL, fichier, contact, ticket) | requis | requis |
| 13 | `source_type` | `static_schedule` \| `gtfs_static` \| `gtfs_realtime` \| `operator_api` \| `absence` | requis | requis |
| 14 | `date_verified` | date de vérification de la source (ISO) | requis | requis |
| 15 | `valid_from` / `valid_to` | période de validité de la donnée | requis | requis (sinon : fraîcheur non mesurable) |

Chaînes complétées par ce schéma :

- statique : `route → trip → service → stop → direction → heure` → 🟢 X min ;
- temps réel : `route → stop → timestamp → predicted_time` → 🟢 (ou 🟡 si `delay` est une preuve de retard) ;
- aucune des deux chaînes complétable → ⚪ ABSENCE DE DONNÉE (jamais transformée en retard ni en interruption, jamais comblée par une fréquence ou une simulation).

---

## 8. Critères d'acceptation

### 8.1 Toute donnée (statique ou non)

Une donnée ne pourra être intégrée que si **tous** ces critères sont satisfaits :

1. **source identifiable** — émetteur connu (SETER, SunuBRT, DDD, AFTU, CETUD) ;
2. **provenance documentée** — URL/ticket/contact, date de récupération, empreinte ou version du fichier si possible ;
3. **date de validité connue** — `valid_from`/`valid_to` explicites ou déductibles du document ;
4. **route identifiable** — `route_id` ou correspondance 1:1 non ambiguë vers une route du réseau ;
5. **station identifiable** — `stop_id` ou gare/station nommée de façon non ambiguë ;
6. **direction identifiable** — sens explicite (`direction_id` ou libellé aller/retour non déduit de la géométrie seule) ;
7. **temps identifiable** — heure de passage rattachée à une station, un sens et un jour ;
8. **absence d'invention** — aucun temps reconstruit, interpolé, moyenné, déduit d'une fréquence, d'un n° de ligne, d'une géométrie, d'OSM ou d'une source tierce non vérifiée ;
9. **cohérence réseau vérifiée** — les identifiants reçus se relient entre eux sans référence orpheline (route → trips → stop_times → stops), sans chevauchement de sens impossible, sans contradiction frontière avec les autres sources du dépôt.

### 8.2 Données temps réel (en plus)

10. **`timestamp` présent** — horodatage serveur exploitable (ISO 8601 ou epoch) ;
11. **fraîcheur mesurable** — `now − timestamp` calculable ; délai connu entre événement terrain et publication ;
12. **trip/route identifiable** — `trip_id` (ou équivalent) et `route_id` dans le message ;
13. **stop ou position exploitable** — `stop_id`/`stop_sequence` ou position véhicule suffisante pour rattacher le passage à une station ;
14. **prédiction ou événement temporel exploitable** — `predicted_time`, `delay` ou événement équivalent daté (un simple message d'alerte sans temps ne produit pas d'ETA).

**Règles immuables :**

- Une donnée rejetée sur l'un de ces critères n'est **pas** intégrée telle quelle ; elle est documentée (critère manquant) et l'état du réseau reste inchangé ;
- un flux ne respectant pas ces critères n'est jamais présenté comme « temps réel » ;
- aucun mock, aucune donnée simulée ne peut satisfaire ces critères (leur `source_type` est `absence`).

---

## 9. Matrice

| Réseau | Donnée demandée | Source cible | Priorité | Peut produire ETA ? |
|---|---|---|---|---|
| TER | grille gare×sens×jour / GTFS | SETER | Haute | Oui sous conditions |
| BRT B1 | grille station×sens / RT | SunuBRT/CETUD | Haute | Oui |
| BRT B2 | grille station×sens / RT | SunuBRT/CETUD | Haute | Oui |
| BRT B3 | identité + grille / RT | SunuBRT/CETUD | Haute | Oui si obtenu |
| DDD | GTFS actuel / SAEIV | DDD/CETUD | Haute | Oui si obtenu |
| AFTU | GTFS actuel / données horaires | AFTU/CETUD | Haute | Oui si obtenu |

Lecture :

- « Oui sous conditions » (TER) = l'ancrage par terminus est déjà défendable ; la grille intermédiaire ou le GTFS-RT l'étendrait à toutes les gares ;
- « Oui » (B1/B2) = conditionnée à l'obtention d'une **heure de référence** (phase) par station et par sens — jamais à la seule fréquence ;
- « Oui si obtenu » (B3/DDD/AFTU) = aucun objet de chaîne statique ni temps réel n'est encore disponible aujourd'hui.

---

## 10. Ne pas envoyer automatiquement

**Ce lot prépare les demandes uniquement.**

- Ne **pas** contacter réellement les opérateurs depuis le dépôt.
- Ne **pas** utiliser e-mail, formulaire web, API de contact ou tout autre service externe sans instruction explicite du demandeur.
- Les formulaires ci-dessus sont des **cahiers des charges de demande** : à envoyer manuellement, avec les coordonnées du porteur de projet, lorsqu'un envoi sera explicitement demandé.
- Aucun compte, jeton, destinataire ou identifiants de contact ne sont créés ou stockés dans ce dépôt.

---

## 11. Validation (après création du document)

Exécuté à la création de ce document (résultats rapportés dans le canal de travail, hors dépôt) :

- `npm test` — suite de tests repository ;
- `node scripts/check-arrets.js` — **peut refléter l'état historique du checkout utilisé pour l'audit 4.15** ; ses erreurs ne sont **pas** corrigées dans ce lot ;
- `git diff --check`, `git status`, `git diff --stat`, `git diff` — preuve qu'aucune donnée transport n'est modifiée (aucune correction pour obtenir un PASS artificiel).

**Aucune donnée transport ne doit être modifiée pour obtenir un PASS artificiel.**

---

## 12. Protection

Confirmations du périmètre — **aucune** des opérations suivantes n'est réalisée par ce lot :

- [x] `data/transit/` inchangé
- [x] `data/gtfs/` inchangé
- [x] `dakar_network.json` inchangé
- [x] Flutter fonctionnel inchangé (application, service, calculateur d'ETA, présentation)
- [x] GPS inchangé
- [x] PositionValidity inchangé
- [x] cartographie inchangée
- [x] polylines inchangées
- [x] aucun horaire ajouté
- [x] aucun trip ajouté
- [x] aucun stop_time ajouté
- [x] aucun GTFS-RT créé
- [x] aucun mock transformé en donnée réelle

**Aucun commit. Aucun push. Aucun merge.**
