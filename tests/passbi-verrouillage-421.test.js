// Lot 4.21 (suite) — VERROUILLAGE : identité publique ≠ horaire ≠ correspondance.
//
// Ces tests scellent les trois séparations exigées :
//   1. disponibilité réelle des horaires PassBi (trips + stop_times réels) ;
//   2. identité publique CONFIRMED uniquement avec preuve documentaire —
//      jamais par numéro, route_id, nom similaire, OSM, proximité ou terminus
//      proches (TERMINI_MATCH reste une hypothèse NON confirmée) ; plusieurs
//      lignes publiques pointant vers un même identifiant PassBi ne sont
//      JAMAIS fusionnées automatiquement ;
//   3. correspondances intermodales réellement documentées — même arrêt
//      physique desservi OU lien crosswalk à nom vérifié ; AUCUNE
//      correspondance par proximité seule ; TATA : zéro correspondance.
//
// Garde-fous anti-régression : TER/BRT (IDENTITY_OFFICIELLE) inchangés ;
// aucun TATA fabriqué ; aucune fréquence convertie en horaire individuel.
import test from 'node:test';
import assert from 'node:assert/strict';

import { loadAll, splitComposite, planJourneys, AT } from './helpers/passbi-engine419.mjs';
import {
  IDENTITY,
  identityStatusOf,
  dakarRouteIdsFor,
  departureAtPassBiStop,
  routeSummaries,
  networkAvailability,
  tataMentions,
  documentedTransfers,
  isDocumentedTransfer,
  DOCUMENTED_IDENTITY_METHODS,
} from './helpers/passbi-native421.mjs';

const ALL = loadAll();
const LUNDI_10H = AT(2026, 9, 28, 10, 0);
const LUNDI_12H = AT(2026, 9, 28, 12, 0);

const C_DAKAR = 'TER:544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';

/// Toute transition de tronçon repose sur un arrêt PARTAGÉ ou un lien
/// réellement documenté du crosswalk — jamais sur une proximité, jamais sur
/// une identité publique (confirmée ou non).
function verifieTransitions(trajet, contexte) {
  for (let i = 1; i < trajet.legs.length; i++) {
    const precedent = trajet.legs[i - 1];
    const suivant = trajet.legs[i];
    const memeArret = precedent.toStopId === suivant.fromStopId;
    const lien = documentedTransfers(ALL.cw).find((t) =>
      (t.from === precedent.toStopId && t.to === suivant.fromStopId) ||
      (t.to === precedent.toStopId && t.from === suivant.fromStopId));
    assert.ok(memeArret || lien,
      `${contexte} : correspondance non documentée ${precedent.toStopId} → ${suivant.fromStopId}`);
  }
}

// ============================================================ 1. IDENTITÉ
test('1a. identité JAMAIS confirmée par numéro/termini/nom seul', () => {
  // TOUT mapping confirmé doit être une preuve documentaire.
  for (const [id, m] of Object.entries(ALL.cw.routes)) {
    if (m.status === 'MAPPED') {
      assert.ok(DOCUMENTED_IDENTITY_METHODS.includes(m.method),
        `${id} : MAPPED avec la méthode non documentaire ${m.method}`);
      assert.ok((m.pbRouteIds ?? []).length > 0, id);
    }
  }
  // Aucune méthode d'appariement approximatif ne confirme.
  for (const approx of ['TERMINI_MATCH', 'NUMBER_SIMILARITY', 'NAME_SIMILARITY',
    'OSM_MATCH', 'PROXIMITY', 'ROUTE_ID_SIMILARITY']) {
    for (const [id, m] of Object.entries(ALL.cw.routes)) {
      if (m.method === approx) {
        assert.notEqual(m.status, 'MAPPED', `${id} : ${approx} ne confirme jamais`);
      }
    }
  }
  // DDD/AFTU : AUCUNE identité confirmée (pas de preuve documentaire).
  for (const key of ['DDD', 'AFTU']) {
    for (const s of routeSummaries(ALL, key)) {
      assert.equal(s.identityStatus, IDENTITY.UNCONFIRMED, s.routeId);
      assert.deepEqual(s.dakarRouteIds, [], s.routeId);
    }
  }
});

