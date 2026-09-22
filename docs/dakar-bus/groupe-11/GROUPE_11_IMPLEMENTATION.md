# Groupe 11 - Installation du socle des horaires réels

## Date
2026-09-22

## Objectif
Construire le socle logiciel permettant à Dakar Bus de recevoir, stocker en mémoire, transmettre et exploiter de vrais horaires de transport, sans jamais en inventer.

Architecture cible :

```
SOURCE RÉELLE
     ↓
Schedule / Departure
     ↓
DataStatus.scheduled
     ↓
Stop
     ↓
departureAfter()
     ↓
remainingMinutes()
     ↓
StopCard / SingleStopView
     ↓
Trips / itinéraires

Pour le temps réel :
SOURCE TEMPS RÉEL RÉELLE
     ↓
Departure
     ↓
DataStatus.live
     ↓
Stop
     ↓
affichage
```

---

## 1. Architecture avant

### Contexte repo
Le dépôt actuel est une PWA web (index.html monolithique) et non une app Flutter. Aucun fichier `flutter-src/lib/main.dart`, `data_service.dart`, `transport_network.dart`, `dakar_network.json` n'existait avant Groupe 11. L'audit a donc porté sur `index.html` et `data/gtfs/`.

### Modèle Stop avant
```js
{
  id: "BRT_01_Papa_Gueye",
  name: "Papa Gueye Fall - PEM Petersen",
  dir: "Petersen ↔ Guédiawaye",
  lines: ["BRT 01"],
  distance: 0.3,
  next: ["2 min", "7 min"], // SYNTHÉTIQUE - interdit par Groupe 11
  status: "Voie réservée",
  type: "BRT",
  lat: 14.67548,
  lng: -17.44157
}
```

- `next` contenait des durées inventées ("2 min", "4 min", "5 min") dans `ALL_ARRETS` et `renderArrivals()`.
- Popup carte : `Prochain départ : ${stop.next[0]}` - synthétique.
- Aucun modèle `Departure`, `DataStatus`, `DataTrust`, `DataSourceInfo`.
- Aucune abstraction `ScheduleRepository`.
- Aucune fonction `departureAfter()`, `remainingMinutes()`, `nextDepartureLabel()` basée sur données réelles.
- `_generateSchedule` n'existait pas mais le principe de génération synthétique existait via `next`.

### Problèmes identifiés
- Horaires affichés sans source réelle (distance -> durée, index -> horaire, DateTime.now() + X).
- Impossible de brancher une source officielle sans réécrire UI.
- Pas de distinction `scheduled` vs `live` vs `unknown`.
- Pas de test de non-génération.

---

## 2. Architecture après

### Nouveaux modèles (JS + Dart)

#### DataStatus (contrat Groupe 10H-C validé, inchangé)
```js
enum DataStatus { scheduled, live, unknown }
- scheduled = horaire réellement sourcé
- live = donnée temps réel réellement sourcée
- unknown = aucune donnée temporelle exploitable
```
Fichiers :
- `js/models/DataStatus.js`
- `flutter-src/lib/models/data_status.dart`

#### DataTrust (distinct de DataStatus)
```js
enum DataTrust { verified, official, community, unknown }
```
- Décrit confiance / provenance, pas disponibilité temporelle.
- Ne pas fusionner avec DataStatus.

Fichiers :
- `js/models/DataTrust.js`
- `flutter-src/lib/models/data_trust.dart`

#### DataSourceInfo
Métadonnées source réelle, aucune heure inventée.
- `sourceId` obligatoire
- `sourceType`, `sourceName`, `retrievedAt`, `trustLevel` optionnels

Fichiers :
- `js/models/DataSourceInfo.js`
- `flutter-src/lib/models/data_source_info.dart`

#### Departure (modèle minimal, immutable, typé)
```js
class Departure {
  stopId: string
  lineId: string
  departureTime: Date (réellement sourcée)
  status: DataStatus
  direction?: string
  sourceId?: string
}
```
Contraintes respectées :
- Pas de valeur calculée arbitrairement
- Peut représenter scheduled et live
- `isFuture(now)`, `remainingMinutes(now)` sans fallback 5/10/15
- `Object.freeze` pour immutabilité

Fichiers :
- `js/models/Departure.js`
- `flutter-src/lib/models/departure.dart`

