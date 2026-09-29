# Intégration opérationnelle des données GTFS PassBi — Lot 4.18

**Date :** 2026-09-27
**Branche :** `arena/01a0e370-dakar-bus`
**Périmètre :** rendre les 4 feeds GTFS PassBi (`data/transit/passbi/`) la base
opérationnelle courante de Dakar Bus, jusqu'à l'arrivée des données
d'étude/CETUD. Aucune nouvelle source externe, aucune demande, aucun contact.

---

## 1. Architecture utilisée

```
data/transit/passbi/*.zip  (Lot 4.17, empreintes sha256 inchangées)
        │
        ▼  scripts/build-passbi-processed.mjs  (générateur, un seul)
flutter-src/assets/data/passbi/{ter,brt,ddd,aftu,crosswalk}.json
        │
        ▼  PassBiSource.loadAll()  (lecture unique, réutilisable)
┌─────────────────────────────────────────────────────────────────────┐
│ Couche GTFS réutilisable : lib/services/gtfs/                       │
│   • gtfs_source.dart   : parseur générique (routes/stops/services/  │
│     exceptions/trips/stop_times + index), 1 lecteur pour 4 feeds    │
│   • passbi_source.dart : chargement assets + crosswalk PassBi↔dakar │
│   • routing_engine.dart: route → trip → service → stop →            │
│     stop_sequence → horaire → correspondance                       │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
DataService.departureFor (point d'entrée UI unique)
  → ScheduleProvider (PassBi SCHEDULED)     [chaîne imposée du lot]
  → EtaCalculator (hiérarchie REAL_TIME > SCHEDULED > ESTIMATED > UNKNOWN)
  → DataProvider fréquences (ESTIMATED legacy, si PassBi sans mappage)
        │
        ▼
Stop.departureInfoAt → StopCard / AssistantReplies / RoutePlanner (présentation)
RoutePlanner.plan → candidats PassBi (segments SCHEDULED horodatés) + legacy
```

**Décision produit appliquée :** statut **ACTIVE**, source **PassBi**,
`source_type = PUBLIC_GTFS` (nouvelle valeur `SourceType.publicGtfs`).
Les dates d'origine des feeds (`valid_from`/`valid_to`, `date_source`,
`date_verified`) sont **conservées telles quelles** (format GTFS
`YYYYMMDD`) — jamais falsifiées. Aucun statut « HISTORICAL » n'est appliqué.
Le calendrier fonctionne en mode **ROLLING** documenté : motif hebdomadaire
(+ exceptions datées) comme base courante, fenêtres d'origine non bloquantes.

**Décision d'identité DDD/AFTU (méthode) :** les identités dakar↔PassBi des
réseaux DDD/AFTU ne sont défendables que par concordance des **extrémités**
(`TERMINI_MATCH` ≥ 0,7) ; l'appariement par numéro de ligne a été prouvé
faux en amont (DDD_01 PassBi ≠ ddd_1 dakar). Les routes sans identité
confirmée restent `UNMAPPED` (`IDENTITE_NON_CONFIRMEE`) : aucune heure
n'est rattachée à ces lignes côté UI (comportement legacy conservé, zéro
régression, zéro invention). **Le moteur, lui, exploite les 4 réseaux
directement sous les identifiants PassBi** — aucune donnée n'est gaspillée.

**Interface de départ (depuis les arrêts dakar) :** le mappage
dakar→PassBi ne couvre que TER + BRT (`IDENTITY_OFFICIELLE` ou
`TERMINI_MATCH`), ce qui correspond à l'intégralité de la surface
« fréquence » legacy (ter / brt_b1 / brt_b2).

## 2. Fichiers modifiés / créés

