# GROUPE 6 — CORRECTIONS FACTUELLES MINIMALES

**Date** : 2026-09-22
**Branche** : `arena/01a0c385-dakar-bus`
**Commits** : `0e2a157` (corrections + tests) · `0d1696a` (fix finder de test)
**Audit préalable** : `docs/dakar-bus/groupe-6/RAPPORT_AUDIT.md` (commit `6270aa7`)
**HEAD fonctionnel avant Groupe 6** : `87f54d6`

**Résultat CI** (run `35668205582`, job `106558552722`) :

```
tests +231/-0 | 9 fichiers | analyze 0 issue(s) | exit a=0 t=0 | Flutter 3.24.5 • channel stable
flutter analyze : No issues found! (ran in 10.5s)
flutter test    : All tests passed!
```

---

## 1. Fichiers modifiés

| Fichier | Statut | Lignes |
|---|---|---|
| `flutter-src/lib/main.dart` | modifié | **+65 / −5** (5 lignes de code, 60 lignes de commentaires de traçabilité) |
| `flutter-src/test/groupe6_alertes_test.dart` | **ajouté** | 526 lignes, 12 tests |
| `docs/dakar-bus/groupe-6/RAPPORT_AUDIT.md` | ajouté (`6270aa7`) | 1 209 lignes — audit |
| `docs/dakar-bus/groupe-6/CORRECTIONS.md` | ajouté (ce fichier) | compte-rendu |

**Aucun autre fichier touché.** En particulier : `dakar_network.json`, `pubspec.yaml`,
`pubspec.lock`, les workflows CI et les 8 fichiers de test existants sont **inchangés**.

---

## 2. Lignes modifiées

**Preuve de minimalité** : en retirant toutes les chaînes littérales des 5 lignes
modifiées, le squelette de code obtenu est **strictement identique** avant/après.
Aucun widget, aucun style, aucune couleur, aucune navigation, aucune structure
n'a changé — **seules 5 valeurs de chaîne diffèrent**.

| # | Zone | Ligne avant | Ligne après |
|---|---|---|---|
| 1 | `AlertsPage` · carte BRT · `message` | 2392 | 2421 |
| 2 | `AlertsPage` · carte BRT · `badge` | 2394 | 2423 |
| 3 | `CommunityAlertsPageState` · `_communityReports[0].time` | 2485 | 2536 |
| 4 | `CommunityAlertsPageState` · `_communityReports[1].time` | 2486 | 2537 |
| 5 | `CommunityAlertsPage` · sous-titre d'en-tête | 2578 | 2638 |

---

## 3 & 4. Ancienne formulation → nouvelle formulation

### Correction 1 — Alerte BRT, message (incohérence E.2)

**AVANT**
> Le corridor relie Guédiawaye à Petersen en passant par Dalal Jamm, Parcelles Assainies, **Grand Yoff** et la Place de l'Obélisque.

**APRÈS**
> Le corridor relie Guédiawaye à Petersen en passant par Dalal Jamm, Parcelles Assainies et la Place de l'Obélisque.

### Correction 2 — Alerte BRT, badge (incohérence E.3)

**AVANT** : `En direct`
**APRÈS** : `Données officielles`

### Correction 3 — CommunityAlertsPage (incohérences E.4 et E.5)

**AVANT**
```dart
{'user': 'Mamadou S.',  …, 'time': 'Il y a 3 min', 'status': '🟢 Fluide'},
{'user': 'Aïssatou N.', …, 'time': 'Il y a 6 min', 'status': '🟢 Fluide'},
…
Text('Signalements en temps réel par les usagistes à Dakar.', …)
```

**APRÈS**
```dart
{'user': 'Mamadou S.',  …, 'time': 'Sans horodatage', 'status': '🟢 Fluide'},
{'user': 'Aïssatou N.', …, 'time': 'Sans horodatage', 'status': '🟢 Fluide'},
…
Text('Signalements publiés par les usagers à Dakar.', …)
```

---

## 5. Justification factuelle

### Correction 1 — « Grand Yoff » retiré du corridor BRT

