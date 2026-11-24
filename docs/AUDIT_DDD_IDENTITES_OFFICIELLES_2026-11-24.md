# Audit DDD — identités officielles et raccordement PassBi
Date de vérification : 2026-11-24

## Source officielle consultée

Page « Info voyageurs » de Dakar Dem Dikk :
https://demdikk.sn/info-voyageurs/

La page officielle consultée le 24 novembre 2026 publie explicitement les identités suivantes :

| Ligne publique | Origine | Destination |
|---|---|---|
| 502A | Colobane | UCAD |
| 502B | Colobane | Abass Ndao |
| 503A | Colobane | Môle 8 |
| 503B | Colobane | Hydrocarbure |
| 504A | Gare Diamniadio | Sphère ministérielle |
| 504B | Sébikotane | Gare Diamniadio |
| 15A | Rufisque | Palais 1 |
| 15B | Rufisque | Palais 1 |
| 16A | Malika | Palais 1 |
| 16B | Malika | Palais 1 |
| 327 | Keur Massar | Terminus Parcelles |
| TO1 | Ouakam (rubrique « TAF TAF OUAKAM (TO1) ») | Palais 2 |

La page possède également une rubrique « Lignes TAF TAF » décrivant un service depuis Ouakam vers AIBD et la Sphère ministérielle de Diamniadio. Elle ne publie pas une ligne autonome intitulée simplement « TAF ». Cette différence de libellé doit être conservée : ne pas transformer automatiquement « TAF » en un numéro ou en un alias confirmé.

## Ce que cette vérification confirme

- Les douze identités numérotées ou codées ci-dessus sont bien publiées par DDD.
- Les variantes A/B sont des identités publiques distinctes ; elles ne doivent pas être fusionnées sous le numéro nu.
- Le service TAF TAF comporte des destinations AIBD et Sphère ministérielle ; il ne doit pas être confondu avec TO1, qui est présenté séparément comme « TAF TAF OUAKAM (TO1) ».

## Ce que cette vérification ne confirme pas

La présence d’une identité sur le site DDD ne prouve pas le raccordement à un route_id du flux PassBi.

L’audit du flux disponible trouve des identifiants nus tels que DDD_502, DDD_503, DDD_504, DDD_15 et DDD_16, mais pas de route_id distincts DDD_502A / DDD_502B, etc. Un identifiant nu ne permet pas de choisir sans preuve entre deux variantes A/B. La ligne 327, TO1 et le service TAF TAF ne disposent pas non plus d’un raccordement exact établi dans l’audit actuel.

En conséquence :
- conserver les identités publiques dans le référentiel ;
- conserver leur statut de raccordement NOT_VERIFIED tant qu’une correspondance source exacte n’est pas fournie ;
- ne rattacher aucune variante A/B à une route au numéro nu ;
- ne fabriquer aucun horaire, arrêt, sens ou passage ;
- demander une table de correspondance officielle route publique ↔ route_id PassBi, ou une version du flux dont les identifiants distinguent les variantes.

## Impact sur Dakar Bus

Aucun horaire n’a été modifié par cet audit. Aucun feed_route_id n’a été ajouté. Les règles d’exclusivité PassBi et les horaires TER/BRT validés restent inchangés.

La source officielle est conservée dans la documentation du dépôt uniquement ; son nom ne doit jamais apparaître dans l’interface voyageurs.


## Recoupement des itinéraires publiés — 24 novembre 2026

Une seconde page officielle de l’exploitant a été relue :
https://demdikk.sn/reseau-urbain-dakar/

Elle publie des listes d’arrêts ordonnées pour plusieurs lignes qui permettent de préciser les limites du raccordement :

