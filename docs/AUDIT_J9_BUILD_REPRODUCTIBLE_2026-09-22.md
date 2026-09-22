# AUDIT J9 — CHAÎNE DE BUILD REPRODUCTIBLE (Flutter → GitHub Pages)

- Date : 2026-09-22
- Branche de travail : `arena/01a0ca19-dakar-bus` (base `ce8c94f` = `main`)
- État : **J9 EXÉCUTÉ ET VÉRIFIÉ** — commits `f62ef9e` (restauration), `2d0fcf3`/`50e0370` (outil de récupération du lockfile), `f924691` (`pubspec.lock`) ; runs GitHub Actions `35782638226` (sans lock), `35783754750` (exposition du lock), `35783905099` (avec `--enforce-lockfile`). Détails et preuves : **section O**. Les sections A→N ci-dessous décrivent la préparation (rédigées avant le premier run) ; les points désormais résolus sont signalés par « ✅ (voir O) ».
- Périmètre : J9 uniquement (chaîne SOURCE FLUTTER COMMITÉ → Flutter 3.24.5 → `pub get` → `test` → `build web` → ARTEFACT → GH-PAGES)
- Hors périmètre (documentés, **non corrigés**) : GPS hors Dakar, arrêts codés en dur, TER/BRT, DakarBounds, J1-J8, J10, interface
- Projet officiel : Flutter `dakar_bus` 9.3.2+12 (base B = `ac03557`). PWA JavaScript racine = archive intouchable.

---

## A. Source : commit `ac03557`

| Élément | Valeur |
|---|---|
| Commit | `ac035570bb600f2427a164e41b7af7803fe965c6` |
| Date / message | 2026-09-22 06:30:31 +0000 — `docs(groupe-9): audit DataTrust / DataStatus / fiabilité affichée` |
| Branche d'origine | `arena/01a0c385-dakar-bus` (base B, adoptée en mission 4) |
| Arbre `flutter-src/` | `c4337fa4e09ee12efb3b94c7fe1ed2672a867e32` |
| Base rejetée | `2c72e57` (A, référence historique — **non utilisée**) |

Le dossier `flutter-src/` n'existait pas sur `main`/`ce8c94f` (branche de travail) : il a été importé tel quel (voir D). La PWA racine (`index.html`, `data/`, `js/`, etc.) n'a pas été touchée : `git diff --stat` sur les fichiers suivis est **vide**.

## B. Flutter 3.24.5

- Version épinglée dans le workflow : `FLUTTER_VERSION: '3.24.5'`, `FLUTTER_CHANNEL: 'stable'` (installation `subosito/flutter-action@v2`, `cache: true`).
- Contrôle bloquant dans le workflow : `flutter --version --machine | jq -r .frameworkVersion` doit valoir exactement `3.24.5`, sinon `exit 1`.
- Cohérence avec l'historique : le `deploy.yml` hérité dans `flutter-src/.github/workflows/` (inerte, voir M) utilisait déjà `flutter-version: '3.24.5'` et la même commande de build ; le CI de la base B (`flutter-verify.yml`) a tourné avec « Flutter 3.24.5 • channel stable ».
- Contrainte `pubspec.yaml` : `environment.sdk: '>=3.3.0 <4.0.0'` (Dart 3.5.4 livré avec Flutter 3.24.5 est compatible).
- Vérifications faites sur le code source de Flutter au tag `3.24.5` (API GitHub, fichiers `packages/flutter_tools/...`) :
  - `flutter pub get --enforce-lockfile` existe (`commands/packages.dart` l.218) ;
  - `flutter --version --machine` expose `frameworkVersion` (`version.dart` l.246) ;
  - `flutter build web` écrit `version.json` depuis le `pubspec.yaml` (`build_system/targets/web.dart` l.493-510, `createVersionFile`).

## C. Version : 9.3.2+12 — source unique `flutter-src/pubspec.yaml`

- `flutter-src/pubspec.yaml` l.1 `name: dakar_bus`, l.19 `version: 9.3.2+12`. **Aucune autre version n'est introduite** (ni dans le workflow, ni dans un fichier annexe).
- Le workflow lit cette ligne en bash (`grep -E '^version:'`), l'expose en sortie `app_version`, et après compilation vérifie que `build/web/version.json` (généré par Flutter) contient `version == 9.3.2` et `build_number == 12`, sinon échec.
- Preuve que Flutter dérive bien `version.json` du pubspec : le build historique `2c96eef` (source 2c72e57, pubspec `9.3.0+4`) contient `{"app_name":"dakar_bus","version":"9.3.0","build_number":"4","package_name":"dakar_bus"}`.
- Constat (information, hors périmètre) : le `version.json` **actuellement servi** sur `gh-pages` (`94a84b6`) est indenté sur 5 lignes avec `"app_name": "dakarbus"`, alors que Flutter écrit un JSON compact avec `app_name` = `name:` du pubspec (`dakar_bus`). Il n'a donc pas été produit tel quel par `flutter build web` à partir de B. Le premier run du workflow rétablira un `version.json` généré automatiquement (`dakar_bus` / `9.3.2` / `12`). Rien dans `lib/` ne lit `version.json` (grep `version.json|package_info` : aucun résultat).
- Hors périmètre, **non modifié** : chaîne UI `Dakar Bus v9.4 (Web Fix)` codée en dur dans `lib/main.dart` l.2796 (deuxième « version » affichée, incohérente avec le pubspec).

## D. Fichiers restaurés dans `flutter-src/`

Import : `git -C /tmp/dakar-mirror.git archive ac03557 flutter-src | tar -x -C /home/user/dakar-bus` (miroir Git complet du dépôt, le clone de travail étant superficiel). Chaque fichier a été comparé blob par blob (`git hash-object` local = blob de `ac03557`) :

