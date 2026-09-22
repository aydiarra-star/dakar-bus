# AUDIT J9 — CHAÎNE DE BUILD REPRODUCTIBLE (Flutter → GitHub Pages)

- Date : 2026-09-22
- Branche de travail : `arena/01a0ca19-dakar-bus` (HEAD `ce8c94f` = `main`), **aucun commit, aucun push**
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
- Traitement dans le workflow (aucune version changée arbitrairement ; `pubspec.yaml` intact) :
  - si `flutter-src/pubspec.lock` est présent → `flutter pub get --enforce-lockfile` (résolution imposée, build reproductible) ;
  - s'il est absent → `flutter pub get` normal + `::warning::` + le `pubspec.lock` généré par Flutter 3.24.5 est affiché dans le log et publié comme artefact `pubspec.lock`, **à vérifier puis commiter dans `flutter-src/` après validation** (étape humaine, pas de commit automatique).
- Dépendances déclarées (inchangées) : `flutter` (sdk), `cupertino_icons ^1.0.8`, `flutter_map ^6.1.0`, `geolocator ^12.0.0`, `http ^1.2.2` ; dev : `flutter_test` (sdk), `flutter_lints ^4.0.0`.

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

**Non exécutées** (impossible ici, sans SDK) : `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web`. Aucune de ces commandes n'a été lancée ; **la validation réelle sera faite par le premier run de GitHub Actions** après push (validation à donner). Je ne prétends à aucun résultat local.

## H. Résultat `flutter test`

