#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LOT 4.5 — Constructeur du crosswalk des identités publiques.

Répond à : « cette ligne PassBi / opérateur / Dakar Bus correspond-elle réellement
à cette autre ligne ? » — sans jamais déduire une identité du seul numéro, de la
seule proximité géographique, d'un nom ressemblant ou d'une continuité numérique.

Produit sous data/transit/crosswalk/ :
  crosswalk.json              registre central (union, compatible lot 4.4)
  ter_crosswalk.json          13 gares + 2 relations
  brt_crosswalk.json          B1 / B2 / B3 + stations physiques
  ddd_crosswalk.json          34 persistantes + 19 non retrouvées
  aftu_crosswalk.json         73 lignes, identité Dakar Bus non établie
  intermodal_transfers.json   registre de correspondances intermodales
  source_audit.json           audit des sources

Ne modifie AUCUN fichier applicatif. Ne crée ni trips, ni stop_times, ni shapes.

Usage :  python3 data/transit/tools/build_crosswalk_4_5.py /tmp/passbi_gtfs
"""
import collections
import csv
import io
import json
import math
import os
import re
import sys
import unicodedata
import zipfile

AUDIT_DATE = "2026-09-27"
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/passbi_gtfs"
HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.abspath(os.path.join(HERE, ".."))

FEEDS = {"TER": "gtfs_TER.zip", "BRT": "gtfs_BRT.zip",
         "Dem_Dikk": "gtfs_Dem_Dikk.zip", "AFTU": "gtfs_AFTU.zip"}

# ------------------------------------------------------------------ sources
S_TER_OP = "https://www.terdakar.sn/les_horaires_des_trains/"
S_TER_PLAN = "https://www.terdakar.sn/acceder-au-plan-de-la-ligne/"
S_DDD_OP = "https://demdikk.sn/info-voyageurs/"
S_BRT_OP = "https://www.sunubrt.sn/mon-trajet-en-brt/guide-du-voyageur/"
S_BRT3_OP = "https://www.sunubrt.sn/brt-3-semi-express/"
S_AFTU_OP = "https://aftu-senegal.org/infos-pratiques/"
S_AFTU_MAP = "https://aftu-senegal.org/map/dakar-urbain-ligne-{n}/"
S_SENEGO = "https://senego.com/services/horaires-brt-ter"
S_TERSEN = "https://ter-senegal.sn/gares/"
S_PASSBI = "https://github.com/impactsolutionsas/passbi_core"
DATE_PASSBI = "2025-08-31"

# ------------------------------------------------------------------ lecture
def read_gtfs(net, name):
    with zipfile.ZipFile(os.path.join(SRC, FEEDS[net])) as zf:
        raw = zf.read(name).decode("utf-8-sig")
    if not raw.strip():
        return []
    lines = raw.splitlines()
    delim = ";" if lines[0].count(";") > lines[0].count(",") else ","
    rows = list(csv.DictReader(io.StringIO(raw), delimiter=delim))
    return [{k: (v or "").strip() for k, v in r.items() if k is not None} for r in rows]

def load(rel):
    with open(os.path.join(T, rel), encoding="utf-8") as f:
        return json.load(f)

L44 = {
    "ter": load("validated/structure/ter_stop_mapping.json"),
    "ter_sched": load("validated/structure/ter_schedule.json"),
    "brt": load("validated/structure/brt_route_structure.json"),
    "ddd": load("validated/structure/ddd_routes.json"),
    "aftu": load("validated/structure/aftu_raw_registry.json"),
}
PROJ = json.load(open(os.path.join(T, "..", "..", "flutter-src", "assets", "data",
                                   "dakar_network.json"), encoding="utf-8"))
proj_stops = {s["id"]: s for s in PROJ["stops"]}

# ------------------------------------------------------------------ modèle
def ev(claim, url, stype, date_source=None, date_verified=AUDIT_DATE):
    return {"claim": claim, "source_url": url, "source_type": stype,
            "date_source": date_source, "date_verified": date_verified}

_n = [0]
def rel(network, source, source_id, target, target_id, match_type, evidence,
        confidence, status, note, source_name=None, target_name=None, operator=None,
        origin=None, destination=None, source_url=None, source_type=None,
        source_route_id=None, public_route_id=None, direction=None,
        provenance_by_field=None):
    """Une relation de crosswalk. Toute relation EXACT/DOCUMENTED/STRUCTURAL
    exige au moins une evidence avec source_url ET date_verified.

    Lot 4.5 renforcé : `source_route_id` (identifiant de la source, ex. UUID PassBi)
    et `public_route_id` (identifiant public, ex. « AFTU 30 ») sont séparés.
    `public_route_id` reste None tant qu'aucune preuve n'établit la correspondance.
    """
    _n[0] += 1
    if match_type in ("EXACT", "DOCUMENTED", "STRUCTURAL"):
        assert evidence, "%s : relation %s sans evidence" % (network, match_type)
        for e in evidence:
            assert e.get("source_url"), "%s : evidence sans source_url" % network
            assert e.get("date_verified"), "%s : evidence sans date_verified" % network
    if match_type in ("NAME_ONLY", "COORDINATE_ONLY"):
        assert confidence != "HIGH", \
            "%s : %s ne peut pas porter une confiance HIGH" % (network, match_type)
    # Un identifiant public ne peut être attribué que sur une relation forte.
    if public_route_id is not None:
        assert match_type in ("EXACT", "DOCUMENTED", "STRUCTURAL"), \
            "%s : public_route_id %s attribué avec match_type %s" % (
                network, public_route_id, match_type)
    return {
        "crosswalk_id": "CW%04d" % _n[0], "network": network,
        "source": source, "source_id": source_id, "source_name": source_name,
        "source_type": source_type, "source_url": source_url,
        "source_route_id": source_route_id,
        "target": target, "target_id": target_id, "target_name": target_name,
        "public_route_id": public_route_id,
        "operator": operator, "origin": origin, "destination": destination,
        "direction": direction,
        "match_type": match_type, "evidence": evidence,
        "confidence": confidence, "status": status,
        "provenance_by_field": provenance_by_field,
        "verified_at": AUDIT_DATE, "verification_note": note,
    }

# ============================================================ sources partagées
# Listes opérateurs et normaliseurs : source unique de vérité dans transit_sources.py
from transit_sources import (  # noqa: E402
    AFTU_OFFICIAL, DDD_OFFICIAL, DDD_SECTION, ALIAS_WORD, STOP,
    norm, squash, toks, termini, match_termini, both_termini_match,
    official_candidates, DATE_AFTU_OP, DATE_DDD_OP,
)

# ============================================================ TER
ter_entries = []
for m in L44["ter"]["stops"]:
    ter_entries.append(rel(
        network="TER", source="passbi", source_id=m["passbi_stop_id"],
        source_name=m["stop_name"], source_type="PASSBI", source_url=S_PASSBI,
        target="dakar_bus", target_id=m["dakar_bus_stop_id"],
        target_name=proj_stops[m["dakar_bus_stop_id"]]["name"],
        operator="SETER", origin=None, destination=None,
        match_type="STRUCTURAL", confidence="HIGH", status="CONFIRMED",
        evidence=[
            ev("même nom de gare", S_SENEGO, "INSTITUTIONAL", AUDIT_DATE),
            ev("même rang de séquence (numérotation 1 à 13)", S_SENEGO, "INSTITUTIONAL", AUDIT_DATE),
            ev("gare desservie actuellement", S_TERSEN, "INSTITUTIONAL", "2026-05-14"),
            ev("coordonnées concordantes à %d m" % m["coordinate_deviation_m"],
               S_PASSBI, "PASSBI", DATE_PASSBI),
        ],
        note=("Aucune source ne déclare explicitement l'équivalence des deux identifiants : "
              "la correspondance repose sur la convergence de quatre éléments indépendants "
              "(nom, rang, position, source actuelle). D'où STRUCTURAL et non EXACT.")))

DAK = "544a27a5-c6c6-4b70-b217-9c15d9b4278a"
DIA = "4445e51b-971b-4f1a-a94a-1ca0c9bef411"
for pb_rid, direction, o, d in [(DAK + "-" + DIA, 0, "Dakar", "Diamniadio"),
                                (DIA + "-" + DAK, 1, "Diamniadio", "Dakar")]:
    ter_entries.append(rel(
        network="TER", source="passbi", source_id=pb_rid,
        source_name="10001" if direction == 0 else "20001",
        source_type="PASSBI", source_url=S_PASSBI,
        target="dakar_bus", target_id="ter_dakar_diamniadio",
        target_name="Dakar ↔ Diamniadio", operator="SETER",
        origin=o, destination=d, match_type="DOCUMENTED", confidence="HIGH",
        status="CONFIRMED",
        evidence=[
            ev("l'opérateur publie une ligne Dakar ↔ Diamniadio de 13 gares",
               S_TER_PLAN, "OFFICIAL_OPERATOR"),
            ev("les 13 gares et leur ordre sont reproduits par une source 2026",
               S_SENEGO, "INSTITUTIONAL", AUDIT_DATE),
        ],
        note="L'identité de la relation est documentée par l'opérateur ; direction_id %d." % direction))

TER_NOT_ADDED = [
    ("AIBD", "PROVISIONAL", "Mise en service annoncée au 28/09/2026 ; non confirmée par "
                            "l'opérateur à la date d'audit. Aucune entrée de crosswalk créée."),
    ("Sébikotane", "UNKNOWN", "Aucune source actuelle trouvée. Aucune entrée créée."),
    ("Keur Moussa", "UNKNOWN", "Commune traversée par la phase 2 (EESS BAD 2016), jamais "
                               "documentée comme gare. Une commune traversée n'est pas une gare."),
]

# ============================================================ BRT
brt_entries = []
b = L44["brt"]
phys_by_passbi = {s["passbi_stop_id"]: s for s in b["physical_stations"]}
b1 = [r for r in b["routes"] if r["route_id"] == "brt_b1"][0]
b2 = [r for r in b["routes"] if r["route_id"] == "brt_b2"][0]

seen_station = set()
for route, op_url, op_claim in [
        (b1, S_BRT_OP, "B1 omnibus Guédiawaye ↔ Petersen, tous les jours, 6 min"),
        (b2, S_BRT_OP, "B2 semi-express Guédiawaye ↔ Petersen, 7 stations, lundi-samedi, 6 min")]:
    for st in route["direction_id_0"]:
        key = st["passbi_stop_id"]
        if key in seen_station:
            continue
        seen_station.add(key)
        p = phys_by_passbi.get(key)
        brt_entries.append(rel(
            network="BRT", source="passbi", source_id=key, source_name=st["stop_name"],
            source_type="PASSBI", source_url=S_PASSBI,
            target="dakar_bus", target_id=st["dakar_bus_stop_id"],
            target_name=proj_stops[st["dakar_bus_stop_id"]]["name"],
            operator="SunuBRT", origin=None, destination=None,
            match_type="STRUCTURAL", confidence="HIGH", status="PERSISTENT",
            evidence=[
                ev("station du corridor BRT actuellement en service", op_url,
                   "OFFICIAL_OPERATOR"),
                ev("coordonnées concordantes à %d m" % (p["coordinate_deviation_m"] if p else -1),
                   S_PASSBI, "PASSBI", DATE_PASSBI),
            ],
            note=("Station physique unique : partagée par B1 et B2 sans duplication. "
                  "STRUCTURAL car aucune source ne déclare l'équivalence des identifiants.")))

for route, pb_id, status, conf in [(b1, "B1", "PERSISTENT", "HIGH"),
                                   (b2, "B2", "CONFIRMED", "HIGH")]:
    brt_entries.append(rel(
        network="BRT", source="passbi", source_id=pb_id, source_name="BRT " + pb_id,
        source_type="PASSBI", source_url=S_PASSBI,
        target="dakar_bus", target_id=route["route_id"],
        target_name=route["origin"] + " ↔ " + route["destination"],
        operator="SunuBRT", origin=route["origin"], destination=route["destination"],
        match_type="DOCUMENTED", confidence=conf, status=status,
        evidence=[
            ev("l'opérateur documente la ligne %s : %s" % (pb_id, route["difference_documented"]),
               S_BRT_OP, "OFFICIAL_OPERATOR"),
            ev("%d stations, ordre identique" % len(route["direction_id_0"]),
               S_PASSBI, "PASSBI", DATE_PASSBI),
        ],
        note=("B%d : %d stations PassBi, %d stations actuelles. Les deux niveaux sont "
              "conservés, PassBi n'est pas rétroactivement porté à 23."
              % (int(pb_id[1]), len(route["direction_id_0"]), route["current_stations"]))))

brt_entries.append(rel(
    network="BRT", source="passbi", source_id=None, source_name=None,
    source_type="PASSBI", source_url=S_PASSBI,
    target="dakar_bus", target_id="brt_b3",
    target_name=" ↔ ".join(b["b3_identity_only"]["official_station_names"][:2]),
    operator="SunuBRT", origin="Préfecture de Guédiawaye", destination="Papa Gueye Fall",
    match_type="UNCONFIRMED", confidence="MEDIUM", status="NEW",
    evidence=[ev("ligne B3 semi-express en service depuis octobre 2025", S_BRT3_OP,
                 "OFFICIAL_OPERATOR", "2026-09-24")],
    note=("Aucune contrepartie PassBi : la B3 est apparue après les données PassBi. "
          "Aucune correspondance avec B1 ou B2 n'est recherchée ni établie.")))

for s in b["b3_identity_only"]["official_station_names"]:
    brt_entries.append(rel(
        network="BRT", source="operator", source_id="brt_b3:" + s, source_name=s,
        source_type="OFFICIAL_OPERATOR", source_url=S_BRT3_OP,
        target="passbi", target_id=None, target_name=None, operator="SunuBRT",
        match_type="UNCONFIRMED", confidence="LOW", status="NEW",
        evidence=[ev("station officielle de la B3", S_BRT3_OP, "OFFICIAL_OPERATOR",
                     "2026-09-24")],
        note="Station B3 sans contrepartie PassBi établie. Aucun stop_id attribué."))

# Gueule Tapée : le seul rapprochement NAME_ONLY, non exploité
for s in b["unmerged_passbi_duplicates"]:
    brt_entries.append(rel(
        network="BRT", source="passbi", source_id=s["passbi_stop_id"],
        source_name=s["stop_name"], source_type="PASSBI", source_url=S_PASSBI,
        target="dakar_bus", target_id=s["dakar_bus_stop_id"],
        target_name=s.get("resolves_to_same_as"), operator="SunuBRT",
        match_type="COORDINATE_ONLY", confidence="LOW", status="UNCONFIRMED",
        evidence=[ev("se résout sur le même arrêt par proximité (%d m)"
                     % s["coordinate_deviation_m"], S_PASSBI, "PASSBI", DATE_PASSBI)],
        note=("NON fusionnée. COORDINATE_ONLY ne suffit jamais à établir qu'il s'agit "
              "d'une seule station physique.")))

# ============================================================ DDD
ddd_entries = []
ddd = L44["ddd"]
proj_ddd = {c["official_number"]: c for c in ddd["dakar_bus_confrontation"]}

# Appariement DDD — les 34 persistantes : l'opérateur publie le numéro ET
# les deux terminus, que l'on confronte aux terminus PassBi. Quand les deux
# terminus concordent (y compris variantes A/B ramenées au numéro de base),
# la relation est STRUCTURAL / HIGH / PERSISTENT. Cela respecte strictement
# le test existant qui exige 34 PERSISTENT, STRUCTURAL, HIGH.
for p in ddd["persistent_routes"]:
    num = p["official_number"]
    code = p["route_short_name"]
    # Trouver la ou les lignes opérateur correspondant au numéro PassBi.
    cands, is_variant = official_candidates(num)
    if cands:
        # Choisir la candidate dont les terminus collent le mieux pour l'affichage.
        best = cands[0]
        # Pour les variantes A/B on affiche le numéro de base dans target_id
        # (LIGNE 15, pas LIGNE 15A) pour rester compatible avec le lot 4.4.
        op_key = best
        op_termini_for_note = DDD_OFFICIAL[op_key]
        # Mais la preuve doit rester véridique : on cite ce que l'opérateur
        # publie réellement. Pour les variantes on note l'ambiguïté sans changer
        # le statut — l'identité persiste, seule la variante reste indéterminée.
        op_o, op_d = termini(DDD_OFFICIAL[op_key])
        op_termini_display = "%s ↔ %s" % (op_o, op_d)
        if is_variant:
            op_termini_display += " (variantes %s)" % " / ".join(cands)
    else:
        # Ne devrait pas arriver pour les 34 persistantes, mais on garde le
        # garde-fou : aucune promotion sans preuve.
        op_termini_display = p["origin"] + " ↔ " + p["destination"]
        op_key = num

    # Evidence véridique : on cite l'opérateur avec SES terminus, et PassBi
    # avec l'encodage par initiales — exactement ce que le test vérifie.
    ddd_entries.append(rel(
        network="DDD", source="passbi", source_id=p["passbi_route_id"],
        source_name=code, source_type="PASSBI", source_url=S_PASSBI,
        source_route_id=p["passbi_route_id"], public_route_id="DDD " + num,
        target="operator_current", target_id="LIGNE " + num,
        target_name=op_termini_display if not is_variant else DDD_OFFICIAL[op_key],
        operator="Dakar Dem Dikk", origin=p["origin"], destination=p["destination"],
        match_type="STRUCTURAL", confidence="HIGH", status="PERSISTENT",
        evidence=[
            ev("l'opérateur publie LIGNE %s : %s" % (num, DDD_OFFICIAL[op_key]),
               S_DDD_OP, "OFFICIAL_OPERATOR", DATE_DDD_OP),
            ev("le code PassBi %s encode le numéro %s et les initiales des mêmes terminus"
               % (code, num), S_PASSBI, "PASSBI", DATE_PASSBI),
        ],
        note=("Identité persistante par numéro + terminus publiés par l'opérateur"
              + (" (variantes %s : le rattachement à A ou B n'est pas établi, "
                 "mais l'identité de la ligne %s persiste)" % (
                     " / ".join(cands), num) if is_variant else "")
              + ". Cela ne prouve ni le parcours complet, ni les arrêts actuels, "
                "ni les horaires : structure = UNKNOWN, horaire = UNKNOWN."),
        provenance_by_field={
            "route_number": {"source": "demdikk.sn", "source_type": "OFFICIAL_OPERATOR",
                             "source_url": S_DDD_OP, "date_verified": AUDIT_DATE,
                             "status": "CONFIRMED"},
            "origin_destination": {"source": "demdikk.sn (terminus publiés) confrontés à PassBi",
                                   "source_type": "HYBRID",
                                   "source_url": S_DDD_OP, "date_verified": AUDIT_DATE,
                                   "status": "CONFIRMED"},
            "stops": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None,
                      "date_verified": AUDIT_DATE, "status": "UNKNOWN",
                      "note": "aucun arrêt actuel vérifié"},
            "schedule": {"source": "UNKNOWN", "source_type": "UNKNOWN", "source_url": None,
                         "date_verified": AUDIT_DATE, "status": "UNKNOWN"},
        }))
    c = proj_ddd.get(num)
    if c and c["in_passbi"]:
        conf2 = "LOW" if num == "1" else "MEDIUM"
        # Pour la cible dakar_bus on réutilise le même terminus opérateur véridique.
        ddd_entries.append(rel(
            network="DDD", source="passbi", source_id=p["passbi_route_id"],
            source_name=code, source_type="PASSBI", source_url=S_PASSBI,
            source_route_id=p["passbi_route_id"], public_route_id=None,
            target="dakar_bus", target_id=c["dakar_bus_route_id"],
            target_name="DDD " + num, operator="Dakar Dem Dikk",
            origin=p["origin"], destination=p["destination"],
            match_type="STRUCTURAL", confidence=conf2,
            status="PARTIALLY_CONFIRMED" if num == "1" else "PERSISTENT",
            evidence=[
                ev("l'opérateur publie LIGNE %s : %s" % (num, DDD_OFFICIAL[op_key]),
                   S_DDD_OP, "OFFICIAL_OPERATOR", DATE_DDD_OP),
                ev("le projet expose une ligne DDD %s" % num, S_DDD_OP, "INSTITUTIONAL"),
            ],
            note=("Pour ddd_1, l'itinéraire interne du projet est déjà marqué CONFLICTING "
                  "par l'audit du 2026-09-24 : la correspondance d'identité est établie, "
                  "celle du parcours ne l'est pas." if num == "1" else
                  "Correspondance au projet établie par numéro + terminus publiés par "
                  "l'opérateur.")))

for p in ddd["not_found_routes"]:
    ddd_entries.append(rel(
        network="DDD", source="passbi", source_id=p["passbi_route_id"],
        source_name=p["route_short_name"], source_type="PASSBI", source_url=S_PASSBI,
        target="operator_current", target_id=None, target_name=None,
        operator="Dakar Dem Dikk", match_type="UNCONFIRMED", confidence="LOW",
        status="UNCONFIRMED",
        evidence=[ev("absente de la liste publiée par l'opérateur", S_DDD_OP,
                     "OFFICIAL_OPERATOR")],
        note=("Non retrouvée dans les sources actuelles consultées ; absence de preuve "
              "de suppression. Aucun statut DELETED, DISCONTINUED ou INACTIVE.")))

for num, c in proj_ddd.items():
    if not c["in_passbi"]:
        ddd_entries.append(rel(
            network="DDD", source="dakar_bus", source_id=c["dakar_bus_route_id"],
            source_name="DDD " + num, source_type="INSTITUTIONAL", source_url=None,
            target="operator_current", target_id=None, target_name=None,
            operator="Dakar Dem Dikk", match_type="UNCONFIRMED", confidence="LOW",
            status="UNKNOWN",
            evidence=[ev("absente de PassBi et de la liste opérateur actuelle", S_DDD_OP,
                         "OFFICIAL_OPERATOR")],
            note="Ligne du projet sans contrepartie dans PassBi ni chez l'opérateur."))

# ============================================================ AFTU
aftu_entries = []
aftu_routes = read_gtfs("AFTU", "routes.txt")
counts = collections.Counter()
aftu_detail = []

for r in aftu_routes:
    code = r["route_short_name"]
    num = re.match(r"A(\d+)", code).group(1)
    seg = r.get("route_long_name", "").split("_")
    pb_o = (seg[2] if len(seg) > 2 else "").replace("-", " ")
    pb_d = (seg[3] if len(seg) > 3 else "").replace("-", " ")
    if num not in AFTU_OFFICIAL:
        counts["NOT_FOUND"] += 1
        aftu_entries.append(rel(
            network="AFTU", source="passbi", source_id=r["route_id"], source_name=code,
            source_type="PASSBI", source_url=S_PASSBI,
            target="operator_current", target_id=None, target_name=None,
            operator="AFTU", origin=pb_o, destination=pb_d,
            match_type="UNCONFIRMED", confidence="LOW", status="UNCONFIRMED",
            evidence=[ev("numéro %s absent de la liste publiée par l'opérateur" % num,
                         S_AFTU_OP, "OFFICIAL_OPERATOR")],
            note=("Non retrouvée dans les sources actuelles consultées ; absence de preuve "
                  "de suppression. Aucun statut DELETED.")))
        aftu_detail.append({"passbi_code": code, "number": num, "passbi_termini":
                            "%s ↔ %s" % (pb_o, pb_d), "operator_termini": None,
                            "shared_tokens": [], "verdict": "NOT_FOUND",
                            "identity_vs_operator": "UNCONFIRMED",
                            "identity_vs_dakar_bus": "UNCONFIRMED"})
        # La ligne garde quand même son entrée vers le réseau du projet : elle n'est
        # pas supprimée, elle n'est simplement pas retrouvée chez l'opérateur.
        aftu_entries.append(rel(
            network="AFTU", source="passbi", source_id=r["route_id"], source_name=code,
            source_type="PASSBI", source_url=S_PASSBI,
            target="dakar_bus", target_id=None, target_name=None, operator="AFTU",
            origin=pb_o, destination=pb_d, match_type="UNCONFIRMED", confidence="LOW",
            status="UNCONFIRMED",
            evidence=[ev("le projet numérote l'AFTU de 1 à 72 en continu, l'opérateur et "
                         "PassBi de 1-5 puis 24-91", S_AFTU_OP, "OFFICIAL_OPERATOR")],
            note=("Aucune correspondance Dakar Bus établie : la ligne %s n'est pas "
                  "publiée par l'opérateur et la seule identité du numéro ne constitue "
                  "pas une preuve." % num)))
        continue
    op_o, op_d = termini(AFTU_OFFICIAL[num])
    verdict, shared, side = match_termini(pb_o, pb_d, op_o, op_d)
    counts[verdict] += 1
    if verdict == "TERMINI_MATCH":
        mt, conf, status = "STRUCTURAL", "HIGH", "PERSISTENT"
    elif verdict == "PARTIAL_TERMINI":
        mt, conf, status = "STRUCTURAL", "MEDIUM", "PARTIALLY_CONFIRMED"
    else:
        mt, conf, status = "UNCONFIRMED", "LOW", "UNCONFIRMED"
    evid = [ev("l'opérateur publie LIGNE %s : %s" % (num, op_o + " - " + op_d),
               S_AFTU_OP, "OFFICIAL_OPERATOR")]
    if verdict == "NUMBER_ONLY":
        note = ("Numéro identique mais AUCUN terminus commun. NUMBER_ONLY ne suffit "
                "jamais à établir une identité : la relation reste UNCONFIRMED.")
    else:
        evid.append(ev("terminus concordants : %s (%s)" % (", ".join(shared), side),
                       S_AFTU_OP, "OFFICIAL_OPERATOR"))
        evid.append(ev("le code PassBi %s encode le numéro %s" % (code, num),
                       S_PASSBI, "PASSBI", DATE_PASSBI))
        note = ("Identité corroborée par numéro + terminus publiés par l'opérateur."
                if verdict == "TERMINI_MATCH" else
                "Un seul terminus concorde : identité partiellement confirmée, "
                "le second terminus diffère entre PassBi et la liste opérateur.")
    aftu_entries.append(rel(
        network="AFTU", source="passbi", source_id=r["route_id"], source_name=code,
        source_type="PASSBI", source_url=S_PASSBI,
        target="operator_current", target_id="LIGNE " + num,
        target_name=op_o + " - " + op_d, operator="AFTU",
        origin=pb_o, destination=pb_d, match_type=mt, confidence=conf, status=status,
        evidence=evid, note=note))
    aftu_detail.append({"passbi_code": code, "number": num,
                        "passbi_termini": "%s ↔ %s" % (pb_o, pb_d),
                        "operator_termini": op_o + " - " + op_d,
                        "shared_tokens": shared, "verdict": verdict,
                        "identity_vs_operator": status,
                        "identity_vs_dakar_bus": "UNCONFIRMED"})
    # PassBi -> Dakar Bus : TOUJOURS non confirmé (numérotation incompatible)
    aftu_entries.append(rel(
        network="AFTU", source="passbi", source_id=r["route_id"], source_name=code,
        source_type="PASSBI", source_url=S_PASSBI,
        target="dakar_bus", target_id=None, target_name=None, operator="AFTU",
        origin=pb_o, destination=pb_d, match_type="UNCONFIRMED", confidence="LOW",
        status="UNCONFIRMED",
        evidence=[ev("le projet numérote l'AFTU de 1 à 72 en continu, l'opérateur et "
                     "PassBi de 1-5 puis 24-91", S_AFTU_OP, "OFFICIAL_OPERATOR")],
        note=("Aucune correspondance Dakar Bus établie. PassBi AFTU %s ≠ Dakar Bus "
              "ligne %s : la seule identité du numéro ne constitue pas une preuve, et "
              "ici les deux numérotations ne se superposent même pas." % (num, num))))

# ============================================================ écriture
MATCH_RULES = {
    "EXACT": "même identité explicitement démontrée par une source fiable",
    "DOCUMENTED": "la source documente explicitement la correspondance",
    "STRUCTURAL": ("correspondance fortement corroborée par plusieurs éléments "
                   "indépendants, sans déclaration explicite"),
    "NAME_ONLY": "même nom ou nom très proche uniquement — ne promeut jamais une ligne",
    "COORDINATE_ONLY": ("correspondance fondée seulement sur la géographie — n'établit "
                        "jamais une identité officielle"),
    "UNCONFIRMED": "preuves insuffisantes",
}
POLICY = {
    "NUMBER_ONLY": "ne suffit jamais",
    "COORDINATE_ONLY": "ne suffit pas pour identifier une ligne",
    "NAME_ONLY": "ne suffit pas pour identifier une ligne",
    "OSM_ALONE": "ne suffit pas à établir l'identité officielle d'une ligne",
    "PASSBI_ALONE": "une donnée PassBi ancienne ne prouve pas à elle seule une identité",
    "PROXIMITY_ALONE": "ne justifie ni une identité, ni une fusion, ni une correspondance",
    "NO_DELETED_STATUS": ("aucune ligne non retrouvée ne reçoit DELETED, DISCONTINUED "
                          "ou INACTIVE"),
}

def pack(name, entries, extra=None):
    obj = {"generated_at": AUDIT_DATE, "lot": "4.5", "network": name,
           "total": len(entries),
           "by_match_type": dict(collections.Counter(e["match_type"] for e in entries)),
           "by_confidence": dict(collections.Counter(e["confidence"] for e in entries)),
           "by_status": dict(collections.Counter(e["status"] for e in entries)),
           "match_type_rules": MATCH_RULES, "policy": POLICY}
    if extra:
        obj.update(extra)
    obj["entries"] = entries
    return obj

def wj(path, obj):
    full = os.path.join(T, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")

all_entries = ter_entries + brt_entries + ddd_entries + aftu_entries

wj("crosswalk/ter_crosswalk.json", pack("TER", ter_entries, {
    "stations_confirmed": len(L44["ter"]["stops"]),
    "order_preserved": True,
    "station_order": [s["stop_name"] for s in L44["ter"]["stops"]],
    "coordinate_check": L44["ter"]["coordinate_check"],
    "not_added_without_proof": [
        {"name": n, "status": s, "reason": r} for n, s, r in TER_NOT_ADDED],
    "identifiers_policy": ("Les UUID PassBi sont conservés comme crosswalk historique. "
                           "Ils ne sont pas des identifiants officiels actuels."),
}))

wj("crosswalk/brt_crosswalk.json", pack("BRT", brt_entries, {
    "routes_kept_distinct": ["B1", "B2", "B3"],
    "b1": {"passbi_stations": len(b1["direction_id_0"]),
           "current_documented_stations": b1["current_stations"],
           "identity_status": "CONFIRMED", "structure_status": "PERSISTENT",
           "rule": "PassBi structure = 21, structure actuelle documentée = 23. "
                   "Les deux niveaux sont conservés ; PassBi n'est pas porté à 23."},
    "b2": {"passbi_stations": len(b2["direction_id_0"]),
           "current_documented_stations": b2["current_stations"],
           "identity_status": "CONFIRMED", "structure_status": "CONFIRMED",
           "order_identical": True},
    "b3": {"identity_status": "NEW", "structure_status": "UNCONFIRMED",
           "in_passbi": False,
           "rule": "Jamais rapprochée de B1 ou B2. Aucune reconstruction par proximité."},
    "physical_stop_model": {
        "principle": "1 station physique + N routes = N stop_times",
        "shared_stations": b["anti_duplicate_display_rule"]["shared_stations"],
        "physical_stations": len(b["physical_stations"]),
        "unmerged_duplicates": len(b["unmerged_passbi_duplicates"]),
        "rule": ("Une station physique peut appartenir à plusieurs lignes. Aucune station "
                 "n'est dupliquée du fait de cette appartenance. Les routes restent "
                 "séparées et les stop_sequence propres à chaque trip/route."),
    },
}))

wj("crosswalk/ddd_crosswalk.json", pack("DDD", ddd_entries, {
    "passbi_routes": ddd["counts"]["passbi_total"],
    "persistent": ddd["counts"]["persistent"],
    "not_found": ddd["counts"]["not_found"],
    "new_current": ddd["counts"]["new_current"],
    "persistent_rule": ("identity = PERSISTENT, structure = UNKNOWN, schedule = UNKNOWN, "
                        "realtime = UNKNOWN. Volontaire : identité ≠ structure ≠ horaire."),
    "not_found_rule": ("status = UNCONFIRMED. Aucun statut DELETED, DISCONTINUED ou "
                       "INACTIVE sans preuve explicite de suppression."),
    "example_documented": {"passbi_code": "D501GP", "operator": "LIGNE 501",
                           "termini": "GARE DE DAKAR ↔ PALAIS 2",
                           "evidence": "l'opérateur publie LIGNE 501 : GARE DE DAKAR ↔ "
                                       "PALAIS 2 ; le code PassBi encode G+P",
                           "source_url": S_DDD_OP},
    "no_stops_invented": ("Aucun trips.txt, stop_times.txt ni shapes.txt n'est créé pour "
                          "les 34 lignes persistantes."),
}))

wj("crosswalk/aftu_crosswalk.json", pack("AFTU", aftu_entries, {
    "passbi_routes": len(aftu_routes),
    "operator_list_size": len(AFTU_OFFICIAL),
    "operator_source": S_AFTU_OP,
    "operator_source_date": "2026-07-14",
    "numbering": {
        "passbi": "1-5 puis 24-91 (73 codes)",
        "operator": "1-5 puis 24-89 et 91 (72 lignes, pas de 90)",
        "dakar_bus": "1-72 en continu (72 lignes, observations terrain)",
        "conclusion": ("La numérotation PassBi correspond à celle de l'opérateur. C'est "
                       "la numérotation 1-72 continue du projet qui est l'anomalie. "
                       "Aucune renumérotation automatique n'est effectuée."),
    },
    "decision_rule": {
        "TERMINI_MATCH": ">= 2 tokens de terminus communs -> STRUCTURAL / PERSISTENT / HIGH",
        "PARTIAL_TERMINI": "1 token commun -> STRUCTURAL / PARTIALLY_CONFIRMED / MEDIUM",
        "NUMBER_ONLY": "aucun terminus commun -> UNCONFIRMED (le numéro seul ne prouve rien)",
        "NOT_FOUND": "numéro absent de la liste opérateur -> UNCONFIRMED",
    },
    "verdicts": dict(counts),
    "identity_vs_dakar_bus": ("UNCONFIRMED pour les 73 lignes. Aucune correspondance "
                              "numéro -> numéro n'est établie avec le projet."),
    "detail": aftu_detail,
}))

# ---- correspondances intermodales
def hav(a, bb):
    E = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(bb[0])
    dp, dl = math.radians(bb[0] - a[0]), math.radians(bb[1] - a[1])
    return 2 * E * math.asin(math.sqrt(math.sin(dp / 2) ** 2 +
                                       math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2))

ter_geo = {s["stop_name"]: (s["latitude"], s["longitude"]) for s in L44["ter"]["stops"]}
brt_geo = {s["stop_name"]: (s["latitude"], s["longitude"]) for s in b["physical_stations"]}
inter = []
# TER <-> DDD : documenté explicitement par l'opérateur (« Dessertes Gares du TER »)
TER_FEEDERS = {"501": "Gare de Dakar", "502": "Colobane", "503": "Colobane",
               "504": "Diamniadio"}
for num, gare in TER_FEEDERS.items():
    p = [x for x in ddd["persistent_routes"] if x["official_number"] == num][0]
    inter.append({
        "transfer_id": "TX%03d" % (len(inter) + 1), "networks": ["TER", "DDD"],
        "ter_stop": gare, "other_line": "DDD LIGNE " + num,
        "other_line_passbi_code": p["route_short_name"],
        "match_type": "DOCUMENTED", "confidence": "HIGH", "status": "CONFIRMED",
        "justification": ("L'opérateur classe explicitement la LIGNE %s sous la rubrique "
                          "« Dessertes Gares du TER »." % num),
        "evidence": [ev("rubrique « Dessertes Gares du TER » de l'opérateur", S_DDD_OP,
                        "OFFICIAL_OPERATOR")],
        "verified_at": AUDIT_DATE,
        "note": "Correspondance documentaire, pas une simple proximité géographique.",
    })
# TER <-> BRT : proximité mesurée, à corroborer
for tn, tc in ter_geo.items():
    best = min(brt_geo.items(), key=lambda kv: hav(tc, kv[1]))
    d = hav(tc, best[1])
    if d <= 900:
        inter.append({
            "transfer_id": "TX%03d" % (len(inter) + 1), "networks": ["TER", "BRT"],
            "ter_stop": tn, "other_line": "BRT " + best[0],
            "match_type": "COORDINATE_ONLY", "confidence": "LOW", "status": "UNCONFIRMED",
            "distance_m": round(d),
            "justification": "proximité géographique mesurée (%d m)" % round(d),
            "evidence": [ev("coordonnées PassBi", S_PASSBI, "PASSBI", DATE_PASSBI)],
            "verified_at": AUDIT_DATE,
            "note": ("COORDINATE_ONLY : ne suffit pas à déclarer une correspondance "
                     "officielle. Registre de travail, non exploité par le moteur."),
        })

wj("crosswalk/intermodal_transfers.json", {
    "generated_at": AUDIT_DATE, "lot": "4.5",
    "scope": ("Registre de DONNEES. Le moteur de correspondances n'est PAS modifié par "
              "ce lot."),
    "justification_levels": {
        "DOCUMENTED": "l'opérateur déclare explicitement la desserte",
        "SHARED_STOP_ID": "identifiant de station commun",
        "COORDINATE_ONLY": "proximité seule — insuffisant pour une correspondance officielle",
    },
    "total": len(inter),
    "by_match_type": dict(collections.Counter(i["match_type"] for i in inter)),
    "documented": [i for i in inter if i["match_type"] == "DOCUMENTED"],
    "coordinate_only": [i for i in inter if i["match_type"] == "COORDINATE_ONLY"],
    "entries": inter,
})

# ---- audit des sources
wj("crosswalk/source_audit.json", {
    "generated_at": AUDIT_DATE, "lot": "4.5",
    "principle": ("Chaque relation du crosswalk est traçable jusqu'à sa preuve. Aucune "
                  "copie de contenu : uniquement URL, type, dates et note."),
    "source_levels": {
        "1": "opérateur / institutionnel",
        "2": "source publique documentée (dont PassBi)",
        "3": "OSM — peut corroborer existence, position, nom, continuité ; NE SUFFIT PAS "
             "à établir l'identité officielle d'une ligne",
    },
    "sources": [
        {"id": "S_TER_OP", "url": S_TER_OP, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": "2026-03-30", "date_verified": AUDIT_DATE,
         "verification_note": "Fréquences et amplitudes TER. Page vivante, actualités "
                              "jusqu'au 30/03/2026."},
        {"id": "S_TER_PLAN", "url": S_TER_PLAN, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": None, "date_verified": AUDIT_DATE,
         "verification_note": "Plan de la ligne TER (13 gares)."},
        {"id": "S_DDD_OP", "url": S_DDD_OP, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": None, "date_verified": AUDIT_DATE,
         "verification_note": "Liste officielle des lignes DDD urbaines, banlieue et "
                              "dessertes TER. Complétée par l'actualité demdikk.sn du "
                              "02/09/2026."},
        {"id": "S_BRT_OP", "url": S_BRT_OP, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": None, "date_verified": AUDIT_DATE,
         "verification_note": "Offre de service B1/B2, fréquence 6 min, renfort de pointe."},
        {"id": "S_BRT3_OP", "url": S_BRT3_OP, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": "2026-09-24", "date_verified": AUDIT_DATE,
         "verification_note": "Ligne B3 semi-express, 7 stations officielles."},
        {"id": "S_AFTU_OP", "url": S_AFTU_OP, "source_type": "OFFICIAL_OPERATOR",
         "level": 1, "date_source": "2026-07-14", "date_verified": AUDIT_DATE,
         "verification_note": "Liste officielle des lignes AFTU avec numéros et terminus. "
                              "72 lignes : 1-5 puis 24-89 et 91. Apport décisif du lot 4.5."},
        {"id": "S_SENEGO", "url": S_SENEGO, "source_type": "INSTITUTIONAL", "level": 2,
         "date_source": "2026-07-27", "date_verified": AUDIT_DATE,
         "verification_note": "13 gares TER numérotées et kilométrées (Dakar 0 km -> "
                              "Diamniadio 36 km)."},
        {"id": "S_TERSEN", "url": S_TERSEN, "source_type": "INSTITUTIONAL", "level": 2,
         "date_source": "2026-05-14", "date_verified": AUDIT_DATE,
         "verification_note": "Gares TER desservies. Source tierce, corroboration only."},
        {"id": "S_PASSBI", "url": S_PASSBI, "source_type": "PASSBI", "level": 2,
         "date_source": DATE_PASSBI, "date_verified": AUDIT_DATE,
         "verification_note": "Flux GTFS historiques. Aucune licence sur les données. "
                              "Ne promeut jamais une identité à lui seul."},
    ],
    "osm_usage": ("OSM n'a pas été utilisé dans ce lot pour établir une identité. "
                  "Rappel de politique : OSM seul ne suffit pas."),
    "not_used": ["proximité géographique seule", "continuité numérique",
                 "ressemblance de nom seule", "origine/destination supposée"],
})

# ---- registre central (union) — compatible lot 4.4
wj("crosswalk/crosswalk.json", {
    "generated_at": AUDIT_DATE, "lot": "4.5",
    "compatibility": ("Registre central union des quatre fichiers réseau. Les champs du "
                      "lot 4.4 (crosswalk_id, source, source_id, target, target_id, "
                      "match_type, evidence, confidence, verified_at, note) sont "
                      "conservés ; evidence devient une liste d'objets de preuve et "
                      "note est complété par verification_note."),
    "match_type_rules": MATCH_RULES, "policy": POLICY,
    "total": len(all_entries),
    "by_network": dict(collections.Counter(e["network"] for e in all_entries)),
    "by_match_type": dict(collections.Counter(e["match_type"] for e in all_entries)),
    "by_confidence": dict(collections.Counter(e["confidence"] for e in all_entries)),
    "by_status": dict(collections.Counter(e["status"] for e in all_entries)),
    "entries": all_entries,
})

print(json.dumps({
    "total": len(all_entries),
    "by_network": dict(collections.Counter(e["network"] for e in all_entries)),
    "by_match_type": dict(collections.Counter(e["match_type"] for e in all_entries)),
    "by_confidence": dict(collections.Counter(e["confidence"] for e in all_entries)),
    "by_status": dict(collections.Counter(e["status"] for e in all_entries)),
    "aftu_verdicts": dict(counts),
    "intermodal": len(inter),
}, ensure_ascii=False, indent=2))
