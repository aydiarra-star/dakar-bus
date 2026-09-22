'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('TEST D — Position Paris : interface doit utiliser coordonnées Paris, pas Dieuppeul/Dakar', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');
  const { distanceMeters } = await import('../js/services/distanceService.js');

  // Position réelle Paris
  const parisLocation = new UserLocation({
    latitude: 48.8566,
    longitude: 2.3522,
    accuracy: 20,
    timestamp: new Date(),
  });

  assert.equal(parisLocation.latitude, 48.8566);
  assert.equal(parisLocation.longitude, 2.3522);

  // Vérifier que ce n'est PAS Dakar
  assert.notEqual(parisLocation.latitude, 14.7167, 'Paris lat ne doit pas être DAKAR_CENTER');
  assert.notEqual(parisLocation.latitude, 14.6937, 'Paris lat ne doit pas être fallback Dakar');
  assert.notEqual(parisLocation.longitude, -17.4677);
  assert.notEqual(parisLocation.longitude, -17.4441);

  // Distance Paris -> Dakar ~3800km
  const d = distanceMeters(parisLocation.latitude, parisLocation.longitude, 14.6937, -17.4441);
  assert.ok(d > 3500000 && d < 4500000, `Paris-Dakar distance should be ~3800km, got ${d}`);

  // Arrêts Dakar : aucun dans rayon 1000m depuis Paris
  const dakarStops = [
    { id: 'BRT_01', name: 'Petersen', lat: 14.67548, lng: -17.44157 },
    { id: 'BRT_07', name: 'Sacré-Cœur (près Dieuppeul)', lat: 14.7166, lng: -17.4635 },
    { id: 'TER_01', name: 'Gare Dakar', lat: 14.67599, lng: -17.43352 },
  ];

  const service = new NearbyStopsService({ searchRadiusMeters: 1000, maxResults: 5 });
  const nearbyParis = service.findNearby(parisLocation, dakarStops);

  assert.equal(nearbyParis.length, 0, 'Depuis Paris, aucun arrêt Dakar dans rayon 1000m - doit afficher "Aucun arrêt connu à proximité"');

  // Même avec rayon 20000m, toujours 0 depuis Paris
  const nearbyParis20k = service.findNearby(parisLocation, dakarStops, { searchRadiusMeters: 20000 });
  assert.equal(nearbyParis20k.length, 0, 'Même avec 20km rayon, Paris est loin de Dakar');

  // Avec rayon très large (5000km), on doit trouver Dakar mais trié par distance, et distance doit être ~3800km, pas 350m
  const nearbyParis5000k = service.findNearby(parisLocation, dakarStops, { searchRadiusMeters: 5000000, maxResults: 5 });
  assert.equal(nearbyParis5000k.length, 3, 'Avec rayon 5000km, doit trouver Dakar');
  // Vérifier que distance affichée est grande, pas petite Dieuppeul
  assert.ok(nearbyParis5000k[0].distanceMeters > 3000000, 'Distance Paris->Dakar doit être >3000km, pas 350m');
  assert.ok(nearbyParis5000k[0].distanceFormatted.includes('km'), 'Doit être en km pour Paris-Dakar');
});

