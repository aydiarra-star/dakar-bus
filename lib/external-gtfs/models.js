'use strict';
/**
 * Modèle canonique d'un feed GTFS externe : index en mémoire construits à partir
 * des tables CSV, sans transformation des valeurs (identifiants, noms, heures
 * conservés tels quels). stop_times est stocké en colonnes (tableaux typés)
 * pour supporter 677 918 lignes (PassBi AFTU) sans extraction sur disque.
 */
const { parseCsv, rowsToObjects } = require('./gtfs-csv');
const { parseTime, normalizeServiceDate, weekdayOf, WEEKDAYS } = require('./gtfs-time');

const REQUIRED_FILES = Object.freeze(['agency', 'routes', 'stops', 'trips', 'stop_times']);
const CALENDAR_FILES = Object.freeze(['calendar', 'calendar_dates']);
const OPTIONAL_FILES = Object.freeze(['shapes', 'feed_info', 'frequencies', 'fare_attributes', 'fare_rules', 'transfers']);
/** Tables lues par le moteur (les tarifs ne servent pas au moteur horaire). */
const ENGINE_TABLES = Object.freeze(['agency', 'routes', 'stops', 'trips', 'stop_times', 'calendar', 'calendar_dates', 'shapes', 'feed_info', 'frequencies']);

const REQUIRED_COLUMNS = Object.freeze({
  agency: ['agency_name', 'agency_url', 'agency_timezone'],
  routes: ['route_id', 'route_type'],
  stops: ['stop_id', 'stop_name'],
  trips: ['route_id', 'service_id', 'trip_id'],
  stop_times: ['trip_id', 'stop_id', 'stop_sequence'],
  calendar: ['service_id', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'start_date', 'end_date'],
  calendar_dates: ['service_id', 'date', 'exception_type'],
  feed_info: ['feed_publisher_name', 'feed_publisher_url', 'feed_lang'],
  frequencies: ['trip_id', 'start_time', 'end_time', 'headway_secs'],
  shapes: ['shape_id', 'shape_pt_lat', 'shape_pt_lon', 'shape_pt_sequence'],
});

const tableName = (name) => String(name).replace(/\.txt$/i, '');

class GtfsService {
  constructor(serviceId) {
    this.serviceId = serviceId;
    this.weekdays = {};
    this.startDate = null;
    this.endDate = null;
    this.hasCalendarRow = false;
    this.addedDates = new Set();
    this.removedDates = new Set();
  }

  /** Actif à une date : calendar_dates (2 = retiré, 1 = ajouté) puis calendar. */
  isActiveOn(date) {
    const day = normalizeServiceDate(date);
    if (this.removedDates.has(day)) return false;
    if (this.addedDates.has(day)) return true;
    if (!this.hasCalendarRow || !this.startDate || !this.endDate) return false;
    if (day < this.startDate || day > this.endDate) return false;
    return this.weekdays[weekdayOf(day)] === true;
  }
}

class GtfsFeed {
  constructor(provenance, options = {}) {
    this.provenance = provenance;
    this.network = options.network || provenance.network || null;
    this.tables = new Set();
    /** En-têtes lus par table (contrôle des colonnes obligatoires). */
    this.headers = {};
    this.agencies = [];
    this.routes = new Map();
    this.stops = new Map();
    this.trips = new Map();
    this.tripsByRoute = new Map();
    this.services = new Map();
    this.stopTimes = { tripIds: [], stopIds: [], sequences: null, arrivals: null, departures: null, count: 0 };
    this.stopTimesByTrip = new Map();
    this.stopTimesByStop = new Map();
    this.shapeCount = 0;
    this.shapeIds = new Set();
    this.feedInfo = null;
    this.frequencies = null;
    this.anomalies = [];
    this.calendarWindow = { start: null, end: null };
  }

  get counts() {
    return {
      agency: this.agencies.length,
      routes: this.routes.size,
      stops: this.stops.size,
      trips: this.trips.size,
      stop_times: this.stopTimes.count,
      services: this.services.size,
      shapes: this.shapeIds.size,
      shape_points: this.shapeCount,
      frequencies: this.frequencies ? this.frequencies.length : 0,
    };
  }

  /** Lignes du feed (valeurs brutes). */
  routeList() { return Array.from(this.routes.values()); }
  stopList() { return Array.from(this.stops.values()); }

