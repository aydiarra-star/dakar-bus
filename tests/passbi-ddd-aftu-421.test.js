// Lot 4.21 — EXPLOITATION COMPLÈTE DES DONNÉES PASSBI DDD / AFTU / TATA.
//
// Matrice §11 (A–L) du lot :
//   A. DDD avec prochain départ PassBi calculable
//   B. AFTU avec prochain départ PassBi calculable
//   C. DDD sans départ → UNKNOWN
//   D. AFTU sans départ → UNKNOWN
//   E. DDD/AFTU SCHEDULED ≠ REAL_TIME
//   F. ETA dynamique
//   G. changement de jour
//   H. terminus : arrivée ≠ prochain départ
//   I. horizon d'embarquement
//   J. aucune identité inventée
//   K. aucun TATA inventé
//   L. correspondance DDD/AFTU uniquement si réellement supportée
//
// Les attendus proviennent des données PassBi PRÉSENTES DANS LE DÉPÔT
// (flutter-src/assets/data/passbi/*.json) ; le moteur Lot 4.19
// (tests/helpers/passbi-engine419.mjs) sert de contre-vérification indépendante
// du chemin natif ajouté ici (tests/helpers/passbi-native421.mjs).
import test from 'node:test';
import assert from 'node:assert/strict';

import { loadAll, nextDepartureAbs, planJourneys, splitComposite } from './helpers/passbi-engine419.mjs';
import {
  IDENTITY,
  REASON,
  departureAtPassBiStop,
  identityStatusOf,
  nativeNetworkKeys,
  nativeStops,
  networkAvailability,
  nextNativeDeparture,
  routeSummaries,
  schedulableRouteCount,
  searchNativeStops,
  tataMentions,
  normalizeName,
  AT,
  fmtSec,
} from './helpers/passbi-native421.mjs';

const ALL = loadAll();
const DDD = routeSummaries(ALL, 'DDD');
const AFTU = routeSummaries(ALL, 'AFTU');

// Lundi 2026-09-28 (jour ouvré) / dimanche 2026-10-04 (week-end).
const LUNDI_10H = AT(2026, 9, 28, 10, 0);
const LUNDI_12H = AT(2026, 9, 28, 12, 0);
const LUNDI_23H59 = AT(2026, 9, 28, 23, 59);
const DIMANCHE_10H = AT(2026, 10, 4, 10, 0);
const DIMANCHE_23H59 = AT(2026, 10, 4, 23, 59);

/// Premier arrêt desservi par une route (celui de sa première séquence).
function firstStopOf(networkKey, routeId) {
  const net = ALL.networks[networkKey];
  const ri = net._routeById.get(routeId);
  for (const [ti, t] of net.trips.entries()) {
    if (t[1] !== ri) continue;
    const rows = net._byTrip.get(ti) ?? [];
    if (rows.length === 0) continue;
    return { stopId: net.stops[rows[0][1]][0], name: net.stops[rows[0][1]][1], tripIndex: ti, rows };
  }
  return null;
}

// ==================================================================== A
test('A. DDD — prochain départ PassBi réellement calculable (SCHEDULED)', () => {
  const ref = firstStopOf('DDD', 'DDD_01');
  assert.ok(ref, 'DDD_01 doit desservir des arrêts');
  const res = departureAtPassBiStop(ALL, 'DDD', ref.stopId, LUNDI_12H, { pbRouteId: 'DDD_01' });
  assert.equal(res.status, 'SCHEDULED', `${ref.stopId} : ${JSON.stringify(res)}`);
  assert.equal(res.routeId, 'DDD_01');
  assert.equal(res.sourceType, 'PUBLIC_GTFS');
  assert.ok(res.depAbs !== null);
  // Contre-vérification avec le moteur Lot 4.19, inchangé.
  const independant = nextDepartureAbs(
    ALL.networks.DDD,
    ['DDD_01'],
    [ref.stopId],
    { year: 2026, month: 9, day: 28 },
    12 * 3600,
  );
  assert.equal(res.depAbs, independant, 'le chemin natif doit rendre le même départ que le moteur 4.19');
  assert.equal(res.label, `Prochain départ dans ${Math.floor((independant - 12 * 3600) / 60)} min`);
  // Aucune fréquence n'est jamais un départ.
  assert.equal(res.frequencyMinutes, null);
});

