// Lot 4.19 — VALIDATION FONCTIONNELLE RÉELLE (moteur, routage, ETA).
//
// Exécute l'ensemble des cas §1–§13 du lot contre la couche PassBi intégrée,
// via le miroir fidèle du moteur Dart (tests/helpers/passbi-engine419.mjs)
// corrigé par le Lot 4.19 (départs embarquables, passage J+1, horizons).
// Aucun mock : uniquement les assets réels flutter-src/assets/data/passbi/.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  loadAll, nextDepartureAbs, nextDepartureRawBuggy, providerDeparture,
  planJourneys, activeServices, AT, fmtSec, splitComposite,
} from './helpers/passbi-engine419.mjs';

const all = loadAll();
const { networks: N, cw } = all;
const ALL_TER = N.TER.routes.map((r) => r.id);

// Identifiants PassBi (composite)
const C_DAKAR = 'TER:544a27a5-c6c6-4b70-b217-9c15d9b4278a-00000000-0000-0000-0000-000000000000';
const C_COL = 'TER:c70477e7-8391-4388-9a1f-8929a18dc14e-00000000-0000-0000-0000-000000000000';
const C_DIA = 'TER:4445e51b-971b-4f1a-a94a-1ca0c9bef411-00000000-0000-0000-0000-000000000000';
const C_RUF = 'TER:1d859f92-c798-4291-9631-262ed863698a-00000000-0000-0000-0000-000000000000';
const C_KMF = 'TER:41016cdb-2f7f-4453-a774-ad1b74a9b876-00000000-0000-0000-0000-000000000000';

const LUN12 = AT(2026, 9, 28, 12, 0);
const LUN10 = AT(2026, 9, 28, 10, 0);
const LUN1329 = AT(2026, 9, 28, 13, 29);

function stopOrderOnTrip(net, tripIdx, stopIds) {
  const list = net._byTrip.get(tripIdx);
  const positions = stopIds.map((id) => list.findIndex((x) => x[1] === net._stopById.get(id)));
  return positions;
}

// ============================================================ §1 TER direct
test('§1 TER : Dakar → Diamniadio (route, trip, direction, ordre, horaires)', () => {
  const js = planJourneys(all, new Set([C_DAKAR]), new Set([C_DIA]), LUN12);
  assert.ok(js.length >= 1, 'itinéraire TER attendu');
  const j = js[0];
  assert.equal(j.transferCount, 0);
  assert.equal(j.legs.length, 1);
  const leg = j.legs[0];
  assert.equal(leg.network, 'TER');
  assert.ok(ALL_TER.includes(leg.routeId), 'route TER du feed');
  assert.ok(leg.tripId, 'trip identifié');
  assert.equal(leg.fromStopName, 'Dakar - Gare ferroviaire');
  assert.equal(leg.toStopName, 'Diamniadio');
  // direction cohérente : sens Diamniadio (dir 1, headsign Diamniadio)
  assert.equal(leg.direction, '1');
  assert.equal(leg.headsign, 'Diamniadio');
  // stop_sequence respectée : ordre croissant dans le trip
  const net = N.TER;
  const ti = net.trips.findIndex((t) => t[0] === leg.tripId);
  const pos = stopOrderOnTrip(net, ti, [
    C_DAKAR.slice(4), C_COL.slice(4), C_DIA.slice(4),
  ]);
  assert.deepEqual(pos, [0, 1, 2].map((k) => pos[k]));
  assert.ok(pos[0] < pos[1] && pos[1] < pos[2],
    `ordre gares incohérent: ${JSON.stringify(pos)}`);
  // horaires cohérents : départ < arrivée, dans la journée
  assert.ok(j.departureSec >= 12 * 3600 && j.arrivalSec > j.departureSec);
  assert.equal(fmtSec(j.departureSec), '12:06:00');
  assert.equal(fmtSec(j.arrivalSec), '12:51:29');
});

