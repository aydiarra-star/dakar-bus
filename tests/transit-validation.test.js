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
test('network cannot be derived from a TER-like ID', () => {
  const f=fixture(); f.stops[0].id='TER_01'; f.stops[0].network=undefined;
  has(validate(f),'STOP_NETWORK_INVALID'); has(validate(f),'STOP_NETWORK_MISMATCH');
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
test('missing provenance and UNKNOWN quality do not pass release', () => {
  const f=fixture(); f.stops[0].source=null; f.stops[1].dataStatus='UNKNOWN';
  has(validate(f),'STOP_SOURCE_MISSING'); has(validate(f),'STOP_DATA_UNVERIFIED'); assert.ok(v.blocksRelease(validate(f)));
});
test('static status allowed, LIVE and unsupported realtime rejected', () => {
  const f=fixture(); f.stops[0].status='SCHEDULED'; assert.deepEqual(validate(f),[]);
  f.stops[0].status='LIVE'; has(validate(f),'STOP_STATUS_INVALID');
  f.stops[0].status='REAL_TIME'; has(validate(f),'REALTIME_WITHOUT_EVIDENCE');
  f.stops[0].realtimeSource='test'; f.stops[0].observedAt='2026-09-21T07:00:00Z';
  assert.deepEqual(validate(f),[]);
});
test('unknown or approximate route never becomes exact by passing through stops', () => {
  for (const status of ['UNKNOWN','APPROXIMATE']) {
    const f=fixture(); f.route.geometry=f.stops.map(s=>[s.latitude,s.longitude]); f.route.geometryStatus=status;
    const out=validate(f); has(out,'ROUTE_GEOMETRY_UNVERIFIED'); has(out,'ALL_STOPS_ARE_GEOMETRY_VERTICES'); assert.ok(v.blocksRelease(out));
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
  const f=fixture(); f.route.geometrySource=null; has(validate(f),'ROUTE_GEOMETRY_UNVERIFIED');
  f.policy.maxStopDistanceMeters=-1; has(validate(f),'INVALID_DISTANCE_THRESHOLD');
});
test('published audit detects demo concatenation, missing Dart, unsafe shapes', () => {
  const f={network:{stops:[{id:'t',name:'test TER'},{id:'old',name:'legacy BRT'}],
    routes:[{operator_id:'ter',stops:['t']},{operator_id:'ddd',stops:['t']}]},
    compiled:'aW7(){ B.b.D($.di(),new A.cg(\ns($,"x","aCz",()=>A.cP())\ns($,"y","aCq",()=>A.cP())\ns($,"z",()=>{})',
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