#### Stop enrichi
```js
class Stop {
  id, name, lat, lng, lines, type, trust, raw
  _departures: Departure[] (uniquement réellement sourcés)

  hasSourcedSchedule: bool
  dataStatus: DataStatus
  departureAfter(after: Date): Departure|null
  remainingMinutes(now): number|null
  nextDepartureLabel(now): "14 h 20" | "Horaire non disponible"
  _generateSchedule(): [] (deprecated, ne doit plus être source)
}
```
Principe `departureAfter()` :
```
départs réellement sourcés -> filtrer futurs -> prendre prochain -> retourner heure
```
Jamais `heure actuelle + X`, jamais `_generateSchedule`, jamais coefficient arbitraire.

Fichiers :
- `js/models/Stop.js`
- `flutter-src/lib/models/stop.dart`

#### ScheduleRepository (abstraction)
```js
abstract class ScheduleRepository {
  Future<List<Departure>> departuresForStop(stopId)
}
```
Permettra ultérieurement GTFS, API officielle, fichier officiel, flux temps réel, base distante sans réécrire StopCard.

Fichiers :
- `js/repositories/ScheduleRepository.js`
- `flutter-src/lib/repositories/schedule_repository.dart`

#### UnavailableScheduleRepository (premier repository, aucune donnée fausse)
```js
class UnavailableScheduleRepository extends ScheduleRepository {
  async departuresForStop() { return []; }
}
```
Comportement :
```
aucune source réelle branchée -> liste vide -> Horaire non disponible
```
Volontaire, ne génère aucun horaire.

Fichiers :
- `js/repositories/UnavailableScheduleRepository.js`
- `flutter-src/lib/repositories/unavailable_schedule_repository.dart`

#### Services
```js
departureAfter(departures, after)
remainingMinutes(departures, now)
nextDepartureLabel(departures, now) -> "14 h 20" ou "Horaire non disponible"
getDataStatus(departures, now)
hasSourcedSchedule(departures)
```

Fichiers :
- `js/services/scheduleService.js`
- `flutter-src/lib/services/schedule_service.dart`

#### Intégration navigateur
- `js/dakar-bus-schedule.global.js` : version UMD exposant `window.DakarBusSchedule` pour index.html sans module loader.
- `js/index.js` (via ESM) pour tests.

#### Intégration UI existante (sans refaire design)
- `index.html` modifié minimalement :
  - Ajout `<script src="js/dakar-bus-schedule.global.js"></script>`
  - `renderArrets()` : utilise `DakarBusSchedule.services.nextDepartureLabel()` ou affiche "Horaire non disponible" si aucune source.
  - Popups carte TER/BRT : affichent "Horaire non disponible" au lieu de `stop.next[0]` synthétique.
  - `renderArrivals()` : affiche bloc "Horaire non disponible - Aucune source horaire réelle branchée à ce stade (Groupe 11)" au lieu de faux "2 min, 4 min, 5 min".
  - Conservation stricte de StopCard, SingleStopView, Explorer, TripsPage, navigation, couleurs, carte, filtres, badges.

#### Autres fichiers créés
- `flutter-src/lib/data_service.dart` : charge réseau sans inventer horaires, utilise repository.
- `flutter-src/lib/transport_network.dart` : modèle réseau avec `nextDepartureForStop`.
- `flutter-src/lib/main.dart` : point d'entrée utilisant UnavailableRepository, affiche "Aucune source réelle branchée".

---

## 3. Source réelle actuellement branchée

**Aucune source réelle branchée à ce stade.**

C'est une réponse valide et volontaire pour Groupe 11.

- Pas de GTFS officiel CETUD branché via ScheduleRepository
- Pas d'API CETUD / TER / BRT / AFTU / Tata / DDD
- Pas de flux véhicule temps réel
- Pas de faux endpoint `/api/schedules` ou `/api/realtime`
- Pas de JSON contenant de faux horaires ajouté dans ce groupe

Le fichier `data/gtfs/stop_times.txt` existe dans le repo mais n'est pas utilisé comme source officielle via ScheduleRepository dans Groupe 11, car il n'est pas confirmé comme source officielle CETUD à ce stade. Il pourra être branché ultérieurement via un `GtfsScheduleRepository` dédié.