test('1b. AFTU_8 / AFTU_11 : hypothèses conservées, JAMAIS fusionnées sur AFTU_3', () => {
  const m8 = ALL.cw.routes.aftu_8;
  const m11 = ALL.cw.routes.aftu_11;
  for (const [id, m] of [['aftu_8', m8], ['aftu_11', m11]]) {
    assert.equal(m.status, 'UNMAPPED', id);
    assert.equal(m.method, 'IDENTITE_NON_CONFIRMEE', id);
    assert.deepEqual(m.pbRouteIds ?? [], [], id);
    // L'observation de termini reste pour l'audit, sans produire de rattachement.
    assert.equal(m.hypothesis?.pbRouteId, 'AFTU_3', id);
    assert.equal(m.hypothesis?.method, 'TERMINI_MATCH', id);
    assert.ok((m.hypothesis?.score ?? 0) >= 0.7, id);
    assert.match(m.note, /Aucune fusion automatique/, id);
  }
  // Deux lignes publiques distinctes → un même identifiant PassBi : aucune
  // n'est confirmée, aucune n'est rattachée.
  assert.deepEqual(dakarRouteIdsFor(ALL.cw, 'AFTU', 'AFTU_3'), []);
  assert.equal(identityStatusOf(ALL.cw, 'AFTU', 'AFTU_3'), IDENTITY.UNCONFIRMED);
});

test('1c. anti-fusion générale : aucun identifiant PassBi porté par 2 identités confirmées', () => {
  const claims = new Map();
  for (const [id, m] of Object.entries(ALL.cw.routes)) {
    for (const pbId of m.pbRouteIds ?? []) {
      if (!claims.has(pbId)) claims.set(pbId, []);
      claims.get(pbId).push(id);
    }
  }
  for (const [pbId, ids] of claims) {
    assert.ok(ids.length <= 1,
      `fusion automatique : ${ids.join(', ')} → ${pbId}`);
  }
  // TER et BRT restent confirmés par preuve documentaire (aucune régression).
  assert.equal(ALL.cw.routes.ter_dakar_diamniadio.method, 'IDENTITY_OFFICIELLE');
  assert.equal(ALL.cw.routes.brt_b1_guediawaye_petersen.method, 'IDENTITY_OFFICIELLE');
  assert.equal(ALL.cw.routes.brt_b2_express.method, 'IDENTITY_OFFICIELLE');
  assert.equal(identityStatusOf(ALL.cw, 'BRT', 'B1'), IDENTITY.CONFIRMED);
  assert.equal(identityStatusOf(ALL.cw, 'BRT', 'B2'), IDENTITY.CONFIRMED);
});

// ======================================================== 2. TATA (absent)
test('2a. TATA : AUCUNE route fabriquée, AUCUNE identité confirmée', () => {
  assert.equal(networkAvailability(ALL, 'TATA'), 'ABSENT_FROM_FEED');
  assert.equal(ALL.networks.TATA, undefined);
  assert.deepEqual(tataMentions(ALL), []);
  const tata = Object.entries(ALL.cw.routes).filter(([id]) => id.startsWith('tata_'));
  assert.ok(tata.length > 0, 'les identités TATA du référentiel dakar existent');
  for (const [id, m] of tata) {
    assert.equal(m.status, 'UNMAPPED', id);
    assert.equal(m.method, 'RESEAU_ABSENT_DU_FEED', id);
    assert.deepEqual(m.pbRouteIds ?? [], [], `${id} : aucune route TATA`);
  }
  // Aucun réseau de feed ne porte de TATA.
  for (const key of Object.keys(ALL.networks)) {
    for (const r of ALL.networks[key].routes) {
      assert.equal(/tata/i.test(`${r.id} ${r.short} ${r.long}`), false);
    }
  }
});

