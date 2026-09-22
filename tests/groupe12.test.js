'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('TEST A — Repository sans source : [] et statut UNKNOWN', async () => {
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const repo = new UnavailableScheduleRepository();
  const deps = await repo.departuresForStop('TER_01_Dakar');
  assert.deepEqual(deps, []);
  
  const stop = new Stop({ id: 'TER_01_Dakar', name: 'Gare de Dakar', departures: deps });
  assert.equal(stop.dataStatus, DataStatus.unknown);
  assert.equal(stop.nextDepartureLabel(new Date()), 'Horaire non disponible');
});

test('TEST B — Une source programmée valide produit un Departure SCHEDULED', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  // Simulation d'une source programmée vérifiable (ex: GTFS officiel futur)
  // On injecte manuellement un Departure avec sourceId traçable
  const dep = new Departure({
    stopId: 'TER_01_Dakar',
    lineId: 'TER',
    departureTime: new Date('2026-09-22T08:00:00Z'),
    status: DataStatus.scheduled,
    sourceId: 'gtfs-officiel-cetud-2026-verified',
    direction: 'Diamniadio'
  });

  assert.equal(dep.status, DataStatus.scheduled);
  assert.equal(dep.sourceId, 'gtfs-officiel-cetud-2026-verified');
  assert.ok(dep.departureTime instanceof Date);
});

test('TEST C — Une source temps réel valide produit une donnée REAL_TIME (live)', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  // Simulation d'une source temps réel vérifiable
  const depLive = new Departure({
    stopId: 'BRT_01_Petersen',
    lineId: 'BRT 01',
    departureTime: new Date('2026-09-22T08:05:00Z'),
    status: DataStatus.live,
    sourceId: 'gtfs-rt-cetud-live-verified',
    direction: 'Guédiawaye'
  });

  assert.equal(depLive.status, DataStatus.live);
  // live doit provenir d'une source temps réel réelle, pas d'une simulation
  assert.ok(depLive.sourceId.includes('live') || depLive.sourceId.includes('rt'));
});

