# GROUPE 7 — AUDIT STRICT : GPS → proximité → arrêts → distance → départs

**Règle appliquée : AUCUNE modification fonctionnelle.** Ce document est le seul artefact produit.
Aucun fichier de `lib/`, `test/`, `assets/` n'a été touché. Aucun déploiement.

- **HEAD audité** : `5fdf9bd` — arbre propre (`git status --porcelain` → 0 entrée)
- **Source auditée** : `flutter-src/lib/main.dart`, 3 272 lignes
- **Donnée** : `assets/data/dakar_network.json`, md5 `81c778f4644dcf5e1cf4ae25879218f0` (inchangé)
- **Version** : `9.3.2+12`
- **Tests** : 231 (comptage local : 17+10+37+40+12+22+34+57+2)
- **Binaire de production comparé** : gh-pages `94a84b60` → `main.dart.js`, 2 497 533 octets,
  blob `4260bdf5a569c753e3470af2cb35b8055c56b43d`

> **Méthode.** Chaque affirmation sur la production est prouvée par lecture directe du binaire
> dart2js (symboles minifiés résolus), jamais par les commentaires du source — un commentaire
> source s'était déjà révélé trompeur en cours d'audit (voir §M, point 3).

---

## A. État de référence

| Élément | Valeur vérifiée |
|---|---|
| HEAD | `5fdf9bd` (branche `arena/01a0c385-dakar-bus`) |
| Arbre Git | propre, 0 entrée |
| JSON | md5 `81c778f4…` inchangé |
| TER | 13 gares (confirmé par simulation de `_integrateNetworkData`) |
| BRT | B1 = 23 stations, B2 = 7 (confirmé idem) |
| Tests | 231 déclarés, CI G6 verte |
| analyze | 0 issue (CI G6) — **non re-exécutable localement** : aucun SDK Flutter dans le sandbox |
| Déploiement | aucun ; gh-pages inchangée |

Le clone local avait été réinitialisé entre sessions (HEAD retombé à `ce8c94f`). Il a été réparé
par `git fetch --depth 12 origin arena/…` + `git reset --mixed FETCH_HEAD` : **aucun contenu
modifié**, historique restauré.

---

## B. GPS réel (§1) — Réponse : **A (position réelle), sans aucun fallback fabriqué**

Chaîne complète, dans `lib/main.dart` :

| Étape | Ligne | Comportement |
|---|---|---|
| `initState` → `_requestLocation()` | 1481, 1511 | déclenchement unique au démarrage |
| `isLocationServiceEnabled()` | 1511+ | faux → `GpsState.serviceDisabled`, « GPS désactivé. » |
| `checkPermission()` / `requestPermission()` | idem | `denied` → « Permission GPS refusée. » ; `deniedForever` → message distinct (D4, Groupe 4) |
| `Geolocator.getPositionStream(accuracy: high, distanceFilter: 10, timeLimit: 20 s)` | 1532+ | flux continu |
| `GpsResolver.fromMeasuredPosition` | 1403 | `null` → `error` ; hors `DakarBounds` → `error` + **position `null`** + « Position hors zone, recentré sur Dakar. » ; valide → `granted` + coordonnée **telle quelle** |
| `onError` / `onDone` / `catch` | 1549, 1551, 1559 | `fromStreamInterrupted(_userPosition)` (L1446) : conserve la dernière position **réelle** valide, sinon `error` |

**Aucune des réponses B (simulée), C (défaut) ou D (mélange) ne s'applique.** L'invariant
`isSubstitutedPosition == false` tient sur tous les chemins (testé, `gps_position_test.dart`).
`_userPosition` (L1476) ne reçoit jamais une coordonnée fabriquée.

Constantes : `DakarBounds` L1287 = nord 14.9 / sud 14.55 / est −16.85 / ouest −17.6, et rejet de
(0,0). `nearbyRadiusMeters = 4000.0` (L1353), `nearbyLimit = 30` (L1357),
`streamDistanceFilterMeters = 10`, `streamTimeLimit = 20 s`.

---

## C. Traçage de la position (§2) — **la même position partout où elle est consommée**

Source unique : `_MainShellState._userPosition` (L1476), écrite uniquement par `_applyGps` (L1507).

**Un seul widget la reçoit** : `ExplorerPage` (L1567). Consommations internes, exhaustives :

| Ligne | Usage |
|---|---|
| 1639-1645 | `didUpdateWidget` → recentrage carte si la position a changé et est valide |
| 1724-1726 | `_filteredStops` : tri haversine + `GpsResolver.nearbyStops` |
| 1759 | `_distanceTo` |
| 1800 | `_openAI()` → `AIChatPage(userPosition: …)` |
| 1872-1873 | `MapOptions.initialCenter` |
| 1899-1900 | marqueur utilisateur |
| 1911 | bouton « me recentrer » |

Puis dans `AIChatPage` : L2850, L2873-2878 (arrêt le plus proche), L2914-2916 (arrêts à proximité).

**Ne reçoivent PAS la position** : `TripsPage`, `AlertsPage`, `CommunityAlertsPage`,
`SettingsPage`, `DualStopDetailPage`, `SingleStopView`, `DetailedRoutePage`.
Aucune copie, aucune transformation, aucune position divergente : **réponse « même position
partout » = OUI**.

---

## D. Arrêt le plus proche (§3)

### D.1 Le chemin GPS — correct 🟢

`GpsResolver.nearbyStops` (L1451-1461) :
```dart
if (userPosition == null) return null;                 // jamais de liste fabriquée
… haversineMeters(userPosition, s.location) < 4000.0   // rayon
… sort(compareTo(haversine…))                          // distance croissante
… take(30)                                             // plafond
```
`_filteredStops` (L1700-1737) : **avec GPS** → tri haversine puis `nearbyStops`, avec repli
`take(30)` si la liste est vide. **Sans GPS** → tri depuis `const dakarCenter = LatLng(14.7167, -17.4677)`
(L1733) puis `take(30)` — tri d'affichage seulement, aucune distance réelle.

Seuils testés aux bornes ±0,1 m (`gps_position_test.dart`) : 3999,9 m inclus, 4000,1 m exclu,
35 arrêts → exactement 30, aucun remplissage.

### D.2 `_findNearestStop` (L1135-1142) — 🔴 contresens : il ne calcule aucune distance

```dart
static Stop? _findNearestStop(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final s in allStops) {
    if (s.name.toLowerCase().contains(q)) return s;      // ← 1er appariement en ordre d'insertion
  }
  return allStops.firstWhere((s) => s.name.toLowerCase().contains('dakar'),
                             orElse: () => allStops.first);   // ← repli silencieux
}
```
- **Aucune distance, aucun GPS, aucune position.** Malgré son nom, c'est un *premier appariement
  de sous-chaîne* dans l'ordre d'insertion de `allStops` (24 arrêts démo d'abord, puis le JSON
  dans l'ordre des lignes).
- **Le repli n'est jamais `null`** : une requête sans correspondance renvoie un arrêt contenant
  « dakar », sinon `allStops.first`. Utilisé par `RoutePlanner` (L1108-1109), donc
  « je veux aller à Thiès » planifie silencieusement un trajet depuis un arrêt dakarois,
  **sans erreur ni UNKNOWN**. Contredit le §12 et la règle verrouillée
  « correspondance non fiable → UNKNOWN ».
- Conséquence aggravée par les homonymes (§F.3) : le résultat dépend de l'ordre d'insertion,
  pas de la géographie.

### D.3 Les deux autres résolveurs — corrects 🟢

- `_resolveJsonStop` (L538-577) : 1) `stopId` exact, 2) nom exact dans le périmètre de
  l'opérateur, 3) plus proche à **`kMaxResolveMeters = 250.0`** (L379) ou moins, **sinon `null`**.
  Documenté « jamais un arrêt inventé ». Conforme §12.
- `AIChatPage` L2873-2882 : plus proche arrêt par haversine, **mais sans aucun plafond de
  rayon** — incohérent avec les 4000 m de `nearbyStops` (§O, point 17).

---

## E. Distance affichée (§4)

### E.1 La règle

```dart
// L1759
double _distanceTo(Stop s) => widget.userPosition == null
    ? s.distanceMeters
    : DistanceHelper.haversineMeters(widget.userPosition!, s.location);
```
**Point d'affichage unique** : L2123, sous-titre du `StopCard`
(`'${DistanceHelper.format(distanceMeters)} • ${stop.modeLabel} (${stop.source.badgeEmoji}) • $crowd'`),
alimenté par L2013. Second appel : L2916 (`AIChatPage`, « Tu es près de », distance **réelle**
uniquement, calculée en L2915).

`DualStopDetailPage` et `SingleStopView` **n'affichent aucune distance** (elles ne reçoivent pas
la position).

### E.2 Origine de `distanceMeters` — trois sources, aucune géographique

| Source | Ligne | Valeur | Population |
|---|---|---|---|
| Littéraux de démonstration | 751-788 | 150 / 200 / 300 / 350 / 450 / 500 / 800 / 900 / 1100 / 1200 / 1300 / 1500 / 1800 / 2100 / 2400 / 3100 / 3500 / 7200 / 10500 / 14200 / 35000 | **24 arrêts** |
| Intégration JSON | **974** | **`300 + (i * 800).toDouble()`** | **117 arrêts** |
| Chemin « orphelins » | **1027** | `500` constant | **0 arrêt** (voir E.4) |

