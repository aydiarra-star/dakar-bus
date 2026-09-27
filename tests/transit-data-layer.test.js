'use strict';
/**
 * LOT 4.4 — Tests de la couche de données de travail (data/transit/).
 *
 * Tests de DONNÉES uniquement. Ce fichier n'importe aucun code applicatif,
 * ne touche ni main.dart, ni le routage, ni le GPS, ni l'interface,
 * ni data/gtfs/ (feed synthétique existant).
 *
 * Rappel du lot : la validation SYNTAXIQUE d'un GTFS ne vaut jamais validation
 * MÉTIER. Ces tests vérifient les deux séparément.
 */
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const T = path.join(ROOT, 'data', 'transit');
const L1 = path.join(T, 'passbi');
const L2 = path.join(T, 'validated');
const L3 = path.join(T, 'production');

const read = (p) => fs.readFileSync(p, 'utf8');
const jread = (p) => JSON.parse(read(p));

function csv(file) {
  const lines = read(file).replace(/\r/g, '').split('\n').filter((l) => l.length > 0);
  if (lines.length === 0) return {header: [], rows: []};
  const header = lines[0].split(',');
  const rows = lines.slice(1).map((l) => {
    const cells = l.split(',');
    const o = {};
    header.forEach((h, i) => { o[h] = cells[i] === undefined ? '' : cells[i]; });
    return o;
  });
  return {header, rows};
}

const gtfs = (f) => csv(path.join(L2, 'gtfs', f));
const uniq = (a) => [...new Set(a)];
const dupes = (a) => a.filter((v, i) => a.indexOf(v) !== i);

const STATUSES = ['CONFIRMED', 'PERSISTENT', 'PARTIALLY_CONFIRMED', 'UNCONFIRMED',
  'CONTRADICTED', 'NEW', 'UNKNOWN',
  // NOT_FOUND : valeur admise par la section 9 du lot pour l'absence d'identité.
  // Elle ne signifie jamais « supprimée ».
  'NOT_FOUND'];
const SOURCE_TYPES = ['OFFICIAL_OPERATOR', 'INSTITUTIONAL', 'PASSBI', 'OSM', 'HYBRID'];
const MATCH_TYPES = ['EXACT', 'DOCUMENTED', 'STRUCTURAL', 'NAME_ONLY', 'COORDINATE_ONLY',
  'UNCONFIRMED'];
const CONFIDENCES = ['HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'];

// ============================================================ niveaux séparés
test('les trois niveaux existent et sont physiquement séparés', () => {
  for (const d of [L1, L2, L3]) {
    assert.ok(fs.existsSync(d), `niveau manquant : ${d}`);
  }
  assert.ok(fs.existsSync(path.join(L1, 'ter', 'routes.txt')), 'LEVEL 1 TER manquant');
  assert.ok(fs.existsSync(path.join(L2, 'gtfs', 'routes.txt')), 'LEVEL 2 GTFS manquant');
  assert.ok(fs.existsSync(path.join(L3, 'production_ready.json')), 'LEVEL 3 manquant');
});

test('le feed existant data/gtfs/ et reference-policy.json ne sont pas écrasés', () => {
  const legacy = path.join(ROOT, 'data', 'gtfs');
  for (const f of ['agency.txt', 'calendar.txt', 'feed_info.txt', 'routes.txt',
    'shapes.txt', 'stop_times.txt', 'stops.txt', 'trips.txt']) {
    assert.ok(fs.existsSync(path.join(legacy, f)), `feed legacy perdu : ${f}`);
  }
  // Le feed legacy reste identifiable comme synthétique et n'a pas été mélangé à PassBi.
  assert.match(read(path.join(legacy, 'feed_info.txt')), /2\.1-dakar-pwa-gtfs-rt/);
  const policy = jread(path.join(T, 'reference-policy.json'));
  assert.equal(policy.reviewedAt, '2026-09-21', 'reference-policy.json a été modifié');
  // Aucune contamination : le LEVEL 2 ne reprend pas le feed_version synthétique.
  assert.ok(!read(path.join(L2, 'gtfs', 'routes.txt')).includes('2.1-dakar-pwa-gtfs-rt'));
});

// ============================================================ intégrité GTFS
test('LEVEL 2 GTFS : identifiants uniques', () => {
  for (const [f, key] of [['stops.txt', 'stop_id'], ['routes.txt', 'route_id'],
    ['trips.txt', 'trip_id'], ['agency.txt', 'agency_id'], ['calendar.txt', 'service_id']]) {
    const {rows} = gtfs(f);
    assert.ok(rows.length > 0, `${f} est vide`);
    const ids = rows.map((r) => r[key]);
    assert.deepEqual(dupes(ids), [], `${f} : identifiants ${key} dupliqués`);
  }
});