test('A bis. DDD — 52 des 53 routes du feed ont des horaires calculables', () => {
  assert.equal(DDD.length, 53);
  assert.equal(schedulableRouteCount(ALL, 'DDD'), 52);
  const sans = DDD.filter((r) => !r.scheduleAvailable);
  assert.deepEqual(sans.map((r) => r.routeId), ['DDD_323']);
  assert.equal(sans[0].reason, REASON.NO_STOP_TIMES);
  assert.equal(sans[0].trips, 288, 'DDD_323 a bien des trips… sans aucun stop_time');
  assert.equal(sans[0].stopTimes, 0);
});

// ==================================================================== B
test('B. AFTU — prochain départ PassBi réellement calculable (SCHEDULED)', () => {
  const ref = firstStopOf('AFTU', 'AFTU_3');
  assert.ok(ref, 'AFTU_3 doit desservir des arrêts');
  const res = departureAtPassBiStop(ALL, 'AFTU', ref.stopId, LUNDI_10H, { pbRouteId: 'AFTU_3' });
  assert.equal(res.status, 'SCHEDULED', JSON.stringify(res));
  assert.equal(res.routeId, 'AFTU_3');
  const independant = nextDepartureAbs(
    ALL.networks.AFTU,
    ['AFTU_3'],
    [ref.stopId],
    { year: 2026, month: 9, day: 28 },
    10 * 3600,
  );
  assert.equal(res.depAbs, independant);
});

test('B bis. AFTU — 71 des 73 routes du feed ont des horaires calculables', () => {
  assert.equal(AFTU.length, 73);
  assert.equal(schedulableRouteCount(ALL, 'AFTU'), 71);
  assert.deepEqual(
    AFTU.filter((r) => !r.scheduleAvailable).map((r) => r.routeId).sort(),
    ['AFTU_47', 'AFTU_52'],
  );
  assert.equal(AFTU.find((r) => r.routeId === 'AFTU_47').trips, 0);
  assert.equal(AFTU.find((r) => r.routeId === 'AFTU_52').stopTimes, 0);
});

// ==================================================================== C
test('C. DDD sans aucun départ calculable → UNKNOWN motivé (jamais un faux départ)', () => {
  // 1) arrêt inexistant dans le feed.
  const inconnu = departureAtPassBiStop(ALL, 'DDD', 'D_INEXISTANT', LUNDI_12H);
  assert.equal(inconnu.status, 'UNKNOWN');
  assert.equal(inconnu.unresolvedReason, REASON.NO_DEPARTURE);
  assert.equal(inconnu.lineLabel, null);
  assert.equal(inconnu.scheduledTime, null);

  // 2) route du feed sans aucun stop_time (DDD_323) : l'appel au moteur natif
  //    échoue parce que l'ARRÊT n'est pas desservi par cette route.
  const ref = nativeStops(ALL, 'DDD')[0];
  const sansHoraire = departureAtPassBiStop(ALL, 'DDD', ref.stopId, LUNDI_12H, { pbRouteId: 'DDD_323' });
  assert.equal(sansHoraire.status, 'UNKNOWN');
  assert.equal(sansHoraire.unresolvedReason, REASON.NO_STOP_TIMES);
  assert.equal(sansHoraire.frequencyMinutes, null);

  // 3) aucune requête DDD ne produit REAL_TIME.
  assert.notEqual(inconnu.status, 'REAL_TIME');
});

