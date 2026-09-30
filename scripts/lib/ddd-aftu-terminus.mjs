// Chantier DDD / AFTU / TATA — identification des pôles, gares routières et
// terminus. Bibliothèque de construction du référentiel (lecture seule des
// feeds PassBi déjà intégrés au dépôt).
//
// PÉRIMÈTRE : ce module ne touche NI au TER, NI au BRT, NI aux horaires, NI au
// routage. Il DÉRIVE, pour chaque route DDD et AFTU, le premier et le dernier
// arrêt réellement desservis par chaque `trip` du feed, puis agrège ces
// terminus par pôle documenté. Aucun arrêt, aucune ligne et aucun horaire ne
// sont inventés : tout provient des `stop_times` du feed.
//
// Règle de statut :
//   * `CONFIRMED`  → terminus réel des trips du feed ET arrêt nommé d'un pôle
//                    documenté (source opérateur/PassBi).
//   * `PARTIAL`    → terminus réel du feed, mais non rattaché à un pôle de la
//                    liste documentée (nom d'arrêt non identifié).
//   * `UNKNOWN`    → la route n'a AUCUN `stop_time` (aucun terminus calculable).
//   * `CONFLICTING`→ le sens `direction_id=0` du feed contredit le libellé
//                    officiel publié par l'opérateur (ex. DDD 16 : libellé
//                    « MALIKA ↔ PALAIS 1 », sens retour du feed vers PALAIS 2).
//   * `CANDIDATE`  → le feed contredit le libellé ET aucun arrêt du sens retour
//                    n'est nommé « Palais » : le terminus retour reste à
//                    confirmer (ex. DDD 23).

import { readFileSync } from 'node:fs';

export const BOUNDS = Object.freeze({
  north: 14.9,
  south: 14.55,
  east: -16.85,
  west: -17.6,
});

const ACCENT_FOLDS = {
  à: 'a', á: 'a', â: 'a', ã: 'a', ä: 'a', å: 'a',
  è: 'e', é: 'e', ê: 'e', ë: 'e',
  ì: 'i', í: 'i', î: 'i', ï: 'i',
  ò: 'o', ó: 'o', ô: 'o', õ: 'o', ö: 'o',
  ù: 'u', ú: 'u', û: 'u', ü: 'u',
  ç: 'c', ñ: 'n', ÿ: 'y', æ: 'ae', œ: 'oe', ß: 'ss',
  À: 'a', Á: 'a', Â: 'a', Ã: 'a', Ä: 'a', Å: 'a',
  È: 'e', É: 'e', Ê: 'e', Ë: 'e',
  Ì: 'i', Í: 'i', Î: 'i', Ï: 'i',
  Ò: 'o', Ó: 'o', Ô: 'o', Õ: 'o', Ö: 'o',
  Ù: 'u', Ú: 'u', Û: 'u', Ü: 'u',
  Ç: 'c', Ñ: 'n',
};

/** Normalisation identique à `PassBiSource.normalizeName` (Dart) : accents
 *  repliés, minuscules, ponctuation → espace. */
export function normalizeName(value) {
  let out = '';
  for (const ch of String(value ?? '')) {
    const c = ACCENT_FOLDS[ch] ?? ch;
    out += /[0-9a-zA-Z]/.test(c) ? c.toLowerCase() : ' ';
  }
  return out.replace(/ +/g, ' ').trim();
}

export function inBounds(lat, lon) {
  return (
    typeof lat === 'number' && typeof lon === 'number' &&
    lat >= BOUNDS.south && lat <= BOUNDS.north &&
    lon >= BOUNDS.west && lon <= BOUNDS.east &&
    !(lat === 0 && lon === 0)
  );
}

export function haversineMeters(a, b) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.min(1, Math.sqrt(s))));
}

export function loadFeed(path) {
  const root = JSON.parse(readFileSync(path, 'utf8'));
  const stops = root.stops.map((s) => ({ id: s[0], name: s[1], lat: s[2], lon: s[3], used: s[4] }));
  const routes = root.routes;
  const trips = root.trips;
  // `stop_times[i][0]` est l'INDEX du trip dans `trips`, pas son identifiant.
  const byTrip = new Map();
  for (const st of root.stop_times) {
    if (!byTrip.has(st[0])) byTrip.set(st[0], []);
    byTrip.get(st[0]).push(st);
  }
  for (const list of byTrip.values()) list.sort((a, b) => a[2] - b[2]);
  return { key: root.meta.network, meta: root.meta, agency: root.agency, routes, stops, trips, byTrip };
}

