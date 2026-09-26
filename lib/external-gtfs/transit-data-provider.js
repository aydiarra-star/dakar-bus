'use strict';
/**
 * TransitDataProvider : couche unique de résolution des horaires.
 *
 * Ordre de priorité (spécification LOT 18 BIS §8) :
 *   1. CETUD CURRENT (currentOfficial, autorité CETUD)
 *   2. autre source officielle actuelle (currentOfficial, autre autorité)
 *   3. PassBi CURRENT si réellement prouvé (currentApplication)
 *   4. open data actuelle (currentOpenData)
 *   5. estimation par fréquence documentée (currentFrequency → ESTIMATED)
 *   6. UNKNOWN
 * Les sources HISTORICAL (PassBi) ne participent JAMAIS à une réponse
 * « maintenant » : elles ne sont interrogeables que via getHistoricalDepartures.
 */
const { normalizeServiceDate, toIsoDate, dakarClock, formatTime, parseTime } = require('./gtfs-time');
const { SOURCE_TYPES, VALIDITY } = require('./provenance');
const { STATUS, REASONS } = require('./gtfs-schedule-service');

const ROLES = Object.freeze({
  CURRENT_OFFICIAL: 'currentOfficial',
  CURRENT_APPLICATION: 'currentApplication',
  CURRENT_OPEN_DATA: 'currentOpenData',
  CURRENT_FREQUENCY: 'currentFrequency',
  HISTORICAL_REFERENCE: 'historicalReference',
});
const ROLE_LIST = Object.freeze(Object.values(ROLES));
const CURRENT_ROLES = Object.freeze([ROLES.CURRENT_OFFICIAL, ROLES.CURRENT_APPLICATION, ROLES.CURRENT_OPEN_DATA, ROLES.CURRENT_FREQUENCY]);

const ROLE_SOURCE_TYPE = Object.freeze({
  [ROLES.CURRENT_OFFICIAL]: SOURCE_TYPES.SOURCE_INSTITUTIONAL,
  [ROLES.CURRENT_APPLICATION]: SOURCE_TYPES.SOURCE_APPLICATION,
  [ROLES.CURRENT_OPEN_DATA]: SOURCE_TYPES.OPEN_DATA,
});

const ROLE_LEVEL = Object.freeze({
  [ROLES.CURRENT_OFFICIAL]: 'OFFICIAL_STATIC_CURRENT',
  [ROLES.CURRENT_APPLICATION]: 'SOURCE_APPLICATION_CURRENT',
  [ROLES.CURRENT_OPEN_DATA]: 'OPEN_DATA_CURRENT',
  [ROLES.CURRENT_FREQUENCY]: 'ESTIMATED',
  [ROLES.HISTORICAL_REFERENCE]: 'HISTORICAL_REFERENCE',
});

const normalizeText = (s) => String(s || '')
  .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  .toUpperCase().replace(/[^A-Z0-9]+/g, ' ').trim();

class TransitDataProvider {
  /** @param {{now?: () => Date}} [options] horloge injectable (tests) */
  constructor(options = {}) {
    this.now = typeof options.now === 'function' ? options.now : () => new Date();
    this.sources = [];
  }

