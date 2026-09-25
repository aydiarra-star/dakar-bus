# Audit d'impact — Intégration du référentiel canonique AFTU / Tata / DDD

**Phase 4 — étape 1 : audit d'impact en LECTURE SEULE.**
Aucune ligne de code de production n'a été modifiée, aucun fichier de données, aucun test, aucun moteur.

| Élément | Valeur |
|---|---|
| HEAD de référence | `653b91631c74cc60da09cb3558c2c8fc9a0addf4` (poussé sur `origin/arena/01a0d6a5-dakar-bus`) |
| Entrée | `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` (127 entités, statuts canoniques) |
| Objet | Définir **quoi** modifier, **où**, **avec quels champs**, **quels tests**, **quels risques** — avant toute écriture |
| Statut | **Audit présenté — aucune modification de production engagée** |

---

## 0. Règle de conception retenue

> Le référentiel canonique est la **source de référence**. L'intégration doit **transporter son statut**, jamais le lisser.

Conséquence directe, vérifiée plus bas : **l'enrichissement documentaire peut être intégré sans toucher à l'UI ni au moteur** (Lot 1 + Lot 2). Tout ce qui touche l'affichage (arrêts, itinéraires, horaires) constitue un **changement de comportement** et exige une décision explicite.

---

## 1. Chaîne de consommation actuelle (analyse)

### 1.1 Flutter — chaîne principale

```
assets/data/dakar_network.json
   └─ DataService.loadNetworkData()            lib/services/data_service.dart l.24-38
      └─ TransportNetwork.fromJson()           lib/models/transport_network.dart l.429-441
         ├─ Operator        (id, name, color, official_line_count, source)
         ├─ BusStop         (id, name, lat/lng, data_trust, provenance, place_id, coordinates_status)
         └─ TransportRoute  (id, operator_id, short_name, long_name, type, data_trust,
                             provenance, schedule_status, counts_toward_official_total,
                             audit_flags, stops[])
            └─ _integrateNetworkData()         lib/main.dart l.1296-1440
               ├─ allStops   : 1 « Stop » par paire (route × arrêt), dédupliqué nom+lat+lng
               ├─ demoRoutes : 1 polyligne par route si ≥2 arrêts coordonnés
               └─ arrêts orphelins : ajoutés avec le libellé par défaut « AFTU »
                  └─ UI : liste, recherche, planificateur, carte, fiche détaillée, assistant
```

**Point d'entrée unique des horaires** (inchangé) :

```
UI (modeLabel, lineId, stopId, direction)
  └─ DepartureService.estimateForLine()        lib/services/departure_service.dart l.67-81
     └─ networkOfModeLabel()                   l.43-50   (« Tata » → 'TATA', sinon TER/BRT/DDD/AFTU)
        └─ estimateNextDeparture()             engine/departure-engine.js l.651
           └─ registre : departure-frequencies.json  (« AFTU/TATA/DDD » : 0 fréquence)
```

`defaultLineIdByNetwork` (l.54-58) ne contient **que** TER et BRT : AFTU, Tata et DDD ne peuvent recevoir **aucune** estimation par défaut. `hasDocumentedFrequency()` (l.86-90) renvoie `false` pour ces trois réseaux.

### 1.2 PWA (`index.html`) — chaîne **séparée**

| Fait vérifié | Emplacement |
|---|---|
| `ALL_ARRETS` = **42 arrêts codés en dur** (23 BRT + 13 TER + 6 BUS) | l.603 |
| **Ne charge JAMAIS** `dakar_network.json` (0 occurrence) | — |
| Seul chargement réseau : `data/transit/departure-frequencies.json` | l.670 |
| `LINES_TOTAL = 105` (constante) | l.863 |
| « 76 lignes » en dur (titre + bandeaux) | l.6, l.258, l.305, l.313 |
| « 42 arrêts » en dur | l.143, l.192, l.248, l.305 |

### 1.3 Serveur (`server/server.js`)

