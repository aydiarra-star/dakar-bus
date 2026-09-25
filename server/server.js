import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import compression from 'compression';
import morgan from 'morgan';
import NodeCache from 'node-cache';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
// MOTEUR D'ESTIMATION — politique des données temps réel simulées (2026-09-25).
// Une position ou un retard inventés ne doivent JAMAIS être servis comme du
// temps réel : voir engine/gtfs-rt-policy.js et docs/AUDIT_MOTEUR_DEPARTS_2026-09-25.md.
import gtfsRtPolicy from '../engine/gtfs-rt-policy.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.join(__dirname, '..');

const app = express();
const PORT = process.env.PORT || 8000;

// Cache 30s pour GTFS-RT, 7 jours pour tuiles (géré côté SW)
const gtfsCache = new NodeCache({ stdTTL: parseInt(process.env.CACHE_TTL_SECONDS || '30'), checkperiod: 10 });
const staticCache = new NodeCache({ stdTTL: 60 * 60 * 24, checkperiod: 600 });

// Middleware
app.use(compression());
app.use(morgan('dev'));
app.use(cors({
  origin: (origin, cb) => {
    const allowed = (process.env.ALLOWED_ORIGINS || '*').split(',').map(s => s.trim());
    if (!origin || allowed.includes('*') || allowed.some(a => origin.includes(a.replace('*.','')))) {
      cb(null, true);
    } else {
      cb(null, true); // en dev on autorise tout
    }
  },
  credentials: true
}));
app.use(express.json());

// Try to load gtfs-realtime-bindings (optional, for protobuf)
let GtfsRealtimeBindings = null;
try {
  const mod = await import('gtfs-realtime-bindings');
  GtfsRealtimeBindings = mod.default || mod;
  console.log('✅ gtfs-realtime-bindings loaded - protobuf support OK');
} catch (e) {
  console.warn('⚠️ gtfs-realtime-bindings not installed yet, will use JSON mode. Run npm install');
}