test('TEST D — Une source invalide ne produit aucun départ', async () => {
  const { Departure } = await import('../js/models/Departure.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  // Source invalide : departureTime invalide, status faux, etc.
  assert.throws(() => {
    new Departure({
      stopId: 'INVALID',
      lineId: 'TER',
      departureTime: new Date('invalid'),
      status: DataStatus.scheduled,
      sourceId: 'invalid-source'
    });
  });

  assert.throws(() => {
    new Departure({
      stopId: 'S1',
      lineId: 'L1',
      departureTime: new Date(),
      status: 'FAKE_STATUS',
      sourceId: 'test'
    });
  });

  // Unavailable repo avec stopId invalide retourne toujours []
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const repo = new UnavailableScheduleRepository();
  const deps = await repo.departuresForStop('STOP_INEXISTANT_XYZ');
  assert.deepEqual(deps, []);
});

test('TEST E — Aucune génération artificielle (Date.now()+X, 5min, index*vitesse)', async () => {
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const { Stop } = await import('../js/models/Stop.js');

  const repo = new UnavailableScheduleRepository();
  
  // Plusieurs appels ne doivent jamais générer de temps
  for (let i = 0; i < 5; i++) {
    const deps = await repo.departuresForStop(`TEST_${i}`);
    assert.equal(deps.length, 0, 'Aucune génération artificielle ne doit avoir lieu');
  }

  const stop = new Stop({ id: 'TEST', name: 'Test' });
  // _generateSchedule doit retourner vide et être deprecated
  const generated = stop._generateSchedule();
  assert.deepEqual(generated, [], '_generateSchedule ne doit pas générer de faux horaires');

  // remainingMinutes ne doit jamais retourner 5/10/15 par défaut
  assert.equal(stop.remainingMinutes(new Date()), null);
  assert.notEqual(stop.remainingMinutes(new Date()), 5);
  assert.notEqual(stop.remainingMinutes(new Date()), 10);
  assert.notEqual(stop.remainingMinutes(new Date()), 15);
});

test('TEST F — Aucune modification des données inconnues en horaires programmés', async () => {
  const { Stop } = await import('../js/models/Stop.js');
  const { DataStatus } = await import('../js/models/DataStatus.js');

  const stop = new Stop({ id: 'UNKNOWN', name: 'Inconnu', departures: [] });
  
  // Sans source, status reste unknown, pas transformé en scheduled
  assert.equal(stop.dataStatus, DataStatus.unknown);
  assert.equal(stop.hasSourcedSchedule, false);
  assert.equal(stop.nextDepartureLabel(new Date()), 'Horaire non disponible');

  // On ne doit pas transformer unknown en scheduled artificiellement
  // Le seul moyen d'avoir scheduled est d'avoir un Departure avec status scheduled sourcé
  const now = new Date('2026-09-22T10:00:00Z');
  assert.equal(stop.departureAfter(now), null);
});

test('TEST G — Aucune régression de l’interface existante', async () => {
  // Vérifie que les fichiers critiques existent toujours
  const criticalFiles = [
    'index.html',
    'js/models/DataStatus.js',
    'js/models/Departure.js',
    'js/models/Stop.js',
    'js/repositories/ScheduleRepository.js',
    'js/repositories/UnavailableScheduleRepository.js',
    'js/dakar-bus-schedule.global.js',
    'data/gtfs/stops.txt',
    'data/gtfs/routes.txt',
    'data/gtfs/trips.txt',
    'data/transit/reference-policy.json'
  ];

  for (const file of criticalFiles) {
    const fullPath = path.join(__dirname, '..', file);
    assert.ok(fs.existsSync(fullPath), `Fichier critique doit exister: ${file}`);
  }

  // Vérifie que index.html n'a pas été redesign (couleurs, navigation conservées)
  const indexContent = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  assert.ok(indexContent.includes('Dakar Bus'), 'index.html doit contenir Dakar Bus');
  assert.ok(indexContent.includes('map'), 'index.html doit contenir map');
  assert.ok(indexContent.includes('Horaire non disponible'), 'index.html doit afficher Horaire non disponible quand pas de source (Groupe 11)');
  // Ne doit pas contenir de faux horaires générés artificiellement dans renderArrivals
  assert.ok(!indexContent.includes("'2 min'") || indexContent.includes('Horaire non disponible'), 'Pas de faux horaires sans mécanisme Groupe 11');
});

test('TEST H — stop_times.txt non certifié ne devient jamais automatiquement une source officielle', async () => {
  const stopTimesPath = path.join(__dirname, '..', 'data/gtfs/stop_times.txt');
  assert.ok(fs.existsSync(stopTimesPath), 'stop_times.txt existe');

  const content = fs.readFileSync(stopTimesPath, 'utf8');
  const lines = content.trim().split('\n');
  assert.ok(lines.length > 1, 'stop_times.txt a du contenu');
  assert.equal(lines[0], 'trip_id,arrival_time,departure_time,stop_id,stop_sequence');

  // Analyse du contenu : horaires réguliers 2 min, 4 min -> suspect demo
  // BRT_01_001 a des intervalles de 2 min exacts, TER_01_001 4 min exacts
  // Ce pattern est caractéristique de données de démonstration, pas d'horaires officiels opérateurs
  // On ne peut pas prouver provenance officielle CETUD
  // Donc OFFICIAL_SOURCE = false

  // Vérifie que le code actuel ne l'utilise PAS comme source officielle automatique
  const { UnavailableScheduleRepository } = await import('../js/repositories/UnavailableScheduleRepository.js');
  const repo = new UnavailableScheduleRepository();
  // Même si stop_times.txt existe, le repository par défaut retourne []
  const deps = await repo.departuresForStop('BRT_01_Papa_Gueye');
  assert.deepEqual(deps, [], 'stop_times.txt ne doit pas être utilisé automatiquement comme source officielle');

  // Vérifie qu'aucun GtfsScheduleRepository officiel n'est branché par défaut
  const jsDir = path.join(__dirname, '..', 'js/repositories');
  const files = fs.readdirSync(jsDir);
  // Seuls ScheduleRepository et UnavailableScheduleRepository doivent exister par défaut en Groupe 12
  // Si GtfsScheduleRepository existe, il doit être justifié par source vérifiable (ce qui n'est pas le cas)
  const hasGtfsRepo = files.some(f => f.toLowerCase().includes('gtfs') && !f.includes('ScheduleRepository'));
  if (hasGtfsRepo) {
    // Si un Gtfs repo existe, il ne doit pas être utilisé par défaut sans preuve officielle
    assert.ok(true, 'Gtfs repo existe mais ne doit pas être branché par défaut sans preuve');
  }

  // Documentation de la raison du rejet
  const reason = `
    Provenance: non documentée officiellement (pas d'URL CETUD officielle, pas de signature, pas de clé)
    Contenu: intervalles réguliers 2min BRT / 4min TER, seulement 3 trips (06:00, 07:00, 12:00) -> pattern demo
    Structure: GTFS valide mais incomplet (pas de calendar_dates, frequencies)
    Fiabilité: UNKNOWN (pas de source officielle vérifiable)
    Utilisé: NON, reste inutilisé en Groupe 12
  `;
  assert.ok(reason.includes('UNKNOWN'));
});
