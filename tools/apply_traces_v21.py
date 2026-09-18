#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v2.1 — applique les modifications v2.1 sur un checkout gh-pages.

Rôle (équivalent du runbook TRACES-V21-HANDOFF) : si des fichiers v2.1 semblent
manquants ou réinitialisés, rejouer `python3 tools/apply_traces_v21.py`.
Le script est idempotent : le rejouer ne change rien si le correctif est déjà là.

Prérequis : le correctif v2 doit être présent (cache `osrm-geom-v2`, bundle
`assets/assets/data/osrm_geometries.json`, workflow « PrefetchOSRM geometries »).
Sinon rejouer d'abord `python3 tools/apply_traces_v2.py`.

Ce que fait ce script :

  1. main.dart.js : le libellé affiché dans Réglages → « Version de
     l'application » est codé en dur dans le bundle compilé
     (« Dakar Bus v9.3.2 build 6 » alors que version.json annonçait déjà le
     build 7). Il est aligné sur « build 8 ». Remplacement à longueur
     identique : aucun décalage dans le bundle, UI et logique inchangées.
     (Le dépôt ne contient aucune source Flutter — gh-pages ne porte que la
     sortie compilée — donc le libellé visible ne peut pas être obtenu par un
     rebuild.)

  2. version.json : build_number -> 8 (cohérence avec le libellé affiché).

  3. index.html : bump de `serviceWorkerVersion` (477962403 -> 477962404) pour
     propager immédiatement le nouveau service worker chez les clients.

  4. flutter_bootstrap.js : `serviceWorkerVersion` était resté à 477962402 (v1).
     Ce fichier n'est pas chargé par index.html aujourd'hui (qui utilise
     flutter.js + loadEntrypoint), mais il est dans RESOURCES/CORE : on
     l'aligne pour qu'un futur basculement ne réinstalle pas un SW périmé.

  5. flutter_service_worker.js — fiabilisation des tracés réels :
     a. le bundle préchargé est aussi gardé en mémoire (`osrmLoadBundle`) ;
     b. `osrmRespond` sert toute paire absente du cache depuis le bundle au
        lieu de partir vers le routeur public OSRM (429/timeout -> l'app
        retombait sur une ligne droite entre deux arrêts). Résultat : chaque
        mobilité suit son itinéraire réel, y compris si le semis a été
        interrompu (SW tué, réseau coupé, fenêtre de déploiement, offline
        partiel) ;
     c. le semis vérifie sa couverture après coup et se reprogramme
        (3 tentatives, 30 s d'écart) s'il manque des géométries ;
     d. l'activateur n'est plus bloqué par une exception de semis ;
     e. marqueur auditable `TRACES_SW = 'v2.1'`.

  6. Couverture des paires : les URL OSRM que construit l'app sont recalculées
     depuis `assets/assets/data/dakar_network.json` (formatage des doubles
     identique à Dart2js, donc identiques octet pour octet aux clés du cache) et
     comparées à `osrm_pairs.json`. Toute paire manquante est ajoutée (additif
     seulement) : le workflow « PrefetchOSRM geometries » récupère sa géométrie
     au push suivant. Sans cette étape, un arrêt déplacé ou ajouté dans les
     données réseau ferait silencieusement retomber une mobilité en ligne droite.

  7. Sommes MD5 de RESOURCES recalculées pour tous les fichiers modifiés
     (main.dart.js, index.html, "/", version.json, flutter_bootstrap.js) — et
     pour toute autre entrée qui aurait dérivé. Sans cela le service worker
     compare son manifeste à l'ancien, juge la ressource inchangée et continue
     de servir l'ancienne copie en cache : le libellé « build 8 » n'apparaîtrait
     jamais chez les clients déjà venus.

  8. Vérification finale (libellé, build_number, versions SW, présence du repli
     bundle, couverture octet pour octet des paires, MD5 cohérents) et compte
     rendu sur stdout.

Ne touche à rien d'autre : données réseau, géométries OSRM, workflow
« PrefetchOSRM geometries » et UI restent intacts. Le bundle
`osrm_geometries.json` n'est volontairement PAS ajouté à RESOURCES : son URL de
semis porte `?v=GEOM_VERSION` que le fetch handler retire, donc une entrée en
cache figerait un bundle périmé après régénération par le workflow.
"""
import hashlib
import json
import re
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

TARGET_BUILD = 8
SW_VERSION_V21 = "477962404"      # était 477962403 (v2), 477962402 (v1)
TRACES_SW = "v2.1"

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


# ---------------------------------------------------------------------------
# Garde-fou : le correctif v2 doit être en place
# ---------------------------------------------------------------------------

def require_v2():
    print("[0] Controle du prerequis v2")
    if not SW.exists():
        sys.exit("ECHEC : flutter_service_worker.js absent (mauvais checkout ?)")
    sw = read(SW)
    missing = [m for m in ("osrm-geom-v2", "osrmSeedFromBundle", "GEOM_VERSION")
               if m not in sw]
    if missing:
        sys.exit("ECHEC : correctif v2 absent (%s). Rejouez d'abord "
                 "tools/apply_traces_v2.py" % ", ".join(missing))
    for f in (PAIRS, GEOMS):
        if not f.exists():
            sys.exit("ECHEC : %s absent (correctif v2 incomplet)" % f.name)
    print("  = v2 en place (cache osrm-geom-v2, semis bundle, GEOM_VERSION)")


# ---------------------------------------------------------------------------
# 1. main.dart.js : libellé Réglages « build 8 »
# ---------------------------------------------------------------------------

LABEL_RE = r"Dakar Bus v(\d+(?:\.\d+)*) build (\d+)"


def patch_main_js():
    print("[1] main.dart.js : libelle Reglages")
    text = read(MAIN_JS)
    found = re.findall(LABEL_RE, text)
    if not found:
        sys.exit("ECHEC : libelle « Dakar Bus vX.Y.Z build N » introuvable dans "
                 "main.dart.js (bundle recompilé ? adapter LABEL_RE)")
    current = found[0]
    if current[1] == str(TARGET_BUILD):
        print("  = libellé déjà à « build %d »" % TARGET_BUILD)
        return
    new = re.sub(LABEL_RE,
                 lambda m: "Dakar Bus v%s build %d" % (m.group(1), TARGET_BUILD),
                 text)
    if len(new) != len(text):
        sys.exit("ECHEC : le remplacement a changé la taille du bundle "
                 "(%d -> %d)" % (len(text), len(new)))
    write(MAIN_JS, new)
    note("libellé Réglages « v%s build %s » -> « v%s build %d »"
         % (current[0], current[1], current[0], TARGET_BUILD))


# ---------------------------------------------------------------------------
# 2. version.json : build_number 8
# ---------------------------------------------------------------------------

def patch_version():
    print("[2] version.json : build_number")
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
# 3-4. Propagation du service worker : index.html + flutter_bootstrap.js
# ---------------------------------------------------------------------------

SWV_RE = r'(serviceWorkerVersion\s*:\s*")(\d+)(")'


def patch_sw_versions():
    print("[3] index.html / flutter_bootstrap.js : serviceWorkerVersion")
    for path in (INDEX, BOOTSTRAP):
        text = read(path)
        m = re.search(SWV_RE, text)
        if not m:
            sys.exit("ECHEC : serviceWorkerVersion introuvable dans %s" % path.name)
        if m.group(2) == SW_VERSION_V21:
            print("  = %s déjà en %s" % (path.name, SW_VERSION_V21))
            continue
        new = text[:m.start()] + m.group(1) + SW_VERSION_V21 + m.group(3) + text[m.end():]
        write(path, new)
        note("%s serviceWorkerVersion %s -> %s" % (path.name, m.group(2), SW_VERSION_V21))


# ---------------------------------------------------------------------------
# 5. flutter_service_worker.js : repli bundle à la demande + semis vérifié
# ---------------------------------------------------------------------------

V2_HEADER = "// ===== Traces routiers reels v2 (geometries prechargees au deploiement) ====="
V21_HEADER = (
    "// ===== Traces routiers reels v2.1 (geometries prechargees + repli bundle "
    "a la demande) ====="
)

MEMO_BLOCK = """
// v2.1 : marqueur de revision du correctif traces (audit, logs).
const TRACES_SW = '{traces}';
// v2.1 : le bundle precharge est garde en memoire apres son premier chargement.
// Toute paire absente du cache est servie depuis ce bundle (une requete pour
// 281 paires) au lieu de partir vers le routeur public OSRM, dont le rate-limit
// faisait retomber l'app sur une ligne droite entre deux arrets.
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

function osrmJsonResponse(payload) {{
  return new Response(JSON.stringify(payload),
      {{ headers: {{ 'Content-Type': 'application/json' }} }});
}}

""".format(traces=TRACES_SW)

SEED_V21 = """async function osrmSeedFromBundle() {
  let geoms;
  try {
    geoms = await osrmLoadBundle();
  } catch (e) {
    console.warn('OSRM ' + TRACES_SW + ' : bundle precharge indisponible (' + e
        + '), repli file runtime + nouvelle tentative programmee');
    osrmScheduleSeedRetry();
    return;
  }
  const cache = await caches.open(OSRM_CACHE);
  const before = new Set((await cache.keys()).map((r) => r.url));
  const urls = Object.keys(geoms);
  let n = 0;
  for (const url of urls) {
    if (before.has(url)) continue;
    await cache.put(new Request(url), osrmJsonResponse(geoms[url]));
    n++;
  }
  console.debug('OSRM ' + TRACES_SW + ' : ' + n + ' geometries installees depuis le bundle ('
      + urls.length + ' au total)');
  // v2.1 : controle de couverture, puis nouvelle tentative si le semis est incomplet.
  const after = new Set((await cache.keys()).map((r) => r.url));
  const missing = urls.filter((u) => !after.has(u));
  if (missing.length === 0) {
    console.debug('OSRM ' + TRACES_SW + ' : couverture complete ' + after.size + '/' + urls.length);
    return;
  }
  console.warn('OSRM ' + TRACES_SW + ' : ' + missing.length + ' geometries manquantes apres semis');
  osrmScheduleSeedRetry();
}

function osrmScheduleSeedRetry() {
  if (osrmSeedAttempts >= OSRM_SEED_MAX_ATTEMPTS) {
    console.warn('OSRM ' + TRACES_SW + ' : semis abandonne, le repli bundle a la demande prend le relais');
    return;
  }
  osrmSeedAttempts++;
  setTimeout(() => {
    osrmSeedFromBundle().catch((e) => console.warn('OSRM ' + TRACES_SW + ' : retry KO', e));
  }, OSRM_SEED_RETRY_MS);
}"""

RESPOND_V21 = """async function osrmRespond(request) {
  const cache = await caches.open(OSRM_CACHE);
  const hit = await cache.match(request);
  if (hit) return hit;
  // v2.1 : la paire est peut-etre dans le bundle precharge sans etre encore en
  // cache (semis interrompu, SW tue, offline partiel). On la sert depuis le
  // bundle : chaque mobilite suit son itineraire reel au lieu d'une ligne droite.
  try {
    const geoms = await osrmLoadBundle();
    const payload = geoms && geoms[request.url];
    if (payload) {
      const response = osrmJsonResponse(payload);
      await cache.put(request, response.clone());
      console.debug('OSRM ' + TRACES_SW + ' : paire servie depuis le bundle precharge');
      return response;
    }
  } catch (e) {
    console.warn('OSRM ' + TRACES_SW + ' : repli bundle indisponible (' + e + '), file runtime');
  }
  try {
    return await osrmSchedule(request.url);
  } catch (e) {
    // Dernier recours : reseau direct non limite
    return fetch(request, { cache: 'no-store' });
  }
}"""

ACTIVATE_V21 = """self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      await osrmSeedFromBundle();
      await osrmPrefetch();
    } catch (e) {
      // v2.1 : un semis incomplet ne doit jamais bloquer l'activation.
      console.warn('OSRM ' + TRACES_SW + ' : semis incomplet (' + e
          + '), repli bundle a la demande actif');
    }
    await caches.delete('osrm-geom-v1'); // cache v1 obsolete
  })());
});"""

ACTIVATE_V2 = ("self.addEventListener('activate', (event) => {\n"
               "  event.waitUntil((async () => {\n"
               "    await osrmSeedFromBundle();\n"
               "    await osrmPrefetch();\n"
               "    await caches.delete('osrm-geom-v1'); // cache v1 obsolete\n"
               "  })());\n"
               "});")


def patch_sw():
    print("[4] flutter_service_worker.js : repli bundle + semis verifie")
    text = read(SW)
    if "TRACES_SW" in text and "osrmLoadBundle" in text:
        print("  = correctif SW v2.1 déjà appliqué")
        return

    # 4a. en-tête
    if V2_HEADER not in text:
        sys.exit("ECHEC : en-tête v2 du bloc OSRM introuvable dans le service worker")
    text = text.replace(V2_HEADER, V21_HEADER, 1)
    note("en-tête du bloc OSRM -> v2.1")

    # 4b. mémo bundle + marqueur, juste après GEOM_VERSION
    anchor = re.search(r"const GEOM_VERSION = '[^']*';\n", text)
    if not anchor:
        sys.exit("ECHEC : constante GEOM_VERSION introuvable")
    text = text[:anchor.end()] + MEMO_BLOCK + text[anchor.end():]
    note("mémo bundle (osrmLoadBundle/osrmJsonResponse) + marqueur TRACES_SW")

    # 4c. semis vérifié + reprogrammation
    seed_re = re.compile(r"async function osrmSeedFromBundle\(\) \{.*?\n\}\n", re.S)
    if not seed_re.search(text):
        sys.exit("ECHEC : fonction osrmSeedFromBundle v2 introuvable")
    text = seed_re.sub(SEED_V21 + "\n", text, count=1)
    note("semis du bundle vérifié (couverture) + retries programmés")

    # 4d. réponse aux requêtes OSRM : repli bundle avant le routeur public
    respond_re = re.compile(r"async function osrmRespond\(request\) \{.*?\n\}\n", re.S)
    if not respond_re.search(text):
        sys.exit("ECHEC : fonction osrmRespond introuvable")
    text = respond_re.sub(RESPOND_V21 + "\n", text, count=1)
    note("osrmRespond : paire absente du cache servie depuis le bundle")

    # 4e. activateur non bloquant
    if ACTIVATE_V2 not in text:
        sys.exit("ECHEC : activateur OSRM v2 introuvable (format inattendu)")
    text = text.replace(ACTIVATE_V2, ACTIVATE_V21, 1)
    note("activateur OSRM : exception de semis non bloquante")

    write(SW, text)


# ---------------------------------------------------------------------------
# 6. Couverture des paires : dakar_network.json -> osrm_pairs.json
# ---------------------------------------------------------------------------

def dart_double(value):
    """Formatage d'un double dans les URL construites par l'app.

    main.dart.js assemble l'URL OSRM par concatenation directe des doubles
    (`A.j(f) + "," + A.j(g) + ";" + ...`), sans mise en forme : Dart2js émet la
    représentation la plus courte qui round-trip, exactement comme `repr(float)`
    en Python. Les clés du cache et du bundle doivent donc être identiques
    octet pour octet à ce formatage, sinon la requête de l'app rate le cache et
    part vers le routeur public (rate-limit -> ligne droite dans la carte).
    """
    return repr(float(value))


def expected_pairs(network):
    """URL OSRM des paires d'arrêts consécutifs de toutes les lignes du réseau."""
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


