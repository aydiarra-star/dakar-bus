/**
 * DAKAR BUS — POLITIQUE DES DONNÉES GTFS-RT
 * ==========================================================================
 * Le proxy `server/server.js` sait produire des positions de véhicules, des
 * retards et des alertes SIMULÉS (`generateMockDakarGTFS`). Ces données ne
 * doivent JAMAIS pouvoir être servies comme du temps réel :
 *
 *   • une fréquence n'est pas du temps réel ;
 *   • une position inventée n'est pas un véhicule (§15) ;
 *   • un retard chiffré sans donnée de trafic est interdit (§13) ;
 *   • REAL_TIME est réservé aux données réellement observées (§14).
 *
 * Règle appliquée : la simulation est DÉSACTIVÉE par défaut, refusée
 * explicitement en production, et ne peut être activée que par un drapeau
 * dédié — jamais par simple absence de clé API (le comportement historique
 * `USE_MOCK === 'true' || !CETUD_API_KEY` est supprimé).
 *
 * Module pur, testable sans Express ni réseau (voir tests/departure-engine.test.js).
 */
(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module && module.exports) module.exports = api;
  if (root) root.DakarGtfsRtPolicy = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const POLICY_VERSION = '1.0.0';

  const DECISION = Object.freeze({
    SERVE_SIMULATED: 'SERVE_SIMULATED',
    REFUSE: 'REFUSE',
  });

  const isTrue = (value) => String(value == null ? '' : value).toLowerCase() === 'true';

  /**
   * @param {Object} env  variables d'environnement (process.env)
   * @returns {{serve:boolean, decision:string, reason:string, note:string|null}}
   */
  function mayServeSimulatedData(env) {
    const e = env || {};
    const requested = isTrue(e.USE_MOCK) || isTrue(e.ALLOW_SIMULATED_DATA);
    const explicitlyAllowed = isTrue(e.ALLOW_SIMULATED_DATA);
    const isProduction = String(e.NODE_ENV || '').toLowerCase() === 'production';

    if (!requested) {
      return {
        serve: false,
        decision: DECISION.REFUSE,
        reason: 'SIMULATION_NOT_REQUESTED',
        note: 'Aucune donnée simulée servie : la simulation est désactivée par défaut.',
      };
    }
    if (isProduction) {
      return {
        serve: false,
        decision: DECISION.REFUSE,
        reason: 'SIMULATION_FORBIDDEN_IN_PRODUCTION',
        note: 'Données simulées refusées en production : REAL_TIME exige une observation réelle (§14).',
      };
    }
    if (!explicitlyAllowed) {
      return {
        serve: false,
        decision: DECISION.REFUSE,
        reason: 'SIMULATION_WITHOUT_EXPLICIT_FLAG',
        note: 'USE_MOCK seul ne suffit plus : il faut ALLOW_SIMULATED_DATA=true, hors production et explicitement.',
      };
    }
    return {
      serve: true,
      decision: DECISION.SERVE_SIMULATED,
      reason: 'SIMULATION_EXPLICITLY_ALLOWED_OUTSIDE_PRODUCTION',
      note: 'Données simulées servies : cet endpoint ne doit jamais être présenté comme du temps réel.',
    };
  }

  /**
   * Réponse de refus : un corps explicite plutôt qu'un flux inventé. Le
   * client ne peut pas confondre un refus avec un passage de véhicule.
   */
  function refusalPayload(endpoint, verdict) {
    return {
      header: {
        gtfsRealtimeVersion: '2.0',
        incrementality: 'FULL_DATASET',
        timestamp: Math.floor(Date.now() / 1000),
      },
      entity: [],
      _meta: {
        endpoint: endpoint || null,
        source: 'none',
        simulated: false,
        status: 'UNKNOWN',
        reason: (verdict && verdict.reason) || 'SIMULATION_REFUSED',
        note: (verdict && verdict.note) ||
          'Aucune donnée temps réel disponible. Aucune donnée simulée n’est servie.',
        policyVersion: POLICY_VERSION,
      },
    };
  }

  /** Marque une charge simulée à des fins de test/développement local. */
  function tagSimulated(payload) {
    if (!payload || typeof payload !== 'object') return payload;
    const meta = { ...(payload._meta || {}), source: 'simulated', simulated: true, status: 'SIMULATED', note: 'Donnée simulée — ne jamais présenter comme du temps réel.' };
    return { ...payload, _meta: meta };
  }

  return { POLICY_VERSION, DECISION, mayServeSimulatedData, refusalPayload, tagSimulated };
});
