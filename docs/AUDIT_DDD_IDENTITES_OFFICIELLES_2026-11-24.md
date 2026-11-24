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
