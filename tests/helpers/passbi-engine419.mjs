// Lot 4.19 — Miroir fonctionnel du moteur PassBi (Dart) pour tests Node.
//
// Port fidèle 1:1 de gtfs_source.dart / passbi_source.dart / routing_engine.dart
// tel que CORRIGÉ par le Lot 4.19 :
//   * nextDepartureSec : uniquement les départs EMBARQUABLES (le trip doit
//     continuer après l'arrêt — les lignes terminus sont des arrivées de
//     trip fini, pas des départs) ;
//   * passage à J+1..J+6 (aucun départ restant aujourd'hui → service du
//     lendemain ; services/exceptions recalculés par jour) ;
//   * ScheduleProvider : union plateforme mappée + plateformes sœurs du
//     même réseau reliées par un lien documenté du crosswalk ;
//   * routage : passe J et J+1 (temps absolus, départs/arrêts affichables
//     via modulo 1440) ; correspondance seulement si le 2e départ est
//     atteignable (arrivée 1re véhicule + marche ≤ départ 2e véhicule).
import { readFileSync } from 'node:fs';

const BASE = 'flutter-src/assets/data/passbi';
const FILES = { TER: 'ter.json', BRT: 'brt.json', DDD: 'ddd.json', AFTU: 'aftu.json' };

export function loadAll() {
  const networks = {};
  for (const [key, file] of Object.entries(FILES)) {
    const n = JSON.parse(readFileSync(`${BASE}/${file}`, 'utf8'));
    n._key = key;
    n._stopById = new Map(n.stops.map((s, i) => [s[0], i]));
    n._routeById = new Map(n.routes.map((r, i) => [r.id, i]));
    const byStop = new Map();
    const byTrip = new Map();
    n.stop_times.forEach((st) => {
      if (!byStop.has(st[1])) byStop.set(st[1], []);
      byStop.get(st[1]).push(st);
      if (!byTrip.has(st[0])) byTrip.set(st[0], []);
      byTrip.get(st[0]).push(st);
    });
    for (const list of byStop.values()) list.sort((a, b) => a[4] - b[4]);
    for (const list of byTrip.values()) list.sort((a, b) => a[2] - b[2]);
    n._byStop = byStop;
    n._byTrip = byTrip;
    networks[key] = n;
  }
  const cw = JSON.parse(readFileSync(`${BASE}/crosswalk.json`, 'utf8'));
  // Verrouillage Lot 4.21 — miroir du parseur Dart (CrosswalkParser) : seuls
  // les liens de correspondance DOCUMENTÉS (nom vérifié + distance bornée,
  // réseaux couverts par les feeds) entrent dans `cw.transfers`. Une proximité
  // seule, un lien sans nom vérifié ou une clé hors feeds (TATA) est rejeté :
  // le moteur ne peut pas l'utiliser comme correspondance.
  const DOCUMENTED_TRANSFER_METHODS = ['NOM_IDENTIQUE_PROXIMITE', 'INCLUSION_NOM_PROXIMITE'];
  const netOf = (k) => { const i = k.indexOf(':'); return i > 0 ? k.slice(0, i) : null; };
  cw.transfers = (cw.transfers ?? []).filter((t) =>
    DOCUMENTED_TRANSFER_METHODS.includes(t.method)
    && typeof t.name === 'string' && t.name.trim() !== ''
    && Number.isFinite(t.meters) && t.meters >= 0 && t.meters <= 500
    && t.from !== t.to
    && FILES[netOf(t.from)] !== undefined && FILES[netOf(t.to)] !== undefined);
  return { networks, cw };
}

export function activeServices(net, serviceIdx, day) {
  if (serviceIdx < 0) return false;
  const svc = net.services[serviceIdx];
  const ymd = `${day.getUTCFullYear()}${String(day.getUTCMonth() + 1).padStart(2, '0')}${String(day.getUTCDate()).padStart(2, '0')}`;
  for (const [id, date, type] of net.exceptions) {
    if (id === svc[0] && date === ymd) return type === 1;
  }
  const wd = (day.getUTCDay() + 6) % 7; // lun=0
  return (svc[1] & (1 << wd)) !== 0;
}

function tripContinues(net, st) {
  const tl = net._byTrip.get(st[0]);
  if (!tl) return false;
  return tl.some((x) => x[2] > st[2]);
}

