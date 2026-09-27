'use strict';
/**
 * Lot 4.9 — Tests d'affichage minimal Trajets.
 *
 * Vérifie la couche UI (logique d'affichage) sans toucher GPS/Explorer :
 * - le widget consomme uniquement DepartureInfo (pas de DateTime.now pour fabriquer une heure)
 * - SCHEDULED / PARTIALLY_CONFIRMED : countdown et "Départ maintenant"
 * - ESTIMATED : fréquence uniquement
 * - UNKNOWN : "Horaire indisponible"
 * - fin de service : pas de 22:25
 * - pas de 0 min approximatif, pas de fréquence→heure
 * Tests passent par integration.queryDeparture (moteur réel) + helper UI miroir de main.dart
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { ScheduleEngine } = require('../data/transit/engine/schedule_engine');
const { ServiceDate, ServiceTime } = require('../data/transit/engine/gtfs_time');
const { queryDeparture, createEngineFromRegistry } = require('../data/transit/engine/integration');

const ROOT = path.join(__dirname, '..');
const REG = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/transit/validated/schedule_registry.json'), 'utf8'));

function utc(s){ return new Date(s); }

// Helper UI miroir de main.dart _departureLabelForSegment (sans DateTime.now)
function uiLabel(contract){
  // contract = toContract result (status, scheduledTime, nextDepartureAt, frequencyMinutes, minutesUntil, displayLabel)
  if (!contract) return 'Horaire indisponible';
  switch(contract.status){
    case 'SCHEDULED':
    case 'REAL_TIME':
    case 'PARTIALLY_CONFIRMED':
      // Moteur fournit minutesUntil/displayLabel ; l'UI ne recalcule pas
      if (contract.minutesUntil === 0) return '🟢 Départ maintenant';
      if (contract.minutesUntil != null) return `🟢 Départ dans ${contract.minutesUntil} min`;
      if (contract.scheduledTime) return `🟢 ${contract.scheduledTime.slice(0,5)}`;
      return 'Horaire indisponible';
    case 'ESTIMATED':
      if (contract.frequencyMinutes == null) return 'Horaire indisponible';
      return `🟡 Passage estimé toutes les ${contract.frequencyMinutes} min`;
    case 'UNKNOWN':
    case 'NO_DEPARTURE':
    default:
      return 'Horaire indisponible';
  }
}

// 1. SCHEDULED avec countdown (synthétique 08:17→08:20)
test('Lot4.9 SCHEDULED countdown 08:17→08:20 = 3 min', () => {
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'ui_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'08:20:00', departure_time:'08:20:00', schedule_status:'SCHEDULED', valid_from:'20260928', valid_to:'20260928' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260928', end_date:'20260928', exceptions:[] }],
  });
  const r = engine.nextDeparture({ routeId:'ui_route', stopId:'S1', serviceDate:'2026-09-28', now: utc('2026-09-28T08:17:00Z') });
  assert.equal(r.status, 'SCHEDULED');
  assert.equal(r.minutesUntil, 3);
  // UI helper
  const c = { status:'SCHEDULED', minutesUntil:3, scheduledTime:'08:20:00' };
  assert.equal(uiLabel(c), '🟢 Départ dans 3 min');
});

// 2. SCHEDULED maintenant
test('Lot4.9 SCHEDULED maintenant 08:20 → Départ maintenant', () => {
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'ui_route', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'08:20:00', departure_time:'08:20:00', schedule_status:'SCHEDULED', valid_from:'20260928', valid_to:'20260928' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260928', end_date:'20260928', exceptions:[] }],
  });
  const r = engine.nextDeparture({ routeId:'ui_route', stopId:'S1', serviceDate:'2026-09-28', now: utc('2026-09-28T08:20:00Z') });
  assert.equal(r.status, 'SCHEDULED');
  assert.equal(r.minutesUntil, 0);
  const c = { status:'SCHEDULED', minutesUntil:0, scheduledTime:'08:20:00' };
  assert.equal(uiLabel(c), '🟢 Départ maintenant');
  assert.notEqual(uiLabel(c), '🟢 Départ dans 0 min');
});

// 3. PARTIALLY_CONFIRMED TER 08:17→08:25 (8 min) — le moteur démontre 08:25 donc UI = 8 min
test('Lot4.9 PARTIALLY_CONFIRMED TER 08:17 → 08:25 = 8 min', () => {
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'PARTIALLY_CONFIRMED');
  assert.equal(c.scheduledTime, '08:25:00');
  assert.equal(c.minutesUntil, 8);
  assert.equal(uiLabel(c), '🟢 Départ dans 8 min');
});

// 4. ESTIMATED BRT B1 6 min
test('Lot4.9 ESTIMATED BRT B1 → Passage estimé 6 min (scheduledTime null)', () => {
  const c = queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  assert.equal(uiLabel(c), '🟡 Passage estimé toutes les 6 min');
});

// 5. ESTIMATED BRT B2 6 min
test('Lot4.9 ESTIMATED BRT B2 → Passage estimé 6 min', () => {
  const c = queryDeparture({ routeId:'brt_b2', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 6);
  assert.equal(uiLabel(c), '🟡 Passage estimé toutes les 6 min');
});

// 6. UNKNOWN BRT B3
test('Lot4.9 UNKNOWN BRT B3 → Horaire indisponible', () => {
  const c = queryDeparture({ routeId:'brt_b3', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(uiLabel(c), 'Horaire indisponible');
});

// 7. UNKNOWN DDD ddd_1
test('Lot4.9 UNKNOWN DDD ddd_1 → Horaire indisponible', () => {
  const c = queryDeparture({ routeId:'ddd_1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(uiLabel(c), 'Horaire indisponible');
});

// 8. UNKNOWN AFTU aftu_1
test('Lot4.9 UNKNOWN AFTU aftu_1 → Horaire indisponible', () => {
  const c = queryDeparture({ routeId:'aftu_1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.equal(uiLabel(c), 'Horaire indisponible');
});

// 9. aucun faux 0 min
test('Lot4.9 aucun faux 0 min : UNKNOWN jamais Départ dans 0 min', () => {
  const c = queryDeparture({ routeId:'unknown_route', stopId:'unknown_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.equal(c.status, 'UNKNOWN');
  assert.notEqual(uiLabel(c), '🟢 Départ dans 0 min');
  assert.notEqual(uiLabel(c), '🟢 Départ maintenant');
  assert.equal(c.minutesUntil, null);
});

// 10. aucun faux horaire issu d'une fréquence
test('Lot4.9 ESTIMATED jamais 08:00/08:06', () => {
  const c = queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:00:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.scheduledTime, null);
  assert.equal(c.nextDepartureAt, null);
  // Pas de 08:00/08:06 généré
  assert.ok(!c.scheduledTime);
  assert.equal(uiLabel(c), '🟡 Passage estimé toutes les 6 min');
  assert.ok(!uiLabel(c).includes('08:00'));
});

// 11. dernier départ 22:10 → pas 22:25
test('Lot4.9 fin de service TER 22:10 → ESTIMATED 20 pas 22:25', () => {
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T22:10:00Z') });
  assert.equal(c.status, 'ESTIMATED');
  assert.equal(c.frequencyMinutes, 20);
  assert.equal(c.scheduledTime, null);
  assert.notEqual(c.scheduledTime, '22:25:00');
  assert.equal(uiLabel(c), '🟡 Passage estimé toutes les 20 min');
});

// 12. absence de REAL_TIME prod
test('Lot4.9 REAL_TIME prod = 0 (aucun DepartureInfo prod en REAL_TIME)', () => {
  assert.equal(REG.stats.realtime_entries, 0);
  const c = queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_dakar_ter', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') });
  assert.notEqual(c.status, 'REAL_TIME');
  assert.equal(uiLabel(c).includes('temps réel'), false);
});

// 13. vérification UI n'affiche jamais une heure inventée depuis fréquence
test('Lot4.9 UI respecte scheduledTime null pour ESTIMATED', () => {
  const list = [
    queryDeparture({ routeId:'brt_b1', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') }),
    queryDeparture({ routeId:'brt_b2', stopId:'any_stop', serviceDate:'2026-09-27', now: utc('2026-09-27T08:17:00Z') }),
    queryDeparture({ routeId:'ter_dakar_diamniadio', stopId:'stop_colobane', serviceDate:'2026-09-27', now: utc('2026-09-27T06:20:00Z') }),
  ];
  for(const c of list){
    assert.equal(c.status, 'ESTIMATED');
    assert.equal(c.scheduledTime, null);
    assert.equal(c.nextDepartureAt, null);
    assert.ok(uiLabel(c).startsWith('🟡 Passage estimé'));
  }
});

// 14. countdown moteur non approximé : 08:17→08:20 via synthétique reste 3 min exact
test('Lot4.9 countdown exact non approximé (synthétique 08:20)', () => {
  const engine = new ScheduleEngine({
    stopTimes: [{ route_id:'ui_route2', service_id:'S', trip_id:'T1', stop_id:'S1', stop_sequence:1, arrival_time:'08:20:00', departure_time:'08:20:00', schedule_status:'SCHEDULED', valid_from:'20260928', valid_to:'20260928' }],
    services: [{ service_id:'S', monday:1,tuesday:1,wednesday:1,thursday:1,friday:1,saturday:1,sunday:1, start_date:'20260928', end_date:'20260928', exceptions:[] }],
  });
  const r = engine.nextDeparture({ routeId:'ui_route2', stopId:'S1', serviceDate:'2026-09-28', now: utc('2026-09-28T08:17:00Z') });
  assert.equal(r.minutesUntil, 3);
  assert.equal(r.secondsUntil, 180);
});
