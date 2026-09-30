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
//
// On construit, par route du feed, la CHAÎNE DE RACCORDEMENT VÉRIFIABLE :
//   route_id → trip_id → direction_id → stop_id → stop_sequence → stop_times
// (le format compact stocke trips = [tripId, routeIndex, serviceIndex,
// directionId, headsign] et stop_times = [tripIndex, stopIndex, stopSequence,
// arrivalSec, departureSec]).
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
  const routeIdByIndex = feed.routes.map((r) => r.id);
  const tripRouteIndex = feed.trips.map((t) => t[1]);

  // Evidence par route : trips réels, directions réelles, stop_times, arrêts,
  // et qualité de stop_sequence (présence + unicité).
  const evidence = new Map();
  const ensure = (routeId) => {
    if (!evidence.has(routeId)) {
      evidence.set(routeId, {
        tripIds: [],
        directionIds: new Set(),
        stopIndexes: new Set(),
        stopTimes: 0,
        stopSequencePresent: true,
        stopSequenceValid: true,
      });
    }
    return evidence.get(routeId);
  };
  for (const r of routeIdByIndex) ensure(r);
  // 1) trips → route
  for (const t of feed.trips) {
    const ev = ensure(routeIdByIndex[t[1]]);
    ev.tripIds.push(t[0]);
    ev.directionIds.add(String(t[3]));
  }
  // 2) stop_times → trip → route ; présence et ordre de stop_sequence
  const perTripSeq = new Map();
  for (const st of feed.stop_times) {
    const routeId = routeIdByIndex[tripRouteIndex[st[0]]];
    const ev = ensure(routeId);
    ev.stopTimes += 1;
    ev.stopIndexes.add(st[1]);
    if (st[2] === null || st[2] === undefined || Number.isNaN(Number(st[2]))) {
      ev.stopSequencePresent = false;
    }
    if (!perTripSeq.has(st[0])) perTripSeq.set(st[0], []);
    perTripSeq.get(st[0]).push(Number(st[2]));
  }
  // stop_sequence strictement croissante au sein d'un trip (unicité/ordre).
  const seqStrictByRoute = new Map();
  for (const [tripIndex, seqs] of perTripSeq) {
    const routeId = routeIdByIndex[tripRouteIndex[tripIndex]];
    const strict = seqs.every((v, i) => i === 0 || v > seqs[i - 1]);
    if (!strict) seqStrictByRoute.set(routeId, false);
  }
  for (const [routeId, ev] of evidence) {
    ev.stopSequenceValid = seqStrictByRoute.get(routeId) !== false;
  }
  return { byNumber, evidence };
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
  const tripIds = [];
  const directionIds = new Set();
  const stopIndexes = new Set();
  let stopTimes = 0;
  let stopSequencePresent = routeIds.length > 0;
  let stopSequenceStrict = routeIds.length > 0;
  for (const rid of routeIds) {
    const ev = feed.evidence.get(rid);
    if (!ev) continue;
    for (const t of ev.tripIds) tripIds.push(t);
    for (const d of ev.directionIds) directionIds.add(d);
    for (const s of ev.stopIndexes) stopIndexes.add(s);
    stopTimes += ev.stopTimes;
    if (!ev.stopSequencePresent) stopSequencePresent = false;
    if (!ev.stopSequenceValid) stopSequenceStrict = false;
  }
  // La chaîne est VÉRIFIABLE (raccordée) si les 6 maillons existent réellement :
  // route_id, trip_id, direction_id, stop_id, stop_sequence (présente),
  // stop_times. L'unicité/ordre strict de stop_sequence est une qualité
  // ADDITIONNELLE, rapportée séparément — jamais un prétexte pour dé-raccorder.
  const complete =
    routeIds.length > 0 &&
    tripIds.length > 0 &&
    directionIds.size > 0 &&
    stopIndexes.size > 0 &&
    stopTimes > 0 &&
    stopSequencePresent;
  return {
    routeIds,
    tripIds,
    directionIds: [...directionIds].sort(),
    stopCount: stopIndexes.size,
    stopTimes,
    stopSequencePresent,
    stopSequenceStrict,
    complete,
    status: complete ? 'SCHEDULE_AVAILABLE' : 'NO_SCHEDULE',
  };
}

/** Route(s) du feed portant le numéro NU (ex. `502A` → `DDD_502`).
 *
 *  Sert UNIQUEMENT de preuve d'audit : on documente qu'une route au numéro nu
 *  existe mais que la rattacher à une variante lettrée serait une fusion non
 *  prouvée (identités publiques distinctes). Le résultat n'est JAMAIS utilisé
 *  pour raccorder. */
