// MISSION — CONTRÔLE FORT DE RACCORDEMENT (§6 / §15).
//
// Pour CHAQUE ligne publique AFTU / DDD du référentiel
// (`data/reference/public_bus_lines_dakar.json`), on re-dérive la chaîne de
// raccordement horaire directement depuis les feeds PassBi embarqués et on
// vérifie qu'elle est réellement complète :
//
//   line_number → operator → route_id → trip_id → direction_id → stop_id
//   → stop_sequence → stop_times
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
    if (!ev.has(id)) ev.set(id, { trips: 0, dirs: new Set(), stops: new Set(), st: 0 });
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
    if (!l.feed_route_ids || l.feed_route_ids.length === 0) {
      problems.push(l.unresolved_reason ?? 'aucun route_id raccordé');
    } else {
      // Aucun raccordement fabriqué : le route_id doit porter le numéro public.
      const expected = new Set(feed.byNumber.get(String(Number(l.line_number))) ?? []);
      for (const rid of l.feed_route_ids) {
        if (!expected.has(rid)) {
          problems.push(`route_id ${rid} non corrélé au numéro ${l.line_number} (raccordement fabriqué ?)`);
          continue;
        }
        const e = feed.ev.get(rid);
        if (!e || e.trips === 0) problems.push(`route ${rid} sans trip réel`);
        if (!e || e.dirs.size === 0) problems.push(`route ${rid} sans direction_id réel`);
        if (!e || e.st === 0) problems.push(`route ${rid} sans stop_time`);
        if (!e || e.stops.size === 0) problems.push(`route ${rid} sans stop_id réel`);
      }
    }
    if (l.served_stop_count === 0) problems.push('served_stop_count = 0');
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
if (failures.length > 0) {
  console.error('');
  console.error(`ÉCHEC DE COMPLÉTUDE : ${failures.length} ligne(s) publique(s) AFTU/DDD non raccordée(s) :`);
  for (const f of failures) console.error(`  - ${f.label} : ${f.problems.join(' ; ')}`);
  console.error('');
  console.error('Le chantier n’est PAS terminé : 100 % des lignes publiques doivent être raccordées.');
  process.exit(1);
}
console.log('COMPLET : 100 % des lignes publiques AFTU/DDD sont raccordées aux horaires réels.');
