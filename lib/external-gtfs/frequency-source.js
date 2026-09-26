'use strict';
/**
 * Source « fréquence documentée » : produit un statut ESTIMATED (intervalle de
 * passage publié par une source identifiée), JAMAIS une heure de passage.
 * Elle n'intervient qu'après toutes les sources statiques actuelles
 * (stop_times) et uniquement pour la ligne et la période documentées.
 *
 * Aucune fréquence n'est embarquée par défaut : les entrées doivent provenir
 * d'une publication identifiée (source, url, published_at, validité).
 */
const { parseTime, normalizeServiceDate, toIsoDate, formatTime, weekdayOf } = require('./gtfs-time');
const { FeedProvenance } = require('./provenance');
const { STATUS, REASONS } = require('./gtfs-schedule-service');

class FrequencySource {
  /**
   * @param {Array<object>} entries [{ network, lineNumber, routeIds?, headwayMinutes, days?: ['monday',…], from?: 'HH:MM', to?: 'HH:MM', label? }]
   * @param {FeedProvenance|object} provenance provenance de la publication (source, url, published_at, valid_from, valid_to)
   */
  constructor(entries, provenance) {
    this.provenance = provenance instanceof FeedProvenance ? provenance : new FeedProvenance(provenance);
    this.entries = (entries || []).map((e, k) => {
      if (!e || !e.network || !e.lineNumber) throw new Error(`FrequencySource : entrée ${k} sans network / lineNumber`);
      const headway = Number(e.headwayMinutes);
      if (!Number.isFinite(headway) || headway <= 0) throw new Error(`FrequencySource : headwayMinutes invalide (${e.lineNumber})`);
      return {
        network: String(e.network).toUpperCase(),
        lineNumber: String(e.lineNumber).trim().toUpperCase(),
        routeIds: Array.isArray(e.routeIds) ? e.routeIds.slice() : [],
        headwayMinutes: headway,
        days: Array.isArray(e.days) && e.days.length ? e.days.map((d) => String(d).toLowerCase()) : null,
        fromSeconds: e.from ? parseTime(e.from) : null,
        toSeconds: e.to ? parseTime(e.to) : null,
        label: e.label || null,
      };
    });
    this.network = this.entries.length ? this.entries[0].network : (this.provenance.network || null);
    this.kind = 'frequency';
  }

  /** Pseudo-lignes : numéro public tel que publié (jamais déduit). */
  routes() {
    return this.entries.map((e) => ({
      routeId: `FREQ:${e.network}:${e.lineNumber}`,
      routeShortName: e.lineNumber,
      routeLongName: e.label,
      routeType: null,
      agencyId: null,
      network: e.network,
      raw: {},
    }));
  }

  stops() { return []; }
  knowsRoute(routeId) { return this.entries.some((e) => e.routeIds.includes(routeId) || `FREQ:${e.network}:${e.lineNumber}` === routeId); }

  /** Entrée applicable à une ligne, une date et une heure. */
  entryFor(network, lineNumber, date, time) {
    const net = network ? String(network).toUpperCase() : null;
    const line = String(lineNumber || '').trim().toUpperCase();
    const day = normalizeServiceDate(date);
    const weekday = weekdayOf(day);
    const seconds = parseTime(time);
    for (const e of this.entries) {
      if (net && e.network !== net) continue;
      if (e.lineNumber !== line) continue;
      if (e.days && !e.days.includes(weekday)) continue;
      if (seconds !== null && e.fromSeconds !== null && seconds < e.fromSeconds) continue;
      if (seconds !== null && e.toSeconds !== null && seconds > e.toSeconds) continue;
      return e;
    }
    return null;
  }

  /**
   * Interface commune : statut ESTIMATED pour la ligne (l'arrêt n'est pas
   * vérifiable dans une simple fréquence, ce qui est dit explicitement).
   */
  getDeparturesAtStop(routeId, stopId, date, time, options = {}) {
    const serviceDate = normalizeServiceDate(date);
    const asOf = options.asOf ? normalizeServiceDate(options.asOf) : serviceDate;
    const nowSeconds = parseTime(time);
    const entry = this.entries.find((e) => e.routeIds.includes(routeId) || `FREQ:${e.network}:${e.lineNumber}` === routeId) || null;
    const applicable = entry ? this.entryFor(entry.network, entry.lineNumber, serviceDate, time) : null;
    const base = {
      routeId,
      stopId,
      date: toIsoDate(serviceDate),
      currentTime: nowSeconds === null ? null : formatTime(nowSeconds),
      source: this.provenance.source,
      sourceType: this.provenance.sourceTypeLabel,
      authority: this.provenance.authority,
      feedVersion: this.provenance.feedVersion,
      validity: this.provenance.validityOn(asOf, serviceDate),
      provenanceLevel: this.provenance.isCurrentOn(asOf) ? 'ESTIMATED' : 'HISTORICAL_REFERENCE',
      isCurrent: false,
      departures: [],
    };
    if (nowSeconds === null) return { ...base, status: STATUS.UNKNOWN, reason: REASONS.INVALID_TIME };
    if (!entry) return { ...base, status: STATUS.UNKNOWN, reason: REASONS.ROUTE_UNKNOWN };
    if (!applicable) return { ...base, status: STATUS.UNKNOWN, reason: REASONS.NO_SERVICE_ON_DATE };
    return {
      ...base,
      status: STATUS.ESTIMATED,
      reason: null,
      estimate: {
        network: applicable.network,
        lineNumber: applicable.lineNumber,
        headwayMinutes: applicable.headwayMinutes,
        window: {
          from: applicable.fromSeconds === null ? null : formatTime(applicable.fromSeconds),
          to: applicable.toSeconds === null ? null : formatTime(applicable.toSeconds),
          days: applicable.days,
        },
        stopVerified: false,
        source: this.provenance.source,
        url: this.provenance.url,
        publishedAt: this.provenance.publishedAt,
      },
    };
  }
}

module.exports = { FrequencySource };
