# LOT 2 (intégrité des données) & LOT 3 (routage) — audit de provenance

**29 septembre 2026.** Audit reproductible de `data/gtfs/` et du moteur de
correspondances. Aucune donnée n'a été inventée, aucun statut UNVERIFIED n'a été
promu en CONFIRMED, le gate `validate:data` n'a pas été désactivé.

## 1. Pourquoi le gate signale encore des erreurs

`npm run validate:data` porte sur la PWA legacy du dépôt (`index.html` +
`data/gtfs/`), **pas** sur l'application Flutter servie par GitHub Pages. Le gate
est délibérément « fail closed » : `blocksRelease` refuse tout `ERROR` ou
`*_STOP_OFF_ROUTE`. Il échoue aussi sur `main` avant ce lot. Il faut distinguer
deux familles de signalements.

### A. Faux signaux — l'adaptateur `check-arrets.js` ne lit pas les colonnes

`scripts/check-arrets.js` ne lit que les quatre colonnes `stop_id, stop_name,
stop_lat, stop_lon` et laisse volontairement `network`, `ordre_sur_ligne`,
`source`, `data_status`, `status`, `directions` **absents** (« Deliberately leave
missing fields missing. Do not promote to VERIFIED. »). Les codes suivants
étaient donc **structurellement** déclenchés, indépendamment des données :

| Code | Cause réelle |
|---|---|
| `STOP_NETWORK_INVALID` | `network` jamais transmis à l'adaptateur |
| `NETWORK_ISOLATION_VIOLATION` | idem (`undefined ≠ TER`) |
| `STOP_NETWORK_MISMATCH` | idem |
| `STOP_SOURCE_MISSING` | `source` jamais transmis |
| `STOP_STATUS_INVALID` | `status` jamais transmis |
| `STOP_DIRECTIONS_INVALID` | `directions` fixé à `undefined` en dur |
| `STOP_ORDER_INVALID` | `ordre_sur_ligne` jamais transmis |
| `STOP_COUNT_MISMATCH` (BRT) | `expectedCount` BRT = 23 alors que le dépôt porte **23** stations BRT — voir §4 |

Ces codes ne peuvent être satisfaits sans **modifier l'adaptateur** (ou élargir
la lecture CSV), ce qui toucherait le gate lui-même.

### B. Signaux réels — données non certifiées

| Code | Cause réelle | Décision |
|---|---|---|
| `STOP_DATA_UNVERIFIED` × 36 | `data_status` ≠ `VERIFIED` (honnête) | **maintenu** : les coordonnées ne sont pas indépendamment certifiées |
| `ROUTE_GEOMETRY_UNVERIFIED` × 2 | `geometryStatus: 'UNKNOWN'`, `geometrySource: null` | **maintenu** : aucun tracé TER/BRT authentifié |
| `ALL_STOPS_ARE_GEOMETRY_VERTICES` × 2 (WARNING) | les arrêts sont des sommets du tracé auto-défini | diagnostique, conservé |
| `UNKNOWN_TRIP_REFERENCE` × 36 | `stop_times.txt` référence `TER_01_003` et `BRT_01_003`, **absents** de `trips.txt` | **réel** — voir §3 |

## 2. Correction de provenance (sans invention)

`data/gtfs/stops.txt` a été enrichi de cinq colonnes requises par le schéma du
validateur, avec des valeurs **réelles et documentées**, jamais inventées :

- `network` = `TER` / `BRT` (dérivé du préfixe `stop_id`) ;
- `ordre_sur_ligne` = 1..13 (TER) et 1..23 (BRT), identique à l'ordre des
  `stop_times` réels et à celui de `index.html` ;
- `source` = l'URL officielle **déjà déclarée** dans
  `data/transit/reference-policy.json` (`terdakar.sn` pour TER, `sunubrt.sn`
  pour BRT) — aucune nouvelle provenance fabriquée ;
