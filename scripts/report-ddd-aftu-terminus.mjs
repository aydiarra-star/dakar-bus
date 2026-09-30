// Chantier DDD / AFTU / TATA — RAPPORT DE COMPLÉTUDE (§17).
//
// Détecte, sans jamais compléter artificiellement, ce qui reste UNKNOWN :
//   * ligne DDD / AFTU sans terminus confirmé ;
//   * ligne avec un seul terminus alors que deux sont documentés ;
//   * terminus sans source ;
//   * ligne associée à un pôle uniquement par proximité ;
//   * TATA sans preuve documentaire.
//
// Usage :
//   node scripts/report-ddd-aftu-terminus.mjs         # texte
//   node scripts/report-ddd-aftu-terminus.mjs --md    # Markdown
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const ref = JSON.parse(
  readFileSync(resolve(ROOT, 'data/reference/ddd_aftu_poles_terminus.json'), 'utf8'),
);
const md = process.argv.includes('--md');
const out = (s = '') => console.log(s);

function block(title) {
  if (md) out(`\n### ${title}\n`);
  else out(`\n=== ${title} ===`);
}

if (md) out('# Rapport de complétude DDD / AFTU / TATA\n');

for (const net of ['ddd', 'aftu']) {
  const d = ref[net];
  const label = net.toUpperCase();
  block(`${label} — synthèse`);
  out(`- lignes analysées : ${d.totalRoutes}`);
  out(`- terminus A confirmés : ${d.terminusAConfirmed}`);
  out(`- terminus B confirmés : ${d.terminusBConfirmed}`);
  out(`- lignes UNKNOWN : ${d.unknownRoutes.length} ${d.unknownRoutes.join(', ')}`);
  out(`- lignes CONFLICTING : ${d.conflictingRoutes.length} ${d.conflictingRoutes.join(', ')}`);
  out(`- terminus distincts : ${d.terminusCount}`);

  block(`${label} — lignes sans terminus confirmé (UNKNOWN)`);
  const sansTerm = d.completeness.filter((c) => c.issue === 'LIGNE_SANS_TERMINUS_CONFIRME');
  if (sansTerm.length === 0) out('- (aucune)');
  for (const c of sansTerm) out(`- ${c.routeId} : ${c.detail}`);

  block(`${label} — terminus à confirmer (CONFLICTING / CANDIDATE)`);
  const aConf = d.completeness.filter((c) => c.issue === 'TERMINUS_A_CONFIRMER');
  if (aConf.length === 0) out('- (aucune)');
  for (const c of aConf) out(`- ${c.routeId} : ${c.detail}`);

  block(`${label} — terminus uniques alors que deux sont documentés`);
  const single = d.completeness.filter(
    (c) => c.issue === 'TERMINUS_UNIQUE_ALORS_QUE_DEUX_SONT_DOCUMENTES');
  if (single.length === 0) out('- (aucune)');
  for (const c of single) out(`- ${c.routeId} : ${c.detail}`);
}

block('TATA — associations');
out(`- associations confirmées : ${ref.tata.confirmedAssociations.length}`);
out(`- associations non confirmées : ${ref.tata.unconfirmedAssociations.length}`);
out(`- ${ref.tata.note}`);

block('Intégrité (§13) — aucun terminus par proximité');
out(`- associations pôle→ligne par proximité seule : ${ref.integrity.poleRouteAssociationsByProximityOnly.length}`);
for (const x of ref.integrity.poleRouteAssociationsByProximityOnly) out(`  - ${x}`);
out(`- terminus sans source : ${ref.integrity.terminiWithoutSource.length}`);
out(`- lignes à terminus unique : ${ref.integrity.linesWithSingleTerminus.length} ${ref.integrity.linesWithSingleTerminus.join(', ')}`);

block('Pôles (périmètre §3–§5 + découverts)');
if (md) out('| pôle | statut | rôles | DDD terminus | AFTU terminus | coord |');
if (md) out('|---|---|---|---|---|---|');
for (const p of ref.poles) {
  const roles = p.roles.join(', ');
  if (md) {
    out(`| ${p.name} | ${p.status} | ${roles} | ${p.dddRoutes.length} | ${p.aftuRoutes.length} | ${p.coordinatesStatus} |`);
  } else {
    out(`- ${p.name} [${p.status}] (${roles}) DDD=${p.dddRoutes.length} AFTU=${p.aftuRoutes.length} coord=${p.coordinatesStatus}`);
  }
}

if (md) {
  block('Liste complète des terminus');
  for (const net of ['ddd', 'aftu']) {
    out(`\n**${net.toUpperCase()}** (${ref[net].terminusCount}) : `);
    out(ref[net].terminusNames.join(' · '));
  }
}