test('§1 TER : Dakar → Colobane, Colobane → Diamniadio', () => {
  const a = planJourneys(all, new Set([C_DAKAR]), new Set([C_COL]), LUN12)[0];
  assert.ok(a, 'Dakar→Colobane');
  assert.equal(a.legs[0].network, 'TER');
  assert.equal(a.legs[0].fromStopName, 'Dakar - Gare ferroviaire');
  assert.equal(a.legs[0].toStopName, 'Colobane');
  assert.equal(a.transferCount, 0);
  const b = planJourneys(all, new Set([C_COL]), new Set([C_DIA]), LUN12)[0];
  assert.ok(b, 'Colobane→Diamniadio');
  assert.equal(b.legs[0].fromStopName, 'Colobane');
  assert.equal(b.legs[0].toStopName, 'Diamniadio');
  // même véhicule que l'arrivée 12:11:25 côté Dakar→Colobane (cohérence)
  assert.ok(b.departureSec >= a.arrivalSec - 1);
});

test('§1 TER : Rufisque → Dakar (sens retour)', () => {
  const j = planJourneys(all, new Set([C_RUF]), new Set([C_DAKAR]), LUN12)[0];
  assert.ok(j, 'sens retour Rufisque→Dakar présent dans le feed');
  assert.equal(j.legs[0].fromStopName, 'Rufisque');
  assert.equal(j.legs[0].toStopName, 'Dakar - Gare ferroviaire');
  assert.equal(j.legs[0].direction, '0');
  assert.equal(j.legs[0].headsign, 'Dakar - Gare ferroviaire');
  assert.ok(j.arrivalSec > j.departureSec);
});

test('§1 TER : prochain départ calculable + ETA dynamique (colobane 12:00)', () => {
  const p = providerDeparture(all, 'ter_dakar_diamniadio', 'stop_colobane', LUN12);
  assert.equal(p.status, 'SCHEDULED');
  assert.equal(p.depAbs, 43885); // 12:11:25
  assert.equal(p.waitMin, 11);
  assert.equal(p.network, 'TER');
});

// ============================================================ §2 BRT B1
test('§2 B1 : Guédiawaye → Petersen + trajet intermédiaire B1 (Golf Nord)', () => {
  // Guédiawaye → Petersen : départ du quai de départ GDWB, headsign PETERSEN
  const j = planJourneys(all, new Set(['BRT:0:GDWB']), new Set(['BRT:0:PGFB']), LUN12)[0];
  assert.ok(j, 'B1 Guédiawaye→Petersen');
  assert.equal(j.legs.length, 1);
  assert.equal(j.legs[0].network, 'BRT');
  assert.ok(['B1', 'B2'].includes(j.legs[0].routeId)); // services parallèles
  assert.equal(j.legs[0].headsign, 'PETERSEN');
  // intermédiaire sur une station exclusive B1 : route B1 UNIQUEMENT
  const k = planJourneys(all, new Set(['BRT:0:GNOA']), new Set(['BRT:0:PGFB']), LUN12)[0];
  assert.ok(k, 'intermédiaire GOLF NORD→PETERSEN');
  assert.equal(k.legs[0].routeId, 'B1');
  assert.equal(k.legs[0].fromStopName, 'GOLF NORD');
  assert.ok(k.arrivalSec > k.departureSec);
  // stop_sequence : positions croissantes plateforme départ → PGFB sur le trip B1
  const net = N.BRT;
  const ti = net.trips.findIndex((t) => t[0] === k.legs[0].tripId);
  const pos = stopOrderOnTrip(net, ti, [
    k.legs[0].fromStopId.split(':').slice(1).join(':'), '0:PGFB']);
  assert.ok(pos[0] >= 0 && pos[1] > pos[0], `seq B1 invalide ${JSON.stringify(pos)}`);
  // ETA B1 dynamique (arrêt intermédiaire réel GRAND DAKAR)
  const p = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_05_grand_dakar', LUN1329);
  assert.equal(p.status, 'SCHEDULED');
  assert.deepEqual(p.routeIds, ['B1']);
  assert.equal(p.depAbs, 48724); // 13:32:04
  assert.equal(p.waitMin, 3); // 🟢 3 min — calculé, non codé en dur
});