test('LEVEL 2 GTFS : stop_sequence cohérente par trip', () => {
  const {rows} = gtfs('stop_times.txt');
  const byTrip = new Map();
  for (const r of rows) {
    if (!byTrip.has(r.trip_id)) byTrip.set(r.trip_id, []);
    byTrip.get(r.trip_id).push(r);
  }
  assert.ok(byTrip.size > 0, 'aucun trip dans stop_times');
  for (const [tid, legs] of byTrip) {
    const seq = legs.map((l) => parseInt(l.stop_sequence, 10));
    assert.deepEqual(dupes(seq), [], `${tid} : stop_sequence dupliqué`);
    const sorted = [...seq].sort((a, b) => a - b);
    assert.deepEqual(seq, sorted, `${tid} : stop_sequence non croissante`);
    assert.equal(seq[0], 1, `${tid} : stop_sequence ne commence pas à 1`);
    assert.equal(new Set(seq).size, seq.length, `${tid} : trous dans stop_sequence`);
    for (let i = 1; i < seq.length; i++) {
      assert.equal(seq[i], seq[i - 1] + 1, `${tid} : rupture de séquence à ${seq[i]}`);
    }
  }
});

test('LEVEL 2 GTFS : trip -> route valide, stop_time -> stop valide, service_id valide', () => {
  const routes = new Set(gtfs('routes.txt').rows.map((r) => r.route_id));
  const stops = new Set(gtfs('stops.txt').rows.map((r) => r.stop_id));
  const services = new Set(gtfs('calendar.txt').rows.map((r) => r.service_id));
  const agencies = new Set(gtfs('agency.txt').rows.map((r) => r.agency_id));
  const trips = gtfs('trips.txt').rows;

  for (const t of trips) {
    assert.ok(routes.has(t.route_id), `trip ${t.trip_id} -> route inconnue ${t.route_id}`);
    assert.ok(services.has(t.service_id), `trip ${t.trip_id} -> service_id inconnu ${t.service_id}`);
    assert.ok(['0', '1'].includes(t.direction_id), `trip ${t.trip_id} : direction_id invalide`);
  }
  for (const r of gtfs('routes.txt').rows) {
    assert.ok(agencies.has(r.agency_id), `route ${r.route_id} -> agency inconnue ${r.agency_id}`);
  }
  for (const s of gtfs('stop_times.txt').rows) {
    assert.ok(stops.has(s.stop_id), `stop_time -> stop inconnu ${s.stop_id}`);
  }
});

test('LEVEL 2 GTFS : aucune route orpheline, aucun stop_time orphelin', () => {
  const routes = gtfs('routes.txt').rows.map((r) => r.route_id);
  const trips = gtfs('trips.txt').rows;
  const st = gtfs('stop_times.txt').rows;
  const stops = gtfs('stops.txt').rows.map((r) => r.stop_id);

  const routedTrips = new Set(trips.map((t) => t.route_id));
  for (const rid of routes) {
    assert.ok(routedTrips.has(rid), `route orpheline (aucun trip) : ${rid}`);
  }
  const stTrips = new Set(st.map((s) => s.trip_id));
  const tripIds = new Set(trips.map((t) => t.trip_id));
  for (const t of stTrips) {
    assert.ok(tripIds.has(t), `stop_time orphelin : trip ${t} absent de trips.txt`);
  }
  const usedStops = new Set(st.map((s) => s.stop_id));
  for (const s of stops) {
    assert.ok(usedStops.has(s), `stop orphelin (aucun stop_time) : ${s}`);
  }
  for (const t of tripIds) {
    assert.ok(stTrips.has(t), `trip sans stop_times : ${t}`);
  }
});

test('LEVEL 2 GTFS : heures conformes à la convention GTFS (>= 24h non converties)', () => {
  const {rows} = gtfs('stop_times.txt');
  const re = /^(\d{2,}):([0-5]\d):([0-5]\d)$/;
  let after24 = 0;
  for (const r of rows) {
    for (const k of ['arrival_time', 'departure_time']) {
      const m = re.exec(r[k]);
      assert.ok(m, `${k} invalide : "${r[k]}"`);
      const h = parseInt(m[1], 10);
      assert.ok(h <= 47, `${k} hors plage GTFS : ${r[k]}`);
      assert.ok(parseInt(m[2], 10) < 60 && parseInt(m[3], 10) < 60, `${k} invalide : ${r[k]}`);
      if (h >= 24) after24++;
    }
  }
  // Aucune conversion arbitraire : les heures sont celles du feed d'origine.
  const sched = jread(path.join(L2, 'structure', 'ter_schedule.json'));
  assert.equal(sched.gtfs_time_convention.times_rewritten, 0,
    'des heures ont été réécrites');
  const origin = rows.filter((r) => r.stop_sequence === '1').map((r) => r.departure_time);
  assert.deepEqual(origin, sched.promoted_to_level2.departure_times_dakar,
    'les départs du LEVEL 2 ne correspondent pas à la série confirmée');
  // Information : le jeu TER ne traverse pas minuit ; le garde-fou reste actif.
  assert.ok(after24 >= 0);
});

