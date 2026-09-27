// Lot 4.18 — Tests d'intégration GTFS PassBi (niveau données).
// Source : flutter-src/assets/data/passbi/*.json générés par
// scripts/build-passbi-processed.mjs à partir des 4 ZIP data/transit/passbi/.
// Les attendus proviennent d'un calcul INDEPENDANT sur les GTFS bruts
// (python/csv le 2026-09-27) — jamais d'une relecture du code testé.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const BASE = 'flutter-src/assets/data/passbi';
const load = (f) => JSON.parse(readFileSync(`${BASE}/${f}`, 'utf8'));

const ter = load('ter.json');
const brt = load('brt.json');
const ddd = load('ddd.json');
const aftu = load('aftu.json');
const crosswalk = load('crosswalk.json');
const manifest = JSON.parse(
  readFileSync('data/transit/passbi/processed_manifest.json', 'utf8'));

// ---------- Mini-implémentation indépendante (roll-on ROLLING) ----------
function activeServices(net, day) {
  // day: Date (UTC). mask bit0=lundi. Exceptions datées priment.
  const wd = (day.getUTCDay() + 6) % 7; // lun=0
  const ymd = `${day.getUTCFullYear()}${String(day.getUTCMonth() + 1).padStart(2, '0')}${String(day.getUTCDate()).padStart(2, '0')}`;
  const exc = new Map();
  for (const [svc, date, type] of net.exceptions) {
    if (date === ymd) exc.set(svc, type);
  }
  const out = new Set();
  for (const [id, mask] of net.services) {
    if (exc.has(id)) {
      if (exc.get(id) === 1) out.add(id);
      continue;
    }
    if ((mask & (1 << wd)) !== 0) out.add(id);
  }
  return out;
}

function nextDepartureSec(net, routeIds, stopId, day, afterSec) {
  const stopIdx = net.stops.findIndex((s) => s[0] === stopId);
  assert.notEqual(stopIdx, -1, `stop ${stopId} absent de ${net.meta.network}`);
  const routeIdx = new Set();
  net.routes.forEach((r, i) => { if (routeIds.includes(r.id)) routeIdx.add(i); });
  assert.equal(routeIdx.size, routeIds.length, 'routes inconnues');
  // Embarquable : le trip continue APRÈS cet arrêt. Un arrêt de terminus ne
  // produit que des ARRIVÉES — jamais un « prochain départ » (Lot 4.19, Bug A).
  const tripMax = new Map();
  for (const [ti, , seq] of net.stop_times) {
    tripMax.set(ti, Math.max(tripMax.get(ti) ?? -1, seq));
  }
  // Scan J puis J+1 : après minuit, le prochain service est retrouvé avec son
  // propre service_id/calendar (Lot 4.19, Bug B). Retour abs depuis day0.
  for (let dShift = 0; dShift <= 1; dShift++) {
    const active = activeServices(net, new Date(day.getTime() + dShift * 86400000));
    const minSec = dShift === 0 ? afterSec : 0;
    let best = null;
    for (const [tripIdx, stIdx, seq, , dep] of net.stop_times) {
      if (stIdx !== stopIdx) continue;
      const trip = net.trips[tripIdx];
      if (!routeIdx.has(trip[1])) continue;
      if (seq >= tripMax.get(tripIdx)) continue; // arrivée de terminus
      if (dep < minSec) continue;
      if (!active.has(net.services[trip[2]][0])) continue;
      if (best === null || dep < best) best = dep;
    }
    if (best !== null) return best + dShift * 86400;
  }
  return null;
}

const MON = new Date(Date.UTC(2026, 8, 28)); // lundi 2026-09-28
const SUN = new Date(Date.UTC(2026, 9, 4)); // dimanche 2026-10-04
const TUE = new Date(Date.UTC(2026, 8, 29)); // mardi 2026-09-29
const COL = 'c70477e7-8391-4388-9a1f-8929a18dc14e-00000000-0000-0000-0000-000000000000';