  /**
   * Enregistre une source horaire avec un rôle. Règles strictes :
   *  - un feed déclaré HISTORICAL ne peut recevoir qu'un rôle historicalReference ;
   *  - un rôle « current » exige un statut déclaré CURRENT ;
   *  - currentOfficial exige une source institutionnelle (CETUD / autorité).
   */
  registerSource(service, { role, realtime = false } = {}) {
    if (!service || typeof service.getDeparturesAtStop !== 'function' || !service.provenance) {
      throw new Error('TransitDataProvider : source invalide (getDeparturesAtStop / provenance requis)');
    }
    if (!ROLE_LIST.includes(role)) throw new Error(`TransitDataProvider : rôle inconnu « ${role} »`);
    const prov = service.provenance;
    const label = `${prov.source}${prov.network ? ` (${prov.network})` : ''}`;
    if (role !== ROLES.HISTORICAL_REFERENCE) {
      if (prov.declaredStatus === VALIDITY.HISTORICAL) {
        throw new Error(`TransitDataProvider : ${label} est déclarée HISTORICAL et ne peut pas être enregistrée comme ${role}`);
      }
      if (prov.declaredStatus !== VALIDITY.CURRENT) {
        throw new Error(`TransitDataProvider : ${label} n'a pas de statut CURRENT prouvé (statut ${prov.declaredStatus}) — rôle ${role} refusé`);
      }
      if (ROLE_SOURCE_TYPE[role] && prov.sourceType !== ROLE_SOURCE_TYPE[role]) {
        throw new Error(`TransitDataProvider : ${label} (${prov.sourceTypeLabel}) ne peut pas tenir le rôle ${role} (${ROLE_SOURCE_TYPE[role]} requis)`);
      }
      if (role === ROLES.CURRENT_FREQUENCY && service.kind !== 'frequency') {
        throw new Error(`TransitDataProvider : le rôle currentFrequency est réservé aux sources de fréquence`);
      }
      if (role !== ROLES.CURRENT_FREQUENCY && service.kind === 'frequency') {
        throw new Error(`TransitDataProvider : une source de fréquence ne peut pas tenir le rôle ${role}`);
      }
    }
    const entry = {
      service,
      role,
      realtime: Boolean(realtime),
      provenance: prov,
      network: service.network || prov.network || null,
      rank: this.rankFor(role, prov),
      level: role === ROLES.CURRENT_OFFICIAL && realtime ? 'OFFICIAL_CURRENT' : ROLE_LEVEL[role],
    };
    this.sources.push(entry);
    this.sources.sort((a, b) => a.rank - b.rank);
    return entry;
  }

  rankFor(role, prov) {
    switch (role) {
      case ROLES.CURRENT_OFFICIAL: return normalizeText(prov.authority || prov.source) === 'CETUD' ? 0 : 1;
      case ROLES.CURRENT_APPLICATION: return 2;
      case ROLES.CURRENT_OPEN_DATA: return 3;
      case ROLES.CURRENT_FREQUENCY: return 4;
      default: return 9;
    }
  }

  /** Date/heure de référence (horloge Dakar, UTC+0). */
  reference(options = {}) {
    const clock = dakarClock(this.now());
    const serviceDate = options.date ? normalizeServiceDate(options.date) : clock.serviceDate;
    const time = options.time || clock.time;
    if (parseTime(time) === null) throw new Error(`TransitDataProvider : heure invalide « ${time} »`);
    return { serviceDate, isoDate: toIsoDate(serviceDate), time: formatTime(parseTime(time)) };
  }

  /** Sources « current » utilisables à une date (validité vérifiée à chaque appel). */
  resolveCurrentSources(asOf) {
    const day = normalizeServiceDate(asOf);
    return this.sources
      .filter((s) => CURRENT_ROLES.includes(s.role))
      .map((s) => {
        const status = s.provenance.validityStatusOn(day);
        return { ...s, validityStatus: status, usable: status === VALIDITY.CURRENT };
      });
  }

  historicalSources() { return this.sources.filter((s) => s.role === ROLES.HISTORICAL_REFERENCE); }

  /** Source gagnante pour un réseau à une date (ou null → UNKNOWN). */
  winningSource(network, asOf) {
    const net = network ? String(network).toUpperCase() : null;
    return this.resolveCurrentSources(asOf).find((s) => s.usable && s.service.kind !== 'frequency' && (!net || !s.network || String(s.network).toUpperCase() === net)) || null;
  }

  /**
   * Prochains départs « actuels » : uniquement sources current utilisables ;
   * SCHEDULED depuis stop_times, sinon ESTIMATED (fréquence documentée), sinon UNKNOWN.
   */
  getDepartures(routeId, stopId, options = {}) {
    const ref = this.reference(options);
    const limit = options.limit === undefined ? 5 : options.limit;
    const current = this.resolveCurrentSources(ref.serviceDate);
    const consulted = [];
    let fallback = null;
    for (const s of current) {
      const knows = s.service.knowsRoute(routeId);
      consulted.push({ source: s.provenance.source, network: s.network, role: s.role, validityStatus: s.validityStatus, usable: s.usable, knowsRoute: knows });
      if (!s.usable || !knows) continue;
      const result = s.service.getDeparturesAtStop(routeId, stopId, ref.serviceDate, ref.time, { limit, asOf: ref.serviceDate });
      if (result.status === STATUS.SCHEDULED || result.status === STATUS.ESTIMATED) {
        return this.decorate(result, s, ref, consulted);
      }
      if (!fallback) fallback = this.decorate(result, s, ref, consulted);
    }
    if (fallback) return { ...fallback, consulted };
    return this.unknown(routeId, stopId, ref, consulted, current.length ? REASONS.NO_CURRENT_SOURCE : REASONS.NO_CURRENT_SOURCE);
  }

