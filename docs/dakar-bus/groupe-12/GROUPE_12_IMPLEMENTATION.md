# Groupe 12 — Audit + Intégration des vraies sources de données

**Date :** 2026-09-22
**Branche :** arena/01a0c8f1-dakar-bus
**Commit référence Groupe 11 :** 27ae525e1bf724ca5d7432eade66e1003a17b2a7
**HEAD actuel avant rapport :** 27ae525

---

## PHASE 1 — Audit complet du dépôt

### Git
```bash
git status -> On branch arena/01a0c8f1-dakar-bus, nothing to commit, working tree clean
git branch --show-current -> arena/01a0c8f1-dakar-bus
git log --oneline -10 -> 27ae525 (Groupe 11), ce8c94f (main)
```

### Fichiers maxdepth 4
```
.github/workflows/transit-validation.yml
BRANCHEMENT_CETUD.md, CORRECTIFS.md, CORRECTIF_ARRETS_TER_BRT.md, etc.
api/gtfs-rt (placeholder JSON)
api/index.js
data/gtfs/agency.txt, calendar.txt, feed_info.txt, routes.txt, shapes.txt, stop_times.txt, stops.txt, trips.txt
data/transit/reference-policy.json
docs/dakar-bus/groupe-11/GROUPE_11_IMPLEMENTATION.md
flutter-src/lib/...
index.html
js/models/, repositories/, services/, dakar-bus-schedule.global.js
tests/schedule.test.js, transit-validation.test.js
server/server.js, .env, etc.
```

**Recherche ciblée :**
- GTFS : `data/gtfs/` complet (7 fichiers)
- API : `api/gtfs-rt`, `server/.env` avec URLs CETUD/DDD/BRT/TER, `server/server.js` proxy
- schedule/departure/realtime : `js/models/Departure.js`, `js/repositories/ScheduleRepository.js`, `js/services/sourceAudit.js` (nouveau Groupe 12)

---

## PHASE 2 — Audit de data/gtfs/stop_times.txt

### 1. Origine documentée ?
- Mention dans `CORRECTIF_ARRETS_TER_BRT.md` : "Données GTFS complétées : passage de 36 à 108 lignes. Trajets retour et départs supplémentaires"
- `feed_info.txt` : `CETUD Dakar Mobilité, https://cetud.sn, contact@cetud.sn, version 2.1-dakar-pwa-gtfs-rt`
- `agency.txt` : liste CETUD, DDD, BRT, TER, AFTU avec URLs génériques
- **Aucune URL officielle de téléchargement GTFS**, pas de signature, pas de clé, pas de documentation d'import depuis Mobility Database ou transport.data.gouv.fr
- **Conclusion provenance :** Fichier local généré/complété manuellement pour PWA, pas de preuve d'origine officielle CETUD

### 2. Contenu
```
trip_id,arrival_time,departure_time,stop_id,stop_sequence
BRT_01_001,06:00:00,06:00:30,BRT_01_Papa_Gueye,1
BRT_01_001,06:02:00,06:02:30,BRT_02_Grande_Mos,2
...
TER_01_001,06:00:00,06:01:00,TER_01_Dakar,1
TER_01_001,06:04:00,06:05:00,TER_02_Colobane,2
...
```
- 108 lignes (hors header)
- 3 trips BRT : BRT_01_001 (06:00), BRT_01_002 (07:00), BRT_01_003 (12:00)
- 3 trips TER : TER_01_001 (06:00), TER_01_002 (07:00), TER_01_003 (12:00)

### 3. Structure
- Format GTFS `stop_times.txt` valide : 5 colonnes standard
- `stop_id` correspond à `stops.txt` (42 arrêts)
- `trip_id` correspond à `trips.txt`
- Pas de `calendar_dates.txt`, `frequencies.txt`

### 4. Autres fichiers GTFS associés
- `stops.txt` : 42 arrêts (13 TER + 23 BRT + 6 pôles)
- `routes.txt` : 76 routes (BRT 01, DDD 10/07/12/23, TATA 01/02, TER 01, AFTU 01-73)
- `trips.txt` : 146 lignes, trips BRT/TER/AFTU/DDD
- `calendar.txt` : WEEKDAY, WEEKEND, DAILY, BRT_DAILY, TER_DAILY
- `agency.txt` : 5 agences
- `shapes.txt` : tracés BRT/TER
- `feed_info.txt` : métadonnées CETUD