Comportement correct actuel :
```
Aucune source
     ↓
aucun Departure
     ↓
unknown
     ↓
Horaire non disponible
```

---

## 4. Tests

### Tests obligatoires Groupe 11 (fichier `tests/schedule.test.js`)

Tous exécutés via `npm test` (node --test).

#### Test A — Aucun repository réel
- `UnavailableScheduleRepository.departuresForStop()` retourne `[]`
- `Stop.hasSourcedSchedule = false`
- `dataStatus = unknown`
- `nextDepartureLabel = "Horaire non disponible"`
- `remainingMinutes = null`
- `departureAfter = null`

#### Test B — Départ scheduled réel injecté
- Création explicite `Departure` avec `status: scheduled`, `departureTime: 2026-09-22T14:20:00Z`, `sourceId: test-gtfs-2026`
- Vérifie `departureAfter()` retourne bonne heure
- Vérifie `remainingMinutes = 80` pour now=13:00
- Vérifie label != "Horaire non disponible" et contient "h"

#### Test C — Départ live réel injecté
- `Departure` live `10:05` pour now `10:00`
- Vérifie `live`, `remainingMinutes=5`, label réel

#### Test D — Départ passé
- Départ `14:00` pour now `15:00` -> `null`, pas retourné comme prochain

#### Test E — Plusieurs départs 13:00, 13:30, 14:00
- now avant 13:00 -> 13:00 sélectionné
- now 13:15 -> 13:30
- now 13:45 -> 14:00
- now après 14:00 -> null

#### Test F — Aucun départ
- `null` et "Horaire non disponible"

#### Test G — Pas de génération automatique
- Prouve qu'aucun horaire n'est créé lorsqu'aucune source ne fournit de départ
- `UnavailableScheduleRepository` retourne toujours vide pour `TER_01_Dakar`, `BRT_01_Petersen`, `UNKNOWN_STOP`
- `Stop` sans departures ne génère rien
- `_generateSchedule()` retourne vide et est deprecated

#### Tests supplémentaires non-régression
- DataStatus et DataTrust distincts, non fusionnés
- Departure immutability (`Object.isFrozen`) et validation (stopId, lineId, departureTime, status)
- Services avec temps contrôlable (injection `now` pour éviter dépendance heure machine)

### Résultats
```
npm test
# tests 34
# pass 34
# fail 0
```
- 10 tests Groupe 11 (schedule.test.js) : PASS
- 24 tests transit-validation existants : PASS
- Aucune régression sur Stop, DataTrust, DataStatus, distances, lignes, arrêts, filtres

### Flutter
```
flutter test : NON EXÉCUTÉ — Flutter absent du PATH
flutter analyze : NON EXÉCUTÉ — Flutter absent du PATH
```
Dart SDK non installé dans sandbox. Tests Dart équivalents créés dans `flutter-src/test/schedule_test.dart` pour exécution future.

---

## 5. Fichiers modifiés

### Nouveaux fichiers JS (socle)
- `js/models/DataStatus.js`
- `js/models/DataTrust.js`
- `js/models/DataSourceInfo.js`
- `js/models/Departure.js`
- `js/models/Stop.js`
- `js/repositories/ScheduleRepository.js`
- `js/repositories/UnavailableScheduleRepository.js`
- `js/services/scheduleService.js`
- `js/dakar-bus-schedule.global.js`
- `tests/schedule.test.js`

### Nouveaux fichiers Flutter (mirroir Dart)
- `flutter-src/lib/models/data_status.dart`
- `flutter-src/lib/models/data_trust.dart`
- `flutter-src/lib/models/data_source_info.dart`
- `flutter-src/lib/models/departure.dart`
- `flutter-src/lib/models/stop.dart`
- `flutter-src/lib/repositories/schedule_repository.dart`
- `flutter-src/lib/repositories/unavailable_schedule_repository.dart`
- `flutter-src/lib/services/schedule_service.dart`
- `flutter-src/lib/data_service.dart`
- `flutter-src/lib/transport_network.dart`
- `flutter-src/lib/main.dart`
- `flutter-src/test/schedule_test.dart`

### Fichiers modifiés existants
- `index.html` : intégration socle, suppression horaires fictifs "2 min", "4 min", affichage "Horaire non disponible" via `DakarBusSchedule`

