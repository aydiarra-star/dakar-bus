// MISSION — CONTRÔLE FORT DE RACCORDEMENT (§6 / §15) + HONNÊTETÉ DU STATUT (§9).
//
// Pour CHAQUE ligne publique AFTU / DDD du référentiel
// (`data/reference/public_bus_lines_dakar.json`), on re-dérive la chaîne de
// raccordement horaire directement depuis les feeds PassBi embarqués et on
// vérifie qu'elle est réellement complète :
//
//   line_number → operator → route_id → trip_id → direction_id → stop_id
//   → stop_sequence → stop_times
//
// On vérifie EN PLUS la cohérence de `mapping_status` : `CONNECTED` est
// IMPOSSIBLE sans la chaîne complète, et toute ligne non raccordée doit porter
// une cause exacte (`unresolved_reason`) ET une preuve de blocage (`blocking`).
//
// Toute ligne publique NON raccordée fait ÉCHOUER la validation (code 1) et est
// listée avec sa cause exacte. Aucun défaut n'est masqué par NO_SCHEDULE /
// UNKNOWN / PARTIAL. Aucun raccordement n'est fabriqué (le route_id doit
// correspondre au numéro public de l'opérateur, jamais une similarité de nom).
//
// Usage : node scripts/validate-public-bus-lines.mjs
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const REF = JSON.parse(
  readFileSync(resolve(ROOT, 'data/reference/public_bus_lines_dakar.json'), 'utf8'));

function feedEvidence(path, prefix) {
  const feed = JSON.parse(readFileSync(path, 'utf8'));
  const routeIdByIndex = feed.routes.map((r) => r.id);
  const tripRouteIndex = feed.trips.map((t) => t[1]);
  const byNumber = new Map();
  for (const r of feed.routes) {
    const m = new RegExp(`^${prefix}_(\\d+)$`).exec(r.id);
    if (!m) continue;
    const num = String(Number(m[1]));
    if (!byNumber.has(num)) byNumber.set(num, []);
    byNumber.get(num).push(r.id);
  }
  const ev = new Map();
  const ensure = (id) => {
    if (!ev.has(id)) ev.set(id, { trips: 0, dirs: new Set(), stops: new Set(), st: 0, seq: new Set() });
    return ev.get(id);
  };
  for (const id of routeIdByIndex) ensure(id);
  for (const t of feed.trips) {
    const e = ensure(routeIdByIndex[t[1]]);
    e.trips += 1;
    e.dirs.add(String(t[3]));
  }
  for (const s of feed.stop_times) {
    const e = ensure(routeIdByIndex[tripRouteIndex[s[0]]]);
    e.st += 1;
    e.stops.add(s[1]);
    e.seq.add(s[2] === null || s[2] === undefined ? null : Number(s[2]));
  }
  return { byNumber, ev };
}

const AFTU = feedEvidence(resolve(ROOT, 'flutter-src/assets/data/passbi/aftu.json'), 'AFTU');
const DDD = feedEvidence(resolve(ROOT, 'flutter-src/assets/data/passbi/ddd.json'), 'DDD');

const failures = [];
const linked = [];

