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

Fichier généré par `scripts/build-public-bus-lines.mjs` (schéma **v3**) :

- `data/reference/public_bus_lines_dakar.json` (source de vérité)
- `flutter-src/assets/data/reference/public_bus_lines_dakar.json` (asset app)

| Population | Nombre |
|---|---|
| Lignes AFTU officielles (1–5, 24–89, 91) | **72** |
| dont raccordées aux horaires du feed | **70** |
| Lignes DDD publiques | **48** |
| dont raccordées aux horaires du feed | **34** |
| Identités Tata en audit (aucune ligne publique) | 7 |
| **Lignes publiques raccordées (CONNECTED)** | **104 / 120** |
| **Lignes publiques NON raccordées** | **16 / 120** (2 BLOCKED, 14 NOT_VERIFIED) |

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

### 3.0.1 Statut de raccordement explicite (`mapping_status`, §9)

Le statut n'est **jamais optimiste** : `CONNECTED` exige la chaîne complète.

| Statut | Signification | Nombre |
|---|---|---|
| `CONNECTED` | les 6 maillons existent réellement | **104** |
| `BLOCKED` | une route du feed porte ce numéro, mais un maillon manque | **2** |
| `NOT_VERIFIED` | aucune route du feed ne porte ce numéro public | **14** |
| `PARTIAL` | réservé (aucune ligne dans cet état) | 0 |

Toute ligne non raccordée porte en plus une **preuve de blocage** (`blocking`) :
`reason`, `missing_fields`, `feed_route_ids_present`, `bare_number_route_ids`
(route au numéro nu, jamais fusionnée), `consulted_sources`, `next_action`.

### 3.0.2 Qualité de l'ordre des arrêts (`sequence_quality`)

`sequence_quality` = `STRICT` | `UNORDERED_IN_FEED` | `ABSENT`. Une
`stop_sequence` dupliquée dans certains trips (`AFTU 43`, `59`, `80`, `84`) est
un artefact de donnée **source** : elle est signalée mais **ne dé-raccorde
pas** la ligne.

### 3.1 AFTU

Les 72 numéros publiés par AFTU sont présents. **70** lignes sont raccordées.
Deux lignes ne le sont pas, cause exacte documentée (`mapping_status = BLOCKED`) :

| Ligne | Cause | Constat | Preuve de blocage |
|---|---|---|---|
| `AFTU 47` | `FEED_ROUTE_WITHOUT_TRIP` | route `AFTU_47` présente dans le feed, **0 trip** | `feed_route_ids_present = ["AFTU_47"]`, `missing_fields` = trip_id, direction_id, stop_id, stop_sequence, stop_times |
| `AFTU 52` | `FEED_ROUTE_WITHOUT_STOP_TIME` | route `AFTU_52` avec 190 trips mais **0 stop_time** | `feed_route_ids_present = ["AFTU_52"]`, `missing_fields` = stop_times, stop_sequence |

> Recherche exhaustive (aucune autre source) : le numéro `47` n'apparaît dans
> **aucun** `trip_id` ni `stop_time` de tout le feed AFTU ; `AFTU_52` a des
> trips mais aucun `stop_time`. `data/gtfs/` est dormant et non sourcé
> (canonique §K.3.3), donc inutilisable. Aucun horaire ne peut être produit
> sans fabriquer une donnée. La preuve de blocage indique la prochaine action :
> obtenir de la source les trips/stop_times manquants.

Quatre lignes (`AFTU 43`, `59`, `80`, `84`) portent des `stop_sequence`
**dupliquées** dans certains trips du feed. C'est une qualité de donnée
signalée (`sequence_quality = UNORDERED_IN_FEED`) — la chaîne reste raccordée
(`mapping_status = CONNECTED`).

Le champ `vehicle_type` vaut `TATA` pour les lignes AFTU : « Tata » désigne la
catégorie usuelle des minibus de l'écosystème AFTU (source S-I1), **jamais un
opérateur**.

### 3.2 DDD

48 lignes publiques DDD. **34** sont raccordées (numérotation `DDD_<nn>`).
**14** ne le sont pas, toutes avec la cause exacte
`NO_FEED_ROUTE_FOR_LINE_NUMBER` (`mapping_status = NOT_VERIFIED`) : le feed Dem
Dikk n'expose **aucune** route portant ces numéros.