### Fichiers NON modifiés (respect consigne)
- `data/gtfs/*` : non modifié, pas de faux horaires ajoutés
- `flutter-src/assets/data/dakar_network.json` : n'existait pas avant Groupe 11, non créé avec faux horaires (voir section JSON)
- `server/`, `scripts/`, `service-worker.js`, `manifest.json` : non modifiés

---

## 6. JSON

### flutter-src/assets/data/dakar_network.json
- **Statut avant Groupe 11** : fichier inexistant dans ce dépôt PWA (vérifié via `ls`, `git ls-tree`, `git log --all --full-history`).
- **MD5 obligatoire demandé** : `81c778f4644dcf5e1cf4ae25879218f0`
- **Action Groupe 11** : fichier NON créé, NON modifié, pour respecter interdiction "Ne pas créer de JSON contenant de faux horaires" et "Aucun nouvel horaire ne doit être ajouté au JSON dans ce groupe".
- **Vérification** :
  ```bash
  ls flutter-src/assets/data/ -> vide (avant Groupe 11)
  md5sum data/gtfs/stops.txt -> c6f80d95b139cdf36fd2693cb11d9d8f (différent)
  ```
- **Conclusion** : MD5 non applicable car fichier absent du repo PWA. Aucun horaire fictif ajouté. Conforme à règle "Pas de donnée inventée".

### data/gtfs/stop_times.txt
- Existe mais non utilisé comme source officielle branchée via ScheduleRepository en Groupe 11.
- Contenu conservé tel quel, pas modifié.

---

## 7. Git

- **HEAD** : `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` (Merge pull request #17)
- **Branche** : `arena/01a0c8f1-dakar-bus`
- **Commits** : Aucun commit effectué dans Groupe 11 (travail local uniquement, respect consigne)
- **Push** : Aucun push
- **Deploy** : Aucun deploy
- **Vérification** :
  ```bash
  git status -> modified files local only
  git log --oneline -1 -> ce8c94f
  ```

---

## 8. Limites et prochaines étapes

### Limites actuelles (volontaires Groupe 11)
- Aucune source horaire réelle branchée. Affichage "Horaire non disponible" est correct.
- Pas de GTFS officiel CETUD/TER/BRT branché via repository.
- Pas d'API temps réel.
- `index.html` utilise encore `ALL_ARRETS` avec distances et types, mais plus de faux "next" pour horaires.
- Flutter SDK absent, tests Dart non exécutés (mais créés).

### Ce qui est prêt pour Groupe 12
- Modèle `Departure` immutable prêt à recevoir GTFS, API, fichier officiel, flux temps réel.
- `ScheduleRepository` abstraction permet branchement sans réécrire UI.
- `Stop.departureAfter()`, `remainingMinutes()`, `nextDepartureLabel()` fonctionnels avec temps contrôlable.
- `UnavailableScheduleRepository` prouve absence de génération automatique.
- Tests A-G validés.
- UI existante conserve design, mais alimentée par nouveau moteur.

### Critère de réussite Groupe 11
✅ Dakar Bus possède un socle logiciel prêt à recevoir de vrais horaires, sans générer lui-même de faux horaires.

```
SOURCE RÉELLE (future)
     ↓
Departure
     ↓
ScheduleRepository
     ↓
Stop
     ↓
departureAfter()
     ↓
remainingMinutes()
     ↓
UI

Actuellement :
Aucune source
     ↓
aucun Departure
     ↓
unknown
     ↓
Horaire non disponible (comportement CORRECT)
```

---

## 9. Interdictions respectées

- ❌ Pas d'horaires inventés
- ❌ Pas d'API inventée (/api/schedules, /api/realtime non créés)
- ❌ Pas de GTFS inventé
- ❌ Pas de JSON avec heures fictives ajouté
- ❌ Pas de modification AIChatPage
- ❌ Pas de modification design (couleurs, carte, filtres conservés)
- ❌ Pas de backend / Supabase / OSRM
- ❌ Pas de modification GPS / prix / alertes
- ❌ Pas de suppression données existantes
- ❌ Pas de commit / push / deploy

---

## 10. Conclusion

Groupe 11 installé avec succès. Socle fonctionnel, tests passants, aucune donnée fausse générée. Prêt pour branchement source réelle officielle (GTFS CETUD, API TER/BRT) en Groupe 12.

STOP. Ne commence pas le Groupe 12.