| Fait | Preuve |
|---|---|
| Le corridor B1 compte **23 stations** | `routes[brt_b1_guediawaye_petersen].stops` = 23 identifiants, `data_trust = OFFICIAL` |
| **Aucune** des 23 ne porte le nom « Grand Yoff » | parcours des 23 noms : 0 correspondance |
| « Grand Yoff » existe pourtant dans le JSON | `stop_grand_yoff` = « Grand Yoff - BRT & AFTU Hub » |
| … mais n'est sur **aucune ligne BRT** | desservi par **20 lignes** : `ddd_1`, `ddd_7`, `ddd_8`, `ddd_10`, `aftu_1`, `aftu_6`, `aftu_7`, `aftu_8`, `aftu_10`, `aftu_11`, `aftu_19`, `aftu_24`, `aftu_27`, `aftu_33`, `aftu_38`, `aftu_40`, `aftu_49`, `aftu_50`, `aftu_65`, `tata_218` |
| Les 5 lieux conservés sont confirmés | Guédiawaye **#1**, Dalal Jamm **#5**, Parcelles Assainies **#8**, Obélisque **#21**, Petersen **#23** |

La formulation retenue est celle que l'audit a classée **« CONFIRMÉ PAR LES
DONNÉES »** (incohérence E.16) pour le descriptif BRT de l'assistant : les deux
textes décrivent désormais le même corridor, **sans qu'aucun des deux ait été
inventé**. Aucune station créée, la liste des 23 inchangée, carte et polylignes
intactes.

### Correction 2 — badge « En direct » → « Données officielles »

| Fait | Preuve |
|---|---|
| `DataStatus.live` n'est **jamais assigné** | `enum DataStatus { scheduled, live, unknown }` (L719) ; 0 assignation dans `lib/` ; garde-fou déjà posé par `gps_position_test.dart` (Carte 14) |
| Aucun flux temps réel n'existe | les 3 cartes d'alerte sont des littéraux statiques, `severity: 'success'` fixe |
| Le seul statut **réel** disponible pour cette ligne | `brt_b1_guediawaye_petersen.data_trust == 'OFFICIAL'` → `DataTrust.official` |

Le nouveau badge s'appuie donc sur un **attribut effectivement présent dans la
source unique**, vérifié par test. Aucun horodatage créé, aucun `REAL_TIME`
introduit, `DataStatus.scheduled` inchangé.

### Correction 3 — signalements non présentés comme live

| Fait | Preuve |
|---|---|
| `'Il y a 3 min'` / `'Il y a 6 min'` étaient des **chaînes figées** | rendues telles quelles par `Text(report['time']!)` ; jamais recalculées |
| Aucun horodatage n'existe | `dakar_network.json` ne contient aucune donnée de signalement ; ni backend ni persistance |
| L'en-tête affirmait un flux live inexistant | `'Signalements en temps réel…'` |
| `usagistes` est une coquille | le binaire de production contient exactement `'Signalements en temps réel par les usagers à Dakar.'` ; `usagistes` : **0 occurrence** |

`'Sans horodatage'` est la **formulation explicitement non temps réel** autorisée
par la consigne. Aucune date ni heure générée, aucun signalement créé ou supprimé.

**Fonctionnalité intégralement conservée** : mêmes clés, mêmes deux
signalements, même structure de carte, même widget de rendu, bouton
« Signaler » toujours actif (`onPressed != null`, asserté par test).

**Résidu volontairement non modifié** — `_showAddReportModal` insère un
signalement avec `'time': 'À l'instant'` (L2593). Contrairement aux deux chaînes
figées, celle-ci est produite par une action **réelle** de l'utilisateur au moment
où elle a lieu : à l'instant de l'insertion, elle est exacte. La rendre non
temporelle exigerait de générer un horodatage (`DateTime.now()`), ce que la
consigne interdit explicitement. **Documentée, pas corrigée.**

---

## 6. Tests ajoutés

`flutter-src/test/groupe6_alertes_test.dart` — **12 tests**, 3 groupes.
Suite : **219 → 231**. Aucun test existant supprimé, remplacé ni modifié
(`git diff --name-status` : `A` uniquement).

Trois niveaux de vérification, alignés sur le reste de la suite :

- **DONNÉE** — lue dans `dakar_network.json` via `appDataService`
- **RENDU** — pages montées avec `testWidgets`, texte **effectivement affiché** asserté
- **SOURCE** — garde-fou anti-régression sur les littéraux, selon le modèle
  « GARDE-FOU SOURCE » déjà employé par `gps_position_test.dart`