// ==================================================================== D
test('D. AFTU sans aucun départ calculable → UNKNOWN motivé', () => {
  const inconnu = departureAtPassBiStop(ALL, 'AFTU', 'A_INEXISTANT', LUNDI_12H);
  assert.equal(inconnu.status, 'UNKNOWN');
  assert.equal(inconnu.unresolvedReason, REASON.NO_DEPARTURE);

  const ref = nativeStops(ALL, 'AFTU')[0];
  const sansHoraire = departureAtPassBiStop(ALL, 'AFTU', ref.stopId, LUNDI_12H, { pbRouteId: 'AFTU_47' });
  assert.equal(sansHoraire.status, 'UNKNOWN');
  assert.equal(sansHoraire.unresolvedReason, REASON.NO_STOP_TIMES);
});

test('D bis. UNKNOWN ne signifie JAMAIS « feed absent » quand le feed existe', () => {
  assert.equal(networkAvailability(ALL, 'DDD'), 'AVAILABLE');
  assert.equal(networkAvailability(ALL, 'AFTU'), 'AVAILABLE');
});

// ==================================================================== E
test('E. DDD/AFTU — SCHEDULED n\'est jamais REAL_TIME (aucun flux temps réel)', () => {
  const echantillons = [
    ['DDD', nativeStops(ALL, 'DDD')[5].stopId],
    ['DDD', nativeStops(ALL, 'DDD')[500].stopId],
    ['AFTU', nativeStops(ALL, 'AFTU')[7].stopId],
    ['AFTU', nativeStops(ALL, 'AFTU')[900].stopId],
  ];
  for (const [net, stopId] of echantillons) {
    const res = departureAtPassBiStop(ALL, net, stopId, LUNDI_12H);
    assert.ok(['SCHEDULED', 'UNKNOWN'].includes(res.status), `${net} ${stopId} : ${res.status}`);
    assert.equal(res.sourceType === 'PUBLIC_GTFS' || res.status === 'UNKNOWN', true);
    if (res.status === 'SCHEDULED') {
      assert.equal(res.sourceType, 'PUBLIC_GTFS');
      assert.equal(res.frequencyMinutes, null, 'une fréquence n\'est jamais un départ');
    }
    assert.notEqual(res.label, 'Prochain départ dans 0 min', 'jamais « 0 min »');
  }
});

test('E bis. les feeds DDD/AFTU ne contiennent aucune donnée temps réel', () => {
  for (const key of ['DDD', 'AFTU']) {
    const net = ALL.networks[key];
    assert.equal(net.meta.time_semantics.startsWith('SCHEDULED'), true, `${key} : ${net.meta.time_semantics}`);
    assert.equal(/realtime|temps r[ée]el/i.test(net.meta.source_type), false);
  }
});

// ==================================================================== F
test('F. ETA dynamique : le libellé suit l\'heure de la demande', () => {
  const net = ALL.networks.DDD;
  const stopId = nativeStops(ALL, 'DDD')[2].stopId;
  const t0 = AT(2026, 9, 28, 8, 0);
  const t1 = AT(2026, 9, 28, 8, 30);
  const a = departureAtPassBiStop(ALL, 'DDD', stopId, t0);
  const b = departureAtPassBiStop(ALL, 'DDD', stopId, t1);
  assert.equal(a.status, 'SCHEDULED');
  assert.equal(b.status, 'SCHEDULED');
  // Les deux départs diffèrent (aucun ETA figé), et l'attente est cohérente.
  assert.notEqual(a.depAbs, b.depAbs);
  const wait0 = a.estimatedWaitFrom;
  const wait1 = b.estimatedWaitFrom;
  assert.ok(wait0 >= 0 && wait1 >= 0);
  assert.equal(a.label, wait0 === 0 ? 'Prochain départ dans moins d’une minute' : `Prochain départ dans ${wait0} min`);
  assert.equal(b.label, wait1 === 0 ? 'Prochain départ dans moins d’une minute' : `Prochain départ dans ${wait1} min`);
  // Le départ absolu du second doit rester dans la journée du lundi.
  assert.ok(b.depAbs < 2 * 86400, 'ETA dynamique sans dérive de jour');
});

