'use strict';
// Chantier « Recherche + GPS + Routage » — tests Node du moteur d'accès au
// réseau (miroir de flutter-src/lib/services/gtfs/network_access.dart).
//
// Vérifie, à partir des feeds réellement présents :
//   * position → plusieurs arrêts réels candidats (jamais un seul) ;
//   * position → plusieurs mobilités disponibles ;
//   * position → itinéraire réel (Parcelles Assainies → Keur Mbaye Fall) ;
//   * intégrité : une simple proximité ne crée JAMAIS une correspondance.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const { loadAll, planJourneys, splitComposite, AT } = require('./helpers/passbi-engine419.mjs');
const { nativeStops, searchNativeStops, NETWORK_KEYS } = require('./helpers/passbi-native421.mjs');

const ROOT = resolve(__dirname, '..');
const ref = JSON.parse(
  readFileSync(resolve(ROOT, 'data/reference/ddd_aftu_poles_terminus.json'), 'utf8'),
);

const all = loadAll();

// Miroir de NetworkAccess (bornes documentées).
const RADIUS = 2500;
const MAX_PER_NETWORK = 5;
const MAX_POINTS = 15;

function haversineMeters(lat1, lon1, lat2, lon2) {
  const r = 6371008.8;
  const p1 = (lat1 * Math.PI) / 180;
  const p2 = (lat2 * Math.PI) / 180;
  const dp = ((lat2 - lat1) * Math.PI) / 180;
  const dl = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dp / 2) ** 2 + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(Math.min(1, a)));
}

function accessPointsNear(lat, lon) {
  const selected = [];
  for (const key of NETWORK_KEYS) {
    const per = [];
    for (const s of nativeStops(all, key)) {
      const d = haversineMeters(lat, lon, s.lat, s.lon);
      if (d > RADIUS) continue;
      per.push({ ...s, distanceMeters: d });
    }
    per.sort((a, b) => a.distanceMeters - b.distanceMeters);
    selected.push(...per.slice(0, MAX_PER_NETWORK));
  }
  selected.sort((a, b) => a.distanceMeters - b.distanceMeters);
  return selected.slice(0, MAX_POINTS);
}

// Parcelles Assainies / Keur Mbaye Fall (coordonnées de service, cf. tests Dart).
const PARCELLES = { lat: 14.76269, lon: -17.42431 };
const KEUR_MBAYE_FALL = { lat: 14.74408, lon: -17.31389 };

test('GPS — la position retourne un ENSEMBLE d\'arrêts réels, multi-réseaux', () => {
  const pts = accessPointsNear(PARCELLES.lat, PARCELLES.lon);
  assert.ok(pts.length > 1, 'plusieurs arrêts candidats attendus');
  // Aucun doublon.
  assert.equal(new Set(pts.map((p) => p.compositeKey)).size, pts.length);
  // Tri par distance croissante.
  for (let i = 1; i < pts.length; i++) {
    assert.ok(pts[i].distanceMeters >= pts[i - 1].distanceMeters);
  }
  // Chaque point est un arrêt RÉEL du feed (jamais fabriqué).
  for (const p of pts) {
    const ids = new Set(nativeStops(all, p.network).map((s) => s.stopId));
    assert.ok(ids.has(p.stopId), `arrêt ${p.stopId} absent du feed ${p.network}`);
  }
  // Plusieurs mobilités disponibles.
  const mob = new Set(pts.map((p) => p.network));
  assert.ok(mob.has('DDD') && mob.has('AFTU') && mob.has('BRT'),
    `mobilités attendues DDD/AFTU/BRT, obtenu ${[...mob].join(',')}`);
});

test('GPS — destination : points de sortie réels autour de Keur Mbaye Fall', () => {
  const exits = accessPointsNear(KEUR_MBAYE_FALL.lat, KEUR_MBAYE_FALL.lon);
  assert.ok(exits.length > 0);
  const mob = new Set(exits.map((p) => p.network));
  assert.ok(mob.has('TER'), 'la gare TER de Keur Mbaye Fall doit être candidate');
  assert.ok(mob.has('AFTU'));
});

