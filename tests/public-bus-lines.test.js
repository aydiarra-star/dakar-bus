// MISSION — RÉFÉRENTIEL PUBLIC DES LIGNES AFTU / TATA / DDD.
//
// Vérifie que le générateur (`scripts/build-public-bus-lines.mjs`) produit un
// référentiel où :
//   * chaque ligne PUBLIQUE possède un numéro officiel (jamais un identifiant
//     de feed) ;
//   * les 72 lignes AFTU officielles sont présentes, sans doublon ;
//   * aucune identité Tata n'est exposée comme ligne publique ;
//   * le raccordement horaire pointe vers des `route_id` réellement présents
//     dans les feeds PassBi embarqués ;
//   * aucun horaire, arrêt ou correspondance n'est inventé.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const REF = JSON.parse(
  readFileSync(resolve(ROOT, 'data/reference/public_bus_lines_dakar.json'), 'utf8'));
const ASSET = JSON.parse(
  readFileSync(
    resolve(ROOT, 'flutter-src/assets/data/reference/public_bus_lines_dakar.json'),
    'utf8'));

function feedRouteIds(path) {
  const feed = JSON.parse(readFileSync(path, 'utf8'));
  return new Set(feed.routes.map((r) => r.id));
}
const AFTU_ROUTES = feedRouteIds(resolve(ROOT, 'flutter-src/assets/data/passbi/aftu.json'));
const DDD_ROUTES = feedRouteIds(resolve(ROOT, 'flutter-src/assets/data/passbi/ddd.json'));

test('le référentiel public est identique entre data/ et l’asset Flutter', () => {
  assert.deepEqual(REF, ASSET);
});

test('les 72 lignes AFTU officielles sont présentes, sans doublon', () => {
  assert.equal(REF.aftu.length, 72);
  const nums = REF.aftu.map((l) => l.line_number);
  assert.equal(new Set(nums).size, nums.length);
  for (const l of REF.aftu) {
    const n = Number(l.line_number);
    const inRange = (n >= 1 && n <= 5) || (n >= 24 && n <= 89) || n === 91;
    assert.ok(inRange, `numéro AFTU hors plage publiée : ${n}`);
  }
});

test('les lignes DDD publiques sont présentes, sans doublon', () => {
  assert.ok(REF.ddd.length > 40, `DDD publiques attendues > 40, reçu ${REF.ddd.length}`);
  const nums = REF.ddd.map((l) => l.line_number);
  assert.equal(new Set(nums).size, nums.length);
});

test('chaque ligne publique porte un numéro et un libellé officiels', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    assert.ok(l.line_number.length > 0);
    assert.equal(l.public_label, `${l.operator} ${l.line_number}`);
    assert.ok(!l.public_label.includes('_'), 'identifiant de feed dans le libellé');
    assert.ok(l.identity_status === 'CONFIRMED');
  }
});

test('le raccordement horaire pointe vers des route_id réellement présents', () => {
  for (const l of REF.aftu) {
    for (const id of l.feed_route_ids) assert.ok(AFTU_ROUTES.has(id), `route AFTU inconnue : ${id}`);
  }
  for (const l of REF.ddd) {
    for (const id of l.feed_route_ids) assert.ok(DDD_ROUTES.has(id), `route DDD inconnue : ${id}`);
  }
});

test('une ligne sans raccordement horaire ne déclare aucun arrêt desservi', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    if (l.schedule_status === 'NO_SCHEDULE') {
      // Un route_id peut exister dans le feed sans aucun stop_time : la ligne
      // reste alors sans horaire et sans arrêt desservi (jamais d'invention).
      assert.equal(l.served_stop_count, 0, `${l.public_label} : arrêts sans horaire`);
    } else {
      assert.ok(l.served_stop_count > 0);
      assert.ok(l.feed_route_ids.length > 0);
    }
  }
});

test('aucune identité Tata n’est exposée comme ligne publique', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    assert.notEqual(l.operator, 'TATA');
    assert.ok(!l.public_label.startsWith('Tata'));
  }
  // Les identités techniques vivent dans un registre d’audit séparé, sans
  // numéro public.
  assert.equal(REF.tata_audit.length, 7);
  for (const t of REF.tata_audit) {
    assert.equal(t.operator, 'AFTU');
    assert.equal(t.line_number, null);
    assert.equal(t.public_label, null);
  }
});

test('les variantes lettrées DDD ne sont pas raccordées au numéro nu du feed', () => {
  for (const l of REF.ddd) {
    if (!/[A-Za-z]/.test(l.line_number)) continue;
    if (l.published_schedule_status === 'SCHEDULE_CONFIRMED') continue; // TAF TAF
    assert.equal(l.schedule_status, 'NO_SCHEDULE', `${l.public_label} raccordée à tort`);
    assert.equal(l.feed_route_ids.length, 0);
  }
});

