'use strict';
// Chantier DDD / AFTU / TATA — tests du référentiel pôles & terminus.
//
// Vérifie que le référentiel GÉNÉRÉ est complet, sourcé, et qu'aucune
// association pôle→ligne n'est produite par simple proximité. Aucune donnée
// TER/BRT, aucun horaire, aucun routage n'est touché.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const ROOT = resolve(__dirname, '..');
const ref = JSON.parse(
  readFileSync(resolve(ROOT, 'data/reference/ddd_aftu_poles_terminus.json'), 'utf8'),
);

test('DDD : 53 lignes, 52 terminus A et B confirmés, 1 UNKNOWN motivé', () => {
  assert.equal(ref.ddd.totalRoutes, 53);
  assert.equal(ref.ddd.terminusAConfirmed, 52);
  assert.equal(ref.ddd.terminusBConfirmed, 52);
  assert.deepEqual(ref.ddd.unknownRoutes, ['DDD_323']);
  const unknown = ref.ddd.routes.find((r) => r.routeId === 'DDD_323');
  assert.equal(unknown.status, 'UNKNOWN');
  assert.equal(unknown.note, 'AUCUN_STOP_TIME_DANS_LE_FEED');
  assert.equal(unknown.terminus.length, 0);
});

test('AFTU : 73 lignes, 71 terminus A et B confirmés, 2 UNKNOWN motivés', () => {
  assert.equal(ref.aftu.totalRoutes, 73);
  assert.equal(ref.aftu.terminusAConfirmed, 71);
  assert.equal(ref.aftu.terminusBConfirmed, 71);
  assert.deepEqual(ref.aftu.unknownRoutes, ['AFTU_47', 'AFTU_52']);
  for (const id of ref.aftu.unknownRoutes) {
    const r = ref.aftu.routes.find((x) => x.routeId === id);
    assert.equal(r.status, 'UNKNOWN');
    assert.equal(r.note, 'AUCUN_STOP_TIME_DANS_LE_FEED');
  }
});

test('DDD 16 : le sens retour du feed contredit le libellé officiel (Palais 1)', () => {
  const r = ref.ddd.routes.find((x) => x.routeId === 'DDD_16');
  assert.equal(r.status, 'CONFLICTING');
  assert.equal(r.label, 'MALIKA ↔ PALAIS 1');
  // Le feed ne dessert jamais Palais 1 pour cette route : contradiction conservée.
  const names = r.directions.flatMap((d) => [d.depart?.stopName, d.arrivee?.stopName]);
  assert.ok(!names.some((n) => n && /palais 1/i.test(n)));
  assert.ok(names.some((n) => n && /palais 2/i.test(n)));
});

test('chaque route non-UNKNOWN expose un terminus départ ET arrivée', () => {
  for (const net of ['ddd', 'aftu']) {
    for (const r of ref[net].routes) {
      if (r.status === 'UNKNOWN') continue;
      assert.ok(r.directions.some((d) => d.depart), `${r.routeId} départ`);
      assert.ok(r.directions.some((d) => d.arrivee), `${r.routeId} arrivée`);
    }
  }
});

test('les 16 pôles du périmètre §3–§5 existent avec coordonnées Dakar', () => {
  const required = ['petersen', 'pem_guediawaye', 'grand_medine', 'colobane',
    'baux_maraichers', 'diamniadio', 'parcelles_assainies', 'keur_massar',
    'pikine', 'thiaroye', 'rufisque', 'sandaga', 'yoff', 'ouakam', 'ngor', 'mermoz'];
  for (const id of required) {
    const p = ref.poles.find((x) => x.id === id);
    assert.ok(p, `pôle manquant : ${id}`);
    assert.ok(p.coordinates.lat >= 14.55 && p.coordinates.lat <= 14.9, id);
    assert.ok(p.coordinates.lon >= -17.6 && p.coordinates.lon <= -16.85, id);
    assert.notEqual(p.coordinatesStatus, 'REJECTED_OUT_OF_BOUNDS', id);
  }
});

test('aucun terminus n\'est rattaché à un pôle par simple proximité', () => {
  assert.deepEqual(ref.integrity.poleRouteAssociationsByProximityOnly, []);
  assert.deepEqual(ref.integrity.terminiWithoutSource, []);
  assert.deepEqual(ref.integrity.linesWithSingleTerminus, []);
});

test('une ligne en transit n\'est jamais listée comme terminus d\'un pôle', () => {
  for (const p of ref.poles) {
    const transit = new Set([...p.dddTransitRoutes, ...p.aftuTransitRoutes]);
    for (const r of transit) {
      assert.ok(!p.dddRoutes.includes(r) && !p.aftuRoutes.includes(r),
        `${p.id} : ${r} ne fait que transiter`);
    }
  }
});

test('Grand Médine / Pikine / Mermoz / Sandaga : pas de terminus DDD-AFTU inventé', () => {
  for (const id of ['grand_medine', 'pikine', 'mermoz', 'sandaga']) {
    const p = ref.poles.find((x) => x.id === id);
    assert.equal(p.isTerminal, false, id);
    assert.deepEqual(p.dddRoutes, [], id);
    assert.deepEqual(p.aftuRoutes, [], id);
    assert.deepEqual(p.terminalStops, [], id);
  }
  // …mais une desserte en transit réelle est bien enregistrée pour trois d'entre eux.
  for (const id of ['grand_medine', 'pikine', 'mermoz']) {
    const p = ref.poles.find((x) => x.id === id);
    assert.ok(p.dddTransitRoutes.length + p.aftuTransitRoutes.length > 0, id);
  }
});

test('TATA : aucune association confirmée ni inventée', () => {
  assert.equal(ref.tata.vehicleType, 'TATA');
  assert.deepEqual(ref.tata.confirmedAssociations, []);
  assert.deepEqual(ref.tata.unconfirmedAssociations, []);
});

test('les pôles découverts (hors périmètre) sont inclus et terminaux', () => {
  const discovered = ref.poles.filter((p) => p.discovered);
  assert.ok(discovered.length > 0, 'liste §3–§5 non limitative (§6)');
  for (const p of discovered) assert.equal(p.isTerminal, true, p.id);
});