def coverage_report():
    """(attendues, listées, manquantes, sans géométrie) — utilisé par patch et verify."""
    network = json.loads(read(NETWORK))
    expected = expected_pairs(network)
    pairs = json.loads(read(PAIRS))
    geoms = json.loads(read(GEOMS)).get("geometries", {})
    listed = set(pairs)
    missing = [u for u in expected if u not in listed]
    no_geom = [u for u in expected if u not in geoms]
    return expected, pairs, missing, no_geom


def patch_pairs_coverage():
    print("[5] Couverture des paires : dakar_network.json -> osrm_pairs.json")
    expected, pairs, missing, no_geom = coverage_report()
    print("  = %d paires consécutives attendues (%d lignes), %d listées"
          % (len(expected), len(json.loads(read(NETWORK)).get("routes", [])), len(pairs)))
    if not missing:
        print("  = clés identiques octet pour octet aux URL construites par l'app")
    else:
        pairs.extend(missing)  # additif seulement : l'ordre existant est préservé
        write(PAIRS, json.dumps(pairs, ensure_ascii=False, separators=(",", ":")))
        note("osrm_pairs.json : +%d paires manquantes (%d au total)" % (len(missing), len(pairs)))
    if no_geom:
        print("  ! %d paires sans géométrie dans le bundle : le workflow "
              "« PrefetchOSRM geometries » les récupère au push ; d'ici là la file "
              "runtime régulée les sert" % len(no_geom))
    else:
        print("  = bundle : %d/%d géométries disponibles" % (len(expected), len(expected)))


