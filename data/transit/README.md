# Couche de données de travail — Dakar Bus Transit Data Layer

**Lot 4.4** · généré le 2026-09-27 · **statut : référentiel de travail, PAS une publication GTFS usager**

Cette couche rassemble les données PassBi et les sources actuelles en **trois niveaux strictement
séparés**. Elle n'alimente **aucune** partie de l'application : ni `main.dart`, ni le routage, ni
le GPS, ni l'interface, ni `dakar_network.json`.

Rapport complet : [`docs/DAKAR_BUS_TRANSIT_DATA_LAYER_4_4.md`](../../docs/DAKAR_BUS_TRANSIT_DATA_LAYER_4_4.md)

---

## Les trois niveaux

| Niveau | Dossier | Contenu | Peut alimenter l'usager ? |
|---|---|---|---|
| **1 — RAW / HISTORICAL** | `passbi/` | Données PassBi telles quelles, identifiants d'origine conservés (21 fichiers) | **NON** |
| **2 — VALIDATED REFERENCE** | `validated/` | Éléments confirmés ou partiellement confirmés par des sources actuelles | **NON, sauf liste explicite** |
| **3 — PRODUCTION READY** | `production/` | Ce qui est suffisamment documenté pour l'expérience usager | **OUI, pour 4 entités seulement** |

**Ne jamais mélanger les trois niveaux.** Un élément ne monte d'un niveau que sur preuve.

---

## Arborescence

```
data/transit/
├── README.md                     ← ce fichier
├── MANIFEST.json                 ← empreintes SHA-256, blobs Git, re-téléchargement
├── reference-policy.json         ← PRÉEXISTANT (2026-09-21), non modifié
├── schema/
│   └── provenance.schema.json    ← modèle de provenance + vocabulaire des statuts
├── tools/
│   └── build_transit_layer.py    ← générateur reproductible
├── passbi/                       ← LEVEL 1
│   ├── ter/   agency routes stops calendar
│   ├── brt/   agency routes stops calendar_dates transfers
│   ├── ddd/   agency routes stops calendar calendar_dates fare_attributes
│   └── aftu/  agency routes stops calendar calendar_dates fare_attributes
├── crosswalk/
│   └── crosswalk.json            ← 186 correspondances, 6 types d'appariement
├── validated/                    ← LEVEL 2
│   ├── gtfs/                     ← GTFS structurel (agency routes stops trips
│   │                                stop_times calendar calendar_dates)
│   ├── structure/
│   │   ├── ter_stop_mapping.json     13 gares, crosswalk, comparaison de coordonnées
│   │   ├── ter_schedule.json         deux niveaux d'horaires séparés
│   │   ├── brt_route_structure.json  B1 / B2 / B3, stations physiques
│   │   ├── ddd_routes.json           34 persistantes + 19 NOT_FOUND
│   │   └── aftu_raw_registry.json    73 lignes, identité non établie
│   ├── route_status.json         ← 130 routes × 4 dimensions indépendantes
│   └── BUILD_SUMMARY.json
└── production/                   ← LEVEL 3
    └── production_ready.json     4 prêtes / 7 non prêtes
```

---

## Les quatre dimensions indépendantes

Aucune n'est déduite d'une autre.

```
IDENTITÉ    Qui est cette ligne ?
STRUCTURE   Quels sont ses arrêts, son parcours, ses directions ?
HORAIRE     Quand passe-t-elle ?
TEMPS RÉEL  Où est-elle maintenant ?
```

Exemple — **TER** : `identity = CONFIRMED`, `structure = CONFIRMED`,
`schedule = PARTIALLY_CONFIRMED`, `realtime = UNKNOWN`.
La solidité de la structure **n'entraîne pas** la confirmation de l'horaire.

---

## Statuts

| Statut | Sens |
|---|---|
| `CONFIRMED` | source actuelle fiable confirmant explicitement la donnée |
| `PERSISTENT` | donnée PassBi ancienne retrouvée dans une source actuelle, sans contradiction |
| `PARTIALLY_CONFIRMED` | une partie est confirmée, pas l'ensemble |
| `UNCONFIRMED` | conservée comme référence, validation actuelle insuffisante |
| `CONTRADICTED` | une source actuelle fournit une information différente |
| `NEW` | apparue après PassBi, confirmée par une source actuelle |
| `UNKNOWN` | impossible de déterminer l'état actuel |
| `NOT_FOUND` | absente des sources vérifiées — **ne signifie jamais « supprimée »** |

## Types de source

`OFFICIAL_OPERATOR` · `INSTITUTIONAL` · `PASSBI` · `OSM` · `HYBRID`

**`PASSBI` ne devient jamais `OFFICIAL_OPERATOR`** au motif que PassBi revendique l'usage de
données CETUD.

---

## Règles structurantes

1. **Identifiants publics.** Les UUID PassBi ne sont **pas** exposés comme identifiants publics.
   L'identifiant public est celui déjà utilisé par `dakar_network.json` ; l'UUID PassBi reste
   dans `passbi_stop_id` et dans le crosswalk.
2. **Une station physique, plusieurs routes.** Les stations partagées par B1 et B2 portent le
   même `dakar_bus_stop_id`. B1, B2 et B3 restent trois `route_id` distincts.
3. **Aucune fusion sur la seule proximité.** Deux stations PassBi peuvent se résoudre sur le
   même arrêt du projet ; elles ne sont pas fusionnées sans preuve opérateur.
4. **Une fréquence n'est jamais un horaire.** Les fréquences opérateur donnent `ESTIMATED`,
   jamais `SCHEDULED`.
5. **Convention GTFS des heures.** Les heures ≥ 24:00 (`25:xx`, `26:xx`) sont conservées telles
   quelles, jamais converties en heure civile du jour suivant.
6. **Crosswalk.** `COORDINATE_ONLY` et `NAME_ONLY` ne suffisent pas à identifier une ligne.
   `NUMBER_ONLY` ne suffit **jamais**.
7. **Temps réel.** `REAL_TIME = NON` sur toute la couche. Aucun flux actif n'est identifié.

---

## Reproduction

```bash
# 1. récupérer les 4 archives PassBi (empreintes dans MANIFEST.json)
mkdir -p /tmp/passbi_gtfs && cd /tmp/passbi_gtfs
gh api repos/impactsolutionsas/passbi_core/git/blobs/<git_blob> --jq .content | base64 -d > gtfs_TER.zip
# … idem pour BRT, Dem_Dikk, AFTU

# 2. régénérer la couche
python3 data/transit/tools/build_transit_layer.py /tmp/passbi_gtfs

# 3. valider
npm test        # 52 tests : 24 applicatifs existants + 28 tests de données
```

---

## ⚠ Blocage licence

Le dépôt PassBi annonce une licence MIT mais **ne contient aucun fichier `LICENSE`**, et aucune
licence ne couvre les **données**. Toute **republication externe** de cette couche est bloquée
tant que la licence n'est pas clarifiée. L'usage interne de travail n'est pas concerné.

## ⚠ Ce que cette couche n'est pas

- **Pas** un feed GTFS publiable en l'état : seuls 4 éléments sont `PRODUCTION READY`.
- **Pas** une source d'horaires : aucun `stop_times` ne peut être affiché comme certifié.
- **Pas** du temps réel.
- **Pas** mélangée à `data/gtfs/` (feed synthétique `2.1-dakar-pwa-gtfs-rt`), laissé intact.
