# Groupe 13 — Recherche et Qualification des Sources Officielles Externes

**Date :** 2026-09-22  
**Branche :** arena/01a0c8f1-dakar-bus  
**HEAD Groupe 12 :** c54e95bcb06022f9ebbe1446f57f0e5a60695e2c  
**Type de mission :** Audit documentaire uniquement, pas de développement fonctionnel  
**Objectif :** Déterminer quelles données officielles sont exploitables pour TER / BRT / AFTU / Tata / DDD : réseau statique, arrêts, lignes, itinéraires, horaires programmés, calendrier, fréquences, perturbations, positions, ETA, départs temps réel, alertes, GTFS, GTFS-RT, API officielles, autres formats.

**Règle d'or :** Classer chaque source OFFICIAL / VERIFIED / UNKNOWN / REJECTED. Ne jamais intégrer de données plausibles sans preuve.

---

## 1. Introduction et Méthodologie

### Périmètre
- Types de données recherchées : GTFS statique (agency, stops, routes, trips, stop_times, calendar, calendar_dates, frequencies, shapes, feed_info), GTFS-RT (VehiclePositions, TripUpdates, ServiceAlerts protobuf), API officielles JSON, autres formats (NeTEx, SIRI).
- Réseaux : TER Dakar (SETER), BRT SunuBRT (Dakar Mobilité), Dakar Dem Dikk (DDD), AFTU, Tata (type minibus).

### Méthode d'investigation (Phases 1-8)
1. Recherche web `CETUD observatoire systeme de donnees GTFS Dakar`
2. Fetch `https://cetud.sn/observatoire/systeme-de-donnees/` chunks 0-2
3. Recherche `site:cetud.sn GTFS`, `CETUD GTFS zip download`
4. Recherche `CETUD Dakar GTFS download site:transport.data.gouv.fr OR data.gouv.fr`
5. Recherche `TER Dakar SETER API horaires GTFS`
6. Recherche `BRT Dakar SunuBRT API GTFS-RT`
7. Recherche `Dakar Dem Dikk GTFS API CAPTRANS`
8. Recherche `AFTU Dakar API GTFS`
9. Recherche `open data Senegal transport GTFS data.gouv.sn`
10. Recherche `Tata bus Dakar GTFS API`
11. Recherche `MobilityData GTFS Senegal Dakar feed`
12. Recherche `CETUD contact observatoire`
13. Fetch `https://www.sunubrt.sn/`, `https://www.terdakar.sn/les_horaires_des_trains`, `https://cetud.sn/observatoire/indicateurs-de-la-mobilite/`

**Outils :** web_search depth 2-3, fetch_page, vérification portails open data, vérification MobilityDatabase.org, transport.data.gouv.fr (NAP France), data.gouv.fr, senegal.opendataforafrica.org, senegalouvert.github.io.

### Classification utilisée
- **OFFICIAL** : Source autorité organisatrice (CETUD, SETER, DDD, AFTU, Dakar Mobilité) avec preuve URL officielle documentée, clé API valide, feed signé, documentation import, ou page officielle listant téléchargement direct.
- **VERIFIED** : Source OFFICIAL vérifiée terrain / croisée avec plusieurs sources officielles, ou données recoupées avec référence-policy.
- **UNKNOWN** : Provenance non établie, non utilisable comme source horaire officielle (local file sans URL, URL sans clé, agrégation tierce).
- **REJECTED** : Source non pertinente, hors périmètre Dakar, placeholder vide, mock, fallback Suisse, ou présentée comme officielle sans preuve.

---

## 2. CETUD — Système de données (Phase 1) — Questions A-D

### Source principale auditée
- URL : `https://cetud.sn/observatoire/systeme-de-donnees/`
- Titre : Système de données — Observatoire de la mobilité
- Contenu confirmé (chunks 0-1) :
  > - **Données de trafic** : comptages, EMD, O/D, données mobiles SONATEL anonymisées
  > - **DONNÉES D'EXPLOITATION HORS SAE** via CAPTRANS pour AFTU/DDD : remontées exploitation, régulation GIE
  > - **SYSTÈME D'AIDE À L'EXPLOITATION SAE** : suivi temps réel bus équipés
  > - **FICHIER GTFS** : numérisation réseau, horaires, arrêts, itinéraires, trajet, tarifs, services pour opendata / app mobile

**Analyse : CETUD dispose bien d'un GTFS interne et d'un SAE temps réel, mais la page est descriptive, pas distributive.**

#### QUESTION A — Le GTFS est-il publiquement téléchargeable ?
**Réponse : NON trouvé.**
- Recherche `site:cetud.sn GTFS` → seul résultat = page système de données, aucun lien `.zip`
- Recherche `CETUD GTFS zip download` → aucun résultat Dakar, uniquement TUMI, France
- Navigation sous-domaines : `api.cetud.sn` mentionné dans `server/.env` mais pas résolvable publiquement sans clé, pas de portail développeur public listé sur cetud.sn
- Vérification footer/contact : pas de section "Open Data" avec téléchargement