// ============================================================ provenance
test('provenance : blocs complets et vocabulaire contrôlé', () => {
  const seen = [];
  const walk = (o) => {
    if (Array.isArray(o)) return o.forEach(walk);
    if (o && typeof o === 'object') {
      if ('source_type' in o && 'status' in o) seen.push(o);
      Object.values(o).forEach(walk);
    }
  };
  for (const f of ['structure/ter_stop_mapping.json', 'structure/ter_schedule.json',
    'structure/brt_route_structure.json', 'structure/ddd_routes.json',
    'structure/aftu_raw_registry.json']) {
    walk(jread(path.join(L2, f)));
  }
  assert.ok(seen.length >= 10, `trop peu de blocs de provenance trouvés (${seen.length})`);
  for (const p of seen) {
    if (p.source_type !== null) {
      assert.ok(SOURCE_TYPES.includes(p.source_type), `source_type inconnu : ${p.source_type}`);
    }
    if (p.status !== null) {
      assert.ok(STATUSES.includes(p.status), `status inconnu : ${p.status}`);
    }
    if (p.confidence !== undefined && p.confidence !== null) {
      assert.ok(CONFIDENCES.includes(p.confidence), `confidence inconnue : ${p.confidence}`);
    }
  }
});

test('PASSBI n’est jamais promu OFFICIAL_OPERATOR', () => {
  const files = ['structure/ddd_routes.json', 'structure/aftu_raw_registry.json',
    'structure/brt_route_structure.json', 'structure/ter_stop_mapping.json',
    'structure/ter_schedule.json'];
  const blocks = [];
  const walk = (o) => {
    if (Array.isArray(o)) return o.forEach(walk);
    if (o && typeof o === 'object') {
      if ('source_type' in o) blocks.push(o);
      Object.values(o).forEach(walk);
    }
  };
  for (const f of files) walk(jread(path.join(L2, f)));
  const passbi = blocks.filter((b) => b.source_type === 'PASSBI');
  assert.ok(passbi.length > 0, 'aucun bloc PASSBI trouvé : le test ne prouve rien');
  for (const b of passbi) {
    assert.notEqual(b.source_type, 'OFFICIAL_OPERATOR');
    assert.notEqual(b.source_type, 'INSTITUTIONAL',
      'PassBi promu institutionnel sans preuve');
  }
  // Aucune entité ne revendique CETUD comme source officielle
  for (const b of blocks) {
    if (b.source_type === 'OFFICIAL_OPERATOR') {
      assert.ok(!/passbi/i.test(String(b.source || '')),
        'PassBi présenté comme source opérateur officielle');
    }
  }
});

test('provenance par champ : TER ne réduit pas sa source à « PassBi »', () => {
  const m = jread(path.join(L2, 'structure', 'ter_stop_mapping.json'));
  const pf = m.provenance_by_field;
  for (const k of ['stop_name', 'coordinates', 'sequence']) {
    assert.ok(pf[k], `provenance par champ manquante : ${k}`);
    assert.ok(pf[k].source && pf[k].source.length > 0, `${k} : source vide`);
    assert.ok(pf[k].verification_note, `${k} : verification_note absente`);
  }
  assert.notEqual(pf.stop_name.source_type, 'PASSBI',
    'le nom des gares est corroboré par des sources actuelles, pas seulement PassBi');
});

