# Audit — Référentiel public des lignes AFTU / TATA / DDD (2026-09-30)

MISSION : construire un référentiel PUBLIC des lignes AFTU / Tata / DDD
(numéros, itinéraires, arrêts, raccordement horaire) à partir de sources
officielles ou du brief, sans rien inventer, et l'exposer dans le MÊME moteur de
recherche / routage que le GPS.

## 1. Règle structurante : numéro public obligatoire

Une ligne PUBLIQUE possède **toujours** un numéro officiel :

```
operator + line_number + public_label + origin + destination
```

- `line_number` est un **numéro publié par l'opérateur**, jamais un identifiant
  de feed (`route_id`, `trip_id`). Le test
  `public_bus_lines_test.dart` vérifie qu'aucun `line_number` / `public_label`
  ne contient `_`.
- Un libellé technique (`new_commune_12`, `tata_218`) n'est **jamais** converti
  en numéro public.
- Aucun horaire, aucun arrêt, aucune correspondance n'est fabriqué : les
  horaires ne proviennent que des `stop_times` réels des feeds embarqués.

## 2. Sources

| Réseau | Source officielle | Rôle |
|---|---|---|
| AFTU | `https://aftu-senegal.org/infos-pratiques/` | identités + terminus publiés (72 lignes) |
| DDD | `https://demdikk.sn/info-voyageurs/` | identités + terminus publiés |
| DDD (itinéraires) | `https://demdikk.sn/reseau-urbain-dakar/` | itinéraires publiés |
| PassBi (feeds) | `flutter-src/assets/data/passbi/{ddd,aftu}.json` | raccordement horaire réel (route → trip → stop_sequence) |
| Référentiel canonique | `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` | consolidation §A.2 / §L, datée 2026-09-25 |

### 2.1 Recherche exhaustive des sources (aucune autre source)

| Source examinée | Résultat |
|---|---|
| `flutter-src/assets/data/passbi/aftu.json` | 73 routes, 11 077 trips, 677 918 stop_times (feed de référence AFTU) |
| `flutter-src/assets/data/passbi/ddd.json` | 53 routes, 9 529 trips, 314 029 stop_times (feed de référence DDD) |
| `data/gtfs/` (dépôt) | dormant et non sourcé (canonique §K.3.3) → **inutilisable** |
| `data/transit/passbi/*.zip` | zips sources des feeds ci-dessus (mêmes données) |
| `flutter-src/assets/data/dakar_network.json` | 105 identités terrain, numérotation « AFTU 1 » = observation non vérifiée |
| Recherche de `47`/`52` dans tout le feed AFTU | `47` absent de tout `trip_id`/`stop_time` ; `52` sans aucun `stop_time` |
| Recherche des numéros lettrés DDD (`15A`, `502A`, `327`, `TO1`, `TAF`…) dans le feed | **aucune** route correspondante |

## 3. Résultats du référentiel

Fichier généré par `scripts/build-public-bus-lines.mjs` (schéma **v2**) :

- `data/reference/public_bus_lines_dakar.json` (source de vérité)
- `flutter-src/assets/data/reference/public_bus_lines_dakar.json` (asset app)

| Population | Nombre |
|---|---|
| Lignes AFTU officielles (1–5, 24–89, 91) | **72** |
| dont raccordées aux horaires du feed | **70** |
| Lignes DDD publiques | **48** |
| dont raccordées aux horaires du feed | **34** |
| Identités Tata en audit (aucune ligne publique) | 7 |
| **Lignes publiques raccordées (total)** | **104 / 120** |
| **Lignes publiques NON raccordées** | **16 / 120** |

### 3.0 Chaîne de raccordement vérifiable

Chaque ligne publique expose désormais, quand elle est raccordée, la chaîne
complète et vérifiable :

```
line_number → operator → feed_route_ids → trip_ids_count
            → direction_ids → stop_times_count → served_stop_count
            → stop_sequence_present / stop_sequence_strict
```

Le raccordement se fait **exclusivement** par la numérotation de l'opérateur
(`AFTU_<n>`, `DDD_<nn>`), jamais par similarité de terminus ou de nom. Le
contrôle `scripts/validate-public-bus-lines.mjs` re-dérive la chaîne depuis les
feeds et échoue si un seul maillon manque.

### 3.1 AFTU

Les 72 numéros publiés par AFTU sont présents. **70** lignes sont raccordées.
Deux lignes ne le sont pas, cause exacte documentée :

| Ligne | Cause | Constat |
|---|---|---|
| `AFTU 47` | `FEED_ROUTE_WITHOUT_TRIP` | route `AFTU_47` présente dans le feed, **0 trip** |
| `AFTU 52` | `FEED_ROUTE_WITHOUT_STOP_TIME` | route `AFTU_52` avec 190 trips mais **0 stop_time** |

> Recherche exhaustive (aucune autre source) : le numéro `47` n'apparaît dans
> **aucun** `trip_id` ni `stop_time` de tout le feed AFTU ; `AFTU_52` a des
> trips mais aucun `stop_time`. `data/gtfs/` est dormant et non sourcé
> (canonique §K.3.3), donc inutilisable. Aucun horaire ne peut être produit
> sans fabriquer une donnée.

Quatre lignes (`AFTU 43`, `59`, `80`, `84`) portent des `stop_sequence`
**dupliquées** dans certains trips du feed. C'est une qualité de donnée
signalée (`stop_sequence_strict = false`) — la chaîne reste raccordée.

Le champ `vehicle_type` vaut `TATA` pour les lignes AFTU : « Tata » désigne la
catégorie usuelle des minibus de l'écosystème AFTU (source S-I1), **jamais un
opérateur**.