| Groupe | Test | Niveau |
|---|---|---|
| **Correction 1** | la source unique ne place aucune station « Grand Yoff » sur le B1 | DONNÉE |
| | « Grand Yoff » reste un arrêt réel du JSON, desservi hors BRT | DONNÉE |
| | l'alerte BRT affichée ne cite pas « Grand Yoff » | RENDU |
| | chaque lieu cité par l'alerte BRT est une station du corridor B1 | RENDU |
| | le littéral « Grand Yoff » a disparu de la page Alertes | SOURCE |
| **Correction 2** | aucune carte d'alerte n'affirme un direct ou un temps réel | RENDU |
| | le badge BRT s'appuie sur le `data_trust` réel de la ligne | RENDU + DONNÉE |
| | aucun des trois badges de la page Alertes ne revendique un direct | SOURCE |
| **Correction 3** | aucun signalement n'affiche une ancienneté figée | RENDU |
| | l'en-tête n'affirme plus de temps réel | RENDU |
| | la fonctionnalité est conservée, sans horodatage inventé | RENDU |
| | plus aucune ancienneté figée ni « usagistes » dans `main.dart` | SOURCE |

**Aucune valeur imposée de l'extérieur.** Le test central (« chaque lieu cité est
une station du B1 ») dérive son vocabulaire des **noms d'arrêt du JSON** : pour
chaque mot distinctif d'un arrêt du fichier apparaissant dans le message rendu,
il exige qu'une station du B1 porte ce même mot. Vérifié par simulation avant
poussée : il **passe** sur le nouveau message et **échoue** sur l'ancien (où il
détecte `yoff`, porté par 7 arrêts dont aucun n'est sur le B1). Le garde-fou est
donc réel et non vacuous.

Chaque groupe comporte un test « rien n'a été supprimé », pour qu'une correction
ne puisse pas passer en vidant la donnée.

### Incident de parcours (run `35667964660`, `+230/-1`)

Un seul test a échoué au premier run : `find.widgetWithText(ElevatedButton,
'Signaler')` ne trouvait aucun bouton.

**Cause** : `ElevatedButton.icon(…)` est une **fabrique** retournant
`_ElevatedButtonIcon`, une **sous-classe** d'`ElevatedButton`. Or
`find.widgetWithText` et `find.byType` comparent le `runtimeType` **exact**.
Le libellé, lui, était bien trouvé — le log CI l'atteste : *« Found 0 widgets
with type "ElevatedButton" that are ancestors of widgets with text "Signaler" »*.

**Correction** (`0d1696a`, fichier de test **seul**) : remontée depuis le libellé
avec `find.ancestor(of: find.text('Signaler'), matching:
find.byWidgetPredicate((w) => w is ElevatedButton))` — le prédicat `is`
reconnaît les sous-classes. L'assertion `onPressed != null` est conservée.

Les **230 autres tests passaient déjà**, dont les 11 autres du Groupe 6 :
l'échec portait sur le finder, pas sur les corrections.

---

## 7 & 8. Résultat CI et `flutter analyze`

| Métrique | Run `35667964660` (`0e2a157`) | Run **`35668205582`** (`0d1696a`) |
|---|---|---|
| Conclusion | `completed/failure` | **`completed/success`** |
| Tests | `+230/-1` | **`+231/-0`** |
| Fichiers de test | 9 | 9 |
| `flutter analyze` | **0 issue** | **0 issue** |
| Codes de sortie | `a=0 t=1` | **`a=0 t=0`** |
| Flutter | 3.24.5 stable | 3.24.5 stable |

```
=== flutter analyze (intégral) ===
Analyzing flutter-src...
No issues found! (ran in 10.5s)

=== flutter test (intégral) ===
00:04 +231: All tests passed!
```

**Aucun test existant cassé** : les 219 tests antérieurs passent tous.

---

## 9 à 13. Confirmations d'intégrité

