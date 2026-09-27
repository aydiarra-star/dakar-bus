#!/usr/bin/env node
/**
 * Lot 4.18 — Générateur de la couche opérationnelle PassBi.
 *
 * data/transit/passbi/*.zip  (source publique, bit-à-bit, NON modifiée)
 *        ↓  ce script (déterministe, réexécutable au remplacement de la source)
 * flutter-src/assets/data/passbi/{ter,brt,ddd,aftu}.json   (format compact indexé)
 * flutter-src/assets/data/passbi/crosswalk.json           (correspondances dakar_network ↔ PassBi)
 * data/transit/passbi/processed_manifest.json             (provenance de la dérivation)
 *
 * Règles :
 *  - AUCUNE donnée inventée ; les métadonnées d'origine (valid_from/valid_to,
 *    date_source, date_verified) sont recopiées telles quelles.
 *  - statut opérationnel : ACTIVE (source = PassBi, source_type = PUBLIC_GTFS).
 *  - le mode calendrier est ROLLING : le motif hebdomadaire publié s'applique
 *    comme base de fonctionnement courante jusqu'à remplacement (décision
 *    produit Lot 4.18) ; les dates d'origine restent visibles dans meta.
 *  - aucune conversion fréquence → prochain passage ; SCHEDULED uniquement.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC_DIR = path.join(ROOT, 'data', 'transit', 'passbi');
const OUT_DIR = path.join(ROOT, 'flutter-src', 'assets', 'data', 'passbi');
const DATE_SOURCE = '2026-02-10'; // commit des fichiers dans passbi_core
const DATE_VERIFIED = '2026-09-27';
const GENERATED_AT = '2026-09-27';

// ---------------------------------------------------------------- ZIP reader
function readZip(buf) {
  // EOCD
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('EOCD introuvable (zip invalide)');
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const entries = new Map();
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) throw new Error('Entrée centrale invalide');
    const method = buf.readUInt16LE(off + 10);
    const compSize = buf.readUInt32LE(off + 20);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const localOff = buf.readUInt32LE(off + 42);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    // header local
    if (buf.readUInt32LE(localOff) !== 0x04034b50) throw new Error('En-tête local invalide');
    const lNameLen = buf.readUInt16LE(localOff + 26);
    const lExtraLen = buf.readUInt16LE(localOff + 28);
    const dataStart = localOff + 30 + lNameLen + lExtraLen;
    const raw = buf.subarray(dataStart, dataStart + compSize);
    if (!name.endsWith('/')) {
      entries.set(name, method === 0 ? Buffer.from(raw) : zlib.inflateRawSync(raw));
    }
    off += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

// ---------------------------------------------------------------- CSV parser
function parseCsv(text, delim) {
  const rows = [];
  let field = '', row = [], inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else inQ = false;
      } else field += c;
    } else if (c === '"') inQ = true;
    else if (c === delim) { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c === '\r') { /* skip */ }
    else field += c;
  }
  if (field.length > 0 || row.length > 0) { row.push(field); rows.push(row); }
  const header = rows.shift() || [];
  return rows.filter((r) => r.length === header.length && r.some((v) => v !== ''))
    .map((r) => Object.fromEntries(header.map((h, i) => [h, r[i]])));
}

function detectDelim(text) {
  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== '').slice(0, 5);
  if (lines.length === 0) return ',';
  const header = lines[0];
  const candidates = [';', ','];
  let best = ',', bestScore = -1;
  for (const d of candidates) {
    const hCount = header.split(d).length;
    if (hCount < 2) continue;
    let ok = 0, seen = 0;
    for (let i = 1; i < lines.length; i++) {
      seen++;
      if (lines[i].split(d).length === hCount) ok++;
    }
    const score = seen === 0 ? hCount : (ok / seen) * 10 + hCount;
    if (score > bestScore) { bestScore = score; best = d; }
  }
  return best;
}