function bareNumberRouteIds(feed, number) {
  const bare = /^(\d+)/.exec(number);
  if (!bare) return [];
  return feed.byNumber.get(String(Number(bare[1]))) ?? [];
}

/** Statut de raccordement explicite (§9).
 *
 *  - `CONNECTED`    : les 6 maillons de la chaîne existent réellement ;
 *  - `BLOCKED`      : une route du feed porte ce numéro, mais un maillon
 *                     manque (cause exacte dans `blocking`) ;
 *  - `NOT_VERIFIED` : aucune route du feed ne porte ce numéro public ;
 *  - `PARTIAL`      : réservé (aucune ligne dans cet état aujourd'hui).
 *
 *  `CONNECTED` est IMPOSSIBLE sans la chaîne complète : jamais de statut
 *  optimiste. */
function mappingStatus(sch) {
  if (sch.complete) return 'CONNECTED';
  if (sch.routeIds.length > 0) return 'BLOCKED';
  return 'NOT_VERIFIED';
}

/** Qualité de l'ordre des arrêts dans le feed (≠ raccordement). */
function sequenceQuality(sch) {
  if (!sch.stopSequencePresent) return 'ABSENT';
  return sch.stopSequenceStrict ? 'STRICT' : 'UNORDERED_IN_FEED';
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
    mapping_status: mappingStatus(sch),
    feed_route_ids: sch.routeIds,
    trip_ids_count: sch.tripIds.length,
    sample_trip_ids: sch.tripIds.slice(0, 3),
    direction_ids: sch.directionIds,
    stop_times_count: sch.stopTimes,
    stop_sequence_present: sch.stopSequencePresent,
    stop_sequence_strict: sch.stopSequenceStrict,
    sequence_quality: sequenceQuality(sch),
    served_stop_count: sch.stopCount,
    unresolved_reason: sch.complete ? null : unresolvedReason(sch),
    blocking: sch.complete ? null : blockingFor('AFTU', l.number, sch),
    source: SOURCES.aftu,
    verified_at: VERIFIED_AT,
    canonical_status: l.canonical_status,
  };
});

const dddLines = ddd.map((l) => {
  // Variantes lettrées (15A/15B, 16A/16B, 502A…) et services TAF TAF : le feed
  // n'expose AUCUNE route portant ce numéro — aucun raccordement n'est possible
  // sans fabriquer un mapping (interdit). Le raccordement reste donc vide, avec
  // la cause documentée dans `unresolved_reason`. On documente en plus, pour
  // audit, les routes au numéro NU (ex. `DDD_502`) qui existent mais ne doivent
  // PAS être fusionnées avec la variante.
  const hasLetter = /[A-Za-z]/.test(l.number);
  const sch = hasLetter
    ? { routeIds: [], tripIds: [], directionIds: [], stopCount: 0, stopTimes: 0,
        stopSequencePresent: false, stopSequenceStrict: false, complete: false,
        status: 'NO_SCHEDULE' }
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
    mapping_status: mappingStatus(sch),
    feed_route_ids: sch.routeIds,
    trip_ids_count: sch.tripIds.length,
    sample_trip_ids: sch.tripIds.slice(0, 3),
    direction_ids: sch.directionIds,
    stop_times_count: sch.stopTimes,
    stop_sequence_present: sch.stopSequencePresent,
    stop_sequence_strict: sch.stopSequenceStrict,
    sequence_quality: sequenceQuality(sch),
    served_stop_count: sch.stopCount,
    unresolved_reason: sch.complete
      ? null
      : unresolvedReason(sch, hasLetter ? 'NO_FEED_ROUTE_FOR_LINE_NUMBER' : null),
    blocking: sch.complete
      ? null
      : blockingFor('DDD', l.number, sch, {
          bareNumberRouteIds: hasLetter ? bareNumberRouteIds(dddFeed, l.number) : [],
        }),
    source: SOURCES.ddd,
    itinerary_source: SOURCES.dddItineraries,
    verified_at: VERIFIED_AT,
    canonical_status: l.canonical_status,
  };
});

/** Preuve de blocage : ce qui manque, pourquoi, et ce qu'il faudrait (§8).
 *
 *  Aucune donnée n'est inventée ici : on ne fait que consigner l'absence
 *  constatée dans le feed et la source qu'il faudrait obtenir. */