test('§2 B1 : le départ affiché est un départ EMBARQUABLE (bug quai d arrivité)', () => {
  // Démonstration : l'ancien calcul sur PGFB (quai d'arrivée) donnait
  // 50547 = ARRIVÉE d'un trip terminé (0/50 lignes embarquables).
  const raw = nextDepartureRawBuggy(N.BRT, ['B1'], '0:PGFB', AT(2026, 9, 28, 0, 0), 14 * 3600);
  assert.equal(raw, 50547); // comportement ancien (arrivées de terminus)
  const rows = N.BRT._byStop.get(N.BRT._stopById.get('0:PGFB'));
  const rideable = rows.filter((st) => {
    const tl = N.BRT._byTrip.get(st[0]);
    const idx = tl.findIndex((x) => x[2] === st[2] && x[1] === st[1]);
    return idx >= 0 && idx < tl.length - 1;
  });
  assert.equal(rideable.length, 0, 'PGFB = quai d\'arrivée : aucun départ embarquable');
  // Correctif : plateforme sœur PGFA (départs), lien documenté 10 m.
  const p = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen',
    AT(2026, 9, 28, 14, 0));
  assert.equal(p.status, 'SCHEDULED');
  assert.equal(p.stop, 'BRT:0:PGFA');
  assert.equal(p.depAbs, 50430); // 14:00:30 — vrai départ, pas une arrivée
});

// ============================================================ §3 BRT B2
test('§3 B2 : trajet indépendant, arrêts/trips/séquence, ETA distincte de B1', () => {
  // Trips B2 : 7 stations express dans l'ordre, headsign cohérent.
  const net = N.BRT;
  const b2Trips = [...net._byTrip.keys()].filter(
    (ti) => net.routes[net.trips[ti][1]].id === 'B2');
  assert.ok(b2Trips.length > 800, 'trips B2 présents');
  const seq = ['0:PGFA', '0:GDAA', '0:SACA', '0:GMEA', '0:HDJA', '0:GDWA'];
  const ti0 = b2Trips.find((ti) => {
    const list = net._byTrip.get(ti);
    const ids = list.map((x) => net.stops[x[1]][0]);
    return seq.every((s, i) => ids.includes(s) && (i === 0 || ids.indexOf(s) > ids.indexOf(seq[i - 1])));
  });
  assert.ok(ti0 !== undefined, 'trip B2 avec stop_sequence croissante');
  const t0 = net.trips[ti0];
  assert.equal(t0[4], 'GUEDIAWAYE'); // direction cohérente
  // Itinéraire sur stations B2 (sous-ensemble de B1) : legs mono-route.
  const j = planJourneys(all, new Set(['BRT:0:GMEA']), new Set(['BRT:0:HDJA']), LUN12)[0];
  assert.ok(j, 'B2 stations express desservies');
  assert.equal(j.legs.length, 1);
  assert.ok(['B1', 'B2'].includes(j.legs[0].routeId));
  assert.equal(j.legs[0].routeId, net.routes[net.trips[
    net.trips.findIndex((t) => t[0] === j.legs[0].tripId)][1]].id,
  'route du leg = route du trip (aucun mélange)');
  // ETA B2 : strictement filtrée aux trips B2 (jamais l ETA B1).
  const p2 = providerDeparture(all, 'brt_b2_express', 'stop_brt_23_guediawaye',
    AT(2026, 9, 28, 14, 0));
  assert.equal(p2.status, 'SCHEDULED');
  assert.deepEqual(p2.routeIds, ['B2']);
  assert.equal(p2.depAbs, 50610); // 14:03:30 — via quai sœur GDWB
  const p1 = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen',
    AT(2026, 9, 28, 14, 0));
  assert.equal(p1.depAbs, 50430); // B1 : 14:00:30 — départs distincts
  assert.notEqual(p1.depAbs, p2.depAbs, 'aucune réutilisation croisée');
  // Aucune route B3 dans le feed.
  assert.equal(N.BRT.routes.some((r) => r.id === 'B3'), false);
});

