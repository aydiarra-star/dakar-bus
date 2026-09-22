/**
 * Dakar Bus - Groupe 12
 * Audit des sources de données réellement disponibles
 * Principe : Pas de donnée inventée. Si provenance non établie, source = UNKNOWN et non utilisée.
 */

export const SourceTrust = Object.freeze({
  OFFICIAL: 'OFFICIAL',   // Source autorité organisatrice avec preuve
  VERIFIED: 'VERIFIED',   // Source officielle vérifiée terrain / croisée
  UNKNOWN: 'UNKNOWN',     // Provenance non établie, non utilisable comme source officielle
});

export const sources = [
  {
    name: 'data/gtfs/stop_times.txt',
    network: 'TER, BRT',
    type: 'GTFS static local',
    provenance: 'Fichier local dans repo, documenté comme "Données GTFS complétées" dans CORRECTIF_ARRETS_TER_BRT.md mais sans URL officielle CETUD, sans signature, sans clé',
    url: 'local: data/gtfs/stop_times.txt',
    authentication: 'aucune',
    data: 'trip_id, arrival_time, departure_time, stop_id, stop_sequence - 108 lignes, intervalles réguliers 2min BRT / 4min TER, trips à 06:00, 07:00, 12:00 seulement',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Provenance non prouvable officiellement, pattern demo (intervalles réguliers), pas de feed officiel CETUD signé, seulement 3 trips, pas de calendar_dates/frequencies, ne peut pas être considéré comme horaires réels officiels sans preuve'
  },
  {
    name: 'data/gtfs/stops.txt',
    network: 'TER, BRT, BUS',
    type: 'GTFS static local - arrêts',
    provenance: 'Fichier local, 42 arrêts (13 TER + 23 BRT + 6 pôles), coordonnées vérifiées via reference-policy.json mais pas de source temps réel',
    url: 'local: data/gtfs/stops.txt',
    authentication: 'aucune',
    data: 'stop_id, stop_name, stop_lat, stop_lon - 42 arrêts',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: true,
    reasonRejected: null,
    note: 'Utilisé pour affichage carte et comptage arrêts, mais pas comme source horaire temps réel'
  },
  {
    name: 'data/gtfs/routes.txt',
    network: 'TER, BRT, DDD, AFTU, TATA',
    type: 'GTFS static local - lignes',
    provenance: 'Fichier local, 76 lignes listées (BRT, DDD, TATA, TER, AFTU)',
    url: 'local: data/gtfs/routes.txt',
    authentication: 'aucune',
    data: 'route_id, agency_id, route_short_name, route_long_name, route_type, etc.',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: true,
    note: 'Utilisé pour liste lignes, pas comme source horaire'
  },
  {
    name: 'CETUD GTFS-RT VehiclePositions',
    network: 'TER, BRT, DDD, AFTU',
    type: 'GTFS-RT API temps réel',
    provenance: 'URL mentionnée dans server/.env et BRANCHEMENT_CETUD.md, mais sans clé API, sans preuve d\'accès, mode MOCK activé',
    url: 'https://api.cetud.sn/gtfs-rt/vehiclePositions',
    authentication: 'CETUD_API_KEY manquante, USE_MOCK=true',
    data: 'Aucune donnée réelle récupérée, mock de 127 véhicules généré via generateMockDakarGTFS()',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Pas de clé API, pas de preuve que endpoint existe et est accessible, pas de données réelles, mode mock uniquement. Ne peut pas être considéré comme source temps réel vérifiable sans clé et sans test réussi.'
  },
  {
    name: 'CETUD GTFS-RT TripUpdates',
    network: 'TER, BRT',
    type: 'GTFS-RT API horaires temps réel',
    provenance: 'Mentionné dans .env',
    url: 'https://api.cetud.sn/gtfs-rt/tripUpdates',
    authentication: 'CETUD_API_KEY manquante',
    data: 'Aucune',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Même raison que VehiclePositions, pas de clé, pas de données'
  },
  {
    name: 'CETUD GTFS-RT Alerts',
    network: 'TER, BRT',
    type: 'GTFS-RT API alertes',
    provenance: 'Mentionné dans .env',
    url: 'https://api.cetud.sn/gtfs-rt/alerts',
    authentication: 'CETUD_API_KEY manquante',
    data: 'Aucune',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Pas de clé, pas de données'
  },
  {
    name: 'DDD API',
    network: 'DDD',
    type: 'API temps réel supposée',
    provenance: 'Mentionné dans server/.env comme DDD_API_URL=https://api.dakardemdikk.sn/gtfs-rt mais jamais utilisé dans server.js, pas de doc officielle',
    url: 'https://api.dakardemdikk.sn/gtfs-rt',
    authentication: 'aucune preuve',
    data: 'Aucune',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'URL non vérifiée, pas utilisée dans code, pas de clé, pas de preuve d\'existence'
  },
  {
    name: 'BRT API',
    network: 'BRT',
    type: 'API temps réel supposée',
    provenance: 'BRT_API_URL dans .env',
    url: 'https://api.sunubrt.sn/gtfs-rt',
    authentication: 'aucune preuve',
    data: 'Aucune',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Même raison que DDD'
  },
  {
    name: 'TER API',
    network: 'TER',
    type: 'API temps réel supposée',
    provenance: 'TER_API_URL dans .env',
    url: 'https://api.ter.sn/gtfs-rt',
    authentication: 'aucune preuve',
    data: 'Aucune',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Même raison'
  },
  {
    name: 'api/gtfs-rt placeholder',
    network: 'ALL',
    type: 'Fichier JSON statique placeholder',
    provenance: 'Fichier api/gtfs-rt contenant {"entity":[],"source":"static-mock-file","note":"placeholder"}',
    url: 'local: api/gtfs-rt',
    authentication: 'aucune',
    data: 'Vide',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: false,
    reasonRejected: 'Placeholder mock, pas de données réelles'
  },
  {
    name: 'GTFSRTClient mock dans index.html',
    network: 'ALL',
    type: 'Simulation JS',
    provenance: 'Classe GTFSRTClient dans index.html avec generateMockGTFS() qui simule 30 véhicules le long de polylines',
    url: 'inline: index.html',
    authentication: 'aucune',
    data: 'Simulation interpolation linéaire, setInterval 3s',
    reliability: SourceTrust.UNKNOWN,
    officialSource: false,
    usedByDakarBus: true,
    note: 'Utilisé pour animation véhicules sur carte, mais pas comme source horaire officielle. Ne doit pas être confondu avec temps réel réel.'
  }
];

export function getOfficialSources() {
  return sources.filter(s => s.officialSource === true && s.reliability === SourceTrust.OFFICIAL);
}

export function getVerifiedSources() {
  return sources.filter(s => s.reliability === SourceTrust.VERIFIED);
}

export function getUnknownSources() {
  return sources.filter(s => s.reliability === SourceTrust.UNKNOWN);
}

export function isStopTimesOfficial() {
  const st = sources.find(s => s.name === 'data/gtfs/stop_times.txt');
  return st ? st.officialSource : false;
}

export default {
  SourceTrust,
  sources,
  getOfficialSources,
  getVerifiedSources,
  getUnknownSources,
  isStopTimesOfficial
};
