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

## 3. Résultats du référentiel

Fichier généré par `scripts/build-public-bus-lines.mjs` :

- `data/reference/public_bus_lines_dakar.json` (source de vérité)
- `flutter-src/assets/data/reference/public_bus_lines_dakar.json` (asset app)

| Population | Nombre |
|---|---|
| Lignes AFTU officielles (1–5, 24–89, 91) | **72** |
| dont raccordées aux horaires du feed | 70 |
| Lignes DDD publiques | **48** |
| dont raccordées aux horaires du feed | 34 |
| Identités Tata en audit (aucune ligne publique) | 7 |

### 3.1 AFTU

Les 72 numéros publiés par AFTU sont présents. Deux lignes (`AFTU 47`,
`AFTU 52`) existent dans le feed mais **sans aucun `stop_time`** : elles restent
`NO_SCHEDULE` avec 0 arrêt desservi — le référentiel ne leur attribue aucun
horaire.

Le champ `vehicle_type` vaut `TATA` pour les lignes AFTU : « Tata » désigne la
catégorie usuelle des minibus de l'écosystème AFTU (source S-I1), **jamais un
opérateur**.

### 3.2 DDD

48 lignes publiques DDD. Les **variantes lettrées** (`15A`, `15B`, `16A`,
`16B`, `502A`, `502B`, `503A`, `503B`, `504A`, `504B`) ne sont **pas**
raccordées au numéro nu du feed : un `route_id` `DDD_15` ne permet pas de
trancher entre 15A et 15B. Elles restent `NO_SCHEDULE`.

Exception documentée : `TAF TAF` porte un horaire `SCHEDULE_CONFIRMED` dans le
référentiel canonique (§L) ; son statut publié est conservé tel quel
(`published_schedule_status`), distinct du raccordement feed.

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

## 7. Tests

- `flutter-src/test/public_bus_lines_test.dart` (15 tests) : lignes AFTU,
  lignes DDD, intégrité, recherche.
- `tests/public-bus-lines.test.js` (10 tests) : invariants du générateur.
- Suite complète : `flutter analyze`, `flutter test` (806 tests),
  `npm test` (115 tests).

## 8. Validation

Voir le rapport final (SHA, fichiers modifiés, build, compteurs).