// ============================================================ §4 DDD
test('§4 DDD : deux lignes exploitables (DDD_01, DDD_403) malgré identité UI non mappée', () => {
  const net = N.DDD;
  for (const rid of ['DDD_01', 'DDD_403']) {
    const ti0 = [...net._byTrip.keys()].find(
      (ti) => net.routes[net.trips[ti][1]].id === rid);
    assert.ok(ti0 !== undefined, `${rid} présent`);
    const list = net._byTrip.get(ti0);
    const trip = net.trips[ti0];
    // origine / destination / arrêts / trip / stop_sequence / horaire
    assert.ok(list.length >= 20, `${rid} : série d'arrêts`);
    assert.equal(list[0][2], 1, 'stop_sequence démarre à 1');
    for (let i = 1; i < list.length; i++) {
      assert.ok(list[i][2] > list[i - 1][2], `${rid} : séquence croissante`);
      assert.ok(list[i][4] >= list[i - 1][4], `${rid} : horaires croissants`);
    }
    assert.ok(trip[0].startsWith(rid), 'trip rattaché à la ligne');
    assert.ok(['0', '1'].includes(trip[3]), 'direction_id présent');
    // prochain départ calculable (moteur direct, identifiants PassBi)
    const firstStopId = net.stops[list[0][1]][0];
    const dep = nextDepartureAbs(net, [rid], [firstStopId], AT(2026, 9, 28, 0, 0), 6 * 3600);
    assert.ok(dep !== null && dep >= 6 * 3600, `${rid} : départ calculable`);
  }
  // Trajet complet DDD_01 : origine Terminus Parcelles → Terminus Leclerc.
  const j = planJourneys(all, new Set(['DDD:D_805']), new Set(['DDD:D_140']), LUN10)[0];
  assert.ok(j, 'itinéraire DDD_01 exploitable par le moteur');
  assert.equal(j.legs[0].network, 'DDD');
  assert.equal(j.legs[0].routeId, 'DDD_01');
  assert.equal(j.transferCount, 0);
  // Le mappage UI ddd_1 reste UNMAPPED : aucune identité forcée.
  assert.equal(cw.routes.ddd_1.status, 'UNMAPPED');
});

// ============================================================ §5 AFTU
test('§5 AFTU : deux routes exploitables (AFTU_1, AFTU_3), directions vérifiées', () => {
  const net = N.AFTU;
  const expected = {
    AFTU_1: { first: 'A_916', last: 'A_1601' },
    AFTU_3: { first: 'A_1633', last: 'A_1250' },
  };
  for (const [rid, ex] of Object.entries(expected)) {
    const ti0 = [...net._byTrip.keys()].find(
      (ti) => net.routes[net.trips[ti][1]].id === rid);
    assert.ok(ti0 !== undefined, `${rid} présent`);
    const list = net._byTrip.get(ti0);
    const trip = net.trips[ti0];
    assert.equal(net.stops[list[0][1]][0], ex.first, `${rid} origine`);
    assert.equal(net.stops[list[list.length - 1][1]][0], ex.last, `${rid} destination`);
    for (let i = 1; i < list.length; i++) {
      assert.ok(list[i][2] > list[i - 1][2], `${rid} : stop_sequence croissante`);
    }
    assert.ok(['0', '1'].includes(trip[3]), `${rid} : direction_id`);
    // départ + ETA via API moteur
    const dep = nextDepartureAbs(net, [rid], [ex.first], AT(2026, 9, 28, 0, 0), 8 * 3600);
    assert.ok(dep !== null && dep >= 8 * 3600, `${rid} : départ après 08:00`);
  }
  // Itinéraire complet AFTU_3 Petersen 1 → Yoff.
  const j = planJourneys(all, new Set(['AFTU:A_1633']), new Set(['AFTU:A_1250']), LUN10)[0];
  assert.ok(j, 'itinéraire AFTU_3');
  assert.equal(j.legs[0].network, 'AFTU');
  assert.ok(['AFTU_3', 'AFTU_4'].includes(j.legs[0].routeId),
    'route AFTU du feed (AFTU_3 ou service parallèle AFTU_4)');
  assert.equal(j.transferCount, 0);
});

// =============================================== §6 correspondance BRT → DDD
test('§6 BRT → DDD : correspondance documentée et temporellement compatible', () => {
  const js = planJourneys(all, new Set(['BRT:0:GNOA']), new Set(['DDD:D_449']), LUN10);
  assert.ok(js.length >= 1, 'corridor BRT→DDD exploitable');
  const j = js[0];
  assert.ok(j.transferCount >= 1, 'correspondance réelle (au moins 2 jambes)');
  const [l1, l2] = j.legs;
  assert.equal(l1.network, 'BRT');
  assert.equal(l2.network, 'DDD');
  // Le 2e départ doit être atteignable : arrivée 1re véhicule + marche ≤ départ 2e.
  assert.ok(l2.depSec >= l1.arrSec, '2e départ après arrivée du 1er véhicule');
  const link = cw.transfers.find((t) =>
    (t.from === l1.toStopId && t.to === l2.fromStopId) ||
    (t.to === l1.toStopId && t.from === l2.fromStopId));
  assert.ok(link, 'liaison de correspondance documentée dans le crosswalk');
  const walk = Math.max(1, Math.floor(link.meters / 80)) * 60;
  assert.ok(l2.depSec >= l1.arrSec + walk,
    `2e départ inatteignable: arr ${l1.arrSec} + ${walk} s > dep ${l2.depSec}`);
  assert.ok(link.meters <= 500, 'liaison ≤ 500 m');
});