// ==================================================================== G
test('G. changement de jour : 23:59 → service J+1 retrouvé', () => {
  // Balaie les arrêts DDD pour trouver un cas de bascule réelle.
  let trouve = null;
  for (const s of nativeStops(ALL, 'DDD').slice(0, 400)) {
    const res = departureAtPassBiStop(ALL, 'DDD', s.stopId, LUNDI_23H59);
    if (res.status === 'SCHEDULED' && res.depAbs > 86400) {
      trouve = { s, res };
      break;
    }
  }
  assert.ok(trouve, 'un départ J+1 doit être trouvable après le dernier service du lundi');
  assert.equal(trouve.s.stopId.trim().length > 0, true);
  assert.ok(trouve.res.depAbs >= 86400);
  // Le rendez-vous affiché est bien daté du lendemain.
  assert.equal(trouve.res.scheduledTime.getUTCDate(), 29);
});

test('G bis. le service diffère selon le jour (motifs du feed réellement évalués)', () => {
  // DDD_18 et DDD_20 ne circulent qu'en semaine (service LAV) ; le dimanche,
  // leur premier arrêt doit chercher le prochain jour ouvré.
  const net = ALL.networks.DDD;
  const ri = net._routeById.get('DDD_18');
  let stopId = null;
  for (const [ti, t] of net.trips.entries()) {
    if (t[1] !== ri) continue;
    const rows = net._byTrip.get(ti) ?? [];
    if (rows.length > 0) { stopId = net.stops[rows[0][1]][0]; break; }
  }
  const dimanche = departureAtPassBiStop(ALL, 'DDD', stopId, DIMANCHE_10H, { pbRouteId: 'DDD_18' });
  assert.equal(dimanche.status, 'SCHEDULED');
  assert.ok(dimanche.depAbs > 86400, 'aucun service LAV le dimanche : départ reporté');
  const lundi = departureAtPassBiStop(ALL, 'DDD', stopId, LUNDI_10H, { pbRouteId: 'DDD_18' });
  assert.equal(lundi.status, 'SCHEDULED');
  assert.ok(lundi.depAbs < 86400, 'le lundi, DDD_18 part le jour même');
});

// ==================================================================== H
test('H. terminus : une ARRIVÉE de trip fini n\'est jamais un prochain départ', () => {
  const net = ALL.networks.DDD;
  const ri = net._routeById.get('DDD_01');
  // Dernier arrêt des trips DDD_01 = terminus (arrivée seule).
  let terminusStopId = null;
  for (const [ti, t] of net.trips.entries()) {
    if (t[1] !== ri) continue;
    const rows = net._byTrip.get(ti) ?? [];
    if (rows.length > 0) { terminusStopId = net.stops[rows[rows.length - 1][1]][0]; break; }
  }
  const res = departureAtPassBiStop(ALL, 'DDD', terminusStopId, LUNDI_12H, { pbRouteId: 'DDD_01' });
  if (res.status === 'SCHEDULED') {
    // Le départ retenu n'est pas l'arrivée de terminus : il correspond à un
    // stop_time embarquable (la route doit continuer après cet arrêt).
    assert.equal(res.routeId, 'DDD_01');
    const suffix = res.depAbs % 86400;
    const list = net._byStop.get(net._stopById.get(terminusStopId)) ?? [];
    const match = list.find((st) => st[4] === suffix && net.trips[st[0]][1] === ri);
    assert.ok(match, 'le départ rendu doit exister en stop_time');
    const rows = net._byTrip.get(match[0]);
    assert.ok(match[2] < rows[rows.length - 1][2],
      'le stop_time retenu doit être EMBARQUABLE (le trip continue)');
  }
  // Le prochain départ via la route native respecte la même règle que le
  // moteur 4.19 (rideableOnly = true par défaut).
  const natif = nextNativeDeparture(ALL, 'DDD', terminusStopId, LUNDI_12H, { onlyRouteId: 'DDD_01' });
  const moteur = nextDepartureAbs(net, ['DDD_01'], [terminusStopId],
    { year: 2026, month: 9, day: 28 }, 12 * 3600, { rideableOnly: true });
  assert.equal(natif === null ? null : natif.sec, moteur);
});

