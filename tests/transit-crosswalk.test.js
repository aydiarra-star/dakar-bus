'use strict';
/**
 * LOT 4.5 — Tests du crosswalk des identités publiques.
 *
 * Tests de DONNÉES uniquement. Aucun code applicatif n'est importé ni modifié :
 * ni main.dart, ni GPS, ni UI, ni RoutePlanner, ni moteur d'itinéraires,
 * ni logique des correspondances.
 *
 * Principe vérifié partout : aucune identité n'est établie par le seul numéro,
 * la seule proximité géographique, un nom ressemblant ou une continuité numérique.
 */
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const T = path.join(ROOT, 'data', 'transit');
const CW = path.join(T, 'crosswalk');
const jread = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));

const central = jread(path.join(CW, 'crosswalk.json'));
const ter = jread(path.join(CW, 'ter_crosswalk.json'));
const brt = jread(path.join(CW, 'brt_crosswalk.json'));
const ddd = jread(path.join(CW, 'ddd_crosswalk.json'));
const aftu = jread(path.join(CW, 'aftu_crosswalk.json'));
const inter = jread(path.join(CW, 'intermodal_transfers.json'));
const audit = jread(path.join(CW, 'source_audit.json'));

const MATCH_TYPES = ['EXACT', 'DOCUMENTED', 'STRUCTURAL', 'NAME_ONLY',
  'COORDINATE_ONLY', 'UNCONFIRMED'];
const STATUSES = ['CONFIRMED', 'PERSISTENT', 'PARTIALLY_CONFIRMED', 'UNCONFIRMED',
  'CONTRADICTED', 'NEW', 'UNKNOWN'];
const CONFIDENCES = ['HIGH', 'MEDIUM', 'LOW', 'UNKNOWN'];
const FORBIDDEN = ['DELETED', 'DISCONTINUED', 'INACTIVE', 'SUPPRIMED', 'REMOVED',
  'OBSOLETE', 'RETIRED'];

// ============================================================ schéma
test('crosswalk : schéma complet et compatible avec le lot 4.4', () => {
  const legacyFields = ['crosswalk_id', 'source', 'source_id', 'target', 'target_id',
    'match_type', 'evidence', 'confidence', 'verified_at'];
  const newFields = ['source_name', 'target_name', 'operator', 'network',
    'source_url', 'source_type', 'verification_note', 'status'];
  for (const e of central.entries) {
    for (const f of [...legacyFields, ...newFields]) {
      assert.ok(f in e, `${e.crosswalk_id} : champ ${f} absent (compatibilité 4.4 cassée)`);
    }
    assert.ok(MATCH_TYPES.includes(e.match_type), `match_type inconnu : ${e.match_type}`);
    assert.ok(STATUSES.includes(e.status), `status inconnu : ${e.status}`);
    assert.ok(CONFIDENCES.includes(e.confidence), `confidence inconnue : ${e.confidence}`);
    assert.equal(e.verified_at, '2026-09-27');
    assert.ok(Array.isArray(e.evidence), `${e.crosswalk_id} : evidence doit être une liste`);
  }
  assert.equal(central.total, central.entries.length);
  assert.deepEqual([...new Set(central.entries.map((e) => e.crosswalk_id))].length,
    central.total, 'crosswalk_id dupliqué');
});

test('crosswalk : EXACT et DOCUMENTED exigent evidence ET verified_at', () => {
  const strong = central.entries.filter((e) =>
    ['EXACT', 'DOCUMENTED', 'STRUCTURAL'].includes(e.match_type));
  assert.ok(strong.length > 0, 'aucune relation forte : le test ne prouve rien');
  for (const e of strong) {
    assert.ok(e.evidence.length > 0, `${e.crosswalk_id} (${e.match_type}) sans evidence`);
    assert.ok(e.verified_at, `${e.crosswalk_id} sans verified_at`);
    for (const v of e.evidence) {
      assert.ok(v.source_url, `${e.crosswalk_id} : preuve sans source_url`);
      assert.ok(v.date_verified, `${e.crosswalk_id} : preuve sans date_verified`);
      assert.ok(v.claim && v.claim.length > 0, `${e.crosswalk_id} : preuve sans libellé`);
      assert.ok(v.source_type, `${e.crosswalk_id} : preuve sans source_type`);
    }
    assert.ok(e.verification_note && e.verification_note.length > 0,
      `${e.crosswalk_id} : verification_note vide`);
  }
});