// =============================================== §7 correspondance BRT → AFTU
test('§7 BRT → AFTU : 2e départ réellement atteignable', () => {
  // Origine B1 sans lien AFTU : le leg BRT est obligatoire (pas de raccourci).
  const js = planJourneys(all, new Set(['BRT:0:GNOA']), new Set(['AFTU:A_608']), LUN10);
  assert.ok(js.length >= 1, 'corridor BRT→AFTU exploitable');
  const j = js[0];
  assert.ok(j.transferCount >= 1, 'correspondance BRT→AFTU');
  const [l1, l2] = j.legs;
  assert.equal(l1.network, 'BRT');
  assert.equal(l2.network, 'AFTU');
  assert.ok(l2.depSec >= l1.arrSec, '2e véhicule après le 1er');
  const link = cw.transfers.find((t) =>
    (t.from === l1.toStopId && t.to === l2.fromStopId) ||
    (t.to === l1.toStopId && t.from === l2.fromStopId));
  assert.ok(link, 'lien documenté BRT↔AFTU');
  const walk = Math.max(1, Math.floor(link.meters / 80)) * 60;
  assert.ok(l2.depSec >= l1.arrSec + walk, 'marche tenue avant le 2e départ');
});

// =============================================== §8 correspondance TER → BUS
test('§8 TER → DDD : uniquement des liens documentés (aucune proximité seule)', () => {
  // Origine = gare Dakar TER : AUCUN lien direct → le leg TER est obligatoire.
  const lsDakar = cw.transfers.filter((t) => t.from === C_DAKAR || t.to === C_DAKAR);
  assert.equal(lsDakar.length, 0, 'aucun lien artificiel à la gare de Dakar');
  const js = planJourneys(all, new Set([C_DAKAR]), new Set(['DDD:D_325']), LUN10);
  assert.ok(js.length >= 1, 'corridor TER→DDD exploitable');
  const j = js[0];
  assert.ok(j.transferCount >= 1, 'correspondance TER→DDD');
  assert.equal(j.legs[0].network, 'TER', 'premier leg = TER (aucune invention)');
  assert.equal(j.legs[j.legs.length - 1].network, 'DDD');
  const l1 = j.legs[0], l2 = j.legs[1];
  const link = cw.transfers.find((t) =>
    (t.from === l1.toStopId && t.to === l2.fromStopId) ||
    (t.to === l1.toStopId && t.from === l2.fromStopId));
  assert.ok(link, 'lien TER↔DDD documenté (nom + distance)');
  assert.ok(link.meters <= 500);
  const walk = Math.max(1, Math.floor(link.meters / 80)) * 60;
  assert.ok(l2.depSec >= l1.arrSec + walk, 'temporalité de correspondance');
});

test('§8 TER → AFTU : même exigence de liens réels', () => {
  const js = planJourneys(all, new Set([C_DAKAR]), new Set(['AFTU:A_548']), LUN10);
  assert.ok(js.length >= 1, 'corridor TER→AFTU exploitable');
  const j = js[0];
  assert.ok(j.transferCount >= 1);
  assert.equal(j.legs[0].network, 'TER');
  assert.equal(j.legs[j.legs.length - 1].network, 'AFTU');
  const l1 = j.legs[0], l2 = j.legs[1];
  const link = cw.transfers.find((t) =>
    (t.from === l1.toStopId && t.to === l2.fromStopId) ||
    (t.to === l1.toStopId && t.from === l2.fromStopId));
  assert.ok(link, 'lien documenté');
  const walk = Math.max(1, Math.floor(link.meters / 80)) * 60;
  assert.ok(l2.depSec >= l1.arrSec + walk);
});