#### QUESTION B — Existe-t-il une URL directe .zip ?
**Réponse : Aucune URL directe trouvée.**
- Pas de `https://cetud.sn/.../gtfs.zip`
- Pas de `https://cetud.sn/.../dakar.gtfs.zip`
- Pas de `stops.txt`, `routes.txt` direct
- Recherche `transport.data.gouv.fr` avec "Senegal Dakar" → 0 résultat Dakar, uniquement réseaux français (Arc-en-ciel, CarSud, etc.)
- Recherche `data.gouv.fr` GTFS Dakar → 0
- Conclusion : **Pas de lien public GTFS Dakar**

#### QUESTION C — Existe-t-il un GTFS-RT (VehiclePositions / TripUpdates / ServiceAlerts) protobuf exploitable ?
**Réponse : NON accessible publiquement.**
- Dans `server/.env` :
  ```
  CETUD_VEHICLE_POSITIONS_URL=https://api.cetud.sn/gtfs-rt/vehiclePositions
  CETUD_TRIP_UPDATES_URL=https://api.cetud.sn/gtfs-rt/tripUpdates
  CETUD_ALERTS_URL=https://api.cetud.sn/gtfs-rt/alerts
  CETUD_API_KEY= (vide)
  USE_MOCK=true
  ```
- Aucune clé, aucun test protobuf réussi documenté
- `server/server.js` fallback mock 127 bus si pas de clé
- Recherche web GTFS-RT CETUD → 0 flux protobuf public
- Conclusion : URLs supposées existent en config mais **non vérifiables sans convention**, statut **UNKNOWN**, pas **OFFICIAL**

#### QUESTION D — Procédure d'accès si non public ?
**Réponse : Demande officielle nécessaire.**
- Organisme : CETUD — Conseil Exécutif des Transports Urbains Durables
- Service : Observatoire de la mobilité
- Page : https://cetud.sn/observatoire/systeme-de-donnees/ + https://cetud.sn/contact/
- Email : `observatoire@cetud.sn`, `cetud@cetud.sn` (confirmé via web_search contact)
- Téléphone : `+221 33 859 47 20` / `33 828 92 91`
- Adresse : Route du Front de Terre, Hann, Dakar
- Type de demande : convention de partenariat / accès open data GTFS statique + GTFS-RT SAE + CAPTRANS, clé API portail développeur, format souhaité (GTFS zip + GTFS-RT protobuf JSON proxy), usage PWA Dakar Bus, non commercial, attribution CETUD.

---

## 3. Contact Officiel (Phase 2)

| Champ | Valeur |
|-------|--------|
| Organisme | CETUD — Conseil Exécutif des Transports Urbains Durables |
| Service | Observatoire de la mobilité |
| Page système données | https://cetud.sn/observatoire/systeme-de-donnees/ |
| Page indicateurs | https://cetud.sn/observatoire/indicateurs-de-la-mobilite/ |
| Email observatoire | observatoire@cetud.sn |
| Email générique | cetud@cetud.sn |
| Téléphone | 33 859 47 20 / 33 828 92 91 |
| Adresse | Route du Front de Terre, Hann, Dakar, Sénégal |
| Type de demande | Accès GTFS statique officiel + GTFS-RT SAE temps réel + données CAPTRANS AFTU/DDD, clé API, convention |
| Pièces à fournir | Lettre motivation projet Dakar Bus PWA, usage non commercial, attribution, volume requêtes estimé, contact technique |
| Statut contact | À demander — aucune réponse automatique avec GTFS obtenue lors de l'audit |

**Classification contact : OFFICIAL** (source institutionnelle vérifiée), mais **données associées = À DEMANDER**, pas encore utilisables.

---

## 4. TER / SETER (Phase 3)

### Sources auditées
- `https://www.terdakar.sn/` : site officiel SETER
- `https://www.terdakar.sn/les_horaires_des_trains` : horaires HTML statiques
- `https://www.terdakar.sn/plan-de-transport/` (sentersa.sn) : plan transport fréquence 10 min 5h30-21h, 20 min dimanche, tarifs 500-1500F
- Wikipedia TER Dakar
- Recherche `TER Dakar SETER API horaires GTFS` → résultats uniquement SNCF TER France `export-ter-gtfs-last.zip` (France), pas Dakar
- `api.ter.sn/gtfs-rt` dans `.env` → aucune preuve existence, DNS non vérifiable

