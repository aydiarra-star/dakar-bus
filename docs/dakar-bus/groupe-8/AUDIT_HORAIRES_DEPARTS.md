# GROUPE 8 — AUDIT STRICT : HORAIRES → PROCHAINS DÉPARTS → ATTENTE → STATUT DE DONNÉE

**Règle appliquée : AUCUNE modification fonctionnelle.** Ce document est le seul artefact produit.
Aucun fichier de `lib/`, `test/`, `assets/`, `pubspec.yaml` n'a été touché. Aucun déploiement.

Chaîne auditée :
**ARRÊT → LIGNE → HORAIRE → PROCHAIN DÉPART → TEMPS D'ATTENTE → STATUT DE DONNÉE → AFFICHAGE**

> **Méthode.** Toute affirmation sur la production est prouvée par lecture directe du binaire
> dart2js (gh-pages `94a84b60`, `main.dart.js`, 2 497 533 octets, blob
> `4260bdf5a569c753e3470af2cb35b8055c56b43d`), symboles minifiés résolus un par un. Toute
> affirmation sur le comportement temporel est prouvée par **simulation statique exhaustive**
> d'un port fidèle de la logique Dart, faute de SDK Flutter dans le sandbox.

---

## A. État de référence

| Élément | Valeur vérifiée |
|---|---|
| HEAD avant audit | `0c2ca4d` (rapport G7 P1) |
| Commits de référence | `e2ebbd1` (audit G7) · `e506b72` (correctif P1) · `0c2ca4d` (rapport P1) |
| Branche | `arena/01a0c385-dakar-bus` |
| `git status --porcelain` avant audit | **vide** (arbre propre) |
| Tests | **232** (18+10+37+40+12+22+34+57+2) |
| `flutter analyze` | **0 issue** (CI check-run `106617368855`) |
| JSON | md5 **`81c778f4644dcf5e1cf4ae25879218f0`** — inchangé |
| gh-pages | **`94a84b6070569bed708b8e779b9e70b7c9dafa45`** — inchangée |
| Déploiement | aucun |
| `lib/main.dart` | 3 310 lignes (3 272 + 38 de documentation ajoutées par P1) |
| Inventaire `lib/` | `main.dart`, `models/transport_network.dart`, `services/data_service.dart` |

Le correctif P1 (`DistanceHelper.format`, L1243) n'a **aucun** effet sur la chaîne auditée ici :
`format` ne traite que des distances, jamais des minutes.

---

## B. Source des horaires

### B.1 Le JSON ne contient **aucune** donnée horaire — constat Groupe 6 **CONFIRMÉ**

Inventaire exhaustif des clés de `assets/data/dakar_network.json` (3 clés racines) :

| Section | Entrées | Clés présentes | Champ horaire ? |
|---|---|---|---|
| `operators` | 5 | `id`, `name`, `color` | **aucun** |
| `stops` | 117 | `id`, `name`, `latitude`, `longitude`, `data_trust` | **aucun** |
| `routes` | 105 | `id`, `operator_id`, `short_name`, `long_name`, `type`, `data_trust`, `stops` | **aucun** |

Scan brut du fichier sur tout motif temporel :

| Motif | Occurrences | Motif | Occurrences |
|---|---|---|---|
| `hour` | **0** | `schedule` | **0** |
| `minute` | **0** | `calendar` | **0** |
| `freq` | **0** | `departure` | **0** |
| `headway` | **0** | `interval` | **0** |
| `service` | **0** | `05:` / `06:` / `22:` | **0 / 0 / 0** |
| `time` | 10 | `day` | 3 |

Les 10 `time` et 3 `day` sont des **sous-chaînes de noms de lieux** — « Gare Mari**time** »,
« Gare Mari**time** ↔ Grand Yoff » — et non des champs. Vérifié un par un.

**Conclusion : il n'existe dans la source unique ni horaire, ni fréquence, ni headway, ni heure de
début ou de fin, ni jour de circulation, ni calendrier, ni exception.** Rien pour TER, rien pour
BRT, rien pour AFTU, rien pour Tata, rien pour DDD.

### B.2 Le seul champ de confiance du JSON est parsé mais **jamais utilisé**

`data_trust` existe et porte une information réelle :

| | OFFICIAL | FIELD_OBSERVATION |
|---|---|---|
| `stops` (117) | 55 | 62 |
| `routes` (105) | 14 | 91 |

Il est correctement modélisé : `enum DataTrust { official, fieldObservation, estimated }`
(`lib/models/transport_network.dart:5`), `fromString` (L19), `toLabel` (L8), parsé dans
`BusStop.fromJson` (L79) et `TransportRoute.fromJson` (L118).

**Mais `lib/main.dart` ne le lit jamais.** Les seules occurrences de `dataTrust` / `data_trust`
dans `main.dart` sont des **commentaires** (L830, L2453-2454, L3152). `_integrateNetworkData`
n'utilise que `busStop.name`, `.id`, `.latitude`, `.longitude` ; le badge affiché vient
exclusivement de `sourceForOperator(route.operatorId)` (L925-933). Conséquence chiffrée en §N.4.

---

## C. `_generateSchedule` — audit intégral

### C.1 Code exact (L253-262)

