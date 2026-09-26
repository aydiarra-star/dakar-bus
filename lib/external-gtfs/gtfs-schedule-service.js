'use strict';
/**
 * Moteur horaire sur un feed GTFS : les heures proviennent EXCLUSIVEMENT de
 * stop_times.txt ; une course n'est retenue que si son service est actif le
 * jour interrogé (calendar.txt + calendar_dates.txt). Jamais d'interpolation,
 * jamais de fréquence convertie en heure.
 */
const { parseTime, formatTime, normalizeServiceDate, toIsoDate, addDays } = require('./gtfs-time');
const { SOURCE_TYPES, VALIDITY } = require('./provenance');

const STATUS = Object.freeze({ SCHEDULED: 'SCHEDULED', ESTIMATED: 'ESTIMATED', UNKNOWN: 'UNKNOWN' });

const REASONS = Object.freeze({
  INVALID_TIME: 'INVALID_TIME',
  ROUTE_UNKNOWN: 'ROUTE_UNKNOWN',
  STOP_UNKNOWN: 'STOP_UNKNOWN',
  STOP_NOT_ON_ROUTE: 'STOP_NOT_ON_ROUTE',
  NO_SERVICE_ON_DATE: 'NO_SERVICE_ON_DATE',
  NO_MORE_DEPARTURES: 'NO_MORE_DEPARTURES',
  NO_CURRENT_SOURCE: 'NO_CURRENT_SOURCE',
  FEED_NOT_CURRENT: 'FEED_NOT_CURRENT',
});

/** Niveau de provenance intrinsèque d'un feed à une date (hors rôle). */
function provenanceLevelForFeed(provenance, asOf) {
  if (provenance.validityStatusOn(asOf) !== VALIDITY.CURRENT) return 'HISTORICAL_REFERENCE';
  if (provenance.sourceType === SOURCE_TYPES.SOURCE_INSTITUTIONAL) return 'OFFICIAL_STATIC_CURRENT';
  if (provenance.sourceType === SOURCE_TYPES.SOURCE_APPLICATION) return 'SOURCE_APPLICATION_CURRENT';
  if (provenance.sourceType === SOURCE_TYPES.OPEN_DATA) return 'OPEN_DATA_CURRENT';
  return 'UNKNOWN';
}

class GtfsScheduleService {
  /** @param {import('./models').GtfsFeed} feed */
  constructor(feed) {
    if (!feed || !feed.provenance) throw new Error('GtfsScheduleService : feed avec provenance requis');
    this.feed = feed;
    this.provenance = feed.provenance;
    this.network = feed.network || null;
    this.kind = 'gtfs';
  }

  knowsRoute(routeId) { return this.feed.routes.has(routeId); }
  routes() { return this.feed.routeList(); }
  stops() { return this.feed.stopList(); }
  getRoute(routeId) { return this.feed.routes.get(routeId) || null; }
  getStop(stopId) { return this.feed.stops.get(stopId) || null; }
  isServiceActive(serviceId, date) { return this.feed.isServiceActive(serviceId, date); }

  /** Origine / terminus d'une course d'après ses stop_times (ordre stop_sequence). */
  tripDirection(tripId) {
    const trip = this.feed.trips.get(tripId);
    const idx = this.feed.stopTimesByTrip.get(tripId) || [];
    const first = idx.length ? this.feed.stopTimes.stopIds[idx[0]] : null;
    const last = idx.length ? this.feed.stopTimes.stopIds[idx[idx.length - 1]] : null;
    const name = (id) => (id && this.feed.stops.has(id) ? this.feed.stops.get(id).stopName : null);
    return {
      directionId: trip ? trip.directionId : null,
      tripHeadsign: trip ? trip.tripHeadsign : null,
      originStopId: first,
      originStopName: name(first),
      terminusStopId: last,
      terminusStopName: name(last),
    };
  }

  /** Arrêts desservis par une ligne, par direction, dans l'ordre de la course la plus longue. */
  getStopsForRoute(routeId) {
    const trips = this.feed.tripsByRoute.get(routeId) || [];
    const byDirection = new Map();
    for (const tripId of trips) {
      const trip = this.feed.trips.get(tripId);
      const key = trip && trip.directionId !== null ? trip.directionId : '';
      const idx = this.feed.stopTimesByTrip.get(tripId) || [];
      const current = byDirection.get(key);
      if (!current || idx.length > current.idx.length) byDirection.set(key, { tripId, idx });
    }
    const out = [];
    for (const [directionId, { tripId, idx }] of byDirection) {
      out.push({
        directionId: directionId === '' ? null : directionId,
        tripId,
        stops: idx.map((i) => ({
          stopId: this.feed.stopTimes.stopIds[i],
          stopName: (this.feed.stops.get(this.feed.stopTimes.stopIds[i]) || {}).stopName || null,
          stopSequence: this.feed.stopTimes.sequences[i],
        })),
      });
    }
    return out;
  }

