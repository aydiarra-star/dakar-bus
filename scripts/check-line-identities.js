#!/usr/bin/env node
'use strict';
// LOT 15 — Contrôle des identités publiques de lignes (axe IDENTIFIANT uniquement).
//
// Objet : rendre IMPOSSIBLE l'intégration d'une correspondance « publique »
// fondée sur une simple ressemblance. Une identité ne peut porter un numéro
// officiel que si ce numéro est explicitement soutenu par une preuve
// documentée (référentiel canonique AFTU/Tata/DDD, révision 1.1).
//
// Ce script ne modifie RIEN. Il lit, il vérifie, il sort en erreur (exit 1)
// dès qu'une règle est violée. Il ne touche ni arrêts, ni horaires, ni
// géométrie, ni fréquences, ni temps réel.
//
// Règles interdites explicitement (voir docs/INTEGRATION_IDENTITES_LIGNES_LOT15_2026-09-26.md §2) :
//   même numéro · nom similaire · même origine · même destination ·
//   proximité géographique · OSM seul · Moovit.
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
// Par défaut : la donnée de production. Un chemin peut être fourni en argument
// pour éprouver le contrôle sur une COPIE (tests négatifs), sans jamais écrire
// dans le dépôt.
const DATA = process.argv[2] ? path.resolve(process.argv[2]) : path.join(root, 'flutter-src/assets/data/dakar_network.json');

// ─── Champs d'identité : les 4 seuls autorisés (§9-1 / PR #28). Aucun autre. ───
const IDENTITY_FIELDS = [
  'official_identifier_status',
  'official_identifier_note',
  'official_number_observed',
  'official_number_belongs_to',
];
const STATUSES = new Set(['CONFIRMED', 'MISSING', 'CONFLICTING', 'UNKNOWN']);
const OWNERS = new Set(['AFTU', 'DDD', 'TATA']);

// ─── Référentiel officiel AFTU (référentiel canonique rév. 1.1, §A.1). ───
// Plage publiée : 1–5, 24–89, 91. Trous documentés : 6–23, 90.
const AFTU_OFFICIAL_NUMBERS = new Set([1, 2, 3, 4, 5, ...[...Array(66).keys()].map(i => i + 24), 91]);
// Collisions de numéros inter-réseaux documentées (§F.2) : deux lignes distinctes.
const DOCUMENTED_INTER_NETWORK_COLLISIONS = new Map([
  [1, 'DDD'], [2, 'DDD'], [4, 'DDD'], [5, 'DDD'],
]);

// ─── Verrou d'intégrité : FNV-1a 32 des données PRÉEXISTANTES (les 4 champs ───
// retirés) sur les 105 routes, dans l'ordre du fichier. Valeur figée par le
// lot §9-1 et re-vérifiée au lot 15 : strictement inchangée par les ajouts.
const FNV_PREEXISTING_DATA = 0x0F206256;

// ─── Axe Tata/DDD figé par le lot §9-1 (doit rester intact). ───
const FROZEN_22 = {
  tata_50: ['CONFLICTING', true, 'AFTU'],
  tata_64: ['CONFLICTING', true, 'AFTU'],
  tata_78: ['CONFLICTING', true, 'AFTU'],
  tata_218: ['CONFLICTING', true, 'DDD'],
  tata_219: ['CONFLICTING', true, 'DDD'],
  new_commune_11: ['MISSING', false, null],
  new_commune_12: ['MISSING', false, null],
  ddd_1: ['CONFLICTING', true, 'DDD'],
  ddd_3: ['MISSING', false, null],
  ddd_7: ['CONFLICTING', true, 'DDD'],
  ddd_8: ['CONFLICTING', true, 'DDD'],
  ddd_9: ['CONFLICTING', true, 'DDD'],
  ddd_10: ['CONFLICTING', true, 'DDD'],
  ddd_11: ['CONFLICTING', true, 'DDD'],
  ddd_12: ['CONFLICTING', true, 'DDD'],
  ddd_14: ['MISSING', false, null],
  ddd_15: ['CONFLICTING', true, 'DDD'],
  ddd_20: ['CONFLICTING', true, 'DDD'],
  ddd_23: ['CONFLICTING', true, 'DDD'],
  new_commune_01: ['MISSING', false, null],
  new_commune_02: ['MISSING', false, null],
  new_commune_13: ['MISSING', false, null],
};

