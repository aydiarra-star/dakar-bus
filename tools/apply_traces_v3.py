#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v3 — applique les modifications v3 sur un checkout gh-pages.

Rôle (équivalent du runbook TRACES-V3-HANDOFF) : si des fichiers v3 semblent
manquants ou réinitialisés, rejouer `python3 tools/apply_traces_v3.py`.
Le script est idempotent : le rejouer ne change rien si le correctif est déjà là.

Prérequis : le correctif v2.1 doit être présent (cache OSRM, bundle
`assets/assets/data/osrm_geometries.json`, workflow « PrefetchOSRM geometries »).

POURQUOI v3 (ce que v1/v2/v2.1 ne pouvaient pas corriger)
---------------------------------------------------------
Le dépôt ne contient aucune source Flutter : gh-pages ne porte que la sortie
compilée. Tout se joue donc dans `main.dart.js`.

1. LA CARTE NE DEMANDAIT DES TRACÉS RÉELS QUE POUR 2 MODES SUR 5.

   `main.dart.js` construit les polylignes de la carte dans deux fonctions de
   l'état `A.F1` (créé par `A.zP`) :

     * `xw()` — appelle `A.agn(arretA, arretB)` (donc OSRM) pour chaque paire
       d'arrêts consécutifs, mais seulement sur les lignes filtrées par
       `A.ap9` : `$1(a){var s=a.c; return s==="TER"||s==="BRT"}`.
     * `xv()` — dessine les lignes filtrées par `A.ap6`
       (`return!(s==="TER"||s==="BRT")`) en reliant les arrêts **en ligne
       droite**, sans jamais appeler OSRM.

   Or `$.J0()` contient 105 lignes issues de `assets/assets/data/dakar_network.json`
   (1 TER, 2 BRT, 15 DDD, 80 AFTU, 7 Tata) plus les lignes de démonstration.
   Autrement dit : 102 lignes sur 105 étaient dessinées en ligne droite **par
   conception du bundle compilé**, quel que soit l'état du cache OSRM. C'est la
   raison pour laquelle les correctifs v1/v2/v2.1 — tous centrés sur le service
   worker — n'ont produit aucun changement visible sur la carte.

   v3 inverse les deux filtres : `xw()` traite toutes les lignes (281 paires
   d'arrêts, toutes présentes dans le bundle) et `xv()` n'ajoute plus rien.

2. LES TRACÉS DÉPENDAIENT D'UN HÔTE TIERS ET D'UN CORS INCERTAIN.

   L'app construisait
   `https://router.project-osrm.org/route/v1/driving/<lng,lat;lng,lat>?overview=full&geometries=geojson`.
   Une réponse fabriquée par le service worker pour une requête cross-origin
   doit porter `Access-Control-Allow-Origin`, sans quoi le navigateur la
   rejette et `A.aS2` retombe sur son repli « ligne droite entre deux arrêts »
   (`A.b([a,a0])`). v3 supprime le problème à la racine : l'app appelle
   désormais la MÊME origine que le site
   (`/dakar-bus/osrm/route/v1/driving/...`), ce qui rend le CORS sans objet, et
   le service worker ajoute quand même les en-têtes CORS à toute réponse qu'il
   fabrique (pour les clients dont le `main.dart.js` n'est pas encore à jour).

3. ÇA DOIT MARCHER AU TOUT PREMIER CHARGEMENT, MÊME SANS SERVICE WORKER.

   v3 matérialise les 281 réponses dans `osrm/route/v1/driving/*` : ce sont de
   vrais fichiers du dépôt, servis par GitHub Pages. Ordre de service :
   cache `osrm-geom-v3` → bundle préchargé → fichiers statiques. Le routeur
   public OSRM n'est plus jamais appelé par la carte.

Ce que fait ce script
---------------------
  1. main.dart.js : `A.ap9` -> toutes les lignes passent par OSRM ;
     `A.ap6` -> plus aucune ligne en ligne droite.
  2. main.dart.js : préfixe OSRM -> `/dakar-bus/osrm/route/v1/driving/`
     (préfixe dérivé du `<base href>` d'index.html, donc cohérent par
     construction).
  3. main.dart.js : libellé Réglages -> « build 9 » (remplacement à longueur
     identique, aucun décalage dans le bundle).
  4. version.json : build_number -> 9.
  5. index.html + flutter_bootstrap.js : bump de `serviceWorkerVersion`
     (477962404 -> 477962405) pour propager le nouveau service worker.
  6. flutter_service_worker.js : bloc OSRM v3 (mêmes origine, en-têtes CORS,
     cache `osrm-geom-v3`, repli fichiers statiques, nettoyage des caches v1/v2).
  7. `osrm/route/v1/driving/*` : 281 fichiers JSON (repli sans service worker).
  8. Sommes MD5 de RESOURCES recalculées pour tous les fichiers modifiés — sans
     cela le service worker juge la ressource inchangée et sert l'ancienne copie.
  9. Vérification finale et compte rendu sur stdout.

Ne touche à rien d'autre : données réseau, bundle de géométries, workflow
« PrefetchOSRM geometries » et UI restent intacts.
"""
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN_JS = ROOT / "main.dart.js"
INDEX = ROOT / "index.html"
BOOTSTRAP = ROOT / "flutter_bootstrap.js"
VERSION = ROOT / "version.json"
SW = ROOT / "flutter_service_worker.js"
PAIRS = ROOT / "assets" / "assets" / "data" / "osrm_pairs.json"
GEOMS = ROOT / "assets" / "assets" / "data" / "osrm_geometries.json"
NETWORK = ROOT / "assets" / "assets" / "data" / "dakar_network.json"

OSRM_PREFIX = "https://router.project-osrm.org/route/v1/driving/"
OSRM_SUFFIX = "?overview=full&geometries=geojson"

TARGET_BUILD = 9
SW_VERSION_V3 = "477962405"      # était 477962404 (v2.1), 477962403 (v2)
TRACES_SW = "v3"
OSRM_CACHE = "osrm-geom-v3"

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
    """`<base href>` d'index.html, avec slash final — préfixe du site."""
    m = re.search(r'<base href="([^"]+)"', read(INDEX))
    if not m:
        sys.exit("ECHEC : <base href> introuvable dans index.html")
    href = m.group(1)
    return href if href.endswith("/") else href + "/"


LOCAL_PATH = base_href() + "osrm/route/v1/driving/"
LOCAL_DIR = ROOT / "osrm" / "route" / "v1" / "driving"


# ---------------------------------------------------------------------------
# Garde-fou : le correctif v2.1 doit être en place
# ---------------------------------------------------------------------------

def require_v21():
    print("[0] Controle du prerequis v2.1")
    if not SW.exists():
        sys.exit("ECHEC : flutter_service_worker.js absent (mauvais checkout ?)")
    sw = read(SW)
    missing = [m for m in ("osrmSeedFromBundle", "GEOM_VERSION") if m not in sw]
    if missing:
        sys.exit("ECHEC : correctif v2/v2.1 absent (%s). Rejouez d'abord "
                 "tools/apply_traces_v21.py" % ", ".join(missing))
    for f in (PAIRS, GEOMS):
        if not f.exists():
            sys.exit("ECHEC : %s absent (correctif v2 incomplet)" % f.name)
    print("  = v2.1 en place (semis bundle, GEOM_VERSION, bundle de geometries)")
    print("  = prefixe local calcule depuis <base href> : %s" % LOCAL_PATH)


# ---------------------------------------------------------------------------
# 1-3. main.dart.js
# ---------------------------------------------------------------------------

LABEL_RE = r"Dakar Bus v(\d+(?:\.\d+)*) build (\d+)"
URL_RE = r'"https://router\.project-osrm\.org/route/v1/driving/"'

# Filtres des polylignes de la carte (état A.F1).
AP9_BEFORE = 'A.ap9.prototype={\n$1(a){var s=a.c\nreturn s==="TER"||s==="BRT"},\n$S:128}'
AP9_AFTER = ("A.ap9.prototype={\n"
             "// v3 : TOUTES les lignes du reseau passent par OSRM (avant : TER et BRT).\n"
             "$1(a){return!0},\n$S:128}")
AP6_BEFORE = 'A.ap6.prototype={\n$1(a){var s=a.c\nreturn!(s==="TER"||s==="BRT")},\n$S:128}'
AP6_AFTER = ("A.ap6.prototype={\n"
             "// v3 : plus aucune ligne en ligne droite, xw() couvre tout le reseau.\n"
             "$1(a){return!1},\n$S:128}")


def patch_main_js():
    print("[1] main.dart.js : polylignes de la carte")
    text = read(MAIN_JS)

    if AP9_BEFORE in text and AP6_BEFORE in text:
        text = text.replace(AP9_BEFORE, AP9_AFTER, 1)
        text = text.replace(AP6_BEFORE, AP6_AFTER, 1)
        note("filtre xw() (A.ap9) -> toutes les lignes ; filtre xv() (A.ap6) -> aucune")
    elif "v3 : TOUTES les lignes du reseau passent par OSRM" in text:
        print("  = filtres déjà inversés (toutes les lignes passent par OSRM)")
    else:
        sys.exit("ECHEC : filtres A.ap9/A.ap6 introuvables dans main.dart.js "
                 "(bundle recompilé ? adapter AP9_BEFORE/AP6_BEFORE)")

    if re.search(URL_RE, text):
        text = re.sub(URL_RE, json.dumps(LOCAL_PATH), text, count=1)
        note("prefixe OSRM -> %s (meme origine : plus de CORS, plus de rate-limit)"
             % LOCAL_PATH)
    elif ('"%s"' % LOCAL_PATH) in text:
        print("  = préfixe déjà en même origine (%s)" % LOCAL_PATH)
    else:
        sys.exit("ECHEC : préfixe OSRM introuvable dans main.dart.js")

    write(MAIN_JS, text)

    print("[2] main.dart.js : libelle Reglages")
    text = read(MAIN_JS)
    found = re.findall(LABEL_RE, text)
    if not found:
        sys.exit("ECHEC : libellé « Dakar Bus vX.Y.Z build N » introuvable dans "
                 "main.dart.js (bundle recompilé ? adapter LABEL_RE)")
    current = found[0]
    if current[1] != str(TARGET_BUILD):
        new = re.sub(LABEL_RE,
                     lambda m: "Dakar Bus v%s build %d" % (m.group(1), TARGET_BUILD),
                     text)
        if len(new) != len(text):
            sys.exit("ECHEC : le remplacement a changé la taille du bundle "
                     "(%d -> %d)" % (len(text), len(new)))
        write(MAIN_JS, new)
        note("libellé Réglages « v%s build %s » -> « v%s build %d »"
             % (current[0], current[1], current[0], TARGET_BUILD))
    else:
        print("  = libellé déjà à « build %d »" % TARGET_BUILD)


# ---------------------------------------------------------------------------
# 4. version.json
# ---------------------------------------------------------------------------

def patch_version():
    print("[3] version.json : build_number")
    text = read(VERSION)
    m = re.search(r'"build_number"\s*:\s*"?(\d+)"?', text)
    if not m:
        sys.exit("ECHEC : build_number introuvable dans version.json")
    if m.group(1) == str(TARGET_BUILD):
        print("  = build_number déjà à %d" % TARGET_BUILD)
        return
    quoted = '"' in text[m.start():m.end()]
    repl = '"build_number":"%d"' % TARGET_BUILD if quoted else '"build_number":%d' % TARGET_BUILD
    new = text[:m.start()] + repl + text[m.end():]
    json.loads(new)  # garde-fou : JSON toujours valide
    write(VERSION, new)
    note("version.json build_number %s -> %d" % (m.group(1), TARGET_BUILD))


# ---------------------------------------------------------------------------
# 5. Propagation du service worker
# ---------------------------------------------------------------------------

SWV_RE = r'(serviceWorkerVersion\s*:\s*")(\d+)(")'


def patch_sw_versions():
    print("[4] index.html / flutter_bootstrap.js : serviceWorkerVersion")
    for path in (INDEX, BOOTSTRAP):
        text = read(path)
        m = re.search(SWV_RE, text)
        if not m:
            sys.exit("ECHEC : serviceWorkerVersion introuvable dans %s" % path.name)
        if m.group(2) == SW_VERSION_V3:
            print("  = %s déjà en %s" % (path.name, SW_VERSION_V3))
            continue
        new = text[:m.start()] + m.group(1) + SW_VERSION_V3 + m.group(3) + text[m.end():]
        write(path, new)
        note("%s serviceWorkerVersion %s -> %s" % (path.name, m.group(2), SW_VERSION_V3))


# ---------------------------------------------------------------------------
# 6. flutter_service_worker.js : bloc OSRM v3
# ---------------------------------------------------------------------------

BLOCK_START_RE = re.compile(
    r"// ===== Traces routiers reels v[^\n]*=====\n", re.S)
BLOCK_END = ("// The fetch handler redirects requests for RESOURCE files to the service\n"
             "// worker cache.\n")

BLOCK_V3 = """// ===== Traces routiers reels v3 (meme origine : aucun appel au routeur public) =====
// L'app demande ses geometries sur la MEME origine que le site :
//   {local}<lng,lat;lng,lat>?overview=full&geometries=geojson
// Trois niveaux de service, dans l'ordre :
//   1. cache persistant {cache} (instantane, offline) ;
//   2. bundle precharge assets/assets/data/osrm_geometries.json (1 requete) ;
//   3. fichiers statiques osrm/route/v1/driving/* — servis par GitHub Pages,
//      donc operationnels MEME sans service worker (premiere visite).
// Le routeur public OSRM n'est plus jamais appele par la carte : plus de 429,
// plus de ligne droite entre deux arrets.
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

// v3 : toute reponse fabriquee ici porte les en-tetes CORS. Sans eux, une
// reponse synthetisee par le service worker pour une requete cross-origin est
// rejetee par le navigateur et l'app retombe sur une ligne droite.
function osrmJsonResponse(payload) {{
  return new Response(JSON.stringify(payload), {{ headers: {{
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Timing-Allow-Origin': '*'
  }} }});
}}

// v3 : cle du bundle pour une URL, locale ({local}...) ou publique.
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

// v3 : requete de l'app sur la meme origine.
// Dernier niveau : le fichier statique du depot (marche aussi sans SW).
async function osrmLocalRespond(request) {{
  const served = await osrmServe(request.url);
  if (served) return served;
  return fetch(request, {{ cache: 'no-store' }});
}}

// Ancien prefixe cross-origin, pour les clients dont le main.dart.js n'est pas
// encore a jour : cache -> bundle -> routeur public en file regulée.
async function osrmRespond(request) {{
  const served = await osrmServe(request.url);
  if (served) return served;
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
  }})());
}});

"""

FETCH_BRANCH_BEFORE = (
    "  // Requetes OSRM : servir depuis le cache de traces reels (ou file regulée).\n"
    "  if (event.request.url.startsWith(OSRM_PREFIX)) {\n"
    "    event.respondWith(osrmRespond(event.request));\n"
    "    return;\n"
    "  }\n")

FETCH_BRANCH_V3 = (
    "  // v3 : tracés reels — meme origine d'abord (l'app), ancien prefixe ensuite.\n"
    "  if (new URL(event.request.url).pathname.indexOf(OSRM_LOCAL_PATH) === 0) {\n"
    "    event.respondWith(osrmLocalRespond(event.request));\n"
    "    return;\n"
    "  }\n"
    "  if (event.request.url.startsWith(OSRM_PREFIX)) {\n"
    "    event.respondWith(osrmRespond(event.request));\n"
    "    return;\n"
    "  }\n")


def patch_sw():
    print("[5] flutter_service_worker.js : bloc OSRM v3")
    text = read(SW)

    if ("TRACES_SW = '%s'" % TRACES_SW) not in text:
        m = BLOCK_START_RE.search(text)
        if not m:
            sys.exit("ECHEC : en-tête du bloc OSRM introuvable dans le service worker")
        end = text.find(BLOCK_END, m.end())
        if end < 0:
            sys.exit("ECHEC : fin du bloc OSRM introuvable dans le service worker")
        geom = re.search(r"const GEOM_VERSION = '([^']*)';", text)
        if not geom:
            sys.exit("ECHEC : constante GEOM_VERSION introuvable")
        block = BLOCK_V3.format(local=LOCAL_PATH, cache=OSRM_CACHE,
                                geom_version=geom.group(1), traces=TRACES_SW)
        text = text[:m.start()] + block + text[end:]
        note("bloc OSRM réécrit en v3 (même origine, en-têtes CORS, cache %s)" % OSRM_CACHE)
        write(SW, text)
    else:
        print("  = bloc OSRM déjà en v3")

    text = read(SW)
    if FETCH_BRANCH_BEFORE in text:
        text = text.replace(FETCH_BRANCH_BEFORE, FETCH_BRANCH_V3, 1)
        write(SW, text)
        note("fetch handler : requêtes %s servies par osrmLocalRespond" % LOCAL_PATH)
    elif "osrmLocalRespond(event.request)" in text:
        print("  = fetch handler déjà v3")
    else:
        sys.exit("ECHEC : branche OSRM du fetch handler introuvable (format inattendu)")


# ---------------------------------------------------------------------------
# 7. Fichiers statiques : repli sans service worker
# ---------------------------------------------------------------------------

def write_static_files():
    print("[6] Fichiers statiques : %s" % LOCAL_DIR.relative_to(ROOT))
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
    if written or stale:
        note("osrm/route/v1/driving : %d fichier(s) écrit(s), %d supprimé(s) (%d au total)"
             % (written, len(stale), len(expected)))
    else:
        print("  = %d fichiers déjà à jour" % len(expected))
    return expected


# ---------------------------------------------------------------------------
# 8. RESOURCES : sommes MD5
# ---------------------------------------------------------------------------

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
            print("  ! RESOURCES[%s] : fichier absent du checkout, laissé tel quel" % key)
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
# 9. Vérification finale
# ---------------------------------------------------------------------------

def dart_double(value):
    """Formatage d'un double dans les URL construites par l'app (Dart2js == repr)."""
    return repr(float(value))


def expected_pairs(network):
    stops = {s["id"]: s for s in network.get("stops", [])}
    urls, seen = [], set()
    for route in network.get("routes", []):
        ids = route.get("stops", [])
        for i in range(len(ids) - 1):
            a, b = stops.get(ids[i]), stops.get(ids[i + 1])
            if not a or not b:
                continue
            url = (OSRM_PREFIX
                   + dart_double(a["longitude"]) + "," + dart_double(a["latitude"]) + ";"
                   + dart_double(b["longitude"]) + "," + dart_double(b["latitude"])
                   + OSRM_SUFFIX)
            if url in seen:
                continue
            seen.add(url)
            urls.append(url)
    return urls


def verify(static_expected):
    print("[8] Verification")
    problems = []
    main_js = read(MAIN_JS)

    # 1. filtres de la carte
    if AP9_BEFORE in main_js or AP6_BEFORE in main_js:
        problems.append("main.dart.js : filtres A.ap9/A.ap6 encore en v2.1 "
                        "(seules TER et BRT seraient tracées)")
    elif ("$1(a){return!0}" not in main_js.split("A.ap9.prototype=")[1][:400]
          or "$1(a){return!1}" not in main_js.split("A.ap6.prototype=")[1][:400]):
        problems.append("main.dart.js : filtres A.ap9/A.ap6 inattendus")
    else:
        routes = json.loads(read(NETWORK)).get("routes", [])
        print("  ok carte : les %d lignes du reseau passent toutes par OSRM "
              "(plus aucune ligne droite)" % len(routes))

    # 2. même origine
    if re.search(URL_RE, main_js):
        problems.append("main.dart.js : préfixe OSRM encore cross-origin")
    elif ('"%s"' % LOCAL_PATH) not in main_js:
        problems.append("main.dart.js : préfixe local %r absent" % LOCAL_PATH)
    else:
        print("  ok même origine : %s (CORS sans objet)" % LOCAL_PATH)

    # 3. versions
    labels = re.findall(LABEL_RE, main_js)
    if not labels or labels[0][1] != str(TARGET_BUILD):
        problems.append("main.dart.js : libellé attendu « build %d », trouvé %s"
                        % (TARGET_BUILD, labels))
    else:
        print("  ok libellé Réglages : « Dakar Bus v%s build %s »" % labels[0])

    version = json.loads(read(VERSION))
    if version.get("build_number") != str(TARGET_BUILD):
        problems.append("version.json : build_number=%r" % version.get("build_number"))
    else:
        print("  ok version.json : build_number=%s" % version["build_number"])

    for path in (INDEX, BOOTSTRAP):
        m = re.search(SWV_RE, read(path))
        if not m or m.group(2) != SW_VERSION_V3:
            problems.append("%s : serviceWorkerVersion=%s" % (path.name, m and m.group(2)))
        else:
            print("  ok %s : serviceWorkerVersion=%s" % (path.name, SW_VERSION_V3))

    # 4. service worker
    sw = read(SW)
    for marker in ("TRACES_SW = '%s'" % TRACES_SW, "OSRM_CACHE = '%s'" % OSRM_CACHE,
                   "OSRM_LOCAL_PATH = '%s'" % LOCAL_PATH, "osrmBundleKey",
                   "osrmLocalRespond", "'Access-Control-Allow-Origin': '*'"):
        if marker not in sw:
            problems.append("service worker : marqueur manquant %r" % marker)
    if "osrmLocalRespond(event.request)" not in sw:
        problems.append("service worker : fetch handler sans branche locale")
    if not any(p.startswith("service worker") for p in problems):
        print("  ok service worker %s : cache %s + bundle + repli fichiers, en-têtes CORS"
              % (TRACES_SW, OSRM_CACHE))

    # 5. couverture des paires
    network = json.loads(read(NETWORK))
    expected = expected_pairs(network)
    pairs = json.loads(read(PAIRS))
    geoms = json.loads(read(GEOMS)).get("geometries", {})
    missing = [u for u in expected if u not in set(pairs)]
    no_geom = [u for u in expected if u not in geoms]
    if missing:
        problems.append("couverture : %d paires du réseau absentes d'osrm_pairs.json"
                        % len(missing))
    elif no_geom:
        print("  !  couverture : %d paires en attente de géométrie "
              "(workflow PrefetchOSRM au push)" % len(no_geom))
    else:
        print("  ok couverture : %d/%d paires d'arrêts consécutifs, clés identiques "
              "octet pour octet aux URL de l'app, toutes dans le bundle"
              % (len(expected), len(expected)))

    # 6. fichiers statiques
    on_disk = {p.name for p in LOCAL_DIR.iterdir()} if LOCAL_DIR.exists() else set()
    if on_disk != static_expected:
        problems.append("fichiers statiques : %d sur disque, %d attendus"
                        % (len(on_disk), len(static_expected)))
    else:
        print("  ok repli sans service worker : %d fichiers dans osrm/route/v1/driving"
              % len(on_disk))

    # 7. MD5
    block = re.search(r"const RESOURCES = (\{.*?\});", sw, re.S)
    resources = json.loads(block.group(1))
    for key in ("main.dart.js", "index.html", "/", "version.json", "flutter_bootstrap.js"):
        path = ROOT / ("index.html" if key == "/" else key)
        if resources.get(key) != md5(path):
            problems.append("RESOURCES[%s] : MD5 incohérent" % key)
    if not any(p.startswith("RESOURCES") for p in problems):
        print("  ok RESOURCES : MD5 cohérents (main.dart.js, index.html, /, "
              "version.json, flutter_bootstrap.js)")

    if problems:
        for p in problems:
            print("  KO " + p)
        sys.exit("ECHEC : verification incomplete (%d probleme(s))" % len(problems))


def main():
    print("Correctif traces v3 — checkout : %s" % ROOT)
    require_v21()
    patch_main_js()
    patch_version()
    patch_sw_versions()
    patch_sw()
    static_expected = write_static_files()
    patch_resources()
    verify(static_expected)
    print("")
    if CHANGES:
        print("Correctif v3 applique (%d modification(s)) :" % len(CHANGES))
        for c in CHANGES:
            print("  * " + c)
    else:
        print("Correctif v3 deja en place : aucune modification (script idempotent).")
    print("")
    print("Effet cote clients : 1er reload -> le SW %s s'installe et seme les "
          "geometries ; 2e reload -> le nouveau main.dart.js est servi, Reglages "
          "affiche « build %d » et les %d lignes du reseau suivent leur itineraire "
          "reel." % (SW_VERSION_V3, TARGET_BUILD,
                     len(json.loads(read(NETWORK)).get("routes", []))))


if __name__ == "__main__":
    main()
