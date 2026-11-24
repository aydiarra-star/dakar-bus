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
