# Dakar Bus — reprise de correction TER / BRT

**21 septembre 2026 — LIVRAISON PARTIELLE, PAS DE CORRECTION VISUELLE DÉPLOYÉE.**

## 1. Sauvegarde et périmètre

- Accord utilisateur reçu après diagnostic initial, avec captures IMG_6478.png et IMG_6477.png.
- Point de sauvegarde : commit `e64686c`, parent `c3bbd0f`.
- Travail exclusivement sur `arena/01a0c2cd-dakar-bus`.
- Interface, navigation, couleurs, boutons, filtres et fichiers compilés de production laissés intacts.
- Aucune nouvelle gare, station, coordonnée ou géométrie inventée.

## 2. Découverte déterminante : deux applications distinctes

L'API GitHub Pages indique :

- URL : https://aydiarra-star.github.io/dakar-bus/
- source : branche `gh-pages`, dossier `/`, mode `legacy` ;
- commit de l'arbre distant audité : `94a84b6070569bed708b8e779b9e70b7c9dafa45`.

Cet arbre contient `index.html` (chargeur Flutter), `main.dart.js`, les ressources Flutter et `assets/assets/data/dakar_network.json`. Aucun `.dart` ni `pubspec.yaml` n'y figure. Les arbres des branches examinées et un ancien build Flutter ne contiennent pas non plus ces sources. Cela ne prouve pas qu'elles n'existent dans aucun autre dépôt : il faut retrouver le projet de compilation.

La branche de cette session, issue de `main`, contient une PWA HTML/Leaflet. Le précédent correctif et son test contrôlaient cette PWA, pas l'application visible dans les captures. **Fusionner une correction de la PWA ne met pas à jour le Flutter actuellement servi par Pages.** Il ne faut pas changer Pages pour publier la PWA : cela remplacerait l'interface utilisateur, contrairement au cahier des charges.

## 3. Cause du surnombre localisée dans le compilé (lecture seule)

### Initialisation Flutter

- `aCz` construit **12 objets de démonstration TER** ; certains représentent un même lieu dans deux directions. Ils incluent encore « Gare TER Keur Massar ».
- `aCq` construit **6 objets de démonstration BRT**.
- `di` assemble les listes de démonstration.
- `aW7` ajoute ensuite des objets `cg` provenant des lignes et arrêts du JSON à cette liste globale déjà remplie.
- La clé de dédoublonnage est une concaténation **nom + latitude + longitude**, pas l'identifiant de gare physique. Des noms différents pour le même lieu restent distincts.
- Le modèle JSON compilé `dA` ne lit que id/name/latitude/longitude/data_trust. Ajouter `network`, `source` ou un statut dans le JSON seul ne suffit donc pas à corriger les filtres ou les informations affichées.

Les captures montrent **24 TER** et **29 BRT**. Ces valeurs ne sont pas des effectifs officiels. La présence de ces listes et leur concaténation est vérifiée dans le programme ; le nombre final en navigateur n'a pas été remesuré dans cette session. Ne pas présenter 12+13 comme une égalité à 24 : il y a aussi un dédoublonnage lors de l'import.

### Données publiées

- Ligne TER : 13 identifiants de gares dans le JSON ; **11** de ces identifiants sont aussi utilisés par des lignes DDD/AFTU/TATA.
- Lignes BRT : 23 identifiants physiques distincts, y compris l'union B1/B2.
- **11 autres entrées** contiennent « BRT » dans leur nom mais ne figurent pas dans les lignes BRT. Certaines sont référencées par des bus : ne pas les supprimer aveuglément.
- Les noms, coordonnées, sources, appartenances réseau et correspondances de ces objets doivent être revus. Pas de clonage artificiel de gare TER pour fabriquer un arrêt bus adjacent.

Liste complète des identifiants litigieux et résultats reproductibles : [audit JSON](audit-pages-2026-09-21.json).

### Tracés