```dart
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

### C.2 Paramètres, branches, constantes

| Paramètre | Type | Rôle | Valeurs réellement passées |
|---|---|---|---|
| `from` | `int` | minute du premier départ depuis minuit | **330** (TER), **360** (BRT) |
| `to` | `int` | minute du dernier départ, **borne inclusive** | **1320** (TER), **1260** (BRT) |
| `step` | `int` | intervalle entre deux départs, en minutes | **10** ou **20** (TER), **6** (BRT) |

- **Une seule branche** dans `_generateSchedule` : la boucle `for`. Aucun `if`, aucune garde.
- **Une seule branche** dans `_buildTerBase` : le ternaire `_isSunday() ? 20 : 10`.
- `_shift` : aucune branche, translation arithmétique pure.
- **Aucune validation** : `step <= 0` produirait une boucle infinie ; `from > to` une liste vide.
  Aucun appel ne provoque ces cas (valeurs codées en dur).

### C.3 Fréquences, heures de début et de fin

| Base | Début | Fin | Pas | Nombre de départs | Dernier départ réel |
|---|---|---|---|---|---|
| `_brtBase` | 360 = **06:00** | 1260 = **21:00** | 6 min | **151** | 21:00 |
| `_terBase` lundi–samedi | 330 = **05:30** | 1320 = **22:00** | 10 min | **100** | 22:00 |
| `_terBase` dimanche | 330 = **05:30** | 1320 = **22:00** | 20 min | **50** | **21:50** (330+20×49=1310) |

Cardinal vérifié : `(1260−360)/6 + 1 = 151` ; `(1320−330)/10 + 1 = 100` ; dimanche
`330 + 20k ≤ 1320 ⇒ k ≤ 49,5 ⇒ k ∈ [0,49]` soit **50** valeurs, la dernière à 1310 = 21:50.
**Le dimanche, le dernier TER est donc à 21:50 et non 22:00.**

### C.4 Réseaux et lignes concernés

| Réseau | Lignes | Base utilisée | Décalage appliqué | Horaires résultants |
|---|---|---|---|---|
| TER | 1 (`ter_dakar_diamniadio`) | `_terBase` | `_shift(_terBase, i*2)`, i = 0…12 | **0 à +24 min** |
| BRT | B1 (23), B2 Express (7) | `_brtBase` | `_shift(_brtBase, i*2)`, i = 0…22 | **0 à +44 min** |
| DDD | 23 lignes | — | — | **liste vide** → flux continu |
| AFTU | 78 lignes | — | — | **liste vide** → flux continu |
| Tata | 4 lignes | — | — | **liste vide** → flux continu |

Affectation dans `_integrateNetworkData` (L958-966) :
```dart
if (label == 'TER')            schedule = _shift(_terBase, i * 2);
else if (label == 'BRT')       schedule = _shift(_brtBase, i * 2);
else                           schedule = [];   // AFTU/DDD/Tata → isContinuousFlow
```
`i` est l'index de l'arrêt **dans la liste d'arrêts de sa ligne**, et seule la **première** ligne
qui atteint un arrêt le crée (déduplication `existingKeys`, L890). B2 Express étant un
sous-ensemble de B1 traité après, **B2 ne crée aucun arrêt** et n'applique aucun décalage propre.

Les **24 arrêts littéraux de démonstration** (L750-790, répartis en 5 listes nommées :
`terStations` L750, `brtStations` L761, `dddStations` L769, `tataStations` L778,
`aftuAndBusStations` L785, fusionnées dans `allStops` L791) utilisent des décalages **codés en dur** :
`_shift(_terBase, 0/3/5/9/17/27/50/48)` et `_shift(_brtBase, 0/2/4/8)`, les DDD/TATA/AFTU
littéraux recevant `[]`.

### C.5 Dépendance à l'heure système et au jour

- `_isSunday()` lit `DateTime.now().weekday` → **heure locale de l'appareil**, `DateTime.sunday == 7`.
- `_terBase` et `_brtBase` sont des **`final` top-level** : initialisés **une seule fois**, au
  premier accès, pour toute la durée de la session. `_isSunday()` n'est donc **jamais réévalué**.
- `_brtBase` ne dépend **d'aucun** jour : pas de 6 min toute la semaine, y compris le dimanche.
- Aucune dépendance au GPS, à la position, à l'arrêt géographique ou à la ligne réelle : le seul
  paramètre d'entrée est l'**index** `i`.

### C.6 Comportements aux limites

| Situation | Comportement |
|---|---|
| Avant le premier départ (ex. 05:00 pour le TER) | La liste commence à 330 ; `nextDepartureMinutes` renvoie 330 si l'écart ≤ 180 min → attente affichée 30 min |
| Hors période de service | `_isServiceOpen()` renvoie `false` → `null` partout, badge « Fermé » |
| Après le dernier départ | Aucun `d ≥ currentMin` → `null` → « Prochainement » / « Bientôt ». **Aucun report au lendemain** |
| Valeurs > 1440 | **Impossible** : max `_terBase` 1320 + 50 (démo) = 1370 ; max `_brtBase` 1260 + 44 = 1304 |
| Valeurs < début de service | **Impossible** : offsets toujours ≥ 0 |

### C.7 Statut des départs générés

| Qualification | Verdict | Justification |
|---|---|---|
| Officiels | ❌ **NON** | Le JSON ne contient aucun horaire (§B.1) |
| Calculés à partir de données officielles | ❌ **NON** | Aucune donnée officielle horaire n'entre dans le calcul ; les seules entrées sont des constantes codées en dur (330/1320/360/1260/10/20/6) et l'index `i` |
| **Synthétiques** | ✅ **OUI** | Suite arithmétique pure, décalée d'un pas proportionnel à la position de l'arrêt dans sa ligne |
| De démonstration | ⚠️ **partiellement** | Les 24 arrêts littéraux (L750-790) relèvent de la démonstration ; les 117 arrêts JSON relèvent de la synthèse |
| Inconnus | ❌ non exprimé | L'application ne dit jamais « horaire inconnu » : elle affiche une heure précise |

> **Verdict §C : 100 % SYNTHÉTIQUE.** Aucun horaire affiché par Dakar Bus ne provient d'une
> source officielle, ni n'en est dérivé.

---

## D. Prochain départ — traçage exact

### D.1 Le code complet

Aucune autre arithmétique temporelle n'existe dans `lib/`. Inventaire exhaustif :
**0 occurrence** de `difference(`, `.inMinutes`, `isAfter`, `isBefore`, `add(Duration`.

```dart
// L683-692  nextDepartureMinutes()
int? nextDepartureMinutes() {
  if (!_isServiceOpen()) return null;
  if (isContinuousFlow) return 5;                       // ← constante, pas une minute-du-jour
  final now = DateTime.now();
  final currentMin = now.hour * 60 + now.minute;
  for (final d in departureMinutesFromMidnight) {
    if (d >= currentMin && (d - currentMin) <= 180) return d;
  }
  return null;
}

// L674-681  _isServiceOpen()
bool _isServiceOpen() {
  final now = DateTime.now();
  final hour = now.hour;
  int startHour = isContinuousFlow ? 6 : 5;
  if (hour >= startHour && hour < 22) return true;
  if (!isContinuousFlow && hour == 22 && now.minute <= 30) return true;
  return false;
}

// L672  isContinuousFlow
bool get isContinuousFlow => modeLabel == 'AFTU' || modeLabel == 'Tata' || modeLabel == 'DDD';
```

Points d'appel : `nextDepartureMinutes()` n'est appelé **que** par `remainingMinutes()` (L697) et
`nextDepartureLabel()` (L705). `departureAfter()` (L711) n'est appelé que par `_buildRoute` (L1151).

La boucle parcourt la liste **dans l'ordre** et s'arrête au premier candidat : comme les bases sont
croissantes et `_shift` une translation, la liste reste triée → le premier candidat est bien le
plus proche. **Aucun tri explicite n'est effectué**, la correction repose sur l'ordre de génération.

### D.2 Les six cas exigés

| Cas | Comportement réel | Preuve |
|---|---|---|
| **A — Départ dans la journée** | Premier `d` de la liste avec `d ≥ currentMin` **et** `d − currentMin ≤ 180`. Renvoie la minute-du-jour absolue. | L689 |
| **B — Aucun départ restant aujourd'hui** | La boucle ne trouve aucun `d ≥ currentMin` → **`null`**. `nextDepartureLabel()` → **« Prochainement »**, `StopCard` → **« Bientôt »**. Aucune mention de « plus de départ aujourd'hui ». | L691, 706, 2121 |
| **C — Premier départ du lendemain** | **N'existe pas.** Aucun code ne reboucle, n'ajoute 1440, ni ne consulte la liste du jour suivant. `departureAfter` non plus (L711-716). Le `% 1440` de L707 ne normalise qu'une valeur **déjà** choisie, il ne fait pas de report. | L683-716, simulation §G |
| **D — Hors horaires** | `_isServiceOpen()` faux → `null` immédiatement, **sans parcourir la liste**. Étiquette « Service fermé », badge « Fermé ». | L684, 703, 2119 |
| **E — Liste vide** | Deux sous-cas. (1) mode continu (`AFTU`/`Tata`/`DDD`) : court-circuit **avant** la boucle → renvoie **5**. (2) mode TER/BRT avec liste vide : la boucle ne tourne pas → `null`. En pratique aucun TER/BRT n'a de liste vide. | L685, 688 |
| **F — Horaire inconnu** | **Non exprimé.** Il n'existe aucun état « horaire inconnu » : `DataStatus.unknown` n'est jamais assigné (§M) et `nextDepartureLabel()` renvoie « Prochainement », qui est un **euphémisme** et non un aveu d'ignorance. | §M, L706 |

### D.3 Chaîne de transformation complète

```
JSON (aucun horaire)
  → _generateSchedule(330|360, 1320|1260, 10|20|6)      L253   liste arithmétique
  → _shift(base, i * 2)                                   L258   translation selon l'index
  → Stop.departureMinutesFromMidnight                     L631   champ du modèle
  → nextDepartureMinutes()                                L683   filtre ≥ now, ≤ 180 min
  → remainingMinutes()  /  nextDepartureLabel()           L694 / L702
  → StopCard (badge)    /  SingleStopView (« Prochain départ »)   L2117 / L3272
```

---

## E. Temps d'attente

```dart
// L694-700
int? remainingMinutes() {
  if (!_isServiceOpen()) return null;
  if (isContinuousFlow) return 5;
  final d = nextDepartureMinutes();
  if (d == null) return null;
  return d - (DateTime.now().hour * 60 + DateTime.now().minute);
}
```

- **Formule** : `attente = minute_du_prochain_départ − minute_courante`. Aucune `Duration`, aucun
  `difference()`, aucun horodatage : de l'arithmétique entière sur des minutes-du-jour.
- **Domaine de définition prouvé** : `remainingMinutes() ∈ {null} ∪ {5} ∪ [0 ; 180]`.
  Le `5` du flux continu est une **constante**, pas un calcul.
- **`-1` atteignable** : L699 rappelle `DateTime.now()` **une seconde fois** après l'appel à
  `nextDepartureMinutes()` (L686). Si la minute bascule entre les deux, `d − currentMin₂` vaut
  `-1`. Effet visible bénin (L2123, branche `remaining <= 0` → « Imminent »), mais valeur
  incohérente. **Production-fidèle** (§Q).
- **Affichage** : `TimeHelper.formatRemaining` (L1188-1192) → `≤ 0` = « Imminent », `1` = « 1 min »,
  sinon « N min ». Le badge `StopCard` (L2117-2125) enchaîne : `Fermé` → `Bientôt` → `Imminent` → `N min`.
- **Rafraîchissement** : `Timer.periodic(const Duration(seconds: 15))` (L1522) → `setState`, annulé
  dans `dispose` (L1532). L'attente se recalcule donc toutes les 15 s.

---

## F. Horizon de 3 heures

| Question | Réponse |
|---|---|
| Où est-il défini ? | **`lib/main.dart:689`**, unique occurrence : `(d - currentMin) <= 180` |
| Est-il nommé / documenté ? | **Non.** Aucune constante nommée, aucun commentaire. `180` est un littéral magique inline. |
| Pourquoi 180 ? | **NON PROUVÉ.** Aucun commentaire, aucun ticket, aucune trace dans `docs/`, aucun test, aucune justification dans le binaire de production. Rien n'établit l'origine de cette valeur. |
| Horizon métier ou technique ? | **Ni l'un ni l'autre, en pratique : il est inopérant.** Avec un pas de 6 min (BRT), 10 min (TER semaine) ou 20 min (TER dimanche), un candidat existe toujours à moins de 20 min pendant toute la plage horaire. L'horizon ne se déclenche **que** après le dernier départ, où il redonne le même résultat que l'absence de candidat. |
| Les départs au-delà de 3 h sont-ils ignorés ? | **Oui**, strictement : `d - currentMin > 180` → le candidat est sauté, la boucle continue, et comme la liste est croissante tous les suivants sont aussi rejetés → `null`. |
| Que se passe-t-il sans départ dans les 3 h ? | `null` → « Prochainement » (étiquette) et « Bientôt » (badge). **Pas** « aucun départ », **pas** « service terminé pour aujourd'hui ». |
| L'application cherche-t-elle le lendemain ? | **Non** (§D.2 cas C, §G). |
| Affiche-t-elle une absence de départ ? | **Non.** « Bientôt » et « Prochainement » sont des formulations **positives** qui masquent l'absence. |
| Fabrique-t-elle un prochain départ ? | **Non**, et c'est un point positif 🟢 : aucune heure inventée n'est produite. En revanche `RoutePlanner._buildRoute` L1151 fait `from.departureAfter(safeCurrentMin) ?? safeCurrentMin` — il **substitue l'heure courante** comme heure de départ quand aucun départ n'existe (§R, H-14). |

---

## G. Passage au lendemain

**Aucun mécanisme de report n'existe.** Simulation statique exhaustive d'un port fidèle de
L672-716 et L2116-2125, sur 6 arrêts × 14 heures :

| Arrêt | 23:59 | 00:00 | 00:01 | 04:59 | 05:00 | 14:41 | dernier dép. | 22:30 | 22:31 |
|---|---|---|---|---|---|---|---|---|---|
| TER Dakar (i=0) | Fermé | Fermé | Fermé | Fermé | **30 min** | 9 min | 22:00 | Bientôt | Fermé |
| TER Diamniadio (i=12) | Fermé | Fermé | Fermé | Fermé | 54 min | 3 min | 22:24 | Bientôt | Fermé |
| TER dimanche Diamniadio | Fermé | Fermé | Fermé | Fermé | 54 min | 13 min | 22:14 | Bientôt | Fermé |
| BRT B1 Guédiawaye (i=0) | Fermé | Fermé | Fermé | Fermé | 60 min | 1 min | 21:00 | Bientôt | Fermé |
| BRT B1 Petersen (i=22) | Fermé | Fermé | Fermé | Fermé | **104 min** | 3 min | 21:44 | Bientôt | Fermé |
| AFTU / Tata / DDD | Fermé | Fermé | Fermé | Fermé | **Bientôt** ⚠ | 5 min | 22:00 | **Bientôt** ⚠ | Fermé |

Constats :

1. **Minuit est correctement géré** 🟢 : 23:59, 00:00, 00:01 → `null`, « Service fermé », badge
   « Fermé ». Aucun calcul aberrant, aucune valeur négative, aucun report involontaire.
2. **Aucune valeur ≥ 1000 min n'est produite.** Maximum observé sur les 84 combinaisons :
   **104 min** (BRT Petersen à 05:00). Plafond structurel : **180**.
3. **Le premier départ du lendemain n'est jamais proposé.** Entre le dernier départ et 22:31,
   l'application affiche « Bientôt » / « Prochainement », puis bascule sur « Fermé » — sans jamais
   annoncer l'heure du premier départ du jour suivant (05:30 TER, 06:00 BRT).
4. **Fenêtre « Bientôt » trompeuse, plus large que prévu** : pour BRT B1 elle s'étend de
   **21:45 à 22:30**, soit **45 minutes** pendant lesquelles le badge annonce un départ imminent
   alors qu'il n'y en a plus aucun.
5. **Contradiction inter-écrans** ⚠ : pour AFTU/Tata/DDD à 05:00-05:59 et 22:00-22:30, le badge
   `StopCard` affiche **« Bientôt »** pendant que `nextDepartureLabel()` renvoie **« Service fermé »**
   pour le **même arrêt au même instant**. Les deux écrans se contredisent (§R, H-04).
6. **Écart entre fenêtre déclarée et horaires générés** : la fenêtre est 05:00-22:30 pour TER/BRT,
   mais le premier TER est à **05:30** et le premier BRT à **06:00** (06:44 pour Petersen). Entre
   05:00 et 06:00 l'application se déclare ouverte et affiche des attentes de 30 à 104 min.

---

## H. TER

| Point | Constat |
|---|---|
| Gares | **13**, confirmées : ligne unique `ter_dakar_diamniadio`, `type: TER`, `operator_id: ter`, `short_name: TER`, `long_name: « Dakar Gare ↔ Diamniadio (13 gares officielles SETER/CETUD) »` |
| Confiance JSON | route **OFFICIAL**, et **13/13 arrêts OFFICIAL** ✅ |
| Ordre | `stop_dakar_ter` (i=0) → `stop_diamniadio` (i=12), du nord-ouest au sud-est |
| Keur Massar | **absente** ✅ (les 13 gares sont Dakar, Colobane, Hann, Dalifort, Baux Maraîchers, Pikine, Thiaroye, Yeumbeul, Keur Mbaye Fall, PNR, Rufisque, Bargny, Diamniadio) |
| **Direction « Diamniadio »** | Synthétisée : `'Dir. ${nom du dernier arrêt}'` (L972-973) → « Dir. Diamniadio - Gare TER Terminus » pour i=0…11 ; « Terminus Diamniadio - Gare TER Terminus (Arrivée) » pour i=12 |
| **Direction « Dakar »** | **N'existe pas dans le JSON.** Le JSON ne porte **aucun** champ de sens (§B.1). La direction Dakar n'apparaît que sur **2 arrêts littéraux de démonstration** (L751 « Terminus Dakar (Arrivée) », L752 « Dir. Diamniadio (Embarquement) » — ce dernier étant d'ailleurs libellé Diamniadio, et L756 « Dir. Dakar / Diamniadio ») |
| Sens retour | `DualStopDetailPage` (L3131) : `allerStop = stop.copyWith(direction:…, stopType: boarding)` **conserve les mêmes horaires** ; `retourStop = OppositeStopService.findOppositeStop(…)`. Comme les 13 gares JSON partagent **toutes** le même libellé de direction, la passe 2 (même mode + sens opposé ≤ 500 m) échoue → **`null`** → l'onglet « Sens Retour » affiche un état « non identifié » explicite 🟢 (comportement Groupe 3, conforme §12) |
| Horaires affichés | `_shift(_terBase, i*2)` → décalage **+0 à +24 min** selon l'index. **Synthétiques** (§C.7) |
| Prochain départ | `nextDepartureMinutes()`, pas de 10 min (semaine) / 20 min (dimanche) |
| Temps d'attente | 0 à 10 min (semaine) / 0 à 20 min (dimanche), + l'effet du décalage |
| Horaires codés en dur | Les **8 arrêts TER littéraux** L751-758 : décalages `0, 3, 5, 9, 17, 27, 50, 48` et `distanceMeters` `350, 350, 1200, 3500, 7200, 14200, 35000, 35000`. Ce sont des **résidus de démonstration** qui coexistent avec les 13 gares JSON |
| Horaires historiques | Aucun horaire historique résiduel : `_terBase` est la seule source. En revanche les **8 arrêts littéraux** dupliquent partiellement les gares JSON (« Gare TER Dakar » existe **3 fois** au total : l'arrêt JSON `stop_dakar_ter`
  (14.6760, −17.4335) et **deux** littéraux L751 (14.6792, −17.4407) et L752 (14.6795, −17.4405),
  distants de **24 m entre eux** mais de **851 m et 846 m** de l'arrêt JSON — anomalie G7 O4) |

**Aucune des 13 gares n'a été modifiée. Keur Massar n'a pas été ajoutée.**

---

## I. BRT

| Point | Constat |
|---|---|
| Lignes | **2** : `brt_b1_guediawaye_petersen` (`short_name: BRT B1`) et `brt_b2_express` (`BRT B2 Express`) |
| B1 | **23 stations** ✅ — `stop_brt_23_guediawaye` (i=0) → `stop_brt_01_petersen` (i=22) |
| B2 Express | **7 stations** ✅ — sous-ensemble strict de B1 (`set(B2) ⊆ set(B1)` vérifié), **même sens** (Guédiawaye → Petersen), **pas une inversion** |
| Confiance JSON | B1 et B2 : route **OFFICIAL**, 23/23 et 7/7 arrêts **OFFICIAL** ✅ |
| Directions | Synthétisées comme pour le TER : « Dir. Papa Gueye Fall - PEM Petersen BRT » pour i=0…21, « Terminus … (Arrivée) » pour i=22. **Aucune direction retour dans le JSON** |
| **B2 ne crée aucun arrêt** | B1 étant traité avant B2 dans l'ordre du JSON, les 7 stations de B2 ont déjà leur clé dans `existingKeys` → **0 arrêt créé pour B2**. Seule une polyligne `TransitRoute` distincte est ajoutée (L1041+) |
| Conséquence horaire | Les 7 stations B2 **héritent du décalage B1** (leur index dans B1, pas dans B2). **Il n'existe aucun horaire propre à B2 Express**, et rien ne distingue un arrêt B1 d'un arrêt B2 au niveau du modèle `Stop` (même `modeLabel: 'BRT'`) |
| Horaires affichés | `_shift(_brtBase, i*2)` → décalage **+0 à +44 min** |
| Prochain départ | pas de **6 min**, de 06:00 à 21:00 (+ décalage) |
| Temps d'attente | 0 à 6 min en régime normal ; jusqu'à **104 min** à 05:00 pour Petersen (§G) |
| Données synthétiques | `_brtBase` (151 départs), le décalage `i*2`, et la fenêtre 06:00-21:00 |
| Données historiques | Les **4 arrêts BRT littéraux** L762-765 : « PEM Petersen » (200 m), « BRT Colobane » (150 m), « BRT Grand Dakar » (1500 m), « PEM Guediawaye » (10500 m), décalages `0, 2, 4, 8`. Le modèle historique à **11 stations** n'a **pas** été réintroduit ✅ |
| Horaires codés en dur | Aucun au-delà de `_brtBase` et des 4 littéraux ci-dessus |

**Aucune station n'a été modifiée.**

---

## J. AFTU

| Point | Constat |
|---|---|
| Lignes | **78** lignes AFTU dans le JSON (`operator_id: aftu`, `type: BUS`) — 41 arrêts créés |
| Source du départ | `departureMinutesFromMidnight = []` (L965) → **liste vide** |
| Logique de calcul | `isContinuousFlow == true` (L672, `modeLabel == 'AFTU'`) → **court-circuit avant toute lecture de liste** : `nextDepartureMinutes()` renvoie `5` (L685), `remainingMinutes()` renvoie `5` (L696) |
| Valeur fixe | **5 minutes**, littéral codé en dur à deux endroits |
| Dépendance à l'heure | **Oui, binaire** : `_isServiceOpen()` exige `hour >= 6 && hour < 22` (démarrage à 6 h, **pas** d'extension à 22:30). Hors fenêtre → `null` |
| Dépendance à l'arrêt | **Aucune.** Les 41 arrêts AFTU renvoient exactement la même valeur |
| Dépendance à la ligne | **Aucune.** Aucune des 78 lignes n'intervient |
| Dépendance au GPS | **Aucune** |
| Dépendance à la date | **Aucune.** Aucun traitement du dimanche, aucun jour férié |
| Affichage | Badge **« 5 min »** ; étiquette **« En rotation (~5 min) »** |
| Problème | 🔴 Une valeur **constante et non mesurée** est présentée comme un temps d'attente, sans aucun qualificatif d'incertitude, à côté d'un badge 🔵 « AFTU (72 Lignes Officielles) » |

---

## K. Tata

| Point | Constat |
|---|---|
| Lignes | 4 lignes Tata (`operator_id: tata`) — **8 arrêts** créés |
| Source du départ | `[]` → liste vide |
| Logique | Identique à AFTU : `isContinuousFlow == true` (`modeLabel == 'Tata'`) → **5 min** |
| Valeur fixe | **5 minutes** |
| Dépendances | heure (6 h–22 h) uniquement ; **aucune** à l'arrêt, la ligne, le GPS, la date |
| Affichage | « 5 min » / « En rotation (~5 min) » |
| Problème | 🔴 identique à AFTU |
| Particularité | `labelForOperator` (L915-922) renvoie `'Tata'` pour `operatorId == 'tata'`, mais aussi pour `operatorId == 'aftu'` quand `type.toUpperCase().contains('TATA')`. Le JSON ne contient aucun `type: TATA` (types réels : `TER` 1, `BRT` 2, `BUS` 102), donc cette seconde branche est **inatteinte** |

---

## L. DDD

| Point | Constat |
|---|---|
| Lignes | 23 lignes DDD (`operator_id: ddd`) — **32 arrêts** créés |
| Source du départ | `[]` → liste vide |
| Logique | Identique : `isContinuousFlow == true` (`modeLabel == 'DDD'`) → **5 min** |
| Valeur fixe | **5 minutes** |
| Dépendances | heure (6 h–22 h) uniquement |
| Affichage | « 5 min » / « En rotation (~5 min) » |
| Problème | 🔴 identique, **aggravé** : DDD reçoit le badge 🟢 `DataSourceInfo.demdikk` = « Dakar Dem Dikk (Officiel) » (`origin: official`), alors que **18 de ses 32 arrêts** sont `data_trust: FIELD_OBSERVATION` dans le JSON (§N.4) |

### L.1 Tableau récapitulatif exigé (§8)

| Réseau | Source horaire | Réel / officiel | Synthétique | Problème |
|---|---|---|---|---|
| **TER** | `_terBase` = suite arithmétique 330→1320, pas 10 (20 le dimanche), décalée de `i*2` | ❌ **non** — le JSON n'a aucun horaire ; seules les **13 gares et leurs coordonnées** sont OFFICIAL | ✅ **100 %** (100 ou 50 départs) | 🔴 heures précises (« 14 h 50 ») affichées sans qualificatif, à côté d'un badge 🟢 « SETER (Officiel) ». Pas de sens retour. Grille figée pour toute la session (H-06) |
| **BRT** | `_brtBase` = 360→1260, pas 6, décalée de `i*2` | ❌ **non** — idem ; les **23 stations B1 et 7 B2** sont OFFICIAL | ✅ **100 %** (151 départs) | 🔴 idem, plus : **B2 Express n'a aucun horaire propre** et hérite du décalage B1 (H-15) ; fenêtre « Bientôt » trompeuse de 45 min le soir (H-05) |
| **AFTU** | aucune : liste vide + constante `5` | ❌ **non** | ✅ **100 %** (constante) | 🔴 « 5 min » permanent pour 41 arrêts et 78 lignes, sans aucune dépendance à l'arrêt, la ligne, l'heure (hors fenêtre) ou la date |
| **Tata** | aucune : liste vide + constante `5` | ❌ **non** | ✅ **100 %** (constante) | 🔴 idem pour 8 arrêts |
| **DDD** | aucune : liste vide + constante `5` | ❌ **non** | ✅ **100 %** (constante) | 🔴 idem pour 32 arrêts, **aggravé** par un badge 🟢 « Officiel » alors que 18 arrêts sont `FIELD_OBSERVATION` (H-08) |

**Aucun des cinq réseaux ne dispose d'un horaire réel ou officiel.**

---

## M. `DataStatus`

### M.1 Déclaration

```dart
// lib/main.dart:719
enum DataStatus { scheduled, live, unknown }
```

> **⚠️ `DataStatus.realTime` n'existe pas.** L'énumération ne compte que trois membres, nommés
> `scheduled`, `live` et `unknown`. La chaîne `REAL_TIME` apparaît **3 fois** dans `lib/`, et
> **uniquement dans des commentaires** (L1340, L1371, L2455) qui interdisent d'en produire.
> Le triplet « SCHEDULED / REAL_TIME / UNKNOWN » du cahier des charges se traduit donc par
> `scheduled` / `live` / `unknown`.

Un enum adjacent, `DataOrigin { official, verified, indicative, unavailable }` (L289), qualifie la
**provenance de l'exploitant** — pas la fraîcheur de la donnée horaire. `unavailable` n'y est
**jamais assigné** non plus.

### M.2 Affectations — exhaustives

| Ligne | Affectation | Objet |
|---|---|---|
| 647 | `this.status = DataStatus.scheduled` | `Stop` — valeur par défaut |
| 732 | `this.status = DataStatus.scheduled` | `RouteSegment` — valeur par défaut |
| 738 | `this.status = DataStatus.scheduled` | `PlannedRoute` — valeur par défaut |
| 1156 | `status: DataStatus.scheduled` | `PlannedRoute` dans `_buildRoute` |
| 1157 | `status: DataStatus.scheduled` | `RouteSegment` dans `_buildRoute` |
| 1173 | `status: DataStatus.scheduled` | `PlannedRoute` dans `_findTransfer` |

**6 affectations, toutes `scheduled`.** `DataStatus.live` : **0 affectation**. `DataStatus.unknown` :
**0 affectation et 0 référence** dans `lib/` comme dans `test/`.

### M.3 Lectures — **aucune**

Recherche exhaustive de `.status`, `status ==`, `status !=` dans `lib/` :

| Ligne | Nature |
|---|---|
| 140 | `response.statusCode == 200` — HTTP, **sans rapport** |
| 631, 731, 737 | **déclarations** de champ |
| 655, 665 | plumbing de `copyWith` |
| 647, 732, 738, 1156, 1157, 1173 | **écritures** |
| 1341, 2447, 2562, 2669 | **commentaires** |

> **Il n'existe aucune lecture de `DataStatus` dans tout `lib/`.** Aucune condition, aucun `switch`,
> aucun badge, aucun texte, aucune couleur n'en dépend. `DataStatus` est un champ
> **en écriture seule** : posé à la construction, jamais consulté, jamais affiché.

### M.4 Réponses aux questions posées

| Question | Réponse |
|---|---|
| Existe-t-il un objet réellement marqué **REAL_TIME** ? | **NON.** `realTime` n'existe pas comme membre ; `live` n'est jamais assigné ; et même s'il l'était, rien ne le lirait |
| Existe-t-il un objet réellement marqué **UNKNOWN** ? | **NON.** `unknown` n'est jamais assigné, ni même référencé |
| Existe-t-il un objet réellement marqué **LIVE** ? | **NON.** 0 affectation, 0 lecture |
| Tous les objets sont-ils marqués SCHEDULED ? | **OUI**, les trois classes (`Stop`, `RouteSegment`, `PlannedRoute`), par valeur par défaut ou explicitement |
| Ce marquage a-t-il un effet ? | **AUCUN.** Le champ n'est jamais lu |

**Contraste probant avec `DataTrust`.** Dans le même binaire, l'enum voisin `DataTrust`
(`lib/models/transport_network.dart:5`) voit **ses trois valeurs matérialisées** :
`new A.zc(0,"official")`, `new A.zc(1,"fieldObservation")`, `new A.zc(2,"estimated")`. La raison
est mécanique : `DataTrust.fromString` **construit** les trois, donc dart2js doit les conserver.
`DataStatus`, lui, n'est **jamais construit** autrement que `scheduled` → les deux autres membres
sont élagués. Le compilateur confirme ainsi, indépendamment de l'analyse de source, que
`live` et `unknown` sont du code mort.

### M.5 Écrans affichant « En direct », « Live », « Temps réel », « Programmé »

| Libellé | Dans le source actuel | Dans la production `94a84b60` |
|---|---|---|
| « En direct » | **0 occurrence** (retiré par Groupe 6, E.3) | **0 occurrence** |
| « LIVE » / « Live » | **0 occurrence** | 0 (les 3 `Live` du binaire sont `TextInput.startLiveTextInput` et l'icône `LiveContent`, sans rapport) |
| « REAL_TIME » | 0 (3 commentaires d'interdiction) | **0** |
| **« Programmé »** | **0 occurrence** | **0 occurrence** |
| « Données officielles » | présent (badge Groupe 6, AlertsPage) | **0** (ajout postérieur au build déployé) |
| **« en temps réel »** | **2 occurrences face utilisateur** | 2 occurrences |

Les deux occurrences « temps réel » face utilisateur, avec source et statut réel :

| Fichier:ligne | Texte | Source de la donnée | Statut réel | Cohérence |
|---|---|---|---|---|
| `lib/main.dart:2779` (`SettingsPage`, modale d'aide) | « 1. Utilisez l'onglet Explorer pour visualiser votre position GPS **en temps réel** et les arrêts à proximité. » | Flux `getPositionStream` + ticker 15 s | Position **réellement** rafraîchie quand le GPS fonctionne ; **synthétique** sinon (distances `300+i*800`, tri sur centre fabriqué) | 🟡 **partiellement fondé**, non qualifié. Présent **aussi** en production |
| `lib/main.dart:2960` (`AIChatPage`) | « 🚨 **Alertes en temps réel** : consulte l'onglet "Alertes" (CETUD/SETER) et "Direct rue" (signalements usagers)… » | Alertes = liste statique, sans backend ni horodatage réel | **Aucun** flux temps réel | 🟠 **non fondé**, et en contradiction avec la correction E.4/E.5 du Groupe 6 qui a retiré cette formulation de `CommunityAlertsPage`. **Absent de la production** : `« Alertes en temps réel » → 0 occurrence` dans le binaire → texte **postérieur** au build déployé |

**Aucun écran n'affiche « Programmé »**, alors que c'est le seul statut réellement porté par
toutes les données. L'utilisateur ne voit donc **jamais** le qualificatif qui correspondrait à la
réalité de la donnée horaire.

### M.6 Tests portant sur `DataStatus` (10 références)

| Fichier:ligne | Test | Portée |
|---|---|---|
| `gps_position_test.dart:509` | `DataStatus conserve exactement 3 valeurs` → `hasLength(3)` + noms `['scheduled','live','unknown']` | **verrouille la forme de l'enum** |
| `gps_position_test.dart:515` | `le resolver GPS n'expose AUCUN DataStatus` | couture GPS |
| `gps_position_test.dart:531` | `GARDE-FOU SOURCE : DataStatus.live n'est assigné nulle part` → scan textuel de `lib/main.dart` : `contains('DataStatus.live') == false` **et** `contains('enum DataStatus { scheduled, live, unknown }') == true` | **verrouille textuellement la déclaration** |
| `groupe6_alertes_test.dart:271` | `reason:` rappelant que `live` n'est jamais assigné | alertes |

**Conséquence pour toute correction future** : ajouter un membre (par ex. `realTime`) ou renommer
`live` **casse deux tests** (`hasLength(3)`, la liste des noms, et le scan textuel de la
déclaration). Aucun test ne vérifie en revanche que `unknown` n'est jamais assigné.

---

## N. Affichage utilisateur

### N.1 Inventaire exhaustif des points d'affichage horaire

Il existe **trois** endroits où un départ ou une attente est montré à l'utilisateur, **trois**
autres pour les itinéraires et durées :

| # | Widget | Fichier:ligne | Ce qui est affiché | Provenance |
|---|---|---|---|---|
| 1 | **`StopCard`**, badge `trailing` | 2116-2125 | `Fermé` / `Bientôt` / `Imminent` / `N min` | `remainingMinutes()` (L2111) **+** fenêtre recalculée en ligne (L2116) |
| 2 | **`SingleStopView`**, « Prochain départ » | 3270-3272 | `Service fermé` / `En rotation (~5 min)` / `Prochainement` / `HH h MM` | `nextDepartureLabel()` |
| 3 | **`AIChatPage`**, ligne d'itinéraire | 2884 | `🕒 dep → arr • N min • Direct\|Rotation ~5 min` | `RouteSegment.departureTime`/`arrivalTime` (`_formatMin`) |
| 4 | **`TripsPage`**, carte d'itinéraire | 2344, 2369 | `${totalMinutes} min`, `Durée: ${durationMinutes} min` | `_buildRoute` (durées, pas des horaires) |
| 5 | **`AIChatPage`**, durée totale | 2879 | `⏱️ Durée totale : N min • M correspondance(s)` | idem |
| 6 | **`DetailedRoutePage`**, fiche ligne | 3107 | `⏱ Heure : ~N min` | `DetailedStopInfo.estimatedTime` = `out.length × kMinutesPerStop` (L489, 495) |

**Le point 6 est un libellé trompeur** : `estimatedTime` est une **durée écoulée depuis le terminus**
(nombre d'arrêts précédents × 3 min), mais il est rendu sous le mot **« Heure : »**, précédé d'une
icône `Icons.access_time`. L'usager lit « Heure : ~30 min » comme une heure de passage alors que
c'est un temps de parcours cumulé, purement synthétique (S23). Voir **H-30**.

**`TripsPage` n'affiche jamais `departureTime` ni `arrivalTime`** : ces deux champs sont déclarés
(L730), renseignés (L1157) et **consommés uniquement par `AIChatPage`** (L2884).

Widgets audités et **sans** affichage horaire : `ExplorerPage` (carte, liste, recherche),
`DualStopDetailPage` (conteneur à onglets), `AlertsPage`, `CommunityAlertsPage`, `SettingsPage`.

### N.2 Le seul badge de statut visible : `badgeEmoji`

```dart
// L2161 — sous-titre StopCard, unique point d'affichage
Text('${DistanceHelper.format(distanceMeters)} • ${stop.modeLabel} (${stop.source.badgeEmoji}) • $crowd')
```

`badgeEmoji` est affiché à **un seul endroit** (L2161). `source.label` — le texte explicite
« SETER (Officiel) », « Donnée Indicative (~) » — n'est **jamais affiché** : seul l'émoji l'est.

| `DataSourceInfo` | `origin` | `label` (jamais affiché) | badge (affiché) |
|---|---|---|---|
| `seter` | official | SETER (Officiel) | 🟢 |
| `sunubrt` | official | SunuBRT (Officiel) | 🟢 |
| `demdikk` | official | Dakar Dem Dikk (Officiel) | 🟢 |
| `tataOfficial` | verified | Bus TATA (Officiel) | 🔵 |
| `aftuOfficial` | verified | AFTU (72 Lignes Officielles) | 🔵 |
| `demo` | indicative | Donnée Indicative (~) | 🟡 |

Ce badge qualifie **l'exploitant**, et il est attribué par `sourceForOperator(route.operatorId)`
(L925-933) — **jamais** d'après `data_trust`.

### N.3 🔴 La confusion centrale

Le sous-titre du `StopCard` et son badge d'attente sont **juxtaposés dans la même carte** :

```
┌──────────────────────────────────────────────┬───────────┐
│  Gare TER Dakar                              │           │
│  Dir. Diamniadio - Gare TER Terminus         │   9 min   │  ← synthétique
│  1.5 km • TER (🟢) • 🟠 Dense                │           │
└──────────────────────────────────────────────┴───────────┘
                        ↑                ↑
              distance parfois      badge « officiel »
              synthétique           (exploitant, pas l'horaire)
```

Rien, dans cette carte, ne permet de savoir que **« 9 min » est une valeur synthétique** issue
d'une suite arithmétique. Le 🟢 est légitime quant à l'existence de la gare (JSON `OFFICIAL`),
mais il est **contigu** à une attente fabriquée et il n'existe aucun qualificatif horaire —
ni « Programmé », ni « Estimé », ni « Indicatif ».

### N.4 Croisement confiance réelle × badge affiché (117 arrêts JSON)

| Badge affiché | `data_trust` réel des arrêts | Écart |
|---|---|---|
| 🟢 `seter` | 13 OFFICIAL | ✅ cohérent |
| 🟢 `sunubrt` | 23 OFFICIAL | ✅ cohérent |
| 🟢 `demdikk` | 14 OFFICIAL, **18 FIELD_OBSERVATION** | 🟠 **18 arrêts sur-qualifiés** |
| 🔵 `aftuOfficial` | 4 OFFICIAL, **37 FIELD_OBSERVATION** | 🟡 |
| 🔵 `tataOfficial` | 1 OFFICIAL, **7 FIELD_OBSERVATION** | 🟡 |
| **Total** | 55 OFFICIAL, 62 FIELD_OBSERVATION | |

**68 arrêts portent un badge 🟢 « Officiel », dont 18 sont en réalité `FIELD_OBSERVATION`.**
Le signal de confiance porté par la source unique est **intégralement ignoré** (§B.2).

### N.5 Absence totale de qualification horaire

Recherche exhaustive dans `lib/` : « Programmé » → **0**, « Estimé » → **0**, « Indicatif » →
**0** (hors `label` jamais affiché), « Horaire théorique » → **0**, « Approximatif » → **0**.
Les heures sont rendues par `_formatMin` (L1178-1181) et `nextDepartureLabel` (L702-709) au format
`« HH h MM »`, **sans aucun suffixe ni préfixe** de fiabilité.

---

## O. Données synthétiques — liste exhaustive

| # | Fichier:ligne | Réseau | Contexte | Valeur | Justification | Impact utilisateur | Classe |
|---|---|---|---|---|---|---|---|
| S1 | `main.dart:260` | TER | `_buildTerBase` — début | **330** (05:30) | aucune | premier départ TER affiché | 🔴 |
| S2 | `main.dart:260` | TER | `_buildTerBase` — fin | **1320** (22:00) | aucune | dernier départ TER affiché | 🔴 |
| S3 | `main.dart:260` | TER | `_buildTerBase` — pas semaine | **10 min** | aucune | attente TER 0-10 min, **100 départs/jour** | 🔴 |
| S4 | `main.dart:260` | TER | `_buildTerBase` — pas dimanche | **20 min** | aucune | attente TER 0-20 min, **50 départs** | 🔴 |
| S5 | `main.dart:259` | TER | `_isSunday` | `weekday == 7` | aucune | grille du dimanche ; **évaluée 1 fois par session** | 🟠 |
| S6 | `main.dart:261` | BRT | `_brtBase` — début / fin / pas | **360 / 1260 / 6** | aucune | attente BRT 0-6 min, **151 départs/jour**, identique le dimanche | 🔴 |
| S7 | `main.dart:961` | TER | `_shift(_terBase, i*2)` | **+0 à +24 min** | aucune | décale les horaires le long de la ligne | 🔴 |
| S8 | `main.dart:963` | BRT | `_shift(_brtBase, i*2)` | **+0 à +44 min** | aucune | idem ; Petersen démarre à 06:44 | 🔴 |
| S9 | `main.dart:965` | AFTU/Tata/DDD | `schedule = []` | liste vide | aucune | bascule en flux continu | 🟠 |
| S10 | `main.dart:685, 696` | AFTU/Tata/DDD | `nextDepartureMinutes`/`remainingMinutes` | **5** | aucune | « 5 min » permanent pour **81 arrêts** | 🔴 |
| S11 | `main.dart:704` | AFTU/Tata/DDD | `nextDepartureLabel` | **« En rotation (~5 min) »** | aucune | texte affirmant une fréquence non sourcée | 🔴 |
| S12 | `main.dart:677` | TER/BRT vs autres | `startHour = isContinuousFlow ? 6 : 5` | **5 h / 6 h** | aucune | fenêtre d'ouverture | 🟠 |
| S13 | `main.dart:678-679` | TER/BRT | fin de service | **22 h**, **+30 min** (22:30) | aucune | fenêtre de fermeture | 🟠 |
| S14 | `main.dart:689` | TER/BRT | horizon de recherche | **180 min** | **aucune — NON PROUVÉ** | au-delà : « Prochainement » | 🟠 |
| S15 | `main.dart:1103` | tous | `RoutePlanner.plan` — fenêtre | `>=5 && <22` ou `==22 && <=30` | aucune | 3ᵉ copie contradictoire | 🟠 |
| S16 | `main.dart:1105` | tous | message d'erreur | **« Service de 5h00 à 22h30 »** | aucune | **contredit** S12 (6 h pour AFTU/Tata/DDD) et les premiers départs réels (05:30 / 06:00) ; omet AFTU | 🟠 |
| S17 | `main.dart:2116` | tous | `StopCard` — fenêtre | `>=5 && <22` ou `==22 && <=30` | aucune | 2ᵉ copie contradictoire → badge « Bientôt » vs « Service fermé » | 🟠 |
| S18 | `main.dart:750-758` (`terStations`) | TER | 8 arrêts littéraux | décalages `0,3,5,9,17,27,50,48` | démonstration | horaires TER **différents** de ceux des 13 gares JSON pour les mêmes lieux | 🟠 |
| S19 | `main.dart:761-765` (`brtStations`) | BRT | 4 arrêts littéraux | décalages `0,2,4,8` | démonstration | idem | 🟠 |
| S20 | `main.dart:1028` | AFTU | chemin « orphelins » | `departureMinutesFromMidnight: []` | **dormant** : 0 orphelin | aucun aujourd'hui | 🟡 |
| S21 | `main.dart:1146-1147` | TER/BRT vs autres | vitesses de calcul | **35 / 20 km/h** | aucune | `totalMinutes` des itinéraires | 🟠 |
| S22 | `main.dart:1148` | tous | plancher de durée | **5 min** | aucune | durée minimale d'un segment | 🟡 |
| S23 | `main.dart:388`, `489`, `495` (`kMinutesPerStop`) | TER/BRT | temps par arrêt | **3 min × index** | aucune | `estimatedTime` de la fiche ligne | 🟠 |
| S24 | `main.dart:1194-1203` | tous | `getCrowdLevel` | 7-9/17-19 → « 🔴 Bondé », 10-16 → « 🟠 Dense », sinon « 🟢 Fluide » | aucune | **« Affluence »** affichée en gras, identique pour les **141 arrêts**, paramètre `stop` inutilisé | 🔴 |
| S25 | `main.dart:1151` | tous | `departureAfter(…) ?? safeCurrentMin` | heure courante | aucune | heure de départ **substituée** quand aucun départ n'existe | 🟠 |
| S26 | `main.dart:2938` | TER | réponse assistant | « un départ toutes les 10 à 20 min » | **cohérent** avec S3/S4 | texte exact mais non sourcé | 🟡 |
| S27 | `main.dart:2884` | non-TER/BRT | réponse assistant | « Rotation ~5 min » | aucune | reprend S10 | 🟡 |
| S28 | `main.dart:2201-2202` | — | champs de saisie `TripsPage` | `'Parcelles Assainies'`, `'Petersen'` | démonstration | pré-remplissage visible | 🟡 |

**Aucune de ces 28 valeurs ne provient du JSON.** Toutes sont des constantes codées en dur ou des
formules arithmétiques.

---

## P. Tests existants

### P.1 Inventaire (232 tests, HEAD `0c2ca4d`)

| Fichier | Tests | Dont chaîne horaire |
|---|---|---|
| `dakar_bounds_test.dart` | 18 | **0** |
| `data_service_test.dart` | 10 | **0** |
| `detailed_route_test.dart` | 37 | **0** |
| `gps_position_test.dart` | 40 | **0** |
| `groupe6_alertes_test.dart` | 12 | **0** |
| `network_data_test.dart` | 22 | **0** |
| `opposite_stop_test.dart` | 34 | **0** |
| `ter_brt_route_data_test.dart` | 57 | **0** |
| `widget_test.dart` | 2 | **0** |
| **Total** | **232** | **0** |

### P.2 🔴 Couverture **nulle** — références par symbole dans `test/`

| Symbole | Réf. | Symbole | Réf. |
|---|---|---|---|
| `_generateSchedule` | **0** | `_isServiceOpen` | **0** |
| `_buildTerBase` | **0** | `RoutePlanner` | **0** |
| `_terBase` | **0** | `plan(` | **0** |
| `_brtBase` | **0** | `_findNearestStop` | **0** |
| `_shift` | **0** | `_formatMin` | **0** |
| `_isSunday` | **0** | `formatRemaining` | **0** |
| `remainingMinutes` | **0** | `getCrowdLevel` | **0** |
| `nextDepartureMinutes` | **0** | `StopCard` | **0** |
| `nextDepartureLabel` | **0** | `SingleStopView` | **0** |
| `departureAfter` | **0** | `DualStopDetailPage` | **0** |

Libellés affichés : « Fermé » **0**, « Bientôt » **0**, « Imminent » **0**, « Prochainement » **0**,
« Service fermé » **0**, « En rotation » **0**.
Concepts temporels : `weekday` **0**, `sunday` **0**, `dimanche` **0**, `minuit` **0**,
`22:30` **0**, `5h00` **0**, `1199` **0**, `1189` **0**.

Les **7 occurrences de « 180 »** dans les tests sont toutes **sans rapport** avec l'horizon de
3 heures : `math.pi / 180` (conversion radians, ×3), `180.0 / math.pi` (`opposite_stop_test`),
et les fixtures `c_1800` / `1800` m (`gps_position_test`). **L'horizon de 180 min n'est testé
nulle part.**

L'**unique occurrence de `TimeHelper`** dans les tests figure dans un **commentaire** de
`gps_position_test.dart:81` décrivant l'outil de scan de source — ce n'est pas un test.

### P.3 Ce qui **est** couvert, et qui touche indirectement la chaîne

| Test | Fichier:ligne | Portée réelle |
|---|---|---|
| `DataStatus conserve exactement 3 valeurs` | `gps_position_test.dart:509` | **forme de l'enum uniquement**, pas son usage |
| `GARDE-FOU SOURCE : DataStatus.live n'est assigné nulle part` | `gps_position_test.dart:531` | scan textuel ; verrouille aussi la déclaration |
| `le resolver GPS n'expose AUCUN DataStatus` | `gps_position_test.dart:515` | couture GPS |
| `chaque gare porte un statut de donnée connu (§9)` | `ter_brt_route_data_test.dart` | `data_trust` du **JSON**, pas `DataStatus` |
| `TER : la fiche dérivée compte exactement 13 gares` | `detailed_route_test.dart` | structure, pas horaires |
| `BRT : 23 stations (jamais 11)` | `detailed_route_test.dart` | structure, pas horaires |
| `estimatedTime suit la règle prouvée ~(index * 3) min` | `detailed_route_test.dart` | ⚠️ verrouille **S23**, une valeur synthétique |
| `totalDistance = 34.6 / 17.5 / 16.0 km` | `detailed_route_test.dart` | distances, hors périmètre |

### P.4 Le test placeholder (anomalie G7 O21) est toujours présent

```dart
// test/dakar_bounds_test.dart:162-167 — inchangé, conformément au périmètre P1
group('Stop isContinuousFlow logic', () {
  test('placeholder - verified via modeLabel', () {
    // AFTU/DDD/Tata sont en rotation continue (isContinuousFlow true)
    // Vérifié indirectement via DistanceHelper et DakarBounds
    expect(DistanceHelper.format(100), '100 m');
  });
});
```

Son groupe annonce `isContinuousFlow` ; son commentaire affirme une vérification « indirectement
via DistanceHelper et DakarBounds » ; son assertion porte sur le **formateur de distance**.
`isContinuousFlow` n'est **jamais appelé**. Les 2 occurrences du symbole dans `test/` sont le nom
du groupe et ce commentaire.

**C'est le seul des 232 tests dont l'intitulé annonce la chaîne horaire, et il ne la teste pas.**

### P.5 Confirmation du constat Groupe 7

L'audit Groupe 7 (anomalie O5) affirmait une couverture insuffisante. **Confirmé et précisé** :
la couverture de la chaîne horaires → départs → attente → statut → affichage n'est pas
« insuffisante », elle est **nulle** — 0 test sur 232, 0 symbole référencé sur 20, 0 libellé
affiché verrouillé sur 6. Les 232 tests verts certifient la donnée **structurelle** (13 gares,
23 stations, polylignes, GPS, arrêt opposé, bornes) et **aucun** comportement temporel.

**Aucun test n'a été modifié pendant cet audit.**

---

## Q. Production vs source

Binaire comparé : gh-pages `94a84b60` → `main.dart.js`. Toutes les fonctions ont été résolues
individuellement.

| # | Élément | Production (binaire) | Source actuel | Verdict |
|---|---|---|---|---|
| 1 | `_generateSchedule` | `aIr(a,b,c){ var r=[]; for(s=a;s<=c;s+=b) r.push(s); return r }` | L253-257 | 🟢 **identique** |
| 2 | `_brtBase` | `s($,"b21","aCb",()=>A.aIr(360,6,1260))` | L261 `(from:360,to:1260,step:6)` | 🟢 **identique** |
| 3 | `_terBase` | `s($,"b3b","aCo",()=>A.aIr(330,A.aRz(A.aOl())===7?20:10,1320))` | L260 | 🟢 **identique**, y compris `weekday==7` et 330/1320/20/10 |
| 4 | Initialisation unique | `s($,…,()=>…)` = initialiseur paresseux de statique, exécuté **une fois** | `final` top-level, **une fois** | 🟢 **identique** → H-06 est production-fidèle |
| 5 | Heure locale | `A.aOl(){return new A.cH(Date.now(),0,!1)}` (3ᵉ arg `false` = non-UTC) ; `A.aRz(a){ return ((a.c?getUTCDay():getDay())+6)%7+1 }` → **`getDay()`, jour local** | `DateTime.now()`, aucune conversion UTC | 🟢 **identique** → H-12 production-fidèle |
| 6 | `_isServiceOpen` | `xt(){ r=hour(now); if(r>=(gqy()?6:5)&&r<22) return true; if(!gqy()&&r===22&&min<=30) return true; return false }` | L674-681 | 🟢 **identique** |
| 7 | `nextDepartureMinutes` | `Xc(){ if(!xt())return null; if(gqy())return 5; r=hour*60+min; for(…){ n=q[o]; if(n>=r&&n-r<=180) return n } return null }` | L683-692 | 🟢 **identique**, horizon **180** inclus |
| 8 | `remainingMinutes` | `asb(){ if(!xt())return null; if(gqy())return 5; s=Xc(); if(s==null)return null; return s-(hour(now)*60+min(now)) }` — **deux `Date.now()`** | L694-700 — **deux `DateTime.now()`** | 🟢 **identique**, y compris la double lecture (H-11) |
| 9 | `nextDepartureLabel` | `IM(){ if(!xt())return"Service fermé"; if(gqy())return"En rotation (~5 min)"; s=Xc(); if(s==null)return"Prochainement"; r=s%1440; return pad(r~/60)+" h "+pad(r%60) }` | L702-709 | 🟢 **identique**, mêmes 4 chaînes |
| 10 | `departureAfter` | `amk(a){ if(!xt())return null; if(gqy())return a+5; for(…){ p=s[q]; if(p>a) return p } return null }` | L711-716 | 🟢 **identique** |
| 11 | `formatRemaining` | `aTn(a){ if(a<=0)return"Imminent"; if(a===1)return"1 min"; return""+a+" min" }` | L1188-1192 | 🟢 **identique** |
| 12 | Badge `StopCard` | `Fermé` / `Bientôt` / `Imminent` / `aTn(b)`, fenêtre inline `>=5 && <22 ‖ ==22 && <=30` | L2116-2125 | 🟢 **identique**, contradiction comprise |
| 13 | « Prochain départ » / « Affluence » | `A.aic.$2` : `Text("Prochain départ")` + `h.IM()` + `Text("Affluence")` + `akL(...)` | L3270-3272 | 🟢 **identique** |
| 14 | Message de fermeture | `B.PQ = "🌙 Les réseaux TER, BRT, DDD et TATA sont actuellement fermés (Service de 5h00 à 22h30)."` | L1105 | 🟢 **identique**, y compris l'inexactitude |
| 15 | `DataStatus` | **un seul membre matérialisé** : `B.a2 = new A.a2U(0,"scheduled")`. `"live"` → **0 occurrence** dans tout le binaire ; `"realTime"` → 0 | 3 membres déclarés, 1 seul assigné | 🟢 **équivalent** : dart2js a élagué `live` et `unknown` parce qu'ils ne sont **jamais référencés** — confirmation indépendante de §M |
| 16 | « En direct » / « LIVE » / « Programmé » | **0 occurrence** chacun | 0 occurrence | 🟢 **identique** |
| 17 | « Signalements en temps réel par les usagers à Dakar. » | **présent** | **retiré** par Groupe 6 (E.4/E.5) | 🟢 **divergence volontaire documentée** |
| 18 | « Alertes en temps réel » (`AIChatPage`) | **0 occurrence** | présent, L2960 | 🟠 **divergence** : texte **postérieur** au build déployé (H-09) |
| 19 | Intent assistant « horaire / prochain / depart / quelle heure / passe a » | **présent** : `return "🕒 "+r.a+" ("+r.b+") — lignes "+r.got()+"\nProchain départ : "+r.IM()+"\nAffluence actuelle : "+akL(r)` | **absent** : aucune de ces branches n'existe | 🟠 **régression** : l'assistant ne reporte plus **aucun** prochain départ (H-09) |
| 20 | Réponse « fréquence » de l'assistant | `ter → "toutes les 10 à 20 min (5h–22h30)"`, `brt → "toutes les 6 min en pointe"`, autres → `"rotation continue (~5 min)"`, rendue par `"🕒 Fréquence : "+c` | **absente** ; ne subsiste que « toutes les 10 à 20 min » dans la réponse TER (L2938) | 🟠 **divergence** |
| 21 | Réponse « arrêt » de l'assistant | `"🚏 "+nom+" — "+direction+"\n Lignes : "+got()+"\n🕒 Prochain départ : "+IM()+" • "+akL()+"\n"+opposé+"\n\nDites « je veux aller à X »…"` | **absente** sous cette forme ; réponses réécrites (L2927-2964), registre « tu » au lieu de « vous » | 🟠 **réécriture complète** (zone verrouillée) |
| 22 | Ligne d'itinéraire de l'assistant | `"N. mode : de → à • 🕒 dep → arr (dur min)"` et `"⏱️ "+d+" min • "+r+" correspondance(s)"` | `'   🕒 dep → arr • N min • Direct\|Rotation ~5 min'` (L2884) et `'⏱️ Durée totale : N min • M correspondance(s)'` (L2879) | 🟠 **formats différents** |
| 23 | `RoutePlanner.plan` (complet) | fenêtre inline `>=5 && <22 ‖ ==22 && <=30` → `B.PQ` ; `B.PR` « Lieu de départ introuvable. », `B.PP` « Destination introuvable. » ; seuil de correspondance `> 45` ; tri par durée ; « Aucun itinéraire trouvé entre … » | L1101-1132, mêmes 4 messages, même seuil 45, même tri | 🟢 **identique**, y compris les garde-fous morts (H-10) |
| 24 | `_findNearestStop` | `aG1(a)` : requête vide → null ; sinon `contains`, repli `contains('dakar')` | L1135-1142 | 🟢 **identique** → H-10 production-fidèle |
| 25 | `getCrowdLevel` | `akL(a){ var s,r=A.jq(new A.cH(Date.now(),0,!1)); …"🔴 Bondé (Heure de pointe)"… }` — **le paramètre `a` n'est jamais utilisé** | L1194-1203, `stop` inutilisé | 🟢 **identique** → H-19 production-fidèle |
| 26 | `DataTrust` | `A.zc(0,"official")`, `(1,"fieldObservation")`, `(2,"estimated")` — **3 valeurs matérialisées** | L5-27, parsé mais jamais lu | 🟢 **identique** (H-08 production-fidèle) |
| 27 | `DistanceHelper.format` | `azr` : seuil 950, entier ≥ 10 km | **aligné par P1** (`e506b72`) | 🟢 **corrigé** |

### Q.1 Synthèse §Q

**La chaîne horaires → départs → attente → statut est intégralement production-fidèle.**
Les points 1 à 16 et 23 à 26 sont identiques, au littéral près : mêmes constantes (330, 1320, 360, 1260, 10,
20, 6, 5, 6, 180, 22, 30), mêmes quatre libellés, mêmes messages, même double lecture de l'heure,
même fenêtre contradictoire. **Aucune divergence** n'a été introduite par les Groupes 1 à 7 sur
cette chaîne.

Les divergences (17 à 22) sont **toutes** concentrées dans `AIChatPage`, qui a été réécrit après le
build déployé — zone **verrouillée**, à traiter en Groupe 9.

Conformément à la consigne, **aucun comportement historique n'a été restauré** : les points 18-22
sont documentés, pas corrigés, et le point 17 (retrait de « Signalements en temps réel ») est une
amélioration à conserver.

---

## R. Liste des anomalies

**30 anomalies**, identifiées `H-01` à `H-30` (préfixe `H` = *horaires*, pour éviter toute
collision avec les `O-01`…`O-23` de l'audit Groupe 7). Les identifiants sont **stables** :
l'ordre de présentation suit la **gravité**, pas la numérotation — d'où `H-30` (🟡) placé après
`H-22` et avant le bloc 🟢. Toute référence croisée (`§R H-04`, `G7 O21`, …) reste valable.

| Gravité | Nombre | Identifiants |
|---|---|---|
| 🔴 Critique | **3** | H-01, H-02, H-03 |
| 🟠 Important | **7** | H-04 … H-10 |
| 🟡 À documenter | **13** | H-11 … H-22, H-30 |
| 🟢 Normal / conforme | **7** | H-23 … H-29 |

Les anomalies marquées **« production-fidèle »** (H-04, H-06, H-07, H-10, H-11, H-12, H-18, H-19,
H-08) sont des défauts **hérités du build déployé**, pas des régressions introduites par les
Groupes 1 à 7. Leur correction ferait **diverger** de la production : c'est une amélioration à
décider, non une restauration.

### 🔴 CRITIQUE — peut faire croire à une information réelle

---

**H-01** · 🔴 Critique · `lib/main.dart:2161`, `961-965`, `685`, `696`, `704`, `293-298`

- **Preuve** : le sous-titre du `StopCard` juxtapose `badgeEmoji` (🟢 « SETER (Officiel) » /
  🔵 « AFTU (72 Lignes Officielles) ») et le badge d'attente issu de `remainingMinutes()`.
  Or §B.1 établit que le JSON ne contient **aucun** horaire, et §C.7 que 100 % des départs sont
  synthétiques. Recherche exhaustive : « Programmé » **0 occurrence**, « Estimé » **0**,
  « Indicatif » **0 affiché** (`source.label` n'est jamais rendu, seul l'émoji l'est).
- **Impact** : l'usager voit « 9 min » ou « 14 h 50 » en gras, à côté d'un point vert « officiel »,
  sans aucun qualificatif. Pour AFTU/Tata/DDD il voit « 5 min » en permanence — valeur constante
  non mesurée — sous un badge « Officielles ». **C'est la confusion exacte que le principe
  directeur interdit** : une donnée synthétique est présentée avec les marqueurs visuels d'une
  donnée officielle.
- **Correction potentielle** : rendre visible le statut réel. Deux voies non exclusives —
  (a) afficher un qualificatif horaire à côté de l'heure (« 14 h 50 · programmé (estimation) »),
  (b) faire dépendre le badge de `DataStatus` plutôt que de l'exploitant, et affecter `unknown`
  là où aucun horaire n'existe. Les deux touchent l'UI.
- **Groupe recommandé** : **Groupe 9** (décision produit préalable indispensable : c'est un
  changement d'affichage, donc de contrat vis-à-vis de l'utilisateur).

---

**H-02** · 🔴 Critique · `test/` (9 fichiers, 232 tests)

- **Preuve** : §P.2 — **20 symboles** de la chaîne à **0 référence**, **6 libellés affichés** à
  0 référence, horizon 180 non testé (les 7 « 180 » sont des conversions radians), `TimeHelper`
  présent uniquement dans un commentaire. §P.4 : le seul test à l'intitulé horaire est un
  placeholder sans rapport.
- **Impact** : les 232 tests verts **ne garantissent rien** sur le temps d'attente affiché. Toute
  régression sur `_terBase`, `_shift`, `remainingMinutes`, `_isServiceOpen` ou les fenêtres
  passerait inaperçue. C'est aussi ce qui a permis à H-04 et H-05 de rester invisibles.
- **Correction potentielle** : ajouter un jeu de tests sur les 6 cas de §D.2, les 4 libellés de
  `nextDepartureLabel`, les fenêtres de service, le plafond 180, l'absence de report au lendemain,
  et les cardinaux (151 / 100 / 50).
- **Obstacle structurel** : `_generateSchedule`, `_shift`, `_isSunday`, `_buildTerBase` sont des
  fonctions **top-level privées** ; `_isServiceOpen` est **privée** sur `Stop`. Elles sont
  inaccessibles depuis `test/` sans `@visibleForTesting` ni extraction vers un fichier de service —
  ce qui n'est **pas** une modification neutre. `remainingMinutes`, `nextDepartureLabel` et
  `departureAfter` sont en revanche **publics** et testables immédiatement, à condition de
  maîtriser l'heure (ils lisent `DateTime.now()` en interne, sans injection possible).
- **Groupe recommandé** : **Groupe 9**, en deux temps — d'abord ce qui est testable sans toucher
  à `lib/`, puis décision sur l'injectabilité de l'heure.

---

**H-03** · 🔴 Critique · `lib/main.dart:719` (+ 631, 647, 655, 665, 731-738, 1156-1157, 1173)

- **Preuve** : §M.3 — **aucune lecture** de `.status` dans tout `lib/`. Les 3 membres de l'enum
  sont déclarés, **1 seul** est assigné (`scheduled`, 6 fois), `live` et `unknown` **jamais**.
  `DataStatus.realTime` **n'existe pas**. Confirmation indépendante par le binaire : dart2js n'a
  matérialisé que `new A.a2U(0,"scheduled")`, `"live"` ayant **0 occurrence** dans 2,5 Mo de code.
- **Impact** : le triplet SCHEDULED / REAL_TIME / UNKNOWN exigé par le cahier des charges est
  **structurellement inopérant**. L'application ne peut pas distinguer un horaire programmé d'une
  donnée temps réel d'une donnée inconnue, parce que **rien ne lit le statut**. Le champ est de la
  dette pure : il donne l'illusion d'une modélisation de la fiabilité.
- **Correction potentielle** : deux voies — (a) **utiliser** le champ : affecter `unknown` là où
  l'horaire est synthétique ou absent, et en faire dépendre un affichage (rejoint H-01) ;
  (b) **assumer** qu'il est déclaratif et le documenter comme garde-fou, en ajoutant le test
  manquant sur `unknown`.
- **Contrainte** : la déclaration est **verrouillée textuellement** par
  `gps_position_test.dart:509-512` (`hasLength(3)`, noms exacts) et `:531-540` (scan de source).
  Toute évolution de l'enum casse ces deux tests.
- **Groupe recommandé** : **Groupe 9**, conjointement avec H-01 (même décision produit).

### 🟠 IMPORTANT — comportement incorrect mais identifiable

---

**H-04** · 🟠 Important · `lib/main.dart:674-681` vs `2116` vs `1103`

- **Preuve** : **trois** implémentations indépendantes de la fenêtre de service.
  `_isServiceOpen()` : `startHour = isContinuousFlow ? 6 : 5`, et 22:30 **réservé** aux modes non
  continus. `StopCard` L2116 et `RoutePlanner` L1103 : `>= 5` codé en dur et 22:30 pour **tous**.
  Simulation §G : pour AFTU/Tata/DDD à 05:00, 05:59, 22:00, 22:24, 22:25, 22:30 → badge
  **« Bientôt »** alors que `nextDepartureLabel()` renvoie **« Service fermé »**.
- **Impact** : le même arrêt, au même instant, affiche **« Bientôt »** sur la carte Explorer et
  **« Service fermé »** sur sa fiche. Deux fenêtres quotidiennes concernées (05:00-05:59 et
  22:00-22:30) pour **81 arrêts** AFTU/Tata/DDD.
- **Production-fidèle** : le binaire contient exactement les deux logiques (`A.aiK.$2` inline
  `>=5`, `Stop.xt()` utilise `gqy()?6:5`). Ce n'est donc **pas** une régression.
- **Correction potentielle** : exposer `_isServiceOpen()` en getter public et supprimer les deux
  copies inline. 3 lignes, aucun changement de donnée.
- **Groupe recommandé** : **Groupe 9**. Décision requise : corriger, c'est **diverger** de la
  production (amélioration, pas restauration).

---

**H-05** · 🟠 Important · `lib/main.dart:683-692`, `706`, `2121`

- **Preuve** : aucun report au lendemain (§D.2 cas C, §G). Simulation : BRT B1 dernier départ
  21:44 (Petersen) → badge **« Bientôt »** de **21:45 à 22:30**, soit **45 minutes** ; TER Dakar
  dernier départ 22:00 → « Bientôt » de 22:01 à 22:30.
- **Impact** : « Bientôt » et « Prochainement » sont des formulations **positives** qui annoncent
  un départ alors qu'**il n'y en a plus aucun aujourd'hui**. L'usager attend un bus qui ne viendra
  pas. Le principe « si Dakar Bus ne sait pas, il doit le dire » n'est pas respecté : ici il sait
  (la liste est épuisée) et il dit le contraire.
- **Correction potentielle** : distinguer « aucun départ restant aujourd'hui » de « prochainement »,
  et/ou annoncer le premier départ du lendemain (05:30 TER / 06:00 BRT), qui est **calculable**
  depuis `_terBase`/`_brtBase` sans rien inventer.
- **Groupe recommandé** : **Groupe 9** (texte utilisateur → décision produit).

---

**H-06** · 🟠 Important · `lib/main.dart:259`, `262`

- **Preuve** : `_terBase` est un `final` **top-level** ; `_isSunday()` n'est donc évalué qu'au
  premier accès. Le binaire confirme le même mécanisme (`s($,"b3b","aCo",()=>…)`).
- **Impact** : session ouverte à cheval sur minuit → la grille du jour précédent persiste.
  Concret : un onglet ouvert le samedi soir affiche le samedi toute la nuit ; à 05:00 le dimanche
  il propose des départs toutes les **10 min** au lieu de **20** — soit **deux fois plus** de
  départs que la grille dominicale. Inversement le lundi matin à 05:00 après un dimanche.
- **Correction potentielle** : rendre la base dépendante du jour courant (fonction plutôt que
  constante), ou la recalculer dans le ticker de 15 s.
- **Groupe recommandé** : **Groupe 9**.

---

**H-07** · 🟠 Important · `lib/main.dart:1105` (+ 1103, 677-679, 260-261)

- **Preuve** : le message affirme **« Service de 5h00 à 22h30 »** et cite
  **« TER, BRT, DDD et TATA »**. Or : `_isServiceOpen()` démarre AFTU/Tata/DDD à **6 h** et les
  arrête à **22 h** pile ; `_terBase` commence à **05:30** ; `_brtBase` à **06:00** (06:44 pour
  Petersen) et s'arrête à **21:00** (21:44 avec décalage). **AFTU est omis** de la liste des
  réseaux alors que 41 de ses arrêts sont exposés.
- **Impact** : l'application annonce une plage **fausse** pour trois réseaux sur cinq, et une heure
  de premier départ **fausse** pour les deux autres. Message bloquant : il empêche toute recherche
  d'itinéraire.
- **Production-fidèle** : `B.PQ` contient la chaîne exacte.
- **Correction potentielle** : dériver le message des constantes réelles, ou le rendre neutre.
- **Groupe recommandé** : **Groupe 9** (texte utilisateur).

---

**H-08** · 🟠 Important · `lib/main.dart:925-933` ; `lib/models/transport_network.dart:5-27, 79, 118`

- **Preuve** : `data_trust` est **parsé** (`DataTrust.fromString`) et stocké (`BusStop.dataTrust`,
  `TransportRoute.dataTrust`) mais **jamais lu** par `lib/main.dart` (3 occurrences, toutes en
  commentaire). Le badge vient de `sourceForOperator(operatorId)`. Croisement §N.4 :
  **68 arrêts affichent 🟢 « Officiel », dont 18 sont `FIELD_OBSERVATION`** ; 44 arrêts 🔵 sont
  `FIELD_OBSERVATION`.
- **Impact** : le **seul signal de confiance porté par la source unique est intégralement jeté**.
  Un arrêt relevé sur le terrain est présenté comme officiel. C'est une seconde forme de H-01,
  sur la provenance plutôt que sur la fraîcheur.
- **Correction potentielle** : faire intervenir `busStop.dataTrust` dans le choix du
  `DataSourceInfo` (un `FIELD_OBSERVATION` devrait relever de `indicative`/🟡, pas d'`official`/🟢).
  Le modèle existe déjà, y compris la valeur `DataTrust.estimated` et `DataOrigin.unavailable`,
  toutes deux **jamais utilisées**.
- **Groupe recommandé** : **Groupe 9**. Attention : modifie des badges visibles → décision produit.

---

**H-09** · 🟠 Important · `lib/main.dart:2812-2965` (`AIChatPage`)

- **Preuve** : §Q points 18-22. Production : intent dédié
  `horaire|prochain|depart|quelle heure|passe a` → `"🕒 …\nProchain départ : "+IM()+
  "\nAffluence actuelle : "+akL()` ; réponse « fréquence » par réseau ; réponse « arrêt » avec
  `IM()`. Source : **aucune** de ces branches (grep `contains\('(horaire|prochain|depart|quelle
  heure|passe a)'\)` → **0 résultat**). `nextDepartureLabel` n'est appelé **que** par
  `SingleStopView` (L3272). S'y ajoute « Alertes en temps réel » (L2960), **absent** du binaire.
- **Impact** : l'assistant — point d'entrée conversationnel principal — **ne reporte plus aucun
  prochain départ**. « Prochain départ à Colobane » tombe sur la réponse générique L2962. Perte
  fonctionnelle nette par rapport à la production, et revendication « temps réel » non fondée.
- **Correction potentielle** : rétablir un intent horaire déterministe s'appuyant sur
  `nextDepartureLabel()` (aucune donnée nouvelle à inventer), et retirer « en temps réel ».
- **Groupe recommandé** : **Groupe 9** — `AIChatPage` est un élément **verrouillé**, et la
  correction « 14 gares » (L2938) y est déjà réservée. **Ne rien faire en Groupe 8.**

---

**H-10** · 🟠 Important · `lib/main.dart:1108-1112` (+ `1135-1142`)

- **Preuve** : `_findNearestStop` ne renvoie `null` **que** si la requête est vide ; sinon il
  retombe sur `allStops.firstWhere(contains('dakar'), orElse: allStops.first)`. Les garde-fous
  L1111-1112 (`'Lieu de départ introuvable.'`, `'Destination introuvable.'`) sont donc
  **inatteignables** hors requête vide. Les deux chaînes existent pourtant en production
  (`B.PR`, `B.PP`).
- **Impact** : une requête sans correspondance produit un itinéraire **depuis ou vers un arrêt
  arbitraire**, sans aucun avertissement. Lie directement à l'anomalie G7 **O2**.
- **Correction potentielle** : voir G7 §P2 (renommer + supprimer le repli, ou trier par distance
  avec plafond).
- **Groupe recommandé** : **Groupe 9**, périmètre G7 O2.

### 🟡 À DOCUMENTER — dette technique / architecture

---

**H-11** · 🟡 · `lib/main.dart:699` · `remainingMinutes()` rappelle `DateTime.now()` après
`nextDepartureMinutes()` (L686) → `-1` atteignable à cheval sur une minute. Effet visible bénin
(« Imminent »). **Production-fidèle** (`asb()` fait exactement la même double lecture).
*Correction* : une seule lecture d'horloge, passée en paramètre. *Groupe 9.*

**H-12** · 🟡 · `lib/main.dart:259, 675, 686, 699, 1102, 1195, 2115` · **7 `DateTime.now()`,
0 conversion de fuseau.** Grep : `toUtc` **0**, `timeZone` **0**, `DateTime.utc` **0**, `isUtc` **0**,
`toLocal` **0**. Dakar est à **UTC+0 sans heure d'été** ; un appareil en Europe/Paris décale toutes
les fenêtres (service, pointe, dimanche) de 1 à 2 h. **Production-fidèle** (`A.aOl` construit un
`DateTime` non-UTC, `A.aRz` utilise `getDay()` local). *Correction* : introduire une horloge
Dakar explicite — décision structurante. *Groupe 9 ou ultérieur.*

**H-13** · 🟡 · `lib/main.dart:702, 3272` · `nextDepartureLabel()` est déclarée `String?` mais ses
**quatre** branches renvoient une chaîne non nulle → le `?? 'Fermé'` de L3272 est du **code mort**.
*Correction* : type non nullable, ou conserver. *Groupe 9.*

**H-14** · 🟡 · `lib/main.dart:1151` · `from.departureAfter(safeCurrentMin) ?? safeCurrentMin`
**substitue l'heure courante** comme heure de départ quand aucun départ n'existe, puis
`arr = dep + dur`. Contrairement à `nextDepartureMinutes`, `departureAfter` n'a **ni horizon 180
ni report**. L'itinéraire affiche donc une heure de départ qui n'est pas un départ.
*Correction* : propager un état inconnu plutôt que substituer. *Groupe 9.*

**H-15** · 🟡 · `lib/main.dart:958-966` + JSON `brt_b2_express` · B2 Express (7 stations) est un
sous-ensemble de B1 traité **après** : il ne crée **aucun** arrêt et n'applique **aucun** décalage
propre. Les 7 stations héritent du décalage B1, et rien dans le modèle `Stop` ne distingue B1 de
B2 (`modeLabel: 'BRT'` pour les deux). Aucune fréquence « express » n'existe.
*Correction* : aucune sans donnée nouvelle. *À documenter.*

**H-16** · 🟡 · `lib/main.dart:972-973` + JSON · Le JSON ne porte **aucun** champ de sens. Les 13
gares TER reçoivent toutes « Dir. Diamniadio - Gare TER Terminus » ; **aucune** direction Dakar
n'existe pour elles. La passe 2 d'`OppositeStopService` (même mode + sens opposé ≤ 500 m) échoue
donc systématiquement → `retourStop == null` → onglet « Sens Retour » en état « non identifié ».
**Comportement honnête** 🟢 dans son rendu, mais la limite structurelle mérite d'être rappelée :
c'est le Groupe 3 qui l'a documentée, elle n'a pas changé.

**H-17** · 🟡 · `test/dakar_bounds_test.dart:162-167` · Test placeholder (anomalie G7 **O21**),
toujours présent : groupe `Stop isContinuousFlow logic`, assertion `DistanceHelper.format(100)`.
`isContinuousFlow` n'y est jamais appelé. **Non corrigé, conformément au périmètre P1.**
*Groupe 9.*

**H-18** · 🟡 · `lib/main.dart:1014-1040` · Chemin « orphelins » : `distanceMeters: 500`,
`label = 'AFTU'`, `direction: 'Dir. Centre Dakar'`, `departureMinutesFromMidnight: []` codés en
dur. **Dormant** : 117 arrêts créés par les lignes = 117 arrêts du JSON → **0 orphelin**.
**Production-fidèle** (binaire : `new A.cg(h,"Dir. Centre Dakar",500,…,"AFTU",…)`).
Deviendrait actif — et inventerait mode, direction et flux continu — si le JSON ajoutait un arrêt
non rattaché à une ligne. *Groupe 9.*

**H-19** · 🟡 · `lib/main.dart:1194-1203`, `3278` · `getCrowdLevel(Stop stop)` **n'utilise pas son
paramètre** : étiquette purement horlogère (7-9/17-19 « 🔴 Bondé », 10-16 « 🟠 Dense », sinon
« 🟢 Fluide »), **identique pour les 141 arrêts**, affichée en gras sous l'intitulé
**« Affluence »** (L3278) et dans le sous-titre du `StopCard`. 20 h-22 h → « Fluide » alors que le
service tourne jusqu'à 22:30. **Production-fidèle à l'identique** (`A.akL` ignore aussi son
paramètre). *Aucune correction possible sans donnée d'affluence réelle.*

**H-20** · 🟡 · `lib/main.dart:2201-2202` · `TripsPage` pré-remplit ses champs avec
`'Parcelles Assainies'` et `'Petersen'` : démonstration visible, combinée à H-10 une recherche
non modifiée produit un itinéraire réel entre deux arrêts arbitraires.

**H-21** · 🟡 · `lib/main.dart:730, 1157, 2884` · `RouteSegment.departureTime` et `.arrivalTime`
sont calculés (`_formatMin`) mais **jamais affichés par `TripsPage`** ; seul `AIChatPage` les
consomme. Champs partiellement morts côté UI.

**H-22** · 🟡 · `lib/main.dart:289` · `DataOrigin.unavailable` et `DataTrust.estimated` sont
déclarés et **jamais assignés** — même dette que `DataStatus.unknown` (H-03), sur deux enums
voisins.

**H-30** · 🟡 · `lib/main.dart:3107`, `388`, `489`, `495` · La fiche de ligne affiche
`'Heure : ${stop.estimatedTime}'` avec `Icons.access_time`, où `estimatedTime = '~' + (nombre
d'arrêts précédents × 3) + ' min'`. Une **durée cumulée** est donc présentée sous le mot
**« Heure »**. La constante `kMinutesPerStop = 3` est synthétique (S23) et son décompte a été
volontairement aligné sur la production par le Groupe 4 (correction 4A, commentaire L384-387).
*Impact* : lecture erronée d'un temps de parcours comme d'une heure de passage. *Correction* :
renommer le libellé (« Temps de parcours », « Depuis le terminus »). *Groupe 9* (texte utilisateur).

### 🟢 NORMAL / CONFORME

**H-23** · 🟢 · **1199 / 1189 structurellement impossibles.** Domaine prouvé de
`remainingMinutes()` : `{null} ∪ {5} ∪ [0 ; 180]`. Simulation exhaustive sur 6 arrêts × 14 heures
(84 combinaisons) : **maximum observé 104 min**. À **14:41**, heure du bug historique : TER Dakar
9 min, TER Diamniadio 3 min, TER dimanche 13 min, BRT Guédiawaye 1 min, BRT Petersen 3 min,
flux continu 5 min. Aucun `difference()`, aucun `inMinutes`, aucun `add(Duration` dans `lib/` :
il n'existe **aucune** arithmétique `DateTime` susceptible de produire une telle valeur.

**H-24** · 🟢 · **Minuit correctement géré.** 23:59, 00:00, 00:01 → `null`, « Service fermé »,
badge « Fermé », pour les 6 arrêts testés. Aucune valeur négative, aucun report involontaire.

**H-25** · 🟢 · **13 gares TER, 23 stations B1, 7 stations B2**, toutes `data_trust: OFFICIAL`,
route `OFFICIAL`. Keur Massar absente du TER. Modèle 11 stations non réintroduit.

**H-26** · 🟢 · **Chaîne horaire intégralement production-fidèle** (§Q points 1-16, 23-26) : constantes,
libellés, messages, double lecture d'horloge et fenêtre contradictoire **identiques au binaire**.
Aucune régression introduite par les Groupes 1 à 7 sur cette chaîne.

**H-27** · 🟢 · **Aucun badge « LIVE » / « En direct » / « REAL_TIME » / « Temps réel » dans
l'interface** (0 occurrence ; les 2 « en temps réel » restants sont analysés en H-09 et §M.5).
`DataStatus.live` jamais assigné, gardé par 2 tests.

**H-28** · 🟢 · **Aucun prochain départ n'est fabriqué.** Quand la liste est épuisée ou hors
fenêtre, le code renvoie `null` — jamais une heure inventée. (Le seul `??` de substitution est
H-14, dans le planificateur d'itinéraire, pas dans l'affichage d'un départ.)

**H-29** · 🟢 · `OppositeStopService`, `_resolveJsonStop` (250 m), `DetailedRoute.fromStop`
renvoient `null` plutôt que d'inventer — conforme §12.

---

## S. Périmètre du prochain groupe

**Rien n'est à implémenter en Groupe 8.** Proposition pour le Groupe 9, ordonnée par risque
décroissant et sans préjuger des décisions produit.

### S.1 Ce qui peut être fait **sans toucher à `lib/`** (risque nul)

1. **H-02, premier temps** — tester ce qui est déjà public : `remainingMinutes()`,
   `nextDepartureMinutes()`, `nextDepartureLabel()`, `departureAfter()`, `isContinuousFlow`.
   Couvrir les 6 cas de §D.2, les 4 libellés, le plafond 180, le domaine `[0;180] ∪ {5}`
   (garde-fou direct contre H-23), les cardinaux 151/100/50.
   **Obstacle à lever d'abord** : ces méthodes lisent `DateTime.now()` en interne, sans injection.
   Sans horloge injectable, les tests seraient dépendants de l'heure d'exécution → **non
   déterministes**. C'est un préalable structurant, pas un détail.
2. **H-17** — remplacer le test placeholder par une assertion réelle sur `isContinuousFlow`.

### S.2 Ce qui exige une **décision produit** préalable (affichage)

3. **H-01 + H-03 + H-08** forment **un seul sujet** : *rendre visible la fiabilité réelle de la
   donnée*. À trancher avant tout code —
   - qualifier les horaires synthétiques (« programmé (estimation) », « horaire indicatif ») ?
   - faire dépendre un badge de `DataStatus` plutôt que de l'exploitant ?
   - utiliser enfin `data_trust` (18 arrêts 🟢 à rétrograder en 🟡) ?
   Le principe directeur (« si Dakar Bus ne sait pas, il doit le dire ») impose **oui** aux trois,
   mais cela change ce que voit l'utilisateur : ce n'est pas une correction technique.
4. **H-05** — remplacer « Bientôt » / « Prochainement » par un état explicite
   (« aucun départ restant aujourd'hui », ou le premier départ du lendemain, **calculable** depuis
   `_terBase`/`_brtBase` sans rien inventer).
5. **H-07** — corriger « Service de 5h00 à 22h30 » et la liste de réseaux (AFTU omis).

### S.3 Ce qui est **technique** et peut suivre

6. **H-04** — unifier les trois fenêtres de service sur `_isServiceOpen()`. Divergence volontaire
   par rapport à la production : à assumer comme amélioration.
7. **H-06** — réévaluer la grille dominicale (fonction plutôt que constante top-level).
8. **H-11**, **H-13**, **H-14**, **H-22** — hygiène : lecture d'horloge unique, nullabilité,
   substitution `?? safeCurrentMin`, enums morts.
9. **H-12** — horloge Dakar explicite. Chantier le plus structurant ; à traiter seul.

### S.4 Explicitement **hors** Groupe 9

- **H-09** et la correction « 14 gares » : `AIChatPage`, élément **verrouillé**, à regrouper dans
  un lot dédié.
- **H-10** : relève du périmètre G7 **O2** (`_findNearestStop`).
- **H-15**, **H-16**, **H-18**, **H-19**, **H-20**, **H-21** : à documenter ; aucune correction
  possible sans donnée nouvelle, donc sans invention.
- **Anomalies G7 restantes** : O3, O4, O11, O12, O13 — inchangées, hors périmètre horaire.

### S.5 Rappel des verrous

`dakar_network.json`, les 13 gares TER, les 23 stations B1 et 7 B2, les polylignes (G5),
`AlertsPage` / `CommunityAlertsPage` (G6), Explorer, la navigation, le design, les couleurs, les
filtres, `AIChatPage`, les horaires synthétiques, OSRM, les dépendances — **tous verrouillés**.
La déclaration `enum DataStatus { scheduled, live, unknown }` est en outre **verrouillée par deux
tests** (§M.6).

---

## T. Conclusion

**Aucune donnée horaire réelle n'existe dans Dakar Bus.** Le JSON — source unique — ne porte ni
horaire, ni fréquence, ni headway, ni heure de début ou de fin, ni jour de circulation, ni
calendrier, ni exception, pour aucun des cinq réseaux. Tout ce que l'application affiche comme
heure de départ provient de **28 constantes et formules codées en dur** (§O), dont deux suites
arithmétiques (TER 05:30→22:00 par 10 min, 20 min le dimanche ; BRT 06:00→21:00 par 6 min)
décalées de `2 × index` minutes, et une constante de **5 minutes** appliquée indifféremment aux
**81 arrêts** AFTU, Tata et DDD.

**Le calcul, lui, est correct.** La chaîne `liste → prochain départ → attente` est exacte, bornée
(`[0 ; 180] ∪ {5}`), sans report involontaire, correcte à minuit, et **intégralement fidèle à la
production** sur 16 points de comparaison. Le bug historique 1199/1189 est **structurellement
impossible** aujourd'hui : maximum observé 104 min sur 84 combinaisons, et aucune arithmétique
`DateTime` n'existe plus dans le code.

**Le problème n'est donc pas le calcul, c'est le statut.** Trois faits le résument :

1. `DataStatus` n'est **jamais lu** — le modèle ne peut pas exprimer la différence entre
   programmé, temps réel et inconnu, et `realTime` n'existe même pas comme membre (§M).
2. **Aucun qualificatif** n'accompagne une heure affichée : « Programmé », « Estimé »,
   « Indicatif » ont 0 occurrence (§N.5).
3. Le seul marqueur de fiabilité visible est un **émoji de provenance exploitant** (🟢/🔵),
   attribué sans tenir compte du `data_trust` réel du JSON — 18 arrêts `FIELD_OBSERVATION`
   s'affichent 🟢 « Officiel » (§N.4) — et il est **contigu** à une attente synthétique (§N.3).

Résultat : une donnée **100 % synthétique** est présentée avec les marqueurs visuels d'une donnée
**officielle**, sans aucun moyen pour l'usager de le savoir. C'est précisément la confusion que le
principe directeur interdit — et elle n'est pas produite par un badge « LIVE » (il n'y en a aucun),
mais par **l'absence** de tout badge de statut.

Deux aggravations : **trois** fenêtres de service contradictoires font dire « Bientôt » à la carte
pendant que la fiche dit « Service fermé » (H-04), et l'absence de report au lendemain transforme
« Bientôt » en annonce d'un départ qui n'existe plus, pendant jusqu'à 45 minutes (H-05). Enfin,
**0 des 232 tests** ne couvre cette chaîne (H-02) : rien ne protège aucun de ces comportements.

---

**GROUPE 8 — AUDIT TERMINÉ — AUCUNE MODIFICATION FONCTIONNELLE EFFECTUÉE**