  /**
   * Prochains départs d'une ligne à un arrêt, à une date et une heure.
   * @param {string} routeId route_id exact
   * @param {string} stopId stop_id exact
   * @param {string} date 'YYYY-MM-DD' | 'YYYYMMDD' (jour de service)
   * @param {string} time 'HH:MM[:SS]'
   * @param {{limit?: number|null, asOf?: string}} [options] asOf : date de référence pour la validité (défaut : date)
   */
  getDeparturesAtStop(routeId, stopId, date, time, options = {}) {
    const limit = options.limit === undefined ? 5 : options.limit;
    const serviceDate = normalizeServiceDate(date);
    const asOf = options.asOf ? normalizeServiceDate(options.asOf) : serviceDate;
    const nowSeconds = parseTime(time);
    const validity = this.provenance.validityOn(asOf, serviceDate);
    const level = provenanceLevelForFeed(this.provenance, asOf);
    const base = {
      routeId,
      stopId,
      date: toIsoDate(serviceDate),
      currentTime: nowSeconds === null ? null : formatTime(nowSeconds),
      source: this.provenance.source,
      sourceType: this.provenance.sourceTypeLabel,
      authority: this.provenance.authority,
      feedVersion: this.provenance.feedVersion,
      validity,
      provenanceLevel: level,
      isCurrent: false,
    };
    const empty = (reason) => ({ ...base, status: STATUS.UNKNOWN, reason, departures: [] });
    if (nowSeconds === null) return empty(REASONS.INVALID_TIME);
    const route = this.feed.routes.get(routeId);
    if (!route) return empty(REASONS.ROUTE_UNKNOWN);
    const stop = this.feed.stops.get(stopId);
    if (!stop) return empty(REASONS.STOP_UNKNOWN);

    const st = this.feed.stopTimes;
    const atStop = this.feed.stopTimesByStop.get(stopId) || [];
    const previousDate = addDays(serviceDate, -1);
    const candidates = [];
    let onRoute = false;
    let anyServiceActive = false;
    const activeCache = new Map();
    const active = (serviceId, day) => {
      const key = `${serviceId}|${day}`;
      if (!activeCache.has(key)) activeCache.set(key, this.feed.isServiceActive(serviceId, day));
      return activeCache.get(key);
    };
    for (const i of atStop) {
      const trip = this.feed.trips.get(st.tripIds[i]);
      if (!trip || trip.routeId !== routeId) continue;
      onRoute = true;
      // Terminus d'une course : arrivée, pas un départ (aucune montée possible).
      const tripIdx = this.feed.stopTimesByTrip.get(trip.tripId);
      if (tripIdx && tripIdx.length > 1 && tripIdx[tripIdx.length - 1] === i) continue;
      const dep = st.departures[i] >= 0 ? st.departures[i] : (st.arrivals[i] >= 0 ? st.arrivals[i] : -1);
      if (dep < 0) continue;
      if (active(trip.serviceId, serviceDate)) {
        anyServiceActive = true;
        if (dep >= nowSeconds) candidates.push({ i, trip, dep, effective: dep, serviceDate });
      }
      // Courses de la veille dépassant minuit (heures GTFS ≥ 24:00:00).
      if (dep >= 86400 && active(trip.serviceId, previousDate)) {
        anyServiceActive = true;
        const effective = dep - 86400;
        if (effective >= nowSeconds) candidates.push({ i, trip, dep, effective, serviceDate: previousDate });
      }
    }
    if (!onRoute) return empty(REASONS.STOP_NOT_ON_ROUTE);
    if (!anyServiceActive) return empty(REASONS.NO_SERVICE_ON_DATE);
    if (candidates.length === 0) return empty(REASONS.NO_MORE_DEPARTURES);
    candidates.sort((a, b) => a.effective - b.effective || a.trip.tripId.localeCompare(b.trip.tripId));
    const kept = limit === null || limit === undefined ? candidates : candidates.slice(0, Math.max(0, limit));
    const departures = kept.map(({ i, trip, serviceDate: day }) => ({
      tripId: trip.tripId,
      routeId,
      routeShortName: route.routeShortName,
      routeLongName: route.routeLongName,
      stopId,
      stopName: stop.stopName,
      stopSequence: st.sequences[i],
      direction: this.tripDirection(trip.tripId),
      arrivalTime: st.arrivals[i] >= 0 ? formatTime(st.arrivals[i]) : null,
      departureTime: st.departures[i] >= 0 ? formatTime(st.departures[i]) : null,
      arrivalSeconds: st.arrivals[i] >= 0 ? st.arrivals[i] : null,
      departureSeconds: st.departures[i] >= 0 ? st.departures[i] : null,
      serviceId: trip.serviceId,
      serviceDate: toIsoDate(day),
      status: STATUS.SCHEDULED,
      source: this.provenance.source,
      sourceType: this.provenance.sourceTypeLabel,
      feedVersion: this.provenance.feedVersion,
      validity,
      provenanceLevel: level,
    }));
    return { ...base, status: STATUS.SCHEDULED, reason: null, departures };
  }
}

module.exports = { GtfsScheduleService, STATUS, REASONS, provenanceLevelForFeed };