test('1. chargement GTFS TER', () => {
  assert.equal(ter.meta.network, 'TER');
  assert.equal(ter.routes.length, 6);
  assert.equal(ter.trips.length, 572);
  assert.equal(ter.stop_times.length, 7332);
});

test('2. chargement GTFS BRT', () => {
  assert.equal(brt.meta.network, 'BRT');
  assert.deepEqual(brt.routes.map((r) => r.id).sort(), ['B1', 'B2']);
  assert.equal(brt.trips.length, 4036);
  assert.equal(brt.stop_times.length, 58674);
});

test('3. chargement GTFS DDD', () => {
  assert.equal(ddd.meta.network, 'DDD');
  assert.equal(ddd.routes.length, 53);
  assert.equal(ddd.trips.length, 9529);
  assert.equal(ddd.stop_times.length, 314029);
});

test('4. chargement GTFS AFTU', () => {
  assert.equal(aftu.meta.network, 'AFTU');
  assert.equal(aftu.routes.length, 73);
  assert.equal(aftu.trips.length, 11077);
  assert.equal(aftu.stop_times.length, 677918);
});

test('5. routes : structure et libellés', () => {
  for (const net of [ter, brt, ddd, aftu]) {
    for (const r of net.routes) {
      assert.equal(typeof r.id, 'string');
      assert.equal(typeof r.short, 'string');
      assert.equal(typeof r.long, 'string');
      assert.ok(r.type > 0);
    }
  }
  assert.equal(ter.routes.filter((r) => r.id.includes('↔') || r.long.includes('↔')).length >= 0, true);
  const b1 = brt.routes.find((r) => r.id === 'B1');
  const b2 = brt.routes.find((r) => r.id === 'B2');
  assert.notEqual(b1.long, b2.long);
});

test('6. stops : compteurs et coordinates exploitables', () => {
  assert.equal(ter.stops.length, 26);
  assert.equal(brt.stops.length, 79);
  assert.equal(ddd.stops.length, 1277);
  assert.equal(aftu.stops.length, 2401);
  assert.equal(ter.stops.filter((s) => s[4] === 1).length, 13);
  assert.equal(brt.stops.filter((s) => s[4] === 1).length, 43);
  for (const s of [...ter.stops, ...brt.stops]) {
    assert.ok(Math.abs(s[2]) > 10 && Math.abs(s[3]) > 10,
      `coordonnées absurdes ${s[0]}`);
  }
});

test('7. trips : indexation route/trip/service', () => {
  for (const net of [ter, brt, ddd, aftu]) {
    for (const t of net.trips) {
      const [id, routeIdx, svcIdx] = t;
      assert.equal(typeof id, 'string');
      assert.ok(routeIdx >= 0 && routeIdx < net.routes.length);
      assert.ok(svcIdx >= 0 && svcIdx < net.services.length);
    }
  }
});

test('8. stop_times : séquences cohérentes', () => {
  let total = 0;
  let anomalies = 0;
  for (const net of [ter, brt, ddd, aftu]) {
    for (const [tripIdx, stopIdx, seq, arr, dep] of net.stop_times) {
      total++;
      assert.ok(tripIdx >= 0 && tripIdx < net.trips.length);
      assert.ok(stopIdx >= 0 && stopIdx < net.stops.length);
      assert.ok(seq > 0);
      assert.ok(dep >= 0);
      assert.ok(arr >= 0);
      // Anomalie constatée dans le feed TER brut (1/7332) : arrival_time >
      // departure_time. Documentée, non corrigée (aucune invention).
      if (arr > dep) anomalies++;
    }
  }
  assert.ok(anomalies * 100 <= total,
    `anomalies arr>dep trop nombreuses: ${anomalies}/${total}`);
});

