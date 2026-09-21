# GROUPE 6 — RAPPORT D'AUDIT STRICT AVANT IMPLÉMENTATION

**Date** : 2026-09-22
**Branche** : `arena/01a0c385-dakar-bus`
**HEAD audité** : `87f54d6`
**Périmètre** : audit seul. **Aucune modification fonctionnelle effectuée.**
**Règle appliquée** : pas de donnée inventée. Si Dakar Bus ne sait pas → `UNKNOWN`.
Si Dakar Bus sait → l'afficher correctement. Toute affirmation non démontrable est
classée `UNKNOWN` ou `NON PROUVÉ`, jamais complétée par une estimation.

---

## A. ÉTAT ACTUEL

| Élément | Valeur vérifiée | Statut |
|---|---|---|
| HEAD arena | `87f54d6` — « Groupe 5 — micro-correction AlertsPage » | ✅ |
| Arbre de travail | propre, **0 fichier modifié, 0 fichier non suivi** | ✅ |
| `main` distant | `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` | ✅ inchangé |
| `gh-pages` distant | `94a84b6070569bed708b8e779b9e70b7c9dafa45` | ✅ inchangé |
| Dernier build Pages | `built 2026-09-19T12:14:29Z` | ✅ antérieur à tout ce travail → **aucun déploiement** |
| CI (run `35661781590`, job `106538460935`) | `completed/success` | ✅ |
| Sortie CI exacte | `tests +219/-0 \| 8 fichiers \| analyze 0 issue(s) \| exit a=0 t=0 \| Flutter 3.24.5 • channel stable` | ✅ |
| `flutter analyze` | `No issues found! (ran in 11.5s)` | ✅ |
| `dakar_network.json` | md5 `81c778f4644dcf5e1cf4ae25879218f0` | ✅ inchangé |
| `pubspec.yaml` | md5 `a44209df21aa059becf0ae95dcc8d058`, `version: 9.3.2+12` | ✅ inchangé |
| Dépendances | aucune ajoutée | ✅ |
| Runs CI déclenchés par l'audit | **aucun** | ✅ |

**Taille du code audité** : `flutter-src/lib/main.dart` = 3 212 lignes.

**Chaîne de données au démarrage** (`main()`, L31-38) :

```dart
await appDataService.loadNetworkData();   // L31 — lit assets/data/dakar_network.json
_integrateNetworkData();                  // L32 — coud le JSON dans les structures de l'app
runApp(const DakarBusApp());              // L38
```

→ **Le JSON est réellement chargé et utilisé au runtime**, pas seulement dans les
tests. `integrateNetworkDataForTest()` (L874) n'est qu'une couture de test appelant
la même fonction privée.

---

## B. DONNÉES CONFIRMÉES (par la source unique `dakar_network.json`)

### B.1 Contenu exact de la source unique

| Clé | Champs disponibles |
|---|---|
| racine | `operators`, `routes`, `stops` |
| `operators[]` | `color`, `id`, `name` |
| `stops[]` | `data_trust`, `id`, `latitude`, `longitude`, `name` |
| `routes[]` | `data_trust`, `id`, `long_name`, `operator_id`, `short_name`, `stops`, `type` |

> **FAIT STRUCTUREL DÉTERMINANT** : la source unique ne contient **aucun champ
> horaire, aucune fréquence, aucune heure de départ, aucun headway, aucun sens de
> circulation**. Toute donnée de ce type présente dans l'application est
> nécessairement **synthétique ou codée en dur** — jamais issue de la source.

### B.2 Volumes confirmés

- **5 opérateurs** : `ter`, `brt`, `ddd`, `aftu`, `tata`
- **105 lignes**, **117 arrêts**
- **117 / 117 arrêts sont desservis par au moins une ligne** → **0 arrêt orphelin**
- Lignes par opérateur : `aftu` 80 · `ddd` 15 · `tata` 7 · `brt` 2 · `ter` 1
- `data_trust` du TER et du BRT B1/B2 = `OFFICIAL`

### B.3 Deux familles de noms de ligne (source de confusion fréquente)

| Famille | Nombre | Détail |
|---|---|---|
| `AFTU n` | **72** | numéros **1 à 72, aucun trou** |
| `DDD n` | 12 | 1, 3, 7, 8, 9, 10, 11, 12, 14, 15, 20, 23 |
| `Tata n` | 5 | 50, 64, 78, 218, 219 |
| `BRT B1` / `BRT B2 Express` | 2 | — |
| `TER` | 1 | — |
| `NEW nn` | **13** | `new_commune_01…13`, répartis : 8 → aftu, 3 → ddd, 2 → tata |

> ⚠️ **Correction d'une lecture erronée possible** : `AFTU 3` et `NEW 03` sont
> **deux lignes distinctes**, pas un doublon. Compter les chiffres des
> `short_name` sans distinguer les familles fait apparaître 8 faux doublons AFTU.
> Le total réel est **72 lignes AFTU numérotées + 8 lignes `NEW` rattachées à
> AFTU = 80 entrées**.

### B.4 Affirmations de l'application vérifiées comme **CONFIRMÉES**

| Affirmation | Preuve JSON | Verdict |
|---|---|---|
| « 72 lignes AFTU » (assistant L2852) | 72 lignes `AFTU n`, numéros 1..72 sans trou | ✅ **CONFIRMÉ** |
| TER Dakar ↔ Diamniadio | `long_name` = `'Dakar Gare ↔ Diamniadio (13 gares officielles SETER/CETUD)'` | ✅ **CONFIRMÉ** |
| TER = **13 gares** | `routes[ter_dakar_diamniadio].stops` = 13 identifiants | ✅ **CONFIRMÉ** |
| BRT B1 = **23 stations** | `routes[brt_b1_guediawaye_petersen].stops` = 23 | ✅ **CONFIRMÉ** |
| BRT : Guédiawaye ↔ Petersen | station #1 `Préfecture Guédiawaye - PEM BRT`, #23 `Papa Gueye Fall - PEM Petersen BRT` | ✅ **CONFIRMÉ** |
| BRT via Dalal Jamm | #5 `Hôpital Dalal Jamm - BRT` | ✅ **CONFIRMÉ** |
| BRT via Parcelles Assainies | #8 `Parcelles Assainies - BRT` | ✅ **CONFIRMÉ** |
| BRT via l'Obélisque | #21 `Place de la Nation - Obélisque - BRT` | ✅ **CONFIRMÉ** |
| DDD « L1 Colobane-Yoff » (L2846) | `ddd_1` = `'Colobane ↔ Yoff Pêcheurs (DDD Ligne 1)'` | ✅ **CONFIRMÉ** (abrégé) |
| DDD « L3 Sandaga-Ouakam » (L2846) | `ddd_3` = `'Sandaga ↔ Ouakam / Ngor (DDD Ligne 3)'` | ✅ **CONFIRMÉ** (abrégé, `/ Ngor` omis) |
| TATA dessert Guédiawaye, Pikine, Yoff, Mermoz, Keur Massar (L2849) | 1 + 1 + 4 + 1 + 2 arrêts TATA correspondants | ✅ **CONFIRMÉ** |
| DDD « lignes régulières 1, 3, 10, 14 et 20 » (AlertsPage) | `ddd_1`, `ddd_3`, `ddd_10`, `ddd_14`, `ddd_20` existent | ✅ **CONFIRMÉ** (liste partielle : DDD a 15 lignes) |
| Les 9 lignes citées par les points de démo | DDD 1/3/10/14/20 + TATA 50/64/78/218 toutes présentes | ✅ **CONFIRMÉ** |

### B.5 Keur Massar — statut définitif

| Arrêt JSON | Lignes le desservant |
|---|---|
| `stop_keur_massar` | `ddd_23`, `aftu_5`, `aftu_38`, `aftu_46`, `aftu_53`, `tata_218` — **6 lignes** |
| `stop_keur_massar_nord` | `new_commune_11` — 1 ligne |
| `stop_jaxaay` (Jaxaay - Keur Massar) | `new_commune_05` — 1 ligne |
| `stop_malika` (Malika - Keur Massar) | `new_commune_05` — 1 ligne |

> ✅ **Aucune ligne TER ne dessert Keur Massar.**
> ✅ **`ter_8` n'existe PAS dans `dakar_network.json`** (vérifié : `'ter_8' in stops` → `False`).
> `ter_8` n'existe **que dans le binaire de production déployé** (voir §J.4 et E.20).

### B.6 Distances — formule prouvée et revérifiée indépendamment

`totalDistance` = somme des haversine(arrêtᵢ, arrêtᵢ₊₁), **R = 6 371 008,8 m**.

| Ligne | Arrêts | Somme de cordes (revérifiée) | Documenté dans le source |
|---|---|---|---|
| `ter_dakar_diamniadio` | 13 | **34,6 km** | 34,6 km ✅ |
| `brt_b1_guediawaye_petersen` | 23 | **17,5 km** | 17,5 km ✅ |
| `brt_b2_express` | 7 | **16,0 km** | 16,0 km ✅ |

> **Les trois grandeurs « 14,0 km / 17,5 km / 18,3 km » sont distinctes et
> désormais tranchées** :
> - `14,0 km` = **littéral codé en dur** de la production (supprimé par Groupe 2)
> - `17,5 km` = **somme de cordes géographiques** calculée depuis la source unique
> - `18,3 km` = **longueur officielle du corridor annoncée par le CETUD**
>   (longueur de voirie, grandeur différente par nature)
> Le constat F7 du Groupe 4 (« NON PROUVÉ ») est donc **POUVÉ CONFORME**.

---

## C. DONNÉES HARDCODÉES

### C.1 Les 24 points de démonstration (`main.dart` L750-791)

| Liste | Ligne | Nb | Mode |
|---|---|---|---|
| `terStations` | L750 | **8** | TER |
| `brtStations` | L761 | **4** | BRT |
| `dddStations` | L769 | 5 | DDD |
| `tataStations` | L778 | 4 | Tata |
| `aftuAndBusStations` | L785 | 3 | AFTU |
| **`allStops`** | **L791** | **24** | concaténation + filtre `DakarBounds.isValid` |

Chaque point porte : `name`, `direction`, **`distanceMeters` (littéral)**,
`departureMinutesFromMidnight` (synthétique), `icon`, `color`, **`location`
(littéral LatLng)**, `modeLabel`, `source`, `stopType`.

**`distanceMeters` codés en dur** : TER 350 / 350 / 1 200 / 3 500 / 7 200 /
14 200 / 35 000 / 35 000 m — BRT 200 / 150 / 1 500 / 10 500 m.

> ⚠️ `35000` reproduit exactement le littéral « 35.0 km » de la production.
> ⚠️ `14200` pour « Gare TER Keur Mbaye Fall » contredit la production, qui
> indiquait `17.0 km` pour cette gare (`ter_9`).

### C.2 Horaires synthétiques (`_generateSchedule`, L253-262)

```dart
L253  List<int> _generateSchedule({required int from, required int to, required int step})
L258  List<int> _shift(List<int> base, int offset) => base.map((m) => m + offset).toList();
L259  bool _isSunday() => DateTime.now().weekday == DateTime.sunday;
L260  List<int> _buildTerBase() => _generateSchedule(from: 330, to: 1320, step: _isSunday() ? 20 : 10);
L261  final List<int> _brtBase = _generateSchedule(from: 360, to: 1260, step: 6);
L262  final List<int> _terBase = _buildTerBase();
```

| Réseau | Fenêtre | Pas | Nb de départs générés |
|---|---|---|---|
| TER (lun-sam) | 330 → 1320 min = **05:30 → 22:00** | 10 min | **100** |
| TER (dimanche) | idem | 20 min | **50** |
| BRT | 360 → 1260 min = **06:00 → 21:00** | 6 min | **151** |
| DDD / TATA / AFTU | — | — | `schedule = []` (**aucun horaire**) |

`_shift(base, i * 2)` décale la grille de **+2 minutes par index d'arrêt**
(ex. `_shift(_terBase, 50)` pour Diamniadio → +100 min).

### C.3 Constantes de temps codées en dur