// ---------- MOCK GENERATOR DAKAR REALISTE ----------
function generateMockDakarGTFS(type = 'vehiclePositions') {
  const now = Math.floor(Date.now() / 1000);
  const routes = [
    { id: 'BRT_01', short: 'BRT 01', color: '#8b5cf6', baseLat: 14.75, baseLng: -17.42, count: 23 },
    { id: 'DDD_10', short: 'DDD 10', color: '#3b82f6', baseLat: 14.6937, baseLng: -17.4441, count: 18 },
    { id: 'DDD_07', short: 'DDD 07', color: '#3b82f6', baseLat: 14.71, baseLng: -17.46, count: 15 },
    { id: 'DDD_12', short: 'DDD 12', color: '#3b82f6', baseLat: 14.73, baseLng: -17.48, count: 12 },
    { id: 'TATA', short: 'Car Rapide', color: '#f59e0b', baseLat: 14.685, baseLng: -17.45, count: 34 },
    { id: 'TER', short: 'TER', color: '#10b981', baseLat: 14.68, baseLng: -17.43, count: 3 },
    { id: 'AFTU_01', short: 'AFTU 01', color: '#ec4899', baseLat: 14.76, baseLng: -17.52, count: 22 },
  ];

  if (type === 'vehiclePositions') {
    const entities = [];
    routes.forEach(r => {
      for (let i = 0; i < r.count; i++) {
        const lat = r.baseLat + (Math.random() - 0.5) * 0.12;
        const lng = r.baseLng + (Math.random() - 0.5) * 0.12;
        entities.push({
          id: `${r.id}_veh_${i}_${now}`,
          vehicle: {
            trip: {
              tripId: `${r.id}_trip_${i}`,
              routeId: r.id,
              startTime: new Date().toISOString().substr(11, 8),
              scheduleRelationship: 'SCHEDULED'
            },
            vehicle: {
              id: `${r.id}_bus_${i}`,
              label: `${r.short} ${i + 1}`,
              licensePlate: `DK-${Math.floor(1000 + Math.random() * 9000)}-A`
            },
            position: {
              latitude: lat,
              longitude: lng,
              bearing: Math.floor(Math.random() * 360),
              odometer: Math.random() * 100000,
              speed: parseFloat((5 + Math.random() * 35).toFixed(1)),
              // speed in m/s for GTFS-RT spec
              // we store km/h in custom field too
            },
            currentStopSequence: Math.floor(Math.random() * 20),
            stopId: `stop_${Math.floor(Math.random() * 100)}`,
            currentStatus: ['INCOMING_AT', 'STOPPED_AT', 'IN_TRANSIT_TO'][Math.floor(Math.random() * 3)],
            timestamp: now,
            congestionLevel: ['UNKNOWN_CONGESTION_LEVEL', 'RUNNING_SMOOTHLY', 'STOP_AND_GO', 'CONGESTION', 'SEVERE_CONGESTION'][Math.floor(Math.random() * 5)],
            occupancyStatus: ['EMPTY', 'MANY_SEATS_AVAILABLE', 'FEW_SEATS_AVAILABLE', 'STANDING_ROOM_ONLY', 'CRUSHED_STANDING_ROOM_ONLY'][Math.floor(Math.random() * 5)],
            occupancyPercentage: Math.floor(Math.random() * 100)
          }
        });
      }
    });

    return {
      header: {
        gtfsRealtimeVersion: '2.0',
        incrementality: 'FULL_DATASET',
        timestamp: now,
        feedVersion: `dakar-mock-${new Date().toISOString().split('T')[0]}`
      },
      entity: entities,
      _meta: {
        source: 'mock-dakar-cetud',
        count: entities.length,
        generatedAt: new Date().toISOString(),
        note: 'Mock réaliste Dakar - Remplace CETUD_API_URL par vrai endpoint pour live'
      }
    };
  }

  if (type === 'tripUpdates') {
    const entities = [];
    for (let i = 0; i < 40; i++) {
      const route = routes[Math.floor(Math.random() * routes.length)];
      const delay = Math.floor((Math.random() - 0.3) * 600); // -180 to +420 sec
      entities.push({
        id: `tu_${route.id}_${i}_${now}`,
        tripUpdate: {
          trip: { tripId: `${route.id}_trip_${i}`, routeId: route.id },
          vehicle: { id: `${route.id}_bus_${i}` },
          stopTimeUpdate: Array.from({ length: 5 }, (_, j) => ({
            stopSequence: j + 1,
            stopId: `stop_${route.id}_${j}`,
            arrival: { delay, time: now + j * 180 + delay, uncertainty: Math.floor(Math.random() * 60) },
            departure: { delay, time: now + j * 180 + 30 + delay },
            scheduleRelationship: 'SCHEDULED'
          })),
          timestamp: now,
          delay
        }
      });
    }
    return {
      header: { gtfsRealtimeVersion: '2.0', incrementality: 'FULL_DATASET', timestamp: now },
      entity: entities,
      _meta: { source: 'mock-dakar-tripupdates', count: entities.length }
    };
  }

  if (type === 'alerts') {
    const alerts = [
      { cause: 'TECHNICAL_PROBLEM', effect: 'SIGNIFICANT_DELAYS', title: 'Panne DDD à Colobane', desc: 'Bus DDD 07 en panne, retard 12 min, bus remplacement en route' },
      { cause: 'TRAFFIC', effect: 'DETOUR', title: 'Ralentissement VDN', desc: 'VDN Liberté 6 dévié via Ouakam, +8 min' },
      { cause: 'CONSTRUCTION', effect: 'STOP_MOVED', title: 'Travaux Grand Yoff BRT', desc: 'Arrêt Grand Yoff déplacé 80m pendant travaux' },
      { cause: 'OTHER_CAUSE', effect: 'OTHER_EFFECT', title: 'BRT fluide', desc: 'BRT Guédiawaye-Petersen 18 min au lieu de 25' },
    ];
    const entities = alerts.map((a, i) => ({
      id: `alert_${i}_${now}`,
      alert: {
        activePeriod: [{ start: now - 600, end: now + 3600 }],
        informedEntity: [{ routeId: routes[i % routes.length].id }],
        cause: a.cause,
        effect: a.effect,
        url: { translation: [{ text: 'https://cetud.sn', language: 'fr' }] },
        headerText: { translation: [{ text: a.title, language: 'fr' }] },
        descriptionText: { translation: [{ text: a.desc, language: 'fr' }] },
        severityLevel: ['INFO', 'WARNING', 'SEVERE'][Math.floor(Math.random() * 3)]
      }
    }));
    return {
      header: { gtfsRealtimeVersion: '2.0', timestamp: now },
      entity: entities,
      _meta: { source: 'mock-dakar-alerts', count: entities.length }
    };
  }
}