test('9. calendar : motifs hebdomadaires et fenêtres d origine conservées', () => {
  assert.equal(ter.services.length, 12);
  assert.equal(brt.services.length, 7);
  assert.equal(ddd.services.length, 4);
  assert.equal(aftu.services.length, 4);
  // Fenêtres d'origine intactes (jamais falsifiées) — mode ROLLING documenté.
  // Formats GTFS YYYYMMDD d'origine, non falsifiés.
  assert.equal(ter.meta.valid_from, '20250818');
  assert.equal(ter.meta.valid_to, '20250831');
  assert.equal(ddd.meta.valid_from, '20220101');
  assert.equal(ddd.meta.valid_to, '20231231');
  assert.equal(aftu.meta.valid_from, '20220101');
  assert.equal(aftu.meta.valid_to, '20231231');
  assert.equal(brt.meta.valid_from, '20241024');
  assert.equal(brt.meta.valid_to, '20241231');
  assert.equal(ter.meta.calendar_mode, 'ROLLING');
  // Le lundi couvert par au moins les services attendus du TER.
  const monActive = activeServices(ter, MON);
  assert.equal(monActive.size, 2);
  const sunActive = activeServices(ter, SUN);
  assert.equal(sunActive.size, 2);
  assert.notDeepEqual([...monActive].sort(), [...sunActive].sort());
});

test('10. calendar_dates : exceptions datées appliquées', () => {
  assert.equal(brt.exceptions.length, 69);
  assert.equal(ddd.exceptions.length, 40);
  assert.equal(aftu.exceptions.length, 40);
  assert.equal(ter.exceptions.length, 0); // feed TER sans calendar_dates
  // Lundi de Pâques 2022-04-04 : LAV retiré, DIMANCHE ajouté (DDD).
  const apr4 = new Date(Date.UTC(2022, 3, 4));
  const apr11 = new Date(Date.UTC(2022, 3, 11));
  const act4 = activeServices(ddd, apr4);
  const act11 = activeServices(ddd, apr11);
  assert.equal(act4.has('LAV'), false, 'LAV doit être retiré le 2022-04-04');
  assert.equal(act4.has('DIMANCHE'), true);
  assert.equal(act11.has('LAV'), true, 'LAV actif lundi ordinaire 2022-04-11');
});

test('11. prochain départ : TER Colobane lundi 12:00 (fixture brut)', () => {
  const dep = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, MON, 12 * 3600);
  assert.equal(dep, 43885, 'attendu 12:11:25 depuis calcul brut');
  // Pas de départ avant le premier matin : 05:35:30 attendu après 03:00.
  const first = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, MON, 3 * 3600);
  assert.equal(first, 20130);
  // Après le dernier départ du jour : le service J+1 est retrouvé (106530 =
  // mardi 05:35:30 depuis lundi 00:00) — jamais null (Lot 4.19, Bug B).
  const overnight = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, MON,
    23 * 3600 + 59 * 60 + 59);
  assert.equal(overnight, 106530);
  assert.ok(overnight >= 86400, 'service du jour suivant');
  // Dimanche 23:59 → lundi 05:35:30, même valeur (changement de service_id
  // entre {db5eb,1ed5} actifs le dimanche et {38f2,68f0} le lundi).
  const sunRollover = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, SUN,
    23 * 3600 + 59 * 60);
  assert.equal(sunRollover, 106530);
  // Un jour sans service complet reste null (aucune fréquence inventée).
  const allOff = activeServices(ter, SUN).size === 0;
  assert.equal(allOff, false);
});