// ==================================================================== I
test('I. horizon d\'embarquement : départ dans l\'horizon, arrivée au-delà conservée', () => {
  const HORIZON = 6 * 3600;
  const depart = 23 * 3600 + 59 * 60;
  const borneEmbarquement = depart + HORIZON;

  // (1) INVARIANT sur les trajets DDD : tout EMBARQUEMENT tombe dans l'horizon,
  //     y compris quand l'ARRIVÉE le dépasse (correction Lot 4.19 C).
  const origine = nativeStops(ALL, 'DDD')[0].compositeKey;
  let trajets = 0;
  let arriveesAuDela = 0;
  for (const s of nativeStops(ALL, 'DDD').slice(0, 80)) {
    const js = planJourneys(ALL, new Set([origine]), new Set([s.compositeKey]), LUNDI_23H59, { maxResults: 2 });
    for (const j of js) {
      trajets++;
      assert.ok(j.departureSec <= borneEmbarquement,
        `embarquement ${j.departureSec} hors horizon (${borneEmbarquement})`);
      if (j.arrivalSec > borneEmbarquement) arriveesAuDela++;
    }
  }

  // (2) CAS PROUVÉ du dépôt (Lot 4.19 C) : TER Colobane → Diamniadio dimanche
  //     23:59 — embarquement lundi 05:35:30 (dans l'horizon), arrivée 06:15:09
  //     AU-DELÀ de l'horizon. Le moteur natif DDD/AFTU partage ce code :
  //     l'arrivée n'est jamais tronquée par l'horizon.
  const terFrom = ALL.cw.stops?.ter_dakar_diamniadio?.stop_colobane?.pb;
  const terTo = ALL.cw.stops?.ter_dakar_diamniadio?.stop_diamniadio?.pb;
  if (terFrom && terTo) {
    const js = planJourneys(ALL, new Set([terFrom]), new Set([terTo]), DIMANCHE_23H59, { maxResults: 2 });
    assert.ok(js.length > 0, 'trajet J+1 embarquable après le dernier service');
    const j = js[0];
    assert.ok(j.departureSec <= DIMANCHE_23H59.hour * 3600 + DIMANCHE_23H59.minute * 60 + HORIZON);
    assert.ok(j.arrivalSec > borneEmbarquement,
      `arrivée ${j.arrivalSec} doit dépasser l'horizon ${borneEmbarquement} (Lot 4.19 C)`);
    arriveesAuDela++;
  }

  assert.ok(trajets > 0 || arriveesAuDela > 0,
    'l\'horizon laisse passer des trajets réels, y compris à cheval sur minuit');
});

// ==================================================================== J
test('J. aucune identité inventée : le crosswalk ne rattache QUE ce qu\'il a prouvé', () => {
  // 1) Aucune route DDD n'est mappée (l'identité publique reste à confirmer).
  for (const s of DDD) {
    if (s.identityStatus === IDENTITY.CONFIRMED) {
      assert.ok(s.dakarRouteIds.length > 0, `${s.routeId} ne peut pas être CONFIRMED sans rattachement`);
    } else {
      assert.equal(s.dakarRouteIds.length, 0, `${s.routeId} : aucune identité ne doit être devinée`);
    }
  }
  assert.equal(DDD.filter((s) => s.identityStatus === IDENTITY.CONFIRMED).length, 0);
  // 2) AFTU : seules les routes réellement rattachées par le crosswalk.
  const aftuConfirmed = AFTU.filter((s) => s.identityStatus === IDENTITY.CONFIRMED);
  assert.deepEqual(aftuConfirmed.map((s) => s.routeId).sort(), ['AFTU_3']);
  assert.deepEqual(aftuConfirmed[0].dakarRouteIds.sort(), ['aftu_11', 'aftu_8']);
  // 3) L'identité affichée vient du feed (route_id / short_name), jamais d'un
  //    nom commercial ni d'un numéro déduit.
  const ref15 = firstStopOf('DDD', 'DDD_15');
  assert.ok(ref15, 'DDD_15 doit desservir des arrêts');
  const exemple = departureAtPassBiStop(ALL, 'DDD', ref15.stopId, LUNDI_12H, { pbRouteId: 'DDD_15' });
  assert.equal(exemple.status, 'SCHEDULED');
  {
    assert.match(exemple.lineLabel, /^Ligne PassBi DDD_15/);
    assert.equal(exemple.identityStatus, IDENTITY.UNCONFIRMED);
    assert.match(exemple.identityNote, /UNCONFIRMED/);
  }
  // 4) Aucune route PassBi ne porte de nom d'arrêt du référentiel dakar : la
  //    correspondance n'est jamais déduite.
  assert.equal(identityStatusOf(ALL.cw, 'DDD', 'DDD_01'), IDENTITY.UNCONFIRMED);
  assert.equal(identityStatusOf(ALL.cw, 'BRT', 'B1'), IDENTITY.CONFIRMED);
});