- **DDD 18 et DDD 20** : deux boucles Dieuppeul–centre-ville–Dieuppeul, avec des séquences d’arrêts différentes. Le feed contient bien `DDD_18` et `DDD_20`, mais chacun ne présente qu’un seul `direction_id`. Le raccordement au numéro de ligne est distinct de la preuve d’un aller/retour : ne pas fabriquer une seconde direction GTFS.
- **DDD 502 et DDD 503** : la page décrit deux boucles distinctes depuis/vers la gare de Colobane. La page « Info voyageurs » distingue cependant 502A/502B et 503A/503B, avec des destinations différentes. Les descriptions de boucle ne démontrent pas quelle variante A/B correspond à quel trajet. Les routes nues `DDD_502` et `DDD_503` restent donc non attribuées aux variantes.
- **DDD 16A et 16B** : les séquences publiées sont différentes. Elles confirment que les deux services ne doivent pas être fusionnés ; le route_id nu `DDD_16` ne suffit pas à identifier l’un ou l’autre.
- **DDD 327** : la séquence d’arrêts est publiée sur cette page et l’identité est également publiée dans « Info voyageurs ». Cela renforce la preuve de l’identité publique, mais aucun `route_id` PassBi `DDD_327` n’est présent dans l’inventaire audité.
- **DDD 501** : les deux pages officielles ne concordent pas sur les terminus. « Info voyageurs » indique Gare de Dakar ↔ Palais 2, tandis que la page des itinéraires indique Palais 2 ↔ Leclerc. La contradiction demeure ouverte ; aucun changement de terminus ni de raccordement n’est autorisé sur cette seule base.
- **DDD 15A/15B** : la page des itinéraires décrit une ligne générique 15, mais ne publie pas deux séquences distinctes A et B. Elle ne permet donc pas de choisir entre les deux variantes officielles.

### Décision de raccordement

Aucun nouveau `feed_route_id` n’est ajouté à la suite de ce recoupement. Les éléments ci-dessus renforcent ou précisent les identités et les limites documentaires, mais ne fournissent pas une table de correspondance exacte entre chaque variante publique et chaque route PassBi.

Les statuts de raccordement du catalogue ne sont pas modifiés. Les quatre routes DDD à direction GTFS unique restent sans direction Aller/Retour inventée. Les horaires, arrêts, identifiants et affichages TER/BRT restent inchangés.

## Recoupement institutionnel complémentaire — guide de mobilité JOJ Dakar 2026

Document consulté le 24 novembre 2026 :
https://www.vie-publique.sn/docs/270ed4e5-ab8f-47b6-9e77-cfd6ed491f02/guide-mobilite-dakar-joj-2026.pdf

Le guide officiel du dispositif de mobilité des JOJ (période annoncée du 31 octobre au 13 novembre 2026) présente une sélection de lignes DDD et AFTU. Il s'agit d'un document de mobilité événementielle ; il ne constitue pas, à lui seul, un référentiel permanent ni une table de correspondance vers les identifiants PassBi.

### Écarts DDD à conserver comme points de vérification

- Le guide décrit **504A** comme « circulaire Diamniadio – Sphères ministérielles », alors que la page « Info voyageurs » consultée le même jour publie « Gare Diamniadio ↔ Sphère ministérielle ». Le guide ne permet pas de conclure que le terminus Gare Diamniadio est supprimé ou remplacé : conserver l'écart documentaire, ne pas modifier le référentiel ni le feed.
- Le guide présente **TAF TAF OUAKAM – VILLE**, tandis que la page « Info voyageurs » décrit les trajets Ouakam–AIBD et Ouakam–Sphère ministérielle, et présente séparément TO1. Ces libellés peuvent relever de périmètres ou de périodes différents ; aucun alias ni fusion n'est établi.
- Le guide événementiel ne fournit pas de preuve de raccordement pour les identifiants DDD nus et les variantes publiques A/B du flux PassBi.

### Recoupement AFTU : sélection événementielle, pas mise à jour du référentiel

Le guide cite notamment les lignes AFTU 1, 2, 3, 4, 5, 24, 25, 27, 28, 29, 34, 38, 40, 41, 46, 48, 50, 54, 55, 58, 62, 71 et 82, avec certains terminus. Plusieurs descriptions ne concordent pas avec la liste actuelle affichée sur la page officielle AFTU « Infos pratiques ». Exemples relevés :