function readTable(entries, name) {
  const key = [...entries.keys()].find((k) => k.endsWith(name) || k === name);
  if (!key) return null;
  let text = entries.get(key).toString('utf8');
  // Feed hétérogène constaté (DDD/AFTU calendar_dates.txt) : en-tête séparé par
  // « ; » mais lignes de données séparées par « , ». On normalise l'en-tête.
  const lines = text.split(/\r?\n/);
  const headerIdx = lines.findIndex((l) => l.trim() !== '');
  if (headerIdx >= 0) {
    const h = lines[headerIdx];
    const next = lines.slice(headerIdx + 1).find((l) => l.trim() !== '');
    if (h.includes(';') && !h.includes(',') && next && next.includes(',') && !next.includes(';')) {
      lines[headerIdx] = h.replace(/;/g, ',');
      text = lines.join('\n');
    }
  }
  return parseCsv(text, detectDelim(text));
}

function timeToSec(t) {
  const m = /^(\d+):(\d+):(\d+)$/.exec((t || '').trim());
  if (!m) return null;
  return (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]);
}

function sha256(buf) { return crypto.createHash('sha256').update(buf).digest('hex'); }

// ---------------------------------------------------------------- Normalisation
function norm(s) {
  return String(s || '')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}
function tokens(s) { return new Set(norm(s).split(' ').filter((t) => t.length >= 3)); }
function nameScore(a, b) {
  const na = norm(a), nb = norm(b);
  if (!na || !nb) return 0;
  if (na === nb) return 1;
  const short = na.length < nb.length ? na : nb;
  const long = na.length < nb.length ? nb : na;
  if (short.length >= 4 && long.includes(short)) return 0.92;
  const ta = tokens(a), tb = tokens(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter++;
  return (2 * inter) / (ta.size + tb.size);
}
function haversine(a, b) {
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLon = (b.lon - a.lon) * rad;
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}
function confidenceOf(score) {
  if (score >= 0.9) return 'high';
  if (score >= 0.7) return 'medium';
  return 'low';
}

// ---------------------------------------------------------------- Réseaux
const NETWORKS = {
  TER: { zip: 'gtfs_TER.zip', out: 'ter.json', label: 'TER' },
  BRT: { zip: 'gtfs_BRT.zip', out: 'brt.json', label: 'BRT' },
  DDD: { zip: 'gtfs_Dem_Dikk.zip', out: 'ddd.json', label: 'DDD' },
  AFTU: { zip: 'gtfs_AFTU.zip', out: 'aftu.json', label: 'AFTU' },
};

function buildNetwork(net, zipPath) {
  const zipBuf = fs.readFileSync(zipPath);
  const entries = readZip(zipBuf);

  const routesRaw = readTable(entries, 'routes.txt') || [];
  const stopsRaw = readTable(entries, 'stops.txt') || [];
  const tripsRaw = readTable(entries, 'trips.txt') || [];
  const stRaw = readTable(entries, 'stop_times.txt') || [];
  const calRaw = readTable(entries, 'calendar.txt') || [];
  const calDatesRaw = readTable(entries, 'calendar_dates.txt') || [];

  // agency
  const agencyRaw = readTable(entries, 'agency.txt') || [];
  const agency = agencyRaw.length > 0 ? (agencyRaw[0].agency_name || agencyRaw[0].agency_id || net) : net;

  // routes
  const routeIdx = new Map();
  const routes = routesRaw.map((r, i) => {
    const id = r.route_id;
    routeIdx.set(id, i);
    return {
      id,
      short: r.route_short_name || id,
      long: r.route_long_name || r.route_short_name || id,
      type: Number(r.route_type || 3),
    };
  });

  // stops (avec indicateur « utilisé par stop_times »)
  const stopIdx = new Map();
  let stops = stopsRaw.map((s) => ({
    id: s.stop_id,
    name: s.stop_name || s.stop_id,
    lat: Number(s.stop_lat),
    lon: Number(s.stop_lon),
    used: false,
  }));
  // index construit après dédup éventuelle : on garde toutes les lignes

  // services (calendar hebdomadaire)
  const services = [];
  const svcIdx = new Map();
  const addService = (id, mask, start, end) => {
    svcIdx.set(id, services.length);
    services.push({ id, mask, start, end });
  };
  const DAY_KEYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  for (const c of calRaw) {
    let mask = 0;
    DAY_KEYS.forEach((d, i) => { if (c[d] === '1') mask |= (1 << i); });
    addService(c.service_id, mask, c.start_date || '', c.end_date || '');
  }

  // exceptions (calendar_dates : , ou ;)
  const exceptions = calDatesRaw.map((e) => [e.service_id, e.date, Number(e.exception_type)]);

  // BRT : calendar.txt vide → masque dérivé des dates d'exceptions (constat documenté)
  if (services.length === 0 && exceptions.length > 0) {
    const bySvc = new Map();
    for (const [svc, date, type] of exceptions) {
      if (type !== 1) continue;
      const wd = new Date(Date.UTC(+date.slice(0, 4), +date.slice(4, 6) - 1, +date.slice(6, 8)))
        .getUTCDay(); // 0 = dimanche
      const maskIdx = (wd + 6) % 7; // lundi = bit0
      if (!bySvc.has(svc)) bySvc.set(svc, { mask: 0, start: '99999999', end: '00000000' });
      const e = bySvc.get(svc);
      e.mask |= (1 << maskIdx);
      if (date < e.start) e.start = date;
      if (date > e.end) e.end = date;
    }
    for (const [svc, e] of bySvc) addService(svc, e.mask, e.start, e.end);
  }

  // trips
  const tripIdx = new Map();
  const trips = tripsRaw.map((t, i) => {
    tripIdx.set(t.trip_id, i);
    const rid = routeIdx.has(t.route_id) ? routeIdx.get(t.route_id) : -1;
    const sid = svcIdx.has(t.service_id) ? svcIdx.get(t.service_id) : -1;
    return [t.trip_id, rid, sid, t.direction_id ?? '', t.trip_headsign || ''];
  });

  // stop_times → index (trip, stop, seq, arr, dep)
  const stopIdToIdx = new Map();
  stops.forEach((s, i) => stopIdToIdx.set(s.id, i));
  const stopTimes = [];
  for (const st of stRaw) {
    const ti = tripIdx.get(st.trip_id);
    const si = stopIdToIdx.get(st.stop_id);
    if (ti === undefined || si === undefined) continue;
    stops[si].used = true;
    stopTimes.push([
      ti, si,
      Number(st.stop_sequence || 0),
      timeToSec(st.arrival_time),
      timeToSec(st.departure_time),
    ]);
  }
  stopTimes.sort((a, b) => (a[0] - b[0]) || (a[2] - b[2]));

  const validFrom = services.reduce((m, s) => (s.start && s.start < m ? s.start : m), '99999999');
  const validTo = services.reduce((m, s) => (s.end && s.end > m ? s.end : m), '00000000');

  const processed = {
    meta: {
      network: NETWORKS[net].label,
      source: 'PassBi (impactsolutionsas/passbi_core)',
      source_type: 'PUBLIC_GTFS',
      source_url: `https://raw.githubusercontent.com/impactsolutionsas/passbi_core/main/gtfs_folder/${NETWORKS[net].zip}`,
      discovery_source: 'PassBi',
      discovery_source_type: 'PUBLIC_APP',
      date_source: DATE_SOURCE,
      date_verified: DATE_VERIFIED,
      valid_from: validFrom === '99999999' ? null : validFrom,
      valid_to: validTo === '00000000' ? null : validTo,
      confidence: 'MEDIUM',
      status: 'ACTIVE',
      source_role: 'operational_current_base',
      calendar_mode: 'ROLLING',
      calendar_mode_note:
        'Base opérationnelle courante (Lot 4.18) : le motif hebdomadaire publié s’applique ' +
        'jusqu’à remplacement par de nouvelles données étude/CETUD. Les dates valid_from/valid_to ' +
        'd’origine ne sont pas falsifiées et restent ci-dessus.',
      time_semantics: 'SCHEDULED (jamais REAL_TIME) : horaires programmés, aucun flux temps réel.',
      input_file: NETWORKS[net].zip,
      input_sha256: sha256(zipBuf),
      generator: 'scripts/build-passbi-processed.mjs',
      generated_at: GENERATED_AT,
    },
    agency,
    routes,
    stops: stops.map((s) => [s.id, s.name, s.lat, s.lon, s.used ? 1 : 0]),
    services: services.map((s) => [s.id, s.mask, s.start, s.end]),
    exceptions,
    trips,
    stop_times: stopTimes,
  };
  return { processed, zipSha: sha256(zipBuf), entries };
}

// ---------------------------------------------------------------- Crosswalk
function buildCrosswalk(allProcessed, rawStops) {
  const dPath = path.join(ROOT, 'flutter-src', 'assets', 'data', 'dakar_network.json');
  const dakar = JSON.parse(fs.readFileSync(dPath, 'utf8'));
  const dRoutes = dakar.routes;
  const dStopById = new Map(dakar.stops.map((s) => [s.id, s]));

  // Termini d'une long_name dakar « X ↔ Y (…) » → paires normalisées.
  function dakarEndpoints(long) {
    const m = /^(.*?)\s*(?:↔|<->|->|–|—)\s*(.*?)\s*\(/.exec(long || '') ||
      /^(.*?)\s*(?:↔|<->|->|–|—)\s*(.*)$/.exec(long || '');
    if (!m) return null;
    const a = norm(m[1]), b = norm(m[2]);
    return a && b ? [a, b] : null;
  }
  // Score de présence des deux termini dans la long_name encodée du feed
  // (ex. « DDD_05_GUEDIAWAYE_PALAIS1 », « AFTU_2_Parcelles-Assainies_Petersen »).
  function terminiScore(pbRouteLong, endpoints) {
    if (!endpoints) return 0;
    const bare = String(pbRouteLong || '').replace(/^(DDD|AFTU)_\d+_/i, '');
    const fields = [...bare.split(/[_\s]+/).map(norm).filter(Boolean), norm(bare)]
      .filter(Boolean);
    if (fields.length === 0) return 0;
    const sc = (t) => Math.max(...fields.map((f) => nameScore(t, f)), 0);
    return Math.min(sc(endpoints[0]), sc(endpoints[1]));
  }

  // Mappe dakar route id → réseau + route_ids PassBi
  function pbRoutesFor(dRoute) {
    const id = dRoute.id;
    if (id === 'ter_dakar_diamniadio') {
      return { network: 'TER', pbRouteIds: allProcessed.TER.processed.routes.map((r) => r.id),
        status: 'MAPPED', method: 'IDENTITY_OFFICIELLE',
        note: 'Corridor TER : les 6 routes PassBi (sens + branches Rufisque/Yeumbeul) partagent les gares du référentiel.' };
    }
    if (id === 'brt_b1_guediawaye_petersen') {
      return { network: 'BRT', pbRouteIds: ['B1'], status: 'MAPPED', method: 'IDENTITY_OFFICIELLE',
        note: 'B1 = B1 (PassBi), identité officielle SunuBRT.' };
    }
    if (id === 'brt_b2_express') {
      return { network: 'BRT', pbRouteIds: ['B2'], status: 'MAPPED', method: 'IDENTITY_OFFICIELLE',
        note: 'B2 = B2 (PassBi), identité officielle SunuBRT. Route strictement distincte de B1.' };
    }
    const endpoints = dakarEndpoints(dRoute.long_name);
    const net = id.startsWith('ddd_') ? 'DDD' : (id.startsWith('aftu_') ? 'AFTU' : null);
    if (!net) {
      return { network: null, pbRouteIds: [], status: 'UNMAPPED', method: 'RESEAU_ABSENT_DU_FEED',
        note: `${id} : réseau non couvert par les feeds PassBi — AUCUNE donnée, statut UNKNOWN.` };
    }
    const proc = allProcessed[net].processed;
    // 1) concordance des termini sur l'ensemble des routes PassBi du réseau
    let best = null;
    for (const r of proc.routes) {
      const sc = terminiScore(r.long, endpoints);
      if (!best || sc > best.sc) best = { id: r.id, sc };
    }
    if (best && best.sc >= 0.7) {
      return { network: net, pbRouteIds: [best.id], status: 'MAPPED', method: 'TERMINI_MATCH',
        score: Number(best.sc.toFixed(3)),
        note: `Termini concordants (« ${dRoute.long_name} » ↔ « ${best.id} »), score ${best.sc.toFixed(2)}.` };
    }
    // 2) sinon : identité non documentée — aucun rapprochement par numéro seul
    const n = id.split('_')[1];
    const numeric = net === 'DDD' ? `DDD_${String(n).padStart(2, '0')}` : `AFTU_${n}`;
    const numericExists = proc.routes.some((r) => r.id === numeric);
    return { network: net, pbRouteIds: [], status: 'UNMAPPED', method: 'IDENTITE_NON_CONFIRMEE',
      note: `Identité non confirmée pour ${id} : termini non concordants avec ${numeric}` +
        (numericExists ? ' (même numéro, autre ligne)' : ' (route absente)') +
        ` ni avec aucune autre route PassBi ${net}. Les numéros divergent entre référentiels : ` +
        'aucun horaire n’est rattaché à cette ligne (UNKNOWN) ; les données PassBi restent ' +
        'exploitables côté moteur sous leurs propres identifiants PassBi.' };
  }

  const routesMap = {};
  const stopsMap = {};
  const unmappedRoutes = [];
  const unmappedStops = [];

  for (const dRoute of dRoutes) {
    const mapping = pbRoutesFor(dRoute);
    routesMap[dRoute.id] = mapping;
    if (mapping.status !== 'MAPPED') {
      unmappedRoutes.push({ id: dRoute.id, note: mapping.note });
      stopsMap[dRoute.id] = {};
      for (const dSid of dRoute.stops) {
        const dStop = dStopById.get(dSid);
        unmappedStops.push({ route: dRoute.id, stop: dSid, name: dStop ? dStop.name : dSid,
          note: 'route non mappée (identité non confirmée) — aucun rattachement deviné' });
      }
      continue;
    }
    const proc = allProcessed[mapping.network].processed;
    // index route → stop_ids réellement appelés (via stop_times)
    const routeStops = new Map(); // pbRouteId → Set(stopId)
    const tripRoute = proc.trips.map((t) => t[1]);
    for (const [ti, si, seq] of proc.stop_times) {
      const ridx = tripRoute[ti];
      if (ridx < 0) continue;
      const rid = proc.routes[ridx].id;
      if (!mapping.pbRouteIds.includes(rid)) continue;
      if (!routeStops.has(rid)) routeStops.set(rid, new Set());
      routeStops.get(rid).add(proc.stops[si][0]);
    }
    // pool : stop_ids utilisés sur les routes mappées
    const poolIds = [];
    const poolSeen = new Set();
    for (const rid of mapping.pbRouteIds) {
      for (const sid of routeStops.get(rid) || []) {
        if (!poolSeen.has(sid)) { poolSeen.add(sid); poolIds.push(sid); }
      }
    }
    const stopById = new Map(proc.stops.map((s) => [s[0], s]));
    const entry = {};
    for (const dSid of dRoute.stops) {
      const dStop = dStopById.get(dSid);
      if (!dStop) continue;
      let best = null;
      for (const pid of poolIds) {
        const s = stopById.get(pid);
        if (!s) continue;
        const sc = nameScore(dStop.name, s[1]);
        if (!best || sc > best.score || (sc === best.score && s[4] === 1)) {
          best = { pid, score: sc, used: s[4] === 1 };
        }
      }
      if (best && best.score >= 0.55) {
        entry[dSid] = {
          pb: `${mapping.network}:${best.pid}`,
          method: best.score === 1 ? 'EXACT_NAME' : (best.score >= 0.9 ? 'NAME_CONTAINMENT' : 'NAME_SIMILARITY'),
          confidence: confidenceOf(best.score),
          score: Number(best.score.toFixed(3)),
        };
      } else {
        // Secours coordonné : précision dakar ≥ 3 décimales et distance ≤ 150 m
        // dans le périmètre des routes mappées (jamais de proximité seule hors route).
        const latStr = String(dStop.latitude ?? '');
        const lonStr = String(dStop.longitude ?? '');
        const dp = (s) => (s.includes('.') ? s.split('.')[1].length : 0);
        let coordBest = null;
        if (dp(latStr) >= 3 && dp(lonStr) >= 3) {
          for (const pid of poolIds) {
            const s = stopById.get(pid);
            if (!s) continue;
            const dist = haversine({ lat: Number(dStop.latitude), lon: Number(dStop.longitude) },
              { lat: s[2], lon: s[3] });
            if (dist <= 150 && (!coordBest || dist < coordBest.dist)) coordBest = { pid, dist };
          }
        }
        if (coordBest) {
          entry[dSid] = {
            pb: `${mapping.network}:${coordBest.pid}`,
            method: 'COORDINATE_WITHIN_ROUTE',
            confidence: 'medium',
            score: Number((1 - coordBest.dist / 150).toFixed(3)),
            meters: Math.round(coordBest.dist),
          };
        } else {
          entry[dSid] = null;
          unmappedStops.push({ route: dRoute.id, stop: dSid, name: dStop.name,
            note: best ? `meilleur score nom ${best.score.toFixed(2)} < 0.55 et pas de coordonnée ≤ 150 m`
              : 'aucun arrêt PassBi sur la route mappée' });
        }
      }
    }
    stopsMap[dRoute.id] = entry;
  }

  // Transferts inter-réseaux : même nom normalisé, distance ≤ 500 m, ids distincts
  const allStops = [];
  for (const [netKey, { processed }] of Object.entries(allProcessed)) {
    for (const s of processed.stops) {
      if (!s[4]) continue; // uniquement les arrêts réellement utilisés
      allStops.push({ key: `${netKey}:${s[0]}`, net: netKey, id: s[0], name: s[1], lat: s[2], lon: s[3] });
    }
  }
  const byName = new Map();
  for (const s of allStops) {
    const n = norm(s.name);
    if (!n) continue;
    if (!byName.has(n)) byName.set(n, []);
    byName.get(n).push(s);
  }
  const transfers = [];
  const seenPair = new Set();
  for (const group of byName.values()) {
    for (let i = 0; i < group.length; i++) {
      for (let j = i + 1; j < group.length; j++) {
        const a = group[i], b = group[j];
        if (a.key === b.key) continue;
        const d = haversine(a, b);
        if (d <= 500) {
          const pk = [a.key, b.key].sort().join('|');
          if (seenPair.has(pk)) continue;
          seenPair.add(pk);
          transfers.push({ from: a.key, to: b.key, meters: Math.round(d), name: norm(a.name),
            method: 'NOM_IDENTIQUE_PROXIMITE', confidence: d <= 150 ? 'high' : 'medium' });
        }
      }
    }
  }
  // Règle complémentaire inter-réseaux : inclusion de nom (suite de mots complète)
  // et distance ≤ 250 m — couvre ex. « Colobane » (TER) ↔ « Terrain Colobane » (DDD).
  const namesList = [...byName.keys()];
  const groupsByKey = new Map();
  for (const s of allStops) {
    const n = norm(s.name);
    if (n) { if (!groupsByKey.has(n)) groupsByKey.set(n, []); groupsByKey.get(n).push(s); }
  }
  for (const na of namesList) {
    for (const nb of namesList) {
      if (na === nb) continue;
      const [short, long] = na.length <= nb.length ? [na, nb] : [nb, na];
      if (short.split(' ').length < 1 || short.length < 5) continue;
      if (!new RegExp(`(^| )${short.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}( |$)`).test(long)) continue;
      for (const a of groupsByKey.get(na) || []) {
        for (const b of groupsByKey.get(nb) || []) {
          if (a.net === b.net) continue; // uniquement inter-réseaux
          const d = haversine(a, b);
          if (d > 250) continue;
          const pk = [a.key, b.key].sort().join('|');
          if (seenPair.has(pk)) continue;
          seenPair.add(pk);
          transfers.push({ from: a.key, to: b.key, meters: Math.round(d), name: short,
            method: 'INCLUSION_NOM_PROXIMITE', confidence: 'medium' });
        }
      }
    }
  }
  transfers.sort((x, y) => x.meters - y.meters);

  const crosswalk = {
    meta: {
      source: 'PassBi (impactsolutionsas/passbi_core)',
      source_type: 'PUBLIC_GTFS',
      discovery_source: 'PassBi',
      discovery_source_type: 'PUBLIC_APP',
      date_verified: DATE_VERIFIED,
      generated_at: GENERATED_AT,
      generator: 'scripts/build-passbi-processed.mjs',
      status: 'ACTIVE',
      reference_target: 'flutter-src/assets/data/dakar_network.json',
      rules: [
        'routes : identité officielle (TER/BRT) ou concordance des extrémités TERMINI_MATCH ≥ 0,7 sur les terminus (DDD/AFTU) — aucun appariement par numéro seul ; sinon UNMAPPED (IDENTITE_NON_CONFIRMEE) ou RESEAU_ABSENT.',
        'arrêts : score de nom (égalité / inclusion / F1 ≥ 0,55) dans le périmètre des routes mappées, arrêts réellement appelés uniquement ; repli coordonnée ≥ 3 décimales à ≤ 150 m dans ce même périmètre ; sinon non mappé.',
        'transferts : même nom normalisé à ≤ 500 m, ou inclusion de nom inter-réseaux à ≤ 250 m — aucune correspondance par proximité seule.',
        'tout arrêt/route sans correspondance documentée reste UNKNOWN (jamais deviné).',
      ],
    },
    routes: routesMap,
    stops: stopsMap,
    transfers,
    unmapped: { routes: unmappedRoutes, stops: unmappedStops },
  };
  return crosswalk;
}

// ---------------------------------------------------------------- Main
function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const allProcessed = {};
  const outputs = {};
  for (const [net, cfg] of Object.entries(NETWORKS)) {
    const zipPath = path.join(SRC_DIR, cfg.zip);
    const { processed, zipSha } = buildNetwork(net, zipPath);
    allProcessed[net] = { processed, zipSha };
    const outPath = path.join(OUT_DIR, cfg.out);
    const json = JSON.stringify(processed);
    fs.writeFileSync(outPath, json);
    outputs[cfg.out] = { sha256: sha256(Buffer.from(json)), bytes: Buffer.byteLength(json) };
    const usedStops = processed.stops.filter((s) => s[4]).length;
    console.log(`${cfg.out}: routes=${processed.routes.length} stops=${processed.stops.length} ` +
      `(used=${usedStops}) trips=${processed.trips.length} stop_times=${processed.stop_times.length} ` +
      `services=${processed.services.length} exceptions=${processed.exceptions.length} ` +
      `→ ${(Buffer.byteLength(json) / 1048576).toFixed(1)} MiB`);
  }

  const crosswalk = buildCrosswalk(allProcessed, null);
  const cwJson = JSON.stringify(crosswalk);
  fs.writeFileSync(path.join(OUT_DIR, 'crosswalk.json'), cwJson);
  outputs['crosswalk.json'] = { sha256: sha256(Buffer.from(cwJson)), bytes: Buffer.byteLength(cwJson) };

  const mappedRoutes = Object.values(crosswalk.routes).filter((r) => r.status === 'MAPPED').length;
  let mappedStops = 0, totalStops = 0;
  for (const entry of Object.values(crosswalk.stops)) {
    for (const v of Object.values(entry)) { totalStops++; if (v) mappedStops++; }
  }
  console.log(`crosswalk: routes ${mappedRoutes}/${Object.keys(crosswalk.routes).length} mappées, ` +
    `arrêts ${mappedStops}/${totalStops} mappés, transferts=${crosswalk.transfers.length}, ` +
    `routes unmapped=${crosswalk.unmapped.routes.length}, arrêts unmapped=${crosswalk.unmapped.stops.length}`);

  const manifest = {
    set: 'passbi-operational-layer',
    generated_at: GENERATED_AT,
    generator: 'scripts/build-passbi-processed.mjs',
    operational_status: 'ACTIVE',
    source: 'PassBi (impactsolutionsas/passbi_core)',
    source_type: 'PUBLIC_GTFS',
    date_source: DATE_SOURCE,
    date_verified: DATE_VERIFIED,
    calendar_mode: 'ROLLING',
    note: 'Dérivation bit-à-bit des zips source (non modifiés) vers la couche opérationnelle Dart. ' +
      'Les dates valid_from/valid_to d origine sont conservées dans chaque meta. ' +
      'Remplacement futur : déposer les nouveaux feeds et réexécuter ce script.',
    inputs: Object.fromEntries(Object.entries(allProcessed)
      .map(([k, v]) => [NETWORKS[k].zip, { sha256: v.zipSha }])),
    outputs,
    crosswalk_stats: {
      routes_mapped: mappedRoutes,
      routes_total: Object.keys(crosswalk.routes).length,
      stops_mapped: mappedStops,
      stops_total: totalStops,
      transfers: crosswalk.transfers.length,
    },
  };
  fs.writeFileSync(path.join(SRC_DIR, 'processed_manifest.json'),
    JSON.stringify(manifest, null, 2) + '\n');
  console.log('manifest écrit :', path.join(SRC_DIR, 'processed_manifest.json'));
}

main();