| Fichier (`flutter-src/…`) | Blob `ac03557` | Identique |
|---|---|---|
| `.github/workflows/deploy.yml` | `5be325dc63b4` | OK |
| `.gitignore` | `9844482abe96` | OK |
| `README.md` | `3f31d28360da` | OK |
| `analysis_options.yaml` | `3f41edab5b51` | OK |
| `assets/data/dakar_network.json` | `e82d25e60e95` | OK |
| `lib/main.dart` | `5d07efa36693` | OK |
| `lib/models/transport_network.dart` | `1218a389080c` | OK |
| `lib/services/data_service.dart` | `d91c72757cf2` | OK |
| `pubspec.yaml` | `5a6143b99bfc` | OK |
| `test/dakar_bounds_test.dart` | `d894957b0213` | OK |
| `test/data_service_test.dart` | `e450947169d2` | OK |
| `test/detailed_route_test.dart` | `2db56aa65d62` | OK |
| `test/gps_position_test.dart` | `a0f776274857` | OK |
| `test/groupe6_alertes_test.dart` | `fc6cff60ae76` | OK |
| `test/network_data_test.dart` | `32077e6ee1d4` | OK |
| `test/opposite_stop_test.dart` | `74c7e417fd2c` | OK |
| `test/ter_brt_route_data_test.dart` | `f2729905015b` | OK |
| `test/widget_test.dart` | `8781a8540e3c` | OK |
| `web/index.html` | `cffe3f06fb14` | OK |
| `web/manifest.json` | `d89fefb68b01` | OK |

20/20 identiques ; aucun fichier ajouté, modifié ou supprimé dans `flutter-src/` ; aucun fichier PWA mélangé. État Git : `?? flutter-src/` (non suivi, en attente de validation pour commit).

## E. `pubspec.lock`

- **Jamais commité** dans tout l'historique du dépôt (`git log --all --diff-filter=A -- pubspec.lock flutter-src/pubspec.lock` sur le miroir complet : vide). Ni A ni B n'en ont.
- `flutter-src/.gitignore` l'autorise explicitement (`*.lock` puis `!pubspec.lock`) : il est destiné à être commité.
- **Non généré ici** : le SDK Flutter/Dart ne peut pas être installé dans cet environnement (voir G). Un lockfile écrit à la main serait une falsification (versions transitives et `sha256` des archives pub non vérifiables) — refusé.
- ✅ (voir O) : le lockfile a été **généré par Flutter 3.24.5 sur GitHub Actions** (run `35782638226`), récupéré à l'identique (SHA-256 vérifié) et commité dans `flutter-src/pubspec.lock` (`f924691`) ; le run suivant (`35783905099`) l'a imposé avec `--enforce-lockfile`.
- Traitement dans le workflow (aucune version changée arbitrairement ; `pubspec.yaml` intact) :
  - si `flutter-src/pubspec.lock` est présent → `flutter pub get --enforce-lockfile` (résolution imposée, build reproductible) ;
  - s'il est absent → `flutter pub get` normal + `::warning::` + le `pubspec.lock` généré par Flutter 3.24.5 est affiché dans le log et publié comme artefact `pubspec.lock`, **à vérifier puis commiter dans `flutter-src/` après validation** (étape humaine, pas de commit automatique).
