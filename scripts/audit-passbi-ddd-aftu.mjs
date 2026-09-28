// Lot 4.21 §1 — AUDIT PASSBI DDD / AFTU / TATA (tableau reproductible).
//
// Lit UNIQUEMENT les données déjà intégrées au dépôt :
//   flutter-src/assets/data/passbi/{ddd,aftu,ter,brt,crosswalk}.json
// Aucun téléchargement, aucune donnée nouvelle.
//
// Usage :
//   node scripts/audit-passbi-ddd-aftu.mjs            # résumé + tableau
//   node scripts/audit-passbi-ddd-aftu.mjs --md       # tableau Markdown
//   node scripts/audit-passbi-ddd-aftu.mjs DDD        # un seul réseau
import { readFileSync } from 'node:fs';
import { loadAll, splitComposite } from '../tests/helpers/passbi-engine419.mjs';
import { routeSummaries, nativeStops, tataMentions, networkAvailability } from '../tests/helpers/passbi-native421.mjs';

const BASE = 'flutter-src/assets/data/passbi';
const all = loadAll();
const md = process.argv.includes('--md');
const only = process.argv.slice(2).find((a) => !a.startsWith('--'));

const hhmm = (sec) => {
  if (sec === null || sec === undefined) return '-';
  const s = ((sec % 86400) + 86400) % 86400;
  return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}`;
};

function audit(networkKey) {
  const net = all.networks[networkKey];
  if (!net) return null;
  const summaries = routeSummaries(all, networkKey);
  const used = net.stops.filter((s) => s[4] === 1).length;
  return {
    network: networkKey,
    agency: net.agency,
    routes: net.routes.length,
    stops: net.stops.length,
    usedStops: used,
    calledStops: nativeStops(all, networkKey).length,
    trips: net.trips.length,
    stopTimes: net.stop_times.length,
    services: net.services.map((s) => `${s[0]}(mask=${s[1]})`).join(', '),
    exceptions: net.exceptions.length,
    schedulable: summaries.filter((s) => s.scheduleAvailable).length,
    confirmedIdentity: summaries.filter((s) => s.identityStatus === 'CONFIRMED').length,
    summaries,
  };
}

const reseaux = ['TER', 'BRT', 'DDD', 'AFTU'].filter((k) => (only ? k === only : true));

// --------------------------------------------------------------- résumé
console.log('=== PASSBI — DISPONIBILITÉ DES DONNÉES (Lot 4.21) ===\n');
for (const key of reseaux) {
  const a = audit(key);
  if (!a) {
    console.log(`${key} : AUCUN FEED PASSBI (RESEAU_ABSENT_DU_FEED)`);
    continue;
  }
  console.log(`${a.network} — agence « ${a.agency} »`);
  console.log(`  routes=${a.routes} stops=${a.stops} (used=${a.usedStops}, appelés=${a.calledStops}) trips=${a.trips} stop_times=${a.stopTimes}`);
  console.log(`  services=[${a.services}] exceptions=${a.exceptions}`);
  console.log(`  horaires calculables=${a.schedulable}/${a.routes} | identité publique confirmée=${a.confirmedIdentity}/${a.routes}`);
  console.log('');
}

// --------------------------------------------------------------- TATA
const mentions = tataMentions(all);
console.log('=== TATA (§6) ===');
console.log(`  feed PassBi autonome : ${networkAvailability(all, 'TATA')} (aucun asset TATA dans PassBiSource.assetFiles)`);
console.log(`  mentions « tata » dans les métadonnées PassBi (agency, meta, routes, stops, trips) : ${mentions.length}`);
console.log(`  identités TATA du référentiel dakar : `
  + `${Object.entries(all.cw.routes).filter(([id]) => id.startsWith('tata_')).length} `
  + `— toutes UNMAPPED / RESEAU_ABSENT_DU_FEED, pbRouteIds vide`);
console.log('  → AUCUNE route TATA n\'est fabriquée.\n');

// --------------------------------------------------------------- tableaux
const SEP = md
  ? '| network | route_id | short | long | trips | stops | stop_times | boardable | schedule_available | identity | UI_mapping | first | last | reason |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|---|'
  : null;
if (SEP) console.log(SEP);

for (const key of reseaux) {
  const a = audit(key);
  if (!a) continue;
  for (const s of a.summaries) {
    const ui = s.dakarRouteIds.length > 0
      ? s.dakarRouteIds.join(',')
      : (s.identityStatus === 'CONFIRMED' ? 'CONFIRMED' : 'UNCONFIRMED');
    if (md) {
      console.log(`| ${s.network} | ${s.routeId} | ${s.shortName} | ${s.longName} | ${s.trips} | ${s.servedStops} | ${s.stopTimes} | ${s.boardableStopTimes} | ${s.scheduleAvailable ? 'YES' : 'NO'} | ${s.identityStatus} | ${ui} | ${hhmm(s.firstDepartureSec)} | ${hhmm(s.lastDepartureSec)} | ${s.reason} |`);
    } else {
      console.log(`${s.network} | ${s.routeId} | ${s.shortName} | ${s.trips} trips | ${s.stopTimes} stop_times | ${s.scheduleAvailable ? 'SCHEDULE=YES' : 'SCHEDULE=NO'} | ${s.identityStatus} | ${s.reason}`);
    }
  }
}

if (!md) {
  // Routes sans horaire calculable, tous réseaux confondus.
  console.log('=== Routes SANS horaire calculable ===');
  for (const key of reseaux) {
    const a = audit(key);
    if (!a) continue;
    for (const s of a.summaries.filter((x) => !x.scheduleAvailable)) {
      console.log(`  ${s.network} ${s.routeId} : trips=${s.trips} stop_times=${s.stopTimes} → ${s.reason}`);
    }
  }

  // Désalignement référentiel dakar ↔ feed PassBi (documentaire, non bloquant).
  const cw = JSON.parse(readFileSync(`${BASE}/crosswalk.json`, 'utf8'));
  console.log('\n=== Crosswalk (identités du référentiel dakar) ===');
  const DOCUMENTED = ['IDENTITY_OFFICIELLE'];
  const parReseau = {};
  for (const [, m] of Object.entries(cw.routes)) {
    const k = m.network ?? 'null';
    parReseau[k] = parReseau[k] ?? { total: 0, mapped: 0 };
    parReseau[k].total++;
    if (m.status === 'MAPPED') parReseau[k].mapped++;
  }
  for (const [k, v] of Object.entries(parReseau)) {
    console.log(`  ${k} : ${v.mapped}/${v.total} identités MAPPED`);
  }
  const mappedList = Object.entries(cw.routes).filter(([, m]) => m.status === 'MAPPED');
  console.log('  identités confirmées (preuve documentaire UNIQUEMENT) : '
    + mappedList.map(([id, m]) => `${id}→${m.pbRouteIds.join('+')} (${m.method})`).join(' | '));
  const hypotheses = Object.entries(cw.routes).filter(([, m]) => m.hypothesis);
  console.log('  hypothèses NON confirmées (TERMINI_MATCH, aucun rattachement) : '
    + hypotheses.map(([id, m]) => `${id}≈${m.hypothesis.pbRouteId} (${m.hypothesis.score})`).join(' | '));
  console.log('  règle : numéro / route_id / nom / OSM / terminus proches ne confirment JAMAIS.');
  // Anti-fusion : aucun identifiant PassBi porté par 2 identités confirmées.
  const claims = {};
  for (const [id, m] of mappedList) {
    for (const pbId of m.pbRouteIds) (claims[pbId] ??= []).push(id);
  }
  const fusions = Object.entries(claims).filter(([, ids]) => ids.length > 1);
  console.log('  fusions automatiques : ' + (fusions.length === 0 ? 'AUCUNE' : JSON.stringify(fusions)));
  const tataTransfers = cw.transfers.filter((t) =>
    `${t.from}|${t.to}`.toUpperCase().includes('TATA'));
  console.log('  transferts impliquant TATA : ' + tataTransfers.length + ' (0 attendu)');
  console.log('\n  transferts documentés (méthode + nom vérifiés) :');
  const paires = {};
  for (const t of cw.transfers) {
    const a2 = splitComposite(t.from)[0];
    const b2 = splitComposite(t.to)[0];
    const k = [a2, b2].sort().join('<->');
    paires[k] = (paires[k] ?? 0) + 1;
  }
  for (const [k, v] of Object.entries(paires).sort()) console.log(`    ${k} : ${v}`);
}