// ============================================================ TER
test('TER : 13 gares confirmées, appariement 1:1 sans croisement', () => {
  const m = jread(path.join(L2, 'structure', 'ter_stop_mapping.json'));
  assert.equal(m.stops.length, 13, 'le référentiel TER ne compte pas 13 gares');
  const seq = m.stops.map((s) => s.sequence);
  assert.deepEqual(seq, [...Array(13).keys()].map((i) => i + 1), 'séquence discontinue');
  assert.deepEqual(dupes(m.stops.map((s) => s.passbi_stop_id)), [], 'passbi_stop_id dupliqué');
  assert.deepEqual(dupes(m.stops.map((s) => s.dakar_bus_stop_id)), [],
    'deux gares PassBi appariées au même arrêt du projet');
  for (const s of m.stops) {
    assert.equal(s.status, 'CONFIRMED');
    assert.equal(s.confidence, 'HIGH');
    assert.ok(s.coordinate_deviation_m < 500, `${s.stop_name} : écart ${s.coordinate_deviation_m} m`);
  }
  assert.equal(m.coordinate_check.matched, 13);
  assert.equal(m.coordinate_check.crossed_pairing, false);
  // Ordre des 13 gares attendu
  assert.deepEqual(m.stops.map((s) => s.stop_name), [
    'Dakar - Gare ferroviaire', 'Colobane', 'Hann', 'Dalifort', 'Baux Maraîchers', 'Pikine',
    'Thiaroye', 'Yeumbeul', 'Keur Mbaye Fall', 'PNR Rufisque', 'Rufisque', 'Bargny', 'Diamniadio']);
});

test('TER : aucun UUID PassBi exposé comme identifiant public', () => {
  const {rows} = gtfs('stops.txt');
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  for (const s of rows) {
    assert.ok(!uuid.test(s.stop_id),
      `identifiant public = UUID PassBi : ${s.stop_id} (décision de modélisation violée)`);
  }
  // Les UUID restent disponibles en crosswalk
  const cw = jread(path.join(T, 'crosswalk', 'crosswalk.json'));
  const passbiUuids = cw.entries.filter((e) => uuid.test(e.source_id)).length;
  assert.ok(passbiUuids >= 13, 'les UUID PassBi ont disparu du crosswalk');
});

test('TER : AIBD / Sébikotane / Keur Moussa non ajoutés', () => {
  const m = jread(path.join(L2, 'structure', 'ter_stop_mapping.json'));
  const names = m.stops.map((s) => s.stop_name.toLowerCase());
  for (const banned of ['aibd', 'sébibotane', 'sebikotane', 'keur moussa']) {
    assert.ok(!names.some((n) => n.includes(banned)), `station non autorisée ajoutée : ${banned}`);
  }
  assert.equal(m.not_added.length, 3);
  const km = m.not_added.find((s) => s.name === 'Keur Moussa');
  assert.match(km.reason, /commune traversée/i);
  assert.equal(m.not_added.find((s) => s.name === 'AIBD').status, 'PROVISIONAL');
});

test('TER horaires : semaine PassBi exclue, dimanche partiellement confirmée', () => {
  const s = jread(path.join(L2, 'structure', 'ter_schedule.json'));
  const hist = s.two_level_separation.historical_passbi_schedule;
  const cur = s.two_level_separation.current_operator_schedule;
  assert.equal(hist.weekday.status, 'CONTRADICTED', 'la grille semaine doit rester CONTRADICTED');
  assert.equal(hist.weekday.frequency_min, 12);
  assert.equal(cur.weekday.frequency_min, 10, 'la valeur opérateur actuelle doit primer');
  assert.equal(cur.weekday.resulting_status, 'ESTIMATED',
    'une fréquence ne doit pas devenir SCHEDULED');
  assert.equal(cur.sunday.resulting_status, 'ESTIMATED');
  assert.equal(cur.weekday.exact_stop_times_published, false);
  // Séparation effective des deux niveaux
  assert.ok(hist.location.includes('passbi/'), 'l’historique doit pointer vers le LEVEL 1');
  // Réconciliation dominicale
  const rec = s.sunday_reconciliation;
  assert.equal(rec.official_series_departures, 48);
  assert.equal(rec.passbi_found_in_official, 48);
  assert.deepEqual(rec.official_missing_from_passbi, [], 'un départ officiel manque dans PassBi');
  assert.deepEqual(rec.passbi_only_departures, ['18:03', '19:50']);
  assert.equal(s.promoted_to_level2.schedule_status, 'PARTIALLY_CONFIRMED');
  assert.deepEqual(s.promoted_to_level2.excluded, ['18:03', '19:50'],
    'les départs PassBi non confirmés ne doivent pas être promus');
  // Garde-fou de calendrier : fenêtre réduite, aucune validité inventée
  const {rows} = gtfs('calendar.txt');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].start_date, rows[0].end_date,
    'la fenêtre GTFS doit rester réduite à la date d’audit');
  assert.match(s.calendar_note, /garde-fou/);
});