- **Non exécuté localement** (cf. G).
- Résultat connu le plus récent sur ce même source (`ac03557`, CI de la base B `flutter-verify.yml`, résumé récupéré via l'API GitHub, `/tmp/checkrun_ac03557.txt`) : `flutter analyze` → « No issues found! » ; `flutter test` → **232 tests, 232 réussis, 0 échec**, 9 fichiers de test, Flutter 3.24.5 stable.
- Le nouveau workflow rejoue `flutter test --reporter expanded` sur le même source ; le résultat attendu est identique, **à confirmer par le run**. Aucun test n'est ignoré, filtré ni contourné (pas de `--exclude-tags`, pas de `continue-on-error`).

## I. Résultat `flutter build web`

- **Non exécuté localement** (cf. G). `flutter build web` n'a jamais été exécuté sur B (constat mission 4) ; le premier run du workflow sera la première compilation web de `ac03557`.
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
| 1 | La chaîne n'a **pas été exécutée** : un échec au premier run (résolution pub, analyse, test, compilation web) reste possible tant que GitHub Actions ne l'a pas prouvée. | Validation | J9 — premier run |
| 2 | Sans `pubspec.lock` commité, deux runs peuvent résoudre des versions différentes de `flutter_map`/`geolocator`/`http` (dans les bornes `^`). Le workflow le signale et fournit le lock à commiter. | Reproductibilité | J9 — étape 2 (validation humaine) |
| 3 | Mode Pages `legacy` : aucune publication possible depuis le workflow tant que le changement documenté en K n'est pas validé et appliqué. | Publication | J9/J10 — décision |
| 4 | Transition service worker : le site actuel enregistre un SW (`flutter_service_worker.js` prod + `service-worker.js` ad hoc). Après publication du nouveau build, le SW existant se mettra à jour avec le nouveau `flutter_service_worker.js` ; le `service-worker.js` ad hoc ne sera plus servi. Un rechargement peut être nécessaire chez les utilisateurs. | Runtime | J10 |
| 5 | Le bundle OSRM (`osrm/`) et les patches manuels de `gh-pages` ne font pas partie du build Flutter : le nouveau build appelle `router.project-osrm.org` directement (`data_service.dart` l.134). Fonctionnalité à réévaluer avant publication. | Fonctionnel | Hors périmètre (documenté mission 4) |
| 6 | `flutter-src/.github/workflows/deploy.yml` (hérité) est inerte tant que `flutter-src/` n'est pas à la racine ; s'il y était déplacé un jour, il déploierait automatiquement à chaque push sur `main`. | Latent | Hors périmètre |
| 7 | `transit-validation.yml` (PWA) échoue sur toute PR, y compris une PR Flutter : bruit de CI, pas de blocage du workflow J9. | CI | Hors périmètre |
| 8 | Différence visible après le premier build : `version.json` `app_name` passe de `dakarbus` (fichier servi, édité à la main) à `dakar_bus` (nom du pubspec) ; aucune incidence fonctionnelle (rien ne lit ce fichier). | Cosmétique | Information |
| 9 | Problèmes applicatifs déjà audités et **non corrigés** (rappel, hors J9) : GPS hors `DakarBounds` → position `null` ; 24 arrêts codés en dur (`main.dart` l.750-788) verrouillés par tests ; libellé « Dakar Bus v9.4 (Web Fix) » l.2796 ; horaires générés sous badge « Officiel » ; `_loadFallbackData` ; etc. | Applicatif | J1-J8 |
| 10 | Déclencheur `push` sur `arena/01a0ca19-dakar-bus` : dès que le push est validé et effectué, le job `build` s'exécute (sans publication). C'est voulu (premier run de validation). | Process | J9 |

## N. Prochaine étape (après validation explicite — rien n'est fait sans elle)

1. **Validation → commit + push** sur `arena/01a0ca19-dakar-bus` de : `flutter-src/` (20 fichiers), `.github/workflows/flutter-web-build.yml`, `docs/AUDIT_J9_BUILD_REPRODUCTIBLE_2026-09-22.md` (et, si souhaité, les 4 rapports précédents). Ne pas commiter `flutter-src/build/` (ignoré).
2. **Premier run** (automatique sur push) : lire le résumé ; si échec → corriger uniquement ce qui relève de la chaîne de build, jamais `main.dart.js`.
3. **Lockfile** : télécharger l'artefact `pubspec.lock` du premier run, le relire (versions résolues, `sha256` pub), le placer dans `flutter-src/pubspec.lock`, commiter → le run suivant passe en `--enforce-lockfile`.
4. **Décision Pages** : valider (ou non) le passage en mode « GitHub Actions » (K). Tant que non validé, aucune publication.
5. **Publication** (après 4) : `gh workflow run flutter-web-build.yml --ref <branche> -f publish_pages=true`, puis comparer les SHA-256 du site servi avec l'artefact `dakar-bus-web-checksums-<sha>`.
6. J10 (séparé) : traitement de la branche `gh-pages` (archive, bundle OSRM, anciens artefacts).

---

## Réponse à la question finale

> « Si je modifie `lib/main.dart` demain, puis-je reconstruire et republier sans modifier manuellement `main.dart.js` ? »

**Reconstruire : la chaîne est définie mais NON prouvée** — le workflow est écrit, validé syntaxiquement, verrouillé sur Flutter 3.24.5 et sans aucun post-traitement ; mais aucune commande Flutter n'a pu être exécutée ici.

**Republier : NON, pas encore.** Il manque exactement :

1. **Le premier run réel de GitHub Actions** (après votre validation du push) prouvant `pub get` → `analyze` → `test` (232 attendus) → `build web` → artefact sur `ac03557`/9.3.2+12.
2. **`flutter-src/pubspec.lock` commité** (fourni en artefact par ce premier run) pour que le build soit reproductible et non seulement automatisé.
3. **La décision sur le mode Pages** : passage de `legacy` (branche `gh-pages`) à « GitHub Actions » (`build_type: workflow`) — changement documenté en K, **non appliqué**. Sans lui, le job de publication refuse de publier ; l'alternative (pousser sur `gh-pages`) écraserait le contenu actuel et relève de J10.

Une fois ces trois points réglés, la réponse devient OUI : modification de `lib/main.dart` → push → build automatique → `main.dart.js` produit uniquement par `flutter build web`, empreinte SHA-256 vérifiée, publication manuelle par `publish_pages=true`.

**ARRÊT.** Aucun commit, aucun push, aucun déploiement, aucune modification de `gh-pages`, aucun merge, aucune correction J1-J8/J10 n'a été effectué.
