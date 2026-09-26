'use strict';
/**
 * Assistant horaire : Question (FR) → ScheduleQuestion → TransitDataProvider
 * → source CURRENT → stop_times → phrase. L'assistant n'a AUCUNE donnée
 * propre : il consomme uniquement le provider commun.
 */
const { normalizeServiceDate, toIsoDate, addDays, dakarClock, formatHHMM, parseTime } = require('./gtfs-time');
const { STATUS } = require('./gtfs-schedule-service');
const { TransitDataProvider, normalizeText } = require('./transit-data-provider');

const SENTENCES = Object.freeze({
  /** LOT 18 BIS — aucune donnée fiable (ligne inconnue, arrêt inconnu, aucune source actuelle, plus de départ). */
  NO_RELIABLE_DATA: "Je n'ai pas actuellement de donnée horaire suffisamment fiable pour annoncer un départ précis.",
  /** LOT 18 — ligne connue (référence historique) mais aucune source actuelle. */
  KNOWN_LINE_NO_SCHEDULE: "Je connais la ligne, mais je n'ai pas actuellement d'horaire suffisamment fiable pour annoncer un départ précis.",
});

const NETWORK_PATTERNS = [
  [/\bAFTU\b/i, 'AFTU'],
  [/\bDEM\s*DIKK\b/i, 'DDD'],
  [/\bDDD\b/i, 'DDD'],
  [/\bBRT\b/i, 'BRT'],
  [/\bTER\b/i, 'TER'],
];

const SCHEDULE_KEYWORDS = /\b(prochain|prochaine|horaire|horaires|quand|heure|passe|passage|d[ée]part|bus|ligne|arr[êe]t)\b/i;