  /** stop_time n° i sous forme d'objet. */
  stopTimeAt(i) {
    const st = this.stopTimes;
    return {
      tripId: st.tripIds[i],
      stopId: st.stopIds[i],
      stopSequence: st.sequences[i],
      arrivalSeconds: st.arrivals[i] < 0 ? null : st.arrivals[i],
      departureSeconds: st.departures[i] < 0 ? null : st.departures[i],
    };
  }

  isServiceActive(serviceId, date) {
    const s = this.services.get(serviceId);
    return !!s && s.isActiveOn(date);
  }
}

/**
 * Construit le modèle depuis des textes CSV ({ routes: '...', 'stop_times.txt': '...', … }).
 * Les grandes tables (stop_times, shapes) sont consommées en flux.
 * @param {Object<string,string>} texts
 * @param {FeedProvenance} provenance
 * @param {{network?: string, tables?: string[]}} options
 */
function buildFeedFromTexts(texts, provenance, options = {}) {
  const wanted = new Set((options.tables || ENGINE_TABLES).map(tableName));
  const byTable = {};
  for (const [name, text] of Object.entries(texts || {})) {
    const t = tableName(name);
    if (wanted.has(t) && typeof text === 'string') byTable[t] = text;
  }
  return buildFeed(byTable, provenance, options);
}

/**
 * Construit le modèle depuis des textes par table (déjà filtrés).
 * @param {Object<string,string>} texts { routes: '...', stop_times: '...', … }
 */
