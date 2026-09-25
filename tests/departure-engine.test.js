'use strict';
/**
 * DAKAR BUS — MOTEUR COMMUN DE DÉPARTS : tests des règles non négociables.
 * ==========================================================================
 * T1  Horaire précis → SCHEDULED          T10 Périodes différentes
 * T2  Fréquence fiable → ESTIMATED        T11 Début de service respecté
 * T3  GPS véhicule réel → REAL_TIME       T12 Fin de service respectée
 * T4  Aucune donnée → UNKNOWN             T13 Changement de fréquence
 * T5  Fréquence historique → pas actuelle T14 Assistant = même statut
 * T6  OSM/COMMUNITY jamais OFFICIAL       T15 KMF reste UNKNOWN
 * T7  GPS utilisateur ≠ GPS véhicule      T16 Mbao distinct de KMF
 * T8  Aucune heure précise inventée       T17 Yeumbeul A/B non résolu
 * T9  Fréquences différentes par ligne    T18 AIBD hors TER
 * + itinéraires (incertitude conservée), politique des données simulées,
 * + non-régression de l'interface publiée et du référentiel audité.
 *
 * Aucun test ne dépend de l'heure réelle : tous les instants sont explicites.
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ENG = require('../engine/departure-engine.js');
const POLICY = require('../engine/gtfs-rt-policy.js');

const ROOT = path.join(__dirname, '..');
const REGISTRY = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/transit/departure-frequencies.json'), 'utf8'));
const NETWORK = JSON.parse(fs.readFileSync(path.join(ROOT, 'flutter-src/assets/data/dakar_network.json'), 'utf8'));

const at = (date, clock) => ({ date, minutes: ENG.clockToMinutes(clock) });
const LUNDI = '2026-09-28';       // lundi
const SAMEDI = '2026-10-03';      // samedi
const DIMANCHE = '2026-10-04';    // dimanche
const FERIE = '2026-10-05';       // lundi déclaré férié par le test
const HOLIDAYS = [FERIE];
const TER = { network: 'TER', lineId: 'ter_dakar_diamniadio', stopId: 'stop_dakar_ter' };
const BRT_B1 = { network: 'BRT', lineId: 'brt_b1_guediawaye_petersen', stopId: 'stop_brt_01_petersen' };
const BRT_B2 = { network: 'BRT', lineId: 'brt_b2_express', stopId: 'stop_brt_23_guediawaye' };
const DDD = { network: 'DDD', lineId: 'ddd_1', stopId: null };

const est = (query, now, extra) =>
  ENG.estimateNextDeparture(Object.assign({ registry: REGISTRY, holidays: HOLIDAYS, now }, query, extra || {}));

const clockOf = (iso) => (iso == null ? null : iso.slice(11, 16));

// ---------------------------------------------------------------------------
// T1 — horaire précis fiable
// ---------------------------------------------------------------------------
test('T1 — horaire précis correctement sourcé : SCHEDULED, jamais converti en estimation', () => {
  const now = at(LUNDI, '11:30');
  const e = est(TER, now, {
    scheduledDepartures: [{
      time: '11:40', lineId: 'ter_dakar_diamniadio', stopId: 'stop_dakar_ter',
      source: 'SETER — horaire publié', sourceType: 'OFFICIAL', validFrom: '2026-09-01', validTo: null,
    }],
  });
  assert.equal(e.status, ENG.STATUS.SCHEDULED);
  assert.equal(clockOf(e.scheduledTime), '11:40');
  assert.equal(e.estimatedFrom, null);
  assert.equal(e.estimatedTo, null);
  assert.equal(e.frequencyMinutes, null, 'un horaire précis ne doit pas porter de fréquence');
  assert.deepEqual(ENG.validateEstimate(e), []);
  const d = ENG.displayFor(e, { now });
  assert.equal(d.badge, 'Horaire théorique');
  assert.match(d.headline, /11h40/);
});

test('T1b — un horaire sans source utilisable ne devient pas SCHEDULED', () => {
  const now = at(LUNDI, '11:30');
  for (const sourceType of [null, 'UNKNOWN', 'COMMUNITY', 'HISTORICAL']) {
    const e = est(TER, now, { scheduledDepartures: [{ time: '11:40', sourceType, source: 'x' }] });
    assert.notEqual(e.status, ENG.STATUS.SCHEDULED, `sourceType=${sourceType}`);
  }
});

test('T1c — un horaire déjà passé n’est pas proposé', () => {
  const now = at(LUNDI, '11:45');
  const e = est(TER, now, {
    scheduledDepartures: [{ time: '11:40', sourceType: 'OFFICIAL', source: 'SETER' }],
  });
  assert.notEqual(e.status, ENG.STATUS.SCHEDULED);
});

// ---------------------------------------------------------------------------
// T2 — fréquence fiable
// ---------------------------------------------------------------------------
test('T2 — fréquence TER documentée : ESTIMATED, fenêtre 0–10 min', () => {
  const now = at(LUNDI, '11:43');
  const e = est(TER, now);
  assert.equal(e.status, ENG.STATUS.ESTIMATED);
  assert.equal(e.frequencyMinutes, 10);
  assert.equal(e.estimatedFrom, `${LUNDI}T11:43:00+00:00`);
  assert.equal(e.estimatedTo, `${LUNDI}T11:53:00+00:00`);
  assert.equal(e.scheduledTime, null, 'une estimation ne porte jamais d’heure de départ');
  assert.equal(e.observedAt, null);
  assert.equal(e.sourceType, 'OFFICIAL');
  assert.match(e.source, /SETER/);
  assert.equal(e.validTo, null);
  assert.deepEqual(ENG.validateEstimate(e), []);
});

test('T2b — la fenêtre reste une fenêtre : jamais un point unique, jamais « Départ 11h47 »', () => {
  const now = at(LUNDI, '11:43');
  const e = est(TER, now);
  const d = ENG.displayFor(e, { now });
  assert.equal(d.badge, 'Estimation');
  assert.equal(d.isRealTime, false);
  assert.equal(d.isOfficial, false, 'une estimation n’est pas « officielle »');
  assert.match(d.headline, /fenêtre|0–10 min/);
  assert.match(d.trafficNote, /circulation/);
  const text = `${d.headline} ${d.body}`;
  assert.ok(!/D[ée]part\s+\d{1,2}h\d{2}/.test(text), `heure précise interdite : ${text}`);
  assert.notEqual(e.estimatedFrom, e.estimatedTo);
});

// ---------------------------------------------------------------------------
// T3 — données véhicule réelles
// ---------------------------------------------------------------------------
test('T3 — observation véhicule réelle : REAL_TIME (source, horodatage, ligne, véhicule, ETA)', () => {
  const now = at(LUNDI, '14:38');
  const e = est(BRT_B1, now, {
    preferObservedRealtime: true,
    observations: [{
      kind: 'VEHICLE_OBSERVATION', source: 'SunuBRT — flux opérateur', sourceType: 'OPERATOR_REALTIME',
      observedAt: `${LUNDI}T14:38:00+00:00`, lineId: 'brt_b1_guediawaye_petersen', vehicleId: 'BRT-123',
      eta: `${LUNDI}T14:42:00+00:00`,
    }],
  });
  assert.equal(e.status, ENG.STATUS.REAL_TIME);
  assert.equal(e.vehicleId, 'BRT-123');
  assert.equal(e.observedAt, `${LUNDI}T14:38:00+00:00`);
  assert.equal(clockOf(e.estimatedFrom), '14:42');
  assert.equal(e.scheduledTime, null);
  assert.deepEqual(ENG.validateEstimate(e), []);
  const d = ENG.displayFor(e, { now });
  assert.equal(d.badge, 'Temps réel');
  assert.equal(d.isRealTime, true);
  assert.match(d.headline, /4 min/);
});

test('T3b — ordre strict de la spécification : SCHEDULED → ESTIMATED → REAL_TIME ; option d’inversion explicite', () => {
  const now = at(LUNDI, '11:43');
  const observation = {
    kind: 'VEHICLE_OBSERVATION', source: 'opérateur', sourceType: 'OPERATOR_REALTIME',
    observedAt: `${LUNDI}T11:43:00+00:00`, lineId: 'ter_dakar_diamniadio', vehicleId: 'TER-01',
    eta: `${LUNDI}T11:47:00+00:00`,
  };
  const strict = est(TER, now, { observations: [observation] });
  assert.equal(strict.status, ENG.STATUS.ESTIMATED, 'une fréquence documentée prime dans l’ordre strict');
  const observedFirst = est(TER, now, { observations: [observation], preferObservedRealtime: true });
  assert.equal(observedFirst.status, ENG.STATUS.REAL_TIME);
});

test('T3c — REAL_TIME refusé sans source / horodatage / ligne / véhicule / ETA ou position', () => {
  const now = at(LUNDI, '14:38');
  const base = {
    kind: 'VEHICLE_OBSERVATION', source: 'opérateur', sourceType: 'OPERATOR_REALTIME',
    observedAt: `${LUNDI}T14:38:00+00:00`, lineId: 'brt_b1_guediawaye_petersen',
    vehicleId: 'BRT-123', eta: `${LUNDI}T14:42:00+00:00`,
  };
  for (const missing of ['source', 'observedAt', 'vehicleId', 'eta']) {
    const broken = { ...base };
    delete broken[missing];
    const e = est(BRT_B1, now, { preferObservedRealtime: true, observations: [broken] });
    assert.notEqual(e.status, ENG.STATUS.REAL_TIME, `champ manquant : ${missing}`);
  }
  const noLine = { ...base };
  delete noLine.lineId;
  assert.notEqual(est(BRT_B1, now, { preferObservedRealtime: true, observations: [noLine] }).status, ENG.STATUS.REAL_TIME);
  const community = est(BRT_B1, now, {
    preferObservedRealtime: true,
    observations: [{ ...base, sourceType: 'COMMUNITY' }],
  });
  assert.notEqual(community.status, ENG.STATUS.REAL_TIME, 'une observation communautaire n’est pas du temps réel vérifié');
  const simulated = est(BRT_B1, now, {
    preferObservedRealtime: true,
    observations: [{ ...base, simulated: true }],
  });
  assert.notEqual(simulated.status, ENG.STATUS.REAL_TIME, 'une donnée simulée n’est jamais du temps réel');
  const stale = est(BRT_B1, now, {
    preferObservedRealtime: true,
    observations: [{ ...base, observedAt: `${LUNDI}T09:00:00+00:00` }],
  });
  assert.notEqual(stale.status, ENG.STATUS.REAL_TIME, 'une observation périmée n’est plus du temps réel');
});

// ---------------------------------------------------------------------------
// T4 — aucune donnée
// ---------------------------------------------------------------------------
test('T4 — aucune donnée fiable : UNKNOWN, tous les champs temporels à null', () => {
  const now = at(LUNDI, '11:43');
  const e = est(DDD, now);
  assert.equal(e.status, ENG.STATUS.UNKNOWN);
  for (const key of ['scheduledTime', 'estimatedFrom', 'estimatedTo', 'frequencyMinutes', 'observedAt']) {
    assert.equal(e[key], null, `${key} doit rester null`);
  }
  assert.equal(e.confidence, 'none');
  assert.deepEqual(ENG.validateEstimate(e), []);
  const d = ENG.displayFor(e, { now });
  assert.equal(d.headline, 'Prochain passage');
  assert.equal(d.body, 'Horaire indisponible');
  assert.equal(d.isEstimate, false);
  assert.equal(d.available, false);
});

test('T4b — aucune donnée : le moteur ne complète jamais un objet par des valeurs fictives', () => {
  const e = ENG.estimateNextDeparture({ now: at(LUNDI, '11:43') });
  assert.equal(e.lineId, null);
  assert.equal(e.source, null);
  assert.equal(e.sourceType, null);
  assert.equal(e.simulated, false);
  assert.equal(e.confidence, 'none');
});

// ---------------------------------------------------------------------------
// T5 — donnée historique
// ---------------------------------------------------------------------------
test('T5 — fréquence historique : jamais utilisée comme service actuel', () => {
  const now = at(LUNDI, '11:43');
  const registry = {
    sources: [{ id: 'passbi_2025', label: 'PassBI 08/2025', source_type: 'HISTORICAL', url: null, retrieved_at: '2026-09-25' }],
    frequencies: [{
      id: 'ddd_1_historique', network: 'DDD', line_id: 'ddd_1', day_types: ['MONDAY'],
      service_start: '06:00', service_end: '21:00', frequency_minutes: 10, status: 'HISTORICAL', source_id: 'passbi_2025',
    }],
  };
  const e = ENG.estimateNextDeparture({ now, network: 'DDD', lineId: 'ddd_1', registry });
  assert.equal(e.status, ENG.STATUS.UNKNOWN);
  assert.ok(e.warnings.some((w) => w.code === ENG.REASONS.FREQUENCY_NOT_CURRENT));
  assert.match(e.note, /historique/i);
});

test('T5b — fréquence dont la validité est expirée : aucun service actuel', () => {
  const now = at(LUNDI, '11:43');
  const registry = {
    sources: [{ id: 's', label: 'source', source_type: 'OFFICIAL', url: 'https://exemple.sn', retrieved_at: '2026-09-25' }],
    frequencies: [{
      id: 'f', network: 'TER', line_id: 'ter_dakar_diamniadio', day_types: ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'],
      service_start: '06:00', service_end: '21:00', frequency_minutes: 10,
      status: 'ACTIVE', source_id: 's', valid_from: '2024-01-01', valid_to: '2025-12-31',
    }],
  };
  const e = ENG.estimateNextDeparture({ now, network: 'TER', lineId: 'ter_dakar_diamniadio', registry });
  assert.equal(e.status, ENG.STATUS.UNKNOWN);
  assert.equal(e.frequencyMinutes, null);
});

// ---------------------------------------------------------------------------
// T6 — source communautaire
// ---------------------------------------------------------------------------
test('T6 — OSM / communauté : jamais OFFICIAL, jamais utilisée sans opt-in explicite', () => {
  const now = at(LUNDI, '11:43');
  const registry = {
    sources: [{ id: 'osm', label: 'OpenStreetMap (contributeurs)', source_type: 'COMMUNITY', url: 'https://www.openstreetmap.org/', retrieved_at: '2026-09-25' }],
    frequencies: [{
      id: 'ddd_1_osm', network: 'DDD', line_id: 'ddd_1', day_types: ['MONDAY'],
      service_start: '06:00', service_end: '21:00', frequency_minutes: 10, status: 'ACTIVE', source_id: 'osm',
    }],
  };
  const refused = ENG.estimateNextDeparture({ now, network: 'DDD', lineId: 'ddd_1', registry });
  assert.equal(refused.status, ENG.STATUS.UNKNOWN);
  assert.equal(ENG.displayFor(refused, { now }).isOfficial, false);

  const optedIn = ENG.estimateNextDeparture({ now, network: 'DDD', lineId: 'ddd_1', registry, allowCommunityFrequencies: true });
  assert.equal(optedIn.status, ENG.STATUS.ESTIMATED);
  assert.equal(optedIn.confidence, 'low');
  const display = ENG.displayFor(optedIn, { now });
  assert.equal(display.isOfficial, false, 'une source communautaire n’est jamais officielle');
  assert.equal(ENG.SOURCE_POLICY.COMMUNITY.official, false);
  assert.equal(ENG.SOURCE_POLICY.OPEN_DATA.official, false);
  assert.equal(ENG.SOURCE_POLICY.UNKNOWN.usable, false);
  assert.equal(ENG.SOURCE_POLICY.HISTORICAL.usable, false);
});

// ---------------------------------------------------------------------------
// T7 — GPS utilisateur
// ---------------------------------------------------------------------------
test('T7 — GPS utilisateur : localisation, proximité, routage — jamais un véhicule', () => {
  const userPosition = { latitude: 14.7167, longitude: -17.4677, accuracy: 12, at: `${LUNDI}T11:43:00+00:00` };
  assert.deepEqual(ENG.USER_POSITION_USES, ['LOCALISATION', 'STOP_PROXIMITY', 'DISTANCE', 'ROUTING']);
  assert.equal(ENG.vehicleFromUserPosition(userPosition, {}), null);

  const fromUser = ENG.classifyObservation({ kind: 'USER_POSITION', fromUserDevice: true, latitude: 14.7, longitude: -17.4 });
  assert.equal(fromUser.usable, false);
  assert.equal(fromUser.reason, 'USER_POSITION_CANNOT_BE_VEHICLE');

  const disguised = ENG.classifyObservation({
    kind: 'VEHICLE_OBSERVATION', fromUserDevice: true, source: 'téléphone', sourceType: 'OFFICIAL',
    observedAt: `${LUNDI}T11:43:00+00:00`, lineId: 'ter_dakar_diamniadio', vehicleId: 'moi', eta: `${LUNDI}T11:45:00+00:00`,
  }, { now: at(LUNDI, '11:43') });
  assert.equal(disguised.usable, false, 'une position utilisateur déguisée en véhicule est refusée');

  const e = est(TER, at(LUNDI, '11:43'), { observations: [{ ...userPosition, kind: 'USER_POSITION', fromUserDevice: true }], preferObservedRealtime: true });
  assert.equal(e.status, ENG.STATUS.ESTIMATED, 'le GPS utilisateur ne change pas le statut d’un départ');
});

// ---------------------------------------------------------------------------
// T8 — aucune heure inventée
// ---------------------------------------------------------------------------
test('T8 — aucune heure précise inventée : balayage complet de la journée', () => {
  const queries = [TER, BRT_B1, BRT_B2, DDD, { network: 'AFTU', lineId: 'aftu_1' }, { network: 'TATA', lineId: 'tata_50' }];
  const days = [LUNDI, SAMEDI, DIMANCHE, FERIE];
  for (const date of days) {
    for (let minutes = 0; minutes < 1440; minutes += 7) {
      for (const query of queries) {
        const now = { date, minutes };
        const e = est(query, now);
        assert.deepEqual(ENG.validateEstimate(e), [], `${date} ${minutes} ${query.lineId}`);
        const d = ENG.displayFor(e, { now });
        assert.equal(d.status, e.status);
        if (e.status === ENG.STATUS.ESTIMATED) {
          assert.notEqual(e.estimatedFrom, e.estimatedTo, 'fenêtre d’une seule minute = heure précise déguisée');
          assert.ok(!/^D[ée]part/.test(d.headline), `estimation affichée comme un départ : ${d.headline}`);
        }
        if (e.status === ENG.STATUS.UNKNOWN) {
          assert.equal(d.body, 'Horaire indisponible');
          assert.equal(d.isRealTime, false);
        }
      }
    }
  }
});

// ---------------------------------------------------------------------------
// T9 — fréquences par ligne
// ---------------------------------------------------------------------------
test('T9 — la fréquence d’une ligne ne s’applique jamais aux autres', () => {
  const dimanche = at(DIMANCHE, '11:00');
  assert.equal(est(BRT_B1, dimanche).status, ENG.STATUS.ESTIMATED, 'B1 circule tous les jours');
  assert.equal(est(BRT_B2, dimanche).status, ENG.STATUS.UNKNOWN, 'B2 n’a aucune fréquence le dimanche');
  assert.equal(est({ network: 'BRT', lineId: 'brt_b3_semi_express' }, at(LUNDI, '07:30')).status, ENG.STATUS.UNKNOWN);
  assert.equal(est(DDD, at(LUNDI, '11:00')).status, ENG.STATUS.UNKNOWN);
  assert.equal(est({ network: 'AFTU', lineId: 'aftu_1' }, at(LUNDI, '11:00')).status, ENG.STATUS.UNKNOWN);
  assert.equal(est({ network: 'TATA', lineId: 'tata_50' }, at(LUNDI, '11:00')).status, ENG.STATUS.UNKNOWN);
});

// ---------------------------------------------------------------------------
// T10 — fréquences par période
// ---------------------------------------------------------------------------
test('T10 — la fréquence dépend de la période et du type de jour', () => {
  const journee = est(TER, at(LUNDI, '11:43'));
  const soir = est(TER, at(LUNDI, '21:30'));
  const dimanche = est(TER, at(DIMANCHE, '11:43'));
  assert.equal(journee.frequencyMinutes, 10);
  assert.equal(soir.frequencyMinutes, 20);
  assert.equal(dimanche.frequencyMinutes, 20);
  assert.equal(est(TER, at(FERIE, '11:43')).frequencyMinutes, 20, 'un jour férié déclaré suit la règle dimanche/fériés');
  assert.equal(ENG.minutesBetween(journee.estimatedFrom, journee.estimatedTo), 10);
  assert.equal(ENG.minutesBetween(soir.estimatedFrom, soir.estimatedTo), 20);
});

// ---------------------------------------------------------------------------
// T11 / T12 — début et fin de service
// ---------------------------------------------------------------------------
test('T11 — début de service respecté : la fenêtre est ancrée sur l’ouverture documentée', () => {
  const e = est(TER, at(LUNDI, '05:00'));
  assert.equal(e.status, ENG.STATUS.ESTIMATED);
  assert.equal(clockOf(e.estimatedFrom), '05:30');
  assert.equal(clockOf(e.estimatedTo), '05:40');
  assert.equal(e.relative, 'BEFORE_SERVICE');
  assert.match(e.note, /non commencé/i);

  const dimanche = est(TER, at(DIMANCHE, '05:00'));
  assert.equal(clockOf(dimanche.estimatedFrom), '06:30', 'le dimanche ouvre à 6h30');

  const avant = ENG.estimateNextDepartureFromFrequency({
    currentTime: at(LUNDI, '04:00'), frequency: 10, serviceStart: '05:30', serviceEnd: '22:00', dayType: 'MONDAY',
  });
  assert.equal(avant.status, ENG.STATUS.ESTIMATED);
  assert.equal(clockOf(avant.estimatedFrom), '05:30');
});

test('T12 — fin de service respectée : aucune estimation après le dernier départ documenté', () => {
  const e = est(TER, at(LUNDI, '22:30'));
  assert.equal(e.status, ENG.STATUS.UNKNOWN);
  assert.equal(e.reason, ENG.REASONS.SERVICE_ENDED);
  assert.equal(e.estimatedFrom, null);
  assert.equal(est(BRT_B1, at(LUNDI, '21:30')).status, ENG.STATUS.UNKNOWN, 'le BRT s’arrête à 21h');
  const fin = ENG.estimateNextDepartureFromFrequency({
    currentTime: at(LUNDI, '22:00'), frequency: 20, serviceStart: '06:00', serviceEnd: '22:00', dayType: 'MONDAY',
  });
  assert.equal(fin.status, ENG.STATUS.UNKNOWN);
});

// ---------------------------------------------------------------------------
// T13 — changement de fréquence en cours de journée
// ---------------------------------------------------------------------------
test('T13 — changement de fréquence pendant la journée (10 min → 20 min à 21h)', () => {
  assert.equal(est(TER, at(LUNDI, '20:55')).frequencyMinutes, 10);
  assert.equal(est(TER, at(LUNDI, '21:00')).frequencyMinutes, 20);
  assert.equal(est(TER, at(LUNDI, '21:05')).frequencyMinutes, 20);
  const finDePeriode = est(TER, at(LUNDI, '20:57'));
  assert.equal(clockOf(finDePeriode.estimatedTo), '21:00', 'la fenêtre ne déborde pas sur la période suivante');
  const sel = ENG.selectFrequency(ENG.buildIndex(REGISTRY).frequencies, {
    network: 'TER', lineId: 'ter_dakar_diamniadio', dayType: 'MONDAY', date: LUNDI, minutes: ENG.clockToMinutes('21:30'),
  });
  assert.equal(sel.frequency.id, 'ter_dakar_diamniadio_lun_sam_soir', 'la période qui contient l’instant est choisie');
});

// ---------------------------------------------------------------------------
// T14 — assistant IA
// ---------------------------------------------------------------------------
test('T14 — l’assistant IA utilise exactement le même statut que l’interface', () => {
  const now = at(LUNDI, '11:43');
  const cases = [
    [TER, 'TER'],
    [BRT_B1, 'BRT'],
    [DDD, 'DDD'],
  ];
  for (const [query, mode] of cases) {
    const e = est(query, now);
    const display = ENG.displayFor(e, { now });
    const answer = ENG.assistantReply(e, { mode, now });
    assert.equal(display.status, e.status);
    if (e.status === ENG.STATUS.ESTIMATED) {
      assert.match(answer, new RegExp(`fenêtre de 0 à ${e.frequencyMinutes} minutes`));
      assert.match(answer, /L'heure exacte .* n'est pas disponible/);
      assert.ok(!/\d{1,2}h\d{2}/.test(answer), `aucune heure dans la réponse estimée : ${answer}`);
    }
    if (e.status === ENG.STATUS.UNKNOWN) {
      assert.match(answer, /je n’ai pas actuellement de donnée suffisamment fiable/i);
      assert.ok(!/\d+\s*min/.test(answer), 'aucune durée inventée quand la donnée manque');
    }
  }
  assert.match(ENG.assistantReply(est(BRT_B1, now), { mode: 'BRT', now }), /fenêtre de 0 à 6 minutes/);

  // Dernière minute de service : « 0 à 1 minute », jamais « 1 minutes ».
  const fin = at(LUNDI, '20:59');
  const answerFin = ENG.assistantReply(est(TER, fin), { mode: 'TER', now: fin });
  assert.match(answerFin, /fenêtre de 0 à 1 minute\./);
  assert.ok(!/1 minutes/.test(answerFin), `accord singulier attendu : ${answerFin}`);
});

// ---------------------------------------------------------------------------
// T15 à T18 — verrous de référentiel
// ---------------------------------------------------------------------------
test('T15 — TER Keur Massar (KMF) reste UNKNOWN', () => {
  assert.equal(est({ network: 'TER', lineId: 'ter_keur_massar', stopId: 'stop_keur_massar' }, at(LUNDI, '11:43')).status, ENG.STATUS.UNKNOWN);
  const terRoute = NETWORK.routes.find((r) => r.id === 'ter_dakar_diamniadio');
  assert.ok(!terRoute.stops.some((id) => /keur_massar/.test(id)));
  assert.ok(!REGISTRY.frequencies.some((f) => /keur_massar/.test(JSON.stringify(f))));
  const kmf = NETWORK.stops.find((s) => s.id === 'stop_keur_massar');
  assert.equal(kmf.data_status, 'UNVERIFIED');
  assert.equal(kmf.data_trust, 'UNVERIFIED');
  assert.match(kmf.audit_note, /Keur Massar n’est pas une gare TER/);
});

test('T16 — Mbao reste distinct de KMF', () => {
  const mbao = NETWORK.stops.find((s) => s.id === 'stop_mbao');
  const kmf = NETWORK.stops.find((s) => s.id === 'stop_keur_massar');
  assert.ok(mbao && kmf);
  assert.notEqual(mbao.id, kmf.id);
  assert.notEqual(mbao.place_id, kmf.place_id);
  assert.equal(mbao.data_status, 'UNVERIFIED');
  const terRoute = NETWORK.routes.find((r) => r.id === 'ter_dakar_diamniadio');
  assert.ok(!terRoute.stops.includes('stop_mbao'));
  assert.equal(est({ network: 'TER', lineId: 'ter_mbao' }, at(LUNDI, '11:43')).status, ENG.STATUS.UNKNOWN);
});

test('T17 — Yeumbeul A/B ne devient pas institutionnellement résolu', () => {
  const yeumbeulStops = NETWORK.stops.filter((s) => /yeumbeul/i.test(s.id) || /yeumbeul/i.test(s.name));
  assert.equal(yeumbeulStops.length, 1, 'un seul arrêt Yeumbeul : aucun A ni B n’est créé');
  assert.ok(!/yeumbeul\s*[ab]\b/i.test(JSON.stringify(yeumbeulStops[0])));
  assert.ok(!REGISTRY.frequencies.some((f) => /yeumbeul/i.test(JSON.stringify(f))));
  const e = est({ network: 'TER', lineId: 'ter_dakar_diamniadio', stopId: 'stop_yeumbeul' }, at(LUNDI, '11:43'));
  assert.equal(e.direction, null, 'aucun sens A/B n’est inventé');
});

test('T18 — AIBD n’est pas ajouté au TER', () => {
  assert.ok(NETWORK.services_not_exposed.some((s) => s.id === 'ter_diamniadio_aibd' && s.data_status === 'FUTURE' && s.exposed === false));
  assert.ok(!NETWORK.stops.some((s) => /aibd/i.test(s.id) || /aibd/i.test(s.name)));
  assert.ok(!REGISTRY.frequencies.some((f) => /aibd/i.test(JSON.stringify(f))));
  assert.equal(est({ network: 'TER', lineId: 'ter_diamniadio_aibd' }, at(LUNDI, '11:43')).status, ENG.STATUS.UNKNOWN);
  const terRoute = NETWORK.routes.find((r) => r.id === 'ter_dakar_diamniadio');
  assert.equal(terRoute.stops.length, 13, 'les 13 gares V2 restent intactes');
});

// ---------------------------------------------------------------------------
// Itinéraires — l'incertitude est conservée
// ---------------------------------------------------------------------------
test('Itinéraires : une estimation donne une fenêtre d’arrivée, jamais 12h17', () => {
  const now = at(LUNDI, '11:43');
  const e = est(TER, now);
  const leg = ENG.planItineraryLeg(e, { durationMinutes: 34, fromName: 'Dakar', toName: 'Diamniadio' });
  assert.equal(leg.precision, 'WINDOW');
  assert.equal(leg.departureTime, null);
  assert.equal(leg.arrivalTime, null);
  assert.deepEqual(leg.departureWindow, [e.estimatedFrom, e.estimatedTo]);
  assert.equal(clockOf(leg.arrivalWindow[0]), '12:17');
  assert.equal(clockOf(leg.arrivalWindow[1]), '12:27');
  assert.match(leg.note, /incertitude est conservée/);

  const unknownLeg = ENG.planItineraryLeg(est(DDD, now), { durationMinutes: 30 });
  assert.equal(unknownLeg.precision, 'NONE');
  assert.equal(unknownLeg.arrivalTime, null);
  assert.equal(unknownLeg.arrivalWindow, null);

  const scheduledLeg = ENG.planItineraryLeg(
    est(TER, now, { scheduledDepartures: [{ time: '12:10', sourceType: 'OFFICIAL', source: 'SETER' }] }),
    { durationMinutes: 30 });
  assert.equal(scheduledLeg.precision, 'EXACT');
  assert.equal(clockOf(scheduledLeg.departureTime), '12:10');
  assert.equal(clockOf(scheduledLeg.arrivalTime), '12:40');
});

// ---------------------------------------------------------------------------
// Politique des données simulées (API GTFS-RT)
// ---------------------------------------------------------------------------
test('API GTFS-RT : aucune donnée simulée sans drapeau explicite, jamais en production', () => {
  assert.equal(POLICY.mayServeSimulatedData({}).serve, false);
  assert.equal(POLICY.mayServeSimulatedData({ USE_MOCK: 'true' }).serve, false, 'USE_MOCK seul ne suffit plus');
  assert.equal(POLICY.mayServeSimulatedData({ USE_MOCK: 'true', NODE_ENV: 'production' }).serve, false);
  assert.equal(POLICY.mayServeSimulatedData({ ALLOW_SIMULATED_DATA: 'true', NODE_ENV: 'production' }).serve, false);
  assert.equal(POLICY.mayServeSimulatedData({ ALLOW_SIMULATED_DATA: 'true', NODE_ENV: 'development' }).serve, true);

  const refusal = POLICY.refusalPayload('/api/gtfs-rt/vehiclePositions', POLICY.mayServeSimulatedData({ USE_MOCK: 'true' }));
  assert.equal(refusal.entity.length, 0);
  assert.equal(refusal._meta.simulated, false);
  assert.equal(refusal._meta.status, 'UNKNOWN');

  const vercel = JSON.parse(fs.readFileSync(path.join(ROOT, 'vercel.json'), 'utf8'));
  assert.equal(vercel.env.USE_MOCK, 'false');
  assert.equal(vercel.env.ALLOW_SIMULATED_DATA, 'false');
  const server = fs.readFileSync(path.join(ROOT, 'server/server.js'), 'utf8');
  assert.ok(!/USE_MOCK === 'true' \|\| !process\.env\.CETUD_API_KEY/.test(server), 'l’ancien déclenchement automatique du mock est supprimé');
  assert.ok(server.includes('gtfs-rt-policy.js'));
});

// ---------------------------------------------------------------------------
// Non-régression de l'interface publiée
// ---------------------------------------------------------------------------
test('Interface publiée : plus aucun faux départ, plus aucun véhicule simulé', () => {
  const raw = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  // Les seules mentions restantes sont des commentaires d'audit (AVANT/APRÈS) :
  // ce qui est vérifié ici, c'est ce que la page affiche ou exécute.
  const html = raw
    .replace(/<!--[\s\S]*?-->/g, '')     // commentaires HTML (mémoire AVANT/APRÈS)
    .replace(/\/\*[\s\S]*?\*\//g, '')          // commentaires de bloc JS
    .replace(/^\s*\/\/.*$/gm, '');         // commentaires de ligne JS
  assert.ok(!/"next"\s*:/.test(html), 'aucun tableau de départs codé en dur');
  assert.ok(!/127 véhicules/.test(html));
  assert.ok(!/generateMockGTFS/.test(html));
  assert.ok(!/updateVehicles/.test(html));
  assert.ok(!/Math\.random\(\) \* 0\.05/.test(html), 'aucune progression aléatoire de véhicule');
  assert.ok(!/vehicle-pin/.test(html) || !/new L\.marker\(pos/.test(html), 'aucun marqueur véhicule fictif');
  assert.ok(raw.includes('engine/departure-engine.js'), 'le moteur commun est chargé');
  assert.ok(html.includes('data/transit/departure-frequencies.json'), 'le référentiel sourcé est lu');
  assert.ok(html.includes('assistantAnswer'), 'l’assistant passe par le moteur');
});

test('Référentiel de fréquences : valide, sourcé, et identique pour les deux applications', () => {
  assert.deepEqual(ENG.validateFrequencyRegistry(REGISTRY), []);
  for (const f of REGISTRY.frequencies) {
    const src = REGISTRY.sources.find((s) => s.id === f.source_id);
    assert.ok(src, `source inconnue pour ${f.id}`);
    assert.ok(['OFFICIAL', 'INSTITUTIONAL', 'OPEN_DATA'].includes(src.source_type), `${f.id} : source non utilisable (${src.source_type})`);
    assert.equal(f.status, 'ACTIVE');
    assert.ok(f.frequency_minutes > 0);
  }
  // Garde anti-dérive : le référentiel embarqué par l'application Flutter doit
  // être identique, octet pour octet, à celui du dépôt.
  const mirror = path.join(ROOT, 'flutter-src/assets/data/departure-frequencies.json');
  assert.ok(fs.existsSync(mirror), 'miroir Flutter absent');
  assert.equal(
    fs.readFileSync(mirror, 'utf8'),
    fs.readFileSync(path.join(ROOT, 'data/transit/departure-frequencies.json'), 'utf8'),
    'le référentiel des deux applications a divergé'
  );
});

test('Référentiel audité intact : 13 gares TER, 23 stations BRT, KMF/Mbao/Yeumbeul inchangés', () => {
  const ter = NETWORK.routes.find((r) => r.id === 'ter_dakar_diamniadio');
  const b1 = NETWORK.routes.find((r) => r.id === 'brt_b1_guediawaye_petersen');
  assert.equal(ter.stops.length, 13);
  assert.equal(b1.stops.length, 23);
  assert.equal(NETWORK.operators.length, 5);
  assert.equal(NETWORK.routes.length, 105);
  assert.equal(NETWORK.stops.length, 117);
  assert.equal(NETWORK.dataset_meta.schema, 'dakar-bus-network/provenance-v1');
  const kmf = NETWORK.stops.find((s) => s.id === 'stop_keur_massar');
  assert.equal(kmf.source, null);
  assert.equal(kmf.data_status, 'UNVERIFIED');
  assert.equal(NETWORK.stops.find((s) => s.id === 'stop_mbao').place_id, 'place_mbao');
  assert.equal(NETWORK.stops.find((s) => s.id === 'stop_yeumbeul').data_status, 'CONFIRMED');
});
