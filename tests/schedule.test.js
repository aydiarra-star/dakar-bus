'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

// Import ES modules via dynamic import workaround for CommonJS test runner
// We'll use require for built files via creating CJS versions or using import()

// Since our implementation is ESM, we need to create a CJS compatible test harness
// We'll directly test logic by importing via import() in async tests

test('Test A — Aucun repository réel : aucune source → aucun départ → unknown / indisponible', async () => {
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const repo = new UnavailableScheduleRepository();
  const departures = await repo.departuresForStop('TER_01_Dakar');
  assert.deepEqual(departures, [], 'Unavailable repository must return empty list');

  const stop = new Stop({ id: 'TER_01_Dakar', name: 'Gare de Dakar', departures });
  assert.equal(stop.hasSourcedSchedule, false);
  assert.equal(stop.dataStatus, DataStatus.unknown);
  assert.equal(stop.nextDepartureLabel(new Date('2026-09-22T10:00:00Z')), 'Horaire non disponible');
  assert.equal(stop.remainingMinutes(new Date('2026-09-22T10:00:00Z')), null);
  assert.equal(stop.departureAfter(new Date('2026-09-22T10:00:00Z')), null);
});

test('Test B — Départ scheduled réel injecté par le test', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const fixedNow = new Date('2026-09-22T13:00:00Z');
  const departureTime = new Date('2026-09-22T14:20:00Z');

  const dep = new Departure({
    stopId: 'TER_01_Dakar',
    lineId: 'TER',
    departureTime,
    status: DataStatus.scheduled,
    direction: 'Diamniadio',
    sourceId: 'test-gtfs-2026'
  });

  assert.equal(dep.status, DataStatus.scheduled);
  assert.equal(dep.stopId, 'TER_01_Dakar');

  const stop = new Stop({ id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: [dep] });
  assert.equal(stop.hasSourcedSchedule, true);

  const next = stop.departureAfter(fixedNow);
  assert.ok(next, 'should have next departure');
  assert.equal(next.departureTime.getTime(), departureTime.getTime());
  assert.equal(next.status, DataStatus.scheduled);

  // Label should be real time, not "Horaire non disponible"
  const label = stop.nextDepartureLabel(fixedNow);
  // Should contain "14 h 20" in local time, but our Date is UTC, getHours uses local TZ.
  // Use UTC-based check: we format with getHours, so we check that label is not unavailable and contains "h"
  assert.notEqual(label, 'Horaire non disponible');
  assert.ok(label.includes('h'), `label should contain h, got ${label}`);

  // remainingMinutes should be 80
  const remaining = stop.remainingMinutes(fixedNow);
  assert.equal(remaining, 80);
});

test('Test C — Départ live réel injecté par le test', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const fixedNow = new Date('2026-09-22T10:00:00Z');
  const departureTime = new Date('2026-09-22T10:05:00Z');

  const dep = new Departure({
    stopId: 'BRT_01_Petersen',
    lineId: 'BRT 01',
    departureTime,
    status: DataStatus.live,
    direction: 'Guédiawaye',
    sourceId: 'test-realtime-cetud'
  });

  const stop = new Stop({ id: 'BRT_01_Petersen', name: 'Petersen', departures: [dep] });

  const next = stop.departureAfter(fixedNow);
  assert.ok(next);
  assert.equal(next.status, DataStatus.live);
  assert.equal(next.departureTime.getTime(), departureTime.getTime());

  assert.equal(stop.remainingMinutes(fixedNow), 5);
  assert.notEqual(stop.nextDepartureLabel(fixedNow), 'Horaire non disponible');
});

test('Test D — Départ passé ne doit pas être retourné comme prochain départ', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const now = new Date('2026-09-22T15:00:00Z');
  const past = new Date('2026-09-22T14:00:00Z');

  const dep = new Departure({
    stopId: 'TER_01_Dakar',
    lineId: 'TER',
    departureTime: past,
    status: DataStatus.scheduled,
    sourceId: 'test'
  });

  const stop = new Stop({ id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: [dep] });

  assert.equal(stop.departureAfter(now), null);
  assert.equal(stop.remainingMinutes(now), null);
  assert.equal(stop.nextDepartureLabel(now), 'Horaire non disponible');
});

test('Test E — Plusieurs départs : 13:00, 13:30, 14:00', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const d1 = new Departure({ stopId: 'S1', lineId: 'TER', departureTime: new Date('2026-09-22T13:00:00Z'), status: DataStatus.scheduled, sourceId: 'test' });
  const d2 = new Departure({ stopId: 'S1', lineId: 'TER', departureTime: new Date('2026-09-22T13:30:00Z'), status: DataStatus.scheduled, sourceId: 'test' });
  const d3 = new Departure({ stopId: 'S1', lineId: 'TER', departureTime: new Date('2026-09-22T14:00:00Z'), status: DataStatus.scheduled, sourceId: 'test' });

  const stop = new Stop({ id: 'S1', name: 'Test', departures: [d1, d2, d3] });

  // Avant 13:00 -> 13:00
  let now = new Date('2026-09-22T12:50:00Z');
  let next = stop.departureAfter(now);
  assert.equal(next.departureTime.toISOString(), '2026-09-22T13:00:00.000Z');

  // Entre 13:00 et 13:30 -> 13:30
  now = new Date('2026-09-22T13:15:00Z');
  next = stop.departureAfter(now);
  assert.equal(next.departureTime.toISOString(), '2026-09-22T13:30:00.000Z');

  // Entre 13:30 et 14:00 -> 14:00
  now = new Date('2026-09-22T13:45:00Z');
  next = stop.departureAfter(now);
  assert.equal(next.departureTime.toISOString(), '2026-09-22T14:00:00.000Z');

  // Après 14:00 -> null
  now = new Date('2026-09-22T14:10:00Z');
  next = stop.departureAfter(now);
  assert.equal(next, null);
});

