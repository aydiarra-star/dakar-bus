#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LOT 4.5 renforcé — Registre public des lignes + Registre horaire commun.

Ne modifie aucun fichier applicatif. N'invente ni horaire exact, ni temps réel.

Produit :
  data/transit/validated/public_routes.json   (socle officiel, provenance par champ)
  data/transit/validated/schedule_registry.json (structure horaire, fréquences vs horaires)

Usage : python3 data/transit/tools/build_public_registry_4_5.py
"""
import json
import os
import csv

AUDIT_DATE = "2026-09-27"
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, ".."))
SRC = os.path.abspath(os.path.join(T, "..", "..", "flutter-src", "assets", "data", "dakar_network.json"))

from transit_sources import (
    AFTU_OFFICIAL, DDD_OFFICIAL, DDD_SECTION,
    termini, AUDIT_DATE as _AD, S_TER_OP, S_TER_PLAN, S_DDD_OP, S_BRT_OP, S_BRT3_OP,
    S_AFTU_OP, S_SENEGO, S_TERSEN, S_PASSBI, DATE_PASSBI, DATE_AFTU_OP, DATE_DDD_OP, DATE_TER_OP, DATE_TERSEN,
)

# Dates sources
DATE_BRT_OP = None
DATE_BRT3_OP = "2026-09-24"

def load(rel):
    with open(os.path.join(T, rel), encoding="utf-8") as f:
        return json.load(f)

L_ter_map = load("validated/structure/ter_stop_mapping.json")
L_brt = load("validated/structure/brt_route_structure.json")
L_ddd = load("validated/structure/ddd_routes.json")
L_ter_sched = load("validated/structure/ter_schedule.json")

PROJ = json.load(open(SRC, encoding="utf-8"))
proj_stops = {s["id"]: s for s in PROJ["stops"]}

# ------------------------------------------------------------------ helpers
def wj(path, obj):
    full = os.path.join(T, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")

def prov(identity, structure, schedule, realtime, src_level=""):
    # Common provenance template, overridden per entry
    return {
        "identity": {"status": identity, "note": "voir champ source"},
        "structure": {"status": structure, "note": "arrêts vérifiés ou non"},
        "schedule": {"status": schedule, "note": "horaire exact vs fréquence"},
        "realtime": {"status": realtime, "note": "temps réel nécessite flux frais"},
    }

# ------------------------------------------------------------------ public_routes
routes = []

# TER — 1 route, 13 stops, structure confirmée
for m in []:  # placeholder to keep structure
    pass

ter_entry = {
    "route_id": "ter_dakar_diamniadio",
    "route_short_name": "TER",
    "route_long_name": "Dakar ↔ Diamniadio",
    "operator": "SETER",
    "network": "TER",
    "origin": "Dakar",
    "destination": "Diamniadio",
    "direction": "0/1 (Dakar→Diamniadio / Diamniadio→Dakar)",
    "identity_status": "CONFIRMED",
    "structure_status": "CONFIRMED",
    "schedule_status": "ESTIMATED",
    "realtime_status": "UNKNOWN",
    "source": "https://www.terdakar.sn/ + https://www.terdakar.sn/acceder-au-plan-de-la-ligne/",
    "source_type": "OFFICIAL_OPERATOR",
    "source_url": S_TER_OP,
    "date_source": DATE_TER_OP,
    "date_verified": AUDIT_DATE,
    "confidence": "HIGH",
    "verification_note": "13/13 gares dans le même ordre, confirmées par 3 sources 2026 (PassBi + senego.com + ter-senegal.sn). Fréquence 10 min semaine / 20 min dimanche publiée par l'opérateur, mais aucune heure par station publiée : schedule = ESTIMATED, jamais SCHEDULED.",
    "provenance_by_field": {
        "route_id": {"source": S_TER_PLAN, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED", "note": "ligne Dakar ↔ Diamniadio publiée"},
        "origin_destination": {"source": S_TER_PLAN, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED", "note": "terminus Dakar et Diamniadio"},
        "stops": {"source": "PassBi (SETER) + senego.com + ter-senegal.sn", "source_type": "HYBRID", "source_url": S_SENEGO, "date_verified": AUDIT_DATE, "status": "CONFIRMED", "note": "13/13, écart moyen 85 m"},
        "schedule": {"source": S_TER_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "ESTIMATED", "note": "fréquence publiée, pas d'heure par arrêt"},
        "realtime": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN", "note": "aucun flux temps réel exploitable"},
    }
}
routes.append(ter_entry)

# BRT — 3 routes
b1 = [r for r in L_brt["routes"] if r["route_id"] == "brt_b1"][0]
b2 = [r for r in L_brt["routes"] if r["route_id"] == "brt_b2"][0]
b3 = L_brt["b3_identity_only"]

for brt_id, origin, dest, identity, structure, schedule, provenance_stops in [
    ("brt_b1", b1["origin"], b1["destination"], "CONFIRMED", "PERSISTENT", "ESTIMATED",
     {"source": S_BRT_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "PERSISTENT", "note": "21 stations PassBi retrouvées dans le réseau actuel à 23"}),
    ("brt_b2", b2["origin"], b2["destination"], "CONFIRMED", "CONFIRMED", "ESTIMATED",
     {"source": S_BRT_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED", "note": "7/7 stations, même ordre"}),
    ("brt_b3", "Préfecture de Guédiawaye", "Papa Gueye Fall", "NEW", "UNCONFIRMED", "UNKNOWN",
     {"source": "UNKNOWN", "source_type": "UNKNOWN", "date_verified": AUDIT_DATE, "status": "UNKNOWN", "note": "B3 hors PassBi, structure non vérifiée au-delà des 7 noms officiels"}),
]:
    source_url = S_BRT3_OP if brt_id == "brt_b3" else S_BRT_OP
    date_source = DATE_BRT3_OP if brt_id == "brt_b3" else DATE_BRT_OP
    routes.append({
        "route_id": brt_id,
        "route_short_name": brt_id.replace("brt_", "B").upper(),
        "route_long_name": "%s ↔ %s" % (origin, dest),
        "operator": "SunuBRT",
        "network": "BRT",
        "origin": origin,
        "destination": dest,
        "direction": None,
        "identity_status": identity,
        "structure_status": structure,
        "schedule_status": schedule,
        "realtime_status": "UNKNOWN",
        "source": source_url,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": source_url,
        "date_source": date_source,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH" if brt_id in ("brt_b1", "brt_b2") else "MEDIUM",
        "verification_note": (
            "B1 : 21 stations PassBi, 23 actuelles, les deux niveaux conservés. B2 : 7 stations confirmées."
            if brt_id == "brt_b1" else
            "B2 : 7 stations, ordre identique, fréquence 6 min (ESTIMATED, jamais horaire exact)."
            if brt_id == "brt_b2" else
            "B3 semi-express en service depuis octobre 2025, 7 stations officielles. Aucune correspondance avec B1/B2 recherchée."
        ),
        "provenance_by_field": {
            "route_id": {"source": source_url, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED" if brt_id != "brt_b3" else "NEW"},
            "origin_destination": {"source": source_url, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED" if brt_id != "brt_b3" else "NEW"},
            "stops": provenance_stops,
            "schedule": {"source": S_BRT_OP if brt_id != "brt_b3" else "UNKNOWN", "source_type": "OFFICIAL_OPERATOR" if brt_id != "brt_b3" else "UNKNOWN", "source_url": S_BRT_OP if brt_id != "brt_b3" else None, "date_verified": AUDIT_DATE, "status": schedule, "note": "fréquence 6 min, pas d'heure par arrêt" if brt_id != "brt_b3" else "aucune grille horaire publiée"},
            "realtime": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
        }
    })

# DDD — 39 codes officiels (dont 7 variantes A/B)
for code, terminus_str in sorted(DDD_OFFICIAL.items(), key=lambda x: (int(''.join(filter(str.isdigit, x[0]))), x[0])):
    o, d = termini(terminus_str)
    # DDD circulaires 18/20 : termini() retourne DIEUPPEUL/DIEUPPEUL, on restaure CENTRE-VILLE
    if code in ("18", "20") and o == d == "DIEUPPEUL":
        # Le vrai libellé est "DIEUPPEUL ↔ CENTRE-VILLE ↔ DIEUPPEUL" : on garde tel quel
        route_long = terminus_str
        origin = "DIEUPPEUL"
        destination = "CENTRE-VILLE"
    else:
        route_long = "%s ↔ %s" % (o, d)
        origin = o
        destination = d
    # statut : tous CONFIRMED côté identité car publiés par l'opérateur
    routes.append({
        "route_id": "ddd_%s" % code.lower(),
        "route_short_name": code,
        "route_long_name": route_long,
        "operator": "Dakar Dem Dikk",
        "network": "DDD",
        "origin": origin,
        "destination": destination,
        "direction": None,
        "identity_status": "CONFIRMED",
        "structure_status": "UNKNOWN",
        "schedule_status": "UNKNOWN",
        "realtime_status": "UNKNOWN",
        "source": S_DDD_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_DDD_OP,
        "date_source": DATE_DDD_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "Ligne publiée par l'opérateur (%s). Section : %s. Ne prouve ni parcours complet, ni arrêts, ni horaires." % (code, DDD_SECTION.get(code, "UNKNOWN")),
        "provenance_by_field": {
            "route_id": {"source": S_DDD_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED"},
            "origin_destination": {"source": S_DDD_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED"},
            "stops": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN", "note": "aucun arrêt actuel vérifié"},
            "schedule": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
            "realtime": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
        }
    })

# AFTU — 72 lignes officielles
for num, terminus_str in sorted(AFTU_OFFICIAL.items(), key=lambda x: int(x[0])):
    o, d = termini(terminus_str)
    routes.append({
        "route_id": "aftu_%s" % num,
        "route_short_name": num,
        "route_long_name": "%s - %s" % (o, d),
        "operator": "AFTU",
        "network": "AFTU",
        "origin": o,
        "destination": d,
        "direction": None,
        "identity_status": "CONFIRMED",
        "structure_status": "UNKNOWN",
        "schedule_status": "UNKNOWN",
        "realtime_status": "UNKNOWN",
        "source": S_AFTU_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_AFTU_OP,
        "date_source": DATE_AFTU_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "Ligne publiée par l'opérateur AFTU (LIGNE %s). Numérotation 1-5 puis 24-89 et 91 (pas de 90). Ne prouve ni arrêts, ni horaires." % num,
        "provenance_by_field": {
            "route_id": {"source": S_AFTU_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED"},
            "origin_destination": {"source": S_AFTU_OP, "source_type": "OFFICIAL_OPERATOR", "date_verified": AUDIT_DATE, "status": "CONFIRMED"},
            "stops": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN", "note": "aucun arrêt actuel vérifié"},
            "schedule": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
            "realtime": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None, "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
        }
    })

# Stats
from collections import Counter
by_network = Counter(r["network"] for r in routes)
by_identity = Counter(r["identity_status"] for r in routes)
by_structure = Counter(r["structure_status"] for r in routes)
by_schedule = Counter(r["schedule_status"] for r in routes)
by_realtime = Counter(r["realtime_status"] for r in routes)

public_routes_obj = {
    "generated_at": AUDIT_DATE,
    "lot": "4.5",
    "description": "Référentiel public des lignes — socle officiel (opérateurs) + provenance par champ. Aucun horaire exact inventé, aucun temps réel fictif.",
    "total": len(routes),
    "by_network": dict(by_network),
    "by_identity_status": dict(by_identity),
    "by_structure_status": dict(by_structure),
    "by_schedule_status": dict(by_schedule),
    "by_realtime_status": dict(by_realtime),
    "provenance_policy": "Chaque champ porte sa propre source. Une identité CONFIRMED ne signifie pas que la structure ou l'horaire sont vérifiés. Voir provenance_by_field par route.",
    "routes": routes,
}

wj("validated/public_routes.json", public_routes_obj)

# ------------------------------------------------------------------ schedule_registry
# Fréquences officielles (ESTIMATED, jamais SCHEDULED)
frequencies = [
    {
        "route_id": "ter_dakar_diamniadio",
        "service_id": "TER_WEEKDAY",
        "headway_min": 10,
        "evening_headway_min": 20,
        "evening_from": "21:05",
        "first_departure": "05:45",
        "last_departure": "22:05",
        "valid_from": None,
        "valid_to": None,
        "schedule_status": "ESTIMATED",
        "realtime_status": "UNKNOWN",
        "source": S_TER_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_TER_OP,
        "date_source": DATE_TER_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "Fréquence publiée par l'opérateur (toutes les 10 min, 20 min en soirée après 21:05). Une fréquence ne génère JAMAIS d'heures 10:00, 10:10, 10:20 artificielles.",
    },
    {
        "route_id": "ter_dakar_diamniadio",
        "service_id": "TER_SUNDAY",
        "headway_min": 20,
        "first_departure": "06:25",
        "last_departure": "22:05",
        "valid_from": None,
        "valid_to": None,
        "schedule_status": "ESTIMATED",
        "realtime_status": "UNKNOWN",
        "source": S_TER_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_TER_OP,
        "date_source": DATE_TER_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "Dimanche et jours fériés : toutes les 20 min. Les 48 départs PassBi correspondants sont conservés en LEVEL 1, mais seule la fréquence est promue en LEVEL 2 (ESTIMATED).",
    },
    {
        "route_id": "brt_b1",
        "service_id": "BRT_ALL_DAYS",
        "headway_min": 6,
        "peak_reinforcement": "Petersen ↔ Grand Médine (6h-10h sens Petersen, 16h-20h sens Grand-Médine)",
        "valid_from": None,
        "valid_to": None,
        "schedule_status": "ESTIMATED",
        "realtime_status": "UNKNOWN",
        "source": S_BRT_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_BRT_OP,
        "date_source": DATE_BRT_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "Fréquence B1/B2 : 6 min. Ne devient jamais un horaire exact. Le renfort de pointe est documenté séparément.",
    },
    {
        "route_id": "brt_b2",
        "service_id": "BRT_WEEKDAYS",
        "headway_min": 6,
        "valid_from": None,
        "valid_to": None,
        "schedule_status": "ESTIMATED",
        "realtime_status": "UNKNOWN",
        "source": S_BRT_OP,
        "source_type": "OFFICIAL_OPERATOR",
        "source_url": S_BRT_OP,
        "date_source": DATE_BRT_OP,
        "date_verified": AUDIT_DATE,
        "confidence": "HIGH",
        "verification_note": "B2 : 7 stations, même fréquence 6 min, lundi-samedi.",
    },
]

# Stop_times : on expose les 624 stop_times TER Sunday tels que produits en LEVEL 2,
# mais avec un schedule_status par ligne qui respecte la séparation identité/structure/horaire.
# Les heures viennent de PassBi (historique) et sont traçables ; l'opérateur ne publie pas
# d'heure par station, donc on NE PEUT PAS les marquer SCHEDULED. On les marque
# PARTIALLY_CONFIRMED pour le départ à Dakar (qui correspond à la fréquence officielle)
# et UNCONFIRMED pour les intermédiaires.
stop_times = []
gtfs_stop_times_path = os.path.join(T, "validated", "gtfs", "stop_times.txt")
if os.path.exists(gtfs_stop_times_path):
    with open(gtfs_stop_times_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Tous les champs demandés par la spec
            is_first = row["stop_sequence"] == "1"
            # Le départ à Dakar correspond à la fréquence officielle -> PARTIALLY_CONFIRMED
            # Les intermédiaires ne sont pas confirmés par l'opérateur -> UNCONFIRMED
            # Aucun n'est SCHEDULED car l'opérateur ne publie pas d'heure par station (règle §12)
            schedule_status = "PARTIALLY_CONFIRMED" if is_first else "UNCONFIRMED"
            stop_times.append({
                "route_id": "ter_dakar_diamniadio",
                "service_id": "TER_SUNDAY_AUDIT",
                "trip_id": row["trip_id"],
                "stop_id": row["stop_id"],
                "stop_sequence": int(row["stop_sequence"]),
                "arrival_time": row["arrival_time"],
                "departure_time": row["departure_time"],
                "schedule_status": schedule_status,
                "realtime_status": "UNKNOWN",
                "source": "PassBi (flux SETER) — heure copiée caractère pour caractère",
                "source_type": "PASSBI",
                "source_url": S_PASSBI,
                "date_source": DATE_PASSBI,
                "date_verified": AUDIT_DATE,
                "valid_from": "20260927",
                "valid_to": "20260927",
                "confidence": "MEDIUM" if is_first else "LOW",
                "verification_note": (
                    "Départ Dakar correspondant à la fréquence officielle 20 min (06:25→22:05). "
                    "Heure PassBi conservée, mais l'opérateur ne publie pas d'heure par station : "
                    "ne peut être SCHEDULED (règle §12)."
                    if is_first else
                    "Heure intermédiaire PassBi. Aucune heure par station publiée par l'opérateur : UNCONFIRMED."
                ),
            })

# Stats horaires
from collections import Counter as _C
by_sched = _C(s["schedule_status"] for s in stop_times) if stop_times else {}
# On compte aussi les fréquences dans les totaux horaires pour le rapport
# SCHEDULED : 0 (aucune heure exacte avec les 6 conditions §12 n'est remplie)
# ESTIMATED : fréquences (4)
# UNKNOWN/PARTIALLY_CONFIRMED : stop_times
total_sched_entries = len(stop_times) + len(frequencies)
# Pour le rapport on ventile :
sched_counts = {
    "SCHEDULED": 0,
    "ESTIMATED": len(frequencies),
    "PARTIALLY_CONFIRMED": by_sched.get("PARTIALLY_CONFIRMED", 0),
    "UNCONFIRMED": by_sched.get("UNCONFIRMED", 0),
    "UNKNOWN": by_sched.get("UNKNOWN", 0),
}
# Ajouter les routes dont l'horaire est UNKNOWN (AFTU 72 + DDD 39 + BRT B3)
# Ces routes n'ont pas de stop_times, leur schedule_status est UNKNOWN au niveau route
# mais elles ne comptent pas comme entrées horaires — on les note séparément

schedule_obj = {
    "generated_at": AUDIT_DATE,
    "lot": "4.5",
    "description": "Registre horaire commun — séparation stricte fréquence vs horaire exact vs temps réel. Aucun SCHEDULED sans les 6 conditions, aucun REAL_TIME sans flux frais.",
    "gtfs_time_convention": {
        "rule": "Convention GTFS conservée : les heures >= 24:00 (ex. 25:30:00) sont écrites telles quelles et ne sont JAMAIS converties en heure civile du jour suivant.",
        "times_rewritten": 0,
        "note": "Les heures du LEVEL 2 sont copiées caractère pour caractère depuis le feed PassBi. Les heures >24h sont acceptées et conservées si présentes. Actuellement 0/624 stop_times >=24:00 dans le registre TER.",
        "example_over_24h": "25:15:00",
        "example_valid": True,
    },
    "frequencies": frequencies,
    "stop_times": stop_times,
    "stats": {
        "frequencies": len(frequencies),
        "stop_times": len(stop_times),
        "total_schedule_entries": total_sched_entries,
        "by_schedule_status": sched_counts,
        "by_realtime_status": {"UNKNOWN": len(stop_times), "REAL_TIME": 0},
        "realtime_entries": 0,
        "realtime_status": "NO_REAL_TIME_FEED",
        "note": "Aucune donnée temps réel disponible. PassBi reste NOT_REAL_TIME (lot 4.2B). REAL_TIME exige vehicle/trip/stop/direction/timestamp/freshness/source.",
    },
    "rules": {
        "SCHEDULED": "heure exacte + source identifiable + période de validité + service actif + lien route→trip→stop→stop_time cohérent + provenance traçable. Sinon UNKNOWN.",
        "ESTIMATED": "fréquence opérateur (ex. toutes les 10 min) affichée comme 'Passage estimé toutes les 10 min', jamais comme 10:00, 10:10...",
        "REAL_TIME": "vehicle/trip/stop/direction/timestamp/prediction/freshness/source tous présents et frais. Sinon UNKNOWN.",
    }
}

wj("validated/schedule_registry.json", schedule_obj)

print(json.dumps({
    "public_routes_total": len(routes),
    "by_network": dict(by_network),
    "frequencies": len(frequencies),
    "stop_times": len(stop_times),
    "by_schedule_status": sched_counts,
    "realtime": 0,
}, ensure_ascii=False, indent=2))