// ─── Registre des preuves autorisant un statut CONFIRMED. ───
// VIDE À DESSEIN : aucune identité publique n'est démontrée par les sources
// actuellement disponibles. Toute route qui se déclarerait CONFIRMED sans
// entrée nominative ici est un ÉCHEC du contrôle.
const CONFIRMED_EVIDENCE_REGISTRY = new Map(); // internal_id -> {source, date, proof}

// ─── Vocabulaire interdit : jamais une preuve. ───
const FORBIDDEN_JUSTIFICATIONS = /(probablement|vraisemblablement|ressemble|semble|semblerait|proximité géographique|osm|moovit|même numéro|même trajet|homonymie)/i;

const issues = [];
const fail = (code, id, detail) => issues.push({ code, id, detail });
const ok = [];
const note = (m) => ok.push(m);

// ─── Sérialisation canonique, identique au test Dart §9-1. ───
const render = (v) => {
  if (v === null) return '~';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number') return Number.isInteger(v) ? `i${v}` : `f${v}`;
  if (typeof v === 'string') return `@${v}`;
  if (Array.isArray(v)) return `[${v.map(render).join('\u0003')}]`;
  if (typeof v === 'object') return `{${Object.keys(v).map(k => `${k}:${render(v[k])}`).join('\u0004')}}`;
  throw new Error(`Type JSON non géré : ${typeof v}`);
};
// FNV-1a 32 bits sur les unités de code UTF-16.
// Math.imul reproduit exactement le produit modulo 2^32 de Dart (& 0xFFFFFFFF) ;
// une multiplication flottante perdrait la précision au-delà de 2^53.
const fnv1a32 = (s) => {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 0x01000193) >>> 0;
  return h;
};

const raw = JSON.parse(fs.readFileSync(DATA, 'utf8'));
const routes = raw.routes;
const byId = new Map(routes.map(r => [r.id, r]));

// ─── R1 — Non-régression : aucune donnée préexistante modifiée. ───
{
  const d = fnv1a32(routes
    .map(r => Object.keys(r).filter(k => !IDENTITY_FIELDS.includes(k))
      .map(k => `${k}=${render(r[k])}`).join('\u0001'))
    .join('\u0002'));
  if (d !== FNV_PREEXISTING_DATA) {
    fail('PREEXISTING_DATA_MODIFIED', '*',
      `empreinte 0x${d.toString(16).toUpperCase().padStart(8, '0')} ≠ attendu 0x0F206256`);
  } else {
    note(`R1 non-régression : FNV-1a des données préexistantes = 0x0F206256 (inchangée)`);
  }
}

// ─── R2 — Périmètre : les 4 champs présents ensemble, et seulement là. ───
const carriers = routes.filter(r => IDENTITY_FIELDS.some(f => f in r));
for (const r of routes) {
  const present = IDENTITY_FIELDS.filter(f => f in r);
  if (present.length !== 0 && present.length !== IDENTITY_FIELDS.length) {
    fail('PARTIAL_IDENTITY_FIELDS', r.id, `champs partiels : ${present.join(', ')}`);
  }
}
const aftu = routes.filter(r => r.operator_id === 'aftu');
for (const r of aftu) {
  const present = IDENTITY_FIELDS.filter(f => f in r);
  if (present.length !== IDENTITY_FIELDS.length) fail('AFTU_IDENTITY_MISSING', r.id, 'les 4 champs sont requis');
}
for (const id of Object.keys(FROZEN_22)) {
  if (!byId.has(id)) fail('FROZEN_ROUTE_MISSING', id, 'route du lot §9-1 introuvable');
}
const expectedCarriers = new Set([...Object.keys(FROZEN_22), ...aftu.map(r => r.id)]);
for (const r of routes) {
  const has = IDENTITY_FIELDS.every(f => f in r);
  if (has && !expectedCarriers.has(r.id)) fail('UNEXPECTED_IDENTITY_CARRIER', r.id, 'hors périmètre');
  if (!has && expectedCarriers.has(r.id)) fail('MISSING_IDENTITY_CARRIER', r.id, 'dans le périmètre');
}
note(`R2 périmètre : ${expectedCarriers.size} routes porteuses (22 Tata/DDD + 80 AFTU) sur ${routes.length}`);

