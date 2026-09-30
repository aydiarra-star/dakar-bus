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

const ALL = [...REF.aftu, ...REF.ddd];

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
  for (const l of ALL) {
    if (l.mapping_status === 'CONNECTED') {
      assert.ok(l.served_stop_count > 0);
      assert.ok(l.feed_route_ids.length > 0);
    } else {
      // Une route peut exister dans le feed sans aucun stop_time (AFTU 47/52) :
      // la ligne reste alors sans horaire et sans arrêt desservi (jamais
      // d'invention).
      assert.equal(l.served_stop_count, 0, `${l.public_label} : arrêts sans horaire`);
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
    // Le feed n'expose aucune route pour ces identités lettrées : aucune ne peut
    // être CONNECTED, et aucune ne fusionne avec la route au numéro nu.
    assert.notEqual(l.mapping_status, 'CONNECTED',
      `${l.public_label} raccordée à tort`);
    assert.equal(l.feed_route_ids.length, 0);
    assert.equal(l.unresolved_reason, 'NO_FEED_ROUTE_FOR_LINE_NUMBER');
  }
});

test('les compteurs déclarés correspondent aux listes', () => {
  assert.equal(REF.counts.aftu_official, REF.aftu.length);
  assert.equal(REF.counts.ddd_public, REF.ddd.length);
  assert.equal(REF.counts.tata_identities, REF.tata_audit.length);
  const byStatus = (s) => ALL.filter((l) => l.mapping_status === s).length;
  assert.equal(REF.counts.connected, byStatus('CONNECTED'));
  assert.equal(REF.counts.blocked, byStatus('BLOCKED'));
  assert.equal(REF.counts.not_verified, byStatus('NOT_VERIFIED'));
  assert.equal(REF.counts.partial, byStatus('PARTIAL'));
  assert.equal(
    REF.counts.connected + REF.counts.blocked + REF.counts.not_verified + REF.counts.partial,
    ALL.length);
});

test('mapping_status est dérivé de la chaîne, jamais optimiste', () => {
  for (const l of ALL) {
    if (l.mapping_status === 'CONNECTED') {
      assert.ok(l.feed_route_ids.length > 0, `${l.public_label} : route_id`);
      assert.ok(l.trip_ids_count > 0, `${l.public_label} : trip_id`);
      assert.ok(l.direction_ids.length > 0, `${l.public_label} : direction_id`);
      assert.ok(l.stop_times_count > 0, `${l.public_label} : stop_times`);
      assert.ok(l.served_stop_count > 0, `${l.public_label} : stop_id`);
      assert.equal(l.stop_sequence_present, true, `${l.public_label} : stop_sequence`);
      assert.equal(l.schedule_status, 'SCHEDULE_AVAILABLE');
      assert.equal(l.unresolved_reason, null);
      assert.equal(l.blocking, null);
    } else {
      // BLOCKED (route présente, maillon manquant) ou NOT_VERIFIED (aucune
      // route). Jamais CONNECTED sans la chaîne complète.
      assert.ok(['BLOCKED', 'NOT_VERIFIED', 'PARTIAL'].includes(l.mapping_status));
      assert.equal(l.schedule_status, 'NO_SCHEDULE');
      assert.ok(l.unresolved_reason, `${l.public_label} : cause absente`);
    }
  }
});

test('toute ligne non raccordée porte une preuve de blocage exploitable', () => {
  for (const l of ALL) {
    if (l.mapping_status === 'CONNECTED') continue;
    assert.ok(l.blocking, `${l.public_label} : preuve de blocage absente`);
    assert.equal(l.blocking.reason, l.unresolved_reason);
    assert.ok(l.blocking.missing_fields.length > 0,
      `${l.public_label} : champs manquants non listés`);
    assert.ok(l.blocking.next_action.length > 0,
      `${l.public_label} : prochaine action absente`);
    assert.ok(l.blocking.consulted_sources.length > 0,
      `${l.public_label} : sources consultées absentes`);
    if (l.mapping_status === 'BLOCKED') {
      assert.ok(l.blocking.feed_route_ids_present.length > 0,
        `${l.public_label} : route présente non documentée`);
    }
    if (l.mapping_status === 'NOT_VERIFIED') {
      assert.equal(l.blocking.feed_route_ids_present.length, 0);
    }
  }
});