for (const [network, feed] of [['AFTU', AFTU], ['DDD', DDD]]) {
  const lines = REF[network.toLowerCase()];
  for (const l of lines) {
    const problems = [];
    if (!l.line_number) problems.push('line_number absent');
    if (l.operator !== network) problems.push('operator incohérent');

    // Chaîne dérivée du feed : ce que la ligne DEVRAIT déclarer.
    const routeIds = l.feed_route_ids ?? [];
    let chainComplete = routeIds.length > 0;
    for (const rid of routeIds) {
      // Aucun raccordement fabriqué : le route_id doit porter le numéro public.
      const expected = new Set(feed.byNumber.get(String(Number(l.line_number))) ?? []);
      if (!expected.has(rid)) {
        problems.push(`route_id ${rid} non corrélé au numéro ${l.line_number} (raccordement fabriqué ?)`);
        chainComplete = false;
        continue;
      }
      const e = feed.ev.get(rid);
      if (!e || e.trips === 0) { problems.push(`route ${rid} sans trip réel`); chainComplete = false; }
      if (!e || e.dirs.size === 0) { problems.push(`route ${rid} sans direction_id réel`); chainComplete = false; }
      if (!e || e.st === 0) { problems.push(`route ${rid} sans stop_time`); chainComplete = false; }
      if (!e || e.stops.size === 0) { problems.push(`route ${rid} sans stop_id réel`); chainComplete = false; }
      if (!e || e.seq.has(null)) { problems.push(`route ${rid} sans stop_sequence`); chainComplete = false; }
    }

    // Honnêteté du statut : CONNECTED exigé si la chaîne est complète, interdit
    // sinon. Le statut déclaré doit refléter la chaîne réelle.
    const declaredConnected = l.mapping_status === 'CONNECTED';
    if (chainComplete && !declaredConnected) {
      problems.push(`chaîne complète mais mapping_status = ${l.mapping_status}`);
    }
    if (!chainComplete && declaredConnected) {
      problems.push('mapping_status = CONNECTED sans chaîne complète');
    }

    // Cohérence interne du statut déclaré.
    if (declaredConnected) {
      if (!l.stop_sequence_present) problems.push('CONNECTED sans stop_sequence_present');
      if (l.schedule_status !== 'SCHEDULE_AVAILABLE') problems.push('CONNECTED sans SCHEDULE_AVAILABLE');
      if (l.unresolved_reason != null) problems.push('CONNECTED avec unresolved_reason');
      if (l.blocking != null) problems.push('CONNECTED avec blocking');
    } else {
      // PORTE DE COMPLÉTUDE : toute ligne non raccordée fait échouer la
      // validation, quelle qu'en soit la cause (BLOCKED ou NOT_VERIFIED).
      problems.push(`NON RACCORDÉE [${l.mapping_status}] : ${l.unresolved_reason ?? 'cause absente'}`);
      if (!l.unresolved_reason) problems.push('ligne non raccordée sans cause exacte');
      if (!l.blocking) problems.push('ligne non raccordée sans preuve de blocage');
      if (l.mapping_status === 'BLOCKED' && routeIds.length === 0) {
        problems.push('BLOCKED sans aucune route présente dans le feed');
      }
      if (l.mapping_status === 'NOT_VERIFIED' && routeIds.length > 0) {
        problems.push('NOT_VERIFIED avec un route_id déclaré');
      }
    }

    if (l.served_stop_count === 0 && declaredConnected) problems.push('CONNECTED avec served_stop_count = 0');
    if (l.schedule_status === 'SCHEDULE_AVAILABLE' && (l.stop_times_count ?? 0) === 0) {
      problems.push('SCHEDULE_AVAILABLE sans stop_times réels');
    }
    if (problems.length > 0) {
      failures.push({ label: l.public_label, problems });
    } else {
      linked.push(l.public_label);
    }
  }
}

console.log(`Raccordement vérifié : ${linked.length} lignes publiques AFTU/DDD OK.`);
console.log(`Statuts : CONNECTED=${REF.counts.connected} BLOCKED=${REF.counts.blocked} ` +
  `NOT_VERIFIED=${REF.counts.not_verified} PARTIAL=${REF.counts.partial}`);
if (failures.length > 0) {
  console.error('');
  console.error(`ÉCHEC DE COMPLÉTUDE : ${failures.length} ligne(s) publique(s) AFTU/DDD non raccordée(s) :`);
  for (const f of failures) console.error(`  - ${f.label} : ${f.problems.join(' ; ')}`);
  console.error('');
  console.error('Le chantier n’est PAS terminé : 100 % des lignes publiques doivent être raccordées.');
  process.exit(1);
}
console.log('COMPLET : 100 % des lignes publiques AFTU/DDD sont raccordées aux horaires réels.');
