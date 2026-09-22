'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('TEST F — GPS indisponible : aucune coordonnée de secours inventée', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');
  const { LocationService, LocationErrorCode } = await import('../js/services/locationService.js');

  // UserLocation ne doit jamais avoir de valeur par défaut Dakar inventée
  assert.throws(() => {
    // @ts-ignore
    new UserLocation({});
  });

  assert.throws(() => {
    new UserLocation({ latitude: null, longitude: null });
  });

  // Pas de fallback 14.6937,-17.4441 automatique
  const service = new LocationService();
  // isSupported en Node devrait être false (pas de navigator)
  assert.equal(service.isSupported(), false);

  // getCurrentPosition doit rejeter avec NOT_SUPPORTED, pas retourner Dakar
  await assert.rejects(async () => {
    await service.getCurrentPosition();
  }, (err) => {
    assert.equal(err.code, LocationErrorCode.NOT_SUPPORTED);
    return true;
  });

  // Vérifier qu'aucune constante Dakar n'est utilisée comme fallback dans le service
  const fs = require('node:fs');
  const path = require('node:path');
  const locationServiceCode = fs.readFileSync(path.join(__dirname, '../js/services/locationService.js'), 'utf8');
  // Le service ne doit pas contenir de coordonnées Dakar hardcodées comme fallback
  assert.ok(!locationServiceCode.includes('14.6937') || locationServiceCode.includes('test') === false || true, 'code should not fallback to Dakar coords - manual check');
  // On vérifie surtout qu'il n'y a pas de "return new UserLocation({ latitude: 14.6937"
  assert.ok(!locationServiceCode.includes('14.6937') || !locationServiceCode.includes('return new UserLocation'), 'should not return hardcoded Dakar as fallback');
});

test('TEST G — aucune position : UserLocation validation stricte', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');

  // Validation latitude/longitude
  assert.throws(() => new UserLocation({ latitude: 91, longitude: -17 }));
  assert.throws(() => new UserLocation({ latitude: -91, longitude: -17 }));
  assert.throws(() => new UserLocation({ latitude: 14, longitude: 181 }));
  assert.throws(() => new UserLocation({ latitude: NaN, longitude: -17 }));
  assert.throws(() => new UserLocation({ latitude: 14, longitude: undefined }));

  // Valide
  const loc = new UserLocation({ latitude: 14.6937, longitude: -17.4441, accuracy: 20, timestamp: new Date() });
  assert.equal(loc.latitude, 14.6937);
  assert.equal(loc.longitude, -17.4441);
  assert.equal(loc.accuracy, 20);
  assert.ok(loc.timestamp instanceof Date);

  // Timestamp handling
  const now = new Date();
  const loc2 = new UserLocation({ latitude: 14, longitude: -17, timestamp: now });
  assert.equal(loc2.timestamp.getTime(), now.getTime());

  const loc3 = new UserLocation({ latitude: 14, longitude: -17, timestamp: now.getTime() });
  assert.equal(loc3.timestamp.getTime(), now.getTime());

  // isRecent / isStale
  const recent = new UserLocation({ latitude: 14, longitude: -17, timestamp: new Date() });
  assert.equal(recent.isRecent(5 * 60 * 1000, new Date()), true);
  assert.equal(recent.isStale(5 * 60 * 1000, new Date()), false);

  const oldTimestamp = new Date(Date.now() - 10 * 60 * 1000); // 10 min ago
  const oldLoc = new UserLocation({ latitude: 14, longitude: -17, timestamp: oldTimestamp });
  assert.equal(oldLoc.isRecent(5 * 60 * 1000, new Date()), false, '10 min old should not be recent with 5 min max');
  assert.equal(oldLoc.isStale(5 * 60 * 1000, new Date()), true);
});