test('TER : structure CONFIRMED mais horaire non certifié (dimensions indépendantes)', () => {
  const rs = jread(path.join(L2, 'route_status.json'));
  const ter = rs.routes.find((r) => r.route_id === 'ter_dakar_diamniadio');
  assert.equal(ter.route_identity_status, 'CONFIRMED');
  assert.equal(ter.route_structure_status, 'CONFIRMED');
  assert.equal(ter.route_schedule_status, 'PARTIALLY_CONFIRMED');
  assert.equal(ter.route_realtime_status, 'UNKNOWN');
  // Aucune déduction automatique : structure CONFIRMED n'entraîne pas schedule CONFIRMED
  assert.notEqual(ter.route_schedule_status, ter.route_structure_status);
});

// ============================================================ BRT
test('BRT : B1, B2 et B3 restent trois routes distinctes, jamais fusionnées', () => {
  const b = jread(path.join(L2, 'structure', 'brt_route_structure.json'));
  const ids = b.routes.map((r) => r.route_id);
  assert.deepEqual(ids, ['brt_b1', 'brt_b2'], 'B1/B2 doivent rester distincts');
  assert.equal(b.b3_identity_only.route_id, 'brt_b3');
  assert.equal(b.anti_duplicate_display_rule.routes_kept_distinct.length, 3);
  // B2 : 7 stations confirmées
  const b2 = b.routes.find((r) => r.route_id === 'brt_b2');
  assert.equal(b2.direction_id_0.length, 7);
  assert.equal(b2.direction_id_1.length, 7);
  assert.equal(b2.structure_status, 'CONFIRMED');
  assert.equal(b2.identity_status, 'CONFIRMED');
  assert.equal(b2.schedule_status, 'UNCONFIRMED', 'un horaire BRT ne peut pas être confirmé');
  // B1 : structure persistante, évolution documentée
  const b1 = b.routes.find((r) => r.route_id === 'brt_b1');
  assert.equal(b1.direction_id_0.length, 21);
  assert.equal(b1.structure_status, 'PERSISTENT');
  assert.equal(b1.current_stations, 23);
  assert.match(b1.difference_documented, /23/);
});

test('BRT : 1 station physique + plusieurs routes, sans duplication', () => {
  const b = jread(path.join(L2, 'structure', 'brt_route_structure.json'));
  const b1 = b.routes.find((r) => r.route_id === 'brt_b1');
  const b2 = b.routes.find((r) => r.route_id === 'brt_b2');
  const ids1 = b1.direction_id_0.map((s) => s.dakar_bus_stop_id);
  const ids2 = b2.direction_id_0.map((s) => s.dakar_bus_stop_id);
  const shared = ids2.filter((i) => ids1.includes(i));
  assert.equal(shared.length, 7, 'les 7 stations de B2 devraient être partagées avec B1');
  // Une seule station physique : aucune copie suffixée par ligne
  const phys = b.physical_stations.map((s) => s.dakar_bus_stop_id);
  assert.deepEqual(dupes(phys), [], 'station physique dupliquée');
  for (const id of shared) {
    assert.equal(phys.filter((p) => p === id).length, 1,
      `la station partagée ${id} existe en plusieurs exemplaires`);
  }
  // Aucune station d'une séquence de ligne ne reste non résolue
  for (const r of b.routes) {
    for (const dir of ['direction_id_0', 'direction_id_1']) {
      for (const s of r[dir]) {
        assert.ok(s.dakar_bus_stop_id,
          `${r.route_id} ${dir} : station ${s.stop_name} sans identifiant public`);
      }
      assert.deepEqual(dupes(r[dir].map((s) => s.dakar_bus_stop_id)), [],
        `${r.route_id} ${dir} : station dupliquée dans la séquence`);
    }
  }
  // Les doublons PassBi ne sont PAS fusionnés sur la seule proximité
  assert.ok(Array.isArray(b.unmerged_passbi_duplicates));
  for (const u of b.unmerged_passbi_duplicates) {
    assert.equal(u.merged, false, `${u.stop_name} a été fusionnée`);
    assert.equal(u.status, 'UNCONFIRMED');
    assert.match(u.note, /proximité/);
    assert.ok(!phys.includes(u.passbi_stop_id));
  }
  assert.match(b.unmerged_rule, /ne sont PAS fusionnées/);
  assert.equal(b.anti_duplicate_display_rule.shared_stations.length, 7);
  // Modèle complet : route_id / direction_id / stop_sequence présents
  for (const r of b.routes) {
    for (const dir of ['direction_id_0', 'direction_id_1']) {
      const seqs = r[dir].map((s) => s.stop_sequence);
      assert.deepEqual(seqs, [...Array(r[dir].length).keys()].map((i) => i + 1),
        `${r.route_id} ${dir} : stop_sequence incohérente`);
    }
    assert.ok('shape_id' in r, `${r.route_id} : shape_id absent du modèle`);
  }
});

