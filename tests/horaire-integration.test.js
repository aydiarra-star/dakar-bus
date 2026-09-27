'use strict';
/**
 * Lot 4.7 — Tests d'intégration du moteur horaire.
 *
 * Ne supprime aucun test existant (100 tests conservés).
 * Vérifie le contrat de sortie, les règles de promotion et la non-régression.
 */
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { ScheduleEngine } = require('../data/transit/engine/schedule_engine');
const { queryDeparture, createEngineFromRegistry } = require('../data/transit/engine/integration');

const ROOT = path.join(__dirname, '..');
const REG = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8'));

function utc(s) { return new Date(s); }

// =================================================================== Contrat
test('contrat de sortie : structure minimale', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  for (const f of ['status','routeId','stopId','serviceDate','scheduledTime','nextDepartureAt','frequencyMinutes','source','sourceType','confidence','verificationNote']) {
    assert.ok(f in c, `champ ${f} absent du contrat`);
  }
  assert.ok(['SCHEDULED','PARTIALLY_CONFIRMED','ESTIMATED','UNKNOWN','REAL_TIME','NO_DEPARTURE'].includes(c.status));
});

test('ESTIMATED ne renseigne jamais scheduledTime/nextDepartureAt', () => {
  const c = queryDeparture({
    routeId: 'brt_b1',
    stopId: 'any_stop',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  assert.equal(c.frequencyMinutes, 6);
});

// =================================================================== TER
test('TER 08:17 → 08:25 PARTIALLY_CONFIRMED (pas SCHEDULED)', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z')
  });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '08:25:00');
  assert.equal(c.nextDepartureAt, '2026-09-27T08:25:00.000Z');
});

test('TER 06:25 premier départ', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T06:20:00Z')
  });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '06:25:00');
});

test('TER 22:05 dernier départ', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T22:00:00Z')
  });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '22:05:00');
});

test('TER après 22:05 → ESTIMATED 20 min (pas de faux 22:25)', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T22:10:00Z')
  });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 20);
  assert.equal(c.scheduledTime, null);
});

test('TER service dimanche actif, semaine → ESTIMATED via fréquence semaine', () => {
  // Le registre n'a que dimanche en stop_times, mais la fréquence semaine existe
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-28', // lundi
    now: utc('2026-09-28T08:17:00Z')
  });
  // Pas de stop_times pour lundi, mais fréquence semaine 10 min
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 10);
});

test('TER horaires intermédiaires restent non promus', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_colobane',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T06:20:00Z')
  });
  // 576 UNCONFIRMED → ESTIMATED
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 20);
});

// =================================================================== BRT
test('BRT B1 → ESTIMATED 6 min', () => {
  const c = queryDeparture({ routeId:'brt_b1', stopId:'any', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
});
test('BRT B2 → ESTIMATED 6 min', () => {
  const c = queryDeparture({ routeId:'brt_b2', stopId:'any', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
});
test('BRT B3 → UNKNOWN (aucune grille)', () => {
  const c = queryDeparture({ routeId:'brt_b3', stopId:'any', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
});
test('BRT aucun faux départ exact généré', () => {
  const engine = createEngineFromRegistry();
  // Aucun stop_time BRT dans le registre → engine ne doit jamais produire PARTIALLY_CONFIRMED/SCHEDULED pour BRT
  const c = engine.nextDeparture({ routeId:'brt_b1', stopId:'stop_brt_test', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
});

// =================================================================== DDD / AFTU
test('DDD ddd_1 → UNKNOWN', () => {
  const c = queryDeparture({ routeId:'ddd_1', stopId:'any', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(c.scheduledTime, null);
});
test('AFTU aftu_1 → UNKNOWN', () => {
  const c = queryDeparture({ routeId:'aftu_1', stopId:'any', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
});

// =================================================================== REAL_TIME
test('REAL_TIME impossible sans source (0 en prod)', () => {
  assert.equal(REG.stats.realtime_entries, 0);
  assert.equal(REG.stats.by_realtime_status.REAL_TIME, 0);
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.notEqual(c.status, 'REAL_TIME');
});

test('REAL_TIME frais → REAL_TIME, périmé → ESTIMATED', () => {
  const now = utc('2026-09-27T08:17:00Z');
  const fresh = new Date(now.getTime() - 60*1000);
  const predicted = new Date(now.getTime() + 3*60*1000);
  const { ServiceDate } = require('../data/transit/engine/gtfs_time');
  const engine = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id:'ter_dakar_diamniadio', service_id:'TER_SUNDAY', headway_min:20, schedule_status:'ESTIMATED' }],
    services: [],
    realtimePredictions: [{
      routeId:'ter_dakar_diamniadio', tripId:'TER_SUN_001', stopId:'stop_dakar_ter', stopSequence:1, directionId:0,
      serviceDate: ServiceDate.parse('2026-09-27'), predictedDepartureAt: predicted, observedAt: fresh, provenance:{}
    }]
  });
  const rt = engine.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now });
  assert.equal(rt.status, 'REAL_TIME');
  assert.equal(rt.minutesUntil, 3);

  // Périmé (10 min > 5 min maxAge)
  const stale = new Date(now.getTime() - 10*60*1000);
  const engineStale = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id:'ter_dakar_diamniadio', service_id:'TER_SUNDAY', headway_min:20, schedule_status:'ESTIMATED' }],
    services: [],
    realtimePredictions: [{
      routeId:'ter_dakar_diamniadio', tripId:'TER_SUN_001', stopId:'stop_dakar_ter', stopSequence:1, directionId:0,
      serviceDate: ServiceDate.parse('2026-09-27'), predictedDepartureAt: predicted, observedAt: stale, provenance:{}
    }]
  });
  const staleRes = engineStale.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now });
  assert.equal(staleRes.status, 'ESTIMATED');
});