`/api/gtfs/static` (l.397), `/data/gtfs/:file` (l.441), catch-all → `index.html` (l.532).
`dakar_network.json` est un **asset Flutter** ; il n'est **pas** servi par le serveur.

---

## 2. Fichiers qui devront être modifiés

### Lot 1 — Référentiel enrichi (obligatoire, risque faible)

| Fichier | Nature de la modification | Risque |
|---|---|---|
| `flutter-src/assets/data/dakar_network.json` | **Ajout de champs** de provenance canonique (voir §3). **Aucune suppression, aucun renommage, aucune route ajoutée, aucun arrêt ajouté.** | Faible : `TransportRoute.fromJson` (l.382-393) ignore les clés inconnues → le modèle Dart continue de fonctionner sans modification |

Ce lot **ne change pas un pixel** de l'UI ni une ligne du moteur.

### Lot 2 — Verrous et tests de données (obligatoire)

| Fichier | Nature | Détail |
|---|---|---|
| `flutter-src/test/gps_position_test.dart` | À mettre à jour | verrou l.709-722 : `expect(bytes.length, 213248)` + sha256 `3c2574e3…` |
| `flutter-src/test/cartographic_render_test.dart` | À mettre à jour | verrou l.729-744 (mêmes valeurs) |
| `flutter-src/test/out_of_coverage_test.dart` | À mettre à jour | verrou l.565-578 (mêmes valeurs) |
| `flutter-src/test/data_provenance_test.dart` | À étendre | ajout d'assertions canoniques (§5.2) ; les assertions existantes (l.54-57, 209-212, 291, 370-371) **restent valides** si aucune route/arrêt n'est ajouté |
| `flutter-src/test/referentiel_canonique_test.dart` | **À créer** | nouveau verrou du référentiel canonique (§5.2) |

> **Le verrou d'octets est un point de rupture connu** : toute modification du JSON casse ces 3 tests par construction. Il doit être mis à jour **délibérément**, avec le bloc de justification daté déjà utilisé par le dépôt (« AUDIT DONNÉES 2026-09-24 — AVANT/APRÈS — RAISON »).

### Lot 3 — Modèle Dart (uniquement si l'UI doit lire les nouveaux champs)

| Fichier | Modification | Nécessaire ? |
|---|---|---|
| `flutter-src/lib/models/transport_network.dart` | `TransportRoute.fromJson` (l.382-393) : exposer `route_documentation`, `service_category`, `frequency_status`, `official_line_number`, `canonical_status` ; enum `ProvenanceStatus` (l.52-85) : ajouter `PARTIAL` | **Seulement** si l'on veut distinguer `PARTIAL` de `UNVERIFIED` dans l'UI |

**Comportement actuel à connaître** : `Provenance.fromJson` (l.196-218) applique un **fail-closed** — `CONFIRMED` sans `source` + `verified_at` devient `UNVERIFIED`. Une valeur `PARTIAL` envoyée aujourd'hui est lue `UNVERIFIED` (sûr, mais **perte d'information**).

### Lot 4 — UI (hors périmètre recommandé à ce stade)

| Fichier | Zone | Effet d'une modification |
|---|---|---|
| `flutter-src/lib/main.dart` | `_integrateNetworkData` l.1296-1440 | affichage d'arrêts/itinéraires supplémentaires |
| `flutter-src/lib/main.dart` | `AssistantReplies.modeInfo` l.3490-3510 | compteurs par réseau dans l'assistant |
| `flutter-src/lib/main.dart` | `DataSourceInfo` l.346-366 | libellés « (non vérifié) » / pastilles 🟡 |

### Fichiers qui ne doivent **PAS** bouger

`engine/departure-engine.js` · `engine/gtfs-rt-policy.js` · `data/transit/departure-frequencies.json` · `flutter-src/assets/data/departure-frequencies.json` · `flutter-src/lib/services/departure_service.dart` · `flutter-src/lib/models/departure_estimate.dart` · `data/gtfs/*` (dormant) · `server/server.js` · `scripts/check-arrets.js` · routes et arrêts TER/BRT du JSON · `index.html` (sauf décision explicite) · les 5 tests TER/BRT (`ter_brt_route_data_test`, `network_data_test`, `detailed_route_test`, `opposite_stop_test`, `dakar_bounds_test`).

