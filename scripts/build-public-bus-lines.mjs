// MISSION — RÉFÉRENTIEL PUBLIC DES LIGNES AFTU / TATA / DDD.
//
// GÉNÉRATEUR du référentiel public `public_bus_lines_dakar.json`.
//
// Sources (aucune ligne inventée) :
//   * identités officielles AFTU/DDD : docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md
//     (§A.2 pour les 72 AFTU ; §L pour les lignes DDD et les 7 identités Tata),
//     lui-même dérivé des publications officielles aftu-senegal.org / demdikk.sn ;
//   * raccordement horaire : feeds PassBi déjà embarqués (ddd.json / aftu.json)
//     via route_id → trip_id → direction_id → stop_id → stop_sequence.
//
// Règles strictes :
//   * numéro public obligatoire : aucune entrée sans `line_number` n'est écrite
//     dans le référentiel public ;
//   * le numéro public n'est JAMAIS déduit d'un `route_id` (le mapping
//     route_id → numéro public s'appuie sur la correspondance documentée) ;
//   * aucune fréquence convertie en horaire ; aucun arrêt fabriqué ;
//   * les identités techniques Tata (`new_commune_*`, `tata_*`) ne deviennent
//     jamais des lignes visibles : elles sont conservées dans un registre
//     d'audit séparé (`tata_audit`), sans numéro public.
//
// Usage : node scripts/build-public-bus-lines.mjs
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const CANONICAL = resolve(ROOT, 'docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md');
const DDD_FEED = resolve(ROOT, 'flutter-src/assets/data/passbi/ddd.json');
const AFTU_FEED = resolve(ROOT, 'flutter-src/assets/data/passbi/aftu.json');
const NETWORK = resolve(ROOT, 'flutter-src/assets/data/dakar_network.json');

const VERIFIED_AT = '2026-09-25'; // date de vérification des sources officielles (§M du canonique).
const GENERATED_AT = '2026-09-30';

const SOURCES = {
  aftu: 'https://aftu-senegal.org/infos-pratiques/',
  ddd: 'https://demdikk.sn/info-voyageurs/',
  dddItineraries: 'https://demdikk.sn/reseau-urbain-dakar/',
  canonical: 'docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md',
};

// ---------------------------------------------------------------------------
// Parsing du référentiel canonique.
// ---------------------------------------------------------------------------
const md = readFileSync(CANONICAL, 'utf8');