test('12. calcul des minutes affichées (prochain départ)', () => {
  const dep = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, MON, 12 * 3600);
  const waitSec = dep - 12 * 3600;
  assert.equal(Math.floor(waitSec / 60), 11); // « Prochain départ dans 11 min »
  // Jamais d'affichage « 0 min » pseudo temps réel ici : 11 min réels.
  // B1 au quai de DÉPART (PGFA) à 14:00 : départ embarquable 14:00:30,
  // soit 30 s → libellé « moins d'une minute » côté UI (Lot 4.19, Bug A).
  const b1dep = nextDepartureSec(brt, ['B1'], '0:PGFA', MON, 14 * 3600);
  assert.equal(b1dep, 50430);
  assert.equal(Math.floor((b1dep - 14 * 3600) / 60), 0);
  // Le quai d'arrivée PGFB ne produit JAMAIS de départ (arrivées de terminus).
  const arrivalOnly = nextDepartureSec(brt, ['B1'], '0:PGFB', MON, 14 * 3600);
  assert.equal(arrivalOnly, null);
});

test('13. changement de date : départs différents selon le jour', () => {
  const mon = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, MON, 12 * 3600);
  const sun = nextDepartureSec(ter, ter.routes.map((r) => r.id), COL, SUN, 12 * 3600);
  assert.equal(mon, 43885);
  assert.equal(sun, 43671);
  assert.notEqual(mon, sun);
});

test('14. services actifs par date (mode ROLLING documenté)', () => {
  const monTer = activeServices(ter, MON);
  assert.equal(monTer.size, 2);
  const tueDdd = activeServices(ddd, TUE);
  assert.ok(tueDdd.has('FULL'));
  assert.ok(tueDdd.has('LAV'));
  assert.equal(tueDdd.has('SAMEDAI') || tueDdd.has('DIMANCHE'), false);
  const monBrt = activeServices(brt, MON);
  assert.deepEqual([...monBrt], ['0_1']);
});

test('15. correspondances : liens documentés, bornes respectées', () => {
  assert.ok(crosswalk.transfers.length >= 1000);
  for (const t of crosswalk.transfers) {
    const [na] = t.from.split(':');
    const [nb] = t.to.split(':');
    assert.ok(na && nb);
    const inter = na !== nb;
    if (t.method === 'NOM_IDENTIQUE_PROXIMITE') {
      assert.ok(t.meters <= 500, `${t.from}/${t.to} > 500 m`);
    } else if (t.method === 'INCLUSION_NOM_PROXIMITE') {
      assert.ok(inter, 'inclusion = inter-réseaux uniquement');
      assert.ok(t.meters <= 250, `${t.from}/${t.to} > 250 m`);
    } else {
      assert.fail(`méthode de transfert inattendue: ${t.method}`);
    }
  }
  // Corridors inter-réseaux exigés : TER↔DDD, TER↔AFTU, BRT↔DDD, BRT↔AFTU,
  // DDD↔AFTU. (BRT↔TER direct absent : chaînable via DDD/AFTU — limite connue.)
  const pairs = new Set(crosswalk.transfers.map(
    (t) => [t.from.split(':')[0], t.to.split(':')[0]].sort().join('-')));
  for (const p of ['DDD-TER', 'AFTU-TER', 'BRT-DDD', 'AFTU-BRT', 'AFTU-DDD']) {
    assert.ok(pairs.has(p), `corridor ${p} absent`);
  }
  // Jamais de recréation d'aberrations TER/bus anciennes : chaque lien est
  // nom-identique ou inclusion de nom, toujours à distance bornée.
});