test('les compteurs déclarés correspondent aux listes', () => {
  assert.equal(REF.counts.aftu_official, REF.aftu.length);
  assert.equal(REF.counts.ddd_public, REF.ddd.length);
  assert.equal(REF.counts.tata_identities, REF.tata_audit.length);
});

test('aucune ligne publique sans source ni date de vérification', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    assert.ok(l.source.startsWith('http'), `source manquante : ${l.public_label}`);
    assert.ok(l.verified_at.length > 0);
  }
});

// ---------------------------------------------------------------------------
// §6 / §15 — Chaîne de raccordement horaire vérifiable.
// ---------------------------------------------------------------------------

/** route_id attendu pour un numéro public, par numérotation de l'opérateur. */
function expectedRouteId(network, number) {
  if (network === 'AFTU') return `AFTU_${Number(number)}`;
  const n = Number(number);
  return `DDD_${n < 100 ? String(n).padStart(2, '0') : String(n)}`;
}

test('chaque ligne raccordée expose les 6 maillons de la chaîne horaire', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    if (l.schedule_status !== 'SCHEDULE_AVAILABLE') continue;
    assert.ok(l.feed_route_ids.length > 0, `${l.public_label} : route_id`);
    assert.ok(l.trip_ids_count > 0, `${l.public_label} : trip_id`);
    assert.ok(l.direction_ids.length > 0, `${l.public_label} : direction_id`);
    assert.ok(l.stop_times_count > 0, `${l.public_label} : stop_times`);
    assert.ok(l.served_stop_count > 0, `${l.public_label} : stop_id`);
    assert.equal(l.stop_sequence_present, true, `${l.public_label} : stop_sequence`);
    assert.equal(l.unresolved_reason, null, `${l.public_label} : unresolved_reason`);
  }
});

test('aucun raccordement n’est fabriqué par similarité de numéro', () => {
  // Le route_id raccordé doit être exactement celui de la numérotation de
  // l’opérateur pour ce numéro public — jamais une route « proche ».
  for (const l of [...REF.aftu, ...REF.ddd]) {
    const expected = expectedRouteId(l.operator, l.line_number);
    for (const rid of l.feed_route_ids) {
      assert.equal(rid, expected,
        `${l.public_label} : route_id ${rid} ≠ numérotation attendue ${expected}`);
    }
  }
});

test('une ligne NON raccordée porte une cause exacte, jamais NO_SCHEDULE nu', () => {
  for (const l of [...REF.aftu, ...REF.ddd]) {
    if (l.schedule_status === 'SCHEDULE_AVAILABLE') continue;
    assert.ok(l.unresolved_reason, `${l.public_label} : cause de non-raccordement absente`);
    assert.notEqual(l.unresolved_reason, 'UNRESOLVED_UNKNOWN',
      `${l.public_label} : cause non identifiée`);
    // Un route_id peut exister dans le feed sans aucun stop_time (AFTU_47/52) :
    // la ligne reste alors sans horaire et sans arrêt desservi, jamais inventé.
    assert.equal(l.served_stop_count, 0, `${l.public_label} : arrêts sans horaire`);
    assert.equal(l.stop_times_count, 0, `${l.public_label} : stop_times sans horaire`);
  }
});

test('les compteurs de raccordement du référentiel sont exacts', () => {
  const all = [...REF.aftu, ...REF.ddd];
  const linkedCount = all.filter((l) => l.schedule_status === 'SCHEDULE_AVAILABLE').length;
  assert.equal(REF.counts.linked, linkedCount);
  assert.equal(REF.counts.unresolved, all.length - linkedCount);
  assert.equal(REF.unresolved_public_lines.length, REF.counts.unresolved);
});

// ---------------------------------------------------------------------------
// TEST CRITIQUE (§15) — TOUTES LES LIGNES PUBLIQUES AFTU/DDD DOIVENT ÊTRE
// RACCORDÉES AUX DONNÉES HORAIRES.
// ---------------------------------------------------------------------------

test('TEST CRITIQUE — 100 % des lignes publiques AFTU/DDD raccordées aux horaires',
  () => {
    const unresolved = REF.unresolved_public_lines.map(
      (u) => `${u.public_label} (${u.reason})`);
    assert.equal(
      REF.unresolved_public_lines.length,
      0,
      `lignes publiques non raccordées (chantier NON terminé) :\n  - ${unresolved.join('\n  - ')}`,
    );
  });