const strip = (s) => s.replace(/`/g, '').trim();

/** Découpe une section `## X.` (jusqu'au prochain `## `). */
function section(markdown, heading) {
  const start = markdown.indexOf(heading);
  if (start < 0) throw new Error(`section introuvable : ${heading}`);
  const rest = markdown.slice(start + heading.length);
  const end = rest.search(/\n## /);
  return end < 0 ? rest : rest.slice(0, end);
}

// AFTU §A.2, ligne : `| \`AFTU 26\` | NOM | ORIGINE | DEST | ROUTE | ARRÊTS | SRC | DATE | STATUT |`
// m[2] commence juste après `| \`AFTU 26\` |` → cols[0]=NOM, [1]=ORIGINE, [2]=DEST,
// [3]=ROUTE, [4]=ARRÊTS, [5]=SRC, [6]=DATE, [7]=STATUT.
function parseAftu() {
  const body = section(md, '## A. AFTU');
  const seen = new Set();
  const out = [];
  const re = /^\| `AFTU (\d+)` \|([^\n]*)$/gm;
  let m;
  while ((m = re.exec(body)) !== null) {
    const cols = m[2].split('|').map((c) => c.trim());
    if (seen.has(m[1])) continue; // la sous-table §A.4 répète 84–89/91
    seen.add(m[1]);
    out.push({
      number: m[1],
      official_name: strip(cols[0] ?? ''),
      origin: strip(cols[1] ?? ''),
      destination: strip(cols[2] ?? ''),
      route_status: /ROUTE_DOCUMENTED/.test(cols[3] ?? '') ? 'ROUTE_DOCUMENTED' : 'ROUTE_NOT_FOUND',
      stops_status: 'UNKNOWN',
      canonical_status: strip(cols[7] ?? ''),
    });
  }
  return out;
}

// §L, ligne DDD : `| DDD | **221** | ORIG | DEST | ITIN | ARRÊTS | HORAIRE | FRÉQ | STATUT | SRC |`
// m[2] commence après `| **221** |` → cols[0]=ORIG, [1]=DEST, [2]=ITIN,
// [3]=ARRÊTS, [4]=HORAIRE, [5]=FRÉQ, [6]=STATUT, [7]=SRC.
function parseDdd() {
  const body = section(md, '## L. Tableau final');
  const allowed = new Set(['CONFIRMED', 'PARTIAL', 'CONFLICTING', 'UNVERIFIED']);
  const seen = new Set();
  const out = [];
  const re = /^\| DDD \| \*\*([^*]+)\*\* \|([^\n]*)$/gm;
  let m;
  while ((m = re.exec(body)) !== null) {
    const number = m[1].trim();
    if (seen.has(number)) continue;
    const cols = m[2].split('|').map((c) => c.trim());
    // La ligne de volumétrie §L.1 (`| DDD | **48** | 39 ... |`) n'est pas une
    // ligne : son statut canonique n'appartient pas à l'ensemble autorisé.
    const canonical = strip(cols[6] ?? '');
    if (!allowed.has(canonical)) continue;
    seen.add(number);
    out.push({
      number,
      origin: strip(cols[0] ?? ''),
      destination: strip(cols[1] ?? ''),
      route_status: /STOP_SEQUENCE_CONFIRMED/.test(cols[2] ?? '')
        ? 'STOP_SEQUENCE_CONFIRMED'
        : 'ROUTE_NOT_FOUND',
      stops_status: /OUI/.test(cols[3] ?? '') ? 'STOP_SEQUENCE_CONFIRMED' : 'UNKNOWN',
      schedule_status: /SCHEDULE_CONFIRMED/.test(cols[4] ?? '') ? 'SCHEDULE_CONFIRMED' : 'NO_SCHEDULE',
      canonical_status: canonical,
    });
  }
  return out;
}

// §L : identités Tata `| Tata (catégorie AFTU) | \`id\` | ORIG | DEST | ITIN | ARRÊTS | HORAIRE | FRÉQ | STATUT | SRC |`
// m[2] commence après `| \`id\` |` → cols[0]=ORIG, [1]=DEST, [2]=ITIN,
// [3]=ARRÊTS, [4]=HORAIRE, [5]=FRÉQ, [6]=STATUT, [7]=SRC.
function parseTataIdentities() {
  const body = section(md, '## L. Tableau final');
  const out = [];
  const re = /^\| Tata \(catégorie AFTU\) \| `([^`]+)` \|([^\n]*)$/gm;
  let m;
  while ((m = re.exec(body)) !== null) {
    const cols = m[2].split('|').map((c) => c.trim());
    out.push({
      route_id: m[1].trim(),
      canonical_status: strip(cols[6] ?? ''),
      source: strip(cols[7] ?? ''),
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Raccordement horaire (feeds PassBi).
// ---------------------------------------------------------------------------
function feedSchedule(feedPath, prefix) {
  const feed = JSON.parse(readFileSync(feedPath, 'utf8'));
  const byNumber = new Map(); // "26" -> [routeId...]
  for (const r of feed.routes) {
    const mm = new RegExp(`^${prefix}_(\\d+)$`).exec(r.id);
    if (!mm) continue;
    const num = String(Number(mm[1]));
    if (!byNumber.has(num)) byNumber.set(num, []);
    byNumber.get(num).push(r.id);
  }
  // Le feed stocke les `stop_times` en tableaux :
  //   [tripIndex, stopIndex, stopSequence, arrivalSec, departureSec]
  // et les `trips` en tableaux : [tripId, routeIndex, serviceIndex, directionId, headsign].
  const routeIdByIndex = feed.routes.map((r) => r.id);
  const tripRouteIndex = feed.trips.map((t) => t[1]);
  const servedByRoute = new Map();
  for (const st of feed.stop_times) {
    const routeId = routeIdByIndex[tripRouteIndex[st[0]]];
    if (!servedByRoute.has(routeId)) servedByRoute.set(routeId, new Set());
    servedByRoute.get(routeId).add(st[1]);
  }
  return { byNumber, servedByRoute };
}

const dddFeed = feedSchedule(DDD_FEED, 'DDD');
const aftuFeed = feedSchedule(AFTU_FEED, 'AFTU');

// ---------------------------------------------------------------------------
// Construction des entrées.
// ---------------------------------------------------------------------------
const aftu = parseAftu();
const ddd = parseDdd();
const tataIdentities = parseTataIdentities();
const network = JSON.parse(readFileSync(NETWORK, 'utf8'));

function scheduleFor(feed, number) {
  const routeIds = feed.byNumber.get(String(Number(number))) ?? [];
  const served = new Set();
  for (const rid of routeIds) {
    for (const s of feed.servedByRoute.get(rid) ?? []) served.add(s);
  }
  return {
    routeIds,
    stopCount: served.size,
    status: routeIds.length > 0 && served.size > 0 ? 'SCHEDULE_AVAILABLE' : 'NO_SCHEDULE',
  };
}

/** Origine/destination : la donnée structurée si présente, sinon la seule
 *  source officielle disponible (libellé publié « A - B »). Jamais inventées. */
function endpoints(origin, destination, officialName) {
  const norm = (s) => (s || '').replace(/[–—]/g, '-').trim();
  let o = norm(origin);
  let d = norm(destination);
  const published = /ROUTE_NOT_FOUND|NON PUBLI|non publi/i.test(o) || o === '';
  if (published) {
    const parts = norm(officialName).split(/\s+-\s+/);
    if (parts.length >= 2) {
      o = parts[0];
      d = parts.slice(1).join(' - ');
    } else {
      o = norm(officialName) || 'NON PUBLIÉE';
      d = 'NON PUBLIÉE';
    }
  }
  return { origin: o || 'NON PUBLIÉE', destination: d || 'NON PUBLIÉE' };
}

const aftuLines = aftu.map((l) => {
  const sch = scheduleFor(aftuFeed, l.number);
  const { origin, destination } = endpoints(l.origin, l.destination, l.official_name);
  return {
    operator: 'AFTU',
    line_number: l.number,
    vehicle_type: 'TATA', // minibus AFTU (S-I1) ; AFTU reste l'opérateur.
    public_label: `AFTU ${l.number}`,
    origin,
    destination,
    official_name: l.official_name,
    identity_status: 'CONFIRMED',
    route_status: l.route_status,
    stops_status: l.stops_status,
    schedule_status: sch.status,
    feed_route_ids: sch.routeIds,
    served_stop_count: sch.stopCount,
    source: SOURCES.aftu,
    verified_at: VERIFIED_AT,
    canonical_status: l.canonical_status,
  };
});

const dddLines = ddd.map((l) => {
  // Variantes lettrées (15A/15B, 16A/16B, 502A…) : le numéro nu du feed ne
  // permet pas de trancher A/B → aucun raccordement horaire (UNKNOWN).
  const hasLetter = /[A-Za-z]/.test(l.number);
  const sch = hasLetter
    ? { routeIds: [], stopCount: 0, status: 'NO_SCHEDULE' }
    : scheduleFor(dddFeed, l.number);
  const { origin, destination } = endpoints(l.origin, l.destination, '');
  return {
    operator: 'DDD',
    line_number: l.number,
    vehicle_type: 'BUS',
    public_label: `DDD ${l.number}`,
    origin,
    destination,
    identity_status: 'CONFIRMED',
    route_status: l.route_status,
    stops_status: l.stops_status,
    schedule_status: sch.status, // dérivé du feed (raccordement réel)
    published_schedule_status: l.schedule_status, // publié (canonique)
    feed_route_ids: sch.routeIds,
    served_stop_count: sch.stopCount,
    source: SOURCES.ddd,
    itinerary_source: SOURCES.dddItineraries,
    verified_at: VERIFIED_AT,
    canonical_status: l.canonical_status,
  };
});

// Registre d'audit Tata : AUCUN numéro public, jamais une ligne visible.
const tataAudit = tataIdentities.map((t) => {
  const route = network.routes.find((r) => r.id === t.route_id) ?? {};
  return {
    route_id: t.route_id,
    operator: 'AFTU', // Tata = catégorie de véhicule de l'écosystème AFTU, pas un opérateur.
    vehicle_type: 'TATA',
    line_number: null, // aucun numéro public établi : NE JAMAIS afficher comme ligne.
    public_label: null,
    identity_status: /CONFLICTING/.test(t.canonical_status) ? 'CONFLICTING' : 'UNVERIFIED',
    canonical_status: t.canonical_status,
    internal_short_name: route.short_name ?? null,
    source: SOURCES.canonical,
    verified_at: VERIFIED_AT,
    note:
      'Identité technique interne conservée pour audit. Aucun numéro officiel Tata ' +
      "n'est établi : cette entrée ne doit jamais être rendue comme une ligne publique.",
  };
});

const ref = {
  schema: 'public-bus-lines-dakar/v1',
  generated_at: GENERATED_AT,
  sources_verified_at: VERIFIED_AT,
  principle:
    'Numéro public obligatoire (operator + line_number + public_label + origin + ' +
    'destination). Aucune ligne sans numéro officiel. Aucun horaire, aucun arrêt, ' +
    'aucune correspondance inventés. Le numéro public n’est jamais déduit du route_id.',
  sources: SOURCES,
  counts: {
    aftu_official: aftuLines.length,
    ddd_public: dddLines.length,
    tata_identities: tataAudit.length,
  },
  aftu: aftuLines,
  ddd: dddLines,
  tata_audit: tataAudit,
};

const json = JSON.stringify(ref, null, 2) + '\n';
for (const out of [
  resolve(ROOT, 'data/reference/public_bus_lines_dakar.json'),
  resolve(ROOT, 'flutter-src/assets/data/reference/public_bus_lines_dakar.json'),
]) {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, json);
}

const withSchedule = (arr) => arr.filter((l) => l.schedule_status !== 'NO_SCHEDULE').length;
console.log(`AFTU : ${aftuLines.length} lignes officielles (${withSchedule(aftuLines)} reliées aux horaires).`);
console.log(`DDD  : ${dddLines.length} lignes publiques (${withSchedule(dddLines)} reliées aux horaires).`);
console.log(`Tata : ${tataAudit.length} identités en audit (0 ligne publique — aucun numéro officiel).`);