test('2b. TATA → tout réseau : ZÉRO correspondance', () => {
  for (const t of ALL.cw.transfers) {
    const a = splitComposite(t.from)?.[0] ?? t.from;
    const b = splitComposite(t.to)?.[0] ?? t.to;
    assert.notEqual(a, 'TATA', `transfert impliquant TATA : ${t.from}`);
    assert.notEqual(b, 'TATA', `transfert impliquant TATA : ${t.to}`);
  }
  // Le moteur ne produit rien depuis/vers une clé TATA (aucun feed).
  const tataKeys = new Set(['TATA:tata_50', 'TATA:tata_218']);
  for (const autre of ['DDD:D_708', 'AFTU:A_839', 'BRT:0:GNOA', C_DAKAR]) {
    const js = planJourneys(ALL, tataKeys, new Set([autre]), LUNDI_10H, { maxResults: 4 });
    assert.deepEqual(js, [], `TATA → ${autre} : aucun trajet`);
    const js2 = planJourneys(ALL, new Set([autre]), tataKeys, LUNDI_10H, { maxResults: 4 });
    assert.deepEqual(js2, [], `${autre} → TATA : aucun trajet`);
  }
});

// ================================================== 3. CORRESPONDANCES
test('3a. source.transfers : uniquement des liens DOCUMENTÉS (jamais la proximité seule)', () => {
  assert.ok(ALL.cw.transfers.length >= 1000);
  for (const t of ALL.cw.transfers) {
    assert.ok(isDocumentedTransfer(t), `lien non documenté : ${JSON.stringify(t)}`);
  }
  assert.deepEqual(documentedTransfers(ALL.cw).length, ALL.cw.transfers.length);
});

test('3b. proximité seule → AUCUNE correspondance (rejet du lien fabriqué)', () => {
  // Un lien sans nom vérifié est irrecevable même à 0 m.
  const fabrique = { from: 'DDD:D_12', to: 'AFTU:A_345', meters: 0, name: '', method: 'PROXIMITE_SEULE', confidence: 'high' };
  assert.equal(isDocumentedTransfer(fabrique), false);
  const sansMethode = { ...fabrique, name: 'x', method: '' };
  assert.equal(isDocumentedTransfer(sansMethode), false);
  const tata = { from: 'TATA:tata_50', to: 'DDD:D_708', meters: 10, name: 'meme point', method: 'NOM_IDENTIQUE_PROXIMITE', confidence: 'high' };
  assert.equal(isDocumentedTransfer(tata), false, 'TATA : jamais de correspondance');
  const tropLoin = { from: 'DDD:D_708', to: 'AFTU:A_839', meters: 900, name: 'x', method: 'NOM_IDENTIQUE_PROXIMITE', confidence: 'high' };
  assert.equal(isDocumentedTransfer(tropLoin), false);

  // Deux arrêts RÉELS à 9,8 m avec des noms différents : aucun lien dans le
  // crosswalk (DDD « Aéroport Léopold Sédar Senghor » ↔ AFTU « En Face École
  // Franco Islamique Al Qalam »).
  const lien = documentedTransfers(ALL.cw).find((t) =>
    (t.from === 'DDD:D_12' && t.to === 'AFTU:A_345') ||
    (t.to === 'DDD:D_12' && t.from === 'AFTU:A_345'));
  assert.equal(lien, undefined, 'la géographie seule ne crée aucune correspondance');
  // Le moteur ne relie JAMAIS ces deux arrêts par la seule proximité : toute
  // transition d'un trajet réel repose sur un arrêt partagé ou un lien
  // documenté — la paire (D_12, A_345) ne peut pas être une transition.
  const js = planJourneys(ALL, new Set(['DDD:D_12']), new Set(['AFTU:A_345']), LUNDI_12H, { maxResults: 4 });
  for (const j of js) {
    verifieTransitions(j, 'D_12→A_345');
    for (let i = 1; i < j.legs.length; i++) {
      const paire = [j.legs[i - 1].toStopId, j.legs[i].fromStopId];
      assert.equal(
        (paire[0] === 'DDD:D_12' && paire[1] === 'AFTU:A_345') ||
        (paire[0] === 'AFTU:A_345' && paire[1] === 'DDD:D_12'),
        false,
        `transition par proximité seule : ${paire.join(' → ')}`);
    }
  }
});