### 5. Lien fiable arrêts/routes ?
- Oui techniquement : `stop_id` présents dans `stops.txt`, `route_id` dans `routes.txt`
- Mais fiabilité **UNKNOWN** car pas de source officielle vérifiable

### 6. Horaires réels ou test/démo ?
- **Pattern démo** :
  - BRT : intervalles **exactement 2 min** (06:00, 06:02, 06:04...)
  - TER : intervalles **exactement 4 min** (06:00, 06:04, 06:08...)
  - Seulement 3 départs par sens (06:00, 07:00, 12:00), pas de journée complète
  - Pas de variations, pas de retards, pas de fréquences réelles opérateurs
- **Conclusion :** Données de **test/démonstration**, pas horaires réels opérateurs
- **OFFICIAL_SOURCE = false**, reste **inutilisé** comme source officielle

---

## PHASE 3 — Recherche sources disponibles dans le projet

### Commande
```bash
grep -RniE "gtfs|api|realtime|real.time|departure|schedule|horaire|ter|brt|aftu|tata|ddd" . --exclude-dir=.git --exclude-dir=node_modules
```

### Sources trouvées

| Source | Réseau | Type | URL | Auth | Données | Fiabilité |
|--------|--------|------|-----|------|---------|-----------|
| `data/gtfs/stop_times.txt` | TER, BRT | GTFS static local | local: data/gtfs/stop_times.txt | aucune | 108 lignes horaires réguliers | UNKNOWN |
| `data/gtfs/stops.txt` | TER, BRT, BUS | GTFS static arrêts | local: data/gtfs/stops.txt | aucune | 42 arrêts | UNKNOWN (mais utilisé pour carte) |
| `data/gtfs/routes.txt` | ALL | GTFS routes | local | aucune | 76 lignes | UNKNOWN |
| `CETUD VehiclePositions` | TER,BRT,DDD,AFTU | GTFS-RT API | https://api.cetud.sn/gtfs-rt/vehiclePositions | CETUD_API_KEY vide, USE_MOCK=true | mock 127 véhicules | UNKNOWN |
| `CETUD TripUpdates` | TER,BRT | GTFS-RT | https://api.cetud.sn/gtfs-rt/tripUpdates | clé manquante | aucune | UNKNOWN |
| `CETUD Alerts` | TER,BRT | GTFS-RT | https://api.cetud.sn/gtfs-rt/alerts | clé manquante | aucune | UNKNOWN |
| `DDD API` | DDD | API supposée | https://api.dakardemdikk.sn/gtfs-rt | aucune preuve | aucune | UNKNOWN |
| `BRT API` | BRT | API supposée | https://api.sunubrt.sn/gtfs-rt | aucune preuve | aucune | UNKNOWN |
| `TER API` | TER | API supposée | https://api.ter.sn/gtfs-rt | aucune preuve | aucune | UNKNOWN |
| `api/gtfs-rt` | ALL | JSON placeholder | local: api/gtfs-rt | aucune | {"entity":[]} | UNKNOWN |
| `GTFSRTClient mock` | ALL | Simulation JS | inline index.html | aucune | setInterval 3s, interpolation | UNKNOWN (animation carte) |
| `FALLBACK Swiss` | - | GTFS-RT public test | https://api.opentransportdata.swiss/... | aucune | Suisse, pas Dakar | UNKNOWN |

**Aucune URL/API avec authentification valide et données réelles Dakar n'est disponible.**

---

## PHASE 4 — Modèle de confiance

### Définition
- **OFFICIAL** : Source autorité organisatrice (CETUD, SETER, DDD, AFTU, SunuBRT) avec preuve : URL officielle documentée, clé API valide, feed signé, documentation import
- **VERIFIED** : Source OFFICIAL vérifiée terrain / croisée avec plusieurs sources officielles (ex: coordonnées vérifiées via reference-policy.json + source opérateur)
- **UNKNOWN** : Provenance non établie, non utilisable comme source horaire officielle

### Classification actuelle
- Tous les fichiers `data/gtfs/*` : **UNKNOWN** (pas de preuve officielle, pattern demo)
- Toutes les URLs CETUD/DDD/BRT/TER dans `.env` : **UNKNOWN** (pas de clé, pas de test réussi, mode mock)
- `api/gtfs-rt` placeholder : **UNKNOWN**
- `GTFSRTClient` mock : **UNKNOWN** (simulation)
- **Aucune source OFFICIAL ou VERIFIED pour horaires**

---

## PHASE 5 — Intégration au ScheduleRepository

