# audit/external-feeds — flux de transport externes récupérés (LOT 16 BIS)

Rapport complet : [`docs/AUDIT_FEEDS_CETUD_PASSBI_2026-09-26.md`](../../docs/AUDIT_FEEDS_CETUD_PASSBI_2026-09-26.md).

Ce dossier est **documentaire**. Il n'est lu par aucun code de production
(ni la PWA JavaScript historique, ni l'application Flutter `flutter-src/`,
ni `data/gtfs/`). Rien n'y a été importé dans `dakar_network.json`.

## Contenu

| Chemin | Nature | Origine |
|---|---|---|
| `source/passbi_core/gtfs_folder/gtfs_AFTU.zip` | GTFS statique AFTU — 73 routes, 2 401 arrêts, 11 077 trips, 677 918 stop_times, calendrier **2022-01-01 → 2023-12-31** (**HISTORICAL**) | dépôt GitHub public `impactsolutionsas/passbi_core` @ `4de3d96` (PassBi = **SOURCE_APPLICATION**) |
| `source/passbi_core/gtfs_folder/gtfs_Dem_Dikk.zip` | GTFS statique DDD — 53 routes, 1 277 arrêts, 9 529 trips, 314 029 stop_times, calendrier **2022-01-01 → 2023-12-31** (**HISTORICAL**) | idem |
| `source/passbi_core/gtfs_folder/gtfs_BRT.zip` | GTFS statique BRT — 2 routes (B1, B2), 79 arrêts, 4 036 trips, dates **2024-10-24 → 2024-12-31** (**HISTORICAL**) | idem |
| `source/passbi_core/gtfs_folder/gtfs_TER.zip` | GTFS statique TER (SETER) — 6 routes, 26 arrêts (13 gares × 2 quais), 572 trips, **2025-08-18 → 2025-08-31** (**HISTORICAL**) | idem |
| `source/passbi_core/docs/api/openapi.yaml` | Spécification OpenAPI 3.0.3 de l'API PassBi Core v2.0.0 (8 GET, sans authentification déclarée) | idem — serveur de production **suspendu** le 2026-09-26 |
| `source/cetud/plan-lignes-ddd.jpeg` | Image cartographique 1282×905 (87 217 octets) livrée par le bouton « Télécharger les lignes et horaires » de la page CETUD DDD — **carte, pas GTFS, aucun horaire** | copie identique en taille/dimensions obtenue via `demdikk.sn` (CETUD injoignable depuis le bac à sable) |
| `manifest.json` | Provenance complète de chaque fichier : `source_name`, `source_url`, `retrieved_at`, `published_at`, `valid_from`, `valid_to`, `sha256`, `file_size`, `format`, `networks`, `license`, `access_type`, notes de qualité, constats négatifs | généré le 2026-09-26 |
| `fetch_sources.sh` | Commandes de reproduction (clone épinglé + vérification SHA-256 ; `curl` des artefacts cetud.sn à exécuter hors bac à sable) | — |
| `analyze_feeds.py` | Script d'analyse (lecture seule des ZIP, de `dakar_network.json` et du référentiel officiel du 2026-09-25) ; écrit uniquement dans `reports/` | `python3 audit/external-feeds/analyze_feeds.py` |
| `reports/` | Sorties générées : `feed_summary.{md,json}`, `routes_*.{md,csv}`, `schedules_*.{md,csv}`, `comparison_{AFTU,DDD}.{md,csv}` | régénérables |

## Empreintes SHA-256

```
7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428  source/passbi_core/gtfs_folder/gtfs_AFTU.zip      (10 693 791 octets)
578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159  source/passbi_core/gtfs_folder/gtfs_Dem_Dikk.zip  ( 2 635 299 octets)
f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4  source/passbi_core/gtfs_folder/gtfs_BRT.zip       (   520 189 octets)
09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408  source/passbi_core/gtfs_folder/gtfs_TER.zip       (   109 650 octets)
b8cba8a1cd3abb012266d240fcc1dfab99798afc03690f5ab55e21ac3b063bd7  source/passbi_core/docs/api/openapi.yaml
6c40333cb4423e5bf4b33422eb70e20e08ab67c0c5d629ac06f901bbaf74f0f8  source/cetud/plan-lignes-ddd.jpeg                 (    87 217 octets)
```

## Règles de lecture

1. **Numéro de ligne = champ du flux** (`route_short_name` croisé avec `route_id` et
   `route_long_name`, cohérents pour les 73 routes AFTU et les 53 routes DDD). Jamais
   un identifiant interne Dakar Bus, jamais OSM/Moovit, jamais un rapprochement
   géométrique.
2. **Fréquence observée ≠ fréquence déclarée.** Aucun flux ne contient
   `frequencies.txt` : les fréquences des rapports sont *observées* (écarts entre
   départs successifs dans `stop_times.txt`). Seule fréquence *déclarée* connue :
   BRT « toutes les 6 minutes » (page CETUD), qui coïncide avec l'observation (6,0 min).
3. **Validité temporelle : HISTORICAL pour les 4 flux.** Ils ne décrivent pas l'offre
   2026 et ne doivent pas être présentés comme telle.
4. **Provenance : SOURCE_APPLICATION.** Le dépôt PassBi n'indique pas l'origine des
   fichiers ; l'origine CETUD n'est qu'alléguée par le site senpassbi.com.
5. **Licence : aucune déclarée.** Les copies sont conservées à des fins d'audit et
   de traçabilité ; toute réutilisation en production suppose une clarification des
   droits auprès de l'éditeur et/ou du CETUD.
