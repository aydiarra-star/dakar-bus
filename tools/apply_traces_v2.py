#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v2 — applique les modifications v2 sur un checkout gh-pages.

Rôle (équivalent du runbook TRACES-V2-HANDOFF) : si des fichiers v2 semblent
manquants ou réinitialisés, rejouer `python3 tools/apply_traces_v2.py`.

Ce que fait ce script (idempotent, rejouable sans risque) :
  1. flutter_service_worker.js : cache `osrm-geom-v1` -> `osrm-geom-v2`,
     semis instantané des géométries préchargées depuis le bundle
     `assets/assets/data/osrm_geometries.json` (généré par le workflow
     « PrefetchOSRM geometries »), la file régulée runtime v1 restant en
     repli, et purge du cache v1 obsolète à l'activation.
  2. index.html : bump de `serviceWorkerVersion` (propagation immédiate
     du nouveau service worker chez les clients).
  3. version.json : build_number 6 -> 7.
  4. Met à jour les sommes MD5 de RESOURCES (index.html, "/", version.json).
  5. Écrit .github/workflows/prefetch-osrm.yml (workflow « PrefetchOSRM
     geometries ») et tools/prefetch_osrm.py (exécuté par ce workflow).

Ne touche à rien d'autre : UI, main.dart.js et données restent intacts.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SW = ROOT / "flutter_service_worker.js"
INDEX = ROOT / "index.html"
VERSION = ROOT / "version.json"
WORKFLOW = ROOT / ".github" / "workflows" / "prefetch-osrm.yml"
PREFETCH_TOOL = ROOT / "tools" / "prefetch_osrm.py"

SW_VERSION_V2 = "477962403"  # était 477962402 (v1)

OLD_INDEX_MD5 = "42e430c45a5f1c62105082da3931ee39"  # index.html + "/" (v1)
OLD_VERSION_MD5 = "4667366da077675603bb0ec12a23f2ae"  # version.json (v1)

# ---------------------------------------------------------------------------
# 1. Service worker : passage en v2 (semis depuis le bundle préchargé)
# ---------------------------------------------------------------------------

ANCHOR_COMMENT = "// ===== Traces routiers reels (fix geographies) ====="
ANCHOR_HEADER = (
    "const OSRM_CACHE = 'osrm-geom-v1';\n"
    "const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';\n"
    "const OSRM_PAIRS_URL = 'assets/assets/data/osrm_pairs.json';"
)
NEW_HEADER = (
    "const OSRM_CACHE = 'osrm-geom-v2';\n"
    "const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';\n"
    "const OSRM_PAIRS_URL = 'assets/assets/data/osrm_pairs.json';\n"
    "const OSRM_GEOMS_URL = 'assets/assets/data/osrm_geometries.json';\n"
    "// v2 : version des geometries prechargees. Le workflow « PrefetchOSRM geometries »\n"
    "// la recalcule (hachage du bundle) a chaque regeneration de osrm_geometries.json :\n"
    "// le changement d'octets du service worker declenche la mise a jour chez les clients.\n"
    "const GEOM_VERSION = 'v2-initial';"
)

ANCHOR_PREFETCH = "async function osrmPrefetch() {"
SEED_FN = (
    "// v2 : installe en une seule requete les geometries prechargees par le workflow\n"
    "// « PrefetchOSRM geometries » (bundle osrm_geometries.json commite sur gh-pages).\n"
    "// La file runtime (osrmPrefetch) reste en repli pour les paires absentes du bundle.\n"
    "async function osrmSeedFromBundle() {\n"
    "  try {\n"
    "    const res = await fetch(OSRM_GEOMS_URL + '?v=' + GEOM_VERSION, { cache: 'no-store' });\n"
    "    if (!res.ok) throw new Error('bundle HTTP ' + res.status);\n"
    "    const bundle = await res.json();\n"
    "    const geoms = bundle && bundle.geometries;\n"
    "    if (!geoms) throw new Error('bundle sans geometries');\n"
    "    const cache = await caches.open(OSRM_CACHE);\n"
    "    const existing = new Set((await cache.keys()).map((r) => r.url));\n"
    "    let n = 0;\n"
    "    for (const url in geoms) {\n"
    "      if (existing.has(url)) continue;\n"
    "      await cache.put(new Request(url), new Response(JSON.stringify(geoms[url]),\n"
    "          { headers: { 'Content-Type': 'application/json' } }));\n"
    "      n++;\n"
    "    }\n"
    "    console.debug('OSRM v2 : ' + n + ' geometries installees depuis le bundle precharge');\n"
    "  } catch (e) {\n"
    "    console.warn('OSRM v2 : bundle precharge indisponible (' + e + '), repli file runtime');\n"
    "  }\n"
    "}\n\n"
)