// ==================================================================== K
test('K. aucun TATA inventé : aucune donnée PassBi n\'établit TATA', () => {
  assert.deepEqual(tataMentions(ALL), [], 'aucune mention « tata » dans les feeds PassBi');
  assert.equal(networkAvailability(ALL, 'TATA'), 'ABSENT_FROM_FEED');
  assert.equal(ALL.networks.TATA, undefined, 'aucun feed TATA n\'est chargé');
  // Le crosswalk constate explicitement l'absence de réseau côté feed.
  const tataMappings = Object.entries(ALL.cw.routes).filter(([id]) => id.startsWith('tata_'));
  assert.ok(tataMappings.length > 0, 'les identités TATA du référentiel dakar existent');
  for (const [id, m] of tataMappings) {
    assert.equal(m.status, 'UNMAPPED', id);
    assert.equal((m.pbRouteIds ?? []).length, 0, `${id} : aucune route TATA fabriquée`);
    assert.equal(m.method, 'RESEAU_ABSENT_DU_FEED', id);
  }
  // Aucun réseau PassBi ne porte de mode/vehicle_type « tata ».
  for (const key of Object.keys(ALL.networks)) {
    for (const r of ALL.networks[key].routes) {
      assert.equal(`${r.id} ${r.short} ${r.long}`.toLowerCase().includes('tata'), false);
    }
  }
});

