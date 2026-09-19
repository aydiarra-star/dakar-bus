#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v5 — séparation stricte par mode (spécification impérative).

Rôle (équivalent du runbook TRACES-V5-HANDOFF) : si des fichiers v5 semblent
manquants ou réinitialisés, rejouer `python3 tools/apply_traces_v5.py`.
Le script est idempotent : le rejouer ne change rien si le correctif est déjà là.

Prérequis : le correctif v4 doit être présent (filtre A.eI sans rectangle,
démos $.J0 recalées, constantes recalées, SW v4). Ces corrections v4 sont
CONSERVÉES : sans elles (démos demandant des paires non consécutives, gares
exclues par eI), même la méthode de secours afficherait des cordes à travers
la carte. v5 ne change que la SOURCE des géométries guidées.

POURQUOI v5
-----------
La spécification impérative exige, dans le script de génération :
  * TER : shapes.txt GTFS officiel (prioritaire) ; sinon méthode de secours
    (segments droits entre gares CONSÉCUTIVES triées par sequence). OSRM
    driving INTERDIT pour un train. Jamais de direct premier <-> dernier.
  * BRT : essai OSRM (arrêts triés par sequence) puis, si incohérent, méthode
    de secours (segments droits consécutifs, sans API).
  * AFTU/DDD/TATA : OSRM driving normalement.
  * Régénération des GeoJSON TER/BRT + renouvellement forcé du cache SW,
    SANS réutiliser les géométries guidées précédentes.

Constats : shapes.txt GTFS officiel non téléchargeable depuis l'environnement
de génération (sandbox sans accès réseau ; CETUD annonce des GTFS mais sans
shapes TER récupérables) -> secours TER. Tracés BRT OSRM mesurés incohérents
(ratios route/direct 1,21 à 3,09, seuil 2,0 dépassé) -> secours BRT intégral.
Les tracés obtenus sont anguleux mais logiques et lisibles, comme l'exige la
consigne. L'activation ultérieure du GTFS officiel se fait par simple dépôt
(source_kind = "gtfs-officiel", voir ter_rail_shapes.json).