  getDeparturesNow(routeId, stopId, options = {}) {
    return this.getDepartures(routeId, stopId, { ...options, date: undefined, time: undefined });
  }

  /** Consultation explicite de la référence historique (jamais « actuel »). */
  getHistoricalDepartures(routeId, stopId, options = {}) {
    const ref = this.reference(options);
    const limit = options.limit === undefined ? 5 : options.limit;
    const sources = this.historicalSources().filter((s) => !options.sourceId || s.provenance.sourceId === options.sourceId);
    for (const s of sources) {
      if (!s.service.knowsRoute(routeId)) continue;
      const result = s.service.getDeparturesAtStop(routeId, stopId, ref.serviceDate, ref.time, { limit, asOf: ref.serviceDate });
      return {
        ...result,
        isCurrent: false,
        provenanceLevel: 'HISTORICAL_REFERENCE',
        role: ROLES.HISTORICAL_REFERENCE,
        note: 'Référence historique : ne décrit pas le service actuel.',
      };
    }
    return this.unknown(routeId, stopId, ref, [], REASONS.ROUTE_UNKNOWN);
  }

  decorate(result, entry, ref, consulted) {
    return {
      ...result,
      isCurrent: result.status === STATUS.SCHEDULED || result.status === STATUS.ESTIMATED,
      provenanceLevel: result.status === STATUS.UNKNOWN ? 'UNKNOWN' : entry.level,
      role: entry.role,
      network: entry.network,
      consulted,
      departures: (result.departures || []).map((d) => ({ ...d, provenanceLevel: entry.level })),
    };
  }

  unknown(routeId, stopId, ref, consulted, reason) {
    return {
      routeId,
      stopId,
      date: ref.isoDate,
      currentTime: ref.time,
      status: STATUS.UNKNOWN,
      reason,
      source: null,
      sourceType: null,
      feedVersion: null,
      validity: null,
      provenanceLevel: 'UNKNOWN',
      isCurrent: false,
      role: null,
      consulted,
      historicalReferenceAvailable: this.historicalSources().some((s) => s.service.knowsRoute(routeId)),
      departures: [],
    };
  }

  /** Lignes d'un réseau dont route_short_name (champ officiel) vaut exactement le numéro demandé. */
  routesForLine(network, lineNumber, { asOf, includeHistorical = false } = {}) {
    const wanted = normalizeText(lineNumber);
    if (!wanted) return [];
    const net = network ? String(network).toUpperCase() : null;
    const day = asOf ? normalizeServiceDate(asOf) : dakarClock(this.now()).serviceDate;
    const pool = includeHistorical ? this.historicalSources().map((s) => ({ ...s, usable: true })) : this.resolveCurrentSources(day).filter((s) => s.usable);
    const out = [];
    for (const s of pool) {
      if (s.service.kind === 'frequency') continue; // les fréquences ne sont pas des lignes GTFS (voir frequencyEstimate)
      if (net && s.network && String(s.network).toUpperCase() !== net) continue;
      for (const r of s.service.routes()) {
        if (normalizeText(r.routeShortName) === wanted) out.push({ route: r, source: s });
      }
    }
    return out;
  }

  /** Arrêts d'une source dont le nom correspond (exact normalisé, puis inclusion unique). */
  static matchStops(stops, name) {
    const wanted = normalizeText(name);
    if (!wanted) return { exact: [], partial: [] };
    const exact = stops.filter((s) => normalizeText(s.stopName) === wanted);
    if (exact.length) return { exact, partial: [] };
    const partial = stops.filter((s) => normalizeText(s.stopName).includes(wanted));
    return { exact: [], partial };
  }

  describe(asOf) {
    const day = asOf ? normalizeServiceDate(asOf) : dakarClock(this.now()).serviceDate;
    return {
      asOf: toIsoDate(day),
      sources: this.sources.map((s) => ({
        source: s.provenance.source,
        network: s.network,
        role: s.role,
        rank: s.rank,
        level: s.level,
        sourceType: s.provenance.sourceTypeLabel,
        declaredStatus: s.provenance.declaredStatus,
        validity: s.provenance.validityOn(day),
        usableNow: CURRENT_ROLES.includes(s.role) && s.provenance.isCurrentOn(day),
      })),
    };
  }
}

module.exports = { TransitDataProvider, ROLES, ROLE_LEVEL, CURRENT_ROLES, normalizeText };