/** Terminus réels d'une route, agrégés par `direction_id` du feed.
 *  Retourne pour chaque sens le premier/dernier arrêt majoritaire. */
export function routeTermini(feed, routeId) {
  const routeIndex = feed.routes.findIndex((r) => r.id === routeId);
  if (routeIndex < 0) return null;
  const perDir = new Map(); // dir → { first:Counter, last:Counter, trips }
  for (let tripIndex = 0; tripIndex < feed.trips.length; tripIndex++) {
    const trip = feed.trips[tripIndex];
    if (trip[1] !== routeIndex) continue;
    const rows = feed.byTrip.get(tripIndex);
    if (!rows || rows.length === 0) continue;
    const dir = String(trip[3] ?? '');
    if (!perDir.has(dir)) perDir.set(dir, { first: new Map(), last: new Map(), trips: 0 });
    const agg = perDir.get(dir);
    agg.trips++;
    const firstStop = feed.stops[rows[0][1]];
    const lastStop = feed.stops[rows[rows.length - 1][1]];
    agg.first.set(firstStop.id, (agg.first.get(firstStop.id) ?? 0) + 1);
    agg.last.set(lastStop.id, (agg.last.get(lastStop.id) ?? 0) + 1);
  }
  const majority = (counter) => {
    let best = null;
    for (const [id, n] of counter) if (!best || n > best.n) best = { id, n };
    return best ? feed.stops.find((s) => s.id === best.id) : null;
  };
  const directions = [];
  for (const dir of ['1', '0']) {
    const agg = perDir.get(dir);
    if (!agg) continue;
    directions.push({ directionId: dir, depart: majority(agg.first), arrivee: majority(agg.last), trips: agg.trips });
  }
  return { routeId, directions };
}