### Données trouvées
- **Réseau statique** : 14 gares listées publiquement (Dakar, Colobane, Hann, Dalifort, Beaux Maraichers, Thiaroye, Yeumbeul, Keur Mbaye Fall, Mbao, Rufisque, Bargny, Diamniadio, AIBD via bus)
- **Arrêts** : Oui en HTML, mais pas de GTFS stops.txt officiel téléchargeable
- **Lignes** : 1 ligne principale Dakar-Diamniadio + navette Diamniadio-AIBD bus
- **Itinéraires** : Oui descriptif
- **Horaires programmés** : Oui HTML "toutes les 10 minutes lundi-samedi 5h30-21h, 20 min 21h-22h, 20 min dimanche", mais pas de fichier GTFS stop_times
- **Calendrier** : Lundi-samedi vs dimanche/jours fériés
- **Fréquences** : 10 min / 20 min affichées
- **Perturbations / Alertes** : Page actualités, pas de ServiceAlerts GTFS-RT
- **Positions temps réel** : Aucune API publique
- **ETA / départs temps réel** : Aucun
- **GTFS** : Non trouvé public
- **GTFS-RT** : Non trouvé
- **API officielle** : Non trouvée

### Classification TER
- `terdakar.sn` horaires HTML : **UNKNOWN** (information voyageur, pas GTFS officiel, pas traçable comme source horaire programmée pour repository)
- `api.ter.sn/gtfs-rt` : **UNKNOWN** (URL supposée dans .env, aucune preuve, pas de clé, pas de test)
- `data/gtfs/stops.txt` 13 gares TER : **UNKNOWN** (local, pas preuve SETER)
- `data/gtfs/stop_times.txt` TER 3 trips 4 min réguliers : **REJECTED comme officiel** (pattern démo)

**Conclusion TER : Aucune source OFFICIAL / VERIFIED exploitable directement. À demander via CETUD + SETER.**

---

## 5. BRT / Dakar Mobilité / SunuBRT (Phase 4)

### Sources auditées
- `https://www.sunubrt.sn/` fetch chunk 0-1
- `https://www.sunubrt.sn/mon-trajet-en-brt/horaires-et-frequences/`
- `https://www.sunubrt.sn/mon-trajet-en-brt/horaires-et-arrets/`
- `https://www.sunubrt.sn/cartes-et-itineraires/carte-interactive/`
- Wikipedia Sunu BRT : 18.3 km, 23 stations, lignes B1/B2/B3/B4
- Recherche `BRT Dakar SunuBRT API GTFS-RT` → aucun API, uniquement site vitrine
- `api.sunubrt.sn/gtfs-rt` dans .env → non vérifiable

### Données trouvées
- **Réseau statique** : Oui descriptif B1 Omnibus toutes stations, B2 Semi Express 7 stations, B3 pointe, B4 Express
- **Arrêts** : 23 stations listées (Papa Gueye Fall Petersen, Grande Mosquée, Place Nation Obélisque, Dial Diop 1/2, Grand Dakar, Liberté 1, Sacré-Cœur, Liberté 5/6, Khar Yallah, Scat Urbam, Cardinal Hyacinthe Thiandoum, Grand Médine PEM, Police Parcelles, Croisement 22, Parcelles Assainies, Fith Mith, Ndingala Golf Sud, Dalal Jam Hôpital, Golf Nord, Gadaye Cambérène, Préfecture Guédiawaye PEM)
- **Lignes** : B1/B2/B3/B4
- **Itinéraires** : Oui plan interactif Leaflet mais pas GTFS shapes officiel téléchargeable
- **Horaires** : "6h-21h fréquence 6 min" en texte, pas de stop_times officiel
- **Calendrier** : 7j/7, horaires guichet 6h-21h, site 24/7
- **Fréquences** : 6 min B1, renfort pointe Petersen-Grand Médine 6h-10h et 16h-20h
- **Perturbations** : Actualités site, pas GTFS-RT
- **Positions** : PCC (Poste Commandement Centralisé) interne Dakar Mobilité, CRC, billettique, mais pas d'API tierce publique
- **ETA** : Calculateur itinéraire A→B sur site (probablement interne, pas API documentée)
- **GTFS** : Non trouvé public
- **GTFS-RT** : Non trouvé public
- **API** : `serviceclient@sunubrt.sn`, tel `818 55 55 55`, mais pas d'API développeur

### Classification BRT
- `sunubrt.sn` site officiel : **OFFICIAL comme source institutionnelle**, mais **UNKNOWN comme source GTFS/API** (pas de feed téléchargeable)
- `api.sunubrt.sn/gtfs-rt` : **UNKNOWN**
- `data/gtfs/stops.txt` 23 BRT : **UNKNOWN**
- `data/gtfs/stop_times.txt` BRT 2 min réguliers : **REJECTED**