// ---------- POLITIQUE DES DONNÉES SIMULÉES ----------
// AVANT (jusqu'au 2026-09-24) : `useMock = USE_MOCK === 'true' || !CETUD_API_KEY`
//   → l'absence de clé API suffisait à servir des positions, des retards
//     (Math.random ±600 s) et des alertes inventées, en production comprise.
// APRÈS : la simulation est refusée par défaut, refusée en production, et
//   n'est servie que si ALLOW_SIMULATED_DATA=true est explicitement posée hors
//   production. Le refus est un corps explicite (status UNKNOWN, 0 entité),
//   jamais un flux crédible.
function simulatedDataVerdict() {
  return gtfsRtPolicy.mayServeSimulatedData(process.env);
}

function simulatedOrRefusal(type, endpoint) {
  const verdict = simulatedDataVerdict();
  if (verdict.serve) {
    const payload = gtfsRtPolicy.tagSimulated(generateMockDakarGTFS(type));
    payload._meta.policyReason = verdict.reason;
    return payload;
  }
  return gtfsRtPolicy.refusalPayload(endpoint, verdict);
}

// ---------- FETCH REAL GTFS-RT WITH PROTOBUF SUPPORT ----------
async function fetchRealGTFSRT(url, apiKey = '', keyHeader = 'X-API-Key') {
  if (!url) return null;
  try {
    const headers = {
      'User-Agent': 'DakarMobilite/2.0 (CETUD GTFS-RT Client)',
      'Accept': 'application/x-protobuf, application/octet-stream, application/json',
      'Accept-Encoding': 'gzip, deflate, br'
    };
    if (apiKey) {
      if (keyHeader.toLowerCase() === 'authorization' && !apiKey.toLowerCase().startsWith('bearer')) {
        headers['Authorization'] = `Bearer ${apiKey}`;
      } else {
        headers[keyHeader] = apiKey;
      }
    }

    console.log(`[GTFS] Fetching ${url} with key ${apiKey ? 'YES' : 'NO'}`);
    const resp = await fetch(url, { headers, signal: AbortSignal.timeout(8000) });
    
    if (!resp.ok) {
      console.warn(`[GTFS] ${url} -> HTTP ${resp.status}`);
      return null;
    }

    const contentType = resp.headers.get('content-type') || '';
    const buffer = await resp.arrayBuffer();

    // If JSON, parse directly
    if (contentType.includes('application/json') || url.includes('format=JSON')) {
      const text = new TextDecoder().decode(buffer);
      return JSON.parse(text);
    }

    // If protobuf, decode
    if (GtfsRealtimeBindings) {
      try {
        const feed = GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(new Uint8Array(buffer));
        // Convert to plain object for JSON response
        const obj = GtfsRealtimeBindings.transit_realtime.FeedMessage.toObject(feed, {
          longs: Number,
          enums: String,
          bytes: String,
          defaults: true
        });
        console.log(`[GTFS] Protobuf decoded: ${obj.entity?.length} entities`);
        return obj;
      } catch (e) {
        console.warn('[GTFS] Protobuf decode failed, trying JSON', e.message);
        // Try as text
        try {
          const text = new TextDecoder().decode(buffer);
          return JSON.parse(text);
        } catch {}
        return null;
      }
    } else {
      // No bindings, try to return as base64 info
      console.warn('[GTFS] No protobuf bindings, returning raw info');
      return {
        _raw: true,
        size: buffer.byteLength,
        contentType,
        simulated: false,
        note: 'Install gtfs-realtime-bindings: npm install gtfs-realtime-bindings. Aucune donnée simulée n’est injectée ici.'
      };
    }
  } catch (e) {
    console.warn(`[GTFS] Fetch error ${url}:`, e.message);
    return null;
  }
}

// ---------- API ROUTES ----------

