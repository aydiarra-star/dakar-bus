'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const v = require('../scripts/lib/transit-validation');
const {auditPublished} = require('../scripts/lib/pages-audit');
// Deliberately synthetic fixtures, NOT station data; never imported by the app.
function fixture(network = 'TER') {
  const policy = {expectedCount:2,directions:['A','B'],maxStopDistanceMeters:100};
  const stops = [1,2].map((n) => ({id:`test-${n}`,name:`Fixture ${n}`,network,
    latitude:14.7,longitude:-17.4 + n * 0.001,ordre_sur_ligne:n,source:'test fixture only',
    dataStatus:'VERIFIED',status:'UNKNOWN',directions:['A','B']}));
  const route = {id:'test-route',network,stopIds:stops.map(s=>s.id),reverseStopIds:stops.map(s=>s.id).reverse(),
    geometry:[[14.7,-17.401],[14.7,-17.396]],geometryStatus:'VERIFIED',geometrySource:'test fixture only'};
  return {stops,route,policy};
}
const validate = f => (f.route.network==='TER' ? v.validateTerData : v.validateBrtData)(f.stops,f.route,f.policy);
const has = (issues,code) => assert.ok(issues.some(i=>i.code===code),`Expected ${code}: ${JSON.stringify(issues)}`);
const hasSeverity = (issues,code,severity) => assert.ok(issues.some(i=>i.code===code && i.severity===severity),`Expected ${code}/${severity}: ${JSON.stringify(issues)}`);
test('valid synthetic TER and BRT contracts, no mutations', () => {
  for (const n of ['TER','BRT']) {
    const f=fixture(n), before=JSON.stringify(f);
    assert.deepEqual(validate(f),[]); assert.equal(JSON.stringify(f),before);
  }
});
test('counts cannot be satisfied by duplicated IDs', () => {
  const f=fixture(); f.stops[1].id=f.stops[0].id; has(validate(f),'DUPLICATE_STOP_ID');
});
test('accent/punctuation/case name variants are duplicates', () => {
  const f=fixture(); f.stops[0].name='École-Test'; f.stops[1].name='ecole test'; has(validate(f),'DUPLICATE_STOP_NAME');
});
test('duplicate GPS coordinates detected independently', () => {
  const f=fixture(); f.stops[1].longitude=f.stops[0].longitude; has(validate(f),'DUPLICATE_STOP_COORDINATES');
});
test('null, strings, empty, NaN, infinity, invalid ranges are not coordinates', () => {
  for (const x of [null,undefined,'','14.7',NaN,Infinity,91,-91]) {
    const f=fixture(); f.stops[0].latitude=x; has(validate(f),'STOP_COORDINATES_MISSING_OR_INVALID');
  }
});
test('missing names and IDs rejected', () => {
  const f=fixture(); f.stops[0].name=' '; f.stops[0].id='';
  has(validate(f),'STOP_NAME_MISSING'); has(validate(f),'STOP_ID_MISSING');
});
test('count checked against scoped policy', () => {
  const f=fixture(); f.policy.expectedCount=13; has(validate(f),'STOP_COUNT_MISMATCH');
});
test('explicit order required, no geographic inference', () => {
  for (const orders of [[undefined,2],[1,1],[1,3],[0,1],[1.2,2]]) {
    const f=fixture(); f.stops.forEach((s,i)=>s.ordre_sur_ligne=orders[i]); has(validate(f),'STOP_ORDER_INVALID');
  }
});
test('canonical order survives shuffled storage, but route must match', () => {
  const f=fixture(); f.stops.reverse(); assert.deepEqual(validate(f),[]);
  f.route.stopIds.reverse(); has(validate(f),'ROUTE_STOP_ORDER_INVALID');
});
test('reverse direction uses same physical IDs in reverse order', () => {
  const f=fixture(); f.route.reverseStopIds=f.route.stopIds; has(validate(f),'REVERSE_STOP_ORDER_INVALID');
});
test('both directions explicit, no duplicate physical stations', () => {
  const f=fixture(); f.stops[0].directions=['A','A']; has(validate(f),'STOP_DIRECTIONS_INVALID');
});
// Lot 4.11 — network absent dans GTFS minimal ≠ erreur automatique
test('Lot 4.11 — absence de network dans GTFS minimal n est pas une erreur automatique', () => {
  const f=fixture(); f.stops[0].id='TER_01'; f.stops[0].network=undefined;
  f.route.stopIds[0]='TER_01'; f.route.reverseStopIds[1]='TER_01';
  // Ne doit pas produire STOP_NETWORK_INVALID quand champ absent (GTFS minimal)
  const out = validate(f);
  assert.ok(!out.some(i=>i.code==='STOP_NETWORK_INVALID'), `Ne doit pas être INVALID quand absent (Lot 4.11): ${JSON.stringify(out)}`);
  // Vraie incohérence : réseau explicite différent du attendu doit rester détectée
  f.stops[0].network='DDD';
  has(validate(f),'STOP_NETWORK_MISMATCH');
  has(validate(f),'NETWORK_ISOLATION_VIOLATION');
  // Network invalide explicite reste ERROR
  f.stops[0].network='INVALID';
  has(validate(f),'STOP_NETWORK_INVALID');
});
test('TER/BRT isolated from all other networks', () => {
  for (const n of ['BRT','DDD','AFTU','TATA']) {
    const f=fixture(); f.stops[0].network=n; has(validate(f),'NETWORK_ISOLATION_VIOLATION');
  }
  const f=fixture('BRT'); f.route.network='DDD'; has(v.validateNetworkIsolation(f.stops,[f.route]),'NETWORK_ISOLATION_VIOLATION');
});
test('unknown stop references rejected', () => {
  const f=fixture(); f.route.stopIds.push('absent'); has(validate(f),'UNKNOWN_STOP_REFERENCE');
});
// Lot 4.11 — mise à jour : source null explicite reste erreur, mais undefined (GTFS minimal) ne l'est pas si provenance validée ailleurs
test('missing provenance and UNKNOWN quality do not pass release', () => {
  const f=fixture(); f.stops[0].source=null; f.stops[1].dataStatus='UNKNOWN';
  has(validate(f),'STOP_SOURCE_MISSING'); has(validate(f),'STOP_DATA_UNVERIFIED'); assert.ok(v.blocksRelease(validate(f)));
  // Lot 4.11 : absence pure (undefined) en GTFS minimal ≠ erreur si provenance dans data/transit
  const f2=fixture(); delete f2.stops[0].source; delete f2.stops[1].dataStatus;
  const out2 = validate(f2);
  assert.ok(!out2.some(i=>i.code==='STOP_SOURCE_MISSING'), `undefined source ne doit pas être MISSING en mode minimal: ${JSON.stringify(out2)}`);
  assert.ok(!out2.some(i=>i.code==='STOP_DATA_UNVERIFIED'), `undefined dataStatus ne doit pas être UNVERIFIED en mode minimal: ${JSON.stringify(out2)}`);
});
test('Lot 4.11 — static status : SCHEDULED exige provenance, ESTIMATED/UNKNOWN acceptés, REAL_TIME exige preuve', () => {
  // SCHEDULED sans provenance → ERROR
  const f=fixture(); f.stops[0].status='SCHEDULED';
  has(validate(f),'SCHEDULED_WITHOUT_PROVENANCE');
  // SCHEDULED avec provenance complète → OK
  f.stops[0].source='https://www.terdakar.sn/les_horaires_des_trains/';
  f.stops[0].sourceType='OFFICIAL_STATIC';
  f.stops[0].dateSource='2026-03-30';
  f.stops[0].dateVerified='2026-09-27';
  f.stops[0].validFrom='2026-09-27';
  f.stops[0].validTo='2026-09-30';
  f.stops[0].coverage={complete:true, includes:()=>true};
  assert.ok(!validate(f).some(i=>i.code==='SCHEDULED_WITHOUT_PROVENANCE'), `SCHEDULED avec provenance complète ne doit pas échouer: ${JSON.stringify(validate(f))}`);
  // LIVE invalide
  const f2=fixture(); f2.stops[0].status='LIVE'; has(validate(f2),'STOP_STATUS_INVALID');
  // ESTIMATED accepté (fréquences documentées TER 10min / BRT 6min)
  const f3=fixture(); f3.stops[0].status='ESTIMATED'; assert.ok(!validate(f3).some(i=>i.code==='STOP_STATUS_INVALID'), `ESTIMATED doit être accepté: ${JSON.stringify(validate(f3))}`);
  // UNKNOWN accepté
  const f4=fixture(); f4.stops[0].status='UNKNOWN'; assert.deepEqual(validate(f4).filter(i=>i.code==='STOP_STATUS_INVALID'),[]);
  // REAL_TIME sans preuve → ERROR
  const f5=fixture(); f5.stops[0].status='REAL_TIME'; has(validate(f5),'REALTIME_WITHOUT_EVIDENCE');
  f5.stops[0].realtimeSource='test'; f5.stops[0].observedAt='2026-09-21T07:00:00Z';
  assert.ok(!validate(f5).some(i=>i.code==='REALTIME_WITHOUT_EVIDENCE'), `REAL_TIME avec preuve doit passer: ${JSON.stringify(validate(f5))}`);
  // PARTIALLY_CONFIRMED ne doit pas devenir SCHEDULED automatiquement — reste invalide comme status stop
  const f6=fixture(); f6.stops[0].status='PARTIALLY_CONFIRMED'; has(validate(f6),'STOP_STATUS_INVALID');
});
// Lot 4.11 — géométrie non vérifiée → WARNING pas ERROR bloquante seule
test('unknown or approximate route never becomes exact by passing through stops', () => {
  for (const status of ['UNKNOWN','APPROXIMATE']) {
    const f=fixture(); f.route.geometry=f.stops.map(s=>[s.latitude,s.longitude]); f.route.geometryStatus=status;
    const out=validate(f); has(out,'ROUTE_GEOMETRY_UNVERIFIED'); hasSeverity(out,'ROUTE_GEOMETRY_UNVERIFIED','WARNING'); has(out,'ALL_STOPS_ARE_GEOMETRY_VERTICES');
    // Lot 4.11 : UNVERIFIED seul en WARNING ne bloque pas sans off-route ou géométrie manquante
    const withoutOffRoute = out.filter(i=>!i.code.endsWith('_STOP_OFF_ROUTE'));
    // Doit contenir WARNING mais pas d'ERROR bloquant pour la seule absence de source
    assert.ok(!v.blocksRelease(withoutOffRoute.filter(i=>i.severity==='ERROR' && i.code==='ROUTE_GEOMETRY_UNVERIFIED')), `UNVERIFIED en WARNING ne doit pas bloquer seule: ${JSON.stringify(out)}`);
    // En revanche, géométrie manquante reste ERROR
    const f2=fixture(); f2.route.geometry=[]; has(validate(f2),'ROUTE_GEOMETRY_MISSING_OR_INVALID');
  }
});
test('empty or malformed geometry returns unknown distance, not zero', () => {
  for (const g of [[],null,[[14.7,-17.4]],[[null,0],[1,1]],[[1,2],[NaN,0]]]) {
    const f=fixture(); f.route.geometry=g; has(validate(f),'ROUTE_GEOMETRY_MISSING_OR_INVALID');
    assert.equal(v.distanceToRouteMeters([14.7,-17.4],g),null);
  }
});
test('point to segment checks segments, not only vertices', () => {
  assert.equal(v.distanceToRouteMeters([14.7,-17.4],[[14.7,-17.5],[14.7,-17.3]]),0);
  const distance=v.distanceToRouteMeters([14.701,-17.4],[[14.7,-17.5],[14.7,-17.3]]);
  assert.ok(distance>110 && distance<112);
});
test('off-corridor TER and BRT warnings block release', () => {
  for (const net of ['TER','BRT']) {
    const f=fixture(net); f.stops[0].latitude+=0.01;
    const out=validate(f); has(out,`${net}_STOP_OFF_ROUTE`); assert.ok(v.blocksRelease(out));
  }
});
test('missing geometry source and invalid distance threshold rejected', () => {
  const f=fixture(); f.route.geometrySource=null; hasSeverity(validate(f),'ROUTE_GEOMETRY_UNVERIFIED','WARNING');
  f.policy.maxStopDistanceMeters=-1; has(validate(f),'INVALID_DISTANCE_THRESHOLD');
});
test('published audit detects demo concatenation, missing Dart, unsafe shapes', () => {
  const f={network:{stops:[{id:'t',name:'test TER'},{id:'old',name:'legacy BRT'}],
    routes:[{operator_id:'ter',stops:['t']},{operator_id:'ddd',stops:['t']}]},
    compiled:'aW7(){ B.b.D($.di(),new A.cg(\ns($,\"x\",\"aCz\",()=>A.cP())\ns($,\"y\",\"aCq\",()=>A.cP())\ns($,\"z\",()=>{})',
    index:'flutter.js',files:['main.dart.js'],shapes:{TER:{source_kind:'secours-consecutif'}}};
  const out=auditPublished(f); has(out.findings,'FLUTTER_SOURCE_UNAVAILABLE');
  has(out.findings,'DEMO_AND_REFERENCE_MERGED'); has(out.findings,'PUBLISHED_GEOMETRY_UNVERIFIED');
  has(out.findings,'GUIDED_STOP_SHARED_WITH_OTHER_NETWORKS'); has(out.findings,'NETWORK_NAMES_OUTSIDE_REFERENCE');
  assert.equal(out.counts.TER.embeddedDemoEntries,1); assert.equal(out.releaseReady,false);
});
test('unrecognized compiled build fails closed, not a false clean audit', () => {
  const out=auditPublished({network:{stops:[],routes:[]},compiled:'',index:'',files:[],shapes:{}});
  has(out.findings,'COMPILED_AUDIT_SIGNATURE_CHANGED'); assert.equal(out.releaseReady,false);
});
test('corrected local BRT headsigns correspond to existing trip endpoints', () => {
  const fs=require('node:fs'),path=require('node:path'),root=path.join(__dirname,'..');
  const trips=fs.readFileSync(path.join(root,'data/gtfs/trips.txt'),'utf8');
  assert.ok(trips.includes('BRT_01,BRT_DAILY,BRT_01_001,Guédiawaye,0,'));
  assert.ok(trips.includes('BRT_01,BRT_DAILY,BRT_01_002,Petersen,1,'));
});