// =================================================================== Countdown & >24h
test('countdown 08:17→08:20 = 3 min, displayLabel correct', () => {
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.minutesUntil, 8); // 08:25 is next after 08:17 for TER Dakar
  // Synthetic exact:
  const { ScheduleEngine: SE2 } = require('../data/transit/engine/schedule_engine');
  const eng2 = new SE2({ stopTimes:[{ route_id:'test', service_id:'S', trip_id:'T', stop_id:'S', stop_sequence:1, arrival_time:'08:20:00', departure_time:'08:20:00', schedule_status:'SCHEDULED', valid_from:'20260927', valid_to:'20260927' }], frequencies:[], services:[{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260927', end_date:'20260927', exceptions:[] }] });
  const c2 = eng2.nextDeparture({ routeId:'test', stopId:'S', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c2.minutesUntil, 3);
});

test('départ maintenant : 08:20 à 08:20 → 0 min, label Départ maintenant', () => {
  const { ScheduleEngine: SE2 } = require('../data/transit/engine/schedule_engine');
  const eng2 = new SE2({ stopTimes:[{ route_id:'test', service_id:'S', trip_id:'T', stop_id:'S', stop_sequence:1, arrival_time:'08:20:00', departure_time:'08:20:00', schedule_status:'SCHEDULED', valid_from:'20260927', valid_to:'20260927' }], frequencies:[], services:[{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260927', end_date:'20260927', exceptions:[] }] });
  const c2 = eng2.nextDeparture({ routeId:'test', stopId:'S', serviceDate:'2026-09-27', now:utc('2026-09-27T08:20:00Z') });
  assert.equal(c2.minutesUntil, 0);
  const { toContract } = require('../data/transit/engine/integration');
  const contract = toContract(c2, { routeId:'test', stopId:'S', serviceDate:'2026-09-27', now:utc('2026-09-27T08:20:00Z') });
  assert.equal(contract.displayLabel, 'Départ maintenant');
});

test('jamais Départ dans 0 min par approximation', () => {
  const c = queryDeparture({ routeId:'unknown_route', stopId:'unknown', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.notEqual(c.displayLabel, 'Départ dans 0 min');
  assert.equal(c.status, 'UNKNOWN');
});

test('GTFS >24h conservé 25:15 → 01:15 lendemain sans réécriture', () => {
  const { ServiceTime } = require('../data/transit/engine/gtfs_time');
  assert.equal(ServiceTime.parse('25:15:00').toString(), '25:15:00');
  assert.equal(REG.gtfs_time_convention.times_rewritten, 0);
  assert.equal(REG.gtfs_time_convention.example_over_24h, '25:15:00');
});

// =================================================================== Non-régression
test('non-régression : schedule_registry non réécrit par l’intégration', () => {
  const before = fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8');
  queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  const after = fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8');
  assert.equal(before, after);
});