| # | Exigence | Vérification | Statut |
|---|---|---|---|
| 9 | `dakar_network.json` inchangé | `git diff 87f54d6..HEAD` sur le fichier : **vide** ; md5 `81c778f4644dcf5e1cf4ae25879218f0` identique | ✅ |
| — | Aucune nouvelle dépendance | `pubspec.yaml` et `pubspec.lock` : diff **vide** ; `version: 9.3.2+12` | ✅ |
| — | Aucun changement UI hors textes/statuts | squelette de code (chaînes retirées) **identique** sur les 5 lignes | ✅ |
| — | Aucun changement de navigation | 0 ligne contenant `Navigator`, `onTap`, `onPressed`, `MaterialPageRoute`, `BottomNavigation`, `IndexedStack` | ✅ |
| 10 | **AIChatPage inchangée** | 0 ligne de code modifiée sur `aiReply`, `_extractTrip`, `_formatRouteResult`, `_sendMessage`, `Nanga def`. Le « 14 gares officielles » (L2840 avant Groupe 6, **L2900** après, du seul fait des commentaires de traçabilité ajoutés plus haut dans le fichier) est **toujours présent**, réservé au Groupe 9 | ✅ |
| 11 | **Horaires inchangés** | 0 ligne de code modifiée sur `_generateSchedule`, `_shift`, `_terBase`, `_brtBase`, `departureMinutesFromMidnight`, `isContinuousFlow`, `kMinutesPerStop`, `enum DataStatus`. Rien transformé en `REAL_TIME` ; aucun horaire créé | ✅ |
| 12 | **Explorer inchangé** | 0 ligne de code modifiée sur `terStations`, `brtStations`, `dddStations`, `tataStations`, `aftuAndBusStations`, `allStops`, `_distanceTo`, `networkPoints`, `demoRoutes`. Les 24 points de démonstration sont intacts ; les invariants **TER 21 points / BRT 27 points** sont toujours assertés par `ter_brt_route_data_test.dart` (inchangé) | ✅ |
| — | TER inchangé | 0 ligne sur `officialRouteStops`, `_integrateNetworkData`, `DetailedRoute`. 13 gares, ordre et sens inverse conservés | ✅ |
| — | Données BRT inchangées | 23 stations B1 et 7 stations B2 conservées ; seule une **chaîne d'alerte** a été corrigée | ✅ |
| — | Polylignes inchangées | `demoRoutes` toujours vide, alimentée depuis le JSON | ✅ |
| — | Tests existants | `git diff --name-status` sur `test/` : **`A`** uniquement, aucun `M` ni `D` | ✅ |
| 13 | **Aucun déploiement** | `gh-pages` = `94a84b6070569bed708b8e779b9e70b7c9dafa45` (inchangé) · `main` = `ce8c94f14f3712e77708f0e2a1de725c5f8c5779` (inchangé) · dernier build Pages `built 2026-09-19T12:14:29Z` (antérieur à tout ce travail) · **0 release** · **aucune PR créée** | ✅ |

Poussées effectuées **uniquement** vers `arena/01a0c385-dakar-bus`.

---

## Hors périmètre, documenté et non touché

Conformément à la consigne, les éléments suivants restent en l'état :

| Élément | Incohérence d'audit | Raison |
|---|---|---|
| `AIChatPage` « 14 gares officielles » (L2840 → L2900) | **E.1** 🔴 | Réservé au **Groupe 9 — Assistant IA** |
| `AIChatPage` « Alertes en temps réel » / « fonctionnent normalement » (L2862-L2864 → L2922-L2924) | E.6, E.7 | `AIChatPage` interdite |
| Libellés AFTU des points de démo (« L1 à L10 », « Terminus Petersen (AFTU L25) ») | E.8, E.9 | Toucherait `allStops` donc **Explorer** (invariants 21/27) |
| `_generateSchedule`, grilles synthétiques TER/BRT | §L | Chantier séparé ; **fidèle à la production** |
| `return 5` du flux continu, `getCrowdLevel` | E.10 | **Fidèles à la production** |
| Fenêtres de service divergentes (6h-22h vs 5h-22h30) | E.12 | Modifierait un comportement |
| `_findNearestStop` : nom trompeur, repli silencieux sur Dakar | E.11 | Modifierait les réponses de l'assistant |
| Test placeholder `isContinuousFlow` | E.13 | Interdit de supprimer/remplacer un test existant |
| `'À l'instant'` à l'insertion d'un signalement | résidu | Exigerait de générer un horodatage — interdit |
| `reverse` non exposé dans l'UI | E.17 | Exigerait de modifier un écran |
| Reconstruction d'`AlertsPage` à l'identique de la production (2 alertes horodatées) | E.19 | Refonte d'écran |
| `aftu_25` : géométrie en baïonnette | E.18 | **UNKNOWN** — non démontrable |

---

**GROUPE 6 — CORRECTIONS FACTUELLES TERMINÉES — AUCUN DÉPLOIEMENT**