- Dépendances déclarées (inchangées) : `flutter` (sdk), `cupertino_icons ^1.0.8`, `flutter_map ^6.1.0`, `latlong2 ^0.9.1`, `geolocator ^12.0.0`, `http ^1.2.2` ; dev : `flutter_test` (sdk), `flutter_lints ^4.0.0`. (Correctif de rédaction : `latlong2` manquait dans la première version de cette liste ; le `pubspec.yaml` n'a pas changé.)

## F. Workflow : `.github/workflows/flutter-web-build.yml` (racine du dépôt)

- Fichier : 323 lignes, SHA-256 `b52e67d9e5afd635bb99af37695cda9716138daf091c6fcad3618f9797671b57`.
- Déclencheurs : `push` sur `main` et `arena/01a0ca19-dakar-bus` (chemins `flutter-src/**` + le workflow), `pull_request` (mêmes chemins), `workflow_dispatch` avec entrée booléenne `publish_pages` (défaut `false`).
- `permissions: contents: read` au niveau racine ; `concurrency` par ref.
- Job `build` (ubuntu-latest, `working-directory: flutter-src`, timeout 30 min), 20 étapes :
  1. `actions/checkout@v4`
  2. `subosito/flutter-action@v2` — 3.24.5 stable
  3. contrôle de version exact (bloquant) ; création du journal `$RUNNER_TEMP/j9-logs/`
  4. lecture de `version:` dans `pubspec.yaml` → sortie `app_version`
  5. détection `pubspec.lock` → sortie `present`
  6. `flutter pub get --enforce-lockfile` (si lock présent)
  7. `flutter pub get` (si lock absent, avec affichage du lock généré)
  8. `flutter analyze`
  9. `flutter test --reporter expanded`
  10. `flutter build web --release --base-href "/dakar-bus/"` (commande identique au `deploy.yml` historique ; renderer et stratégie PWA par défaut de 3.24.5, rien de plus)
  11. (`if: always()`) résultats des commandes : dernière ligne de chaque sortie en annotation `::notice::` (lisible via l'API check-runs), extraits dans `$GITHUB_STEP_SUMMARY`, lockfile généré affiché avec ses versions résolues (lecture en bash pur)
  12. (`if: always()`) `upload-artifact@v4` `j9-logs-<sha>` = sorties brutes de `flutter --version`, `pub get`, `analyze`, `test`, `build web` (+ `pubspec.lock` généré)
  13. empreintes SHA-256 de tous les fichiers de `build/web` → `build/web-checksums.txt` (annotation avec l'empreinte de `main.dart.js`)
  14. contrôles : `version.json` == pubspec, `<base href="/dakar-bus/">` présent dans `index.html`, `assets/data/dakar_network.json` **identique octet pour octet** à `build/web/assets/assets/data/dakar_network.json` (`cmp`), `main.dart.js` non vide
  15. résumé `$GITHUB_STEP_SUMMARY` (version, Flutter, lock, empreintes principales, « Post-traitement de main.dart.js : AUCUN »)
  16. `upload-artifact@v4` `dakar-bus-web-<sha>` = `flutter-src/build/web` intégral (30 jours)
  17. `upload-artifact@v4` `dakar-bus-web-checksums-<sha>`
  18. `upload-artifact@v4` `pubspec.lock` (seulement si le lock était absent)
  19. **recalcul** des empreintes juste avant la préparation Pages et `diff` avec l'étape 13 → échec si le moindre octet a changé (preuve mécanique de l'absence de post-traitement)
  20. `actions/upload-pages-artifact@v3` (`flutter-src/build/web`) — prépare l'artefact Pages, **ne déploie pas**
- Les commandes Flutter sont exécutées via `cmd 2>&1 | tee <journal>` sous `bash -eo pipefail` (shell par défaut de GitHub pour `shell: bash`) : le code de sortie de Flutter est conservé, aucun échec n'est masqué.
- Job `deploy-pages` : `if: github.event_name == 'workflow_dispatch' && inputs.publish_pages == true`, `needs: build`, `permissions: pages: write, id-token: write`, `environment: github-pages`, `concurrency: github-pages-deploy`. Étape 1 : `gh api repos/<repo>/pages --jq .build_type` ≠ `workflow` ⇒ `::error::` avec le changement exact à faire, `exit 1`, **rien n'est publié**. Étape 2 : `actions/deploy-pages@v4` (uniquement en mode « GitHub Actions »).
- Ce que le workflow **ne contient pas** : aucun `python`, `sed`, `perl`, `awk`, `node`, aucune regex sur `main.dart.js`, aucun remplacement de coordonnées, aucune injection JS, aucune écriture dans `build/web` après compilation (les seules écritures sont `build/web-checksums*.txt` et le journal `$RUNNER_TEMP/j9-logs/`, **hors** de `build/web`). Les seules occurrences de `main.dart.js` sont `test -s build/web/main.dart.js` (contrôle de non-vacuité) et une ligne du résumé.
- Le workflow ne lit ni ne publie aucun fichier de la PWA racine ; il ne touche pas à la branche `gh-pages` (aucun `git push`, aucun `peaceiris/actions-gh-pages`).
- Validation locale : `action-validator` (schéma officiel des workflows GitHub) → OK, aucune erreur ; parsing YAML (PyYAML) → OK, 3 déclencheurs, 2 jobs, 20 + 2 étapes ; `bash -n` sur chacun des scripts `run` → OK.
- Note : `.github/workflows/transit-validation.yml` (PWA, `npm test` + `validate:data`, déclenché sur toute `pull_request`) n'a **pas été modifié** ; il continuera de s'exécuter (et d'échouer comme sur `main`) sur les PR — hors périmètre.

## G. Commandes réellement exécutées (et non exécutées)

Exécutées dans cet environnement :

| Commande | Résultat |
|---|---|
| `git -C /tmp/dakar-mirror.git archive ac03557 flutter-src \| tar -x -C /home/user/dakar-bus` | import de `flutter-src/` |
| `git hash-object <chaque fichier>` vs `git ls-tree -r ac03557 flutter-src` | 20/20 blobs identiques |
| `git log --all --diff-filter=A -- pubspec.lock flutter-src/pubspec.lock` (miroir) | vide : lock jamais commité |
| `git diff --stat` / `git status --short` | aucun fichier suivi modifié ; nouveaux : workflow, `flutter-src/`, 5 rapports docs |
| `curl` vers `storage.googleapis.com` (SDK Flutter/Dart) et `pub.dev` | HTTP `000` (bloqués) ; idem miroirs flutter-io.cn, ghcr.io, docker hub, snapcraft, objects.githubusercontent.com |
| `which flutter dart` | absents |
| `gh api repos/flutter/flutter/contents/...?ref=3.24.5` | vérification `--enforce-lockfile`, `frameworkVersion`, `createVersionFile` |
| `git show 2c96eef:flutter.js`, `git show 2c96eef:version.json`, `git show 94a84b6:version.json` (miroir) | preuves sections C et K |
| `npx action-validator .github/workflows/flutter-web-build.yml` | OK |
| `gh api repos/aydiarra-star/dakar-bus/pages` | `build_type: legacy`, source `gh-pages` `/`, status `built` |

**Non exécutées localement** (impossible ici, sans SDK) : `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web`. ✅ (voir O) Elles ont été **réellement exécutées par GitHub Actions** dans les runs `35782638226` et `35783905099` ; les résultats rapportés en O proviennent des conclusions d'étapes et des annotations de ces runs (API GitHub), pas d'une exécution locale.

## H. Résultat `flutter test`

- **Non exécuté localement** (cf. G).
- Résultat connu le plus récent sur ce même source (`ac03557`, CI de la base B `flutter-verify.yml`, résumé récupéré via l'API GitHub, `/tmp/checkrun_ac03557.txt`) : `flutter analyze` → « No issues found! » ; `flutter test` → **232 tests, 232 réussis, 0 échec**, 9 fichiers de test, Flutter 3.24.5 stable.
- ✅ (voir O) Confirmé par les deux runs : `00:04 +232: All tests passed!` (run `35782638226`, sans lock) et `00:03 +232: All tests passed!` (run `35783905099`, avec `--enforce-lockfile`). Aucun test n'est ignoré, filtré ni contourné (pas de `--exclude-tags`, pas de `continue-on-error`).

## I. Résultat `flutter build web`

- **Non exécuté localement** (cf. G). ✅ (voir O) Exécuté par GitHub Actions : `✓ Built build/web`, 28 fichiers, dans les deux runs ; `main.dart.js` **identique octet pour octet** entre les deux runs (SHA-256 `a5ee5158…`).
- Points vérifiés statiquement pour anticiper le build :
  - `web/index.html` l.4 `<base href="$FLUTTER_BASE_HREF">` → substitué par `--base-href "/dakar-bus/"` (contrôlé par le workflow) ; chargeur `flutter.js` + `loadEntrypoint` sans `serviceWorker` configuré → `flutter.js` 3.24.5 loggue « Null serviceWorker configuration. Skipping. » (chaîne présente dans le `flutter.js` du build historique `2c96eef`) ; le fichier `flutter_service_worker.js` est tout de même généré par défaut.
  - `pubspec.yaml` : `assets: - assets/data/dakar_network.json` → sortie `build/web/assets/assets/data/dakar_network.json` (même chemin que sur `gh-pages` aujourd'hui), vérifié par `cmp` dans le workflow.
  - Chemins relatifs : `manifest.json`, `flutter.js`, `main.dart.js` relatifs à `<base href>` ; `manifest.json` `start_url: "."`, `icons: []` (aucune icône référencée → aucun 404 d'icône ; `web/` ne contient que `index.html` et `manifest.json`, pas de `favicon.png` ni `icons/`).
  - Routing : `lib/main.dart` n'utilise ni `usePathUrlStrategy`, ni routes nommées, ni `onGenerateRoute`/`initialRoute` (navigation par `Navigator.push` uniquement) → stratégie d'URL par défaut (hash) → aucun deep link, **pas besoin de `404.html`** sur Pages.
  - `main()` charge `appDataService.loadNetworkData()` puis `runApp` ; `flutter_map ^6.1.0`, `geolocator ^12.0.0`, `http ^1.2.2` sont compatibles web et avec Dart 3.5.
  - Avertissements possibles (non bloquants) : `loadEntrypoint` est une API de chargement héritée en 3.24 (avertissement de dépréciation à l'exécution possible) — **hors périmètre, non modifié**.

## J. Artefact

Produit par le job `build` à chaque run (push / PR / dispatch) :

| Artefact | Contenu | Rétention |
|---|---|---|
| `dakar-bus-web-<sha>` | `flutter-src/build/web` complet, tel qu'écrit par `flutter build web` (`index.html`, `main.dart.js`, `flutter.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`, `manifest.json`, `assets/`, `canvaskit/`) | 30 jours |
| `dakar-bus-web-checksums-<sha>` | `web-checksums.txt` : SHA-256 de chaque fichier (calculé juste après compilation) | 30 jours |
| `pubspec.lock` | lockfile généré par Flutter 3.24.5 (uniquement tant qu'aucun lock n'est commité) | 30 jours |
| `j9-logs-<sha>` | sorties brutes de `flutter --version`, `pub get`, `analyze`, `test`, `build web` (+ `pubspec.lock` généré), même en cas d'échec | 30 jours |
| `github-pages` | archive Pages de `flutter-src/build/web` (via `upload-pages-artifact@v3`), consommée uniquement par `deploy-pages` | 1 jour (défaut de l'action) |

Chaque `main.dart.js` publié est identifiable par son empreinte SHA-256 et rattaché à un `github.sha` précis : c'est la traçabilité source → binaire qui manquait.

## K. Méthode de publication GitHub Pages

- **État actuel (vérifié)** : `build_type: legacy`, source = branche `gh-pages`, chemin `/`, site `https://aydiarra-star.github.io/dakar-bus/`. La branche `gh-pages` (`94a84b6`) contient, en plus d'une sortie Flutter, des éléments **non produits par `flutter build web`** : `osrm/` (bundle OSRM), `tools/`, `service-worker.js`, `.github/`, `.last_build_id`, un `version.json` reformaté à la main (cf. C). Conformément à la consigne, **rien de tout cela n'est remplacé ni supprimé** (J10).
- **Incompatibilité** : une publication propre à partir de l'artefact du workflow (`deploy-pages@v4`) exige le mode Pages « GitHub Actions » (`build_type: workflow`). En mode `legacy`, la seule façon de publier serait de pousser sur `gh-pages`, ce qui écraserait les fichiers ci-dessus → **refusé en J9**.
- **Changement exact à faire (documenté, NON appliqué, à valider)** : Settings → Pages → Build and deployment → Source : « Deploy from a branch » → « GitHub Actions ». Équivalent API : `gh api -X PUT repos/aydiarra-star/dakar-bus/pages -f build_type=workflow`. Effets : le site sera servi depuis l'artefact du workflow ; la branche `gh-pages` **n'est ni modifiée ni supprimée** (elle reste l'archive du déploiement patché jusqu'à J10) ; le workflow système `pages-build-deployment` cesse de publier la branche. Retour arrière possible à tout moment (`build_type=legacy`, source `gh-pages`).
- **Garde-fou** : le job `deploy-pages` vérifie le mode et s'arrête en erreur explicite tant que le mode est `legacy` ; il ne s'exécute de toute façon que sur `workflow_dispatch` avec `publish_pages=true` (jamais sur push/PR). Commande une fois le workflow enregistré par un premier push : `gh workflow run flutter-web-build.yml --ref arena/01a0ca19-dakar-bus -f publish_pages=true`.
- Détails techniques : en mode « GitHub Actions » Jekyll ne s'applique pas (`.nojekyll` inutile) ; pas de `404.html` nécessaire (cf. I) ; le `deploy.yml` hérité de `flutter-src/` utilisait déjà `upload-pages-artifact@v3` + `deploy-pages@v4`, donc ce mode est celui prévu à l'origine par le projet Flutter.

## L. Vérification zéro patch sur `main.dart.js`

1. Le workflow ne contient aucun interpréteur ni outil de réécriture (`grep -nE "python|sed |perl |awk |node |\.py\b"` sur le fichier : aucune ligne hors commentaires).
2. Aucune étape n'écrit dans `build/web` après `flutter build web` : les fichiers `web-checksums.txt` et `web-checksums-final.txt` sont écrits dans `build/`, pas dans `build/web`.
3. Preuve mécanique à chaque run : SHA-256 de tous les fichiers calculés immédiatement après la compilation (étape 11), recalculés juste avant `upload-pages-artifact` (étape 17), `diff` bloquant. Toute modification post-build, même d'un octet, fait échouer le run avant publication.
4. Les empreintes sont archivées (`dakar-bus-web-checksums-<sha>`) et affichées dans le résumé du run : n'importe qui peut télécharger le site publié et comparer.
5. Aucune coordonnée, aucun texte, aucune donnée n'est injecté : la seule source de données embarquée est `flutter-src/assets/data/dakar_network.json`, vérifiée identique (`cmp`) dans le bundle.

## M. Risques

| # | Risque | Nature | Périmètre |
|---|---|---|---|
| 1 | ~~La chaîne n'a pas été exécutée~~ ✅ résolu : runs `35782638226` et `35783905099` réussis (voir O). | Validation | clos |
| 2 | ~~Sans `pubspec.lock` commité…~~ ✅ résolu : `flutter-src/pubspec.lock` commité (`f924691`), `--enforce-lockfile` effectif au run `35783905099`. | Reproductibilité | clos |
| 3 | Mode Pages `legacy` : aucune publication possible depuis le workflow tant que le changement documenté en K n'est pas validé et appliqué. **Seul verrou restant avant une republication.** | Publication | J9/J10 — décision |
| 4 | Transition service worker : le site actuel enregistre un SW (`flutter_service_worker.js` prod + `service-worker.js` ad hoc). Après publication du nouveau build, le SW existant se mettra à jour avec le nouveau `flutter_service_worker.js` ; le `service-worker.js` ad hoc ne sera plus servi. Un rechargement peut être nécessaire chez les utilisateurs. | Runtime | J10 |
| 5 | Le bundle OSRM (`osrm/`) et les patches manuels de `gh-pages` ne font pas partie du build Flutter : le nouveau build appelle `router.project-osrm.org` directement (`data_service.dart` l.134). Fonctionnalité à réévaluer avant publication. | Fonctionnel | Hors périmètre (documenté mission 4) |
| 6 | `flutter-src/.github/workflows/deploy.yml` (hérité) est inerte tant que `flutter-src/` n'est pas à la racine ; s'il y était déplacé un jour, il déploierait automatiquement à chaque push sur `main`. | Latent | Hors périmètre |
| 7 | `transit-validation.yml` (PWA) échoue sur toute PR, y compris une PR Flutter : bruit de CI, pas de blocage du workflow J9. | CI | Hors périmètre |
| 8 | Différence visible après le premier build : `version.json` `app_name` passe de `dakarbus` (fichier servi, édité à la main) à `dakar_bus` (nom du pubspec) ; aucune incidence fonctionnelle (rien ne lit ce fichier). | Cosmétique | Information |
| 9 | Problèmes applicatifs déjà audités et **non corrigés** (rappel, hors J9) : GPS hors `DakarBounds` → position `null` ; 24 arrêts codés en dur (`main.dart` l.750-788) verrouillés par tests ; libellé « Dakar Bus v9.4 (Web Fix) » l.2796 ; horaires générés sous badge « Officiel » ; `_loadFallbackData` ; etc. | Applicatif | J1-J8 |
| 10 | Déclencheur `push` sur `arena/01a0ca19-dakar-bus` : dès que le push est validé et effectué, le job `build` s'exécute (sans publication). C'est voulu (premier run de validation). | Process | J9 |

## N. Prochaine étape (après validation explicite — rien n'est fait sans elle)

1. ✅ fait — commit + push `f62ef9e` (flutter-src, workflow, rapports B et J9).
2. ✅ fait — premier run `35782638226` : succès complet.
3. ✅ fait — lockfile récupéré à l'identique (run `35783754750`), commité (`f924691`), run `35783905099` en `--enforce-lockfile` : succès complet.
4. **Décision Pages** (en attente de validation) : passage en mode « GitHub Actions » (K). Tant que non validé, aucune publication.
5. **Publication** (après 4) : `gh workflow run flutter-web-build.yml --ref <branche> -f publish_pages=true`, puis comparer les SHA-256 du site servi avec l'artefact `dakar-bus-web-checksums-<sha>`.
6. J10 (séparé) : traitement de la branche `gh-pages` (archive, bundle OSRM, anciens artefacts) ; suppression éventuelle de l'outil `j9-expose-lockfile.yml` devenu inutile.

---

## O. Exécution réelle sur GitHub Actions (mise à jour finale, 2026-09-22 soir)

### O.1 Commits poussés sur `arena/01a0ca19-dakar-bus`

| Commit | Contenu | Déclenche |
|---|---|---|
| `f62ef9effdc21fa65d971825dc67ffcf7699daf7` | `flutter-src/` (20 fichiers = `ac03557:flutter-src`, arbre `c4337fa4…`), `.github/workflows/flutter-web-build.yml`, `docs/AUDIT_BASE_B_2026-09-22.md`, ce rapport | run `35782638226` |
| `2d0fcf3` puis `50e0370` | `.github/workflows/j9-expose-lockfile.yml` — outil de récupération en lecture seule (voir O.3) ; le second commit ajoute le déclencheur `push` sur son propre chemin, nécessaire pour que GitHub enregistre le workflow (un workflow `workflow_dispatch` seul n'est pas enregistré : `HTTP 404` au `gh workflow run`) | run `35783754750` |
| `f924691c00f7346c39836fd45ec5c6da4ee07c7c` | `flutter-src/pubspec.lock` **uniquement** (410 lignes) — message « J9: lock Flutter dependencies » | run `35783905099` |

Aucun autre fichier modifié ; `lib/`, `assets/`, `pubspec.yaml`, `web/`, tests : inchangés depuis `ac03557`. Aucune PR créée.

### O.2 Run 1 — `35782638226` (commit `f62ef9e`, sans lockfile)

https://github.com/aydiarra-star/dakar-bus/actions/runs/35782638226 — événement `push`, `success`, 20:48:12 → 20:49:46 UTC.

| Étape | Résultat |
|---|---|
| Flutter | `Flutter 3.24.5 • channel stable` (contrôle exact OK) |
| `flutter pub get` | OK (lock absent → résolution normale, avertissement émis, `pubspec.lock` généré et téléversé en artefact) |
| `flutter analyze` | `No issues found! (ran in 11.1s)` |
| `flutter test` | `00:04 +232: All tests passed!` |
| `flutter build web --release --base-href /dakar-bus/` | `✓ Built build/web` — 28 fichiers |
| `version.json` | `{"app_name":"dakar_bus","version":"9.3.2","build_number":"12","package_name":"dakar_bus"}` |
| Cohérence | base href OK ; `dakar_network.json` embarqué identique (`cmp`) ; empreintes avant publication identiques |
| `main.dart.js` | SHA-256 `a5ee51589b85424d0b52f704b50d33bdd85a54cc917e7f21ea52844e2b072746` |
| Artefacts | `dakar-bus-web-f62ef9e…` (7 690 070 o), `dakar-bus-web-checksums-f62ef9e…` (1 520 o), `pubspec.lock` (3 042 o zippés), `j9-logs-f62ef9e…` (12 653 o), `github-pages` (7 689 079 o, non déployé) |
| `deploy-pages` | skipped (pas de `workflow_dispatch`) |

### O.3 Récupération du lockfile — run `35783754750`

- Contrainte : le téléchargement des artefacts et des logs redirige vers `productionresults*.blob.core.windows.net` / `results-receiver.actions.githubusercontent.com`, injoignables depuis l'environnement d'audit (HTTP 000). `gh run download` échoue (`EOF`).
- Mécanisme GitHub/API utilisé : workflow `j9-expose-lockfile.yml` (lecture seule ; permissions `contents: read`, `actions: read`, `checks: write`) → `actions/download-artifact@v4` de l'artefact `pubspec.lock` du run `35782638226` → `sha256sum`, `wc -c`, `base64` → contenu (base64 + brut) écrit dans `output.text` du check-run de son propre job via `PATCH /repos/…/check-runs/{job_id}` (procédé déjà employé par le CI de la base B).
- Lecture depuis l'environnement : `gh api repos/aydiarra-star/dakar-bus/check-runs/106935397282 --jq .output.text` → bloc base64 → `base64 -d` → fichier.
- **Vérification d'identité** : SHA-256 du fichier reconstruit `16b73eef4974518cd6010e1635e62a79ba155c6498a51a3e9de50d3a89432b16`, 11 749 octets = empreinte et taille calculées **sur le runner** (présentes à la fois dans le texte du check-run et dans une annotation `::notice::`, canal indépendant) ; bloc brut et bloc base64 identiques (`cmp`). Aucune ligne écrite ou modifiée à la main.
- **Vérification de contenu** : en-tête `# Generated by pub` ; 52 paquets (48 `hosted` sur `https://pub.dev`, 4 `sdk`) ; versions **identiques** à la liste annoncée par le run `35782638226` (`diff` vide sur les 52 entrées) ; dépendances directes conformes à `pubspec.yaml` inchangé : `cupertino_icons 1.0.8` (^1.0.8), `flutter_map 6.2.1` (^6.1.0), `latlong2 0.9.1` (^0.9.1), `geolocator 12.0.0` (^12.0.0), `http 1.6.0` (^1.2.2), `flutter_lints 4.0.0` (^4.0.0) ; `sdks: dart ">=3.5.0 <4.0.0"`, `flutter ">=3.19.0"` (Dart 3.5.4 de Flutter 3.24.5).
- Emplacement : `flutter-src/pubspec.lock` (autorisé par `flutter-src/.gitignore` l.10 `!pubspec.lock`).

### O.4 Run 2 — `35783905099` (commit `f924691`, avec lockfile)

https://github.com/aydiarra-star/dakar-bus/actions/runs/35783905099 — événement `push`, `success`, 21:00:23 → 21:02:02 UTC.

| Étape | Résultat |
|---|---|
| Flutter | `Flutter 3.24.5 • channel stable` |
| État du lockfile | présent → étape « flutter pub get (lockfile imposé) » **exécutée** (`success`) ; étape « première exécution » **skipped** ; artefact `pubspec.lock` non produit (skipped) ; plus aucun avertissement « lockfile absent » |
| `flutter pub get --enforce-lockfile` | OK |
| `flutter analyze` | `No issues found! (ran in 11.3s)` |
| `flutter test` | `00:03 +232: All tests passed!` |
| `flutter build web --release --base-href /dakar-bus/` | `✓ Built build/web` — 28 fichiers |
| `version.json` | `{"app_name":"dakar_bus","version":"9.3.2","build_number":"12","package_name":"dakar_bus"}` |
| Cohérence | base href OK ; asset réseau identique ; empreintes avant publication identiques |
| `main.dart.js` | SHA-256 `a5ee51589b85424d0b52f704b50d33bdd85a54cc917e7f21ea52844e2b072746` — **identique au run 1** |
| Artefacts | `dakar-bus-web-f924691…` (7 690 068 o), `dakar-bus-web-checksums-f924691…` (1 518 o), `j9-logs-f924691…` (8 270 o), `github-pages` (7 689 062 o, non déployé) |
| `deploy-pages` | skipped |

### O.5 Zéro post-traitement JS — confirmation

- Le workflow ne contient aucun interpréteur ni outil de réécriture et n'écrit rien dans `build/web` après compilation (section L) ; l'étape « Empreintes au moment de la publication » (recalcul + `diff`) a réussi dans les deux runs.
- Le même source (`lib/`, `assets/`, `pubspec.yaml` inchangés) avec le même SDK produit un `main.dart.js` **octet pour octet identique** dans deux runs distincts (même SHA-256), avec et sans lockfile — la résolution figée est bien celle du build validé, et la sortie est déterministe.
- Le `main.dart.js` actuellement servi par `gh-pages` (`94a84b6`, patché à la main) n'a pas été touché ; le nouveau binaire n'existe que dans les artefacts des runs.

### O.6 État après J9

- Pages : `build_type=legacy`, source `gh-pages:/` — inchangé ; `gh-pages` = `94a84b6` — inchangé ; dernier déploiement Pages : 2026-09-19 — aucun nouveau.
- Aucune PR, aucun merge, aucune correction fonctionnelle (GPS, TER, BRT, arrêts, gares, tracés, DakarBounds, UI), aucun J1-J8/J10.
- Fichiers locaux non commités (volontairement, non autorisés) : `docs/AUDIT_GPS_HORS_DAKAR_2026-09-22.md`, `docs/AUDIT_SOURCE_FLUTTER_GPS_2026-09-22.md`, `docs/AUDIT_TER_BRT_DONNEES_2026-09-22.md`.

---

## P. Vérification de la configuration GitHub Pages avant bascule (lecture seule, 2026-09-22)

Vérifié via l'API GitHub (`GET /repos/aydiarra-star/dakar-bus/pages`, `/pages/builds/latest`, `/branches/gh-pages`, `/environments/github-pages`, `/environments/github-pages/deployment-branch-policies`, `/deployments?environment=github-pages`) et la description OpenAPI officielle de `PUT /repos/{owner}/{repo}/pages`. **Rien n'a été changé.**

### P.1 Configuration actuelle

| Élément | Valeur constatée |
|---|---|
| Mode (`build_type`) | `legacy` (« Deploy from a branch ») |
| Source | branche `gh-pages`, chemin `/` |
| Branche `gh-pages` | `94a84b6070569bed708b8e779b9e70b7c9dafa45` (2026-09-19 12:14:28 Z, non protégée) |
| Dernier build Pages (legacy) | `built`, commit `94a84b6`, 2026-09-19 12:14:29 Z, 18 s, pusher `arena-ai-coding-agent[bot]` |
| Déploiement actif (environnement `github-pages`) | id `6540734411`, `sha 94a84b6`, `ref gh-pages`, statut `success`, créé par `github-pages[bot]` |
| URL | `https://aydiarra-star.github.io/dakar-bus/` (`cname: null`, `https_enforced: true`, `public: true`, `custom_404: false`, `protected_domain_state: null`) |
| Dépôt | public, propriétaire = compte utilisateur, `default_branch: main`, `has_pages: true` |
| Environnement `github-pages` | existe ; `deployment_branch_policy: custom_branch_policies: true` ; branches autorisées : **`gh-pages`, `main`** (2 règles) ; aucun relecteur requis, pas de délai |
| Workflow système | `pages-build-deployment` (dernier run 35442297686, `success`, branche `gh-pages`) |

### P.2 Configuration cible

`build_type: workflow` (« GitHub Actions ») ; source de branche sans objet ; même URL `https://aydiarra-star.github.io/dakar-bus/` ; publication exclusivement par le job `deploy-pages` du workflow `flutter-web-build.yml` (manuel, `publish_pages=true`), qui déploie l'artefact `github-pages` (= `flutter-src/build/web`, 7,69 Mo, sortie brute de `flutter build web`).

### P.3 Le dépôt permet-il le mode GitHub Actions ? — OUI

- Dépôt public (Pages sur Actions disponible avec GitHub Free) ; Actions activées et actions tierces autorisées (vérifié empiriquement : runs `35782638226`/`35783905099` avec `subosito/flutter-action` ; l'endpoint `actions/permissions` renvoie 403 au jeton du sandbox).
- L'environnement `github-pages` existe déjà (créé par les déploiements précédents).
- **Limite du sandbox** : le jeton utilisé ici n'est pas administrateur (`permissions.admin=false`, 403 sur les endpoints d'administration) → la bascule (`PUT /pages`) **ne peut pas être exécutée depuis ici** ; elle doit l'être par le propriétaire (interface ou jeton personnel `repo`).

### P.4 Le workflow actuel est-il compatible ? — OUI, avec UNE réserve

- Conforme au modèle officiel : `actions/upload-pages-artifact@v3` (artefact `github-pages`, produit avec succès dans les deux runs) + `actions/deploy-pages@v4`, permissions `pages: write` + `id-token: write` limitées au job, `environment: github-pages`, `concurrency`, `needs: build`, `permissions: contents: read` au niveau racine. Garde-fou : `GET /pages` (`pages: read` suffit) doit renvoyer `build_type == workflow`, sinon arrêt sans publication.
- **Réserve — politique de branches de l'environnement** : `github-pages` n'autorise que `gh-pages` et `main`. Un `deploy-pages` déclenché depuis `arena/01a0ca19-dakar-bus` serait **refusé par la règle de branche avant toute étape** (« Branch … is not allowed to deploy to github-pages due to environment protection rules »). Pour publier depuis la branche de travail il faut, en plus de la bascule, **ajouter une règle de branche** `arena/01a0ca19-dakar-bus` à l'environnement (Settings → Environments → github-pages → Deployment branches and tags → Add rule ; API : `POST /repos/…/environments/github-pages/deployment-branch-policies {"name":"arena/01a0ca19-dakar-bus","type":"branch"}`). Alternative : publier depuis `main` après fusion (fusion non autorisée à ce stade).

### P.5 Action exacte nécessaire pour la bascule (NON effectuée)

1. Interface : Settings → Pages → Build and deployment → Source : « Deploy from a branch » → **« GitHub Actions »**.
   API équivalente (administrateur/mainteneur ou permission « manage GitHub Pages settings ») : `PUT /repos/aydiarra-star/dakar-bus/pages` avec `{"build_type":"workflow"}` (`gh api -X PUT repos/aydiarra-star/dakar-bus/pages -f build_type=workflow`) → réponse `204`.
2. (Pour publier depuis la branche de travail) ajouter la règle de branche décrite en P.4.
3. Aucune modification de fichier, de `gh-pages`, ni du workflow n'est nécessaire pour la bascule elle-même.
4. Retour arrière : `Source → Deploy from a branch → gh-pages / (root)` (API : `PUT /pages {"build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}`) → `pages-build-deployment` republie `94a84b6` automatiquement (~20 s observés).

### P.6 La bascule déclenche-t-elle un déploiement ? — NON

Le mode « GitHub Actions » n'associe aucun workflow à Pages (documentation officielle) : rien n'est publié tant qu'un workflow n'appelle pas `actions/deploy-pages`. Dans `flutter-web-build.yml`, ce job ne s'exécute que sur `workflow_dispatch` avec `publish_pages=true` ; les pushes et PR ne publient jamais. Le workflow système `pages-build-deployment` cesse d'être déclenché par les pushes sur `gh-pages`.

### P.7 La bascule peut-elle modifier ou supprimer le site actuel ? — branche NON ; site servi : INCERTAIN

- La branche `gh-pages` n'est **jamais modifiée** par un changement de mode (Pages ne réécrit pas sa source) ; son contenu (bundle OSRM, patches, anciens artefacts) reste intact jusqu'à J10.
- Le site actuellement servi : la documentation officielle ne précise pas si le dernier déploiement legacy reste servi après la bascule. Les retours de terrain divergent (certains rapportent une continuité de service, d'autres un `404` jusqu'au premier `deploy-pages`). **À traiter comme une interruption possible** entre la bascule et la première publication → recommandation : n'effectuer la bascule que dans la même fenêtre validée que la première publication (bascule → règle de branche → `gh workflow run flutter-web-build.yml --ref arena/01a0ca19-dakar-bus -f publish_pages=true`, ~2 min), avec le retour arrière P.5.4 disponible.
- La première publication Actions **remplace intégralement** le site servi par le contenu de l'artefact : `osrm/`, `tools/`, `service-worker.js`, le `main.dart.js` patché ne seront plus servis (ils restent dans la branche). Conséquences fonctionnelles (OSRM direct, service worker) : voir M.4/M.5 — décision J10.

### P.8 URL

Inchangée dans les deux modes : `https://aydiarra-star.github.io/dakar-bus/` (site de projet, pas de domaine personnalisé) ; `--base-href /dakar-bus/` du build reste correct ; `https_enforced` conservé.

### P.9 Nécessité d'un déploiement immédiat ?

Non requis techniquement : la bascule seule ne publie rien. Mais à cause de P.7 (interruption possible du site legacy après bascule), il est **recommandé** de coupler la bascule et la première publication validée dans la même fenêtre, ou de ne pas basculer tant que la publication n'est pas décidée. Les artefacts `dakar-bus-web-*` des runs restent disponibles 30 jours indépendamment de Pages.

---

## Q. Tentative de bascule Pages + premier déploiement (2026-09-22, 21:17 UTC) — BLOQUÉE, rien n'a changé

| Étape | État | Preuve |
|---|---|---|
| 0. Réalignement local | **fait** | `git fetch origin` → `origin/arena/01a0ca19-dakar-bus` = `34a6190` (= API) ; branche locale réalignée par `update-ref` + `reset` (index seulement, arbre de travail intact) ; seule différence locale : section P du rapport (61 insertions, 0 suppression) |
| 1. Règle d'environnement `arena/01a0ca19-dakar-bus` | **bloquée** | `POST /repos/aydiarra-star/dakar-bus/environments/github-pages/deployment-branch-policies {"name":"arena/01a0ca19-dakar-bus","type":"branch"}` → **HTTP 403 « Resource not accessible by integration »** ; règles inchangées (`gh-pages`, `main`) |
| 2. Bascule Pages → GitHub Actions | **non faite (bloquée)** | sondage sans effet `PUT /pages {"https_enforced":true}` (valeur déjà en place) → **HTTP 403** ; configuration vérifiée identique avant/après (`legacy`, `gh-pages:/`, `https_enforced: true`). La bascule n'aurait de toute façon pas été effectuée sans la règle de l'étape 1 (publication impossible ensuite → interruption possible du site, cf. P.7/P.9) |
| 3. Déclenchement manuel du workflow | **bloquée d'avance** | sondage sans effet `PUT /actions/workflows/364594347/enable` (workflow déjà actif) → **HTTP 403** ⇒ le jeton n'a pas `actions: write`, aucun `workflow_dispatch` possible depuis l'environnement d'audit |
| 4-5. Validation du déploiement | **non exécutées** | aucun déploiement n'a eu lieu |

Cause unique : le jeton de l'environnement d'audit est celui de l'application GitHub `arena-ai-coding-agent[bot]`, qui dispose de `contents: write` (les pushes fonctionnent) mais **pas** des permissions dépôt *Administration* (règles d'environnement), *Pages* (bascule) ni *Actions* (déclenchement manuel).

État après la tentative (vérifié) : Pages `legacy` / `gh-pages:/` ; règles d'environnement `gh-pages`, `main` ; `gh-pages` = `94a84b6` ; workflow `Flutter web build (J9)` actif ; aucun run lancé ; site public inchangé (`version.json` servi = `{"app_name": "dakarbus", …}` indenté — fichier édité à la main, repère utile : le build Actions sert `{"app_name":"dakar_bus","version":"9.3.2","build_number":"12","package_name":"dakar_bus"}` compact).

### Q.1 Actions requises du propriétaire (exactes, dans cet ordre, dans la même fenêtre)

1. **Règle d'environnement** — Settings → Environments → `github-pages` → Deployment branches and tags → *Add deployment branch or tag rule* → Ref type *Branch* → `arena/01a0ca19-dakar-bus` → Add rule.
   API : `gh api -X POST repos/aydiarra-star/dakar-bus/environments/github-pages/deployment-branch-policies -f name='arena/01a0ca19-dakar-bus' -f type=branch`
2. **Bascule Pages** — Settings → Pages → Build and deployment → Source → **GitHub Actions** (ne rien supprimer ; `gh-pages` reste intacte).
   API : `gh api -X PUT repos/aydiarra-star/dakar-bus/pages -f build_type=workflow`
3. **Premier déploiement** (immédiatement après, pour limiter toute interruption) — Actions → *Flutter web build (J9)* → *Run workflow* → Branch `arena/01a0ca19-dakar-bus` → cocher `publish_pages` → Run.
   API : `gh workflow run flutter-web-build.yml --ref arena/01a0ca19-dakar-bus -f publish_pages=true`
   Le workflow exécute lui-même : Flutter 3.24.5 → `pub get --enforce-lockfile` → `analyze` → `test` → `build web --release --base-href /dakar-bus/` → contrôles `version.json`/`dakar_network.json`/empreintes → `upload-pages-artifact` → garde-fou `build_type == workflow` → `deploy-pages`. Aucune modification post-build.

Alternative (plus large que nécessaire, non recommandée) : accorder à l'application `arena-ai-coding-agent` les permissions *Administration (write)*, *Pages (write)* et *Actions (write)* sur le dépôt.

Retour arrière si nécessaire : Settings → Pages → Source → *Deploy from a branch* → `gh-pages` / `/ (root)` → republication automatique de `94a84b6` (~20 s).

### Q.2 Ce qui pourra être vérifié depuis l'environnement d'audit une fois les 3 actions faites

API GitHub : statut du run et des jobs `build`/`deploy-pages`, `GET /pages` (`build_type`, `status`), déploiements de l'environnement `github-pages` (nouveau déploiement `success`, `environment_url`), `gh-pages` toujours `94a84b6`, annotations (empreinte `main.dart.js`, `version.json`). Site public : le sandbox n'atteint pas `github.io` (HTTP 000) mais le lecteur web externe fonctionne (`version.json`, `index.html`) — comparaison `version.json` servi ↔ généré, `<base href="/dakar-bus/">`, présence de `main.dart.js`/`flutter_bootstrap.js`.

---

## Réponse à la question finale

> « Si je modifie `lib/main.dart` demain, puis-je reconstruire et republier sans modifier manuellement `main.dart.js` ? »

**Reconstruire : OUI — prouvé.** Preuves (section O) : deux runs GitHub Actions réels sur le source commité, Flutter 3.24.5 épinglé et contrôlé, `flutter pub get` (puis `--enforce-lockfile` avec le `pubspec.lock` commité), `flutter analyze` 0 issue, `flutter test` 232/232, `flutter build web --release` OK, `version.json` généré depuis `pubspec.yaml`, empreintes recalculées identiques avant l'artefact Pages (zéro post-traitement), et `main.dart.js` **byte-identique entre les deux runs** (`a5ee5158…`). Une modification de `lib/main.dart` poussée sur la branche relance automatiquement exactement cette chaîne ; le `main.dart.js` obtenu est uniquement celui écrit par `flutter build web`.

**Republier : NON, pas encore — un seul point manque** : la décision sur le mode GitHub Pages. Le site est en mode `legacy` (branche `gh-pages`, contenu patché + bundle OSRM à préserver jusqu'à J10). Le job `deploy-pages` du workflow est prêt (manuel, `publish_pages=true`) mais refuse de publier tant que Pages n'est pas en mode « GitHub Actions » (`build_type: workflow`) — changement documenté en K, **non appliqué, à valider**. Une fois validé et appliqué : `gh workflow run flutter-web-build.yml --ref <branche> -f publish_pages=true` publie l'artefact tel quel, sans aucune intervention sur `main.dart.js`.

**ARRÊT.** Commits/push limités à la branche de travail (autorisés) ; aucun déploiement, aucune modification de `gh-pages` ni du mode Pages, aucune PR, aucun merge, aucune correction J1-J8/J10, aucune modification de `main.dart.js`.