/// Prochain départ embarquable, en secondes ABSOLUES depuis minuit du jour
/// demandé (> 86400 = service J+1..J+6). `routeIds` ensemble de route_ids.
/// `stops` un ou plusieurs plateformes (union mappé + sœurs, cf. provider).
export function nextDepartureAbs(net, routeIds, stopIds, day0, afterSec, { maxDays = 7, rideableOnly = true } = {}) {
  const routeIdx = new Set();
  for (const id of routeIds) {
    const i = net._routeById.get(id);
    if (i === undefined) return null;
    routeIdx.add(i);
  }
  const stopIdxs = [];
  for (const sid of stopIds) {
    const i = net._stopById.get(sid);
    if (i === undefined) return null;
    stopIdxs.push(i);
  }
  for (let offset = 0; offset < maxDays; offset++) {
    const day = new Date(Date.UTC(day0.year, day0.month - 1, day0.day) + offset * 86400000);
    const from = offset === 0 ? afterSec : 0;
    let best = null;
    for (const si of stopIdxs) {
      const list = net._byStop.get(si);
      if (!list) continue;
      for (const st of list) {
        if (st[4] < from) continue;
        if (best !== null && st[4] >= best) break; // trié par dep
        const trip = net.trips[st[0]];
        if (!routeIdx.has(trip[1])) continue;
        if (!activeServices(net, trip[2], day)) continue;
        if (rideableOnly && !tripContinues(net, st)) continue;
        if (best === null || st[4] < best) best = st[4];
      }
    }
    if (best !== null) return best + offset * 86400;
  }
  return null;
}

/// Valeur brute (ANCIEN comportement buggé) — conservée pour démonstration.
export function nextDepartureRawBuggy(net, routeIds, stopId, day0, afterSec) {
  const routeIdx = new Set(routeIds.map((id) => net._routeById.get(id)));
  const si = net._stopById.get(stopId);
  let best = null;
  for (const st of net._byStop.get(si) ?? []) {
    if (st[4] < afterSec) continue;
    const trip = net.trips[st[0]];
    if (!routeIdx.has(trip[1])) continue;
    const day = new Date(Date.UTC(day0.year, day0.month - 1, day0.day));
    if (!activeServices(net, trip[2], day)) continue;
    if (best === null || st[4] < best) best = st[4];
  }
  return best;
}

export function splitComposite(c) {
  const i = c.indexOf(':');
  if (i <= 0 || i >= c.length - 1) return null;
  return [c.slice(0, i), c.slice(i + 1)];
}

/// Plateformes : mappée + sœurs (même réseau, lien documenté crosswalk).
export function stopCandidates(cw, compositeStopId) {
  const netKey = compositeStopId.split(':')[0];
  const out = new Set([compositeStopId]);
  for (const t of cw.transfers) {
    if (t.from === compositeStopId && t.to.startsWith(`${netKey}:`)) out.add(t.to);
    else if (t.to === compositeStopId && t.from.startsWith(`${netKey}:`)) out.add(t.from);
  }
  return out;
}

/// Miroir ScheduleProvider.departureAt → {status, depAbs, waitMin, stops[]} |
/// null (non mappé) — identique à la chaîne Dart (mapping crosswalk,
/// plateformes sœurs, départ embarquable, rollover 7 j).
export function providerDeparture(all, dakarRouteId, dakarStopId, at) {
  const { networks, cw } = all;
  const mapping = cw.routes[dakarRouteId];
  if (!mapping || mapping.status !== 'MAPPED' || !mapping.network) return null;
  const sm = (cw.stops[dakarRouteId] || {})[dakarStopId];
  if (!sm) return null;
  const base = splitComposite(sm.pb);
  if (!base) return null;
  const net = networks[base[0]];
  if (!net) return null;
  const day0 = new Date(Date.UTC(at.year, at.month - 1, at.day));
  const after = at.hour * 3600 + at.minute * 60 + at.second;
  let best = null;
  let usedStop = null;
  for (const cand of stopCandidates(cw, sm.pb)) {
    const p = splitComposite(cand);
    if (!p || p[0] !== base[0]) continue;
    const dep = nextDepartureAbs(net, mapping.pbRouteIds, [p[1]], day0, after);
    if (dep !== null && (best === null || dep < best)) {
      best = dep;
      usedStop = cand;
    }
  }
  if (best === null) {
    return { status: 'UNKNOWN', depAbs: null, waitMin: null, stop: null };
  }
  return {
    status: 'SCHEDULED',
    depAbs: best,
    waitMin: Math.floor((best - after) / 60),
    stop: usedStop,
    routeIds: mapping.pbRouteIds,
    network: mapping.network,
  };
}

// ------------------------------------------------------------------ moteur
function* linksFrom(cw, key) {
  // Identique au Dart : TOUS les liens documentés (marche inter-réseaux
  // incluse — c'est le mécanisme de correspondance), sans filtre réseau.
  for (const t of cw.transfers) {
    if (t.from === key) {
      yield [t.to, Math.max(1, Math.floor(t.meters / 80)) * 60, t];
    } else if (t.to === key) {
      yield [t.from, Math.max(1, Math.floor(t.meters / 80)) * 60, t];
    }
  }
}