/** Extraction déterministe d'une question horaire. Aucune déduction : ce qui n'est pas écrit est null. */
function parseScheduleQuestion(text, options = {}) {
  const raw = String(text || '');
  const now = options.now instanceof Date ? options.now : new Date();
  const clock = dakarClock(now);
  let work = ` ${raw.replace(/\s+/g, ' ').trim()} `;

  let network = null;
  for (const [re, net] of NETWORK_PATTERNS) {
    if (re.test(work)) { network = net; work = work.replace(re, ' '); break; }
  }

  let date = null;
  const iso = work.match(/\b(\d{4}-\d{2}-\d{2})\b/);
  const fr = work.match(/\b(\d{2})\/(\d{2})\/(\d{4})\b/);
  const safeDate = (v) => { try { return normalizeServiceDate(v); } catch (e) { return null; } }; // date invalide → ignorée, jamais corrigée
  if (iso) { date = safeDate(iso[1]); work = work.replace(iso[0], ' '); }
  else if (fr) { date = safeDate(`${fr[3]}-${fr[2]}-${fr[1]}`); work = work.replace(fr[0], ' '); }
  else if (/\bdemain\b/i.test(work)) { date = addDays(clock.serviceDate, 1); work = work.replace(/\bdemain\b/i, ' '); }
  else if (/\baujourd['’]?hui\b/i.test(work)) { date = clock.serviceDate; work = work.replace(/\baujourd['’]?hui\b/i, ' '); }

  let time = null;
  const t = work.match(/\b(\d{1,2})\s*(?:h|:)\s*(\d{2})?\b/i);
  if (t) {
    const hh = Number(t[1]); const mm = t[2] === undefined ? 0 : Number(t[2]);
    if (hh <= 47 && mm <= 59) { time = `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`; work = work.replace(t[0], ' '); }
  }

  let lineNumber = null;
  const line = work.match(/\b(?:ligne|bus|n[°o]\.?|num[ée]ro)\s*(\d{1,3}\s?[A-Za-z]?)(?=[\s?.,!]|$)/i)
    || (network ? work.match(/(\d{1,3}\s?[A-Za-z]?)(?=[\s?.,!]|$)/) : null);
  if (line) { lineNumber = line[1].replace(/\s+/g, '').toUpperCase(); work = work.replace(line[0], ' '); }

  work = work.replace(/\b(maintenant|svp|s['’]il vous pla[îi]t|merci|le|la|du|de la|prochain|prochaine|passe|quand|horaires?|heure)\b/gi, ' ').replace(/\s+/g, ' ');
  let stopName = null;
  let directionHint = null;
  const stop = work.match(/(?:[àa] l['’]arr[êe]t|arr[êe]t|depuis|station|[àa] partir de|from|[àa])\s+(.+)$/i);
  if (stop) {
    let candidate = stop[1].replace(/[?!.,;]+\s*$/g, '').replace(/(\s+(?:à|a|de|du|des|le|la|les|pour|vers|et))+\s*$/i, '').trim();
    const dir = candidate.match(/^(.+?)\s+(?:direction|vers)\s+(.+)$/i);
    if (dir) { candidate = dir[1].trim(); directionHint = dir[2].replace(/[?!.,;]+\s*$/g, '').replace(/(\s+(?:à|a|de|du|des|le|la|les|pour|vers|et))+\s*$/i, '').trim() || null; }
    stopName = candidate || null;
  }

  // Question horaire : un numéro de ligne ET (un mot-clé horaire OU un réseau explicite avec un arrêt).
  const isScheduleQuestion = Boolean(lineNumber) && (SCHEDULE_KEYWORDS.test(raw) || Boolean(network && stopName));
  return {
    raw,
    isScheduleQuestion,
    network,
    lineNumber,
    stopName,
    directionHint,
    date: date ? toIsoDate(date) : null,
    time,
  };
}

function scheduledSentence({ network, lineNumber, stopName, timeHHMM, terminus, source, sourceTypeLabel, validity }) {
  let s = `La ligne ${network} ${lineNumber} dessert cet itinéraire. Depuis l'arrêt ${stopName}, le prochain départ programmé est à ${timeHHMM}.`;
  if (terminus) s += ` Direction ${terminus}.`;
  s += ` Source : ${source} (${sourceTypeLabel}, validité ${validity.validFrom} → ${validity.validTo}).`;
  return s;
}

function estimatedSentence({ network, lineNumber, estimate }) {
  const window = estimate.window && estimate.window.from && estimate.window.to ? ` entre ${estimate.window.from.slice(0, 5)} et ${estimate.window.to.slice(0, 5)}` : '';
  return `La ligne ${network} ${lineNumber} dessert cet itinéraire. D'après ${estimate.source}, un passage est annoncé environ toutes les ${estimate.headwayMinutes} minutes${window}. ${SENTENCES.NO_RELIABLE_DATA}`;
}

/** Estimation par fréquence documentée (dernier recours avant UNKNOWN). */
function frequencyEstimate(provider, network, lineNumber, ref) {
  for (const s of provider.resolveCurrentSources(ref.serviceDate)) {
    if (!s.usable || s.service.kind !== 'frequency' || typeof s.service.entryFor !== 'function') continue;
    const entry = s.service.entryFor(network, lineNumber, ref.serviceDate, ref.time);
    if (!entry) continue;
    const routeId = `FREQ:${entry.network}:${entry.lineNumber}`;
    const res = s.service.getDeparturesAtStop(routeId, null, ref.serviceDate, ref.time, { asOf: ref.serviceDate });
    if (res.status === STATUS.ESTIMATED) return { result: res, source: s };
  }
  return null;
}

/**
 * @param {TransitDataProvider} provider
 * @param {string|object} questionOrText
 * @param {{date?: string, time?: string, limit?: number}} [options]
 */
function answerScheduleQuestion(provider, questionOrText, options = {}) {
  if (!(provider instanceof TransitDataProvider)) throw new Error('answerScheduleQuestion : TransitDataProvider requis');
  const question = typeof questionOrText === 'string' ? parseScheduleQuestion(questionOrText, { now: provider.now() }) : questionOrText;
  const reply = (status, reason, sentence, extra = {}) => ({ handled: true, status, reason, sentence, question, ...extra });
  if (!question || !question.isScheduleQuestion) {
    return { handled: false, status: 'NOT_A_SCHEDULE_QUESTION', reason: null, sentence: null, question };
  }
  const ref = provider.reference({ date: options.date || question.date || undefined, time: options.time || question.time || undefined });
  const limit = options.limit === undefined ? 3 : options.limit;

  // 1. Ligne : uniquement par route_short_name, uniquement dans les sources actuelles utilisables.
  const matches = provider.routesForLine(question.network, question.lineNumber, { asOf: ref.serviceDate });
  const networks = [...new Set(matches.map((m) => m.source.network).filter(Boolean))];
  if (!question.network && networks.length > 1) {
    return reply('AMBIGUOUS_NETWORK', 'AMBIGUOUS_NETWORK', `Précisez le réseau (${networks.join(' ou ')}) : la ligne ${question.lineNumber} existe dans plusieurs réseaux.`, { networks });
  }
  if (matches.length === 0) {
    const estimate = frequencyEstimate(provider, question.network, question.lineNumber, ref);
    if (estimate) {
      const net = estimate.result.estimate.network;
      return reply(STATUS.ESTIMATED, null, estimatedSentence({ network: net, lineNumber: question.lineNumber, estimate: estimate.result.estimate }), {
        network: net, provenanceLevel: 'ESTIMATED', source: estimate.result.source, estimate: estimate.result.estimate, reference: ref,
      });
    }
    const historical = provider.routesForLine(question.network, question.lineNumber, { includeHistorical: true });
    const known = historical.length > 0;
    return reply(STATUS.UNKNOWN, known ? 'LINE_KNOWN_NO_CURRENT_SOURCE' : 'LINE_UNKNOWN', known ? SENTENCES.KNOWN_LINE_NO_SCHEDULE : SENTENCES.NO_RELIABLE_DATA, {
      provenanceLevel: 'UNKNOWN', lineKnownHistorically: known, reference: ref,
    });
  }
  const network = question.network || networks[0] || null;
  if (!question.stopName) {
    return reply('MISSING_STOP', 'MISSING_STOP', `Précisez l'arrêt de départ pour la ligne ${network} ${question.lineNumber}.`, { network, reference: ref });
  }

  // 2. Arrêt : parmi les arrêts réellement desservis par ces lignes dans la source gagnante.
  const bySource = new Map();
  for (const m of matches) {
    const key = m.source.provenance.sourceId;
    if (!bySource.has(key)) bySource.set(key, { source: m.source, routes: [] });
    bySource.get(key).routes.push(m.route);
  }
  let stopAmbiguity = null;
  let bestUnknown = null;
  for (const { source, routes } of bySource.values()) {
    const service = source.service;
    const servedStops = new Map();
    for (const route of routes) {
      for (const dir of service.getStopsForRoute(route.routeId)) {
        for (const s of dir.stops) if (!servedStops.has(s.stopId)) servedStops.set(s.stopId, { stopId: s.stopId, stopName: s.stopName });
      }
    }
    const { exact, partial } = TransitDataProvider.matchStops([...servedStops.values()], question.stopName);
    const names = (list) => [...new Set(list.map((s) => s.stopName))];
    let stops = exact;
    if (!stops.length) {
      if (partial.length === 1 || (partial.length > 1 && names(partial).length === 1)) stops = partial;
      else if (partial.length > 1) { stopAmbiguity = names(partial); continue; }
      else continue;
    }
    // 3. Départs via le provider (mêmes règles de priorité et de validité).
    const candidates = [];
    const unknowns = [];
    for (const route of routes) {
      for (const stop of stops) {
        const res = provider.getDepartures(route.routeId, stop.stopId, { date: ref.isoDate, time: ref.time, limit });
        if (res.status === STATUS.SCHEDULED) {
          for (const d of res.departures) {
            const dayOffset = normalizeServiceDate(d.serviceDate) < ref.serviceDate ? 86400 : 0;
            candidates.push({ departure: d, result: res, effective: d.departureSeconds - dayOffset });
          }
        } else if (res.status === STATUS.UNKNOWN) unknowns.push(res);
      }
    }
    let filtered = candidates;
    if (question.directionHint) {
      const hint = normalizeText(question.directionHint);
      filtered = candidates.filter((c) => normalizeText(c.departure.direction.terminusStopName).includes(hint) || normalizeText(c.departure.direction.tripHeadsign).includes(hint));
    }
    filtered.sort((a, b) => a.effective - b.effective || a.departure.tripId.localeCompare(b.departure.tripId));
    if (filtered.length) {
      const best = filtered[0];
      const d = best.departure;
      const sentence = scheduledSentence({
        network, lineNumber: question.lineNumber, stopName: d.stopName, timeHHMM: formatHHMM(d.departureSeconds),
        terminus: d.direction.terminusStopName, source: d.source, sourceTypeLabel: d.sourceType, validity: d.validity,
      });
      return reply(STATUS.SCHEDULED, null, sentence, {
        network,
        provenanceLevel: best.result.provenanceLevel,
        source: d.source,
        sourceType: d.sourceType,
        validity: d.validity,
        reference: ref,
        departure: d,
        departures: filtered.slice(0, limit === null ? undefined : limit).map((c) => c.departure),
        routeIds: routes.map((r) => r.routeId),
        stopIds: stops.map((s) => s.stopId),
      });
    }
    if (!bestUnknown && unknowns.length) bestUnknown = unknowns[0];
    if (!bestUnknown && candidates.length && question.directionHint) bestUnknown = { reason: 'NO_DEPARTURE_FOR_DIRECTION' };
  }
  if (stopAmbiguity) {
    return reply('AMBIGUOUS_STOP', 'AMBIGUOUS_STOP', `Plusieurs arrêts correspondent à « ${question.stopName} » : ${stopAmbiguity.join(', ')}. Précisez l'arrêt.`, { network, stops: stopAmbiguity, reference: ref });
  }
  return reply(STATUS.UNKNOWN, bestUnknown ? bestUnknown.reason : 'STOP_NOT_FOUND_ON_LINE', SENTENCES.NO_RELIABLE_DATA, { network, provenanceLevel: 'UNKNOWN', reference: ref });
}

module.exports = { parseScheduleQuestion, answerScheduleQuestion, SENTENCES, scheduledSentence, estimatedSentence, parseTime };
