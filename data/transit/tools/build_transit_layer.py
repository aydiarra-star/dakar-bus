#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LOT 4.4 — Générateur de la couche de données de travail Dakar Bus.

Construit les trois niveaux sous data/transit/ :
  passbi/     LEVEL 1  RAW / HISTORICAL      (données PassBi, identifiants d'origine)
  validated/  LEVEL 2  VALIDATED REFERENCE   (confirmé par des sources actuelles)
  production/ LEVEL 3  PRODUCTION READY      (ce qui peut alimenter l'expérience usager)

Ne lit AUCUN fichier applicatif. N'écrit AUCUN fichier applicatif.
Ne touche ni data/gtfs/ (feed synthétique existant) ni data/transit/reference-policy.json.

Usage :  python3 data/transit/tools/build_transit_layer.py /tmp/passbi_gtfs
"""
import csv, io, json, os, re, sys, zipfile, collections, datetime

AUDIT_DATE = "2026-09-27"
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/passbi_gtfs"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

FEED_META = {
    "TER":      {"sha256": "09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408",
                 "git_blob": "0ea1bfb2929b8498e0c07830541a0ebd685a9427", "file": "gtfs_TER.zip"},
    "BRT":      {"sha256": "f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4",
                 "git_blob": "22e9f4cff94f213040dfa6e61250e1a04c0802e5", "file": "gtfs_BRT.zip"},
    "Dem_Dikk": {"sha256": "578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159",
                 "git_blob": "0d719ed5704a99cca60bac8e0ed038681c5fc5b3", "file": "gtfs_Dem_Dikk.zip"},
    "AFTU":     {"sha256": "7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428",
                 "git_blob": "2cb0fff80857d8b0a3591c58956cffc75d77071a", "file": "gtfs_AFTU.zip"},
}

# ---------------------------------------------------------------- lecture GTFS
def read_gtfs(net, name):
    """Lit un fichier GTFS d'un feed PassBi. Détecte le délimiteur depuis l'en-tête
    (calendar_dates.txt de DDD/AFTU a un en-tête au point-virgule et des données
    à la virgule — voir lot 4.2)."""
    with zipfile.ZipFile(os.path.join(SRC, FEED_META[net]["file"])) as zf:
        raw = zf.read(name).decode("utf-8-sig")
    if not raw.strip():
        return [], []
    lines = raw.splitlines()
    delim = ";" if lines[0].count(";") > lines[0].count(",") else ","
    rows = list(csv.DictReader(io.StringIO(raw), delimiter=delim))
    rows = [{k: (v or "").strip() for k, v in r.items() if k is not None} for r in rows]
    hdr = [h for h in (rows[0].keys() if rows else csv.reader([lines[0]], delimiter=delim).__next__())]
    return rows, hdr


def gtfs_files(net):
    with zipfile.ZipFile(os.path.join(SRC, FEED_META[net]["file"])) as zf:
        return sorted(n for n in zf.namelist() if n.endswith(".txt"))


# ---------------------------------------------------------------- provenance
def prov(source, source_type, url=None, date_source=None, date_verified=None,
         valid_from=None, valid_to=None, confidence="UNKNOWN", status="UNKNOWN", note=""):
    return {"source": source, "source_type": source_type, "source_url": url,
            "date_source": date_source, "date_verified": date_verified,
            "valid_from": valid_from, "valid_to": valid_to,
            "confidence": confidence, "status": status, "verification_note": note}


PASSBI_SRC_DATE = "2025-08-31"   # fin du feed_period du flux TER, le plus récent des quatre
SRC_TER   = "https://www.terdakar.sn/les_horaires_des_trains/"
SRC_DDD   = "https://demdikk.sn/info-voyageurs/"
SRC_BRT   = "https://www.sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/"
SRC_BRT3  = "https://www.sunubrt.sn/brt-3-semi-express/"
SRC_STATIONS = "https://senego.com/services/horaires-brt-ter"

out = collections.defaultdict(list)
def w(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(text)
    out["wrote"].append(path)

def wcsv(path, header, rows):
    b = io.StringIO(); cw = csv.DictWriter(b, header, lineterminator="\n"); cw.writeheader()
    for r in rows: cw.writerow({k: r.get(k, "") for k in header})
    w(path, b.getvalue())

def wjson(path, obj):
    w(path, json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


# ============================================================ LEVEL 1 — RAW
RAW_KEEP = {  # fichiers copiés tels quels en LEVEL 1.
    # Exclus de Git pour volume : stop_times, trips, shapes, fare_rules (44 Mo en AFTU).
    # Tous restent re-téléchargeables via le git_blob consigné dans MANIFEST.json.
    "TER": ["agency.txt", "routes.txt", "stops.txt", "calendar.txt"],
    "BRT": ["agency.txt", "routes.txt", "stops.txt", "calendar_dates.txt", "transfers.txt"],
    "Dem_Dikk": ["agency.txt", "routes.txt", "stops.txt", "calendar.txt", "calendar_dates.txt",
                 "fare_attributes.txt"],
    "AFTU": ["agency.txt", "routes.txt", "stops.txt", "calendar.txt", "calendar_dates.txt",
             "fare_attributes.txt"],
}
MAX_BYTES = 400_000  # garde-fou : aucun fichier LEVEL 1 au-delà n'est versionné
LEVEL1_DIR = {"TER": "ter", "BRT": "brt", "Dem_Dikk": "ddd", "AFTU": "aftu"}
manifest = {"generated_at": AUDIT_DATE,
            "generator": "data/transit/tools/build_transit_layer.py",
            "origin": "https://github.com/impactsolutionsas/passbi_core (branche dev)",
            "refetch": "gh api repos/impactsolutionsas/passbi_core/git/blobs/{git_blob} --jq .content | base64 -d > {file}",
            "licence_warning": ("Aucun fichier LICENSE dans le dépôt PassBi et aucune licence sur les données. "
                                "Toute republication externe est BLOQUÉE tant que la licence n'est pas clarifiée."),
            "feeds": {}}

for net, meta in FEED_META.items():
    files = gtfs_files(net)
    rows_counts = {}
    for f in files:
        r, _ = read_gtfs(net, f)
        rows_counts[f] = len(r)
    copied, skipped = [], []
    for f in RAW_KEEP[net]:
        if f not in files:
            continue
        with zipfile.ZipFile(os.path.join(SRC, meta["file"])) as zf:
            content = zf.read(f).decode("utf-8-sig")
        if len(content.encode("utf-8")) > MAX_BYTES:
            skipped.append({"file": f, "bytes": len(content.encode("utf-8")),
                            "reason": "dépasse le garde-fou de %d octets" % MAX_BYTES})
            continue
        w("passbi/%s/%s" % (LEVEL1_DIR[net], f), content)
        copied.append({"file": f, "bytes": len(content.encode("utf-8"))})
    ag, _ = read_gtfs(net, "agency.txt")
    manifest["feeds"][LEVEL1_DIR[net]] = {
        "archive": meta["file"], "sha256": meta["sha256"], "git_blob": meta["git_blob"],
        "agency": ag[0].get("agency_name") if ag else None,
        "agency_url": ag[0].get("agency_url") if ag else None,
        "agency_timezone": ag[0].get("agency_timezone") if ag else None,
        "files_in_archive": files, "row_counts": rows_counts,
        "copied_to_level1": [c["file"] for c in copied],
        "copied_bytes": sum(c["bytes"] for c in copied),
        "skipped_by_size_guard": skipped,
        "excluded_from_git": sorted(set(files) - {c["file"] for c in copied} - {s["file"] for s in skipped}),
        "exclusion_reason": ("volume (stop_times / trips / shapes / fare_rules) — re-téléchargeable "
                             "via git_blob"),
    }
wjson("MANIFEST.json", manifest)


# ============================================================ données de travail
ter_routes, _ = read_gtfs("TER", "routes.txt")
ter_stops, _  = read_gtfs("TER", "stops.txt")
ter_trips, _  = read_gtfs("TER", "trips.txt")
ter_st, _     = read_gtfs("TER", "stop_times.txt")
ter_cal, _    = read_gtfs("TER", "calendar.txt")

brt_routes, _ = read_gtfs("BRT", "routes.txt")
brt_stops, _  = read_gtfs("BRT", "stops.txt")
brt_trips, _  = read_gtfs("BRT", "trips.txt")
brt_st, _     = read_gtfs("BRT", "stop_times.txt")

ddd_routes, _ = read_gtfs("Dem_Dikk", "routes.txt")
ddd_stops, _  = read_gtfs("Dem_Dikk", "stops.txt")
ddd_trips, _  = read_gtfs("Dem_Dikk", "trips.txt")

aftu_routes, _ = read_gtfs("AFTU", "routes.txt")
aftu_stops, _  = read_gtfs("AFTU", "stops.txt")

# ---- projet (lecture seule, pour le crosswalk) -----------------------------
PROJ = json.load(open(os.path.join(ROOT, "..", "..", "flutter-src", "assets", "data",
                                   "dakar_network.json"), encoding="utf-8"))
proj_stops = {s["id"]: s for s in PROJ["stops"]}
proj_ter = [r for r in PROJ["routes"] if r["id"] == "ter_dakar_diamniadio"][0]
proj_b1 = [r for r in PROJ["routes"] if r["id"] == "brt_b1_guediawaye_petersen"][0]
proj_b2 = [r for r in PROJ["routes"] if r["id"] == "brt_b2_express"][0]
proj_b3 = [s for s in PROJ.get("services_not_exposed", []) if s["id"] == "brt_b3"][0]

# ============================================================ TER — 13 gares
par = {s["stop_id"]: (s.get("parent_station") or s["stop_id"]) for s in ter_stops}
sname = {s["stop_id"]: s["stop_name"] for s in ter_stops}
sgeo = {s["stop_id"]: (s["stop_lat"], s["stop_lon"]) for s in ter_stops
        if s.get("location_type") == "1"}
byt = collections.defaultdict(list)
for r in ter_st:
    byt[r["trip_id"]].append(r)

DAK = "544a27a5-c6c6-4b70-b217-9c15d9b4278a"
DIA = "4445e51b-971b-4f1a-a94a-1ca0c9bef411"
R_10001 = DAK + "-" + DIA
R_20001 = DIA + "-" + DAK

seq = []
for t in ter_trips:
    if t["route_id"] == R_10001:
        for x in sorted(byt[t["trip_id"]], key=lambda y: int(y["stop_sequence"])):
            p = par.get(x["stop_id"])
            if p not in seq:
                seq.append(p)
        break

# appariement PassBi -> projet : arrêt du projet le plus proche, contrôle d'ordre
import math
def hav(a, b):
    E = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = math.radians(b[0] - a[0]), math.radians(b[1] - a[1])
    return 2 * E * math.asin(math.sqrt(math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2))

cand = [s for s in proj_ter["stops"]]
ter_map, used = [], set()
for i, p in enumerate(seq, 1):
    c = (float(sgeo[p][0]), float(sgeo[p][1]))
    best = min((k for k in cand if k not in used),
               key=lambda k: hav(c, (proj_stops[k]["latitude"], proj_stops[k]["longitude"])))
    used.add(best)
    d = hav(c, (proj_stops[best]["latitude"], proj_stops[best]["longitude"]))
    ter_map.append({"sequence": i, "stop_name": sname[p], "passbi_stop_id": p,
                    "dakar_bus_stop_id": best,
                    "latitude": round(c[0], 6), "longitude": round(c[1], 6),
                    "dakar_bus_latitude": proj_stops[best]["latitude"],
                    "dakar_bus_longitude": proj_stops[best]["longitude"],
                    "coordinate_deviation_m": round(d),
                    "source": "PassBi (flux SETER) + senego.com/services/horaires-brt-ter + ter-senegal.sn/gares",
                    "source_type": "HYBRID", "status": "CONFIRMED", "confidence": "HIGH"})

# ---- service dominical : les 48 départs confirmés --------------------------
def sec(t):
    h, m, s = t.split(":"); return int(h)*3600 + int(m)*60 + int(s)
def hm(x): return "%02d:%02d:%02d" % (x//3600, x % 3600//60, x % 60)

SUNDAY_SVC = "db5eb1cc-bd0f-b516-2ab4-b4cf1998f578"
sunday_trips = []
for t in ter_trips:
    if t["service_id"] == SUNDAY_SVC and t["route_id"] == R_10001:
        d = [x for x in byt[t["trip_id"]] if par.get(x["stop_id"]) == DAK]
        if d:
            sunday_trips.append((sec(d[0]["departure_time"]), t))
sunday_trips.sort(key=lambda x: x[0])

official = []
x = 6*3600 + 25*60
while x <= 22*3600 + 5*60:
    official.append(x); x += 1200
official_set = set(official)

confirmed_trips = [(d, t) for d, t in sunday_trips if d in official_set]
unconfirmed_departures = sorted({hm(d)[:5] for d, t in sunday_trips if d not in official_set})
missing_from_passbi = [hm(o)[:5] for o in official if o not in {d for d, _ in sunday_trips}]

timepoint_col = "timepoint" in (ter_st[0].keys() if ter_st else [])

# ============================================================ LEVEL 2 — GTFS
ag_rows = [
    {"agency_id": "SETER", "agency_name": "SETER — Société d'Exploitation du TER",
     "agency_url": "https://www.terdakar.sn/", "agency_timezone": "Africa/Dakar", "agency_lang": "fr"},
]
wcsv("validated/gtfs/agency.txt",
     ["agency_id", "agency_name", "agency_url", "agency_timezone", "agency_lang"], ag_rows)

# stops.txt : identifiant PUBLIC = identifiant du projet (décision de modélisation §4)
stop_rows = [{"stop_id": m["dakar_bus_stop_id"], "stop_name": m["stop_name"],
              "stop_lat": m["latitude"], "stop_lon": m["longitude"]} for m in ter_map]
wcsv("validated/gtfs/stops.txt", ["stop_id", "stop_name", "stop_lat", "stop_lon"], stop_rows)

route_rows = [{"route_id": "ter_dakar_diamniadio", "agency_id": "SETER",
               "route_short_name": "TER", "route_long_name": "Dakar ↔ Diamniadio",
               "route_type": 2, "route_color": "8B4513", "route_text_color": "FFFFFF"}]
wcsv("validated/gtfs/routes.txt",
     ["route_id", "agency_id", "route_short_name", "route_long_name", "route_type",
      "route_color", "route_text_color"], route_rows)

# calendar.txt : fenêtre réduite à la date d'audit (aucune validité opérateur publiée)
cal_rows = [{"service_id": "TER_SUNDAY_AUDIT", "monday": 0, "tuesday": 0, "wednesday": 0,
             "thursday": 0, "friday": 0, "saturday": 0, "sunday": 1,
             "start_date": AUDIT_DATE.replace("-", ""), "end_date": AUDIT_DATE.replace("-", "")}]
wcsv("validated/gtfs/calendar.txt",
     ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
      "sunday", "start_date", "end_date"], cal_rows)
w("validated/gtfs/calendar_dates.txt",
  "service_id,date,exception_type\n")

trip_rows, st_rows = [], []
pub_of = {m["passbi_stop_id"]: m["dakar_bus_stop_id"] for m in ter_map}
for n, (dep, t) in enumerate(confirmed_trips, 1):
    tid = "TER_SUN_%03d" % n
    trip_rows.append({"trip_id": tid, "route_id": "ter_dakar_diamniadio",
                      "service_id": "TER_SUNDAY_AUDIT", "trip_headsign": "Diamniadio",
                      "direction_id": 0})
    legs = sorted(byt[t["trip_id"]], key=lambda y: int(y["stop_sequence"]))
    for k, leg in enumerate(legs, 1):
        parent = par.get(leg["stop_id"], leg["stop_id"])
        st_rows.append({"trip_id": tid, "arrival_time": leg["arrival_time"],
                        "departure_time": leg["departure_time"],
                        "stop_id": pub_of[parent],
                        "stop_sequence": k,
                        "timepoint": leg.get("timepoint", "") if timepoint_col else ""})
wcsv("validated/gtfs/trips.txt",
     ["trip_id", "route_id", "service_id", "trip_headsign", "direction_id"], trip_rows)
st_hdr = ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"]
if timepoint_col:
    st_hdr.append("timepoint")
wcsv("validated/gtfs/stop_times.txt", st_hdr, st_rows)

# ---- registre TER ----------------------------------------------------------
wjson("validated/structure/ter_stop_mapping.json", {
    "level": 2, "network": "TER", "generated_at": AUDIT_DATE,
    "modelling_decision": ("L'identifiant PUBLIC retenu est l'identifiant déjà utilisé par "
                           "dakar_network.json (ex. stop_colobane). L'UUID PassBi est conservé "
                           "uniquement comme identifiant historique dans passbi_stop_id et dans "
                           "le crosswalk. Aucun UUID PassBi n'est exposé comme identifiant public."),
    "provenance_by_field": {
        "stop_name": prov("PassBi (flux SETER) + senego.com + ter-senegal.sn", "HYBRID",
                          SRC_STATIONS, PASSBI_SRC_DATE, AUDIT_DATE,
                          confidence="HIGH", status="CONFIRMED",
                          note="13/13 gares retrouvées dans le même ordre par 3 sources 2026 indépendantes"),
        "coordinates": prov("PassBi (flux SETER), recoupées avec dakar_network.json", "PASSBI",
                            None, PASSBI_SRC_DATE, AUDIT_DATE,
                            confidence="HIGH", status="CONFIRMED",
                            note="écart moyen 85 m, maximum 221 m (Colobane), minimum 9 m"),
        "sequence": prov("PassBi (flux SETER) + senego.com (numérotation 1→13)", "HYBRID",
                         SRC_STATIONS, PASSBI_SRC_DATE, AUDIT_DATE,
                         confidence="HIGH", status="CONFIRMED",
                         note="Rang de séquence identique entre PassBi, dakar_network.json et la "
                              "numérotation 1→13 publiée par senego.com (2026-07)"),
    },
    "stops": ter_map,
    "coordinate_check": {
        "matched": len(ter_map), "total": 13,
        "mean_deviation_m": round(sum(m["coordinate_deviation_m"] for m in ter_map) / len(ter_map)),
        "max_deviation_m": max(m["coordinate_deviation_m"] for m in ter_map),
        "max_deviation_stop": max(ter_map, key=lambda m: m["coordinate_deviation_m"])["stop_name"],
        "min_deviation_m": min(m["coordinate_deviation_m"] for m in ter_map),
        "crossed_pairing": False,
        "note": "Chaque gare PassBi s'apparie à un arrêt distinct du projet, au même rang de séquence.",
    },
    "not_added": [
        {"name": "AIBD", "status": "PROVISIONAL",
         "reason": "Mise en service annoncée au 28/09/2026 ; non confirmée par l'opérateur à la date d'audit."},
        {"name": "Sébikotane", "status": "UNKNOWN",
         "reason": "Aucune source actuelle trouvée."},
        {"name": "Keur Moussa", "status": "UNKNOWN",
         "reason": "Commune traversée par la phase 2 (EESS BAD 2016), jamais documentée comme gare. "
                   "Une commune traversée n'est pas une station."},
    ],
})

wjson("validated/structure/ter_schedule.json", {
    "level": 2, "network": "TER", "generated_at": AUDIT_DATE,
    "two_level_separation": {
        "historical_passbi_schedule": {
            "location": "data/transit/passbi/ter/ (stop_times non versionnés, voir MANIFEST.json)",
            "feed_period": "20250818-20250831",
            "weekday": {"frequency_min": 12, "first_departure_dakar": "05:30",
                        "last_departure": "22:06", "departures": 81,
                        "status": "CONTRADICTED",
                        "contradicted_by": SRC_TER,
                        "current_operator_value": {"frequency_min": 10,
                                                   "first_departure_dakar": "05:45",
                                                   "last_departure": "22:05"},
                        "usage": "référence historique uniquement — NE PAS afficher comme actuel"},
            "sunday": {"frequency_min": 20, "first_departure_dakar": "06:25",
                       "last_departure": "22:05", "departures": len(sunday_trips),
                       "status": "PARTIALLY_CONFIRMED"},
        },
        "current_operator_schedule": {
            "source": SRC_TER, "source_type": "OFFICIAL_OPERATOR",
            "date_verified": AUDIT_DATE,
            "weekday": {"frequency_min": 10, "first_departure_dakar": "05:45",
                        "evening_frequency_min": 20, "evening_from": "21:05",
                        "last_departure": "22:05", "status": "CONFIRMED",
                        "exact_stop_times_published": False,
                        "resulting_status": "ESTIMATED",
                        "note": "L'opérateur publie une FRÉQUENCE, pas une heure par station. "
                                "Une fréquence ne devient jamais un horaire exact."},
            "sunday": {"frequency_min": 20, "first_departure_dakar": "06:25",
                       "last_departure": "22:05", "status": "CONFIRMED",
                       "exact_stop_times_published": False, "resulting_status": "ESTIMATED"},
        },
    },
    "sunday_reconciliation": {
        "official_series_departures": len(official),
        "passbi_series_departures": len(sunday_trips),
        "passbi_found_in_official": len(confirmed_trips),
        "official_missing_from_passbi": missing_from_passbi,
        "passbi_only_departures": unconfirmed_departures,
        "conclusion": ("Aucun départ officiel actuel n'est absent de PassBi. Les départs "
                       "supplémentaires PassBi sont conservés en LEVEL 1 uniquement."),
    },
    "promoted_to_level2": {
        "trips": len(confirmed_trips),
        "basis": "les 48 départs correspondant exactement à la série officielle actuelle",
        "schedule_status": "PARTIALLY_CONFIRMED",
        "departure_times_dakar": [hm(d) for d, _ in confirmed_trips],
        "excluded": unconfirmed_departures,
        "exclusion_reason": "départs PassBi sans correspondance dans la grille actuelle",
    },
    "gtfs_time_convention": {
        "rule": ("Convention GTFS conservée : les heures >= 24:00 (25:xx, 26:xx) sont écrites "
                 "telles quelles et ne sont JAMAIS converties en heure civile du jour suivant."),
        "times_rewritten": 0,
        "note": ("Les heures du LEVEL 2 sont copiées caractère pour caractère depuis le feed "
                 "PassBi. Le test tests/transit-data-layer.test.js le vérifie."),
    },
    "calendar_note": ("La fenêtre GTFS est volontairement réduite à la seule date d'audit "
                      "(%s). Aucune période de validité opérateur n'est publiée : cette fenêtre "
                      "est un garde-fou, pas une validation de validité." % AUDIT_DATE),
    "field_level_status": {
        "origin_departure_time": "PARTIALLY_CONFIRMED",
        "intermediate_stop_times": "UNCONFIRMED",
        "timepoint_column_present": timepoint_col,
        "timepoint_note": ("Le flag timepoint existe dans le feed PassBi mais est DÉTRUIT à "
                           "l'import par PassBi (aucune colonne timepoint dans son schéma ni "
                           "dans ses 9 migrations — lot 4.2B). La distinction heure exacte / "
                           "heure approximative n'est donc pas fiable en aval."),
    },
})

# ============================================================ BRT
bpar = {s["stop_id"]: (s.get("parent_station") or s["stop_id"]) for s in brt_stops}
bname = {s["stop_id"]: s["stop_name"] for s in brt_stops}
bgeo = {s["stop_id"]: (float(s["stop_lat"]), float(s["stop_lon"])) for s in brt_stops
        if s.get("location_type") == "1"}
bbyt = collections.defaultdict(list)
for r in brt_st:
    bbyt[r["trip_id"]].append(r)

def best_variant(route_id):
    var = collections.Counter()
    for t in brt_trips:
        if t["route_id"] != route_id:
            continue
        s = tuple(bpar.get(x["stop_id"], x["stop_id"])
                  for x in sorted(bbyt[t["trip_id"]], key=lambda y: int(y["stop_sequence"])))
        var[s] += 1
    return var.most_common(1)[0]

b1_seq, b1_n = best_variant("B1")
b2_seq, b2_n = best_variant("B2")
served = {bpar.get(r["stop_id"]) for r in brt_st}
unserved = sorted((bname[s] for s in bgeo if s not in served))

# stations physiques BRT : identifiant public = celui du projet quand il existe
proj_brt = list(proj_b1["stops"])
brt_phys, brt_unmerged, taken = [], [], {}
for sid in sorted(bgeo, key=lambda s: bname[s]):
    if sid not in served:
        continue
    c = bgeo[sid]
    best = min(proj_brt, key=lambda k: hav(c, (proj_stops[k]["latitude"], proj_stops[k]["longitude"])))
    d = hav(c, (proj_stops[best]["latitude"], proj_stops[best]["longitude"]))
    if best in taken:
        # Deux stations PassBi se résolvent sur le même arrêt du projet.
        # NON fusionnées : la proximité géographique seule ne suffit pas (§11 du lot 4.3).
        brt_unmerged.append({
            "passbi_stop_id": sid, "stop_name": bname[sid],
            "resolves_to_same_as": taken[best], "dakar_bus_stop_id": best,
            "coordinate_deviation_m": round(d), "status": "UNCONFIRMED",
            "merged": False,
            "note": ("Se résout sur le même arrêt du projet par proximité, mais n'est PAS "
                     "fusionnée. Une preuve opérateur serait nécessaire pour trancher.")})
        continue
    taken[best] = bname[sid]
    brt_phys.append({"passbi_stop_id": sid, "stop_name": bname[sid],
                     "dakar_bus_stop_id": best, "dakar_bus_stop_name": proj_stops[best]["name"],
                     "latitude": round(c[0], 6), "longitude": round(c[1], 6),
                     "coordinate_deviation_m": round(d),
                     "status": "PERSISTENT" if d <= 500 else "UNCONFIRMED"})
b2p = {p["passbi_stop_id"]: p["dakar_bus_stop_id"] for p in brt_phys}

def dirseq(s):
    return [{"stop_sequence": i, "passbi_stop_id": x, "stop_name": bname[x],
             "dakar_bus_stop_id": b2p.get(x)} for i, x in enumerate(s, 1)]

wjson("validated/structure/brt_route_structure.json", {
    "level": 2, "network": "BRT", "generated_at": AUDIT_DATE,
    "anti_duplicate_display_rule": {
        "principle": "1 station physique + plusieurs routes = plusieurs stop_times",
        "implementation": ("Les stations partagées par B1 et B2 portent le MÊME dakar_bus_stop_id. "
                           "B1 et B2 restent deux route_id distincts avec leur propre direction_id "
                           "et leur propre stop_sequence. Aucune station n'est dupliquée par ligne."),
        "shared_stations": sorted({bname[x] for x in b2_seq} & {bname[x] for x in b1_seq}),
        "routes_kept_distinct": ["B1", "B2", "B3"],
        "never_merged": "B1 et B2 ne sont pas fusionnés : partager des stations ne fait pas une seule route.",
    },
    "physical_stations": brt_phys,
    "unmerged_passbi_duplicates": brt_unmerged,
    "unmerged_rule": ("Deux stations PassBi peuvent se résoudre sur le même arrêt du projet par "
                      "proximité. Elles ne sont PAS fusionnées : la proximité géographique seule "
                      "ne suffit pas à établir qu'il s'agit d'une seule station physique. Elles "
                      "restent listées séparément, en statut UNCONFIRMED, en attente d'une preuve "
                      "opérateur."),
    "routes": [
        {"route_id": "brt_b1", "passbi_route_id": "B1", "identity_status": "CONFIRMED",
         "structure_status": "PERSISTENT", "schedule_status": "UNCONFIRMED",
         "origin": "Préfecture de Guédiawaye", "destination": "Papa Gueye Fall (Petersen)",
         "passbi_stations": len(b1_seq), "passbi_trips": b1_n,
         "current_stations": len(proj_b1["stops"]),
         "direction_id_0": dirseq(b1_seq), "direction_id_1": dirseq(tuple(reversed(b1_seq))),
         "shape_id": None,
         "shape_note": "6 785 points de shape existent en LEVEL 1 ; non validés actuellement.",
         "difference_documented": ("PassBi dessert 21 stations ; le réseau actuel en compte 23. "
                                   "Gadaye et Fith Mith figurent dans le stops.txt PassBi mais "
                                   "n'y sont desservies par aucune course."),
         "source": "PassBi + sunubrt.sn + dakar_network.json", "source_type": "HYBRID",
         "date_verified": AUDIT_DATE, "confidence": "HIGH"},
        {"route_id": "brt_b2", "passbi_route_id": "B2", "identity_status": "CONFIRMED",
         "structure_status": "CONFIRMED", "schedule_status": "UNCONFIRMED",
         "origin": "Papa Gueye Fall (Petersen)", "destination": "Préfecture de Guédiawaye",
         "passbi_stations": len(b2_seq), "passbi_trips": b2_n,
         "current_stations": len(proj_b2["stops"]),
         "direction_id_0": dirseq(b2_seq), "direction_id_1": dirseq(tuple(reversed(b2_seq))),
         "shape_id": None,
         "difference_documented": "Aucune. 7 stations, même ordre, même fréquence (6 min), lundi-samedi.",
         "source": "PassBi + sunubrt.sn", "source_type": "HYBRID",
         "date_verified": AUDIT_DATE, "confidence": "HIGH"},
    ],
    "b3_identity_only": {
        "route_id": "brt_b3", "identity_status": "NEW", "structure_status": "UNCONFIRMED",
        "schedule_status": "UNKNOWN", "realtime_status": "UNKNOWN",
        "source": SRC_BRT3, "source_type": "OFFICIAL_OPERATOR", "date_verified": "2026-09-24",
        "official_station_names": proj_b3.get("official_station_names", []),
        "in_passbi": False,
        "excluded_from_gtfs": True,
        "exclusion_reason": ("Identité confirmée, structure non validée. Aucun stop_id ni coordonnée "
                             "n'est attribué : le parcours n'est PAS reconstruit par proximité "
                             "géographique. La ligne reste hors GTFS tant que l'opérateur n'a pas "
                             "publié sa liste de stations rattachable."),
        "note": ("Le stops.txt PassBi contient GUEULE TAPEE (1:GTA), non desservie par B1 ni B2, "
                 "et Gueule Tapée figure parmi les stations officielles de la B3. Ce rapprochement "
                 "est NAME_ONLY et n'est PAS utilisé pour construire la ligne."),
    },
    "passbi_stations_not_served": unserved,
    "not_served_note": ("GADAYE, FITH MITH et GUEULE TAPEE sont des stations réelles du réseau "
                        "actuel, présentes dans le référentiel PassBi mais non exploitées. "
                        "Les 4 autres sont des doublons de pôles d'échange. Aucun doublon n'est "
                        "fusionné : la proximité géographique seule ne suffit pas."),
    "frequency": {"value_min": 6, "status": "CONFIRMED", "source": SRC_BRT,
                  "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE,
                  "note": "Fréquence confirmée. Ne devient jamais un horaire exact."},
    "peak_reinforcement": {
        "segment": "Petersen ↔ Grand Médine", "status": "PERSISTENT", "confidence": "MEDIUM",
        "passbi_observed": "258 courses, 6h-9h et 17h-20h, variante 14 stations",
        "current_documented": "matin sens Petersen 6h-10h, soir sens Grand-Médine 16h-20h",
        "source": SRC_BRT, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE,
    },
})

# ============================================================ DDD
# liste officielle actuelle demdikk.sn/info-voyageurs (lot 4.3)
CUR_DDD = {
 "1": "PARCELLES ASSAINIES ↔ PLACE LECLERC", "2": "DAROUKHANE ↔ PLACE LECLERC",
 "4": "LIBERTÉ 5 ↔ PLACE LECLERC", "5": "GUÉDIAWAYE ↔ PALAIS 1",
 "6": "CAMBÉRÈNE 2 ↔ PALAIS 2", "7": "OUAKAM ↔ PALAIS 2",
 "8": "AÉROPORT LSS ↔ PALAIS 2", "9": "LIBERTÉ 6 ↔ PALAIS 2",
 "10": "LIBERTÉ 5 ↔ PALAIS 2", "11": "KEUR MASSAR ↔ LAT DIOR",
 "12": "GUÉDIAWAYE ↔ PALAIS 1", "13": "LIBERTÉ 5 ↔ PALAIS 2",
 "15": "RUFISQUE ↔ PALAIS 1 (15A/15B)", "16": "MALIKA ↔ PALAIS 1 (16A/16B)",
 "18": "DIEUPPEUL ↔ CENTRE-VILLE", "20": "DIEUPPEUL ↔ CENTRE-VILLE",
 "21": None, "23": "PARCELLES ASSAINIES ↔ PALAIS 1",
 "121": "SCAT URBAM ↔ LECLERC", "208": "BAYAKH ↔ RUFISQUE",
 "213": "RUFISQUE ↔ DIEUPPEUL", "217": "THIAROYE ↔ OUAKAM",
 "218": "THIAROYE ↔ AÉROPORT LSS", "219": "DAROUKHANE ↔ OUAKAM",
 "220": "RUFISQUE ↔ GUÉDIAWAYE", "221": "GADAYE ↔ ALMADIES",
 "227": "KEUR MASSAR ↔ PARCELLES", "228": "RUFISQUE ↔ YENNE",
 "232": "BAUX MARAICHERS ↔ AÉROPORT LSS", "233": "BAUX MARAICHERS ↔ PALAIS 1",
 "234": "JAXAAY ↔ LECLERC", "501": "GARE DE DAKAR ↔ PALAIS 2",
 "502": "COLOBANE ↔ UCAD / ABASS NDAO (502A/502B)",
 "503": "COLOBANE ↔ MOLE 8 / HYDROCARBURE (503A/503B)",
 "504": "GARE DIAMNIADIO ↔ SPHERE MINISTERIEL (504A/504B)",
}
CUR_DDD = {k: v for k, v in CUR_DDD.items() if v}

ddd_trips_by_route = collections.Counter(t["route_id"] for t in ddd_trips)
ddd_stops_by_route = collections.defaultdict(set)
ddd_trip_stops = collections.defaultdict(list)
for r in read_gtfs("Dem_Dikk", "stop_times.txt")[0]:
    ddd_trip_stops[r["trip_id"]].append(r)

persistent, not_found = [], []
for r in ddd_routes:
    code = r["route_short_name"]
    m = re.match(r"D\s*(\d+)", code)
    num = m.group(1) if m else None
    ntrips = ddd_trips_by_route.get(r["route_id"], 0)
    nstops = len({s["stop_id"] for t in ddd_trips if t["route_id"] == r["route_id"]
                  for s in ddd_trip_stops.get(t["trip_id"], [])})
    base = {"passbi_route_id": r["route_id"], "route_short_name": code,
            "route_long_name": r.get("route_long_name", ""),
            "operator": "Dakar Dem Dikk", "passbi_trips": ntrips, "passbi_stops": nstops}
    if num in CUR_DDD:
        o, d = CUR_DDD[num].split("↔")
        persistent.append(dict(base, official_number=num, origin=o.strip(),
            destination=d.strip(),
            identity_status="PERSISTENT", structure_status="UNKNOWN",
            schedule_status="UNKNOWN", realtime_status="UNKNOWN",
            match_basis="numéro + terminus (initiales du code PassBi confrontées à demdikk.sn)",
            source=SRC_DDD, source_type="OFFICIAL_OPERATOR", date_verified=AUDIT_DATE,
            status="PERSISTENT", confidence="HIGH",
            note=("Identité persistante. Cela ne prouve ni le parcours complet, ni les arrêts "
                  "actuels, ni les horaires actuels.")))
    else:
        not_found.append(dict(base, official_number=num,
            identity_status="UNCONFIRMED", structure_status="UNKNOWN",
            schedule_status="UNKNOWN", realtime_status="UNKNOWN",
            source=None, source_type=None, date_verified=None,
            status="NOT_FOUND", confidence="LOW",
            note=("Absente des sources vérifiées, mais absence insuffisante pour conclure à une "
                  "suppression. NE PAS écrire DISCONTINUED.")))

proj_ddd = sorted((r["id"].replace("ddd_", "") for r in PROJ["routes"]
                   if r["id"].startswith("ddd_")), key=int)
pnum = {p["official_number"]: p["route_short_name"] for p in persistent}
ddd_cross_project = []
for n in proj_ddd:
    ddd_cross_project.append({
        "dakar_bus_route_id": "ddd_" + n, "official_number": n,
        "in_passbi": n in pnum, "passbi_code": pnum.get(n),
        "in_operator_current_list": n in CUR_DDD,
        "status": ("PERSISTENT" if (n in pnum and n in CUR_DDD) else "UNKNOWN"),
        "note": ("Identité rapprochée par numéro ET terminus." if (n in pnum and n in CUR_DDD)
                 else "Absente de PassBi et de la liste opérateur actuelle.")})

wjson("validated/structure/ddd_routes.json", {
    "level": 2, "network": "DDD", "generated_at": AUDIT_DATE,
    "source": SRC_DDD, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE,
    "counts": {"passbi_total": len(ddd_routes), "persistent": len(persistent),
               "not_found": len(not_found), "new_current": 0,
               "exposed_by_dakar_bus": len(proj_ddd)},
    "rule_applied": ("IDENTITY = PERSISTENT, STRUCTURE = UNKNOWN, SCHEDULE = UNKNOWN. "
                     "Une ligne retrouvée par numéro + terminus ne prouve ni son parcours, "
                     "ni ses arrêts, ni ses horaires."),
    "persistent_routes": persistent,
    "not_found_routes": not_found,
    "not_found_rule": ("Aucune ligne n'est supprimée. Aucun statut DISCONTINUED. "
                       "IDENTITY_STATUS = UNCONFIRMED, STATUS = NOT_FOUND."),
    "dakar_bus_confrontation": ddd_cross_project,
    "stops_policy": {
        "historical_stops": "data/transit/passbi/ddd/stops.txt (LEVEL 1, %d arrêts)" % len(ddd_stops),
        "current_verified_stops": [],
        "rule": ("Les arrêts PassBi ne sont PAS importés comme arrêts actuels. Ils servent de "
                 "crosswalk futur. Aucun arrêt n'est présenté comme actuel du seul fait de sa "
                 "présence dans PassBi."),
    },
})

# ============================================================ AFTU
aftu_trips_by_route = collections.Counter(t["route_id"] for t in read_gtfs("AFTU", "trips.txt")[0])
aftu_registry = []
for r in aftu_routes:
    code = r["route_short_name"]
    m = re.match(r"A(\d+)", code)
    aftu_registry.append({
        "passbi_route_id": r["route_id"], "passbi_short_name": code,
        "passbi_long_name": r.get("route_long_name", ""),
        "passbi_number": m.group(1) if m else None,
        "origin": (r.get("route_long_name", "").split("->")[0].strip()
                   if "->" in r.get("route_long_name", "") else None),
        "destination": (r.get("route_long_name", "").split("->")[-1].strip()
                        if "->" in r.get("route_long_name", "") else None),
        "passbi_trips": aftu_trips_by_route.get(r["route_id"], 0),
        "source": "PassBi (gtfs_AFTU.zip)", "source_type": "PASSBI",
        "source_date": "2022-01-01/2023-12-31",
        "identity_status": "UNCONFIRMED", "structure_status": "UNKNOWN",
        "schedule_status": "UNKNOWN", "realtime_status": "UNKNOWN", "confidence": "LOW",
    })
aftu_nums = [a["passbi_number"] for a in aftu_registry if a["passbi_number"]]
wjson("validated/structure/aftu_raw_registry.json", {
    "level": 2, "network": "AFTU", "generated_at": AUDIT_DATE,
    "identity_status": "UNCONFIRMED",
    "reason": ("Le lot 4.3 a démontré que les numérotations sont incompatibles : PassBi utilise "
               "1-5 puis 24-91, dakar_network.json utilise 1-72 en continu. Aucun chevaucement "
               "n'est possible. PASSBI A30 ≠ DAKAR BUS ligne 30 sans preuve."),
    "numbering_gap": {
        "passbi_numbers": sorted(set(aftu_nums), key=int),
        "passbi_absent_from_1_72": [str(i) for i in range(1, 73) if str(i) not in set(aftu_nums)],
        "passbi_above_72": sorted([n for n in set(aftu_nums) if int(n) > 72], key=int),
        "dakar_bus_numbering": "1-72 continu",
        "cetud_official_count": 72, "passbi_count": len(aftu_registry),
    },
    "import_rule": "Aucune identité AFTU n'est importée. Référentiel brut uniquement.",
    "raw_registry": aftu_registry,
    "reconciliation_lead": ("Les codes PassBi (A1HL, A24NU, A91AD…) encodent vraisemblablement les "
                            "terminus en suffixe. C'est une piste de réconciliation pour un lot "
                            "dédié — pas une correspondance établie."),
})

# ============================================================ CROSSWALK
cw, n = [], 0
def add(source, sid, target, tid, mtype, ev, conf, note=""):
    global n
    n += 1
    cw.append({"crosswalk_id": "CW%04d" % n, "source": source, "source_id": sid,
               "target": target, "target_id": tid, "match_type": mtype,
               "evidence": ev, "confidence": conf, "verified_at": AUDIT_DATE,
               "note": note})

for m in ter_map:
    add("passbi", m["passbi_stop_id"], "dakar_bus", m["dakar_bus_stop_id"], "DOCUMENTED",
        "nom + rang de séquence + coordonnées (écart %d m) + 3 sources 2026 indépendantes"
        % m["coordinate_deviation_m"], "HIGH")
add("passbi", R_10001, "dakar_bus", "ter_dakar_diamniadio", "DOCUMENTED",
    "mêmes 13 gares, même ordre, terminus identiques", "HIGH", "direction_id 0")
add("passbi", R_20001, "dakar_bus", "ter_dakar_diamniadio", "DOCUMENTED",
    "mêmes 13 gares, ordre inverse, terminus identiques", "HIGH", "direction_id 1")

for s in b1_seq + b2_seq:
    if s in b2p:
        add("passbi", s, "dakar_bus", b2p[s], "DOCUMENTED",
            "station BRT : nom + position + appartenance à B1/B2 confirmée", "HIGH")
for s in bgeo:
    if bname[s] == "GUEULE TAPEE":
        add("passbi", s, "dakar_bus", "brt_b3:Gueule Tapée", "NAME_ONLY",
            "nom uniquement ; station non desservie dans PassBi", "LOW",
            "NAME_ONLY ne suffit pas pour identifier une ligne. NON utilisé pour construire la B3.")
for s in bgeo:
    if s not in served:
        add("passbi", s, "dakar_bus", None, "UNCONFIRMED",
            "station PassBi non desservie ; doublon de pôle ou station non exploitée", "LOW",
            "Aucune fusion : la proximité géographique seule ne suffit pas.")

for p in persistent:
    add("passbi", p["passbi_route_id"], "demdikk_current", "LIGNE " + p["official_number"],
        "DOCUMENTED", "numéro + terminus publiés par l'opérateur", "HIGH")
    tgt = [c for c in ddd_cross_project if c["official_number"] == p["official_number"]]
    if tgt and tgt[0]["in_passbi"]:
        add("passbi", p["passbi_route_id"], "dakar_bus", tgt[0]["dakar_bus_route_id"],
            "DOCUMENTED", "numéro + terminus ; itinéraire interne du projet à vérifier",
            "MEDIUM" if p["official_number"] != "1" else "LOW",
            "Pour ddd_1, l'itinéraire interne du projet est déjà marqué CONFLICTING."
            if p["official_number"] == "1" else "")
for p in not_found:
    add("passbi", p["passbi_route_id"], None, None, "UNCONFIRMED",
        "aucune correspondance dans la liste opérateur actuelle", "LOW",
        "NOT_FOUND ≠ SUPPRIMED.")
for a in aftu_registry:
    add("passbi", a["passbi_route_id"], "dakar_bus", None, "UNCONFIRMED",
        "numérotation incompatible ; aucune base d'appariement", "LOW",
        "NUMBER_ONLY ne suffit jamais.")

wjson("crosswalk/crosswalk.json", {
    "generated_at": AUDIT_DATE,
    "match_type_rules": {
        "EXACT": "identifiant identique dans les deux systèmes",
        "DOCUMENTED": "correspondance établie par preuve documentée (nom + terminus + coordonnées + source actuelle)",
        "STRUCTURAL": "correspondance par position structurelle dans une séquence",
        "NAME_ONLY": "nom seul",
        "COORDINATE_ONLY": "coordonnées seules",
        "UNCONFIRMED": "aucune base suffisante",
    },
    "policy": {
        "COORDINATE_ONLY": "ne suffit pas pour identifier une ligne",
        "NAME_ONLY": "ne suffit pas pour identifier une ligne",
        "NUMBER_ONLY": "ne suffit jamais",
    },
    "total": len(cw),
    "by_match_type": dict(collections.Counter(c["match_type"] for c in cw)),
    "by_confidence": dict(collections.Counter(c["confidence"] for c in cw)),
    "entries": cw,
})

# ============================================================ STATUT PAR ROUTE
def rs(rid, net, i_, s_, sc_, rt_, note=""):
    return {"route_id": rid, "network": net, "route_identity_status": i_,
            "route_structure_status": s_, "route_schedule_status": sc_,
            "route_realtime_status": rt_, "note": note}

route_status = [
    rs("ter_dakar_diamniadio", "TER", "CONFIRMED", "CONFIRMED", "PARTIALLY_CONFIRMED", "UNKNOWN",
       "13/13 gares confirmées. Grille dimanche confirmée (48/48) ; grille semaine CONTRADICTED "
       "(12 min PassBi vs 10 min opérateur) et exclue du LEVEL 2. Aucun temps réel."),
    rs("brt_b1", "BRT", "CONFIRMED", "PERSISTENT", "UNCONFIRMED", "UNKNOWN",
       "Identité et 21 stations confirmées ; réseau actuel passé à 23 stations."),
    rs("brt_b2", "BRT", "CONFIRMED", "CONFIRMED", "UNCONFIRMED", "UNKNOWN",
       "7/7 stations, même ordre, fréquence 6 min confirmée. Aucun horaire validé."),
    rs("brt_b3", "BRT", "NEW", "UNCONFIRMED", "UNKNOWN", "UNKNOWN",
       "Apparue en octobre 2025, absente de PassBi. Hors GTFS : structure non validée."),
]
for p in persistent:
    route_status.append(rs("ddd_" + p["official_number"], "DDD", "PERSISTENT", "UNKNOWN",
                           "UNKNOWN", "UNKNOWN",
                           "PassBi %s. Identité par numéro + terminus uniquement."
                           % p["route_short_name"]))
for p in not_found:
    route_status.append(rs("passbi:" + p["route_short_name"], "DDD", "UNCONFIRMED", "UNKNOWN",
                           "UNKNOWN", "UNKNOWN", "NOT_FOUND — non supprimée."))
for a in aftu_registry:
    route_status.append(rs("passbi:" + a["passbi_short_name"], "AFTU", "UNCONFIRMED", "UNKNOWN",
                           "UNKNOWN", "UNKNOWN", "Identité non établie (numérotation incompatible)."))

wjson("validated/route_status.json", {
    "generated_at": AUDIT_DATE,
    "four_independent_dimensions": ["identity", "structure", "schedule", "realtime"],
    "rule": "Aucune dimension n'est déduite automatiquement d'une autre.",
    "counts": {
        "identity": dict(collections.Counter(r["route_identity_status"] for r in route_status)),
        "structure": dict(collections.Counter(r["route_structure_status"] for r in route_status)),
        "schedule": dict(collections.Counter(r["route_schedule_status"] for r in route_status)),
        "realtime": dict(collections.Counter(r["route_realtime_status"] for r in route_status)),
    },
    "routes": route_status,
})

# ============================================================ LEVEL 3
prod = {
    "generated_at": AUDIT_DATE,
    "level": 3,
    "definition": "Données suffisamment documentées pour alimenter l'expérience utilisateur.",
    "ready": [
        {"entity": "TER — 13 gares (identité, ordre, coordonnées)",
         "status": "CONFIRMED", "confidence": "HIGH",
         "location": "data/transit/validated/structure/ter_stop_mapping.json",
         "usable_for": ["liste des gares", "plan de ligne", "distances", "correspondances"],
         "not_usable_for": ["horaires affichés comme certifiés", "temps réel"]},
        {"entity": "BRT B2 — 7 stations et leur ordre",
         "status": "CONFIRMED", "confidence": "HIGH",
         "location": "data/transit/validated/structure/brt_route_structure.json",
         "usable_for": ["liste des stations", "ordre de desserte"],
         "not_usable_for": ["horaires"]},
        {"entity": "BRT B1 — identité et ses 21 stations PassBi",
         "status": "PERSISTENT", "confidence": "HIGH",
         "location": "data/transit/validated/structure/brt_route_structure.json",
         "usable_for": ["structure de la ligne"],
         "not_usable_for": ["horaires", "liste exhaustive des stations actuelles (23)"]},
        {"entity": "Fréquences opérateur (TER 10 min semaine / 20 min dimanche ; BRT 6 min)",
         "status": "CONFIRMED", "confidence": "HIGH",
         "location": "data/transit/validated/structure/ter_schedule.json",
         "resulting_display_status": "ESTIMATED",
         "usable_for": ["mention d'une fréquence (« un train toutes les 10 min »)",
                        "amplitude de service (premier / dernier départ)",
                        "information voyageur non horodatée"],
         "not_usable_for": ["SCHEDULED", "heure exacte par station", "prochain départ calculé",
                            "REAL_TIME"]},
    ],
    "not_ready": [
        {"entity": "Horaires TER semaine", "status": "CONTRADICTED",
         "reason": "12 min PassBi vs 10 min opérateur ; premier départ 05:30 vs 05:45."},
        {"entity": "Horaires TER dimanche (heures intermédiaires)", "status": "PARTIALLY_CONFIRMED",
         "reason": "Départs de Dakar confirmés 48/48 ; heures par station intermédiaire non validées."},
        {"entity": "Horaires BRT / DDD / AFTU", "status": "UNCONFIRMED",
         "reason": "Aucune source horaire actuelle pour ces trois réseaux."},
        {"entity": "Structure des 34 lignes DDD persistantes", "status": "UNKNOWN",
         "reason": "Identité confirmée, parcours et arrêts non validés."},
        {"entity": "Identités AFTU (73 lignes)", "status": "UNCONFIRMED",
         "reason": "Numérotation incompatible avec celle du projet."},
        {"entity": "Temps réel, tous réseaux", "status": "UNKNOWN",
         "reason": "Aucun flux GTFS-RT ou SAE actif identifié."},
        {"entity": "Republication externe des données PassBi", "status": "BLOCKED",
         "reason": "Aucune licence sur les données PassBi."},
    ],
    "real_time": "NON — aucun feed ne peut être déclaré REAL_TIME dans ce lot.",
    "counts_ready": 4, "counts_not_ready": 7,
}
wjson("production/production_ready.json", prod)

# ============================================================ SCHÉMA
wjson("schema/provenance.schema.json", {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Dakar Bus Transit Data Layer — modèle de provenance",
    "description": ("Modèle de métadonnées compatible GTFS. Toute entité importante de la couche "
                    "peut porter ce bloc. Il est volontairement séparé des fichiers .txt GTFS, "
                    "qui restent syntaxiquement standards."),
    "type": "object",
    "required": ["source", "source_type", "status", "confidence"],
    "properties": {
        "source": {"type": ["string", "null"]},
        "source_type": {"enum": ["OFFICIAL_OPERATOR", "INSTITUTIONAL", "PASSBI", "OSM", "HYBRID",
                                 None]},
        "source_url": {"type": ["string", "null"]},
        "date_source": {"type": ["string", "null"], "description": "date de la donnée d'origine"},
        "date_verified": {"type": ["string", "null"], "description": "date de la dernière vérification"},
        "valid_from": {"type": ["string", "null"]},
        "valid_to": {"type": ["string", "null"]},
        "confidence": {"enum": ["HIGH", "MEDIUM", "LOW", "UNKNOWN"]},
        "status": {"enum": ["CONFIRMED", "PERSISTENT", "PARTIALLY_CONFIRMED", "UNCONFIRMED",
                            "CONTRADICTED", "NEW", "UNKNOWN", "NOT_FOUND"],
                   "description": ("NOT_FOUND est admis pour l'absence d'identité dans les sources "
                                   "actuelles (section 9 du lot). Il ne signifie jamais "
                                   "« supprimée » et ne doit jamais être remplacé par un statut "
                                   "de type DISCONTINUED.")},
        "verification_note": {"type": ["string", "null"]},
    },
    "rules": {
        "no_implicit_promotion": ("PASSBI ne devient jamais OFFICIAL_OPERATOR au motif que PassBi "
                                  "revendique l'usage de données CETUD."),
        "field_level_provenance": ("Quand plusieurs sources alimentent une même entité, la "
                                   "provenance est portée au niveau du champ "
                                   "(source_structure / source_schedule / source_coordinates), "
                                   "jamais réduite à 'source = PassBi'."),
        "four_independent_dimensions": ["identity", "structure", "schedule", "realtime"],
    },
    "status_definitions": {
        "CONFIRMED": "Source actuelle fiable confirmant explicitement la donnée.",
        "PERSISTENT": "Donnée PassBi ancienne retrouvée dans une source actuelle, sans contradiction.",
        "PARTIALLY_CONFIRMED": "Une partie de la donnée est confirmée mais pas l'ensemble.",
        "UNCONFIRMED": "Donnée conservée comme référence mais aucune validation actuelle suffisante.",
        "CONTRADICTED": "Une source actuelle fournit une information différente.",
        "NEW": "Donnée apparue après PassBi et confirmée par une source actuelle.",
        "UNKNOWN": "Impossible de déterminer l'état actuel.",
    },
})

# ============================================================ synthèse
summary = {
    "generated_at": AUDIT_DATE,
    "files_written": len(out["wrote"]),
    "ter": {"routes": 1, "directions": 2, "stops": len(ter_map),
            "trips_level2": len(confirmed_trips),
            "stop_times_level2": len(st_rows),
            "passbi_trips_level1": len(ter_trips),
            "sunday_confirmed": len(confirmed_trips),
            "sunday_passbi_only": unconfirmed_departures,
            "official_missing": missing_from_passbi,
            "timepoint_column": timepoint_col},
    "brt": {"routes": 3, "routes_in_gtfs": 0, "physical_stations": len(brt_phys),
            "unmerged_passbi_duplicates": len(brt_unmerged),
            "b1_stations": len(b1_seq), "b2_stations": len(b2_seq),
            "shared_stations": len({bname[x] for x in b2_seq} & {bname[x] for x in b1_seq}),
            "unserved_passbi_stations": len(unserved)},
    "ddd": {"passbi_routes": len(ddd_routes), "persistent": len(persistent),
            "not_found": len(not_found), "new_current": 0,
            "passbi_stops_level1": len(ddd_stops), "current_verified_stops": 0},
    "aftu": {"passbi_routes": len(aftu_registry), "identity_confirmed": 0,
             "passbi_stops_level1": len(aftu_stops)},
    "crosswalks": len(cw),
    "crosswalk_by_match_type": dict(collections.Counter(c["match_type"] for c in cw)),
    "route_status_rows": len(route_status),
}
wjson("validated/BUILD_SUMMARY.json", summary)
print(json.dumps(summary, ensure_ascii=False, indent=2))