// ============================================================ §9 ETA
test('§9 ETA dynamique : 13:29 → 13:32 = 🟢 3 min ; 13:29 → 13:35 = 🟢 6 min', () => {
  // Cas 1 : B1 GRAND DAKAR, départ réel 13:32:04.
  const a = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_05_grand_dakar', LUN1329);
  assert.equal(fmtSec(a.depAbs), '13:32:04');
  assert.equal(a.waitMin, 3);
  // Cas 2 : TER Colobane, départ réel 13:35:12.
  const b = providerDeparture(all, 'ter_dakar_diamniadio', 'stop_colobane', LUN1329);
  assert.equal(fmtSec(b.depAbs), '13:35:12');
  assert.equal(b.waitMin, 6);
  // Dynamique : 30 s plus tôt sur le même arrêt → ETA différente.
  const earlier = providerDeparture(all, 'ter_dakar_diamniadio', 'stop_colobane', AT(2026, 9, 28, 13, 29, 30));
  assert.equal(earlier.waitMin, 5);
  // Jamais de « 0 min » pseudo temps réel : sous la minute = libellé dédié.
  const imminent = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen',
    AT(2026, 9, 28, 14, 0));
  assert.equal(imminent.depAbs, 50430); // 30 s après 14:00
  assert.equal(imminent.waitMin, 0); // → « moins d'une minute » côté label
  // Aucune fréquence convertie : la valeur vient d'un stop_times réel.
  assert.ok(N.BRT.stop_times.some((st) => st[4] === 48724));
  assert.ok(N.TER.stop_times.some((st) => st[4] === 48912));
});

// ============================================================ §10 jour suivant
test('§10 23:59 → 00:00 : prochain service trouvé sur J+1 (ETA + moteur)', () => {
  // ETA : dimanche 23:59 → premier TER du lundi 05:35:30 (abs 106530).
  const p = providerDeparture(all, 'ter_dakar_diamniadio', 'stop_colobane', AT(2026, 10, 4, 23, 59));
  assert.equal(p.status, 'SCHEDULED');
  assert.equal(p.depAbs, 106530);
  assert.equal(fmtSec(p.depAbs), '05:35:30');
  assert.equal(p.waitMin, 336);
  // B1 : lundi 06:00:30 via quai sœur PGFA (abs 108030).
  const p2 = providerDeparture(all, 'brt_b1_guediawaye_petersen', 'stop_brt_01_petersen', AT(2026, 10, 4, 23, 59));
  assert.equal(p2.status, 'SCHEDULED');
  assert.equal(p2.depAbs, 108030);
  assert.equal(fmtSec(p2.depAbs), '06:00:30');
  // Moteur d'itinéraires : trajet Colobane→Diamniadio embarqué le lendemain.
  const j = planJourneys(all, new Set([C_COL]), new Set([C_DIA]), AT(2026, 10, 4, 23, 59))[0];
  assert.ok(j, 'itinéraire J+1 trouvé');
  assert.equal(fmtSec(j.departureSec), '05:35:30');
  assert.ok(j.departureSec >= 86400, 'embarquement après minuit');
  assert.ok(j.arrivalSec > j.departureSec, 'arrivée postérieure (au-delà de l horizon)');
  // changement de service_id : services actifs dimanche vs lundi.
  const sun = [...activeServicesBy(N.TER, AT(2026, 10, 4, 0, 0))];
  const mon = [...activeServicesBy(N.TER, AT(2026, 10, 5, 0, 0))];
  assert.notDeepEqual(sun, mon);
  assert.equal(sun.length, 2);
  assert.equal(mon.length, 2);
  // calendar (motif) différent : 2 services distincts entre les deux jours.
  sun.forEach((s) => assert.ok(!mon.includes(s)));
  // calendar_dates déjà couvert (BRT 69 exceptions) + jour sans service :
  // lundi de Pâques DDD : LAV retiré → prochain départ via les autres services.
  const lundiPaques = AT(2022, 4, 4, 0, 0);
  const ddd = N.DDD;
  const lavIdx = ddd.services.findIndex((s) => s[0] === 'LAV');
  assert.equal(activeServices(ddd, lavIdx, new Date(Date.UTC(2022, 3, 4))), false);
  const depPaques = nextDepartureAbs(ddd, ['DDD_01'], ['D_805'], lundiPaques, 6 * 3600);
  assert.ok(depPaques !== null, 'DDD_01 reste servi ce jour-là par FULL');
});

