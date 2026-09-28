// Lot 4.21 — Miroir fonctionnel du CHEMIN NATIF PassBi (Dart) pour tests Node.
//
// Port fidèle des ajouts du Lot 4.21 :
//   * passbi_source.dart    — PassBiRouteSummary (audit §1), identityStatusOf,
//                             nativeStops, searchNativeStops, nextNativeDeparture,
//                             tataMentions, networkAvailability ;
//   * gtfs_source.dart      — nextDepartureAmong (une passe par jour, route
//                             gagnante remontée) et routeIndexesByStop ;
//   * schedule_provider.dart— departureAtPassBiStop (SCHEDULED/UNKNOWN +
//                             identity_status + raison d'UNKNOWN) ;
//   * data_service.dart     — écriture native du catalogue.
//
// Le moteur Lot 4.19 (tests/helpers/passbi-engine419.mjs) reste la source de
// vérité pour nextDepartureAbs / planJourneys : il n'est PAS modifié ici.
import { loadAll, splitComposite, activeServices, AT, fmtSec } from './passbi-engine419.mjs';

export const IDENTITY = { CONFIRMED: 'CONFIRMED', UNCONFIRMED: 'UNCONFIRMED' };

export const REASON = {
  NETWORK_ABSENT: 'RESEAU_ABSENT_DU_FEED',
  IDENTITY_UNCONFIRMED: 'IDENTITE_NON_CONFIRMEE',
  STOP_NOT_MATCHED: 'ARRET_NON_CORRESPONDU',
  NO_DEPARTURE: 'AUCUN_DEPART_CALCULABLE',
  NO_STOP_TIMES: 'AUCUN_STOP_TIME_DANS_LE_FEED',
  SOURCE_INACTIVE: 'SOURCE_PASSBI_INACTIVE',
};

