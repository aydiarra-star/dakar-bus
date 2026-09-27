# -*- coding: utf-8 -*-
"""
LOT 4.5 — Source unique de vérité pour les listes opérateurs et les normaliseurs.

Importé par build_crosswalk_4_5.py et build_public_registry_4_5.py pour éviter
toute divergence entre les deux registres.

AUCUNE valeur de ce fichier n'est déduite : chacune est la transcription d'une
page opérateur consultée le 2026-09-27.
"""
import re
import unicodedata

AUDIT_DATE = "2026-09-27"

# ============================================================ sources
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

# Dates de publication relevées sur les pages elles-mêmes.
DATE_AFTU_OP = "2026-07-14"     # aftu-senegal.org/infos-pratiques/
DATE_DDD_OP = "2026-09-02"      # dernière actualité datée sur demdikk.sn
DATE_BRT3_OP = "2026-09-24"     # sunubrt.sn/brt-3-semi-express/
DATE_TER_OP = "2026-03-30"      # dernière actualité sur terdakar.sn
DATE_TERSEN = "2026-05-14"
DATE_SENEGO = "2026-07-27"

# ============================================================ AFTU opérateur
# aftu-senegal.org/infos-pratiques/, page datée du 14/07/2026, consultée 2026-09-27.
# 72 lignes : 1-5 puis 24-89 et 91. Il n'y a PAS de ligne 90.
AFTU_OFFICIAL = {
    "1": "LAT DIOR- HLM GRAND YOFF",
    "2": "ROUTE PRINCIPALE PARCELLES - PETERSEN",
    "3": "YOFF - PETERSEN",
    "4": "YOFF VILLAGE - PETERSEN",
    "5": "PARCELLES ASSAINIES- PETERSEN",
    "24": "UCAD - NOTAIRE GUEDIAWAYE",
    "25": "PARCELLES ASSAINIES - PETERSEN",
    "26": "PARCELLES ASSAINIES - POST THIAROYE",
    "27": "MARCHE BOUBESS - PETERSEN",
    "28": "HAMO V/VI - PETERSEN",
    "29": "CITE NATION UNIES (CAMBERENE) - PETERSEN",
    "30": "GADAYE (GUEDIEWAYE) - GARE DE COLOBANE",
    "31": "TALLY ICOTAF X ROUTE DES NIAYES - HOPITAL ABASS NDAO",
    "32": "SAHM - SERIGNE ASSANE",
    "33": "COLOBANE - SERIGNE ASSANE",
    "34": "NORD FOIRE - LAT DIOR",
    "35": "NGOR - PIKINE TEXACO",
    "36": "MARCHE NDIAREME - NGOR",
    "37": "CITÉ APIX - UCAD (CLAUDEL)",
    "38": "CITE DES ENSEIGNANTS - SHAM",
    "39": "LAT-DIOR - DIAMALAYE",
    "40": "GRAND MBAO - PETERSEN",
    "41": "PETERSEN - ETAGE MADIALE",
    "42": "GADAYE (GUEDIEWAYE) - OUAKAM BAYE",
    "43": "OUAKAM - THIERNO NDIAYE",
    "44": "GRAND MBAO - OUAKAM",
    "45": "KOUNOUNE NGALAM - PARCELLES EGLISE",
    "46": "SDE SERIGNE ASSANE - LAT DIOR",
    "47": "LAT DIOR - ALMADIES",
    "48": "CITE SERIGNE MANSOUR - LAT DIOR",
    "49": "GADAYE - NGOR",
    "50": "PETERSEN - MALIKA CIMETIERE",
    "51": "JAXAAY - GARE DES BAUX MARAICHERS",
    "52": "BOUNTOU PIKINE - KEUR MASSAR",
    "53": "KEUR MASSAR - SEBIKOTANE",
    "54": "TERMINUS KEUR MASSAR (CITE MTOA) - UCAD",
    "55": "TERMINUS RUFISQUE SONADIS - PETERSEN",
    "56": "JAXAAY 2 - PETERSEN",
    "57": "LIBERTE 6 - RUFISQUE",
    "58": "SAHM - COMICO",
    "59": "DIAMALAYE - CITÉ GENDARMERIE (Jaxaay)",
    "60": "COLOBANE - BARGNY",
    "61": "ALMADIES - KEUR MASSAR",
    "62": "ARRET CHERIF (RUFISQUE) - PENC MI (GUEULE TAPEE)",
    "63": "TERMINUS CAMP MARCHAND RUFISQUE - STADE LSS",
    "64": "GUEDIAWAYE - RUFISQUE",
    "65": "COLOBANE - JAXAAY",
    "66": "YOFF - GOROM 1",
    "67": "OUAKAM - THIAWLENE RUFISQUE",
    "68": "YEUMBEUL - SEBIKOTANE",
    "69": "DIAMALAYE - TERMINUS TIVAOUANE PEUL",
    "70": "DAROUKHANE - JAXXAY 2",
    "71": "KEUR MASSAR - CLAUDEL",
    "72": "GUEDIAWAYE - KOUNOUNE",
    "73": "LAC ROSE - POSTE THIAROYE",
    "74": "TERMINUS BARGNY (GARE FERROVIAIRE) - TIVAOUNE PEUL",
    "75": "TERMINUS MALIKA (CITE SONATEL) - TERMINUS GARE ROUTIERE COLOBANE",
    "76": "SIPRES - CITE ASSURANCE",
    "77": "RUFISQUE - LIBERTE 5",
    "78": "DIAMAGUENE - LIBERTE 5",
    "79": "SANGALKAM - CAMBERENE",
    "80": "DIAMALAYE - DAROU THIOUB",
    "81": "BEAUX MARRAICHERS - TIVAOUNE PEUL",
    "82": "LAT DIOR - COMICO YEUMBEUL",
    "83": "RUFISQUE ARAFAT- ZONE DE CAPTAGE",
    "84": "UCAD - JAXAAY",
    "85": "BANOBA - LIBERTE 5",
    "86": "TOURNALOU BOUNE - TOUBAB DIALAW",
    "87": "BAMBILOR - MOSQUEE MASSALIKOU DJINANE",
    "88": "MTOA - LIBERTE 5",
    "89": "BARGNY - CROISEMENT NIAGUE (CITE SICAP)",
    "91": "APIX - DOUGAR",
}