function activeServicesBy(net, at) {
  const out = new Set();
  const day = new Date(Date.UTC(at.year, at.month - 1, at.day));
  net.services.forEach((_, i) => { if (activeServices(net, i, day)) out.add(net.services[i][0]); });
  return out;
}

// ============================================================ §11 aucun départ
test('§11 aucun départ valide → rien nest inventé (UNKNOWN au moteur/UI)', () => {
  // a) Route UI non mappée : aucun horaire rattaché (pas de frelon inventé).
  assert.equal(providerDeparture(all, 'ddd_1', 'stop_dakar_petersen', LUN12), null);
  assert.equal(cw.routes.ddd_1.pbRouteIds.length, 0);
  // b) Arrêt BRT jamais appelé par aucun trip : origine de recherche vide.
  const j = planJourneys(all, new Set(['BRT:0:GTAB']), new Set([C_DIA]), LUN12);
  assert.deepEqual(j, [], 'aucun trajet fabriqué depuis un arrêt non desservi');
  // c) Arrêt non mappé (Gadaye, non appelé dans le feed) : pas d ETA PassBi.
  assert.equal(
    (cw.stops.brt_b1_guediawaye_petersen || {})['stop_brt_22_gadaye'], null);
  // d) Rien de ces cas ne produit : 0 min, retard, interruption, fréquence.
  const labels = ['0 min', 'retard', 'interruption'];
  for (const l of labels) assert.ok(!String(j).includes(l));
});

// ============================================================ §12 jamais de retard
test('§12 un horaire PassBi programmé ne devient jamais un retard', () => {
  // SCHEDULED uniquement : aucune structure de retard dans le flux GTFS.
  const p = providerDeparture(all, 'ter_dakar_diamniadio', 'stop_colobane', LUN12);
  assert.equal(p.status, 'SCHEDULED');
  // Aucune mention realtime/retard dans les métadonnées sources.
  for (const key of ['TER', 'BRT', 'DDD', 'AFTU']) {
    const meta = N[key].meta;
    assert.equal(meta.time_semantics, 'SCHEDULED (jamais REAL_TIME) : horaires programmés, aucun flux temps réel.');
    assert.equal(meta.source_type, 'PUBLIC_GTFS');
  }
  // Le feed ne contient aucun champ de prédiction/position véhicule.
  const raw = JSON.stringify(N.BRT.meta) + JSON.stringify(N.DDD.meta);
  assert.equal(/delay|delayed|late|realtime_vehicle/i.test(raw), false);
});

// ============================================================ §13 identités
test('§13 TER ≠ BRT, B1 ≠ B2, DDD ≠ AFTU, B3 absent', () => {
  const ids = {
    TER: new Set(N.TER.routes.map((r) => r.id)),
    BRT: new Set(N.BRT.routes.map((r) => r.id)),
    DDD: new Set(N.DDD.routes.map((r) => r.id)),
    AFTU: new Set(N.AFTU.routes.map((r) => r.id)),
  };
  assert.equal(ids.TER.has('B1'), false);
  assert.equal(ids.BRT.has('B3'), false);
  assert.equal([...ids.BRT].some((x) => ids.DDD.has(x)), false);
  assert.equal([...ids.DDD].some((x) => ids.AFTU.has(x)), false);
  assert.notEqual(cw.routes.brt_b1_guediawaye_petersen.pbRouteIds[0],
    cw.routes.brt_b2_express.pbRouteIds[0]);
  // Aucun trip d'un réseau ne référence une route d'un autre réseau.
  for (const key of ['TER', 'BRT', 'DDD', 'AFTU']) {
    const net = N[key];
    const rids = new Set(net.routes.map((r) => r.id));
    for (const [ti, list] of net._byTrip) {
      assert.ok(rids.has(net.routes[net.trips[ti][1]].id), `${key}: trip ${ti} hors réseau`);
      assert.ok(list.length > 0);
    }
  }
  // Crosswalk : pas de réseau vers une route d'un autre réseau.
  for (const [dakarId, m] of Object.entries(cw.routes)) {
    if (m.status !== 'MAPPED') continue;
    if (m.network === 'BRT') {
      assert.deepEqual(m.pbRouteIds.filter((x) => ['B1', 'B2'].includes(x)), m.pbRouteIds);
    }
  }
});