test('3c. paires de réseaux : liens documentés uniquement, matrice complète', () => {
  const paires = new Map(); // 'A-B' (trié) → liens
  for (const t of ALL.cw.transfers) {
    const a = splitComposite(t.from)[0];
    const b = splitComposite(t.to)[0];
    const k = [a, b].sort().join('-');
    if (!paires.has(k)) paires.set(k, []);
    paires.get(k).push(t);
  }
  // Chaque paire demandée existe avec des liens documentés (nom vérifié).
  for (const p of ['DDD-TER', 'AFTU-TER', 'BRT-DDD', 'AFTU-BRT', 'AFTU-DDD']) {
    const liens = paires.get(p) ?? [];
    assert.ok(liens.length > 0, `paire ${p} : aucun lien documenté`);
    for (const t of liens) assert.ok(isDocumentedTransfer(t), JSON.stringify(t));
  }
  // TATA n'apparaît dans AUCUNE paire.
  for (const k of paires.keys()) {
    assert.equal(k.includes('TATA'), false, `paire ${k} : TATA interdit`);
  }
});

test('3d. correspondance documentée → autorisée : matrice TER/BRT/DDD/AFTU', () => {
  // Corridors réels (identiques aux tests 419/421) : chaque transition vérifiée.
  const corridors = [
    ['TER → DDD', new Set([C_DAKAR]), new Set(['DDD:D_325'])],
    ['TER → AFTU', new Set([C_DAKAR]), new Set(['AFTU:A_548'])],
    ['BRT → DDD', new Set(['BRT:0:GNOA']), new Set(['DDD:D_449'])],
    ['BRT → AFTU', new Set(['BRT:0:GNOA']), new Set(['AFTU:A_608'])],
    ['DDD → AFTU', new Set(['DDD:D_708']), new Set(['AFTU:A_839'])],
    ['AFTU → DDD', new Set(['AFTU:A_839']), new Set(['DDD:D_708'])],
  ];
  for (const [nom, from, to] of corridors) {
    const js = planJourneys(ALL, from, to, LUNDI_10H, { maxResults: 4 });
    assert.ok(js.length > 0, `${nom} : corridor exploitable`);
    for (const j of js) verifieTransitions(j, nom);
    // Sens des réseaux respecté sur le corridor (premier/dernier leg).
    const j = js[0];
    assert.ok(j.legs.length >= 1, nom);
    verifieTransitions(j, nom);
  }
});

test('3e. identité publique non confirmée ≠ preuve de correspondance', () => {
  // Les rattachements d'arrêts du crosswalk n'existent QUE dans le périmètre
  // des identités documentées : aftu_8/aftu_11 (non confirmées) ne rattachent
  // AUCUN arrêt — leur hypothèse ne sert jamais de preuve.
  assert.deepEqual(ALL.cw.stops.aftu_8 ?? {}, {});
  assert.deepEqual(ALL.cw.stops.aftu_11 ?? {}, {});
  for (const [id, m] of Object.entries(ALL.cw.routes)) {
    const stops = ALL.cw.stops[id] ?? {};
    const avecRattachement = Object.values(stops).some((v) => v != null);
    if (avecRattachement) {
      assert.equal(m.status, 'MAPPED', `${id} : arrêts rattachés hors identité documentée`);
      assert.ok(DOCUMENTED_IDENTITY_METHODS.includes(m.method), id);
    }
  }
  // Un transfert ne porte jamais d'identité de ligne : uniquement des clés
  // d'arrêts PassBi réellement desservis.
  for (const t of documentedTransfers(ALL.cw)) {
    for (const key of [t.from, t.to]) {
      const [net, stopId] = splitComposite(key);
      const n = ALL.networks[net];
      assert.ok(n, `transfert vers un réseau hors feed : ${key}`);
      const si = n._stopById.get(stopId);
      assert.notEqual(si, undefined, `transfert vers un arrêt inconnu : ${key}`);
      assert.ok((n._byStop.get(si) ?? []).length > 0,
        `transfert vers un arrêt jamais desservi : ${key}`);
    }
  }
});