# ============================================================ DDD opérateur
# demdikk.sn/info-voyageurs/, consultée le 2026-09-27.
# L'opérateur publie le NUMÉRO **et les deux terminus** de chaque ligne.
# 3 rubriques : Dessertes Gares du TER (7), Lignes Urbaines (11), Banlieue (21 codes).
DDD_OFFICIAL = {
    # --- Dessertes Gares du TER ---
    "501": "GARE DE DAKAR \u2194 PALAIS 2",
    "502A": "COLOBANE \u2194 UCAD",
    "502B": "COLOBANE \u2194 ABASS NDAO",
    "503A": "COLOBANE \u2194 MOLE 8",
    "503B": "COLOBANE \u2194 HYDROCARBURE",
    "504A": "GARE DIAMNIADIO \u2194 SPHERE MINISTERIEL",
    "504B": "SEBIKOTANE \u2194 GARE DIAMNIADIO",
    # --- Lignes Urbaines ---
    "1": "PARCELLES ASSAINIES \u2194 PLACE LECLERC",
    "4": "LIBERT\u00c9 5 \u2194 PLACE LECLERC",
    "7": "OUAKAM \u2194 PALAIS 2",
    "8": "A\u00c9ROPORT LSS \u2194 PALAIS 2",
    "9": "LIBERT\u00c9 6 \u2194 PALAIS 2",
    "10": "LIBERT\u00c9 5 \u2194 PALAIS 2",
    "13": "LIBERT\u00c9 5 \u2194 PALAIS 2",
    "18": "DIEUPPEUL \u2194 CENTRE-VILLE \u2194 DIEUPPEUL",
    "20": "DIEUPPEUL \u2194 CENTRE-VILLE \u2194 DIEUPPEUL",
    "121": "SCAT URBAM \u2194 LECLERC",
    "23": "PARCELLES ASSAINIES \u2194 PALAIS 1",
    # --- Lignes Banlieue ---
    "2": "DAROUKHANE \u2194 PLACE LECLERC",
    "5": "GU\u00c9DIAWAYE \u2194 PALAIS 1",
    "6": "CAMB\u00c9R\u00c8NE 2 \u2194 PALAIS 2",
    "11": "KEUR MASSAR \u2194 LAT DIOR",
    "12": "GU\u00c9DIAWAYE \u2194 PALAIS 1",
    "15A": "RUFISQUE \u2194 PALAIS 1",
    "15B": "RUFISQUE \u2194 PALAIS 1",
    "16A": "MALIKA \u2194 PALAIS 1",
    "16B": "MALIKA \u2194 PALAIS 1",
    "234": "JAXAAY \u2194 LECLERC",
    "233": "BAUX MARAICHERS \u2194 PALAIS 1",
    "232": "BAUX MARAICHERS \u2194 A\u00c9ROPORT LSS",
    "228": "TERMINUS RUFISQUE \u2194 YENNE",
    "227": "TERMINUS KEUR MASSAR \u2194 TERMINUS PARCELLES",
    "221": "GADAYE \u2194 ALMADIES",
    "220": "RUFISQUE \u2194 GU\u00c9DIAWAYE",
    "219": "DAROUKHANE \u2194 OUAKAM",
    "218": "THIAROYE \u2194 A\u00c9ROPORT LSS",
    "217": "THIAROYE \u2194 OUAKAM",
    "213": "RUFISQUE \u2194 DIEUPPEUL",
    "208": "BAYAKH \u2194 RUFISQUE",
}