// Health
app.get('/api/health', (req, res) => {
  const verdict = simulatedDataVerdict();
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    mode: verdict.serve ? 'SIMULATED_DEV' : (process.env.CETUD_API_KEY ? 'CETUD_CONFIGURED' : 'NO_PUBLIC_FEED'),
    departureEnginePolicy: {
      simulatedDataServed: verdict.serve,
      reason: verdict.reason,
      note: verdict.note,
      noteStatuses: 'SCHEDULED | ESTIMATED | REAL_TIME | UNKNOWN — REAL_TIME exige une observation réelle',
    },
    cache: gtfsCache.getStats(),
    endpoints: {
      vehiclePositions: '/api/gtfs-rt/vehiclePositions',
      tripUpdates: '/api/gtfs-rt/tripUpdates',
      alerts: '/api/gtfs-rt/alerts',
      all: '/api/gtfs-rt',
      vehiclesSimple: '/api/vehicles',
      alertsSimple: '/api/alerts'
    },
    env: {
      hasCetudKey: !!process.env.CETUD_API_KEY,
      cetudUrl: process.env.CETUD_VEHICLE_POSITIONS_URL || 'not set',
      useMock: process.env.USE_MOCK
    }
  });
});

// GTFS-RT Vehicle Positions - Main endpoint used by frontend
app.get('/api/gtfs-rt/vehiclePositions', async (req, res) => {
  const cacheKey = 'vehiclePositions';
  const cached = gtfsCache.get(cacheKey);
  if (cached && !req.query.nocache) {
    return res.json({ ...cached, _cached: true, _cacheAge: Math.floor((Date.now() - cached._cachedAt) / 1000) });
  }

  let data = null;
  if (process.env.CETUD_VEHICLE_POSITIONS_URL) {
    data = await fetchRealGTFSRT(
      process.env.CETUD_VEHICLE_POSITIONS_URL,
      process.env.CETUD_API_KEY,
      process.env.CETUD_API_KEY_HEADER || 'X-API-Key'
    );
  }

  if (!data) {
    const endpoint = '/api/gtfs-rt/vehiclePositions';
    const verdict = simulatedDataVerdict();
    console.log(`[GTFS] ${verdict.serve ? 'Données SIMULÉES (dev explicite)' : 'Aucune donnée temps réel'} — ${verdict.reason}`);
    data = simulatedOrRefusal('vehiclePositions', endpoint);
  }

  data._cachedAt = Date.now();
  gtfsCache.set(cacheKey, data);
  res.json(data);
});

// Trip Updates
app.get('/api/gtfs-rt/tripUpdates', async (req, res) => {
  const cacheKey = 'tripUpdates';
  const cached = gtfsCache.get(cacheKey);
  if (cached && !req.query.nocache) return res.json({ ...cached, _cached: true });

  let data = null;
  if (process.env.CETUD_TRIP_UPDATES_URL) {
    data = await fetchRealGTFSRT(process.env.CETUD_TRIP_UPDATES_URL, process.env.CETUD_API_KEY, process.env.CETUD_API_KEY_HEADER);
  }
  if (!data) data = simulatedOrRefusal('tripUpdates', '/api/gtfs-rt/tripUpdates');
  data._cachedAt = Date.now();
  gtfsCache.set(cacheKey, data);
  res.json(data);
});

// Alerts
app.get('/api/gtfs-rt/alerts', async (req, res) => {
  const cacheKey = 'alerts';
  const cached = gtfsCache.get(cacheKey);
  if (cached && !req.query.nocache) return res.json({ ...cached, _cached: true });

  let data = null;
  if (process.env.CETUD_ALERTS_URL) {
    data = await fetchRealGTFSRT(process.env.CETUD_ALERTS_URL, process.env.CETUD_API_KEY, process.env.CETUD_API_KEY_HEADER);
  }
  if (!data) data = simulatedOrRefusal('alerts', '/api/gtfs-rt/alerts');
  data._cachedAt = Date.now();
  gtfsCache.set(cacheKey, data);
  res.json(data);
});