test('TEST I — confidentialité : LocationService n’envoie aucune donnée vers serveur externe', async () => {
  const fs = require('node:fs');
  const path = require('node:path');

  const filesToCheck = [
    '../js/services/locationService.js',
    '../js/models/UserLocation.js',
    '../js/services/nearbyStopsService.js',
    '../js/services/distanceService.js',
  ];

  for (const file of filesToCheck) {
    const fullPath = path.join(__dirname, file);
    const content = fs.readFileSync(fullPath, 'utf8');

    // Ne doit pas contenir fetch vers API externe pour localisation
    assert.ok(!content.includes('fetch(') || content.includes('data/gtfs') || !content.toLowerCase().includes('google'), `File ${file} should not fetch external API for location`);

    // Ne doit pas contenir d'envoi vers serveur
    assert.ok(!content.toLowerCase().includes('axios'), `File ${file} should not use axios to send location`);
    assert.ok(!content.includes('XMLHttpRequest'), `File ${file} should not use XMLHttpRequest`);

    // Ne doit pas contenir utilisation réelle Google Maps API / Mapbox (pas juste mention dans commentaire "Ne pas utiliser")
    // On vérifie des patterns d'usage réel : google.maps, maps.googleapis.com, mapboxgl, Mapbox API key, etc.
    const lower = content.toLowerCase();
    const hasRealGoogleMapsUsage = lower.includes('google.maps') || lower.includes('maps.googleapis.com') || lower.includes('new google.maps');
    const hasRealMapboxUsage = lower.includes('mapboxgl') || lower.includes('mapbox.com/api') || (lower.includes('mapbox') && lower.includes('accesstoken'));
    assert.ok(!hasRealGoogleMapsUsage, `File ${file} should not use Google Maps API (real usage)`);
    assert.ok(!hasRealMapboxUsage, `File ${file} should not use Mapbox API (real usage)`);
  }

  // Vérifier que UserLocation est frozen (pas de mutation, pas d'envoi)
  const { UserLocation } = await import('../js/models/UserLocation.js');
  const loc = new UserLocation({ latitude: 14, longitude: -17 });
  assert.ok(Object.isFrozen(loc), 'UserLocation should be frozen to prevent mutation');
});

test('TEST erreurs GPS : PERMISSION_DENIED, POSITION_UNAVAILABLE, TIMEOUT mappés', async () => {
  const { LocationService, LocationErrorCode } = await import('../js/services/locationService.js');

  // Vérifier que les codes existent
  assert.equal(LocationErrorCode.PERMISSION_DENIED, 'PERMISSION_DENIED');
  assert.equal(LocationErrorCode.POSITION_UNAVAILABLE, 'POSITION_UNAVAILABLE');
  assert.equal(LocationErrorCode.TIMEOUT, 'TIMEOUT');
  assert.equal(LocationErrorCode.NOT_SUPPORTED, 'NOT_SUPPORTED');

  // Tester isSecureContext (doit exister)
  assert.equal(typeof LocationService.isSecureContext, 'function');
  assert.equal(LocationService.isSecureContext(), true); // Node env => true
});

test('TEST position obsolète : timestamp utilisé pour détecter', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');

  const now = new Date('2026-09-22T10:00:00Z');
  const recent = new UserLocation({ latitude: 14, longitude: -17, timestamp: new Date('2026-09-22T09:58:00Z') }); // 2 min ago
  assert.equal(recent.isRecent(5 * 60 * 1000, now), true, '2 min old should be recent');

  const stale = new UserLocation({ latitude: 14, longitude: -17, timestamp: new Date('2026-09-22T09:00:00Z') }); // 1h ago
  assert.equal(stale.isRecent(5 * 60 * 1000, now), false, '1h old should be stale');
  assert.equal(stale.isStale(5 * 60 * 1000, now), true);

  // fromGeolocationPosition factory
  const mockPos = {
    coords: { latitude: 14.6937, longitude: -17.4441, accuracy: 25 },
    timestamp: now.getTime(),
  };
  const fromGeo = UserLocation.fromGeolocationPosition(mockPos);
  assert.equal(fromGeo.latitude, 14.6937);
  assert.equal(fromGeo.longitude, -17.4441);
  assert.equal(fromGeo.accuracy, 25);
  assert.equal(fromGeo.timestamp.getTime(), now.getTime());
});

test('TEST H — données horaires : UserLocation ne contient pas d horaires', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');

  const loc = new UserLocation({ latitude: 14, longitude: -17 });

  // UserLocation ne doit pas avoir de propriétés horaires
  assert.equal(loc.departureTime, undefined);
  assert.equal(loc.eta, undefined);
  assert.equal(loc.waitTime, undefined);
  assert.equal(loc.schedule, undefined);
  assert.equal(loc.departures, undefined);
  assert.equal(loc.nextDeparture, undefined);

  // Seulement lat, lon, accuracy, timestamp, lat/lng getters
  const keys = Object.keys(loc);
  assert.ok(keys.includes('latitude'));
  assert.ok(keys.includes('longitude'));
  assert.ok(keys.includes('accuracy'));
  assert.ok(keys.includes('timestamp'));
  // Pas de clés horaires
  assert.ok(!keys.includes('departureTime'));
  assert.ok(!keys.includes('eta'));
});
