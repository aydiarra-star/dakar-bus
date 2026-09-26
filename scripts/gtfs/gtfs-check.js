#!/usr/bin/env node
'use strict';
/**
 * npm run gtfs:check — contrôle global du moteur GTFS externe :
 *  1. couche PassBi (HISTORICAL) : ZIP bruts, SHA-256, validation ;
 *  2. couche CETUD : statut (ABSENT tant qu'aucun feed officiel n'est installé) ;
 *  3. provider commun : quelle source gagne pour AFTU / DDD à la date du jour ;
 *  4. assistant : question témoin (fallback exact attendu si aucune source actuelle).
 */
const { spawnSync } = require('child_process');
const path = require('path');
const { buildProvider } = require('../../lib/external-gtfs/feed-layers');
const { answerScheduleQuestion } = require('../../lib/external-gtfs/schedule-assistant');

function run(script, label) {
  const r = spawnSync(process.execPath, [path.join(__dirname, script)], { encoding: 'utf8' });
  let parsed = null;
  try { parsed = JSON.parse(r.stdout); } catch (e) { /* sortie non JSON */ }
  console.log(`[${label}] exit=${r.status} ${parsed ? `layer_status=${parsed.layer_status}` : r.stdout.slice(0, 200)}`);
  if (r.stderr.trim()) console.log(`  ${r.stderr.trim().split('\n').join('\n  ')}`);
  return { status: r.status, report: parsed };
}

function main() {
  const passbi = run('check-passbi-layer.js', 'passbi');
  const cetud = run('check-cetud-layer.js', 'cetud');
  const { provider, registered, skipped, asOf } = buildProvider({});
  console.log(`[provider] as_of=${asOf} sources=${registered.length} ignorées=${skipped.length}`);
  for (const r of registered) console.log(`  ${r.layer} ${r.id} → ${r.role} (${r.validityStatus})`);
  for (const s of skipped) console.log(`  IGNORÉE ${s.layer} ${s.id} : ${s.reason}`);
  for (const network of ['AFTU', 'DDD']) {
    const win = provider.winningSource(network, asOf);
    console.log(`  ${network} : source actuelle = ${win ? `${win.provenance.source} (${win.role}, ${win.level})` : 'AUCUNE → UNKNOWN'}`);
  }
  const answer = answerScheduleQuestion(provider, 'Prochain bus AFTU 30 à l\'arrêt Colobane ?');
  console.log(`[assistant] ${answer.status} ${answer.reason || ''}\n  « ${answer.sentence} »`);
  const ok = passbi.status === 0 && cetud.status === 0;
  console.log(ok ? 'gtfs:check OK' : 'gtfs:check ÉCHEC');
  process.exit(ok ? 0 : 1);
}

if (require.main === module) main();
