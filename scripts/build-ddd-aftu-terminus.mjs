// Chantier DDD / AFTU / TATA — GÉNÉRATEUR du référentiel pôles & terminus.
//
// Lit les feeds PassBi déjà intégrés et écrit :
//   * data/reference/ddd_aftu_poles_terminus.json      (rapport/source de vérité)
//   * flutter-src/assets/data/reference/ddd_aftu_poles_terminus.json (asset app)
//
// Le référentiel est DÉRIVÉ (aucune saisie manuelle d'arrêt, de coordonnée ou
// de ligne) ; les seules entrées humaines sont les LIBELLÉS OFFICIELS publiés
// par l'opérateur (`officialLabels`), utilisés uniquement pour QUALIFIER une
// contradiction du feed — jamais pour fabriquer un terminus.
//
// Usage : node scripts/build-ddd-aftu-terminus.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { buildReference } from './lib/ddd-aftu-terminus.mjs';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const DDD = resolve(ROOT, 'flutter-src/assets/data/passbi/ddd.json');
const AFTU = resolve(ROOT, 'flutter-src/assets/data/passbi/aftu.json');

// Libellés officiels documentés (docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md)
// fournis UNIQUEMENT pour les routes où le sens retour du feed contredit le
// libellé publié. Aucune autre route n'est qualifiée par un libellé.
const OFFICIAL_LABELS = {
  DDD_16: 'MALIKA ↔ PALAIS 1',
  DDD_23: 'PARCELLES ASSAINIES ↔ PALAIS 1',
  DDD_15: 'RUFISQUE ↔ PALAIS 1',
};

const generatedAt = new Date().toISOString().slice(0, 10);
const ref = buildReference({
  dddPath: DDD,
  aftuPath: AFTU,
  generatedAt,
  officialLabels: OFFICIAL_LABELS,
});

const json = JSON.stringify(ref, null, 2) + '\n';
for (const out of [
  resolve(ROOT, 'data/reference/ddd_aftu_poles_terminus.json'),
  resolve(ROOT, 'flutter-src/assets/data/reference/ddd_aftu_poles_terminus.json'),
]) {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, json);
}

console.log(`DDD : ${ref.ddd.totalRoutes} lignes, ${ref.ddd.terminusAConfirmed} terminus A, `
  + `${ref.ddd.terminusBConfirmed} terminus B, ${ref.ddd.unknownRoutes.length} UNKNOWN, `
  + `${ref.ddd.conflictingRoutes.length} CONFLICTING, ${ref.ddd.candidateRoutes.length} CANDIDATE`);
console.log(`AFTU : ${ref.aftu.totalRoutes} lignes, ${ref.aftu.terminusAConfirmed} terminus A, `
  + `${ref.aftu.terminusBConfirmed} terminus B, ${ref.aftu.unknownRoutes.length} UNKNOWN, `
  + `${ref.aftu.conflictingRoutes.length} CONFLICTING, ${ref.aftu.candidateRoutes.length} CANDIDATE`);
console.log(`Pôles : ${ref.poles.filter((p) => p.isTerminal).length}/${ref.poles.length} avec terminus DDD/AFTU`);
for (const p of ref.poles) {
  console.log(`  ${p.name} → DDD ${p.dddRoutes.length} | AFTU ${p.aftuRoutes.length} | ${p.status} | ${p.coordinatesStatus}`);
}
