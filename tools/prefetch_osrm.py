#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PrefetchOSRM geometries — récupère les vraies géométries OSRM de toutes les
paires d'arrêts (assets/assets/data/osrm_pairs.json) et les écrit dans
assets/assets/data/osrm_geometries.json (bundle préchargé que le service
worker v2 sème instantanément chez les clients). Met à jour GEOM_VERSION
dans flutter_service_worker.js (hachage du bundle) pour propager la mise à
jour. Déterministe et rejouable : ne modifie rien si les données OSRM
n'ont pas changé.

Exécuté par le workflow GitHub Actions « PrefetchOSRM geometries ».
"""
import hashlib
import json
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAIRS = ROOT / "assets" / "assets" / "data" / "osrm_pairs.json"
OUT = ROOT / "assets" / "assets" / "data" / "osrm_geometries.json"
SW = ROOT / "flutter_service_worker.js"

TIMEOUT = 10          # secondes par requête
RETRIES = 4           # tentatives supplémentaires sur 429/5xx/réseau
CONC = 2              # requêtes concurrentes (même discipline que le SW v1)
SPACING = 0.4         # espacement après chaque complétion (secondes)
MIN_RATIO = 0.5       # échec si moins de 50 % des géométries récupérées

UA = "dakar-bus-prefetch/2.0 (+https://aydiarra-star.github.io/dakar-bus/)"


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


def main():
    pairs = json.loads(PAIRS.read_text(encoding="utf-8"))
    print("Paires a precharger : %d" % len(pairs))

    geometries = {}
    failures = []
    with ThreadPoolExecutor(max_workers=CONC) as pool:
        for url, data, err in pool.map(worker, pairs):
            if data is not None:
                geometries[url] = data
            else:
                failures.append((url, err))

    ok = len(geometries)
    print("Geometries recuperees : %d/%d" % (ok, len(pairs)))
    for url, err in failures[:10]:
        print("  ECHEC %s -> %s" % (url, err))
    if failures:
        print("::warning title=PrefetchOSRM::%d paires en echec (rejouable)" % len(failures))
    if ok < int(len(pairs) * MIN_RATIO):
        sys.exit("ECHEC : moins de %d%% des geometries, aucun commit" % int(MIN_RATIO * 100))

    bundle = {"schema": 1, "count": ok, "geometries": geometries}
    out_text = json.dumps(bundle, ensure_ascii=False, separators=(",", ":")) + "\n"
    geom_version = "v2-" + hashlib.sha256(out_text.encode("utf-8")).hexdigest()[:12]

    changed = False
    if not OUT.exists() or OUT.read_text(encoding="utf-8") != out_text:
        OUT.write_text(out_text, encoding="utf-8")
        changed = True
        print("Bundle ecrit : %s (%d octets, %d geometries)" % (OUT.name, len(out_text), ok))

    sw = SW.read_text(encoding="utf-8")
    sw_new = re.sub(r"(const GEOM_VERSION = ')[^']*(')",
                    r"\g<1>" + geom_version + r"\g<2>", sw, count=1)
    if sw_new != sw:
        SW.write_text(sw_new, encoding="utf-8")
        changed = True
        print("GEOM_VERSION mise a jour : %s" % geom_version)

    if not changed:
        print("Geometries inchangees (GEOM_VERSION identique) : rien a commiter.")
    print("::notice title=PrefetchOSRM::%d/%d geometries, GEOM_VERSION=%s" % (ok, len(pairs), geom_version))


if __name__ == "__main__":
    main()