**Conclusion BRT : Aucune source GTFS/GTFS-RT OFFICIAL téléchargeable. Données internes Dakar Mobilité PCC non ouvertes. À demander via CETUD + Dakar Mobilité.**

---

## 6. DDD / CAPTRANS (Phase 5)

### Sources auditées
- `https://www.dakardemdikk.com/` (via senegalouvert)
- `busmaps.com/en/senegal/public_transit-agency-Dakar-Dem-Dikk` : mention GTFS `drk-nam` via pipeline qualité tierce, website cetud.sn, non source primaire
- Moovit DDD : 45 routes, 1086 stops, temps réel app
- Recherche `Dakar Dem Dikk GTFS API CAPTRANS` → CAPTRANS = Centre d'Appui à la Professionnalisation des Transports, Support Centre Professionalization, mutuelle, régulation GIE, pas API
- `api.dakardemdikk.sn/gtfs-rt` dans .env → non vérifiable

### Données trouvées
- **Réseau statique DDD** : 46 lignes environ (selon Moovit/busmaps)
- **Arrêts** : 1086 via Moovit, mais agrégation tierce non officielle
- **Lignes** : DDD 10, 07, 12, 23, etc.
- **Itinéraires** : Oui via Moovit/busmaps mais non officiel
- **Horaires** : Non trouvés officiels, fréquences variables
- **GTFS** : Aucun GTFS officiel DDD téléchargeable sur site DDD ou CETUD
- **GTFS-RT** : Aucun
- **CAPTRANS** : Système interne pour AFTU/DDD, collecte données exploitation hors SAE, mais pas d'API tierce publique documentée. Rôle : professionnalisation, régulation, formation, pas diffusion open data.

