'use strict';
/**
 * Lot 4.6 — Tests du moteur horaire pur.
 *
 * Couvre : exact, départ immédiat, départ passé, aucun départ exact (ESTIMATED),
 * UNKNOWN, GTFS >24h, changement de jour, calendrier, TER 48, BRT 6 min, DDD/AFTU UNKNOWN.
 *
 * Aucune heure inventée : toutes les fixtures sont synthétiques sauf les vérifications
 * TER qui lisent les fichiers réels du dépôt.
 */
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { ServiceDate, ServiceTime } = require('../data/transit/engine/gtfs_time');
const { ScheduleEngine, isServiceActiveOn } = require('../data/transit/engine/schedule_engine');
const { FixedClock } = require('../data/transit/engine/clock');

const ROOT = path.join(__dirname, '..');
const REG = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8'));
const CALENDAR_TXT = fs.readFileSync(path.join(ROOT, 'data/transit/validated/gtfs/calendar.txt'), 'utf8');

// Helpers
function svcDate(str) { return ServiceDate.parse(str); }
function svcTime(str) { return ServiceTime.parse(str); }
function utc(str) { return new Date(str); } // expects ISO Z

function makeDataset(times, opts = {}) {
  const route = opts.routeId || 'test_route_synthetic_only';
  const stop = opts.stopId || 'test_stop_synthetic_only';
  const serviceId = opts.serviceId || 'test_service_synthetic_only';
  const scheduleStatus = opts.scheduleStatus || 'SCHEDULED';
  const validFrom = opts.validFrom || '20260928';
  const validTo = opts.validTo || '20261010';
  const stopTimes = times.map((t,i) => ({
    route_id: route,
    service_id: serviceId,
    trip_id: `test_trip_${String(i).padStart(2,'0')}_synthetic_only`,
    stop_id: stop,
    stop_sequence: 1,
    arrival_time: t,
    departure_time: t,
    schedule_status: scheduleStatus,
    realtime_status: 'UNKNOWN',
    source: 'test-fixture://synthetic-only-not-production-data',
    source_url: 'test-fixture://synthetic-only-not-production-data',
    valid_from: validFrom,
    valid_to: validTo,
  }));
  const services = opts.services || [{
    service_id: serviceId,
    monday: 1, tuesday:1, wednesday:1, thursday:1, friday:1, saturday:1, sunday:0,
    start_date: validFrom, end_date: validTo, exceptions: []
  }];
  const frequencies = opts.frequencies || [];
  return { stopTimes, services, frequencies };
}

// =================================================================== Exact
test('Exact : maintenant 08:17, départ 08:20 → 3 min (SCHEDULED)', () => {
  const engine = new ScheduleEngine(makeDataset(['08:20:00','08:30:00']));
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '08:20:00');
  assert.equal(res.minutesUntil, 3);
  assert.equal(res.secondsUntil, 180);
});

test('Départ immédiat : départ réellement à 08:17 → Départ maintenant (0 min)', () => {
  const engine = new ScheduleEngine(makeDataset(['08:17:00','08:30:00']));
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.minutesUntil, 0);
  assert.equal(res.secondsUntil, 0);
});

test('Départ passé : 08:10 passé, prochain = 08:20', () => {
  const engine = new ScheduleEngine(makeDataset(['08:10:00','08:20:00','08:30:00']));
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:15:00Z')
  });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '08:20:00');
  assert.equal(res.minutesUntil, 5);
});

// =================================================================== ESTIMATED / UNKNOWN
test('Aucun départ exact mais fréquence 10 min → ESTIMATED', () => {
  const engine = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id: 'test_route_synthetic_only', service_id: 'FREQ', headway_min: 10, schedule_status: 'ESTIMATED' }],
    services: []
  });
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(res.status, 'ESTIMATED');
  assert.equal(res.frequencyMinutes, 10);
  assert.equal(res.scheduledTime, null);
  assert.equal(res.minutesUntil, null);
});