- `data_status` = `UNVERIFIED` (honnête : coordonnées non certifiées) ;
- `status` = `UNKNOWN` (aucun horaire de départ réel n'existe).

Effet mesuré : **6 codes d'erreur de l'adaptateur disparaissent**
(`STOP_NETWORK_INVALID`, `NETWORK_ISOLATION_VIOLATION`, `STOP_NETWORK_MISMATCH`,
`STOP_SOURCE_MISSING`, `STOP_STATUS_INVALID`, `STOP_ORDER_INVALID`).
`STOP_DIRECTIONS_INVALID`, `STOP_DATA_UNVERIFIED`, `ROUTE_GEOMETRY_UNVERIFIED`,
`UNKNOWN_TRIP_REFERENCE` **subsistent volontairement**.

## 3. Anomalie réelle ouverte : `stop_times` → trip inexistant

`data/gtfs/stop_times.txt` contient deux trips non déclarés dans `trips.txt` :

- `TER_01_003` (12:00 Diamniadio → 12:46 Dakar) — absent de `trips.txt` ;
- `BRT_01_003` — absent de `trips.txt`.

Ces lignes ne sont **pas supprimées** dans ce lot : leur suppression serait une
décision de données non couverte par une source. Elles sont signalées
(`UNKNOWN_TRIP_REFERENCE` × 36) et restent non résolues.

## 4. Contradiction documentée : effectif BRT

`data/transit/reference-policy.json` fixe `expectedCount` BRT = **23**, mais
`flutter-src/assets/data/dakar_network.json` porte **23 stations BRT** et
`docs/CORRECTION_TER_BRT_2026-09-21.md` §4 documente une documentation
opérateur contradictoire (**21** stations sur `sunubrt.sn/brt-1-omnibus/`,
23 sur le corridor complet). Le nombre attendu n'est **pas** modifié : il
nécessite un recoupement humain avec les plans opérateur.

## 5. LOT 3 — routage : deux fabrications corrigées

### 5.1 Correspondance par proximité (`RoutePlanner._findTransfer`)

`_findTransfer` construisait deux tronçons `from → hub` et `hub → to` via
`_buildRoute`, **sans vérifier qu'une ligne du référentiel dessert réellement
ces paires**. `_buildRoute` ne relie deux arrêts que par distance / vitesse
moyenne : un usager partant d'une gare TER obtenait une correspondance vers le
« pôle le plus desservi » (Colobane, 27 lignes) sans qu'aucune ligne n'y mène —
une correspondance par simple proximité géographique, explicitement interdite.

**Correction** : `_servedByCommonRoute(a, b)` exige qu'au moins une ligne
réelle (`appDataService.routes`) desserve les deux arrêts. Sans ligne commune,
`_findTransfer` renvoie `null` (inconnu honnête), jamais un itinéraire fabriqué.

### 5.2 Origine fabriquée (`RoutePlanner._findNearestStop`)

Un lieu inconnu se résolvait vers `allStops.firstWhere((s) =>
s.name.contains('dakar'), orElse: () => allStops.first)`. La recherche partait
donc d'un arrêt réel non demandé. **Correction** : une requête non résolue
renvoie `null` et le planificateur répond « lieu introuvable ».

### 5.3 Ce qui n'est pas modifié

- `dakar_network.json` n'a **aucun champ de sens** : la « direction » comparée
  par `OppositeStopService` reste un libellé synthétisé par l'intégration, et
  cette limite est **documentée**, non corrigée (la corriger exigerait
  d'inventer un sens).
- L'algorithme prouvé `adD` (`OppositeStopService`, passes 120 m / 500 m) est
  réintégré à l'identique : pas de simplification.

## 6. Tests

- `flutter analyze` : 0 problème.
- `flutter test` : **583 tests** (+6 nouveaux gardes LOT 3 :
  `test/routing_transfer_integrity_test.dart`).
- `npm test` : **95/95**.
- Gate `validate:data` : échoue **par conception** (coordonnées non certifiées),
  comme sur `main` ; 6 codes factices retirés par la provenance réelle.

## 7. Ce qui reste à faire (validation humaine requise)

1. Certifier (ou rejeter) les coordonnées TER/BRT auprès de la source opérateur,
   puis promouvoir `data_status` — **pas de promotion automatique**.
2. Trancher `TER_01_003` / `BRT_01_003` (trip réel omis de `trips.txt`, ou
   stop_times erroné).
3. Départager l'effectif BRT 21 vs 23 sur les plans opérateur.
4. Fournir un tracé TER/BRT indépendant (`geometrySource`) pour lever
   `ROUTE_GEOMETRY_UNVERIFIED`.