À L974, `i` est l'index de l'arrêt **dans la liste d'arrêts de sa ligne** (`route.stopIds`), et
seule la **première** ligne qui atteint un arrêt le crée (déduplication `existingKeys`, L890,
clé `name_latitude_longitude`). Donc :

> `distanceMeters` d'un arrêt JSON = **300 + 800 × (son index dans la première ligne qui l'a créé)**.

Valeurs réellement produites (simulation fidèle de `_integrateNetworkData` sur le JSON courant) :

| Ligne | arrêts | `distanceMeters` |
|---|---|---|
| TER (13 gares) | i = 0…12 | 300, 1100, 1900, 2700, 3500, 4300, 5100, 5900, 6700, 7500, 8300, 9100, **9900 m** |
| BRT B1 (23 stations) | i = 0…22 | 300 → **17 900 m** (pas de 800) |
| DDD (32) / AFTU (41) / Tata (8) | i variable | 300 → 3500 m |

Minimum 300 m, maximum 17 900 m, médiane 1 900 m.

**Statut : valeur synthétique dérivée d'un index, sans signification géographique.** Elle n'est
pas « fausse » au sens d'un bug de calcul : elle est **fabriquée**, puis **affichée comme une
distance à l'utilisateur** quand le GPS est absent. Conformément à la consigne, son origine et
son statut sont établis plutôt que présumés — et elle est **production-fidèle** (§M).

### E.3 Le chemin « orphelins » (L1014-1040) est actuellement inatteignable

La simulation crée **117 arrêts**, soit exactement le nombre total d'entrées de `stops` dans le
JSON : la boucle des orphelins ne rencontre donc que des clés déjà présentes et n'ajoute **rien**.
Ses valeurs codées en dur (`distanceMeters: 500`, `label = 'AFTU'`, `direction: 'Dir. Centre Dakar'`,
horaires vides) sont du **code dormant** — présent et identique dans la production (§M).

### E.4 Bilan des 141 arrêts exposés

24 littéraux + 117 JSON = **141 arrêts** dans `allStops`. 347 occurrences d'arrêts partagés entre
les 105 lignes ont été ignorées par la déduplication. 0 arrêt hors bornes, 0 identifiant manquant.

---

## F. Distance réelle vs distance statique (§5)

| Situation | Valeur utilisée | Nature | Affichée comme distance utilisateur ? |
|---|---|---|---|
| GPS `granted`, position dans `DakarBounds` | `haversineMeters(userPosition, s.location)` | **réelle** | oui ✅ |
| GPS absent (jamais obtenu) | `s.distanceMeters` | **synthétique** | oui ❌ |
| GPS refusé (`denied` / `deniedForever`) | `s.distanceMeters` | **synthétique** | oui ❌ |
| Service de localisation désactivé | `s.distanceMeters` | **synthétique** | oui ❌ |
| Erreur / flux interrompu sans mesure antérieure | `s.distanceMeters` | **synthétique** | oui ❌ |
| Position hors zone | `s.distanceMeters` (position mise à `null` par D1-i) | **synthétique** | oui ❌ |
| Flux interrompu **avec** mesure antérieure valide | haversine sur la dernière position réelle | réelle (périmée) | oui ✅ |
| Arrêt sélectionné manuellement (carte, recherche, liste) | — | — | **aucune distance affichée** (fiche détail) |
| Explorer sans GPS : **tri** de la liste | distance à `(14.7167, −17.4677)` | **centre fabriqué** | non (tri seul), mais ordre visible |
| `AIChatPage` « Tu es près de » | haversine réelle | réelle | oui ✅ |
| `DetailedRoutePage` : distances de ligne | cumul haversine entre arrêts | **réelle** | oui ✅ |

**Aucun indicateur visuel ne distingue les deux régimes.** Le même texte, au même endroit, avec
la même mise en forme, affiche une distance mesurée ou une valeur `300 + i×800`.

### F.3 Homonymes dupliqués — 🔴 conséquence directe sur les distances

La clé de déduplication `name_latitude_longitude` laisse passer des arrêts de **même nom et de
coordonnées différentes**. 5 noms produisent 11 entrées, soit **6 entrées surnuméraires** :

| Nom | Occurrences | Écart géographique | Écart de `distanceMeters` affiché (sans GPS) |
|---|---|---|---|
| **Gare TER Dakar** | 3 (2 démo + 1 JSON) | **851 m** | 50 m |
| Gare TER Diamniadio | 2 (démo, arrivée/embarquement) | 73 m | 0 m |
| **Hôpital Dalal Jamm - BRT** | 2 (BRT B1 + AFTU 3) | **1 209 m** | 800 m |
| **Liberté 6 - BRT Correspondance** | 2 (BRT B1 + DDD 10) | **1 028 m** | **11 200 m** |
| **Sacré-Cœur - BRT** | 2 (BRT B1 + DDD 15) | **751 m** | **11 200 m** |

Impact fonctionnel : recherche ambiguë, tri de proximité incohérent, et **deux entrées de même
nom affichant des distances à l'usager différant de 11,2 km**. La paire « Gare TER Diamniadio »
(73 m, arrivée vs embarquement) est intentionnelle 🟢 ; les quatre autres ne le sont pas.

---

## G. Conversion distance → temps (§6) — **aucune valeur modifiée**

### G.1 Il n'existe aucune conversion distance → temps de marche

`DistanceHelper.format` (L1207-1210) ne produit que des distances :
```dart
if (meters < 1000) return '${meters.round()} m';
return '${(meters / 1000.0).toStringAsFixed(1)} km';
```
Aucun segment de code ne convertit une distance en minutes de marche.

### G.2 Les seules conversions distance → minutes sont des vitesses **véhicule**

| Lieu | Ligne | Formule | Vitesse |
|---|---|---|---|
| `RoutePlanner._buildRoute` | 1146-1147 | `dur = ((dist/1000)/speed*60).ceil()`, plancher 5 min | **35 km/h** si TER ou BRT, **20 km/h** sinon |
| `DetailedRoute` (temps par arrêt) | 495 | `~(index × 3) min` | aucune distance : index |

Ces vitesses ne sont **pas** des vitesses de marche et ne sont jamais présentées comme telles.

### G.3 🔴 `DistanceHelper.format` diverge du formateur de la production

Le binaire contient le formateur `A.azr`, appelé exactement aux mêmes endroits (sous-titre de
`StopCard`, `AIChatPage`) :
```js
azr(a){ if (a < 950) return "" + round(a) + " m";
        s = a/1000;
        if (s < 10) return s.toStringAsFixed(1) + " km";
        return "" + round(s) + " km"; }
```

| Distance | Source (`format`) | Production (`azr`) | |
|---|---|---|---|
| 949 m | `949 m` | `949 m` | ✅ |
| **950 m** | `950 m` | `0.9 km` | ❌ |
| **951–999 m** | `951 m`…`999 m` | `1.0 km` | ❌ |
| 1 000 m | `1.0 km` | `1.0 km` | ✅ |
| 1 500 m | `1.5 km` | `1.5 km` | ✅ |
| 9 999 m | `10.0 km` | `10.0 km` | ✅ |
| **10 000 m** | `10.0 km` | `10 km` | ❌ |
| **12 345 m** | `12.3 km` | `12 km` | ❌ |
| **17 900 m** | `17.9 km` | `18 km` | ❌ |
| **35 000 m** | `35.0 km` | `35 km` | ❌ |

Deux différences structurelles, certaines d'après le binaire :
1. **seuil mètres/kilomètres** : 950 en production, 1000 dans le source ;
2. **au-delà de 10 km** : la production arrondit à l'entier, le source conserve une décimale.

Portée réelle : la bande 950-999 m n'est atteinte **que** par des distances GPS réelles (les
valeurs statiques `300+i×800` et les littéraux démo ne tombent jamais dedans) ; la bande ≥ 10 km
concerne **14 des 141 arrêts** sans GPS (10 stations B1 d'index ≥ 13, 3 arrêts TER démo dont
2 à 35 km, 1 arrêt BRT démo à 10,5 km) et toute distance GPS réelle ≥ 10 km.

Ni l'une ni l'autre implémentation n'est « fausse » en soi ; elles **diffèrent**, et le source
s'écarte donc de la production sur l'affichage de toutes les distances ≥ 10 km.

---

## H. Horaires et prochains départs (§7)

### H.1 Les bases — 100 % synthétiques, le JSON ne contient aucun horaire

```dart
// L253-262
List<int> _generateSchedule({required int from, required int to, required int step}) {
  final list = <int>[];
  for (int m = from; m <= to; m += step) { list.add(m); }
  return list;
}
List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);
final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
final List<int> _terBase = _buildTerBase();
```

| Base | Plage | Pas | Entrées | Premier / dernier |
|---|---|---|---|---|
| `_brtBase` | 360→1260 | 6 min | 151 | 06:00 / 21:00 |
| `_terBase` (lun–sam) | 330→1320 | 10 min | 100 | 05:30 / 22:00 |
| `_terBase` (dimanche) | 330→1320 | 20 min | 50 | 05:30 / **21:50** |

`assets/data/dakar_network.json` ne porte, par arrêt, que `id`, `name`, `latitude`, `longitude`,
`data_trust` : **aucun champ horaire**. Tous les horaires sont donc synthétiques (verrouillé :
« horaires synthétiques »).