/// Repliement d'accents + ponctuation — même règle que PassBiSource.normalizeName.
const FOLDS = {
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

export function normalizeName(value) {
  let out = '';
  for (const ch of value) {
    const folded = FOLDS[ch] ?? ch;
    out += /^[a-z0-9]$/i.test(folded) ? folded.toLowerCase() : ' ';
  }
  return out.replace(/ +/g, ' ').trim();
}

export const NETWORK_KEYS = ['TER', 'BRT', 'DDD', 'AFTU'];

/// §3 — Identité publique : CONFIRMED seulement si le crosswalk MAPPED rattache
/// explicitement cette route PassBi.
export function identityStatusOf(cw, networkKey, pbRouteId) {
  for (const [, m] of Object.entries(cw.routes)) {
    if (m.status === 'MAPPED' && m.network === networkKey && (m.pbRouteIds ?? []).includes(pbRouteId)) {
      return IDENTITY.CONFIRMED;
    }
  }
  return IDENTITY.UNCONFIRMED;
}

export function dakarRouteIdsFor(cw, networkKey, pbRouteId) {
  const out = [];
  for (const [dakarId, m] of Object.entries(cw.routes)) {
    if (m.status === 'MAPPED' && m.network === networkKey && (m.pbRouteIds ?? []).includes(pbRouteId)) {
      out.push(dakarId);
    }
  }
  return out;
}

/// §1 — Fiche d'audit par route, calculée sur le feed réel.
export function routeSummaries(all, networkKey) {
  const net = all.networks[networkKey];
  if (!net) return [];
  const n = net.routes.length;
  const trips = new Array(n).fill(0);
  const stopTimes = new Array(n).fill(0);
  const boardable = new Array(n).fill(0);
  const served = Array.from({ length: n }, () => new Set());
  const services = Array.from({ length: n }, () => new Set());
  const directions = Array.from({ length: n }, () => new Set());
  const first = new Array(n).fill(null);
  const last = new Array(n).fill(null);

  net.trips.forEach((trip, ti) => {
    const ri = trip[1];
    if (ri < 0 || ri >= n) return;
    trips[ri]++;
    if (trip[2] >= 0 && trip[2] < net.services.length) services[ri].add(net.services[trip[2]][0]);
    if (trip[3]) directions[ri].add(trip[3]);
    const rows = net._byTrip.get(ti) ?? [];
    for (const st of rows) {
      stopTimes[ri]++;
      served[ri].add(st[1]);
      if (first[ri] === null || st[4] < first[ri]) first[ri] = st[4];
      if (last[ri] === null || st[4] > last[ri]) last[ri] = st[4];
      if (rows.length > 0 && st[2] < rows[rows.length - 1][2]) boardable[ri]++;
    }
  });

  return net.routes.map((r, ri) => {
    const available = boardable[ri] > 0;
    let reason;
    if (available) reason = 'HORAIRES_CALCULABLES';
    else if (trips[ri] === 0) reason = REASON.NO_DEPARTURE;
    else if (stopTimes[ri] === 0) reason = REASON.NO_STOP_TIMES;
    else reason = REASON.NO_DEPARTURE;
    return {
      network: networkKey,
      routeId: r.id,
      shortName: r.short,
      longName: r.long,
      routeType: r.type,
      trips: trips[ri],
      servedStops: served[ri].size,
      stopTimes: stopTimes[ri],
      boardableStopTimes: boardable[ri],
      serviceIds: [...services[ri]].sort(),
      directions: [...directions[ri]].sort(),
      firstDepartureSec: first[ri],
      lastDepartureSec: last[ri],
      scheduleAvailable: available,
      identityStatus: identityStatusOf(all.cw, networkKey, r.id),
      dakarRouteIds: dakarRouteIdsFor(all.cw, networkKey, r.id),
      reason,
    };
  });
}

export function schedulableRouteCount(all, networkKey) {
  return routeSummaries(all, networkKey).filter((s) => s.scheduleAvailable).length;
}

/// §6 — Disponibilité d'un réseau comme feed GTFS PassBi autonome.
export function networkAvailability(all, networkKey) {
  const net = all.networks[networkKey];
  if (!net) return 'ABSENT_FROM_FEED';
  const s = routeSummaries(all, networkKey);
  if (s.length === 0) return 'PRESENT_WITHOUT_SCHEDULES';
  return s.some((x) => x.scheduleAvailable) ? 'AVAILABLE' : 'PRESENT_WITHOUT_SCHEDULES';
}

/// §6 — Occurrences explicites de « tata » dans les métadonnées PassBi.
export function tataMentions(all) {
  const out = [];
  const hit = (v) => typeof v === 'string' && v.toLowerCase().includes('tata');
  for (const [key, net] of Object.entries(all.networks)) {
    if (hit(net.agency)) out.push(`${key}:agency`);
    for (const [k, v] of Object.entries(net.meta ?? {})) if (hit(v)) out.push(`${key}:meta.${k}`);
    for (const r of net.routes) if (hit(r.id) || hit(r.short) || hit(r.long)) out.push(`${key}:route=${r.id}`);
    for (const s of net.stops) if (hit(s[1])) out.push(`${key}:stop=${s[0]}`);
    for (const t of net.trips) if (hit(t[0]) || hit(t[3]) || hit(t[4])) out.push(`${key}:trip=${t[0]}`);
  }
  return out;
}

/// §3 — Plateformes sœurs : liaison documentée du crosswalk ≤ 30 m, même réseau
/// (Lot 4.19 A, réutilisé tel quel par le chemin natif).
export function siblingStops(all, networkKey, stopId) {
  const composite = `${networkKey}:${stopId}`;
  const out = new Set();
  for (const t of all.cw.transfers) {
    if (t.meters > 30) continue;
    let other = null;
    if (t.from === composite) other = t.to;
    else if (t.to === composite) other = t.from;
    if (other === null) continue;
    const p = splitComposite(other);
    if (!p || p[0] !== networkKey) continue;
    out.add(p[1]);
  }
  return [...out];
}

/// §2 — Arrêts natifs réellement appelés (nom et coordonnées du feed).
export function nativeStops(all, networkKey) {
  const net = all.networks[networkKey];
  if (!net) return [];
  const out = [];
  for (let si = 0; si < net.stops.length; si++) {
    const routes = new Set();
    for (const st of net._byStop.get(si) ?? []) routes.add(net.trips[st[0]][1]);
    if (routes.size === 0) continue;
    out.push({
      network: networkKey,
      stopId: net.stops[si][0],
      name: net.stops[si][1],
      lat: net.stops[si][2],
      lon: net.stops[si][3],
      routeCount: routes.size,
      compositeKey: `${networkKey}:${net.stops[si][0]}`,
    });
  }
  return out;
}

/// §8 — Recherche STRICTE : le nom PassBi normalisé doit contenir la requête
/// normalisée entière (l'inverse n'est jamais accepté).
export function searchNativeStops(all, query, { networks = NETWORK_KEYS, limit = 8 } = {}) {
  const q = normalizeName(query);
  if (q.length < 3) return [];
  const out = [];
  for (const key of networks) {
    for (const s of nativeStops(all, key)) {
      if (normalizeName(s.name).includes(q)) {
        out.push(s);
        if (out.length >= limit) return out;
      }
    }
  }
  return out;
}

/// Miroir de GtfsNetwork.nextDepartureAmong : première ligne triée qui passe
/// tous les filtres = minimum du jour.
export function nextDepartureAmong(net, routeIndexes, stopIndex, at) {
  if (routeIndexes.size === 0) return null;
  const list = net._byStop.get(stopIndex);
  if (!list) return null;
  const day0 = Date.UTC(at.year, at.month - 1, at.day);
  const minOfDay0 = at.hour * 3600 + at.minute * 60 + at.second;
  for (let d = 0; d < 7; d++) {
    const day = new Date(day0 + d * 86400000);
    const from = d === 0 ? minOfDay0 : 0;
    for (const st of list) {
      if (st[4] < from) continue;
      const trip = net.trips[st[0]];
      if (!routeIndexes.has(trip[1])) continue;
      if (!activeServices(net, trip[2], day)) continue;
      const rows = net._byTrip.get(st[0]) ?? [];
      if (rows.length === 0) continue;
      if (st[2] >= rows[rows.length - 1][2]) continue; // arrivée de terminus
      return { sec: st[4] + d * 86400, routeIndex: trip[1], tripIndex: st[0], dayOffset: d };
    }
  }
  return null;
}

/// §4/§5 — Prochain départ natif ; retourne la route gagnante.
export function nextNativeDeparture(all, networkKey, pbStopId, at, { onlyRouteId = null } = {}) {
  const net = all.networks[networkKey];
  if (!net) return null;
  const stopIndex = net._stopById.get(pbStopId);
  if (stopIndex === undefined) return null;

  const candidates = [pbStopId, ...siblingStops(all, networkKey, pbStopId)];
  const routeIndexes = new Set();
  for (const c of candidates) {
    const ci = net._stopById.get(c);
    if (ci === undefined) continue;
    for (const st of net._byStop.get(ci) ?? []) routeIndexes.add(net.trips[st[0]][1]);
  }
  if (onlyRouteId !== null) {
    const wanted = net._routeById.get(onlyRouteId);
    if (wanted === undefined) return null;
    for (const ri of [...routeIndexes]) if (ri !== wanted) routeIndexes.delete(ri);
  }
  if (routeIndexes.size === 0) return null;

  let best = null;
  for (const c of candidates) {
    const ci = net._stopById.get(c);
    if (ci === undefined) continue;
    const found = nextDepartureAmong(net, routeIndexes, ci, at);
    if (found === null) continue;
    if (best === null || found.sec < best.sec) best = found;
  }
  if (best === null) return null;
  return {
    sec: best.sec,
    routeId: net.routes[best.routeIndex].id,
    tripId: net.trips[best.tripIndex][0],
  };
}

/// §2 — Identité d'affichage (métadonnées PassBi réelles uniquement).
export function identityLabelFor(networkKey, pbRouteId, identity, shortName = null) {
  if (identity === IDENTITY.CONFIRMED) {
    return pbRouteId.startsWith(networkKey) ? pbRouteId : `${networkKey} ${pbRouteId}`;
  }
  if (shortName && shortName !== pbRouteId) return `Ligne PassBi ${pbRouteId} · ${shortName}`;
  return `Ligne PassBi ${pbRouteId}`;
}

/// Miroir de ScheduleProvider.departureAtPassBiStop.
export function departureAtPassBiStop(all, networkKey, pbStopId, at, { pbRouteId = null } = {}) {
  const net = all.networks[networkKey];
  if (!net) {
    return { status: 'UNKNOWN', unresolvedReason: REASON.NETWORK_ABSENT, identityStatus: IDENTITY.UNCONFIRMED };
  }
  const found = nextNativeDeparture(all, networkKey, pbStopId, at, { onlyRouteId: pbRouteId });
  const day0 = Date.UTC(at.year, at.month - 1, at.day);
  const minOfDay = at.hour * 3600 + at.minute * 60 + at.second;

  if (found === null) {
    const summary = pbRouteId === null ? null : routeSummaries(all, networkKey).find((s) => s.routeId === pbRouteId);
    return {
      status: 'UNKNOWN',
      unresolvedReason:
        summary && !summary.scheduleAvailable ? REASON.NO_STOP_TIMES : REASON.NO_DEPARTURE,
      identityStatus: pbRouteId === null ? IDENTITY.UNCONFIRMED : identityStatusOf(all.cw, networkKey, pbRouteId),
      lineLabel: null,
      label: 'Horaire indisponible',
      scheduledTime: null,
      frequencyMinutes: null,
    };
  }

  const identity = identityStatusOf(all.cw, networkKey, found.routeId);
  const summary = routeSummaries(all, networkKey).find((s) => s.routeId === found.routeId);
  const waitMinutes = Math.floor((found.sec - minOfDay) / 60);
  const trip = net.trips.find((t) => t[0] === found.tripId);
  return {
    status: 'SCHEDULED',
    routeId: found.routeId,
    tripId: found.tripId,
    depAbs: found.sec,
    scheduledTime: new Date(day0 + found.sec * 1000),
    estimatedWaitFrom: waitMinutes,
    label:
      waitMinutes <= 0
        ? 'Prochain départ dans moins d’une minute'
        : `Prochain départ dans ${waitMinutes} min`,
    frequencyMinutes: null,
    sourceType: 'PUBLIC_GTFS',
    identityStatus: identity,
    identityNote:
      identity === IDENTITY.CONFIRMED
        ? `Identité publique confirmée par le crosswalk (${dakarRouteIdsFor(all.cw, networkKey, found.routeId).join(', ')}).`
        : 'Identité publique UNCONFIRMED ; horaire PassBi techniquement calculable.',
    lineLabel: identityLabelFor(networkKey, found.routeId, identity, summary?.shortName ?? null),
    tripDirection: trip ? trip[3] || trip[4] || null : null,
  };
}

/// §2/§7 — Réseaux exploitables dont l'identité publique reste à confirmer
/// (ceux qui alimentent le référentiel natif de l'application).
export function nativeNetworkKeys(all) {
  const out = [];
  for (const key of NETWORK_KEYS) {
    const s = routeSummaries(all, key);
    if (s.length === 0) continue;
    if (s.some((x) => x.scheduleAvailable) && s.some((x) => x.identityStatus === IDENTITY.UNCONFIRMED)) {
      out.push(key);
    }
  }
  return out;
}

export { loadAll, AT, fmtSec, splitComposite };