test('crosswalk : NAME_ONLY et COORDINATE_ONLY ne portent jamais HIGH', () => {
  const weak = central.entries.filter((e) =>
    ['NAME_ONLY', 'COORDINATE_ONLY'].includes(e.match_type));
  for (const e of weak) {
    assert.notEqual(e.confidence, 'HIGH',
      `${e.crosswalk_id} : ${e.match_type} avec confiance HIGH`);
    assert.notEqual(e.status, 'CONFIRMED',
      `${e.crosswalk_id} : ${e.match_type} promeut une identité`);
  }
  assert.match(central.policy.COORDINATE_ONLY, /ne suffit pas/);
  assert.match(central.policy.NAME_ONLY, /ne suffit pas/);
  assert.equal(central.policy.NUMBER_ONLY, 'ne suffit jamais');
  assert.match(central.policy.OSM_ALONE, /ne suffit pas/);
});

// ============================================================ DDD
test('DDD : les 34 persistantes ne sont jamais DELETED', () => {
  assert.equal(ddd.persistent, 34);
  assert.equal(ddd.not_found, 19);
  assert.equal(ddd.new_current, 0);
  assert.equal(34 + 19, 53, 'le total ne retombe pas sur les 53 lignes PassBi');
  // Les 34 persistantes sont celles appariées à l'opérateur actuel. Neuf autres entrées
  // PERSISTENT visent le réseau du projet et ne font pas partie de ce décompte.
  const persistent = ddd.entries.filter((e) => e.status === 'PERSISTENT' &&
    e.target === 'operator_current');
  assert.equal(persistent.length, 34, `attendu 34 PERSISTENT, obtenu ${persistent.length}`);
  // Les valeurs des champs ne portent jamais un statut de suppression.
  for (const e of ddd.entries) {
    for (const f of ['status', 'match_type', 'confidence']) {
      assert.ok(!FORBIDDEN.includes(String(e[f]).toUpperCase()),
        `${e.source_name}.${f} = ${e[f]} : statut de suppression interdit`);
    }
  }
  // La prose nomme DELETED/DISCONTINUED/INACTIVE uniquement pour les écarter. On retire
  // donc la clause de négation avant le scan, sinon on teste la rédaction et non la donnée.
  const NEGATION = /aucun statut[^.]*\./gi;
  for (const e of ddd.entries) {
    const asserted = e.verification_note.replace(NEGATION, '').toUpperCase();
    for (const w of FORBIDDEN) {
      assert.ok(!asserted.includes(w),
        `${e.source_name} : la note affirme « ${w} » hors de sa clause de négation`);
    }
  }
  assert.match(ddd.not_found_rule, /Aucun statut DELETED/);
});

test('DDD : les 19 non retrouvées restent UNCONFIRMED, avec la note imposée', () => {
  const nf = ddd.entries.filter((e) => e.target === 'operator_current' &&
    e.target_id === null && e.source === 'passbi');
  assert.equal(nf.length, 19, `attendu 19 lignes non retrouvées, obtenu ${nf.length}`);
  for (const e of nf) {
    assert.equal(e.status, 'UNCONFIRMED');
    assert.equal(e.match_type, 'UNCONFIRMED');
    assert.equal(e.confidence, 'LOW');
    assert.match(e.verification_note, /absence de preuve de suppression/);
    assert.match(e.verification_note, /Non retrouvée dans les sources actuelles/);
  }
});

