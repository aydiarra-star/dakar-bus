'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('TEST C — tri : A=100m, B=500m, C=200m => A, C, B', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');
  const { distanceMeters } = await import('../js/services/distanceService.js');

  // Position utilisateur Dakar
  const userLocation = { latitude: 14.6937, longitude: -17.4441 };

  // Créer 3 arrêts à distances contrôlées en décalant lat légèrement
  // 0.0009° lat ≈ 100m
  const stops = [
    { id: 'B', name: 'B 500m', lat: 14.6937 + 0.0045, lng: -17.4441 }, // ~500m nord
    { id: 'A', name: 'A 100m', lat: 14.6937 + 0.0009, lng: -17.4441 }, // ~100m
    { id: 'C', name: 'C 200m', lat: 14.6937 + 0.0018, lng: -17.4441 }, // ~200m
  ];

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 10 });
  const nearby = service.findNearby(userLocation, stops);

  assert.equal(nearby.length, 3);
  assert.equal(nearby[0].stop.id, 'A', 'plus proche devrait être A');
  assert.equal(nearby[1].stop.id, 'C', 'deuxième devrait être C');
  assert.equal(nearby[2].stop.id, 'B', 'troisième devrait être B');

  // Vérifier tri par distanceMeters croissant
  assert.ok(nearby[0].distanceMeters < nearby[1].distanceMeters);
  assert.ok(nearby[1].distanceMeters < nearby[2].distanceMeters);

  // Vérifier format
  assert.ok(nearby[0].distanceFormatted.includes('m'));
});

test('TEST D — rayon : arrêt à 1500m non retourné avec rayon 1000m', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const userLocation = { latitude: 14.6937, longitude: -17.4441 };

  // ~1500m = 0.0135° lat
  const stops = [
    { id: 'FAR', name: 'Loin 1500m', lat: 14.6937 + 0.0135, lng: -17.4441 },
    { id: 'NEAR', name: 'Proche 500m', lat: 14.6937 + 0.0045, lng: -17.4441 },
  ];

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 10 });
  const nearby = service.findNearby(userLocation, stops);

  assert.equal(nearby.length, 1);
  assert.equal(nearby[0].stop.id, 'NEAR');

  // Avec rayon 2000m, les deux devraient être retournés
  const nearby2 = service.findNearby(userLocation, stops, { searchRadiusMeters: 2000 });
  assert.equal(nearby2.length, 2);
});

test('TEST E — coordonnées invalides : arrêt sans coordonnées ignoré', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const userLocation = { latitude: 14.6937, longitude: -17.4441 };

  const stops = [
    { id: 'VALID', name: 'Valide', lat: 14.6937 + 0.0009, lng: -17.4441 },
    { id: 'NO_COORDS', name: 'Sans coords' }, // pas de lat/lng
    { id: 'NULL_COORDS', name: 'Null', lat: null, lng: null },
    { id: 'INVALID_LAT', name: 'Invalid lat', lat: 91, lng: -17.4441 }, // lat invalide
    { id: 'INVALID_LON', name: 'Invalid lon', lat: 14.6937, lng: 200 },
  ];

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 10 });
  const nearby = service.findNearby(userLocation, stops);

  assert.equal(nearby.length, 1);
  assert.equal(nearby[0].stop.id, 'VALID');
});

test('TEST G — aucune position : service ne retourne pas faux emplacement', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const stops = [
    { id: 'A', name: 'A', lat: 14.6937, lng: -17.4441 },
  ];

  const service = new NearbyStopsService();

  assert.deepEqual(service.findNearby(null, stops), [], 'null position => []');
  assert.deepEqual(service.findNearby(undefined, stops), [], 'undefined => []');
  assert.deepEqual(service.findNearby({}, stops), [], 'empty object => []');
  assert.deepEqual(service.findNearby({ latitude: null, longitude: null }, stops), [], 'null coords => []');
  assert.deepEqual(service.findNearby({ lat: 91, lng: 0 }, stops), [], 'invalid lat => []');
});

test('TEST H — données horaires : GPS ne transforme jamais UNKNOWN en SCHEDULED/REAL_TIME', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const userLocation = { latitude: 14.6937, longitude: -17.4441 };

  // Stop sans départs = UNKNOWN
  const stop = new Stop({ id: 'TER_01_Dakar', name: 'Gare de Dakar', lat: 14.67599, lng: -17.43352, departures: [] });
  assert.equal(stop.dataStatus, DataStatus.unknown);
  assert.equal(stop.hasSourcedSchedule, false);
  assert.equal(stop.nextDepartureLabel(new Date()), 'Horaire non disponible');

  const service = new NearbyStopsService({ searchRadiusMeters: 5000, maxResults: 5 });
  const nearby = service.findNearby(userLocation, [stop]);

  // Même proche, le stop reste UNKNOWN
  assert.equal(nearby.length, 1);
  const foundStop = nearby[0].stop;
  // Si c'est un Stop model, vérifier status reste UNKNOWN
  if (foundStop instanceof Stop) {
    assert.equal(foundStop.dataStatus, DataStatus.unknown);
    assert.equal(foundStop.nextDepartureLabel(new Date()), 'Horaire non disponible');
  } else {
    // Si c'est un objet brut, on vérifie via Stop wrapper
    const wrapped = new Stop({ id: foundStop.id, name: foundStop.name, lat: foundStop.lat, lng: foundStop.lng, departures: [] });
    assert.equal(wrapped.dataStatus, DataStatus.unknown);
  }

  // Distance affichée OK, mais horaire toujours non disponible
  assert.ok(nearby[0].distanceFormatted);
  assert.notEqual(nearby[0].distanceFormatted, 'Horaire non disponible');
});

test('TEST nombre résultats configurable et rayon configurable', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const userLocation = { latitude: 14.6937, longitude: -17.4441 };
  const stops = [];
  for (let i = 0; i < 10; i++) {
    stops.push({ id: `S${i}`, name: `Stop ${i}`, lat: 14.6937 + (i + 1) * 0.0009, lng: -17.4441 });
  }

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 5 });
  const nearby5 = service.findNearby(userLocation, stops);
  assert.equal(nearby5.length, 5, 'par défaut 5 résultats');

  const nearby3 = service.findNearby(userLocation, stops, { maxResults: 3 });
  assert.equal(nearby3.length, 3, 'configurable 3 résultats');

  const nearby10 = service.findNearby(userLocation, stops, { maxResults: 10, searchRadiusMeters: 5000 });
  assert.equal(nearby10.length, 10, '10 résultats si max 10 et rayon large');
});

test('TEST aucun arrêt dans rayon => message approprié (liste vide)', async () => {
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const userLocation = { latitude: 0, longitude: 0 }; // milieu océan, loin Dakar
  const stops = [
    { id: 'DAKAR', name: 'Dakar', lat: 14.6937, lng: -17.4441 },
  ];

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 5 });
  const nearby = service.findNearby(userLocation, stops);

  assert.equal(nearby.length, 0, 'aucun arrêt dans rayon 1000m depuis 0,0');
  // L'UI doit afficher "Aucun arrêt connu à proximité" quand liste vide
});
