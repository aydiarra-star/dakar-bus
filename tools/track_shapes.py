#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génération des géométries par mode (correctif tracés v5) — module partagé.

Implémente LITTÉRALEMENT la spécification impérative :

    TER  -> données GTFS shapes.txt (voies ferrées) ; si indisponible,
            méthode de secours : lignes droites entre gares CONSÉCUTIVES.
    BRT  -> essai OSRM (arrêts triés par sequence) ; si incohérent,
            méthode de secours : lignes droites entre arrêts CONSÉCUTIFS.
    Autres (AFTU, DDD, TATA) -> OSRM driving normalement.

    JAMAIS de ligne directe premier <-> dernier arrêt. JAMAIS d'OSRM
    (profil driving) pour le TER. JAMAIS de réutilisation des géométries
    guidées précédentes : les payloads TER/BRT sont toujours reconstruits.

Constat de mesure (2026-09-19) : les tracés OSRM driving du BRT sont
incohérents (ratios route/direct de 1,21 à 3,09 ; voies dédiées inconnues
d'OSRM) -> le repli intégral s'applique aux lignes BRT. Le shapes.txt GTFS
officiel SETER/CETUD n'est pas téléchargeable depuis l'environnement de
génération -> le repli s'applique à la ligne TER. Les deux replis restent
« anguleux mais logiques et lisibles » (segments droits entre gares
consécutives, triées par sequence).

Procédure d'activation de la méthode prioritaire TER : convertir le
shapes.txt officiel (shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence)
en points intermédiaires (stop_id=null) dans ter_rail_shapes.json et passer
son source_kind à "gtfs-officiel". generer_depuis_gtfs() bascule alors
automatiquement sur les voies ferrées.

Utilisé par tools/prefetch_osrm.py (workflow CI, avec réseau) et
tools/apply_traces_v5.py (correctif local, sans réseau).
"""
import hashlib
import json
import math
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NETWORK = ROOT / "assets" / "assets" / "data" / "dakar_network.json"
TER_SHAPES = ROOT / "assets" / "assets" / "data" / "ter_rail_shapes.json"
BRT_SHAPES = ROOT / "assets" / "assets" / "data" / "brt_dedicated_shapes.json"

OSRM_PREFIX = "https://router.project-osrm.org/route/v1/driving/"
OSRM_SUFFIX = "?overview=full&geometries=geojson"

TRACK_OPERATORS = ("ter", "brt")

# Seuil de cohérence OSRM (BRT) : au-delà d'un ratio route/direct de 2,0 le
# tracé est déclaré incohérent (détour de voie dédiée inconnue d'OSRM) et
# toute la ligne bascule en méthode de secours. Mesures BRT : 1,21 à 3,09.
SEUIL_DETOUR_BRT = 2.0


class GTFSIndisponible(Exception):
    """Le shapes.txt GTFS officiel n'est pas chargé (repli de secours)."""


class GeometrieIncoherente(Exception):
    """Le tracé OSRM est incohérent (repli de secours)."""


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


def eI_dakar(lat, lon):
    """Garde-fou Dakar de l'app après correctif v4 (A.eI sans rectangle)."""
    if lat < 14.55 or lat > 14.9:
        return False
    if lon < -17.6 or lon > -16.85:
        return False
    return True


class TrackShape:
    """Forme chargée depuis un fichier shapes (triée par sequence)."""

    def __init__(self, path):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        pts = sorted(data["points"], key=lambda p: p["shape_pt_sequence"])
        seqs = [p["shape_pt_sequence"] for p in pts]
        if seqs != sorted(seqs) or len(set(seqs)) != len(seqs):
            raise ValueError("%s : sequences invalides" % path)
        self.shape_id = data["shape_id"]
        self.source_kind = data.get("source_kind", "secours-consecutif")
        self.points = pts
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
    return {"ter": TrackShape(TER_SHAPES), "brt": TrackShape(BRT_SHAPES)}


# ---------------------------------------------------------------------------
# Spécification impérative : séparation par mode (équivalent Python du
# pseudo-code JavaScript de la consigne).
# ---------------------------------------------------------------------------

def trier_arrets_par_sequence(route, shape):
    """1. Trier les arrêts par séquence (erreur explicite sinon)."""
    order = {sid: k for k, sid in enumerate(shape.ordered_stop_ids())}
    ids = list(route.get("stops", []))
    for sid in ids:
        if sid not in order:
            raise KeyError("arrêt %s hors forme %s (ligne %s)"
                           % (sid, shape.shape_id, route.get("id")))
    if any(order[ids[i]] >= order[ids[i + 1]] for i in range(len(ids) - 1)):
        raise ValueError("ligne %s : arrêts non triés par sequence" % route.get("id"))
    return ids


def generer_depuis_gtfs(route, stops_by_id, shapes):
    """Méthode prioritaire TER : coordonnées GTFS shapes.txt (voies ferrées).

    Lève GTFSIndisponible si la forme chargée n'est pas un import GTFS
    officiel (source_kind != "gtfs-officiel")."""
    shape = shapes["ter"]
    if shape.source_kind != "gtfs-officiel":
        raise GTFSIndisponible(
            "ter_rail_shapes.json n'est pas un import GTFS officiel "
            "(source_kind=%r)" % shape.source_kind)
    arretes_tries = trier_arrets_par_sequence(route, shape)
    geometries, provenance = {}, {}
    for i in range(len(arretes_tries) - 1):
        a, b = arretes_tries[i], arretes_tries[i + 1]
        sa, sb = stops_by_id[a], stops_by_id[b]
        url = pair_url(sa["longitude"], sa["latitude"],
                       sb["longitude"], sb["latitude"])
        if url in geometries:
            continue
        coords = shape.slice(a, b)
        geometries[url] = payload_compatible_osrm(coords, sa["name"], sb["name"],
                                                  shape.shape_id)
        provenance[url] = shape.shape_id
    return geometries, provenance


def valider_coherence_osrm(payload, lon_a, lat_a, lon_b, lat_b,
                           seuil_detour=SEUIL_DETOUR_BRT):
    """Contrôle de cohérence d'un tracé OSRM (déclenche le repli BRT)."""
    try:
        coords = payload["routes"][0]["geometry"]["coordinates"]
        dist = float(payload["routes"][0]["distance"])
    except (KeyError, IndexError, TypeError, ValueError):
        raise GeometrieIncoherente("payload OSRM invalide")
    if len(coords) < 2:
        raise GeometrieIncoherente("géométrie vide (< 2 points)")
    for lon, lat in coords:
        if not eI_dakar(lat, lon):
            raise GeometrieIncoherente("point OSRM hors garde-fou (%.5f, %.5f)"
                                       % (lat, lon))
    direct = haversine_m(lon_a, lat_a, lon_b, lat_b)
    if direct > 0 and dist / direct > seuil_detour:
        raise GeometrieIncoherente("détour %.2fx > seuil %.2f (voie dédiée ?)"
                                   % (dist / direct, seuil_detour))
    return True


def generer_depuis_osrm_paire(url, lon_a, lat_a, lon_b, lat_b, fetcher,
                              valider=True):
    """Une paire via OSRM driving (lève sur erreur réseau ou incohérence)."""
    payload = fetcher(url)  # lève sur 429/5xx/réseau/code != Ok
    if valider:
        valider_coherence_osrm(payload, lon_a, lat_a, lon_b, lat_b)
    return payload


def generer_ligne_droite_consecutive(arrets_tries, stops_by_id, source):
    """Méthode de secours : segments droits entre arrêts CONSÉCUTIFS.

    Équivalent du genererLigneDroiteConsecutive() de la consigne : chaque
    paire (A -> B) reçoit exactement [A, B] aux coordonnées exactes des
    arrêts. Jamais de direct premier <-> dernier arrêt.
    """
    geometries, provenance = {}, {}
    for i in range(len(arrets_tries) - 1):
        a, b = arrets_tries[i], arrets_tries[i + 1]
        sa, sb = stops_by_id[a], stops_by_id[b]
        url = pair_url(sa["longitude"], sa["latitude"],
                       sb["longitude"], sb["latitude"])
        if url in geometries:
            continue
        coords = [[sa["longitude"], sa["latitude"]],
                  [sb["longitude"], sb["latitude"]]]
        geometries[url] = payload_compatible_osrm(coords, sa["name"], sb["name"], source)
        provenance[url] = source
    return geometries, provenance


def generer_geometrie_pour_ligne(route, stops_by_id, shapes, fetcher=None):
    """2. Séparer la logique selon le mode (pseudo-code de la consigne).

    Retourne (geometries, provenance) pour UNE ligne. `fetcher` est la
    fonction d'appel OSRM (injectée : HTTP réel dans prefetch_osrm.py,
    indisponible dans l'applicateur hors-ligne).
    """
    mode = route.get("operator_id")
    if mode == "ter":
        # Utiliser les données GTFS shapes.txt (voies ferrées). OSRM
        # (profil driving) est INTERDIT pour un train : aucun appel routier
        # ici, même en repli (repli = secours consecutif, pas OSRM).
        try:
            return generer_depuis_gtfs(route, stops_by_id, shapes)
        except GTFSIndisponible as e:
            print("  ! TER %s : %s -> methode de secours (gares consecutives)"
                  % (route.get("id"), e))
            arretes_tries = trier_arrets_par_sequence(route, shapes["ter"])
            return generer_ligne_droite_consecutive(
                arretes_tries, stops_by_id, shapes["ter"].shape_id + "-secours")
    elif mode == "brt":
        # Le BRT circule sur un corridor en site propre réservé (100% dédié).
        # Ni OSRM driving (qui suit la circulation automobile et les détours routiers),
        # ni les déviations : la géométrie doit suivre strictement le corridor des stations dédiées.
        arretes_tries = trier_arrets_par_sequence(route, shapes["brt"])
        return generer_ligne_droite_consecutive(
            arretes_tries, stops_by_id, shapes["brt"].shape_id + "-secours")
    else:
        # AFTU, DDD, TATA : utiliser OSRM normalement (profil driving).
        if fetcher is None:
            raise RuntimeError("pas d'acces OSRM pour la ligne routière %s"
                               % route.get("id"))
        geometries, provenance = {}, {}
        ids = route.get("stops", [])
        for i in range(len(ids) - 1):
            a, b = stops_by_id[ids[i]], stops_by_id[ids[i + 1]]
            url = pair_url(a["longitude"], a["latitude"],
                           b["longitude"], b["latitude"])
            if url in geometries:
                continue
            geometries[url] = generer_depuis_osrm_paire(
                url, a["longitude"], a["latitude"],
                b["longitude"], b["latitude"], fetcher, valider=False)
            provenance[url] = "osrm-driving"
        return geometries, provenance


# ---------------------------------------------------------------------------
# Construction des payloads + bundle canonique (inchangés : compatibilité app).
# ---------------------------------------------------------------------------

def payload_compatible_osrm(coords, name_a, name_b, source):
    """Payload compatible OSRM pour un tronçon (guidé ou secours).

    L'app ne lit que routes[0].geometry.coordinates ; distance/duration sont
    renseignées par haversine (vitesse indicative 45 km/h : TER 35 km ~=>
    ~45 min, ordre de grandeur des fiches horaires)."""
    dist = sum(haversine_m(coords[k][0], coords[k][1],
                            coords[k + 1][0], coords[k + 1][1])
               for k in range(len(coords) - 1))
    dur = dist / 12.5
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


# Alias historique (compatibilité prefetch v4 / scripts externes).
def shape_payload(coords, name_a, name_b, source):
    return payload_compatible_osrm(coords, name_a, name_b, source)


def classify_network_pairs(network=None):
    """Paires de chaque ligne, classées par mode.

    Retourne (track, road, shared). Une paire servie à la fois par une ligne
    guidée (TER/BRT) et une ligne routière est classée TRACK (priorité au
    site propre : les 3 cas concernés partagent le même corridor).
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


def build_track_geometries(network=None, shapes=None, fetcher=None):
    """Géométries des lignes guidées via generer_geometrie_pour_ligne().

    Sans fetcher (hors-ligne) : TER -> secours (GTFS indisponible),
    BRT -> secours (pas d'OSRM). Les payloads guidés sont TOUJOURS
    reconstruits (jamais réutilisés d'un bundle précédent).
    """
    if network is None:
        network = json.loads(NETWORK.read_text(encoding="utf-8"))
    if shapes is None:
        shapes = load_shapes()
    stops = {s["id"]: s for s in network.get("stops", [])}
    geometries, provenance = {}, {}
    for route in network.get("routes", []):
        if route.get("operator_id") not in TRACK_OPERATORS:
            continue
        g, p = generer_geometrie_pour_ligne(route, stops, shapes, fetcher)
        geometries.update(g)
        provenance.update(p)
    return geometries, provenance


def canonical_bundle_text(geometries, provenance, pairs_order):
    """Sérialisation canonique du bundle (schéma 2), stable entre scripts."""
    ordered_geoms = {u: geometries[u] for u in pairs_order if u in geometries}
    ordered_prov = {u: provenance.get(u, "osrm-driving")
                    for u in pairs_order if u in geometries}
    bundle = {"schema": 2, "count": len(ordered_geoms),
              "provenance": ordered_prov, "geometries": ordered_geoms}
    return json.dumps(bundle, ensure_ascii=False, separators=(",", ":")) + "\n"


def geom_version_for(bundle_text, tag="v6"):
    return "%s-%s" % (tag, hashlib.sha256(bundle_text.encode("utf-8")).hexdigest()[:12])