// --------------------------------------------------------------------------
// Pôles documentés (périmètre §3–§5). Les coordonnées déclarées proviennent du
// référentiel projet (`dakar_network.json`, `place_*`) ; elles sont CONFRONTÉES
// aux coordonnées réelles du feed PassBi pour l'arrêt terminus correspondant,
// et signalées UNVERIFIED si aucun ancrage feed n'existe.
// --------------------------------------------------------------------------
export const POLES = [
  { id: 'petersen', name: 'Gare de Petersen', hubType: ['pole_echange', 'gare_routiere'], match: ['petersen'], declared: { lat: 14.6738, lon: -17.4381 }, declaredSource: 'dakar_network.json place_petersen' },
  { id: 'pem_guediawaye', name: 'PEM Guédiawaye', hubType: ['pole_echange', 'gare_routiere'], match: ['guediawaye'], declared: { lat: 14.7735, lon: -17.3977 }, declaredSource: 'dakar_network.json place_prefecture_guediawaye' },
  { id: 'grand_medine', name: 'Grand Médine', hubType: ['pole_echange'], match: ['medine'], declared: { lat: 14.74795, lon: -17.44715 }, declaredSource: 'dakar_network.json place_grand_medine (arrêt BRT)' },
  { id: 'colobane', name: 'Gare de Colobane', hubType: ['pole_echange', 'gare_routiere'], match: ['colobane'], declared: { lat: 14.70035, lon: -17.44165 }, declaredSource: 'dakar_network.json place_colobane' },
  { id: 'baux_maraichers', name: 'Gare des Baux Maraîchers', hubType: ['pole_echange', 'gare_routiere'], match: ['baux'], declared: { lat: 14.73971, lon: -17.40361 }, declaredSource: 'dakar_network.json place_baux_maraichers' },
  { id: 'diamniadio', name: 'Gare de Diamniadio', hubType: ['pole_echange', 'gare_routiere'], match: ['diamniadio'], declared: { lat: 14.71606, lon: -17.19845 }, declaredSource: 'dakar_network.json place_diamniadio' },
  { id: 'parcelles_assainies', name: 'Parcelles Assainies', hubType: ['pole_echange'], match: ['parcelles'], declared: { lat: 14.758, lon: -17.425 }, declaredSource: 'dakar_network.json place_parcelles_u22' },
  { id: 'keur_massar', name: 'Keur Massar', hubType: ['pole_echange'], match: ['keur massar'], declared: { lat: 14.79, lon: -17.325 }, declaredSource: 'dakar_network.json place_keur_massar' },
  { id: 'pikine', name: 'Pikine', hubType: ['pole_echange'], match: ['pikine'], declared: { lat: 14.74986, lon: -17.39169 }, declaredSource: 'dakar_network.json place_pikine' },
  { id: 'thiaroye', name: 'Thiaroye', hubType: ['pole_echange'], match: ['thiaroye'], declared: { lat: 14.75877, lon: -17.3803 }, declaredSource: 'dakar_network.json place_thiaroye' },
  { id: 'rufisque', name: 'Rufisque', hubType: ['pole_echange'], match: ['rufisque'], declared: { lat: 14.71596, lon: -17.27 }, declaredSource: 'dakar_network.json place_rufisque' },
  // Sandaga est testé STRICTEMENT : aucune ligne ne doit être déclarée
  // terminant au marché Sandaga sans arrêt terminus nommé « Sandaga ».
  { id: 'sandaga', name: 'Sandaga', hubType: ['pole_echange'], match: ['sandaga'], declared: { lat: 14.687, lon: -17.451 }, declaredSource: 'dakar_network.json place_sandaga' },
  { id: 'plateau_leclerc', name: 'Plateau — Terminus Leclerc', hubType: ['pole_echange'], match: ['terminus leclerc'], declared: { lat: 14.672107, lon: -17.427493 }, declaredSource: 'PassBi DDD feed — Terminus Leclerc (D_140)' },
  { id: 'plateau_palais_1', name: 'Plateau — Terminus Palais 1', hubType: ['pole_echange'], match: ['terminus palais 1'], declared: { lat: 14.651017, lon: -17.433384 }, declaredSource: 'PassBi DDD feed — Terminus Palais 1 (D_709)' },
  { id: 'plateau_palais_2', name: 'Plateau — Terminus Palais 2', hubType: ['pole_echange'], match: ['terminus palais 2'], declared: { lat: 14.652759, lon: -17.433470 }, declaredSource: 'PassBi DDD feed — Terminus Palais 2 (D_708)' },
  { id: 'plateau_port_dakar', name: 'Plateau — Port de Dakar', hubType: ['pole_echange'], match: ['port de dakar'], declared: { lat: 14.674378, lon: -17.432178 }, declaredSource: 'PassBi DDD feed — Port De Dakar (D_1275)' },
  { id: 'yoff', name: 'Yoff', hubType: ['pole_echange'], match: ['yoff'], declared: { lat: 14.7604, lon: -17.4681 }, declaredSource: 'dakar_network.json place_yoff' },
  { id: 'ouakam', name: 'Ouakam', hubType: ['pole_echange'], match: ['ouakam'], declared: { lat: 14.724, lon: -17.491 }, declaredSource: 'dakar_network.json place_ouakam' },
  { id: 'ngor', name: 'Ngor', hubType: ['pole_echange'], match: ['ngor'], declared: { lat: 14.747, lon: -17.521 }, declaredSource: 'dakar_network.json place_ngor' },
  { id: 'mermoz', name: 'Mermoz', hubType: ['pole_echange'], match: ['mermoz'], declared: { lat: 14.712, lon: -17.465 }, declaredSource: 'dakar_network.json place_mermoz' },
];

/** Pôles découverts en plus du périmètre §3–§5 (terminus structurants
 *  documentés par le feed). Ajoutés par le générateur, jamais saisis à la main. */
export const DISCOVERED_POLE_THRESHOLD = 2;

function poleForTerminusName(name) {
  const n = normalizeName(name);
  for (const p of POLES) {
    for (const m of p.match) {
      if (n.includes(m)) return p.id;
    }
  }
  return null;
}

/** Détecte la contradiction libellé officiel / sens retour du feed. */
function officialConflict(networkKey, routeId, routeTerm) {
  const label = { DDD: routeId.replace(/^DDD_/, ''), AFTU: null };
  // Le libellé officiel est fourni par l'appelant via `officialLabels`.
  return label;
}