/// Miroir PassBiRoutingEngine.planJourneys (passes J et J+1, temps absolus).
/// Retourne trajets triés par arrivée : {legs:[{network,routeId,tripId,
/// fromStopId,toStopId,fromStopName,toStopName,depSec,arrSec,headsign}],
/// departureSec, arrivalSec, transferCount, originKey, destinationKey}.
export function planJourneys(all, fromKeys, toKeys, at, {
  horizonSec = 6 * 3600, maxTransfers = 2, maxExplorations = 6000, maxResults = 4,
} = {}) {
  const { networks, cw } = all;
  if (fromKeys.size === 0 || toKeys.size === 0) return [];
  const day0 = Date.UTC(at.year, at.month - 1, at.day);
  const startSec = at.hour * 3600 + at.minute * 60 + at.second;
  const deadline = startSec + horizonSec;
  const results = [];
  const seenGoal = new Set();

  for (let shift = 0; shift <= 1; shift++) {
    if (results.length >= maxResults) break;
    const day = new Date(day0 + shift * 86400000);
    let explorations = 0;
    let frontier = [...fromKeys].map((k) => ({ key: k, t: startSec, legs: [] }));
    const bestAt = new Map();
    while (frontier.length > 0 && explorations < maxExplorations) {
      frontier.sort((a, b) => a.t - b.t);
      const nextFrontier = [];
      for (const state of frontier) {
        explorations++;
        if (explorations > maxExplorations) break;
        if (state.t > deadline) continue;
        if (state.legs.length > 0 && toKeys.has(state.key) && !seenGoal.has(state.key)) {
          seenGoal.add(state.key);
          results.push({
            legs: state.legs,
            originKey: state.legs[0].fromStopId,
            destinationKey: state.key,
            departureSec: state.legs[0].depSec,
            arrivalSec: state.t,
            transferCount: state.legs.length - 1,
          });
          continue;
        }
        const boardings = new Map([[state.key, 0]]);
        for (const [alias, walk, link] of linksFrom(cw, state.key)) {
          boardings.set(alias, walk);
        }
        for (const [boardKey, walk] of boardings) {
          const departAt = state.t + walk;
          if (departAt > deadline) continue;
          const parts = splitComposite(boardKey);
          if (!parts) continue;
          const net = networks[parts[0]];
          if (!net) continue;
          const si = net._stopById.get(parts[1]);
          if (si === undefined) continue;
          const list = net._byStop.get(si);
          if (!list) continue;
          for (const st of list) {
            const absDep = st[4] + shift * 86400;
            if (absDep < departAt) continue;
            if (absDep > deadline) break;
            const trip = net.trips[st[0]];
            if (!activeServices(net, trip[2], day)) continue;
            const route = net.routes[trip[1]];
            const tl = net._byTrip.get(st[0]);
            if (!tl) continue;
            let seenCurrent = false;
            for (const rst of tl) {
              if (!seenCurrent) {
                if (rst[2] === st[2] && rst[1] === st[1]) seenCurrent = true;
                continue;
              }
              const absArr = rst[4] + shift * 86400;
              // Lot 4.19 : l'horizon borne les EMBARQUEMENTS uniquement —
              // une fois à bord, l'arrivée peut dépasser l'horizon (trajet
              // de 45 min embarqué à 05:35 reste valide même si l'horizon
              // se termine à 05:59). Ancien comportement : rejetait ces
              // trajets (bug démontré — arrivée du TER J+1 coupée).
              const destKey = `${parts[0]}:${net.stops[rst[1]][0]}`;
              const leg = {
                network: parts[0],
                routeId: route.id,
                tripId: trip[0],
                fromStopId: boardKey,
                fromStopName: net.stops[si][1],
                toStopId: destKey,
                toStopName: net.stops[rst[1]][1],
                depSec: absDep,
                arrSec: absArr,
                headsign: trip[4],
                direction: trip[3],
              };
              const newLegs = [...state.legs, leg];
              if (toKeys.has(destKey) && !seenGoal.has(destKey)) {
                seenGoal.add(destKey);
                results.push({
                  legs: newLegs,
                  originKey: state.legs.length === 0 ? state.key : state.legs[0].fromStopId,
                  destinationKey: destKey,
                  departureSec: newLegs[0].depSec,
                  arrivalSec: absArr,
                  transferCount: newLegs.length - 1,
                });
                continue;
              }
              if (newLegs.length - 1 <= maxTransfers) {
                const prev = bestAt.get(destKey);
                if (prev === undefined || absArr < prev) {
                  bestAt.set(destKey, absArr);
                  nextFrontier.push({ key: destKey, t: absArr, legs: newLegs });
                }
              }
            }
          }
        }
      }
      frontier = nextFrontier;
      if (results.length >= maxResults * 3) break;
    }
  }
  results.sort((a, b) => a.arrivalSec - b.arrivalSec);
  return results.slice(0, maxResults);
}

export const DAY = (y, m, d) => ({ year: y, month: m, day: d, hour: 0, minute: 0, second: 0 });
export const AT = (y, m, d, hh, mm, ss = 0) => ({ year: y, month: m, day: d, hour: hh, minute: mm, second: ss });
export const fmtSec = (abs) => {
  const s = ((abs % 86400) + 86400) % 86400;
  return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};
