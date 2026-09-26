'use strict';
// Synthetic provider contract tests only; no production source is installed.
const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../lib/external-gtfs');
const { AFTU_TEXTS } = require('./helpers/cetud-synthetic-fixture');
const question = 'Prochain bus AFTU 30 à Yeumbeul TEST ?';
const provenance = { source: 'TEST', sourceType: 'SOURCE_INSTITUTIONAL', declaredStatus: 'CURRENT', validFrom: '2026-01-01', validTo: '2026-12-31', network: 'AFTU' };
function provider(historical = false) {
  const p = new L.TransitDataProvider({ now: () => new Date('2026-09-26T07:30:00Z') });
  const prov = new L.FeedProvenance(historical ? { ...provenance, source: 'PassBi TEST', sourceType: 'SOURCE_APPLICATION', declaredStatus: 'HISTORICAL' } : provenance);
  const tables = Object.fromEntries(Object.entries(AFTU_TEXTS).map(([k,v]) => [k.replace('.txt',''), v]));
  const { feed } = L.loadFeedFromTexts(tables, prov, { network: 'AFTU' });
  p.registerSource(new L.GtfsScheduleService(feed), { role: historical ? 'historicalReference' : 'currentOfficial' });
  return p;
}
function frequency(p) {
  p.registerSource(new L.FrequencySource([{ network: 'AFTU', lineNumber: '30', routeIds: ['TEST_AFTU_R30'], headwayMinutes: 12, from: '06:00', to: '21:00' }], { ...provenance, source: 'TEST frequency' }), { role: 'currentFrequency' });
}
test('assistant preserves SCHEDULED and GTFS-known frequency fallback ESTIMATED', () => {
  const p = provider(); frequency(p);
  const scheduled = L.answerScheduleQuestion(p, question);
  assert.equal(scheduled.status, 'SCHEDULED');
  assert.match(scheduled.sentence, /départ programmé est à 07:42/);
  const answer = L.answerScheduleQuestion(p, question, { time: '12:00' });
  assert.equal(answer.status, 'ESTIMATED');
  assert.equal(answer.estimate.headwayMinutes, 12);
  assert.equal(answer.provenanceLevel, 'ESTIMATED');
  assert.equal(answer.source, 'TEST frequency');
  assert.equal(answer.departure, undefined);
  assert.match(answer.sentence, /environ toutes les 12 minutes/);
  assert.doesNotMatch(answer.sentence, /départ programmé|temps réel/);
  assert.equal(L.answerScheduleQuestion(p, question, { time: '22:00' }).status, 'UNKNOWN');
  assert.equal(L.answerScheduleQuestion(p, 'Prochain bus AFTU 30 à Inconnu TEST ?', {time:'12:00'}).status, 'UNKNOWN');
});
test('assistant relays REAL_TIME only from a current provider result (synthetic boundary)', () => {
  for (const isCurrent of [true, false]) {
    const p = provider(); const get = p.getDepartures.bind(p);
    p.getDepartures = (...args) => ({ ...get(...args), status: 'REAL_TIME', isCurrent });
    const answer = L.answerScheduleQuestion(p, question);
    assert.equal(answer.status, isCurrent ? 'REAL_TIME' : 'UNKNOWN');
    if (isCurrent) {
      assert.match(answer.sentence, /annoncé en temps réel est à 07:42/);
      assert.doesNotMatch(answer.sentence, /programmé/);
    }
  }
});
test('assistant keeps UNKNOWN and historical PassBi never becomes current', () => {
  const empty = new L.TransitDataProvider();
  assert.equal(L.answerScheduleQuestion(empty, question).status, 'UNKNOWN');
  const p = provider(true);
  const a = L.answerScheduleQuestion(p, question);
  assert.equal(a.status, 'UNKNOWN');
  assert.equal(a.lineKnownHistorically, true);
  assert.equal(p.getDepartures('TEST_AFTU_R30', 'TEST_S_Y').isCurrent, false);
});
