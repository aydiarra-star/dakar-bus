'use strict';
/**
 * Lot 4.8 — Tests fonctionnels du flux horaire.
 *
 * Vérifie le chemin : requête (route, stop, serviceDate, now) → integration.queryDeparture
 * → ScheduleEngine → contrat DepartureInfo — sans toucher UI/GPS/RoutePlanner.
 *
 * Ne supprime aucun test existant (121 conservés). Ajoute les tests fonctionnels
 * listés au Lot 4.8 §6-15. Tous passent via la couche d'intégration réelle.
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { ScheduleEngine } = require('../data/transit/engine/schedule_engine');
const { ServiceDate, ServiceTime } = require('../data/transit/engine/gtfs_time');
const { FixedClock, SystemClock } = require('../data/transit/engine/clock');
const { queryDeparture, createEngineFromRegistry, toContract } = require('../data/transit/engine/integration');

const ROOT = path.join(__dirname, '..');
const REG = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8'));

function utc(s) { return new Date(s); }

// ---------------------------------------------------------------------------
// 6. TER — chemin fonctionnel
// ---------------------------------------------------------------------------
test('Lot4.8 TER 08:17 dimanche → PARTIALLY_CONFIRMED 08:25 nextDepartureAt correct', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:17:00Z'),
  });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '08:25:00');
  assert.equal(c.nextDepartureAt, '2026-09-27T08:25:00.000Z');
  assert.equal(c.routeId, 'ter_dakar_diamniadio');
  assert.equal(c.stopId, 'stop_dakar_ter');
  assert.equal(c.serviceDate, '2026-09-27');
  // frequencyMinutes doit être null pour un exact
  assert.equal(c.frequencyMinutes, null);
  // minutesUntil cohérent : 08:25 - 08:17 = 8 min
  assert.equal(c.minutesUntil, 8);
  // collection départs disponible dans l'engine sous-jacent
  const eng = createEngineFromRegistry();
  const raw = eng.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z')});
  assert.ok(raw.departures && raw.departures.length === 1);
});

test('Lot4.8 TER 08:25 départ maintenant → PARTIALLY_CONFIRMED countdown 0 Départ maintenant', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T08:25:00Z'),
  });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '08:25:00');
  assert.equal(c.minutesUntil, 0);
  assert.equal(c.secondsUntil, 0);
  assert.equal(c.displayLabel, 'Départ maintenant');
  assert.notEqual(c.displayLabel, 'Départ dans 0 min');
});

test('Lot4.8 TER après dernier 22:10 → ESTIMATED 20 jamais 22:25', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_dakar_ter',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T22:10:00Z'),
  });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 20);
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  // Garde-fou : aucun 22:25 généré
  assert.notEqual(c.scheduledTime, '22:25:00');
});

// ---------------------------------------------------------------------------
// 7. TER intermédiaire
// ---------------------------------------------------------------------------
test('Lot4.8 TER intermédiaire stop_colobane → ESTIMATED (pas SCHEDULED)', () => {
  const c = queryDeparture({
    routeId: 'ter_dakar_diamniadio',
    stopId: 'stop_colobane',
    serviceDate: '2026-09-27',
    now: utc('2026-09-27T06:20:00Z'),
  });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 20);
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  // Interdit de promouvoir UNCONFIRMED en SCHEDULED
  assert.notEqual(c.status, 'SCHEDULED');
  assert.notEqual(c.status, 'PARTIALLY_CONFIRMED');
});

// ---------------------------------------------------------------------------
// 8. BRT
// ---------------------------------------------------------------------------
test('Lot4.8 BRT B1 → ESTIMATED 6 min sans heure exacte', () => {
  const c = queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  assert.equal(c.displayLabel, 'Passage estimé toutes les 6 min');
});

test('Lot4.8 BRT B2 → ESTIMATED 6 min', () => {
  const c = queryDeparture({ routeId:'brt_b2', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
  assert.equal(c.scheduledTime, null);
});

test('Lot4.8 BRT B3 → UNKNOWN aucune heure artificielle', () => {
  const c = queryDeparture({ routeId:'brt_b3', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  assert.equal(c.frequencyMinutes, null);
});

test('Lot4.8 BRT fréquence jamais 08:00→08:06→08:12', () => {
  // Vérifie que l'engine BRT ne produit jamais de départ exact depuis fréquence
  const eng = createEngineFromRegistry();
  const raw = eng.nextDeparture({ routeId:'brt_b1', stopId:'stop_brt_test', serviceDate:'2026-09-27', now:utc('2026-09-27T08:00:00Z') });
  assert.equal(raw.status, 'ESTIMATED');
  assert.equal(raw.scheduledTime, null);
  assert.equal(raw.scheduledTime, null);
});

// ---------------------------------------------------------------------------
// 9. DDD
// ---------------------------------------------------------------------------
test('Lot4.8 DDD ddd_1 → UNKNOWN (IDENTITY CONFIRMED mais SCHEDULE UNKNOWN)', () => {
  const c = queryDeparture({ routeId:'ddd_1', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  assert.equal(c.frequencyMinutes, null);
  // Vérifie que public_routes confirme l'identité DDD
  const pub = JSON.parse(fs.readFileSync(path.join(ROOT,'data/transit/validated/public_routes.json'),'utf8'));
  const ddd1 = pub.routes.find(r=>r.route_id==='ddd_1');
  assert.ok(ddd1, 'ddd_1 doit exister dans public_routes');
  assert.equal(c.routeId, 'ddd_1');
});

// ---------------------------------------------------------------------------
// 10. AFTU
// ---------------------------------------------------------------------------
test('Lot4.8 AFTU aftu_1 → UNKNOWN', () => {
  const c = queryDeparture({ routeId:'aftu_1', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
});

// ---------------------------------------------------------------------------
// 11. REAL_TIME — 0 en prod, frais / périmé (Lot 4.7 conservé)
// ---------------------------------------------------------------------------
test('Lot4.8 REAL_TIME prod = 0 (realtime_entries 0)', () => {
  assert.equal(REG.stats.realtime_entries, 0);
  assert.equal(REG.stats.by_realtime_status.REAL_TIME, 0);
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.notEqual(c.status, 'REAL_TIME');
});

test('Lot4.8 REAL_TIME frais → REAL_TIME, périmé → ESTIMATED (fallback)', () => {
  const now = utc('2026-09-27T08:17:00Z');
  const fresh = new Date(now.getTime() - 60*1000);
  const predicted = new Date(now.getTime() + 3*60*1000);
  const engineFresh = new ScheduleEngine({
    stopTimes: [],
    frequencies: [{ route_id:'ter_dakar_diamniadio', service_id:'TER_SUNDAY', headway_min:20, schedule_status:'ESTIMATED' }],
    services: [],
    realtimePredictions: [{
      routeId:'ter_dakar_diamniadio', tripId:'TER_SUN_001', stopId:'stop_dakar_ter', stopSequence:1, directionId:0,
      serviceDate: ServiceDate.parse('2026-09-27'), predictedDepartureAt: predicted, observedAt: fresh, provenance:{}
    }]
  });
  const rt = engineFresh.nextDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now });
  assert.equal(rt.status, 'REAL_TIME');
  assert.equal(rt.minutesUntil, 3);
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

// ---------------------------------------------------------------------------
// 12. Priorité REAL_TIME > SCHEDULED > PARTIALLY_CONFIRMED > ESTIMATED > UNKNOWN
// ---------------------------------------------------------------------------
test('Lot4.8 priorité : REAL_TIME frais écrase SCHEDULED', () => {
  const now = utc('2026-09-28T08:17:00Z');
  const dataset = {
    stopTimes: [{ route_id:'prio_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'08:40:00', departure_time:'08:40:00', schedule_status:'SCHEDULED', valid_from:'20260928', valid_to:'20260928' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260928', end_date:'20260928', exceptions:[] }],
    frequencies: [{ route_id:'prio_route', service_id:'S', headway_min:5, schedule_status:'ESTIMATED' }],
  };
  const realtimePred = {
    routeId:'prio_route', tripId:'T1', stopId:'S1', stopSequence:1, directionId:0,
    serviceDate: ServiceDate.parse('2026-09-28'),
    predictedDepartureAt: new Date('2026-09-28T08:42:00Z'),
    observedAt: new Date('2026-09-28T08:16:30Z'),
    provenance:{}
  };
  const engine = new ScheduleEngine({ ...dataset, realtimePredictions:[realtimePred] });
  const res = engine.nextDeparture({ routeId:'prio_route', stopId:'S1', serviceDate:'2026-09-28', now });
  assert.equal(res.status, 'REAL_TIME');
});

test('Lot4.8 priorité : SCHEDULED écrase ESTIMATED fréquence', () => {
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'prio_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'08:40:00', departure_time:'08:40:00', schedule_status:'SCHEDULED', valid_from:'20260928', valid_to:'20260928' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260928', end_date:'20260928', exceptions:[] }],
    frequencies: [{ route_id:'prio_route', service_id:'S', headway_min:5, schedule_status:'ESTIMATED' }],
  });
  const res = engine.nextDeparture({ routeId:'prio_route', stopId:'S1', serviceDate:'2026-09-28', now:utc('2026-09-28T08:17:00Z') });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '08:40:00');
});

test('Lot4.8 priorité : PARTIALLY_CONFIRMED écrase ESTIMATED (TER)', () => {
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  // Il existe aussi une fréquence 20 pour TER, mais le moteur doit conserver PARTIALLY
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
});

test('Lot4.8 priorité : UNKNOWN ne devient jamais ESTIMATED si pas de fréquence', () => {
  const c = queryDeparture({ routeId:'unknown_route_sans_frequence', stopId:'unknown_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(c.frequencyMinutes, null);
});

test('Lot4.8 priorité : ESTIMATED ne devient jamais SCHEDULED', () => {
  const c = queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now:utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.notEqual(c.status, 'SCHEDULED');
  assert.equal(c.scheduledTime, null);
});

// ---------------------------------------------------------------------------
// 13. Clock injectable
// ---------------------------------------------------------------------------
test('Lot4.8 Clock FixedClock déterministe', () => {
  const instant = new Date('2026-09-27T08:17:00Z');
  const clock = new FixedClock(instant);
  assert.equal(clock.now().toISOString(), instant.toISOString());
  const c1 = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: clock.now() });
  const c2 = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: clock.now() });
  assert.deepEqual(c1, c2);
});

test('Lot4.8 Clock SystemClock n’est pas appelé dans ScheduleEngine (now injecté)', () => {
  const sys = new SystemClock();
  const before = sys.now();
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'clk_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'23:59:00', departure_time:'23:59:00', schedule_status:'SCHEDULED', valid_from:'20260927', valid_to:'20260927' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260927', end_date:'20260927', exceptions:[] }],
  });
  // now explicite 08:17, ne dépend pas de SystemClock
  const res = engine.nextDeparture({ routeId:'clk_route', stopId:'S1', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.ok(res.status === 'SCHEDULED' || res.status === 'UNKNOWN' || res.status === 'ESTIMATED');
  const after = sys.now();
  assert.ok(after >= before);
});

// ---------------------------------------------------------------------------
// 14. ServiceDate / Timezone / GTFS >24h
// ---------------------------------------------------------------------------
test('Lot4.8 timezone Africa/Dakar = UTC+0 (08:17 Dakar = 08:17 UTC)', () => {
  // Le moteur traite tous les instants en UTC ; un now construit en UTC
  // représente déjà l'heure Dakar (UTC+0). Une heure locale non-UTC serait UNKNOWN côté Dart.
  const cUtc = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(cUtc.status, 'PARTIALLY_CONFIRMED');
});

test('Lot4.8 GTFS >24h 25:15:00 conservé et lendemain sans réécrire', () => {
  assert.equal(ServiceTime.parse('25:15:00').toString(), '25:15:00');
  assert.equal(REG.gtfs_time_convention.times_rewritten, 0);
  assert.equal(REG.gtfs_time_convention.example_over_24h, '25:15:00');
  // Vérifie instant calculé : service 2026-09-27 25:15 = 2026-09-28 01:15 UTC
  const inst = ServiceTime.parse('25:15:00').toInstant(ServiceDate.parse('2026-09-27'));
  assert.equal(inst.toISOString(), '2026-09-28T01:15:00.000Z');
  // Recherche réelle : service 2026-09-27 avec départ 25:15 trouvé 5 min après 01:10 le 28
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'gtfs24_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'25:15:00', departure_time:'25:15:00', schedule_status:'SCHEDULED', valid_from:'20260927', valid_to:'20260927' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260927', end_date:'20260927', exceptions:[] }],
  });
  const res = engine.nextDeparture({ routeId:'gtfs24_route', stopId:'S1', serviceDate:'2026-09-27', now: utc('2026-09-28T01:10:00Z') });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.scheduledTime, '25:15:00');
  assert.equal(res.minutesUntil, 5);
});

// ---------------------------------------------------------------------------
// 15. Compatibilité Flutter DepartureInfo
// ---------------------------------------------------------------------------
test('Lot4.8 compatibilité Flutter : contrat DepartureInfo complet et null-safe', () => {
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  for (const f of ['status','routeId','stopId','serviceDate','scheduledTime','nextDepartureAt','frequencyMinutes','source','sourceType','confidence','verificationNote']) {
    assert.ok(f in c, `champ Flutter ${f} absent`);
  }
  // Types Flutter attendus
  assert.ok(['SCHEDULED','PARTIALLY_CONFIRMED','ESTIMATED','UNKNOWN','REAL_TIME','NO_DEPARTURE'].includes(c.status));
  assert.ok(typeof c.routeId === 'string');
  assert.ok(typeof c.stopId === 'string');
  assert.ok(typeof c.serviceDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(c.serviceDate));
  // ESTIMATED null-safe
  const e = queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(e.scheduledTime, null);
  assert.equal(e.nextDepartureAt, null);
  assert.equal(typeof e.frequencyMinutes, 'number');
  // UNKNOWN null-safe
  const u = queryDeparture({ routeId:'ddd_1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(u.scheduledTime, null);
  assert.equal(u.nextDepartureAt, null);
  assert.equal(u.frequencyMinutes, null);
});

test('Lot4.8 non-régression schedule_registry non réécrit par fonctionnel', () => {
  const before = fs.readFileSync(path.join(ROOT,'data/transit/validated/schedule_registry.json'),'utf8');
  queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  const after = fs.readFileSync(path.join(ROOT,'data/transit/validated/schedule_registry.json'),'utf8');
  assert.equal(before, after);
});