# ---------------------------------------------------------------------------
# 7. RESOURCES : sommes MD5 des fichiers modifiés
# ---------------------------------------------------------------------------

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
# 8. Vérification finale
# ---------------------------------------------------------------------------

def verify():
    print("[7] Verification")
    problems = []

    main_js = read(MAIN_JS)
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
        print("  ok version.json : build_number=%s (version %s)"
              % (version["build_number"], version.get("version")))

    for path in (INDEX, BOOTSTRAP):
        m = re.search(SWV_RE, read(path))
        if not m or m.group(2) != SW_VERSION_V21:
            problems.append("%s : serviceWorkerVersion=%s" % (path.name, m and m.group(2)))
        else:
            print("  ok %s : serviceWorkerVersion=%s" % (path.name, SW_VERSION_V21))

    sw = read(SW)
    for marker in ("TRACES_SW = '%s'" % TRACES_SW, "osrmLoadBundle", "osrmJsonResponse",
                   "osrmScheduleSeedRetry", V21_HEADER):
        if marker not in sw:
            problems.append("service worker : marqueur manquant %r" % marker)
    if "geoms[request.url]" not in sw:
        problems.append("service worker : repli bundle absent d'osrmRespond")
    if not problems:
        print("  ok service worker : repli bundle + semis vérifié (%s)" % TRACES_SW)

    expected, pairs, missing, no_geom = coverage_report()
    if missing:
        problems.append("couverture : %d paires du réseau absentes d'osrm_pairs.json"
                        % len(missing))
    elif no_geom:
        # Non bloquant : le workflow « PrefetchOSRM geometries » les récupère au push.
        print("  !  couverture : %d/%d paires listées, %d en attente de géométrie "
              "(workflow PrefetchOSRM au push)" % (len(expected), len(expected), len(no_geom)))
    else:
        print("  ok couverture : %d/%d paires d'arrêts consécutifs, clés identiques "
              "octet pour octet aux URL de l'app, toutes dans le bundle"
              % (len(expected), len(expected)))
    if set(pairs) - set(expected) and not missing:
        print("  =  %d clés héritées du bundle hors réseau courant (inoffensives)"
              % len(set(pairs) - set(expected)))

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
    print("Correctif traces v2.1 — checkout : %s" % ROOT)
    require_v2()
    patch_main_js()
    patch_version()
    patch_sw_versions()
    patch_sw()
    patch_pairs_coverage()
    patch_resources()
    verify()
    print("")
    if CHANGES:
        print("Correctif v2.1 applique (%d modification(s)) :" % len(CHANGES))
        for c in CHANGES:
            print("  * " + c)
    else:
        print("Correctif v2.1 deja en place : aucune modification (script idempotent).")
    print("")
    print("Effet cote clients : 1er reload -> le SW %s s'installe/s'active et seme les "
          "geometries ; 2e reload -> le nouveau main.dart.js est servi, Reglages affiche "
          "« build %d » et toutes les mobilites suivent leur itineraire reel."
          % (SW_VERSION_V21, TARGET_BUILD))


if __name__ == "__main__":
    main()