| Élément | Ligne | Valeur |
|---|---|---|
| `Stop.isContinuousFlow` | L672 | `modeLabel == 'AFTU' \|\| 'Tata' \|\| 'DDD'` |
| `nextDepartureMinutes()` flux continu | L685 | **`return 5`** (5 min fixes) |
| `remainingMinutes()` flux continu | L696 | **`return 5`** |
| `departureAfter()` flux continu | L713 | `minFromMidnight + 5` |
| Libellé | L704 | `'En rotation (~5 min)'` |
| Fenêtre de service (continu) | L677 | 06:00 → 22:00 |
| Fenêtre de service (non continu) | L677-679 | 05:00 → 22:30 |
| Fenêtre `StopCard.isOpen` | L2078 | 05:00 → 22:30 |
| Fenêtre `RoutePlanner.isOpen` | L1103 | 05:00 → 22:30 |
| Fenêtre de recherche du prochain départ | L689 | `≤ 180 min` |
| `TimeHelper.getCrowdLevel` | L1194-1202 | Bondé 7-9 & 17-19 · Dense 10-16 · Fluide sinon |
| `RoutePlanner` vitesse TER/BRT | L1145 | **35,0 km/h** |
| `RoutePlanner` vitesse autres | L1145 | **20,0 km/h** |
| Durée minimale d'un segment | L1147 | `if (dur < 5) dur = 5` |
| Pénalité de correspondance | L1174 | `+ 5` min |
| Hub de correspondance | L1163 | 1ᵉʳ arrêt contenant `'Colobane'` ou `'Petersen'` |
| Seuil de déclenchement d'une correspondance | L1121 | `> 45 min` |
| `DetailedRoute.kMinutesPerStop` | L388 | `3` min par arrêt |

> ⚠️ **`TimeHelper.getCrowdLevel(Stop stop)` IGNORE son paramètre `stop`.**
> La valeur retournée ne dépend **que** de `DateTime.now().hour`. Aucun arrêt,
> aucune ligne, aucune donnée de fréquentation n'intervient.

### C.4 Alertes et signalements — 100 % littéraux

| Élément | Ligne | Nature |
|---|---|---|
| `AlertsPage.officialAlerts` | L2354-2412 | **3 cartes littérales**, aucune dérivation JSON |
| En-tête AlertsPage | L2423 | `'Informations certifiées CETUD, SETER, SunuBRT & Dakar Dem Dikk.'` |
| `_communityReports` | L2484-2487 | **2 signalements usagers littéraux** |
| En-tête Direct rue | L2578 | `'Signalements en temps réel par les usagistes à Dakar.'` |

Les 2 signalements littéraux :

```dart
L2485 {'user':'Mamadou S.','location':'Parcelles Assainies (BRT)','type':'Trafic fluide',      'time':'Il y a 3 min','status':'🟢 Fluide'}
L2486 {'user':'Aïssatou N.','location':'Gare de Dakar (TER)',     'type':'Embarquement régulier','time':'Il y a 6 min','status':'🟢 Fluide'}
```

> ⚠️ `'Il y a 3 min'` / `'Il y a 6 min'` sont des **chaînes figées** : elles ne
> sont jamais recalculées. Un signalement affiché « il y a 3 min » reste
> « il y a 3 min » indéfiniment, y compris après plusieurs jours.

### C.5 Assistant IA — règles `if/else` sur mots-clés (`AIChatPage` L2714-2932)

| Ligne | Déclencheurs | Réponse |
|---|---|---|
| L2806 | `aller`, `trajet`, `veux aller`, `comment aller`, regex `de X à Y` | calcul d'itinéraire via `RoutePlanner` |
| L2829 | destination manquante | demande de précision |
| L2840 | `ter`, `train`, `diamniadio` | texte littéral TER |
| L2843 | `brt`, `guédiawaye`, `petersen`, `sunu` | texte littéral BRT |
| L2846 | `ddd`, `dakar dem dikk`, `ligne 1`, `ligne 3` | texte littéral DDD |
| L2849 | `tata`, `minibus`, `ligne 50` | texte littéral TATA |
| L2852 | `aftu`, `parcelles`, `grand yoff` | texte littéral AFTU |
| L2855 | `où suis-je`, `autour de moi`, `proche` | 3 arrêts les plus proches (**calculé**) |
| L2862 | `alerte`, `bouchon`, `trafic`, `direct rue` | texte littéral |
| L2864 | tout le reste | texte littéral |

