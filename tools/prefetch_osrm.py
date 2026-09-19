#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Prefetch des géométries — logique séparée par mode (correctif tracés v4).

  * AFTU, DDD, TATA (bus sur voirie) : routage routier OSRM, profil driving,
    via le routeur public (requêtes HTTP régulées, comme avant).
  * TER (train) : JAMAIS de routage routier. Géométries découpées localement
    dans assets/assets/data/ter_rail_shapes.json (forme de la voie ferrée,
    format inspiré de GTFS shapes.txt). Aucun appel réseau pour ces paires.
  * BRT (site propre) : JAMAIS de routage routier (voies dédiées inconnues
    d'OSRM -> détours jusqu'à 3,1x). Géométries découpées localement dans
    assets/assets/data/brt_dedicated_shapes.json, arrêts triés par
    stop_sequence. Aucun appel réseau pour ces paires.

Écrit assets/assets/data/osrm_geometries.json (schéma 2 : geometries +
provenance par URL) puis matérialise osrm/route/v1/driving/* (URL appelées par
l'app depuis le correctif v3). Met à jour GEOM_VERSION dans
flutter_service_worker.js (hachage du bundle). Déterministe et rejouable.

Exécuté par le workflow GitHub Actions « PrefetchOSRM geometries ».
"""
import json
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from track_shapes import (  # noqa: E402
    OSRM_PREFIX,
    build_track_geometries,
    classify_network_pairs,
    load_shapes,
)

ROOT = Path(__file__).resolve().parent.parent
PAIRS = ROOT / "assets" / "assets" / "data" / "osrm_pairs.json"
OUT = ROOT / "assets" / "assets" / "data" / "osrm_geometries.json"
NETWORK = ROOT / "assets" / "assets" / "data" / "dakar_network.json"
SW = ROOT / "flutter_service_worker.js"
# Correctif v3 : l'app appelle /dakar-bus/osrm/route/v1/driving/<lng,lat;lng,lat>.
# Le dépôt doit donc contenir ces fichiers (repli sans service worker).
STATIC_DIR = ROOT / "osrm" / "route" / "v1" / "driving"

TIMEOUT = 10          # secondes par requête
RETRIES = 4           # tentatives supplémentaires sur 429/5xx/réseau
CONC = 2              # requêtes concurrentes (discipline anti rate-limit)
SPACING = 0.4         # espacement après chaque complétion (secondes)
MIN_RATIO = 0.5       # échec si moins de 50 % des paires routières récupérées

UA = "dakar-bus-prefetch/4.0 (+https://aydiarra-star.github.io/dakar-bus/)"


def fetch_osrm(url, attempt=0):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            data = json.loads(r.read().decode("utf-8"))
        if data.get("code") == "Ok" and data.get("routes"):
            return data
        raise ValueError("reponse OSRM invalide code=%s" % data.get("code"))
    except Exception as e:
        code = getattr(e, "code", None)
        retryable = code in (429, 500, 502, 503, 504) or code is None
        if attempt < RETRIES and retryable:
            time.sleep(1.5 * (attempt + 1))
            return fetch_osrm(url, attempt + 1)
        raise


def worker(url):
    try:
        data = fetch_osrm(url)
        time.sleep(SPACING)
        return url, data, None
    except Exception as e:
        return url, None, str(e)


def write_static_files(geometries):
    """Matérialise chaque géométrie sous l'URL que l'app appelle.

    Retourne True si un fichier a changé (écrit ou supprimé)."""
    STATIC_DIR.mkdir(parents=True, exist_ok=True)
    expected = set()
    changed = False
    for url, payload in geometries.items():
        if not url.startswith(OSRM_PREFIX):
            continue
        coords = url[len(OSRM_PREFIX):].split("?", 1)[0]
        if not coords or "/" in coords:
            continue
        expected.add(coords)
        target = STATIC_DIR / coords
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if not target.exists() or target.read_text(encoding="utf-8") != body:
            target.write_text(body, encoding="utf-8", newline="")
            changed = True
    for stale in STATIC_DIR.iterdir():
        if stale.name not in expected:
            stale.unlink()
            changed = True
    print("Fichiers statiques : %d dans %s" % (len(expected), STATIC_DIR.relative_to(ROOT)))
    return changed


def main():
    network = json.loads(NETWORK.read_text(encoding="utf-8"))
    pairs = json.loads(PAIRS.read_text(encoding="utf-8"))
    track_urls, road_urls, shared = classify_network_pairs(network)
    print("Paires guidees (TER/BRT, locales) : %d" % len(track_urls))
    print("Paires routieres (OSRM driving) : %d" % len(road_urls))
    if shared:
        print("Paires partagees (priorite site propre) : %d" % len(shared))

    # Garde-fou : la liste canonique doit couvrir exactement le réseau.
    if set(pairs) != track_urls | road_urls:
        sys.exit("ECHEC : osrm_pairs.json incohérent avec dakar_network.json "
                 "(%d vs %d)" % (len(pairs), len(track_urls | road_urls)))

    # 1. Modes guidés : découpe locale, aucun appel réseau.
    shapes = load_shapes()
    for op, shape in shapes.items():
        print("Forme %s : %d points, %d arrets, %.1f km"
              % (shape.shape_id, len(shape.points),
                 len(shape.ordered_stop_ids()), shape.full_length_m() / 1000))
    geometries, provenance = build_track_geometries(network, shapes)
    print("Geometries guidees construites localement : %d (0 appel reseau)"
          % len(geometries))

    # 2. Modes routiers : routeur public OSRM, profil driving.
    road_list = sorted(road_urls)
    failures = []
    with ThreadPoolExecutor(max_workers=CONC) as pool:
        for url, data, err in pool.map(worker, road_list):
            if data is not None:
                geometries[url] = data
                provenance[url] = "osrm-driving"
            else:
                failures.append((url, err))

    ok_road = len(road_list) - len(failures)
    print("Geometries routieres recuperees : %d/%d" % (ok_road, len(road_list)))
    for url, err in failures[:10]:
        print("  ECHEC %s -> %s" % (url, err))
    if failures:
        print("::warning title=PrefetchOSRM::%d paires routieres en echec (rejouable)"
              % len(failures))
    if ok_road < int(len(road_list) * MIN_RATIO):
        sys.exit("ECHEC : moins de %d%% des geometries routieres, aucun commit"
                 % int(MIN_RATIO * 100))

    out_text = canonical_bundle_text(geometries, provenance, pairs)
    geom_version = geom_version_for(out_text)

    changed = False
    if not OUT.exists() or OUT.read_text(encoding="utf-8") != out_text:
        OUT.write_text(out_text, encoding="utf-8")
        changed = True
        print("Bundle ecrit : %s (%d octets, %d geometries)"
              % (OUT.name, len(out_text), len(geometries)))

    sw = SW.read_text(encoding="utf-8")
    sw_new = re.sub(r"(const GEOM_VERSION = ')[^']*(')",
                    r"\g<1>" + geom_version + r"\g<2>", sw, count=1)
    if sw_new != sw:
        SW.write_text(sw_new, encoding="utf-8")
        changed = True
        print("GEOM_VERSION mise a jour : %s" % geom_version)

    changed |= write_static_files(geometries)

    if not changed:
        print("Geometries inchangees (GEOM_VERSION identique) : rien a commiter.")
    print("::notice title=PrefetchOSRM::%d/%d geometries (dont %d guidees locales), "
          "GEOM_VERSION=%s" % (len(geometries), len(pairs), len(track_urls), geom_version))


if __name__ == "__main__":
    main()
