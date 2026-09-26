# Couche CETUD CURRENT — ABSENTE

État au 2026-09-26 : **CETUD CURRENT : NON RÉCUPÉRABLE PUBLIQUEMENT** (voir `docs/LOT18_CETUD_CURRENT_2026-09-26.md`).

Aucun `feed-manifest.json` n'est présent : le provider ne dispose d'aucune source `currentOfficial`
et l'assistant répond « Je n'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis. »

## Installation d'un feed officiel (quand il sera obtenu)

```
node scripts/gtfs/install-cetud-feed.js \
  --zip /chemin/gtfs_aftu.zip --network AFTU \
  --url <URL officielle ou référence de la remise> \
  --published-at YYYY-MM-DD --version <version publiée> \
  [--license <licence>] [--retrieved-at YYYY-MM-DD]
```

L'installateur : refuse un ZIP invalide (tables requises, références, heures, calendrier),
copie le ZIP **inchangé** dans `data/external/gtfs/cetud/<réseau minuscule>/`, calcule le SHA-256,
lit `valid_from`/`valid_to` dans le feed lui-même (calendar/calendar_dates/feed_info), et n'écrit
`status: CURRENT` / `role: CURRENT_OFFICIAL` que si la validité couvre la date d'installation
et qu'une publication est prouvée (`--published-at`). Sinon : `status: UNKNOWN` (jamais CURRENT).
Vérification ensuite : `npm run gtfs:cetud:check`.