**État mémorisé** : `_dernierModeInterroge` (L2727) — unique variable de session,
alimentée à L2836 (premier segment d'un itinéraire) et L2839/2842/2845/2848/2851.
Affichée à L2866. **Aucune persistance** (perdue à la fermeture de la page).

**Message d'accueil** (L2724) : `'Nanga def ! 👋 Je suis votre assistant IA expert
des mobilités à Dakar…'`

### C.6 Fidélité à la production — qualification indispensable

Vérification par décodage du binaire déployé (`gh-pages 94a84b6`, `main.dart.js`,
échappements `\xNN`/`\uNNNN` résolus) :

| Élément codé en dur | Dans le binaire de production ? | Qualification |
|---|---|---|
| `_generateSchedule(330, 1320, 10/20)` | ✅ `s($,"b3b","aCo",()=>A.aIr(330,A.aRz(A.aOl())===7?20:10,1320))` | **HARDCODÉ + FIDÈLE** |
| `_generateSchedule(360, 1260, 6)` | ✅ `s($,"b21","aCb",()=>A.aIr(360,6,1260))` | **HARDCODÉ + FIDÈLE** |
| `isContinuousFlow` = AFTU/Tata/DDD | ✅ `gqy(){var s=this.x return s==="AFTU"\|\|s==="Tata"\|\|s==="DDD"}` | **HARDCODÉ + FIDÈLE** |
| `return 5` du flux continu | ✅ `Xc(){…if(this.gqy())return 5…}` | **HARDCODÉ + FIDÈLE** |
| Fenêtre 5h/22h30 + 6h/22h | ✅ `xt(){…if(r>=(this.gqy()?6:5)&&r<22)…r===22&&A.v6(s)<=30…}` | **HARDCODÉ + FIDÈLE** |
| Fenêtre de recherche ≤ 180 min | ✅ `if(n>=r&&n-r<=180)return n` | **HARDCODÉ + FIDÈLE** |
| `getCrowdLevel` ignorant son paramètre | ✅ `akL(a){var s,r=A.jq(new A.cH(…))…}` — `a` jamais lu | **HARDCODÉ + FIDÈLE** |
| `'Imminent'` / `'1 min'` / `'N min'` | ✅ `aTn(a){if(a<=0)return"Imminent"…}` | **HARDCODÉ + FIDÈLE** |
| `'Service fermé'` / `'En rotation (~5 min)'` / `'Prochainement'` | ✅ `IM(){…}` | **HARDCODÉ + FIDÈLE** |
| `timeWidget` StopCard (`Fermé`/`Bientôt`/`Imminent`) | ✅ identique | **HARDCODÉ + FIDÈLE** |
| Les 24 points de démonstration | ✅ `$.aCz()` = `terStations` avec `q="Gare TER Dakar"…h=$.aCo()` | **HARDCODÉ + FIDÈLE** |
| Les 2 signalements usagers | ✅ `A.yX.prototype.ab()` → `Mamadou S.` / `Il y a 3 min` / `Aïssatou N.` / `Il y a 6 min` | **HARDCODÉ + FIDÈLE** |
| `'Informations certifiées CETUD, SETER…'` | ✅ présent | **HARDCODÉ + FIDÈLE** |
| Les **3 cartes** `officialAlerts` du source | ❌ `'Réseau CETUD'`, `'14 Gares'`, `'Gares Officielles'`, `'Corridor officiel SunuBRT'`, `'En direct'`, `'lignes régulières 1, 3, 10, 14 et 20'` : **0 occurrence** | **INVENTION DU SOURCE** |
| `'usagistes'` (L2578) | ❌ production dit `'usagers'` | **FAUTE introduite par le source** |
| `[Mémorisé : …]`, `'Astuce : ouvre'`, `'Position GPS prise en compte'`, `'fonctionnent normalement'` | ❌ **0 occurrence** | **INVENTION DU SOURCE** |
| `'14 gares officielles'` (L2840) | ❌ production calcule dynamiquement | **RÉGRESSION DU SOURCE** |

---

## D. DONNÉES CALCULÉES

| Donnée | Emplacement | Formule | Source des entrées |
|---|---|---|---|
| `totalDistance` | L516 | Σ haversine(arrêtᵢ, arrêtᵢ₊₁), R=6371008.8 | JSON |
| `distanceFromStart` | L494 | cumul depuis le 1ᵉʳ arrêt | JSON |
| `estimatedTime` | L494+ | `~(index × 3) min`, compteur démarrant à **0** | JSON (ordre) + constante `kMinutesPerStop=3` |
| Polylignes de la carte | `demoRoutes` L1095 **vide**, alimentée par `_integrateNetworkData` L886 | tracé dérivé des arrêts de chaque ligne | JSON |
| Tracés au démarrage | `_loadDynamicRoutes` | lignes `isDedicated` (`type == 'TER' \|\| 'BRT'`) | JSON |
| Tracés différés | idem | les autres, `take(20)` via OSRM | JSON + OSRM |
| `direction` d'un arrêt | `_integrateNetworkData` | **synthétisée** d'après la position de l'arrêt dans sa ligne | ⚠️ voir D.1 |
| Distance Explorer | `_distanceTo` L1759 | haversine(position GPS, arrêt) **si GPS connu** | GPS réel |
| Arrêts proches | L1759+ | filtre `≤ 4000 m`, tri, `take(30)` | GPS réel |
| Résolution point démo → arrêt JSON | `_resolveStop` | passe 1 nom exact ; passe 2 proximité **≤ 250 m** ; sinon `null` | JSON |
| Arrêt opposé | `OppositeStopService` | passe 1 inclusion de nom **≤ 120 m** ; passe 2 même mode + sens opposé **≤ 500 m** | JSON |
| Prochain départ | `nextDepartureMinutes` L685 | 1ᵉʳ horaire `≥ maintenant` et `≤ 180 min` | ⚠️ **grille synthétique** (C.2) |
| Itinéraire planifié | `RoutePlanner._buildRoute` L1143 | `dist / vitesse × 60`, arrondi sup., min 5 min | haversine + vitesses codées en dur |
| Correspondance | `_findTransfer` L1161 | hub + `leg1 + leg2 + 5 min` | codé en dur |
| 3 arrêts proches (assistant) | L2856 | tri par haversine, `take(3)` | GPS réel |
| Compteurs de lignes (assistant) | — | **aucun** : valeurs littérales | ⚠️ voir K |

### D.1 Limite structurelle documentée — le sens de circulation

`main.dart` L3052-3060 porte déjà ce constat, **volontairement non corrigé** :

> « `dakar_network.json` ne contient AUCUN champ de sens — un arrêt n'y porte que
> id, name, latitude, longitude et data_trust. La "direction" que compare la
> passe 2 est donc un libellé synthétisé par `_integrateNetworkData` d'après la
> position de l'arrêt dans sa ligne, et non un sens réel issu de la source unique. »

✅ **Conforme à la règle fondamentale** : corriger exigerait d'inventer un sens que
la donnée ne fournit pas. **À ne pas modifier.**

### D.2 Constat F7 (Groupe 4, D6-i) — déjà documenté, volontairement inchangé

`_distanceTo` (L1759) retombe sur `s.distanceMeters` — la **valeur codée en dur** —
quand `widget.userPosition == null`, et `StopCard` l'affiche comme s'il s'agissait
de la distance de l'utilisateur à l'arrêt. Le commentaire L1740-1757 documente
explicitement ce comportement et la décision de **ne pas** le modifier.

> ℹ️ Ce n'est **pas une découverte de l'audit** : c'est un constat porté au
> rapport du Groupe 4, laissé inchangé conformément à la règle « ne rien
> réimplémenter de NON PROUVÉ ». La **formule de distance** est depuis POUVÉE
> CONFORME (§B.6) ; le **repli sans GPS** reste, lui, inchangé et documenté.

---

## E. INCOHÉRENCES DÉTECTÉES

| # | Fichier · ligne | Valeur actuelle | Valeur de référence | Preuve | Impact | Priorité |
|---|---|---|---|---|---|---|
| **E.1** | `main.dart` **L2840** | `« …en traversant 14 gares officielles… »` | **13** | JSON `ter_dakar_diamniadio.stops` = 13 ; `long_name` dit littéralement « 13 gares officielles SETER/CETUD » | L'assistant contredit la source unique **et** AlertsPage déjà corrigé en `87f54d6`. Incohérence visible par l'utilisateur | 🔴 **HAUTE** |
| **E.2** | `main.dart` **L2392** | BRT : `« …en passant par Dalal Jamm, Parcelles Assainies, Grand Yoff et la Place de l'Obélisque. »` | **Grand Yoff absent de B1** | Les 23 stations B1 ne contiennent aucun « Grand Yoff ». `stop_grand_yoff` est desservi par DDD/AFTU uniquement | Affirme une station inexistante sur le corridor officiel BRT | 🔴 **HAUTE** |
| **E.3** | `main.dart` **L2394** | badge `'En direct'` sur l'alerte BRT | aucun flux direct n'existe | `DataStatus.live` **n'est jamais assigné** (L719 ; confirmé par le commentaire L1303 « 4A Carte 14 »). Les 3 cartes sont des littéraux statiques | §18 : jamais de faux LIVE. L'utilisateur croit à du temps réel | 🟠 **MOYENNE** |
| **E.4** | `main.dart` **L2485-2486** | 2 signalements usagers fabriqués, `time: 'Il y a 3 min'` / `'Il y a 6 min'` **figés** | aucune donnée de signalement n'existe | Chaînes littérales jamais recalculées ; aucun backend ; `A.yY.prototype.ab()` retourne une liste constante | §9 : donnée inventée. §18 : faux temps réel. §20 : alertes en minutes | 🔴 **HAUTE** *(mais production-fidèle)* |
| **E.5** | `main.dart` **L2578** | `'Signalements en temps réel par les usagistes à Dakar.'` | `usagers` | Le binaire de production contient `'Signalements en temps réel par les usagers à Dakar.'` — `usagistes` : 0 occurrence | Faute de français introduite par le source + affirmation « temps réel » | 🟡 **BASSE** |
| **E.6** | `main.dart` **L2862** | `'🚨 Alertes en temps réel : consulte l'onglet "Alertes"…'` | aucune alerte n'est en temps réel | Les 3 cartes sont statiques, `severity: 'success'` fixe, aucun flux | §18 : faux temps réel | 🟠 **MOYENNE** |
| **E.7** | `main.dart` **L2864** | `'🚍 Les réseaux TER, BRT, DDD, TATA, AFTU fonctionnent normalement.'` | aucune donnée d'exploitation | Aucune source d'état de service dans le JSON ni ailleurs | Affirmation d'exploitation non démontrable → **UNKNOWN** | 🟠 **MOYENNE** |
| **E.8** | `main.dart` **L788** | point de démo `'Terminus Petersen (AFTU L25)'` | `aftu_25` = Dalal Jamm ↔ Obélisque | JSON : `aftu_25.long_name = "Hôpital Dalal Jamm ↔ Place de l'Obélisque (AFTU Ligne 25)"`, arrêts = `[Hôpital Dalal Jamm - BRT, Yoff Pêcheurs - Tata, Place de l'Obélisque - BRT]` → terminus = **Obélisque**, pas Petersen | Le nom d'un point Explorer affirme un terminus faux | 🟠 **MOYENNE** |
| **E.9** | `main.dart` **L786-787** | `'Parcelles Assainies (L1 à L10)'`, `'Grand Yoff (L11 à L25)'` | AFTU numéroté **1 à 72** | JSON : 72 lignes `AFTU n`, aucun trou. Les plages citées s'arrêtent à 25 | Libellés obsolètes : décrivent un réseau de 25 lignes alors qu'il en compte 72 | 🟠 **MOYENNE** |
| **E.10** | `main.dart` **L1194-1202** | `getCrowdLevel(Stop stop)` → `'🔴 Bondé (Heure de pointe)'` / `'🟠 Dense'` / `'🟢 Fluide'` | aucune donnée de fréquentation | Le paramètre `stop` **n'est jamais lu** ; la sortie ne dépend que de `DateTime.now().hour`. Affiché dans `StopCard` (L2122) à côté du badge officiel | §9 : affirmation de fréquentation sans aucune donnée. Trompeur car présenté comme une mesure | 🟠 **MOYENNE** *(production-fidèle)* |
| **E.11** | `main.dart` **L1134-1141** | `_findNearestStop` : recherche par **sous-chaîne de nom**, repli sur `allStops.firstWhere(…'dakar'…, orElse: allStops.first)` | — | Le nom annonce une proximité ; aucune distance n'est calculée. En cas d'échec, retourne **silencieusement** `allStops.first` = `'Gare TER Dakar'` | Une requête inconnue produit un itinéraire **depuis Dakar** sans avertir → résolution fabriquée | 🟠 **MOYENNE** |
| **E.12** | `main.dart` L677-679 · L1103 · L2078 · L1105 | Fenêtres de service divergentes | une seule règle | Flux continu : **06:00-22:00** (`_isServiceOpen`) · `RoutePlanner` : **05:00-22:30** · `StopCard` : **05:00-22:30** · message affiché : « Service de 5h00 à 22h30 » | Un trajet AFTU peut être refusé par `Stop` mais accepté par `RoutePlanner` entre 5h et 6h | 🟡 **BASSE** |
| **E.13** | `test/dakar_bounds_test.dart` **L115-122** | `group('Stop isContinuousFlow logic') { test('placeholder - verified via modeLabel', …) }` | un test réel | Le corps n'asserte **que** `expect(DistanceHelper.format(100), '100 m')` — déjà couvert par le groupe `DistanceHelper` (L70). Aucun appel à `isContinuousFlow` | Le groupe annonce vérifier le flux continu et ne vérifie **rien**. Le `return 5` codé en dur n'est protégé par **aucun** test réel. Gonfle le compte de 219 de 1 test vide | 🟠 **MOYENNE** |
| **E.14** | `main.dart` **L2405** | badge `'Réseau actif'` sur l'alerte DDD | aucune donnée d'état | Littéral statique, `severity: 'success'` | Assertion sans source → **UNKNOWN** | 🟡 **BASSE** |
| **E.15** | `main.dart` **L2840** | `'…avec un départ toutes les 10 à 20 min.'` | grille synthétique 10 min / 20 min le dimanche | Cohérent avec `_generateSchedule(step: _isSunday() ? 20 : 10)`, **mais** la grille elle-même est inventée (C.2) | La formulation présente une grille synthétique comme une fréquence officielle | 🟠 **MOYENNE** |
| **E.16** | `main.dart` **L2843** | BRT assistant : `'Guédiawaye → Petersen via Dalal Jamm, Parcelles Assainies, Obélisque'` | — | **Tous confirmés** : #1, #23, #5, #8, #21 | ✅ Aucune incohérence — cité ici pour montrer que l'assistant BRT est **exact**, contrairement à l'alerte BRT (E.2) | — |
| **E.17** | `main.dart` L422/458/468/842 | `reverse: true` implémenté **et** testé (8 occurrences en `test/`) | aucun appelant dans `lib/` | `grep -rn "reverse: true" lib/` → **0 résultat**. La production, elle, expose « sens retour » : `Dites « je veux aller à X » pour un itinéraire, ou « sens retour » pour l'arr…` | Régression fonctionnelle du source par rapport à la production. **L'exposer modifierait un écran → interdit** | 🟠 **MOYENNE** (documentation seule) |
| **E.18** | JSON · `aftu_25` | arrêts `[Hôpital Dalal Jamm - BRT, Yoff Pêcheurs - Tata, Place de l'Obélisque - BRT]` pour `long_name` « Dalal Jamm ↔ Obélisque » | — | `Yoff Pêcheurs` est à ~10 km au nord-ouest des deux autres arrêts, qui sont tous deux centraux. Géométrie en baïonnette | **SUSPECT, non démontrable** : aucune source ne permet de trancher. → **UNKNOWN**, à ne pas corriger sans preuve | 🟡 **BASSE / UNKNOWN** |
| **E.19** | `main.dart` L2354-2412 | `AlertsPage.officialAlerts` = **3 cartes** (TER, BRT, DDD) | la production en a **2**, de forme différente | Binaire : `new A.jE("Global","Service du matin en cours","CSE / CETUD",…, s.rH(-36e7))` et `new A.jE("TER","Intervalles conformes","TER Sénégal","TER Dakar ↔ Diamniadio : rotations régulières, 13 gares desservies.",…, s.rH(-84e7))`. Classe `A.jE(type,title,source,message,severity,timestamp)` — **6 champs dont un horodatage** | La page Alertes du source est une **réimplémentation**, pas celle de la production. Elle a perdu l'horodatage et gagné 3 littéraux | 🟠 **MOYENNE** |
| **E.20** | binaire de production | table `bS` codée en dur : **14 entrées TER**, **11 entrées BRT** | 13 / 23 | voir §J.4 | **Origine démontrée** des chiffres « 14 gares » et « 11 stations » | ℹ️ historique |
| **E.21** | binaire de production | `line_brt_b1` = **2 arrêts** seulement | 23 | `new A.fc("line_brt_b1","brt","BRT B1","Gare des Guéréos (Petersen) ⇄ Guédiawaye","BRT",B.cz,["stop_petersen","stop_guediawaye"])` | La production n'affichait **pas** 11 stations depuis ses données de ligne : les 11 venaient de la table `bS` hardcodée | ℹ️ historique |

---

## F. TER — 13 GARES ET DIRECTIONS

### F.1 Route normale `ter_dakar_diamniadio` (Dakar → Diamniadio)

`data_trust = OFFICIAL` · `type = TER` · `long_name = 'Dakar Gare ↔ Diamniadio (13 gares officielles SETER/CETUD)'`

| # | Nom (JSON) | Identifiant |
|---|---|---|
| 1 | Gare TER Dakar | `stop_dakar_ter` |
| 2 | Colobane - Marché & Gare TER | `stop_colobane` |
| 3 | Hann - Maristes / TER | `stop_hann` |
| 4 | Dalifort - Gare TER | `stop_dalifort_ter` |
| 5 | Baux Maraîchers - TER | `stop_baux_maraichers` |
| 6 | Pikine - Marché Zinc / TER | `stop_pikine` |
| 7 | Thiaroye - Gare TER | `stop_thiaroye` |
| 8 | Yeumbeul - Station TER | `stop_yeumbeul` |
| 9 | Keur Mbaye Fall - Correspondance TER | `stop_keur_mbaye_fall` |
| 10 | PNR - Station TER | `stop_pnr` |
| 11 | Rufisque - Gare TER | `stop_rufisque` |
| 12 | Bargny - TER | `stop_bargny` |
| 13 | Diamniadio - Gare TER Terminus | `stop_diamniadio` |

**Distance calculée** : 34,6 km (somme de cordes, R = 6 371 008,8).

### F.2 Route inverse (ordre auto-inversé, `reverse: true`)

13 → 1 : Diamniadio · Bargny · Rufisque · PNR · Keur Mbaye Fall · Yeumbeul ·
Thiaroye · Pikine · Baux Maraîchers · Dalifort · Hann · Colobane · Dakar.

✅ **Implémentée** (`officialRouteStops` L842-849, `DetailedRoute._build` L468-471)
et **testée** (`ter_brt_route_data_test.dart` L218/227, `detailed_route_test.dart` L179).
⚠️ **Non exposée dans l'UI** : aucun appelant `lib/` ne passe `reverse: true` (E.17).

### F.3 Keur Massar et Keur Mbaye Fall — confusion levée

| Question | Réponse démontrée |
|---|---|
| Keur Massar est-il une gare TER ? | **NON.** Desservi par 6 lignes (`ddd_23`, `aftu_5`, `aftu_38`, `aftu_46`, `aftu_53`, `tata_218`), **aucune TER** |
| `ter_8` existe-t-il dans le JSON ? | **NON** |
| Keur Mbaye Fall est-il une gare TER officielle ? | **OUI**, gare **n° 9** (`stop_keur_mbaye_fall`) |
| Les deux sont-ils proches ? | Oui, géographiquement → **source vraisemblable de la confusion historique** |
| Le point de démo « Gare TER Keur Mbaye Fall » est-il bien placé ? | **NON.** Coordonnées littérales `(14.7750, -17.3100)` ; la gare JSON est à `(14.74408, -17.31389)` → **écart 3,46 km**. Keur Massar JSON est à **2,32 km** de ce point. Le marqueur « vers Keur Massar » observé est donc **ce point mal positionné**, pas une gare TER supplémentaire |

### F.4 Les 8 points de démonstration TER (Explorer) — ≠ les 13 gares

| Point de démo (L751-758) | `direction` | Résolution vers le JSON (seuil 250 m) |
|---|---|---|
| Gare TER Dakar | `Terminus Dakar (Arrivée)` | ✅ nom exact, 0 m |
| Gare TER Dakar | `Dir. Diamniadio (Embarquement)` | ✅ nom exact, 0 m |
| Gare TER Colobane | `Dir. Diamniadio` | ❌ **0,78 km** → `null`, bouton désactivé |
| Gare TER Hann | `Dir. Diamniadio` | ❌ **1,43 km** → `null`, bouton désactivé |
| Gare TER Pikine | `Dir. Diamniadio` | ❌ **0,60 km** → `null`, bouton désactivé |
| Gare TER Keur Mbaye Fall | `Dir. Dakar / Diamniadio` | ❌ **3,46 km** → `null`, bouton désactivé |
| Gare TER Diamniadio | `Dir. Dakar (Embarquement)` | ✅ proximité, 17 m |
| Gare TER Diamniadio | `Terminus Diamniadio (Arrivée)` | ✅ proximité, 55 m |

> ✅ **Aucune correspondance approximative n'est forcée** : les 4 échecs renvoient
> `null` et désactivent le bouton. Conforme §3/§12.
> ⚠️ Les directions affichées (`Dir. Diamniadio`, `Dir. Dakar`) sont **synthétisées**
> et non issues du JSON (D.1).

---

## G. BRT — 23 STATIONS B1 ET DIRECTIONS

### G.1 `brt_b1_guediawaye_petersen` — 23 stations

`data_trust = OFFICIAL` · `type = BRT` · **distance calculée 17,5 km**

| # | Station | # | Station |
|---|---|---|---|
| 1 | Préfecture Guédiawaye - PEM BRT | 13 | Scat Urbam - BRT |
| 2 | Gadaye - Cambérène - BRT | 14 | Khar Yallah - BRT |
| 3 | Golf Nord - BRT | 15 | Liberté 6 - BRT Correspondance |
| 4 | Fith Mith - BRT | 16 | Liberté 5 - BRT |
| 5 | Hôpital Dalal Jamm - BRT | 17 | Sacré-Cœur - BRT |
| 6 | Golf Sud - BRT | 18 | Liberté 1 - BRT |
| 7 | Ndingala - Golf Sud - BRT | 19 | Grand Dakar - BRT |
| 8 | Parcelles Assainies - BRT | 20 | Dial Diop - BRT |
| 9 | Croisement 22 - BRT | 21 | Place de la Nation - Obélisque - BRT |
| 10 | Police des Parcelles - BRT | 22 | Grande Mosquée - BRT |
| 11 | Grand Médine - PEM BRT | 23 | Papa Gueye Fall - PEM Petersen BRT |
| 12 | Cardinal Hyacinthe Thiandoum - BRT | | |

**Sens inverse** : 23 → 1, ordre auto-inversé (mêmes 23 stations, **pas deux
copies**). Testé : `ter_brt_route_data_test.dart` L296/305.

### G.2 `brt_b2_express` — 7 stations

1 Préfecture Guédiawaye · 2 Hôpital Dalal Jamm · 3 Parcelles Assainies ·
4 Grand Médine · 5 Liberté 6 · 6 Place de la Nation - Obélisque ·
7 Papa Gueye Fall - PEM Petersen. **Distance calculée 16,0 km.**

> B2 est un **sous-ensemble express** de B1 (7 des 23 stations), pas une ligne
> distincte géographiquement.

### G.3 Absence de liste hardcodée de 11 stations — **VÉRIFIÉE**

```
grep -n "11 station" flutter-src/lib/main.dart   → 0 occurrence
grep -n "11 stations" lib/ test/                 → 0 occurrence dans lib/
```

✅ **Aucune liste de 11 stations ne subsiste dans le code fonctionnel actuel.**

Le test `ter_brt_route_data_test.dart` définit une constante `kLegacyBrt11`
**uniquement comme garde-fou** : son rôle est d'assertionner que le modèle à 11
stations **n'est pas** réintroduit. C'est un test de non-régression, pas une
donnée fonctionnelle.

**Où se trouvent réellement les 11 stations** : dans le **binaire déployé** sur
`gh-pages` (`94a84b6`), sous forme de table `bS` codée en dur. Voir §J.4.
Comme le déploiement est interdit (§29-30, §33), **le correctif BRT à 23 stations
est présent dans le source mais invisible en ligne**. C'est l'explication complète
de l'écart observé par l'utilisateur.

### G.4 Les 4 points de démonstration BRT (Explorer)

| Point de démo (L762-765) | `direction` | Résolution (seuil 250 m) |
|---|---|---|
| PEM Petersen | `Terminus sud BRT` | ❌ **0,42 km** → `null` |
| BRT Colobane | `Dir. Guediawaye` | ❌ **0,68 km** → `null` · **aucun homologue B1 n'existe** |
| BRT Grand Dakar | `Dir. Guediawaye` | ❌ **1,47 km** → `null` |
| PEM Guediawaye | `Terminus nord BRT` | ❌ **0,32 km** → `null` |

> ✅ Les 4 renvoient `null` : **aucune correspondance forcée**.
> ⚠️ `BRT Grand Dakar` : le JSON contient bien `stop_brt_05_grand_dakar`
> (« Grand Dakar - BRT », B1 n° 19) à `(14.7052, -17.4578)`, mais le point de démo
> est à `(14.7050, -17.4400)` → **1,93 km d'écart**, hors seuil. Homonyme
> `stop_grand_dakar` (« Grand Dakar - Biscuiterie ») à `(14.692, -17.455)`.
> ⚠️ `BRT Colobane` : **n'existe sur aucune ligne BRT**. Colobane est une gare TER
> (#2) et un arrêt bus, pas une station BRT.

---

## H. AFTU / TATA / DDD — ÉTAT RÉEL

### H.1 Lignes dans la source unique

| Opérateur | Lignes JSON | Numérotées | `NEW nn` |
|---|---|---|---|
| AFTU | **80** | 72 (`AFTU 1` … `AFTU 72`, aucun trou) | 8 (`NEW 03` … `NEW 10`) |
| DDD | **15** | 12 (1, 3, 7, 8, 9, 10, 11, 12, 14, 15, 20, 23) | 3 (`NEW 01`, `NEW 02`, `NEW 13`) |
| TATA | **7** | 5 (50, 64, 78, 218, 219) | 2 (`NEW 11`, `NEW 12`) |

### H.2 Points de démonstration (Explorer)

| Point | Ligne | Ligne JSON correspondante | Résolution ≤ 250 m |
|---|---|---|---|
| `DDD Ligne 1 (Colobane - Yoff)` | L769+ | ✅ `ddd_1` | ❌ 0,65 km |
| `DDD Ligne 3 (Sandaga - Ouakam)` | idem | ✅ `ddd_3` | ❌ 0,43 km |
| `DDD Ligne 10 (Liberté 6 - Patte d'Oie)` | idem | ✅ `ddd_10` | ❌ 0,46 km |
| `DDD Ligne 14 (Gare Maritime - UCAD)` | idem | ✅ `ddd_14` | ✅ 0 m → `UCAD` |
| `DDD Ligne 20 (Petersen - Rufisque)` | idem | ✅ `ddd_20` | ✅ 222 m → `PEM Petersen` |
| `TATA Ligne 50 (Guédiawaye - Sandaga)` | L778+ | ✅ `tata_50` | ❌ 0,49 km |
| `TATA Ligne 64 (Pikine - Liberté 6)` | idem | ✅ `tata_64` | ❌ 0,40 km |
| `TATA Ligne 78 (Yoff - Petersen)` | idem | ✅ `tata_78` | ❌ 0,48 km |
| `TATA Ligne 218 (Mermoz - Keur Massar)` | idem | ✅ `tata_218` | ✅ 0 m → `Mermoz - Sacré-Cœur` |
| `Parcelles Assainies (L1 à L10)` | L785+ | ⚠️ plage **obsolète** (E.9) | ❌ 1,32 km |
| `Grand Yoff (L11 à L25)` | idem | ⚠️ plage **obsolète** (E.9) | ✅ 0 m → `Grand Yoff - BRT & AFTU Hub` |
| `Terminus Petersen (AFTU L25)` | idem | ❌ **contradictoire** (E.8) | ❌ 0,29 km |

✅ **Les 9 lignes nommées par les points de démo DDD/TATA existent toutes dans le
JSON.** ❌ **Les 3 points AFTU portent des revendications de numérotation fausses
ou obsolètes.**

### H.3 Doublons et géométries

- **103 géométries distinctes pour 105 lignes.**
- **2 couloirs partagés légitimes** : `aftu_2`/`tata_50` et `aftu_38`/`tata_218`.
- ✅ **Aucun doublon d'identifiant** de ligne ni d'arrêt (couvert par
  `network_data_test.dart`, groupe « Intégrité du réseau actif »).
- ✅ **Aucun doublon de numéro** une fois les deux familles `AFTU n` / `NEW nn`
  distinguées (§B.3).
- **Polylignes au démarrage** : DDD 12 → 3 points ; Tata 219 → 2 points.
  Les autres tracés sont chargés paresseusement (`take(20)` via OSRM).
- ✅ **Suppression des doublons de tracé** (Groupe TER+BRT) : avant, `'B1' ≠ 'BRT B1'`,
  `'DDD' ≠ 'DDD 12'`, `'TATA' ≠ 'Tata 219'` → ces trois lignes étaient dessinées
  **deux fois** avec deux géométries divergentes superposées.

### H.4 Routes de démonstration

`demoRoutes` (L1095) est **vide** : `final List<TransitRoute> demoRoutes = <TransitRoute>[];`
→ **aucune route de démonstration ne subsiste**. Toutes les polylignes proviennent
du JSON via `_integrateNetworkData` (L886).

**Défaut historique documenté (L1062-1073)** : la déduplication comparait le `code`
de la démo au `short_name` du JSON. `'TER' == 'TER'` → la ligne officielle TER était
**court-circuitée et jamais ajoutée** ; la carte ne dessinait que **6 points sur 13
gares**. Corrigé à la racine.

### H.5 Horaires AFTU / TATA / DDD

`_integrateNetworkData` : `if (label == 'TER') … else if (label == 'BRT') … else schedule = []`.
→ **AFTU, TATA et DDD n'ont aucune grille horaire.** Ils relèvent du **flux
continu** : `isContinuousFlow == true` → `5` minutes fixes (C.3).

### H.6 Éléments suspects non démontrables → `UNKNOWN`

| Élément | Constat | Verdict |
|---|---|---|
| `aftu_25` (E.18) | arrêt intermédiaire `Yoff Pêcheurs - Tata` à ~10 km des deux terminus centraux | **UNKNOWN** — aucune source ne permet de trancher. **À ne pas corriger sans preuve** |
| `stop_brt_05_grand_dakar` vs `stop_grand_dakar` | homonymes à ~1,9 km | **CONFIRMÉ comme homonymes distincts** par les identifiants ; pas d'ambiguïté dans le JSON |
| Distances de la table `bS` de production | non monotones (0 ; 1,5 ; 5,9 ; 9,3 ; **4,6** ; 12,6 ; **8,1** ; 11,7 ; 14,4 ; 16,6 ; 18,3) | **FABRIQUÉES** — supprimées du source par Groupe 2 ✅ |
| Temps de la table `bS` au format `HH:00` | `27:00`, `45:00`, `43:00` → invalides dès l'indice > 23 | **FABRIQUÉS** — remplacés par `~N min` (L338-345) ✅ |

---

## I. EXPLORER — LES TROIS COUCHES DISTINGUÉES

L'audit établit **trois ensembles distincts** qui ne doivent jamais être confondus.

### COUCHE A — Points réseau affichables (`allStops`) = **141**

Composition : **24 points de démonstration** (L750-791) **+ 117 arrêts du JSON**,
dédupliqués par `(name, latitude, longitude)` et filtrés par `DakarBounds.isValid`.

| Filtre | Points | dont démo | dont JSON |
|---|---|---|---|
| **Tous** | **141** | 24 | 117 |
| TER | **21** | 8 | 13 |
| BRT | **27** | 4 | 23 |
| DDD | **37** | 5 | 32 |
| TATA | **12** | 4 | 8 |
| AFTU | **44** | 3 | 41 |

**Marqueurs réellement dessinés** : `_filteredStops` puis **`take(30)`**.
→ Sans GPS et filtre « Tous », **30 marqueurs sur 141** sont dessinés.
→ Avec le filtre TER (21 points) ou BRT (27 points), **tous** sont dessinés (< 30).

> ✅ **C'est cette couche A que comptent les chiffres « 21 » et « 27 »** observés
> dans Explorer. Ce sont des **points réseau**, **ni** des gares, **ni** des
> stations, **ni** des marqueurs effectifs.
> ⚠️ **Règle rappelée** : les ~21 points TER d'Explorer **ne sont pas 21 gares**.
> L'itinéraire officiel TER en compte **13**.

### COUCHE B — Arrêts réellement desservis par une ligne = **117**

Ensemble des identifiants référencés par au moins une `route.stops` :
**117 sur 117** → **aucun arrêt orphelin dans le JSON**.

> ℹ️ Conséquence : `stop_keur_massar` **est** desservi (6 lignes), mais **pas par
> le TER**. Être « desservi » ne signifie pas « desservi par le TER ».

### COUCHE C — Stations construisant une polyligne = **105 tracés**

| Tracé | Points | Chargement |
|---|---|---|
| `ter_dakar_diamniadio` | **13** | au démarrage (`isDedicated`) |
| `brt_b1_guediawaye_petersen` | **23** | au démarrage (`isDedicated`) |
| `brt_b2_express` | **7** | au démarrage (`isDedicated`) |
| 102 autres lignes | variables | **paresseux**, `take(20)` via OSRM |

### Synthèse des trois couches

| Question | Réponse |
|---|---|
| Les chiffres Explorer sont-ils des **points réseau** ? | ✅ **OUI** — couche A (141 ; 21 TER ; 27 BRT) |
| Sont-ils des **arrêts** ? | ⚠️ Partiellement : 117 des 141 le sont ; **24 ne sont que des points de démo** |
| Sont-ils des **stations d'itinéraire** ? | ❌ **NON** — couche C distincte (13 TER / 23 B1) |
| Sont-ils des **marqueurs** ? | ⚠️ Seulement **30 au maximum** à l'écran (`take(30)`) |
| Sont-ils des points géographiques d'une autre couche ? | ❌ Non — tous proviennent d'`allStops` |

### Résolvabilité des 24 points de démonstration

| Catégorie | Nombre |
|---|---|
| ✅ Résolubles (nom exact ou proximité ≤ 250 m) | **8 / 24** |
| ❌ Non résolubles (> 250 m) → `null`, **bouton désactivé** | **16 / 24** |

Les 8 résolubles : Gare TER Dakar ×2 (nom exact), Gare TER Diamniadio ×2 (17 m / 55 m),
DDD Ligne 14 (0 m), DDD Ligne 20 (222 m), TATA Ligne 218 (0 m), Grand Yoff (0 m).

Les 16 non résolubles, avec écart au plus proche :
Colobane 0,78 · Hann 1,43 · Pikine 0,60 · Keur Mbaye Fall 3,46 · PEM Petersen 0,42 ·
BRT Colobane 0,68 · BRT Grand Dakar 1,47 · PEM Guediawaye 0,32 · DDD 1 0,65 ·
DDD 3 0,43 · DDD 10 0,46 · TATA 50 0,49 · TATA 64 0,40 · TATA 78 0,48 ·
Parcelles Assainies 1,32 · Terminus Petersen 0,29 km.

> ✅ **Aucune correspondance approximative n'est forcée.** Conforme §3 / §12.
> **Ne pas modifier Explorer.**

---

## J. ALERTES — ÉTAT APRÈS GROUPE 5

### J.1 `AlertsPage` (L2349-2472) — 3 cartes littérales

**Carte 1 — TER** *(corrigée par Groupe 5, commit `87f54d6`)*

| Champ | Valeur actuelle | Statut |
|---|---|---|
| `type` | `'TER'` | — |
| `title` | `'Réseau CETUD & SETER (13 Gares)'` | ✅ **corrigé** (était `14 Gares`) |
| `source` | `'Source officielle : CETUD / SETER'` | ✅ |
| `message` | `'Le TER dessert officiellement 13 gares de Dakar à Diamniadio en passant par Colobane, Hann, Pikine, Keur Mbaye Fall et Rufisque.'` | ✅ **corrigé** (était `14 gares` + `Keur Massar`) |
| `severity` | `'success'` | ✅ inchangé |
| `badge` | `'13 Gares Officielles'` | ✅ **corrigé** |
| `icon` / `color` | `Icons.train_rounded` / `AppColors.ter` | ✅ inchangés |

**Vérification des 5 gares citées** — toutes officielles dans `ter_dakar_diamniadio` :

| Gare citée | Position dans les 13 | Identifiant |
|---|---|---|
| Colobane | **#2** | `stop_colobane` |
| Hann | **#3** | `stop_hann` |
| Pikine | **#6** | `stop_pikine` |
| Keur Mbaye Fall | **#9** | `stop_keur_mbaye_fall` |
| Rufisque | **#11** | `stop_rufisque` |

✅ **Le correctif 14 → 13 est valide et ne doit PAS être annulé.**
Un commentaire de traçabilité de 24 lignes (L2356-2379) documente la preuve.

**Carte 2 — BRT** *(non corrigée, hors autorisation Groupe 5)*

| Champ | Valeur | Statut |
|---|---|---|
| `title` | `'Corridor officiel SunuBRT'` | ✅ |
| `source` | `'Source officielle : Dakar Mobilité / CETUD'` | ✅ |
| `message` | `'Le corridor relie Guédiawaye à Petersen en passant par Dalal Jamm, Parcelles Assainies, Grand Yoff et la Place de l'Obélisque.'` | ❌ **Grand Yoff absent de B1** (E.2) |
| `badge` | `'En direct'` | ❌ **faux LIVE** (E.3) |

Vérification station par station : Guédiawaye ✅ #1 · Petersen ✅ #23 ·
Dalal Jamm ✅ #5 · Parcelles Assainies ✅ #8 · Obélisque ✅ #21 · **Grand Yoff ❌ absent des 23**.

**Carte 3 — DDD**

| Champ | Valeur | Statut |
|---|---|---|
| `message` | `'Les flottes DDD assurent les liaisons interurbaines et les lignes régulières 1, 3, 10, 14 et 20 aux horaires habituels.'` | ✅ lignes confirmées · ⚠️ « aux horaires habituels » **non vérifiable** (le JSON n'a aucun horaire) |
| `badge` | `'Réseau actif'` | ⚠️ assertion sans source → **UNKNOWN** (E.14) |

### J.2 `CommunityAlertsPage` (L2476-2622) — Direct rue

- **2 signalements littéraux fabriqués** (L2485-2486), horodatages **figés** (E.4)
- En-tête : `'Signalements en temps réel par les usagistes à Dakar.'` (L2578) — faute + faux temps réel (E.5)
- Un formulaire `_showAddReportModal` (L2489+) permet à l'utilisateur d'**ajouter** un
  signalement en session. ⚠️ **Aucune persistance** : les ajouts sont perdus, et
  les 2 signalements littéraux restent affichés.

### J.3 Alertes de l'assistant

L2862 : `'🚨 Alertes en temps réel : consulte l'onglet "Alertes" (CETUD/SETER) et
"Direct rue" (signalements usagers)…'` → ❌ faux temps réel (E.6).

### J.4 Origine démontrée des chiffres « 14 gares » et « 11 stations » (§10)

Le **binaire de production** contient une table codée en dur de classe
`bS(id, nom, position, distanceKm, tempsMin)` — **25 entrées** :

**TER — 14 entrées** (= les 13 gares officielles **+ Keur Massar**)

| id | nom | km | min | Ordre officiel |
|---|---|---|---|---|
| `ter_1` | Gare de Dakar | 0 | 00:00 | #1 ✅ |
| `ter_2` | Colobane | 1.2 | 03:00 | #2 ✅ |
| `ter_3` | Hann | 3.5 | 06:00 | #3 ✅ |
| `ter_13` | **Dalifort** | 6.7 | 08:00 | #4 ✅ *(ajouté hors séquence)* |
| `ter_4` | Baux Maraîchers | 5.5 | 09:00 | #5 ✅ |
| `ter_5` | Pikine | 7.2 | 12:00 | #6 ✅ |
| `ter_6` | Thiaroye | 9.0 | 15:00 | #7 ✅ |
| `ter_7` | Yeumbeul | 11.5 | 18:00 | #8 ✅ |
| `ter_8` | **Keur Massar** | 13.0 | 21:00 | ❌ **HORS ITINÉRAIRE TER** |
| `ter_9` | Keur Mbaye Fall | 17.0 | 24:00 | #9 ✅ |
| `ter_14` | **PNR** | 19.3 | 27:00 | #10 ✅ *(ajouté hors séquence)* |
| `ter_10` | Rufisque | 20.0 | 30:00 | #11 ✅ |
| `ter_11` | Bargny | 26.0 | 36:00 | #12 ✅ |
| `ter_12` | Diamniadio | 35.0 | 45:00 | #13 ✅ |

> 🔑 **DÉMONSTRATION DE L'ORIGINE DU « 14 »** : les identifiants `ter_13` (Dalifort)
> et `ter_14` (PNR) sont **numérotés après `ter_12`** mais **insérés au milieu de
> l'ordre kilométrique** — preuve qu'ils ont été **ajoutés tardivement** pour
> compléter les 13 gares officielles. Lors de cet ajout, **`ter_8` Keur Massar n'a
> pas été retiré**. Résultat : 13 gares officielles + 1 intrus = **14**.
> C'est ce comptage erroné que le source récupéré a figé en texte littéral.

**BRT — 11 entrées**

| id | nom | km | min | Sur le corridor B1 officiel ? |
|---|---|---|---|---|
| `brt_1` | Guédiawaye | 0 | 00:00 | ✅ #1 |
| `brt_2` | Hôpital Dalal Jamm | 1.5 | 04:00 | ✅ #5 |
| `brt_3` | **Cambérène** | 5.9 | 14:00 | ❌ **absent de B1** |
| `brt_4` | **Fadia** | 9.3 | 22:00 | ❌ **absent de B1** |
| `brt_5` | Parcelles Assainies | **4.6** | 11:00 | ✅ #8 — ⚠️ km **non monotone** |
| `brt_6` | Grand Médine | 12.6 | 29:00 | ✅ #11 |
| `brt_7` | **Grand Yoff** | **8.1** | 19:00 | ❌ **absent de B1** — ⚠️ km **non monotone** |
| `brt_8` | Liberté 6 | 11.7 | 27:00 | ✅ #15 |
| `brt_9` | Sacré-Cœur | 14.4 | 33:00 | ✅ #17 |
| `brt_10` | Place de l'Obélisque | 16.6 | 38:00 | ✅ #21 |
| `brt_11` | Gare de Petersen | 18.3 | 43:00 | ✅ #23 |

> 🔑 **3 des 11 noms ne sont sur AUCUNE ligne BRT** : Grand Yoff, Fadia, Cambérène
> (arrêts JSON desservis par DDD/AFTU uniquement).
> **3 homonymes hors corridor** expliquent le reste : `Sacré-Cœur`, `Liberté 6` et
> `Hôpital Dalal Jamm` existent en `stop_brt_NN_*` (officiel B1) **et** en `stop_*`
> homonymes à ~0,7-1,2 km. La liste à 11 s'appuyait sur les **homonymes**, pas sur
> le corridor.
> ⚠️ **Les distances ne sont pas monotones** (…9,3 puis 4,6 ; …12,6 puis 8,1) →
> valeurs **fabriquées à la main**, non calculées.
> ℹ️ `brt_11 = 18,3 km` est **l'origine exacte** du « 18.3 km » de la consigne §9 :
> c'est la dernière valeur de cette table, qui coïncide avec la longueur officielle
> CETUD du corridor. Le littéral « 14.0 km » affiché ailleurs par la production
> **contredisait sa propre table** (18,3 km).

**Autres faits de production établis**

- Production n'a **que 2 alertes**, de classe `A.jE(type, titre, source, message, sévérité, horodatage)` :
  `("Global","Service du matin en cours","CSE / CETUD","Réseau TER, BRT et bus urbains opérationnels sur Dakar et sa banlieue.", …, now−36e7)` et
  `("TER","Intervalles conformes","TER Sénégal","TER Dakar ↔ Diamniadio : rotations régulières, 13 gares desservies.", …, now−84e7)`.
  → **La production annonce bien « 13 gares desservies ».**
- Production possède un générateur d'alertes **capteur** (`A.aeV.$1`, seuil `k.IN() < 0.55`) et des enums `AlertSeverity` / `GpsState`.
- Production calcule les compteurs **dynamiquement** : `+" gares officielles"` précédé de `(n.length===0?1:B.b.gM(n).r.length)` ; `case "tata": return "🚐 Bus TATA ("+n.length+" lignes) : "`. **Le source a figé ces valeurs en littéraux** → régression (E.1, §K).
- Production cite **aussi** Keur Massar dans son texte assistant, et annonce « **12 stations** » pour le BRT B1 (`"Le corridor B1 relie PEM Guédiawaye ↔ PEM Petersen (12 stations : Dalal Jamm, Parcelles Assainies, Grand Yoff, Obélisque…). Fréquence 6 min."`) → **la production elle-même est incohérente** (11 dans la table `bS`, 12 dans l'assistant, 23 dans le JSON).

---

## K. ASSISTANT IA — INVENTAIRE HARDCODÉ **(AUCUNE MODIFICATION)**

> ⚠️ **`AIChatPage` n'a pas été modifié.** Cette section est un inventaire pur.
> Le « 14 gares officielles » **n'a pas été corrigé**, conformément à la consigne.

### K.1 Inventaire classé, affirmation par affirmation

| # | Ligne | Affirmation | Classification | Justification |
|---|---|---|---|---|
| K.1 | L2724 | « assistant IA expert des mobilités à Dakar » | **HARDCODÉ** | Production dit « assistant **vocal** » + « **Parlez-moi (micro)** » → le source a **perdu la voix** |
| K.2 | L2840 | « **14 gares officielles** » | **CONTRADICTOIRE** | JSON = **13** ; `long_name` dit « 13 gares officielles SETER/CETUD ». Production **calcule** ce nombre dynamiquement |
| K.3 | L2840 | « (Colobane, Pikine, Rufisque…) » | **CONFIRMÉ PAR LES DONNÉES** | #2, #6, #11 des 13 gares |
| K.4 | L2840 | « un départ toutes les 10 à 20 min » | **HARDCODÉ** + **NON CONFIRMÉ** | Reproduit le pas de `_generateSchedule` (10 min, 20 le dimanche), **mais cette grille est synthétique** ; le JSON n'a aucune fréquence |
| K.5 | L2840 | « relie Dakar à Diamniadio » | **CONFIRMÉ PAR LES DONNÉES** | `long_name` JSON |
| K.6 | L2843 | « relie le PEM Guédiawaye au PEM Petersen » | **CONFIRMÉ PAR LES DONNÉES** | stations #1 et #23 |
| K.7 | L2843 | « en passant par Dalal Jamm, Parcelles Assainies et l'Obélisque » | **CONFIRMÉ PAR LES DONNÉES** | #5, #8, #21 |
| K.8 | L2846 | « L1 Colobane-Yoff, L3 Sandaga-Ouakam » | **CONFIRMÉ PAR LES DONNÉES** | `ddd_1`, `ddd_3` (abrégé : `/ Ngor` omis) |
| K.9 | L2849 | « TATA desservent Guédiawaye, Pikine, Yoff, Mermoz, Keur Massar » | **CONFIRMÉ PAR LES DONNÉES** | 1+1+4+1+2 arrêts TATA correspondants |
| K.10 | L2852 | « **72 lignes AFTU** » | **CONFIRMÉ PAR LES DONNÉES** | 72 lignes `AFTU n`, numéros 1..72 sans trou. ⚠️ **INCOMPLET** : 8 lignes `NEW nn` rattachées à AFTU ne sont pas mentionnées (80 entrées au total). Production **calcule** ce nombre |
| K.11 | L2852 | « couvrent tout Dakar (Parcelles, Grand Yoff, Petersen…) » | **NON CONFIRMÉ** | « tout Dakar » est une généralisation sans donnée de couverture |
| K.12 | L2857 | « Tu es près de : … » (3 arrêts) | **CALCULÉ** | haversine depuis la position GPS réelle, tri, `take(3)` ✅ |
| K.13 | L2859 | « Active ton GPS… » | **CALCULÉ** | affiché uniquement si `userPosition == null` ✅ |
| K.14 | L2862 | « **Alertes en temps réel** » | **CONTRADICTOIRE** | `DataStatus.live` jamais assigné ; les 3 cartes sont statiques ; les 2 signalements sont figés |
| K.15 | L2864 | « Les réseaux TER, BRT, DDD, TATA, AFTU **fonctionnent normalement** » | **UNKNOWN** | Aucune donnée d'état d'exploitation dans la source unique ni ailleurs. **Indémontrable** |
| K.16 | L2864 | « Exemple testé : "Je suis à Dakar, je veux aller à Keur Mbaye Fall" → je te donne le trajet TER direct » | **NON CONFIRMÉ** | `RoutePlanner` résout « Dakar » par sous-chaîne et « Keur Mbaye Fall » par sous-chaîne ; le résultat dépend de l'ordre de `allStops`, pas d'une garantie TER. Non vérifié à l'exécution (pas de Flutter local) |
| K.17 | L2829 | exemples « Je suis à Petersen, je veux aller à Keur Mbaye Fall » / « De Colobane à Yoff » | **NON CONFIRMÉ** | mêmes réserves que K.16 |
| K.18 | L2836 | mémorisation du mode du 1ᵉʳ segment | **CALCULÉ** | `res.routes.first.segments.first.modeLabel` ✅ |
| K.19 | L2866 | « 💡 (Mémorisé : X) » | **HARDCODÉ** | Absent de la production |
| K.20 | L2814-2823 | si `from` manquant et GPS dispo → arrêt le plus proche | **CALCULÉ** | haversine sur `allStops` ✅ |
| K.21 | L2826 | si `from` toujours manquant → **`from = "Dakar"`** | **HARDCODÉ** | ⚠️ Substitution silencieuse d'un départ non connu par « Dakar ». Contredit l'esprit de §11 (jamais de position substituée), bien que ce ne soit pas une position GPS |
| K.22 | L2790 | « 📍 Position GPS prise en compte pour le tri des arrêts proches. » | **CALCULÉ** | affiché si `userPosition != null` ✅ |
| K.23 | L2785 | « 'Direct' : 'Rotation ~5 min' » pour tout mode non TER/BRT | **HARDCODÉ** | Reproduit le `return 5` du flux continu |
| K.24 | L2782 | « Durée totale : N min • M correspondance(s) » | **CALCULÉ** | `RoutePlanner`, mais sur vitesses codées en dur (35/20 km/h) |
| K.25 | L1105 | « 🌙 Les réseaux TER, BRT, DDD et TATA sont actuellement fermés (Service de 5h00 à 22h30) » | **HARDCODÉ** | ⚠️ **AFTU omis** de l'énumération ; et la fenêtre réelle du flux continu est 6h-22h (E.12) |
| K.26 | — | `reverse` / « sens retour » | **UNKNOWN** (non exposé) | Implémenté et testé, **aucun appelant UI**. La production l'expose : « ou « sens retour » pour l'arr… » |

### K.2 Récapitulatif par classification

| Classification | Nb | Éléments |
|---|---|---|
| **CONFIRMÉ PAR LES DONNÉES** | 7 | K.3, K.5, K.6, K.7, K.8, K.9, K.10 |
| **CALCULÉ** | 6 | K.12, K.13, K.18, K.20, K.22, K.24 |
| **HARDCODÉ** | 7 | K.1, K.4*, K.19, K.21, K.23, K.25, + plages de mots-clés |
| **NON CONFIRMÉ** | 3 | K.11, K.16, K.17 |
| **CONTRADICTOIRE** | 2 | **K.2 (14 gares)**, **K.14 (temps réel)** |
| **UNKNOWN** | 2 | K.15, K.26 |

\* K.4 est à la fois HARDCODÉ (reproduit la grille) et NON CONFIRMÉ (la grille est synthétique).

### K.3 Écarts structurels source ↔ production

| Aspect | Production (binaire déployé) | Source actuel |
|---|---|---|
| Nature | **déterministe, compteurs calculés** | déterministe, **compteurs littéraux** |
| Nb de gares TER | `n.length===0?1:B.b.gM(n).r.length` → **dynamique** | `'14'` → **figé et faux** |
| Nb de lignes TATA/AFTU | `n.length` → **dynamique** | `'72 lignes AFTU'` → **figé** (vrai aujourd'hui, fragile) |
| Stations B1 annoncées | `'12 stations'` | non chiffré dans l'assistant (mais `Grand Yoff` dans AlertsPage) |
| Fréquence BRT | `'Fréquence 6 min'` | non mentionnée |
| Modalité | **vocale** (« assistant vocal », « Parlez-moi (micro) ») | **texte seul** |
| « sens retour » | ✅ exposé | ❌ non exposé |
| `[Mémorisé : …]` | ❌ absent | ✅ présent |

> ⚠️ **Ces écarts sont documentés, pas corrigés.** Toute reprise de la voix ou du
> « sens retour » toucherait un écran existant → **interdit** par les règles en vigueur.

---

## L. HORAIRES — SCHEDULED / REAL_TIME / UNKNOWN

### L.1 Représentation dans le code

```dart
L719  enum DataStatus { scheduled, live, unknown }
```

| Valeur | Assignations dans `lib/` | Usage réel |
|---|---|---|
| `scheduled` | L647, L732, L738 (défauts) ; L1156, L1157, L1173 (`RoutePlanner`) | ✅ **seule valeur effectivement utilisée** |
| `live` | **AUCUNE** | ⚠️ **jamais assigné** — confirmé par le commentaire L1303 : « `DataStatus.live` n'est jamais assigné — 4A Carte 14 » |
| `unknown` | **AUCUNE** | ⚠️ **jamais assigné** — l'état inconnu est exprimé par `null`, pas par cet enum |

### L.2 Comment l'inconnu est réellement exprimé

Le code n'utilise **pas** `DataStatus.unknown` mais le **`null`**, ce qui est
fonctionnellement équivalent et honnête :

| Situation | Expression | Ligne |
|---|---|---|
| Service fermé | `nextDepartureMinutes() → null` | L685 |
| Aucun départ dans les 180 min | `→ null` | L690 |
| Libellé correspondant | `'Service fermé'` / `'Prochainement'` | L703-706 |
| Carte sans horaire (`remaining == null`) | `'Bientôt'` | L2084 |
| Ligne non dérivable du JSON | `DetailedRoute → null` (fiche **non** fabriquée) | L417-419 |
| Arrêt opposé non trouvé | `null` conservé, onglet « non identifié » | L3049-3061 |
| Point de démo non résolvable (≤250 m) | `null` → bouton désactivé | `_resolveStop` |
| AFTU / TATA / DDD | `schedule = []` → `'En rotation (~5 min)'` | L905+, L704 |

✅ **Conforme §18** : aucun `null` n'est remplacé par une valeur fabriquée.

### L.3 Vérification « aucune donnée statique présentée comme temps réel »

| Niveau | Verdict |
|---|---|
| **Modèle de données** | ✅ **CONFORME.** `DataStatus.live` jamais assigné ; tout est `scheduled` |
| **`RoutePlanner`** | ✅ **CONFORME.** L1156/1157/1173 : `status: DataStatus.scheduled` explicite |
| **`DetailedStop.estimatedTime`** | ✅ **CONFORME.** Préfixé `'~'` (L332-338) : « Le tilde marque explicitement l'approximation (§12 : aucune donnée présentée comme certaine) » |
| **Textes d'interface** | ❌ **NON CONFORME.** 4 occurrences affirment du temps réel sans donnée : `'En direct'` (L2394), `'Signalements en temps réel'` (L2578), `'Alertes en temps réel'` (L2862), `'Il y a 3/6 min'` figés (L2485-2486) |
| **Fréquentation** | ❌ **NON CONFORME.** `getCrowdLevel` affirme « Bondé / Dense / Fluide » sans aucune donnée (E.10) |

> 🔑 **DISTINCTION ESSENTIELLE** : la violation n'est **pas** dans le modèle ni dans
> les statuts — elle est **exclusivement dans des chaînes de caractères**
> (4 badges/titres + 1 fonction de libellé). **Aucune donnée n'est faussement
> typée `live`.** La correction relève donc du **texte**, pas de la logique, et
> **n'exige aucune transformation en `REAL_TIME`**.

### L.4 Provenance des horaires — tableau définitif

| Réseau | Horaires affichés | Provenance | Statut |
|---|---|---|---|
| TER | grille 05:30→22:00, pas 10 min (20 le dimanche), +2 min/arrêt | **`_generateSchedule` L260** | 🔴 **SYNTHÉTIQUE** — jamais dans le JSON |
| BRT | grille 06:00→21:00, pas 6 min, +2 min/arrêt | **`_generateSchedule` L261** | 🔴 **SYNTHÉTIQUE** |
| AFTU / TATA / DDD | `5` min fixes, « En rotation (~5 min) » | **`return 5` L685/696/713** | 🔴 **CODÉ EN DUR** |
| Toutes lignes | `~N min` (N = index × 3) | `kMinutesPerStop` L388 | 🟠 **ESTIMATION** affichée comme telle |
| Distances | 34,6 / 17,5 / 16,0 km | haversine depuis le JSON | 🟢 **CALCULÉ** |

> ✅ **Aucun horaire n'a été créé pendant cet audit.**
> ✅ **Rien n'a été transformé en `REAL_TIME`.**
> ✅ **`DataStatus.scheduled` est intact.**

---

## M. TESTS — RÉSULTAT EXACT CI

### M.1 Résultat CI (run `35661781590`, job `106538460935`, HEAD `87f54d6`)

```
tests +219/-0 | 8 fichiers | analyze 0 issue(s) | exit a=0 t=0 | Flutter 3.24.5 • channel stable

=== flutter analyze (intégral) ===
Analyzing flutter-src...
No issues found! (ran in 11.5s)
```

| Métrique | Valeur |
|---|---|
| Tests passés | **+219** |
| Tests échoués | **-0** |
| Fichiers de test | **8** |
| Issues `analyze` | **0** |
| Codes de sortie | `a=0` (analyze), `t=0` (test) |
| Flutter | 3.24.5, channel stable |
| Conclusion du run | `completed/success` |

### M.2 Répartition par fichier (vérifiée par décompte local)

| Fichier | Tests | Somme cumulée |
|---|---|---|
| `dakar_bounds_test.dart` | 17 | 17 |
| `data_service_test.dart` | 10 | 27 |
| `detailed_route_test.dart` | 37 | 64 |
| `gps_position_test.dart` | 40 | 104 |
| `network_data_test.dart` | 22 | 126 |
| `opposite_stop_test.dart` | 34 | 160 |
| `ter_brt_route_data_test.dart` | 57 | 217 |
| `widget_test.dart` | 2 | **219** ✅ |

> ✅ **Le décompte local (219) correspond exactement au résultat CI (+219).**

### M.3 Invariants protégés par les tests existants

| Groupe de tests | Fichier · ligne | Invariant verrouillé |
|---|---|---|
| **TER = 13 gares, ordre et sens inverse** | `ter_brt_route_data_test.dart` L206 | §6 — les 13 gares, leur ordre, `reverse: true` |
| **BRT B1 = 23 stations distinctes, ordre et sens inverse** | idem L283 | §7 — pas de modèle à 11, pas de deux copies |
| **Explorer ≠ itinéraire : les deux ensembles restent distincts** | idem L140 | §1/§6 — `kTerExplorerPoints=21`, `kBrtExplorerPoints=27` |
| **Aucune station inventée, aucune donnée fabriquée** | idem L421 | §9/§12 |
| **La polyligne reste cohérente avec les stations officielles** | idem L514 | §8 |
| **Structure : réseau, ligne, station, itinéraire** | idem L670 | §5 |
| **Arrêts dérivés de la source unique, aucune liste parallèle** | `detailed_route_test.dart` L148 | §8 |
| **Distance CALCULÉE par la formule prouvée, jamais codée en dur** | idem L281 | §9 |
| **Temps estimé marqué approximatif, inconnu honnête** | idem L391 | §12 |
| **Résolution de l'arrêt vers la source unique** | idem L454 | §3 |
| **Modèle `DetailedStop` aligné sur la production** | idem L533 | fidélité |
| **Position réelle ou erreur, jamais fabriquée** | `gps_position_test.dart` L160 | §11 |
| **Les 3 états d'erreur conservés + D4 distinguables** | idem L261 | D4 |
| **Interruption du flux continu (F4)** | idem L335 | F4 |
| **F2 rayon 4000 m** | idem L370 | §11 |
| **F3 plafond 30 résultats** | idem L447 | §11 |
| **F6 garde-fou REAL_TIME (Carte 14)** | idem L508 | §18 — `live` jamais assigné |
| **Invariants de périmètre (règles 4, 6, 8)** | idem L614 | JSON inchangé (md5) |
| **Passe 1 — inclusion de nom à 120 m ou moins** | `opposite_stop_test.dart` L130 | §10 |
| **Passe 2 — même mode, sens opposé, 500 m ou moins** | idem L341 | §10 |
| **Seuils — aucune augmentation, comparaison inclusive** | idem L460 | §10 |
| **Contrat — aucune correspondance forcée** | idem L524 | §12 |
| **Donnée ACTIVE — caractérisation (§10 appliqué aux données réelles)** | idem L578 | §10 |
| **TER — 13 gares (§6)** | `network_data_test.dart` L97 | §6 |
| **BRT — 23 stations (§7)** | idem L176 | §7 |
| **Intégrité du réseau actif** | idem L238 | identifiants uniques, références valides |
| **DakarBounds — données non modifiées par le Groupe 1** | `dakar_bounds_test.dart` L20 | périmètre |
| **DakarBounds — rectangle « océan » retiré** | idem L38 | Groupe 1 |
| **`DataTrust`** | `data_service_test.dart` L6 | confiance |
| **`TransportNetwork` JSON** | idem L20 | 117 arrêts, 105 lignes |
| **`DataService`** | idem L52 | `loadNetworkData` sur la DONNÉE ACTIVE |

### M.4 Tests couvrant les directions

- `officialRouteStops(kTerRouteId, reverse: true)` — L218, L227
- `officialRouteStops(kBrtB1Id, reverse: true)` — L296, L305
- `DetailedRoute.fromOperator('ter', reverse: true)` — L273 ; `detailed_route_test.dart` L179
- `DetailedRoute.fromOperator('brt', reverse: true)` — L411 ; `detailed_route_test.dart` L194

→ **8 assertions de sens inverse.** ✅ Les directions sont bien protégées, alors
même qu'elles ne sont **pas exposées dans l'UI** (E.17).

### M.5 Faiblesses de couverture détectées

| # | Faiblesse | Conséquence |
|---|---|---|
| M.5.1 | `dakar_bounds_test.dart` L115-122 : groupe `'Stop isContinuousFlow logic'` dont le test `'placeholder - verified via modeLabel'` n'asserte que `DistanceHelper.format(100)` (E.13) | Le `return 5` codé en dur du flux continu **n'est protégé par aucun test réel**. 1 des 219 tests est vide de sens pour son groupe |
| M.5.2 | **Aucun test n'assertionne le contenu textuel d'`AlertsPage`** | Le correctif Groupe 5 (14→13) **n'est pas verrouillé** par un test : une régression passerait inaperçue |
| M.5.3 | **Aucun test n'assertionne le contenu textuel d'`AIChatPage`** | Le « 14 gares officielles » (E.1) n'est détecté par aucun test |
| M.5.4 | **Aucun test sur `_communityReports`** | Les signalements figés (E.4) ne sont couverts |
| M.5.5 | **Aucun test sur `TimeHelper.getCrowdLevel`** | Le libellé de fréquentation (E.10) n'est couvert |
| M.5.6 | **Aucun test sur `RoutePlanner`** (vitesses 35/20, min 5, hub Colobane/Petersen, +5 min) | Le repli silencieux `_findNearestStop → allStops.first` (E.11) n'est couvert |
| M.5.7 | `widget_test.dart` ne contient que 2 tests | La couverture widget/UI est **quasi nulle** |

> ✅ **Aucun test n'a été supprimé, remplacé ou ajouté pendant cet audit.**

---

## N. FICHIERS POTENTIELLEMENT À MODIFIER (liste minimale)

Liste **indicative**, établie pour un Groupe 6 d'implémentation. **Aucun de ces
fichiers n'a été modifié.**

| Priorité | Fichier | Lignes | Objet | Nature |
|---|---|---|---|---|
| 🔴 1 | `flutter-src/lib/main.dart` | **L2840** | « 14 gares officielles » → 13 | texte seul *(interdit en Groupe 6, voir P)* |
| 🔴 2 | `flutter-src/lib/main.dart` | **L2392** | retirer « Grand Yoff » du corridor BRT | texte seul |
| 🟠 3 | `flutter-src/lib/main.dart` | **L2394** | badge `'En direct'` → libellé non temps réel | texte seul |
| 🟠 4 | `flutter-src/lib/main.dart` | **L2485-2486, L2578** | signalements figés + « temps réel » + « usagistes » | ⚠️ **production-fidèle** → décision requise |
| 🟠 5 | `flutter-src/lib/main.dart` | **L786-788** | libellés AFTU « L1 à L10 » / « L11 à L25 » / « Terminus Petersen (AFTU L25) » | ⚠️ **touche `allStops` → Explorer** → risque élevé |
| 🟠 6 | `flutter-src/lib/main.dart` | **L1194-1202** | `getCrowdLevel` | ⚠️ **production-fidèle** + affiché dans `StopCard` |
| 🟠 7 | `flutter-src/lib/main.dart` | **L2862, L2864** | « Alertes en temps réel », « fonctionnent normalement » | texte seul |
| 🟡 8 | `flutter-src/lib/main.dart` | **L1105** | fenêtre « 5h00 à 22h30 » + AFTU omis | ⚠️ modifie un comportement de refus |
| 🟡 9 | `flutter-src/lib/main.dart` | **L2405** | badge `'Réseau actif'` | texte seul |
| 🟡 10 | `flutter-src/test/dakar_bounds_test.dart` | **L115-122** | test placeholder | ⚠️ **interdit** de supprimer/remplacer un test existant |

**Total : 1 fichier de code (`main.dart`) + 1 fichier de test, éventuellement.**

---

## O. FICHIERS DEVANT RESTER INTACTS (liste explicite)

### O.1 Interdiction absolue — données et configuration

| Fichier | Raison |
|---|---|
| **`flutter-src/assets/data/dakar_network.json`** | **SOURCE UNIQUE.** md5 `81c778f4644dcf5e1cf4ae25879218f0`. TER 13, B1 23, B2 7, 105 lignes, 117 arrêts. **Aucune modification autorisée** |
| **`flutter-src/pubspec.yaml`** | `version: 9.3.2+12` (§28 — pas de v9.4). **Aucune nouvelle dépendance** |
| **`flutter-src/pubspec.lock`** | cohérence des versions |
| **`.github/workflows/*`** | CI verte stabilisée ; YAML validé par `node /tmp/yamlcheck/valide.js` |
| **`gh-pages` (branche)** | `94a84b6070569…` — **production. Aucun déploiement** (§29-30, §33) |
| **`main` (branche)** | `ce8c94f14f37…` — inchangé |

### O.2 Interdiction absolue — code fonctionnel verrouillé

| Fichier / zone | Raison |
|---|---|
| **`flutter-src/lib/main.dart` L2714-2932 — `AIChatPage`** | **CONSIGNE EXPLICITE : NE PAS MODIFIER.** Inventaire en §K uniquement |
| **`flutter-src/lib/main.dart` L1473-1760 — page Explorer / carte / `_distanceTo` / filtres** | **Ne pas modifier Explorer.** Constat F7 documenté, décision D6-i : inchangé |
| **`flutter-src/lib/main.dart` L750-791 — les 24 points de démonstration** | Alimentent `allStops` → **les compteurs Explorer 21/27 et les 30 marqueurs**. Toute modification **casserait `ter_brt_route_data_test.dart` L140** (`kTerExplorerPoints=21`, `kBrtExplorerPoints=27`) |
| **`flutter-src/lib/main.dart` L253-262 — `_generateSchedule`, `_shift`, `_terBase`, `_brtBase`** | **Production-fidèles** (binaire : `aIr(330,…,1320)`, `aIr(360,6,1260)`). §8 : **ne créer aucun horaire** |
| **`flutter-src/lib/main.dart` L672-716 — `isContinuousFlow`, `_isServiceOpen`, `nextDepartureMinutes`, `remainingMinutes`, `nextDepartureLabel`, `departureAfter`** | **Production-fidèles** (`gqy`, `xt`, `Xc`, `asb`, `IM`). Le `return 5` vient de la production |
| **`flutter-src/lib/main.dart` L719 — `enum DataStatus`** | §18 : **ne rien transformer en `REAL_TIME`**. Le garde-fou `gps_position_test.dart` L508 verrouille l'absence de `live` |
| **`flutter-src/lib/main.dart` L818-905 — `networkPoints`, `officialRouteStops`, `_integrateNetworkData`** | Couture JSON↔UI corrigée et testée (57 tests) |
| **`flutter-src/lib/main.dart` L1095 — `demoRoutes` (vide)** | §8 : polylignes dérivées du JSON. **Ne pas réintroduire de littéraux** |
| **`flutter-src/lib/main.dart` L322-520 — `DetailedStop`, `DetailedRoute`, `kMinutesPerStop`** | §9 formule prouvée, §12 `~` d'approximation. Groupe 2 validé |
| **`flutter-src/lib/main.dart` L2062-2150 — `StopCard`, `_buildStopTypeBadge`** | **Interface existante** : design, couleurs, badges |
| **`flutter-src/lib/main.dart` L2356-2384 — commentaire de traçabilité Groupe 5 + textes TER corrigés** | **Ne pas annuler le correctif 14→13** |
| **`flutter-src/lib/main.dart` L3035-3061 — onglet « Sens Retour », limite structurelle du sens** | D.1 : correction impossible sans inventer un sens |
| **`flutter-src/lib/models/transport_network.dart`** | Modèles `BusStop` / `TransportRoute` / `stopById` / `stopsForRoute` |
| **`flutter-src/lib/services/data_service.dart`** | Getters, `stopsForRoute`, `operatorForRoute`, fallback production |
| **`flutter-src/lib/services/opposite_stop_service.dart`** | §10 passes 120 m / 500 m, R=6371008.8 |
| **`flutter-src/lib/services/gps_resolver.dart`** (et GPS en général) | §11 : position réelle ou erreur, jamais fabriquée |
| **`flutter-src/lib/theme/*`, couleurs, icônes, navigation** | §21 : **aucune refonte UI** |
| **Les 8 fichiers de `flutter-src/test/`** | **Ne supprimer ni remplacer aucun test.** 219 tests verts |

### O.3 Interdictions transverses

- ❌ Aucun prix / tarif / coût / FCFA (§22)
- ❌ Aucune nouvelle dépendance
- ❌ Aucune donnée inventée, aucune coordonnée fabriquée, aucun arrêt artificiel
- ❌ Aucun faux `LIVE`, aucun faux GPS, aucun faux horaire
- ❌ Ne pas réintroduire : le modèle BRT à 11 stations, les plages DDD 1-23 / TATA 50-218 / AFTU 1-72 comme données codées en dur, la table `bS`, les distances littérales `35.0 / 14.0 / 3.5 km`, les pseudo-heures `i*4` / `i*6`
- ❌ Ne pas créer d'alertes 5 / 10 / 15 min (§20)
- ❌ Ne pas ajouter Keur Massar aux données TER (§6)
- ❌ Aucun déploiement, aucun push vers `main` ou `gh-pages`, aucune release
- ❌ Ne pas interpréter les ~21 points TER d'Explorer comme 21 gares
- ❌ Ne pas transformer une station en plusieurs, ni fusionner plusieurs stations sous un nom de quartier

---

## P. PROPOSITION DE PÉRIMÈTRE GROUPE 6

### P.1 Principe directeur

L'audit établit une distinction **décisive** pour le périmètre :

> **Les incohérences détectées se répartissent en deux classes disjointes.**
>
> **Classe I — INVENTIONS DU SOURCE** : textes et comportements **absents du
> binaire de production**. Les corriger **restaure** la fidélité à la production.
> → **Corrections légitimes.**
>
> **Classe II — COMPORTEMENTS FIDÈLES À LA PRODUCTION** : présents **à l'identique**
> dans le binaire déployé. Les « corriger » **améliorerait** l'application **au-delà**
> de la production, ce que la règle « ne rien réimplémenter de NON PROUVÉ » et la
> consigne « NE PAS MODIFIER L'INTERFACE EXISTANTE » interdisent.
> → **À documenter, pas à modifier.**

### P.2 À CORRIGER — Classe I (inventions du source)

| Ordre | Cible | Correction | Preuve | Risque | Tests nécessaires |
|---|---|---|---|---|---|
| **1** | `main.dart` **L2392** (alerte BRT) | Retirer **« Grand Yoff »** de l'énumération du corridor. Les 4 autres (Dalal Jamm, Parcelles Assainies, Obélisque + Guédiawaye/Petersen) sont confirmés | Les 23 stations B1 ne contiennent aucun Grand Yoff ; `stop_grand_yoff` est DDD/AFTU | 🟢 **nul** — texte seul, même structure de carte | 1 test : assertionner que le message de l'alerte BRT ne cite que des stations présentes dans `brt_b1_guediawaye_petersen` |
| **2** | `main.dart` **L2394** (badge BRT) | `'En direct'` → libellé factuel, ex. `'Corridor officiel'` | `DataStatus.live` jamais assigné ; aucune source de flux direct ; production n'a **pas** ce badge | 🟢 **nul** — texte seul | 1 test : aucune carte d'alerte ne porte un libellé de temps réel |
| **3** | `main.dart` **L2578** | `'usagistes'` → `'usagers'` | Production : `'Signalements en temps réel par les usagers à Dakar.'` | 🟢 **nul** | — (faute orthographique) |
| **4** | `main.dart` **L2862, L2864** (assistant) | ⚠️ **INTERDIT** — ces lignes sont dans `AIChatPage` | Consigne explicite « NE PAS MODIFIER AIChatPage » | — | **Aucun** — reporter |

> ℹ️ **Les 3 cartes `officialAlerts` sont elles-mêmes une réimplémentation** (E.19) :
> la production a 2 alertes de classe `A.jE` **avec horodatage**. Les reconstruire
> à l'identique toucherait la structure d'un écran → **hors périmètre**, à
> documenter seulement.

### P.3 À DOCUMENTER SANS MODIFIER — Classe II (fidèle à la production)

| Cible | Pourquoi ne pas modifier |
|---|---|
| **L2840 « 14 gares officielles »** | Dans **`AIChatPage`** → **interdiction explicite**. À reporter au Groupe 9. ⚠️ C'est l'incohérence la plus visible (E.1) : elle contredit la source unique **et** AlertsPage déjà corrigé |
| **L2485-2486 signalements figés** | **Présents à l'identique dans la production** (`A.yX.prototype.ab()`). Les retirer modifierait l'écran « Direct rue » |
| **L1194-1202 `getCrowdLevel`** | **Production identique** : `akL(a)` n'y lit pas non plus son paramètre. Le corriger changerait l'affichage de **chaque** `StopCard` |
| **L253-262 horaires synthétiques** | **Production identique** : `aIr(330, dimanche?20:10, 1320)` et `aIr(360,6,1260)`. §8 : **ne créer aucun horaire** |
| **Le `return 5` du flux continu** | **Production identique** : `if(this.gqy())return 5`. §20 : ne pas créer d'alertes 5/10/15 min |
| **L750-791 les 24 points de démo** | **Production identique** (`$.aCz()`). Toute modification **casse** `kTerExplorerPoints=21` / `kBrtExplorerPoints=27` et donc **Explorer**, explicitement à conserver |
| **L1759 repli `_distanceTo` (F7)** | Déjà documenté L1740-1757, décision **D6-i** du Groupe 4 : inchangé |
| **L1134-1141 `_findNearestStop`** | Modifier le repli changerait les réponses de l'assistant → touche `AIChatPage` indirectement |
| **E.17 `reverse` non exposé** | L'exposer **modifierait un écran** → interdit |
| **D.1 sens synthétisé** | Corriger exigerait d'**inventer** un sens absent de la source unique |
| **E.18 `aftu_25`** | **UNKNOWN** — non démontrable. Règle : ne rien corriger de suspect sans preuve |

### P.4 Périmètre recommandé

**Groupe 6 = 3 corrections de texte dans `AlertsPage` + `CommunityAlertsPage`,
hors `AIChatPage`, hors Explorer, hors horaires.**

| | |
|---|---|
| **Fichiers touchés** | `flutter-src/lib/main.dart` — **3 zones de texte** (L2392, L2394, L2578) |
| **Lignes de code modifiées** | **≈ 3** |
| **Fichiers de données** | **aucun** (JSON md5 inchangé) |
| **Dépendances** | **aucune** |
| **UI / design / couleurs / navigation** | **inchangés** — aucun widget, badge structurel, icône, sévérité ni layout modifié |
| **Explorer / carte / polylignes / filtres** | **inchangés** |
| **Horaires / `DataStatus`** | **inchangés** — rien transformé en `REAL_TIME`, aucun horaire créé |
| **`AIChatPage`** | **inchangé** |
| **Tests existants** | **219 conservés**, aucun supprimé ni remplacé |
| **Tests ajoutés** | **2** (garde-fous de non-régression sur les textes d'alerte) |
| **Cible CI** | `+221/-0`, `analyze 0 issue(s)` |
| **Déploiement** | **AUCUN** |

### P.5 Ordre d'exécution proposé

1. **Vérifier les préconditions** : HEAD, branche, arbre propre, md5 JSON/pubspec,
   `gh-pages` et `main` distants (comme en §A).
2. **Correction 1** — L2392 : retirer « Grand Yoff » du message de l'alerte BRT.
3. **Correction 2** — L2394 : remplacer le badge `'En direct'`.
4. **Correction 3** — L2578 : `'usagistes'` → `'usagers'`.
5. **Ajouter 2 tests garde-fous** dans un **nouveau** fichier
   (`test/alerts_text_test.dart`) — sans toucher aux 8 fichiers existants :
   - toute station citée par l'alerte BRT appartient aux 23 de `brt_b1_guediawaye_petersen` ;
   - aucune carte d'alerte ne porte de libellé affirmant du temps réel (`'En direct'`, `'temps réel'`).
6. **`flutter analyze` + `flutter test` via CI** (pas de Flutter local possible).
7. **Vérifier les invariants finaux** : md5 JSON/pubspec, `gh-pages`, `main`,
   aucun build Pages déclenché.
8. **Pousser uniquement sur `arena/01a0c385-dakar-bus`.**
9. **Rapporter** ; **s'arrêter**. Aucune implémentation supplémentaire sans
   validation séparée.

### P.6 Conditions d'arrêt

**STOP immédiat et rapport** si :
- la CI échoue (`analyze` ≠ 0 issue ou tests ≠ 0 échec) ;
- un md5 de `dakar_network.json` ou `pubspec.yaml` change ;
- `gh-pages` ou `main` bouge ;
- un build Pages est déclenché ;
- un test existant doit être modifié pour passer ;
- une correction s'avère toucher un widget, un layout, une couleur, Explorer,
  `AIChatPage` ou les horaires.

### P.7 Reste à traiter dans un groupe ultérieur (hors Groupe 6)

| # | Élément | Groupe suggéré |
|---|---|---|
| 1 | **L2840 « 14 gares officielles »** (E.1) — 🔴 la plus visible | **Groupe 9** (`AIChatPage`) |
| 2 | L2862 / L2864 : « Alertes en temps réel », « fonctionnent normalement » | Groupe 9 |
| 3 | L786-788 : libellés AFTU obsolètes et contradictoires (E.8, E.9) | Groupe dédié — ⚠️ touche `allStops` donc **Explorer** : exige de revoir `kTerExplorerPoints` / `kBrtExplorerPoints` |
| 4 | `_communityReports` figés (E.4) | Groupe dédié — ⚠️ production-fidèle |
| 5 | `getCrowdLevel` (E.10) | Groupe dédié — ⚠️ production-fidèle, affiché partout |
| 6 | Fenêtres de service divergentes (E.12) | Groupe dédié — ⚠️ change un comportement |
| 7 | `_findNearestStop` : nom trompeur + repli silencieux (E.11) | Groupe dédié |
| 8 | Test placeholder (E.13) | ⚠️ nécessite l'autorisation de **remplacer** un test existant |
| 9 | Reconstruction d'`AlertsPage` à l'identique de la production (2 alertes `A.jE` horodatées) (E.19) | ⚠️ refonte d'écran — hors règles actuelles |
| 10 | Exposer « sens retour » dans l'UI (E.17) | ⚠️ modification d'écran — hors règles actuelles |
| 11 | `aftu_25` : géométrie en baïonnette (E.18) | **UNKNOWN** — aucune action sans preuve nouvelle |

---

## SYNTHÈSE

| Question de l'audit | Réponse |
|---|---|
| Quelle est la source de vérité ? | `assets/data/dakar_network.json`, chargée au démarrage par `main()` L31-32, md5 `81c778f4…` |
| Le JSON contient-il des horaires ? | **NON** — aucun champ horaire, fréquence, départ, headway ni sens |
| TER = ? | **13 gares**, `OFFICIAL`, ordre vérifié, sens inverse implémenté + testé mais non exposé |
| BRT B1 = ? | **23 stations**, `OFFICIAL`, ordre vérifié, sens inverse idem. B2 Express = 7 |
| Une liste de 11 stations subsiste-t-elle dans le code ? | **NON** — 0 occurrence dans `lib/`. Elle n'existe que dans le **binaire déployé** (`gh-pages`) |
| D'où viennent « 14 gares » et « 11 stations » ? | De la table `bS` codée en dur de la production : **14 entrées TER** (13 officielles + `ter_8` Keur Massar jamais retiré après l'ajout tardif de `ter_13` Dalifort et `ter_14` PNR) et **11 entrées BRT** (dont 3 hors corridor : Cambérène, Fadia, Grand Yoff) |
| Explorer affiche-t-il des gares ? | **NON** — des **points réseau** : 141 au total, 21 TER, 27 BRT, 30 marqueurs maximum à l'écran |
| Les 24 points de démo sont-ils résolubles ? | **8 sur 24** ; les 16 autres renvoient `null` et désactivent le bouton, **sans correspondance forcée** |
| Keur Massar est-il une gare TER ? | **NON** — 6 lignes (DDD/AFTU/Tata), aucune TER. Le marqueur « vers Keur Massar » est le point de démo « Gare TER Keur Mbaye Fall » **mal positionné de 3,46 km** |
| Les horaires sont-ils présentés comme temps réel ? | **Le modèle : NON** (`live` jamais assigné, tout est `scheduled`). **Les textes : OUI** — 4 chaînes affirment du temps réel sans donnée |
| Des horaires ont-ils été créés ou passés en `REAL_TIME` ? | **NON** — aucun |
| Tests ? | **219 verts** (+219/-0, 8 fichiers), `analyze` **0 issue**, CI `success` |
| Modifications effectuées pendant l'audit ? | **AUCUNE** — arbre propre, 0 fichier modifié, 0 fichier non suivi, 0 commit, 0 push, 0 run CI déclenché, 0 déploiement |

---

**AUDIT TERMINÉ — AUCUNE MODIFICATION FONCTIONNELLE EFFECTUÉE**