| Lignes non raccordées | Constat | Route au numéro nu (NON fusionnée) |
|---|---|---|
| `15A`, `15B` | variantes lettrées ; le feed n'a que `DDD_15` | `DDD_15` |
| `16A`, `16B` | variantes lettrées ; le feed n'a que `DDD_16` | `DDD_16` |
| `502A`, `502B` | boucles A/B ; le feed n'a que `DDD_502` | `DDD_502` |
| `503A`, `503B` | boucles A/B ; le feed n'a que `DDD_503` | `DDD_503` |
| `504A`, `504B` | le feed n'a que `DDD_504` | `DDD_504` |
| `327` | la source canonique la distingue de la 227 ; aucune route `DDD_327` au feed | — |
| `TO1`, `TAF`, `TAF TAF` | services TAF TAF (catégorie propre) ; aucune route correspondante au feed | — |

Raccorder ces lignes imposerait de les rattacher au numéro **nu** du feed
(`502A`→`DDD_502`) — une fusion non prouvée, interdite par la règle de
verrouillage (identité ≠ horaire) et la règle « aucune invention ». Elles
restent donc explicitement listées dans `unresolved_public_lines`, et la preuve
de blocage cite la route au numéro nu dans `bare_number_route_ids` avec la
prochaine action : « obtenir de la source la preuve que la variante emprunte
bien cette route AVANT tout raccordement ».

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
  numéro, leurs terminus publiés et le statut de raccordement réel.
- Une carte ligne est **cliquable** et ouvre une **fiche ligne** réelle
  (`PublicLineDetailPage`) : identité, terminus, statut, chaîne horaire (si
  CONNECTED) ou **preuve de blocage** (si BLOCKED/NOT_VERIFIED), et — pour une
  ligne raccordée — ses **arrêts réels ordonnés par `stop_sequence`**
  (trip le plus complet du feed). Une ligne non raccordée n'a **aucune** fiche
  d'arrêts fabriquée.
- Une suggestion de recherche de nature LIGNE ouvre la même fiche ligne (aucun
  bouton mort) ; une ligne de feed sans identité publique reste un recentrage.

## 5. Garanties (aucune invention)

- `line_number` = numéro publié, jamais un identifiant de feed.
- Aucun horaire construit : seuls les `stop_times` réels comptent.
- `served_stop_count` = arrêts réellement desservis (0 si non raccordé).
- `mapping_status` n'est jamais optimiste : `CONNECTED` exige les 6 maillons ;
  toute ligne non raccordée porte une cause exacte ET une preuve de blocage.
- Aucune identité Tata exposée comme ligne.
- Une variante lettrée n'est jamais raccordée au numéro nu du feed ; la route
  au numéro nu est **citée** dans la preuve de blocage, jamais fusionnée.
- Le numéro public n'est jamais déduit d'un `route_id`.
- Aucune ligne n'est supprimée du référentiel pour masquer un blocage.

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


## 10. Contrôle de dérive du catalogue AFTU — 24 novembre 2026

### Sources comparées

- Page publique AFTU « Infos pratiques », relue le 24 novembre 2026 : https://aftu-senegal.org/infos-pratiques/
- Référentiel canonique embarqué dans ce dépôt : §A.2, vérifié le 25 septembre 2026 (docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md).

La page AFTU actuellement publiée présente plusieurs numéros avec des terminus qui diffèrent de ceux inscrits dans le référentiel canonique embarqué. Exemples contrôlés :

| Numéro | Page AFTU consultée le 24-11-2026 | Référentiel canonique embarqué (25-09-2026) |
|---|---|---|
| 46 | Lat Dior – Almadies | SDE Serigne Assane – Lat Dior |
| 47 | Cité Serigne Mansour – Lat Dior | Lat Dior – Almadies |
| 48 | Gadaye – Ngor | Cité Serigne Mansour – Lat Dior |
| 50 | Jaxaay – Gare des Baux Maraîchers | Petersen – Malika Cimetière |
| 55 | Jaxaay 2 – Petersen | Terminus Rufisque Sonadis – Petersen |
| 58 | Diamalaye – Cité Gendarmerie (Jaxaay) | Sahm – Comico |
| 62 | Terminus Camp Marchand Rufisque – Stade LSS | Arrêt Chérif (Rufisque) – Penc Mi (Gueule Tapée) |
| 82 | Rufisque Arafat – Zone de Captage | Lat Dior – Comico Yeumbeul |

### Interprétation prudente

Ces différences sont une **dérive documentaire à résoudre**, pas une preuve que les identifiants de ligne ont tous été renumérotés ni que les données PassBi sont erronées. La page AFTU actuelle et le référentiel de septembre ne sont pas synchronisés sur ces entrées. Le présent contrôle ne permet pas d'établir si les écarts résultent d'une renumérotation, d'une évolution d'itinéraire, d'une erreur de publication ou d'une version différente du réseau.