### Classification DDD/CAPTRANS
- `dakardemdikk.com` : **OFFICIAL institutionnel** mais **UNKNOWN GTFS**
- `busmaps.com DDD GTFS drk-nam` : **UNKNOWN** (agrégation tierce, validation pipeline, pas preuve CETUD)
- Moovit DDD 45 routes : **UNKNOWN** (agrégation app, non officiel)
- `api.dakardemdikk.sn` : **UNKNOWN**
- CAPTRANS comme API publique : **REJECTED** (c'est un centre appui, pas une API)

**Conclusion DDD : Pas de GTFS/GTFS-RT officiel public. À demander via CETUD + DDD.**

---

## 7. AFTU (Phase 6)

### Sources auditées
- Recherche `AFTU Dakar API GTFS`
- Moovit AFTU : 64 routes, 1634 stops, temps réel app
- transitrun.com, piaafrica.org contact AFTU
- `data/gtfs/routes.txt` : 60+ lignes AFTU 01-73

### Données trouvées
- **Réseau** : AFTU dense, 64 lignes, 1634 arrêts selon Moovit (agrégation)
- **GTFS officiel** : Aucun trouvé public
- **API** : Aucune
- **Horaires** : Fréquences variables, pas de GTFS officiel

### Classification AFTU
- Moovit AFTU : **UNKNOWN**
- `data/gtfs/routes.txt` AFTU : **UNKNOWN**
- Aucune source **OFFICIAL** GTFS/GTFS-RT

**Conclusion AFTU : Aucune source officielle exploitable directement. À demander via CETUD + AFTU GIE.**

---

## 8. Tata (Phase 7)

### Sources auditées
- Recherche `Tata bus Dakar GTFS API`
- Contexte : Tata = marque constructeur minibus (Tata Motors) utilisé par AFTU/DDD, pas réseau distinct
- `data/gtfs/routes.txt` : TATA 01/02

### Données trouvées
- **Réseau distinct Tata** : Non, c'est un type véhicule, pas un réseau avec GTFS propre
- **GTFS** : Aucun
- **API** : Aucune

### Classification Tata
- Tata comme réseau : **UNKNOWN** (pas de réseau officiel distinct)
- `data/gtfs/routes.txt` TATA : **UNKNOWN** (local)

**Conclusion Tata : Pas de source officielle distincte. Assimilé à AFTU/DDD.**

---

## 9. Portails Open Data (Phase 8)

### Portails vérifiés
| Portail | URL testée | Résultat Dakar GTFS |
|---------|------------|---------------------|
| CETUD site | https://cetud.sn/ | Page système données mention GTFS mais pas de download |
| transport.data.gouv.fr (NAP France) | https://transport.data.gouv.fr | 0 résultat Dakar, uniquement France (Arc-en-ciel, CarSud, etc.) |
| data.gouv.fr | https://www.data.gouv.fr | 0 GTFS Dakar |
| MobilityDatabase.org | https://mobilitydatabase.org | Feed `DAKK GTFS tfs-625` trouvé, mais bounding box unable, validation not available, dates 2023-2024, source TransitFeeds, pas officiel CETUD, statut **UNKNOWN** |
| Senegal Data Portal (ANS D) | https://senegal.opendataforafrica.org/ | Uniquement stats accidents transport routier 2004-2016 via MITTD, pas GTFS |
| senegalouvert.github.io | https://senegalouvert.github.io/ | Liste sources ANSD, demdikk.com, mais pas GTFS |
| data.gouv.sn (supposé) | recherche | Aucun dataset GTFS Dakar vérifié |
| dakartransitsenegal.online | mention via search | Agrégateur non officiel, pas source primaire |

### Classification Open Data
- MobilityDatabase DAKK GTFS tfs-625 : **UNKNOWN** (feed existant mais pas officiel, pas validé, obsolète, pas de preuve CETUD)
- Tous autres portails : **0 source OFFICIAL/VERIFIED GTFS Dakar**

**Conclusion Open Data : Aucun dataset GTFS Dakar vérifié en open data public sans demande.**

---

## 10. Vérification GTFS Statique (Phase 9)

### Fichiers requis GTFS
`agency.txt, stops.txt, routes.txt, trips.txt, stop_times.txt, calendar.txt, calendar_dates.txt, frequencies.txt, shapes.txt, feed_info.txt`

### Audit local `data/gtfs/`

| Fichier | Présent | Contenu | Validité | Source officielle ? |
|---------|---------|---------|----------|---------------------|
| agency.txt | Oui | 5 agences CETUD, DDD, BRT, TER, AFTU URLs génériques | Format valide | NON — URLs génériques, pas preuve |
| stops.txt | Oui | 42 arrêts = 13 TER + 23 BRT + 6 pôles bus, lat/lon Dakar | Format valide, coordonnées plausibles | NON — local, pas URL officielle |
| routes.txt | Oui | 76 routes BRT 01, DDD, TATA, TER, AFTU | Format valide | NON — local |
| trips.txt | Oui | 146 trips BRT/TER/AFTU/DDD | Format valide | NON — local |
| stop_times.txt | Oui | 108 lignes, 3 trips BRT 06:00/07:00/12:00 intervalles 2min exacts, 3 trips TER 4min exacts | Format valide mais pattern démo | **NON — REJECTED comme officiel** |
| calendar.txt | Oui | WEEKDAY, WEEKEND, DAILY, BRT_DAILY, TER_DAILY | Format valide | NON |
| calendar_dates.txt | Non | Absent | - | - |
| frequencies.txt | Non | Absent | - | - |
| shapes.txt | Oui | Tracés BRT/TER | Format valide | NON |
| feed_info.txt | Oui | CETUD Dakar Mobilité, https://cetud.sn, contact@cetud.sn, version 2.1-dakar-pwa-gtfs-rt | Métadonnées mais pas preuve feed | NON — mention CETUD mais sans signature |

### Vérifications spécifiques
- **agency** : pas de feed signé, pas de clé
- **stops** : 42 arrêts cohérents carte mais pas vérifiés terrain avec source officielle SETER/SunuBRT
- **routes** : 76 routes mais pas de preuve AFTU/DDD
- **trips/stop_times** : pattern régulier suspect (2 min BRT, 4 min TER) caractéristique démo, seulement 3 départs/jour, pas de journée complète, pas de variations
- **calendar** : basique, pas de jours fériés Sénégal spécifiques
- **Aucun fichier GTFS officiel téléchargé depuis CETUD** : tout est local

### Classification GTFS statique
- `data/gtfs/*` local : **UNKNOWN** pour tous, **REJECTED** pour stop_times comme source officielle horaire
- GTFS officiel CETUD mentionné page système données : **À DEMANDER**, pas accessible publiquement

**Conclusion GTFS statique : Aucun GTFS officiel accessible sans demande. Local = démo non officielle.**

---

## 11. Vérification GTFS-RT (Phase 10)

### Feeds GTFS-RT attendus
- VehiclePositions : positions bus temps réel
- TripUpdates : ETA, retards, départs temps réel
- ServiceAlerts : perturbations, alertes

### URLs auditées (depuis server/.env)

| Feed | URL config | Clé | Test | Résultat |
|------|-----------|-----|------|----------|
| CETUD VehiclePositions | https://api.cetud.sn/gtfs-rt/vehiclePositions | vide | USE_MOCK=true, fallback mock 127 bus | UNKNOWN, pas OFFICIAL |
| CETUD TripUpdates | https://api.cetud.sn/gtfs-rt/tripUpdates | vide | non testé succès | UNKNOWN |
| CETUD Alerts | https://api.cetud.sn/gtfs-rt/alerts | vide | non testé | UNKNOWN |
| DDD API | https://api.dakardemdikk.sn/gtfs-rt | aucune | jamais utilisée server.js | UNKNOWN |
| BRT API | https://api.sunubrt.sn/gtfs-rt | aucune | jamais utilisée | UNKNOWN |
| TER API | https://api.ter.sn/gtfs-rt | aucune | jamais utilisée | UNKNOWN |
| api/gtfs-rt placeholder | local api/gtfs-rt | aucune | {"entity":[]} | UNKNOWN |
| GTFSRTClient mock | inline index.html | aucune | setInterval 3s interpolation | UNKNOWN simulation |
| FALLBACK Swiss | https://api.opentransportdata.swiss/... | aucune | Suisse, pas Dakar | REJECTED |

### Vérification protobuf
- Aucun flux protobuf GTFS-RT Dakar réel démontré
- `server/server.js` proxy convertit protobuf → JSON mais en mode MOCK car pas de clé
- Pas de validation `FeedMessage` avec timestamp réel Dakar

### Classification GTFS-RT
- Tous feeds listés : **UNKNOWN** sauf FALLBACK Swiss **REJECTED**
- Aucun **OFFICIAL/VERIFIED** GTFS-RT accessible

**Conclusion GTFS-RT : Aucun flux temps réel officiel accessible publiquement. À demander via CETUD.**

---

## 12. Tableau Temps Réel (Phase 11) et Classification Finale (Phase 12)

### Tableau temps réel par réseau

| Réseau | Horaires programmés | Positions temps réel | ETA / départs temps réel | Alertes / perturbations | GTFS statique officiel | GTFS-RT officiel | API officielle | Source à contacter |
|--------|---------------------|----------------------|--------------------------|-------------------------|------------------------|------------------|----------------|-------------------|
| TER | UNKNOWN — HTML 10min existe mais pas GTFS | UNKNOWN — SAE existe interne mais pas API publique | UNKNOWN | UNKNOWN — actualités site, pas ServiceAlerts | UNKNOWN — mention CETUD mais pas téléchargeable | UNKNOWN — URL supposée sans clé | NON | observatoire@cetud.sn + SETER |
| BRT | UNKNOWN — texte 6min mais pas GTFS | UNKNOWN — PCC interne Dakar Mobilité | UNKNOWN — calculateur A→B interne non API | UNKNOWN — actualités | UNKNOWN | UNKNOWN | NON | observatoire@cetud.sn + serviceclient@sunubrt.sn 818 55 55 55 |
| DDD | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN — busmaps drk-nam tierce | UNKNOWN | NON | observatoire@cetud.sn + DDD |
| AFTU | UNKNOWN — 64 lignes Moovit tierce | UNKNOWN | UNKNOWN — Moovit app temps réel mais agrégation non officielle | UNKNOWN | UNKNOWN — Moovit 64 routes non officiel | UNKNOWN | NON | observatoire@cetud.sn + AFTU |
| Tata | UNKNOWN — type véhicule, pas réseau | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | NON | observatoire@cetud.sn |

**Légende :** UNKNOWN = non vérifiable comme source officielle, pas utilisable pour horaires temps réel sans convention.

### Classification finale

#### SOURCES UTILISABLES (OFFICIAL / VERIFIED) : 0
- Aucune source GTFS statique officielle téléchargeable publiquement
- Aucune API GTFS-RT officielle avec clé valide et flux protobuf Dakar vérifié
- Aucune source horaire programmée officielle vérifiable

#### SOURCES À DEMANDER (via procédure officielle)
| Source | Organisme | Données attendues | Procédure |
|--------|-----------|-------------------|-----------|
| GTFS statique Dakar complet | CETUD Observatoire | agency, stops (42+), routes (76+), trips, stop_times réels, calendar, shapes, feed_info | Email observatoire@cetud.sn + cetud@cetud.sn, tel 33 859 47 20, convention |
| GTFS-RT VehiclePositions | CETUD SAE | Positions bus BRT/TER/DDD/AFTU temps réel | Demande clé API api.cetud.sn/gtfs-rt/vehiclePositions |
| GTFS-RT TripUpdates | CETUD SAE | ETA, retards, départs temps réel | Clé API api.cetud.sn/gtfs-rt/tripUpdates |
| GTFS-RT ServiceAlerts | CETUD | Perturbations, alertes | Clé API api.cetud.sn/gtfs-rt/alerts |
| CAPTRANS exploitation | CETUD / AFTU GIE | Données exploitation hors SAE AFTU/DDD | Demande via CETUD + AFTU |
| TER horaires officiels | SETER / CETUD | GTFS TER ou API | Demande via terdakar.sn + CETUD |
| BRT horaires / API | Dakar Mobilité / CETUD | GTFS BRT + API PCC | Demande via serviceclient@sunubrt.sn + CETUD |

#### SOURCES UNKNOWN (11 sources — non utilisables comme officielles)
| Source | Réseau | Type | URL / Local | Raison UNKNOWN |
|--------|--------|------|-------------|---------------|
| data/gtfs/stop_times.txt | TER,BRT | GTFS static local | local | Pattern démo 2min/4min, 3 trips, pas preuve officielle |
| data/gtfs/stops.txt | ALL | GTFS arrêts | local | 42 arrêts plausibles mais pas preuve SETER/SunuBRT |
| data/gtfs/routes.txt | ALL | GTFS routes | local | 76 lignes mais pas preuve AFTU/DDD |
| CETUD VehiclePositions | ALL | GTFS-RT API supposée | https://api.cetud.sn/gtfs-rt/vehiclePositions | Clé vide, USE_MOCK, pas test protobuf réel |
| CETUD TripUpdates | ALL | GTFS-RT API | https://api.cetud.sn/gtfs-rt/tripUpdates | Idem |
| CETUD Alerts | ALL | GTFS-RT API | https://api.cetud.sn/gtfs-rt/alerts | Idem |
| DDD API | DDD | API supposée | https://api.dakardemdikk.sn/gtfs-rt | Aucune preuve existence |
| BRT API | BRT | API supposée | https://api.sunubrt.sn/gtfs-rt | Aucune preuve |
| TER API | TER | API supposée | https://api.ter.sn/gtfs-rt | Aucune preuve |
| api/gtfs-rt placeholder | ALL | JSON placeholder | local api/gtfs-rt | {"entity":[]} vide |
| GTFSRTClient mock | ALL | Simulation JS | inline index.html | setInterval 3s interpolation, pas temps réel réel |

#### SOURCES REJECTED (à ne pas utiliser)
| Source | Raison rejet |
|--------|--------------|
| FALLBACK Swiss opentransportdata.swiss | Données Suisse, pas Dakar |
| busmaps.com DDD GTFS drk-nam | Agrégation tierce, validation pipeline, pas source primaire officielle, website cetud.sn mentionné mais pas preuve feed officiel |
| Moovit DDD 45 routes 1086 stops / AFTU 64 routes 1634 stops | Agrégation app tierce, temps réel Moovit mais non officiel CETUD, pas traçable |
| dakartransitsenegal.online | Agrégateur non officiel |
| data/gtfs/stop_times.txt comme source officielle horaire | REJECTED explicitement Groupe 12 TEST H : provenance non documentée, pattern démo, OFFICIAL_SOURCE=false |
| Tata comme réseau distinct | REJECTED — Tata = marque minibus, pas réseau GTFS distinct |

---

## 13. Recommandations, Procédure de Demande Officielle et Non-Régression

### 13.1 Procédure de demande officielle CETUD

**Objet email :** Demande d'accès GTFS statique et GTFS-RT SAE pour projet Dakar Bus PWA — recherche académique / mobilité urbaine

**Destinataires :**
- observatoire@cetud.sn (prioritaire)
- cetud@cetud.sn
- CC : serviceclient@sunubrt.sn, contact SETER via terdakar.sn

**Contenu type :**
```
Madame, Monsieur,

Dans le cadre du projet Dakar Bus PWA (mobilité urbaine temps réel : TER, BRT, DDD, AFTU),
nous avons identifié via votre page https://cetud.sn/observatoire/systeme-de-donnees/
que le CETUD dispose d'un fichier GTFS (numérisation réseau, horaires, arrêts, itinéraires)
et d'un SAE temps réel.

Nous souhaiterions obtenir :
- GTFS statique officiel Dakar (zip) : agency, stops, routes, trips, stop_times, calendar, shapes, feed_info
- Accès GTFS-RT : VehiclePositions, TripUpdates, ServiceAlerts (protobuf) ou JSON proxy
- Données CAPTRANS pour AFTU/DDD si disponibles
- Clé API api.cetud.sn/gtfs-rt/* et documentation

Usage : PWA non commerciale, attribution CETUD, cache 30s, respect vie privée.
Volume estimé : < 1000 req/jour.

Merci d'indiquer procédure convention / partenariat et format disponible.

Cordialement,
[Nom projet Dakar Bus]
```

**Téléphone relance :** 33 859 47 20 / 33 828 92 91

### 13.2 Ne modifier aucune donnée Dakar Bus (Phase 13)

Conformément à la consigne Groupe 13 :

- ❌ Aucun horaire modifié dans `data/gtfs/`
- ❌ Aucun GTFS créé ou présenté comme officiel
- ❌ Aucune API mock promue en officielle
- ❌ Aucune UI modifiée (couleurs, navigation, cartes conservées)
- ❌ Aucune donnée inventée (pas de Date.now()+X, pas de 5 min arbitraire)
- ✅ Uniquement audit documentaire, classification OFFICIAL/VERIFIED/UNKNOWN/REJECTED
- ✅ Conservation `UnavailableScheduleRepository` qui retourne `[]` et `Horaire non disponible` tant qu'aucune source OFFICIAL n'est obtenue

### 13.3 Livrable

- **Fichier :** `docs/dakar-bus/groupe-13/SOURCES_OFFICIELLES.md` (ce fichier)
- **13 sections** : Introduction, CETUD Questions A-D, Contact officiel, TER, BRT, DDD/CAPTRANS, AFTU, Tata, Open Data, GTFS statique, GTFS-RT, Tableaux + Classification, Recommandations + Non-régression
- **Preuves :** URLs fetchées, recherches web listées, tableaux vérification
- **Tests :** `npm test` sans régression attendu 42 PASS (Groupe 11 + 12 + transit-validation)

### 13.4 Tests et Git

**Avant commit :**
```bash
npm test
# attendu : 42 PASS / 0 FAIL (10 schedule.test.js + 8 groupe12.test.js + 24 transit-validation.test.js)
```

**Git :**
```bash
git add docs/dakar-bus/groupe-13/SOURCES_OFFICIELLES.md
git commit -m "docs: Groupe 13 audit sources officielles CETUD/TER/BRT/DDD/AFTU/Tata - 0 OFFICIAL accessible, procédure demande officielle"
git push origin arena/01a0c8f1-dakar-bus
```

**Important :** Ne committer que le doc Groupe 13, pas de modification fonctionnelle GTFS/API/UI.

---

## Annexes — Preuves de recherche

### Recherche web exécutée (résumés)
- CETUD observatoire systeme de donnees GTFS Dakar → page confirme GTFS interne + SAE + CAPTRANS, pas de download
- site:cetud.sn GTFS → seul résultat page système données
- CETUD GTFS zip download → aucun zip public
- transport.data.gouv.fr Senegal Dakar GTFS → 0 Dakar, uniquement France
- TER Dakar SETER API → SNCF France GTFS France uniquement, sentersa.sn horaires HTML 10min, pas API Dakar
- BRT Dakar SunuBRT API → sunubrt.sn vitrine, horaires 6min texte, PCC interne, pas API
- DDD GTFS CAPTRANS → busmaps drk-nam tierce, Moovit 45 routes, CAPTRANS = centre professionnalisation non API
- AFTU API GTFS → Moovit 64 routes 1634 stops agrégation non officielle
- open data Senegal transport GTFS → Senegal Data Portal accidents seulement, pas GTFS
- Tata bus Dakar GTFS → marque bus, pas réseau
- MobilityData Senegal Dakar → DAKK GTFS tfs-625 mais bounding box unable, validation not available, obsolète 2023-2024
- CETUD contact observatoire → observatoire@cetud.sn +221 33 859 47 20

### Pages fetchées
- https://cetud.sn/observatoire/systeme-de-donnees/ (3 chunks) : confirme GTFS, SAE, CAPTRANS, mais pas de lien download
- https://www.sunubrt.sn/ : confirme 6 min fréquence, B1/B2/B3, Dakar Mobilité, PCC, serviceclient@sunubrt.sn 818 55 55 55, pas API
- https://www.terdakar.sn/ : confirme horaires 10 min HTML, pas GTFS

### Fichiers locaux audités
- data/gtfs/stop_times.txt : 109 lignes (header + 108), pattern démo 2min BRT / 4min TER, 3 trips chaque sens, OFFICIAL_SOURCE=false
- data/gtfs/stops.txt : 42 arrêts
- data/gtfs/routes.txt : 76 routes
- server/.env : URLs CETUD api.cetud.sn/gtfs-rt/* clé vide USE_MOCK=true
- js/services/sourceAudit.js : 11 UNKNOWN list

---

**Conclusion Groupe 13 :**

- **GTFS officiel Dakar téléchargeable publiquement ? NON**
- **URL directe .zip ? Aucune**
- **GTFS-RT VehiclePositions/TripUpdates/ServiceAlerts protobuf exploitable sans clé ? NON**
- **API officielle accessible sans convention ? NON**
- **Procédure = Demande officielle via observatoire@cetud.sn / cetud@cetud.sn / 33 859 47 20**
- **Sources utilisables OFFICIAL/VERIFIED : 0**
- **Sources à demander : CETUD GTFS + GTFS-RT SAE + CAPTRANS**
- **Sources UNKNOWN : 11**
- **Sources REJECTED : FALLBACK Swiss, agrégations tierces Moovit/busmaps non officielles, placeholder vide, mock, Tata réseau distinct**

**Respect règle : Pas de donnée inventée, pas de modification Dakar Bus, audit uniquement.**

---
*Fin rapport Groupe 13*
