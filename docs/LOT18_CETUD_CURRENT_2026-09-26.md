# LOT 18 BIS — Feed CETUD CURRENT (AFTU, DDD) : recherche, verdict, intégration prête

Date de recherche : **2026-09-26** (Europe/Paris). Branche : `arena/01a0dc17-dakar-bus`.
Contexte : les LOT 16 BIS / 17 / 18 précédents ont été perdus avec le bac à sable (seuls les fichiers
non versionnés de l'audit LOT 16 BIS ont survécu). Ce lot **reconstruit en version allégée** la couche
GTFS externe (lecture directe des ZIP bruts, aucune extraction versionnée) et la prépare à recevoir le
feed officiel CETUD dès qu'il sera obtenu.

Principe absolu : **rien d'inventé, rien de déduit**. Aucune URL, ligne, arrêt, direction ou horaire
n'est fabriqué ; aucune donnée PassBi n'est requalifiée en donnée CETUD ; les dates internes des feeds
ne sont jamais modifiées ; aucune fréquence n'est convertie en heure.

---

## §1 Recherche effectuée (2026-09-26)

Pages et interfaces publiques vérifiées (aucune authentification, aucun contournement) :

| Source | Ce qui a été vérifié | Résultat |
|---|---|---|
| https://cetud.sn/observatoire/systeme-de-donnees/ | page complète (3 blocs de contenu) | Prose : « FICHIER GTFS… numérisation… opendata… applications mobiles » **sans aucun lien de téléchargement** ; données d'exploitation « hors SAE » via CAPTRANS/enquêtes ; publications = PDF uniquement (fiche projet RTC 23/09/2025, brochures 2018/BRT, bulletins 2016–2018) |
| cetud.sn — WP REST `wp-json/wp/v2/search?search=gtfs` | index du site | `[]` (aucun contenu) |
| cetud.sn — WP REST `search=open data` | index du site | billets sans rapport (CODATU 2020, Études, PAMUS) |
| cetud.sn — médiathèque | types de médias | images et PDF uniquement, aucun ZIP/GTFS |
| cetud.sn — pages AFTU / DDD (« Télécharger ») | liens de téléchargement | `uploads/2024/11/plan-lignes-aftu.jpeg` et `plan-lignes-ddd.jpeg` : **images de plans**, pas de données |
| https://aftu-senegal.org/infos-pratiques/ et `/map/dakar-urbain-ligne-30/` | site opérateur | listes de lignes et cartes Waymark (itinéraire en liste de rues, longueur 0,00 km), **aucun horaire, aucun fichier** ; page d'accueil = démo de thème WordPress |
| https://demdikk.sn/ | site opérateur | « Info voyageur ligne 01 » (premiers/derniers départs 5h30/20h30 et 6h30/21h) en texte, **aucun jeu de données** ; page contenant des liens indésirables |
| PassBi — dépôt public `impactsolutionsas/passbi_core` (HEAD `4de3d96`, 2026-03-29) | ZIP GTFS | inchangés depuis le commit du 2026-02-10 (blobs identiques au manifeste d'audit) ; API de production suspendue ; texte Play Store « GTFS centralisés par le CETUD » **sans URL** ; « Official partner of CETUD » sur senpassbi.com **non vérifié** |
| Mobility Database, Transitland Atlas, DT4A, TUMI Datahub | registres GTFS | aucun feed Sénégal/Dakar |
| captrans.sn | site institutionnel | aucune donnée publiée |
| cetud.dakeos.com (ancien portail) | portail hérité | injoignable ; extraits indexés = plans et application AFTU, pas de feed |
| data.gouv.fr (« GTFS Dakar ») | open data | résultats hors sujet (Monaco) ; le feed « DAKK » = Szeged (Hongrie) |
| GitHub code search (« dakar gtfs », « cetud gtfs ») | dépôts publics | 0 résultat exploitable (index non fiable, non utilisé comme preuve) |

## §2 Sources officielles identifiées

- **CETUD — Observatoire de la mobilité** (autorité organisatrice) : `observatoire@cetud.sn`, `cetud@cetud.sn`,
  +221 33 859 47 20, Route du Front de Terre, Ex immeuble TP SOM, Hann, Dakar. Page :
  https://cetud.sn/observatoire/systeme-de-donnees/ (« Contacter l'observatoire »).
- **AFTU** (opérateur, siège Zone de captage, +221 33 859 02 88) : pas de données horaires publiées.
- **Dakar Dem Dikk** (opérateur, réservation 33 824 10 10) : pas de données horaires publiées.
- **CAPTRANS** (`captrans@captrans.sn`, +221 33 877 60 38) : cité par le CETUD pour les données hors SAE ; aucune publication.

## §3 Feed trouvé ou non — VERDICT

> **CETUD CURRENT : NON RÉCUPÉRABLE PUBLIQUEMENT** (au 2026-09-26).

- Aucune URL publique de feed GTFS CETUD (AFTU ou DDD) n'existe sur les pages vérifiées ; aucune
  version, date de publication, validité ou licence n'a pu être constatée.
- **Mécanisme officiel** : demande écrite à l'Observatoire de la mobilité du CETUD (adresses ci-dessus).
- **Données et format demandés** : archives ZIP GTFS statique **AFTU** et **DDD** contenant
  `agency.txt`, `routes.txt`, `stops.txt`, `trips.txt`, `stop_times.txt`, `calendar.txt`,
  `calendar_dates.txt`, `shapes.txt` et `feed_info.txt` (avec `feed_version`, `feed_start_date`,
  `feed_end_date`, éditeur, licence de réutilisation), ainsi que la date de publication officielle.
- Le projet est **prêt à recevoir le fichier** : installateur strict, validation, manifeste, SHA-256,
  validité, provider `currentOfficial` (voir §7 et `data/external/gtfs/cetud/README.md`).

## §4 AFTU — feed CETUD

| Élément | Valeur |
|---|---|
| Statut | **NON TROUVÉ** |
| URL | aucune (non publiée) |
| Version / publié le / validité | inconnus |
| SHA-256 | — |
| routes / stops / trips / stop_times | — |

## §5 DDD — feed CETUD

| Élément | Valeur |
|---|---|
| Statut | **NON TROUVÉ** |
| URL | aucune (non publiée) |
| Version / publié le / validité | inconnus |
| SHA-256 | — |
| routes / stops / trips / stop_times | — |

## §6 Validation GTFS (moteur reconstruit)

Moteur Node : `lib/external-gtfs/` (`zip-reader.js`, `gtfs-csv.js`, `gtfs-time.js`, `provenance.js`,
`models.js`, `gtfs-feed-loader.js`, `gtfs-schedule-service.js`, `frequency-source.js`,
`transit-data-provider.js`, `schedule-assistant.js`, `feed-layers.js`, `index.js`).

- Lecture **directe des ZIP bruts** (répertoire central, inflate, **CRC-32 vérifié** par entrée, SHA-256 de
  l'archive) : aucune extraction sur disque, aucun `.txt` versionné.
- CSV tolérant : délimiteur détecté **séparément pour l'en-tête et le corps** (les `calendar_dates.txt`
  PassBi AFTU/DDD ont un en-tête `service_id;date;exception_type` et des lignes séparées par `,`).
- Contrôles bloquants (erreurs) : tables requises (`agency`, `routes`, `stops`, `trips`, `stop_times`,
  `calendar` ou `calendar_dates`), colonnes obligatoires, références orphelines (trip→route, trip→service,
  stop_time→trip, stop_time→stop), heures non conformes (`INVALID_TIME`), absence totale d'heures, tables vides.
- Contrôles non bloquants (avertissements) : courses sans stop_times, `stop_sequence` dupliqués, heures non
  croissantes le long d'une course (`TIME_ORDER`), `direction_id` hors {0,1}, `route_short_name` absent,
  anomalies de calendrier.
- Résultats **réels** sur les ZIP PassBi (HISTORICAL) :

| Réseau | routes | stops | trips | stop_times | services | shapes | validité interne | validation |
|---|---|---|---|---|---|---|---|---|
| AFTU | 73 | 2 401 | 11 077 | 677 918 | 4 (`FULL`, `LAV` –20 dates, `SAMEDI`, `DIMANCHE` +20 dates) | 144 (9 498 pts) | 2022-01-01 → 2023-12-31 | ok ; avertissements `TRIPS_WITHOUT_STOP_TIMES: 738`, `DUPLICATE_STOP_SEQUENCE: 289 trip(s)`, `TIME_ORDER: 109 trip(s)` |
| DDD | 53 | 1 277 | 9 529 | 314 029 | 4 | 102 (3 500 pts) | 2022-01-01 → 2023-12-31 | ok ; `TRIPS_WITHOUT_STOP_TIMES: 333`, `TIME_ORDER: 8 trip(s)` |
| BRT | 2 | 79 | 4 036 | 58 674 | 7 (calendar_dates uniquement) | 35 (6 785 pts) | 2024-10-24 → 2024-12-31 | ok |
| TER | 6 | 26 | 572 | 7 332 | 12 | 0 | 2025-08-18 → 2025-08-31 | ok ; `TIME_ORDER: 1 trip(s)` |

Performances mesurées (lecture directe du ZIP AFTU de 10,7 Mo) : ≈ 1,4 s, ≈ 110 Mo de tas.

## §7 Provider — quelle source gagne

`TransitDataProvider` (Node et miroir Dart) : ordre de priorité
**CETUD CURRENT (currentOfficial, autorité CETUD) → autre source officielle actuelle → PassBi CURRENT si
réellement prouvé (currentApplication) → open data actuelle → fréquence documentée (ESTIMATED) → UNKNOWN**.

Règles vérifiées par les tests : une source déclarée `HISTORICAL` ne peut recevoir qu'un rôle
`historicalReference` (toute autre tentative lève une exception) ; `currentOfficial` exige un statut
déclaré `CURRENT` **et** une source institutionnelle ; la validité est recalculée à chaque requête (un feed
expiré donne `UNKNOWN`, jamais une heure) ; les sources historiques ne participent jamais à une réponse
« maintenant » (`getHistoricalDepartures` est une consultation explicite, marquée `HISTORICAL_REFERENCE`).

État réel au 2026-09-26 (`npm run gtfs:check`) :

```
[passbi] layer_status=INSTALLED_NOT_CURRENT — 4 ZIP, SHA-256 vérifiés, aucune source actuelle
[cetud]  layer_status=ABSENT
AFTU : source actuelle = AUCUNE → UNKNOWN
DDD  : source actuelle = AUCUNE → UNKNOWN
```

Couche CETUD prête : `scripts/gtfs/install-cetud-feed.js` (copie du ZIP **inchangé** dans
`data/external/gtfs/cetud/{aftu,ddd}/`, SHA-256 avant/après, validation bloquante, `valid_from`/`valid_to`
lus dans `feed_info.txt` sinon dans le calendrier, `status: CURRENT` + `role: CURRENT_OFFICIAL` **uniquement**
si la validité couvre la date d'installation, qu'une publication est prouvée (`--published-at`) et que
l'origine est documentée (`--url` ou `--origin`) ; sinon `status: UNKNOWN`, `role: REFERENCE_GTFS`).
Manifeste : `feed-manifest.json` (schéma `dakar-bus/external-gtfs-feed-manifest/v1`, champs `source`,
`source_type`, `status`, `role`, `network`, `zip`, `sha256`, `size_bytes`, `version`, `valid_from`,
`valid_to`, `published_at`, `retrieved_at`, `url`, `license` — valeurs prouvées uniquement, `null` sinon).
Contrôle : `npm run gtfs:cetud:check` (`ABSENT` | `CURRENT_INSTALLED` | `INSTALLED_NOT_CURRENT` | `INVALID`).
Un ZIP dont le SHA-256 diffère du manifeste n'est **jamais** enregistré.

## §8 Assistant IA

Chemin unique : Question → `parseScheduleQuestion` (réseau, numéro de ligne, arrêt, date/heure explicites,
direction) → `TransitDataProvider` → source CURRENT → `stop_times` → phrase.

- Numéro de ligne lu **uniquement** dans `route_short_name` ; les codes internes (ex. `A30CG` chez PassBi) ne
  sont jamais traduits en numéro ; les variantes DDD (`16` / `16A`) restent distinctes.
- Phrase trouvée (fixture synthétique) :
  `La ligne AFTU 30 dessert cet itinéraire. Depuis l'arrêt Yeumbeul TEST, le prochain départ programmé est à 07:42. Direction Fixture C. Source : CETUD (OFFICIAL_STATIC_CURRENT, validité 2026-01-01 → 2026-12-31).`
- Repli LOT 18 BIS (aucune source actuelle, arrêt hors ligne, plus de départ) :
  `Je n'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis.`
- Repli LOT 18 (ligne connue par une référence historique, aucune source actuelle) :
  `Je connais la ligne, mais je n'ai pas actuellement d'horaire suffisamment fiable pour annoncer un départ précis.`
- Fréquence documentée : statut `ESTIMATED` sans heure (« un passage est annoncé environ toutes les N minutes … »
  suivi du repli exact) — aucune fréquence n'est embarquée par défaut.
- Application Flutter : `flutter-src/lib/services/external_gtfs/` (miroir Dart), `cetud_feed_bootstrap.dart`
  appelé dans `main()` ; dans `_sendMessage()` la branche horaire est évaluée **avant** les branches
  TER/BRT/DDD/TATA/AFTU (après la détection d'itinéraire). Aucune modification d'interface. Aucun asset
  ajouté : sans manifeste embarqué, la couche est `ABSENT` et l'assistant répond par le repli exact.

## §9 PassBi — HISTORICAL / REFERENCE_GTFS conservé

`data/external/gtfs/passbi/feed-manifest.json` référence les 4 ZIP bruts **sans les copier** :

| Fichier | Taille | SHA-256 |
|---|---|---|
| `audit/external-feeds/source/passbi_core/gtfs_folder/gtfs_AFTU.zip` | 10 693 791 o | `7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428` |
| `…/gtfs_Dem_Dikk.zip` | 2 635 299 o | `578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159` |
| `…/gtfs_BRT.zip` | 520 189 o | `f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4` |
| `…/gtfs_TER.zip` | 109 650 o | `09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408` |

`source: PassBi`, `source_type: SOURCE_APPLICATION`, `status: HISTORICAL`, `role: REFERENCE_GTFS`,
`published_at: 2026-02-10` (date du commit public, qui ne prouve pas l'actualité du service), `license: null`.
Usage : fixture, comparaison, développement ; **jamais** un départ actuel, jamais présenté comme actuel,
jamais promu automatiquement. Exemple de consultation historique explicite (test 4) : ligne `AFTU_30`
(`A30CG`) à l'arrêt `A_1564` « Colobane » le 2023-03-15 à 07:40 → `07:47:45`, `08:00:45`, `08:13:45`
(niveau `HISTORICAL_REFERENCE`) ; la même requête pour 2026-09-26 → `NO_SERVICE_ON_DATE` ; via le provider
« actuel » → `UNKNOWN` même pour une date couverte par le feed.

## §10 Données non modifiées

Empreintes SHA-256 vérifiées par le test 9 (`tests/external-gtfs.test.js`) :

| Fichier | SHA-256 |
|---|---|
| `flutter-src/assets/data/dakar_network.json` | `c08389ac04265a786fba3794580ef7da19ce258009d8d76290a14d5349e7fbe3` |
| `data/gtfs/shapes.txt` | `80a84ebad85ae58e1081e5308e709bd0262dcdd383c1532a80169396091f27eb` |
| `data/gtfs/stop_times.txt` | `3f90f8f00b247cc5fb79200e2e8ead9b8a8f9abe3e187b532056e62059e0c346` |
| `data/gtfs/stops.txt` | `e9b8081069cf977150645101671037d17f3576d11044836322240e0cd0a8ac49` |
| `data/gtfs/trips.txt` | `568377c6e59c491b40405d88f555a9696a798650398f3a1f9ec43f6888a11824` |
| `data/gtfs/routes.txt` | `bbc838005a6fe36312c979fc0c1374eb9f7c917afb5ca772b8ba85ac909328c6` |
| `data/gtfs/calendar.txt` | `db357382fc2512eb17b14f7fed6af0f0f0c2ec2dabb1c86813d43d4f3da0548d` |
| `data/gtfs/agency.txt` | `d16d5b8026ab4b84851cb12e5b406718bbf05b4eac671e5c681bd8403c85dc5c` |
| `data/gtfs/feed_info.txt` | `2b463e49025011767e5788c430503b3e35ec485389d6881e46af599b15632783` |
| `data/transit/reference-policy.json` | `94d698469b766ee89743392ab8b17458ab6a3e6d183b32bd74d9b26ce19d3d1c` |

TER, BRT, GPS, interface, géométrie, `pubspec.yaml` (assets) : inchangés. `flutter-src/lib/main.dart` :
+36 lignes (imports, provider global, amorçage dans `main()`, branche horaire de l'assistant), aucune
suppression.

## §11 Tests — résultats réels (2026-09-26)

- `npm test` : **36 tests, 36 réussis** (24 existants + 12 nouveaux : `tests/external-gtfs.test.js` 1–9,
  `tests/cetud-current.test.js` 10–12). Les tests 1–5 s'exécutent sur les **vrais ZIP PassBi** ; 6–12 sur
  des fixtures synthétiques `TEST_*` (aucune donnée réelle).
- `npm run gtfs:check` : OK (PassBi conforme, CETUD `ABSENT`, provider sans source actuelle, repli exact).
- `npm run gtfs:passbi:check` : OK ; `npm run gtfs:cetud:check` : `ABSENT` (code 0).
- `npm run validate:data` : NON CONFORME — état **préexistant** (porte de publication TER/BRT), inchangé par ce lot.
- `check:identites`, `transit:layer:check` : **NOT AVAILABLE** (scripts inexistants dans le dépôt).
- `flutter test` / `flutter build web` : **non exécutables dans le bac à sable** (aucun SDK Dart/Flutter
  joignable). Les fichiers Dart ont passé un contrôle syntaxique (tree-sitter-dart) ; la branche a été ajoutée
  au déclencheur du workflow `flutter-web-build.yml` (analyze → test → build web) qui s'exécute au push.

## §12 Limites (UNKNOWN explicite)

- Aucun horaire AFTU/DDD actuel n'est disponible : toute question horaire reçoit le repli exact.
- PassBi : origine des données non documentée, aucune licence, validité 2022–2023 (AFTU/DDD) ; 738 (AFTU) et
  333 (DDD) courses sans stop_times ; 289 courses AFTU avec `stop_sequence` dupliqués ; heures non croissantes
  sur 109 (AFTU) / 8 (DDD) / 1 (TER) courses — signalées, jamais corrigées.
- Le miroir Dart ne vérifie pas le SHA-256 des assets (pas de dépendance `crypto` déclarée) : la vérification
  d'intégrité est faite par les scripts Node à l'installation et au contrôle ; l'embarquement d'un futur feed
  CETUD dans l'application (déclaration d'assets `assets/data/external/cetud/…`) reste une décision à prendre
  lors de sa réception.
- Le détecteur de questions est déterministe et volontairement strict (numéro de ligne + arrêt écrits) : une
  formulation non reconnue n'est pas « devinée ».
- « TATA » n'est pas mappé sur un réseau (aucune correspondance officielle établie).