Le générateur actuel raccorde les routes AFTU au numéro identique (AFTU_<n>), puis vérifie la chaîne technique des trips et stop_times. Cette vérification prouve que la route du feed existe et contient des horaires ; elle ne prouve pas à elle seule que ses terminus correspondent à l'identité actuellement publiée par AFTU.

### Décision de sûreté

- Ne pas réécrire automatiquement le référentiel canonique à partir d'un seul relevé de page web.
- Ne pas décaler les numéros AFTU et ne pas déplacer les horaires d'une ligne vers une autre.
- Ne pas déclarer que la correspondance AFTU_<n> ↔ ligne publique <n> est validée uniquement parce que les numéros coïncident.
- Conserver les données PassBi brutes et les horaires inchangés tant qu'une table de correspondance datée de l'opérateur ou une confirmation écrite n'est pas disponible.
- Ajouter ce contrôle à la liste des vérifications bloquantes avant de considérer les raccordements AFTU 46–82 comme définitivement validés.
- Aucun changement d'interface, d'horaire, de fréquence, de sens, de ligne TER/BRT ou de source de données n'est effectué par cette note.

**Action attendue pour lever l'écart :** obtenir d'AFTU/CETUD la version datée du plan de lignes et la correspondance explicite entre chaque numéro public, chaque route PassBi et ses terminus. En attendant, toute correction de numérotation serait une supposition.


## 11. Triangulation AFTU : catalogue public, guide CETUD des JOJ et métadonnées PassBi — 24 novembre 2026

### Sources distinctes
- Catalogue public AFTU consulté le 24 novembre 2026 : https://aftu-senegal.org/infos-pratiques/
- Guide officiel de mobilité JOJ Dakar publié pour la période événementielle du 31 octobre au 13 novembre 2026 : https://montrajetjoj.sn/guide-mobilite-joj.pdf
- Inventaire technique PassBi déjà relevé dans `docs/INTEGRATION_PASSBI_DDD_AFTU_4_21_2026-09-28.md`.
- Référentiel canonique local daté du 25 septembre 2026.

### Comparaison de quelques identités
| Ligne | Catalogue AFTU consulté le 24-11 | Guide officiel JOJ 2026 | Nom technique PassBi | Référentiel local du 25-09 |
|---|---|---|---|---|
| 46 | SDE Serigne Assane – Lat Dior | Guédiawaye – Lat Dior | Guédiawaye – Lat Dior | SDE Serigne Assane – Lat Dior |
| 48 | Gadaye – Ngor | Kounoune – Lat Dior | Lat Dior – Rufisque | Cité Serigne Mansour – Lat Dior |
| 50 | Jaxaay – Gare des Baux Maraîchers | Cité APIX – Petersen | Malika – Petersen | Petersen – Malika Cimetière |
| 55 | Jaxaay 2 – Petersen | Rufisque – Petersen | Petersen – Rufisque | Rufisque Sonadis – Petersen |
| 58 | Diamalaye – Cité Gendarmerie | Comico Yeumbeul – Sahm | Comico – Sahm | Sahm – Comico |
| 82 | Rufisque Arafat – Zone de Captage | Comico Yeumbeul – Lat Dior | Comico Yeumbeul – Lat Dior | Lat Dior – Comico Yeumbeul |

Le guide JOJ apporte une corroboration indépendante pour certains noms techniques du feed (notamment 46, 55 et 82), mais il s'agit d'un document de mobilité événementielle et non d'une table de correspondance permanente entre les identifiants PassBi et le catalogue AFTU. Il ne résout donc pas les contradictions avec la page AFTU consultée le même jour. Pour 48, 50 et 58, les trois sources donnent même des terminus différents.

### Conséquence pour le raccordement
- Le champ technique du feed confirme l'existence de routes et de chaînes horaires ; il ne constitue pas, à lui seul, une preuve d'identité publique.
- La similitude des terminus entre le guide JOJ et le feed ne suffit pas à valider définitivement une correspondance durable.
- La ligne 55 illustre une contradiction de catalogue : le guide JOJ et le nom technique PassBi convergent sur le corridor Rufisque–Petersen, tandis que la page AFTU actuelle publie Jaxaay 2–Petersen. La page officielle AFTU et le référentiel local avaient déjà été relevés comme contradictoires.
- Aucun décalage de numéros, aucune permutation de lignes et aucun transfert d'horaires ne sont autorisés par ces éléments.
- Les statuts d'identité doivent rester prudents jusqu'à réception d'une table AFTU/CETUD datée reliant explicitement numéro public, identifiant de route PassBi et terminus.