// ─── R3 — Aucun CONFIRMED sans preuve enregistrée. ───
for (const r of carriers) {
  if (r.official_identifier_status !== 'CONFIRMED') continue;
  const proof = CONFIRMED_EVIDENCE_REGISTRY.get(r.id);
  if (!proof || !proof.source || !proof.date || !proof.proof) {
    fail('UNPROVEN_CONFIRMED_IDENTITY', r.id,
      'CONFIRMED revendiqué sans preuve nominative au registre (inférence interdite)');
  }
}

// ─── R4/R5/R6/R7 — Par route : inférence, vocabulaire, collisions, invariants. ───
for (const r of carriers) {
  const st = r.official_identifier_status;
  const observed = r.official_number_observed;
  const belongs = r.official_number_belongs_to;
  const noteTxt = r.official_identifier_note;

  if (!STATUSES.has(st)) fail('INVALID_STATUS', r.id, `${st}`);
  if (typeof observed !== 'boolean') fail('INVALID_OBSERVED', r.id, `${observed}`);
  if (belongs !== null && !OWNERS.has(belongs)) fail('INVALID_OWNER', r.id, `${belongs}`);
  if (typeof noteTxt !== 'string' || noteTxt.trim() === '') fail('EMPTY_NOTE', r.id, 'motif documenté obligatoire');

  // R7 — invariants croisés : le statut et l'observation concordent strictement.
  if ((st === 'CONFLICTING') !== observed) fail('STATUS_OBSERVED_MISMATCH', r.id, `${st} / observed=${observed}`);
  if (observed !== (belongs !== null)) fail('OBSERVED_OWNER_MISMATCH', r.id, `observed=${observed} / belongs_to=${belongs}`);
  // Aucune ligne auditée ne reste indéterminée sur l'axe identifiant (§9-1) :
  // seuls CONFLICTING et MISSING sont admis, plus CONFIRMED sous preuve au
  // registre. UNKNOWN est refusé nommément.
  if (st === 'UNKNOWN') fail('UNDETERMINED_IDENTITY', r.id, 'UNKNOWN interdit sur l’axe identifiant (aucune ligne indéterminée)');
  if (st === 'CONFIRMED' && !CONFIRMED_EVIDENCE_REGISTRY.has(r.id)) {
    fail('UNPROVEN_CONFIRMED_IDENTITY', r.id, 'CONFIRMED hors registre des preuves');
  }

  // R4 — anti-inférence par le NUMÉRO : le numéro interne n'est jamais une preuve.
  // Un numéro n'est « observé » que s'il appartient à la plage publiée documentée.
  if (r.operator_id === 'aftu') {
    const m = /^aftu_(\d+)$/.exec(r.id);
    if (m) {
      const n = Number(m[1]);
      const inRange = AFTU_OFFICIAL_NUMBERS.has(n);
      if (observed !== inRange) {
        fail('NUMBER_INFERENCE', r.id,
          `observed=${observed} mais n°${n} ${inRange ? '∈' : '∉'} plage officielle AFTU (inférence par le numéro interdite)`);
      }
    } else if (observed) {
      fail('NUMBER_INFERENCE', r.id, 'identifiant technique déclaré porteur d’un numéro officiel');
    }
  }

  // R5 — aucune justification par ressemblance / OSM / Moovit.
  if (typeof noteTxt === 'string' && FORBIDDEN_JUSTIFICATIONS.test(noteTxt)) {
    fail('FORBIDDEN_JUSTIFICATION', r.id, 'justification non probante détectée dans la note');
  }
  if ('official_line_number' in r) {
    fail('FORBIDDEN_FIELD', r.id, 'official_line_number ne doit jamais être renseigné');
  }

  // R6 — collisions inter-réseaux documentées : signalées, jamais fusionnées.
  if (r.operator_id === 'aftu' && DOCUMENTED_INTER_NETWORK_COLLISIONS.has(Number(/^aftu_(\d+)$/.exec(r.id)?.[1]))) {
    const n = Number(/^aftu_(\d+)$/.exec(r.id)[1]);
    const other = DOCUMENTED_INTER_NETWORK_COLLISIONS.get(n);
    if (!noteTxt.includes(`${other} ${n}`)) {
      fail('UNDOCUMENTED_COLLISION', r.id, `collision avec ${other} ${n} non signalée dans la note`);
    }
  }
}

// ─── R8 — Notes non vides et distinctes. ───
{
  const notes = carriers.map(r => r.official_identifier_note);
  if (notes.some(n => typeof n !== 'string' || n.trim() === '')) fail('EMPTY_NOTE', '*', 'note vide');
  if (new Set(notes).size !== notes.length) fail('DUPLICATE_NOTE', '*', 'deux routes partagent le même motif');
  note(`R8 notes : ${notes.length} motifs, tous non vides et distincts`);
}