test('DDD : aucune identité créée sans preuve numéro + terminus', () => {
  const toOp = ddd.entries.filter((e) => e.target === 'operator_current' &&
    e.target_id !== null);
  assert.equal(toOp.length, 34);
  for (const e of toOp) {
    assert.equal(e.match_type, 'STRUCTURAL',
      `${e.source_name} : une source ne déclare pas explicitement l'équivalence`);
    assert.equal(e.status, 'PERSISTENT');
    assert.equal(e.confidence, 'HIGH');
    assert.ok(e.origin && e.destination, `${e.source_name} : terminus manquants`);
    assert.ok(e.evidence.some((v) => /publie LIGNE/.test(v.claim)),
      `${e.source_name} : preuve opérateur absente`);
    assert.ok(e.evidence.some((v) => /initiales des mêmes terminus/.test(v.claim)),
      `${e.source_name} : preuve de terminus absente`);
  }
  // Identité n'entraîne ni structure ni horaire
  assert.match(ddd.persistent_rule, /structure = UNKNOWN/);
  assert.match(ddd.persistent_rule, /schedule = UNKNOWN/);
  assert.match(ddd.no_stops_invented, /Aucun trips\.txt/);
});

test('DDD : D501GP conserve sa preuve documentaire', () => {
  const e = ddd.entries.find((x) => x.source_name === 'D501GP' &&
    x.target === 'operator_current');
  assert.ok(e, 'la relation D501GP a disparu');
  assert.equal(e.target_id, 'LIGNE 501');
  assert.equal(e.origin, 'GARE DE DAKAR');
  assert.equal(e.destination, 'PALAIS 2');
  assert.equal(ddd.example_documented.passbi_code, 'D501GP');
  assert.match(ddd.example_documented.evidence, /GARE DE DAKAR/);
});

// ============================================================ AFTU
test('AFTU : aucune correspondance numéro → numéro avec Dakar Bus', () => {
  const toDb = aftu.entries.filter((e) => e.target === 'dakar_bus');
  assert.equal(toDb.length, 73);
  for (const e of toDb) {
    assert.equal(e.match_type, 'UNCONFIRMED',
      `${e.source_name} : identité Dakar Bus établie`);
    assert.equal(e.target_id, null,
      `${e.source_name} : cible Dakar Bus attribuée`);
    assert.equal(e.status, 'UNCONFIRMED');
    assert.match(e.verification_note, /ne constitue pas une preuve/);
  }
  assert.equal(aftu.identity_vs_dakar_bus.startsWith('UNCONFIRMED'), true);
});

test('AFTU : les identités non démontrées restent UNCONFIRMED', () => {
  const v = aftu.verdicts;
  const total = v.TERMINI_MATCH + v.PARTIAL_TERMINI + v.NUMBER_ONLY + v.NOT_FOUND;
  assert.equal(total, 73, 'les 73 lignes PassBi doivent toutes être classées');
  assert.equal(aftu.passbi_routes, 73);
  const toOp = aftu.entries.filter((e) => e.target === 'operator_current');
  assert.equal(toOp.length, 73);
  for (const e of toOp) {
    if (e.match_type === 'UNCONFIRMED') {
      assert.equal(e.status, 'UNCONFIRMED');
      assert.equal(e.confidence, 'LOW');
      if (e.target_id !== null) {
        assert.match(e.verification_note, /NUMBER_ONLY ne suffit jamais/);
      } else {
        assert.match(e.verification_note, /absence de preuve de suppression/);
      }
    }
    if (e.match_type === 'STRUCTURAL') {
      assert.ok(['PERSISTENT', 'PARTIALLY_CONFIRMED'].includes(e.status),
        `${e.source_name} : STRUCTURAL avec statut ${e.status}`);
    }
  }
  // Le numéro seul n'a jamais suffi
  for (const d of aftu.detail) {
    if (d.verdict === 'NUMBER_ONLY') {
      assert.deepEqual(d.shared_tokens, [], `${d.passbi_code} : tokens partagés présents`);
      assert.equal(d.identity_vs_operator, 'UNCONFIRMED');
    }
  }
});