### Interface actuelle (Groupe 11)
```js
abstract class ScheduleRepository {
  async departuresForStop(stopId): Promise<Departure[]>
  async departuresForStopAndLine(stopId, lineId): Promise<Departure[]>
}
class UnavailableScheduleRepository extends ScheduleRepository {
  async departuresForStop() { return []; }
}
```

- Interface **conservée**, non réécrite inutilement
- **Aucune vraie source vérifiable disponible** → repository reste `UnavailableScheduleRepository`
- Retourne `[]` avec état `UNKNOWN` → UI affiche `Horaire non disponible` (comportement correct Groupe 11)

### Pourquoi pas GtfsScheduleRepository ?
- Pour créer `GtfsScheduleRepository`, il faudrait :
  1. Preuve provenance officielle CETUD (URL feed officiel, signature, doc)
  2. Données horaires réelles opérateurs, pas intervalles réguliers demo
  3. Validation structure GTFS complète
  4. Association fiable arrêts/routes
- **Aucune condition remplie** pour `stop_times.txt` → on ne crée pas de repository GTFS officiel
- Création d'un faux repository serait violation "Pas de donnée inventée"

---

## PHASE 6 — Si une vraie source est trouvée

**Condition non remplie.**

Aucune source vérifiable existant déjà dans dépôt avec provenance établie.

Donc **CAS B** s'applique : conserver `UnavailableScheduleRepository`.

Si à l'avenir une source officielle est obtenue (ex: GTFS officiel CETUD avec clé), alors créer :
```js
class GtfsScheduleRepository extends ScheduleRepository {
  // charger, valider, associer arrêts, produire Departure avec provenance, signaler indisponibles
}
```

Mais pas maintenant.

---

## PHASE 7 — Distinction programmé / temps réel

### Respect strict
- **SCHEDULED** : Horaire source programmée vérifiée (ex: GTFS officiel CETUD) → `DataStatus.scheduled`
- **REAL_TIME** : Donnée temps réel véritable (ex: GTFS-RT CETUD avec clé, vehiclePositions avec timestamp réel) → `DataStatus.live`
- **UNKNOWN** : Aucune donnée vérifiable → `DataStatus.unknown` → `Horaire non disponible`

### Actuel
- Aucune donnée SCHEDULED vérifiable → UNKNOWN
- Aucune donnée REAL_TIME vérifiable (mock uniquement, pas de clé) → UNKNOWN
- UI affiche correctement `Horaire non disponible`, pas `Bientôt`, `5 min`, `En approche`, `LIVE` fictif

---

## PHASE 8 — Aucune simulation

**Interdictions respectées :**
- ❌ Pas de `Date.now() + X minutes` pour simuler départ (vérifié dans `js/` et `index.html`)
- ❌ Pas de `5 min / 7 min / 10 min / 15 min` arbitraire (supprimé de `renderArrets` et `renderArrivals` en Groupe 11, remplacé par `Horaire non disponible`)
- ❌ Pas de `index * vitesse` ou approximation
- ❌ Pas de transformation UNKNOWN → SCHEDULED

Vérification :
```bash
grep -Rni "Date.now() +\|5 min\|_generateSchedule" js/ -> seulement deprecated qui retourne []
grep -n "next\[0\]" index.html -> plus utilisé pour horaires réels (remplacé par DakarBusSchedule)
```

---

## PHASE 9 — Interface

**Aucun redesign.**