### Décision
Cette triangulation est ajoutée comme preuve d'audit, pas comme correction de données. Aucun fichier GTFS/PassBi, horaire, arrêt, sens, fréquence, référentiel public, code applicatif ou interface n'est modifié par cette section.


## 12. Contrôle des noms de routes AFTU dans le flux PassBi — 24 novembre 2026

Le contrôle précédent comparait le catalogue AFTU public au référentiel canonique. Le présent contrôle ajoute une troisième colonne : le nom technique des routes du flux PassBi, tel qu'il est consigné dans l'inventaire de feed `docs/INTEGRATION_PASSBI_DDD_AFTU_TATA_4_21_2026-09-28.md`.

| ID de route PassBi | Nom technique du feed | Ligne publique AFTU actuelle portant le même numéro | Observation |
|---|---|---|---|
| AFTU_46 | Guédiawaye – Lat Dior | 46 : Lat Dior – Almadies | Terminus différents ; le guide JOJ mentionne Guédiawaye – Lat Dior, sans établir une correspondance permanente |
| AFTU_47 | Lat Dior – Almadies | 47 : Cité Serigne Mansour – Lat Dior | Identité différente ; aucun trip exploitable dans le feed |
| AFTU_48 | Lat Dior – Rufisque | 48 : Gadaye – Ngor | Identité différente |
| AFTU_49 | Gadaye – Ngor | 49 : Petersen – Malika Cimetière | Identité différente |
| AFTU_50 | Malika – Petersen | 50 : Jaxaay – Baux Maraîchers | Identité différente ; le référentiel canonique de septembre décrit encore Petersen – Malika Cimetière |
| AFTU_51 | Baux Maraîchers – Jaxaay | 51 : Bountou Pikine – Keur Massar | Identité différente |
| AFTU_52 | Baux Maraîchers – Jaxaay | 52 : Keur Massar – Sébikotane | Identité différente ; 190 trips mais aucun stop_time exploitable |
| AFTU_53 | Keur Massar – Sébikotane | 53 : Keur Massar (Cité MTOA) – UCAD | Identité différente |
| AFTU_54 | MTOA – UCAD | 54 : Rufisque Sonadis – Petersen | Identité différente |
| AFTU_55 | Petersen – Rufisque | 55 : Jaxaay 2 – Petersen | Le guide JOJ et le référentiel antérieur décrivent le corridor Rufisque – Petersen, mais la page AFTU actuelle publie une autre identité sous le numéro 55 |
| AFTU_56 | Jaxaay – Petersen | 56 : Liberté 6 – Rufisque | Identité différente |
| AFTU_57 | Liberté 5 – Rufisque Gouye Mouride | 57 : Sahm – Comico | Identité différente |
| AFTU_58 | Comico – Sahm | 58 : Diamalaye – Cité Gendarmerie | Identité différente ; le référentiel de septembre associait encore le numéro 58 à Sahm – Comico |
| AFTU_59 | Cité Gendarmerie – Diamalaye | 59 : Colobane – Bargny | Identité différente |
| AFTU_60 | Bargny – Colobane | 60 : Almadies – Keur Massar | Identité différente |
| AFTU_61 | Keur Massar – Mamelles | 61 : Arrêt Chérif – Penc Mi | Identité différente |
| AFTU_62 | Gueule Tapée – Youssou Mbergane | 62 : Camp Marchand Rufisque – Stade LSS | Identité différente |
| AFTU_63 | Stade de l'Amitié – Rufisque | 63 : Guédiawaye – Rufisque | Identité différente |
| AFTU_64 | Diamniadio – Guédiawaye | 64 : Colobane – Jaxaay | Identité différente |
| AFTU_65 | Colobane – Kounoune | 65 : Yoff – Gorom 1 | Identité différente |
| AFTU_66 | Gorom – Yoff | 66 : Ouakam – Thiawlène | Identité différente |
| AFTU_67 | Ouakam – Thiawlène | 67 : Yeumbeul – Sébikotane | Identité différente |
| AFTU_68 | Sébikotane – Tally Diallo | 68 : Diamalaye – Tivaouane Peul | Identité différente |
| AFTU_69 | Diamalaye – Namora | 69 : Daroukhane – Jaxaay 2 | Identité différente |
| AFTU_70 | Daroukhane – Diaxaye | 70 : Keur Massar – Claudel | Identité différente |
| AFTU_71 | Claudel – Keur Massar | 71 : Guédiawaye – Kounoune | Identité différente |
| AFTU_72 | Kounoune – Guédiawaye | 72 : Lac Rose – Poste Thiaroye | Identité différente |
| AFTU_73 | Lac Rose – Poste Thiaroye | 73 : Bargny – Tivaouane Peul | Identité différente |
| AFTU_74 | Bargny – Socabec | 74 : Malika – Gare routière Colobane | Identité différente |
| AFTU_75 | Colobane – Malika | 75 : Sipres – Cité Assurance | Identité différente |
| AFTU_76 | Assurance – Sipress | 76 : Rufisque – Liberté 5 | Identité différente |
| AFTU_77 | Cité Tacco – Liberté 5 | 77 : Diamaguène – Liberté 5 | Identité différente |
| AFTU_78 | Diamaguène – Liberté 5 | 78 : Sangalkam – Cambérène | Identité différente |
| AFTU_79 | Cambérène 2 – Gorom | 79 : Diamalaye – Darou Thioub | Identité différente |
| AFTU_80 | Darou Thioub – Diamalaye | 80 : Baux Maraîchers – Tivaouane Peul | Identité différente |
| AFTU_81 | Baux Maraîchers – Tawfekh | 81 : Lat Dior – Comico Yeumbeul | Identité différente |
| AFTU_82 | Cité Comico – Lat Dior | 82 : Rufisque Arafat – Zone de Captage | Le guide JOJ mentionne Comico Yeumbeul – Lat Dior ; le référentiel de septembre associait ce corridor au numéro 82 |
| AFTU_83 | Arafat – Zone de Captage | 83 : UCAD – Jaxaay | Identité différente |
| AFTU_84 | Jaxaay – UCAD | 84 : Banoba – Liberté 5 | Identité différente |
| AFTU_85 | Lac Rose – Liberté 5 | 85 : Tournalou Boune – Toubab Dialaw | Identité différente |
| AFTU_86 | Thiaroye – Toubab Dialaw | 86 : Bambilor – Mosquée Massalikou Djinane | Identité différente |
| AFTU_87 | Bambilor / Comico – Massalikou | 87 : MTOA – Liberté 5 | Identité différente |
| AFTU_88 | Keur Massar – Liberté 5 | 88 : Bargny – Croisement Niague | Identité différente |
| AFTU_89 | Bargny – Tawfekh | 89 : APIX – Dougar | Identité différente |

