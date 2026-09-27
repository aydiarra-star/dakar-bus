# data/transit/passbi — GTFS publics récupérés (Lot 4.17)

Jeu de fichiers **réellement récupéré** le 2026-09-27 depuis le dépôt public
`https://github.com/impactsolutionsas/passbi_core` (dossier `gtfs_folder/`,
commit `7a2b998` du 2026-02-10), après découverte via PassBi
(`senpassbi.com`, Google Play, documentation API `impactsolutionsas.github.io/passbi_core`).

**Provenance complète (source, source_url, source_type, date_source, date_verified,
valid_from, valid_to, confidence, verification_note) : voir `MANIFEST.json`.**

## Contenu

| Fichier | Réseau | Lignes | Calendrier | Statut |
|---|---|---|---|---|
| `gtfs_TER.zip` | TER (SETER) | 6 routes / 26 stops / 572 trips / 7 332 stop_times | 2025-08-18 → 2025-08-31 | EXPIRÉ |
| `gtfs_BRT.zip` | BRT (B1, B2 seulement) | 2 routes / 79 stops / 4 036 trips / 58 674 stop_times | 2024-10-24 → 2024-12-31 | EXPIRÉ |
| `gtfs_Dem_Dikk.zip` | DDD | 53 routes / 1 277 stops / 9 529 trips / 314 029 stop_times | 2022-01-01 → 2023-12-31 | HISTORIQUE EXPIRÉ |
| `gtfs_AFTU.zip` | AFTU | 73 routes / 2 401 stops / 11 077 trips / 677 918 stop_times | 2022-01-01 → 2023-12-31 | HISTORIQUE EXPIRÉ |

Empreintes SHA-256 : dans `MANIFEST.json` (copies bit-à-bit des fichiers source).

## Règles d'usage (obligatoires)

1. **Structure uniquement** pour l'avenir : ces calendriers sont expirés, ils ne
   produisent aucun départ planifié 2026. Statut d'exploitation : ABSENCE DE DONNÉE.
2. **Aucun temps réel** : ni timestamp, ni position, ni prédiction. L'API PassBi de
   production est suspendue (« This service has been suspended. », vérifié le
   2026-09-27). Ne jamais présenter ces fichiers comme GTFS-RT.
3. **Jamais de fréquence → prochain passage** à partir de ces données.
4. **B3 n'existe pas dans ce feed** (B1/B2 uniquement) : ne jamais déduire B3 de B1/B2.
5. Toute lecture doit conserver la provenance de `MANIFEST.json`.
6. `data/gtfs/` (legacy) n'est pas impacté par ce dossier ; les deux jeux ne sont
   pas fusionnés sans preuve d'équivalence.

## Référence

Rapport : `docs/AUDIT_PUBLIC_MOBILITY_DATA_4_17_2026-09-27.md`
