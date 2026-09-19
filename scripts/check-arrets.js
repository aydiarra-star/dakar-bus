#!/usr/bin/env node
/**
 * Dakar Bus — Contrôle automatique du nombre d'arrêts (non-régression)
 * ---------------------------------------------------------------------
 * Garantit une fois pour toutes que :
 *   • TER  = 13 gares   (Dakar -> Diamniadio, phase 1 SETER/CETUD)
 *   • BRT  = 23 stations (corridor B1 omnibus PEM Petersen <-> PEM Guédiawaye)
 *   • BUS  =  6 pôles   -> total 42 arrêts
 *
 * Vérifie la cohérence entre TOUTES les sources :
 *   1. data/gtfs/stops.txt        (source officielle servie à la carte)
 *   2. data/gtfs/stop_times.txt   (les arrêts sont-ils réellement desservis ?)
 *   3. index.html                 (liste embarquée ALL_ARRETS + constantes de l'app)
 *   4. tracés TER/BRT             (chaque arrêt est-il posé sur son tracé ?)
 *
 * Usage : npm test   (ou : node scripts/check-arrets.js)
 * Sortie : code 0 si tout est conforme, code 1 sinon.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const ATTENDU = { TER: 13, BRT: 23, BUS: 6, TOTAL: 42 };

let echecs = 0;
const ok = (cond, msg, detail = '') => {
  if (cond) console.log(`  ✅ ${msg}`);
  else { echecs++; console.log(`  ❌ ${msg}${detail ? ' — ' + detail : ''}`); }
  return cond;
};
const titre = (t) => console.log(`\n${t}`);

// ---------------------------------------------------------------- utilitaires
const lire = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');
const csv = (txt) => {
  const [head, ...lignes] = txt.trim().split('\n');
  const cols = head.split(',').map((c) => c.trim());
  return lignes.filter((l) => l.trim()).map((l) => {
    const cells = l.split(',');
    return Object.fromEntries(cols.map((c, i) => [c, (cells[i] || '').trim()]));
  });
};
const secondes = (t) => { const [h, m, s] = t.split(':').map(Number); return h * 3600 + m * 60 + s; };
const metresEntre = (a, b) => {
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (b[0] - a[0]) * rad, dLon = (b[1] - a[1]) * rad;
  const x = dLon * Math.cos(((a[0] + b[0]) / 2) * rad);
  return Math.sqrt(dLat * dLat + x * x) * R;
};
/** distance d'un point au segment [p1,p2] (mètres) */
const distanceAuSegment = (p, p1, p2) => {
  const lat0 = p[0] * Math.PI / 180, mlat = 111320, mlon = 111320 * Math.cos(lat0);
  const toXY = (q) => [q[1] * mlon, q[0] * mlat];
  const [x, y] = toXY(p), [x1, y1] = toXY(p1), [x2, y2] = toXY(p2);
  const dx = x2 - x1, dy = y2 - y1, l2 = dx * dx + dy * dy;
  let t = l2 === 0 ? 0 : ((x - x1) * dx + (y - y1) * dy) / l2;
  t = Math.max(0, Math.min(1, t));
  const px = x1 + t * dx, py = y1 + t * dy;
  return Math.hypot(x - px, y - py);
};
const distanceAuTrace = (pt, trace) => {
  let min = Infinity;
  for (let i = 1; i < trace.length; i++) min = Math.min(min, distanceAuSegment(pt, trace[i - 1], trace[i]));
  return min;
};
/** bbox "grand Dakar" : tout arrêt hors de cette zone est une erreur de saisie */
const BBOX = { latMin: 14.55, latMax: 14.85, lonMin: -17.60, lonMax: -17.10 };

// ---------------------------------------------------------------- 1. stops.txt
titre('1) data/gtfs/stops.txt — source officielle servie à la carte');
const stops = csv(lire('data/gtfs/stops.txt'));
const terStops = stops.filter((s) => s.stop_id.startsWith('TER_'));
const brtStops = stops.filter((s) => s.stop_id.startsWith('BRT_'));
const busStops = stops.filter((s) => !s.stop_id.startsWith('TER_') && !s.stop_id.startsWith('BRT_'));

ok(terStops.length === ATTENDU.TER, `TER : ${terStops.length} gares (attendu ${ATTENDU.TER})`);
ok(brtStops.length === ATTENDU.BRT, `BRT : ${brtStops.length} stations (attendu ${ATTENDU.BRT})`);
ok(busStops.length === ATTENDU.BUS, `BUS : ${busStops.length} pôles (attendu ${ATTENDU.BUS})`);
ok(stops.length === ATTENDU.TOTAL, `TOTAL : ${stops.length} arrêts (attendu ${ATTENDU.TOTAL})`);