| Fichier | État | Rôle |
|---|---|---|
| `scripts/build-passbi-processed.mjs` | créé | Générateur : ZIP → JSON indexés + crosswalk + manifeste sha256 |
| `flutter-src/lib/services/gtfs/gtfs_source.dart` | créé | Lecteur GTFS réutilisable (4 feeds, zéro duplication) |
| `flutter-src/lib/services/gtfs/passbi_source.dart` | créé | Source PassBi (assets + crosswalk + API moteur) |
| `flutter-src/lib/services/gtfs/routing_engine.dart` | créé | Moteur de routage sur stop_sequence + transferts documentés |
| `flutter-src/lib/services/schedule_provider.dart` | créé | Horaires PassBi → `DepartureInfo` SCHEDULED / UNKNOWN |
| `flutter-src/lib/services/eta_calculator.dart` | créé | Hiérarchie d'ETA (aucun chemin REAL_TIME) |
| `flutter-src/lib/services/data_service.dart` | modifié | `loadPassBiSchedules()`, `departureFor` → `EtaCalculator`, API planner |
| `flutter-src/lib/models/transport_network.dart` | modifié | `SourceType.publicGtfs` + `PUBLIC_GTFS` (label/fromString) |
| `flutter-src/lib/models/departure_info.dart` | modifié | Libellé scheduled : « Prochain départ dans X min » (« moins d'une minute » si 0) ; libellés UNKNOWN/ESTIMATED inchangés (assertés CI) |
| `flutter-src/lib/main.dart` | modifié | 1 appel de chargement dans `main()` (aucune donnée embarquée) + candidats itinéraire PassBi dans `RoutePlanner.plan` |
| `flutter-src/pubspec.yaml` | modifié | Asset `assets/data/passbi/` |
| `flutter-src/assets/data/passbi/*.json` | créé | ter.json 0,2 MiB · brt 1,5 · ddd 8,2 · aftu 17,6 · crosswalk 0,35 |
| `data/transit/passbi/processed_manifest.json` | créé | Manifeste opérationnel (entrées/sorties sha256) |
| `tests/passbi-gtfs.test.js` | créé | 21 tests niveau données (fixtures calculées sur les GTFS bruts) |
| `flutter-src/test/passbi_integration_test.dart` | créé | 20 groupes de tests d'intégration (CI Flutter) |
| `docs/INTEGRATION_PASSBI_4_18_2026-09-27.md` | créé | Ce rapport |

Non touchés (conformément au lot) : `data/gtfs/`, données transit validées,
GPS/PositionValidity/DakarBounds, cartographie, polylines, MarkerLayer,
`dakar_network.json`, UI/navigations hors libellé scheduled, `data_provider.dart`.

## 3. Réseaux activés (compteurs issus des feeds, non inventés)

| Réseau | Routes | Stops (utilisés) | Trips | Stop_times | Services | Exceptions |
|---|---|---|---|---|---|---|
| TER | 6 | 26 (13 gares) | 572 | 7 332 | 12 | 0 |
| BRT (B1+B2) | 2 | 79 (43) | 4 036 | 58 674 | 7 (dérivés) | 69 |
| DDD | 53 | 1 277 (1 186) | 9 529 | 314 029 | 4 | 40 |
| AFTU | 73 | 2 401 (2 237) | 11 077 | 677 918 | 4 | 40 |
| **Total** | **134** | — | **25 214** | **1 057 953** | — | 149 |

- **TER** : les 13 gares sont mappées (13/13), départs intermédiaires
  autorisés (aucune limitation aux terminus). Les 5 arrêts dakar TER
  supplémentaires non couverts par le feed restent sans mappage.
- **BRT** : B1 et B2 **séparés** (jamais fusionnés, aucune ligne B3 créée —
  absente du feed → reste SOURCE À OBTENIR). `direction_id` absent du feed
  → aucune direction n'est inventée (headsigns bruts affichés tels quels).
- **DDD / AFTU** : utilisés tels quels, aucune route écartée pour écart de
  comptes avec d'autres sources ; exploitées côté moteur sous leurs ids.
- **Crosswalk** : 5/105 routes mappées (TER 1 → 6 routes PassBi, B1, B2,
  aftu_8 → AFTU_3, aftu_11 → AFTU_3 en `TERMINI_MATCH` 0,92) ;
  82 `IDENTITE_NON_CONFIRMEE` ; 18 `RESEAU_ABSENT` (tata/new). Arrêts :
  44/51 mappés ; 7 non mappés dont Gadaye et Fith Mith (**réellement non
  appelés** dans le feed BRT — vérifié, aucune approximation par proximité).

## 4. Connexions moteur / ETA / routage / correspondances

- **Routage** (`routing_engine.dart`) : exploration temporelle bornée
  (horizon 6 h, ≤ 2 correspondances, budget d'explorations borné) qui
  n'emprunte que des `stop_sequence` présents dans les données.
  Trajets directs **et** correspondances ; arrêts intermédiaires desservis.
- **Correspondances** : uniquement (a) même arrêt physique, ou (b) lien
  documenté du crosswalk (nom identique ≤ 500 m, ou inclusion de nom
  inter-réseaux ≤ 250 m). **1 505 liens**, corridors vérifiés :
  TER↔DDD (3), TER↔AFTU (19), BRT↔DDD (30), BRT↔AFTU (22), DDD↔AFTU (769),
  + intraréseaux. Jamais de recréation des anciennes correspondances
  TER/bus aberrantes (règle d'origine conservée). Marche : 80 m/min,
  minimum 1 min.
- **ETA** : `ScheduleProvider` (PassBi SCHEDULED) → en l'absence de
  mappage, fréquences officielles (ESTIMATED) → sinon UNKNOWN. Prohibitions
  respectées : aucune fréquence présentée comme prochain passage, aucun
  « 0 min » temps réel, aucun « 0–20 min » sur un horaire PassBi, aucun
  « Passage non communiqué ». Route mappée sans départ → UNKNOWN portant la
  provenance PassBi (label « Horaire indisponible », statut honnête).
- **Affichage** : `DepartureInfo.label` scheduled → « Prochain départ dans
  X min » / « … moins d'une minute » ; statut `scheduled` (badge 🟢 UI),
  jamais `live`.
- **Itinéraires** : `RoutePlanner.plan` ajoute les trajets PassBi réels
  (segments `DataStatus.scheduled` avec heures de départ/arrivée) et garde
  les candidats legacy en secours ; `AssistantReplies.itinerary` affiche
  « Horaire programmé » quand les segments portent ces heures.

## 5. Tests

**Local — `npm test` : 45/45 verts** (24 antérieurs inchangés + 21 nouveaux
`tests/passbi-gtfs.test.js`) couvrant au niveau données : chargements
TER/BRT/DDD/AFTU, routes, stops, trips, stop_times, calendar, calendar_dates,
prochain départ (fixtures brutes : TER Colobane lundi 12:00 → 43885 s =
« 11 min » ; B1 Petersen → 50547 s = « 2 min »), calcul des minutes,
changement de date (lundi 43885 / dimanche 43671), services actifs,
correspondances (1 505, bornes et corridors), B1/B2 strictement séparés
(PGFB vs PGFA, départs 14:02:27 vs 14:05:30), provenance
(ACTIVE/PUBLIC_GTFS/dates d'origine), absence de données → null/UNKNOWN,
aucune structure temps réel, manifeste reproductible (sha256).

**CI Flutter — `flutter-src/test/passbi_integration_test.dart`** : les
20 exigences obligatoires en groupes (1–20) + chaîne `DataService`
complète, avec les mêmes fixtures. Le moteur a été validé par port
miroir déterministe (trajet TER Colobane→Diamniadio dep 43885 tc=0 ;
correspondance BRT(B1)→DDD tc=1 avec lien documenté).

**Validation exécutée (2026-09-27) :**
- `npm test` → **45 pass / 0 fail**
- `node scripts/check-arrets.js` → **EXIT=1, strictement identique à la
  baseline** (`/tmp/checkarrets_before.txt`) : aucune donnée transport
  modifiée, aucun « PASS » artificiel.
- `git diff --check` → 0 erreur
- `flutter analyze/test/build` → **indisponible localement** (aucun binaire
  `flutter`/`dart` dans l'environnement, egress SDK bloqué) ; laissé au
  workflow CI `.github/workflows/flutter-web-build.yml` à l'intégration.
  Aucune dépendance pub modifiée (`pubspec.lock` inchangé).

## 6. Limites techniques (constatées, non contournées)

1. **Identité DDD/AFTU non prouvée** : 82 lignes dakar sans correspondance
   d'extrémités → cartes UI en UNKNOWN (comportement antérieur conservé)
   alors que leurs horaires restent exploitables côté moteur (ids PassBi).
   Le remplacement par les données CETUD/étude passera par régénérer le
   crosswalk (point d'entrée unique), sans refonte moteur.
2. **Gadaye / Fith Mith** : arrêts BRT présents dans `stops.txt` mais non
   appelés par aucun trip → non mappés, aucun horaire (feed réel).
3. **BRT↔TER sans lien direct** : aucun couple d'arrêts nom-identique ≤ 500 m
   (gare ferroviaire « Dakar - Gare ferroviaire » vs « PETERSEN ») ;
   chaînage possible via DDD/AFTU. Aucun lien n'est fabriqué.
4. **Anomalie brute** : 1 `stop_times` TER sur 7 332 avec `arrival_time` >
   `departure_time` (feed d'origine) — documentée, non corrigée.
5. **`pickup/drop_off_type`** : tous égaux à `1` sur le TER (anomalie du
   feed) → le moteur n'en tient pas compte (non bloquant), à réévaluer si
   un futur feed est correct.
6. **B3** : absente du feed PassBi → reste SOURCE À OBTENIR (aucune ligne
   B3 déduite).
7. **Dates des feeds** : fenêtres GTFS 2022–2025 (captures publiques
   `passbi_core` du 2026-02-10). Statut produit ACTIVE par décision, dates
   d'origine affichées en provenance — aucune mise à jour de date.
8. **Flux temps réel** : aucun (API PassBi suspendue, aucun GTFS-RT) →
   `realTime` structurellement impossible ; un futur flux pourra compléter.

## 7. Remplacement futur (condition « nouvelles données »)

Le contrat d'architecture est : **les données remplacent PassBi, pas le
moteur**. Point d'entrée unique = `PassBiSource.loadAll()` + régénération
des assets par `scripts/build-passbi-processed.mjs` (manifeste sha256 des
4 entrées et 5 sorties : `data/transit/passbi/processed_manifest.json`).
Aucun autre fichier du moteur, de l'ETA ou de l'UI n'a besoin d'être
modifié pour substituer une source.
