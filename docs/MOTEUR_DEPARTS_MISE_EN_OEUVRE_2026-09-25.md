# Moteur commun de départs — mise en œuvre et confirmations (2026-09-25)

Suite de `docs/AUDIT_MOTEUR_DEPARTS_2026-09-25.md` (audit read-only, six rubriques).
Cette étape **implémente** le moteur d'estimation des prochains départs et
l'applique aux interfaces. Aucune donnée existante n'a été modifiée, aucun arrêt
ajouté, aucun `stop_times` fabriqué.

## 1. Ce qui a été produit

| Élément | Rôle |
|---|---|
| `engine/departure-engine.js` | Moteur unique (v1.0.0, UMD : navigateur + Node). 40 exports : statuts, sélection de fréquence, fenêtre d'estimation, classification d'observation, présentation, assistant, itinéraires, validation. **Aucune donnée embarquée.** |
| `data/transit/departure-frequencies.json` | Référentiel de fréquences **sourcées** (3 sources OFFICIAL, 5 fréquences : TER ×3, BRT B1, BRT B2) + couverture par réseau + `real_time.public_feeds = []` + liste `not_imported`. |
| `engine/gtfs-rt-policy.js` | Politique anti-simulation du proxy : refus par défaut, refus en production, activation locale explicite. |
| `index.html` | Carte, liste des 42 arrêts, panneau « Prochains passages » et assistant IA branchés sur le moteur. Faux départs (`next`), flotte simulée (13 véhicules), badges « LIVE / GTFS-RT LIVE / 127 véhicules actifs » supprimés ou neutralisés. |
| `service-worker.js` | Cache `v2.4` : moteur + référentiel en *network-first* (un statut périmé n'est jamais servi après déploiement). |
| `server/server.js`, `vercel.json`, `server/.env.example`, `server/README.md` | Le mock n'est plus actif par défaut et n'est jamais servi comme du temps réel ; refus explicite (`status: UNKNOWN`, 0 entité). |
| `flutter-src/lib/models/departure_estimate.dart`, `flutter-src/lib/services/departure_service.dart`, `flutter-src/test/departure_engine_test.dart`, `flutter-src/assets/data/departure-frequencies.json`, `flutter-src/pubspec.yaml` | Miroir Dart du moteur (mêmes règles, même référentiel). `main.dart` **non modifié**. |
| `tests/departure-engine.test.js` | 30 tests (T1–T18 + itinéraires + politique GTFS-RT + non-régression interface/référentiel). |

## 2. Règle appliquée, sans exception

```
1. horaire précis fiable ...................... SCHEDULED  (heure exacte, source identifiée)
2. sinon fréquence documentée ................. ESTIMATED  (fenêtre, jamais une heure exacte)
3. sinon observation véhicule réelle .......... REAL_TIME  (source + horodatage + ligne + véhicule)
4. sinon ...................................... UNKNOWN    (aucune donnée inventée)
```

* Une **fréquence n'est pas du temps réel** : elle produit une fenêtre
  (`11:43 → 11:53`), affichée « Estimation », jamais « Départ 11h43 ».
* **DDD, AFTU, TATA** n'ont aucune fréquence publiée : `UNKNOWN`, sans exception.
* La **position GPS de l'utilisateur** ne peut jamais devenir une position de
  véhicule (`vehicleFromUserPosition()` renvoie `null`, testé).
* Une source `HISTORICAL`, `UNKNOWN` ou simulée ne produit **aucun** service ;
  `COMMUNITY` n'est jamais officielle et reste désactivée par défaut.

## 3. Fréquences réellement utilisées

| Réseau / ligne | Fréquence | Amplitude | Source |
|---|---|---|---|
| TER Dakar ↔ Diamniadio (lun→sam) | 10 min | 05:30 → 21:00 | SETER, terdakar.sn |
| TER Dakar ↔ Diamniadio (lun→sam, soir) | 20 min | 21:00 → 22:00 | SETER, terdakar.sn |
| TER Dakar ↔ Diamniadio (dim. + fériés) | 20 min | 06:30 → 22:00 | SETER, terdakar.sn |
| BRT B1 Petersen ↔ Guédiawaye | 6 min | 06:00 → 21:00, tous les jours | SunuBRT, guide du voyageur |
| BRT B2 semi-express | 6 min | 06:00 → 21:00, lun→sam | SunuBRT, guide du voyageur |
| BRT B3, B4, TER AIBD, DDD, AFTU, TATA | **aucune** | — | non publiée / service non exposé |

Chaque fréquence porte `source`, `source_type`, `url`, `retrieved_at`,
`valid_from`, `valid_to`, `day_types`, `service_start`, `service_end`,
`frequency_minutes`, `confidence`, `status` et une note. Les valeurs inconnues
restent `null` (aucune date de publication inventée).

## 4. Mise en œuvre — vérifications exécutées

| Commande | Résultat |
|---|---|
| `npm test` | **54/54** (30 tests du moteur + 24 tests historiques TER/BRT) |
| `node --check` (moteur, politique, serveur, *service worker*, JS inline) | OK |
| `npm run validate:data` | rouge **comme avant** (36 × `STOP_NETWORK_INVALID`, `UNKNOWN_TRIP_REFERENCE`…) : gate données TER/BRT préexistant, non modifié par cette étape |
| `npm run audit:pages` | `releaseReady: false` — mêmes constats préexistants (géométrie publiée non certifiée, routage segment droit) |
| Serveur réel (`PORT=3000 node server/server.js`) | `/api/health` → `mode: NO_PUBLIC_FEED`, `simulatedDataServed: false` ; `/api/gtfs-rt/vehiclePositions` → `entity: []`, `status: UNKNOWN`, `simulated: false` ; `/api/vehicles` → `count: 0` ; `/api/alerts` → `count: 0` |
| Page servie | `engine/departure-engine.js` et `data/transit/departure-frequencies.json` servis (200) |

## 5. Les 13 confirmations demandées

1. **Départs documentés ou estimations marquées** — oui : `SCHEDULED` (heure exacte sourcée) /
   `ESTIMATED` (badge « Estimation », source et fréquence affichées) / `UNKNOWN`.
2. **Aucune heure inventée** — oui : `validateEstimate()` interdit toute fenêtre incomplète et
   toute heure dans un `UNKNOWN` ; l'interface n'affiche une heure que si la source la publie.
3. **Aucun temps réel sans source identifiée** — oui : `REAL_TIME` exige observation
   (source, horodatage, ligne, véhicule/événement) et refuse simulé, GPS utilisateur, périmé (>30 min).
4. **DDD / AFTU / TATA → UNKNOWN** — oui, aucune fréquence publiée n'existe ; aucune n'a été créée.
5. **TER : fréquences documentées + règle dimanche/jours fériés** — oui : 10 min (05:30-21:00),
   20 min (21:00-22:00), 20 min dimanche et jours fériés (06:30-22:00) ; testé avec une date
   fériée explicite (2026-10-05) — le moteur ne devine jamais un jour férié.
6. **BRT : fréquence uniquement si la ligne est documentée** — oui : B1 et B2 seulement ;
   la fréquence de 6 min de B1 **n'est pas** étendue aux autres lignes.
7. **BRT ≠ RAPIDE / B3 non exposée** — oui : aucune ligne B3 n'est créée, `services_not_exposed`
   est intact. *Point de veille* : la page d'accueil SunuBRT annonce désormais B3 « en service du
   lundi au vendredi aux heures de pointe » ; la correspondance de stations (Gueule Tapée) reste
   non confirmée → à trancher dans un audit dédié, pas ici.
8. **KMF UNKNOWN, Mbao distinct, Yeumbeul A/B non résolu** — oui : `dakar_network.json` inchangé ;
   les tests rejouent ces trois règles (place_id distincts, un seul arrêt Yeumbeul, aucune promotion).
9. **Aucun arrêt ajouté** — oui : 42 arrêts dans la PWA (inchangé), 117 arrêts / 105 routes dans le
   référentiel Flutter (inchangé) ; seule la **suppression** de champs `next` fabriqués a eu lieu.
10. **AIBD reste FUTURE et non exposée** — oui : aucune gare AIBD, aucune fréquence AIBD,
    `ter_diamniadio_aibd` toujours `exposed: false`.
11. **Une seule source de vérité partagée** — oui pour les **données et les règles** : un référentiel
    unique (`data/transit/departure-frequencies.json`, miroir byte-identique embarqué par Flutter) et
    deux implémentations du même moteur (JS pour la PWA/le proxy, Dart pour l'application Flutter),
    avec le même vocabulaire de statuts et de libellés (`ScheduleStatus.displayLabel()`,
    `ReliabilityLabel.scheduleUnavailable`).
    *Limite assumée* : `flutter-src/lib/main.dart` n'a pas été modifié (décision de l'audit §6), donc
    l'écran Flutter affiche toujours « Horaire indisponible » : il reste honnête, mais il n'est pas
    encore branché. Le branchement est le lot suivant (il exige `flutter analyze` + `flutter test`).
12. **Tests 12, 13 et 18 rejoués** — **à nuancer** : aucun document « audit V4.4 » n'existe dans le
    dépôt (`docs/` contient 4 audits datés + 1 JSON), donc ses tests 12/13/18 n'ont pas pu être
    rejoués littéralement. Les équivalents présents ont été rejoués : les 30 tests du moteur,
    les 24 tests historiques TER/BRT, les règles KMF/Mbao/Yeumbeul/AIBD issues de l'audit des
    données du 2026-09-24. Si l'audit V4.4 est disponible, le fournir permet de rejouer exactement
    ses tests.
13. **Aucune régression** — oui : `npm test` 54/54, `dakar_network.json` et `data/gtfs/*` intacts,
    gates `validate:data` / `audit:pages` au même état qu'avant, GPS/carte/marqueurs/polylignes/
    favoris/recherche non touchés, assistant toujours honnête.

## 6. Limites explicites

* `flutter analyze` / `flutter test` **n'ont pas pu être exécutés** dans cet environnement
  (SDK Flutter non installable, accès réseau bloqué). Les fichiers Dart sont écrits pour la CI
  J9 (`analyze` → `test` → `build web`) ; c'est elle qui les validera.
* Le moteur ne contient **aucune donnée** : sans référentiel chargé, tout est `UNKNOWN`
  (échec fermé). C'est volontaire — un moteur « qui marche quand même » inventerait.
* B3/B4, TER AIBD, KMF, Yeumbeul A/B restent hors service, exactement comme dans l'audit des
  données : cette étape ne les promeut pas.