test('UNKNOWN : aucune donnée horaire → UNKNOWN', () => {
  const engine = new ScheduleEngine({ stopTimes: [], frequencies: [], services: [] });
  const res = engine.nextDeparture({
    routeId: 'unknown_route',
    stopId: 'unknown_stop',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(res.status, 'UNKNOWN');
  assert.equal(res.scheduledTime, null);
});

test('Ne jamais produire 0 min par défaut : UNKNOWN n’a pas de minutesUntil', () => {
  const engine = new ScheduleEngine({ stopTimes: [], frequencies: [], services: [] });
  const res = engine.nextDeparture({
    routeId: 'unknown_route',
    stopId: 'unknown_stop',
    serviceDate: '2026-09-28',
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(res.minutesUntil, null);
  assert.notEqual(res.minutesUntil, 0);
});

// =================================================================== GTFS >24h
test('GTFS >24h : 25:15:00 correctement interprété comme lendemain 01:15', () => {
  const st = svcTime('25:15:00');
  assert.equal(st.hour, 25);
  assert.equal(st.secondsSinceServiceDayStart, 25*3600+15*60);
  const d = svcDate('2026-09-27');
  const instant = st.toInstant(d);
  assert.equal(instant.toISOString(), '2026-09-28T01:15:00.000Z');
  assert.equal(st.civilDate(d).toString(), '2026-09-28');

  const engine = new ScheduleEngine(makeDataset(['25:15:00'], { validFrom:'20260927', validTo:'20260928', services: [{
    service_id: 'test_service_synthetic_only',
    monday:1, tuesday:1, wednesday:1, thursday:1, friday:1, saturday:1, sunday:1,
    start_date:'20260927', end_date:'20260928', exceptions:[]
  }] }));
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-27',
    now: utc('2026-09-28T01:10:00Z')
  });
  // Le départ 25:15 du service 2026-09-27 est à 2026-09-28T01:15:00Z, donc 5 min après 01:10
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '25:15:00');
  assert.equal(res.minutesUntil, 5);
});

test('GTFS >24h : conservé tel quel, jamais réécrit en 01:15', () => {
  const raw = '25:15:00';
  const parsed = ServiceTime.parse(raw);
  assert.equal(parsed.toString(), '25:15:00');
  assert.notEqual(parsed.toString(), '01:15:00');
});

// =================================================================== Changement de jour
test('Changement de jour : départ après minuit trouvé depuis la veille', () => {
  const engine = new ScheduleEngine(makeDataset(['00:10:00'], { serviceDate: '2026-09-28' }));
  // Si on est le 27 à 23:55, le prochain départ du service 28 à 00:10 est dans 15 min via scan jour suivant
  const res = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T23:55:00Z')
  });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '00:10:00');
  assert.equal(res.minutesUntil, 15);
});

// =================================================================== Calendrier
test('Calendrier : service actif un lundi → trouvé, dimanche → prochain lundi trouvé via scan', () => {
  const dataset = makeDataset(['08:20:00'], {
    services: [{
      service_id: 'test_service_synthetic_only',
      monday:1, tuesday:0, wednesday:0, thursday:0, friday:0, saturday:0, sunday:0,
      start_date:'20260928', end_date:'20261010', exceptions:[]
    }]
  });
  const engine = new ScheduleEngine(dataset);
  const monday = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-28', // monday
    now: utc('2026-09-28T08:17:00Z')
  });
  assert.equal(monday.status, 'SCHEDULED');

  const sunday = engine.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    serviceDate: '2026-09-27', // sunday 27/09 is actually Sunday
    now: utc('2026-09-27T08:17:00Z')
  });
  // Service non actif ce dimanche, le moteur scanne le jour suivant et trouve lundi 08:20 → SCHEDULED (comportement Dart identique)
  assert.equal(sunday.status, 'SCHEDULED');
  assert.equal(sunday.scheduledTime, '08:20:00');
});

test('Calendrier : exception ajout et retrait', () => {
  const svc = {
    service_id: 'S1',
    monday:0, tuesday:0, wednesday:0, thursday:0, friday:0, saturday:0, sunday:0,
    start_date:'20260927', end_date:'20261010',
    exceptions: [{date:'20260928', exception_type:1}, {date:'20260929', exception_type:2}]
  };
  assert.equal(isServiceActiveOn(svc, svcDate('2026-09-28')), true);
  assert.equal(isServiceActiveOn(svc, svcDate('2026-09-29')), false);
  assert.equal(isServiceActiveOn(svc, svcDate('2026-09-30')), false);
});

// =================================================================== TER — 48 départs
test('TER : vérifier les 48 départs corroborés du dimanche — PARTIALLY_CONFIRMED', () => {
  // Lire le registre réel
  assert.equal(REG.stats.stop_times, 624);
  assert.equal(REG.stats.by_schedule_status.PARTIALLY_CONFIRMED, 48);
  assert.equal(REG.stats.by_schedule_status.UNCONFIRMED, 576);
  assert.equal(REG.stats.by_schedule_status.SCHEDULED, 0);

  const engine = ScheduleEngine.fromRegistry(REG);
  // Premier départ Dakar 06:25
  const first = engine.nextDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T06:20:00Z')
  });
  assert.equal(first.status, 'PARTIALLY_CONFIRMED');
  assert.equal(first.scheduledTime, '06:25:00');
  assert.equal(first.minutesUntil, 5);

  // 08:17 → 08:25 (grille 20 min)
  const mid = engine.nextDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(mid.status, 'PARTIALLY_CONFIRMED');
  assert.equal(mid.scheduledTime, '08:25:00');
  assert.equal(mid.minutesUntil, 8);

  // Après dernier départ 22:05 → UNKNOWN ou ESTIMATED ?
  const after = engine.nextDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T22:10:00Z')
  });
  // Aucun départ exact futur ce jour, mais fréquence ESTIMATED existe → ESTIMATED
  assert.equal(after.status, 'ESTIMATED');
  assert.equal(after.frequencyMinutes, 20);
});