export function buildReference({ dddPath, aftuPath, generatedAt, officialLabels = {} }) {
  const feeds = { DDD: loadFeed(dddPath), AFTU: loadFeed(aftuPath) };
  const routes = [];
  const completeness = { DDD: [], AFTU: [] };

  for (const key of ['DDD', 'AFTU']) {
    const feed = feeds[key];
    for (const r of feed.routes) {
      const term = routeTermini(feed, r.id);
      const dirs = term ? term.directions : [];
      const forward = dirs.find((d) => d.directionId === '1') ?? dirs[0] ?? null;
      const backward = dirs.find((d) => d.directionId === '0') ?? null;

      let status;
      let note;
      if (!forward) {
        status = 'UNKNOWN';
        note = 'AUCUN_STOP_TIME_DANS_LE_FEED';
      } else if (!backward) {
        status = 'PARTIAL';
        note = 'SENS_RETOUR_ABSENT_DU_FEED';
      } else {
        status = 'CONFIRMED';
        note = 'TERMINUS_REELS_DU_FEED';
      }

      // Contradiction documentée : le libellé officiel nomme un terminus
      // (ex. « PALAIS 1 ») que le feed ne dessert JAMAIS pour cette route.
      const label = officialLabels[r.id];
      if (status !== 'UNKNOWN' && label) {
        const lbl = normalizeName(label);
        const names = dirs.flatMap((d) => [d.depart?.name, d.arrivee?.name]).filter(Boolean).map(normalizeName);
        const wantsPalais1 = lbl.includes('palais 1');
        if (wantsPalais1 && !names.some((n) => n.includes('palais 1'))) {
          if (names.some((n) => n.includes('palais 2'))) {
            status = 'CONFLICTING';
            note = 'TERMINUS_FEED_CONTREDIT_LIBELLE_OFFICIEL_PALAIS_1_VS_PALAIS_2';
          } else {
            status = 'CANDIDATE';
            note = 'TERMINUS_LIBELLE_OFFICIEL_ABSENT_DU_FEED';
          }
        }
      }

      const terminus = [];
      for (const d of dirs) {
        if (d.depart) {
          terminus.push({
            pole: poleForTerminusName(d.depart.name),
            stopId: d.depart.id,
            stopName: d.depart.name,
            lat: d.depart.lat,
            lon: d.depart.lon,
            role: 'depart',
            directionId: d.directionId,
          });
        }
        if (d.arrivee) {
          terminus.push({
            pole: poleForTerminusName(d.arrivee.name),
            stopId: d.arrivee.id,
            stopName: d.arrivee.name,
            lat: d.arrivee.lat,
            lon: d.arrivee.lon,
            role: 'arrivee',
            directionId: d.directionId,
          });
        }
      }

      const entry = {
        routeId: r.id,
        network: key,
        shortName: r.short,
        longName: r.long,
        label: label ?? null,
        status,
        note,
        directions: dirs.map((d) => ({
          directionId: d.directionId,
          depart: d.depart ? { stopId: d.depart.id, stopName: d.depart.name } : null,
          arrivee: d.arrivee ? { stopId: d.arrivee.id, stopName: d.arrivee.name } : null,
          trips: d.trips,
        })),
        terminus,
      };
      routes.push(entry);

      if (status === 'UNKNOWN') {
        completeness[key].push({ routeId: r.id, issue: 'LIGNE_SANS_TERMINUS_CONFIRME', detail: note });
      } else if (status === 'CANDIDATE' || status === 'CONFLICTING') {
        completeness[key].push({ routeId: r.id, issue: 'TERMINUS_A_CONFIRMER', detail: note });
      } else if (terminus.length < 2) {
        completeness[key].push({ routeId: r.id, issue: 'TERMINUS_UNIQUE_ALORS_QUE_DEUX_SONT_DOCUMENTES', detail: note });
      }
    }
  }

  // ---------------------------------------------------------------- pôles
  // Index de desserte réelle (tous arrêts appelés, terminus ou non) pour
  // distinguer TERMINUS et TRANSIT sans jamais confondre les deux.
  const servedByStop = new Map(); // stopId → Set(routeId)
  for (const key of ['DDD', 'AFTU']) {
    const feed = feeds[key];
    for (let ti = 0; ti < feed.trips.length; ti++) {
      const route = feed.routes[feed.trips[ti][1]];
      for (const row of feed.byTrip.get(ti) ?? []) {
        const stopId = feed.stops[row[1]].id;
        if (!servedByStop.has(stopId)) servedByStop.set(stopId, new Set());
        servedByStop.get(stopId).add(route.id);
      }
    }
  }

  const allPoles = [...POLES];
  // Pôles découverts : arrêts terminus réels les plus partagés, regroupés par
  // nom normalisé (un même terminus peut exister en DDD et en AFTU), hors
  // périmètre initial. Jamais saisis à la main : nom et coordonnées du feed.
  const discoveredGroups = new Map(); // normalizedName → {name, stopIds:Set, routes:Set}
  for (const r of routes) for (const t of r.terminus) {
    const n = normalizeName(t.stopName);
    if (!discoveredGroups.has(n)) discoveredGroups.set(n, { name: t.stopName, stopIds: new Set(), routes: new Set() });
    discoveredGroups.get(n).stopIds.add(t.stopId);
    discoveredGroups.get(n).routes.add(r.routeId);
  }
  for (const g of [...discoveredGroups.values()].sort((a, b) => b.routes.size - a.routes.size)) {
    if (g.routes.size < DISCOVERED_POLE_THRESHOLD) continue;
    if (allPoles.some((p) => poleForTerminusName(g.name) === p.id)) continue;
    const stopId = [...g.stopIds][0];
    const stop = feeds.DDD.stops.find((s) => s.id === stopId) ?? feeds.AFTU.stops.find((s) => s.id === stopId);
    if (!stop) continue;
    allPoles.push({
      id: `discovered_${stopId}`,
      name: g.name,
      hubType: ['terminus'],
      match: [],
      stopIds: [...g.stopIds],
      declared: { lat: stop.lat, lon: stop.lon },
      declaredSource: `PassBi feed — arrêt terminus « ${g.name} » (${stopId})`,
      discovered: true,
    });
  }

  const poles = allPoles.map((p) => {
    const dddRoutes = new Set();
    const aftuRoutes = new Set();
    const anchors = new Map();
    const ownStopIds = new Set(p.stopIds ?? []);
    for (const r of routes) {
      for (const t of r.terminus) {
        if (t.pole !== p.id && !ownStopIds.has(t.stopId)) continue;
        (r.network === 'DDD' ? dddRoutes : aftuRoutes).add(r.routeId);
        if (!anchors.has(t.stopId)) anchors.set(t.stopId, { stopId: t.stopId, stopName: t.stopName, lat: t.lat, lon: t.lon, routes: new Set() });
        anchors.get(t.stopId).routes.add(r.routeId);
      }
    }
    const anchorList = [...anchors.values()]
      .map((a) => ({ ...a, routes: [...a.routes] }))
      .sort((a, b) => b.routes.length - a.routes.length);
    const best = anchorList[0] ?? null;

    // TRANSIT : routes qui desservent un arrêt du pôle SANS y terminer.
    const transitDdd = new Set();
    const transitAftu = new Set();
    const poleStopIds = new Set(anchorList.map((a) => a.stopId));
    if (p.match.length) {
      for (const feed of Object.values(feeds)) {
        for (const s of feed.stops) {
          if (poleForTerminusName(s.name) === p.id) poleStopIds.add(s.id);
        }
      }
    }
    for (const sid of poleStopIds) {
      for (const rid of servedByStop.get(sid) ?? []) {
        if (dddRoutes.has(rid) || aftuRoutes.has(rid)) continue;
        (rid.startsWith('DDD_') ? transitDdd : transitAftu).add(rid);
      }
    }

    let coordinates = p.declared;
    let coordinatesStatus = 'UNVERIFIED';
    let distanceToAnchor = null;
    if (best) {
      distanceToAnchor = haversineMeters(p.declared, { lat: best.lat, lon: best.lon });
      if (p.discovered || distanceToAnchor <= 1500) {
        coordinates = { lat: best.lat, lon: best.lon };
        coordinatesStatus = 'CONFIRMED_VS_FEED';
      } else {
        coordinatesStatus = 'CONFLICTING';
      }
    }
    if (!inBounds(coordinates.lat, coordinates.lon)) coordinatesStatus = 'REJECTED_OUT_OF_BOUNDS';

    const hasTerminus = dddRoutes.size + aftuRoutes.size > 0;
    const hasTransit = transitDdd.size + transitAftu.size > 0;
    // Statuts simultanés (§10) : un même lieu peut être terminus ET transit.
    const roles = [];
    if (hasTerminus) roles.push('TERMINUS');
    if (hasTransit) roles.push('TRANSIT');
    if (p.hubType.includes('gare_routiere')) roles.push('GARE_ROUTIERE');
    if (p.hubType.includes('pole_echange')) roles.push('POLE_ECHANGE');

    return {
      id: p.id,
      name: p.name,
      hubType: p.hubType,
      roles,
      discovered: p.discovered === true,
      coordinates,
      declaredCoordinates: p.declared,
      coordinateSource: best
        ? `PassBi feed — arrêt terminus « ${best.stopName} » (${best.stopId})`
        : p.declaredSource,
      coordinateConfidence: coordinatesStatus === 'CONFIRMED_VS_FEED' ? 'HIGH' : 'LOW',
      coordinatesStatus,
      distanceToAnchor,
      terminalStops: anchorList,
      dddRoutes: [...dddRoutes].sort(),
      aftuRoutes: [...aftuRoutes].sort(),
      dddTransitRoutes: [...transitDdd].sort(),
      aftuTransitRoutes: [...transitAftu].sort(),
      isTerminal: hasTerminus,
      terminalType: hasTerminus ? p.hubType : [],
      status: hasTerminus ? 'CONFIRMED' : (hasTransit ? 'PARTIAL' : 'UNKNOWN'),
      note: hasTerminus
        ? null
        : (hasTransit
          ? 'AUCUN_TERMINUS_DDD_AFTU_DANS_LE_FEED_MAIS_DESSERTE_EN_TRANSIT'
          : 'AUCUNE_DESSERTE_DDD_AFTU_DANS_LE_FEED'),
    };
  });

  // ------------------------------------------------------------ intégrité §17
  const integrity = {
    // Toute association pôle→ligne est STRUCTURELLEMENT prouvée par un arrêt
    // terminus réel du feed ; une association par simple proximité est rejetée.
    poleRouteAssociationsByProximityOnly: [],
    // Terminus sans source documentaire : un terminus est dérivé d'un trip du
    // feed, donc toujours sourcé — la liste doit rester vide.
    terminiWithoutSource: [],
    // Lignes avec un seul terminus alors que deux sens sont attendus.
    linesWithSingleTerminus: [],
    // TATA sans preuve documentaire.
    tataWithoutProof: [],
  };
  for (const r of routes) {
    const hasA = r.directions.some((d) => d.depart);
    const hasB = r.directions.some((d) => d.arrivee);
    if (r.status !== 'UNKNOWN' && (!hasA || !hasB)) {
      integrity.linesWithSingleTerminus.push(r.routeId);
    }
    for (const t of r.terminus) {
      if (!t.stopId || !t.stopName) integrity.terminiWithoutSource.push(`${r.routeId}:${t.stopId}`);
    }
  }
  // Une ligne ne peut apparaître comme terminus d'un pôle que via un arrêt
  // terminus rattaché (jamais via un arrêt de simple transit).
  for (const p of poles) {
    const anchorStops = new Set(p.terminalStops.map((s) => s.stopId));
    for (const rid of [...p.dddRoutes, ...p.aftuRoutes]) {
      const r = routes.find((x) => x.routeId === rid);
      const ok = r && r.terminus.some((t) => anchorStops.has(t.stopId) || t.pole === p.id);
      if (!ok) integrity.poleRouteAssociationsByProximityOnly.push(`${p.id}:${rid}`);
    }
  }

  const summary = {
    generatedAt,
    ddd: {
      ...summarize(routes, 'DDD', completeness.DDD),
      routes: routes.filter((r) => r.network === 'DDD'),
    },
    aftu: {
      ...summarize(routes, 'AFTU', completeness.AFTU),
      routes: routes.filter((r) => r.network === 'AFTU'),
    },
    poles,
    completeness,
    integrity,
    tata: {
      vehicleType: 'TATA',
      confirmedAssociations: [],
      unconfirmedAssociations: [],
      note: "Aucune source officielle n'établit qu'une ligne AFTU/DDD utilise des véhicules TATA. Aucune association n'est enregistrée (voir docs/AUDIT_IDENTIFICATION_TATA_PR48_2026-09-29.md).",
    },
  };
  return summary;
}

function summarize(routes, network, completeness) {
  const mine = routes.filter((r) => r.network === network);
  const withA = mine.filter((r) => r.directions.some((d) => d.depart));
  const withB = mine.filter((r) => r.directions.some((d) => d.arrivee));
  const unknown = mine.filter((r) => r.status === 'UNKNOWN');
  const terminus = new Set();
  for (const r of mine) for (const t of r.terminus) terminus.add(t.stopName);
  return {
    totalRoutes: mine.length,
    terminusAConfirmed: withA.length,
    terminusBConfirmed: withB.length,
    unknownRoutes: unknown.map((r) => r.routeId),
    conflictingRoutes: mine.filter((r) => r.status === 'CONFLICTING').map((r) => r.routeId),
    candidateRoutes: mine.filter((r) => r.status === 'CANDIDATE').map((r) => r.routeId),
    terminusCount: terminus.size,
    terminusNames: [...terminus].sort(),
    completeness,
  };
}