ANCHOR_ACTIVATE = "self.addEventListener('activate', (event) => { event.waitUntil(osrmPrefetch()); });"
NEW_ACTIVATE = (
    "self.addEventListener('activate', (event) => {\n"
    "  event.waitUntil((async () => {\n"
    "    await osrmSeedFromBundle();\n"
    "    await osrmPrefetch();\n"
    "    await caches.delete('osrm-geom-v1'); // cache v1 obsolete\n"
    "  })());\n"
    "});"
)

# ---------------------------------------------------------------------------
# 2. Workflow « PrefetchOSRM geometries » + outil exécuté par celui-ci
# ---------------------------------------------------------------------------

WORKFLOW_YAML = """name: PrefetchOSRM geometries

on:
  workflow_dispatch:
  push:
    branches: [gh-pages]

concurrency:
  group: prefetch-osrm
  cancel-in-progress: true

permissions:
  contents: write

jobs:
  prefetch:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout gh-pages
        uses: actions/checkout@v4
        with:
          ref: gh-pages

      - name: Prefetch des geometries OSRM (paires d'arrets du reseau)
        run: python3 tools/prefetch_osrm.py

      - name: Commit des geometries si changement
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add assets/assets/data/osrm_geometries.json flutter_service_worker.js
          if git diff --cached --quiet; then
            echo "Geometries inchangees - aucun commit necessaire."
          else
            git commit -m "chore(osrm): geometries v2 regenerees (workflow PrefetchOSRM geometries)"
            git push
            echo "Commit pousse - GitHub Pages redemarrera un build avec le bundle."
          fi
"""

PREFETCH_PY = '''#!/usr/bin/env python3
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
    out_text = json.dumps(bundle, ensure_ascii=False, separators=(",", ":")) + "\\n"
    geom_version = "v2-" + hashlib.sha256(out_text.encode("utf-8")).hexdigest()[:12]

    changed = False
    if not OUT.exists() or OUT.read_text(encoding="utf-8") != out_text:
        OUT.write_text(out_text, encoding="utf-8")
        changed = True
        print("Bundle ecrit : %s (%d octets, %d geometries)" % (OUT.name, len(out_text), ok))

    sw = SW.read_text(encoding="utf-8")
    sw_new = re.sub(r"(const GEOM_VERSION = ')[^']*(')",
                    r"\\g<1>" + geom_version + r"\\g<2>", sw, count=1)
    if sw_new != sw:
        SW.write_text(sw_new, encoding="utf-8")
        changed = True
        print("GEOM_VERSION mise a jour : %s" % geom_version)

    if not changed:
        print("Geometries inchangees (GEOM_VERSION identique) : rien a commiter.")
    print("::notice title=PrefetchOSRM::%d/%d geometries, GEOM_VERSION=%s" % (ok, len(pairs), geom_version))


if __name__ == "__main__":
    main()
'''


def die(msg):
    sys.exit("apply_traces_v2: ERREUR : %s" % msg)


def replace_once(text, old, new, what):
    if old not in text:
        die("ancre introuvable pour %s (fichier inattendu ?)" % what)
    return text.replace(old, new, 1)