### Lecture et limites
Cette comparaison révèle une divergence étendue entre les noms de routes du feed et les identités publiques portant les mêmes numéros. Plusieurs noms techniques semblent correspondre à des identités publiées sous un autre numéro, mais cette ressemblance ne constitue pas une table de correspondance vérifiée. Les orientations peuvent aussi être inversées dans les libellés, et certains noms de terminus sont abrégés.

La page AFTU, le référentiel canonique de septembre, le guide événementiel JOJ et les noms techniques PassBi ne sont donc pas interchangeables. Une hypothèse de décalage numérique, même si elle semble expliquer plusieurs lignes consécutives, ne doit pas être appliquée automatiquement : elle pourrait déplacer des horaires vers une mauvaise identité publique.

### Décision opérationnelle
1. Le générateur actuel utilise toujours le numéro identique pour choisir la route PassBi AFTU. Cela établit une chaîne technique de données, pas une identité d'itinéraire démontrée.
2. Ne pas permuter les numéros, les terminus ou les horaires sur la base de cette comparaison.
3. Ne pas supprimer les horaires du flux ni les remplacer par des fréquences estimées : les données PassBi restent la source horaire exclusive décidée pour ce chantier.
4. Avant de déclarer le raccordement identité ↔ route validé, obtenir une table de correspondance datée et explicite de l'opérateur/CETUD, ou un fichier de feed dont les identifiants et métadonnées permettent une preuve univoque.
5. La présente section est une pièce d'audit uniquement. Aucun code, asset JSON, horaire, arrêt, sens, fréquence ou élément d'interface n'est modifié.

**Point de vigilance majeur :** tant que cette correspondance n'est pas établie, le statut technique `CONNECTED` signifie seulement que la route choisie contient une chaîne exploitable de trips, directions, arrêts et stop_times. Il ne doit pas être interprété comme une certification de l'identité de la ligne publique.


## 13. Contrôle du générateur et du validateur — séparation des preuves — 24 novembre 2026

