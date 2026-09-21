#!/usr/bin/env node
'use strict';
// Audit of the PWA in this checkout, NOT the Flutter app served by GitHub Pages.
// Legacy identifiers are interpreted only to inspect existing data. This adapter
// does not supply missing provenance/order/status to the application.
const fs = require('node:fs');
const path = require('node:path');
const v = require('./lib/transit-validation');
const root = path.join(__dirname, '..');
const policy = require('../data/transit/reference-policy.json');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
function csv(text) {
  const rows = text.trim().split(/\r?\n/).map(line => line.split(','));
  return rows.slice(1).map(cells => Object.fromEntries(rows[0].map((key,i) => [key, cells[i]])));
}
const raw = csv(read('data/gtfs/stops.txt')), trips = csv(read('data/gtfs/trips.txt'));
const times = csv(read('data/gtfs/stop_times.txt')), html = read('index.html');
const embedded = JSON.parse(html.match(/const ALL_ARRETS = (\[[\s\S]*?\n\]);/)[1]);
const issues = [];
const fail = (code,id,detail) => issues.push({severity:'ERROR',code,id,detail});
for (const network of ['TER','BRT']) {
  const rows = raw.filter(s => s.stop_id.startsWith(`${network}_`));
  const stops = rows.map(s => ({id:s.stop_id, name:s.stop_name,
    latitude:s.stop_lat?.trim() ? Number(s.stop_lat) : null,
    longitude:s.stop_lon?.trim() ? Number(s.stop_lon) : null,
    // Deliberately leave missing fields missing. Do not promote to VERIFIED.
    network:s.network, ordre_sur_ligne:s.ordre_sur_ligne ? Number(s.ordre_sur_ligne) : undefined,
    source:s.source, dataStatus:s.data_status, status:s.status, directions:undefined
  }));
  const forward = times.filter(t => t.trip_id === `${network}_01_001`).sort((a,b) => a.stop_sequence-b.stop_sequence).map(t => t.stop_id);
  const backward = times.filter(t => t.trip_id === `${network}_01_002`).sort((a,b) => a.stop_sequence-b.stop_sequence).map(t => t.stop_id);
  const geometry = JSON.parse(html.match(new RegExp(`const ${network}_SHAPE = (\\[[^;]+\\]);`))[1]);
  const route = { id:`${network}_01`,network,stopIds:forward,reverseStopIds:backward,
    geometry,geometryStatus:'UNKNOWN',geometrySource:null };
  issues.push(...(network==='TER' ? v.validateTerData : v.validateBrtData)(stops,route,policy.networks[network]));
  if (JSON.stringify(backward) !== JSON.stringify([...forward].reverse())) fail('GTFS_RETURN_ORDER_INVALID', network, 'Retour non inversé');
  console.log(`${network}: ${stops.length} entrées / ${policy.networks[network].expectedCount} attendues ; ${geometry.length} sommets NON VÉRIFIÉS`);
  for (const s of rows) {
    const e = embedded.find(e => e.id === s.stop_id);
    if (!e || e.name !== s.stop_name || e.lat !== Number(s.stop_lat) || e.lng !== Number(s.stop_lon)) fail('EMBEDDED_STOP_DIVERGENCE', s.stop_id, 'Nom ou coordonnées différents du GTFS');
  }
  const expectedHeadsigns = network==='TER' ? ['Diamniadio','Dakar'] : ['Guédiawaye','Petersen'];
  for (const [i, headsign] of expectedHeadsigns.entries()) {
    const trip = trips.find(t => t.trip_id === `${network}_01_00${i+1}`);
    if (!trip || trip.trip_headsign !== headsign) fail('TRIP_HEADSIGN_MISMATCH', trip?.trip_id || network, `Destination attendue selon la séquence actuelle : ${headsign}`);
  }
}
const knownTrips = new Set(trips.map(t => t.trip_id)), knownStops = new Set(raw.map(s => s.stop_id));
for (const [id, group] of Object.entries(times.reduce((groups,t) => { (groups[t.trip_id] ||= []).push(t); return groups; }, {}))) {
  const ordered = [...group].sort((a,b) => Number(a.stop_sequence)-Number(b.stop_sequence));
  const seqs = ordered.map(t => Number(t.stop_sequence));
  if (seqs.some((n,i) => n !== i+1)) fail('TRIP_SEQUENCE_INVALID', id, 'Séquence non contiguë ou dupliquée');
  const seconds = value => {
    if (!/^\d{2,}:\d{2}:\d{2}$/.test(value || '')) return NaN;
    const [h,m,s] = value.split(':').map(Number);
    return m < 60 && s < 60 ? h*3600 + m*60 + s : NaN;
  };
  let previous = -1;
  for (const t of ordered) {
    const arrival=seconds(t.arrival_time), departure=seconds(t.departure_time);
    if (!Number.isFinite(arrival) || !Number.isFinite(departure) || arrival < previous || departure < arrival) fail('TRIP_TIME_INVALID', id, t.stop_id);
    previous=departure;
  }
}
for (const t of times) {
  if (!knownTrips.has(t.trip_id)) fail('UNKNOWN_TRIP_REFERENCE', t.trip_id, t.stop_id);
  if (!knownStops.has(t.stop_id)) fail('UNKNOWN_STOP_REFERENCE', t.trip_id, t.stop_id);
}
console.log('\nAudit PWA seulement. Pour la production Flutter : npm run audit:pages');
const groups = new Map();
for (const i of issues) {
  if (!groups.has(i.code)) groups.set(i.code, []);
  groups.get(i.code).push(i);
}
for (const [code, list] of groups) console.log(`${list[0].severity} ${code} × ${list.length} — ${list[0].id}: ${list[0].detail}`);
if (v.blocksRelease(issues)) {
  console.error('\nNON CONFORME : effectifs seuls insuffisants. Coordonnées et corridors réels non certifiés.');
  process.exitCode = 1;
} else console.log('Référentiel conforme aux contrôles, sous réserve de la validité des sources déclarées.');