// ─── R9 — Distributions attendues (aucune conversion vers CONFIRMED). ───
{
  const count = (list) => list.reduce((acc, r) => {
    acc[r.official_identifier_status] = (acc[r.official_identifier_status] || 0) + 1;
    return acc;
  }, {});
  const cA = count(aftu);
  const c22 = count(Object.keys(FROZEN_22).map(id => byId.get(id)).filter(Boolean));
  const cAll = count(carriers);
  const expect = (got, want, label) => {
    for (const k of new Set([...Object.keys(got), ...Object.keys(want)])) {
      if ((got[k] || 0) !== (want[k] || 0)) fail('UNEXPECTED_DISTRIBUTION', label, `${k}: ${got[k] || 0} ≠ ${want[k] || 0}`);
    }
  };
  expect(cA, { CONFLICTING: 54, MISSING: 26 }, 'AFTU (80)');
  expect(c22, { CONFLICTING: 15, MISSING: 7 }, 'Tata/DDD (22)');
  expect(cAll, { CONFLICTING: 69, MISSING: 33, CONFIRMED: 0, UNKNOWN: 0 }, 'ensemble (102)');
  note('R9 distributions : AFTU 54 CONFLICTING / 26 MISSING · Tata/DDD 15 / 7 · total 69 CONFLICTING, 33 MISSING, 0 CONFIRMED, 0 UNKNOWN');
}

// ─── R10 — L'axe Tata/DDD du §9-1 reste intact, aucune Tata remappée. ───
for (const [id, [st, obs, bel]] of Object.entries(FROZEN_22)) {
  const r = byId.get(id);
  if (!r) continue;
  if (r.official_identifier_status !== st) fail('FROZEN_TUPLE_CHANGED', id, `status ${r.official_identifier_status} ≠ ${st}`);
  if (r.official_number_observed !== obs) fail('FROZEN_TUPLE_CHANGED', id, `observed ${r.official_number_observed} ≠ ${obs}`);
  if (r.official_number_belongs_to !== bel) fail('FROZEN_TUPLE_CHANGED', id, `belongs_to ${r.official_number_belongs_to} ≠ ${bel}`);
}
for (const r of routes.filter(x => x.operator_id === 'tata')) {
  if (r.official_number_belongs_to === 'TATA') {
    fail('TATA_NETWORK_INVENTED', r.id, 'aucun réseau Tata publié : belongs_to ne peut jamais valoir "TATA"');
  }
}
note('R10 axe Tata/DDD §9-1 : 22 tuples conformes, aucune identité Tata remappée, aucun réseau TATA créé');

// ─── R11 — Les autres réseaux et les volumes globaux sont intacts. ───
{
  for (const r of routes.filter(x => x.operator_id === 'ter' || x.operator_id === 'brt')) {
    if (IDENTITY_FIELDS.some(f => f in r)) fail('OTHER_NETWORK_TOUCHED', r.id, 'TER/BRT hors périmètre du lot 15');
  }
  if (raw.routes.length !== 105) fail('ROUTE_COUNT_CHANGED', '*', `${raw.routes.length} ≠ 105`);
  if (raw.stops.length !== 117) fail('STOP_COUNT_CHANGED', '*', `${raw.stops.length} ≠ 117`);
  if (raw.operators.length !== 5) fail('OPERATOR_COUNT_CHANGED', '*', `${raw.operators.length} ≠ 5`);
  if (raw.services_not_exposed.length !== 3) fail('SERVICES_CHANGED', '*', `${raw.services_not_exposed.length} ≠ 3`);
  note('R11 volumes intacts : 105 routes · 117 arrêts · 5 opérateurs · 3 services non exposés · TER/BRT sans champ d’identité');
}

// ─── Rapport ───
for (const m of ok) console.log(`OK   ${m}`);
for (const i of issues) console.error(`ERROR ${i.code} — ${i.id}: ${i.detail}`);
if (issues.length) {
  console.error(`\nNON CONFORME : ${issues.length} violation(s) de l'intégrité des identités de lignes.`);
  process.exitCode = 1;
} else {
  console.log('\nCONFORME : aucune correspondance fondée sur une ressemblance. 0 identité publique CONFIRMED, aucune inférence.');
}