test('aucune route du feed ne reste orpheline sans être documentée (audit §9)', () => {
  // Toute route du feed est soit rattachée à une ligne publique, soit une
  // identité Tata, soit listée comme route SANS identité publique établie. Rien
  // n'est perdu silencieusement et rien n'est fusionné de force.
  const publicRoutes = new Set(ALL.flatMap((l) => l.feed_route_ids));
  const tataRoutes = new Set(REF.tata_audit.map((t) => t.route_id));
  const documented = new Set([
    ...REF.feed_routes_without_public_line.DDD,
    ...REF.feed_routes_without_public_line.AFTU,
  ]);
  const known = (rid) =>
    publicRoutes.has(rid) || tataRoutes.has(rid) || documented.has(rid);
  for (const rid of DDD_ROUTES) assert.ok(known(rid), `route DDD non documentée : ${rid}`);
  for (const rid of AFTU_ROUTES) assert.ok(known(rid), `route AFTU non documentée : ${rid}`);
  assert.equal(
    REF.counts.feed_routes_without_public_line,
    REF.feed_routes_without_public_line.DDD.length +
      REF.feed_routes_without_public_line.AFTU.length);
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
  for (const l of ALL) {
    if (l.mapping_status !== 'CONNECTED') continue;
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
  for (const l of ALL) {
    const expected = expectedRouteId(l.operator, l.line_number);
    for (const rid of l.feed_route_ids) {
      assert.equal(rid, expected,
        `${l.public_label} : route_id ${rid} ≠ numérotation attendue ${expected}`);
    }
  }
});

test('une ligne NON raccordée porte une cause exacte, jamais NO_SCHEDULE nu', () => {
  for (const l of ALL) {
    if (l.mapping_status === 'CONNECTED') continue;
    assert.ok(l.unresolved_reason, `${l.public_label} : cause de non-raccordement absente`);
    assert.notEqual(l.unresolved_reason, 'UNRESOLVED_UNKNOWN',
      `${l.public_label} : cause non identifiée`);
    // Un route_id peut exister dans le feed sans aucun stop_time (AFTU 47/52) :
    // la ligne reste alors sans horaire et sans arrêt desservi, jamais inventé.
    assert.equal(l.served_stop_count, 0, `${l.public_label} : arrêts sans horaire`);
    assert.equal(l.stop_times_count, 0, `${l.public_label} : stop_times sans horaire`);
  }
});

test('les compteurs de raccordement du référentiel sont exacts', () => {
  const linkedCount = ALL.filter((l) => l.mapping_status === 'CONNECTED').length;
  assert.equal(REF.counts.linked, linkedCount);
  assert.equal(REF.counts.unresolved, ALL.length - linkedCount);
  assert.equal(REF.unresolved_public_lines.length, REF.counts.unresolved);
});

test('une ligne BLOCKED documente la route présente sans stop_times exploitables', () => {
  // AFTU 47 (aucun trip) et AFTU 52 (trips sans stop_time) : la route existe
  // dans le feed, mais la chaîne est incomplète. La cause ET la preuve de
  // blocage doivent être exactes — jamais un statut optimiste.
  const blocked = ALL.filter((l) => l.mapping_status === 'BLOCKED');
  assert.ok(blocked.length > 0, 'au moins une ligne BLOCKED attendue (AFTU 47/52)');
  for (const l of blocked) {
    assert.ok(l.blocking.feed_route_ids_present.length > 0);
    assert.ok(l.blocking.missing_fields.includes('trip_id') ||
      l.blocking.missing_fields.includes('stop_times'),
      `${l.public_label} : maillon manquant non documenté`);
  }
  const byNumber = Object.fromEntries(blocked.map((l) => [l.line_number, l]));
  assert.ok(byNumber['47'], 'AFTU 47 attendue BLOCKED (FEED_ROUTE_WITHOUT_TRIP)');
  assert.equal(byNumber['47'].unresolved_reason, 'FEED_ROUTE_WITHOUT_TRIP');
  assert.ok(byNumber['52'], 'AFTU 52 attendue BLOCKED (FEED_ROUTE_WITHOUT_STOP_TIME)');
  assert.equal(byNumber['52'].unresolved_reason, 'FEED_ROUTE_WITHOUT_STOP_TIME');
});

test('une variante lettrée documente la route au numéro nu SANS la fusionner', () => {
  // DDD 502A/502B : le feed porte `DDD_502` (numéro nu) mais AUCUNE route
  // « 502A/502B ». La fusion est interdite : la preuve de blocage cite la route
  // au numéro nu comme À NE PAS fusionner, et `feed_route_ids` reste vide.
  for (const num of ['502A', '502B', '503A', '503B', '504A', '504B']) {
    const l = REF.ddd.find((x) => x.line_number === num);
    assert.ok(l, `DDD ${num} absente`);
    assert.equal(l.mapping_status, 'NOT_VERIFIED');
    assert.equal(l.feed_route_ids.length, 0);
    assert.ok(l.blocking.bare_number_route_ids.length > 0,
      `DDD ${num} : route au numéro nu non documentée`);
  }
});

// ---------------------------------------------------------------------------
// PORTE DE RACCORDEMENT HONNÊTE (§6 / §15 / §19).
//
// Une ligne publique OFFICIELLEMENT PUBLIÉE dont le feed actuel ne permet pas le
// raccordement reste explicitement non raccordée : c'est un état honnête, pas un
// échec. Ce qui échoue, c'est FABRIQUER un raccordement pour atteindre 100 %.
// Cette porte vérifie donc :
//   * chaque ligne CONNECTED expose la chaîne COMPLÈTE + un départ exploitable ;
//   * chaque ligne non raccordée est honnête (cause + preuve, aucun faux horaire) ;
//   * aucune identité publique n'est supprimée ;
//   * aucun compteur n'est trafiqué.
// Elle interdit toute dérive optimiste : le seul chemin vers un CONNECTED
// supplémentaire est une donnée source réellement publiée.
// ---------------------------------------------------------------------------

test('chaque ligne CONNECTED expose la chaîne complète ET un départ exploitable',
  () => {
    for (const l of ALL) {
      if (l.mapping_status !== 'CONNECTED') continue;
      assert.ok(l.feed_route_ids.length > 0, `${l.public_label} : route_id`);
      assert.ok(l.trip_ids_count > 0, `${l.public_label} : trip_id`);
      assert.ok(l.direction_ids.length > 0, `${l.public_label} : direction_id`);
      assert.ok(l.stop_times_count > 0, `${l.public_label} : stop_times`);
      assert.ok(l.served_stop_count > 0, `${l.public_label} : stop_id`);
      assert.equal(l.stop_sequence_present, true, `${l.public_label} : stop_sequence`);
      // ≥ 2 arrêts sur un trip → au moins un prochain départ calculable.
      assert.ok(l.served_stop_count >= 2,
        `${l.public_label} : aucun départ exploitable (< 2 arrêts)`);
      assert.equal(l.unresolved_reason, null);
    }
  });

test('les 16 identités publiées non raccordables restent honnêtes (jamais fabriquées)',
  () => {
    // Baseline issue de la recherche exhaustive du 2026-09-30 : le feed ne
    // permet pas le raccordement (AFTU 47 sans trip, AFTU 52 sans stop_time,
    // 14 identités DDD sans route au numéro). Elles doivent rester présentes,
    // non raccordées, avec cause + preuve — et ne JAMAIS devenir CONNECTED sans
    // preuve opérationnelle nouvelle.
    const baseline = [
      'AFTU 47', 'AFTU 52',
      'DDD 502A', 'DDD 502B', 'DDD 503A', 'DDD 503B', 'DDD 504A', 'DDD 504B',
      'DDD TO1', 'DDD TAF', 'DDD TAF TAF', 'DDD 15A', 'DDD 15B',
      'DDD 16A', 'DDD 16B', 'DDD 327',
    ];
    const byLabel = new Map(ALL.map((l) => [l.public_label, l]));
    for (const label of baseline) {
      const l = byLabel.get(label);
      assert.ok(l, `${label} : identité publique supprimée du référentiel`);
      assert.notEqual(l.mapping_status, 'CONNECTED',
        `${label} : déclarée CONNECTED sans preuve opérationnelle nouvelle`);
      assert.equal(l.schedule_status, 'NO_SCHEDULE', `${label} : faux horaire`);
      assert.equal(l.served_stop_count, 0, `${label} : arrêts sans horaire`);
      assert.equal(l.stop_times_count, 0, `${label} : stop_times sans horaire`);
      assert.ok(l.unresolved_reason, `${label} : cause absente`);
      assert.ok(l.blocking, `${label} : preuve de blocage absente`);
    }
    assert.equal(REF.unresolved_public_lines.length, baseline.length,
      'la liste des lignes non raccordées a changé sans preuve documentée');
  });