def main():
    changed = []

    # --- Service worker ---------------------------------------------------
    sw = SW.read_text(encoding="utf-8")
    if "osrm-geom-v2" in sw:
        print("Service worker deja en v2 : patch SW ignore (idempotent).")
    elif "osrm-geom-v1" in sw:
        sw = replace_once(sw, ANCHOR_COMMENT,
                          "// ===== Traces routiers reels v2 (geometries prechargees au deploiement) =====",
                          "commentaire bloc traces")
        sw = replace_once(sw, ANCHOR_HEADER, NEW_HEADER, "en-tete bloc OSRM")
        sw = replace_once(sw, ANCHOR_PREFETCH, SEED_FN + ANCHOR_PREFETCH,
                          "insertion osrmSeedFromBundle")
        sw = replace_once(sw, ANCHOR_ACTIVATE, NEW_ACTIVATE, "listener activate OSRM")
        SW.write_text(sw, encoding="utf-8")
        changed.append("flutter_service_worker.js")
        print("flutter_service_worker.js : osrm-geom-v1 -> osrm-geom-v2 (semis bundle + repli file).")
    else:
        die("flutter_service_worker.js sans bloc OSRM v1 ni v2 — etat inconnu.")

    # --- index.html : bump SW version --------------------------------------
    idx = INDEX.read_text(encoding="utf-8")
    idx_new = re.sub(r'serviceWorkerVersion: "\d+"',
                     'serviceWorkerVersion: "%s"' % SW_VERSION_V2, idx, count=1)
    if idx_new != idx:
        INDEX.write_text(idx_new, encoding="utf-8")
        changed.append("index.html")
        print("index.html : serviceWorkerVersion -> %s" % SW_VERSION_V2)
    else:
        print("index.html : serviceWorkerVersion deja a jour.")

    # --- version.json : build 6 -> 7 ---------------------------------------
    v = json.loads(VERSION.read_text(encoding="utf-8"))
    if v.get("build_number") != "7":
        v["build_number"] = "7"
        VERSION.write_text(json.dumps(v, ensure_ascii=False, separators=(",", ":")),
                           encoding="utf-8")
        changed.append("version.json")
        print("version.json : build_number -> 7")
    else:
        print("version.json : build_number deja 7.")

    # --- MD5 RESOURCES du service worker -----------------------------------
    sw = SW.read_text(encoding="utf-8")
    idx_md5 = hashlib.md5(INDEX.read_bytes()).hexdigest()
    ver_md5 = hashlib.md5(VERSION.read_bytes()).hexdigest()
    n_idx = sw.count('"%s"' % OLD_INDEX_MD5)
    if n_idx:
        if n_idx != 2:
            die("MD5 index.html attendu 2 fois, trouve %d" % n_idx)
        sw = sw.replace('"%s"' % OLD_INDEX_MD5, '"%s"' % idx_md5)
    n_ver = sw.count('"%s"' % OLD_VERSION_MD5)
    if n_ver:
        if n_ver != 1:
            die("MD5 version.json attendu 1 fois, trouve %d" % n_ver)
        sw = sw.replace('"%s"' % OLD_VERSION_MD5, '"%s"' % ver_md5)
    if '"/":' in sw and ('"/": "%s"' % idx_md5) not in sw:
        # sécurité : l'entree "/" doit partager le MD5 de index.html
        sw = re.sub(r'("/": ")[0-9a-f]{32}(")', r'\\g<1>%s\\g<2>' % idx_md5, sw, count=1)
    if sw != SW.read_text(encoding="utf-8"):
        SW.write_text(sw, encoding="utf-8")
        if "flutter_service_worker.js" not in changed:
            changed.append("flutter_service_worker.js")
        print("RESOURCES MD5 mis a jour (index.html, /, version.json).")

    # --- Workflow + outil prefetch ------------------------------------------
    WORKFLOW.parent.mkdir(parents=True, exist_ok=True)
    if not WORKFLOW.exists() or WORKFLOW.read_text(encoding="utf-8") != WORKFLOW_YAML:
        WORKFLOW.write_text(WORKFLOW_YAML, encoding="utf-8")
        changed.append(".github/workflows/prefetch-osrm.yml")
        print(".github/workflows/prefetch-osrm.yml : ecrit (workflow « PrefetchOSRM geometries »).")
    else:
        print("Workflow prefetch-osrm.yml deja present.")
    PREFETCH_TOOL.parent.mkdir(parents=True, exist_ok=True)
    if not PREFETCH_TOOL.exists() or PREFETCH_TOOL.read_text(encoding="utf-8") != PREFETCH_PY:
        PREFETCH_TOOL.write_text(PREFETCH_PY, encoding="utf-8")
        changed.append("tools/prefetch_osrm.py")
        print("tools/prefetch_osrm.py : ecrit (outil du workflow).")
    else:
        print("tools/prefetch_osrm.py deja present.")

    print("\nFichiers modifiés/créés : %s" % (", ".join(changed) if changed else "aucun (déjà appliqué)"))


if __name__ == "__main__":
    main()