# Rubrique de publication : seule la rubrique « Dessertes Gares du TER » établit
# explicitement une correspondance intermodale avec le TER.
DDD_SECTION = {
    **{k: "DESSERTES_GARES_TER" for k in ("501", "502A", "502B", "503A", "503B",
                                          "504A", "504B")},
    **{k: "URBAINE" for k in ("1", "4", "7", "8", "9", "10", "13", "18", "20", "121", "23")},
    **{k: "BANLIEUE" for k in ("2", "5", "6", "11", "12", "15A", "15B", "16A", "16B",
                               "234", "233", "232", "228", "227", "221", "220", "219",
                               "218", "217", "213", "208")},
}

# Lignes TAF TAF : l'opérateur publie un itinéraire et des premiers/derniers départs,
# mais ni numéro de ligne, ni liste d'arrêts, ni grille horaire complète.
DDD_TAFTAF = [
    {"itineraire": ("Terminus Ouakam – Mamelles – Croisement Almadies – Ngor – Yoff – "
                    "Rte de l'Aéroport – Foire – VDN – Direction Générale DDD – "
                    "Rond-Point JVC – Rond-Point Liberté 6 – Itinéraire 213 – "
                    "Police Grand Yoff – Pharmacie Patte d'Oie – Autoroute à Péage – "
                    "Diamniadio – AIBD"),
     "sens": "Ouakam \u2192 AIBD", "first_departure": "06:00", "last_departure": "21:00"},
    {"itineraire": "Même circuit, vers Sphère Ministérielle à Diamniadio",
     "sens": "Ouakam \u2192 Sphère Ministérielle", "first_departure": "05:45",
     "last_departure": "21:00"},
    {"itineraire": "Même circuit, sens retour",
     "sens": "AIBD \u2192 Ouakam", "first_departure": "06:00", "last_departure": "21:00"},
    {"itineraire": "Même circuit, sens retour",
     "sens": "Sphère Ministérielle \u2192 Ouakam", "first_departure": "06:00",
     "last_departure": "20:30"},
]

# ============================================================ normalisation
STOP = {"TERMINUS", "GARE", "ROUTE", "PRINCIPALE", "CITE", "CROISEMENT", "ARRET",
        "MOSQUEE", "HOPITAL", "DES", "DU", "DE", "LA", "LE", "X", "V", "VI", "SDE",
        "PEM", "GRAND", "GRANDE", "VILLAGE", "SONADIS", "SONATEL", "ROUTIERE"}

# Variantes orthographiques OBSERVEES entre PassBi et le site opérateur.
# Chaque entrée correspond à une divergence réellement constatée, jamais devinée.
ALIAS_WORD = {
    "PARCELLE": "PARCELLES", "MARAICHER": "MARAICHERS", "MARRAICHERS": "MARAICHERS",
    "MALICKA": "MALIKA", "SIPRESS": "SIPRES", "SIPRESSE": "SIPRES",
    "JAXAAYE": "JAXAAY", "JAXXAY": "JAXAAY", "DIAXAYE": "JAXAAY", "DIAXAAY": "JAXAAY",
    "DAROUHANE": "DAROUKHANE", "DAROUKANE": "DAROUKHANE",
    "GUEDIEWAYE": "GUEDIAWAYE", "GUEDIWAYE": "GUEDIAWAYE",
    "SEBIKHOTANE": "SEBIKOTANE", "TIVAOUNE": "TIVAOUANE",
    "THIAWLENE": "THIAROYE", "SHAM": "SAHM", "DJALAW": "DIALAW",
    "BAMBIBOR": "BAMBILOR", "POSTETHIAROYE": "THIAROYE", "POSTTHIAROYE": "THIAROYE",
    "MB": "BOUBESS", "MASSAR": "KEURMASSAR", "COMICOYEUMBEUL": "COMICO",
    "TAWFEEKH": "TAWFEKH", "GR": "YOFF",
    # Marqueurs de branche : le suffixe numérique désigne une variante du même lieu,
    # pas un lieu différent. Constaté sur JAXAAY 2 / GOROM 1 / CAMBERENE 2.
    "JAXAAY2": "JAXAAY", "JAXXAY2": "JAXAAY", "GOROM1": "GOROM",
    "CAMBERENE2": "CAMBERENE",
}