### 13.1 Trois preuves distinctes

L'inspection de `scripts/build-public-bus-lines.mjs`, `scripts/validate-public-bus-lines.mjs`, de `tests/public-bus-lines.test.js` et du modèle Flutter confirme que trois notions doivent rester indépendantes :

1. **Identité publique** : la ligne et son numéro existent dans le catalogue officiel AFTU ou DDD.
2. **Disponibilité horaire technique** : la route PassBi sélectionnée possède effectivement des trips, des direction_id, des stop_id, des stop_sequence et des stop_times permettant de calculer un départ.
3. **Correspondance identité ↔ route PassBi** : une preuve documentaire établit que cette route technique est bien celle de la ligne publique affichée.

Une preuve pour l'une de ces notions ne vaut pas preuve pour les deux autres.

### 13.2 Ce que le code vérifie actuellement

- Le générateur AFTU sélectionne les routes PassBi par égalité numérique (`AFTU 46` → `AFTU_46`, etc.).
- Le générateur DDD sélectionne également les routes par numéro nu ; les variantes lettrées sont correctement laissées sans raccordement et les routes nues 15/502/503 ne sont pas fusionnées automatiquement avec 15A/15B, 502A/502B ou 503A/503B.
- Le validateur reconstitue la chaîne technique et vérifie que le `route_id` appartient au groupe portant le même numéro. Il vérifie aussi les trips, directions, arrêts, stop_times et la possibilité d'embarquer.
- Les tests vérifient la cohérence de cette chaîne et l'absence de fusion des variantes lettrées.

Ces contrôles sont utiles et doivent être conservés. Toutefois, l'égalité du numéro technique et du numéro public ne démontre pas, à elle seule, l'identité de l'itinéraire. Le validateur actuel ne compare pas systématiquement les terminus et les séquences du feed aux publications officielles pour établir cette preuve. Les divergences AFTU documentées à la section 12 et les ambiguïtés DDD documentées dans l'audit DDD illustrent ce risque.

### 13.3 Risque sémantique identifié

Le champ `mapping_status = CONNECTED` est aujourd'hui calculé à partir de la chaîne horaire et le libellé Flutter associé est « Horaires raccordés ». Il décrit donc un raccordement technique exploitable. Il ne doit pas être présenté dans la documentation, les contrôles ou les décisions métier comme une validation de l'identité publique de la route.

De même, les champs `identity_status`, `route_status` et `mapping_status` ne doivent pas être confondus : l'identité officielle d'une ligne publique peut être connue alors que sa correspondance avec un `route_id` PassBi reste non prouvée.

### 13.4 Correction à préparer, sans régression horaire

La prochaine évolution technique devra ajouter une preuve indépendante de correspondance identité ↔ route (par exemple un statut explicite de correspondance de route et sa référence documentaire), puis des tests qui couvrent au minimum :

- AFTU 46 à 89 : une route au même numéro ne suffit pas à certifier la correspondance lorsque les noms du feed divergent du catalogue public ;
- DDD 15, 502 et 503 : une route au numéro nu ne certifie pas l'une des variantes lettrées ;
- DDD 15A/15B, 502A/502B et 503A/503B : aucune fusion avec la route au numéro nu ;
- les lignes dont la correspondance est prouvée : la preuve doit être explicite, datée et traçable ;
- indépendance stricte : une correspondance non prouvée ne doit pas effacer les horaires techniques réellement présents dans PassBi.

Cette évolution ne doit ni modifier les feeds, ni changer les horaires, ni réintroduire une fréquence de secours, ni modifier les libellés ou l'interface sans validation spécifique. Le comportement horaire actuel reste inchangé tant que les tests d'impact ne démontrent pas que la séparation peut être ajoutée sans régression.

### 13.5 Décision de cette passe

Audit et diagnostic uniquement. Aucun changement du générateur, du validateur, des tests, des JSON, des horaires, des arrêts ou de l'interface dans cette passe. La correction de schéma est isolée comme chantier suivant afin de ne pas confondre une amélioration de traçabilité avec une modification du service affiché.


## 14. Consommateurs Flutter du raccordement — risque d'étiquetage public — 24 novembre 2026

### 14.1 Chaîne de consommation vérifiée

L'inspection de `flutter-src/lib/services/public_bus_line_catalog.dart`, `flutter-src/lib/services/schedule_provider.dart` et `flutter-src/lib/services/data_service.dart` établit le chemin suivant :

