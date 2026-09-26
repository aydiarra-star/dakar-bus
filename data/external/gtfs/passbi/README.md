# Couche PassBi — HISTORICAL / REFERENCE_GTFS

- Source : PassBi (Impact Solutions SAS), dépôt public `impactsolutionsas/passbi_core` — **SOURCE_APPLICATION**, jamais officiel.
- Statut : **HISTORICAL** (validités internes 2022–2023 pour AFTU/DDD, fin 2024 pour BRT, août 2025 pour TER).
- Usage : fixture, comparaison, développement. Ne fournit **jamais** un départ « actuel » ; jamais promu automatiquement.
- Les ZIP bruts ne sont pas copiés ici : `feed-manifest.json` pointe vers
  `audit/external-feeds/source/passbi_core/gtfs_folder/*.zip` (octet pour octet, SHA-256 re-vérifié à chaque chargement).
- Contrôle : `npm run gtfs:passbi:check`.