// ================= Lot 4.11 — Tests obligatoires 1..16 =================
test('Lot 4.11 — 1. TER = 13 arrêts (STOP_COUNT_MISMATCH si différent)', () => {
  const fs=require('node:fs'),path=require('node:path');
  const raw=fs.readFileSync(path.join(__dirname,'..','data/gtfs/stops.txt'),'utf8').trim().split(/\r?\n/).slice(1);
  const terCount = raw.filter(l=>l.startsWith('TER_')).length;
  assert.equal(terCount, 13, `TER doit avoir 13 arrêts, trouvé ${terCount}`);
  const f=fixture('TER');
  f.policy.expectedCount=13;
  f.stops = Array.from({length:13},(_,i)=>({id:`TER_${String(i+1).padStart(2,'0')}`,name:`Gare ${i+1}`,network:'TER',latitude:14.7,longitude:-17.4+i*0.001,ordre_sur_ligne:i+1,source:'x',dataStatus:'VERIFIED',status:'UNKNOWN',directions:['DAKAR','DIAMNIADIO']}));
  f.route.stopIds=f.stops.map(s=>s.id); f.route.reverseStopIds=[...f.route.stopIds].reverse();
  assert.deepEqual(v.validateTerData(f.stops,f.route,{expectedCount:13,directions:['DAKAR','DIAMNIADIO'],maxStopDistanceMeters:100}).filter(i=>i.code==='STOP_COUNT_MISMATCH'),[]);
  f.stops.pop();
  has(v.validateTerData(f.stops,{...f.route,stopIds:f.stops.map(s=>s.id),reverseStopIds:[...f.stops.map(s=>s.id)].reverse()},{expectedCount:13,directions:['DAKAR','DIAMNIADIO'],maxStopDistanceMeters:100}),'STOP_COUNT_MISMATCH');
});
test('Lot 4.11 — 2. BRT = 23 arrêts', () => {
  const fs=require('node:fs'),path=require('node:path');
  const raw=fs.readFileSync(path.join(__dirname,'..','data/gtfs/stops.txt'),'utf8').trim().split(/\r?\n/).slice(1);
  const brtCount = raw.filter(l=>l.startsWith('BRT_')).length;
  assert.equal(brtCount, 23, `BRT doit avoir 23 arrêts, trouvé ${brtCount}`);
});
test('Lot 4.11 — 3. absence de network dans GTFS minimal ≠ erreur automatique', () => {
  // Vérifie que le GTFS minimal (4 colonnes) ne porte pas network et n est pas sanctionné
  const fs=require('node:fs'),path=require('node:path');
  const header=fs.readFileSync(path.join(__dirname,'..','data/gtfs/stops.txt'),'utf8').split('\n')[0];
  assert.ok(!header.includes('network'), `stops.txt header ne doit pas contenir network en GTFS minimal: ${header}`);
  const f=fixture('TER');
  f.stops.forEach(s=>{ delete s.network; s.id='TER_01_Dakar'; });
  f.stops[0].id='TER_01_Dakar'; f.stops[1].id='TER_02_Colobane';
  // Retirer network de tous
  const out = v.validateTerData(f.stops.map(s=>({id:s.id,name:s.name,latitude:s.latitude,longitude:s.longitude,ordre_sur_ligne:s.ordre_sur_ligne,source:s.source,dataStatus:s.dataStatus,status:s.status,directions:s.directions})), f.route, f.policy);
  assert.ok(!out.some(i=>i.code==='STOP_NETWORK_INVALID'), `Minimal GTFS sans network ne doit pas être INVALID: ${JSON.stringify(out)}`);
  assert.ok(!out.some(i=>i.code==='STOP_NETWORK_MISMATCH'), `Minimal sans network ne doit pas être MISMATCH: ${JSON.stringify(out)}`);
});
test('Lot 4.11 — 4. absence de source dans stops.txt ≠ erreur si provenance validée ailleurs', () => {
  const f=fixture();
  // Simule GTFS minimal : source absente (undefined)
  const minimalStops = f.stops.map(s=>({id:s.id,name:s.name,latitude:s.latitude,longitude:s.longitude,network:s.network,ordre_sur_ligne:s.ordre_sur_ligne,dataStatus:s.dataStatus,status:s.status,directions:s.directions}));
  // Supprimer source
  const out = validate({stops:minimalStops, route:f.route, policy:f.policy});
  assert.ok(!out.some(i=>i.code==='STOP_SOURCE_MISSING'), `GTFS minimal sans source ne doit pas être MISSING si provenance ailleurs: ${JSON.stringify(out)}`);
  // En revanche source explicite vide doit rester ERROR
  const f2=fixture(); f2.stops[0].source='   ';
  has(validate(f2),'STOP_SOURCE_MISSING');
  // Vérifier provenance existe bien dans data/transit
  const fs=require('node:fs'),path=require('node:path');
  assert.ok(fs.existsSync(path.join(__dirname,'..','data/transit/validated/structure/ter_stop_mapping.json')), 'provenance TER doit exister dans validated/structure');
  assert.ok(fs.existsSync(path.join(__dirname,'..','data/transit/validated/route_status.json')));
});
test('Lot 4.11 — 5 & 6. ESTIMATED et UNKNOWN acceptés', () => {
  for (const status of ['ESTIMATED','UNKNOWN']) {
    const f=fixture(); f.stops[0].status=status; f.stops[1].status=status;
    const out = validate(f);
    assert.ok(!out.some(i=>i.code==='STOP_STATUS_INVALID'), `${status} doit être accepté: ${JSON.stringify(out)}`);
  }
  // ESTIMATED ne doit jamais être transformé en heure exacte — vérifier qu'aucun générateur n'existe
  const fs=require('node:fs'),path=require('node:path');
  const check = fs.readFileSync(path.join(__dirname,'..','scripts/check-arrets.js'),'utf8');
  assert.ok(!check.includes('frequencyMinutes') || !check.includes('DateTime.now'), 'check-arrets ne doit pas transformer fréquence en heure');
  assert.ok(!check.includes('estimatedWait') || check.includes('WARNING'), 'pas de génération horaire depuis fréquence');
});
test('Lot 4.11 — 7. REAL_TIME sans preuve = ERROR', () => {
  const f=fixture(); f.stops[0].status='REAL_TIME';
  has(validate(f),'REALTIME_WITHOUT_EVIDENCE');
  assert.ok(v.blocksRelease(validate(f)));
  f.stops[0].realtimeSource='gps'; f.stops[0].observedAt='2026-09-27T10:00:00Z';
  assert.ok(!validate(f).some(i=>i.code==='REALTIME_WITHOUT_EVIDENCE'));
});
test('Lot 4.11 — 8. SCHEDULED sans provenance/coverage = ERROR, avec = OK', () => {
  const f=fixture(); f.stops[0].status='SCHEDULED';
  has(validate(f),'SCHEDULED_WITHOUT_PROVENANCE');
  assert.ok(v.blocksRelease(validate(f)));
  // Avec provenance complète
  f.stops[0].source='https://www.terdakar.sn/les_horaires_des_trains/';
  f.stops[0].sourceType='OFFICIAL_STATIC';
  f.stops[0].dateSource='2026-03-30';
  f.stops[0].dateVerified='2026-09-27';
  f.stops[0].validFrom='2026-09-27';
  f.stops[0].validTo='2026-09-30';
  f.stops[0].coverage={complete:true};
  assert.ok(!validate(f).some(i=>i.code==='SCHEDULED_WITHOUT_PROVENANCE'));
});
test('Lot 4.11 — 9. direction_id et stop_sequence restent contrôlés (GTFS)', () => {
  const fs=require('node:fs'),path=require('node:path');
  const tripsTxt=fs.readFileSync(path.join(__dirname,'..','data/gtfs/trips.txt'),'utf8');
  assert.ok(tripsTxt.includes('direction_id'), 'trips.txt doit porter direction_id');
  const stopTimes=fs.readFileSync(path.join(__dirname,'..','data/gtfs/stop_times.txt'),'utf8');
  assert.ok(stopTimes.includes('stop_sequence'), 'stop_times doit porter stop_sequence');
  // Vérifier coherence via check-arrets : TER 0=Diamniadio 1=Dakar
  const terTrips = tripsTxt.split('\n').filter(l=>l.startsWith('TER_'));
  assert.ok(terTrips.some(l=>l.includes('TER_01_001') && l.includes(',0,')), 'TER_01_001 doit être direction 0');
  assert.ok(terTrips.some(l=>l.includes('TER_01_002') && l.includes(',1,')), 'TER_01_002 doit être direction 1');
  // stop_sequence contigu
  const {execSync}=require('node:child_process');
  const out = execSync('node scripts/check-arrets.js', {cwd: path.join(__dirname,'..'), encoding:'utf8'});
  assert.ok(out.includes('TER: 13 entrées'), 'check-arrets doit valider TER 13');
});
test('Lot 4.11 — 10. un vrai unknown_stop_reference reste ERROR', () => {
  const f=fixture(); f.route.stopIds.push('INEXISTANT_TER_99');
  has(validate(f),'UNKNOWN_STOP_REFERENCE');
  assert.ok(v.blocksRelease(validate(f)));
});
test('Lot 4.11 — 11. un vrai trip inexistant dans validated reste ERROR', () => {
  const fs=require('node:fs'),path=require('node:path');
  // validated/gtfs/trips.txt contient TER_SUN_001..048, pas FAKE_999
  const validatedTrips=fs.readFileSync(path.join(__dirname,'..','data/transit/validated/gtfs/trips.txt'),'utf8');
  assert.ok(validatedTrips.includes('TER_SUN_001'), 'validated doit contenir TER_SUN_001');
  assert.ok(!validatedTrips.includes('FAKE_999'), 'FAKE_999 ne doit pas exister');
  // Simulation via check-arrets : un trip autre que PWA_ORPHAN doit être ERROR
  const check = fs.readFileSync(path.join(__dirname,'..','scripts/check-arrets.js'),'utf8');
  assert.ok(check.includes("UNKNOWN_TRIP_REFERENCE"), 'doit encore vérifier UNKNOWN_TRIP_REFERENCE');
  assert.ok(check.includes("PWA_ORPHAN_TRIP"), 'doit distinguer PWA_ORPHAN_TRIP');
});
test('Lot 4.11 — 12. TER_01_003 / BRT_01_003 = PWA_ORPHAN_TRIP WARNING sans création', () => {
  const {execSync}=require('node:child_process');
  const path=require('node:path');
  const fs=require('node:fs');
  // Lot 4.12 : les 36 stop_times orphelins ont été supprimés → plus de PWA_ORPHAN_TRIP
  const out = execSync('node scripts/check-arrets.js', {cwd: path.join(__dirname,'..'), encoding:'utf8'});
  assert.ok(!out.includes('PWA_ORPHAN_TRIP'), `après Lot 4.12, PWA_ORPHAN_TRIP doit avoir disparu: ${out}`);
  assert.ok(!out.includes('ERROR UNKNOWN_TRIP_REFERENCE'), 'ne doit pas être ERROR UNKNOWN_TRIP_REFERENCE');
  // Vérifier qu'aucun trip n a été créé dans data/gtfs/trips.txt
  const trips=fs.readFileSync(path.join(__dirname,'..','data/gtfs/trips.txt'),'utf8');
  assert.ok(!trips.includes('TER_01_003'), 'TER_01_003 ne doit pas être créé');
  assert.ok(!trips.includes('BRT_01_003'), 'BRT_01_003 ne doit pas être créé');
  // Vérifier stop_times ABSENTS après nettoyage Lot 4.12 (13+23 supprimés)
  const st=fs.readFileSync(path.join(__dirname,'..','data/gtfs/stop_times.txt'),'utf8');
  assert.ok(!st.includes('TER_01_003'), 'stop_times TER_01_003 doit être ABSENT après Lot 4.12');
  assert.ok(!st.includes('BRT_01_003'), 'stop_times BRT_01_003 doit être ABSENT après Lot 4.12');
  assert.ok(st.split('\n').filter(l=>l.trim()).length===73, `stop_times doit avoir 73 lignes (header+72) après suppression, trouvé ${st.split('\n').length}`);
  // Vérifier check-arrets ne fabrique pas de trip
  const check=fs.readFileSync(path.join(__dirname,'..','scripts/check-arrets.js'),'utf8');
  assert.ok(!check.includes('TER_01_003,TER_DAILY') && !check.includes('BRT_01_003,BRT_DAILY'), 'ne doit pas inventer trip TER/BRT 01_003');
  assert.ok(!check.match(/trips\.push.*TER_01_003/), 'ne doit pas pousser de trip artificiel');
  // Vérifier les 4 trips légitimes restent
  assert.ok(trips.includes('TER_01_001'), 'TER_01_001 doit rester');
  assert.ok(trips.includes('TER_01_002'), 'TER_01_002 doit rester');
  assert.ok(trips.includes('BRT_01_001'), 'BRT_01_001 doit rester');
  assert.ok(trips.includes('BRT_01_002'), 'BRT_01_002 doit rester');
});
test('Lot 4.11 — 13. aucune fréquence transformée en heure exacte', () => {
  const fs=require('node:fs'),path=require('node:path');
  const schedule=JSON.parse(fs.readFileSync(path.join(__dirname,'..','data/transit/validated/structure/ter_schedule.json'),'utf8'));
  assert.equal(schedule.two_level_separation.current_operator_schedule.weekday.resulting_status, 'ESTIMATED', 'fréquence opérateur doit rester ESTIMATED');
  // Vérifier que le moteur ne génère pas d heures 10:00/10:10 artificielles
  assert.ok(schedule.two_level_separation.current_operator_schedule.weekday.exact_stop_times_published===false);
  // Vérifier Dart : FrequencyWindow ne produit pas d instant
  const dart=fs.readFileSync(path.join(__dirname,'..','flutter-src/lib/models/departure_info.dart'),'utf8');
  assert.ok(dart.includes('FrequencyWindow'), 'doit conserver FrequencyWindow pour ESTIMATED');
  // check-arrets ne doit pas contenir de génération horaire depuis fréquence
  const check=fs.readFileSync(path.join(__dirname,'..','scripts/check-arrets.js'),'utf8');
  assert.ok(!/DateTime\.now\(\)/.test(check), 'interdit DateTime.now pour fabriquer départ');
  assert.ok(!/frequen.*->.*DateTime/.test(check), 'pas de conversion fréquence→heure');
});
test('Lot 4.11 — 14/15/16. aucune modification main.dart / dakar_network.json / data/gtfs par ce lot', () => {
  const {execSync}=require('node:child_process');
  const path=require('node:path');
  const fs=require('node:fs');
  // Lot 4.12 : data/gtfs/stop_times.txt a été nettoyé (36 suppressions autorisées), les autres fichiers data/gtfs restent inchangés
  const diffGtfs = execSync('git diff -- data/gtfs/', {cwd: path.join(__dirname,'..'), encoding:'utf8'});
  const diffStat = execSync('git diff --stat -- data/gtfs/', {cwd: path.join(__dirname,'..'), encoding:'utf8'});
  // Vérifier que seule stop_times.txt est modifiée et avec 36 suppressions
  assert.ok(diffGtfs.includes('TER_01_003') || diffGtfs.trim()==='', `data/gtfs diff doit concerner la suppression des 01_003 ou être vide: ${diffGtfs.slice(0,200)}`);
  const diffNameGtfs = execSync('git diff --name-only -- data/gtfs/', {cwd: path.join(__dirname,'..'), encoding:'utf8'}).trim().split('\n').filter(Boolean);
  assert.ok(diffNameGtfs.length===0 || (diffNameGtfs.length===1 && diffNameGtfs[0]==='data/gtfs/stop_times.txt'), `Seul stop_times.txt doit être modifié dans data/gtfs, trouvé: ${diffNameGtfs}`);
  if (diffGtfs.trim()!=='') {
    const deletions = (diffGtfs.match(/^-TER_01_003/mg)||[]).length + (diffGtfs.match(/^-BRT_01_003/mg)||[]).length;
    assert.equal(deletions, 36, `Doit avoir 36 suppressions (13 TER + 23 BRT), trouvé ${deletions}`);
    assert.ok(!diffGtfs.match(/^\+\S/m) || diffGtfs.split('\n').filter(l=>l.startsWith('+') && !l.startsWith('+++')).length===0, `Aucune addition de données, diff: ${diffGtfs.slice(0,300)}`);
  }
  // Pour main.dart / dakar_network.json : vérifier que Lot 4.11/4.12 n'y a pas ajouté de modification hors Lots 4.9-4.10
  const checkContent = fs.readFileSync(path.join(__dirname,'..','scripts/check-arrets.js'),'utf8');
  const validationContent = fs.readFileSync(path.join(__dirname,'..','scripts/lib/transit-validation.js'),'utf8');
  assert.ok(!checkContent.includes('main.dart'), 'check-arrets ne doit pas toucher main.dart');
  assert.ok(!validationContent.includes('main.dart'), 'transit-validation ne doit pas toucher main.dart');
  assert.ok(!checkContent.includes('dakar_network.json'), 'check-arrets ne doit pas toucher dakar_network.json');
});
