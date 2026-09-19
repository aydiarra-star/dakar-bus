#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v4 — TER ferroviaire + BRT site propre + lignes de démo.

Rôle (équivalent du runbook TRACES-V4-HANDOFF) : si des fichiers v4 semblent
manquants ou réinitialisés, rejouer `python3 tools/apply_traces_v4.py`.
Le script est idempotent : le rejouer ne change rien si le correctif est déjà là.

Prérequis : le correctif v3 doit être présent (même origine, fichiers
statiques osrm/route/v1/driving/*, bundle osrm_geometries.json).

POURQUOI v4 (ce que v3 ne pouvait pas corriger)
----------------------------------------------
v3 a prouvé que les 281 paires d'arrêts consécutifs du JSON sont servies avec
des géométries routières réelles — et AFTU/DDD suivent maintenant les routes.
Mais v3 partait de deux hypothèses fausses :

1. L'APP N'AFFICHE PAS LA LIGNE TER DU JSON. `$.J0()` (lignes de la carte)
   est initialisée avec 4 lignes de DÉMO codées en dur dans main.dart.js,
   dont une démo TER à 6 arrêts (Dakar, Colobane, Hann, Pikine, Keur Mbaye
   Fall, Diamniadio). À l'intégration des données (aW7), la dédup
   `A.awY` (`a.b === i.c`, testée via `B.b.je` = any) compare le nom démo au
   short_name JSON : démo "TER" == JSON "TER" -> la ligne JSON à 13 gares
   n'est JAMAIS ajoutée. La carte affiche donc la démo à 6 arrêts.

2. LE FILTRE `A.eI` EXCLUT 3 GARES TER OFFICIELLES. eI valide les coordonnées
   (Dakar : lat 14.55-14.9, lng -17.6--16.85) mais exclut aussi le rectangle
   lat 14.7-14.745 × lng -17.435--17.375, qui couvre EXACTEMENT Hann,
   Dalifort et Baux Maraîchers. Ce filtre s'applique aux arrêts (apa, awX)
   ET à chaque point des géométries OSRM (apc). La démo TER devient donc
   [Dakar, Colobane, Pikine, KMB, Diamniadio] et demande des paires
   (Colobane->Pikine, Pikine->KMB ~8 km, KMB->Diamniadio ~12 km) absentes du
   bundle -> 404 -> repli « ligne droite entre deux arrêts » : LA LIGNE
   MARRON DROITE À TRAVERS LA CARTE. Le même mécanisme touche 11 lignes AFTU
   passant par Hann/Baux Maraîchers.

3. LA DÉMO B1 (VERTE) EST INVERSÉE ET INCOMPLÈTE (Petersen->Guédiawaye,
   10 arrêts, Fadia exclue par eI) : ses paires inversées sont absentes du
   bundle -> cordes droites + zigzag superposés aux lignes JSON B1/B2
   correctes : LE BRT « MANQUE DE PRÉCISION / SAUTE DES SEGMENTS ».
   (Les démos DDD et TATA, hors réseau, ajoutaient des cordes parasites.)

4. UN TRAIN N'EST PAS ROUTÉ COMME UN BUS. Même avec des paires correctes,
   le profil OSRM driving (sens uniques, détours routiers) est absurde pour
   le TER ; les voies BRT dédiées sont inconnues d'OSRM (détours jusqu'à
   3,1x sur Grand Yoff->Fadia).

Ce que fait ce script
---------------------
A. main.dart.js :
   1. `A.eI` : suppression du rectangle d'exclusion (garde-fou Dakar
      conservé) -> les 13 gares TER et tous les points de trace redeviennent
      valides (94/94 arrêts valides).
   2. Recalage de 4 constantes sur dakar_network.json : B.J1 (Rufisque),
      B.kb (Diamniadio), B.oK (Fadia), B.kh (Liberté 6).
   3. `$.J0` : démo TER -> 13 gares officielles dans l'ordre ; démo B1 ->
      ordre JSON B1 direct (12 stations) ; démo DDD -> ddd_12 ; démo TATA ->
      tata_219 (doublons invisibles : mêmes coordonnées, mêmes couleurs).
   4. Libellé Réglages -> « build 10 » (changement de longueur sans risque :
      pas de source map dans le bundle, MD5 RESOURCES recalculés).
B. Données : vérifie les formes assets/assets/data/ter_rail_shapes.json et
   brt_dedicated_shapes.json (format inspiré de GTFS shapes.txt).
C. Bundle osrm_geometries.json (schéma 2) : paires TER/BRT générées
   LOCALEMENT depuis les formes (0 appel réseau, marqueur shape_source +
   table provenance) ; paires routières réutilisées du bundle v3 (inchangées,
   validées). Priorité site propre sur les 3 paires partagées avec des bus.
D. osrm/route/v1/driving/* : 281 fichiers régénérés (repli sans SW).
E. flutter_service_worker.js : bloc OSRM v4 (cache osrm-geom-v4, GEOM_VERSION
   recalculée, chemin legacy cross-origin : bundle -> fichier statique
   same-origin -> routeur public, purge des caches v1/v2/v3).
F. version.json (build 10), index.html + flutter_bootstrap.js
   (serviceWorkerVersion 477962406), MD5 RESOURCES, vérification finale.

Ne touche à rien d'autre : UI, paires canoniques, workflow CI (message v4).
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
    haversine_m,
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

TARGET_BUILD = 10
SW_VERSION_V4 = "477962406"      # était 477962405 (v3)
TRACES_SW = "v4"
OSRM_CACHE = "osrm-geom-v4"

# Plages de contrôle des longueurs (haversine). TER : ~35 km officiels
# (vue détail). BRT : le modèle applicatif à 12 stations zigzague davantage
# que le busway réel à 23 stations (18,3 km) ; la forme reste fidèle au
# modèle (~23 km) au lieu des ~40 km de détours routiers OSRM.
TER_LEN_RANGE = (30000, 40000)
BRT_LEN_RANGE = (20000, 26000)

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


def base_href():
    m = re.search(r'<base href="([^"]+)"', read(INDEX))
    if not m:
        sys.exit("ECHEC : <base href> introuvable dans index.html")
    href = m.group(1)
    return href if href.endswith("/") else href + "/"


LOCAL_PATH = base_href() + "osrm/route/v1/driving/"


# ---------------------------------------------------------------------------
# Garde-fous
# ---------------------------------------------------------------------------

def require_v3():
    print("[0] Controle du prerequis v3")
    main_js, sw = read(MAIN_JS), read(SW)
    missing = []
    if "v3 : TOUTES les lignes du reseau passent par OSRM" not in main_js:
        missing.append("filtres carte v3")
    if ('"%s"' % LOCAL_PATH) not in main_js:
        missing.append("prefixe same-origin v3")
    if "TRACES_SW = 'v3'" not in sw and "TRACES_SW = 'v4'" not in sw:
        missing.append("service worker v3/v4")
    for f in (PAIRS, GEOMS, NETWORK):
        if not f.exists():
            missing.append("fichier %s" % f.name)
    if missing:
        sys.exit("ECHEC : prerequis v3 incomplet (%s). Rejouez d'abord "
                 "tools/apply_traces_v3.py" % ", ".join(missing))
    for f in (TER_SHAPES, BRT_SHAPES):
        if not f.exists():
            sys.exit("ECHEC : %s absent (forme v4 manquante)" % f.relative_to(ROOT))
    print("  = v3 en place + formes v4 presentes")


# ---------------------------------------------------------------------------
# A. main.dart.js
# ---------------------------------------------------------------------------

EI_BEFORE = ("eI(a){var s,r=a.a\n"
             "if(r<14.55||r>14.9)return!1\n"
             "s=a.b\n"
             "if(s<-17.6||s>-16.85)return!1\n"
             "if(r>=14.7&&r<=14.745&&s>=-17.435&&s<=-17.375)return!1\n"
             "return!0},")
EI_AFTER = ("eI(a){var s,r=a.a\n"
            "if(r<14.55||r>14.9)return!1\n"
            "s=a.b\n"
            "if(s<-17.6||s>-16.85)return!1\n"
            "// v4 : rectangle d'exclusion Hann/Dalifort retire (il couvrait 3 gares TER\n"
            "// v4 : officielles : Hann, Dalifort, Baux Maraichers). Garde-fou Dakar inchange.\n"
            "return!0},")

LITERAL_FIXES = [
    # (avant, après, signification)
    ("B.J1=new A.aE(14.715,-17.27)",
     "B.J1=new A.aE(14.71596,-17.27)",
     "Rufisque recale sur stop_rufisque"),
    ("B.kb=new A.aE(14.716,-17.1986)",
     "B.kb=new A.aE(14.71606,-17.19845)",
     "Diamniadio recale sur stop_diamniadio"),
    ("B.oK=new A.aE(14.735,-17.435)",
     "B.oK=new A.aE(14.735,-17.436)",
     "Fadia recale sur stop_fadia"),
    ("B.kh=new A.aE(14.715,-17.458)",
     "B.kh=new A.aE(14.718,-17.455)",
     "Liberte 6 recale sur stop_liberte6"),
]

J0_COMMENT_ANCHOR = 's($,"b3t","J0",()=>{var q=t.q_\nreturn A.b(['
J0_COMMENT_NEW = ('s($,"b3t","J0",()=>{var q=t.q_\n'
                  '// v4 : demos recalees sur le reseau JSON (TER 13 gares, B1 direct 12\n'
                  '// v4 : stations, DDD=ddd_12, TATA=tata_219 : doublons invisibles).\n'
                  'return A.b([')

DEMO_FIXES = [
    ('A.akW("TER",B.az,"TER",A.b([B.kg,B.kf,B.ke,B.kj,B.kd,B.kb],q),"TER")',
     'A.akW("TER",B.az,"TER",A.b([B.kg,B.kf,B.ke,B.PDA,B.J4,B.kj,B.IY,B.J2,'
     'B.kd,B.PPNR,B.J1,B.IV,B.kb],q),"TER")',
     "demo TER 6 -> 13 gares officielles dans l'ordre"),
    ('A.akW("B1",B.bl,"BRT",A.b([B.hz,B.oA,B.oE,B.kh,B.kc,B.oB,B.oK,B.oC,'
     'B.oD,B.ki],q),"BRT")',
     'A.akW("B1",B.bl,"BRT",A.b([B.ki,B.oD,B.oB,B.oC,new A.aE(14.745,-17.458),'
     'B.kc,B.oK,B.kh,B.IX,B.oE,B.oA,B.hz],q),"BRT")',
     "demo B1 inversee 10 -> directe 12 stations (= JSON B1)"),
    ('A.akW("DDD",B.bR,"DDD Lignes",A.b([B.oJ,B.oF,B.oI],q),"DDD")',
     'A.akW("DDD",B.bR,"DDD Lignes",A.b([B.ki,new A.aE(14.758,-17.415),'
     'B.oB],q),"DDD")',
     "demo DDD hors reseau -> ddd_12 (doublon invisible)"),
    ('A.akW("TATA",B.bS,"TATA Bus",A.b([B.oL,B.oH,B.oG],q),"Tata")',
     'A.akW("TATA",B.bS,"TATA Bus",A.b([B.oB,B.hz],q),"Tata")',
     "demo TATA hors reseau -> tata_219 (doublon invisible)"),
]

LABEL_RE = r"Dakar Bus v(\d+(?:\.\d+)*) build (\d+)"


def patch_main_js():
    print("[1] main.dart.js : filtre eI, constantes, demos, libelle")
    text = read(MAIN_JS)
    if "sourceMappingURL" in text:
        sys.exit("ECHEC : bundle avec source map, patch dangereux")

    if EI_BEFORE in text:
        assert text.count(EI_BEFORE) == 1
        text = text.replace(EI_BEFORE, EI_AFTER, 1)
        note("A.eI : rectangle d'exclusion retire (Hann/Dalifort/Baux revalides)")
    elif "rectangle d'exclusion Hann/Dalifort retire" in text:
        print("  = A.eI deja corrige (v4)")
    else:
        sys.exit("ECHEC : fonction A.eI introuvable (bundle recompile ?)")

    for before, after, label in LITERAL_FIXES:
        if before in text:
            assert text.count(before) == 1, before
            text = text.replace(before, after, 1)
            note("constante %s" % label)
        elif after in text:
            print("  = constante deja recalee (%s)" % label)
        else:
            sys.exit("ECHEC : constante introuvable : %s" % before)

    if J0_COMMENT_ANCHOR in text:
        assert text.count(J0_COMMENT_ANCHOR) == 1
        text = text.replace(J0_COMMENT_ANCHOR, J0_COMMENT_NEW, 1)
        note("$.J0 : commentaire v4")
    elif "demos recalees sur le reseau JSON" in text:
        print("  = commentaire $.J0 deja en place")
    else:
        sys.exit("ECHEC : initialiseur $.J0 introuvable")

    for before, after, label in DEMO_FIXES:
        if before in text:
            assert text.count(before) == 1, label
            text = text.replace(before, after, 1)
            note("demo : %s" % label)
        elif after in text:
            print("  = demo deja corrigee (%s)" % label)
        else:
            sys.exit("ECHEC : demo introuvable : %s" % label)

    write(MAIN_JS, text)

    print("[2] main.dart.js : libelle Reglages")
    text = read(MAIN_JS)
    found = re.findall(LABEL_RE, text)
    if not found:
        sys.exit("ECHEC : libelle « Dakar Bus vX.Y.Z build N » introuvable")
    if found[0][1] != str(TARGET_BUILD):
        # Le changement de longueur (+1 octet) est sans risque : bundle sans
        # source map ni table d'offsets, MD5 RESOURCES recalcules en [7].
        new = re.sub(LABEL_RE,
                     lambda m: "Dakar Bus v%s build %d" % (m.group(1), TARGET_BUILD),
                     text)
        write(MAIN_JS, new)
        note("libelle Reglages « v%s build %s » -> « v%s build %d »"
             % (found[0][0], found[0][1], found[0][0], TARGET_BUILD))
    else:
        print("  = libelle deja a « build %d »" % TARGET_BUILD)


# ---------------------------------------------------------------------------
# B. Formes + C. bundle schéma 2 (sans réseau : réutilise les payloads route v3)
# ---------------------------------------------------------------------------

def eI_new(lat, lon):
    if lat < 14.55 or lat > 14.9:
        return False
    if lon < -17.6 or lon > -16.85:
        return False
    return True


def rebuild_bundle():
    print("[3] Formes guidees + bundle schema 2 (TER/BRT locaux, route reutilisee)")
    network = json.loads(read(NETWORK))
    pairs = json.loads(read(PAIRS))
    old_bundle = json.loads(read(GEOMS))
    old_geoms = old_bundle.get("geometries", {})

    # 1. Formes : validité + longueurs.
    shapes = load_shapes()
    for op, shape in shapes.items():
        n_stops = len(shape.ordered_stop_ids())
        length = shape.full_length_m()
        lo, hi = TER_LEN_RANGE if op == "ter" else BRT_LEN_RANGE
        if not (lo <= length <= hi):
            sys.exit("ECHEC : forme %s = %.1f km hors plage [%d, %d] km"
                     % (shape.shape_id, length / 1000, lo / 1000, hi / 1000))
        for p in shape.points:
            if not eI_new(p["lat"], p["lon"]):
                sys.exit("ECHEC : point de forme hors garde-fou : %s" % p)
        print("  = forme %s : %d points, %d arrets, %.1f km"
              % (shape.shape_id, len(shape.points), n_stops, length / 1000))

    # 2. Classification + géométries guidées (locales, 0 appel réseau).
    track_urls, road_urls, shared = classify_network_pairs(network)
    if set(pairs) != track_urls | road_urls:
        sys.exit("ECHEC : osrm_pairs.json incohérent avec le réseau")
    track_geoms, track_prov = build_track_geometries(network, shapes)
    assert set(track_geoms) == track_urls, "couverture guidee incomplete"
    print("  = %d paires guidees construites localement (TER %d, BRT %d)" % (
        len(track_geoms),
        sum(1 for u in track_geoms if track_prov[u].startswith("ter-")),
        sum(1 for u in track_geoms if track_prov[u].startswith("brt-"))))
    if shared:
        print("  = %d paires partagees route/guidee -> priorite site propre" % len(shared))

    # 3. Paires routières : réutilise les payloads v3 validés (aucun appel
    #    réseau ici ; le workflow CI les régénère via prefetch_osrm.py).
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
        sys.exit("ECHEC : %d paires routieres manquantes, %d invalides dans "
                 "le bundle v3 (lancez prefetch_osrm.py avec reseau)"
                 % (len(missing), len(invalid)))
    print("  = %d paires routieres reutilisees du bundle v3 (validees >= 2 pts)"
          % len(road_urls))

    out_text = canonical_bundle_text(geometries, provenance, pairs)
    geom_version = geom_version_for(out_text)
    if not GEOMS.exists() or read(GEOMS) != out_text:
        write(GEOMS, out_text)
        note("bundle schema 2 : %d geometries (%d guidees locales, %d route) "
             "GEOM_VERSION=%s" % (len(geometries), len(track_geoms),
                                 len(road_urls), geom_version))
    else:
        print("  = bundle deja a jour (GEOM_VERSION=%s)" % geom_version)
    return geom_version


# ---------------------------------------------------------------------------
# D. Fichiers statiques
# ---------------------------------------------------------------------------

def write_static_files():
    print("[4] Fichiers statiques : %s" % LOCAL_DIR.relative_to(ROOT))
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
# E. Service worker v4
# ---------------------------------------------------------------------------

BLOCK_START_RE = re.compile(r"// ===== Traces routiers reels v[^\n]*=====\n", re.S)
BLOCK_END = ("// The fetch handler redirects requests for RESOURCE files to the service\n"
             "// worker cache.\n")

BLOCK_V4 = """// ===== Traces reels v4 (TER ferroviaire + BRT site propre : jamais de routage routier) =====
// L'app demande ses geometries sur la MEME origine que le site :
//   {local}<lng,lat;lng,lat>?overview=full&geometries=geojson
// Trois niveaux de service, dans l'ordre :
//   1. cache persistant {cache} (instantane, offline) ;
//   2. bundle precharge assets/assets/data/osrm_geometries.json (1 requete) ;
//   3. fichiers statiques osrm/route/v1/driving/* — servis par GitHub Pages,
//      donc operationnels MEME sans service worker (premiere visite).
// Separation par mode (v4) : les paires TER/BRT sont des geometries LOCALES
// (voie ferree / site propre, table `provenance` du bundle) ; seules les
// paires AFTU/DDD/TATA proviennent du routeur OSRM (profil driving).
// Le routeur public n'est plus jamais appele par la carte en pratique.
const OSRM_CACHE = '{cache}';
const OSRM_PREFIX = 'https://router.project-osrm.org/route/v1/driving/';
const OSRM_LOCAL_PATH = '{local}';
const OSRM_SUFFIX = '?overview=full&geometries=geojson';
const OSRM_PAIRS_URL = 'assets/assets/data/osrm_pairs.json';
const OSRM_GEOMS_URL = 'assets/assets/data/osrm_geometries.json';
// Version des geometries prechargees. Le workflow « PrefetchOSRM geometries »
// la recalcule (hachage du bundle) a chaque regeneration de osrm_geometries.json.
const GEOM_VERSION = '{geom_version}';
// Marqueur de revision du correctif traces (audit, logs).
const TRACES_SW = '{traces}';

let osrmBundle = null;
let osrmBundlePromise = null;
let osrmSeedAttempts = 0;
const OSRM_SEED_MAX_ATTEMPTS = 3;
const OSRM_SEED_RETRY_MS = 30000;

async function osrmLoadBundle() {{
  if (osrmBundle) return osrmBundle;
  if (!osrmBundlePromise) {{
    osrmBundlePromise = (async () => {{
      try {{
        const res = await fetch(OSRM_GEOMS_URL + '?v=' + GEOM_VERSION, {{ cache: 'no-store' }});
        if (!res.ok) throw new Error('bundle HTTP ' + res.status);
        const data = await res.json();
        const geoms = data && data.geometries;
        if (!geoms) throw new Error('bundle sans geometries');
        osrmBundle = geoms;
        return geoms;
      }} finally {{
        osrmBundlePromise = null;
      }}
    }})();
  }}
  return osrmBundlePromise;
}}

// Toute reponse fabriquee ici porte les en-tetes CORS. Sans eux, une
// reponse synthetisee par le service worker pour une requete cross-origin est
// rejetee par le navigateur et l'app retombe sur une ligne droite.
function osrmJsonResponse(payload) {{
  return new Response(JSON.stringify(payload), {{ headers: {{
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Timing-Allow-Origin': '*'
  }} }});
}}

// Cle du bundle pour une URL, locale ({local}...) ou publique.
function osrmBundleKey(url) {{
  if (url.indexOf(OSRM_PREFIX) === 0) return url;
  let u;
  try {{
    u = new URL(url, self.location.href);
  }} catch (e) {{
    return null;
  }}
  if (u.pathname.indexOf(OSRM_LOCAL_PATH) !== 0) return null;
  const coords = u.pathname.substring(OSRM_LOCAL_PATH.length);
  if (!coords || coords.indexOf('/') !== -1) return null;
  return OSRM_PREFIX + coords + OSRM_SUFFIX;
}}

// Cache -> bundle. Renvoie null si la paire n'est disponible nulle part.
async function osrmServe(url) {{
  const key = osrmBundleKey(url);
  if (!key) return null;
  const cache = await caches.open(OSRM_CACHE);
  const hit = await cache.match(key);
  // Toujours reconstruite depuis un clone : la reponse stockee n'est jamais
  // consommee (une seconde lecture du cache doit marcher) et les en-tetes CORS
  // sont garantis quelle que soit la provenance de l'entree.
  if (hit) return osrmJsonResponse(await hit.clone().json());
  try {{
    const geoms = await osrmLoadBundle();
    const payload = geoms && geoms[key];
    if (payload) {{
      const response = osrmJsonResponse(payload);
      await cache.put(key, response.clone());
      return response;
    }}
  }} catch (e) {{
    console.warn('OSRM ' + TRACES_SW + ' : bundle indisponible (' + e + ')');
  }}
  return null;
}}

// Requete de l'app sur la meme origine.
// Dernier niveau : le fichier statique du depot (marche aussi sans SW).
async function osrmLocalRespond(request) {{
  const served = await osrmServe(request.url);
  if (served) return served;
  return fetch(request, {{ cache: 'no-store' }});
}}

// Ancien prefixe cross-origin, pour les clients dont le main.dart.js n'est pas
// encore a jour : cache -> bundle -> fichier statique same-origin -> routeur
// public en file regulee. L'etape fichier statique garantit que les paires
// guidees (TER/BRT, locales par construction) n'atteignent jamais le routeur
// public, meme pour un client en version mixte.
async function osrmRespond(request) {{
  const served = await osrmServe(request.url);
  if (served) return served;
  try {{
    const coords = request.url.substring(OSRM_PREFIX.length).split('?')[0];
    if (coords && coords.indexOf('/') === -1 && coords.indexOf(';') !== -1) {{
      const file = await fetch(OSRM_LOCAL_PATH + coords, {{ cache: 'no-store' }});
      if (file.ok) return osrmJsonResponse(await file.json());
    }}
  }} catch (e) {{
    console.warn('OSRM ' + TRACES_SW + ' : repli statique KO (' + e + ')');
  }}
  try {{
    return await osrmSchedule(request.url);
  }} catch (e) {{
    return fetch(request, {{ cache: 'no-store' }});
  }}
}}

let osrmInflight = {{}};
let osrmQueue = [];
let osrmActive = 0;
let osrmPrefetchStarted = false;
const OSRM_MAX_CONC = 2;
const OSRM_SPACING_MS = 400;
const OSRM_TIMEOUT_MS = 10000;

function osrmNetwork(url, attempt) {{
  return new Promise((resolve, reject) => {{
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), OSRM_TIMEOUT_MS);
    fetch(url, {{ signal: ctrl.signal }}).then((res) => {{
      clearTimeout(t);
      if (res.ok) {{
        return caches.open(OSRM_CACHE).then((c) => c.put(url, res.clone())).then(() => resolve(res));
      }}
      if ((res.status === 429 || res.status >= 500) && attempt < 4) {{
        return setTimeout(() => resolve(osrmNetwork(url, attempt + 1)), 1500 * attempt);
      }}
      reject(new Error('OSRM ' + res.status));
    }}).catch((e) => {{
      clearTimeout(t);
      if (attempt < 4) return setTimeout(() => resolve(osrmNetwork(url, attempt + 1)), 1500 * attempt);
      reject(e);
    }});
  }});
}}

function osrmSchedule(url) {{
  if (osrmInflight[url]) return osrmInflight[url];
  const p = new Promise((resolve, reject) => {{ osrmQueue.push({{ url, resolve, reject }}); osrmPump(); }});
  osrmInflight[url] = p;
  p.finally(() => {{ delete osrmInflight[url]; }});
  return p;
}}

function osrmPump() {{
  while (osrmActive < OSRM_MAX_CONC && osrmQueue.length > 0) {{
    const job = osrmQueue.shift();
    osrmActive++;
    osrmNetwork(job.url, 1)
      .then(job.resolve)
      .catch((e) => {{ console.warn('OSRM serve fail', job.url, e); job.reject(e); }})
      .finally(() => {{ osrmActive--; setTimeout(osrmPump, OSRM_SPACING_MS); }});
  }}
}}

// Installe en une seule requete les geometries prechargees par le workflow
// « PrefetchOSRM geometries » (bundle osrm_geometries.json commite sur gh-pages).
async function osrmSeedFromBundle() {{
  let geoms;
  try {{
    geoms = await osrmLoadBundle();
  }} catch (e) {{
    console.warn('OSRM ' + TRACES_SW + ' : bundle precharge indisponible (' + e
        + '), repli fichiers statiques + nouvelle tentative programmee');
    osrmScheduleSeedRetry();
    return;
  }}
  const cache = await caches.open(OSRM_CACHE);
  const before = new Set((await cache.keys()).map((r) => r.url));
  const urls = Object.keys(geoms);
  let n = 0;
  for (const url of urls) {{
    if (before.has(url)) continue;
    await cache.put(new Request(url), osrmJsonResponse(geoms[url]));
    n++;
  }}
  console.debug('OSRM ' + TRACES_SW + ' : ' + n + ' geometries installees depuis le bundle ('
      + urls.length + ' au total)');
  const after = new Set((await cache.keys()).map((r) => r.url));
  const missing = urls.filter((u) => !after.has(u));
  if (missing.length === 0) {{
    console.debug('OSRM ' + TRACES_SW + ' : couverture complete ' + after.size + '/' + urls.length);
    return;
  }}
  console.warn('OSRM ' + TRACES_SW + ' : ' + missing.length + ' geometries manquantes apres semis');
  osrmScheduleSeedRetry();
}}

function osrmScheduleSeedRetry() {{
  if (osrmSeedAttempts >= OSRM_SEED_MAX_ATTEMPTS) {{
    console.warn('OSRM ' + TRACES_SW + ' : semis abandonne, le repli bundle/fichiers prend le relais');
    return;
  }}
  osrmSeedAttempts++;
  setTimeout(() => {{
    osrmSeedFromBundle().catch((e) => console.warn('OSRM ' + TRACES_SW + ' : retry KO', e));
  }}, OSRM_SEED_RETRY_MS);
}}

async function osrmPrefetch() {{
  if (osrmPrefetchStarted) return;
  osrmPrefetchStarted = true;
  try {{
    const cache = await caches.open(OSRM_CACHE);
    const res = await fetch(OSRM_PAIRS_URL, {{ cache: 'no-store' }});
    const pairs = await res.json();
    const existing = new Set((await cache.keys()).map((r) => r.url));
    for (const url of pairs) {{
      if (!existing.has(url)) osrmSchedule(url).catch(() => {{}});
    }}
    console.debug('OSRM prefetch :', pairs.length - existing.size, 'geometries en file');
  }} catch (e) {{ console.warn('OSRM prefetch fail', e); }}
}}

self.addEventListener('activate', (event) => {{
  event.waitUntil((async () => {{
    try {{
      await osrmSeedFromBundle();
      await osrmPrefetch();
    }} catch (e) {{
      // Un semis incomplet ne doit jamais bloquer l'activation.
      console.warn('OSRM ' + TRACES_SW + ' : semis incomplet (' + e
          + '), repli bundle/fichiers statiques actif');
    }}
    await caches.delete('osrm-geom-v1'); // caches obsoletes
    await caches.delete('osrm-geom-v2');
    await caches.delete('osrm-geom-v3');
  }})());
}});

"""


def patch_sw(geom_version):
    print("[5] flutter_service_worker.js : bloc OSRM v4")
    text = read(SW)
    if ("TRACES_SW = '%s'" % TRACES_SW) not in text:
        m = BLOCK_START_RE.search(text)
        if not m:
            sys.exit("ECHEC : en-tête du bloc OSRM introuvable dans le service worker")
        end = text.find(BLOCK_END, m.end())
        if end < 0:
            sys.exit("ECHEC : fin du bloc OSRM introuvable dans le service worker")
        block = BLOCK_V4.format(local=LOCAL_PATH, cache=OSRM_CACHE,
                                geom_version=geom_version, traces=TRACES_SW)
        text = text[:m.start()] + block + text[end:]
        write(SW, text)
        note("bloc OSRM réécrit en v4 (cache %s, repli statique avant routeur)"
             % OSRM_CACHE)
        text = read(SW)
    else:
        print("  = bloc OSRM déjà en v4")

    # GEOM_VERSION alignée sur le bundle (idempotent).
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
# F. Versions + workflow + RESOURCES
# ---------------------------------------------------------------------------

SWV_RE = r'(serviceWorkerVersion\s*:\s*")(\d+)(")'


def patch_versions():
    print("[6] version.json / index.html / flutter_bootstrap.js / workflow")
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
        if m.group(2) != SW_VERSION_V4:
            new = text[:m.start()] + m.group(1) + SW_VERSION_V4 + m.group(3) + text[m.end():]
            write(path, new)
            note("%s serviceWorkerVersion %s -> %s" % (path.name, m.group(2), SW_VERSION_V4))
        else:
            print("  = %s déjà en %s" % (path.name, SW_VERSION_V4))

    if WORKFLOW.exists():
        text = read(WORKFLOW)
        old_msg = "chore(osrm): geometries v2 regenerees (workflow PrefetchOSRM geometries)"
        new_msg = "chore(osrm): geometries v4 regenerees (workflow PrefetchOSRM geometries)"
        if old_msg in text:
            write(WORKFLOW, text.replace(old_msg, new_msg, 1))
            note("workflow : message de commit v2 -> v4")
        elif new_msg in text:
            print("  = workflow déjà en v4")
        else:
            print("  ! workflow : message de commit inattendu, laissé tel quel")


def patch_resources():
    print("[7] flutter_service_worker.js : sommes MD5 de RESOURCES")
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
    print("[8] Verification")
    problems = []
    main_js = read(MAIN_JS)
    network = json.loads(read(NETWORK))
    stops = {s["id"]: s for s in network.get("stops", [])}

    # 1. eI : rectangle retiré, garde-fou conservé, 94/94 valides.
    if "-17.435&&s<=-17.375" in main_js or "14.745&&s>=-17.435" in main_js:
        problems.append("main.dart.js : rectangle d'exclusion toujours présent")
    elif "rectangle d'exclusion Hann/Dalifort retire" not in main_js:
        problems.append("main.dart.js : marqueur v4 absent dans A.eI")
    else:
        bad = [s["id"] for s in network["stops"]
               if not eI_new(s["latitude"], s["longitude"])]
        if bad:
            problems.append("garde-fou v4 : arrêts invalides %s" % bad)
        else:
            print("  ok eI v4 : rectangle retire, 94/94 arrets valides")

    # 2. Constantes recalées.
    for _, after, label in LITERAL_FIXES:
        if after not in main_js:
            problems.append("constante non recalee : %s" % label)
    if not any(p.startswith("constante") for p in problems):
        print("  ok constantes : Rufisque, Diamniadio, Fadia, Liberte 6 = JSON")

    # 3. Démos : paires demandées == paires du bundle.
    demo_routes = {
        "TER": ["stop_dakar_ter", "stop_colobane", "stop_hann", "stop_dalifort_ter",
                "stop_baux_maraichers", "stop_pikine", "stop_thiaroye",
                "stop_yeumbeul", "stop_keur_mbaye_fall", "stop_pnr",
                "stop_rufisque", "stop_bargny", "stop_diamniadio"],
        "B1": [s for s in
               json.loads(read(NETWORK))["routes"][1]["stops"]],  # brt B1
        "DDD": ["stop_guediawaye", "stop_scatt_urbam", "stop_parcelles_u26"],
        "TATA": ["stop_parcelles_u26", "stop_petersen"],
    }
    for _, after, label in DEMO_FIXES:
        if after not in main_js:
            problems.append("demo non réécrite : %s" % label)
    if not any(p.startswith("demo") for p in problems):
        print("  ok demos $.J0 : TER 13 gares, B1 12 stations direct, DDD/TATA = JSON")
    bundle_keys = set(json.loads(read(GEOMS)).get("geometries", {}))
    for name, ids in demo_routes.items():
        for i in range(len(ids) - 1):
            a, b = stops[ids[i]], stops[ids[i + 1]]
            url = (OSRM_PREFIX + dart_double(a["longitude"]) + ","
                   + dart_double(a["latitude"]) + ";"
                   + dart_double(b["longitude"]) + ","
                   + dart_double(b["latitude"]) + OSRM_SUFFIX)
            if url not in bundle_keys:
                problems.append("demo %s : paire %s->%s absente du bundle"
                                % (name, ids[i], ids[i + 1]))
    if not any(p.startswith("demo ") for p in problems):
        print("  ok demos : toutes leurs paires sont dans le bundle (0 appel 404)")

    # 4. Bundle schéma 2 : couverture + provenance + longueurs.
    bundle = json.loads(read(GEOMS))
    pairs = json.loads(read(PAIRS))
    track_urls, road_urls, _ = classify_network_pairs(network)
    if bundle.get("schema") != 2:
        problems.append("bundle : schema=%r (attendu 2)" % bundle.get("schema"))
    if set(bundle.get("geometries", {})) != set(pairs):
        problems.append("bundle : clés != osrm_pairs.json")
    prov = bundle.get("provenance", {})
    track_ok = all(prov.get(u, "").endswith("-v4") for u in track_urls)
    road_ok = all(prov.get(u) == "osrm-driving" for u in road_urls)
    if not (track_ok and road_ok):
        problems.append("bundle : provenance incohérente")
    else:
        print("  ok bundle schema 2 : %d geometries (%d guidees locales, %d route)"
              % (len(pairs), len(track_urls), len(road_urls)))
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
        print("  ok TER ferroviaire : %.1f km (~35 km officiels)" % (ter_len / 1000))
    if not (BRT_LEN_RANGE[0] <= brt_len <= BRT_LEN_RANGE[1]):
        problems.append("BRT : %.1f km hors plage" % (brt_len / 1000))
    else:
        print("  ok BRT site propre : %.1f km (modele 12 stations)" % (brt_len / 1000))
    # Extrémités exactes des tronçons guidés.
    for route in network["routes"]:
        if route.get("operator_id") not in ("ter", "brt"):
            continue
        ids = route["stops"]
        for i in range(len(ids) - 1):
            a, b = stops[ids[i]], stops[ids[i + 1]]
            url = (OSRM_PREFIX + dart_double(a["longitude"]) + ","
                   + dart_double(a["latitude"]) + ";" + dart_double(b["longitude"])
                   + "," + dart_double(b["latitude"]) + OSRM_SUFFIX)
            coords = bundle["geometries"][url]["routes"][0]["geometry"]["coordinates"]
            if (coords[0] != [a["longitude"], a["latitude"]]
                    or coords[-1] != [b["longitude"], b["latitude"]]):
                problems.append("troncon guide imprecis : %s->%s" % (ids[i], ids[i + 1]))
    if not any(p.startswith("troncon") for p in problems):
        print("  ok troncons guides : extremites = coordonnees exactes des arrets")

    # 5. Fichiers statiques.
    on_disk = {p.name for p in LOCAL_DIR.iterdir()} if LOCAL_DIR.exists() else set()
    if on_disk != static_expected:
        problems.append("fichiers statiques : %d sur disque, %d attendus"
                        % (len(on_disk), len(static_expected)))
    else:
        print("  ok repli sans service worker : %d fichiers" % len(on_disk))

    # 6. Service worker + versions + MD5.
    sw = read(SW)
    for marker in ("TRACES_SW = '%s'" % TRACES_SW, "OSRM_CACHE = '%s'" % OSRM_CACHE,
                   "const GEOM_VERSION = '%s';" % geom_version,
                   "fichier statique same-origin", "caches.delete('osrm-geom-v3')"):
        if marker not in sw:
            problems.append("service worker : marqueur manquant %r" % marker)
    if not any(p.startswith("service worker") for p in problems):
        print("  ok service worker v4 : cache %s, GEOM_VERSION=%s" % (OSRM_CACHE, geom_version))
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
        if not m or m.group(2) != SW_VERSION_V4:
            problems.append("%s : serviceWorkerVersion=%s" % (path.name, m and m.group(2)))
    if not any("serviceWorkerVersion" in p for p in problems):
        print("  ok serviceWorkerVersion=%s (index + bootstrap)" % SW_VERSION_V4)
    block = re.search(r"const RESOURCES = (\{.*?\});", sw, re.S)
    resources = json.loads(block.group(1))
    for key in ("main.dart.js", "index.html", "/", "version.json", "flutter_bootstrap.js"):
        path = ROOT / ("index.html" if key == "/" else key)
        if resources.get(key) != md5(path):
            problems.append("RESOURCES[%s] : MD5 incohérent" % key)
    if not any(p.startswith("RESOURCES") for p in problems):
        print("  ok RESOURCES : MD5 cohérents")

    # 7. Filtres v3 toujours en place (non-régression).
    if "$1(a){return!0}" not in main_js.split("A.ap9.prototype=")[1][:400]:
        problems.append("non-régression : filtre A.ap9 modifié")
    elif "$1(a){return!1}" not in main_js.split("A.ap6.prototype=")[1][:400]:
        problems.append("non-régression : filtre A.ap6 modifié")
    elif "router.project-osrm.org" in main_js:
        problems.append("non-régression : routeur public de retour dans main.dart.js")
    else:
        print("  ok non-regression v3 : filtres carte + same-origin intacts")

    if problems:
        for p in problems:
            print("  KO " + p)
        sys.exit("ECHEC : verification incomplete (%d probleme(s))" % len(problems))


def main():
    print("Correctif traces v4 — checkout : %s" % ROOT)
    require_v3()
    patch_main_js()
    geom_version = rebuild_bundle()
    static_expected = write_static_files()
    patch_sw(geom_version)
    patch_versions()
    patch_resources()
    verify(static_expected, geom_version)
    print("")
    if CHANGES:
        print("Correctif v4 applique (%d modification(s)) :" % len(CHANGES))
        for c in CHANGES:
            print("  * " + c)
    else:
        print("Correctif v4 deja en place : aucune modification (script idempotent).")
    print("")
    print("Effet cote clients : 1er reload -> le SW %s s'installe ; 2e reload -> "
          "« build %d », TER sur voie ferree (~35 km), BRT en site propre, "
          "demos recalees." % (SW_VERSION_V4, TARGET_BUILD))


if __name__ == "__main__":
    main()
