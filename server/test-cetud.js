#!/usr/bin/env node
// Test script pour CETUD GTFS-RT - teste avec ou sans clé
import dotenv from 'dotenv';
dotenv.config();

const TEST_URLS = [
  process.env.CETUD_VEHICLE_POSITIONS_URL,
  process.env.CETUD_TRIP_UPDATES_URL,
  process.env.CETUD_ALERTS_URL,
  'https://api.cetud.sn/gtfs-rt/vehiclePositions',
  'https://api.cetud.sn/gtfs-rt',
  'https://api.dakardemdikk.sn/api/gtfs-rt',
  'https://api.sunubrt.sn/gtfs-rt',
].filter(Boolean);

const API_KEY = process.env.CETUD_API_KEY || '';
const KEY_HEADER = process.env.CETUD_API_KEY_HEADER || 'X-API-Key';

async function testEndpoint(url) {
  console.log(`\n🔍 Testing: ${url}`);
  console.log(`   Key: ${API_KEY ? API_KEY.substring(0,8)+'...' : 'NONE (mock mode)'}`);
  
  const headers = {
    'User-Agent': 'DakarMobilite-Test/2.0',
    'Accept': 'application/x-protobuf, application/octet-stream, application/json, */*'
  };
  if (API_KEY) {
    if (KEY_HEADER.toLowerCase() === 'authorization' && !API_KEY.toLowerCase().startsWith('bearer')) {
      headers['Authorization'] = `Bearer ${API_KEY}`;
    } else {
      headers[KEY_HEADER] = API_KEY;
    }
  }

  try {
    const resp = await fetch(url, { headers, signal: AbortSignal.timeout(10000) });
    console.log(`   Status: ${resp.status} ${resp.statusText}`);
    console.log(`   Content-Type: ${resp.headers.get('content-type')}`);
    console.log(`   Content-Length: ${resp.headers.get('content-length') || 'unknown'}`);
    
    if (!resp.ok) {
      const text = await resp.text();
      console.log(`   Body (first 500 chars): ${text.substring(0,500)}`);
      return { url, ok: false, status: resp.status };
    }

    const buffer = await resp.arrayBuffer();
    console.log(`   Received: ${buffer.byteLength} bytes`);

    // Try to decode as protobuf if bindings available
    try {
      const { default: Gtfs } = await import('gtfs-realtime-bindings');
      const feed = Gtfs.transit_realtime.FeedMessage.decode(new Uint8Array(buffer));
      console.log(`   ✅ Protobuf decoded! Entities: ${feed.entity.length}`);
      if (feed.entity[0]) {
        console.log(`   First entity: ${JSON.stringify(feed.entity[0].id || feed.entity[0].vehicle?.vehicle?.label || 'no label').substring(0,200)}`);
      }
      return { url, ok: true, type: 'protobuf', count: feed.entity.length };
    } catch (e) {
      // Try JSON
      try {
        const text = new TextDecoder().decode(buffer);
        const json = JSON.parse(text);
        console.log(`   ✅ JSON parsed! Keys: ${Object.keys(json).join(', ')}`);
        if (json.entity) console.log(`   Entities: ${json.entity.length}`);
        return { url, ok: true, type: 'json', count: json.entity?.length || 0 };
      } catch {
        console.log(`   ⚠️ Not protobuf nor JSON, raw binary ${buffer.byteLength} bytes`);
        return { url, ok: true, type: 'binary', size: buffer.byteLength };
      }
    }
  } catch (err) {
    console.log(`   ❌ Error: ${err.message}`);
    return { url, ok: false, error: err.message };
  }
}

async function main() {
  console.log('🚀 CETUD GTFS-RT Endpoint Tester');
  console.log(`📅 ${new Date().toISOString()}`);
  console.log(`🔑 API Key: ${API_KEY ? 'SET' : 'NOT SET - will test without key'}`);
  
  const results = [];
  for (const url of TEST_URLS) {
    const res = await testEndpoint(url);
    results.push(res);
    await new Promise(r => setTimeout(r, 1000));
  }

  console.log('\n📊 Summary:');
  results.forEach(r => {
    const icon = r.ok ? '✅' : '❌';
    console.log(`  ${icon} ${r.url} -> ${r.ok ? `${r.type} (${r.count || r.size || 'ok'})` : `FAILED ${r.status || r.error}`}`);
  });

  const live = results.filter(r => r.ok);
  if (live.length > 0) {
    console.log(`\n🎉 Found ${live.length} working endpoint(s)! Update your .env:`);
    console.log(`CETUD_VEHICLE_POSITIONS_URL=${live[0].url}`);
    console.log(`USE_MOCK=false`);
    console.log(`\nThen restart: npm start`);
  } else {
    console.log(`\n⚠️ No live CETUD endpoint found. This is normal if you don't have a key.`);
    console.log(`The proxy will continue in MOCK mode with 127 realistic Dakar vehicles.`);
    console.log(`To get a key, contact CETUD: https://cetud.sn or Dakar Dem Dikk.`);
  }
}

main();