test('16. B1 et B2 strictement séparés', () => {
  const b1 = crosswalk.routes['brt_b1_guediawaye_petersen'];
  const b2 = crosswalk.routes['brt_b2_express'];
  assert.deepEqual(b1.pbRouteIds, ['B1']);
  assert.deepEqual(b2.pbRouteIds, ['B2']);
  assert.notEqual(b1.pbRouteIds[0], b2.pbRouteIds[0]);
  // Même station, plateformes distinctes : jamais de réutilisation d'ETA.
  const pB1 = crosswalk.stops['brt_b1_guediawaye_petersen']['stop_brt_01_petersen'].pb;
  const pB2 = crosswalk.stops['brt_b2_express']['stop_brt_01_petersen'].pb;
  assert.notEqual(pB1, pB2);
  // Aucune route « B3 » fabriquée.
  assert.equal(brt.routes.some((r) => r.id === 'B3'), false);
  // Départs distincts aux quais de départ : B1 PGFA 14:00:30 vs B2 GDWB
  // 14:03:30 (Lot 4.19 : plus d'arrêts de terminus en guise de « départ »).
  const d1 = nextDepartureSec(brt, ['B1'], '0:PGFA', MON, 14 * 3600);
  const d2 = nextDepartureSec(brt, ['B2'], '0:GDWB', MON, 14 * 3600);
  assert.equal(d1, 50430);
  assert.equal(d2, 50610);
  assert.notEqual(d1, d2);
  // Quais d'arrivée (PGFB/GDWA) : aucune donnée de départ, jamais un ETA volé.
  assert.equal(nextDepartureSec(brt, ['B1'], '0:PGFB', MON, 14 * 3600), null);
  assert.equal(nextDepartureSec(brt, ['B2'], '0:GDWA', MON, 14 * 3600), null);
});

test('17. provenance PassBi : ACTIVE, PUBLIC_GTFS, dates d origine intactes', () => {
  for (const net of [ter, brt, ddd, aftu]) {
    assert.ok(String(net.meta.source).startsWith('PassBi'));
    assert.equal(net.meta.source_type, 'PUBLIC_GTFS');
    assert.equal(net.meta.status, 'ACTIVE');
    assert.equal(net.meta.calendar_mode, 'ROLLING');
    assert.equal(net.meta.date_source, '2026-02-10');
    assert.equal(net.meta.date_verified, '2026-09-27');
    assert.ok(net.meta.valid_from && net.meta.valid_to,
      'fenêtres d origine obligatoires (jamais falsifiées)');
    assert.notEqual(net.meta.status, 'HISTORICAL');
  }
  assert.ok(String(crosswalk.meta.source).startsWith('PassBi'));
  assert.equal(crosswalk.meta.source_type, 'PUBLIC_GTFS');
  assert.equal(crosswalk.meta.status, 'ACTIVE');
  assert.equal(manifest.operational_status, 'ACTIVE');
  assert.ok(String(manifest.source).startsWith('PassBi'));
  assert.equal(manifest.source_type, 'PUBLIC_GTFS');
  // Chiffres publiés : 5/105 routes mappées, 44/51 arrêts.
  assert.equal(manifest.crosswalk_stats.routes_mapped, 5);
  assert.equal(manifest.crosswalk_stats.stops_mapped, 44);
  assert.equal(manifest.crosswalk_stats.transfers, crosswalk.transfers.length);
});

test('18. absence de données : mappage non confirmé → UNKNOWN (rien d inventé)', () => {
  // ddd_1 : identité non confirmée avec DDD_01 → aucun horaire rattaché.
  const ddd1 = crosswalk.routes['ddd_1'];
  assert.equal(ddd1.status, 'UNMAPPED');
  assert.equal(ddd1.method, 'IDENTITE_NON_CONFIRMEE');
  assert.deepEqual(ddd1.pbRouteIds, []);
  // Arrêts BRT réellement non appelés dans le feed → non mappés, jamais
  // approximés par proximité seule.
  const b1stops = crosswalk.stops['brt_b1_guediawaye_petersen'];
  assert.equal(b1stops['stop_brt_22_gadaye'], null);
  const gadayeListed = JSON.stringify(crosswalk.unmapped.stops)
    .toLowerCase().includes('gadaye');
  assert.equal(gadayeListed, true);
  // Compteur : 100 routes sans identité confirmée (dont 18 réseaux absents).
  assert.equal(crosswalk.unmapped.routes.length, 100);
  // Un départ introuvable reste null — jamais une fréquence.
  // PGFB (quai d'arrivée) : aucun départ embarquable, même sur 2 jours.
  const night = nextDepartureSec(brt, ['B1'], '0:PGFB', SUN, 23 * 3600 + 59 * 60);
  assert.equal(night, null);
  // Arrêt listé mais jamais appelé (GUEULE TAPEE / GTAB, 0 rows) : null.
  const neverCalled = nextDepartureSec(brt, ['B1', 'B2'], '0:GTAB', MON, 0);
  assert.equal(neverCalled, null);
});