const numeros = (liste, prefixe) => liste.map((s) => Number(s.stop_id.slice(prefixe.length).split('_')[0]));
const terNums = numeros(terStops, 'TER_'), brtNums = numeros(brtStops, 'BRT_');
const contigu = (nums, n) => nums.length === n && [...new Set(nums)].length === n && Math.max(...nums) === n && nums.every((v) => v >= 1);
ok(contigu(terNums, ATTENDU.TER), `TER numérotées de 1 à ${ATTENDU.TER} sans trou ni doublon`, `reçu : ${[...terNums].sort((a, b) => a - b).join(',')}`);
ok(contigu(brtNums, ATTENDU.BRT), `BRT numérotées de 1 à ${ATTENDU.BRT} sans trou ni doublon`, `reçu : ${[...brtNums].sort((a, b) => a - b).join(',')}`);

const ids = stops.map((s) => s.stop_id);
ok(new Set(ids).size === ids.length, 'Aucun stop_id dupliqué');
const coords = stops.map((s) => `${s.stop_lat},${s.stop_lon}`);
ok(new Set(coords).size === coords.length, 'Aucune coordonnée GPS dupliquée (sinon marqueurs superposés)');
const horsZone = stops.filter((s) => {
  const lat = Number(s.stop_lat), lon = Number(s.stop_lon);
  return !(lat >= BBOX.latMin && lat <= BBOX.latMax && lon >= BBOX.lonMin && lon <= BBOX.lonMax);
});
ok(horsZone.length === 0, 'Toutes les coordonnées sont dans la région de Dakar', horsZone.map((s) => s.stop_id).join(', '));
ok(stops.every((s) => s.stop_name && s.stop_name.length > 1), 'Chaque arrêt possède un nom');

// ------------------------------------------------------- 2. stop_times.txt
titre('2) data/gtfs/stop_times.txt — les 13 gares et 23 stations sont réellement desservies');
const stopTimes = csv(lire('data/gtfs/stop_times.txt'));
const parTrip = stopTimes.reduce((acc, r) => ((acc[r.trip_id] = acc[r.trip_id] || []).push(r), acc), {});
const terTrip = parTrip['TER_01_001'] || [], brtTrip = parTrip['BRT_01_001'] || [];
ok(terTrip.length === ATTENDU.TER, `Trajet TER desservant ${terTrip.length} gares (attendu ${ATTENDU.TER})`);
ok(brtTrip.length === ATTENDU.BRT, `Trajet BRT desservant ${brtTrip.length} stations (attendu ${ATTENDU.BRT})`);
ok(new Set(terTrip.map((r) => r.stop_id)).size === ATTENDU.TER, 'Les 13 gares TER sont toutes distinctes dans le trajet');
ok(new Set(brtTrip.map((r) => r.stop_id)).size === ATTENDU.BRT, 'Les 23 stations BRT sont toutes distinctes dans le trajet');
ok(
  new Set(stopTimes.map((r) => r.stop_id)).size >= ATTENDU.TER + ATTENDU.BRT,
  'Tous les arrêts TER/BRT figurent dans les horaires'
);
const idsValides = new Set(ids);
const inconnus = stopTimes.filter((r) => !idsValides.has(r.stop_id));
ok(inconnus.length === 0, 'Aucun stop_id inconnu dans stop_times.txt', inconnus.map((r) => r.stop_id).join(', '));
let chrono = true;
Object.values(parTrip).forEach((rows) => {
  const tri = [...rows].sort((a, b) => Number(a.stop_sequence) - Number(b.stop_sequence));
  for (let i = 1; i < tri.length; i++) if (secondes(tri[i].arrival_time) < secondes(tri[i - 1].departure_time)) chrono = false;
});
ok(chrono, 'Horaires strictement croissants sur tous les trajets');

// ------------------------------------------------------------- 3. index.html
titre('3) index.html — liste embarquée et constantes de l’application');
const html = lire('index.html');
const blocArrets = html.match(/const ALL_ARRETS = (\[[\s\S]*?\n\]);/);
if (!ok(!!blocArrets, 'Liste ALL_ARRETS présente dans index.html')) {
  console.log('\n⛔ Arrêt du contrôle.'); process.exit(1);
}
const embarques = JSON.parse(blocArrets[1]);
const embTER = embarques.filter((a) => a.type === 'TER');
const embBRT = embarques.filter((a) => a.type === 'BRT');
const embBUS = embarques.filter((a) => a.type !== 'TER' && a.type !== 'BRT');
ok(embTER.length === ATTENDU.TER, `ALL_ARRETS : ${embTER.length} arrêts TER (attendu ${ATTENDU.TER})`);
ok(embBRT.length === ATTENDU.BRT, `ALL_ARRETS : ${embBRT.length} arrêts BRT (attendu ${ATTENDU.BRT})`);
ok(embBUS.length === ATTENDU.BUS, `ALL_ARRETS : ${embBUS.length} pôles bus (attendu ${ATTENDU.BUS})`);
ok(embarques.length === ATTENDU.TOTAL, `ALL_ARRETS : ${embarques.length} arrêts au total (attendu ${ATTENDU.TOTAL})`);

const idsEmbarques = new Set(embarques.map((a) => a.id).filter(Boolean));
const idsFichier = new Set(stops.map((s) => s.stop_id));
const divergence = [...idsFichier].filter((id) => !idsEmbarques.has(id)).concat([...idsEmbarques].filter((id) => !idsFichier.has(id)));
ok(divergence.length === 0, 'Liste embarquée et stops.txt strictement identiques', divergence.join(', '));