test('AFTU : la numérotation du projet n’est pas renumérotée', () => {
  assert.match(aftu.numbering.dakar_bus, /1-72 en continu/);
  assert.match(aftu.numbering.conclusion, /Aucune renumérotation automatique/);
  const proj = JSON.parse(fs.readFileSync(
    path.join(ROOT, 'flutter-src', 'assets', 'data', 'dakar_network.json'), 'utf8'));
  const nums = proj.routes.filter((r) => r.id.startsWith('aftu_'))
    .map((r) => parseInt(r.id.replace('aftu_', ''), 10));
  assert.equal(nums.length, 72, 'la numérotation du projet a été modifiée');
  assert.deepEqual(nums, [...Array(72).keys()].map((i) => i + 1),
    'la numérotation 1-72 du projet a été altérée');
});

// ============================================================ BRT
test('BRT : B1, B2 et B3 restent trois lignes distinctes', () => {
  assert.deepEqual(brt.routes_kept_distinct, ['B1', 'B2', 'B3']);
  const ids = brt.entries.filter((e) => e.target === 'dakar_bus' &&
    ['brt_b1', 'brt_b2', 'brt_b3'].includes(e.target_id)).map((e) => e.target_id);
  assert.deepEqual([...new Set(ids)].sort(), ['brt_b1', 'brt_b2', 'brt_b3']);
  // La B3 n'est jamais rapprochée de B1 ou B2
  const b3 = brt.entries.filter((e) => e.target_id === 'brt_b3');
  for (const e of b3) {
    assert.equal(e.status, 'NEW');
    assert.match(e.verification_note, /Aucune correspondance avec B1 ou B2/);
  }
  assert.equal(brt.b3.identity_status, 'NEW');
  assert.equal(brt.b3.structure_status, 'UNCONFIRMED');
  assert.equal(brt.b3.in_passbi, false);
});

test('BRT : B2 possède bien ses 7 stations, dans le même ordre', () => {
  assert.equal(brt.b2.passbi_stations, 7);
  assert.equal(brt.b2.current_documented_stations, 7);
  assert.equal(brt.b2.order_identical, true);
  const b2 = brt.entries.find((e) => e.target_id === 'brt_b2');
  assert.equal(b2.match_type, 'DOCUMENTED');
  assert.equal(b2.status, 'CONFIRMED');
  assert.match(b2.verification_note, /7 stations/);
});