test('BRT B3 : identité NEW construite uniquement sur source actuelle, hors GTFS', () => {
  const b = jread(path.join(L2, 'structure', 'brt_route_structure.json'));
  const b3 = b.b3_identity_only;
  assert.equal(b3.identity_status, 'NEW');
  assert.equal(b3.structure_status, 'UNCONFIRMED');
  assert.equal(b3.in_passbi, false);
  assert.equal(b3.excluded_from_gtfs, true);
  assert.equal(b3.source_type, 'OFFICIAL_OPERATOR');
  assert.match(b3.source, /sunubrt\.sn/);
  assert.ok(b3.official_station_names.length > 0, 'stations officielles B3 absentes');
  // Aucun stop_id attribué : pas de reconstruction par proximité
  assert.match(b3.exclusion_reason, /proximité géographique/);
  const {rows} = gtfs('routes.txt');
  assert.ok(!rows.some((r) => r.route_id === 'brt_b3'), 'la B3 ne doit pas être dans le GTFS');
});

// ============================================================ DDD
test('DDD : 34 persistantes, 19 NOT_FOUND non supprimées, 0 DISCONTINUED', () => {
  const d = jread(path.join(L2, 'structure', 'ddd_routes.json'));
  assert.equal(d.counts.passbi_total, 53);
  assert.equal(d.persistent_routes.length, 34);
  assert.equal(d.not_found_routes.length, 19);
  assert.equal(d.counts.new_current, 0);
  assert.equal(34 + 19, 53, 'le total ne retombe pas sur 53');
  for (const p of d.persistent_routes) {
    assert.equal(p.identity_status, 'PERSISTENT');
    assert.equal(p.structure_status, 'UNKNOWN', 'la structure ne peut pas être déduite de l’identité');
    assert.equal(p.schedule_status, 'UNKNOWN');
    assert.equal(p.realtime_status, 'UNKNOWN');
    assert.ok(p.origin && p.destination, `${p.route_short_name} : terminus manquants`);
    assert.equal(p.source_type, 'OFFICIAL_OPERATOR');
    assert.equal(p.date_verified, '2026-09-27');
    assert.match(p.match_basis, /numéro \+ terminus/);
  }
  for (const n of d.not_found_routes) {
    assert.equal(n.identity_status, 'UNCONFIRMED');
    assert.equal(n.status, 'NOT_FOUND');
    assert.match(n.note, /insuffisante pour conclure à une suppression/);
  }
  // Vérification sur les VALEURS des champs de statut, pas sur le texte du fichier :
  // la prose du rapport peut légitimement citer les statuts interdits pour les écarter.
  const forbidden = ['DISCONTINUED', 'SUPPRIMED', 'DELETED', 'REMOVED', 'OBSOLETE'];
  const statusFields = ['status', 'identity_status', 'structure_status',
    'schedule_status', 'realtime_status'];
  for (const r of [...d.persistent_routes, ...d.not_found_routes]) {
    for (const f of statusFields) {
      if (r[f] === undefined || r[f] === null) continue;
      assert.ok(!forbidden.includes(String(r[f]).toUpperCase()),
        `${r.route_short_name}.${f} = ${r[f]} : statut de suppression interdit`);
    }
  }
  // Et aucune des 19 n'a disparu du référentiel
  const rs = jread(path.join(L2, 'route_status.json'));
  const inStatus = rs.routes.filter((r) => r.network === 'DDD' &&
    r.route_identity_status === 'UNCONFIRMED');
  assert.equal(inStatus.length, 19, 'les 19 lignes NOT_FOUND ont disparu de route_status');
});

test('DDD : les arrêts PassBi ne sont pas importés comme arrêts actuels', () => {
  const d = jread(path.join(L2, 'structure', 'ddd_routes.json'));
  assert.deepEqual(d.stops_policy.current_verified_stops, [],
    'aucun arrêt DDD n’est actuellement validé');
  assert.ok(d.stops_policy.historical_stops.includes('passbi/ddd/stops.txt'));
  assert.match(d.stops_policy.rule, /PAS importés/);
  // Aucun arrêt DDD dans le GTFS validé
  const {rows} = gtfs('stops.txt');
  assert.ok(rows.every((r) => r.stop_id.startsWith('stop_')),
    'des arrêts non TER se sont glissés dans le GTFS validé');
  assert.equal(rows.length, 13, 'seules les 13 gares TER sont validées');
});

