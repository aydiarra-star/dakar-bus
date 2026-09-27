# Lot 4.14D — Inventaire des ETA réellement calculables (27 septembre 2026)

## Verdict par mobilité, à partir des données **livrées à l'application**

| Mobilité | Donnée présente et preuve | ETA possible actuellement ? | Exemple / limite |
|---|---|---|---|
| TER | [Opérateur](https://www.terdakar.sn/les_horaires_des_trains/) : départ du **terminus** Dakar 05:45 et Diamniadio 05:35, toutes les 10 min L–S jusqu'à 20:55, puis 21:05–22:05 toutes les 20 min ; dimanche/fériés 06:25–22:05 toutes les 20 min. `FrequencyProvider` porte ces plages ; `dakar_network.json` lie la ligne aux terminus `stop_dakar_ter` et `stop_diamniadio`. Le registre `data/transit/validated/schedule_registry.json` a 48 départs dimanche Dakar seulement `PARTIALLY_CONFIRMED`, 576 autres stop_times `UNCONFIRMED`. | **OUI, uniquement aux terminus explicitement ancrés** : Dakar L–S, dimanche/férié ; Diamniadio L–S. | Dakar lundi 13:29 → 13:35 = `🟢 6 min` (premier départ 05:45 + 47 × 10 min). Pas de passage calculable aux 11 autres gares, pas d'ancrage Diamniadio dimanche. Pas de statut `SCHEDULED` ni de `trip_id` reconstruit : ETA `ESTIMATED`/`COMBINED` provenant de l'heure du premier départ publiée **et** d'une cadence ancrée. |
| BRT B1 | `FrequencyProvider` : 6 min semaine, 10 puis 7 min dimanche ; structure 23 stations dans le JSON ; `data/transit/validated/structure/brt_route_structure.json` : ordre partiel historique. `data/gtfs/` contient deux trips BRT_01 synthétiques, **non validés**. | **NON** | Aucun premier passage daté/horodaté à une station et à un sens ; ni passages observés ni position véhicule ; 6 min ≠ prochain départ dans 6 min. |
| BRT B2 | Fréquence opérateur 6 min L–S ; 7 stations confirmées, distinctes de B1. | **NON** | Aucun ancrage de passage, horaire par station, calendrier de trips utilisable ou flux temps réel. La structure B2 ne donne pas l'heure. |
| BRT B3 | Identité/7 stations sur source opérateur et registre transit ; **route B3 absente de l'asset réseau de l'application**. | **NON** | Ni route exposée, ni départ précis, historique ou flux. Ne pas emprunter la cadence B1/B2. Ajout de la mobilité aux données de production requis dans un lot autorisé séparément. |
| DDD | Routes indicatives dans le JSON ; registre transit : 53 routes PassBi historiques, 34 persistantes, mais aucun `stop_time` courant validé par arrêt. | **NON** | Il manque des passages horodatés liés route→trip→stop, un calendrier valide, ou une observation de véhicule et un modèle de trajet vérifiable. |
| AFTU | Routes indicatives dans le JSON ; données PassBi de niveau structurel et annuaire des lignes, sans temps de passage validé. | **NON** | Aucune heure de passage ni observation exploitables par arrêt et sens, aucun flux temps réel. |
| Nouvelle mobilité | Le chemin `DataService`→`ScheduleEngine`→`DepartureInfo` accepte un dataset horaire sourcé injecté pour **n'importe quel identifiant**. | **Seulement lorsqu'une donnée horaire exploitable est réellement intégrée.** | Test synthétique explicitement marqué *fixture*, non livré comme donnée opérateur. |

**Attention à la portée TER :** la phrase opérateur associe explicitement le premier départ à chaque terminus L–S et annonce une cadence jusqu'au dernier départ. C'est un ancrage temporel à ces terminus seulement ; appliquer la même cadence aux gares intermédiaires exigerait un décalage/temps de trajet vérifié. Le dimanche, seul Dakar est rapproché du registre auditée ; aucune heure au terminus inverse n'est affirmée. Une annonce de fréquence isolée, telle que celle de BRT B1/B2, ne fixe pas sa phase.

`data/transit/validated/gtfs/` contient **48 trips et 624 stop_times**, mais pour le seul calendrier `2026-09-27` ; 576 stop_times intermédiaires ne sont pas confirmés. Les sources PassBi n'ont pas de licence de redistribution clarifiée (`data/transit/MANIFEST.json`). Ils ne sont ni promus au statut `SCHEDULED`, ni copiés dans un asset public, ni prolongés à une autre date. `data/gtfs/` est un jeu PWA synthétique (72 stop_times pour quatre trips), pas un flux TER/BRT d'opérateur. `flutter-src/pubspec.yaml` ne livre qu'un asset réseau, **aucune grille GTFS** ; le `ScheduleProvider` de production reste vide, le `RealtimeProvider` aussi.

## Chemin technique de « Passage non communiqué »

`Stop.departureInfoAt` → `DataService.departureFor` → recherche de grille `ScheduleEngine` **si une grille sourcée est injectée** → sinon `FrequencyProvider` (ou `UNKNOWN` si arrêt/ligne inconnus). Le provider TER ne calcule désormais une ETA `COMBINED` **que pour le terminus ancré**. `EtaCalculator.fromDepartureInfo` renvoie `null` lorsque l'heure cible manque, a expiré ou vient d'une simple fréquence. `DeparturePresentation.at` rend alors « Passage non communiqué », de couleur neutre. `StopCard`, `TripsPage` et `AssistantReplies` utilisent cette même présentation. Elle n'est remplacée ni par une heure fictive ni par un incident.

Audit des champs hérités : `info.label` n'alimente aucune vue ; `departureTime` reste un champ interne de segment, **non utilisé pour son libellé** ; `frequencyMinutes` et `estimatedWaitFrom/To` décrivent une fenêtre mais ne donnent aucune ETA sans ancrage ; « Horaire indisponible » et « Passage estimé dans 0–20 min » ne sont pas générés dans l'affichage des départs. Rouge exige une preuve opérationnelle sourcée, jaune une prédiction fraîche comparée à l'horaire réel ; la source du calcul et la couleur ne se déduisent jamais l'une de l'autre.

## Suite requise pour la couverture totale

1. Obtenir de chaque opérateur une grille par arrêt/sens/trip et calendrier courant **avec couverture/provenance vérifiable**, ou un flux de prédictions véhicules fraîches reliées aux mêmes identifiants.
2. Valider droit de redistribution et fraîcheur des sources ; ne pas utiliser les jeux synthétiques ou les 576 stop_times TER non confirmés comme horaires actuels.
3. Brancher ensuite ces sources sur `ScheduleProvider`/`RealtimeProvider` existants ; ne pas créer un calcul horaire dans les widgets ni promouvoir une fenêtre de fréquence en trip.

Aucun changement à `data/gtfs/`, `data/transit/`, `dakar_network.json`, GPS ou cartographie dans ce lot.