// Combined GTFS-RT (all)
app.get('/api/gtfs-rt', async (req, res) => {
  const verdict = simulatedDataVerdict();
  const [vehicles, trips, alerts] = await Promise.all([
    fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/vehiclePositions?nocache=${req.query.nocache ? '1' : '0'}`).then(r => r.json()).catch(() => simulatedOrRefusal('vehiclePositions', '/api/gtfs-rt')),
    fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/tripUpdates?nocache=${req.query.nocache ? '1' : '0'}`).then(r => r.json()).catch(() => simulatedOrRefusal('tripUpdates', '/api/gtfs-rt')),
    fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/alerts?nocache=${req.query.nocache ? '1' : '0'}`).then(r => r.json()).catch(() => simulatedOrRefusal('alerts', '/api/gtfs-rt'))
  ]);

  res.json({
    header: { timestamp: Math.floor(Date.now() / 1000), version: '2.0' },
    vehiclePositions: vehicles,
    tripUpdates: trips,
    alerts: alerts,
    _meta: {
      generatedAt: new Date().toISOString(),
      mode: verdict.serve ? 'SIMULATED_DEV' : 'NO_PUBLIC_FEED',
      status: verdict.serve ? 'SIMULATED' : 'UNKNOWN',
      simulated: verdict.serve,
      reason: verdict.reason,
      note: 'Aucun flux temps réel public (TER/BRT/DDD/AFTU/TATA) n’est disponible ; aucune donnée simulée n’est servie comme du temps réel.',
      sources: []
    }
  });
});

// GTFS Static Dakar - serve files
app.get('/api/gtfs/static', (req, res) => {
  const gtfsDir = path.join(ROOT_DIR, 'data', 'gtfs');
  try {
    const files = fs.readdirSync(gtfsDir).filter(f => f.endsWith('.txt'));
    const feed = {};
    files.forEach(file => {
      const content = fs.readFileSync(path.join(gtfsDir, file), 'utf-8');
      const lines = content.trim().split('\n');
      if (lines.length < 2) return;
      const headers = lines[0].split(',');
      feed[file.replace('.txt','')] = lines.slice(1).map(line => {
        // Simple CSV parse (handles quoted commas not fully, but ok for our data)
        const values = line.split(',');
        const obj = {};
        headers.forEach((h, i) => obj[h.trim()] = values[i]?.trim() || '');
        return obj;
      });
    });
    res.json({
      ...feed,
      _meta: {
        source: 'CETUD Dakar GTFS Static - Generated for Dakar Mobilité PWA',
        generatedAt: new Date().toISOString(),
        stops: feed.stops?.length || 0,
        routes: feed.routes?.length || 0,
        trips: feed.trips?.length || 0,
        downloadUrl: '/api/gtfs/static.zip'
      }
    });
  } catch (e) {
    res.status(500).json({ error: e.message, note: 'GTFS static not found, generating mock' });
  }
});

app.get('/api/gtfs/static.zip', (req, res) => {
  const gtfsDir = path.join(ROOT_DIR, 'data', 'gtfs');
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', 'attachment; filename=dakar-gtfs-static.zip');
  // For simplicity, we don't create real zip, we return JSON listing files
  // In production, use archiver to zip
  res.json({ message: 'Use /api/gtfs/static for JSON, or download individual files from /data/gtfs/', files: fs.readdirSync(gtfsDir) });
});

// Serve individual GTFS files
app.get('/data/gtfs/:file', (req, res) => {
  const filePath = path.join(ROOT_DIR, 'data', 'gtfs', req.params.file);
  if (fs.existsSync(filePath)) {
    res.sendFile(filePath);
  } else {
    res.status(404).json({ error: 'GTFS file not found' });
  }
});

// Simple vehicles for frontend (compatible with old frontend)
app.get('/api/vehicles', async (req, res) => {
  const gtfs = await fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/vehiclePositions`).then(r => r.json()).catch(() => simulatedOrRefusal('vehiclePositions', '/api/vehicles'));
  const simple = (gtfs.entity || []).map(e => {
    const v = e.vehicle || {};
    const pos = v.position || {};
    return {
      id: e.id,
      routeId: v.trip?.routeId,
      tripId: v.trip?.tripId,
      label: v.vehicle?.label || v.vehicle?.id,
      lat: pos.latitude,
      lng: pos.longitude,
      bearing: pos.bearing,
      speed: pos.speed,
      speedKmh: pos.speed ? (pos.speed * 3.6).toFixed(1) : null,
      occupancy: v.occupancyStatus,
      occupancyPct: v.occupancyPercentage,
      congestion: v.congestionLevel,
      timestamp: v.timestamp
    };
  });
  res.json({ vehicles: simple, count: simple.length, timestamp: Date.now(), source: gtfs._meta?.source || 'unknown' });
});