- Couleurs : conservées (#00B140, etc.)
- Navigation : conservée (Explorer, Trajets, Arrêts, Transports, Alertes)
- Cartes : conservées (Leaflet, TER/BRT shapes, calques)
- Boutons, disposition, cartes d'arrêts, filtres, identité visuelle : conservés

Seul comportement :
- Donnée disponible → afficher correctement (pas de cas actuel)
- Donnée indisponible → `Horaire non disponible` (mécanisme Groupe 11)

---

## PHASE 10 — Tests

### Tests ajoutés Groupe 12 (`tests/groupe12.test.js`)

- **TEST A** : Repository sans source → [] et UNKNOWN → PASS
- **TEST B** : Source programmée valide produit Departure SCHEDULED avec sourceId traçable → PASS
- **TEST C** : Source temps réel valide produit REAL_TIME (live) avec sourceId contenant live/rt → PASS
- **TEST D** : Source invalide (Date invalide, status fake, stop inexistant) → aucun départ, throws → PASS
- **TEST E** : Aucune génération artificielle (boucle 5 appels → 0, _generateSchedule → [], remainingMinutes jamais 5/10/15) → PASS
- **TEST F** : Données inconnues non transformées en programmées (UNKNOWN reste UNKNOWN) → PASS
- **TEST G** : Aucune régression interface (fichiers critiques existent, index.html contient Dakar Bus, map, Horaire non disponible) → PASS
- **TEST H** : stop_times.txt non certifié ne devient jamais source officielle automatique (fichier existe, contenu 108 lignes, pattern demo, Unavailable repo retourne [] même si fichier présent, pas de GtfsScheduleRepository branché par défaut) → PASS

### Tests existants
- Groupe 11 (schedule.test.js) : 10 tests PASS
- transit-validation.test.js : 24 tests PASS
- **Total npm test : 42 PASS / 0 FAIL**

---

## PHASE 11 — Tests exécutés

```bash
npm test
# tests 42
# pass 42
# fail 0

node --test tests/*.test.js -> idem
```

Flutter :
```
Flutter tests: NON EXÉCUTÉS — Flutter absent du PATH
Flutter analyze: NON EXÉCUTÉ — Flutter absent du PATH
```

---

## PHASE 12 — Rapport

### 1. Sources trouvées

**Aucune source OFFICIAL/VERIFIED pour horaires.**

Liste détaillée voir tableau Phase 3 et fichier `js/services/sourceAudit.js`.

Pour chaque source :
- **Nom** : ex: `data/gtfs/stop_times.txt`
- **Réseau** : TER, BRT, etc.
- **Type** : GTFS static local, GTFS-RT API, Simulation JS
- **Provenance** : Fichier local sans URL officielle, ou URL dans .env sans clé
- **URL** : local ou https://api.cetud.sn/...
- **Statut** : UNKNOWN (pas de preuve officielle)
- **Utilisée par Dakar Bus** : Non pour horaires (Oui pour carte pour stops.txt/routes.txt, Oui pour animation véhicules pour mock, mais pas comme source horaire officielle)

### 2. Sources rejetées

| Source | Raison rejet |
|--------|--------------|
| `data/gtfs/stop_times.txt` | Provenance non prouvable, pattern demo (2min/4min réguliers), seulement 3 trips, pas de feed officiel signé |
| `CETUD VehiclePositions` | Pas de clé API, USE_MOCK=true, endpoint non testé avec succès, mock uniquement |
| `CETUD TripUpdates` | Même raison, pas de clé |
| `CETUD Alerts` | Même raison |
| `DDD API` | URL non vérifiée, jamais utilisée dans server.js, pas de doc officielle |
| `BRT API` | Idem |
| `TER API` | Idem |
| `api/gtfs-rt` | Placeholder vide |
| `GTFSRTClient mock` | Simulation JS, pas temps réel réel |
| `FALLBACK Swiss` | Données Suisse, pas Dakar |

Toutes rejetées car **provenance non établie** → ne peuvent pas être considérées comme fiables pour horaires.

### 3. stop_times.txt

- **Provenance** : Fichier local dans repo, mention "Données GTFS complétées" dans CORRECTIF_ARRETS_TER_BRT.md, feed_info.txt mention CETUD mais sans URL officielle, sans signature, sans clé, sans documentation d'import depuis source officielle
- **Contenu** : 108 lignes, 3 trips BRT (06:00,07:00,12:00) avec intervalles 2min, 3 trips TER (06:00,07:00,12:00) avec intervalles 4min
- **Structure** : GTFS valide mais incomplet, pas de calendar_dates, frequencies
- **Utilisé** : **NON** comme source officielle horaire en Groupe 12
- **Source officielle** : **NON** (OFFICIAL_SOURCE = false)
- **Raison** : Pattern démo (intervalles réguliers exacts), seulement 3 départs, pas de preuve origine officielle CETUD, pas de feed signé, ne peut pas être considéré comme horaires réels opérateurs

### 4. Architecture

```
Aucune source officielle vérifiable (GTFS officiel, API CETUD avec clé)
     ↓
UnavailableScheduleRepository (retourne [])
     ↓
Departure : aucun (liste vide)
     ↓
Stop : hasSourcedSchedule=false, dataStatus=UNKNOWN, nextDepartureLabel="Horaire non disponible"
     ↓
UI : affiche "Horaire non disponible" (mécanisme Groupe 11)
     ↓
Carte : 42 arrêts affichés (13 TER + 23 BRT + 6 pôles) mais sans horaires temps réel

Si à l'avenir source officielle obtenue :
SOURCE OFFICIELLE (GTFS officiel CETUD ou API avec clé)
     ↓
GtfsScheduleRepository / OfficialApiScheduleRepository (à créer)
     ↓
Departure (scheduled/live avec sourceId traçable)
     ↓
Stop (departureAfter, remainingMinutes, nextDepartureLabel)
     ↓
UI (affiche "14 h 20" ou temps réel)
```

### 5. Tests

- **npm test** : 42 PASS, 0 FAIL
  - Groupe 11 : 10 tests (A→G + non-régression)
  - Groupe 12 : 8 tests (A→H)
  - transit-validation : 24 tests
- **Flutter** : NON EXÉCUTÉS — Flutter absent

### 6. Données réellement disponibles

| Réseau | Statut | Détail |
|--------|--------|--------|
| TER | **INCONNU** | Aucune source horaire officielle vérifiable. stops.txt a 13 gares, mais pas d'horaires réels. API TER supposée sans clé, non vérifiée. |
| BRT | **INCONNU** | Aucune source horaire officielle vérifiable. stops.txt a 23 stations, mais stop_times.txt est demo (2min réguliers). API BRT supposée sans clé. |
| AFTU | **INCONNU** | Aucune source horaire. routes.txt liste 60+ lignes AFTU mais pas d'horaires. Pas d'API vérifiable. |
| TATA | **INCONNU** | Aucune source horaire. routes.txt liste TATA 01/02 mais pas d'horaires. |
| DDD | **INCONNU** | Aucune source horaire. routes.txt liste DDD 10/07/12/23 mais pas d'horaires. API DDD supposée sans clé. |

**Aucun réseau n'a de source horaire DISPONIBLE ou PARTIEL vérifiable en Groupe 12.**

---

## Règle de décision

**CAS B — Aucune source réelle et vérifiable n'est disponible**

→ **NE RIEN INVENTER**
→ Conserver `UnavailableScheduleRepository` et `Horaire non disponible`
→ C'est un résultat valide pour Groupe 12

---

## Git

### Vérifications avant commit
```bash
git diff --stat -> js/services/sourceAudit.js (nouveau), tests/groupe12.test.js (nouveau), docs/dakar-bus/groupe-12/ (nouveau)
git diff -> pas de faux horaires, pas de simulation, seulement audit + tests
npm test -> 42 PASS
git status -> untracked/modified files list
```

### Décision commit ?
- **Modification fonctionnelle nécessaire ?** Oui : ajout audit service + tests Groupe 12 qui prouvent qu'aucune source officielle n'est disponible et que stop_times.txt ne devient pas source officielle automatiquement. C'est une modification validée et nécessaire pour Groupe 12.
- Donc **commit + push** justifiés.

### Actions
```bash
git add .
git commit -m "feat: integrate verified schedule sources - Groupe 12 audit, no official source found, keep UnavailableRepository"
git push origin HEAD
```

---

## Interdictions respectées

- ❌ Aucun horaire inventé
- ❌ Aucun temps réel simulé (mock existant conservé mais non utilisé comme source officielle)
- ❌ Aucun LIVE fictif (badge LIVE remplacé par Horaire non disponible quand pas de source)
- ❌ Aucun faux API (pas de /api/schedules créé)
- ❌ Aucun GTFS présenté comme officiel sans preuve (stop_times.txt explicitement marqué UNKNOWN, non utilisé)
- ❌ Aucun prix, redesign, remplacement interface, suppression données

---

## GROUPE 12 TERMINÉ

- **Sources vérifiées :** Aucune (0 OFFICIAL, 0 VERIFIED, 11 UNKNOWN)
- **Sources intégrées :** Aucune (UnavailableScheduleRepository conservé)
- **Sources rejetées :** 11 (stop_times.txt, stops.txt horaire, routes.txt horaire, CETUD VehiclePositions/TripUpdates/Alerts, DDD/BRT/TER API supposées, api/gtfs-rt placeholder, GTFSRTClient mock, FALLBACK Swiss)
- **TER :** INCONNU
- **BRT :** INCONNU
- **AFTU :** INCONNU
- **TATA :** INCONNU
- **DDD :** INCONNU
- **Tests :** 42 PASS / 0 FAIL (npm test)
- **Commit :** à faire après validation
- **Push :** à faire après commit
- **HEAD :** 27ae525 avant Groupe 12, à mettre à jour après push

**Priorité absolue respectée : Pas de donnée inventée.**