Les fichiers publiés `ter_rail_shapes.json` et `brt_dedicated_shapes.json` indiquent `source_kind: secours-consecutif`. Les outils historiques relient les gares consécutives par des segments droits. Le compilé comporte également un repli de routage `[départ, arrivée]`. Ces mécanismes ne sont **pas une géométrie ferroviaire/BRT vérifiée**.

Dans la PWA, les 13 arrêts TER et 23 BRT sont tous des sommets exacts des polylignes internes (57 et 48 sommets). L'ancien « écart maximal 0 m » ne démontrait donc rien sur le corridor réel. Le seuil de l'ancien test était 600 m.

## 4. Référentiel retenu et limites

- TER : 13 gares sur le périmètre Dakar–Diamniadio. Sources : https://sentersa.sn/plan-de-transport/ et https://www.terdakar.sn/acceder-au-plan-de-la-ligne/
- BRT : 23 stations sur le corridor complet. Sources : https://www.sunubrt.sn/quest-ce-quun-brt/dakar-mobilite/ et annonce de réouverture complète du 29 décembre 2025 : https://www.sunubrt.sn/toutes-les-stations-du-reseau-sunubrt-sont-maintenant-operationnelles/
- La page https://www.sunubrt.sn/brt-1-omnibus/ mentionne encore 21 stations : documentation contradictoire conservée dans le diagnostic, pas prise comme une donnée temps réel.
- Liste BRT à recouper avec https://www.sunubrt.sn/fermeture-temporaire-de-certaines-stations-sunubrt-ce-quil-faut-savoir/ : Liberté 4 est citée, Ndinguela diffère de « Ndingala ».
- Liste TER : Dalifort/Mbao et Keur Mbaye Fall/Keur Massar nécessitent un recoupement des plans opérateur ; pas de remplacement automatique.

**Coordonnées incorrectes : nombre inconnu. Gares hors rail et stations hors corridor réel : nombres inconnus.** Les géométries et coordonnées fiables n'ont pas été obtenues. Les téléchargements directs vers les sites opérateurs ont échoué dans cet environnement ; les pages textuelles sont consultables mais ne constituent pas un export géographique. Une requête Overpass a retourné une erreur serveur. Aucune coordonnée n'a été déduite de ces échecs.

## 5. Modifications réalisées

| Fichier | Correction / ajout |
|---|---|
| `data/gtfs/trips.txt` | Deux destinations BRT inversées corrigées, selon les séquences existantes : 001 vers Guédiawaye ; 002 vers Petersen. Affecte la PWA seulement. |
| `scripts/check-arrets.js` | Remplace le résultat trompeur « CONFORME » par un audit strict ; compare noms ET coordonnées ; contrôle références, séquences, horaires et provenance. |
| `scripts/lib/transit-validation.js` | Validateurs purs de doublons, coordonnées, réseau, ordre aller/retour, statuts, source et distance au tracé. Aucun générateur d'arrêt. |
| `scripts/lib/pages-audit.js` | Analyse du JSON et des signatures du compilé, sans exécuter ni modifier celui-ci. Si signature inconnue, audit bloqué, pas de succès silencieux. |
| `scripts/audit-pages.js` | Audit en lecture seule du déploiement réellement configuré dans Pages. Tous les fichiers sont lus au même SHA Git. |
| `data/transit/reference-policy.json` | Périmètres, effectifs attendus, sources et inconnues. **Ce n'est pas encore le référentiel de stations demandé.** |
| `tests/transit-validation.test.js` | 24 tests, données synthétiques isolées dans les tests uniquement. |
| `package.json` | Sépare tests unitaires et validation des données, ajoute l'audit Pages et le hook `prebuild`. |
| `.github/workflows/transit-validation.yml` | Tests et contrôle strict des données sur PR. Doit rester rouge tant que les données réelles ne satisfont pas les critères. Aucun déploiement. |
| `README.md`, `CORRECTIF_ARRETS_TER_BRT.md` | Avertissement : anciennes affirmations de conformité non valables pour la production Flutter. |
| `docs/` | Rapport et audit machine de l'application réellement publiée. |