Ce que fait ce script
---------------------
  1. Vérifie les formes de secours (sequence strict, coordonnées exactes).
  2. Reconstruit les 25 payloads TER/BRT via generer_geometrie_pour_ligne()
     (if TER / elif BRT / else) — TOUJOURS reconstruits, jamais réutilisés ;
     paires routières réutilisées du bundle précédent (validées, non erronées).
  3. Régénère les 281 fichiers osrm/route/v1/driving/*.
  4. Service worker v5 : cache osrm-geom-v5 (renouvellement FORCÉ : nouveau
     nom + purge v1..v4, la seule GEOM_VERSION ne suffisant pas puisque le
     semis saute les clés déjà en cache), TRACES_SW=v5.
  5. build 11, serviceWorkerVersion 477962407, MD5 RESOURCES, vérification
     (payloads guidés = EXACTEMENT 2 points = gares consécutives exactes).
"""
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from track_shapes import (  # noqa: E402
    OSRM_PREFIX,
    OSRM_SUFFIX,
    build_track_geometries,
    canonical_bundle_text,
    classify_network_pairs,
    dart_double,
    geom_version_for,
    load_shapes,
)

ROOT = Path(__file__).resolve().parent.parent
MAIN_JS = ROOT / "main.dart.js"
INDEX = ROOT / "index.html"
BOOTSTRAP = ROOT / "flutter_bootstrap.js"
VERSION = ROOT / "version.json"
SW = ROOT / "flutter_service_worker.js"
PAIRS = ROOT / "assets" / "assets" / "data" / "osrm_pairs.json"
GEOMS = ROOT / "assets" / "assets" / "data" / "osrm_geometries.json"
NETWORK = ROOT / "assets" / "assets" / "data" / "dakar_network.json"
TER_SHAPES = ROOT / "assets" / "assets" / "data" / "ter_rail_shapes.json"
BRT_SHAPES = ROOT / "assets" / "assets" / "data" / "brt_dedicated_shapes.json"
WORKFLOW = ROOT / ".github" / "workflows" / "prefetch-osrm.yml"
LOCAL_DIR = ROOT / "osrm" / "route" / "v1" / "driving"

TARGET_BUILD = 11
SW_VERSION_V5 = "477962407"      # était 477962406 (v4)
TRACES_SW = "v5"
OSRM_CACHE = "osrm-geom-v5"

# Longueurs de contrôle (haversine sur secours consécutif).
TER_LEN_RANGE = (30000, 40000)   # ~35 km officiels
BRT_LEN_RANGE = (20000, 26000)   # modèle applicatif 12 stations

CHANGES = []


def note(msg):
    CHANGES.append(msg)
    print("  - " + msg)


def read(path):
    return path.read_text(encoding="utf-8")


def write(path, text):
    path.write_text(text, encoding="utf-8", newline="")


def md5(path):
    return hashlib.md5(path.read_bytes()).hexdigest()


def eI_new(lat, lon):
    if lat < 14.55 or lat > 14.9:
        return False
    if lon < -17.6 or lon > -16.85:
        return False
    return True


# ---------------------------------------------------------------------------
# Garde-fous : v4 en place (conservée)
# ---------------------------------------------------------------------------

def require_v4():
    print("[0] Controle du prerequis v4")
    main_js, sw = read(MAIN_JS), read(SW)
    missing = []
    if "rectangle d'exclusion Hann/Dalifort retire" not in main_js:
        missing.append("filtre A.eI v4")
    if "demos recalees sur le reseau JSON" not in main_js:
        missing.append("demos $.J0 v4")
    if "TRACES_SW = 'v4'" not in sw and "TRACES_SW = 'v5'" not in sw:
        missing.append("service worker v4/v5")
    for f in (PAIRS, GEOMS, NETWORK, TER_SHAPES, BRT_SHAPES):
        if not f.exists():
            missing.append("fichier %s" % f.name)
    if missing:
        sys.exit("ECHEC : prerequis v4 incomplet (%s). Rejouez d'abord "
                 "tools/apply_traces_v4.py" % ", ".join(missing))
    print("  = v4 en place (eI, demos, constantes, SW) + formes v5 presentes")


# ---------------------------------------------------------------------------
# 1. Formes de secours + 2. bundle (dispatcher if TER / elif BRT / else)
# ---------------------------------------------------------------------------

LABEL_RE = r"Dakar Bus v(\d+(?:\.\d+)*) build (\d+)"


def patch_label():
    print("[1] main.dart.js : libelle Reglages (seule retouche JS v5)")
    text = read(MAIN_JS)
    found = re.findall(LABEL_RE, text)
    if not found:
        sys.exit("ECHEC : libelle « Dakar Bus vX.Y.Z build N » introuvable")
    if found[0][1] != str(TARGET_BUILD):
        new = re.sub(LABEL_RE,
                     lambda m: "Dakar Bus v%s build %d" % (m.group(1), TARGET_BUILD),
                     text)
        write(MAIN_JS, new)
        note("libelle Reglages « v%s build %s » -> « v%s build %d »"
             % (found[0][0], found[0][1], found[0][0], TARGET_BUILD))
    else:
        print("  = libelle deja a « build %d »" % TARGET_BUILD)


def rebuild_bundle():
    print("[2] Secours consecutif + bundle (dispatcher par mode, 0 reutilisation guidee)")
    network = json.loads(read(NETWORK))
    pairs = json.loads(read(PAIRS))
    old_bundle = json.loads(read(GEOMS))
    old_geoms = old_bundle.get("geometries", {})

    # 1. Formes : sequence strict, coordonnées exactes, garde-fou.
    shapes = load_shapes()
    stops = {s["id"]: s for s in network.get("stops", [])}
    for op, shape in shapes.items():
        for p in shape.points:
            if not eI_new(p["lat"], p["lon"]):
                sys.exit("ECHEC : point de forme hors garde-fou : %s" % p)
            if p.get("stop_id"):
                s = stops[p["stop_id"]]
                if p["lat"] != s["latitude"] or p["lon"] != s["longitude"]:
                    sys.exit("ECHEC : ancre %s != coordonnees exactes" % p["stop_id"])
        print("  = forme %s (%s) : %d points, %d arrets, %.1f km"
              % (shape.shape_id, shape.source_kind, len(shape.points),
                 len(shape.ordered_stop_ids()), shape.full_length_m() / 1000))

    # 2. Classification + dispatch if TER / elif BRT / else (hors-ligne :
    #    fetcher=None -> TER secours (GTFS indisponible), BRT secours).
    track_urls, road_urls, shared = classify_network_pairs(network)
    if set(pairs) != track_urls | road_urls:
        sys.exit("ECHEC : osrm_pairs.json incohérent avec le réseau")
    track_geoms, track_prov = build_track_geometries(network, shapes, fetcher=None)
    assert set(track_geoms) == track_urls, "couverture guidee incomplete"
    n_secours = sum(1 for s in track_prov.values() if s.endswith("-secours"))
    print("  = %d paires guidees RECONSTRUITES (%d secours, 0 reutilisee)"
          % (len(track_geoms), n_secours))
    if shared:
        print("  = %d paires partagees route/guidee -> priorite site propre" % len(shared))

    # Preuve de non-réutilisation : les payloads guidés sont des segments
    # de secours à EXACTEMENT 2 points (aucune géométrie précédente n'a
    # cette forme : v3 = routes multi-points, v4 = formes multi-points).
    for url, payload in track_geoms.items():
        coords = payload["routes"][0]["geometry"]["coordinates"]
        if len(coords) != 2:
            sys.exit("ECHEC : payload guide non-secours : %s (%d pts)"
                     % (url[:80], len(coords)))

    # 3. Paires routières : réutilise les payloads validés (NON erronés :
    #    tracés AFTU/DDD/TATA validés visuellement depuis v3).
    geometries, provenance = dict(track_geoms), dict(track_prov)
    missing, invalid = [], []
    for url in road_urls:
        payload = old_geoms.get(url)
        if payload is None:
            missing.append(url)
            continue
        coords = (((payload.get("routes") or [{}])[0].get("geometry") or {})
                  .get("coordinates") or [])
        if len(coords) < 2:
            invalid.append(url)
            continue
        geometries[url] = payload
        provenance[url] = "osrm-driving"
    if missing or invalid:
        sys.exit("ECHEC : %d paires routieres manquantes, %d invalides "
                 "(lancez prefetch_osrm.py avec reseau)" % (len(missing), len(invalid)))
    print("  = %d paires routieres reutilisees (validees >= 2 pts, non erronees)"
          % len(road_urls))

    out_text = canonical_bundle_text(geometries, provenance, pairs)
    geom_version = geom_version_for(out_text)
    if not GEOMS.exists() or read(GEOMS) != out_text:
        write(GEOMS, out_text)
        note("bundle : %d geometries (%d secours reconstruits, %d route) "
             "GEOM_VERSION=%s" % (len(geometries), len(track_geoms),
                                 len(road_urls), geom_version))
    else:
        print("  = bundle deja a jour (GEOM_VERSION=%s)" % geom_version)
    return geom_version


# ---------------------------------------------------------------------------
# 3. Fichiers statiques
# ---------------------------------------------------------------------------

def write_static_files():
    print("[3] Fichiers statiques : %s" % LOCAL_DIR.relative_to(ROOT))
    geoms = json.loads(read(GEOMS)).get("geometries", {})
    LOCAL_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    for url, payload in geoms.items():
        if not url.startswith(OSRM_PREFIX):
            continue
        coords = url[len(OSRM_PREFIX):].split("?", 1)[0]
        if not coords or "/" in coords:
            continue
        target = LOCAL_DIR / coords
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if not target.exists() or target.read_text(encoding="utf-8") != body:
            target.write_text(body, encoding="utf-8", newline="")
            written += 1
    expected = {u[len(OSRM_PREFIX):].split("?", 1)[0]
                for u in geoms if u.startswith(OSRM_PREFIX)}
    stale = [p for p in LOCAL_DIR.iterdir() if p.name not in expected]
    for p in stale:
        p.unlink()
    non_ascii = [p.name for p in LOCAL_DIR.iterdir()
                 if any(b >= 128 for b in p.read_bytes())]
    if non_ascii:
        sys.exit("ECHEC : fichiers statiques non ASCII : %s" % non_ascii[:3])
    if written or stale:
        note("osrm/route/v1/driving : %d ecrit(s), %d supprime(s) (%d au total)"
             % (written, len(stale), len(expected)))
    else:
        print("  = %d fichiers deja a jour (tous ASCII)" % len(expected))
    return expected


# ---------------------------------------------------------------------------
# 4. Service worker v5 (renouvellement FORCÉ du cache)
# ---------------------------------------------------------------------------

SW_REPLACEMENTS = [
    ("// ===== Traces reels v4 (TER ferroviaire + BRT site propre : "
     "jamais de routage routier) =====",
     "// ===== Traces reels v5 (TER/BRT : GTFS officiel ou secours consecutif) =====",
     "en-tête v4 -> v5"),
    ("const OSRM_CACHE = 'osrm-geom-v4';",
     "const OSRM_CACHE = 'osrm-geom-v5';",
     "cache osrm-geom-v4 -> osrm-geom-v5 (renouvellement force)"),
    ("const TRACES_SW = 'v4';",
     "const TRACES_SW = 'v5';",
     "TRACES_SW v4 -> v5"),
    ("    await caches.delete('osrm-geom-v3');",
     "    await caches.delete('osrm-geom-v3');\n    await caches.delete('osrm-geom-v4');",
     "purge du cache v4"),
]


def patch_sw(geom_version):
    print("[4] flutter_service_worker.js : passage en v5 (cache renouvele de force)")
    text = read(SW)
    for before, after, label in SW_REPLACEMENTS:
        # Tester `after` D'ABORD : certains `before` sont des sous-chaines de
        # `after` (ex. la ligne de purge), sinon chaque re-execution duplique.
        if after in text:
            print("  = SW deja (%s)" % label)
        elif before in text:
            assert text.count(before) == 1, label
            text = text.replace(before, after, 1)
            note("SW : %s" % label)
        else:
            sys.exit("ECHEC : marqueur SW introuvable : %s" % label)
    write(SW, text)

    text = read(SW)
    m = re.search(r"const GEOM_VERSION = '([^']*)';", text)
    if not m:
        sys.exit("ECHEC : GEOM_VERSION introuvable dans le service worker")
    if m.group(1) != geom_version:
        text = (text[:m.start()] + "const GEOM_VERSION = '%s';" % geom_version
                + text[m.end():])
        write(SW, text)
        note("GEOM_VERSION %s -> %s" % (m.group(1), geom_version))
    else:
        print("  = GEOM_VERSION déjà %s" % geom_version)

    if "osrmLocalRespond(event.request)" not in text:
        sys.exit("ECHEC : branche locale absente du fetch handler")


# ---------------------------------------------------------------------------
# 5. Versions + workflow + RESOURCES
# ---------------------------------------------------------------------------

SWV_RE = r'(serviceWorkerVersion\s*:\s*")(\d+)(")'


def patch_versions():
    print("[5] version.json / index.html / flutter_bootstrap.js / workflow")
    text = read(VERSION)
    m = re.search(r'"build_number"\s*:\s*"?(\d+)"?', text)
    if not m:
        sys.exit("ECHEC : build_number introuvable dans version.json")
    if m.group(1) != str(TARGET_BUILD):
        quoted = '"' in text[m.start():m.end()]
        repl = ('"build_number":"%d"' % TARGET_BUILD if quoted
                else '"build_number":%d' % TARGET_BUILD)
        new = text[:m.start()] + repl + text[m.end():]
        json.loads(new)
        write(VERSION, new)
        note("version.json build_number %s -> %d" % (m.group(1), TARGET_BUILD))
    else:
        print("  = build_number déjà à %d" % TARGET_BUILD)

    for path in (INDEX, BOOTSTRAP):
        text = read(path)
        m = re.search(SWV_RE, text)
        if not m:
            sys.exit("ECHEC : serviceWorkerVersion introuvable dans %s" % path.name)
        if m.group(2) != SW_VERSION_V5:
            new = text[:m.start()] + m.group(1) + SW_VERSION_V5 + m.group(3) + text[m.end():]
            write(path, new)
            note("%s serviceWorkerVersion %s -> %s" % (path.name, m.group(2), SW_VERSION_V5))
        else:
            print("  = %s déjà en %s" % (path.name, SW_VERSION_V5))

    if WORKFLOW.exists():
        text = read(WORKFLOW)
        old_msg = "chore(osrm): geometries v4 regenerees (workflow PrefetchOSRM geometries)"
        new_msg = "chore(osrm): geometries v5 regenerees (workflow PrefetchOSRM geometries)"
        if old_msg in text:
            write(WORKFLOW, text.replace(old_msg, new_msg, 1))
            note("workflow : message de commit v4 -> v5")
        elif new_msg in text:
            print("  = workflow déjà en v5")
        else:
            print("  ! workflow : message de commit inattendu, laissé tel quel")


def patch_resources():
    print("[6] flutter_service_worker.js : sommes MD5 de RESOURCES")
    text = read(SW)
    block = re.search(r"const RESOURCES = (\{.*?\});", text, re.S)
    if not block:
        sys.exit("ECHEC : objet RESOURCES introuvable dans le service worker")
    resources = json.loads(block.group(1))
    updated = 0
    for key, old in list(resources.items()):
        path = ROOT / (key.lstrip("/") if key != "/" else "index.html")
        if not path.exists():
            print("  ! RESOURCES[%s] : fichier absent, laissé tel quel" % key)
            continue
        actual = md5(path)
        if actual == old:
            continue
        entry_re = re.compile(r'("%s": ")%s(")' % (re.escape(key), re.escape(old)))
        text, n = entry_re.subn(lambda m: m.group(1) + actual + m.group(2), text, count=1)
        if n != 1:
            sys.exit("ECHEC : entrée RESOURCES[%s] introuvable pour mise à jour" % key)
        updated += 1
        note("RESOURCES[%s] %s -> %s" % (key, old[:8], actual[:8]))
    if updated == 0:
        print("  = toutes les sommes MD5 étaient déjà à jour")
    else:
        write(SW, text)


# ---------------------------------------------------------------------------
# Vérification finale
# ---------------------------------------------------------------------------

def verify(static_expected, geom_version):
    print("[7] Verification")
    problems = []
    main_js = read(MAIN_JS)
    network = json.loads(read(NETWORK))
    stops = {s["id"]: s for s in network.get("stops", [])}

    # 1. Correctifs v4 conservés (indispensables au secours consécutif).
    if "rectangle d'exclusion Hann/Dalifort retire" not in main_js:
        problems.append("non-régression : correctif A.eI v4 perdu")
    if "demos recalees sur le reseau JSON" not in main_js:
        problems.append("non-régression : correctif demos v4 perdu")
    for lit in ("B.J1=new A.aE(14.71596,-17.27)",
                "B.kb=new A.aE(14.71606,-17.19845)",
                "B.oK=new A.aE(14.735,-17.436)",
                "B.kh=new A.aE(14.718,-17.455)"):
        if lit not in main_js:
            problems.append("non-régression : constante perdue %s" % lit[:12])
    if "$1(a){return!0}" not in main_js.split("A.ap9.prototype=")[1][:400]:
        problems.append("non-régression : filtre A.ap9 modifié")
    if "router.project-osrm.org" in main_js:
        problems.append("non-régression : routeur public dans main.dart.js")
    if not problems:
        print("  ok correctifs v4 conserves (eI, demos, constantes, filtres)")

    # 2. Secours consécutif strict : 25 payloads à EXACTEMENT 2 points.
    bundle = json.loads(read(GEOMS))
    pairs = json.loads(read(PAIRS))
    track_urls, road_urls, _ = classify_network_pairs(network)
    if bundle.get("schema") != 2 or set(bundle.get("geometries", {})) != set(pairs):
        problems.append("bundle : schema/couverture incoherents")
    prov = bundle.get("provenance", {})
    bad_n, bad_ends, bad_prov = [], [], []
    for route in network["routes"]:
        if route.get("operator_id") not in ("ter", "brt"):
            continue
        ids = route["stops"]
        for i in range(len(ids) - 1):
            a, b = stops[ids[i]], stops[ids[i + 1]]
            url = (OSRM_PREFIX + dart_double(a["longitude"]) + ","
                   + dart_double(a["latitude"]) + ";" + dart_double(b["longitude"])
                   + "," + dart_double(b["latitude"]) + OSRM_SUFFIX)
            payload = bundle["geometries"].get(url)
            if payload is None:
                bad_n.append(url[:60])
                continue
            coords = payload["routes"][0]["geometry"]["coordinates"]
            if len(coords) != 2:
                bad_n.append("%s (%d pts)" % (url[:60], len(coords)))
            elif (coords[0] != [a["longitude"], a["latitude"]]
                    or coords[-1] != [b["longitude"], b["latitude"]]):
                bad_ends.append(url[:60])
            if not prov.get(url, "").endswith("-secours"):
                bad_prov.append(url[:60])
    if bad_n or bad_ends or bad_prov:
        problems.append("secours : %d payloads != 2 pts, %d extremites inexactes, "
                        "%d provenances non-secours"
                        % (len(bad_n), len(bad_ends), len(bad_prov)))
    else:
        print("  ok secours : 25/25 payloads TER/BRT = 2 gares consecutives exactes")
    road_ok = all(prov.get(u) == "osrm-driving" for u in road_urls)
    if not road_ok:
        problems.append("bundle : provenance routiere incohérente")
    else:
        print("  ok bundle : 256 paires bus = osrm-driving, 25 guidees = secours")

    # 3. Longueurs (garde-fou anti premier<->dernier direct).
    ter_len = sum(bundle["geometries"][u]["routes"][0]["distance"] for u in track_urls
                  if prov.get(u, "").startswith("ter-"))
    b1 = [r for r in network["routes"] if r["id"] == "brt_b1_guediawaye_petersen"][0]
    brt_len = 0
    for i in range(len(b1["stops"]) - 1):
        a, b = stops[b1["stops"][i]], stops[b1["stops"][i + 1]]
        url = (OSRM_PREFIX + dart_double(a["longitude"]) + ","
               + dart_double(a["latitude"]) + ";" + dart_double(b["longitude"])
               + "," + dart_double(b["latitude"]) + OSRM_SUFFIX)
        brt_len += bundle["geometries"][url]["routes"][0]["distance"]
    if not (TER_LEN_RANGE[0] <= ter_len <= TER_LEN_RANGE[1]):
        problems.append("TER : %.1f km hors plage" % (ter_len / 1000))
    else:
        print("  ok TER secours : %.1f km de gares consecutives" % (ter_len / 1000))
    if not (BRT_LEN_RANGE[0] <= brt_len <= BRT_LEN_RANGE[1]):
        problems.append("BRT : %.1f km hors plage" % (brt_len / 1000))
    else:
        print("  ok BRT secours : %.1f km d'arrets consecutifs" % (brt_len / 1000))

    # 4. Statiques + SW + versions + MD5.
    on_disk = {p.name for p in LOCAL_DIR.iterdir()} if LOCAL_DIR.exists() else set()
    if on_disk != static_expected:
        problems.append("fichiers statiques : %d sur disque, %d attendus"
                        % (len(on_disk), len(static_expected)))
    else:
        print("  ok repli sans service worker : %d fichiers" % len(on_disk))
    sw = read(SW)
    for marker in ("TRACES_SW = '%s'" % TRACES_SW, "OSRM_CACHE = '%s'" % OSRM_CACHE,
                   "const GEOM_VERSION = '%s';" % geom_version,
                   "caches.delete('osrm-geom-v4')",
                   "GTFS officiel ou secours consecutif"):
        if marker not in sw:
            problems.append("service worker : marqueur manquant %r" % marker)
    if not any(p.startswith("service worker") for p in problems):
        print("  ok service worker v5 : cache %s renouvele de force" % OSRM_CACHE)
    labels = re.findall(LABEL_RE, main_js)
    version = json.loads(read(VERSION))
    if not labels or labels[0][1] != str(TARGET_BUILD):
        problems.append("libellé Réglages inattendu : %s" % (labels,))
    elif version.get("build_number") != str(TARGET_BUILD):
        problems.append("version.json : build_number=%r" % version.get("build_number"))
    else:
        print("  ok versions : build %d partout" % TARGET_BUILD)
    for path in (INDEX, BOOTSTRAP):
        m = re.search(SWV_RE, read(path))
        if not m or m.group(2) != SW_VERSION_V5:
            problems.append("%s : serviceWorkerVersion=%s" % (path.name, m and m.group(2)))
    if not any("serviceWorkerVersion" in p for p in problems):
        print("  ok serviceWorkerVersion=%s (index + bootstrap)" % SW_VERSION_V5)
    block = re.search(r"const RESOURCES = (\{.*?\});", sw, re.S)
    resources = json.loads(block.group(1))
    for key in ("main.dart.js", "index.html", "/", "version.json", "flutter_bootstrap.js"):
        path = ROOT / ("index.html" if key == "/" else key)
        if resources.get(key) != md5(path):
            problems.append("RESOURCES[%s] : MD5 incohérent" % key)
    if not any(p.startswith("RESOURCES") for p in problems):
        print("  ok RESOURCES : MD5 cohérents")

    if problems:
        for p in problems:
            print("  KO " + p)
        sys.exit("ECHEC : verification incomplete (%d probleme(s))" % len(problems))


def main():
    print("Correctif traces v5 — checkout : %s" % ROOT)
    require_v4()
    patch_label()
    geom_version = rebuild_bundle()
    static_expected = write_static_files()
    patch_sw(geom_version)
    patch_versions()
    patch_resources()
    verify(static_expected, geom_version)
    print("")
    if CHANGES:
        print("Correctif v5 applique (%d modification(s)) :" % len(CHANGES))
        for c in CHANGES:
            print("  * " + c)
    else:
        print("Correctif v5 deja en place : aucune modification (script idempotent).")
    print("")
    print("Effet cote clients : 1er reload -> le SW %s s'installe (cache %s "
          "vide : telechargement force des 281 geometries) ; 2e reload -> "
          "« build %d », TER/BRT en segments consecutifs."
          % (SW_VERSION_V5, OSRM_CACHE, TARGET_BUILD))


if __name__ == "__main__":
    main()
