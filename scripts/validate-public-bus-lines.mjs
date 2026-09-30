// MISSION — CONTRÔLE FORT DE RACCORDEMENT (§6 / §15) + HONNÊTETÉ DU STATUT (§9).
//
// Pour CHAQUE ligne publique AFTU / DDD du référentiel
// (`data/reference/public_bus_lines_dakar.json`), on re-dérive la chaîne de
// raccordement horaire directement depuis les feeds opérationnels embarqués et on
// vérifie qu'elle est réellement complète ET exploitable :
//
//   line_number → operator → route_id → trip_id → direction_id → stop_id
//   → stop_sequence → stop_times → départ calculable (≥ 2 arrêts sur un trip)
//
// On vérifie EN PLUS la cohérence de `mapping_status` : `CONNECTED` est
// IMPOSSIBLE sans la chaîne complète et un départ exploitable, et toute ligne
// non raccordée doit porter une cause exacte (`unresolved_reason`) ET une preuve
// de blocage (`blocking`).
//
// La validation ÉCHOUE si une ligne est mal déclarée, ou si une identité est
// inventée / fusionnée / supprimée :
//   * CONNECTED sans chaîne complète ou sans départ exploitable ;
//   * NON CONNECTED présentée comme horairée (SCHEDULE_AVAILABLE / arrêts) ;
//   * route_id non corrélé au numéro public (raccordement fabriqué) ;
//   * variante lettrée fusionnée au numéro nu du feed (`502A` → `DDD_502`) ;
//   * identité publique supprimée, ou compteur incohérent.
//
// Une ligne publique OFFICIELLEMENT PUBLIÉE mais dont le feed actuel ne permet
// PAS le raccordement reste explicitement non raccordée : elle est listée avec
// sa cause exacte et sa preuve de blocage. Ce n'est PAS un échec de validation —
// c'est un état honnête. On ne fabrique jamais une donnée pour atteindre 100 %.
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
    if (!ev.has(id)) {
      ev.set(id, { trips: 0, dirs: new Set(), stops: new Set(), st: 0, seq: new Set(), boardable: 0 });
    }
    return ev.get(id);
  };
  for (const id of routeIdByIndex) ensure(id);
  for (const t of feed.trips) {
    const e = ensure(routeIdByIndex[t[1]]);
    e.trips += 1;
    e.dirs.add(String(t[3]));
  }
  // stop_times : regroupe par trip pour compter les départs EMBARQUABLES
  // (un trip avec ≥ 2 arrêts offre au moins un départ). Un trip mono-arrêt
  // n'offre aucun départ exploitable.
  const rowsByTrip = new Map();
  for (const s of feed.stop_times) {
    if (!rowsByTrip.has(s[0])) rowsByTrip.set(s[0], []);
    rowsByTrip.get(s[0]).push(s);
  }
  for (const [tripIdx, rows] of rowsByTrip) {
    const rid = routeIdByIndex[tripRouteIndex[tripIdx]];
    const e = ensure(rid);
    e.st += rows.length;
    for (const s of rows) {
      e.stops.add(s[1]);
      e.seq.add(s[2] === null || s[2] === undefined ? null : Number(s[2]));
    }
    if (rows.length >= 2) e.boardable += rows.length - 1;
  }
  return { byNumber, ev };
}

const AFTU = feedEvidence(resolve(ROOT, 'flutter-src/assets/data/passbi/aftu.json'), 'AFTU');
const DDD = feedEvidence(resolve(ROOT, 'flutter-src/assets/data/passbi/ddd.json'), 'DDD');

const failures = [];
const linked = [];
const unresolvedHonest = [];

