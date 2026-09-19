#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Formes en site propre (correctif tracés v4) — module partagé.

Rôle : fournir les géométries des modes guidés/dédiés SANS passer par le
routage routier OSRM (profil driving), inapplicable à un train et aux voies
de bus en site propre :
  * TER  -> assets/assets/data/ter_rail_shapes.json
  * BRT  -> assets/assets/data/brt_dedicated_shapes.json

Les arrêts BRT sont triés par stop_sequence avant tout découpage (exigence de
la consigne). Les payloads produits sont compatibles OSRM (même structure que
les réponses driving : code/routes[0].geometry.coordinates) afin que l'app
(main.dart.js, inchangée sur ce point) les consomme sans modification, via les
mêmes URL de paires. Chaque payload porte un marqueur `shape_source` et le
bundle global porte une table `provenance` par URL.

Utilisé par tools/prefetch_osrm.py (workflow CI) et tools/apply_traces_v4.py
(correctif local, sans réseau).
"""
import json
import hashlib
import math
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NETWORK = ROOT / "assets" / "assets" / "data" / "dakar_network.json"
TER_SHAPES = ROOT / "assets" / "assets" / "data" / "ter_rail_shapes.json"
BRT_SHAPES = ROOT / "assets" / "assets" / "data" / "brt_dedicated_shapes.json"

OSRM_PREFIX = "https://router.project-osrm.org/route/v1/driving/"
OSRM_SUFFIX = "?overview=full&geometries=geojson"

# Vitesses commerciales constatées (vues détail de l'app) : TER 35 km en
# 45 min (~13 m/s), BRT 18,3 km en 43 min (~7 m/s). Servent uniquement à
# renseigner duration/weight des payloads synthétiques.
TER_SPEED_MPS = 13.0
BRT_SPEED_MPS = 7.0

TRACK_OPERATORS = ("ter", "brt")


def dart_double(value):
    """Formatage d'un double dans les URL construites par l'app (Dart2js)."""
    return repr(float(value))


def pair_url(lon_a, lat_a, lon_b, lat_b):
    return (OSRM_PREFIX
            + dart_double(lon_a) + "," + dart_double(lat_a) + ";"
            + dart_double(lon_b) + "," + dart_double(lat_b)
            + OSRM_SUFFIX)


def haversine_m(lon1, lat1, lon2, lat2):
    r = math.radians
    dlat, dlon = r(lat2 - lat1), r(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(r(lat1)) * math.cos(r(lat2)) * math.sin(dlon / 2) ** 2)
    return 12742017.6 * math.asin(math.sqrt(a))


def ascii_name(text):
    """Nom de gare/station translittéré en ASCII (fichiers statiques ASCII)."""
    return unicodedata.normalize("NFKD", str(text)).encode("ascii", "ignore").decode("ascii")


class TrackShape:
    """Forme chargée depuis un fichier shapes (triée par sequence)."""

    def __init__(self, path, speed_mps):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        pts = sorted(data["points"], key=lambda p: p["shape_pt_sequence"])
        seqs = [p["shape_pt_sequence"] for p in pts]
        if seqs != sorted(seqs) or len(set(seqs)) != len(seqs):
            raise ValueError("%s : sequences invalides" % path)
        self.shape_id = data["shape_id"]
        self.points = pts
        self.speed_mps = speed_mps
        self.stop_index = {}
        for i, p in enumerate(pts):
            if p.get("stop_id"):
                if p["stop_id"] in self.stop_index:
                    raise ValueError("%s : stop_id dupliqué %s" % (path, p["stop_id"]))
                self.stop_index[p["stop_id"]] = i

    def ordered_stop_ids(self):
        """Identifiants d'arrêts dans l'ordre de la forme (sequence)."""
        return [p["stop_id"] for p in self.points if p.get("stop_id")]

    def slice(self, stop_a, stop_b):
        """Tronçon [stop_a, stop_b] (listes [lon, lat], extrémités exactes)."""
        if stop_a not in self.stop_index or stop_b not in self.stop_index:
            raise KeyError("paire %s->%s absente de %s" % (stop_a, stop_b, self.shape_id))
        i, j = self.stop_index[stop_a], self.stop_index[stop_b]
        if i >= j:
            raise ValueError("paire %s->%s inversée dans %s" % (stop_a, stop_b, self.shape_id))
        return [[self.points[k]["lon"], self.points[k]["lat"]] for k in range(i, j + 1)]

    def full_length_m(self):
        pts = self.points
        return sum(haversine_m(pts[k]["lon"], pts[k]["lat"],
                               pts[k + 1]["lon"], pts[k + 1]["lat"])
                   for k in range(len(pts) - 1))


def load_shapes():
    return {
        "ter": TrackShape(TER_SHAPES, TER_SPEED_MPS),
        "brt": TrackShape(BRT_SHAPES, BRT_SPEED_MPS),
    }


def shape_payload(coords, name_a, name_b, source):
    """Payload compatible OSRM pour un tronçon en site propre."""
    dist = sum(haversine_m(coords[k][0], coords[k][1],
                            coords[k + 1][0], coords[k + 1][1])
               for k in range(len(coords) - 1))
    speed = TER_SPEED_MPS if source.startswith("ter-") else BRT_SPEED_MPS
    dur = dist / speed
    return {
        "code": "Ok",
        "shape_source": source,
        "routes": [{
            "geometry": {"coordinates": coords, "type": "LineString"},
            "legs": [{"steps": [], "summary": "", "weight": dur,
                      "duration": dur, "distance": dist}],
            "weight_name": "routability",
            "weight": dur,
            "duration": dur,
            "distance": dist,
        }],
        "waypoints": [
            {"hint": "", "distance": 0, "name": ascii_name(name_a),
             "location": coords[0]},
            {"hint": "", "distance": 0, "name": ascii_name(name_b),
             "location": coords[-1]},
        ],
    }


def classify_network_pairs(network=None):
    """Paires de chaque ligne, classées par mode.

    Retourne (track_pairs, road_pairs) : ensembles d'URL. Une paire servie à
    la fois par une ligne guidée (TER/BRT) et une ligne routière est classée
    TRACK (priorité au site propre : les 3 cas concernés partagent le même
    corridor, l'écart est négligeable pour le bus et le guidé y gagne un
    tracé exact).
    """
    if network is None:
        network = json.loads(NETWORK.read_text(encoding="utf-8"))
    stops = {s["id"]: s for s in network.get("stops", [])}
    track, road = set(), set()
    for route in network.get("routes", []):
        ids = route.get("stops", [])
        bucket = track if route.get("operator_id") in TRACK_OPERATORS else road
        for i in range(len(ids) - 1):
            a, b = stops.get(ids[i]), stops.get(ids[i + 1])
            if not a or not b:
                continue
            bucket.add(pair_url(a["longitude"], a["latitude"],
                                b["longitude"], b["latitude"]))
    shared = track & road
    road -= shared  # priorité track (documentée)
    return track, road, shared


def build_track_geometries(network=None, shapes=None):
    """Géométries locales pour toutes les paires TER/BRT du réseau.

    Retourne (geometries, provenance) : dict URL -> payload, dict URL -> source.
    Lève une erreur si une paire guidée n'est couverte par aucune forme.
    """
    if network is None:
        network = json.loads(NETWORK.read_text(encoding="utf-8"))
    if shapes is None:
        shapes = load_shapes()
    stops = {s["id"]: s for s in network.get("stops", [])}
    geometries, provenance = {}, {}
    for route in network.get("routes", []):
        op = route.get("operator_id")
        if op not in TRACK_OPERATORS:
            continue
        shape = shapes[op]
        ids = route.get("stops", [])
        # Exigence consigne : arrêts triés par sequence avant découpage.
        # Ici la forme fait foi : on vérifie que la ligne suit l'ordre de
        # la forme (erreur explicite sinon, jamais de découpage inversé).
        order = {sid: k for k, sid in enumerate(shape.ordered_stop_ids())}
        for i in range(len(ids) - 1):
            a, b = ids[i], ids[i + 1]
            if a not in order or b not in order:
                raise KeyError("arrêt %s ou %s hors forme %s (ligne %s)"
                               % (a, b, shape.shape_id, route.get("id")))
            if order[a] >= order[b]:
                raise ValueError("ligne %s : arrêts non triés par sequence "
                                 "(%s après %s)" % (route.get("id"), a, b))
            sa, sb = stops[a], stops[b]
            url = pair_url(sa["longitude"], sa["latitude"],
                            sb["longitude"], sb["latitude"])
            if url in geometries:
                continue
            coords = shape.slice(a, b)
            # Les extrémités de la forme doivent être les coordonnées exactes
            # des arrêts (pas d'approximation).
            assert coords[0] == [sa["longitude"], sa["latitude"]], url
            assert coords[-1] == [sb["longitude"], sb["latitude"]], url
            geometries[url] = shape_payload(coords, sa["name"], sb["name"],
                                            shape.shape_id)
            provenance[url] = shape.shape_id
    return geometries, provenance


def canonical_bundle_text(geometries, provenance, pairs_order):
    """Sérialisation canonique du bundle (schéma 2), stable entre scripts.

    L'ordre des clés suit osrm_pairs.json (lui-même dans l'ordre du réseau),
    afin que tools/prefetch_osrm.py (CI) et tools/apply_traces_v4.py (local)
    produisent des octets identiques pour des payloads identiques (pas de
    churn de GEOM_VERSION).
    """
    ordered_geoms = {u: geometries[u] for u in pairs_order if u in geometries}
    ordered_prov = {u: provenance.get(u, "osrm-driving")
                    for u in pairs_order if u in geometries}
    bundle = {"schema": 2, "count": len(ordered_geoms),
              "provenance": ordered_prov, "geometries": ordered_geoms}
    return json.dumps(bundle, ensure_ascii=False, separators=(",", ":")) + "\n"


def geom_version_for(bundle_text, tag="v4"):
    return "%s-%s" % (tag, hashlib.sha256(bundle_text.encode("utf-8")).hexdigest()[:12])