- `PublicBusLineCatalog.publicLabelForFeedRouteId(routeId)` renvoie le libellé public dès que le `route_id` figure dans `PublicBusLine.feedRouteIds` ;
- `ScheduleProvider.documentedCatalogLabelForFeedRouteId(routeId)` transmet ce libellé au chemin natif PassBi ;
- `departureAtPassBiStop()` utilise ce libellé pour construire `lineLabel` ;
- `DataService.publicLineStopSequence()` autorise la fiche d'arrêts dès que `PublicBusLine.hasRealSchedule` est vrai.

Le garde-fou actuel est donc le raccordement technique `mapping_status = CONNECTED`, pas une preuve indépendante de correspondance entre l'identité publique et la route PassBi.

### 14.2 Conséquence

Pour une ligne AFTU dont le numéro du feed correspond au numéro public mais dont les terminus/identités divergent, le catalogue peut fournir un libellé public au chemin natif. Les horaires et arrêts restent des données réellement présentes dans le feed, mais leur attribution à ce libellé public n'est pas démontrée. Le risque concerne donc l'étiquette et la fiche de ligne, pas l'authenticité des `stop_times` eux-mêmes.

Les variantes DDD lettrées déjà non raccordées restent protégées : elles ne figurent pas dans `feedRouteIds`. Les routes DDD au numéro nu 15/502/503 demeurent toutefois à traiter séparément des variantes officielles lettrées.

### 14.3 Correction proposée et limites

Ajouter au référentiel un champ indépendant, par exemple `feed_route_identity_status`, avec des valeurs explicites `VERIFIED` / `UNVERIFIED` et une référence de preuve lorsque la correspondance est établie. Ce champ ne doit jamais être calculé depuis le seul numéro, le `route_id`, les horaires présents ou la proximité des terminus.

Les consommateurs de libellés publics et de fiches publiques devront exiger cette preuve indépendante. En revanche, la disponibilité horaire technique doit rester séparée : le nouveau statut ne doit ni supprimer les trips/stop_times du feed, ni changer les horaires natifs réellement calculables, ni réintroduire les fréquences de secours.

Aucune correspondance AFTU ne peut être marquée `VERIFIED` sur la seule base des comparaisons actuelles : la table officielle de correspondance reste à obtenir. Pour DDD, les routes nues ambiguës 15/502/503 ne peuvent pas certifier les variantes A/B.

### 14.4 Décision de cette passe

Constat de consommation et de risque ajouté à l'audit. Aucun changement de code, de JSON, de libellé, de fiche, d'horaire, d'arrêt ou d'interface n'est effectué dans cette passe : la correction doit être implémentée avec tests ciblés et contrôle de régression Flutter, car elle peut modifier les libellés publics visibles. Aucun déploiement ni fusion.


## 15. Mise en place de la preuve indépendante d'identité — 24 novembre 2026

### Schéma ajouté

Le référentiel porte désormais deux statuts distincts :

- `mapping_status` / `schedule_status` : existence de la chaîne technique et disponibilité des horaires PassBi ;
- `feed_route_identity_status` : preuve que le `route_id` est bien la ligne publique affichée ;
- `feed_route_identity_proof` : référence documentaire obligatoire si le statut devient `VERIFIED`.

Le générateur attribue `UNVERIFIED` tant qu'aucune preuve explicite n'est enregistrée. Le validateur refuse un statut inconnu, un statut `VERIFIED` sans référence documentaire, ou une référence associée à un statut non vérifié.

### Conséquence Flutter

- Le catalogue ne fournit plus de libellé public à un `route_id` dont l'identité n'est pas vérifiée.
- La fiche publique d'arrêts exige à la fois un horaire technique exploitable et une identité route ↔ ligne publique vérifiée.
- Les données brutes PassBi, trips, directions, stop_times et le calcul natif des départs ne sont pas supprimés ni réécrits par cette séparation.
- `hasRealSchedule` reste un indicateur de disponibilité horaire technique ; il ne certifie pas l'identité publique.

### État de départ

Les 120 identités publiques présentes dans le référentiel (72 AFTU et 48 DDD) sont explicitement `UNVERIFIED` pour leur association aux routes PassBi. Cela ne signifie pas que les 120 lignes publiques sont inexistantes ou que les horaires du feed sont faux : cela signifie que le dépôt ne contient pas encore de pièce documentaire suffisante pour certifier ces associations.

Aucune permutation de numéro, aucun transfert d'horaire et aucune modification TER/BRT n'ont été effectués. Les variantes DDD lettrées restent distinctes des routes au numéro nu.

### Vérifications à effectuer