Données supprimées : **aucune** (les horaires `_003` orphelins sont signalés, pas transformés en trajets inventés).

Données corrigées : **deux destinations GTFS BRT**.

Données ajoutées : **aucune station, aucune coordonnée, aucun tracé** ; uniquement politique de validation et constats d'audit.

Le seuil technique de distance est 100 m, paramétrable et non présenté comme une règle officielle. La provenance indépendante reste indispensable même si tous les points se trouvent sur la polyline. Les avertissements `TER_STOP_OFF_ROUTE`/`BRT_STOP_OFF_ROUTE` bloquent la validation de livraison.

## 6. Tests effectivement exécutés

| Test | Résultat |
|---|---|
| `npm test` | **24/24** tests unitaires réussis. Ne certifie pas les données de production. |
| `npm run validate:data` | **ÉCHEC attendu**, données réelles non conformes : sources, réseaux, directions, ordre explicite et géométries non vérifiés ; 36 références d'horaires à des trajets `_003` absents de `trips.txt`. |
| `npm run prebuild` | **BLOQUÉ** par le même contrôle, pas de faux succès. |
| `node scripts/audit-pages.js docs/audit-pages-2026-09-21.json` | **ÉCHEC attendu**, défauts de la production identifiés, `releaseReady: false`. |
| Code syntaxique / diff Git | Vérifié. |
| Test TER/BRT réel dans le navigateur | **Non effectué**. Captures utilisateur utilisées comme preuve du symptôme, pas comme validation après correction. |
| Vérification visuelle rail/corridor | **Non effectuée**, pas de géométrie indépendante vérifiée. |
| Explorer / Trajets / Alertes / Réglages / IA / GPS / recherche | **Non revalidés en navigateur** ; aucun fichier d'interface modifié. |

Le projet n'avait pas de commande `build` ni de projet Flutter compilable. Le hook `prebuild` s'applique à une future commande npm build ; il ne prétend pas intercepter `flutter build`. Le contrôle CI est la barrière actuellement ajoutée. Le pipeline Flutter devra appeler le validateur après récupération des sources.

## 7. Ce qu'il faut pour terminer sans remplacer l'interface

Récupérer le **projet Flutter ayant produit l'application des captures** : `pubspec.yaml`, `lib/`, `assets/`, `web/` et le fichier de verrouillage, sans clés ni identifiants secrets. Un ZIP du projet ou le dépôt GitHub où il se trouve suffit.

Ensuite, correction ciblée dans ses sources :

1. Remplacer la concaténation démo+référentiel par une seule liste de gares/stations physiques, avec identifiants stables.
2. Séparer départs, horaires et directions de la notion d'arrêt physique ; aucun doublon de gare pour un retour.
3. Charger réseau/ordre/source/statuts depuis le référentiel, pas depuis un nom ni un préfixe ni la proximité.
4. Vérifier chaque coordonnée et nom avec des sources documentées ; conserver `UNKNOWN` quand la preuve manque.
5. Remplacer les tracés de secours par des géométries sourcées ou ne pas les présenter comme exactes ; interdire le repli routier/segments droits pour le TER/BRT.
6. Supprimer les positions simulées et informations imminentes non justifiées, sans supprimer les écrans.
7. Exécuter les six scénarios de recette sur le vrai build Flutter, puis publier ce build via le circuit GitHub Pages existant.

## 8. GitHub

Point de sauvegarde créé avant modification. Ces travaux sont destinés à une **PR brouillon**, pas à un déploiement déclaré conforme. Aucun push vers `main` ou `gh-pages`, aucun remplacement de l'application en production, aucune demande de mot de passe/token.

**Les 12 conditions de fin ne sont pas satisfaites. Ce rapport ne présente pas le problème comme résolu.**