test('TER : horaires intermédiaires 576 restent UNCONFIRMED et non promus', () => {
  const engine = ScheduleEngine.fromRegistry(REG);
  const res = engine.nextDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_colobane', // intermédiaire
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T06:20:00Z')
  });
  // Les 576 intermédiaires sont UNCONFIRMED, donc l'engine ne les considère pas comme exacts → ESTIMATED via fréquence
  assert.equal(res.status, 'ESTIMATED');
  assert.equal(res.frequencyMinutes, 20);
});

// =================================================================== BRT
test('BRT : fréquence 6 min → ESTIMATED, aucune création de faux départs', () => {
  const engine = ScheduleEngine.fromRegistry(REG);
  const brt = engine.nextDeparture({
    routeId: 'brt_b1',
    stopId: 'any_stop',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(brt.status, 'ESTIMATED');
  assert.equal(brt.frequencyMinutes, 6);
  assert.equal(brt.scheduledTime, null);
  assert.equal(brt.minutesUntil, null);

  const b2 = engine.nextDeparture({
    routeId: 'brt_b2',
    stopId: 'any_stop',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(b2.status, 'ESTIMATED');
  assert.equal(b2.frequencyMinutes, 6);

  // B3 n'a qu'une identité NEW mais pas de fréquence horaire exacte non plus — ESTIMATED ou UNKNOWN ?
  // B3 n'a pas de fréquence dans le registre (seules B1/B2 ont 6 min), donc UNKNOWN
  const b3 = engine.nextDeparture({
    routeId: 'brt_b3',
    stopId: 'any_stop',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  // B3 n'a pas de fréquence horaire documentée comme exploitable pour nextDeparture, donc UNKNOWN
  // (ou ESTIMATED si on considère qu'elle partage la même fréquence — mais on distingue B3)
  // Notre registre n'a que B1/B2 en ESTIMATED, donc B3 → UNKNOWN
  assert.equal(b3.status, 'UNKNOWN');
});

// =================================================================== DDD / AFTU
test('DDD : identité confirmée mais horaire UNKNOWN', () => {
  const engine = ScheduleEngine.fromRegistry(REG);
  const ddd = engine.nextDeparture({
    routeId: 'ddd_1',
    stopId: 'stop_parcelles',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(ddd.status, 'UNKNOWN');
  assert.match(ddd.reason, /Aucune donnée horaire|IDENTITY/);
});

test('AFTU : identité confirmée mais horaire UNKNOWN', () => {
  const engine = ScheduleEngine.fromRegistry(REG);
  const aftu = engine.nextDeparture({
    routeId: 'aftu_1',
    stopId: 'stop_lat_dior',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(aftu.status, 'UNKNOWN');
});

// =================================================================== REAL_TIME
test('REAL_TIME : uniquement avec prédiction fraîche, sinon ESTIMATED/UNKNOWN', () => {
  const now = utc('2026-09-27T08:17:00Z');
  const fresh = new Date(now.getTime() - 60*1000); // observé il y a 1 min
  const predicted = new Date(now.getTime() + 3*60*1000); // dans 3 min
  const stale = new Date(now.getTime() - 10*60*1000); // 10 min old, > maxAge 5 min
  const engineFresh = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id: 'test_route_synthetic_only', service_id: 'FREQ', headway_min: 10, schedule_status: 'ESTIMATED' }],
    services: [],
    realtimePredictions: [{
      routeId: 'test_route_synthetic_only',
      tripId: 'T1',
      stopId: 'test_stop_synthetic_only',
      stopSequence: 1,
      directionId: 0,
      serviceDate: svcDate('2026-09-27'),
      predictedDepartureAt: predicted,
      observedAt: fresh,
      provenance: {}
    }],
    realtimeMaxAgeMs: 5*60*1000
  });
  const rt = engineFresh.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    directionId: 0,
    serviceDate: '2026-09-27',
    now
  });
  assert.equal(rt.status, 'REAL_TIME');
  assert.equal(rt.minutesUntil, 3);

  const engineStale = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id: 'test_route_synthetic_only', service_id: 'FREQ', headway_min: 10, schedule_status: 'ESTIMATED' }],
    services: [],
    realtimePredictions: [{
      routeId: 'test_route_synthetic_only',
      tripId: 'T1',
      stopId: 'test_stop_synthetic_only',
      stopSequence: 1,
      directionId: 0,
      serviceDate: svcDate('2026-09-27'),
      predictedDepartureAt: predicted,
      observedAt: stale,
      provenance: {}
    }],
  });
  const staleRes = engineStale.nextDeparture({
    routeId: 'test_route_synthetic_only',
    stopId: 'test_stop_synthetic_only',
    directionId: 0,
    serviceDate: '2026-09-27',
    now
  });
  // Prédiction périmée → fallback ESTIMATED
  assert.equal(staleRes.status, 'ESTIMATED');
});
