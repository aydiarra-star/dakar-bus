'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('TEST A — distance : deux coordonnées connues produisent une distance cohérente', async () => {
  const { distanceMeters } = await import('../js/services/distanceService.js');

  // Dakar centre approximatif vs Petersen (BRT_01)
  // 14.7167,-17.4677 vs 14.67548,-17.44157
  const d = distanceMeters(14.7167, -17.4677, 14.67548, -17.44157);
  assert.ok(typeof d === 'number' && d > 0, 'distance should be positive number');
  // Distance attendue ~5.3 km (calcul Haversine)
  // On vérifie ordre grandeur 4-7 km
  assert.ok(d > 4000 && d < 7000, `distance Dakar centre -> Petersen devrait être ~5km, got ${d}`);

  // Même point très proche : 2 stations BRT voisines ~300-500m
  const d2 = distanceMeters(14.67548, -17.44157, 14.67822, -17.44219);
  assert.ok(d2 > 200 && d2 < 800, `distance BRT 01->02 devrait être ~300m, got ${d2}`);

  // Distance Paris Dakar très grande ~3800 km
  const dParisDakar = distanceMeters(48.8566, 2.3522, 14.6937, -17.4441);
  assert.ok(dParisDakar > 3500000 && dParisDakar < 4500000, `Paris-Dakar ~3800km, got ${dParisDakar}`);
});

test('TEST B — même position : distance ≈ 0', async () => {
  const { distanceMeters } = await import('../js/services/distanceService.js');

  const d = distanceMeters(14.6937, -17.4441, 14.6937, -17.4441);
  assert.equal(d, 0);

  const d2 = distanceMeters(0, 0, 0, 0);
  assert.equal(d2, 0);
});

test('TEST B2 — formatDistance lisible', async () => {
  const { formatDistance } = await import('../js/services/distanceService.js');

  assert.equal(formatDistance(0), '0 m');
  assert.equal(formatDistance(5), '5 m');
  assert.equal(formatDistance(120), '120 m');
  // 347,238 → 350 m (arrondi dizaine)
  assert.equal(formatDistance(347.238), '350 m');
  assert.equal(formatDistance(349), '350 m');
  // <100 m précis
  assert.equal(formatDistance(99), '99 m');
  // 100-999 arrondi dizaine
  assert.equal(formatDistance(100), '100 m');
  assert.equal(formatDistance(105), '110 m');
  // >=1000 → km avec virgule
  assert.equal(formatDistance(1000), '1,0 km');
  assert.equal(formatDistance(800), '800 m');
  assert.equal(formatDistance(1200), '1,2 km');
  assert.equal(formatDistance(8000), '8,0 km');
  assert.equal(formatDistance(850), '850 m');
  // 0,8 km
  const formatted = formatDistance(800);
  assert.ok(formatted.includes('m'), 'should contain m');

  const formattedKm = formatDistance(1200);
  assert.ok(formattedKm.includes('km'), 'should contain km');
  assert.ok(formattedKm.includes(','), 'French comma decimal expected for km');

  assert.equal(formatDistance(null), 'Distance inconnue');
  assert.equal(formatDistance(NaN), 'Distance inconnue');
});

test('TEST E — coordonnées invalides : distance null', async () => {
  const { distanceMeters, isValidCoordinate } = await import('../js/services/distanceService.js');

  assert.equal(isValidCoordinate(null, -17), false);
  assert.equal(isValidCoordinate(14, null), false);
  assert.equal(isValidCoordinate(NaN, -17), false);
  assert.equal(isValidCoordinate(91, -17), false); // lat >90
  assert.equal(isValidCoordinate(14, 181), false); // lon >180

  assert.equal(distanceMeters(null, -17, 14, -17), null);
  assert.equal(distanceMeters(14, -17, null, -17), null);
  assert.equal(distanceMeters(91, 0, 0, 0), null);
  assert.equal(distanceMeters(14, -17, 14, 200), null);
});
