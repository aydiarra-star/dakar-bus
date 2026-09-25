# Audit read-only — branchement de Flutter sur `DepartureEngineService` (2026-09-25)

Périmètre : `flutter-src/` (app J9) et le moteur déjà validé (`engine/departure-engine.js`
+ miroir Dart `lib/services/departure_service.dart` + `assets/data/departure-frequencies.json`).
**Cette étape d'audit ne modifie aucun fichier.** État au moment de l'audit : branche
`arena/01a0d6a5-dakar-bus`, HEAD `c0ef96a`, arbre propre hors travaux du moteur.

---

## 1. Où les arrêts sont chargés

```
main()                                  lib/main.dart:22
  └─ appDataService.loadNetworkData()   lib/services/data_service.dart:22
       └─ rootBundle 'assets/data/dakar_network.json' → TransportNetwork.fromJson
            ├─ _stops    117 arrêts  (BusStop : id, name, lat/lng, provenance, placeId)
            ├─ _routes   105 lignes  (TransportRoute : id, operatorId, stopIds, provenance)
            └─ _operators 5          (TER, BRT, DDD, AFTU, Tata)
       └─ repli mémoire si l'asset est illisible (_loadFallbackData, 6 arrêts non vérifiés)
  └─ _integrateNetworkData()            lib/main.dart:1248
       ├─ construit `allStops`  (List<Stop>) : un Stop par (arrêt, route qui le dessert)
       ├─ construit `demoRoutes` (List<TransitRoute>) : polylignes de la carte
       └─ horaires : `const List<int> schedule = <int>[]` (l. 1330) — AUCUN horaire
```

`Stop` (`lib/main.dart:699`) porte : `name`, `direction`, `distanceMeters`,
`departureMinutesFromMidnight` (**toujours vide**), `icon`, `color`, `status`, `modeLabel`
(`TER`/`BRT`/`DDD`/`AFTU`/`Tata`), `source`, `stopType`, **`stopId`** (id JSON, ex. `stop_dakar_ter`).

**Constat A1 — l'identité de la LIGNE est perdue.** `_integrateNetworkData` connaît `route.id`
pendant la boucle mais ne le stocke pas : le `Stop` ne garde que `modeLabel` (« TER », « BRT »).
Or le référentiel de fréquences indexe par `line_id` (`ter_dakar_diamniadio`,
`brt_b1_guediawaye_petersen`, `brt_b2_express`). Sans `lineId`, le moteur ne peut pas choisir la
bonne fréquence : **c'est le seul champ manquant pour le branchement**.

**Constat A2 — arrêts mutualisés.** 49 arrêts appartiennent à plus d'une route (ex. `stop_colobane` :
TER + 7 DDD + 17 AFTU). La déduplication actuelle (`name + lat + lng`) conserve le **premier**
arrêt rencontré, et l'ordre du JSON est : TER (0), B1 (1), B2 (2), `ddd_*`, `aftu_*`, `tata_*`.
Conséquence : une gare TER reste TER, une station BRT reste B1 (les 7 stations B2 ⊂ B1), et un
arrêt de bus reste DDD/AFTU/Tata. Cet ordre est déterministe et suffisant — aucune modification
de la déduplication n'est nécessaire.

## 2. Où les lignes sont chargées

* Modèle : `TransportRoute` (`lib/models/transport_network.dart:789`), `id` = id référentiel.
* Carte : `demoRoutes` (polylignes construites depuis `route.stopIds`), `MarkerLayer` et
  `PolylineLayer` de l'onglet Explorer (`lib/main.dart:2417-2455`).
* Fiches de ligne : `DetailedRoute.fromStop` / `fromOperator` (`lib/main.dart:397+`).
* Aucune coordonnée codée en dur : tout vient du JSON (déjà corrigé le 2026-09-24).

## 3. Où les départs sont calculés aujourd'hui

| Emplacement | Ce qui est calculé | Valeur réelle |
|---|---|---|
| `Stop.nextDepartureMinutes()` (l. 757) | premier départ fourni ≥ maintenant | `null` (aucun horaire fourni) |
| `Stop.remainingMinutes()` (l. 766) | compte à rebours | `null` |
| `Stop.nextDepartureLabel()` (l. 773) | « HH h MM » | « Horaire indisponible » |
| `Stop.departureAfter(min)` (l. 780) | prochain départ après une minute | `null` |
| `RoutePlanner._buildRoute` (l. 1520) | heure de départ du tronçon | `null` → `DataStatus.unknown` |

**Constat A3 — il n'existe plus aucun calcul de départ, ni aucun générateur.** Tous les chemins
retournent « indisponible ». L'application Flutter est donc honnête mais **muette** : elle
n'affiche nulle part l'estimation TER/BRT que le référentiel permet désormais.

## 4. Où les horaires sont affichés

| Écran | Ligne | Ce qui est affiché aujourd'hui |
|---|---|---|
| `StopCard` (liste Explorer) | 2641-2647 | `stop.scheduleStatus == unknown` → « Horaire indisponible » |
| `SingleStopView` (détail arrêt, 2 onglets) | 3935-3937 | « Prochain départ programmé » + « Horaire indisponible » |
| `AssistantReplies.itinerary` | 3400 | « Je ne dispose pas d'un horaire vérifié pour ce trajet. » |
| `AssistantReplies.modeInfo` | ~3450 | se termine par « Je ne dispose d'aucun horaire ni d'aucune fréquence vérifiés pour ce réseau. » |
| `TripsPage` | 2715+ | durées estimées uniquement, aucune heure |
| Popups carte | — | **n'existent pas** : un marqueur ouvre la fiche d'arrêt |