---

## 3. Champs ajoutés / modifiés (schéma proposé)

Tous les champs sont **additifs** et portés **au niveau `routes[]`**. Aucun n'est inventé : chaque valeur provient du référentiel canonique.

| Champ | Portée | Valeurs | Exemple réel | Consommé par |
|---|---|---|---|---|
| `route_documentation` | toutes routes AFTU/DDD | `ROUTE_DOCUMENTED` \| `STOP_SEQUENCE_CONFIRMED` \| `ROUTE_NOT_FOUND` | AFTU 5 → `ROUTE_DOCUMENTED` ; DDD 1 → `STOP_SEQUENCE_CONFIRMED` ; AFTU 84 → `ROUTE_NOT_FOUND` | modèle Dart (Lot 3) |
| `canonical_status` | toutes routes | `CONFIRMED` \| `PARTIAL` \| `CONFLICTING` \| `UNVERIFIED` | DDD 4 → `CONFIRMED` ; DDD 6 → `CONFLICTING` | modèle Dart (Lot 3) |
| `service_category` | routes Tata + AFTU | `TATA` \| `null` | `tata_50` → `TATA` | déjà présent (Tata) |
| `frequency_status` | toutes routes AFTU/Tata/DDD | `UNKNOWN` (**valeur unique aujourd'hui**) | `AFTU 5` → `UNKNOWN` | aucun (documentaire) |
| `schedule_status` | toutes routes AFTU/Tata/DDD | `UNKNOWN` (**valeur unique aujourd'hui**) | `DDD 46` → `UNKNOWN` | déjà présent (l.387-388) |
| `first_departure` / `last_departure` + `schedule_source_url` | **DDD 1 uniquement** (ligne urbaine) | heures publiées | `05:30` / `20:30`, `06:30` / `21:00` | **aucun en Phase 4** : n'alimente pas le moteur |
| `conflict_reason` + `conflict_sources[]` | entités `CONFLICTING` | texte + 2 URL officielles | DDD 6, DDD 501, Tata 50/64/78 | modèle Dart (Lot 3) |
| `route_description_text` | 65 routes AFTU | texte de rues | « ROUTE DE L'EGLISE – ROUTE DES NIAYES – … » | **jamais** converti en `stops[]` |
| `official_line_number` / `nomenclature_status` | routes AFTU | déjà présents | `5`, `CONTRADICTED_BY_OPERATOR` | inchangé |

**Champs qui ne doivent pas être créés** : `stops[]` pour AFTU (aucun arrêt publié), `frequency_*` chiffré pour AFTU/Tata/DDD, `first_departure`/`last_departure` pour une autre ligne que DDD 1, tout champ `realtime_*`.

---

## 4. Données qui resteront UNKNOWN (interdiction d'intégration)

| Catégorie | Entités | Volume |
|---|---|---|
| Horaires et fréquences AFTU | lignes 1–5, 24–89, 91 | **72** |
| Horaires et fréquences Tata | 7 identités (catégorie AFTU) | **7** |
| Horaires et fréquences DDD | les 46 identifiants hors ligne 1 / TAF TAF | **46** |
| Arrêts AFTU | toutes les lignes | **0 arrêt disponible** |
| Itinéraires AFTU | 84, 85, 86, 87, 88, 89, 91 | **7** |
| Itinéraires DDD | 15A, 15B, 502A, 502B, 503A, 503B, 504A, 504B | **8** |
| Arrêts TAF TAF (variante Sphère Ministérielle) | 1 service | **—** |
| Temps réel (tous réseaux) | — | **aucune API publique** |
| Doublons non résolus | 15A/15B, 502A/502B, 503A/503B | **3 paires** |

Rappel : la FAQ AFTU (« tôt le matin … jusqu'à 21 H ») est une **généralité d'exploitation** — elle ne produit **aucune** valeur horaire par ligne et ne doit pas être transformée en `first_departure` / `last_departure`.

---

## 5. Tests nécessaires

### 5.1 Existants à mettre à jour (obligatoire, dans le même commit que le Lot 1)

| Test | Assertion concernée | Action |
|---|---|---|
| `gps_position_test.dart` l.709-722 | octets `213248` + sha256 | recalculer + bloc de justification daté |
| `cartographic_render_test.dart` l.729-744 | idem | idem |
| `out_of_coverage_test.dart` l.565-578 | idem | idem |
| `data_provenance_test.dart` l.54-57 | 5 opérateurs / 117 arrêts / 105 routes | **inchangé** si aucun arrêt/route ajouté |
| `data_provenance_test.dart` l.209-212 | DDD : 15 routes, aucune `CONFIRMED` | **inchangé** (le Lot 1 n'en confirme aucune) |
| `data_provenance_test.dart` l.291 | Tata : 7 routes | inchangé |
| `data_provenance_test.dart` l.370-371 | repli : 117 arrêts / 105 routes | inchangé |

### 5.2 Nouveaux tests (nouveau fichier `referentiel_canonique_test.dart`)

1. **Statuts préservés** : aucune route AFTU/Tata/DDD ne porte `canonical_status = CONFIRMED` par déduction ; les 8 DDD conflictuelles + 7 Tata restent `CONFLICTING`.
2. **Zéro fréquence** : `frequency_status == 'UNKNOWN'` pour **toutes** les routes AFTU/Tata/DDD ; `departure-frequencies.json` inchangé (5 fréquences, TER/BRT uniquement).
3. **Aucun arrêt AFTU** : pour les 72 routes AFTU, `route_documentation == 'ROUTE_DOCUMENTED'` ⇒ **aucun** `stops[]` ajouté (garde-fou anti-`stop_sequence`).
4. **84–91** : `route_documentation == 'ROUTE_NOT_FOUND'` et `stops[]` inchangé.
5. **Horaires cloisonnés** : seul `DDD 1` porte `first_departure`/`last_departure` ; TAF TAF et Express AIBD ne sont rattachés à aucune route urbaine.
6. **Fail-closed** : toute route `CONFIRMED` sans `source` + `verified_at` est lue `UNVERIFIED` par le modèle.
7. **Non-régression moteur** : `npm test` (54 tests) vert ; les tests TER/BRT inchangés verts.

### 5.3 Commandes de vérification

```bash
npm test                    # moteur de départs (tests/departure-engine.test.js)
npm run validate:data       # scripts/check-arrets.js — TER/BRT 42 arrêts
node --test tests/*.test.js
# Flutter (CI) : flutter analyze + flutter test
```

CI de référence : `flutter-web-build.yml` (verte, run `36098382724`). `transit-validation.yml` reste **rouge préexistant** (identique avant/après) — ne pas la « réparer » dans ce lot.

---

## 6. Divergences PWA ↔ Flutter

| Dimension | Flutter (cible Pages) | PWA `index.html` | Conséquence pour l'intégration |
|---|---|---|---|
| Source de données | `dakar_network.json` (105 routes, 117 arrêts) | **42 arrêts codés en dur** | la PWA **ne verra rien** du référentiel canonique |
| AFTU / Tata / DDD | 80 + 7 + 15 routes | **aucune** | intégration PWA = **chantier séparé** |
| Compteur de lignes | `LINES_TOTAL` non affiché | « 76 lignes » en dur (l.6/258/305/313) et `LINES_TOTAL = 105` (l.863) | incohérence **déjà connue** (audit fonctionnel P2) |
| Compteur d'arrêts | dérivé de la donnée | « 42 arrêts » en dur (l.143/192/248/305) | idem |
| Horaires | moteur (TER/BRT seulement) | mêmes fréquences, mêmes limites | cohérent |
| Itinéraires | planificateur Flutter | planificateur **inerte** (audit P1) | ne pas mélanger les deux chantiers |

**Conclusion** : intégrer le référentiel canonique dans la PWA supposerait (a) un chemin de données inexistant (fetch d'un JSON + rendu), (b) la reprise des compteurs en dur, (c) la réparation du planificateur inerte (P1 distinct). **À traiter comme un lot séparé, après décision.**

---

## 7. Risques identifiés et garde-fous (quantifiés)

| # | Risque | Mesure du risque | Garde-fou proposé |
|---|---|---|---|
| 1 | **Explosion d'arrêts dans l'UI** si l'on ajoute les 39 listes DDD | 710 arrêts publiés → paires (route×arrêt) **464 → 1 174 (+153 %)** ; `Stop()` avec `distanceMeters: 300 + i*800` (**valeur calculée**, l.1386) | **Ne pas ajouter d'arrêts au Lot 1.** Si Lot 4 : revoir l.1386 (distance synthétique) et l.1431 (libellé AFTU par défaut) avant tout import |
| 2 | **Verrou d'octets** | 3 tests cassent à la moindre modification du JSON | mise à jour **explicite** avec bloc daté, jamais un contournement |
| 3 | `PARTIAL` lu comme `UNVERIFIED` | l.196-218 fail-closed | acceptable (sûr) ; documenter la perte, ou ajouter l'enum (Lot 3) |
| 4 | Réutilisation du GTFS dormant | `stop_times.txt` non sourcé | **interdit** ; aucune donnée de `data/gtfs/` dans le référentiel |
| 5 | Glissement « corridor ≈ service » | Tata 78/219 = `POSSIBLE_MATCH` | aucune fusion de route ; `service_category` reste documentaire |
| 6 | Fréquence déduite d'une amplitude | TAF TAF / Express AIBD | cloisonnés hors lignes urbaines ; **0 fréquence** ajoutée au registre |
| 7 | Doublons de polylignes carte | `demoRoutes` déduplique par `code == short_name` (l.1412) | si ajout d'arrêts : vérifier l'unicité des `short_name` |
| 8 | Arrêts orphelins mal étiquetés | l.1416-1440 : libellé `AFTU` **par défaut** | ne pas ajouter d'arrêts sans réseau explicite |

---

## 8. Ordre d'exécution recommandé

| Étape | Contenu | Validation requise |
|---|---|---|
| **Étape 1** | Lot 1 (enrichissement JSON) + Lot 2 (verrous + tests) | **oui — décision du donneur d'ordre** |
| Étape 2 | Lot 3 (modèle Dart : exposer `route_documentation`, `canonical_status`, `PARTIAL`) | oui |
| Étape 3 | Lot 4 (affichage) — *optionnel* | oui, avec arbitrage sur les 710 arrêts DDD |
| Étape 4 | PWA (`index.html`) — *chantier séparé* | oui |
| **Exclu** | moteur, fréquences, TER/BRT, GPS, RoutePlanner, Assistant, navigation | — |

**Critères d'acceptation de l'Étape 1** : aucun arrêt ajouté · aucune fréquence ajoutée · aucun horaire ajouté au moteur · `canonical_status` fidèle aux 127 entités · `npm test` vert · tests TER/BRT inchangés verts · verrous mis à jour avec justification datée · `git status` propre hors fichiers prévus · `dakar_network.json` : **aucune suppression**.

---

## 9. Décision demandée

| # | Question | Options |
|---|---|---|
| 1 | Périmètre de l'Étape 1 | **(a) Lot 1 + Lot 2 seuls** (recommandé) · (b) Lot 1 + 2 + 3 · (c) reporter |
| 2 | Faut-il intégrer les **39 listes d'arrêts DDD** (710 arrêts) dans cette phase ? | (a) non (recommandé) · (b) oui, avec reprise de `_integrateNetworkData` |
| 3 | La PWA `index.html` doit-elle suivre ? | (a) non, chantier séparé (recommandé) · (b) oui |

**Aucune modification de production ne sera engagée avant votre réponse.**

---

*Audit d'impact — 2026-09-25 — lecture seule. Aucun fichier existant modifié.*