function buildFeed(texts, provenance, options = {}) {
  const parsed = {};
  const small = ['agency', 'routes', 'stops', 'trips', 'calendar', 'calendar_dates', 'feed_info', 'frequencies'];
  for (const t of small) if (typeof texts[t] === 'string') parsed[t] = parseCsv(texts[t]);
  const feed = new GtfsFeed(provenance, options);
  for (const name of Object.keys(texts)) if (typeof texts[name] === 'string') feed.tables.add(name);
  for (const [name, t] of Object.entries(parsed)) feed.headers[name] = t.header;
  const anomaly = (code, detail) => feed.anomalies.push(detail ? `${code}: ${detail}` : code);

  if (parsed.agency) feed.agencies = rowsToObjects(parsed.agency);
  if (parsed.feed_info) feed.feedInfo = rowsToObjects(parsed.feed_info)[0] || null;
  if (parsed.frequencies) feed.frequencies = rowsToObjects(parsed.frequencies);

  if (parsed.routes) {
    const t = parsed.routes;
    const iId = t.columnIndex('route_id');
    const iShort = t.columnIndex('route_short_name');
    const iLong = t.columnIndex('route_long_name');
    const iType = t.columnIndex('route_type');
    const iAgency = t.columnIndex('agency_id');
    for (const r of t.rows) {
      const routeId = iId >= 0 ? r[iId] : '';
      if (!routeId) { anomaly('ROUTE_ID_MISSING'); continue; }
      if (feed.routes.has(routeId)) anomaly('ROUTE_ID_DUPLICATE', routeId);
      const raw = {};
      for (let k = 0; k < t.header.length; k++) raw[t.header[k]] = r[k] === undefined ? '' : r[k];
      feed.routes.set(routeId, {
        routeId,
        routeShortName: emptyToNull(iShort >= 0 ? r[iShort] : null),
        routeLongName: emptyToNull(iLong >= 0 ? r[iLong] : null),
        routeType: iType >= 0 ? r[iType] : null,
        agencyId: iAgency >= 0 ? r[iAgency] : null,
        raw,
      });
    }
  }

  if (parsed.stops) {
    const t = parsed.stops;
    const iId = t.columnIndex('stop_id');
    const iName = t.columnIndex('stop_name');
    const iLat = t.columnIndex('stop_lat');
    const iLon = t.columnIndex('stop_lon');
    const iLoc = t.columnIndex('location_type');
    const iParent = t.columnIndex('parent_station');
    for (const r of t.rows) {
      const stopId = iId >= 0 ? r[iId] : '';
      if (!stopId) { anomaly('STOP_ID_MISSING'); continue; }
      if (feed.stops.has(stopId)) anomaly('STOP_ID_DUPLICATE', stopId);
      const raw = {};
      for (let k = 0; k < t.header.length; k++) raw[t.header[k]] = r[k] === undefined ? '' : r[k];
      const lat = iLat >= 0 ? Number(r[iLat]) : NaN;
      const lon = iLon >= 0 ? Number(r[iLon]) : NaN;
      feed.stops.set(stopId, {
        stopId,
        stopName: emptyToNull(iName >= 0 ? r[iName] : null),
        stopLat: Number.isFinite(lat) ? lat : null,
        stopLon: Number.isFinite(lon) ? lon : null,
        locationType: iLoc >= 0 ? (r[iLoc] || '0') : '0',
        parentStation: emptyToNull(iParent >= 0 ? r[iParent] : null),
        raw,
      });
    }
  }

  if (parsed.calendar) {
    const t = parsed.calendar;
    const iId = t.columnIndex('service_id');
    const iStart = t.columnIndex('start_date');
    const iEnd = t.columnIndex('end_date');
    const dayIdx = WEEKDAYS.map((d) => t.columnIndex(d));
    for (const r of t.rows) {
      const id = iId >= 0 ? r[iId] : '';
      if (!id) { anomaly('SERVICE_ID_MISSING', 'calendar'); continue; }
      const s = getService(feed, id);
      s.hasCalendarRow = true;
      WEEKDAYS.forEach((d, k) => { s.weekdays[d] = dayIdx[k] >= 0 && r[dayIdx[k]] === '1'; });
      s.startDate = safeDate(iStart >= 0 ? r[iStart] : null, () => anomaly('CALENDAR_DATE_INVALID', `${id} start_date`));
      s.endDate = safeDate(iEnd >= 0 ? r[iEnd] : null, () => anomaly('CALENDAR_DATE_INVALID', `${id} end_date`));
      widenWindow(feed, s.startDate);
      widenWindow(feed, s.endDate);
    }
  }

  if (parsed.calendar_dates) {
    const t = parsed.calendar_dates;
    const iId = t.columnIndex('service_id');
    const iDate = t.columnIndex('date');
    const iType = t.columnIndex('exception_type');
    if (iId < 0 || iDate < 0 || iType < 0) anomaly('CALENDAR_DATES_HEADER_INVALID', t.header.join(t.delimiter));
    for (const r of t.rows) {
      const id = iId >= 0 ? r[iId] : '';
      const day = safeDate(iDate >= 0 ? r[iDate] : null, () => anomaly('CALENDAR_DATES_DATE_INVALID', `${id} ${r[iDate]}`));
      if (!id || !day) continue;
      const s = getService(feed, id);
      const type = iType >= 0 ? r[iType] : '';
      if (type === '1') { s.addedDates.add(day); widenWindow(feed, day); } else if (type === '2') s.removedDates.add(day);
      else anomaly('CALENDAR_DATES_EXCEPTION_INVALID', `${id} ${type}`);
    }
  }

  if (parsed.trips) {
    const t = parsed.trips;
    const iTrip = t.columnIndex('trip_id');
    const iRoute = t.columnIndex('route_id');
    const iService = t.columnIndex('service_id');
    const iHead = t.columnIndex('trip_headsign');
    const iDir = t.columnIndex('direction_id');
    const iShape = t.columnIndex('shape_id');
    for (const r of t.rows) {
      const tripId = iTrip >= 0 ? r[iTrip] : '';
      const routeId = iRoute >= 0 ? r[iRoute] : '';
      if (!tripId) { anomaly('TRIP_ID_MISSING'); continue; }
      if (feed.trips.has(tripId)) anomaly('TRIP_ID_DUPLICATE', tripId);
      const trip = {
        tripId,
        routeId,
        serviceId: iService >= 0 ? r[iService] : '',
        tripHeadsign: emptyToNull(iHead >= 0 ? r[iHead] : null),
        directionId: emptyToNull(iDir >= 0 ? r[iDir] : null),
        shapeId: emptyToNull(iShape >= 0 ? r[iShape] : null),
      };
      feed.trips.set(tripId, trip);
      if (!feed.tripsByRoute.has(routeId)) feed.tripsByRoute.set(routeId, []);
      feed.tripsByRoute.get(routeId).push(tripId);
    }
  }

  if (typeof texts.stop_times === 'string') {
    const tripIds = [];
    const stopIds = [];
    let sequences = [];
    let arrivals = [];
    let departures = [];
    let missingTimes = 0;
    let invalidTimes = 0;
    const isBlank = (v) => v === undefined || v === null || String(v).trim() === '';
    const intern = new Map();
    const canon = (v) => { let c = intern.get(v); if (c === undefined) { c = v; intern.set(v, c); } return c; };
    let iTrip = -1; let iStop = -1; let iSeq = -1; let iArr = -1; let iDep = -1;
    let headerSeen = false;
    const table = parseCsv(texts.stop_times, {
      onRow: (r, k) => {
        if (!headerSeen) { headerSeen = true; }
        const tripId = iTrip >= 0 ? r[iTrip] : undefined;
        const stopId = iStop >= 0 ? r[iStop] : undefined;
        if (!tripId || !stopId) { anomaly('STOP_TIME_REFERENCE_MISSING', `ligne ${k + 2}`); return; }
        const seq = Number(iSeq >= 0 ? r[iSeq] : NaN);
        const rawArr = iArr >= 0 ? r[iArr] : null;
        const rawDep = iDep >= 0 ? r[iDep] : null;
        const arr = parseTime(rawArr);
        const dep = parseTime(rawDep);
        if ((arr === null && !isBlank(rawArr)) || (dep === null && !isBlank(rawDep))) invalidTimes++;
        if (arr === null && dep === null) missingTimes++;
        const i = tripIds.length;
        const t = canon(tripId);
        const st = canon(stopId);
        tripIds.push(t);
        stopIds.push(st);
        sequences.push(Number.isFinite(seq) ? seq : -1);
        arrivals.push(arr === null ? -1 : arr);
        departures.push(dep === null ? -1 : dep);
        let byTrip = feed.stopTimesByTrip.get(t);
        if (!byTrip) { byTrip = []; feed.stopTimesByTrip.set(t, byTrip); }
        byTrip.push(i);
        let byStop = feed.stopTimesByStop.get(st);
        if (!byStop) { byStop = []; feed.stopTimesByStop.set(st, byStop); }
        byStop.push(i);
      },
      onHeader: (header, columnIndex) => {
        iTrip = columnIndex('trip_id'); iStop = columnIndex('stop_id'); iSeq = columnIndex('stop_sequence');
        iArr = columnIndex('arrival_time'); iDep = columnIndex('departure_time');
      },
    });
    feed.headers.stop_times = table.header;
    sequences = Int32Array.from(sequences);
    arrivals = Int32Array.from(arrivals);
    departures = Int32Array.from(departures);
    feed.stopTimes = { tripIds, stopIds, sequences, arrivals, departures, count: tripIds.length, missingTimes, invalidTimes };
    for (const list of feed.stopTimesByTrip.values()) list.sort((a, b) => sequences[a] - sequences[b]);
  }

  if (typeof texts.shapes === 'string') {
    let iShape = -1;
    let points = 0;
    const table = parseCsv(texts.shapes, {
      onHeader: (header, columnIndex) => { iShape = columnIndex('shape_id'); },
      onRow: (r) => { points++; if (iShape >= 0) feed.shapeIds.add(r[iShape]); },
    });
    feed.headers.shapes = table.header;
    feed.shapeCount = points;
  }
  return feed;
}

