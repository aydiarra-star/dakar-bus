# Sauvegarde des sources Flutter récupérées

> **Ce dossier est une SAUVEGARDE FIDÈLE, pas une version améliorée.**
> Aucun fichier source n'a été modifié, reformaté, corrigé ou supprimé.
> Les 14 fichiers sont byte-pour-byte identiques aux blobs Git d'origine (SHA-1 vérifiés).

## Origine

Les sources Flutter de l'application publiée sur https://aydiarra-star.github.io/dakar-bus/
avaient été rendues inaccessibles par un **force-push sur `main`** le **2026-09-17 à 10:23:41 UTC**
(commit `d179fe1611a6d8ec99fbfe7d3aa747d118cebe6d`, « feat: Dakar Mobilité v3 »), qui a remplacé
l'intégralité de l'historique Flutter par la PWA HTML.

Les commits étaient devenus **orphelins** (non référencés par aucune branche) mais toujours
servis par l'API GitHub. Ils ont été récupérés par SHA puis rattachés à cette branche.

## Commit source restauré

| | |
|---|---|
| **SHA** | `2c72e576b3e6a7aca20071035a919205dd851455` |
| **Message** | `fix: lint curly braces → 0 issue (CI)` |
| **Date** | 2026-09-17T07:29:23Z |
| **Auteur** | aydiarra-star |
| **CI** | `Deploy to GitHub Pages` — **succès** (run `35194777042`) |
| **Version** | `pubspec.yaml` → `9.3.0+4` |

C'est le **dernier état source Flutter valide** avant la destruction de l'historique.

## Contenu restauré (14 fichiers)

```
.github/workflows/deploy.yml          analysis_options.yaml
.gitignore                            assets/data/dakar_network.json
README.md                             pubspec.yaml
lib/main.dart                         test/dakar_bounds_test.dart
lib/models/transport_network.dart     test/data_service_test.dart
lib/services/data_service.dart        test/widget_test.dart
web/index.html                        web/manifest.json
```

> Les fichiers sont placés sous `flutter-src/` uniquement pour **ne rien écraser** à la racine
> (`README.md` et `.gitignore` y existent déjà avec un contenu différent, conservé intact).
> L'arborescence interne du projet Flutter est strictement préservée.

## Historique

Les **260 commits** Flutter (de `0ea899d` « Initial commit » jusqu'à `2c72e57`) sont rattachés
à cette branche via un commit de fusion `-s ours`, qui les rend **atteignables et donc protégés
du garbage collector GitHub**, sans modifier l'arbre de travail existant.

```bash
git log 2c72e576b3e6a7aca20071035a919205dd851455        # 260 commits
git log --all --oneline -- lib/main.dart                # historique du fichier
git show 2c72e57:lib/main.dart                          # état d'origine
```

## Divergence source ↔ production (à traiter ultérieurement)

La production (`gh-pages`, **9.3.2 build 12**) porte 7 correctifs appliqués **uniquement par
patch regex sur `main.dart.js` minifié** (scripts `tools/apply_traces_v*.py`) : 13 gares TER,
23 stations SunuBRT, tracés OSRM v2→v6, refonte UI Trajets.

**Ces correctifs n'existent pas dans ces sources Dart.** Recompiler ce commit en l'état
provoquerait une régression. La gare fantôme `Gare TER Keur Massar`, présente dans le JS publié,
est **absente de ces sources** — elle a été introduite par les patchs.

Aucune action de correction n'a été entreprise à ce stade.