Attribution dans `_integrateNetworkData` (L960-966) :
- `label == 'TER'` → `_shift(_terBase, i * 2)` → offsets **+0 à +24 min** pour les 13 gares
- `label == 'BRT'` → `_shift(_brtBase, i * 2)` → offsets **+0 à +44 min** pour les 23 stations B1
- sinon (AFTU / Tata / DDD) → **liste vide** → `isContinuousFlow == true`

Aucun décalage ne fait sortir de la journée : max TER 1320+24 = 1344 (22:24), max BRT
1260+44 = 1304 (21:44), tous deux ≤ 1440 et dans la fenêtre de service.

### H.2 🔴 `_isSunday()` n'est évalué qu'une seule fois

`_terBase` est un `final` **top-level** (L262) : `_buildTerBase()` — donc `_isSunday()` — est
exécuté au premier accès et **jamais réévalué**. Une session ouverte à cheval sur minuit conserve
la grille du jour précédent (pas de 10 min au lieu de 20, ou l'inverse) jusqu'à rechargement.

De plus, `_isSunday()`, `_isServiceOpen()`, `nextDepartureMinutes()`, `remainingMinutes()` et
`getCrowdLevel()` utilisent tous `DateTime.now()` = **heure locale de l'appareil**, alors que
Dakar est à UTC+0 sans heure d'été. Pour un appareil en Europe/Paris, toutes les fenêtres
(ouverture de service, heure de pointe, dimanche) sont décalées de 1 à 2 heures.

### H.3 La logique d'attente (L672-716)

```dart
bool get isContinuousFlow => modeLabel == 'AFTU' || modeLabel == 'Tata' || modeLabel == 'DDD';

bool _isServiceOpen() {                       // L674
  final hour = DateTime.now().hour;
  int startHour = isContinuousFlow ? 6 : 5;
  if (hour >= startHour && hour < 22) return true;
  if (!isContinuousFlow && hour == 22 && now.minute <= 30) return true;   // 22:30 TER/BRT seulement
  return false;
}

int? nextDepartureMinutes() {                 // L683
  if (!_isServiceOpen()) return null;
  if (isContinuousFlow) return 5;             // ← constante, jamais mesurée
  final currentMin = now.hour*60 + now.minute;
  for (final d in departureMinutesFromMidnight) {
    if (d >= currentMin && (d - currentMin) <= 180) return d;    // horizon 3 h
  }
  return null;                                // ← aucun report au lendemain
}

int? remainingMinutes() {                     // L694
  if (!_isServiceOpen()) return null;
  if (isContinuousFlow) return 5;
  final d = nextDepartureMinutes();
  if (d == null) return null;
  return d - (DateTime.now().hour*60 + DateTime.now().minute);   // ← 2e appel à now()
}
```

| Question posée | Réponse établie |
|---|---|
| JSON vs synthétique | **100 % synthétique.** Le JSON n'a aucun horaire. |
| Dernier départ passé | `null` → badge « Bientôt », étiquette « Prochainement ». **Jamais** « plus de départ aujourd'hui ». |
| Report au lendemain | **Aucun.** Aucune fonction ne reboucle sur le premier départ du jour suivant. |
| Dimanche | `_terBase` passe à un pas de 20 min — **mais une seule fois par session** (H.2). BRT, AFTU, Tata, DDD : aucune différence dimanche. |
| Flux continu (AFTU/Tata/DDD) | `remainingMinutes() == 5` en permanence, pour les **81 arrêts** concernés, à toute heure de 06:00 à 22:00. Étiquette « En rotation (~5 min) ». Valeur codée en dur, non mesurée. |
| Fenêtre de service | TER/BRT 05:00→22:30 ; AFTU/Tata/DDD 06:00→22:00. |
| Rafraîchissement | `Timer.periodic(15 s)` (L1484) → `setState`, correctement annulé (L1494). |

### H.4 🟠 Deux logiques d'ouverture contradictoires dans `StopCard`

`StopCard` (L2078) recalcule sa **propre** fenêtre, codée en dur :
```dart
final bool isOpen = (now.hour >= 5 && now.hour < 22) || (now.hour == 22 && now.minute <= 30);
```
puis affiche `Fermé` / `Bientôt` / `Imminent` / `N min` d'après `stop.remainingMinutes()` —
lequel utilise `_isServiceOpen()` (L674), où le démarrage est `isContinuousFlow ? 6 : 5` et où
l'extension à 22:30 est réservée aux modes non continus.

Conséquence pour AFTU / Tata / DDD, dans **deux fenêtres quotidiennes** :
- **05:00–05:59** : `isOpen == true` mais `_isServiceOpen() == false` → `remaining == null` → **« Bientôt »** alors que le service est fermé ;
- **22:00–22:30** : idem → **« Bientôt »** alors que le service est fermé.

Cette double logique est **production-fidèle** : le binaire inline exactement `>=5` dans
`A.aiK.$2` tout en ayant `Stop.xt()` avec `gqy()?6:5`. Ce n'est donc pas une régression, mais
c'est un défaut fonctionnel réel et reproductible.

### H.5 🟡 `remainingMinutes()` peut renvoyer `-1`

L694-700 appelle `DateTime.now()` une seconde fois après `nextDepartureMinutes()`. Si la minute
change entre les deux, `d - currentMin` vaut `-1`. Le badge affiche alors « Imminent » (L2085,
branche `remaining <= 0`) — donc l'effet visible est bénin, mais la valeur retournée est
incohérente et le `Timer.periodic(15 s)` rend le cas atteignable.

---

## I. `DataStatus` (§8) et §9

```dart
enum DataStatus { scheduled, live, unknown }      // L719
```

Occurrences **exhaustives** dans `lib/` :

| Ligne | Usage |
|---|---|
| 647 | `Stop(… this.status = DataStatus.scheduled)` — valeur par défaut |
| 732 | `RouteSegment(… this.status = DataStatus.scheduled)` — valeur par défaut |
| 738 | `PlannedRoute(… this.status = DataStatus.scheduled)` — valeur par défaut |
| 1156, 1157, 1173 | `status: DataStatus.scheduled` explicite |

- **`DataStatus.live` : jamais assigné.** 0 assignation dans `lib/`. Gardé par 3 tests
  (`gps_position_test.dart`) + 1 (`groupe6_alertes_test.dart`), et documenté aux L1302, 1333,
  2409, 2524, 2631.
- **`DataStatus.unknown` : jamais assigné ET jamais référencé.** **0 occurrence** dans `lib/`
  comme dans `test/`. Valeur d'énumération morte.
- **`DataStatus.scheduled` : 0 occurrence dans `test/`** (seulement via les valeurs par défaut).

**Réponse §9 : confirmée.** `DataStatus` est, en pratique, une énumération à **une seule valeur
effective**. Le triplet SCHEDULED / REAL_TIME / UNKNOWN exigé n'est pas exprimable par le modèle
tel qu'il est utilisé : aucun objet ne peut jamais porter `live` ni `unknown`.

### §8 — Occurrences « LIVE » / « temps réel » face utilisateur

**Aucun badge « LIVE », « En direct » ou « REAL_TIME » n'existe dans l'interface.** Groupe 6
(E.3) a remplacé « En direct » par « Données officielles ». Deux revendications subsistent :

| Ligne | Texte | Statut |
|---|---|---|
| **2741** (`SettingsPage`, modale d'aide) | « …visualiser votre position GPS **en temps réel** et les arrêts à proximité. » | 🟡 partiellement fondé : le flux GPS + le ticker 15 s rendent bien la *position* vivante quand le GPS fonctionne ; rien ne qualifie le cas GPS absent (distances synthétiques, tri sur centre fabriqué). |
| **2922** (`AIChatPage`) | « 🚨 **Alertes en temps réel** : consulte l'onglet "Alertes" (CETUD/SETER) et "Direct rue"… » | 🟠 **non fondé** et **en contradiction avec la correction E.4/E.5 du Groupe 6**, qui a retiré « en temps réel » de `CommunityAlertsPage` au motif qu'aucun flux temps réel n'existe. `AIChatPage` étant verrouillé, ce point est à reporter sur le Groupe 9 (comme le « 14 gares »). |

Toutes les autres occurrences de « temps réel » dans `lib/` sont des **commentaires** documentant
son retrait.

---

## J. Les « inconnus » honnêtes : où ils existent, où ils manquent

| Chemin | Comportement | Verdict |
|---|---|---|
| `_resolveJsonStop` (L538) | `null` au-delà de 250 m | 🟢 conforme §12 |
| `OppositeStopService` (L218, 237) | `null` si > 120 m (passe 1) ou > 500 m / mode ou sens inadéquat (passe 2) | 🟢 conforme |
| `DetailedRoute.fromStop` | `null` si ligne indérivable | 🟢 conforme (Groupe 2 §8) |
| `GpsResolver.nearbyStops` | `null` sans position ; liste vide si aucun arrêt dans le rayon, jamais de substitution | 🟢 conforme |
| `GpsResolver.fromMeasuredPosition` | position `null` + `error` hors zone | 🟢 conforme (D1-i) |
| **`_findNearestStop` (L1135)** | **jamais `null`** (sauf requête vide) : repli sur un arrêt contenant « dakar » | 🔴 **non conforme** |
| **`nextDepartureLabel()` (L702)** | « Prochainement » quand aucun départ dans les 3 h | 🟡 euphémisme : ne dit pas « plus de départ aujourd'hui » |
| **`DataStatus.unknown`** | jamais utilisé | 🔴 le modèle ne peut pas exprimer l'inconnu |
| **`distanceMeters` sans GPS** | valeur synthétique affichée sans qualification | 🔴 pas d'état « inconnu » |

---

## K. Arrêt sélectionné manuellement (§10)

### K.1 Les quatre points d'entrée

| Entrée | Ligne | Effet |
|---|---|---|
| Marqueur carte (appui) | 1887 | `_centerOnStop(s)` **+** `DualStopDetailPage(stop: s)` |
| Résultat de recherche | 1998 | remplit le champ, ferme le focus, `_centerOnStop(s)` — **n'ouvre pas la fiche** |
| Carte de la liste Explorer | 2013 | `GestureDetector` → `_centerOnStop(s)` ; le `ListTile` interne (L2107) → `DualStopDetailPage(stop: stop)` |
| Assistant IA | 2873-2882, 2914-2916 | résolution par haversine sur la position, si présente |

`_centerOnStop` (L1789) : `_mapController.move(s.location, _zoomOnStop)` dans un `try/catch`.

### K.2 Réponses aux questions posées

- **Coordonnées utilisées ?** Celles de l'arrêt **lui-même** (`s.location`), pour le centrage
  comme pour la fiche. Jamais celles du GPS.
- **Le GPS intervient-il ?** **Non.** `DualStopDetailPage` (L3093) et `SingleStopView` (L3174)
  sont des `StatelessWidget` qui ne reçoivent **que** `stop`. Aucune position, aucun état GPS.
- **Une distance est-elle affichée ?** **Non.** La fiche affiche « Prochain départ »
  (`nextDepartureLabel()`, L3234) et « Affluence » (`getCrowdLevel`), jamais de distance.
- **Les départs ?** Ceux de `stop.departureMinutesFromMidnight`, c'est-à-dire la liste
  synthétique `_shift(_terBase|_brtBase, i*2)` ou la liste vide (flux continu → « 5 min »).
- **L'arrêt précédent est-il conservé ?** **Non.** Chaque appui pousse une page neuve construite
  depuis l'objet `Stop` tapé. `_userPosition` n'est **jamais** modifié par une sélection
  manuelle : la liste Explorer continue de se trier et de se filtrer sur le GPS (ou, sans GPS,
  sur le centre fabriqué L1733).
- **Différence entre modes (TER / BRT / AFTU / Tata / DDD) ?** Le chemin de sélection est
  **identique** pour tous. Seuls changent, dans la fiche : `isContinuousFlow` (donc « 5 min » vs
  horaires), la couleur, l'icône, le label de source, et `DetailedRoute.fromStop` (qui renvoie
  `null` si la ligne n'est pas dérivable).
- **Sens aller / retour** : `allerStop = stop.copyWith(direction: …, stopType: boarding)` ;
  `retourStop = OppositeStopService.findOppositeStop(…)`, conservé `null` si non fiable
  (Groupe 3) — l'onglet affiche alors un état « non identifié » explicite. 🟢

### K.3 🟡 La recherche

```dart
// L1690
allStops.where((s) => (s.name.toLowerCase().contains(q)
                    || s.direction.toLowerCase().contains(q))
                   && DakarBounds.isValid(s.location)).take(8).toList();
```
Ordre d'**insertion** (ni pertinence, ni distance, ni alphabet) ; plafond 8 ; les homonymes de
§F.3 apparaissent côte à côte sans rien qui les distingue ; taper un résultat **centre la carte
sans ouvrir la fiche**, ce qui oblige à retrouver le marqueur.

---

## L. Données de démonstration (§11) — classification

| Élément | Ligne | Classe | Justification |
|---|---|---|---|
| Coordonnées des 117 arrêts JSON | `assets/data` | **JSON / métier** | source unique, verrouillée |
| 13 gares TER, 23 stations B1, 7 B2 | JSON | **JSON / métier** | confirmé par simulation |
| Polylignes de la carte | 1041+ | **calcul** | dérivées du JSON, aucun littéral codé en dur |
| `totalDistance`, `distanceFromStart` | 487 | **calcul** | cumul haversine, testé (34.6 / 17.5 / 16.0 km) |
| Distances GPS de `_distanceTo`, `nearbyStops`, `AIChatPage` | 1759, 1455, 2915 | **calcul** | haversine sur position réelle |
| `distanceMeters` des 117 arrêts JSON (`300 + i*800`) | 974 | **démo / synthétique** | dérivé d'un index, sans base géographique |
| `distanceMeters` des 24 arrêts littéraux | 751-788 | **démo** | littéraux codés en dur |
| `distanceMeters: 500` du chemin orphelins | 1027 | **démo — code dormant** | 0 orphelin avec le JSON courant |
| Les 24 arrêts littéraux eux-mêmes | 751-788 | **démo** | doublonnent partiellement le JSON (Gare TER Dakar ×3) |
| `_terBase`, `_brtBase`, `_shift(…, i*2)` | 253-262, 960-966 | **synthétique (verrouillé)** | aucun horaire dans le JSON |
| `remainingMinutes() == 5` en flux continu | 685, 696 | **synthétique** | constante, non mesurée |
| `getCrowdLevel` (« Affluence ») | 1194-1203 | **synthétique** | purement horloger, **paramètre `stop` inutilisé**, valeur identique pour les 141 arrêts |
| `direction` des arrêts JSON (`'Dir. <dernier arrêt>'`) | 969-971 | **synthétique** | le JSON n'a aucun champ de sens |
| `direction: 'Dir. Centre Dakar'` (orphelins) | 1025 | **démo — dormant** | codée en dur |
| Centre de tri sans GPS `(14.7167, −17.4677)` | 1733 | **fallback** | production-fidèle (`B.hA`) |
| Centre de carte `(14.7200, −17.4300)` | 1614 | **fallback** | production-fidèle (`B.IR`) |
| Centre de carte `DetailedRoutePage` | 3030 | **fallback** | production-fidèle |
| Vitesse 35 / 20 km/h | 1146-1147 | **calcul (hypothèse)** | vitesse véhicule, non sourcée |
| 3 min par arrêt (`estimatedTime`) | 495 | **synthétique** | index × 3 |
| `_findNearestStop` repli « dakar » | 1141 | **fallback inventé** | 🔴 substitue un arrêt à une absence de résultat |
| `DataStatus.live`, `DataStatus.unknown` | 719 | **UNKNOWN** | déclarés, jamais assignés |

---

## M. Production vs source actuel (§12)

**Aucune restauration automatique.** Tableau comparatif établi sur le binaire `94a84b60`.

| # | Élément | Production (binaire) | Source actuel | Verdict |
|---|---|---|---|---|
| 1 | Distance synthétique | `300+a2*800`, 3ᵉ argument de `A.cg` | `300 + (i * 800)` L974 | 🟢 **fidèle** |
| 2 | Repli de distance | `q==null ? a.c : A.ew(q,a.r)` (`A.apw.$1`) | `widget.userPosition == null ? s.distanceMeters : haversine(…)` L1759 | 🟢 **fidèle, à l'identique** |
| 3 | Méthode GPS | `$.IM().Kd(B.Lf).apR(new A.arr(this), !1, new A.ars())` dans `ahF()`, avec `if(s!=null) s.au(0)` (cancel) | `getPositionStream(…).listen(…)` L1532+, `_positionSub?.cancel()` | 🟢 **fidèle** — `Kd` est le nom minifié de `getPositionStream` |
| 4 | Réglages du flux | `B.Lf = new A.uy(B.kq, 10, B.FZ)` ; `B.kq = LocationAccuracy.high` ; `B.FZ = Duration(2e7 µs)` = **20 s** ; distanceFilter **10** | `accuracy: high, distanceFilter: 10, timeLimit: 20 s` | 🟢 **fidèle, valeurs identiques** |
| 5 | Chemin ponctuel | **existe aussi** : `$.IM().lH(0, j.aV())` = `getCurrentPosition(LocationSettings(high, 0, B.jN))`, `B.jN = Duration(1e7 µs)` = **10 s** | **absent** : `_requestLocation` n'utilise que le flux | 🟠 **divergence** (voir M.1) |
| 6 | Position hors zone | `A.arn.$0(){ s.r = B.hA; s.w = B.ht; s.x = "Position hors zone, recentré sur Dakar." }` → **substitue (14.7167, −17.4677) et passe l'état à `granted`** | position `null` + `error`, message conservé (D1-i) | 🟢 **divergence volontaire documentée** : le source corrige un défaut réel de la production |
| 7 | Erreur de flux | `A.ars.$1(a){}` → **corps vide**, erreur avalée | `onError` → `fromStreamInterrupted`, conserve la dernière position valide | 🟢 **amélioration** |
| 8 | Rayon de proximité | `A.ap3.$1(a){ return A.ew(s, a.r) < 4000 }` | `nearbyRadiusMeters = 4000.0` L1353 | 🟢 **fidèle** |
| 9 | Tri sans GPS | `A.ap4.$2(a,b){ return A.ew(B.hA,a.r).compareTo(A.ew(B.hA,b.r)) }` | `dakarCenter = LatLng(14.7167, -17.4677)` L1733 | 🟢 **fidèle, même coordonnée** |
| 10 | Centre de carte Explorer | `B.IR = new A.aE(14.72,-17.43)` ; `A.apz.$2` : `e = (position valide) ? position : B.IR; A.aEX(e, 11.2, 17, 9)` | `_dakarCenter = LatLng(14.7200, -17.4300)` L1614 ; `initialZoom` 11.2 | 🟢 **fidèle** — les **deux** centres existent en production, distants de **4,07 km** |
| 11 | Centre de carte fiche ligne | `A.aEX(j.length!==0 ? B.b.gM(j) : B.hA, 11.5, …)` | L3030 : `validPoints.isNotEmpty ? validPoints.first : LatLng(14.7167,-17.4677)`, zoom 11.5 | 🟡 **quasi fidèle** : la production prend le **dernier** point (`gM`), le source le **premier** |
| 12 | Clé de déduplication | `A.awP.$1(a){ return a.a+"_"+A.j(s.a)+"_"+A.j(s.b) }` et `b2 = h+"_"+A.j(g)+"_"+A.j(f)` | `'${s.name}_${s.location.latitude}_${s.location.longitude}'` L890, L1016 | 🟢 **fidèle** → les homonymes dupliqués de §F.3 existent **aussi** en production |
| 13 | Chemin orphelins | `new A.cg(h,"Dir. Centre Dakar",500,a0,…,"AFTU",…)` | L1023-1035, identique | 🟢 **fidèle** (dormant des deux côtés) |
| 14 | Formateur de distance | `A.azr` : seuil **950**, entier **≥ 10 km** | `DistanceHelper.format` : seuil **1000**, 1 décimale toujours | 🔴 **divergence** (§G.3) |
| 15 | Fenêtre de service (modèle) | `Stop.xt()` : `r >= (gqy()?6:5) && r<22`, plus `r===22 && min<=30` si `!gqy()` | `_isServiceOpen()` L674-681 | 🟢 **fidèle, à l'identique** |
| 16 | Fenêtre de service (carte) | inline dans `A.aiK.$2` : `A.jq(a0)>=5 && <22`, ou `===22 && <=30` | inline L2078 : `now.hour >= 5 && < 22`, ou `== 22 && <= 30` | 🟢 **fidèle, à l'identique** — y compris la contradiction interne (§H.4) |
| 17 | Badge de départ | `Fermé` / `Bientôt` (`b==null`) / `Imminent` (`b<=0`) / `A.aTn(b)` | `Fermé` / `Bientôt` / `Imminent` / `TimeHelper.formatRemaining` | 🟢 **fidèle** |
| 18 | `formatRemaining` | `aTn(a){ if(a<=0) return "Imminent"; if(a===1) return "1 min"; return ""+a+" min" }` | L1188-1192, identique | 🟢 **fidèle, à l'identique** |
| 19 | Affluence | `akL(a){ r=hour(now); (7..9‖17..19)→"🔴 Bondé (Heure de pointe)"; (10..16)→"🟠 Dense"; else "🟢 Fluide" }` — **paramètre `a` inutilisé** | L1194-1203, identique, **paramètre `stop` inutilisé** | 🟢 **fidèle, à l'identique** |
| 20 | Sous-titre `StopCard` | `got() + " • " + azr(distance) + " • " + modeLabel + " (" + badgeEmoji + ") • " + crowd` — **4 segments** | `format(distance) + " • " + modeLabel + " (" + badgeEmoji + ") • " + crowd` — **3 segments** | 🟠 **divergence** : `got()` = `lines.isEmpty ? modeLabel : lines.join(" · ")` ; le `Stop` du source n'a **aucun champ `lines`** (0 occurrence dans `lib/`) |
| 21 | Haversine | `A.ew` : `12742017.6 * asin(sqrt(…))` (forme diamètre) | `2 * 6371008.8` L1229 | 🟢 **fidèle** (même rayon) |
| 22 | `GpsState` | 6 valeurs : `granted(2)`, `denied(3)`, `serviceDisabled(4)`, `error(5)` + 2 — **pas de `deniedForever`** | 7 valeurs, `deniedForever` assigné (D4) | 🟢 **amélioration documentée** |
| 23 | Message permission | `"Permission GPS refusée."` (un seul) | messages distincts `denied` / `deniedForever` | 🟢 **amélioration** (D4) |

### M.1 Conséquence fonctionnelle du point 5 (chemin ponctuel supprimé)

La production offrait **deux** chemins : le flux au démarrage (`ahF`) **et** un
`getCurrentPosition` ponctuel (timeLimit 10 s) renvoyant un résultat immédiat. Le source n'a
plus que le flux, y compris pour le bouton « Activer GPS » (`onRequestLocation: _requestLocation`).

Avec `distanceFilter: 10` et `timeLimit: 20 s`, un utilisateur **immobile** peut ne recevoir
aucun événement pendant 20 s, puis `onDone` → `fromStreamInterrupted(null)` → **« Erreur GPS. »**,
alors que la production aurait renvoyé une position en ≤ 10 s. Appuyer à nouveau relance bien une
fenêtre de 20 s (le bouton n'est pas mort), mais la latence perçue et le taux d'échec au premier
appui sont dégradés. **Aucun redémarrage automatique n'existe** (choix documenté du Groupe 4).

### M.2 Le commentaire source L1532-1534 est exact

Il affirme : *« AVANT : `getCurrentPosition(desiredAccuracy: high, timeLimit: 10 s)` — APRÈS :
`getPositionStream(locationSettings: B.Lf)` »*. Le binaire confirme **les deux** :
`B.jN = 1e7 µs = 10 s` pour le ponctuel, `B.Lf = LocationSettings(high, 10, 20 s)` pour le flux.
Une première lecture par chaînes littérales avait conclu à tort que `getPositionStream` était
absent de la production : il est simplement **minifié en `Kd`**. Méthode retenue pour la suite :
ne jamais conclure sur une recherche de nom de méthode sans énumérer aussi les appels minifiés.

---

## N. Analyse des 231 tests (§13) — **aucun test ajouté**

### N.1 Inventaire

| Fichier | Tests |
|---|---|
| `dakar_bounds_test.dart` | 17 |
| `data_service_test.dart` | 10 |
| `detailed_route_test.dart` | 37 |
| `gps_position_test.dart` | 40 |
| `groupe6_alertes_test.dart` | 12 |
| `network_data_test.dart` | 22 |
| `opposite_stop_test.dart` | 34 |
| `ter_brt_route_data_test.dart` | 57 |
| `widget_test.dart` | 2 |
| **Total** | **231** ✅ conforme à la CI |

### N.2 🔴 Couverture **nulle** de la chaîne horaires → temps d'attente

Références dans `test/` (recherche par symbole, pas par intitulé) :

| Symbole | Réf. | | Symbole | Réf. |
|---|---|---|---|---|
| `_generateSchedule` | **0** | | `_distanceTo` | **0** |
| `_buildTerBase` | **0** | | `_integrateNetworkData` | **0** |
| `_terBase` | **0** | | `_findNearestStop` | **0** |
| `_brtBase` | **0** | | `_filteredStops` | **0** |
| `_shift` | **0** | | `_resolveJsonStop` | **0** |
| `_isSunday` | **0** | | `kMaxResolveMeters` | **0** |
| `_isServiceOpen` | **0** | | `DataStatus.unknown` | **0** |
| `remainingMinutes` | **0** | | `DataStatus.scheduled` | **0** |
| `nextDepartureMinutes` | **0** | | `14.7200` (`_dakarCenter`) | **0** |
| `nextDepartureLabel` | **0** | | `300 +` (formule de distance) | **0** |
| `departureAfter` | **0** | | `existingKeys` (déduplication) | **0** |

**Aucun test ne vérifie le temps d'attente affiché à l'utilisateur.** Les 231 tests verts ne
garantissent rien sur : les bases horaires, le pas dominical, l'horizon de 3 h, l'absence de
report au lendemain, la constante « 5 min » du flux continu, les fenêtres de service
contradictoires de §H.4, le `-1` de §H.5, la formule `300 + i*800`, la déduplication et les
homonymes de §F.3, ni le repli de `_distanceTo`.

### N.3 Ce qui **est** couvert

| Symbole | Réf. | Fichier |
|---|---|---|
| `GpsResolver` | 70 | `gps_position_test.dart` |
| `DakarBounds` | 38 | 4 fichiers |
| `allStops` | 35 | `opposite_stop_test`, `ter_brt_route_data_test` |
| `OppositeStopService` | 32 | `opposite_stop_test.dart` |
| `haversineMeters` | 24 | 3 fichiers |
| `nearbyStops` | 15 | `gps_position_test.dart` |
| `fromMeasuredPosition` | 12 | `gps_position_test.dart` |
| `14.7167` | 6 | `gps_position_test.dart` (garde-fou D1-i) |
| `fromStreamInterrupted` | 6 | `gps_position_test.dart` |
| `DataStatus.live` | 4 | garde-fous « jamais assigné » |
| `DistanceHelper.format` | 3 | `dakar_bounds_test.dart` L110-111, 119 |
| `distanceMeters` | 3 | **uniquement `distanceMeters: 0` dans des fixtures** — aucune assertion sur la valeur synthétique |

Le rayon de 4000 m est testé aux bornes (3999,9 / 4000,1), le plafond 30 est testé (35 → 30),
l'absence d'arrêt dans le rayon est testée (liste vide, jamais de substitution), et le garde-fou
D1-i vérifie que `14.7167` n'est jamais substitué. **La partie GPS/proximité est bien couverte ;
la partie horaires/distances affichées ne l'est pas du tout.**

### N.4 🟡 Un test creux

`dakar_bounds_test.dart` L115-121 :
```dart
group('Stop isContinuousFlow logic', () {
  test('placeholder - verified via modeLabel', () {
    // AFTU/DDD/Tata sont en rotation continue (isContinuousFlow true)
    // Vérifié indirectement via DistanceHelper et DakarBounds
    expect(DistanceHelper.format(100), '100 m');
  });
});
```
Son nom annonce `isContinuousFlow` ; son commentaire affirme une vérification « indirectement via
DistanceHelper et DakarBounds » ; son assertion porte sur le **formateur de distance**, sans
aucun lien avec `isContinuousFlow`, qui n'est d'ailleurs **jamais appelé**. C'est un
auto-déclaré « placeholder » qui **gonfle le compte de 231** tout en laissant croire que la
logique de flux continu est couverte. Elle ne l'est pas.

### N.5 Les 3 assertions sur `DistanceHelper.format`

`format(850) == '850 m'`, `format(1500) == '1.5 km'`, `format(100) == '100 m'` : toutes dans la
zone où source et production **concordent**. Aucune ne touche le seuil de 950 ni la bande ≥ 10 km,
c'est-à-dire précisément les deux divergences de §G.3. Le test verrouille donc le comportement
divergent sans le détecter.

---

## O. Anomalies classées (§14) — critère : **impact fonctionnel uniquement**

### 🔴 CRITIQUE

| # | Anomalie | Fichier:ligne | Preuve | Impact fonctionnel |
|---|---|---|---|---|
| **O1** | `DistanceHelper.format` diverge du formateur production `A.azr` | `main.dart:1207-1210` | binaire : `azr(a){if(a<950)…; s=a/1000; if(s<10) return s.toStringAsFixed(1)+" km"; return round(s)+" km"}` | Toutes les distances **≥ 10 km** s'affichent avec une décimale au lieu d'un entier (17 900 m → « 17.9 km » au lieu de « 18 km ») : 14 arrêts sur 141 sans GPS, et toute distance GPS ≥ 10 km. Bande 950-999 m : « 999 m » au lieu de « 1.0 km ». |
| **O2** | `_findNearestStop` ne calcule aucune distance et **invente** un arrêt de repli | `main.dart:1135-1142` | code : boucle `contains(q)` puis `firstWhere(contains('dakar'), orElse: allStops.first)` | Une requête sans correspondance planifie **silencieusement** un trajet depuis/vers un arrêt dakarois arbitraire. Aucune erreur, aucun UNKNOWN. Viole §12 et la règle « correspondance non fiable → UNKNOWN ». |
| **O3** | `distanceMeters` synthétique affichée comme distance utilisateur quand le GPS est absent | `main.dart:974` (origine), `1759` (repli), `2123` (affichage) | `300 + (i * 800)` ; binaire `300+a2*800` et `q==null?a.c:A.ew(q,a.r)` | Sans GPS (refus, désactivé, erreur, hors zone), les 141 arrêts affichent des distances de 300 m à 17,9 km **déduites de leur index dans leur ligne**, sans rapport avec la position de l'usager. Aucun indice visuel ne le signale. **Production-fidèle** — pas une régression. |
| **O4** | Arrêts homonymes dupliqués dans la liste Explorer | `main.dart:890`, `1016` (clé de dédup) | simulation : 5 noms → 11 entrées, 6 surnuméraires ; écarts 751 m / 851 m / 1028 m / 1209 m | « Gare TER Dakar » apparaît **3 fois** (dont une à 851 m des deux autres) ; « Liberté 6 - BRT Correspondance » et « Sacré-Cœur - BRT » **2 fois** avec **11,2 km** d'écart de distance affichée. Recherche ambiguë, tri de proximité incohérent. **Production-fidèle** (clé identique dans le binaire). |
| **O5** | Couverture de test **nulle** sur horaires, départs, temps d'attente, distance affichée, intégration JSON | `test/` (9 fichiers) | 11 symboles à 0 référence (§N.2) | Les 231 tests verts ne garantissent **rien** sur la moitié de la chaîne auditée. Toute régression future sur `_terBase`, `remainingMinutes`, `_distanceTo` ou `300+i*800` passerait inaperçue. |
| **O6** | `DataStatus.unknown` jamais assigné, jamais référencé | `main.dart:719` | grep : 0 occurrence dans `lib/` **et** `test/` | Le modèle ne peut exprimer ni le temps réel (`live` également mort) ni l'inconnu. Le triplet SCHEDULED / REAL_TIME / UNKNOWN exigé est inopérant : tout objet est `scheduled`. |

### 🟠 IMPORTANT

| # | Anomalie | Fichier:ligne | Preuve | Impact |
|---|---|---|---|---|
| **O7** | Double logique d'ouverture de service contradictoire dans `StopCard` | `main.dart:2078` vs `674-681` | L2078 `now.hour >= 5` codé en dur ; `_isServiceOpen()` `isContinuousFlow ? 6 : 5` et 22:30 réservé aux non-continus | Pour AFTU/Tata/DDD, **05:00-05:59** et **22:00-22:30** : la carte affiche **« Bientôt »** alors que le service est fermé. **Production-fidèle** (binaire `A.aiK.$2` inline `>=5`, `Stop.xt()` utilise `gqy()?6:5`). |
| **O8** | `_isSunday()` évalué une seule fois par session | `main.dart:259`, `262` | `_terBase` est un `final` top-level | Session ouverte à cheval sur minuit : la grille TER du jour précédent persiste (pas de 10 min au lieu de 20, ou l'inverse) jusqu'à rechargement. |
| **O9** | Aucun report au lendemain après le dernier départ | `main.dart:683-691` | `return null` en fin de boucle, aucune reboucle | Entre 22:24 et 22:30 (dernier TER à 22:24), l'usager voit **« Bientôt »** alors qu'il n'y a plus aucun départ. `nextDepartureLabel()` renvoie « Prochainement », euphémisme. |
| **O10** | « Alertes en temps réel » dans `AIChatPage` | `main.dart:2922` | texte littéral | Revendication **non fondée** (aucun flux temps réel) et **en contradiction avec la correction E.4/E.5 du Groupe 6** qui a retiré cette formulation de `CommunityAlertsPage`. `AIChatPage` verrouillé → à traiter en Groupe 9 avec le « 14 gares ». |
| **O11** | Segment « lignes desservant l'arrêt » disparu du `StopCard` | `main.dart:2123` | binaire : `got(){"…"} = lines.isEmpty ? modeLabel : lines.join(" · ")`, 1ᵉʳ des 4 segments ; `lines` → **0 occurrence** dans `lib/` | Depuis la carte Explorer, l'usager ne voit plus **quelles lignes** desservent l'arrêt (ex. « B1 · DDD 10 »), seulement le mode. Aggrave O4 : deux homonymes deviennent indiscernables. |
| **O12** | Chemin GPS ponctuel supprimé | `main.dart:1511-1560` | binaire : `$.IM().lH(0, …)` avec `B.jN = 1e7 µs` = 10 s | Bouton « Activer GPS » : utilisateur immobile → aucun événement pendant 20 s (`distanceFilter: 10`) puis **« Erreur GPS. »**, là où la production répondait en ≤ 10 s. Un second appui relance bien une fenêtre. |
| **O13** | Deux centres « Dakar » distants de 4,07 km | `main.dart:1614` (14.7200, −17.4300) et `1733` (14.7167, −17.4677), + `3030` | calcul haversine ; binaire `B.IR` et `B.hA` | Sans GPS, la carte est centrée sur un point et la liste **triée** depuis un autre, à 4,07 km : l'ordre affiché ne correspond pas au centre visible. **Les deux sont production-fidèles.** |

### 🟡 À DOCUMENTER

| # | Anomalie | Fichier:ligne | Impact |
|---|---|---|---|
| **O14** | `remainingMinutes()` appelle `DateTime.now()` deux fois | `main.dart:694-700` | `-1` atteignable à cheval sur une minute ; effet visible bénin (branche « Imminent »), mais valeur incohérente. |
| **O15** | `getCrowdLevel(stop)` n'utilise pas son paramètre | `main.dart:1194-1203` | « Affluence » = étiquette purement horlogère, **identique pour les 141 arrêts**, présentée en gras comme une propriété de l'arrêt. Aucune mesure. **Production-fidèle** (`A.akL` ignore aussi son paramètre). |
| **O16** | `DateTime.now()` = heure locale de l'appareil, pas heure de Dakar (UTC+0) | `main.dart:259, 675, 686, 699, 1195` | Fenêtres de service, heure de pointe et détection du dimanche décalées de 1-2 h pour un appareil hors UTC+0. |
| **O17** | Arrêt le plus proche **sans plafond de rayon** dans `AIChatPage` | `main.dart:2873-2882` | Incohérent avec les 4000 m de `nearbyStops` : un arrêt à 30 km peut être retenu comme « le plus proche ». |
| **O18** | `nextDepartureLabel()` déclarée `String?` mais ne renvoie jamais `null` | `main.dart:702-709`, `3234` | `?? 'Fermé'` en L3234 est du **code mort** ; les 4 branches renvoient toutes une chaîne. |
| **O19** | Chemin « orphelins » : `500` m, `'AFTU'`, `'Dir. Centre Dakar'` codés en dur | `main.dart:1014-1040` | **Dormant** : 117 arrêts créés = 117 arrêts JSON, donc 0 orphelin. Deviendrait actif (et inventerait mode, direction et distance) si le JSON ajoutait un arrêt non rattaché à une ligne. **Production-fidèle.** |
| **O20** | Recherche : ordre d'insertion, plafond 8, n'ouvre pas la fiche | `main.dart:1690`, `1998` | Résultats ni triés par pertinence ni par distance ; homonymes côte à côte sans distinction ; taper un résultat centre la carte sans ouvrir la fiche. |
| **O21** | Test creux « placeholder - verified via modeLabel » | `test/dakar_bounds_test.dart:115-121` | Groupe intitulé `isContinuousFlow logic`, commentaire affirmant une vérification indirecte, assertion sans rapport (`format(100)`). `isContinuousFlow` n'est jamais appelé. Gonfle le compte de 231. |
| **O22** | `_dakarCenter` (14.7200, −17.4300) et la formule `300 +` non testés | `test/` | 0 référence ; le centre de carte et la formule de distance synthétique ne sont verrouillés par aucun test. |
| **O23** | Fiche ligne : la production centre sur le **dernier** point, le source sur le **premier** | `main.dart:3030` | binaire `B.b.gM(j)` (dernier) vs `validPoints.first`. Centre de carte initial différent d'une extrémité de la ligne à l'autre. |

### 🟢 NORMAL / CONFORME

| # | Élément | Preuve |
|---|---|---|
| **O24** | GPS réel, aucune coordonnée fabriquée dans `_userPosition` | §B ; `isSubstitutedPosition` toujours `false`, testé |
| **O25** | 4 états d'erreur distingués (service désactivé / refus / refus définitif / erreur) | D4, Groupe 4 ; testé « distinguables deux à deux (état ET message) » |
| **O26** | Interruption de flux : la dernière position réelle valide est conservée | `fromStreamInterrupted` L1446 ; **amélioration** sur la production (`A.ars` = corps vide) |
| **O27** | Position hors zone → `null` + `error`, jamais de substitution | D1-i ; **corrige un défaut réel de la production** (`A.arn` substituait `B.hA` avec état `granted`) |
| **O28** | Rayon 4000 m, plafond 30, R = 6 371 008,8 m | L1353, 1357, 1229 ; production-fidèle (`A.ap3`, `A.ew`) ; testé aux bornes ±0,1 m |
| **O29** | `_resolveJsonStop` : id → nom → ≤ 250 m → **`null`** | L538-577 ; jamais d'arrêt inventé |
| **O30** | `OppositeStopService` : 120 m puis 500 m, `null` sinon | L218, 237 ; 34 tests |
| **O31** | `DetailedRoute.fromStop` → `null` si indérivable | Groupe 2 §8 |
| **O32** | 13 gares TER, 23 stations B1, 7 B2 | simulation + 57 tests `ter_brt_route_data_test` |
| **O33** | Polylignes dérivées du JSON, aucun littéral codé en dur | L1041+ ; test « AUCUNE coordonnée de tracé ne subsiste hors de la source unique » |
| **O34** | Sélection manuelle : coordonnées propres de l'arrêt, jamais le GPS, aucune distance en fiche | §K |
| **O35** | Badge de départ `Fermé`/`Bientôt`/`Imminent`/`N min` et `formatRemaining` | L2078-2088, 1188-1192 ; **identiques à la production** (`A.aiK`, `A.aTn`) |
| **O36** | Ticker 15 s annulé dans `dispose` | L1484, 1494 |
| **O37** | Aucun badge « LIVE » / « En direct » / « REAL_TIME » dans l'interface | §I ; `DataStatus.live` jamais assigné, gardé par 4 tests |
| **O38** | Vitesse 35 / 20 km/h = vitesse **véhicule**, jamais présentée comme temps de marche | L1146-1147 |

---

## P. Corrections potentielles (§15) — **PROPOSÉES, NON IMPLÉMENTÉES**

Aucune de ces corrections n'a été appliquée. Aucune valeur arbitraire nouvelle n'est proposée :
chaque valeur cible est soit prouvée par le binaire de production, soit déjà présente dans le
source.

### P1 — O1 : aligner `DistanceHelper.format` sur le formateur production
- **Fichier / lignes** : `lib/main.dart:1207-1210`
- **Problème** : seuil 1000 au lieu de 950 ; décimale conservée ≥ 10 km.
- **Preuve** : `A.azr` du binaire `94a84b60`.
- **Correction minimale** : reproduire les trois branches de `azr` — `< 950` → `round() + " m"` ;
  `km < 10` → `toStringAsFixed(1) + " km"` ; sinon → `round(km) + " km"`.
- **Tests** : ajouter les valeurs charnières 949 / 950 / 951 / 999 / 1000 / 9999 / 10000 / 12345 /
  17900 / 35000 ; conserver 850, 1500, 100 (déjà verts).
- ** Inchangé** : `haversineMeters`, `_distanceTo`, `distanceMeters`, toutes les valeurs de
  distance, le JSON, l'UI.
- **Risque** : les 3 assertions existantes restent vertes (elles sont dans la zone concordante).

### P2 — O2 : rendre `_findNearestStop` honnête
- **Fichier / lignes** : `lib/main.dart:1135-1142` ; appelants `1108-1109`.
- **Problème** : repli silencieux sur un arrêt « dakar », aucune distance calculée.
- **Preuve** : code source ; §12 et règle verrouillée « correspondance non fiable → UNKNOWN ».
- **Correction minimale** : deux options, à trancher —
  (a) renommer en `_findStopByName` et supprimer le repli (`return null`), les appelants devant
  alors produire un UNKNOWN ; (b) si la position est disponible, trier les appariements par
  haversine et plafonner à `GpsResolver.nearbyRadiusMeters`, sinon `null`.
- **Tests** : requête sans correspondance → `null` ; requête vide → `null` ; requête ambigüe avec
  homonymes → résultat déterministe.
- **Inchangé** : `RoutePlanner._buildRoute`, vitesses, JSON.
- **Risque** : modifie le comportement de l'assistant sur les requêtes hors réseau — c'est
  l'objectif, mais cela touche `AIChatPage` (verrouillé) si les appelants y sont. **À valider
  avant tout Groupe 8.**

### P3 — O5 / O21 / O22 : couvrir la chaîne horaires et distances
- **Fichier** : nouveau `test/schedule_test.dart` (+ 3 assertions dans `dakar_bounds_test.dart`).
- **Correction minimale** : tests de `_generateSchedule` (bornes inclusives, cardinal 151/100/50),
  `_shift` (offset, pas de dépassement de 1440), `remainingMinutes` / `nextDepartureMinutes`
  (horizon 180, service fermé, flux continu = 5, dernier départ passé → `null`),
  `_isServiceOpen` (5 h vs 6 h, 22:30), et `distanceMeters = 300 + i*800` pour les 13 gares TER
  et les 23 stations B1. Remplacer le test « placeholder » par une vraie assertion sur
  `isContinuousFlow`.
- **Inchangé** : `lib/` entirely — tests seuls.
- **Note** : ces fonctions sont **top-level privées** (`_`), donc inaccessibles depuis `test/`
  sans export. Les rendre testables exige soit un `@visibleForTesting`, soit un déplacement vers
  un fichier de service — **décision de périmètre requise**, ce n'est pas une modification neutre.

### P4 — O7 : unifier la fenêtre de service
- **Fichier / lignes** : `lib/main.dart:2078`.
- **Correction minimale** : remplacer le calcul inline par `stop`-porté (exposer `_isServiceOpen()`
  en getter public) pour que la carte et le modèle utilisent la **même** fenêtre.
- **Preuve** : contradiction L2078 vs L674-681 ; la production a la même contradiction.
- **Tests** : AFTU à 05:30 → « Fermé » ; AFTU à 22:15 → « Fermé » ; TER à 22:15 → ouvert.
- **Inchangé** : textes des badges, styles, couleurs.
- **Risque** : divergence volontaire par rapport à la production (§M : ne jamais restaurer
  automatiquement — ici il s'agit de **corriger**, pas de restaurer). **À valider.**

### P5 — O4 : déduplication des homonymes
- **Fichier / lignes** : `lib/main.dart:890`, `1016`.
- **Problème** : clé `name_lat_lng` trop stricte.
- **Contrainte bloquante** : `dakar_network.json` est **verrouillé** — les coordonnées divergentes
  des homonymes ne peuvent pas y être corrigées. Toute fusion devrait se faire dans
  `_integrateNetworkData`, donc **au prix d'une décision sur quelle coordonnée l'emporte** —
  ce qui serait une invention si rien ne la fonde.
- **Recommandation** : **ne pas corriger en Groupe 7/8.** Documenter, et porter la question au
  propriétaire de la donnée. Un affichage distinguant les homonymes (par ex. en ajoutant le mode
  ou la ligne — cf. P6) résout le problème utilisateur sans toucher aux coordonnées.

### P6 — O11 : rétablir l'information « lignes desservant l'arrêt »
- **Fichier / lignes** : `lib/main.dart:629` (modèle `Stop`), `974-986` (intégration), `2123` (affichage).
- **Preuve** : `got()` production = `lines.isEmpty ? modeLabel : lines.join(" · ")`.
- **Correction minimale** : ajouter un champ `lines` au `Stop`, alimenté **uniquement** depuis
  `routes` du JSON (aucune invention : les 105 lignes donnent exactement quels `short_name`
  desservent chaque `stop_id`), et rétablir le 1ᵉʳ segment du sous-titre.
- **Tests** : un arrêt de B1 porte « B1 » ; un arrêt desservi par 2 lignes porte les deux, joints
  par « · » ; un arrêt sans ligne retombe sur le mode.
- **Inchangé** : couleurs, styles, JSON, polylignes, tous les autres segments.
- **Risque** : touche le modèle `Stop` et donc `copyWith`, `OppositeStopService`,
  `_resolveJsonStop`, les fixtures de test (`distanceMeters: 0` ×3). Périmètre non trivial.
  **Le design étant verrouillé, cette correction exige une validation explicite.**

### P7 — O6 : donner un usage à `DataStatus.unknown`, ou le retirer
- **Fichier / lignes** : `lib/main.dart:719`, et les points de production d'état.
- **Deux options** : (a) affecter `unknown` là où la donnée est réellement indisponible
  (distance synthétique sans GPS, horaire non sourcé) — ce qui **changerait l'affichage** et
  contredit « ne pas refactorer » ; (b) documenter que l'énumération est réduite à `scheduled`
  et que `live`/`unknown` sont des garde-fous déclaratifs.
- **Recommandation** : **(b)** en Groupe 7, aucune modification. Le garde-fou `live` existe déjà
  côté tests ; il manque son pendant pour `unknown`.

### P8 — O10 : « Alertes en temps réel » dans `AIChatPage`
- **Fichier / lignes** : `lib/main.dart:2922`.
- **Correction** : reformuler sans « en temps réel », comme Groupe 6 l'a fait pour
  `CommunityAlertsPage`.
- **Bloqué** : `AIChatPage` est un élément **verrouillé**. À inscrire au **Groupe 9**, avec la
  correction « 14 gares » déjà réservée.

### Corrections explicitement **écartées**
- **O3** (`distanceMeters` synthétique) : production-fidèle, et toute valeur de remplacement
  serait arbitraire. **Aucune nouvelle valeur ne sera proposée**, conformément à la consigne.
  La seule correction non arbitraire serait de **ne pas afficher** de distance quand la position
  est absente — mais c'est un changement d'UI, verrouillé.
- **O13** (deux centres) : les deux sont production-fidèles ; les unifier serait une restauration
  arbitraire d'un choix non prouvé.
- **O15** (`getCrowdLevel`) : production-fidèle à l'identique ; la remplacer exigerait une donnée
  d'affluence qui n'existe nulle part.
- **O8, O9, O12, O14, O16, O17, O18, O19, O20, O23** : impacts faibles ou dormants ; à documenter,
  pas à corriger en Groupe 7.

---

## Q. Fichiers à modifier / à ne pas modifier (§16)

### À modifier (uniquement si un Groupe 8 est ouvert — **rien n'a été modifié ici**)

| Fichier | Lignes | Pour |
|---|---|---|
| `lib/main.dart` | 1207-1210 | P1 (formateur de distance) |
| `lib/main.dart` | 1135-1142 (+ 1108-1109) | P2 (`_findNearestStop`) |
| `lib/main.dart` | 2078 | P4 (fenêtre de service) |
| `lib/main.dart` | 629, 974-986, 2123 | P6 (champ `lines`) — **après validation** |
| `test/schedule_test.dart` (nouveau) | — | P3 |
| `test/dakar_bounds_test.dart` | 115-121 | P3 (remplacer le placeholder), P1 (valeurs charnières) |

### À NE PAS modifier

| Élément | Raison |
|---|---|
| `assets/data/dakar_network.json` | verrouillé, source unique ; md5 `81c778f4…` doit rester identique |
| Les 13 gares TER, 23 stations B1, 7 B2 | verrouillé |
| Les polylignes (Groupe 5) | verrouillé |
| `AlertsPage`, `CommunityAlertsPage` (Groupe 6) | verrouillé |
| `ExplorerPage` : navigation, design, couleurs, filtres | verrouillé |
| `AIChatPage` (L2922 inclus) | verrouillé → Groupe 9 |
| Les horaires synthétiques (`_terBase`, `_brtBase`, `_shift`, `_generateSchedule`) | verrouillé |
| `OSRM`, `pubspec.yaml` (dépendances) | verrouillé |
| Les points de démonstration Explorer | verrouillé |
| `GpsResolver`, `DakarBounds`, `OppositeStopService`, `DetailedRoute`, `_resolveJsonStop` | conformes et testés (O24-O33) — y toucher serait une régression |
| `distanceMeters` (toute valeur) | aucune valeur de remplacement fondée n'existe |
| gh-pages, tout déploiement | interdit |

---

## R. Périmètre recommandé pour le Groupe 7 (§17)

Le Groupe 7 était un **audit**. Il est terminé et n'a rien modifié. Recommandation pour la suite :

**Groupe 7 bis — « Affichage fidèle de la distance » (périmètre minimal, risque minimal)**
1. **P1 seul** : aligner `DistanceHelper.format` (L1207-1210) sur `A.azr` du binaire.
   - 1 fonction, 4 lignes, aucune donnée, aucune UI, aucun modèle.
   - Preuve production établie et vérifiable.
   - Tests : 10 valeurs charnières ajoutées, 3 existantes conservées.
   - C'est la **seule** correction de tout l'audit qui soit à la fois prouvée par le binaire,
     strictement locale, et sans décision de conception à prendre.
2. **P3 partiel** : couvrir `_generateSchedule`, `_shift`, `remainingMinutes`,
   `nextDepartureMinutes`, `_isServiceOpen` — **si** l'obstacle d'accessibilité (fonctions
   top-level privées) est levé sans refactor ; sinon, documenter l'obstacle et s'arrêter.
3. **P3 minimal** : remplacer le test « placeholder » (O21) par une assertion réelle sur
   `isContinuousFlow`, sans changer le compte de tests de façon trompeuse.

**Explicitement hors périmètre recommandé** : P2 (touche l'assistant, verrouillé), P4 (divergence
volontaire par rapport à la production, à valider), P5 (donnée verrouillée), P6 (modèle + design
verrouillés), P7 (choix (b) : documenter seulement), P8 (Groupe 9).

**Recommandation de décision préalable** : O3, O4, O7, O11, O13, O15 sont **production-fidèles**.
Les corriger revient à **améliorer** l'application au-delà de la production déployée, ce qui est
légitime mais constitue un changement de contrat : cela doit être **décidé explicitement**, et
non déduit de cet audit. Aucune restauration d'implémentation ancienne n'est proposée.

---

## S. Conclusion

La chaîne auditée fonctionne ainsi, de bout en bout :

1. **GPS** : flux continu réel (`getPositionStream`, précision haute, filtre 10 m, limite 20 s).
   Quatre états d'erreur distingués. **Aucune position fabriquée** n'atteint `_userPosition` ;
   hors zone, la position vaut `null` et l'état `error`.
2. **Position** : une seule source (`_MainShellState._userPosition`), transmise à un seul widget
   (`ExplorerPage`), qui la relaye à `AIChatPage`. **La même position est utilisée partout.**
3. **Arrêts proches** : filtre haversine `< 4000 m`, tri croissant, plafond 30. Sans position,
   `nearbyStops` renvoie `null` et la liste est seulement **triée** depuis un centre fabriqué
   `(14.7167, −17.4677)` — sans rayon ni filtrage.
4. **Distance** : `_distanceTo` renvoie la distance **réelle** si la position existe, sinon la
   valeur **synthétique** `distanceMeters`. Celle-ci vaut `300 + 800 × index` pour les 117 arrêts
   JSON, un littéral codé en dur pour les 24 arrêts de démonstration, et `500` dans un chemin
   orphelin actuellement inatteignable. Un seul point d'affichage : le sous-titre du `StopCard`.
5. **Conversion en temps** : **il n'en existe aucune pour la marche.** Les seules conversions
   distance → minutes utilisent 35 km/h (TER/BRT) et 20 km/h (autres) — des vitesses véhicule —
   ou 3 min par index d'arrêt.
6. **Départs et attente** : horaires 100 % synthétiques (`_terBase` 05:30-22:00 par 10 min,
   20 min le dimanche ; `_brtBase` 06:00-21:00 par 6 min), décalés de `i × 2` minutes selon
   l'index de l'arrêt dans sa ligne. AFTU / Tata / DDD renvoient **5 minutes en permanence**.
   Horizon de recherche : 3 h. **Aucun report au lendemain.** Rafraîchissement toutes les 15 s.
7. **Statut** : `DataStatus` ne porte en pratique qu'une seule valeur, `scheduled`. `live` et
   `unknown` sont morts. Aucun badge LIVE dans l'interface, mais deux textes « temps réel »
   subsistent (L2741, L2922).
8. **Arrêt manuel** : coordonnées propres de l'arrêt, **jamais** le GPS, **aucune** distance
   affichée en fiche, départs issus de la liste synthétique de l'arrêt, aucun arrêt précédent
   conservé.

**Bilan chiffré** : 6 anomalies 🔴, 7 🟠, 10 🟡, 15 éléments 🟢 conformes. Sur 23 points de
comparaison avec la production, **17 sont fidèles**, **3 sont des améliorations volontaires
documentées** (position hors zone, erreur de flux, `deniedForever`), et **3 sont des divergences
non documentées** (formateur de distance, chemin ponctuel supprimé, segment « lignes » disparu).

**Point le plus important de l'audit** : la moitié de la chaîne — tout ce qui produit le
**temps d'attente** et la **distance affichée** — n'est couverte par **aucun** des 231 tests, et
l'un de ces 231 tests est un « placeholder » dont le nom annonce une couverture qui n'existe pas.
Les 231 tests verts certifient la partie GPS/proximité/données, pas la partie horaires/distances.

---

**GROUPE 7 — AUDIT TERMINÉ — AUCUNE MODIFICATION FONCTIONNELLE EFFECTUÉE**