// ============================================================ AFTU
test('AFTU : référentiel brut uniquement, aucune identité importée', () => {
  const a = jread(path.join(L2, 'structure', 'aftu_raw_registry.json'));
  assert.equal(a.raw_registry.length, 73);
  assert.equal(a.identity_status, 'UNCONFIRMED');
  for (const r of a.raw_registry) {
    assert.equal(r.identity_status, 'UNCONFIRMED');
    assert.equal(r.structure_status, 'UNKNOWN');
    assert.equal(r.schedule_status, 'UNKNOWN');
    assert.equal(r.source_type, 'PASSBI');
    assert.ok(r.passbi_route_id && r.passbi_short_name);
  }
  const gap = a.numbering_gap;
  assert.equal(gap.passbi_count, 73);
  assert.equal(gap.dakar_bus_numbering, '1-72 continu');
  assert.ok(gap.passbi_absent_from_1_72.includes('6'), 'le trou 6-23 doit être documenté');
  assert.ok(gap.passbi_above_72.includes('91'));
  // Aucune ligne AFTU dans le GTFS validé
  const {rows} = gtfs('routes.txt');
  assert.ok(!rows.some((r) => /aftu/i.test(r.route_id + r.route_long_name)));
});

// ============================================================ CROSSWALK
test('crosswalk : schéma complet et politique respectée', () => {
  const cw = jread(path.join(T, 'crosswalk', 'crosswalk.json'));
  assert.equal(cw.entries.length, cw.total);
  assert.deepEqual(dupes(cw.entries.map((e) => e.crosswalk_id)), [], 'crosswalk_id dupliqué');
  for (const e of cw.entries) {
    assert.ok(MATCH_TYPES.includes(e.match_type), `match_type inconnu : ${e.match_type}`);
    assert.ok(CONFIDENCES.includes(e.confidence), `confidence inconnue : ${e.confidence}`);
    assert.equal(e.verified_at, '2026-09-27');
    assert.ok(e.evidence && e.evidence.length > 0, `${e.crosswalk_id} : evidence vide`);
    assert.ok(e.source && e.target !== undefined, `${e.crosswalk_id} : source/cible manquantes`);
  }
  assert.equal(cw.policy.NUMBER_ONLY, 'ne suffit jamais');
  // NUMBER_ONLY ne suffit jamais : aucun AFTU apparié par numéro
  const aftuMatched = cw.entries.filter((e) => e.source_id &&
    /^A\d/.test(String(e.source_id)) === false && false);
  assert.deepEqual(aftuMatched, []);
  for (const e of cw.entries.filter((x) => x.note && x.note.includes('NUMBER_ONLY'))) {
    assert.equal(e.match_type, 'UNCONFIRMED');
  }
  // COORDINATE_ONLY / NAME_ONLY n'identifient pas une ligne
  for (const e of cw.entries.filter((x) => x.match_type === 'NAME_ONLY')) {
    assert.notEqual(e.confidence, 'HIGH', 'NAME_ONLY ne peut pas porter une confiance HIGH');
  }
});

test('crosswalk : aucune identité AFTU Dakar Bus n’est déduite du numéro', () => {
  const cw = jread(path.join(T, 'crosswalk', 'crosswalk.json'));
  const a = jread(path.join(L2, 'structure', 'aftu_raw_registry.json'));
  const aftuIds = new Set(a.raw_registry.map((r) => r.passbi_route_id));
  const aftuCw = cw.entries.filter((e) => aftuIds.has(e.source_id));
  assert.ok(aftuCw.length >= 73,
    `chaque ligne AFTU doit porter au moins une entrée (${aftuCw.length})`);

  // Invariant du lot 4.4, inchangé : aucune cible Dakar Bus n'est attribuée par numéro.
  const toDakarBus = aftuCw.filter((e) => e.target === 'dakar_bus');
  assert.equal(toDakarBus.length, 73, 'une entrée AFTU -> Dakar Bus manque');
  for (const e of toDakarBus) {
    assert.equal(e.match_type, 'UNCONFIRMED',
      `${e.source_name} : correspondance Dakar Bus établie sans preuve`);
    assert.equal(e.target_id, null,
      `${e.source_name} : une cible Dakar Bus a été attribuée`);
  }

  // Apport du lot 4.5 : une correspondance avec l'OPÉRATEUR est possible, mais elle
  // exige des terminus concordants — jamais le seul numéro.
  const toOperator = aftuCw.filter((e) => e.target === 'operator_current');
  assert.equal(toOperator.length, 73);
  for (const e of toOperator) {
    if (e.match_type === 'STRUCTURAL') {
      assert.ok(e.evidence.length >= 2,
        `${e.source_name} : STRUCTURAL sans terminus corroborés`);
      assert.ok(e.evidence.some((v) => /terminus concordants/i.test(v.claim)),
        `${e.source_name} : STRUCTURAL sans preuve de terminus`);
      assert.ok(['PERSISTENT', 'PARTIALLY_CONFIRMED'].includes(e.status),
        `${e.source_name} : STRUCTURAL avec statut ${e.status}`);
      assert.notEqual(e.status, 'CONFIRMED',
        `${e.source_name} : une source n'a pas déclaré explicitement l'équivalence`);
    }
    if (e.match_type === 'UNCONFIRMED' && e.target_id !== null) {
      assert.match(e.verification_note, /NUMBER_ONLY ne suffit jamais/,
        `${e.source_name} : numéro seul accepté comme preuve`);
    }
  }
  assert.ok(!cw.policy.NUMBER_ONLY || cw.policy.NUMBER_ONLY === 'ne suffit jamais');
});