function blockingFor(operator, number, sch, extra = {}) {
  const reason = unresolvedReason(sch, extra.bareNumberRouteIds ? 'NO_FEED_ROUTE_FOR_LINE_NUMBER' : null);
  const common = {
    operator,
    line_number: number,
    reason,
    missing_fields: [],
    consulted_sources: [SOURCES.canonical, 'feeds PassBi embarqués (ddd.json / aftu.json)'],
    next_action: '',
  };
  if (sch.routeIds.length === 0) {
    const bare = extra.bareNumberRouteIds ?? [];
    return {
      ...common,
      feed_route_ids_present: [],
      bare_number_route_ids: bare,
      missing_fields: ['route_id', 'trip_id', 'direction_id', 'stop_id', 'stop_sequence', 'stop_times'],
      next_action: bare.length > 0
        ? `Obtenir de la source la preuve que la variante « ${number} » emprunte bien la route ` +
          `au numéro nu (${bare.join(', ')}) AVANT tout raccordement. Sans cette preuve, la ` +
          'fusion est interdite (identités publiques distinctes).'
        : `Obtenir de ${operator} un feed (ou une publication) exposant la route de la ligne ` +
          `« ${number} ». Aucune route de ce numéro n'existe dans le feed embarqué.`,
    };
  }
  if (sch.tripIds.length === 0) {
    return {
      ...common,
      feed_route_ids_present: sch.routeIds,
      missing_fields: ['trip_id', 'direction_id', 'stop_id', 'stop_sequence', 'stop_times'],
      next_action: `La route ${sch.routeIds.join(', ')} existe dans le feed mais ne porte aucun trip : ` +
        'obtenir les trips (et leurs stop_times) auprès de la source.',
    };
  }
  if (sch.stopTimes === 0) {
    return {
      ...common,
      feed_route_ids_present: sch.routeIds,
      missing_fields: ['stop_times', 'stop_sequence'],
      next_action: `La route ${sch.routeIds.join(', ')} porte des trips mais AUCUN stop_time : ` +
        'obtenir les stop_times auprès de la source.',
    };
  }
  if (sch.stopCount === 0) {
    return {
      ...common,
      feed_route_ids_present: sch.routeIds,
      missing_fields: ['stop_id'],
      next_action: 'Aucun arrêt réellement desservi : obtenir les stop_times nommés.',
    };
  }
  return {
    ...common,
    feed_route_ids_present: sch.routeIds,
    missing_fields: ['stop_sequence'],
    next_action: 'stop_sequence absente du feed : obtenir une séquence d\'arrêts ordonnée.',
  };
}

/** Cause exacte d'un défaut de raccordement — jamais un simple « NO_SCHEDULE ». */
function unresolvedReason(sch, override = null) {
  if (override) return override;
  if (sch.routeIds.length === 0) return 'NO_FEED_ROUTE_FOR_LINE_NUMBER';
  if (sch.tripIds.length === 0) return 'FEED_ROUTE_WITHOUT_TRIP';
  if (sch.stopTimes === 0) return 'FEED_ROUTE_WITHOUT_STOP_TIME';
  if (sch.stopCount === 0) return 'FEED_ROUTE_WITHOUT_STOP';
  if (!sch.stopSequencePresent) return 'STOP_SEQUENCE_MISSING';
  return 'UNRESOLVED_UNKNOWN';
}

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

// ---------------------------------------------------------------------------
// Porte de complétude (§6 / §15) : TOUTE ligne publique AFTU/DDD doit être
// raccordée aux données horaires réelles. On ne masque jamais un défaut.
// ---------------------------------------------------------------------------
const allPublic = [...aftuLines, ...dddLines];
const unresolved = allPublic
  .filter((l) => !isLinked(l))
  .map((l) => ({
    operator: l.operator,
    line_number: l.line_number,
    public_label: l.public_label,
    reason: l.unresolved_reason,
    mapping_status: l.mapping_status,
    feed_route_ids: l.feed_route_ids,
  }));

/** Vrai si les 6 maillons de la chaîne de raccordement existent réellement. */
function isLinked(l) {
  return (
    l.line_number != null &&
    l.operator != null &&
    Array.isArray(l.feed_route_ids) && l.feed_route_ids.length > 0 &&
    l.trip_ids_count > 0 &&
    Array.isArray(l.direction_ids) && l.direction_ids.length > 0 &&
    l.stop_times_count > 0 &&
    l.served_stop_count > 0 &&
    l.stop_sequence_present === true &&
    l.schedule_status === 'SCHEDULE_AVAILABLE'
  );
}