app.get('/api/alerts', async (req, res) => {
  const gtfs = await fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/alerts`).then(r => r.json()).catch(() => simulatedOrRefusal('alerts', '/api/alerts'));
  const simple = (gtfs.entity || []).map(e => {
    const a = e.alert || {};
    return {
      id: e.id,
      cause: a.cause,
      effect: a.effect,
      title: a.headerText?.translation?.[0]?.text || 'Alerte',
      description: a.descriptionText?.translation?.[0]?.text || '',
      severity: a.severityLevel || 'INFO',
      routes: a.informedEntity?.map(en => en.routeId) || [],
      active: a.activePeriod?.[0]
    };
  });
  res.json({ alerts: simple, count: simple.length, timestamp: Date.now() });
});

// SSE for live push (alternative to polling)
app.get('/api/stream/vehicles', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');

  const send = async () => {
    try {
      const data = await fetch(`${req.protocol}://${req.get('host')}/api/gtfs-rt/vehiclePositions?nocache=1`).then(r => r.json()).catch(() => simulatedOrRefusal('vehiclePositions', '/api/stream/vehicles'));
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    } catch (e) {
      res.write(`data: ${JSON.stringify({ error: e.message })}\n\n`);
    }
  };

  send();
  const interval = setInterval(send, parseInt(process.env.POLL_INTERVAL_MS || '3000'));

  req.on('close', () => {
    clearInterval(interval);
    res.end();
  });
});

// Serve static frontend (PWA)
app.use(express.static(ROOT_DIR, {
  maxAge: '1d',
  setHeaders: (res, path) => {
    if (path.endsWith('service-worker.js')) {
      res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
    }
    if (path.endsWith('manifest.json')) {
      res.setHeader('Content-Type', 'application/manifest+json');
    }
  }
}));

// Fallback to index.html for SPA routing (fix refresh bug)
app.get('*', (req, res) => {
  // Don't fallback for api
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ error: 'API not found', path: req.path });
  }
  res.sendFile(path.join(ROOT_DIR, 'index.html'));
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: err.message, stack: process.env.NODE_ENV === 'development' ? err.stack : undefined });
});

// Export for Vercel serverless
export default app;

// Only listen if not in Vercel (Vercel sets VERCEL env)
if (!process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    const verdict = simulatedDataVerdict();
    console.log(`\n🚀 Dakar Mobilité GTFS-RT Proxy running on http://0.0.0.0:${PORT}`);
    console.log(`📦 Mode: ${verdict.serve ? 'DONNÉES SIMULÉES (dev explicite — jamais du temps réel)' : 'AUCUN FLUX TEMPS RÉEL PUBLIC'}`);
    console.log(`🛡️ Politique: ${verdict.reason} — ${verdict.note}`);
    console.log(`🔑 CETUD Key: ${process.env.CETUD_API_KEY ? 'SET (' + process.env.CETUD_API_KEY.substring(0, 8) + '...)' : 'NOT SET'}`);
    console.log(`📡 Endpoints:`);
    console.log(`   - http://localhost:${PORT}/api/gtfs-rt/vehiclePositions`);
    console.log(`   - http://localhost:${PORT}/api/gtfs-rt/tripUpdates`);
    console.log(`   - http://localhost:${PORT}/api/gtfs-rt/alerts`);
    console.log(`   - http://localhost:${PORT}/api/vehicles (simple)`);
    console.log(`   - http://localhost:${PORT}/api/stream/vehicles (SSE)`);
    console.log(`   - http://localhost:${PORT}/api/health`);
    console.log(`   - http://localhost:${PORT}/api/gtfs/static (GTFS static Dakar)`);
    console.log(`🌍 Frontend: http://localhost:${PORT}/#explorer\n`);
  });
}