const attenduApp = html.match(/const NETWORK_OFFICIEL = \{ TER:(\d+), BRT:(\d+), BUS:(\d+) \};/);
if (ok(!!attenduApp, 'Constante NETWORK_OFFICIEL présente (comptage unique utilisé par la carte)')) {
  ok(
    Number(attenduApp[1]) === ATTENDU.TER && Number(attenduApp[2]) === ATTENDU.BRT && Number(attenduApp[3]) === ATTENDU.BUS,
    `NETWORK_OFFICIEL = ${attenduApp[1]}/${attenduApp[2]}/${attenduApp[3]} conforme`,
    `attendu ${ATTENDU.TER}/${ATTENDU.BRT}/${ATTENDU.BUS}`
  );
}
ok(/data-kind="stop"/.test(html), 'Les marqueurs d’arrêt sont identifiables sur la carte (data-kind="stop")');
ok(/function applyMapFilter\(\)/.test(html), 'La carte applique le filtre réseau (applyMapFilter)');
ok(/showToast\(`🚆 TER Dakar : \$\{s\.TER\} gares affichées/.test(html), 'Le compteur affiché est dynamique (plus de « 13 » codé en dur)');
const mentionsArrets = [...html.matchAll(/(\d+)\s+arrêts/g)].map((m) => Number(m[1]));
ok(!/40 arrêts/.test(html), 'Plus aucune mention obsolète de « 40 arrêts »');
ok(
  mentionsArrets.every((n) => n === ATTENDU.TOTAL),
  `Toutes les mentions d’arrêts affichent ${ATTENDU.TOTAL}`,
  `trouvé : ${[...new Set(mentionsArrets)].join(', ')}`
);
const mentionsGares = [...html.matchAll(/(\d+)\s+gares/g)].map((m) => Number(m[1]));
const mentionsStations = [...html.matchAll(/(\d+)\s+stations/g)].map((m) => Number(m[1]));
ok(mentionsGares.every((n) => n === ATTENDU.TER), `Toutes les mentions de gares affichent ${ATTENDU.TER}`, `trouvé : ${[...new Set(mentionsGares)].join(', ')}`);
ok(mentionsStations.every((n) => n === ATTENDU.BRT), `Toutes les mentions de stations affichent ${ATTENDU.BRT}`, `trouvé : ${[...new Set(mentionsStations)].join(', ')}`);

// ------------------------------------------------------ 4. tracés TER / BRT
titre('4) Tracés — chaque arrêt est-il posé sur le tracé de sa ligne ?');
const extraireTrace = (nom) => {
  const m = html.match(new RegExp(`const ${nom} = (\\[[\\s\\S]*?\\]);`));
  return m ? JSON.parse(m[1]) : [];
};
const TER_SHAPE = extraireTrace('TER_SHAPE');
const BRT_SHAPE = extraireTrace('BRT_SHAPE');
ok(TER_SHAPE.length > 10, `Tracé TER présent (${TER_SHAPE.length} points)`);
ok(BRT_SHAPE.length > 10, `Tracé BRT présent (${BRT_SHAPE.length} points)`);
const ecartMax = (liste, trace) => Math.max(...liste.map((s) => distanceAuTrace([Number(s.stop_lat), Number(s.stop_lon)], trace)));
const ecartTER = ecartMax(terStops, TER_SHAPE);
const ecartBRT = ecartMax(brtStops, BRT_SHAPE);
ok(ecartTER < 600, `Les 13 gares TER sont sur le tracé (écart max ${Math.round(ecartTER)} m)`);
ok(ecartBRT < 600, `Les 23 stations BRT sont sur le tracé (écart max ${Math.round(ecartBRT)} m)`);

// ------------------------------------------------------------- vérif. croisée
titre('5) Ordre officiel des arrêts');
const nom = (id) => stops.find((s) => s.stop_id === id).stop_name;
console.log('  🚆 TER 1→13 :', terNums.sort((a, b) => a - b).map((n) => nom(`TER_${String(n).padStart(2, '0')}_${terStops.find((s) => s.stop_id.startsWith(`TER_${String(n).padStart(2, '0')}`)).stop_id.split('_').slice(2).join('_')}`)).join(' → '));
console.log('  🚌 BRT 1→23 :', brtNums.sort((a, b) => a - b).map((n) => brtStops.find((s) => s.stop_id.startsWith(`BRT_${String(n).padStart(2, '0')}`)).stop_name).join(' → '));

// ------------------------------------------------------------------ résultat
if (echecs === 0) {
  console.log(`\n✅ CONFORME : ${ATTENDU.TER} gares TER + ${ATTENDU.BRT} stations BRT + ${ATTENDU.BUS} pôles bus = ${ATTENDU.TOTAL} arrêts, sur toutes les sources.`);
  process.exit(0);
} else {
  console.log(`\n❌ ${echecs} contrôle(s) en échec.`);
  process.exit(1);
}