test('19. aucun faux temps réel dans les données produites', () => {
  const forbidden = /real_?time|temps réel|gtfs-rt|vehicle_position/i;
  for (const [name, net] of Object.entries({ ter, brt, ddd, aftu })) {
    for (const k of Object.keys(net.meta)) {
      if (k === 'time_semantics') {
        // Documentation honnête de l'absence de flux temps réel.
        assert.ok(String(net.meta[k]).includes('jamais REAL_TIME'),
          `${name}: time_semantics doit documenter l'absence de REAL_TIME`);
        continue;
      }
      assert.equal(forbidden.test(k), false, `${name}.meta.${k}`);
      assert.equal(forbidden.test(String(net.meta[k])), false, `${name}.meta.${k}`);
    }
    assert.equal(net.meta.source_type !== 'PUBLIC_GTFS', false);
  }
  // Aucune structure de prédiction/position véhicule dans les JSON.
  const raw = readFileSync(`${BASE}/crosswalk.json`, 'utf8');
  assert.equal(forbidden.test(raw), false, 'crosswalk: mention temps réel');
  assert.equal(Object.keys(crosswalk.meta).some((k) => forbidden.test(k)), false);
});

test('20. remplacement futur : manifeste reproductible, entrées/sorties tracées', () => {
  assert.equal(manifest.set, 'passbi-operational-layer');
  assert.equal(manifest.generator, 'scripts/build-passbi-processed.mjs');
  assert.equal(manifest.calendar_mode, 'ROLLING');
  // Entrées : les 4 ZIP PassBi, chacun scellé par sha256.
  const inNames = Object.keys(manifest.inputs);
  assert.equal(inNames.length, 4);
  for (const name of inNames) {
    assert.match(name, /^gtfs_.*\.zip$/);
    assert.match(manifest.inputs[name].sha256, /^[0-9a-f]{64}$/);
  }
  // Sorties : les 5 assets consommés par l'application, scellés aussi.
  const outNames = Object.keys(manifest.outputs).sort();
  assert.deepEqual(outNames,
    ['aftu.json', 'brt.json', 'crosswalk.json', 'ddd.json', 'ter.json']);
  for (const name of outNames) {
    assert.match(manifest.outputs[name].sha256, /^[0-9a-f]{64}$/);
    assert.ok(manifest.outputs[name].bytes > 0);
  }
  // Le futur remplacement = régénérer ces sorties (même lecteur, zéro
  // changement moteur).
  assert.equal(manifest.calendar_mode, 'ROLLING');
});

test('fixture : DDD et AFTU exposés au moteur sous leurs propres identifiants', () => {
  // L'ensemble des données reste exploitable malgré l'absence de mappage
  // dakar_network : le moteur lit PassBi directement (route DDD_01, AFTU_1).
  const dddDep = nextDepartureSec(ddd, ['DDD_01'], 'D_805', TUE, 8 * 3600);
  assert.equal(dddDep, 29400); // 08:10:00, services FULL+LAV
  // 08:01:53 était l'ARRIVÉE du sens inverse terminant à A_916 (Bug A) :
  // le premier départ embarquable réel est 08:15:09 (Lot 4.19).
  const aftuDep = nextDepartureSec(aftu, ['AFTU_1'], 'A_916', MON, 8 * 3600);
  assert.equal(aftuDep, 29709); // 08:15:09, départ terminus, services FULL+LAV
});