test('BRT : PassBi B1 = 21 et réseau actuel = 23, les deux niveaux conservés', () => {
  assert.equal(brt.b1.passbi_stations, 21);
  assert.equal(brt.b1.current_documented_stations, 23);
  assert.equal(brt.b1.structure_status, 'PERSISTENT');
  assert.match(brt.b1.rule, /n'est pas porté à 23/);
  const b1 = brt.entries.find((e) => e.target_id === 'brt_b1');
  assert.match(b1.verification_note, /21 stations PassBi, 23 stations actuelles/);
});

test('BRT : une station physique peut appartenir à plusieurs routes, sans duplication', () => {
  const m = brt.physical_stop_model;
  assert.equal(m.shared_stations.length, 7);
  // PassBi fournit 22 entrées station : 21 stations physiques confirmées + 1 doublon
  // conservé à part, volontairement NON fusionné.
  const stationEntries = brt.entries.filter((e) => e.source === 'passbi' &&
    e.source_id && !['B1', 'B2', 'B3'].includes(e.source_id));
  assert.equal(stationEntries.length, 22,
    `attendu 22 entrées station PassBi, obtenu ${stationEntries.length}`);
  const ids = stationEntries.map((e) => e.source_id);
  assert.deepEqual(ids.filter((v, i) => ids.indexOf(v) !== i), [],
    'une station physique est enregistrée plusieurs fois');
  const confirmedStations = stationEntries.filter((e) => e.match_type === 'STRUCTURAL');
  assert.equal(confirmedStations.length, m.physical_stations,
    'le nombre de stations physiques ne correspond pas aux entrées confirmées');
  assert.equal(m.physical_stations, 21);
  assert.equal(m.unmerged_duplicates, 1);
  assert.equal(stationEntries.length, m.physical_stations + m.unmerged_duplicates,
    'les doublons non fusionnés ne sont pas comptés');
  assert.match(m.rule, /Aucune station n'est dupliquée/);
  // Le doublon n'est pas fusionné
  const dup = stationEntries.find((e) => e.match_type === 'COORDINATE_ONLY');
  assert.ok(dup, 'le doublon non fusionné a disparu');
  assert.equal(dup.confidence, 'LOW');
  assert.match(dup.verification_note, /NON fusionnée/);
});

// ============================================================ TER
test('TER : les 13 gares sont présentes, l’ordre est conservé', () => {
  assert.equal(ter.stations_confirmed, 13);
  assert.equal(ter.order_preserved, true);
  assert.deepEqual(ter.station_order, [
    'Dakar - Gare ferroviaire', 'Colobane', 'Hann', 'Dalifort', 'Baux Maraîchers',
    'Pikine', 'Thiaroye', 'Yeumbeul', 'Keur Mbaye Fall', 'PNR Rufisque', 'Rufisque',
    'Bargny', 'Diamniadio']);
  const stops = ter.entries.filter((e) => e.target === 'dakar_bus' &&
    e.match_type === 'STRUCTURAL');
  assert.equal(stops.length, 13);
  for (const e of stops) {
    assert.equal(e.status, 'CONFIRMED');
    assert.equal(e.confidence, 'HIGH');
    assert.ok(e.evidence.length >= 4, `${e.source_name} : moins de 4 éléments indépendants`);
    assert.match(e.verification_note, /STRUCTURAL et non EXACT/);
  }
  assert.equal(ter.coordinate_check.matched, 13);
  assert.equal(ter.coordinate_check.crossed_pairing, false);
  // 2 relations documentées
  const routes = ter.entries.filter((e) => e.match_type === 'DOCUMENTED');
  assert.equal(routes.length, 2);
  assert.deepEqual(routes.map((r) => r.origin).sort(), ['Dakar', 'Diamniadio']);
});

test('TER : aucune nouvelle gare ajoutée sans preuve', () => {
  assert.equal(ter.not_added_without_proof.length, 3);
  const names = ter.entries.map((e) => String(e.source_name || ''));
  for (const banned of ['AIBD', 'Sébikotane', 'Sebikotane', 'Keur Moussa']) {
    assert.ok(!names.some((n) => n.toLowerCase().includes(banned.toLowerCase())),
      `${banned} a été ajouté au crosswalk`);
  }
  const km = ter.not_added_without_proof.find((s) => s.name === 'Keur Moussa');
  assert.match(km.reason, /commune traversée/);
  assert.equal(ter.not_added_without_proof.find((s) => s.name === 'AIBD').status,
    'PROVISIONAL');
  assert.match(ter.identifiers_policy, /ne sont pas des identifiants officiels actuels/);
});

// ============================================================ intermodal
test('intermodal : registre de données, correspondances justifiées', () => {
  assert.equal(inter.total, inter.entries.length);
  assert.ok(inter.documented.length >= 4, 'les 4 dessertes TER de l’opérateur manquent');
  for (const e of inter.documented) {
    assert.equal(e.match_type, 'DOCUMENTED');
    assert.equal(e.confidence, 'HIGH');
    assert.match(e.justification, /Dessertes Gares du TER/);
    assert.ok(e.evidence.length > 0);
  }
  for (const e of inter.coordinate_only) {
    assert.equal(e.match_type, 'COORDINATE_ONLY');
    assert.equal(e.confidence, 'LOW');
    assert.equal(e.status, 'UNCONFIRMED');
    assert.match(e.note, /ne suffit pas à déclarer une correspondance officielle/);
  }
  assert.match(inter.scope, /moteur de correspondances n'est PAS modifié/);
  assert.deepEqual([...new Set(inter.documented.map((e) => e.ter_stop))].sort(),
    ['Colobane', 'Diamniadio', 'Gare de Dakar']);
});

// ============================================================ audit des sources
test('audit : chaque source est traçable', () => {
  assert.equal(audit.sources.length, 9, 'le nombre de sources auditées a changé');
  for (const s of audit.sources) {
    assert.ok(s.url && s.url.startsWith('http'), `${s.id} : URL absente`);
    assert.ok(s.source_type, `${s.id} : source_type absent`);
    assert.ok([1, 2, 3].includes(s.level), `${s.id} : niveau invalide`);
    assert.equal(s.date_verified, '2026-09-27');
    assert.ok(s.verification_note && s.verification_note.length > 0,
      `${s.id} : verification_note vide`);
  }
  const urls = new Set(audit.sources.map((s) => s.url));
  // Chaque preuve du crosswalk pointe vers une source auditée
  const unknown = new Set();
  for (const e of central.entries) {
    for (const v of e.evidence) {
      if (!urls.has(v.source_url)) unknown.add(v.source_url);
    }
  }
  assert.deepEqual([...unknown], [], 'preuves pointant vers des sources non auditées');
  assert.match(audit.osm_usage, /ne suffit pas/);
  for (const n of audit.not_used) {
    assert.match(central.policy.PROXIMITY_ALONE, /ne justifie ni une identité/);
    assert.ok(n.length > 0);
  }
});

test('audit : les niveaux de source sont respectés', () => {
  // Aucune identité forte ne repose uniquement sur PassBi ou sur OSM
  const strong = central.entries.filter((e) =>
    ['EXACT', 'DOCUMENTED', 'STRUCTURAL'].includes(e.match_type));
  for (const e of strong) {
    const types = e.evidence.map((v) => v.source_type);
    assert.ok(!types.every((t) => t === 'PASSBI'),
      `${e.crosswalk_id} : identité établie par PassBi seul`);
    assert.ok(!types.includes('OSM') || types.length > 1,
      `${e.crosswalk_id} : identité établie par OSM seul`);
  }
  const passbiOnly = strong.filter((e) => e.evidence.every((v) => v.source_type === 'PASSBI'));
  assert.deepEqual(passbiOnly, []);
});

// ============================================================ cohérence globale
test('registres réseau et registre central sont cohérents', () => {
  const sum = ter.total + brt.total + ddd.total + aftu.total;
  assert.equal(sum, central.total,
    `somme des registres (${sum}) != registre central (${central.total})`);
  const ids = [...ter.entries, ...brt.entries, ...ddd.entries, ...aftu.entries]
    .map((e) => e.crosswalk_id).sort();
  assert.deepEqual(ids, central.entries.map((e) => e.crosswalk_id).sort(),
    'le registre central n’est pas l’union exacte des registres réseau');
  assert.deepEqual(central.by_network, {TER: ter.total, BRT: brt.total,
    DDD: ddd.total, AFTU: aftu.total});
});

test('crosswalk : aucun horaire, tarif ni temps réel inventé', () => {
  const raw = fs.readFileSync(path.join(CW, 'crosswalk.json'), 'utf8');
  for (const banned of ['REAL_TIME', 'fare', 'price', 'tarif', 'SCHEDULED']) {
    assert.ok(!raw.includes(banned), `le crosswalk contient « ${banned} »`);
  }
  for (const e of central.entries) {
    assert.ok(!('arrival_time' in e) && !('departure_time' in e),
      `${e.crosswalk_id} : un horaire s'est glissé dans le crosswalk`);
  }
});