test('GPS — Parcelles Assainies → Keur Mbaye Fall : itinéraires réels comparés', () => {
  const fromKeys = new Set(accessPointsNear(PARCELLES.lat, PARCELLES.lon).map((p) => p.compositeKey));
  const toKeys = new Set(accessPointsNear(KEUR_MBAYE_FALL.lat, KEUR_MBAYE_FALL.lon).map((p) => p.compositeKey));
  const journeys = planJourneys(all, fromKeys, toKeys, AT(2026, 9, 28, 8, 0), { maxResults: 4 });
  assert.ok(journeys.length >= 2, 'plusieurs itinéraires candidats attendus');
  for (const j of journeys) {
    assert.ok(j.legs.length >= 1);
    // Chaque tronçon provient d'une route réelle du feed.
    for (const leg of j.legs) {
      const net = all.networks[leg.network];
      assert.ok(net._routeById.has(leg.routeId), `route ${leg.routeId} inconnue`);
    }
  }
  // Les itinéraires sont triés par heure d'arrivée.
  for (let i = 1; i < journeys.length; i++) {
    assert.ok(journeys[i].arrivalSec >= journeys[i - 1].arrivalSec);
  }
});

test('GPS — un point hors réseau ne renvoie aucun arrêt (aucune invention)', () => {
  assert.equal(accessPointsNear(14.0, -18.5).length, 0);
});

test('Intégrité — la proximité ne crée pas de correspondance à pied', () => {
  // Deux arrêts à moins de 200 m sans lien de transfert documenté.
  const ddd = searchNativeStops(all, 'Westerne Cbao Parcelles', { networks: ['DDD'] })[0];
  const aftu = searchNativeStops(all, 'Lpa', { networks: ['AFTU'] })[0];
  assert.ok(ddd && aftu, 'les deux arrêts de référence doivent exister');
  const meters = haversineMeters(ddd.lat, ddd.lon, aftu.lat, aftu.lon);
  assert.ok(meters < 200, `arrêts attendus proches, obtenu ${meters} m`);

  const journeys = planJourneys(
    all,
    new Set([ddd.compositeKey]),
    new Set([aftu.compositeKey]),
    AT(2026, 9, 28, 8, 0),
    { maxResults: 4 },
  );
  // Un trajet d'un seul tronçon entre deux arrêts de RÉSEAUX différents est
  // impossible sans correspondance : il ne peut donc exister que si une ligne
  // dessert réellement les deux arrêts. Le moteur ne fabrique jamais une
  // correspondance à pied par simple proximité.
  for (const j of journeys) {
    assert.ok(j.legs.length >= 2,
      'une correspondance de proximité ne peut pas produire un trajet à un seul tronçon');
    for (const leg of j.legs) {
      const net = all.networks[leg.network];
      // Le tronçon provient d'un trip réel qui contient bien les deux arrêts.
      const ti = net.trips.findIndex((t) => t[0] === leg.tripId);
      assert.ok(ti >= 0, 'trip réel attendu');
      const seq = net._byTrip.get(ti).map((st) => net.stops[st[1]][0]);
      assert.ok(seq.includes(splitComposite(leg.fromStopId)[1]));
      assert.ok(seq.includes(splitComposite(leg.toStopId)[1]));
    }
  }
});

test('Intégrité — un lien de transfert DOCUMENTÉ reste exploitable', () => {
  // BRT PARCELLES ↔ DDD LycéE Parcelles Assainies : transfert documenté (21 m).
  const journeys = planJourneys(
    all,
    new Set(['BRT:0:PARB']),
    new Set(['DDD:D_1032']),
    AT(2026, 9, 28, 8, 0),
    { maxResults: 4 },
  );
  assert.ok(journeys.length > 0, 'le transfert documenté doit être exploité');
  for (const j of journeys) {
    const parts = splitComposite(j.destinationKey);
    assert.ok(parts);
  }
});

test('Recherche — le référentiel est construit depuis les feeds (pas préchargé)', () => {
  let stops = 0;
  let routes = 0;
  for (const key of NETWORK_KEYS) {
    stops += nativeStops(all, key).length;
    routes += all.networks[key].routes.length;
  }
  assert.ok(stops > 1000, `arrêts indexés attendus > 1000, obtenu ${stops}`);
  assert.ok(routes > 100, `lignes indexées attendues > 100, obtenu ${routes}`);
  assert.ok(ref.poles.length > 0, 'pôles/terminus documentés attendus');
});

test('Recherche — mobilité, ligne, arrêt, terminus, destination retrouvables', () => {
  // Mobilité : nom du réseau.
  assert.ok(NETWORK_KEYS.includes('AFTU'));
  // Ligne : libellé réel du feed.
  const line = all.networks.AFTU.routes.find((r) => r.id.startsWith('AFTU_37'));
  assert.ok(line, 'ligne AFTU_37 attendue dans le feed');
  // Arrêt : nom réel du feed.
  assert.ok(searchNativeStops(all, 'Keur Mbaye Fall', { limit: 1 }).length > 0);
  // Terminus / destination documentés.
  const named = ref.poles.filter((p) => p.isTerminal !== undefined || Array.isArray(p.roles));
  assert.ok(named.length > 0);
});
