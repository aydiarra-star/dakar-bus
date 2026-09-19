#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif tracés v6 — alignement strict des 13 gares TER et des 23 stations SunuBRT.

1. TER : 13 gares officielles (Dakar -> Diamniadio), ordre exact SETER.
2. BRT : 23 stations réelles le long du corridor officiel 18.3 km (Guédiawaye -> Petersen).
3. dakar_network.json : 23 stations SunuBRT intégrées, routes B1 et B2 Express recalées.
4. brt_dedicated_shapes.json : 23 stations dans l'ordre strict de sequence 1..23.
5. ter_rail_shapes.json : 13 gares dans l'ordre strict de sequence 1..13.
6. Régénération du bundle osrm_geometries.json et des fichiers statiques osrm/route/v1/driving/*.
7. Service worker v6 : cache osrm-geom-v6 (purge forcenée v1..v5), build 12.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from track_shapes import (
    OSRM_PREFIX,
    OSRM_SUFFIX,
    canonical_bundle_text,
    dart_double,
    geom_version_for,
    haversine_m,
    pair_url,
    payload_compatible_osrm,
)

NETWORK_FILE = ROOT / "assets" / "assets" / "data" / "dakar_network.json"
TER_SHAPES_FILE = ROOT / "assets" / "assets" / "data" / "ter_rail_shapes.json"
BRT_SHAPES_FILE = ROOT / "assets" / "assets" / "data" / "brt_dedicated_shapes.json"
PAIRS_FILE = ROOT / "assets" / "assets" / "data" / "osrm_pairs.json"
BUNDLE_FILE = ROOT / "assets" / "assets" / "data" / "osrm_geometries.json"
STATIC_DIR = ROOT / "osrm" / "route" / "v1" / "driving"
SW_FILE = ROOT / "flutter_service_worker.js"
MAIN_JS = ROOT / "main.dart.js"
INDEX_HTML = ROOT / "index.html"
BOOTSTRAP_JS = ROOT / "flutter_bootstrap.js"
VERSION_JSON = ROOT / "version.json"

# Les 23 stations officielles SunuBRT du corridor (Guédiawaye -> Petersen)
BRT_23_STATIONS = [
    ("stop_brt_23_guediawaye", "Préfecture Guédiawaye - PEM BRT", 14.77156, -17.38694),
    ("stop_brt_22_gadaye", "Gadaye - Cambérène - BRT", 14.77450, -17.39300),
    ("stop_brt_21_golf_nord", "Golf Nord - BRT", 14.77619, -17.39881),
    ("stop_brt_20_fith_mith", "Fith Mith - BRT", 14.77019, -17.40156),
    ("stop_brt_19_dalal_jamm", "Hôpital Dalal Jamm - BRT", 14.77287, -17.40979),
    ("stop_brt_18_golf_sud", "Golf Sud - BRT", 14.76756, -17.41356),
    ("stop_brt_17_ndingala", "Ndingala - Golf Sud - BRT", 14.76462, -17.41969),
    ("stop_brt_16_parcelles_assainies", "Parcelles Assainies - BRT", 14.76269, -17.42431),
    ("stop_brt_15_croisement_22", "Croisement 22 - BRT", 14.75369, -17.43181),
    ("stop_brt_14_police_parcelles", "Police des Parcelles - BRT", 14.75120, -17.43950),
    ("stop_brt_13_grand_medine", "Grand Médine - PEM BRT", 14.74795, -17.44715),
    ("stop_brt_12_thiandoum", "Cardinal Hyacinthe Thiandoum - BRT", 14.74156, -17.45131),
    ("stop_brt_11_scat_urbam", "Scat Urbam - BRT", 14.73681, -17.45531),
    ("stop_brt_10_khar_yallah", "Khar Yallah - BRT", 14.73150, -17.45600),
    ("stop_brt_09_liberte_6", "Liberté 6 - BRT Correspondance", 14.72631, -17.45919),
    ("stop_brt_08_liberte_5", "Liberté 5 - BRT", 14.72044, -17.46444),
    ("stop_brt_07_sacre_coeur", "Sacré-Cœur - BRT", 14.71660, -17.46350),
    ("stop_brt_06_liberte_1", "Liberté 1 - BRT", 14.70993, -17.46250),
    ("stop_brt_05_grand_dakar", "Grand Dakar - BRT", 14.70520, -17.45780),
    ("stop_brt_04_dial_diop", "Dial Diop - BRT", 14.69956, -17.45244),
    ("stop_brt_03_obelisque", "Place de la Nation - Obélisque - BRT", 14.69430, -17.44826),
    ("stop_brt_02_mosquee", "Grande Mosquée - BRT", 14.67822, -17.44219),
    ("stop_brt_01_petersen", "Papa Gueye Fall - PEM Petersen BRT", 14.67548, -17.44157),
]

# Les 13 gares officielles du TER (Dakar -> Diamniadio)
TER_13_STATIONS = [
    ("stop_dakar_ter", "Gare TER Dakar", 14.67599, -17.43352),
    ("stop_colobane", "Colobane - Marché & Gare TER", 14.70035, -17.44165),
    ("stop_hann", "Hann - Maristes / TER", 14.72209, -17.43207),
    ("stop_dalifort_ter", "Dalifort - Gare TER", 14.73425, -17.41900),
    ("stop_baux_maraichers", "Baux Maraîchers - TER", 14.73971, -17.40361),
    ("stop_pikine", "Pikine - Marché Zinc / TER", 14.74986, -17.39169),
    ("stop_thiaroye", "Thiaroye - Gare TER", 14.75877, -17.38030),
    ("stop_yeumbeul", "Yeumbeul - Station TER", 14.76491, -17.35650),
    ("stop_keur_mbaye_fall", "Keur Mbaye Fall - Correspondance TER", 14.74408, -17.31389),
    ("stop_pnr", "PNR - Station TER", 14.72317, -17.28394),
    ("stop_rufisque", "Rufisque - Gare TER", 14.71596, -17.27000),
    ("stop_bargny", "Bargny - TER", 14.69818, -17.22920),
    ("stop_diamniadio", "Diamniadio - Gare TER Terminus", 14.71606, -17.19845),
]

def main():
    print("[1] Chargement et mise à jour de dakar_network.json")
    network = json.loads(NETWORK_FILE.read_text(encoding="utf-8"))
    
    stops_map = {s["id"]: s for s in network["stops"]}
    # Ajouter / mettre à jour les 23 stations SunuBRT
    for sid, name, lat, lon in BRT_23_STATIONS:
        stops_map[sid] = {
            "id": sid,
            "name": name,
            "latitude": lat,
            "longitude": lon,
            "data_trust": "OFFICIAL"
        }
    
    # Mettre à jour les 13 gares TER
    for sid, name, lat, lon in TER_13_STATIONS:
        if sid in stops_map:
            stops_map[sid]["latitude"] = lat
            stops_map[sid]["longitude"] = lon
            stops_map[sid]["data_trust"] = "OFFICIAL"
        else:
            stops_map[sid] = {"id": sid, "name": name, "latitude": lat, "longitude": lon, "data_trust": "OFFICIAL"}

    network["stops"] = sorted(stops_map.values(), key=lambda s: s["id"])

    # Mettre à jour les routes BRT B1 et B2
    for route in network["routes"]:
        if route["id"] == "brt_b1_guediawaye_petersen":
            route["stops"] = [s[0] for s in BRT_23_STATIONS]
            route["long_name"] = "PEM Guédiawaye ↔ PEM Petersen (Corridor SunuBRT 23 stations)"
        elif route["id"] == "brt_b2_express":
            route["stops"] = [
                "stop_brt_23_guediawaye",
                "stop_brt_19_dalal_jamm",
                "stop_brt_16_parcelles_assainies",
                "stop_brt_13_grand_medine",
                "stop_brt_09_liberte_6",
                "stop_brt_03_obelisque",
                "stop_brt_01_petersen"
            ]
            route["long_name"] = "Guédiawaye ↔ Petersen Express (7 stations directes)"
        elif route["id"] == "ter_dakar_diamniadio":
            route["stops"] = [s[0] for s in TER_13_STATIONS]
            route["long_name"] = "Dakar Gare ↔ Diamniadio (13 gares officielles SETER/CETUD)"

    NETWORK_FILE.write_text(json.dumps(network, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  = dakar_network.json à jour : {len(network['stops'])} arrêts, {len(network['routes'])} lignes")

    print("[2] Mise à jour des formes brt_dedicated_shapes.json et ter_rail_shapes.json")
    brt_shapes = {
        "description_fr": "Corridor 100% site propre SunuBRT (23 stations réelles, PEM Guédiawaye ↔ PEM Petersen)",
        "provenance": "sunubrt-officiel",
        "shape_id": "brt-dedicated-v6",
        "source_kind": "secours-consecutif",
        "updated": "2026-09-19",
        "points": [
            {"lat": lat, "lon": lon, "shape_pt_sequence": i + 1, "stop_id": sid}
            for i, (sid, _, lat, lon) in enumerate(BRT_23_STATIONS)
        ]
    }
    BRT_SHAPES_FILE.write_text(json.dumps(brt_shapes, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  = brt_dedicated_shapes.json : {len(brt_shapes['points'])} stations ordonnées (sequence 1..23)")

    ter_shapes = {
        "description_fr": "Voie ferrée express TER Dakar (13 gares officielles, Gare de Dakar ↔ Gare de Diamniadio)",
        "provenance": "seter-cetud-officiel",
        "shape_id": "ter-rail-v6",
        "source_kind": "secours-consecutif",
        "updated": "2026-09-19",
        "points": [
            {"lat": lat, "lon": lon, "shape_pt_sequence": i + 1, "stop_id": sid}
            for i, (sid, _, lat, lon) in enumerate(TER_13_STATIONS)
        ]
    }
    TER_SHAPES_FILE.write_text(json.dumps(ter_shapes, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  = ter_rail_shapes.json : {len(ter_shapes['points'])} gares ordonnées (sequence 1..13)")

    print("[3] Construction du bundle osrm_geometries.json et des paires")
    old_bundle = json.loads(BUNDLE_FILE.read_text(encoding="utf-8"))
    old_geoms = old_bundle.get("geometries", {})
    old_prov = old_bundle.get("provenance", {})

    new_geoms = {}
    new_prov = {}
    new_pairs = []

    stops_lookup = {s["id"]: s for s in network["stops"]}

    # Modes guidés : TER (12 paires consécutives) et BRT B1 (22 paires) et B2 (6 paires)
    def add_track_pair(sid_a, sid_b, source_tag):
        sa = stops_lookup[sid_a]
        sb = stops_lookup[sid_b]
        url = pair_url(sa["longitude"], sa["latitude"], sb["longitude"], sb["latitude"])
        coords = [[sa["longitude"], sa["latitude"]], [sb["longitude"], sb["latitude"]]]
        new_geoms[url] = payload_compatible_osrm(coords, sa["name"], sb["name"], source_tag)
        new_prov[url] = source_tag
        return url

    # Paires TER
    for i in range(len(TER_13_STATIONS) - 1):
        add_track_pair(TER_13_STATIONS[i][0], TER_13_STATIONS[i+1][0], "ter-rail-v6-secours")

    # Paires BRT B1
    for i in range(len(BRT_23_STATIONS) - 1):
        add_track_pair(BRT_23_STATIONS[i][0], BRT_23_STATIONS[i+1][0], "brt-dedicated-v6-secours")

    # Paires BRT B2 Express
    b2_stops = [
        "stop_brt_23_guediawaye",
        "stop_brt_19_dalal_jamm",
        "stop_brt_16_parcelles_assainies",
        "stop_brt_13_grand_medine",
        "stop_brt_09_liberte_6",
        "stop_brt_03_obelisque",
        "stop_brt_01_petersen"
    ]
    for i in range(len(b2_stops) - 1):
        add_track_pair(b2_stops[i], b2_stops[i+1], "brt-dedicated-v6-secours")

    track_count = len(new_geoms)
    print(f"  = Géométries guidées générées : {track_count} paires (12 TER + 22 B1 + 6 B2)")

    # Paires routières : réutilisation des géométries validées
    RESTORED_ROAD_FILE = ROOT / "tools" / "restored_road_geoms.json"
    restored_geoms = json.loads(RESTORED_ROAD_FILE.read_text(encoding="utf-8")) if RESTORED_ROAD_FILE.exists() else {}

    road_count = 0
    for r in network["routes"]:
        if r["operator_id"] in ("ter", "brt"):
            continue
        st = r["stops"]
        for i in range(len(st) - 1):
            sa = stops_lookup[st[i]]
            sb = stops_lookup[st[i+1]]
            url = pair_url(sa["longitude"], sa["latitude"], sb["longitude"], sb["latitude"])
            if url in new_geoms:
                continue
            if url in restored_geoms:
                new_geoms[url] = restored_geoms[url]
                new_prov[url] = "osrm-driving"
                road_count += 1
            elif url in old_geoms:
                payload = dict(old_geoms[url])
                payload.pop("shape_source", None)
                new_geoms[url] = payload
                new_prov[url] = "osrm-driving"
                road_count += 1
            else:
                print(f"  ! Paire routière manquante : {url}")

    print(f"  = Géométries routières réutilisées : {road_count} paires")

    # Liste ordonnée de toutes les paires
    new_pairs = sorted(new_geoms.keys())
    PAIRS_FILE.write_text(json.dumps(new_pairs, indent=2) + "\n", encoding="utf-8")
    print(f"  = osrm_pairs.json écrit : {len(new_pairs)} paires")

    out_text = canonical_bundle_text(new_geoms, new_prov, new_pairs)
    geom_version = geom_version_for(out_text, tag="v6")
    BUNDLE_FILE.write_text(out_text, encoding="utf-8")
    print(f"  = osrm_geometries.json écrit : {len(out_text)} octets, GEOM_VERSION={geom_version}")

    print("[4] Génération des fichiers statiques dans osrm/route/v1/driving/")
    STATIC_DIR.mkdir(parents=True, exist_ok=True)
    expected = set()
    for url, payload in new_geoms.items():
        coords = url[len(OSRM_PREFIX):].split("?", 1)[0]
        expected.add(coords)
        target = STATIC_DIR / coords
        body = json.dumps(payload, ensure_ascii=True, separators=(",", ":"))
        target.write_text(body, encoding="utf-8", newline="")
    
    # Supprimer les anciens fichiers non utilisés
    for stale in STATIC_DIR.iterdir():
        if stale.name not in expected:
            stale.unlink()
    print(f"  = {len(expected)} fichiers statiques écrits dans {STATIC_DIR.relative_to(ROOT)}")

    print("[5] Mise à jour de main.dart.js (démos et build version)")
    main_text = MAIN_JS.read_text(encoding="utf-8")
    
    # Mettre à jour build 11 -> build 12
    main_text = main_text.replace("Dakar Bus v9.3.2 build 11", "Dakar Bus v9.3.2 build 12")
    
    # Mettre à jour la ligne de démo B1 dans $.J0
    brt_demo_pts = [f"new A.aE({lat},{lon})" for _, _, lat, lon in BRT_23_STATIONS]
    b1_demo_str = f'A.akW("B1",B.bl,"BRT",A.b([{",".join(brt_demo_pts)}],q),"BRT")'
    
    old_b1_pattern = r'A\.akW\("B1",B\.bl,"BRT",A\.b\(\[[^\]]*\],q\),"BRT"\)'
    main_text = re.sub(old_b1_pattern, b1_demo_str, main_text, count=1)

    MAIN_JS.write_text(main_text, encoding="utf-8")
    print("  = main.dart.js mis à jour : build 12 et démo B1 à 23 stations réelles")

    # Mettre à jour version.json et index/bootstrap d'abord pour avoir les bons MD5
    VERSION_JSON.write_text(json.dumps({"app_name": "dakarbus", "version": "9.3.2", "build_number": "12", "package_name": "dakarbus"}, indent=2) + "\n")
    
    sw_version = "477962408"
    idx_text = INDEX_HTML.read_text(encoding="utf-8")
    idx_text = re.sub(r'serviceWorkerVersion:\s*"[0-9]+"', f'serviceWorkerVersion: "{sw_version}"', idx_text)
    INDEX_HTML.write_text(idx_text, encoding="utf-8")
    
    boot_text = BOOTSTRAP_JS.read_text(encoding="utf-8")
    boot_text = re.sub(r'serviceWorkerVersion:\s*"[0-9]+"', f'serviceWorkerVersion: "{sw_version}"', boot_text)
    BOOTSTRAP_JS.write_text(boot_text, encoding="utf-8")
    print(f"  = Versions alignées : build 12, serviceWorkerVersion={sw_version}")

    print("[6] Mise à jour du Service Worker et versions")
    sw_text = SW_FILE.read_text(encoding="utf-8")
    sw_text = re.sub(r"const OSRM_CACHE = 'osrm-geom-v[0-9]+';", "const OSRM_CACHE = 'osrm-geom-v6';", sw_text)
    sw_text = re.sub(r"const TRACES_SW = 'v[0-9]+';", "const TRACES_SW = 'v6';", sw_text)
    sw_text = re.sub(r"// ===== Traces reels v[0-9]+", "// ===== Traces reels v6", sw_text)
    
    # Prune old caches up to v5
    old_prunes = """    await caches.delete('osrm-geom-v1'); // caches obsoletes
    await caches.delete('osrm-geom-v2');
    await caches.delete('osrm-geom-v3');
    await caches.delete('osrm-geom-v4');
    await caches.delete('osrm-geom-v5');"""
    sw_text = re.sub(r"\s*await caches\.delete\('osrm-geom-v1'\);[\s\S]*?await caches\.delete\('osrm-geom-v[0-9]'\);", "\n" + old_prunes, sw_text)
    
    sw_text = re.sub(r"(const GEOM_VERSION = ')[^']*(')", r"\g<1>" + geom_version + r"\g<2>", sw_text, count=1)
    
    # Recalculer les sommes MD5 de RESOURCES
    res_match = re.search(r'const RESOURCES = (\{[\s\S]*?\});', sw_text)
    if res_match:
        res_dict = json.loads(res_match.group(1))
        for rel_path in list(res_dict.keys()):
            fpath = ROOT / (rel_path if rel_path != "/" else "index.html")
            if fpath.exists():
                h = hashlib.md5(fpath.read_bytes()).hexdigest()
                res_dict[rel_path] = h
        res_formatted = json.dumps(res_dict, indent=2, sort_keys=True)
        sw_text = sw_text[:res_match.start()] + "const RESOURCES = " + res_formatted + ";" + sw_text[res_match.end():]
        print("  = Sommes MD5 de RESOURCES recalculées")

    SW_FILE.write_text(sw_text, encoding="utf-8")
    print(f"  = flutter_service_worker.js mis à jour : osrm-geom-v6, GEOM_VERSION={geom_version}")

    print("\n✅ Correctif v6 appliqué avec succès !")

if __name__ == "__main__":
    main()