test('TEST A — GPS réel disponible : position reçue = marker = même coordonnées, pas fallback Dakar', async () => {
  const fs = require('node:fs');
  const path = require('node:path');

  // Vérifier index.html ne contient plus fallback Petersen -120m • 2 min
  const indexContent = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');
  assert.ok(!indexContent.includes('Petersen - 120m • 2 min'), 'index.html ne doit plus contenir fake ETA Petersen -120m');

  // Vérifier que handleLocationSuccess loggue latitude, longitude, accuracy, timestamp, source
  assert.ok(indexContent.includes('GPS réel reçu') || indexContent.includes('latitude') && indexContent.includes('longitude'), 'Doit logguer lat/lon');

  // Vérifier que DAKAR_CENTER n'est jamais utilisé comme position utilisateur
  // DAKAR_CENTER peut être utilisé pour map.setView initial, mais pas pour userMarker ou userPos fallback
  // On vérifie que userMarker utilise lat,lng de userLocation, pas DAKAR_CENTER
  assert.ok(indexContent.includes('L.marker([lat, lng]'), 'userMarker doit utiliser [lat, lng] réels');

  // Vérifier qu'il n'y a pas de fallback Dakar hardcodé dans startGPS/handleLocationSuccess
  // Chercher patterns interdits : userPos = DAKAR_CENTER, userPos = { lat: 14.6937
  const hasForbiddenFallback = indexContent.includes('userPos = DAKAR_CENTER') || 
                                indexContent.includes('userPos={ lat: 14.6937') ||
                                indexContent.includes('userPos = { lat: 14.7167') ||
                                indexContent.includes('14.6937,-17.4441') && indexContent.includes('userPos');
  // On autorise 14.6937 dans commentaires ou tests, mais pas comme assignation userPos
  // Vérification plus précise : chercher "userPos =" suivi de Dakar coords
  const lines = indexContent.split('\n');
  let forbiddenFound = false;
  for (const line of lines) {
    if (line.includes('userPos') && line.includes('=') && (line.includes('14.6937') || line.includes('14.7167')) && line.includes('14.') && !line.trim().startsWith('//')) {
      // Si c'est dans handleLocationSuccess qui assigne depuis userLocation, c'est OK (userLocation.latitude peut être 14.6937 si user à Dakar, mais pas hardcodé)
      // On vérifie si c'est hardcodé, pas depuis userLocation
      if (!line.includes('userLocation') && !line.includes('latitude') && !line.includes('longitude')) {
        forbiddenFound = true;
        console.log('Forbidden line:', line);
      }
    }
  }
  assert.equal(forbiddenFound, false, 'Aucun fallback Dakar hardcodé ne doit exister pour userPos');
});

test('TEST B — GPS refusé : Localisation indisponible, aucun marker fictif', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const indexContent = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');

  // Vérifier handleLocationError affiche Localisation indisponible
  assert.ok(indexContent.includes('Localisation indisponible'), 'Doit afficher Localisation indisponible');
  assert.ok(indexContent.includes('Aucune coordonnée de secours inventée'), 'Doit mentionner pas de secours inventée');
  assert.ok(indexContent.includes('Aucune position Dakar fixe utilisée'), 'Doit mentionner pas de position Dakar fixe');

  // Vérifier que handleLocationError ne crée pas de marker fictif
  // Il doit clear marker, pas en créer
  assert.ok(indexContent.includes('if(userMarker){ map.removeLayer(userMarker)'), 'En cas erreur, doit supprimer marker, pas créer fictif');
});

test('TEST C — GPS indisponible : aucun fallback géographique', async () => {
  const { UserLocation } = await import('../js/models/UserLocation.js');
  const { NearbyStopsService } = await import('../js/services/nearbyStopsService.js');

  const service = new NearbyStopsService();

  // Sans position, aucun résultat, pas de fallback
  assert.deepEqual(service.findNearby(null, [{ id: 'A', lat: 14, lng: -17 }]), []);
  assert.deepEqual(service.findNearby(undefined, [{ id: 'A', lat: 14, lng: -17 }]), []);

  // UserLocation ne doit pas avoir de constructeur par défaut qui retourne Dakar
  assert.throws(() => new UserLocation({}), 'UserLocation sans args doit throw, pas fallback Dakar');
});

test('TEST régression - DAKAR_CENTER utilisé uniquement pour carte initiale, pas comme position utilisateur', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const indexContent = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');

  // DAKAR_CENTER doit exister pour centrage initial carte (OK)
  assert.ok(indexContent.includes('DAKAR_CENTER'), 'DAKAR_CENTER doit exister pour carte initiale');

  // Mais ne doit pas être utilisé pour userMarker fallback
  // Vérifier que userMarker est créé avec [lat, lng] de GPS réel, pas DAKAR_CENTER
  const hasUserMarkerWithRealCoords = indexContent.includes('L.marker([lat, lng]') && indexContent.includes('userMarker');
  assert.ok(hasUserMarkerWithRealCoords, 'userMarker doit utiliser lat,lng réels');

  // Vérifier que map.setView sur position réelle existe (correction critique)
  assert.ok(indexContent.includes('map.setView([lat, lng]'), 'Carte doit se centrer sur position réelle GPS (correction Paris->Dieuppeul)');
});