function getService(feed, id) {
  let s = feed.services.get(id);
  if (!s) { s = new GtfsService(id); feed.services.set(id, s); }
  return s;
}

function widenWindow(feed, day) {
  if (!day) return;
  const w = feed.calendarWindow;
  if (!w.start || day < w.start) w.start = day;
  if (!w.end || day > w.end) w.end = day;
}

function safeDate(v, onError) {
  try { return normalizeServiceDate(v); } catch (e) { if (onError) onError(); return null; }
}

const emptyToNull = (v) => (v === undefined || v === null || String(v).trim() === '' ? null : v);

/**
 * Validation structurelle et référentielle d'un feed (rapport, jamais de
 * correction). `ok` est faux si un fichier ou une colonne obligatoire manque,
 * si les références sont orphelines ou si aucune heure n'est présente.
 */
function validateFeed(feed) {
  const errors = [];
  const warnings = [];
  const present = new Set(feed.tables);
  for (const f of REQUIRED_FILES) if (!present.has(f)) errors.push(`FILE_MISSING: ${f}.txt`);
  if (!present.has('calendar') && !present.has('calendar_dates')) errors.push('FILE_MISSING: calendar.txt ou calendar_dates.txt');
  for (const [name, cols] of Object.entries(REQUIRED_COLUMNS)) {
    const header = feed.headers[name];
    if (!header) continue;
    for (const c of cols) if (!header.includes(c)) errors.push(`COLUMN_MISSING: ${name}.${c}`);
  }
  const stHeader = feed.headers.stop_times;
  if (stHeader && !stHeader.includes('arrival_time') && !stHeader.includes('departure_time')) errors.push('COLUMN_MISSING: stop_times.arrival_time/departure_time');
  // Références.
  let tripsUnknownRoute = 0; let tripsUnknownService = 0;
  for (const trip of feed.trips.values()) {
    if (!feed.routes.has(trip.routeId)) tripsUnknownRoute++;
    if (!feed.services.has(trip.serviceId)) tripsUnknownService++;
  }
  let stUnknownTrip = 0; let stUnknownStop = 0;
  const st = feed.stopTimes;
  for (let i = 0; i < st.count; i++) {
    if (!feed.trips.has(st.tripIds[i])) stUnknownTrip++;
    if (!feed.stops.has(st.stopIds[i])) stUnknownStop++;
  }
  let tripsWithoutStopTimes = 0; let duplicateSequences = 0;
  for (const tripId of feed.trips.keys()) {
    const idx = feed.stopTimesByTrip.get(tripId);
    if (!idx || idx.length === 0) { tripsWithoutStopTimes++; continue; }
    for (let k = 1; k < idx.length; k++) if (st.sequences[idx[k]] === st.sequences[idx[k - 1]]) { duplicateSequences++; break; }
  }
  if (tripsUnknownRoute) errors.push(`ORPHAN_REFERENCE: ${tripsUnknownRoute} trip(s) → route_id inconnu`);
  if (tripsUnknownService) errors.push(`ORPHAN_REFERENCE: ${tripsUnknownService} trip(s) → service_id inconnu`);
  if (stUnknownTrip) errors.push(`ORPHAN_REFERENCE: ${stUnknownTrip} stop_time(s) → trip_id inconnu`);
  if (stUnknownStop) errors.push(`ORPHAN_REFERENCE: ${stUnknownStop} stop_time(s) → stop_id inconnu`);
  if (tripsWithoutStopTimes) warnings.push(`TRIPS_WITHOUT_STOP_TIMES: ${tripsWithoutStopTimes}`);
  if (duplicateSequences) warnings.push(`DUPLICATE_STOP_SEQUENCE: ${duplicateSequences} trip(s)`);
  const timesPresent = st.count - (st.missingTimes || 0);
  if (st.count > 0 && timesPresent === 0) errors.push('NO_TIMES: aucune heure dans stop_times.txt');
  if (st.invalidTimes) errors.push(`INVALID_TIME: ${st.invalidTimes} stop_time(s) avec une heure non conforme (HH:MM:SS attendu)`);
  let orderErrors = 0;
  for (const idx of feed.stopTimesByTrip.values()) {
    let last = -1;
    for (const i of idx) {
      const t = st.departures[i] >= 0 ? st.departures[i] : st.arrivals[i];
      if (t < 0) continue;
      if (t < last) { orderErrors++; break; }
      last = t;
    }
  }
  if (orderErrors) warnings.push(`TIME_ORDER: ${orderErrors} trip(s) avec des heures non croissantes le long de la course`);
  if (feed.routes.size === 0) errors.push('EMPTY: routes.txt vide');
  if (feed.stops.size === 0) errors.push('EMPTY: stops.txt vide');
  if (feed.trips.size === 0) errors.push('EMPTY: trips.txt vide');
  if (st.count === 0) errors.push('EMPTY: stop_times.txt vide');
  if (feed.services.size === 0) errors.push('EMPTY: aucun service (calendar / calendar_dates)');
  const routesWithoutShortName = feed.routeList().filter((r) => !r.routeShortName).length;
  if (routesWithoutShortName) warnings.push(`ROUTE_SHORT_NAME_MISSING: ${routesWithoutShortName} route(s)`);
  const directions = new Set();
  for (const trip of feed.trips.values()) directions.add(trip.directionId === null ? '' : trip.directionId);
  for (const d of directions) if (d !== '' && d !== '0' && d !== '1') warnings.push(`DIRECTION_ID_INVALID: ${d}`);
  for (const a of feed.anomalies) warnings.push(a);
  return {
    ok: errors.length === 0,
    errors,
    warnings,
    counts: feed.counts,
    timesPresent,
    calendarWindow: feed.calendarWindow,
    tables: Array.from(present).sort(),
    directions: Array.from(directions).sort(),
  };
}

module.exports = {
  GtfsFeed, GtfsService, buildFeed, buildFeedFromTexts, validateFeed,
  REQUIRED_FILES, CALENDAR_FILES, OPTIONAL_FILES, ENGINE_TABLES, REQUIRED_COLUMNS, tableName,
};