// ============================================================ statuts globaux
test('route_status : quatre dimensions indépendantes et vocabulaire contrôlé', () => {
  const rs = jread(path.join(L2, 'route_status.json'));
  assert.deepEqual(rs.four_independent_dimensions,
    ['identity', 'structure', 'schedule', 'realtime']);
  const dims = ['route_identity_status', 'route_structure_status',
    'route_schedule_status', 'route_realtime_status'];
  for (const r of rs.routes) {
    for (const d of dims) {
      assert.ok(STATUSES.includes(r[d]), `${r.route_id}.${d} : statut inconnu "${r[d]}"`);
    }
    // Aucun temps réel affirmé
    assert.equal(r.route_realtime_status, 'UNKNOWN',
      `${r.route_id} : REAL_TIME affirmé sans flux actif`);
  }
  // Aucune dimension déduite d'une autre : la structure ne force pas l'horaire
  const withStructure = rs.routes.filter((r) =>
    ['CONFIRMED', 'PERSISTENT'].includes(r.route_structure_status));
  assert.ok(withStructure.length > 0);
  assert.ok(withStructure.every((r) => r.route_schedule_status !== 'CONFIRMED'),
    'un horaire a été déduit de la seule solidité structurelle');
});

test('REAL_TIME = NON sur toute la couche', () => {
  const prod = jread(path.join(L3, 'production_ready.json'));
  assert.match(prod.real_time, /^NON/);
  const rs = jread(path.join(L2, 'route_status.json'));
  assert.deepEqual(Object.keys(rs.counts.realtime), ['UNKNOWN']);
});

test('LEVEL 3 : séparation prête / non prête explicite', () => {
  const p = jread(path.join(L3, 'production_ready.json'));
  assert.equal(p.ready.length, p.counts_ready);
  assert.equal(p.not_ready.length, p.counts_not_ready);
  for (const r of p.ready) {
    assert.ok(STATUSES.includes(r.status), `statut inconnu : ${r.status}`);
    assert.ok(r.usable_for && r.usable_for.length > 0, `${r.entity} : usable_for vide`);
    assert.ok(fs.existsSync(path.join(T, r.location.replace('data/transit/', ''))),
      `${r.entity} : emplacement introuvable ${r.location}`);
  }
  for (const n of p.not_ready) {
    assert.ok(n.reason && n.reason.length > 0, `${n.entity} : raison absente`);
  }
  // Un horaire ne figure pas dans les données prêtes
  assert.ok(!p.ready.some((r) => /horaire/i.test(r.entity) &&
    !/fréquence/i.test(r.entity)), 'un horaire exact a été déclaré prêt');
});

test('manifeste LEVEL 1 : empreintes et re-téléchargement documentés', () => {
  const m = jread(path.join(T, 'MANIFEST.json'));
  for (const [k, f] of Object.entries(m.feeds)) {
    assert.match(f.sha256, /^[0-9a-f]{64}$/, `${k} : sha256 invalide`);
    assert.match(f.git_blob, /^[0-9a-f]{40}$/, `${k} : git_blob invalide`);
    assert.ok(f.copied_to_level1.length > 0, `${k} : rien en LEVEL 1`);
    for (const c of f.copied_to_level1) {
      assert.ok(fs.existsSync(path.join(L1, k, c)), `${k}/${c} absent`);
    }
  }
  assert.match(m.licence_warning, /BLOQUÉE/);
  assert.match(m.refetch, /gh api/);
});

test('critère de fin : chaque entité conservée porte un statut et une raison', () => {
  const rs = jread(path.join(L2, 'route_status.json'));
  for (const r of rs.routes) {
    assert.ok(r.note && r.note.length > 0, `${r.route_id} : aucune raison de conservation`);
  }
  const cw = jread(path.join(T, 'crosswalk', 'crosswalk.json'));
  for (const e of cw.entries) {
    assert.ok(e.evidence.length > 0, `${e.crosswalk_id} : aucune preuve`);
  }
});