### 3.2 DDD

48 lignes publiques DDD. **34** sont raccordées (numérotation `DDD_<nn>`).
**14** ne le sont pas, toutes avec la cause exacte
`NO_FEED_ROUTE_FOR_LINE_NUMBER` : le feed Dem Dikk n'expose **aucune** route
portant ces numéros.

| Lignes non raccordées | Constat |
|---|---|
| `15A`, `15B`, `16A`, `16B` | variantes lettrées ; le feed n'a que `DDD_15`/`DDD_16` (numéro nu) |
| `502A`, `502B`, `503A`, `503B` | boucles A/B ; le feed n'a que `DDD_502`/`DDD_503` |
| `504A`, `504B` | le feed n'a que `DDD_504` ; la source canonique note 504A/504B « absentes » |
| `327` | la source canonique la distingue de la 227 ; aucune route `DDD_327` au feed |
| `TO1`, `TAF`, `TAF TAF` | services TAF TAF (catégorie propre) ; aucune route correspondante au feed |

Raccorder ces lignes imposerait de les rattacher au numéro **nu** du feed
(`502A`→`DDD_502`) — une fusion non prouvée, interdite par la règle de
verrouillage (identité ≠ horaire) et la règle « aucune invention ». Elles
restent donc explicitement listées dans `unresolved_public_lines`.

`TAF TAF` conserve son statut publié (`published_schedule_status =
SCHEDULE_CONFIRMED`, canonique §L), distinct du raccordement feed.

### 3.3 Tata

Tata est un **type de véhicule**, pas un opérateur. Aucune source admissible
n'établit de numéro de ligne Tata. Les 7 identités techniques
(`new_commune_11`, `new_commune_12`, `tata_50`, `tata_64`, `tata_78`,
`tata_218`, `tata_219`) sont conservées dans `tata_audit` avec
`line_number: null` et `public_label: null` : elles ne sont **jamais** rendues
comme lignes publiques.

## 4. Intégration au moteur de recherche / routage

Le référentiel est exposé dans le **catalogue unique**
(`NetworkSearchCatalogBuilder.fromPublicLines`) : la barre de recherche et le
GPS interrogent le même référentiel.

| Nature | Avant | Après |
|---|---|---|
| Total catalogue | 3849 | **4106** |
| Mobilités | 4 | 4 |
| Lignes | 266 | **386** (+120 lignes publiques) |
| Arrêts | 3423 | 3423 |
| Gares / stations | 56 | 56 |
| Terminus | 46 | 46 |
| Pôles | 4 | 4 |
| Destinations | 50 | **187** (+137 terminus publiés) |

- Une ligne publique est recherchable par son numéro (« AFTU 26 »,
  « DDD 221 »).
- Les terminus publiés alimentent les destinations (lieux atteignables).
- Un nouveau filtre **« Lignes »** affiche les 120 lignes publiques avec leur
  numéro, leurs terminus publiés et la disponibilité des horaires.

## 5. Garanties (aucune invention)

- `line_number` = numéro publié, jamais un identifiant de feed.
- Aucun horaire construit : seuls les `stop_times` réels comptent.
- `served_stop_count` = arrêts réellement desservis (0 si non raccordé).
- Aucune identité Tata exposée comme ligne.
- Une variante lettrée n'est jamais raccordée au numéro nu du feed.
- Le numéro public n'est jamais déduit d'un `route_id`.

## 6. Non-régression

- Aucune donnée TER / BRT / GTFS modifiée.
- Aucun changement de DakarClock, `nextRealDepartures`, `service_availability`,
  fin de service, reprise T-1h, calendrier GTFS, gestion >24h,
  `servedInOrder()`, logique TER/BRT, GPS existant.
- Le chargement du référentiel est **non bloquant** : un asset illisible laisse
  le catalogue vide sans planter.
- Ajout **purement additif** : nouvelles entrées de recherche + nouveau filtre.

## 7. Porte de complétude (§6 / §15) — le chantier n’est PAS terminé

Règle absolue : **toute** ligne publique AFTU/DDD doit être raccordée aux
données horaires réelles. Un contrôle dédié applique cette règle :

| Contrôle | Effet |
|---|---|
| `npm run validate:public-lines` (`scripts/validate-public-bus-lines.mjs`) | re-dérive la chaîne depuis les feeds ; **exit 1** avec la liste si une ligne manque |
| `tests/public-bus-lines.test.js` — « TEST CRITIQUE — 100 %… » | échoue en listant les lignes non raccordées |
| `flutter-src/test/public_bus_lines_test.dart` — « TEST CRITIQUE — 100 %… » | idem côté Dart |

État actuel : **104 / 120** lignes raccordées, **16 / 120** non raccordées
(AFTU 47, 52 + 14 DDD). Le contrôle échoue donc **volontairement** : il matérialise
l’écart restant sans jamais le masquer. Le chantier ne pourra être déclaré
terminé qu’une fois les données manquantes publiées par les opérateurs
(itéraires/arrêts/horaires des 14 lignes DDD et trips/stop_times AFTU 47/52).

## 8. Tests

- `flutter-src/test/public_bus_lines_test.dart` : lignes AFTU, lignes DDD,
  intégrité (chaîne horaire vérifiable), porte de complétude, recherche.
- `tests/public-bus-lines.test.js` : invariants du générateur + chaîne horaire +
  porte de complétude.
- Suite complète : `flutter analyze`, `flutter test`, `npm test`,
  `npm run validate:data`.

## 9. Validation

Voir le rapport final (SHA, fichiers modifiés, build, compteurs).