| Ligne | Guide de mobilité JOJ | Liste AFTU « Infos pratiques » |
|---|---|---|
| 46 | Guédiawaye – Lat Dior | Lat-Dior – Almadies |
| 50 | Cité APIX – Petersen | Jaxaay – Gare des Baux Maraîchers |
| 55 | Rufisque – Petersen | Jaxaay 2 – Petersen |
| 58 | Comico Yeumbeul – Sahm | Diamalaye – Cité Gendarmerie (Jaxaay) |
| 62 | Rufisque – Guelle Tapée | Arrêt Chérif (Rufisque) – Penc Mi (Gueule Tapée) |
| 82 | Comico Yeumbeul – Lat Dior | Rufisque Arafat – Zone de Captage |

Ces différences sont consignées comme **écarts entre une sélection événementielle et la liste générale consultée**, et non comme preuve d'une erreur de l'une des sources. Le guide peut refléter des dessertes mobilisées ou adaptées pour les Jeux. Il ne faut donc ni remplacer les terminus du référentiel AFTU par ceux du guide, ni en déduire un raccordement PassBi nouveau.

### Décision technique

- Aucune modification des identités canoniques AFTU/DDD sur la seule base de ce guide.
- Aucun nouveau raccordement route_id PassBi.
- Aucun changement d'arrêt, d'horaire, de fréquence ou de direction.
- Les éléments du guide sont conservés comme preuve contextuelle datée, à rapprocher d'une confirmation permanente des opérateurs.
- Les pages et documents sources restent strictement dans la documentation du dépôt ; aucune mention de source ne doit apparaître dans l'interface voyageurs.


## Contrôle du catalogue embarqué : lignes nues 15, 502 et 503 — 24 novembre 2026

Le contrôle du référentiel généré `data/reference/public_bus_lines_dakar.json` révèle trois entrées DDD au numéro nu qui doivent être distinguées des variantes actuellement affichées dans « Info voyageurs » :

| Entrée du référentiel embarqué | Identité publiée dans « Info voyageurs » | Route PassBi actuelle | Observation |
|---|---|---|---|
| DDD 15 — Rufisque ↔ Palais 1 | 15A et 15B — Rufisque ↔ Palais 1 | `DDD_15` | La page des itinéraires décrit une ligne 15 générique, mais ne démontre pas la correspondance de `DDD_15` avec chacune des variantes A/B |
| DDD 502 — origine/destination générées « GARE DE GARE » | 502A — Colobane ↔ UCAD ; 502B — Colobane ↔ Abass Ndao | `DDD_502` | La page des itinéraires décrit une boucle 502, mais ne prouve pas qu'elle représente les deux variantes publiées |
| DDD 503 — origine/destination générées « GARE DE GARE » | 503A — Colobane ↔ Môle 8 ; 503B — Colobane ↔ Hydrocarbure | `DDD_503` | La page des itinéraires décrit une boucle 503, mais ne prouve pas qu'elle représente les deux variantes publiées |

La page « Info voyageurs » distingue explicitement les variantes A/B. La page des itinéraires présente des parcours génériques 15, 502 et 503. Ces deux présentations ne fournissent pas la correspondance exacte entre les identités publiques et les routes du feed. Le libellé « GARE DE GARE » présent dans les deux entrées du référentiel n'est pas un terminus public exploitable et ne doit pas être présenté comme tel.

### Décision
- Ne pas interpréter `DDD_502` comme 502A **et** 502B ; même interdiction pour `DDD_503` et les variantes 503A/503B.
- Ne pas fusionner `DDD_15` avec 15A/15B.
- Ne pas considérer les valeurs « GARE DE GARE » comme des terminus validés.
- Conserver les identités A/B distinctes et leur statut non vérifié tant qu'une correspondance explicite n'est pas disponible.
- Ne pas modifier les horaires PassBi, ne pas inventer de lignes ou de directions, et ne pas modifier l'interface par cette note.

**Anomalie à traiter avant validation finale du catalogue :** les entrées génériques 15/502/503 et leurs libellés doivent être réconciliés avec les identités publiques actuelles. Cette note ne tranche pas si les lignes génériques sont des services additionnels, des désignations historiques ou des libellés incomplets.