def norm(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^A-Z0-9 ]", " ", s.upper())
    return [w for w in s.split() if w and w not in STOP]


def squash(words):
    """« M T O A » -> « MTOA » ; « LIBERTE 5 » -> « LIBERTE5 »."""
    out, buf = [], ""
    for w in words:
        if len(w) == 1 and w.isalpha():
            buf += w
        else:
            if buf:
                out.append(buf); buf = ""
            if w.isdigit() and out:
                out[-1] += w
            else:
                out.append(w)
    if buf:
        out.append(buf)
    return out


def toks(side):
    words = squash(norm(side))
    out = {ALIAS_WORD.get(w, w) for w in words}
    full = "".join(words)
    if full in ALIAS_WORD:
        out.add(ALIAS_WORD[full])
    return {t for t in out if t not in STOP}


def termini(s):
    """Sépare les deux terminus d'une chaîne publiée par un opérateur.

    Séparateurs réellement observés :
      « A ↔ B »  (DDD)
      « A - B »  (AFTU, cas général)
      « A- B »   (AFTU : « LAT DIOR- HLM GRAND YOFF », « PARCELLES ASSAINIES- PETERSEN »,
                          « RUFISQUE ARAFAT- ZONE DE CAPTAGE »)

    Un tiret sans espace du tout (« CENTRE-VILLE », « LAT-DIOR ») fait partie du nom
    et n'est jamais un séparateur.
    """
    s = s.strip()
    parts = [p.strip() for p in re.split(r"\s*\u2194\s*", s) if p.strip()]
    if len(parts) == 1:
        parts = [p.strip() for p in re.split(r"\s+-\s+", s) if p.strip()]
    if len(parts) == 1:
        parts = [p.strip() for p in re.split(r"-\s+", s) if p.strip()]
    if len(parts) == 1:
        return s, s
    return parts[0], parts[-1]


def match_termini(pb_o, pb_d, op_o, op_d):
    """Retourne (verdict, tokens_communs, detail). Insensible à l'ordre des terminus."""
    po, pd_ = toks(pb_o), toks(pb_d)
    qo, qd = toks(op_o), toks(op_d)
    a = (po & qo) | (pd_ & qd)
    b = (po & qd) | (pd_ & qo)
    shared = a if len(a) >= len(b) else b
    side = "ordre direct" if len(a) >= len(b) else "ordre inversé"
    n = max(1, min(len(po) + len(pd_), len(qo) + len(qd)))
    if len(shared) >= 2 and len(shared) / n >= 0.5:
        return "TERMINI_MATCH", sorted(shared), side
    if len(shared) >= 1:
        return "PARTIAL_TERMINI", sorted(shared), side
    return "NUMBER_ONLY", [], side


def both_termini_match(pb_o, pb_d, op_o, op_d):
    """True si les DEUX terminus PassBi sont publiés par l'opérateur (ordre libre).

    C'est le critère exigé pour DOCUMENTED : la source publie le numéro ET les
    deux terminus. Un seul terminus commun ne suffit pas.
    """
    po, pd_ = toks(pb_o), toks(pb_d)
    qo, qd = toks(op_o), toks(op_d)
    direct = (po & qo) and (pd_ & qd)
    inverse = (po & qd) and (pd_ & qo)
    return bool(direct or inverse)


def official_candidates(num):
    """Codes opérateur correspondant à un numéro PassBi, variantes A/B incluses.

    L'opérateur publie 15A/15B, 16A/16B, 502A/502B, 503A/503B, 504A/504B alors que
    PassBi n'a qu'un seul 15, 16, 502, 503, 504. Le rapprochement n'est jamais
    automatique : il est signalé comme ambigu.
    """
    exact = [k for k in DDD_OFFICIAL if k == num]
    if exact:
        return exact, False
    variants = [k for k in DDD_OFFICIAL
                if k.startswith(num) and k[len(num):] in ("A", "B")]
    return variants, bool(variants)