test('Test F — Aucun départ : null et Horaire non disponible', async () => {
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const stop = new Stop({ id: 'EMPTY', name: 'Vide', departures: [] });
  const now = new Date('2026-09-22T10:00:00Z');

  assert.equal(stop.departureAfter(now), null);
  assert.equal(stop.remainingMinutes(now), null);
  assert.equal(stop.nextDepartureLabel(now), 'Horaire non disponible');
  assert.equal(stop.hasSourcedSchedule, false);
  assert.equal(stop.dataStatus, DataStatus.unknown);
});

test('Test G — Pas de génération automatique : prouver qu\'aucun horaire n\'est créé sans source', async () => {
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const { Stop } = await import('../js/models/Stop.js');

  const repo = new UnavailableScheduleRepository();

  // Simuler plusieurs appels
  const ids = ['TER_01_Dakar', 'BRT_01_Petersen', 'UNKNOWN_STOP'];
  for (const id of ids) {
    const deps = await repo.departuresForStop(id);
    assert.deepEqual(deps, [], `Repository should return empty for ${id}, not generate`);
    assert.equal(deps.length, 0);

    const stop = new Stop({ id, name: id, departures: deps });
    assert.equal(stop.hasSourcedSchedule, false);
    assert.equal(stop.departures.length, 0);
  }

  // Vérifier que Stop sans departures ne génère rien en interne
  const emptyStop = new Stop({ id: 'TEST', name: 'Test' });
  assert.equal(emptyStop.departures.length, 0);
  assert.equal(emptyStop._generateSchedule().length, 0, '_generateSchedule should return empty (deprecated)');
});

test('Test non-régression — DataStatus et DataTrust distincts', async () => {
  const { DataStatus } = await import('../js/models/DataStatus.js');
  const { DataTrust } = await import('../js/models/DataTrust.js');

  // DataStatus
  assert.equal(DataStatus.scheduled, 'scheduled');
  assert.equal(DataStatus.live, 'live');
  assert.equal(DataStatus.unknown, 'unknown');

  // DataTrust différent conceptuellement, même si string 'unknown' peut coïncider
  assert.equal(DataTrust.verified, 'verified');
  assert.notEqual(DataStatus.scheduled, DataTrust.verified);
  // Les deux enums sont des objets différents, pas fusionnés
  assert.notDeepEqual(DataStatus, DataTrust);
  // DataTrust décrit confiance, DataStatus disponibilité temporelle
  assert.ok(DataStatus.scheduled);
  assert.ok(DataTrust.verified);
  // Vérifie que les clés sont distinctes
  assert.ok(Object.keys(DataStatus).includes('scheduled'));
  assert.ok(Object.keys(DataTrust).includes('verified'));
});

test('Test Departure immutability et validation', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const dep = new Departure({
    stopId: 'S1',
    lineId: 'L1',
    departureTime: new Date('2026-09-22T12:00:00Z'),
    status: DataStatus.scheduled,
  });

  // Immutable
  assert.ok(Object.isFrozen(dep));

  // Invalid should throw
  assert.throws(() => {
    new Departure({ stopId: '', lineId: 'L1', departureTime: new Date(), status: DataStatus.scheduled });
  });

  assert.throws(() => {
    new Departure({ stopId: 'S1', lineId: 'L1', departureTime: new Date('invalid'), status: DataStatus.scheduled });
  });

  assert.throws(() => {
    new Departure({ stopId: 'S1', lineId: 'L1', departureTime: new Date(), status: 'fake' });
  });
});

test('Test service functions avec temps contrôlable', async () => {
  const { departureAfter, remainingMinutes, nextDepartureLabel, getDataStatus } = await import('../js/services/scheduleService.js');
  const { Departure } = await import('../js/models/Departure.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const now = new Date('2026-09-22T08:00:00Z');
  const deps = [
    new Departure({ stopId: 'S1', lineId: 'L1', departureTime: new Date('2026-09-22T09:00:00Z'), status: DataStatus.scheduled, sourceId: 'test' }),
    new Departure({ stopId: 'S1', lineId: 'L1', departureTime: new Date('2026-09-22T10:00:00Z'), status: DataStatus.live, sourceId: 'test' }),
  ];

  const next = departureAfter(deps, now);
  assert.equal(next.departureTime.toISOString(), '2026-09-22T09:00:00.000Z');
  assert.equal(remainingMinutes(deps, now), 60);
  assert.notEqual(nextDepartureLabel(deps, now), 'Horaire non disponible');
  assert.equal(getDataStatus(deps, now), DataStatus.scheduled);

  const afterFirst = new Date('2026-09-22T09:30:00Z');
  const next2 = departureAfter(deps, afterFirst);
  assert.equal(next2.status, DataStatus.live);
  assert.equal(getDataStatus(deps, afterFirst), DataStatus.live);
});