- Régénérer le référentiel avec `node scripts/build-public-bus-lines.mjs`.
- Exécuter `node scripts/validate-public-bus-lines.mjs`.
- Exécuter les tests Flutter du référentiel public et des départs natifs.
- Contrôler visuellement qu'un horaire PassBi reste calculable sous son réseau technique, sans être attribué à tort à une ligne publique non vérifiée.

Cette passe modifie le schéma, le garde-fou de libellé et l'accès aux fiches publiques d'arrêts. Elle ne fusionne pas la PR, ne déploie pas l'application et ne publie aucune nouvelle version.


## 16. Correspondances identité ↔ route prouvées — actualisation du 24 novembre 2026

La preuve indépendante est maintenant conservée dans `data/reference/passbi_route_identity_proofs.json`. Le générateur ne certifie une identité que si :
1. le numéro public apparaît dans la publication officielle de l'opérateur ;
2. l'itinéraire officiel et les deux terminus observés dans l'audit du feed concordent ;
3. le `route_id` du feed correspond exactement à celui enregistré dans la preuve ;
4. la référence documentaire est conservée dans `feed_route_identity_proof`.

### Identités vérifiées

**AFTU — 31 lignes :** 2, 3, 5, 25, 30, 32, 33, 34, 35, 37, 39, 40, 42, 44, 46, 49, 51, 54, 60, 62, 67, 70, 71, 73, 75, 76, 78, 80, 82, 83 et 84.

Les pages officielles AFTU consultées le 24 novembre 2026 confirment les itinéraires de ces lignes. Chaque preuve conserve le `route_id`, le `route_long_name` exact, les `stop_id` et noms de terminus observés, ainsi que l'URL officielle. Les lignes 28, 48, 58 et 66 restent non vérifiées lorsque les terminus sont génériques, contradictoires ou ambigus. Les lignes 42 (Gadaye ↔ Ouakam Baye) et 70 (Daroukhane Keur Serigne Assane ↔ Jaxaay 2) ont été ajoutées après concordance des itinéraires officiels avec les terminus partagés ou nommés du feed.

**DDD — 17 lignes :** 1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 121, 208, 227, 232, 233 et 234.

Pour ces lignes, les identités et terminus publiés sur la page officielle « Info voyageurs » concordent avec les métadonnées de route et les terminus relevés dans l'audit du feed. Les variantes DDD 15A/15B, 16A/16B, 502A/502B et 503A/503B ne sont pas incluses.

### Identités qui restent non vérifiées

- **72 lignes publiques** restent `UNVERIFIED` : 41 AFTU et 31 DDD.
- Les AFTU dont les terminus du feed divergent de la liste officielle, les pages AFTU contradictoires, les lignes sans stop_times et les lignes sans preuve suffisante restent non attribuées.
- DDD 15, 16, 501, 502, 503, 504 et les variantes A/B restent non vérifiés lorsque les terminus sont contradictoires, ambigus ou non distingués par le feed.
- Le fait qu'un numéro soit officiellement publié ne suffit pas à certifier le `route_id` correspondant.

### Garde-fous ajoutés

- Le générateur lit le registre explicite ; il n'infère jamais `VERIFIED` par égalité numérique.
- Le validateur contrôle le registre, le `route_id` exact, la référence de preuve et les compteurs.
- Flutter n'affiche un numéro AFTU/DDD dans les départs natifs que si le catalogue a validé cette preuve.
- La recherche peut toujours retrouver les 120 identités publiques, mais ne transmet un `route_id` au moteur de trajet que pour une identité vérifiée.
- La fiche publique d'arrêts exige à la fois `hasRealSchedule` et `hasVerifiedFeedIdentity`.
- Les trips, directions, stop_times et calculs horaires natifs des feeds ne sont ni supprimés ni réécrits.

### Résultat de cette passe

- 48 identités publiques ↔ route PassBi vérifiées (31 AFTU + 17 DDD).
- 74 identités conservées comme non vérifiées.
- AFTU 28, 48, 58 et 66 restent non vérifiées faute de terminus explicites concordants. Aucune permutation de numéros, aucun transfert d'horaire et aucune fusion A/B.
- TER/BRT inchangés ; TATA reste exclu du catalogue public.
- Aucune modification de l'application publiée, aucune fusion et aucun déploiement.

Le générateur et le validateur comparent désormais aussi le `route_long_name` exact du feed avec la preuve, en plus des terminus et des identifiants d'arrêt. Les validations Node et Flutter doivent réussir sur le dernier commit avant de considérer cette étape technique comme validée.