const countStatus = (s) => allPublic.filter((l) => l.mapping_status === s).length;

// ---------------------------------------------------------------------------
// Audit §9 — routes du feed SANS ligne publique correspondante.
//
// Le feed opérationnel contient des routes dont le numéro public n'apparaît pas
// dans le référentiel canonique publié (ex. `DDD_102`, `DDD_401`, `AFTU_90`).
// Ce n'est PAS un défaut de raccordement : ces routes n'ont aucune identité
// publique établie par une source. On les DOCUMENTE (jamais on ne les fusionne
// avec une ligne publique existante, jamais on ne fabrique une ligne).
// ---------------------------------------------------------------------------
function feedRoutesWithoutPublicLine(feed, publicRoutes, tataRoutes) {
  const orphans = [];
  for (const rid of feed.evidence.keys()) {
    if (publicRoutes.has(rid)) continue;
    if (tataRoutes.has(rid)) continue;
    orphans.push(rid);
  }
  return orphans.sort();
}

const publicRouteIds = new Set(allPublic.flatMap((l) => l.feed_route_ids));
const tataRouteIds = new Set(tataAudit.map((t) => t.route_id));
const dddFeedOrphans = feedRoutesWithoutPublicLine(dddFeed, publicRouteIds, tataRouteIds);
const aftuFeedOrphans = feedRoutesWithoutPublicLine(aftuFeed, publicRouteIds, tataRouteIds);

const ref = {
  schema: 'public-bus-lines-dakar/v3',
  generated_at: GENERATED_AT,
  sources_verified_at: VERIFIED_AT,
  principle:
    'Numéro public obligatoire (operator + line_number + public_label + origin + ' +
    'destination). Aucune ligne sans numéro officiel. Aucun horaire, aucun arrêt, ' +
    'aucune correspondance inventés. Le numéro public n’est jamais déduit du route_id. ' +
    'Toute ligne publique AFTU/DDD doit être raccordée aux données horaires réelles ' +
    '(route_id → trip_id → direction_id → stop_id → stop_sequence → stop_times) ; ' +
    'un défaut de raccordement est listé dans `unresolved_public_lines` avec sa cause ' +
    'exacte et sa preuve de blocage (`blocking`), jamais masqué. `mapping_status` vaut ' +
    'CONNECTED uniquement si la chaîne complète existe ; sinon BLOCKED (route présente, ' +
    'maillon manquant) ou NOT_VERIFIED (aucune route de ce numéro). Aucune ligne n’est ' +
    'supprimée pour masquer un blocage, aucune identité publique distincte n’est fusionnée.',
  sources: SOURCES,
  counts: {
    aftu_official: aftuLines.length,
    ddd_public: dddLines.length,
    tata_identities: tataAudit.length,
    linked: allPublic.length - unresolved.length,
    unresolved: unresolved.length,
    connected: countStatus('CONNECTED'),
    blocked: countStatus('BLOCKED'),
    not_verified: countStatus('NOT_VERIFIED'),
    partial: countStatus('PARTIAL'),
    feed_routes_without_public_line:
      dddFeedOrphans.length + aftuFeedOrphans.length,
  },
  unresolved_public_lines: unresolved,
  // Routes du feed sans identité publique : constat documenté, jamais fusionné.
  feed_routes_without_public_line: {
    note:
      'Routes présentes dans le feed opérationnel PassBi dont le numéro public ' +
      'n’est PAS établi par le référentiel canonique publié. Aucune ligne n’est ' +
      'fabriquée et aucune n’est fusionnée avec une ligne existante.',
    DDD: dddFeedOrphans,
    AFTU: aftuFeedOrphans,
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
console.log(`Statuts : CONNECTED=${countStatus('CONNECTED')} BLOCKED=${countStatus('BLOCKED')} ` +
  `NOT_VERIFIED=${countStatus('NOT_VERIFIED')} PARTIAL=${countStatus('PARTIAL')}`);
if (unresolved.length > 0) {
  console.log('');
  console.log(`NON RACCORDÉES : ${unresolved.length} / ${allPublic.length} lignes publiques AFTU/DDD`);
  for (const u of unresolved) {
    console.log(`  - ${u.public_label} : ${u.reason} [${u.mapping_status}] ` +
      `(feed_route_ids=${JSON.stringify(u.feed_route_ids)})`);
  }
}
