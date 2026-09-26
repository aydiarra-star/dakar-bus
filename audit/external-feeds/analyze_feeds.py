#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LOT 16 BIS — Analyse documentaire des flux GTFS externes récupérés
(audit/external-feeds/source/passbi_core/gtfs_folder/*.zip).

Ce script est un OUTIL D'AUDIT, PAS UN IMPORT :
  * il ne lit que les ZIP conservés dans source/ et, en LECTURE SEULE,
    flutter-src/assets/data/dakar_network.json (référentiel de production) et
    docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md (listes officielles
    aftu-senegal.org / demdikk.sn transcrites le 2026-09-25) ;
  * il n'écrit QUE dans audit/external-feeds/reports/ ;
  * il ne modifie ni dakar_network.json, ni le code Flutter, ni data/gtfs/.

Règles appliquées (cf. docs/AUDIT_FEEDS_CETUD_PASSBI_2026-09-26.md) :
  * le NUMÉRO d'une ligne provient EXCLUSIVEMENT des champs du flux
    (route_short_name, croisé avec route_id / route_long_name). Aucune
    identité n'est déduite d'OSM, de Moovit, d'un identifiant interne Dakar
    Bus ou d'un rapprochement géométrique ;
  * la « fréquence observée » est calculée à partir de stop_times.txt
    (écart entre départs successifs au premier arrêt). Aucun flux ne contient
    frequencies.txt : il n'existe donc AUCUNE fréquence déclarée dans les
    fichiers ; les deux notions restent séparées ;
  * la validité temporelle est classée CURRENT / HISTORICAL / FUTURE /
    UNKNOWN par rapport à la date d'audit (--as-of, défaut 2026-09-26).

Usage :
    python3 audit/external-feeds/analyze_feeds.py [--as-of 2026-09-26]
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import statistics
import sys
import unicodedata
import zipfile
from collections import Counter, defaultdict
from datetime import date, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SOURCE_DIR = os.path.join(HERE, "source", "passbi_core", "gtfs_folder")
REPORTS_DIR = os.path.join(HERE, "reports")
DAKAR_NETWORK = os.path.join(REPO, "flutter-src", "assets", "data", "dakar_network.json")
REFERENTIEL = os.path.join(REPO, "docs", "REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md")

FEEDS = [
    # (clé réseau, nom de fichier, agence attendue, nature)
    ("AFTU", "gtfs_AFTU.zip"),
    ("DDD", "gtfs_Dem_Dikk.zip"),
    ("BRT", "gtfs_BRT.zip"),
    ("TER", "gtfs_TER.zip"),
]

GTFS_FILES = [
    "agency.txt", "routes.txt", "stops.txt", "trips.txt", "stop_times.txt",
    "calendar.txt", "calendar_dates.txt", "shapes.txt", "fare_attributes.txt",
    "fare_rules.txt", "frequencies.txt", "transfers.txt", "feed_info.txt",
]

# ----------------------------------------------------------------------------
# Lecture GTFS tolérante (BOM, CRLF, en-tête « ; » de calendar_dates AFTU/DDD)
# ----------------------------------------------------------------------------

def _decode(raw: bytes) -> str:
    txt = raw.decode("utf-8-sig", errors="replace")
    return txt.replace("\r\n", "\n").replace("\r", "\n")


def read_table(zf: zipfile.ZipFile, name: str, notes: list, stream_cb=None):
    """Retourne (header, rows) ; rows = liste de dict. Si stream_cb est fourni,
    les lignes lui sont passées une à une et la liste retournée est vide
    (utilisé pour stop_times / fare_rules volumineux)."""
    if name not in zf.namelist():
        return None, []
    with zf.open(name) as fh:
        txt = _decode(fh.read())
    lines = txt.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines:
        return [], []
    header_line = lines[0]
    delimiter = ","
    if ";" in header_line and "," not in header_line:
        # Anomalie constatée dans gtfs_AFTU / gtfs_Dem_Dikk : l'en-tête de
        # calendar_dates.txt est séparé par « ; » alors que les données le
        # sont par « , ». On la consigne et on lit quand même.
        notes.append(f"{name}: en-tête séparé par ';' ({header_line!r}) alors que les lignes de données utilisent ',' — non conforme GTFS, lu en mode tolérant")
        header = [h.strip() for h in header_line.split(";")]
    else:
        header = next(csv.reader([header_line]))
        header = [h.strip() for h in header]
    rows = []
    reader = csv.reader(lines[1:])
    bad = 0
    for rec in reader:
        if not rec or all(c.strip() == "" for c in rec):
            continue
        if len(rec) != len(header):
            bad += 1
            # on tolère les lignes plus courtes/longues en tronquant/complétant
            rec = (rec + [""] * len(header))[: len(header)]
        row = dict(zip(header, [c.strip() for c in rec]))
        if stream_cb is not None:
            stream_cb(row)
        else:
            rows.append(row)
    if bad:
        notes.append(f"{name}: {bad} ligne(s) dont le nombre de colonnes diffère de l'en-tête")
    return header, rows


def hms_to_sec(s: str):
    s = (s or "").strip()
    m = re.match(r"^(\d{1,2}):(\d{2}):(\d{2})$", s)
    if not m:
        return None
    h, mi, se = (int(x) for x in m.groups())
    return h * 3600 + mi * 60 + se


def sec_to_hms(v):
    if v is None:
        return ""
    v = int(v)
    return f"{v // 3600:02d}:{(v % 3600) // 60:02d}:{v % 60:02d}"


def parse_yyyymmdd(s: str):
    s = (s or "").strip()
    if not re.match(r"^\d{8}$", s):
        return None
    try:
        return date(int(s[:4]), int(s[4:6]), int(s[6:8]))
    except ValueError:
        return None


def norm(s: str) -> str:
    """Normalisation de chaînes pour comparaison indicative de libellés."""
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.upper()
    s = re.sub(r"[^A-Z0-9]+", " ", s)
    return s.strip()


STOPWORDS = {"TERMINUS", "GARE", "DE", "DU", "DES", "LA", "LE", "LES", "ET", "X", "ROUTE",
             "CITE", "MARCHE", "PLACE", "ARRET", "DEPOT", "VIA", "LIGNE", "AFTU", "DDD",
             "TATA", "BUS", "EXPRESS", "GR", "HLM", "PEM", "KEUR", "GRAND", "GRANDE", "VILLE",
             "CENTRE", "NORD", "SUD", "EST", "OUEST", "VILLAGE", "STATION", "FACE", "EN", "PRES",
             "DEVANT", "ROUTIERE", "TERMINUS", "FERROVIAIRE", "URBAIN", "INTERURBAIN"}


def tokens(s: str) -> set:
    """Jetons significatifs d'un libellé de terminus (sans nombres ni mots génériques)."""
    return {t for t in norm(s).split() if t and t not in STOPWORDS and len(t) > 2 and not t.isdigit()}


def _tok_eq(a: str, b: str) -> bool:
    if a == b:
        return True
    if len(a) >= 4 and len(b) >= 4 and (a.startswith(b) or b.startswith(a)):
        return True
    if len(a) >= 5 and len(b) >= 5:
        import difflib
        return difflib.SequenceMatcher(None, a, b).ratio() >= 0.8
    return False


def terminus_matches(candidates: list, reference: str) -> bool:
    """Vrai si le terminus `reference` partage au moins un jeton significatif
    (égalité, préfixe ≥ 4 ou similarité ≥ 0.8) avec l'un des libellés `candidates`."""
    ref = tokens(reference)
    if not ref:
        return False
    for c in candidates:
        for tc in tokens(c):
            for tr in ref:
                if _tok_eq(tc, tr):
                    return True
    return False


def split_terminus(label: str) -> list:
    """Découpe un libellé « A ↔ B », « A - B », « A → B », « A <--> B » en terminus.
    Retire les parenthèses finales du type « (AFTU Ligne 12) »."""
    label = re.sub(r"\((?:AFTU|DDD|Tata)[^)]*\)", " ", label or "")
    parts = re.split(r"\s*(?:↔|<-->|-->|→|->|<->)\s*", label)
    if len(parts) == 1:
        parts = re.split(r"\s+-\s+|(?<=[A-Za-zÉÈ])-\s+|\s+-(?=[A-Za-zÉÈ])", label)
    return [p.strip() for p in parts if p and p.strip()]


def compare_terminus(candidates: list, reference_terminus: list) -> tuple:
    """Compare une liste de libellés candidats (flux) à la liste des terminus
    d'une référence. Retourne (nb_terminus_reference_retrouvés, nb_terminus_reference).
    Comparaison INDICATIVE de libellés : elle ne fonde jamais une identité,
    elle signale seulement une cohérence ou une contradiction pour un MÊME numéro."""
    refs = [r for r in reference_terminus if tokens(r)]
    if not refs or not any(tokens(c) for c in candidates):
        return (None, len(refs))
    found = sum(1 for r in refs if terminus_matches(candidates, r))
    return (found, len(refs))


def status_from_terminus(found, total) -> tuple:
    if found is None or total == 0:
        return "UNKNOWN", "libellés de terminus non comparables"
    if found == total:
        return "MATCH", f"numéro identique et {found}/{total} terminus concordants (libellés)"
    if found > 0:
        return "MISMATCH", f"numéro identique mais {found}/{total} terminus concordant(s) seulement"
    return "MISMATCH", f"numéro identique mais aucun terminus concordant ({total} comparés)"


# ----------------------------------------------------------------------------
# Analyse d'un flux
# ----------------------------------------------------------------------------

def analyze_feed(network: str, zip_path: str, as_of: date) -> dict:
    notes: list = []
    result = {"network": network, "file": os.path.basename(zip_path), "notes": notes}
    zf = zipfile.ZipFile(zip_path)
    infos = zf.infolist()
    result["zip_entries"] = [
        {"name": i.filename, "size": i.file_size, "compressed": i.compress_size,
         "mtime": datetime(*i.date_time).isoformat(timespec="seconds")}
        for i in infos
    ]
    result["files_present"] = [i.filename for i in infos]
    result["files_absent"] = [f for f in GTFS_FILES if f not in zf.namelist()]

    counts = {}

    # --- petites tables -----------------------------------------------------
    _, agency = read_table(zf, "agency.txt", notes)
    _, routes = read_table(zf, "routes.txt", notes)
    _, stops = read_table(zf, "stops.txt", notes)
    _, trips = read_table(zf, "trips.txt", notes)
    _, calendar = read_table(zf, "calendar.txt", notes)
    _, calendar_dates = read_table(zf, "calendar_dates.txt", notes)
    _, fare_attributes = read_table(zf, "fare_attributes.txt", notes)
    _, frequencies = read_table(zf, "frequencies.txt", notes)
    _, transfers = read_table(zf, "transfers.txt", notes)
    _, feed_info = read_table(zf, "feed_info.txt", notes)

    for nm, tbl in (("agency", agency), ("routes", routes), ("stops", stops), ("trips", trips),
                    ("calendar", calendar), ("calendar_dates", calendar_dates),
                    ("fare_attributes", fare_attributes), ("frequencies", frequencies),
                    ("transfers", transfers), ("feed_info", feed_info)):
        counts[nm] = len(tbl) if nm + ".txt" in zf.namelist() else None

    # --- shapes (compte + nb de shape_id) -----------------------------------
    shape_ids = set()
    shape_rows = 0

    def _shape_cb(row):
        nonlocal shape_rows
        shape_rows += 1
        shape_ids.add(row.get("shape_id", ""))

    read_table(zf, "shapes.txt", notes, stream_cb=_shape_cb)
    counts["shapes"] = shape_rows if "shapes.txt" in zf.namelist() else None
    counts["shapes_distinct_shape_id"] = len(shape_ids) if shape_ids else None

    # --- fare_rules (flux volumineux : comptage en streaming) ---------------
    fare_rules_rows = 0
    fare_rules_routes = set()
    fare_rules_fares = Counter()

    def _fare_cb(row):
        nonlocal fare_rules_rows
        fare_rules_rows += 1
        fare_rules_routes.add(row.get("route_id", ""))
        fare_rules_fares[row.get("fare_id", "")] += 1

    read_table(zf, "fare_rules.txt", notes, stream_cb=_fare_cb)
    counts["fare_rules"] = fare_rules_rows if "fare_rules.txt" in zf.namelist() else None
    result["fare_rules_summary"] = {
        "distinct_route_id": len(fare_rules_routes) if fare_rules_rows else 0,
        "rows_per_fare_id": dict(sorted(fare_rules_fares.items())) if fare_rules_rows else {},
    }

    # --- stop_times (streaming : agrégats par trip) -------------------------
    trip_first = {}   # trip_id -> (seq, dep_sec, stop_id)
    trip_last = {}    # trip_id -> (seq, arr_sec, stop_id)
    trip_nstops = Counter()
    trip_seq = defaultdict(list)  # trip_id -> [(seq, stop_id)]
    st_rows = 0
    st_bad_time = 0

    def _st_cb(row):
        nonlocal st_rows, st_bad_time
        st_rows += 1
        tid = row.get("trip_id", "")
        try:
            seq = int(row.get("stop_sequence", "") or 0)
        except ValueError:
            seq = 0
        dep = hms_to_sec(row.get("departure_time", ""))
        arr = hms_to_sec(row.get("arrival_time", ""))
        if dep is None and arr is None:
            st_bad_time += 1
        sid = row.get("stop_id", "")
        trip_nstops[tid] += 1
        trip_seq[tid].append((seq, sid))
        f = trip_first.get(tid)
        if f is None or seq < f[0]:
            trip_first[tid] = (seq, dep if dep is not None else arr, sid)
        l = trip_last.get(tid)
        if l is None or seq > l[0]:
            trip_last[tid] = (seq, arr if arr is not None else dep, sid)

    read_table(zf, "stop_times.txt", notes, stream_cb=_st_cb)
    counts["stop_times"] = st_rows if "stop_times.txt" in zf.namelist() else None
    if st_bad_time:
        notes.append(f"stop_times.txt: {st_bad_time} ligne(s) sans heure exploitable (arrêts non horodatés)")

    stop_name = {s.get("stop_id", ""): s.get("stop_name", "") for s in stops}

    # contrôle de cohérence stop_lat / stop_lon (l'ordre des colonnes diffère
    # entre flux : AFTU/DDD écrivent stop_lon avant stop_lat)
    lat_ok = lon_ok = lat_bad = 0
    for s in stops:
        try:
            la = float(s.get("stop_lat", ""))
            lo = float(s.get("stop_lon", ""))
        except ValueError:
            continue
        if 12.0 <= la <= 17.0 and -18.0 <= lo <= -16.0:
            lat_ok += 1
        else:
            lat_bad += 1
    result["stops_coord_check"] = {
        "dans_emprise_dakar_(lat 12..17, lon -18..-16)": lat_ok,
        "hors_emprise": lat_bad,
        "header_order": [h for h in (next(csv.reader([_decode(zf.open('stops.txt').read()).split('\n')[0]])) if 'stops.txt' in zf.namelist() else [])],
    }
    if lat_bad:
        notes.append(f"stops.txt: {lat_bad} arrêt(s) hors emprise Dakar (coordonnées suspectes)")

    # --- calendrier / validité ---------------------------------------------
    service_days = {}
    cal_min = cal_max = None
    for c in calendar:
        days = [d for d in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday") if c.get(d) == "1"]
        sd, ed = parse_yyyymmdd(c.get("start_date", "")), parse_yyyymmdd(c.get("end_date", ""))
        service_days[c.get("service_id", "")] = {
            "days": days, "start_date": c.get("start_date", ""), "end_date": c.get("end_date", ""),
        }
        if sd and (cal_min is None or sd < cal_min):
            cal_min = sd
        if ed and (cal_max is None or ed > cal_max):
            cal_max = ed
    cd_min = cd_max = None
    cd_added = Counter()
    cd_removed = Counter()
    for c in calendar_dates:
        d = parse_yyyymmdd(c.get("date", ""))
        if d is None:
            continue
        if cd_min is None or d < cd_min:
            cd_min = d
        if cd_max is None or d > cd_max:
            cd_max = d
        if c.get("exception_type") == "1":
            cd_added[c.get("service_id", "")] += 1
        elif c.get("exception_type") == "2":
            cd_removed[c.get("service_id", "")] += 1
    # services uniquement définis par calendar_dates (cas BRT)
    for sid in set(list(cd_added) + list(cd_removed)):
        if sid not in service_days:
            service_days[sid] = {"days": [], "start_date": "", "end_date": "",
                                 "defined_only_in_calendar_dates": True,
                                 "dates_added": cd_added.get(sid, 0), "dates_removed": cd_removed.get(sid, 0)}
    valid_from = min([d for d in (cal_min, cd_min) if d], default=None)
    valid_to = max([d for d in (cal_max, cd_max) if d], default=None)
    if valid_from is None or valid_to is None:
        validity = "UNKNOWN"
    elif valid_to < as_of:
        validity = "HISTORICAL"
    elif valid_from > as_of:
        validity = "FUTURE"
    else:
        validity = "CURRENT"
    result["calendar"] = {
        "services": service_days,
        "calendar_span": [cal_min.isoformat() if cal_min else None, cal_max.isoformat() if cal_max else None],
        "calendar_dates_span": [cd_min.isoformat() if cd_min else None, cd_max.isoformat() if cd_max else None],
        "calendar_dates_added_by_service": dict(cd_added),
        "calendar_dates_removed_by_service": dict(cd_removed),
        "valid_from": valid_from.isoformat() if valid_from else None,
        "valid_to": valid_to.isoformat() if valid_to else None,
        "as_of": as_of.isoformat(),
        "validity": validity,
    }

    # --- agences / tarifs ----------------------------------------------------
    result["agency"] = agency
    result["fare_attributes"] = fare_attributes
    result["feed_info"] = feed_info
    result["has_frequencies_txt"] = "frequencies.txt" in zf.namelist()

    # --- routes ---------------------------------------------------------------
    trips_by_route = defaultdict(list)
    for t in trips:
        trips_by_route[t.get("route_id", "")].append(t)

    route_rows = []
    sched_rows = []
    for r in routes:
        rid = r.get("route_id", "")
        rtrips = trips_by_route.get(rid, [])
        short = r.get("route_short_name", "")
        long_ = r.get("route_long_name", "")
        # numéro de ligne : UNIQUEMENT depuis les champs du flux
        num_short = None
        m = re.match(r"^[AD](\d+)", short)
        if m:
            num_short = m.group(1)
        num_id = None
        m = re.match(r"^(?:AFTU|DDD)_(\d+)", rid)
        if m:
            num_id = m.group(1)
        num_long = None
        m = re.match(r"^(?:AFTU|DDD)_(\d+)", long_)
        if m:
            num_long = m.group(1)
        nums = {str(int(x)) for x in (num_short, num_id, num_long) if x is not None}
        if network in ("AFTU", "DDD"):
            if len(nums) == 1:
                line_number = nums.pop()
                number_status = "COHERENT (route_short_name = route_id = route_long_name)"
            elif len(nums) > 1:
                line_number = num_short and str(int(num_short)) or ""
                number_status = f"INCOHERENT short={num_short} id={num_id} long={num_long}"
            else:
                line_number = ""
                number_status = "ABSENT"
        else:
            line_number = short
            number_status = "route_short_name tel quel"

        service_counter = Counter(t.get("service_id", "") for t in rtrips)
        n_without_st = sum(1 for t in rtrips if t.get("trip_id", "") not in trip_first)
        # Clé de direction : direction_id si renseigné ; sinon (cas gtfs_BRT où
        # direction_id est vide) le premier arrêt du trip, afin de ne pas
        # mélanger les deux sens dans le calcul de la fréquence observée.
        def _dir_key(t):
            d = t.get("direction_id", "")
            if d != "":
                return d
            f = trip_first.get(t.get("trip_id", ""))
            return "orig=" + (stop_name.get(f[2], f[2]) if f else "?")
        for t in rtrips:
            t["_dir_key"] = _dir_key(t)
        dir_counter = Counter(t["_dir_key"] for t in rtrips)
        distinct_stops = set()
        per_dir = {}
        first_all = last_all = None
        for t in rtrips:
            tid = t.get("trip_id", "")
            for _, sid in trip_seq.get(tid, []):
                distinct_stops.add(sid)
            f = trip_first.get(tid)
            l = trip_last.get(tid)
            if f and f[1] is not None:
                first_all = f[1] if first_all is None else min(first_all, f[1])
            if l and l[1] is not None:
                last_all = l[1] if last_all is None else max(last_all, l[1])
        # motif dominant par direction
        for d in sorted(dir_counter):
            dtrips = [t for t in rtrips if t["_dir_key"] == d]
            patterns = Counter()
            for t in dtrips:
                seq = tuple(sid for _, sid in sorted(trip_seq.get(t.get("trip_id", ""), [])))
                patterns[seq] += 1
            dom, dom_n = (patterns.most_common(1)[0] if patterns else ((), 0))
            headsigns = Counter(t.get("trip_headsign", "") for t in dtrips)
            # libellé porté par trip_id / shape_id (AFTU/DDD n'ont pas de headsign) :
            # observation sur les données, il désigne le TERMINUS DE DÉPART de la
            # direction (ex. AFTU_1_HLM-GR-YOFF_1 part de HLM Grand Yoff)
            label = ""
            if dtrips:
                tid0 = dtrips[0].get("trip_id", "")
                m = re.match(r"^(?:AFTU|DDD)_\d+[A-Za-z]?_(.+?)(?:_(?:FULL|LAV|SAMEDI|DIMANCHE))?_\d+$", tid0)
                if m:
                    label = m.group(1)
            per_dir[d] = {
                "trips": len(dtrips),
                "dominant_pattern_trips": dom_n,
                "distinct_patterns": len(patterns),
                "origin_stop_id": dom[0] if dom else "",
                "origin_stop_name": stop_name.get(dom[0], "") if dom else "",
                "destination_stop_id": dom[-1] if dom else "",
                "destination_stop_name": stop_name.get(dom[-1], "") if dom else "",
                "stops_in_dominant_pattern": len(dom),
                "trip_headsign": headsigns.most_common(1)[0][0] if headsigns else "",
                "trip_id_label": label,
            }
            # horaires par service et direction (fréquence OBSERVÉE)
            for sid in sorted(service_counter):
                deps = sorted(
                    trip_first[t.get("trip_id", "")][1]
                    for t in dtrips
                    if t.get("service_id", "") == sid and t.get("trip_id", "") in trip_first and trip_first[t.get("trip_id", "")][1] is not None
                )
                if not deps:
                    continue
                gaps = [(b - a) / 60.0 for a, b in zip(deps, deps[1:]) if b > a]
                days = service_days.get(sid, {}).get("days", [])
                sched_rows.append({
                    "network": network, "route_id": rid, "line_number": line_number,
                    "route_short_name": short, "direction_id": d,
                    "origine": per_dir[d]["origin_stop_name"],
                    "destination": per_dir[d]["destination_stop_name"],
                    "trip_id_label_depart": per_dir[d]["trip_id_label"] or per_dir[d]["trip_headsign"],
                    "service_id": sid, "service_days": "/".join(days) if days else ("calendar_dates seulement" if service_days.get(sid, {}).get("defined_only_in_calendar_dates") else ""),
                    "trips": len(deps),
                    "premier_depart": sec_to_hms(deps[0]), "dernier_depart": sec_to_hms(deps[-1]),
                    "headway_obs_median_min": round(statistics.median(gaps), 1) if gaps else "",
                    "headway_obs_min_min": round(min(gaps), 1) if gaps else "",
                    "headway_obs_max_min": round(max(gaps), 1) if gaps else "",
                    "frequence_declaree": "AUCUNE (pas de frequencies.txt)",
                })
        route_rows.append({
            "network": network,
            "route_id": rid,
            "route_short_name": short,
            "route_long_name": long_,
            "agency_id": r.get("agency_id", ""),
            "route_type": r.get("route_type", ""),
            "line_number": line_number,
            "line_number_status": number_status,
            "direction_ids": "/".join(sorted(dir_counter)),
            "directions": per_dir,
            "stops_count_distinct": len(distinct_stops),
            "trips_count": len(rtrips),
            "service_ids": dict(service_counter),
            "premier_depart": sec_to_hms(first_all),
            "dernier_depart": sec_to_hms(last_all),
            "trips_without_stop_times": n_without_st,
            "schedule_status": (
                "NO_SCHEDULE (aucun trip sans stop_times)" if not rtrips else
                "NO_STOP_TIMES (trips déclarés mais aucun horaire)" if first_all is None else
                ("SCHEDULE_PRESENT_" + validity + (f" (partiel : {n_without_st} trips sans stop_times)" if n_without_st else ""))
            ),
        })

    total_without = sum(r["trips_without_stop_times"] for r in route_rows)
    if total_without:
        detail = ", ".join(f"{r['route_id']}={r['trips_without_stop_times']}" for r in route_rows if r["trips_without_stop_times"])
        notes.append(f"trips.txt: {total_without} trip(s) sans aucune ligne dans stop_times.txt (horaire absent) — {detail}")
    result["counts"] = counts
    result["routes"] = route_rows
    result["schedules"] = sched_rows
    result["stops_sample"] = stops[:3]
    return result


# ----------------------------------------------------------------------------
# Références externes (lecture seule)
# ----------------------------------------------------------------------------

def load_dakar_bus():
    with open(DAKAR_NETWORK, encoding="utf-8") as fh:
        d = json.load(fh)
    out = {"AFTU": {}, "DDD": {}, "OTHER": []}
    for r in d.get("routes", []):
        op = r.get("operator_id", "")
        sn = r.get("short_name", "")
        m = re.match(r"^(AFTU|DDD)\s+(\d+)$", sn)
        if m and op in ("aftu", "ddd"):
            out[m.group(1)][str(int(m.group(2)))] = r
        else:
            out["OTHER"].append(r)
    return out, d.get("dataset_meta", {})


def load_referentiel():
    """Transcrit les tableaux A.2 (AFTU, source S-A1 aftu-senegal.org) et C.2
    (DDD, sources S-D1/S-D2 demdikk.sn) du référentiel canonique du 2026-09-25."""
    ref = {"AFTU": {}, "DDD": {}}
    if not os.path.exists(REFERENTIEL):
        return ref, False
    with open(REFERENTIEL, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"^\|\s*`AFTU (\d+)`\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|", line)
            if m:
                ref["AFTU"][str(int(m.group(1)))] = {
                    "official_name": m.group(2).strip(), "origin": m.group(3).strip(),
                    "destination": m.group(4).strip(), "source": "S-A1 https://aftu-senegal.org/infos-pratiques/ (vérifié 2026-09-25)",
                }
                continue
            m = re.match(r"^\|\s*`DDD ([0-9A-Z ]+?)`\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|", line)
            if m:
                key = m.group(1).strip()
                ref["DDD"][key] = {
                    "category": m.group(2).strip(), "official_name": m.group(3).strip(),
                    "origin_destination": m.group(4).strip(),
                    "source": "S-D1 https://demdikk.sn/info-voyageurs/ + S-D2 https://demdikk.sn/reseau-urbain-dakar/ (vérifié 2026-09-25)",
                }
    return ref, True


# ----------------------------------------------------------------------------
# Comparaisons
# ----------------------------------------------------------------------------

def gtfs_candidates(routes_for_number: list) -> list:
    """Libellés de terminus portés par le flux pour un numéro : segments du
    route_long_name (après le préfixe AFTU_n_/DDD_nn_), libellés de trip_id et
    premier/dernier arrêt des motifs dominants."""
    out = []
    for x in routes_for_number:
        body = re.sub(r"^(?:AFTU|DDD)_\d+[A-Za-z]?_?", "", x["route_long_name"])
        out.extend([p for p in body.split("_") if p])
        for v in x["directions"].values():
            out.extend([v.get("origin_stop_name", ""), v.get("destination_stop_name", ""), v.get("trip_id_label", "")])
    return [o for o in out if o]


def compare(network: str, feed: dict, dakar: dict, ref: dict) -> list:
    rows = []
    gtfs_by_num = {}
    for r in feed["routes"]:
        if r["line_number"]:
            gtfs_by_num.setdefault(r["line_number"], []).append(r)
    db = dakar.get(network, {})
    refn = ref.get(network, {})

    def sort_key(k):
        m = re.match(r"^(\d+)(.*)$", k)
        return (int(m.group(1)), m.group(2)) if m else (10 ** 9, k)

    all_nums = sorted(set(gtfs_by_num) | set(db) | set(refn), key=sort_key)
    for n in all_nums:
        g = gtfs_by_num.get(n, [])
        b = db.get(n)
        o = refn.get(n)
        g_label = "; ".join(
            f"{x['route_id']} [{x['route_short_name']}] {x['route_long_name']} — " + " / ".join(
                f"dir{d}: {v['origin_stop_name']} → {v['destination_stop_name']}" for d, v in x["directions"].items())
            for x in g)
        o_label = (o.get("official_name") or o.get("origin_destination")) if o else ""
        # terminus officiels : libellé S-A1/S-D1 ET, pour DDD, itinéraire S-D2
        # (les deux sont testés, le meilleur résultat est retenu, car le
        # référentiel officiel comporte lui-même des entrées CONFLICTING)
        o_terminus_sets = []
        if o:
            if o.get("origin") or o.get("destination"):
                o_terminus_sets.append([o.get("origin", ""), o.get("destination", "")])
            if o.get("official_name"):
                o_terminus_sets.append(split_terminus(re.sub(r"^[^:]*:\s*", "", o["official_name"])))
            if o.get("origin_destination") and o["origin_destination"] not in ("", "—"):
                o_terminus_sets.append(split_terminus(o["origin_destination"]))
        o_terminus_sets = [t for t in o_terminus_sets if t]
        o_terminus = o_terminus_sets[0] if o_terminus_sets else []
        b_label = b.get("long_name", "") if b else ""
        b_terminus = split_terminus(b_label) if b else []
        g_cands = gtfs_candidates(g)

        # --- PassBi GTFS ↔ Dakar Bus (vocabulaire imposé) ---
        if g and b:
            found, total = compare_terminus(g_cands, b_terminus)
            status_db, status_db_detail = status_from_terminus(found, total)
        elif g and not b:
            status_db, status_db_detail = "MISSING_IN_DAKAR_BUS", "numéro présent dans le flux, absent du référentiel Dakar Bus"
        elif b and not g:
            status_db, status_db_detail = "MISSING_IN_SOURCE", "numéro Dakar Bus absent du flux PassBi"
        else:
            status_db, status_db_detail = "UNKNOWN", "numéro seulement dans la liste officielle"

        # --- PassBi GTFS ↔ liste officielle exploitant (2026-09-25) ---
        base = re.match(r"^(\d+)", n)
        base = base.group(1) if base else None
        if g and o:
            best = None
            for ts in o_terminus_sets:
                found, total = compare_terminus(g_cands, ts)
                if found is not None and total and (best is None or found / total > best[0] / best[1]):
                    best = (found, total)
            found, total = best if best else (None, 0)
            status_off, status_off_detail = status_from_terminus(found, total)
        elif g and not o:
            status_off = "MISSING_IN_OFFICIAL_LIST"
            variants = [k for k in refn if re.match(rf"^{re.escape(n)}[A-Z]$", k)]
            status_off_detail = ("numéro présent dans le flux PassBi (2022-2023) mais absent de la liste officielle 2026-09-25"
                                 + (f" ; la liste officielle publie les variantes {', '.join(sorted(variants))} — correspondance UNKNOWN" if variants else ""))
        elif o and not g:
            status_off = "MISSING_IN_SOURCE"
            status_off_detail = "numéro officiel 2026 absent du flux PassBi (2022-2023)"
            if base and base != n and base in gtfs_by_num:
                status_off_detail += f" ; le flux contient le numéro de base {base} sans suffixe — correspondance UNKNOWN"
        else:
            status_off, status_off_detail = "UNKNOWN", ""

        # --- liste officielle ↔ Dakar Bus ---
        if o and b:
            found, total = compare_terminus([o_label] + sum(o_terminus_sets, []), b_terminus)
            status_ob, _ = status_from_terminus(found, total)
        elif o and not b:
            status_ob = "MISSING_IN_DAKAR_BUS"
        elif b and not o:
            status_ob = "MISSING_IN_SOURCE"
        else:
            status_ob = "UNKNOWN"

        rows.append({
            "network": network, "line_number": n,
            "passbi_gtfs": g_label, "passbi_gtfs_trips": sum(x["trips_count"] for x in g) if g else "",
            "passbi_gtfs_stops": sum(x["stops_count_distinct"] for x in g) if g else "",
            "official_2026": o_label, "dakar_bus": b_label,
            "dakar_bus_id": b.get("id", "") if b else "", "dakar_bus_stops": len(b.get("stops", [])) if b else "",
            "dakar_bus_data_status": b.get("data_status", "") if b else "",
            "dakar_bus_schedule_status": b.get("schedule_status", "") if b else "",
            "status_passbi_vs_dakar_bus": status_db, "detail_passbi_vs_dakar_bus": status_db_detail,
            "status_passbi_vs_official": status_off, "detail_passbi_vs_official": status_off_detail,
            "status_official_vs_dakar_bus": status_ob,
            "stops_comparison": (f"flux {sum(x['stops_count_distinct'] for x in g)} arrêts géolocalisés vs Dakar Bus {len(b.get('stops', []))} arrêts (coordonnées {b.get('data_status','')}) — ordre des arrêts : UNKNOWN (granularités incomparables, aucun rapprochement géométrique effectué)") if (g and b) else "",
            "schedule_comparison": ("PassBi: horaires HISTORIQUES (calendrier 2022-01-01→2023-12-31) ; Dakar Bus: " + (b.get("schedule_status", "UNKNOWN") if b else "ligne absente")) if g else ("aucun horaire source ; Dakar Bus: " + (b.get("schedule_status", "UNKNOWN") if b else "")),
        })
    return rows


# ----------------------------------------------------------------------------
# Sorties
# ----------------------------------------------------------------------------

def write_csv(path, rows, fields=None):
    if not rows:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write("")
        return
    fields = fields or list(rows[0].keys())
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: (json.dumps(v, ensure_ascii=False) if isinstance(v, (dict, list)) else v) for k, v in r.items()})


def md_table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c).replace("|", "\\|").replace("\n", " ") for c in r) + " |")
    return "\n".join(out)


def routes_md(feed: dict) -> str:
    rows = []
    for r in feed["routes"]:
        dirs = r["directions"]
        for d in sorted(dirs) or [""]:
            v = dirs.get(d, {})
            rows.append([
                r["route_id"], r["route_short_name"], r["route_long_name"], r["agency_id"], d,
                r["line_number"], v.get("origin_stop_name", ""), v.get("destination_stop_name", ""),
                v.get("trip_id_label", "") or v.get("trip_headsign", ""),
                v.get("stops_in_dominant_pattern", ""), v.get("trips", ""),
                ", ".join(f"{k}={n}" for k, n in sorted(r["service_ids"].items())),
                r["premier_depart"], r["dernier_depart"], r["schedule_status"],
            ])
    return md_table(["route_id", "route_short_name", "route_long_name", "agency_id", "direction_id", "n° (champ flux)",
                     "origine (1er arrêt motif dominant)", "destination (dernier arrêt)", "libellé trip_id (terminus de départ) / headsign",
                     "arrêts (motif dominant)", "trips (direction)", "service_ids (trips, toute direction)",
                     "premier départ", "dernier départ", "schedule_status"], rows)


def schedules_md(feed: dict) -> str:
    rows = [[s["route_id"], s["line_number"], s["direction_id"], f'{s["origine"]} → {s["destination"]}', s["service_id"], s["service_days"],
             s["trips"], s["premier_depart"], s["dernier_depart"], s["headway_obs_median_min"], s["headway_obs_min_min"],
             s["headway_obs_max_min"], s["frequence_declaree"]] for s in feed["schedules"]]
    return md_table(["route_id", "n°", "dir", "origine → destination (motif dominant)", "service_id", "jours", "trips", "premier départ",
                     "dernier départ", "fréq. observée médiane (min)", "min", "max", "fréq. déclarée"], rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--as-of", default="2026-09-26")
    args = ap.parse_args()
    as_of = date.fromisoformat(args.as_of)
    os.makedirs(REPORTS_DIR, exist_ok=True)

    feeds = {}
    for network, fname in FEEDS:
        p = os.path.join(SOURCE_DIR, fname)
        if not os.path.exists(p):
            print(f"[absent] {p}", file=sys.stderr)
            continue
        print(f"[analyse] {network} ← {fname}", file=sys.stderr)
        feeds[network] = analyze_feed(network, p, as_of)

    dakar, meta = load_dakar_bus()
    ref, ref_ok = load_referentiel()

    summary = {"as_of": as_of.isoformat(), "generated_by": "audit/external-feeds/analyze_feeds.py",
               "dakar_network_json_read_only": {"path": os.path.relpath(DAKAR_NETWORK, REPO), "audited_at": meta.get("audited_at"), "schema": meta.get("schema")},
               "referentiel_officiel_charge": ref_ok, "feeds": {}}
    for network, f in feeds.items():
        summary["feeds"][network] = {
            "file": f["file"], "counts": f["counts"], "files_present": f["files_present"], "files_absent": f["files_absent"],
            "zip_entries": f["zip_entries"], "agency": f["agency"], "fare_attributes": f["fare_attributes"],
            "fare_rules_summary": f["fare_rules_summary"], "calendar": f["calendar"], "has_frequencies_txt": f["has_frequencies_txt"],
            "stops_coord_check": f["stops_coord_check"], "notes": f["notes"],
            "routes_count": len(f["routes"]),
            "line_numbers": sorted({r["line_number"] for r in f["routes"] if r["line_number"]}, key=lambda x: (len(x), x)),
        }
        write_csv(os.path.join(REPORTS_DIR, f"routes_{network}.csv"), f["routes"])
        write_csv(os.path.join(REPORTS_DIR, f"schedules_{network}.csv"), f["schedules"])
        with open(os.path.join(REPORTS_DIR, f"routes_{network}.md"), "w", encoding="utf-8") as fh:
            fh.write(f"# Lignes {network} — flux `{f['file']}` (PassBi, SOURCE_APPLICATION) — validité {f['calendar']['validity']} au {as_of}\n\n")
            fh.write("Numéro de ligne = champ du flux (route_short_name croisé route_id / route_long_name). Origine/destination = premier/dernier arrêt du motif d'arrêts dominant de la direction. Aucune donnée inventée.\n\n")
            fh.write(routes_md(f) + "\n")
        with open(os.path.join(REPORTS_DIR, f"schedules_{network}.md"), "w", encoding="utf-8") as fh:
            fh.write(f"# Horaires {network} — flux `{f['file']}` — fréquence OBSERVÉE (stop_times.txt), aucune fréquence déclarée dans le flux — validité {f['calendar']['validity']}\n\n")
            fh.write(schedules_md(f) + "\n")

    comparisons = {}
    for network in ("AFTU", "DDD"):
        if network in feeds:
            comparisons[network] = compare(network, feeds[network], dakar, ref)
            write_csv(os.path.join(REPORTS_DIR, f"comparison_{network}.csv"), comparisons[network])
            with open(os.path.join(REPORTS_DIR, f"comparison_{network}.md"), "w", encoding="utf-8") as fh:
                fh.write(f"# Comparaison {network} — PassBi GTFS (SOURCE_APPLICATION, 2022-2023) ↔ liste officielle exploitant 2026-09-25 ↔ Dakar Bus (lecture seule)\n\n")
                fh.write("Clé de comparaison = numéro de ligne porté par le champ source. La colonne « terminus » est une comparaison INDICATIVE de libellés (jetons communs) et ne fonde aucune identité.\n\n")
                fh.write(md_table(["n°", "PassBi GTFS (route_id [short] ; origine → destination)", "trips", "liste officielle 2026", "Dakar Bus (long_name)", "Dakar Bus stops",
                                   "PassBi ↔ Dakar Bus", "PassBi ↔ officiel", "officiel ↔ Dakar Bus", "horaires"],
                                  [[c["line_number"], c["passbi_gtfs"], c["passbi_gtfs_trips"], c["official_2026"], c["dakar_bus"], c["dakar_bus_stops"],
                                    c["status_passbi_vs_dakar_bus"], c["status_passbi_vs_official"], c["status_official_vs_dakar_bus"], c["schedule_comparison"]]
                                   for c in comparisons[network]]) + "\n")
            summary["feeds"][network]["comparison_status_counts"] = {
                "passbi_vs_dakar_bus": dict(Counter(c["status_passbi_vs_dakar_bus"] for c in comparisons[network])),
                "passbi_vs_official": dict(Counter(c["status_passbi_vs_official"] for c in comparisons[network])),
                "official_vs_dakar_bus": dict(Counter(c["status_official_vs_dakar_bus"] for c in comparisons[network])),
            }

    # autres identités Dakar Bus (Tata, NEW xx, BRT, TER) : hors clé numérique AFTU/DDD
    summary["dakar_bus_routes_not_comparable_by_number"] = [
        {"id": r.get("id"), "operator_id": r.get("operator_id"), "short_name": r.get("short_name"), "long_name": r.get("long_name")} for r in dakar["OTHER"]
    ]

    with open(os.path.join(REPORTS_DIR, "feed_summary.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=2, default=str)

    # résumé markdown
    lines = [f"# Synthèse des flux analysés (as-of {as_of})", ""]
    lines.append(md_table(["Réseau", "Fichier", "agency", "routes", "stops", "trips", "stop_times", "calendar", "calendar_dates", "shapes (pts / shape_id)", "fare_attributes", "fare_rules", "frequencies", "valid_from", "valid_to", "validité"],
                          [[n, s["file"], s["counts"].get("agency"), s["counts"].get("routes"), s["counts"].get("stops"), s["counts"].get("trips"), s["counts"].get("stop_times"),
                            s["counts"].get("calendar"), s["counts"].get("calendar_dates"), f"{s['counts'].get('shapes')} / {s['counts'].get('shapes_distinct_shape_id')}",
                            s["counts"].get("fare_attributes"), s["counts"].get("fare_rules"), "OUI" if s["has_frequencies_txt"] else "NON (absent)",
                            s["calendar"]["valid_from"], s["calendar"]["valid_to"], s["calendar"]["validity"]] for n, s in summary["feeds"].items()]))
    lines.append("")
    for n, s in summary["feeds"].items():
        lines.append(f"## {n}")
        lines.append(f"- agences : {json.dumps(s['agency'], ensure_ascii=False)}")
        lines.append(f"- services : {json.dumps(s['calendar']['services'], ensure_ascii=False)}")
        lines.append(f"- numéros de ligne présents ({len(s['line_numbers'])}) : {', '.join(s['line_numbers'])}")
        lines.append(f"- fichiers absents : {', '.join(s['files_absent']) or 'aucun'}")
        lines.append(f"- contrôle coordonnées : {json.dumps(s['stops_coord_check'], ensure_ascii=False)}")
        for note in s["notes"]:
            lines.append(f"- note qualité : {note}")
        if "comparison_status_counts" in s:
            lines.append(f"- comparaison : {json.dumps(s['comparison_status_counts'], ensure_ascii=False)}")
        lines.append("")
    with open(os.path.join(REPORTS_DIR, "feed_summary.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(json.dumps({n: {"routes": s["routes_count"], "validity": s["calendar"]["validity"], "valid_from": s["calendar"]["valid_from"], "valid_to": s["calendar"]["valid_to"], "counts": s["counts"]} for n, s in summary["feeds"].items()}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