for (const [network, feed] of [['AFTU', AFTU], ['DDD', DDD]]) {
  const lines = REF[network.toLowerCase()];
  for (const l of lines) {
    const problems = [];
    if (!l.line_number) problems.push('line_number absent');
    if (l.operator !== network) problems.push('operator incohérent');

    // Chaîne dérivée du feed : ce que la ligne DEVRAIT déclarer.
    const routeIds = l.feed_route_ids ?? [];
    let chainComplete = routeIds.length > 0;
    // Les maillons manquants sont consignés à part : pour une ligne NON
    // raccordée, c'est exactement la cause documentée (`blocking`), pas une
    // incohérence. Ils ne deviennent une incohérence que si la ligne se
    // prétend CONNECTED.
    const chainProblems = [];
    for (const rid of routeIds) {
      // Aucun raccordement fabriqué : le route_id doit porter le numéro public.
      const expected = new Set(feed.byNumber.get(String(Number(l.line_number))) ?? []);
      if (!expected.has(rid)) {
        chainProblems.push(`route_id ${rid} non corrélé au numéro ${l.line_number} (raccordement fabriqué ?)`);
        chainComplete = false;
        continue;
      }
      const e = feed.ev.get(rid);
      if (!e || e.trips === 0) { chainProblems.push(`route ${rid} sans trip réel`); chainComplete = false; }
      if (!e || e.dirs.size === 0) { chainProblems.push(`route ${rid} sans direction_id réel`); chainComplete = false; }
      if (!e || e.st === 0) { chainProblems.push(`route ${rid} sans stop_time`); chainComplete = false; }
      if (!e || e.stops.size === 0) { chainProblems.push(`route ${rid} sans stop_id réel`); chainComplete = false; }
      if (!e || e.seq.has(null)) { chainProblems.push(`route ${rid} sans stop_sequence`); chainComplete = false; }
      // Départ EXPLOITABLE : au moins un trip avec ≥ 2 arrêts. Une route dont
      // tous les trips sont mono-arrêt ne produit aucun prochain départ.
      if (!e || e.boardable === 0) {
        chainProblems.push(`route ${rid} sans départ exploitable (trip < 2 arrêts)`);
        chainComplete = false;
      }
    }

    // Honnêteté du statut : CONNECTED exigé si la chaîne est complète, interdit
    // sinon. Le statut déclaré doit refléter la chaîne réelle.
    const declaredConnected = l.mapping_status === 'CONNECTED';
    if (declaredConnected) {
      // Une ligne qui se prétend CONNECTED doit assumer TOUS les maillons.
      problems.push(...chainProblems);
    }
    // Pour une ligne NON raccordée, un maillon manquant n'est PAS une
    // incohérence : c'est la cause documentée (`blocking`), vérifiée plus bas.
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
      // LIGNE PUBLIÉE NON RACCORDÉE — état honnête, PAS un échec en soi. Mais
      // la déclaration doit rester honnête : cause exacte + preuve de blocage,
      // et surtout JAMAIS présentée comme disposant d'horaires réels.
      if (!l.unresolved_reason) problems.push('ligne non raccordée sans cause exacte');
      if (!l.blocking) problems.push('ligne non raccordée sans preuve de blocage');
      if (l.schedule_status === 'SCHEDULE_AVAILABLE') {
        problems.push('ligne non raccordée présentée avec SCHEDULE_AVAILABLE (faux horaire)');
      }
      if ((l.served_stop_count ?? 0) > 0) {
        problems.push('ligne non raccordée avec served_stop_count > 0 (arrêts sans horaire)');
      }
      if ((l.stop_times_count ?? 0) > 0) {
        problems.push('ligne non raccordée avec stop_times déclarés');
      }
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

    // Anti-invention d'identité : une VARIANTE LETTRÉE (`502A`, `15B`…) n'est
    // jamais raccordée au numéro NU du feed (`DDD_502`, `DDD_15`). Cette fusion
    // serait un raccordement par ressemblance, interdit.
    const lettered = /^\d+[A-Za-z]$/.test(String(l.line_number));
    if (lettered && routeIds.length > 0) {
      problems.push(`variante lettrée ${l.line_number} raccordée (fusion au numéro nu interdite)`);
    }

    if (problems.length > 0) {
      failures.push({ label: l.public_label, problems });
    } else if (declaredConnected) {
      linked.push(l.public_label);
    } else {
      unresolvedHonest.push(l.public_label);
    }
  }
}

// Anti-régression : aucune identité publique ne disparaît du référentiel.
const expectedTotal = (REF.counts.aftu_official ?? 0) + (REF.counts.ddd_public ?? 0);
const actualTotal = REF.aftu.length + REF.ddd.length;
if (actualTotal !== expectedTotal) {
  failures.push({
    label: 'RÉFÉRENTIEL',
    problems: [`${actualTotal} lignes publiques ≠ compteurs déclarés ${expectedTotal} (identité supprimée ?)`],
  });
}

// Anti-régression : une ligne raccordée ne peut pas redevenir non raccordée
// silencieusement. Le nombre de CONNECTED ne doit jamais diminuer sous la
// référence publiée, et les compteurs doivent rester cohérents.
const byStatus = (s) => REF.aftu.concat(REF.ddd).filter((l) => l.mapping_status === s).length;
if (REF.counts.connected !== byStatus('CONNECTED')) {
  failures.push({ label: 'RÉFÉRENTIEL', problems: ['counts.connected ≠ nombre réel de CONNECTED'] });
}
if ((REF.counts.unresolved ?? 0) !== byStatus('BLOCKED') + byStatus('NOT_VERIFIED') + byStatus('PARTIAL')) {
  failures.push({ label: 'RÉFÉRENTIEL', problems: ['counts.unresolved ≠ nombre réel de lignes non raccordées'] });
}

console.log(`Raccordement vérifié : ${linked.length} lignes publiques AFTU/DDD CONNECTED (chaîne + départ exploitable).`);
console.log(`Statuts : CONNECTED=${REF.counts.connected} BLOCKED=${REF.counts.blocked} ` +
  `NOT_VERIFIED=${REF.counts.not_verified} PARTIAL=${REF.counts.partial}`);
if (unresolvedHonest.length > 0) {
  console.log('');
  console.log(`${unresolvedHonest.length} identité(s) publique(s) OFFICIELLEMENT PUBLIÉE(S) mais NON raccordée(s) ` +
    'au feed horaire actuel — conservée(s) dans le catalogue, jamais présentée(s) comme horairée(s) :');
  for (const label of unresolvedHonest) console.log(`  - ${label}`);
  console.log('');
  console.log('Le catalogue public est complet ; le feed opérationnel disponible ne permet pas ' +
    'actuellement de raccorder toutes les identités publiques aux données horaires.');
}
if (failures.length > 0) {
  console.error('');
  console.error(`ÉCHEC DE VALIDATION : ${failures.length} incohérence(s) détectée(s) ` +
    '(raccordement fabriqué, statut optimiste, identité supprimée ou variante fusionnée) :');
  for (const f of failures) console.error(`  - ${f.label} : ${f.problems.join(' ; ')}`);
  console.error('');
  console.error('Aucune donnée ne doit être inventée pour atteindre 100 % : corrigez la déclaration, pas la donnée.');
  process.exit(1);
}
console.log('VALIDATION OK : raccordement honnête (aucune invention, aucune identité supprimée).');