**Constat A4 — il n'existe PAS de « panneau Prochains passages » côté Flutter.** Ce panneau est un
composant de la PWA (`#next-arrivals`). Les équivalents Flutter à brancher sont donc `StopCard`,
`SingleStopView` et l'assistant : c'est là que « prochain passage » est affiché (ou refusé).

**Constat A5 — une phrase de l'assistant est devenue fausse.** « Je ne dispose d'aucune fréquence
vérifiée » était exact le 2026-09-24 ; depuis le référentiel validé, TER et B1/B2 ont des
fréquences sourcées. La phrase doit être corrigée, pas contournée.

## 5. Où l'assistant récupère ses informations

`_AIChatPageState._sendMessage()` (l. 3535+) — routage par mots-clés, sans moteur :

```
« ter|train|diamniadio »      → AssistantReplies.modeInfo('ter', operators, routes)
« brt|guédiawaye|petersen|sunu » → modeInfo('brt')
« ddd|dakar dem dikk|ligne 1… » → modeInfo('ddd')
« tata|minibus|ligne 50 »       → modeInfo('tata')
« aftu|parcelles|grand yoff »   → modeInfo('aftu')
trajet (départ/destination)      → RoutePlanner.plan + AssistantReplies.itinerary
« bouchon|trafic|direct rue »    → refus explicite (aucune donnée)
```

`modeInfo` ne décrit que des comptes de lignes et des provenances : **aucun départ**. L'assistant
n'invente rien aujourd'hui, mais il ne sait pas répondre « quand part le prochain TER ? ».

## 6. Points à modifier, et points à ne pas toucher

**À modifier (strictement nécessaire au branchement)**

1. `DepartureEngineService` : registre chargé une fois (`ensureLoaded`), sélecteur
   `estimateForLine(modeLabel, lineId, stopId, direction, now)`.
2. `Stop` : + `lineId` (issu de `route.id`) et accesseur `departureEstimate({now})` délégué au
   service. **Ajout de champ uniquement** (paramètre nommé optionnel) : aucun appelant cassé.
3. `StopCard` : le widget de droite affiche `DepartureDisplay` (libellé court + badge), à la
   place de la valeur locale.
4. `SingleStopView` : « Prochain passage » + fenêtre + badge + source, à la place de
   `nextDepartureLabel()`.
5. `AssistantReplies.modeInfo` : phrase finale rendue vraie ; **nouveau** `nextDeparture(...)`
   qui formule un `DepartureEstimate` via le moteur.
6. `_sendMessage` : les 5 branches réseau ajoutent la phrase du moteur après `modeInfo`.
7. `main()` : `await DepartureEngineService.ensureLoaded();` (aucun impact visuel).
8. `test/departure_wiring_test.dart` : tests fonctionnels d'intégration (matrice horaire).

**À ne pas toucher**

* **Toute l'UI** : navigation, couleurs, cartes, filtres, recherche, GPS, boutons, typographie,
  icônes, disposition, `AppColors`, `MainShell`, les 5 onglets, les widgets de carte.
* **Les données** : `dakar_network.json` (117 arrêts / 105 routes), `departure-frequencies.json`,
  `data/gtfs/*`. Aucun arrêt, aucune ligne, aucune fréquence ajoutés. KMF/Mbao/Yeumbeul/AIBD
  inchangés, B3 non exposée.
* **`Stop.scheduleStatus` / `nextDepartureMinutes` / `remainingMinutes` / `nextDepartureLabel` /
  `departureAfter`** : conservés tels quels. Trois tests d'audit (`ui_data_reliability_test.dart`)
  les utilisent comme garde-fous « aucun horaire fabriqué » ; les supprimer casserait la
  non-régression (§17). Ils ne servent plus à l'affichage des départs.
* **`RoutePlanner`** : ses tronçons restent `DataStatus.unknown` avec heures `null`, contrat figé
  par `ui_data_reliability_test.dart` (test 5) et `demo_data_cleanup_test.dart` (test 5).
  Brancher les tronçons sur le moteur exigerait de changer ce contrat de test : lot séparé, à
  décider explicitement (aucune régression ici).
* **`DetailedRoute`, `OppositeStopService`, `GpsResolver`, `PositionValidity`, `DakarBounds`**,
  `DataService`, les 15 autres fichiers de test.

---

## 7. Plan de branchement (flux cible)

```
Stop (stopId + lineId + modeLabel)
      ↓ DepartureEngineService.estimateForLine(now: DateTime.now())
DepartureEstimate   ← moteur Dart unique, registre assets/data/departure-frequencies.json
      ↓ DepartureEngineService.displayFor(estimate, now:)
DepartureDisplay → StopCard · SingleStopView · assistant
```

Contraintes vérifiées avant d'écrire une ligne : le vocabulaire d'affichage vient d'une source
unique (`ScheduleStatus.displayLabel()`, `ReliabilityLabel.scheduleUnavailable`) et le miroir
byte-identique du référentiel est déjà contrôlé par la CI J9.