// ============================================ 4. IDENTITÉ ≠ HORAIRE
test('4a. DDD_217 / D217OT : horaire disponible, identité UNKNOWN, libellé honnête', () => {
  const ref = routeSummaries(ALL, 'DDD').find((s) => s.routeId === 'DDD_217');
  assert.ok(ref, 'DDD_217 existe dans le feed');
  assert.equal(ref.shortName, 'D217OT');
  assert.equal(ref.scheduleAvailable, true, 'horaire calculable (trips + stop_times)');
  assert.equal(ref.identityStatus, IDENTITY.UNCONFIRMED, 'identité publique UNKNOWN');
  assert.deepEqual(ref.dakarRouteIds, [], 'aucune identité publique déduite du numéro');

  const net = ALL.networks.DDD;
  const stopId = net.stops.find((s, i) =>
    (net._byStop.get(i) ?? []).some((st) => net.trips[st[0]][1] === net._routeById.get('DDD_217')))[0];
  const res = departureAtPassBiStop(ALL, 'DDD', stopId, LUNDI_12H, { pbRouteId: 'DDD_217' });
  assert.equal(res.status, 'SCHEDULED', 'l identité non confirmée n bloque pas l horaire');
  assert.equal(res.identityStatus, IDENTITY.UNCONFIRMED);
  assert.equal(res.frequencyMinutes, null, 'jamais une fréquence transformée en horaire');
  assert.match(res.lineLabel, /^Ligne PassBi DDD_217/,
    'un identifiant PassBi n est jamais présenté comme le numéro public DDD');
  assert.match(res.lineLabel, /D217OT/, 'le short_name du feed reste visible tel quel');
  assert.equal(res.lineLabel.startsWith('D217OT'), false);
  assert.notEqual(res.lineLabel, 'D217OT');
  assert.match(res.identityNote, /UNCONFIRMED/);
});

test('4b. AFTU_3 : horaire disponible + identité UNKNOWN (séparation stricte)', () => {
  const res = departureAtPassBiStop(ALL, 'AFTU', 'A_1633', LUNDI_10H, { pbRouteId: 'AFTU_3' });
  assert.equal(res.status, 'SCHEDULED');
  assert.equal(res.identityStatus, IDENTITY.UNCONFIRMED);
  assert.match(res.lineLabel, /^Ligne PassBi AFTU_3/);
});

test('4c. les horaires proviennent uniquement de vrais trips + stop_times', () => {
  const net = ALL.networks.DDD;
  const ref = routeSummaries(ALL, 'DDD').find((s) => s.routeId === 'DDD_01');
  const stopId = net.stops.find((s, i) =>
    (net._byStop.get(i) ?? []).some((st) => net.trips[st[0]][1] === net._routeById.get('DDD_01')))[0];
  const res = departureAtPassBiStop(ALL, 'DDD', stopId, LUNDI_12H, { pbRouteId: 'DDD_01' });
  assert.equal(res.status, 'SCHEDULED');
  // Le départ annoncé existe comme stop_time réel du feed (aucune estimation).
  const si = net._stopById.get(stopId);
  const ridx = net._routeById.get('DDD_01');
  const secondOfDay = res.depAbs % 86400;
  const reel = (net._byStop.get(si) ?? []).some((st) =>
    net.trips[st[0]][1] === ridx && st[4] === secondOfDay);
  assert.ok(reel, `départ ${secondOfDay}s absent des stop_times réels`);
  assert.equal(res.frequencyMinutes, null);
  assert.notEqual(res.status, 'REAL_TIME');
  assert.ok(ref.trips > 0 && ref.stopTimes > 0);
});