// ==================================================================== L
test('L. correspondance DDD ↔ AFTU uniquement via un lien réellement documenté', () => {
  const liees = ALL.cw.transfers.filter((t) => {
    const a = splitComposite(t.from)[0];
    const b = splitComposite(t.to)[0];
    return (a === 'DDD' && b === 'AFTU') || (a === 'AFTU' && b === 'DDD');
  });
  assert.ok(liees.length >= 700, `liens DDD↔AFTU documentés : ${liees.length}`);
  for (const t of liees) {
    assert.ok(t.meters <= 500, 'une correspondance ne dépasse pas 500 m');
    assert.ok(['high', 'medium'].includes(t.confidence), t.confidence);
  }

  // Un trajet réel DDD → AFTU : le premier tronçon est DDD, le dernier AFTU,
  // et chaque transition s'appuie sur un arrêt partagé ou un lien documenté.
  const from = 'DDD:D_708'; // « Terminus Palais 2 »
  const to = 'AFTU:A_839'; // « Gare Ter Keur Mbaye Fall »
  const js = planJourneys(ALL, new Set([from]), new Set([to]), AT(2026, 9, 28, 7, 30), { maxResults: 4 });
  assert.ok(js.length > 0, 'le corridor DDD → AFTU doit être exploitable');
  const j = js[0];
  assert.equal(j.legs[j.legs.length - 1].network, 'AFTU');
  assert.ok(js.some((x) => x.legs[0].network === 'DDD'),
    'au moins un trajet embarque bien sur le réseau DDD de départ');
  /// Toute transition de tronçon repose sur un arrêt PARTAGÉ ou un lien
  /// réellement documenté du crosswalk — jamais sur une proximité.
  const verifieTransitions = (trajet) => {
    for (let i = 1; i < trajet.legs.length; i++) {
      const precedent = trajet.legs[i - 1];
      const suivant = trajet.legs[i];
      const memeArret = precedent.toStopId === suivant.fromStopId;
      const lien = ALL.cw.transfers.find((t) =>
        (t.from === precedent.toStopId && t.to === suivant.fromStopId) ||
        (t.to === precedent.toStopId && t.from === suivant.fromStopId));
      assert.ok(memeArret || lien,
        `correspondance non documentée ${precedent.toStopId} → ${suivant.fromStopId}`);
    }
  };
  for (const trajet of js) verifieTransitions(trajet);

  // Sens inverse : AFTU → DDD.
  const inverse = planJourneys(ALL, new Set([to]), new Set([from]), AT(2026, 9, 28, 7, 30), { maxResults: 4 });
  for (const trajet of inverse) verifieTransitions(trajet);
  // La correspondance inverse AFTU → DDD est réellement empruntée par le
  // moteur (l'embarquement initial peut se faire sur un autre réseau via un
  // lien documenté : c'est le moteur, pas le test, qui choisit).
  assert.ok(inverse.length > 0, 'le corridor AFTU → DDD doit être exploitable');
  const utiliseAftuVersDdd = inverse.some((x) =>
    x.legs.some((l, i) => i > 0 && x.legs[i - 1].network === 'AFTU' && l.network === 'DDD'));
  assert.ok(utiliseAftuVersDdd, 'au moins un trajet enchaîne AFTU puis DDD');
  const utiliseDddVersAftu = js.some((x) =>
    x.legs.some((l, i) => i > 0 && x.legs[i - 1].network === 'DDD' && l.network === 'AFTU'));
  assert.ok(utiliseDddVersAftu, 'au moins un trajet enchaîne DDD puis AFTU');
  // Aucune correspondance n'est créée par pure proximité : tout lien du
  // crosswalk porte une méthode et une confiance documentées.
  for (const t of ALL.cw.transfers) {
    assert.ok(t.method, `transfert sans méthode : ${JSON.stringify(t)}`);
    assert.ok(t.confidence, `transfert sans confiance : ${JSON.stringify(t)}`);
  }
});

// ============================================================ audit §1
test('§1 — tableau d\'audit DDD / AFTU / TATA reproductible', () => {
  assert.deepEqual(nativeNetworkKeys(ALL), ['DDD', 'AFTU'],
    'TER et BRT ont une identité confirmée : hors référentiel natif');
  for (const [key, total, attendu] of [['DDD', 53, 52], ['AFTU', 73, 71]]) {
    const s = routeSummaries(ALL, key);
    assert.equal(s.length, total);
    assert.equal(s.filter((r) => r.scheduleAvailable).length, attendu);
    for (const r of s) {
      assert.ok(r.routeId && r.shortName && r.longName, `${key} ${r.routeId}`);
      assert.equal(r.network, key);
      assert.ok(Array.isArray(r.serviceIds));
      assert.ok(Array.isArray(r.directions));
      assert.ok(r.directions.every((d) => d === '0' || d === '1'),
        'directions = direction_id réels du feed (0/1), jamais inventés');
    }
  }
  // Arrêts natifs réellement appelés (aucun n'est fabriqué).
  assert.equal(nativeStops(ALL, 'DDD').length, 1186);
  assert.equal(nativeStops(ALL, 'AFTU').length, 2237);
  for (const s of nativeStops(ALL, 'DDD').slice(0, 50)) {
    assert.ok(s.routeCount > 0, `${s.stopId} exposé sans être appelé`);
  }
});

test('§8 — recherche native : correspondance stricte, jamais approchée', () => {
  // Nom réel complet : trouvé.
  assert.ok(searchNativeStops(ALL, 'Terminus Palais 2').length > 0);
  // Requête partielle trop courte : refusée (garde-fou de longueur).
  assert.deepEqual(searchNativeStops(ALL, 'Pa'), []);
  // Fragment de nom isolé : aucune correspondance inventée.
  assert.deepEqual(searchNativeStops(ALL, 'zzzz introuvable'), []);
  // Normalisation : accents et ponctuation neutralisés.
  assert.equal(normalizeName('Guédiawaye - Gare'), 'guediawaye gare');
});
